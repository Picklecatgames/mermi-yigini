extends SceneTree
## Settles the scrap heap's face for real: builds the heap's shape (scripts/pile.gd, no pieces),
## then over it, CHUNK metres at a time, drops real pieces and lets them come to rest. Gravity
## pulls each chunk's pieces onto the face along its normal, so they lie on a 61° face as on the
## floor; pieces settled in chunks before are solid, so nothing ends up inside anything else.
## Chunks two apart settle at once. Then rays from outside find the pieces that show; only those
## are written, to data/scrap_face.json:
##   {"heights": hash of the heap's starting heights, "pieces": [[id, x, lift, z, qx, qy, qz, qw], ...]}
## x, z in the heap's own space, lift over its surface there, at each piece's box centre.
##   Godot.exe --headless --path . --fixed-fps 60 -s res://tools/build_scrap_face.gd

const CHUNK := 8          # cells (2 m) a chunk
const LAYERS := 6.0       # a chunk's true area covered this many times over by footprints: no gap down to the surface
const BATCH := 70         # pieces per drop into a chunk
const DROP_FRAMES := 25
const SETTLE_FRAMES := 240
const GROUP := 10         # chunks settling at once
const LAYER := 1 << 6     # physics layer of the settling pieces
const RAYS := 4           # per cell side
const OUT := "res://data/scrap_face.json"

var _pile
var _to_world: Transform3D  # the heap's space to the hall's
var _space: PhysicsDirectSpaceState3D
var _rng := RandomNumberGenerator.new()
var _zone_noise := FastNoiseLite.new()
var _zone_parts := {}
# Settled pieces: part, transform (heap space), static body.
var _part := PackedInt32Array()
var _xform: Array[Transform3D] = []
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
	_zone_noise.seed = 11
	_zone_noise.frequency = _pile.ZONE_FREQ
	for zone: String in _pile.ZONES:
		_zone_parts[zone] = _parts(zone)
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
			await _settle(batch.slice(g, g + GROUP))
			done += mini(GROUP, batch.size() - g)
			print("%d / %d chunks, %d pieces (%d s)" % [done, chunks.size(), _part.size(), (Time.get_ticks_msec() - t0) / 1000])
	var seen := _seen()
	var out := []
	for i: int in seen:
		var t: Transform3D = _xform[i]
		var q := t.basis.get_rotation_quaternion()
		out.append([_pile._part_info[_part[i]].id, snappedf(t.origin.x, 0.001), snappedf(t.origin.y - _pile._height_smooth(t.origin), 0.001),
			snappedf(t.origin.z, 0.001), snappedf(q.x, 0.0001), snappedf(q.y, 0.0001), snappedf(q.z, 0.0001), snappedf(q.w, 0.0001)])
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"heights": hash(_pile._h), "pieces": out}))
	print("%d of %d pieces show; saved %s (%d s)" % [out.size(), _part.size(), ProjectSettings.globalize_path(OUT), (Time.get_ticks_msec() - t0) / 1000])
	quit()


## The face cells of the chunk at cell (cx, cz).
func _cells(cx: int, cz: int) -> Array:
	var list := []
	for j in range(cz, mini(cz + CHUNK, _pile.GRID_Z - 1)):
		for i in range(cx, mini(cx + CHUNK, _pile.GRID_X - 1)):
			if i >= 1 and j >= 1 and _pile._face_cell(j * _pile.GRID_X + i):
				list.append(Vector2i(i, j))
	return list


## The parts zone `zone` lays, with their weights in the heap.
func _parts(zone: String) -> Array:
	var mats: Array = _pile.ZONES[zone].mats
	var kinds: Array = _pile.ZONES[zone].kinds
	var list := []
	for i in _pile._part_info.size():
		var s: Vector3 = _pile._part_size[i]
		if s[s.max_axis_index()] < _pile.SURFACE_MIN:
			continue
		if not mats.is_empty() and not mats.has(_pile._part_info[i].materyal):
			continue
		if not kinds.is_empty() and not kinds.has(_pile._part_info[i].tur):
			continue
		list.append([i, _pile._part_pick[i] - (_pile._part_pick[i - 1] if i > 0 else 0.0)])
	return list


func _pick(zone: String) -> int:
	var parts: Array = _zone_parts[zone]
	var total := 0.0
	for p: Array in parts:
		total += p[1]
	var r := _rng.randf() * total
	for p: Array in parts:
		r -= p[1]
		if r <= 0.0:
			return p[0]
	return parts[-1][0]


## Drops pieces onto each chunk in `group` until its face is covered LAYERS deep, lets them come
## to rest, and keeps them as solid static bodies.
func _settle(group: Array) -> void:
	var jobs := []
	for c: Vector2i in group:
		var cells := _cells(c.x, c.y)
		var n := Vector3.ZERO
		var area := 0.0
		for cell: Vector2i in cells:
			var cn: Vector3 = _pile._cell_normal(cell)
			n += cn
			area += _pile.CELL * _pile.CELL / maxf(cn.y, 0.25)
		var mid: Vector3 = _pile._cell_pos(c + Vector2i.ONE * (CHUNK / 2))
		var v := _zone_noise.get_noise_2d(mid.x, mid.z)
		var zone: String = "celik" if v < _pile.ZONE_CUT.x else ("sari" if v > _pile.ZONE_CUT.y else "karisik")
		jobs.append({"cells": cells, "n": n.normalized(), "want": area * LAYERS, "zone": zone, "bodies": []})
	var dropping := true
	while dropping:
		dropping = false
		for job: Dictionary in jobs:
			if job.want <= 0.0:
				continue
			dropping = true
			for k in BATCH:
				var part := _pick(job.zone)
				job.want -= _pile._part_foot[part]
				var cell: Vector2i = job.cells[_rng.randi() % job.cells.size()]
				var at: Vector3 = _pile._cell_pos(cell) + Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(-0.5, 0.5)) * _pile.CELL
				at.y = _pile._height_smooth(at)
				# Born clear of everything: over the top of what has piled up there already.
				var probe := PhysicsRayQueryParameters3D.create(_to_world * (at + job.n * 4.0), _to_world * at)
				probe.collision_mask = 1 | LAYER
				var hit := _space.intersect_ray(probe)
				if not hit.is_empty():
					at = _to_world.affine_inverse() * hit.position
				at += job.n * (_pile._part_size[part].length() * 0.5 + _rng.randf_range(0.15, 0.6))
				job.bodies.append(_body(part, _to_world * Transform3D(Basis(Quaternion.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))), at), _to_world.basis * job.n))
		for f in DROP_FRAMES:
			await physics_frame
	for f in SETTLE_FRAMES:
		await physics_frame
		if f % 30 == 29 and jobs.all(func(job: Dictionary) -> bool: return job.bodies.all(func(b: RigidBody3D) -> bool: return b.sleeping or b.linear_velocity.length() < 0.03)):
			break
	for job: Dictionary in jobs:
		for body: RigidBody3D in job.bodies:
			_keep(body)


func _body(part: int, t: Transform3D, n: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = _pile._part_mass[part]
	body.gravity_scale = 0.0
	body.constant_force = -n * 9.8 * body.mass  # down onto the face, whatever its slope
	body.linear_damp = 0.3
	body.angular_damp = 0.6
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


## A piece at rest stays as a bare static body the next chunks' pieces land on.
func _keep(body: RigidBody3D) -> void:
	var part: int = body.get_meta("part")
	var t := Transform3D(body.global_transform.basis.orthonormalized(), body.global_transform.origin)
	body.queue_free()
	if t.origin.y < -0.5:
		return  # fell off the world
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


## Pieces a ray from outside reaches: RAYS × RAYS rays a cell, straight in along the face's
## normal and leaning four ways.
func _seen() -> Dictionary:
	var seen := {}
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = LAYER
	for j in range(1, _pile.GRID_Z - 1):
		for i in range(1, _pile.GRID_X - 1):
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
							seen[_rid_piece[hit.rid]] = true
	return seen
