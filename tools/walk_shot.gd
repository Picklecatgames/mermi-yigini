extends SceneTree
## Photographs the dead on their way from the pens to the railing (scripts/waves.gd), for judging
## how they walk without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/walk_shot.gd -- --wave=4 --tag=after
## Nobody shoots. Every STEP s after the pull it saves user://walk_<tag>_<view>_<t>.png from above
## the bay and from behind the railing, and prints how the crowd stands: the nearest two (m), how
## many are clawing, how many are through a hole. `--hole=B` tears bay B down before the pull.

const STEP := 1.0
const UNTIL := 30.0
const VIEWS := {
	"top": [Vector3(20.0, 17.0, 0.0), Vector3(25.0, 0.0, 0.0)],
	"rail": [Vector3(9.5, 2.4, 9.0), Vector3(18.0, 0.8, -4.0)],
}


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.get_node("Player").free()  # its camera and HUD would take over; it stands as a pose below
	var gs := root.get_node("GameState")
	var waves: Node = main.get_node("Waves")
	var cam := Camera3D.new()
	main.add_child(cam)
	await process_frame
	var wave := 1
	var tag := "now"
	var hole := -1
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--wave="):
			wave = a.trim_prefix("--wave=").to_int()
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--hole="):
			hole = a.trim_prefix("--hole=").to_int()
	if wave != 1:
		gs.cue_wave([&"phase", wave, waves.Phase.READY, 0])
	gs.player().pos = gs.LEVER_POS + Vector3(0, 0, 0.6)
	gs.player().has_pose = true
	if hole >= 0:
		gs.hurt_fence(gs.FENCE_MAX, gs.bay_mid(hole) if gs.has_method("bay_mid") else 0.0)
	for i in 5:
		await process_frame
	gs.request_pull_lever()
	gs.player().pos = Vector3(6.0, 0.0, 0.0)  # out of the way, standing (the dead inside come for it)
	cam.make_current()
	var t0 := Time.get_ticks_msec() / 1000.0
	var t := STEP
	while t <= UNTIL:
		while Time.get_ticks_msec() / 1000.0 - t0 < t:
			await process_frame
		for view: String in VIEWS:
			cam.look_at_from_position(VIEWS[view][0], VIEWS[view][1])
			# From above, the roof and the lamps left out (build_arena.gd overhead()).
			cam.set_cull_mask_value(gs.OVERHEAD_LAYER, view != "top")
			await process_frame
			await process_frame
			var path := "user://walk_%s_%s_%04.1f.png" % [tag, view, t]
			root.get_texture().get_image().save_png(path)
		print("t %4.1f  %s" % [t, _crowd(waves)])
		t += STEP
	print("saved to ", ProjectSettings.globalize_path("user://"))
	quit()


func _crowd(waves: Node) -> String:
	var at: Array[Vector3] = []
	var clawing := 0
	var inside := 0
	for z: Dictionary in waves._zombies.values():
		if z.dead or not z.released:
			continue
		at.append((z.node as Node3D).global_position)
		if z.path.is_empty() and not z.get("inside", false):
			clawing += 1
		if z.get("inside", false):
			inside += 1
	var near := INF
	for i in at.size():
		for j in range(i + 1, at.size()):
			near = minf(near, Vector2(at[i].x - at[j].x, at[i].z - at[j].z).length())
	return "out %d, nearest two %.2f m, clawing %d, inside %d" % [at.size(), near, clawing, inside]
