extends SceneTree
## Headless check of a player's life and going down (GameState.hurt_player, player.gd, down_view.gd,
## remote_players.gd, bench_menu.gd), alone and then host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/down_check.gd --quit-after 100000
## Alone: a blow takes its share and marks the side it came from, the view shakes; between waves life
## comes back, in a fight it does not. At 0 we are down: no moving, no shooting, the view on the floor
## and tipped over, the screen reddens, then goes black; nobody to watch, so all_down comes, and not
## before. A blow on the floor does nothing. The lost wave waiting again stands us up, whole.
## Online: the host's blows reach the client; the client down, its rounds and its walking away are
## turned down by the host, its body lies on the floor on the host, it watches the host through the
## host's eyes. No revive during the fight; once cleared the host raises it from the bench for the
## price, from the vault. Then the client raises the host. Both down in the next wave: all_down on
## both machines, and the lost wave waiting again stands both up.

const PORT := 24733  # not Net.PORT nor another check's
const LOG := "user://down_check_client.log"
const ENGINE_LOG := "user://down_check_client_engine.log"  # the client's engine output: script errors, a crash
const SEEN := "user://down_check_seen.json"
const FROM := Vector3(14.5, 1.2, 0.0)  # a zombie over the railing

var gs: Node
var net: Node
var main: Node
var me: CharacterBody3D
var view: Control
var _log: Array[String] = []
var _client_pid := 0  # host: the client's process, till it has gone and passed
var _all_down := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	for i in 3:
		await physics_frame
	me = main.get_node("Player")
	view = me._down_ui
	gs.all_down.connect(func() -> void: _all_down += 1)
	if not "--client" in OS.get_cmdline_user_args():
		gs.request_pick_character("boss")
	if "--client" in OS.get_cmdline_user_args():
		await _client()
	else:
		await _solo()


func _solo() -> void:
	me.global_position = Vector3(10.0, 0.0, 0.0)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	if not _ok(gs.player().hp == gs.HP_MAX and not gs.is_down(), "we start whole, standing"): return
	var hurt := [0]
	gs.health_changed.connect(func(peer: int, _hp: float, _f: Vector3, h: bool) -> void:
		if h and peer == gs.local_peer():
			hurt[0] += 1)
	var trauma: float = me._trauma
	gs.hurt_player(0, 30.0, FROM)
	if not _ok(gs.player().hp == 70.0 and hurt[0] == 1, "a blow takes 30 (%.0f left)" % gs.player().hp): return
	await process_frame  # (emitted before the nodes' own _process)
	await process_frame
	if not _ok(view._hits.size() == 1 and view._hit > 0.5 and view._tint.visible and me._trauma > trauma + 0.3, "its spray, the red pulse and the shake (%d, %.2f, %s, %.2f)" % [view._hits.size(), view._hit, view._tint.visible, me._trauma]): return
	if not _ok(view._name.visible == false, "no words on a blow"): return
	await create_timer(1.0).timeout
	if not _ok(gs.player().hp > 76.0, "between waves life comes back (%.1f)" % gs.player().hp): return
	gs.cue_wave([&"phase", 1, gs.WAVE_FIGHT, 6])
	var held: float = gs.player().hp
	await create_timer(1.0).timeout
	if not _ok(gs.player().hp == held, "not in a fight"): return
	# Down.
	var downed := [0]
	gs.player_downed.connect(func(_p: int) -> void: downed[0] += 1)
	gs.hurt_player(gs.local_peer(), 500.0, FROM)
	if not _ok(gs.is_down() and gs.player().hp == 0.0 and downed[0] == 1, "down at 0"): return
	gs.hurt_player(0, 10.0, FROM)
	if not _ok(hurt[0] == 2 and downed[0] == 1, "no more blows on the floor"): return
	gs.request_toggle_infinite_ammo()  # loaded, a gun open: still no shot
	gs.request_select_gun(1)
	if not _ok(not gs.request_fire(me._camera.global_position, Vector3.RIGHT) and me._hands_busy(), "no shooting, no moving"): return
	var at := me.global_position
	Input.action_press("move_forward")
	await create_timer(1.0).timeout
	Input.action_release("move_forward")
	if not _ok(Vector2(me.global_position.x - at.x, me.global_position.z - at.z).length() < 0.05, "WASD does not move us"): return
	var eye: float = me._head.global_position.y - me.global_position.y
	if not _ok(eye < 0.4 and me._camera.rotation.z > 1.0, "the view on the floor (%.2f m), tipped over (%.2f rad)" % [eye, me._camera.rotation.z]): return
	if not _ok(me._viewmodel._lowered > 0.98 and not me._crosshair.visible, "no gun, no crosshair"): return
	await create_timer(3.0).timeout  # ~4 s down
	var red: float = view._red
	if not _ok(red > 0.35 and red < 0.7 and view._dark == 0.0 and view._tint.visible, "reddening (%.2f), not dark yet" % red): return
	if not _ok(_all_down == 0, "no all_down while the screen is still red"): return
	await create_timer(gs.DOWN_TIME - 4.0 + 0.3).timeout
	if not _ok(view._dark > 0.99 and me.watching == 0, "black, nobody to watch"): return
	if not _ok(_all_down == 1, "alone, all_down once it is dark"): return
	await create_timer(0.5).timeout
	if not _ok(_all_down == 1, "and only once"): return
	gs.cue_wave([&"phase", 1, gs.WAVE_FAILED, 6])
	await create_timer(0.2).timeout
	if not _ok(gs.is_down(), "still down while the wave is lost"): return
	gs.cue_wave([&"phase", 1, gs.WAVE_READY, 0])
	await process_frame
	if not _ok(not gs.is_down() and gs.player().hp == gs.HP_MAX, "the lost wave waiting again stands us up, whole"): return
	await create_timer(1.0).timeout
	eye = me._head.global_position.y - me.global_position.y
	if not _ok(eye > 1.4 and view._dark < 0.01 and view._red < 0.01, "back on our feet, the screen clear (%.2f m)" % eye): return
	gs.request_toggle_infinite_ammo()
	print("down_check solo OK")
	await _online()


func _online() -> void:
	_all_down = 0  # the solo one
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEEN))
	_client_pid = _start_client("res://tools/down_check.gd")
	if not await _until(func() -> bool: return gs.multiplayer.get_peers().size() == 1, "the client", 60.0): return
	var c: int = gs.multiplayer.get_peers()[0]
	if not await _until(func() -> bool: return gs.player(c).has_pose and gs.player(c).character != "", "the client's body"): return
	var fired := [0, 0]  # the client's rounds standing, down
	gs.fired.connect(func(peer: int, _f: Vector3, _d: Vector3) -> void:
		if peer == c:
			fired[1 if gs.is_down(c) else 0] += 1)
	await create_timer(1.5).timeout  # it takes the pistol, fires a round
	if not await _until(func() -> bool: return fired[0] > 0, "the client's round standing"): return
	gs.cue_wave([&"phase", 1, gs.WAVE_FIGHT, 6])  # no regen from here
	gs.hurt_player(c, 40.0, FROM)
	gs.hurt_player(c, 5.0, FROM)  # a client is hurt here only: its own call is dropped (client side)
	await create_timer(0.5).timeout
	gs.hurt_player(c, 100.0, FROM)
	if not _ok(gs.is_down(c), "the client is down here"): return
	var lie: Vector3 = gs.player(c).down_pos
	await create_timer(2.0).timeout  # it walks off and fires
	if not _ok(gs.player(c).pos == lie and fired[1] == 0, "its walking off and its rounds turned down"): return
	var rp := get_first_node_in_group("remote_players")
	var them: Node = rp.character(c)
	if not _ok(them != null and them._fallen and them._shape.height < 1.0, "its body lies on the floor here"): return
	var tree: AnimationTree = them._tree
	if not _ok(tree and tree.get("parameters/fall/current_state") == "down", "playing the fall"): return
	await create_timer(gs.DOWN_TIME).timeout
	if not _ok(_all_down == 0, "no all_down: we stand"): return
	# The bench: not in the fight, then for the price.
	me.global_position = gs.REPAIR_POS + Vector3(0, 0, -0.9)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	gs.vault = 1000.0
	if not _ok(not gs.request_revive(c) and gs.is_down(c), "no revive during the wave"): return
	gs.cue_wave([&"phase", 1, gs.WAVE_CLEARED, 0])
	await process_frame
	if not _ok(gs.is_down(c), "cleared: still down, watching"): return
	var bench: Node = me._bench
	bench.open()
	await process_frame
	var row: Button = bench._revive[0]
	if not _ok(row.visible and not row.disabled and row.text.contains("KALDIR") and row.text.ends_with("$%d" % gs.REVIVE_COST), "the bench's row: \"%s\"" % row.text.strip_edges()): return
	row.pressed.emit()
	if not _ok(not gs.is_down(c) and absf(gs.player(c).hp - gs.REVIVE_HP) < 3.0 and is_equal_approx(gs.vault, 1000.0 - gs.REVIVE_COST), "raised for $%d from the vault, %d life" % [gs.REVIVE_COST, gs.REVIVE_HP]): return
	await process_frame
	if not _ok(not row.visible, "the row goes"): return
	bench.close()
	await create_timer(1.0).timeout
	if not _ok(not them._fallen, "its body stands again here"): return
	# The client raises us.
	gs.hurt_player(0, 500.0, FROM)
	if not await _until(func() -> bool: return not gs.is_down(), "the client to raise us", 40.0): return
	if not _ok(is_equal_approx(gs.vault, 1000.0 - 2 * gs.REVIVE_COST) and absf(gs.player().hp - gs.REVIVE_HP) < 3.0, "raised by the client, paid from the vault"): return
	# Both down: all_down, then the lost wave stands both up.
	await create_timer(1.0).timeout
	gs.cue_wave([&"phase", 2, gs.WAVE_FIGHT, 9])
	gs.hurt_player(0, 500.0, FROM)
	gs.hurt_player(c, 500.0, FROM)
	await create_timer(gs.DOWN_TIME - 0.5).timeout
	if not _ok(_all_down == 0, "no all_down before DOWN_TIME"): return
	if not await _until(func() -> bool: return _all_down == 1, "all_down", 5.0): return
	gs.cue_wave([&"phase", 2, gs.WAVE_FAILED, 9])
	await create_timer(1.0).timeout
	gs.cue_wave([&"phase", 2, gs.WAVE_READY, 0])
	await process_frame
	if not _ok(not gs.is_down() and not gs.is_down(c) and gs.player(c).hp == gs.HP_MAX, "both up again, whole"): return
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(_client_pid):
		if Time.get_ticks_msec() - t0 > 120_000:
			return _fail("client timed out")  # its log's last line is the last check it passed
		await process_frame
	if OS.get_process_exit_code(_client_pid) != 0:
		return _fail("client side failed")
	_client_pid = 0
	print(FileAccess.get_file_as_string(LOG))
	var seen = JSON.parse_string(FileAccess.get_file_as_string(SEEN))
	if not _ok(seen is Dictionary and seen.all_down == 1 and is_equal_approx(seen.vault, gs.vault), "the same on the client (%s)" % [seen]): return
	print("down_check OK")
	quit()


func _client() -> void:
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client and gs._spawned, "joining"): return
	var host_peer := 1
	gs.request_pick_character("worker")  # picked alone, the host never heard
	me.global_position = Vector3(9.0, 0.0, 3.0)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout
	gs.request_take_pistol()
	gs.request_toggle_infinite_ammo()
	await create_timer(0.5).timeout
	_raw_fire()
	if not await _until(func() -> bool: return gs.player().hp == 55.0, "the host's blows"): return
	if not _ok(view._hits.size() >= 1, "their sprays here"): return
	gs.hurt_player(0, 50.0, FROM)
	if not _ok(gs.player().hp == 55.0, "our own blow is dropped"): return
	if not await _until(func() -> bool: return gs.is_down(), "going down"): return
	if not _ok(not gs.request_fire(me._camera.global_position, Vector3.RIGHT) and me._hands_busy(), "no shooting, no moving here"): return
	await create_timer(1.0).timeout
	if not _ok(me._head.global_position.y - me.global_position.y < 0.4, "the view on the floor"): return
	me.global_position += Vector3(-3.0, 0.0, 0.0)  # walking off anyway, and firing
	me.reset_physics_interpolation()
	for i in 3:
		_raw_fire()
		await create_timer(0.3).timeout
	if not await _until(func() -> bool: return gs.player().down_for > gs.DOWN_TIME + 0.2, "the dark"): return
	var rp := get_first_node_in_group("remote_players")
	var host_body: Node = rp.character(host_peer)
	if not _ok(me.watching == host_peer and host_body.watched and not host_body._model.visible, "watching the host, its body out of the way"): return
	await process_frame
	var eye: Transform3D = host_body.eye_transform()
	if not _ok(me._head.global_transform.origin.distance_to(eye.origin) < 0.01 and eye.origin.y > 1.4, "through its eyes"): return
	if not _ok(view._name.visible and view._red > 0.1, "its name, a red rim"): return
	await create_timer(1.0).timeout
	if not _ok(view._dark < 0.05, "the dark lifted off it"): return
	me._next_watch(1)
	if not _ok(me.watching == host_peer, "clicking on: nobody else stands, still the host"): return
	if not await _until(func() -> bool: return not gs.is_down(), "the host to raise us", 30.0): return
	if not _ok(absf(gs.player().hp - gs.REVIVE_HP) < 3.0 and me.watching == 0 and not host_body.watched, "raised, back in our own eyes"): return
	if not await _until(func() -> bool: return gs.is_down(host_peer), "the host to go down"): return
	me.global_position = gs.REPAIR_POS + Vector3(0, 0, -0.9)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout  # our pose reaches the host
	if not _ok(gs.request_revive(host_peer), "we raise the host"): return
	if not await _until(func() -> bool: return not gs.is_down(host_peer), "the host up"): return
	if not await _until(func() -> bool: return gs.is_down() and gs.is_down(host_peer), "both down"): return
	if not await _until(func() -> bool: return _all_down == 1, "all_down here"): return
	if not await _until(func() -> bool: return not gs.is_down() and gs.player().hp == gs.HP_MAX, "up again"): return
	var f := FileAccess.open(SEEN, FileAccess.WRITE)
	f.store_string(JSON.stringify({"all_down": _all_down, "vault": gs.vault}))
	f.close()
	_log.append("down_check client OK")
	_write_log()
	quit()


## A round straight to the host, past our own guard, as a cheat would.
func _raw_fire() -> void:
	gs._sent_seq += 1
	gs._request.rpc_id(1, &"request_fire", [me.global_position + Vector3.UP * gs.EYE, Vector3.RIGHT], gs._sent_seq)


func _until(cond: Callable, what: String, secs := 60.0) -> bool:
	var t0 := Time.get_ticks_msec()
	if not cond.call():
		_write_log(what)
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
		_write_log()
	return cond


func _fail(what: String) -> void:
	_log.append("down_check FAIL: " + what)
	_stop_client()
	printerr("down_check FAIL: ", what)
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
