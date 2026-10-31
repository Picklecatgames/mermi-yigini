extends Node3D
## The railing's bays (GameState.fence_bays; docs/ayrintilar.md "Çit"): the builder's railing
## (tools/build_arena.gd _firing_line) is left as it is, only its two long rails, the wall that
## stops players and the rails' bullet stops are swapped for one of each per bay, so each bay can
## give on its own. The more a bay is clawed, the more its posts lean back over our side and its
## rails bow in and sag; clawed through, it comes down and leaves a hole: each rail snaps off a post,
## a stub hangs down it, the rest lies on our side of the floor, the posts either side lean away,
## and its wall and bullet stops go (the dead walk in through it, waves.gd). Mended, it straightens
## back and shuts. Every peer shows the same, from the host's fence_changed; the sparks of each claw
## (struck) come from each peer's own zombie, like its swing.
## Sounds come from the user (assets/sounds/fence/<slot>.ogg|wav): hit, break, repair. A missing
## file stays silent.

const SOUNDS := "res://assets/sounds/fence/"
const LEAN := 0.5  # rad, a post at its worst
const SPLAY := 0.22  # rad, a post beside a hole leaning away from it
const BOW := 0.32  # m, a rail bowed in at its worst
const SAG := 0.22  # m
const EASE := 2.5  # 1/s, the shown wear following the real one
const RAIL := 0.05  # m, the rails' square section
const MAX_SPARKS := 10  # bursts alive at once
const FLASHES := 4  # their lights, taken in turn

var _x := 0.0
var _heights: Array[float] = []  # the rails, top first
var _posts: Array[MeshInstance3D] = []  # along z
var _post_home: Array[Transform3D] = []
var _halves: Array = []  # per bay: per rail [half from the lower post, half from the upper post]
var _shown: Array[float] = []  # per bay, 0..1 (1 torn down), easing to _goal
var _goal: Array[float] = []
var _walls: Array[CollisionShape3D] = []  # per bay: its piece of the wall that stops players
var _stops: Array = []  # per bay: its rails' bullet stops (FiringLineBars)
var _sparks := 0
var _streams := {}  # slot -> AudioStream or null

## The sparks' flashes are made once and only dimmed: a light added mid-fight had every surface
## near it compile its pipelines again, a claw at a time (tools/spike_probe.gd).
var _flashes: Array[OmniLight3D] = []
var _next_flash := 0

static var _spark_mesh: BoxMesh


func _ready() -> void:
	var line := get_tree().root.find_child("FiringLine", true, false)
	if line == null:
		return
	for i in FLASHES:
		var flash := OmniLight3D.new()
		flash.light_color = Color(1.0, 0.65, 0.3)
		flash.omni_range = 2.0
		flash.light_energy = 0.0
		add_child(flash)
		_flashes.append(flash)
	var paint: Material = null
	var wall: CollisionShape3D = null
	for c in line.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D and (c.shape as BoxShape3D).size.z > 10.0:
			wall = c
		if not (c is MeshInstance3D and c.mesh is BoxMesh):
			continue
		var size: Vector3 = (c.mesh as BoxMesh).size
		if size.z > 10.0:  # a long rail: the bays' halves take its place
			paint = c.material_override
			_heights.append(c.position.y)
			_x = c.position.x
			c.visible = false
		elif size.y > 0.5:
			_posts.append(c)
	_heights.sort()
	_heights.reverse()
	_posts.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.z < b.position.z)
	for p in _posts:
		_post_home.append(p.transform)
	var unit := BoxMesh.new()
	unit.size = Vector3(RAIL, RAIL, 1.0)  # stretched along z to each half's length
	for b in _posts.size() - 1:
		var rails := []
		for h in _heights:
			var pair := []
			for k in 2:
				var m := MeshInstance3D.new()
				m.mesh = unit
				m.material_override = paint
				line.add_child(m)
				pair.append(m)
			rails.append(pair)
		_halves.append(rails)
		_shown.append(0.0)
		_goal.append(0.0)
	_split_wall(line, wall)
	_split_stops(line.get_parent().get_node_or_null("FiringLineBars") as Node3D)
	GameState.fence_changed.connect(_on_fence)
	_on_fence(GameState.fence_bays)
	_shown = _goal.duplicate()
	_pose()


## The one wall that stops players, wall to wall, cut into a piece per bay (the end ones out to the
## hall's walls), so a torn down bay lets the dead through.
func _split_wall(line: Node3D, wall: CollisionShape3D) -> void:
	if wall == null:
		return
	var box: BoxShape3D = wall.shape
	var ends := [wall.position.z - box.size.z * 0.5, wall.position.z + box.size.z * 0.5]
	wall.disabled = true
	for b in _halves.size():
		var z0: float = ends[0] if b == 0 else _posts[b].position.z
		var z1: float = ends[1] if b == _halves.size() - 1 else _posts[b + 1].position.z
		var cs := CollisionShape3D.new()
		var piece := BoxShape3D.new()
		piece.size = Vector3(box.size.x, box.size.y, z1 - z0)
		cs.shape = piece
		cs.position = Vector3(wall.position.x, wall.position.y, (z0 + z1) * 0.5)
		line.add_child(cs)
		_walls.append(cs)


## The long rails' bullet stops the same: a piece per bay and rail, gone with the bay.
func _split_stops(bars: Node3D) -> void:
	if bars == null:
		return
	var long: Array[CollisionShape3D] = []
	for c in bars.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D and (c.shape as BoxShape3D).size.z > 10.0:
			long.append(c)
	for b in _halves.size():
		var pieces := []
		var z0 := _posts[b].position.z
		var z1 := _posts[b + 1].position.z
		for rail in long:
			var size: Vector3 = (rail.shape as BoxShape3D).size
			var cs := CollisionShape3D.new()
			var piece := BoxShape3D.new()
			piece.size = Vector3(size.x, size.y, z1 - z0)
			cs.shape = piece
			cs.position = Vector3(rail.position.x, rail.position.y, (z0 + z1) * 0.5)
			bars.add_child(cs)
			pieces.append(cs)
		_stops.append(pieces)
	for rail in long:
		rail.disabled = true


## A zombie's claw landed on the railing at `along` (z): sparks off the steel there, a clang.
func struck(along: float, kind: StringName) -> void:
	var low: bool = kind in [&"dog", &"crawler", &"blob"]
	_burst(Vector3(_x + 0.05, randf_range(0.3, 0.6) if low else randf_range(0.7, 1.05), along), 12, 1.0)
	_sound(&"hit", Vector3(_x, 0.8, along))


func _on_fence(hp: Array) -> void:
	if _halves.is_empty():
		return
	var bays := _halves.size()
	for b in bays:
		# GameState's bays and the builder's are the same 20; should they ever differ, by share.
		var left: float = hp[mini(b * hp.size() / bays, hp.size() - 1)] if not hp.is_empty() else float(GameState.BAY_HP)
		var goal := clampf(1.0 - left / GameState.BAY_HP, 0.0, 1.0)
		var open := goal >= 1.0
		if b < _walls.size():
			_walls[b].disabled = open
		if b < _stops.size():
			for cs: CollisionShape3D in _stops[b]:
				cs.disabled = open
		var mid := Vector3(_x, _heights[0], (_posts[b].position.z + _posts[b + 1].position.z) * 0.5)
		if open and _goal[b] < 1.0:
			_burst(mid, 30, 2.0)
			_sound(&"break", mid)
		elif goal < _goal[b] - 0.01:  # mended: a shower off the welds
			_burst(mid + Vector3.DOWN * 0.3, 16, 0.6)
			_sound(&"repair", mid)
		_goal[b] = goal


func _process(delta: float) -> void:
	var moved := false
	for b in _shown.size():
		if not is_equal_approx(_shown[b], _goal[b]):
			# Coming down it drops at once (a hole is a hole); everything else eases.
			if _goal[b] >= 1.0:
				_shown[b] = 1.0
			else:
				_shown[b] = move_toward(minf(_shown[b], 0.999), _goal[b], EASE * delta)
			moved = true
	if moved:
		_pose()


## Every post and rail where the wear shown puts them.
func _pose() -> void:
	var bays := _halves.size()
	for i in _posts.size():
		var below := _shown[i - 1] if i > 0 else 0.0  # the bay on its -z side
		var above := _shown[i] if i < bays else 0.0
		var d := maxf(below, above)
		var r := _rand(i)
		# Beside a hole it leans away from it, out along the railing (a hole either side: upright).
		var splay := (_down(below) - _down(above)) * SPLAY * (0.7 + 0.6 * r)
		var lean := Basis(Vector3.BACK, d * LEAN * (0.65 + 0.35 * r)) * Basis(Vector3.RIGHT, d * (r - 0.5) * 0.3 + splay)
		var home := _post_home[i]
		var foot := home.origin - Vector3.UP * home.origin.y
		_posts[i].transform = Transform3D(lean, foot + lean * (Vector3.UP * home.origin.y))
	for b in bays:
		var d := _shown[b]
		var r := _rand(b + 100)
		for k in _heights.size():
			var a := _top(b, _heights[k])
			var c := _top(b + 1, _heights[k])
			var pair: Array = _halves[b][k]
			if d < 1.0:
				var mid := (a + c) * 0.5 + Vector3(-BOW * d * (0.7 + 0.6 * r), -SAG * d * (k + 1), 0.0)
				_beam(pair[0], a, mid)
				_beam(pair[1], mid, c)
				continue
			# Torn down, a hole: each rail snapped off one post (top and bottom off opposite ones).
			# A short stub hangs down that post, close in to it; the rest lies on our side of the
			# floor, out of the way through.
			var span := c.z - a.z
			var from_a := (r < 0.5) == (k == 0)
			var from := a if from_a else c
			var side := 1.0 if from_a else -1.0  # into the bay from that post
			_beam(pair[0], from, Vector3(_x - 0.12 - 0.1 * k, 0.12 + 0.1 * r, from.z + side * span * 0.12))
			var lie_x := _x - 0.75 - 0.45 * k - 0.25 * r
			var lie_z := (a.z + c.z) * 0.5 + span * (r - 0.5) * 0.3
			var tilt := (0.18 + 0.12 * r) * (1.0 if k == 0 else -1.0)
			_beam(pair[1], Vector3(lie_x + tilt, RAIL * 0.5, lie_z - span * 0.3),
					Vector3(lie_x - tilt, RAIL * 0.5, lie_z + span * 0.3))


## 1 for a bay shown torn down, else 0.
func _down(d: float) -> float:
	return 1.0 if d >= 1.0 else 0.0


## Where rail height `h` meets post `i` as it leans now.
func _top(i: int, h: float) -> Vector3:
	var t := _posts[i].transform
	return t.origin + t.basis * (Vector3.UP * (h - _post_home[i].origin.y))


## `m` stretched from `a` to `b`.
func _beam(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.001:
		m.visible = false
		return
	m.visible = true
	var up := Vector3.UP if absf(along.normalized().y) < 0.95 else Vector3.RIGHT
	var turn := Basis.looking_at(along, up).scaled_local(Vector3(1.0, 1.0, length))
	m.transform = Transform3D(turn, (a + b) * 0.5)


## The same 0..1 for `i` on every machine.
func _rand(i: int) -> float:
	return float(absi(hash(i * 7919 + 17)) % 1000) / 1000.0


## Hot sparks off the steel at `at` (world), flying back over our side and falling.
func _burst(at: Vector3, amount: int, force: float) -> void:
	if _sparks >= MAX_SPARKS or not is_inside_tree():
		return
	_sparks += 1
	var sparks := _make_sparks(amount, force)
	add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	var flash := _flashes[_next_flash]
	_next_flash = (_next_flash + 1) % _flashes.size()
	flash.global_position = at
	if flash.has_meta(&"tween"):
		(flash.get_meta(&"tween") as Tween).kill()
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.2).from(1.5 * force)
	flash.set_meta(&"tween", tw)
	sparks.finished.connect(func() -> void:
		_sparks -= 1
		sparks.queue_free())


func _make_sparks(amount: int, force: float) -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.amount = amount
	sparks.lifetime = 0.45
	sparks.direction = Vector3(-1.0, 0.6, 0.0)
	sparks.spread = 60.0
	sparks.initial_velocity_min = 1.5 * force
	sparks.initial_velocity_max = 3.5 * force
	sparks.gravity = Vector3(0, -9.8, 0)
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.2
	if _spark_mesh == null:
		_spark_mesh = BoxMesh.new()  # a streak, stretched along its flight
		_spark_mesh.size = Vector3(0.006, 0.006, 0.05)
		var hot := StandardMaterial3D.new()
		hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hot.albedo_color = Color(1.0, 0.72, 0.32)
		hot.emission_enabled = true
		hot.emission = Color(1.0, 0.6, 0.2)
		hot.emission_energy_multiplier = 4.0
		_spark_mesh.material = hot
	sparks.mesh = _spark_mesh
	sparks.particle_flag_align_y = false
	sparks.particle_flag_rotate_y = false
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # glowing streaks: no shadow pass to compile at the first claw
	return sparks


## One spark too small to see at `at` (in front of the camera), so the sparks' shader compiles with
## the hall: the first claw at the railing held its frame up 10-50 ms (tools/first_probe.gd).
func prewarm(at: Vector3) -> void:
	var sparks := _make_sparks(1, 0.0)
	sparks.scale_amount_min = 0.001
	sparks.scale_amount_max = 0.001
	sparks.gravity = Vector3.ZERO
	add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)


func _sound(slot: StringName, at: Vector3) -> void:
	if not _streams.has(slot):
		_streams[slot] = null
		for ext in [".ogg", ".wav"]:
			if ResourceLoader.exists(SOUNDS + String(slot) + ext):
				_streams[slot] = load(SOUNDS + String(slot) + ext)
	if _streams[slot] == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[slot]
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)
