extends SceneTree
## Headless check of the day-night clock (scripts/day_night.gd) and the zombie test menu
## (scripts/spawn_menu.gd), host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/day_night_check.gd
## Alone first: the day is what the scene was built with; N (GameState.request_skip_time) runs the
## clock to night in SKIP_TIME, the sun sinking and going out, the sky, the ambient light and the
## haze darkening a little more every frame, never at once; again, back to morning and the built
## day exactly. Every TYPES type comes up from the menu in front of the player, facing it, and
## comes for it; one shot down through GameState dies. Then online: the client presses N and asks
## for zombies; the host runs the clock and puts them up, and both end on the same hour with the
## same zombies under the same paths.

const PORT := 24697
const LOG := "user://day_night_check_client.log"
const ENGINE_LOG := "user://day_night_check_client_engine.log"
const STAND := Vector3(3.0, 0.0, 7.5)  # on the yard's concrete beside the house, looking along +x
const YAW := -PI / 2  # player.gd: looking along (-sin, 0, -cos)

var gs: Node
var net: Node
var main: Node
var waves: Node
var dn: Node
var _log: Array[String] = []
var _client_pid := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	waves = main.get_node("Waves")
	for i in 5:
		await physics_frame
	for c in net.get_children():  # Net's _ready runs after this script's _initialize
		if c.get_script() and c.get_script().resource_path == "res://scripts/day_night.gd":
			dn = c
	if "--client" in OS.get_cmdline_user_args():
		await _client()
	else:
		await _host()


func _host() -> void:
	if not _ok(dn != null, "Net added the day-night node"): return
	var env: Environment = main.get_node("World/WorldEnvironment").environment
	var sun: DirectionalLight3D = main.get_node("World/Sun")
	var built := [sun.rotation_degrees, sun.light_energy, env.background_energy_multiplier, env.ambient_light_energy, env.fog_light_color]
	if not _ok(absf(gs.hour - gs.START_HOUR) < 0.05, "the clock starts at %.1f" % gs.START_HOUR): return
	for i in 3:
		await process_frame
	if not _ok(dn._env == env and gs.night_of(gs.hour) == 0.0 and sun.visible and sun.light_energy == built[1], "by day the sun and sky are as built"): return
	# To night, under a full moon picked by hand for it (the Z menu's row) while it is still day.
	gs.request_debug_moon("full")
	gs.request_skip_time()
	var t0 := Time.get_ticks_msec()
	var samples := []  # [t, sun energy, sky, ambient]
	var at := Time.get_ticks_msec()
	while gs.hour_rate > 24.0 / gs.DAY_SECONDS * 1.01:
		await process_frame
		samples.append([(Time.get_ticks_msec() - at) / 1000.0, sun.light_energy if sun.visible else 0.0,
			env.background_energy_multiplier, env.ambient_light_energy])
		if Time.get_ticks_msec() - t0 > 15_000:
			return _fail("the run to night never ended")
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	if not _ok(absf(took - gs.SKIP_TIME) < 0.5, "N took %.2f s (SKIP_TIME %.1f)" % [took, gs.SKIP_TIME]): return
	if not _ok(absf(gs.hour - gs.SKIP_TO[false]) < 0.01 and gs.night_of(gs.hour) == 1.0, "it ends at %.0f, full night" % gs.SKIP_TO[false]): return
	await process_frame
	if not _ok(not sun.visible and env.background_energy_multiplier < built[2] * 0.05 and env.ambient_light_energy < built[3] * 0.35, "at night the sun is out, the sky and its light nearly gone"): return
	var moon: DirectionalLight3D = main.get_node("World/Moon")
	if not _ok(gs.nights == 1 and gs.moon == "full", "dusk began night 1, under the moon picked for it"): return
	if not _ok(moon.visible and moon.light_energy > 0.3 and moon.shadow_enabled and dn._discs.size() == 1 and dn._discs[0].visible, "the full moon is up, its light casting shadows"): return
	gs.request_debug_moon("blood")
	await process_frame
	await process_frame
	if not _ok(moon.light_color.r > moon.light_color.b * 2.0 and env.fog_light_color.r > env.fog_light_color.b * 2.0 and env.ambient_light_color.r > env.ambient_light_color.b, "under the blood moon the light, the haze and the dark go red"): return
	gs.request_debug_moon("boss")
	await process_frame
	await process_frame
	var e0 := moon.light_energy
	var wavers := false
	for i in 40:
		await process_frame
		wavers = wavers or absf(moon.light_energy - e0) > 0.02
	if not _ok(dn._discs.size() == 3 and dn._discs.all(func(d: Node3D) -> bool: return d.visible) and wavers, "a boss night: three moons up, their light wavering"): return
	var mids := 0
	var worst := 0.0
	for i in range(1, samples.size()):
		var s: Array = samples[i]
		if s[2] < built[2] * 0.9 and s[2] > built[2] * 0.1:
			mids += 1
		worst = maxf(worst, samples[i - 1][2] - s[2])
		if s[1] > samples[i - 1][1] + 0.001 or s[2] > samples[i - 1][2] + 0.0001:
			return _fail("the light came back up on the way to night at %.2f s" % s[0])
	if not _ok(mids >= 10 and worst < built[2] * 0.25, "the sky darkened over %d frames, %.3f at most in one" % [mids, worst]): return
	# And back to morning: the day as built.
	gs.request_skip_time()
	t0 = Time.get_ticks_msec()
	while gs.hour_rate > 24.0 / gs.DAY_SECONDS * 1.01:
		await process_frame
		if Time.get_ticks_msec() - t0 > 15_000:
			return _fail("the run to morning never ended")
	await process_frame
	if not _ok(absf(gs.hour - gs.SKIP_TO[true]) < 0.01 and gs.night_of(gs.hour) == 0.0, "back at %.0f, day" % gs.SKIP_TO[true]): return
	if not _ok(sun.visible and sun.rotation_degrees.is_equal_approx(built[0]) and is_equal_approx(sun.light_energy, built[1])
			and is_equal_approx(env.background_energy_multiplier, built[2]) and is_equal_approx(env.ambient_light_energy, built[3])
			and env.fog_light_color.is_equal_approx(built[4]), "the morning is the day as built"): return
	if not _ok(not moon.visible and not dn._discs.any(func(d: Node3D) -> bool: return d.visible), "the moon down by day"): return
	# Nights 2-5: each dusk a new night and a moon of its own, the fifth a boss night.
	var seen_moons := []
	for n in range(2, 6):
		gs.hour = gs.NIGHT_FROM - gs.TWILIGHT + 0.3  # into dusk
		await process_frame
		await process_frame
		seen_moons.append(gs.moon)
		gs.hour = gs.SKIP_TO[true]
		await process_frame
	if not _ok(gs.nights == 5 and seen_moons[3] == "boss" and seen_moons.slice(0, 3).all(func(k: String) -> bool: return gs.MOONS.has(k)), "nights 2-5 rolled %s, the fifth a boss night" % [seen_moons]): return
	# Every type from the menu.
	var me: Node3D = main.get_node("Player")
	me.global_position = STAND
	me.set(&"_yaw", YAW)
	await physics_frame
	var menu: Node = null
	for c in net.get_children():
		if c.get_script() and c.get_script().resource_path == "res://scripts/spawn_menu.gd":
			menu = c
	if not _ok(menu != null, "Net added the zombie menu"): return
	var types: Array = menu.NAMES.map(func(p: Array) -> String: return p[0])
	for t: StringName in waves.TYPES:
		if not _ok(String(t) in types, "the menu has %s" % t): return
	for t: String in types:
		var before: Array = waves._zombies.keys()
		menu.count = 1
		menu.spawn(t)
		var new: Array = waves._zombies.keys().filter(func(id: int) -> bool: return not id in before)
		if not _ok(new.size() == 1 and waves._zombies[new[0]].type == StringName(t), "a %s came up" % t): return
		var node: Node3D = waves._zombies[new[0]].node
		var off := node.global_position - STAND
		if not _ok(absf(off.x - waves.SUMMON_AHEAD) < 0.5 and absf(off.z) < 0.5, "%s %.1f m in front (%s)" % [t, off.x, off]): return
		await process_frame
		_clear()
	menu.count = 5
	menu.spawn("walker")
	if not _ok(waves._zombies.size() == 5, "x5: five walkers"): return
	var first: Dictionary = waves._zombies.values()[0]
	var d0: float = (first.node as Node3D).global_position.distance_to(STAND)
	for i in 60:
		await physics_frame
	var d1: float = (first.node as Node3D).global_position.distance_to(STAND)
	if not _ok(d1 < d0 - 1.0, "they come for the player (%.1f -> %.1f m)" % [d0, d1]): return
	_clear()
	menu.count = 1
	menu.spawn("walker")
	var z: Dictionary = waves._zombies.values()[0]
	var died := [false]
	gs.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"die" and cue[1] == z.id:
			died[0] = true)
	gs.request_toggle_infinite_ammo()
	gs.request_take_pistol()  # in hand too
	if gs.player().gun != 1:
		gs.request_select_gun(1)
	for i in 40:
		if died[0]:
			break
		var eye := STAND + Vector3.UP * 1.5
		var aim: Vector3 = (z.trunk as Node3D).global_position  # its trunk's shape (on the bones)
		gs.player().cooldown = 0.0
		gs.request_fire(eye, (aim - eye).normalized())
		await physics_frame
	if not _ok(died[0], "a summoned walker shot down dies"): return
	_clear()
	# The moon row by day: that moon, and the clock on to its night.
	if not _ok(gs.night_of(gs.hour) == 0.0, "still day before the moon row"): return
	menu.moon("blood")
	if not _ok(gs.moon == "blood" and gs.hour_rate > 24.0 / gs.DAY_SECONDS * 1.5, "the moon row by day picks the blood moon and runs on to night"): return
	t0 = Time.get_ticks_msec()
	while gs.hour_rate > 24.0 / gs.DAY_SECONDS * 1.01:
		await process_frame
		if Time.get_ticks_msec() - t0 > 15_000:
			return _fail("the moon row's run never ended")
	if not _ok(gs.night_of(gs.hour) == 1.0 and gs.moon == "blood", "night under the blood moon"): return
	menu.moon("crescent")
	if not _ok(gs.moon == "crescent" and gs.night_of(gs.hour) == 1.0, "by night the row only changes the moon"): return
	gs.request_skip_time()
	t0 = Time.get_ticks_msec()
	while gs.hour_rate > 24.0 / gs.DAY_SECONDS * 1.01:
		await process_frame
		if Time.get_ticks_msec() - t0 > 15_000:
			return _fail("the run back to morning never ended")
	gs.request_toggle_infinite_ammo()
	if not await _raid(): return
	await _online()


## B by day: the clock runs to night, then a wave steps out of the wood's edge, on the ground, and
## comes for the player.
func _raid() -> bool:
	var me: Node3D = main.get_node("Player")
	var w0: int = waves.wave
	gs.request_debug_raid()
	if not _ok(gs.hour_rate > 24.0 / gs.DAY_SECONDS * 1.5 and waves._zombies.is_empty(), "B by day runs the clock on, nobody yet"): return false
	var t0 := Time.get_ticks_msec()
	while waves._zombies.is_empty():
		await process_frame
		if Time.get_ticks_msec() - t0 > 20_000:
			_fail("B's wave never came")
			return false
	if not _ok(gs.night_of(gs.hour) >= 0.6 and waves.wave == w0 + 1, "they came once dark, wave %d -> %d" % [w0, waves.wave]): return false
	var first: Dictionary = waves._zombies.values()[0]
	var node: Node3D = first.node
	var near := INF
	for m: Node3D in tree_nodes("forest_edge"):
		near = minf(near, Vector2(m.global_position.x - node.global_position.x, m.global_position.z - node.global_position.z).length())
	if not _ok(near < 5.0, "the first came out at the wood's edge (%.1f m from a marker)" % near): return false
	while waves._zombies.size() < 6:
		await process_frame
		if Time.get_ticks_msec() - t0 > 20_000:
			_fail("only %d of B's wave came" % waves._zombies.size())
			return false
	var d0 := node.global_position.distance_to(me.global_position)
	for i in 120:
		await physics_frame
	var d1 := node.global_position.distance_to(me.global_position)
	var ground: Vector3 = waves._on_ground(node.global_position, node)
	if not _ok(d1 < d0 - 1.0 and absf(ground.y - node.global_position.y) < 0.3, "it comes for the player on the ground (%.1f -> %.1f m, %.2f m off it)" % [d0, d1, ground.y - node.global_position.y]): return false
	waves._seq += 1  # the rest stay in the wood
	while waves._raiding:
		await process_frame
	_clear()
	return true


func tree_nodes(group: String) -> Array:
	return get_nodes_in_group(group)


func _clear() -> void:
	for id: int in waves._zombies.keys():
		waves._zombies[id].node.free()
	waves._zombies.clear()


func _online() -> void:
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	_client_pid = OS.create_process(OS.get_executable_path(), ["--headless", "--log-file", ProjectSettings.globalize_path(ENGINE_LOG),
		"--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/day_night_check.gd", "--", "--client"])
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(_client_pid):
		if Time.get_ticks_msec() - t0 > 60_000:
			return _fail("client timed out")
		await process_frame
	var code := OS.get_process_exit_code(_client_pid)
	_client_pid = 0
	print(FileAccess.get_file_as_string(LOG))
	if code != 0:
		return _fail("client side failed (exit %d)" % code)
	var seen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOG).get_slice("\n", 0))
	if not _ok(absf(float(seen.hour) - gs.hour) < 0.25, "the client ended on the host's hour (%.2f, %.2f)" % [seen.hour, gs.hour]): return
	var ids: Array = waves._zombies.keys().map(func(id: int) -> String: return "Z%d" % id)
	ids.sort()
	if not _ok(ids.size() == 2 and ids == Array(seen.zombies), "the client asked for 2 zombies; both have %s" % [ids]): return
	if not _ok(gs.moon == "crescent" and seen.moon == "crescent", "the client picked the crescent; both have it"): return
	print("day_night_check: PASS")
	quit(0)


func _client() -> void:
	if net.join("127.0.0.1", PORT) != OK:
		return _fail("could not join")
	var t0 := Time.get_ticks_msec()
	while not net.online or not gs._spawned:
		await process_frame
		if Time.get_ticks_msec() - t0 > 20_000:
			return _fail("never got in")
	for i in 30:
		await process_frame
	var night: bool = gs.night_of(gs.hour) > 0.5
	gs.request_skip_time()
	t0 = Time.get_ticks_msec()
	while gs.hour_rate < 24.0 / gs.DAY_SECONDS * 1.5:  # the host's word that it runs
		await process_frame
		if Time.get_ticks_msec() - t0 > 5_000:
			return _fail("the host never ran the clock")
	while gs.hour_rate > 24.0 / gs.DAY_SECONDS * 1.01:
		await process_frame
		if Time.get_ticks_msec() - t0 > 15_000:
			return _fail("the run never ended here")
	if not _ok((gs.night_of(gs.hour) > 0.5) != night, "the client's N turned %s" % ("day" if night else "night")): return
	main.get_node("Player").global_position = STAND
	gs.request_debug_moon("crescent")
	gs.request_debug_spawn("runner", STAND, YAW, 2)
	t0 = Time.get_ticks_msec()
	while waves._zombies.size() < 2:
		await process_frame
		if Time.get_ticks_msec() - t0 > 5_000:
			return _fail("the zombies never came")
	var ids: Array = waves._zombies.keys().map(func(id: int) -> String: return "Z%d" % id)
	ids.sort()
	for i in 10:
		await process_frame
	_log.push_front(JSON.stringify({"hour": gs.hour, "zombies": ids, "moon": gs.moon}))
	_write_log()
	quit(0)


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fail(what)
	else:
		_log.append("ok: " + what)
		if not "--client" in OS.get_cmdline_user_args():
			print("ok: ", what)
	return cond


func _fail(what: String) -> void:
	_log.append("day_night_check FAIL: " + what)
	printerr("day_night_check FAIL: ", what)
	if _client_pid != 0 and OS.is_process_running(_client_pid):
		OS.kill(_client_pid)
	_write_log()
	quit(1)


func _write_log() -> void:
	if "--client" in OS.get_cmdline_user_args():
		var f := FileAccess.open(LOG, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_log))
