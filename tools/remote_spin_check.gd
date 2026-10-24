extends SceneTree
## Headless check of another player's minigun sound (scripts/impacts.gd _on_fired, SPIN_GAP):
##   Godot.exe --headless --path . -s res://tools/remote_spin_check.gd
## Their rounds keep one firing loop going instead of a shot each; when the rounds stop it gives
## way to the run-down; a plain gun after it plays its own shot again.

const DT := 1.0 / 120.0
const MINIGUN := 4
const PEER := 2  # not us (1)


func _initialize() -> void:
	await process_frame  # root enters the tree first
	var gs: Node = root.get_node("GameState")
	var ok := [true]
	var check := func(good: bool, what: String) -> void:
		print(("ok   " if good else "FAIL ") + what)
		ok[0] = ok[0] and good

	var vm: Node3D = load("res://scenes/viewmodel.tscn").instantiate()  # its ShotSound is copied
	vm.set_process(false)
	root.add_child(vm)
	var fx := Node3D.new()
	fx.set_script(load("res://scripts/impacts.gd"))
	root.add_child(fx)
	fx.set_process(false)  # we step it ourselves
	await process_frame

	gs.player(PEER).gun = MINIGUN
	var step := func(secs: float, every: float) -> void:
		var since := every
		for i in roundi(secs / DT):
			since += DT
			if every > 0.0 and since >= every:
				since = 0.0
				gs.fired.emit(PEER, Vector3.ZERO, Vector3.FORWARD)
			fx._process(DT)

	step.call(1.0, 0.06)
	var p: AudioStreamPlayer3D = fx._shot_sounds[PEER]
	check.call(p.stream == vm.SPIN_LOOP and p.playing, "their minigun rounds play the loop")
	step.call(0.5, 0.16)  # a fresh spin-up's slow first rounds keep it going too
	check.call(p.stream == vm.SPIN_LOOP, "slow rounds keep the loop")
	step.call(0.6, 0.0)
	check.call(p.stream == vm.SPIN_STOP, "rounds stop: the run-down plays")
	gs.player(PEER).gun = 1
	step.call(0.1, 0.06)
	check.call(p.stream != vm.SPIN_LOOP and p.stream != vm.SPIN_STOP, "a plain gun plays its own shot again")

	print("remote_spin_check OK" if ok[0] else "remote_spin_check FAIL")
	quit(0 if ok[0] else 1)
