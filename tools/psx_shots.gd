extends SceneTree
## The PS1 horror zombies (tools/lowpoly_zombie.gd psx) at night under one work lamp, as PNGs to
## look at without playing. The screen is brought down the way the look will be in the game: drawn
## small (SCREEN), 15-bit colour with ordered dither, blown up unfiltered.
##   Godot.exe --path . --position -10000,-10000 --resolution 1600x900 -s res://tools/psx_shots.gd
## Shots land in user:// as psx_<name>.png; psx_compare is the prisoner as built (left) and PS1.

const ZOMBIES := ["prisoner", "copzombie", "zombiegirl"]
const SCREEN := Vector2i(400, 225)
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.025, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.4, 0.5)
	e.ambient_light_energy = 0.25
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.06, 0.07)
	e.fog_density = 0.09
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0, 4.0, 2.5)
	lamp.basis = Basis.looking_at(Vector3(0, -1, -0.45), Vector3.FORWARD)
	lamp.light_color = Color(1.0, 0.72, 0.45)
	lamp.light_energy = 6.0
	lamp.spot_range = 12.0
	lamp.spot_angle = 50.0
	lamp.shadow_enabled = true
	world.add_child(lamp)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(40, 40)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.2, 0.18)
	ground.material_override = gm
	world.add_child(ground)

	var xs := [-1.3, 0.0, 1.3]
	for i in ZOMBIES.size():
		_zombie(world, "res://assets/characters/zombies/%s/%s_psx.scn" % [ZOMBIES[i], ZOMBIES[i]],
				Vector3(xs[i], 0, -0.4 * (i % 2)), 0.3 + i * 0.37)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 60
	await _shot(cam, Vector3(0, 1.6, 4.0), Vector3(0, 1.1, 0), "group", true)
	await _shot(cam, Vector3(-1.3, 1.65, 1.3), Vector3(-1.3, 1.5, 0), "face", true)

	for n in world.get_children():
		if n.has_meta("zombie"):
			n.free()
	_zombie(world, "res://assets/characters/zombies/prisoner/prisoner.scn", Vector3(-0.6, 0, 0), 0.3)
	_zombie(world, "res://assets/characters/zombies/prisoner/prisoner_psx.scn", Vector3(0.6, 0, 0), 0.3)
	await _shot(cam, Vector3(0, 1.4, 2.6), Vector3(0, 1.0, 0), "compare", false)
	quit()


func _zombie(world: Node3D, path: String, at: Vector3, t: float) -> void:
	var z: Node3D = load(path).instantiate()
	z.position = at
	z.set_meta("zombie", true)
	world.add_child(z)
	var sk: Skeleton3D = z.get_node("Skeleton3D")
	sk.motion_scale = sk.get_bone_global_rest(0).origin.y
	var ap := AnimationPlayer.new()
	z.add_child(ap)
	ap.root_node = ^".."
	ap.add_animation_library("", load("res://assets/characters/zombies/zombie_anims.res"))
	ap.play(&"walk_a")
	ap.seek(t, true)
	ap.speed_scale = 0.0


func _shot(cam: Camera3D, from: Vector3, to: Vector3, name: String, ps1: bool) -> void:
	cam.look_at_from_position(from, to)
	for i in 8:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var size := img.get_size()
	if ps1:
		img.resize(SCREEN.x, SCREEN.y, Image.INTERPOLATE_NEAREST)
		for y in SCREEN.y:
			for x in SCREEN.x:
				var c := img.get_pixel(x, y)
				var d: float = (BAYER[(y % 4) * 4 + x % 4] / 16.0 - 0.5) / 31.0
				img.set_pixel(x, y, Color(roundf((c.r + d) * 31.0) / 31.0, roundf((c.g + d) * 31.0) / 31.0, roundf((c.b + d) * 31.0) / 31.0))
		img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var file := "user://psx_%s.png" % name
	img.save_png(file)
	print("shot ", ProjectSettings.globalize_path(file))
