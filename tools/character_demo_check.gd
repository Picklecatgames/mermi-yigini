extends SceneTree
## Headless check for the character test (K, scripts/character_demo.gd): the mirror's stand-in
## wears our character and gun, stands in front of us and walks as we do, reflected; K changes the
## character on us and on it, L opens the pick screen, Shift+K takes it away:
##   Godot.exe --headless --path . -s res://tools/character_demo_check.gd


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	for i in 3:
		await physics_frame
	var gs: Node = root.get_node("GameState")
	var me: CharacterBody3D = get_first_node_in_group("walker")
	var others: Node = get_first_node_in_group("remote_players")
	gs.request_pick_character("boss")
	gs.request_take_pistol()
	me._toggle_mirror(true)
	for i in 10:
		await physics_frame
	var demo: Node = me.get_parent().get_node("CharacterDemo")
	var peer: int = demo.PEER
	var c: Node3D = others.character(peer)
	assert(c != null, "the stand-in is drawn")
	assert(c.look == "boss" and c._model != null, "in our character")
	assert(c.gun == gs.player().gun and c.gun != 0, "with our gun")
	var ahead := -me.global_basis.z
	ahead.y = 0.0
	var gap: float = (c.global_position - me.global_position).dot(ahead.normalized())
	assert(gap > demo.GAP - 0.5, "in front of us: %.2f m" % gap)
	# Walking at the mirror, it walks at us.
	var start := c.global_position
	me.global_position += ahead.normalized()
	for i in 20:
		await physics_frame
	var came: float = (start - c.global_position).dot(ahead.normalized())
	assert(came > 0.8, "comes toward us: %.2f m" % came)
	# K: the next character, on us and the stand-in.
	me._toggle_mirror(true)
	await physics_frame
	assert(gs.player().character == "masked" and c.look == "masked", "K: next character on both")
	# L: the pick screen, as at the start.
	demo.open_pick()
	await process_frame
	await process_frame
	var pick: CanvasLayer = me._pick
	assert(pick.is_open and c._model == null, "L: pick screen open, the stand-in bare")
	pick._pick("chupacabra")
	await process_frame
	await process_frame
	assert(not pick.is_open and c.look == "chupacabra", "picked: screen closes, the stand-in dressed")
	# Shift+K: gone.
	me._toggle_mirror(false)
	for i in 3:
		await physics_frame
	assert(others.character(peer) == null and not gs._players.has(peer), "Shift+K: gone")
	print("character demo: ok")
	quit()
