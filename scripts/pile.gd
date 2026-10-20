class_name Pile
extends StaticBody3D
## The bullet pile as a real heap: a height field the count is carved out of. Every take digs
## where it happened; slopes steeper than the angle of repose slide down over the next frames,
## so a spot that keeps getting drained turns into a funnel and its sides pour in.
## Spilled floor bullets are individual, numbered, and get picked up one by one.
## Co-op: only GameState events cross the network (bullets_taken for the heap, loose_taken by
## id for single bullets); every peer digs and removes locally.
# Every peer runs the same digs through the same slide passes, so heights match bit for bit
# (tools/net_check.gd compares them). Joining mid-game needs _h sent once (Faz 1/8).

const BULLET_VOLUME := 3.8e-6  # m³ per 9mm cartridge incl. gaps in a loose heap
const SLOPE := 0.577           # tan(30°), angle of repose
const BULLET_SCALE := 0.03     # model is ~2.9 units long -> 29 mm, shown 3x like the heap texture
const LUMP := 0.15             # m of height noise on the starting heap
const CELL := 0.125            # m per height field cell
const GRID := 160              # cells per side -> 20 m
const MAX_STEP := SLOPE * CELL # steepest allowed height difference between neighbour cells
const RELAX_PASSES := 3        # slide passes per physics frame while something is unsettled
const MIN_SLIDE := 1e-4        # m, smaller moves count as settled
const SLIDE_STEP := MAX_STEP + MIN_SLIDE  # height difference that slides
const DIG_RADIUS := 2          # cells
const SURFACE_GRAB := 0.1      # m around a heap take point to pick the mesh bullet from
const COLLISION_INTERVAL := 0.25
const SURFACE_LIFT := 0.014    # m, centre above the surface: resting on it (radius 0.0149)
const TOE := 0.06              # m, how thick the heap's thinning foot is (softplus width)
const CHUNKS := 4              # surface bullet chunks per side, for culling
const SPILL_FILE := "res://data/spill.bin"  # settled by tools/bake_spill.gd
const HEAP_FILE := "res://data/heap.bin"    # starting heights, already at rest
const BULLET_RADIUS := 0.0149  # m, collision capsule at the shown 3x size
const BULLET_LENGTH := 0.0875
const BULLET_MASS := 0.012     # kg
const BULLET_LAYER := 1 << 2   # physics layer 3: loose bullets; the player's body ignores it
const WAKE_RADIUS := 0.3       # m around a walker's feet where resting spill turns into bodies
const WAKE_SPEED := 0.5        # m/s, slower walkers don't kick anything
const MAX_AWAKE := 64
const TILE := 8 # cells per activity tile side; far-apart digs stay separate tiles
const TILES := GRID / TILE
const REDRAW_STEP := 0.001    # m a cell drifts before the mesh bullets on it are moved

@export var bullet_scene: PackedScene = preload("res://assets/bullet/bullet_9mm.glb")
@export var cone_material: ShaderMaterial
## The bullet model's base colour is saturated gold; these pull heap texture and mesh bullets
## toward pale brass, the same way for both.
@export var saturation := 0.75
@export var brightness := 1.1
@export var tint := Color(1.0, 0.9, 0.78)
## Real meshes on the surface; the heap shader fakes the rest.
@export var surface_bullets := 15000
## Bullets spilled on the floor around the rim, thinning out with distance.
@export var spill_bullets := 8000
@export var spill_reach := 0.9  # m past where the foot runs out

var _h := PackedFloat32Array()   # height per cell, row j = +z, column i = +x
var _img: Image
var _tex: ImageTexture
var _tex_prev: ImageTexture  # heights a tick earlier; the shader blends toward _tex
var _prev_stale := false     # _tex_prev still differs from _tex
var _shape := HeightMapShape3D.new()
var _scaled := PackedFloat32Array()  # _h / CELL for the collision shape, kept current per changed cell
var _active: Array[Rect2i] = []  # per tile: cells that may still slide; all empty when the heap is at rest
var _dirty: Array[Rect2i] = []   # per tile: cells changed since the last visual update
var _redraw: Array[Rect2i] = []  # per tile: cells whose mesh bullets need to move
var _drawn_h := PackedFloat32Array()  # height per cell when bullets around it were last moved
var _any_active := false
var _any_dirty := false
var _shape_dirty := false
var _shape_timer := 0.0
var _digs := []                  # [cell: Vector2i, height-metres still to remove]
var _dig_w := PackedFloat64Array()  # Gaussian weight per cell of a dig, row by row
var _surface: Array[MultiMeshInstance3D] = []
var _surface_base: Array[PackedFloat32Array] = []
var _cell_bullets := {}          # cell index -> PackedInt32Array of chunk << 16 | instance
var _cell_first := PackedInt32Array()  # cell index -> first slot below; slots are in cell order
var _slot_code := PackedInt32Array()   # per surface bullet: its code as in _cell_bullets
var _slot_k := PackedInt32Array()      # cell whose corner the bullet's height interpolates from
var _slot_f := PackedVector2Array()    # bilinear weights toward +x and +z
var _slot_xform: Array[Transform3D] = []  # as placed
var _spill: MultiMeshInstance3D
var _spill_pos := PackedVector3Array()
var _spill_xform: Array[Transform3D] = []
var _spill_rid: Array[RID] = []  # resting spill: bare static bodies, no nodes, so 8000 cost ~nothing
var _spill_index := {}           # RID -> index into the spill arrays
var _spill_id := PackedInt32Array()  # loose bullet id per spill index
var _id_index := {}              # loose bullet id -> index into the spill arrays
var _surface_removed := {}       # surface bullet codes that were picked up
var _query_sphere := SphereShape3D.new()
var _awake: Array[RigidBody3D] = []
var _capsule := CapsuleShape3D.new()
var _bullet_mesh: Mesh
var _bullet_mat: Material
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 3
	_noise.frequency = 0.45
	_noise.fractal_octaves = 4
	_active.resize(TILES * TILES)
	_dirty.resize(TILES * TILES)
	_redraw.resize(TILES * TILES)
	for dj in range(-DIG_RADIUS, DIG_RADIUS + 1):
		for di in range(-DIG_RADIUS, DIG_RADIUS + 1):
			_dig_w.append(exp(-(di * di + dj * dj) * 0.5))
	if not _load_heights():
		_build_heights((GameState.PILE_START - spill_bullets) * BULLET_VOLUME)
		settle_all()

	_img = Image.create_from_data(GRID, GRID, false, Image.FORMAT_RF, _h.to_byte_array())
	_tex = ImageTexture.create_from_image(_img)
	_tex_prev = ImageTexture.create_from_image(_img)
	cone_material.set_shader_parameter("height_field", _tex)
	cone_material.set_shader_parameter("height_prev", _tex_prev)
	cone_material.set_shader_parameter("grid", GRID)
	cone_material.set_shader_parameter("cell_size", CELL)
	cone_material.set_shader_parameter("tint", tint)
	cone_material.set_shader_parameter("albedo_tex", _graded(cone_material.get_shader_parameter("albedo_tex")))
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (GRID - 1) * CELL  # vertices sit on cell centres
	plane.subdivide_width = GRID - 2
	plane.subdivide_depth = GRID - 2
	plane.material = cone_material
	var heap := MeshInstance3D.new()
	heap.mesh = plane
	heap.custom_aabb = AABB(Vector3(-GRID * CELL * 0.5, -0.1, -GRID * CELL * 0.5), Vector3(GRID * CELL, 8.0, GRID * CELL))
	add_child(heap)

	_shape.map_width = GRID
	_shape.map_depth = GRID
	var col := CollisionShape3D.new()
	col.shape = _shape
	col.scale = Vector3.ONE * CELL  # samples are 1 unit apart; heights are divided by CELL
	add_child(col)
	_drawn_h = _h.duplicate()
	_scaled = _h.duplicate()
	for k in _scaled.size():
		_scaled[k] /= CELL
	_update_shape()

	_build_bullets()
	GameState.bullets_taken.connect(_on_bullets_taken)
	GameState.bullets_thrown.connect(_on_bullets_thrown)
	GameState.loose_taken.connect(_on_loose_taken)
	GameState.pile_changed.connect(func(count: int) -> void: visible = count > 0)
	visible = GameState.pile > 0


## Lumpy cone with a rounded top, scaled so its volume is exactly `volume`.
func _build_heights(volume: float) -> void:
	var r0 := pow(volume * 3.0 / (PI * SLOPE), 1.0 / 3.0)  # V = π·r²·h / 3, h = r·SLOPE
	var top := 0.15  # radius fraction that is rounded off
	_h.resize(GRID * GRID)
	var sum := 0.0
	for j in GRID:
		for i in GRID:
			var p := _cell_pos(Vector2i(i, j))
			var f := Vector2(p.x, p.z).length() / r0
			# Parabola below `top`, matching the cone's height and slope where they meet.
			var y := r0 * SLOPE * (1.0 - top * 0.5 - f * f / (2.0 * top) if f < top else 1.0 - f)
			y += _noise.get_noise_2d(p.x, p.z) * LUMP * minf(f * 4.0, 1.0)
			# Softplus instead of a hard cut at the floor: the slope eases into a thin foot.
			if y < TOE * 20.0:  # above that softplus is just y
				y = TOE * log(1.0 + exp(maxf(y / TOE, -30.0)))
			_h[j * GRID + i] = y if y > 0.002 else 0.0
			sum += _h[j * GRID + i]
	var k := volume / (sum * CELL * CELL)
	for c in _h.size():
		_h[c] *= k


func _load_heights() -> bool:
	var f := FileAccess.open(HEAP_FILE, FileAccess.READ)
	if f == null:
		return false
	_h = f.get_buffer(f.get_length()).to_float32_array()
	return _h.size() == GRID * GRID


## Slides the whole heap until no slope is steeper than the angle of repose. Slow (seconds),
## so tools/bake_spill.gd runs it once and saves the result to HEAP_FILE; without it, the
## first take would set off an avalanche over the whole heap.
func settle_all() -> void:
	_mark(_active, Rect2i(0, 0, GRID, GRID))
	_any_active = true
	for pass_i in 2000:
		_relax()
		if not _any_active:
			break
	_dirty.fill(Rect2i())
	_any_dirty = false


func _build_bullets() -> void:
	var glb := bullet_scene.instantiate()
	var mesh_inst := glb.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh: Mesh = mesh_inst.mesh
	var mat: BaseMaterial3D = mesh_inst.get_active_material(0).duplicate()
	mat.albedo_color = tint
	mat.albedo_texture = _graded(mat.albedo_texture)
	glb.free()
	_bullet_mesh = mesh
	_bullet_mat = mat
	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	# Surface bullets: lying along the slope, randomly turned, chunked by area.
	# Plain Arrays while filling: packed arrays inside an Array are copied on access.
	var buffers: Array[Array] = []
	for i in CHUNKS * CHUNKS:
		buffers.append([])
	var placed := 0
	var segments := {}  # cell index -> Array of [a, b] capsule axis ends, to keep bullets apart
	var half := BULLET_LENGTH * 0.5 - BULLET_RADIUS
	for attempt in surface_bullets * 4:
		if placed == surface_bullets:
			break
		var cell := Vector2i(rng.randi_range(1, GRID - 2), rng.randi_range(1, GRID - 2))
		if _h[cell.y * GRID + cell.x] < 0.05:
			continue
		var n := _cell_normal(cell)
		var around := n.cross(Vector3.FORWARD if absf(n.z) < 0.9 else Vector3.RIGHT).normalized()
		var x := around.rotated(n, rng.randf() * TAU)
		var b := Basis(x, n, x.cross(n)).scaled(Vector3.ONE * BULLET_SCALE)
		var o := _cell_pos(cell) + Vector3(rng.randf_range(-0.5, 0.5) * CELL, 0.0, rng.randf_range(-0.5, 0.5) * CELL)
		o.y = _height_smooth(o) + SURFACE_LIFT
		if _overlaps(segments, cell, o - x * half, o + x * half):
			continue
		var seg_key := cell.y * GRID + cell.x
		var segs: Array = segments.get(seg_key, [])
		segs.append([o - x * half, o + x * half])
		segments[seg_key] = segs
		var chunk := (cell.y * CHUNKS / GRID) * CHUNKS + cell.x * CHUNKS / GRID
		var idx := buffers[chunk].size() / 12
		buffers[chunk].append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z])
		var key := cell.y * GRID + cell.x
		var list: PackedInt32Array = _cell_bullets.get(key, PackedInt32Array())
		list.append(chunk << 16 | idx)
		_cell_bullets[key] = list
		placed += 1
	for arr in buffers:
		var buf := PackedFloat32Array(arr)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = buf.size() / 12
		mm.buffer = buf
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # tiny; SSAO covers it
		add_child(node)
		_surface.append(node)
		_surface_base.append(buf)
	# Flat copy of _cell_bullets for the per-frame update: bullets in cell order, cell -> first slot.
	_cell_first.resize(GRID * GRID + 1)
	for key in GRID * GRID:
		_cell_first[key] = _slot_code.size()
		for code in _cell_bullets.get(key, PackedInt32Array()):
			var b := _surface_base[code >> 16]
			var k: int = (code & 0xFFFF) * 12
			var u: float = b[k + 3] / CELL + (GRID - 1) * 0.5
			var v: float = b[k + 11] / CELL + (GRID - 1) * 0.5
			var ci := clampi(floori(u), 0, GRID - 2)
			var cj := clampi(floori(v), 0, GRID - 2)
			_slot_code.append(code)
			_slot_k.append(cj * GRID + ci)
			_slot_f.append(Vector2(clampf(u - ci, 0.0, 1.0), clampf(v - cj, 0.0, 1.0)))
			_slot_xform.append(Transform3D(Vector3(b[k], b[k + 4], b[k + 8]), Vector3(b[k + 1], b[k + 5], b[k + 9]),
					Vector3(b[k + 2], b[k + 6], b[k + 10]), Vector3(b[k + 3], b[k + 7], b[k + 11])))
	_cell_first[GRID * GRID] = _slot_code.size()

	_spill_xform = _load_spill()
	if _spill_xform.is_empty():
		_spill_xform = scatter_spill(rng)
	_capsule.radius = BULLET_RADIUS
	_capsule.height = BULLET_LENGTH
	for t in _spill_xform:
		var rid := _make_static(t)
		var i := _spill_pos.size()
		_spill_index[rid] = i
		_id_index[i] = i  # baked spill ids are their file order
		_spill_id.append(i)
		_spill_pos.append(t.origin)
		_spill_rid.append(rid)
	var spill_mm := MultiMesh.new()
	spill_mm.transform_format = MultiMesh.TRANSFORM_3D
	spill_mm.mesh = mesh
	spill_mm.instance_count = _spill_xform.size()
	for i in _spill_xform.size():
		spill_mm.set_instance_transform(i, _spill_xform[i])
	_spill = MultiMeshInstance3D.new()
	_spill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # thousands of 1600-tri bullets per cascade
	_spill.multimesh = spill_mm
	_spill.material_override = mat
	add_child(_spill)


## Unsettled spill: where a bucket would pour it, dense at the foot and thinning out.
## tools/bake_spill.gd drops these as rigid bodies and saves where they come to rest.
func scatter_spill(rng: RandomNumberGenerator) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i in spill_bullets:
		var theta := rng.randf() * TAU
		var dir := Vector3(cos(theta), 0.0, sin(theta))
		var rim := 0.0
		while _height_at(dir * rim) > TOE:  # where the foot starts thinning out
			rim += CELL
		var d := spill_reach * pow(rng.randf(), 2.5)  # poured off a bucket: dense at the foot, thinning out
		var b := (Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf() * TAU)).scaled(Vector3.ONE * BULLET_SCALE)
		var p := dir * (rim + d)
		p.y = _height_at(p) + BULLET_SCALE * 0.5  # model is ~1 unit thick; rests on the foot
		out.append(Transform3D(b, p))
	return out


func _load_spill() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var f := FileAccess.open(SPILL_FILE, FileAccess.READ)
	if f == null:
		return out
	var buf := f.get_buffer(f.get_length()).to_float32_array()
	for k in range(0, buf.size(), 12):
		out.append(Transform3D(Vector3(buf[k], buf[k + 1], buf[k + 2]), Vector3(buf[k + 3], buf[k + 4], buf[k + 5]),
				Vector3(buf[k + 6], buf[k + 7], buf[k + 8]), Vector3(buf[k + 9], buf[k + 10], buf[k + 11])))
	return out


## A loose cartridge as a rigid body: capsule hitbox along the model's long (x) axis, drawn
## with `mesh` when given. `t` is a visual transform (basis scaled by BULLET_SCALE); the body
## itself is unscaled.
static func make_body(t: Transform3D, mesh: Mesh = null, mat: Material = null) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = BULLET_MASS
	body.continuous_cd = true
	body.angular_damp = 4.0  # a real cartridge's taper and rim stop it rolling; a capsule would roll on
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.6
	body.physics_material_override.bounce = 0.1
	var shape := CapsuleShape3D.new()
	shape.radius = BULLET_RADIUS
	shape.height = BULLET_LENGTH
	var col := CollisionShape3D.new()
	col.shape = shape
	col.rotation.z = PI * 0.5  # capsule is along y, the bullet along x
	body.add_child(col)
	if mesh:
		var look := MeshInstance3D.new()
		look.mesh = mesh
		look.material_override = mat
		look.scale = Vector3.ONE * BULLET_SCALE
		body.add_child(look)
	body.transform = Transform3D(t.basis.orthonormalized(), t.origin)
	return body


## True if a capsule along a..b would touch one already placed in this or a neighbouring cell.
func _overlaps(segments: Dictionary, cell: Vector2i, a: Vector3, b: Vector3) -> bool:
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for seg in segments.get((cell.y + dj) * GRID + cell.x + di, []):
				var pts := Geometry3D.get_closest_points_between_segments(a, b, seg[0], seg[1])
				if pts[0].distance_to(pts[1]) < BULLET_RADIUS * 2.0:
					return true
	return false


## True if a ray hit on `collider` / `rid` is part of this heap: the heap itself or a loose bullet.
func is_grabbable(collider: Object, rid: RID) -> bool:
	return collider == self or _spill_index.has(rid) or (collider is RigidBody3D and _awake.has(collider))


## Loose bullets (resting or moving) whose hitbox is within `radius` of world point `at`.
func _loose_near(at: Vector3, radius: float, max_results := 32) -> Array[Dictionary]:
	_query_sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _query_sphere
	q.transform = Transform3D(Basis(), at)
	q.collision_mask = BULLET_LAYER
	return get_world_3d().direct_space_state.intersect_shape(q, max_results)


## Id of the loose bullet a ray hit (resting or moving), or -1 if it hit something else.
func loose_id(collider: Object, rid: RID) -> int:
	if _spill_index.has(rid):
		return _spill_id[_spill_index[rid]]
	if collider is RigidBody3D and _awake.has(collider):
		return collider.get_meta("id")
	return -1


func _on_loose_taken(id: int) -> void:
	if _id_index.has(id):
		_remove_spill(_id_index[id])
		return
	for body in _awake:
		if body.get_meta("id") == id:
			_awake.erase(body)
			body.queue_free()
			return


## Hides the mesh bullet nearest to a heap take, so the bullet looked at is the one that goes.
func _take_surface_near(local: Vector3) -> void:
	var cell := _cell_of(local)
	var best := -1
	var best_d := SURFACE_GRAB
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for code in _cell_bullets.get((cell.y + dj) * GRID + cell.x + di, PackedInt32Array()):
				if _surface_removed.has(code):
					continue
				var b := _surface_base[code >> 16]
				var k: int = (code & 0xFFFF) * 12
				var pos := Vector3(b[k + 3], 0.0, b[k + 11])
				pos.y = _height_smooth(pos) + SURFACE_LIFT
				if pos.distance_to(local) < best_d:
					best_d = pos.distance_to(local)
					best = code
	if best >= 0:
		_surface_removed[best] = true
		_surface[best >> 16].multimesh.set_instance_transform(best & 0xFFFF, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


## A resting spilled bullet as a bare static body, so moving bullets land on it.
func _make_static(t: Transform3D) -> RID:
	var rid := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(rid, _capsule.get_rid(), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO))
	PhysicsServer3D.body_set_collision_layer(rid, BULLET_LAYER)
	PhysicsServer3D.body_set_collision_mask(rid, 0)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform * Transform3D(t.basis.orthonormalized(), t.origin))
	PhysicsServer3D.body_set_space(rid, get_world_3d().space)
	return rid


## Swap-remove so the drawn instances stay packed at the front.
func _remove_spill(i: int) -> void:
	var last := _spill_pos.size() - 1
	_spill_index.erase(_spill_rid[i])
	_id_index.erase(_spill_id[i])
	PhysicsServer3D.free_rid(_spill_rid[i])
	if i < last:
		_spill_index[_spill_rid[last]] = i
		_id_index[_spill_id[last]] = i
		_spill_id[i] = _spill_id[last]
	_spill_id.resize(last)
	_spill_pos[i] = _spill_pos[last]
	_spill_xform[i] = _spill_xform[last]
	_spill_rid[i] = _spill_rid[last]
	_spill_pos.resize(last)
	_spill_xform.resize(last)
	_spill_rid.resize(last)
	if i < last:
		_spill.multimesh.set_instance_transform(i, _spill_xform[i])
	_spill.multimesh.visible_instance_count = last


# ponytail: thrown bullets that land on the heap stay where they land, even if it's dug out under them.
func _add_spill(t: Transform3D, id: int) -> void:
	var rid := _make_static(t)
	_spill_index[rid] = _spill_pos.size()
	_id_index[id] = _spill_pos.size()
	_spill_id.append(id)
	_spill_rid.append(rid)
	_spill_pos.append(t.origin)
	_spill_xform.append(t)
	var mm := _spill.multimesh
	if _spill_pos.size() > mm.instance_count:  # thrown bullets can grow the spill
		mm.instance_count = _spill_pos.size() + 1024  # resizing clears the instances
		for i in _spill_pos.size() - 1:
			mm.set_instance_transform(i, _spill_xform[i])
	_spill.multimesh.set_instance_transform(_spill_pos.size() - 1, t)
	_spill.multimesh.visible_instance_count = _spill_pos.size()


## Walkers kick resting spill near their feet into real bodies; bodies that come to rest
## turn back into static spill. Only these few dozen bullets are ever simulated.
# Co-op: kicks are local visuals, so spill can drift apart a little between peers.
func _update_awake() -> void:
	for walker in get_tree().get_nodes_in_group("walker"):
		var v: Vector3 = walker.velocity * Vector3(1, 0, 1)
		if v.length() < WAKE_SPEED or _awake.size() >= MAX_AWAKE:
			continue
		for hit in _loose_near(walker.global_position, WAKE_RADIUS, MAX_AWAKE - _awake.size()):
			var i: int = _spill_index.get(hit.rid, -1)
			if i < 0:
				continue  # already moving
			var t := global_transform * _spill_xform[i]
			var id := _spill_id[i]
			_remove_spill(i)
			_spawn_loose(id, t, v * randf_range(0.4, 0.9) + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.6), randf_range(-0.3, 0.3)))
	for i in range(_awake.size() - 1, -1, -1):
		var body := _awake[i]
		# Velocity is still zero on the frame the kick is queued, so give each body a few frames.
		var age: int = Engine.get_physics_frames() - body.get_meta("woke")
		var resting := body.sleeping or (body.linear_velocity.length() < 0.02 and body.angular_velocity.length() < 0.2)
		if (age > 15 and resting) or age > 600:  # 10 s cap for ones that keep jittering
			var t := global_transform.affine_inverse() * body.global_transform
			_add_spill(Transform3D(t.basis.orthonormalized().scaled(Vector3.ONE * BULLET_SCALE), t.origin), body.get_meta("id"))
			body.queue_free()
			_awake.remove_at(i)


## Throws `count` bullets from `from` along `dir` with some spread; they settle into spill.
func _on_bullets_thrown(from: Vector3, dir: Vector3, count: int, first_id: int) -> void:
	for n in count:
		var b := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)).scaled(Vector3.ONE * BULLET_SCALE)
		var spread := Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)) * 1.2
		_spawn_loose(first_id + n, Transform3D(b, from + spread * 0.05), dir * randf_range(3.0, 6.0) + spread)


## Loose bullet `id` as a body at global transform `t` with `velocity`; joins _awake until it rests.
func _spawn_loose(id: int, t: Transform3D, velocity: Vector3) -> void:
	var body := make_body(t, _bullet_mesh, _bullet_mat)
	body.collision_layer = BULLET_LAYER
	body.collision_mask = 1 | BULLET_LAYER
	body.top_level = true  # t is global
	add_child(body)
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	body.set_meta("woke", Engine.get_physics_frames())
	body.set_meta("id", id)
	_awake.append(body)


func _exit_tree() -> void:
	for rid in _spill_rid:
		PhysicsServer3D.free_rid(rid)


## Bullets out of the heap at `at`, starting with the mesh bullet nearest to it.
func _on_bullets_taken(at: Vector3, count: int) -> void:
	var local := to_local(at)
	for n in mini(count, 8):
		_take_surface_near(local)
	_digs.append([_cell_of(local), count * BULLET_VOLUME / (CELL * CELL)])


func _physics_process(delta: float) -> void:
	_update_awake()
	for dig in _digs:
		dig[1] = _dig(dig[0], dig[1])
	# Leftover keeps digging at the same spot as the sides slide in; dropped once nothing can.
	_digs = _digs.filter(func(d: Array) -> bool: return d[1] > 1e-9 and (_any_active or _material_near(d[0])))

	for pass_i in RELAX_PASSES:
		if not _any_active:
			break
		_relax()

	if _any_dirty:
		_tex_prev.update(_img)  # _img still holds last tick's heights
		_img.set_data(GRID, GRID, false, Image.FORMAT_RF, _h.to_byte_array())
		_tex.update(_img)
		_prev_stale = true
		for area in _dirty:
			if area.has_area():
				_update_cells(area)
		_dirty.fill(Rect2i())
		_any_dirty = false
		for area in _redraw:
			if area.has_area():
				_update_surface_bullets(area)
		_redraw.fill(Rect2i())
		_shape_dirty = true
	elif _prev_stale:  # came to rest: stop blending from the older heights
		_tex_prev.update(_img)
		_prev_stale = false
	_shape_timer -= delta
	if _shape_dirty and _shape_timer <= 0.0:
		_update_shape()


func _process(_delta: float) -> void:
	cone_material.set_shader_parameter("blend", Engine.get_physics_interpolation_fraction())


## Removes up to `amount` height-metres around `cell`, Gaussian-weighted; returns the rest.
func _dig(cell: Vector2i, amount: float) -> float:
	var total := 0.0
	var n := 0
	for y in range(cell.y - DIG_RADIUS, cell.y + DIG_RADIUS + 1):
		for x in range(cell.x - DIG_RADIUS, cell.x + DIG_RADIUS + 1):
			if x >= 0 and y >= 0 and x < GRID and y < GRID:
				total += _dig_w[n] * signf(_h[y * GRID + x])
			n += 1
	if total <= 0.0:
		return amount
	var left := amount
	n = 0
	for y in range(cell.y - DIG_RADIUS, cell.y + DIG_RADIUS + 1):
		for x in range(cell.x - DIG_RADIUS, cell.x + DIG_RADIUS + 1):
			if x >= 0 and y >= 0 and x < GRID and y < GRID:
				var k := y * GRID + x
				var take := minf(_h[k], amount * _dig_w[n] / total)
				_h[k] -= take
				left -= take
			n += 1
	var area := Rect2i(cell - Vector2i.ONE * (DIG_RADIUS + 1), Vector2i.ONE * (DIG_RADIUS * 2 + 3))
	_mark(_active, area)
	_mark(_dirty, area)
	_any_active = true
	_any_dirty = true
	return maxf(left, 0.0)


func _material_near(cell: Vector2i) -> bool:
	for y in range(maxi(cell.y - DIG_RADIUS, 0), mini(cell.y + DIG_RADIUS + 1, GRID)):
		for x in range(maxi(cell.x - DIG_RADIUS, 0), mini(cell.x + DIG_RADIUS + 1, GRID)):
			if _h[y * GRID + x] > 0.0:
				return true
	return false


## One sand-pile pass over the active tiles: any neighbour pair steeper than the angle of
## repose sheds half the excess downhill. What moved is marked dirty and, grown a cell up and
## left so slides cross tile edges, becomes the next pass's active area.
# Rows run top to bottom across a whole tile row, so one dig visits cells in the same order
# as a single rectangle would.
# ponytail: GDScript loop, cost scales with active tiles; compute shader if the whole heap
# avalanches at once.
func _relax() -> void:
	var cur := _active.duplicate()
	_active.fill(Rect2i())
	_any_active = false
	var lo_x := PackedInt32Array()
	lo_x.resize(TILES * TILES)
	lo_x.fill(GRID)
	var lo_y := lo_x.duplicate()
	var hi_x := PackedInt32Array()
	hi_x.resize(TILES * TILES)
	hi_x.fill(-1)
	var hi_y := hi_x.duplicate()
	var h := _h
	_h = PackedFloat32Array()  # h is then the only reference: writes don't copy the array
	for tj in TILES:
		var row: Array[int] = []
		var y0 := GRID
		var y1 := 0
		for t in range(tj * TILES, tj * TILES + TILES):
			var r: Rect2i = cur[t]
			if r.has_area():
				row.append(t)
				y0 = mini(y0, r.position.y)
				y1 = maxi(y1, r.end.y)
		# The last row and column are skipped: they have no neighbour on one side, and the heap's
		# foot ends metres before the grid does.
		for j in range(y0, mini(y1, GRID - 1)):
			for t in row:
				var r: Rect2i = cur[t]
				if j < r.position.y or j >= r.end.y:
					continue
				var first := -1  # columns of this row segment that moved
				var last := -1
				for i in range(r.position.x, mini(r.end.x, GRID - 1)):
					var k := j * GRID + i
					var hk := h[k]
					var d := hk - h[k + 1]  # right neighbour
					if absf(d) > SLIDE_STEP:
						var m := (absf(d) - MAX_STEP) * 0.5 * signf(d)
						hk -= m
						h[k] = hk
						h[k + 1] += m
						last = i
						if first < 0:
							first = i
					d = hk - h[k + GRID]  # neighbour below
					if absf(d) > SLIDE_STEP:
						var m := (absf(d) - MAX_STEP) * 0.5 * signf(d)
						h[k] = hk - m
						h[k + GRID] += m
						last = i
						if first < 0:
							first = i
				if last >= 0:  # counted as reaching one cell right and down either way
					lo_x[t] = mini(lo_x[t], first)
					lo_y[t] = mini(lo_y[t], j)
					hi_x[t] = maxi(hi_x[t], last + 1)
					hi_y[t] = maxi(hi_y[t], j + 1)
	_h = h
	for t in TILES * TILES:
		if hi_x[t] < 0:
			continue
		var moved := Rect2i(lo_x[t], lo_y[t], hi_x[t] - lo_x[t] + 1, hi_y[t] - lo_y[t] + 1)
		_mark(_active, moved.grow_individual(1, 1, 0, 0))  # a pair is checked from its left / upper cell
		_mark(_dirty, moved)
		_any_active = true
		_any_dirty = true


## Adds `area` to the per-tile rectangles in `tiles`, split along tile edges.
func _mark(tiles: Array[Rect2i], area: Rect2i) -> void:
	area = area.intersection(Rect2i(0, 0, GRID, GRID))
	if not area.has_area():
		return
	for tj in range(area.position.y / TILE, (area.end.y - 1) / TILE + 1):
		for ti in range(area.position.x / TILE, (area.end.x - 1) / TILE + 1):
			var part := area.intersection(Rect2i(ti * TILE, tj * TILE, TILE, TILE))
			var t := tj * TILES + ti
			tiles[t] = part if not tiles[t].has_area() else tiles[t].merge(part)


## Copies changed cells into the collision heights, and queues the mesh bullets around cells
## that drifted a visible amount since they were last drawn. Most slides move a cell by
## fractions of a millimetre; redrawing bullets for those cost more than the slides did.
func _update_cells(area: Rect2i) -> void:
	for j in range(area.position.y, area.end.y):
		for i in range(area.position.x, area.end.x):
			var key := j * GRID + i
			var h := _h[key]
			_scaled[key] = h / CELL
			if absf(h - _drawn_h[key]) >= REDRAW_STEP:
				_drawn_h[key] = h
				_mark(_redraw, Rect2i(i - 1, j - 1, 3, 3))  # bullets interpolate the cells around them


## Keeps mesh bullets resting on the cells in `area`; hides them where the heap is gone.
func _update_surface_bullets(area: Rect2i) -> void:
	var h := _h
	for j in range(area.position.y, area.end.y):
		for i in range(area.position.x, area.end.x):
			var key := j * GRID + i
			for s in range(_cell_first[key], _cell_first[key + 1]):
				var code := _slot_code[s]
				if _surface_removed.has(code):
					continue
				var k := _slot_k[s]  # _height_smooth with the corner and weights worked out once
				var f := _slot_f[s]
				var y := lerpf(lerpf(h[k], h[k + 1], f.x), lerpf(h[k + GRID], h[k + GRID + 1], f.x), f.y)
				var t := _slot_xform[s]
				t.origin.y = y + SURFACE_LIFT
				if y < 0.02:
					t.basis = Basis.from_scale(Vector3.ZERO)
				_surface[code >> 16].multimesh.set_instance_transform(code & 0xFFFF, t)


func _update_shape() -> void:
	_shape.map_data = _scaled
	_shape_dirty = false
	_shape_timer = COLLISION_INTERVAL


func _cell_of(local: Vector3) -> Vector2i:
	return Vector2i(floori(local.x / CELL + GRID * 0.5), floori(local.z / CELL + GRID * 0.5))


func _cell_pos(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (GRID - 1) * 0.5) * CELL, 0.0, (cell.y - (GRID - 1) * 0.5) * CELL)


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID and c.y < GRID


## World height of the heap's surface above `world` (the floor where there is no heap); for
## things buried in it, like the crate keys.
func surface_y(world: Vector3) -> float:
	return global_position.y + _height_smooth(to_local(world))


func _height_at(local: Vector3) -> float:
	var c := _cell_of(local)
	return _h[c.y * GRID + c.x] if _in_grid(c) else 0.0


## Height between cell centres, interpolated like the drawn surface (bilinear).
func _height_smooth(local: Vector3) -> float:
	var u := local.x / CELL + (GRID - 1) * 0.5
	var v := local.z / CELL + (GRID - 1) * 0.5
	var i := clampi(floori(u), 0, GRID - 2)
	var j := clampi(floori(v), 0, GRID - 2)
	var fx := clampf(u - i, 0.0, 1.0)
	var fz := clampf(v - j, 0.0, 1.0)
	var k := j * GRID + i
	return lerpf(lerpf(_h[k], _h[k + 1], fx), lerpf(_h[k + GRID], _h[k + GRID + 1], fx), fz)


func _cell_normal(c: Vector2i) -> Vector3:
	var k := c.y * GRID + c.x
	return Vector3(_h[k - 1] - _h[k + 1], 2.0 * CELL, _h[k - GRID] - _h[k + GRID]).normalized()


func _graded(tex: Texture2D) -> ImageTexture:
	var img := tex.get_image()
	img.decompress()
	img.clear_mipmaps()
	img.adjust_bcs(brightness, 1.0, saturation)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
