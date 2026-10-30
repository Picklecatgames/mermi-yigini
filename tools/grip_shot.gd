extends SceneTree
## Another player's character holding each gun (and bare-handed), photographed from several sides,
## for checking the grip (fingers round the grip, the left hand on the gun) without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 960x720 -s res://tools/grip_shot.gd
## Saves user://grip_<gun>_<view>.png (the folder is printed). Needs a window: headless does not draw.

## view -> [camera position, look-at point], metres, the character at the origin facing -Z.
const VIEWS := {
	"front": [Vector3(0.9, 1.5, -1.5), Vector3(0.0, 1.3, -0.35)],
	"right": [Vector3(1.1, 1.4, -0.35), Vector3(0.0, 1.3, -0.35)],
	"left": [Vector3(-1.1, 1.4, -0.4), Vector3(0.0, 1.3, -0.35)],
	"above": [Vector3(0.25, 2.1, -0.45), Vector3(0.0, 1.3, -0.4)],
	"shoulder": [Vector3(0.45, 1.75, 0.9), Vector3(0.0, 1.3, -0.5)],
}

var mgr: Node3D


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
	await _hold(0.8)
	print("pictures in ", OS.get_user_data_dir())
	var gs := root.get_node("GameState")
	for g in gs.GUNS.size():
		if not gs.GUNS[g].ready:
			continue
		var id: String = gs.GUNS[g].id
		gs.gun_changed.emit(7, g)
		await _hold(0.3)
		for v: String in VIEWS:
			cam.look_at_from_position(VIEWS[v][0], VIEWS[v][1])
			await _hold(0.15)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://grip_%s_%s.png" % [id, v])
		if g == 0:
			continue
		# Close on the right side of the grip and trigger, wherever the gun ended up.
		var c = mgr.character(7)
		var at: Vector3 = c._muzzle.global_position - (c._gun.global_basis.z.normalized()) * 0.14
		cam.look_at_from_position(at + Vector3(0.45, 0.03, 0.0), at)
		await _hold(0.15)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://grip_%s_trigger.png" % id)
	quit()


func _hold(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		mgr._on_pose(7, Time.get_ticks_msec() / 1000.0, Vector3.ZERO, 0.0, 0.0, 0, false, false, true)
		await process_frame
