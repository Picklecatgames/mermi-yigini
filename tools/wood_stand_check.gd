extends SceneTree
## The wood's trees stand and are solid (2026-11-04, the user: "most of these trees stand in the air,
## and you walk through them"). Reads the built scene: each tree's foot in the ground, wood where the
## ground meets it, and from all round, at chest height, the physics stops a ray at its posts.
##   Godot.exe --headless --path . -s res://tools/wood_stand_check.gd
const CHEST := 1.2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	# The scene's scripts ask the game for things; only its bodies are wanted here.
	var forest: Node = world.get_node("Forest")
	var rows: Array = forest.get_meta("stand")
	var trunks: StaticBody3D = forest.get_node("Trunks")
	world.remove_child(forest)
	forest.set_script(null)
	root.add_child(forest)
	await physics_frame
	await physics_frame
	var space := (forest as Node3D).get_world_3d().direct_space_state
	var bad_air := 0
	var bad_wood := {}
	var bad_solid := 0
	var no_posts := {}
	for row: Array in rows:
		var foot: Vector3 = row[1]
		if foot.y > row[2]:
			bad_air += 1
		if not row[3]:
			bad_wood[row[0]] = true
		var posts: PackedVector3Array = row[4]
		if posts.is_empty():
			no_posts[row[0]] = true
			continue
		var aim := Vector3(posts[0].x, posts[0].y, posts[0].z)
		for at: Vector3 in posts:
			if absf(at.y - foot.y - CHEST) < absf(aim.y - foot.y - CHEST):
				aim = at
		var stopped := 0
		for i in 4:
			var d := Vector3.RIGHT.rotated(Vector3.UP, TAU * i / 4.0) * 3.0
			var q := PhysicsRayQueryParameters3D.create(aim + d, aim)
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and hit.collider == trunks:
				stopped += 1
		if stopped < 4:
			bad_solid += 1
	print("trees: ", rows.size())
	print("foot over the ground: ", bad_air)
	print("no wood where the ground meets the trunk: ", bad_wood.keys())
	print("no posts: ", no_posts.keys())
	print("not solid from all round at chest height: ", bad_solid)
	var failed := bad_air > 0 or not bad_wood.is_empty() or not no_posts.is_empty() or bad_solid > 0
	print("wood_stand_check: ", "FAILED" if failed else "passed")
	world.free()
	quit(1 if failed else 0)
