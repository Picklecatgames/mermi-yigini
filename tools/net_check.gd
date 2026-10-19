extends SceneTree
## Headless co-op check, host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/net_check.gd
## This process hosts and starts the client itself (same script with `-- --client`). The client
## grabs, reloads and fires at the dummy; both sides check they agree on what happened.

const PORT := 24691  # not Net.PORT, so a game left running doesn't get in the way
const LOG := "user://net_check_client.log"

var gs: Node
var net: Node
var main: Node
var _log: Array[String] = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	for i in 3:
		await physics_frame
	if "--client" in OS.get_cmdline_user_args():
		await _client()
	else:
		await _host()


func _host() -> void:
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	# Taken before anyone joins: the client will reach for the same bullet and must lose it.
	if gs.request_pick_up_loose(0) != 1:
		return _fail("host takes loose bullet 0")
	var client_id := [0]
	gs.multiplayer.peer_connected.connect(func(id: int) -> void: client_id[0] = id)
	var shots := []
	gs.shot_landed.connect(func(peer: int, _at: Vector3, _n: Vector3, _d: Vector3, t: Node, gold: int, _w: bool, _c: int) -> void:
		shots.append([peer, t, gold]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "-s", "res://tools/net_check.gd", "--", "--client"])
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() - t0 > 120_000:
			OS.kill(pid)
			return _fail("client timed out")
		await process_frame
	var code := OS.get_process_exit_code(pid)
	print(FileAccess.get_file_as_string(LOG))
	if code != 0:
		return _fail("client side failed (exit %d)" % code)
	var cid: int = client_id[0]
	if not _ok(cid != 0, "client connected"): return
	if not _ok(gs.pile == gs.PILE_START - 2, "host pile: its loose bullet + the client's grab"): return
	if not _ok(shots.size() == 1 and shots[0][0] == cid, "host traced one shot, the client's"): return
	if not _ok(shots[0][1] == main.get_node("Dummy") and shots[0][2] == 1, "it hit the dummy for $1"): return
	var p = gs.player(cid)
	if not _ok(p.gold == 1 and p.loaded == 0 and p.carried == 0, "host keeps the client's state"): return
	if not _ok(gs.player().carried == 1, "the host's own hand is untouched"): return
	print("net_check OK")
	quit()


func _client() -> void:
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client, "connect"): return
	if not await _until(func() -> bool: return gs.pile == gs.PILE_START - 1, "pile count on join"): return
	# A loose bullet the host already has: the grab is predicted, then the host takes it back.
	if not _ok(gs.request_pick_up_loose(0) == 1 and gs.carried == 1, "loose grab predicted"): return
	if not _ok(gs.request_pick_up_loose(0) == 0, "holding E asks only once"): return
	if not await _until(gs.synced, "answer to the loose grab"): return
	if not _ok(gs.carried == 0, "host said no: the bullet is taken back"): return
	# From the heap.
	if not _ok(gs.request_pick_up(Vector3(0, 1, 0), 1) == 1, "heap grab predicted"): return
	if not await _until(gs.synced, "answer to the heap grab"): return
	if not _ok(gs.carried == 1 and gs.pile == gs.PILE_START - 2, "host agrees: in hand, pile down"): return
	if not _ok(gs.request_reload() == 1, "reload"): return
	if not await _until(gs.synced, "answer to the reload"): return
	if not _ok(gs.loaded == 1 and gs.carried == 0, "round in the gun"): return
	# One shot at the dummy's body. The client traces the same ray itself to compare.
	var dummy: Node3D = main.get_node("Dummy")
	var from := dummy.global_position + Vector3(-11, 1.1, 0)
	var dir := Vector3(1, 0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * gs.SHOT_RANGE, gs.SHOT_MASK)
	var mine: Dictionary = root.world_3d.direct_space_state.intersect_ray(q)
	if not _ok(not mine.is_empty() and mine.collider == dummy, "local trace hits the dummy"): return
	var shots := []
	gs.shot_landed.connect(func(peer: int, at: Vector3, _n: Vector3, _d: Vector3, t: Node, gold: int, _w: bool, combo: int) -> void:
		shots.append([peer, at, t, gold, combo]))
	if not _ok(gs.request_fire(from, dir) and gs.loaded == 0, "shot predicted, round gone"): return
	if not await _until(func() -> bool: return gs.synced() and shots.size() == 1, "the shot's result"): return
	var s: Array = shots[0]
	_log.append("client saw: peer %d at %v target %s gold %d combo %d" % [s[0], s[1], s[2], s[3], s[4]])
	if not _ok(s[0] == gs.local_peer(), "the event names us as the shooter"): return
	if not _ok(s[1].distance_to(mine.position) < 0.001 and s[2] == dummy, "host's hit = our own trace"): return
	if not _ok(s[3] == 1 and s[4] == 1 and gs.gold == 1, "$1 paid, and it reached us"): return
	gs.player().cooldown = 0.0
	if not _ok(not gs.request_fire(from, dir), "empty gun stays quiet"): return
	_log.append("client OK")
	_write_log()
	quit()


func _until(cond: Callable, what: String, secs := 30.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			_fail("timed out waiting for " + what)
			return false
		await process_frame
	return true


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fail(what)
	return cond


func _fail(what: String) -> void:
	_log.append("net_check FAIL: " + what)
	printerr("net_check FAIL: ", what)
	_write_log()
	quit(1)


func _write_log() -> void:
	if "--client" in OS.get_cmdline_user_args():
		var f := FileAccess.open(LOG, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_log))
