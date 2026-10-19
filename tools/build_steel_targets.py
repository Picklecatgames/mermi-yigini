# Blender (5.x, background): splits the "Steel Targets Pack" (linx_567, CC-BY-4.0) into three
# hanging targets, each a static mount plus swinging plates whose origin sits on their hinge.
# Run: blender -b --factory-startup -P tools/build_steel_targets.py -- <pack scene.gltf> <out_dir>
# Pack units are ~2x real size; everything is halved. Plates face Blender -Y (Godot +Z).
import bpy, sys, os
from mathutils import Vector, Matrix

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
SCALE = 0.5
TEX = 1024
# mount, plate, hinge (pack x, z) measured from the mount's bar / pegs
SETS = {
    "plate_rack": ("Plate_Mount_Plate Mount_0", "Steel Targets_Steel_Target_0", (0.075, 2.15)),
    "gong": ("gong_mount_gong_mount_0", "s_gong_s_gong_0", (0.295, 2.11)),
    "silhouette": ("Silhouette_mount_Silhouette_Mount_0", "Silhouette  target.001_Silhouette _target_0", (0.26, 1.815)),
}

# Plates moved along the bar off a clamp their hook would swing through (target, plate) -> m.
NUDGE = {("plate_rack", "Plate3"): 0.07}

def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    for img in bpy.data.images:
        if img.size[0] > TEX:
            img.scale(TEX, TEX)
    return {o.name: o for o in bpy.data.objects if o.type == 'MESH'}

def bake(o):
    o.data = o.data.copy()
    o.data.transform(o.matrix_world)
    o.parent = None
    o.matrix_world = Matrix.Identity(4)

for name, (mount_name, plate_name, hinge) in SETS.items():
    objs = load()
    mount, plate = objs[mount_name], objs[plate_name]
    for o in list(bpy.data.objects):
        if o not in (mount, plate):
            bpy.data.objects.remove(o)
    bake(mount); bake(plate)
    vs = [v.co for v in mount.data.vertices]
    c = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / 2, (min(v.y for v in vs) + max(v.y for v in vs)) / 2, min(v.z for v in vs)))
    # mount floor centre to origin, plate normal (+X) turned to -Y, halved
    to_local = Matrix.Scale(SCALE, 4) @ Matrix.Rotation(-1.5708, 4, 'Z') @ Matrix.Translation(-c)
    for o in (mount, plate):
        o.data.transform(to_local)
    mount.name = "Mount"
    plates = [plate]
    if name == "plate_rack":  # five plates in one mesh: split, then regroup loose parts by position
        bpy.ops.object.select_all(action='DESELECT')
        plate.select_set(True); bpy.context.view_layer.objects.active = plate
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.separate(type='LOOSE'); bpy.ops.object.mode_set(mode='OBJECT')
        parts = [o for o in bpy.data.objects if o.type == 'MESH' and o is not mount]
        span = lambda o: (min(v.co.x for v in o.data.vertices), max(v.co.x for v in o.data.vertices))
        groups = []  # parts whose x ranges overlap belong to one plate (disc, tab, rings)
        for o in sorted(parts, key=lambda o: span(o)[0]):
            if groups and span(o)[0] < groups[-1][1]:
                groups[-1][0].append(o); groups[-1][1] = max(groups[-1][1], span(o)[1])
            else:
                groups.append([[o], span(o)[1]])
        plates = []
        for g, _end in groups:
            bpy.ops.object.select_all(action='DESELECT')
            for o in g: o.select_set(True)
            bpy.context.view_layer.objects.active = g[0]
            if len(g) > 1: bpy.ops.object.join()
            plates.append(bpy.context.view_layer.objects.active)
    hz = hinge[1]
    for i, p in enumerate(plates):
        vs = [v.co for v in p.data.vertices]
        px = (min(v.x for v in vs) + max(v.x for v in vs)) / 2
        h = (to_local @ Vector((hinge[0], 0, hz)))  # hinge line y, z after the move
        pivot = Vector((px, h.y, h.z))
        p.data.transform(Matrix.Translation(-pivot))
        p.location = pivot
        p.name = "Plate%d" % (i + 1) if len(plates) > 1 else "Plate"
        p.location.x += NUDGE.get((name, p.name), 0.0)
        print("PLATE", name, p.name, "hinge (%.3f %.3f %.3f)" % tuple(pivot))
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_yup=True)
    print("WROTE", path)
