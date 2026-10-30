extends SceneTree
## Headless zombie wave check (scripts/waves.gd), host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/waves_check.gd --quit-after 600
## Alone first, at TIME_SCALE: the lever starts wave 1 (lever down, alarms lit, gates open, the dead
## walk out), we shoot every one of them through GameState and the wave clears: gates shut, lever
## up, wave 2 waits. Wave 2 is left alone: the dead claw the railing down and the wave is lost
## (GameState.fence), wave 2 waits again with nobody left and the railing patched up a little. Wave 2 once more, every zombie put down in
## the pens before the gates are wide (it must still clear). Then dogs and blobs (_new_kinds). Then online: the host pulls wave 3;
## the client, in a solo wave of its own, joins mid-wave, drops its own dead and gets the host's
## phase and zombies under the same paths, shoots them down through the host, sees the next wave
## waiting and pulls the lever itself. Last, the client loses the host: the wave starts over there.
## The client aims some rounds at legs and arms; the limbs torn off each zombie by the time it dies
## must be the same on both machines (CUTS: the client's, read back by the host).
## Throughout, on both machines: no zombie still standing ever leaves the floor unless the railing
## fell (a lost wave, shown as one) or the session was reset (_watch_wipes; the dead ones used to
## vanish without a word when the old temporary railing ran out).

const PORT := 24693
const LOG := "user://waves_check_client.log"
const CUTS := "user://waves_check_cuts.json"
const TIME_SCALE := 4.0  # the solo part: walkers take half a minute to reach the railing
const SHOOT_FROM_X := 12.5

var gs: Node
var net: Node
var main: Node
var waves: Node
var _log: Array[String] = []
var _cuts := {}  # zombie id -> the limbs it had lost when the die cue came (wave 3, online)
var _down := {}  # zombie id -> its die cue came
var _wipe_ok := false  # the railing fell, or a reset: the living may be cleared away


## Fails the moment a living zombie leaves the floor while nothing allows it.
func _watch_wipes() -> void:
	gs.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"die":
			_down[cue[1]] = true
		elif cue[0] == &"reset" or (cue[0] == &"phase" and cue[2] == waves.Phase.FAILED):
			_wipe_ok = true
		elif cue[0] == &"phase" and cue[2] == waves.Phase.STARTING:
			_wipe_ok = false)
	gs.multiplayer.server_disconnected.connect(func() -> void: _wipe_ok = true)
	waves.child_exiting_tree.connect(func(n: Node) -> void:
		if n.has_meta("zombie") and not _down.has(n.get_meta("zombie")) and not _wipe_ok:
			_fail("zombie %d (standing) left the floor with the railing up" % n.get_meta("zombie")))


## Notes what each zombie has lost as it goes down (the die cue comes after its limb cues).
func _watch_cuts() -> void:
	gs.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"die" and waves._zombies.has(cue[1]) and waves.wave == 3:
			var cut: Array = waves._zombies[cue[1]].body.cuts.map(func(c: StringName) -> String: return String(c))
			cut.sort()
			_cuts[str(cue[1])] = cut)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	waves = main.get_node("Waves")
	for i in 3:
		await physics_frame
	_watch_wipes()
	if "--client" in OS.get_cmdline_user_args():
		await _client()
	else:
		await _host()


func _host() -> void:
	if not _ok(waves.wave == 1 and waves.phase == waves.Phase.READY and waves._number.text == "01", "wave 1 waits, the sign says 01"): return
	if not _ok(waves._spawns.size() == 24 and waves._gates.size() == 4 and waves._alarms.size() == 12, "spawns, gate leaves and alarms found"): return
	if not _ok(waves._lever_clip != &"", "the lever has its clip"): return
	var kills := []
	waves.zombie_killed.connect(func(peer: int, _kind: StringName, _weak: bool, at: Vector3, gun: String) -> void:
		kills.append([peer, at, gun]))
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
	if not _ok(kills.size() == waves.BASE_COUNT and kills.all(func(k: Array) -> bool: return k[0] == gs.local_peer() and k[2] == "scorpion" and k[1].x > 14.0),
			"zombie_killed told each kill: ours, with the Scorpion, past the railing"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY and waves.wave == 2, "wave 2 to wait"): return
	if not _ok(not waves._lit and waves._status.text == "HAZIR", "lights off, the sign says HAZIR"): return
	if not await _until(func() -> bool: return waves._number.text == "02", "the sign to flip to 02"): return
	if not await _until(func() -> bool: return gate.position.distance_to(shut) < 0.01, "the gates to shut"): return
	# Wave 2 alone: the railing goes and the wave is lost.
	gs.request_pull_lever()
	var size: int = waves.BASE_COUNT + waves.COUNT_GROW
	if not _ok(waves.left == size, "wave 2 is %d strong (%d)" % [size, waves.left]): return
	var bites := [0]
	gs.fence_changed.connect(func(_hp: int, _wear: Array) -> void: bites[0] += 1)
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FAILED, "the railing to fall", 120.0): return
	if not _ok(bites[0] > 0 and waves.fence == 0 and waves._status.text == "ÇİT YIKILDI", "it fell bite by bite and the sign says so"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY, "the lost wave to wait again"): return
	await process_frame
	if not _ok(waves.wave == 2 and gs.fence == gs.FENCE_PATCH and waves._zombies.is_empty(), "wave 2 again, the railing patched up, nobody left"): return
	gs.mend_fence(gs.FENCE_MAX)  # the rest of the check wants a whole railing
	# Wave 2 again, all of it shot in the pens before the fight is called: it clears anyway.
	gs.request_pull_lever()
	for id: int in waves._zombies.keys():
		gs.cue_wave([&"die", id, waves.left - 1, gs.local_peer(), false, waves._zombies[id].node.global_position, "scorpion"])
	if not _ok(waves.phase == waves.Phase.STARTING and waves.left == 0, "all of wave 2 down before the gates"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY and waves.wave == 3, "wave 2 to clear all the same"): return
	if not await _new_kinds(): return
	Engine.time_scale = 1.0
	if not await _until(func() -> bool: return gate.position.distance_to(shut) < 0.01, "the gates to shut"): return
	print("waves_check solo OK")
	await _online()


func _online() -> void:
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	_watch_cuts()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CUTS))
	gs.request_pull_lever()  # wave 3 is on when the client comes
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT, "wave 3's fight"): return
	var client_id := [0]
	gs.multiplayer.peer_connected.connect(func(id: int) -> void: client_id[0] = id)
	var pulled_by := [0]
	gs.lever_pulled.connect(func(peer: int) -> void: pulled_by[0] = peer)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "-s", "res://tools/waves_check.gd", "--", "--client"])
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		gs.mend_fence(gs.FENCE_MAX)  # wave 3 must not be lost under the client's slow fire
		if Time.get_ticks_msec() - t0 > 240_000:
			OS.kill(pid)
			return _fail("client timed out")
		await process_frame
	print(FileAccess.get_file_as_string(LOG))
	if OS.get_process_exit_code(pid) != 0:
		return _fail("client side failed")
	var theirs = JSON.parse_string(FileAccess.get_file_as_string(CUTS))
	var torn := 0
	for id: String in _cuts:
		torn += (_cuts[id] as Array).size()
	print("limbs torn in wave 3, host: ", _cuts)
	if not _ok(theirs is Dictionary and (theirs as Dictionary).size() >= _cuts.size() - 1, "the client saw the kills (%s)" % [theirs]): return
	if not _ok(torn > 0, "limbs came off in wave 3"): return
	for id: String in _cuts:
		if theirs.has(id) and not _ok(theirs[id] == _cuts[id], "zombie %s lost %s here and %s there" % [id, _cuts[id], theirs[id]]): return
	if not _ok(client_id[0] != 0 and pulled_by[0] == client_id[0], "the client's pull reached the host"): return
	if not _ok(waves.wave == 4 and waves.phase in [waves.Phase.STARTING, waves.Phase.FIGHT], "and started wave 4"): return
	print("waves_check OK")
	_wipe_ok = true
	quit()


## Dogs and blobs: none before their waves, the dogs in one pack; then a wave of them for real, from
## the pens to the railing, shot down, a blob always bursting. Leaves wave 3 waiting.
func _new_kinds() -> bool:
	for w in [1, 3, waves.DOG_FROM, waves.BLOB_FROM, 12, 30]:
		var plan: Array = waves._plan(w)
		var dogs := plan.count(&"dog")
		var want := 0 if w < waves.DOG_FROM else mini(waves.DOG_PACK + (w - waves.DOG_FROM) / waves.DOG_PACK_GROW, waves.DOG_PACK_MAX)
		var first := plan.find(&"dog")
		if not _ok(dogs == want and plan.slice(first, first + dogs).all(func(k: StringName) -> bool: return k == &"dog"),
				"wave %d: %d dogs, in one pack" % [w, want]): return false
		if not _ok(w >= waves.BLOB_FROM or not plan.has(&"blob"), "wave %d: no blobs before wave %d" % [w, waves.BLOB_FROM]): return false
	if not _ok(waves._plan(30).has(&"blob"), "blobs in wave 30"): return false
	var seed := 0
	while true:  # a roll of wave BLOB_FROM that has a blob in it
		waves._rng.seed = seed
		if waves._plan(waves.BLOB_FROM).has(&"blob"):
			break
		seed += 1
	waves._rng.seed = seed
	gs.cue_wave([&"phase", waves.BLOB_FROM, waves.Phase.READY, 0])
	var gibs := {}  # kind -> how they went down
	var spawned := {}
	var cue_seen := func(cue: Array) -> void:
		if cue[0] == &"spawn":
			spawned[cue[1]] = cue[2]
		elif cue[0] == &"die" and spawned.has(cue[1]):
			gibs[spawned[cue[1]]] = gibs.get(spawned[cue[1]], []) + [cue[7]]
	gs.wave_cue.connect(cue_seen)
	gs.request_pull_lever()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT, "wave %d's fight" % waves.BLOB_FROM): return false
	if not await _until(func() -> bool: return spawned.values().has(&"dog") and spawned.values().has(&"blob"), "a dog and a blob out of the pens"): return false
	for z: Dictionary in waves._zombies.values():
		if z.kind in [&"dog", &"blob"]:
			if not _ok(z.body.model == z.kind and absf(z.trunk.rotation.x - PI / 2) < 0.01 and z.body.height < 1.4,
					"%s %d wears its own model and lies low (%.2f m)" % [z.kind, z.id, z.body.height]): return false
	if not await _shoot_all("wave %d" % waves.BLOB_FROM): return false
	gs.wave_cue.disconnect(cue_seen)
	if not await _until(func() -> bool: return waves.phase == waves.Phase.CLEARED, "wave %d cleared" % waves.BLOB_FROM): return false
	if not _ok(gibs.has(&"dog") and (gibs.get(&"blob", []) as Array).all(func(g: StringName) -> bool: return g == &"body") and gibs.has(&"blob"),
			"the dogs went down, every blob burst (%s)" % gibs): return false
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY, "the next wave to wait"): return false
	gs.cue_wave([&"phase", 3, waves.Phase.READY, 0])  # back to where the online part starts
	print("waves_check new kinds OK: ", gibs)
	return true


func _client() -> void:
	# A wave of our own first, solo: joining must drop it (the host's ids are past ours by now).
	var me: Node3D = main.get_node("Player")
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	gs.request_pull_lever()
	if not _ok(waves.phase == waves.Phase.STARTING and waves._zombies.size() == waves.BASE_COUNT, "a solo wave of our own"): return
	var own: Array = waves._zombies.keys()
	_watch_cuts()
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client, "connect"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT and waves.wave == 3, "the host's wave 3 on joining"): return
	if not await _until(func() -> bool: return waves._zombies.size() > 0, "its zombies"): return
	if not _ok(own.all(func(id: int) -> bool: return not waves._zombies.has(id)), "our own dead are gone"): return
	await process_frame
	var standing := waves.get_children().filter(func(n: Node) -> bool: return n.has_meta("zombie") and not n.is_queued_for_deletion())
	if not _ok(standing.size() == waves._zombies.size(), "nothing else stands under Waves"): return
	var gate: Node3D = waves._gates[0]
	if not _ok(waves._lit and gate.position.distance_to(waves._gate_home[gate] + gate.get_meta("open_offset")) < 0.01, "lights on and gates open at once"): return
	for z: Dictionary in waves._zombies.values():
		if not _ok(z.node.get_path() == NodePath("/root/Main/Waves/Z%d" % z.id) and z.released, "zombie %d under the host's path, walking" % z.id): return
	# Shoot from the railing: the host traces every round from our synced eye.
	gs.request_toggle_infinite_ammo()
	gs.request_select_gun(4)  # the Scorpion: test mode opens it
	if not await _until(gs.synced, "the host's answer"): return
	if not await _shoot_all("wave 3", me): return
	var f := FileAccess.open(CUTS, FileAccess.WRITE)
	f.store_string(JSON.stringify(_cuts))
	f.close()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY and waves.wave == 4, "wave 4 to wait", 40.0): return
	if not await _until(func() -> bool: return waves._number.text == "04", "the sign to flip to 04"): return
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout  # our pose reaches the host
	if not _ok(waves.can_pull(me.global_position), "the lever is in reach"): return
	gs.request_pull_lever()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.STARTING and waves.wave == 4, "our pull to start wave 4"): return
	if not await _until(func() -> bool: return waves._zombies.size() > 0, "wave 4's dead"): return
	# The host is gone (as net.gd hears it): the wave starts over here and the lever works again.
	gs.multiplayer.server_disconnected.emit()
	if not _ok(waves.phase == waves.Phase.READY and waves.wave == 4 and waves._zombies.is_empty() and not waves._lit, "host gone: quiet bay, wave 4 waiting"): return
	if not await _until(func() -> bool: return not net.online, "net.gd to drop the connection"): return
	gs.request_pull_lever()
	if not _ok(waves.phase == waves.Phase.STARTING and waves._zombies.size() > 0, "and we can pull it ourselves"): return
	_log.append("waves_check client OK")
	_write_log()
	_wipe_ok = true
	quit()


## Fires at every zombie out in the hall until none of this wave is left. Solo the round leaves
## from the railing level with it; a client stands there itself so its eye is the round's start.
func _shoot_all(what: String, me: Node3D = null) -> bool:
	var t0 := Time.get_ticks_msec()
	while waves.left > 0:
		if Time.get_ticks_msec() - t0 > 120_000:
			var still := []
			for z: Dictionary in waves._zombies.values():
				if not z.dead:
					still.append("%s %s at %s path %d down %.1f low %s bar %.2f" % [z.id, z.kind, (z.node as Node3D).global_position, z.path.size(), z.down, z.body.crawling, z.bar.left])
			_fail("%s: %d left standing: %s" % [what, waves.left, still])
			return false
		var aim := Vector3.INF
		for z: Dictionary in waves._zombies.values():
			var at: Vector3 = (z.node as Node3D).global_position
			if not z.dead and at.x < 27.0:
				aim = at + Vector3.UP * (z.trunk.position.y if waves.LOW.has(z.kind) or z.body.crawling else 1.1)  # (a leg torn off: low too)
				# (at the railing its swings take the arms out of the body's shape: the trunk there)
				if me and not waves.LOW.has(z.kind) and not z.body.crawling and z.kind != &"brute" and not z.path.is_empty():
					match z.id % 3:  # some into the legs, some into an arm
						1: aim = at + Vector3(0, 0.45, 0.1)
						2: aim = z.body.call("_bone_at", "LeftForeArm")
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
	_wipe_ok = true  # quitting frees the floor
	_log.append("waves_check FAIL: " + what)
	printerr("waves_check FAIL: ", what)
	_write_log()
	quit(1)


func _write_log() -> void:
	if "--client" in OS.get_cmdline_user_args():
		var f := FileAccess.open(LOG, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_log))
