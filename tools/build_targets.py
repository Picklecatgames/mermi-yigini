# Blender (5.x, background): splits HippoStance's "Shooting Target Set" (Sketchfab, CC-BY-4.0) into
# one glTF per target, each at its own origin (stand foot on the floor), moving parts as separate
# nodes keeping the artist's pivots (hinges, star hub). Metres, scale applied, textures 2K and
# shared in one folder.
# Run: blender -b --factory-startup -P tools/build_targets.py -- <scene.gltf> <out_dir>
import bpy, os, sys
from mathutils import Matrix

SRC, OUT = sys.argv[sys.argv.index("--") + 1:]
os.makedirs(OUT, exist_ok=True)

# file -> [(source node prefix or exact name, new name)]; the first entry is the stand/origin.
SETS = {
    "texas_star": [("TexasStar_Stand", "Stand"), ("TexasStar_Arm", "Arm")] + [(f"TexasStar_Plate_0{i}", f"Plate{i}") for i in range(1, 6)],
    "plate_rack": [("PlateRack_Stand", "Stand"), ("PlateRack_ResetArm", "ResetArm")] + [(f"PlateRack_Plate_0{i}", f"Plate{i}") for i in range(1, 7)],
    "popper": [("Popper_Stand", "Stand"), ("Popper_Target", "Target")],
    "gong": [("GongTarget", "Stand")],
    "steel66": [("Steel66", "Stand")],
    "steel10": [("Steel10Inch", "Stand")],
    "hostage": [("HostageSteel", "Stand"), ("HostageSteel_Target", "Target")],
    "paper": [("PaperTarget", "Stand")],
    "duel_tree": [("DuelTree_Stand", "Stand")] + [(f"DuelTree_Target_0{i}", f"Paddle{i}") for i in range(1, 7)],
    "spin_rack": [("SpinningPlateRack_Stand", "Stand"), ("SpinningPlateRack_Rack", "Rack")] + [(f"SpinningPlateRack_Plate_0{i}", f"Plate{i}") for i in range(1, 9)],
}

# Parts cut out of a single mesh by face centre (Blender Z-up metres, after the move to the
# set's origin): name -> (new part, test). The gong's disc and chains swing from the beam.
GONG_BEAM = 1.29  # m: underside of the A-frame beam, where the chains hang from
# Every corner inside: long thin faces (the bolt through the beam) stay with the stand.
SPLITS = {"gong": ("Plate", lambda ws: all(abs(w.x) < 0.7 and -0.05 < w.z < GONG_BEAM for w in ws))}

bpy.ops.import_scene.gltf(filepath=SRC)
for img in bpy.data.images:
    if img.size[0] > 2048:
        img.scale(2048, 2048)

def mesh_of(node_name):
    # Sketchfab puts each mesh under an empty that carries the pivot; the mesh child sits at identity.
    for o in bpy.data.objects:
        if o.type == "MESH" and o.parent and o.parent.name == node_name:
            return o
    raise KeyError(node_name)

for name, parts in SETS.items():
    objs = []
    for src, new in parts:
        o = mesh_of(src)
        objs.append((o, new, o.matrix_world.copy()))
    origin = objs[0][2].to_translation()
    origin.z = 0.0
    bpy.ops.object.select_all(action="DESELECT")
    for o, new, mw in objs:
        o.parent = None
        o.matrix_world = Matrix.Translation(-origin) @ mw
        o.name = new
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0][0]
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if name in SPLITS:
        new, test = SPLITS[name]
        o = objs[0][0]
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        for f in o.data.polygons:
            f.select = test([o.matrix_world @ o.data.vertices[i].co for i in f.vertices])
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        part = [x for x in bpy.context.selected_objects if x != o][0]
        part.name = new
        # Pivot at the top of the cut-out, centred over it: where it hangs from.
        ws = [part.matrix_world @ v.co for v in part.data.vertices]
        top = max(w.z for w in ws)
        cx = (min(w.x for w in ws) + max(w.x for w in ws)) / 2
        cy = (min(w.y for w in ws) + max(w.y for w in ws)) / 2
        bpy.context.scene.cursor.location = (cx, cy, top)
        bpy.ops.object.select_all(action="DESELECT")
        part.select_set(True)
        bpy.context.view_layer.objects.active = part
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        objs.append((part, new, part.matrix_world.copy()))
        print("SPLIT", name, new, "pivot", round(cx, 3), round(cy, 3), round(top, 3), len(part.data.polygons), "faces")
        bpy.ops.object.select_all(action="DESELECT")
        for x, _, _ in objs:
            x.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, name + ".gltf"), export_format="GLTF_SEPARATE",
        export_texture_dir="textures", use_selection=True, export_yup=True,
        export_image_format="AUTO", export_apply=False)
    for o, new, mw in objs:  # back, so later sets see untouched world transforms
        o.name = new + "_done_" + name
    print("EXPORTED", name, [n for _, n, _ in objs])
