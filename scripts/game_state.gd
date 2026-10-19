extends Node
## All game state lives here. Player actions are request_* commands:
## solo they run directly, in co-op they will be routed to the host.
## The world (pile, loose bullets) is shared; each player has their own hands, gun, gold and
## upgrades, kept per peer id. `peer` 0 in a request means the local player.

signal pile_changed(count: int)
## Local player only; other players' state reaches their own machines over the network.
signal carried_changed(count: int)
## Where bullets left the pile, so the heap can dig there (hands, robots, belts).
signal bullets_taken(at: Vector3, count: int)
## Carried bullets thrown back out; they land as loose spill and count as pile again.
## They get ids first_id .. first_id + count - 1.
signal bullets_thrown(from: Vector3, dir: Vector3, count: int, first_id: int)
## A loose bullet (spilled or thrown) was picked up, by id; every peer removes the same one.
signal loose_taken(id: int)
signal upgraded(id: String, level: int)  # local player
signal loaded_changed(count: int)        # local player
## A round left someone's gun: every peer plays the flash, shell and sound locally from this,
## first person for its own shots, in the world for everyone else's.
signal fired(peer: int, from: Vector3, dir: Vector3)
## Where that round landed. `target` is what it hit (null for a miss into the sky), `gold` what
## the shooter earned for it, `weak` whether it struck a weak spot (a dummy's head), `combo`
## the shooter's chain after it (0 when it didn't hit a dummy).
## Dummies react and pay out from this; impacts are drawn from it.
signal shot_landed(peer: int, at: Vector3, normal: Vector3, dir: Vector3, target: Node, gold: int, weak: bool, combo: int)
signal gold_changed(gold: int)  # local player
## Local player went into or out of placement mode (may cross the firing line).
signal placing_changed(on: bool)
## Crate keys buried in the heap (scripts/key_cache.gd). Digging reached one: it pops out at `at`.
signal key_revealed(rank: int, at: Vector3)
## Someone picked a key up; every peer removes it from the heap.
signal key_taken(rank: int, peer: int)

const PILE_START := 100_000_000
const MAX_PLAYERS := 4
## Loose bullet ids: the baked spill is 0 .. its size - 1, thrown bullets count up from here.
const THROWN_ID_START := 1 << 20

## Upgrade tree: value per level (level 0 = start) and gold cost to reach each next level.
## The pistol's only upgrade is capacity: rounds carried and rounds in the gun, up to the
## heavy pistol's 7-round magazine. First level in ~20 s of play, the last ~10 min in.
# ponytail: placeholder numbers until the 60-minute balance pass.
const UPGRADES := {
	"capacity": {"values": [1, 2, 3, 4, 5, 6, 7], "costs": [8, 20, 45, 90, 160, 280]},
}
## Fixed, not an upgrade: the slide has finished its cycle and the recoil spring has settled.
const FIRE_INTERVAL := 0.42  # s, ~143 rounds/min
## A weak spot pays this many times over: a collision shape in group "weak_spot" (the dummy's
## head), or where the target's `is_weak(at)` says so (a popper's round head).
const WEAK_MULT := 2
## Combo: each paying hit within this long of the last one adds 1 to the chain (shown as xN, it
## can climb to x100 with a fast gun). A gap this long or a miss starts it over. The chain pays
## at most 1 + the number of different target kinds hit in it, so variety is what lifts the
## multiplier: a dummy alone tops out at x2, dummy + gong + popper at x4 (docs/oyun_kritigi).
const COMBO_WINDOW := 1.5  # s
const SHOT_RANGE := 300.0  # m
const SHOT_MASK := 1  # world layer: walls, floor, heap, dummies
## The firing line: a railing across the shed at this x, with every target past it. Players
## only cross it in placement mode, and rounds fired from past it pay nothing and build no combo,
## so walking up to a target to shoot it point blank gets you nothing.
const FIRING_LINE_X := 14.0
## Physics layer of the railing: it stops players (mask), never rounds (SHOT_MASK).
const FENCE_LAYER := 4


class PlayerState:
	var carried := 0
	var loaded := 0  # rounds in the gun
	var gold := 0
	var levels := {"capacity": 0}
	var cooldown := 0.0  # s; game time, so it follows Engine.time_scale like the gun does
	var combo := 0  # paying hits in the current chain
	var combo_kinds := {}  # target kinds hit in the current chain
	var saved_loaded := -1  # rounds in the gun before test mode (T) filled it
	var keys: Array[int] = []  # crate key ranks held (1 = most common)
	var combo_left := 0.0  # s until the chain breaks; game time
	var placing := false  # placement mode: may cross the firing line


var pile: int = PILE_START
var _players := {}  # peer id -> PlayerState
var _next_loose_id := THROWN_ID_START
# ponytail: grows by one per loose grab; the save system can prune ids no longer in the world.
var _taken_loose := {}

# The local player's view, for HUD and first-person code.
var carried: int:
	get: return player().carried
var loaded: int:
	get: return player().loaded
var gold: int:
	get: return player().gold
var carry_capacity: int:
	get: return carry_capacity_of(0)
var mag_capacity: int:
	get: return mag_capacity_of(0)
## Seconds between shots.
var fire_interval: float:
	get: return FIRE_INTERVAL


## Offline this is 1, the same id the host has in co-op.
func local_peer() -> int:
	return multiplayer.get_unique_id()


func player(peer := 0) -> PlayerState:
	if peer == 0:
		peer = local_peer()
	if not _players.has(peer):
		_players[peer] = PlayerState.new()
	return _players[peer]


func _is_local(peer: int) -> bool:
	return peer == 0 or peer == local_peer()


func upgrade_value(id: String, peer := 0) -> int:
	return UPGRADES[id].values[player(peer).levels[id]] if UPGRADES.has(id) else 0


func carry_capacity_of(peer: int) -> int:
	return upgrade_value("capacity", peer)


func mag_capacity_of(peer: int) -> int:
	return upgrade_value("capacity", peer)


func _process(delta: float) -> void:
	for p: PlayerState in _players.values():
		p.cooldown = maxf(p.cooldown - delta, 0.0)
		p.combo_left = maxf(p.combo_left - delta, 0.0)
		if p.combo_left == 0.0 and p.combo > 0:
			_break_chain(p)


## Buys the next level of an upgrade if there is one and gold covers it.
func request_buy_upgrade(id: String, peer := 0) -> bool:
	if not UPGRADES.has(id):  # ids will come from peers in co-op
		return false
	var p := player(peer)
	var level: int = p.levels[id]
	var costs: Array = UPGRADES[id].costs
	if level >= costs.size() or p.gold < costs[level]:
		return false
	p.gold -= costs[level]
	p.levels[id] = level + 1
	if _is_local(peer):
		upgraded.emit(id, level + 1)
		gold_changed.emit(p.gold)
	return true


## Demo key: next level of an upgrade for free, back to the start after the last one.
func request_debug_level_up(id: String, peer := 0) -> void:
	if not UPGRADES.has(id):
		return
	var p := player(peer)
	p.levels[id] = (p.levels[id] + 1) % UPGRADES[id].values.size()
	if _is_local(peer):
		upgraded.emit(id, p.levels[id])


## Takes up to `count` bullets off the pile at world point `at`, returns how many were taken.
func request_take_bullets(count: int, at: Vector3) -> int:
	var taken: int = clampi(count, 0, pile)
	if taken > 0:
		pile -= taken
		pile_changed.emit(pile)
		bullets_taken.emit(at, taken)
	return taken


## Player grabs bullets at `at` by hand, up to carry capacity and at most `limit`.
func request_pick_up(at: Vector3, limit := 1 << 30, peer := 0) -> int:
	var p := player(peer)
	var taken := request_take_bullets(mini(carry_capacity_of(peer) - p.carried, limit), at)
	if taken > 0:
		_set_carried(peer, p.carried + taken)
	return taken


## Player picks up the loose bullet `id`. The first request wins; later ones for the same
## bullet (another player, same frame) get nothing.
func request_pick_up_loose(id: int, peer := 0) -> int:
	var p := player(peer)
	if _taken_loose.has(id) or p.carried >= carry_capacity_of(peer) or pile <= 0:
		return 0
	_taken_loose[id] = true
	pile -= 1
	pile_changed.emit(pile)
	_set_carried(peer, p.carried + 1)
	loose_taken.emit(id)
	return 1


## Moves carried bullets into the gun up to its capacity; returns how many went in.
func request_reload(peer := 0) -> int:
	var p := player(peer)
	var n := mini(mag_capacity_of(peer) - p.loaded, p.carried)
	if n <= 0:
		return 0
	_set_carried(peer, p.carried - n)
	_set_loaded(peer, p.loaded + n)
	return n


## Placement mode (B for now, until the build mode has its own way in): lets the player through
## the firing line to set targets up.
func request_toggle_placing(peer := 0) -> void:
	var p := player(peer)
	p.placing = not p.placing
	if _is_local(peer):
		placing_changed.emit(p.placing)


## Test mode (T): the gun never runs dry, for trying the feel and effects.
# ponytail: one switch for everyone; per-peer if co-op ever needs it.
var infinite_ammo := false


## Debug builds only. Switching it off puts back what was in the gun, so it never leaves free
## rounds behind.
func request_toggle_infinite_ammo(peer := 0) -> void:
	if not OS.is_debug_build():
		return
	infinite_ammo = not infinite_ammo
	var p := player(peer)
	if infinite_ammo:
		p.saved_loaded = p.loaded
		_set_loaded(peer, mag_capacity_of(peer))
	elif p.saved_loaded >= 0:
		_set_loaded(peer, mini(p.saved_loaded, mag_capacity_of(peer)))
		p.saved_loaded = -1
	if _is_local(peer):
		loaded_changed.emit(player(peer).loaded)


## Fires one loaded round from `from` along `dir`. The host traces it, so who hit what and
## how much it paid is decided in one place.
func request_fire(from: Vector3, dir: Vector3, peer := 0) -> bool:
	var p := player(peer)
	if p.loaded <= 0 or p.cooldown > 0.02:  # slack for frame timing on the caller
		return false
	p.cooldown = FIRE_INTERVAL
	if not infinite_ammo:
		_set_loaded(peer, p.loaded - 1)
	var who := local_peer() if peer == 0 else peer
	fired.emit(who, from, dir)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * SHOT_RANGE, SHOT_MASK)
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_break_chain(p)
		shot_landed.emit(who, from + dir * SHOT_RANGE, -dir, dir, null, 0, false, 0)
		return true
	var target: Node = hit.collider
	var gold := 0
	var weak := false
	# Pays only from the shooter's side of the firing line, at a target on the far side.
	if target.is_in_group("target") and from.x <= FIRING_LINE_X and hit.position.x > FIRING_LINE_X:
		var shape: Node = target.shape_owner_get_owner(target.shape_find_owner(hit.shape))
		weak = shape.is_in_group("weak_spot") or (target.has_method("is_weak") and target.is_weak(hit.position))
		p.combo += 1
		p.combo_left = COMBO_WINDOW
		p.combo_kinds[target.get("kind") if target.get("kind") else target.get_script()] = true
		var base = target.get("hit_gold")
		gold = (base if base is int else 1) * (WEAK_MULT if weak else 1) * combo_pay(p.combo, p.combo_kinds.size())
		p.gold += gold
		if _is_local(peer):
			gold_changed.emit(p.gold)
	else:
		_break_chain(p)
	shot_landed.emit(who, hit.position, hit.normal, dir, target, gold, weak, p.combo)
	return true


enum KeyState { BURIED, EXPOSED, TAKEN }
var key_states := {}  # rank -> KeyState, for every key the heap holds


## The heap uncovered key `rank`; only buried keys can be revealed, once.
func request_reveal_key(rank: int, at: Vector3) -> bool:
	if key_states.get(rank, -1) != KeyState.BURIED:
		return false
	key_states[rank] = KeyState.EXPOSED
	key_revealed.emit(rank, at)
	return true


## A player picks up an exposed key; the first request wins.
func request_take_key(rank: int, peer := 0) -> bool:
	if key_states.get(rank, -1) != KeyState.EXPOSED:
		return false
	key_states[rank] = KeyState.TAKEN
	player(peer).keys.append(rank)
	key_taken.emit(rank, local_peer() if peer == 0 else peer)
	return true


## What a chain of `combo` hits over `kinds` different target kinds pays per hit.
static func combo_pay(combo: int, kinds: int) -> int:
	return mini(combo, 1 + kinds)


func _break_chain(p: PlayerState) -> void:
	p.combo = 0
	p.combo_left = 0.0
	p.combo_kinds.clear()


## Player throws everything they carry from `from` toward `dir`; it goes back to the pile.
func request_throw(from: Vector3, dir: Vector3, peer := 0) -> int:
	var n := player(peer).carried
	if n == 0:
		return 0
	_set_carried(peer, 0)
	pile += n
	var first_id := _next_loose_id
	_next_loose_id += n
	pile_changed.emit(pile)
	bullets_thrown.emit(from, dir, n, first_id)
	return n


func _set_carried(peer: int, n: int) -> void:
	player(peer).carried = n
	if _is_local(peer):
		carried_changed.emit(n)


func _set_loaded(peer: int, n: int) -> void:
	player(peer).loaded = n
	if _is_local(peer):
		loaded_changed.emit(n)
