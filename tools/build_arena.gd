extends SceneTree
## Builds scenes/arena.tscn: the range shed (beveled precast walls, H columns, trusses, purlins,
## corrugated roof with skylights, gable cladding), hanging lamps, props, floor paint and stains,
## four co-op spawn points, the yard outside (gravel, fence, veld), sky, sun and the post stack. Re-run after changing tools/build_shed_meshes.py output or these numbers:
##   godot --headless --path . -s res://tools/build_arena.gd
## Dimensions must match tools/build_shed_meshes.py.

const SHED := "res://assets/env/shed/"
const TEX := "res://assets/env/textures/"
const MODELS := "res://assets/env/models/"
const HDRI := "res://assets/env/hdri/kloofendal_48d_partly_cloudy_puresky_2k.hdr"
const HALF_SPAN := 27.7
const EAVE := 8.8
const BOTTOM := 8.0
const PITCH := deg_to_rad(6.0)
const CHORD := 0.18
const COLUMN_H := 8.95
const BAYS: Array[float] = [-27.85, -21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0, 27.85]
const LAMP_X: Array[float] = [-22.0, -11.0, 0.0, 11.0, 22.0]
const YARD_HALF := 44.0   # m, fence line around the shed
const DECALS := "res://materials/env/decals/"
## Co-op spawns along the south wall, everyone facing the heap.
const SPAWNS: Array[Vector3] = [Vector3(-4.5, 0, 23.5), Vector3(-1.5, 0, 23.5), Vector3(1.5, 0, 23.5), Vector3(4.5, 0, 23.5)]

var arena: Node3D


func _initialize() -> void:
	seed(7)  # props get the same random yaw every rebuild
	arena = Node3D.new()
	arena.name = "Arena"
	_environment()
	_floor()
	_walls()
	_columns()
	_roof()
	_lamps()
	_props()
	_firing_line()
	_markings()
	_spawns()
	_exterior()
	var scene := PackedScene.new()
	print("pack: ", scene.pack(arena), " save: ", ResourceSaver.save(scene, "res://scenes/arena.tscn"))
	arena.free()
	quit()


static func top_chord(x: float) -> float:
	return EAVE + (HALF_SPAN - absf(x)) * tan(PITCH)


func add(node: Node, parent: Node = null) -> Node:
	(parent if parent else arena).add_child(node)
	node.owner = arena
	return node


func mesh_at(mesh_name: String, xf: Transform3D, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = load(SHED + mesh_name + ".obj")
	mi.material_override = mat
	mi.transform = xf
	add(mi, parent)
	return mi


## PBR material from a Poly Haven texture set (diff, nor_gl, arm = AO/rough/metal), saved as .tres.
func pbr(id: String, tint := Color.WHITE, double_sided := false) -> ORMMaterial3D:
	var path := "res://materials/env/%s.tres" % id
	var m := ORMMaterial3D.new()
	m.albedo_texture = load(TEX + "%s/%s_diff_2k.jpg" % [id, id])
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX + "%s/%s_nor_gl_2k.jpg" % [id, id])
	m.orm_texture = load(TEX + "%s/%s_arm_2k.jpg" % [id, id])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	ResourceSaver.save(m, path)
	return load(path)


func _environment() -> void:
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load(HDRI)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.8
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.sdfgi_enabled = true  # bounce light under the roof; the shed is open-sided so it follows the sun
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_cascades = 4
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.3
	env.volumetric_fog_enabled = true  # dust in the air: sun shafts through the skylights, lamp cones
	env.volumetric_fog_density = 0.0045
	env.volumetric_fog_albedo = Color(0.92, 0.9, 0.86)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_sky_affect = 0.0
	# Haze past the fence, so the far veld melts into the sky instead of ending in a line.
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.64, 0.72)  # the HDRI horizon
	env.fog_density = 0.0018
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var to_sun := _hdri_sun_dir()
	var up := Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD
	sun.transform = Transform3D(Basis.looking_at(-to_sun, up), Vector3(0, 20, 0))
	sun.light_energy = 2.0
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.light_angular_distance = 0.6  # soft-edged sun shadows
	sun.directional_shadow_max_distance = 90.0
	sun.light_volumetric_fog_energy = 1.6
	add(sun)
	# One probe for the whole shed, captured once: metal and paint reflect the roof and walls
	# instead of the open sky they cannot see. Ambient stays with SDFGI.
	var probe := ReflectionProbe.new()
	probe.name = "ShedReflections"
	probe.size = Vector3(56.0, 9.6, 56.0)
	probe.position = Vector3(0, 4.8, 0)
	probe.origin_offset = Vector3(0, -3.0, 0)  # captured from eye height, not mid-air
	probe.box_projection = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.max_distance = 80.0
	add(probe)
	print("sun from: ", to_sun.snappedf(0.01), " elevation ", snappedf(rad_to_deg(asin(to_sun.y)), 0.1))


## Direction toward the brightest pixel of the HDRI, using Godot's panorama mapping
## (u = atan2(x, z) / 2pi, v = acos(y) / pi), so the light matches the painted sun.
func _hdri_sun_dir() -> Vector3:
	var img: Image = (load(HDRI) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.resize(512, 256, Image.INTERPOLATE_BILINEAR)
	var best := Vector2i.ZERO
	var best_l := -1.0
	for y in img.get_height() / 2:
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			if l > best_l:
				best_l = l
				best = Vector2i(x, y)
	var u := (best.x + 0.5) / img.get_width()
	var v := (best.y + 0.5) / img.get_height()
	var s := sin(PI * v)
	return Vector3(sin(TAU * u) * s, cos(PI * v), cos(TAU * u) * s).normalized()


func _floor() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	add(body)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(56, 56)
	mi.mesh = pm
	mi.material_override = load("res://materials/concrete.tres")
	add(mi, body)
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	add(cs, body)


func _walls() -> void:
	var mat := pbr("concrete_slab_wall", Color(0.9, 0.9, 0.88))
	var walls := Node3D.new()
	walls.name = "Walls"
	add(walls)
	# name, yaw so the panel faces inward, centre of the 0.3 m wall
	for side in [["North", 0.0, Vector3(0, 0, -28.15)], ["South", PI, Vector3(0, 0, 28.15)],
			["East", -PI / 2, Vector3(28.15, 0, 0)], ["West", PI / 2, Vector3(-28.15, 0, 0)]]:
		var body := StaticBody3D.new()
		body.name = side[0]
		body.transform = Transform3D(Basis(Vector3.UP, side[1]), side[2])
		add(body, walls)
		for i in 14:
			mesh_at("wall_panel", Transform3D(Basis(), Vector3(-26.0 + 4.0 * i, 0, 0)), mat, body)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(56.6, 4.0, 0.3)
		cs.shape = box
		cs.position.y = 2.0
		add(cs, body)


func _columns() -> void:
	var steel := pbr("metal_plate_02", Color(0.62, 0.64, 0.66))
	var body := StaticBody3D.new()
	body.name = "Columns"
	add(body)
	var spots: Array = []  # [position, yaw, height]
	for z in BAYS:
		for s in [-1.0, 1.0]:
			spots.append([Vector3(s * 27.85, 0, z), PI / 2, COLUMN_H])
	for x in BAYS.slice(1, BAYS.size() - 1):
		for s in [-1.0, 1.0]:
			spots.append([Vector3(x, 0, s * 27.85), 0.0, top_chord(x) + CHORD / 2 + 0.25])
	for sp in spots:
		var h: float = sp[2]
		var xf := Transform3D(Basis(Vector3.UP, sp[1]).scaled(Vector3(1, h / COLUMN_H, 1)), sp[0])
		mesh_at("column", xf, steel, body)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, h, 0.3)
		cs.shape = box
		cs.position = sp[0] + Vector3(0, h / 2, 0)
		add(cs, body)


func _roof() -> void:
	var steel: Material = load("res://materials/env/metal_plate_02.tres")
	var roof := Node3D.new()
	roof.name = "Roof"
	add(roof)
	for z in BAYS:
		mesh_at("truss", Transform3D(Basis(), Vector3(0, 0, z)), steel, roof)
	var xs: Array[float] = []
	var x := 0.6
	while x < 27.0:
		xs.append(x)
		x += 2.3
	xs.append(27.45)
	for px in xs:
		for s in [-1.0, 1.0]:
			var xf := Transform3D(Basis(Vector3.BACK, -s * PITCH), Vector3(s * px, top_chord(px) + CHORD / 2 + 0.1, 0))
			mesh_at("purlin", xf, steel, roof)
	var sheet := mesh_at("roof_sheet", Transform3D(), pbr("corrugated_iron_02", Color(0.85, 0.86, 0.88), true), roof)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	var glass := StandardMaterial3D.new()  # polycarbonate skylight: milky, lets the sun through
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.95, 0.97, 1.0, 0.62)
	glass.roughness = 0.45
	glass.emission_enabled = true  # daylight glowing through the milky sheet
	glass.emission = Color(0.85, 0.9, 1.0)
	glass.emission_energy_multiplier = 0.6
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	ResourceSaver.save(glass, "res://materials/env/skylight.tres")
	var sky := mesh_at("skylight", Transform3D(), load("res://materials/env/skylight.tres"), roof)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var clad: Material = load("res://materials/env/corrugated_iron_02.tres")
	for s in [-1.0, 1.0]:
		var g := mesh_at("gable_cladding", Transform3D(Basis(), Vector3(0, 0, s * 28.3)), clad, roof)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED


func _lamps() -> void:
	var lamps := Node3D.new()
	lamps.name = "Lamps"
	add(lamps)
	var lamp_scene: PackedScene = load(MODELS + "hanging_industrial_lamp/hanging_industrial_lamp_1k.gltf")
	for z in BAYS.slice(1, BAYS.size() - 1):
		for x in LAMP_X:
			var lamp: Node3D = lamp_scene.instantiate()
			lamp.position = Vector3(x, BOTTOM - CHORD / 2, z)
			add(lamp, lamps)
			for mi in lamp.find_children("*", "MeshInstance3D", true, false):
				for i in (mi as MeshInstance3D).mesh.get_surface_count():
					var m := (mi as MeshInstance3D).mesh.surface_get_material(i) as BaseMaterial3D
					if m and m.emission_enabled:
						m.emission_energy_multiplier = 6.0  # lit bulb reads in daylight and blooms
			var spot := SpotLight3D.new()
			spot.position = Vector3(0, -1.25, 0)
			spot.rotation.x = -PI / 2
			spot.light_color = Color(1.0, 0.9, 0.76)  # warm high-bay
			spot.light_energy = 5.0
			spot.spot_range = 16.0
			spot.spot_angle = 52.0
			spot.spot_angle_attenuation = 0.6
			spot.light_size = 0.25
			spot.light_volumetric_fog_energy = 0.5
			spot.shadow_enabled = false  # 35 of them; the sun carries the shadows
			add(spot, lamp)


## Props sit along the walls, out of the way of the heap and the shooting lanes.
func _props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	add(props)
	var barrel := MODELS + "Barrel_01/Barrel_01_1k.gltf"
	for p in [Vector3(-25.6, 0, -24.8), Vector3(-24.9, 0, -25.5), Vector3(-26.2, 0, -25.9), Vector3(24.8, 0, 24.6), Vector3(25.6, 0, 25.4)]:
		_prop(props, barrel, p, randf() * TAU)
	var shelves := MODELS + "steel_frame_shelves_01/steel_frame_shelves_01_1k.gltf"
	for z in [-6.0, -4.8, 4.8, 6.0]:
		_prop(props, shelves, Vector3(-27.45, 0, z), PI / 2, 0.1)
	var crate := MODELS + "wooden_crate_01/wooden_crate_01_1k.gltf"
	var ammo := MODELS + "ammo_box/ammo_box_1k.gltf"
	for p in [Vector3(-25.8, 0, -3.4), Vector3(-25.7, 0.35, -3.35), Vector3(-25.2, 0, 3.6), Vector3(24.9, 0, -24.9), Vector3(25.8, 0, -25.3), Vector3(25.3, 0.35, -25.1)]:
		_prop(props, crate, p, randf_range(-0.3, 0.3))
	for p in [Vector3(-25.6, 0.7, -3.3), Vector3(-25.3, 0.35, 3.7), Vector3(25.4, 0.7, -25.0)]:
		_prop(props, ammo, p, randf_range(-0.6, 0.6))
	# North wall: a storage cart with boxes, a generator with fuel cans by the east wall.
	_prop(props, MODELS + "industrial_storage_cart/industrial_storage_cart_1k.gltf", Vector3(-21.5, 0, -26.9), 0.0)
	var box := MODELS + "cardboard_box_01/cardboard_box_01_1k.gltf"
	for p in [Vector3(-19.9, 0, -27.2), Vector3(-19.3, 0, -26.8), Vector3(-19.6, 0.34, -27.0), Vector3(-23.6, 0, -27.1)]:
		_prop(props, box, p, randf_range(-0.4, 0.4))
	_prop(props, MODELS + "portable_generator/portable_generator_1k.gltf", Vector3(26.9, 0, -18.4), -PI / 2 + 0.2)
	var can := MODELS + "metal_jerrycan/metal_jerrycan_1k.gltf"
	for p in [Vector3(27.3, 0, -17.3), Vector3(27.35, 0, -16.9)]:
		_prop(props, can, p, PI / 2 + randf_range(-0.2, 0.2))
	var crate3 := MODELS + "plastic_crate_03/plastic_crate_03_1k.gltf"
	for p in [Vector3(-24.2, 0, 26.9), Vector3(-23.6, 0, 26.95), Vector3(-23.9, 0.27, 26.9)]:
		_prop(props, crate3, p, randf_range(-0.15, 0.15))
	var barrel2 := MODELS + "Barrel_02/Barrel_02_1k.gltf"
	for p in [Vector3(-26.9, 0, 17.6), Vector3(-26.3, 0, 18.3), Vector3(-26.95, 0, 18.6)]:
		_prop(props, barrel2, p, randf() * TAU)
	var mil := MODELS + "old_military_crate/old_military_crate_1k.gltf"
	_prop(props, mil, Vector3(26.9, 0, 18.2), PI / 2)
	_prop(props, mil, Vector3(26.9, 0.26, 18.25), PI / 2 + 0.05)
	# An extinguisher at every other column; a wet floor sign next to the biggest oil stain.
	var ext := MODELS + "korean_fire_extinguisher_01/korean_fire_extinguisher_01_1k.gltf"
	for p in [Vector3(-27.4, 0, -13.4), Vector3(27.4, 0, 14.6), Vector3(13.4, 0, -27.4), Vector3(-13.4, 0, 27.4)]:
		_prop(props, ext, p, randf() * TAU)
	_prop(props, MODELS + "WetFloorSign_01/WetFloorSign_01_1k.gltf", Vector3(13.2, 0, 15.1), 0.6)


## The firing line: a yellow steel railing wall to wall at GameState.FIRING_LINE_X, every target
## past it. Its collision is on the fence layer only: it stops players, rounds fly through.
func _firing_line() -> void:
	const GS := preload("res://scripts/game_state.gd")
	const RUN := 55.4  # m, between the inner wall faces
	const HEIGHT := 1.1
	var x: float = GS.FIRING_LINE_X
	var body := StaticBody3D.new()
	body.name = "FiringLine"
	body.collision_layer = 1 << (GS.FENCE_LAYER - 1)
	body.collision_mask = 0
	add(body)
	var cs := CollisionShape3D.new()
	var wall := BoxShape3D.new()
	wall.size = Vector3(0.3, 3.0, RUN)  # taller than a jump
	cs.shape = wall
	cs.position = Vector3(x, 1.5, 0)
	add(cs, body)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.86, 0.62, 0.08)
	paint.roughness = 0.55
	paint.metallic = 0.25
	var steel := pbr("metal_plate_02", Color(0.45, 0.46, 0.48))
	var box := func(size: Vector3, at: Vector3, mat: Material) -> void:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		m.mesh = b
		m.material_override = mat
		m.position = at
		add(m, body)
	for rail_y in [HEIGHT - 0.025, 0.55]:
		box.call(Vector3(0.05, 0.05, RUN), Vector3(x, rail_y, 0), paint)
	var posts := 21
	for i in posts:
		var z := -RUN / 2.0 + 0.2 + i * (RUN - 0.4) / (posts - 1)
		box.call(Vector3(0.06, HEIGHT, 0.06), Vector3(x, HEIGHT / 2.0, z), paint)
		box.call(Vector3(0.16, 0.012, 0.16), Vector3(x, 0.006, z), steel)


func _prop(parent: Node, path: String, pos: Vector3, yaw: float, s := 1.0) -> void:
	var body := StaticBody3D.new()
	body.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), pos)
	add(body, parent)
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	add(inst, body)
	var b := _aabb(inst, Transform3D())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = b.size
	cs.shape = box
	cs.position = b.get_center()
	add(cs, body)


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var t := xf * (n as Node3D).transform if n is Node3D else xf
	var out := AABB()
	var empty := true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out = t * (n as MeshInstance3D).mesh.get_aabb()
		empty = false
	for c in n.get_children():
		var cb := _aabb(c, t)
		if cb.size != Vector3.ZERO:
			out = cb if empty else out.merge(cb)
			empty = false
	return out


## Worn yellow floor paint: a keep-clear ring around the heap, walkway lines along the walls and
## the four spawn boxes; plus oil stains. Textures are drawn here once and saved lossless.
func _markings() -> void:
	var marks := Node3D.new()
	marks.name = "FloorMarks"
	add(marks)
	var paint := Color(0.86, 0.66, 0.08)
	var wear := FastNoiseLite.new()
	wear.seed = 11
	wear.frequency = 0.02
	wear.fractal_octaves = 5
	var worn := func(x: float, y: float) -> float:  # 0..1 paint left
		return smoothstep(-0.35, 0.15, wear.get_noise_2d(x, y))

	# Ring: radius 10.6 m (heap 8.6 m + spill), 12 cm line and a thinner one 35 cm outside.
	var ring_px := 1536
	var ring_m := 22.4
	var ring := _decal_tex("ring", ring_px, ring_px, func(img: Image) -> void:
		var c := ring_px * 0.5
		for y in ring_px:
			for x in ring_px:
				var r := Vector2(x - c, y - c).length() * ring_m / ring_px
				var a := 0.0
				if absf(r - 10.6) < 0.06:
					a = 1.0
				elif absf(r - 10.95) < 0.03:
					a = 0.8
				if a > 0.0:
					img.set_pixel(x, y, Color(paint, a * worn.call(x * 1.0, y * 1.0))))
	_decal(marks, ring, Vector3.ZERO, 0.0, Vector3(ring_m, 1.0, ring_m))

	var line := _decal_tex("line", 16, 2048, func(img: Image) -> void:
		for y in 2048:
			for x in 16:
				img.set_pixel(x, y, Color(paint, worn.call(x * 0.5, y * 1.5))))
	for side in 4:  # walkways 1.8 m in from each wall
		var yaw := side * PI / 2.0
		_decal(marks, line, Basis(Vector3.UP, yaw) * Vector3(0, 0, 25.9), yaw + PI / 2.0, Vector3(0.1, 1.0, 50.0))

	var box := _decal_tex("spawn_box", 256, 256, func(img: Image) -> void:
		for y in 256:
			for x in 256:
				var edge := mini(mini(x, y), mini(255 - x, 255 - y))
				if edge < 12:
					img.set_pixel(x, y, Color(paint, worn.call(x * 3.0, y * 3.0 + 400.0))))
	for p in SPAWNS:
		_decal(marks, box, p, 0.0, Vector3(1.6, 1.0, 1.6))

	var spot := FastNoiseLite.new()
	spot.seed = 5
	spot.frequency = 0.012
	var stain := _decal_tex("oil_stain", 512, 512, func(img: Image) -> void:
		for y in 512:
			for x in 512:
				var r := Vector2(x - 256, y - 256).length() / 256.0
				var a := clampf((1.0 - r * (1.0 + spot.get_noise_2d(x, y) * 0.8)) * 2.0, 0.0, 1.0)
				if a > 0.0:
					img.set_pixel(x, y, Color(0.05, 0.04, 0.03, a * 0.55)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var placed := 0
	while placed < 14:
		var p := Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))
		if p.length() < 12.0:
			continue  # under or next to the heap
		var s := rng.randf_range(0.8, 2.6)
		_decal(marks, stain, p, rng.randf() * TAU, Vector3(s, 1.0, s * rng.randf_range(0.6, 1.0)))
		placed += 1
	_decal(marks, stain, Vector3(13.8, 0, 14.4), 0.4, Vector3(3.2, 1.0, 2.4))  # by the wet floor sign


func _decal(parent: Node, tex: Texture2D, pos: Vector3, yaw: float, size: Vector3) -> void:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = size
	d.position = pos
	d.rotation.y = yaw
	d.upper_fade = 0.1
	d.lower_fade = 0.1
	d.cull_mask = 1  # floor and heap only; not the gun (layer 2)
	add(d, parent)


func _decal_tex(id: String, w: int, h: int, paint: Callable) -> Texture2D:
	var path := DECALS + id + ".res"
	if ResourceLoader.exists(path):  # drawing in GDScript is slow; delete the file to redraw
		return load(path)
	DirAccess.make_dir_recursive_absolute(DECALS)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	paint.call(img)
	img.generate_mipmaps()
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)  # else headless saves no pixels
	var tex := PortableCompressedTexture2D.new()
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	ResourceSaver.save(tex, path)
	return load(path)


## Co-op spawn points; player.gd takes one per player.
func _spawns() -> void:
	var spawns := Node3D.new()
	spawns.name = "Spawns"
	add(spawns)
	for i in SPAWNS.size():
		var m := Marker3D.new()
		m.name = "Spawn%d" % (i + 1)
		m.position = SPAWNS[i]  # identity basis looks down -z, at the heap
		add(m, spawns)
		m.add_to_group("spawn", true)


## The yard: gravel out to a chain-link fence, dry veld beyond. Ground is one big plane under the
## shed floor; the fence is two MultiMeshes per stretch (panels, posts), no shadows.
func _exterior() -> void:
	var outside := Node3D.new()
	outside.name = "Outside"
	add(outside)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/ground.gdshader")
	for pair in [["yard", "gravel_floor_02"], ["field", "dry_ground_01"]]:
		var id: String = pair[1]
		mat.set_shader_parameter(pair[0] + "_albedo", load(TEX + "%s/%s_diff_2k.jpg" % [id, id]))
		mat.set_shader_parameter(pair[0] + "_normal", load(TEX + "%s/%s_nor_gl_2k.jpg" % [id, id]))
		mat.set_shader_parameter(pair[0] + "_arm", load(TEX + "%s/%s_arm_2k.jpg" % [id, id]))
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 256
	noise.height = 256
	noise.noise = FastNoiseLite.new()
	mat.set_shader_parameter("noise_tex", noise)
	mat.set_shader_parameter("yard_half", YARD_HALF)
	mat.set_shader_parameter("tint", Color(0.72, 0.7, 0.64))  # the scans are lit bright; the veld is darker
	ResourceSaver.save(mat, "res://materials/env/ground.tres")
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 2400)  # out to where the haze takes over
	ground.mesh = pm
	ground.material_override = load("res://materials/env/ground.tres")
	ground.position.y = -0.03  # the shed floor covers it inside
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(ground, outside)

	var fence: Node3D = (load(MODELS + "modular_chainlink_fence/modular_chainlink_fence_1k.gltf") as PackedScene).instantiate()
	var panel: Mesh = (fence.find_child("modular_chainlink_fence_double", true, false) as MeshInstance3D).mesh
	var post: Mesh = (fence.find_child("modular_chainlink_fence_post", true, false) as MeshInstance3D).mesh
	fence.free()
	var modules := int(YARD_HALF)  # 2 m each: post at the start, panel spans the next 1.86 m
	var per_stretch := modules / 4
	for side in 4:
		var yaw := side * PI / 2.0
		var b := Basis(Vector3.UP, yaw)
		for stretch in 4:  # short stretches so each gets its own LOD and culling
			var panels: Array[Transform3D] = []
			var posts: Array[Transform3D] = []
			for m in range(stretch * per_stretch, (stretch + 1) * per_stretch):
				var x := -YARD_HALF + 2.0 * m
				posts.append(Transform3D(b, b * Vector3(x, 0, -YARD_HALF)))
				panels.append(Transform3D(b, b * Vector3(x + 2.0, 0, -YARD_HALF)))  # mesh spans x -1.93..-0.07
			_multimesh(outside, panel, panels)
			_multimesh(outside, post, posts)


func _multimesh(parent: Node, mesh: Mesh, xforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(mmi, parent)
