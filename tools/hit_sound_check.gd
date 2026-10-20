extends SceneTree
## Headless: the dummy's hit randomizer has all 6 hits, and the gun's own world can be heard.
func _init() -> void:
	var r: AudioStreamRandomizer = load("res://assets/props/dummy/sounds/hit.tres")
	assert(r.streams_count == 6)
	for i in r.streams_count:
		assert(r.get_stream(i).get_length() > 0.3)
	var s := (load("res://scenes/player.tscn") as PackedScene).get_state()
	var heard := false
	for n in s.get_node_count():
		if s.get_node_name(n) == "SubViewport":
			for p in s.get_node_property_count(n):
				heard = heard or (s.get_node_property_name(n, p) == "audio_listener_enable_3d" and s.get_node_property_value(n, p))
	assert(heard, "viewmodel SubViewport has its own world but no 3D listener: gun sounds go silent")
	print("OK")
	quit()
