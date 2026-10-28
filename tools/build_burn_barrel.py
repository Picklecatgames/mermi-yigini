# Blender (5.x, background): the rusty burn barrel in the workshop (docs/ayrintilar.md "Kullanılan
# asetler"), its firewood glowing on the grate. The model is in metres, its foot on the origin;
# textures cut to 1K. Its flames, sparks, smoke, light and crackle are scripts/barrel_fire.gd.
# Run: blender -b --factory-startup -P tools/build_burn_barrel.py -- <Rusty Burn Barrel.fbx> <out.glb>
import bpy, os, sys

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
TEX = os.path.join(os.path.dirname(os.path.dirname(SRC)), "textures")
# Material in the file -> its texture set's prefix (the sets are named in Russian).
SETS = {"Barrel": "Бочка", "Grate": "Колосник", "Hinge": "Петли", "Bolts": "Болты", "Burning Firewood": "1burn_wood"}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC)


def image(stem, kind, colour):
    for ext in (".png", ".jpg"):
        path = os.path.join(TEX, "%s_%s%s" % (stem, kind, ext))
        if os.path.exists(path):
            im = bpy.data.images.load(path)
            if im.size[0] > 1024:
                im.scale(1024, 1024)
            im.pack()
            if not colour:
                im.colorspace_settings.name = "Non-Color"
            return im
    return None


def material(name):
    stem = SETS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    def tex(kind, colour, socket):
        im = image(stem, kind, colour)
        if im:
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = im
            nt.links.new(n.outputs["Color"], socket)
        return im
    tex("BaseColor", True, bsdf.inputs["Base Color"])
    tex("Roughness", False, bsdf.inputs["Roughness"])
    tex("Metallic", False, bsdf.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    if tex("Normal", False, nm.inputs["Color"]):
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if tex("Emission", True, bsdf.inputs["Emission Color"]):  # the embers in the wood's cracks
        bsdf.inputs["Emission Strength"].default_value = 3.0
    return m


made = {}
parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in parts:
    for i, m in enumerate(o.data.materials):
        key = m.name.split(".")[0]
        if key not in made:
            made[key] = material(key)
        o.data.materials[i] = made[key]
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB")
