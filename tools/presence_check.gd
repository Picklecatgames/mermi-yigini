extends SceneTree
## Headless check for what is heard in the wood (scripts/forest_presence.gd):
##   Godot.exe --headless --path . -s res://tools/presence_check.gd
## Offline: DAYS whole days and nights of the host's clock at the wood's edge, in the open middle and
## inside the wood: rarer by day and in the middle, never the same kind twice running, never sooner
## than MIN_GAP, within the caps a night and a day, nothing that needs the night by day. The steps that follow ours: one for each
## of ours a beat behind, one more after we stop, a single one if we never walk; the hush dips the
## beds and holds the night's events. Then co-op (this script again with `-- --client`): an event the
## host picks for the client reaches the client alone, and the host's own stays on the host.

const PORT := 24693
const LOG := "user://presence_check_client.json"
const ENGINE_LOG := "user://presence_check_client_engine.log"
const DAYS := 30
const DT := 0.5

var gs: Node
var net: Node
var main: Node
var fp: Node
var _client_pid := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	for i in 3:
		await process_frame
	fp = main.get_node("Ambience/ForestPresence")
	fp.set_process(false)  # the check drives it
	if "--client" in OS.get_cmdline_user_args():
		await _client()
	else:
		await _host()


func _host() -> void:
	if not _ok(fp != null, "Ambience/ForestPresence is there"): return
	for k: String in ["steps", "rustle", "echo"]:
		print("%s: %d clips" % [k, fp.clips[k].size()])
		if not _ok(fp.clips[k].size() > 0, "%s has clips" % k): return
	print("kinds: %s" % [fp.kinds_available()])
	# --- when and what -------------------------------------------------------------------
	fp._rng.seed = 7
	var c: Vector2 = fp.CLEARING_CENTRE
	var places := {
		"middle": Vector3(c.x, 0, c.y),
		"edge": Vector3(c.x + fp.CLEARING_RADII.x - 3.0, 0, c.y),
		"wood": Vector3(c.x + fp.CLEARING_RADII.x + 15.0, 0, c.y),
	}
	# Whole days on the game's clock (GameState.DAY_SECONDS, night_of): per night and per day.
	var counts := {}
	var peer := 100  # not anyone's: presence_to sends it nowhere
	var day_s: float = gs.DAY_SECONDS
	for place: String in places:
		var at: Vector3 = places[place]
		var got: Array = []  # [time, kind, night, scare]
		var t := 0.0
		while t < DAYS * day_s:
			t += DT
			var dark: float = gs.night_of(fmod(gs.START_HOUR + t / day_s * 24.0, 24.0))
			var cue: Dictionary = fp.tick(peer, at, 0.0, dark, DT)
			if not cue.is_empty():
				got.append([t, cue.kind, dark > 0.5, fp.is_scare(cue)])
		var gaps: Array = []
		for i in range(1, got.size()):
			gaps.append(got[i][0] - got[i - 1][0])
			if not _ok(got[i][1] != got[i - 1][1], "%s: never the same twice running (%s at %.0f s)" % [place, got[i][1], got[i][0]]): return
		var shortest: float = gaps.min() if not gaps.is_empty() else INF
		# Per night and per day: a period is a run of the same darkness.
		var nights := {}
		var days := {}
		var scares := {}
		var kinds := {}
		for g: Array in got:
			var h := fmod(gs.START_HOUR + g[0] / day_s * 24.0, 24.0)
			var n := int(floor((g[0] / day_s * 24.0 + gs.START_HOUR - 12.0) / 24.0))  # a night runs over midnight
			var d := int(floor((g[0] / day_s * 24.0 + gs.START_HOUR) / 24.0))
			if g[2]:
				nights[n] = nights.get(n, 0) + 1
				scares[n] = scares.get(n, 0) + int(g[3])
			else:
				if not _ok(not g[1] in ["hush", "breath", "whisper"] and not g[3], "%s: nothing of the night's by day (%s at %.1f h)" % [place, g[1], h]): return
				days[d] = days.get(d, 0) + 1
			kinds[g[1]] = kinds.get(g[1], 0) + 1
		var n_night := 0
		var n_day := 0
		for v: int in nights.values():
			n_night += v
		for v: int in days.values():
			n_day += v
		counts[place] = [float(n_night) / DAYS, float(n_day) / DAYS]
		print("%-7s a night %.2f (most %d), a day %.2f (most %d), close ones a night most %d, shortest gap %3.0f s, first at %4.0f s  %s" % [place,
			counts[place][0], nights.values().max() if not nights.is_empty() else 0, counts[place][1], days.values().max() if not days.is_empty() else 0,
			scares.values().max() if not scares.is_empty() else 0, shortest, got[0][0] if not got.is_empty() else -1.0, kinds])
		if not _ok(got.is_empty() or got[0][0] >= fp.FIRST_GAP, "%s: nothing on arrival" % place): return
		if not _ok(shortest >= fp.MIN_GAP - DT, "%s: never sooner than MIN_GAP" % place): return
		if not _ok(nights.values().all(func(v: int) -> bool: return v <= fp.NIGHT_CAP), "%s: at most NIGHT_CAP a night" % place): return
		if not _ok(days.values().all(func(v: int) -> bool: return v <= fp.DAY_CAP), "%s: at most DAY_CAP a day" % place): return
		if not _ok(scares.values().all(func(v: int) -> bool: return v <= fp.SCARE_CAP), "%s: at most SCARE_CAP close ones a night" % place): return
		print("  tension after: %.2f" % fp.presence_tension(peer))
		peer += 1
	if not _ok(counts.edge[0] > 3.0 * counts.middle[0], "the edge of the wood far busier than the open middle"): return
	if not _ok(counts.wood[0] >= counts.edge[0], "inside the wood at least as busy as its edge"): return
	if not _ok(counts.edge[0] > 4.0 * counts.edge[1], "the night far busier than the day"): return
	if not _ok(counts.edge[0] <= fp.NIGHT_CAP and counts.edge[0] >= 1.0, "a typical night at the edge: a few, not none"): return
	# Placement: out of sight among the trees, never past FARTHEST.
	for i in 200:
		var cue: Dictionary = fp.pick(999, places.edge, 0.0, 1.0)
		if cue.has("at"):
			var at: Vector3 = cue.at
			var away := Vector2(at.x - places.edge.x, at.z - places.edge.z)
			if not _ok(away.length() <= fp.FARTHEST + 0.01, "%s within %d m (%.1f)" % [cue.kind, fp.FARTHEST, away.length()]): return
			if not _ok(away.normalized().dot(Vector2(0, -1)) < 0.35, "%s not in front of us (yaw 0 looks down -Z)" % cue.kind): return
		if cue.kind == "steps":
			if not _ok(absf(wrapf(cue.angle - PI, -PI, PI)) <= 1.1 + 1e-4, "steps behind or beside"): return
	# --- the steps that follow ours -------------------------------------------------------
	var cue := {"kind": "steps", "angle": PI, "dist": 8.0, "count": 5, "lag": 0.2, "db": -28.0, "pitch": 0.85, "clips": [0, 1, 2], "late": true}
	fp.play(cue)
	var n0: int = fp.shadow_steps
	var times: Array = []
	for i in 3:  # we take three steps, half a second apart, and stop
		fp.on_step()
		times.append(fp._t)
		for f in 10:
			fp._play_shadow(0.05)
	var answered: int = fp.shadow_steps - n0
	for f in 60:
		fp._play_shadow(0.05)
	print("steps: ours 3, its %d while we walked, %d all told" % [answered, fp.shadow_steps - n0])
	if not _ok(answered == 3, "one of its for each of ours, a beat behind"): return
	if not _ok(fp.shadow_steps - n0 == 4 and fp._shadow.is_empty(), "one more after we stopped, then still"): return
	fp.play(cue.merged({"count": 2}, true))
	n0 = fp.shadow_steps
	for i in 5:
		fp.on_step()
		for f in 10:
			fp._play_shadow(0.05)
	if not _ok(fp.shadow_steps - n0 == 2 and fp._shadow.is_empty(), "out of steps it stops first, before us"): return
	fp.play(cue)
	n0 = fp.shadow_steps
	for f in int((fp.STEP_WAIT + 1.0) / 0.05):
		fp._play_shadow(0.05)
	if not _ok(fp.shadow_steps - n0 == 1 and fp._shadow.is_empty(), "we never walked: a single step"): return
	# --- the hush -------------------------------------------------------------------------
	var amb: Node = main.get_node("Ambience")
	amb.night = true
	for f in 30:
		await process_frame
	fp.play({"kind": "hush", "down": 0.3, "hold": 0.6, "up": 0.3, "depth": -14.0})
	for ev in amb.events:
		ev.wait = 0.0
	await create_timer(0.5).timeout
	print("hush: beds at %.2f of their level" % amb.hush_gain())
	if not _ok(amb.hush_gain() < db_to_linear(-12.0), "the wood falls quiet"): return
	if not _ok(amb.events.all(func(ev: Dictionary) -> bool: return not ev.player.playing), "and nothing calls through it"): return
	await create_timer(1.0).timeout
	if not _ok(amb.hush_gain() == 1.0 and amb._hush.is_empty(), "then comes back"): return
	amb.night = false
	# --- co-op: to one player only --------------------------------------------------------
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	var mine: Array = []
	gs.presence_cue.connect(func(p: int, c2: Dictionary) -> void: mine.append([p, c2.kind]))
	var cid := [0]
	gs.multiplayer.peer_connected.connect(func(id: int) -> void: cid[0] = id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	_client_pid = OS.create_process(OS.get_executable_path(), ["--headless", "--log-file", ProjectSettings.globalize_path(ENGINE_LOG),
		"--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/presence_check.gd", "--", "--client"])
	var t0 := Time.get_ticks_msec()
	while cid[0] == 0 or not gs.player(cid[0]).has_pose:
		if Time.get_ticks_msec() - t0 > 90_000:
			return _fail("the client never came")
		await process_frame
	await create_timer(1.0).timeout
	var wood: Vector3 = places.wood
	fp._peers.erase(cid[0])
	fp._peers.erase(gs.local_peer())
	var to_them: Dictionary = {}
	while to_them.is_empty():  # its first is past FIRST_GAP: a long delta gets it there at once
		to_them = fp.tick(cid[0], wood, 0.0, 1.0, 1000.0)
	var to_us: Dictionary = {}
	while to_us.is_empty():
		to_us = fp.tick(gs.local_peer(), wood, 0.0, 1.0, 1000.0)
	print("host sent %s to the client (%d), %s to itself" % [to_them.kind, cid[0], to_us.kind])
	while OS.is_process_running(_client_pid):
		if Time.get_ticks_msec() - t0 > 150_000:
			return _fail("the client timed out")
		await process_frame
	var code := OS.get_process_exit_code(_client_pid)
	_client_pid = 0
	if not _ok(code == 0, "the client side passed (exit %d)" % code): return
	var theirs: Array = JSON.parse_string(FileAccess.get_file_as_string(LOG))
	print("client heard %s, host heard %s" % [theirs, mine])
	if not _ok(theirs.size() == 1 and int(theirs[0][0]) == cid[0] and theirs[0][1] == to_them.kind, "the client heard its own, only"): return
	if not _ok(mine.size() == 1 and mine[0] == [gs.local_peer(), to_us.kind], "the host heard its own, only"): return
	if not _ok(fp.presence_tension(cid[0]) > 0.0, "the client's tension rose on the host"): return
	print("presence_check OK")
	quit()


func _client() -> void:
	var heard: Array = []
	gs.presence_cue.connect(func(p: int, c: Dictionary) -> void: heard.append([p, c.kind]))
	net.join("127.0.0.1", PORT)
	var t0 := Time.get_ticks_msec()
	while heard.is_empty():
		if Time.get_ticks_msec() - t0 > 90_000:
			break
		await process_frame
	await create_timer(3.0).timeout  # and nothing else (the host's own) comes after
	var f := FileAccess.open(LOG, FileAccess.WRITE)
	f.store_string(JSON.stringify(heard))
	f.close()
	quit(0 if heard.size() > 0 else 1)


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fail(what)
	return cond


func _fail(what: String) -> void:
	if _client_pid != 0 and OS.is_process_running(_client_pid):
		OS.kill(_client_pid)
		print("--- client engine output, last lines:\n", "\n".join(FileAccess.get_file_as_string(ENGINE_LOG).split("\n").slice(-30)))
	printerr("presence_check FAIL: ", what)
	quit(1)
