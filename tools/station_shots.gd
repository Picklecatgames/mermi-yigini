extends SceneTree
## The hopper's and the press's screens (scripts/melter_menu.gd, press_menu.gd) and their E hints,
## as PNGs to look at without playing: at the hopper with rounds in hand, its screen once they are
## poured in and melting, the hopper from a few steps off (its tag, fire and grate), at the press,
## its screen with clones picked, and right after a pull (the handle down, "+12").
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/station_shots.gd
## Shots land in user:// as station_<n>_<name>.png.

var _gs: Node
var _me: CharacterBody3D
var _n := 0


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_gs = root.get_node("GameState")
	_me = main.get_node("Player")
	await _settle(40)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # the window is off screen: don't hold the mouse
	_gs.request_take_pistol()
	while _gs.warming():
		_gs._finish_quest(_gs.quest_board[0])
	_gs._world(&"quests_changed", [_gs.quest_board, _gs.quest_progress, _gs.quests_ready])
	for what: String in ["workbench", "melter", "hand_press"]:
		for id: String in _gs.QUESTS:
			if _gs.QUESTS[id].get("unlock") == what and id not in _gs.quests_done:
				_gs.quests_done.append(id)
				_gs.quest_done.emit(id, 0)
	_gs.player().gold = 640
	_gs.gold_changed.emit(640)
	await _wait(12.0)  # the drops and their beams (reveal.gd)

	_gs.player().carried = 10
	_gs.carried_changed.emit(10)
	_stand(_gs.MELTER_POS + Vector3(0.1, 0, -1.3), _gs.MELTER_POS + Vector3(0, 0.9, 0))
	await _wait(0.6)
	await _shot("hopper_hint")
	_gs.request_melt()
	var melter: CanvasLayer = _me.get_node("MelterMenu")
	melter.open()
	await _wait(1.6)
	await _shot("hopper_screen")
	melter.close()
	await _wait(0.8)
	_gs.player().carried = 90
	_gs.request_melt()
	_stand(_gs.MELTER_POS + Vector3(1.2, 0, -3.4), _gs.MELTER_POS + Vector3(0, 0.8, 0))
	await _wait(1.0)
	await _shot("hopper_world")

	_gs.brass = 37
	_gs._melter_now(true)
	_stand(_gs.PRESS_POS + Vector3(-0.1, 0, -1.4), _gs.PRESS_POS + Vector3(0, 1.3, 0))
	await _wait(0.6)
	await _shot("press_hint")
	var press: CanvasLayer = _me.get_node("PressMenu")
	press.open()
	press._amount = 12
	press._refresh()
	await _wait(1.0)  # the camera's flight and the cards fading in
	await _shot("press_screen")
	press._press()
	await _wait(0.2)
	await _shot("press_made")
	quit()


func _stand(at: Vector3, look: Vector3) -> void:
	_me.global_position = at
	var d := look - (at + Vector3.UP * 1.6)
	_me._yaw = atan2(-d.x, -d.z)
	_me._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_me.velocity = Vector3.ZERO
	_me.reset_physics_interpolation()


## Offscreen frames run unthrottled: waits are in seconds.
func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(what: String, wait := 2) -> void:
	await _settle(wait)
	_n += 1
	var path := "user://station_%d_%s.png" % [_n, what]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", ProjectSettings.globalize_path(path))
