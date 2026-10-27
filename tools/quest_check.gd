extends SceneTree
## Headless check for the quest board (GameState QUESTS):
##   Godot.exe --headless --path . -s res://tools/quest_check.gd
## Five slots of the right tiers, the main chain in order, `with` and `needs` respected, peak kinds,
## rewards, targets growing with the team, and every quest in the pool reachable. Co-op
## mirroring over a real connection is in tools/net_check.gd; here the client side is _event fed
## the host's own events.

var _failed := false


func _initialize() -> void:
	var gs: Node = root.get_node("GameState")
	await process_frame
	seed(7)
	gs.start_quests()
	var board: Array = gs.quest_board
	_ok(board.size() == gs.QUEST_SLOTS.size(), "five slots")
	for i in board.size():
		_ok(board[i] != "" and gs.QUESTS[board[i]].tier == gs.QUEST_SLOTS[i], "slot %d holds a %s quest" % [i, gs.QUEST_SLOTS[i]])
		_ok(board.count(board[i]) == 1, "no quest pinned twice")
	var mains: Array = gs.QUESTS.keys().filter(func(id: String) -> bool: return gs.QUESTS[id].tier == "main")
	_ok(board[0] == mains[0], "the main slot starts the chain")
	for id: String in gs.QUESTS:
		if gs.QUESTS[id].has("needs"):
			_ok(gs.QUESTS.values().any(func(q: Dictionary) -> bool: return q.get("unlock") == gs.QUESTS[id].needs),
				"%s needs something a quest unlocks" % id)

	# Progress, and the main quest finishing: its unlock is in, the chain's next one is pinned.
	var done := []
	gs.quest_done.connect(func(id: String, gold: int) -> void: done.append([id, gold]))
	var m: String = board[0]
	var q: Dictionary = gs.QUESTS[m]
	gs.quest_add(q.kind, 1, [q.get("with", "")])
	_ok(gs.quest_progress[m] == 1, "progress counts")
	gs.quest_add(q.kind, 1000, ["something_else"])
	_ok(not q.has("with") or gs.quest_progress[m] == 1, "a quest with `with` ignores other guns and rounds")
	gs.quest_add(q.kind, gs.quest_target(m), [q.get("with", "")])
	_ok(m in gs.quests_done and done.size() >= 1 and done[0][0] == m, "the main quest finishes")
	_ok(not q.has("unlock") or gs.unlocked(q.unlock), "its unlock is in")
	_ok(gs.quest_board[0] == mains[1], "the main slot moves on to the next one")

	# Peak kinds keep the best value, and gold rewards reach the player.
	for id: String in gs.quest_board:
		if id != "" and gs.QUESTS[id].kind in gs.QUEST_PEAK_KINDS:
			var t: int = gs.quest_target(id)
			gs.quest_add(gs.QUESTS[id].kind, t - 1)
			gs.quest_add(gs.QUESTS[id].kind, 1)
			_ok(gs.quest_progress[id] == t - 1, "a peak kind keeps its best, it doesn't add up")
	var gold_before: int = gs.gold
	var rewarded := 0
	for id: String in gs.quest_board.duplicate():
		if id != "" and gs.QUESTS[id].reward.has("gold"):
			rewarded += gs.QUESTS[id].reward.gold
			gs.quest_add(gs.QUESTS[id].kind, gs.quest_target(id), [gs.QUESTS[id].get("with", "")])
	_ok(gs.gold - gold_before >= rewarded, "gold rewards are paid ($%d)" % (gs.gold - gold_before))

	# Targets grow with the team; fixed kinds don't.
	var one := {}
	for id: String in gs.QUESTS:
		one[id] = gs.quest_target(id)
	gs.slots = {1: 0, 2: 1, 3: 2, 4: 3}
	for id: String in gs.QUESTS:
		var want: int = one[id] if gs.QUESTS[id].kind in gs.QUEST_FIXED_KINDS else ceili(gs.QUESTS[id].target * (1.0 + gs.QUEST_SCALE * 3))
		_ok(gs.quest_target(id) == want, "%s: %d for four" % [id, want])
	gs.slots = {}

	# A client mirrors the host's board from the events alone.
	var host_board: Array = gs.quest_board.duplicate()
	var host_progress: Dictionary = gs.quest_progress.duplicate()
	var host_done: Array = gs.quests_done.duplicate()
	gs.quest_board = []
	gs.quest_progress = {}
	gs.quests_done.clear()
	for id: String in host_done:
		gs._event(&"quest_done", [id, 0])
	gs._event(&"quests_changed", [host_board, host_progress])
	_ok(gs.quest_board == host_board and gs.quest_progress == host_progress and Array(gs.quests_done) == host_done, "the events carry the whole board")

	# The hooks: a grab, a shot, a bonus and a key each count on a quest of their kind.
	for hook: Array in [["bullets_carried", func() -> void: gs.request_pick_up(Vector3.ZERO, 1)],
			["bullets_fired", func() -> void:
				gs.player().gun = 1
				gs.player().loaded = 1
				gs.player().cooldown = 0.0
				gs.request_fire(Vector3(0, 50, 0), Vector3.UP)],  # into the sky: a miss still counts as fired
			["gold_earned", func() -> void: gs.pay_bonus(gs.local_peer(), null, 1)],
			["key_found", func() -> void:
				gs.key_states[1] = gs.KeyState.EXPOSED
				gs.request_take_key(1)]]:
		var id := ""
		for k: String in gs.QUESTS:
			if gs.QUESTS[k].kind == hook[0] and (not gs.QUESTS[k].has("with") or gs.QUESTS[k].with == "deagle") and k not in gs.quests_done:
				id = k
		if id == "":
			continue  # nothing of that kind left in the pool
		if id not in gs.quest_board:
			gs.quest_board[1] = id
		gs.quest_progress[id] = 0
		hook[1].call()
		_ok(gs.quest_progress.get(id, 0) == 1 or id in gs.quests_done, "%s counts on %s (%s)" % [hook[0], id, gs.quest_progress.get(id)])

	# Every quest is reachable: keep finishing whatever is pinned until the board runs dry.
	gs.start_quests()
	for guard in 1000:
		var pinned: Array = gs.quest_board.filter(func(id: String) -> bool: return id != "")
		if pinned.is_empty():
			break
		for id: String in pinned:
			if id in gs.quest_board:
				gs.quest_add(gs.QUESTS[id].kind, gs.quest_target(id), [gs.QUESTS[id].get("with", "")])
	_ok(gs.quests_done.size() == gs.QUESTS.size(), "all %d quests can be finished (%d were)" % [gs.QUESTS.size(), gs.quests_done.size()])
	var chain: Array = Array(gs.quests_done).filter(func(id: String) -> bool: return gs.QUESTS[id].tier == "main")
	_ok(chain == mains, "the main chain finished in its order")
	if not _failed:
		print("quest_check OK")
	quit(1 if _failed else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_failed = true
		printerr("quest_check FAIL: ", what)
