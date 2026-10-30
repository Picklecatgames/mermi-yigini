extends Node3D
## A zombie coming apart: lumps of meat (the pen's own meat meshes in the scanned flesh,
## materials/env/gore/flesh.tres) thrown out of `at`, falling, bouncing once and lying in a splash of
## blood (blood_fx.gd). Everything is rolled from `seed`, so the pieces fly the same on every peer. Each lump that lands is heard
## where it lands (zombie_voice.gd "chunk"), the first few only, so the rain of meat patters down
## over a second instead of a single thud. Visual and sound only; frees itself after LINGER s.
##   ZombieGibs.burst(world, at, dir, floor_y, count, scale, seed)

const VOICE := preload("res://scripts/zombie_voice.gd")
const MESHES := [
	preload("res://materials/env/gore/meat_0.res"), preload("res://materials/env/gore/meat_1.res"),
	preload("res://materials/env/gore/meat_2.res"), preload("res://materials/env/gore/meat_3.res"),
]
const FLESH := preload("res://materials/env/gore/flesh.tres")
const BLOOD := preload("res://scripts/blood_fx.gd")
const GRAVITY := 9.8
const HEARD := 5  # lumps per burst that make a sound on landing
const LINGER := 10.0  # s on the floor before they sink away
const SINK := 1.5  # s to shrink out
const LIMBS_MAX := 12  # torn limbs lying about at once (each a whole skinned model)

static var _limbs: Array[Node] = []

var _lumps: Array[Dictionary] = []
var _floor := 0.0
var _heard := 0
var _age := 0.0
var _pitch := 1.0
var _rng := RandomNumberGenerator.new()


## `dir`: the way the round was going (most of it flies on that way). `size`: the zombie's scale.
static func burst(world: Node, at: Vector3, dir: Vector3, floor_y: float, count: int, size := 1.0, seed := 0) -> void:
	var g = load("res://scripts/zombie_gibs.gd").new()
	world.add_child(g)
	var rng: RandomNumberGenerator = g._rng
	rng.seed = seed
	rng.state = 0
	g._floor = floor_y
	g._pitch = 1.0 / sqrt(size)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	for i in count:
		var m := MeshInstance3D.new()
		m.mesh = MESHES[rng.randi() % MESHES.size()]
		m.material_override = FLESH
		var s := rng.randf_range(0.05, 0.13) * size
		m.scale = Vector3(s, s * rng.randf_range(0.6, 0.9), s * rng.randf_range(0.8, 1.2))
		g.add_child(m)
		m.global_position = at + Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.05, 0.1), rng.randf_range(-0.1, 0.1))
		var out := (flat * rng.randf_range(0.5, 1.4) + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * 0.9)
		var v := out * rng.randf_range(1.5, 3.5) + Vector3.UP * rng.randf_range(2.0, 5.0)
		g._lumps.append({"node": m, "v": v, "spin": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 12.0,
				"bounced": false, "rest": false, "r": s * 0.3, "seed": rng.randi()})


## A torn-off limb (zombie_body.gd _piece(): a copy of the model showing only that limb, placed where
## it was) thrown off the body: out along `dir` and up, tumbling end over end, landing in a splash
## and settling flat. `joint` and `tip`: its two ends in the world. The oldest goes past LIMBS_MAX.
static func limb(world: Node, piece: Node3D, joint: Vector3, tip: Vector3, dir: Vector3, floor_y: float, size := 1.0, seed := 0) -> void:
	var g = load("res://scripts/zombie_gibs.gd").new()
	world.add_child(g)
	var live: Array[Node] = []
	for o in _limbs:  # (the ones gone already are freed objects: untyped)
		if is_instance_valid(o):
			live.append(o)
	_limbs = live
	_limbs.append(g)
	if _limbs.size() > LIMBS_MAX:
		_limbs.pop_front().queue_free()
	var rng: RandomNumberGenerator = g._rng
	rng.seed = seed
	rng.state = 0
	g._floor = floor_y
	g._pitch = 1.0 / sqrt(size)
	var pivot := Node3D.new()  # the limb turns about its middle
	g.add_child(pivot)
	pivot.global_position = (joint + tip) / 2.0
	var at := piece.transform
	pivot.add_child(piece)
	piece.global_transform = at
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var side := flat.cross(Vector3.UP) * rng.randf_range(-1.0, 1.0)
	var v := (flat * rng.randf_range(1.2, 2.6) + side * 1.2 + (joint - tip).normalized() * -0.6 + Vector3.UP * rng.randf_range(1.8, 3.2))
	var spin := (flat.cross(Vector3.UP) * rng.randf_range(-1.0, 1.0) + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1), 0.0))
	g._lumps.append({"node": pivot, "v": v, "spin": spin.normalized() * rng.randf_range(7.0, 13.0), "bounced": false,
			"rest": false, "r": 0.05 * size, "seed": rng.randi(), "axis": pivot.global_basis.inverse() * (tip - joint),
			"big": true})


func _process(delta: float) -> void:
	_age += delta
	for l in _lumps:
		if l.rest:
			if l.has("axis"):
				_lie_flat(l, delta)
			continue
		var m: Node3D = l.node
		l.v.y -= GRAVITY * delta
		m.global_position += l.v * delta
		if l.spin.length() > 0.01:
			m.rotate(l.spin.normalized(), l.spin.length() * delta)
		if m.global_position.y > _floor + l.r:
			continue
		m.global_position.y = _floor + l.r
		if not l.bounced:  # first touch: splash, sound, a small hop
			l.bounced = true
			_landed(m.global_position, l.r, l.seed)
			l.v = Vector3(l.v.x * 0.3, -l.v.y * 0.2, l.v.z * 0.3)
			l.spin *= 0.3
		else:
			l.rest = true
	if _age > LINGER:
		var k := clampf(1.0 - (_age - LINGER) / SINK, 0.0, 1.0)
		for l in _lumps:
			(l.node as Node3D).scale *= lerpf(1.0, k, 0.2)
		if k <= 0.0:
			queue_free()


## A limb at rest rolls over until it lies along the floor.
func _lie_flat(l: Dictionary, delta: float) -> void:
	var m: Node3D = l.node
	var along: Vector3 = m.global_basis * l.axis
	var flat := Vector3(along.x, 0.0, along.z)
	if flat.length() < 0.01 or along.normalized().dot(flat.normalized()) > 0.999:
		return
	var turn := Quaternion(along.normalized(), flat.normalized())
	var step := Quaternion.IDENTITY.slerp(turn, minf(1.0, 10.0 * delta))
	m.global_basis = Basis(step) * m.global_basis


func _landed(at: Vector3, r: float, seed: int) -> void:
	if _heard < HEARD:
		_heard += 1
		VOICE.gore(&"chunk", at, -3.0 + r * 20.0, _pitch * (1.25 if r < 0.02 else 1.0))
	_rng.seed = seed  # rolled at the burst: lumps land in a different order on each peer
	_rng.state = 0
	BLOOD.ground(get_parent(), at, _floor, [&"drop", &"smear"], _rng, r * 14.0)
