# Blender (5.x, background): the old scissor-arm U-boat lamp on the wall over the workshop bench
# (docs/ayrintilar.md "Kullanılan asetler"), its bulb glowing warm. Scaled by SCALE, the origin the
# middle of its wall plate's back, the arm reaching glTF +Z off the wall. Prints the bulb's place for
# range_dressing.gd's light.
# Run: blender -b --factory-startup -P tools/build_wall_lamp.py -- <uboat_nav_lamp.obj> <textures dir> <out.glb>
import bpy, glob, os, sys
from mathutils import Matrix, Vector

SRC, TEXDIR, OUT = sys.argv[sys.argv.index("--") + 1:][:3]
SCALE = 0.16  # the model is in decimetres and then some: a 30 cm shade
REACH = 0.73  # m from the wall to the shade's middle: over the middle of the bench's free top (front 26.85, shelves from 27.6)
ARM_END = -3.2  # the model's pantograph ends here (y), where the shade's hull hangs from it
GLOW = (1.0, 0.62, 0.28, 1)  # the bulb, as its light (range_dressing.gd)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=SRC)  # Y up in the file: Blender turns it Z up, the wall plate at +Y


def image(path, colour):
    im = bpy.data.images.load(path)
    if im.size[0] > 1024:
        im.scale(1024, 1024)
    im.pack()
    if not colour:
        im.colorspace_settings.name = "Non-Color"
    return im


def material(name):
    """name: the OBJ's material, e.g. Lamp_Hull_M; its textures are uboat_nav_lamp_<name>_<kind>,
    the kind cut short in the file names."""
    m = bpy.data.materials.new("UBoat_" + name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    def tex(kind):
        hits = glob.glob(os.path.join(TEXDIR, "uboat_nav_lamp_%s_%s*.png" % (name, kind[:5])))
        return hits[0] if hits else None
    for kind, socket, colour in (("BaseColor", "Base Color", True), ("Roughness", "Roughness", False), ("Metallic", "Metallic", False)):
        if tex(kind):
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = image(tex(kind), colour)
            nt.links.new(n.outputs["Color"], bsdf.inputs[socket])
    if tex("Normal"):
        nm = nt.nodes.new("ShaderNodeNormalMap")
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = image(tex("Normal"), False)
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if name == "Bulb_Glass_M":
        bsdf.inputs["Base Color"].default_value = GLOW
        bsdf.inputs["Emission Color"].default_value = GLOW
        bsdf.inputs["Emission Strength"].default_value = 8.0
    return m


parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
made = {}
for o in parts:
    for i, m in enumerate(o.data.materials):
        key = m.name.split(".")[0]
        if key not in made:
            made[key] = material(key)
        o.data.materials[i] = made[key]
box = lambda o: [o.matrix_world @ Vector(c) for c in o.bound_box]
# Draw the arm out: the pantograph (and its wire) stretches along the reach and narrows as it does,
# the way a scissor arm flattens; the shade and what hangs on it slide out with its end.
shade_y = sum(box(next(o for o in parts if o.name.startswith("Lamp_Hull"))), Vector()).y / 8
stretch = (-REACH / SCALE - shade_y + ARM_END) / ARM_END  # end moves from ARM_END to ARM_END * stretch
for o in parts:
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix()
    if o.name.startswith(("Pantograph_Screws", "Pantograph_Segment", "Wire")):
        for v in o.data.vertices:
            if v.co.y < 0:
                v.co.y *= stretch
                v.co.z /= stretch ** 0.5
    elif not o.name.startswith(("Mount_Plate", "Pantograph_MP_Mount")):
        o.data.transform(Matrix.Translation((0, ARM_END * (stretch - 1), 0)))
    o.data.update()
bpy.context.view_layer.update()  # or the bounding boxes below are the ones from before
plate = box(next(o for o in parts if o.name.startswith("Mount_Plate")))
back = Vector((0, max(v.y for v in plate), 0))
bulb = box(next(o for o in parts if o.name.startswith("Bulb")))
bulb_at = sum(bulb, Vector()) / 8
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
lamp = bpy.context.view_layer.objects.active
lamp.name = "WallLamp"
lamp.data.transform(Matrix.Scale(SCALE, 4) @ Matrix.Translation(-back))
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB")
g = (bulb_at - back) * SCALE  # glTF is Y up: Blender (x, y, z) is glTF (x, z, -y)
print("bulb at (%.3f, %.3f, %.3f)" % (g.x, g.z, -g.y))
