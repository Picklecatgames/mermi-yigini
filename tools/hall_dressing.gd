extends RefCounted
## The hall's abandonment for tools/build_arena.gd (2026-10-22): years of an empty army range,
## then the digging crew's few months on top. Plan from the art-director and research reviews.
##   Decay: cracks along the slab joints,
##     dust drifts at the wall feet, pigeon droppings under the trusses, leaks and moss down the
##     walls, a few old tags near the doors.
##   Light, one meaning per colour: cold night light through the glass roof (abandoned), sodium tripods
##     and factory pendants on the crew's generator (alive), the army's red caged emergency lamps still lit on their
##     battery, green exit signs.
##   The crew: a camp in the north-west corner (container office, desk, stove, generator), their
##     covered car by the jammed loading door in the south wall, cables back to the generator.
##     The belt band east of the heap (x -3..14) and the placement zones stay clear on the floor;
##     what hangs overhead goes on the overhead layer.

const MODELS := "res://assets/env/models/"
const DECALS := "res://materials/env/decals/"
const ACG := "res://assets/env/decals/"
const SODIUM := Color(1.0, 0.6, 0.3)
const RED := Color(0.72, 0.08, 0.06)  # spray paint
const WHITE := Color(0.88, 0.86, 0.8)
const BLACK := Color(0.06, 0.06, 0.065)
const ACID := Color(0.72, 0.85, 0.1)
const DOOR_X := -6.0  # the loading door's centre in the south wall (build_arena _walls skips that panel)
const GENERATOR := Vector3(-16.6, 0, -26.9)

var b  # the arena builder (tools/build_arena.gd)
var root: Node3D
var rng := RandomNumberGenerator.new()
var cord: StandardMaterial3D
var steel: Material
var dark: Material


func _init(builder) -> void:
	b = builder


func build() -> void:
	rng.seed = 2210
	root = Node3D.new()
	root.name = "Abandon"
	b.add(root)
	cord = _flat(Color(0.03, 0.03, 0.03), 0.6)
	cord.cull_mode = BaseMaterial3D.CULL_DISABLED
	steel = load("res://materials/env/scrap_steel.tres")
	dark = _flat(Color(0.05, 0.05, 0.055), 0.7)
	_floor_decay()
	_wall_decay()
	_loading_door()
	_leftovers()
	_camp()
	_heap_lights()
	_beacons()
	_overhead()
	_range_wear()
	_crew_work()


# --- floor --------------------------------------------------------------------------------------

func _floor_decay() -> void:
	var fl: float = b.GS.FIRING_LINE_X
	# Cracks: they run out from the slab joints, more near the walls and the door.
	var cracks: Array[Texture2D] = []
	for k in 3:
		cracks.append(_crack_tex(k))
	var placed := 0
	while placed < 26:
		var p := Vector3(roundf(rng.randf_range(-26, 12) / 4.0) * 4.0, 0, rng.randf_range(-26, 26))
		if rng.randf() < 0.5:
			p = Vector3(rng.randf_range(-26, 12), 0, roundf(rng.randf_range(-26, 26) / 4.0) * 4.0)
		if p.distance_to(b.HEAP) < 10.0 or p.x > fl - 1.0:
			continue
		var s := rng.randf_range(1.5, 3.4)
		var d: Decal = b._decal(root, cracks[placed % 3], p, rng.randf() * TAU, Vector3(s, 0.5, s))
		d.modulate = Color(1, 1, 1, rng.randf_range(0.6, 1.0))
		placed += 1
	# Dust and grit blown into drifts along every wall foot.
	var drift := _drift_tex()
	for side in 4:
		var yaw := side * PI / 2.0
		var basis := Basis(Vector3.UP, yaw)
		for k in 7:
			var along := -24.0 + k * 8.0 + rng.randf_range(-1.0, 1.0)
			var at := basis * Vector3(along, 0, 27.2)
			if at.x > fl - 0.5:
				continue  # the range keeps its rubber clean
			var d: Decal = b._decal(root, drift, at, yaw, Vector3(rng.randf_range(7.0, 10.0), 0.6, rng.randf_range(1.6, 2.6)))
			d.modulate = Color(1, 1, 1, rng.randf_range(0.55, 0.9))
	# Pigeons roost on the bottom chords: droppings in lines under them.
	var droppings := _droppings_tex()
	for z: float in b.BAYS.slice(1, b.BAYS.size() - 1):
		var x := -25.0
		while x < fl - 2.0:
			if Vector2(x - b.HEAP.x, z - b.HEAP.z).length() > 9.5 and rng.randf() < 0.6:
				var d: Decal = b._decal(root, droppings, Vector3(x, 0, z + rng.randf_range(-0.3, 0.3)), rng.randf_range(-0.1, 0.1), Vector3(rng.randf_range(2.0, 4.0), 0.5, 0.9))
				d.modulate = Color(1, 1, 1, rng.randf_range(0.5, 0.9))
			x += rng.randf_range(2.5, 5.0)
	# Tyre tracks in the dust: the crew's car from the loading door to where it stands.
	var tread := _tread_tex()
	var path := [Vector2(DOOR_X, 29.0), Vector2(DOOR_X - 1.0, 25.5), Vector2(DOOR_X - 4.5, 23.4), Vector2(DOOR_X - 9.0, 23.6), Vector2(-17.6, 24.5)]
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var c: Vector2 = path[i + 1]
		var mid := (a + c) / 2.0
		var d: Decal = b._decal(root, tread, Vector3(mid.x, 0, mid.y), atan2(c.x - a.x, c.y - a.y), Vector3(1.9, 0.5, a.distance_to(c) + 0.6))
		d.modulate = Color(1, 1, 1, 0.75)


func _crack_tex(k: int) -> Texture2D:
	return b._decal_tex("crack_%d" % k, 1024, 1024, func(img: Image) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 90 + k
		img.fill(Color(0, 0, 0, 0))
		# A random walk from the middle, splitting now and then: a branching hairline network.
		var tips: Array = [[Vector2(512, 512), r.randf() * TAU, 3.4], [Vector2(512, 512), r.randf() * TAU, 3.0]]
		var steps := 0
		while not tips.is_empty() and steps < 400:
			steps += 1
			var t: Array = tips.pop_back()
			var p: Vector2 = t[0]
			var ang: float = t[1]
			var w: float = t[2]
			for s in r.randi_range(40, 120):
				ang += r.randf_range(-0.35, 0.35)
				p += Vector2(cos(ang), sin(ang)) * 2.0
				if p.x < 8 or p.y < 8 or p.x > 1015 or p.y > 1015:
					break
				var rad := maxf(w, 0.6)
				for oy in range(-3, 4):
					for ox in range(-3, 4):
						var dd := Vector2(ox, oy).length()
						if dd <= rad + 0.5:
							var q := Vector2i(int(p.x) + ox, int(p.y) + oy)
							var a := clampf(rad + 0.5 - dd, 0.0, 1.0) * 0.9
							img.set_pixelv(q, Color(0.03, 0.028, 0.025, maxf(img.get_pixelv(q).a, a)))
				w *= 0.995
			if w > 0.7 and tips.size() < 12:
				tips.append([p, ang + r.randf_range(0.4, 1.0), w * 0.8])
				tips.append([p, ang - r.randf_range(0.4, 1.0), w * 0.7]))


func _drift_tex() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 44
	noise.frequency = 0.02
	noise.fractal_octaves = 5
	return b._decal_tex("dust_drift", 512, 128, func(img: Image) -> void:
		for y in 128:
			for x in 512:
				var depth := pow(y / 127.0, 1.6)  # y 127 is the wall side
				var ends := smoothstep(0.0, 90.0, minf(x, 511 - x))
				var a := clampf(depth * (0.7 + 0.6 * noise.get_noise_2d(x, y * 2.0)), 0.0, 1.0) * ends
				img.set_pixel(x, y, Color(0.42, 0.38, 0.32, a * 0.75)))


func _droppings_tex() -> Texture2D:
	return b._decal_tex("droppings", 512, 128, func(img: Image) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 8
		img.fill(Color(0, 0, 0, 0))
		for i in 260:
			var c := Vector2i(int(r.randf_range(10, 502)), int(clampf(64 + r.randfn(0.0, 16.0), 8, 119)))
			var rad := r.randf_range(1.0, 4.5)
			var white := Color(0.62, 0.61, 0.57) if r.randf() < 0.6 else Color(0.22, 0.21, 0.19)
			for oy in range(-5, 6):
				for ox in range(-5, 6):
					var dd := Vector2(ox, oy).length()
					if dd < rad:
						img.set_pixelv(c + Vector2i(ox, oy), Color(white, 0.55 * (1.0 - dd / rad * 0.5))))


func _tread_tex() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 61
	noise.frequency = 0.05
	return b._decal_tex("tyre_tracks", 128, 512, func(img: Image) -> void:
		for y in 512:
			for x in 128:
				var a := 0.0
				for c in [22.0, 106.0]:  # two wheels
					var dx := absf(x - c)
					if dx < 12.0:
						a = (0.55 if fposmod(y + (x - c) * 0.5, 9.0) < 5.0 else 0.25) * smoothstep(12.0, 8.0, dx)
				a *= clampf(0.6 + noise.get_noise_2d(x, y), 0.0, 1.0)
				img.set_pixel(x, y, Color(0.06, 0.055, 0.05, a)))


# --- walls --------------------------------------------------------------------------------------

## A decal flat on the inside of wall `side` (0 south, 1 east, 2 north, 3 west), `along` it.
func _on_wall(tex: Texture2D, side: int, along: float, y: float, size: Vector2) -> Decal:
	var basis := Basis(Vector3.UP, side * PI / 2.0)
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(size.x, 0.5, size.y)
	# Turned half round its own +Y as well: texture row 0 at the top, not mirrored.
	d.transform = Transform3D(basis * Basis(Vector3.RIGHT, -PI / 2) * Basis(Vector3.UP, PI), basis * Vector3(along, 0, 28.0) + Vector3(0, y, 0))
	d.cull_mask = 1
	b.add(d, root)
	return d


## A decal on any wall face at `at` looking along `out`, texture top up.
func _on_face(tex: Texture2D, at: Vector3, out: Vector3, size: Vector2) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(size.x, 0.3, size.y)
	d.transform = Transform3D(Basis(out.cross(Vector3.UP), out, Vector3.DOWN), at)
	d.cull_mask = 1
	b.add(d, root)
	return d


func _wall_decay() -> void:
	var leaks: Array[Texture2D] = [_acg("Leaking004"), _acg("Leaking005")]
	# Under the eaves water has run down the panels for years: long wet streaks, moss at their feet.
	var moss := _moss_tex()
	for side in 4:
		for k in 9:
			if rng.randf() < 0.35:
				continue
			var along := -24.0 + k * 6.0 + rng.randf_range(-1.5, 1.5)
			if side == 1 and absf(along) < b.BAY_HALF + 1.5:
				continue
			var h := rng.randf_range(2.6, 3.9)
			var d := _on_wall(leaks[rng.randi() % 2], side, along, 4.0 - h / 2.0, Vector2(rng.randf_range(1.2, 2.6), h))
			d.modulate = Color(0.55, 0.55, 0.5, rng.randf_range(0.6, 1.0))
			if rng.randf() < 0.6:
				var m := _on_wall(moss, side, along + rng.randf_range(-0.4, 0.4), 0.35, Vector2(rng.randf_range(1.4, 2.8), 0.8))
				m.modulate = Color(1, 1, 1, rng.randf_range(0.6, 1.0))
	# Sprayed slogans from the years it stood empty, at arm's height, clear of the columns (every 7 m).
	# [side, along, y, height m, image, colour]
	for t in [[0, DOOR_X - 4.5, 1.9, 1.2, "86", RED], [0, DOOR_X + 3.4, 1.6, 1.1, "16", RED],
			[0, -17.5, 1.8, 1.3, "07", WHITE], [0, 1.9, 1.45, 0.45, "83", BLACK],
			[2, -10.5, 1.7, 1.3, "57", WHITE], [2, 2.0, 1.8, 0.8, "36", RED], [2, 9.5, 1.9, 0.9, "30", RED],
			[3, -10.5, 1.7, 1.0, "66", RED], [3, -3.5, 2.1, 2.0, "53", WHITE], [3, 3.5, 1.7, 1.0, "78", WHITE],
			[3, 10.5, 1.6, 0.9, "85", ACID], [3, 18.5, 1.6, 1.2, "80", WHITE]]:
		var tex := _spray(t[4], t[5])
		_on_wall(tex, t[0], t[1], t[2], Vector2(t[3] * tex.get_width() / tex.get_height(), t[3]))


## An ambientCG decal: its colour map with the opacity map as alpha, saved once.
func _acg(id: String) -> Texture2D:
	var path := DECALS + "acg_%s.res" % id
	if ResourceLoader.exists(path):
		return load(path)
	var col := Image.load_from_file(ProjectSettings.globalize_path(ACG + "%s/%s_2K-JPG_Color.jpg" % [id, id]))
	var op := Image.load_from_file(ProjectSettings.globalize_path(ACG + "%s/%s_2K-JPG_Opacity.jpg" % [id, id]))
	col.resize(col.get_width() / 2, col.get_height() / 2)
	op.resize(col.get_width(), col.get_height())
	col.convert(Image.FORMAT_RGBA8)
	for y in col.get_height():
		for x in col.get_width():
			var c := col.get_pixel(x, y)
			c.a = op.get_pixel(x, y).r
			col.set_pixel(x, y, c)
	return _save_tex(col, path)


## A real sprayed wall slogan (OpenGameArt "Russian graffiti, labels and tags vol 1", CC0; white
## on clear) in spray colour `colour`, saved once.
func _spray(id: String, colour: Color) -> Texture2D:
	var path := DECALS + "spray_%s.res" % id
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(ACG + "RussianGraffiti/img_%s.png" % id))
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, Color(colour, img.get_pixel(x, y).a * 0.9))
	return _save_tex(img, path)


func _moss_tex() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 71
	noise.frequency = 0.03
	noise.fractal_octaves = 5
	return b._decal_tex("wall_moss", 512, 128, func(img: Image) -> void:
		for y in 128:
			for x in 512:
				var foot := pow(y / 127.0, 1.3)
				var ends := smoothstep(0.0, 120.0, minf(x, 511 - x))
				var n := noise.get_noise_2d(x, y)
				var a := clampf((foot + n * 0.7) * 1.4 - 0.3, 0.0, 1.0) * ends
				var c := Color(0.12, 0.16, 0.06).lerp(Color(0.05, 0.06, 0.04), clampf(n + 0.5, 0.0, 1.0))
				img.set_pixel(x, y, Color(c, a * 0.85)))


func _save_tex(img: Image, path: String) -> Texture2D:
	DirAccess.make_dir_recursive_absolute(DECALS)
	img.generate_mipmaps()
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	var tex := PortableCompressedTexture2D.new()
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	ResourceSaver.save(tex, path)
	return load(path)


# --- doors --------------------------------------------------------------------------------------

## The loading door in the south wall: a roller shutter run down for good, only lines of daylight
## through its sprung slats and under its warped bottom edge (2026-10-22: open, with the bright
## yard behind, it said "crawl out here"). The wall's collision runs across it anyway.
func _loading_door() -> void:
	var z := 28.15
	var paint: Material = b.worn("metal_plate_02", "shutter_paint", {"tint": Color(0.55, 0.62, 0.66), "tex_size": 1.2,
		"cell_size": 4.0, "grime": 0.6, "grime_scale": 0.5, "rust": 0.7})
	var frame: Material = load("res://materials/env/range_steel_dark.tres")
	for s in [-1.0, 1.0]:  # side guides
		b.block(Vector3(0.16, 4.0, 0.36), Vector3(DOOR_X + s * 2.0, 2.0, z), frame, root)
	b.block(Vector3(4.3, 0.55, 0.6), Vector3(DOOR_X, 3.78, z - 0.1), frame, root)  # the roll box
	# Slats down to a crooked bottom edge: one guide broke, the left side dropped lower.
	const LEFT := 0.03
	const RIGHT := 0.14
	var tilt := atan2(RIGHT - LEFT, 3.85)
	var y := 3.45
	var k := 0
	while y > (LEFT + RIGHT) / 2.0 + 0.05:
		var bend := clampf((1.2 - y) / 1.0, 0.0, 1.0)  # straight high up, crooked near the bottom
		var gap := 0.0  # slits shimmered like scan lines: the light comes in under the edge only
		var slat: MeshInstance3D = b.block(Vector3(3.85, 0.106 - gap, 0.04), Vector3(DOOR_X, y, z + 0.02), paint, root, Basis(Vector3.BACK, -tilt * bend))
		k += 1
		slat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		y -= 0.1
	b.block(Vector3(3.9, 0.05, 0.07), Vector3(DOOR_X, (LEFT + RIGHT) / 2.0, z + 0.02), frame, root, Basis(Vector3.BACK, -tilt))
	# The night outside, seen only through the slits: a dim blue plane right behind the shutter.
	var day := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4.2, 4.0)
	day.mesh = q
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0.06, 0.08, 0.14)
	day.material_override = dm
	day.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	day.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	day.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(DOOR_X, 2.0, z + 0.35))
	b.add(day, root)
	var spill := SpotLight3D.new()  # the bright yard throws light in under the door
	spill.transform = Transform3D(Basis.looking_at(Vector3(0, -0.05, -1)), Vector3(DOOR_X, 0.1, z + 1.2))
	spill.light_color = Color(1.0, 0.96, 0.9)
	spill.light_energy = 3.0
	spill.spot_range = 16.0
	spill.spot_angle = 60.0
	spill.spot_angle_attenuation = 1.2
	spill.light_volumetric_fog_energy = 0.6
	spill.shadow_enabled = true
	b.add(spill, root)
	var d: Decal = b._decal(root, _drift_tex(), Vector3(DOOR_X, 0, z - 1.2), PI, Vector3(5.5, 0.6, 2.8))
	d.modulate = Color(1, 1, 1, 0.95)  # grit blown in under it


## Where the hall's two side doors were planned: the army's leftovers instead. North a steel rack
## that gave way, its crates spilled; west a stack of old target boards leaning on the wall.
func _leftovers() -> void:
	var rack: String = MODELS + "worn_metal_rack/worn_metal_rack_1k.gltf"
	b._prop(root, rack, Vector3(-12.6, 0, -27.55), 0.05)
	b._prop(root, rack, Vector3(-11.1, 0.05, -26.9), 0.35, 1.0, Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.FORWARD, 0.12))  # collapsed onto it
	var mil: String = MODELS + "old_military_crate/old_military_crate_1k.gltf"
	var ammo: String = MODELS + "ammo_box/ammo_box_1k.gltf"
	b._prop(root, mil, Vector3(-10.4, 0, -26.2), 0.6)
	b._prop(root, mil, Vector3(-9.7, 0.12, -26.6), 2.1, 1.0, Basis(Vector3.FORWARD, 0.4))
	for p in [Vector3(-11.6, 0, -25.9), Vector3(-10.9, 0, -25.5), Vector3(-12.2, 0, -26.4)]:
		b._prop(root, ammo, p, rng.randf() * TAU)
	b._prop(root, MODELS + "old_gas_mask/old_gas_mask_1k.gltf", Vector3(-11.3, 0, -25.2), 1.2)
	# Target boards: plywood frames with old paper targets, slid down the wall one on another.
	var ply: Material = load("res://materials/env/plywood_1.tres")
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = load(DECALS + "poster_target.res")
	paper.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	paper.roughness = 0.9
	for k in 5:
		var lean := 0.16 + k * 0.05
		var z := 20.0 + k * 0.32 + rng.randf_range(-0.05, 0.05)
		var face := Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, -lean)  # front looks east, top on the wall
		var at := Vector3(-28.0 + 0.62 * sin(lean) + 0.05 + k * 0.035, 0.6 * cos(lean), z)
		b.block(Vector3(0.9, 1.2, 0.018), at, ply, root, face)
		b.add(_mesh(_quad_mesh(Vector2(0.62, 0.85)), paper, Transform3D(face, at + face * Vector3(0, 0.05, 0.011))), root)
	var body := StaticBody3D.new()
	b.add(body, root)
	b.collide(Vector3(0.6, 1.2, 1.7), Vector3(-27.6, 0.6, 20.7), body)


func _quad_mesh(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	return q


# --- the crew's camp ----------------------------------------------------------------------------

func _camp() -> void:
	var m := func(n: String) -> String: return MODELS + n + "/" + n + "_1k.gltf"
	# A 20 ft container against the north wall in the corner: the site office.
	var box: Material = b.pbr_box("container_side", 2.4, Color(0.82, 0.86, 0.84), false, "container")
	var cont := StaticBody3D.new()
	b.add(cont, root)
	var c_at := Vector3(-23.6, 0, -26.55)
	b.block(Vector3(6.06, 2.59, 2.44), c_at + Vector3(0, 1.295, 0), box, cont)
	b.collide(Vector3(6.06, 2.59, 2.44), c_at + Vector3(0, 1.295, 0), cont)
	b.block(Vector3(0.04, 2.3, 2.2), c_at + Vector3(3.04, 1.25, 0), steel, cont)  # its doors' end
	# The desk outside it with the radio and the paperwork, chairs round the stove.
	var desk := Vector3(-22.4, 0, -23.7)
	b._prop(root, m.call("metal_office_desk"), desk, PI + 0.06)
	b._prop(root, m.call("vintage_radio_transceiver"), desk + Vector3(-0.5, 0.79, 0.05), PI + 0.2)
	b._prop(root, m.call("classic_laptop"), desk + Vector3(0.35, 0.79, 0.1), PI - 0.3)
	b._prop(root, MODELS + "clipboard/clipboard_1k.gltf", desk + Vector3(0.8, 0.8, -0.1), 0.5)
	b._prop(root, MODELS + "binoculars/binoculars_1k.gltf", desk + Vector3(-0.05, 0.8, -0.25), 1.1)
	var chair: String = m.call("plastic_monobloc_chair_01")
	b._prop(root, chair, desk + Vector3(0.2, 0, 0.95), 0.25)
	b._prop(root, chair, Vector3(-19.3, 0, -23.0), 2.3)
	b._prop(root, chair, Vector3(-18.0, 0.32, -24.6), -1.6, 1.0, Basis(Vector3.FORWARD, PI / 2))  # knocked over
	b._prop(root, m.call("barrel_stove"), Vector3(-18.9, 0, -24.3), 0.0)
	b._prop(root, m.call("small_lpg_tank"), Vector3(-27.3, 0, -23.4), 0.0)
	b._prop(root, m.call("tool_cart"), Vector3(-26.9, 0, -21.3), PI / 2)
	b._prop(root, m.call("metal_toolbox"), Vector3(-26.9, 0.96, -21.0), PI / 2 + 0.3)
	var bag: String = m.call("trashbag")
	for p in [Vector3(-27.5, 0, -19.9), Vector3(-27.2, 0, -19.4), Vector3(-27.55, 0, -19.1)]:
		b._prop(root, bag, p, rng.randf() * TAU)
	b._prop(root, m.call("wooden_ladder"), Vector3(-20.0, 0, -27.6), 0.0, 1.6, Basis(Vector3.RIGHT, -0.3))
	b._prop(root, m.call("hand_truck"), Vector3(-14.6, 0, -27.5), 0.2)
	# The generator on a pallet, cans by it, a power box on the wall, the amber "running" lamp.
	_pallet(GENERATOR + Vector3(0, 0, 0.1), 0.0)
	b._prop(root, MODELS + "portable_generator/portable_generator_1k.gltf", GENERATOR + Vector3(0, 0.14, 0.1), 0.15)
	var can: String = m.call("plastic_jerrycan")
	for p in [Vector3(-15.4, 0, -27.5), Vector3(-15.05, 0, -27.55), Vector3(-15.25, 0, -27.1)]:
		b._prop(root, can, p, rng.randf_range(-0.4, 0.4))
	b._prop(root, MODELS + "metal_jerrycan_green/metal_jerrycan_green_1k.gltf", Vector3(-17.9, 0, -27.5), 0.2)
	b._prop(root, m.call("power_box_01"), Vector3(-17.0, 1.5, -27.93), 0.0)
	_lamp(Vector3(-17.0, 2.35, -27.95), Vector3(0, 0, 1), Color(1.0, 0.55, 0.12), 1.4)  # amber: the generator is on
	# Crates of sorted brass the crew stacked on pallets along the west wall.
	var crate: String = MODELS + "wooden_military_crate/wooden_military_crate_1k.gltf"
	var ammo: String = MODELS + "ammo_box/ammo_box_1k.gltf"
	for at in [Vector3(-27.0, 0, -16.8), Vector3(-27.0, 0, 13.6)]:
		_pallet(at, PI / 2)
		for k in 3:
			b._prop(root, crate, at + Vector3(0.0, 0.14 + 0.465 * (k / 2), -0.3 + 0.6 * (k % 2)), PI / 2 + rng.randf_range(-0.06, 0.06))
		b._prop(root, ammo, at + Vector3(0.1, 0.605, 0.25), rng.randf() * TAU)
	# The covered car they came in, by the loading door.
	b._prop(root, m.call("covered_car"), Vector3(-17.6, 0, 24.6), PI / 2 + 0.08)
	b._prop(root, MODELS + "rusted_spade_01/rusted_spade_01_1k.gltf", Vector3(-14.9, 0.5, 27.8), 0.0, 1.0, Basis(Vector3.RIGHT, -0.25))
	# Light: factory pendants on a strut over the desk and the stove, and one sodium tripod.
	b.strut(-22.4, -27.85, -21.0)
	b.strut(-18.8, -27.85, -21.0)
	b.pendant(Vector3(-22.4, 4.4, -23.1), b.BOTTOM - b.CHORD / 2.0 - 0.065, Color(1.0, 0.68, 0.38), 6.0, 50.0, 0.0, true)
	b.pendant(Vector3(-18.8, 4.6, -24.0), b.BOTTOM - b.CHORD / 2.0 - 0.065, Color(1.0, 0.68, 0.38), 6.0, 50.0, 0.0, true)
	_tripod(Vector3(-25.8, 0, -19.8), Vector3(-20.5, 0.2, -24.0), 1)
	_cable([Vector2(GENERATOR.x, GENERATOR.z + 0.4), Vector2(-17.5, -25.2), Vector2(-21.0, -24.5), Vector2(-25.0, -21.0), Vector2(-25.8, -19.9)])
	_cable([Vector2(GENERATOR.x - 0.3, GENERATOR.z + 0.3), Vector2(-17.3, -27.6), Vector2(-22.0, -27.8)])


## A plain timber pallet (1.2 x 0.8 m, 14 cm).
func _pallet(at: Vector3, yaw: float) -> void:
	var wood: Material = load("res://materials/env/crate_wood.tres")
	var basis := Basis(Vector3.UP, yaw)
	for k in 5:
		b.block(Vector3(1.2, 0.022, 0.1), at + basis * Vector3(0, 0.129, -0.35 + k * 0.175), wood, root, basis)
	for k in 3:
		b.block(Vector3(0.1, 0.098, 0.8), at + basis * Vector3(-0.55 + k * 0.55, 0.069, 0), wood, root, basis)
		b.block(Vector3(1.2, 0.02, 0.1), at + basis * Vector3(0, 0.01, -0.35 + k * 0.35), wood, root, basis)
	var body := StaticBody3D.new()
	b.add(body, root)
	b.collide(Vector3(1.2, 0.14, 0.8), at + Vector3(0, 0.07, 0), body, basis)


# --- the crew's work lights ---------------------------------------------------------------------

## Sodium tripods round the heap's west side, each cabled back to the generator: warm low light
## raking across the brass, against the cold shaft from above.
func _heap_lights() -> void:
	var heap: Vector3 = b.HEAP
	var aim := heap + Vector3(0, 0.7, 0)  # low: the cones graze the floor round the foot too
	_tripod(heap + Vector3(-7.4, 0, -9.6), aim, 2)
	_tripod(heap + Vector3(-7.6, 0, 9.4), aim, 2)
	_tripod(heap + Vector3(5.3, 0, 11.6), aim + Vector3(0, 1.0, 0), 1)
	var g := Vector2(GENERATOR.x, GENERATOR.z)
	_cable([g + Vector2(0.4, 0.3), Vector2(-15.6, -23.5), Vector2(-16.0, -19.0), Vector2(-16.4, -9.6)])
	_cable([Vector2(-16.4, -9.4), Vector2(-17.4, -4.0), Vector2(-17.6, 3.0), Vector2(-17.0, 8.0), Vector2(-16.6, 9.4)])
	_cable([Vector2(-16.5, 9.6), Vector2(-14.0, 12.4), Vector2(-9.0, 13.9), Vector2(-5.0, 13.4), Vector2(-3.7, 11.6)])


## The office pack's two-head flood on its tripod (tools/build_office.py), turned to face `aim`;
## `heads` of its two lamps lit (a lone one: the other's dead), each a spot on `aim`.
const TRIPOD_LENSES: Array[Vector3] = [Vector3(-0.32, 2.35, -0.055), Vector3(0.26, 2.35, 0.275)]  # recessed lens faces, +Z


func _tripod(at: Vector3, aim: Vector3, heads: int) -> void:
	var stand: StaticBody3D = b._prop(root, b.OFFICE + "tripod_light.gltf", at, 0.0)
	stand.basis = Basis.looking_at(Vector3(aim.x - at.x, 0, aim.z - at.z), Vector3.UP, true)
	var to_local := stand.transform.affine_inverse()
	var lens := _glow(Color(1.0, 0.82, 0.6), 6.0)
	for h in heads:
		var p := TRIPOD_LENSES[h]
		var face: MeshInstance3D = b.block(Vector3(0.3, 0.22, 0.01), p, lens, stand)
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var target: Vector3 = to_local * (aim + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)))
		var head := Node3D.new()
		head.transform = Transform3D(Basis.looking_at(target - p), p)
		b.add(head, stand)
		var spot := SpotLight3D.new()
		spot.position = Vector3(0, 0, -0.03)
		spot.light_color = SODIUM
		spot.light_energy = 5.0 if heads > 1 else 3.5
		spot.spot_range = 22.0
		spot.spot_angle = 48.0
		spot.spot_angle_attenuation = 1.3
		spot.light_volumetric_fog_energy = 0.5
		spot.shadow_enabled = h == 0
		b.add(spot, head)


func _rod(parent: Node3D, from: Vector3, to: Vector3, r: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = from.distance_to(to)
	c.radial_segments = 8
	var up := (to - from).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	b.add(_mesh(c, dark, Transform3D(Basis(side, up, side.cross(up)), (from + to) / 2.0)), parent)


## A power cable lying on the floor through `points` (x, z), with a little slack wander.
func _cable(points: Array, height := 0.012) -> void:
	var path := PackedVector3Array()
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var c: Vector2 = points[i + 1]
		var n := maxi(2, int(a.distance_to(c) / 0.4))
		var normal := (c - a).orthogonal().normalized()
		for k in n:
			var t := float(k) / n
			var p := a.lerp(c, t) + normal * sin(t * PI * 2.0 + i) * 0.08
			path.append(Vector3(p.x, height, p.y))
	var last: Vector2 = points[-1]
	path.append(Vector3(last.x, height, last.y))
	b.add(_mesh(_tube(path, 0.012), cord, Transform3D()), root)


## A round tube along `path`.
func _tube(path: PackedVector3Array, r: float) -> ArrayMesh:
	const SEGS := 6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in path.size():
		var fwd := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := fwd.cross(Vector3.UP)
		side = (side if side.length() > 0.1 else fwd.cross(Vector3.RIGHT)).normalized()
		var up := side.cross(fwd)
		var ring := []
		for k in SEGS:
			var a := TAU * k / SEGS
			ring.append(path[i] + (side * cos(a) + up * sin(a)) * r)
		rings.append(ring)
	for i in rings.size() - 1:
		for k in SEGS:
			var k2 := (k + 1) % SEGS
			for v in [rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k], rings[i + 1][k2], rings[i][k2]]:
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	return st.commit()


# --- red emergency lamps ------------------------------------------------------------------------

## The army's emergency lamps, still lit on their battery: caged bulkheads with red glass, the
## hall's red mood light washing down the walls. None by the loading door: that reads as "exit".
func _beacons() -> void:
	# Only where the army needed one: the range's mouth, the loading door, the stores wall.
	var red := Color(1.0, 0.1, 0.05)
	_lamp(Vector3(-27.98, 4.6, -0.6), Vector3(1, 0, 0), red, 2.0)   # behind the crate stands
	_lamp(Vector3(27.8, 4.4, -13.4), Vector3(-1, 0, 0), red, 2.0)   # the range bay's mouth
	_lamp(Vector3(27.8, 4.4, 13.4), Vector3(-1, 0, 0), red, 2.0)


## Poly Haven's caged wall lamp on a wall facing `out`, its glass glowing `colour`, a soft light
## pooling round it and a wide spot washing down the wall.
func _lamp(at: Vector3, out: Vector3, colour: Color, energy: float) -> void:
	var lamp: Node3D = (load(MODELS + "industrial_wall_lamp/industrial_wall_lamp_1k.gltf") as PackedScene).instantiate()
	lamp.transform = Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), at)
	b.add(lamp, root)
	for mi: MeshInstance3D in lamp.find_children("*", "MeshInstance3D", true, false):
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i).duplicate() as StandardMaterial3D
			if m.resource_name.contains("glass") or m.emission_enabled:
				m.albedo_color = m.albedo_color * colour
				m.emission_enabled = true
				m.emission = colour
				m.emission_energy_multiplier = 3.0
			mi.set_surface_override_material(i, m)
	var glow := OmniLight3D.new()
	glow.position = at + out * 0.3
	glow.light_color = colour
	glow.light_energy = energy * 0.35
	glow.omni_range = 2.2
	glow.light_volumetric_fog_energy = 0.8
	b.add(glow, root)
	var wash := SpotLight3D.new()
	wash.transform = Transform3D(Basis.looking_at(out * 0.35 + Vector3.DOWN), at + out * 0.25)
	wash.light_color = colour
	wash.light_energy = energy * 0.8
	wash.spot_range = 9.0
	wash.spot_angle = 40.0
	wash.spot_angle_attenuation = 1.2
	wash.light_volumetric_fog_energy = 1.2
	b.add(wash, root)


# --- overhead -----------------------------------------------------------------------------------

## The 8 m of air: cables sagging between the trusses, chain hoists left hanging. All on the
## overhead layer (the placement view looks past it).
func _overhead() -> void:
	var over := Node3D.new()
	over.name = "Overhead"
	b.add(over, root)
	var y: float = b.BOTTOM - 0.12
	for run in [[-24.0, -14.0, 5.0], [-21.0, 21.0, -11.0], [-7.0, 14.0, 17.0], [-21.0, 0.0, -18.5]]:
		var path := PackedVector3Array()
		var x: float = run[2]
		var z: float = run[0]
		while z < run[1] - 0.01:  # one sag per 7 m bay
			var z_next := minf(z + 7.0, run[1])
			for k in 14:
				var t := k / 14.0
				path.append(Vector3(x, y - 1.1 * sin(t * PI) * (z_next - z) / 7.0, lerpf(z, z_next, t)))
			z = z_next
		path.append(Vector3(x, y, run[1]))
		b.add(_mesh(_tube(path, 0.014), cord, Transform3D()), over)
	for h in [[Vector3(4.5, 0, -21.0), 3.8], [Vector3(-14.0, 0, 7.0), 4.6], [Vector3(21.5, 0, -21.0), 4.2]]:
		_hoist(over, h[0], h[1])
	b.overhead(over)


## A chain hoist hanging from a truss down to `low` m, its hook free.
func _hoist(parent: Node3D, at: Vector3, low: float) -> void:
	var top: float = b.BOTTOM - 0.1
	b.block(Vector3(0.24, 0.3, 0.2), Vector3(at.x, top - 0.25, at.z), load("res://materials/env/paint_unit.tres"), parent)
	var link := TorusMesh.new()
	link.inner_radius = 0.012
	link.outer_radius = 0.028
	link.rings = 8
	link.ring_segments = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link
	var n := int((top - 0.4 - low) / 0.045)
	mm.instance_count = n
	for i in n:  # links stand on edge, every other one turned a quarter
		var basis := Basis(Vector3.UP, (i % 2) * PI / 2) * Basis(Vector3.FORWARD, PI / 2)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(at.x, top - 0.4 - i * 0.045, at.z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = steel
	b.add(mmi, parent)
	b.block(Vector3(0.08, 0.14, 0.05), Vector3(at.x, low - 0.07, at.z), steel, parent)


func _mesh(mesh: Mesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	return mi


func _flat(colour: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	return m


func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var m := _flat(colour, 0.3)
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	return m


# --- the range ----------------------------------------------------------------------------------

## The range's own years: water swollen up the foot of the plywood with a tide line, sand slumped
## out of the backstop over the rubber, and dusty boot prints worn from the railing to where the
## targets stood and back.
func _range_wear() -> void:
	var fl: float = b.GS.FIRING_LINE_X
	var tide := _tide_tex()
	var faces := []  # [from, to, fixed coordinate, along_x, out]
	for s in [-1.0, 1.0]:
		faces.append([fl + 0.3, 27.6, s * 27.96, true, Vector3(0, 0, -s)])
		faces.append([s * b.BAY_HALF, s * 27.6, 27.96, false, Vector3(-1, 0, 0)])
		faces.append([28.4, b.BAY_END - 0.2, s * (b.BAY_HALF - 0.04), true, Vector3(0, 0, -s)])
	for f in faces:
		var lo := minf(f[0], f[1])
		var hi := maxf(f[0], f[1])
		var t := lo
		while t < hi - 0.5:
			var w := minf(rng.randf_range(2.0, 4.5), hi - t)
			var h := rng.randf_range(0.5, 1.1)
			var c := t + w / 2.0
			var at := Vector3(c, h / 2.0, f[2]) if f[3] else Vector3(f[2], h / 2.0, c)
			var d := _on_face(tide, at, f[4], Vector2(w, h))
			d.modulate = Color(1, 1, 1, rng.randf_range(0.55, 0.95))
			t += w + rng.randf_range(-0.3, 0.8)
	# Sand slumped out over the rubber at the backstop's toe.
	var spill := _sand_tex()
	for z in [-8.0, -2.5, 3.0, 8.5]:
		var d: Decal = b._decal(root, spill, Vector3(b.BERM_TOE - 0.6, 0, z + rng.randf_range(-1.0, 1.0)), PI / 2 + rng.randf_range(-0.15, 0.15), Vector3(6.5, 0.6, 2.6))
		d.modulate = Color(1, 1, 1, rng.randf_range(0.7, 1.0))
	# Boot prints out to the target lines and back.
	var prints := _prints_tex()
	for path in [[Vector2(fl + 0.5, -19.0), Vector2(22.5, -17.5)], [Vector2(fl + 0.5, -9.0), Vector2(24.0, -7.0)],
			[Vector2(fl + 0.5, 2.0), Vector2(23.0, 1.0)], [Vector2(fl + 0.5, 11.0), Vector2(21.5, 13.5)],
			[Vector2(fl + 0.5, 20.0), Vector2(24.5, 19.0)], [Vector2(23.0, 1.0), Vector2(39.0, -1.5)],
			[Vector2(24.0, -7.0), Vector2(38.5, 4.0)]]:
		for back in [0.0, 1.0]:
			var a: Vector2 = path[0]
			var c: Vector2 = path[1]
			if back > 0:  # the way back wanders off the way out
				a += Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-1.2, 1.2))
			var side := (c - a).orthogonal().normalized() * (0.35 if back > 0 else -0.35)
			var dir := (c - a)
			var n := int(ceilf(dir.length() / 6.0))
			for k in n:  # 6 m strips of prints
				var p0 := a + dir * (float(k) / n) + side
				var p1 := a + dir * (float(k + 1) / n) + side
				var mid := (p0 + p1) / 2.0
				var yaw: float = atan2(dir.x, dir.y) + PI * back
				var d: Decal = b._decal(root, prints, Vector3(mid.x, 0, mid.y), yaw, Vector3(0.5, 0.4, p0.distance_to(p1)))
				d.modulate = Color(1, 1, 1, rng.randf_range(0.08, 0.2))


func _tide_tex() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 23
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	return b._decal_tex("tide_line", 512, 128, func(img: Image) -> void:
		for y in 128:
			for x in 512:
				var line := 18.0 + 22.0 * (noise.get_noise_1d(x * 0.7) + 0.5)  # the tide line's height from the top
				var ends := smoothstep(0.0, 60.0, minf(x, 511 - x))
				var a := 0.0
				var c := Color(0.2, 0.13, 0.07)
				if y > line:
					a = 0.45 + 0.3 * (y - line) / (128.0 - line) + 0.2 * noise.get_noise_2d(x, y)
				var rim := absf(y - line)
				if rim < 3.0:  # the dark ring the water left
					a = maxf(a, 0.8 * (1.0 - rim / 3.0))
					c = Color(0.12, 0.07, 0.03)
				img.set_pixel(x, y, Color(c, clampf(a, 0.0, 1.0) * ends)))


func _sand_tex() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 88
	noise.frequency = 0.025
	noise.fractal_octaves = 5
	return b._decal_tex("sand_spill", 512, 256, func(img: Image) -> void:
		for y in 256:
			for x in 512:
				var thick := pow(y / 255.0, 0.8)  # row 255 at the backstop
				var ends := smoothstep(0.0, 120.0, minf(x, 511 - x))
				var n := noise.get_noise_2d(x, y)
				var a := clampf(thick * 1.3 + n * 0.8 - 0.25, 0.0, 1.0) * ends
				img.set_pixel(x, y, Color(Color(0.62, 0.55, 0.42).lerp(Color(0.5, 0.44, 0.33), n + 0.5), a)))


func _prints_tex() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 15
	noise.frequency = 0.06
	return b._decal_tex("boot_prints", 64, 1024, func(img: Image) -> void:
		img.fill(Color(0, 0, 0, 0))
		var k := 0
		var y := 20.0
		var r := RandomNumberGenerator.new()
		r.seed = 5
		while y < 1000.0:  # 6 m strip: a step every ~0.4 m, left and right, uneven, some scuffed out
			var cx := (20.0 if k % 2 == 0 else 44.0) + r.randf_range(-4.0, 4.0)
			if r.randf() < 0.25:
				y += r.randf_range(58.0, 80.0)
				k += 1
				continue
			for py in range(-30, 31):
				for px in range(-10, 11):
					var heel := py > 14
					var e := Vector2(px / (7.0 if heel else 9.0), (py - (22.0 if heel else -6.0)) / (8.0 if heel else 22.0)).length()
					if e < 1.0 and (heel or py < 6):
						var tread := 0.6 if posmod(py, 5) < 3 else 0.25
						var q := Vector2i(int(cx) + px, int(y) + py)
						if q.y >= 0 and q.y < 1024:
							img.set_pixelv(q, Color(0.5, 0.48, 0.44, tread * clampf(0.7 + noise.get_noise_2d(q.x, q.y), 0.0, 1.0)))
			y += r.randf_range(58.0, 80.0)
			k += 1)


# --- the crew at work ---------------------------------------------------------------------------

## What the crew does here, in sight of the heap: a sieve table on the north wall where they sift
## the brass for keys, buckets of it, a wheelbarrow; the board on the office where the keys will
## hang (twelve hooks, all empty); spades left by the work lights; sagging roof insulation; the
## army's cameras still on two columns; the army's boxes on the west shelves.
func _crew_work() -> void:
	var m := func(n: String) -> String: return MODELS + n + "/" + n + "_1k.gltf"
	var brass := _bullet_mesh()
	# Sieve table: a steel frame at 0.85 m, a tilted mesh tray, a mound of sifted brass under it.
	var at := Vector3(-5.6, 0, -27.25)
	for sx in [-0.75, 0.75]:
		for sz in [-0.4, 0.4]:
			b.block(Vector3(0.04, 0.85, 0.04), at + Vector3(sx, 0.425, sz), steel, root)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_texture = _sieve_tex()
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_mat.metallic = 0.7
	mesh_mat.roughness = 0.5
	var tray := Basis(Vector3.RIGHT, 0.17)
	b.add(_mesh(_quad_mesh(Vector2(1.6, 0.9)), mesh_mat, Transform3D(tray * Basis(Vector3.RIGHT, -PI / 2), at + Vector3(0, 0.9, 0))), root)
	for e in [[Vector3(0, 0, -0.45), Vector3(1.64, 0.06, 0.04)], [Vector3(0, 0, 0.45), Vector3(1.64, 0.06, 0.04)],
			[Vector3(-0.8, 0, 0), Vector3(0.04, 0.06, 0.9)], [Vector3(0.8, 0, 0), Vector3(0.04, 0.06, 0.9)]]:
		b.block(e[1], at + Vector3(0, 0.9, 0) + tray * e[0], steel, root, tray)
	_brass_pile(brass, at + Vector3(0, 0, 0.1), 0.55, 0.22, 420)
	_brass_pile(brass, at + Vector3(0.2, 0.93, -0.05), 0.35, 0.06, 90, tray)  # some still on the mesh
	var body := StaticBody3D.new()
	b.add(body, root)
	b.collide(Vector3(1.6, 0.95, 0.9), at + Vector3(0, 0.475, 0), body)
	# Buckets, two full of brass and two empty; a wheelbarrow, handles toward the heap.
	for bk in [[Vector3(-4.3, 0, -27.4), true], [Vector3(-3.85, 0, -26.95), false], [Vector3(-7.0, 0, -27.5), true], [Vector3(-7.4, 0, -27.0), false]]:
		_bucket(bk[0], bk[1], brass)
	_wheelbarrow(Vector3(-8.4, 0, -26.3), PI - 0.5, brass)
	# The key board on the office: twelve numbered hooks, all empty until the heap gives them up.
	var board_at := Vector3(-21.4, 1.55, -25.31)
	b.block(Vector3(1.1, 0.6, 0.02), board_at, load("res://materials/env/plywood_2.tres"), root)
	for i in 12:
		var hook := board_at + Vector3(-0.42 + (i % 6) * 0.168, 0.04 - (i / 6) * 0.25, 0.012)
		b.block(Vector3(0.012, 0.012, 0.05), hook + Vector3(0, 0, 0.025), steel, root)
		var n: Label3D = b._range_label(str(i + 1), 22, Color(0.08, 0.08, 0.08, 0.8), b.STENCIL)
		n.position = hook + Vector3(0, -0.065, 0.001)
		b.add(n, root)
	# Spades left by the work lights.
	var spade: String = m.call("rusted_spade_01")
	for sp in [[Vector3(-16.0, 0.5, -9.15), 0.4], [Vector3(-16.2, 0.5, 9.85), 2.0], [Vector3(-3.4, 0.5, 12.0), 2.6]]:
		b._prop(root, spade, sp[0], sp[1], 1.0, Basis(Vector3.RIGHT, 0.32))
	b._prop(root, MODELS + "rubber_boots/rubber_boots_1k.gltf", Vector3(-15.5, 0, -10.2), 0.8)
	# The army's cameras, still on two columns, watching the heap; a cut cable under each.
	var cam: String = m.call("security_camera_01")
	for c in [Vector3(27.55, 5.0, -27.55), Vector3(-27.55, 5.0, 27.55)]:
		var yaw := atan2(-(-9.0 - c.x), -(0.0 - c.z))
		b._prop(root, cam, c, yaw)
		b.block(Vector3(0.012, 0.6, 0.012), c + Vector3(0, -0.4, 0), cord, root, Basis(Vector3.FORWARD, 0.15))
	# The west shelves were bare: the army's boxes left on them.
	var box: String = m.call("cardboard_box_01")
	var ammo: String = MODELS + "ammo_box/ammo_box_1k.gltf"
	for z in [-6.0, -4.8, 4.8, 6.0]:
		for level in [0.42, 1.12]:
			if rng.randf() < 0.75:
				b._prop(root, box if rng.randf() < 0.5 else ammo, Vector3(-27.4, level, z + rng.randf_range(-0.1, 0.1)), PI / 2 + rng.randf_range(-0.3, 0.3))
	_insulation()


## Foil-faced roof insulation come loose between the purlins, hanging in sagging flaps.
func _insulation() -> void:
	var over := Node3D.new()
	over.name = "Insulation"
	b.add(over, root)
	var foil := StandardMaterial3D.new()
	foil.albedo_color = Color(0.55, 0.53, 0.5)
	foil.metallic = 0.6
	foil.roughness = 0.45
	foil.cull_mode = BaseMaterial3D.CULL_DISABLED
	var noise := FastNoiseLite.new()
	noise.seed = 12
	noise.frequency = 0.9
	for spot in [Vector2(-20, -18), Vector2(-2, -4), Vector2(8, 11), Vector2(20, 24), Vector2(-14, 21), Vector2(3, -22), Vector2(-24, 4), Vector2(13, -9), Vector2(-4, 19), Vector2(22, -14)]:
		var x: float = spot.x
		var top: float = b.top_chord(x) + 0.05
		var drop := rng.randf_range(0.7, 1.6)
		var w := rng.randf_range(0.9, 1.4)
		var pt := func(u: int, v: int) -> Vector3:  # pinned at the top, sagging, crumpled
			var fu := float(u) / 6.0
			var fv := float(v) / 10.0
			var crumple := noise.get_noise_2d(u * 1.3 + x, v * 1.3) * 0.12
			return Vector3((fu - 0.5) * w, -fv * drop, sin(fv * PI * 0.8) * 0.25 + crumple)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for u in 6:
			for v in 10:
				var a: Vector3 = pt.call(u, v)
				var c: Vector3 = pt.call(u + 1, v)
				var d: Vector3 = pt.call(u, v + 1)
				var e: Vector3 = pt.call(u + 1, v + 1)
				for q in [a, c, e, a, e, d]:
					st.add_vertex(q)
		st.generate_normals()
		b.add(_mesh(st.commit(), foil, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, top, spot.y))), over)
	b.overhead(over)


func _bullet_mesh() -> Mesh:
	var scene: Node = (load("res://assets/bullet/bullet_9mm_lod.glb") as PackedScene).instantiate()
	var mesh: Mesh = (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	return mesh


## A low mound of loose rounds: `count` lying every which way within `radius`, up to `height`.
func _brass_pile(mesh: Mesh, at: Vector3, radius: float, height: float, count: int, tilt := Basis()) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var r := radius * sqrt(rng.randf())
		var a := rng.randf() * TAU
		var y := height * (1.0 - r / radius) * rng.randf()
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2 + rng.randf_range(-0.4, 0.4))
		mm.set_instance_transform(i, Transform3D(tilt * basis, tilt * Vector3(cos(a) * r, y + 0.01, sin(a) * r)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = at
	b.add(mmi, root)


func _bucket(at: Vector3, full: bool, brass: Mesh) -> void:
	var lathe: ArrayMesh = preload("res://tools/range_dressing.gd")._lathe([Vector2(0.0, 0.0), Vector2(0.0, 0.13), Vector2(0.32, 0.16), Vector2(0.33, 0.165)], 20)
	var pail := StandardMaterial3D.new()
	pail.albedo_color = Color(0.55, 0.57, 0.58)
	pail.metallic = 0.8
	pail.roughness = 0.45
	pail.cull_mode = BaseMaterial3D.CULL_DISABLED
	b.add(_mesh(lathe, pail, Transform3D(Basis(Vector3.RIGHT, -PI / 2), at)), root)
	if full:
		_brass_pile(brass, at + Vector3(0, 0.27, 0), 0.14, 0.06, 60)


func _wheelbarrow(at: Vector3, yaw: float, brass: Mesh) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var tray: Material = load("res://materials/env/paint_olive.tres")
	var tb := basis * Basis(Vector3.RIGHT, 0.08)
	b.block(Vector3(0.62, 0.04, 0.85), at + basis * Vector3(0, 0.42, 0), tray, root, tb)
	for e in [[Vector3(-0.31, 0.13, 0), Vector3(0.03, 0.26, 0.85)], [Vector3(0.31, 0.13, 0), Vector3(0.03, 0.26, 0.85)],
			[Vector3(0, 0.13, -0.42), Vector3(0.62, 0.26, 0.03)], [Vector3(0, 0.13, 0.42), Vector3(0.62, 0.26, 0.03)]]:
		b.block(e[1], at + basis * (Vector3(0, 0.42, 0) + e[0]), tray, root, tb)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.19
	wheel.bottom_radius = 0.19
	wheel.height = 0.08
	b.add(_mesh(wheel, dark, Transform3D(basis * Basis(Vector3.FORWARD, PI / 2), at + basis * Vector3(0, 0.19, -0.55))), root)
	for sx in [-0.25, 0.25]:
		_rod(root, at + basis * Vector3(sx, 0.19, -0.55), at + basis * Vector3(sx * 1.2, 0.55, 0.95), 0.016)
		_rod(root, at + basis * Vector3(sx, 0.4, 0.3), at + basis * Vector3(sx, 0.0, 0.35), 0.014)
	_brass_pile(brass, at + basis * Vector3(0, 0.46, 0), 0.26, 0.12, 160)
	var body := StaticBody3D.new()
	b.add(body, root)
	b.collide(Vector3(0.7, 0.7, 1.5), at + Vector3(0, 0.35, 0), body, basis)


func _sieve_tex() -> Texture2D:
	return b._decal_tex("sieve_mesh", 128, 128, func(img: Image) -> void:
		for y in 128:
			for x in 128:
				var wire := x % 8 < 2 or y % 8 < 2
				img.set_pixel(x, y, Color(0.35, 0.34, 0.32, 1.0) if wire else Color(0, 0, 0, 0)))
