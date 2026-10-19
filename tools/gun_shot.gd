extends SceneTree
## Plays the pistol through draw, shots, reloads and saves screenshots, for checking the
## viewmodel without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/gun_shot.gd


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var player: CharacterBody3D = main.get_node("Player")
	var vm: Node3D = player.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	player.rotation.y = deg_to_rad(20)  # pile off to the side, wall and floor in view
	await process_frame  # GameState needs the tree's multiplayer before player()
	gs.player().levels["capacity"] = 6
	gs.player().carried = 20
	await _wait(1.3)
	_save("idle")
	vm.reload()
	await _wait(0.9)
	_save("reload_mid")
	await _wait(2.2)
	vm.fire()
	await process_frame
	await process_frame
	_save("fire_flash")
	await _wait(0.12)
	_save("fire_shell")
	await _wait(0.5)
	for i in 3:
		vm.fire()
		await _wait(0.3)
	_save("smoke")
	await _wait(3.0)
	player.get_node("Head").rotation.x = -0.9
	await _wait(0.3)
	_save("shells_floor")
	var shell: Node3D = vm._shells.filter(func(x): return x.visible)[0]
	var close := Camera3D.new()
	main.add_child(close)
	close.near = 0.005
	close.look_at_from_position(shell.global_position + Vector3(0.12, 0.06, 0.0), shell.global_position)
	close.make_current()
	player.get_node("ViewmodelView").visible = false
	await _wait(0.3)
	_save("shell_close")
	player.get_node("ViewmodelView").visible = true
	player.get_node("Head/Camera3D").make_current()
	player.get_node("Head").rotation.x = 0.0
	player.position = Vector3(0, 0, 27.4)  # nose to the south wall
	player.rotation.y = PI
	await _wait(0.4)
	_save("wall")
	quit()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _save(shot_name: String) -> void:
	root.get_texture().get_image().save_png("user://gun_%s.png" % shot_name)
	print("saved ", ProjectSettings.globalize_path("user://gun_%s.png" % shot_name))
