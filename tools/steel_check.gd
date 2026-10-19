extends Node3D
## Headless check for the hanging steel targets (needs autoloads, so it runs as a scene):
##   Godot.exe --headless --path . res://tools/steel_check.tscn

func _ready() -> void:
	var rack: Node3D = load("res://scenes/steel_rack.tscn").instantiate()
	var gong: Node3D = load("res://scenes/steel_gong.tscn").instantiate()
	gong.position = Vector3(4, 0, 0)
	add_child(rack)
	add_child(gong)
	await get_tree().physics_frame
	var plates := rack.get_children().filter(func(n): return n.is_in_group("target"))
	assert(plates.size() == 5, "rack should hang five plates, got %d" % plates.size())
	var p: StaticBody3D = plates[2]
	var g: StaticBody3D = gong.get_children().filter(func(n): return n.is_in_group("target"))[0]
	# a ray from the front finds the plate
	var front := p.global_position + Vector3(0, -0.15, 3)
	var q := PhysicsRayQueryParameters3D.create(front, front + Vector3(0, 0, -6))
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	assert(hit and hit.collider == p, "ray from the front should hit the middle plate")
	# one centre hit: swings back (away from the shooter), does not flip
	_shoot(p, hit.position)
	_shoot(g, g.global_position + Vector3(0, -0.3, 0.02))
	var max_back := 0.0
	var max_gong := 0.0
	for i in 30:
		await get_tree().physics_frame
		max_back = maxf(max_back, p._swing)
		max_gong = maxf(max_gong, absf(g._swing))
	print("one hit: plate %.0f°, gong %.0f°" % [rad_to_deg(max_back), rad_to_deg(max_gong)])
	assert(max_back > deg_to_rad(20) and max_back < deg_to_rad(150), "a light plate swings well back, not over")
	assert(max_gong > deg_to_rad(2) and max_gong < deg_to_rad(20), "the heavy gong barely moves")
	# three low hits in a row go over the bar
	var flipped := false
	for k in 3:
		_shoot(p, p.global_transform * Vector3(0, -0.28, 0.02))
		for i in 3:
			await get_tree().physics_frame
	for i in 120:
		await get_tree().physics_frame
		flipped = flipped or absf(p._swing) > deg_to_rad(170)
	print("three low hits flip: ", flipped)
	assert(flipped, "hit hard enough, a light plate goes over the bar")
	for i in 60 * 25:
		await get_tree().physics_frame
	print("after 25 s: plate %.1f° gong %.1f°" % [rad_to_deg(p._swing), rad_to_deg(g._swing)])
	assert(absf(p._swing_vel) < 0.05 and absf(g._swing_vel) < 0.05, "swings come to rest")
	print("steel_check OK")
	get_tree().quit()


func _shoot(target: Node, at: Vector3) -> void:
	GameState.shot_landed.emit(0, at, Vector3.BACK, Vector3.FORWARD, target, 0, false, 0)
