extends SceneTree
## The first-person arms as the player sees them, the PS1 screen on: bare fists and the pistol, by
## day and at night (psx_shots.gd's night), over the grass and into the wood:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/arms_shots.gd -- --tag=T
## `--psx=0` without the PS1 screen. user://arms_<T>_<fists|pistol>_<view>_<day|night>.png

const VIEWS := {  # eye, looking at
	"grass": [Vector3(20.0, 1.7, 6.0), Vector3(30.0, 0.2, 9.0)],
	"forest": [Vector3(30.0, 1.7, 8.0), Vector3(90.0, 3.0, 25.0)],
}


func _initialize() -> void:
	var tag := "x"
	var psx := 4
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--psx="):  # 0: no PS1 screen, the arms as lit
			psx = a.trim_prefix("--psx=").to_int()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	var settings: Node = root.get_node("Settings")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	settings.save_path = "user://settings_shots.cfg"  # never the developer's own
	settings.set_value("psx", psx)
	var gs: Node = root.get_node("GameState")
	gs.request_pick_character("oldman")
	var player: Node3D = main.get_node("Player")
	await _frames(240)  # shaders compile, the probes capture
	for night: bool in [false, true]:
		if night:
			_night(main)
		for hold: String in ["fists", "pistol"]:
			if hold == "pistol":
				gs.request_take_pistol()
				if gs.player().gun != 1:
					gs.request_select_gun(1)
			elif gs.player().gun != 0:
				gs.request_select_gun(0)
			await _frames(90)  # the draw plays out
			for v: String in VIEWS:
				var eye: Vector3 = VIEWS[v][0]
				var d: Vector3 = (VIEWS[v][1] - eye).normalized()
				player.global_position = eye - Vector3.UP * 1.6
				player.velocity = Vector3.ZERO
				player.set(&"_yaw", atan2(-d.x, -d.z))
				player.set(&"_pitch", asin(d.y))
				await _frames(40)
				var file := "user://arms_%s_%s_%s_%s.png" % [tag, hold, v, "night" if night else "day"]
				root.get_viewport().get_texture().get_image().save_png(file)
				print(ProjectSettings.globalize_path(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.save_path))
	quit()


## psx_shots.gd's night: the sun out, the sky and its light nearly gone.
func _night(main: Node) -> void:
	main.get_node("World/Sun").visible = false
	var env: Environment = main.get_node("World/WorldEnvironment").environment
	env.background_energy_multiplier = 0.02
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.42, 0.6)
	env.ambient_light_energy = 0.16
	env.ambient_light_sky_contribution = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_light_color = Color(0.07, 0.08, 0.1)
	env.fog_sky_affect = 1.0
	env.volumetric_fog_albedo = Color(0.05, 0.05, 0.06)
	main.get_node("Ambience").set(&"night", true)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
