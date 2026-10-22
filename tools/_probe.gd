extends SceneTree
func _initialize() -> void:
	var s: Node3D = load("res://assets/weapons/arms/arms.gltf").instantiate()
	root.add_child(s)
	await process_frame
	var sk: Skeleton3D = s.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
	print("clips ", Array(ap.get_animation_list()).filter(func(n): return n.begins_with("Minigun")))
	var body := sk.find_bone("Minigun_M-134_Body")
	for c in ["Minigun_Idle", "Minigun_Fire", "Minigun_Reload", "Deagle_Idle"]:
		ap.play(c); ap.seek(0.3, true); ap.advance(0.0)
		var g := sk.get_bone_global_pose(body)
		print(c, " body ", g.origin, " handR ", sk.get_bone_global_pose(sk.find_bone("DEF-hand.R")).origin, " handL ", sk.get_bone_global_pose(sk.find_bone("DEF-hand.L")).origin, " mainhand ", sk.get_bone_global_pose(sk.find_bone("Main_hand")).origin, " second ", sk.get_bone_global_pose(sk.find_bone("Second_Hand")).origin)
	# muzzle/port in body-bone space at Idle
	ap.play("Minigun_Idle"); ap.seek(0.0, true); ap.advance(0.0)
	var mi: MeshInstance3D = sk.get_node("Minigun")
	var bind := {}
	for i in mi.skin.get_bind_count():
		bind[i] = sk.get_bone_global_pose(sk.find_bone(mi.skin.get_bind_name(i))) * mi.skin.get_bind_pose(i)
	var pts := PackedVector3Array()
	for si in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(si)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]; var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var k := bo.size() / v.size()
		for j in v.size():
			var p := Vector3.ZERO
			for c in k:
				if w[j * k + c] > 0.0: p += (bind[bo[j * k + c]] * v[j]) * w[j * k + c]
			pts.append(p)
	var lo := Vector3.INF; var hi := -Vector3.INF
	for q in pts: lo = lo.min(q); hi = hi.max(q)
	var front := AABB(); var first := true
	for q in pts:
		if q.z > hi.z - 0.01:
			if first: front = AABB(q, Vector3.ZERO); first = false
			else: front = front.expand(q)
	var inv := sk.get_bone_global_pose(body).affine_inverse()
	print("aabb ", lo, " .. ", hi, " front ", front.position, "..", front.end, " centre->body ", inv * front.get_center())
	for f: float in [0.2, 0.35, 0.5, 0.65]:
		var z0 := lo.z + (hi.z - lo.z) * f
		var b := AABB(); first = true
		for q in pts:
			if absf(q.z - z0) < 0.015:
				if first: b = AABB(q, Vector3.ZERO); first = false
				else: b = b.expand(q)
		print("slice z %.3f x[%.3f %.3f] y[%.3f %.3f] -> right-mid body-space %s" % [z0, b.position.x, b.end.x, b.position.y, b.end.y, inv * Vector3(b.position.x, (b.position.y + b.end.y) * 0.5, z0)])
	print("eye skel ", Vector3(-0.0082, 1.4235 + 0.1079, 0.0212))
	quit()
