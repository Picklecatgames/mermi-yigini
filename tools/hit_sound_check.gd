extends SceneTree
## Headless: the gun's own world can be heard.
func _initialize() -> void:  # not _init: the autoloads (GameState...) must exist when player.tscn compiles
	var s := (load("res://scenes/player.tscn") as PackedScene).get_state()
	var heard := false
	var own := false
	for n in s.get_node_count():
		if s.get_node_name(n) == "SubViewport":
			for p in s.get_node_property_count(n):
				heard = heard or (s.get_node_property_name(n, p) == "audio_listener_enable_3d" and s.get_node_property_value(n, p))
				own = own or (s.get_node_property_name(n, p) == "own_world_3d" and s.get_node_property_value(n, p))
	assert(heard == own, "viewmodel SubViewport: a world of its own needs a 3D listener, a shared one must not have one (every shot twice)")
	print("OK")
	quit()
