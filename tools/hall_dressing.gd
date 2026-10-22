extends RefCounted
## The hall's abandonment for tools/build_arena.gd (2026-10-22): years of an empty army range,
## then the digging crew's few months on top. Plan from the art-director and research reviews.
##   Decay: sun shafts through the broken skylights and rust holes (build_arena SKY_HOLES /
##     RUST_HOLES), each with a puddle and fallen bits under it; cracks along the slab joints,
##     dust drifts at the wall feet, pigeon droppings under the trusses, leaks and moss down the
##     walls, a few old tags near the doors.
##   Light, one meaning per colour: cold daylight through the holes (abandoned), sodium tripods
##     and caged bulbs on the crew's generator (alive), red army beacons still turning on their
##     battery, green exit signs.
##   The crew: a camp in the north-west corner (container office, desk, stove, generator), their
##     covered car by the jammed loading door in the south wall, cables back to the generator.
##     The belt band east of the heap (x -3..14) and the placement zones stay clear on the floor;
##     what hangs overhead goes on the overhead layer.

const MODELS := "res://assets/env/models/"
const DECALS := "res://materials/env/decals/"
const ACG := "res://assets/env/decals/"
const SODIUM := Color(1.0, 0.6, 0.3)
const BEACON := preload("res://scripts/beacon.gd")
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
	_shafts()
	_floor_decay()
	_wall_decay()
	_loading_door()
	_doors()
	_camp()
	_heap_lights()
	_beacons()
	_overhead()


# --- sun shafts ---------------------------------------------------------------------------------

## Where the sun through a roof hole at `x, z` lands on the floor.
func landing(x: float, z: float) -> Vector3:
	var d: Vector3 = b.SUN_DIR.normalized()
	var top := Vector3(x, b.top_chord(x) + 0.35, z)
	return top + d * (top.y / -d.y)


func _shafts() -> void:
	var holes: Array = b.SKY_HOLES + b.RUST_HOLES
	var noise := FastNoiseLite.new()
	noise.seed = 17
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var beam := ShaderMaterial.new()
	beam.shader = load("res://materials/env/sun_shaft.gdshader")
	beam.set_shader_parameter("noise_tex", nt)
	ResourceSaver.save(beam, "res://materials/env/sun_shaft.tres")
	beam = load("res://materials/env/sun_shaft.tres")
	var unit := BoxMesh.new()
	for i in holes.size():
		var h: Vector4 = holes[i]
		var c := Vector2((h.x + h.z) / 2.0, (h.y + h.w) / 2.0)
		var size := Vector2(h.z - h.x, h.w - h.y)
		var top := Vector3(c.x, b.top_chord(c.x) + 0.35, c.y)
		var foot := landing(c.x, c.y)
		# The beam: a unit box sheared along the sunlight, so every slice of it is the hole.
		var xf := Transform3D(Basis(Vector3(size.x * 0.9, 0, 0), top - foot, Vector3(0, 0, size.y * 0.9)), (top + foot) / 2.0)
		var shaft := _mesh(unit, beam, xf)
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		b.add(shaft, root)
		_motes(Transform3D(Basis(), (top + foot) / 2.0), Vector3(size.x, top.y - foot.y, size.y) * 0.8 + Vector3(absf(top.x - foot.x), 0, absf(top.z - foot.z)))
		# Rain falls straight in: a puddle right under the hole, bits of roof in it.
		var under := Vector3(c.x, 0, c.y)
		if Vector2(under.x - b.HEAP.x, under.z - b.HEAP.z).length() < 9.0:
			continue  # over the heap
		_puddle(under, maxf(size.x, size.y) * rng.randf_range(0.9, 1.25), rng.randf() * TAU)
		if i < b.SKY_HOLES.size():
			for k in 6:  # fibreglass shards
				var at := under + Vector3(rng.randf_range(-1.4, 1.4), 0.004, rng.randf_range(-1.4, 1.4))
				var shard: MeshInstance3D = b.block(Vector3(rng.randf_range(0.15, 0.5), 0.006, rng.randf_range(0.1, 0.35)), at,
					load("res://materials/env/skylight.tres"), root, Basis(Vector3.UP, rng.randf() * TAU))
				shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Specks in a shaft: only lit inside it, so they read as dust turning in the sunlight.
func _motes(xf: Transform3D, size: Vector3) -> void:
	var speck := QuadMesh.new()
	speck.size = Vector2(0.012, 0.012)
	var look := StandardMaterial3D.new()
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.albedo_color = Color(1.0, 0.97, 0.9, 0.5)
	speck.material = look
	var drift := ParticleProcessMaterial.new()
	drift.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	drift.emission_box_extents = size * 0.45
	drift.spread = 180.0
	drift.initial_velocity_min = 0.01
	drift.initial_velocity_max = 0.04
	drift.gravity = Vector3(0, -0.004, 0)
	drift.turbulence_enabled = true
	drift.turbulence_noise_scale = 3.0
	drift.turbulence_influence_max = 0.03
	drift.scale_min = 0.5
	drift.scale_max = 1.6
	var p := GPUParticles3D.new()
	p.transform = xf
	p.amount = 260
	p.lifetime = 20.0
	p.preprocess = 20.0
	p.local_coords = true
	p.process_material = drift
	p.draw_pass_1 = speck
	p.visibility_aabb = AABB(-size * 0.6, size * 1.2)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add(p, root)


## Standing water: darker, mirror-smooth (SSR), a damp ring round it.
func _puddle(at: Vector3, size: float, yaw: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var shape := func(x: int, y: int) -> float:
		return 1.0 - Vector2(x - 256, y - 256).length() / 256.0 + noise.get_noise_2d(x, y) * 0.55
	var water: Texture2D = b._decal_tex("puddle", 512, 512, func(img: Image) -> void:
		for y in 512:
			for x in 512:
				var s: float = shape.call(x, y)
				var a := clampf(s * 5.0, 0.0, 1.0)  # the water, crisp edged
				var damp := clampf(s * 2.0 + 0.5, 0.0, 1.0) * 0.55  # the wet ring
				img.set_pixel(x, y, Color(0.02, 0.022, 0.025, maxf(a, damp))))
	var orm: Texture2D = b._decal_tex("puddle_orm", 512, 512, func(img: Image) -> void:
		for y in 512:
			for x in 512:
				var s: float = shape.call(x, y)
				img.set_pixel(x, y, Color(1.0, lerpf(0.5, 0.1, clampf(s * 5.0, 0.0, 1.0)), 0.0)))
	var d: Decal = b._decal(root, water, at, yaw, Vector3(size, 0.6, size * rng.randf_range(0.6, 0.9)))
	d.texture_orm = orm
	d.albedo_mix = 0.3


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
	d.transform = Transform3D(basis * Basis(Vector3.RIGHT, -PI / 2), basis * Vector3(along, 0, 28.0) + Vector3(0, y, 0))
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
	# A few old tags from the years it stood empty, near the doors, at arm's height.
	var tags := _graffiti()
	for t in [[0, DOOR_X - 4.4, 1.6, 0, 1.0], [0, DOOR_X + 4.6, 1.35, 1, 0.8], [2, 12.0, 1.5, 2, 0.75],
			[3, 18.5, 1.7, 3, 0.85], [2, -9.0, 1.45, 4, 0.7]]:
		var d := _on_wall(tags[t[3]], t[0], t[1], t[2], Vector2(1.9, 1.9))
		d.modulate = Color(1, 1, 1, t[4])


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


## Tags out of ambientCG's GraffitiSet001 atlas (4x4 cells), sprayed in our own colours.
func _graffiti() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var cells := [Vector2i(3, 0), Vector2i(3, 1), Vector2i(1, 3), Vector2i(0, 3), Vector2i(2, 2)]
	var colours := [Color(0.08, 0.08, 0.09), Color(0.72, 0.12, 0.08), Color(0.85, 0.85, 0.82), Color(0.1, 0.2, 0.45), Color(0.08, 0.08, 0.09)]
	var op: Image = null
	for i in cells.size():
		var path := DECALS + "tag_%d.res" % i
		if ResourceLoader.exists(path):
			out.append(load(path))
			continue
		if op == null:
			op = Image.load_from_file(ProjectSettings.globalize_path(ACG + "GraffitiSet001/GraffitiSet001_2K-JPG_Opacity.jpg"))
		var cell := op.get_region(Rect2i(cells[i] * 512, Vector2i(512, 512)))
		var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		for y in 512:
			for x in 512:
				img.set_pixel(x, y, Color(colours[i], cell.get_pixel(x, y).r * 0.85))
		out.append(_save_tex(img, path))
	return out


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

## The loading door in the south wall: a roller shutter jammed 0.7-1.1 m open, daylight on the
## yard outside and a fan of it laid across the dusty floor. The wall's collision still runs across.
func _loading_door() -> void:
	var z := 28.15
	var paint: Material = b.worn("metal_plate_02", "shutter_paint", {"tint": Color(0.55, 0.62, 0.66), "tex_size": 1.2,
		"cell_size": 4.0, "grime": 0.6, "grime_scale": 0.5, "rust": 0.7})
	var frame: Material = load("res://materials/env/range_steel_dark.tres")
	for s in [-1.0, 1.0]:  # side guides
		b.block(Vector3(0.16, 4.0, 0.36), Vector3(DOOR_X + s * 2.0, 2.0, z), frame, root)
	b.block(Vector3(4.3, 0.55, 0.6), Vector3(DOOR_X, 3.78, z - 0.1), frame, root)  # the roll box
	# Slats down to a crooked bottom edge: one guide broke, the left side dropped lower.
	const LEFT := 0.7
	const RIGHT := 1.1
	var tilt := atan2(RIGHT - LEFT, 3.85)
	var y := 3.45
	while y > (LEFT + RIGHT) / 2.0 + 0.05:
		var bend := clampf((1.9 - y) / 0.9, 0.0, 1.0)  # straight high up, crooked near the bottom
		var slat: MeshInstance3D = b.block(Vector3(3.85, 0.095, 0.04), Vector3(DOOR_X, y, z + 0.02), paint, root, Basis(Vector3.BACK, -tilt * bend))
		slat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		y -= 0.1
	b.block(Vector3(3.9, 0.05, 0.07), Vector3(DOOR_X, (LEFT + RIGHT) / 2.0, z + 0.02), frame, root, Basis(Vector3.BACK, -tilt))
	# The yard: dry ground in the daylight, a bright haze beyond.
	var yard := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 14)
	yard.mesh = pm
	yard.material_override = b.pbr_box("dry_ground_01", 3.0, Color(0.9, 0.88, 0.84), true, "yard_ground")
	yard.position = Vector3(DOOR_X, 0.0, z + 7.2)
	b.add(yard, root)
	var haze := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(40, 6)
	haze.mesh = q
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Color(0.92, 0.94, 0.96)
	haze.material_override = hm
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	haze.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	haze.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(DOOR_X, 3.0, z + 14.0))
	b.add(haze, root)
	var spill := SpotLight3D.new()  # the bright yard throws light in under the door
	spill.transform = Transform3D(Basis.looking_at(Vector3(0, -0.12, -1)), Vector3(DOOR_X, 0.55, z + 3.5))
	spill.light_color = Color(1.0, 0.96, 0.9)
	spill.light_energy = 14.0
	spill.spot_range = 16.0
	spill.spot_angle = 60.0
	spill.spot_angle_attenuation = 1.2
	spill.light_volumetric_fog_energy = 2.0
	spill.shadow_enabled = true
	b.add(spill, root)
	_exit_sign(Vector3(DOOR_X, 4.55, z - 0.16), PI)
	var d: Decal = b._decal(root, _drift_tex(), Vector3(DOOR_X, 0, z - 1.2), PI, Vector3(5.5, 0.6, 2.8))
	d.modulate = Color(1, 1, 1, 0.95)  # grit blown in under it


## Steel personnel doors, shut for good, each under a green exit sign.
func _doors() -> void:
	var paint: Material = load("res://materials/env/paint_olive.tres")
	var frame: Material = load("res://materials/env/range_steel_dark.tres")
	for door in [[Vector3(-12.0, 0, -28.0), 0.0], [Vector3(-28.0, 0, 21.0), PI / 2]]:
		var at: Vector3 = door[0]
		var face := Basis(Vector3.UP, door[1])
		var out := face * Vector3(0, 0, 1)
		b.block(Vector3(1.2, 2.2, 0.06), at + out * 0.03 + Vector3(0, 1.1, 0), dark, root, face)
		b.block(Vector3(1.04, 2.08, 0.05), at + out * 0.06 + Vector3(0, 1.05, 0), paint, root, face)
		for s in [-1.0, 1.0]:
			b.block(Vector3(0.07, 2.25, 0.1), at + out * 0.05 + face * Vector3(s * 0.6, 1.12, 0), frame, root, face)
		b.block(Vector3(1.3, 0.07, 0.1), at + out * 0.05 + Vector3(0, 2.25, 0), frame, root, face)
		b.block(Vector3(0.8, 0.04, 0.05), at + out * 0.11 + Vector3(0, 1.0, 0), steel, root, face)  # push bar
		_exit_sign(at + out * 0.1 + Vector3(0, 2.6, 0), door[1])


func _exit_sign(at: Vector3, yaw: float) -> void:
	var face := Basis(Vector3.UP, yaw)
	var out := face * Vector3(0, 0, 1)
	b.block(Vector3(0.46, 0.2, 0.08), at, dark, root, face)
	var lit: MeshInstance3D = b.block(Vector3(0.42, 0.16, 0.01), at + out * 0.042, _glow(Color(0.1, 0.85, 0.35), 0.9), root, face)
	lit.gi_mode = GeometryInstance3D.GI_MODE_DISABLED  # else SDFGI paints the whole wall green
	var l: Label3D = b._range_label("ACİL ÇIKIŞ", 44, Color(0.92, 1.0, 0.94), b.STENCIL)
	l.transform = Transform3D(face, at + out * 0.049)
	l.shaded = false
	l.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	b.add(l, root)
	var glow := OmniLight3D.new()
	glow.position = at + out * 0.25
	glow.light_color = Color(0.2, 1.0, 0.45)
	glow.light_energy = 0.3
	glow.omni_range = 2.0
	glow.light_volumetric_fog_energy = 0.3
	b.add(glow, root)


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
	_stencil_on("ÜS · Y-7", c_at + Vector3(0, 1.9, 1.225), Basis(), 150, Color(0.9, 0.9, 0.86, 0.85))
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
	_beacon(GENERATOR + Vector3(0.3, 0.72, 0.1), Color(1.0, 0.55, 0.08), 1.6)
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
	# Light: caged bulbs on a cord over the desk and the stove, and one sodium tripod.
	var bulb: String = MODELS + "caged_hanging_light/caged_hanging_light_1k.gltf"
	for at in [desk + Vector3(0, 3.0, 0.6), Vector3(-18.8, 3.2, -24.0)]:
		b.block(Vector3(0.012, b.BOTTOM - at.y, 0.012), Vector3(at.x, (b.BOTTOM + at.y) / 2.0, at.z), cord, root)
		var cage: Node3D = (load(bulb) as PackedScene).instantiate()
		cage.position = at + Vector3(0, 0.75, 0)
		b.add(cage, root)
		var warm := OmniLight3D.new()
		warm.position = at + Vector3(0, -0.1, 0)
		warm.light_color = Color(1.0, 0.68, 0.38)
		warm.light_energy = 3.2
		warm.omni_range = 7.0
		warm.omni_attenuation = 1.4
		warm.light_volumetric_fog_energy = 0.8
		warm.shadow_enabled = true
		b.add(warm, root)
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


func _stencil_on(text: String, at: Vector3, face: Basis, size: int, colour: Color) -> void:
	var l: Label3D = b._range_label(text, size, colour, b.STENCIL)
	l.transform = Transform3D(face, at)
	b.add(l, root)


# --- the crew's work lights ---------------------------------------------------------------------

## Sodium tripods round the heap's west side, each cabled back to the generator: warm low light
## raking across the brass, against the cold shaft from above.
func _heap_lights() -> void:
	var heap: Vector3 = b.HEAP
	var aim := heap + Vector3(0, 1.6, 0)
	_tripod(heap + Vector3(-7.4, 0, -9.6), aim, 2)
	_tripod(heap + Vector3(-7.6, 0, 9.4), aim, 2)
	_tripod(heap + Vector3(5.3, 0, 11.6), aim + Vector3(0, 1.0, 0), 1)
	var g := Vector2(GENERATOR.x, GENERATOR.z)
	_cable([g + Vector2(0.4, 0.3), Vector2(-15.6, -23.5), Vector2(-16.0, -19.0), Vector2(-16.4, -9.6)])
	_cable([Vector2(-16.4, -9.4), Vector2(-17.4, -4.0), Vector2(-17.6, 3.0), Vector2(-17.0, 8.0), Vector2(-16.6, 9.4)])
	_cable([Vector2(-16.5, 9.6), Vector2(-14.0, 12.4), Vector2(-9.0, 13.9), Vector2(-5.0, 13.4), Vector2(-3.7, 11.6)])


## A work light on a tripod: legs, mast, `heads` LED boxes on a bar, aimed at `aim`.
func _tripod(at: Vector3, aim: Vector3, heads: int) -> void:
	var stand := Node3D.new()
	stand.transform = Transform3D(Basis.looking_at(Vector3(aim.x - at.x, 0, aim.z - at.z)), at)
	b.add(stand, root)
	var to_local := stand.transform.affine_inverse()
	const MAST := 2.1
	for k in 3:
		_rod(stand, Basis(Vector3.UP, k * TAU / 3.0 + 0.5) * Vector3(0, 0, 0.6), Vector3(0, 1.0, 0), 0.016)
	_rod(stand, Vector3(0, 0.6, 0), Vector3(0, MAST, 0), 0.022)
	var bar := 0.32 * (heads - 1)
	if heads > 1:
		_rod(stand, Vector3(-bar, MAST, 0), Vector3(bar, MAST, 0), 0.016)
	var body := StaticBody3D.new()
	b.add(body, stand)
	b.collide(Vector3(0.9, MAST, 0.9), Vector3(0, MAST / 2.0, 0), body)
	var lens := _glow(Color(1.0, 0.82, 0.6), 6.0)
	for h in heads:
		var p := Vector3(-bar + h * bar * 2.0 if heads > 1 else 0.0, MAST + 0.12, 0)
		var target: Vector3 = to_local * (aim + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)))
		var head := Node3D.new()
		head.transform = Transform3D(Basis.looking_at(target - p), p)
		b.add(head, stand)
		b.block(Vector3(0.36, 0.28, 0.1), Vector3.ZERO, dark, head)
		var face: MeshInstance3D = b.block(Vector3(0.31, 0.23, 0.01), Vector3(0, 0, -0.052), lens, head)
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var spot := SpotLight3D.new()
		spot.position = Vector3(0, 0, -0.08)
		spot.light_color = SODIUM
		spot.light_energy = 7.0 if heads > 1 else 5.0
		spot.spot_range = 22.0
		spot.spot_angle = 38.0
		spot.spot_angle_attenuation = 1.3
		spot.light_volumetric_fog_energy = 0.9
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


# --- red beacons --------------------------------------------------------------------------------

## The army's emergency beacons, still turning on their battery: the hall's red mood light.
func _beacons() -> void:
	var red := Color(1.0, 0.08, 0.04)
	_beacon(Vector3(-27.75, 5.0, -0.6), red, 3.0, Vector3(1, 0, 0))   # behind the crate stands
	_beacon(Vector3(27.6, 4.6, -13.4), red, 3.0, Vector3(-1, 0, 0))  # the range bay's mouth
	_beacon(Vector3(27.6, 4.6, 13.4), red, 3.0, Vector3(-1, 0, 0))
	_beacon(Vector3(-1.5, 4.6, 27.75), red, 2.6, Vector3(0, 0, -1))  # beside the loading door
	_beacon(Vector3(1.0, 4.6, -27.75), red, 2.6, Vector3(0, 0, 1))


## A rotating beacon: a bracket off the wall (`out` from it), a glowing dome, a turning pair of
## spots sweeping the walls. With `out` zero it stands on whatever it is put on.
func _beacon(at: Vector3, colour: Color, energy: float, out := Vector3.ZERO) -> void:
	if out != Vector3.ZERO:
		b.block(Vector3(0.05, 0.05, 0.05) + out.abs() * 0.24, at - out * 0.12 + Vector3(0, -0.05, 0), dark, root)
	b.block(Vector3(0.14, 0.06, 0.14), at, dark, root)
	var dome := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07
	s.height = 0.16
	dome.mesh = s
	dome.material_override = _glow(colour, 4.0)
	dome.position = at + Vector3(0, 0.09, 0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	b.add(dome, root)
	var spin := Node3D.new()
	spin.set_script(BEACON)
	spin.position = at + Vector3(0, 0.09, 0)
	b.add(spin, root)
	for yaw in [0.0, PI]:
		var spot := SpotLight3D.new()
		spot.rotation = Vector3(-0.08, yaw, 0)
		spot.light_color = colour
		spot.light_energy = energy
		spot.spot_range = 18.0
		spot.spot_angle = 22.0
		spot.spot_angle_attenuation = 0.8
		spot.light_volumetric_fog_energy = 1.6
		b.add(spot, spin)
	var glow := OmniLight3D.new()
	glow.position = at + Vector3(0, 0.12, 0)
	glow.light_color = colour
	glow.light_energy = 0.6
	glow.omni_range = 2.2
	b.add(glow, root)


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
