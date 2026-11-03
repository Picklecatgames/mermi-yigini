extends SceneTree
## The PS1 guns and arms (tools/psx_import.gd) in first person, for looking without playing: the
## pistol on the spawn desk, then every gun at rest, aimed and in the frame its muzzle flashes, and
## the trail and puff where the round lands. Each shot twice: as drawn (user://psxgun_<shot>.png) and
## brought down the way the screen will be (_ps1.png: drawn small, 15-bit colour with ordered dither,
## blown up unfiltered, as tools/psx_shots.gd does).
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/psx_gun_shots.gd

const SCREEN := Vector2i(427, 240)
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var player: CharacterBody3D = main.get_node("Player")
	var vm: Node3D = player.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gs.player().levels["magazine"] = 6
	gs.player().carried = 200
	print("pictures in ", OS.get_user_data_dir())
	await _wait(1.0)
	# The pistol lying on the desk, from where a player walks up to it.
	var table := get_first_node_in_group("gun_table") as Node3D
	if table:
		var at := table.global_position + table.global_basis.z * 1.1
		at.y = player.global_position.y
		var to := table.global_position - at
		player.global_position = at
		player._yaw = atan2(-to.x, -to.z)
		player._pitch = -0.55
		player.reset_physics_interpolation()
		await _wait(0.8)
		await _save("table")
	player._pitch = 0.0
	gs.player().has_pistol = true
	gs.player().levels.deagle = 1
	for g in range(1, gs.GUNS.size()):
		if not gs.GUNS[g].ready:
			continue
		var id: String = gs.GUNS[g].id
		gs.request_select_gun(g)
		while vm.gun != g or vm.clip != "":
			await process_frame
		await _wait(0.6)
		await _save(id + "_idle")
		gs.player().cooldown = 0.0
		vm._since_fire = 10.0
		if vm.SETS[id].has("spin"):  # barrels up first
			vm.spin = 1.0
		vm.fire()
		await process_frame
		await process_frame
		await _save(id + "_fire")
		await _wait(0.1)
		await _save(id + "_after")
		while vm.clip != "":
			await process_frame
		if vm.SETS[id].get("no_aim", false):
			continue
		vm.set_process(false)
		vm.aim = 1.0
		vm._aim_lin = 1.0
		vm._rest_clip()
		var t0 := Time.get_ticks_msec()
		var last := t0
		while Time.get_ticks_msec() - t0 < 900:
			vm._sway_and_bob((Time.get_ticks_msec() - last) / 1000.0)
			last = Time.get_ticks_msec()
			await process_frame
		await _save(id + "_aimed")
		vm.aim = 0.0
		vm._aim_lin = 0.0
		vm._aim_pose = false
		vm.set_process(true)
		await _wait(0.5)
	quit()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("user://psxgun_%s.png" % shot_name)
	var size := img.get_size()
	img.resize(SCREEN.x, SCREEN.y, Image.INTERPOLATE_NEAREST)
	for y in SCREEN.y:
		for x in SCREEN.x:
			var c := img.get_pixel(x, y)
			var d: float = (BAYER[(y % 4) * 4 + x % 4] / 16.0 - 0.5) / 31.0
			img.set_pixel(x, y, Color(roundf((c.r + d) * 31.0) / 31.0, roundf((c.g + d) * 31.0) / 31.0, roundf((c.b + d) * 31.0) / 31.0))
	img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	img.save_png("user://psxgun_%s_ps1.png" % shot_name)
