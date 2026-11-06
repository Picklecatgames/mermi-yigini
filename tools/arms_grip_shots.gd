extends SceneTree
## The first-person arms and gun on their own, seen from around the right hand (no PS1 screen, a
## plain grey room light): to judge how the hand closes on each grip, which the player's own view
## (arms_shots.gd) hides behind the gun.
##   Godot.exe --path . --position -10000,-10000 --resolution 960x720 -s res://tools/arms_grip_shots.gd -- --tag=T --holds=pistol,deagle
## user://grip_<T>_<hold>_<left|right|under|back>.png

const VIEWS := {  # camera offset from between the right hand and the gun's bone, in the view's space (x right, y up, z back)
	"left": Vector3(-0.28, 0.06, 0.04),
	"right": Vector3(0.28, 0.06, 0.04),
	"under": Vector3(0.1, -0.26, 0.0),
	"back": Vector3(0.03, 0.08, 0.3),
}


func _initialize() -> void:
	var tag := "x"
	var holds := PackedStringArray(["pistol", "deagle"])
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--holds="):
			holds = a.trim_prefix("--holds=").split(",")
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.player().character = "oldman"
	gs.player().infinite_ammo = true
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.33, 0.34)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.47, 0.5, 0.49)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.94, 0.94, 0.9)
	key.rotation = Vector3(-0.65, 0.4, 0.0)
	key.light_cull_mask = 0xFFFFF
	key.layers = 0xFFFFF
	world.add_child(key)
	var eye := Camera3D.new()  # the player's eye; the gun hangs off it as off the player's
	eye.fov = 60.0
	eye.cull_mask = 0xFFFFF
	world.add_child(eye)
	var vm: Node3D = load("res://scenes/viewmodel.tscn").instantiate()
	eye.add_child(vm)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.cull_mask = 0xFFFFF
	cam.near = 0.01
	world.add_child(cam)
	await _frames(10)
	var skel: Skeleton3D = vm.get(&"_skel")
	for hold: String in holds:
		var gun := 0
		for i in gs.GUNS.size():
			if gs.GUNS[i].id == hold:
				gun = i
		gs.player().gun = gun
		vm.call(&"equip", gun)
		await _frames(150)
		var hand := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("DEF-hand.R")).origin
		var bone: Node3D = vm.get(&"_attach")
		var at := hand.lerp(bone.global_position, 0.6) if gun > 0 else hand
		for v: String in VIEWS:
			var off: Vector3 = VIEWS[v]
			cam.look_at_from_position(at + eye.global_basis * off, at, eye.global_basis.y)
			cam.make_current()
			await _frames(4)
			var file := "user://grip_%s_%s_%s.png" % [tag, hold, v]
			root.get_viewport().get_texture().get_image().save_png(file)
			print(ProjectSettings.globalize_path(file))
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
