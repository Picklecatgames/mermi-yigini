# Blender (5.x, background): the 9mm round as the body of a special round (GameState.SPECIALS).
# The bullet is pressed down to a short, slightly swollen dome over the case mouth, so a tip model
# grows out of it like part of the round instead of standing on a cut cylinder. A "TipSocket"
# empty sits inside the dome; a tip (tools/build_tips.py) goes on it, base at its origin, +X.
# Run: blender -b --factory-startup -P tools/build_bullet_case.py -- <in.glb> <case.glb>
import bpy, bmesh, sys

args = sys.argv[sys.argv.index("--") + 1:]
src, case_out = args[0], args[1]
MOUTH = 0.4644  # m in the model's units: the case mouth ring along +X (measured)
SQUASH = 0.38   # the bullet's length past the mouth keeps this share
SWELL = 1.12    # and gets this much rounder, a lip over the case's edge
SOCKET = 0.22   # past the mouth: the tip sinks into the dome's top half

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob = next(o for o in bpy.context.scene.objects if o.type == "MESH")
# Bake the Sketchfab node chain into the vertices: the round lies along world +X.
ob.data.transform(ob.matrix_world)
ob.parent = None
ob.matrix_world.identity()
ob.name = "Case"
for o in list(bpy.context.scene.objects):
    if o != ob:
        bpy.data.objects.remove(o)


def islands(bm):
    seen, out = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        seen.add(v.index)
        stack, comp = [v], []
        while stack:
            x = stack.pop()
            comp.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
        out.append(comp)
    return out


def is_bullet(comp):
    # The bullet: islands wholly past the case's inner ring, except the case mouth's own flat ring.
    xs = [v.co.x for v in comp]
    return min(xs) > 0.39 and not all(abs(x - MOUTH) < 1e-3 for x in xs)


bm = bmesh.new()
bm.from_mesh(ob.data)
bm.verts.ensure_lookup_table()
for comp in islands(bm):
    if not is_bullet(comp):
        continue
    for v in comp:
        past = v.co.x - MOUTH
        if past > 0.0:
            v.co.x = MOUTH + past * SQUASH
            grow = 1.0 + (SWELL - 1.0) * min(past / 0.08, 1.0)  # eased in over the first 8 cm
            v.co.y *= grow
            v.co.z *= grow
bm.to_mesh(ob.data)
bm.free()
for p in ob.data.polygons:
    p.use_smooth = True

e = bpy.data.objects.new("TipSocket", None)
e.location = (MOUTH + SOCKET, 0, 0)
bpy.context.scene.collection.objects.link(e)
bpy.ops.export_scene.gltf(filepath=case_out, export_format="GLB", export_yup=True)
print("bullet case:", case_out, len(ob.data.polygons), "faces")
