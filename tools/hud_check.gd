extends SceneTree
## Headless check for the HUD's layout (scripts/hud.gd): it covers the whole window however the
## window is resized, its corners stay in the corners, and past 1080p it grows with the screen.
## (It once froze at the window's starting size and sat in the top left of a full screen.)
##   Godot.exe --headless --path . -s res://tools/hud_check.gd

func _initialize() -> void:
	var screen := SubViewport.new()  # the headless window won't resize; a SubViewport stands in
	screen.size = Vector2i(1152, 648)
	root.add_child(screen)
	var hud: Control = load("res://scripts/hud.gd").new()
	screen.add_child(hud)
	for s: Vector2i in [Vector2i(1152, 648), Vector2i(2560, 1440), Vector2i(1280, 720), Vector2i(3840, 2160)]:
		screen.size = s
		await process_frame
		await process_frame
		var k := hud.scale.x
		assert(is_equal_approx(k, maxf(1.0, s.y / 1080.0)), "scale %.2f at %s" % [k, s])
		assert((hud.size * k).is_equal_approx(Vector2(s)), "covers %s, got %s" % [s, hud.size * k])
		var gold: Control = hud._gold.get_parent().get_parent()
		var right_gap := s.x - (gold.position.x + gold.size.x) * k
		assert(absf(right_gap - hud.MARGIN.x * k) < 2.0, "gold sits on the right edge at %s (gap %.0f)" % [s, right_gap])
		var heap: Control = hud._heap.get_parent()
		var mid := (heap.position.x + heap.size.x * 0.5) * k
		assert(absf(mid - s.x * 0.5) < 2.0, "heap is centred at %s (%.0f)" % [s, mid])
		var quests: Control = hud._quests
		var quests_gap: float = s.x - (quests.get_parent().position.x + quests.position.x + quests.size.x) * k
		assert(absf(quests_gap - hud.MARGIN.x * k) < 2.0, "quests sit on the right edge at %s (gap %.0f)" % [s, quests_gap])
		print("%s ok  scale %.2f" % [s, k])
	# The warmup: its key under the main quest, the hand and gold hidden until learnt.
	var gs: Node = root.get_node("GameState")
	gs.start_quests()
	await process_frame
	assert(gs.QUESTS[gs.quest_board[0]].get("warmup", false) and hud._hint.visible, "the warmup's key is shown")
	assert(not hud._left.visible and not hud._right.visible, "hand and gold wait during the warmup")
	while gs.QUESTS[gs.quest_board[0]].get("warmup", false):
		var w: String = gs.quest_board[0]
		gs.quest_add(gs.QUESTS[w].kind, gs.quest_target(w))
		if gs.QUESTS[w].kind == "board_claim":
			gs.request_claim_quests()
	await create_timer(hud.CLOSE_TIME + 0.6).timeout
	assert(hud._left.visible and hud._right.visible and not hud._hint.visible, "the warmup over, the whole screen")
	# A done quest lights up and waits to be claimed at the board; claimed, its card folds away and
	# the next comes in.
	var first: String = gs.quest_board[0]
	assert(hud._cards[0].id == first and not hud._claim.visible, "the main quest's card, nothing to claim")
	gs.quest_add(gs.QUESTS[first].kind, gs.quest_target(first), [gs.QUESTS[first].get("with", "")])
	var card: Dictionary = hud._cards[0]
	assert(card.tick.visible and card.pulse != null and hud._claim.visible, "done: ticked, pulsing, C offered")
	assert(card.share.text == hud._reward_text(first), "its reward in place of the share (%s)" % card.share.text)
	gs.request_claim_quests()
	assert(card.has("folding") and card.tick.visible, "claimed: the ticked card folds")
	await create_timer(hud.CLOSE_TIME + 0.6).timeout
	assert(card.id == gs.quest_board[0] and card.id != first and not card.has("folding") and not hud._claim.visible, "the next main quest came in")
	print("quests ok: %s -> %s" % [first, card.id])
	print("hud_check ok")
	quit()
