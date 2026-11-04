extends "res://tools/build_arena.gd"
## Builds scenes/world.tscn, the open ground (2026-11-02, the user: the old hall and everything in it
## goes; a wide rectangle out in the open, Mad Max wasteland, a light desert with a few dead trees):
## a concrete pad, on it the workshop (open to the front, a lean-to roof on posts, the crew's bench
## with its radio and the desk with the pistol brought over from the hall); behind it the back yard,
## flat ground with the junkyard (scripts/pile.gd: a scrap heap, mountains of scrap behind it);
## round it all sand and cracked earth rising into dunes at the edges.
## The scene is never edited by hand: change the numbers here and re-run
##   godot --headless --path . -s res://tools/build_world.gd
## The helpers (add, worn, pbr_box, _prop, block, collide, pendant, _pit...) are build_arena.gd's.

const WORLD := Rect2(-136.0, -80.0, 256.0, 160.0)  # x, z: the ground, the junkyard's grid included, so the ring of dunes closes behind the mountain too
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
const EDGE_RISE := 12.0  # m the dunes climb to at the world's edge: the players' natural border
const EDGE_REACH := 28.0  # m in from the edge over which they climb
## What ends the walk: no wall, the dunes turn into a sand cliff too steep to climb (the player's
## floor_max_angle is 60 degrees, tan 1.73), its foot wandering in and out through the fog.
const RIM_REACH := 3.0  # m in from the edge where the cliff's foot lies at the closest...
const RIM_WANDER := 4.0  # m ...and this much further in at the furthest
const RIM_SLOPE := 3.0  # m up per m in

## The workshop: back wall on x = WS.position.x, open towards +x (the yard, the spawns).
const WS := Rect2(2.0, -4.5, 7.0, 9.0)  # 2026-11-02, the user: half as long, compact like a van
const WS_BACK_H := 3.4  # m, the roof over the back wall
const WS_FRONT_H := 2.9  # m, its front edge: the lean-to drains forwards
const WS_POSTS: Array[float] = [-4.5, 0.0, 4.5]  # z of each post line, front and back
const BENCH_AT := Vector3(2.6, 0, 1.2)  # the crew's bench, its back on the back wall
const BENCH_SCALE := 1.2  # as it stood in the hall (range_dressing.gd _workshop)
const DESK_AT := Vector3(8.2, 0, 0.0)  # the pistol's crate, right in front of the spawns

const SPAWNS_WORLD: Array[Vector3] = [Vector3(9.3, 0, -0.8), Vector3(9.3, 0, 0.8), Vector3(9.3, 0, -2.4), Vector3(9.3, 0, 2.4)]
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
	_workshop_shed()
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
	var edge := minf(minf(x - WORLD.position.x, WORLD.end.x - x), minf(z - WORLD.position.y, WORLD.end.y - z))
	var ridge := noise.get_noise_2d(x * 0.45 + 300.0, z * 0.45) * 0.5 + 0.5
	h += pow(1.0 - clampf(edge / EDGE_REACH, 0.0, 1.0), 1.8) * EDGE_RISE * (0.45 + 0.9 * ridge)
	h += _past_rim(x, z, noise) * RIM_SLOPE
	return h


## How far (x, z) lies up the cliff at the world's edge, in metres past its foot; 0 off it.
func _past_rim(x: float, z: float, noise: FastNoiseLite) -> float:
	var edge := minf(minf(x - WORLD.position.x, WORLD.end.x - x), minf(z - WORLD.position.y, WORLD.end.y - z))
	var wander := noise.get_noise_2d(x * 0.6 + 700.0, z * 0.6) * 0.5 + 0.5
	return maxf(RIM_REACH + wander * RIM_WANDER - edge, 0.0)


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
		_wood_tree(root, wood.close[_weighted(rng, wood.close)], p, rng)
	for p: Vector3 in spots.call(120, 3.0, 120.0, true, 2.5):
		_wood_low(wood.under[rng.randi() % wood.under.size()], p, rng, Vector2(0.5, 0.9))
	for p: Vector3 in spots.call(50, 3.0, 60.0, true, 2.0):
		_wood_low(wood.rocks[rng.randi() % wood.rocks.size()], p, rng, Vector2(0.8, 2.2))
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


const WOOD_NEAR_EDGE := 14.0  # m in from the clearing's edge: only trees with real branches, where players walk up to them;
# the pack's background trees (one card for a whole crown, big blocks from under it) further in


## One kind: [[mesh, its transform], ...] standing on its origin: over its trunk if it has one
## (a crown is lopsided), else over the middle of its box.
func _wood_kind(file: String, names: Array) -> Array:
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
		parts.append([mi.mesh, x])
		var b: AABB = x * mi.mesh.get_aabb()
		if String(mi.name).contains("Trunk"):
			box = b
			trunk = true
		elif not trunk:
			box = b if parts.size() == 1 else box.merge(b)
	scene.free()
	var foot := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	for part: Array in parts:
		part[1] = Transform3D(Basis(), -foot) * part[1]
	return parts


func _wood() -> Dictionary:
	if _wood_kinds.is_empty():
		var trees := []
		var close := []
		for k: Array in WOOD_TREES:
			trees.append([_wood_kind(k[0], k[1]), k[2], k[3], k[4]])
			if k[1].is_empty() or not String(k[1][0]).begins_with("Background"):
				close.append([trees[-1][0], k[2] / 0.34, k[3], k[4]])  # shares that add up to about 1 again
		var under := []
		for n in ["_009", "_010", "_011", "_012"]:
			under.append(_wood_kind(WOOD_PACK, [AT % n]))
		var rocks := []
		for n in ["", "_001", "_002", "_003", "_004", "_005", "_006", "_007", "_008"]:
			rocks.append(_wood_kind(WOOD_PACK, ["Rocks%s_Rocks_0" % n]))
		_wood_kinds = {"trees": trees, "close": close, "under": under, "rocks": rocks}
	return _wood_kinds


## A tree of the clearing, its post round the trunk.
func _wood_tree(parent: Node, kind: Array, at: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(kind[2].x, kind[2].y)
	var body := StaticBody3D.new()
	body.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), at - Vector3(0, 0.08, 0))
	add(body, parent)
	for part: Array in kind[0]:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.transform = part[1]
		add(mi, body)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = kind[3]
	cyl.height = 2.4 / s
	cs.shape = cyl
	cs.position = Vector3(0, 1.2 / s, 0)
	add(cs, body)


## Something low on the floor, no collision: a fern, a stone, a log. Drawn with the wood (_forest).
func _wood_low(parts: Array, at: Vector3, rng: RandomNumberGenerator, size: Vector2) -> void:
	_floor_things.append([parts, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(size.x, size.y)), at - Vector3(0, 0.05, 0))])


var _floor_things := []


## A copy's tone: from the clearing's edge into the wood it goes dark, so the first trees show and
## behind them it's black between the trunks; some yellower, some browner, a few half dead.
func _wood_tone(p: Vector2, rng: RandomNumberGenerator) -> Color:
	var deep := smoothstep(WOOD_DARK_FROM, WOOD_DARK_FROM + WOOD_DARK_REACH, _out_of_clearing(p) + rng.randf_range(-3.0, 3.0))
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
const FOREST_DARTS := 90000
const FOREST_CHUNK := 40.0
const HEAP_TREE_LINE := 0.5  # m of scrap a tree still stands in
const HEAP_NEAR := Rect2(-40.0, -20.0, 32.0, 40.0)  # pile.gd NEAR
const VEIL_ROWS := [[12.0, 0.6], [18.0, 0.8], [25.0, 0.95], [34.0, 1.0]]  # m in from the clearing's edge, how black
const VEIL_H := 19.0  # under the crowns: above them it showed against the sky as pale rays
const WOOD_DARK := 0.32  # a tree's light deep in the wood...
const WOOD_DARK_FROM := 4.0  # ...from this far in from the clearing's edge (m)...
const WOOD_DARK_REACH := 14.0  # ...over this many metres


func _forest() -> void:
	var root := Node3D.new()
	root.name = "Forest"
	root.set_script(preload("res://scripts/forest.gd"))
	add(root)
	var trunks := StaticBody3D.new()
	trunks.name = "Trunks"
	add(trunks, root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var wood := _wood()
	var chunks := {}  # Vector2i -> Mesh -> [flat transforms, low on the floor, tones]
	var stood := {}  # Vector2i (16 m cell) -> Array[Vector2], the trees so far
	var plant := func(parts: Array, xf: Transform3D, low: bool) -> void:
		var tone := _wood_tone(Vector2(xf.origin.x, xf.origin.z), rng)
		var key := Vector2i(floori(xf.origin.x / FOREST_CHUNK), floori(xf.origin.z / FOREST_CHUNK))
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
		if _heap_h(p) > HEAP_TREE_LINE or HEAP_NEAR.grow(5.0).has_point(p) or _past_rim(p.x, p.y, _desert_noise) > 0.0:
			continue
		var away := _out_of_clearing(p) + _desert_noise.get_noise_2d(p.x * 2.0, p.y * 2.0) * 5.0
		var thick := smoothstep(FOREST_START, FOREST_FULL, away)
		if rng.randf() > thick:
			continue
		var open := clampf(_desert_noise.get_noise_2d(p.x * 1.4 + 500.0, p.y * 1.4 - 200.0) * 1.8 + 0.5, 0.0, 1.0)
		var apart := minf(lerpf(FOREST_SPACING.x, FOREST_SPACING.y, open) / maxf(thick, 0.4), 10.0)
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
		var kind: Array = kinds[_weighted(rng, kinds)]
		var sc: float = rng.randf_range(kind[2].x, kind[2].y)
		var at := Vector3(p.x, _ground_y(p.x, p.y, _desert_noise) - 0.08, p.y)
		plant.call(kind[0], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), at), false)
		count += 1
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = minf(kind[3] * sc, 0.5)
		cyl.height = 2.4
		cs.shape = cyl
		cs.position = at + Vector3(0, 1.2, 0)
		add(cs, trunks)
		# The floor between them: ferns, shrubs, a stone.
		if rng.randf() < 0.55:
			var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.8, 2.5)
			var b := at + Vector3(off.x, 0, off.y)
			if _past_rim(b.x, b.z, _desert_noise) == 0.0:
				b.y = _ground_y(b.x, b.z, _desert_noise) - 0.04
				var stone := rng.randf() < 0.2
				var parts: Array = wood.rocks[rng.randi() % wood.rocks.size()] if stone else wood.under[rng.randi() % wood.under.size()]
				plant.call(parts, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.5, 1.0)), b), true)
	for thing: Array in _floor_things:
		plant.call(thing[0], thing[1], true)
	# No distance limits at all (2026-11-04, the user: "they load in as you get closer, very
	# annoying"): a range counts from a chunk's middle, so 40 m of ferns and trees came on at once.
	# The fog hides the far ones, and they're a few hundred triangles each.
	var groups := []
	for key: Vector2i in chunks:
		for m: Mesh in chunks[key]:
			var e: Array = chunks[key][m]
			groups.append([m, null, 0.0, 0.0, not e[1], e[0], e[2]])
	root.set("groups", groups)
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


## The workshop's shell (2026-11-02, the user: "it looks like a sharp box"): nothing in it is one
## clean slab. Walls and roof are separate corrugated sheets with real ripples, each overlapping the
## last, a little off true, its own tone of rust, here and there a galvanised patch, ragged at the
## foot; steel posts with knee braces, rafters and purlins. Closed on three sides, open to the yard.
func _workshop_shed() -> void:
	var shed := StaticBody3D.new()
	shed.name = "Workshop"
	add(shed)
	var steel: Material = _psx_mat("rust_coarse_01", Color(0.55, 0.5, 0.46), "workshop_steel", 1.5)
	var x0 := WS.position.x
	var x1 := WS.end.x
	var roof_y := func(x: float) -> float: return WS_BACK_H + (x - x0) / (x1 - x0) * (WS_FRONT_H - WS_BACK_H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for z: float in WS_POSTS:
		for x: float in [x0 + 0.1, x1 - 0.1]:
			var h: float = roof_y.call(x) - 0.12
			block(Vector3(0.14, h, 0.14), Vector3(x, h * 0.5, z), steel, shed)
			collide(Vector3(0.16, h, 0.16), Vector3(x, h * 0.5, z), shed)
			block(Vector3(0.34, 0.02, 0.34), Vector3(x, 0.01, z), steel, shed)  # base plate
		# The rafter under the roof, front to back, and a knee brace under its front end.
		var run := Vector3(x1 - x0, WS_FRONT_H - WS_BACK_H, 0)
		var slope := Basis(Vector3.BACK, atan2(run.y, run.x))
		block(Vector3(run.length() + 0.3, 0.14, 0.08), Vector3((x0 + x1) * 0.5, (WS_BACK_H + WS_FRONT_H) * 0.5 - 0.12, z), steel, shed, slope)
		block(Vector3(0.9, 0.07, 0.07), Vector3(x1 - 0.42, WS_FRONT_H - 0.6, z), steel, shed, Basis(Vector3.BACK, deg_to_rad(42.0)))
	for x: float in [x0 + 0.1, x1 - 0.1]:  # the eaves beams along the front and back
		block(Vector3(0.1, 0.18, WS.size.y + 0.3), Vector3(x, roof_y.call(x) - 0.21, WS.get_center().y), steel, shed)
	for i in WS_POSTS.size() - 1:  # knee braces from the front posts up to the eaves beam
		for side: float in [1.0, -1.0]:
			var z: float = (WS_POSTS[i] + 0.42) if side > 0 else (WS_POSTS[i + 1] - 0.42)
			block(Vector3(0.07, 0.9, 0.07), Vector3(x1 - 0.1, WS_FRONT_H - 0.62, z), steel, shed, Basis(Vector3.RIGHT, deg_to_rad(-42.0) * side))
	for i in 4:  # purlins under the sheets
		var x := x0 + 0.5 + i * (x1 - x0 - 1.0) / 3.0
		block(Vector3(0.06, 0.08, WS.size.y + 0.3), Vector3(x, roof_y.call(x) - 0.03, WS.get_center().y), steel, shed)
	# The roof: sheets laid down the slope side by side, overhanging all round.
	var back := Vector3(x0 - 0.35, roof_y.call(x0 - 0.35) + 0.02, 0)
	var front := Vector3(x1 + 0.6, roof_y.call(x1 + 0.6) + 0.02, 0)
	var down := (front - back).normalized()
	var roof := Node3D.new()
	roof.name = "Roof"
	add(roof, shed)
	var z := WS.position.y - 0.45
	while z < WS.end.y + 0.45:
		var b := Basis(Vector3.BACK, down, Vector3.BACK.cross(down)).rotated(down, rng.randf_range(-0.01, 0.01))
		_sheet(roof, b, back + Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * 0.012, z), (front - back).length() + rng.randf_range(-0.06, 0.06), rng, true)
		z += SHEET_PITCH
	collide(Vector3((front - back).length(), 0.05, WS.size.y + 0.9), (back + front) * 0.5 + Vector3(0, 0, WS.get_center().y), shed, Basis(Vector3.BACK, atan2(down.y, down.x)))
	overhead(roof)
	# Walls: sheets standing side by side, their feet ragged off the concrete, tops under the roof.
	var walls := Node3D.new()
	walls.name = "Walls"
	add(walls, shed)
	z = WS.position.y
	while z < WS.end.y - 0.05:
		var foot := Vector3(x0 - 0.03, rng.randf_range(0.02, 0.09), z)
		var b := Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT).rotated(Vector3.UP, rng.randf_range(-0.015, 0.015))
		_sheet(walls, b, foot + Vector3(-0.025 * (int(z / SHEET_PITCH) % 2), 0, 0), WS_BACK_H - foot.y, rng)
		z += SHEET_PITCH
	collide(Vector3(0.2, WS_BACK_H, WS.size.y), Vector3(x0 - 0.1, WS_BACK_H * 0.5, WS.get_center().y), shed)
	for side: float in [-1.0, 1.0]:
		var wz := (WS.position.y - 0.03) if side < 0 else (WS.end.y + 0.03)
		var x := x0
		var i := 0
		while x < x1 - 0.05:
			var foot := Vector3(x, rng.randf_range(0.02, 0.09), wz - side * 0.025 * (i % 2))
			var top: float = roof_y.call(minf(x + SHEET_PITCH, x1)) - 0.02
			var b := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK).rotated(Vector3.UP, rng.randf_range(-0.015, 0.015))
			_sheet(walls, b, foot, top - foot.y, rng)
			x += SHEET_PITCH
			i += 1
		var h: float = roof_y.call((x0 + x1) * 0.5)
		collide(Vector3(WS.size.x, h, 0.2), Vector3((x0 + x1) * 0.5, h * 0.5, wz + side * 0.08), shed)
	# A rusted steel sill along the walls' feet (2026-11-03, the PS1 critic: at 270p the ragged sheet
	# feet read as a sawtooth band of light): the sheets stand in it, nothing shows under them.
	block(Vector3(0.12, 0.16, WS.size.y + 0.1), Vector3(x0 - 0.04, 0.08, WS.get_center().y), steel, shed)
	for side: float in [-1.0, 1.0]:
		var wz := (WS.position.y - 0.04) if side < 0 else (WS.end.y + 0.04)
		block(Vector3(WS.size.x + 0.1, 0.16, 0.12), Vector3((x0 + x1) * 0.5, 0.08, wz), steel, shed)


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
	# The pistol on an army crate in front of the spawns (scripts/gun_table.gd; the user took the
	# office desk out, 2026-11-02): taken, the crate fades away.
	var desk := _prop(root, MODELS + "wooden_military_crate/wooden_military_crate_1k.gltf", DESK_AT, PI / 2.0, 1.65)  # its lid at desk height
	desk.name = "GunTable"
	desk.set_script(preload("res://scripts/gun_table.gd"))
	# Along the walls.
	_prop(root, MODELS + "steel_frame_shelves_01/steel_frame_shelves_01_1k.gltf", Vector3(2.45, 0, 3.9), PI / 2.0, 0.1)  # the scan is 10x too big
	_prop(root, MODELS + "metal_tool_chest/metal_tool_chest_1k.gltf", Vector3(3.0, 0, -4.0), 0.0)
	_prop(root, MODELS + "tool_cart/tool_cart_1k.gltf", Vector3(4.6, 0, -2.9), 0.4)
	_prop(root, MODELS + "portable_generator/portable_generator_1k.gltf", Vector3(5.4, 0, 4.0), 0.2)
	_prop(root, MODELS + "metal_jerrycan/metal_jerrycan_1k.gltf", Vector3(6.2, 0, 4.1), 0.5)
	_prop(root, MODELS + "wooden_military_crate/wooden_military_crate_1k.gltf", Vector3(10.8, 0, 5.2), 0.1)
	_prop(root, MODELS + "wooden_crate_01/wooden_crate_01_1k.gltf", Vector3(10.8, 0.465, 5.25), 0.25)
	_prop(root, MODELS + "small_lpg_tank/small_lpg_tank_1k.gltf", Vector3(2.5, 0, -3.1), 0.0)
	# Light under the roof: caged work lamps off the purlins (2026-11-02, the user: change the
	# ceiling lamps); ambience.gd hums near the "Lamps".
	var lamps := Node3D.new()
	lamps.name = "Lamps"
	add(lamps)
	for at: Vector3 in [Vector3(4.3, 0, -2.3), Vector3(4.3, 0, 2.3), Vector3(7.2, 0, 0.0)]:
		_cage_lamp(lamps, at)
	# A fire in the burn barrel in front of the workshop, where the crew stands at night.
	var stove: StaticBody3D = _prop(root, "res://assets/props/burn_barrel/burn_barrel.glb", Vector3(12.0, 0, -4.2), 0.4)
	var burning := Node3D.new()
	burning.name = "BarrelFire"
	burning.set_script(preload("res://scripts/barrel_fire.gd"))
	burning.set("rim", 0.914)
	burning.set("inner", 0.29)
	burning.set("bed", 0.545)
	burning.set("logs", false)
	add(burning, stove)
	_prop(root, MODELS + "old_tyre/old_tyre_1k.gltf", Vector3(13.0, 0.12, -3.5), 0.0, 1.0, Basis(Vector3.RIGHT, PI / 2.0))


## A caged work lamp hanging off the roof at (x, z): the cage and its bulb are Poly Haven's
## caged_hanging_light; a warm spot down through the cage, a soft fill round the bulb.
func _cage_lamp(parent: Node, at: Vector3) -> void:
	var inst: Node3D = (load(_ps1(MODELS + "caged_hanging_light/caged_hanging_light_1k.gltf")) as PackedScene).instantiate()
	var box := _aabb(inst, Transform3D())
	var roof := WS_BACK_H + (at.x - WS.position.x) / WS.size.x * (WS_FRONT_H - WS_BACK_H) - 0.06
	var lamp := Node3D.new()
	lamp.name = "CageLamp"
	lamp.position = Vector3(at.x, roof - box.end.y, at.z)
	add(lamp, parent)
	add(inst, lamp)
	_own(inst)
	var bulb_y := box.position.y + box.size.y * 0.3
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, bulb_y, 0)
	spot.basis = Basis.looking_at(Vector3.DOWN, Vector3.FORWARD)
	spot.light_color = Color(1.0, 0.72, 0.42)
	spot.light_energy = 3.2  # a wide warm pool on the floor, not a small spot (2026-11-03, the PS1 critic)
	spot.spot_range = 7.0
	spot.spot_angle = 80.0
	spot.spot_angle_attenuation = 0.9
	spot.shadow_enabled = at.z == 0.0  # one shadow caster is enough under a roof this small
	spot.light_volumetric_fog_energy = 0.5
	add(spot, lamp)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, bulb_y, 0)
	fill.light_color = Color(1.0, 0.7, 0.4)
	fill.light_energy = 0.8
	fill.omni_range = 3.5
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
