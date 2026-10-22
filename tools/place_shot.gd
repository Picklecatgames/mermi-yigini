extends SceneTree
## Placement mode from the overview, with some stock and a piece up, saved as a PNG:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/place_shot.gd


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	await process_frame
	gs.gear_stock = {"dummy": 3, "popper": 2, "texas_star": 1}
	gs.request_place_gear("dummy", Vector3(20, 0, 6), -PI / 2)
	gs.request_place_gear("texas_star", Vector3(33, 0, -4), -PI / 2)
	gs.request_toggle_placing()
	for f in 40:
		await process_frame
	Input.warp_mouse(Vector2(560, 420))
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png("user://shot_place_mode.png")
	print("saved ", ProjectSettings.globalize_path("user://shot_place_mode.png"))
	quit()
