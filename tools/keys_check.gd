extends SceneTree
## Headless check for the crate keys (scripts/key_cache.gd): all twelve buried, costlier by rank,
## each tier costing at least its share of the heap, and digging straight down onto a common key with
## the real heap simulation brings it out. Then it is picked up. What digging costs is printed, not
## held to key_cost(): that bound (pile.gd min_take) takes the heap to stand no steeper than
## LOCK_SLOPE, and the scrap mountains do, so on them a key can come out far cheaper (2026-11-05: 150
## pieces for a bound of 508). The rare ones' digs (80,000 pieces and up) went with it: over 5 minutes.
##   Godot.exe --headless --path . -s res://tools/keys_check.gd

const DIG_CHUNK := 2000

var _fails := 0


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var keys: Node3D = main.get_node("Keys")
	var pile: Node3D = main.get_node("Pile")
	for i in 3:
		await physics_frame
	var ranks: Array = gs.key_states.keys()
	_expect(ranks.size() == keys.KEYS.size(), "every key buried, got %d" % ranks.size())
	var prev := 0
	print("rank  depth   min pieces   at")
	for rank in range(1, keys.KEYS.size() + 1):
		var d: float = keys.key_depth(rank)
		var p: Vector3 = keys.key_position(rank)
		var need: int = keys.key_cost(rank)
		print("%4d  %.2f m  %11d  %s" % [rank, d, need, p])
		_expect(need > prev, "rank %d costs more than rank %d" % [rank, rank - 1])
		prev = need
		_expect(p.y - pile.global_position.y >= keys.FLOOR_GAP - 0.001, "key %d sits above the floor" % rank)
		_expect(gs.key_states[rank] == gs.KeyState.BURIED, "key %d buried" % rank)
		match keys.KEYS[rank - 1][1]:
			0: _expect(need >= 20 and need <= 800, "a common key is a hand dig (%d)" % need)
			1: _expect(need >= 50_000, "a rare key needs belts (%d)" % need)
			2: _expect(need >= 1_000_000, "a legendary key needs late automation (%d)" % need)
	# Dig straight down onto every common key.
	for rank in [1, 2, 3, 4]:
		var used: int = await _dig_to(gs, keys, pile, rank)
		var need: int = keys.key_cost(rank)
		print("key %d: revealed after %d rounds dug straight onto it (bound %d)" % [rank, used, need])
		_expect(gs.key_states[rank] == gs.KeyState.EXPOSED, "digging reveals key %d" % rank)
	# Walk onto key 1 and it is yours.
	var pl: Node3D = main.get_node("Player")
	pl.global_position = keys.key_position(1)
	await create_timer(0.5).timeout
	_expect(gs.key_states[1] == gs.KeyState.TAKEN and gs.player().keys.has(1), "walking over a key picks it up")
	print("keys_check OK" if _fails == 0 else "keys_check FAILED (%d)" % _fails)
	quit(1 if _fails else 0)


## (Not assert: one that fails stops the coroutine and the check never quits.)
func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("keys_check FAIL: ", what)


func _dig_to(gs: Node, keys: Node3D, pile: Node3D, rank: int) -> int:
	var p: Vector3 = keys.key_position(rank)
	var used := 0
	while gs.key_states[rank] == gs.KeyState.BURIED and used < 2_000_000:
		var at := Vector3(p.x, pile.surface_y(p), p.z)
		# 50 at a time took the check past five minutes: the common keys need tens of thousands.
		used += gs.request_take_bullets(DIG_CHUNK if used >= 20_000 else (500 if used >= 500 else 50), at)
		for f in 400:  # until the dig is done and the slides have stopped
			await physics_frame
			if pile._digs.is_empty() and not pile._any_active:
				break
		for f in 15:  # the key check runs every 0.2 s
			await physics_frame
	return used
