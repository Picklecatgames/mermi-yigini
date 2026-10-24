extends SceneTree
## Photographs every page of the pause menu over the hall, for looking at it without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/pause_shot.gd
## Saves user://pause_<page>.png (the folder is printed). Needs a window: headless does not draw.


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	for i in 90:  # the hall settles: shaders compiled, the camera in place
		await process_frame
	var menu: CanvasLayer
	for c in root.get_node("Settings").get_children():
		if c is CanvasLayer and c.has_method("open"):
			menu = c
	menu.open()
	print("pictures in ", OS.get_user_data_dir())
	for p in menu.PAGES.size():
		menu._show_page(p)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://pause_%d.png" % p)
	menu.close()
	quit()
