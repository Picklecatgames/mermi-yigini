extends SceneTree
## Headless check for the hall's ambience (scripts/ambience.gd): every bed is a 3D sound in the
## hall and plays, no take runs into the end of its recording (no loop seam), a sound turns from
## behind to in front as the listener turns, there is something on every side, and the lamp hum
## is full under a lit lamp and gone between rows:
##   Godot.exe --headless --path . -s res://tools/ambience_check.gd


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	for i in 3:
		await process_frame
	var amb: Node = root.get_node("Main/Ambience")
	await _frames()
	assert(amb.beds.size() == amb.BEDS.size(), "a bed for every sound")
	for b in amb.beds:
		assert(b.players[0] is AudioStreamPlayer3D and (b.players[0].playing or b.players[1].playing), "%s plays in 3D" % b.players[0].stream.resource_path)

	# Takes: many in a row, each ends (with its fade, at the fastest pitch) before the recording does.
	for b in amb.beds:
		for i in 40:
			b._take()
			var p: AudioStreamPlayer3D = b.players[b._on]
			var end: float = p.get_playback_position() + (b._left + b._fade) * p.pitch_scale
			assert(end <= b._len + 0.05, "%s: a take ends at %.2f s of %.2f" % [p.stream.resource_path, end, b._len])
			assert(b._left > 0.0, "a take has length")
	print("takes stay inside their recordings")
	for b in amb.beds + [amb._hum]:  # done fading: what follows measures direction and distance alone
		b._mix = [0.0, 0.0]
		b._mix[b._on] = 1.0

	# Something on every side of the hall's middle.
	var sides := {}
	for b in amb.beds:
		var at: Vector3 = b.global_position
		sides[(1 if at.x > 0 else 0) + (2 if at.z > 0 else 0)] = true
	assert(sides.size() == 4, "beds round all four quarters of the hall")

	# Turning: the creak in front, then behind.
	var body: Node3D = root.get_node("Main/Player")
	var cart: Node3D = amb.beds[amb.beds.size() - 1]
	body.global_position = Vector3(0, 0, 0)
	var to := cart.global_position - body.global_position
	body._yaw = atan2(-to.x, -to.z)  # the body turns to its _yaw every physics frame
	await _frames()
	var front: float = cart.behind
	var front_db: float = _loudest(cart)
	body._yaw += PI
	await _frames()
	print("creak facing: behind %.2f, %.1f dB; turned away: behind %.2f, %.1f dB" % [front, front_db, cart.behind, _loudest(cart)])
	assert(front < 0.2 and cart.behind > 0.8, "the creak goes from in front to behind")
	assert(_loudest(cart) < front_db - 3.0, "and is quieter behind")

	# The lamp hum.
	assert(amb._lamps.size() > 10, "found the lit hall lamps")
	var lamp: Vector3 = amb._lamps[0]
	body.global_position = Vector3(lamp.x, 0.0, lamp.z)
	await _frames()
	assert(amb._hum.gain > 0.99 and _loudest(amb._hum) > amb.HUM_DB + amb.BEHIND_DB - 0.1, "full hum under a lamp")
	body.global_position = Vector3(lamp.x, 0.0, lamp.z + 3.5)  # half way to the next truss
	await _frames()
	print("hum between rows: %.1f dB" % _loudest(amb._hum))
	assert(_loudest(amb._hum) < amb.HUM_DB - 12.0, "quiet away from the lamps")
	print("ambience ok")
	quit()


func _loudest(b: Node) -> float:
	var db := -INF
	for p in b.players:
		if p.playing:
			db = maxf(db, p.volume_db)
	return db


## The camera eases after the body over a few frames, the first take fades in, and process_frame
## fires before the nodes' _process: give them time to settle.
func _frames() -> void:
	for i in 30:
		await process_frame
