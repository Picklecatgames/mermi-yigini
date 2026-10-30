extends SceneTree
## Headless check of how the guns feel (scripts/viewmodel.gd SETS shake/rise/weight, player.gd
## shake and kill punch, scripts/hit_marker.gd):
##   Godot.exe --headless --path . -s res://tools/feel_check.gd
## Every round jolts the camera by its gun's share (the Deagle hardest, the minigun least), aimed
## less; the SMGs climb more the longer a burst runs; the minigun's muzzle smoke goes with every
## other round only. The player's shake runs down, the settings turn it off, a spinning minigun keeps
## a floor. Hit marker: a zombie hit, a head hit, a kill, and the kill isn't cut short by the next hit.

const ORDER := ["deagle", "pistol", "uzi", "scorpion", "minigun"]  # hardest jolt first


func _initialize() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var settings: Node = root.get_node("Settings")
	var ok := [true]
	var check := func(good: bool, what: String) -> void:
		print(("ok   " if good else "FAIL ") + what)
		ok[0] = ok[0] and good
	var VM: GDScript = load("res://scripts/viewmodel.gd")

	# Per-gun numbers.
	var last := INF
	for id: String in ORDER:
		var k: Dictionary = VM.SETS[id]
		check.call(k.has("shake") and k.has("weight"), "%s has shake and weight" % id)
		check.call(float(k.shake) < last, "%s jolts less than the one before (%.2f)" % [id, k.shake])
		last = float(k.shake)
	check.call(float(VM.SETS.minigun.weight) > float(VM.SETS.deagle.weight), "the minigun is the heaviest in the hands")

	# The viewmodel firing on its own, stepped by hand.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	gs.request_pick_character("worker")
	gs.request_toggle_infinite_ammo()
	gs.player().has_pistol = true
	gs.player().levels.deagle = 1
	gs.player().carried = 400
	var player: CharacterBody3D = main.get_node("Player")
	var vm: Node3D = player.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	var shakes: Array[float] = []
	var climbs: Array[float] = []
	vm.shook.connect(func(t: float) -> void: shakes.append(t))
	vm.kicked.connect(func(a: float, _y: float) -> void: climbs.append(a))
	var draw := func(id: String) -> void:
		var g := -1
		for i in gs.GUNS.size():
			if gs.GUNS[i].id == id:
				g = i
		gs.request_select_gun(g)
		vm._want_gun = g
		vm._swap()
		vm._clip = ""
	var shoot := func() -> void:
		gs.player().cooldown = 0.0
		vm._since_fire = 10.0
		vm._clip = ""
		vm.fire()

	draw.call("deagle")
	shakes.clear()
	shoot.call()
	check.call(shakes.size() == 1 and is_equal_approx(shakes[0], VM.SETS.deagle.shake), "a Deagle round jolts the camera (%s)" % [shakes])
	vm.aim = 1.0
	shakes.clear()
	shoot.call()
	vm.aim = 0.0
	check.call(shakes.size() == 1 and shakes[0] < float(VM.SETS.deagle.shake), "aimed it jolts less")

	# A held UZI: later rounds climb more than the first (random ±20% per round, so averages).
	draw.call("uzi")
	climbs.clear()
	for i in 14:
		gs.player().cooldown = 0.0
		vm._since_fire = gs.fire_interval  # one interval on: still the same burst
		vm._clip = ""
		vm.fire()
	var first: float = (climbs[0] + climbs[1]) / 2.0
	var late: float = (climbs[12] + climbs[13]) / 2.0
	check.call(climbs.size() == 14 and late > first * 1.25, "the UZI walks up a burst (%.4f -> %.4f)" % [first, late])

	# Minigun: smoke and sparks every other round.
	draw.call("minigun")
	var fx: Array = vm._muzzle_fx
	var played := 0
	vm.spin = 1.0
	for i in 10:
		var before: int = vm._next_muzzle_fx
		vm.spin = 1.0
		shoot.call()
		played += 1 if vm._next_muzzle_fx != before else 0
	check.call(played == 10 / vm.SPIN_FX_EVERY, "minigun muzzle smoke on %d of 10 rounds" % played)

	# The player's shake: runs down, off with the setting, a floor while barrels turn.
	vm.spin = 0.0
	player._trauma = 0.7
	player._shake_camera(0.1)
	check.call(player._shake.length() > 0.0 and player._trauma < 0.7, "shake moves the camera and runs down")
	for i in 30:
		player._shake_camera(0.1)
	check.call(player._trauma == 0.0, "and is gone in under a second or so")
	settings.values["screen_shake"] = 0
	player._trauma = 1.0
	player._shake_camera(0.016)
	check.call(player._shake == Vector3.ZERO, "screen shake 0% holds the camera still")
	settings.values["screen_shake"] = 100
	vm.spin = 1.0
	player._trauma = 0.0
	player._shake_camera(0.016)
	check.call(is_equal_approx(player._trauma, player.SPIN_SHAKE), "spinning barrels keep a rumble")
	vm.spin = 0.0

	# A kill of ours narrows the view a blink and springs back.
	gs.wave_cue.emit([&"die", 1, 0, gs.local_peer(), true, Vector3.ZERO, "deagle", &"head"])
	var low := 0.0
	for i in 40:
		player._process(1.0 / 120.0)
		low = minf(low, player._punch)
	check.call(low < -1.0 and absf(player._punch) < 0.3, "a head kill punches the fov in (%.2f°) and back" % low)

	# Hit marker kinds.
	var marker: Control = player.get_node("HUD/HitMarker")
	var zombie := Node3D.new()
	zombie.set_meta("zombie", 1)
	main.add_child(zombie)
	marker._alpha = 0.0  # the kill above is still showing
	gs.shot_landed.emit(gs.local_peer(), Vector3.ZERO, Vector3.UP, Vector3.FORWARD, zombie, 0, false, 1)
	check.call(marker._kind == &"hit" and marker._alpha == 1.0, "a zombie hit flashes the marker even with no gold")
	gs.shot_landed.emit(gs.local_peer(), Vector3.ZERO, Vector3.UP, Vector3.FORWARD, zombie, 0, true, 1)
	check.call(marker._kind == &"head", "a head hit has its own")
	gs.wave_cue.emit([&"die", 1, 0, gs.local_peer(), false, Vector3.ZERO, "deagle", &""])
	check.call(marker._kind == &"kill", "a kill has its own")
	gs.shot_landed.emit(gs.local_peer(), Vector3.ZERO, Vector3.UP, Vector3.FORWARD, zombie, 0, false, 1)
	check.call(marker._kind == &"kill", "the next hit doesn't cut the kill short")
	marker._alpha = 0.0
	gs.shot_landed.emit(gs.local_peer() + 7, Vector3.ZERO, Vector3.UP, Vector3.FORWARD, zombie, 0, false, 1)
	check.call(marker._alpha == 0.0, "someone else's hit doesn't flash ours")

	print("feel_check " + ("OK" if ok[0] else "FAILED"))
	quit(0 if ok[0] else 1)
