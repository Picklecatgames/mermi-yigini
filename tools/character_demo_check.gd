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
	# A quick turn of the look: the head turns at once, the body (and gun) comes after.
	var body_was: float = c.rotation.y
	var head_was: Basis = _head_on_chest(c)
	me._yaw += 0.5
	for i in 12:
		await physics_frame
	var head_now: Basis = _head_on_chest(c)
	var head_turn := (head_was.inverse() * head_now).get_rotation_quaternion().get_angle()
	var body_turn := absf(wrapf(c.rotation.y - body_was, -PI, PI))
	print("0.2 s after a 0.5 rad look: body %.2f rad, head %.2f rad off the chest" % [body_turn, head_turn])
	assert(body_turn < 0.25 and head_turn > 0.25, "the head turns first")
	for i in 120:
		await physics_frame
	assert(absf(wrapf(c.rotation.y - body_was, -PI, PI)) > 0.45, "then the body catches up")
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
	# Shift+K: gone, even while we look right at it (the reach ray held on to its freed body and
	# player.gd _looking_at_table crashed on it).
	var to: Vector3 = c.global_position + Vector3.UP * 1.2 - me._reach.global_position
	me._yaw = atan2(-to.x, -to.z)
	me._pitch = atan2(to.y, Vector2(to.x, to.z).length())
	for i in 3:
		await physics_frame
	print("reach on the stand-in: %s" % (me._reach.is_colliding() and me._reach.get_collider() == c.body))
	me._toggle_mirror(false)
	for i in 3:
		await physics_frame
	assert(others.character(peer) == null and not gs._players.has(peer), "Shift+K: gone")
	print("character demo: ok")
	quit()


func _head_on_chest(c: Node3D) -> Basis:
	var sk: Skeleton3D = c._skel
	var chest := sk.get_bone_global_pose(sk.find_bone("mixamorig_Spine2")).basis.orthonormalized()
	return chest.inverse() * sk.get_bone_global_pose(c._head).basis.orthonormalized()
