extends SceneTree
## Headless zombie wave check (scripts/waves.gd), host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/waves_check.gd --quit-after 600
## Alone first, at TIME_SCALE: the lever starts wave 1 (lever down, alarms lit, gates open, the dead
## walk out), we shoot every one of them through GameState and the wave clears: gates shut, lever
## up, wave 2 waits. Wave 2 is left alone: the dead claw the railing down and the wave is lost (the
## temporary rule), wave 2 waits again with nobody left. Then online: the host pulls wave 2, the
## client joins mid-wave and gets the phase and the same zombies under the same paths, shoots them
## down through the host, sees wave 3 waiting and pulls the lever itself from beside it.

const PORT := 24693
const LOG := "user://waves_check_client.log"
const TIME_SCALE := 4.0  # the solo part: walkers take half a minute to reach the railing
const SHOOT_FROM_X := 12.5

var gs: Node
var net: Node
var main: Node
var waves: Node
var _log: Array[String] = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	waves = main.get_node("Waves")
	for i in 3:
		await physics_frame
	if "--client" in OS.get_cmdline_user_args():
		await _client()
	else:
		await _host()


func _host() -> void:
	if not _ok(waves.wave == 1 and waves.phase == waves.Phase.READY and waves._number.text == "01", "wave 1 waits, the sign says 01"): return
	if not _ok(waves._spawns.size() == 24 and waves._gates.size() == 4 and waves._alarms.size() == 12, "spawns, gate leaves and alarms found"): return
	if not _ok(waves._lever_clip != &"", "the lever has its clip"): return
	var me: Node3D = main.get_node("Player")
	if not _ok(not waves.can_pull(me.global_position), "out of the lever's reach from the spawn"): return
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)  # stays there: the rounds below start at the railing
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout  # our pose catches up
	if not _ok(waves.can_pull(me.global_position), "the lever in reach beside it"): return
	gs.request_toggle_infinite_ammo()
	gs.request_select_gun(4)  # the Scorpion: test mode opens it
	Engine.time_scale = TIME_SCALE
	var gate: Node3D = waves._gates[0]
	var shut := gate.position
	gs.request_pull_lever()
	if not _ok(waves.phase == waves.Phase.STARTING and waves._zombies.size() == waves.BASE_COUNT, "the lever starts wave 1 and its %d dead wait in the pens" % waves.BASE_COUNT): return
	if not _ok(waves._lever_anim.is_playing() and not waves._lit, "the lever swings down, the lights not on yet"): return
	gs.request_pull_lever()  # again: nothing more
	if not _ok(waves._zombies.size() == waves.BASE_COUNT, "a second pull does nothing"): return
	if not await _until(func() -> bool: return waves._lit, "the alarms to light"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT, "the fight"): return
	if not await _until(func() -> bool: return gate.position.distance_to(shut + gate.get_meta("open_offset")) < 0.01, "the gates to open"): return
	if not await _shoot_all("wave 1"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.CLEARED, "wave 1 cleared"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY and waves.wave == 2, "wave 2 to wait"): return
	if not _ok(not waves._lit and waves._status.text == "HAZIR", "lights off, the sign says HAZIR"): return
	if not await _until(func() -> bool: return waves._number.text == "02", "the sign to flip to 02"): return
	if not await _until(func() -> bool: return gate.position.distance_to(shut) < 0.01, "the gates to shut"): return
	# Wave 2 alone: the railing goes and the wave is lost.
	gs.request_pull_lever()
	var size: int = waves.BASE_COUNT + waves.COUNT_GROW
	if not _ok(waves.left == size, "wave 2 is %d strong (%d)" % [size, waves.left]): return
	var bites := [0]
	gs.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"fence":
			bites[0] += 1)
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FAILED, "the railing to fall", 120.0): return
	if not _ok(bites[0] > 0 and waves.fence == 0 and waves._status.text == "ÇİT YIKILDI", "it fell bite by bite and the sign says so"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY, "the lost wave to wait again"): return
	await process_frame
	if not _ok(waves.wave == 2 and waves.fence == waves.FENCE_HP and waves._zombies.is_empty(), "wave 2 again, the railing whole, nobody left"): return
	Engine.time_scale = 1.0
	if not await _until(func() -> bool: return gate.position.distance_to(shut) < 0.01, "the gates to shut"): return
	print("waves_check solo OK")
	await _online()


func _online() -> void:
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	gs.request_pull_lever()  # wave 2 is on when the client comes
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT, "wave 2's fight"): return
	var client_id := [0]
	gs.multiplayer.peer_connected.connect(func(id: int) -> void: client_id[0] = id)
	var pulled_by := [0]
	gs.lever_pulled.connect(func(peer: int) -> void: pulled_by[0] = peer)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "-s", "res://tools/waves_check.gd", "--", "--client"])
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() - t0 > 240_000:
			OS.kill(pid)
			return _fail("client timed out")
		await process_frame
	print(FileAccess.get_file_as_string(LOG))
	if OS.get_process_exit_code(pid) != 0:
		return _fail("client side failed")
	if not _ok(client_id[0] != 0 and pulled_by[0] == client_id[0], "the client's pull reached the host"): return
	if not _ok(waves.wave == 3 and waves.phase in [waves.Phase.STARTING, waves.Phase.FIGHT], "and started wave 3"): return
	print("waves_check OK")
	quit()


func _client() -> void:
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client, "connect"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT and waves.wave == 2, "the host's wave 2 on joining"): return
	if not await _until(func() -> bool: return waves._zombies.size() > 0, "its zombies"): return
	var gate: Node3D = waves._gates[0]
	if not _ok(waves._lit and gate.position.distance_to(waves._gate_home[gate] + gate.get_meta("open_offset")) < 0.01, "lights on and gates open at once"): return
	for z: Dictionary in waves._zombies.values():
		if not _ok(z.node.get_path() == NodePath("/root/Main/Waves/Z%d" % z.id) and z.released, "zombie %d under the host's path, walking" % z.id): return
	# Shoot from the railing: the host traces every round from our synced eye.
	var me: Node3D = main.get_node("Player")
	gs.request_toggle_infinite_ammo()
	gs.request_select_gun(4)  # the Scorpion: test mode opens it
	if not await _until(gs.synced, "the host's answer"): return
	if not await _shoot_all("wave 2", me): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY and waves.wave == 3, "wave 3 to wait", 40.0): return
	if not await _until(func() -> bool: return waves._number.text == "03", "the sign to flip to 03"): return
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout  # our pose reaches the host
	if not _ok(waves.can_pull(me.global_position), "the lever is in reach"): return
	gs.request_pull_lever()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.STARTING and waves.wave == 3, "our pull to start wave 3"): return
	if not await _until(func() -> bool: return waves._zombies.size() > 0, "wave 3's dead"): return
	_log.append("waves_check client OK")
	_write_log()
	quit()


## Fires at every zombie out in the hall until none of this wave is left. Solo the round leaves
## from the railing level with it; a client stands there itself so its eye is the round's start.
func _shoot_all(what: String, me: Node3D = null) -> bool:
	var t0 := Time.get_ticks_msec()
	while waves.left > 0:
		if Time.get_ticks_msec() - t0 > 120_000:
			_fail("%s: %d left standing" % [what, waves.left])
			return false
		var aim := Vector3.INF
		for z: Dictionary in waves._zombies.values():
			var at: Vector3 = (z.node as Node3D).global_position
			if not z.dead and at.x < 27.0:
				aim = at + Vector3.UP * (0.35 if z.kind == &"crawler" else 1.1)
				break
		if aim != Vector3.INF:
			var from := Vector3(SHOOT_FROM_X, gs.EYE, aim.z)
			if me:
				if me.global_position.distance_to(Vector3(SHOOT_FROM_X, 0, aim.z)) > 0.3:
					me.global_position = Vector3(SHOOT_FROM_X, 0, aim.z)
					me.reset_physics_interpolation()
					await create_timer(0.25).timeout  # our pose reaches the host
					continue
				from = me.global_position + Vector3.UP * gs.EYE
			gs.player().cooldown = 0.0 if not me else gs.player().cooldown
			gs.request_fire(from, (aim - from).normalized())
		if me:
			await create_timer(0.15).timeout
		else:
			await physics_frame
	return true


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
		_log.append("ok: " + what)
	return cond


func _fail(what: String) -> void:
	_log.append("waves_check FAIL: " + what)
	printerr("waves_check FAIL: ", what)
	_write_log()
	quit(1)


func _write_log() -> void:
	if "--client" in OS.get_cmdline_user_args():
		var f := FileAccess.open(LOG, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_log))
