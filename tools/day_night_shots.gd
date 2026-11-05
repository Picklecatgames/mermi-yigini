extends SceneTree
## The day turning to night under N (scripts/day_night.gd) and the zombie test menu's pick
## (scripts/spawn_menu.gd), as the player sees them, the PS1 screen on, as PNGs:
##   Godot.exe --path . --position -10000,-10000 --resolution 1600x900 -s res://tools/day_night_shots.gd
## user://daynight_<n>_<hour>.png along the run to night, then user://summon_<day|night>.png: a mix of
## types called up in front of the player, a moment after they come up; user://night_far.png: from
## FAR_EYE, the workshop and the heap behind it ~30 m off, a few of the dead ~20 m off;
## user://night_moon.png: up at the moon.
## `-- --moons` instead: every moon (GameState.MOONS and "boss") at midnight, the pistol in hand,
## user://moon_<kind>_sky.png up at the moon(s) from across the clearing, over the house, three of the
## dead ~9 m off either side of the gun, and moon_<kind>_yard.png the workshop from ~30 m.

const EYE := Vector3(17.0, 1.7, 4.0)  # psx_shots.gd's "yard" view
const LOOK := Vector3(5.0, 1.4, -0.5)
const AT := [0.8, 1.6, 2.4, 3.2, 4.0, 5.2]  # s into N's run to night
const FAR_EYE := Vector3(36.0, 1.7, 8.0)
const FAR_LOOK := Vector3(2.0, 3.0, -2.0)
const CLEARING := Vector2(8.0, 0.0)  # build_world.gd CLEARING_CENTRE
const CLEARING_BACK := 18.0  # m back from it, away from the moon, for the --moons sky view
const SUMMON := [["walker", 1], ["brute", 1], ["dog", 2], ["runner", 2], ["spiker", 1]]


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var settings: Node = root.get_node("Settings")
	settings.save_path = "user://settings_shots.cfg"  # never the developer's own
	settings.set_value("psx", 2)
	var gs: Node = root.get_node("GameState")
	gs.request_pick_character("oldman")
	var player: Node3D = main.get_node("Player")
	_stand(player, EYE, LOOK)
	await _frames(200)  # shaders compile, the probes capture
	if "--moons" in OS.get_cmdline_user_args():
		gs.request_take_pistol()  # the hands in each picture, lit as the night lights them
		await _frames(30)
		await _moons(gs, player)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.save_path))
		quit()
		return
	_save("daynight_0_day")
	gs.request_skip_time()
	var t0 := Time.get_ticks_msec()
	for i in AT.size():
		while (Time.get_ticks_msec() - t0) / 1000.0 < AT[i]:
			await process_frame
		_save("daynight_%d_%02d%02d" % [i + 1, int(gs.hour), int(fmod(gs.hour, 1.0) * 60.0)])
	await _summon(gs, player, "night")
	await _far(gs, player)
	gs.request_skip_time()
	while gs.hour_rate > 24.0 / gs.DAY_SECONDS * 1.01:
		await process_frame
	await _frames(10)
	await _summon(gs, player, "day")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.save_path))
	quit()


## The SUMMON mix in front of the player, then a picture a moment after they come up.
func _summon(gs: Node, player: Node3D, tag: String) -> void:
	var waves: Node = player.get_parent().get_node("Waves")
	for id: int in waves._zombies.keys():
		waves._zombies[id].node.free()
	waves._zombies.clear()
	var eye := Vector3(6.0, 1.7, 0.0)
	_stand(player, eye, eye + Vector3(1, -0.08, 0))
	await _frames(5)
	var side := 0
	for s: Array in SUMMON:  # each its own spot, side by side
		var at := player.global_position + Vector3(0.0, 0.0, (side - 2) * 1.6)
		gs.request_debug_spawn(s[0], at, float(player.get(&"_yaw")), s[1])
		side += 1
	await _frames(25)
	_save("summon_" + tag)


func _far(gs: Node, player: Node3D) -> void:
	_stand(player, FAR_EYE, FAR_LOOK)
	await _frames(5)
	var ahead := (FAR_LOOK - FAR_EYE).normalized()
	ahead.y = 0.0
	for i in 3:  # called up 14 m out, they come up 6 m further: ~20 m
		var at := player.global_position + ahead.normalized() * 14.0 + Vector3(0.0, 0.0, (i - 1) * 3.0)
		gs.request_debug_spawn(["walker", "brute", "runner"][i], at, float(player.get(&"_yaw")), 1)
	await _frames(20)
	_save("night_far")
	var moon: Node3D = player.get_parent().get_node("World/Moon")  # and the moon itself, over the desert
	_stand(player, FAR_EYE, FAR_EYE + moon.global_basis.z * 10.0 + Vector3.DOWN * 3.0)
	await _frames(5)
	_save("night_moon")


func _moons(gs: Node, player: Node3D) -> void:
	var waves: Node = player.get_parent().get_node("Waves")
	gs.request_skip_time()
	while gs.hour_rate > 24.0 / gs.DAY_SECONDS * 1.01:
		await process_frame
	for kind: String in gs.MOONS.keys() + ["boss"]:
		gs.request_debug_moon(kind)
		for id: int in waves._zombies.keys():
			waves._zombies[id].node.free()
		waves._zombies.clear()
		var out := Basis.from_euler(Vector3(deg_to_rad(-18.0), deg_to_rad(75.0), 0.0)).z  # day_night.gd _toward
		var flat := Vector3(out.x, 0.0, out.z).normalized()
		# From the clearing's far side, its whole width between the eye and the wood under the moon:
		# from beside the house the wood stood up in front of every moon.
		var eye := Vector3(CLEARING.x, 1.7, CLEARING.y) - flat * CLEARING_BACK
		_stand(player, eye, eye + out)
		await _frames(3)
		for i in 3:
			var at := player.global_position + flat * 3.0 + flat.cross(Vector3.UP) * (i - 1) * 5.0  # waves.gd SUMMON_AHEAD on: ~9 m off, this side of the house, out from behind the gun
			gs.request_debug_spawn(["walker", "brute", "runner"][i], at, atan2(-flat.x, -flat.z), 1)
		await _frames(15)
		_save("moon_%s_sky" % kind)
		_stand(player, FAR_EYE, FAR_LOOK)
		await _frames(10)
		_save("moon_%s_yard" % kind)


func _stand(player: Node3D, eye: Vector3, look: Vector3) -> void:
	var d := (look - eye).normalized()
	player.global_position = eye - Vector3.UP * 1.6
	player.velocity = Vector3.ZERO
	player.set(&"_yaw", atan2(-d.x, -d.z))
	player.set(&"_pitch", asin(d.y))


func _save(name: String) -> void:
	var file := "user://%s.png" % name
	root.get_viewport().get_texture().get_image().save_png(file)
	print("shot ", ProjectSettings.globalize_path(file))


func _frames(n: int) -> void:
	for i in n:
		await process_frame
