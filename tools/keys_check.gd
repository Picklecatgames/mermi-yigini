extends SceneTree
## Headless check for the crate keys (scripts/key_cache.gd): all twelve buried, costlier by rank,
## each tier costing at least its share of the heap, and digging straight down onto a key with
## the real heap simulation needs at least the bound key_cost() promises. Then it is picked up.
##   Godot.exe --headless --path . -s res://tools/keys_check.gd

const DIG_CHUNK := 2000


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var keys: Node3D = main.get_node("Keys")
	var pile: Node3D = main.get_node("Pile")
	for i in 3:
		await physics_frame
	var ranks: Array = gs.key_states.keys()
	assert(ranks.size() == keys.KEYS.size(), "every key buried, got %d" % ranks.size())
	var prev := 0
	print("rank  depth   min pieces   at")
	for rank in range(1, keys.KEYS.size() + 1):
		var d: float = keys.key_depth(rank)
		var p: Vector3 = keys.key_position(rank)
		var need: int = keys.key_cost(rank)
		print("%4d  %.2f m  %11d  %s" % [rank, d, need, p])
		assert(need > prev, "rank %d costs more than rank %d" % [rank, rank - 1])
		prev = need
		assert(p.y - pile.global_position.y >= keys.FLOOR_GAP - 0.001, "key %d sits above the floor" % rank)
		assert(gs.key_states[rank] == gs.KeyState.BURIED)
		match keys.KEYS[rank - 1][1]:
			0: assert(need >= 20 and need <= 800, "a common key is a hand dig")
			1: assert(need >= 50_000, "a rare key needs belts")
			2: assert(need >= 1_000_000, "a legendary key needs late automation")
	# Dig straight down onto every common key and the shallowest rare one.
	for rank in [1, 2, 3, 4, 5]:
		var used: int = await _dig_to(gs, keys, pile, rank)
		var need: int = keys.key_cost(rank)
		print("key %d: revealed after %d rounds dug straight onto it (bound %d)" % [rank, used, need])
		assert(gs.key_states[rank] == gs.KeyState.EXPOSED, "digging reveals key %d" % rank)
		assert(used >= need * 0.8, "no cheaper than the crater bound")
	# Walk onto key 1 and it is yours.
	var pl: Node3D = main.get_node("Player")
	pl.global_position = keys.key_position(1)
	await create_timer(0.5).timeout
	assert(gs.key_states[1] == gs.KeyState.TAKEN and gs.player().keys.has(1), "walking over a key picks it up")
	print("keys_check OK")
	quit()


func _dig_to(gs: Node, keys: Node3D, pile: Node3D, rank: int) -> int:
	var p: Vector3 = keys.key_position(rank)
	var used := 0
	while gs.key_states[rank] == gs.KeyState.BURIED and used < 2_000_000:
		var at := Vector3(p.x, pile.surface_y(p), p.z)
		used += gs.request_take_bullets(DIG_CHUNK if used >= 20_000 else 50, at)
		for f in 400:  # until the dig is done and the slides have stopped
			await physics_frame
			if pile._digs.is_empty() and not pile._any_active:
				break
		for f in 15:  # the key check runs every 0.2 s
			await physics_frame
	return used
