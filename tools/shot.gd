extends SceneTree
## Renders main.tscn from fixed cameras and saves PNGs, for checking visuals without playing.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/shot.gd
## Add `-- --dig` to drain 3M bullets from one spot on the heap first.

const SHOTS := {
	"far": [Vector3(0, 1.6, 15), Vector3(0, 2.0, 0)],
	"mid": [Vector3(0, 1.6, 10.5), Vector3(0, 1.0, 6.0)],
	"near": [Vector3(0, 1.6, 8.8), Vector3(0, 0.6, 7.6)],
	"rim": [Vector3(1.5, 1.4, 11.5), Vector3(0, 0.0, 8.5)],
	"toe": [Vector3(0.5, 1.0, 10.2), Vector3(0, 0.0, 8.3)],
	"floor": [Vector3(0, 1.6, 22), Vector3(10, 0, 12)],
	"dig": [Vector3(9.5, 4.0, 4.0), Vector3(4.0, 1.5, 0.0)],
}


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()  # no mouse capture, no HUD
	root.add_child(main)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.make_current()
	if "--dig" in OS.get_cmdline_user_args():
		await process_frame
		var pile: Node3D = main.get_node("Pile")
		var at := pile.to_global(Vector3(4.0, 0.0, 0.0))
		for i in 150:
			root.get_node("GameState").request_take_bullets(20000, at)
			await physics_frame
		for i in 400:
			await physics_frame
	for shot_name in SHOTS:
		cam.look_at_from_position(SHOTS[shot_name][0], SHOTS[shot_name][1])
		for f in 30:  # let TAA settle
			await process_frame
		root.get_texture().get_image().save_png("user://shot_%s.png" % shot_name)
		print("saved ", ProjectSettings.globalize_path("user://shot_%s.png" % shot_name))
	quit()
