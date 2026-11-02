extends "res://tools/build_arena.gd"
## Builds scenes/world.tscn, the open ground (2026-11-02, the user: the old hall and everything in it
## goes; a wide rectangle out in the open, Mad Max wasteland, a light desert with a few dead trees):
## a concrete pad, on it the workshop (open to the front, a lean-to roof on posts, the crew's bench
## with its radio and the desk with the pistol brought over from the hall) and, until the scrap
## mountain comes, the scrap pit; round it sand and cracked earth rising into dunes at the edges.
## The scene is never edited by hand: change the numbers here and re-run
##   godot --headless --path . -s res://tools/build_world.gd
## The helpers (add, worn, pbr_box, _prop, block, collide, pendant, _pit...) are build_arena.gd's.

const WORLD := Rect2(-200.0, -130.0, 400.0, 260.0)  # x, z: everything the players can see the ground of
const PAD := Rect2(-28.0, -24.0, 64.0, 48.0)  # the concrete; edges on the desert grid (CELL)
const CELL := 4.0  # m, the desert mesh's grid
const DUNE_START := 6.0  # m from the pad's edge where the ground starts to roll
const EDGE_RISE := 26.0  # m the dunes climb to at the world's edge: the players' natural border
const EDGE_REACH := 45.0  # m in from the edge over which they climb

## The workshop: back wall on x = WS.position.x, open towards +x (the yard, the spawns).
const WS := Rect2(2.0, -9.0, 10.0, 18.0)
const WS_BACK_H := 4.6  # m, the roof over the back wall
const WS_FRONT_H := 3.8  # m, its front edge: the lean-to drains forwards
const WS_POSTS: Array[float] = [-9.0, -4.5, 0.0, 4.5, 9.0]  # z of each post line, front and back
const WS_SIDE_WALL := 5.0  # m of sheeting down each side from the back; the front half open
const BENCH_AT := Vector3(2.6, 0, -3.0)  # the crew's bench, its back on the back wall
const BENCH_SCALE := 1.2  # as it stood in the hall (range_dressing.gd _workshop)
const DESK_AT := Vector3(9.6, 0, 0.0)  # the pistol's desk, right in front of the spawns

const SPAWNS_WORLD: Array[Vector3] = [Vector3(11.0, 0, -0.8), Vector3(11.0, 0, 0.8), Vector3(11.0, 0, -2.4), Vector3(11.0, 0, 2.4)]
const SUN_ANGLE := Vector3(-48.0, -125.0, 0.0)  # deg: afternoon, from behind the workshop's left


func _initialize() -> void:
	seed(11)
	arena = Node3D.new()
	arena.name = "World"
	_sky()
	_pad()
	_desert()
	_wasteland()
	_workshop_shed()
	_workshop_inside()
	_world_spawns()
	_lighten(arena, Transform3D())
	var scene := PackedScene.new()
	print("pack: ", scene.pack(arena), " save: ", ResourceSaver.save(scene, "res://scenes/world.tscn"))
	arena.free()
	quit()


## Open sky over a desert: a hot hazy blue going dusty at the horizon, the sun and a sandy fog that
## swallows the far dunes. The day-night cycle (scripts/day_night.gd, coming) takes these over.
func _sky() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.52, 0.72)
	sky_mat.sky_horizon_color = Color(0.86, 0.74, 0.6)
	sky_mat.ground_bottom_color = Color(0.36, 0.28, 0.2)
	sky_mat.ground_horizon_color = Color(0.86, 0.74, 0.6)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.1
	env.ssao_power = 1.2
	env.ssao_detail = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.6
	env.fog_enabled = true  # dust hanging over the desert: the far dunes fade into it
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.84, 0.72, 0.58)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.4
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ANGLE
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.light_angular_distance = 0.5
	add(sun)


## The concrete: filthy cracked slabs (Poly Haven "Dirty Concrete"), each 4 m pour its own tone,
## sand blown onto it, round the pit's opening; under it ground a metre thick.
func _pad() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	add(body)
	var slabs := worn("dirty_concrete", "yard_concrete", {"tint": Color(0.8, 0.74, 0.66), "tex_size": 4.0,
		"cell_size": 4.0, "cell_tone": 0.12, "odd_cells": 0.1, "antitile": 0.5, "grime": 0.9,
		"grime_scale": 0.08, "grime_color": Color(0.42, 0.33, 0.22)})  # the grime is blown sand, not soot
	for r in _around_pit(PAD):
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = r.size
		mi.mesh = pm
		mi.position = Vector3(r.get_center().x, 0, r.get_center().y)
		mi.material_override = slabs
		mi.layers = 1 | FLOOR_PAINT
		add(mi, body)
		collide(Vector3(r.size.x, 1.0, r.size.y), Vector3(r.get_center().x, -0.5, r.get_center().y), body)
	# The pad's edge: a broken kerb of the same concrete, a hand high, so it ends instead of fading.
	var kerb := pbr_box("concrete_slab_wall", 2.0, Color(0.7, 0.64, 0.56), true, "yard_kerb")
	for side in [[Vector3(PAD.size.x + 0.4, 0.12, 0.2), Vector3(PAD.get_center().x, 0.06, PAD.position.y - 0.1)],
			[Vector3(PAD.size.x + 0.4, 0.12, 0.2), Vector3(PAD.get_center().x, 0.06, PAD.end.y + 0.1)],
			[Vector3(0.2, 0.12, PAD.size.y), Vector3(PAD.position.x - 0.1, 0.06, PAD.get_center().y)],
			[Vector3(0.2, 0.12, PAD.size.y), Vector3(PAD.end.x + 0.1, 0.06, PAD.get_center().y)]]:
		block(side[0], side[1], kerb, body)
	_pit(body)


## Height of the desert at (x, z): flat at the pad, rolling dunes further out, climbing steeply into
## a ring of high dunes near the world's edge that nobody walks over.
func _ground_y(x: float, z: float, noise: FastNoiseLite) -> float:
	var dx := maxf(maxf(PAD.position.x - x, x - PAD.end.x), 0.0)
	var dz := maxf(maxf(PAD.position.y - z, z - PAD.end.y), 0.0)
	var away := Vector2(dx, dz).length()
	var roll := smoothstep(DUNE_START, DUNE_START + 40.0, away)
	var h := (noise.get_noise_2d(x, z) * 0.5 + 0.5) * 3.2 * roll
	var edge := minf(minf(x - WORLD.position.x, WORLD.end.x - x), minf(z - WORLD.position.y, WORLD.end.y - z))
	h += pow(1.0 - clampf(edge / EDGE_REACH, 0.0, 1.0), 1.6) * EDGE_RISE * (0.75 + 0.5 * (noise.get_noise_2d(x * 0.3, z * 0.3) * 0.5 + 0.5))
	return h


## The desert: one grid mesh over WORLD with the pad's cells left out, its collision the same
## triangles. Sand, cracked earth and gravel are materials/env/desert.gdshader.
func _desert() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 41
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var nx := int(WORLD.size.x / CELL)
	var nz := int(WORLD.size.y / CELL)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in nx:
		for j in nz:
			var x0 := WORLD.position.x + i * CELL
			var z0 := WORLD.position.y + j * CELL
			if PAD.encloses(Rect2(x0, z0, CELL, CELL)):
				continue
			var q: Array[Vector3] = []
			for c in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var x: float = x0 + c.x * CELL
				var z: float = z0 + c.y * CELL
				q.append(Vector3(x, _ground_y(x, z, noise), z))
			for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
				st.add_vertex(v)
				faces.append(v)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/env/desert.gdshader")
	for slot in [["sand", "sand_01"], ["earth", "dry_ground_01"], ["gravel", "gravel_floor_02"]]:
		mat.set_shader_parameter(slot[0] + "_albedo", load(TEX + "%s/%s_diff_2k.jpg" % [slot[1], slot[1]]))
		mat.set_shader_parameter(slot[0] + "_normal", load(TEX + "%s/%s_nor_gl_2k.jpg" % [slot[1], slot[1]]))
		mat.set_shader_parameter(slot[0] + "_arm", load(TEX + "%s/%s_arm_2k.jpg" % [slot[1], slot[1]]))
	var n2 := FastNoiseLite.new()
	n2.frequency = 0.02
	n2.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = n2
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	mat.set_shader_parameter("noise_tex", tex)
	mat.set_shader_parameter("pad", Vector4(PAD.position.x, PAD.position.y, PAD.end.x, PAD.end.y))
	ResourceSaver.save(mat, "res://materials/env/desert.tres")
	var body := StaticBody3D.new()
	body.name = "Desert"
	add(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = load("res://materials/env/desert.tres")
	add(mi, body)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add(cs, body)
	_desert_noise = noise


var _desert_noise: FastNoiseLite


## Out on the sand: dead trees in loose clumps, dry weeds, a wrecked car, tyres and drums.
func _wasteland() -> void:
	var root := Node3D.new()
	root.name = "Wasteland"
	add(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var spots := func(count: int, near: float, far: float) -> Array[Vector3]:
		var out: Array[Vector3] = []
		while out.size() < count:
			var p := Vector2(rng.randf_range(WORLD.position.x + 20.0, WORLD.end.x - 20.0), rng.randf_range(WORLD.position.y + 20.0, WORLD.end.y - 20.0))
			var away := Rect2(PAD.position - Vector2(near, near), PAD.size + Vector2(near, near) * 2.0)
			var too_far := Rect2(PAD.position - Vector2(far, far), PAD.size + Vector2(far, far) * 2.0)
			if away.has_point(p) or not too_far.has_point(p):
				continue
			out.append(Vector3(p.x, _ground_y(p.x, p.y, _desert_noise), p.y))
		return out
	# Trees: clumps of two to four, so it reads as a thinned-out dead wood, not a scatter.
	for centre: Vector3 in spots.call(16, 12.0, 120.0):
		for k in rng.randi_range(2, 4):
			var p := centre + Vector3(rng.randf_range(-6.0, 6.0), 0, rng.randf_range(-6.0, 6.0))
			p.y = _ground_y(p.x, p.z, _desert_noise) - 0.15
			var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
			_prop(root, MODELS + "dead_quiver_branch_02/dead_quiver_branch_02_1k.gltf", p, rng.randf() * TAU, rng.randf_range(4.0, 6.5), tilt)  # a branch scan grown into a dead tree
	for p: Vector3 in spots.call(40, 4.0, 90.0):
		var weed := "weed_plant_02/weed_plant_02_1k.gltf" if rng.randf() < 0.6 else "nettle_plant/nettle_plant_1k.gltf"
		var inst: Node3D = (load(MODELS + weed) as PackedScene).instantiate()
		inst.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), p)
		add(inst, root)
	for p: Vector3 in spots.call(3, 14.0, 60.0):
		_prop(root, MODELS + "covered_car/covered_car_1k.gltf", p, rng.randf() * TAU, 1.0, Basis(Vector3.FORWARD, rng.randf_range(-0.05, 0.05)))
	for p: Vector3 in spots.call(10, 3.0, 50.0):
		var junk: String = ["old_tyre/old_tyre_1k.gltf", "barrel_03/barrel_03_1k.gltf", "rusted_wheel_rim_01/rusted_wheel_rim_01_1k.gltf"][rng.randi() % 3]
		_prop(root, MODELS + junk, p, rng.randf() * TAU)


## The workshop's shell: steel posts on the post lines, a beam along the front and back, rafters
## down the slope, a corrugated lean-to roof, rusty sheet on the back wall and the back of each side.
func _workshop_shed() -> void:
	var shed := StaticBody3D.new()
	shed.name = "Workshop"
	add(shed)
	var steel: Material = pbr_box("rust_coarse_01", 1.5, Color(0.55, 0.5, 0.46), true, "workshop_steel")
	var sheet: Material = pbr_box("rusty_corrugated_iron", 2.0, Color.WHITE, true, "workshop_sheet")
	var roof_mat: Material = pbr_box("corrugated_iron_02", 2.0, Color(0.85, 0.8, 0.74), true, "workshop_roof")
	var x0 := WS.position.x
	var x1 := WS.end.x
	var roof_y := func(x: float) -> float: return WS_BACK_H + (x - x0) / (x1 - x0) * (WS_FRONT_H - WS_BACK_H)
	for z: float in WS_POSTS:
		for x: float in [x0 + 0.1, x1 - 0.1]:
			var h: float = roof_y.call(x) - 0.12
			block(Vector3(0.16, h, 0.16), Vector3(x, h * 0.5, z), steel, shed)
			collide(Vector3(0.16, h, 0.16), Vector3(x, h * 0.5, z), shed)
			block(Vector3(0.4, 0.02, 0.4), Vector3(x, 0.01, z), steel, shed)  # base plate
		# The rafter under the roof, front to back.
		var run := Vector3(x1 - x0, WS_FRONT_H - WS_BACK_H, 0)
		var slope := Basis(Vector3.BACK, atan2(run.y, run.x))
		block(Vector3(run.length() + 0.3, 0.16, 0.1), Vector3((x0 + x1) * 0.5, (WS_BACK_H + WS_FRONT_H) * 0.5 - 0.12, z), steel, shed, slope)
	for x: float in [x0 + 0.1, x1 - 0.1]:  # the eaves beams along the front and back
		block(Vector3(0.12, 0.2, WS.size.y + 0.3), Vector3(x, roof_y.call(x) - 0.22, WS.get_center().y), steel, shed)
	# The roof: one sheet along the slope, overhanging all round, purlins under it.
	var run := Vector2(x1 - x0 + 1.2, WS_FRONT_H - WS_BACK_H)
	var tilt := Basis(Vector3.BACK, atan2(run.y, run.x - 1.2))
	var roof := block(Vector3(run.length(), 0.05, WS.size.y + 1.0), Vector3((x0 + x1) * 0.5 + 0.3, (WS_BACK_H + WS_FRONT_H) * 0.5 + 0.02, WS.get_center().y), roof_mat, shed, tilt)
	roof.name = "Roof"
	collide(Vector3(run.length(), 0.05, WS.size.y + 1.0), roof.position, shed, tilt)
	overhead(roof)
	for i in 5:
		var x := x0 + 0.6 + i * (x1 - x0 - 1.2) / 4.0
		block(Vector3(0.08, 0.1, WS.size.y + 0.3), Vector3(x, roof_y.call(x) - 0.03, WS.get_center().y), steel, shed)
	# Back wall and the back of each side: rusty sheet, a hand off the concrete.
	block(Vector3(0.05, WS_BACK_H - 0.1, WS.size.y), Vector3(x0 - 0.02, (WS_BACK_H - 0.1) * 0.5 + 0.05, WS.get_center().y), sheet, shed)
	collide(Vector3(0.2, WS_BACK_H, WS.size.y), Vector3(x0 - 0.1, WS_BACK_H * 0.5, WS.get_center().y), shed)
	for z: float in [WS.position.y - 0.02, WS.end.y + 0.02]:
		var x_mid := x0 + WS_SIDE_WALL * 0.5
		var h: float = roof_y.call(x0 + WS_SIDE_WALL) - 0.1
		block(Vector3(WS_SIDE_WALL, h, 0.05), Vector3(x_mid, h * 0.5 + 0.05, z), sheet, shed)
		collide(Vector3(WS_SIDE_WALL, h, 0.2), Vector3(x_mid, h * 0.5, z), shed)


## Inside: the crew's bench from the hall with the press, the hopper and the radio playing its
## 78s, the wall lamp over it; the desk with the pistol at the front; shelves, a tool chest, a
## generator, crates; three pendants under the roof; a fire in a burn barrel out in front.
func _workshop_inside() -> void:
	var root := Node3D.new()
	root.name = "Bench"
	add(root)
	var yaw := PI / 2.0  # the bench's front (+z in its glb) to the yard
	var bench: StaticBody3D = _prop(root, "res://assets/props/workbench/workbench.glb", BENCH_AT, yaw, BENCH_SCALE)
	bench.set_script(preload("res://scripts/bench_top.gd"))
	var press: StaticBody3D = _prop(bench, "res://assets/props/press/press.glb", Vector3(0.8, 0.779, -0.11), 0.0)
	press.name = "Press"
	press.set_script(preload("res://scripts/press.gd"))
	# The hopper on the bench's right, as in the hall (range_dressing.gd _workshop): 2.06 m along its x.
	var hopper: StaticBody3D = _prop(root, "res://assets/props/workbench/hopper.glb", BENCH_AT + Basis(Vector3.UP, yaw) * Vector3(2.064, 0, 0.25), yaw)
	hopper.set_script(preload("res://scripts/hopper.gd"))
	_bench_radio(bench)
	_bench_lamp(BENCH_AT + Basis(Vector3.UP, yaw) * Vector3(-0.108, 2.8, -0.45))
	# The desk with the pistol on it (scripts/gun_table.gd), its drawer side to the spawns.
	var desk := _prop(root, MODELS + "metal_office_desk/metal_office_desk_1k.gltf", DESK_AT, PI / 2.0)
	desk.name = "GunTable"
	desk.set_script(preload("res://scripts/gun_table.gd"))
	# Along the walls.
	_prop(root, MODELS + "steel_frame_shelves_01/steel_frame_shelves_01_1k.gltf", Vector3(2.45, 0, 3.0), PI / 2.0, 0.1)  # the scan is 10x too big
	_prop(root, MODELS + "steel_frame_shelves_01/steel_frame_shelves_01_1k.gltf", Vector3(2.45, 0, 4.2), PI / 2.0, 0.1)
	_prop(root, MODELS + "metal_tool_chest/metal_tool_chest_1k.gltf", Vector3(3.2, 0, -8.4), 0.0)
	_prop(root, MODELS + "tool_cart/tool_cart_1k.gltf", Vector3(4.6, 0, -1.2), 0.4)
	_prop(root, MODELS + "portable_generator/portable_generator_1k.gltf", Vector3(5.6, 0, 8.3), 0.2)
	_prop(root, MODELS + "metal_jerrycan/metal_jerrycan_1k.gltf", Vector3(6.4, 0, 8.5), 0.5)
	_prop(root, MODELS + "wooden_military_crate/wooden_military_crate_1k.gltf", Vector3(2.8, 0, 7.9), 0.1)
	_prop(root, MODELS + "wooden_crate_01/wooden_crate_01_1k.gltf", Vector3(2.8, 0.465, 7.95), 0.25)
	_prop(root, MODELS + "small_lpg_tank/small_lpg_tank_1k.gltf", Vector3(2.5, 0, -6.2), 0.0)
	# Light under the roof: three old pendants (ambience.gd hums near the "Lamps").
	var lamps := Node3D.new()
	lamps.name = "Lamps"
	add(lamps)
	for z: float in [-5.0, 0.0, 5.0]:
		var top := Vector3(6.0, 3.1, z)
		var lamp := pendant(top, WS_BACK_H + (6.0 - WS.position.x) / WS.size.x * (WS_FRONT_H - WS_BACK_H) - 0.1, Color(1.0, 0.78, 0.5), 2.2, 60.0)
		arena.remove_child(lamp)
		lamp.owner = null
		lamps.add_child(lamp)
		_own(lamp)
	# A fire in the burn barrel in front of the workshop, where the crew stands at night.
	var stove: StaticBody3D = _prop(root, "res://assets/props/burn_barrel/burn_barrel.glb", Vector3(14.2, 0, -7.0), 0.4)
	var burning := Node3D.new()
	burning.name = "BarrelFire"
	burning.set_script(preload("res://scripts/barrel_fire.gd"))
	burning.set("rim", 0.914)
	burning.set("inner", 0.29)
	burning.set("bed", 0.545)
	burning.set("logs", false)
	add(burning, stove)
	_prop(root, MODELS + "old_tyre/old_tyre_1k.gltf", Vector3(15.3, 0.12, -6.2), 0.0, 1.0, Basis(Vector3.RIGHT, PI / 2.0))


## The crew's 1967 radio on the bench's shelf playing four Hawaiian guitar 78s in a loop, quietly
## (docs/ayrintilar.md "Radyo"); as range_dressing.gd _radio, in the bench's own frame.
func _bench_radio(bench: Node3D) -> void:
	var radio: Node3D = _prop(arena.get_node("Bench"), "res://assets/props/radio/radio.glb",
		bench.transform * Vector3(-0.38, 1.293, -0.275), bench.rotation.y + 0.45, 1.1)
	var list := AudioStreamPlaylist.new()
	list.loop = true
	list.fade_time = 1.5
	var records := ["aloha_oe", "honolulu_bay", "mahina_malamalama", "la_paloma"]
	list.stream_count = records.size()
	for i in records.size():
		list.set_list_stream(i, load("res://assets/props/radio/music/%s.ogg" % records[i]))
	var sound := AudioStreamPlayer3D.new()
	sound.name = "RadioMusic"
	sound.stream = list
	sound.autoplay = true
	sound.bus = &"Dunya"
	sound.volume_db = -10.0
	sound.unit_size = 4.0
	sound.max_distance = 25.0
	sound.position = Vector3(0, 0.1, 0)
	add(sound, radio)


## The wall lamp over the bench, its arm out from the back wall (range_dressing.gd _wall_lamp).
func _bench_lamp(at: Vector3) -> void:
	var lamp: StaticBody3D = _prop(arena.get_node("Bench"), "res://assets/props/wall_lamp/wall_lamp.glb", at, PI / 2.0)
	var bulb_at := Vector3(0.0, -0.111, 0.752)  # build_wall_lamp.py prints this
	var spot := SpotLight3D.new()
	spot.position = bulb_at + Vector3(0, -0.05, 0)
	spot.basis = Basis.looking_at(Vector3(0, -1, 0.0), Vector3.FORWARD)
	spot.light_color = Color(1.0, 0.55, 0.22)
	spot.light_energy = 3.0
	spot.spot_range = 3.6
	spot.spot_attenuation = 0.8
	spot.spot_angle = 68.0
	spot.spot_angle_attenuation = 2.6
	spot.shadow_enabled = true
	spot.shadow_bias = 0.08
	add(spot, lamp)


## Four co-op spawns under the front of the workshop roof, facing the desk and the back wall.
func _world_spawns() -> void:
	var spawns := Node3D.new()
	spawns.name = "Spawns"
	add(spawns)
	for i in SPAWNS_WORLD.size():
		var m := Marker3D.new()
		m.name = "Spawn%d" % (i + 1)
		m.position = SPAWNS_WORLD[i]
		m.basis = Basis.looking_at(Vector3(WS.get_center().x, 0, SPAWNS_WORLD[i].z) - SPAWNS_WORLD[i])
		add(m, spawns)
		m.add_to_group("spawn", true)


func _own(n: Node) -> void:
	n.owner = arena
	for c in n.get_children():
		_own(c)
