extends SceneTree
## Headless check for the hall's ambience (scripts/ambience.gd): the loops play, the lamp hum is
## full under a lit lamp and gone between rows, the night's events come due and hold each other back:
##   Godot.exe --headless --path . -s res://tools/ambience_check.gd


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	for i in 3:
		await process_frame
	var amb: Node = root.get_node("Main/Ambience")
	assert(amb._lamps.size() > 10, "found the lit hall lamps")
	print("lit lamps: %d" % amb._lamps.size())
	var lamp: Vector3 = amb._lamps[0]
	var body: Node3D = root.get_node("Main/Player")
	body.global_position = Vector3(lamp.x, 0.0, lamp.z)
	await _frames()
	assert(amb._hum.playing and amb._hum.volume_db > amb.HUM_DB - 0.1, "full hum under a lamp")
	body.global_position = Vector3(lamp.x, 0.0, lamp.z + 3.5)  # half way to the next truss
	await _frames()
	print("hum between rows: %.1f dB" % amb._hum.volume_db)
	assert(amb._hum.volume_db < amb.HUM_DB - 12.0, "quiet away from the lamps")
	# The night's events: every one has its clips, comes due, plays from round the hall and waits;
	# never more than MAX_AT_ONCE outside at once.
	for ev in amb.events:
		assert(ev.clips.size() > 0 and ev.clips.all(func(c: AudioStream) -> bool: return c != null), "%s has its clips" % ev.row[0])
		ev.wait = 0.0
	await process_frame
	await process_frame
	var outside: Array = amb.events.filter(func(ev: Dictionary) -> bool: return ev.player.playing and not ev.row[6])
	print("all due at once: %d outside sounding, cart %s" % [outside.size(), amb.events[-1].player.playing])
	assert(outside.size() == amb.MAX_AT_ONCE, "a busy night holds the rest back")
	assert(amb.events[-1].player.playing, "the cart, inside, is not held back")
	for ev in outside:
		assert(ev.wait >= ev.row[2].x, "%s waits its gap after playing" % ev.row[0])
		assert(Vector2(ev.player.global_position.x, ev.player.global_position.z).length() > 35.0, "%s is out past the walls" % ev.row[0])
	var held: Array = amb.events.filter(func(ev: Dictionary) -> bool: return not ev.player.playing)
	assert(held.all(func(ev: Dictionary) -> bool: return ev.wait <= 20.0), "and the held ones try again soon")
	# Outside: faint in the middle of the hall, clearer at a wall and from that wall's side.
	var crickets: AudioStreamPlayer3D = amb._outside[0]
	body.global_position = Vector3(2.0, 0.0, 0.0)
	await _frames()
	var mid := crickets.volume_db
	body.global_position = Vector3(2.0, 0.0, 26.8)
	await _frames()
	print("crickets: middle %.1f dB, by the south wall %.1f dB" % [mid, crickets.volume_db])
	assert(mid < amb.NIGHT_DB.x + 1.0 and crickets.volume_db > amb.NIGHT_DB.y - 1.5, "faint inside, clearer at a wall")
	assert(crickets.global_position.z > 28.0, "and heard from beyond that wall")
	assert(amb._outside[1].playing, "the forest plays too")
	print("ambience ok")
	quit()


## The camera eases after the body and the hum fades in and out: give both time to settle.
func _frames() -> void:
	await create_timer(2.0).timeout
