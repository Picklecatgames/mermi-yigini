extends Node
## When a flashlight flickers or dies (scripts/head_lamp.gd plays it), the host's call; under GameState.
## 2026-11-06, the coordinator's brief: at night, a dead one close by that the player doesn't see
## (behind, beside, behind a tree) and now and then their lamp flickers; seldom and short, "to taste",
## never the same player twice running, so many a night and none per player at most, and now and then
## with nothing there at all, so a flicker isn't always "one's here". Every number below is mine
## (docs/ayrintilar.md "Kafa lambası titremesi").
##
## For the tension director to come: GameState.try_lamp_flicker(peer) asks for one now, under the
## same limits (it says whether it went), and `auto = false` stops this script's own rolls.
## Only a flashlight in hand flickers (GameState PlayerState.torch, F).
##
## The blackout (2026-11-06, the user: "fenere bir sinsilik ekle, nadiren titreyip kapansın, bu olay
## sadece ormandayken yaşansın, kapandığında bir yaratığın yanında belirme ihtimali olsun, böylece
## bir korku sekansı olacak"): in the wood (forest_presence.gd out_of_clearing past WOOD_IN m) after
## dark, seldom, a player's flashlight stutters and dies for a few seconds (head_lamp.gd
## blackout_steps), every machine seeing it die. Sometimes (CREATURE_CHANCE) something is put up in
## the dark right in front of them (CREATURE_AT m, where the beam will land, or beside if a tree is
## there), facing them, and the light comes back on it; then it comes for them like any of the dead.
## try_blackout(peer) for the director too.

const CHECK := 1.0  # s between rolls
const NEAR_FROM := 6.0  # m, flat: a dead one this close and no closer (closer, it is a fight)...
const NEAR_TO := 15.0  # ...or further
const SEEN_COS := 0.55  # ...out of the view: more than ~57 deg off where the player looks
const CHEST := 1.2  # m over its feet: where the line of sight goes to
const EYE_SLACK := 0.7  # m short of the eye: our own body (or a remote one) doesn't hide it
const CHANCE_NEAR := 0.06  # a roll, while one is close and unseen: ~17 s on average
const CHANCE_EMPTY := 0.001  # a roll, with nothing there: once in ~17 min of night
const PLAYER_GAP := 150.0  # s from one player's flicker to their next
const ANY_GAP := 40.0  # s from anyone's flicker to the next
const PLAYER_NIGHT := 2  # a player's at most, a night
const ALL_NIGHT := 5  # everyone's at most, a night
const WOOD_IN := 3.0  # m into the wood past the clearing's edge (forest_presence.gd out_of_clearing)
const CHANCE_BLACKOUT := 1.0 / 150.0  # a roll, in the wood with the flashlight on after dark: ~2.5 min
const BLACKOUT_GAP := 300.0  # s from one player's blackout to their next
const BLACKOUT_NIGHT := 2  # a player's at most, a night
const CREATURE_CHANCE := 0.5
const CREATURE_AT := 3.2  # m in front of the player: seen before it reaches them
const CREATURE_TYPE := &"walker"  # waves.gd TYPES: slow, so the scare is the sight of it, not a death
const CREATURE_DARK := 0.8  # of the way through the dark it is put up: it has not come far when the light is back
const FOREST := preload("res://scripts/forest_presence.gd")
const LAMP := preload("res://scripts/head_lamp.gd")

var auto := true  # this script's own rolls; the tension director may take them over
var now := 0.0  # s, game time
var _wait := CHECK
var _night := -1  # GameState.nights the counts are of
var _last_at := {}  # peer -> now of their last flicker
var _count := {}  # peer -> this night's
var _all := 0  # this night's
var _any_at := -INF
var _last_peer := 0
var _rng := RandomNumberGenerator.new()
var history: Array = []  # [now, peer, near], every flicker that went (tools/lamp_flicker_check.gd)
var blackouts: Array = []  # [now, peer, creature], every blackout that went (tools/torch_check.gd)
var _dark_until := {}  # peer -> now their blackout ends: no flicker over it
var _black_at := {}  # peer -> now of their last blackout
var _black_count := {}  # peer -> this night's blackouts
var _black_night := -1


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	now += delta
	if Net.is_client or not auto:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = CHECK
	var lit := GameState.everyone().filter(func(peer: int) -> bool: return GameState.player(peer).torch)
	if lit.is_empty() or GameState.night_of(GameState.hour) < 0.5:
		return
	for peer: int in lit:
		if in_wood(peer) and _rng.randf() < CHANCE_BLACKOUT and try_blackout(peer):
			return
	if GameState.night_of(GameState.hour) >= 1.0:
		roll(func(peer: int) -> bool: return unseen_near(peer), lit)


## One roll for everyone (`peers`, else the session's); `near.call(peer)`: a dead one close and unseen.
func roll(near: Callable, peers: Array = []) -> void:
	if peers.is_empty():
		peers = GameState.everyone()
	for peer: int in peers:
		if GameState.is_down(peer):
			continue
		var close: bool = near.call(peer)
		if _rng.randf() < (CHANCE_NEAR if close else CHANCE_EMPTY) and try_flicker(peer, close, peers.size()):
			return  # one a roll


## Host: `peer`'s lamp flickers now if the limits allow (`crowd`: how many play, else the session's);
## whether it did.
func try_flicker(peer: int, near := true, crowd := -1) -> bool:
	if Net.is_client or not allowed(peer, GameState.everyone().size() if crowd < 0 else crowd):
		return false
	_last_at[peer] = now
	_count[peer] = _count.get(peer, 0) + 1
	_all += 1
	_any_at = now
	_last_peer = peer
	history.append([now, peer, near])
	GameState._world(&"lamp_flicker", [peer, _rng.randi()])
	return true


## Whether `peer`'s lamp may flicker now.
func allowed(peer: int, crowd: int) -> bool:
	if now < _dark_until.get(peer, -INF):
		return false  # it is dead just now
	if GameState.nights != _night:
		_night = GameState.nights
		_count.clear()
		_all = 0
	if _all >= ALL_NIGHT or _count.get(peer, 0) >= PLAYER_NIGHT:
		return false
	if now - _any_at < ANY_GAP or now - _last_at.get(peer, -INF) < PLAYER_GAP:
		return false
	return peer != _last_peer or crowd < 2


## A dead one NEAR_FROM..NEAR_TO m from `peer` that they don't see: out of their view, or something
## (a tree, a wall) between its chest and their eyes.
func unseen_near(peer: int) -> bool:
	var p = GameState.player(peer)
	if not p.has_pose:
		return false
	var look := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))  # player.gd
	var eye: Vector3 = p.pos + Vector3.UP * (GameState.CROUCH_EYE if p.crouch else GameState.EYE)
	var space: PhysicsDirectSpaceState3D = null
	for z: Node in get_tree().get_nodes_in_group("target"):
		if not z.has_meta(&"zombie") or not z is Node3D:
			continue
		var to: Vector3 = (z as Node3D).global_position - p.pos
		to.y = 0.0
		var d := to.length()
		if d < NEAR_FROM or d > NEAR_TO:
			continue
		if look.dot(to / d) < SEEN_COS:
			return true
		if space == null:
			space = get_viewport().world_3d.direct_space_state
		var chest: Vector3 = (z as Node3D).global_position + Vector3.UP * CHEST
		var ray := PhysicsRayQueryParameters3D.create(chest, eye + (chest - eye).normalized() * EYE_SLACK, 1)
		if z is CollisionObject3D:
			ray.exclude = [(z as CollisionObject3D).get_rid()]
		if not space.intersect_ray(ray).is_empty():
			return true
	return false


## Whether `peer` stands in the wood, WOOD_IN m or more past the clearing's edge.
func in_wood(peer: int) -> bool:
	var p = GameState.player(peer)
	return p.has_pose and FOREST.out_of_clearing(p.pos) >= WOOD_IN


## Host: `peer`'s flashlight dies now if the limits allow (in hand, BLACKOUT_GAP, BLACKOUT_NIGHT);
## `creature`: 1 something waits when it comes back, 0 nothing, -1 the dice (CREATURE_CHANCE).
## Whether it did. Where it stands is not checked here: in_wood is the rolls' own.
func try_blackout(peer: int, creature := -1) -> bool:
	if Net.is_client or not GameState.player(peer).torch or GameState.is_down(peer):
		return false
	if GameState.nights != _black_night:
		_black_night = GameState.nights
		_black_count.clear()
	if _black_count.get(peer, 0) >= BLACKOUT_NIGHT or now - _black_at.get(peer, -INF) < BLACKOUT_GAP or now < _dark_until.get(peer, -INF):
		return false
	var seed := _rng.randi()
	var with := _rng.randf() < CREATURE_CHANCE if creature < 0 else creature == 1
	var steps := LAMP.blackout_steps(seed)
	var dark := LAMP.dark_span(steps)
	_black_at[peer] = now
	_black_count[peer] = _black_count.get(peer, 0) + 1
	_dark_until[peer] = now + LAMP.flicker_length(steps)
	blackouts.append([now, peer, with])
	GameState._world(&"torch_blackout", [peer, seed, with])
	if with:
		get_tree().create_timer(dark.x + dark.y * CREATURE_DARK, false).timeout.connect(_creature.bind(peer))
	return true


## Host: the thing in the dark, in front of `peer` where the beam will land, facing them.
func _creature(peer: int) -> void:
	var waves := get_tree().get_first_node_in_group("waves")
	var p = GameState.player(peer)
	if waves == null or not waves.has_method(&"_summon") or not p.has_pose or GameState.is_down(peer):
		return
	var at := creature_spot(p.pos, p.yaw)
	var to: Vector3 = p.pos - at
	waves.call(&"_summon", CREATURE_TYPE, at, atan2(-to.x, -to.z), maxi(waves.wave, 1))


## Where it stands: CREATURE_AT m ahead of `feet` looking along `yaw`, or as near that as a free
## line from the eyes allows (a tree in the way: a little to the side), on the ground.
func creature_spot(feet: Vector3, yaw: float) -> Vector3:
	var space := get_viewport().world_3d.direct_space_state
	var eye := feet + Vector3.UP * GameState.EYE
	var best := Vector3.INF
	for turn: float in [0.0, 0.35, -0.35, 0.7, -0.7]:
		var look := Vector3(-sin(yaw + turn), 0.0, -cos(yaw + turn))
		var want := feet + look * CREATURE_AT
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, want + Vector3.UP * CHEST, 1))
		if hit.is_empty():
			best = want
			break
	if best == Vector3.INF:
		best = feet + Vector3(-sin(yaw), 0.0, -cos(yaw)) * CREATURE_AT
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(best + Vector3.UP * 2.2, best + Vector3.DOWN * 6.0, 1))
	if not ground.is_empty():
		best.y = ground.position.y
	return best
