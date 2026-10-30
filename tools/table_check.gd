extends SceneTree
## Headless check of the start (2026-10-28): we stand between the heap and the railing facing the
## heap, the desk with the pistol in front of us; E on it draws the pistol empty and the pistol goes;
## the desk stays, for mending the railing (tools/fence_check.gd). Then the heap's sides: walking into it climbs, no snagging (player.gd floor_max_angle).
##   Godot.exe --headless --path . -s res://tools/table_check.gd

const HEAP := Vector3(-9.0, 0, 0)

var _fail := false


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	await process_frame
	gs.start_quests()
	var me: CharacterBody3D = main.get_node("Player")
	for i in 10:
		await physics_frame
	var ahead := -me.global_basis.z
	_ok(me.global_position.x > 2.0 and me.global_position.x < gs.FIRING_LINE_X, "spawn between the heap and the railing (%s)" % me.global_position)
	_ok(absf(me.global_position.y) < 0.05, "standing on the floor, the arena not shifted under the heap")
	_ok(ahead.dot((HEAP - me.global_position).normalized()) > 0.95, "facing the heap")
	var table: Node3D = get_first_node_in_group("gun_table")
	_ok(table != null and (table.global_position - me.global_position).dot(ahead) > 0.5, "the desk is in front of us")
	_ok(gs.quest_board[0] == "t00", "the first warmup quest is the pistol")
	gs.request_select_gun(1)
	_ok(gs.player().gun == 0, "the pistol can't be drawn before it is taken")
	# Look down at the desk and press E.
	var d: Vector3 = table.global_position + Vector3.UP * 0.8 - me._camera.global_position
	me._yaw = atan2(-d.x, -d.z)
	me._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 3:
		await physics_frame
	_ok(me._table_hint.visible, "the E hint shows on the desk")
	var e := InputEventAction.new()
	e.action = "pick_up"
	e.pressed = true
	me._unhandled_input(e)
	await process_frame
	_ok(gs.player().gun == 1 and gs.loaded == 0, "the pistol is in hand, empty")
	for i in 30:  # the fists go away first
		if me._viewmodel.clip == "draw":
			break
		await create_timer(0.05).timeout
	_ok(me._viewmodel.clip == "draw", "drawn with its animation (%s)" % me._viewmodel.clip)
	_ok("t00" in gs.quests_done and gs.quest_board[0] == "t01", "the warmup moves on to buying a dummy")
	_ok(me._hud._subtitle.visible, "the heap's line is said at the bottom")
	await create_timer(2.5).timeout
	_ok(is_instance_valid(table) and not is_instance_valid(table._gun), "the pistol is gone, the desk stays")
	_ok(not me._table_hint.visible and not me._repair_hint.visible, "no hint on the desk with the railing whole")
	_ok((-me._camera.global_basis.z).dot((HEAP - me._camera.global_position).normalized()) > 0.9, "the view turned to the heap")
	await create_timer(4.0).timeout
	_ok(gs.unlocked("workbench") and not me._hud._q.visible, "the bench is open (no Q: everything is bought there)")
	_ok(not me._hud._sheet.visible, "the quest list waits for the board")
	# The gear at the bench, only the straw dummy open; the gold buys exactly it, then it goes up.
	_ok(gs.gold == gs.GEAR.dummy.cost, "we start with a dummy's price ($%d)" % gs.gold)
	_ok(not gs.request_buy_gear("popper"), "the rest of the gear is locked")
	_ok(gs.request_buy_gear("dummy") and gs.gold == 0 and gs.quest_board[0] == "t02", "the dummy is bought, on to placing it")
	_ok(gs.request_place_gear("dummy", Vector3(23, 0, 0), 0.0) and gs.quest_board[0] == "t03", "placed, on to the heap")
	if gs.player().placing:
		gs.request_toggle_placing()
	# The heap: from its foot, walk straight in for 3 s.
	me.global_position = HEAP + Vector3(9.5, 0.2, 0.0)
	me._yaw = PI / 2.0  # looking -x, at the middle
	me._pitch = 0.0
	me.reset_physics_interpolation()
	Input.action_press("move_forward")
	await create_timer(3.0).timeout
	Input.action_release("move_forward")
	_ok(me.global_position.y > 2.0, "walking into the heap climbs it (%.1f m up, %.1f m in)" % [me.global_position.y, 9.5 - (me.global_position.x - HEAP.x)])
	print("table_check ", "FAILED" if _fail else "OK")
	quit(1 if _fail else 0)


func _ok(cond: bool, what: String) -> void:
	print("ok   " if cond else "FAIL ", what)
	_fail = _fail or not cond
