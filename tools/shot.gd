extends SceneTree
## Renders main.tscn from fixed cameras and saves PNGs, for checking visuals without playing.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/shot.gd
## Add `-- --gold=N` to give the local player N gold first (the desk's cash heap follows it).
## Add `-- --dig` to drain 3M bullets from one spot on the heap first; name shots after `--` to take only those.

const SHOTS := {
	"far": [Vector3(0, 1.6, 15), Vector3(0, 2.0, 0)],
	"mid": [Vector3(0, 1.6, 10.5), Vector3(0, 1.0, 6.0)],
	"near": [Vector3(0, 1.6, 8.8), Vector3(0, 0.6, 7.6)],
	"rim": [Vector3(1.5, 1.4, 11.5), Vector3(0, 0.0, 8.5)],
	"toe": [Vector3(0.5, 1.0, 10.2), Vector3(0, 0.0, 8.3)],
	"floor": [Vector3(0, 1.6, 22), Vector3(10, 0, 12)],
	"dig": [Vector3(9.5, 4.0, 4.0), Vector3(4.0, 1.5, 0.0)],
	"range": [Vector3(9.0, 1.6, 7.0), Vector3(26.0, 1.2, -1.0)],
	"bay": [Vector3(25.0, 1.6, 2.0), Vector3(44.0, 1.0, 0.0)],
	"place": [Vector3(12.0, 4.6, 9.0), Vector3(26.0, 0.0, 0.0)],
	"wall": [Vector3(16.0, 1.6, 10.0), Vector3(22.0, 1.5, 27.9)],
	"north": [Vector3(17.0, 1.7, -18.0), Vector3(22.0, 1.2, -27.9)],
	"crew": [Vector3(6.0, 1.7, 20.0), Vector3(11.0, 1.4, 27.9)],
	"gear": [Vector3(7.0, 1.7, -20.0), Vector3(11.0, 1.5, -27.9)],
	"mouth": [Vector3(13.0, 2.2, 0.0), Vector3(28.0, 3.6, 0.0)],
	"site_n": [Vector3(-3.0, 1.6, -7.0), Vector3(-12.0, 0.4, -14.0)],
	"site_s": [Vector3(-3.0, 1.6, 7.0), Vector3(-12.0, 0.4, 14.0)],
	"spawn": [Vector3(-9.0, 1.7, 23.5), Vector3(-9.0, 2.5, 0.0)],
	"boards": [Vector3(5.5, 1.7, 22.0), Vector3(5.5, 1.6, 27.9)],
	"heap_sun": [Vector3(4.0, 1.7, 12.0), Vector3(-9.0, 3.5, 0.0)],
	"camp": [Vector3(-14.0, 1.7, -16.0), Vector3(-22.0, 1.0, -25.0)],
	"door": [Vector3(-8.0, 1.7, 14.0), Vector3(-6.0, 1.0, 28.0)],
	"west": [Vector3(-17.5, 1.7, 7.0), Vector3(-28.0, 2.0, -3.0)],
	"walk0": [Vector3(-2.00, 1.7, -12.00), Vector3(-23.0, 1.5, -26.0)],
	"walk1": [Vector3(-4.50, 1.7, -13.64), Vector3(-23.0, 1.5, -26.0)],
	"walk2": [Vector3(-7.00, 1.7, -15.29), Vector3(-23.0, 1.5, -26.0)],
	"walk3": [Vector3(-9.50, 1.7, -16.93), Vector3(-23.0, 1.5, -26.0)],
	"walk4": [Vector3(-12.00, 1.7, -18.57), Vector3(-23.0, 1.5, -26.0)],
	"walk5": [Vector3(-14.50, 1.7, -20.21), Vector3(-23.0, 1.5, -26.0)],
	"walk6": [Vector3(-17.00, 1.7, -21.86), Vector3(-23.0, 1.5, -26.0)],
	"walk7": [Vector3(-19.50, 1.7, -23.50), Vector3(-23.0, 1.5, -26.0)],
	"stands": [Vector3(-18.5, 1.8, -1.0), Vector3(-23.0, 1.0, 9.0)],
	"stands_south": [Vector3(-18.5, 1.8, 1.0), Vector3(-23.0, 1.0, -10.0)],
	"stands_front": [Vector3(-14.5, 1.7, 3.0), Vector3(-23.0, 1.0, 3.0)],
	"stands_legend": [Vector3(-17.0, 1.7, -5.0), Vector3(-23.0, 1.2, -12.0)],
	"up": [Vector3(0.0, 1.7, 6.0), Vector3(-6.0, 9.0, -4.0)],
	"desk": [Vector3(5.0, 1.7, 22.3), Vector3(5.0, 0.9, 25.5)],
	"cash": [Vector3(5.4, 1.45, 24.1), Vector3(5.12, 0.95, 25.45)],
	"bulb": [Vector3(1.3, 6.2, 15.3), Vector3(0.0, 6.85, 14.0)],
	"workshop": [Vector3(10.0, 1.7, 21.5), Vector3(10.8, 1.6, 27.9)],
	"lamps": [Vector3(2.0, 1.7, 16.0), Vector3(-2.0, 6.5, 2.0)],
	"tripod": [Vector3(-12.5, 1.7, -14.5), Vector3(-16.4, 1.9, -9.6)],
	"graf_w": [Vector3(-21.5, 1.7, 13.0), Vector3(-28.0, 1.5, 17.0)],
	"graf_s": [Vector3(-17.0, 1.7, 21.0), Vector3(-19.0, 1.4, 28.0)],
	"graf_n": [Vector3(12.0, 1.7, -21.0), Vector3(11.0, 1.4, -28.0)],
	"squat": [Vector3(-22.6, 1.6, 23.0), Vector3(-25.4, 0.4, 26.0)],
	"rubble": [Vector3(-24.5, 1.5, -7.2), Vector3(-27.0, 0.2, -9.5)],
	"tyres": [Vector3(3.5, 1.7, -22.5), Vector3(0.0, 0.5, -27.5)],
	"puddle": [Vector3(-7.0, 1.7, 21.0), Vector3(-13.0, 0.0, 16.0)],
	"lining_s": [Vector3(17.0, 1.6, 22.0), Vector3(21.0, 1.2, 27.9)],
	"lining_e": [Vector3(22.0, 1.6, 17.0), Vector3(27.9, 1.2, 21.0)],
	"rubber": [Vector3(15.5, 1.7, -3.0), Vector3(21.0, 0.0, -8.0)],
	"lining_close": [Vector3(26.0, 1.5, 15.5), Vector3(27.9, 0.9, 18.5)],
	"brass": [Vector3(15.0, 1.5, -6.0), Vector3(15.8, 0.0, -4.5)],
}


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()  # no mouse capture, no HUD
	root.add_child(main)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.make_current()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--gold="):
			await process_frame
			var gs := root.get_node("GameState")
			gs.player().gold = a.trim_prefix("--gold=").to_int()
			gs.gold_changed.emit(gs.player().gold)
	if "--dig" in OS.get_cmdline_user_args():
		await process_frame
		var pile: Node3D = main.get_node("Pile")
		var at := pile.to_global(Vector3(4.0, 0.0, 0.0))
		for i in 150:
			root.get_node("GameState").request_take_bullets(20000, at)
			await physics_frame
		for i in 400:
			await physics_frame
	var only := Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool: return SHOTS.has(a))
	for shot_name in (only if not only.is_empty() else SHOTS.keys()):
		cam.look_at_from_position(SHOTS[shot_name][0], SHOTS[shot_name][1])
		for f in 30:  # let TAA settle
			await process_frame
		root.get_texture().get_image().save_png("user://shot_%s.png" % shot_name)
		print("saved ", ProjectSettings.globalize_path("user://shot_%s.png" % shot_name))
	quit()
