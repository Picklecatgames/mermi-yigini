extends SceneTree
## Builds scenes/arena.tscn: the range shed (beveled precast walls, H columns, trusses, purlins,
## corrugated roof with skylights, gable cladding), ceiling LED battens, props, floor paint and stains,
## four co-op spawn points, the crate stands and the stage spots; closed and dark, no sky or sun. Re-run after changing tools/build_shed_meshes.py output or these numbers:
##   godot --headless --path . -s res://tools/build_arena.gd
## Dimensions must match tools/build_shed_meshes.py.

const SHED := "res://assets/env/shed/"
const TEX := "res://assets/env/textures/"
const MODELS := "res://assets/env/models/"
const HALF_SPAN := 27.7
const EAVE := 8.8
const BOTTOM := 8.0
const PITCH := deg_to_rad(6.0)
const CHORD := 0.18
const COLUMN_H := 8.95
const BAYS: Array[float] = [-27.85, -21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0, 27.85]
const LAMP_SPAN := 24.0  # ceiling battens from -LAMP_SPAN to +LAMP_SPAN along each truss
const LAMP_STEP := 6.0
const LAMP_ENERGY := 0.9  # dim working light: the heap's own spots must stay the brightest thing
const LAMP_HEAP_CLEAR := 9.0  # m round the heap with no battens, so it stands in its own light
const DECALS := "res://materials/env/decals/"
## Co-op spawns along the south wall, everyone facing the heap.
const SPAWNS: Array[Vector3] = [Vector3(-4.5, 0, 23.5), Vector3(-1.5, 0, 23.5), Vector3(1.5, 0, 23.5), Vector3(4.5, 0, 23.5)]
## Crate stands west of the heap, a row running north and centred on the hall: levels 1-11 on
## stands STAND_GAP apart (1, the worst crate, on bare floor), then a gap and level 12, the final
## crate, on the floor in a big square under two crossing stage spots. Stand tiers follow the
## keys: 4 common, 5 rare, 2 legendary + the final. Tops climb on an ease-in curve to STAND_TOP,
## well under the 1.6 m eye so the crate on top still shows.
const CHEST_X := -20.0  # halfway between the heap's paint ring and the west wall
const CHEST_COUNT := 12
const STAND_GAP := 3.0
const FINAL_GAP := 4.5  # level 11 to level 12, room for the big square
const FINAL_SQUARE := 4.2  # m
const STAND_TOP := 1.1  # m, level 11's top
const RARE_FROM := 4  # index of the first rare stand; legendary from LEGEND_FROM
const LEGEND_FROM := 9


## Where crate `i` (0 = level 1) stands: the row is centred on z = 0.
static func chest_pos(i: int) -> Vector3:
	var span := STAND_GAP * (CHEST_COUNT - 2) + FINAL_GAP
	var z := span / 2.0 - STAND_GAP * mini(i, CHEST_COUNT - 2) - (FINAL_GAP if i == CHEST_COUNT - 1 else 0.0)
	return Vector3(CHEST_X, 0, z)

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
	_heap_spot()
	_final_spots()
	_upper_walls()
	_props()
	_firing_line()
	_chest_stands()
	_markings()
	_spawns()
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
	# A closed, dark hall: no sky at all, so nothing outside can leak in through the GI, the
	# reflections or the fog. Every bit of light is a lamp or spot we placed.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR  # faint fill: the roof and corners never go pitch black
	env.ambient_light_color = Color(0.62, 0.6, 0.56)
	env.ambient_light_energy = 0.15
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED  # the probe below covers it
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.sdfgi_enabled = true  # bounce light from the lamps and spots
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_cascades = 4
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.3
	env.volumetric_fog_enabled = true  # dust in the air: the lamp cones and spot beams show in it
	env.volumetric_fog_density = 0.002  # a light haze; thicker turned every beam into a grey wedge
	env.volumetric_fog_albedo = Color(0.92, 0.9, 0.86)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add(we)

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
	# The skylight strips are sheeted over too: the hall is closed and dark, lit only from inside.
	var shut := mesh_at("skylight", Transform3D(), load("res://materials/env/corrugated_iron_02.tres"), roof)
	shut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	var clad: Material = load("res://materials/env/corrugated_iron_02.tres")
	for s in [-1.0, 1.0]:
		var g := mesh_at("gable_cladding", Transform3D(Basis(), Vector3(0, 0, s * 28.3)), clad, roof)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED


## LED battens bolted flat under every truss's bottom chord, LAMP_STEP apart: a slim housing with a
## glowing diffuser underneath and one wide, soft, shadowless light each. Many and even, so the
## hall reads bright and the roof catches their bounce; none of them light the dust.
func _lamps() -> void:
	var lamps := Node3D.new()
	lamps.name = "Lamps"
	add(lamps)
	var housing := BoxMesh.new()
	housing.size = Vector3(1.5, 0.07, 0.24)
	var diffuser := BoxMesh.new()
	diffuser.size = Vector3(1.42, 0.012, 0.18)
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(1.0, 0.97, 0.92)
	lens.emission_enabled = true
	lens.emission = Color(1.0, 0.95, 0.86)
	lens.emission_energy_multiplier = 2.5  # a soft strip, no glare
	ResourceSaver.save(lens, "res://materials/env/lamp_diffuser.tres")
	lens = load("res://materials/env/lamp_diffuser.tres")
	var paint: Material = load("res://materials/env/metal_plate_02.tres")
	var y := BOTTOM - CHORD / 2
	for z in BAYS.slice(1, BAYS.size() - 1):
		var x := -LAMP_SPAN
		while x <= LAMP_SPAN + 0.01:
			var near_spot := false
			for s in HEAP_SPOTS + [Vector3(CHEST_X, 0, -14), Vector3(CHEST_X, 0, -21)]:
				near_spot = near_spot or (absf(s.z - z) < 0.1 and absf(s.x - x) < 1.4)
			near_spot = near_spot or Vector2(x, z).length() < LAMP_HEAP_CLEAR
			if not near_spot:  # the stage spots' clamps sit on these chords
				var lamp := Node3D.new()
				lamp.position = Vector3(x, y, z)
				add(lamp, lamps)
				var h := MeshInstance3D.new()
				h.mesh = housing
				h.material_override = paint
				h.position.y = -0.035
				add(h, lamp)
				var d := MeshInstance3D.new()
				d.mesh = diffuser
				d.material_override = lens
				d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				d.position.y = -0.076
				add(d, lamp)
				var spot := SpotLight3D.new()
				spot.position.y = -0.1
				spot.rotation.x = -PI / 2
				spot.light_color = Color(1.0, 0.95, 0.88)  # neutral-warm 4000 K
				spot.light_energy = LAMP_ENERGY
				spot.spot_range = 14.0
				spot.spot_attenuation = 0.6
				spot.spot_angle = 75.0
				spot.spot_angle_attenuation = 0.9  # soft falloff: neighbours blend, no rings on the floor
				spot.light_volumetric_fog_energy = 0.0  # no cones in the dust
				spot.shadow_enabled = false
				add(spot, lamp)
			x += LAMP_STEP


## The heap's lights: four theatre spots, one from each corner round it, clamped under the z = +-7
## trusses in place of the hall lamps there. Wide and soft-edged, crossing so the whole heap is
## washed in an even, calm light, with faint beams in the dust. No lamp hangs over the heap itself.
const HEAP_SPOTS: Array[Vector3] = [Vector3(-11, 0, 7), Vector3(11, 0, 7), Vector3(-11, 0, -7), Vector3(11, 0, -7)]
const HEAP_AIM := Vector3(0, 2.4, 0)  # a third up the ~7 m heap


func _heap_spot() -> void:
	for i in HEAP_SPOTS.size():
		var at := HEAP_SPOTS[i] + Vector3(0, BOTTOM - CHORD / 2 - 0.05, 0)
		_stage_spot("HeapSpot%d" % (i + 1), at, HEAP_AIM, 36.0, 11.0, 0.0, 1.0, 1.8)  # no beams: in the hall they read as solid grey wedges


## A theatre spot hanging from a truss at `at`, aimed at `aim`, with a visible beam cone.
## `angle` is the half angle, `strength` the beam cone's glow, `size` scales the fixture.
## `edge` is the angle attenuation: low is a hard theatre edge, high a soft wash.
func _stage_spot(spot_name: String, at: Vector3, aim: Vector3, angle: float, energy: float, strength: float, size := 1.0, edge := 0.12) -> void:
	var paint := ORMMaterial3D.new()  # black stage paint over the steel scan
	paint.albedo_texture = load(TEX + "metal_plate_02/metal_plate_02_diff_2k.jpg")
	paint.albedo_color = Color(0.09, 0.09, 0.1)
	paint.orm_texture = load(TEX + "metal_plate_02/metal_plate_02_arm_2k.jpg")
	paint.roughness = 0.55
	paint.metallic = 0.4
	ResourceSaver.save(paint, "res://materials/env/stage_paint.tres")
	paint = load("res://materials/env/stage_paint.tres")
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color.WHITE
	lens.emission_enabled = true
	lens.emission = Color.WHITE
	lens.emission_energy_multiplier = 8.0
	ResourceSaver.save(lens, "res://materials/env/stage_lens.tres")
	lens = load("res://materials/env/stage_lens.tres")
	var rig := Node3D.new()
	rig.name = spot_name
	rig.position = at
	rig.scale = Vector3.ONE * size
	add(rig)
	var part := func(parent: Node3D, mesh: Mesh, xf: Transform3D, mat: Material) -> void:
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.transform = xf
		m.material_override = mat
		add(m, parent)
	var cyl := func(r: float, h: float) -> CylinderMesh:
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = h
		c.radial_segments = 32
		return c
	var cube := func(size: Vector3) -> BoxMesh:
		var c := BoxMesh.new()
		c.size = size
		return c
	const PIVOT := 0.42  # m from the clamp down to the tilt axis
	# Clamp on the chord and the yoke: a U hanging from it, open downward.
	part.call(rig, cube.call(Vector3(0.12, 0.1, 0.22)), Transform3D(Basis(), Vector3.ZERO), paint)
	part.call(rig, cube.call(Vector3(0.6, 0.04, 0.06)), Transform3D(Basis(), Vector3(0, -0.07, 0)), paint)
	for sx in [-1.0, 1.0]:
		part.call(rig, cube.call(Vector3(0.03, PIVOT, 0.06)), Transform3D(Basis(), Vector3(sx * 0.285, -0.07 - PIVOT / 2, 0)), paint)
	# The head tilts on the yoke to look at the heap; its -Z is the beam.
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, -0.07 - PIVOT + 0.04, 0)
	add(head, rig)
	head.basis = Basis.looking_at(aim - (at + head.position * size), Vector3.UP)
	var along := Basis(Vector3.RIGHT, PI / 2)  # CylinderMesh stands on Y; lay it along Z
	part.call(head, cyl.call(0.21, 0.62), Transform3D(along, Vector3(0, 0, 0.02)), paint)
	part.call(head, cyl.call(0.17, 0.12), Transform3D(along, Vector3(0, 0, 0.39)), paint)  # lamp housing
	for k in 4:  # cooling fins round the lamp housing
		part.call(head, cyl.call(0.225, 0.012), Transform3D(along, Vector3(0, 0, 0.12 + k * 0.05)), paint)
	part.call(head, cyl.call(0.235, 0.07), Transform3D(along, Vector3(0, 0, -0.3)), paint)  # front bezel
	part.call(head, cyl.call(0.18, 0.01), Transform3D(along, Vector3(0, 0, -0.34)), lens)
	for sx in [-1.0, 1.0]:  # trunnions into the yoke arms
		part.call(head, cyl.call(0.03, 0.06), Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(sx * 0.245, 0, 0)), paint)
	# Barn doors: four flaps on the bezel, opened out a little, shaping the beam.
	for k in 4:
		var turn := Basis(Vector3.BACK, k * PI / 2)
		var flap := Transform3D(turn * Basis(Vector3.RIGHT, -0.45), turn * Vector3(0, 0.235, -0.335))
		part.call(head, cube.call(Vector3(0.4, 0.004, 0.2)), flap * Transform3D(Basis(), Vector3(0, 0, -0.1)), paint)
	var spot := SpotLight3D.new()
	spot.name = "Beam"
	spot.position = Vector3(0, 0, -0.36)  # at the lens; a SpotLight shines down its -Z
	spot.light_color = Color(1.0, 1.0, 1.0)  # stage white
	spot.light_energy = energy
	spot.spot_range = 20.0 / size
	spot.spot_attenuation = 0.2
	spot.spot_angle = angle
	spot.spot_angle_attenuation = edge
	spot.shadow_enabled = true
	spot.light_size = 0.05
	spot.light_volumetric_fog_energy = 8.0 * strength  # the beam shows in the dust as much as its cone
	add(spot, head)
	if strength <= 0.0:
		return
	# The beam itself: an open cone from the lens down to the heap, glowing white and fading.
	var length := ((aim - (at + head.position * size)).length() - 0.36 * size) / size  # in rig units; the arena is not in a tree yet
	var cone := CylinderMesh.new()
	cone.top_radius = 0.17  # the lens
	cone.bottom_radius = length * tan(deg_to_rad(spot.spot_angle))
	cone.height = length
	cone.radial_segments = 48
	cone.rings = 8
	cone.cap_top = false
	cone.cap_bottom = false
	var beam := ShaderMaterial.new()
	beam.shader = load("res://materials/light_cone.gdshader")
	beam.set_shader_parameter("strength", strength)
	beam.set_shader_parameter("edge_softness", 0.9 if edge < 1.0 else 2.4)  # a soft wash has no visible rim
	var m := MeshInstance3D.new()
	m.name = "BeamCone"
	m.mesh = cone
	m.material_override = beam
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# CylinderMesh stands on Y with its top up: turning +Y onto +Z puts the top on the lens and the
	# wide end down the beam (-Z).
	m.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, -0.36 - length / 2.0))
	add(m, head)


## The final crate's spots: two big stage spots from the trusses either side, crossing over its
## square, so the last crate stands in a wash of white; soft-edged, not a hard theatre ring.
func _final_spots() -> void:
	var target := chest_pos(CHEST_COUNT - 1) + Vector3(0, 0.6, 0)
	for z in [-14.0, -21.0]:
		var at := Vector3(CHEST_X, BOTTOM - CHORD / 2 - 0.05, z)
		_stage_spot("FinalSpot%d" % int(absf(z)), at, target, 22.0, 60.0, 0.4, 1.4, 1.6)


## A halo round crate `level`'s stand that grows up the row: a soft glow pooled on the floor and a
## column of light rising from it and fading out, faint and low at level 1, tall, bright and gold
## at 12. Both additive, no lights of their own. `radius` is the halo's, in m.
func _aura(parent: Node3D, level: int, radius: float) -> void:
	var k := float(level) / CHEST_COUNT  # 0.08 .. 1
	var colour := Color(0.8, 0.88, 1.0).lerp(Color(1.0, 0.78, 0.35), k)
	# Floor glow: a radial blob lying on the floor, just above the paint.
	var blob := GradientTexture2D.new()
	blob.width = 128
	blob.height = 128
	blob.fill = GradientTexture2D.FILL_RADIAL
	blob.fill_from = Vector2(0.5, 0.5)
	blob.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.45))
	blob.gradient = g
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_texture = blob
	glow.albedo_color = Color(colour, 0.12 + 0.75 * k * k)
	var floor_quad := QuadMesh.new()
	floor_quad.size = Vector2.ONE * radius * (2.2 + 1.2 * k)
	floor_quad.orientation = PlaneMesh.FACE_Y
	var f := MeshInstance3D.new()
	f.name = "AuraFloor"
	f.mesh = floor_quad
	f.material_override = glow
	f.position.y = 0.012
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(f, parent)
	# Column: an open cylinder of light, brightest at the floor and fading upward.
	var height := 0.8 + 4.2 * pow(k, 1.5)
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius * 0.85  # tips inward a little as it rises (flipped below)
	tube.height = height
	tube.radial_segments = 40
	tube.rings = 6
	tube.cap_top = false
	tube.cap_bottom = false
	var beam := ShaderMaterial.new()
	beam.shader = load("res://materials/light_cone.gdshader")
	beam.set_shader_parameter("color", Color(colour.r, colour.g, colour.b))
	beam.set_shader_parameter("strength", 0.04 + 0.4 * k * k)
	beam.set_shader_parameter("fade_power", 1.3)
	beam.set_shader_parameter("edge_softness", 2.0)
	var c := MeshInstance3D.new()
	c.name = "AuraColumn"
	c.mesh = tube
	c.material_override = beam
	# The shader is brightest at the mesh's top: turn it over so that end sits on the floor.
	c.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, height / 2.0, 0))
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(c, parent)


## Dust, glitter and gold flakes over crate `level`'s stand, more and richer each level: a few slow
## motes at level 1, a shimmering column at 11, a shower of gold at 12. `top` is the stand's top,
## `area` the painted square's side. Soft dot sprites drawn here, no texture files.
func _sparkle(parent: Node3D, level: int, top: float, area: float) -> void:
	var k := float(level) / CHEST_COUNT  # 0.08 .. 1
	var dot := GradientTexture2D.new()
	dot.width = 64
	dot.height = 64
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.6))
	dot.gradient = g
	var half := area / 2.0
	var emitter := func(fx_name: String, amount: int, life: float, box: Vector3, centre_y: float,
			vel: float, grav: float, size: Vector2, ramp: Gradient, additive: bool) -> void:
		if amount <= 0:
			return
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = box
		mat.direction = Vector3.UP
		mat.spread = 180.0
		mat.initial_velocity_min = vel * 0.3
		mat.initial_velocity_max = vel
		mat.gravity = Vector3(0, grav, 0)
		mat.damping_min = 0.2
		mat.damping_max = 0.6
		mat.scale_min = size.x
		mat.scale_max = size.y
		mat.angle_min = -180.0
		mat.angle_max = 180.0
		mat.angular_velocity_min = -90.0
		mat.angular_velocity_max = 90.0
		var cr := GradientTexture1D.new()
		cr.gradient = ramp
		mat.color_ramp = cr
		var draw := StandardMaterial3D.new()
		draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if additive:
			draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		draw.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		draw.billboard_keep_scale = true
		draw.vertex_color_use_as_albedo = true
		draw.albedo_texture = dot
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		quad.material = draw
		var p := GPUParticles3D.new()
		p.name = fx_name
		p.amount = amount
		p.lifetime = life
		p.preprocess = life  # already in the air when the hall loads
		p.process_material = mat
		p.draw_pass_1 = quad
		p.position = Vector3(0, centre_y, 0)
		p.visibility_aabb = AABB(-box - Vector3(1, 1, 1), box * 2.0 + Vector3(2, 4, 2))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add(p, parent)
	# Dust: soft motes hanging in the stand's light.
	var dust := Gradient.new()
	dust.set_color(0, Color(1, 0.97, 0.9, 0))
	dust.set_color(1, Color(1, 0.97, 0.9, 0))
	dust.add_point(0.3, Color(1, 0.97, 0.9, 0.35))
	dust.add_point(0.7, Color(1, 0.97, 0.9, 0.35))
	emitter.call("Dust", int(6 + 70 * pow(k, 1.4)), 7.0, Vector3(half * 0.8, 1.0, half * 0.8), top + 1.0,
		0.08, 0.01, Vector2(0.015, 0.04), dust, false)
	# Glitter: tiny points that twinkle on and off as they drift up, white turning gold up the row.
	var tint := Color(1.6, 1.6, 1.7).lerp(Color(2.6, 2.0, 0.9), k)  # above 1: they bloom
	var tw := Gradient.new()
	tw.set_color(0, Color(tint, 0))
	tw.set_color(1, Color(tint, 0))
	for j in 5:  # five flashes over a life
		tw.add_point(0.1 + j * 0.2, Color(tint, 1.0))
		tw.add_point(0.2 + j * 0.2 - 0.01, Color(tint, 0.1))
	emitter.call("Glitter", int(pow(k, 2.0) * 220) if level > 1 else 0, 3.0,
		Vector3(half * 0.7, 0.8, half * 0.7), top + 0.9, 0.15, 0.12, Vector2(0.012, 0.03), tw, true)
	# Gold flakes: from the legendary stands up, a slow shower falling through the light.
	if level >= LEGEND_FROM + 1:
		var flake := Gradient.new()
		var gold := Color(2.4, 1.7, 0.6)
		flake.set_color(0, Color(gold, 0))
		flake.set_color(1, Color(gold, 0))
		for j in 6:  # catching the light as they turn
			flake.add_point(0.08 + j * 0.15, Color(gold, 0.9))
			flake.add_point(0.15 + j * 0.15, Color(gold, 0.25))
		emitter.call("GoldFlakes", int(40 + 260 * pow(k, 4.0)), 4.5, Vector3(half * 0.6, 0.3, half * 0.6),
			top + 3.0, 0.1, -0.5, Vector2(0.02, 0.045), flake, true)


## The concrete walls stop at 4 m and the roof starts at 8-9 m; corrugated sheet closes the gap on
## all four sides so nothing outside shows, with a steel ledger capping the concrete.
func _upper_walls() -> void:
	var sheet := ORMMaterial3D.new()
	sheet.albedo_texture = load(TEX + "corrugated_iron_02/corrugated_iron_02_diff_2k.jpg")
	sheet.albedo_color = Color(0.68, 0.7, 0.72)
	sheet.normal_enabled = true
	sheet.normal_texture = load(TEX + "corrugated_iron_02/corrugated_iron_02_nor_gl_2k.jpg")
	sheet.orm_texture = load(TEX + "corrugated_iron_02/corrugated_iron_02_arm_2k.jpg")
	sheet.uv1_triplanar = true
	sheet.uv1_scale = Vector3.ONE * 0.5
	sheet.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ResourceSaver.save(sheet, "res://materials/env/wall_sheet.tres")
	sheet = load("res://materials/env/wall_sheet.tres")
	var steel: Material = load("res://materials/env/metal_plate_02.tres")
	var upper := Node3D.new()
	upper.name = "UpperWalls"
	add(upper)
	var box := func(size: Vector3, at: Vector3, mat: Material) -> void:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		m.mesh = b
		m.material_override = mat
		m.position = at
		add(m, upper)
	const RUN := 56.6
	const FROM := 4.0
	var gable_top := BOTTOM + 0.05  # the gable cladding starts at the bottom chord
	var side_top := top_chord(28.6) + CHORD / 2 + 0.25  # under the roof sheet's overhang
	for s in [-1.0, 1.0]:
		box.call(Vector3(RUN, gable_top - FROM, 0.04), Vector3(0, (FROM + gable_top) / 2, s * 28.24), sheet)
		box.call(Vector3(0.04, side_top - FROM, RUN), Vector3(s * 28.24, (FROM + side_top) / 2, 0), sheet)
		box.call(Vector3(RUN, 0.14, 0.34), Vector3(0, FROM + 0.07, s * 28.15), steel)
		box.call(Vector3(0.34, 0.14, RUN), Vector3(s * 28.15, FROM + 0.07, 0), steel)


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


## Stone stands for the crates: rounded, slightly lumpy cast stone that grows with the crate.
## The final crate (12) has none: a big square on the floor and two crossing stage spots.
## Common: a plain block. Rare: on a wider plinth slab. Legendary: plinth, block and an overhanging
## darker cap, like a monument. Footprint and height grow along the row. Named ChestStand1..12
## (1 and 12 have no block); meta "height" is the top, and its Socket marker (group
## "chest_socket", meta "level") is where that level's crate is placed.
func _chest_stands() -> void:
	var mat := _stone_mat("stone_stand", Color(1.05, 1.03, 1.0))  # a touch paler than the floor
	var cap_mat := _stone_mat("stone_stand_cap", Color(0.6, 0.59, 0.57))
	var stands := Node3D.new()
	stands.name = "ChestStands"
	add(stands)
	var last := CHEST_COUNT - 2  # the last stand; the final crate has none
	for i in CHEST_COUNT:
		var t := float(i - 1) / (last - 1)  # 0 at the first block, 1 at the last
		var final := i == CHEST_COUNT - 1
		var top := 0.0 if i == 0 or final else lerpf(0.25, STAND_TOP, pow(t, 1.3))
		var body := StaticBody3D.new()
		body.name = "ChestStand%d" % (i + 1)
		body.position = chest_pos(i)
		body.rotation.y = PI / 2  # +Z, the crate's front, faces the heap (east)
		body.set_meta("height", top)
		add(body, stands)
		# Socket: where crate i + 1 goes. Its +Z is the crate's front, toward the heap.
		var socket := Marker3D.new()
		socket.name = "Socket"
		socket.position.y = top
		socket.set_meta("level", i + 1)
		socket.add_to_group("chest_socket", true)
		add(socket, body)
		_sparkle(body, i + 1, top, FINAL_SQUARE if final else 2.0)
		_aura(body, i + 1, FINAL_SQUARE * 0.42 if final else 0.85)
		if final:
			continue  # lit by its own two stage spots
		# A pool of light on each stand that grows by 40% a level, cool white at the bottom of the
		# row to warm gold at the top: the better the crate, the more it is lit up.
		var glow := SpotLight3D.new()
		glow.position = Vector3(0, top + 2.4, 0)
		glow.rotation.x = -PI / 2
		glow.light_color = Color(0.85, 0.92, 1.0).lerp(Color(1.0, 0.8, 0.45), float(i) / last)
		glow.light_energy = 0.5 * pow(1.4, i)  # 0.5 at level 1, 14 at level 11
		glow.spot_range = 7.0
		glow.spot_angle = 16.0 + 1.2 * i
		glow.spot_angle_attenuation = 0.4
		glow.shadow_enabled = false
		add(glow, body)
		if i == 0:
			continue
		var w := lerpf(0.75, 0.95, t)  # top width, the crate's footing
		var parts: Array = []  # [size, mat] stacked bottom up
		if i >= RARE_FROM:
			var plinth := 0.12 if i < LEGEND_FROM else 0.16
			parts.append([Vector3(w + 0.22, plinth, w + 0.22), mat])
		var cap := 0.09 if i >= LEGEND_FROM else 0.0
		var used := 0.0
		for p in parts:
			used += (p[0] as Vector3).y
		parts.append([Vector3(w, top - used - cap, w), mat])
		if cap > 0.0:
			parts.append([Vector3(w + 0.12, cap, w + 0.12), cap_mat])
		var y := 0.0
		for k in parts.size():
			var size: Vector3 = parts[k][0]
			var mi := MeshInstance3D.new()
			mi.mesh = _stone_block(size, i * 10 + k)
			mi.material_override = parts[k][1]
			mi.position.y = y + size.y / 2.0
			add(mi, body)
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			cs.shape = box
			cs.position.y = mi.position.y
			add(cs, body)
			y += size.y


## Cast stone: the floor's own concrete shader (Poly Haven "Concrete Floor Worn 001", CC0), so the
## stands sit in the hall's light like the floor does, with the slab joints turned off (a 4 m
## joint line would run across a block) and a tint of their own.
func _stone_mat(id: String, tint: Color) -> ShaderMaterial:
	var mat := (load("res://materials/concrete.tres") as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter("seam_width", 0.0)
	mat.set_shader_parameter("tex_size", 1.2)  # finer grain on a 1 m block
	mat.set_shader_parameter("tint", tint)
	var path := "res://materials/env/%s.tres" % id
	ResourceSaver.save(mat, path)
	return load(path)


## A box with rounded edges and a little noise pushed into its faces, centred on the origin.
func _stone_block(size: Vector3, noise_seed: int) -> ArrayMesh:
	const N := 14  # quads per face edge
	const R := 0.02  # m, edge radius: a mason's chamfer, not a cushion
	const BUMP := 0.003  # m, how far the faces swell and dip
	var r := minf(R, size.y * 0.45)  # a 10 cm block can't take full-size rounding
	var half := size / 2.0
	var inner := half - Vector3.ONE * r
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 7.0
	noise.fractal_octaves = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var point := func(p: Vector3) -> Vector3:
		var core := p.clamp(-inner, inner)
		var n := (p - core).normalized()
		var v := core + n * r
		return v + n * noise.get_noise_3dv(v) * BUMP
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var nrm := Vector3.ZERO
			nrm[axis] = sgn
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var w := nrm.cross(u)  # u x w points along nrm, so triangles face out
			var at := func(a: int, b: int) -> Vector3:
				var p := nrm * half + u * half * (2.0 * a / N - 1.0) + w * half * (2.0 * b / N - 1.0)
				return point.call(p)
			for a in N:
				for b in N:
					var p00: Vector3 = at.call(a, b)
					var p10: Vector3 = at.call(a + 1, b)
					var p01: Vector3 = at.call(a, b + 1)
					var p11: Vector3 = at.call(a + 1, b + 1)
					for v in [p00, p11, p10, p00, p01, p11]:
						st.add_vertex(v)
	st.index()  # shared positions merge across the face seams, so the normals come out smooth
	st.generate_normals()
	return st.commit()


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
	for i in CHEST_COUNT - 1:  # a painted square round each crate stand, clear of the widest plinth
		_decal(marks, box, chest_pos(i), 0.0, Vector3(2.0, 0.2, 2.0))
	# The final crate: a big square with a second one inside it, like a stage mark.
	_decal(marks, box, chest_pos(CHEST_COUNT - 1), 0.0, Vector3(FINAL_SQUARE, 0.2, FINAL_SQUARE))
	_decal(marks, box, chest_pos(CHEST_COUNT - 1), 0.0, Vector3(FINAL_SQUARE - 0.7, 0.2, FINAL_SQUARE - 0.7))

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
	# Big faint wear patches: break up the floor scan's repeat at a scale it never tiles at.
	placed = 0
	while placed < 18:
		var p := Vector3(rng.randf_range(-26, 26), 0, rng.randf_range(-26, 26))
		if p.length() < 11.0:
			continue
		var s := rng.randf_range(4.0, 9.0)
		var d := _decal(marks, stain, p, rng.randf() * TAU, Vector3(s, 1.0, s * rng.randf_range(0.5, 1.0)))
		d.modulate = Color(1, 1, 1, rng.randf_range(0.15, 0.3))
		placed += 1
	_wall_grime(marks, rng)


## Grime on the precast walls so the 4 m panels stop reading as copies: rain-like streaks down
## from the top on some panels, and a dirty band along the foot of every wall.
func _wall_grime(parent: Node, rng: RandomNumberGenerator) -> void:
	var streaks := FastNoiseLite.new()
	streaks.seed = 31
	streaks.frequency = 0.05
	var streak := _decal_tex("wall_streaks", 256, 512, func(img: Image) -> void:
		for y in 512:
			for x in 256:
				var col := streaks.get_noise_2d(x * 1.0, y * 0.04)  # long vertical runs
				var fade := pow(1.0 - y / 512.0, 1.5)  # heaviest at the top, running out downward
				var edge := smoothstep(0.0, 40.0, minf(x, 255 - x))
				var a := clampf(col * 1.6 + 0.25, 0.0, 1.0) * fade * edge
				if a > 0.0:
					img.set_pixel(x, y, Color(0.12, 0.1, 0.08, a * 0.6)))
	var foot := _decal_tex("wall_foot", 512, 64, func(img: Image) -> void:
		for y in 64:
			for x in 512:
				var a := pow(y / 63.0, 2.0) * (0.6 + 0.4 * streaks.get_noise_2d(x * 2.0, y * 2.0 + 900.0))
				img.set_pixel(x, y, Color(0.1, 0.09, 0.07, clampf(a, 0.0, 1.0) * 0.55)))
	for side in 4:
		var yaw := side * PI / 2.0
		var b := Basis(Vector3.UP, yaw)
		var face := b * Vector3(0, 0, 28.0)  # inner face of this wall
		# Decals project along their -Y: tip it over to point into the wall.
		var into := b * Basis(Vector3.RIGHT, -PI / 2)
		for i in 14:
			if rng.randf() < 0.45:
				continue
			var along := -26.0 + 4.0 * i + rng.randf_range(-1.2, 1.2)
			var h := rng.randf_range(1.6, 3.6)
			var d := Decal.new()
			d.texture_albedo = streak
			d.size = Vector3(rng.randf_range(1.2, 3.2), 0.6, h)
			d.transform = Transform3D(into, face + b * Vector3(along, 0, 0) + Vector3(0, 4.0 - h / 2.0, 0))
			d.modulate = Color(1, 1, 1, rng.randf_range(0.5, 1.0))
			d.cull_mask = 1
			add(d, parent)
		var f := Decal.new()
		f.texture_albedo = foot
		f.size = Vector3(56.0, 0.6, 0.9)
		f.transform = Transform3D(into, face + Vector3(0, 0.45, 0))
		f.cull_mask = 1
		add(f, parent)


func _decal(parent: Node, tex: Texture2D, pos: Vector3, yaw: float, size: Vector3) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = size
	d.position = pos
	d.rotation.y = yaw
	d.upper_fade = 0.1
	d.lower_fade = 0.1
	d.cull_mask = 1  # floor and heap only; not the gun (layer 2)
	add(d, parent)
	return d


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
