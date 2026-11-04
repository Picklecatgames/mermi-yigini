extends SceneTree
## What a pull from low down sets moving on the game's own heap (scripts/pile.gd): it takes a piece at the
## foot with a piece resting on it, follows what moves link by link, how long the physics takes, and
## shoots frames of it.
##   Godot.exe --path . --fixed-fps 60 --position -10000,-10000 --resolution 1280x720 -s res://tools/heap_pull_probe.gd [-- --hour=23 --pulls=5 --psx=2]
## Headless it measures the physics only and passes or fails on it: --headless ... (no shots)
## Frames: user://pull_<n>_<frame>.png

const FRAMES := [0, 8, 20, 40, 70, 110, 170, 260]
const BUDGET_MS := 8.0   # physics time a frame may take at worst while a pull runs (my guess at a share of 16.6)

var _gs: Node
var _pile: Node
var _cam: Camera3D
var _main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_gs = root.get_node("GameState")
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_main.get_node("Player").free()
	root.add_child(_main)
	_cam = Camera3D.new()
	_main.add_child(_cam)
	_cam.make_current()
	_pile = root.get_tree().get_first_node_in_group("bullet_pile")
	var pulls := 3
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--pulls="):
			pulls = a.trim_prefix("--pulls=").to_int()
		elif a.begins_with("--psx="):
			await process_frame
			var settings: Node = root.get_node("Settings")
			settings.save_path = "user://settings_shots.cfg"
			settings.set_value("psx", a.trim_prefix("--psx=").to_int())
		elif a.begins_with("--hour="):
			await process_frame
			_gs.hour_rate = 0.0
			_gs.hour = a.trim_prefix("--hour=").to_float()
	for f in 30:
		await physics_frame
	print("shown %d, buried %d, bodies still %d" % [_pile._slot_part.size(), _pile._hid_part.size(), _pile._rid_slot.size()])
	var over := false
	for n in pulls:
		over = (await _pull(n)) or over
	print("heap_pull_probe: ", "OVER BUDGET" if over else "within budget")
	quit(1 if over else 0)


## The lowest piece near the middle of the face's near side that has one resting on it.
func _low_piece(n: int) -> int:
	var best := -1
	var best_y := INF
	var q := PhysicsShapeQueryParameters3D.new()
	q.collision_mask = _pile.SCRAP_LAYER
	q.margin = _pile.WAKE_MARGIN
	var want: Vector3 = _pile.to_local(Vector3(-17.0, 0.0, -14.0 + (n % 3) * 14.0))
	for s in _pile._slot_part.size():
		if _pile._slot_id[s] < 0 or not _pile._slot_rid[s].is_valid():
			continue
		var t: Transform3D = _pile._slot_at(s)
		if Vector2(t.origin.x - want.x, t.origin.z - want.z).length() > 4.0 or t.origin.y < 0.5 or t.origin.y > best_y or _pile._cell_normal(_pile._cell_of(t.origin)).y > 0.9:
			continue
		q.shape = _pile._part_hull[_pile._slot_part[s]]
		q.transform = _pile.global_transform * t * _pile._part_hull_at[_pile._slot_part[s]]
		for h in _pile.get_world_3d().direct_space_state.intersect_shape(q, 16):
			if _pile._rid_slot.has(h.rid) and _pile._slot_at(_pile._rid_slot[h.rid]).origin.y > t.origin.y + 0.05:
				best = s
				best_y = t.origin.y
				break
	return best


func _pull(n: int) -> bool:
	var s := _low_piece(n)
	if s < 0:
		print("pull %d: no piece found" % n)
		return false
	var at: Vector3 = _pile.global_transform * _pile._slot_at(s).origin
	# From out of the face, a player's distance off, up over whatever is round it.
	var cell: Vector2i = _pile._cell_of(_pile._slot_at(s).origin)
	var out: Vector3 = _pile._cell_normal(cell)
	out = (Vector3(out.x, 0.0, out.z).normalized() + Vector3(0.0, 0.5, 0.0)).normalized()
	_cam.look_at_from_position(at + out * 3.2 + Vector3.UP * 0.6, at + Vector3.UP * 0.25)
	var windowed: bool = DisplayServer.get_name() != "headless"
	if windowed:
		for f in 40:
			await process_frame
	var was := {}
	for o in _pile._slot_part.size():
		if _pile._slot_id[o] >= 0:
			was[_pile._slot_id[o]] = _pile._slot_at(o).origin
	var size: Vector3 = _pile._part_size[_pile._slot_part[s]]
	print("pull %d: %s, %.2f m long, at %v" % [n, _pile._part_info[_pile._slot_part[s]].id, size[size.max_axis_index()], at])
	var id: int = _pile._slot_id[s]
	_gs.player().carried = 0
	if windowed:
		await _shot(n, 0)
	var got: int = _gs.request_pick_up_loose(id)
	var peak := 0
	var phys_worst := 0.0
	var phys_sum := 0.0
	var frames := 0
	var last_awake := 0
	var ever := {}
	var spikes := []
	var woken_at := {}  # frame -> how many were moving
	var clock := Time.get_ticks_usec()
	for f in 900:
		await physics_frame
		# The wall clock between physics frames: Performance's monitor only moves once a second. Headless
		# nothing draws, so this is the scripts and the physics. With a window it has the drawing in it too.
		var ms: float = (Time.get_ticks_usec() - clock) / 1000.0
		clock = Time.get_ticks_usec()
		var active := 0
		for b: RigidBody3D in _pile._debris:
			if b.has_meta("start"):
				active += 1
				ever[b.get_meta("id")] = true
		peak = maxi(peak, active)
		if active > 0 or not _pile._wake_queue.is_empty():
			last_awake = f
			phys_worst = maxf(phys_worst, ms)
			if ms > BUDGET_MS:
				spikes.append("f%d %.0f ms" % [f, ms])
			phys_sum += ms
			frames += 1
		if f % 30 == 0:
			woken_at[f] = ever.size()
		if windowed and f + 1 in FRAMES:
			await _shot(n, f + 1)
			clock = Time.get_ticks_usec()
		if f > last_awake + 90:
			break
	var moved := 0
	var far := 0
	var high := -INF
	for o in was:
		var now: Variant = null
		if _pile._id_index.has(o):
			now = (_pile._id_index[o][3] as Transform3D).origin
		if now != null:
			var d: float = (now as Vector3).distance_to(was[o])
			if d > 0.03:
				moved += 1
				high = maxf(high, was[o].y)
			if d > 0.3:
				far += 1
	print("  took %d; woken %d, moved>3cm %d, >30cm %d, highest mover started %.2f m over the take; still moving until %.1f s; at once %d; physics worst %.1f ms, mean %.1f ms; by 0.5 s steps %s" % [
		got, ever.size(), moved, far, high - _pile.to_local(at).y, last_awake / 60.0, peak, phys_worst, phys_sum / maxi(frames, 1), str(woken_at.values())])
	print("  spikes: ", spikes)
	return phys_worst > BUDGET_MS


func _shot(n: int, f: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://pull_%d_%03d.png" % [n, f])
