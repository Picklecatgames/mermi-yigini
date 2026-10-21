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
## Another player's body moved: feet `pos`, look `yaw`/`pitch`, what they are doing (Act),
## whether they are off the ground (`air`, a jump or a fall). `time` is on that player's own
## clock (seconds), so the receiver can space snapshots evenly.
signal pose_received(peer: int, time: float, pos: Vector3, yaw: float, pitch: float, act: int, air: bool)
## The host gave this machine's player its own spawn point (index into group "spawn").
signal spawn_assigned(index: int)
## Where the keys are buried: the host rolls the seed, a client lays its keys out again from it
## (scripts/key_cache.gd).
signal key_layout(seed: int)
## The shared vault: everything built into the world is bought from it. Every paying hit adds
## VAULT_SHARE of its pay on top (the shooter keeps all of theirs). Float, so $1 hits add up.
signal vault_changed(vault: float)
signal gear_changed(stock: Dictionary)  # GEAR id -> bought, not placed yet
## Gear went up in the target area: number `n` in placement order (its node is Placed/Gear_<n>).
signal gear_placed(n: int, id: String, pos: Vector3, yaw: float)
## Placed piece `n` was taken down and went back to the stock; its number stays unused.
signal gear_removed(n: int)
## Someone else's placement preview (scripts/placement.gd draws it faint); id "" when they stop.
signal preview_received(peer: int, id: String, pos: Vector3, yaw: float)
## A moving target's own call, made on the host alone: which plate comes up, when a popper
## stands back up, where the star has turned to. Clients follow these instead of rolling their own.
## What `cue` holds is up to the target.
signal target_cue(target: Node, cue: Array)
## Friendly fire: `shooter`'s round struck `victim`. It does no harm; it throws the victim's aim.
signal player_shot(shooter: int, victim: int, at: Vector3, dir: Vector3)
## Who stands on which spawn point (peer -> slot, the host 0); a player's colour follows it.
signal player_slots(slots: Dictionary)
## Someone walked into the local player: shove it this way (m/s), on top of its own walking.
signal pushed(vel: Vector3)
## What `peer` holds now: an index into GUNS (0 is bare fists).
signal gun_changed(peer: int, gun: int)

const PILE_START := 100_000_000
const MAX_PLAYERS := 4
## Loose bullet ids: the baked spill is 0 .. its size - 1, thrown bullets count up from here.
const THROWN_ID_START := 1 << 20

## Upgrade tree: value per level (level 0 = start) and gold cost to reach each next level.
## All personal: each player buys their own, nothing carries over to the others.
# ponytail: placeholder numbers until the 60-minute balance pass.
const UPGRADES := {
	"carry": {"values": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "costs": [6, 15, 30, 55, 90, 140, 210, 300, 420]},
	# Up to the heavy pistol's 7-round magazine. First level in ~20 s of play, the last ~10 min in.
	"magazine": {"values": [1, 2, 3, 4, 5, 6, 7], "costs": [8, 20, 45, 90, 160, 280]},
	# The highest a combo chain can reach, on every target. The last level is COMBO_MAX.
	"combo_cap": {"values": [2, 5, 10, 15, 20], "costs": [15, 60, 180, 450]},
	# Extra gold per hit on every target, in percent.
	"gold_bonus": {"values": [0, 10, 20, 30, 40, 50, 60], "costs": [25, 60, 120, 220, 380, 600]},
	# Extra gold in percent for every metre the shooter stands behind the firing line, every target.
	"range_bonus": {"values": [0, 1, 2, 3, 4, 5], "costs": [30, 80, 180, 350, 600]},
}
## What a player can hold, in the order the bar and the number keys list them (1 = the first gun);
## everyone starts with bare fists. A gun without its model yet is not `ready`: nobody can draw it.
## Shots, rounds and fire rate are the same for every gun for now (the weapon order comes later).
const GUNS := [
	{"id": "fists", "name": "Yumruk", "ready": true},
	{"id": "deagle", "name": "Ağır Tabanca", "ready": true},
	{"id": "uzi", "name": "Mikro SMG", "ready": true},
	{"id": "scorpion", "name": "Kompakt SMG", "ready": true},
	{"id": "minigun", "name": "Minigun", "ready": false},  # final, from a crate; model not in yet
]
## Fixed, not an upgrade: the slide has finished its cycle and the recoil spring has settled.
const FIRE_INTERVAL := 0.42  # s, ~143 rounds/min
## A weak spot pays this many times over: a collision shape in group "weak_spot" (the dummy's
## head), or where the target's `is_weak(at)` says so (a popper's round head).
const WEAK_MULT := 2
## Combo: each paying hit within this long of the last one adds 1 to the chain, and the chain is
## the multiplier (x3 pays 3 times over), up to the player's "combo_cap" upgrade. Weak spot hits and body hits keep
## separate chains, so a chain built on easy body shots never pays out on a head. A gap this long
## starts a chain over; a miss starts both over.
const COMBO_WINDOW := 1.5  # s
const COMBO_MAX := 20  # combo_cap's last level; the combo meter's full size and colour
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
## A push only counts between players this close (feet, from their poses), and is never faster
## than a sprint, so a forged one cannot fling anybody across the shed.
const PUSH_REACH := 1.5  # m
const PUSH_MAX := 8.0  # m/s
const VAULT_SHARE := 0.2  # placeholder (yol haritası 7)
## Gear: targets the team buys from the shared vault (Q menu, Teçhizatlar). Bought ones wait in
## the shared stock until someone places them (yol haritası 10). Order is the menu's order.
# ponytail: placeholder prices until the 60-minute balance pass.
const GEAR := {
	"dummy": {"name": "Saman Kukla", "scene": "res://scenes/dummy.tscn", "cost": 20},
	"steel_silhouette": {"name": "Çelik Siluet", "scene": "res://scenes/steel_silhouette.tscn", "cost": 35},
	"steel_gong": {"name": "Çelik Gong", "scene": "res://scenes/steel_gong.tscn", "cost": 35},
	"popper": {"name": "Popper", "scene": "res://scenes/popper_target.tscn", "cost": 60},
	"steel_rack": {"name": "Plaka Dizisi", "scene": "res://scenes/steel_rack.tscn", "cost": 90},
	"plate_rack": {"name": "Köstebek Rafı", "scene": "res://scenes/plate_rack.tscn", "cost": 150},
	"texas_star": {"name": "Texas Star", "scene": "res://scenes/texas_star.tscn", "cost": 300},
}
## Name tag colour per spawn slot, until players pick their own (Faz 6, step 25).
const PLAYER_COLORS: Array[Color] = [Color(0.95, 0.55, 0.1), Color(0.2, 0.6, 1.0), Color(0.35, 0.8, 0.3), Color(0.85, 0.3, 0.75)]
## What a player is doing, sent with its pose so other machines can show it.
enum Act { IDLE, WALKING, RELOADING, SHOOTING }

## What a client may ask the host for, with its argument count (`peer` comes from the sender).
const REQUESTS := {
	&"request_buy_upgrade": 1, &"request_debug_level_up": 1, &"request_pick_up": 2,
	&"request_pick_up_loose": 1, &"request_reload": 0, &"request_toggle_placing": 0,
	&"request_toggle_infinite_ammo": 0, &"request_fire": 2, &"request_take_key": 1,
	&"request_throw": 2, &"request_push": 2, &"request_hello": 1, &"request_buy_gear": 1,
	&"request_place_gear": 3, &"request_remove_gear": 1, &"request_select_gun": 1,
}
## Where gear may stand: the target area past the firing line, clear of the east wall and the
## crate stands; at least PLACE_GAP from any target's origin.
const PLACE_ZONE := Rect2(15.0, -25.0, 11.5, 45.0)  # x, z
const PLACE_GAP := 1.6  # m
const TOKEN_FILE := "user://player_token.txt"
## World signals: emitted on the host and sent on to every client.
const EVENTS: Array[StringName] = [&"pile_changed", &"bullets_taken", &"bullets_thrown",
	&"loose_taken", &"fired", &"shot_landed", &"key_revealed", &"key_taken", &"key_layout",
	&"target_cue", &"player_shot", &"player_slots", &"vault_changed", &"gear_changed", &"gear_placed", &"gear_removed", &"gun_changed"]
## Events with a node in them, and where: nodes travel as paths, every peer runs the same scenes.
const NODE_ARG := {&"shot_landed": 4, &"target_cue": 0}


class PlayerState:
	var carried := 0
	var loaded := 0  # rounds in the gun
	var gold := 0
	var levels := {"carry": 0, "magazine": 0, "combo_cap": 0, "gold_bonus": 0, "range_bonus": 0}
	var gold_rest := 0.0  # the fraction of a dollar the percent bonuses left over, paid on later hits
	var cooldown := 0.0  # s; game time, so it follows Engine.time_scale like the gun does
	var combo := 0  # body hits in the current chain
	var weak_combo := 0  # weak spot hits in their own chain
	var saved_loaded := -1  # rounds in the gun before test mode (T) filled it
	var keys: Array[int] = []  # crate key ranks held (1 = most common)
	var combo_left := 0.0  # s until the body chain breaks; game time
	var weak_left := 0.0  # s until the weak spot chain breaks
	var placing := false  # placement mode: may cross the firing line
	var gun := 0  # GUNS index in hand; 0 is bare fists
	var infinite_ammo := false  # test mode (T)
	var pos := Vector3.ZERO  # feet, from the last pose
	var has_pose := false


var pile: int = PILE_START
var vault := 0.0
var gear_stock := {}  # GEAR id -> bought and not placed yet, shared by the team
var placed := []      # [GEAR id, pos, yaw] per piece put up, in order
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
var _spawned := false  # client: the host has placed us; until then our body stays unseen
var slots := {}  # peer -> spawn slot, everyone in the session (player_slots)
var key_seed := 0  # the key layout's seed; 0 until scripts/key_cache.gd has rolled or received one
var _spawn_slots := {}  # host: peer -> spawn index
# Host: who is who across reconnects. A client says its token on joining (request_hello); a
# leaver's state waits under it until the same token comes back.
# ponytail: a token file per machine; Steam IDs replace it in Faz 6 (step 22).
var _token_of := {}  # peer -> token
var _saved := {}     # token -> PlayerState of a player who left
var key_at := {}     # rank -> where an exposed key came out, for joiners

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
	return upgrade_value("carry", peer)


func mag_capacity_of(peer: int) -> int:
	return upgrade_value("magazine", peer)


func _ready() -> void:
	# Someone joined: they get the world as it is now, in one go, before any later event.
	multiplayer.peer_connected.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_event.rpc_id(id, &"pile_changed", [pile])
			_event.rpc_id(id, &"key_layout", [key_seed])
			_event.rpc_id(id, &"vault_changed", [vault])
			_event.rpc_id(id, &"gear_changed", [gear_stock])
			var heap := get_tree().get_first_node_in_group("bullet_pile")
			_join.rpc_id(id, heap.snapshot() if heap else [], _taken_loose.keys())
			for rank: int in key_states:
				if key_states[rank] != KeyState.BURIED:
					_event.rpc_id(id, &"key_revealed", [rank, key_at.get(rank, Vector3.ZERO)])
				if key_states[rank] == KeyState.TAKEN:
					_event.rpc_id(id, &"key_taken", [rank, _holder_of(rank)])
			for n in placed.size():  # before the cues: placed targets have state of their own
				if placed[n]:
					_event.rpc_id(id, &"gear_placed", [n] + placed[n])
			for peer: int in _players:
				if _players[peer].gun != 0 and peer != id:
					_event.rpc_id(id, &"gun_changed", [peer, _players[peer].gun])
			for t: Node in get_tree().get_nodes_in_group("target"):
				if t.has_method("join_cues"):
					for cue: Array in t.join_cues():
						_event.rpc_id(id, &"target_cue", [t.get_path(), cue])
			# Each player starts on a spawn point of their own: the first one nobody holds.
			var slot := 1
			while slot in _spawn_slots.values():
				slot += 1
			_spawn_slots[id] = slot
			_spawn.rpc_id(id, slot)
			slots = _slots_now()
			_world(&"player_slots", [slots]))
	multiplayer.connected_to_server.connect(func() -> void: request_hello(_token()))
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		_spawn_slots.erase(id)
		if multiplayer.is_server():
			if _token_of.has(id) and _players.has(id):
				_saved[_token_of[id]] = _players[id]  # gold, upgrades, hand, gun, keys: back when they are
			_token_of.erase(id)
			_players.erase(id)
			slots = _slots_now()
			_world(&"player_slots", [slots]))


func _slots_now() -> Dictionary:
	var all := _spawn_slots.duplicate()
	all[local_peer()] = 0
	return all


## The colour standing for `peer` (name tag).
func color_of(peer: int) -> Color:
	return PLAYER_COLORS[slots.get(peer, 0) % PLAYER_COLORS.size()]


## Every request from this peer has been answered by the host (always true solo and on the host).
func synced() -> bool:
	return _acked_seq == _sent_seq


func _process(delta: float) -> void:
	for p: PlayerState in _players.values():
		p.cooldown = maxf(p.cooldown - delta, 0.0)
		p.combo_left = maxf(p.combo_left - delta, 0.0)
		p.weak_left = maxf(p.weak_left - delta, 0.0)
		if p.combo_left == 0.0:
			p.combo = 0
		if p.weak_left == 0.0:
			p.weak_combo = 0


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


## Anyone buys a piece of gear for the team, from the shared vault. No guess on a client: the
## vault is the host's, and two players may spend the same money; gear_changed says what came of it.
func request_buy_gear(id: String, peer := 0) -> bool:
	if not GEAR.has(id):
		return false
	if _send(&"request_buy_gear", [id], peer):
		return vault >= GEAR[id].cost
	if vault < GEAR[id].cost:
		return false
	vault -= GEAR[id].cost
	gear_stock[id] = gear_stock.get(id, 0) + 1
	_world(&"vault_changed", [vault])
	_world(&"gear_changed", [gear_stock])
	return true


## Whether piece `id` from the stock may go up at `pos` (target area, room around it).
func can_place(id: String, pos: Vector3) -> bool:
	if gear_stock.get(id, 0) <= 0 or not PLACE_ZONE.has_point(Vector2(pos.x, pos.z)):
		return false
	for t: Node in get_tree().get_nodes_in_group("target"):
		var at: Vector3 = (t as Node3D).global_position
		if Vector2(at.x - pos.x, at.z - pos.z).length() < PLACE_GAP:
			return false
	return true


## Puts piece `id` from the shared stock up at `pos`, turned `yaw`. The host checks the spot; two
## players dropping on one spot: the first wins, the second finds it taken (or the stock empty).
func request_place_gear(id: String, pos: Vector3, yaw: float, peer := 0) -> bool:
	if not GEAR.has(id):
		return false
	if _send(&"request_place_gear", [id, pos, yaw], peer):
		return can_place(id, pos)  # no guess: the piece appears when the host's gear_placed comes
	if not can_place(id, pos):
		return false
	gear_stock[id] -= 1
	placed.append([id, pos, yaw])
	_world(&"gear_changed", [gear_stock])
	_world(&"gear_placed", [placed.size() - 1, id, pos, yaw])
	return true


## Takes placed piece `n` down, back into the shared stock. Anyone may; the host decides.
func request_remove_gear(n: int, peer := 0) -> bool:
	if n < 0 or n >= placed.size() or placed[n] == null:
		return false
	if _send(&"request_remove_gear", [n], peer):
		return true  # it goes when the host's gear_removed comes
	var id: String = placed[n][0]
	placed[n] = null
	gear_stock[id] = gear_stock.get(id, 0) + 1
	_world(&"gear_changed", [gear_stock])
	_world(&"gear_removed", [n])
	return true


## Our placement preview for the others to see faint; id "" when we stop. Unreliable, ~10 Hz.
func send_preview(id: String, pos: Vector3, yaw: float) -> void:
	if not Net.online:
		return
	if multiplayer.is_server():
		_preview_of.rpc(local_peer(), id, pos, yaw)
	else:
		_preview.rpc_id(1, id, pos, yaw)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _preview(id: String, pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	preview_received.emit(peer, id, pos, yaw)
	for other in multiplayer.get_peers():
		if other != peer:
			_preview_of.rpc_id(other, peer, id, pos, yaw)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _preview_of(peer: int, id: String, pos: Vector3, yaw: float) -> void:
	if peer != local_peer():
		preview_received.emit(peer, id, pos, yaw)


## What a player is called on screen (name tag, Q menu).
func display_name(peer := 0) -> String:
	return "Oyuncu %d" % (local_peer() if peer == 0 else peer)  # ponytail: Steam name in Faz 6


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
	if p.gun == 0:
		return 0
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


## Puts away what is in hand and draws GUNS[`gun`]; the same one again goes back to bare fists.
## Everyone sees it (gun_changed): the first-person arms and others' third-person hold follow it.
func request_select_gun(gun: int, peer := 0) -> void:
	var p := player(peer)
	if gun < 0 or gun >= GUNS.size() or not GUNS[gun].ready or p.placing:
		return
	if gun == p.gun:
		gun = 0
	if _send(&"request_select_gun", [gun], peer):
		p.gun = gun  # predicted; the host's gun_changed says the same a moment later
		gun_changed.emit(local_peer(), gun)
		return
	p.gun = gun
	_world(&"gun_changed", [local_peer() if peer == 0 else peer, gun])


## Test mode (T): the gun never runs dry, for trying the feel and effects. Per player.
var infinite_ammo: bool:
	get: return player().infinite_ammo
	set(v): player().infinite_ammo = v

const TEST_MONEY := 1_000_000_000  # what T tops gold and the vault up to


## Debug builds only. Switching it off puts back what was in the gun, so it never leaves free
## rounds behind. Switching it on also tops up gold and the vault, for trying the shop.
func request_toggle_infinite_ammo(peer := 0) -> void:
	if not OS.is_debug_build():
		return
	_send(&"request_toggle_infinite_ammo", [], peer)
	var p := player(peer)
	p.infinite_ammo = not p.infinite_ammo
	if p.infinite_ammo:
		p.saved_loaded = p.loaded
		_set_loaded(peer, mag_capacity_of(peer))
		# ponytail: the money stays after T goes off; a test build only, so not worth undoing.
		p.gold = maxi(p.gold, TEST_MONEY)
		if _is_local(peer):
			gold_changed.emit(p.gold)
		if not Net.is_client:  # the vault is the host's
			vault = maxf(vault, TEST_MONEY)
			_world(&"vault_changed", [vault])
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
	if p.gun == 0 or p.loaded <= 0 or p.cooldown > (0.02 if _is_local(peer) else NET_JITTER):
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
	var own := _body_of(who)  # the round starts inside the shooter
	if own:
		q.exclude = [own.get_rid()]
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_break_chain(p)
		_world(&"shot_landed", [who, from + dir * SHOT_RANGE, -dir, dir, null, 0, false, 0])
		return true
	var target: Node = hit.collider
	var victim := _peer_of(target)
	if victim != 0:  # friendly fire: no pay, no harm, the chain breaks and their aim jumps
		_break_chain(p)
		_world(&"shot_landed", [who, hit.position, hit.normal, dir, null, 0, false, 0])
		_world(&"player_shot", [who, victim, hit.position, dir])
		return true
	var gold := 0
	var weak := false
	var chain := 0
	# Pays only from the shooter's side of the firing line, at a target on the far side.
	if target.is_in_group("target") and from.x <= FIRING_LINE_X and hit.position.x > FIRING_LINE_X:
		var shape: Node = target.shape_owner_get_owner(target.shape_find_owner(hit.shape))
		weak = shape.is_in_group("weak_spot") or (target.has_method("is_weak") and target.is_weak(hit.position))
		var cap := upgrade_value("combo_cap", peer)
		if weak:
			p.weak_combo = mini(p.weak_combo + 1, cap)
			p.weak_left = COMBO_WINDOW
			chain = p.weak_combo
		else:
			p.combo = mini(p.combo + 1, cap)
			p.combo_left = COMBO_WINDOW
			chain = p.combo
		var base = target.get("hit_gold")
		var behind := maxf(FIRING_LINE_X - from.x, 0.0)  # m behind the railing
		var bonus := upgrade_value("gold_bonus", peer) + roundi(upgrade_value("range_bonus", peer) * behind)
		var raw := float((base if base is int else 1) * (WEAK_MULT if weak else 1) * chain) * (100 + bonus) / 100.0 + p.gold_rest
		gold = floori(raw)
		p.gold_rest = raw - gold
		p.gold += gold
		if _is_local(peer):
			gold_changed.emit(p.gold)
		if not Net.is_client:  # a client's prediction leaves the shared vault to the host
			vault += gold * VAULT_SHARE
			_world(&"vault_changed", [vault])
	else:
		_break_chain(p)
	_world(&"shot_landed", [who, hit.position, hit.normal, dir, target, gold, weak, chain])
	return true


## The body standing for `peer` here: this machine's own player, or another's character.
func _body_of(peer: int) -> CollisionObject3D:
	if peer == local_peer():
		return get_tree().get_first_node_in_group("walker") as CollisionObject3D
	var rp := get_tree().get_first_node_in_group("remote_players")
	var c: Node = rp.character(peer) if rp else null
	return c.body if c else null


## Which player a collider is (0 if it is no player).
func _peer_of(collider: Node) -> int:
	if collider.is_in_group("walker"):
		return local_peer()
	return collider.get_meta("peer", 0)


## The local player walked into `target`'s body: shove them along with `vel`. The shoved player's
## own machine moves them (everyone moves their own body), so this goes there through the host.
func request_push(target: int, vel: Vector3, peer := 0) -> void:
	if _send(&"request_push", [target, vel], peer):
		return
	var who := local_peer() if peer == 0 else peer
	var a := player(who)
	var b := player(target)
	if target == who or not b.has_pose or not a.has_pose or a.pos.distance_to(b.pos) > PUSH_REACH:
		return
	vel = Vector3(vel.x, 0.0, vel.z).limit_length(PUSH_MAX)
	if target == local_peer():
		pushed.emit(vel)
	elif Net.online:
		_pushed.rpc_id(target, vel)


## Client: someone walked into us (from the host).
@rpc("authority", "call_remote", "reliable")
func _pushed(vel: Vector3) -> void:
	pushed.emit(vel)


enum KeyState { BURIED, EXPOSED, TAKEN }
var key_states := {}  # rank -> KeyState, for every key the heap holds


## Host (or solo): the key layout's seed, told to everyone.
func set_key_seed(seed: int) -> void:
	if not Net.is_client:
		key_seed = seed
		_world(&"key_layout", [seed])


## Host (or solo): a moving target's decision; see target_cue. A client's own calls are dropped.
func cue_target(target: Node, cue: Array) -> void:
	if not Net.is_client:
		_world(&"target_cue", [target, cue])


## The heap uncovered key `rank`; only buried keys can be revealed, once.
## Host only: the host's heap says when a key comes out.
func request_reveal_key(rank: int, at: Vector3) -> bool:
	if Net.is_client or key_states.get(rank, -1) != KeyState.BURIED:
		return false
	key_states[rank] = KeyState.EXPOSED
	key_at[rank] = at
	_world(&"key_revealed", [rank, at])
	return true


## Host: who holds taken key `rank` (a player who left still counts, under their old id).
func _holder_of(rank: int) -> int:
	for peer: int in _players:
		if rank in _players[peer].keys:
			return peer
	return 0


## A client says who it is, once connected; the host gives back what it had when it left.
func request_hello(token: String, peer := 0) -> void:
	if _send(&"request_hello", [token], peer) or peer == 0:
		return
	if token.is_empty() or token in _token_of.values():
		return  # a second window on the same machine plays as somebody new
	_token_of[peer] = token
	if _saved.has(token):
		var p: PlayerState = _saved[token]
		_saved.erase(token)
		p.cooldown = 0.0
		p.has_pose = false
		_players[peer] = p  # the answer to this request (_state) carries it to the client
		if p.gun != 0:
			_world(&"gun_changed", [peer, p.gun])


## This machine's player token, made once and kept in user://.
func _token() -> String:
	if FileAccess.file_exists(TOKEN_FILE):
		return FileAccess.get_file_as_string(TOKEN_FILE).strip_edges()
	var t := "%x%x" % [randi(), Time.get_ticks_usec()]
	var f := FileAccess.open(TOKEN_FILE, FileAccess.WRITE)
	if f:
		f.store_string(t)
	return t


## Joiner: the heap and loose bullets as the host has them now (pile.gd snapshot()).
@rpc("authority", "call_remote", "reliable")
func _join(heap: Array, taken: Array) -> void:
	var node := get_tree().get_first_node_in_group("bullet_pile")
	if node and not heap.is_empty():
		node.restore(heap)
	for id: int in taken:
		_taken_loose[id] = true
		loose_taken.emit(id)


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


func _break_chain(p: PlayerState) -> void:
	p.combo = 0
	p.combo_left = 0.0
	p.weak_combo = 0
	p.weak_left = 0.0


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
	_state.rpc_id(peer, seq, p.carried, p.loaded, p.gold, p.levels, p.placing, p.infinite_ammo, p.keys, p.gun)


## Client: the host's word on our own state, after request `seq`.
@rpc("authority", "call_remote", "reliable")
func _state(seq: int, carried_: int, loaded_: int, gold_: int, levels: Dictionary, placing: bool, infinite: bool, keys: Array, gun: int) -> void:
	_acked_seq = seq
	if seq != _sent_seq:
		return  # newer requests are still on their way; their answer will have it all
	_claimed.clear()
	var p := player()
	p.keys.assign(keys)
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
	if p.gun != gun:  # a pick the host turned down, or the gun we had before rejoining
		p.gun = gun
		gun_changed.emit(local_peer(), gun)


## The local player's body, ~20 times a second (player.gd). Online it goes to the host, which
## keeps it (request_fire checks `from` against it) and passes it on to everyone else. Poses are
## unreliable on a channel of their own: a lost one is replaced 50 ms later anyway.
func send_pose(pos: Vector3, yaw: float, pitch: float, act: int, air: bool) -> void:
	var p := player()
	p.pos = pos
	p.has_pose = true
	if not Net.online or (Net.is_client and not _spawned):
		return  # a joiner stands on the host's spot until its own comes: bodies would collide
	var t := Time.get_ticks_msec() / 1000.0
	if multiplayer.is_server():
		_pose_of.rpc(local_peer(), t, pos, yaw, pitch, act, air)
	else:
		_pose.rpc_id(1, t, pos, yaw, pitch, act, air)


## Host: a client's pose.
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _pose(t: float, pos: Vector3, yaw: float, pitch: float, act: int, air: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var p := player(peer)
	p.pos = pos
	p.has_pose = true
	pose_received.emit(peer, t, pos, yaw, pitch, act, air)
	for id in multiplayer.get_peers():
		if id != peer:
			_pose_of.rpc_id(id, peer, t, pos, yaw, pitch, act, air)


## Client: someone else's pose, from the host.
@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _pose_of(peer: int, t: float, pos: Vector3, yaw: float, pitch: float, act: int, air: bool) -> void:
	if peer != local_peer():
		pose_received.emit(peer, t, pos, yaw, pitch, act, air)


## Client: the host's pick of our spawn point.
@rpc("authority", "call_remote", "reliable")
func _spawn(index: int) -> void:
	spawn_index = index
	spawn_assigned.emit(index)
	_spawned = true


## A world signal: emitted here, and on the host sent on to every client as well.
func _world(event: StringName, args: Array) -> void:
	callv(&"emit_signal", [event] + args)
	if Net.online and multiplayer.is_server():
		if NODE_ARG.has(event):
			var i: int = NODE_ARG[event]
			args[i] = args[i].get_path() if args[i] else NodePath()
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
		&"key_layout":
			key_seed = args[0]
		&"player_slots":
			slots = args[0]
		&"vault_changed":
			vault = args[0]
		&"gear_changed":
			gear_stock = args[0]
		&"gear_placed":
			if placed.size() <= args[0]:
				placed.resize(args[0] + 1)  # a joiner skips numbers taken down before it came
			placed[args[0]] = args.slice(1)
		&"gear_removed":
			if args[0] < placed.size():
				placed[args[0]] = null
		&"gun_changed":
			if args[0] == local_peer():
				return  # our own: predicted, and settled by the host's answer (_state)
			player(args[0]).gun = args[1]
	if NODE_ARG.has(event):
		# A node only the host has lands as null (spent shells are on no layer, so none yet).
		var i: int = NODE_ARG[event]
		var path: NodePath = args[i]
		args[i] = null if path.is_empty() else get_node_or_null(path)
		if event == &"target_cue" and args[i] == null:
			return
	callv(&"emit_signal", [event] + args)
