extends SceneTree
## Headless check for weak spot and combo payouts:
##   Godot.exe --headless --path . -s res://tools/combo_check.gd


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.add_child(load("res://scenes/test_range.tscn").instantiate())  # the six fixed targets; the game starts with one dummy
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var dummy: Node3D = main.get_node("Dummy")
	for i in 3:
		await physics_frame
	assert(not gs.request_fire(Vector3.ZERO, Vector3.FORWARD), "bare fists fire nothing")
	gs.request_select_gun(1)
	assert(gs.player().gun == 1, "number key 1 draws the first gun")
	gs.infinite_ammo = true
	gs.player().loaded = 1
	gs.player().levels["combo_cap"] = 4  # x20; the cap itself is checked further down
	var from: Vector3 = dummy.global_position + Vector3(-11, 0, 0)  # from in front of the firing line
	var shot := func(height: float) -> int:
		var before: int = gs.player().gold
		gs.player().cooldown = 0.0
		var to: Vector3 = dummy.global_position + Vector3(0, height, 0)
		gs.request_fire(from + Vector3(0, height, 0), (to - from - Vector3(0, height, 0)).normalized())
		return gs.player().gold - before
	assert(shot.call(1.1) == 1, "first hit pays 1")
	assert(shot.call(1.1) == 2, "2nd body hit: chain x2")
	assert(shot.call(1.64) == 2, "a head starts its own chain: 1 x2 weak x1")
	assert(shot.call(1.1) == 3, "3rd body hit: chain x3, the head did not add to it")
	assert(shot.call(1.64) == 4, "2nd head: 1 x2 weak x2")
	assert(gs.player().combo == 3 and gs.player().weak_combo == 2, "two chains")
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
	# One body chain runs across targets: three on the dummy, the fourth on the star.
	gs._process(gs.COMBO_WINDOW + 0.1)
	var chain := func(point: Vector3, from_dir: Vector3) -> int:
		var start: Vector3 = point + from_dir * 11.0
		var before: int = gs.player().gold
		gs.player().cooldown = 0.0
		gs.request_fire(start, (point - start).normalized())
		return gs.player().gold - before
	assert(chain.call(dummy.global_position + Vector3(0, 1.1, 0), Vector3(-1, 0, 0)) == 1, "chain 1")
	assert(chain.call(dummy.global_position + Vector3(0, 1.1, 0), Vector3(-1, 0, 0)) == 2, "chain 2")
	assert(chain.call(dummy.global_position + Vector3(0, 1.1, 0), Vector3(-1, 0, 0)) == 3, "chain 3")
	assert(chain.call(star.plate_center(1), Vector3(-1, 0, 0)) == 12 * 4, "chain 4 pays x4 on the star too")
	# The chain is the multiplier all the way to COMBO_MAX, then holds there.
	gs._process(gs.COMBO_WINDOW + 0.1)
	var got := 0
	for i in gs.COMBO_MAX + 3:
		got = chain.call(dummy.global_position + Vector3(0, 1.1, 0), Vector3(-1, 0, 0))
		if i < gs.COMBO_MAX:
			assert(got == i + 1, "hit %d pays x%d" % [i + 1, i + 1])
	assert(got == gs.COMBO_MAX, "capped at x%d" % gs.COMBO_MAX)
	# Q upgrades, on every target: a fresh player's combo stops at x2, and +10% gold adds up.
	gs.player().levels["combo_cap"] = 0
	gs.player().levels["gold_bonus"] = 1
	gs.player().gold_rest = 0.0
	gs._process(gs.COMBO_WINDOW + 0.1)
	var total := 0
	for i in 10:
		total += chain.call(dummy.global_position + Vector3(0, 1.1, 0), Vector3(-1, 0, 0))
	assert(gs.player().combo == 2, "combo capped at x2 before the upgrade")
	assert(total == 20, "1.1 + 9 x 2.2 = 20.9: whole dollars paid, the 0.9 carried")
	assert(chain.call(star.plate_center(2), Vector3(-1, 0, 0)) == 27, "the star too: 12 x2 x1.1 + 0.9 carried = 27.3")
	gs.player().levels["gold_bonus"] = 0
	# Range: +4%/m from 5 m behind the railing (clear of the heap) is +20%.
	gs.player().levels["range_bonus"] = 4
	gs.player().gold_rest = 0.0
	gs._process(gs.COMBO_WINDOW + 0.1)
	var body: Vector3 = dummy.global_position + Vector3(0, 1.1, 0)
	var back := Vector3(gs.FIRING_LINE_X - 5.0, body.y, body.z)
	total = 0
	for i in 5:
		var before: int = gs.player().gold
		gs.player().cooldown = 0.0
		gs.request_fire(back, (body - back).normalized())
		total += gs.player().gold - before
	assert(total == 10, "1.2 + 4 x 2.4 = 10.8 from 5 m back")
	gs.player().levels["range_bonus"] = 0
	gs.player().levels["combo_cap"] = 4
	# Hand and magazine grow apart.
	gs.player().levels["carry"] = 4
	assert(gs.carry_capacity == 5 and gs.mag_capacity == 1, "carry and magazine are separate upgrades")
	gs.player().levels["carry"] = 0
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
	gs.player().levels["magazine"] = 3  # room for more than the 2 rounds below
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
	# Moving costs accuracy, and stopping wins it back within a quarter second.
	var vm: Node3D = pl.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	vm.set_process(false)
	var settle := func(v: Vector3, frames: int) -> float:
		for i in frames:
			pl.velocity = v
			vm._sway_and_bob(1.0 / 60.0)
		return vm.spread
	var still: float = settle.call(Vector3.ZERO, 60)
	var walking: float = settle.call(Vector3(5, 0, 0), 12)
	var stopped: float = settle.call(Vector3.ZERO, 15)
	print("spread still %.4f, walking %.4f, 0.25 s after stopping %.4f rad" % [still, walking, stopped])
	assert(pl.is_on_floor() and still < 0.004 and walking > 0.018 and stopped < walking * 0.3, "moving costs accuracy, stopping wins it back")
	vm.set_process(true)
	# Guns: each one up the order fires faster; an SMG's magazine is the upgrade times its own; a
	# round before the gun is ready again is refused; switching guns puts the magazine back in hand.
	for i in range(2, gs.GUNS.size()):
		assert(gs.GUNS[i].interval < gs.GUNS[i - 1].interval, "%s fires faster than %s" % [gs.GUNS[i].id, gs.GUNS[i - 1].id])
	gs.infinite_ammo = false
	gs.player().levels["magazine"] = 2
	gs.request_select_gun(2)
	assert(gs.player().gun == 2 and gs.mag_capacity == gs.upgrade_value("magazine") * gs.GUNS[2].mag, "the UZI's magazine")
	gs.player().carried = 10
	gs.request_reload()
	var in_mag: int = gs.loaded
	gs.player().cooldown = 0.0
	assert(gs.request_fire(close, Vector3(1, 0, 0)) and not gs.request_fire(close, Vector3(1, 0, 0)), "one round per interval")
	gs.request_select_gun(3)
	assert(gs.loaded == 0 and gs.carried == 10 - in_mag + in_mag - 1, "the UZI's rounds went back into the hand")
	print("combo_check OK")
	quit()
