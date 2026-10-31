extends SceneTree
## scratch: necks of heads blown off, close
const BODY := preload("res://scripts/zombie_body.gd")
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	var cam := Camera3D.new()
	cam.fov = 35.0
	main.add_child(cam)
	cam.make_current()
	var light := OmniLight3D.new()
	light.omni_range = 6.0
	light.light_energy = 2.0
	main.add_child(light)
	await process_frame
	var models := [&"prisoner", &"zombiegirl", &"whiteclown", &"maw"]
	var i := 0
	for m in models:
		var holder := Node3D.new()
		main.add_child(holder)
		holder.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(20, 0, 0))
		var body: Node3D = BODY.new()
		body.setup(&"walker", 3)
		body.model = m
		holder.add_child(body)
		await create_timer(0.4).timeout
		var sk: Skeleton3D = body.get("_skel")
		var neck := sk.to_global(sk.get_bone_global_pose(sk.get_bone_parent(body.get("_flinch").head)).origin)
		body.call("_head_shot", neck) if false else null
		body.die(&"head", true, 1234 + i, Vector3(1, 0, 0.2))
		await create_timer(0.08).timeout
		cam.look_at_from_position(neck + Vector3(-0.7, 0.45, 0.35), neck)
		light.global_position = neck + Vector3(-0.6, 0.7, 0.3)
		await create_timer(0.2).timeout
		root.get_texture().get_image().save_png("user://stump_%d.png" % i)
		i += 1
		holder.queue_free()
		await create_timer(0.1).timeout
	quit()
