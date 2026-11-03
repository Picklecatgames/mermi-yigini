class_name Pile
extends StaticBody3D
## The scrap heap in the back yard (2026-11-03, the user: the pit goes, "the back yard is flat ground
## with heaps and heaps of junk, as if we were a scrap dealer in the desert; some mountains touching the
## sky"; "the mountain is the scrap: as it runs out it goes down bit by bit, hours later the player sees
## half the mountain gone"): one height field on the flat ground the count is carved out of
## (GameState.pile, 100M pieces; one piece is UNIT of the starting volume): a small heap in front,
## behind it one great mountain (MOUNTAIN) with lesser heaps round its foot. The node sits on the
## ground. Real pieces cover the part the players reach (NEAR, _face_cell); the mountains above it are
## covered by bigger drawn pieces that ride the surface down as it goes (scripts/scrap_hills.gd).
## Scrap locks together: slopes up to LOCK_SLOPE stand, and every take that undercuts such a slope
## lets what is above it settle down into the gap. Takes from the same steep spot build up strain;
## past a threshold the host lets that part of the face give way (GameState scrap_collapse): it
## slumps to REPOSE_SLOPE, the top comes down with it, and real pieces tumble off the face and
## shove whoever stands below. A height field can't hang: nothing ever floats over a hole.
## Pieces on the surface are drawn from the prepared scrap (assets/props/hurda/hurda.json), one
## MultiMesh per part; loose pieces on the floor are numbered and picked up one by one.
## Co-op: only GameState events cross the network (bullets_taken for the heap, loose_taken by id,
## scrap_collapse with the host's seed); every peer digs, slides and slumps locally, the same way.
# Every peer runs the same digs through the same slide passes, so heights match bit for bit
# (tools/net_check.gd compares them): the heap keeps a step count, the host stamps its events
# with it and sends it on (heap_clock), and a client's heap applies each event at that step and
# never runs past the host's. Tumbling pieces are local visuals.

const CELL := 0.25            # m per height field cell
const GRID_X := 512           # cells along x -> 128 m
const GRID_Z := 640           # cells along z -> 160 m
## The junkyard: its middle on the ground (x, z) behind the workshop. One great mountain (2026-11-03,
## the user: "not sharp triangles: one big mountain with little hills round it, real, epic,
## dramatic"): world x, z, height, radius; a massive rounded top, SHOULDERS lesser domes on its
## flanks, gullies down it, a foot that spreads out, its outline wobbling round it. Out past its foot
## HILLOCKS lesser heaps standing on their own (rolled from HILLOCK_SEED), and in front the heap
## players dig into (FRONT, x, z, height, radius). Every side falls to the ground at EDGE_SLOPE
## before the grid ends.
const CENTER := Vector2(-72.0, 0.0)
const MOUNTAIN := Vector4(-88.0, 0.0, 74.0, 58.0)
const SHOULDERS := 4
const FRONT: Array[Vector4] = [Vector4(-20.0, -6.0, 6.0, 10.0), Vector4(-23.0, 7.0, 5.0, 9.0), Vector4(-14.0, 1.0, 3.0, 6.0)]
const HILLOCKS := 40
const HILLOCK_SEED := 5
const EDGE_SLOPE := 1.5
const TOP := 78.0             # m: no cell starts higher
## Where players reach (world x, z) and how high up it: those cells carry real pieces
## (data/scrap_face.json); the rest, the mountains, are covered by scrap_hills.gd.
const NEAR := Rect2(-40.0, -20.0, 32.0, 40.0)
const NEAR_TOP := 14.0
const LOCK_SLOPE := 1.8       # tan(61°): scrap hooked into scrap stands this steep
const REPOSE_SLOPE := 0.75    # tan(37°): a face that gave way slumps to this
const LOCK_STEP := LOCK_SLOPE * CELL
const REPOSE_STEP := REPOSE_SLOPE * CELL
const MIN_SLIDE := 1e-4       # m, smaller moves count as settled
const RELAX_PASSES := 3       # slide passes per physics frame while something is unsettled
const SLUMP_PASSES := 6       # while a face is coming down: it falls faster than it settles
const DIG_RADIUS := 2         # cells
const TILE := 8               # cells per activity tile side
const TILES_X := GRID_X / TILE
const TILES_Z := GRID_Z / TILE
const COLLISION_INTERVAL := 0.25
const SLUMP_COLLISION_INTERVAL := 0.1  # s, while a face comes down: it carries walkers
const SLUMP_REDRAW_EVERY := 3  # physics frames between moving the pieces on a slumping face
## The collision is cut into square height maps CHUNK cells a side (sharing their edge row), so a
## slide rebuilds only the ones it touched: one shape over the whole heap took 160 ms to rebuild.
const CHUNK := 32
const CHUNKS_X := (GRID_X - 2) / CHUNK + 1
const CHUNKS_Z := (GRID_Z - 2) / CHUNK + 1
const REDRAW_STEP := 0.002    # m a cell drifts before the pieces on it are moved
## The pieces: the prepared scrap (id, glb, tur, kutle_kg, boyut_m...; each glb a mesh with its
## base at y = 0 and one convex collision).
const PARTS_FILE := "res://assets/props/hurda/hurda.json"
## Only these kinds go into the heap (2026-11-02, the user's list: gears, heavy springs, nuts, bolts,
## pipes and valves, metal rims, aerials, car mirrors, chain, corkscrews, coins, rusty knives,
## scissors, metal buckets; tins, drink cans, metal bottles, flasks, thermoses, spoons, forks, metal
## plates; old motherboards, old phones, modems, broken alarm clocks), by hurda.json "tur", with how
## often each turns up (times the root of how many pieces the kind has). Any other kind stays out
## (guns, sheet, tools, crates, motor parts...).
const KIND_WEIGHT := {"disli": 1.0, "yay": 1.0, "civata": 1.0, "boru": 0.9, "zincir": 0.6, "konserve": 0.8,
	"kola": 0.6, "sise": 0.4, "mutfak": 0.6, "elektronik": 0.4, "jant": 0.3, "kap": 0.3, "anten": 0.3,
	"ayna": 0.2, "bicak": 0.4, "para": 0.5}
## The face is real pieces dropped onto this heap and settled, big ones under, small ones in the
## gaps (tools/build_scrap_face.gd picks them; data/scrap_face.json).
const FACE_FILE := "res://data/scrap_face.json"
## Pieces of those kinds that are not on the user's list, and ones left whole from a set (the
## stacked tyres looked silly in the heap).
const NOT_IN_HEAP := [
	"saw_blade",  # disli
	"pressure_gauge", "old_faucet",  # boru: a gauge and a tap, not a valve
	"metal_paint_can", "paint_can_01", "paint_can_02", "paint_can_03", "motor_oil_tin", "oil_tin", "cleaner_tin_01",
	"spray_paint_bottles_02_a", "spray_paint_bottles_02_dented", "small_oil_can_01", "russian_food_cans_01_salt_box",  # konserve: paint, oil, a salt box
	"dirty_tire_01", "dirty_tire_02", "dirty_tire_03", "dirty_tire_04", "old_tyre", "junk_scrap_06", "stacked_tire_01", "muddy_tire_01", "truck_wheel",  # jant: tyres
	"rusted_wheel_rim_01", "rusted_wheel_rim_02",  # jant: metal, but drawn small they read as black tyres
	"gate_latch_01", "horse_shoe", "old_key", "old_padlock",  # zincir
	"jerry_can_01", "jerry_can_02", "jerry_can_03", "jerry_can_04", "metal_jerrycan", "metal_jerrycan_green", "metal_jug",
	"small_lpg_tank", "soviet_fuel_canister", "watering_can_metal_01",  # kap: all but the bucket
	"retro_multimeter", "vintage_flashlight", "boombox"]  # elektronik
## Kinds known to stay out, quietly: anything else not in KIND_WEIGHT is warned about.
const OUT_KINDS := ["silah", "sac", "alet", "motor", "sandik"]
const MAX_SHARE := 0.015
## Each copy of a model a little darker or more rust-brown than the next, so repeats don't match;
## only a little, or neighbours flicker light and dark and the face reads as noise.
const TONE := Vector2(0.84, 1.02)
const RUST_TINT := Color(0.86, 0.74, 0.62)
const RUST_SHARE := 0.6
const LUMP := 0.12            # m of height noise on the scrap's top
const SCRAP_LAYER := 1 << 2   # physics layer 3: loose pieces; the player's body ignores it
const BULLET_LAYER := SCRAP_LAYER  # the old name (player.gd's reach ray masks it)
const WAKE_RADIUS := 0.45     # m round a walker's feet where resting pieces turn into bodies
const WAKE_SPEED := 0.5       # m/s, slower walkers don't kick anything
const MAX_AWAKE := 48         # kicked loose pieces at once
const MAX_DEBRIS := 90        # pieces tumbling off a face or falling from where they lay
const SHOVE_REACH := 0.7      # m from a walker's middle a moving piece shoves them
const SHOVE_SHARE := 0.8      # of the piece's speed
const POUR_SHOVE := 9.0       # m/s per m/s the surface under a walker rises
## Host: strain per tile from takes off a locked face; it gives way past a threshold rolled
## between these.
const STRAIN_MIN := 18.0
const STRAIN_MAX := 60.0
const STRAIN_SLOPE := 1.15    # takes count only where the slope is past REPOSE_STEP * this
const SLUMP_RADIUS := Vector2(1.8, 3.6)  # m, the host rolls a face's size between these

@export var heap_material: ShaderMaterial
## The face is covered in pieces (2026-11-01, the user: where the heap shows, scrap, no mesh, each
## piece its own): this many times over by their footprints, at most MAX_PER_CELL to a cell.
@export var cover := 1.3
const MAX_PER_CELL := 6
const TOP_LAYER := 6          # pieces to a cell lying on top; the rest lie a layer down
const SURFACE_MIN := 0.025   # m: only crumbs smaller than this stay off the face (the user: nuts and bolts too)
## Each piece's hitbox: its box this much bigger, plus BOX_PAD_MIN m (_load_parts).
const BOX_PAD := 1.15
const BOX_PAD_MIN := 0.006
const LOW_TRIS := 150         # surface pieces are drawn from a lighter copy of their part
## Loose pieces on the ground round the heap's foot, thinning out with distance.
@export var spill_pieces := 300
@export var spill_reach := 2.2  # m past the grid's edge
## False: only the heap's shape and collision, no pieces (tools/build_scrap_face.gd settles them).
var with_pieces := true

var _h := PackedFloat32Array()   # height per cell, row j = +z, column i = +x
var _ceil := PackedFloat32Array()  # roof height per cell: the heap never reaches over it
var _near := PackedByteArray()     # per cell: 1 where players reach (NEAR), as the heap started
var _far: Node                     # the mountains' pieces (scrap_hills.gd)
var unit := 0.0                  # m³ of heap per piece in the count
var _img: Image
var _tex: ImageTexture
var _tex_prev: ImageTexture
var _prev_stale := false
var _shapes: Array[HeightMapShape3D] = []  # per collision chunk
var _chunk_dirty := PackedByteArray()
var _active: Array[Rect2i] = []  # per tile: cells that may still slide
var _dirty: Array[Rect2i] = []   # per tile: cells changed since the last visual update
var _redraw: Array[Rect2i] = []  # per tile: cells whose pieces need to move
var _slump := PackedByteArray()  # per tile: 1 while a face there is giving way (REPOSE_STEP)
var _any_slump := false
var _drawn_h := PackedFloat32Array()
var _any_active := false
var _any_dirty := false
var _shape_dirty := false
var _shape_timer := 0.0
var _digs := []                  # [cell: Vector2i, height-metres still to remove]
var _dig_w := PackedFloat64Array()
var _noise := FastNoiseLite.new()
# Parts: one entry per piece in hurda.json that goes into the heap.
var _part_info: Array[Dictionary] = []  # its hurda.json row (id, materyal, tur...)
var _part_mesh: Array[Mesh] = []
var _part_size: Array[Vector3] = []
var _part_mid: Array[Vector3] = []  # the mesh's box centre: pieces are placed and collide by it
var _part_low: Array[Mesh] = []     # LOW_TRIS copy, for the thousands on the surface
var _part_foot := PackedFloat32Array()  # m², lying on its widest side
var _mark_mi := MeshInstance3D.new()  # the piece under a player's crosshair, outlined (highlight())
var _marked := -1
var _part_hull: Array[Shape3D] = []     # the glb's own convex hull: aimed at, it is the piece; wheels roll
var _part_hull_at: Array[Transform3D] = []  # the hull relative to the box centre
var _part_mass := PackedFloat32Array()
var _part_pick := PackedFloat32Array()  # running weight, for picking a part by a random number
var _face_pick := PackedFloat32Array()  # the same for the face, without the parts under SURFACE_MIN
# Surface pieces: a MultiMesh per part, slots in cell order.
var _surface: Array[MultiMeshInstance3D] = []
var _cell_first := PackedInt32Array()  # cell index -> first slot; slots are in cell order
var _slot_part := PackedInt32Array()
var _slot_index := PackedInt32Array()  # instance in its part's MultiMesh
var _slot_k := PackedInt32Array()      # cell whose corner the piece's height interpolates from
var _slot_f := PackedVector2Array()    # bilinear weights toward +x and +z
var _slot_xform: Array[Transform3D] = []  # as placed; origin.y is its lift over the surface
var _surface_removed := {}       # slot -> surface height there when it was picked off or fell
const RESURFACE := 0.06          # m the surface moves on from there before another piece shows in its slot
## Every piece of the heap is a body of its own, picked up by id (GameState loose ids): the drawn
## one in slot s, and every piece born there after it (shown under a taken one, or back in the
## slot when the surface moves on), is HEAP_ID_START + born * slot count + s.
const HEAP_ID_START := 1 << 32
var _slot_rid: Array[RID] = []   # per slot: its static body (layer SCRAP_LAYER), empty while gone
var _rid_slot := {}              # body -> slot
var _slot_body_y := PackedFloat32Array()  # per slot: the surface height its body was last put at
var _pad := PackedFloat32Array()  # per cell: how high its pieces rise over it (walkers' collision)
const MAX_PAD := 0.6
const BODY_STEP := 0.01         # m a slot drifts before its body follows (moving thousands costs)
var _slot_born := PackedInt32Array()  # per slot: pieces born there so far
var _slot_id := PackedInt64Array()    # per slot: the drawn piece's id, -1 while it is gone
var _gone := {}                  # heap id -> [part, local transform] taken, until heap_piece_taken digs under it
var _on_heap := {}               # cell key -> loose ids lying on the heap there (they sink or fall with it)
var _marked_loose := -1          # loose id under a crosshair, drawn by _mark_mi
const UNDER_DROP := 0.6          # of a taken piece's thickness, the one under it lies lower
## The pieces the face was settled with that lie buried under the ones that show
## (data/scrap_face.json "hidden"): kept as data, not drawn and with no body, until a take lays
## one open. It is then a loose piece, id HIDDEN_ID_START + its index. Past them the heap goes on
## with pieces made as they are dug to, EXTRA_ID_START + how many so far.
const HIDDEN_ID_START := HEAP_ID_START + (1 << 40)
const EXTRA_ID_START := HEAP_ID_START + (1 << 41)
const OPEN_REACH := 0.08         # m past touching a taken piece a buried one is laid open
## A taken piece lets go of what rested on it: those turn into bodies and fall into the room it
## left, and what rested on them too, this many deep.
const WAKE_DEPTH := 2
const WAKE_MARGIN := 0.03        # m round a taken piece's hull: what touches it rested on it
var _hid_part := PackedInt32Array()
var _hid_xform: Array[Transform3D] = []  # as settled; origin.y is its lift over the surface
var _hid_cell := {}              # cell index -> buried pieces' indices there
var _hid_left := PackedInt32Array()  # per cell: buried pieces not laid open yet
var _hid_open := {}              # buried piece index -> true once laid open
var _extra_born := 0
const BURY := 0.02               # m the heap rises over a loose piece's top before it is inside it
const FALL := 0.05               # m the heap drops under a loose piece's bottom before it falls
# Loose pieces: numbered, lying still as bare static bodies, one MultiMesh per part.
var _spill: Array[MultiMeshInstance3D] = []
var _part_slots: Array[Array] = []  # per part: loose id in each instance slot
var _id_index := {}              # loose id -> [part, slot, rid, transform]
var _spill_index := {}           # rid -> loose id
var _awake: Array[RigidBody3D] = []   # kicked loose pieces, meta "id", "part"
var _debris: Array[RigidBody3D] = []  # pieces off a slumping face, meta "since"
var _query_sphere := SphereShape3D.new()
var _strain := {}                # host: tile -> strain
var _limit := {}                 # host: tile -> the strain it gives way at
var step := 0                    # heap steps run (one per physics frame)
var _host_step := 0              # client: the host's, as last heard
var _pending := []               # client: [step, Callable] heap events for a step not reached yet
const CLOCK_EVERY := 6           # host: physics frames between heap_clock sends
const CATCH_UP := 4              # client: steps it may run in one frame when behind
var _walker_h := {}              # walker -> the surface height under it last frame


func _ready() -> void:
	position = Vector3(CENTER.x, 0.0, CENTER.y)
	_noise.seed = 3
	_noise.frequency = 0.18
	_noise.fractal_octaves = 4
	_active.resize(TILES_X * TILES_Z)
	_dirty.resize(TILES_X * TILES_Z)
	_redraw.resize(TILES_X * TILES_Z)
	_slump.resize(TILES_X * TILES_Z)
	for dj in range(-DIG_RADIUS, DIG_RADIUS + 1):
		for di in range(-DIG_RADIUS, DIG_RADIUS + 1):
			_dig_w.append(exp(-(di * di + dj * dj) * 0.5))
	_load_parts()
	_build_heights()
	var volume := 0.0
	for y in _h:
		volume += y
	unit = volume * CELL * CELL / float(GameState.PILE_START - spill_pieces)

	_img = Image.create_from_data(GRID_X, GRID_Z, false, Image.FORMAT_RF, _h.to_byte_array())
	_tex = ImageTexture.create_from_image(_img)
	_tex_prev = ImageTexture.create_from_image(_img)
	heap_material.set_shader_parameter("height_field", _tex)
	heap_material.set_shader_parameter("height_prev", _tex_prev)
	heap_material.set_shader_parameter("grid", Vector2i(GRID_X, GRID_Z))
	heap_material.set_shader_parameter("cell_size", CELL)
	var plane := PlaneMesh.new()
	plane.size = Vector2(GRID_X - 1, GRID_Z - 1) * CELL  # vertices sit on cell centres
	plane.subdivide_width = GRID_X - 2
	plane.subdivide_depth = GRID_Z - 2
	plane.material = heap_material
	var heap := MeshInstance3D.new()
	# Drawn too, black and sunk under the pieces (2026-11-03: the boxed pieces leave gaps): a chink
	# looks into the dark, never onto mud (scrap_heap.gdshader).
	heap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	heap.mesh = plane
	heap.custom_aabb = AABB(Vector3(-GRID_X * CELL * 0.5, -0.1, -GRID_Z * CELL * 0.5), Vector3(GRID_X * CELL, TOP + 0.5, GRID_Z * CELL))
	add_child(heap)

	for cz in CHUNKS_Z:
		for cx in CHUNKS_X:
			var shape := HeightMapShape3D.new()
			shape.map_width = CHUNK + 1
			shape.map_depth = CHUNK + 1
			var col := CollisionShape3D.new()
			col.shape = shape
			col.scale = Vector3.ONE * CELL  # samples are 1 unit apart; heights are divided by CELL
			# Its middle sample over cell (cx * CHUNK + CHUNK / 2, ...); past the grid it reads 0.
			col.position = _cell_pos(Vector2i(cx * CHUNK + CHUNK / 2, cz * CHUNK + CHUNK / 2))
			add_child(col)
			_shapes.append(shape)
	_chunk_dirty.resize(CHUNKS_X * CHUNKS_Z)
	_chunk_dirty.fill(1)
	_drawn_h = _h.duplicate()
	_update_shape()
	if not with_pieces:
		return

	_build_surface()
	_build_spill()
	_far = preload("res://scripts/scrap_hills.gd").new()
	add_child(_far)
	_far.build(self)
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.006
	outline.albedo_color = Color(1.0, 0.82, 0.45)
	_mark_mi.material_overlay = outline
	_mark_mi.visible = false
	add_child(_mark_mi)
	GameState.bullets_taken.connect(_on_bullets_taken)
	GameState.bullets_thrown.connect(_on_bullets_thrown)
	GameState.loose_taken.connect(_on_loose_taken)
	GameState.heap_piece_taken.connect(_on_heap_piece_taken)
	GameState.scrap_collapse.connect(_on_collapse)
	GameState.heap_clock.connect(func(s: int) -> void: _host_step = maxi(_host_step, s))
	GameState.pile_changed.connect(func(count: int) -> void: visible = count > 0)
	visible = GameState.pile > 0


func _load_parts() -> void:
	var list: Array = []
	for p: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(PARTS_FILE)):
		if not KIND_WEIGHT.has(p.tur) and p.tur not in OUT_KINDS:
			push_warning("hurda.json: %s has kind '%s', not one the heap takes (Pile.KIND_WEIGHT)" % [p.id, p.tur])
		if KIND_WEIGHT.has(p.tur) and p.id not in NOT_IN_HEAP:
			p.glb = PARTS_FILE.get_base_dir().path_join(p.glb.get_file())
			# PS1 horror look (2026-11-02, the user): the part's <name>_psx.scn (tools/psx_props.gd)
			# wherever there is one.
			var psx: String = p.glb.get_basename() + "_psx.scn"
			if ResourceLoader.exists(psx):
				p.glb = psx
			list.append(p)
	var in_kind := {}
	for p: Dictionary in list:
		in_kind[p.tur] = in_kind.get(p.tur, 0) + 1
	# All at once, on the loader's threads: one by one took 1.4 s. Not headless (the checks): there
	# the dummy renderer makes meshes and textures without a lock, and now and then two threads
	# made one at once and crashed it.
	var threaded := DisplayServer.get_name() != "headless"
	if threaded:
		for p: Dictionary in list:
			ResourceLoader.load_threaded_request(p.glb)
	var weight := PackedFloat32Array()
	for p: Dictionary in list:
		_part_info.append(p)
		var scene: PackedScene = ResourceLoader.load_threaded_get(p.glb) if threaded else load(p.glb)
		var glb: Node = scene.instantiate()
		var mi: MeshInstance3D = glb.find_children("*", "MeshInstance3D", true, false)[0]
		var mesh: Mesh = mi.mesh
		_part_mesh.append(mesh)
		# Each piece an invisible box a little bigger than it (2026-11-03, the user: "lay the pieces
		# apart, not like dust: draw a gear as a box, an invisible hitbox"): boxes touch, the pieces
		# in them never do, a gap is left round each; cheap and steady to stack and to fall.
		var box := BoxShape3D.new()
		box.size = mesh.get_aabb().size * BOX_PAD + Vector3.ONE * BOX_PAD_MIN
		_part_hull.append(box)
		_part_hull_at.append(Transform3D())
		_part_mass.append(clampf(p.kutle_kg, 0.05, 30.0))
		glb.free()
		_part_low.append(_low_poly(mesh))
		var aabb: AABB = mesh.get_aabb()
		_part_size.append(aabb.size)
		_part_mid.append(aabb.get_center())
		var dims := [aabb.size.x, aabb.size.y, aabb.size.z]
		dims.sort()
		_part_foot.append(dims[1] * dims[2])
		# A kind's share grows with the root of its count: 96 pipe pieces don't bury the one spring.
		weight.append(KIND_WEIGHT[p.tur] / sqrt(in_kind[p.tur]))
	# No one model more than MAX_SHARE of the heap: the one spring was every thirtieth piece.
	var sum := 0.0
	for w in weight:
		sum += w
	var total := 0.0
	var face := 0.0
	for i in weight.size():
		var w := minf(weight[i], sum * MAX_SHARE)
		total += w
		_part_pick.append(total)
		if _part_size[i][_part_size[i].max_axis_index()] >= SURFACE_MIN:
			face += w
		_face_pick.append(face)
	for i in _part_pick.size():
		_part_pick[i] /= total
		_face_pick[i] /= face


## `n`'s transform in its scene, outside a tree.
static func _to_root(n: Node) -> Transform3D:
	var t := Transform3D()
	while n:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## `mesh` brought down to about `target` triangles with the engine's own simplifier (meshoptimizer,
## as import makes LODs); `mesh` itself where it is already light or won't simplify.
static func _low_poly(mesh: Mesh, target := LOW_TRIS) -> Mesh:
	var tris := 0
	for s in mesh.get_surface_count():
		tris += mesh.surface_get_array_index_len(s) / 3
	if tris <= target * 1.3:
		return mesh
	var im := ImporterMesh.new()
	for s in mesh.get_surface_count():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s), [], {}, mesh.surface_get_material(s))
	im.generate_lods(25.0, 60.0, [])
	var out := ArrayMesh.new()
	var keep := float(target) / tris
	for s in im.get_surface_count():
		var arrays := im.get_surface_arrays(s)
		var full: int = arrays[Mesh.ARRAY_INDEX].size()
		# The lightest LOD still over half our share of this surface: the last ones collapse
		# a crate into a dozen triangles.
		for l in im.get_surface_lod_count(s):
			var idx := im.get_surface_lod_indices(s, l)
			if idx.size() < full * keep * 0.5:
				break
			arrays[Mesh.ARRAY_INDEX] = idx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(s, im.get_surface_material(s))
	return out


## The mesh's own transform for a piece whose box centre is at `t`.
func _drawn(part: int, t: Transform3D) -> Transform3D:
	return t.translated_local(-_part_mid[part])


## Whether loose id `id` is a piece of the heap itself (GameState then digs under it).
func is_heap_id(id: int) -> bool:
	return id >= HEAP_ID_START


func _heap_id(s: int, born: int) -> int:
	return HEAP_ID_START + born * _slot_part.size() + s


func _slot_of_id(id: int) -> int:
	return (id - HEAP_ID_START) % _slot_part.size()


## Slot `s`'s body to `t` (local, at the box centre), made the first time; `t` null takes it out.
func _set_slot_body(s: int, t: Variant) -> void:
	var rid := _slot_rid[s]
	if t == null:
		if rid.is_valid():
			_rid_slot.erase(rid)
			PhysicsServer3D.free_rid(rid)
			_slot_rid[s] = RID()
		return
	if not rid.is_valid():
		rid = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
		var part := _slot_part[s]
		PhysicsServer3D.body_add_shape(rid, _part_hull[part].get_rid(), _part_hull_at[part])
		PhysicsServer3D.body_set_collision_layer(rid, SCRAP_LAYER)
		PhysicsServer3D.body_set_collision_mask(rid, 0)
		PhysicsServer3D.body_attach_object_instance_id(rid, get_instance_id())
		PhysicsServer3D.body_set_space(rid, get_world_3d().space)
		_slot_rid[s] = rid
		_rid_slot[rid] = s
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform * (t as Transform3D))


## Slot `s`'s piece goes (taken, or tumbling off as a body): not drawn, no body, no id; the next
## one shows there once the surface has moved on (RESURFACE).
func _clear_slot(s: int) -> void:
	_surface_removed[s] = _height_smooth(_slot_xform[s].origin)
	_surface[_slot_part[s]].multimesh.set_instance_transform(_slot_index[s], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_set_slot_body(s, null)
	_slot_id[s] = -1
	if s == _marked:
		_marked = -1
		_mark_mi.visible = false


## Slot `s` as it lies now (local, at the box centre, riding the surface).
func _slot_at(s: int) -> Transform3D:
	var t := _slot_xform[s]
	t.origin.y += _height_smooth(t.origin)
	return t


func _pick_part(r: float, on_face := false) -> int:
	var pick := _face_pick if on_face else _part_pick
	return clampi(pick.bsearch(r), 0, pick.size() - 1)


## The starting heap: the mountain or the highest of the lesser heaps over each cell, under the
## EDGE_SLOPE ramp off the grid's edges, lumps all over, and no slope steeper than LOCK_SLOPE.
func _build_heights() -> void:
	_h.resize(GRID_X * GRID_Z)
	_ceil.resize(GRID_X * GRID_Z)
	var half := Vector2(GRID_X, GRID_Z) * CELL * 0.5
	# The mountain's shoulders, then the lesser heaps out past its foot, lower the further out.
	var prng := RandomNumberGenerator.new()
	prng.seed = HILLOCK_SEED
	var mid := Vector2(MOUNTAIN.x, MOUNTAIN.y)
	var domes: Array[Vector4] = [MOUNTAIN]
	for n in SHOULDERS:
		var a := TAU * (n + prng.randf_range(0.2, 0.8)) / SHOULDERS
		var at := mid + Vector2(cos(a), sin(a)) * MOUNTAIN.w * prng.randf_range(0.3, 0.5)
		domes.append(Vector4(at.x, at.y, MOUNTAIN.z * prng.randf_range(0.5, 0.72), MOUNTAIN.w * prng.randf_range(0.45, 0.6)))
	var hills: Array[Vector4] = FRONT.duplicate()
	var tries := 0
	while hills.size() < FRONT.size() + HILLOCKS and tries < 5000:
		tries += 1
		var a := prng.randf() * TAU
		var d := MOUNTAIN.w * prng.randf_range(0.95, 1.7)
		var at := mid + Vector2(cos(a), sin(a)) * d
		var local := at - CENTER
		if absf(local.x) > half.x - 8.0 or absf(local.y) > half.y - 8.0 or at.x > NEAR.position.x - 4.0:
			continue  # off the grid, or in among the front heap
		var hh := prng.randf_range(3.0, 16.0) * clampf(2.0 - d / MOUNTAIN.w, 0.35, 1.0)
		hills.append(Vector4(at.x, at.y, hh, hh * prng.randf_range(2.6, 3.8)))
	for j in GRID_Z:
		for i in GRID_X:
			var c := _cell_pos(Vector2i(i, j))
			var k := j * GRID_X + i
			_ceil[k] = TOP + 1.0
			var w := Vector2(c.x, c.z) + CENTER
			# The mountain and its shoulders: domes (a bell, round on top, spreading at the foot), their
			# outline wobbling (the radius by direction from the mountain's middle), gullies running
			# down them (ridged noise along the fall line).
			var off := w - mid
			var dir := off.normalized() if off.length() > 0.01 else Vector2.RIGHT
			var wobble := 1.0 + 0.16 * _noise.get_noise_2d(dir.x * 40.0 + 300.0, dir.y * 40.0) + 0.07 * _noise.get_noise_2d(dir.x * 120.0, dir.y * 120.0 + 70.0)
			var y := 0.0
			for d in domes:
				var t := w.distance_to(Vector2(d.x, d.y)) / (d.w * wobble)
				if t < 1.0:
					y = maxf(y, d.z * (exp(-3.0 * t * t) - exp(-3.0)) / (1.0 - exp(-3.0)))
			var gully := 1.0 - absf(_noise.get_noise_2d(dir.x * 90.0 + 900.0, dir.y * 90.0))
			y *= 1.0 - 0.14 * gully * gully * smoothstep(0.15, 0.6, off.length() / MOUNTAIN.w)
			for p in hills:
				var q := w.distance_to(Vector2(p.x, p.y)) / p.w
				y = maxf(y, p.z * (1.0 - smoothstep(0.0, 1.0, q)))
			# Big lumps all over it, growing with height; small lumps everywhere.
			y += (_noise.get_noise_2d(c.x * 0.035 + 50.0, c.z * 0.035) * 0.14 + _noise.get_noise_2d(c.x * 0.12, c.z * 0.12) * 0.06) * y
			y += _noise.get_noise_2d(c.x * 0.8, c.z * 0.8) * 0.6 + _noise.get_noise_2d(c.x * 6.0, c.z * 6.0) * LUMP
			var edge := minf(half.x - absf(c.x), half.y - absf(c.z)) - CELL
			y = minf(y, EDGE_SLOPE * edge)
			_h[k] = clampf(y, 0.0, TOP)
	# No step between neighbours over LOCK_STEP: lower whatever stands too proud, two sweeps
	# (the chamfer distance transform's), so the heap starts at rest.
	for sweep in 2:
		var rng := range(GRID_Z) if sweep == 0 else range(GRID_Z - 1, -1, -1)
		var dir := 1 if sweep == 0 else -1
		for j: int in rng:
			for n in GRID_X:
				var i := n if dir == 1 else GRID_X - 1 - n
				var k := j * GRID_X + i
				var lim := _h[k]
				if i - dir >= 0 and i - dir < GRID_X:
					lim = minf(lim, _h[k - dir] + LOCK_STEP)
				if j - dir >= 0 and j - dir < GRID_Z:
					lim = minf(lim, _h[k - dir * GRID_X] + LOCK_STEP)
				_h[k] = lim
	for k in _h.size():
		if _h[k] < 0.004:
			_h[k] = 0.0
	_near.resize(_h.size())
	for j in GRID_Z:
		for i in GRID_X:
			var c := _cell_pos(Vector2i(i, j))
			var k := j * GRID_X + i
			_near[k] = int(NEAR.has_point(Vector2(c.x, c.z) + CENTER) and _h[k] < NEAR_TOP)


## A point over the scrap players reach (world, the middle of NEAR), for markers that point the way.
func top_point() -> Vector3:
	var at := Vector3(NEAR.get_center().x - CENTER.x, 0.0, NEAR.get_center().y - CENTER.y)
	return global_position + at + Vector3(0.0, _height_smooth(at), 0.0)


## Surface pieces: the face as it was settled (data/scrap_face.json), or, without it, laid
## pieces one by one. Each piece is a slot: its place over the surface, riding it.
func _build_surface() -> void:
	var per_part: Array[Array] = []  # plain Arrays while filling: packed arrays in an Array copy on access
	for p in _part_mesh.size():
		per_part.append([])
	var cell_slots := {}  # cell index -> Array of [part, index]
	var face: Variant = JSON.parse_string(FileAccess.get_file_as_string(FACE_FILE)) if FileAccess.file_exists(FACE_FILE) else null
	_hid_left.resize(GRID_X * GRID_Z)
	if face is Dictionary and int(face.heights) == hash(_h):
		_lay_settled(face.pieces, per_part, cell_slots)
		_bury_settled(face.get("hidden", []))
	else:
		push_warning("data/scrap_face.json is missing or was settled on another heap shape: run tools/build_scrap_face.gd")
		_lay_one_by_one(per_part, cell_slots)
	_make_slots(per_part, cell_slots)


## Cells with real pieces on them: scrap where players reach.
func _face_cell(k: int) -> bool:
	return _h[k] >= 0.03 and _near[k] == 1


## The face as tools/build_scrap_face.gd settled it, piece by piece on this very heap: each one
## where it came to rest, none inside another.
func _lay_settled(pieces: Array, per_part: Array[Array], cell_slots: Dictionary) -> void:
	var by_id := {}
	for i in _part_info.size():
		by_id[_part_info[i].id] = i
	for e: Array in pieces:
		if not by_id.has(e[0]):
			continue
		var part: int = by_id[e[0]]
		var o := Vector3(e[1], e[2], e[3])
		var cell := _cell_of(o)
		if not _in_grid(cell):
			continue
		var k := cell.y * GRID_X + cell.x
		var idx: int = per_part[part].size()
		per_part[part].append(Transform3D(Basis(Quaternion(e[4], e[5], e[6], e[7])), o))
		var list: Array = cell_slots.get(k, [])
		list.append([part, idx])
		cell_slots[k] = list


## The settled pieces buried under the face, kept as data until a take lays them open.
func _bury_settled(pieces: Array) -> void:
	var by_id := {}
	for i in _part_info.size():
		by_id[_part_info[i].id] = i
	for e: Array in pieces:
		if not by_id.has(e[0]):
			continue
		var o := Vector3(e[1], e[2], e[3])
		var cell := _cell_of(o)
		if not _in_grid(cell):
			continue
		var k := cell.y * GRID_X + cell.x
		var h := _hid_part.size()
		_hid_part.append(by_id[e[0]])
		_hid_xform.append(Transform3D(Basis(Quaternion(e[4], e[5], e[6], e[7])), o))
		var list: Array = _hid_cell.get(k, [])
		list.append(h)
		_hid_cell[k] = list
		_hid_left[k] += 1


## Without the settled face: every cell of the face that shows gets pieces until their footprints cover it
## `cover` times over (its true area: more where it's steep). Each lies on its widest side along
## the slope, tumbled and sunk into the ones round it.
func _lay_one_by_one(per_part: Array[Array], cell_slots: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for j in range(1, GRID_Z - 1):
		for i in range(1, GRID_X - 1):
			var cell := Vector2i(i, j)
			var k := j * GRID_X + i
			if not _face_cell(k):
				continue  # bare ground, or the mountains (scrap_hills.gd)
			var n := _cell_normal(cell)
			var area := CELL * CELL / maxf(n.y, 0.2) * cover
			var count := 0
			while area > 0.0 and count < MAX_PER_CELL:
				var part := _pick_part(rng.randf(), true)
				area -= _part_foot[part]
				count += 1
				var s := _part_size[part]
				# Widest side down: the smallest axis along the normal.
				var thin := 0 if s.x <= s.y and s.x <= s.z else (1 if s.y <= s.z else 2)
				var lay := Basis()
				if thin == 0:
					lay = Basis(Vector3.BACK, PI * 0.5)
				elif thin == 2:
					lay = Basis(Vector3.RIGHT, PI * 0.5)
				var tumble := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.7))
				var up := Basis(Quaternion(Vector3.UP, n))
				var b := up * tumble * Basis(Vector3.UP, rng.randf() * TAU) * lay
				var o := _cell_pos(cell) + Vector3(rng.randf_range(-0.5, 0.5) * CELL, 0.0, rng.randf_range(-0.5, 0.5) * CELL)
				# The first few a quarter sunk at most, their shape all there to see; the rest a layer
				# down between them, so through every gap shows another piece, never the heap's surface.
				o.y = s[thin] * (rng.randf_range(0.25, 0.5) if count <= TOP_LAYER else rng.randf_range(-0.25, 0.1))
				var idx: int = per_part[part].size()
				per_part[part].append(Transform3D(b, o))
				var list: Array = cell_slots.get(k, [])
				list.append([part, idx])
				cell_slots[k] = list


## The laid pieces as slots: a MultiMesh per part, slots in cell order, each with its body.
func _make_slots(per_part: Array[Array], cell_slots: Dictionary) -> void:
	for p in _part_mesh.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _part_low[p]
		mm.instance_count = per_part[p].size()
		for i in mm.instance_count:
			mm.set_instance_color(i, _tone(p * 100003 + i))
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = _toned(p)
		# Only the big ones cast: thousands of tools in every cascade cost more than they show.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _part_size[p].length() > 0.9 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_surface.append(node)
	_cell_first.resize(GRID_X * GRID_Z + 1)
	for key in GRID_X * GRID_Z:
		_cell_first[key] = _slot_part.size()
		for e: Array in cell_slots.get(key, []):
			var t: Transform3D = per_part[e[0]][e[1]]
			var u: float = t.origin.x / CELL + (GRID_X - 1) * 0.5
			var v: float = t.origin.z / CELL + (GRID_Z - 1) * 0.5
			var ci := clampi(floori(u), 0, GRID_X - 2)
			var cj := clampi(floori(v), 0, GRID_Z - 2)
			_slot_part.append(e[0])
			_slot_index.append(e[1])
			_slot_k.append(cj * GRID_X + ci)
			_slot_f.append(Vector2(clampf(u - ci, 0.0, 1.0), clampf(v - cj, 0.0, 1.0)))
			_slot_xform.append(t)
	_cell_first[GRID_X * GRID_Z] = _slot_part.size()
	var slots := _slot_part.size()
	_slot_rid.resize(slots)
	_slot_body_y.resize(slots)
	_slot_born.resize(slots)
	_slot_id.resize(slots)
	for s in slots:
		_slot_id[s] = _heap_id(s, 0)
	_mark(_redraw, Rect2i(0, 0, GRID_X, GRID_Z))
	_update_surface_pieces(Rect2i(0, 0, GRID_X, GRID_Z))
	_redraw.fill(Rect2i())
	# Walkers stand on the pieces, not on the surface they lie on: each cell's collision is raised
	# by how high its upper half of pieces rise over it, on average (the lower ones lie in the gaps
	# between them, and a foot rests on the top ones).
	_pad.resize(GRID_X * GRID_Z)
	for key in GRID_X * GRID_Z:
		var ys := PackedFloat32Array()
		for s in range(_cell_first[key], _cell_first[key + 1]):
			ys.append(_slot_xform[s].origin.y)
		ys.sort()
		var sum := 0.0
		for y in ys.slice(ys.size() / 2):
			sum += y
		var n := ys.size() - ys.size() / 2
		# No higher than the heap is thick there: at the foot it ramps up from the floor, no step.
		_pad[key] = clampf(sum / n, 0.0, minf(MAX_PAD, _h[key])) if n > 0 else 0.0
	_chunk_dirty.fill(1)
	_update_shape()


## Loose pieces on the floor in front of the face: dense at the foot, thinning out. Laid flat,
## each a bare static body, numbered 0.. in placement order (the same on every peer).
func _build_spill() -> void:
	for p in _part_mesh.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _part_mesh[p]
		mm.instance_count = 16
		mm.visible_instance_count = 0
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = _toned(p)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_spill.append(node)
		_part_slots.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	# On the ground round the foot of the scrap players reach: off its edge cells, down the slope,
	# thick at the edge, thinning out.
	var edge: Array[Vector2i] = []
	for j in range(1, GRID_Z - 1):
		for i in range(1, GRID_X - 1):
			var k := j * GRID_X + i
			if _face_cell(k) and minf(minf(_h[k - 1], _h[k + 1]), minf(_h[k - GRID_X], _h[k + GRID_X])) < 0.03:
				edge.append(Vector2i(i, j))
	var id := 0
	while id < spill_pieces and not edge.is_empty():
		var cell := edge[rng.randi() % edge.size()]
		var n := _cell_normal(cell)
		var out := Vector3(n.x, 0.0, n.z).normalized() * (0.25 + spill_reach * pow(rng.randf(), 2.2))
		var p := _cell_pos(cell) + out
		if _height_at(p) >= 0.03:
			continue
		var part := _pick_part(rng.randf())
		var t := rest_on(p, part, rng.randf() * TAU)
		t.origin.y = _part_size[part][_part_size[part].min_axis_index()] * 0.5
		_add_loose(id, part, t)
		id += 1


## A flat resting transform for `part` at local point `p` on the heap or the floor.
func rest_on(p: Vector3, part: int, yaw: float) -> Transform3D:
	var s := _part_size[part]
	var thin := 0 if s.x <= s.y and s.x <= s.z else (1 if s.y <= s.z else 2)
	var lay := Basis()
	if thin == 0:
		lay = Basis(Vector3.BACK, PI * 0.5)
	elif thin == 2:
		lay = Basis(Vector3.RIGHT, PI * 0.5)
	p.y = _height_smooth(p) + s[thin] * 0.5
	return Transform3D(Basis(Vector3.UP, yaw) * lay, p)


func _add_loose(id: int, part: int, t: Transform3D) -> void:
	var rid := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(rid, _part_hull[part].get_rid(), _part_hull_at[part])  # its own shape: aimed at, it is the piece
	PhysicsServer3D.body_set_collision_layer(rid, SCRAP_LAYER)
	PhysicsServer3D.body_set_collision_mask(rid, 0)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform * t)
	PhysicsServer3D.body_set_space(rid, get_world_3d().space)
	var slots: Array = _part_slots[part]
	var mm := _spill[part].multimesh
	if slots.size() >= mm.instance_count:  # resizing clears the instances
		mm.instance_count = slots.size() * 2
		for s in slots.size():
			mm.set_instance_transform(s, _drawn(part, _id_index[slots[s]][3]))
			mm.set_instance_color(s, _tone(slots[s]))
	mm.set_instance_transform(slots.size(), _drawn(part, t))
	mm.set_instance_color(slots.size(), _tone(id))
	_id_index[id] = [part, slots.size(), rid, t]
	_spill_index[rid] = id
	slots.append(id)
	mm.visible_instance_count = slots.size()
	var c := _cell_of(t.origin)
	if _in_grid(c):
		var key := c.y * GRID_X + c.x
		var here: Array = _on_heap.get(key, [])
		here.append(id)
		_on_heap[key] = here


## Swap-remove so each part's drawn instances stay packed at the front.
func _remove_loose(id: int) -> void:
	var rec: Array = _id_index[id]
	var slots: Array = _part_slots[rec[0]]
	var mm := _spill[rec[0]].multimesh
	var last := slots.size() - 1
	if rec[1] < last:
		var moved: int = slots[last]
		slots[rec[1]] = moved
		_id_index[moved][1] = rec[1]
		mm.set_instance_transform(rec[1], _drawn(rec[0], _id_index[moved][3]))
		mm.set_instance_color(rec[1], _tone(moved))
	slots.resize(last)
	mm.visible_instance_count = last
	var c := _cell_of(rec[3].origin)
	var key := c.y * GRID_X + c.x
	if _on_heap.has(key):
		_on_heap[key].erase(id)
		if _on_heap[key].is_empty():
			_on_heap.erase(key)
	_spill_index.erase(rec[2])
	PhysicsServer3D.free_rid(rec[2])
	_id_index.erase(id)


## True if a ray hit on `collider` / `rid` is a piece of scrap: one on the heap's face, one lying
## loose, or one moving. The heap's own surface between them is not: only pieces are taken.
func is_grabbable(collider: Object, rid: RID, _at: Vector3) -> bool:
	return loose_id(collider, rid) >= 0


## Whether the piece `id` is here to be picked up: on the face, lying loose, or moving.
func has_loose(id: int) -> bool:
	if _id_index.has(id) or _moving(id) != null:
		return true
	if is_heap_id(id):
		var s := _slot_of_id(id)
		return _slot_id[s] == id and _slot_rid[s].is_valid()
	return false


## Id of the piece a ray hit (on the face, resting or moving), or -1 if it hit something else.
func loose_id(collider: Object, rid: RID) -> int:
	if _rid_slot.has(rid):
		return _slot_id[_rid_slot[rid]]
	if _spill_index.has(rid):
		return _spill_index[rid]
	if collider is RigidBody3D and (_awake.has(collider) or _debris.has(collider)) and collider.has_meta("id"):
		return collider.get_meta("id")
	return -1


## The moving body of piece `id` (kicked, or tumbling off the face), or null.
func _moving(id: int) -> RigidBody3D:
	for list: Array in [_awake, _debris]:
		for body in list:
			if body.has_meta("id") and body.get_meta("id") == id:
				return body
	return null


## What the piece a ray hit looks like, for player.gd's hand: [mesh, its box centre in the mesh,
## its size, the box centre's world transform]; [] if the ray hit no piece.
func piece_look(collider: Object, rid: RID) -> Array:
	var part := -1
	var t := Transform3D()
	if _rid_slot.has(rid):
		var s: int = _rid_slot[rid]
		part = _slot_part[s]
		t = global_transform * _slot_at(s)
	elif _spill_index.has(rid):
		var rec: Array = _id_index[_spill_index[rid]]
		part = rec[0]
		t = global_transform * (rec[3] as Transform3D)
	elif collider is RigidBody3D and collider.has_meta("part"):
		part = collider.get_meta("part")
		t = (collider as RigidBody3D).global_transform
	if part < 0:
		return []
	return [_part_mesh[part], _part_mid[part], _part_size[part], t]


## A random piece's look, for a hand whose pieces we never saw taken (a rejoin): see piece_look.
func any_look() -> Array:
	var part := _pick_part(randf(), true)
	return [_part_mesh[part], _part_mid[part], _part_size[part], Transform3D()]


## A piece is picked up, everywhere at once: what it was and where it lay stays in _gone until
## heap_piece_taken (heap pieces) digs out its room and shows the one under it.
func _on_loose_taken(id: int) -> void:
	if id == _marked_loose:
		highlight(Vector3.ZERO, false)
	if _id_index.has(id):
		var rec: Array = _id_index[id]
		_gone[id] = [rec[0], rec[3]]
		_remove_loose(id)
	elif is_heap_id(id) and _slot_id[_slot_of_id(id)] == id:
		var s := _slot_of_id(id)
		_gone[id] = [_slot_part[s], _slot_at(s)]
		_clear_slot(s)
	else:
		var body := _moving(id)
		if body:
			var t := global_transform.affine_inverse() * body.global_transform
			_gone[id] = [body.get_meta("part"), Transform3D(t.basis.orthonormalized(), t.origin)]
			_awake.erase(body)
			_debris.erase(body)
			body.queue_free()
	if not is_heap_id(id):
		_gone.erase(id)


## A heap piece was taken (the host's call, at heap step `at_step`): its room in the heap is dug
## out, and the piece that lay under it shows, lower by part of its thickness.
func _on_heap_piece_taken(id: int, at_step: int) -> void:
	_at_step(at_step, _dig_under.bind(id))


func _dig_under(id: int) -> void:
	var rec: Array = _gone.get(id, [])
	_gone.erase(id)
	if rec.is_empty():
		return  # a joiner: the host's snapshot already holds what came of it
	var part: int = rec[0]
	var t: Transform3D = rec[1]
	var size := _part_size[part]
	var cell := _cell_of(t.origin).clamp(Vector2i.ZERO, Vector2i(GRID_X - 1, GRID_Z - 1))
	# Its room: the box it filled, shared out over the pieces lying on top of one another there.
	_digs.append([cell, size.x * size.y * size.z / cover / (CELL * CELL)])
	if _height_at(t.origin) < 0.05:
		return  # it lay on the floor: nothing under it
	# What it covered shows, then what rested on it falls into the room it left (onto those).
	var opened := _lay_open(part, t)
	if opened == 0:
		opened = _lay_open_nearest(t.origin)  # none touched it: the next one down round there shows
	_wake_over(part, t, WAKE_DEPTH)
	if opened > 0:
		return
	# Under the settled face the heap goes on: a piece made where this one lay, a little lower.
	var new_id := 0
	if id < HIDDEN_ID_START:
		var s := _slot_of_id(id)
		_slot_born[s] += 1
		new_id = _heap_id(s, _slot_born[s])
	else:
		_extra_born += 1
		new_id = EXTRA_ID_START + _extra_born
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var under := _pick_part(rng.randf(), true)
	var at := t.origin + Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04))
	at.y -= size[size.min_axis_index()] * UNDER_DROP
	_add_loose(new_id, under, _lay(under, at, rng))


## Buried piece `h` where it lies now (local, at the box centre, riding the surface).
func _hid_at(h: int) -> Transform3D:
	var t := _hid_xform[h]
	t.origin.y += _height_smooth(t.origin)
	return t


## Lays open the buried pieces piece `part` at `t` (local) lay on or against: each one turns into
## a loose piece where it lies. Returns how many.
func _lay_open(part: int, t: Transform3D) -> int:
	var reach := _part_size[part].length() * 0.5 + OPEN_REACH
	var c := _cell_of(t.origin)
	var r := ceili((reach + 0.3) / CELL)
	var n := 0
	for j in range(c.y - r, c.y + r + 1):
		for i in range(c.x - r, c.x + r + 1):
			if not _in_grid(Vector2i(i, j)):
				continue
			var key := j * GRID_X + i
			for h: int in _hid_cell.get(key, []):
				if _hid_open.has(h):
					continue
				var ht := _hid_at(h)
				# Over a piece that showed nothing lay buried, or a ray would have found it.
				if ht.origin.y > t.origin.y + 0.05 or ht.origin.distance_to(t.origin) > reach + _part_size[_hid_part[h]].length() * 0.5:
					continue
				_hid_open[h] = true
				_hid_left[key] -= 1
				_add_loose(HIDDEN_ID_START + h, _hid_part[h], ht)
				n += 1
	return n


## Lays open the buried piece nearest under `at` (local) in the cells round it, if any: every take
## shows something where it was. Returns 1 or 0.
func _lay_open_nearest(at: Vector3) -> int:
	var c := _cell_of(at)
	var best := -1
	var best_d := INF
	for j in range(c.y - 1, c.y + 2):
		for i in range(c.x - 1, c.x + 2):
			if not _in_grid(Vector2i(i, j)):
				continue
			for h: int in _hid_cell.get(j * GRID_X + i, []):
				if _hid_open.has(h):
					continue
				var ht := _hid_at(h)
				var d := ht.origin.distance_to(at)
				if ht.origin.y <= at.y + 0.05 and d < best_d:
					best = h
					best_d = d
	if best < 0:
		return 0
	var o := _hid_xform[best].origin
	_hid_open[best] = true
	_hid_left[_cell_of(o).y * GRID_X + _cell_of(o).x] -= 1
	_add_loose(HIDDEN_ID_START + best, _hid_part[best], _hid_at(best))
	return 1


## What rested on piece `part` at `t` (local), just taken, lets go: each piece touching it from
## above turns into a body and falls into the room it left, and what rested on those, `depth` deep.
## Local visuals like the tumbling ones: where they come to rest can differ a little between peers.
func _wake_over(part: int, t: Transform3D, depth: int) -> void:
	if depth <= 0 or _debris.size() >= MAX_DEBRIS:
		return
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _part_hull[part]
	q.transform = global_transform * t * _part_hull_at[part]
	q.margin = WAKE_MARGIN
	q.collision_mask = SCRAP_LAYER
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var rid: RID = hit.rid
		var wt: Transform3D
		var wpart := -1
		var wid := -1
		if _rid_slot.has(rid):
			var s: int = _rid_slot[rid]
			wt = _slot_at(s)
			if wt.origin.y <= t.origin.y:
				continue  # beside it or under it: it didn't rest on this one
			wpart = _slot_part[s]
			wid = _slot_id[s]
			_clear_slot(s)
		elif _spill_index.has(rid):
			wid = _spill_index[rid]
			var rec: Array = _id_index[wid]
			wt = rec[3]
			if wt.origin.y <= t.origin.y:
				continue
			wpart = rec[0]
			_remove_loose(wid)
		else:
			continue
		var body := _make_body(wpart, global_transform * wt)
		# Only the pieces round it hold it: the walkers' raised surface would throw it up.
		body.collision_mask = SCRAP_LAYER
		body.set_meta("id", wid)
		body.set_meta("since", -1.0)
		body.set_meta("soft", true)
		_debris.append(body)
		if _debris.size() >= MAX_DEBRIS:
			return
		_wake_over(wpart, wt, depth - 1)


## A resting transform for `part` at local point `p` on the heap's face: widest side down along
## the slope, tumbled, a quarter sunk at most into what is under it.
func _lay(part: int, p: Vector3, rng: RandomNumberGenerator) -> Transform3D:
	var s := _part_size[part]
	var thin := 0 if s.x <= s.y and s.x <= s.z else (1 if s.y <= s.z else 2)
	var lay := Basis()
	if thin == 0:
		lay = Basis(Vector3.BACK, PI * 0.5)
	elif thin == 2:
		lay = Basis(Vector3.RIGHT, PI * 0.5)
	var n := _cell_normal(_cell_of(p).clamp(Vector2i.ONE, Vector2i(GRID_X - 2, GRID_Z - 2)))
	var tumble := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.7))
	var b := Basis(Quaternion(Vector3.UP, n)) * tumble * Basis(Vector3.UP, rng.randf() * TAU) * lay
	p.y = maxf(p.y, _height_smooth(p)) + s[thin] * rng.randf_range(0.25, 0.5)
	return Transform3D(b, p)


## The piece a player looks at (the body `rid` the crosshair's ray hit): drawn in full with an
## outline, the one E takes. `on` false clears it. Local: each machine marks its own player's.
func highlight(_at: Vector3, on: bool, rid := RID()) -> void:
	var s: int = _rid_slot.get(rid, -1) if on else -1
	var id: int = _spill_index.get(rid, -1) if on else -1
	if s == _marked and id == _marked_loose:
		return
	if _marked >= 0 and not _surface_removed.has(_marked):
		_redraw_slot(_marked)
	if _marked_loose >= 0 and _id_index.has(_marked_loose):
		var was: Array = _id_index[_marked_loose]
		_spill[was[0]].multimesh.set_instance_transform(was[1], _drawn(was[0], was[3]))
	_marked = s
	_marked_loose = id
	_mark_mi.visible = s >= 0 or id >= 0
	if s >= 0:
		var p := _slot_part[s]
		_mark_mi.mesh = _part_mesh[p]
		_mark_mi.transform = _drawn(p, _slot_at(s))
		_surface[p].multimesh.set_instance_transform(_slot_index[s], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	elif id >= 0:
		var rec: Array = _id_index[id]
		_mark_mi.mesh = _part_mesh[rec[0]]
		_mark_mi.transform = _drawn(rec[0], rec[3])
		_spill[rec[0]].multimesh.set_instance_transform(rec[1], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


func _redraw_slot(s: int) -> void:
	var t := _slot_xform[s]
	var y := _height_smooth(t.origin)
	t.origin.y += y
	t = _drawn(_slot_part[s], t)
	if y < 0.03:
		t.basis = Basis.from_scale(Vector3.ZERO)
	_surface[_slot_part[s]].multimesh.set_instance_transform(_slot_index[s], t)


## A piece as a rigid body: its own convex hull and weight. `t` is global, at the box centre.
func _make_body(part: int, t: Transform3D) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = _part_mass[part]
	body.continuous_cd = true
	body.angular_damp = 1.5
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.8
	body.physics_material_override.bounce = 0.15
	var col := CollisionShape3D.new()
	col.shape = _part_hull[part]
	col.transform = _part_hull_at[part]
	body.add_child(col)
	var look := MeshInstance3D.new()
	look.mesh = _part_mesh[part]
	look.position = -_part_mid[part]
	body.add_child(look)
	body.collision_layer = SCRAP_LAYER
	body.collision_mask = 1 | SCRAP_LAYER
	body.top_level = true
	body.transform = t
	body.set_meta("part", part)
	add_child(body)
	return body


## Walkers kick resting loose pieces near their feet into real bodies; bodies that come to rest
## turn back into static loose pieces. Only these few dozen are ever simulated.
# Co-op: kicks are local visuals, so loose pieces can drift apart a little between peers.
func _update_awake() -> void:
	for walker in get_tree().get_nodes_in_group("walker"):
		var v: Vector3 = walker.velocity * Vector3(1, 0, 1)
		if v.length() < WAKE_SPEED or _awake.size() >= MAX_AWAKE:
			continue
		for hit in _loose_near(walker.global_position, WAKE_RADIUS, MAX_AWAKE - _awake.size()):
			var id: int = _spill_index.get(hit.rid, -1)
			if id < 0:
				continue
			var rec: Array = _id_index[id]
			var t: Transform3D = global_transform * rec[3]
			var part: int = rec[0]
			_remove_loose(id)
			_spawn_loose(id, part, t, v * randf_range(0.4, 0.9) + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.6), randf_range(-0.3, 0.3)))
	for i in range(_awake.size() - 1, -1, -1):
		var body := _awake[i]
		var age: int = Engine.get_physics_frames() - body.get_meta("woke")
		var resting := body.sleeping or (body.linear_velocity.length() < 0.03 and body.angular_velocity.length() < 0.2)
		if (age > 15 and resting) or age > 600:
			var t := global_transform.affine_inverse() * body.global_transform
			_add_loose(body.get_meta("id"), body.get_meta("part"), Transform3D(t.basis.orthonormalized(), t.origin))
			body.queue_free()
			_awake.remove_at(i)


func _loose_near(at: Vector3, radius: float, max_results := 32) -> Array[Dictionary]:
	_query_sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _query_sphere
	q.transform = Transform3D(Basis(), at)
	q.collision_mask = SCRAP_LAYER
	return get_world_3d().direct_space_state.intersect_shape(q, max_results)


## Throws `count` carried pieces from `from` along `dir` with some spread; they land loose.
func _on_bullets_thrown(from: Vector3, dir: Vector3, count: int, first_id: int) -> void:
	for n in count:
		var id := first_id + n
		var b := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
		var spread := Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)) * 1.2
		_spawn_loose(id, _pick_part(_hash01(id)), Transform3D(b, from + spread * 0.05), dir * randf_range(3.0, 6.0) + spread)


func _spawn_loose(id: int, part: int, t: Transform3D, velocity: Vector3) -> void:
	var body := _make_body(part, Transform3D(t.basis.orthonormalized(), t.origin))
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	body.set_meta("woke", Engine.get_physics_frames())
	body.set_meta("id", id)
	_awake.append(body)


## Host: the heap as it is now, for a player joining mid-game (GameState sends it). Heights,
## what is still sliding, slumping and digging (so both go on the same way), the surface pieces
## picked off, and thrown pieces with where they lie. Pieces taken from the starting spill come
## separately (GameState's taken ids).
func snapshot() -> Array:
	var thrown := []  # thrown pieces and the heap's own that lie loose (shown under a taken one, fallen)
	for id: int in _id_index:
		if id >= GameState.THROWN_ID_START:
			thrown.append([id, _id_index[id][0], _id_index[id][3]])
	for body: RigidBody3D in _awake + _debris:
		if body.has_meta("id") and body.get_meta("id") >= GameState.THROWN_ID_START:
			var t := global_transform.affine_inverse() * body.global_transform
			thrown.append([body.get_meta("id"), body.get_meta("part"), Transform3D(t.basis.orthonormalized(), t.origin)])
	return [_h, _active, _digs, _surface_removed, thrown, _slump, step, _slot_born, _slot_id, _hid_open, _extra_born]


## Joiner: takes the host's snapshot() over the starting heap this machine built.
func restore(snap: Array) -> void:
	_h = snap[0]
	_active.assign(snap[1])
	_any_active = _active.any(func(r: Rect2i) -> bool: return r.has_area())
	_digs = snap[2]
	_slot_born = snap[7]
	for s: int in snap[3]:
		_clear_slot(s)
		_surface_removed[s] = snap[3][s]
	_slot_id = snap[8]
	for h: int in snap[9]:  # laid open on the host: what is left of them comes with the thrown ones
		if not _hid_open.has(h):
			_hid_open[h] = true
			var c := _cell_of(_hid_xform[h].origin)
			_hid_left[c.y * GRID_X + c.x] -= 1
	_extra_born = snap[10]
	for b: Array in snap[4]:
		if not _id_index.has(b[0]):
			_add_loose(b[0], b[1], b[2])
	_slump = snap[5]
	_any_slump = _slump.has(1)
	step = snap[6]
	_host_step = step
	_mark(_dirty, Rect2i(0, 0, GRID_X, GRID_Z))
	_any_dirty = true


func _exit_tree() -> void:
	for rec: Array in _id_index.values():
		PhysicsServer3D.free_rid(rec[2])
	for rid: RID in _rid_slot:
		PhysicsServer3D.free_rid(rid)


## Scrap dug out of the heap in bulk at `at` (tools, the old count): the surface comes down there
## and the pieces on it ride it down.
func _on_bullets_taken(at: Vector3, count: int, at_step: int) -> void:
	var local := to_local(at)
	var cell := _cell_of(local).clamp(Vector2i.ZERO, Vector2i(GRID_X - 1, GRID_Z - 1))
	_at_step(at_step, func() -> void: _digs.append([cell, count * unit / (CELL * CELL)]))
	if not Net.is_client:
		_strain_at(cell, count)


## Runs a heap change now on the host; on a client at step `at_step`, where the host ran it.
func _at_step(at_step: int, change: Callable) -> void:
	_host_step = maxi(_host_step, at_step)
	if not Net.is_client or at_step <= step:
		change.call()
	else:
		_pending.append([at_step, change])


func _run_pending() -> void:
	while not _pending.is_empty() and _pending[0][0] <= step:
		_pending.pop_front()[1].call()


## Host: a take off a locked face strains it; past its limit, that part of the face gives way.
## The limit and the size of the fall are rolled here and nowhere else.
func _strain_at(cell: Vector2i, count: int) -> void:
	if _steepest_near(cell) < REPOSE_STEP * STRAIN_SLOPE:
		return
	var t := (cell.y / TILE) * TILES_X + cell.x / TILE
	if not _limit.has(t):
		_limit[t] = randf_range(STRAIN_MIN, STRAIN_MAX)
	_strain[t] = _strain.get(t, 0.0) + 1.0 + log(float(count))
	if _strain[t] >= _limit[t]:
		_strain.erase(t)
		_limit.erase(t)
		var r := roundi(randf_range(SLUMP_RADIUS.x, SLUMP_RADIUS.y) / CELL)
		GameState.collapse_scrap(cell, r, randi())


## Steepest step between neighbours within two cells of `cell`.
func _steepest_near(cell: Vector2i) -> float:
	var worst := 0.0
	for y in range(maxi(cell.y - 2, 0), mini(cell.y + 3, GRID_Z - 1)):
		for x in range(maxi(cell.x - 2, 0), mini(cell.x + 3, GRID_X - 1)):
			var k := y * GRID_X + x
			worst = maxf(worst, maxf(absf(_h[k] - _h[k + 1]), absf(_h[k] - _h[k + GRID_X])))
	return worst


## A part of the face gives way (GameState scrap_collapse, the host's call): round `cell` and up
## the slope above it everything slumps to REPOSE_SLOPE, so the top comes down with it; pieces
## tumble off the face from `seed`.
func _on_collapse(cell: Vector2i, radius: int, seed: int, at_step: int) -> void:
	_at_step(at_step, _collapse.bind(cell, radius, seed))


func _collapse(cell: Vector2i, radius: int, seed: int) -> void:
	# Uphill: against the slope's fall line, where the face comes down from.
	var k := clampi(cell.y, 1, GRID_Z - 2) * GRID_X + clampi(cell.x, 1, GRID_X - 2)
	var up := Vector2(_h[k + 1] - _h[k - 1], _h[k + GRID_X] - _h[k - GRID_X])
	up = up.normalized() if up.length() > 1e-5 else Vector2(-1, 0)
	var top := Vector2(cell) + up * radius * 1.3
	for tj in TILES_Z:
		for ti in TILES_X:
			var c := Vector2((ti + 0.5) * TILE, (tj + 0.5) * TILE)
			if c.distance_to(Vector2(cell)) < radius + TILE * 0.7 or c.distance_to(top) < radius * 1.4 + TILE * 0.7:
				_slump[tj * TILES_X + ti] = 1
				_mark(_active, Rect2i(ti * TILE, tj * TILE, TILE, TILE))
	_any_slump = true
	_any_active = true
	_shape_timer = 0.0
	_tumble(cell, top, radius, seed)


## Real pieces off the slumping face: from the drawn ones over it, which go, and fall from where
## they lay down the slope.
func _tumble(cell: Vector2i, top: Vector2, radius: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var want := mini(rng.randi_range(18, 36) + radius, MAX_DEBRIS)
	while _debris.size() + want > MAX_DEBRIS and not _debris.is_empty():
		_settle(_debris.pop_front())  # the oldest stop where they are
	var fall := (Vector2(cell) - top).normalized()
	for n in want * 4:
		if want <= 0:
			break
		var c := Vector2i(Vector2(cell).lerp(top, rng.randf()) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * radius)
		if not _in_grid(c):
			continue
		var key := c.y * GRID_X + c.x
		var s0 := _cell_first[key]
		var s1 := _cell_first[key + 1]
		if s1 == s0:
			continue
		var s := s0 + rng.randi() % (s1 - s0)
		if _slot_id[s] < 0:
			continue
		var t := _slot_at(s)
		t.origin.y += 0.05
		var body := _make_body(_slot_part[s], global_transform * t)
		body.set_meta("id", _slot_id[s])  # the same piece, picked up the same way while it rolls
		_clear_slot(s)
		var speed := rng.randf_range(1.0, 3.5)
		body.linear_velocity = global_basis * Vector3(fall.x * speed, rng.randf_range(-0.5, 1.0), fall.y * speed)
		body.angular_velocity = Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		body.set_meta("since", -1.0)
		_debris.append(body)
		want -= 1


## Tumbling pieces shove walkers they hit; once still, each lies where it stopped as a loose
## piece of its own (its id kept), which sinks into the heap or falls again as the heap moves.
func _update_debris(delta: float) -> void:
	var walkers := get_tree().get_nodes_in_group("walker")
	for i in range(_debris.size() - 1, -1, -1):
		var body := _debris[i]
		var v := body.linear_velocity
		for w: Node3D in walkers:
			var mid := w.global_position + Vector3.UP * 0.9
			var d := body.global_position - mid
			if absf(d.y) < 1.0 and Vector2(d.x, d.z).length() < SHOVE_REACH and v.length() > 0.8 and w.has_method("shove"):
				w.shove(Vector3(v.x, 0.0, v.z) * SHOVE_SHARE)
		if body.has_meta("soft"):
			# One let go by a take has only the pieces round it to hold it: reaching the heap's own
			# surface it comes to rest there (nothing that shows lies under it).
			var local := to_local(body.global_position)
			var floor_y := _height_smooth(local)
			if local.y < floor_y:
				body.global_position += global_basis.y * (floor_y - local.y)
				_settle(body)
				_debris.remove_at(i)
				continue
		var since: float = body.get_meta("since")
		if body.sleeping or (v.length() < 0.05 and body.angular_velocity.length() < 0.2):
			body.set_meta("since", 0.0 if since < 0.0 else since + delta)
		else:
			body.set_meta("since", -1.0)
		if since > 0.5:
			_settle(body)
			_debris.remove_at(i)


## A moving piece comes to rest: it lies there as a loose piece with its id (bodies only while
## they move).
func _settle(body: RigidBody3D) -> void:
	var t := global_transform.affine_inverse() * body.global_transform
	if body.has_meta("id") and not _id_index.has(body.get_meta("id")):
		_add_loose(body.get_meta("id"), body.get_meta("part"), Transform3D(t.basis.orthonormalized(), t.origin))
	body.queue_free()


## Where the heap rises under a walker (a slump pouring onto them) it shoves them off down the
## slope: a height field can't push a body by itself.
func _update_pour(delta: float) -> void:
	for w: Node3D in get_tree().get_nodes_in_group("walker"):
		var local := to_local(w.global_position)
		var c := _cell_of(local)
		if not _in_grid(c) or c.x < 1 or c.y < 1 or c.x > GRID_X - 2 or c.y > GRID_Z - 2:
			_walker_h.erase(w)
			continue
		var y := _height_smooth(local)
		var was: float = _walker_h.get(w, y)
		_walker_h[w] = y
		var rise := (y - was) / delta
		if rise > 0.05 and w.has_method("shove"):
			var k := c.y * GRID_X + c.x
			var down := Vector3(_h[k - 1] - _h[k + 1], 0.0, _h[k - GRID_X] - _h[k + GRID_X])
			if down.length() < 1e-4:
				down = Vector3(1, 0, 0)  # flat: out toward the hall
			w.shove(global_basis * down.normalized() * minf(rise * POUR_SHOVE, 7.0))


func _physics_process(delta: float) -> void:
	_update_awake()
	_update_debris(delta)
	# A client's heap keeps to the host's clock: behind, it catches up a few steps; level, it waits.
	var steps := clampi(_host_step - step, 0, CATCH_UP) if Net.is_client else 1
	for n in steps:
		_run_pending()
		step += 1
		_step()
	_run_pending()
	if not Net.is_client and step % CLOCK_EVERY == 0:
		GameState.send_heap_clock(step)

	if _any_dirty:
		_tex_prev.update(_img)
		_img.set_data(GRID_X, GRID_Z, false, Image.FORMAT_RF, _h.to_byte_array())
		_tex.update(_img)
		_prev_stale = true
		for area in _dirty:
			if area.has_area():
				_update_cells(area)
		_dirty.fill(Rect2i())
		_any_dirty = false
		_shape_dirty = true
	elif _prev_stale:
		_tex_prev.update(_img)
		_prev_stale = false
	# Pieces on a slumping face move every few frames: thousands of them, every frame cost 20 ms.
	if not _any_slump or Engine.get_physics_frames() % SLUMP_REDRAW_EVERY == 0:
		for area in _redraw:
			if area.has_area():
				_update_surface_pieces(area)
				if _far:
					_far.redraw(area)
		_redraw.fill(Rect2i())
	_update_pour(delta)
	_shape_timer -= delta
	if _shape_dirty and (_shape_timer <= 0.0 or _any_slump and _shape_timer <= COLLISION_INTERVAL - SLUMP_COLLISION_INTERVAL):
		_update_shape()


## One heap step: digs, then slides.
func _step() -> void:
	for dig in _digs:
		dig[1] = _dig(dig[0], dig[1])
	_digs = _digs.filter(func(d: Array) -> bool: return d[1] > 1e-9 and (_any_active or _material_near(d[0])))
	for pass_i in (SLUMP_PASSES if _any_slump else RELAX_PASSES):
		if not _any_active:
			break
		_relax()
	if _any_slump and not _any_active:  # the face came to rest: it locks again where it lies
		_slump.fill(0)
		_any_slump = false


func _process(_delta: float) -> void:
	heap_material.set_shader_parameter("blend", Engine.get_physics_interpolation_fraction())


## Removes up to `amount` height-metres around `cell`, Gaussian-weighted; returns the rest.
func _dig(cell: Vector2i, amount: float) -> float:
	var total := 0.0
	var n := 0
	for y in range(cell.y - DIG_RADIUS, cell.y + DIG_RADIUS + 1):
		for x in range(cell.x - DIG_RADIUS, cell.x + DIG_RADIUS + 1):
			if x >= 0 and y >= 0 and x < GRID_X and y < GRID_Z:
				total += _dig_w[n] * signf(_h[y * GRID_X + x])
			n += 1
	if total <= 0.0:
		return amount
	var left := amount
	n = 0
	for y in range(cell.y - DIG_RADIUS, cell.y + DIG_RADIUS + 1):
		for x in range(cell.x - DIG_RADIUS, cell.x + DIG_RADIUS + 1):
			if x >= 0 and y >= 0 and x < GRID_X and y < GRID_Z:
				var k := y * GRID_X + x
				var take := minf(_h[k], amount * _dig_w[n] / total)
				_h[k] -= take
				left -= take
			n += 1
	var area := Rect2i(cell - Vector2i.ONE * (DIG_RADIUS + 1), Vector2i.ONE * (DIG_RADIUS * 2 + 3))
	_mark(_active, area)
	_mark(_dirty, area)
	_any_active = true
	_any_dirty = true
	return maxf(left, 0.0)


func _material_near(cell: Vector2i) -> bool:
	for y in range(maxi(cell.y - DIG_RADIUS, 0), mini(cell.y + DIG_RADIUS + 1, GRID_Z)):
		for x in range(maxi(cell.x - DIG_RADIUS, 0), mini(cell.x + DIG_RADIUS + 1, GRID_X)):
			if _h[y * GRID_X + x] > 0.0:
				return true
	return false


## One pass over the active tiles: any neighbour pair steeper than it may stand (LOCK_STEP, or
## REPOSE_STEP where a face is giving way) sheds half the excess downhill. What moved is marked
## dirty and, grown a cell up and left so slides cross tile edges, becomes the next pass's area.
# Rows run top to bottom across a whole tile row, so one dig visits cells in the same order
# as a single rectangle would.
func _relax() -> void:
	var cur := _active.duplicate()
	_active.fill(Rect2i())
	_any_active = false
	var lo_x := PackedInt32Array()
	lo_x.resize(TILES_X * TILES_Z)
	lo_x.fill(GRID_X)
	var lo_y := lo_x.duplicate()
	var hi_x := PackedInt32Array()
	hi_x.resize(TILES_X * TILES_Z)
	hi_x.fill(-1)
	var hi_y := hi_x.duplicate()
	var h := _h
	_h = PackedFloat32Array()  # h is then the only reference: writes don't copy the array
	var slump := _slump
	for tj in TILES_Z:
		var row: Array[int] = []
		var y0 := GRID_Z
		var y1 := 0
		for t in range(tj * TILES_X, tj * TILES_X + TILES_X):
			var r: Rect2i = cur[t]
			if r.has_area():
				row.append(t)
				y0 = mini(y0, r.position.y)
				y1 = maxi(y1, r.end.y)
		for j in range(y0, mini(y1, GRID_Z - 1)):
			var down_t := TILES_X if (j + 1) % TILE == 0 else 0  # the neighbour below is in the next tile row
			for t in row:
				var r: Rect2i = cur[t]
				if j < r.position.y or j >= r.end.y:
					continue
				var first := -1
				var last := -1
				var loose := slump[t] == 1
				var step_in := REPOSE_STEP if loose else LOCK_STEP
				var step_down := REPOSE_STEP if loose or slump[mini(t + down_t, slump.size() - 1)] == 1 else LOCK_STEP
				for i in range(r.position.x, mini(r.end.x, GRID_X - 1)):
					var k := j * GRID_X + i
					var hk := h[k]
					var step := step_in if (i + 1) % TILE != 0 else (REPOSE_STEP if loose or slump[t + 1] == 1 else LOCK_STEP)
					var d := hk - h[k + 1]  # right neighbour
					if absf(d) > step + MIN_SLIDE:
						var m := (absf(d) - step) * 0.5 * signf(d)
						hk -= m
						h[k] = hk
						h[k + 1] += m
						last = i
						if first < 0:
							first = i
					d = hk - h[k + GRID_X]  # neighbour below
					if absf(d) > step_down + MIN_SLIDE:
						var m := (absf(d) - step_down) * 0.5 * signf(d)
						h[k] = hk - m
						h[k + GRID_X] += m
						last = i
						if first < 0:
							first = i
				if last >= 0:
					lo_x[t] = mini(lo_x[t], first)
					lo_y[t] = mini(lo_y[t], j)
					hi_x[t] = maxi(hi_x[t], last + 1)
					hi_y[t] = maxi(hi_y[t], j + 1)
	_h = h
	for t in TILES_X * TILES_Z:
		if hi_x[t] < 0:
			continue
		var moved := Rect2i(lo_x[t], lo_y[t], hi_x[t] - lo_x[t] + 1, hi_y[t] - lo_y[t] + 1)
		_mark(_active, moved.grow_individual(1, 1, 0, 0))  # a pair is checked from its left / upper cell
		_mark(_dirty, moved)
		_any_active = true
		_any_dirty = true


## Adds `area` to the per-tile rectangles in `tiles`, split along tile edges.
func _mark(tiles: Array[Rect2i], area: Rect2i) -> void:
	area = area.intersection(Rect2i(0, 0, GRID_X, GRID_Z))
	if not area.has_area():
		return
	for tj in range(area.position.y / TILE, (area.end.y - 1) / TILE + 1):
		for ti in range(area.position.x / TILE, (area.end.x - 1) / TILE + 1):
			var part := area.intersection(Rect2i(ti * TILE, tj * TILE, TILE, TILE))
			var t := tj * TILES_X + ti
			tiles[t] = part if not tiles[t].has_area() else tiles[t].merge(part)


## Copies changed cells into the collision heights, and queues the pieces around cells that
## drifted a visible amount since they were last drawn.
func _update_cells(area: Rect2i) -> void:
	# Chunks share their edge row, so a cell on one's last row is the next one's first.
	for cz in range(maxi(area.position.y - 1, 0) / CHUNK, mini((area.end.y - 1) / CHUNK, CHUNKS_Z - 1) + 1):
		for cx in range(maxi(area.position.x - 1, 0) / CHUNK, mini((area.end.x - 1) / CHUNK, CHUNKS_X - 1) + 1):
			_chunk_dirty[cz * CHUNKS_X + cx] = 1
	for j in range(area.position.y, area.end.y):
		for i in range(area.position.x, area.end.x):
			var key := j * GRID_X + i
			var h := _h[key]
			if absf(h - _drawn_h[key]) >= REDRAW_STEP:
				_drawn_h[key] = h
				_mark(_redraw, Rect2i(i - 1, j - 1, 3, 3))
			if _on_heap.has(key):
				_loose_follow(key)


## Loose pieces lying on the heap at cell `key` go with it: where it rises over one, that one is
## inside the heap now; where it drops away under one, that one falls.
func _loose_follow(key: int) -> void:
	for id: int in _on_heap[key].duplicate():
		var rec: Array = _id_index[id]
		var part: int = rec[0]
		var t: Transform3D = rec[3]
		var y := _height_smooth(t.origin)
		var half := _part_size[part][_part_size[part].min_axis_index()] * 0.5
		if y > t.origin.y + half + BURY:  # covered over: what slid onto it shows its own pieces
			_remove_loose(id)
		elif _top(t.origin) < t.origin.y - half - FALL:  # what it lay on (the pieces over the surface too) is gone
			_remove_loose(id)
			while _debris.size() >= MAX_DEBRIS:
				_settle(_debris.pop_front())
			var body := _make_body(part, global_transform * t)
			body.set_meta("id", id)
			body.set_meta("since", -1.0)
			_debris.append(body)


## Keeps surface pieces riding the cells in `area` (they sink with it, deeper into one another);
## hides them where the heap is gone.
func _update_surface_pieces(area: Rect2i) -> void:
	var h := _h
	for j in range(area.position.y, area.end.y):
		for i in range(area.position.x, area.end.x):
			var key := j * GRID_X + i
			for s in range(_cell_first[key], _cell_first[key + 1]):
				if s == _marked:
					continue
				var k := _slot_k[s]
				var f := _slot_f[s]
				var y := lerpf(lerpf(h[k], h[k + 1], f.x), lerpf(h[k + GRID_X], h[k + GRID_X + 1], f.x), f.y)
				if _surface_removed.has(s):
					# Dug on down, or covered by what slid: the next piece of the heap shows there.
					# Not while settled pieces lie buried there: those show as they are laid open.
					if absf(y - _surface_removed[s]) < RESURFACE or y < 0.03 or _hid_left[key] > 0:
						continue
					_surface_removed.erase(s)
					_slot_born[s] += 1
					_slot_id[s] = _heap_id(s, _slot_born[s])
				var c := _slot_xform[s]
				c.origin.y += y
				var t := _drawn(_slot_part[s], c)
				if y < 0.03:  # the heap is gone from under it
					t.basis = Basis.from_scale(Vector3.ZERO)
					_set_slot_body(s, null)
				elif absf(y - _slot_body_y[s]) > BODY_STEP or not _slot_rid[s].is_valid():
					_slot_body_y[s] = y
					_set_slot_body(s, c)
				_surface[_slot_part[s]].multimesh.set_instance_transform(_slot_index[s], t)


func _update_shape() -> void:
	for c in _chunk_dirty.size():
		if _chunk_dirty[c] == 0:
			continue
		_chunk_dirty[c] = 0
		var x0 := (c % CHUNKS_X) * CHUNK
		var z0 := (c / CHUNKS_X) * CHUNK
		var data := PackedFloat32Array()
		data.resize((CHUNK + 1) * (CHUNK + 1))
		for j in CHUNK + 1:
			var z := z0 + j
			if z >= GRID_Z:
				break
			for i in CHUNK + 1:
				var x := x0 + i
				if x >= GRID_X:
					break
				var k := z * GRID_X + x
				data[j * (CHUNK + 1) + i] = (_h[k] + (_pad[k] if _h[k] > 0.03 and not _pad.is_empty() else 0.0)) / CELL
		_shapes[c].map_data = data
	_shape_dirty = false
	_shape_timer = COLLISION_INTERVAL


## The least pieces that must leave the heap before the surface over world point `p` is down
## to it: everything above a cone at LOCK_SLOPE (the steepest the heap stands) with its tip at
## `p` has to go, however one digs (key_cache.gd: what a key costs).
func min_take(p: Vector3) -> int:
	var c := _cell_of(to_local(p))
	var y := p.y - global_position.y
	var reach := ceili((TOP - y) / LOCK_STEP) + 1
	var vol := 0.0
	for j in range(maxi(c.y - reach, 0), mini(c.y + reach + 1, GRID_Z)):
		for i in range(maxi(c.x - reach, 0), mini(c.x + reach + 1, GRID_X)):
			var cone := y + LOCK_STEP * (absi(i - c.x) + absi(j - c.y))
			vol += maxf(_h[j * GRID_X + i] - cone, 0.0)
	return int(vol * CELL * CELL / unit)


## Height field cells, for spots over the heap (key_cache.gd).
func cells() -> Vector2i:
	return Vector2i(GRID_X, GRID_Z)


func cell_world(c: Vector2i) -> Vector3:
	return global_transform * (_cell_pos(c) + Vector3.UP * _h[c.y * GRID_X + c.x])


func _cell_of(local: Vector3) -> Vector2i:
	return Vector2i(floori(local.x / CELL + GRID_X * 0.5), floori(local.z / CELL + GRID_Z * 0.5))


func _cell_pos(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (GRID_X - 1) * 0.5) * CELL, 0.0, (cell.y - (GRID_Z - 1) * 0.5) * CELL)


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID_X and c.y < GRID_Z


## World height of the heap's surface above `world` (the floor where there is no heap); for
## things buried in it, like the crate keys.
func surface_y(world: Vector3) -> float:
	return global_position.y + _height_smooth(to_local(world))


## Where things stand on the heap at `world`: the surface plus the pieces lying on it there.
func walk_y(world: Vector3) -> float:
	return global_position.y + _top(to_local(world))


func _top(local: Vector3) -> float:
	var y := _height_smooth(local)
	var c := _cell_of(local)
	return y + (_pad[c.y * GRID_X + c.x] if y > 0.03 and _in_grid(c) and not _pad.is_empty() else 0.0)


func _height_at(local: Vector3) -> float:
	var c := _cell_of(local)
	return _h[c.y * GRID_X + c.x] if _in_grid(c) else 0.0


## Height between cell centres, interpolated like the drawn surface (bilinear).
func _height_smooth(local: Vector3) -> float:
	var u := local.x / CELL + (GRID_X - 1) * 0.5
	var v := local.z / CELL + (GRID_Z - 1) * 0.5
	var i := clampi(floori(u), 0, GRID_X - 2)
	var j := clampi(floori(v), 0, GRID_Z - 2)
	var fx := clampf(u - i, 0.0, 1.0)
	var fz := clampf(v - j, 0.0, 1.0)
	var k := j * GRID_X + i
	return lerpf(lerpf(_h[k], _h[k + 1], fx), lerpf(_h[k + GRID_X], _h[k + GRID_X + 1], fx), fz)


func _cell_normal(c: Vector2i) -> Vector3:
	var k := c.y * GRID_X + c.x
	return Vector3(_h[k - 1] - _h[k + 1], 2.0 * CELL, _h[k - GRID_X] - _h[k + GRID_X]).normalized()


## 0..1 from an id, the same on every peer.
## A copy's tone from `key`: darker or lighter, a little more or less rust-brown.
static func _tone(key: int) -> Color:
	var c := Color.WHITE.lerp(RUST_TINT, _hash01(key * 31 + 7) * RUST_SHARE) * lerpf(TONE.x, TONE.y, _hash01(key))
	c.a = 1.0
	return c


## Part `p`'s material, taking each copy's tone (MultiMesh colours) on its colour.
func _toned(p: int) -> Material:
	var m := _part_mesh[p].surface_get_material(0)
	if m is ShaderMaterial:  # PS1 parts (materials/psx_prop.gdshader): the tone rides on COLOR
		var psx := m.duplicate() as ShaderMaterial
		psx.set_shader_parameter("vertex_tint", true)
		return psx
	if not m is BaseMaterial3D:
		return null
	var out := m.duplicate() as BaseMaterial3D
	out.vertex_color_use_as_albedo = true
	return out


static func _hash01(id: int) -> float:
	return float(hash(id) & 0xFFFF) / 65536.0
