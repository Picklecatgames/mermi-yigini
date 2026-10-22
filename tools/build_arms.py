# Builds assets/weapons/arms/arms.gltf: one pair of first-person arms (gloves, sleeves, watch) with
# every gun on the same rig. 1Matzh's first-person sets (CC-BY-4.0) all use the same Rigify arms
# ("Division Agent"), so the arms come from the first set only; from each other set we take its gun
# mesh, the gun's own bones (copied onto our rig, constraints included) and its clips, renamed
# "<Gun>_<clip>". Switching guns in game then only swaps the gun mesh and the clip prefix.
# Sketchfab's own glTF of these is broken (stretched, spiky skin), so this starts from the original
# downloads: <dir>/source/*.blend (unpacked from the .rar) and <dir>/textures.
# Drops the rig widgets, scenery and unused body parts, wires the materials to the loose textures
# (UDIM tiles 1002-1004 stay as UV offsets; glTF repeat covers them), caps textures at 4K and
# keeps only the deform bones, animations baked. tools/paint_arms.py recolours the arms after.
# Run: blender -b --factory-startup --disable-autoexec -P tools/build_arms.py -- <out_dir> UZI=<dir> [Deagle=<dir> ...]
# Fists (2023) ships an FBX only, on a different body with the same Rigify bones: its clips go to
# fists.gltf (DEF bones only, our bone set), and the game plays them on these arms.
# Prints each set's eye (its camera, in our glTF space: y up, looking +Z) for scripts/guns.gd.
# Run: ... -- <out_dir> UZI=<dir> Deagle=<dir> Scorpion=<dir> Minigun=<dir> Fists=<dir>   (UZI first: its set has every arms map)
import bpy, bmesh, glob, math, os, re, sys

MAX_SIZE = 4096  # the sources are 4K; the gun fills half the screen, 2K blurred the detail
# Arms materials, from the first set: (base, metallic, roughness, normal, emission) in its textures/.
ARMS = {
    "Cloths": ("Cloths_BaseColor.1002.png", "Cloths_Metallic.1002.png", "Cloths_Roughness.1002.png", "Cloths_Normal.1002.png", "Cloths_Emission.1002.png"),
    "Gloves": ("Gloves_BaseColor.1003.png", "Gloves_Metallic.1003.png", "Gloves_Roughness.1003.png", "Gloves_Normal.1003.png", None),
    "Watch": ("Watch_BaseColor.1004.png", "Watch_Metallic.1004.png", "Watch_Roughness.1004.png", "Watch_Normal.1004.png", None),
    "Body": ("Face_Basecolor.png", None, None, "Face_Normal.png", None),
}
# Per set: the gun's mesh object and its materials. A new set needs an entry here.
GUNS = {
    "Deagle": {"mesh": "Deagle", "sets": {
        n: ("T_Deagle_%s_BaseColor.png" % t, "T_Deagle_%s_Metallic.png" % t, "T_Deagle_%s_Roughness.png" % t, "T_Deagle_%s_Normal.png" % t, None)
        for n, t in {"MainBody": "MainBody", "Slide": "Slide", "Magazine": "Magazine", "Bullet": "Bullet"}.items()
    }},
    # The Scorpion's maps carry its Substance project's name; they are its real textures.
    "Scorpion": {"mesh": "CZScorpion", "sets": {
        "CZScorpion": tuple("low_sp_TT_checker_4096x4096_UV_GRID_%s.jpeg" % m for m in ("BaseCo", "Metall", "Roughn", "Normal")) + (None,),
    }},
    # The Minigun set's gun is a material on its own arms' mesh (the arms are someone else's, not
    # used): its faces are split off and named for the gun. Its clips drive the same Rigify controls
    # with the hands tied to the gun, so they play on our arms as they are.
    "Minigun": {"mesh": "Arms", "name": "Minigun", "sets": {
        "Minigun_Mtl": ("Minigun_Mtl_BaseColor.png", "Minigun_Mtl_Metallic.png", "Minigun_Mtl_Roughness.png", "Minigun_Mtl_Normal.png", None),
    }},
    "UZI": {"mesh": "UZI", "sets": {
        "UZI": ("UZI_Base_color.png", "UZI_Metallic.png", "UZI_Roughness.png", "UZI_Normal_OpenGL.png", None),
        "UZI Magazine and Bullet": ("UZI_Magazine_and_Bullet_Base_color.png", "UZI_Magazine_and_Bullet_Metallic.png",
            "UZI_Magazine_and_Bullet_Roughness.png", "UZI_Magazine_and_Bullet_Normal_OpenGL.png", None),
    }},
}

args = sys.argv[sys.argv.index("--") + 1:]
out_dir = args[0]
sets = [a.split("=", 1) for a in args[1:]]
fists = [d for g, d in sets if g == "Fists"]
sets = [s for s in sets if s[0] != "Fists"]


def blend_of(d):
    return glob.glob(os.path.join(d, "source", "*.blend"))[0]


def plain(name):  # "UZI.001" -> "UZI": appended data gets a suffix when the name is taken
    return re.sub(r"\.\d{3}$", "", name)


def image(path, data):
    img = bpy.data.images.load(path)
    name = os.path.basename(path)
    img.name = os.path.splitext(name)[0].replace(".", "_").replace(" ", "_")
    if not data:
        img.colorspace_settings.name = "Non-Color"
    if max(img.size) > MAX_SIZE:
        img.scale(MAX_SIZE, MAX_SIZE)
    return img


def wire(mat, files, tex_dir):
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    base, metal, rough, normal, emit = files

    def tex(name, data):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = image(os.path.join(tex_dir, name), data)
        return n
    nt.links.new(tex(base, True).outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.8
    if metal:
        nt.links.new(tex(metal, False).outputs["Color"], bsdf.inputs["Metallic"])
    if rough:
        nt.links.new(tex(rough, False).outputs["Color"], bsdf.inputs["Roughness"])
    if normal:
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tex(normal, False).outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if emit:
        nt.links.new(tex(emit, True).outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0


def strip(o, keep_sets, tex_dir):
    """Faces on materials without a texture set are the Division Agent body parts hidden off screen."""
    me = o.data
    keep = [i for i, s in enumerate(o.material_slots) if s.material and plain(s.material.name) in keep_sets]
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index not in keep], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    for i in reversed(range(len(o.material_slots))):
        if i not in keep:
            o.active_material_index = i
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.material_slot_remove()
    # The parts are unwrapped in different UV layers (the gloves and bare arm in "DiffuseUV", the
    # rest in "UVMap") and the .blend's materials don't say which; glTF exports one layer. Where a
    # material's faces all sit on one point of the exported layer, they take the layer they are
    # spread out in, or the gloves read a single texel and come out a flat block.
    out = me.uv_layers.active
    for i, s in enumerate(o.material_slots):
        loops = [li for p in me.polygons if p.material_index == i for li in p.loop_indices]
        spread = lambda layer: len({tuple(round(v, 3) for v in layer.data[li].uv) for li in loops[::7]})
        if loops and spread(out) <= 1:
            best = max(me.uv_layers, key=spread)
            for li in loops:
                out.data[li].uv = best.data[li].uv
            print(o.name, s.material.name, "UVs from", best.name)
    for s in o.material_slots:
        if not s.material.get("wired"):
            wire(s.material, keep_sets[plain(s.material.name)], tex_dir)
            s.material["wired"] = True
    print(o.name, "verts", len(me.vertices), "slots", [s.material.name for s in o.material_slots])


## The guns' hard edges are knife-sharp: flat panels meeting at a line that never catches light, so
## up close they read as boxes. Real machined steel is broken at every edge; a small rounded bevel
## on the sharp edges only (normals hardened, so the flat panels stay flat) gives each one a thin
## highlight. Under a millimetre, so the textures and their normal maps don't shift.
BEVEL = {"width": 0.0007, "segments": 2, "angle": 30}  # m, -, degrees


def bevel(o):
    # Only edges whose both ends ride one bone fully: a bevel across two parts (magazine and well,
    # slide and frame) gives its new points both bones' weights, and they stretch apart in a reload.
    me = o.data
    one = {}
    for v in me.vertices:
        gs = [g for g in v.groups if g.weight > 0.01]
        one[v.index] = gs[0].group if len(gs) == 1 and gs[0].weight > 0.99 else None
    bm = bmesh.new()
    bm.from_mesh(me)
    # Zero-length edges and stacked points send a bevel's arcs off to infinity: tidy them first.
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges[:])
    bm.to_mesh(me)
    bm.free()
    one = {}
    for v in me.vertices:
        gs = [g for g in v.groups if g.weight > 0.01]
        one[v.index] = gs[0].group if len(gs) == 1 and gs[0].weight > 0.99 else None
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.edges.ensure_lookup_table()
    marked = [e.index for e in bm.edges if one[e.verts[0].index] is not None and one[e.verts[0].index] == one[e.verts[1].index]
        and len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(BEVEL["angle"])]
    bm.free()
    weights = me.attributes.get("bevel_weight_edge") or me.attributes.new("bevel_weight_edge", "FLOAT", "EDGE")
    vals = [0.0] * len(me.edges)
    for i in marked:
        vals[i] = 1.0
    weights.data.foreach_set("value", vals)
    m = o.modifiers.new("Bevel", "BEVEL")
    m.width = BEVEL["width"]
    m.segments = BEVEL["segments"]
    m.limit_method = "WEIGHT"
    m.harden_normals = True
    with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o]):
        bpy.ops.object.modifier_move_to_index(modifier="Bevel", index=0)  # before the armature
        before = len(me.polygons)
        bpy.ops.object.modifier_apply(modifier="Bevel")
    lost = sum(1 for v in o.data.vertices if not all(abs(c) < 10.0 for c in v.co))
    assert lost == 0, "%s: %d points flew off in the bevel" % (o.name, lost)
    print(o.name, "bevelled", len(marked), "edges: faces", before, "->", len(o.data.polygons))


def fcurves(action):
    for layer in action.layers:
        for strip_ in layer.strips:
            for bag in strip_.channelbags:
                yield from bag.fcurves


def gun_bone(name):  # Rigify's own bones are DEF-/ORG-/MCH-/VIS_ or lower case; the authors' are not
    return name[:1].isupper() and not name.startswith(("DEF-", "ORG-", "MCH-", "VIS"))


def eye(gun, cam, src_rig):
    p = rig.matrix_world @ src_rig.matrix_world.inverted() @ cam.matrix_world.translation
    print("EYE %s: Vector3(%.4f, %.4f, %.4f) lens %.2f mm" % (gun, p.x, p.z, -p.y, cam.data.lens))


def untied(r, bone, action):
    """`bone`'s pose (armature space) on `action`'s first frame with its Child Of ties off."""
    pb = r.pose.bones[bone]
    ties_ = [c for c in pb.constraints if c.type == "CHILD_OF"]
    was = [c.mute for c in ties_]
    for c in ties_:
        c.mute = True
    if r.animation_data is None:
        r.animation_data_create()
    r.animation_data.action = action
    bpy.context.scene.frame_set(int(action.frame_range[0]))
    bpy.context.view_layer.update()
    m = r.evaluated_get(bpy.context.evaluated_depsgraph_get()).pose.bones[bone].matrix.copy()
    for c, w in zip(ties_, was):
        c.mute = w
    r.animation_data.action = None
    return m


def prefix_actions(actions, gun):
    for a in actions:
        a.name = gun + "_" + plain(a.name)
        a.use_fake_user = True  # kept until export even while no object uses it


# The first set: its rig and arms are everyone's.
base_gun, base_dir = sets[0]
bpy.ops.wm.open_mainfile(filepath=blend_of(base_dir))
rig = bpy.data.objects["rig"]
eye(base_gun, bpy.data.objects["Camera"], rig)
for o in list(bpy.data.objects):
    if o.name not in {"rig", "Mesh", GUNS[base_gun]["mesh"]}:
        bpy.data.objects.remove(o)
strip(bpy.data.objects["Mesh"], ARMS, os.path.join(base_dir, "textures"))
strip(bpy.data.objects[GUNS[base_gun]["mesh"]], GUNS[base_gun]["sets"], os.path.join(base_dir, "textures"))
bevel(bpy.data.objects[GUNS[base_gun]["mesh"]])
prefix_actions(list(bpy.data.actions), base_gun)
base_bones = {b.name for b in rig.data.bones}
# Each set ties the hands to its gun with Child Of constraints on the IK hand controls (right hand on
# the body, left on the magazine) and keys their influence in its clips. Every set's ties go onto our
# rig under the gun's name; in each clip the other guns' ties are keyed off (_tie_off).
actions = {base_gun: list(bpy.data.actions)}
ties = {base_gun: [(pb.name, c.name, c.influence) for pb in rig.pose.bones if not gun_bone(pb.name)
    for c in pb.constraints if gun_bone(getattr(c, "subtarget", "") or "")]}

for gun, d in sets[1:]:
    mesh_name = GUNS[gun]["mesh"]
    with bpy.data.libraries.load(blend_of(d)) as (src, dst):
        dst.objects = ["rig", mesh_name, "Camera"]
        dst.actions = list(src.actions)
    src_rig, gun_mesh, cam = dst.objects
    gun_mesh.name = GUNS[gun].get("name", gun_mesh.name)
    for o in (src_rig, cam, gun_mesh):  # in the scene, so their world matrices are evaluated
        bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.update()
    eye(gun, cam, src_rig)
    prefix_actions(dst.actions, gun)
    # The gun's own bones go onto our rig; one whose name another gun already uses gets this gun's
    # name in front. Names are mapped on our side only: renaming a bone in Blender rewrites the
    # paths in other actions too.
    ours = {b.name: (gun + " " + b.name if b.name in base_bones else b.name) for b in src_rig.data.bones if gun_bone(b.name)}
    for old, new in ours.items():
        if old != new:
            if old in gun_mesh.vertex_groups:
                gun_mesh.vertex_groups[old].name = new
            for a in dst.actions:
                for fc in fcurves(a):
                    fc.data_path = fc.data_path.replace('pose.bones["%s"]' % old, 'pose.bones["%s"]' % new)
    # Same arms, same rest pose in rig space (the sets stand the rig object in different places;
    # the clips are rig space): warn if the hands disagree, the clips would then be off by that.
    for side in "LR":
        dh = (src_rig.data.bones["DEF-hand." + side].head_local - rig.data.bones["DEF-hand." + side].head_local).length
        if dh > 0.001:
            print("WARNING %s: DEF-hand.%s rests %.1f mm off ours" % (gun, side, dh * 1000))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for b in src_rig.data.bones:  # parents first: data.bones lists them that way
        if b.name in ours:
            eb = rig.data.edit_bones.new(ours[b.name])
            eb.tail = (0.0, 0.0, b.length)  # a new bone has no length, and no direction for matrix to turn
            eb.matrix = b.matrix_local
            eb.length = b.length
            eb.use_deform = b.use_deform
            if b.parent:
                eb.parent = rig.data.edit_bones[ours.get(b.parent.name, b.parent.name)]
    bpy.ops.object.mode_set(mode="OBJECT")
    for old, new in ours.items():
        for c in src_rig.pose.bones[old].constraints:
            nc = rig.pose.bones[new].constraints.copy(c)
            if getattr(nc, "target", None) == src_rig:
                nc.target = rig
                nc.subtarget = ours.get(nc.subtarget, nc.subtarget)
    ties[gun] = []
    first = dst.actions[0]
    for pb in src_rig.pose.bones:
        if gun_bone(pb.name):
            continue
        for c in pb.constraints:
            if getattr(c, "subtarget", "") in ours:
                nc = rig.pose.bones[pb.name].constraints.copy(c)
                nc.name = gun + " " + c.name
                nc.target = rig
                nc.subtarget = ours[c.subtarget]
                # A set with other arms (the Minigun's) has its hand controls elsewhere before the tie
                # takes them: the tie's inverse is made for that, so it is moved by the difference
                # (measured with the ties off, on the set's first clip). Same arms: no difference.
                if hasattr(nc, "inverse_matrix"):
                    nc.inverse_matrix = c.inverse_matrix @ untied(src_rig, pb.name, first) @ untied(rig, pb.name, first).inverted()
                ties[gun].append((pb.name, nc.name, c.influence))
                for a in dst.actions:
                    for fc in fcurves(a):
                        fc.data_path = fc.data_path.replace('pose.bones["%s"].constraints["%s"]' % (pb.name, c.name),
                            'pose.bones["%s"].constraints["%s"]' % (pb.name, nc.name))
    actions[gun] = list(dst.actions)
    base_bones |= set(ours.values())
    # Where it sat by its rig, now by ours, baked into the vertices: the glTF exporter writes a
    # skinned mesh's vertices as they are, as if the object stood on the rig (the Deagle's is in cm).
    gun_mesh.data.transform(src_rig.matrix_world.inverted() @ gun_mesh.matrix_world)
    gun_mesh.parent = rig
    gun_mesh.matrix_world = rig.matrix_world
    for m in gun_mesh.modifiers:
        if m.type == "ARMATURE":
            m.object = rig
    strip(gun_mesh, GUNS[gun]["sets"], os.path.join(d, "textures"))
    bevel(gun_mesh)
    bpy.data.objects.remove(src_rig)
    bpy.data.objects.remove(cam)
    print(gun, "merged:", len(ours), "bones,", len(dst.actions), "clips")

# Every clip keys every gun's ties: its own at the set's value unless it animates them, the rest off.
if rig.animation_data is None:
    rig.animation_data_create()
for gun, acts in actions.items():
    for a in acts:
        rig.animation_data.action = a  # fcurve_ensure_for_datablock wants it assigned
        keyed = {fc.data_path for fc in fcurves(a)}
        for owner, ties_of in ties.items():
            for bone, name, value in ties_of:
                path = 'pose.bones["%s"].constraints["%s"].influence' % (bone, name)
                if owner != gun or path not in keyed:
                    for fc in [f for f in fcurves(a) if f.data_path == path]:
                        fc.keyframe_points.clear()
                    fc = a.fcurve_ensure_for_datablock(rig, path)
                    fc.keyframe_points.insert(a.frame_range[0], value if owner == gun else 0.0)
rig.animation_data.action = None
print("ties:", {g: [t[1] for t in v] for g, v in ties.items()})

os.makedirs(out_dir, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=os.path.join(out_dir, "arms.gltf"), export_format="GLTF_SEPARATE", export_texture_dir="textures",
    export_def_bones=True, export_animation_mode="ACTIONS", export_force_sampling=True,
    export_cameras=False, export_lights=False, export_apply=False, export_yup=True)
print("arms built:", [g for g, _ in sets])
our_def = {b.name for b in rig.data.bones if b.name.startswith("DEF-")}
base_at = rig.matrix_world.copy()

# Fists: its rig, moved to where ours stands, with only our DEF bones left deforming, and its clips.
for d in fists:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=glob.glob(os.path.join(d, "source", "*.fbx"))[0])
    rig = bpy.data.objects["rig"]
    cam = bpy.data.objects["Camera"]
    rig.matrix_world = base_at  # the FBX rig stands at the origin
    eye("Fists", cam, bpy.data.objects.new("origin", None))
    for o in list(bpy.data.objects):
        if o != rig:
            bpy.data.objects.remove(o)
    for b in rig.data.bones:
        b.use_deform = b.name in our_def
    for a in list(bpy.data.actions):
        if a.name.startswith("rig|rig|"):
            a.name = "Fists_" + a.name.removeprefix("rig|rig|")
            a.use_fake_user = True
        else:
            bpy.data.actions.remove(a)  # the camera's and the skybox's
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, "fists.gltf"), export_format="GLTF_SEPARATE",
        export_def_bones=True, export_animation_mode="ACTIONS", export_force_sampling=True,
        export_cameras=False, export_lights=False, export_apply=False, export_yup=True)
    print("fists built:", [a.name for a in bpy.data.actions])
