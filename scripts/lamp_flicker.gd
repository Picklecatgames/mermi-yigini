extends Node
## When a head lamp flickers (scripts/head_lamp.gd plays it), the host's call; under GameState.
## 2026-11-06, the coordinator's brief: at night, a dead one close by that the player doesn't see
## (behind, beside, behind a tree) and now and then their lamp flickers; seldom and short, "to taste",
## never the same player twice running, so many a night and none per player at most, and now and then
## with nothing there at all, so a flicker isn't always "one's here". Every number below is mine
## (docs/ayrintilar.md "Kafa lambası titremesi").
##
## For the tension director to come: GameState.try_lamp_flicker(peer) asks for one now, under the
## same limits (it says whether it went), and `auto = false` stops this script's own rolls.

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
	if GameState.night_of(GameState.hour) < 1.0:
		return
	roll(func(peer: int) -> bool: return unseen_near(peer))


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
