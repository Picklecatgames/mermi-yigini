extends Node3D
## The mountains' pieces (2026-11-03, the user: "the mountain is the scrap: as it runs out it goes down
## bit by bit"): the junkyard's height field (scripts/pile.gd) carries real pieces only where players
## reach (Pile._face_cell); over the rest, the mountains, real scrap models (the heap's own) lie along
## the slope, bigger the further from where players stand (a few pixels each at 270p), and ride the
## surface: as it slides down, they go down with it (redraw()). Only looks: the same seed on every
## peer, nothing to sync, no bodies.

const PARTS := 24            # models used: of the CANDIDATES widest, the lightest once simplified
const CANDIDATES := 60
const TRIS := 60             # each drawn from a copy this light
const COVER := 2.2           # their footprints over the mountains' area
const BLOCK := 4             # cells (1 m) a block: pieces are scattered block by block
## Piece scale by distance (m) from the reach of players (Pile.NEAR): SCALE.x at its edge, SCALE.y
## from SCALE_FAR.y on.
const SCALE := Vector2(1.8, 14.0)
const SCALE_FAR := Vector2(0.0, 60.0)
const GROUP := 128           # cells: pieces grouped per GROUP × GROUP, so a far side is culled whole

var _pile: Node
var _mm: Array[MultiMesh] = []
var _inst_mm := PackedInt32Array()     # per piece: its MultiMesh
var _inst_i := PackedInt32Array()      # and its instance there
var _inst_xf: Array[Transform3D] = []  # as laid, its origin's y over the surface
var _inst_k := PackedInt32Array()      # the cell it lies on
var _tile := {}                        # pile tile index -> PackedInt32Array of pieces
var _hazed: Array[ShaderMaterial] = [] # materials moved onto FAR_SHADER (its haze: _process)
## One colour for every far piece: a mosaic of near browns boiled at 270p, grey at night
## (2026-11-04, the user: "ants", "a grey pile by night"). The shader breaks it into big patches.
const FAR_RUST := Color(0.15, 0.088, 0.062)
## Scrap thrown out on the ground round the mountains' foot, thinning out into the trees; looks only.
const FRINGE := 9.0  # m
const FRINGE_COVER := 0.55
const FAR_SHADER := preload("res://materials/psx_far.gdshader")
const HAZE_MAX := 0.55        # the most the mountain goes into the dust
const HAZE_REACH := 2.2       # times the scene's fog end: where the haze is full
const NIGHT_HAZE := 0.86      # by night (dark fog), how far into it
const NIGHT_RUST := Color(0.02, 0.012, 0.012)  # a rust dark, not a grey one
const NIGHT_SHADE := 0.55      # and the haze that much darker than the fog: against the sky


func build(pile: Node) -> void:
	_pile = pile
	var t0 := Time.get_ticks_msec()
	var parts := _parts()
	if parts.is_empty():
		return
	var foot := 0.0
	for p: Array in parts:
		foot += p[2]
	foot /= parts.size()
	var gx: int = pile.GRID_X
	var gz: int = pile.GRID_Z
	var cell: float = pile.CELL
	var near: Rect2 = pile.NEAR
	var rng := RandomNumberGenerator.new()
	rng.seed = 1931
	var groups := {}  # Vector3i(group x, group z, part) -> Array of piece indices
	for bj in range(1, gz - 1, BLOCK):
		for bi in range(1, gx - 1, BLOCK):
			var c := Vector2i(mini(bi + BLOCK / 2, gx - 2), mini(bj + BLOCK / 2, gz - 2))
			var k := c.y * gx + c.x
			if pile._h[k] < 0.03 or pile._face_cell(k):
				continue
			var n: Vector3 = pile._cell_normal(c)
			var at: Vector3 = pile._cell_pos(c)
			var w: Vector2 = Vector2(at.x, at.z) + pile.CENTER
			var away: float = Vector2(maxf(maxf(near.position.x - w.x, w.x - near.end.x), 0.0), maxf(maxf(near.position.y - w.y, w.y - near.end.y), 0.0)).length()
			var s := lerpf(SCALE.x, SCALE.y, smoothstep(SCALE_FAR.x, SCALE_FAR.y, away))
			var area := pow(BLOCK * cell, 2.0) / maxf(n.y, 0.2)
			var want := area * COVER / (foot * s * s)
			var count := int(want) + int(rng.randf() < want - floorf(want))
			for m in count:
				var pos := Vector3(bi * 1.0 + rng.randf() * BLOCK, 0.0, bj * 1.0 + rng.randf() * BLOCK)
				var ck := Vector2i(clampi(int(pos.x), 1, gx - 2), clampi(int(pos.z), 1, gz - 2))
				pos = pile._cell_pos(Vector2i.ZERO) + Vector3(pos.x, 0.0, pos.z) * cell
				var pi := rng.randi() % parts.size()
				var part: Array = parts[pi]
				var size: Vector3 = part[1]
				var sc := s * rng.randf_range(0.75, 1.35)
				# Lying on the slope: its thinnest side along the normal, a random turn about it, a tilt.
				var thin := size.min_axis_index()
				var lay := Basis()
				if thin == 0:
					lay = Basis(Vector3.BACK, PI * 0.5)
				elif thin == 2:
					lay = Basis(Vector3.RIGHT, PI * 0.5)
				var side := n.cross(Vector3.FORWARD if absf(n.z) < 0.9 else Vector3.RIGHT).normalized()
				var on := Basis(side, n, side.cross(n))
				var tip := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.3))
				var basis := (on * tip * Basis(Vector3.UP, rng.randf() * TAU) * lay).scaled_local(Vector3.ONE * sc)
				pos.y = size[thin] * sc * rng.randf_range(0.05, 0.35)
				var key := Vector3i(ck.x / GROUP, ck.y / GROUP, pi)
				if not groups.has(key):
					groups[key] = []
				groups[key].append(_inst_xf.size())
				_inst_xf.append(Transform3D(basis, pos).translated_local(-part[3]))
				_inst_k.append(ck.y * gx + ck.x)
				var tile: int = (ck.y / pile.TILE) * pile.TILES_X + ck.x / pile.TILE
				if not _tile.has(tile):
					_tile[tile] = PackedInt32Array()
				_tile[tile].append(_inst_xf.size() - 1)
	_fringe(parts, groups, rng)
	_inst_mm.resize(_inst_xf.size())
	_inst_i.resize(_inst_xf.size())
	var tris := 0
	for key: Vector3i in groups:
		var part: Array = parts[key.z]
		var list: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = part[0]
		mm.instance_count = list.size()
		for i in list.size():
			_inst_mm[list[i]] = _mm.size()
			_inst_i[list[i]] = i
			mm.set_instance_color(i, Pile._tone(list[i] * 7 + 3))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = part[4]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mm.append(mm)
		tris += list.size() * part[5]
	for s in _inst_xf.size():
		_place(s)
	# The real pieces where players reach go into the same haze, or the mountain's foot stood paler
	# in the scene's fog than the mountain behind it.
	for node: MultiMeshInstance3D in pile._surface + pile._spill:
		var m := node.material_override as ShaderMaterial
		if m and not m in _hazed:
			m.shader = FAR_SHADER
			_hazed.append(m)
	for m: ShaderMaterial in _hazed:
		m.set_shader_parameter("far_colour", FAR_RUST)
	print("scrap hills: %d pieces of %d models in %d groups, %d triangles (%d ms)" % [_inst_xf.size(), parts.size(), groups.size(), tris, Time.get_ticks_msec() - t0])


## The haze follows the scene's fog (its colour turns with the day, scripts/day_night.gd).
func _process(_delta: float) -> void:
	var env := get_viewport().find_world_3d().environment
	if env == null:
		env = get_viewport().find_world_3d().fallback_environment
	var col := Color(0.5, 0.5, 0.5)
	var reach := Vector2(12.0, 160.0)
	var most := 0.0
	var day := 1.0
	if env and env.fog_enabled:
		reach = Vector2(env.fog_depth_begin, env.fog_depth_end * HAZE_REACH) if env.fog_mode == Environment.FOG_MODE_DEPTH else Vector2(10.0, 0.6 / maxf(env.fog_density, 1e-4))
		# By night the dust is dark: the mountain goes almost all into it, a little darker than the
		# sky, a silhouette; by day its scrap shows through.
		day = smoothstep(0.1, 0.5, env.background_energy_multiplier)  # the fog is dark by day too now
		col = env.fog_light_color * lerpf(NIGHT_SHADE, 1.0, day) + NIGHT_RUST * (1.0 - day)
		most = lerpf(NIGHT_HAZE, HAZE_MAX, day)
	RenderingServer.global_shader_parameter_set(&"psx_haze_colour", col)
	RenderingServer.global_shader_parameter_set(&"psx_haze_range", reach)
	RenderingServer.global_shader_parameter_set(&"psx_haze_max", most)
	RenderingServer.global_shader_parameter_set(&"psx_haze_day", day)


## Pieces lying flat on bare ground near the foot, fewer further off; they don't ride anything.
func _fringe(parts: Array, groups: Dictionary, rng: RandomNumberGenerator) -> void:
	var gx: int = _pile.GRID_X
	var gz: int = _pile.GRID_Z
	var cell: float = _pile.CELL
	var reach := int(FRINGE / cell)
	for bj in range(1, gz - 1, BLOCK):
		for bi in range(1, gx - 1, BLOCK):
			var k: int = bj * gx + bi
			if _pile._h[k] >= 0.03:
				continue
			var at: Vector3 = _pile._cell_pos(Vector2i(bi, bj))
			var w: Vector2 = Vector2(at.x, at.z) + _pile.CENTER
			if _pile.NEAR.grow(FRINGE).has_point(w):
				continue  # the real spill's (pile.gd _build_spill)
			var away := 1.0
			for step in [0.25, 0.5, 1.0]:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					var c := Vector2i(bi, bj) + Vector2i(Vector2(d) * step * reach)
					if _pile._in_grid(c) and _pile._h[c.y * gx + c.x] >= 0.03:
						away = minf(away, step)
			if away >= 1.0 and rng.randf() > 0.15:
				continue
			var want := pow(BLOCK * cell, 2.0) * FRINGE_COVER * (1.0 - away * 0.8) / 0.5
			for m in int(want) + int(rng.randf() < want - floorf(want)):
				var pi := rng.randi() % parts.size()
				var part: Array = parts[pi]
				var size: Vector3 = part[1]
				var sc := rng.randf_range(1.0, 1.7)
				var thin := size.min_axis_index()
				var lay := Basis()
				if thin == 0:
					lay = Basis(Vector3.BACK, PI * 0.5)
				elif thin == 2:
					lay = Basis(Vector3.RIGHT, PI * 0.5)
				var basis := (Basis(Vector3.UP, rng.randf() * TAU) * lay).scaled_local(Vector3.ONE * sc)
				var pos := at + Vector3(rng.randf() * BLOCK, 0.0, rng.randf() * BLOCK) * cell
				pos.y = size[thin] * sc * 0.3
				var key := Vector3i(bi / GROUP, bj / GROUP, pi)
				if not groups.has(key):
					groups[key] = []
				groups[key].append(_inst_xf.size())
				_inst_xf.append(Transform3D(basis, pos).translated_local(-part[3]))
				_inst_k.append(-1)


## The pieces over cells `area` follow the surface (pile.gd, as it redraws its own).
func redraw(area: Rect2i) -> void:
	var t: int = _pile.TILE
	for tj in range(maxi(area.position.y, 0) / t, mini(area.end.y - 1, _pile.GRID_Z - 1) / t + 1):
		for ti in range(maxi(area.position.x, 0) / t, mini(area.end.x - 1, _pile.GRID_X - 1) / t + 1):
			for s in _tile.get(tj * _pile.TILES_X + ti, PackedInt32Array()):
				_place(s)


func _place(s: int) -> void:
	var xf := _inst_xf[s]
	if _inst_k[s] < 0:
		pass  # on the bare ground
	elif _pile._h[_inst_k[s]] < 0.03:
		xf = Transform3D(Basis().scaled(Vector3.ZERO), xf.origin)  # the scrap under it is gone
	else:
		xf.origin.y += _pile._height_smooth(Vector3(xf.origin.x, 0.0, xf.origin.z))
	_mm[_inst_mm[s]].set_instance_transform(_inst_i[s], xf)


## Of the heap's models with the widest footprints, the lightest once simplified (some keep hundreds
## of triangles, the simplifier stops at UV seams): [light mesh, size, footprint m², box centre,
## material, triangles] each.
func _parts() -> Array:
	var out := []
	for i in _pile._part_mesh.size():
		var size: Vector3 = _pile._part_size[i]
		var dims := [size.x, size.y, size.z]
		dims.sort()
		out.append([i, size, dims[1] * dims[2], _pile._part_mid[i]])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[2] > y[2])
	out = out.slice(0, CANDIDATES)
	for o: Array in out:
		var low: Mesh = Pile._low_poly(_pile._part_mesh[o[0]], TRIS)
		var m := low.surface_get_material(0)
		if m is ShaderMaterial:
			m = m.duplicate()
			m.shader = FAR_SHADER  # its own haze, not the scene's solid fog
			m.set_shader_parameter("vertex_tint", true)
			_hazed.append(m)
		elif m is BaseMaterial3D:
			m = m.duplicate()
			m.vertex_color_use_as_albedo = true
		var tris := 0
		for s in low.get_surface_count():
			tris += low.surface_get_array_index_len(s) / 3
		o[0] = low
		o.append(m)
		o.append(tris)
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[5] < y[5])
	return out.slice(0, PARTS)
