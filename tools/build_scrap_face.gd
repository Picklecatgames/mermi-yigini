extends SceneTree
## Settles the scrap heap's face for real: builds the heap's shape (scripts/pile.gd, no pieces),
## then over it, CHUNK cells at a time, drops real pieces and lets them come to rest. Gravity
## pulls each chunk's pieces onto the face along its normal, so they lie on a 61° face as on the
## floor; pieces settled before are solid, so nothing ends up inside anything else.
## Each chunk is laid in layers (LAYERS): hand-sized pieces fill, the longer ones lie over them, the
## small ones run into the gaps last.
## Pieces lie down flat-ish onto the face, as dumped scrap does, not on end. The mix shifts slowly
## along the face (brass and copper thicker in places), with no edges between stretches.
## Chunks two apart settle at once. As soon as a group is down, rays from outside find its pieces
## that show; the buried ones leave the physics server (it holds only so many bodies, project
## setting jolt_physics_3d/limits/max_bodies: past it later chunks find no room and stay bare).
## The pieces that show at the end are written to data/scrap_face.json, and the buried ones under
## them apart (the heap draws those only once a take lays them open):
##   {"heights": hash of the heap's starting heights, "pieces": [[id, x, lift, z, qx, qy, qz, qw], ...],
##    "hidden": [the same, ...]}
## x, z in the heap's own space, lift over its surface there, at each piece's box centre.
##   Godot.exe --headless --path . --fixed-fps 60 -s res://tools/build_scrap_face.gd

const CHUNK := 8          # cells (2 m) a chunk
const BATCH := 60         # pieces per drop into a chunk
const DROP_FRAMES := 20
const SETTLE_FRAMES := 180
const GROUP := 6          # chunks settling at once
const LAYER := 1 << 6     # physics layer of the settling pieces
const RAYS := 4           # per cell side
const REACH := 4          # cells round a group its rays come from (a leaning ray travels ~1 m sideways)
const MIN_HITS := 3       # rays a piece must catch to be kept, unless it is all that stands in a gap (_straight)
const FILL_PASSES := 6    # rounds of dropping pieces into the gaps left, until none shows the heap's surface
const FILL_BATCH := 4000  # pieces falling at once while filling
const LOW_FACE := 2.0     # m: the face under this is looked at from low down too
const LOW_LOOK := Vector3(1.0, 0.25, 0.0)  # (hall space) out of the face toward an eye low in the hall
const OUT := "res://data/scrap_face.json"
## The layers, bottom up: which pieces (by their longest side, m), how many times their footprints
## cover the chunk's true area, how far they may tip off lying flat (rad), and how much of each
## kind (by area covered, not by count; a kind the heap takes but not named here gets 1). The
## hand-sized pieces fill, the longer pipes, valve wheels, rims and chain lie over them, nuts and
## bolts run into the gaps. Which kinds there are at all is the heap's (Pile.KIND_WEIGHT).
const LAYERS := [
	{"size": Vector2(0.12, 0.35), "cover": 3.0, "tilt": 0.5,
		"kinds": {"disli": 2.0, "boru": 1.1, "konserve": 1.5, "kola": 1.0, "zincir": 0.8, "yay": 0.8, "jant": 0.6, "kap": 0.4}},
	{"size": Vector2(0.35, 9.0), "cover": 0.15, "tilt": 0.3,
		"kinds": {"boru": 2.0, "jant": 1.5, "zincir": 1.2}},
	{"size": Vector2(0.0, 0.12), "cover": 0.4, "tilt": 0.8,
		"kinds": {"civata": 2.5, "boru": 0.7, "disli": 1.0, "konserve": 0.6}},
]
## A kind with few models in a layer gets less of its share, or its one model repeats all over the
## face (a single motor was every tenth piece): full share from this many models.
const KIND_MODELS := 4.0
## A model heavier than this (triangles in the face's light copy) turns up that much less often:
## the face draws ~30 000 pieces, and some light copies keep 1 500-2 000 triangles (the simplifier
## stops at UV seams).
const TRIS_EASY := 250.0
## Off the face: one model that stands out at a glance repeats all over it and gives the heap away
## (the user, 2026-11-02: the long valve stem with its wheel). Still in the heap, under the face.
const FACE_SKIP := ["valve_wheel_scan"]
const BRASS := ["pirinc", "bakir"]
const BRASS_FREQ := 0.06    # the brass-and-copper share drifts over some 15 m of face
const BRASS_RANGE := Vector2(0.25, 2.5)  # times its plain weight, where the drift is lowest and highest

var _pile
var _to_world: Transform3D  # the heap's space to the hall's
var _space: PhysicsDirectSpaceState3D
var _rng := RandomNumberGenerator.new()
var _brass_noise := FastNoiseLite.new()
var _layer_parts := []  # per layer: {kind: [part, ...]}
var _layer_kind_foot := []  # per layer: {kind: mean footprint}
var _layer_kind_share := []  # per layer: {kind: its weight to be picked}
var _part_cost := {}  # part -> how much less often it is picked for its triangles
# Settled pieces: part, transform (heap space), body (an invalid RID once buried and let go).
var _part := PackedInt32Array()
var _xform: Array[Transform3D] = []
var _rid: Array[RID] = []
var _rid_piece := {}


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	# The hall as the game has it: the heap where it stands (its roof heights come from there), the
	# walls round it for the pieces to land against.
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.get_node("Player").free()
	_pile = main.get_node("Pile")
	_pile.with_pieces = false
	root.add_child(main)
	await process_frame  # the world is not there yet while _initialize runs
	_to_world = _pile.global_transform
	_space = _pile.get_world_3d().direct_space_state
	_rng.seed = 5
	_brass_noise.seed = 11
	_brass_noise.frequency = BRASS_FREQ
	_sort_parts()
	await physics_frame
	var chunks := []
	for cz in range(0, _pile.GRID_Z, CHUNK):
		for cx in range(0, _pile.GRID_X, CHUNK):
			if not _cells(cx, cz).is_empty():
				chunks.append(Vector2i(cx, cz))
	print("%d chunks to settle" % chunks.size())
	var done := 0
	for parity in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var batch := chunks.filter(func(c: Vector2i) -> bool: return (c.x / CHUNK) % 2 == parity.x and (c.y / CHUNK) % 2 == parity.y)
		for g in range(0, batch.size(), GROUP):
			var group := batch.slice(g, g + GROUP)
			await _settle(group)
			var bodies := _bury(group)
			if bodies > int(ProjectSettings.get_setting("physics/jolt_physics_3d/limits/max_bodies")) * 0.9:
				push_warning("%d bodies: near the physics server's limit, the next chunks may stay bare" % bodies)
			done += group.size()
			print("%d / %d chunks, %d pieces, %d bodies (%d s)" % [done, chunks.size(), _part.size(), bodies, (Time.get_ticks_msec() - t0) / 1000])
	# Slivers go before the gaps are filled: what they half hid is filled for real.
	var seen := _seen(Rect2i(0, 0, _pile.GRID_X, _pile.GRID_Z))
	var slivers := _drop(func(i: int) -> bool: return seen.get(i, 0) < MIN_HITS)
	await _fill()
	# Kept: what shows well, and whatever a ray straight in meets first (it is all that covers there).
	seen = _seen(Rect2i(0, 0, _pile.GRID_X, _pile.GRID_Z))
	var straight := _straight()
	slivers += _drop(func(i: int) -> bool: return seen.get(i, 0) < MIN_HITS and not straight.has(i))
	seen = _seen(Rect2i(0, 0, _pile.GRID_X, _pile.GRID_Z))
	print("%d slivers left out" % slivers)
	var out := []
	var hidden := []
	var kinds := {}
	for i in _part.size():
		if _xform[i].origin.y < -0.5:
			continue
		(out if seen.has(i) else hidden).append(_entry(i))
		if seen.has(i):
			var tur: String = _pile._part_info[_part[i]].tur
			kinds[tur] = kinds.get(tur, 0) + 1
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"heights": hash(_pile._h), "pieces": out, "hidden": hidden}))
	print("shown by kind: ", kinds)
	_holes()
	print("%d of %d pieces show, %d lie under them; saved %s (%d s)" % [out.size(), _part.size(), hidden.size(), ProjectSettings.globalize_path(OUT), (Time.get_ticks_msec() - t0) / 1000])
	quit()


## Piece `i` as the file has it: [id, x, lift, z, qx, qy, qz, qw].
func _entry(i: int) -> Array:
	var t: Transform3D = _xform[i]
	var q := t.basis.get_rotation_quaternion()
	return [_pile._part_info[_part[i]].id, snappedf(t.origin.x, 0.001), snappedf(t.origin.y - _pile._height_smooth(t.origin), 0.001),
		snappedf(t.origin.z, 0.001), snappedf(q.x, 0.0001), snappedf(q.y, 0.0001), snappedf(q.z, 0.0001), snappedf(q.w, 0.0001)]


## The face cells of the chunk at cell (cx, cz).
func _cells(cx: int, cz: int) -> Array:
	var list := []
	for j in range(cz, mini(cz + CHUNK, _pile.GRID_Z - 1)):
		for i in range(cx, mini(cx + CHUNK, _pile.GRID_X - 1)):
			if i >= 1 and j >= 1 and _pile._face_cell(j * _pile.GRID_X + i):
				list.append(Vector2i(i, j))
	return list


## The heap's parts sorted into the layers by size and kind.
func _sort_parts() -> void:
	for layer: Dictionary in LAYERS:
		var by_kind := {}
		var foot := {}
		for i in _pile._part_info.size():
			var info: Dictionary = _pile._part_info[i]
			var s: Vector3 = _pile._part_size[i]
			var longest := s[s.max_axis_index()]
			if longest < _pile.SURFACE_MIN or longest < layer.size.x or longest >= layer.size.y:
				continue
			if layer.kinds.get(info.tur, 1.0) <= 0.0 or info.id in FACE_SKIP:
				continue
			by_kind[info.tur] = by_kind.get(info.tur, []) + [i]
			foot[info.tur] = foot.get(info.tur, 0.0) + _pile._part_foot[i]
		var share := {}
		for kind: String in by_kind:
			foot[kind] /= by_kind[kind].size()
			share[kind] = layer.kinds.get(kind, 1.0) / foot[kind] * minf(1.0, by_kind[kind].size() / KIND_MODELS)
		_layer_parts.append(by_kind)
		_layer_kind_foot.append(foot)
		_layer_kind_share.append(share)
	for i in _pile._part_info.size():
		var m: Mesh = _pile._part_low[i]
		var tris := 0
		for s in m.get_surface_count():
			tris += m.surface_get_array_index_len(s) / 3
		_part_cost[i] = minf(1.0, TRIS_EASY / tris)


## A part for layer `l` at `at` (heap space): the kind by its share of the area, then a part of
## that kind, light ones more likely, brass and copper more or less as the mix drifts along the face.
func _pick(l: int, at: Vector3) -> int:
	var by_kind: Dictionary = _layer_parts[l]
	var shares: Dictionary = _layer_kind_share[l]
	var total := 0.0
	for k: String in by_kind:
		total += shares[k]
	var r := _rng.randf() * total
	var kind: String = by_kind.keys()[-1]
	for k: String in by_kind:
		r -= shares[k]
		if r <= 0.0:
			kind = k
			break
	var parts: Array = by_kind[kind]
	var brass := lerpf(BRASS_RANGE.x, BRASS_RANGE.y, clampf(_brass_noise.get_noise_2d(at.x, at.z) * 1.4 + 0.5, 0.0, 1.0))
	var weights := []
	var sum := 0.0
	for p: int in parts:
		var w: float = (brass if _pile._part_info[p].materyal in BRASS else 1.0) * _part_cost[p]
		weights.append(w)
		sum += w
	r = _rng.randf() * sum
	for i in parts.size():
		r -= weights[i]
		if r <= 0.0:
			return parts[i]
	return parts[-1]


## Lays each chunk in `group` layer by layer: drops a layer's pieces until they cover the chunk as
## the layer asks, lets them come to rest, and keeps them as solid static bodies for the next.
func _settle(group: Array) -> void:
	var jobs := []
	for c: Vector2i in group:
		var cells := _cells(c.x, c.y)
		var area := 0.0
		for cell: Vector2i in cells:
			area += _pile.CELL * _pile.CELL / maxf(_pile._cell_normal(cell).y, 0.25)
		jobs.append({"cells": cells, "area": area})
	for l in LAYERS.size():
		var bodies := []
		for job: Dictionary in jobs:
			job.want = job.area * LAYERS[l].cover
		var dropping := true
		while dropping:
			dropping = false
			for job: Dictionary in jobs:
				if job.want <= 0.0:
					continue
				dropping = true
				for k in BATCH:
					var cell: Vector2i = job.cells[_rng.randi() % job.cells.size()]
					var at: Vector3 = _pile._cell_pos(cell) + Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(-0.5, 0.5)) * _pile.CELL
					var part := _pick(l, at)
					job.want -= _pile._part_foot[part]
					at.y = _pile._height_smooth(at)
					# Each piece pulled onto the face where it lands, not along the chunk's mean:
					# where a chunk spans a ridge or a gully, one side would shed its pieces.
					var n := _normal_round(cell)
					# Born clear of everything: over the top of what has piled up there already.
					var probe := PhysicsRayQueryParameters3D.create(_to_world * (at + n * 4.0), _to_world * at)
					probe.collision_mask = 1 | LAYER
					var hit := _space.intersect_ray(probe)
					if not hit.is_empty():
						at = _to_world.affine_inverse() * hit.position
					var s: Vector3 = _pile._part_size[part]
					at += n * (s.length() * 0.5 + _rng.randf_range(0.05, 0.25))
					bodies.append(_body(part, _to_world * Transform3D(_lying(part, n, LAYERS[l].tilt), at), _to_world.basis * n))
					if job.want <= 0.0:
						break
			for f in DROP_FRAMES:
				await physics_frame
		for f in SETTLE_FRAMES:
			await physics_frame
			if f % 30 == 29 and bodies.all(func(b: RigidBody3D) -> bool: return b.sleeping or b.linear_velocity.length() < 0.03):
				break
		for body: RigidBody3D in bodies:
			_keep(body)


## The face's normal round `cell`, over a metre: the lumps of single cells smoothed out.
func _normal_round(cell: Vector2i) -> Vector3:
	var n := Vector3.ZERO
	for j in range(-2, 3):
		for i in range(-2, 3):
			var c := cell + Vector2i(i, j)
			if c.x >= 1 and c.y >= 1 and c.x < _pile.GRID_X - 1 and c.y < _pile.GRID_Z - 1:
				n += _pile._cell_normal(c)
	return n.normalized()


## `part` lying on its widest side on a face with normal `n`, tipped up to `tilt` rad and turned
## any way about the normal.
func _lying(part: int, n: Vector3, tilt: float) -> Basis:
	var s: Vector3 = _pile._part_size[part]
	var thin := s.min_axis_index()
	var lay := Basis()
	if thin == 0:
		lay = Basis(Vector3.BACK, PI * 0.5)
	elif thin == 2:
		lay = Basis(Vector3.RIGHT, PI * 0.5)
	var tip := Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf() * tilt)
	return Basis(Quaternion(Vector3.UP, n)) * tip * Basis(Vector3.UP, _rng.randf() * TAU) * lay


func _body(part: int, t: Transform3D, n: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = _pile._part_mass[part]
	body.gravity_scale = 0.0
	body.constant_force = -n * 9.8 * body.mass  # down onto the face, whatever its slope
	body.linear_damp = 0.3
	body.angular_damp = 0.8
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.9
	body.physics_material_override.bounce = 0.05
	body.collision_layer = LAYER
	body.collision_mask = 1 | LAYER
	var col := CollisionShape3D.new()
	col.shape = _pile._part_hull[part]
	col.transform = _pile._part_hull_at[part]
	body.add_child(col)
	body.set_meta("part", part)
	body.transform = t
	root.add_child(body)
	return body


## A piece at rest stays as a bare static body the next pieces land on.
func _keep(body: RigidBody3D) -> void:
	var part: int = body.get_meta("part")
	var t := Transform3D(body.global_transform.basis.orthonormalized(), body.global_transform.origin)
	body.queue_free()
	if (_to_world.affine_inverse() * t).origin.y < -0.5:
		return  # fell off the world (under the pit's bottom)
	var rid := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(rid, _pile._part_hull[part].get_rid(), _pile._part_hull_at[part])
	PhysicsServer3D.body_set_collision_layer(rid, LAYER)
	PhysicsServer3D.body_set_collision_mask(rid, 0)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	PhysicsServer3D.body_set_space(rid, _pile.get_world_3d().space)
	_rid_piece[rid] = _part.size()
	_part.append(part)
	_xform.append(_to_world.affine_inverse() * t)  # kept in the heap's space
	_rid.append(rid)


## Lets go of the bodies fewer than MIN_HITS rays from outside reach, in `group`'s chunks and the ones round them
## (their pieces spilled over the edges): more pieces only cover them further, so they never show,
## and what lands later lands on the ones that do. Returns the bodies left.
func _bury(group: Array) -> int:
	var areas := group.map(func(c: Vector2i) -> Rect2i: return Rect2i(c, Vector2i.ONE * CHUNK).grow(CHUNK))
	var seen := {}
	for area: Rect2i in areas:
		var more := _seen(area.grow(REACH))
		for i: int in more:
			seen[i] = maxi(seen.get(i, 0), more[i])
	for i in _part.size():
		if not _rid[i].is_valid() or seen.get(i, 0) >= MIN_HITS:
			continue
		var cell: Vector2i = _pile._cell_of(_xform[i].origin)
		if not areas.any(func(a: Rect2i) -> bool: return a.has_point(cell)):
			continue
		_rid_piece.erase(_rid[i])
		PhysicsServer3D.free_rid(_rid[i])
		_rid[i] = RID()
	return _rid_piece.size()


## Lets go of every live piece `out` says, returns how many.
func _drop(out: Callable) -> int:
	var n := 0
	for i in _part.size():
		if _rid[i].is_valid() and out.call(i):
			_rid_piece.erase(_rid[i])
			PhysicsServer3D.free_rid(_rid[i])
			_rid[i] = RID()
			n += 1
	return n


## The pieces met first by the rays that must not reach the heap's surface (_cover_rays).
func _straight() -> Dictionary:
	var out := {}
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = LAYER
	for j in range(1, _pile.GRID_Z - 1):
		for i in range(1, _pile.GRID_X - 1):
			if not _pile._face_cell(j * _pile.GRID_X + i):
				continue
			for r: Array in _cover_rays(Vector2i(i, j)):
				ray.from = _to_world * (r[0] + r[1] * 3.0)
				ray.to = _to_world * (r[0] - r[1] * 0.3)
				var hit := _space.intersect_ray(ray)
				if not hit.is_empty() and _rid_piece.has(hit.rid):
					out[_rid_piece[hit.rid]] = true
	return out


## Rays onto `cell` that must meet scrap before the heap's surface, as [point on it, direction
## out of it] (heap space): RAYS × RAYS straight in along the face's normal, and on the lower
## face as many more from low down in the hall, as a player looks at its foot.
func _cover_rays(cell: Vector2i) -> Array:
	var out := []
	var n := _normal_round(cell)
	var low := (_to_world.basis.inverse() * LOW_LOOK).normalized()
	for b in RAYS:
		for a in RAYS:
			var at: Vector3 = _pile._cell_pos(cell) + Vector3((a + 0.5) / RAYS - 0.5, 0.0, (b + 0.5) / RAYS - 0.5) * _pile.CELL
			at.y = _pile._height_smooth(at)
			out.append([at, n])
			if at.y < LOW_FACE and low.dot(n) > 0.3:
				out.append([at, low])
	return out


## The heap's own surface must not show anywhere, only scrap (2026-11-02, the user). Where a ray
## straight in still reaches it, a piece is dropped onto that very spot, a hand-sized one or a small
## one, and comes to rest in the gap; again, until no ray gets through or FILL_PASSES run out.
func _fill() -> void:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1 | LAYER
	for pass_no in FILL_PASSES:
		var spots := []
		for j in range(1, _pile.GRID_Z - 1):
			for i in range(1, _pile.GRID_X - 1):
				if not _pile._face_cell(j * _pile.GRID_X + i):
					continue
				var cell := Vector2i(i, j)
				for r: Array in _cover_rays(cell):
					ray.from = _to_world * (r[0] + r[1] * 3.0)
					ray.to = _to_world * (r[0] - r[1] * 0.3)
					var hit := _space.intersect_ray(ray)
					if not hit.is_empty() and (_rid_piece.has(hit.rid) or hit.position.distance_to(_to_world * r[0]) > 0.25):
						continue  # scrap there, or the heap itself in the way of a low look
					spots.append([r[0], r[1], _normal_round(cell)])
		print("fill %d: %d bare spots" % [pass_no, spots.size()])
		if spots.is_empty():
			return
		# One piece a spot: bigger ones first, the last rounds small ones for the last chinks.
		var l := 0 if pass_no < FILL_PASSES / 2 else 2
		for k in range(0, spots.size(), FILL_BATCH):
			var bodies := []
			for spot: Array in spots.slice(k, k + FILL_BATCH):
				var at: Vector3 = spot[0]
				var n: Vector3 = spot[2]
				var part := _pick(l, at)
				var s: Vector3 = _pile._part_size[part]
				at += spot[1] * (s.length() * 0.5 + 0.03)  # back along the ray: clear of everything
				bodies.append(_body(part, _to_world * Transform3D(_lying(part, n, LAYERS[l].tilt), at), _to_world.basis * n))
			for f in SETTLE_FRAMES:
				await physics_frame
				if f % 30 == 29 and bodies.all(func(b: RigidBody3D) -> bool: return b.sleeping or b.linear_velocity.length() < 0.03):
					break
			for body: RigidBody3D in bodies:
				_keep(body)


## How much of the face shows bare between the pieces: the share of straight-in rays that reach
## the heap's surface, overall and as a map (user://scrap_face_holes.png, a pixel a cell, white bare).
func _holes() -> void:
	var img := Image.create(_pile.GRID_X, _pile.GRID_Z, false, Image.FORMAT_L8)
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1 | LAYER
	var rays := 0
	var bare := 0
	for j in range(1, _pile.GRID_Z - 1):
		for i in range(1, _pile.GRID_X - 1):
			if not _pile._face_cell(j * _pile.GRID_X + i):
				continue
			var cell := Vector2i(i, j)
			var n: Vector3 = _pile._cell_normal(cell)
			var miss := 0
			for b in RAYS:
				for a in RAYS:
					var at: Vector3 = _pile._cell_pos(cell) + Vector3((a + 0.5) / RAYS - 0.5, 0.0, (b + 0.5) / RAYS - 0.5) * _pile.CELL
					at.y = _pile._height_smooth(at)
					ray.from = _to_world * (at + n * 3.0)
					ray.to = _to_world * (at - n * 0.3)
					var hit := _space.intersect_ray(ray)
					if hit.is_empty() or not _rid_piece.has(hit.rid):
						miss += 1
			rays += RAYS * RAYS
			bare += miss
			img.set_pixel(i, j, Color.from_hsv(0, 0, float(miss) / (RAYS * RAYS)))
	img.save_png("user://scrap_face_holes.png")
	print("bare face: %.1f%% of straight-in rays" % (100.0 * bare / rays))


## Pieces a ray from outside reaches over the cells in `area`, with how many rays reach each:
## RAYS × RAYS rays a cell, straight in along the face's normal and leaning four ways.
func _seen(area: Rect2i) -> Dictionary:
	var seen := {}
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = LAYER
	for j in range(maxi(area.position.y, 1), mini(area.end.y, _pile.GRID_Z - 1)):
		for i in range(maxi(area.position.x, 1), mini(area.end.x, _pile.GRID_X - 1)):
			if not _pile._face_cell(j * _pile.GRID_X + i):
				continue
			var cell := Vector2i(i, j)
			var n: Vector3 = _pile._cell_normal(cell)
			var side := n.cross(Vector3.FORWARD if absf(n.z) < 0.9 else Vector3.RIGHT).normalized()
			var up := n.cross(side)
			for b in RAYS:
				for a in RAYS:
					var at: Vector3 = _pile._cell_pos(cell) + Vector3((a + 0.5) / RAYS - 0.5, 0.0, (b + 0.5) / RAYS - 0.5) * _pile.CELL
					at.y = _pile._height_smooth(at)
					for lean: Vector3 in [Vector3.ZERO, side, -side, up, -up]:
						var dir := _to_world.basis * (n + lean * 0.6).normalized()
						ray.from = _to_world * at + dir * 2.0
						ray.to = _to_world * at - dir * 0.3
						var hit := _space.intersect_ray(ray)
						if not hit.is_empty() and _rid_piece.has(hit.rid):
							seen[_rid_piece[hit.rid]] = seen.get(_rid_piece[hit.rid], 0) + 1
	return seen
