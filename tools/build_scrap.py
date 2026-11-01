# Blender (5.x, background): the scrap that fills the hall (scripts/pile.gd), one glb per piece in
# assets/scrap/, plus data/scrap_parts.json (name, size, kind) that pile.gd reads. Run from the project root.
#   blender -b --factory-startup -P tools/build_scrap.py -- <polyhaven dir> <ambientcg dir> <out dir>
# <polyhaven dir>: one folder per Poly Haven model id with its 1k glTF (api.polyhaven.com/files/<id>).
# <ambientcg dir>: one folder per ambientCG set id with its 1K-JPG maps (Rust004, Metal041B, ...).
# Poly Haven models are brought down to TRIS triangles and 512 px maps: thousands of them lie in
# the heap at once. Sets are split, every part its own piece (docs/ayrintilar.md, "Yeni yön:
# hurdalık": the user's rule). Springs, gears, bolts, nuts, chain, pipe and bent sheet are made
# here, too few good free models of them exist, and dressed in ambientCG rust and sheet metal.
import bpy, bmesh, sys, os, glob, json, math, random
from mathutils import Vector, Matrix

ph_dir, acg_dir, out_dir = sys.argv[sys.argv.index("--") + 1:][:3]
os.makedirs(out_dir, exist_ok=True)
TRIS = 900          # most pieces
TRIS_BIG = 1600     # crates, tyres, rims: seen larger
TEX = 512
# Sets: model id -> parts, each a list of object-name substrings that make one piece.
SETS = {
	"russian_food_cans_01": [["salt_box"], ["can_cond"], ["can_fish"]],
	"spray_paint_bottles_02": [["spray_paint_bottles_02_dented"], ["!dented"]],
	"old_military_crate": [["_a"], ["_b"]],
}
BIG = {"old_tyre", "rusted_wheel_rim_01", "rusted_wheel_rim_02", "wooden_crate_01", "wooden_crate_02",
	"old_military_crate", "wooden_military_crate", "plastic_crate_03", "cardboard_box_01", "boombox",
	"metal_toolbox", "small_lpg_tank", "metal_jerrycan", "metal_jerrycan_green"}
# What each piece is for the heap's mix (pile.gd KIND_WEIGHT): crates are few, the small metal many.
KIND = {
	"wooden_crate_01": "crate", "wooden_crate_02": "crate", "old_military_crate": "crate",
	"wooden_military_crate": "crate", "plastic_crate_03": "crate", "cardboard_box_01": "crate",
	"ammo_box": "box", "metal_toolbox": "box", "boombox": "box", "retro_multimeter": "box",
	"old_tyre": "wheel", "rusted_wheel_rim_01": "wheel", "rusted_wheel_rim_02": "wheel",
	"metal_jerrycan": "can_big", "metal_jerrycan_green": "can_big", "small_lpg_tank": "can_big",
	"watering_can_metal_01": "can_big", "metal_jug": "can",
}
parts = []


def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)


def meshes():
	return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def tri_count(objs):
	return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def join(objs):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.data = o.data.copy()  # sets share meshes between their parts
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	if len(objs) > 1:
		bpy.ops.object.join()
	o = bpy.context.view_layer.objects.active
	bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	return o


def centre(o):
	"""Origin to the middle of its box: pile.gd lays pieces by their centre."""
	lo = Vector([min((v.co[i] for v in o.data.vertices)) for i in range(3)])
	hi = Vector([max((v.co[i] for v in o.data.vertices)) for i in range(3)])
	c = (lo + hi) / 2
	o.data.transform(Matrix.Translation(-c))
	return hi - lo


def decimate(o, tris):
	if o.data.shape_keys:
		o.shape_key_clear()
	n = tri_count([o])
	if n > tris:
		m = o.modifiers.new("dec", "DECIMATE")
		m.ratio = tris / n
		bpy.context.view_layer.objects.active = o
		bpy.ops.object.modifier_apply(modifier=m.name)


def shrink_images():
	for img in bpy.data.images:
		if img.size[0] > TEX:
			img.scale(TEX, TEX * img.size[1] // img.size[0])
			img.pack()


def export(o, name, size, kind):
	bpy.ops.object.select_all(action="DESELECT")
	o.select_set(True)
	bpy.context.view_layer.objects.active = o
	o.name = name
	path = os.path.join(out_dir, name + ".glb")
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
		export_yup=True, export_apply=True, export_image_format="JPEG", export_image_quality=85)
	# Blender is Z up; the glb, and Godot, Y up.
	parts.append({"name": name, "size": [round(size.x, 3), round(size.z, 3), round(size.y, 3)], "kind": kind})
	print("PART", name, tri_count([o]), "%.2f %.2f %.2f" % (size.x, size.y, size.z), flush=True)


# --- Poly Haven ---------------------------------------------------------------------------------

for sub in sorted(os.listdir(ph_dir)):
	g = glob.glob(os.path.join(ph_dir, sub, "*.gltf"))
	if not g:
		continue
	reset()
	bpy.ops.import_scene.gltf(filepath=g[0])
	all_objs = meshes()
	groups = []
	for keys in SETS.get(sub, [[""]]):
		def wanted(o):
			return all((k[1:] not in o.name) if k.startswith("!") else (k in o.name) for k in keys)
		groups.append([o for o in all_objs if wanted(o)])
	shrink_images()
	for n, objs in enumerate(groups):
		if not objs:
			print("EMPTY", sub, n)
			continue
		o = join(objs)
		decimate(o, TRIS_BIG if sub in BIG else TRIS)
		size = centre(o)
		name = sub if len(groups) == 1 else "%s_%d" % (sub, n + 1)
		export(o, name, size, KIND.get(sub, "small"))
		bpy.data.objects.remove(o)


# --- made here ----------------------------------------------------------------------------------

def acg_material(set_id, tint=(1, 1, 1)):
	"""ambientCG maps (Color, NormalGL, Roughness, Metalness) as a Principled material."""
	m = bpy.data.materials.new(set_id)
	m.use_nodes = True
	nt = m.node_tree
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	d = os.path.join(acg_dir, set_id)
	def tex(suffix, colour):
		f = glob.glob(os.path.join(d, "*_" + suffix + ".jpg"))
		if not f:
			return None
		node = nt.nodes.new("ShaderNodeTexImage")
		node.image = bpy.data.images.load(f[0])
		node.image.colorspace_settings.name = "sRGB" if colour else "Non-Color"
		return node
	c = tex("Color", True)
	if c:
		if tint != (1, 1, 1):
			mix = nt.nodes.new("ShaderNodeMix")
			mix.data_type = "RGBA"
			mix.blend_type = "MULTIPLY"
			mix.inputs["Factor"].default_value = 1.0
			nt.links.new(c.outputs["Color"], mix.inputs[6])
			mix.inputs[7].default_value = (*tint, 1)
			nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
		else:
			nt.links.new(c.outputs["Color"], bsdf.inputs["Base Color"])
	r = tex("Roughness", False)
	if r:
		nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
	mt = tex("Metalness", False)
	if mt:
		nt.links.new(mt.outputs["Color"], bsdf.inputs["Metallic"])
	else:
		bsdf.inputs["Metallic"].default_value = 0.6
	nm = tex("NormalGL", False)
	if nm:
		nmap = nt.nodes.new("ShaderNodeNormalMap")
		nt.links.new(nm.outputs["Color"], nmap.inputs["Color"])
		nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
	return m


def finish(o, mat, name, kind, uv_scale=1.0):
	bpy.context.view_layer.objects.active = o
	o.select_set(True)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.cube_project(cube_size=uv_scale)
	bpy.ops.object.mode_set(mode="OBJECT")
	bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
	o.data.materials.clear()
	o.data.materials.append(mat)
	shrink_images()
	size = centre(o)
	export(o, name, size, kind)
	bpy.data.objects.remove(o)


def mesh_object(bm, name):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(o)
	return o


def spring(name, radius, wire, coils, pitch, mat):
	curve = bpy.data.curves.new(name, "CURVE")
	curve.dimensions = "3D"
	curve.bevel_depth = wire
	curve.bevel_resolution = 2
	sp = curve.splines.new("POLY")
	steps = int(coils * 14)
	sp.points.add(steps)
	for i in range(steps + 1):
		a = i / 14 * math.tau
		# Closed, ground ends: the last quarter turn at each end lies flat.
		z = min(max(i / 14 - 0.25, 0), coils - 0.5) * pitch
		sp.points[i].co = (math.cos(a) * radius, math.sin(a) * radius, z, 1)
	o = bpy.data.objects.new(name, curve)
	bpy.context.scene.collection.objects.link(o)
	bpy.context.view_layer.objects.active = o
	o.select_set(True)
	bpy.ops.object.convert(target="MESH")
	finish(bpy.context.view_layer.objects.active, mat, name, "small", 0.05)


def gear(name, radius, teeth, depth, thick, hole, mat, spokes=0):
	bm = bmesh.new()
	outer = []
	n = teeth * 4
	for i in range(n):
		a = i / n * math.tau
		r = radius if (i % 4) in (1, 2) else radius - depth
		outer.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0)))
	inner = [bm.verts.new((math.cos(i / n * math.tau) * hole, math.sin(i / n * math.tau) * hole, 0)) for i in range(n)]
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((outer[i], outer[j], inner[j], inner[i]))
	ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
	bmesh.ops.translate(bm, vec=(0, 0, thick), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	o = mesh_object(bm, name)
	bev = o.modifiers.new("bev", "BEVEL")
	bev.width = thick * 0.08
	bev.segments = 1
	bpy.context.view_layer.objects.active = o
	bpy.ops.object.modifier_apply(modifier=bev.name)
	finish(o, mat, name, "small", radius)


def nut(name, size, thick, mat):
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=size, radius2=size, depth=thick)
	o = mesh_object(bm, name)
	hole = bpy.data.objects.new("hole", bpy.data.meshes.new("hole"))
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=size * 0.5, radius2=size * 0.5, depth=thick * 3)
	bm.to_mesh(hole.data)
	bm.free()
	bpy.context.scene.collection.objects.link(hole)
	b = o.modifiers.new("hole", "BOOLEAN")
	b.object = hole
	bpy.context.view_layer.objects.active = o
	bpy.ops.object.modifier_apply(modifier=b.name)
	bpy.data.objects.remove(hole)
	finish(o, mat, name, "small", size * 2)


def bolt(name, head, length, mat):
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=head, radius2=head, depth=head * 0.7,
		matrix=Matrix.Translation((0, 0, length / 2 + head * 0.35)))
	bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=head * 0.55, radius2=head * 0.55, depth=length)
	# A bend: half of the bolts in a heap were pulled out crooked.
	bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(random.uniform(-0.25, 0.25), 3, "X"),
		verts=[v for v in bm.verts if v.co.z < -length * 0.1])
	finish(mesh_object(bm, name), mat, name, "small", head * 2)


def chain(name, links, link_len, wire, mat):
	bm = bmesh.new()
	for k in range(links):
		# An elongated torus: two half rings joined by straights.
		ring = []
		segs = 16
		r = link_len * 0.3
		straight = link_len * 0.4
		for i in range(segs):
			a = i / segs * math.tau
			off = straight / 2 if math.cos(a) >= 0 else -straight / 2
			ring.append((math.cos(a) * r + off, math.sin(a) * r))
		rings = []  # a six-sided tube round the ring
		for i, (x, y) in enumerate(ring):
			nx, ny = ring[(i + 1) % segs]
			px, py = ring[i - 1]
			t = Vector((nx - px, ny - py, 0)).normalized()
			nrm = Vector((t.y, -t.x, 0))
			circ = [bm.verts.new(Vector((x, y, 0)) + (nrm * math.cos(j / 6 * math.tau) + Vector((0, 0, 1)) * math.sin(j / 6 * math.tau)) * wire) for j in range(6)]
			rings.append(circ)
		for i in range(segs):
			a, b2 = rings[i], rings[(i + 1) % segs]
			for j in range(6):
				bm.faces.new((a[j], a[(j + 1) % 6], b2[(j + 1) % 6], b2[j]))
		new = [v for c in rings for v in c]
		# Every other link stands up, each one through the last, with some slack.
		rot = Matrix.Rotation(math.pi / 2 if k % 2 else 0, 3, "X") @ Matrix.Rotation(random.uniform(-0.3, 0.3), 3, "Z")
		bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=rot, verts=new)
		bmesh.ops.translate(bm, vec=(k * (link_len - wire * 2.6), 0, random.uniform(-0.01, 0.01)), verts=new)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	finish(mesh_object(bm, name), mat, name, "small", link_len)


def pipe(name, radius, length, wall, bend, mat):
	curve = bpy.data.curves.new(name, "CURVE")
	curve.dimensions = "3D"
	curve.bevel_depth = radius
	curve.bevel_resolution = 3
	sp = curve.splines.new("POLY")
	steps = 10
	sp.points.add(steps)
	for i in range(steps + 1):
		t = i / steps
		a = t * bend
		if bend > 0.01:
			rr = length / bend
			sp.points[i].co = (math.sin(a) * rr, 0, (1 - math.cos(a)) * rr, 1)
		else:
			sp.points[i].co = (t * length, 0, 0, 1)
	o = bpy.data.objects.new(name, curve)
	bpy.context.scene.collection.objects.link(o)
	bpy.context.view_layer.objects.active = o
	o.select_set(True)
	bpy.ops.object.convert(target="MESH")
	o = bpy.context.view_layer.objects.active
	s = o.modifiers.new("wall", "SOLIDIFY")
	s.thickness = wall
	bpy.ops.object.modifier_apply(modifier=s.name)
	finish(o, mat, name, "small", radius * 4)


def sheet(name, w, h, crumple, seed, mat):
	random.seed(seed)
	bm = bmesh.new()
	bmesh.ops.create_grid(bm, x_segments=10, y_segments=8, size=0.5)
	for v in bm.verts:
		x, y = v.co.x * w, v.co.y * h
		# A fold across the sheet and some dents, then torn corners pulled in.
		fold = math.sin(x / w * math.pi * random.uniform(0.5, 1.5) + seed) * crumple
		v.co = Vector((x, y, fold + random.uniform(-0.3, 0.3) * crumple))
	corner = random.choice(bm.verts[:])
	bmesh.ops.delete(bm, geom=[corner], context="VERTS")
	o = mesh_object(bm, name)
	s = o.modifiers.new("t", "SOLIDIFY")
	s.thickness = 0.004
	bpy.context.view_layer.objects.active = o
	bpy.ops.object.modifier_apply(modifier=s.name)
	finish(o, mat, name, "sheet", max(w, h))


reset()
random.seed(11)
rust = acg_material("Rust004")
steel = acg_material("Metal041B")
copper = acg_material("Metal041B", (1.0, 0.62, 0.4))
for i, (r, wire, coils, pitch) in enumerate([(0.03, 0.004, 7, 0.016), (0.05, 0.007, 5, 0.03), (0.02, 0.0025, 10, 0.009), (0.07, 0.01, 6, 0.04)]):
	spring("spring_%d" % (i + 1), r, wire, coils, pitch, rust if i % 2 == 0 else steel)
for i, (r, teeth, depth, thick, hole) in enumerate([(0.06, 18, 0.008, 0.015, 0.012), (0.11, 30, 0.01, 0.02, 0.025),
		(0.035, 12, 0.006, 0.012, 0.008), (0.16, 42, 0.012, 0.025, 0.04), (0.08, 24, 0.009, 0.03, 0.015)]):
	gear("gear_%d" % (i + 1), r, teeth, depth, thick, hole, [rust, steel, copper][i % 3])
for i, (s, t) in enumerate([(0.012, 0.01), (0.02, 0.016), (0.03, 0.022)]):
	nut("nut_%d" % (i + 1), s, t, steel if i else rust)
for i, (hd, ln) in enumerate([(0.01, 0.06), (0.016, 0.12), (0.022, 0.18)]):
	bolt("bolt_%d" % (i + 1), hd, ln, rust)
for i, (links, ll, wire) in enumerate([(6, 0.05, 0.006), (4, 0.09, 0.011), (9, 0.035, 0.004)]):
	chain("chain_%d" % (i + 1), links, ll, wire, rust)
for i, (r, ln, bend) in enumerate([(0.02, 0.4, 0.0), (0.03, 0.3, math.pi / 2), (0.012, 0.5, 0.6), (0.045, 0.35, 0.0)]):
	pipe("pipe_%d" % (i + 1), r, ln, 0.003, bend, copper if i == 2 else rust)
sheet_mats = [acg_material(s) for s in ("SheetMetal004", "Rust004", "MetalPlates013", "DiamondPlate008C")]
for i in range(6):
	sheet("sheet_%d" % (i + 1), random.uniform(0.25, 0.6), random.uniform(0.2, 0.45), random.uniform(0.01, 0.06), i, sheet_mats[i % len(sheet_mats)])

with open(os.path.join("data", "scrap_parts.json"), "w") as f:
	json.dump(parts, f, indent=1)
print("PARTS", len(parts))
