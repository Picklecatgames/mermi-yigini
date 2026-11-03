extends SceneTree
## Headless check for scripts/music.gd: Net has it, a day piece plays on Muzik under the world, the
## next one is the other piece, dusk fades the day's piece and plays the dusk drone, the night and
## a start deep in the night stay quiet:
##   Godot.exe --headless --path . -s res://tools/music_check.gd

var _fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	await process_frame
	var net: Node = root.get_node("Net")
	var music: Node = null
	for c in net.get_children():
		if c.get_script() == load("res://scripts/music.gd"):
			music = c
	_ok(music != null, "Net has the music")
	if music == null:
		quit(1)
		return
	var gs: Node = root.get_node("GameState")
	_ok(Ps1Sound.files("muzik/day").size() >= 2 and Ps1Sound.files("muzik/dusk").size() >= 1, "the day's pieces and the dusk drone are there")
	_ok(music._player.bus == &"Muzik" and AudioServer.get_bus_index(&"Muzik") >= 0, "on its own bus")
	_ok(music._player.volume_db <= -10.0, "quiet, under the world")

	# By day: nothing at first, then a piece, then (after the gap) the other one.
	gs.hour = 12.0
	await process_frame
	_ok(music.playing() == "", "a while of nothing first")
	music._wait = 0.0
	await process_frame
	await process_frame
	var first: String = music.playing()
	_ok(first.contains("/day_"), "a day piece plays (%s)" % first)
	music._player.stop()
	music._wait = 0.0
	await process_frame
	await process_frame
	_ok(music.playing().contains("/day_") and music.playing() != first, "the next is the other piece")

	# Dusk: the day's piece fades, the drone plays once.
	gs.hour = 19.5
	await create_timer(music.FADE + 0.5).timeout
	_ok(music.playing().contains("/dusk_"), "dusk plays its drone (%s)" % music.playing())
	music._player.stop()
	gs.hour = 23.0
	for i in 5:
		await process_frame
	_ok(music.playing() == "", "the night is quiet")

	# Morning resets the day; a game started deep in the night gets no dusk drone.
	gs.hour = 9.0
	await process_frame
	_ok(not music._dusk_played and music._wait > 30.0, "a new day starts with a wait")
	music._dusk_played = false
	gs.hour = 0.0
	await process_frame
	_ok(music.playing() == "", "no drone deep in the night")

	print("music_check: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + what)
