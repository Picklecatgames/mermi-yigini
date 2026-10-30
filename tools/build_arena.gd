extends SceneTree
## Builds scenes/arena.tscn: the range shed (beveled precast walls, H columns, trusses, purlins,
## corrugated roof with skylights, gable cladding), ceiling LED battens, props, floor paint and stains,
## four co-op spawn points, the crate stands and the stage spots; closed and dark, the sun only
## through the roof's holes (tools/hall_dressing.gd dresses the abandonment). Re-run after changing tools/build_shed_meshes.py output or these numbers:
##   godot --headless --path . -s res://tools/build_arena.gd
## Dimensions must match tools/build_shed_meshes.py.

const SHED := "res://assets/env/shed/"
const TEX := "res://assets/env/textures/"
const MODELS := "res://assets/env/models/"
const FLOOR_PAINT := 1 << 5  # the floor alone also sits on layer 6; floor decals print only there
const OFFICE := "res://assets/props/office/"  # tools/build_office.py
const LAMP_DROP := 1.34  # hanging_industrial_lamp: rod top to the shade's rim
const BULB_Y := -1.06  # the model's own bulb, up in the glass under the reflector
const HALF_SPAN := 27.7
const EAVE := 8.8
const BOTTOM := 8.0
const PITCH := deg_to_rad(6.0)
const CHORD := 0.18
const COLUMN_H := 8.95
const BAYS: Array[float] = [-27.85, -21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0, 27.85]
const LAMP_SPAN := 24.0  # ceiling battens from -LAMP_SPAN to +LAMP_SPAN along each truss
const LAMP_STEP := 6.0
const LAMP_ENERGY := 1.0  # night: dim, old bulbs; working light pools under each bulb; the heap's own spots stay the brightest thing
const LAMP_HEAP_CLEAR := 9.0  # m round the heap with no battens, so it stands in its own light
const DECALS := "res://materials/env/decals/"
# 2026-10-24: a greenhouse glass roof over the middle of the hall (x0, z0, x1, z1), about 30% of
# its floor, the heap under it; the rest of the roof is sheeted shut. _lantern builds it.
const LANTERN := Vector4(-15.0, -14.0, 15.0, 14.0)
const LANTERN_EAVE := 11.6  # top of its glass side walls, over the old roof
const LANTERN_PITCH := deg_to_rad(18.0)
const SUN_DIR := Vector3(-0.42, -1.0, 0.22)  # the night light's travel through the glass
## The heap's centre, west of the hall's middle (scenes/main.tscn Pile has the same): its paint
## ring (10.6 m) ends at x 1.6, leaving a 12.4 m band to the railing for belts and turrets
## (docs/taret_bant_kilavuzu.md, "Yerleşim").
const HEAP := Vector3(-9.0, 0, 0)
## Co-op spawns between the heap and the railing (2026-10-28, the user), everyone facing the heap
## over the desk with the pistol (GUN_TABLE); the first two right behind it.
const SPAWNS: Array[Vector3] = [Vector3(8.7, 0, -0.8), Vector3(8.7, 0, 0.8), Vector3(8.7, 0, -2.4), Vector3(8.7, 0, 2.4)]
const GUN_TABLE := Vector3(7.3, 0, 0)  # metal_office_desk, 2 m along z, its drawer side to the spawns
## Crate stands west of the heap, a row running north and centred on the hall: levels 1-11 on
## stands STAND_GAP apart (1, the worst crate, on bare floor), then a gap and level 12, the final
## crate, on the floor in a big square under two crossing stage spots. Stand tiers follow the
## keys: 4 common, 5 rare, 2 legendary + the final. Tops climb on an ease-in curve to STAND_TOP,
## well under the 1.6 m eye so the crate on top still shows.
const GS := preload("res://scripts/game_state.gd")
## Past the firing line (2026-10-29, zombie waves: no range any more, the yard where the dead come
## in and are cut down): filthy concrete floor, the bare walls, a light bridge over the line, and a
## covered bay out through the east wall with a low ceiling. The dead come in through the bay:
## three gates (the big sliding one in the back wall, a lifting one in each side wall) open onto
## holding pens; tools/zombie_bay.gd builds the gates, pens, spawns, alarms and the gore.
const BAY_END := 44.3     # inner face of the bay's back wall (30 m from the railing)
const BAY_HALF := 12.0    # the east wall is open over |z| < BAY_HALF
const BAY_H := 4.0        # the bay's ceiling, level with the hall's concrete
## The gates' openings in the bay walls (tools/zombie_bay.gd hangs the leaves in them): the back
## wall is open over |z| < MAIN_GATE_HALF, each side wall over x SIDE_GATE_X +- SIDE_GATE_HALF.
const MAIN_GATE_HALF := 4.0
const SIDE_GATE_X := 38.3
const SIDE_GATE_HALF := 2.0
const BRIDGE_Y := 5.0     # the light bridge over the firing line
const RANGE_LIGHT := Color(0.74, 0.88, 0.78)  # old fluorescent gone green, against the hall's warm 4000 K
const SODIUM := Color(1.0, 0.66, 0.32)  # the light bridge's work lights: dirty sodium
const STENCIL := preload("res://assets/fonts/SairaStencilOne-Regular.ttf")  # signs (OFL)
const FLICKER := preload("res://scripts/flicker_lamp.gd")
const WORKSHOP := Vector3(10.5, 0, 26.0)  # the crew's corner (range_dressing _workshop), between the columns at x 7 and 14
const WORKSHOP_DARK := 11.0  # m round it with the hall lamps dead, so the corner stands out lit
const CHEST_X := -23.0  # between the heap's paint ring (x -19.6) and the west wall
const CHEST_COUNT := 12
const STAND_GAP := 3.0
const FINAL_GAP := 4.5  # level 11 to level 12, room for the big square
const FINAL_SQUARE := 4.2  # m
const STAND_TOP := 1.1  # m, level 11's top
const TWIN_SPOT := MODELS + "twin_spot_light/"
const TWIN_SPOT_SCALE := 0.13  # the FBX is in decimetres: a 50 cm box
## The floor lamp between crate n and n + 1: yaw (deg off facing its two crates), roll about its
## length (±90: knocked over, on its back or its face, the eyes still turned onto the crates), tilt
## (deg, one end up on rubble).
const LAMP_POSES: Array[Vector3] = [Vector3(15, 0, 0), Vector3(-38, 0, 0), Vector3(10, 90, 0),
	Vector3(35, 0, 7), Vector3(-12, -90, 0), Vector3(-52, 0, 0), Vector3(20, 0, -6),
	Vector3(-25, 90, 0), Vector3(-25, 0, 0), Vector3(52, 0, 0), Vector3(-4, -90, 0)]
## Where it stands (2026-10-26, the user: not all in one line): x off the row (+ toward the heap,
## - behind it, near 0 in the gap between the squares), z off the middle of its two crates (toward
## one crate's side).
const LAMP_SPOTS: Array[Vector2] = [Vector2(1.1, 0.2), Vector2(-1.3, -0.3), Vector2(0.1, 0.1),
	Vector2(1.4, -0.6), Vector2(-1.1, 0.5), Vector2(0.95, -1.0), Vector2(-0.2, 0.3),
	Vector2(1.25, 0.9), Vector2(-1.4, 0.0), Vector2(0.25, -0.4), Vector2(1.0, 0.0)]
const RARE_FROM := 4  # index of the first rare stand; legendary from LEGEND_FROM
const LEGEND_FROM := 9


## Where crate `i` (0 = level 1) stands: the row is centred on z = 0.
static func chest_pos(i: int) -> Vector3:
	var span := STAND_GAP * (CHEST_COUNT - 2) + FINAL_GAP
	var z := span / 2.0 - STAND_GAP * mini(i, CHEST_COUNT - 2) - (FINAL_GAP if i == CHEST_COUNT - 1 else 0.0)
	return Vector3(CHEST_X, 0, z)

var arena: Node3D
var _lamp_saved := false


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
	_dust()
	_firing_line()
	_range()
	_chest_stands()
	_markings()
	_spawns()
	preload("res://tools/hall_dressing.gd").new(self).build()
	_lighten(arena, Transform3D())
	for path in ["Roof", "Lamps", "UpperWalls", "Range/LightBridge", "Range/BayCeiling"]:
		overhead(arena.get_node(path))
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


## A Poly Haven set on materials/env/worn_surface.gdshader (no visible repeat: per-cell tone,
## a big turned sample, grime, rust), saved as `save_as`. `params` set its uniforms.
func worn(id: String, save_as: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://materials/env/worn_surface.gdshader")
	m.set_shader_parameter("albedo_tex", load(TEX + "%s/%s_diff_2k.jpg" % [id, id]))
	m.set_shader_parameter("normal_tex", load(TEX + "%s/%s_nor_gl_2k.jpg" % [id, id]))
	m.set_shader_parameter("arm_tex", load(TEX + "%s/%s_arm_2k.jpg" % [id, id]))
	var noise := FastNoiseLite.new()
	noise.seed = save_as.hash() & 0xffff
	noise.frequency = 0.02
	noise.fractal_octaves = 5
	var grime := NoiseTexture2D.new()
	grime.noise = noise
	grime.seamless = true
	grime.width = 512
	grime.height = 512
	m.set_shader_parameter("grime_tex", grime)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	var path := "res://materials/env/%s.tres" % save_as
	ResourceSaver.save(m, path)
	return load(path)


## The same, mapped by position instead of UVs, a texture repeat every `metres`: world-space
## (seamless across separate meshes) or per object (`world` off: every piece starts its own).
func pbr_box(id: String, metres: float, tint := Color.WHITE, world := true, save_as := "") -> ORMMaterial3D:
	var m := ORMMaterial3D.new()
	m.albedo_texture = load(TEX + "%s/%s_diff_2k.jpg" % [id, id])
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX + "%s/%s_nor_gl_2k.jpg" % [id, id])
	m.orm_texture = load(TEX + "%s/%s_arm_2k.jpg" % [id, id])
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_scale = Vector3.ONE / metres
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var path := "res://materials/env/%s.tres" % (save_as if save_as != "" else id)
	ResourceSaver.save(m, path)
	return load(path)


func _environment() -> void:
	# A closed, dark hall: no sky at all, so nothing outside can leak in through the GI, the
	# reflections or the fog. Every bit of light is a lamp or spot we placed.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR  # faint fill: the roof and corners never go pitch black
	env.ambient_light_color = Color(0.5, 0.52, 0.58)  # night: a touch cold
	env.ambient_light_energy = 0.18
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED  # the probe below covers it
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.sdfgi_enabled = false  # 2026-10-22: its camera-centred cascades made dark corners pop lighter/darker as you walked; bounce is faked by ambient and the heap fill
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_cascades = 4
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.6  # lenses and bulbs bloom, brass speculars do not
	env.volumetric_fog_enabled = true  # dust in the air: the lamp cones and spot beams show in it
	env.volumetric_fog_density = 0.0025  # a light haze; thicker turned every beam into a grey wedge
	env.volumetric_fog_albedo = Color(0.92, 0.9, 0.86)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_sky_affect = 0.0
	env.ssr_enabled = true  # the puddles under the roof holes mirror the shafts and lamps
	env.ssr_max_steps = 48  # puddles only; 96 cost ~3 ms at 1080p for no visible gain
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	env.adjustment_enabled = true  # AgX washes colour out; give the brass, paint and signs back some punch
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
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
	# Concrete up to the firing line; past it (2026-10-29, the user: not a range any more, the yard
	# where the dead come in and die) filthy cracked slabs (Poly Haven "Dirty Concrete"), 3 m pours
	# each its own tone, grime gone brown-red with years of blood, the scuffed band behind the
	# railing where the shooting is. World-mapped like the hall's, so the two meet clean.
	var fl: float = GS.FIRING_LINE_X
	var rubber := worn("dirty_concrete", "kill_floor", {"tint": Color(0.72, 0.68, 0.64), "tex_size": 3.0,
		"cell_size": 3.0, "cell_tone": 0.14, "odd_cells": 0.12, "antitile": 0.5, "grime": 1.0,
		"grime_scale": 0.11, "grime_color": Color(0.11, 0.045, 0.035), "wear_x": fl + 2.2, "wear_width": 2.6})
	for part in [[Rect2(-28.0, -28.0, fl + 28.0, 56.0), load("res://materials/concrete.tres")],
			[Rect2(fl, -28.0, 28.15 - fl, 56.0), rubber],
			[Rect2(28.15, -BAY_HALF - 0.3, BAY_END - 28.15, 2.0 * BAY_HALF + 0.6), rubber]]:
		var r: Rect2 = part[0]
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = r.size
		mi.mesh = pm
		mi.position = Vector3(r.get_center().x, 0, r.get_center().y)
		mi.material_override = part[1]
		mi.layers = 1 | FLOOR_PAINT
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
		var east: bool = side[0] == "East"  # open over the range bay; local x is world z there
		for i in 14:
			var along := -26.0 + 4.0 * i
			if side[0] == "South" and i == 8:
				continue  # world x -6: the loading door (tools/hall_dressing.gd _loading_door)
			if not (east and absf(along) < BAY_HALF):
				mesh_at("wall_panel", Transform3D(Basis(), Vector3(along, 0, 0)), mat, body)
		var runs := [[-28.3, -BAY_HALF], [BAY_HALF, 28.3]] if east else [[-28.3, 28.3]]
		for run in runs:
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(run[1] - run[0], 4.0, 0.3)
			cs.shape = box
			cs.position = Vector3((run[0] + run[1]) / 2.0, 2.0, 0)
			add(cs, body)


func _columns() -> void:
	var steel := pbr("metal_plate_02", Color(0.62, 0.64, 0.66))
	var body := StaticBody3D.new()
	body.name = "Columns"
	add(body)
	var spots: Array = []  # [position, yaw, height]
	for z in BAYS:
		for s in [-1.0, 1.0]:
			if s > 0 and absf(z) < BAY_HALF:
				continue  # the range bay's mouth: a girder carries these trusses instead (_bay)
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
	# Sheets 6 m apart each a little different, grime and rust blooms: no tiling seen from below.
	var roof_mat := worn("corrugated_iron_02", "roof_sheet", {"mesh_uv": true, "tint": Color(0.85, 0.86, 0.88),
		"cell_size": 6.0, "cell_tone": 0.12, "odd_cells": 0.1, "antitile": 0.3, "grime": 0.55,
		"grime_scale": 0.07, "rust": 0.45})
	var sheet := mesh_at("roof_sheet", Transform3D(), roof_mat, roof)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	# Cut clean where the glass lantern sits; the old skylight strips are sheeted over with the rest.
	roof_mat.set_shader_parameter("cutout", LANTERN)
	ResourceSaver.save(roof_mat)
	var shut := mesh_at("skylight", Transform3D(), roof_mat, roof)
	shut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	_lantern(roof, steel, roof_mat.get_shader_parameter("grime_tex"))
	_sun(roof)
	var clad: Material = load("res://materials/env/corrugated_iron_02.tres")
	for s in [-1.0, 1.0]:
		var g := mesh_at("gable_cladding", Transform3D(Basis(), Vector3(0, 0, s * 28.3)), clad, roof)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED



## A greenhouse lantern over the LANTERN rect: glass side walls standing on the roof sheet, a
## glass gable over them at LANTERN_PITCH, glass gable ends down to the old roof line, all on a
## grid of slim steel glazing bars. The glass casts no shadow, the bars do.
func _lantern(roof: Node3D, steel: Material, grime: Texture2D) -> void:
	var e1 := LANTERN.z
	var z0 := LANTERN.y
	var z1 := LANTERN.w
	var sheet := func(x: float) -> float: return top_chord(x) + CHORD / 2 + 0.21
	var glass_y := func(x: float) -> float: return LANTERN_EAVE + (e1 - absf(x)) * tan(LANTERN_PITCH)
	var base: float = sheet.call(e1)
	var mid: float = sheet.call(0.0)
	var ridge: float = glass_y.call(0.0)
	var panes := SurfaceTool.new()
	panes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		for v in [a, b, c, a, c, d]:
			panes.add_vertex(v)
	var bars := SurfaceTool.new()
	bars.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unit := BoxMesh.new()
	var bar := func(a: Vector3, b: Vector3) -> void:
		var along := b - a
		var side := along.cross(Vector3.RIGHT if absf(along.normalized().y) > 0.9 else Vector3.UP).normalized()
		bars.append_from(unit, 0, Transform3D(Basis(along, side.cross(along).normalized() * 0.09, side * 0.06), (a + b) / 2.0))
	for s in [-1.0, 1.0]:
		var e: float = s * e1
		quad.call(Vector3(e, LANTERN_EAVE, z0), Vector3(0, ridge, z0), Vector3(0, ridge, z1), Vector3(e, LANTERN_EAVE, z1))
		quad.call(Vector3(e, base, z0), Vector3(e, LANTERN_EAVE, z0), Vector3(e, LANTERN_EAVE, z1), Vector3(e, base, z1))
		var z := z0
		while z <= z1 + 0.01:  # rafters down the slope, mullions in the side wall
			bar.call(Vector3(e, LANTERN_EAVE, z), Vector3(0, ridge, z))
			bar.call(Vector3(e, base, z), Vector3(e, LANTERN_EAVE, z))
			z += 2.0
		for t in [0.0, 0.34, 0.67, 1.0]:  # glazing bars along the slope, eave to ridge
			var at := Vector3(e, LANTERN_EAVE, 0).lerp(Vector3(0, ridge, 0), t)
			bar.call(Vector3(at.x, at.y, z0), Vector3(at.x, at.y, z1))
		bar.call(Vector3(e, base, z0), Vector3(e, base, z1))
		for gz in [z0, z1]:  # the gable ends, down to the old roof
			quad.call(Vector3(e, base, gz), Vector3(0, mid, gz), Vector3(0, ridge, gz), Vector3(e, LANTERN_EAVE, gz))
			bar.call(Vector3(e, base, gz), Vector3(0, mid, gz))
			var x := 0.0
			while x < e1 - 0.01:
				bar.call(Vector3(s * x, sheet.call(x), gz), Vector3(s * x, glass_y.call(x), gz))
				x += 2.5
	panes.generate_normals()
	var glass := ShaderMaterial.new()
	glass.shader = load("res://materials/env/lantern_glass.gdshader")
	glass.set_shader_parameter("grime_tex", grime)
	var g := MeshInstance3D.new()
	g.name = "LanternGlass"
	g.mesh = panes.commit()
	g.material_override = glass
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add(g, roof)
	# The shed's probe stops under the roof: without its own the glass has nothing to mirror. Captured
	# from down in the hall, so the panes show the lamps and the heap's glow, as greenhouse glass does at night.
	var probe := ReflectionProbe.new()
	probe.name = "LanternReflections"
	probe.size = Vector3(e1 * 2.0 + 1.0, ridge - base + 1.5, z1 - z0 + 1.0)
	probe.position = Vector3(0, (ridge + base) / 2.0, (z0 + z1) / 2.0)
	probe.origin_offset = Vector3(0, 4.5 - probe.position.y, 0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.max_distance = 80.0
	add(probe, roof)
	var f := MeshInstance3D.new()
	f.name = "LanternFrame"
	f.mesh = bars.commit()
	f.material_override = steel
	add(f, roof)


## Night outside, about 21:30: a starry sky on a dome round the whole shed (night_sky.gdshader,
## seen only through the glass lantern) and its cold light, which falls in through the glass with
## the glazing bars' shadows on the heap. Kept out of the GI, so nothing outside leaks in evenly.
func _sun(roof: Node3D) -> void:
	var sky := MeshInstance3D.new()
	sky.name = "Sky"
	var dome := SphereMesh.new()
	dome.radius = 150.0
	dome.height = 300.0
	dome.flip_faces = true  # seen from inside
	sky.mesh = dome
	var lid := ShaderMaterial.new()
	lid.shader = load("res://materials/env/night_sky.gdshader")
	lid.set_shader_parameter("panorama", load("res://assets/env/hdri/rogland_clear_night_4k.hdr"))
	sky.material_override = lid
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add(sky, roof)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(SUN_DIR.normalized(), Vector3.FORWARD), Vector3(0, 20, 0))
	sun.light_color = Color(0.6, 0.72, 1.0)  # cold night light: the abandonment, against the crew's warm lamps
	sun.light_energy = 0.4  # the only light under the glass: the heap and the floor round it stay cold and readable
	sun.light_volumetric_fog_energy = 0.0  # the fog ignores the roof's shadow: it would light the whole hall
	sun.light_cull_mask = 1  # not the gun's layer
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_blend_splits = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add(sun)
	# The lamps' bounce up off the floor: a faint warm light from below on the overhead layer
	# alone, so the closed roof and its trusses show dimly instead of a black void.
	var bounce := DirectionalLight3D.new()
	bounce.name = "RoofBounce"
	bounce.transform = Transform3D(Basis.looking_at(Vector3.UP, Vector3.FORWARD), Vector3(0, 2, 0))
	bounce.light_color = Color(1.0, 0.88, 0.75)
	bounce.light_energy = 0.25
	bounce.light_cull_mask = 1 << (GS.OVERHEAD_LAYER - 1)
	bounce.light_volumetric_fog_energy = 0.0
	bounce.light_specular = 0.0
	bounce.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add(bounce)


## Enamel pendants (ceiling_lamp()) hung under every truss's bottom chord, LAMP_STEP apart: a bulb
## in each shade and one wide, soft, shadowless light. Only every other spot, staggered, so the hall
## is pools of light with dark between, not a lit, safe-feeling grid.
func _lamps() -> void:
	var lamps := Node3D.new()
	lamps.name = "Lamps"
	add(lamps)
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(1.0, 0.97, 0.92)
	lens.emission_enabled = true
	lens.emission = Color(1.0, 0.95, 0.86)
	lens.emission_energy_multiplier = 14.0  # a hot bulb: well over the glow threshold, it blooms through the glass
	ResourceSaver.save(lens, "res://materials/env/lamp_diffuser.tres")
	lens = load("res://materials/env/lamp_diffuser.tres")
	var paint: Material = load("res://materials/env/metal_plate_02.tres")
	var y := BOTTOM - CHORD / 2
	var row := 0
	for z in BAYS.slice(1, BAYS.size() - 1):
		row += 1
		var x := -LAMP_SPAN
		while x <= LAMP_SPAN + 0.01:
			if (row + roundi((x + LAMP_SPAN) / LAMP_STEP)) % 2 == 1:  # every other one, staggered: a full grid read safe and lit
				x += LAMP_STEP
				continue
			var near_spot := false
			for s in HEAP_SPOTS + [Vector3(CHEST_X, 0, -14), Vector3(CHEST_X, 0, -21)]:
				near_spot = near_spot or (absf(s.z - z) < 0.1 and absf(s.x - x) < 1.4)
			near_spot = near_spot or Vector2(x - HEAP.x, z - HEAP.z).length() < LAMP_HEAP_CLEAR
			var downrange := x > GS.FIRING_LINE_X  # cool daylight over the targets (_range)
			# Years abandoned: half the hall's bulbs dead, some failing, some knocked askew.
			# The range side still has its own working circuit. Pools of light, not a grid.
			var wear := absi(hash(Vector2i(roundi(x * 3.0), roundi(z * 7.0)))) % 10
			if Vector2(x - HEAP.x, z - HEAP.z).length() < 17.0 or (x > -3.0 and x < GS.FIRING_LINE_X):
				wear = 9 if wear < 8 else wear  # where players dig and build, the crew keeps the tubes working
			if downrange:  # past the railing (2026-10-29, the dead's side): half dead, one in ten failing
				wear = 0 if wear < 5 else (5 if wear == 5 else 9)
			if Vector2(x - WORKSHOP.x, z - WORKSHOP.z).length() < WORKSHOP_DARK:
				wear = 0  # dark round the crew's corner
			if x < CHEST_X + 4.5:
				wear = 0  # dark over the crate row (2026-10-25, the user): only the lamps on the floor light it
			if absf(x) < LANTERN.z and absf(z) < LANTERN.w:  # none under the glass: there the sky and its cold light are the lamp
				x += LAMP_STEP
				continue
			if not near_spot:  # the stage spots' clamps sit on these chords
				var lamp := ceiling_lamp(lamps)
				lamp.position = Vector3(x, y, z)
				if wear == 7:  # knocked: hangs a little askew on its rod
					lamp.rotation.z = 0.08 * (1.0 if hash(z) % 2 == 0 else -1.0)
				var dead := wear <= 4 or wear == 7
				var d := bulb(lamp, paint if dead else lens, not dead)
				if dead:  # dark bulb, no light
					x += LAMP_STEP
					continue
				var spot := SpotLight3D.new()
				if wear == 5 or wear == 6:
					d.material_override = lens.duplicate()
					spot.set_script(FLICKER)
				spot.position.y = BULB_Y  # from the bulb itself, the shade's rim cuts the cone
				spot.rotation.x = -PI / 2
				spot.light_color = RANGE_LIGHT if downrange else Color(1.0, 0.9, 0.78)  # old tungsten-warm 3500 K: only the daylight is cold
				spot.light_energy = LAMP_ENERGY * (0.9 if downrange else 1.0)
				spot.spot_range = 14.0
				spot.spot_attenuation = 0.6
				spot.spot_angle = 58.0  # the shade's rim seen from the bulb
				spot.spot_angle_attenuation = 1.6  # pools of light on the floor, dark between
				spot.light_volumetric_fog_energy = 1.2  # a soft cone in the dust under each bulb: the light visibly leaves the lamp
				spot.shadow_enabled = false
				add(spot, lamp)
			x += LAMP_STEP


## The heap's lights: four theatre spots, one from each corner round it, clamped under the z = +-7
## trusses in place of the hall lamps there. Wide and soft-edged, crossing so the whole heap is
## washed in an even, calm light, with faint beams in the dust. No lamp hangs over the heap itself.
const HEAP_SPOTS: Array[Vector3] = [HEAP + Vector3(-11, 0, 7), HEAP + Vector3(11, 0, 7), HEAP + Vector3(-11, 0, -7), HEAP + Vector3(11, 0, -7)]
const HEAP_AIM := HEAP + Vector3(0, 2.4, 0)  # a third up the ~7 m heap


func _heap_spot() -> void:
	for i in HEAP_SPOTS.size():
		var at := HEAP_SPOTS[i] + Vector3(0, BOTTOM - CHORD / 2 - 0.05, 0)
		_stage_spot("HeapSpot%d" % (i + 1), at, HEAP_AIM, 36.0, 7.0, 0.0, 1.0, 1.8)  # no beams: in the hall they read as solid grey wedges
	# The pile is a big gold reflector: a warm bounce off it keeps the floor round its foot, where
	# players dig, out of the black.
	var bounce := OmniLight3D.new()
	bounce.name = "HeapBounce"
	bounce.position = HEAP + Vector3(0, 0.6, 0)
	bounce.light_color = Color(1.0, 0.72, 0.4)
	bounce.light_energy = 2.2
	bounce.omni_range = 10.5  # short of the crate row (x -23), which only its floor lamps light
	bounce.omni_attenuation = 1.2
	bounce.light_volumetric_fog_energy = 0.0
	add(bounce)


## A theatre spot hanging from a truss at `at`, aimed at `aim`, with a visible beam cone.
## `angle` is the half angle, `strength` the beam cone's glow, `size` scales the fixture.
## `edge` is the angle attenuation: low is a hard theatre edge, high a soft wash; `colour` the light's.
func _stage_spot(spot_name: String, at: Vector3, aim: Vector3, angle: float, energy: float, strength: float, size := 1.0, edge := 0.12, colour := Color.WHITE) -> void:
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
	spot.light_color = colour
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
	beam.set_shader_parameter("color", Vector3(colour.r, colour.g, colour.b))
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
		_stage_spot("FinalSpot%d" % int(absf(z)), at, target, 22.0, 6.0, 0.1, 1.4, 1.6)  # was 60 / 0.4: the brightest thing in the hall, lighting an empty square


## Dust hanging in the light over crate `level`'s stand, a little more each level. `top` is the
## stand's top, `area` the painted square's side. Soft dot sprites drawn here, no texture files.
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
	dust.add_point(0.3, Color(1, 0.97, 0.9, 0.18))
	dust.add_point(0.7, Color(1, 0.97, 0.9, 0.18))
	emitter.call("Dust", int(6 + 30 * k), 9.0, Vector3(half * 0.8, 0.8, half * 0.8), top + 0.8,
		0.05, 0.005, Vector2(0.008, 0.02), dust, false)


## The crate's aura, an industrial one (2026-10-25, the user: an aura, but not magic): a cloud of
## dust and powder hanging low round the stand, thicker and warmer up the row, that the floor
## lamps' beams cut through and light from below. A FogVolume in the hall's volumetric fog, so it
## only shows where light falls on it; `area` is the painted square's side, `top` the stand's top.
func _haze(parent: Node3D, level: int, area: float, top: float) -> void:
	var k := float(level) / CHEST_COUNT
	var fog := FogMaterial.new()
	fog.density = lerpf(0.08, 0.26, k)
	fog.albedo = Color(0.85, 0.8, 0.7).lerp(Color(0.95, 0.78, 0.5), k)  # concrete dust, turning to brass powder
	fog.height_falloff = 0.6  # settles toward the floor
	fog.edge_fade = 0.8  # no box edges in the air
	var v := FogVolume.new()
	v.name = "Haze"
	v.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	v.size = Vector3(area * 0.95, top + 1.8, area * 0.95)
	v.position.y = (top + 1.8) / 2.0 - 0.2
	v.material = fog
	add(v, parent)


## Loose rounds round crate `level`'s stand, as if it leaks them: a few at level 1, a spill across
## the painted square by the last ones (2026-10-25, the user: the glitter and gold flakes read as a
## magic game). The brass catches the floor lamps, so the shine comes from the game's own stuff.
## `area` is the square's side, `foot` the stand's half width.
func _spilled_rounds(parent: Node3D, level: int, area: float, foot: float) -> void:
	var scene: Node = (load("res://assets/bullet/bullet_9mm_lod.glb") as PackedScene).instantiate()
	var mesh: Mesh = (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = level
	var k := float(level) / CHEST_COUNT
	# The glb is not in metres: bring it to the heap's round (pile.gd BULLET_LENGTH, 3x a real 9 mm), centred, its length along Y.
	var box := mesh.get_aabb()
	var size := preload("res://scripts/pile.gd").BULLET_LENGTH / box.get_longest_axis_size()
	var upright := Basis() if box.size.y >= maxf(box.size.x, box.size.z) else (Basis(Vector3.RIGHT, PI / 2) if box.size.z > box.size.x else Basis(Vector3.BACK, PI / 2))
	var unit := Transform3D(upright.scaled(Vector3.ONE * size), Vector3.ZERO) * Transform3D(Basis(), -box.get_center())
	var radius := box.get_shortest_axis_size() * size / 2.0
	# One merged mesh, not a MultiMesh: a headless build saves MultiMeshes without their transforms.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var reach := area / 2.0 * 0.9
	var spill := func(at: Vector3, lay: Basis) -> void:
		st.append_from(mesh, 0, Transform3D(lay, at) * unit)
	for i in int(6 + 110 * pow(k, 1.5)):
		# Most spill out the front (+Z, toward the heap) in a fan, the rest anywhere round the foot.
		var a := rng.randfn(0.0, 0.6) if i % 3 != 0 else rng.randf() * TAU
		var r := lerpf(foot, reach, pow(rng.randf(), 0.9))
		if rng.randf() < 0.08:  # one in a dozen landed standing
			spill.call(Vector3(sin(a) * r, preload("res://scripts/pile.gd").BULLET_LENGTH / 2.0, cos(a) * r), Basis(Vector3.UP, rng.randf() * TAU))
		else:  # on its side, any way round
			spill.call(Vector3(sin(a) * r, radius, cos(a) * r), Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2))
	# From the rare crates up, a heap of them where they poured out at the stand's front.
	if level > RARE_FROM:
		var mound := lerpf(0.16, 0.34, k)
		for i in int(20 + 90 * k):
			var r := mound * sqrt(rng.randf())
			var a := rng.randf() * TAU
			var y := radius + 0.16 * k * (1.0 - r / mound) * rng.randf()
			var tip := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2 + rng.randf_range(-0.4, 0.4))
			spill.call(Vector3(cos(a) * r, y, foot + mound * 0.7 + sin(a) * r), tip)
	var mi := MeshInstance3D.new()
	mi.name = "Rounds"
	mi.mesh = st.commit()
	mi.material_override = mesh.surface_get_material(0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(mi, parent)


## The concrete walls stop at 4 m and the roof starts at 8-9 m; corrugated sheet closes the gap on
## all four sides so nothing outside shows, with a steel ledger capping the concrete.
func _upper_walls() -> void:
	var sheet := worn("corrugated_iron_02", "wall_sheet", {"tint": Color(0.68, 0.7, 0.72), "tex_size": 2.0,
		"cell_size": 3.0, "cell_tone": 0.1, "odd_cells": 0.08, "antitile": 0.3, "grime": 0.45,
		"grime_scale": 0.08, "rust": 0.35})
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
	var shelves := MODELS + "steel_frame_shelves_01/steel_frame_shelves_01_1k.gltf"
	for z in [-6.0, -4.8, 4.8, 6.0]:
		_prop(props, shelves, Vector3(-27.45, 0, z), PI / 2, 0.1)
	var crate := MODELS + "wooden_crate_01/wooden_crate_01_1k.gltf"
	var ammo := MODELS + "ammo_box/ammo_box_1k.gltf"
	for p in [Vector3(-25.8, 0, -3.4), Vector3(-25.7, 0.35, -3.35), Vector3(-25.2, 0, 3.6)]:
		_prop(props, crate, p, randf_range(-0.3, 0.3))
	for p in [Vector3(-25.6, 0.7, -3.3), Vector3(-25.3, 0.35, 3.7)]:
		_prop(props, ammo, p, randf_range(-0.6, 0.6))
	var barrel2 := MODELS + "Barrel_02/Barrel_02_1k.gltf"
	for p in [Vector3(-26.9, 0, 17.6), Vector3(-26.3, 0, 18.3), Vector3(-26.95, 0, 18.6)]:
		_prop(props, barrel2, p, randf() * TAU)
	var mil := MODELS + "old_military_crate/old_military_crate_1k.gltf"
	_prop(props, mil, Vector3(26.9, 0, 18.2), PI / 2)
	_prop(props, mil, Vector3(26.9, 0.26, 18.25), PI / 2 + 0.05)
	# An extinguisher at every other column.
	var ext := MODELS + "korean_fire_extinguisher_01/korean_fire_extinguisher_01_1k.gltf"
	for p in [Vector3(-27.4, 0, -13.4), Vector3(27.4, 0, 16.4), Vector3(13.4, 0, -27.4), Vector3(-13.4, 0, 27.4)]:
		_prop(props, ext, p, randf() * TAU)


## Dust drifting in the air over the heap and down the range: tiny lit specks, so they only show
## where a light falls, and the still air of the shed moves a little.
func _dust() -> void:
	var speck := QuadMesh.new()
	speck.size = Vector2(0.01, 0.01)
	var look := StandardMaterial3D.new()
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	look.albedo_color = Color(1.0, 0.95, 0.85, 0.05)  # faint: against the dark roof brighter specks read as stars
	look.roughness = 1.0
	speck.material = look
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color.WHITE)
	fade.add_point(0.8, Color.WHITE)
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	for zone in [[HEAP + Vector3(0, 3.5, 0), Vector3(12, 3.5, 12)]]:  # the range one starred its black roof
		var drift := ParticleProcessMaterial.new()
		drift.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		drift.emission_box_extents = zone[1]
		drift.direction = Vector3.UP
		drift.spread = 180.0
		drift.initial_velocity_min = 0.01
		drift.initial_velocity_max = 0.05
		drift.gravity = Vector3(0, -0.006, 0)
		drift.turbulence_enabled = true
		drift.turbulence_noise_scale = 6.0
		drift.turbulence_influence_min = 0.01
		drift.turbulence_influence_max = 0.04
		drift.scale_min = 0.6
		drift.scale_max = 1.5
		drift.color_ramp = ramp
		var p := GPUParticles3D.new()
		p.name = "Dust"
		p.position = zone[0]
		p.amount = 200  # more sprinkled the dark roof with "stars"
		p.lifetime = 24.0
		p.preprocess = 24.0
		p.process_material = drift
		p.draw_pass_1 = speck
		p.visibility_aabb = AABB(-zone[1] * 1.3, zone[1] * 2.6)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add(p)


## The firing line: a yellow steel railing wall to wall at GameState.FIRING_LINE_X, every target
## past it. Its collision is on the fence layer only: it stops players, rounds fly through.
func _firing_line() -> void:
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
	# Rusted bare steel (2026-10-29): the range's safety yellow went with the range.
	var paint := pbr_box("rust_coarse_01", 1.0, Color(0.62, 0.56, 0.52), true, "railing_rust")
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


## A plain box mesh under `parent`.
## Puts everything under `node` on GS.OVERHEAD_LAYER: the placement overview camera leaves it out,
## so from above the range reads like a plan (roof, lamps, the bay's lid and baffles gone).
func overhead(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = 1 << (GS.OVERHEAD_LAYER - 1)
	for c in node.get_children():
		overhead(c)


func block(size: Vector3, at: Vector3, mat: Material, parent: Node, basis := Basis()) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.transform = Transform3D(basis, at)
	add(m, parent)
	return m


func collide(size: Vector3, at: Vector3, parent: Node, basis := Basis()) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.transform = Transform3D(basis, at)
	add(cs, parent)


## Everything past the firing line that makes it read as a range (see BAY_END above).
func _range() -> void:
	var fl: float = GS.FIRING_LINE_X
	var range_node := Node3D.new()
	range_node.name = "Range"
	add(range_node)
	# Weathered plywood, four sheets' worth (2026-10-24, the user: weather it like the rest); no
	# lining any more, but range_dressing and zombie_bay take boards from these.
	for k in 4:
		worn("plywood", "plywood_%d" % k, {"tint": [Color(0.6, 0.57, 0.53), Color(0.52, 0.5, 0.48),
			Color(0.66, 0.62, 0.57), Color(0.5, 0.49, 0.48)][k], "tex_size": 1.1, "cell_size": 100.0, "cell_tone": 0.0,
			"odd_cells": 0.0, "antitile": 0.3, "grime": 0.6, "grime_scale": 0.12, "grime_color": Color(0.12, 0.11, 0.1)})
	var steel := pbr_box("metal_plate_02", 1.0, Color(0.3, 0.31, 0.33), true, "range_steel")
	var dark := pbr_box("metal_plate_02", 1.0, Color(0.1, 0.1, 0.11), true, "range_steel_dark")

	# 2026-10-29 (the user: "talim alanı olmayacak, zombilerin gelip öldüğü kıyım yeri"): the range's
	# plywood lining, distance lines and boards, shooting counter and baffles are gone; the bare
	# concrete walls of the hall and the bay show, zombie_bay dresses the rest.
	_bay(range_node, steel, dark)
	_light_bridge(range_node, dark)
	preload("res://tools/range_dressing.gd").new(self).build(range_node)
	preload("res://tools/zombie_bay.gd").new(self).build(range_node)
	# Steel threshold under the railing, where the hall's floor meets the yard's.
	block(Vector3(0.12, 0.01, 55.4), Vector3(fl, 0.005, 0), steel, range_node)


## The covered bay out through the east wall: concrete sides and back like the hall with the gates'
## openings left in them, a low dark ceiling, its tube lights (most dead) and a probe. No backstop any more: the floor runs flat to the back gate for the dead to walk.
func _bay(parent: Node, steel: Material, dark: Material) -> void:
	var concrete: Material = load("res://materials/env/concrete_slab_wall.tres")
	var body := StaticBody3D.new()
	body.name = "Bay"
	add(body, parent)
	var cx := (28.3 + BAY_END) / 2.0
	for s in [-1.0, 1.0]:
		var side := Node3D.new()
		side.transform = Transform3D(Basis(Vector3.UP, 0.0 if s < 0 else PI), Vector3(cx, 0, s * (BAY_HALF + 0.15)))
		add(side, body)
		for i in 4:
			if absf(cx - 6.0 + 4.0 * i - SIDE_GATE_X) > 0.1:  # the side gate's panel is left out
				mesh_at("wall_panel", Transform3D(Basis(), Vector3(-6.0 + 4.0 * i, 0, 0)), concrete, side)
		for run in [[28.0, SIDE_GATE_X - SIDE_GATE_HALF], [SIDE_GATE_X + SIDE_GATE_HALF, BAY_END]]:
			collide(Vector3(run[1] - run[0], 4.0, 0.3), Vector3((run[0] + run[1]) / 2.0, 2.0, s * (BAY_HALF + 0.15)), body)
	var back := Node3D.new()
	back.transform = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(BAY_END + 0.15, 0, 0))
	add(back, body)
	for i in 6:
		var along := -10.0 + 4.0 * i
		if absf(along) > MAIN_GATE_HALF:
			mesh_at("wall_panel", Transform3D(Basis(), Vector3(along, 0, 0)), concrete, back)
	for s in [-1.0, 1.0]:
		var w := BAY_HALF + 0.3 - MAIN_GATE_HALF
		collide(Vector3(0.3, 4.0, w), Vector3(BAY_END + 0.15, 2.0, s * (MAIN_GATE_HALF + w / 2.0)), body)
	# Ceiling: flat, painted near black, so the lit lane below is all there is to look at.
	var lid := Vector3(BAY_END + 0.3 - 28.0, 0.12, 2.0 * BAY_HALF + 0.6)
	var lid_at := Vector3((28.0 + BAY_END + 0.3) / 2.0, BAY_H + 0.06, 0)
	var ceiling := StaticBody3D.new()  # its own body: the placement overview's ray skips it
	ceiling.name = "BayCeiling"
	ceiling.add_to_group("overhead", true)
	add(ceiling, parent)
	var lid_mat := worn("corrugated_iron_02", "bay_ceiling", {"tint": Color(0.16, 0.16, 0.17), "tex_size": 1.5,
		"cell_size": 2.5, "cell_tone": 0.15, "odd_cells": 0.1, "grime": 0.4, "rust": 0.25})
	block(lid, lid_at, lid_mat, ceiling)
	for k in 5:  # transverse steel ribs every ~3.2 m hide where the sheets meet
		block(Vector3(0.12, 0.16, 2.0 * BAY_HALF), Vector3(28.9 + k * 3.25, BAY_H - 0.08, 0), dark, ceiling)
	collide(lid, lid_at, ceiling)
	# A steel lintel across the mouth, under the hall's ledger, and a deep girder up under the truss
	# ends from column to column, standing in for the columns taken out of the mouth.
	block(Vector3(0.3, 0.3, 2.0 * BAY_HALF + 0.6), Vector3(28.15, BAY_H - 0.15, 0), dark, ceiling)
	var girder: Material = load("res://materials/env/metal_plate_02.tres")
	block(Vector3(0.3, 0.7, 28.0), Vector3(27.85, BOTTOM - CHORD - 0.35, 0), girder, ceiling)

	# Tube lights flush on the ceiling between the baffles (Poly Haven "Mounted Fluorescent
	# Lights"), two tubes end to end per strip. Nobody has kept them up: most strips are dead and
	# dark, a few still give a weak green downlight, two of those failing (FLICKER blinks the strip's
	# `Diffuser` glass with its light). Strips by the gates are dead: the dead come out of darkness.
	var tube := _tube_mesh()
	var dead_tube := tube.duplicate() as Mesh
	for si in dead_tube.get_surface_count():
		var gm := dead_tube.surface_get_material(si) as BaseMaterial3D
		if gm and gm.emission_enabled:
			gm = gm.duplicate()
			gm.emission_enabled = false
			gm.albedo_color = gm.albedo_color.darkened(0.6)
			dead_tube.surface_set_material(si, gm)
	var edges: Array[float] = [28.3, 31.6, 34.9, 38.2, 41.5, BAY_END]
	const LIT := {"0,-3": 1.0, "0,9": 1.0, "1,3": 2.0, "2,-9": 1.0, "2,3": 1.0, "3,-3": 2.0}  # strip -> 1 lit, 2 failing
	for r in edges.size() - 1:
		var x := (edges[r] + edges[r + 1]) / 2.0
		for z: float in [-9.0, -3.0, 3.0, 9.0]:
			var fate: float = LIT.get("%d,%d" % [r, int(z)], 0.0)
			var strip := Node3D.new()
			strip.position = Vector3(x, BAY_H, z)
			add(strip, ceiling)
			for dz in [-0.46, 0.46]:
				var m := MeshInstance3D.new()
				m.mesh = tube if fate > 0.0 else dead_tube
				m.transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0, 0, dz))
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add(m, strip)
			if fate == 0.0:
				continue
			var light := SpotLight3D.new()
			light.position = Vector3(0, -0.08, 0)
			light.rotation.x = -PI / 2
			light.light_color = RANGE_LIGHT
			light.light_energy = 1.1
			light.spot_range = 7.0
			light.spot_attenuation = 0.7
			light.spot_angle = 70.0
			light.spot_angle_attenuation = 0.9
			light.light_volumetric_fog_energy = 0.0
			if fate == 2.0:  # failing: a glass bar of its own for FLICKER to dim
				var glass := MeshInstance3D.new()
				glass.name = "Diffuser"
				var bar := BoxMesh.new()
				bar.size = Vector3(1.6, 0.02, 0.05)
				glass.mesh = bar
				var glow := StandardMaterial3D.new()
				glow.albedo_color = Color(0.85, 0.95, 0.88)
				glow.emission_enabled = true
				glow.emission = RANGE_LIGHT
				glow.emission_energy_multiplier = 4.0
				glass.material_override = glow
				glass.position = Vector3(0, -0.035, 0)
				glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add(glass, strip)
				light.set_script(FLICKER)
			add(light, strip)
	# One flood just inside the mouth, the lane's only shadowed light, aimed on the back gate.
	_flood(parent, Vector3(28.7, BAY_H - 0.25, -2.0), Vector3(43.5, 1.2, 0.0), dark, 4.5, true)

	var probe := ReflectionProbe.new()
	probe.name = "BayReflections"
	probe.size = Vector3(BAY_END - 28.0, BAY_H + 0.2, 2.0 * BAY_HALF)
	probe.position = Vector3((28.0 + BAY_END) / 2.0, BAY_H / 2.0, 0)
	probe.box_projection = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add(probe, parent)


## One tube of Poly Haven's "Mounted Fluorescent Lights" (the set is seven in a row), saved on its
## own with the glass glowing: the set leaves the emissive factor at zero.
func _tube_mesh() -> Mesh:
	var path := MODELS + "mounted_fluorescent_lights/tube.res"
	var scene: Node = (load(MODELS + "mounted_fluorescent_lights/mounted_fluorescent_lights_1k.gltf") as PackedScene).instantiate()
	var src := scene.find_child("mounted_fluorescent_lights_d", true, false) as MeshInstance3D
	var mesh := src.mesh.duplicate() as ArrayMesh
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s) as BaseMaterial3D
		if m and m.resource_name.ends_with("glass"):
			m = m.duplicate()
			m.emission_enabled = true
			m.emission = RANGE_LIGHT
			m.emission_energy_multiplier = 5.0
			mesh.surface_set_material(s, m)
	scene.free()
	ResourceSaver.save(mesh, path)
	return load(path)


## A slim floodlight at `at` turned on `aim`: housing, cooling fins, glowing lens, a bracket up,
## and a spot of `colour` (shadowed when `shadow`).
func _flood(parent: Node, at: Vector3, aim: Vector3, paint: Material, energy: float, shadow: bool, round := false, colour := RANGE_LIGHT) -> void:
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color.WHITE
	lens.emission_enabled = true
	lens.emission = colour
	lens.emission_energy_multiplier = 2.2
	var lens_path := "res://materials/env/flood_lens%s.tres" % ("" if colour == RANGE_LIGHT else "_" + colour.to_html(false))
	ResourceSaver.save(lens, lens_path)
	lens = load(lens_path)
	var rig := Node3D.new()
	rig.position = at
	add(rig, parent)
	block(Vector3(0.05, 0.16, 0.05), Vector3(0, 0.1, 0), paint, rig)  # bracket up to the beam
	var head := Node3D.new()
	add(head, rig)
	head.basis = Basis.looking_at(aim - at, Vector3.UP)
	if round:  # a PAR can: a short drum with a round lens
		var along := Basis(Vector3.RIGHT, PI / 2)
		for part in [[0.13, 0.3, 0.0, paint], [0.115, 0.01, -0.152, lens]]:
			var m := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = part[0]
			c.bottom_radius = part[0]
			c.height = part[1]
			m.mesh = c
			m.material_override = part[3]
			m.transform = Transform3D(along, Vector3(0, 0, part[2]))
			add(m, head)
	else:
		block(Vector3(0.36, 0.24, 0.12), Vector3.ZERO, paint, head)
		for k in 4:
			block(Vector3(0.34, 0.012, 0.05), Vector3(0, -0.09 + k * 0.06, 0.08), paint, head)
		var glass := block(Vector3(0.32, 0.2, 0.01), Vector3(0, 0, -0.062), lens, head)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 0, -0.17 if round else -0.08)
	spot.light_color = colour
	spot.light_energy = energy
	spot.spot_range = 24.0
	spot.spot_attenuation = 0.5
	spot.spot_angle = 30.0 if round else 40.0  # the can throws a tighter pool
	spot.spot_angle_attenuation = 0.7
	spot.shadow_enabled = shadow
	spot.light_volumetric_fog_energy = 0.4  # a faint beam in the haze, like a real range
	add(spot, head)


## The light bridge: a steel beam hung from the trusses over the railing. Of the old rig's floods
## five still work, dirty sodium, aimed at odd spots down the range: pools of light with dark
## between, where the dead show up as they walk through. Two keep shadows. The red wave lamps
## on it are tools/zombie_bay.gd's.
func _light_bridge(parent: Node, dark: Material) -> void:
	var bx: float = GS.FIRING_LINE_X + 0.8
	var bridge := Node3D.new()
	bridge.name = "LightBridge"
	add(bridge, parent)
	block(Vector3(0.16, 0.2, 55.4), Vector3(bx, BRIDGE_Y, 0), dark, bridge)
	var drop := BOTTOM - CHORD - BRIDGE_Y - 0.1
	for z in BAYS.slice(1, BAYS.size() - 1):
		block(Vector3(0.03, drop, 0.03), Vector3(bx, BRIDGE_Y + 0.1 + drop / 2.0, z), dark, bridge)
	# [z, aim, round can, shadow, energy]; the dead ones keep their housings, lens dark.
	var rig := [[-21.9, Vector3(22.0, 0.3, -19.0), false, false, 3.2], [-12.1, null, true, false, 0.0],
		[-6.6, Vector3(25.5, 0.5, -3.5), false, true, 3.6], [-2.5, null, false, false, 0.0],
		[2.9, Vector3(34.0, 0.8, 4.0), true, true, 4.2], [11.6, Vector3(21.5, 0.3, 10.5), false, false, 3.0],
		[16.2, null, true, false, 0.0], [25.1, Vector3(24.0, 0.3, 22.0), false, false, 2.6]]
	for r in rig:
		var z: float = r[0]
		var at := Vector3(bx, BRIDGE_Y - 0.22, z)
		if r[1] == null:  # dead: the housing, its lens dark, hanging off true
			var hang := Node3D.new()
			hang.position = at
			hang.rotation = Vector3(0.5, 0.3 * signf(z), 0.15)
			add(hang, bridge)
			block(Vector3(0.36, 0.24, 0.12), Vector3.ZERO, dark, hang)
			block(Vector3(0.32, 0.2, 0.01), Vector3(0, 0, -0.062), dark, hang)
			continue
		_flood(bridge, at, r[1], dark, r[4], r[3], r[2], SODIUM)


func _range_label(text: String, size: int, colour: Color, font: Font = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if font:
		l.font = font
	l.font_size = size
	l.pixel_size = 0.0035
	l.modulate = colour
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	return l


## Stands for the crates (2026-10-22: stone plinths read as a museum): the army's pallets and olive
## crates, each under a factory pendant on one strut. Common: one pallet, one crate. Rare: two
## crates, a yellow band. Legendary: two pallets, steel corners and a hazard stripe. The final crate (12) has none: a big square on the floor
## and two crossing stage spots. Footprint and height grow along the row. Named ChestStand1..12
## (1 and 12 have no block); meta "height" is the top, and its Socket marker (group
## "chest_socket", meta "level") is where that level's crate is placed.
func _chest_stands() -> void:
	var olive: Material = worn("plywood", "crate_olive", {"tint": Color(0.78, 0.82, 0.58), "tex_size": 0.7,
		"cell_size": 0.5, "cell_tone": 0.12, "grime": 0.55, "grime_scale": 1.1})
	var wood: Material = load("res://materials/env/crate_wood.tres")
	var steel: Material = load("res://materials/env/range_steel.tres")
	var stands := Node3D.new()
	stands.name = "ChestStands"
	add(stands)
	var last := CHEST_COUNT - 2  # the last stand; the final crate has none
	var tops: Array[float] = []
	for i in CHEST_COUNT:
		var t := float(i - 1) / (last - 1)  # 0 at the first stack, 1 at the last
		var final := i == CHEST_COUNT - 1
		var top := 0.0 if i == 0 or final else lerpf(0.25, STAND_TOP, pow(t, 1.3))
		tops.append(top)
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
		_spilled_rounds(body, i + 1, FINAL_SQUARE if final else 2.0, 0.9 if final else (lerpf(0.75, 0.95, t) + 0.3) / 2.0 + 0.05)
		_haze(body, i + 1, FINAL_SQUARE if final else 2.0, top)
		if final:
			continue  # lit by its own two stage spots
		if i == 0:
			continue  # level 1 sits on the bare floor
		var w := lerpf(0.75, 0.95, t)  # top width, the crate's footing
		var rare := i >= RARE_FROM
		var legend := i >= LEGEND_FROM
		var y := 0.0
		for k in (2 if legend else 1):  # pallets: one, two under the legendary stacks
			y = _stand_pallet(body, y, w + 0.3, wood)
		# The crates: one on the common stands, two (the lower one wider) from rare up.
		var crates := 2 if rare and top - y > 0.4 else 1
		var h := (top - y) / crates
		for k in crates:
			var cw := w + (0.08 if k == 0 and crates == 2 else 0.0)
			_stand_crate(body, Vector3(cw, h, cw), y, olive, steel, rare, legend)
			y += h
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w + 0.3, top, w + 0.3)
		cs.shape = box
		cs.position.y = top / 2.0
		add(cs, body)
	_crate_lamps(tops)


## A timber pallet `size` m square, 14 cm high, from `y`; returns its top.
func _stand_pallet(body: Node3D, y: float, size: float, wood: Material) -> float:
	for k in 5:
		block(Vector3(size, 0.022, size * 0.15), Vector3(0, y + 0.129, (k - 2) * size * 0.22), wood, body)
	for k in 3:
		block(Vector3(size * 0.12, 0.098, size), Vector3((k - 1) * size * 0.44, y + 0.069, 0), wood, body)
		block(Vector3(size, 0.02, size * 0.12), Vector3(0, y + 0.01, (k - 1) * size * 0.44), wood, body)
	return y + 0.14


## An olive army crate `size`, standing on `y`: a lid band, rope handles; rare ones a yellow band, legendary ones steel corners and a hazard stripe.
func _stand_crate(body: Node3D, size: Vector3, y: float, olive: Material, steel: Material, rare: bool, legend: bool) -> void:
	block(size, Vector3(0, y + size.y / 2.0, 0), olive, body)
	if size.y > 0.16:
		block(Vector3(size.x + 0.02, 0.035, size.z + 0.02), Vector3(0, y + size.y - 0.03, 0), olive, body)  # lid
	for sx in [-1.0, 1.0]:  # rope handles on the sides
		block(Vector3(0.02, 0.03, 0.16), Vector3(sx * (size.x / 2.0 + 0.01), y + size.y * 0.6, 0), load("res://materials/env/paint_black.tres"), body)
	var front := size.z / 2.0 + 0.002
	if rare:
		var band := StandardMaterial3D.new()
		band.albedo_color = Color(0.78, 0.62, 0.12)
		band.roughness = 0.7
		block(Vector3(size.x, 0.05, 0.004), Vector3(0, y + size.y * 0.25, front), band, body)
	if legend:
		for sx in [-1.0, 1.0]:  # steel corner guards
			for sz in [-1.0, 1.0]:
				block(Vector3(0.05, size.y, 0.05), Vector3(sx * size.x / 2.0, y + size.y / 2.0, sz * size.z / 2.0), steel, body)
		var stripe := _decal_tex("hazard_stripe", 256, 32, func(img: Image) -> void:
			for py in 32:
				for px in 256:
					img.set_pixel(px, py, Color(0.86, 0.66, 0.08) if fposmod((px + py) / 20.0, 1.0) < 0.5 else Color(0.06, 0.06, 0.06)))
		var hz := StandardMaterial3D.new()
		hz.albedo_texture = stripe
		hz.roughness = 0.7
		block(Vector3(size.x - 0.06, 0.07, 0.004), Vector3(0, y + size.y * 0.78, front), hz, body)


## The crates' light (2026-10-25, the user, replacing the theatre spots on a track): rusty twin
## spot emergency lamps left on the floor round the row, one between each pair of crates,
## one eye on each, lighting them from below. Not set out in a line: some turned, some knocked
## over (LAMP_POSES). The tier is in the light: cold on the common crates, neutral from rare
## up, warm on the legendary ones and the final crate (which keeps its stage spots too).
func _crate_lamps(tops: Array[float]) -> void:
	var lamp := _twin_spot()
	var root := Node3D.new()
	root.name = "CrateLamps"
	add(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 25
	var box: AABB = (lamp.body as Mesh).get_aabb()
	var lenses := {}
	for n in CHEST_COUNT - 1:
		var pose: Vector3 = LAMP_POSES[n]
		var spot_at := LAMP_SPOTS[n] + Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
		var at := Vector3(CHEST_X + spot_at.x, 0, (chest_pos(n).z + chest_pos(n + 1).z) / 2.0 + spot_at.y)
		# Its front (+X, or the side the eyes lie on once knocked onto its back) toward its two crates.
		var to := (chest_pos(n) + chest_pos(n + 1)) / 2.0 - at
		var face := atan2(-to.z, to.x) + (PI if pose.y > 45.0 else 0.0)
		var basis := Basis(Vector3.UP, face + deg_to_rad(pose.x)) * Basis(Vector3.BACK, deg_to_rad(pose.y)) * Basis(Vector3.RIGHT, deg_to_rad(pose.z))
		var low := INF  # rest it on the floor by its lowest corner, standing or fallen
		for k in 8:
			low = minf(low, (basis * (box.get_endpoint(k) * TWIN_SPOT_SCALE)).y)
		var body := StaticBody3D.new()
		body.name = "CrateLamp%d" % (n + 1)
		body.transform = Transform3D(basis, at - Vector3(0, low, 0))
		add(body, root)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size * TWIN_SPOT_SCALE
		cs.shape = shape
		cs.position = box.get_center() * TWIN_SPOT_SCALE
		add(cs, body)
		var model := Node3D.new()
		model.scale = Vector3.ONE * TWIN_SPOT_SCALE
		add(model, body)
		var mi := MeshInstance3D.new()
		mi.mesh = lamp.body
		add(mi, model)
		# The eye nearer each crate looks at it (a fallen lamp has them the other way round).
		var heads: Array = lamp.heads.duplicate()
		heads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (body.transform * (a.at * TWIN_SPOT_SCALE)).z > (body.transform * (b.at * TWIN_SPOT_SCALE)).z)
		for k in 2:
			var head: Dictionary = heads[k]
			var ti := n + k  # chest_pos z falls with i: the larger-z eye takes crate n
			var target := chest_pos(ti) + Vector3(0, tops[ti] * 0.6 + 0.25, 0)  # low on the stand: the beam climbs the stack and spills on the floor before it
			var pivot: Vector3 = body.transform * (head.at * TWIN_SPOT_SCALE)
			var want := basis.inverse() * (target - pivot)
			var turn := Basis(Quaternion((head.fwd as Vector3).normalized(), want.normalized()))
			var colour := Color(1.0, 0.78, 0.45) if ti >= LEGEND_FROM else (Color(1.0, 0.93, 0.82) if ti >= RARE_FROM else Color(0.85, 0.92, 1.0))
			if not lenses.has(colour):
				var lens := StandardMaterial3D.new()
				lens.albedo_texture = load(TWIN_SPOT + "heads_albedo.png")
				lens.emission_enabled = true
				lens.emission = colour
				lens.emission_energy_multiplier = 1.2  # a warm glass, not a flash: higher bloomed into a blown-out star
				lenses[colour] = lens
			var hi := MeshInstance3D.new()
			hi.name = "Eye%d" % (k + 1)
			hi.mesh = head.mesh
			hi.transform = Transform3D(turn, head.at)
			hi.set_surface_override_material(1, lenses[colour])
			add(hi, model)
			var spot := SpotLight3D.new()
			spot.name = "%s_Eye%d" % [body.name, k + 1]
			var from: Vector3 = body.transform * ((head.at + turn * head.lens) * TWIN_SPOT_SCALE)
			spot.transform = Transform3D(Basis.looking_at(target - from), from)
			spot.light_color = colour
			spot.light_energy = 4.5 if ti >= LEGEND_FROM else (3.8 if ti >= RARE_FROM else 3.2)  # half what they were: the crate fronts burnt out white
			spot.spot_range = 7.0
			spot.spot_angle = 34.0
			spot.spot_angle_attenuation = 2.2  # a soft-edged wash, no hard bright core
			spot.light_volumetric_fog_energy = 1.0  # the beams show in the crates' dust (_haze)
			spot.shadow_enabled = false  # 22 of them; each crate already sits in its own pool
			add(spot, root)


## The twin spot's parts, cut from its FBX once per build and saved as meshes: the body (box, top
## bar, the eyes' swivel posts) from its bottom centre, and the two eyes (housing, glass as
## surface 1) round their swivels, each with `at` (its swivel), `fwd` (where it looks) and `lens`
## (its glass from the swivel), all in model units.
func _twin_spot() -> Dictionary:
	var scene: Node = (load(TWIN_SPOT + "twin_spot_light.fbx") as PackedScene).instantiate()
	var steel := StandardMaterial3D.new()
	steel.albedo_texture = load(TWIN_SPOT + "body_albedo.png")
	steel.normal_enabled = true
	steel.normal_texture = load(TWIN_SPOT + "body_normal.png")
	steel.roughness_texture = load(TWIN_SPOT + "body_rough.png")
	steel.metallic = 1.0
	steel.metallic_texture = load(TWIN_SPOT + "body_metal.png")
	ResourceSaver.save(steel, TWIN_SPOT + "body.tres")
	steel = load(TWIN_SPOT + "body.tres")
	var centre := func(part: String) -> Vector3:
		var mi: MeshInstance3D = scene.get_node(part)
		var c := Vector3.ZERO
		var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for p in v:
			c += mi.transform * p
		return c / v.size()
	var bake := func(parts: Array, origin: Vector3, save_as: String) -> ArrayMesh:
		var out := ArrayMesh.new()
		for part: String in parts:
			var mi: MeshInstance3D = scene.get_node(part)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.append_from(mi.mesh, 0, Transform3D(Basis(), -origin) * mi.transform)
			st.commit(out)
			out.surface_set_material(out.get_surface_count() - 1, steel)
		ResourceSaver.save(out, TWIN_SPOT + save_as + ".res")
		return load(TWIN_SPOT + save_as + ".res")
	var bottom := Vector3(-0.59, -1.004, 0.52)  # the box's bottom centre
	var out := {"body": bake.call(["Cube_001", "Cube_003", "Cylinder_002", "Cylinder_004"], bottom, "body"), "heads": []}
	for eye in [["Cylinder_002", "light frame", "light glass", "eye_a"], ["Cylinder_004", "light frame_001", "light glass_001", "eye_b"]]:
		var swivel: Vector3 = centre.call(eye[0])
		var glass: Vector3 = centre.call(eye[2])
		out.heads.append({"mesh": bake.call([eye[1], eye[2]], swivel, eye[3]), "at": swivel - bottom,
			"fwd": glass - centre.call(eye[1]), "lens": glass - swivel})
	scene.free()
	return out


## A steel lighting strut along z at `x`, bolted under the trusses' bottom chords from `z0` to
## `z1`: what the pendants hang from (2026-10-22: lamps hung on bare cords from nowhere).
func strut(x: float, z0: float, z1: float) -> void:
	var steel: Material = load("res://materials/env/range_steel_dark.tres")
	var y := BOTTOM - CHORD / 2.0 - 0.04
	block(Vector3(0.05, 0.05, absf(z1 - z0)), Vector3(x, y, (z0 + z1) / 2.0), steel, arena)
	for z: float in BAYS:  # a clamp at every chord it crosses
		if z > minf(z0, z1) - 0.01 and z < maxf(z0, z1) + 0.01:
			block(Vector3(0.12, 0.1, 0.1), Vector3(x, y + 0.05, z), steel, arena)


## The office pack's enamel pendant on its rod (tools/build_office.py), and from the rod's top a
## chain and cable carried on up to the strut over it at `anchor_y`, so it hangs from something.
## `top` is where the rod ends; the shade's rim is LAMP_DROP below, a bulb in it glowing `colour`.
## A spot shines down from it, `beam` > 0 also draws its cone in the dust.
func pendant(top: Vector3, anchor_y: float, colour: Color, energy: float, angle: float, beam := 0.0, shadow := false) -> Node3D:
	var lamp := ceiling_lamp(arena)
	lamp.position = top
	var glow := StandardMaterial3D.new()
	glow.albedo_color = colour
	glow.emission_enabled = true
	glow.emission = colour
	glow.emission_energy_multiplier = 14.0
	bulb(lamp, glow)
	var metal: Material = load("res://materials/env/range_steel_dark.tres")
	# The chain on up: long oval links, every other one turned a quarter, like the model's own.
	var link := TorusMesh.new()
	link.inner_radius = 0.009
	link.outer_radius = 0.016
	link.rings = 10
	link.ring_segments = 6
	var length := anchor_y - top.y
	var n := int(length / 0.05) + 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link
	mm.instance_count = n
	for i in n:
		var b := Basis(Vector3.UP, (i % 2) * PI / 2) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(1.0, 1.0, 1.9))
		mm.set_instance_transform(i, Transform3D(b, Vector3(0, 0.03 + i * 0.05, 0)))
	var chain := MultiMeshInstance3D.new()
	chain.multimesh = mm
	chain.material_override = metal
	chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(chain, lamp)
	# The cable from its rose (4 cm off the chain) up the same way, and a shackle on the strut.
	var cable := CylinderMesh.new()
	cable.top_radius = 0.006
	cable.bottom_radius = 0.006
	cable.height = length
	cable.radial_segments = 6
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.03, 0.03, 0.03)
	cord.roughness = 0.6
	var c := MeshInstance3D.new()
	c.mesh = cable
	c.material_override = cord
	c.position = Vector3(0.045, length / 2.0, 0)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(c, lamp)
	block(Vector3(0.06, 0.04, 0.06), Vector3(0, length - 0.02, 0), metal, lamp)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, BULB_Y, 0)
	spot.rotation.x = -PI / 2
	spot.light_color = colour
	spot.light_energy = energy
	spot.spot_range = 9.0
	spot.spot_angle = angle
	spot.spot_angle_attenuation = 0.8
	spot.light_volumetric_fog_energy = 0.4
	spot.shadow_enabled = shadow
	add(spot, lamp)
	if beam > 0.0:
		var drop := top.y - LAMP_DROP
		var cone := CylinderMesh.new()
		cone.top_radius = 0.26  # the shade's rim
		cone.bottom_radius = 0.26 + drop * tan(deg_to_rad(angle)) * 0.75
		cone.height = drop
		cone.radial_segments = 32
		cone.cap_top = false
		cone.cap_bottom = false
		var m := ShaderMaterial.new()
		m.shader = load("res://materials/light_cone.gdshader")
		m.set_shader_parameter("color", Color(colour.r, colour.g, colour.b))
		m.set_shader_parameter("strength", beam)
		m.set_shader_parameter("edge_softness", 2.0)
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = m
		mi.position.y = -LAMP_DROP - drop / 2.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add(mi, lamp)
	return lamp


## Poly Haven's olive enamel factory pendant (CC0), origin at its rod's top, the shade's rim
## LAMP_DROP below. Its own bulb's glow is switched off (bulb() is the one that lights, dies and
## flickers) and its glass, which Godot can't transmit through, is swapped for a clear one.
## A plain mesh, not the glTF's scene: edits to an instanced scene's children aren't saved in arena.tscn.
func ceiling_lamp(parent: Node) -> Node3D:
	var path := MODELS + "hanging_industrial_lamp/lamp.res"
	if not _lamp_saved:  # once per build
		_lamp_saved = true
		var scene: Node = (load(MODELS + "hanging_industrial_lamp/hanging_industrial_lamp_1k.gltf") as PackedScene).instantiate()
		var mesh := (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.duplicate() as ArrayMesh
		scene.free()
		var shade := mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		shade.emission_enabled = false
		mesh.surface_set_material(0, shade)
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.95, 0.93, 0.88, 0.15)
		glass.roughness = 0.08
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(1, glass)
		ResourceSaver.save(mesh, path)
	var lamp := Node3D.new()
	lamp.name = "Pendant"
	var mi := MeshInstance3D.new()
	mi.mesh = load(path)
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # its own spot shines from inside it
	add(lamp, parent)
	add(mi, lamp)
	return lamp


## The bulb in a ceiling_lamp()'s glass, lit by `lens` (flicker_lamp.gd dims it by this name). A
## lit one carries a short warm light that fills the reflector and the glass from inside, so the
## lamp reads as lit by its bulb, not as a disc with light coming out from under it.
func bulb(lamp: Node3D, lens: Material, lit := true) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 0.048
	s.height = 0.135  # over the model's bulb, a pear, not a ball
	var d := MeshInstance3D.new()
	d.name = "Diffuser"
	d.mesh = s
	d.material_override = lens
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.position.y = BULB_Y
	add(d, lamp)
	if lit:
		var fill := OmniLight3D.new()
		fill.name = "Fill"
		fill.light_color = (lens as StandardMaterial3D).emission
		fill.light_energy = 1.2
		fill.omni_range = 0.75  # the shade and its glass, nothing past the rim
		fill.omni_attenuation = 1.5
		fill.light_volumetric_fog_energy = 0.0
		fill.light_specular = 0.3
		add(fill, d)
	return d


## A box with rounded edges and a little noise pushed into its faces, centred on the origin.
## `edge` is the edge radius (a mason's chamfer by default, a stuffed sandbag when large) and
## `bump` how far the faces swell and dip.
func _stone_block(size: Vector3, noise_seed: int, edge := 0.02, bump := 0.003) -> ArrayMesh:
	const N := 14  # quads per face edge
	var r := minf(edge, size.y * 0.45)  # a 10 cm block can't take full-size rounding
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
		return v + n * noise.get_noise_3dv(v) * bump
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


func _prop(parent: Node, path: String, pos: Vector3, yaw: float, s := 1.0, tilt := Basis()) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = Transform3D((Basis(Vector3.UP, yaw) * tilt).scaled(Vector3.ONE * s), pos)
	add(body, parent)
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	# Parts lying wholly under the floor are leftovers (hopper.glb has rounds a physics sim dropped
	# 100 m down): they'd stretch the collision box into a wall over the whole corner.
	_drop_buried(inst, Transform3D())
	add(inst, body)
	var b := _aabb(inst, Transform3D())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = b.size
	cs.shape = box
	cs.position = b.get_center()
	add(cs, body)
	return body


func _drop_buried(n: Node, xf: Transform3D) -> void:
	var t := xf * (n as Node3D).transform if n is Node3D else xf
	for c in n.get_children():
		_drop_buried(c, t)
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (t * (n as MeshInstance3D).mesh.get_aabb()).end.y < -0.5:
		n.free()


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var t := xf * (n as Node3D).transform if n is Node3D else xf
	var out := AABB()
	var empty := true
	# Loose bits (single rounds strewn round hopper.glb) don't count: they made a wall in front of it.
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as MeshInstance3D).mesh.get_aabb().get_longest_axis_size() * t.basis.get_scale().x > 0.15:
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

	# Ring: radius 9.6 m (heap 8.6 m + spill), 12 cm line and a thinner one 35 cm outside.
	var ring_px := 1536
	var ring_m := 20.4
	var ring := _decal_tex("ring", ring_px, ring_px, func(img: Image) -> void:
		var c := ring_px * 0.5
		for y in ring_px:
			for x in ring_px:
				var r := Vector2(x - c, y - c).length() * ring_m / ring_px
				var a := 0.0
				if absf(r - 9.6) < 0.06:
					a = 1.0
				elif absf(r - 9.95) < 0.03:
					a = 0.8
				if a > 0.0:
					img.set_pixel(x, y, Color(paint, a * worn.call(x * 1.0, y * 1.0))))
	_decal(marks, ring, HEAP, 0.0, Vector3(ring_m, 1.0, ring_m))

	var line := _decal_tex("line", 16, 2048, func(img: Image) -> void:
		for y in 2048:
			for x in 16:
				img.set_pixel(x, y, Color(paint, worn.call(x * 0.5, y * 1.5))))
	for side: int in [0, 2, 3]:  # walkways 1.8 m in from each wall; north and south stop short of the range
		var yaw := side * PI / 2.0
		var along := 0.0 if side == 3 else -6.0
		var at := Basis(Vector3.UP, yaw) * Vector3(0, 0, 25.9) + Vector3(along, 0, 0)
		_decal(marks, line, at, yaw + PI / 2.0, Vector3(0.1, 1.0, 50.0 if side == 3 else 38.0))

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
		if p.distance_to(HEAP) < 12.0 or p.x > GS.FIRING_LINE_X - 1.5:
			continue  # under or next to the heap, or on the range's rubber
		var s := rng.randf_range(0.8, 2.6)
		_decal(marks, stain, p, rng.randf() * TAU, Vector3(s, 1.0, s * rng.randf_range(0.6, 1.0)))
		placed += 1
	# Big faint wear patches: break up the floor scan's repeat at a scale it never tiles at.
	placed = 0
	while placed < 18:
		var p := Vector3(rng.randf_range(-26, 26), 0, rng.randf_range(-26, 26))
		if p.distance_to(HEAP) < 11.0 or p.x > GS.FIRING_LINE_X - 3.0:
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
			if side == 1 and absf(along) < BAY_HALF + 1.6:
				continue  # the east wall is open over the range bay
			var d := Decal.new()
			d.texture_albedo = streak
			d.size = Vector3(rng.randf_range(1.2, 3.2), 0.6, h)
			d.transform = Transform3D(into, face + b * Vector3(along, 0, 0) + Vector3(0, 4.0 - h / 2.0, 0))
			d.modulate = Color(1, 1, 1, rng.randf_range(0.5, 1.0))
			d.cull_mask = 1
			add(d, parent)
		for run in ([[-20.0, 16.0], [20.0, 16.0]] if side == 1 else [[0.0, 56.0]]):
			var f := Decal.new()
			f.texture_albedo = foot
			f.size = Vector3(run[1], 0.6, 0.9)
			f.transform = Transform3D(into, face + b * Vector3(run[0], 0, 0) + Vector3(0, 0.45, 0))
			f.cull_mask = 1
			add(f, parent)


## Age on a sign `size` m facing `out`: dust and grime over the board, sun-bleached patches,
## rust run from its two top bolts down the wall below.
func sign_grime(parent: Node, at: Vector3, out: Vector3, size: Vector2) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 52
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	var tex := _decal_tex("sign_grime", 256, 512, func(img: Image) -> void:
		for y in 512:
			for x in 256:
				var n := noise.get_noise_2d(x, y)
				var c := Color(0, 0, 0, 0)
				if y < 256:  # the board (row 0 is its top)
					var edge := minf(minf(x, 255 - x), minf(y, 255 - y))
					var a := clampf(0.25 + n * 0.8, 0.0, 1.0) * 0.55 + 0.35 * smoothstep(40.0, 0.0, edge)
					c = Color(0.16, 0.13, 0.09, a) if n > -0.15 else Color(0.8, 0.78, 0.7, 0.3)
				for bolt in [22.0, 234.0]:  # rust run from the bolts, down past the board
					var dx := absf(x - bolt - sin(y * 0.05) * 3.0)
					if y > 14 and dx < 5.0 + y * 0.012:
						var run := (1.0 - (y - 14) / 498.0) * smoothstep(5.0 + y * 0.012, 0.0, dx)
						c = c.blend(Color(0.4, 0.17, 0.06, run * (0.6 + 0.4 * n)))
				img.set_pixel(x, y, c))
	var up := Vector3.UP
	var basis := Basis(out.cross(up), out, -up)  # decal +Y out of the wall, texture top up
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(size.x * 1.04, 0.12, size.y * 2.08)
	d.transform = Transform3D(basis, at - Vector3(0, size.y * 0.52, 0))
	d.modulate = Color(1, 1, 1, randf_range(0.7, 1.0))
	d.cull_mask = 1
	add(d, parent)


func _decal(parent: Node, tex: Texture2D, pos: Vector3, yaw: float, size: Vector3) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = size
	d.position = pos
	d.rotation.y = yaw
	d.upper_fade = 0.1
	d.lower_fade = 0.1
	d.cull_mask = FLOOR_PAINT  # the floor only: crates, cables and the railing standing in it stay clean
	add(d, parent)
	return d


## Cheaper to draw (2026-10-24, the user: "the game got heavy"): small things stop drawing a little
## way off (a can at 25 m is a pixel; 2,300 meshes made 3,400 draw calls), cast no shadow when tiny,
## small decals fade out with distance, and lights smaller than a room stay out of the fog.
func _lighten(n: Node, parent_xf: Transform3D) -> void:
	var xf := parent_xf * (n as Node3D).transform if n is Node3D else parent_xf
	for c in n.get_children():
		_lighten(c, xf)
	if n is GeometryInstance3D and not n is MultiMeshInstance3D:
		var g := n as GeometryInstance3D
		var size := g.get_aabb().size.length() * xf.basis.get_scale().x
		if size < 0.5:
			g.visibility_range_end = 18.0
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif size < 1.2:
			g.visibility_range_end = 30.0
		elif size < 2.5:
			g.visibility_range_end = 45.0
		if g.visibility_range_end > 0.0:
			g.visibility_range_end_margin = 2.0  # hysteresis: no flicker at the edge
	elif n is Decal:
		var d := n as Decal
		var size := Vector2(d.size.x, d.size.z).length()
		if size < 4.0:
			d.distance_fade_enabled = true
			d.distance_fade_begin = 16.0 if size < 1.5 else 30.0
			d.distance_fade_length = 6.0
	elif n is OmniLight3D and (n as OmniLight3D).omni_range < 3.5:
		var l := n as OmniLight3D
		l.light_volumetric_fog_energy = 0.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 25.0
		l.distance_fade_length = 5.0


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
		m.position = SPAWNS[i]
		m.basis = Basis.looking_at(Vector3(HEAP.x, 0, HEAP.z) - SPAWNS[i])
		add(m, spawns)
		m.add_to_group("spawn", true)
	var table := _prop(spawns, MODELS + "metal_office_desk/metal_office_desk_1k.gltf", GUN_TABLE, PI / 2.0)
	table.name = "GunTable"
	table.set_script(preload("res://scripts/gun_table.gd"))
