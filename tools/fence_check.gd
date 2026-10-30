extends SceneTree
## Headless check of the railing's life (GameState.fence, scripts/fence.gd, waves.gd, hud.gd), host
## and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/fence_check.gd --quit-after 100000
## Alone: claws wear the bay they land on, the posts there lean and the rails bow, clawed through
## the bay comes down; the desk mends it for gold, as far as the gold goes, and only within reach
## (E at the desk, its hint and price). A wave with the railing nearly gone: the next claw loses it,
## the dead turn back, the screen goes dark with "ÇİT YIKILDI", then the same wave waits with the
## railing patched up and nobody left. Online: a joiner gets the railing as it is, every claw reaches
## it bay by bay, its repair at the desk is paid from the vault on the host, and a wave lost on the
## host is lost on the client at the same moment, patched the same.

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
	if not _ok(gs.fence == gs.FENCE_MAX and gs.fence_wear.size() == gs.FENCE_BAYS and _wear_sum() == 0, "the railing starts whole"): return
	if not _ok(fence._posts.size() == gs.FENCE_BAYS + 1 and fence._halves.size() == gs.FENCE_BAYS, "the railing's posts and bays found (%d posts)" % fence._posts.size()): return
	# Claws on one bay: that bay alone wears, its posts lean back over our side.
	var bay_z := _bay_z(12)
	gs.hurt_fence(3, bay_z)
	gs.hurt_fence(2, bay_z)
	if not _ok(gs.fence == gs.FENCE_MAX - 5 and gs.fence_wear[12] == 5 and _wear_sum() == 5, "two claws took 5 off bay 12 (%s)" % [gs.fence_wear]): return
	await create_timer(1.0).timeout
	var post: MeshInstance3D = fence._posts[12]
	var tilt := post.transform.basis.y.x
	if not _ok(tilt < -0.1 and fence._posts[5].transform.basis.y.is_equal_approx(Vector3.UP), "its post leans back (%.2f), one far off stands" % tilt): return
	var mid: Vector3 = fence._halves[12][0][0].transform.origin
	if not _ok(mid.x < fence._x - 0.02, "its top rail bows in towards us"): return
	if not _ok(hud._fence_hp.text == str(gs.fence) and absf(hud._fence_bar.get_meta("fill") - 0.95) < 0.01, "the HUD says %s" % hud._fence_hp.text): return
	# Clawed through: the bay comes down, the top rail snapped, half of it on the floor.
	gs.hurt_fence(20, bay_z)
	await create_timer(1.0).timeout
	var lying: Vector3 = fence._halves[12][0][1].transform.origin
	if not _ok(fence._shown[12] == 1.0 and lying.y < 0.1 and lying.x < fence._x - 0.3, "bay 12 torn down, half its top rail on the floor"): return
	# The desk: out of reach nothing, then as far as the gold goes.
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	gs.player().gold = 1000
	if not _ok(gs.request_repair_fence() == 0 and gs.fence == 75, "no mending from across the hall"): return
	me.global_position = gs.REPAIR_POS + Vector3(1.4, 0, 0)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	gs.player().gold = 30
	var got: int = gs.request_repair_fence()
	if not _ok(got == 10 and gs.fence == 85 and gs.gold == 0, "$30 mends 10 points (%d, %d, $%d)" % [got, gs.fence, gs.gold]): return
	if not _ok(gs.fence_wear[12] == 15 and _wear_sum() == 15, "off the worst bay first"): return
	# E at the desk with the pistol taken: the hint and its price, then the mend.
	gs.request_take_pistol()
	var table: Node3D = get_first_node_in_group("gun_table")
	var d: Vector3 = table.global_position + Vector3.UP * 0.8 - me._camera.global_position
	me._yaw = atan2(-d.x, -d.z)
	me._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 3:
		await physics_frame
	gs.player().gold = 1000
	var price: int = gs.fence_repair_price()
	if not await _until(func() -> bool: return me._repair_hint.visible, "the repair hint (the draw first)", 5.0): return
	await process_frame
	if not _ok(me._repair_hint.visible and not me._table_hint.visible and (me._repair_hint.get_child(1) as Label).text.ends_with("$%d" % price),
			"looking at the desk: \"%s\"" % (me._repair_hint.get_child(1) as Label).text): return
	var e := InputEventAction.new()
	e.action = "pick_up"
	e.pressed = true
	me._unhandled_input(e)
	if not _ok(gs.fence == gs.FENCE_MAX and gs.gold == 1000 - price and _wear_sum() == 0, "E mends it all for $%d" % price): return
	await process_frame
	if not _ok(not me._repair_hint.visible and gs.request_repair_fence() == 0, "whole: no hint, nothing to pay"): return
	await create_timer(1.5).timeout
	if not _ok(fence._posts[12].transform.basis.y.is_equal_approx(Vector3.UP) and fence._shown[12] == 0.0, "the bay stands straight again"): return
	# A wave with the railing all but gone: the next claw loses it.
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	Engine.time_scale = TIME_SCALE
	gs.hurt_fence(gs.FENCE_MAX - 2, 0.0)
	gs.request_pull_lever()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FAILED, "the railing to fall", 120.0): return
	if not _ok(gs.fence == 0 and waves._status.text == "ÇİT YIKILDI" and hud._lost.visible, "it fell: the sign and the screen say so"): return
	await create_timer(0.3).timeout
	var back: Array = waves._zombies.values().filter(func(z: Dictionary) -> bool: return not z.dead and not z.path.is_empty() and z.path[-1] == z.mouth)
	if not _ok(back.size() > 0, "the dead turn back for the pens (%d)" % back.size()): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY, "the lost wave to wait again"): return
	await process_frame
	if not _ok(waves.wave == 1 and gs.fence == gs.FENCE_PATCH and waves._zombies.is_empty(), "wave 1 again, patched up to %d, nobody left" % gs.fence): return
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
	# Claws while it's here, then it mends the railing at its desk.
	await create_timer(1.5).timeout
	for i in 5:
		gs.hurt_fence(1, _bay_z(9))
		await create_timer(0.05).timeout
	if not await _until(func() -> bool: return gs.fence == gs.FENCE_MAX, "the client's repair", 30.0): return
	if not _ok(is_equal_approx(gs.vault, 1000.0 - 16 * gs.FENCE_REPAIR_COST) and _wear_sum() == 0, "paid from the vault ($%d left)" % gs.vault): return
	# A wave lost here is lost there.
	var me: Node3D = main.get_node("Player")
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout
	gs.hurt_fence(gs.FENCE_MAX - 1, 5.0)
	gs.request_pull_lever()
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FIGHT, "the fight"): return
	var z: Dictionary = waves._zombies.values()[0]
	waves._bite(z)  # the claw that does it, now
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY and gs.fence == gs.FENCE_PATCH, "the lost wave to wait again"): return
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() - t0 > 120_000:
			OS.kill(pid)
			return _fail("client timed out")
		await process_frame
	print(FileAccess.get_file_as_string(LOG))
	if OS.get_process_exit_code(pid) != 0:
		return _fail("client side failed")
	var seen = JSON.parse_string(FileAccess.get_file_as_string(SEEN))
	if not _ok(seen is Dictionary and absf(seen.failed_at - failed_at[0]) < 0.5, "the client lost it at the same moment (%.2f s apart)" % absf(seen.get("failed_at", 0.0) - failed_at[0])): return
	var theirs: Array = (seen.wear as Array).map(func(w: float) -> int: return int(w))  # JSON reads numbers as floats
	if not _ok(theirs == Array(gs.fence_wear) and int(seen.fence) == gs.fence, "the same railing on both machines (%s)" % [seen.wear]): return
	print("fence_check OK")
	quit()


func _client() -> void:
	var me: Node3D = main.get_node("Player")
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client and gs.fence == gs.FENCE_MAX - 11, "the host's railing on joining"): return
	if not _ok(gs.fence_wear[3] == 7 and gs.fence_wear[17] == 4, "worn where the host's was (%s)" % [gs.fence_wear]): return
	await create_timer(0.5).timeout
	if not _ok(fence._shown[3] > 0.5 and fence._shown[9] == 0.0 and hud._fence_hp.text == str(gs.fence), "shown worn here too, HUD %s" % hud._fence_hp.text): return
	if not await _until(func() -> bool: return gs.fence == gs.FENCE_MAX - 16 and gs.fence_wear[9] == 5, "the claws on bay 9"): return
	me.global_position = gs.REPAIR_POS + Vector3(1.4, 0, 0)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout  # our pose reaches the host
	if not _ok(gs.request_repair_fence() == 16, "we ask to mend 16 points"): return
	if not await _until(func() -> bool: return gs.fence == gs.FENCE_MAX and is_equal_approx(gs.vault, 1000.0 - 16 * gs.FENCE_REPAIR_COST), "the host's mend"): return
	var seen := {}
	gs.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"phase" and cue[2] == waves.Phase.FAILED:
			seen.failed_at = Time.get_unix_time_from_system())
	if not await _until(func() -> bool: return waves.phase == waves.Phase.FAILED, "the host's wave to be lost", 60.0): return
	if not _ok(gs.fence == 0 and hud._lost.visible and waves._status.text == "ÇİT YIKILDI", "lost here too: the sign and the screen"): return
	if not await _until(func() -> bool: return waves.phase == waves.Phase.READY, "the same wave to wait again"): return
	await process_frame
	if not _ok(waves.wave == 1 and gs.fence == gs.FENCE_PATCH and waves._zombies.is_empty(), "wave 1 again, patched, nobody left"): return
	seen.fence = gs.fence
	seen.wear = gs.fence_wear
	var f := FileAccess.open(SEEN, FileAccess.WRITE)
	f.store_string(JSON.stringify(seen))
	f.close()
	_log.append("fence_check client OK")
	_write_log()
	quit()


func _wear_sum() -> int:
	var n := 0
	for w: int in gs.fence_wear:
		n += w
	return n


## The middle of bay `b` along the railing.
func _bay_z(b: int) -> float:
	return -gs.FENCE_SPAN + (b + 0.5) * gs.FENCE_SPAN * 2.0 / gs.FENCE_BAYS


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
