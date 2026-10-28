extends SceneTree
## Puts a scarecrow up next to the dummy and saves screenshots: from the firing line, up close
## from the front and the side, and burning after a hit:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/scarecrow_shot.gd


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var player: CharacterBody3D = main.get_node("Player")
	var crow: Node3D = load("res://scenes/scarecrow.tscn").instantiate()
	crow.position = Vector3(21, 0, 2.5)
	crow.rotation.y = -PI / 2  # faces the firing line, as placement turns it
	main.add_child(crow)
	await process_frame
	player.global_position = Vector3(11, 0, 1.2)
	_aim(player, crow.global_position + Vector3(0, 1.1, 0))
	await _wait(1.5)
	_save("line")
	var cam := Camera3D.new()
	main.add_child(cam)
	var mid: Vector3 = crow.global_position + Vector3(0, 1.0, 0)
	cam.look_at_from_position(mid + crow.global_basis.z * 3.2 + Vector3(0, 0.2, 0), mid)
	cam.make_current()
	player.get_node("ViewmodelView").visible = false
	await _wait(0.3)
	_save("front")
	cam.look_at_from_position(mid + crow.global_basis.x * 3.2 + Vector3(0, 0.2, 0), mid)
	await _wait(0.3)
	_save("side")
	cam.look_at_from_position(mid + crow.global_basis.z * 3.2 + Vector3(0, 0.2, 0), mid)
	gs.request_take_pistol()  # off the desk at the spawn: drawn at once
	gs.infinite_ammo = true
	gs.player().loaded = 1
	var from := Vector3(11, 1.6, crow.global_position.z)
	gs.request_fire(from, (crow.global_position + Vector3(0, 1.0, 0) - from).normalized())
	await _wait(1.2)
	_save("burning")
	quit()


func _aim(player: Node3D, at: Vector3) -> void:
	var d := at - (player.global_position + Vector3.UP * 1.6)
	player._yaw = atan2(-d.x, -d.z)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _save(shot_name: String) -> void:
	root.get_texture().get_image().save_png("user://scarecrow_%s.png" % shot_name)
	print("saved ", shot_name)
