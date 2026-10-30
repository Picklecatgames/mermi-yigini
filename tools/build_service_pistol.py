# Builds assets/weapons/service_pistol/service_pistol.glb: the starting pistol (Poly Haven "Service
# Pistol", CC0), cut into the parts the Deagle's first-person clips move, so it plays every Deagle
# clip on the same arms (scripts/viewmodel.gd SETS "pistol", add_pistol). The download has the gun
# twice: "a" with wooden grips (the bench's upgrade) and "b" with its grip taped up in blue (what
# the table gives); their slides and hammers are the same. Each part is moved into the Deagle's
# "Weapon" bone space (y up, barrel +z, metres): the point between hammer and trigger on the
# Deagle's, which also puts the bore 1 mm and the grip's foot 5 mm off the Deagle's.
# The loaded magazine lies 10 cm behind the grip in the download; it goes into the well.
# Run: blender -b --factory-startup --disable-autoexec -P tools/build_service_pistol.py -- <unzipped dir> <out.glb>
import bpy, os, sys
from mathutils import Matrix

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
TEX = 2048  # 4K in the download; the gun never fills more than half the screen

# Download name -> ours. Ours are what scripts/viewmodel.gd looks for.
PARTS = {
    "service_pistol_pistol_a": "frame_wood", "service_pistol_pistol_b": "frame_tape",
    "service_pistol_trigger_a": "trigger_wood", "service_pistol_trigger_b": "trigger_tape",
    "service_pistol_slide_a": "slide", "service_pistol_hammer_a": "hammer",
    "service_pistol_magazine_loaded": "magazine",
}
ROW_B = 0.15  # m: the "b" gun stands this far above the "a" one
MAG_IN = 0.1  # m forward into the well
# Blender (x forward, z up) -> the Deagle's Weapon bone as glTF writes it (y up, +z forward):
# a quarter turn about z, then the hammer-trigger midpoint (x 0.0105, z 0.041) onto the
# Deagle's (z -0.075, y -0.014).
FIT = Matrix.Translation((0.0, 0.0855, -0.055)) @ Matrix.Rotation(-1.5707963, 4, "Z")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(src, "service_pistol_4k.fbx"))
bpy.context.view_layer.update()
for o in list(bpy.data.objects):
    if o.name not in PARTS:
        bpy.data.objects.remove(o)
        continue
    m = o.matrix_world.copy()
    if o.name.endswith("_b"):
        m = Matrix.Translation((0.0, 0.0, -ROW_B)) @ m
    if o.name == "service_pistol_magazine_loaded":
        m = Matrix.Translation((MAG_IN, 0.0, 0.0)) @ m
    o.data = o.data.copy()  # a and b may share data
    o.data.transform(FIT @ m)
    o.parent = None
    o.matrix_world = Matrix.Identity(4)
    o.name = o.data.name = PARTS[o.name]


def image(name, color):
    img = bpy.data.images.load(os.path.join(src, "textures", name))
    if not color:
        img.colorspace_settings.name = "Non-Color"
    img.scale(TEX, TEX)
    img.file_format = "PNG"
    return img


mat = bpy.data.materials["service_pistol"]
mat.use_nodes = True
nt = mat.node_tree
nt.nodes.clear()
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
nt.links.new(bsdf.outputs["BSDF"], nt.nodes.new("ShaderNodeOutputMaterial").inputs["Surface"])


def tex(name, color):
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = image(name, color)
    return n


nt.links.new(tex("service_pistol_diff_4k.jpg", True).outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(tex("service_pistol_metal_4k.exr", False).outputs["Color"], bsdf.inputs["Metallic"])
nt.links.new(tex("service_pistol_rough_4k.exr", False).outputs["Color"], bsdf.inputs["Roughness"])
nm = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(tex("service_pistol_nor_gl_4k.exr", False).outputs["Color"], nm.inputs["Color"])
nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])

os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=False,
    export_image_format="AUTO", export_cameras=False, export_lights=False, export_animations=False)
print("pistol built:", sorted(o.name for o in bpy.data.objects))
