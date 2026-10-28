extends SceneTree
## The workshop bench (scripts/bench_menu.gd) and the parts in hand, as PNGs to look at without
## playing: the quests up to the bench, sitting down, the Deagle sliding in, the laser and the holo
## going on (mid-flight and home), then the gun in hand with both and the laser's dot.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/bench_shots.gd
## Shots land in user:// as bench_<n>_<name>.png.

var _gs: Node
var _me: CharacterBody3D
var _bench: CanvasLayer
var _n := 0


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_gs = root.get_node("GameState")
	_me = main.get_node("Player")
	await _settle(40)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # the window is off screen: don't hold the mouse
	_gs.request_take_pistol()
	for i in 20:  # the warmup and the main quests up to the bench
		var id: String = _gs.quest_board[0]
		if id == "m01c":
			break
		_gs.quest_add(_gs.QUESTS[id].kind, _gs.quest_target(id))
		_gs.player().has_pose = false  # claims as if at the board
		_gs.request_claim_quests()
		await process_frame
	print("main quest: ", _gs.quest_board[0], " bench open: ", _gs.unlocked("workbench"))
	_stand(Vector3(12.2, 0, 26.2), Vector3(12.2, 1.1, 27.6))
	await _wait(4.0)  # the bench has fallen in (reveal.gd)
	await _shot("at_bench")
	_bench = _me.get_node("BenchMenu")
	print("can open: ", _bench.can_open())
	_bench.open()
	await _wait(1.0)
	await _shot("open")
	_bench._pick("deagle")
	await _wait(0.25)
	await _shot("sliding", 0)
	await _wait(1.0)
	await _shot("gun_in")
	_gs.player().gold = 1000
	_gs.gold_changed.emit(1000)
	_bench._buy("laser")
	await _wait(0.35)
	await _shot("laser_coming", 0)
	await _wait(1.6)
	await _shot("laser_on")
	_bench._buy("holo")
	await _wait(0.35)
	await _shot("holo_coming", 0)
	await _wait(1.6)
	await _shot("holo_on")
	_bench._buy("magazine")
	await _wait(0.62)
	await _shot("magazine_out", 0)
	await _wait(0.6)
	await _shot("magazine_in", 0)
	await _wait(1.5)
	await _shot("magazine_done", 0)
	_bench.close()
	await _wait(1.0)
	_stand(Vector3(10.0, 0, 0.0), Vector3(22.0, 1.4, 0.0))
	await _wait(2.0)
	await _shot("in_hand")
	print("quest board: ", _gs.quest_board[0], " done ", _gs.quests_done.has("m01c"))
	quit()


func _stand(at: Vector3, look: Vector3) -> void:
	_me.global_position = at
	var d := look - (at + Vector3.UP * 1.6)
	_me._yaw = atan2(-d.x, -d.z)
	_me._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_me.velocity = Vector3.ZERO
	_me.reset_physics_interpolation()


## Offscreen frames run unthrottled: animations are waited for in seconds.
func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(what: String, wait := 2) -> void:
	await _settle(wait)
	_n += 1
	var path := "user://bench_%d_%s.png" % [_n, what]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", ProjectSettings.globalize_path(path))
