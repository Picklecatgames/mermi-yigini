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

const WORLD := Rect2(-100.0, -80.0, 220.0, 160.0)  # x, z: everything the players can see the ground of (2026-11-02, the user: smaller, the zombies' ground was needlessly big)
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
	env.ambient_light_energy = 0.75  # overcast, but corners and the shade under trees stay dark
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
	env.fog_light_color = Color(0.66, 0.56, 0.42)  # warm sandy dust, yellower than the sky
	env.fog_density = 1.0  # depth fog: all the way to the colour at fog_depth_end
	env.fog_depth_begin = 12.0
	env.fog_depth_end = 75.0
	env.fog_depth_curve = 0.6  # under 1 it thickens early: half way in at ~35 m
	env.fog_sky_affect = 0.6  # the sky goes dusty too, the horizon one with the ground
	env.fog_aerial_perspective = 0.0  # its colour from the dust, not the sky
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.75
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ANGLE
	sun.light_color = Color(0.96, 0.89, 0.78)
	sun.light_energy = 1.15  # through the overcast; a little over the ambient, so the shadows read
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
	return h


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
	for slot in [["sand", "gravelly_sand"], ["earth", "mud_cracked_dry_03"], ["gravel", "sandy_gravel_02"]]:
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
	mat.set_shader_parameter("pad", Vector4(PAD.position.x, PAD.position.y, PAD.end.x, PAD.end.y))
	mat.set_shader_parameter("sand_tint", Color(1.0, 0.94, 0.86))
	mat.set_shader_parameter("earth_tint", Color(0.95, 0.86, 0.76))
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


## Out on the sand (Poly Haven's Namaqualand set, CC0): quiver trees and thorn trees in loose
## clumps, so it reads as a thinned-out dry wood; low bushes everywhere; boulders, more and bigger
## up the edge hills; stones and dead branches near the pad; a wrecked car, tyres and drums.
func _wasteland() -> void:
	var root := Node3D.new()
	root.name = "Wasteland"
	add(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	# `in_yard`: it may lie in the back yard too (junk, bushes), not only out on the sand; never on
	# the scrap heap or the giant heaps.
	var spots := func(count: int, near: float, far: float, in_yard := false) -> Array[Vector3]:
		var out: Array[Vector3] = []
		while out.size() < count:
			var p := Vector2(rng.randf_range(WORLD.position.x + 8.0, WORLD.end.x - 8.0), rng.randf_range(WORLD.position.y + 8.0, WORLD.end.y - 8.0))
			var away := Rect2(PAD.position - Vector2(near, near), PAD.size + Vector2(near, near) * 2.0)
			var too_far := Rect2(PAD.position - Vector2(far, far), PAD.size + Vector2(far, far) * 2.0)
			if away.has_point(p) or not too_far.has_point(p):
				continue
			if (not in_yard and YARD.has_point(p)) or HEAP_AREA.grow(3.0).has_point(p):
				continue
			out.append(Vector3(p.x, _ground_y(p.x, p.y, _desert_noise), p.y))
		return out
	var on_ground := func(p: Vector3) -> Vector3: return Vector3(p.x, _ground_y(p.x, p.z, _desert_noise) - 0.05, p.z)
	for centre: Vector3 in spots.call(8, 10.0, 34.0):
		for k in rng.randi_range(2, 5):
			var p: Vector3 = on_ground.call(centre + Vector3(rng.randf_range(-9.0, 9.0), 0, rng.randf_range(-9.0, 9.0)))
			if PAD.grow(3.0).has_point(Vector2(p.x, p.z)) or YARD.has_point(Vector2(p.x, p.z)):
				continue
			var r := rng.randf()
			if r < 0.4:
				_tree(root, "quiver_tree_01", p, rng.randf() * TAU, rng.randf_range(1.4, 2.4), 0.22)
			elif r < 0.6:
				_tree(root, "quiver_tree_02", p, rng.randf() * TAU, rng.randf_range(1.6, 2.6), 0.2)
			elif r < 0.85:
				_tree(root, "searsia_burchellii", p, rng.randf() * TAU, rng.randf_range(0.7, 1.1), 0.25)
			else:
				_tree(root, "dead_quiver_trunk", p, rng.randf() * TAU, rng.randf_range(1.5, 2.5), 0.2)
		for k in rng.randi_range(3, 6):  # bushes round the foot of each clump, never on the concrete
			var b: Vector3 = on_ground.call(centre + Vector3(rng.randf_range(-12.0, 12.0), 0, rng.randf_range(-12.0, 12.0)))
			if not PAD.grow(3.0).has_point(Vector2(b.x, b.z)):
				_plant(root, "wild_rooibos_bush", b, rng)
	for p: Vector3 in spots.call(60, 3.0, 120.0, true):
		_plant(root, "wild_rooibos_bush", p, rng)
	for p: Vector3 in spots.call(40, 3.0, 40.0, true):
		var clutter: String = ["dry_branches_medium_01", "namaqualand_stones_01", "namaqualand_rocks_01"][rng.randi() % 3]
		_plant(root, clutter, p, rng)
	for p: Vector3 in spots.call(45, 10.0, 120.0):
		var edge := minf(minf(p.x - WORLD.position.x, WORLD.end.x - p.x), minf(p.z - WORLD.position.y, WORLD.end.y - p.z))
		var big := 1.0 + 2.5 * (1.0 - clampf(edge / EDGE_REACH, 0.0, 1.0))
		var id: String = ["namaqualand_boulder_02", "namaqualand_boulder_04", "namaqualand_boulder_05"][rng.randi() % 3]
		_prop(root, NAMA + "%s/%s_1k.gltf" % [id, id], p - Vector3(0, 0.15 * big, 0), rng.randf() * TAU, big * rng.randf_range(0.8, 1.6))
	for p: Vector3 in spots.call(5, 6.0, 60.0):
		_prop(root, NAMA + "dead_tree_trunk_02/dead_tree_trunk_02_1k.gltf", p + Vector3(0, 0.12, 0), rng.randf() * TAU)
	for p: Vector3 in spots.call(3, 14.0, 60.0):
		_prop(root, MODELS + "covered_car/covered_car_1k.gltf", p, rng.randf() * TAU, 1.0, Basis(Vector3.FORWARD, rng.randf_range(-0.05, 0.05)))
	for p: Vector3 in spots.call(10, 3.0, 50.0, true):
		var junk: String = ["old_tyre/old_tyre_1k.gltf", "rusted_wheel_rim_01/rusted_wheel_rim_01_1k.gltf", "rusted_wheel_rim_02/rusted_wheel_rim_02_1k.gltf"][rng.randi() % 3]
		_prop(root, MODELS + junk, p, rng.randf() * TAU)


const NAMA := "res://assets/env/namaqualand/"


## A tree with a collision post round its trunk only (its canopy is walked under, not into). The
## Poly Haven scans are 80-600 K triangles: what stands here is a light copy (_lite).
func _tree(parent: Node, id: String, at: Vector3, yaw: float, s: float, trunk: float) -> void:
	var body := StaticBody3D.new()
	body.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	add(body, parent)
	var spec: Array = TREES[id]
	var mi := MeshInstance3D.new()
	mi.mesh = _lite(id, spec[0], spec[1])
	mi.visibility_range_end = 120.0
	add(mi, body)
	var far := MeshInstance3D.new()
	far.mesh = _lite(id, spec[0], spec[2])
	far.visibility_range_begin = 120.0
	far.visibility_range_end = 320.0
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(far, body)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = trunk
	cyl.height = 2.0
	cs.shape = cyl
	cs.position = Vector3(0, 1.0, 0)
	add(cs, body)


## id -> [mesh node in its glTF, triangles near, triangles far]
const TREES := {
	"quiver_tree_01": ["quiver_tree_01", 9000, 1500],
	"quiver_tree_02": ["quiver_tree_02", 7000, 1200],
	"searsia_burchellii": ["searsia_burchellii_large_LOD0", 16000, 2500],
	"searsia_medium": ["searsia_burchellii_medium_LOD0", 9000, 1500],
	"dead_quiver_trunk": ["dead_quiver_trunk_LOD0", 5000, 900],
}
var _lites := {}


## A light copy of a scan's mesh, about `tris` triangles: Godot's importer already made LODs for
## it (one index list per level over the same vertices); the level nearest `tris` becomes the
## mesh's own indices. Saved next to the glTF (`<node>_<tris>.res`) so the scene stays small.
func _lite(id: String, node_name: String, tris: int) -> Mesh:
	var key := "%s_%d" % [node_name, tris]
	if _lites.has(key):
		return _lites[key]
	var file := id if id != "searsia_medium" else "searsia_burchellii"
	# The PS1 copy (tools/psx_props.gd nature, 2026-11-03, the user: the trees are bad, PS1 ones):
	# a few hundred triangles, alpha-cut cards, small textures in the desert's colours. Near and far
	# are the one mesh then.
	var psx := NAMA + "%s/%s_1k_psx.scn" % [file, file]
	if ResourceLoader.exists(psx):
		var lowp: Node = (load(psx) as PackedScene).instantiate()
		_lites[key] = (lowp.find_child(node_name, true, false) as MeshInstance3D).mesh
		lowp.free()
		return _lites[key]
	var path := NAMA + "%s/%s.res" % [file, key]
	var scene: Node = (load(NAMA + "%s/%s_1k.gltf" % [file, file]) as PackedScene).instantiate()
	var src := (scene.find_child(node_name, true, false) as MeshInstance3D).mesh
	scene.free()
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arrays := src.surface_get_arrays(si)
		var full: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var share := float(tris) / float(src.get_surface_count())
		var best := full
		var surf: Dictionary = RenderingServer.mesh_get_surface(src.get_rid(), si)
		var wide := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 65535
		for lod: Dictionary in surf.get("lods", []):
			var bytes: PackedByteArray = lod["index_data"]
			var idx := bytes.to_int32_array() if wide else _u16(bytes)
			if absf(idx.size() / 3.0 - share) < absf(best.size() / 3.0 - share):
				best = idx
		arrays[Mesh.ARRAY_INDEX] = best
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, src.surface_get_material(si))
	ResourceSaver.save(out, path)
	_lites[key] = load(path)
	return _lites[key]


func _u16(bytes: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(bytes.size() / 2)
	for i in out.size():
		out[i] = bytes.decode_u16(i * 2)
	return out


## Where the dead come from (2026-11-02, the user: "the spawn ground is too open; they'll come from
## far off; cover it in trees so they come at us out of a wood, fit for a desert climate"): past
## FOREST_START from the pad a dry wood thickens to the world's edge, the kind that grows in such
## a desert: quiver trees (a kokerboom forest), thorn trees, dead trunks, bushes under them. Drawn
## as MultiMeshes in FOREST_CHUNK squares, a light copy near and a lighter one far; each trunk a
## collision post. Markers in group "forest_edge" round the wood's inner edge are where waves
## (scripts/waves.gd, the night session) can let the dead out of the trees.
## The clearing the wood stands round (the user's drawing, 2026-11-02): an oval, the workshop near
## its back, the scrap mountain closing it behind; the dead come out of the trees on the other sides.
const CLEARING_CENTRE := Vector2(8.0, 0.0)
const CLEARING_RADII := Vector2(62.0, 50.0)
const FOREST_START := 0.0  # m out from the clearing's edge: the first trees
const FOREST_FULL := 16.0  # m: as thick as it gets from here out
const FOREST_STEP := 3.6  # m between candidate spots
const FOREST_CHUNK := 40.0


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
	var kinds := [["quiver_tree_01", 0.24, Vector2(1.6, 2.8), 0.22], ["quiver_tree_02", 0.14, Vector2(1.8, 3.0), 0.2],
		["searsia_burchellii", 0.24, Vector2(0.8, 1.2), 0.25], ["searsia_medium", 0.24, Vector2(0.9, 1.3), 0.2],
		["dead_quiver_trunk", 0.14, Vector2(1.6, 2.8), 0.2]]
	var chunks := {}  # Vector2i -> kind -> Array[Transform3D]
	var x := WORLD.position.x + 4.0
	while x < WORLD.end.x - 2.0:
		var z := WORLD.position.y + 4.0
		while z < WORLD.end.y - 2.0:
			var p := Vector2(x + rng.randf_range(-1.6, 1.6), z + rng.randf_range(-1.6, 1.6))
			z += FOREST_STEP
			var away := _out_of_clearing(p) + _desert_noise.get_noise_2d(p.x * 2.0, p.y * 2.0) * 10.0
			var thick := smoothstep(FOREST_START, FOREST_FULL, away) * 0.92
			if rng.randf() > thick or YARD.grow(2.0).has_point(p):
				continue
			var r := rng.randf()
			var kind: Array = kinds[0]
			for k: Array in kinds:
				r -= k[1]
				kind = k
				if r <= 0.0:
					break
			var sc := rng.randf_range(kind[2].x, kind[2].y)
			var at := Vector3(p.x, _ground_y(p.x, p.y, _desert_noise) - 0.08, p.y)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), at)
			var key := Vector2i(floori(p.x / FOREST_CHUNK), floori(p.y / FOREST_CHUNK))
			if not chunks.has(key):
				chunks[key] = {}
			if not chunks[key].has(kind[0]):
				chunks[key][kind[0]] = []
			chunks[key][kind[0]].append(xf)
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = kind[3] * sc * 0.6
			cyl.height = 2.4
			cs.shape = cyl
			cs.position = at + Vector3(0, 1.2, 0)
			add(cs, trunks)
			# Bushes at the feet of the trees, the wood's undergrowth.
			if rng.randf() < 0.35:
				var b := at + Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))
				b.y = _ground_y(b.x, b.z, _desert_noise) - 0.04
				if not chunks[key].has("bush"):
					chunks[key]["bush"] = []
				chunks[key]["bush"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.5)), b))
		x += FOREST_STEP
	var count := 0
	var groups := []
	for key: Vector2i in chunks:
		for kind: String in chunks[key]:
			var xfs: Array = chunks[key][kind]
			count += xfs.size()
			var flat := PackedFloat32Array()
			for xf: Transform3D in xfs:
				flat.append_array([xf.basis.x.x, xf.basis.x.y, xf.basis.x.z, xf.basis.y.x, xf.basis.y.y, xf.basis.y.z,
					xf.basis.z.x, xf.basis.z.y, xf.basis.z.z, xf.origin.x, xf.origin.y, xf.origin.z])
			if kind == "bush":
				groups.append([_bush_mesh(), null, 80.0, 80.0, true, flat])
				continue
			var spec: Array = TREES[kind]
			groups.append([_lite(kind, spec[0], spec[1]), _lite(kind, spec[0], spec[2]), 90.0, 260.0, true, flat])
	root.set("groups", groups)
	print("forest: ", count, " trees and bushes in ", chunks.size(), " chunks")
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


## How far `p` (x, z) lies outside the clearing's oval, in metres (negative inside).
func _out_of_clearing(p: Vector2) -> float:
	var q := (p - CLEARING_CENTRE) / CLEARING_RADII
	return (q.length() - 1.0) * minf(CLEARING_RADII.x, CLEARING_RADII.y)


func _bush_mesh() -> Mesh:
	return _lite("wild_rooibos_bush", "wild_rooibos_bush_a", 1500)


## Something low with no collision: a bush, dry branches, a spill of stones.
func _plant(parent: Node, id: String, at: Vector3, rng: RandomNumberGenerator) -> void:
	var inst: Node3D = (load(_ps1(NAMA + "%s/%s_1k.gltf" % [id, id])) as PackedScene).instantiate()
	inst.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), at)
	add(inst, parent)
	_own(inst)


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
