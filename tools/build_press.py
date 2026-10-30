# Blender (5.x, background): the press (Poly Haven drill_press_01, CC0; credits in docs/ayrintilar.md
# "Kullanılan asetler"). A bench-top drill press, 0.9 m, that the crew turned into their round press;
# it stands on the workshop bench's low stand (tools/range_dressing.gd _workshop).
#   press.glb: foot on the origin, the spindle's side toward glTF +Z. Its parts stay apart; the
#   feed handle ("Handle") has its origin on its hub, so turning it round its own x pulls the
#   spindle down. The body, lid and bit are thinned (~58K -> ~27K tris), textures cut to 2K.
# Run: blender -b --factory-startup -P tools/build_press.py -- <unzipped drill_press_01_4k.fbx dir> <out.glb>
import bpy, os, sys
from mathutils import Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
TEX = os.path.join(SRC, "textures", "drill_press_01_%s_4k.%s")
THIN = {"drill_press_01": 0.35, "drill_press_01_lid": 0.4, "drill_press_01_bit": 0.25,
        "drill_press_01_plug": 0.5, "drill_press_01_gear_a": 0.5, "drill_press_01_gear_b": 0.5}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(SRC, "drill_press_01_4k.fbx"))
for o in [o for o in bpy.data.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)


def image(kind, ext, colour):
    im = bpy.data.images.load(TEX % (kind, ext))
    im.scale(2048, 2048)
    im.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    im.pack()
    return im


m = bpy.data.materials.new("press")
m.use_nodes = True
nt = m.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
for kind, ext, colour, socket in [("diff", "jpg", True, "Base Color"), ("rough", "exr", False, "Roughness"),
                                  ("metal", "exr", False, "Metallic")]:
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = image(kind, ext, colour)
    nt.links.new(n.outputs["Color"], bsdf.inputs[socket])
nm = nt.nodes.new("ShaderNodeNormalMap")
n = nt.nodes.new("ShaderNodeTexImage")
n.image = image("nor_gl", "exr", False)
nt.links.new(n.outputs["Color"], nm.inputs["Color"])
nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])

for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    o.data.materials.clear()
    o.data.materials.append(m)
    bpy.context.view_layer.objects.active = o
    if o.name in THIN:
        d = o.modifiers.new("thin", "DECIMATE")
        d.ratio = THIN[o.name]
        bpy.ops.object.modifier_apply(modifier="thin")
    o.name = o.name.replace("drill_press_01_", "").replace("drill_press_01", "body").capitalize()

# The handle's hub: its spokes meet on the side of the head, where the handle is closest to the body.
h = bpy.data.objects["Handle"]
vs = [h.matrix_world @ v.co for v in h.data.vertices]
inner = min(v.x for v in vs)
hub = [v for v in vs if v.x < inner + 0.012]
hub = sum(hub, Vector()) / len(hub)
bpy.context.scene.cursor.location = hub
bpy.ops.object.select_all(action="DESELECT")
h.select_set(True)
bpy.context.view_layer.objects.active = h
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
print("handle hub", tuple(round(c, 3) for c in hub))
print("tris", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH"))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=88)
