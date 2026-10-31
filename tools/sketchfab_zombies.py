# Blender (5.x, background): the Sketchfab zombies (docs/ayrintilar.md, "Kullanılan asetler") from the
# zips' source/ + textures/ folders into glb, textures wired by name and embedded.
#   blender -b --factory-startup -P tools/sketchfab_zombies.py -- <name> <unzipped dir> <out.glb>
# Humanoids play the shared Mixamo library, so they go out as Mixamo rigs resting in a T-pose, without
# their own clips, with a HeadTop_End bone (zombie_body.gd reads the height off it), scale and Z-up
# applied, to assets/characters/zombies/raw/chars/<name>.glb for tools/build_zombies.gd:
#   hazmat:  already a Mixamo rig. Its FBX nodes rest in a pose (arms forward), so Godot's FBX import
#            takes that as the rest; Blender rests it in the bind pose, the T-pose.
#   bloater: a Character Creator rig in an A-pose. The arms are raised level and that becomes the rest
#            (its shape key goes, or the mesh can't take the pose), and the bones get Mixamo names.
#   leaper:  "Crawling mutated human", a Mixamo rig with no legs: its tail hangs on the right leg's
#            chain. A left leg chain goes in beside it, weighting nothing, so the rig is whole. No
#            colour map comes with it: one is made from its curvature, cavity and occlusion maps.
#            Arms raised level as the bloater's; HEIGHT tall.
#   spiker:  "Free Creature Character", a Rigify rig. Its DEF bones are folded into a new Mixamo
#            skeleton (RIGIFY; twist and helper bones' weights go to the bone they hang off), the
#            meshes come down to about a third (DECIMATE), the DirectX normal maps get their green
#            turned over. Arms raised level; HEIGHT tall.
# Creatures keep their own clips and go straight to assets/characters/zombies/<name>/<name>.glb:
#   blob:  its one pulsing clip, as "pulse"; zombie_body.gd makes its moves from it.
#   melty: its fifteen clips by their names. Unzip source/zombie_de_goma.zip under source/ first, on a
#          short path: its texture is lost past Windows' 260 characters.
#   dog:   its one clip, a howl, as "howl"; the rest of its moves are made in zombie_body.gd.
import bpy, os, sys, glob
import numpy as np
from mathutils import Vector, Matrix
name, src, out = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
model = sorted(glob.glob(os.path.join(src, "source", "**", "*.*"), recursive=True))
model = next(m for m in model if os.path.splitext(m)[1].lower() in (".fbx", ".glb", ".gltf"))
if model.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=model)
else:
    bpy.ops.import_scene.gltf(filepath=model)
texs = glob.glob(os.path.join(src, "**", "*.*"), recursive=True)
HUMANOID = name in ("hazmat", "bloater", "leaper", "spiker")
RAISE = ("bloater", "leaper", "spiker")  # rest in an A-pose: arms raised level
HEIGHT = {"leaper": 1.8, "spiker": 2.7}  # m, top of the head (the leaper's tail hangs below its hips)
DECIMATE = {"spiker": 0.3}

# material -> (albedo, normal) file names; melty and dog come with theirs embedded
MAPS = {
    "hazmat": {"HazMatSuit": ("HazMatSuit_BaseMap", "HazMatSuit_Normal"), "ZombieHead": ("ZombieHead_BaseMap", "HeadNorm")},
    "bloater": {"__mesh0_0_5_16_16": ("__mesh0_0_5_16_16_Diffuse", "__mesh0_0_5_16_16_Normal")},
    "blob": {"Spore": ("Blob_albedo", "Blob_normal")},
    "spiker": {m: (f"{m}.001_Base_color", f"{m}.001_Normal_DirectX") for m in ("Body", "Chain", "Parts", "Theeth")},
}.get(name, {})

# Rigify DEF bone -> Mixamo; any other DEF bone's weights go to the first of these above it, or
# (hung off an ORG bone) to RIGIFY_REST.
RIGIFY = {"DEF-spine": "Hips", "DEF-spine.001": "Spine", "DEF-spine.002": "Spine1", "DEF-spine.003": "Spine2",
          "DEF-spine.004": "Neck", "DEF-spine.006": "Head"}
for side, s in (("L", "Left"), ("R", "Right")):
    RIGIFY.update({f"DEF-shoulder.{side}": f"{s}Shoulder", f"DEF-upper_arm.{side}": f"{s}Arm",
                   f"DEF-forearm.{side}": f"{s}ForeArm", f"DEF-hand.{side}": f"{s}Hand",
                   f"DEF-thigh.{side}": f"{s}UpLeg", f"DEF-shin.{side}": f"{s}Leg",
                   f"DEF-foot.{side}": f"{s}Foot", f"DEF-toe.{side}": f"{s}ToeBase"})
RIGIFY_REST = {"pelvis": "Hips", "breast": "Spine2"}
MIXAMO_PARENT = {"Spine": "Hips", "Spine1": "Spine", "Spine2": "Spine1", "Neck": "Spine2", "Head": "Neck"}
for s in ("Left", "Right"):
    MIXAMO_PARENT.update({f"{s}Shoulder": "Spine2", f"{s}Arm": f"{s}Shoulder", f"{s}ForeArm": f"{s}Arm",
                          f"{s}Hand": f"{s}ForeArm", f"{s}UpLeg": "Hips", f"{s}Leg": f"{s}UpLeg",
                          f"{s}Foot": f"{s}Leg", f"{s}ToeBase": f"{s}Foot"})

# Character Creator -> Mixamo
CC = {"Hip": "Hips", "Waist": "Spine", "Spine01": "Spine1", "Spine02": "Spine2", "NeckTwist01": "Neck", "Head": "Head"}
for side, s in (("L", "Left"), ("R", "Right")):
    CC.update({f"{side}_Clavicle": f"{s}Shoulder", f"{side}_Upperarm": f"{s}Arm", f"{side}_Forearm": f"{s}ForeArm",
               f"{side}_Hand": f"{s}Hand", f"{side}_Thigh": f"{s}UpLeg", f"{side}_Calf": f"{s}Leg",
               f"{side}_Foot": f"{s}Foot", f"{side}_ToeBase": f"{s}ToeBase"})
    for cc, mx in (("Thumb", "Thumb"), ("Index", "Index"), ("Mid", "Middle"), ("Ring", "Ring"), ("Pinky", "Pinky")):
        for i in (1, 2, 3):
            CC[f"{side}_{cc}{i}"] = f"{s}Hand{mx}{i}"


def tex(stem):
    return next(t for t in texs if os.path.splitext(os.path.basename(t))[0] == stem)


for m in {m for o in bpy.context.scene.objects if o.type == "MESH" for m in o.data.materials if m}:
    if m.name.split(".")[0] not in MAPS:
        continue
    albedo, normal = MAPS[m.name.split(".")[0]]
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for link in list(nt.links):
        if link.to_node == bsdf:
            nt.links.remove(link)
    a = nt.nodes.new("ShaderNodeTexImage")
    a.image = bpy.data.images.load(tex(albedo))
    nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = bpy.data.images.load(tex(normal))
    n.image.colorspace_settings.name = "Non-Color"
    if normal.endswith("DirectX"):  # glTF wants OpenGL normals: green turned over
        img = n.image
        if img.size[0] > 2048:
            img.scale(2048, 2048 * img.size[1] // img.size[0])
        px = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        px[1::4] = 1.0 - px[1::4]
        img.pixels.foreach_set(px)
        img.pack()
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.8
for img in bpy.data.images:  # embedded maps over 2K come down (dog: 4K)
    if img.size[0] > 2048:
        img.scale(2048, 2048 * img.size[1] // img.size[0])

# The glTF importer's bone-shape sphere and an empty take are not part of the model.
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    if a.name == "Default Take":
        bpy.data.actions.remove(a)

arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
if HUMANOID:
    for o in bpy.context.scene.objects:
        o.animation_data_clear()
        if o.type == "MESH" and o.data.shape_keys:
            o.data.shape_keys.animation_data_clear()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
for o in list(bpy.context.scene.objects):  # Rigify's control shapes
    if o.type == "MESH" and not o.data.polygons:
        bpy.data.objects.remove(o)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def raise_arms(arm, bone):
    """Arm, forearm and hand laid out level along ±X, each turned about its own head; that pose baked
    into the meshes and made the rest."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:  # an imported clip's first frame stays on the bones
        pb.matrix_basis = Matrix()
    to_world = arm.matrix_world.to_3x3().normalized()
    for side, sign in (("Left", 1), ("Right", -1)):
        for b in ("Arm", "ForeArm", "Hand"):
            pb = arm.pose.bones[bone(side + b)]
            bpy.context.view_layer.update()
            d = (to_world @ (pb.tail - pb.head)).normalized()
            turn = to_world.inverted() @ d.rotation_difference(Vector((sign, 0, 0))).to_matrix() @ to_world
            head = pb.head.copy()
            pb.matrix = Matrix.Translation(head) @ turn.to_4x4() @ Matrix.Translation(-head) @ pb.matrix
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in meshes:  # bake the pose into the mesh, make it the rest, skin it again
        mod = next(m for m in o.modifiers if m.type == "ARMATURE")
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in meshes:
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = arm


if name == "spiker":
    # A new skeleton with the DEF bones' rests under Mixamo names and Mixamo's hierarchy.
    old = arm

    def mixamo_of(bname):
        b = old.data.bones.get(bname)
        while b:
            if b.name in RIGIFY:
                return RIGIFY[b.name]
            b = b.parent
        return next((v for k, v in RIGIFY_REST.items() if k in bname), "Spine2")
    src_of = {v: old.data.bones[k] for k, v in RIGIFY.items()}
    child = {p: c for c, p in MIXAMO_PARENT.items()}
    child.update({"Hips": "Spine", "Spine2": "Neck"})
    arm = bpy.data.objects.new("Armature", bpy.data.armatures.new("Armature"))
    bpy.context.scene.collection.objects.link(arm)
    arm.matrix_world = old.matrix_world
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for m in ["Hips"] + list(MIXAMO_PARENT):
        eb = arm.data.edit_bones.new("mixamorig:" + m)
        eb.head = src_of[m].head_local
        eb.tail = src_of[child[m]].head_local if m in child else src_of[m].tail_local
        if m in MIXAMO_PARENT:
            eb.parent = arm.data.edit_bones["mixamorig:" + MIXAMO_PARENT[m]]
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in meshes:
        w = {}  # vertex -> Mixamo bone -> weight
        names = {g.index: mixamo_of(g.name) for g in o.vertex_groups}
        for v in o.data.vertices:
            for g in v.groups:
                d = w.setdefault(v.index, {})
                d[names[g.group]] = d.get(names[g.group], 0.0) + g.weight
        o.vertex_groups.clear()
        groups = {}
        for vi, d in w.items():
            for m, wt in d.items():
                if m not in groups:
                    groups[m] = o.vertex_groups.new(name="mixamorig:" + m)
                groups[m].add([vi], wt, "REPLACE")
        mw = o.matrix_world.copy()
        o.parent = arm
        o.matrix_world = mw
        next(m for m in o.modifiers if m.type == "ARMATURE").object = arm
    bpy.data.objects.remove(old)

if name == "leaper":
    # A left leg beside the tail (the right leg's chain), weighting nothing.
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    ebs = arm.data.edit_bones
    parent = ebs["mixamorig:Hips"]
    for b in ("UpLeg", "Leg", "Foot", "ToeBase"):
        r = ebs["mixamorig:Right" + b]
        eb = ebs.new("mixamorig:Left" + b)
        eb.head = (-r.head.x, r.head.y, r.head.z)
        eb.tail = (-r.tail.x, r.tail.y, r.tail.z)
        eb.parent = parent
        parent = eb
    bpy.ops.object.mode_set(mode="OBJECT")

    # Colour from its maps (sRGB values): flesh, darker and redder in the creases and where light
    # can't reach, paler over the ridges.
    def channel(stem):
        img = bpy.data.images.load(tex(stem))
        px = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        return img.size, px.reshape(-1, 4)[:, 0]
    size, curve = channel("Curva")
    occ = channel("map_occlusion")[1]
    cav = channel("map_cavity")[1]
    flesh = np.array([0.70, 0.50, 0.47])
    crease = np.array([0.33, 0.11, 0.10])
    ridge = np.array([0.86, 0.78, 0.70])
    dark = np.clip((1.0 - occ * cav) * 1.6, 0.0, 1.0)[:, None]
    pale = np.clip((curve - 0.55) * 2.0, 0.0, 1.0)[:, None]
    rgb = flesh * (1.0 - dark) + crease * dark
    rgb = rgb * (1.0 - pale * 0.6) + ridge * pale * 0.6
    albedo = bpy.data.images.new("leaper_albedo", size[0], size[1])
    albedo.pixels.foreach_set(np.concatenate([rgb, np.ones((rgb.shape[0], 1))], axis=1).astype(np.float32).ravel())
    albedo.pack()
    mat = bpy.data.materials.new("Leaper")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    a = nt.nodes.new("ShaderNodeTexImage")
    a.image = albedo
    nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = bpy.data.images.load(tex("map_normals"))
    n.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.6
    for o in meshes:
        o.data.materials.clear()
        o.data.materials.append(mat)

if name in DECIMATE:
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        mod = o.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = DECIMATE[name]
        bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    print("triangles", sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons))

if name == "bloater":
    for o in meshes:  # the one shape key (a body morph) would stop the modifier from applying
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.shape_key_remove(all=True)
    for b in arm.data.bones:  # vertex groups follow the rename
        cc = b.name.removeprefix("CC_Base_")
        if cc in CC:
            b.name = "mixamorig:" + CC[cc]
if name in RAISE:
    raise_arms(arm, lambda b: "mixamorig:" + b)

if name in HEIGHT:  # to its height, before the units go into the data
    top = max((o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices)
    for o in bpy.context.scene.objects:
        if o.parent is None:
            o.matrix_world = Matrix.Scale(HEIGHT[name] / top, 4) @ o.matrix_world

# Scale (FBX centimetres) and rotation into the data, so the glb's skeleton is in metres. Not for
# creatures with clips: their keys would stay in the old units.
if HUMANOID or name == "blob":
    for o in bpy.context.scene.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
if HUMANOID:
    top = max((o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices)
    bpy.ops.object.mode_set(mode="EDIT")
    head = arm.data.edit_bones["mixamorig:Head"]
    end = arm.data.edit_bones.get("mixamorig:HeadTop_End") or arm.data.edit_bones.new("mixamorig:HeadTop_End")
    end.parent = head
    end.head = (head.head.x, head.head.y, top)
    end.tail = (head.head.x, head.head.y, top + 0.05)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("head top", round(top, 3))
elif name in ("blob", "dog"):
    for a in bpy.data.actions:
        a.name = {"blob": "pulse", "dog": "howl"}[name]
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=not HUMANOID,
                          export_animation_mode="ACTIONS", export_image_format="AUTO")
print("wrote", out)
