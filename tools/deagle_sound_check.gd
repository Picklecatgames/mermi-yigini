extends SceneTree
## Headless check of the Deagle's own sounds (scripts/viewmodel.gd SETS deagle shot/cues, _cues):
##   Godot.exe --headless --path . -s res://tools/deagle_sound_check.gd
## The Deagle shoots its own shot, the UZI keeps the plain one; a reload clip plays its cues as it
## passes them, taking turns on MagSound and SlideSound.

const DEAGLE := 1
const UZI := 2


func _initialize() -> void:
	await process_frame
	var ok := [true]
	var check := func(good: bool, what: String) -> void:
		print(("ok   " if good else "FAIL ") + what)
		ok[0] = ok[0] and good

	var vm: Node3D = load("res://scenes/viewmodel.tscn").instantiate()
	vm.set_process(false)
	root.add_child(vm)
	await process_frame
	var shot: AudioStreamPlayer = vm._shot_sound
	check.call(shot.bus == vm.GUN_BUS and vm._dry_sound.bus == vm.GUN_BUS and vm._mag_sound.bus == vm.GUN_BUS,
		"our own gun's sounds play flat on the gun bus, not placed in the hall")
	var bus := AudioServer.get_bus_index(vm.GUN_BUS)
	check.call((AudioServer.get_bus_effect(bus, 0) as AudioEffectPanner).pan > 0.0, "the gun bus leans right")
	check.call(vm._dry_sound.stream.random_pitch <= vm.GUN_PITCH, "the dry click's pitch varies at most ±%.1f%%" % ((vm.GUN_PITCH - 1.0) * 100.0))
	vm._want_gun = UZI
	vm._swap()
	check.call(shot.stream == vm.plain_shot, "UZI keeps the plain shot")
	vm._want_gun = DEAGLE
	vm._swap()
	check.call(shot.stream == vm.SETS.deagle.shot, "Deagle shoots its own shot")

	var anim: AnimationPlayer = vm.get_node("Model/AnimationPlayer")
	var players := [vm._mag_sound, vm._slide_sound]
	for clip in ["reload", "reload_empty"]:
		vm._next_cue_player = 0
		vm._play(clip)
		var cues: Array = vm.SETS.deagle.cues[clip]
		var mid: float = cues[1][0] + 0.01
		var at_mid: AudioStream = null
		while anim.current_animation_position < anim.current_animation_length - 0.05:
			anim.advance(1.0 / 60.0)
			vm._cues()
			if at_mid == null and anim.current_animation_position >= mid:
				at_mid = players[1].stream  # the second cue went to SlideSound
		var n := cues.size()
		var last: AudioStream = players[(n - 1) % 2].stream
		check.call(at_mid == cues[1][1] and last == cues[n - 1][1] and vm._next_cue_player == n % 2,
			"%s: its %d cues play in turn as the clip passes them" % [clip, n])

	print("deagle_sound_check OK" if ok[0] else "deagle_sound_check FAIL")
	quit(0 if ok[0] else 1)
