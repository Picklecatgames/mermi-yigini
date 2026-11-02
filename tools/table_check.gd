extends SceneTree
## Headless check of the start (2026-10-28): we stand between the heap and the railing facing the
## heap, the desk with the pistol in front of us; E on it draws the pistol empty and the desk fades
## out. Then the heap: walking into it goes up its foot and stands on the scrap, never sunk in.
##   Godot.exe --headless --path . -s res://tools/table_check.gd

const HEAP := Vector3(-9.0, 0, 0)

var _fail := false


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	await process_frame
	gs.start_quests()
	gs.request_pick_character("boss")  # the picker holds the hands until then
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
	_ok("t00" in gs.quests_done and gs.quest_board[0] == "t01", "the warmup moves on to the heap")
	_ok(me._hud._subtitle.visible, "the heap's line is said at the bottom")
	await create_timer(2.5).timeout
	_ok(not is_instance_valid(table), "the desk faded out and is gone")
	_ok((-me._camera.global_basis.z).dot((HEAP - me._camera.global_position).normalized()) > 0.9, "the view turned to the heap")
	await create_timer(4.0).timeout
	_ok(gs.unlocked("workbench") and not me._hud._q.visible, "the bench is open (no Q: everything is bought there)")
	_ok(not me._hud._sheet.visible, "the quest list waits for the board")
	_ok(gs.gold == gs.START_GOLD, "we start with $%d" % gs.gold)
	# The heap: from its foot, walk straight in for 3 s.
	me.global_position = HEAP + Vector3(9.5, 0.2, 0.0)
	me._yaw = PI / 2.0  # looking -x, at the middle
	me._pitch = 0.0
	me.reset_physics_interpolation()
	Input.action_press("move_forward")
	await create_timer(3.0).timeout
	Input.action_release("move_forward")
	# The scrap heap (2026-11-01) is locked up to 61°: we go up its foot and stop at the face, on the
	# pieces round our feet (the capsule rests on the highest of them), never sunk into the heap.
	var pile: Node = main.get_node("Pile")
	var top := 0.0
	for a in 8:
		top = maxf(top, pile.walk_y(me.global_position + Vector3(0.4, 0, 0).rotated(Vector3.UP, a * PI / 4.0)))
	var under: float = pile.surface_y(me.global_position)
	_ok(me.global_position.y > 0.3 and me.global_position.y > under - 0.05 and me.global_position.y < top + 0.3,
		"walking into the heap goes up its foot and stands on the scrap (%.1f m up, the scrap round us up to %.1f m, %.1f m in)" % [me.global_position.y, top, 9.5 - (me.global_position.x - HEAP.x)])
	print("table_check ", "FAILED" if _fail else "OK")
	quit(1 if _fail else 0)


func _ok(cond: bool, what: String) -> void:
	print("ok   " if cond else "FAIL ", what)
	_fail = _fail or not cond
