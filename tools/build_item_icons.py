# Blender (5.x, background): the item icons (assets/ui/items/*.png, UiStyle.item), rendered from the
# game's own models in a small studio light so they read as the things themselves, not flat
# silhouettes (2026-10-28, the user's call: game-icons.net's ingot and the like looked cheap). 256 px,
# transparent, three-quarter view from above, the long axis turned across the frame.
#   round: a 9 mm round (assets/bullet/bullet_9mm.glb)       rounds: three of them
#   clone: two 9 mm splaying out of one spot                  electric: the workbench's coiled .50 BMG
#   heavy: the workbench's .338 Lapua                         ingot: a brass ingot (modelled here)
#   melt: the hopper's crucible with its melt and the burner  press: the press (press.glb)
# Run: blender -b --factory-startup -P tools/build_item_icons.py -- <studio .hdr> [names...]
#   The .hdr is any studio HDRI (Poly Haven studio_small_09, CC0); it only lights the renders.
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:]
HDRI, ONLY = ARGS[0], ARGS[1:]
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "ui", "items")
SIZE = 256
VIEW = Vector((0.0, -1.0, 0.75)).normalized()  # from the front, above
ROLL = math.radians(-32)  # the long axis rises to the right


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    try:
        sc.eevee.use_raytracing = True
    except AttributeError:
        pass
    sc.view_settings.look = "AgX - Medium High Contrast" if "AgX - Medium High Contrast" in [i.identifier for i in bpy.types.ColorManagedViewSettings.bl_rna.properties["look"].enum_items] else sc.view_settings.look
    w = bpy.data.worlds.new("studio")
    w.use_nodes = True
    nt = w.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(HDRI)
    nt.links.new(env.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.8
    sc.world = w
    # A warm key from the top left, as the workshop's lamp, and a cool rim behind.
    for name, loc, energy, color in [("key", (-1.5, -1.2, 2.2), 260.0, (1.0, 0.86, 0.7)), ("rim", (1.4, 1.6, 1.4), 160.0, (0.7, 0.8, 1.0))]:
        l = bpy.data.lights.new(name, "AREA")
        l.energy = energy
        l.color = color
        l.size = 1.2
        o = bpy.data.objects.new(name, l)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(o)


def load(path, keep=None):
    """Imports a glb; with `keep`, only the meshes so named stay. Returns the meshes, unparented."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, path))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = []
    for o in new:
        if o.type == "MESH" and (keep is None or o.name in keep):
            meshes.append(o)
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in new:
        if o not in meshes:
            bpy.data.objects.remove(o)
    return meshes


def group(objs):
    """Parents `objs` under an empty at their middle; returns it."""
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    mid = sum(pts, Vector()) / len(pts)
    e = bpy.data.objects.new("item", None)
    bpy.context.scene.collection.objects.link(e)
    e.location = mid
    bpy.context.view_layer.update()
    for o in objs:
        mw = o.matrix_world.copy()
        o.parent = e
        o.matrix_world = mw
    return e


def lay_long_along_x(e, objs):
    """Turns the group so its longest side runs along x, lying down."""
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    size = [max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3)]
    axis = size.index(max(size))
    if axis == 1:
        e.rotation_euler.z += math.pi / 2
    elif axis == 2:
        e.rotation_euler.y += math.pi / 2
    bpy.context.view_layer.update()


def shoot(name, objs, margin=1.14, roll=ROLL, view=VIEW):
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    mid = sum(pts, Vector()) / len(pts)
    cam.location = mid + view * 10.0
    rot = view.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Rotation(roll, 4, "Z")
    cam.matrix_world = Matrix.Translation(cam.location) @ rot
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    local = [inv @ p for p in pts]
    xs, ys = [p.x for p in local], [p.y for p in local]
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    cam.matrix_world = cam.matrix_world @ Matrix.Translation((cx, cy, 0))
    cam.data.ortho_scale = max(max(xs) - min(xs), max(ys) - min(ys)) * margin
    cam.data.clip_end = 100.0
    sc.camera = cam
    os.makedirs(OUT, exist_ok=True)
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("icon", name)


def nine_mm():
    objs = load("assets/bullet/bullet_9mm.glb")
    e = group(objs)
    lay_long_along_x(e, objs)
    return e, objs


def icon_round():
    fresh()
    e, objs = nine_mm()
    shoot("round", objs)


def icon_rounds():
    fresh()
    all_ = []
    for k in range(3):
        e, objs = nine_mm()
        size = max(max((o.matrix_world @ Vector(c))[i] for o in objs for c in o.bound_box) - min((o.matrix_world @ Vector(c))[i] for o in objs for c in o.bound_box) for i in range(3))
        e.location += Vector((k * size * 0.12, k * size * 0.42, 0.0))
        all_ += objs
    bpy.context.view_layer.update()
    shoot("rounds", all_)


def icon_clone():
    fresh()
    all_ = []
    for k, ang in enumerate([-24, 24]):
        e, objs = nine_mm()
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        length = max(p.x for p in pts) - min(p.x for p in pts)
        # From one base, the two splay apart like the shot splitting.
        e.location = Vector((length * 0.5 * math.cos(math.radians(ang)), length * 0.5 * math.sin(math.radians(ang)), 0))
        e.rotation_euler.z += math.radians(ang)
        all_ += objs
    bpy.context.view_layer.update()
    shoot("clone", all_, 1.12, math.radians(-8), Vector((0.0, -0.45, 1.0)).normalized())  # from above: the V shows


def icon_from_bench(name, keep):
    fresh()
    objs = load("assets/props/workbench/workbench.glb", keep)
    e = group(objs)
    lay_long_along_x(e, objs)
    bpy.context.view_layer.update()
    shoot(name, objs)


def icon_ingot():
    fresh()
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= 1.0
        v.co.y *= 0.46
        v.co.z *= 0.26
        if v.co.z > 0:  # cast in a mould: the top narrower than the foot
            v.co.x *= 0.84
            v.co.y *= 0.74
    me = bpy.data.meshes.new("ingot")
    bm.to_mesh(me)
    o = bpy.data.objects.new("ingot", me)
    bpy.context.scene.collection.objects.link(o)
    bev = o.modifiers.new("bevel", "BEVEL")
    bev.width = 0.035
    bev.segments = 4
    m = bpy.data.materials.new("brass")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.92, 0.56, 0.17, 1)
    bsdf.inputs["Metallic"].default_value = 1.0
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 18.0
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["To Min"].default_value = 0.22
    ramp.inputs["To Max"].default_value = 0.42
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Value"])
    nt.links.new(ramp.outputs["Result"], bsdf.inputs["Roughness"])  # cast, a little mottled
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.08
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    me.materials.append(m)
    bpy.context.view_layer.update()
    shoot("ingot", [o], roll=math.radians(-20))


def icon_melt():
    fresh()
    keep = {"Hopper_crucible", "Hopper_molten", "Hopper_burner", "Hopper_flame", "Hopper_stand"}
    objs = load("assets/props/workbench/hopper.glb", keep)
    for o in objs:  # in the studio light the melt's own glow burns white: molten orange, not milk
        for m in o.data.materials:
            b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.use_nodes else None
            if b and b.inputs["Emission Strength"].default_value > 0:
                for link in list(b.inputs["Emission Color"].links):
                    m.node_tree.links.remove(link)
                b.inputs["Emission Color"].default_value = (1.0, 0.36, 0.05, 1.0)
                b.inputs["Base Color"].default_value = (0.04, 0.01, 0.0, 1.0)  # all its colour its own glow
                b.inputs["Emission Strength"].default_value = 0.45  # AgX bleaches anything brighter to peach
                b.inputs["Roughness"].default_value = 1.0
                b.inputs["Specular IOR Level"].default_value = 0.0  # no studio sky mirrored on it
    shoot("melt", objs, 1.16, 0.0, Vector((0.0, -1.0, 0.8)).normalized())


def icon_press():
    fresh()
    objs = load("assets/props/press/press.glb")
    shoot("press", objs, 1.1, 0.0, Vector((0.55, -1.0, 0.45)).normalized())


ICONS = {"round": icon_round, "rounds": icon_rounds, "clone": icon_clone,
         "electric": lambda: icon_from_bench("electric", {"R_bmg", "R_coil_on_bmg"}),
         "heavy": lambda: icon_from_bench("heavy", {"R_lapua"}), "ingot": icon_ingot, "melt": icon_melt,
         "press": icon_press}
for n, f in ICONS.items():
    if not ONLY or n in ONLY:
        f()
print("ok", OUT)
