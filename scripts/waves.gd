extends Node3D
## Zombie waves (docs/ayrintilar.md "Yeni yön: zombi dalgaları"). A player pulls the wall lever
## when the team is ready; in the user's words "şalter iner, siren ve kırmızı ışıklarla beraber
## ikili kapı ortadan yanlara doğru slide ile açılır", and the dead walk out of the pens, through the
## gates and up to the railing, where they claw at it. When the last one is down the gates close and
## the next wave waits on the lever; every wave is bigger, tougher and a little quicker.
##
## Host-authoritative like GameState: the lever is a request (GameState.request_pull_lever), the
## host plans the wave, rolls every zombie and keeps their hit points, and tells everyone through
## GameState.cue_wave. Every peer builds the same zombie under the same path (Waves/Z<id>), so
## shot_landed names it everywhere; each peer walks and animates its own copy from the cue.
## A joiner gets the phase and the living zombies where they stand (join_cues).
##
## Cues (wave_cue): [&"reset"] (a joiner drops what it had alone) · [&"phase", wave, phase, left] · [&"spawn", id, kind, seed, gate, pos, yaw,
## speed, rail_z, walking, cuts] · [&"die", id, left, killer, weak, at, gun, gib] ·
## [&"limb", id, part] (a limb torn off, zombie_body.gd LIMBS).
##
## The railing (2026-10-30, the user's call): its hit points are GameState's (GameState.fence), every
## claw takes a bite (STATS), and at 0 the wave is lost, in co-op too: the dead turn back, the screen
## says so (hud.gd), the railing is patched up a little and the same wave waits again. It is mended
## at the desk (GameState.request_repair_fence), never on its own between waves. scripts/fence.gd
## shows the wear and the sparks. The numbers below are first guesses.
##
## Sounds come from the user (assets/sounds/waves/<slot>.ogg|wav): lever, siren, gate. A missing
## file stays silent.

## On every peer when a zombie goes down: who shot it (peer id), its kind, a head shot or not,
## where it stood (x: how close it got to the railing at 14) and the gun's GameState.GUNS id.
signal zombie_killed(peer: int, kind: StringName, weak: bool, at: Vector3, gun: String)

enum Phase { READY, STARTING, FIGHT, CLEARED, FAILED }

const BODY := preload("res://scripts/zombie_body.gd")
const FENCE := preload("res://scripts/fence.gd")
const VOICE := preload("res://scripts/zombie_voice.gd")
const SOUNDS := "res://assets/sounds/waves/"
const LEVER_TIME := 0.6  # s from the pull to the siren and the lights
const GATES_AT := 1.8  # s after the pull the gates start to slide
const GATE_TIME := 2.5  # s to slide open (or shut)
const FIGHT_AT := GATES_AT + GATE_TIME * 0.6  # the dead may walk once the gap is wide enough
const CLEAR_PAUSE := 4.0  # s from the last kill to the lever coming back up
const FAIL_PAUSE := 6.0  # s from the railing going to the same wave waiting again (hud.gd darkens over it)
const DEAD_STAY := 8.0  # s a body lies before it goes
const RAIL_X := 14.8  # where they stop, just past the railing (x 14)
const RAIL_Z := 18.0  # ± along it
const DOOR_X := 29.5  # just inside the bay's mouth in the hall's east wall
const DOOR_Z := 9.0  # ± (the opening is ±12)
const BAY_HALF := 12.0  # tools/build_arena.gd
const BAY_END := 44.3
const MAX_ALIVE := 40  # on the floor at once, the rest wait their turn (network load stays flat)
const SPAWN_EVERY := 0.5  # s between the waiting ones once the gates are open
## How it comes apart (the host decides, the die cue carries it): a head shot kill takes the head
## off, SHRED rounds inside SHRED_TIME (a burst from the UZI or the minigun) burst the body, a brute
## and a blob always burst (a blob has no head to lose).
const SHRED := 4
const SHRED_TIME := 0.5
## Limbs (Mixamo bodies; zombie_body.gd LIMBS): the host counts paying hits per arm and per leg, and
## at LIMB_HITS ("arm" / "leg", ×LIMB_HITS_BRUTE for a brute, which keeps its legs) tears it off at
## the joint above the last hit. A torn arm slows its swings by ARM_SLOW of a swing each; a torn
## leg drops it to its belly to crawl at LEGLESS of its speed.
const LIMB_HITS := {"arm": 2, "leg": 3}
const LIMB_HITS_BRUTE := 3
const ARM_SLOW := 0.6
const LEGLESS := {&"walker": 0.65, &"runner": 0.45}
## The crowd keeps apart: two closer than SPREAD m (×size; the low ones more) push each other off.
const SPREAD := 0.6
const SPREAD_PUSH := 4.0  # 1/s
const WAYPOINT_SLACK := 0.8  # m: near enough to a gate's mouth on the way (only the railing spot is exact)
## kind -> walk speed (m/s), hit points (a head shot takes 3), bite out of the fence per claw
const STATS := {&"walker": [0.9, 5, 1], &"runner": [3.0, 3, 1], &"crawler": [0.6, 4, 1], &"brute": [1.4, 25, 4],
		&"blob": [0.7, 12, 2], &"dog": [4.5, 2, 1]}
## The ones that keep low, lying along their way: kind -> trunk radius, trunk length, trunk height,
## head radius (m, ×the body's size; the crawler's is the same at every size).
const LOW := {&"crawler": [0.3, 0.9, 0.35, 0.13], &"blob": [0.42, 1.0, 0.4, 0.2], &"dog": [0.2, 0.9, 0.45, 0.13]}
## Wave n: BASE_COUNT + COUNT_GROW·(n-1) zombies; hit points ×(1 + HP_GROW·(n-1)), speed likewise
## up to SPEED_MAX; crawlers from wave CRAWLER_FROM, runners from RUNNER_FROM, blobs from BLOB_FROM,
## a brute every BRUTE_EVERY. From DOG_FROM a pack of dogs comes on top, all together: DOG_PACK
## of them, one more every DOG_PACK_GROW waves, up to DOG_PACK_MAX.
const BASE_COUNT := 8
const COUNT_GROW := 4
const HP_GROW := 0.2
const SPEED_GROW := 0.02
const SPEED_MAX := 1.4
const CRAWLER_FROM := 2
const CRAWLER_SHARE := 0.15
const RUNNER_FROM := 3
const RUNNER_SHARE := 0.2
const BRUTE_EVERY := 5
const BLOB_FROM := 6
const BLOB_SHARE := 0.08
const DOG_FROM := 4
const DOG_PACK := 2
const DOG_PACK_GROW := 2
const DOG_PACK_MAX := 8
const STATUS := {Phase.READY: "HAZIR", Phase.STARTING: "AÇILIYOR", Phase.CLEARED: "TEMİZ", Phase.FAILED: "ÇİT YIKILDI"}

var wave := 1
var phase := Phase.READY
var left := 0  # zombies of this wave not yet down (waiting ones too)
var fence: int:  # the railing's hit points, GameState's
	get: return GameState.fence

var _zombies := {}  # id -> record (see _add_zombie)
var _spawns: Array[Node3D] = []
var _gates: Array[Node3D] = []
var _gate_home := {}  # leaf -> closed position
var _gate_tween: Tween
var _gates_open := false
var _alarms: Array[Node3D] = []
var _spins: Array[Node3D] = []  # turning now
var _spins_paused: Array[Node3D] = []  # the beacons' mirrors while dark
var _lit := false
var _lever: Node3D
var _lever_anim: AnimationPlayer
var _lever_clip := &""
var _number: Label3D
var _status: Label3D
var _shown_wave := -1
var _seq := 0  # bumped by every phase, so a sequence left waiting stops when the next comes
var _fence: Node3D  # scripts/fence.gd: the railing's wear and sparks
# Host only.
var _rng := RandomNumberGenerator.new()
var _queue: Array[StringName] = []
var _hp := {}  # id -> hit points left
var _limb_hits := {}  # id -> {"arm_l": hits, ...}
var _next_id := 1
var _next_spawn := 0
var _spawn_wait := 0.0


## A zombie's body: what the shot code and the HUD ask of a target.
class Zombie extends StaticBody3D:
	var tall := 1.8

	func above_head() -> Vector3:
		return global_position + Vector3.UP * (tall + 0.15)


func _ready() -> void:
	add_to_group("waves")
	_rng.randomize()
	for s: Node3D in get_tree().get_nodes_in_group("wave_spawn"):
		_spawns.append(s)
	for g: Node3D in get_tree().get_nodes_in_group("wave_gate"):
		_gates.append(g)
		_gate_home[g] = g.position
	for a: Node3D in get_tree().get_nodes_in_group("wave_alarm"):
		_alarms.append(a)
		var spin := a.find_child("Spin", true, false)
		if spin:
			_spins_paused.append(spin)
	_lever = get_tree().get_first_node_in_group("wave_lever")
	if _lever:
		_lever_anim = _lever.find_child("AnimationPlayer", true, false)
		if _lever_anim and not _lever_anim.get_animation_list().is_empty():
			_lever_clip = _lever_anim.get_animation_list()[0]
			_lever_anim.play(_lever_clip)  # rest on its first frame: up
			_lever_anim.seek(0.0, true)
			_lever_anim.pause()
		_number = _lever.find_child("Number", true, false)
		_status = _lever.find_child("Status", true, false)
	GameState.wave_cue.connect(_on_cue)
	GameState.lever_pulled.connect(_on_lever)
	GameState.shot_landed.connect(_on_shot)
	GameState.fence_changed.connect(func(_hp: int, _wear: Array) -> void: _sign())
	_fence = FENCE.new()
	add_child(_fence)
	# The host is gone: its timers and hit points went with it, so the wave starts over here.
	multiplayer.server_disconnected.connect(func() -> void: _reset())
	_sign()
	_pen_cries()


## The local player at `at` may pull the lever now (player.gd shows the hint, E pulls it).
func can_pull(at: Vector3) -> bool:
	var to := Vector2(at.x - GameState.LEVER_POS.x, at.z - GameState.LEVER_POS.z)
	return phase == Phase.READY and to.length() <= GameState.STATION_REACH


## Host: what a joiner needs, in order: the phase, then every zombie still standing where it is now.
func join_cues() -> Array:
	var cues := [[&"reset"], [&"phase", wave, phase, left]]
	for id: int in _zombies:
		var z: Dictionary = _zombies[id]
		if not z.dead:
			var node: Node3D = z.node
			cues.append([&"spawn", id, z.kind, z.seed, z.gate, node.global_position, node.global_rotation.y,
					z.speed, z.rail.z, z.moving, z.body.cuts.duplicate()])
	return cues


func _process(delta: float) -> void:
	for s in _spins:
		s.rotate_object_local(Vector3.UP, TAU * 0.8 * delta)
	for z: Dictionary in _zombies.values():
		if not z.dead:
			_walk(z, delta)
	_spread(delta)
	for z: Dictionary in _zombies.values():
		if not z.dead:
			(z.head_shape as Node3D).global_position = (z.head as Node3D).global_position
	if Net.is_client:
		return
	if phase == Phase.FIGHT and not _queue.is_empty():
		_spawn_wait -= delta
		if _spawn_wait <= 0.0 and _alive() < MAX_ALIVE:
			_spawn_wait = SPAWN_EVERY
			_spawn_next()


# --- host -----------------------------------------------------------------------------------------

func _on_lever(_peer: int) -> void:
	if phase != Phase.READY or Net.is_client:
		return
	_queue = _plan(wave)
	_hp.clear()
	_limb_hits.clear()
	_next_spawn = 0
	GameState.cue_wave([&"phase", wave, Phase.STARTING, _queue.size()])
	for i in mini(_spawns.size(), _queue.size()):  # a pen-full waits behind the gates
		_spawn_next()
	var seq := _seq
	await get_tree().create_timer(FIGHT_AT).timeout
	if seq == _seq:
		GameState.cue_wave([&"phase", wave, Phase.FIGHT, left])
		_check_clear()  # shot down in the pens before the gates were wide enough


## What wave `w` sends, in order.
func _plan(w: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for i in BASE_COUNT + COUNT_GROW * (w - 1):
		var r := _rng.randf()
		if w >= RUNNER_FROM and r < RUNNER_SHARE:
			out.append(&"runner")
		elif w >= CRAWLER_FROM and r < RUNNER_SHARE + CRAWLER_SHARE:
			out.append(&"crawler")
		elif w >= BLOB_FROM and r < RUNNER_SHARE + CRAWLER_SHARE + BLOB_SHARE:
			out.append(&"blob")
		else:
			out.append(&"walker")
	for i in w / BRUTE_EVERY:  # not first out of the gate
		out.insert(_rng.randi_range(out.size() / 3, out.size()), &"brute")
	if w >= DOG_FROM:  # a while in, so they come at a railing that is already busy
		var at := _rng.randi_range(out.size() / 4, out.size())
		for i in mini(DOG_PACK + (w - DOG_FROM) / DOG_PACK_GROW, DOG_PACK_MAX):
			out.insert(at, &"dog")
	return out


func _spawn_next() -> void:
	var kind: StringName = _queue.pop_front()
	var at: Node3D = _spawns[_next_spawn % _spawns.size()]
	var pos := at.global_position
	if _next_spawn >= _spawns.size():  # a marker used before: not quite on the same spot
		pos += Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4))
	_next_spawn += 1
	var id := _next_id
	_next_id += 1
	var st: Array = STATS[kind]
	var grow := float(wave - 1)
	_hp[id] = ceili(st[1] * (1.0 + HP_GROW * grow))
	var speed: float = st[0] * minf(1.0 + SPEED_GROW * grow, SPEED_MAX)
	GameState.cue_wave([&"spawn", id, kind, _rng.randi(), at.get_meta("gate"), pos, at.global_rotation.y,
			speed, _rng.randf_range(-RAIL_Z, RAIL_Z), phase == Phase.FIGHT])


func _alive() -> int:
	var n := 0
	for z: Dictionary in _zombies.values():
		if not z.dead:
			n += 1
	return n


## Host: a claw landed on the railing. Down to nothing, the wave is lost: the dead turn back and,
## once the screen has said so, the railing is patched up and the same wave waits again.
func _bite(z: Dictionary) -> void:
	if phase != Phase.FIGHT:
		return
	GameState.hurt_fence(STATS[z.kind][2], z.rail.z)
	if GameState.fence > 0:
		return
	GameState.cue_wave([&"phase", wave, Phase.FAILED, left])
	var seq := _seq
	await get_tree().create_timer(FAIL_PAUSE).timeout
	if seq == _seq:
		GameState.mend_fence(GameState.FENCE_PATCH)
		GameState.cue_wave([&"phase", wave, Phase.READY, 0])


func _check_clear() -> void:
	if phase != Phase.FIGHT or not _queue.is_empty() or _alive() > 0:
		return
	GameState.cue_wave([&"phase", wave, Phase.CLEARED, 0])
	var seq := _seq
	await get_tree().create_timer(CLEAR_PAUSE).timeout
	if seq == _seq:
		GameState.cue_wave([&"phase", wave + 1, Phase.READY, 0])


# --- every peer -----------------------------------------------------------------------------------

func _on_cue(cue: Array) -> void:
	match cue[0]:
		&"reset":
			_reset()
		&"phase":
			_set_phase(cue[1], cue[2], cue[3])
		&"spawn":
			_add_zombie(cue[1], cue[2], cue[3], cue[4], cue[5], cue[6], cue[7], cue[8], cue[9],
					cue[10] if cue.size() > 10 else [])
		&"limb":
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty():
				_cut(z, cue[2], true)
		&"die":
			left = cue[2]
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty() and not z.dead:
				zombie_killed.emit(cue[3], z.kind, cue[4], cue[5], cue[6])
			_kill(cue[1], cue[7] if cue.size() > 7 else &"")
			_sign()
			if not Net.is_client:
				_check_clear()


func _set_phase(w: int, ph: Phase, p_left: int) -> void:
	var was := phase
	wave = w
	phase = ph
	left = p_left
	_seq += 1
	_sign()
	match ph:
		Phase.STARTING:
			_sequence(_seq)
		Phase.FIGHT:
			var skipped := was != Phase.STARTING  # joined mid-wave: no show, it is already so
			if skipped:
				_set_lever(true, true)
			_light(true)
			if not _gates_open:
				_open_gates(skipped)
			for z: Dictionary in _zombies.values():
				if not z.released:
					_release(z, true)
		Phase.CLEARED:
			if was == Phase.READY:  # joined in the pause: as it stands on the host
				_set_lever(true, true)
			_light(false)
			_close_gates(was == Phase.READY)
		Phase.FAILED:
			if was == Phase.READY:
				_set_lever(true, true)
				_open_gates(true)
			for z: Dictionary in _zombies.values():  # the railing is down: they turn back for the pens
				if not z.dead:
					_retreat(z)
			_light(false)
		Phase.READY:
			_set_lever(false, was == Phase.READY)
			_light(false)
			if _gates_open:
				_close_gates(was == Phase.READY)
			for id: int in _zombies.keys():  # the ones a lost wave left standing
				if not _zombies[id].dead:
					_zombies[id].node.queue_free()
					_zombies.erase(id)


## Back to a quiet bay with the lever up, keeping the wave number: a joiner before the host's
## world comes in, or everyone left behind when the host goes.
func _reset() -> void:
	_seq += 1
	for z: Dictionary in _zombies.values():
		if is_instance_valid(z.node):
			z.node.queue_free()
	_zombies.clear()
	_queue.clear()
	_hp.clear()
	phase = Phase.READY
	left = 0
	_set_lever(false, true)
	_light(false)
	_close_gates(true)
	_sign()


## The pull, the siren and the lights, the gates.
func _sequence(seq: int) -> void:
	_set_lever(true, false)
	_sound(&"lever", _lever)
	await get_tree().create_timer(LEVER_TIME).timeout
	if seq != _seq:
		return
	_light(true)
	for a in _alarms:
		if a.get_meta("kind", "") == "beacon":
			_sound(&"siren", a)
	await get_tree().create_timer(GATES_AT - LEVER_TIME).timeout
	if seq == _seq:
		_open_gates(false)


func _set_lever(down: bool, instant: bool) -> void:
	if not _lever_anim or _lever_clip == &"":
		return
	if instant:
		_lever_anim.play(_lever_clip)
		_lever_anim.seek(_lever_anim.current_animation_length if down else 0.0, true)
		_lever_anim.pause()
	elif down:
		_lever_anim.play(_lever_clip)
	else:
		_lever_anim.play_backwards(_lever_clip)


func _light(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	for a in _alarms:
		for n in a.find_children("*", "", true, false) + [a]:
			if n is Light3D:
				n.visible = on
			if n is GeometryInstance3D and n.has_meta("lit_material"):
				if not n.has_meta("dark_material"):
					n.set_meta("dark_material", n.material_override)
				n.material_override = n.get_meta("lit_material" if on else "dark_material")
	if not on:  # the mirrors stop where they are
		_spins_paused = _spins.duplicate()
		_spins.clear()
	elif not _spins_paused.is_empty():
		_spins = _spins_paused.duplicate()
		_spins_paused.clear()


func _open_gates(instant: bool) -> void:
	_gates_open = true
	_slide(true, instant)


func _close_gates(instant: bool) -> void:
	_gates_open = false
	_slide(false, instant)


func _slide(open: bool, instant: bool) -> void:
	if _gate_tween:
		_gate_tween.kill()
	if instant:
		for g in _gates:
			g.position = _gate_home[g] + (g.get_meta("open_offset") if open else Vector3.ZERO)
		return
	_gate_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	for g in _gates:
		_gate_tween.tween_property(g, "position", _gate_home[g] + (g.get_meta("open_offset") if open else Vector3.ZERO), GATE_TIME)
		_sound(&"gate", g)


func _add_zombie(id: int, kind: StringName, seed: int, gate: String, pos: Vector3, yaw: float, speed: float, rail_z: float, walking: bool, cuts: Array = []) -> void:
	if _zombies.has(id):
		return
	var node := Zombie.new()
	node.name = "Z%d" % id
	node.add_to_group("target")
	node.add_to_group("flesh")  # impacts.gd leaves the wound to zombie_body.gd
	node.set_meta("zombie", id)
	add_child(node)
	node.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	var body: Node3D = BODY.new()
	body.setup(kind, seed)
	node.add_child(body)
	var tall: float = body.height
	var low: Array = LOW.get(kind, [])
	var k: float = 1.0 if kind == &"crawler" else body.size
	node.tall = 0.9 if kind == &"crawler" else tall
	var trunk := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = low[0] * k if low else 0.3 * tall / 1.8
	cap.height = low[1] * k if low else tall - 0.25
	trunk.shape = cap
	if low:
		trunk.rotation.x = PI / 2
		trunk.position = Vector3(0, low[2] * k, 0)
	else:
		trunk.position = Vector3(0, cap.height / 2.0, 0)
	node.add_child(trunk)
	var head := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = low[3] * k if low else 0.13 * tall / 1.8
	head.shape = ball
	head.add_to_group("weak_spot")
	node.add_child(head)
	var mouth := Vector3.ZERO
	for g in _gates:
		if g.get_meta("gate") == gate:
			mouth = g.get_meta("mouth")
	var z := {"id": id, "node": node, "body": body, "kind": kind, "seed": seed, "gate": gate,
			"mouth": mouth, "rail": Vector3(RAIL_X, 0.0, rail_z), "head": body.attach("Head"),
			"head_shape": head, "trunk": trunk, "speed": speed, "dead": false, "path": [],
			"stagger": 0.0, "down": 0.0, "released": false, "moving": false, "hits": []}
	_zombies[id] = z
	_next_id = maxi(_next_id, id + 1)  # should this machine ever be the one handing them out
	body.idle()
	for part: StringName in cuts:  # a joiner: what was torn off before it came, already off
		_cut(z, part, false)
	if phase == Phase.FIGHT:  # one still waiting to set off on the host waits a little here too
		_release(z, not walking)


## Sets it walking from where it stands: the gate's mouth (if still in the pen), the bay's mouth,
## its spot on the railing. Out of a gate that has just opened, they don't all set off at once.
func _release(z: Dictionary, stagger: bool) -> void:
	z.released = true
	var at: Vector3 = (z.node as Node3D).global_position
	var path := []
	if absf(at.z) > BAY_HALF - 0.5 or at.x > BAY_END:
		path.append(z.mouth)
	if at.x > DOOR_X:
		path.append(Vector3(DOOR_X, 0.0, clampf(z.rail.z, -DOOR_Z, DOOR_Z)))
	path.append(z.rail)
	var r := absi(hash(z.seed))
	if stagger:
		await get_tree().create_timer(float(r % 400) / 100.0).timeout
		if z.dead or not is_instance_valid(z.node) or phase != Phase.FIGHT:
			return
	if (z.kind == &"brute" and r % 7 < 3) or (z.kind == &"dog" and r % 4 == 0):  # a roar, a howl
		await get_tree().create_timer(z.body.scream()).timeout
		if z.dead or not is_instance_valid(z.node) or phase != Phase.FIGHT:
			return
	z.path = path
	z.moving = true
	z.body.move(z.speed)


func _walk(z: Dictionary, delta: float) -> void:
	var falling: bool = z.down > 0.0  # going down on a torn leg: stumbles on a little, then crawls
	z.down = maxf(0.0, z.down - delta)
	if z.path.is_empty():
		return
	var node: StaticBody3D = z.node
	var to: Vector3 = z.path[0] - node.global_position
	to.y = 0.0
	if falling:
		node.global_position += to.limit_length(z.body.fall_speed * delta)
		if z.down <= 0.0:
			z.body.move(z.speed)
		return
	z.stagger = maxf(0.0, z.stagger - delta)
	var step: float = z.speed * delta * (0.2 if z.stagger > 0.0 else 1.0)
	var last: bool = z.path.size() == 1
	if to.length() <= (step if last else maxf(step, WAYPOINT_SLACK)):  # a crowd at a gate can't all stand on its spot
		if last:
			node.global_position += to
		z.path.pop_front()
		if z.path.is_empty():
			node.look_at(node.global_position + Vector3.LEFT, Vector3.UP)
			z.body.idle()  # what it stands in between swings
			_claw(z)
		return
	node.global_position += to.normalized() * step
	node.global_transform = node.global_transform.interpolate_with(
			node.global_transform.looking_at(node.global_position + to, Vector3.UP), minf(1.0, 6.0 * delta))


func _claw(z: Dictionary) -> void:
	while not z.dead and is_instance_valid(z.node) and phase == Phase.FIGHT:
		if z.down > 0.0:  # a leg torn off at the railing: down first, then it bites from there
			await get_tree().process_frame
			continue
		var t: float = z.body.attack()
		await get_tree().create_timer(t * 0.5).timeout
		if z.dead or phase != Phase.FIGHT:
			return
		_fence.struck(z.node.global_position.z, z.kind)  # every peer: the sparks, the clang
		if not Net.is_client:
			_bite(z)
		await get_tree().create_timer(t * (0.5 + ARM_SLOW * z.body.arms_hurt()) + 0.4).timeout


func _on_shot(peer: int, at: Vector3, _n: Vector3, dir: Vector3, target: Node, _gold: int, weak: bool, combo: int) -> void:
	if target == null or not target.has_meta("zombie"):
		return
	var z: Dictionary = _zombies.get(target.get_meta("zombie"), {})
	if z.is_empty() or z.dead:
		return
	var part: StringName = z.body.wound(at, dir, weak)
	z.stagger = 0.7 if BODY.is_leg(part) else 0.35  # held back a moment by the hit, a leg longer
	z.body.hit()
	if Net.is_client or combo == 0 or not _hp.has(z.id):  # combo 0: not a paying hit (wrong side of the line)
		return
	if part != &"":
		_limb_hit(z, part)
	_hp[z.id] -= 3 if weak else 1
	var now := Time.get_ticks_msec() / 1000.0
	z.hits = (z.hits as Array).filter(func(t: float) -> bool: return now - t < SHRED_TIME) + [now]
	if _hp[z.id] <= 0:
		_hp.erase(z.id)
		var gun: String = GameState.GUNS[GameState.player(peer).gun].id
		var gib := &""
		if weak and z.kind != &"blob":
			gib = &"head"
		elif z.kind in [&"brute", &"blob"] or (z.hits as Array).size() >= SHRED:
			gib = &"body"
		GameState.cue_wave([&"die", z.id, _queue.size() + _alive() - 1, peer, weak,
				(z.node as Node3D).global_position, gun, gib])


## Host: a paying hit on `part`; enough of them on that arm or leg and it goes, at the joint above
## where this one went in.
func _limb_hit(z: Dictionary, part: StringName) -> void:
	var limb := ("leg" if BODY.is_leg(part) else "arm") + String(part).right(2)
	var hits: Dictionary = _limb_hits.get_or_add(z.id, {})
	hits[limb] = hits.get(limb, 0) + 1
	var need: int = LIMB_HITS[limb.left(3)] * (LIMB_HITS_BRUTE if z.kind == &"brute" else 1)
	if hits[limb] >= need:
		hits[limb] = 0  # what is left of it (an arm that lost the forearm) can go too
		GameState.cue_wave([&"limb", z.id, part])


## Every peer, the wave lost: off back the way it came, to the bay's mouth and its gate.
func _retreat(z: Dictionary) -> void:
	z.released = true
	var at: Vector3 = (z.node as Node3D).global_position
	var path := []
	if at.x < DOOR_X:
		path.append(Vector3(DOOR_X, 0.0, clampf(at.z, -DOOR_Z, DOOR_Z)))
	path.append(z.mouth)
	z.path = path
	z.moving = true
	if z.down <= 0.0:
		z.body.move(z.speed)


## Every peer: `part` comes off (zombie_body.gd cut()). A leg lost drops a standing one to its belly:
## it waits out the fall, then crawls on slower and lies low for the rounds.
func _cut(z: Dictionary, part: StringName, fly: bool) -> void:
	var was_low: bool = z.body.crawling
	z.down = maxf(z.down, z.body.cut(part, fly))
	if was_low or not z.body.crawling:
		return
	z.speed *= LEGLESS.get(z.kind, 0.6)
	(z.node as Zombie).tall = 0.9
	var trunk: CollisionShape3D = z.trunk
	var low: Array = LOW[&"crawler"]
	var cap := trunk.shape as CapsuleShape3D
	cap.radius = low[0]
	cap.height = low[1]
	trunk.rotation.x = PI / 2
	trunk.position = Vector3(0, low[2], 0)
	if z.down <= 0.0 and not z.path.is_empty():
		z.body.move(z.speed)


## Keeps the crowd from walking into each other: every pair of the living standing too close is
## pushed apart along the floor, those already at the railing only along it. Each peer its own.
func _spread(delta: float) -> void:
	var live: Array[Dictionary] = []
	var reach: Array[float] = []
	for z: Dictionary in _zombies.values():
		if not z.dead and z.released:
			live.append(z)
			reach.append(SPREAD * (1.5 if z.body.crawling or LOW.has(z.kind) else 1.0) * z.body.size)
	var k := minf(1.0, SPREAD_PUSH * delta)
	for i in live.size():
		var a: Node3D = live[i].node
		for j in range(i + 1, live.size()):
			var off := a.global_position - (live[j].node as Node3D).global_position
			off.y = 0.0
			var r := (reach[i] + reach[j]) * 0.5
			var d := off.length()
			if d >= r:
				continue
			var push := (off / d if d > 0.001 else Vector3(0, 0, 1)) * (r - d) * 0.5 * k
			_nudge(live[i], push)
			_nudge(live[j], -push)


func _nudge(z: Dictionary, by: Vector3) -> void:
	if z.path.is_empty():  # clawing at the railing: slides along it, never through
		by = Vector3(0.0, 0.0, by.z)
	(z.node as Node3D).global_position += by


func _kill(id: int, gib: StringName) -> void:
	var z: Dictionary = _zombies.get(id, {})
	if z.is_empty() or z.dead:
		return
	z.dead = true
	z.path = []
	var node: Node3D = z.node
	node.remove_from_group("target")
	(z.trunk as CollisionShape3D).disabled = true
	(z.head_shape as CollisionShape3D).disabled = true
	z.body.die(gib)
	await get_tree().create_timer(DEAD_STAY).timeout
	if is_instance_valid(node):
		node.queue_free()
	if is_same(_zombies.get(id), z):
		_zombies.erase(id)


## While the gates are shut, now and then one of them screams somewhere behind them (each machine
## its own, only a sound).
func _pen_cries() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
		if not _gates_open and not _spawns.is_empty():
			VOICE.distant(_spawns.pick_random().global_position + Vector3.UP * 1.5)


## The mechanical sign over the lever: the wave's number on flip plates, the state under it.
func _sign() -> void:
	if _status:
		var text: String = STATUS.get(phase, "")
		if phase == Phase.FIGHT:
			text = "KALAN %d   ÇİT %d" % [left, GameState.fence]
		_status.text = text
	if _number and wave != _shown_wave:
		var first := _shown_wave < 0
		_shown_wave = wave
		if first:
			_number.text = "%02d" % wave
			return
		var tw := create_tween()  # the plate flips over to the new number
		tw.tween_property(_number, "scale:y", 0.0, 0.12)
		tw.tween_callback(func() -> void: _number.text = "%02d" % wave)
		tw.tween_property(_number, "scale:y", 1.0, 0.12)


func _sound(slot: StringName, at: Node3D) -> void:
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(SOUNDS + String(slot) + ext):
			stream = load(SOUNDS + String(slot) + ext)
	if stream == null or at == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	at.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
