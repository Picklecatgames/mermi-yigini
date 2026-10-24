extends RefCounted
## Dresses the range for tools/build_arena.gd (called from its _range): "POLİGON 7 – YIĞIN
## BÖLÜĞÜ", an old military range a crew took over to finish the pile. Two layers: the old
## institution's stencilled signs, inert ordnance and retired armour; and the crew's spray paint,
## posters, mats and gear. Everything hugs the walls or hangs overhead: the target zones
## (GameState.PLACE_ZONES) stay clear, and so does the east wall straight behind the targets.
## Colours: range yellow for safety only, signal orange-red for the unit, olive for the old army.
## Plan from the art-director and level-designer reviews of 2026-10-22.

const MODELS := "res://assets/env/models/"
const DECALS := "res://materials/env/decals/"
const YELLOW := Color(0.91, 0.71, 0.09)
const UNIT := Color(0.82, 0.27, 0.17)       # signal orange-red, the crew's colour
const OLIVE := Color(0.29, 0.32, 0.21)
const PRACTICE := Color(0.16, 0.27, 0.42)   # inert ordnance blue
const INK := Color(0.06, 0.06, 0.06)
const PAPER := Color(0.93, 0.9, 0.82)

var b  # the arena builder (tools/build_arena.gd): add, block, collide, worn, _prop, _decal...
var root: Node3D
var rng := RandomNumberGenerator.new()
var cloth: Material
var khaki: Material
var steel: Material
var wood: Material
var paint := {}  # colour name -> worn paint material
var _bags: Array[ArrayMesh] = []


func _init(builder) -> void:
	b = builder


func build(parent: Node) -> void:
	rng.seed = 77
	root = Node3D.new()
	root.name = "Dressing"
	b.add(root, parent)
	cloth = b.worn("sand_01", "cloth_olive", {"tint": Color(0.5, 0.56, 0.36), "tex_size": 0.5, "cell_size": 0.5, "grime": 0.4, "grime_scale": 0.8})
	khaki = b.worn("sand_01", "sandbag", {"tint": Color(0.86, 0.78, 0.6), "tex_size": 0.6, "cell_size": 0.5, "cell_tone": 0.12, "grime": 0.5, "grime_scale": 0.9})
	steel = b.worn("metal_plate_02", "scrap_steel", {"tint": Color(0.4, 0.41, 0.42), "tex_size": 0.8, "grime": 0.5, "rust": 0.6})
	wood = b.worn("plywood", "crate_wood", {"tint": Color(0.75, 0.66, 0.52), "tex_size": 0.6, "cell_size": 0.3, "cell_tone": 0.15, "grime": 0.5, "grime_scale": 1.0})
	var colours := {"blue": PRACTICE, "olive": OLIVE, "unit": UNIT, "black": Color(0.07, 0.07, 0.08)}
	for k: String in colours:
		var c: Color = colours[k] * 2.4  # the steel scan under the paint is dark
		paint[k] = b.worn("metal_plate_02", "paint_" + k, {"tint": Color(c.r, c.g, c.b), "tex_size": 0.6, "cell_size": 3.0, "grime": 0.35, "grime_scale": 1.5, "rust": 0.25})
	_bay_mouth()
	_firing_line()
	_ordnance_row()
	_armour_corner()
	_shooters_side()
	_flanks()
	_bay_detail()
	_posters()
	_workshop()
	_overhead()


# --- the bay mouth: the range's landmark --------------------------------------------------------

func _bay_mouth() -> void:
	# Header over the opening, on the hall's sheet wall: yellow board, black stencil, the unit's
	# emblem (a cartridge over the pile's triangle) in orange-red.
	var face := Basis(Vector3.UP, -PI / 2)  # +Z looks west, into the hall
	var at := Vector3(28.17, 4.78, 0)
	var header := Node3D.new()  # hidden from the placement overview: from above it floats over the bay
	header.name = "Header"
	b.add(header, root)
	header.transform = Transform3D(Basis(Vector3.RIGHT, 0.012), Vector3.ZERO).translated_local(Vector3.ZERO)  # one end's bolt gone: it sags
	b.block(Vector3(0.03, 0.95, 8.4), at, _flat(YELLOW.lerp(Color(0.7, 0.66, 0.55), 0.35), 0.75), header)
	for k in 4:  # dust, fading and rust over the board, a run under each bolt pair
		b.sign_grime(header, at + Vector3(-0.02, 0, -3.15 + k * 2.1), Vector3(-1, 0, 0), Vector2(2.1, 0.95))
	b.block(Vector3(0.035, 0.08, 8.4), at + Vector3(0, -0.44, 0), _flat(INK, 0.6), header)
	var tri := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 0.62, 0.02)
	tri.mesh = prism
	tri.material_override = _flat(UNIT, 0.5)
	tri.transform = Transform3D(face, at + Vector3(-0.025, -0.02, -3.45))
	b.add(tri, header)
	b.block(Vector3(0.03, 0.34, 0.11), at + Vector3(-0.04, 0.12, -3.45), _flat(Color(0.75, 0.55, 0.2), 0.35), header)  # the round
	for z in [-2.6, 2.6]:  # two small lamps washing the board from below
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(27.4, 3.95, z)
		lamp.basis = Basis.looking_at(Vector3(28.1, 4.8, z * 1.3) - lamp.position, Vector3.UP)
		lamp.light_color = Color(1.0, 0.93, 0.8)
		lamp.light_energy = 2.0
		lamp.spot_range = 3.5
		lamp.spot_angle = 50.0
		lamp.light_volumetric_fog_energy = 0.0
		b.add(lamp, header)
		b.block(Vector3(0.12, 0.08, 0.16), lamp.position, _flat(INK, 0.5), header)
	b.overhead(header)
	# Range status lamps either side of the mouth: the red one lit, the green one dark.
	for s in [-1.0, 1.0]:
		var p := Vector3(27.93, 3.25, s * 13.0)
		b.block(Vector3(0.12, 0.56, 0.62), p, _flat(INK, 0.5), root)
		b.block(Vector3(0.02, 0.2, 0.52), p + Vector3(-0.06, 0.12, 0), _glow(Color(1.0, 0.12, 0.06), 5.0), root)
		b.block(Vector3(0.02, 0.2, 0.52), p + Vector3(-0.06, -0.13, 0), _glow(Color(0.1, 0.5, 0.15), 0.25), root)
		var red := OmniLight3D.new()
		red.position = p + Vector3(-0.4, 0.12, 0)
		red.light_color = Color(1.0, 0.15, 0.08)
		red.light_energy = 0.6
		red.omni_range = 2.5
		red.light_volumetric_fog_energy = 0.0
		b.add(red, root)
		_flag(Vector3(27.45, 0, s * 13.9))
		_sandbags(Vector3(28.75, 0, s * 11.55), 3, 3, 0.0)  # inside the mouth, against the bay walls


## A red range flag on a pole.
func _flag(at: Vector3) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.018
	c.bottom_radius = 0.022
	c.height = 3.0
	b.add(_mesh(c, steel, Transform3D(Basis(), at + Vector3(0, 1.5, 0))), root)
	b.block(Vector3(0.3, 0.05, 0.3), at + Vector3(0, 0.025, 0), steel, root)
	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.75, 0.08, 0.05)
	cloth_mat.roughness = 0.9
	cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var flag := _mesh(_quad(Vector2(0.7, 0.45)), cloth_mat,
		Transform3D(Basis(Vector3.UP, PI / 2 + 0.3) * Basis(Vector3.FORWARD, 0.06), at + Vector3(-0.15, 2.72, 0.3 * signf(at.z))))
	b.add(flag, root)


# --- the firing line ----------------------------------------------------------------------------

func _firing_line() -> void:
	var west := Basis(Vector3.UP, -PI / 2)
	# Four shooting stations: rubber mats with taped numbers, brass all round them.
	var mat: Material = load("res://materials/env/rubber_floor.tres")
	var stations := [-18.0, -6.0, 6.0, 18.0]
	for i in stations.size():
		var z: float = stations[i]
		var m: MeshInstance3D = b.block(Vector3(2.4, 0.012, 1.5), Vector3(12.5, 0.006, z), mat, root)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.layers = 1 | b.FLOOR_PAINT
		var n: Label3D = b._range_label(str(i + 1), 220, Color(0.92, 0.9, 0.84, 0.9), b.STENCIL)
		n.transform = Transform3D(Basis(Vector3.UP, -PI / 2) * Basis(Vector3.RIGHT, -PI / 2), Vector3(11.65, 0.016, z))
		b.add(n, root)
	_brass(stations)


## Spent cases on the floor behind the railing: thick on the mats, thinning along the line.
func _brass(stations: Array) -> void:
	var shell: Mesh = load("res://assets/bullet/shell_45.res")
	var a := shell.get_aabb()
	var s := 0.023 / maxf(a.size.x, maxf(a.size.y, a.size.z))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = shell
	mm.instance_count = 520
	for i in mm.instance_count:
		var z: float
		var x: float
		if i < 360:  # round the stations
			z = stations[i % stations.size()] + rng.randfn(0.0, 0.9)
			x = 12.5 + rng.randfn(0.4, 0.6)
		else:
			z = rng.randf_range(-27.0, 27.0)
			x = rng.randf_range(11.0, 13.9)
		x = minf(x, 13.93)
		# Lying on its side, any way round: the long axis goes flat.
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var lay := spin * Basis(Vector3.RIGHT, PI / 2) if a.size.y >= maxf(a.size.x, a.size.z) else spin
		mm.set_instance_transform(i, Transform3D(lay.scaled(Vector3.ONE * s), Vector3(x, 0.006, z)))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Brass"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add(mi, root)


# --- target side, north: the old range's inert ordnance --------------------------------------

func _ordnance_row() -> void:
	var z := -27.0
	# Mortar rounds stood in a wooden rack.
	var rack := Vector3(16.3, 0, -27.45)
	b.block(Vector3(1.2, 0.04, 0.32), rack + Vector3(0, 0.02, 0), wood, root)
	b.block(Vector3(1.2, 0.04, 0.32), rack + Vector3(0, 0.3, 0), wood, root)
	for sx in [-0.55, 0.55]:
		b.block(Vector3(0.05, 0.34, 0.3), rack + Vector3(sx, 0.17, 0), wood, root)
	for k in 4:
		_round(_mortar_profile(), rack + Vector3(-0.39 + k * 0.26, 0.04, 0), Basis(Vector3.RIGHT, PI / 2), "blue" if k != 2 else "olive", 0.5)
	# Two artillery shells stood up, one lying.
	for k in 2:
		_round(_shell_profile(), Vector3(17.7 + k * 0.3, 0, -27.45), Basis(Vector3.RIGHT, PI / 2), "olive", 0.7)
	_round(_shell_profile(), Vector3(18.9, 0.078, -27.2), Basis(Vector3.UP, PI / 2 + 0.2), "blue", 0.0)
	# Stick grenades on an army crate.
	b._prop(root, MODELS + "wooden_military_crate/wooden_military_crate_1k.gltf", Vector3(19.9, 0, -27.4), 0.05)
	for k in 5:
		b._prop(root, MODELS + "stick_grenade/stick_grenade_1k.gltf", Vector3(19.4 + k * 0.2, 0.5, -27.4 + rng.randf_range(-0.1, 0.1)), rng.randf_range(-0.3, 0.3), 1.0, Basis(Vector3.FORWARD, PI / 2))
	# The big one: a practice bomb on its wheeled cradle, and a scorch under it.
	_cradle(Vector3(22.4, 0, z))
	_bomb(Vector3(22.4, 0.6, z), "blue")
	b._decal(root, _scorch(), Vector3(22.4, 0, z), 0.4, Vector3(2.6, 0.6, 1.6))
	# Another on wooden chocks, olive, older.
	for dx in [-0.6, 0.6]:
		b.block(Vector3(0.24, 0.12, 0.42), Vector3(25.2 + dx, 0.06, z - 0.1), wood, root)
	_bomb(Vector3(25.2, 0.12 + 0.137, z - 0.1), "olive", -0.15)
	_sandbags(Vector3(27.0, 0, -26.9), 3, 4, PI / 2)


func _mortar_profile() -> Array:
	return [Vector2(0, 0), Vector2(0.03, 0.02), Vector2(0.1, 0.038), Vector2(0.16, 0.041), Vector2(0.27, 0.041),
		Vector2(0.36, 0.025), Vector2(0.36, 0.012), Vector2(0.5, 0.012), Vector2(0.5, 0)]


func _shell_profile() -> Array:
	return [Vector2(0, 0), Vector2(0.08, 0.035), Vector2(0.2, 0.065), Vector2(0.3, 0.077), Vector2(0.6, 0.077),
		Vector2(0.6, 0.08), Vector2(0.64, 0.08), Vector2(0.64, 0.072), Vector2(0.7, 0.07), Vector2(0.7, 0)]


## A round turned from `profile` (along +Z, nose at 0) at `at` turned by `basis`, painted `colour`
## with a unit-coloured band; `stand` > 0 stands it nose up on the floor, that tall.
func _round(profile: Array, at: Vector3, basis: Basis, colour: String, stand: float) -> void:
	var xf := Transform3D(basis, at + Vector3(0, stand, 0))
	b.add(_mesh(_lathe(profile), paint[colour], xf), root)
	var mid: float = profile[profile.size() / 2].x
	var r := 0.0
	for p: Vector2 in profile:
		r = maxf(r, p.y)
	b.add(_mesh(_lathe([Vector2(mid - 0.02, 0), Vector2(mid - 0.02, r + 0.002), Vector2(mid + 0.02, r + 0.002), Vector2(mid + 0.02, 0)]), paint.unit, xf), root)


## An aircraft practice bomb lying along x, nose west: body, two unit bands, lugs, four tail fins.
func _bomb(at: Vector3, colour: String, yaw := 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.UP, PI / 2), at)
	var body := _lathe([Vector2(0, 0), Vector2(0.05, 0.04), Vector2(0.2, 0.09), Vector2(0.45, 0.125), Vector2(0.7, 0.137),
		Vector2(1.55, 0.137), Vector2(1.85, 0.11), Vector2(2.05, 0.075), Vector2(2.08, 0)])
	b.add(_mesh(body, paint[colour], xf * Transform3D(Basis(), Vector3(0, 0, -1.04))), root)
	for z0 in [-0.48, -0.36]:
		var band := _lathe([Vector2(0, 0), Vector2(0, 0.14), Vector2(0.05, 0.14), Vector2(0.05, 0)])
		b.add(_mesh(band, paint.unit, xf * Transform3D(Basis(), Vector3(0, 0, z0))), root)
	for zl in [-0.25, 0.25]:  # lifting lugs on top
		b.block(Vector3(0.03, 0.05, 0.06), xf * Vector3(0, 0.155, zl), steel, root, xf.basis)
	for k in 4:  # tail fins
		var turn := Basis(Vector3.BACK, PI / 4 + k * PI / 2)
		b.block(Vector3(0.006, 0.17, 0.36), xf * (turn * Vector3(0, 0.15, 0.82)), paint[colour], root, xf.basis * turn)


## A low wheeled steel cradle for the bomb on the north wall.
func _cradle(at: Vector3) -> void:
	for sz in [-0.22, 0.22]:
		b.block(Vector3(1.9, 0.06, 0.06), at + Vector3(0, 0.3, sz), paint.black, root)
	var tyre := _flat(Color(0.05, 0.05, 0.05), 0.85)
	for sx in [-0.6, 0.6]:
		b.block(Vector3(0.06, 0.06, 0.5), at + Vector3(sx, 0.3, 0), paint.black, root)
		for sz in [-0.13, 0.13]:  # the V saddle
			b.block(Vector3(0.05, 0.26, 0.04), at + Vector3(sx, 0.41, sz), paint.black, root, Basis(Vector3.RIGHT, 0.7 * signf(sz)))
		for sz in [-0.26, 0.26]:
			var c := CylinderMesh.new()
			c.top_radius = 0.11
			c.bottom_radius = 0.11
			c.height = 0.06
			b.add(_mesh(c, tyre, Transform3D(Basis(Vector3.RIGHT, PI / 2), at + Vector3(sx * 1.4, 0.11, sz))), root)
	b.block(Vector3(0.6, 0.04, 0.04), at + Vector3(-1.2, 0.2, 0), paint.black, root, Basis(Vector3.BACK, 0.25))  # tow bar
	var body := StaticBody3D.new()
	b.add(body, root)
	b.collide(Vector3(2.4, 0.8, 0.6), at + Vector3(0, 0.4, 0), body)


# --- target side, south: retired armour --------------------------------------------------------

func _armour_corner() -> void:
	var z := 27.3
	b._prop(root, MODELS + "worn_metal_rack/worn_metal_rack_1k.gltf", Vector3(17.2, 0, z), PI)
	b._prop(root, MODELS + "worn_metal_rack/worn_metal_rack_1k.gltf", Vector3(18.2, 0, z), PI)
	for k in 3:  # helmets on the shelves
		_helmet(Vector3(16.95 + k * 0.25, [0.62, 1.22, 0.62][k], z - 0.02), rng.randf() * TAU)
	_helmet(Vector3(18.0, 1.22, z), 0.6)
	b._prop(root, MODELS + "old_gas_mask/old_gas_mask_1k.gltf", Vector3(18.35, 1.2, z + 0.05), PI + 0.4)
	for k in 4:  # plate carriers hanging on the wall beside the racks
		_vest(Vector3(19.3 + k * 0.55, 1.45 - (k % 2) * 0.04, 27.9), rng.randf_range(-0.08, 0.08))
	# A ballistic shield leaning on the wall, boots and a tyre on the floor.
	var shield := Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -0.2), Vector3(21.9, 0.52, 27.72))
	b.add(_mesh(b._stone_block(Vector3(0.56, 1.05, 0.035), 91, 0.03, 0.002), paint.black, shield), root)
	b.block(Vector3(0.28, 0.07, 0.01), shield * Vector3(0, 0.33, 0.02), _flat(Color(0.2, 0.25, 0.28, 0.7), 0.1), root, shield.basis)
	b._prop(root, MODELS + "rubber_boots/rubber_boots_1k.gltf", Vector3(20.4, 0, 27.4), PI + 0.5)
	b._prop(root, MODELS + "old_tyre/old_tyre_1k.gltf", Vector3(23.4, 0, 27.3), 0.3)
	b._prop(root, MODELS + "cement_bag/cement_bag_1k.gltf", Vector3(24.4, 0, 27.4), 1.2)
	b._prop(root, MODELS + "cement_bag/cement_bag_1k.gltf", Vector3(24.5, 0.16, 27.35), 1.4)
	_sandbags(Vector3(27.0, 0, 26.9), 3, 3, PI / 2)


func _helmet(at: Vector3, yaw: float) -> void:
	var dome := SphereMesh.new()
	dome.radius = 0.135
	dome.height = 0.135
	dome.is_hemisphere = true
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.0, 0.85, 1.12)), at)
	b.add(_mesh(dome, paint.olive, xf), root)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.142
	rim.bottom_radius = 0.145
	rim.height = 0.012
	b.add(_mesh(rim, cloth, xf * Transform3D(Basis(), Vector3(0, 0.006, 0))), root)


## A plate carrier on a wall hook: padded front panel, three pouches, two shoulder straps.
func _vest(at: Vector3, roll: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.BACK, roll), at + Vector3(0, 0, -0.06))
	b.add(_mesh(b._stone_block(Vector3(0.34, 0.44, 0.07), rng.randi() % 1000, 0.03, 0.006), cloth, xf), root)
	for k in 3:
		b.block(Vector3(0.09, 0.12, 0.05), xf * Vector3(-0.11 + k * 0.11, -0.12, 0.055), cloth, root, xf.basis)
	for sx in [-0.11, 0.11]:
		b.block(Vector3(0.05, 0.14, 0.03), xf * Vector3(sx, 0.27, 0.01), cloth, root, xf.basis)
	b.block(Vector3(0.02, 0.02, 0.08), at + Vector3(0, 0.36, -0.03), steel, root)  # the hook


# --- shooters' side: the crew's corner ---------------------------------------------------------

func _shooters_side() -> void:
	# North wall: a pegboard of range gear over a shelf, the tool chest under it.
	b.block(Vector3(3.0, 1.15, 0.02), Vector3(10.8, 1.55, -27.98), load("res://materials/env/plywood_2.tres"), root)
	b.block(Vector3(3.0, 0.03, 0.3), Vector3(10.8, 1.0, -27.83), wood, root)
	b._prop(root, MODELS + "binoculars/binoculars_1k.gltf", Vector3(9.7, 1.02, -27.85), 0.3)
	b._prop(root, MODELS + "Megaphone_01/Megaphone_01_1k.gltf", Vector3(10.6, 1.02, -27.82), -0.4)
	b._prop(root, MODELS + "clipboard/clipboard_1k.gltf", Vector3(11.5, 1.02, -27.85), 0.1)
	b._prop(root, MODELS + "medical_box/medical_box_1k.gltf", Vector3(12.0, 1.02, -27.8), 0.0)
	b._prop(root, MODELS + "metal_tool_chest/metal_tool_chest_1k.gltf", Vector3(12.9, 0, -27.5), 0.0)
	b._prop(root, MODELS + "fire_alarm/fire_alarm_1k.gltf", Vector3(13.4, 1.45, -28.0), 0.0)


# --- east wall flanks, either side of the bay -----------------------------------------------

func _flanks() -> void:
	b._prop(root, MODELS + "old_military_compressor/old_military_compressor_1k.gltf", Vector3(27.1, 0, -23.6), -PI / 2)
	b._prop(root, MODELS + "propane_tank/propane_tank_1k.gltf", Vector3(27.55, 0, -25.6), 0.3)
	b._prop(root, MODELS + "propane_tank/propane_tank_1k.gltf", Vector3(27.6, 0, -25.05), 1.9)
	b._prop(root, MODELS + "wooden_military_crate/wooden_military_crate_1k.gltf", Vector3(27.35, 0, 21.6), PI / 2)
	b._prop(root, MODELS + "wooden_military_crate/wooden_military_crate_1k.gltf", Vector3(27.35, 0.46, 21.7), PI / 2 + 0.06)
	b._prop(root, MODELS + "metal_jerrycan_green/metal_jerrycan_green_1k.gltf", Vector3(27.5, 0, 23.4), PI / 2)
	b._prop(root, MODELS + "fire_alarm/fire_alarm_1k.gltf", Vector3(27.97, 1.45, 15.2), -PI / 2)
	# Burnt practice targets pinned to the plywood near the north-west corner of the range.
	for k in 3:
		_paper([], Vector3(15.5 + k * 0.8, 1.4 + rng.randf_range(-0.1, 0.1), -27.955), _wall(1.0), Vector2(0.55, 0.75), rng.randf_range(-0.06, 0.06), true)


# --- inside the bay ----------------------------------------------------------------------------

func _bay_detail() -> void:
	for s in [-1.0, 1.0]:
		# Shot-up steel plates leaning in the corners before the berm.
		for k in 2:
			var tilt := Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)) * Basis(Vector3.RIGHT, s * (0.25 + k * 0.1))
			b.block(Vector3(0.45 + k * 0.1, 0.6, 0.012), Vector3(39.5 + k * 0.5, 0.29, s * (11.75 - k * 0.05)), steel, root, tilt)
		# An old target frame half sunk into the berm's flank, an orange stake at its toe.
		var frame := Basis(Vector3.BACK, 0.35) * Basis(Vector3.UP, s * 0.3)
		var at := Vector3(42.2, 1.6, s * 10.2)
		for dz in [-0.45, 0.45]:
			b.block(Vector3(0.06, 1.6, 0.06), at + frame * Vector3(0, 0, dz), wood, root, frame)
		b.block(Vector3(0.03, 0.9, 1.0), at + frame * Vector3(-0.04, 0.35, 0), wood, root, frame)
		b.block(Vector3(0.04, 0.9, 0.04), Vector3(40.0, 0.45, s * 10.9), paint.unit, root)
		b.block(Vector3(0.045, 0.1, 0.045), Vector3(40.0, 0.75, s * 10.9), _flat(Color.WHITE, 0.6), root)
		# A cable tray with conduit along each wall, under the ceiling.
		var tray := Vector3((28.4 + 44.2) / 2.0, 3.5, s * 11.7)
		b.block(Vector3(15.8, 0.02, 0.3), tray, steel, root)
		b.block(Vector3(15.8, 0.08, 0.02), tray + Vector3(0, 0.04, -s * 0.14), steel, root)
		var wires := [INK, Color(0.15, 0.15, 0.17), Color(0.5, 0.18, 0.08)]
		for k in 3:
			var c := CylinderMesh.new()
			c.top_radius = 0.012 + k * 0.004
			c.bottom_radius = c.top_radius
			c.height = 15.8
			b.add(_mesh(c, _flat(wires[k], 0.6), Transform3D(Basis(Vector3.BACK, PI / 2), tray + Vector3(0, 0.03, s * (0.08 - k * 0.06)))), root)
		for k in 6:
			b.block(Vector3(0.02, 0.48, 0.02), Vector3(29.0 + k * 3.0, 3.75, s * 11.75), steel, root)
	# Forklift tyre tracks from the mouth to the berm, oil where it stood.
	var track: Texture2D = b._decal_tex("tyre_track", 64, 512, func(img: Image) -> void:
		for y in 512:
			for x in 64:
				var lug := fposmod(y + absf(x - 32) * 0.6, 24.0) < 13.0
				var a := (0.55 if lug else 0.25) * smoothstep(0.0, 6.0, minf(x, 63 - x)) * (0.6 + 0.4 * sin(y * 0.05))
				img.set_pixel(x, y, Color(0.03, 0.03, 0.03, a)))
	for z in [4.9, 6.1]:
		b._decal(root, track, Vector3(34.0, 0, z), PI / 2 + 0.02, Vector3(0.28, 0.6, 11.0))
	var stain: Texture2D = load(DECALS + "oil_stain.res")
	for p in [Vector3(38.6, 0, 5.4), Vector3(31.2, 0, -7.8), Vector3(27.6, 0, 9.5)]:
		b._decal(root, stain, p, rng.randf() * TAU, Vector3(1.4, 0.6, 1.0))
	# Bullet holes: the back wall above the berm, and round the columns on the lining.
	var holes := []
	for i in 4:
		holes.append(load(DECALS + "bullet_mark_0_%d.png" % i))
	for i in 46:
		_hole(holes, Vector3(44.29, rng.randf_range(3.0, 3.95), rng.randf_range(-11.5, 11.5)), Vector3.LEFT)
	for c in [Vector3(21.0, 0, -27.97), Vector3(21.0, 0, 27.97), Vector3(27.97, 0, -21.0), Vector3(27.97, 0, 21.0)]:
		var ns := absf(c.z) > 27.0  # on the north or south wall
		var n := Vector3(0, 0, -signf(c.z)) if ns else Vector3.LEFT
		var along := Vector3(1, 0, 0) if ns else Vector3(0, 0, 1)
		for i in 10:
			var off := rng.randf_range(0.25, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
			_hole(holes, c + along * off + Vector3(0, rng.randf_range(0.6, 2.2), 0), n)


func _hole(holes: Array, at: Vector3, normal: Vector3) -> void:
	var d := Decal.new()
	d.texture_albedo = holes[rng.randi() % holes.size()]
	var w := rng.randf_range(0.07, 0.11)
	d.size = Vector3(w, 0.1, w)
	var side := normal.cross(Vector3.UP).normalized()
	d.transform = Transform3D(Basis(side, normal, side.cross(normal)) * Basis(Vector3.UP, rng.randf() * TAU), at)
	d.cull_mask = 1
	b.add(d, root)


# --- posters: odd old public-information prints the crew taped up, on the shooters' side --------

func _posters() -> void:
	# Two crowded notice boards, years of notices pinned over each other, faded, torn, a few
	# hanging off or fallen; not posters spaced out one by one on a bare wall.
	_board(Vector3(5.4, 1.75, -27.97), _wall(1.0), ["fly_bomber", "john_not_dull", "dont_mix_em", "heat_ruins_ammo"])
	_board(Vector3(5.6, 1.75, 27.97), _wall(-1.0), ["firecrackers", "six_out_of_ten", "oops", "black_widow"])


## The upgrade workshop in the shooters' corner, where the railing meets the south wall: the bullet
## workbench (assembled in Blender, docs/ayrintilar.md "Mermi tezgâhı") a size up and pushed into the
## corner, the melting hopper on its right, both on a worn carpet. Round it the crew's corner: old
## ammunition posters taped up (Commons, public domain), a rifle and a pistol hung on the wall, a
## fire going in a barrel stove, crates and sandbags by the railing. Lit like a camp: one failing
## pendant, the barrel's fire and the crucible's glow.
func _workshop() -> void:
	const BENCH := 1.2  # the Blender bench, scaled up to stand out
	var at := Vector3(12.3, 0, 27.4)  # its east end against the column at x 14, its back on the wall
	b._prop(root, "res://assets/props/workbench/workbench.glb", at, PI, BENCH)
	var x := at.x - 0.09 * BENCH  # the bench's middle
	var hopper := Vector3(at.x - 1.22 * BENCH - 1.0, 0, 27.15)  # on its right (looking at it), the bucket on the bench side
	b._prop(root, "res://assets/props/workbench/hopper.glb", hopper, PI)
	var rug := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.6, 2.6)
	rug.mesh = plane
	rug.material_override = b.pbr_box("dirty_carpet", 0.6, Color.WHITE, false)  # the scan is 0.6 m square
	rug.transform = Transform3D(Basis(Vector3.UP, 0.03), Vector3(11.3, 0.006, 26.3))
	rug.layers = 1 << 4  # off the floor paint's layer: the walkway decal printed over it
	b.add(rug, root)
	# The wall behind: posters over the bench's shelf and round the hopper, guns on nails.
	var face := _wall(-1.0)
	for pz in [["fifty_cal", Vector3(x, 2.85, 27.96), 0.66, 0.02], ["both_barrels", Vector3(11.0, 2.7, 27.955), 0.6, -0.04],
			["bonds_bullets", Vector3(13.5, 2.75, 27.955), 0.7, 0.03], ["pass_ammo", Vector3(9.85, 2.0, 27.96), 0.85, -0.02],
			["keep_shooting", Vector3(9.1, 2.15, 27.955), 0.9, 0.05], ["keep_firing", Vector3(8.2, 1.65, 27.96), 0.75, -0.03]]:
		_poster(pz[0], pz[1], face, pz[2], pz[3])
	b._prop(root, MODELS + "bolt_action_rifle_7_62/bolt_action_rifle_7_62_1k.gltf", Vector3(10.25, 1.3, 27.9), 0.04)
	b._prop(root, MODELS + "service_pistol/service_pistol_1k.gltf", Vector3(10.55, 1.75, 27.94), -0.3)
	# A fire in a barrel west of the hopper, a jerrycan and a tyre by it.
	var barrel := Vector3(8.7, 0, 27.0)
	b._prop(root, MODELS + "barrel_stove/barrel_stove_1k.gltf", barrel, 0.4)
	b._prop(root, MODELS + "metal_jerrycan/metal_jerrycan_1k.gltf", Vector3(8.0, 0, 27.65), 0.2)
	b._prop(root, MODELS + "old_tyre/old_tyre_1k.gltf", Vector3(7.75, 0.3, 27.82), 0.0, 1.0, Basis(Vector3.RIGHT, -0.15))
	# Stock along the railing: an army crate, a crate of rounds on it, ammo boxes, sandbags.
	b._prop(root, MODELS + "wooden_military_crate/wooden_military_crate_1k.gltf", Vector3(13.45, 0, 25.4), PI / 2)
	b._prop(root, MODELS + "wooden_crate_01/wooden_crate_01_1k.gltf", Vector3(13.45, 0.465, 25.6), 0.15)
	for p in [Vector3(13.45, 0.465, 25.05), Vector3(13.4, 0.815, 25.6)]:
		b._prop(root, MODELS + "ammo_box/ammo_box_1k.gltf", p, PI / 2 + rng.randf_range(-0.4, 0.4))
	_sandbags(Vector3(13.45, 0, 24.1), 2, 2, PI / 2)
	_sticker("ghs_explos", Vector3(13.1, 0.25, 25.4), Vector3(-1, 0, 0), 0.18)
	_sticker("ghs_flamme", Vector3(hopper.x, 0.72, 26.78), Vector3(0, 0, -1), 0.14)
	# Light: a steady pendant over the corner's middle, the barrel's fire, the crucible's glow, a dim
	# wash. The hall lamps round it are dead (build_arena _lamps): a warm island in the dark.
	var mid: float = b.WORKSHOP.x
	b.strut(mid, 21.0, 27.85)
	b.pendant(Vector3(mid, 5.0, 26.9), b.BOTTOM - b.CHORD / 2.0 - 0.065, Color(1.0, 0.68, 0.38), 5.0, 62.0, 0.05, true)
	for f in [[barrel + Vector3(0, 1.0, 0), Color(1.0, 0.45, 0.15), 2.2, 4.5, true], [hopper + Vector3(0, 0.3, 0), Color(1.0, 0.5, 0.2), 0.8, 1.8, false]]:
		var fire := OmniLight3D.new()
		fire.position = f[0]
		fire.light_color = f[1]
		fire.light_energy = f[2]
		fire.omni_range = f[3]
		fire.shadow_enabled = f[4]
		fire.light_volumetric_fog_energy = 0.6
		b.add(fire, root)
	var wash := SpotLight3D.new()
	wash.position = Vector3(8.6, 4.6, 23.6)
	wash.basis = Basis.looking_at(Vector3(x - 0.8, 1.6, 27.9) - wash.position, Vector3.UP)
	wash.light_color = Color(1.0, 0.72, 0.42)
	wash.light_energy = 2.2
	wash.spot_range = 10.0
	wash.spot_angle = 30.0
	wash.spot_angle_attenuation = 1.8
	wash.light_volumetric_fog_energy = 0.0
	wash.shadow_enabled = true
	b.add(wash, root)


## A GHS hazard sticker (assets/env/stickers/, public domain) on the face at `at` looking along `out`.
func _sticker(id: String, at: Vector3, out: Vector3, size: float) -> void:
	var d := Decal.new()
	d.texture_albedo = load("res://assets/env/stickers/" + id + ".png")
	d.modulate = Color(0.85, 0.82, 0.75)  # sun and grime
	d.size = Vector3(size, 0.4, size)
	d.transform = Transform3D(Basis(out.cross(Vector3.UP), out, Vector3.DOWN), at)
	d.cull_mask = 1
	b.add(d, root)


## A 3.2 x 1.5 m pin board: posters and papers overlapping, scraps of torn-off ones, one poster
## peeled half off the board, one fallen to the floor under it.
func _board(at: Vector3, face: Basis, posters: Array) -> void:
	var out := face * Vector3(0, 0, 1)
	var cork: Material = b.worn("plywood", "board_cork", {"tint": Color(0.66, 0.6, 0.52), "tex_size": 0.8, "cell_size": 4.0, "grime": 0.6, "grime_scale": 1.2})
	b.block(Vector3(3.6, 1.8, 0.025), at + out * 0.0125, cork, root, face)
	for e in [[Vector3(0, 0.92, 0), Vector3(3.68, 0.05, 0.04)], [Vector3(0, -0.92, 0), Vector3(3.68, 0.05, 0.04)],
			[Vector3(1.82, 0, 0), Vector3(0.05, 1.88, 0.04)], [Vector3(-1.82, 0, 0), Vector3(0.05, 1.88, 0.04)]]:
		b.block(e[1], at + out * 0.02 + face * e[0], wood, root, face)
	var z := 0.028
	for k in 6:  # scraps left where older sheets were torn off
		var p := Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(-0.6, 0.6), 0)
		b.add(_sheet(Vector2(rng.randf_range(0.08, 0.2), rng.randf_range(0.06, 0.16)), _aged_paper(),
			Transform3D(face * Basis(Vector3.BACK, rng.randf_range(-0.5, 0.5)), at + face * p + out * z)), root)
	var slots := [Vector3(-1.2, 0.1, 0), Vector3(-0.3, 0.18, 0), Vector3(0.62, -0.04, 0), Vector3(1.35, 0.22, 0)]
	for i in posters.size():
		z += 0.003
		var h := rng.randf_range(0.95, 1.2)
		var m := _aged_poster(posters[i])
		var tex: Texture2D = m.albedo_texture
		var size := Vector2(h * tex.get_width() / tex.get_height(), h)
		var sx := clampf(slots[i].x, -1.75 + size.x / 2.0, 1.75 - size.x / 2.0)  # never past the frame
		var p: Vector3 = at + face * Vector3(sx, slots[i].y, 0) + out * z
		if i == 2:  # this one's bottom pins are gone: it hangs off the board from the top
			var hinge := p + face * Vector3(0, size.y / 2.0, 0)
			var xf := Transform3D(face * Basis(Vector3.RIGHT, -0.32) * Basis(Vector3.BACK, 0.05), hinge)
			b.add(_sheet(size, m, xf * Transform3D(Basis(), Vector3(0, -size.y / 2.0, 0))), root)
			continue
		_taped(m, p, face, size, rng.randf_range(-0.05, 0.05))
	for k in 4:  # notices over and between them
		z += 0.003
		_paper([], at + face * Vector3(rng.randf_range(-1.45, 1.45), rng.randf_range(-0.5, 0.55), 0) + out * z, face,
			Vector2(0.21, 0.297), rng.randf_range(-0.12, 0.12), k == 1)
	# The one that came down, lying curled at the wall foot.
	var fallen := _aged_poster(posters[0])
	var floor_at := Vector3(at.x + 1.9, 0.004, at.z) + out * 0.5
	b.add(_sheet(Vector2(0.55, 0.75), fallen, Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, -PI / 2), floor_at)), root)


# --- overhead: ducts fill the black void under the roof ---------------------------------------

func _overhead() -> void:
	const SET := "modular_airduct_rectangular_01"
	var run := _piece(SET, SET + "_tripple_01", "duct_run")
	var joint := _piece(SET, SET + "_connector_01", "duct_joint")
	var wire := _piece(SET, SET + "_brace_wire_01", "duct_wire")
	# One run along the hall over the shooters, one across the range near the north wall. The long
	# run sits halfway between the hall lamps' rows at x 6 and 12; at x 6.5 they hung inside it.
	for r in [[Vector3(9.0, 6.9, -26.0), Basis(), 29], [Vector3(9.4, 6.6, -24.6), Basis(Vector3.UP, PI / 2), 11]]:
		var start: Vector3 = r[0]
		var basis: Basis = r[1]
		for k in r[2]:
			var at := start + basis * Vector3(0, 0, k * 1.8)
			for m in [_mesh(run, null, Transform3D(basis, at)), _mesh(joint, null, Transform3D(basis, at)),
					_mesh(wire, null, Transform3D(basis, at + basis * Vector3(0, 0.75, 0.9))) if k % 2 == 0 else null]:
				if m:
					b.add(m, root)
					b.overhead(m)  # the placement overview looks past the ducts


## One node's mesh out of a Poly Haven set, saved on its own (the arena can't point into a glTF).
func _piece(slug: String, node: String, out: String) -> Mesh:
	var path := MODELS + "%s/%s.res" % [slug, out]
	var scene: Node = (load(MODELS + "%s/%s_1k.gltf" % [slug, slug]) as PackedScene).instantiate()
	var src := scene.find_child(node, true, false) as MeshInstance3D
	var mesh: Mesh = src.mesh.duplicate()
	scene.free()
	ResourceSaver.save(mesh, path)
	return load(path)


# --- shared bits -------------------------------------------------------------------------------

## The basis for something flat on a north (+1: faces +z) or south (-1: faces -z) wall face.
func _wall(facing: float) -> Basis:
	return Basis() if facing > 0 else Basis(Vector3.UP, PI)


func _wall_east() -> Basis:
	return Basis(Vector3.UP, -PI / 2)


## A paper poster taped on: a yellowed sheet, dark text, a shot-up target drawn on it if `target`.
func _paper(lines: Array, at: Vector3, face: Basis, size: Vector2, roll: float, target := false) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _paper_tex(target)
	m.roughness = 0.9
	if target:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR  # burnt-through holes
	var xf := _taped(m, at, face, size, roll)
	if lines.is_empty():
		return
	var area := Vector2(size.x * 0.85, size.y * (0.3 if target else 0.75))  # the target takes the bottom
	var l: Label3D = b._range_label("\n".join(lines), _fit(lines, area), Color(0.1, 0.09, 0.08, 0.92), b.STENCIL)
	l.transform = xf * Transform3D(Basis(), Vector3(0, size.y * (0.3 if target else 0.0), 0.003))
	b.add(l, root)


## A printed poster from assets/env/posters, `height` m tall, taped on like the papers.
func _poster(file: String, at: Vector3, face: Basis, height: float, roll: float) -> void:
	var m := _aged_poster(file)
	var tex: Texture2D = m.albedo_texture
	_taped(m, at, face, Vector2(height * tex.get_width() / tex.get_height(), height), roll)


## A poster gone old on the wall: sun-faded toward the paper, yellowed, water stains, damp
## blooms, fold lines, corners and edges torn away. Drawn once into materials/env/decals.
func _aged_poster(file: String) -> StandardMaterial3D:
	var path := DECALS + "aged_%s.res" % file
	if not ResourceLoader.exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/env/posters/%s.jpg" % file))
		var w := 384
		var h := int(384.0 * img.get_height() / img.get_width())
		img.resize(w, h)
		img.convert(Image.FORMAT_RGBA8)
		var n := FastNoiseLite.new()
		n.seed = file.hash() & 0xffff
		n.frequency = 0.012
		n.fractal_octaves = 5
		var torn_corner := (file.hash() >> 3) % 4
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				var g := n.get_noise_2d(x, y)
				c = c.lerp(Color(0.86, 0.8, 0.64), 0.32 + 0.12 * g)  # faded and yellowed
				var stain := smoothstep(0.25, 0.45, n.get_noise_2d(x * 0.6 + 500.0, y * 0.6))
				c = c.lerp(Color(0.55, 0.45, 0.3), stain * 0.35)  # water stains with a darker tide line
				if absf(n.get_noise_2d(x * 0.6 + 500.0, y * 0.6) - 0.25) < 0.012:
					c = c.darkened(0.25)
				if absi(y - h / 2) < 1 or absi(x - w / 2) < 1:
					c = c.darkened(0.12)  # fold lines
				var edge := minf(minf(x, w - 1 - x), minf(y, h - 1 - y))
				var rag := 6.0 + 10.0 * (n.get_noise_2d(x * 3.0, y * 3.0) + 0.5)
				var corner := Vector2(0 if torn_corner % 2 == 0 else w, 0 if torn_corner < 2 else h)
				var gone := edge < rag * 0.5 or Vector2(x, y).distance_to(corner) < 70.0 + 40.0 * g
				c = c.darkened(0.25 * smoothstep(rag * 3.0, 0.0, edge))  # grimy edges
				c.a = 0.0 if gone else 1.0
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
		var tex := PortableCompressedTexture2D.new()
		tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		ResourceSaver.save(tex, path)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = Color(0.85, 0.83, 0.78)
	m.roughness = 0.9
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _aged_paper() -> StandardMaterial3D:
	var m := _flat(PAPER.darkened(0.25), 0.9)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A sheet of `m` with tape on its corners; returns its transform.
func _taped(m: Material, at: Vector3, face: Basis, size: Vector2, roll: float) -> Transform3D:
	var xf := Transform3D(face * Basis(Vector3.BACK, roll), at)
	b.add(_sheet(size, m, xf), root)
	for c in [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]:  # tape
		b.add(_sheet(Vector2(0.09, 0.035), _flat(Color(0.85, 0.82, 0.7, 0.85), 0.6),
			xf * Transform3D(Basis(Vector3.BACK, c.x * c.y * 0.6), Vector3(c.x * size.x * 0.46, c.y * size.y * 0.46, 0.002))), root)
	return xf


## The font size that fits `lines` of stencil inside `area` (m) at _range_label's pixel size.
func _fit(lines: Array, area: Vector2) -> int:
	const PX := 0.0035
	var longest := 1
	for t: String in lines:
		longest = maxi(longest, t.length())
	return int(minf(area.x / (longest * 0.62 * PX), area.y / (lines.size() * 1.3 * PX)))


func _paper_tex(target: bool) -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 4 if target else 9
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	return b._decal_tex("poster_target" if target else "poster_plain", 256, 352, func(img: Image) -> void:
		for y in 352:
			for x in 256:
				var n := noise.get_noise_2d(x, y)
				var edge := minf(minf(x, 255 - x), minf(y, 351 - y))
				var c := PAPER.darkened(0.08 + 0.12 * n + 0.1 * smoothstep(40.0, 0.0, edge))
				if target:  # rings round a red centre, burnt through in places
					var r := Vector2(x - 128, y - 230).length()
					if fposmod(r, 22.0) < 2.5 and r < 110.0:
						c = Color(0.1, 0.1, 0.1)
					if r < 11.0:
						c = Color(0.75, 0.1, 0.06)
					if n > 0.42 and r < 105.0:
						c = Color(0.03, 0.02, 0.02, 0.0)
				img.set_pixel(x, y, c))


func _scorch() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 13
	noise.frequency = 0.03
	return b._decal_tex("scorch", 256, 256, func(img: Image) -> void:
		for y in 256:
			for x in 256:
				var r := Vector2(x - 128, y - 128).length() / 128.0
				var a := clampf((1.0 - r) * 1.6 + noise.get_noise_2d(x, y) * 0.6, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.02, 0.02, 0.02, a * 0.7)))


## Sandbags in brick bond: `across` bags a course, `courses` high, the row turned by `yaw`.
func _sandbags(at: Vector3, across: int, courses: int, yaw: float) -> void:
	if _bags.is_empty():  # six lumpy bags shared by every stack
		for i in 6:
			_bags.append(b._stone_block(Vector3(0.5, 0.15, 0.28), 300 + i, 0.06, 0.012))
	var basis := Basis(Vector3.UP, yaw)
	for c in courses:
		var n := across - (c % 2)
		for i in n:
			var lx := (i - (n - 1) / 2.0) * 0.5
			var bag: ArrayMesh = _bags[rng.randi() % _bags.size()]
			var xf := Transform3D(basis * Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)), at + basis * Vector3(lx, 0.075 + c * 0.14, rng.randf_range(-0.03, 0.03)))
			b.add(_mesh(bag, khaki, xf), root)
	var body := StaticBody3D.new()
	b.add(body, root)
	b.collide(Vector3(across * 0.5, courses * 0.14 + 0.02, 0.32), at + Vector3(0, courses * 0.07, 0), body, basis)


## A surface of revolution round +Z from (z, radius) points, nose to tail.
static func _lathe(profile: Array, segs := 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var c: Vector2 = profile[i + 1]
		for k in segs:
			var t0 := TAU * k / segs
			var t1 := TAU * (k + 1) / segs
			var p00 := Vector3(cos(t0) * a.y, sin(t0) * a.y, a.x)
			var p01 := Vector3(cos(t1) * a.y, sin(t1) * a.y, a.x)
			var p10 := Vector3(cos(t0) * c.y, sin(t0) * c.y, c.x)
			var p11 := Vector3(cos(t1) * c.y, sin(t1) * c.y, c.x)
			for v in [p00, p10, p11, p00, p11, p01]:  # (C-A)x(B-A) points out, as in _stone_block
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	return st.commit()


func _mesh(mesh: Mesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	if mat:
		m.material_override = mat
	m.transform = xf
	return m


## A sheet of paper or tape: off layer 1 so the walls' leak, grime and tag decals don't print
## over it, and no shadow, or sheets 3 mm apart shade each other in bands.
func _sheet(size: Vector2, mat: Material, xf: Transform3D) -> MeshInstance3D:
	var m := _mesh(_quad(size), mat, xf)
	m.layers = 1 << 4
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _quad(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	return q


func _flat(colour: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	if colour.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var m := _flat(colour, 0.3)
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	return m
