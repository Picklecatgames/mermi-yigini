extends SceneTree
## Headless check that aiming puts each gun's rear and front sight on the view axis (the guns
## without aim clips of their own; scripts/viewmodel.gd SETS rear / front), and that one aimed shot
## flips the front sight up fast and brings it back before the next:
##   Godot.exe --headless --path . -s res://tools/ads_check.gd


func _initialize() -> void:
	await process_frame  # root enters the tree first
	var cam := Camera3D.new()
	root.add_child(cam)
	var vm: Node3D = load("res://scenes/viewmodel.tscn").instantiate()
	vm.set_process(false)
	cam.add_child(vm)
	var gs: Node = root.get_node("GameState")
	var ok := true
	for g in gs.GUNS.size():
		var set: Dictionary = vm.SETS.get(gs.GUNS[g].id, {})
		if not set.has("rear"):
			continue
		vm._want_gun = g
		vm._swap()
		var anim: AnimationPlayer = vm.get_node("Model/AnimationPlayer")
		var sk: Skeleton3D = vm._skel
		var bone := sk.find_bone(set.bone)
		var on_axis := func(at: Vector3) -> Vector3:
			return cam.to_local(sk.global_transform * sk.get_bone_global_pose(bone) * at)
		anim.play(set.clips + "Idle")  # the pose the sights were measured in
		anim.seek(0.0, true)
		anim.advance(0.0)
		vm.transform = Transform3D(Basis(vm._ads_rot), vm._ads_pos)
		var rear: Vector3 = on_axis.call(set.rear)
		var front: Vector3 = on_axis.call(set.front)
		var muzzle: Vector3 = on_axis.call(set.muzzle)
		print("%s: rear %s front %s muzzle %s" % [gs.GUNS[g].id, rear, front, muzzle])
		var good := absf(rear.x) < 1e-4 and absf(rear.y) < 1e-4 and absf(front.x) < 1e-4 and absf(front.y) < 1e-4 \
			and absf(rear.z + float(set.ads_eye)) < 1e-4 and front.z < rear.z and muzzle.z < front.z + 0.05
		vm.aim = 1.0
		vm._add_kick(1.0)
		var peak := 0.0
		var peak_t := 0.0
		var tilt := 0.0
		for i in 50:  # 0.42 s at 120 fps, one shot interval
			vm._sway_and_bob(1.0 / 120.0)
			var r: Vector3 = on_axis.call(set.rear)
			var f: Vector3 = on_axis.call(set.front)
			tilt = atan2(f.y - r.y, r.z - f.z)  # front sight above the rear, rad
			if tilt > peak:
				peak = tilt
				peak_t = (i + 1) / 120.0
		print("  flip peak %.1f deg at %d ms, left after one interval %.2f deg" % [rad_to_deg(peak), peak_t * 1000.0, rad_to_deg(tilt)])
		good = good and peak > 0.05 and peak_t < 0.07 and absf(tilt) < 0.005
		vm.aim = 0.0
		vm._push = 0.0
		vm._push_vel = 0.0
		vm._kick = 0.0
		vm._kick_vel = 0.0
		ok = ok and good
	print("ADS_OK" if ok else "ADS_FAIL")
	quit(0 if ok else 1)
