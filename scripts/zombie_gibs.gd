extends Node3D
## A zombie coming apart: lumps of meat (the pen's own meat meshes, materials/env/gore) thrown out
## of `at`, falling, bouncing once and lying in a splash of blood. Each lump that lands is heard
## where it lands (zombie_voice.gd "chunk"), the first few only, so the rain of meat patters down
## over a second instead of a single thud. Visual and sound only; frees itself after LINGER s.
##   ZombieGibs.burst(world, at, dir, floor_y, count, scale)

const VOICE := preload("res://scripts/zombie_voice.gd")
const MESHES := [
	preload("res://materials/env/gore/meat_0.res"), preload("res://materials/env/gore/meat_1.res"),
	preload("res://materials/env/gore/meat_2.res"), preload("res://materials/env/gore/meat_3.res"),
]
const SPLATS := [
	preload("res://materials/env/decals/blood_splat_0.res"),
	preload("res://materials/env/decals/blood_splat_1.res"),
	preload("res://materials/env/decals/blood_splat_2.res"),
]
const GRAVITY := 9.8
const HEARD := 5  # lumps per burst that make a sound on landing
const LINGER := 10.0  # s on the floor before they sink away
const SINK := 1.5  # s to shrink out

var _lumps: Array[Dictionary] = []
var _floor := 0.0
var _heard := 0
var _age := 0.0
var _pitch := 1.0


## `dir`: the way the round was going (most of it flies on that way). `size`: the zombie's scale.
static func burst(world: Node, at: Vector3, dir: Vector3, floor_y: float, count: int, size := 1.0) -> void:
	var g = load("res://scripts/zombie_gibs.gd").new()
	world.add_child(g)
	g._floor = floor_y
	g._pitch = 1.0 / sqrt(size)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	for i in count:
		var m := MeshInstance3D.new()
		m.mesh = MESHES.pick_random()
		var s := randf_range(0.05, 0.13) * size
		m.scale = Vector3(s, s * randf_range(0.6, 0.9), s * randf_range(0.8, 1.2))
		g.add_child(m)
		m.global_position = at + Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.1), randf_range(-0.1, 0.1))
		var out := (flat * randf_range(0.5, 1.4) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.9)
		var v := out * randf_range(1.5, 3.5) + Vector3.UP * randf_range(2.0, 5.0)
		g._lumps.append({"node": m, "v": v, "spin": Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 12.0,
				"bounced": false, "rest": false, "r": s * 0.3})


func _process(delta: float) -> void:
	_age += delta
	for l in _lumps:
		if l.rest:
			continue
		var m: MeshInstance3D = l.node
		l.v.y -= GRAVITY * delta
		m.global_position += l.v * delta
		if l.spin.length() > 0.01:
			m.rotate(l.spin.normalized(), l.spin.length() * delta)
		if m.global_position.y > _floor + l.r:
			continue
		m.global_position.y = _floor + l.r
		if not l.bounced:  # first touch: splash, sound, a small hop
			l.bounced = true
			_landed(m.global_position, l.r)
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


func _landed(at: Vector3, r: float) -> void:
	if _heard < HEARD:
		_heard += 1
		VOICE.gore(&"chunk", at, -3.0 + r * 20.0, _pitch * (1.25 if r < 0.02 else 1.0))
	var d := Decal.new()
	d.texture_albedo = SPLATS.pick_random()
	d.normal_fade = 0.5
	var w := r * 14.0
	d.size = Vector3(w, 0.3, w)
	add_child(d)
	d.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), Vector3(at.x, _floor + 0.05, at.z))
