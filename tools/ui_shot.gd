extends SceneTree
## The screens in UiStyle, saved as PNGs to look at the spacing and alignment without playing:
## HUD, the "found one" note, the round picker, both Q tabs, placement mode with the pendulum's
## and the bank-shot plate's copies under the cursor.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/ui_shot.gd


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	await _frames(10)
	var p: Object = gs.player()
	p.gold = 1234
	gs.vault = 5678.0
	gs.gold_changed.emit(p.gold)
	gs.vault_changed.emit(gs.vault)
	gs.request_take_pistol()  # off the desk at the spawn: drawn at once
	var special: String = gs.SPECIALS.keys()[0]
	p.specials.append_array([special, special])
	gs.specials_changed.emit()  # the player's "found one" note comes up by itself
	await _shot("note", 30)
	await create_timer(5.0).timeout  # the note gone
	await _shot("hud", 1)
	for i in gs.quest_board.size():  # some way along each, the easy one done and waiting for C
		var id: String = gs.quest_board[i]
		if id != "":
			gs.quest_add(gs.QUESTS[id].kind, gs.quest_target(id) if i == 1 else maxi(1, gs.quest_target(id) * (i + 1) / 7), [gs.QUESTS[id].get("with", "")])
	await _shot("gorevler", 20)
	var board: Node = main.find_child("BoardMenu", true, false)
	board.open()
	await _shot("pano", 10)
	board.close()
	Input.action_press("reload")  # held: the picker opens
	await _shot("wheel", 60)
	Input.action_release("reload")
	var menu: Node = main.find_child("UpgradeMenu", true, false)
	p.levels["carry"] = 3  # some bought, the gold reaching some of the rest
	p.levels["combo_cap"] = 1
	p.gold = 70
	gs.vault = 160.0
	gs.gold_changed.emit(p.gold)
	gs.vault_changed.emit(gs.vault)
	menu.toggle()
	await _shot("q_kisisel", 10)
	menu._cards["carry"].button.pressed.emit()  # the moment of buying
	await _shot("q_al", 8)
	menu._show_tab(1)
	await _shot("q_techizat", 30)
	menu.toggle()
	gs.gear_stock = {"pendulum": 2, "ricochet": 1, "popper": 1}
	gs.gear_changed.emit(gs.gear_stock)
	gs.request_toggle_placing()
	var placement: Node = main.get_node("Placed")
	for id in ["pendulum", "ricochet"]:
		placement.focus(id)
		Input.warp_mouse(Vector2(560, 420))
		await _shot("place_" + id, 40)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name_: String, wait: int) -> void:
	await _frames(wait)
	var path := "user://ui_%s.png" % name_
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
