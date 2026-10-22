# Blender (5.x, background): a special round's tip (GameState.SPECIALS) from a downloaded model.
# Turns it so `fwd` points along +X (the way the round flies) and, if given, `face` along -Y:
# that is toward the player's eye while the round lies in the hand (Godot +Z there). Cuts it to
# about `tris` triangles, scales it to `length` (the plain bullet is ~1.05 in the case's units,
# 0.99 across) with its back at the origin, so it drops onto the case's TipSocket
# (tools/build_bullet_case.py). Textures go down to 512 px: in hand the tip is a fingertip big.
# Axes are +X|-X|+Y|-Y|+Z|-Z of the downloaded model.
# Meshes in material `drop` are left out (the balloons' strings, too thin to see at this size);
# `tex` sets the texture size instead (the scream round's full-screen face: scream_face.glb).
# Run: blender -b --factory-startup -P tools/build_tips.py -- <in.gltf> <out.glb> <fwd> <face|-> <tris> <length> [drop|-] [tex]
import bpy, sys, math
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
src, dst, fwd, face, target, length = args[0], args[1], args[2], args[3], int(args[4]), float(args[5])
TEX = int(args[7]) if len(args) > 7 else 512
WIDTH_MAX = 1.25  # the case is 0.99 across

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
drop = args[6] if len(args) > 6 and args[6] != "-" else None
obs = [o for o in bpy.context.scene.objects if o.type == "MESH" and not (drop and o.data.materials[0].name == drop)]
for o in obs:
    o.data = o.data.copy()  # instances share mesh data; each is baked on its own
    o.data.transform(o.matrix_world)
    o.parent = None
    o.matrix_world = Matrix.Identity(4)
for o in list(bpy.context.scene.objects):
    if o not in obs:
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="SELECT")
bpy.context.view_layer.objects.active = obs[0]
bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
ob.name = "Tip"

def axis(s):
    return Vector({"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}[s[1]]) * (1 if s[0] == "+" else -1)


if face == "-":
    turn = axis(fwd).rotation_difference(Vector((1, 0, 0))).to_matrix()
else:  # rows: where +X, +Y and +Z come from
    x, y = axis(fwd), -axis(face)
    turn = Matrix((x, y, x.cross(y)))
ob.data.transform(turn.to_4x4())

tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
if tris > target:
    m = ob.modifiers.new("cut", "DECIMATE")
    m.ratio = target / tris
    m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)
for p in ob.data.polygons:
    p.use_smooth = True

vs = [v.co for v in ob.data.vertices]
lo = Vector([min(v[i] for v in vs) for i in range(3)])
hi = Vector([max(v[i] for v in vs) for i in range(3)])
# At most `length` long and WIDTH_MAX across: a wide bunch (the balloons) would spill over the
# rounds beside it in the hand.
s = min(length / (hi.x - lo.x), WIDTH_MAX / max(hi.y - lo.y, hi.z - lo.z))
ob.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(-Vector((lo.x, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2))))

for img in bpy.data.images:
    if img.size[0] > TEX:
        img.scale(TEX, max(1, img.size[1] * TEX // img.size[0]))

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_image_format="JPEG")
print("tip:", dst, tris, "->", len(ob.data.polygons), "tris", "size", tuple(round(x, 3) for x in (hi - lo) * s))
