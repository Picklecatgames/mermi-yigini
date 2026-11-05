extends "res://tools/build_arena.gd"
## Builds scenes/world.tscn, the open ground (2026-11-02, the user: the old hall and everything in it
## goes; a wide rectangle out in the open, Mad Max wasteland, a light desert with a few dead trees):
## a concrete pad, on it the house (2026-11-05, the user: "our home's bad; a house of a few rooms or
## one hall, the feel of a man's house up in the hills"; inside the bench with its radio, the crate with
## the pistol, the television); behind it the back yard,
## flat ground with the junkyard (scripts/pile.gd: a scrap heap, mountains of scrap behind it);
## round it all sand and cracked earth rising into dunes at the edges.
## The scene is never edited by hand: change the numbers here and re-run
##   godot --headless --path . -s res://tools/build_world.gd
## The helpers (add, worn, pbr_box, _prop, block, collide, pendant, _pit...) are build_arena.gd's.

const WORLD := Rect2(-236.0, -220.0, 500.0, 440.0)  # x, z: the ground, the junkyard's grid included, so the ring of dunes closes behind the mountain too
const PAD := Rect2(-6.0, -14.0, 32.0, 28.0)  # the concrete round the workshop; edges on the desert grid (CELL)
## The back yard (2026-11-03, the user: "the pit goes; the back yard is flat ground and heaps and heaps
## of junk, as if we were a scrap dealer in the desert; some mountains touching the sky"): flat ground
## behind the workshop, all of it the junkyard's (scripts/pile.gd: a heap in front, mountains of
## scrap behind it); nothing else stands on it.
const YARD := Rect2(-136.0, -80.0, 130.0, 160.0)
## The junkyard's grid on the ground (pile.gd CENTER, GRID_X/Z × CELL; pile.gd can't be loaded here,
## it needs the autoloads).
const HEAP_AREA := Rect2(-136.0, -80.0, 128.0, 160.0)
const CELL := 2.0  # m, the desert mesh's grid
const DUNE_START := 6.0  # m from the pad's edge where the ground starts to roll
## What ends the walk (2026-11-05, the user: "the area is too small and ahead it's blocked by a mountain,
## that's absurd; make the map bigger and make its limit feel logical"): no cliff. The ground climbs
## gently into wooded hills and on them the wood has closed itself: a belt of fallen trunks, thick and
## tall, with more wood standing behind it. Numbers are my guess.
const EDGE_RISE := 9.0  # m the ground climbs to at the belt
const EDGE_REACH := 70.0  # m in from the belt over which it climbs
const RIM_CENTRE := Vector2(14.0, 0.0)
const RIM_RADII := Vector2(215.0, 190.0)  # the belt: a rounded oblong, no straight sides
const RIM_WANDER := 9.0  # m it wanders in from there
const RIM_SLOPE := 0.25  # m up per m past it
const RIM_STEP := 1.7  # m along the belt between fallen trunks
const RIM_SOLID_EVERY := 3  # one length of the belt's collision per this many steps
const RIM_SOLID := Vector3(13.0, 7.0, 3.0)  # m: along, up, through

## The house (tools/build_house.py, the Old russian house model, 2026-11-05: chosen over a shack and a
## log cabin by shots; the bigger floor and the veranda). Its veranda door looks at the yard (+x), the
## back door at the mountain (-x). What the model has is the outside only: inside walls, floor, ceiling
## are _house's. All in world metres on the pad, walls' outer faces on these lines.
const HOUSE_AT := Vector3(6.25, 0, 0.34)  # the model's origin; its y becomes world x, its x world z
const HOUSE := Rect2(1.6, -3.88, 7.4, 7.76)  # the main room's outer walls, x, z
const VERANDA := Rect2(9.0, 0.05, 2.65, 3.35)
const CEIL_Y := 2.9
const VERANDA_CEIL := 2.5
const WALL_T := 0.2
const LIT_CELL := 0.45  # m, the inside's grid for the lamps' light (_fine)
const HOUSE_DOOR_TOP := 2.26
## [along from, along to, foot, head] of each opening in a wall: tools/build_house.py HOLES (doors), the model's windows.
const BACK_DOOR := [-3.7, -2.3, 0.0, HOUSE_DOOR_TOP]
const INNER_DOOR := [0.2, 1.6, 0.0, HOUSE_DOOR_TOP]
const FRONT_DOOR := [0.22, 1.62, 0.0, HOUSE_DOOR_TOP]
const WIN_W := [[-2.02, -0.79, 0.87, 2.34], [0.8, 2.02, 0.87, 2.34]]  # the mountain's side, z
const WIN_SOUTH := [[3.27, 4.49, 0.87, 2.34], [6.06, 7.29, 0.87, 2.34]]  # x; the north wall's two look into the wing now, its lining has none
const NORTH_DOOR := [4.57, 5.97, 0.0, HOUSE_DOOR_TOP]  # to the workshop wing, between them
const WIN_VERANDA := [[9.66, 11.2, 1.03, 1.98]]
## The workshop wing on the north wall (2026-11-05, the user: the bench to a workshop, the house wider):
## tools/build_wing.py, a real shed. Its door looks at the mountain, for what is carried down from it.
const WING_AT := Vector3(4.8, 0, -6.03)  # the model's origin; its y becomes world x, its x world z
const WING := Rect2(1.6, -8.13, 7.2, 4.2)  # its outer walls, x, z
const WING_CEIL := 2.55
const WING_T := 0.12
const WING_DOOR := [-6.03, -4.6, 0.0, 2.45]  # z, in its west wall
## The models' own sizes (measured off their files).
const BED_YAW := PI / 2.0
const BED_SCALE := 1.0
const STOVE_SCALE := 0.4  # the file's in no unit; its body knee high, its pipe near the ceiling
const STOVE_TOP := 0.92
const TABLE_TOP := 0.549
const CHAIR_SCALE := 0.5  # 2.27 m tall in the file
const NIGHTSTAND_TOP := 0.616
const STUMP_SCALE := 0.5
const STUMP_TOP := 0.19
const WOOD_LENGTH := 0.42  # m, a log
const WEB_SCALE := 0.9  # m across
const BED_X := 4.7  # the sleeping corner's wall, from the west wall to here, z BED_Z to the south wall
const BED_Z := 0.85
const BED_DOOR := [0.95, 2.35, 0.0, HOUSE_DOOR_TOP]
const BENCH_AT := Vector3(4.0, 0, -7.4)  # the crew's bench, its back on the wing's north wall; GameState.MELTER_POS, PRESS_POS follow it
const BENCH_SCALE := 1.2  # as it stood in the hall (range_dressing.gd _workshop)
const DESK_AT := Vector3(5.6, 0, 0.0)  # the pistol's crate, right in front of the spawns
const TV_AT := Vector3(2.2, 0, 0.0)  # GameState.TV_POS; between the mountain's windows, in the spawns' view
const TV_STAND_SCALE := 1.45  # the crate under it
const TV_STAND_TOP := 0.68
const TV_YAW := PI / 2.0  # its screen (+z in its gltf) to the room
const SPAWNS_WORLD: Array[Vector3] = [Vector3(7.3, 0, -0.9), Vector3(7.3, 0, 0.9), Vector3(8.15, 0, -0.1), Vector3(6.0, 0, -2.6)]
const SUN_ANGLE := Vector3(-26.0, -125.0, 0.0)  # deg: late afternoon, from behind the workshop's left; low (2026-11-03, the PS1 critic: the day was flat, no shadow read): one long, clear shadow direction
const SKY_TURN := 0.0  # deg: the HDRI turned so its bright side is where the sun stands


func _initialize() -> void:
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)  # else the PS1 trees' WebP textures save with no pixels (magenta)
	seed(11)
	arena = Node3D.new()
	arena.name = "World"
	_sky()
	_pad()
	_desert()
	_wasteland()
	_forest()
	_house()
	_workshop_inside()
	_world_spawns()
	_lighten(arena, Transform3D())
	var scene := PackedScene.new()
	print("pack: ", scene.pack(arena), " save: ", ResourceSaver.save(scene, "res://scenes/world.tscn"))
	arena.free()
	quit()


## The default day (2026-11-03, the user on the PS1 critic's notes: not a holiday sky): choked,
## dusty and pale under overcast, and a short, hard PS1 fog wall that swallows the far ground,
## half gone by ~35 m, all dust by 75 m. The day-night cycle (scripts/day_night.gd, coming) takes
## these over; its night: tools/psx_shots.gd `_night`.
func _sky() -> void:
	# Poly Haven's Kloofendal Overcast pure sky (CC0), 1k and unfiltered: its big pixels are the PS1's.
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/env/hdri/kloofendal_overcast_puresky_1k.hdr")
	sky_mat.filter = false
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.8  # 2026-11-04, the user: more unknown: a dim day, the shade under the trees dark
	env.background_energy_multiplier = 0.8
	env.sky_rotation = Vector3(0, deg_to_rad(SKY_TURN), 0)
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
	env.fog_enabled = true  # dust hanging over the desert: the far ground goes into it
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.1, 0.12, 0.095)  # the old wood's haze: a damp grey-green, the trees going into it
	env.fog_density = 1.0  # depth fog: all the way to the colour at fog_depth_end
	env.fog_depth_begin = 22.0
	env.fog_depth_end = 85.0
	env.fog_depth_curve = 0.6  # under 1 it thickens early: half way in at ~35 m
	env.fog_sky_affect = 0.45  # the sky goes dusty too, the horizon one with the ground
	env.fog_aerial_perspective = 0.0  # its colour from the dust, not the sky
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.95
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ANGLE
	sun.light_color = Color(0.96, 0.89, 0.78)
	sun.light_energy = 1.25  # through the overcast; a little over the ambient, so the shadows read
	sun.shadow_enabled = true
	# Short and coarse, PS1 taste (2026-11-03, the user: the lighting PS1-fit): past 50 m the fog
	# has it all anyway, and the shadow map spent on 50 m draws the near shadows hard and clean.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 50.0
	sun.light_angular_distance = 3.0  # soft-edged shadows
	add(sun)


## The concrete: filthy cracked slabs (Poly Haven "Dirty Concrete"), each 4 m pour its own tone,
## sand blown onto it; under it ground a metre thick.
func _pad() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	add(body)
	var slabs := worn("dirty_concrete", "yard_concrete", {"tint": Color(0.8, 0.74, 0.66), "tex_size": 4.0,
		"cell_size": 4.0, "cell_tone": 0.12, "odd_cells": 0.1, "antitile": 0.5, "grime": 0.9,
		"grime_scale": 0.08, "grime_color": Color(0.42, 0.33, 0.22)})  # the grime is blown sand, not soot
	for r in [PAD]:
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


## Height of the desert at (x, z): flat at the pad, rolling dunes further out, climbing steeply into
## a ring of high dunes near the world's edge that nobody walks over.
func _ground_y(x: float, z: float, noise: FastNoiseLite) -> float:
	var away := INF
	for flat in [PAD, YARD]:  # the pad and the back yard are flat
		var dx := maxf(maxf(flat.position.x - x, x - flat.end.x), 0.0)
		var dz := maxf(maxf(flat.position.y - z, z - flat.end.y), 0.0)
		away = minf(away, Vector2(dx, dz).length())
	var roll := smoothstep(DUNE_START, DUNE_START + 30.0, away)
	# Low uneven swells and gullies, not smooth dunes (2026-11-02, the user: "looks like a Unity demo").
	var h := noise.get_noise_2d(x, z) * 2.2 * roll + noise.get_noise_2d(x * 4.1, z * 4.1) * 0.35 * roll
	h = maxf(h, -0.6)
	var edge := -_to_rim(x, z, noise)
	var ridge := noise.get_noise_2d(x * 0.45 + 300.0, z * 0.45) * 0.5 + 0.5
	h += pow(1.0 - clampf(edge / EDGE_REACH, 0.0, 1.0), 1.8) * EDGE_RISE * (0.45 + 0.9 * ridge)
	h += _past_rim(x, z, noise) * RIM_SLOPE
	return h


## Metres past the belt of fallen trunks at (x, z): under 0 inside it.
func _to_rim(x: float, z: float, noise: FastNoiseLite) -> float:
	var q := (Vector2(x, z) - RIM_CENTRE) / RIM_RADII
	var d := pow(pow(absf(q.x), 4.0) + pow(absf(q.y), 4.0), 0.25)
	var wander := noise.get_noise_2d(x * 0.6 + 700.0, z * 0.6) * 0.5 + 0.5
	return (d - 1.0) * minf(RIM_RADII.x, RIM_RADII.y) + wander * RIM_WANDER


## How far (x, z) lies past the belt at the map's limit, in metres; 0 inside it.
func _past_rim(x: float, z: float, noise: FastNoiseLite) -> float:
	return maxf(_to_rim(x, z, noise), 0.0)


## The desert: one grid mesh over WORLD with the pad's cells left out, its collision the same
## triangles. Sand, cracked earth and gravel are materials/env/desert.gdshader.
func _desert() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 41
	noise.frequency = 0.018
	noise.fractal_octaves = 4
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
	# 2026-11-04, the user: not a desert, the floor of an old wood: needles and dead leaves, dark mud
	# in patches, trodden dirt round the concrete. The shader's slot names are still the desert's.
	for slot in [["sand", "forest_leaves_04"], ["earth", "mud_forest"], ["gravel", "forest_ground_04"]]:
		var small := _psx_tex(slot[1])  # the PS1 copy (worn, above)
		mat.set_shader_parameter(slot[0] + "_albedo", small if small else load(TEX + "%s/%s_diff_2k.jpg" % [slot[1], slot[1]]))
		mat.set_shader_parameter(slot[0] + "_normal", null if small else load(TEX + "%s/%s_nor_gl_2k.jpg" % [slot[1], slot[1]]))
		mat.set_shader_parameter(slot[0] + "_arm", load(FLAT_ARM) if small else load(TEX + "%s/%s_arm_2k.jpg" % [slot[1], slot[1]]))
	var n2 := FastNoiseLite.new()
	n2.frequency = 0.02
	n2.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = n2
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	mat.set_shader_parameter("noise_tex", tex)
	mat.set_shader_parameter("wood_oval", Vector4(CLEARING_CENTRE.x, CLEARING_CENTRE.y, CLEARING_RADII.x, CLEARING_RADII.y))
	mat.set_shader_parameter("pad", Vector4(PAD.position.x, PAD.position.y, PAD.end.x, PAD.end.y))
	mat.set_shader_parameter("sand_tint", Color(0.56, 0.58, 0.32))
	mat.set_shader_parameter("earth_tint", Color(0.9, 0.9, 0.62))
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


## Out on the sand (Poly Haven's Namaqualand set, CC0): one tree here and there, one bush, one
## stone; each spot one single thing. Those glTFs are catalogues, every variant of a kind side by
## side in one file (wild_rooibos_bush a-e in a row 2 m long): _part takes one of them out. Boulders
## more and bigger towards the edge hills, a wrecked car, tyres and drums.
func _wasteland() -> void:
	var root := Node3D.new()
	root.name = "Wasteland"
	add(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var taken: Array[Vector2] = []  # nothing lands on anything else
	# `in_yard`: it may lie in the back yard too (junk, bushes), not only out on the sand; never on
	# the scrap heap or the giant heaps, never on the cliff.
	var spots := func(count: int, near: float, far: float, in_yard := false, apart := 3.0) -> Array[Vector3]:
		var out: Array[Vector3] = []
		var tries := 0
		while out.size() < count and tries < count * 400:
			tries += 1
			var p := Vector2(rng.randf_range(WORLD.position.x + 8.0, WORLD.end.x - 8.0), rng.randf_range(WORLD.position.y + 8.0, WORLD.end.y - 8.0))
			var away := Rect2(PAD.position - Vector2(near, near), PAD.size + Vector2(near, near) * 2.0)
			var too_far := Rect2(PAD.position - Vector2(far, far), PAD.size + Vector2(far, far) * 2.0)
			if away.has_point(p) or not too_far.has_point(p):
				continue
			if (not in_yard and YARD.has_point(p)) or _heap_h(p) > 0.05 or HEAP_NEAR.grow(2.0).has_point(p):
				continue
			if _past_rim(p.x, p.y, _desert_noise) > 0.0:
				continue
			var gap := apart * rng.randf_range(1.0, 2.2)
			var clear := true
			for o: Vector2 in taken:
				if o.distance_to(p) < gap:
					clear = false
					break
			if not clear:
				continue
			taken.append(p)
			out.append(Vector3(p.x, _ground_y(p.x, p.y, _desert_noise), p.y))
		return out
	# The clearing's floor: ferns and shrubs, fallen logs, stones (the pack); a tree only here and there.
	var wood := _wood()
	for p: Vector3 in spots.call(10, 12.0, 26.0, false, 8.0):
		_wood_tree(root, _pick_tree(rng, wood.close, Vector2(p.x, p.z)), p, rng)
	# Nothing strewn one by one over the open ground (2026-11-04, the user: "the stones look like
	# shards, as if a few were sprinkled"): what lies about lies in the scenes of _wood_floor.
	for p: Vector3 in spots.call(3, 14.0, 60.0, false, 12.0):
		_prop(root, MODELS + "covered_car/covered_car_1k.gltf", p, rng.randf() * TAU, 1.0, Basis(Vector3.FORWARD, rng.randf_range(-0.05, 0.05)))
	for p: Vector3 in spots.call(10, 3.0, 50.0, true, 3.0):
		var junk: String = ["old_tyre/old_tyre_1k.gltf", "rusted_wheel_rim_01/rusted_wheel_rim_01_1k.gltf", "rusted_wheel_rim_02/rusted_wheel_rim_02_1k.gltf"][rng.randi() % 3]
		var thing := _prop(root, MODELS + junk, p, rng.randf() * TAU)
		thing.collision_layer = 0  # walked over, not snagged on (2026-11-04, the user: player friendly)
		thing.collision_mask = 0


const NAMA := "res://assets/env/namaqualand/"


func _weighted(rng: RandomNumberGenerator, kinds: Array) -> int:
	var r := rng.randf()
	for i in kinds.size():
		r -= kinds[i][1]
		if r <= 0.0:
			return i
	return kinds.size() - 1


## The old, half-dead wood's models (tools/psx_props.gd orman): Low Poly Forest Tree Pack (99.Miles),
## Cypress tree (ElectroNick), Cherry tree (matousekfoto), all CC-BY. A kind is one or more meshes
## that stand together (a trunk and its branches), their offsets in the file taken out so it stands
## on its origin. [file, mesh nodes (none: all), share of the wood, scale range, trunk radius in its own units]
const WOOD_PACK := "res://assets/env/orman/forest_pack_psx.scn"
const WOOD_CYPRESS := "res://assets/env/orman/cypress_psx.scn"
const WOOD_CHERRY := "res://assets/env/orman/cherry_psx.scn"
const AT := "Background_Tree_Atlas%s_Background_Tree_Atlas_0"
const WOOD_TREES := [
	[WOOD_PACK, [AT % ""], 0.1, Vector2(0.65, 1.1), 0.5],
	[WOOD_PACK, [AT % "_001"], 0.08, Vector2(0.6, 1.0), 0.6],
	[WOOD_PACK, [AT % "_002"], 0.08, Vector2(0.7, 1.2), 0.4],
	[WOOD_PACK, [AT % "_003"], 0.1, Vector2(0.65, 1.1), 0.5],
	[WOOD_PACK, [AT % "_004"], 0.08, Vector2(0.65, 1.1), 0.6],
	[WOOD_PACK, [AT % "_005"], 0.08, Vector2(0.6, 0.95), 0.5],
	[WOOD_PACK, [AT % "_006"], 0.08, Vector2(0.65, 1.1), 0.5],
	[WOOD_PACK, [AT % "_007"], 0.08, Vector2(0.65, 1.1), 0.5],
	[WOOD_PACK, ["Tree_Trunk_01_Tree_Trunk_01_0", "Tree_Branches_01_001_Tree_Branches_01_0"], 0.05, Vector2(1.25, 1.9), 0.4],
	[WOOD_PACK, ["Tree_Trunk_01_001_Tree_Trunk_01_0", "Tree_Branches_01_Tree_Branches_01_0"], 0.05, Vector2(0.9, 1.35), 0.6],
	[WOOD_PACK, ["Tree_Trunk_01_002_Tree_Trunk_01_0", "Tree_Branches_01_002_Tree_Branches_01_0"], 0.05, Vector2(1.0, 1.45), 0.6],
	[WOOD_PACK, ["Tree_Trunk_02_Tree_Trunk_02_0", "Tree_Branches_02_Tree_Branches_02_0"], 0.05, Vector2(1.25, 1.9), 0.4],
	# Half dead: the same trunks with nothing left on them.
	[WOOD_PACK, ["Tree_Trunk_01_001_Tree_Trunk_01_0"], 0.03, Vector2(0.6, 1.0), 0.6],
	[WOOD_PACK, ["Tree_Trunk_01_002_Tree_Trunk_01_0"], 0.03, Vector2(0.6, 1.0), 0.6],
	[WOOD_CYPRESS, [], 0.05, Vector2(2.2, 3.4), 0.12],
	[WOOD_CHERRY, [], 0.05, Vector2(2.2, 3.4), 0.2],
]
var _wood_kinds := {}
const ORMAN_KINDS := preload("res://tools/orman_kinds.gd")
const TREE_STAND := preload("res://tools/tree_stand.gd")
var _trunks: StaticBody3D
var _stand_rows := []  # per tree in the wood: [family, foot, ground under it, wood at the ground, posts]
## Two trees of one silhouette stand at least this far apart wherever the kinds allow it (2026-11-04,
## the user: "I don't want to see two alike side by side"; m, my guess). With thirty-odd families and
## a tree every 2-3.6 m a circle this wide holds about as many trees as there are kinds.
const WOOD_APART := 10.0
var _tree_fams := {}  # Vector2i (16 m cell) -> Array of [Vector2, family]: the trees so far


const WOOD_NEAR_EDGE := 14.0  # m in from the clearing's edge: only trees with real branches, where players walk up to them;
# the pack's background trees (one card for a whole crown, big blocks from under it) further in


## One kind: [[mesh, its transform], ...] standing on its origin: over its trunk if it has one
## (a crown is lopsided), else over the middle of its box.
func _wood_kind(file: String, names: Array, low_foot := false) -> Array:
	var scene: Node = (load(file) as PackedScene).instantiate()
	var parts := []
	var box := AABB()
	var trunk := false
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if not names.is_empty() and not String(mi.name) in names:
			continue
		var x := Transform3D()
		var n: Node = mi
		while n and n != scene:
			x = (n as Node3D).transform * x
			n = n.get_parent()
		parts.append([mi.mesh, x, String(mi.name)])
		var b: AABB = x * mi.mesh.get_aabb()
		if String(mi.name).contains("Trunk"):
			box = b
			trunk = true
		elif not trunk:
			box = b if parts.size() == 1 else box.merge(b)
	scene.free()
	var foot := _lowest_middle(parts) if low_foot and not trunk else Vector3(box.get_center().x, box.position.y, box.get_center().z)
	for part: Array in parts:
		part[1] = Transform3D(Basis(), -foot) * part[1]
	return parts


## The middle of a kind's lowest corners: where a leaning dead tree really meets the ground.
func _lowest_middle(parts: Array) -> Vector3:
	var pts := PackedVector3Array()
	var low := INF
	var high := -INF
	for part: Array in parts:
		var m: Mesh = part[0]
		for s in m.get_surface_count():
			for v: Vector3 in m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var w: Vector3 = part[1] * v
				pts.append(w)
				low = minf(low, w.y)
				high = maxf(high, w.y)
	var sum := Vector2.ZERO
	var n := 0
	for w: Vector3 in pts:
		if w.y <= low + (high - low) * 0.05:
			sum += Vector2(w.x, w.z)
			n += 1
	return Vector3(sum.x / n, low, sum.y / n)


func _parts_box(parts: Array) -> AABB:
	var box := AABB()
	for i in parts.size():
		var b: AABB = parts[i][1] * (parts[i][0] as Mesh).get_aabb()
		box = b if i == 0 else box.merge(b)
	return box


func _wood() -> Dictionary:
	if _wood_kinds.is_empty():
		var trees := []
		var close := []
		var fams := {}
		for k: Array in WOOD_TREES:
			var parts := _wood_kind(k[0], k[1])
			var mid: float = (k[3].x + k[3].y) * 0.5
			var stood := _stand(parts, mid, k[4] * mid)
			trees.append([parts, k[2], k[3], k[4], _family(parts, k[1][0] if not k[1].is_empty() else k[0], fams), stood])
			if k[1].is_empty() or not String(k[1][0]).begins_with("Background"):
				close.append(trees[-1])
		for k: Array in ORMAN_KINDS.TREES:
			var parts := _wood_kind(ORMAN_KINDS.scene(k[0]), k[1], true)
			var tall := _parts_box(parts).size.y
			var mid: float = (k[4].x + k[4].y) * 0.5 / tall
			var stood := _stand(parts, mid, k[5], k[2])
			trees.append([parts, k[3], k[4] / tall, k[5] / mid, _family(parts, k[2], fams), stood])
			if k[6]:
				close.append(trees[-1])
		var under := []
		for n in ["_010"]:  # the rest are a fir and flat discs on crossed cards
			under.append(_wood_kind(WOOD_PACK, [AT % n]))
		var rocks := []
		for n in ["", "_001", "_002", "_003", "_004", "_005", "_006", "_007", "_008"]:
			rocks.append(_wood_kind(WOOD_PACK, ["Rocks%s_Rocks_0" % n]))
		var floor_things := {}
		for g: String in ORMAN_KINDS.FLOOR:
			floor_things[g] = []
			for k: Array in ORMAN_KINDS.FLOOR[g]:
				var parts := _wood_kind(ORMAN_KINDS.scene(k[0]), k[1])
				var size := _parts_box(parts).size
				floor_things[g].append([parts, k[2] / maxf(size.x, maxf(size.y, size.z)), size])
		floor_things.green.append_array(_old_floor(under))
		_wood_kinds = {"trees": _normal_shares(trees), "close": _normal_shares(close), "under": under, "rocks": rocks, "floor": floor_things}
	return _wood_kinds


## Puts a kind's origin where its trunk meets the ground (tools/tree_stand.gd), moving its parts: its
## posts in those units come back, and whether there is wood at the ground there.
## 2026-11-04, the user: "most of these trees stand in the air, and you walk through them": the origin
## was the model's box, whose bottom a stray root sets and whose middle a lopsided crown.
func _stand(parts: Array, scale: float, hint: float, kind := "") -> Dictionary:
	var solid := []
	for part: Array in parts:
		if String(part[2]).contains("Trunk"):
			solid.append(part)
	if solid.is_empty():
		solid = parts
	var m: Dictionary = TREE_STAND.measure(solid, scale, hint, kind)
	var foot: Vector3 = m.foot
	var touch: bool = TREE_STAND.wood_at(solid, foot, 0.15, scale)
	for part: Array in parts:
		part[1] = Transform3D(Basis(), -foot) * part[1]
	var posts := []
	for post: Array in m.posts:
		posts.append([(post[0] as Vector3) - foot, post[1]])
	return {"posts": posts, "touch": touch, "ok": m.ok}


## A kind's posts round its trunk, as it stands by `xf`: a short cylinder at each height, so a leaning
## or crooked trunk is solid where it shows. Radius in m.
func _posts(kind: Array, xf: Transform3D, body: StaticBody3D, sc: float) -> void:
	for post: Array in kind[5].posts:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = clampf(post[1] * sc, TREE_STAND.MIN_POST, TREE_STAND.MAX_POST)
		cyl.height = 0.85
		cs.shape = cyl
		cs.position = xf * (post[0] as Vector3)
		add(cs, body)


## The ground under a trunk, its lowest round it: on a slope no side of the foot shows air.
func _ground_under(p: Vector2, r: float) -> float:
	var y := _ground_y(p.x, p.y, _desert_noise)
	for o: Vector2 in [Vector2(r, 0.0), Vector2(-r, 0.0), Vector2(0.0, r), Vector2(0.0, -r)]:
		y = minf(y, _ground_y(p.x + o.x, p.y + o.y, _desert_noise))
	return y


## A kind's family: any kind it shares a mesh with (the bare trunks and the same trunks with branches,
## the pack's crowns that are one mesh under several node names) is one silhouette, one family.
func _family(parts: Array, own: String, fams: Dictionary) -> String:
	var family := own
	for part: Array in parts:
		family = fams.get(part[0], family)
	for part: Array in parts:
		fams[part[0]] = family
	return family


## The pack's rocks and low green in the floor's form, at their own sizes (their units are metres).
func _old_floor(kinds: Array) -> Array:
	var out := []
	for parts: Array in kinds:
		var size := _parts_box(parts).size
		out.append([parts, Vector2(0.5, 1.0), size])
	return out


## The same kinds with their shares adding up to 1: _weighted counts on that.
func _normal_shares(kinds: Array) -> Array:
	var sum := 0.0
	for k: Array in kinds:
		sum += k[1]
	var out := []
	for k: Array in kinds:
		var c: Array = k.duplicate()
		c[1] = k[1] / sum
		out.append(c)
	return out


## A kind for a tree at `p`, of a family none of the trees within WOOD_APART has; by share among
## those; if every family is that close already, the one whose nearest tree is the furthest off.
## Remembered, so the next tree sees it.
func _pick_tree(rng: RandomNumberGenerator, kinds: Array, p: Vector2) -> Array:
	var cell := Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))
	var nearest := {}
	for i in range(-1, 2):
		for j in range(-1, 2):
			for o: Array in _tree_fams.get(cell + Vector2i(i, j), []):
				var d: float = (o[0] as Vector2).distance_to(p)
				if d < nearest.get(o[1], INF):
					nearest[o[1]] = d
	var free := []
	var furthest: Array = kinds[0]
	var best := -1.0
	for k: Array in kinds:
		var d: float = nearest.get(k[4], INF)
		if d >= WOOD_APART:
			free.append(k)
		if d > best:
			best = d
			furthest = k
	var kind: Array = furthest
	if not free.is_empty():
		var shares := _normal_shares(free)
		kind = shares[_weighted(rng, shares)]
	if not _tree_fams.has(cell):
		_tree_fams[cell] = []
	_tree_fams[cell].append([p, kind[4]])
	return kind


## A tree of the clearing, its post round the trunk.
func _wood_tree(parent: Node, kind: Array, at: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(kind[2].x, kind[2].y)
	var body := StaticBody3D.new()
	var p := Vector2(at.x, at.z)
	body.position = Vector3(at.x, _ground_under(p, kind[3] * s) - 0.08, at.z)
	add(body, parent)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3.ZERO)
	for part: Array in kind[0]:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.transform = xf * part[1]
		add(mi, body)
	_posts(kind, xf, body, s)


## Something low on the floor, no collision: a fern, a stone, a log. Drawn with the wood (_forest).
func _wood_low(parts: Array, at: Vector3, rng: RandomNumberGenerator, size: Vector2) -> void:
	_floor_things.append([parts, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(size.x, size.y)), at - Vector3(0, 0.05, 0))])


var _floor_things := []


## A copy's tone: from the clearing's edge into the wood it goes dark, so the first trees show and
## behind them it's black between the trunks; some yellower, some browner, a few half dead.
func _wood_tone(p: Vector2, rng: RandomNumberGenerator) -> Color:
	var out := _out_of_clearing(p) + rng.randf_range(-3.0, 3.0)
	# Darkest at the wood's front, what the clearing looks into; further in it opens again: players walk there.
	var deep := smoothstep(WOOD_DARK_FROM, WOOD_DARK_FROM + WOOD_DARK_REACH, out) * (1.0 - 0.75 * smoothstep(WOOD_LIGHT_FROM, WOOD_LIGHT_FROM + 30.0, out))
	var kind := rng.randf()
	var hue := Color(1.0, 1.0, 0.95)
	if kind < 0.3:
		hue = Color(1.08, 1.0, 0.68)  # yellowing
	elif kind < 0.45:
		hue = Color(1.05, 0.82, 0.6)  # going brown
	elif kind < 0.65:
		hue = Color(0.82, 0.92, 0.82)  # the darker, greyer ones
	var light := lerpf(1.0, WOOD_DARK, deep) * rng.randf_range(0.85, 1.1)
	return Color(hue.r * light, hue.g * light, hue.b * light)


## Where the dead come from (2026-11-02, the user: "the spawn ground is too open; they'll come from
## far off; cover it in trees so they come at us out of a wood"; 2026-11-04: an old, half-dead wood,
## thick, random, mixed, so that nothing shows behind it): round the clearing the wood goes straight
## to its full thickness and stays there to the world's edge. Each tree is a dart thrown at the
## ground that sticks only if nothing stands within a spacing that changes from place to place, so
## no grid shows through. Drawn as MultiMeshes in FOREST_CHUNK squares; each trunk a collision post.
## Markers in group "forest_edge" round the wood's inner edge are where waves (scripts/waves.gd) let
## the dead out of the trees.
## The clearing the wood stands round (the user's drawing, 2026-11-02): an oval, the workshop near
## its back, the scrap mountain closing it behind; the dead come out of the trees on the other sides.
const CLEARING_CENTRE := Vector2(8.0, 0.0)
const CLEARING_RADII := Vector2(40.0, 34.0)
const FOREST_START := 0.0  # m out from the clearing's edge: the first trees
const FOREST_FULL := 7.0  # m: as thick as it gets from here out
const FOREST_SPACING := Vector2(2.0, 3.6)  # m to the nearest tree: thickest, thinnest
const FOREST_DARTS := 480000
const FOREST_DEEP_FROM := 75.0  # m out from the clearing's edge
const FOREST_DEEP_APART := 2.6  # times the spacing there
const FOREST_CHUNK := 40.0
const HEAP_TREE_LINE := 0.5  # m of scrap a tree still stands in
const HEAP_NEAR := Rect2(-40.0, -20.0, 32.0, 40.0)  # pile.gd NEAR
const VEIL_ROWS := [[12.0, 0.6], [18.0, 0.8], [25.0, 0.95], [34.0, 1.0]]  # m in from the clearing's edge, how black
const VEIL_H := 19.0  # under the crowns: above them it showed against the sky as pale rays
const WOOD_DARK := 0.32  # a tree's light deep in the wood...
const WOOD_DARK_FROM := 4.0  # ...from this far in from the clearing's edge (m)...
const WOOD_LIGHT_FROM := 55.0  # m in: from here it lightens again
const WOOD_DARK_REACH := 14.0  # ...over this many metres


func _forest() -> void:
	var root := Node3D.new()
	root.name = "Forest"
	root.set_script(preload("res://scripts/forest.gd"))
	add(root)
	var trunks := StaticBody3D.new()
	trunks.name = "Trunks"
	add(trunks, root)
	_trunks = trunks
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var wood := _wood()
	var chunks := {}  # Vector3i (x, z, chunk size) -> Mesh -> [flat transforms, low on the floor, tones]
	var stood := {}  # Vector2i (16 m cell) -> Array[Vector2], the trees so far
	var plant := func(parts: Array, xf: Transform3D, low: bool, chunk := FOREST_CHUNK) -> void:
		var tone := _wood_tone(Vector2(xf.origin.x, xf.origin.z), rng)
		var key := Vector3i(floori(xf.origin.x / chunk), floori(xf.origin.z / chunk), int(chunk))
		if not chunks.has(key):
			chunks[key] = {}
		for part: Array in parts:
			var m: Mesh = part[0]
			if not chunks[key].has(m):
				chunks[key][m] = [PackedFloat32Array(), low, PackedColorArray()]
			var x: Transform3D = xf * part[1]
			var flat: PackedFloat32Array = chunks[key][m][0]
			flat.append_array(PackedFloat32Array([x.basis.x.x, x.basis.x.y, x.basis.x.z, x.basis.y.x, x.basis.y.y, x.basis.y.z,
				x.basis.z.x, x.basis.z.y, x.basis.z.z, x.origin.x, x.origin.y, x.origin.z]))
			chunks[key][m][0] = flat
			var tones: PackedColorArray = chunks[key][m][2]
			tones.append(tone)
			chunks[key][m][2] = tones
	var count := 0
	for dart in FOREST_DARTS:
		var p := Vector2(rng.randf_range(WORLD.position.x, WORLD.end.x), rng.randf_range(WORLD.position.y, WORLD.end.y))
		# 2026-11-04, the user: the trees stopped at a line before the junk. Now right up to the heaps'
		# foot and in among its lowest edge, all round; only the ground players work on stays clear.
		if _heap_h(p) > HEAP_TREE_LINE or HEAP_NEAR.grow(5.0).has_point(p):
			continue
		var away := _out_of_clearing(p) + _desert_noise.get_noise_2d(p.x * 2.0, p.y * 2.0) * 5.0
		var thick := smoothstep(FOREST_START, FOREST_FULL, away)
		if rng.randf() > thick:
			continue
		var open := clampf(_desert_noise.get_noise_2d(p.x * 1.4 + 500.0, p.y * 1.4 - 200.0) * 1.8 + 0.5, 0.0, 1.0)
		var apart := minf(lerpf(FOREST_SPACING.x, FOREST_SPACING.y, open) / maxf(thick, 0.4), 10.0)
		# Past where the fog ends for anyone at the clearing's edge, thinner: it costs less and still reads as wood.
		apart *= lerpf(1.0, FOREST_DEEP_APART, smoothstep(FOREST_DEEP_FROM, FOREST_DEEP_FROM + 25.0, away))
		# Behind the belt thick again: nothing to see through to the world's edge.
		if _past_rim(p.x, p.y, _desert_noise) > 0.0:
			apart = minf(apart, FOREST_SPACING.y * 1.3)
		var cell := Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))
		var free := true
		for i in range(-1, 2):
			for j in range(-1, 2):
				for o: Vector2 in stood.get(cell + Vector2i(i, j), []):
					free = free and o.distance_to(p) >= apart
		if not free:
			continue
		if not stood.has(cell):
			stood[cell] = []
		stood[cell].append(p)
		var kinds: Array = wood.close if _out_of_clearing(p) < WOOD_NEAR_EDGE else wood.trees
		var kind: Array = _pick_tree(rng, kinds, p)
		var sc: float = rng.randf_range(kind[2].x, kind[2].y)
		var ground := _ground_under(p, kind[3] * sc)
		var at := Vector3(p.x, ground - 0.08, p.y)
		# No two standing quite alike even of one kind: a little lean, a little thinner or fatter.
		var lean_to := rng.randf() * TAU
		var lean := Basis(Vector3(cos(lean_to), 0.0, sin(lean_to)), deg_to_rad(rng.randf_range(0.0, WOOD_LEAN)))
		var girth := rng.randf_range(0.88, 1.12)
		var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc * girth, sc, sc * girth)), at)
		plant.call(kind[0], xf, false)
		count += 1
		if _past_rim(p.x, p.y, _desert_noise) == 0.0:  # behind the belt nobody walks up to it
			_posts(kind, xf, trunks, sc * girth)
			var post_at := PackedVector3Array()
			for post: Array in kind[5].posts:
				post_at.append(xf * (post[0] as Vector3))
			_stand_rows.append([kind[4], at, _ground_y(p.x, p.y, _desert_noise), kind[5].touch and kind[5].ok, post_at])
		# The floor between them: ferns, shrubs, a stone.
		if rng.randf() < 0.25:
			var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.8, 2.5)
			var b := at + Vector3(off.x, 0, off.y)
			if _past_rim(b.x, b.z, _desert_noise) == 0.0:
				b.y = _ground_y(b.x, b.z, _desert_noise) - 0.04
				var parts: Array = wood.under[rng.randi() % wood.under.size()]
				plant.call(parts, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.5, 1.0)), b), true)
	for thing: Array in _floor_things:
		plant.call(thing[0], thing[1], true)
	_wood_floor(plant, rng)
	_rim_belt(root, plant, rng)
	# No distance limits at all (2026-11-04, the user: "they load in as you get closer, very
	# annoying"): a range counts from a chunk's middle, so 40 m of ferns and trees came on at once.
	# The fog hides the far ones, and they're a few hundred triangles each.
	var groups := []
	for key: Vector3i in chunks:
		for m: Mesh in chunks[key]:
			var e: Array = chunks[key][m]
			groups.append([m, null, 0.0, 0.0, not e[1], e[0], e[2]])
	root.set("groups", groups)
	# Where each family's trees stand, for tools/wood_mix_check.gd: a copy's mesh box says little about
	# where its foot is (a lopsided crown).
	var stands := {}
	for cell: Vector2i in _tree_fams:
		for o: Array in _tree_fams[cell]:
			if not stands.has(o[1]):
				stands[o[1]] = PackedVector2Array()
			var at: PackedVector2Array = stands[o[1]]
			at.append(o[0])
			stands[o[1]] = at
	root.set_meta("tree_families", stands)
	root.set_meta("stand", _stand_rows)  # tools/wood_stand_check.gd
	print("forest: ", count, " trees in ", chunks.size(), " chunks")
	_veils(root)
	# The wood's inner edge, every 30 degrees round the pad: where the dead can step out.
	for i in 12:
		var a := TAU * i / 12.0
		var dir := Vector2(cos(a), sin(a))
		var p := CLEARING_CENTRE + dir * CLEARING_RADII
		p = p.clamp(WORLD.position + Vector2(10, 10), WORLD.end - Vector2(10, 10))
		if YARD.has_point(p):
			continue  # nobody steps out of the junk behind the yard
		var m := Marker3D.new()
		m.name = "ForestEdge%d" % i
		m.position = Vector3(p.x, _ground_y(p.x, p.y, _desert_noise), p.y)
		add(m, root)
		m.add_to_group("forest_edge", true)


## What a wood's floor has on it (2026-11-04, the user: "too sterile; rocks, rubbish, bones, things
## you'd find in a wood"), never spread evenly: little scenes, each round its own spot: a boulder
## with stones and ferns at its foot, a fallen log with twigs and mushrooms, a dead thing's bones, a
## spot someone dumped rubbish. Between them patches of bare floor, by a low noise. No collision.
## [name, how often, radius m, [[group, least, most], ...]]; every number here is my guess, no rule.
const FLOOR_SCENES := [
	["rocks", 0.13, 2.2, [["boulder", 1, 2], ["rock", 3, 5], ["stone", 4, 8], ["green", 2, 4], ["moss", 2, 4], ["twig", 1, 2]]],
	["scree", 0.1, 2.2, [["rock", 2, 4], ["stone", 8, 14], ["moss", 1, 3], ["green", 1, 2], ["twig", 1, 2]]],
	["deadfall", 0.13, 3.0, [["log", 1, 2], ["twig", 3, 6], ["mushroom", 2, 5], ["green", 1, 2], ["moss", 0, 2]]],
	["stump", 0.11, 3.0, [["stump", 1, 1], ["root", 0, 1], ["twig", 1, 3], ["mushroom", 1, 4], ["moss", 1, 2]]],
	["roots", 0.07, 3.0, [["root", 1, 2], ["twig", 2, 4], ["stone", 1, 3], ["green", 0, 2]]],
	["thicket", 0.16, 3.5, [["green", 4, 8], ["moss", 1, 3], ["twig", 1, 2]]],
	["litter", 0.12, 3.0, [["twig", 4, 7], ["moss", 2, 4], ["stone", 1, 3]]],
	["fungi", 0.05, 2.0, [["mushroom", 4, 8], ["moss", 1, 2], ["twig", 0, 1]]],
	["bones", 0.05, 2.5, [["skull", 1, 1], ["bones", 2, 4], ["twig", 1, 2], ["stone", 0, 2]]],
	["carcass", 0.03, 1.6, [["bones", 3, 6], ["skull", 0, 1], ["green", 0, 1]]],
	["dump", 0.05, 1.5, [["junk", 4, 8], ["twig", 2, 3], ["moss", 1, 3], ["green", 1, 3]]],
]
const FLOOR_SPOTS := 2200  # scenes wanted over the whole ground
const FLOOR_APART := 4.0  # m between two scenes' middles
const FLOOR_CHUNK := 160.0  # m: small things, a few of each: wider squares than the trees', fewer draws
const FLOOR_SOFT := ["green", "moss", "fern", "mushroom", "bark"]  # never in the way
const FLOOR_SOLID_FROM := 0.5  # m high over the ground: lower is stepped over or through (my guess)
const WOOD_LEAN := 3.5  # deg: the most a tree leans off upright
const FLOOR_LIES := ["log", "twig", "bones", "skull", "stone", "junk", "root"]  # tipped off level
const FLOOR_WOOD_ONLY := ["dump", "bones", "carcass", "fungi", "litter"]  # in under the trees, not out in the open


func _wood_floor(plant: Callable, rng: RandomNumberGenerator) -> void:
	var things: Dictionary = _wood().floor
	var decks := {}  # group -> indices still to come: all of a group gone through before one comes again
	var taken := {}  # Vector2i (8 m cell) -> Array[Vector2]
	var made := 0
	var items := 0
	for dart in FLOOR_SPOTS * 60:
		if made >= FLOOR_SPOTS:
			break
		var p := Vector2(rng.randf_range(WORLD.position.x, WORLD.end.x), rng.randf_range(WORLD.position.y, WORLD.end.y))
		if _heap_h(p) > 0.05 or HEAP_NEAR.grow(3.0).has_point(p) or PAD.grow(3.0).has_point(p) or _past_rim(p.x, p.y, _desert_noise) > 0.0:
			continue
		# Patches: a low noise leaves stretches nearly bare. The clearing, where the fighting is, gets few.
		var patch := clampf(_desert_noise.get_noise_2d(p.x * 0.7 - 300.0, p.y * 0.7 + 90.0) * 2.5 + 0.75, 0.08, 1.0)
		patch *= lerpf(0.2, 1.0, smoothstep(-16.0, -2.0, _out_of_clearing(p)))
		if rng.randf() > patch:
			continue
		var cell := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
		var clear := true
		for i in range(-1, 2):
			for j in range(-1, 2):
				for o: Vector2 in taken.get(cell + Vector2i(i, j), []):
					clear = clear and o.distance_to(p) >= FLOOR_APART
		if not clear:
			continue
		if not taken.has(cell):
			taken[cell] = []
		taken[cell].append(p)
		made += 1
		var scene: Array = FLOOR_SCENES[_weighted(rng, FLOOR_SCENES)]
		if _out_of_clearing(p) < -3.0 and scene[0] in FLOOR_WOOD_ONLY:
			continue
		var placed: Array[Vector2] = [p]
		for entry: Array in scene[3]:
			for n in rng.randi_range(entry[1], entry[2]):
				var group: String = entry[0]
				if not decks.has(group) or (decks[group] as Array).is_empty():
					var deck := range((things[group] as Array).size())
					for i in range(deck.size() - 1, 0, -1):  # the shuffle by our own dice: the same wood every build
						var j := rng.randi_range(0, i)
						var t: int = deck[i]
						deck[i] = deck[j]
						deck[j] = t
					decks[group] = deck
				var thing: Array = things[group][decks[group].pop_back()]
				# Close by something already there mostly, so it clumps: no stone off on its own.
				var from: Vector2 = placed[rng.randi() % placed.size()] if rng.randf() < 0.7 else p
				var reach: float = rng.randf_range(0.25, 0.9) if from != p else scene[2] * pow(rng.randf(), 0.8)
				var at := from + Vector2.from_angle(rng.randf() * TAU) * reach
				if _heap_h(at) > 0.05 or PAD.grow(1.0).has_point(at) or _past_rim(at.x, at.y, _desert_noise) > 0.0:
					continue
				placed.append(at)
				var thing_xf := _floor_xf(thing, group, at, rng)
				plant.call(thing[0], thing_xf, true, FLOOR_CHUNK)
				_floor_solid(thing, thing_xf, group)
				items += 1
	print("wood floor: ", made, " scenes, ", items, " things")


## The map's limit: fallen trunks piled along the belt, roots among them, one solid length after another.
## Its own body, so tools/world_limit_check.gd can tell that it closes.
func _rim_belt(root: Node, plant: Callable, rng: RandomNumberGenerator) -> void:
	var things: Dictionary = _wood().floor
	var logs: Array = []
	for log_thing: Array in things["log"]:
		var size: Vector3 = log_thing[2]
		if size[size.max_axis_index()] > 2.0 * minf(size.x, minf(size.y, size.z)):
			logs.append(log_thing)
	var roots: Array = things["root"]
	var wall := StaticBody3D.new()
	wall.name = "RimBelt"
	add(wall, root)
	var a := 0.0
	var n := 0
	var pieces := 0
	while a < TAU + 0.06:  # past the start: no gap where the ring closes
		var dir := Vector2(cos(a), sin(a))
		var at := _rim_point(dir)
		var along := (_rim_point(Vector2(cos(a + 0.05), sin(a + 0.05))) - _rim_point(Vector2(cos(a - 0.05), sin(a - 0.05)))).normalized()  # wide: the wander alone can turn a short step
		a += RIM_STEP / maxf(at.distance_to(RIM_CENTRE), 1.0)
		n += 1
		if _heap_h(at) > 0.05:
			continue
		var out := Vector2(along.y, -along.x)
		if out.dot(dir) < 0.0:
			out = -out
		var yaw := atan2(-along.y, along.x)
		for row in rng.randi_range(2, 5):
			pieces += 1
			var off := at + out * rng.randf_range(-1.4, 1.4) + along * rng.randf_range(-1.2, 1.2)
			var y := _ground_y(off.x, off.y, _desert_noise) + 0.35 + row * rng.randf_range(0.7, 0.95)
			var log_kind: Array = logs[rng.randi() % logs.size()]
			plant.call(log_kind[0], _rim_log(log_kind, off, y, yaw, rng), true, FLOOR_CHUNK)
		if rng.randf() < 0.3:
			var thing: Array = roots[rng.randi() % roots.size()]
			var off := at - out * rng.randf_range(1.5, 3.0)
			plant.call(thing[0], _floor_xf(thing, "root", off, rng), true, FLOOR_CHUNK)
		if n % RIM_SOLID_EVERY == 0:
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = RIM_SOLID
			cs.shape = box
			cs.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, _ground_y(at.x, at.y, _desert_noise) + RIM_SOLID.y * 0.4, at.y))
			add(cs, wall)
	print("rim belt: ", pieces, " trunks")


## Where the belt lies on the way out from its middle along `dir`.
func _rim_point(dir: Vector2) -> Vector2:
	var d := dir / RIM_RADII
	var r := pow(pow(absf(d.x), 4.0) + pow(absf(d.y), 4.0), -0.25)
	var p := RIM_CENTRE + dir * r
	for i in 3:
		p -= dir * _to_rim(p.x, p.y, _desert_noise)
	return p


## A trunk lying along the belt: its long side to `yaw`, a little off level, its middle at (at, y).
func _rim_log(thing: Array, at: Vector2, y: float, yaw: float, rng: RandomNumberGenerator) -> Transform3D:
	var size: Vector3 = thing[2]
	var axis := size.max_axis_index()
	var lay := Basis()  # its long side onto x
	if axis == Vector3.AXIS_Y:
		lay = Basis(Vector3.BACK, -PI * 0.5)
	elif axis == Vector3.AXIS_Z:
		lay = Basis(Vector3.UP, PI * 0.5)
	var dims := [size.x, size.y, size.z]
	dims.sort()
	# As long as a fallen trunk, no thicker than one: the scans are stubby, stretched alone they turn into hills.
	var s: float = minf(rng.randf_range(6.0, 10.0) / maxf(size[axis], 0.1), rng.randf_range(1.1, 1.7) / maxf(dims[1], 0.05))
	var b := Basis(Vector3.UP, yaw + rng.randf_range(-0.45, 0.45)) * Basis(Vector3.BACK, rng.randf_range(-0.22, 0.22)) * lay
	var mid: Vector3 = (b.scaled(Vector3.ONE * s)) * _parts_box(thing[0]).get_center()
	return Transform3D(b.scaled(Vector3.ONE * s), Vector3(at.x, y, at.y) - mid)


## A thing on the floor that stands in the way is solid (2026-11-04, the user: "you walk through them"):
## its own box. Ferns, cans, skulls and the like stay underfoot; green is walked through.
func _floor_solid(thing: Array, xf: Transform3D, group: String) -> void:
	if group in FLOOR_SOFT:
		return
	var box := _parts_box(thing[0])
	var s := xf.basis.get_scale().x
	var size := box.size * s
	if size.y < FLOOR_SOLID_FROM or (xf * box.get_center()).y + size.y * 0.5 < _ground_y(xf.origin.x, xf.origin.z, _desert_noise) + FLOOR_SOLID_FROM:
		return
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = Transform3D(xf.basis.orthonormalized(), xf * box.get_center())
	add(cs, _trunks)


## Where a floor thing lies: sized, turned, off level if it's the kind that lies about, half fallen
## over now and then, a little sunk.
func _floor_xf(thing: Array, group: String, at: Vector2, rng: RandomNumberGenerator) -> Transform3D:
	var s: float = lerpf(thing[1].x, thing[1].y, pow(rng.randf(), 1.8))  # many small, a few big
	var size: Vector3 = thing[2]
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	var lift := -size.y * s * 0.08
	if group in ["boulder", "rock", "stone"]:  # grown out of the ground, not set on it
		lift = -size.y * s * rng.randf_range(0.25, 0.45)
	if group in FLOOR_LIES:
		b = b * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-12.0, 12.0))) * Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-12.0, 12.0)))
		if group == "junk" and rng.randf() < 0.4:  # on its side
			b = b * Basis(Vector3.RIGHT, PI * 0.5)
			lift = size.z * s * 0.4
	return Transform3D(b.scaled(Vector3.ONE * s), Vector3(at.x, _ground_y(at.x, at.y, _desert_noise) + lift, at.y))


## Black between the trees (2026-11-04, the user: "the gaps are grey and show too far; put blackness
## between them, nothing physical, only for the eye"): tall sheets winding through the wood behind
## its first trees, no collision, thinning into nothing near the eye (materials/env/wood_veil.gdshader).
## Who walks in walks through them; what's behind them isn't seen until it steps out.
func _veils(root: Node) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: Array in VEIL_ROWS:
		var along := 0.0
		var last := Vector3.INF
		var steps := 220
		for n in steps + 1:
			var a := TAU * n / steps
			var dir := Vector2(cos(a), sin(a))
			var wander := _desert_noise.get_noise_2d(dir.x * 90.0 + row[0], dir.y * 90.0) * 7.0
			var scale_out: float = 1.0 + (row[0] + wander) / minf(CLEARING_RADII.x, CLEARING_RADII.y)
			var p: Vector2 = CLEARING_CENTRE + dir * CLEARING_RADII * scale_out
			p = p.clamp(WORLD.position + Vector2(2, 2), WORLD.end - Vector2(2, 2))
			var at := Vector3(p.x, _ground_y(p.x, p.y, _desert_noise) - 1.0, p.y)
			var open := _heap_h(p) > 0.2 or HEAP_NEAR.grow(4.0).has_point(p)
			if last != Vector3.INF and not open:
				var d := last.distance_to(at)
				var u0 := along / 7.0
				var u1 := (along + d) / 7.0
				for v: Array in [[last, u0, 0.0], [at, u1, 0.0], [at, u1, 1.0], [last, u0, 0.0], [at, u1, 1.0], [last, u0, 1.0]]:
					st.set_uv(Vector2(v[1], v[2]))
					st.set_color(Color(1, 1, 1, row[1]))
					st.add_vertex(v[0] + Vector3.UP * VEIL_H * v[2])
				along += d
			last = Vector3.INF if open else at
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/env/wood_veil.gdshader")
	var mi := MeshInstance3D.new()
	mi.name = "Veils"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(mi, root)


## Metres of scrap at (x, z) as the game starts (data/heap_mask.json, tools/heap_mask.gd: the height
## field is pile.gd's, which can't load here).
func _heap_h(p: Vector2) -> float:
	if _mask.is_empty():
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/heap_mask.json"))
		_mask = d
		_mask_data = Marshalls.base64_to_raw(d.data)
	var i := floori((p.x - _mask.x0) / _mask.cell)
	var j := floori((p.y - _mask.z0) / _mask.cell)
	if i < 0 or j < 0 or i >= int(_mask.w) or j >= int(_mask.h):
		return 0.0
	return _mask_data[j * int(_mask.w) + i] * 0.1


var _mask := {}
var _mask_data := PackedByteArray()


## How far `p` (x, z) lies outside the clearing's oval, in metres (negative inside).
func _out_of_clearing(p: Vector2) -> float:
	var q := (p - CLEARING_CENTRE) / CLEARING_RADII
	return (q.length() - 1.0) * minf(CLEARING_RADII.x, CLEARING_RADII.y)


## The house. The outside is the model's (tools/build_house.py; no collision of its own), everything
## you touch or see from inside is built here, on the model's openings: plank walls, floor, ceiling and joists. Mended by hand: boards over a window, rusty sheets on the
## roof and on the wall to the mountain, doors of rough plank, an aerial wired in for the television.
func _house() -> void:
	var house := StaticBody3D.new()
	house.name = "House"
	add(house)
	var shell: Node3D = (load(_ps1("res://assets/props/house/house.glb")) as PackedScene).instantiate()
	shell.name = "Shell"
	shell.position = HOUSE_AT
	shell.rotation.y = -PI / 2.0
	add(shell, house)
	var planks: Material = _psx_mat("raw_plank_wall", Color(0.46, 0.42, 0.37), "house_planks", 3.0)
	var floor_mat: Material = _psx_mat("old_wood_floor", Color(0.5, 0.42, 0.34), "house_floor", 1.8)
	var dark: Material = _psx_mat("raw_plank_wall", Color(0.36, 0.3, 0.25), "house_dark", 1.2)
	var door_mat: Material = _psx_mat("rough_pine_door", Color(0.62, 0.54, 0.46), "house_door", 1.4)
	var steel: Material = _psx_mat("rust_coarse_01", Color(0.55, 0.5, 0.46), "workshop_steel", 1.5)
	var x0 := HOUSE.position.x
	var x1 := HOUSE.end.x
	var z0 := HOUSE.position.y
	var z1 := HOUSE.end.y
	var half := WALL_T * 0.5
	_wall(house, false, x0 + half, z0, z1, CEIL_Y, [BACK_DOOR, WIN_W[0], WIN_W[1]], planks)
	_wall(house, false, x1 - half, z0, z1, CEIL_Y, [INNER_DOOR], planks)
	_wall(house, true, z0 + half, x0, x1, CEIL_Y, [NORTH_DOOR], planks)
	_wall(house, true, z1 - half, x0, x1, CEIL_Y, WIN_SOUTH, planks)
	var thin := 0.15
	_wall(house, true, VERANDA.position.y + thin * 0.5, x1, VERANDA.end.x, VERANDA_CEIL, WIN_VERANDA, dark, thin)
	_wall(house, true, VERANDA.end.y - thin * 0.5, x1, VERANDA.end.x, VERANDA_CEIL, WIN_VERANDA, dark, thin)
	_wall(house, false, VERANDA.end.x - thin * 0.5, VERANDA.position.y, VERANDA.end.y, VERANDA_CEIL, [FRONT_DOOR], dark, thin)
	# The sleeping corner: a plank partition, its own doorway.
	_wall(house, false, BED_X, BED_Z, z1 - WALL_T, CEIL_Y, [BED_DOOR], dark, 0.12)
	_wall(house, true, BED_Z, x0 + WALL_T, BED_X + 0.06, CEIL_Y, [], dark, 0.12)
	_wing(house, planks, dark, floor_mat)
	# Floors, a hair over the concrete; ceilings; joists.
	_fine(block(Vector3(x1 - x0, 0.02, z1 - z0), Vector3((x0 + x1) * 0.5, 0.002, 0.0), floor_mat, house))
	_fine(block(Vector3(VERANDA.size.x, 0.02, VERANDA.size.y), Vector3(VERANDA.get_center().x, 0.002, VERANDA.get_center().y), dark, house))
	for roof: Array in [[Vector3(x1 - x0, 0.1, z1 - z0), Vector3((x0 + x1) * 0.5, CEIL_Y + 0.05, 0.0)],
			[Vector3(VERANDA.size.x, 0.1, VERANDA.size.y), Vector3(VERANDA.get_center().x, VERANDA_CEIL + 0.05, VERANDA.get_center().y)]]:
		_fine(block(roof[0], roof[1], dark, house))
		collide(roof[0], roof[1], house)
	var x := x0 + 0.8
	while x < x1 - 0.4:
		block(Vector3(0.12, 0.15, z1 - z0 - WALL_T * 2.0), Vector3(x, CEIL_Y - 0.075, 0.0), dark, house)
		x += 1.55
	# Door frames, leaves standing open: nobody here shuts them for the night any more.
	_door_frame(house, Vector3(VERANDA.end.x - 0.02, 0, FRONT_DOOR[0]), Vector3(VERANDA.end.x - 0.02, 0, FRONT_DOOR[1]), dark)
	_door_frame(house, Vector3(x0 + 0.02, 0, BACK_DOOR[0]), Vector3(x0 + 0.02, 0, BACK_DOOR[1]), dark)
	_door_frame(house, Vector3(x1 - 0.1, 0, INNER_DOOR[0]), Vector3(x1 - 0.1, 0, INNER_DOOR[1]), dark)
	block(Vector3(NORTH_DOOR[1] - NORTH_DOOR[0], 0.04, 0.42), Vector3((NORTH_DOOR[0] + NORTH_DOOR[1]) * 0.5, 0.01, z0 + 0.03), dark, house)
	for side: float in [NORTH_DOOR[0], NORTH_DOOR[1]]:
		block(Vector3(0.11, HOUSE_DOOR_TOP + 0.08, 0.3), Vector3(side, (HOUSE_DOOR_TOP + 0.08) * 0.5, z0 + 0.1), dark, house)
	block(Vector3(NORTH_DOOR[1] - NORTH_DOOR[0] + 0.2, 0.12, 0.3), Vector3((NORTH_DOOR[0] + NORTH_DOOR[1]) * 0.5, HOUSE_DOOR_TOP + 0.03, z0 + 0.1), dark, house)
	_door_leaf(house, Vector3(VERANDA.end.x + 0.04, 0, FRONT_DOOR[0]), Vector3(0.55, 0, -0.83), door_mat, dark)
	_door_leaf(house, Vector3(x0 - 0.04, 0, BACK_DOOR[0]), Vector3(-0.8, 0, -0.6), door_mat, dark)
	# Boards over the south-east window and the sleeping corner's to the mountain, gaps left to look through: light comes in in strips.
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var win: Array = WIN_SOUTH[1]
	for y: float in [1.02, 1.36, 1.62, 2.1]:
		var tilt := Basis(Vector3.BACK, rng.randf_range(-0.09, 0.09))
		block(Vector3(win[1] - win[0] + 0.4, 0.17, 0.03), Vector3((win[0] + win[1]) * 0.5, y, z1 + 0.06), dark, house, tilt)
	win = WIN_W[1]
	for y: float in [1.1, 1.5, 2.05]:
		var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.09, 0.09))
		block(Vector3(0.03, 0.17, win[1] - win[0] + 0.4), Vector3(x0 - 0.06, y, (win[0] + win[1]) * 0.5), dark, house, tilt)
	# Rusty sheets: a stretch of the roof on the yard's side, the wall to the mountain under its south window.
	var patch := Node3D.new()
	patch.name = "Mended"
	add(patch, house)
	var down := Vector3(0.75, -0.66, 0.0).normalized()  # the model's slope towards the yard
	var z := -2.5
	while z < -0.9:
		var b := Basis(Vector3.BACK, down, Vector3.BACK.cross(down)).rotated(down, rng.randf_range(-0.02, 0.02))
		_sheet(patch, b, Vector3(7.25, 5.5 + rng.randf_range(0.0, 0.04), z), 2.3 + rng.randf_range(-0.2, 0.2), rng, true)
		z += SHEET_PITCH
	z = 2.2
	while z < z1 - 0.3:
		var b := Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT).rotated(Vector3.UP, rng.randf_range(-0.015, 0.015))
		_sheet(patch, b, Vector3(x0 - 0.05, rng.randf_range(0.02, 0.09), z), rng.randf_range(1.5, 2.1), rng)
		z += SHEET_PITCH
	# The aerial on the ridge, its wire down the roof to the wall behind the television.
	var ridge := Vector3(5.3, 7.2, -2.4)
	block(Vector3(0.05, 1.7, 0.05), ridge + Vector3(0, 0.75, 0), steel, house)
	for i in 3:
		block(Vector3(0.03, 0.03, 1.1 - i * 0.25), ridge + Vector3(0, 1.0 + i * 0.26, 0), steel, house)
	_rod(house, ridge + Vector3(0, 0.1, 0), Vector3(x0 - 0.1, 3.1, -0.3), 0.025, dark)


## Cuts a box into a grid: the PS1 shader lights per vertex, and a lamp's pool falls between a big box's corners.
func _fine(m: MeshInstance3D) -> MeshInstance3D:
	var box := m.mesh as BoxMesh
	box.subdivide_width = mini(int(box.size.x / LIT_CELL), 24)
	box.subdivide_height = mini(int(box.size.y / LIT_CELL), 10)
	box.subdivide_depth = mini(int(box.size.z / LIT_CELL), 24)
	return m


## The workshop wing: the shed's shell, its walls' inside, floor, ceiling.
func _wing(house: Node, planks: Material, dark: Material, floor_mat: Material) -> void:
	var shell: Node3D = (load(_ps1("res://assets/props/house/wing.glb")) as PackedScene).instantiate()
	shell.name = "Wing"
	shell.position = WING_AT
	shell.rotation.y = -PI / 2.0
	add(shell, house)
	var x0 := WING.position.x
	var x1 := WING.end.x
	var z0 := WING.position.y
	var z1 := WING.end.y
	var half := WING_T * 0.5
	_wall(house, false, x0 + half, z0, z1, WING_CEIL, [WING_DOOR], planks, WING_T)
	_wall(house, false, x1 - half, z0, z1, WING_CEIL, [], planks, WING_T)
	_wall(house, true, z0 + half, x0, x1, WING_CEIL, [], planks, WING_T)
	_wall(house, true, z1 - half, x0, x1, WING_CEIL, [NORTH_DOOR], planks, WING_T)
	_fine(block(Vector3(x1 - x0, 0.02, z1 - z0), Vector3((x0 + x1) * 0.5, 0.002, (z0 + z1) * 0.5), floor_mat, house))
	var lid := Vector3(x1 - x0, 0.1, z1 - z0)
	_fine(block(lid, Vector3((x0 + x1) * 0.5, WING_CEIL + 0.05, (z0 + z1) * 0.5), dark, house))
	collide(lid, Vector3((x0 + x1) * 0.5, WING_CEIL + 0.05, (z0 + z1) * 0.5), house)
	var x := x0 + 0.7
	while x < x1 - 0.3:
		block(Vector3(0.12, 0.14, z1 - z0 - WING_T * 2.0), Vector3(x, WING_CEIL - 0.07, (z0 + z1) * 0.5), dark, house)
		x += 1.6
	_door_frame(house, Vector3(x0 + 0.03, 0, WING_DOOR[0]), Vector3(x0 + 0.03, 0, WING_DOOR[1]), dark)
	_door_leaf(house, Vector3(x0 - 0.04, 0, WING_DOOR[0]), Vector3(-0.75, 0, -0.66), load("res://materials/env/house_door.tres"), dark)


## A wall along x or z, `across` its middle on the other axis, `from`..`to` along it, holes
## [from, to, foot, head] sorted along it. What's solid draws and collides; the holes are the model's.
func _wall(parent: Node, along_x: bool, across: float, from: float, to: float, top: float, holes: Array, mat: Material, thick := WALL_T) -> void:
	var solid := func(a: float, b: float, y0: float, y1: float) -> void:
		if b - a < 0.01 or y1 - y0 < 0.01:
			return
		var size := Vector3(b - a, y1 - y0, thick) if along_x else Vector3(thick, y1 - y0, b - a)
		var at := Vector3((a + b) * 0.5, (y0 + y1) * 0.5, across) if along_x else Vector3(across, (y0 + y1) * 0.5, (a + b) * 0.5)
		_fine(block(size, at, mat, parent))
		collide(size, at, parent)
	var from_here := from
	for h: Array in holes:
		solid.call(from_here, h[0], 0.0, top)
		solid.call(h[0], h[1], 0.0, h[2])
		solid.call(h[0], h[1], h[3], top)
		from_here = h[1]
	solid.call(from_here, to, 0.0, top)


func _door_frame(parent: Node, a: Vector3, b: Vector3, mat: Material) -> void:
	for at: Vector3 in [a, b]:
		block(Vector3(0.11, HOUSE_DOOR_TOP + 0.08, 0.11), at + Vector3(0, (HOUSE_DOOR_TOP + 0.08) * 0.5, 0), mat, parent)
	block(Vector3(0.11, 0.12, absf(b.z - a.z) + 0.2), (a + b) * 0.5 + Vector3(0, HOUSE_DOOR_TOP + 0.03, 0), mat, parent)
	block(Vector3(0.2, 0.04, absf(b.z - a.z)), (a + b) * 0.5 + Vector3(0, 0.01, 0), mat, parent)


## An open door of rough plank hung at `hinge`, standing off along `dir`: two battens and a brace.
func _door_leaf(parent: Node, hinge: Vector3, dir: Vector3, mat: Material, batten: Material) -> void:
	var w := 1.34
	var h := 2.18
	var b := Basis.looking_at(dir.cross(Vector3.UP), Vector3.UP)  # its x along dir, or against it
	if b.x.dot(dir) < 0.0:
		b = b.rotated(Vector3.UP, PI)
	var mid := hinge + dir * w * 0.5 + Vector3(0, h * 0.5 + 0.04, 0)
	block(Vector3(w, h, 0.05), mid, mat, parent, b)
	collide(Vector3(w, h, 0.07), mid, parent, b)
	for y: float in [-0.75, 0.75]:
		block(Vector3(w - 0.1, 0.13, 0.03), mid + b * Vector3(0, y, 0.04), batten, parent, b)
	block(Vector3(1.75, 0.11, 0.025), mid + b * Vector3(0, 0, 0.04), batten, parent, b * Basis(Vector3.BACK, 0.95))


## A thin square rod from a to b.
func _rod(parent: Node, a: Vector3, b: Vector3, thick: float, mat: Material) -> void:
	var d := b - a
	var along := d.normalized()
	var side := along.cross(Vector3.FORWARD).normalized()
	block(Vector3(thick, d.length(), thick), (a + b) * 0.5, mat, parent, Basis(side, along, side.cross(along)))


const SHEET_W := 0.86  # m, one corrugated sheet; laid every SHEET_PITCH, the rest overlaps the next
const SHEET_PITCH := 0.78
var _sheet_meshes := {}
var _sheet_mats: Array[Material] = []


## One corrugated sheet at `foot` (its lower left corner), `length` m along `b.y`, its ripples
## across `b.x`, bulging along `b.z`. Rusty most of them, every so often a galvanised patch.
func _sheet(parent: Node, b: Basis, foot: Vector3, length: float, rng: RandomNumberGenerator, roof := false) -> void:
	if _sheet_mats.is_empty():
		# PS1 at 270p (2026-11-03, the user: the zigzag walls hurt the eyes): plain rust and plate
		# textures, the ripples are the geometry's; each sheet its own tone.
		for v in [["rust_coarse_01", Color(1.0, 0.92, 0.86)], ["rust_coarse_01", Color(0.8, 0.66, 0.58)],
				["rust_coarse_01", Color(0.95, 0.8, 0.66)], ["rust_coarse_01", Color(0.64, 0.54, 0.48)],
				["metal_plate_02", Color(0.78, 0.78, 0.76)], ["rust_coarse_01", Color(0.55, 0.47, 0.43)]]:
			_sheet_mats.append(_psx_mat(v[0], v[1], "workshop_sheet_%d" % _sheet_mats.size()))
	var key := snappedf(length, 0.05)
	if not _sheet_meshes.has(key):
		_sheet_meshes[key] = _sheet_mesh(SHEET_W, key)
	var mi := MeshInstance3D.new()
	mi.mesh = _sheet_meshes[key]
	var r := rng.randf()
	var pick := 4 if r < 0.08 else (5 if r < 0.13 and not roof else rng.randi() % 4)
	mi.material_override = _sheet_mats[pick]
	mi.transform = Transform3D(b, foot)
	mi.position += b.x * rng.randf_range(-0.01, 0.01)
	add(mi, parent)


## A corrugated sheet `w` wide, `h` long: sine ripples 17 cm apart, 3.2 cm deep; UVs in metres
## over a 2 m texture so the rust doesn't stretch with the length.
func _sheet_mesh(w: float, h: float) -> ArrayMesh:
	const PERIOD := 0.172  # five to a sheet: at 270p a ripple is several pixels, not a shimmer
	const AMP := 0.016
	var segs := int(w / PERIOD * 4.0)  # PS1: four points a ripple, lit per vertex
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs + 1:
		var x := w * i / segs
		var k := x / PERIOD * TAU
		var z := sin(k) * AMP
		var n := Vector3(-cos(k) * AMP * TAU / PERIOD, 0, 1).normalized()
		for y: float in [0.0, h]:
			st.set_normal(n)
			st.set_uv(Vector2(x * 0.5, (h - y) * 0.5))
			st.add_vertex(Vector3(x, y, z))
	for i in segs:
		var a := i * 2
		for t in [a, a + 1, a + 2, a + 1, a + 3, a + 2]:
			st.add_index(t)
	return st.commit()


## PS1 horror look (2026-11-02, the user: the whole game PSX horror; tools/psx_props.gd): props
## and the pit's rim pieces come as their <source>_psx.scn wherever there is one.
func _ps1(path: String) -> String:
	var psx := path.get_basename() + "_psx.scn"
	return psx if ResourceLoader.exists(psx) else path


func _prop(parent: Node, path: String, pos: Vector3, yaw: float, s := 1.0, tilt := Basis()) -> StaticBody3D:
	return super(parent, _ps1(path), pos, yaw, s, tilt)


## The ground's textures the PS1 way where there is one (2026-11-03, the user: "the surfaces are
## bad"; tools/psx_props.gd tex): 128 px in the desert's colours, no normal map, flat roughness.
const PSX_TEX := "res://assets/psx/tex/%s.res"
const FLAT_ARM := "res://assets/psx/tex/flat_arm.res"


func _psx_tex(id: String) -> Texture2D:
	return load(PSX_TEX % id) if ResourceLoader.exists(PSX_TEX % id) else null


func worn(id: String, save_as: String, params: Dictionary) -> ShaderMaterial:
	var m: ShaderMaterial = super(id, save_as, params)
	var tex := _psx_tex(id)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("normal_tex", null)
		m.set_shader_parameter("arm_tex", load(FLAT_ARM))
		ResourceSaver.save(m, m.resource_path)
	return m


func pbr_box(id: String, metres: float, tint := Color.WHITE, world := true, save_as := "") -> ORMMaterial3D:
	var m: ORMMaterial3D = super(id, metres, tint, world, save_as)
	var tex := _psx_tex(id)
	if tex:
		m.albedo_texture = tex
		m.normal_enabled = false
		m.normal_texture = null
		m.orm_texture = load(FLAT_ARM)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		ResourceSaver.save(m, m.resource_path)
	return m


func _cukur(piece: String, xf: Transform3D, parent: Node) -> void:
	var n: Node3D = (load(_ps1(CUKUR + piece + ".gltf")) as PackedScene).instantiate()
	n.transform = xf
	add(n, parent)


## The workshop's sheets and steel, PS1: the texture small and unfiltered (assets/psx/tex/, made by
## tools/psx_props.gd tex), lit per vertex, drawn from both sides; `metres` > 0 maps it by world
## position every `metres` (the steel boxes) instead of by UV.
func _psx_mat(id: String, tint: Color, save_as: String, metres := 0.0) -> Material:
	var m := ShaderMaterial.new()
	m.shader = load("res://materials/psx_prop_2s.gdshader")
	m.set_shader_parameter("albedo_tex", load("res://assets/psx/tex/%s.res" % id))
	m.set_shader_parameter("tint", tint)
	if metres > 0.0:
		m.set_shader_parameter("triplanar", true)
		m.set_shader_parameter("tri_metres", metres)
	var path := "res://materials/env/%s.tres" % save_as
	ResourceSaver.save(m, path)
	return load(path)


## Inside (2026-11-05, the user: everything a real model, dim, left behind). What a mountain hut holds:
## its stove at the heart, a table, a food cupboard, a bed in a corner; long left, it has been gone through
## and things lie where they fell. The wing is the workshop: the crew's bench with the press, the hopper, the
## radio playing its 78s; tools; a stump and an axe by the door to the mountain.
func _workshop_inside() -> void:
	var root := Node3D.new()
	root.name = "Bench"
	add(root)
	var yaw := 0.0  # the bench's front (+z in its glb) to the room
	var turn := Basis(Vector3.UP, yaw)
	var bench: StaticBody3D = _prop(root, "res://assets/props/workbench/workbench.glb", BENCH_AT, yaw, BENCH_SCALE)
	bench.set_script(preload("res://scripts/bench_top.gd"))
	var press: StaticBody3D = _prop(bench, "res://assets/props/press/press.glb", Vector3(0.8, 0.779, -0.11), 0.0)
	press.name = "Press"
	press.set_script(preload("res://scripts/press.gd"))
	# The hopper on the bench's right, as in the hall (range_dressing.gd _workshop): 2.06 m along its x.
	var hopper: StaticBody3D = _prop(root, "res://assets/props/workbench/hopper.glb", BENCH_AT + turn * Vector3(2.064, 0, 0.25), yaw)
	hopper.set_script(preload("res://scripts/hopper.gd"))
	_bench_radio(bench)
	# The pistol on an army crate in front of the spawns (scripts/gun_table.gd; the user took the
	# office desk out, 2026-11-02): taken, the crate fades away.
	var desk := _prop(root, MODELS + "wooden_military_crate/wooden_military_crate_1k.gltf", DESK_AT, PI / 2.0, 1.65)  # its lid at desk height
	desk.name = "GunTable"
	desk.set_script(preload("res://scripts/gun_table.gd"))
	# The television (2026-11-05, the user: an old tube set, the news on it every day; scripts/tv.gd) on
	# a crate, the sofa turned to it on an old rug.
	_prop(root, MODELS + "wooden_crate_01/wooden_crate_01_1k.gltf", TV_AT, 0.08, TV_STAND_SCALE)
	var tv := _prop(root, MODELS + "Television_01/Television_01_1k.gltf", TV_AT + Vector3(0, TV_STAND_TOP, 0), TV_YAW)
	tv.name = "TV"
	tv.set_script(preload("res://scripts/tv.gd"))
	_flat(root, "res://assets/props/house/old_rug.glb", Vector3(3.6, 0.015, -0.9), 0.15, 0.5)
	_prop(root, MODELS + "sofa_02/sofa_02_1k.gltf", Vector3(4.35, 0, -1.6), -1.4)
	# The stove, the hut's heart, cold; its wood; the pot left on it.
	var stove_at := Vector3(8.2, 0, -2.6)
	_centre(_prop(root, "res://assets/props/house/wood_stove.glb", stove_at, -PI / 2.0, STOVE_SCALE), stove_at)
	_prop(root, MODELS + "pot_enamel_01/pot_enamel_01_1k.gltf", stove_at + Vector3(-0.02, STOVE_TOP, 0.05), 0.7)
	_wood_pile(root, Vector3(8.25, 0, -1.25))
	_prop(root, MODELS + "wooden_broom/wooden_broom_1k.gltf", Vector3(8.62, 0, -0.75), 0.4, 1.0, Basis(Vector3.BACK, -0.1))
	# The table by the boarded window: one chair still at it, one thrown over, tins nobody came back for.
	var table_at := Vector3(6.75, 0, 2.75)
	_prop(root, MODELS + "WoodenTable_01/WoodenTable_01_1k.gltf", table_at, 0.05)
	_prop(root, MODELS + "WoodenChair_01/WoodenChair_01_1k.gltf", table_at + Vector3(-0.2, 0, -0.7), 0.25, CHAIR_SCALE)
	_prop(root, MODELS + "WoodenChair_01/WoodenChair_01_1k.gltf", Vector3(8.2, 0.18, 2.95), 1.2, CHAIR_SCALE, Basis(Vector3.RIGHT, -PI / 2.0))
	_prop(root, MODELS + "russian_food_cans_01/russian_food_cans_01_1k.gltf", table_at + Vector3(0.15, TABLE_TOP, 0.05), 0.5)
	_prop(root, MODELS + "vintage_oil_lamp/vintage_oil_lamp_1k.gltf", table_at + Vector3(-0.3, TABLE_TOP, -0.1), 2.0, 0.45)
	# Against the north wall: the food cupboard, the shelf gone through.
	_prop(root, MODELS + "painted_wooden_cabinet/painted_wooden_cabinet_1k.gltf", Vector3(7.0, 0, -3.36), 0.0)
	_prop(root, MODELS + "wooden_bookshelf_worn/wooden_bookshelf_worn_1k.gltf", Vector3(3.6, 0, -3.39), 0.0)
	_prop(root, MODELS + "wooden_bucket_01/wooden_bucket_01_1k.gltf", Vector3(5.5, 0, 3.35), 0.5)
	_prop(root, MODELS + "wall_clock/wall_clock_1k.gltf", Vector3(8.76, 1.95, 2.2), -PI / 2.0)  # stopped
	_prop(root, MODELS + "rubber_boots/rubber_boots_1k.gltf", Vector3(2.05, 0, -1.45), PI / 2.0)
	_prop(root, MODELS + "street_rat/street_rat_1k.gltf", Vector3(4.95, 0.02, 3.3), 2.4, 2.0)  # dead a good while
	_prop(root, MODELS + "mousetrap/mousetrap_1k.gltf", Vector3(8.3, 0.01, 1.95), 0.9)
	# The sleeping corner: an iron bed, nightstand, a suitcase half packed, the mask ready.
	_prop(root, MODELS + "old_bed_frame/old_bed_frame_1k.gltf", Vector3(2.95, 0, 2.95), BED_YAW, BED_SCALE)
	_prop(root, MODELS + "painted_wooden_nightstand/painted_wooden_nightstand_1k.gltf", Vector3(2.15, 0, 1.55), PI / 2.0)
	_prop(root, MODELS + "old_gas_mask/old_gas_mask_1k.gltf", Vector3(2.15, NIGHTSTAND_TOP, 1.55), 0.5)
	_prop(root, MODELS + "vintage_suitcase/vintage_suitcase_1k.gltf", Vector3(4.32, 0, 3.32), PI / 2.0, 0.5)
	# The wing, along its walls.
	_prop(root, MODELS + "steel_frame_shelves_01/steel_frame_shelves_01_1k.gltf", Vector3(8.35, 0, -6.6), PI / 2.0, 0.1)  # the scan is 10x too big
	_prop(root, MODELS + "metal_tool_chest/metal_tool_chest_1k.gltf", Vector3(7.5, 0, -7.65), 0.0)
	_prop(root, MODELS + "tool_cart/tool_cart_1k.gltf", Vector3(8.2, 0, -4.8), PI)
	_prop(root, MODELS + "metal_jerrycan/metal_jerrycan_1k.gltf", Vector3(2.15, 0, -7.6), 0.5)
	_prop(root, MODELS + "small_lpg_tank/small_lpg_tank_1k.gltf", Vector3(2.65, 0, -7.65), 0.0)
	_prop(root, MODELS + "cement_bag/cement_bag_1k.gltf", Vector3(2.2, 0, -6.75), 1.3)
	_prop(root, MODELS + "wicker_basket_01/wicker_basket_01_1k.gltf", Vector3(7.0, 0, -4.45), 0.2)
	var stump_at := Vector3(2.4, 0.1, -7.1)
	_prop(root, MODELS + "tree_stump_01/tree_stump_01_1k.gltf", stump_at, 0.6, STUMP_SCALE)
	_prop(root, MODELS + "hatchet/hatchet_1k.gltf", stump_at + Vector3(0, STUMP_TOP, 0), 1.0, 2.0, Basis(Vector3.BACK, PI / 2.0))
	# Veranda and yard.
	_prop(root, MODELS + "metal_jerrycan/metal_jerrycan_1k.gltf", Vector3(11.1, 0, 3.0), 0.5)
	_prop(root, MODELS + "wooden_stool_01/wooden_stool_01_1k.gltf", Vector3(9.6, 0, 2.85), 0.5)
	_prop(root, MODELS + "portable_generator/portable_generator_1k.gltf", Vector3(9.75, 0, -2.2), 1.3)  # outside the east wall, the yard's side
	_prop(root, MODELS + "wooden_military_crate/wooden_military_crate_1k.gltf", Vector3(10.8, 0, 5.2), 0.1)
	_prop(root, MODELS + "wooden_crate_01/wooden_crate_01_1k.gltf", Vector3(10.8, 0.465, 5.25), 0.25)
	# Cobwebs in the corners and off the joists (the Free Pack's cards, each its own mesh).
	for web: Array in [[5, Vector3(8.78, 2.68, -3.66), -2.4], [7, Vector3(1.84, 2.65, -3.62), 0.75], [12, Vector3(1.84, 2.62, 0.72), 2.3],
			[8, Vector3(8.74, 2.66, 3.62), -0.8], [14, Vector3(1.75, 2.3, -7.95), 0.8], [4, Vector3(8.65, 2.32, -7.9), -0.75], [3, Vector3(11.48, 2.28, 3.2), -0.8]]:
		_web(root, web[0], web[1], web[2])
	# Light, what is left of it (2026-11-05, the user: the bench's lamp goes, ceiling lamps that suit the
	# place): a bare bulb on a chain in the room and one in the wing, an old lantern on a beam in the wing;
	# the sleeping corner and the veranda have none. ambience.gd hums near the "Lamps".
	var lamps := Node3D.new()
	lamps.name = "Lamps"
	add(lamps)
	_lamp(lamps, Vector3(6.3, CEIL_Y - 0.32, 0.2), "pull_chain_light_socket", 5.0)
	_lamp(lamps, Vector3(3.2, WING_CEIL - 0.28, -6.0), "pull_chain_light_socket", 4.2)
	_rod(lamps, Vector3(6.3, CEIL_Y, 0.2), Vector3(6.3, CEIL_Y - 0.33, 0.2), 0.018, load("res://materials/env/house_dark.tres"))
	_rod(lamps, Vector3(3.2, WING_CEIL, -6.0), Vector3(3.2, WING_CEIL - 0.29, -6.0), 0.018, load("res://materials/env/house_dark.tres"))
	_lamp(lamps, Vector3(6.9, WING_CEIL - 0.1, -6.2), "Lantern_01", 3.0)
	# A fire in the burn barrel in front of the house, where the crew stands at night.
	var fire: StaticBody3D = _prop(root, "res://assets/props/burn_barrel/burn_barrel.glb", Vector3(12.5, 0, -10.0), 0.4)
	var burning := Node3D.new()
	burning.name = "BarrelFire"
	burning.set_script(preload("res://scripts/barrel_fire.gd"))
	burning.set("rim", 0.914)
	burning.set("inner", 0.29)
	burning.set("bed", 0.545)
	burning.set("logs", false)
	add(burning, fire)
	_prop(root, MODELS + "old_tyre/old_tyre_1k.gltf", Vector3(13.5, 0.12, -9.3), 0.0, 1.0, Basis(Vector3.RIGHT, PI / 2.0))


## A model that lies on the floor: no collision.
func _flat(parent: Node, path: String, at: Vector3, yaw: float, s: float) -> void:
	var inst: Node3D = (load(_ps1(path)) as PackedScene).instantiate()
	inst.position = at
	inst.rotation.y = yaw
	inst.scale = Vector3.ONE * s
	add(inst, parent)
	_centre(inst, at)


## A model whose file sits far off its origin: moved so its middle is over `at`.
func _centre(n: Node3D, at: Vector3) -> void:
	var c := _aabb(n, Transform3D()).get_center()
	n.position += Vector3(at.x - c.x, 0.0, at.z - c.z)


## The Wood Pile Pack's logs, each its own mesh, stacked lying down.
func _wood_pile(parent: Node, at: Vector3) -> void:
	var pack: Node3D = (load(_ps1("res://assets/props/house/wood_pile.glb")) as PackedScene).instantiate()
	var meshes: Array[Mesh] = []
	for mi: MeshInstance3D in pack.find_children("*", "MeshInstance3D", true, false):
		if not mi.name.contains("Pole"):
			meshes.append(mi.mesh)
	pack.free()
	var pile := StaticBody3D.new()
	pile.name = "WoodPile"
	pile.position = at
	add(pile, parent)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var count := 0
	for layer in 3:
		for i in 4 - layer:
			var m := MeshInstance3D.new()
			m.mesh = meshes[count % meshes.size()]
			count += 1
			var box := m.mesh.get_aabb()
			var lie := Basis()  # its longest side along x, lying down
			if box.size.y >= box.size.x and box.size.y >= box.size.z:
				lie = Basis(Vector3.BACK, PI / 2.0)
			elif box.size.z >= box.size.x:
				lie = Basis(Vector3.UP, PI / 2.0)
			lie = Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)) * lie
			lie = lie.scaled(Vector3.ONE * WOOD_LENGTH / maxf(box.size.x, maxf(box.size.y, box.size.z)))
			m.transform = Transform3D(lie, Vector3(0, 0.09 + layer * 0.15, (i - (3 - layer) * 0.5) * 0.19 + layer * 0.02) - lie * box.get_center())
			add(m, pile)
	collide(Vector3(0.5, 0.5, 0.8), Vector3(0, 0.25, 0), pile)


## Cobweb card `n` of the Free Pack, its middle at `at`, turned to `yaw`, upright; no collision, no shadow.
func _web(parent: Node, n: int, at: Vector3, yaw: float) -> void:
	var pack: Node3D = (load("res://assets/props/house/cobwebs.glb") as PackedScene).instantiate()
	var mi := pack.find_child("SM_Cobwebs_%02d*" % n, true, false) as MeshInstance3D
	if mi == null:
		for c: MeshInstance3D in pack.find_children("*", "MeshInstance3D", true, false):
			if c.name.contains("Cobwebs_%02d" % n):
				mi = c
	var web := MeshInstance3D.new()
	web.name = "Cobweb%d" % n
	web.mesh = mi.mesh
	pack.free()
	var box := web.mesh.get_aabb()
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2.0 if box.size.y < box.size.z else 0.0)
	b = b.scaled(Vector3.ONE * WEB_SCALE / maxf(box.size.x, maxf(box.size.y, box.size.z)))
	web.transform = Transform3D(b, at - b * box.get_center())
	web.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var thin := (web.mesh.surface_get_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
	thin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # a white card at 480 lines otherwise
	thin.albedo_color = Color(0.62, 0.62, 0.58, 0.38)
	thin.cull_mode = BaseMaterial3D.CULL_DISABLED
	web.material_override = thin
	add(web, parent)



## A lamp off the ceiling at `at` (2026-11-05, the user: lamps that suit the place): `model`, a dim warm
## pool down, a soft fill round it.
func _lamp(parent: Node, at: Vector3, model: String, energy: float, shadow := false) -> void:
	var inst: Node3D = (load(_ps1(MODELS + "%s/%s_1k.gltf" % [model, model])) as PackedScene).instantiate()
	var box := _aabb(inst, Transform3D())
	var roof := at.y - 0.06
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(at.x, roof - box.end.y, at.z)
	add(lamp, parent)
	add(inst, lamp)
	_own(inst)
	if model == "pull_chain_light_socket":  # the socket's bare bulb, screwed in from below
		var bulb: Node3D = (load(_ps1(MODELS + "lightbulb_01/lightbulb_01_1k.gltf")) as PackedScene).instantiate()
		bulb.position = Vector3(0, box.position.y + 0.01, 0)
		bulb.rotation.x = PI
		add(bulb, lamp)
		_own(bulb)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.68, 0.36)
		for mi: MeshInstance3D in bulb.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = glow
	var bulb_y := box.position.y + box.size.y * 0.3
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, bulb_y, 0)
	spot.basis = Basis.looking_at(Vector3.DOWN, Vector3.FORWARD)
	spot.light_color = Color(1.0, 0.72, 0.42)
	spot.light_energy = energy
	spot.spot_range = 5.5
	spot.spot_angle = 80.0
	spot.spot_angle_attenuation = 0.9
	spot.shadow_enabled = shadow
	spot.light_volumetric_fog_energy = 0.5
	add(spot, lamp)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, bulb_y, 0)
	fill.light_color = Color(1.0, 0.7, 0.4)
	fill.light_energy = energy * 0.22
	fill.omni_range = 4.0
	add(fill, lamp)
	# The bulb glows the light's own warm colour, not white.
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m and m.emission_enabled:
				m = m.duplicate()
				m.emission = Color(1.0, 0.62, 0.3)
				m.emission_energy_multiplier = minf(m.emission_energy_multiplier, 2.0)
				m.albedo_color = m.albedo_color * Color(1.0, 0.8, 0.6)
				mi.set_surface_override_material(i, m)


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
	sound.unit_size = 1.5  # heard at the bench and the desk, gone a few steps out (2026-11-03, the user: the songs stay, the range shrinks)
	sound.max_distance = 9.0
	sound.position = Vector3(0, 0.1, 0)
	add(sound, radio)


## Four co-op spawns under the front of the workshop roof, facing the desk and the back wall.
func _world_spawns() -> void:
	var spawns := Node3D.new()
	spawns.name = "Spawns"
	add(spawns)
	for i in SPAWNS_WORLD.size():
		var m := Marker3D.new()
		m.name = "Spawn%d" % (i + 1)
		m.position = SPAWNS_WORLD[i]
		m.basis = Basis.looking_at(Vector3.LEFT)  # at the television, the window and the mountain past it
		add(m, spawns)
		m.add_to_group("spawn", true)


func _own(n: Node) -> void:
	n.owner = arena
	for c in n.get_children():
		_own(c)
