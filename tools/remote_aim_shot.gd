extends SceneTree
## Another player's character with each gun relaxed (held low), aimed (right mouse) and at the peak
## of a round's kick, photographed from the side and from ahead, for checking the stances without
## playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 960x720 -s res://tools/remote_aim_shot.gd
## Saves user://aim_<gun>_<state>_<view>.png (the folder is printed). Needs a window: headless does not draw.

## view -> [camera position, look-at point], metres, the character at the origin facing -Z.
const VIEWS := {
	"side": [Vector3(2.4, 1.3, -0.4), Vector3(0.0, 1.1, -0.4)],
	"front": [Vector3(1.4, 1.5, -2.6), Vector3(0.0, 1.1, -0.2)],
}
const KICK_PEAK := 0.035  # s after the round: about the top of the flip

var mgr: Node3D
var _aim := false


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
	mgr = load("res://scripts/remote_players.gd").new()
	root.add_child(mgr)
	await process_frame
	var gs := root.get_node("GameState")
	await _hold(0.2)  # the character comes with the first pose
	gs.character_changed.emit(7, "oldman")
	await _hold(0.8)
	print("pictures in ", OS.get_user_data_dir())
	for g in range(1, gs.GUNS.size()):
		if not gs.GUNS[g].ready:
			continue
		var id: String = gs.GUNS[g].id
		gs.gun_changed.emit(7, g)
		for v: String in VIEWS:
			cam.look_at_from_position(VIEWS[v][0], VIEWS[v][1])
			_aim = false
			await _hold(0.8)
			await _save("aim_%s_relaxed_%s" % [id, v])
			_aim = true
			await _hold(0.6)
			await _save("aim_%s_aimed_%s" % [id, v])
			mgr.character(7).shoot()
			await _hold(KICK_PEAK)
			await _save("aim_%s_fire_%s" % [id, v])
	quit()


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://%s.png" % file)


func _hold(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		mgr._on_pose(7, Time.get_ticks_msec() / 1000.0, Vector3.ZERO, 0.0, 0.0, 0, false, false, _aim)
		await process_frame
