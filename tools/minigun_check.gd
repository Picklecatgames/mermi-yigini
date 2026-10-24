extends SceneTree
## Headless check of the minigun (scripts/viewmodel.gd SETS minigun spin, GameState gun_open):
##   Godot.exe --headless --path . -s res://tools/minigun_check.gd
## Shut until its crate opens (test mode T opens it; T off with it in hand puts it away). Held
## trigger: no round until the barrels are up to speed, then the rate climbs from the slow first
## rounds to the top rate. Let go, they run down; pressing again picks up from the speed left. The
## aim button only turns them (no sights, no round). They turn on top of the clip's pose, slow the
## player down, and running plays the set's looping Sprint clip.

const DT := 1.0 / 120.0
const MINIGUN := 4


func _initialize() -> void:
	await process_frame  # root enters the tree first
	var gs: Node = root.get_node("GameState")
	var ok := [true]  # lambdas capture locals by value; an array is shared
	var check := func(good: bool, what: String) -> void:
		print(("ok   " if good else "FAIL ") + what)
		ok[0] = ok[0] and good

	assert(gs.GUNS[MINIGUN].id == "minigun")
	gs.request_select_gun(MINIGUN)
	check.call(gs.player().gun == 0, "shut before its crate: gun stays %d" % gs.player().gun)
	gs.request_toggle_infinite_ammo()
	gs.request_select_gun(MINIGUN)
	check.call(gs.player().gun == MINIGUN, "test mode opens it")
	gs.request_toggle_infinite_ammo()
	check.call(gs.player().gun == 0, "test mode off puts it away")
	gs.request_toggle_infinite_ammo()
	gs.request_select_gun(MINIGUN)

	var level := Node3D.new()
	root.add_child(level)
	var body := CharacterBody3D.new()
	level.add_child(body)
	var head := Node3D.new()
	head.name = "Head"
	body.add_child(head)
	var cam := Camera3D.new()
	cam.name = "Camera3D"  # in_view looks for the player's camera here
	head.add_child(cam)
	var vm: Node3D = load("res://scenes/viewmodel.tscn").instantiate()
	vm.set_process(false)  # we step it ourselves
	cam.add_child(vm)
	vm.setup(body)
	await process_frame
	vm._want_gun = MINIGUN
	vm._swap()
	vm._clip = ""  # skip the draw
	vm._was_captured = true
	var anim: AnimationPlayer = vm.get_node("Model/AnimationPlayer")
	var sk: Skeleton3D = vm._skel
	var barrel := sk.find_bone(vm._kit.spin.bone)

	# Steps `secs`, the trigger (and the aim button) held as given; returns the shot times.
	var t := [0.0]
	var run := func(secs: float, trigger: bool, aim_held := false) -> Array:
		if trigger:
			Input.action_press("fire")
		else:
			Input.action_release("fire")
		var shots := []
		for i in roundi(secs / DT):
			t[0] += DT
			vm._since_fire += DT
			gs.player().cooldown = maxf(gs.player().cooldown - DT, 0.0)  # GameState's own tick, which we skip
			vm._spin(DT, aim_held)
			if trigger and vm._can_fire():
				vm.fire()
				if vm._since_fire == 0.0:
					shots.append(t[0])
		return shots

	var shots: Array = run.call(2.6, true)
	var first: float = shots[0] if shots else INF
	check.call(absf(first - 0.6) < 0.03, "first round once the barrels are up: %.2f s" % first)
	var early: float = shots[1] - shots[0] if shots.size() > 1 else 0.0
	var late: float = shots[-1] - shots[-2] if shots.size() > 1 else 0.0
	check.call(absf(early - 0.16) < 0.02 and absf(late - gs.GUNS[MINIGUN].interval) < 0.01,
		"rate climbs: %.3f s between the first rounds, %.3f s at the top (%d rounds in 2 s)" % [early, late, shots.size()])
	check.call(is_equal_approx(vm.walk_share, 0.5), "turning, the player walks at %.2f" % vm.walk_share)
	var snd: AudioStreamPlayer = vm._spin_sound
	check.call(snd.stream == vm.SPIN_LOOP and snd.playing and snd.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"firing plays the looping minigun sound, not a shot per round")

	anim.play(vm._kit.clips + "Idle")
	anim.seek(0.0, true)
	anim.advance(0.0)  # mixer_applied turns the barrels over the clip's pose
	var turned: float = sk.get_bone_pose_rotation(barrel).angle_to(sk.get_bone_rest(barrel).basis.get_rotation_quaternion())
	check.call(turned > 0.01, "barrels turned over the Idle pose: %.2f rad" % turned)

	run.call(0.65, false)
	var left: float = vm.spin
	check.call(left > 0.4 and left < 0.6, "let go, they run down: speed %.2f after 0.65 s" % left)
	check.call(snd.stream == vm.SPIN_STOP, "let go, the run-down sound takes over")
	shots = run.call(1.0, true)
	first = shots[0] - (t[0] - 1.0) if shots else INF
	check.call(first < 0.35, "pressed again, picks up from there: first round in %.2f s" % first)
	run.call(1.4, false)
	check.call(vm.spin == 0.0 and vm.walk_share == 1.0, "run down to a stop, full walking speed")

	shots = run.call(1.0, false, true)
	check.call(vm.spin == 1.0 and shots.is_empty(), "aim button turns them up, fires nothing")
	check.call(vm._kit.get("no_aim", false) and not vm._kit.has("rear"), "no sights to aim through")

	var sprint := anim.get_animation(vm._kit.clips + vm._kit.run)
	check.call(sprint != null and sprint.loop_mode == Animation.LOOP_LINEAR, "runs with its own looping %s clip" % vm._kit.run)

	Input.action_release("fire")
	print("minigun_check OK" if ok[0] else "minigun_check FAIL")
	quit(0 if ok[0] else 1)
