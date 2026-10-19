extends SceneTree
## Headless check for weak spot and combo payouts:
##   Godot.exe --headless --path . -s res://tools/combo_check.gd


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var dummy: Node3D = main.get_node("Dummy")
	for i in 3:
		await physics_frame
	gs.infinite_ammo = true
	gs.player().loaded = 1
	var from: Vector3 = dummy.global_position + Vector3(-11, 0, 0)  # from in front of the firing line
	var shot := func(height: float) -> int:
		var before: int = gs.player().gold
		gs.player().cooldown = 0.0
		var to: Vector3 = dummy.global_position + Vector3(0, height, 0)
		gs.request_fire(from + Vector3(0, height, 0), (to - from - Vector3(0, height, 0)).normalized())
		return gs.player().gold - before
	assert(shot.call(1.1) == 1, "first hit pays 1")
	assert(shot.call(1.64) == 4, "2nd hit in the window, head: 1 x2 weak x2 chain")
	assert(shot.call(1.1) == 2, "3rd hit: chain x3, but one kind caps the pay at x2")
	assert(gs.player().combo == 3, "the chain itself keeps counting")
	gs._process(gs.COMBO_WINDOW + 0.1)  # let the window run out
	assert(gs.player().combo == 0, "a gap breaks the chain")
	assert(shot.call(1.1) == 1, "chain starts over")
	gs._process(gs.COMBO_WINDOW - 0.1)  # just inside the window
	assert(shot.call(1.1) == 2, "a hit just in time keeps it")
	shot.call(8.0)  # over the top: a miss
	assert(gs.player().combo == 0, "a miss breaks the chain")
	# Past the firing line a hit pays nothing and builds no chain.
	gs.player().cooldown = 0.0
	var close: Vector3 = dummy.global_position + Vector3(-3, 1.1, 0)
	var before_close: int = gs.player().gold
	gs.request_fire(close, Vector3(1, 0, 0))
	assert(gs.player().gold == before_close and gs.player().combo == 0, "no pay from past the line")
	# Other targets, each from 5 m in front, chain cleared between them.
	var at := func(node: String, height: float) -> int:
		gs._process(gs.COMBO_WINDOW + 0.1)
		var t: Node3D = main.get_node("LockedTargets/" + node)
		var to: Vector3 = t.global_position + Vector3(0, height, 0)
		var start := to + Vector3(-11, 0, 0)
		var before: int = gs.player().gold
		gs.player().cooldown = 0.0
		gs.request_fire(start, (to - start).normalized())
		return gs.player().gold - before
	var locked: Node3D = main.get_node("LockedTargets")
	locked.visible = false
	locked.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	assert(at.call("PopperNorth", 0.3) == 0, "locked targets take no hits")
	locked.visible = true
	locked.process_mode = Node.PROCESS_MODE_INHERIT
	await physics_frame
	# Model targets face their local +Z: shoot from 11 m out in front of a world point on them.
	var front := func(node: String, point: Vector3) -> int:
		gs._process(gs.COMBO_WINDOW + 0.1)
		var t: Node3D = main.get_node("LockedTargets/" + node)
		var start: Vector3 = point + t.global_basis.z * 11.0
		var before: int = gs.player().gold
		gs.player().cooldown = 0.0
		gs.request_fire(start, (point - start).normalized())
		return gs.player().gold - before
	var popper: Node3D = main.get_node("LockedTargets/PopperNorth")
	assert(front.call("PopperNorth", popper.global_transform * Vector3(0, 0.62, 0)) == 6, "popper head pays 3 x2")
	assert(front.call("PopperNorth", popper.global_transform * Vector3(0, 0.3, 0)) == 0, "a knocked popper takes no hits")
	await create_timer(4.5).timeout
	await physics_frame
	assert(front.call("PopperNorth", popper.global_transform * Vector3(0, 0.3, 0)) == 3, "back up, body pays 3")
	var rack: Node3D = main.get_node("LockedTargets/PlateRack")
	var waited := 0.0
	while rack.up_plate() < 0 and waited < 4.0:
		await physics_frame
		waited += 1.0 / 60.0
	var up: int = rack.up_plate()
	assert(up >= 0, "a rack plate comes up")
	assert(front.call("PlateRack", rack.plate_center(up)) == 7, "up plate pays 7")
	assert(rack.up_plate() == -1, "it goes down at once")
	var star: Node3D = main.get_node("LockedTargets/TexasStar")
	assert(front.call("TexasStar", star.plate_center(0)) == 12, "star plate pays 12")
	assert(star.plates_on() == 4, "the hit plate falls off")
	# Variety lifts the cap: dummy, then gong, then the star in one chain pays x3 on the third.
	gs._process(gs.COMBO_WINDOW + 0.1)
	var chain := func(point: Vector3, from_dir: Vector3) -> int:
		var start: Vector3 = point + from_dir * 11.0
		var before: int = gs.player().gold
		gs.player().cooldown = 0.0
		gs.request_fire(start, (point - start).normalized())
		return gs.player().gold - before
	assert(chain.call(dummy.global_position + Vector3(0, 1.1, 0), Vector3(-1, 0, 0)) == 1, "chain 1")
	assert(chain.call(dummy.global_position + Vector3(0, 1.1, 0), Vector3(-1, 0, 0)) == 2, "chain 2, one kind")
	assert(chain.call(dummy.global_position + Vector3(0, 1.1, 0), Vector3(-1, 0, 0)) == 2, "chain 3, still one kind")
	assert(chain.call(star.plate_center(1), Vector3(-1, 0, 0)) == 12 * 3, "a second kind: chain 4 pays x3")
	# From past the line a popper rings but stays up.
	gs._process(gs.COMBO_WINDOW + 0.1)
	var south: Node3D = main.get_node("LockedTargets/PopperSouth")
	var head: Vector3 = south.global_transform * Vector3(0, 0.62, 0)
	gs.player().cooldown = 0.0
	gs.request_fire(head + Vector3(-3, 0, 0), Vector3(1, 0, 0))
	await physics_frame
	assert(front.call("PopperSouth", head) == 6, "still standing after a shot from past the line")
	# Test mode (T) gives the gun back as it was.
	gs.infinite_ammo = false  # the test turned it on directly at the start
	gs.player().levels["capacity"] = 3  # room for more than the 2 rounds below
	gs.player().loaded = 2
	gs.request_toggle_infinite_ammo()
	gs.request_toggle_infinite_ammo()
	assert(gs.player().loaded == 2, "T on and off leaves no free rounds")
	# The firing line stops the player, except in placement mode.
	var pl: CharacterBody3D = main.get_node("Player")
	pl.global_position = Vector3(gs.FIRING_LINE_X - 1.5, 0.05, 0)
	await physics_frame
	await physics_frame
	var col := pl.move_and_collide(Vector3(3, 0, 0), true)
	assert(col != null and col.get_collider().name == "FiringLine", "the railing stops the player")
	gs.request_toggle_placing()
	await physics_frame
	await physics_frame
	col = pl.move_and_collide(Vector3(3, 0, 0), true)
	assert(col == null or col.get_collider().name != "FiringLine", "placement mode lets them through")
	gs.request_toggle_placing()
	print("combo_check OK")
	quit()
