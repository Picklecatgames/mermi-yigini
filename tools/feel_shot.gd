extends SceneTree
## Frame-by-frame pictures of how each gun feels to fire, for judging the recoil, the flash, the
## shell and the hit without playing. Per gun: one shot from rest photographed on frames 1, 2, 3, 5,
## 9 and 16 after it (the game held at 60 fps), then the automatics held down for 0.6 s, then a
## close look at where the rounds landed. Each gun's frames go on one sheet:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/feel_shot.gd -- --tag=before
## Saves user://feel_<tag>_<gun>.png (3 x 3 frames at half size, left to right, top to bottom:
## rest, 1, 2 / 3, 5, 9 / 16, held, impact) and user://feel_<tag>_zombie.png (hits on a zombie).
## Needs a window: headless does not draw.

const BODY := preload("res://scripts/zombie_body.gd")
const FRAMES := [1, 2, 3, 5, 9, 16]
const CELL := Vector2i(640, 360)

var _tag := "now"
var _cells: Array[Image] = []


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
	Engine.max_fps = 60
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var player: CharacterBody3D = main.get_node("Player")
	var vm: Node3D = player.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gs.request_pick_character("oldman")  # else the picker covers the screen
	gs.infinite_ammo = true
	gs.player().levels["magazine"] = 6
	gs.player().carried = 400
	gs.player().has_pistol = true
	gs.player().levels.deagle = 1
	print("pictures in ", OS.get_user_data_dir())
	# At the railing, looking east over the targets at the far wall.
	player.global_position = Vector3(12.0, 0.0, -3.0)
	player._yaw = -PI / 2.0
	player._pitch = -0.05
	player.reset_physics_interpolation()
	await _wait(1.5)
	for g in range(1, gs.GUNS.size()):
		if not gs.GUNS[g].ready:
			continue
		var id: String = gs.GUNS[g].id
		gs.request_select_gun(g)
		while vm.gun != g or vm.clip != "":
			await process_frame
		await _wait(0.8)
		_cells.clear()
		await _cell()
		var spun: bool = vm._kit.has("spin")
		if spun:  # barrels up to speed first
			vm.spin = 1.0
		gs.player().cooldown = 0.0
		vm._since_fire = 10.0
		vm.fire()
		var at := 0
		for f: int in FRAMES:
			while at < f - 1:
				await process_frame
				at += 1
			await _cell()
			at += 1
		await _wait(0.8)
		if gs.GUNS[g].auto:
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 600:
				if spun:
					vm.spin = 1.0
				gs.player().cooldown = 0.0
				if vm._since_fire >= vm._interval():
					vm.fire()
				await process_frame
			await _cell()
		else:
			for i in 3:  # a few taps at its own pace
				await _wait(gs.fire_interval + 0.02)
				gs.player().cooldown = 0.0
				vm.fire()
			await _wait(0.05)
			await _cell()
		# Where they landed, close up: zoomed in on the screen centre.
		var cam: Camera3D = player.get_node("Head/Camera3D")
		var fov := cam.fov
		var view: CanvasItem = player.get_node("ViewmodelView")
		view.visible = false
		cam.fov = 12.0
		await _wait(0.12)
		await _cell()
		cam.fov = fov
		view.visible = true
		_sheet(id)
		await _wait(1.5)  # smoke and holes from this gun out of the next one's way
	await _zombie(main, player, vm, gs)
	quit()


## A zombie standing past the railing, shot in the body twice and then in the head, through the
## same signal a real hit comes in on, so the blood, the marker and the camera all answer.
func _zombie(main: Node, player: CharacterBody3D, vm: Node3D, gs: Node) -> void:
	_cells.clear()
	var at := Vector3(16.6, 0.0, -3.7)  # a little left of the gun
	var holder := Node3D.new()
	main.add_child(holder)
	holder.global_transform = Transform3D(Basis(Vector3.UP, -PI / 2), at)  # faces the railing
	var body: Node3D = BODY.new()
	body.setup(&"walker", 5)
	holder.add_child(body)
	gs.request_select_gun(2)
	while vm.gun != 2 or vm.clip != "":
		await process_frame
	player.global_position = Vector3(13.2, 0.0, -3.0)
	player._yaw = -PI / 2.0
	player._pitch = -0.02
	player.reset_physics_interpolation()
	await _wait(1.2)
	await _cell()
	var eye: Vector3 = player.get_node("Head/Camera3D").global_position
	for shot: Array in [[Vector3(0.0, 1.2, 0.05), false], [Vector3(0.0, 1.0, -0.1), false], [Vector3(0.0, body.height - 0.12, 0.0), true]]:
		var hit: Vector3 = at + shot[0]
		var dir := (hit - eye).normalized()
		holder.set_meta("zombie", -1)
		gs.player().cooldown = 0.0
		vm._since_fire = 10.0
		vm.fire()
		body.wound(hit, dir, shot[1])
		gs.shot_landed.emit(gs.local_peer(), hit, -dir, dir, holder, 0, shot[1], 1)
		for f: int in [2, 6]:
			for i in f:
				await process_frame
			await _cell()
		await _wait(0.5)
	if root.get_node_or_null("/root/Main/Waves") and root.get_node("/root/Main/Waves").has_signal("zombie_killed"):
		root.get_node("/root/Main/Waves").zombie_killed.emit(gs.local_peer(), &"walker", true, at, "deagle")
	body.die(&"head")
	await _wait(0.1)
	await _cell()
	await _wait(0.6)
	await _cell()
	_sheet("zombie")
	holder.queue_free()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _cell() -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	_cells.append(img)


func _sheet(name: String) -> void:
	var cols := 3
	var rows := ceili(_cells.size() / float(cols))
	var out := Image.create(CELL.x * cols, CELL.y * rows, false, _cells[0].get_format())
	for i in _cells.size():
		out.blit_rect(_cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % cols, i / cols) * CELL)
	out.save_png("user://feel_%s_%s.png" % [_tag, name])
	print("saved feel_%s_%s.png" % [_tag, name])
