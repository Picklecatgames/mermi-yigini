# Blender (5.x, background): the house the user picked (2026-11-05), "Post-Apocalyptic | House | Dirty | Old |
# Wooden", yadrogames, Sketchfab, CC-BY 4.0: credits. Its source .blend and textures are in
# assets/props/house/source/. Its materials are rebuilt on their base colours (the file's graphs point at
# missing images), the ground decal goes, the door stands open, every window gets clean thin dirty glass in
# place of what filled it, so you see out (2026-11-05, the user). Walls, floor and ceiling are the model's own.
#   blender -b --factory-startup assets/props/house/source/Model.blend -P tools/build_house.py -- assets/props/house/source/textures assets/props/house/house.glb
# Output: metres, the room's floor a hair over the ground. World layout: tools/build_world.gd _house.
import bmesh, bpy, math, os, sys
from mathutils import Matrix, Vector

tex, out = sys.argv[sys.argv.index("--") + 1:]
SCALE = 1.65  # its door stands 1.2 over its floor in the file: 2 m here (build_world.gd HOUSE_SCALE)
SINK = 0.33  # its floor stands 0.21 up (x SCALE): down to the pad
GRID = 0.4  # file units, about 66 cm: the lit grid on the walls (below)
BASE = {"Elements": "Elements_base.png", "HouseEquip": "HouseEquip_base.png", "Roof": "Roof_base.png", "RoofSaver": "RoofSaver_base.png", "Wall": "WallDirty_base.png"}
scene = bpy.context.scene

for name in ("Plane", "DoorBlock", "Cube.005", "Cube.002_cell.010", "Cube.002_cell.002", "Cube.002_cell.003", "Cube.002_cell.006", "Cube.002_cell.007"):
    o = scene.objects.get(name)
    if o:
        bpy.data.objects.remove(o)  # the ground, a speck, what filled the windows
for o in list(scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)

for name, image in BASE.items():
    m = bpy.data.materials[name]
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    res = nt.nodes.new("ShaderNodeOutputMaterial")
    im = nt.nodes.new("ShaderNodeTexImage")
    im.image = bpy.data.images.load(os.path.abspath(os.path.join(tex, image)))
    nt.links.new(im.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], res.inputs["Surface"])
    m.blend_method = "OPAQUE"
glass = bpy.data.materials["Glass"]
glass.use_nodes = True
nt = glass.node_tree
nt.nodes.clear()
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
res = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(bsdf.outputs["BSDF"], res.inputs["Surface"])
bsdf.inputs["Base Color"].default_value = (0.42, 0.46, 0.4, 1.0)
bsdf.inputs["Alpha"].default_value = 0.2
bsdf.inputs["Roughness"].default_value = 0.35
glass.blend_method = "BLEND"


def pane(name, centre, size, axis):
    """A sheet of glass in a window's frame; `axis` is the way it faces."""
    mesh = bpy.data.meshes.new(name)
    a, b = size[0] / 2.0, size[1] / 2.0
    vs = [(0, -a, -b), (0, a, -b), (0, a, b), (0, -a, b)] if axis == "x" else [(-a, 0, -b), (a, 0, -b), (a, 0, b), (-a, 0, b)]
    mesh.from_pydata(vs, [], [(0, 1, 2, 3), (3, 2, 1, 0)])
    mesh.materials.append(glass)
    o = bpy.data.objects.new(name, mesh)
    o.location = centre
    scene.collection.objects.link(o)


pane("Glass_West1", (-3.255, 1.085, 1.095), (0.87, 0.87), "x")
pane("Glass_West2", (-3.255, 3.735, 1.095), (0.87, 0.87), "x")
pane("Glass_Wing", (1.895, 1.93, 1.095), (0.87, 0.87), "y")

# The door stands open, outwards: the leaf turned on its hinge (the end away from the handle).
door = scene.objects["Door"]
hinge = Vector((-1.39, -0.98, 0.0))
turn = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(105.0), 4, "Z") @ Matrix.Translation(-hinge)
bpy.context.view_layer.update()
door.matrix_world = turn @ door.matrix_world

# The walls, floor and ceiling cut into a grid: the PS1 shader lights per vertex, and a bulb's pool would
# fall between a big polygon's far corners, the room staying black under it.
wall = scene.objects["Wall"]
bm = bmesh.new()
bm.from_mesh(wall.data)
for axis in range(3):
    lo = min(v.co[axis] for v in bm.verts)
    hi = max(v.co[axis] for v in bm.verts)
    at = lo + GRID
    while at < hi:
        no = Vector((0, 0, 0))
        no[axis] = 1.0
        co = Vector((0, 0, 0))
        co[axis] = at
        bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), plane_co=co, plane_no=no, clear_inner=False, clear_outer=False, dist=1e-5)
        at += GRID
bmesh.ops.triangulate(bm, faces=bm.faces)
bm.to_mesh(wall.data)
print("WALL tris", len(bm.faces))
bm.free()

# All of it under one root, sized and sunk.
root = bpy.data.objects.new("House", None)
scene.collection.objects.link(root)
for o in scene.objects:
    if o is not root and o.parent is None:
        o.parent = root
root.scale = (SCALE, SCALE, SCALE)
root.location = (0, 0, -SINK)
bpy.context.view_layer.update()
for m in ("Dots Stroke", "Ground"):
    if m in bpy.data.materials:
        bpy.data.materials.remove(bpy.data.materials[m])
bpy.ops.export_scene.gltf(filepath=os.path.abspath(out), export_format="GLB", export_yup=True, export_apply=False, export_cameras=False, export_lights=False)
print("WROTE", out, "objects", len(scene.objects))
