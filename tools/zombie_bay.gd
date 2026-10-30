extends RefCounted
## The range as the place the dead come in (2026-10-29, the user: zombie waves; "orayı komple
## baştan dizayn et"). Called from tools/build_arena.gd _range after range_dressing.
##
## Gates: the bay's back wall has a double sliding gate that parts in the middle (the user's pick),
## each side wall a lifting shutter; behind each a dark holding pen where the dead pile up. Every
## moving leaf (two for the main gate) is an AnimatableBody3D in group "wave_gate" with meta "gate"
## (main / north / south), "slide_dir" (world direction it opens along), "slide_dist" (m),
## "open_offset" (the two multiplied: the translation that opens it), "mouth" (global point on the
## range just inside it); the main gate's two also "leaf" (north / south). Its decals are its
## children and move with it. Spawn points: Marker3D in group "wave_spawn" in the pens, meta "gate" the same names.
## The floor from every gate to the railing is flat and free of anything that collides.
##
## Wave alarms (group "wave_alarm", meta "kind" beacon / lamp) are built dark: their lights are
## hidden and every glass mesh carries its lit look in meta "lit_material". To light one: show its
## Light3D children and set each such mesh's material_override to that meta; a beacon's "Spin"
## child turns about its local Y. Wave code does all of that (game side), nothing here moves.
##
## The wave lever (group "wave_lever") hangs on the hall's north wall by the railing, the players'
## side, at GameState.LEVER_POS: "Old lever" on a steel plate, the mechanical sign over it with
## its "Number" (the wave, on flip plates) and "Status" labels. scripts/waves.gd pulls it, plays its
## AnimationPlayer's one clip (up -> down) and writes the sign.
##
## Calm light: a few dirty sodium floods on the bridge and dying green tubes in the bay
## (build_arena), burning tyre stacks with their firelight, haze lying in the bay. The gore: blood
## pools, drag trails into the gates, spatter and claw marks on the gates and walls, scattered bones
## (Smithsonian scans, CC0), meat, rubbish, the survivors' dropped tools.

const MODELS := "res://assets/env/models/"
const BONES := "res://assets/env/bones/"
const GORE := "res://materials/env/gore/"
const ALARM_RED := Color(1.0, 0.07, 0.03)
## Bone pieces and how much bigger than the deer they came from (read as human at a distance).
const BONE_KINDS := {"skull": 1.0, "mandible": 1.0, "rib": 2.0, "humerus": 1.8, "pelvis": 1.9,
	"scapula": 1.8, "vertebra_lumbar": 1.5, "vertebra_thoracic": 1.5}

var b  # the arena builder (tools/build_arena.gd)
var root: Node3D
var rng := RandomNumberGenerator.new()
var dark: Material
var frame_static: Material
var frame_moving: Material
var stripe: Material
var concrete: Material
var meat_mat: Material
var _bone := {}  # kind -> [mesh, fix transform, resting half height]
var _bone_xf := {}  # kind -> Array[Transform3D] (MultiMesh instances)
var _bone_tint := {}  # kind -> Array[Color]
var _meat: Array[Mesh] = []
var _meat_xf: Array = [[], [], [], []]
var _blood := {}  # name -> Texture2D


func _init(builder) -> void:
	b = builder


func build(parent: Node) -> void:
	rng.seed = 2910
	root = Node3D.new()
	root.name = "ZombieBay"
	b.add(root, parent)
	DirAccess.make_dir_recursive_absolute(GORE)
	dark = b.pbr_box("metal_plate_02", 1.0, Color(0.1, 0.1, 0.11), true, "range_steel_dark")
	frame_static = b.pbr_box("rust_coarse_01", 1.2, Color(0.75, 0.68, 0.62), true, "gate_frame")
	frame_moving = b.pbr_box("rust_coarse_01", 1.2, Color(0.7, 0.64, 0.58), false, "gate_frame_leaf")
	concrete = b.pbr_box("dirty_concrete", 2.5, Color(0.55, 0.53, 0.5), true, "pen_concrete")
	var hazard := StandardMaterial3D.new()
	hazard.albedo_texture = load("res://materials/env/decals/hazard.res")
	hazard.uv1_scale = Vector3(1.0, 8.0, 1.0)
	hazard.albedo_color = Color(0.65, 0.6, 0.55)
	hazard.roughness = 0.8
	stripe = hazard
	_blood_textures()
	_main_gate()
	_side_gate(-1.0)
	_side_gate(1.0)
	_pens()
	_spawns()
	_alarms()
	_lever()
	_fires()
	_haze()
	_gore()
	_debris()
	_chains()
	_flush_multimeshes()


# --- gates ----------------------------------------------------------------------------------------

## The back wall's gate (2026-10-29, the user: a double sliding gate that parts in the middle):
## two leaves of rusted corrugated iron on steel frames, each braced with an X, a hazard kick plate
## along the foot, a rubber seal and a drop bolt where they meet; they roll on one rail behind the
## wall and part to either side, out of sight behind the wall's concrete.
func _main_gate() -> void:
	var x: float = b.BAY_END
	var half: float = b.MAIN_GATE_HALF
	var frame := StaticBody3D.new()
	frame.name = "MainGateFrame"
	b.add(frame, root)
	for s in [-1.0, 1.0]:  # jambs: steel posts boxed into the concrete either side
		b.block(Vector3(0.36, 4.0, 0.3), Vector3(x + 0.15, 2.0, s * (half - 0.15)), frame_static, frame)
		b.collide(Vector3(0.36, 4.0, 0.3), Vector3(x + 0.15, 2.0, s * (half - 0.15)), frame)
	b.block(Vector3(0.36, 0.45, 2.0 * half), Vector3(x + 0.15, 3.775, 0), frame_static, frame)  # header
	b.collide(Vector3(0.36, 0.45, 2.0 * half), Vector3(x + 0.15, 3.775, 0), frame)
	b.block(Vector3(0.5, 0.012, 2.0 * half), Vector3(x + 0.1, 0.006, 0), dark, frame)  # threshold plate
	b.block(Vector3(0.12, 0.05, 16.2), Vector3(x + 0.5, 0.025, 0), dark, frame)  # bottom rail, out to where both open
	b.block(Vector3(0.12, 0.14, 16.2), Vector3(x + 0.5, 3.68, 0), dark, frame)  # top track
	for z in [-7.6, -4.2, 4.2, 7.6]:  # the track's hangers off the wall
		b.block(Vector3(0.24, 0.06, 0.06), Vector3(x + 0.42, 3.78, z), dark, frame)
	for z in [-8.05, 8.05]:  # end stops
		b.block(Vector3(0.14, 0.18, 0.06), Vector3(x + 0.5, 0.09, z), dark, frame)
	var sheet: Material = b.pbr_box("rusty_corrugated_iron", 1.4, Color(0.9, 0.85, 0.8), false, "gate_corrugated")
	const W := 3.85  # each leaf: from the middle to 15 cm behind its jamb
	const H := 3.6
	const SLIDE := 3.9  # clears the jamb's inner face (3.7 m off the middle) by 20 cm
	for s in [-1.0, 1.0]:
		var leaf := _leaf("MainGate" + ("N" if s < 0 else "S"), "main", Vector3(x + 0.5, 0, s * W / 2.0), Vector3(0, 0, s), SLIDE, Vector3(x - 1.2, 0, 0))
		leaf.set_meta("leaf", "north" if s < 0 else "south")
		var meet: float = -s * W / 2.0  # the leaf's edge at the middle, leaf space
		var away: float = -s  # from that edge into the leaf
		b.block(Vector3(0.05, H - 0.1, W), Vector3(0, H / 2.0, 0), sheet, leaf)
		# Frame on the bay face (-x): rails, stiles, an X across the leaf.
		var f := -0.09
		for y in [0.08, 1.25, 2.4, H - 0.06]:
			b.block(Vector3(0.12, 0.12, W), Vector3(f, y, 0), frame_moving, leaf)
		for z in [-W / 2.0 + 0.06, W / 2.0 - 0.06]:
			b.block(Vector3(0.12, H, 0.12), Vector3(f, H / 2.0, z), frame_moving, leaf)
		var span := Vector2(W - 0.12, H - 0.14)
		var ang := atan2(span.y, span.x)
		for d in [-1.0, 1.0]:
			b.block(Vector3(0.06, 0.08, span.length()), Vector3(f + 0.02, H / 2.0, 0), frame_moving, leaf,
				Basis(Vector3.RIGHT, d * (PI / 2.0 - ang)))
		b.block(Vector3(0.012, 0.32, W - 0.1), Vector3(-0.16, 0.24, 0), stripe, leaf)  # kick plate
		if s < 0:  # the north leaf carries the rubber seal and the drop bolt
			b.block(Vector3(0.1, H - 0.05, 0.04), Vector3(-0.02, H / 2.0, meet + 0.02), _rubber(), leaf)
			b.block(Vector3(0.03, 0.7, 0.03), Vector3(-0.19, 0.42, meet - 0.18), dark, leaf)
			for y in [0.25, 0.65]:
				b.block(Vector3(0.06, 0.04, 0.06), Vector3(-0.17, y, meet - 0.18), dark, leaf)
		else:  # the south one a steel channel to meet them
			b.block(Vector3(0.16, H, 0.03), Vector3(-0.03, H / 2.0, meet + 0.015), frame_moving, leaf)
		b.block(Vector3(0.05, 0.9, 0.05), Vector3(-0.2, 1.2, meet + 0.45 * away), dark, leaf)  # pull handle
		for zz in [-1.3, 1.3]:  # rollers on the rail
			var wheel := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.09
			c.bottom_radius = 0.09
			c.height = 0.06
			wheel.mesh = c
			wheel.material_override = dark
			wheel.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.09, zz))
			b.add(wheel, leaf)
		b.collide(Vector3(0.3, H, W), Vector3(-0.06, H / 2.0, 0), leaf)
		# The dead have been at it: claw gouges low on it, smears and spatter.
		for i in 4:
			_on_leaf(leaf, _blood.claw, Vector3(-0.22, rng.randf_range(0.5, 1.6), rng.randf_range(-1.6, 1.6)), Vector3.LEFT, rng.randf_range(0.5, 0.9))
		for i in 3:
			_on_leaf(leaf, _blood["run_%d" % (i % 3)], Vector3(-0.22, rng.randf_range(0.9, 1.9), rng.randf_range(-1.5, 1.5)), Vector3.LEFT, rng.randf_range(0.8, 1.3))
		for i in 2:
			_on_leaf(leaf, _blood["splat_%d" % (i % 3)], Vector3(-0.22, rng.randf_range(0.6, 2.4), rng.randf_range(-1.4, 1.4)), Vector3.LEFT, rng.randf_range(0.6, 1.1))


var _rubber_mat: Material


func _rubber() -> Material:
	if not _rubber_mat:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.035, 0.033, 0.03)
		m.roughness = 0.85
		_rubber_mat = m
	return _rubber_mat


## A side wall's gate: a rusted shutter that lifts straight up into the dark over the bay's ceiling,
## two lift handles at its foot, a hazard bar; steel jambs and header boxed into the concrete.
func _side_gate(s: float) -> void:
	var gx: float = b.SIDE_GATE_X
	var half: float = b.SIDE_GATE_HALF
	var wz: float = s * (b.BAY_HALF + 0.15)
	var frame := StaticBody3D.new()
	frame.name = "SideGateFrame%s" % ("N" if s < 0 else "S")
	b.add(frame, root)
	for e in [-1.0, 1.0]:
		b.block(Vector3(0.3, 4.0, 0.36), Vector3(gx + e * (half - 0.15), 2.0, wz), frame_static, frame)
		b.collide(Vector3(0.3, 4.0, 0.36), Vector3(gx + e * (half - 0.15), 2.0, wz), frame)
	b.block(Vector3(2.0 * half, 0.7, 0.36), Vector3(gx, 3.65, wz), frame_static, frame)
	b.collide(Vector3(2.0 * half, 0.7, 0.36), Vector3(gx, 3.65, wz), frame)
	b.block(Vector3(2.0 * half, 0.012, 0.5), Vector3(gx, 0.006, wz - s * 0.05), dark, frame)
	var gate_name := "north" if s < 0 else "south"
	var leaf := _leaf("SideGate%s" % ("N" if s < 0 else "S"), gate_name, Vector3(gx, 0, s * (b.BAY_HALF + 0.42)),
		Vector3.UP, 3.35, Vector3(gx, 0, s * (b.BAY_HALF - 1.2)))
	leaf.basis = Basis(Vector3.UP, 0.0 if s > 0 else PI)  # local -z looks into the bay
	var shutter: Material = b.pbr_box("rusted_shutter", 1.1, Color(0.85, 0.82, 0.8), false, "gate_shutter")
	const W := 3.7
	const H := 3.4
	b.block(Vector3(W, H, 0.06), Vector3(0, H / 2.0, 0), shutter, leaf)
	b.block(Vector3(W, 0.12, 0.1), Vector3(0, 0.06, -0.02), frame_moving, leaf)  # bottom bar
	b.block(Vector3(W - 0.1, 0.2, 0.012), Vector3(0, 0.25, -0.05), stripe, leaf)
	for e in [-1.0, 1.0]:
		b.block(Vector3(0.18, 0.03, 0.06), Vector3(e * 1.1, 0.42, -0.08), dark, leaf)  # lift handles
		for k in [-1.0, 1.0]:
			b.block(Vector3(0.03, 0.08, 0.05), Vector3(e * 1.1 + k * 0.08, 0.39, -0.06), dark, leaf)
	b.collide(Vector3(W, H, 0.24), Vector3(0, H / 2.0, -0.04), leaf)
	for i in 4:
		_on_leaf(leaf, _blood.claw, Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(0.4, 1.5), -0.14), Vector3.FORWARD, rng.randf_range(0.5, 0.8))
	for i in 3:
		_on_leaf(leaf, _blood["run_%d" % (i % 3)], Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(1.0, 2.0), -0.14), Vector3.FORWARD, rng.randf_range(0.8, 1.2))


## A gate's moving leaf: it opens by sliding `dist` m along the world direction `dir` (metas
## slide_dir, slide_dist; open_offset is the two multiplied, in the leaf's parent space).
func _leaf(node_name: String, gate: String, at: Vector3, dir: Vector3, dist: float, mouth: Vector3) -> AnimatableBody3D:
	var leaf := AnimatableBody3D.new()
	leaf.name = node_name
	leaf.sync_to_physics = false
	leaf.position = at
	leaf.set_meta("gate", gate)
	leaf.set_meta("slide_dir", dir)
	leaf.set_meta("slide_dist", dist)
	leaf.set_meta("open_offset", dir * dist)
	leaf.set_meta("mouth", mouth)
	b.add(leaf, root)
	leaf.add_to_group("wave_gate", true)
	leaf.add_to_group("steel", true)  # rounds spark off it
	return leaf


## A decal on a leaf's face (leaf space, `out` the face's normal there), riding with the leaf.
func _on_leaf(leaf: Node3D, tex: Texture2D, at: Vector3, out: Vector3, size: float) -> void:
	var d := _face_decal(tex, at, out, Vector2(size, size))
	b.add(d, leaf)


func _face_decal(tex: Texture2D, at: Vector3, out: Vector3, size: Vector2) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(size.x, 0.3, size.y)
	var side := out.cross(Vector3.UP).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	d.transform = Transform3D(Basis(side, out, side.cross(out)) * Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), at)
	d.cull_mask = 1
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	return d


# --- pens -----------------------------------------------------------------------------------------

## Behind each gate a low concrete pen, black but for one caged lamp gone dim, its floor thick
## with what the dead left. Walls collide; the sliding leaf's slot stays clear.
func _pens() -> void:
	var x0: float = b.BAY_END
	_pen("MainPen", Rect2(x0 + 0.6, -4.45, 8.0, 8.9), [Vector3(x0 + 4.6, 0, 0)])
	var gx: float = b.SIDE_GATE_X
	for s in [-1.0, 1.0]:
		var z0: float = s * (b.BAY_HALF + 0.3)
		var z1: float = s * (b.BAY_HALF + 6.6)
		_pen("SidePen%s" % ("N" if s < 0 else "S"), Rect2(gx - 2.55, minf(z0, z1), 5.1, absf(z1 - z0)), [Vector3(gx, 0, (z0 + z1) / 2.0)])


func _pen(pen_name: String, r: Rect2, lamps: Array) -> void:
	var body := StaticBody3D.new()
	body.name = pen_name
	b.add(body, root)
	const T := 0.3
	var c := r.get_center()
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = r.size + Vector2(0.6, 0.6)
	floor_mesh.mesh = pm
	floor_mesh.position = Vector3(c.x, 0.002, c.y)
	floor_mesh.material_override = concrete
	floor_mesh.layers = 1 | b.FLOOR_PAINT
	b.add(floor_mesh, body)
	var main := pen_name == "MainPen"
	# Walls on the three sides away from the gate, and the lid.
	var walls := []
	if main:
		walls = [[Vector3(r.size.x, 4.0, T), Vector3(c.x, 2.0, r.position.y - T / 2.0)],
			[Vector3(r.size.x, 4.0, T), Vector3(c.x, 2.0, r.end.y + T / 2.0)],
			[Vector3(T, 4.0, r.size.y + 2.0 * T), Vector3(r.end.x + T / 2.0, 2.0, c.y)]]
	else:
		var far: float = r.end.y + T / 2.0 if c.y > 0 else r.position.y - T / 2.0
		walls = [[Vector3(T, 4.0, r.size.y), Vector3(r.position.x - T / 2.0, 2.0, c.y)],
			[Vector3(T, 4.0, r.size.y), Vector3(r.end.x + T / 2.0, 2.0, c.y)],
			[Vector3(r.size.x + 2.0 * T, 4.0, T), Vector3(c.x, 2.0, far)]]
	for w in walls:
		b.block(w[0], w[1], concrete, body)
		b.collide(w[0], w[1], body)
	var lid_r := r.grow(T)
	if not main:  # leave the lifting shutter's slot open on the gate side
		var z0 := r.position.y + 0.45 if c.y > 0 else r.position.y - T
		var z1 := r.end.y + T if c.y > 0 else r.end.y - 0.45
		lid_r = Rect2(lid_r.position.x, z0, lid_r.size.x, z1 - z0)
	var lid: MeshInstance3D = b.block(Vector3(lid_r.size.x, 0.12, lid_r.size.y), Vector3(lid_r.get_center().x, 4.06, lid_r.get_center().y), dark, body)
	b.overhead(lid)
	for at: Vector3 in lamps:
		var lamp: Node3D = (load(MODELS + "caged_hanging_light/caged_hanging_light_1k.gltf") as PackedScene).instantiate()
		lamp.position = Vector3(at.x, 4.0, at.z)
		lamp.rotation.y = rng.randf() * TAU
		b.add(lamp, body)
		var glow := OmniLight3D.new()
		glow.position = Vector3(at.x, 3.0, at.z)
		glow.light_color = Color(0.7, 0.85, 0.75)
		glow.light_energy = 0.35
		glow.omni_range = 5.5
		glow.light_volumetric_fog_energy = 0.6
		b.add(glow, body)
	# Murk: thick dark haze, so an opened gate shows shapes in the dark, not a lit room.
	var fog := FogVolume.new()
	fog.size = Vector3(r.size.x, 4.0, r.size.y)
	fog.position = Vector3(c.x, 2.0, c.y)
	var fm := FogMaterial.new()
	fm.density = 0.25
	fm.albedo = Color(0.12, 0.11, 0.1)
	fm.height_falloff = 0.3
	fog.material = fm
	b.add(fog, body)
	# The floor: old blood soaked in, bones and meat everywhere.
	for i in int(r.get_area() / 6.0):
		var p := Vector3(rng.randf_range(r.position.x + 0.4, r.end.x - 0.4), 0, rng.randf_range(r.position.y + 0.4, r.end.y - 0.4))
		var d: Decal = b._decal(root, _blood["pool_%d" % (i % 3)] if i % 2 == 0 else _blood.dried_0, p, rng.randf() * TAU, Vector3(2.4, 0.4, 2.4))
		d.modulate = Color(1, 1, 1, rng.randf_range(0.7, 1.0))
	for i in int(r.get_area() / 5.0):
		var p := Vector3(rng.randf_range(r.position.x + 0.5, r.end.x - 0.5), 0, rng.randf_range(r.position.y + 0.5, r.end.y - 0.5))
		_remains(p, 0.9, false)


func _spawns() -> void:
	var holder := Node3D.new()
	holder.name = "WaveSpawns"
	b.add(holder, root)
	var x0: float = b.BAY_END
	var k := 0
	for ix in 4:
		for iz in 3:
			_spawn(holder, "main", Vector3(x0 + 2.0 + ix * 1.7, 0, -2.6 + iz * 2.6), Vector3.LEFT, k)
			k += 1
	var gx: float = b.SIDE_GATE_X
	for s in [-1.0, 1.0]:
		for ix in 2:
			for iz in 3:
				_spawn(holder, "north" if s < 0 else "south", Vector3(gx - 1.1 + ix * 2.2, 0, s * (b.BAY_HALF + 1.6 + iz * 1.9)), Vector3(0, 0, -s), k)
				k += 1


func _spawn(holder: Node3D, gate: String, at: Vector3, facing: Vector3, k: int) -> void:
	var m := Marker3D.new()
	m.name = "WaveSpawn%02d" % (k + 1)
	m.position = at
	m.basis = Basis.looking_at(facing)
	m.set_meta("gate", gate)
	b.add(m, holder)
	m.add_to_group("wave_spawn", true)


# --- wave alarms ----------------------------------------------------------------------------------

func _alarms() -> void:
	var holder := Node3D.new()
	holder.name = "WaveAlarms"
	b.add(holder, root)
	var x0: float = b.BAY_END
	var gx: float = b.SIDE_GATE_X
	var n := 0
	# Rotating beacons by every gate and either side of the bay's mouth, on the hall's wall.
	for at_out in [[Vector3(x0 - 0.02, 3.25, -b.MAIN_GATE_HALF - 0.7), Vector3.LEFT], [Vector3(x0 - 0.02, 3.25, b.MAIN_GATE_HALF + 0.7), Vector3.LEFT],
			[Vector3(gx - b.SIDE_GATE_HALF - 0.7, 3.25, -b.BAY_HALF + 0.02), Vector3.BACK], [Vector3(gx + b.SIDE_GATE_HALF + 0.7, 3.25, b.BAY_HALF - 0.02), Vector3.FORWARD],
			[Vector3(27.83, 4.4, -13.4), Vector3.LEFT], [Vector3(27.83, 4.4, 13.4), Vector3.LEFT]]:
		n += 1
		_beacon(holder, "WaveBeacon%d" % n, at_out[0], at_out[1])
	# Caged red lamps under the light bridge and on the bay's ceiling.
	var bx: float = b.GS.FIRING_LINE_X + 0.8
	n = 0
	for at: Vector3 in [Vector3(bx, b.BRIDGE_Y - 0.1, -20.0), Vector3(bx, b.BRIDGE_Y - 0.1, -8.0), Vector3(bx, b.BRIDGE_Y - 0.1, 8.0),
			Vector3(bx, b.BRIDGE_Y - 0.1, 20.0), Vector3(32.4, b.BAY_H, -7.5), Vector3(32.4, b.BAY_H, 7.5)]:
		n += 1
		_red_lamp(holder, "WaveLamp%d" % n, at)


## A rotating beacon on a wall bracket facing `out`: base, red glass dome, a mirror turning inside
## with two spots back to back. Built dark (see the header).
func _beacon(holder: Node3D, node_name: String, at: Vector3, out: Vector3) -> void:
	var beacon := Node3D.new()
	beacon.name = node_name
	beacon.transform = Transform3D(Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out), at)
	beacon.set_meta("kind", "beacon")
	b.add(beacon, holder)
	beacon.add_to_group("wave_alarm", true)
	b.block(Vector3(0.12, 0.12, 0.2), Vector3(0, 0, 0.1), dark, beacon)
	b.block(Vector3(0.24, 0.03, 0.26), Vector3(0, 0.075, 0.25), dark, beacon)
	var base := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.1
	c.bottom_radius = 0.11
	c.height = 0.07
	base.mesh = c
	base.material_override = dark
	base.position = Vector3(0, 0.125, 0.27)
	b.add(base, beacon)
	var glass := _red_glass()
	var dome := MeshInstance3D.new()
	var dc := CylinderMesh.new()
	dc.top_radius = 0.08
	dc.bottom_radius = 0.09
	dc.height = 0.15
	dome.mesh = dc
	_alarm_glass(dome, glass)
	dome.position = Vector3(0, 0.235, 0.27)
	b.add(dome, beacon)
	var cap := MeshInstance3D.new()
	var sc := SphereMesh.new()
	sc.radius = 0.08
	sc.height = 0.08
	sc.is_hemisphere = true
	cap.mesh = sc
	_alarm_glass(cap, glass)
	cap.position = Vector3(0, 0.31, 0.27)
	b.add(cap, beacon)
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.position = Vector3(0, 0.24, 0.27)
	b.add(spin, beacon)
	var mirror := StandardMaterial3D.new()
	mirror.albedo_color = Color(0.8, 0.8, 0.82)
	mirror.metallic = 1.0
	mirror.roughness = 0.15
	b.block(Vector3(0.1, 0.1, 0.006), Vector3(0, 0, 0.02), mirror, spin)
	var bulb := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.025
	bs.height = 0.05
	bulb.mesh = bs
	_alarm_glass(bulb, glass)
	b.add(bulb, spin)
	for turn in [0.0, PI]:
		var spot := SpotLight3D.new()
		spot.rotation.y = turn
		spot.light_color = ALARM_RED
		spot.light_energy = 9.0
		spot.spot_range = 16.0
		spot.spot_angle = 18.0
		spot.spot_attenuation = 0.8
		spot.light_volumetric_fog_energy = 2.0  # sweeping beams in the haze
		spot.visible = false
		b.add(spot, spin)
	var glow := OmniLight3D.new()  # the dome's own red wash on the wall round it
	glow.position = Vector3(0, 0.25, 0.4)
	glow.light_color = ALARM_RED
	glow.light_energy = 1.2
	glow.omni_range = 3.6  # over 3.5: _lighten keeps it in the fog
	glow.visible = false
	b.add(glow, beacon)


## A red bulb in a wire cage hung from a short rod, built dark.
func _red_lamp(holder: Node3D, node_name: String, top: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = node_name
	lamp.position = top
	lamp.set_meta("kind", "lamp")
	b.add(lamp, holder)
	lamp.add_to_group("wave_alarm", true)
	b.block(Vector3(0.02, 0.3, 0.02), Vector3(0, -0.15, 0), dark, lamp)
	b.block(Vector3(0.14, 0.05, 0.14), Vector3(0, -0.32, 0), dark, lamp)
	var globe := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.17
	globe.mesh = s
	_alarm_glass(globe, _red_glass())
	globe.position = Vector3(0, -0.44, 0)
	b.add(globe, lamp)
	for k in 4:  # the cage
		var a := k * PI / 2.0 + PI / 4.0
		b.block(Vector3(0.008, 0.2, 0.008), Vector3(cos(a) * 0.095, -0.44, sin(a) * 0.095), dark, lamp)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.09
	t.outer_radius = 0.1
	ring.mesh = t
	ring.material_override = dark
	ring.position = Vector3(0, -0.44, 0)
	b.add(ring, lamp)
	var light := OmniLight3D.new()
	light.position = Vector3(0, -0.5, 0)
	light.light_color = ALARM_RED
	light.light_energy = 3.0
	light.omni_range = 8.0
	light.light_volumetric_fog_energy = 1.0
	light.visible = false
	b.add(light, lamp)


var _glass: Array[Material] = []


## [dark, lit] red glass, shared by every alarm.
func _red_glass() -> Array[Material]:
	if _glass.is_empty():
		var off := StandardMaterial3D.new()
		off.albedo_color = Color(0.32, 0.03, 0.02, 0.88)
		off.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		off.roughness = 0.12
		off.metallic_specular = 0.8
		ResourceSaver.save(off, GORE + "alarm_glass_off.tres")
		var on := StandardMaterial3D.new()
		on.albedo_color = Color(1.0, 0.25, 0.18)
		on.emission_enabled = true
		on.emission = ALARM_RED
		on.emission_energy_multiplier = 8.0
		on.roughness = 0.2
		ResourceSaver.save(on, GORE + "alarm_glass_on.tres")
		_glass = [load(GORE + "alarm_glass_off.tres"), load(GORE + "alarm_glass_on.tres")]
	return _glass


func _alarm_glass(m: MeshInstance3D, glass: Array[Material]) -> void:
	m.material_override = glass[0]
	m.set_meta("lit_material", glass[1])
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- the wave lever -------------------------------------------------------------------------------

const LEVER := "res://assets/props/lever/"
const LEVER_SCALE := 1.8  # the model is a real 41 cm panel: too small to spot across the hall
const WALL_Z := -28.0  # the north wall's inner face (build_arena _walls)


## "Old lever" (Gunnar Correa, CC-BY 4.0) on a steel backing plate, a conduit up to the sign: a
## riveted box with DALGA stencilled on it, the number on two dark flip plates and a status strip;
## a small cold lamp over it so it reads from the railing.
func _lever() -> void:
	var at: Vector3 = b.GS.LEVER_POS
	var holder := StaticBody3D.new()  # rounds spark off it, nothing more
	holder.name = "WaveLever"
	holder.position = Vector3(at.x, 0.0, WALL_Z)  # local +z: out of the wall into the hall
	b.add(holder, root)
	holder.add_to_group("wave_lever", true)
	holder.add_to_group("steel", true)
	b.block(Vector3(0.72, 1.05, 0.03), Vector3(0, 1.25, 0.015), dark, holder)
	for x in [-0.32, 0.32]:
		for y in [0.78, 1.72]:
			b.block(Vector3(0.03, 0.03, 0.012), Vector3(x, y, 0.035), frame_static, holder)  # bolt heads
	# Copied out of the FBX rather than instanced: a packed instance drops the materials set on its parts.
	var src: Node3D = (load(LEVER + "lever.fbx") as PackedScene).instantiate()
	var model := Node3D.new()
	model.name = "Lever"
	# The panel sits 10 cm right of and 2.7 cm over the model's origin, its back 5.4 cm behind it.
	model.transform = Transform3D(Basis().scaled(Vector3.ONE * LEVER_SCALE),
			Vector3(-0.1 * LEVER_SCALE, 1.25 - 0.027 * LEVER_SCALE, 0.03 + 0.054 * LEVER_SCALE))
	b.add(model, holder)
	for part in ["Panel", "Lever"]:
		var mi := src.get_node(part).duplicate() as MeshInstance3D
		mi.material_override = _lever_mat(part)
		b.add(mi, model)
	b.add(src.get_node("AnimationPlayer").duplicate(), model)  # its one clip swings the "Lever" part
	src.free()
	b.block(Vector3(0.05, 0.62, 0.05), Vector3(0.24, 1.98, 0.04), dark, holder)  # conduit
	# The sign.
	const SIGN_Y := 2.55
	b.block(Vector3(1.24, 0.78, 0.06), Vector3(0, SIGN_Y, 0.03), frame_static, holder)
	b.block(Vector3(1.16, 0.7, 0.01), Vector3(0, SIGN_Y, 0.065), dark, holder)
	var title: Label3D = b._range_label("DALGA", 30, Color(0.85, 0.8, 0.68, 0.9), b.STENCIL)
	title.position = Vector3(0, SIGN_Y + 0.25, 0.072)
	b.add(title, holder)
	for x in [-0.1, 0.1]:  # the flip plates, a hinge line across each
		b.block(Vector3(0.18, 0.3, 0.02), Vector3(x, SIGN_Y + 0.02, 0.08), _rubber(), holder)
		b.block(Vector3(0.18, 0.006, 0.004), Vector3(x, SIGN_Y + 0.02, 0.092), dark, holder)
	var number: Label3D = b._range_label("01", 84, Color(0.92, 0.88, 0.78), b.STENCIL)
	number.name = "Number"
	number.position = Vector3(0, SIGN_Y + 0.02, 0.095)
	b.add(number, holder)
	b.block(Vector3(1.04, 0.13, 0.012), Vector3(0, SIGN_Y - 0.25, 0.075), _rubber(), holder)
	var status: Label3D = b._range_label("HAZIR", 24, Color(1.0, 0.36, 0.22), b.STENCIL)
	status.name = "Status"
	status.position = Vector3(0, SIGN_Y - 0.25, 0.085)
	status.shaded = false  # a lit strip: readable whatever the hall's light does
	b.add(status, holder)
	b.collide(Vector3(0.72, 1.05, 0.1), Vector3(0, 1.25, 0.05), holder)
	b.collide(Vector3(1.24, 0.78, 0.1), Vector3(0, SIGN_Y, 0.05), holder)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0, SIGN_Y + 0.75, 0.45)
	lamp.basis = Basis.looking_at(Vector3(0, 1.6, 0.0) - lamp.position, Vector3.UP)
	lamp.light_color = Color(0.85, 0.93, 1.0)
	lamp.light_energy = 2.0
	lamp.spot_range = 3.5
	lamp.spot_angle = 40.0
	lamp.light_volumetric_fog_energy = 0.0
	b.add(lamp, holder)
	b.block(Vector3(0.16, 0.05, 0.4), Vector3(0, SIGN_Y + 0.8, 0.22), dark, holder)  # its arm and shade


func _lever_mat(part: String) -> StandardMaterial3D:
	var path := GORE + "lever_%s.tres" % part.to_lower()
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(LEVER + part + "_Base_Color.png")
	m.metallic = 1.0
	m.metallic_texture = load(LEVER + part + "_Metallic.png")
	m.roughness_texture = load(LEVER + part + "_Roughness.png")
	m.normal_enabled = true
	m.normal_texture = load(LEVER + part + "_Normal_OpenGL.png")
	ResourceSaver.save(m, path)
	return load(path)


# --- fire and haze --------------------------------------------------------------------------------

## Tyres stacked and set alight in the corners, out of the dead's way (scripts/barrel_fire.gd
## burns them: flames, sparks, smoke, the crackle and a breathing orange light), soot round each.
func _fires() -> void:
	var tyre := MODELS + "old_tyre/old_tyre_1k.gltf"
	var soot: Texture2D = _blood.scorch
	for spot in [[Vector3(18.6, 0, -25.9), 3], [Vector3(25.3, 0, 25.0), 2], [Vector3(42.9, 0, -10.2), 3], [Vector3(29.4, 0, 11.0), 2]]:
		var at: Vector3 = spot[0]
		var stack := StaticBody3D.new()
		stack.name = "BurningTyres"
		stack.position = at
		b.add(stack, root)
		var count: int = spot[1]
		for k in count:
			var t: Node3D = (load(tyre) as PackedScene).instantiate()
			t.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2 + rng.randf_range(-0.08, 0.08)),
				Vector3(rng.randf_range(-0.05, 0.05), 0.085 + k * 0.16, rng.randf_range(-0.05, 0.05)))
			b.add(t, stack)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3
		cyl.height = count * 0.165
		cs.shape = cyl
		cs.position.y = cyl.height / 2.0
		b.add(cs, stack)
		var fire := Node3D.new()
		fire.name = "Fire"
		fire.set_script(preload("res://scripts/barrel_fire.gd"))
		fire.set("rim", count * 0.165)
		fire.set("inner", 0.19)
		fire.set("bed", count * 0.165 - 0.12)
		fire.set("logs", false)
		b.add(fire, stack)
		var d: Decal = b._decal(root, soot, at, rng.randf() * TAU, Vector3(2.6, 0.6, 2.6))
		d.modulate = Color(1, 1, 1, 0.9)
	# Two dead fires: a charred stack gone cold, ash round it.
	for at in [Vector3(16.2, 0, 24.8), Vector3(43.0, 0, 9.6)]:
		for k in 2:
			var t := _deco(tyre, at + Vector3(rng.randf_range(-0.3, 0.3), 0.085 + k * 0.16, rng.randf_range(-0.3, 0.3)), rng.randf() * TAU, 1.0, Basis(Vector3.RIGHT, PI / 2 + rng.randf_range(-0.2, 0.2)))
			t.scale = Vector3(1.0, 1.0, 0.85)
		b._decal(root, soot, at, rng.randf() * TAU, Vector3(2.0, 0.6, 2.0))


## Haze lying in the bay and low over the range: the floods' and fires' light shows in it, the
## beacons will sweep through it, and the far end fades into murk.
func _haze() -> void:
	for f in [[Vector3((28.3 + b.BAY_END) / 2.0, 1.6, 0), Vector3(b.BAY_END - 28.3, 3.2, 2.0 * b.BAY_HALF), 0.025, Color(0.42, 0.4, 0.38)],
			[Vector3(21.0, 0.7, 0), Vector3(14.0, 1.4, 55.0), 0.012, Color(0.5, 0.48, 0.45)]]:
		var fog := FogVolume.new()
		fog.position = f[0]
		fog.size = f[1]
		var fm := FogMaterial.new()
		fm.density = f[2]
		fm.albedo = f[3]
		fm.height_falloff = 0.6
		fm.edge_fade = 0.4
		fog.material = fm
		b.add(fog, root)


# --- gore -----------------------------------------------------------------------------------------

func _gore() -> void:
	var x0: float = b.BAY_END
	var gx: float = b.SIDE_GATE_X
	var fl: float = b.GS.FIRING_LINE_X
	# Big pools and remains by the gates, where the dead come out and where they were stopped.
	for p in [Vector3(x0 - 1.6, 0, -1.4), Vector3(x0 - 2.6, 0, 2.6), Vector3(gx - 1.0, 0, -b.BAY_HALF + 1.6),
			Vector3(gx + 1.3, 0, b.BAY_HALF - 1.9), Vector3(34.0, 0, -6.4), Vector3(31.2, 0, 3.5)]:
		var d: Decal = b._decal(root, _blood["pool_%d" % rng.randi_range(0, 2)], p, rng.randf() * TAU, Vector3(3.2, 0.5, 3.2))
		d.modulate = Color(1, 1, 1, 0.95)
		_remains(p + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), 1.2, true)
	for p in [Vector3(22.2, 0, -14.0), Vector3(19.2, 0, 9.2), Vector3(25.6, 0, 3.2), Vector3(17.0, 0, -4.5),
			Vector3(24.0, 0, -22.5), Vector3(23.0, 0, 18.6)]:
		var d: Decal = b._decal(root, _blood["dried_%d" % rng.randi_range(0, 1)], p, rng.randf() * TAU, Vector3(2.6, 0.5, 2.6))
		d.modulate = Color(1, 1, 1, 0.9)
		_remains(p, 1.0, rng.randf() < 0.5)
	# Drag trails: bodies hauled from the range back in through the gates.
	for path in [[Vector2(20.5, -6.0), Vector2(x0 - 0.6, -0.8)], [Vector2(18.0, 12.0), Vector2(gx + 0.4, b.BAY_HALF - 0.4)],
			[Vector2(27.0, -2.0), Vector2(gx - 0.3, -b.BAY_HALF + 0.4)], [Vector2(24.5, 6.5), Vector2(x0 - 0.6, 1.6)]]:
		_trail(path[0], path[1])
	# Spatter all over the floor, thickest past x 30.
	for i in 70:
		var x := lerpf(fl + 1.5, x0 - 0.5, sqrt(rng.randf()))
		var half: float = b.BAY_HALF - 0.5 if x > 28.3 else 27.3
		var d: Decal = b._decal(root, _blood["splat_%d" % (i % 3)], Vector3(x, 0, rng.randf_range(-half, half)), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.6, 1.6) * Vector3(1, 0.4, 1))
		d.modulate = Color(1, 1, 1, rng.randf_range(0.6, 1.0))
	# Single bones and meat kicked about.
	for i in 46:
		var x := lerpf(fl + 2.0, x0 - 0.5, sqrt(rng.randf()))
		var half: float = b.BAY_HALF - 0.6 if x > 28.3 else 27.0
		var p := Vector3(x, 0, rng.randf_range(-half, half))
		if i % 3 == 0:
			_meat_at(p, rng.randf_range(0.12, 0.26))
		else:
			_bone_at(BONE_KINDS.keys()[rng.randi() % BONE_KINDS.size()], p)
	# Blood up the walls: the bay's sides, the lining, the back wall either side of the gate.
	var faces := []
	for s in [-1.0, 1.0]:
		faces.append([28.6, gx - b.SIDE_GATE_HALF - 0.3, s * (b.BAY_HALF - 0.04), true, Vector3(0, 0, -s), 6])
		faces.append([gx + b.SIDE_GATE_HALF + 0.3, x0 - 0.3, s * (b.BAY_HALF - 0.04), true, Vector3(0, 0, -s), 3])
		faces.append([s * (b.MAIN_GATE_HALF + 0.3), s * (b.BAY_HALF - 0.3), x0 - 0.02, false, Vector3.LEFT, 4])
		faces.append([fl + 1.0, 27.4, s * 27.95, true, Vector3(0, 0, -s), 7])
		faces.append([s * (b.BAY_HALF + 0.5), s * 27.4, 27.95, false, Vector3.LEFT, 4])
	for f in faces:
		for i in f[5]:
			var c := rng.randf_range(minf(f[0], f[1]), maxf(f[0], f[1]))
			var y := rng.randf_range(0.6, 1.9)
			var at := Vector3(c, y, f[2]) if f[3] else Vector3(f[2], y, c)
			var tex: Texture2D = _blood["run_%d" % (i % 3)] if i % 3 != 2 else _blood.claw
			var d := _face_decal(tex, at, f[4], Vector2.ONE * rng.randf_range(0.8, 1.4))
			d.modulate = Color(1, 1, 1, rng.randf_range(0.75, 1.0))
			b.add(d, root)


## A body's worth of what is left, round `at`: a pool under it if `fresh`, a skull or not, ribs,
## a run of vertebrae, a pelvis, long bones, a scapula, meat. `spread` m.
func _remains(at: Vector3, spread: float, fresh: bool) -> void:
	var off := func() -> Vector3:
		return at + Vector3(rng.randfn(0.0, spread * 0.45), 0, rng.randfn(0.0, spread * 0.45))
	if fresh:
		var d: Decal = b._decal(root, _blood["splat_%d" % rng.randi_range(0, 2)], at, rng.randf() * TAU, Vector3(1.6, 0.4, 1.6))
		d.modulate = Color(1, 1, 1, 0.9)
	if rng.randf() < 0.6:
		_bone_at("skull", off.call())
		if rng.randf() < 0.6:
			_bone_at("mandible", off.call())
	var spine_dir := Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU))
	var spine_at: Vector3 = off.call()
	for k in rng.randi_range(2, 5):
		_bone_at("vertebra_thoracic" if k % 2 == 0 else "vertebra_lumbar", spine_at + spine_dir * k * 0.09 + Vector3(rng.randfn(0, 0.02), 0, rng.randfn(0, 0.02)))
	for k in rng.randi_range(3, 7):
		_bone_at("rib", spine_at + Vector3(rng.randfn(0, 0.25), 0, rng.randfn(0, 0.25)))
	if rng.randf() < 0.7:
		_bone_at("pelvis", off.call())
	for k in rng.randi_range(1, 2):
		_bone_at("humerus", off.call())
	if rng.randf() < 0.5:
		_bone_at("scapula", off.call())
	for k in rng.randi_range(1, 4):
		_meat_at(off.call(), rng.randf_range(0.14, 0.3) if fresh else rng.randf_range(0.1, 0.2))


## A blood trail from `a` to `c`: smeared strips laid end to end, wandering a little.
func _trail(a: Vector2, c: Vector2) -> void:
	var n := int(ceilf(a.distance_to(c) / 2.4))
	var prev := a
	for k in n:
		var next := a.lerp(c, float(k + 1) / n) + (Vector2(rng.randfn(0, 0.25), rng.randfn(0, 0.25)) if k < n - 1 else Vector2.ZERO)
		var mid := (prev + next) / 2.0
		var dir := next - prev
		var d: Decal = b._decal(root, _blood.drag, Vector3(mid.x, 0, mid.y), atan2(dir.x, dir.y), Vector3(0.7, 0.4, dir.length() + 0.3))
		d.modulate = Color(1, 1, 1, rng.randf_range(0.75, 1.0))
		prev = next


func _bone_at(kind: String, at: Vector3) -> void:
	var info: Array = _bone_mesh(kind)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15)), at + Vector3(0, info[2], 0)) * (info[1] as Transform3D)
	if not _bone_xf.has(kind):
		_bone_xf[kind] = []
		_bone_tint[kind] = []
	_bone_xf[kind].append(xf)
	var tints := [Color(0.95, 0.9, 0.82), Color(0.8, 0.72, 0.6), Color(0.72, 0.42, 0.36), Color(0.55, 0.3, 0.26), Color(0.62, 0.56, 0.48)]
	_bone_tint[kind].append(tints[rng.randi() % tints.size()])


## A bone scan's mesh, its own material on it (the scan's normal and AO, a bone colour taken from the
## instance): [mesh, transform that centres it, sizes it in metres and lays it flattest side down,
## half its resting height].
func _bone_mesh(kind: String) -> Array:
	if _bone.has(kind):
		return _bone[kind]
	var scene: Node = (load(BONES + kind + ".glb") as PackedScene).instantiate()
	var src := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := src.mesh.duplicate() as ArrayMesh
	var mat := (mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_color = Color(0.88, 0.82, 0.7)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.62
	mat.ao_light_affect = 0.4
	mesh.surface_set_material(0, mat)
	scene.free()
	var path := BONES + kind + ".res"
	ResourceSaver.save(mesh, path)
	mesh = load(path)
	var box := mesh.get_aabb()
	var unit := 0.001 if box.get_longest_axis_size() > 10.0 else 1.0
	var k: float = unit * BONE_KINDS[kind]
	var rot := Basis()
	var shortest := box.get_shortest_axis_index()
	if shortest == Vector3.AXIS_X:
		rot = Basis(Vector3.BACK, PI / 2)
	elif shortest == Vector3.AXIS_Z:
		rot = Basis(Vector3.RIGHT, -PI / 2)
	var basis := rot.scaled(Vector3.ONE * k)
	var fix := Transform3D(basis, -(basis * box.get_center()))
	_bone[kind] = [mesh, fix, box.size[shortest] * k / 2.0 - 0.004]
	return _bone[kind]


func _meat_at(at: Vector3, size: float) -> void:
	if _meat.is_empty():
		_meat_meshes()
	var k := rng.randi() % _meat.size()
	var s := Vector3(size, size * rng.randf_range(0.5, 0.8), size * rng.randf_range(0.7, 1.1))
	_meat_xf[k].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(s), at + Vector3(0, s.y * 0.12, 0)))
	# Every lump lies in what ran out of it: a splash, and a pool under the big ones.
	var d: Decal = b._decal(root, _blood["splat_%d" % rng.randi_range(0, 2)], at, rng.randf() * TAU, Vector3(size * 4.5, 0.3, size * 4.5))
	d.modulate = Color(1, 1, 1, 0.9)
	if size > 0.2:
		var pool: Decal = b._decal(root, _blood["pool_%d" % rng.randi_range(0, 2)], at, rng.randf() * TAU, Vector3(size * 3.0, 0.3, size * 3.0))
		pool.modulate = Color(1, 1, 1, 0.95)


## Four lumps of torn flesh: a lumpy, ragged noise-pushed sphere drawn out long, its underside
## slumped on the floor; wet, stringy and clotted, red going black, no clean fat or cut faces (2026-10-29,
## the user: the first try with pale fat bands read as butcher's chops). materials/env/gore/meat.tres,
## all noise, no texture file.
func _meat_meshes() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.45, 0.6, 0.72, 0.8, 1.0])
	g.colors = PackedColorArray([Color(0.05, 0.004, 0.004), Color(0.16, 0.012, 0.01), Color(0.3, 0.02, 0.018),
		Color(0.42, 0.04, 0.03), Color(0.34, 0.1, 0.08), Color(0.22, 0.02, 0.015), Color(0.08, 0.01, 0.006)])
	var n := FastNoiseLite.new()  # ridged and warped: torn fibres, not marbling
	n.seed = 31
	n.frequency = 0.02
	n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n.fractal_octaves = 4
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = 60.0
	var albedo := NoiseTexture2D.new()
	albedo.noise = n
	albedo.color_ramp = g
	albedo.seamless = true
	albedo.width = 512
	albedo.height = 512
	var bump := NoiseTexture2D.new()
	var nb := FastNoiseLite.new()
	nb.seed = 32
	nb.frequency = 0.06
	nb.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	nb.fractal_octaves = 4
	bump.noise = nb
	bump.as_normal_map = true
	bump.bump_strength = 16.0
	bump.seamless = true
	bump.width = 512
	bump.height = 512
	var m := StandardMaterial3D.new()
	m.albedo_texture = albedo
	m.normal_enabled = true
	m.normal_texture = bump
	m.normal_scale = 1.0
	m.roughness = 0.16
	m.metallic_specular = 0.7
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 2.5
	ResourceSaver.save(m, GORE + "meat.tres")
	meat_mat = load(GORE + "meat.tres")
	for v in 4:
		var path := GORE + "meat_%d.res" % v
		var noise := FastNoiseLite.new()  # the lump's big shape
		noise.seed = 70 + v
		noise.frequency = 1.4
		noise.fractal_octaves = 3
		var rag := FastNoiseLite.new()  # torn edges and strings over it
		rag.seed = 90 + v
		rag.frequency = 5.0
		rag.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		rag.fractal_octaves = 3
		var stretch := Vector3(1.0 + 0.35 * v, 1.0, 1.0 - 0.08 * v)
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 32
		sphere.rings = 18
		var arrays := sphere.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			var p := verts[i]
			var dir := p.normalized() if p.length() > 0.0001 else Vector3.UP
			var r := 1.0 + 0.5 * noise.get_noise_3dv(dir * 1.7) + 0.16 * rag.get_noise_3dv(dir * 1.3)
			p = dir * 0.5 * maxf(r, 0.35) * stretch
			if p.y < -0.12:
				p.y = -0.12 + (p.y + 0.12) * 0.15
			verts[i] = p
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in idx:
			st.add_vertex(verts[i])
		st.generate_normals()
		var mesh := st.commit()
		mesh.surface_set_material(0, meat_mat)
		ResourceSaver.save(mesh, path)
		_meat.append(load(path))


## Bones and meat in a few MultiMeshes: hundreds of pieces in a handful of draw calls, drawn at any
## distance (they're what the range is about).
func _flush_multimeshes() -> void:
	for kind: String in _bone_xf:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _bone[kind][0]
		mm.instance_count = _bone_xf[kind].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, _bone_xf[kind][i])
			mm.set_instance_color(i, _bone_tint[kind][i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Bones_" + kind
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add(mi, root)
	for v in _meat.size():
		if _meat_xf[v].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meat[v]
		mm.instance_count = _meat_xf[v].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, _meat_xf[v][i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Meat_%d" % v
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add(mi, root)


# --- rubbish --------------------------------------------------------------------------------------

## Rubbish against the walls (colliding, out of the walk), small stuff on the floor (no collision):
## bin bags, tipped bins and drums, crushed boxes, tyres and rims, the survivors' last stand —
## planks they nailed up, a sledgehammer and a bat where they dropped them — and broken concrete.
func _debris() -> void:
	var bag := MODELS + "trashbag/trashbag_1k.gltf"
	var box := MODELS + "cardboard_box_01/cardboard_box_01_1k.gltf"
	var drum := MODELS + "barrel_03/barrel_03_1k.gltf"
	var drum2 := MODELS + "Barrel_02/Barrel_02_1k.gltf"
	var tyre := MODELS + "old_tyre/old_tyre_1k.gltf"
	var rims := [MODELS + "rusted_wheel_rim_01/rusted_wheel_rim_01_1k.gltf", MODELS + "rusted_wheel_rim_02/rusted_wheel_rim_02_1k.gltf"]
	var can := MODELS + "can_rusted/can_rusted_1k.gltf"
	var jerry := MODELS + "plastic_jerrycan/plastic_jerrycan_1k.gltf"
	var bin := _rusty_bin()
	# Bag heaps along the walls: [centre, along x, bags].
	for heap in [[Vector3(21.5, 0, -27.3), true, 7], [Vector3(26.4, 0, -27.2), true, 4], [Vector3(19.0, 0, 27.3), true, 6],
			[Vector3(27.3, 0, -17.0), false, 5], [Vector3(27.3, 0, 20.0), false, 4], [Vector3(31.0, 0, -11.4), true, 5],
			[Vector3(42.6, 0, 11.4), true, 4], [Vector3(43.7, 0, -6.6), false, 3]]:
		var c: Vector3 = heap[0]
		for k in heap[2]:
			var along := Vector3(rng.randf_range(-1.3, 1.3), 0, rng.randf_range(-0.25, 0.25)) if heap[1] else Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-1.3, 1.3))
			var up := 0.0 if k < heap[2] - 2 else 0.35
			_deco(bag, c + along + Vector3(0, up, 0), rng.randf() * TAU, rng.randf_range(0.85, 1.15), Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)))
		var body := StaticBody3D.new()
		b.add(body, root)
		b.collide(Vector3(2.8, 0.6, 0.8) if heap[1] else Vector3(0.8, 0.6, 2.8), c + Vector3(0, 0.3, 0), body)
	# Bins and drums, some knocked over and spilling.
	var side := Basis(Vector3.BACK, PI / 2)
	for p in [[bin, Vector3(16.4, 0, -27.3), 0.2, false], [bin, Vector3(27.2, 0, 23.3), 1.4, true], [drum, Vector3(23.6, 0, 27.3), 0.0, false],
			[drum, Vector3(24.4, 0, 27.2), 0.0, false], [drum2, Vector3(29.4, 0, -11.4), 0.0, false], [drum, Vector3(41.3, 0, -11.3), 0.3, true],
			[drum2, Vector3(35.0, 0, 11.5), 0.0, false], [bin, Vector3(44.0, 0, 5.4), -0.4, true]]:
		var n: Node3D
		if p[0] is String:
			n = _prop_body(p[0], p[1], p[2], p[3])
		else:
			n = (p[0] as Callable).call(p[1], p[2], p[3])
		if p[3]:
			var at: Vector3 = p[1]
			var inward := Vector3(-0.6, 0, 0) if absf(at.z) < 8.0 else Vector3(0, 0, -signf(at.z) * 0.6)
			for k in 3:  # what spilled out, toward the room
				_deco(bag if k == 0 else can, at + inward + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)), rng.randf() * TAU, 0.9 if k == 0 else 1.0)
	# Crushed boxes, cans, a jerrycan: small, no collision, anywhere along the walls.
	for i in 18:
		var w := _wall_spot()
		var crushed := Basis.from_scale(Vector3(1.0, rng.randf_range(0.25, 0.6), 1.0))
		_deco(box, w, rng.randf() * TAU, rng.randf_range(0.8, 1.1), crushed * Basis(Vector3.FORWARD, rng.randf_range(-0.2, 0.2)))
	for i in 24:
		var w := _wall_spot(2.5)
		_deco(can, w, rng.randf() * TAU, 1.0, side if rng.randf() < 0.7 else Basis())
	for i in 4:
		_deco(jerry, _wall_spot(), rng.randf() * TAU, 1.0, side if i % 2 == 0 else Basis())
	# Loose tyres and rims.
	for p in [Vector3(17.6, 0, -26.8), Vector3(26.9, 0, -24.5), Vector3(42.4, 0, -11.0), Vector3(15.8, 0, 26.9)]:
		_deco(tyre, p + Vector3(0, 0.085, 0), rng.randf() * TAU, 1.0, Basis(Vector3.RIGHT, PI / 2))
	for p in [Vector3(27.3, 0, -25.6), Vector3(30.2, 0, 11.4), Vector3(43.8, 0, -3.6)]:
		_deco(tyre, p + Vector3(0, 0.3, 0), rng.randf_range(-0.2, 0.2) + PI / 2, 1.0, Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)))
	for i in 5:
		_deco(rims[i % 2], _wall_spot() + Vector3(0, 0.07, 0), rng.randf() * TAU, 1.0, Basis(Vector3.RIGHT, PI / 2))
	# The last stand: planks they nailed across the bay's mouth corners, torn down; tools dropped.
	var wood: Material = load("res://materials/env/plywood_1.tres")
	for i in 14:
		var at := Vector3(rng.randf_range(28.6, 31.5), 0.02 + (i % 3) * 0.025, rng.randf_range(-11.6, -9.5) if i % 2 == 0 else rng.randf_range(9.5, 11.6))
		b.block(Vector3(rng.randf_range(1.2, 2.2), 0.025, 0.14), at, wood, root, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.05, 0.05)))
	for s in [-1.0, 1.0]:  # two still nailed up on the hall wall, hanging off one end
		for k in 3:
			b.block(Vector3(0.025, 0.16, rng.randf_range(1.6, 2.2)), Vector3(27.93, 1.0 + k * 0.45, s * (b.BAY_HALF + 1.1)), wood, root, Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)))
	_deco(MODELS + "sledgehammer_01/sledgehammer_01_1k.gltf", Vector3(23.4, 0.04, 3.9), 0.7, 1.0, Basis(Vector3.BACK, PI / 2))
	_deco(MODELS + "baseball_bat/baseball_bat_1k.gltf", Vector3(18.6, 0.032, 10.0), 2.1, 1.0, Basis(Vector3.BACK, PI / 2))
	_deco(MODELS + "baseball_bat/baseball_bat_1k.gltf", Vector3(35.2, 0.032, -6.9), -0.6, 1.0, Basis(Vector3.BACK, PI / 2))
	# Broken concrete: chunks off the walls' feet and a few loose on the floor.
	for i in 40:
		var at := _wall_spot(1.2) if i < 28 else Vector3(rng.randf_range(16.0, 43.0), 0, rng.randf_range(-11.0, 11.0))
		var sz := Vector3(rng.randf_range(0.08, 0.3), rng.randf_range(0.05, 0.16), rng.randf_range(0.08, 0.26))
		var m := MeshInstance3D.new()
		m.mesh = b._stone_block(sz, 900 + i, 0.03, 0.01)
		m.material_override = concrete
		m.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), at + Vector3(0, sz.y * 0.4, 0))
		b.add(m, root)
	# Rags: torn clothes, dark with old blood.
	var rag: Material = load("res://materials/env/cloth_olive.tres")
	for i in 16:
		var x := rng.randf_range(16.0, 43.5)
		var half: float = b.BAY_HALF - 0.6 if x > 28.3 else 26.5
		var at := Vector3(x, 0.004, rng.randf_range(-half, half))
		var m: MeshInstance3D = b.block(Vector3(rng.randf_range(0.25, 0.6), 0.006, rng.randf_range(0.2, 0.45)), at, rag, root, Basis(Vector3.UP, rng.randf() * TAU))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var d: Decal = b._decal(root, _blood.dried_1, at, rng.randf() * TAU, Vector3(0.8, 0.3, 0.8))
		d.modulate = Color(1, 1, 1, 0.7)


## A floor spot hugging a wall of the range (within `reach` m of it), clear of the gates.
func _wall_spot(reach := 0.8) -> Vector3:
	while true:
		var pick := rng.randi() % 6
		var d := rng.randf_range(0.2, reach)
		var p: Vector3
		match pick:
			0, 1:
				var s := -1.0 if pick == 0 else 1.0
				p = Vector3(rng.randf_range(15.0, 27.5), 0, s * (27.9 - d))
			2:
				var s := -1.0 if rng.randf() < 0.5 else 1.0
				p = Vector3(27.9 - d, 0, s * rng.randf_range(b.BAY_HALF + 0.4, 27.5))
			3, 4:
				var s := -1.0 if pick == 3 else 1.0
				p = Vector3(rng.randf_range(28.6, b.BAY_END - 0.3), 0, s * (b.BAY_HALF - d))
				if absf(p.x - b.SIDE_GATE_X) < b.SIDE_GATE_HALF + 0.8:
					continue
			5:
				p = Vector3(b.BAY_END - d, 0, (-1.0 if rng.randf() < 0.5 else 1.0) * rng.randf_range(b.MAIN_GATE_HALF + 0.6, b.BAY_HALF - 0.3))
		return p
	return Vector3.ZERO


## The rusty one of Poly Haven's two metal bins, lid off beside it: a Callable placing one at
## (pos, yaw, knocked over), with collision when it stands against a wall.
func _rusty_bin() -> Callable:
	var parts := []
	var scene: Node = (load(MODELS + "metal_trash_can/metal_trash_can_1k.gltf") as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*rust*", "MeshInstance3D", true, false):
		var path := MODELS + "metal_trash_can/%s.res" % mi.name
		ResourceSaver.save(mi.mesh, path)
		parts.append([load(path), mi.name.contains("lid"), (mi.get_parent() as Node3D).transform * mi.transform if mi.get_parent() is Node3D else mi.transform])
	scene.free()
	var centre := Vector3.ZERO
	for p in parts:
		if not p[1]:
			centre += (p[2] as Transform3D).origin
	centre /= maxf(1.0, parts.filter(func(p: Array) -> bool: return not p[1]).size())
	centre.y = 0.0
	return func(pos: Vector3, yaw: float, knocked: bool) -> Node3D:
		var holder: Node3D = StaticBody3D.new() if not knocked else Node3D.new()
		holder.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
		b.add(holder, root)
		var can_xf := Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0, 0.28, 0)) if knocked else Transform3D()
		for p in parts:
			var m := MeshInstance3D.new()
			m.mesh = p[0]
			var local := Transform3D((p[2] as Transform3D).basis, (p[2] as Transform3D).origin - centre)
			if p[1]:  # the lid, on the floor beside it
				m.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2 * 0.97), Vector3(0.55, 0.03, 0.2)) * Transform3D(local.basis, Vector3.ZERO)
			else:
				m.transform = can_xf * local
			b.add(m, holder)
		if not knocked:
			b.collide(Vector3(0.56, 0.9, 0.56), Vector3(0, 0.45, 0), holder)
		return holder


func _prop_body(path: String, pos: Vector3, yaw: float, knocked: bool) -> Node3D:
	if knocked:
		return _deco(path, pos + Vector3(0, 0.3, 0), yaw, 1.0, Basis(Vector3.BACK, PI / 2))
	return b._prop(root, path, pos, yaw)


func _deco(path: String, pos: Vector3, yaw: float, s := 1.0, tilt := Basis()) -> Node3D:
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.transform = Transform3D((Basis(Vector3.UP, yaw) * tilt).scaled(Vector3.ONE * s), pos)
	b.add(inst, root)
	return inst


# --- hanging chains -------------------------------------------------------------------------------

## Chains hung from the bay's ceiling by the side walls, meat or a bag on the end of some: the
## place was a larder once. Links are one MultiMesh; nothing collides.
func _chains() -> void:
	var link := TorusMesh.new()
	link.inner_radius = 0.018
	link.outer_radius = 0.03
	link.rings = 8
	link.ring_segments = 6
	var xfs: Array[Transform3D] = []
	for c in [[Vector3(30.2, 0, -10.6), 2.1, true], [Vector3(33.4, 0, -10.9), 1.5, false], [Vector3(31.6, 0, 10.7), 1.8, true],
			[Vector3(42.0, 0, 10.6), 2.4, false], [Vector3(42.6, 0, -10.8), 1.9, true]]:
		var top: Vector3 = c[0] + Vector3(0, b.BAY_H, 0)
		var length: float = c[1]
		var count := int(length / 0.05)
		for k in count:
			var turn := Basis(Vector3.UP, PI / 2 if k % 2 else 0.0) * Basis(Vector3.RIGHT, PI / 2)
			xfs.append(Transform3D(turn.scaled(Vector3(1.0, 1.0, 1.4)), top - Vector3(0, 0.03 + k * 0.05, 0)))
		var end := top - Vector3(0, length + 0.05, 0)
		b.block(Vector3(0.012, 0.16, 0.06), end - Vector3(0, 0.06, 0), dark, root, Basis(Vector3.FORWARD, 0.4))  # the hook
		if c[2]:
			if _meat.is_empty():
				_meat_meshes()
			var m := MeshInstance3D.new()
			m.mesh = _meat[rng.randi() % _meat.size()]
			m.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(0.28, 0.5, 0.22)), end - Vector3(0, 0.28, 0))
			b.add(m, root)
			var d: Decal = b._decal(root, _blood["pool_%d" % rng.randi_range(0, 2)], Vector3(end.x, 0, end.z), rng.randf() * TAU, Vector3(1.2, 0.4, 1.2))
			d.modulate = Color(1, 1, 1, 0.9)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Chains"
	mi.multimesh = mm
	mi.material_override = dark
	b.add(mi, root)
	b.overhead(mi)


# --- decal textures -------------------------------------------------------------------------------

## Blood, claw marks and soot, drawn once into materials/env/decals (delete a file to redraw it).
func _blood_textures() -> void:
	var fresh := Color(0.24, 0.008, 0.006)
	var dry := Color(0.11, 0.035, 0.02)
	for i in 3:
		_blood["pool_%d" % i] = _pool("blood_pool_%d" % i, 40 + i, fresh, 0.95)
		_blood["splat_%d" % i] = _splat("blood_splat_%d" % i, 50 + i, fresh)
		_blood["run_%d" % i] = _run("blood_run_%d" % i, 60 + i)
	for i in 2:
		_blood["dried_%d" % i] = _pool("blood_dried_%d" % i, 45 + i, dry, 0.85)
	_blood["drag"] = _drag()
	_blood["claw"] = _claw()
	_blood["scorch"] = _soot()


## An irregular pool: a noisy edge, darker where it thinned and dried at the rim, drops round it.
func _pool(id: String, noise_seed: int, colour: Color, alpha: float) -> Texture2D:
	return b._decal_tex(id, 256, 256, func(img: Image) -> void:
		var n := FastNoiseLite.new()
		n.seed = noise_seed
		n.frequency = 0.012
		n.fractal_octaves = 4
		var r := RandomNumberGenerator.new()
		r.seed = noise_seed
		var drops := []
		for k in 14:
			var a := r.randf() * TAU
			drops.append(Vector3(128 + cos(a) * r.randf_range(80, 118), 128 + sin(a) * r.randf_range(80, 118), r.randf_range(1.5, 5.0)))
		for y in 256:
			for x in 256:
				var d := Vector2(x - 128, y - 128).length() / 88.0 + n.get_noise_2d(x, y) * 0.55
				var a := smoothstep(1.0, 0.94, d)
				for dr: Vector3 in drops:
					a = maxf(a, smoothstep(dr.z, dr.z - 1.2, Vector2(x - dr.x, y - dr.y).length()))
				var rim := smoothstep(0.7, 1.0, d)
				var c := colour.lerp(Color(0.07, 0.02, 0.01), rim * 0.7)
				c = c.lerp(colour * 1.4, maxf(0.0, n.get_noise_2d(x * 3.0, y * 3.0)) * 0.4 * (1.0 - rim))
				img.set_pixel(x, y, Color(c, a * alpha)))


## A splash: a core with drops thrown out from it, long ones stretched along their flight.
func _splat(id: String, noise_seed: int, colour: Color) -> Texture2D:
	return b._decal_tex(id, 256, 256, func(img: Image) -> void:
		img.fill(Color(colour, 0.0))
		var n := FastNoiseLite.new()
		n.seed = noise_seed
		n.frequency = 0.03
		var r := RandomNumberGenerator.new()
		r.seed = noise_seed
		var blobs := [Vector4(128, 128, 30, 0)]
		for k in 60:
			var a := r.randf() * TAU
			var dist := r.randf_range(20.0, 118.0)
			blobs.append(Vector4(128 + cos(a) * dist, 128 + sin(a) * dist, r.randf_range(1.0, 7.0) * (1.0 - dist / 160.0), a))
		for y in 256:
			for x in 256:
				var a := 0.0
				for bl: Vector4 in blobs:
					var dv := Vector2(x - bl.x, y - bl.y)
					var along := dv.rotated(-bl.w)
					var e := Vector2(along.x / 2.6, along.y).length() if bl.z < 20.0 else dv.length() + n.get_noise_2d(x, y) * 12.0
					a = maxf(a, smoothstep(bl.z, bl.z - 1.5, e))
				if a > 0.0:
					img.set_pixel(x, y, Color(colour.lerp(Color(0.08, 0.01, 0.0), 0.3 * (1.0 - a)), a * 0.95)))


## Blood thrown on a wall and run down: a splash near the top, drips running down from it, a bead
## at the foot of each.
func _run(id: String, noise_seed: int) -> Texture2D:
	return b._decal_tex(id, 128, 256, func(img: Image) -> void:
		var colour := Color(0.22, 0.01, 0.008)
		img.fill(Color(colour, 0.0))
		var n := FastNoiseLite.new()
		n.seed = noise_seed
		n.frequency = 0.05
		var r := RandomNumberGenerator.new()
		r.seed = noise_seed
		var drips := []
		for k in 9:
			drips.append(Vector3(r.randf_range(24, 104), r.randf_range(90, 240), r.randf_range(1.2, 3.2)))
		for y in 256:
			for x in 128:
				var d := Vector2((x - 64) / 44.0, (y - 56) / 30.0).length() + n.get_noise_2d(x, y) * 0.6
				var a := smoothstep(1.0, 0.9, d)
				for dr: Vector3 in drips:
					var w: float = dr.z * (1.0 - 0.3 * (y - 50) / maxf(1.0, dr.y - 50.0))
					if y > 50 and y < dr.y:
						a = maxf(a, smoothstep(w, w - 0.8, absf(x - dr.x)))
					a = maxf(a, smoothstep(dr.z + 1.4, dr.z + 0.2, Vector2(x - dr.x, y - dr.y).length()))
				if a > 0.0:
					img.set_pixel(x, y, Color(colour, a * 0.92)))


## A drag trail along the texture's length: smeared streaks from cloth and hands, breaking up.
func _drag() -> Texture2D:
	return b._decal_tex("blood_drag", 128, 1024, func(img: Image) -> void:
		var n := FastNoiseLite.new()
		n.seed = 81
		n.frequency = 0.02
		n.fractal_octaves = 3
		for y in 1024:
			var width := 0.32 + 0.14 * n.get_noise_1d(y * 0.4)
			var centre := 64.0 + 14.0 * n.get_noise_1d(y * 0.2 + 400.0)
			var gap := smoothstep(-0.45, -0.15, n.get_noise_1d(y * 0.6 + 900.0))
			for x in 128:
				var across := absf(x - centre) / (64.0 * width)
				var streak := 0.55 + 0.45 * n.get_noise_2d(x * 9.0, y * 0.15)
				var a := smoothstep(1.0, 0.7, across) * streak * gap
				var c := Color(0.2, 0.01, 0.006).lerp(Color(0.1, 0.03, 0.015), clampf(across, 0.0, 1.0))
				img.set_pixel(x, y, Color(c, clampf(a, 0.0, 1.0) * 0.9)))


## Four claw gouges dragged down a steel face: dark grooves, a bright scraped lip on one side.
func _claw() -> Texture2D:
	return b._decal_tex("claw_marks", 256, 256, func(img: Image) -> void:
		img.fill(Color(0, 0, 0, 0))
		var r := RandomNumberGenerator.new()
		r.seed = 91
		for k in 4:
			var x0 := 70.0 + k * 34.0 + r.randf_range(-6, 6)
			var bend := r.randf_range(-18, 18)
			var y0 := r.randf_range(20, 50)
			var y1 := r.randf_range(190, 240)
			for y in range(int(y0), int(y1)):
				var t := (y - y0) / (y1 - y0)
				var cx := x0 + bend * t * t - 20.0 * t
				var w := 3.2 * sin(PI * clampf(t * 1.1, 0.0, 1.0)) + 0.6
				for x in range(int(cx - w - 3), int(cx + w + 3)):
					if x < 0 or x > 255:
						continue
					var d := x - cx
					if absf(d) < w:
						img.set_pixel(x, y, Color(0.04, 0.03, 0.025, 0.95))
					elif d > w and d < w + 2.0:
						img.set_pixel(x, y, Color(0.62, 0.58, 0.52, 0.8)))


func _soot() -> Texture2D:
	return b._decal_tex("tyre_soot", 256, 256, func(img: Image) -> void:
		var n := FastNoiseLite.new()
		n.seed = 99
		n.frequency = 0.02
		n.fractal_octaves = 4
		for y in 256:
			for x in 256:
				var d := Vector2(x - 128, y - 128).length() / 120.0 + n.get_noise_2d(x, y) * 0.35
				var a := smoothstep(1.0, 0.2, d)
				img.set_pixel(x, y, Color(0.02, 0.018, 0.016, a * 0.92)))
