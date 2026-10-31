extends SceneTree
## Headless check for the balance panel (scripts/cheat_menu.gd):
##   Godot.exe --headless --path . -s res://tools/cheat_check.gd
## Solo: F9 opens it, the buttons add money, set the heap and the game speed, open every quest's
## unlock, the rates read per game minute.


func _initialize() -> void:
	for i in 3:
		await process_frame
	var gs: Node = root.get_node("GameState")
	var panel: CanvasLayer
	for c in root.get_node("Net").get_children():
		if c.has_method("rates"):
			panel = c
	if not _ok(panel != null and not panel.visible, "Net adds the panel, closed"): return
	var f9 := InputEventKey.new()
	f9.keycode = KEY_F9
	f9.pressed = true
	root.push_input(f9)
	if not _ok(panel.visible, "F9 opens it"): return

	var gold: int = gs.gold
	gs.vault = 0.0  # it starts with START_GOLD
	panel.add_gold(1_000)
	panel.add_vault(100_000)
	if not _ok(gs.gold == gold + 1_000 and is_equal_approx(gs.vault, 100_000.0), "money goes to the player and the vault"): return
	panel.set_pile(50_000_000)
	if not _ok(gs.pile == 50_000_000, "the heap jumps to 50M"): return
	panel.set_speed(10.0)
	if not _ok(Engine.time_scale == 10.0, "x10 speed"): return
	panel.set_speed(1.0)
	panel.open_all()
	if not _ok(gs.player().has_pistol and gs.unlocked("workbench") and gs.unlocked("melter") and gs.unlocked("hand_press") 			and gs.quest_board[0] == "", "every main quest done, all it opens open"): return

	# Two game seconds: +$20, +$2 vault, 300 rounds gone -> per minute x30.
	panel.reset_clock()
	for s in 2:
		gs.player().gold += 10
		gs.vault += 1.0
		gs.pile -= 150
		panel._sample()
	var r: Vector3 = panel.rates()
	if not _ok(r.is_equal_approx(Vector3(600, 60, -9_000)), "rates per game minute (%s)" % r): return
	print("cheat_check: OK")
	quit(0)


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		printerr("cheat_check FAIL: ", what)
		quit(1)
	return cond
