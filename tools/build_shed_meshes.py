# Blender (5.x, background) generator for the range shed: beveled precast wall panel, H column,
# 56 m roof truss, purlin, corrugated roof with skylight gaps, skylight strips, gable cladding.
# Every edge gets a small bevel + weighted normals so nothing reads razor-sharp.
# Run: blender -b --factory-startup -P tools/build_shed_meshes.py -- <out_dir>
# Authored Blender Z-up with X = Godot X; exported Y-up, -Z forward (Godot axes).
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)

# Shed dimensions (m), shared with tools/build_arena.gd.
HALF_SPAN = 27.7          # truss end to centre (columns' inner faces)
EAVE = 8.8                # top chord height at the truss ends
BOTTOM = 8.0              # bottom chord height
PITCH = math.radians(6.0)
CHORD = 0.18              # chord tube size
ROOF_EDGE = 28.6          # roof sheet reaches past the walls (overhang)
LENGTH = 57.2             # roof length along Godot Z
SKYLIGHTS = [(6.5, 9.5), (17.5, 20.5)]   # |x| ranges left open for skylight strips

def top_chord(x): return EAVE + (HALF_SPAN - abs(x)) * math.tan(PITCH)
def sheet_z(x): return top_chord(x) + CHORD / 2 + 0.2 + 0.0075   # on 0.2 m purlins

def new_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob

def box(bm, center, size, rot=None):
    m = Matrix.Translation(center) @ (rot.to_4x4() if rot else Matrix.Identity(4)) @ Matrix.Diagonal((*size, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)

def member(bm, a, b, w, h):
    """Box from a to b (Blender coords), w across (Y), h in the a-b-Z plane."""
    d = b - a
    rot = d.normalized().to_track_quat("X", "Z").to_matrix()
    box(bm, (a + b) / 2, (d.length, w, h), rot)

def box_uv(ob, scale, u_axis_for=None, offset=(0.0, 0.0)):
    """World-scale box mapping; u_axis_for(normal_axis) -> (u_axis, v_axis) overrides."""
    me = ob.data
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        u, v = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[ax]
        if u_axis_for:
            u, v = u_axis_for(ax, (u, v))
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (co[u] / scale + offset[0], co[v] / scale + offset[1])

def finish_and_export(ob, bevel, segments=3):
    if bevel > 0:
        b = ob.modifiers.new("Bevel", "BEVEL")
        b.width = bevel; b.segments = segments; b.limit_method = "ANGLE"
        b.angle_limit = math.radians(30)
        w = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
        w.mode = "FACE_AREA"; w.keep_sharp = True
    for o in bpy.context.scene.objects: o.select_set(o == ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.wm.obj_export(filepath=os.path.join(OUT, ob.name + ".obj"), export_selected_objects=True,
        forward_axis="NEGATIVE_Z", up_axis="Y", apply_modifiers=True, export_materials=False,
        export_normals=True, export_uv=True, export_triangulated_mesh=True)
    print("exported", ob.name, len(ob.data.polygons), "faces before modifiers")

bpy.ops.wm.read_factory_settings(use_empty=True)

# Precast wall panel: 4 m wide (1 cm joint), 4 m tall, 0.3 m thick; pivot at bottom centre.
bm = bmesh.new(); box(bm, Vector((0, 0, 2.0)), (3.99, 0.3, 4.0))
ob = new_obj("wall_panel", bm); box_uv(ob, 4.0, offset=(0.5, 0.0))  # one cast slab per panel; finish_and_export(ob, 0.025)

# H column (300 x 300), 8.95 m to the top chord; flanges along X; base and cap plates.
H = top_chord(HALF_SPAN) + CHORD / 2 + 0.06
bm = bmesh.new()
for s in (-1, 1):
    box(bm, Vector((0, s * (0.15 - 0.0095), H / 2)), (0.3, 0.019, H))
box(bm, Vector((0, 0, H / 2)), (0.011, 0.262, H))
box(bm, Vector((0, 0, 0.0125)), (0.42, 0.42, 0.025))
box(bm, Vector((0, 0, H - 0.0125)), (0.34, 0.34, 0.025))
ob = new_obj("column", bm); box_uv(ob, 1.0); finish_and_export(ob, 0.004, 2)

# Pratt truss in the XZ plane (Godot XY), centred on x = 0, 16 panels.
bm = bmesh.new()
nodes = [-HALF_SPAN + i * (2 * HALF_SPAN / 16) for i in range(17)]
member(bm, Vector((-HALF_SPAN, 0, BOTTOM)), Vector((HALF_SPAN, 0, BOTTOM)), CHORD, CHORD)
member(bm, Vector((-HALF_SPAN, 0, top_chord(HALF_SPAN))), Vector((0, 0, top_chord(0))), CHORD, CHORD)
member(bm, Vector((0, 0, top_chord(0))), Vector((HALF_SPAN, 0, top_chord(HALF_SPAN))), CHORD, CHORD)
for x in nodes:
    member(bm, Vector((x, 0, BOTTOM)), Vector((x, 0, top_chord(x))), 0.09, 0.09)
for i in range(16):
    a, b = nodes[i], nodes[i + 1]
    if b <= 0:   # left half: top at the outer node down to the bottom at the inner node
        member(bm, Vector((a, 0, top_chord(a))), Vector((b, 0, BOTTOM)), 0.08, 0.08)
    else:
        member(bm, Vector((b, 0, top_chord(b))), Vector((a, 0, BOTTOM)), 0.08, 0.08)
ob = new_obj("truss", bm); box_uv(ob, 1.0); finish_and_export(ob, 0.006, 2)

# Purlin: 0.08 x 0.2 section along Godot Z, centred.
bm = bmesh.new(); box(bm, Vector((0, 0, 0)), (0.08, LENGTH - 0.4, 0.2))
ob = new_obj("purlin", bm); box_uv(ob, 1.0); finish_and_export(ob, 0.004, 2)

def slope_strips(name, ranges, thick, bevel):
    bm = bmesh.new()
    for s in (-1, 1):
        for x0, x1 in ranges:
            member(bm, Vector((s * x0, 0, sheet_z(x0))), Vector((s * x1, 0, sheet_z(x1))), LENGTH, thick)
    ob = new_obj(name, bm)
    # corrugations run along V in the texture: put U along the building length so ribs run downhill
    box_uv(ob, 2.0, lambda ax, uv: (1, 0) if ax == 2 else uv)
    finish_and_export(ob, bevel, 2)

sheet_ranges, x = [], 0.0
for a, b in SKYLIGHTS:
    sheet_ranges.append((x, a)); x = b
sheet_ranges.append((x, ROOF_EDGE))
slope_strips("roof_sheet", sheet_ranges, 0.015, 0.003)
slope_strips("skylight", SKYLIGHTS, 0.01, 0.0)

# Gable cladding (one end, in the XZ plane at y = 0): from the bottom chord up to under the roof.
bm = bmesh.new()
outline = [(-ROOF_EDGE, BOTTOM), (ROOF_EDGE, BOTTOM), (ROOF_EDGE, sheet_z(ROOF_EDGE) - 0.02),
           (0, sheet_z(0) - 0.02), (-ROOF_EDGE, sheet_z(ROOF_EDGE) - 0.02)]
f = bm.faces.new([bm.verts.new((x, 0, z)) for x, z in outline])
ext = bmesh.ops.extrude_face_region(bm, geom=[f])
bmesh.ops.translate(bm, vec=(0, 0.012, 0), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
ob = new_obj("gable_cladding", bm); box_uv(ob, 2.0); finish_and_export(ob, 0.003, 2)
