extends SceneTree
## A look at the factory as tables and scene draw it, the PS1 screen on, off screen:
##   Godot.exe --path . --position -10000,-10000 --resolution 1600x900 -s res://tools/factory_shot.gd
## user://factory_shot_near.png and _far.png: a chain at the heap's foot with items on its belts; the
## debug tool's ghost is out where the camera looks (red: that's on the chain).

const WAIT := 12.0  # s the chain runs before the picture


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var settings: Node = root.get_node("Settings")
	settings.save_path = "user://settings_shots.cfg"  # never the developer's own
	settings.set_value("psx", 2)
	var gs: Node = root.get_node("GameState")
	gs.request_pick_character("worker")
	var f: Node = gs.factory
	var sim: FactorySim = f.sim
	var k: int = sim.data.kind_index["cekici"]
	var spot := Vector2i.MAX
	for x in range(-7, -20, -1):
		for z in range(-12, 12):
			if spot == Vector2i.MAX and f.can_build(k, x, z, 0):
				spot = Vector2i(x, z)
	var x := spot.x
	var z := spot.y
	gs.request_factory_place("cekici", x, z, 0)
	for i in 3:
		gs.request_factory_place("bant", x + 2 + i, z + 1, 0)
	gs.request_factory_place("ezici", x + 5, z, 0)
	gs.request_factory_place("bant", x + 7, z + 1, 0)
	gs.request_factory_place("bant", x + 8, z + 1, 0)
	gs.request_factory_place("sokucu", x + 9, z, 0)
	gs.request_factory_place("kasa", x + 11, z, 0)
	var player: Node3D = main.get_node("Player")
	var mid := Vector3(x + 6, 0.5, z + 1)
	_stand(player, mid + Vector3(0.5, 1.2, 3.5), mid)
	for c in f.get_children():
		if c.has_method("_aim"):
			c.set("_kind", sim.data.kind_index["kasa"])
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < WAIT * 1000.0:
		await process_frame
	_save("factory_shot_near")
	_stand(player, mid + Vector3(-3.0, 3.5, 9.0), mid + Vector3(-3.0, 0.0, 0.0))
	await _frames(20)
	_save("factory_shot_far")
	print("kasa: ", gs.stock_of("celik"), " steel; ", sim.items_on_belts(), " on belts; drawn ", f.view.drawn)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.save_path))
	quit()


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
