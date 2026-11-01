class_name Pile
extends StaticBody3D
## The scrap heap that fills the west of the hall up to the roof: a height field the count is
## carved out of (GameState.pile, 100M pieces; one piece is UNIT of the starting volume).
## Scrap locks together: slopes up to LOCK_SLOPE stand, and every take that undercuts such a slope
## lets what is above it settle down into the gap. Takes from the same steep spot build up strain;
## past a threshold the host lets that part of the face give way (GameState scrap_collapse): it
## slumps to REPOSE_SLOPE, the top comes down with it, and real pieces tumble off the face and
## shove whoever stands below. A height field can't hang: nothing ever floats over a hole.
## Pieces on the surface are drawn from the prepared scrap (assets/props/hurda/hurda.json), one
## MultiMesh per part; loose pieces on the floor are numbered and picked up one by one.
## Co-op: only GameState events cross the network (bullets_taken for the heap, loose_taken by id,
## scrap_collapse with the host's seed); every peer digs, slides and slumps locally, the same way.
# Every peer runs the same digs through the same slide passes, so heights match bit for bit
# (tools/net_check.gd compares them): the heap keeps a step count, the host stamps its events
# with it and sends it on (heap_clock), and a client's heap applies each event at that step and
# never runs past the host's. Tumbling pieces are local visuals.

const CELL := 0.25            # m per height field cell
const GRID_X := 128           # cells along x -> 32 m, the west wall to past the foot
const GRID_Z := 224           # cells along z -> 56 m, wall to wall
const LOCK_SLOPE := 1.8       # tan(61°): scrap hooked into scrap stands this steep
const REPOSE_SLOPE := 0.75    # tan(37°): a face that gave way slumps to this
const LOCK_STEP := LOCK_SLOPE * CELL
const REPOSE_STEP := REPOSE_SLOPE * CELL
const MIN_SLIDE := 1e-4       # m, smaller moves count as settled
const RELAX_PASSES := 3       # slide passes per physics frame while something is unsettled
const SLUMP_PASSES := 6       # while a face is coming down: it falls faster than it settles
const DIG_RADIUS := 2         # cells
const TILE := 8               # cells per activity tile side
const TILES_X := GRID_X / TILE
const TILES_Z := GRID_Z / TILE
const COLLISION_INTERVAL := 0.25
const SLUMP_COLLISION_INTERVAL := 0.1  # s, while a face comes down: it carries walkers
const SLUMP_REDRAW_EVERY := 3  # physics frames between moving the pieces on a slumping face
## The collision is cut into square height maps CHUNK cells a side (sharing their edge row), so a
## slide rebuilds only the ones it touched: one shape over the whole heap took 160 ms to rebuild.
const CHUNK := 32
const CHUNKS_X := (GRID_X - 2) / CHUNK + 1
const CHUNKS_Z := (GRID_Z - 2) / CHUNK + 1
const REDRAW_STEP := 0.002    # m a cell drifts before the pieces on it are moved
const GRAB_DEPTH := 0.05      # m of heap under the crosshair before E grabs from it
const SURFACE_GRAB := 0.35    # m around a heap take to pick the drawn piece from
## The pieces: the prepared scrap (id, glb, tur, kutle_kg, boyut_m...; each glb a mesh with its
## base at y = 0 and one convex collision).
const PARTS_FILE := "res://assets/props/hurda/hurda.json"
## How often each kind of piece turns up in the heap, by hurda.json "tur" (times the root of how
## many pieces the kind has): small metal most, crates few. Guns (tur "silah") stay out: they would read as weapons to pick up.
const KIND_WEIGHT := {"disli": 1.0, "yay": 1.0, "civata": 1.0, "zincir": 0.8, "boru": 0.8, "sac": 0.7,
	"alet": 0.7, "konserve": 0.6, "motor": 0.4, "elektronik": 0.3, "kap": 0.25, "jant": 0.22, "sandik": 0.1}
## The roof (tools/build_arena.gd): a 6° pitch from 8.8 m at the eaves, and the glass lantern over
## the middle, 11.6 m to the top of its walls. The heap is packed up to just under them.
const EAVE := 8.8
const HALF_SPAN := 27.7
const PITCH := 0.1051         # tan(6°)
const LANTERN := Vector4(-15.0, -14.0, 15.0, 14.0)
const LANTERN_TOP := 11.3
const ROOF_GAP := 0.3         # m under the sheeting: purlins and trusses go into the heap
## Where the face starts on average, and how far it wanders along the hall.
const FOOT_X := -2.5
const FOOT_WANDER := 2.4
const LUMP := 0.7             # m of height noise
const SCRAP_LAYER := 1 << 2   # physics layer 3: loose pieces; the player's body ignores it
const BULLET_LAYER := SCRAP_LAYER  # the old name (player.gd's reach ray masks it)
const WAKE_RADIUS := 0.45     # m round a walker's feet where resting pieces turn into bodies
const WAKE_SPEED := 0.5       # m/s, slower walkers don't kick anything
const MAX_AWAKE := 48         # kicked loose pieces at once
const MAX_DEBRIS := 90        # pieces tumbling off a face, or lying where they stopped
const DEBRIS_LIFE := 40.0     # s a stopped piece lies before it sinks into the heap
const SHOVE_REACH := 0.7      # m from a walker's middle a moving piece shoves them
const SHOVE_SHARE := 0.8      # of the piece's speed
const POUR_SHOVE := 9.0       # m/s per m/s the surface under a walker rises
## Host: strain per tile from takes off a locked face; it gives way past a threshold rolled
## between these.
const STRAIN_MIN := 18.0
const STRAIN_MAX := 60.0
const STRAIN_SLOPE := 1.15    # takes count only where the slope is past REPOSE_STEP * this
const SLUMP_RADIUS := Vector2(1.8, 3.6)  # m, the host rolls a face's size between these

@export var heap_material: ShaderMaterial
## The face is covered in pieces (2026-11-01, the user: where the heap shows, scrap, no mesh, each
## piece its own): this many times over by their footprints, at most MAX_PER_CELL to a cell.
@export var cover := 1.3
const MAX_PER_CELL := 6
const SURFACE_MIN := 0.025   # m: only crumbs smaller than this stay off the face (the user: nuts and bolts too)
const LOW_TRIS := 150         # surface pieces are drawn from a lighter copy of their part
## Loose pieces on the floor round the foot, thinning out with distance.
@export var spill_pieces := 700
@export var spill_reach := 2.2  # m past the foot

var _h := PackedFloat32Array()   # height per cell, row j = +z, column i = +x
var _ceil := PackedFloat32Array()  # roof height per cell: the heap never reaches over it
var unit := 0.0                  # m³ of heap per piece in the count
var _img: Image
var _tex: ImageTexture
var _tex_prev: ImageTexture
var _prev_stale := false
var _shapes: Array[HeightMapShape3D] = []  # per collision chunk
var _chunk_dirty := PackedByteArray()
var _active: Array[Rect2i] = []  # per tile: cells that may still slide
var _dirty: Array[Rect2i] = []   # per tile: cells changed since the last visual update
var _redraw: Array[Rect2i] = []  # per tile: cells whose pieces need to move
var _slump := PackedByteArray()  # per tile: 1 while a face there is giving way (REPOSE_STEP)
var _any_slump := false
var _drawn_h := PackedFloat32Array()
var _any_active := false
var _any_dirty := false
var _shape_dirty := false
var _shape_timer := 0.0
var _digs := []                  # [cell: Vector2i, height-metres still to remove]
var _dig_w := PackedFloat64Array()
var _noise := FastNoiseLite.new()
# Parts: one entry per piece in hurda.json that goes into the heap.
var _part_mesh: Array[Mesh] = []
var _part_size: Array[Vector3] = []
var _part_mid: Array[Vector3] = []  # the mesh's box centre: pieces are placed and collide by it
var _part_low: Array[Mesh] = []     # LOW_TRIS copy, for the thousands on the surface
var _part_foot := PackedFloat32Array()  # m², lying on its widest side
var _mark_mi := MeshInstance3D.new()  # the piece under a player's crosshair, outlined (highlight())
var _marked := -1
var _part_shape: Array[BoxShape3D] = []  # resting loose pieces: cheap boxes
var _part_hull: Array[Shape3D] = []     # moving ones: the glb's own convex hull, so wheels roll
var _part_hull_at: Array[Transform3D] = []  # the hull relative to the box centre
var _part_mass := PackedFloat32Array()
var _part_pick := PackedFloat32Array()  # running weight, for picking a part by a random number
var _face_pick := PackedFloat32Array()  # the same for the face, without the parts under SURFACE_MIN
# Surface pieces: a MultiMesh per part, slots in cell order.
var _surface: Array[MultiMeshInstance3D] = []
var _cell_first := PackedInt32Array()  # cell index -> first slot; slots are in cell order
var _slot_part := PackedInt32Array()
var _slot_index := PackedInt32Array()  # instance in its part's MultiMesh
var _slot_k := PackedInt32Array()      # cell whose corner the piece's height interpolates from
var _slot_f := PackedVector2Array()    # bilinear weights toward +x and +z
var _slot_xform: Array[Transform3D] = []  # as placed; origin.y is its lift over the surface
var _surface_removed := {}       # slot -> surface height there when it was picked off or fell
const RESURFACE := 0.06          # m the surface moves on from there before another piece shows in its slot
# Loose pieces: numbered, lying still as bare static bodies, one MultiMesh per part.
var _spill: Array[MultiMeshInstance3D] = []
var _part_slots: Array[Array] = []  # per part: loose id in each instance slot
var _id_index := {}              # loose id -> [part, slot, rid, transform]
var _spill_index := {}           # rid -> loose id
var _awake: Array[RigidBody3D] = []   # kicked loose pieces, meta "id", "part"
var _debris: Array[RigidBody3D] = []  # pieces off a slumping face, meta "since"
var _query_sphere := SphereShape3D.new()
var _strain := {}                # host: tile -> strain
var _limit := {}                 # host: tile -> the strain it gives way at
var step := 0                    # heap steps run (one per physics frame)
var _host_step := 0              # client: the host's, as last heard
var _pending := []               # client: [step, Callable] heap events for a step not reached yet
const CLOCK_EVERY := 6           # host: physics frames between heap_clock sends
const CATCH_UP := 4              # client: steps it may run in one frame when behind
var _walker_h := {}              # walker -> the surface height under it last frame


func _ready() -> void:
	_noise.seed = 3
	_noise.frequency = 0.18
	_noise.fractal_octaves = 4
	_active.resize(TILES_X * TILES_Z)
	_dirty.resize(TILES_X * TILES_Z)
	_redraw.resize(TILES_X * TILES_Z)
	_slump.resize(TILES_X * TILES_Z)
	for dj in range(-DIG_RADIUS, DIG_RADIUS + 1):
		for di in range(-DIG_RADIUS, DIG_RADIUS + 1):
			_dig_w.append(exp(-(di * di + dj * dj) * 0.5))
	_load_parts()
	_build_heights()
	var volume := 0.0
	for y in _h:
		volume += y
	unit = volume * CELL * CELL / float(GameState.PILE_START - spill_pieces)

	_img = Image.create_from_data(GRID_X, GRID_Z, false, Image.FORMAT_RF, _h.to_byte_array())
	_tex = ImageTexture.create_from_image(_img)
	_tex_prev = ImageTexture.create_from_image(_img)
	heap_material.set_shader_parameter("height_field", _tex)
	heap_material.set_shader_parameter("height_prev", _tex_prev)
	heap_material.set_shader_parameter("grid", Vector2i(GRID_X, GRID_Z))
	heap_material.set_shader_parameter("cell_size", CELL)
	var plane := PlaneMesh.new()
	plane.size = Vector2(GRID_X - 1, GRID_Z - 1) * CELL  # vertices sit on cell centres
	plane.subdivide_width = GRID_X - 2
	plane.subdivide_depth = GRID_Z - 2
	plane.material = heap_material
	var heap := MeshInstance3D.new()
	heap.mesh = plane
	heap.custom_aabb = AABB(Vector3(-GRID_X * CELL * 0.5, -0.1, -GRID_Z * CELL * 0.5), Vector3(GRID_X * CELL, LANTERN_TOP + 0.5, GRID_Z * CELL))
	add_child(heap)

	for cz in CHUNKS_Z:
		for cx in CHUNKS_X:
			var shape := HeightMapShape3D.new()
			shape.map_width = CHUNK + 1
			shape.map_depth = CHUNK + 1
			var col := CollisionShape3D.new()
			col.shape = shape
			col.scale = Vector3.ONE * CELL  # samples are 1 unit apart; heights are divided by CELL
			# Its middle sample over cell (cx * CHUNK + CHUNK / 2, ...); past the grid it reads 0.
			col.position = _cell_pos(Vector2i(cx * CHUNK + CHUNK / 2, cz * CHUNK + CHUNK / 2))
			add_child(col)
			_shapes.append(shape)
	_chunk_dirty.resize(CHUNKS_X * CHUNKS_Z)
	_chunk_dirty.fill(1)
	_drawn_h = _h.duplicate()
	_update_shape()

	_build_surface()
	_build_spill()
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.006
	outline.albedo_color = Color(1.0, 0.82, 0.45)
	_mark_mi.material_overlay = outline
	_mark_mi.visible = false
	add_child(_mark_mi)
	GameState.bullets_taken.connect(_on_bullets_taken)
	GameState.bullets_thrown.connect(_on_bullets_thrown)
	GameState.loose_taken.connect(_on_loose_taken)
	GameState.scrap_collapse.connect(_on_collapse)
	GameState.heap_clock.connect(func(s: int) -> void: _host_step = maxi(_host_step, s))
	GameState.pile_changed.connect(func(count: int) -> void: visible = count > 0)
	visible = GameState.pile > 0


func _load_parts() -> void:
	var list: Array = []
	for p: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(PARTS_FILE)):
		if KIND_WEIGHT.has(p.tur):
			p.glb = PARTS_FILE.get_base_dir().path_join(p.glb.get_file())
			list.append(p)
	var in_kind := {}
	for p: Dictionary in list:
		in_kind[p.tur] = in_kind.get(p.tur, 0) + 1
	for p: Dictionary in list:  # all at once, on the loader's threads: one by one took 1.4 s
		ResourceLoader.load_threaded_request(p.glb)
	var total := 0.0
	for p: Dictionary in list:
		var glb: Node = (ResourceLoader.load_threaded_get(p.glb) as PackedScene).instantiate()
		var mi: MeshInstance3D = glb.find_children("*", "MeshInstance3D", true, false)[0]
		var mesh: Mesh = mi.mesh
		_part_mesh.append(mesh)
		var hull: CollisionShape3D = glb.find_children("*", "CollisionShape3D", true, false)[0]
		_part_hull.append(hull.shape)
		_part_hull_at.append(Transform3D(Basis(), -mesh.get_aabb().get_center()) * _to_root(mi).affine_inverse() * _to_root(hull))
		_part_mass.append(clampf(p.kutle_kg, 0.05, 30.0))
		glb.free()
		_part_low.append(_low_poly(mesh))
		var box: AABB = mesh.get_aabb()
		_part_size.append(box.size)
		_part_mid.append(box.get_center())
		var shape := BoxShape3D.new()
		shape.size = box.size.max(Vector3.ONE * 0.02)
		_part_shape.append(shape)
		var dims := [box.size.x, box.size.y, box.size.z]
		dims.sort()
		_part_foot.append(dims[1] * dims[2])
		# A kind's share grows with the root of its count: 96 pipe pieces don't bury the one spring.
		total += KIND_WEIGHT[p.tur] / sqrt(in_kind[p.tur])
		_part_pick.append(total)
	var face := 0.0
	for i in _part_pick.size():
		if _part_size[i][_part_size[i].max_axis_index()] >= SURFACE_MIN:
			face += _part_pick[i] - (_part_pick[i - 1] if i > 0 else 0.0)
		_face_pick.append(face)
	for i in _part_pick.size():
		_part_pick[i] /= total
		_face_pick[i] /= face


## `n`'s transform in its scene, outside a tree.
static func _to_root(n: Node) -> Transform3D:
	var t := Transform3D()
	while n:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## `mesh` brought down to about LOW_TRIS triangles with the engine's own simplifier (meshoptimizer,
## as import makes LODs); `mesh` itself where it is already light or won't simplify.
func _low_poly(mesh: Mesh) -> Mesh:
	var tris := 0
	for s in mesh.get_surface_count():
		tris += mesh.surface_get_array_index_len(s) / 3
	if tris <= LOW_TRIS * 1.3:
		return mesh
	var im := ImporterMesh.new()
	for s in mesh.get_surface_count():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s), [], {}, mesh.surface_get_material(s))
	im.generate_lods(25.0, 60.0, [])
	var out := ArrayMesh.new()
	var keep := float(LOW_TRIS) / tris
	for s in im.get_surface_count():
		var arrays := im.get_surface_arrays(s)
		var full: int = arrays[Mesh.ARRAY_INDEX].size()
		# The lightest LOD still over half our share of this surface: the last ones collapse
		# a crate into a dozen triangles.
		for l in im.get_surface_lod_count(s):
			var idx := im.get_surface_lod_indices(s, l)
			if idx.size() < full * keep * 0.5:
				break
			arrays[Mesh.ARRAY_INDEX] = idx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(s, im.get_surface_material(s))
	return out


## The mesh's own transform for a piece whose box centre is at `t`.
func _drawn(part: int, t: Transform3D) -> Transform3D:
	return t.translated_local(-_part_mid[part])


func _pick_part(r: float, on_face := false) -> int:
	var pick := _face_pick if on_face else _part_pick
	return clampi(pick.bsearch(r), 0, pick.size() - 1)


## The starting heap: packed to the roof from the west wall, a face that wanders along the hall
## with spurs and bays in it, lumps all over, and no slope steeper than LOCK_SLOPE.
func _build_heights() -> void:
	_h.resize(GRID_X * GRID_Z)
	_ceil.resize(GRID_X * GRID_Z)
	for j in GRID_Z:
		for i in GRID_X:
			var g := global_position + _cell_pos(Vector2i(i, j))
			var k := j * GRID_X + i
			_ceil[k] = ceiling_at(g.x, g.z) - global_position.y
			var foot := FOOT_X + _noise.get_noise_1d(g.z * 0.6) * FOOT_WANDER * 1.6 + _noise.get_noise_2d(g.z, 40.0) * 1.2
			var y := (foot - g.x) * LOCK_SLOPE * 0.62 + _noise.get_noise_2d(g.x * 1.7, g.z * 1.7) * LUMP
			_h[k] = clampf(y, 0.0, _ceil[k])
	# No step between neighbours over LOCK_STEP: lower whatever stands too proud, two sweeps
	# (the chamfer distance transform's), so the heap starts at rest.
	for sweep in 2:
		var rng := range(GRID_Z) if sweep == 0 else range(GRID_Z - 1, -1, -1)
		var dir := 1 if sweep == 0 else -1
		for j: int in rng:
			for n in GRID_X:
				var i := n if dir == 1 else GRID_X - 1 - n
				var k := j * GRID_X + i
				var lim := _h[k]
				if i - dir >= 0 and i - dir < GRID_X:
					lim = minf(lim, _h[k - dir] + LOCK_STEP)
				if j - dir >= 0 and j - dir < GRID_Z:
					lim = minf(lim, _h[k - dir * GRID_X] + LOCK_STEP)
				_h[k] = lim
	for k in _h.size():
		if _h[k] < 0.004:
			_h[k] = 0.0


## The roof's underside over world point (x, z), less ROOF_GAP.
static func ceiling_at(x: float, z: float) -> float:
	if x > LANTERN.x and x < LANTERN.z and z > LANTERN.y and z < LANTERN.w:
		return LANTERN_TOP
	return EAVE + (HALF_SPAN - absf(x)) * PITCH - ROOF_GAP


## Surface pieces: every cell of the face that shows gets pieces until their footprints cover it
## `cover` times over (its true area: more where it's steep). Each lies on its widest side along
## the slope, tumbled and sunk into the ones round it.
func _build_surface() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var per_part: Array[Array] = []  # plain Arrays while filling: packed arrays in an Array copy on access
	for p in _part_mesh.size():
		per_part.append([])
	var cell_slots := {}  # cell index -> Array of [part, index]
	for j in range(1, GRID_Z - 1):
		for i in range(1, GRID_X - 1):
			var cell := Vector2i(i, j)
			var k := j * GRID_X + i
			if _h[k] < 0.03 or _h[k] > _ceil[k] - 0.3:
				continue  # bare floor; pressed into the roof nobody sees it
			var n := _cell_normal(cell)
			var area := CELL * CELL / maxf(n.y, 0.2) * cover
			var count := 0
			while area > 0.0 and count < MAX_PER_CELL:
				var part := _pick_part(rng.randf(), true)
				area -= _part_foot[part]
				count += 1
				var s := _part_size[part]
				# Widest side down: the smallest axis along the normal.
				var thin := 0 if s.x <= s.y and s.x <= s.z else (1 if s.y <= s.z else 2)
				var lay := Basis()
				if thin == 0:
					lay = Basis(Vector3.BACK, PI * 0.5)
				elif thin == 2:
					lay = Basis(Vector3.RIGHT, PI * 0.5)
				var tumble := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.7))
				var up := Basis(Quaternion(Vector3.UP, n))
				var b := up * tumble * Basis(Vector3.UP, rng.randf() * TAU) * lay
				var o := _cell_pos(cell) + Vector3(rng.randf_range(-0.5, 0.5) * CELL, 0.0, rng.randf_range(-0.5, 0.5) * CELL)
				# A quarter sunk at most: hooked into what is under it, its shape still all there to see.
				o.y = s[thin] * rng.randf_range(0.25, 0.5)
				var idx: int = per_part[part].size()
				per_part[part].append(Transform3D(b, o))
				var list: Array = cell_slots.get(k, [])
				list.append([part, idx])
				cell_slots[k] = list
	for p in _part_mesh.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _part_low[p]
		mm.instance_count = per_part[p].size()
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		# Only the big ones cast: thousands of tools in every cascade cost more than they show.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _part_size[p].length() > 0.9 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_surface.append(node)
	_cell_first.resize(GRID_X * GRID_Z + 1)
	for key in GRID_X * GRID_Z:
		_cell_first[key] = _slot_part.size()
		for e: Array in cell_slots.get(key, []):
			var t: Transform3D = per_part[e[0]][e[1]]
			var u: float = t.origin.x / CELL + (GRID_X - 1) * 0.5
			var v: float = t.origin.z / CELL + (GRID_Z - 1) * 0.5
			var ci := clampi(floori(u), 0, GRID_X - 2)
			var cj := clampi(floori(v), 0, GRID_Z - 2)
			_slot_part.append(e[0])
			_slot_index.append(e[1])
			_slot_k.append(cj * GRID_X + ci)
			_slot_f.append(Vector2(clampf(u - ci, 0.0, 1.0), clampf(v - cj, 0.0, 1.0)))
			_slot_xform.append(t)
	_cell_first[GRID_X * GRID_Z] = _slot_part.size()
	_mark(_redraw, Rect2i(0, 0, GRID_X, GRID_Z))
	_update_surface_pieces(Rect2i(0, 0, GRID_X, GRID_Z))
	_redraw.fill(Rect2i())


## Loose pieces on the floor in front of the face: dense at the foot, thinning out. Laid flat,
## each a bare static body, numbered 0.. in placement order (the same on every peer).
func _build_spill() -> void:
	for p in _part_mesh.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _part_mesh[p]
		mm.instance_count = 16
		mm.visible_instance_count = 0
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_spill.append(node)
		_part_slots.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for id in spill_pieces:
		var j := rng.randi_range(2, GRID_Z - 3)
		var i := GRID_X - 1
		while i > 0 and _h[j * GRID_X + i - 1] < 0.15:  # walk west to where the foot thickens
			i -= 1
		var p := _cell_pos(Vector2i(i, j)) + Vector3(spill_reach * pow(rng.randf(), 2.2), 0.0, rng.randf_range(-0.5, 0.5) * CELL)
		var part := _pick_part(rng.randf())
		_add_loose(id, part, rest_on(p, part, rng.randf() * TAU))


## A flat resting transform for `part` at local point `p` on the heap or the floor.
func rest_on(p: Vector3, part: int, yaw: float) -> Transform3D:
	var s := _part_size[part]
	var thin := 0 if s.x <= s.y and s.x <= s.z else (1 if s.y <= s.z else 2)
	var lay := Basis()
	if thin == 0:
		lay = Basis(Vector3.BACK, PI * 0.5)
	elif thin == 2:
		lay = Basis(Vector3.RIGHT, PI * 0.5)
	p.y = _height_smooth(p) + s[thin] * 0.5
	return Transform3D(Basis(Vector3.UP, yaw) * lay, p)


func _add_loose(id: int, part: int, t: Transform3D) -> void:
	var rid := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(rid, _part_shape[part].get_rid())
	PhysicsServer3D.body_set_collision_layer(rid, SCRAP_LAYER)
	PhysicsServer3D.body_set_collision_mask(rid, 0)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform * t)
	PhysicsServer3D.body_set_space(rid, get_world_3d().space)
	var slots: Array = _part_slots[part]
	var mm := _spill[part].multimesh
	if slots.size() >= mm.instance_count:  # resizing clears the instances
		mm.instance_count = slots.size() * 2
		for s in slots.size():
			mm.set_instance_transform(s, _drawn(part, _id_index[slots[s]][3]))
	mm.set_instance_transform(slots.size(), _drawn(part, t))
	_id_index[id] = [part, slots.size(), rid, t]
	_spill_index[rid] = id
	slots.append(id)
	mm.visible_instance_count = slots.size()


## Swap-remove so each part's drawn instances stay packed at the front.
func _remove_loose(id: int) -> void:
	var rec: Array = _id_index[id]
	var slots: Array = _part_slots[rec[0]]
	var mm := _spill[rec[0]].multimesh
	var last := slots.size() - 1
	if rec[1] < last:
		var moved: int = slots[last]
		slots[rec[1]] = moved
		_id_index[moved][1] = rec[1]
		mm.set_instance_transform(rec[1], _drawn(rec[0], _id_index[moved][3]))
	slots.resize(last)
	mm.visible_instance_count = last
	_spill_index.erase(rec[2])
	PhysicsServer3D.free_rid(rec[2])
	_id_index.erase(id)


## True if a ray hit at `at` on `collider` / `rid` is scrap: a loose piece, or the heap where it
## is at least a piece deep (the height field runs flat over the floor in front of it).
func is_grabbable(collider: Object, rid: RID, at: Vector3) -> bool:
	if collider == self:
		return _height_at(to_local(at)) > GRAB_DEPTH
	return _spill_index.has(rid) or (collider is RigidBody3D and _awake.has(collider))


## Whether the loose piece `id` is lying here (not yet picked up).
func has_loose(id: int) -> bool:
	return _id_index.has(id)


## Id of the loose piece a ray hit (resting or moving), or -1 if it hit something else.
func loose_id(collider: Object, rid: RID) -> int:
	if _spill_index.has(rid):
		return _spill_index[rid]
	if collider is RigidBody3D and _awake.has(collider):
		return collider.get_meta("id")
	return -1


func _on_loose_taken(id: int) -> void:
	if _id_index.has(id):
		_remove_loose(id)
		return
	for body in _awake:
		if body.get_meta("id") == id:
			_awake.erase(body)
			body.queue_free()
			return


## The drawn piece nearest to local point `local` within SURFACE_GRAB, or -1.
func _nearest_slot(local: Vector3) -> int:
	var cell := _cell_of(local)
	var best := -1
	var best_d := SURFACE_GRAB
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var c := cell + Vector2i(di, dj)
			if not _in_grid(c):
				continue
			var key := c.y * GRID_X + c.x
			for s in range(_cell_first[key], _cell_first[key + 1]):
				if _surface_removed.has(s):
					continue
				var pos := _slot_xform[s].origin
				pos.y += _height_smooth(pos)
				if pos.distance_to(local) < best_d:
					best_d = pos.distance_to(local)
					best = s
	return best


## Hides the drawn piece nearest to a heap take, so the one looked at is the one that goes.
func _take_surface_near(local: Vector3) -> void:
	var best := _nearest_slot(local)
	if best >= 0:
		if best == _marked:
			highlight(Vector3.ZERO, false)
		_surface_removed[best] = _height_smooth(_slot_xform[best].origin)
		_surface[_slot_part[best]].multimesh.set_instance_transform(_slot_index[best], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


## The piece a player looks at on the heap at world point `at`: drawn in full with an outline,
## the one E takes. `on` false clears it. Local: each machine marks its own player's.
func highlight(at: Vector3, on: bool) -> void:
	var s := _nearest_slot(to_local(at)) if on else -1
	if s == _marked:
		return
	if _marked >= 0 and not _surface_removed.has(_marked):
		_redraw_slot(_marked)
	_marked = s
	_mark_mi.visible = s >= 0
	if s < 0:
		return
	var p := _slot_part[s]
	var t := _slot_xform[s]
	t.origin.y += _height_smooth(t.origin)
	_mark_mi.mesh = _part_mesh[p]
	_mark_mi.transform = _drawn(p, t)
	_surface[p].multimesh.set_instance_transform(_slot_index[s], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


func _redraw_slot(s: int) -> void:
	var t := _slot_xform[s]
	var y := _height_smooth(t.origin)
	t.origin.y += y
	t = _drawn(_slot_part[s], t)
	if y < 0.03:
		t.basis = Basis.from_scale(Vector3.ZERO)
	_surface[_slot_part[s]].multimesh.set_instance_transform(_slot_index[s], t)


## A piece as a rigid body: its own convex hull and weight. `t` is global, at the box centre.
func _make_body(part: int, t: Transform3D) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = _part_mass[part]
	body.continuous_cd = true
	body.angular_damp = 1.5
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.8
	body.physics_material_override.bounce = 0.15
	var col := CollisionShape3D.new()
	col.shape = _part_hull[part]
	col.transform = _part_hull_at[part]
	body.add_child(col)
	var look := MeshInstance3D.new()
	look.mesh = _part_mesh[part]
	look.position = -_part_mid[part]
	body.add_child(look)
	body.collision_layer = SCRAP_LAYER
	body.collision_mask = 1 | SCRAP_LAYER
	body.top_level = true
	body.transform = t
	body.set_meta("part", part)
	add_child(body)
	return body


## Walkers kick resting loose pieces near their feet into real bodies; bodies that come to rest
## turn back into static loose pieces. Only these few dozen are ever simulated.
# Co-op: kicks are local visuals, so loose pieces can drift apart a little between peers.
func _update_awake() -> void:
	for walker in get_tree().get_nodes_in_group("walker"):
		var v: Vector3 = walker.velocity * Vector3(1, 0, 1)
		if v.length() < WAKE_SPEED or _awake.size() >= MAX_AWAKE:
			continue
		for hit in _loose_near(walker.global_position, WAKE_RADIUS, MAX_AWAKE - _awake.size()):
			var id: int = _spill_index.get(hit.rid, -1)
			if id < 0:
				continue
			var rec: Array = _id_index[id]
			var t: Transform3D = global_transform * rec[3]
			var part: int = rec[0]
			_remove_loose(id)
			_spawn_loose(id, part, t, v * randf_range(0.4, 0.9) + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.6), randf_range(-0.3, 0.3)))
	for i in range(_awake.size() - 1, -1, -1):
		var body := _awake[i]
		var age: int = Engine.get_physics_frames() - body.get_meta("woke")
		var resting := body.sleeping or (body.linear_velocity.length() < 0.03 and body.angular_velocity.length() < 0.2)
		if (age > 15 and resting) or age > 600:
			var t := global_transform.affine_inverse() * body.global_transform
			_add_loose(body.get_meta("id"), body.get_meta("part"), Transform3D(t.basis.orthonormalized(), t.origin))
			body.queue_free()
			_awake.remove_at(i)


func _loose_near(at: Vector3, radius: float, max_results := 32) -> Array[Dictionary]:
	_query_sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _query_sphere
	q.transform = Transform3D(Basis(), at)
	q.collision_mask = SCRAP_LAYER
	return get_world_3d().direct_space_state.intersect_shape(q, max_results)


## Throws `count` carried pieces from `from` along `dir` with some spread; they land loose.
func _on_bullets_thrown(from: Vector3, dir: Vector3, count: int, first_id: int) -> void:
	for n in count:
		var id := first_id + n
		var b := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
		var spread := Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)) * 1.2
		_spawn_loose(id, _pick_part(_hash01(id)), Transform3D(b, from + spread * 0.05), dir * randf_range(3.0, 6.0) + spread)


func _spawn_loose(id: int, part: int, t: Transform3D, velocity: Vector3) -> void:
	var body := _make_body(part, Transform3D(t.basis.orthonormalized(), t.origin))
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	body.set_meta("woke", Engine.get_physics_frames())
	body.set_meta("id", id)
	_awake.append(body)


## Host: the heap as it is now, for a player joining mid-game (GameState sends it). Heights,
## what is still sliding, slumping and digging (so both go on the same way), the surface pieces
## picked off, and thrown pieces with where they lie. Pieces taken from the starting spill come
## separately (GameState's taken ids).
func snapshot() -> Array:
	var thrown := []
	for id: int in _id_index:
		if id >= GameState.THROWN_ID_START:
			thrown.append([id, _id_index[id][0], _id_index[id][3]])
	for body in _awake:
		if body.get_meta("id") >= GameState.THROWN_ID_START:
			var t := global_transform.affine_inverse() * body.global_transform
			thrown.append([body.get_meta("id"), body.get_meta("part"), Transform3D(t.basis.orthonormalized(), t.origin)])
	return [_h, _active, _digs, _surface_removed, thrown, _slump, step]


## Joiner: takes the host's snapshot() over the starting heap this machine built.
func restore(snap: Array) -> void:
	_h = snap[0]
	_active.assign(snap[1])
	_any_active = _active.any(func(r: Rect2i) -> bool: return r.has_area())
	_digs = snap[2]
	for s: int in snap[3]:
		_surface_removed[s] = snap[3][s]
		_surface[_slot_part[s]].multimesh.set_instance_transform(_slot_index[s], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	for b: Array in snap[4]:
		if not _id_index.has(b[0]):
			_add_loose(b[0], b[1], b[2])
	if snap.size() > 5:
		_slump = snap[5]
		_any_slump = _slump.has(1)
		step = snap[6]
		_host_step = step
	_mark(_dirty, Rect2i(0, 0, GRID_X, GRID_Z))
	_any_dirty = true


func _exit_tree() -> void:
	for rec: Array in _id_index.values():
		PhysicsServer3D.free_rid(rec[2])


## Pieces out of the heap at `at`, starting with the drawn one nearest to it.
func _on_bullets_taken(at: Vector3, count: int, at_step: int) -> void:
	var local := to_local(at)
	for n in mini(count, 4):
		_take_surface_near(local)
	var cell := _cell_of(local).clamp(Vector2i.ZERO, Vector2i(GRID_X - 1, GRID_Z - 1))
	_at_step(at_step, func() -> void: _digs.append([cell, count * unit / (CELL * CELL)]))
	if not Net.is_client:
		_strain_at(cell, count)


## Runs a heap change now on the host; on a client at step `at_step`, where the host ran it.
func _at_step(at_step: int, change: Callable) -> void:
	_host_step = maxi(_host_step, at_step)
	if not Net.is_client or at_step <= step:
		change.call()
	else:
		_pending.append([at_step, change])


func _run_pending() -> void:
	while not _pending.is_empty() and _pending[0][0] <= step:
		_pending.pop_front()[1].call()


## Host: a take off a locked face strains it; past its limit, that part of the face gives way.
## The limit and the size of the fall are rolled here and nowhere else.
func _strain_at(cell: Vector2i, count: int) -> void:
	if _steepest_near(cell) < REPOSE_STEP * STRAIN_SLOPE:
		return
	var t := (cell.y / TILE) * TILES_X + cell.x / TILE
	if not _limit.has(t):
		_limit[t] = randf_range(STRAIN_MIN, STRAIN_MAX)
	_strain[t] = _strain.get(t, 0.0) + 1.0 + log(float(count))
	if _strain[t] >= _limit[t]:
		_strain.erase(t)
		_limit.erase(t)
		var r := roundi(randf_range(SLUMP_RADIUS.x, SLUMP_RADIUS.y) / CELL)
		GameState.collapse_scrap(cell, r, randi())


## Steepest step between neighbours within two cells of `cell`.
func _steepest_near(cell: Vector2i) -> float:
	var worst := 0.0
	for y in range(maxi(cell.y - 2, 0), mini(cell.y + 3, GRID_Z - 1)):
		for x in range(maxi(cell.x - 2, 0), mini(cell.x + 3, GRID_X - 1)):
			var k := y * GRID_X + x
			worst = maxf(worst, maxf(absf(_h[k] - _h[k + 1]), absf(_h[k] - _h[k + GRID_X])))
	return worst


## A part of the face gives way (GameState scrap_collapse, the host's call): round `cell` and up
## the slope above it everything slumps to REPOSE_SLOPE, so the top comes down with it; pieces
## tumble off the face from `seed`.
func _on_collapse(cell: Vector2i, radius: int, seed: int, at_step: int) -> void:
	_at_step(at_step, _collapse.bind(cell, radius, seed))


func _collapse(cell: Vector2i, radius: int, seed: int) -> void:
	# Uphill: against the slope's fall line, where the face comes down from.
	var k := clampi(cell.y, 1, GRID_Z - 2) * GRID_X + clampi(cell.x, 1, GRID_X - 2)
	var up := Vector2(_h[k + 1] - _h[k - 1], _h[k + GRID_X] - _h[k - GRID_X])
	up = up.normalized() if up.length() > 1e-5 else Vector2(-1, 0)
	var top := Vector2(cell) + up * radius * 1.3
	for tj in TILES_Z:
		for ti in TILES_X:
			var c := Vector2((ti + 0.5) * TILE, (tj + 0.5) * TILE)
			if c.distance_to(Vector2(cell)) < radius + TILE * 0.7 or c.distance_to(top) < radius * 1.4 + TILE * 0.7:
				_slump[tj * TILES_X + ti] = 1
				_mark(_active, Rect2i(ti * TILE, tj * TILE, TILE, TILE))
	_any_slump = true
	_any_active = true
	_shape_timer = 0.0
	_tumble(cell, top, radius, seed)


## Real pieces off the slumping face: from the drawn ones over it, which go, and fall from where
## they lay down the slope.
func _tumble(cell: Vector2i, top: Vector2, radius: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var want := mini(rng.randi_range(18, 36) + radius, MAX_DEBRIS)
	while _debris.size() + want > MAX_DEBRIS and not _debris.is_empty():
		_debris.pop_front().queue_free()
	var fall := (Vector2(cell) - top).normalized()
	for n in want * 4:
		if want <= 0:
			break
		var c := Vector2i(Vector2(cell).lerp(top, rng.randf()) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * radius)
		if not _in_grid(c):
			continue
		var key := c.y * GRID_X + c.x
		var s0 := _cell_first[key]
		var s1 := _cell_first[key + 1]
		if s1 == s0:
			continue
		var s := s0 + rng.randi() % (s1 - s0)
		if _surface_removed.has(s):
			continue
		_surface_removed[s] = _height_smooth(_slot_xform[s].origin)
		var t := _slot_xform[s]
		t.origin.y += _height_smooth(t.origin) + 0.05
		_surface[_slot_part[s]].multimesh.set_instance_transform(_slot_index[s], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		var body := _make_body(_slot_part[s], global_transform * t)
		var speed := rng.randf_range(1.0, 3.5)
		body.linear_velocity = global_basis * Vector3(fall.x * speed, rng.randf_range(-0.5, 1.0), fall.y * speed)
		body.angular_velocity = Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		body.set_meta("since", -1.0)
		_debris.append(body)
		want -= 1


## Tumbling pieces shove walkers they hit; stopped ones freeze where they lie and, after a while
## or once the heap has buried them, go back into it.
func _update_debris(delta: float) -> void:
	var walkers := get_tree().get_nodes_in_group("walker")
	for i in range(_debris.size() - 1, -1, -1):
		var body := _debris[i]
		var v := body.linear_velocity
		if not body.freeze:
			for w: Node3D in walkers:
				var mid := w.global_position + Vector3.UP * 0.9
				var d := body.global_position - mid
				if absf(d.y) < 1.0 and Vector2(d.x, d.z).length() < SHOVE_REACH and v.length() > 0.8 and w.has_method("shove"):
					w.shove(Vector3(v.x, 0.0, v.z) * SHOVE_SHARE)
			if body.sleeping or (v.length() < 0.05 and body.angular_velocity.length() < 0.2):
				var since: float = body.get_meta("since")
				body.set_meta("since", 0.0 if since < 0.0 else since + delta)
				if since > 0.5:
					body.freeze = true
			else:
				body.set_meta("since", -1.0)
			continue
		var since: float = body.get_meta("since") + delta
		body.set_meta("since", since)
		var local := to_local(body.global_position)
		if since > DEBRIS_LIFE or _height_smooth(local) > local.y + 0.05:
			body.queue_free()
			_debris.remove_at(i)
		elif _height_smooth(local) < local.y - 0.4:
			body.freeze = false  # dug out from under it
			body.set_meta("since", -1.0)


## Where the heap rises under a walker (a slump pouring onto them) it shoves them off down the
## slope: a height field can't push a body by itself.
func _update_pour(delta: float) -> void:
	for w: Node3D in get_tree().get_nodes_in_group("walker"):
		var local := to_local(w.global_position)
		var c := _cell_of(local)
		if not _in_grid(c) or c.x < 1 or c.y < 1 or c.x > GRID_X - 2 or c.y > GRID_Z - 2:
			_walker_h.erase(w)
			continue
		var y := _height_smooth(local)
		var was: float = _walker_h.get(w, y)
		_walker_h[w] = y
		var rise := (y - was) / delta
		if rise > 0.05 and w.has_method("shove"):
			var k := c.y * GRID_X + c.x
			var down := Vector3(_h[k - 1] - _h[k + 1], 0.0, _h[k - GRID_X] - _h[k + GRID_X])
			if down.length() < 1e-4:
				down = Vector3(1, 0, 0)  # flat: out toward the hall
			w.shove(global_basis * down.normalized() * minf(rise * POUR_SHOVE, 7.0))


func _physics_process(delta: float) -> void:
	_update_awake()
	_update_debris(delta)
	# A client's heap keeps to the host's clock: behind, it catches up a few steps; level, it waits.
	var steps := clampi(_host_step - step, 0, CATCH_UP) if Net.is_client else 1
	for n in steps:
		_run_pending()
		step += 1
		_step()
	_run_pending()
	if not Net.is_client and step % CLOCK_EVERY == 0:
		GameState.send_heap_clock(step)

	if _any_dirty:
		_tex_prev.update(_img)
		_img.set_data(GRID_X, GRID_Z, false, Image.FORMAT_RF, _h.to_byte_array())
		_tex.update(_img)
		_prev_stale = true
		for area in _dirty:
			if area.has_area():
				_update_cells(area)
		_dirty.fill(Rect2i())
		_any_dirty = false
		_shape_dirty = true
	elif _prev_stale:
		_tex_prev.update(_img)
		_prev_stale = false
	# Pieces on a slumping face move every few frames: thousands of them, every frame cost 20 ms.
	if not _any_slump or Engine.get_physics_frames() % SLUMP_REDRAW_EVERY == 0:
		for area in _redraw:
			if area.has_area():
				_update_surface_pieces(area)
		_redraw.fill(Rect2i())
	_update_pour(delta)
	_shape_timer -= delta
	if _shape_dirty and (_shape_timer <= 0.0 or _any_slump and _shape_timer <= COLLISION_INTERVAL - SLUMP_COLLISION_INTERVAL):
		_update_shape()


## One heap step: digs, then slides.
func _step() -> void:
	for dig in _digs:
		dig[1] = _dig(dig[0], dig[1])
	_digs = _digs.filter(func(d: Array) -> bool: return d[1] > 1e-9 and (_any_active or _material_near(d[0])))
	for pass_i in (SLUMP_PASSES if _any_slump else RELAX_PASSES):
		if not _any_active:
			break
		_relax()
	if _any_slump and not _any_active:  # the face came to rest: it locks again where it lies
		_slump.fill(0)
		_any_slump = false


func _process(_delta: float) -> void:
	heap_material.set_shader_parameter("blend", Engine.get_physics_interpolation_fraction())


## Removes up to `amount` height-metres around `cell`, Gaussian-weighted; returns the rest.
func _dig(cell: Vector2i, amount: float) -> float:
	var total := 0.0
	var n := 0
	for y in range(cell.y - DIG_RADIUS, cell.y + DIG_RADIUS + 1):
		for x in range(cell.x - DIG_RADIUS, cell.x + DIG_RADIUS + 1):
			if x >= 0 and y >= 0 and x < GRID_X and y < GRID_Z:
				total += _dig_w[n] * signf(_h[y * GRID_X + x])
			n += 1
	if total <= 0.0:
		return amount
	var left := amount
	n = 0
	for y in range(cell.y - DIG_RADIUS, cell.y + DIG_RADIUS + 1):
		for x in range(cell.x - DIG_RADIUS, cell.x + DIG_RADIUS + 1):
			if x >= 0 and y >= 0 and x < GRID_X and y < GRID_Z:
				var k := y * GRID_X + x
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
	for y in range(maxi(cell.y - DIG_RADIUS, 0), mini(cell.y + DIG_RADIUS + 1, GRID_Z)):
		for x in range(maxi(cell.x - DIG_RADIUS, 0), mini(cell.x + DIG_RADIUS + 1, GRID_X)):
			if _h[y * GRID_X + x] > 0.0:
				return true
	return false


## One pass over the active tiles: any neighbour pair steeper than it may stand (LOCK_STEP, or
## REPOSE_STEP where a face is giving way) sheds half the excess downhill. What moved is marked
## dirty and, grown a cell up and left so slides cross tile edges, becomes the next pass's area.
# Rows run top to bottom across a whole tile row, so one dig visits cells in the same order
# as a single rectangle would.
func _relax() -> void:
	var cur := _active.duplicate()
	_active.fill(Rect2i())
	_any_active = false
	var lo_x := PackedInt32Array()
	lo_x.resize(TILES_X * TILES_Z)
	lo_x.fill(GRID_X)
	var lo_y := lo_x.duplicate()
	var hi_x := PackedInt32Array()
	hi_x.resize(TILES_X * TILES_Z)
	hi_x.fill(-1)
	var hi_y := hi_x.duplicate()
	var h := _h
	_h = PackedFloat32Array()  # h is then the only reference: writes don't copy the array
	var slump := _slump
	for tj in TILES_Z:
		var row: Array[int] = []
		var y0 := GRID_Z
		var y1 := 0
		for t in range(tj * TILES_X, tj * TILES_X + TILES_X):
			var r: Rect2i = cur[t]
			if r.has_area():
				row.append(t)
				y0 = mini(y0, r.position.y)
				y1 = maxi(y1, r.end.y)
		for j in range(y0, mini(y1, GRID_Z - 1)):
			var down_t := TILES_X if (j + 1) % TILE == 0 else 0  # the neighbour below is in the next tile row
			for t in row:
				var r: Rect2i = cur[t]
				if j < r.position.y or j >= r.end.y:
					continue
				var first := -1
				var last := -1
				var loose := slump[t] == 1
				var step_in := REPOSE_STEP if loose else LOCK_STEP
				var step_down := REPOSE_STEP if loose or slump[mini(t + down_t, slump.size() - 1)] == 1 else LOCK_STEP
				for i in range(r.position.x, mini(r.end.x, GRID_X - 1)):
					var k := j * GRID_X + i
					var hk := h[k]
					var step := step_in if (i + 1) % TILE != 0 else (REPOSE_STEP if loose or slump[t + 1] == 1 else LOCK_STEP)
					var d := hk - h[k + 1]  # right neighbour
					if absf(d) > step + MIN_SLIDE:
						var m := (absf(d) - step) * 0.5 * signf(d)
						hk -= m
						h[k] = hk
						h[k + 1] += m
						last = i
						if first < 0:
							first = i
					d = hk - h[k + GRID_X]  # neighbour below
					if absf(d) > step_down + MIN_SLIDE:
						var m := (absf(d) - step_down) * 0.5 * signf(d)
						h[k] = hk - m
						h[k + GRID_X] += m
						last = i
						if first < 0:
							first = i
				if last >= 0:
					lo_x[t] = mini(lo_x[t], first)
					lo_y[t] = mini(lo_y[t], j)
					hi_x[t] = maxi(hi_x[t], last + 1)
					hi_y[t] = maxi(hi_y[t], j + 1)
	_h = h
	for t in TILES_X * TILES_Z:
		if hi_x[t] < 0:
			continue
		var moved := Rect2i(lo_x[t], lo_y[t], hi_x[t] - lo_x[t] + 1, hi_y[t] - lo_y[t] + 1)
		_mark(_active, moved.grow_individual(1, 1, 0, 0))  # a pair is checked from its left / upper cell
		_mark(_dirty, moved)
		_any_active = true
		_any_dirty = true


## Adds `area` to the per-tile rectangles in `tiles`, split along tile edges.
func _mark(tiles: Array[Rect2i], area: Rect2i) -> void:
	area = area.intersection(Rect2i(0, 0, GRID_X, GRID_Z))
	if not area.has_area():
		return
	for tj in range(area.position.y / TILE, (area.end.y - 1) / TILE + 1):
		for ti in range(area.position.x / TILE, (area.end.x - 1) / TILE + 1):
			var part := area.intersection(Rect2i(ti * TILE, tj * TILE, TILE, TILE))
			var t := tj * TILES_X + ti
			tiles[t] = part if not tiles[t].has_area() else tiles[t].merge(part)


## Copies changed cells into the collision heights, and queues the pieces around cells that
## drifted a visible amount since they were last drawn.
func _update_cells(area: Rect2i) -> void:
	# Chunks share their edge row, so a cell on one's last row is the next one's first.
	for cz in range(maxi(area.position.y - 1, 0) / CHUNK, mini((area.end.y - 1) / CHUNK, CHUNKS_Z - 1) + 1):
		for cx in range(maxi(area.position.x - 1, 0) / CHUNK, mini((area.end.x - 1) / CHUNK, CHUNKS_X - 1) + 1):
			_chunk_dirty[cz * CHUNKS_X + cx] = 1
	for j in range(area.position.y, area.end.y):
		for i in range(area.position.x, area.end.x):
			var key := j * GRID_X + i
			var h := _h[key]
			if absf(h - _drawn_h[key]) >= REDRAW_STEP:
				_drawn_h[key] = h
				_mark(_redraw, Rect2i(i - 1, j - 1, 3, 3))


## Keeps surface pieces riding the cells in `area` (they sink with it, deeper into one another);
## hides them where the heap is gone.
func _update_surface_pieces(area: Rect2i) -> void:
	var h := _h
	for j in range(area.position.y, area.end.y):
		for i in range(area.position.x, area.end.x):
			var key := j * GRID_X + i
			for s in range(_cell_first[key], _cell_first[key + 1]):
				if s == _marked:
					continue
				var k := _slot_k[s]
				var f := _slot_f[s]
				var y := lerpf(lerpf(h[k], h[k + 1], f.x), lerpf(h[k + GRID_X], h[k + GRID_X + 1], f.x), f.y)
				if _surface_removed.has(s):
					# Dug on down, or covered by what slid: the next piece of the heap shows there.
					if absf(y - _surface_removed[s]) < RESURFACE:
						continue
					_surface_removed.erase(s)
				var t := _slot_xform[s]
				t.origin.y += y
				t = _drawn(_slot_part[s], t)
				if y < 0.03:
					t.basis = Basis.from_scale(Vector3.ZERO)
				_surface[_slot_part[s]].multimesh.set_instance_transform(_slot_index[s], t)


func _update_shape() -> void:
	for c in _chunk_dirty.size():
		if _chunk_dirty[c] == 0:
			continue
		_chunk_dirty[c] = 0
		var x0 := (c % CHUNKS_X) * CHUNK
		var z0 := (c / CHUNKS_X) * CHUNK
		var data := PackedFloat32Array()
		data.resize((CHUNK + 1) * (CHUNK + 1))
		for j in CHUNK + 1:
			var z := z0 + j
			if z >= GRID_Z:
				break
			for i in CHUNK + 1:
				var x := x0 + i
				if x >= GRID_X:
					break
				data[j * (CHUNK + 1) + i] = _h[z * GRID_X + x] / CELL
		_shapes[c].map_data = data
	_shape_dirty = false
	_shape_timer = COLLISION_INTERVAL


## The least pieces that must leave the heap before the surface over world point `p` is down
## to it: everything above a cone at LOCK_SLOPE (the steepest the heap stands) with its tip at
## `p` has to go, however one digs (key_cache.gd: what a key costs).
func min_take(p: Vector3) -> int:
	var c := _cell_of(to_local(p))
	var y := p.y - global_position.y
	var reach := ceili((LANTERN_TOP - y) / LOCK_STEP) + 1
	var vol := 0.0
	for j in range(maxi(c.y - reach, 0), mini(c.y + reach + 1, GRID_Z)):
		for i in range(maxi(c.x - reach, 0), mini(c.x + reach + 1, GRID_X)):
			var cone := y + LOCK_STEP * (absi(i - c.x) + absi(j - c.y))
			vol += maxf(_h[j * GRID_X + i] - cone, 0.0)
	return int(vol * CELL * CELL / unit)


## Height field cells, for spots over the heap (key_cache.gd).
func cells() -> Vector2i:
	return Vector2i(GRID_X, GRID_Z)


func cell_world(c: Vector2i) -> Vector3:
	return global_transform * (_cell_pos(c) + Vector3.UP * _h[c.y * GRID_X + c.x])


func _cell_of(local: Vector3) -> Vector2i:
	return Vector2i(floori(local.x / CELL + GRID_X * 0.5), floori(local.z / CELL + GRID_Z * 0.5))


func _cell_pos(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (GRID_X - 1) * 0.5) * CELL, 0.0, (cell.y - (GRID_Z - 1) * 0.5) * CELL)


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID_X and c.y < GRID_Z


## World height of the heap's surface above `world` (the floor where there is no heap); for
## things buried in it, like the crate keys.
func surface_y(world: Vector3) -> float:
	return global_position.y + _height_smooth(to_local(world))


func _height_at(local: Vector3) -> float:
	var c := _cell_of(local)
	return _h[c.y * GRID_X + c.x] if _in_grid(c) else 0.0


## Height between cell centres, interpolated like the drawn surface (bilinear).
func _height_smooth(local: Vector3) -> float:
	var u := local.x / CELL + (GRID_X - 1) * 0.5
	var v := local.z / CELL + (GRID_Z - 1) * 0.5
	var i := clampi(floori(u), 0, GRID_X - 2)
	var j := clampi(floori(v), 0, GRID_Z - 2)
	var fx := clampf(u - i, 0.0, 1.0)
	var fz := clampf(v - j, 0.0, 1.0)
	var k := j * GRID_X + i
	return lerpf(lerpf(_h[k], _h[k + 1], fx), lerpf(_h[k + GRID_X], _h[k + GRID_X + 1], fx), fz)


func _cell_normal(c: Vector2i) -> Vector3:
	var k := c.y * GRID_X + c.x
	return Vector3(_h[k - 1] - _h[k + 1], 2.0 * CELL, _h[k - GRID_X] - _h[k + GRID_X]).normalized()


## 0..1 from an id, the same on every peer.
static func _hash01(id: int) -> float:
	return float(hash(id) & 0xFFFF) / 65536.0
