extends SceneTree
## The bench corner and a zombie as they are (left) and low poly (right), side by side, as PNGs to
## look at without playing (tools/lowpoly.py, tools/lowpoly_zombie.gd).
##   Godot.exe --path . --position -10000,-10000 --resolution 1600x900 -s res://tools/lowpoly_shots.gd
## Shots land in user:// as lowpoly_<name>.png.

const PROPS := [
	["workbench/workbench", "workbench", Vector3.ZERO, 0.0],
	["press/press", "press", Vector3(0.8, 0.779, -0.11), 0.0],
	["workbench/hopper", "hopper", Vector3(2.064, 0, 0.25), 0.0],
	["radio/radio", "radio", Vector3(-0.38, 1.293, -0.275), 0.45],
	["wall_lamp/wall_lamp", "wall_lamp", Vector3(-0.108, 2.8, -0.45), 0.0],
]
const ZOMBIE := "prisoner"
const GAP := 4.5  # m between the two copies


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.7, 0.78)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(30, 30)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.42, 0.38)
	ground.material_override = gm
	world.add_child(ground)

	for side in 2:
		var at := Vector3(side * GAP, 0, 0)
		for p: Array in PROPS:
			var path: String = "res://assets/props/%s.glb" % p[0] if side == 0 else "res://assets/lowpoly/%s.glb" % p[1]
			var inst: Node3D = (load(path) as PackedScene).instantiate()
			inst.position = at + p[2]
			inst.rotation.y = p[3]
			world.add_child(inst)
		var z: Node3D = load("res://assets/characters/zombies/%s/%s%s.scn" % [ZOMBIE, ZOMBIE, "" if side == 0 else "_lp"]).instantiate()
		z.position = at + Vector3(1.0, 0, 1.6)
		world.add_child(z)
		var sk: Skeleton3D = z.get_node("Skeleton3D")
		sk.motion_scale = sk.get_bone_global_rest(0).origin.y
		var ap := AnimationPlayer.new()
		z.add_child(ap)
		ap.add_animation_library("", load("res://assets/characters/zombies/zombie_anims.res"))
		var clip: StringName = ap.get_animation_list()[0]
		for c in ap.get_animation_list():
			if c == &"walk_a":
				clip = c
				break
		print("clip ", clip)
		ap.root_node = ^".."
		ap.play(clip)
		ap.seek(0.4, true)
		ap.speed_scale = 0.0  # held mid-stride, both alike

	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 55
	await _shot(cam, Vector3(GAP / 2.0 + 0.6, 2.2, 6.2), Vector3(GAP / 2.0 + 0.6, 1.0, 0), "both")
	for side in 2:
		var x := side * GAP
		await _shot(cam, Vector3(x + 0.4, 1.8, 2.4), Vector3(x + 0.4, 1.0, -0.2), "bench_%d" % side)
		await _shot(cam, Vector3(x + 1.0, 1.3, 3.5), Vector3(x + 1.0, 0.95, 1.6), "zombie_%d" % side)
	quit()


func _shot(cam: Camera3D, from: Vector3, to: Vector3, name: String) -> void:
	cam.look_at_from_position(from, to)
	for i in 6:
		await process_frame
	var file := "user://lowpoly_%s.png" % name
	root.get_viewport().get_texture().get_image().save_png(file)
	print("shot ", ProjectSettings.globalize_path(file))
