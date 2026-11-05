extends SceneTree
## A head lamp flickering at night, frame after frame, on one sheet (scripts/head_lamp.gd flicker):
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/lamp_flicker_shot.gd
## `-- --seed=N` for another flicker, `--at=X,Z,AX,AZ` for the camera's feet and where it looks.
## Saves user://lamp_flicker_sheet.png (every EVERY-th frame, left to right, top to bottom, each
## with its share of the beam); the folder is printed.

const EVERY := 3
const COLS := 4
const ROWS := 4
const CELL := Vector2i(400, 225)

var lamp: SpotLight3D


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.make_current()
	var seed := 7
	var at := [3.5, -22.5, 0.0, -27.5]  # tools/shot.gd "tyres": tyres and junk a few metres off
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = a.trim_prefix("--seed=").to_int()
		elif a.begins_with("--at="):
			at = Array(a.trim_prefix("--at=").split_floats(","))
	await process_frame
	var gs := root.get_node("GameState")
	gs.hour_rate = 0.0
	gs.hour = 0.0
	cam.look_at_from_position(Vector3(at[0], 1.7, at[1]), Vector3(at[2], 0.4, at[3]))
	lamp = preload("res://scripts/head_lamp.gd").new()
	main.add_child(lamp)
	lamp.follow(cam.global_transform, 0.0)
	for f in 150:  # the night comes down, the lamp eases on, TAA settles
		await process_frame
	var frames: Array[Image] = []
	var levels := []
	lamp.flicker(seed)
	var f := 0
	while frames.size() < COLS * ROWS:
		await process_frame
		if f % EVERY == 0:
			frames.append(root.get_texture().get_image())
			levels.append(snappedf(lamp.flick, 0.01))
		f += 1
	print("the beam's share, frame by frame: ", levels)
	var sheet := Image.create(CELL.x * COLS, CELL.y * ROWS, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var img := frames[i]
		img.convert(Image.FORMAT_RGB8)
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLS * CELL.x, i / COLS * CELL.y))
	sheet.save_png("user://lamp_flicker_sheet.png")
	print("saved ", ProjectSettings.globalize_path("user://lamp_flicker_sheet.png"))
	quit()
