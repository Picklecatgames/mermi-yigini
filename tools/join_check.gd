extends SceneTree
## Headless check for joining mid-game and coming back (yol haritası 8), two processes:
##   Godot.exe --headless --path . -s res://tools/join_check.gd
## Before anyone joins, the host changes the world: digs the heap, takes a loose bullet, throws
## three, takes a key and knocks the popper over. The client joins and must see all of it: the
## same heights, that bullet gone, the thrown ones there, the key taken, the popper down. Then it
## grabs bullets, leaves, joins again and must have them back in hand.

const PORT := 24692  # not Net.PORT or net_check's
const LOG := "user://join_check_client.log"
const WORLD := "user://join_check_client.json"
const LOOSE := 7  # a starting spill bullet the host takes
const DUMMY_AT := Vector3(22, 0, 15)   # gear the host puts up before anyone joins
const POPPER_AT := Vector3(22, 0, 8)   # and the joiner puts up

var gs: Node
var net: Node
var main: Node
var _log: Array[String] = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.add_child(load("res://scenes/test_range.tscn").instantiate())  # the six fixed targets; the game starts with one dummy
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
		if i > 0 and not _ok(gs.request_pick_up(top, 1) == 1, "host grabs one from the heap"): return
		if not _ok(gs.request_throw(top + Vector3(0, 1.5, 3.0), Vector3(0, 0.3, 1).normalized()) == 1, "host throws it"): return
	var keys: Node = main.get_node("Keys")
	if not _ok(gs.request_reveal_key(1, keys._pos[1]) and gs.request_take_key(1), "host takes key 1"): return
	var popper: Node = main.get_node("LockedTargets/PopperNorth")
	popper._on_cue(popper, [&"down"])
	# Gear (yol haritası 10): buy a dummy and a popper, put the dummy up; the joiner places the popper.
	gs.vault = 200.0
	gs.quest_board.fill("")  # past the warmup: all the gear open
	if not _ok(gs.request_buy_gear("dummy") and gs.request_buy_gear("popper"), "host buys a dummy and a popper"): return
	if not _ok(not gs.request_place_gear("dummy", Vector3(10, 0, 15), -PI / 2), "no gear on the shooters' side"): return
	if not _ok(gs.request_place_gear("dummy", DUMMY_AT, -PI / 2), "host puts the dummy up"): return
	if not _ok(not gs.request_place_gear("popper", DUMMY_AT + Vector3(0.5, 0, 0), -PI / 2), "no gear on top of other gear"): return
	if not _ok(main.has_node("Placed/Gear_0") and main.get_node("Placed/Gear_0").is_in_group("target"), "the dummy stands, as a target"): return
	if not await _until(func() -> bool: return not pile._any_active and pile._digs.is_empty() and pile._awake.is_empty(), "the host's heap and throw to settle"): return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	var f := FileAccess.open(WORLD, FileAccess.WRITE)  # the heap the joiner must end up with
	f.store_string(JSON.stringify({"heights": Marshalls.raw_to_base64(pile._h.to_byte_array()), "surface_gone": pile._surface_removed.size()}))
	f.close()
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "-s", "res://tools/join_check.gd", "--", "--client"])
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() - t0 > 120_000:
			OS.kill(pid)
			return _fail("client timed out")
		await process_frame
	print(FileAccess.get_file_as_string(LOG))
	if OS.get_process_exit_code(pid) != 0:
		return _fail("client side failed")
	if not _ok(gs._saved.size() == 1 and gs._token_of.is_empty(), "the client's state waits under its token"): return
	var put: Node3D = main.get_node_or_null("Placed/Gear_1")
	if not _ok(put != null and put.global_position.distance_to(POPPER_AT) < 0.01 and gs.gear_stock.popper == 0, "the client's popper stands here too, out of the stock"): return
	print("join_check OK")
	quit()


func _client() -> void:
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client and gs.synced() and gs._sent_seq > 0, "connect and hello"): return
	var pile: Node = main.get_node("Pile")
	var keys: Node = main.get_node("Keys")
	var popper: Node = main.get_node("LockedTargets/PopperNorth")
	if not await _until(func() -> bool: return gs.key_states.get(1) == gs.KeyState.TAKEN, "key 1 taken"): return
	if not _ok(not keys._shown.has(1), "key 1 is not lying on the heap"): return
	if not _ok(not pile._id_index.has(LOOSE) and gs._taken_loose.has(LOOSE), "loose bullet %d is gone" % LOOSE): return
	var thrown: int = pile._spill_id.count(gs.THROWN_ID_START) + pile._spill_id.count(gs.THROWN_ID_START + 1) + pile._spill_id.count(gs.THROWN_ID_START + 2)
	if not _ok(thrown == 3, "the three thrown bullets lie here too (%d)" % thrown): return
	if not _ok(popper.is_down(), "the popper is down"): return
	if not await _until(func() -> bool: return main.has_node("Placed/Gear_0"), "the host's placed dummy"): return
	if not _ok((main.get_node("Placed/Gear_0") as Node3D).global_position.distance_to(DUMMY_AT) < 0.01 and gs.gear_stock.get("popper") == 1, "the dummy stands where the host put it; a popper in stock"): return
	if not _ok(gs.request_place_gear("popper", POPPER_AT, -PI / 2), "we ask to put the popper up"): return
	if not await _until(func() -> bool: return main.has_node("Placed/Gear_1"), "our popper, once the host lets it up"): return
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
	gs.request_pick_up(top, 1)
	if not await _until(func() -> bool: return gs.synced() and gs.carried == 1, "a bullet in hand"): return
	gs.request_reload()
	gs.request_pick_up(top, 1)
	if not await _until(func() -> bool: return gs.synced() and gs.carried == 1 and gs.loaded == 1, "one loaded, one in hand"): return
	net.leave()
	if not await _until(func() -> bool: return not net.online, "leave"): return
	await create_timer(0.5).timeout
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client and gs.synced() and gs.carried == 1 and gs.loaded == 1 and gs.player().gun == 4, "the same hand and gun back after rejoining"): return
	_log.append("client OK: rejoined with %d in hand, %d loaded, gun %d" % [gs.carried, gs.loaded, gs.player().gun])
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
	_log.append("join_check FAIL: " + what)
	printerr("join_check FAIL: ", what)
	_write_log()
	quit(1)


func _write_log() -> void:
	if "--client" in OS.get_cmdline_user_args():
		var f := FileAccess.open(LOG, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_log))
