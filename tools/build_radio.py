# Blender (5.x, background): the crew's 1967 Soviet radio on the workshop bench's shelf, from the
# "Radio from the USSR 1967" download (credits in docs/ayrintilar.md). The FBX comes without
# materials wired up; its two texture sets (Big: the case, Small: the knob and trim) are hooked up
# here and shrunk to 1K (the set is 27 cm wide), then it goes out as one glb.
#   radio.glb: centred, bottom on the origin, dial toward glTF +Z.
# Run: blender -b --factory-startup -P tools/build_radio.py -- <pack dir> <out dir>
#   <pack dir> is the unzipped download (source/*.fbx, textures/*.png).
import bpy, os, sys, glob
from mathutils import Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(OUT, exist_ok=True)
TEX = os.path.join(SRC, "textures", "SM_USSR_Radio_Mid_%s_%s.png")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=glob.glob(os.path.join(SRC, "source", "*.fbx"))[0])
for o in [o for o in bpy.data.objects if o.type != "MESH"]:  # the Cinema 4D camera
    bpy.data.objects.remove(o)


def image(set_name, kind, colour):
    img = bpy.data.images.load(TEX % (set_name, kind))
    if img.size[0] > 1024:
        img.scale(1024, 1024)
    img.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    return img


for name in ("Big", "Small"):
    mat = bpy.data.materials[name]
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for kind, socket, colour in (("BaseColor", "Base Color", True), ("Metallic", "Metallic", False),
                                 ("Roughness", "Roughness", False)):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = image(name, kind, colour)
        nt.links.new(t.outputs["Color"], bsdf.inputs[socket])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = image(name, "Normal", False)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(t.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])

# Bake the FBX's cm scale and quarter turn into the vertices, then centre on X/Y, bottom on Z 0.
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector(tuple(min(c[i] for c in corners) for i in range(3)))
hi = Vector(tuple(max(c[i] for c in corners) for i in range(3)))
shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for o in meshes:
    o.location -= shift
print("radio size", tuple(round(v, 3) for v in hi - lo))

bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "radio.glb"), export_format="GLB",
                          use_selection=True, export_yup=True, export_image_format="JPEG", export_jpeg_quality=90)
