extends SceneTree
## Walks the first minutes (GameState QUESTS warmup, the board, the bench opening) with the real
## player and HUD and saves a PNG at each step, to look at without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/intro_shots.gd
## Shots land in user:// as intro_<n>_<name>.png.

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
	await _shot("start")
	_skip("t01")
	await _shot("hand_shown")
	_skip("t02")
	_skip("t03")
	await _shot("gold_shown")
	_skip("t04")
	await _shot("go_to_board")  # from the spawn: the board off to the side
	_stand(Vector3(8.6, 0, 24.0), _gs.BOARD_POS + Vector3(0, 1.4, 0))
	await _shot("at_board")
	_gs.request_claim_quests()
	await _settle(50)
	await _shot("side_quests")
	var m: String = _gs.quest_board[0]
	_gs.quest_add(_gs.QUESTS[m].kind, _gs.quest_target(m))
	await _shot("m01_done")
	_stand(Vector3(2.0, 0, 18.0), Vector3(12.0, 1.0, 27.0))
	_gs.request_claim_quests()
	await _settle(12)
	await _shot("bench_falling", 0)
	await _settle(40)
	await _shot("bench_in")
	_stand(Vector3(0, 0, 10.0), Vector3(14, 1.2, 0))
	await _shot("bench_arrow")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	quit()


## A warmup quest done as if played (the board's one stands in for the trip).
func _skip(id: String) -> void:
	if _gs.quest_board[0] == id:
		_gs.quest_add(_gs.QUESTS[id].kind, _gs.quest_target(id))


func _stand(at: Vector3, look: Vector3) -> void:
	_me.global_position = at
	var d := look - (at + Vector3.UP * 1.6)
	_me._yaw = atan2(-d.x, -d.z)
	_me._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_me.velocity = Vector3.ZERO
	_me.reset_physics_interpolation()


func _settle(frames: int) -> void:
	for f in frames:
		await process_frame


func _shot(name_: String, wait := 30) -> void:
	await _settle(wait)
	_n += 1
	var path := "user://intro_%02d_%s.png" % [_n, name_]
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
