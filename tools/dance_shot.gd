extends SceneTree
## Another player's body at the J dance (GameState.Act.DANCING), the bare stand and with a gun, for
## checking without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 960x720 -s res://tools/dance_shot.gd
## Saves user://dance_<n>.png, user://stand.png and user://stand_gun.png. Needs a window.

var mgr: Node3D
var _act := 0


func _initialize() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.make_current()
	cam.look_at_from_position(Vector3(1.6, 1.3, -3.0), Vector3(0.0, 0.9, 0.0))
	mgr = load("res://scripts/remote_players.gd").new()
	root.add_child(mgr)
	await process_frame
	var gs := root.get_node("GameState")
	await _hold(0.2)
	gs.character_changed.emit(7, "oldman")
	await _hold(0.6)
	await _save("stand")
	gs.gun_changed.emit(7, 1)
	await _hold(0.6)
	await _save("stand_gun")
	_act = gs.Act.DANCING
	print("pictures in ", OS.get_user_data_dir())
	for n in 6:
		await _hold(1.2)
		await _save("dance_%d" % n)
	assert(not mgr.character(7)._gun.visible, "the gun goes away for the dance")
	_act = gs.Act.IDLE
	await _hold(0.6)
	assert(mgr.character(7)._gun.visible, "and comes back")
	print("dance_shot OK")
	quit()


func _hold(seconds: float) -> void:
	var end := Time.get_ticks_msec() / 1000.0 + seconds
	var gs := root.get_node("GameState")
	while Time.get_ticks_msec() / 1000.0 < end:
		gs.pose_received.emit(7, Time.get_ticks_msec() / 1000.0, Vector3.ZERO, 0.0, 0.0, _act, false, false, false)
		await process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://%s.png" % name)
