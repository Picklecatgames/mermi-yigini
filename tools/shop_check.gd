extends SceneTree
## Headless check for the Q workshop (scripts/upgrade_menu.gd) and gear bought from the vault:
##   Godot.exe --headless --path . -s res://tools/shop_check.gd
## Solo: the buttons on both tabs buy what they say, cost what they say, and stay shut when the
## money is short. (Co-op buying goes through request_buy_gear like every other request.)


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	for i in 3:
		await physics_frame
	gs.player().gold = 0  # it starts with a dummy's price
	gs.quest_board.fill("")  # past the warmup: all the gear open
	var menu: Node = main.find_child("UpgradeMenu", true, false)
	menu.toggle()
	if not _ok(menu.visible and menu._tab == 0, "Q opens on the player's own tab"): return
	var title: String = menu._tabs[0].text
	if not _ok(title == gs.display_name(), "the first tab carries the player's name (%s)" % title): return

	# Own upgrades: short of money, the button is shut; with it, one press buys one level.
	var carry: Button = menu._cards["carry"].button
	if not _ok(carry.disabled, "carry is shut with no gold"): return
	gs.player().gold = 10
	gs.gold_changed.emit(10)
	if not _ok(not carry.disabled and carry.text == "$6", "carry opens at $6 (%s)" % carry.text): return
	carry.pressed.emit()
	if not _ok(gs.player().levels["carry"] == 1 and gs.gold == 4, "one level bought, $6 paid"): return
	if not _ok(menu._cards["carry"].button.text == "$15" and menu._cards["carry"].button.disabled, "the next level's price, out of reach (%s)" % menu._cards["carry"].button.text): return

	# Gear: alone there is no team vault, it comes out of the player's own gold.
	menu._show_tab(1)
	if not _ok(menu._pages[1].visible and not menu._pages[0].visible, "the gear tab shows"): return
	var dummy: Button = menu._cards["dummy"].button
	var star: Button = menu._cards["texas_star"].button
	gs.player().gold = 0
	gs.gold_changed.emit(0)
	if not _ok(dummy.disabled, "no gear with no gold"): return
	gs.player().gold = 50
	gs.gold_changed.emit(50)
	if not _ok(not dummy.disabled and star.disabled, "$50 buys a dummy, not a Texas Star"): return
	dummy.pressed.emit()
	dummy.pressed.emit()
	if not _ok(gs.gear_stock.get("dummy") == 2 and gs.player().gold == 10, "two dummies in stock, $40 out of the player's gold"): return
	if not _ok(dummy.disabled and menu._cards["dummy"].stock.text == "×2", "button shuts, the card says 2 in stock"): return
	if not _ok(not gs.request_buy_gear("texas_star") and not gs.request_buy_gear("nonsense"), "no buying past the vault or off the list"): return
	# Put one up, take it down: it goes back to the stock, and its number is not reused.
	if not _ok(gs.request_place_gear("dummy", Vector3(22, 0, 15), -PI / 2) and gs.gear_stock.dummy == 1, "a dummy goes up from the stock"): return
	var placed: Node = main.get_node("Placed")
	if not _ok(placed.has_node("Gear_0"), "it stands as Gear_0"): return
	if not _ok(gs.request_remove_gear(0) and gs.gear_stock.dummy == 2 and not gs.request_remove_gear(0), "taken down once, back in the stock"): return
	await process_frame
	if not _ok(not placed.has_node("Gear_0"), "and gone from the floor"): return
	if not _ok(gs.request_place_gear("dummy", Vector3(22, 0, 15), -PI / 2) and placed.has_node("Gear_1"), "the next one is Gear_1"): return

	# Every card, hovered (x1.02), stays inside the panel and the page's clip on small windows too.
	var panel: Control = menu._center.get_child(0)
	for res in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1024, 600)]:
		root.size = res
		for tab in 2:
			menu._show_tab(tab)
			for i in 3:
				await process_frame
			var page: Control = menu._pages[tab]
			var clip := page.get_global_rect().grow(0.5)
			var screen := root.get_visible_rect()
			if not _ok(screen.size == Vector2(res) and screen.encloses(panel.get_global_rect()), "%s: the panel fits the screen (%s)" % [res, panel.get_global_rect()]): return
			if not _ok(panel.get_global_rect().grow(0.5).encloses(page.get_global_rect()), "%s tab %d: the page's clip stays in the panel" % [res, tab]): return
			for id in menu._cards:
				var card: Control = menu._cards[id].card
				if not card.is_visible_in_tree():
					continue
				var r := card.get_global_rect()
				var hovered := r.grow_individual(r.size.x * 0.01, 0, r.size.x * 0.01, 0)
				if not _ok(hovered.position.x >= clip.position.x and hovered.end.x <= clip.end.x, "%s: %s hovered fits across (%s in %s)" % [res, id, hovered, clip]): return
	if menu.visible:
		menu.toggle()
	print("shop_check OK")
	quit()


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		printerr("shop_check FAIL: ", what)
		quit(1)
	return cond
