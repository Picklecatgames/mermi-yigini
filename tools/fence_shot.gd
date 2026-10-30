extends SceneTree
## Photographs the railing worn and the HUD with it (scripts/fence.gd, hud.gd), for checking it
## without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/fence_shot.gd
## Saves user://fence_<shot>.png: whole, worn bay by bay, sparks off a claw, a bay torn down close,
## at the desk with the repair hint, the wave lost.

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs := root.get_node("GameState")
	var waves: Node = main.get_node("Waves")
	var me: CharacterBody3D = main.get_node("Player")
	await process_frame
	gs.start_quests()
	gs.request_take_pistol()
	for q in 40:  # past the warmup: the whole HUD
		if not gs.warming():
			break
		var w: String = gs.quest_board[0]
		gs.quest_add(gs.QUESTS[w].kind, gs.quest_target(w))
		if gs.QUESTS[w].kind == "board_claim":
			gs.request_claim_quests()
	var look := func(from: Vector3, at: Vector3) -> void:
		me.global_position = from
		me.reset_physics_interpolation()
		var d: Vector3 = at - (from + Vector3.UP * 1.6)
		me._yaw = atan2(-d.x, -d.z)
		me._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	var bay := func(b: int) -> float:
		return -gs.FENCE_SPAN + (b + 0.5) * gs.FENCE_SPAN * 2.0 / gs.FENCE_BAYS
	look.call(Vector3(10.5, 0, -7.0), Vector3(14.0, 0.7, 2.0))
	await _settle(40)
	_save("whole")
	for w: Array in [[8, 2], [9, 4], [10, 9], [11, 6], [12, 3], [13, 1], [14, 8]]:
		gs.hurt_fence(w[1], bay.call(w[0]))
	gs.hurt_fence(30, bay.call(5))
	await _settle(80)
	_save("worn")
	for i in 4:
		waves._fence.struck(bay.call(11) + randf_range(-1.0, 1.0), &"walker")
	await _settle(4)
	_save("sparks")
	look.call(Vector3(12.0, 0, 0.4), Vector3(14.0, 0.4, 2.6))
	await _settle(40)
	_save("torn")
	look.call(gs.REPAIR_POS + Vector3(1.4, 0, 0.3), gs.REPAIR_POS + Vector3(0, 0.8, 0))
	await _settle(30)
	_save("desk")
	look.call(Vector3(10.5, 0, -7.0), Vector3(14.0, 0.7, 2.0))
	gs.cue_wave([&"phase", 1, waves.Phase.FAILED, 0])
	await _settle(40)
	_save("lost")
	quit()


func _settle(frames: int) -> void:
	for f in frames:  # let TAA settle and the wear ease in
		await process_frame


func _save(name: String) -> void:
	var path := "user://fence_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
