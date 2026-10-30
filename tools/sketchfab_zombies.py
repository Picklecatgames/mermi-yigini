# Blender (5.x, background): the Sketchfab zombies (docs/ayrintilar.md, "Kullanılan asetler") from the
# zips' source/ + textures/ folders into glb, textures wired by name and embedded, scale and Z-up applied.
#   blender -b --factory-startup -P tools/sketchfab_zombies.py -- <name> <unzipped dir> <out.glb>
# hazmat: a Mixamo rig. Its FBX nodes rest in a pose (arms forward), so Godot's FBX import takes that
#   as the rest; Blender rests it in the bind pose, a T-pose, which is what the shared clip library
#   needs. Its own four clips go (the library has better), a HeadTop_End bone is added (zombie_body.gd
#   reads the height off it). Out to assets/characters/zombies/raw/chars/hazmat.glb for
#   tools/build_zombies.gd.
# blob: its one pulsing clip kept as "pulse"; zombie_body.gd makes the rest of its moves from it.
import bpy, os, sys, glob
name, src, out = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
model = (glob.glob(os.path.join(src, "source", "*.fbx")) + glob.glob(os.path.join(src, "source", "*.glb")))[0]
if model.endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=model)
else:
    bpy.ops.import_scene.gltf(filepath=model)
texs = glob.glob(os.path.join(src, "textures", "*"))

# material -> (albedo, normal) file names
MAPS = {
    "hazmat": {"HazMatSuit": ("HazMatSuit_BaseMap", "HazMatSuit_Normal"), "ZombieHead": ("ZombieHead_BaseMap", "HeadNorm")},
    "blob": {"Spore": ("Blob_albedo", "Blob_normal")},
}[name]


def tex(stem):
    return next(t for t in texs if os.path.splitext(os.path.basename(t))[0] == stem)


for m in {m for o in bpy.context.scene.objects if o.type == "MESH" for m in o.data.materials if m}:
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

arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
if name == "hazmat":
    for o in bpy.context.scene.objects:
        o.animation_data_clear()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
# Scale (the FBX's 0.01) and rotation into the data, so the glb's skeleton is in metres.
for o in bpy.context.scene.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
if name == "hazmat":
    top = max((o.matrix_world @ v.co).z for o in bpy.context.scene.objects if o.type == "MESH" for v in o.data.vertices)
    bpy.ops.object.mode_set(mode="EDIT")
    head = arm.data.edit_bones["mixamorig:Head"]
    end = arm.data.edit_bones.new("mixamorig:HeadTop_End")
    end.parent = head
    end.head = (head.head.x, head.head.y, top)
    end.tail = (head.head.x, head.head.y, top + 0.05)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("head top", round(top, 3))
else:
    for a in bpy.data.actions:
        a.name = "pulse"
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=name != "hazmat",
                          export_image_format="AUTO")
print("wrote", out)
