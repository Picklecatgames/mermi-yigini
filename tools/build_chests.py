# Blender (5.x, background): the crates on the chest stands, from Sketchfab downloads (credits in
# docs/ayrintilar.md), cut down for a game: every part baked and joined into one mesh, decimated to
# a triangle budget, textures shrunk, the long side along X and the front (lock side) toward glTF +Z,
# centred with its bottom on the origin and scaled to 1 m wide. The game sizes each one by its level
# (scripts/chests.gd), so the reward grows down the row. A preview of each, seen from the front, goes
# next to it (<name>_front.png) to check the turn.
# Run: blender -b --factory-startup -P tools/build_chests.py -- <downloads dir> <out_dir>
#   <downloads dir> holds chest<level>.glb as Sketchfab's "glb" download.
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(OUT, exist_ok=True)

TEX = 2048     # largest texture side kept
BUDGET = 40000  # triangles
# level: extra turn about the up axis (degrees) after the long side is laid along X, so the
# front faces +Z; read off the previews.
TURN = {1: 180, 2: 180, 3: 180, 6: 180}
# level: materials of what came with the model but is not the chest (a sand dune, a book; steam cards).
DROP = {4: {"sand"}, 7: {"Props", "Steam"}}
# Sat tilted on its dune: stood up along its own principal axes.
LEVEL = {4}


def keep_main(o, PAD):
    # What lies outside the biggest part's footprint is not the chest: a second chest beside it
    # (level 2), coins spilled in front (level 7). Sketchfab exports are triangle soup: welded
    # first, or the biggest "part" is one plank.
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=max(o.dimensions) * 1e-4)
    bm.to_mesh(o.data)
    bm.free()
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [p for p in bpy.context.scene.objects if p.type == "MESH"]
    box = {p: bounds(p) for p in parts}
    vol = lambda p: (box[p][1] - box[p][0]).x * (box[p][1] - box[p][0]).y * (box[p][1] - box[p][0]).z
    lo, hi = box[max(parts, key=vol)]
    pad = (hi - lo) * PAD
    keep = []
    for p in parts:
        c = (box[p][0] + box[p][1]) / 2
        if lo.x - pad.x <= c.x <= hi.x + pad.x and lo.y - pad.y <= c.y <= hi.y + pad.y:
            keep.append(p)
        else:
            bpy.data.objects.remove(p)
    print("  kept %d of %d parts" % (len(keep), len(parts)))
    bpy.ops.object.select_all(action="DESELECT")
    for p in keep:
        p.select_set(True)
    bpy.context.view_layer.objects.active = keep[0]
    if len(keep) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def level_out(o):
    # The box's edges are its principal axes; turn them onto X, Y, Z, the one nearest up kept up.
    import numpy as np
    vs = np.array([v.co[:] for v in o.data.vertices])
    vs = vs - vs.mean(axis=0)
    _, vec = np.linalg.eigh(vs.T @ vs)
    up = int(np.argmax(np.abs(vec[2])))
    rest = [i for i in range(3) if i != up]
    axes = [vec[:, rest[0]], vec[:, rest[1]], vec[:, up] * np.sign(vec[2, up])]
    axes[1] = np.cross(axes[2], axes[0])
    o.data.transform(Matrix([list(a) for a in axes]).to_4x4())


def load(path, drop=()):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and any(m and m.name in drop for m in o.data.materials):
            bpy.data.objects.remove(o)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:  # bake the Sketchfab node chain into the mesh, drop the empties
        o.data = o.data.copy()
        o.data.transform(o.matrix_world)
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    for a in list(bpy.data.actions):  # chest 7's lid animation: not used yet
        bpy.data.actions.remove(a)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def bounds(o):
    vs = [v.co for v in o.data.vertices]
    return Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)])


def preview(o, path):
    # Workbench, textured, orthographic, from a little above the front (glTF +Z is Blender -Y)
    # and from behind, so the lock side can be told from the hinges.
    s = bpy.context.scene
    s.render.engine = "BLENDER_WORKBENCH"
    s.display.shading.light = "STUDIO"
    s.display.shading.color_type = "TEXTURE"
    s.render.resolution_x = s.render.resolution_y = 384
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    s.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.4
    s.camera = cam
    for side, y, turn in (("front", -4.0, 0.0), ("back", 4.0, 180.0)):
        cam.location = (0.0, y, 1.3)
        cam.rotation_euler = (math.radians(80), 0.0, math.radians(turn))
        s.render.filepath = path % side
        bpy.ops.render.render(write_still=True)


for name in sorted(f for f in os.listdir(SRC) if f.startswith("chest") and f.endswith(".glb")):
    level = int(name[5:-4])
    o = keep_main(load(os.path.join(SRC, name), DROP.get(level, ())), 0.02 if level == 7 else 0.1)  # 7's coins lie right at its feet
    if level in LEVEL:
        level_out(o)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if tris > BUDGET:
        m = o.modifiers.new("decimate", "DECIMATE")
        m.ratio = BUDGET / tris
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
    lo, hi = bounds(o)
    d = hi - lo
    if d.y > d.x:  # long side along X
        o.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
    o.data.transform(Matrix.Rotation(math.radians(TURN.get(level, 0)), 4, "Z"))
    lo, hi = bounds(o)
    o.data.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    o.data.transform(Matrix.Scale(1.0 / (hi.x - lo.x), 4))
    for img in bpy.data.images:
        if img.size[0] > TEX or img.size[1] > TEX:
            k = TEX / max(img.size)
            img.scale(int(img.size[0] * k), int(img.size[1] * k))
    lo, hi = bounds(o)
    print("level %d: %d tris, %.2f x %.2f x %.2f (w x h x d)" % (level, sum(len(p.vertices) - 2 for p in o.data.polygons), hi.x - lo.x, hi.z - lo.z, hi.y - lo.y))
    out = os.path.join(OUT, "chest_%02d.glb" % level)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=False, export_image_format="JPEG", export_jpeg_quality=90)
    preview(o, os.path.join(OUT, "chest_%02d_%%s.png" % level))
