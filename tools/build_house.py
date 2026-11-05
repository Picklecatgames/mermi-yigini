# Blender (5.x, background): makes the house a place you can walk into. The source is a closed village
# house ("Old russian house", Tim0, Sketchfab, CC-BY 4.0: credits): one-sided outer walls, flat glass,
# a door painted on the veranda. Out goes the door leaf and the glass, in goes the back door's hole;
# the walls' inside, floor and ceiling are tools/build_world.gd's (_house).
#   blender -b --factory-startup -P tools/build_house.py -- assets/props/house/old_russian_house.glb assets/props/house/house.glb
# Output, Blender Z-up as Godot exports it, metres, the ground at z 0: Roof, Walls, Windows.
import bpy, bmesh, sys
from mathutils import Vector

src, out = sys.argv[sys.argv.index("--") + 1:]
SCALE = 0.001  # the file's in mm
SINK = 0.30  # m: its floor stood on a plinth; sunk so the door's sill is at the ground (build_world.gd HOUSE_SINK)
# [lo, hi] boxes, source metres before the sink: the back door (towards the mountain), the way from the
# veranda into the house.
HOLES = [
    (Vector((-4.04, -4.85, -0.5)), Vector((-2.64, -4.4, 2.56))),
    (Vector((-0.14, 2.55, -0.5)), Vector((1.26, 2.85, 2.56))),
    (Vector((-4.4, -1.68, -0.5)), Vector((-4.0, -0.28, 2.56))),  # the way to the workshop wing (build_wing.py)
    (Vector((-0.12, 5.3, -0.5)), Vector((1.28, 5.7, 2.56))),  # the veranda's door, its frame with it: wide enough for two to pass (and build_world.gd's own frame)
]
# The veranda's door leaf, its frame and everything on it, in source metres.
LEAF = (Vector((-0.1, 5.39, 0.2)), Vector((1.2, 5.62, 2.7)))
NAMES = {"House_Roof": "Roof", "House_wall": "Walls", "House_Window": "Windows"}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.type != "MESH":
        continue
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
    bpy.context.view_layer.objects.active = o
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.transform(bm, matrix=mw, verts=bm.verts)
    for v in bm.verts:
        v.co *= SCALE
    # Parts cut loose by name of what they are, by where they stand.
    seen = set()
    kill = []
    glass = 0
    leaf = 0
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
        lo = Vector((min(q.co.x for q in vs), min(q.co.y for q in vs), min(q.co.z for q in vs)))
        hi = Vector((max(q.co.x for q in vs), max(q.co.y for q in vs), max(q.co.z for q in vs)))
        faces = set(f for q in vs for f in q.link_faces)
        size = hi - lo
        if o.data.materials[0].name == "House_Window":
            if all(lo[i] >= LEAF[0][i] and hi[i] <= LEAF[1][i] for i in range(3)):
                kill += vs
                leaf += 1
            elif len(faces) == 2 and min(size) < 0.005 and sorted(size)[1] > 0.9 and sorted(size)[2] > 1.2 and hi.z < 2.7 and lo.z > 1.1:
                kill += vs  # a pane of flat glass: open window
                glass += 1
    bmesh.ops.delete(bm, geom=list(set(kill)), context="VERTS")
    # The holes: cut along each side of the box, then drop what's in it.
    cut = 0
    if o.data.materials[0].name == "House_wall":
        for lo, hi in HOLES:
            for axis in range(3):
                for at in (lo[axis], hi[axis]):
                    no = Vector((0, 0, 0))
                    no[axis] = 1.0
                    co = Vector((0, 0, 0))
                    co[axis] = at
                    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
                    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_inner=False, clear_outer=False, dist=1e-5)
            dead = [f for f in bm.faces if all(lo[i] <= f.calc_center_median()[i] <= hi[i] for i in range(3))]
            cut += len(dead)
            bmesh.ops.delete(bm, geom=dead, context="FACES")
    for v in bm.verts:
        v.co.z -= SINK
    bm.to_mesh(o.data)
    bm.free()
    o.matrix_world.identity()
    o.name = NAMES[o.data.materials[0].name]
    o.data.name = o.name
    print("PART", o.name, "polys", len(o.data.polygons), "glass", glass, "leaf", leaf, "cut", cut)
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=False)
print("WROTE", out)
