extends Node
## All game state lives here. Player actions are request_* commands:
## solo they run directly, in co-op they will be routed to the host.

signal pile_changed(count: int)
signal carried_changed(count: int)
## Where bullets left the pile, so the heap can dig there (hands, robots, belts).
signal bullets_taken(at: Vector3, count: int)
## Carried bullets thrown back out; they land as loose spill and count as pile again.
## They get ids first_id .. first_id + count - 1.
signal bullets_thrown(from: Vector3, dir: Vector3, count: int, first_id: int)
## A loose bullet (spilled or thrown) was picked up, by id; every peer removes the same one.
signal loose_taken(id: int)
signal upgraded(id: String, level: int)

const PILE_START := 100_000_000
## Loose bullet ids: the baked spill is 0 .. its size - 1, thrown bullets count up from here.
const THROWN_ID_START := 1 << 20

## Upgrade tree: value per level (level 0 = start) and gold cost to reach each next level.
# ponytail: placeholder numbers until the 60-minute balance pass.
const UPGRADES := {
	"carry_capacity": {"values": [1, 2, 3, 6], "costs": [10, 50, 200]},
}

var pile: int = PILE_START
# ponytail: single local player; becomes per-peer when co-op lands.
var carried := 0
var _next_loose_id := THROWN_ID_START
# ponytail: grows by one per loose grab; the save system can prune ids no longer in the world.
var _taken_loose := {}
var gold := 0
var upgrade_levels := {"carry_capacity": 0}
# ponytail: test override while there is nothing to spend bullets on; 0 = upgrades decide.
var debug_carry := 100
var carry_capacity: int:
	get: return debug_carry if debug_carry > 0 else upgrade_value("carry_capacity")


func upgrade_value(id: String) -> int:
	return UPGRADES[id].values[upgrade_levels[id]]


## Buys the next level of an upgrade if there is one and gold covers it.
func request_buy_upgrade(id: String) -> bool:
	var level: int = upgrade_levels[id]
	var costs: Array = UPGRADES[id].costs
	if level >= costs.size() or gold < costs[level]:
		return false
	gold -= costs[level]
	upgrade_levels[id] = level + 1
	upgraded.emit(id, level + 1)
	return true


## Takes up to `count` bullets off the pile at world point `at`, returns how many were taken.
func request_take_bullets(count: int, at: Vector3) -> int:
	var taken: int = clampi(count, 0, pile)
	if taken > 0:
		pile -= taken
		pile_changed.emit(pile)
		bullets_taken.emit(at, taken)
	return taken


## Player grabs bullets at `at` by hand, up to carry capacity and at most `limit`.
func request_pick_up(at: Vector3, limit := 1 << 30) -> int:
	var taken := request_take_bullets(mini(carry_capacity - carried, limit), at)
	if taken > 0:
		carried += taken
		carried_changed.emit(carried)
	return taken


## Player picks up the loose bullet `id`. The first request wins; later ones for the same
## bullet (another player, same frame) get nothing.
func request_pick_up_loose(id: int) -> int:
	if _taken_loose.has(id) or carried >= carry_capacity or pile <= 0:
		return 0
	_taken_loose[id] = true
	pile -= 1
	carried += 1
	pile_changed.emit(pile)
	carried_changed.emit(carried)
	loose_taken.emit(id)
	return 1


## Player throws everything they carry from `from` toward `dir`; it goes back to the pile.
func request_throw(from: Vector3, dir: Vector3) -> int:
	var n := carried
	if n == 0:
		return 0
	carried = 0
	pile += n
	var first_id := _next_loose_id
	_next_loose_id += n
	carried_changed.emit(carried)
	pile_changed.emit(pile)
	bullets_thrown.emit(from, dir, n, first_id)
	return n
