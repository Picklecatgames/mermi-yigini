extends SceneTree
## The hall's lighting on the players: the five characters standing round the hall as other
## players (scripts/remote_players.gd), each from up close, the hall with them in it, and our own
## arms and gun in first person, for checking the light without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/light_shot.gd
## Add `-- --tag=NAME` to save user://light_NAME_<shot>.png (before/after); the folder is printed.

## peer -> [character, feet, the point it faces]. Under the glass, at the spawns, round the heap's
## foot, right under a hall lamp (0, 14), between two of them and out in the dark west side.
const CREW := {
	2: ["oldman", Vector3(5.0, 0, -2.0), Vector3(12.0, 0, 3.0)],
	3: ["oldman", Vector3(8.7, 0, 2.4), Vector3(14.0, 0, 6.0)],
	4: ["oldman", Vector3(0.8, 0, 15.0), Vector3(8.0, 0, 12.0)],
	5: ["oldman", Vector3(6.0, 0, 15.5), Vector3(12.0, 0, 12.0)],
	6: ["oldman", Vector3(-18.0, 0, 10.0), Vector3(-10.0, 0, 14.0)],
}
## Wide shots: [camera, look-at].
const WIDE := {
	"hall": [Vector3(12.5, 1.7, 9.0), Vector3(-2.0, 1.0, 2.0)],
	"heapside": [Vector3(10.0, 1.7, -8.0), Vector3(-2.0, 1.0, 8.0)],
}
## First person: [feet, yaw, pitch].
const FP := {
	"fp_heap": [Vector3(8.7, 0, -0.8), PI / 2.0, -0.1],
	"fp_range": [Vector3(10.0, 0, 6.0), -PI / 2.0, 0.0],
	"fp_lamps": [Vector3(4.0, 0, 20.0), PI, -0.2],
}
## The hall lamps' own shadows, out of the moon's reach on the west side: [feet, the point it
## faces]. Just off the bulb at (-18, 6.8, 7), and halfway to the next one at (-18, -7), where
## each throws its own shadow, one either way. Shot with the moon on and off.
const LAMP_FEET := {
	"under": [Vector3(-17.2, 0, 7.8), Vector3(-10.0, 0, 9.0)],
	"between": [Vector3(-18.0, 0, 0.0), Vector3(-10.0, 0, 1.0)],
}
## First person looking down at our own shadow under that lamp: [feet, yaw, pitch].
const FP_FEET := {
	"fp_feet_lamp": [Vector3(-17.2, 0, 7.8), -PI / 2.0, -1.1],
	"fp_feet_moon": [Vector3(2.0, 0, -5.0), PI / 2.0, -1.1],
}

var mgr: Node3D
var gs: Node
var stand := CREW.duplicate(true)  # where each of the crew stands now


func _initialize() -> void:
	var tag := "shot"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	gs = root.get_node("GameState")
	gs.player().character = "oldman"
	gs.player().gun = 1
	for peer: int in CREW:
		gs.player(peer).character = CREW[peer][0]
		gs.player(peer).gun = 1
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	mgr = main.get_node("RemotePlayers")
	var player: Node3D = main.get_node("Player")
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.cull_mask &= ~(1 << 1)  # not our own arms, which only the gun's camera draws
	main.add_child(cam)
	await _hold(0.5)
	gs.player().character = "oldman"  # before the tree, the local peer was not known yet
	gs.character_changed.emit(gs.local_peer(), "oldman")
	await _hold(1.0)
	var pick := root.find_child("CharacterPick", true, false)
	if pick:  # the pick screen: everyone has already picked
		pick.visible = false
		pick.process_mode = Node.PROCESS_MODE_DISABLED
	var hud_nodes: Array = []
	for n in player.get_children():
		if n != pick and (n is CanvasItem or n is CanvasLayer):
			hud_nodes.append(n)
	for n in main.get_children():
		if n is CanvasLayer:
			hud_nodes.append(n)
	print("pictures in ", OS.get_user_data_dir())

	# Third person: our own body and the gun's view off, a plain camera.
	for n in hud_nodes:
		n.visible = false
	cam.make_current()
	for shot: String in WIDE:
		cam.look_at_from_position(WIDE[shot][0], WIDE[shot][1])
		await _save(tag, shot)
	cam.fov = 40.0
	for peer: int in CREW:
		var feet: Vector3 = CREW[peer][1]
		var dir: Vector3 = (CREW[peer][2] - feet).normalized()
		cam.look_at_from_position(feet + dir * 2.6 + Vector3(0.5, 1.55, 0.0), feet + Vector3(0, 1.2, 0))
		await _save(tag, "close_" + CREW[peer][0])
	# Down at the feet: does the shadow start at the soles and fall away from the light over it?
	cam.fov = 50.0
	for peer: int in [2, 4, 5]:
		var feet: Vector3 = CREW[peer][1]
		var dir: Vector3 = (CREW[peer][2] - feet).normalized()
		cam.look_at_from_position(feet + dir * 2.2 + dir.cross(Vector3.UP) * 1.2 + Vector3(0, 1.1, 0), feet + Vector3(0, 0.25, 0))
		await _save(tag, "feet_" + CREW[peer][0])
	# The lamps alone (the moon off), then with it: under one bulb and between two.
	var sun := main.find_child("Sun", true, false) as Light3D
	for moon: bool in [false, true]:
		sun.visible = moon
		for spot: String in LAMP_FEET:
			stand[6] = ["oldman", LAMP_FEET[spot][0], LAMP_FEET[spot][1]]
			var feet: Vector3 = LAMP_FEET[spot][0]
			var dir: Vector3 = (LAMP_FEET[spot][1] - feet).normalized()
			cam.look_at_from_position(feet + dir * 3.2 + Vector3(0, 2.4, 0), feet)
			await _save(tag, "lamp_%s%s" % [spot, "_moon" if moon else ""])
	sun.visible = true
	stand[6] = CREW[6].duplicate()

	# First person: the player's own camera and the gun's viewport over it, no menus.
	player.get_node("ViewmodelView").visible = true
	player.get_node("Head/Camera3D").make_current()
	for shot: String in FP:
		player.global_position = FP[shot][0]
		player.velocity = Vector3.ZERO
		player._yaw = FP[shot][1]
		player._pitch = FP[shot][2]
		await _save(tag, shot)
	# Our own shadow (remote_players.gd _own_shadow), the gun's view off to see the floor.
	player.get_node("ViewmodelView").visible = false
	for shot: String in FP_FEET:
		player.global_position = FP_FEET[shot][0]
		player.velocity = Vector3.ZERO
		player._yaw = FP_FEET[shot][1]
		player._pitch = FP_FEET[shot][2]
		await _save(tag, shot)
	quit()


func _save(tag: String, shot: String) -> void:
	await _hold(0.6)
	await RenderingServer.frame_post_draw
	var path := "user://light_%s_%s.png" % [tag, shot]
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


## Keeps the crew standing where they are, facing their points, for `secs`.
func _hold(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		for peer: int in stand:
			var d: Vector3 = stand[peer][2] - stand[peer][1]
			mgr._on_pose(peer, Time.get_ticks_msec() / 1000.0, stand[peer][1], atan2(-d.x, -d.z), 0.0, 0, false)
		await process_frame
