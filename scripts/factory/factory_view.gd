extends Node3D
## Draws the factory: one MultiMesh per mesh of each kind of structure, one per kind of item on the
## belts, instances reused; no node per item. Solid machines get a box to bump into; belts are walked
## on. Everything comes from the tables (data/machines.json model, kutu, renk; items.json renk,
## hurda.json glb), so new assets are a new path in a row. Only reads the simulation.

const BELT_TOP := 0.14  # m above the ground: where items ride
const ITEM_MAX := 0.45  # m: a scrap piece is drawn no bigger than this on a belt, whatever it weighs
const INGOT := Vector3(0.24, 0.1, 0.24)
const FAR := 70.0  # m from the camera where items stop being drawn
const REDRAW := 1.0 / 30.0  # s between item redraws
const SOLID_LAYER := 1  # GameState.SHOT_MASK's world layer: blocks players, stops rounds

var factory: Node
var draw_us := 0  # measured: last item redraw
var drawn := 0  # items drawn at the last redraw

var _version := -1
var _parts := {}  # kind -> [[Mesh, Transform3D (fits it to its footprint)]]
var _kind_mm := {}  # kind -> [MultiMeshInstance3D]
var _bodies: Array[StaticBody3D] = []
var _damps: Array[Decal] = []
static var _damp_tex: ImageTexture
var _looks := {}  # item -> look
var _active: Array = []  # the looks with something to draw this time
var _line_pts: Array[PackedVector3Array] = []  # per line: cell centres, the exit one past the last
var _wait := 0.0


class Look:
	var mesh: Mesh
	var basis: Basis
	var mm: MultiMesh
	var buf := PackedFloat32Array()
	var n := 0
	var cap := 0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	var sim: FactorySim = factory.sim
	if sim.layout_version != _version and not sim.dirty:
		_version = sim.layout_version
		_redraw_structures(sim)
		_line_points(sim)
	_wait -= delta
	if _wait <= 0.0:
		_wait = REDRAW
		_redraw_items(sim)


# --- Structures ---

func _redraw_structures(sim: FactorySim) -> void:
	var per_kind := {}
	for s in sim.kind.size():
		if sim.kind[s] >= 0:
			if not per_kind.has(sim.kind[s]):
				per_kind[sim.kind[s]] = PackedInt32Array()
			var list: PackedInt32Array = per_kind[sim.kind[s]]
			list.append(s)
	for k: int in _kind_mm:
		for mmi: MultiMeshInstance3D in _kind_mm[k]:
			mmi.multimesh.visible_instance_count = 0
	for b in _bodies:
		b.queue_free()
	_bodies.clear()
	for d in _damps:
		d.queue_free()
	_damps.clear()
	for k: int in per_kind:
		var list: PackedInt32Array = per_kind[k]
		var parts := parts_of(k)
		if not _kind_mm.has(k):
			_kind_mm[k] = []
			for part: Array in parts:
				var mmi := MultiMeshInstance3D.new()
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = part[0]
				mmi.multimesh = mm
				add_child(mmi)
				_kind_mm[k].append(mmi)
		for p in parts.size():
			var mm: MultiMesh = _kind_mm[k][p].multimesh
			if mm.instance_count < list.size():
				mm.instance_count = list.size() + 16
			for i in list.size():
				mm.set_instance_transform(i, placed(sim, list[i]) * (parts[p][1] as Transform3D))
			mm.visible_instance_count = list.size()
		if sim.data.kinds[k].tur_i != FactoryData.Tur.BANT:
			for s in list:
				_add_body(sim, s)
				_add_damp(sim, s)


## Where structure `s` stands: the middle of its footprint on the ground, its front along its dir.
func placed(sim: FactorySim, s: int) -> Transform3D:
	return placed_at(sim, sim.kind[s], sim.cell_x(sim.cell[s]), sim.cell_z(sim.cell[s]), sim.dir[s])


func placed_at(sim: FactorySim, k: int, x: int, z: int, d: int) -> Transform3D:
	var f := sim.footprint(k, d)
	return Transform3D(Basis(Vector3.UP, -d * PI * 0.5), Vector3(x + f.x * 0.5, 0.0, z + f.y * 0.5))


func _add_body(sim: FactorySim, s: int) -> void:
	var row: Dictionary = sim.data.kinds[sim.kind[s]]
	var body := StaticBody3D.new()
	body.collision_layer = SOLID_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(row.d, row.kutu[1], row.w)
	shape.shape = box
	shape.position.y = row.kutu[1] * 0.5
	body.add_child(shape)
	add_child(body)
	body.global_transform = placed(sim, s)
	_bodies.append(body)


## The floor round what stands on it is baked damp and dark at build time (tools/build_world.gd
## _floor_map); a crate or machine put down in play gets the same as a decal under it, ragged, turned
## by its cell. Only drawn, from the simulation's layout: every peer puts the same, nothing crosses the
## network. Sizes and colour are my guess.
const DAMP_MARGIN := 1.1  # m past what's drawn, on each side
const DAMP_COLOR := Color(0.09, 0.085, 0.05, 0.85)  # the alpha: how dark at the foot


func _add_damp(sim: FactorySim, s: int) -> void:
	var d := Decal.new()
	d.texture_albedo = _damp_texture()
	d.modulate = DAMP_COLOR
	d.albedo_mix = 1.0
	d.upper_fade = 0.6
	d.lower_fade = 0.3
	d.distance_fade_enabled = true
	d.distance_fade_begin = 45.0
	d.distance_fade_length = 15.0
	var wide := _drawn(sim.kind[s]) + Vector2.ONE * DAMP_MARGIN * 2.0
	d.size = Vector3(wide.x, 0.5, wide.y)  # up the thing's foot a hand, no more
	add_child(d)
	var xf := placed(sim, s)
	var turn := PI * float(sim.cell[s] % 2)  # one texture, turned by cell: not every stain the same
	d.global_transform = Transform3D(xf.basis * Basis(Vector3.UP, turn), xf.origin)
	_damps.append(d)


## How big `k` is drawn across, x and z as it stands (the model can stand out of its footprint).
func _drawn(k: int) -> Vector2:
	var row: Dictionary = factory.sim.data.kinds[k]
	var all := AABB(Vector3(-row.d * 0.5, 0.0, -row.w * 0.5), Vector3(row.d, 0.1, row.w))
	for part: Array in parts_of(k):
		all = all.merge((part[1] as Transform3D) * (part[0] as Mesh).get_aabb())
	return Vector2(all.size.x, all.size.z)


## White where it's damp, alpha falling off from the middle with a ragged, noisy edge; the same on
## every machine (fixed seed).
static func _damp_texture() -> ImageTexture:
	if _damp_tex:
		return _damp_tex
	const N := 64
	var noise := FastNoiseLite.new()
	noise.seed = 4127
	noise.frequency = 0.09
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var p := Vector2(x + 0.5, y + 0.5) / N * 2.0 - Vector2.ONE
			var r := p.length() + noise.get_noise_2d(x, y) * 0.28
			var a := pow(clampf(1.0 - smoothstep(0.35, 0.95, r), 0.0, 1.0), 1.3)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_damp_tex = ImageTexture.create_from_image(img)
	return _damp_tex


## A kind's look: its model's meshes fitted into its footprint, standing on the ground; no model (or
## none that loads), the box from its row. Each is [Mesh, Transform3D].
func parts_of(k: int) -> Array:
	if _parts.has(k):
		return _parts[k]
	var row: Dictionary = factory.sim.data.kinds[k]
	var parts := []
	var path: String = row.get("model", "")
	if path != "" and ResourceLoader.exists(path):
		parts = _model_parts(path, Vector3(row.d, row.kutu[1], row.w))
	elif path != "":
		push_warning("factory: no model at " + path)
	if parts.is_empty():
		var box := BoxMesh.new()
		box.size = Vector3(row.kutu[0], row.kutu[1], row.kutu[2])
		box.material = _flat(Color.from_string(row.get("renk", "#444444"), Color.GRAY))
		parts = [[box, Transform3D(Basis.IDENTITY, Vector3.UP * row.kutu[1] * 0.5)]]
	_parts[k] = parts
	return parts


func _model_parts(path: String, fit: Vector3) -> Array:
	var scene := load(path) as PackedScene
	if scene == null:
		return []
	var root: Node = scene.instantiate()
	var found: Array = []
	_collect(root, Transform3D.IDENTITY, found)
	root.free()
	if found.is_empty():
		return []
	var box: AABB = found[0][1] * (found[0][0] as Mesh).get_aabb()
	for f: Array in found:
		box = box.merge(f[1] * (f[0] as Mesh).get_aabb())
	var longest := maxf(box.size.x / fit.x, box.size.z / fit.z)
	var scale_by := 1.0 / maxf(longest, 0.001)
	var fitted := Transform3D(Basis().scaled(Vector3.ONE * scale_by), Vector3.ZERO)
	fitted.origin = -scale_by * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var parts := []
	for f: Array in found:
		parts.append([f[0], fitted * (f[1] as Transform3D)])
	return parts


func _collect(n: Node, at: Transform3D, found: Array) -> void:
	var t := at
	if n is Node3D:
		t = at * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		found.append([(n as MeshInstance3D).mesh, t])
	for c in n.get_children():
		_collect(c, t, found)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


# --- Items ---

func _line_points(sim: FactorySim) -> void:
	_line_pts.clear()
	for slots in sim.l_slots:
		var pts := PackedVector3Array()
		for s in slots:
			pts.append(Vector3(sim.cell_x(sim.cell[s]) + 0.5, BELT_TOP, sim.cell_z(sim.cell[s]) + 0.5))
		var last := slots[-1]
		pts.append(pts[-1] + Vector3(FactorySim.DIR_X[sim.dir[last]], 0.0, FactorySim.DIR_Z[sim.dir[last]]))
		_line_pts.append(pts)


func _redraw_items(sim: FactorySim) -> void:
	if _line_pts.size() != sim.l_slots.size():
		return  # the lines were just remade; the next pass has their points
	var t0 := Time.get_ticks_usec()
	for look: Look in _active:
		look.n = 0
	_active.clear()
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else Vector3.ZERO
	var far2 := FAR * FAR if cam else INF
	var total := 0
	# Items ride between steps too: what's free to move has moved on by this much of a step.
	var ahead := clampf(factory._accum * FactorySim.TICK_HZ, 0.0, 1.0)
	for l in sim.l_len.size():
		var items := sim.l_items[l]
		var n := items.size()
		if n == 0:
			continue
		var pts := _line_pts[l]
		var gaps := sim.l_gaps[l]
		var length := sim.l_len[l]
		var first := sim.l_first[l]
		var shift := int(sim.l_speed[l] * ahead)
		var d := 0
		for i in n:
			d += gaps[i] + (FactorySim.SPACING if i > 0 else 0)
			var u := length - d
			if i >= first:
				u = mini(u + shift, length)
			var c := u / FactorySim.CELL_UNITS
			var f := float(u - c * FactorySim.CELL_UNITS) / FactorySim.CELL_UNITS
			var a := pts[c]
			var p := a if f == 0.0 else a.lerp(pts[c + 1], f)
			if p.distance_squared_to(eye) > far2:
				continue
			var look: Look = _looks.get(items[i])
			if look == null:
				look = _new_look(sim, items[i])
			if look.n == 0:
				_active.append(look)
			if look.n == look.cap:
				_grow(look)
			var k := look.n * 12
			var buf := look.buf
			buf[k + 3] = p.x
			buf[k + 7] = p.y
			buf[k + 11] = p.z
			look.n += 1
			total += 1
	for it: int in _looks:
		var look: Look = _looks[it]
		if look.n > 0:
			if look.mm.instance_count != look.cap:
				look.mm.instance_count = look.cap
			look.mm.buffer = look.buf
		look.mm.visible_instance_count = look.n
	drawn = total
	draw_us = Time.get_ticks_usec() - t0


func _new_look(sim: FactorySim, it: int) -> Look:
	var look := Look.new()
	var row: Dictionary = sim.data.items[it]
	if it >= sim.data.scrap_first:
		look.mesh = _scrap_mesh(row)
	if look.mesh == null:
		var box := BoxMesh.new()
		box.size = INGOT
		box.material = _flat(Color.from_string(row.get("renk", "#666666"), Color.GRAY))
		look.mesh = box
		look.basis = Basis.IDENTITY
	else:
		var size := look.mesh.get_aabb().size
		var longest := maxf(size.x, maxf(size.y, size.z))
		look.basis = Basis().scaled(Vector3.ONE * minf(ITEM_MAX / maxf(longest, 0.001), 1.0))
	look.mm = MultiMesh.new()
	look.mm.transform_format = MultiMesh.TRANSFORM_3D
	look.mm.mesh = look.mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = look.mm
	add_child(mmi)
	_looks[it] = look
	return look


func _scrap_mesh(row: Dictionary) -> Mesh:
	var path: String = String(row.glb).get_basename() + "_psx.scn"
	if not ResourceLoader.exists(path):
		path = row.glb
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root: Node = scene.instantiate()
	var found: Array = []
	_collect(root, Transform3D.IDENTITY, found)
	root.free()
	return found[0][0] if not found.is_empty() else null


## Room for more of this look; each slot's scale is written once, only its position changes after.
func _grow(look: Look) -> void:
	var from := look.cap
	look.cap = maxi(look.cap * 2, 16)
	look.buf.resize(look.cap * 12)
	var b := look.basis
	for i in range(from, look.cap):
		var k := i * 12
		look.buf[k] = b.x.x
		look.buf[k + 1] = b.y.x
		look.buf[k + 2] = b.z.x
		look.buf[k + 3] = 0.0
		look.buf[k + 4] = b.x.y
		look.buf[k + 5] = b.y.y
		look.buf[k + 6] = b.z.y
		look.buf[k + 7] = 0.0
		look.buf[k + 8] = b.x.z
		look.buf[k + 9] = b.y.z
		look.buf[k + 10] = b.z.z
		look.buf[k + 11] = 0.0
