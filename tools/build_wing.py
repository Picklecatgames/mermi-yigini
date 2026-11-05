# Blender (5.x, background): the house's workshop wing, out of a real shed ("Caretaker shack", Tim0,
# Sketchfab, CC-BY 4.0: credits). Its door leaf goes, a way through to the house is cut in its long wall;
# the wall lining, floor and ceiling are tools/build_world.gd's (_house).
#   blender -b --factory-startup -P tools/build_wing.py -- assets/props/house/caretaker_shack.glb assets/props/house/wing.glb
# Output, metres, the ground at z 0, build_world.gd WING_AT turns it. Made 1.2 x its size (the bench's 4 m fit its width that way).
import bpy, bmesh, sys
from mathutils import Vector

src, out = sys.argv[sys.argv.index("--") + 1:]
# The file is in cm.
SINK = 0.15  # m: its door's sill at the ground (build_world.gd WING_AT)
# Source metres before the 1.2: the way through to the house.
HOLE = (Vector((1.65, -0.19, -0.5)), Vector((1.9, 0.97, 2.0)))
LEAF = (Vector((-0.02, -2.6, 0.1)), Vector((1.21, -2.55, 2.25)))  # the door leaf, in its frame

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.type != "MESH":
        continue
    if not o.data.materials:  # a leftover speck in the file
        bpy.data.objects.remove(o)
        continue
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.transform(bm, matrix=mw, verts=bm.verts)
    for v in bm.verts:
        v.co *= 0.01
    cut = 0
    if o.data.materials[0].name == "Down":
        seen = set()
        kill = []
        for v0 in bm.verts:
            if v0 in seen:
                continue
            stack = [v0]
            seen.add(v0)
            vs = []
            while stack:
                x = stack.pop()
                vs.append(x)
                for e in x.link_edges:
                    y = e.other_vert(x)
                    if y not in seen:
                        seen.add(y)
                        stack.append(y)
            if all(LEAF[0][i] <= q.co[i] <= LEAF[1][i] for q in vs for i in range(3)):
                kill += vs
        bmesh.ops.delete(bm, geom=list(set(kill)), context="VERTS")
        lo, hi = HOLE
        for axis in range(3):
            for at in (lo[axis], hi[axis]):
                no = Vector((0, 0, 0))
                no[axis] = 1.0
                co = Vector((0, 0, 0))
                co[axis] = at
                bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), plane_co=co, plane_no=no, clear_inner=False, clear_outer=False, dist=1e-5)
        dead = [f for f in bm.faces if all(lo[i] <= f.calc_center_median()[i] <= hi[i] for i in range(3))]
        cut = len(dead)
        bmesh.ops.delete(bm, geom=dead, context="FACES")
        print("LEAF verts", len(set(kill)))
    for v in bm.verts:
        v.co *= 1.2
        v.co.z -= SINK
    bm.to_mesh(o.data)
    bm.free()
    o.matrix_world.identity()
    print("PART", o.name, "polys", len(o.data.polygons), "cut", cut)
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=False)
print("WROTE", out)
