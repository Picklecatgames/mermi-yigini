extends SceneTree
## Pulls the wave lever and photographs the sequence (scripts/waves.gd), for checking it without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/wave_shot.gd
## Add `-- --wave=N` to start at wave N (from waves.BLOB_FROM a roll with a blob in it is picked).
## Saves user://wave_<n>_<shot>.png: the lever up, swinging down, the alarms lit, the gates open, the
## dead on their way and at the railing.

const SHOT := preload("res://tools/shot.gd")
## [shot, s after the pull, camera from, to (null: from shot.gd)]
const STEPS := [
	["lever", -1.0, null, null],
	["lever_far", -1.0, null, null],
	["lever", 0.4, null, null],
	["lever_far", 1.4, null, null],
	["bay", 4.8, null, null],
	["mouth", 9.0, null, null],
	["range", 14.0, null, null],
	["rail", 18.0, Vector3(11.0, 1.8, -6.0), Vector3(15.0, 0.8, 2.0)],
	["rail", 26.0, Vector3(11.0, 1.8, -6.0), Vector3(15.0, 0.8, 2.0)],
	["range", 60.0, null, null],  # nobody shot them: the railing fell, the wave waits again
]


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()  # no mouse capture, no HUD
	root.add_child(main)
	var gs := root.get_node("GameState")
	var waves: Node = main.get_node("Waves")
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.make_current()
	await process_frame
	var wave := 1
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--wave="):
			wave = a.trim_prefix("--wave=").to_int()
	if wave >= waves.BLOB_FROM:
		var seed := 0
		while true:
			waves._rng.seed = seed
			if waves._plan(wave).has(&"blob"):
				break
			seed += 1
		waves._rng.seed = seed
	if wave != 1:
		gs.cue_wave([&"phase", wave, waves.Phase.READY, 0])
	var t0 := -1.0
	for step: Array in STEPS:
		if step[1] >= 0.0 and t0 < 0.0:
			gs.request_pull_lever()
			print("pulled: phase %d, %d to come %s" % [waves.phase, waves.left, waves._queue])
			t0 = Time.get_ticks_msec() / 1000.0
		while t0 >= 0.0 and Time.get_ticks_msec() / 1000.0 - t0 < step[1]:
			await process_frame
		var from: Vector3 = step[2] if step[2] != null else SHOT.SHOTS[step[0]][0]
		var to: Vector3 = step[3] if step[3] != null else SHOT.SHOTS[step[0]][1]
		cam.look_at_from_position(from, to)
		for f in 20:  # let TAA settle
			await process_frame
		var path := "user://wave_%02d_%s_%s.png" % [wave, step[0], "before" if step[1] < 0.0 else "%04.1f" % step[1]]
		root.get_texture().get_image().save_png(path)
		var kinds := {}
		for z: Dictionary in waves._zombies.values():
			kinds[z.kind] = kinds.get(z.kind, 0) + 1
		print("%s  lever %s, lit %s, gates %s, phase %d, fence %d, standing %s, nearest x %.1f" % [
				ProjectSettings.globalize_path(path), "down" if waves._lever_anim.current_animation_position > 0.01 else "up",
				waves._lit, waves._gates_open, waves.phase, waves.fence, kinds, _nearest(waves)])
	quit()


func _nearest(waves: Node) -> float:
	var x := INF
	for z: Dictionary in waves._zombies.values():
		if not z.dead:
			x = minf(x, (z.node as Node3D).global_position.x)
	return x
