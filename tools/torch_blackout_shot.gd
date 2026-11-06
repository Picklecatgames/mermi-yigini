extends SceneTree
## The flashlight dying in the wood and coming back on something, first person, frame after frame on
## one sheet (scripts/lamp_flicker.gd try_blackout, scripts/head_lamp.gd blackout_steps):
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/torch_blackout_shot.gd
## `-- --none` without the creature. Saves user://torch_blackout_sheet.png (a frame every EVERY s,
## left to right, top to bottom); the folder is printed.

const EVERY := 0.3
const COLS := 4
const ROWS := 5
const CELL := Vector2i(400, 225)
const WOOD := Vector3(60.0, 0.0, 0.0)  # 10 m into the wood east of the clearing


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs := root.get_node("GameState")
	var player: CharacterBody3D = main.get_node("Player")
	main.get_node("Waves").night_spawns = false
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gs.lamp_flicker_rolls.auto = false
	gs.hour_rate = 0.0
	gs.hour = 0.0
	for f in 3:
		await process_frame
	gs.request_debug_moon("full")
	var at := WOOD
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(at + Vector3.UP * 80.0, at + Vector3.DOWN * 50.0, 1))
	at.y = hit.position.y + 0.1 if not hit.is_empty() else 0.1
	player.global_position = at
	player._yaw = 0.0
	player._pitch = -0.08
	player.reset_physics_interpolation()
	gs.request_toggle_torch()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await process_frame
	gs.lamp_flicker_rolls.try_blackout(gs.local_peer(), 0 if "--none" in OS.get_cmdline_user_args() else 1)
	var frames: Array[Image] = []
	t0 = Time.get_ticks_msec()
	var next := 0.0
	while frames.size() < COLS * ROWS:
		await process_frame
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if t >= next:
			frames.append(root.get_texture().get_image())
			next += EVERY
	var sheet := Image.create(CELL.x * COLS, CELL.y * ROWS, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var img := frames[i]
		img.convert(Image.FORMAT_RGB8)
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLS * CELL.x, i / COLS * CELL.y))
	sheet.save_png("user://torch_blackout_sheet.png")
	print("saved ", ProjectSettings.globalize_path("user://torch_blackout_sheet.png"))
	quit()
