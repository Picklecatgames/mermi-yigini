# Blender (5.x, background): turns one of our textured glbs into its low poly version (2026-11-02,
# the user: the game goes low poly, we make the assets ourselves). Every mesh is collapsed down to
# a few hundred faces, near-flat faces merged into planes, shaded flat, and its texture boiled
# down to a handful of flat colours (k-means over the faces of each material, specks melted into
# the regions round them, snapped to tools/lowpoly_palette.json), as vertex colours. Textures go;
# a flat card (a blueprint, a poster: a few faces) keeps a small copy of its own.
# Node names, the hierarchy and transforms stay as they were: scripts/bench_top.gd and
# tools/build_world.gd find parts by them.
#   assets/lowpoly/<same name>.glb: the glb's root takes its name from the file, keep it.
# Run: blender -b --factory-startup -P tools/lowpoly.py -- <in.glb> <out.glb> [detail]
#   detail scales the face budget (1.0 by default; 2.0 doubles it).
import bpy, bmesh, os, sys, math
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[:2]
DETAIL = float(args[2]) if len(args) > 2 else 1.0

CARD_FACES = 12  # up to this many faces it's a card: keeps its texture
MIN_FACES, MAX_FACES = 24, 1600
COLOURS = 4  # flat colours per material
SAMPLE_PX = 64  # textures are averaged down to this before sampling
DISSOLVE = math.radians(5.0)  # faces this close to flat merge into one plane
SMOOTH_PASSES = 4  # each face takes its neighbours' colour where most of them agree: regions, not specks
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "lowpoly_palette.json")) as f:
    import json
    PALETTE = np.array([[int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] for h in json.load(f)["colours"]])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)


def budget(faces):
    return int(min(max(math.sqrt(faces) * 10 * DETAIL, MIN_FACES), MAX_FACES * DETAIL))


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def upstream_image(socket):
    """The first image texture feeding a socket, through mix and the like."""
    seen = set()
    stack = [l.from_node for l in socket.links]
    while stack:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        if n.type == "TEX_IMAGE" and n.image:
            return n.image
        for i in n.inputs:
            stack += [l.from_node for l in i.links]
    return None


_small = {}


def small_pixels(img):
    """The image averaged down to SAMPLE_PX, linear RGB, rows from the bottom as UV v."""
    if img.name in _small:
        return _small[img.name]
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)[:, :, :3]
    f = max(1, max(w, h) // SAMPLE_PX)
    hh, ww = h // f * f, w // f * f
    px = px[:hh, :ww].reshape(hh // f, f, ww // f, f, 3).mean(axis=(1, 3))
    if img.colorspace_settings.name == "sRGB":
        px = srgb_to_linear(px)
    _small[img.name] = px
    return px


def material_info(mat):
    """(base colour factor, image or None, emission rgb, alpha, metallic) of a glTF material."""
    if mat is None or not mat.use_nodes:
        return np.array([0.6, 0.6, 0.6]), None, np.zeros(3), 1.0, 0.0
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return np.array([0.6, 0.6, 0.6]), None, np.zeros(3), 1.0, 0.0
    base = bsdf.inputs["Base Color"]
    factor = np.array(base.default_value[:3])
    img = upstream_image(base)
    if img is not None and not base.links[0].from_node.type == "TEX_IMAGE":
        factor = np.ones(3)  # the glTF importer's factor sits in a mix node; the texture rules
    emit = bsdf.inputs["Emission Color"]
    strength = bsdf.inputs["Emission Strength"].default_value
    emission = np.array(emit.default_value[:3]) * strength
    emit_img = upstream_image(emit)
    if emit_img is not None:
        emission = small_pixels(emit_img).reshape(-1, 3).mean(axis=0) * max(strength, 1.0)
    alpha = bsdf.inputs["Alpha"].default_value
    metallic = bsdf.inputs["Metallic"].default_value if not bsdf.inputs["Metallic"].links else 0.5
    return factor, img, emission, alpha, metallic


def kmeans(colours, weights, k):
    k = min(k, len(colours))
    centres = colours[np.argsort(colours.sum(axis=1))[np.linspace(0, len(colours) - 1, k).astype(int)]].copy()
    for _ in range(12):
        d = ((colours[:, None, :] - centres[None]) ** 2).sum(axis=2)
        label = d.argmin(axis=1)
        for j in range(k):
            m = label == j
            if m.any():
                centres[j] = np.average(colours[m], axis=0, weights=weights[m])
    return centres, label


def to_palette(linear):
    """The nearest palette colour (redmean distance in sRGB), back to linear."""
    s = np.where(linear <= 0.0031308, linear * 12.92, 1.055 * np.power(np.clip(linear, 0, None), 1 / 2.4) - 0.055)
    rm = (s[:, None, 0] + PALETTE[None, :, 0]) / 2
    d = s[:, None, :] - PALETTE[None]
    dist = (2 + rm) * d[..., 0] ** 2 + 4 * d[..., 1] ** 2 + (3 - rm) * d[..., 2] ** 2
    return srgb_to_linear(PALETTE[dist.argmin(axis=1)])


def neighbours(mesh):
    by_edge = {}
    for p in mesh.polygons:
        for e in p.edge_keys:
            by_edge.setdefault(e, []).append(p.index)
    near = [[] for _ in mesh.polygons]
    for faces in by_edge.values():
        for a in faces:
            near[a] += [b for b in faces if b != a]
    return near


def smooth_labels(label, area, near):
    """Each face goes with the colour that covers most of it and its neighbours: specks melt into
    the region round them, edges between regions stay where they are."""
    for _ in range(SMOOTH_PASSES):
        new = label.copy()
        for i, nb in enumerate(near):
            if not nb:
                continue
            votes = {label[i]: area[i]}
            for j in nb:
                votes[label[j]] = votes.get(label[j], 0.0) + area[j]
            new[i] = max(votes, key=votes.get)
        label = new
    return label


def face_colours(mesh):
    """One flat colour per face: its material's texture under the face, clustered per material into
    a few colours, specks smoothed into regions, every colour snapped to the shared palette."""
    uv = mesh.uv_layers.active
    n = len(mesh.polygons)
    mat_of = np.array([p.material_index for p in mesh.polygons])
    area = np.array([p.area for p in mesh.polygons]) + 1e-9
    centres = []
    label = np.zeros(n, dtype=int)
    for mi in np.unique(mat_of):
        mat = mesh.materials[mi] if mi < len(mesh.materials) else None
        factor, img, _, _, _ = material_info(mat)
        faces = np.nonzero(mat_of == mi)[0]
        if img is None or uv is None or img.size[0] == 0:
            label[faces] = len(centres)
            centres.append(factor)
            continue
        px = small_pixels(img)
        h, w = px.shape[:2]
        cols = np.empty((len(faces), 3))
        for j, fi in enumerate(faces):
            p = mesh.polygons[fi]
            pts = [uv.data[li].uv for li in p.loop_indices]
            cu = sum(q[0] for q in pts) / len(pts)
            cv = sum(q[1] for q in pts) / len(pts)
            # the centre and halfway to each corner: a face's colour, not one texel's
            samples = [(cu, cv)] + [((cu + q[0]) / 2, (cv + q[1]) / 2) for q in pts]
            acc = np.zeros(3)
            for su, sv in samples:
                x = int((su % 1.0) * w) % w
                y = int((sv % 1.0) * h) % h
                acc += px[y, x]
            cols[j] = acc / len(samples) * factor
        c, l = kmeans(cols, area[faces], COLOURS)
        label[faces] = l + len(centres)
        centres += list(c)
    label = smooth_labels(label, area, neighbours(mesh))
    return to_palette(np.array(centres))[label]


def simplify(mesh):
    """Coplanar faces into one plane, then back to triangles: clean flat sides, the silhouette kept."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.dissolve_limit(bm, angle_limit=DISSOLVE, use_dissolve_boundaries=False,
                             verts=bm.verts, edges=bm.edges, delimit={"MATERIAL"})
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()


def flat_material(src, name):
    factor, img, emission, alpha, metallic = material_info(src)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.3 if metallic > 0.4 else 0.0
    if emission.max() > 0.01:
        peak = float(emission.max())  # the hue in the colour, the brightness in the strength
        bsdf.inputs["Emission Color"].default_value = (*(emission / peak), 1.0)
        bsdf.inputs["Emission Strength"].default_value = max(1.0, peak)
    if alpha < 0.99:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "BLENDED"
    return mat


def shrink_textures(mesh):
    """A card keeps its picture, small: 256 px, no normal or roughness maps."""
    for mat in mesh.materials:
        if mat is None or not mat.use_nodes:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        for name in ("Normal", "Roughness", "Metallic"):
            for l in list(bsdf.inputs[name].links):
                mat.node_tree.links.remove(l)
        bsdf.inputs["Roughness"].default_value = 0.85
        img = upstream_image(bsdf.inputs["Base Color"])
        if img is not None and max(img.size) > 256:
            img.scale(256, max(1, int(256 * img.size[1] / img.size[0])))


scene = bpy.context.scene
before = after = 0
users = {}
for o in scene.objects:
    if o.type == "MESH":
        users.setdefault(o.data, []).append(o)

for mesh, objs in users.items():
    faces = len(mesh.polygons)
    before += faces * len(objs)
    if faces <= CARD_FACES:
        shrink_textures(mesh)
        after += faces * len(objs)
        continue
    o = objs[0]
    target = budget(faces)
    if target < faces:
        mod = o.modifiers.new("lp", "DECIMATE")
        mod.ratio = target / faces
        mod.use_collapse_triangulate = True
        dg = bpy.context.evaluated_depsgraph_get()
        new = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        o.modifiers.remove(mod)
    else:
        new = mesh.copy()
    new.name = mesh.name
    simplify(new)
    cols = face_colours(new)
    lp = flat_material(new.materials[0] if new.materials else None, mesh.name + "_lp")
    # one surface, one material: the colours carry what the materials used to
    for p in new.polygons:
        p.material_index = 0
        p.use_smooth = False
    new.materials.clear()
    new.materials.append(lp)
    attr = new.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    loop_cols = np.repeat(cols, [p.loop_total for p in new.polygons], axis=0)
    rgba = np.hstack([loop_cols, np.ones((len(loop_cols), 1))]).astype(np.float32).ravel()
    attr.data.foreach_set("color", rgba)
    new.color_attributes.active_color = attr
    for ob in objs:
        ob.data = new
    after += len(new.polygons) * len(objs)

print("lowpoly %s: %d -> %d faces" % (os.path.basename(SRC), before, after))

opts = {"filepath": OUT, "export_format": "GLB", "export_yup": True, "export_image_format": "JPEG",
        "export_jpeg_quality": 85}
props = bpy.ops.export_scene.gltf.get_rna_type().properties
if "export_vertex_color" in props:
    opts["export_vertex_color"] = "ACTIVE" if "ACTIVE" in [i.identifier for i in props["export_vertex_color"].enum_items] else "MATERIAL"
else:
    opts["export_colors"] = True
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(**opts)
