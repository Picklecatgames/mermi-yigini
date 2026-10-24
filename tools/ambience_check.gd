extends SceneTree
## Headless check for the hall's ambience (scripts/ambience.gd): the loops play, the lamp hum is
## full under a lit lamp and gone between rows, the mine cart comes round on its own:
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
	amb._cart_wait = 0.0
	await _frames()
	assert(amb._cart.playing and amb._cart_wait >= amb.CART_GAP.x, "the cart rolls, then waits")
	print("ambience ok")
	quit()


## The camera eases after the body over a few frames, and process_frame fires before the nodes'
## _process: give both time to settle.
func _frames() -> void:
	for i in 30:
		await process_frame
