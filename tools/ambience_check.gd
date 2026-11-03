extends SceneTree
## Headless check for the open ground's ambience (scripts/ambience.gd): the lamp hum is full under a
## lit workshop lamp and gone away from them; by day the night is quiet; at night the beds come up
## and the night's events come due and hold each other back:
##   Godot.exe --headless --path . -s res://tools/ambience_check.gd


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	for i in 3:
		await process_frame
	var amb: Node = root.get_node("Main/Ambience")
	# The workshop's three caged lamps. A failed assert doesn't quit headless, so this one does it itself.
	print("lit lamps: %d" % amb._lamps.size())
	if amb._lamps.is_empty():
		push_error("the lit workshop lamps: missing")
		quit(1)
		return
	var lamp: Vector3 = amb._lamps[0]
	var body: Node3D = root.get_node("Main/Player")
	body.global_position = Vector3(lamp.x, 0.0, lamp.z)
	await _frames()
	assert(amb._hum.playing and amb._hum.volume_db > amb.HUM_DB - 0.1, "full hum under a lamp")
	var mid := Vector3.ZERO
	for l: Vector3 in amb._lamps:
		mid += l / amb._lamps.size()
	var away := Vector3(lamp.x, 0.0, lamp.z) + (Vector3(lamp.x - mid.x, 0.0, lamp.z - mid.z).normalized() * 6.0 if not lamp.is_equal_approx(mid) else Vector3(6.0, 0.0, 0.0))
	body.global_position = away
	await _frames()
	print("hum away from the lamps: %.1f dB" % amb._hum.volume_db)
	assert(amb._hum.volume_db < amb.HUM_DB - 12.0, "quiet away from the lamps")
	# By day: no crickets, no owls.
	for ev in amb.events:
		assert(ev.clips.size() > 0 and ev.clips.all(func(c: AudioStream) -> bool: return c != null), "%s has its clips" % ev.row[0])
		ev.wait = 0.0
	await process_frame
	await process_frame
	assert(amb.events.all(func(ev: Dictionary) -> bool: return not ev.player.playing), "no night event by day")
	assert(amb._outside.all(func(p: AudioStreamPlayer) -> bool: return p.volume_linear < 0.001), "no night beds by day")
	# At night: the events come due, never more than MAX_AT_ONCE at once, out round the base.
	amb.night = true
	await process_frame
	await process_frame
	var sounding: Array = amb.events.filter(func(ev: Dictionary) -> bool: return ev.player.playing)
	print("night, all due at once: %d sounding" % sounding.size())
	assert(sounding.size() == amb.MAX_AT_ONCE, "a busy night holds the rest back")
	for ev in sounding:
		assert(ev.wait >= ev.row[2].x, "%s waits its gap after playing" % ev.row[0])
		assert(Vector2(ev.player.global_position.x, ev.player.global_position.z).length() > 35.0, "%s is out in the dark" % ev.row[0])
	var held: Array = amb.events.filter(func(ev: Dictionary) -> bool: return not ev.player.playing)
	assert(held.all(func(ev: Dictionary) -> bool: return ev.wait <= 20.0), "and the held ones try again soon")
	await create_timer(6.0).timeout
	print("crickets at night: %.1f dB" % amb._outside[0].volume_db)
	assert(amb._outside.all(func(p: AudioStreamPlayer) -> bool: return p.playing and p.volume_db > amb.FOREST_DB - 6.0), "the beds come up at night")
	print("ambience ok")
	quit()


## The camera eases after the body and the hum fades in and out: give both time to settle.
func _frames() -> void:
	await create_timer(2.0).timeout
