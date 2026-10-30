# Blender (5.x, background): the electric round as the bench builds it (scripts/electric_fx.gd,
# 2026-10-28, the user's design): the workbench's own .338 Lapua (R_lapua in workbench.glb, its
# textures) with what goes onto it as separate parts, so each can be brought in on its own.
#   CaseWhole the brass case and primer, uncut          Tip       the plain bullet it starts with
#   CaseLow, CaseMid, CaseHigh  the same case cut in three: the middle slice is thrown out
#   Spool     the empty spool that fills the gap        Coil      the copper winding on it; UV.x runs
#   RingLow   steel ring under the winding                        0 -> 1 along the wire, so a shader
#   RingHigh  steel ring over it                                  can wind it on turn by turn
#   Reactor   shank, two ice-blue rings, the quartz window; inside it Socket, TopCap, Tube, Core,
#             Filament, Plates
#   Nose      the sharp gunmetal ogive, knurled at its foot so it shows turning as it screws on
# Real size (m); every part's origin is the round's foot on its axis, glTF +Y up, so all of them
# stand together at the identity and an animation only moves each off that.
# Run: blender -b --factory-startup -P tools/build_electric_round.py -- assets/props/workbench/workbench.glb assets/bullet/electric_round.glb
import bpy, bmesh, math, sys
from mathutils import Matrix, Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
SEGS = 48
WIRE = 0.0004  # m, the winding wire's radius
TURNS = 22
BAND = (0.013, 0.037)  # m up the case: where the winding goes
SLEEVE = 0.0004  # m, the spool's wall
RING_H = 0.0012  # m, each steel ring's height

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
lapua = bpy.data.objects["R_lapua"]
lapua.data = lapua.data.copy()
lapua.data.transform(lapua.matrix_world)
lapua.matrix_world.identity()
lapua.parent = None
for o in [o for o in bpy.data.objects if o != lapua]:
    bpy.data.objects.remove(o)
vs = [v.co for v in lapua.data.vertices]
foot = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / 2, (min(v.y for v in vs) + max(v.y for v in vs)) / 2, min(v.z for v in vs)))
lapua.data.transform(Matrix.Translation(-foot))
bpy.ops.object.select_all(action="DESELECT")
lapua.select_set(True)
bpy.context.view_layer.objects.active = lapua
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
bullet = next(i for i, s in enumerate(lapua.material_slots) if "Bullet" in s.material.name)
for p in lapua.data.polygons:
    p.select = p.material_index == bullet
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
tip = next(o for o in bpy.data.objects if o != lapua)
tip.name = "Tip"
for o in (lapua, tip):  # drop the slots each half no longer uses
    used = {p.material_index for p in o.data.polygons}
    for i in reversed(range(len(o.material_slots))):
        if i not in used:
            o.active_material_index = i
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.material_slot_remove()

cv = [v.co for v in lapua.data.vertices]
mouth = max(v.z for v in cv)
body = max(math.hypot(v.x, v.y) for v in cv if 0.004 < v.z < 0.056)  # the body runs straight 5 -> 55 mm, no vertices between
tv = [v.co for v in tip.data.vertices]
seat = min(v.z for v in tv)  # the bullet's foot, down in the neck
cal = max(math.hypot(v.x, v.y) for v in tv)


def mat(name, color, metal, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m


STEEL = mat("steel", (0.62, 0.63, 0.64), 1.0, 0.22)
SPOOL = mat("spool", (0.16, 0.16, 0.17), 1.0, 0.3)  # machined dark steel
COPPER = mat("copper", (0.93, 0.48, 0.3), 1.0, 0.28)
GUN = mat("gunmetal", (0.2, 0.21, 0.22), 1.0, 0.32)
BLUE = mat("ice_anodized", (0.42, 0.72, 0.86), 0.85, 0.32)
GLASS = mat("quartz", (0.9, 0.95, 1.0), 0.0, 0.03)
GLOW = mat("reactor_glow", (0.75, 0.9, 1.0), 0.0, 0.4)
CERAMIC = mat("ceramic_black", (0.03, 0.03, 0.035), 0.0, 0.6)
FILAMENT = mat("filament", (0.93, 0.5, 0.3), 1.0, 0.3)
CUT_FACE = mat("brass_cut", (0.78, 0.6, 0.32), 1.0, 0.4)


def obj(name, bm, material, parent=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(35))  # flat ends stay flat, not shaded into a blob
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = parent
    return o


def revolve(profile, segs=SEGS, knurl=None):
    """A body of revolution through (r, z) points, bottom to top; r 0 closes it to a point.
    knurl (z0, z1, depth): every other column cut in by depth between z0 and z1."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    rings = []
    for r, z in profile:
        ring = []
        for s in range(segs):
            a = 2 * math.pi * s / segs
            rr = r
            if knurl and knurl[0] <= z <= knurl[1] and s % 2:
                rr = r - knurl[2]
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    n = len(profile)
    for i in range(n - 1):
        for s in range(segs):
            q = [rings[i][s], rings[i][(s + 1) % segs], rings[i + 1][(s + 1) % segs], rings[i + 1][s]]
            f = bm.faces.new(q)
            for l, (du, dv) in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
                l[uv].uv = ((s + du) / segs, (i + dv) / (n - 1))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def tube(r_in, r_out, z0, z1, bevel=0.0002):
    b = bevel
    return revolve([(r_in, z0), (r_out - b, z0), (r_out, z0 + b), (r_out, z1 - b), (r_out - b, z1), (r_in, z1), (r_in, z0)])


# The winding sits where the case is cut through (the user's call: flush with the brass, not a
# sleeve over it). CaseWhole is the uncut case it starts as; at the cut it becomes CaseLow and
# CaseHigh, the brass slice between (CaseMid) is thrown out, the spool fills the gap, the copper
# stands a hair proud of the brass and the steel rings close the ends. Cut faces are capped.
groove = body + 0.00015 - 2 * WIRE
cut = (BAND[0] - RING_H, BAND[1] + RING_H)
whole = lapua.data.copy()
bm = bmesh.new()
bm.from_mesh(lapua.data)
for z in cut:
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1))
bm.to_mesh(lapua.data)
bm.free()


def piece(name, z0, z1):
    me = lapua.data.copy()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not z0 < f.calc_center_median().z < z1], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    rim = [e for e in bm.edges if e.is_boundary and any(abs(v.co.z - c) < 1e-6 for v in e.verts for c in cut)]
    mid = sum(v.co.z for v in bm.verts) / len(bm.verts)
    caps = bmesh.ops.holes_fill(bm, edges=rim)["faces"]
    me.materials.append(CUT_FACE)
    for f in caps:  # bare brass where it was cut, flat, facing away from the piece
        f.material_index = len(me.materials) - 1
        f.smooth = False
        f.normal_update()
        if f.normal.z * (f.calc_center_median().z - mid) < 0:
            f.normal_flip()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


piece("CaseLow", -1.0, cut[0])
piece("CaseMid", cut[0], cut[1])
piece("CaseHigh", cut[1], 1.0)
lapua.data = whole
lapua.name = "CaseWhole"
# A machined bobbin, solid (it fills the gap): a flange at each end flush with the case, and
# between them one shallow groove per turn for the wire to lie in (the user's call: the plain
# cylinder read as a grey lump).
prof = [(0.0, cut[0]), (body, cut[0]), (body, BAND[0]), (groove, BAND[0])]
for i in range(TURNS):
    z0 = BAND[0] + (BAND[1] - BAND[0]) * i / TURNS
    zs = (BAND[1] - BAND[0]) / TURNS
    prof += [(groove, z0 + zs * 0.15), (groove - 0.00025, z0 + zs * 0.5), (groove, z0 + zs * 0.85)]
prof += [(groove, BAND[1]), (body, BAND[1]), (body, cut[1]), (0.0, cut[1])]
obj("Spool", revolve(prof), SPOOL)
bm = bmesh.new()
uv = bm.loops.layers.uv.new()
coil_r = groove + WIRE
lo, hi = BAND[0] + WIRE * 1.2, BAND[1] - WIRE * 1.2
steps, sides = TURNS * 40, 8
rings = []
for i in range(steps + 1):
    k = i / steps
    a = 2 * math.pi * TURNS * k
    c = Vector((coil_r * math.cos(a), coil_r * math.sin(a), lo + (hi - lo) * k))
    out = Vector((math.cos(a), math.sin(a), 0.0))
    up = Vector((0.0, 0.0, 1.0))
    rings.append([bm.verts.new(c + WIRE * (math.cos(2 * math.pi * j / sides) * out + math.sin(2 * math.pi * j / sides) * up)) for j in range(sides)])
for i in range(steps):
    for j in range(sides):
        f = bm.faces.new([rings[i][j], rings[i + 1][j], rings[i + 1][(j + 1) % sides], rings[i][(j + 1) % sides]])
        for l, (du, dv) in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
            l[uv].uv = ((i + du) / steps, (j + dv) / sides)
for end in (rings[0], rings[-1]):
    bm.faces.new(end)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
obj("Coil", bm, COPPER)
ring_out = body + 0.0003  # a thin steel lip, barely proud of the brass
obj("RingLow", tube(groove - SLEEVE, ring_out, cut[0], BAND[0]), STEEL)
obj("RingHigh", tube(groove - SLEEVE, ring_out, BAND[1], cut[1]), STEEL)

# The reactor: a shank down in the neck, ring, quartz window, ring; the nose screws on above.
reactor = obj("Reactor", revolve([(0.0, seat), (cal, seat), (cal, mouth + 0.0012), (0.0, mouth + 0.0012)]), GUN)
z = mouth + 0.0012
blue_h, window_h = 0.0013, 0.0085
obj("RingBlueLow", tube(cal * 0.7, cal + 0.0003, z, z + blue_h), BLUE, reactor)
z += blue_h
obj("Window", revolve([(cal, z), (cal, z + window_h)]), GLASS, reactor)
inner = cal * 0.62
# Inside the quartz, as in the user's reference: a black ceramic socket and cap, a small glass
# vacuum tube between them, in it a copper filament coil on two legs between two curved steel
# electrode plates; Core fills the tube and is what glows once it's charged (electric_fx.gd).
cap_h = 0.0007
obj("Socket", revolve([(0.0, z), (inner * 1.12, z), (inner * 1.12, z + cap_h), (0.0, z + cap_h)], 32), CERAMIC, reactor)
obj("TopCap", revolve([(0.0, z + window_h - cap_h), (inner * 1.12, z + window_h - cap_h), (inner * 1.12, z + window_h), (0.0, z + window_h)], 32), CERAMIC, reactor)
t0, t1 = z + cap_h, z + window_h - cap_h
obj("Tube", revolve([(inner, t0), (inner, t1 - inner * 0.5)] + [(inner * math.cos(u), t1 - inner * 0.5 + inner * 0.5 * math.sin(u)) for u in [i * math.pi / 2 / 6 for i in range(1, 7)]] + [(0.0, t1)], 32), GLASS, reactor)
obj("Core", revolve([(0.0, t0 + 0.0002), (inner * 0.9, t0 + 0.0002), (inner * 0.9, t1 - inner * 0.5), (0.0, t1 - 0.0003)], 24), GLOW, reactor)
fr, fw, fturns = inner * 0.42, 0.00016, 8
fz0, fz1 = t0 + (t1 - t0) * 0.42, t0 + (t1 - t0) * 0.82  # up in the tube, over the bar
bm = bmesh.new()
bar = t0 + (t1 - t0) * 0.3
path = [Vector((fr, 0.0, bar))]  # one leg up from the bar, the coil, the other leg down
n = fturns * 20
path += [Vector((fr * math.cos(2 * math.pi * fturns * i / n), fr * math.sin(2 * math.pi * fturns * i / n), fz0 + (fz1 - fz0) * i / n)) for i in range(n + 1)]
path += [Vector((fr * math.cos(2 * math.pi * fturns), fr * math.sin(2 * math.pi * fturns), bar))]
rings = []
for i, c in enumerate(path):
    d = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
    side = d.cross(Vector((0, 0, 1))) if abs(d.z) < 0.95 else d.cross(Vector((1, 0, 0)))
    side.normalize()
    up = side.cross(d)
    rings.append([bm.verts.new(c + fw * (math.cos(2 * math.pi * j / 6) * side + math.sin(2 * math.pi * j / 6) * up)) for j in range(6)])
for i in range(len(rings) - 1):
    for j in range(6):
        bm.faces.new([rings[i][j], rings[i + 1][j], rings[i + 1][(j + 1) % 6], rings[i][(j + 1) % 6]])
obj("Filament", bm, FILAMENT, reactor)
bm = bmesh.new()  # the frame it hangs in: two thin posts up the sides and a bar across under it
post = 0.00012
for sx in (-1, 1):
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=post, radius2=post, depth=t1 - t0 - inner * 0.5,
                          matrix=Matrix.Translation((sx * inner * 0.72, 0.0, (t0 + t1 - inner * 0.5) / 2)))
bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0.0, 0.0, bar)) @ Matrix.Diagonal((inner * 1.44, post * 2.5, post * 2.5, 1)))
obj("Plates", bm, STEEL, reactor)
z += window_h
obj("RingBlueHigh", tube(cal * 0.7, cal + 0.0003, z, z + blue_h), BLUE, reactor)
z += blue_h
# Nose: tangent ogive, calibre at its foot, its first 2.4 mm knurled.
L = 0.019
rho = (cal * cal + L * L) / (2 * cal)
prof = [(0.0, z - 0.0001), (cal, z)]
for i in range(1, 25):
    h = L * i / 24
    prof.append((max(math.sqrt(max(rho * rho - h * h, 0.0)) - (rho - cal), 0.0), z + h))
prof[-1] = (0.0, z + L)
obj("Nose", revolve(prof, SEGS, knurl=(z + 0.0003, z + 0.0024, 0.00022)), GUN)

for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
print("ELECTRIC mouth %.4f body %.4f cal %.4f top %.4f" % (mouth, body, cal, z + L))
