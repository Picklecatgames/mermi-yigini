# Blender (5.x, background): the investigation board in the workshop (docs/ayrintilar.md "Kullanılan
# asetler"), made free-standing: the Sketchfab model hangs on a wall, so two rusty steel L feet are
# added, one at each side: a post up the board's edge and a foot running back along the floor.
# The board faces glTF +X, centred on the origin across its width, the feet's soles on the floor.
# Run: blender -b --factory-startup -P tools/build_board.py -- <Board.fbx> <textures dir> <out.glb> <Applique.fbx>
import bpy, math, os, sys
from mathutils import Matrix, Vector

SRC, TEXDIR, OUT, LIGHT = sys.argv[sys.argv.index("--") + 1:][:4]
RUST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "props", "workbench", "hopper_rusty_metal_02_")
POST = 0.045  # steel square tube, m
FOOT = 0.6    # how far the foot runs back behind the board
RUSTED = 0.9  # the feet's paint is gone on the reddest tenth of the rust scan

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC)
parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
# The backing is the widest part; some photos are pinned hanging over its edges.
back = max(parts, key=lambda p: p.dimensions.x * p.dimensions.y * p.dimensions.z + max(p.dimensions))
bw = [back.matrix_world @ Vector(c) for c in back.bound_box]
blo = Vector([min(v[i] for v in bw) for i in range(3)])
bhi = Vector([max(v[i] for v in bw) for i in range(3)])


def image(path, colour, size):
    im = bpy.data.images.load(path)
    if im.size[0] > size:
        im.scale(size, size)
    im.pack()
    if not colour:
        im.colorspace_settings.name = "Non-Color"
    return im


def material(name, base, rough, normal, metal):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    def tex(im):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = im
        return n
    nt.links.new(tex(base).outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex(rough).outputs["Color"], bsdf.inputs["Roughness"])
    if isinstance(metal, float):
        bsdf.inputs["Metallic"].default_value = metal
    else:
        nt.links.new(tex(metal).outputs["Color"], bsdf.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex(normal).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return m


# The board: one atlas for every part (the fbx carries no material). Base colour kept at 4K for the
# photos' sake, the rest at 2K.
t = lambda k: os.path.join(TEXDIR, "DefaultMaterial_%s.png" % k)
board = material("Board", image(t("Base_color"), True, 4096), image(t("Roughness"), False, 2048),
                 image(t("Normal_OpenGL"), False, 2048), image(t("Metallic"), False, 2048))
for o in parts:
    o.data.materials.clear()
    o.data.materials.append(board)
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
o = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
o.name = "Board"

# Centre it: the backing's back face on x = 0, the middle of its width on y = 0. The height stays as
# modelled (bottom edge 0.88 m, top 2.05 m), a comfortable read standing.
o.data.transform(Matrix.Translation(Vector((-blo.x, -(blo.y + bhi.y) / 2, 0))))
half = (bhi.y - blo.y) / 2
top = bhi.z
thick = bhi.x - blo.x

# The feet: each a post along the backing's edge, its front flush with the backing's so the photos
# hanging over the edge pass in front, a little past the top; and a foot back along the floor from
# the post; together an L seen from the side. Black painted steel, rust showing only where the scan
# is most rusted (its reddest patches). UVs box-projected at 0.5 m a tile.
def painted(diff, rough):
    import numpy as np
    rough.scale(*diff.size)
    d = np.array(diff.pixels[:]).reshape(-1, 4)
    r = np.array(rough.pixels[:]).reshape(-1, 4)[:, 0]
    red = d[:, 0] - d[:, 2]
    lo, hi = np.quantile(red, [RUSTED, RUSTED + (1 - RUSTED) / 2])
    rust = np.clip((red - lo) / (hi - lo), 0, 1)[:, None]
    paint = 0.025 + 0.03 * d[:, :3].mean(1, keepdims=True)  # a little wear in the black
    d[:, :3] = paint * (1 - rust) + d[:, :3] * 0.6 * rust
    r = 0.5 * (1 - rust[:, 0]) + r * rust[:, 0]
    # New images: repacking the loaded ones would ship the untouched jpg.
    def baked(name, px, colour):
        im = bpy.data.images.new(name, *diff.size)
        if not colour:
            im.colorspace_settings.name = "Non-Color"
        im.pixels.foreach_set(px.ravel().astype(np.float32))
        im.pack()
        return im
    return (baked("feet_diff", d, True),
            baked("feet_rough", np.column_stack([r, r, r, np.ones_like(r)]), False))
steel = painted(image(RUST + "diff.jpg", True, 2048), image(RUST + "rough.jpg", False, 2048))
rust = material("PaintedSteel", steel[0], steel[1], image(RUST + "nor.jpg", False, 2048), 0.3)
def bar(name, a, b):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(a + b) / 2)
    c = bpy.context.active_object
    c.name = name
    c.scale = b - a
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=0.5, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    c.data.materials.append(rust)
front = thick
for s in (-1, 1):
    y0, y1 = sorted((s * half, s * (half + POST)))
    bar("Post", Vector((front - POST, y0, 0)), Vector((front, y1, top + 0.04)))
    bar("Foot", Vector((front - FOOT, y0, 0)), Vector((front - POST, y1, POST)))

# A picture light over the top edge (the user's "Wall Lamp", Applique.fbx, docs/ayrintilar.md
# "Kullanılan asetler"): its wall plate on the frame, the bar out over the board on its two arms,
# the strip under the bar glowing FLUO, the colour range_dressing.gd _workshop gives the board's spots.
FLUO = (0.82, 0.93, 1.0)
SPAN = 0.4125  # half the bar: the size the fitting before it was given (the user's call)
def flat(name, colour, metal, rough, glow=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = colour + (1,)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if glow:
        bsdf.inputs["Emission Color"].default_value = FLUO + (1,)
        bsdf.inputs["Emission Strength"].default_value = glow
    return m
LAMP_MATS = {"Metal": flat("LampBrass", (0.16, 0.12, 0.07), 0.85, 0.45),  # old darkened brass
             "Plastic": flat("LampSwitch", (0.02, 0.02, 0.02), 0.0, 0.6),
             "Emissive": flat("LampStrip", FLUO, 0.0, 0.5, 5.0)}
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.import_scene.fbx(filepath=LIGHT)
kept = [o for o in bpy.context.selected_objects if o.type == "MESH"]
for o in kept:
    for i, m in enumerate(o.data.materials):
        o.data.materials[i] = LAMP_MATS[m.name.split(".")[0]]
bpy.ops.object.select_all(action="DESELECT")
for o in kept:
    o.select_set(True)
bpy.context.view_layer.objects.active = kept[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bar = next(o for o in kept if o.name.startswith("BigPart"))
reach = max((bar.matrix_world @ Vector(c)).x for c in bar.bound_box)  # half the bar
plate = next(o for o in kept if o.name.startswith("Support"))
pb = [plate.matrix_world @ Vector(c) for c in plate.bound_box]
wall = Vector((0, max(v.y for v in pb), (min(v.z for v in pb) + max(v.z for v in pb)) / 2))  # the plate's wall side
bpy.ops.object.join()
lamp = bpy.context.view_layer.objects.active
lamp.name = "Lamp"
# The model's wall is +Y, its bar along X, the strip facing -Z: turned so the wall is the board's
# front, the bar along its width, the plate's middle 4 cm under the board's top edge.
k = SPAN / reach
lamp.data.transform(Matrix.Translation(Vector((front, 0, top - 0.04))) @ Matrix.Rotation(math.radians(90), 4, "Z")
                    @ Matrix.Scale(k, 4) @ Matrix.Translation(-wall))
print("picture light: bar %.3f out, %.3f high" % (wall.y * k, top - 0.04 - wall.z * k))

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB")
print("board %s: %.2f m wide, %.3f thick, %.2f to %.2f m high" % (back.name, 2 * half, thick, blo.z, top))
