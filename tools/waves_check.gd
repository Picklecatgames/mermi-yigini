extends SceneTree
## Headless zombie wave check (scripts/waves.gd) on the open ground, host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/waves_check.gd --quit-after 600
## Alone first, at TIME_SCALE: no pens, gates or lever out here, nothing offers a pull; the wave's call
## (GameState.request_pull_lever, whatever comes to make it) brings wave 1 out of the wood's edge, each
## on the ground, walking at us. We shoot every one of them through GameState and the wave clears; wave
## 2 waits. Wave 2 is left alone: they come, claw at us till we are down for good (GameState.all_down),
## the wave is lost, wave 2 waits again with nobody left and us up. Then dogs and blobs (_new_kinds).
## Then online: the host calls wave 3; the client, in a solo wave of its own, joins mid-wave, drops its
## own dead and gets the host's phase and zombies under the same paths, on the same ground, shoots them
## down through the host, sees the next wave waiting and calls it itself. Last, the client loses the
## host: the wave starts over there.
## The client aims some rounds at legs and arms; the limbs torn off each zombie by the time it dies
## must be the same on both machines (CUTS: the client's, read back by the host).
## Throughout, on both machines: no zombie still standing ever leaves the ground unless the wave
## was lost (shown as one) or the session was reset (_watch_wipes).

const PORT := 24693
const LOG := "user://waves_check_client.log"
const ENGINE_LOG := "user://waves_check_client_engine.log"  # the client's engine output: script errors, a crash
const CUTS := "user://waves_check_cuts.json"
const TIME_SCALE := 4.0  # the solo part: the walk from the wood is a long one
const SHOOT_FROM := 4.0  # m from what we aim at: nothing of the wood between us

var gs: Node
var net: Node
var main: Node
var waves: Node
var _log: Array[String] = []
var _client_pid := 0  # host: the client's process, till it has gone and passed
var _turn := 0  # _shoot_all: whose turn it is among the nearest
var _on := [0, -1.0, 0]  # _shoot_all, a client: the zombie it stays on, its bar then, rounds since that moved
var _cuts := {}  # zombie id -> the limbs it had lost when the die cue came (wave 3, online)
var _down := {}  # zombie id -> its die cue came
var _wipe_ok := false  # a wave lost, or a reset: the living may be cleared away


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
			_fail("zombie %d (standing) left the ground for no reason" % n.get_meta("zombie")))


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
	if not _ok(waves.wave == 1 and waves.phase == waves.Phase.READY, "wave 1 waits"): return
	if not _ok(waves._spawns.is_empty() and waves._gates.is_empty() and waves._lever == null, "no pens, gates or lever out here"): return
	var edges := root.get_tree().get_nodes_in_group("forest_edge")
	if not _ok(not edges.is_empty(), "the wood's edge is marked (%d)" % edges.size()): return
	var kills := []
	waves.zombie_killed.connect(func(peer: int, _kind: StringName, _weak: bool, at: Vector3, gun: String) -> void:
		kills.append([peer, at, gun]))
	var me: Node3D = main.get_node("Player")
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)  # (where the call is taken from)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout  # our pose catches up
	if not _ok(not waves.can_pull(me.global_position), "and nothing to pull where it was"): return
	gs.request_toggle_infinite_ammo()
	gs.request_select_gun(4)  # the Scorpion: test mode opens it
	Engine.time_scale = TIME_SCALE
	gs.request_pull_lever()
	if not _ok(waves.phase == waves.Phase.STARTING and waves.left == waves.BASE_COUNT, "wave 1 called, %d of them" % waves.BASE_COUNT): return
	gs.request_pull_lever()  # again: nothing more
	if not _ok(waves.left == waves.BASE_COUNT, "a second call does nothing"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT, "the fight"): return
	if not await _until(func() -> bool: return not waves._zombies.is_empty(), "the first out of the wood"): return
	for z: Dictionary in waves._zombies.values():
		var at: Vector3 = (z.node as Node3D).global_position
		var near := INF
		for m: Node3D in edges:
			near = minf(near, Vector2(at.x - m.global_position.x, at.z - m.global_position.z).length())
		if not _ok(near < 25.0 and z.inside and z.released, "%d out of the wood (%.1f m from its edge), hunting" % [z.id, near]): return
	if not await _shoot_all("wave 1"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.CLEARED, "wave 1 cleared"): return
	if not _ok(kills.size() == waves.BASE_COUNT and kills.all(func(k: Array) -> bool: return k[0] == gs.local_peer() and k[2] == "scorpion"),
			"zombie_killed told each kill: ours, with the Scorpion"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY and waves.wave == 2, "wave 2 to wait"): return
	# Wave 2 alone: they come and claw at us; down for good, the wave is lost.
	gs.request_pull_lever()
	var size: int = waves.BASE_COUNT + waves.COUNT_GROW
	if not _ok(waves.left == size, "wave 2 is %d strong (%d)" % [size, waves.left]): return
	var swung := [false]
	gs.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"swing":
			swung[0] = true)
	if not await _until(func() -> bool: return swung[0], "one to walk up and claw at us", 120.0): return
	if not await _until(func() -> bool: return gs.player().hp < gs.HP_MAX, "the claws to land", 30.0): return
	if not await _until(func() -> bool: return gs.is_down(), "us to go down", 120.0): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FAILED, "everyone down: the wave lost", 60.0): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY, "the lost wave to wait again"): return
	await process_frame
	if not _ok(waves.wave == 2 and waves._zombies.is_empty() and waves._queue.size() <= size, "wave 2 again, nobody left"): return
	if not await _until(func() -> bool: return not gs.is_down(), "us up again"): return
	if not await _new_kinds(): return
	Engine.time_scale = 1.0
	print("waves_check solo OK")
	await _online()


## Everyone up and whole: this is about the wave, not about who survives it.
func _heal() -> void:
	for peer: int in gs._slots_now():
		gs.player(peer).hp = gs.HP_MAX


func _online() -> void:
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	_watch_cuts()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CUTS))
	process_frame.connect(_heal)  # wave 3 must not be lost under the client's slow fire
	var me: Node3D = main.get_node("Player")  # (shoved about by the last wave)
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	gs.request_pull_lever()  # wave 3 is on when the client comes
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT, "wave 3's fight"): return
	var client_id := [0]
	gs.multiplayer.peer_connected.connect(func(id: int) -> void: client_id[0] = id)
	var pulled_by := [0]
	gs.lever_pulled.connect(func(peer: int) -> void: pulled_by[0] = peer)
	_client_pid = _start_client("res://tools/waves_check.gd")
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(_client_pid):
		if Time.get_ticks_msec() - t0 > 240_000:
			return _fail("client timed out")  # its log's last line is the last check it passed
		await process_frame
	if OS.get_process_exit_code(_client_pid) != 0:
		return _fail("client side failed")
	_client_pid = 0
	print(FileAccess.get_file_as_string(LOG))
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


## Dogs and blobs: none before their waves, the dogs in one pack; then a wave of them for real, out of
## the wood, shot down, a blob always bursting. Leaves wave 3 waiting.
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
	process_frame.connect(_heal)  # a wave that big would have us down before the blob is out
	var me: Node3D = main.get_node("Player")  # (up again where we were raised)
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	gs.request_pull_lever()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT, "wave %d's fight" % waves.BLOB_FROM): return false
	var make_room := func() -> bool:  # a full floor holds the rest back: the ones in front go (the host's way)
		if waves._alive() >= waves.MAX_ALIVE:
			for z: Dictionary in waves._zombies.values():
				if not z.dead and not z.kind in [&"dog", &"blob"]:
					waves._hurt(z, 1e6, gs.local_peer(), false, "deagle")
					break
		return spawned.values().has(&"dog") and spawned.values().has(&"blob")
	if not await _until(make_room, "a dog and a blob out of the wood"): return false
	for z: Dictionary in waves._zombies.values():
		if z.kind in [&"dog", &"blob"]:
			if not _ok(z.body.model == z.kind and absf(z.trunk.rotation.x - PI / 2) < 0.01 and z.body.height < 1.4,
					"%s %d wears its own model and lies low (%.2f m)" % [z.kind, z.id, z.body.height]): return false
	if not await _shoot_all("wave %d" % waves.BLOB_FROM): return false
	process_frame.disconnect(_heal)
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
	if not _ok(waves.phase == waves.Phase.STARTING, "a solo wave of our own"): return
	if not await _until(func() -> bool: return waves._zombies.size() >= 2, "our own dead out of the wood"): return
	var own: Array = waves._zombies.keys()
	_watch_cuts()
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client, "connect"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT and waves.wave == 3, "the host's wave 3 on joining"): return
	if not await _until(func() -> bool: return waves._zombies.size() > 0, "its zombies"): return
	if not _ok(own.all(func(id: int) -> bool: return not waves._zombies.has(id) or waves._zombies[id].inside), "our own dead are gone"): return
	await process_frame
	var standing := waves.get_children().filter(func(n: Node) -> bool: return n.has_meta("zombie") and not n.is_queued_for_deletion())
	if not _ok(standing.size() == waves._zombies.size(), "nothing else stands under Waves"): return
	for z: Dictionary in waves._zombies.values():
		if not _ok(z.node.get_path() == NodePath("/root/Main/Waves/Z%d" % z.id) and z.released, "zombie %d under the host's path, walking" % z.id): return
	# They move as the host has them: over the rolling ground too, not at the height they came in at.
	if not await _until(func() -> bool:
		for z: Dictionary in waves._zombies.values():
			if not z.dead and z.seen != Vector3.INF and absf((z.node as Node3D).global_position.y - (z.seen as Vector3).y) < 0.5:
				return true
		return false, "one on the host's ground"): return
	# Shoot from nearby: the host traces every round from our synced eye.
	gs.request_toggle_infinite_ammo()
	gs.request_select_gun(4)  # the Scorpion: test mode opens it
	if not await _until(gs.synced, "the host's answer"): return
	if not await _shoot_all("wave 3", me): return
	var f := FileAccess.open(CUTS, FileAccess.WRITE)
	f.store_string(JSON.stringify(_cuts))
	f.close()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY and waves.wave == 4, "wave 4 to wait", 40.0): return
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout  # our pose reaches the host
	gs.request_pull_lever()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.STARTING and waves.wave == 4, "our call to start wave 4"): return
	if not await _until(func() -> bool: return waves._zombies.size() > 0, "wave 4's dead"): return
	# The host is gone (as net.gd hears it): the wave starts over here and a call works again.
	gs.multiplayer.server_disconnected.emit()
	if not _ok(waves.phase == waves.Phase.READY and waves.wave == 4 and waves._zombies.is_empty(), "host gone: nobody left, wave 4 waiting"): return
	if not await _until(func() -> bool: return not net.online, "net.gd to drop the connection"): return
	gs.request_pull_lever()
	if not _ok(waves.phase == waves.Phase.STARTING, "and we can call it ourselves"): return
	_log.append("waves_check client OK")
	_write_log()
	_wipe_ok = true
	quit()


## Fires at every zombie until none of this wave is left. Solo the round starts a few metres from
## it, on the way to us; a client goes and stands there itself so its eye is the round's start.
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
		var near: Array = waves._zombies.values().filter(func(z: Dictionary) -> bool: return not z.dead)
		near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
		if not me:  # (a client stays on one)
			_turn += 1
		var at := Vector3.ZERO
		if not near.is_empty():
			var z: Dictionary = near[_turn % mini(near.size(), 3)]
			if me:  # past a few without a mark, the trunk, then the next one
				if _on[0] != z.id or _on[1] != z.bar.left:
					_on = [z.id, z.bar.left, 0]
				_on[2] += 1
				if _on[2] > 12:
					_turn += 1
					_on[2] = 0
			at = (z.node as Node3D).global_position
			# The trunk's shape where it is (on the bones, or low); a creature standing at chest height.
			aim = (z.trunk as Node3D).global_position if waves.LOW.has(z.kind) or z.body.crawling or not z.bones.is_empty() else at + Vector3.UP * 1.1
			if me and _on[2] <= 6 and not waves.LOW.has(z.kind) and not z.body.crawling and z.kind != &"brute":
				match z.id % 3:  # some into the legs, some into an arm
					1: aim = z.body.call("_bone_at", "RightLeg")  # the knee
					2: if z.body.can_lose(&"forearm_l"):  # (once it is off, the trunk)
						aim = z.body.call("_bone_at", "LeftForeArm")
		if aim != Vector3.INF:
			var toward := Vector3(gs.LEVER_POS.x - at.x, 0.0, gs.LEVER_POS.z - at.z).normalized()
			var stand := at + toward * SHOOT_FROM
			var from: Vector3 = stand + Vector3.UP * gs.EYE
			if me:
				var off := me.global_position - at
				off.y = 0.0
				if off.length() < SHOOT_FROM * 0.5 or off.length() > SHOOT_FROM * 2.0:
					me.global_position = stand + Vector3.UP * 0.1
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
	if not cond.call():
		_write_log(what)
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			_fail("waited for %s (phase %d, wave %d, %d alive)" % [what, waves.phase, waves.wave, waves._alive()])
			return false
		await process_frame
	return true


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fail(what)
	else:
		_log.append("ok: " + what)
		_write_log()  # a script error stops the client without quitting: the host shows how far it got
	return cond


func _fail(what: String) -> void:
	_wipe_ok = true  # quitting frees the floor
	_log.append("waves_check FAIL: " + what)
	_stop_client()
	printerr("waves_check FAIL: ", what)
	_write_log()
	quit(1)


## Host: the client, this script again with `-- --client`, its engine output in ENGINE_LOG.
func _start_client(script: String) -> int:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ENGINE_LOG))
	return OS.create_process(OS.get_executable_path(), ["--headless", "--log-file", ProjectSettings.globalize_path(ENGINE_LOG),
		"--path", ProjectSettings.globalize_path("res://"), "-s", script, "--", "--client"])


## Host, failing with the client still about: stops it and shows its log and the end of its engine
## output, so a hang, a script error or a crash on its side says where.
func _stop_client() -> void:
	if _client_pid == 0:
		return
	if OS.is_process_running(_client_pid):
		OS.kill(_client_pid)
	_client_pid = 0
	print("--- client log:\n", FileAccess.get_file_as_string(LOG))
	var engine := FileAccess.get_file_as_string(ENGINE_LOG).split("\n")
	print("--- client engine output, last lines:\n", "\n".join(engine.slice(-40)))


## `waiting`: the step the client is on, for the host to print if it has to kill it there.
func _write_log(waiting := "") -> void:
	if "--client" in OS.get_cmdline_user_args():
		var lines := _log.duplicate()
		if waiting:
			lines.append("waiting for " + waiting)
		var f := FileAccess.open(LOG, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(lines))
