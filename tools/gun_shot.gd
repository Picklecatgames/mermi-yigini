extends SceneTree
## Draws each gun (and bare fists) in first person and photographs it at rest, aimed, firing and
## mid-reload, for checking the viewmodel without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/gun_shot.gd
## Saves user://gun_<gun>_<shot>.png (the folder is printed). Needs a window: headless does not draw.


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var player: CharacterBody3D = main.get_node("Player")
	var vm: Node3D = player.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	player.rotation.y = deg_to_rad(20)  # pile off to the side, wall and floor in view
	await process_frame  # GameState needs the tree's multiplayer before player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # the player grabs it; the real mouse must not turn the view
	gs.player().levels["magazine"] = 6
	gs.player().carried = 200
	print("pictures in ", OS.get_user_data_dir())
	await _wait(1.5)
	await _save("fists_idle")
	vm.fire()
	await _wait(0.25)
	await _save("fists_punch")
	for g in range(1, gs.GUNS.size()):
		if not gs.GUNS[g].ready:
			continue
		var id: String = gs.GUNS[g].id
		gs.request_select_gun(g)
		while vm.gun != g or vm.clip != "":  # put away, drawn
			await process_frame
		await _wait(0.6)
		await _save(id + "_idle")
		vm.reload()
		await _wait(0.9)
		await _save(id + "_reload_mid")
		while vm.clip != "":
			await process_frame
		gs.player().cooldown = 0.0
		vm._since_fire = 10.0
		vm.fire()
		await process_frame
		await process_frame
		await _save(id + "_fire_flash")
		await _wait(0.12)
		await _save(id + "_fire_shell")
		while vm.clip != "":
			await process_frame
		# Aimed: the right button needs a captured mouse, so the sights are brought up by hand.
		vm.set_process(false)
		vm.aim = 1.0
		vm._aim_lin = 1.0
		vm._rest_clip()  # Aim_In where the set has it, else Idle under the sights
		var t0 := Time.get_ticks_msec()
		var last := t0
		while Time.get_ticks_msec() - t0 < 900:  # by time: off screen it draws a few hundred frames a second
			vm._sway_and_bob((Time.get_ticks_msec() - last) / 1000.0)
			last = Time.get_ticks_msec()
			await process_frame
		await _save(id + "_aimed")
		vm.aim = 0.0
		vm._aim_lin = 0.0
		vm._aim_pose = false
		vm.set_process(true)
		await _wait(0.5)
	# The same gun by the heap's spots and in a dark corner: the hall's nearest lights light it.
	for spot: Array in [["lit", Vector3(-2.5, 0.0, 6.5), PI], ["dark", Vector3(-24.0, 0.0, 22.0), 0.6]]:
		player.global_position = spot[1]
		player._yaw = spot[2]
		player.reset_physics_interpolation()
		await _wait(0.8)
		await _save("scorpion_" + spot[0])
	quit()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://gun_%s.png" % shot_name)
