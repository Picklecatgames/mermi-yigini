extends Node
## All game state lives here. Player actions are request_* commands:
## solo they run directly, in co-op they will be routed to the host.
## The world (pile, loose bullets) is shared; each player has their own hands, gun, gold and
## upgrades, kept per peer id. `peer` 0 in a request means the local player.
##
## Co-op (scripts/net.gd connects): only the host changes state. A client's request runs here
## too, as a prediction on its own PlayerState so the gun and hands answer at once, and goes to
## the host (_request), which runs it for real and answers with that player's state (_state).
## World changes (pile, loose bullets, keys, shots) happen on the host alone and reach every
## peer as events (_world -> _event), so a client never digs, traces or pays by itself.

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
## Another player's body moved: feet `pos`, look `yaw`/`pitch`, what they are doing (Act).
## `time` is on that player's own clock (seconds), so the receiver can space snapshots evenly.
signal pose_received(peer: int, time: float, pos: Vector3, yaw: float, pitch: float, act: int)
## The host gave this machine's player its own spawn point (index into group "spawn").
signal spawn_assigned(index: int)

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
## A client's shots reach the host up to this much closer together than FIRE_INTERVAL
## (network jitter); the host lets them through rather than eat a round the client already fired.
const NET_JITTER := 0.15  # s
## The eye above the feet (player.gd EYE): where a player's rounds leave from.
const EYE := 1.6  # m
## A client's round must leave from within this of its synced eye (pose lag plus a sprint step);
## anything farther is a forged `from` and the host drops the shot.
const FIRE_FROM_SLACK := 1.5  # m
## What a player is doing, sent with its pose so other machines can show it.
enum Act { IDLE, WALKING, RELOADING, SHOOTING }

## What a client may ask the host for, with its argument count (`peer` comes from the sender).
const REQUESTS := {
	&"request_buy_upgrade": 1, &"request_debug_level_up": 1, &"request_pick_up": 2,
	&"request_pick_up_loose": 1, &"request_reload": 0, &"request_toggle_placing": 0,
	&"request_toggle_infinite_ammo": 0, &"request_fire": 2, &"request_take_key": 1,
	&"request_throw": 2,
}
## World signals: emitted on the host and sent on to every client.
const EVENTS: Array[StringName] = [&"pile_changed", &"bullets_taken", &"bullets_thrown",
	&"loose_taken", &"fired", &"shot_landed", &"key_revealed", &"key_taken"]


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
	var infinite_ammo := false  # test mode (T)
	var pos := Vector3.ZERO  # feet, from the last pose
	var has_pose := false


var pile: int = PILE_START
var _players := {}  # peer id -> PlayerState
var _next_loose_id := THROWN_ID_START
# ponytail: grows by one per loose grab; the save system can prune ids no longer in the world.
var _taken_loose := {}
# Client side: requests sent to the host, and the last one it has answered. The host's answer is
# taken as the truth only once every request has been answered, so it never undoes a prediction
# still on its way.
var _sent_seq := 0
var _acked_seq := 0
var _claimed := {}  # loose bullet ids asked for and not answered yet, so E held asks once
var spawn_index := 0  # this machine's spawn point; the host is 0
var _spawn_slots := {}  # host: peer -> spawn index

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


func _ready() -> void:
	# Someone joined: the pile count is the one thing they would see wrong right away.
	# ponytail: count only; heap shape, loose bullets and keys come with mid-game join (Faz 1/8).
	multiplayer.peer_connected.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_event.rpc_id(id, &"pile_changed", [pile])
			# Each player starts on a spawn point of their own: the first one nobody holds.
			var slot := 1
			while slot in _spawn_slots.values():
				slot += 1
			_spawn_slots[id] = slot
			_spawn.rpc_id(id, slot))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: _spawn_slots.erase(id))


## Every request from this peer has been answered by the host (always true solo and on the host).
func synced() -> bool:
	return _acked_seq == _sent_seq


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
	_send(&"request_buy_upgrade", [id], peer)
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
	_send(&"request_debug_level_up", [id], peer)
	var p := player(peer)
	p.levels[id] = (p.levels[id] + 1) % UPGRADES[id].values.size()
	if _is_local(peer):
		upgraded.emit(id, p.levels[id])


## Takes up to `count` bullets off the pile at world point `at`, returns how many were taken.
## Host only: a client digs through its own requests.
func request_take_bullets(count: int, at: Vector3) -> int:
	if Net.is_client:
		return 0
	var taken: int = clampi(count, 0, pile)
	if taken > 0:
		pile -= taken
		_world(&"pile_changed", [pile])
		_world(&"bullets_taken", [at, taken])
	return taken


## Player grabs bullets at `at` by hand, up to carry capacity and at most `limit`.
func request_pick_up(at: Vector3, limit := 1 << 30, peer := 0) -> int:
	var p := player(peer)
	var want := mini(carry_capacity_of(peer) - p.carried, limit)
	if want <= 0:
		return 0  # a full hand asks nobody (E held sends a request every frame otherwise)
	if _send(&"request_pick_up", [at, limit], peer):
		# The host digs; if the pile ran dry first, its answer takes the bullet back.
		var guess := clampi(want, 0, pile)
		_set_carried(peer, p.carried + guess)
		return guess
	var taken := request_take_bullets(want, at)
	if taken > 0:
		_set_carried(peer, p.carried + taken)
	return taken


## Player picks up the loose bullet `id`. The first request wins; later ones for the same
## bullet (another player, same frame) get nothing.
func request_pick_up_loose(id: int, peer := 0) -> int:
	var p := player(peer)
	if _taken_loose.has(id) or p.carried >= carry_capacity_of(peer) or pile <= 0:
		return 0
	if Net.is_client and peer == 0:
		if _claimed.has(id):
			return 0
		_claimed[id] = true
	if _send(&"request_pick_up_loose", [id], peer):
		_set_carried(peer, p.carried + 1)  # the bullet itself goes when the host says loose_taken
		return 1
	_taken_loose[id] = true
	pile -= 1
	_world(&"pile_changed", [pile])
	_set_carried(peer, p.carried + 1)
	_world(&"loose_taken", [id])
	return 1


## Moves carried bullets into the gun up to its capacity; returns how many went in.
func request_reload(peer := 0) -> int:
	var p := player(peer)
	var n := mini(mag_capacity_of(peer) - p.loaded, p.carried)
	if n <= 0:
		return 0
	_send(&"request_reload", [], peer)
	_set_carried(peer, p.carried - n)
	_set_loaded(peer, p.loaded + n)
	return n


## Placement mode (B for now, until the build mode has its own way in): lets the player through
## the firing line to set targets up.
func request_toggle_placing(peer := 0) -> void:
	_send(&"request_toggle_placing", [], peer)
	var p := player(peer)
	p.placing = not p.placing
	if _is_local(peer):
		placing_changed.emit(p.placing)


## Test mode (T): the gun never runs dry, for trying the feel and effects. Per player.
var infinite_ammo: bool:
	get: return player().infinite_ammo
	set(v): player().infinite_ammo = v


## Debug builds only. Switching it off puts back what was in the gun, so it never leaves free
## rounds behind.
func request_toggle_infinite_ammo(peer := 0) -> void:
	if not OS.is_debug_build():
		return
	_send(&"request_toggle_infinite_ammo", [], peer)
	var p := player(peer)
	p.infinite_ammo = not p.infinite_ammo
	if p.infinite_ammo:
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
	# Slack for frame timing on the caller, more for a remote one's network jitter.
	if p.loaded <= 0 or p.cooldown > (0.02 if _is_local(peer) else NET_JITTER):
		return false
	# A remote round leaves from that player's synced eye, or not at all.
	if not _is_local(peer) and not (p.has_pose and from.distance_to(p.pos + Vector3.UP * EYE) <= FIRE_FROM_SLACK):
		return false
	p.cooldown = FIRE_INTERVAL
	if not p.infinite_ammo:
		_set_loaded(peer, p.loaded - 1)
	# A client's gun kicks and flashes now; where the round went comes back as shot_landed.
	if _send(&"request_fire", [from, dir], peer):
		return true
	var who := local_peer() if peer == 0 else peer
	_world(&"fired", [who, from, dir])
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * SHOT_RANGE, SHOT_MASK)
	# Players never stop a round: the host's own body would eat its guests' shots otherwise.
	var bodies: Array[RID] = []
	for w in get_tree().get_nodes_in_group("walker"):
		if w is CollisionObject3D:
			bodies.append(w.get_rid())
	q.exclude = bodies
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_break_chain(p)
		_world(&"shot_landed", [who, from + dir * SHOT_RANGE, -dir, dir, null, 0, false, 0])
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
	_world(&"shot_landed", [who, hit.position, hit.normal, dir, target, gold, weak, p.combo])
	return true


enum KeyState { BURIED, EXPOSED, TAKEN }
var key_states := {}  # rank -> KeyState, for every key the heap holds


## The heap uncovered key `rank`; only buried keys can be revealed, once.
## Host only: the host's heap says when a key comes out.
func request_reveal_key(rank: int, at: Vector3) -> bool:
	if Net.is_client or key_states.get(rank, -1) != KeyState.BURIED:
		return false
	key_states[rank] = KeyState.EXPOSED
	_world(&"key_revealed", [rank, at])
	return true


## A player picks up an exposed key; the first request wins.
func request_take_key(rank: int, peer := 0) -> bool:
	if key_states.get(rank, -1) != KeyState.EXPOSED:
		return false
	if _send(&"request_take_key", [rank], peer):
		return true  # no guess: two players may reach for it, the host's key_taken says who won
	key_states[rank] = KeyState.TAKEN
	player(peer).keys.append(rank)
	_world(&"key_taken", [rank, local_peer() if peer == 0 else peer])
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
	if _send(&"request_throw", [from, dir], peer):
		return n  # the bullets fly when the host's bullets_thrown hands out their ids
	pile += n
	var first_id := _next_loose_id
	_next_loose_id += n
	_world(&"pile_changed", [pile])
	_world(&"bullets_thrown", [from, dir, n, first_id])
	return n


func _set_carried(peer: int, n: int) -> void:
	player(peer).carried = n
	if _is_local(peer):
		carried_changed.emit(n)


func _set_loaded(peer: int, n: int) -> void:
	player(peer).loaded = n
	if _is_local(peer):
		loaded_changed.emit(n)


# --- Co-op plumbing ---------------------------------------------------------------------------

## The local player's request, while joined to someone else's session, goes to the host as
## well. Returns true then; the caller predicts what it can and leaves the world to the host.
func _send(method: StringName, args: Array, peer: int) -> bool:
	if peer != 0 or not Net.is_client:
		return false
	_sent_seq += 1
	_request.rpc_id(1, method, args, _sent_seq)
	return true


## Host: a client's request. Runs it for that peer and answers with the peer's state.
@rpc("any_peer", "call_remote", "reliable")
func _request(method: StringName, args: Array, seq: int) -> void:
	if not multiplayer.is_server() or REQUESTS.get(method, -1) != args.size():
		return  # anything else off the wire is ignored
	var peer := multiplayer.get_remote_sender_id()
	callv(method, args + [peer])
	var p := player(peer)
	_state.rpc_id(peer, seq, p.carried, p.loaded, p.gold, p.levels, p.placing, p.infinite_ammo)


## Client: the host's word on our own state, after request `seq`.
@rpc("authority", "call_remote", "reliable")
func _state(seq: int, carried_: int, loaded_: int, gold_: int, levels: Dictionary, placing: bool, infinite: bool) -> void:
	_acked_seq = seq
	if seq != _sent_seq:
		return  # newer requests are still on their way; their answer will have it all
	_claimed.clear()
	var p := player()
	p.infinite_ammo = infinite
	if p.carried != carried_:
		_set_carried(0, carried_)
	if p.loaded != loaded_:
		_set_loaded(0, loaded_)
	if p.gold != gold_:
		p.gold = gold_
		gold_changed.emit(gold_)
	for id: String in levels:
		if p.levels.get(id) != levels[id]:
			p.levels[id] = levels[id]
			upgraded.emit(id, levels[id])
	if p.placing != placing:
		p.placing = placing
		placing_changed.emit(placing)


## The local player's body, ~20 times a second (player.gd). Online it goes to the host, which
## keeps it (request_fire checks `from` against it) and passes it on to everyone else. Poses are
## unreliable on a channel of their own: a lost one is replaced 50 ms later anyway.
func send_pose(pos: Vector3, yaw: float, pitch: float, act: int) -> void:
	var p := player()
	p.pos = pos
	p.has_pose = true
	if not Net.online:
		return
	var t := Time.get_ticks_msec() / 1000.0
	if multiplayer.is_server():
		_pose_of.rpc(local_peer(), t, pos, yaw, pitch, act)
	else:
		_pose.rpc_id(1, t, pos, yaw, pitch, act)


## Host: a client's pose.
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _pose(t: float, pos: Vector3, yaw: float, pitch: float, act: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var p := player(peer)
	p.pos = pos
	p.has_pose = true
	pose_received.emit(peer, t, pos, yaw, pitch, act)
	for id in multiplayer.get_peers():
		if id != peer:
			_pose_of.rpc_id(id, peer, t, pos, yaw, pitch, act)


## Client: someone else's pose, from the host.
@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _pose_of(peer: int, t: float, pos: Vector3, yaw: float, pitch: float, act: int) -> void:
	if peer != local_peer():
		pose_received.emit(peer, t, pos, yaw, pitch, act)


## Client: the host's pick of our spawn point.
@rpc("authority", "call_remote", "reliable")
func _spawn(index: int) -> void:
	spawn_index = index
	spawn_assigned.emit(index)


## A world signal: emitted here, and on the host sent on to every client as well.
func _world(event: StringName, args: Array) -> void:
	callv(&"emit_signal", [event] + args)
	if Net.online and multiplayer.is_server():
		if event == &"shot_landed":  # nodes travel as paths; every peer runs the same scenes
			args[4] = args[4].get_path() if args[4] else NodePath()
		_event.rpc(event, args)


## Client: a world event from the host. Mirrors the shared state, then emits it as the host did.
@rpc("authority", "call_remote", "reliable")
func _event(event: StringName, args: Array) -> void:
	if event not in EVENTS:
		return
	match event:
		&"pile_changed":
			pile = args[0]
		&"loose_taken":
			_taken_loose[args[0]] = true
		&"bullets_thrown":
			_next_loose_id = maxi(_next_loose_id, args[3] + args[2])
		&"key_revealed":
			key_states[args[0]] = KeyState.EXPOSED
		&"key_taken":
			key_states[args[0]] = KeyState.TAKEN
			player(args[1]).keys.append(args[0])
		&"shot_landed":
			# A node only the host has lands as null (spent shells are on no layer, so none yet).
			var path: NodePath = args[4]
			args[4] = null if path.is_empty() else get_node_or_null(path)
	callv(&"emit_signal", [event] + args)
