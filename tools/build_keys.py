# Blender (5.x, background): the ten crate keys, from seven Sketchfab downloads (all CC-BY-4.0,
# credits in CLAUDE.md), cut down for a game: each key on its own, decimated to a triangle budget,
# textures shrunk, scaled to a length by tier and centred, written to <out>/key_NN.glb in rank
# order (common first). The "Keys" pack holds four keys in one mesh; they are split apart by
# position.
# Run: blender -b --factory-startup -P tools/build_keys.py -- <unzipped downloads dir> <out_dir>
#   <unzipped downloads dir> has one folder per zip (door_key, key, key__1_, key__2_, keys,
#   medieval_gold_key, victorian_key), each with its scene.gltf.
import bpy, bmesh, os, sys
from mathutils import Vector, Matrix

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(OUT, exist_ok=True)

# Long side of the finished key, m, and texture size, by tier.
TIERS = {"common": (0.08, 512), "rare": (0.10, 512), "legendary": (0.13, 1024)}
# rank: (folder, which key of a multi-key mesh counted left to right or None, tier, triangle budget)
# Key 3 has no textures (flat brown) and a shaft that is a broken, hundred-ring tube no decimator
# survives; it is voxel-remeshed into a clean shell first (REMESH).
KEYS = [
    ("door_key", None, "common", 1200),
    ("keys", 0, "common", 1200),
    ("key__1_", None, "common", 1200),  # REMESH
    ("keys", 3, "common", 1200),
    ("keys", 1, "rare", 1500),
    ("keys", 2, "rare", 1500),
    ("key", None, "rare", 1500),
    ("victorian_key", None, "rare", 2000),
    ("key__2_", None, "legendary", 2500),
    ("medieval_gold_key", None, "legendary", 2500),
]


REMESH = {"key__1_"}


def load(folder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, folder, "scene.gltf"))
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
