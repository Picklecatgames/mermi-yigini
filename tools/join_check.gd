extends SceneTree
## Headless check for joining mid-game and coming back (yol haritası 8), two processes:
##   Godot.exe --headless --path . -s res://tools/join_check.gd
## Before anyone joins, the host changes the world: digs the heap, takes a loose bullet, throws
## three, takes a key, claws the railing and fills the vault. The client joins and must see all of
## it: the same heights, that bullet gone, the thrown ones there, the key taken, the railing and the
## vault as the host has them. Then it grabs bullets, leaves, joins again and must have them back in hand.

const PORT := 24692  # not Net.PORT or net_check's
const LOG := "user://join_check_client.log"
const ENGINE_LOG := "user://join_check_client_engine.log"  # the client's engine output: script errors, a crash
const WORLD := "user://join_check_client.json"
const LOOSE := 7  # a starting spill bullet the host takes
const CLAWED := 30  # railing points the host loses before anyone joins: 10 off three bays, one torn down
const VAULT := 200.0

var gs: Node
var net: Node
var main: Node
var _log: Array[String] = []
var _client_pid := 0  # host: the client's process, till it has gone and passed


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
	var pile: Node = main.get_node("Pile")
	var top: Vector3 = pile.global_position
	top.y = pile.surface_y(top)
	gs.request_take_bullets(6000, top + Vector3(0.8, 0, 0.4))
	if not _ok(gs.request_pick_up_loose(LOOSE) == 1, "host takes loose bullet %d" % LOOSE): return
	for i in 3:  # one at a time: the hand starts at one bullet
		# A grab that comes out a special round (GameState._roll_specials) goes in the pocket: again.
		for n in 5:
			if gs.carried == 1:
				break
			if not _ok(gs.request_pick_up(top, 1) == 1, "host grabs one from the heap"): return
		if not _ok(gs.request_throw(top + Vector3(0, 1.5, 3.0), Vector3(0, 0.3, 1).normalized()) == 1, "host throws it"): return
	var keys: Node = main.get_node("Keys")
	if not _ok(gs.request_reveal_key(1, keys._pos[1]) and gs.request_take_key(1), "host takes key 1"): return
	gs.hurt_fence(10, -5.0)
	gs.hurt_fence(10, 0.0)
	gs.hurt_fence(10, 5.0)
	gs.vault = VAULT
	if not await _until(func() -> bool: return not pile._any_active and pile._digs.is_empty() and pile._awake.is_empty(), "the host's heap and throw to settle"): return

	var f := FileAccess.open(WORLD, FileAccess.WRITE)  # the heap the joiner must end up with
	f.store_string(JSON.stringify({"heights": Marshalls.raw_to_base64(pile._h.to_byte_array()), "surface_gone": pile._surface_removed.size()}))
	f.close()
	_client_pid = _start_client("res://tools/join_check.gd")
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(_client_pid):
		if Time.get_ticks_msec() - t0 > 120_000:
			return _fail("client timed out")  # its log's last line is the last check it passed
		await process_frame
	if OS.get_process_exit_code(_client_pid) != 0:
		return _fail("client side failed")
	_client_pid = 0
	print(FileAccess.get_file_as_string(LOG))
	if not _ok(gs._saved.size() == 1 and gs._token_of.is_empty(), "the client's state waits under its token"): return
	print("join_check OK")
	quit()


func _client() -> void:
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client and gs.synced() and gs._sent_seq > 0, "connect and hello"): return
	var pile: Node = main.get_node("Pile")
	var keys: Node = main.get_node("Keys")
	if not await _until(func() -> bool: return gs.key_states.get(1) == gs.KeyState.TAKEN, "key 1 taken"): return
	if not _ok(not keys._shown.has(1), "key 1 is not lying on the heap"): return
	if not _ok(not pile._id_index.has(LOOSE) and gs._taken_loose.has(LOOSE), "loose bullet %d is gone" % LOOSE): return
	var thrown := [0, 1, 2].filter(func(n: int) -> bool: return pile.has_loose(gs.THROWN_ID_START + n)).size()
	if not _ok(thrown == 3, "the three thrown bullets lie here too (%d)" % thrown): return
	if not _ok(gs.fence == gs.FENCE_MAX - CLAWED and gs.fence_bays.count(gs.BAY_HP - 10) == 3,
			"the railing is clawed down here too (%d)" % gs.fence): return
	if not _ok(is_equal_approx(gs.vault, VAULT), "the vault holds what the host's does ($%d)" % gs.vault): return
	if not await _until(func() -> bool: return not pile._any_active and pile._digs.is_empty(), "the heap to settle"): return
	var host: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORLD))
	var h: PackedFloat32Array = Marshalls.base64_to_raw(host.heights).to_float32_array()
	var worst := 0.0
	for k in h.size():
		worst = maxf(worst, absf(h[k] - pile._h[k]))
	_log.append("heap on join: largest difference %.6f m" % worst)
	if not _ok(worst < 1e-6, "our heap has the host's heights"): return
	if not _ok(int(host.surface_gone) == pile._surface_removed.size(), "the same surface bullets picked off (%d, host %d)" % [pile._surface_removed.size(), host.surface_gone]): return

	# Leave with a bullet in hand and the gun (the Scorpion) loaded, come back, have all three again.
	gs.request_select_gun(4)
	var top: Vector3 = pile.global_position + Vector3(-1.0, 0, -0.5)
	top.y = pile.surface_y(top)
	if not await _grab(top): return
	if not await _until(func() -> bool: return gs.synced() and gs.carried == 1, "a bullet in hand"): return
	gs.request_reload()
	if not await _grab(top): return
	if not await _until(func() -> bool: return gs.synced() and gs.carried == 1 and gs.loaded == 1, "one loaded, one in hand"): return
	net.leave()
	if not await _until(func() -> bool: return not net.online, "leave"): return
	await create_timer(0.5).timeout
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client and gs.synced() and gs.carried == 1 and gs.loaded == 1 and gs.player().gun == 4, "the same hand and gun back after rejoining"): return
	_log.append("client OK: rejoined with %d in hand, %d loaded, gun %d" % [gs.carried, gs.loaded, gs.player().gun])
	_write_log()
	quit()


## Client: one bullet off the heap at `at` into the hand. About 1 in 75 grabs is a special round
## (GameState._roll_specials): the host puts that in the pocket, not the hand, and we grab again.
func _grab(at: Vector3) -> bool:
	for n in 5:
		var hand: int = gs.carried
		var pocket: int = gs.player().specials.size()
		gs.request_pick_up(at, 1)
		if not await _until(gs.synced, "the answer to a heap grab"): return false
		if gs.carried > hand:
			return true
		if not _ok(gs.player().specials.size() == pocket + 1, "the grab the host took back is in our pocket (%s)" % [gs.player().specials]): return false
		_log.append("a heap grab came out a special round: %s" % gs.player().specials.back())
	return _ok(false, "five heap grabs in a row came out special rounds")


func _until(cond: Callable, what: String, secs := 30.0) -> bool:
	var t0 := Time.get_ticks_msec()
	if not cond.call():
		_write_log(what)
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			_fail("timed out waiting for " + what)
			return false
		await process_frame
	return true


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fail(what)
	elif "--client" in OS.get_cmdline_user_args():
		_log.append("ok: " + what)
		_write_log()  # a script error stops the client without quitting: the host shows how far it got
	return cond


func _fail(what: String) -> void:
	_log.append("join_check FAIL: " + what)
	_stop_client()
	printerr("join_check FAIL: ", what)
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
