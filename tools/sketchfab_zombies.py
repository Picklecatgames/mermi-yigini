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
# Creatures keep their own clips and go straight to assets/characters/zombies/<name>/<name>.glb:
#   blob:  its one pulsing clip, as "pulse"; zombie_body.gd makes its moves from it.
#   melty: its fifteen clips by their names. Unzip source/zombie_de_goma.zip under source/ first, on a
#          short path: its texture is lost past Windows' 260 characters.
#   dog:   its one clip, a howl, as "howl"; the rest of its moves are made in zombie_body.gd.
import bpy, os, sys, glob
from mathutils import Vector, Matrix
name, src, out = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
model = sorted(glob.glob(os.path.join(src, "source", "**", "*.*"), recursive=True))
model = next(m for m in model if os.path.splitext(m)[1].lower() in (".fbx", ".glb", ".gltf"))
if model.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=model)
else:
    bpy.ops.import_scene.gltf(filepath=model)
texs = glob.glob(os.path.join(src, "textures", "*"))
HUMANOID = name in ("hazmat", "bloater")

# material -> (albedo, normal) file names; melty and dog come with theirs embedded
MAPS = {
    "hazmat": {"HazMatSuit": ("HazMatSuit_BaseMap", "HazMatSuit_Normal"), "ZombieHead": ("ZombieHead_BaseMap", "HeadNorm")},
    "bloater": {"__mesh0_0_5_16_16": ("__mesh0_0_5_16_16_Diffuse", "__mesh0_0_5_16_16_Normal")},
    "blob": {"Spore": ("Blob_albedo", "Blob_normal")},
}.get(name, {})

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
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if HUMANOID:
    for o in bpy.context.scene.objects:
        o.animation_data_clear()
        if o.type == "MESH" and o.data.shape_keys:
            o.data.shape_keys.animation_data_clear()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)

if name == "bloater":
    for o in meshes:  # the one shape key (a body morph) would stop the modifier from applying
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.shape_key_remove(all=True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    # Arm, forearm and hand laid out level along ±X, each turned about its own head.
    for side, sign in (("L", 1), ("R", -1)):
        for b in ("Upperarm", "Forearm", "Hand"):
            pb = arm.pose.bones[f"CC_Base_{side}_{b}"]
            bpy.context.view_layer.update()
            d = (pb.tail - pb.head).normalized()
            turn = d.rotation_difference(Vector((sign, 0, 0))).to_matrix().to_4x4()
            head = pb.head.copy()
            pb.matrix = Matrix.Translation(head) @ turn @ Matrix.Translation(-head) @ pb.matrix
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
    for b in arm.data.bones:  # vertex groups follow the rename
        cc = b.name.removeprefix("CC_Base_")
        if cc in CC:
            b.name = "mixamorig:" + CC[cc]

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
    end = arm.data.edit_bones.new("mixamorig:HeadTop_End")
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
