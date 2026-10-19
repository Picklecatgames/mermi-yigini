extends SceneTree
## Headless check that aiming puts the rear notch and the front post on the view axis:
##   Godot.exe --headless --path . -s res://tools/ads_check.gd


func _initialize() -> void:
	await process_frame  # root enters the tree first
	var cam := Camera3D.new()
	root.add_child(cam)
	var vm: Node3D = load("res://scenes/viewmodel.tscn").instantiate()
	vm.set_process(false)
	cam.add_child(vm)
	var anim: AnimationPlayer = vm.get_node("Model/AnimationPlayer")
	anim.play("allanims")  # _ready started the draw; a section clamps seeks to itself
	anim.seek(vm.CLIPS["settle"][1], true)
	anim.advance(0.0)
	vm.transform = Transform3D(Basis(vm._ads_rot), vm._ads_pos)
	var talon: Node3D = vm.get_node("Model").find_child("Talon", true, false)
	var rear := cam.to_local(talon.to_global(vm.REAR_SIGHT))
	var front := cam.to_local(talon.to_global(vm.FRONT_SIGHT))
	var muzzle := cam.to_local(talon.to_global(vm.MUZZLE))
	print("rear ", rear, " front ", front, " muzzle ", muzzle, " hip ", vm.position)
	var ok := absf(rear.x) < 1e-4 and absf(rear.y) < 1e-4 and absf(front.x) < 1e-4 and absf(front.y) < 1e-4 \
		and absf(rear.z + vm.ADS_EYE) < 1e-4 and front.z < rear.z
	# Every clip aiming can follow must end in the same pose, or the sights would wander.
	for t: float in [0.0, 0.433, 2.833, 3.3, 6.433]:
		anim.seek(t, true)
		anim.advance(0.0)
		var r := cam.to_local(talon.to_global(vm.REAR_SIGHT))
		var f := cam.to_local(talon.to_global(vm.FRONT_SIGHT))
		var off := maxf(Vector2(r.x, r.y).length(), Vector2(f.x, f.y).length())
		print("t=%.3f off-axis %.2f mm" % [t, off * 1000.0])
		ok = ok and off < 0.0005
	print("ADS_OK" if ok else "ADS_FAIL")
	quit(0 if ok else 1)
