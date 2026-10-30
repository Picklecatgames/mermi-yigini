extends SceneTree
## Headless check for the hopper and the press (GameState request_melt, request_upgrade_station,
## request_press) and their screens (scripts/melter_menu.gd, press_menu.gd):
##   Godot.exe --headless --path . -s res://tools/melter_check.gd
## Shut till their quests; the hand goes in whole; it melts at its level's rate into brass, quests
## counting; upgrades take the gold; the press turns brass into rounds at its rate, its next round
## shut till its level; both refuse anyone away from them. The screens build and fill.

var _failed := false
var _gs: Node


func _initialize() -> void:
	_gs = root.get_node("GameState")
	await process_frame
	var p = _gs.player()
	p.pos = _gs.MELTER_POS + Vector3(0, 0, -1.0)
	p.has_pose = true
	p.carried = 10
	_ok(_gs.request_melt() == 0 and p.carried == 10, "no hopper before its quest")
	_open("melter")
	_open("hand_press")

	p.pos = _gs.MELTER_POS + Vector3(0, 0, -5.0)
	_ok(_gs.request_melt() == 0, "too far from the hopper")
	p.pos = _gs.MELTER_POS + Vector3(0, 0, -1.0)
	_ok(_gs.request_melt() == 10 and p.carried == 0 and _gs.melt_bin == 10, "the whole hand goes in")
	_gs._process(1.0)
	_ok(_gs.melt_bin == 8 and _gs.brass == 2, "two a second at the start (%d, %d)" % [_gs.melt_bin, _gs.brass])
	_gs._process(10.0)
	_ok(_gs.melt_bin == 0 and _gs.brass == 10, "melts to the last round, no further")

	p.gold = 100
	_ok(not _gs.request_upgrade_station("melter") and _gs.melt_level == 0, "no faster hopper without the gold")
	p.gold = _gs.MELT_COSTS[0] + 5
	_ok(_gs.request_upgrade_station("melter") and _gs.melt_level == 1 and p.gold == 5, "the next speed paid alone from one's gold")
	p.carried = 8
	_gs.request_melt()
	_gs._process(1.0)
	_ok(_gs.brass == 14, "faster: %d" % _gs.brass)

	p.pos = _gs.PRESS_POS + Vector3(0, 0, -1.0)
	_ok(_gs.request_press("electric", 1) == 0, "the next round is shut at level 0")
	_ok(_gs.request_press("clone", 100) == 7 and _gs.brass == 0 and p.rounds.get("clone") == 7, "two brass a clone, as many as it makes")
	_ok(_gs.request_press("clone", 1) == 0, "nothing without brass")
	p.pos = _gs.PRESS_POS + Vector3(0, 0, -5.0)
	_gs.brass = 10
	_ok(_gs.request_press("clone", 1) == 0, "too far from the press")
	p.gold = _gs.PRESS_COSTS[0]
	_ok(_gs.request_upgrade_station("press") and _gs.press_level == 1, "the press's next level")

	# The screens: built under a body as player.gd does, opened and filled.
	var body := Node3D.new()
	root.add_child(body)
	body.global_position = _gs.PRESS_POS + Vector3(0, 0, -1.0)
	p.pos = body.global_position
	for script: String in ["res://scripts/melter_menu.gd", "res://scripts/press_menu.gd"]:
		var menu: CanvasLayer = load(script).new()
		body.add_child(menu)
		await process_frame
		menu.open()
		await process_frame
		_ok(menu.visible, "%s opens" % script.get_file())
		menu.close()
	var press_menu: CanvasLayer = body.get_child(1)
	_gs.brass = 30
	press_menu.open()
	press_menu._picked = "electric"
	press_menu._amount = 99
	press_menu._refresh()
	_ok(press_menu._count.text == "5" and press_menu._in.text == "30" and press_menu._out.text == "5", "the press shows 30 brass -> 5 electric")
	press_menu._press()
	_ok(p.rounds.get("electric") == 5 and _gs.brass == 0, "Üret makes them")

	print("melter_check: ", "FAILED" if _failed else "ok")
	quit(1 if _failed else 0)


func _open(what: String) -> void:
	for id: String in _gs.QUESTS:
		if _gs.QUESTS[id].get("unlock") == what:
			_gs.quests_done.append(id)
			return


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_failed = true
		print("FAIL: ", what)
