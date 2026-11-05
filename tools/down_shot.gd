extends SceneTree
## Photographs going down (down_view.gd, player.gd, remote_players.gd) for checking it without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/down_shot.gd
## Saves user://down_<shot>.png: a blow from the right, a teammate lying on the floor, reddening at
## 3 and 7 s, black, then watching the teammate through their eyes. The teammate is a stand-in fed
## poses here (peer 99), as the character test does.

const MATE := 99
const MATE_AT := Vector3(10.0, 0.0, 2.5)

var gs: Node
var me: CharacterBody3D
var rp: Node


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	me = main.get_node("Player")
	await process_frame
	rp = get_first_node_in_group("remote_players")
	gs.request_pick_character("oldman")
	gs.request_take_pistol()
	gs.player(MATE).character = "oldman"
	gs.slots[gs.local_peer()] = 0
	gs.slots[MATE] = 1
	_look(Vector3(8.0, 0, -1.0), Vector3(14.0, 1.0, 1.5))
	_feed()
	await _settle(40)
	gs.cue_wave([&"phase", 1, gs.WAVE_FIGHT, 6])
	gs.hurt_player(0, 30.0, me.global_position + Vector3(0.5, 1.2, 2.0))  # from the right
	await _settle(4)
	_save("hurt")
	await _settle(40)
	gs.player(MATE).down = true
	_look(Vector3(7.0, 0, 0.0), MATE_AT + Vector3(0, 0.3, 0))
	await _settle(80)
	_save("mate_down")
	gs.player(MATE).down = false
	_look(Vector3(8.0, 0, -1.0), Vector3(14.0, 1.0, 1.5))
	await _settle(30)
	gs.hurt_player(0, 500.0, Vector3(14.5, 1.2, -1.0))
	await create_timer(3.0).timeout
	_save("red_3s")
	await create_timer(4.0).timeout
	_save("red_7s")
	await create_timer(gs.DOWN_TIME - 7.0 - 0.1).timeout
	_save("black")
	await create_timer(1.5).timeout
	_save("watching")
	quit()


## The stand-in's poses, 20 a second, standing at MATE_AT and looking down the range.
func _feed() -> void:
	var t := Timer.new()
	t.wait_time = 0.05
	t.autostart = true
	t.timeout.connect(func() -> void:
		rp._on_pose(MATE, Time.get_ticks_msec() / 1000.0, MATE_AT, -PI * 0.5 + 0.2, -0.05, gs.Act.IDLE, false, false, false))
	root.add_child(t)


func _look(from: Vector3, at: Vector3) -> void:
	me.global_position = from
	me.reset_physics_interpolation()
	var d: Vector3 = at - (from + Vector3.UP * 1.6)
	me._yaw = atan2(-d.x, -d.z)
	me._pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _settle(frames: int) -> void:
	for f in frames:
		await process_frame


func _save(name: String) -> void:
	var path := "user://down_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
