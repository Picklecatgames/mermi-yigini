extends SceneTree
## Photographs a later wave on its way (scripts/waves.gd roles): the crowd at its different speeds,
## the hurt ones with their bars over them. Off screen:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/roles_shot.gd -- --wave=10
## Saves user://roles_<wave>_<shot>.png.

## [shot, s after the pull, camera from, to]
const STEPS := [
	["bay", 6.0, Vector3(13.0, 2.4, -9.0), Vector3(26.0, 0.6, 2.0)],
	["bay", 8.0, Vector3(13.0, 2.4, -9.0), Vector3(26.0, 0.6, 2.0)],
	["close", 9.5, Vector3(13.2, 1.9, 0.0), Vector3(22.0, 1.0, 0.0)],
	["rail", 14.0, Vector3(11.0, 2.0, -7.0), Vector3(16.0, 0.8, 2.0)],
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
	var wave := 10
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--wave="):
			wave = a.trim_prefix("--wave=").to_int()
	gs.request_toggle_infinite_ammo()
	gs.request_select_gun(2)  # the Deagle: its rounds for the bars
	gs.cue_wave([&"phase", wave, waves.Phase.READY, 0, waves.FENCE_HP])
	gs.request_pull_lever()
	print("pulled wave %d: %s" % [wave, waves._queue])
	var t0 := Time.get_ticks_msec() / 1000.0
	for step: Array in STEPS:
		while Time.get_ticks_msec() / 1000.0 - t0 < step[1]:
			await process_frame
		_wound_some(waves, gs)
		cam.look_at_from_position(step[2], step[3])
		for f in 12:  # let TAA settle, not so long the bars fade
			await process_frame
		var path := "user://roles_%02d_%s_%04.1f.png" % [wave, step[0], step[1]]
		root.get_texture().get_image().save_png(path)
		var kinds := {}
		var speeds := {}
		for z: Dictionary in waves._zombies.values():
			if not z.dead:
				kinds[z.kind] = kinds.get(z.kind, 0) + 1
				speeds[z.kind] = "%.1f" % waves._pace(z)
		print("%s  standing %s, pace %s, fence %d" % [ProjectSettings.globalize_path(path), kinds, speeds, waves.fence])
	quit()


## One body round into every other zombie out in the hall, so their bars show.
func _wound_some(waves: Node, gs: Node) -> void:
	var i := 0
	for z: Dictionary in waves._zombies.values():
		var at: Vector3 = (z.node as Node3D).global_position
		if z.dead or at.x > 29.0 or waves._hp.get(z.id, 0) <= waves.DAMAGE.deagle:
			continue
		i += 1
		if i % 2 == 0:
			continue
		var hit: Vector3 = at + Vector3.UP * (z.trunk as Node3D).position.y
		waves._on_shot(gs.local_peer(), hit, Vector3.LEFT, Vector3.RIGHT, z.node, 1, false, 1)
