# Blender (5.x, background): the twelve crate keys, from Sketchfab downloads (credits in
# docs/ayrintilar.md), cut down for a game: each key on its own, decimated to a triangle budget,
# textures shrunk, scaled to a length by tier and centred, written to <out>/key_NN.glb in rank
# order (common first). Key N opens crate N (assets/props/chests, chosen to match). The "Keys" pack
# holds four keys in one mesh; they are split apart by position.
# Run: blender -b --factory-startup -P tools/build_keys.py -- <downloads dir> <out_dir> [ranks]
#   <downloads dir> holds keyN.glb (Sketchfab "glb" downloads, keys 1-7) and one unzipped folder per
#   older zip (key, victorian_key, key__2_, medieval_gold_key, old_key) with its scene.gltf.
#   [ranks]: e.g. "1-7" builds only those.
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = ARGS[:2]
ONLY = range(int(ARGS[2].split("-")[0]), int(ARGS[2].split("-")[-1]) + 1) if len(ARGS) > 2 else range(1, 13)
os.makedirs(OUT, exist_ok=True)

# Long side of the finished key, m, and texture size, by tier.
TIERS = {"common": (0.08, 512), "rare": (0.10, 512), "legendary": (0.13, 1024)}
# rank: (source, which key of a multi-key mesh counted left to right or None, tier, triangle budget)
# 2026-10-22: 1-7 replaced to match their crates (the Sandman key went); 8-12 as before.
KEYS = [
    ("key1", None, "common", 1200),  # a padlock set: only the key is kept (MESH)
    ("key2", None, "common", 1200),
    ("key3", None, "common", 1200),
    ("key4", None, "common", 1500),
    ("key5", None, "rare", 2000),
    ("key6", None, "rare", 4000),  # a skull: the face needs the triangles; opens the mid-game weapon
    ("key7", None, "rare", 2500),
    ("key", None, "rare", 1500),
    ("victorian_key", None, "rare", 2000),
    ("key__2_", None, "legendary", 2500),
    ("medieval_gold_key", None, "legendary", 2500),
    ("old_key", None, "legendary", 2500),  # opens the minigun
]
# source: the one mesh (by its glTF mesh name's start) that is the key.
MESH = {"key1": "Key_Padlock"}
REMESH = {"key__1_"}
# Bow came out at the bottom after standing up: turned over.
FLIP = {"key__2_", "key1"}
# Modelled lying diagonally: turned upright along their principal axis.
ALIGN = {"old_key"}


def load(folder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    glb = os.path.join(SRC, folder + ".glb")
    bpy.ops.import_scene.gltf(filepath=glb if os.path.exists(glb) else os.path.join(SRC, folder, "scene.gltf"))
    for o in list(bpy.context.scene.objects):
        if folder in MESH and o.type == "MESH" and not o.data.name.startswith(MESH[folder]):
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
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def weld(o):
    # Sketchfab exports are often triangle soup; weld so decimation has edges to collapse.
    # Then dissolve flat runs first: a long tube cut into hundreds of rings (key 3's shaft) keeps
    # its round section that way, where a straight collapse folds it into a line.
    bm = bmesh.new()
    bm.from_mesh(o.data)
    size = max(o.dimensions)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=size * 1e-4)
    bmesh.ops.dissolve_limit(bm, angle_limit=0.035, verts=bm.verts, edges=bm.edges, delimit={"UV"})
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()


def pick(o, index):
    # The pack: split into loose parts, then group parts whose x spans overlap into keys.
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [p for p in bpy.context.scene.objects if p.type == "MESH"]
    span = lambda p: (min(v.co.x for v in p.data.vertices), max(v.co.x for v in p.data.vertices))
    groups = []
    for p in sorted(parts, key=lambda p: span(p)[0]):
        if groups and span(p)[0] < groups[-1][1]:
            groups[-1][0].append(p)
            groups[-1][1] = max(groups[-1][1], span(p)[1])
        else:
            groups.append([[p], span(p)[1]])
    print("  pack groups", len(groups))
    keep = groups[index][0]
    for p in parts:
        if p not in keep:
            bpy.data.objects.remove(p)
    bpy.ops.object.select_all(action="DESELECT")
    for p in keep:
        p.select_set(True)
    bpy.context.view_layer.objects.active = keep[0]
    if len(keep) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


for rank, (folder, index, tier, budget) in enumerate(KEYS, 1):
    if rank not in ONLY:
        continue
    o = load(folder)
    weld(o)
    if index is not None:
        o = pick(o, index)
    if folder in REMESH:
        m = o.modifiers.new("remesh", "REMESH")
        m.mode = "VOXEL"
        m.voxel_size = max(o.dimensions) / 220.0
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if tris > budget:
        m = o.modifiers.new("decimate", "DECIMATE")
        m.ratio = budget / tris
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
    # stand every key up the same way: longest side along Blender Z (Godot Y)
    d = o.dimensions
    if d.x >= d.y and d.x >= d.z:
        o.data.transform(Matrix.Rotation(1.5708, 4, "Y"))
    elif d.y >= d.x and d.y >= d.z:
        o.data.transform(Matrix.Rotation(1.5708, 4, "X"))
    # a key lying diagonally in its plane (old_key): turn about the thin axis so the long axis
    # stands upright; of the two turns, keep the one that narrows the key most
    vs = [v.co for v in o.data.vertices]
    c = sum(vs, Vector()) / len(vs)
    thin = min(range(3), key=lambda i: max(v[i] for v in vs) - min(v[i] for v in vs))
    if folder in ALIGN and thin != 2:
        a = 3 - thin - 2  # the in-plane axis that is not Z
        saa = sum((v[a] - c[a]) ** 2 for v in vs)
        szz = sum((v.z - c.z) ** 2 for v in vs)
        saz = sum((v[a] - c[a]) * (v.z - c.z) for v in vs)
        tilt = 0.5 * math.atan2(2 * saz, szz - saa)
        if abs(tilt) > 0.1:
            width = lambda m: (lambda w: max(w) - min(w))([(m @ v)[a] for v in vs])
            turns = [Matrix.Rotation(t, 3, "XYZ"[thin]) for t in (tilt, -tilt)]
            o.data.transform(min(turns, key=width).to_4x4())
    # flat face toward Godot +Z: the thinnest side goes along Blender Y
    vs = [v.co for v in o.data.vertices]
    span = [max(v[i] for v in vs) - min(v[i] for v in vs) for i in range(3)]
    if span[0] < span[1]:
        o.data.transform(Matrix.Rotation(1.5708, 4, "Z"))
    if folder in FLIP:
        o.data.transform(Matrix.Rotation(3.14159265, 4, "Y"))
    o.data.update()
    # centre on the bounding box, longest side to TIERS length
    vs = [v.co for v in o.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    length, tex = TIERS[tier]
    s = length / max(hi - lo)
    o.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(-(lo + hi) / 2))
    for img in bpy.data.images:
        if img.size[0] > tex:
            img.scale(tex, tex)
    after = sum(len(p.vertices) - 2 for p in o.data.polygons)
    o.name = "Key"
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    path = os.path.join(OUT, "key_%02d.glb" % rank)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True)
    print("KEY %02d %s %s tris %d -> %d, %.0f mm, %s" % (rank, folder, tier, tris, after, length * 1000, os.path.getsize(path) // 1024), "KB")
