extends SceneTree
## Headless check of the railing's bays (GameState.fence_bays, scripts/fence.gd, waves.gd, hud.gd),
## host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/fence_check.gd --quit-after 100000
## Alone: claws wear the bay they land on, the posts there lean and the rails bow; clawed through,
## the bay comes down and leaves a hole: its rails on the floor, its piece of the wall and its
## bullet stops gone, the neighbours' still there. No life bar on the HUD. The workshop bench mends,
## worst bay first, as far as the gold goes and only within reach (its row in the bench menu, the
## price on it); a mended hole shuts. A wave with a hole: the dead outside make for it, walk in,
## go for the player standing and claw them; everyone down (GameState.all_down), the wave is lost:
## the sign and the screen say so, then the same wave waits with the holes patched and nobody left.
## Online: a joiner gets the bays as they are, every claw reaches it bay by bay, its repair at the
## bench is paid from the vault on the host, a hole on the host is a hole there, the ones inside
## follow the host's, and a wave lost on the host is lost on the client at the same moment, patched
## the same.

const PORT := 24711
const LOG := "user://fence_check_client.log"
const SEEN := "user://fence_check_seen.json"
const TIME_SCALE := 4.0

var gs: Node
var net: Node
var main: Node
var waves: Node
var fence: Node3D
var hud: Control
var _log: Array[String] = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	waves = main.get_node("Waves")
	for i in 3:
		await physics_frame
	fence = waves._fence
	hud = main.get_node("Player")._hud
	gs.request_pick_character("worker" if "--client" in OS.get_cmdline_user_args() else "boss")  # the picker holds the hands
	if "--client" in OS.get_cmdline_user_args():
		await _client()
	else:
		await _host()


func _host() -> void:
	var me: Node3D = main.get_node("Player")
	if not _ok(gs.fence == gs.FENCE_MAX and gs.fence_bays.size() == gs.FENCE_BAYS and gs.fence_bays.all(func(hp: int) -> bool: return hp == gs.BAY_HP), "every bay starts whole"): return
	if not _ok(fence._posts.size() == gs.FENCE_BAYS + 1 and fence._halves.size() == gs.FENCE_BAYS, "the railing's posts and bays found (%d posts)" % fence._posts.size()): return
	if not _ok(fence._walls.size() == gs.FENCE_BAYS and fence._stops.size() == gs.FENCE_BAYS and fence._stops[0].size() == 2, "a piece of wall and two bullet stops per bay"): return
	if not _ok(not "_fence_row" in hud and not "_fence_bar" in hud, "no life bar for the railing on the HUD"): return
	# Claws on one bay: that bay alone wears, its posts lean back over our side.
	var bay_z := _bay_z(12)
	gs.hurt_fence(3, bay_z)
	gs.hurt_fence(2, bay_z)
	if not _ok(gs.fence_bays[12] == gs.BAY_HP - 5 and gs.fence == gs.FENCE_MAX - 5, "two claws took 5 off bay 12 (%s)" % [gs.fence_bays]): return
	await create_timer(1.0).timeout
	var post: MeshInstance3D = fence._posts[12]
	var tilt := post.transform.basis.y.x
	if not _ok(tilt < -0.1 and fence._posts[5].transform.basis.y.is_equal_approx(Vector3.UP), "its post leans back (%.2f), one far off stands" % tilt): return
	var mid: Vector3 = fence._halves[12][0][0].transform.origin
	if not _ok(mid.x < fence._x - 0.02, "its top rail bows in towards us"): return
	if not _ok(_blocked(12) and _shot_stops(12), "still a wall there, rounds still stop on its rails"): return
	# Clawed through: a hole. Nothing past what was left of it: the bay next door still stands.
	gs.hurt_fence(20, bay_z)
	if not _ok(gs.fence_bays[12] == 0 and gs.bay_open(12) and gs.fence_holes() == 1 and gs.fence == gs.FENCE_MAX - gs.BAY_HP, "bay 12 down, the claw took no more than it had"): return
	await create_timer(0.3).timeout
	if not _ok(fence._shown[12] == 1.0 and fence._walls[12].disabled and not fence._walls[11].disabled and not fence._walls[13].disabled, "its wall gone, the neighbours' there"): return
	if not _ok(not _blocked(12) and _blocked(11) and not _shot_stops(12) and _shot_stops(13), "a hole to walk through, rounds go through it"): return
	var ok := true
	for k in 2:
		var lying: Vector3 = fence._halves[12][k][1].transform.origin
		var stub: MeshInstance3D = fence._halves[12][k][0]
		var stub_end: Vector3 = stub.transform * Vector3(0, 0, 0.5)
		var near_post := minf(absf(stub_end.z - fence._posts[12].position.z), absf(stub_end.z - fence._posts[13].position.z))
		ok = ok and lying.y < 0.1 and lying.x < fence._x - 0.5 and near_post < 0.6
	if not _ok(ok, "both rails snapped: a stub at a post, the rest on our floor"): return
	var lean_out: float = fence._posts[12].transform.basis.y.z
	if not _ok(lean_out < -0.05 and fence._posts[13].transform.basis.y.z > 0.05, "the posts either side lean away from the hole"): return
	# The bench: out of reach nothing, then as far as the gold goes, worst bay first.
	gs.hurt_fence(5, _bay_z(4))
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	gs.player().gold = 1000
	if not _ok(gs.request_repair_fence() == 0 and gs.fence_bays[12] == 0, "no mending from across the hall"): return
	me.global_position = gs.REPAIR_POS + Vector3(0, 0, -0.9)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	gs.player().gold = 30
	var got: int = gs.request_repair_fence()
	if not _ok(got == 10 and gs.fence_bays[12] == 10 and gs.fence_bays[4] == gs.BAY_HP - 5 and gs.gold == 0, "$30 mends 10 points, all on the hole (%d, %s, $%d)" % [got, gs.fence_bays, gs.gold]): return
	await create_timer(0.3).timeout
	if not _ok(not gs.bay_open(12) and not fence._walls[12].disabled and _blocked(12), "the hole is shut"): return
	gs.player().gold = 9
	gs.request_repair_fence()
	if not _ok(gs.fence_bays[4] == 10 and gs.fence_bays[12] == 10, "then the worst bay now, 4 (%s)" % [gs.fence_bays]): return
	# At the workshop bench (2026-10-31, the user's call: not the desk): its row says the price,
	# a press mends it all.
	gs.request_take_pistol()  # the warmup opens the bench
	gs.player().gold = 1000
	var price: int = gs.fence_repair_price()
	var bench: Node = me._bench
	if not _ok(bench.can_open(), "the bench opens from in front of it"): return
	bench.open()
	await process_frame
	var row: Button = bench._repair
	if not _ok(not row.disabled and row.text.ends_with("$%d" % price), "the bench's row: \"%s\"" % row.text.strip_edges()): return
	row.pressed.emit()
	if not _ok(gs.fence == gs.FENCE_MAX and gs.gold == 1000 - price, "it mends it all for $%d" % price): return
	await process_frame
	if not _ok(row.disabled and gs.request_repair_fence() == 0, "whole: \"%s\", nothing to pay" % row.text.strip_edges()): return
	bench.close()
	await create_timer(2.5).timeout  # gun_table.gd FADE_DELAY + FADE
	if not _ok(not is_instance_valid(get_first_node_in_group("gun_table")), "the desk at the spawns is gone once its pistol is"): return
	await create_timer(1.5).timeout
	if not _ok(fence._posts[12].transform.basis.y.is_equal_approx(Vector3.UP) and fence._shown[12] == 0.0, "the bay stands straight again"): return
	# A wave with a hole in bay 10: the dead make for it, come in and claw at us.
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	Engine.time_scale = TIME_SCALE
	gs.hurt_fence(gs.BAY_HP, _bay_z(10))
	var swings := []
	gs.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"swing":
			var z: Dictionary = waves._zombies.get(cue[1], {})
			if not z.is_empty():
				swings.append((z.node as Node3D).global_position.distance_to(me.global_position * Vector3(1, 0, 1))))
	gs.request_pull_lever()
	me.global_position = Vector3(9.0, 0.1, -12.0)  # open floor, a way in from the hole
	me.reset_physics_interpolation()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT, "the fight"): return
	if not await _until(func() -> bool: return waves._zombies.values().any(func(z: Dictionary) -> bool: return z.moving and z.hole == 10), "one to make for the hole"): return
	if not _ok(waves._status.text.contains("DELİK 1"), "the sign counts the hole: \"%s\"" % waves._status.text): return
	if not await _until(func() -> bool: return waves._zombies.values().any(func(z: Dictionary) -> bool: return z.inside), "one to come in", 60.0): return
	var inside: Dictionary = waves._zombies.values().filter(func(z: Dictionary) -> bool: return z.inside)[0]
	if not _ok(absf((inside.node as Node3D).global_position.z - _bay_z(10)) < 1.4, "it came in through the hole"): return
	if not await _until(func() -> bool: return swings.size() > 0, "a claw at us", 60.0): return
	if not _ok(swings[0] <= waves.REACH + 0.3 and inside.prey == gs.local_peer(), "it clawed from within reach (%.2f m), at us" % swings[0]): return
	var crossing: bool = waves._zombies.values().all(func(z: Dictionary) -> bool:
		var p: Vector3 = (z.node as Node3D).global_position
		return z.dead or p.x <= waves.GAP[0] + 0.01 or p.x >= waves.GAP[1] - 0.01 or absf(p.z - _bay_z(10)) < 1.4)
	if not _ok(crossing, "nobody stands in the railing but in the hole"): return
	gs.all_down.emit()
	if not _ok(waves.phase == waves.Phase.FAILED and waves._status.text == "HERKES DÜŞTÜ" and hud._lost.visible, "everyone down: lost, the sign and the screen say so"): return
	await create_timer(0.3).timeout
	var back: Array = waves._zombies.values().filter(func(z: Dictionary) -> bool: return not z.dead and not z.path.is_empty() and z.path[-1] == z.mouth)
	if not _ok(back.size() > 0 and not waves._zombies.values().any(func(z: Dictionary) -> bool: return z.inside), "the dead turn back for the pens, the ones inside too (%d)" % back.size()): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY, "the lost wave to wait again"): return
	await process_frame
	if not _ok(waves.wave == 1 and gs.fence_holes() == 0 and gs.fence_bays[10] == gs.BAY_PATCH and waves._zombies.is_empty(), "wave 1 again, the hole patched up to %d, nobody left" % gs.fence_bays[10]): return
	if not await _until(func() -> bool: return not hud._lost.visible, "the screen to clear"): return
	Engine.time_scale = 1.0
	gs.mend_fence(gs.FENCE_MAX)
	print("fence_check solo OK")
	await _online()


func _online() -> void:
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	gs.hurt_fence(7, _bay_z(3))  # before the client: it must get this on joining
	gs.hurt_fence(4, _bay_z(17))
	gs.vault = 1000.0
	var failed_at := [0.0]
	gs.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"phase" and cue[2] == waves.Phase.FAILED:
			failed_at[0] = Time.get_unix_time_from_system())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEEN))
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "-s", "res://tools/fence_check.gd", "--", "--client"])
	if not await _until(func() -> bool: return gs.multiplayer.get_peers().size() == 1, "the client", 60.0): return
	# Claws while it's here, then it mends the railing at the bench.
	await create_timer(1.5).timeout
	for i in 5:
		gs.hurt_fence(1, _bay_z(9))
		await create_timer(0.05).timeout
	if not await _until(func() -> bool: return gs.fence == gs.FENCE_MAX, "the client's repair", 30.0): return
	if not _ok(is_equal_approx(gs.vault, 1000.0 - 16 * gs.FENCE_REPAIR_COST), "paid from the vault ($%d left)" % gs.vault): return
	# A hole here is a hole there; a wave through it, lost here, is lost there.
	await create_timer(0.5).timeout
	gs.hurt_fence(gs.BAY_HP, _bay_z(9))
	var me: Node3D = main.get_node("Player")
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	gs.request_pull_lever()
	me.global_position = Vector3(9.0, 0.1, -12.0)
	me.reset_physics_interpolation()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT, "the fight"): return
	if not await _until(func() -> bool: return waves._zombies.values().filter(func(z: Dictionary) -> bool: return z.inside).size() >= 2, "two to come in", 90.0): return
	await create_timer(3.0).timeout  # the client sees them in and follows them a while
	gs.all_down.emit()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY and gs.fence_holes() == 0, "the lost wave to wait again"): return
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() - t0 > 120_000:
			OS.kill(pid)
			print(FileAccess.get_file_as_string(LOG))  # its last line is the last check it passed
			return _fail("client timed out")
		await process_frame
	print(FileAccess.get_file_as_string(LOG))
	if OS.get_process_exit_code(pid) != 0:
		return _fail("client side failed")
	var seen = JSON.parse_string(FileAccess.get_file_as_string(SEEN))
	if not _ok(seen is Dictionary and absf(seen.failed_at - failed_at[0]) < 0.5, "the client lost it at the same moment (%.2f s apart)" % absf(seen.get("failed_at", 0.0) - failed_at[0])): return
	var theirs: Array = (seen.bays as Array).map(func(w: float) -> int: return int(w))  # JSON reads numbers as floats
	if not _ok(theirs == Array(gs.fence_bays), "the same railing on both machines (%s)" % [seen.bays]): return
	print("fence_check OK")
	quit()


func _client() -> void:
	var me: Node3D = main.get_node("Player")
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client and gs.fence == gs.FENCE_MAX - 11, "the host's railing on joining"): return
	if not _ok(gs.fence_bays[3] == gs.BAY_HP - 7 and gs.fence_bays[17] == gs.BAY_HP - 4, "worn where the host's was (%s)" % [gs.fence_bays]): return
	await create_timer(0.5).timeout
	if not _ok(fence._shown[3] > 0.5 and fence._shown[9] == 0.0, "shown worn here too"): return
	if not await _until(func() -> bool: return gs.fence == gs.FENCE_MAX - 16 and gs.fence_bays[9] == gs.BAY_HP - 5, "the claws on bay 9"): return
	me.global_position = gs.REPAIR_POS + Vector3(0, 0, -0.9)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout  # our pose reaches the host
	if not _ok(gs.request_repair_fence() == 16, "we ask to mend 16 points"): return
	if not await _until(func() -> bool: return gs.fence == gs.FENCE_MAX and is_equal_approx(gs.vault, 1000.0 - 16 * gs.FENCE_REPAIR_COST), "the host's mend"): return
	if not await _until(func() -> bool: return gs.bay_open(9), "the host's hole in bay 9"): return
	await create_timer(0.2).timeout
	if not _ok(fence._walls[9].disabled and fence._shown[9] == 1.0, "a hole here too"): return
	var seen := {}
	gs.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"phase" and cue[2] == waves.Phase.FAILED:
			seen.failed_at = Time.get_unix_time_from_system())
	if not await _until(func() -> bool: return waves._zombies.values().any(func(z: Dictionary) -> bool: return z.inside and z.seen != Vector3.INF), "one inside, the host's to follow", 90.0): return
	await create_timer(1.0).timeout
	var off := 0.0
	for z: Dictionary in waves._zombies.values():
		if z.inside and not z.dead and z.seen != Vector3.INF:
			off = maxf(off, (z.node as Node3D).global_position.distance_to(z.seen))
	if not _ok(off < 1.0, "the ones inside go where the host has them (%.2f m off at most)" % off): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FAILED, "the host's wave to be lost", 60.0): return
	if not _ok(hud._lost.visible and waves._status.text == "HERKES DÜŞTÜ", "lost here too: the sign and the screen"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY, "the same wave to wait again"): return
	await process_frame
	if not _ok(waves.wave == 1 and gs.fence_holes() == 0 and waves._zombies.is_empty(), "wave 1 again, patched, nobody left"): return
	seen.bays = gs.fence_bays
	var f := FileAccess.open(SEEN, FileAccess.WRITE)
	f.store_string(JSON.stringify(seen))
	f.close()
	_log.append("fence_check client OK")
	_write_log()
	quit()


## A body walking along x through the middle of bay `b` meets the railing's wall.
func _blocked(b: int) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(16.0, 1.0, _bay_z(b)), Vector3(12.0, 1.0, _bay_z(b)), 1 << (gs.FENCE_LAYER - 1))
	return not main.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A round through bay `b` at its top rail's height stops on the rail.
func _shot_stops(b: int) -> bool:
	var y: float = fence._heights[0]
	var q := PhysicsRayQueryParameters3D.create(Vector3(12.0, y, _bay_z(b)), Vector3(16.0, y, _bay_z(b)), 1 << (gs.RAIL_LAYER - 1))
	return not main.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## The middle of bay `b` along the railing.
func _bay_z(b: int) -> float:
	return gs.bay_mid(b)


func _until(cond: Callable, what: String, secs := 60.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			_fail("waited for " + what)
			return false
		await process_frame
	return true


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fail(what)
	else:
		print("ok   ", what)
		_log.append("ok: " + what)
		_write_log()  # a script error stops the client without quitting: the host shows how far it got
	return cond


func _fail(what: String) -> void:
	_log.append("fence_check FAIL: " + what)
	printerr("fence_check FAIL: ", what)
	_write_log()
	quit(1)


func _write_log() -> void:
	if "--client" in OS.get_cmdline_user_args():
		var f := FileAccess.open(LOG, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_log))
