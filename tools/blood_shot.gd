extends SceneTree
## Off-screen shots of the blood (scripts/blood_fx.gd): a zombie in the hall a metre off the east
## wall, shot from the railing's side, then its head blown off. Saves user://blood_<n>.png.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/blood_shot.gd

const BODY := preload("res://scripts/zombie_body.gd")
const AT := Vector3(26.0, 0.0, 17.0)
const DIR := Vector3(1.0, -0.03, 0.08)  # from the railing on, into the wall


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.make_current()
	var holder := Node3D.new()
	main.add_child(holder)
	holder.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), AT)  # faces -X, toward the railing
	var body: Node3D = BODY.new()
	body.setup(&"walker", 5)
	holder.add_child(body)
	cam.look_at_from_position(AT + Vector3(-3.2, 1.5, -2.2), AT + Vector3(0.6, 1.1, 0.0))
	await create_timer(1.0).timeout
	for i in 3:
		body.wound(AT + Vector3(-0.1, 1.15 + i * 0.12, 0.05 * i), DIR.normalized(), false)
		await create_timer(0.08).timeout
	await _save("hit")
	await create_timer(1.5).timeout
	body.wound(AT + Vector3(-0.05, body.height - 0.15, 0.0), DIR.normalized(), true)
	body.die(&"head")
	await create_timer(0.12).timeout
	await _save("burst")
	await create_timer(3.0).timeout
	await _save("after")
	await create_timer(5.0).timeout
	await _save("pool")
	cam.look_at_from_position(AT + Vector3(-1.6, 1.0, 1.2), AT + Vector3(0.4, 0.2, 0.0))
	await _save("floor")
	cam.look_at_from_position(AT + Vector3(-0.5, 1.6, -2.0), AT + Vector3(1.9, 1.2, 0.0))
	await _save("wall")
	quit()


func _save(name: String) -> void:
	for f in 4:
		await process_frame
	root.get_texture().get_image().save_png("user://blood_%s.png" % name)
	print("saved ", ProjectSettings.globalize_path("user://blood_%s.png" % name))
