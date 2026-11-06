extends SceneTree
## The flashlight at night in first person, as the player sees it (PS1 screen as in Settings), in a few
## places: the open clearing, the wood's edge, in the wood, a wall up close:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/torch_shot.gd -- --tag=NAME
## Saves user://torch_<tag>_<spot>.png; the folder is printed. `--off`: the flashlight put away
## (what the night is without it). `--spots=a,b` only those.

## [feet, yaw (player.gd: looking along (-sin, 0, -cos)), pitch]
const SPOTS := {
	"open": [Vector3(16.0, 0.0, 6.0), -PI / 2.0, -0.12],
	"edge": [Vector3(30.0, 0.0, 18.0), -0.9, -0.08],
	"wood": [Vector3(52.0, 0.0, 22.0), -1.2, -0.1],
	"down": [Vector3(16.0, 0.0, 6.0), -PI / 2.0, -0.6],
	"wall": [Vector3(9.0, 0.0, 8.5), PI, -0.05],
	"feet": [Vector3(16.0, 0.0, 6.0), -PI / 2.0 - 0.4, -1.15],  # down at the lantern in the hand
}


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var player: CharacterBody3D = main.get_node("Player")
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var args := OS.get_cmdline_user_args()
	var tag := "now"
	var only: Array = []
	for a: String in args:
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--spots="):
			only = Array(a.trim_prefix("--spots=").split(","))
	gs.hour_rate = 0.0
	gs.hour = 0.0
	for f in 3:  # crossing dusk rolls a moon: pick after it
		await process_frame
	gs.request_debug_moon("full")
	if not "--off" in args and gs.has_method(&"request_toggle_torch"):
		gs.request_toggle_torch()
	print("pictures in ", OS.get_user_data_dir())
	for a: String in args:  # --set=property:value on the lamp, for trying things out
		if a.begins_with("--set="):
			var kv := a.trim_prefix("--set=").split(":")
			var lamp: Light3D = player.get(&"_lamp")
			lamp.set(kv[0], null if kv[1] == "null" else str_to_var(kv[1]))
	for spot: String in SPOTS:
		if not only.is_empty() and not spot in only:
			continue
		var s: Array = SPOTS[spot]
		var feet: Vector3 = s[0]
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(feet.x, 100.0, feet.z), Vector3(feet.x, -50.0, feet.z)))
		if not hit.is_empty():
			feet.y = hit.position.y + 0.05
		player.global_position = feet
		player.velocity = Vector3.ZERO
		player._yaw = s[1]
		player._pitch = s[2]
		player.reset_physics_interpolation()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2500:  # the lamp eases on, the beam catches up, TAA settles
			await process_frame
		root.get_texture().get_image().save_png("user://torch_%s_%s.png" % [tag, spot])
		print("saved torch_%s_%s.png" % [tag, spot])
	quit()
