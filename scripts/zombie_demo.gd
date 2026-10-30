extends Node
## Throwaway preview of the Mixamo zombies in the real game (scenes/zombie_demo.tscn, F6), until the
## wave code exists: a zombie stands on every pen spawn, the alarms come on, the gates open and they
## walk out to the railing and claw at it. Shots land as on any target (no hit_gold: GameState pays
## them 1 like a straw dummy); enough of them and a zombie falls. When all are down a new lot comes after a pause.
## Local only, no co-op. Delete with the scene once the wave code takes over.

const BODY := preload("res://scripts/zombie_body.gd")
const ALARM_AT := 2.0  # s after the start
const GATES_AT := 3.5
const GATE_TIME := 2.5  # s to slide open
const RAIL_X := 14.8  # where they stop, just past the railing (x 14)
const RAIL_Z := 11.0  # ± along it
## kind -> walk speed (m/s), shots to kill (a head shot counts 3)
const STATS := {&"walker": [0.9, 5], &"runner": [3.0, 3], &"crawler": [0.6, 4], &"brute": [1.4, 25]}

var _zombies: Array[Dictionary] = []
var _round := 0
var _gates_open := false
var _spins: Array[Node3D] = []


func _ready() -> void:
	GameState.shot_landed.connect(_on_shot)
	await get_tree().process_frame  # Main is still adding its children
	_spawn()
	await get_tree().create_timer(ALARM_AT).timeout
	_alarms()
	await get_tree().create_timer(GATES_AT - ALARM_AT).timeout
	for g: Node3D in get_tree().get_nodes_in_group("wave_gate"):
		create_tween().tween_property(g, "position", g.position + g.get_meta("open_offset"), GATE_TIME) \
				.set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(GATE_TIME * 0.6).timeout
	_gates_open = true
	for z in _zombies:
		_release(z)


func _process(delta: float) -> void:
	for s in _spins:
		s.rotate_object_local(Vector3.UP, TAU * 0.8 * delta)
	for z in _zombies:
		if z.dead or z.path.is_empty():
			continue
		var node: StaticBody3D = z.node
		var to: Vector3 = z.path[0] - node.global_position
		to.y = 0.0
		z.stagger = maxf(0.0, z.stagger - delta)
		var step: float = z.speed * delta * (0.2 if z.stagger > 0.0 else 1.0)
		if to.length() <= step:
			node.global_position += to
			z.path.pop_front()
			if z.path.is_empty():
				node.look_at(node.global_position + Vector3.LEFT, Vector3.UP)
				_claw(z)
			continue
		node.global_position += to.normalized() * step
		var face := node.global_position + to
		node.global_transform = node.global_transform.interpolate_with(
				node.global_transform.looking_at(face, Vector3.UP), minf(1.0, 6.0 * delta))
	for z in _zombies:
		if not z.dead:
			(z.head_shape as Node3D).global_position = (z.head as Node3D).global_position


func _spawn() -> void:
	var spawns := get_tree().get_nodes_in_group("wave_spawn")
	for i in spawns.size():
		var at: Node3D = spawns[i]
		var seed := _round * 100 + i
		var kind := &"walker"
		match i % 8:
			3: kind = &"runner"
			6: kind = &"crawler"
		if i == 0 or i == 13:
			kind = &"brute"
		var node := StaticBody3D.new()
		node.name = "DemoZombie%d" % i
		node.add_to_group("target")
		node.add_to_group("flesh")  # impacts.gd leaves the wound to zombie_body.gd
		node.set_meta("demo", true)
		get_parent().add_child(node)
		node.global_transform = at.global_transform
		var body: Node3D = BODY.new()
		body.setup(kind, seed)
		node.add_child(body)
		var tall: float = body.height
		var trunk := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3 * tall / 1.8
		cap.height = (0.9 if kind == &"crawler" else tall - 0.25)
		trunk.shape = cap
		if kind == &"crawler":
			trunk.rotation.x = PI / 2
			trunk.position = Vector3(0, 0.35, 0)
		else:
			trunk.position = Vector3(0, cap.height / 2.0, 0)
		node.add_child(trunk)
		var head := CollisionShape3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 0.13 * tall / 1.8
		head.shape = ball
		head.add_to_group("weak_spot")
		node.add_child(head)
		_zombies.append({"node": node, "body": body, "kind": kind, "spawn": at,
				"head": body.attach("Head"), "head_shape": head, "trunk": trunk,
				"speed": STATS[kind][0], "hp": STATS[kind][1], "dead": false, "path": [], "seed": seed, "stagger": 0.0})
		if _gates_open:
			_release(_zombies[-1])


func _release(z: Dictionary) -> void:
	var gate: String = (z.spawn as Node).get_meta("gate")
	var mouth := Vector3.ZERO
	for g: Node in get_tree().get_nodes_in_group("wave_gate"):
		if g.get_meta("gate") == gate:
			mouth = g.get_meta("mouth")
	var r := absi(hash(z.seed))
	var rail := Vector3(RAIL_X, mouth.y, clampf(mouth.z + float(r % 1000) / 999.0 * 10.0 - 5.0, -RAIL_Z, RAIL_Z))
	await get_tree().create_timer(float(r % 600) / 100.0).timeout  # they don't all set off at once
	if z.dead:
		return
	z.path = [mouth, rail]
	if z.kind == &"brute" and float(r % 7) < 3.0:
		await get_tree().create_timer(z.body.scream()).timeout
	z.body.move(z.speed)


func _claw(z: Dictionary) -> void:
	while not z.dead and is_instance_valid(z.node):
		var t: float = z.body.attack()
		await get_tree().create_timer(t + 0.4).timeout


func _on_shot(_peer: int, at: Vector3, _n: Vector3, dir: Vector3, target: Node, _gold: int, weak: bool, _combo: int) -> void:
	if target == null or not target.has_meta("demo"):
		return
	for z in _zombies:
		if z.node != target or z.dead:
			continue
		z.body.wound(at, dir, weak)
		z.stagger = 0.35  # held back a moment by the hit
		z.hp -= 3 if weak else 1
		if z.hp > 0:
			z.body.hit()
			return
		z.dead = true
		z.path = []
		target.remove_from_group("target")
		(z.trunk as CollisionShape3D).disabled = true
		(z.head_shape as CollisionShape3D).disabled = true
		z.body.die()
		_cleanup(z)
		return


func _cleanup(z: Dictionary) -> void:
	await get_tree().create_timer(8.0).timeout
	z.node.queue_free()
	_zombies.erase(z)
	if _zombies.is_empty():
		await get_tree().create_timer(3.0).timeout
		_round += 1
		_spawn()


func _alarms() -> void:
	for a: Node in get_tree().get_nodes_in_group("wave_alarm"):
		for n in a.find_children("*", "", true, false) + [a]:
			if n is Light3D:
				n.visible = true
			if n is GeometryInstance3D and n.has_meta("lit_material"):
				n.material_override = n.get_meta("lit_material")
		var spin := a.find_child("Spin", true, false)
		if spin:
			_spins.append(spin)
