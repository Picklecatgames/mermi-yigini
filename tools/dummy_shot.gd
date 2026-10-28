extends SceneTree
## Shoots the dummy and saves screenshots of the muzzle effects, the hit reaction, the payout
## pop, bullet holes, a wall hit and the upgrade screen:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/dummy_shot.gd


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var first: Node3D = load("res://scenes/dummy.tscn").instantiate()  # where the game's first dummy used to stand; now the player places it
	first.name = "Dummy"
	first.transform = str_to_var("Transform3D(-3.6199901e-06, 0, -1, 0, 1, 0, 1, 0, -3.6199901e-06, 23, 0, 0)")
	main.add_child(first)
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var player: CharacterBody3D = main.get_node("Player")
	var vm: Node3D = player.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	var dummy: Node3D = main.get_node("Dummy")
	await process_frame
	player.global_position = Vector3(8, 0, 9)
	_aim(player, dummy.global_position + Vector3(0, 1.0, 0))
	gs.player().levels["magazine"] = 6
	gs.player().carried = 7
	await _wait(1.5)
	vm.reload()
	await _wait(2.6)
	_save("aim")
	vm.fire()
	await process_frame
	await process_frame
	_save("muzzle")
	await _wait(0.06)
	_save("muzzle_late")
	await _wait(0.12)
	_save("hit_swing")
	await _wait(0.3)
	_save("hit_pop")
	for i in 4:
		_aim(player, dummy.global_position + Vector3(randf_range(-0.12, 0.12), randf_range(0.8, 1.6), 0))
		await _wait(0.43)
		vm.fire()
	await _wait(0.15)
	_save("burst")
	await _wait(1.6)
	_save("barrel_smoke")
	print("gold ", gs.gold, " loaded ", gs.loaded)
	for d in main.find_children("*", "Decal", true, false):
		if d.visible:
			print("hole ", d.get_parent().name, " at ", d.global_position.snappedf(0.01), " size ", d.size, " up ", d.global_basis.y.snappedf(0.01))
	var cam := Camera3D.new()
	main.add_child(cam)
	var face: Vector3 = dummy.global_position + Vector3(0, 1.0, 0)
	cam.look_at_from_position(face + (player.global_position - dummy.global_position).normalized() * 1.3 + Vector3(0, 0.15, 0), face)
	cam.make_current()
	player.get_node("ViewmodelView").visible = false
	await _wait(0.3)
	_save("holes")
	player.get_node("ViewmodelView").visible = true
	player.get_node("Head/Camera3D").make_current()
	_aim(player, Vector3(26.4, 0.5, 9.0))  # the barriers past the dummy
	await _wait(0.45)
	vm.fire()
	await _wait(0.06)
	_save("wall_hit")
	gs.player().levels["magazine"] = 0
	gs.player().gold = 30
	gs.gold_changed.emit(30)
	player.get_node("UpgradeMenu").toggle()
	await _wait(0.3)
	_save("menu")
	print("buy ", gs.request_buy_upgrade("magazine"), " gold ", gs.gold, " cap ", gs.mag_capacity)
	await _wait(0.1)
	_save("menu_bought")
	quit()


func _aim(player: Node3D, at: Vector3) -> void:
	var d := at - (player.global_position + Vector3.UP * 1.6)
	player._yaw = atan2(-d.x, -d.z)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _save(shot_name: String) -> void:
	root.get_texture().get_image().save_png("user://dummy_%s.png" % shot_name)
	print("saved ", shot_name)
