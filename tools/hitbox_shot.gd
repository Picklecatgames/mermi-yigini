extends SceneTree
## Off-screen shots of the zombies' hit shapes (scripts/waves.gd BONE_SHAPES) at the railing, drawn
## as see-through red capsules over the bodies: a walker clawing, a brute, a crawler, a walker that
## lost a leg, a runner and a dog, from behind the railing and from the side. Saves
## user://hitbox_<tag>_<n>.png.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/hitbox_shot.gd -- --tag=x

var _tag := "now"
var _cam: Camera3D
var _waves: Node


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	_waves = main.get_node("Waves")
	_cam = Camera3D.new()
	_cam.fov = 55.0
	main.add_child(_cam)
	_cam.make_current()
	for i in 3:
		await process_frame
	var x: float = _waves.RAIL_X
	var row := [[&"walker", "claw", -2.4], [&"brute", "idle", -0.8], [&"crawler", "idle", 0.6],
			[&"walker", "legless", 1.8], [&"runner", "walk", 3.0], [&"dog", "idle", 4.2]]
	var id := 800
	for r: Array in row:
		id += 1
		_waves._add_zombie(id, r[0], 11 + id, "", Vector3(x, 0, r[2]), PI / 2, 1.0, r[2], false)
		var z: Dictionary = _waves._zombies[id]
		match r[1]:
			"claw":
				z.body.attack()
			"walk":
				z.body.move(1.0)
			"legless":
				_waves._cut(z, &"leg_r", false)
				z.down = 0.0
				z.body.move(0.4)
	await create_timer(1.2).timeout
	_waves.set_process(false)  # hold the poses still while the shapes are drawn
	for z: Dictionary in _waves._zombies.values():
		z.body.set_process(false)
		_draw_shapes(z.node)
	var mid := Vector3(x, 0.8, 0.9)
	_cam.look_at_from_position(Vector3(11.8, 1.6, 0.9), mid)
	await _save("front")
	_cam.look_at_from_position(Vector3(x - 1.2, 1.3, -4.5), mid + Vector3(0, -0.2, 0))
	await _save("side")
	_cam.look_at_from_position(Vector3(12.9, 1.1, -1.4), Vector3(x, 0.5, -1.4))
	await _save("low")
	quit()


func _draw_shapes(body: CollisionObject3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.1, 0.1, 0.35)
	mat.no_depth_test = true
	for cs in body.get_children():
		if not cs is CollisionShape3D or cs.disabled:
			continue
		var m := MeshInstance3D.new()
		if cs.shape is CapsuleShape3D:
			var c := CapsuleMesh.new()
			c.radius = cs.shape.radius
			c.height = cs.shape.height
			m.mesh = c
		elif cs.shape is SphereShape3D:
			var s := SphereMesh.new()
			s.radius = cs.shape.radius
			s.height = cs.shape.radius * 2.0
			m.mesh = s
		m.material_override = mat
		cs.add_child(m)


func _save(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("user://hitbox_%s_%s.png" % [_tag, name])
