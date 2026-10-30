extends Node3D
## The railing's wear (GameState.fence, fence_wear; docs/ayrintilar.md "Çit"): the builder's railing
## (tools/build_arena.gd _firing_line) is left as it is, only its two long rails are swapped for a
## pair of halves per bay, so each bay can give on its own. The more a bay is clawed, the more its
## posts lean back over our side and its rails bow in and sag; clawed through, the top rail hangs
## snapped from one post, its other half lies on the floor and the bottom one sags to the ground.
## Mended, it straightens back. Every peer shows the same, from the host's fence_changed; the sparks
## of each claw (struck) come from each peer's own zombie, like its swing.
## Sounds come from the user (assets/sounds/fence/<slot>.ogg|wav): hit, break, repair. A missing
## file stays silent.

const SOUNDS := "res://assets/sounds/fence/"
const BREAK_AT := 8.0  # points clawed off one bay that tear it down
const LEAN := 0.5  # rad, a post at its worst
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
	for c in line.get_children():
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
	GameState.fence_changed.connect(_on_fence)
	_on_fence(GameState.fence, GameState.fence_wear)
	_shown = _goal.duplicate()
	_pose()


## A zombie's claw landed on the railing at `along` (z): sparks off the steel there, a clang.
func struck(along: float, kind: StringName) -> void:
	var low: bool = kind in [&"dog", &"crawler", &"blob"]
	_burst(Vector3(_x + 0.05, randf_range(0.3, 0.6) if low else randf_range(0.7, 1.05), along), 12, 1.0)
	_sound(&"hit", Vector3(_x, 0.8, along))


func _on_fence(_hp: int, wear: Array) -> void:
	if _halves.is_empty():
		return
	var bays := _halves.size()
	for b in bays:
		# GameState's bays and the builder's are the same 20; should they ever differ, by share.
		var w: float = wear[mini(b * wear.size() / bays, wear.size() - 1)] if not wear.is_empty() else 0.0
		var goal := clampf(w / BREAK_AT, 0.0, 1.0)
		var mid := Vector3(_x, _heights[0], (_posts[b].position.z + _posts[b + 1].position.z) * 0.5)
		if goal >= 1.0 and _goal[b] < 1.0:
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
			_shown[b] = move_toward(_shown[b], _goal[b], EASE * delta)
			moved = true
	if moved:
		_pose()


## Every post and rail where the wear shown puts them.
func _pose() -> void:
	var bays := _halves.size()
	for i in _posts.size():
		var d := maxf(_shown[i - 1] if i > 0 else 0.0, _shown[i] if i < bays else 0.0)
		var r := _rand(i)
		var lean := Basis(Vector3.BACK, d * LEAN * (0.65 + 0.35 * r)) * Basis(Vector3.RIGHT, d * (r - 0.5) * 0.3)
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
			if k == 0:  # the top rail snapped: one half hangs off its post, the other lies on the floor
				var span := c.z - a.z
				var from := a if r < 0.5 else c
				var hang := Vector3(_x - 0.3, 0.25, from.z + span * (0.3 if r < 0.5 else -0.3))
				_beam(pair[0], from, hang)
				var lie_z := (a.z + c.z) * 0.5 + span * (r - 0.5) * 0.4
				_beam(pair[1], Vector3(_x - 0.55 - r * 0.3, RAIL * 0.5, lie_z - span * 0.22),
						Vector3(_x - 0.75, RAIL * 0.5, lie_z + span * 0.22))
			else:  # the bottom one bent down to the ground
				var low := Vector3(_x - 0.45, RAIL * 0.5, (a.z + c.z) * 0.5)
				_beam(pair[0], a, low)
				_beam(pair[1], low, c)


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
