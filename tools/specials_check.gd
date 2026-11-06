extends SceneTree
## Headless check for special rounds (GameState.SPECIALS): the odds, the pocket, arming one with
## V and the shot that spends it:
##   Godot.exe --headless --path . -s res://tools/specials_check.gd


const OPEN_AIR := Vector3(20.0, 0.2, -6.0)  # on the concrete pad, clear of the house (build_world.gd PAD, HOUSE)


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	for i in 3:
		await physics_frame
	var gs: Node = root.get_node("GameState")
	var p = gs.player()
	for id: String in gs.SPECIALS:
		assert(ResourceLoader.exists(gs.SPECIALS[id].tip), "%s has its tip model" % id)
	# Odds: a million bullets rolled, each special near 1 in its chance.
	seed(7)
	var n := 1_000_000
	var got_all: int = gs._roll_specials(0, n)
	var total := 0.0
	for id: String in gs.SPECIALS:
		var want: float = n / float(gs.SPECIALS[id].chance)
		var got: int = p.specials.count(id)
		total += want
		assert(absf(got - want) < want * 0.1, "%s: %d, want ~%d" % [id, got, want])
		print("%s 1/%d: %d of %d" % [id, gs.SPECIALS[id].chance, got, n])
	assert(got_all == p.specials.size(), "returns how many went in the pocket")
	print("one special every %.0f bullets" % (n / total))
	# A pickup: specials go in the pocket, the rest in the hand; together what came off the heap.
	p.specials.clear()
	p.levels["carry"] = 9
	p.levels["magazine"] = 6
	seed(3)
	var pile_before: int = gs.pile
	var hand := 0
	for i in 40:
		gs._set_carried(0, 0)
		gs.request_pick_up(Vector3.ZERO)
		hand += p.carried
	assert(pile_before - gs.pile == 400 and hand + p.specials.size() == 400, "every bullet off the heap is in hand or pocket")
	print("400 picked up: %d specials" % p.specials.size())
	# Arming: only what is in the pocket; the same again disarms.
	p.specials.assign(["punch", "balloon"])
	gs.request_arm_special("scream")
	assert(p.armed == "", "can't arm what we haven't got")
	gs.request_arm_special("balloon")
	assert(p.armed == "balloon")
	gs.request_arm_special("balloon")
	assert(p.armed == "", "armed again: disarmed")
	# The armed round fires instead of a magazine round, even with the magazine empty.
	var shots := []
	gs.player_shot.connect(func(_s: int, _v: int, _a: Vector3, _d: Vector3, sp: String) -> void: shots.append(sp))
	gs.request_take_pistol()  # off the desk at the spawn: drawn at once
	gs._set_loaded(0, 0)
	assert(not gs.request_fire(Vector3(0, 50, 0), Vector3.UP), "empty and nothing armed: no shot")
	gs.request_arm_special("punch")
	p.cooldown = 0.0
	assert(gs.request_fire(Vector3(0, 50, 0), Vector3.UP), "the armed special fires from an empty gun")
	assert(p.specials == ["balloon"] and p.armed == "" and p.loaded == 0, "spent, magazine untouched")
	# A plain shot leaves the pocket alone.
	gs._set_loaded(0, 2)
	p.cooldown = 0.0
	gs.request_fire(Vector3(0, 50, 0), Vector3.UP)
	assert(p.loaded == 1 and p.specials == ["balloon"], "plain round from the magazine")
	# What a special does to the player it hits (their own machine plays it).
	var me: CharacterBody3D = get_first_node_in_group("walker")
	var vm_cam: Camera3D = me.get_node("ViewmodelView/SubViewport/Camera")
	# Out under the open sky: the players start in the house now (tools/build_world.gd), whose ceiling
	# stopped the flight at 1.1 m (the old hall's roof was 9 m up). On the pad east of the house,
	# nothing over it or along the way it is thrown.
	me.global_position = OPEN_AIR
	me.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	var space := me.get_world_3d().direct_space_state
	var up := PhysicsRayQueryParameters3D.create(me.global_position + Vector3.UP * 2.0, me.global_position + Vector3.UP * 12.0)
	up.exclude = [me.get_rid()]
	assert(me.is_on_floor() and space.intersect_ray(up).is_empty(), "standing out in the open at %s" % me.global_position)
	var start := me.global_position
	me._hit_by_special("punch", Vector3(0, 0, 1))
	var top := 0.0
	var fast := 0.0
	for i in 60:
		await physics_frame
		top = maxf(top, me.global_position.y - start.y)
		if i == 30:  # mid-flight, before a wall can stop it
			fast = me._shove.length()
	print("punch: %.1f m/s half a second in, %.1f m up, ended %.1f m away" % [fast, top, me.global_position.distance_to(start)])
	assert(fast > 12.0 and top > 1.2, "punch throws us far and high")
	assert(me._dizzy > 0.0, "and leaves us dizzy")
	for i in 90:
		await physics_frame
	# Hit again and again, in the air too: it throws us about, never through the ground.
	for hit in 8:
		me._hit_by_special("punch", Vector3(-1, 0, 0) if hit % 2 else Vector3(0, 0, -1))
		for i in 12:
			await physics_frame
			var at: Vector3 = me.global_position
			assert(at.y > -1.0, "stays above the ground: %s" % at)
	for i in 600:  # down, and dizzy no more
		await physics_frame
		if me.is_on_floor() and me._dizzy == 0.0:
			break
	assert(absf(me._camera.rotation.z) < 0.05, "the view rights itself")
	start = me.global_position
	me._hit_by_special("balloon", Vector3.FORWARD)
	for i in 180:
		await physics_frame
	var risen := me.global_position.y - start.y
	for i in 90:  # past the top
		await physics_frame
	var fall := 0.0
	for i in 30:
		var y := me.global_position.y
		await physics_frame
		fall = maxf(fall, (y - me.global_position.y) * 60.0)
	print("balloon: up %.1f m, coming down at %.1f m/s" % [risen, fall])
	assert(risen > 2.5 and fall <= 1.1, "balloon lifts, then drifts down slowly")
	var before := vm_cam.get_child_count()
	me._hit_by_special("scream", Vector3.FORWARD)
	assert(vm_cam.get_child_count() == before + 1, "the face is in front of the camera")
	assert(me._special_sound.playing and me._special_sound.stream.resource_path.ends_with("scream.wav"), "with the scream")
	for i in 80:
		await physics_frame
	assert(vm_cam.get_child_count() == before, "and gone after the scare")
	# The ammo wheel (hold R): plain round first, then each kind in the pocket; sideways picks,
	# letting go loads it as the next shot. A new special brings up its note.
	var wheel: Control = me._wheel
	p.specials.clear()
	gs.specials_changed.emit()
	p.specials.assign(["scream", "punch"])
	p.armed = ""
	gs.specials_changed.emit()
	assert(is_instance_valid(wheel._note), "a new special: its note comes up")
	wheel.open()
	assert(wheel._ids == ["", "punch", "scream"], "plain, then the pocket's kinds: %s" % [wheel._ids])
	wheel.steer(wheel.PICK_STEP * 2.0)
	wheel.close()
	assert(p.armed == "scream" and not wheel.is_open, "let go: the picked one is the next shot")
	wheel.open()
	assert(wheel._pick == 2, "opens on the loaded one")
	wheel.steer(-wheel.PICK_STEP * 5.0)
	wheel.close()
	assert(p.armed == "", "the plain round takes it back out")
	print("specials check passed")
	quit()
