# Blender (5.x, background): the boss's desk corner and the hall's lamps, from the "Mafia Office
# Asset Pack" download (credits in docs/ayrintilar.md). The pack is one FBX whose parts all share one
# baked 4K texture set; each part we use goes out as its own glTF next to the shared textures.
#   desk.gltf, chair.gltf, safe.gltf: the desk with what lies on it (no gun, hat or money), its
#     armchair and the safe beside it, all in the desk's frame: placed at one transform they stand
#     as the pack set them. Centred on the desk, bottom on the origin, visitor side toward glTF +Z.
#   cash_bundle.gltf: one strapped bundle of notes, long side along glTF Z, centred, bottom on the
#     origin. The game stacks these on the desk by the player's gold (scripts/money_pile.gd).
#   ceiling_lamp.gltf: the enamel pendant on its rod, origin at the rod's top.
#   tripod_light.gltf: the two-head flood on a tripod, origin at the mast's foot, lenses toward +Z.
# Run: blender -b --factory-startup -P tools/build_office.py -- <pack dir> <out dir>
#   <pack dir> is the unzipped download (source/*.fbx, textures/*.png).
import bpy, math, os, sys, glob
from mathutils import Matrix, Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(OUT, exist_ok=True)

# The pack's parts by what they are (its own names are Plane.0xx).
DESK = ["Plane.003", "Plane.007", "Plane.009", "Plane.014", "Plane.015", "Plane.017", "Plane.018",
        "Plane.019", "Plane.020", "Plane.021", "Plane.022", "Plane.023"]
CHAIR = ["Plane.005"]
SAFE = ["Plane.012"]
LAMP = "Plane.011"
TRIPOD = "Plane.006"
CASH = "Plane.024"  # the bundles on the desk; one is kept as the stacking piece
# Left out: Plane.001 the hat, Plane.010 the Thompson, Plane.013 the revolver, Plane.016 the money
# on the safe.

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=glob.glob(os.path.join(SRC, "source", "*.fbx"))[0])

# Off the armature into world space, transforms applied.
for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    mw = o.matrix_world.copy()
    o.parent = None
    o.data.transform(mw)
    o.matrix_world = Matrix()
for o in [o for o in bpy.data.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)

# One material over the baked set.
tex = os.path.join(SRC, "textures", "Plane.001_Bake1_PBR_")
mat = bpy.data.materials.new("office")
mat.use_nodes = True
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")


def image(kind, colour):
    img = bpy.data.images.load(tex + kind + ".png")
    img.name = "office_" + kind.lower()
    if not colour:
        img.colorspace_settings.is_data = True
    if kind in ("Metalness", "Roughness"):
        img.scale(2048, 2048)  # flat-ish maps: half size is plenty
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    return node


nt.links.new(image("Diffuse", True).outputs[0], bsdf.inputs["Base Color"])
nt.links.new(image("Metalness", False).outputs[0], bsdf.inputs["Metallic"])
nt.links.new(image("Roughness", False).outputs[0], bsdf.inputs["Roughness"])
nmap = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(image("Normal", False).outputs[0], nmap.inputs["Color"])
nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
for o in bpy.data.objects:
    o.data.materials.clear()
    o.data.materials.append(mat)


def bounds(objs):
    pts = [v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def export(names, xf, out_name):
    objs = [bpy.data.objects[n] for n in names]
    for o in objs:
        o.data.transform(xf)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, out_name), export_format="GLTF_SEPARATE",
                              use_selection=True, export_image_format="JPEG", export_jpeg_quality=90,
                              export_yup=True, export_apply=True)
    lo, hi = bounds(objs)
    print("OUT", out_name, "min", tuple(round(v, 3) for v in lo), "max", tuple(round(v, 3) for v in hi))


# The desk's frame: centre of the desk top, floor level; its visitor side (+X in the pack) turned
# to -Y, which glTF's Y-up turn makes +Z.
lo, hi = bounds([bpy.data.objects["Plane.003"]])
desk_xf = Matrix.Rotation(-math.pi / 2, 4, "Z") @ Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, 0)))
export(DESK, desk_xf, "desk.gltf")
export(CHAIR, desk_xf, "chair.gltf")
export(SAFE, desk_xf, "safe.gltf")

# One bundle: split the desk's money into loose parts, take the straightest note block and the
# paper band round it, turn it square (the pack laid it a little askew) with its long side along -Y
# (glTF +Z).
cash = bpy.data.objects[CASH]
bpy.ops.object.select_all(action="DESELECT")
cash.select_set(True)
bpy.context.view_layer.objects.active = cash
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="LOOSE")
bpy.ops.object.mode_set(mode="OBJECT")
parts = list(bpy.context.selected_objects)
blocks = [p for p in parts if len(p.data.polygons) > 40]


def footprint(objs, a):
    r = Matrix.Rotation(a, 4, "Z")
    pts = [r @ v.co for o in objs for v in o.data.vertices]
    return (max(p.x for p in pts) - min(p.x for p in pts)) * (max(p.y for p in pts) - min(p.y for p in pts))


block = min(blocks, key=lambda p: min(footprint([p], math.radians(a)) for a in range(-20, 21)))
c = (bounds([block])[0] + bounds([block])[1]) / 2
band = min([p for p in parts if p not in blocks],
           key=lambda p: ((bounds([p])[0] + bounds([p])[1]) / 2 - c).length)
pair = [block, band]
turn = min((math.radians(a * 0.5) for a in range(-40, 41)), key=lambda a: footprint(pair, a))
r = Matrix.Rotation(turn, 4, "Z")
lo, hi = bounds(pair)
xf = r @ Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z)))
for o in pair:
    o.data.transform(xf)
lo, hi = bounds(pair)
if hi.x - lo.x > hi.y - lo.y:  # long side to Y
    for o in pair:
        o.data.transform(Matrix.Rotation(math.pi / 2, 4, "Z"))
bpy.ops.object.select_all(action="DESELECT")  # one mesh: the game draws it as a MultiMesh
for o in pair:
    o.select_set(True)
bpy.context.view_layer.objects.active = block
bpy.ops.object.join()
block.name = "cash_bundle"
export([block.name], Matrix(), "cash_bundle.gltf")

# The pendant: origin at the top of its rod.
lo, hi = bounds([bpy.data.objects[LAMP]])
export([LAMP], Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, hi.z))), "ceiling_lamp.gltf")

# The tripod: origin at the mast's foot (the mast is the narrow run between the legs and the heads).
t = bpy.data.objects[TRIPOD]
mast = [v.co for v in t.data.vertices if 0.7 < v.co.z < 1.6]
foot = Vector((sum(p.x for p in mast) / len(mast), sum(p.y for p in mast) / len(mast), 0))
export([TRIPOD], Matrix.Translation(-foot), "tripod_light.gltf")
# Each head's lens (front face, -Y here) in glTF terms, for the game's glow and spot.
heads = [v.co for v in t.data.vertices if v.co.z > 2.1]
for side in (-1, 1):
    h = [p for p in heads if (p.x > 0) == (side > 0)]
    lo = Vector((min(p.x for p in h), min(p.y for p in h), min(p.z for p in h)))
    hi = Vector((max(p.x for p in h), max(p.y for p in h), max(p.z for p in h)))
    print("HEAD", side, "centre (gltf x,y,z)", round((lo.x + hi.x) / 2, 3), round((lo.z + hi.z) / 2, 3), round(-lo.y, 3),
          "size", round(hi.x - lo.x, 3), round(hi.z - lo.z, 3))
