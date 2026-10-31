extends Node3D
## A zombie coming apart: lumps of meat (the pen's own meat meshes in the scanned flesh,
## materials/env/gore/flesh.tres) thrown out of `at`, falling, bouncing once and lying in a splash of
## blood (blood_fx.gd). Everything is rolled from `seed`, so the pieces fly the same on every peer;
## the caller makes `seed` from the death itself (waves.gd roll), so no two come apart alike. Each lump that lands is heard
## where it lands (zombie_voice.gd "chunk"), the first few only, so the rain of meat patters down
## over a second instead of a single thud. Visual and sound only; frees itself after LINGER s.
##   ZombieGibs.burst(world, at, dir, floor_y, count, scale, seed)
##   ZombieGibs.head(world, at, dir, floor_y, scale, seed, power)  # a skull coming apart

const VOICE := preload("res://scripts/zombie_voice.gd")
const MESHES := [
	preload("res://materials/env/gore/meat_0.res"), preload("res://materials/env/gore/meat_1.res"),
	preload("res://materials/env/gore/meat_2.res"), preload("res://materials/env/gore/meat_3.res"),
]
const FLESH := preload("res://materials/env/gore/flesh.tres")
## A head comes apart into a few middling lumps, many crumbs, chips of skull and bits of brain, all
## small next to the head: [how many (range), across (range, of HEAD_SIZE), material (FLESH, bone,
## brain), squashed (y scale range)]. Together they stay well under the head's own bulk
## (tools/blood_check.gd).
const HEAD_SIZE := 0.22  # m across at size 1
const HEAD_PIECES := [
	[[2, 4], [0.22, 0.38], 0, [0.6, 0.9]],
	[[10, 20], [0.07, 0.16], 0, [0.5, 1.0]],
	[[2, 5], [0.1, 0.2], 1, [0.25, 0.45]],
	[[1, 3], [0.14, 0.24], 2, [0.6, 0.9]],
]
const MARKS := 6  # lumps per burst that leave blood where they land; the crumbs don't
const BLOOD := preload("res://scripts/blood_fx.gd")
const GRAVITY := 9.8
const HEARD := 5  # lumps per burst that make a sound on landing
const LINGER := 10.0  # s on the floor before they sink away
const SINK := 1.5  # s to shrink out
const LIMBS_MAX := 12  # torn limbs lying about at once (each a whole skinned model)

static var _limbs: Array[Node] = []
static var _mats := []  # FLESH, bone, brain, wound: the same shader, other colours
static var _across := {}  # mesh -> its widest side as made, so a lump's scale is its size in m

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
	g._floor = floor_y
	g._pitch = 1.0 / sqrt(size)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized().rotated(Vector3.UP, rng.randf_range(-0.4, 0.4))
	for i in rng.randi_range(roundi(count * 0.7), roundi(count * 1.3)):
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
				"bounced": false, "rest": false, "r": s * 0.3, "seed": rng.randi(), "mark": i < MARKS})


## A skull coming apart at `at`: HEAD_PIECES, most of them thrown on along `dir` in a cone, some
## anywhere, the small ones faster. `power` (about 1) scales how hard. Rolled from `seed`.
static func head(world: Node, at: Vector3, dir: Vector3, floor_y: float, size := 1.0, seed := 0, power := 1.0) -> void:
	var g = load("res://scripts/zombie_gibs.gd").new()
	world.add_child(g)
	var rng: RandomNumberGenerator = g._rng
	rng.seed = seed
	g._floor = floor_y
	g._pitch = 1.0 / sqrt(size)
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
	var cone := rng.randf_range(0.35, 0.9)  # rad: tight this time, or wide
	var lean := rng.randf_range(-0.5, 0.5)  # the whole spray off to one side a little
	for kind: Array in HEAD_PIECES:
		for i in rng.randi_range(kind[0][0], kind[0][1]):
			var across: float = rng.randf_range(kind[1][0], kind[1][1]) * HEAD_SIZE * size
			var m := MeshInstance3D.new()
			m.mesh = MESHES[rng.randi() % MESHES.size()]
			m.material_override = material(kind[2])
			var s := across / _across_of(m.mesh)
			m.scale = Vector3(s * rng.randf_range(0.7, 1.3), s * rng.randf_range(kind[3][0], kind[3][1]), s * rng.randf_range(0.7, 1.3))
			m.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
			g.add_child(m)
			m.global_position = at + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1), rng.randf_range(-1, 1)) * 0.04 * size
			var out: Vector3
			if rng.randf() < 0.25:  # anywhere
				out = Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1), rng.randf_range(-1, 1)).normalized()
			else:
				out = flat.rotated(Vector3.UP, lean + rng.randf_range(-cone, cone))
				out = (out + Vector3.UP * rng.randf_range(0.2, 1.1)).normalized()
			var fast := clampf(0.06 * size / across, 0.8, 1.6)  # crumbs fly faster than lumps
			var v := out * rng.randf_range(2.0, 5.0) * power * fast + Vector3.UP * rng.randf_range(0.8, 2.5)
			g._lumps.append({"node": m, "v": v, "spin": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * rng.randf_range(8.0, 22.0),
					"bounced": false, "rest": false, "r": across * 0.3, "seed": rng.randi(), "mark": kind[2] == 0 and across > 0.05 * size})


## FLESH (0), bone (1), brain (2) or a torn stump's raw end (3, dark and wet with blood, not the
## pink of a lump): FLESH tinted, so it draws with the same shader.
static func material(i: int) -> Material:
	if _mats.is_empty():
		var wound: BaseMaterial3D = FLESH.duplicate()
		wound.albedo_color = Color(0.36, 0.05, 0.04)
		wound.clearcoat = 0.3
		wound.clearcoat_roughness = 0.5
		wound.normal_scale = 2.0
		var bone: BaseMaterial3D = FLESH.duplicate()
		bone.albedo_color = Color(0.93, 0.86, 0.72)
		bone.clearcoat = 0.2
		var brain: BaseMaterial3D = FLESH.duplicate()
		brain.albedo_color = Color(1.0, 0.72, 0.72)
		_mats = [FLESH, bone, brain, wound]
	return _mats[i]


static func _across_of(mesh: Mesh) -> float:
	if not _across.has(mesh):
		var box := mesh.get_aabb()
		_across[mesh] = maxf(box.size[box.get_longest_axis_index()], 0.001)
	return _across[mesh]


## A torn-off limb (zombie_body.gd _piece(): a copy of the model showing only that limb, placed where
## it was) thrown off the body: out along `dir` and up, tumbling end over end, landing in a splash
## and settling flat. `joint` and `tip`: its two ends in the world. The oldest goes past LIMBS_MAX.
## `upright`: it settles standing on one end or the other instead (a hat off a head).
static func limb(world: Node, piece: Node3D, joint: Vector3, tip: Vector3, dir: Vector3, floor_y: float, size := 1.0, seed := 0,
		upright := false) -> void:
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
			"big": true, "upright": upright})


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
			if l.get("mark", true):
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


## A limb at rest rolls over until it lies along the floor (or stands on an end, `upright`).
func _lie_flat(l: Dictionary, delta: float) -> void:
	var m: Node3D = l.node
	var along: Vector3 = m.global_basis * l.axis
	var flat := Vector3(along.x, 0.0, along.z)
	if l.upright:
		flat = Vector3(0.0, signf(along.y) if along.y != 0.0 else 1.0, 0.0)
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
	BLOOD.ground(get_parent(), at, _floor, [&"drop", &"smear"], _rng, r * 14.0)
