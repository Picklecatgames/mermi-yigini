extends SceneTree
## Headless co-op check, host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/net_check.gd
## This process hosts and starts the client itself (same script with `-- --client`). The client
## grabs, reloads and fires at the dummy; both sides check they agree on what happened. Also:
## each side gets its own spawn point, sees the other as a third-person character that follows
## its pose, and the host drops a shot whose `from` is nowhere near the shooter.

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
	var rp: Node = main.get_node("RemotePlayers")
	# The dummy connected first, so by now it has reacted; a "+$" over it would be on show.
	var labels: Array = main.get_node("Dummy")._pops._labels
	gs.shot_landed.connect(func(peer: int, _at: Vector3, _n: Vector3, _d: Vector3, t: Node, gold: int, _w: bool, _c: int) -> void:
		var who: Node3D = rp.character(peer)
		var sound: Node3D = main.get_node("Impacts")._shot_sounds.get(peer)
		shots.append([peer, t, gold, labels.any(func(l: Label3D) -> bool: return l.visible),
			who.muzzle_position() if who else Vector3.INF, sound.global_position if sound else Vector3.INF]))
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
	if not _ok(not shots[0][3], "the client's +$ shows on the client only"): return
	var muzzle: Vector3 = shots[0][4]
	if not _ok(muzzle.distance_to(main.get_node("Dummy").global_position + Vector3(-11, 1.1, 0)) < 1.0,
			"the client's character stood where it fired from"): return
	if not _ok(shots[0][5].distance_to(muzzle) < 0.001, "the shot rang out at that character's muzzle"): return
	if not _ok(gs.player(cid).has_pose and gs.player(cid).pos.distance_to(Vector3(12, 0, 0)) < 0.3, "the client's pose reached the host"): return
	if not await _until(func() -> bool: return rp.character(cid) == null, "the client's character to go"): return
	var p = gs.player(cid)
	if not _ok(p.gold == 1 and p.loaded == 0 and p.carried == 0, "host keeps the client's state"): return
	if not _ok(gs.player().carried == 1, "the host's own hand is untouched"): return
	print("net_check OK")
	quit()


func _client() -> void:
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client, "connect"): return
	if not await _until(func() -> bool: return gs.pile == gs.PILE_START - 1, "pile count on join"): return
	# Our own spawn point, not the host's.
	var me: Node3D = main.get_node("Player")
	var spawns := root.get_tree().get_nodes_in_group("spawn")
	if not await _until(func() -> bool: return gs.spawn_index == 1, "a spawn point from the host"): return
	if not _ok(me.global_position.distance_to(spawns[1].global_position) < 0.5 and spawns[1].global_position.distance_to(spawns[0].global_position) > 2.0,
			"we start on spawn 1, away from the host's"): return
	# The host's body shows up as a character where the host stands.
	var rp: Node = main.get_node("RemotePlayers")
	if not await _until(func() -> bool: return rp.character(1) != null and rp.character(1).visible, "the host's character"): return
	if not _ok(rp.character(1).global_position.distance_to(spawns[0].global_position) < 0.5, "it stands on the host's spawn"): return
	# Walk up to the line to shoot from there; our pose follows us to the host.
	me.global_position = Vector3(12, 0, 0)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout  # the pose reaches the host, its character catches up
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
	# A shot from five metres off our body: predicted, then the host says it never happened.
	var dummy0: Node3D = main.get_node("Dummy")
	var fake := dummy0.global_position + Vector3(-11, 1.1, 5)
	var any_shot := [false]
	gs.shot_landed.connect(func(_p: int, _a: Vector3, _n: Vector3, _d: Vector3, _t: Node, _g: int, _w: bool, _c: int) -> void: any_shot[0] = true)
	if not _ok(gs.request_fire(fake, Vector3(1, 0, 0)) and gs.loaded == 0, "forged shot predicted"): return
	if not await _until(gs.synced, "answer to the forged shot"): return
	if not _ok(gs.loaded == 1 and not any_shot[0], "host dropped it: round back, nothing landed"): return
	gs.player().cooldown = 0.0
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
