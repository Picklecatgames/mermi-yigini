extends SceneTree
## Headless co-op check for the flashlight, host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/torch_net_check.gd
## The client takes the flashlight out (F) through the host and both agree; a gun in hand puts it away
## and back (one or the other); the host's flicker and blackout reach the client with the same seed,
## and the budget holds (a second blackout at once is refused); the client's own lamp_flicker_rolls
## refuse (host only); the client skips the time and both clocks follow. Then the client leaves with
## the flashlight in hand and a second one with the same token joins: it gets the flashlight back, on
## the host and on its own machine (the rejoin used to leave it unannounced).

const PORT := 24697
const LOG := "user://torch_net_check_%s.json"
const ENGINE_LOG := "user://torch_net_check_%s_engine.log"
const GUN := 3  # needs test mode (T), which the client turns on

var gs: Node
var net: Node
var main: Node
var _pid := 0
var _who := "a"


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	for i in 3:
		await process_frame
	var args := OS.get_cmdline_user_args()
	if "--client" in args:
		_who = "b" if "--second" in args else "a"
		if _who == "b":
			await _client_second()
		else:
			await _client()
	else:
		await _host()


func _host() -> void:
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	var cid := [0]
	gs.multiplayer.peer_connected.connect(func(id: int) -> void: cid[0] = id)
	var torch_log := []
	gs.torch_changed.connect(func(p: int, on: bool) -> void: torch_log.append([p, on]))
	var rolls: Node = gs.lamp_flicker_rolls
	var sent := {}
	gs.lamp_flicker.connect(func(_p: int, s: int) -> void: sent["flicker"] = s)
	gs.torch_blackout.connect(func(_p: int, s: int, c: bool) -> void: sent["blackout"] = [s, c])
	_pid = _spawn("a")
	var t0 := Time.get_ticks_msec()
	# The client takes the flashlight out; the host's word for it.
	if not await _wait(func() -> bool: return cid[0] != 0 and gs.player(cid[0]).torch, t0, 90_000):
		return _fail("the client's flashlight never came out on the host")
	print("host: client %d has the flashlight" % cid[0])
	# A gun puts it away, the flashlight again puts the gun away.
	if not await _wait(func() -> bool: return gs.player(cid[0]).gun == GUN and not gs.player(cid[0]).torch, t0, 30_000):
		return _fail("a gun in hand did not put the flashlight away on the host")
	if not await _wait(func() -> bool: return gs.player(cid[0]).gun == 0 and gs.player(cid[0]).torch, t0, 30_000):
		return _fail("the flashlight did not put the gun away on the host")
	print("host: gun and flashlight swapped both ways")
	# Flicker and blackout for the client's lamp; the budget refuses a second blackout.
	rolls.now += 100.0
	if not _ok(rolls.try_flicker(cid[0], true), "the host's flicker goes"): return
	if not _ok(rolls.try_blackout(cid[0], 0), "the host's blackout goes"): return
	if not _ok(not rolls.try_blackout(cid[0], 0), "a second blackout at once is refused"): return
	if not _ok(not rolls.try_flicker(cid[0], true), "no flicker over the dead lamp"): return
	while OS.is_process_running(_pid):
		if Time.get_ticks_msec() - t0 > 150_000:
			return _fail("the client timed out")
		await process_frame
	var code := OS.get_process_exit_code(_pid)
	_pid = 0
	if not _ok(code == 0, "the client passed (exit %d)" % code): return
	var theirs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOG % "a"))
	if not _ok(int(theirs.get("flicker", -1)) == sent.get("flicker", -2), "the flicker seed is the same on both"): return
	var bl: Array = theirs.get("blackout", [])
	if not _ok(bl.size() == 2 and int(bl[0]) == sent.blackout[0] and bl[1] == sent.blackout[1], "the blackout seed and creature flag are the same on both"): return
	if not _ok(theirs.get("client_refused", false), "the client's own flicker/blackout rolls refuse"): return
	if not _ok(absf(float(theirs.get("hour_after", -1.0)) - gs.hour) < 1.0 or theirs.get("hour_moved", false), "the client's time skip reached it"): return
	# Gone with the flashlight in hand; a second one with the same token comes in.
	await _wait(func() -> bool: return not gs.slots.has(cid[0]), Time.get_ticks_msec(), 20_000)
	if not _ok(not gs.slots.has(cid[0]), "the host dropped the leaver"): return
	torch_log.clear()
	var second_t0 := Time.get_ticks_msec()
	_pid = _spawn("b")
	while OS.is_process_running(_pid):
		if Time.get_ticks_msec() - second_t0 > 90_000:
			return _fail("the rejoiner timed out")
		await process_frame
	code = OS.get_process_exit_code(_pid)
	_pid = 0
	if not _ok(code == 0, "the rejoiner passed (exit %d), the flashlight came back to its own machine" % code): return
	if not _ok(torch_log.any(func(e: Array) -> bool: return e[1]), "the host announced the returned flashlight"): return
	print("torch_net_check OK")
	quit()


func _spawn(who: String) -> int:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG % who))
	var a := ["--headless", "--log-file", ProjectSettings.globalize_path(ENGINE_LOG % who), "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tools/torch_net_check.gd", "--", "--client"]
	if who == "b":
		a.append("--second")
	return OS.create_process(OS.get_executable_path(), a)


func _client() -> void:
	var out := {}
	gs.lamp_flicker.connect(func(_p: int, s: int) -> void: out["flicker"] = s)
	gs.torch_blackout.connect(func(_p: int, s: int, c: bool) -> void: out["blackout"] = [s, c])
	var hours := []
	gs.clock_changed.connect(func(h: float, _r: float) -> void: hours.append(h))
	net.join("127.0.0.1", PORT)
	var t0 := Time.get_ticks_msec()
	if not await _wait(func() -> bool: return net.is_client and gs.slots.has(gs.local_peer()), t0, 60_000):
		return _client_end(out, 1)
	await create_timer(0.5).timeout
	gs.request_toggle_infinite_ammo()
	await create_timer(0.5).timeout
	gs.request_toggle_torch()
	if not await _wait(func() -> bool: return gs.player().torch, t0, 20_000):
		print("client: flashlight never came out")
		return _client_end(out, 1)
	gs.request_select_gun(GUN)
	if not await _wait(func() -> bool: return gs.player().gun == GUN and not gs.player().torch, t0, 20_000):
		print("client: gun did not put the flashlight away: gun %d torch %s" % [gs.player().gun, gs.player().torch])
		return _client_end(out, 1)
	gs.request_toggle_torch()
	if not await _wait(func() -> bool: return gs.player().gun == 0 and gs.player().torch, t0, 20_000):
		print("client: flashlight did not put the gun away: gun %d torch %s" % [gs.player().gun, gs.player().torch])
		return _client_end(out, 1)
	if not await _wait(func() -> bool: return out.has("flicker") and out.has("blackout"), t0, 30_000):
		print("client: never got the flicker/blackout: %s" % [out])
		return _client_end(out, 1)
	var rolls: Node = gs.lamp_flicker_rolls
	out["client_refused"] = not rolls.try_flicker(gs.local_peer(), true) and not rolls.try_blackout(gs.local_peer(), 0)
	var before: float = gs.hour
	hours.clear()
	gs.request_skip_time()
	await _wait(func() -> bool: return not hours.is_empty(), t0, 20_000)
	out["hour_moved"] = not hours.is_empty()
	out["hour_after"] = gs.hour
	print("client: hour %.2f -> %.2f" % [before, gs.hour])
	_client_end(out, 0)


func _client_end(out: Dictionary, code: int) -> void:
	var f := FileAccess.open(LOG % "a", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	quit(code)


## The second one: same token, so the host gives it the first one's state back.
func _client_second() -> void:
	net.join("127.0.0.1", PORT)
	var t0 := Time.get_ticks_msec()
	var ok := await _wait(func() -> bool: return net.is_client and gs.player().torch, t0, 60_000)
	print("client b: flashlight back = %s" % ok)
	quit(0 if ok else 1)


func _wait(cond: Callable, since: int, limit: int) -> bool:
	var t := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t > limit:
			return false
		await process_frame
	return true


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fail(what)
	return cond


func _fail(what: String) -> void:
	if _pid != 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
		for w in ["a", "b"]:
			var p: String = ENGINE_LOG % w
			if FileAccess.file_exists(p):
				print("--- client %s engine output, last lines:\n" % w, "\n".join(FileAccess.get_file_as_string(p).split("\n").slice(-20)))
	printerr("torch_net_check FAIL: ", what)
	quit(1)
