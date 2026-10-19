# Blender (5.x, background): low-poly copy of the 9mm bullet for the heap and the spill, where
# ~23 000 copies are drawn at once and nobody sees one closer than a hand's length.
# Run: blender -b --factory-startup -P tools/build_bullet_lod.py -- <in.glb> <out.glb> [target_tris]
import bpy, sys

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]
target = int(args[2]) if len(args) > 2 else 140

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for ob in meshes:
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    bpy.context.view_layer.objects.active = ob
    # Planar first: the case and the bullet's sides are mostly flat rings of quads.
    m = ob.modifiers.new("planar", "DECIMATE")
    m.decimate_type = "DISSOLVE"
    m.angle_limit = 0.035
    m.delimit = {"UV"}
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode="OBJECT")
    now = len(ob.data.polygons)
    if now > target:
        m = ob.modifiers.new("collapse", "DECIMATE")
        m.ratio = target / now
        m.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=m.name)
    for p in ob.data.polygons:
        p.use_smooth = True
    print("bullet lod:", ob.name, tris, "->", len(ob.data.polygons), "tris")

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True)
