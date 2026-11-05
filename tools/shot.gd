extends SceneTree
## Renders main.tscn from fixed cameras and saves PNGs, for checking visuals without playing.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/shot.gd
## Add `-- --gold=N` to give the local player N gold first (the desk's cash heap follows it).
## Add `-- --open` to finish every quest that opens something first (the bench, hopper, press drop in).
## Add `-- --dig` to drain 3M pieces from one spot at the foot of the scrap heap's face first, and
## `--collapse` to make the face give way there just before the shots (pieces still tumbling in the
## first); name shots after `--` to take only those.
## Add `--lamp` for a player's head lamp at the camera (it lights itself when the sun goes), `--moon=KIND`
## for tonight's moon (GameState.MOONS, or boss), `--tag=NAME` to add a name to the files, `--psx=N` for
## Settings' "PS1 ekranı" N (2: 270 lines), as the player sees it, not from the developer's own settings.
## `--zombie=X,Z` puts a walker up there, facing -x, seen a moment after it's up.

const SHOTS := {
	"ev_on": [Vector3(21.0, 1.7, 7.0), Vector3(6.0, 2.2, 0.5)],  # build_world.gd: the house from the yard
	"ev_arka": [Vector3(-4.5, 1.7, 2.5), Vector3(6.0, 2.2, -1.0)],  # from the mountain's side, the back door
	"ev_kuzey": [Vector3(8.0, 1.7, -16.0), Vector3(5.5, 2.2, -2.0)],
	"ev_kose": [Vector3(-7.0, 2.2, -13.0), Vector3(5.0, 2.2, -3.0)],
	"ev_uzak": [Vector3(44.0, 9.0, 26.0), Vector3(4.0, 1.0, -2.0)],
	"ev_spawn": [Vector3(7.3, 1.7, 0.9), Vector3(2.2, 1.1, 0.0)],  # what a player sees first: the crate, the TV, the mountain's window
	"ev_tv": [Vector3(3.9, 1.5, 0.2), Vector3(2.2, 0.95, 0.0)],
	"ev_tv_yakin": [Vector3(2.95, 1.05, 0.0), Vector3(2.2, 0.95, 0.0)],
	"ev_tezgah": [Vector3(5.2, 1.7, -4.6), Vector3(4.6, 1.0, -7.8)],  # the wing, from the way in
	"ev_atolye": [Vector3(8.2, 1.7, -4.5), Vector3(2.0, 1.0, -7.0)],
	"ev_soba": [Vector3(5.2, 1.7, 0.4), Vector3(8.4, 0.9, -2.2)],
	"ev_ampul": [Vector3(5.0, 1.7, 0.9), Vector3(6.3, 2.5, 0.2)],
	"ev_masa": [Vector3(4.9, 1.7, -0.5), Vector3(6.9, 0.7, 2.8)],
	"ev_kapi": [Vector3(4.0, 1.7, -1.2), Vector3(1.6, 1.5, -3.0)],  # the back door: the mountain through it
	"ev_veranda": [Vector3(6.0, 1.7, 0.9), Vector3(12.5, 1.5, 0.9)],  # through the veranda to the wood
	"ev_yatak": [Vector3(4.4, 1.7, 1.6), Vector3(2.6, 0.7, 3.2)],
	"ev_ic": [Vector3(8.4, 2.3, 3.2), Vector3(2.4, 0.9, -1.8)],
	"overview": [Vector3(80.0, 45.0, 0.0), Vector3(0.0, 0.0, 0.0)],
	"desert": [Vector3(18.0, 1.7, 4.0), Vector3(80.0, 2.0, 40.0)],
	"junk_front": [Vector3(-3.0, 1.7, 0.0), Vector3(-40.0, 5.0, 0.0)],
	"junk_near": [Vector3(-14.0, 1.7, 12.0), Vector3(-36.0, 2.0, -4.0)],
	"junk_edge": [Vector3(8.0, 1.7, 22.0), Vector3(-30.0, 6.0, 45.0)],
	"junk_side": [Vector3(0.0, 1.7, -24.0), Vector3(-35.0, 6.0, -45.0)],
	"junk_seam": [Vector3(-24.0, 7.5, -3.0), Vector3(-52.0, 16.0, -8.0)],  # where the real pieces end and the drawn ones start
	"junk_close": [Vector3(-9.5, 1.7, -2.0), Vector3(-15.5, 0.9, -0.5)],  # a player at the foot
	"junk_top": [Vector3(35.0, 70.0, 0.0), Vector3(-30.0, 0.0, 0.0)],
	# y under 0: over the ground there, by that much (the map's limit lies up on the hills).
	"wall_east": [Vector3(208.0, -1.7, 8.0), Vector3(235.0, -1.0, 2.0)],
	"wall_near": [Vector3(205.0, -1.7, 90.0), Vector3(222.0, -1.0, 110.0)],
	"wall_north": [Vector3(30.0, -1.7, -170.0), Vector3(36.0, -1.0, -205.0)],
	"rim_top": [Vector3(190.0, -45.0, 0.0), Vector3(235.0, -1.0, 0.0)],
	"rim_low": [Vector3(218.0, -2.0, 4.0), Vector3(232.0, -2.5, 4.0)],
	"far_walk": [Vector3(120.0, -1.7, 20.0), Vector3(180.0, -8.0, 26.0)],
	"wood_up": [Vector3(46.0, 1.7, -2.0), Vector3(50.0, 14.0, 1.0)],
	"wood_front": [Vector3(11.0, 1.7, 1.0), Vector3(60.0, 9.0, 0.0)],
	"wood_near": [Vector3(38.0, 1.7, -6.0), Vector3(70.0, 8.0, 6.0)],
	"wood_floor": [Vector3(44.0, 1.7, -8.0), Vector3(56.0, -0.5, -3.0)],
	"wood_edge": [Vector3(30.0, 1.7, 22.0), Vector3(46.0, 0.5, 32.0)],
	"wood_in": [Vector3(70.0, 1.7, 20.0), Vector3(100.0, 5.0, 30.0)],
	"forest_edge": [Vector3(30.0, 1.7, 8.0), Vector3(90.0, 3.0, 25.0)],
	"night_yard": [Vector3(4.0, 1.7, -9.0), Vector3(60.0, 4.0, -9.0)],  # the yard to the wood, the burn barrel in frame on the right
	"night_edge": [Vector3(30.0, 1.7, -6.0), Vector3(70.0, 3.0, -8.0)],  # standing a few metres off the first trees
	"night_foot": [Vector3(16.0, 1.7, -9.0), Vector3(21.0, 0.2, -5.0)],  # the ground at the player's feet
	"night_close": [Vector3(46.0, 1.7, -2.0), Vector3(55.0, 1.5, -2.0)],  # the first trees, lamp on them
	"night_walk1": [Vector3(52.0, 1.7, -2.0), Vector3(70.0, 2.0, -2.0)],  # walking in: nothing pops, no sheet's edge
	"night_walk2": [Vector3(58.0, 1.7, -2.0), Vector3(76.0, 2.0, -2.0)],
	"night_walk3": [Vector3(64.0, 1.7, -2.0), Vector3(82.0, 2.0, -2.0)],
	"forest_in": [Vector3(75.0, 1.9, 30.0), Vector3(100.0, 2.0, 55.0)],
	"desert_back": [Vector3(10.0, 2.5, 18.0), Vector3(-80.0, 4.0, 50.0)],
	"far": [Vector3(0, 1.6, 15), Vector3(0, 2.0, 0)],
	"mid": [Vector3(0, 1.6, 10.5), Vector3(0, 1.0, 6.0)],
	"near": [Vector3(0, 1.6, 8.8), Vector3(0, 0.6, 7.6)],
	"rim": [Vector3(1.5, 1.4, 11.5), Vector3(0, 0.0, 8.5)],
	"toe": [Vector3(0.5, 1.0, 10.2), Vector3(0, 0.0, 8.3)],
	"floor": [Vector3(0, 1.6, 22), Vector3(10, 0, 12)],
	"dig": [Vector3(9.5, 4.0, 4.0), Vector3(4.0, 1.5, 0.0)],
	"range": [Vector3(9.0, 1.6, 7.0), Vector3(26.0, 1.2, -1.0)],
	"bay": [Vector3(25.0, 1.6, 2.0), Vector3(36.0, 1.0, 0.0)],
	"place": [Vector3(12.0, 4.6, 9.0), Vector3(26.0, 0.0, 0.0)],
	"wall": [Vector3(16.0, 1.6, 10.0), Vector3(22.0, 1.5, 27.9)],
	"north": [Vector3(17.0, 1.7, -18.0), Vector3(22.0, 1.2, -27.9)],
	"crew": [Vector3(6.0, 1.7, 20.0), Vector3(11.0, 1.4, 27.9)],
	"gear": [Vector3(7.0, 1.7, -20.0), Vector3(11.0, 1.5, -27.9)],
	"lever": [Vector3(8.2, 1.7, -24.5), Vector3(8.2, 1.6, -27.9)],  # the wave lever and its sign (GameState.LEVER_POS)
	"lever_far": [Vector3(2.0, 1.7, -16.0), Vector3(9.0, 1.4, -27.9)],
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
	"crate_lamps": [Vector3(-20.6, 0.7, 5.0), Vector3(-22.2, 0.2, 3.3)],
	"crate_lamp_close": [Vector3(-21.3, 0.55, 4.5), Vector3(-22.0, 0.1, 3.6)],
	"rounds_close": [Vector3(-21.0, 0.7, -8.6), Vector3(-22.5, 0.0, -9.75)],
	"stands_front": [Vector3(-14.5, 1.7, 3.0), Vector3(-23.0, 1.0, 3.0)],
	"stands_legend": [Vector3(-17.0, 1.7, -5.0), Vector3(-23.0, 1.2, -12.0)],
	"up": [Vector3(0.0, 1.7, 6.0), Vector3(-6.0, 9.0, -4.0)],
	"scrap_spawn": [Vector3(8.7, 1.7, 0.0), Vector3(-6.0, 3.5, 0.0)],
	"scrap_wide": [Vector3(12.0, 2.2, 18.0), Vector3(-8.0, 4.0, -4.0)],
	"scrap_north": [Vector3(6.0, 1.8, -22.0), Vector3(-8.0, 4.0, -8.0)],
	"scrap_close": [Vector3(0.5, 1.7, 3.5), Vector3(-4.0, 1.2, 1.0)],
	"scrap_fall": [Vector3(3.0, 2.0, 7.5), Vector3(-5.0, 2.0, 1.0)],
	"scrap_macro": [Vector3(0.5, 1.3, 2.0), Vector3(-2.5, 0.5, 1.0)],
	"scrap_touch": [Vector3(-1.2, 1.4, 1.6), Vector3(-3.0, 0.9, 1.0)],
	"scrap_roof":[Vector3(2.0, 1.7, -3.0), Vector3(-9.0, 9.5, 0.0)],
	"pit_rim": [Vector3(0.5, 1.7, 12.5), Vector3(-12.0, -0.5, 0.0)],  # the scrap pit from its south-east corner
	"pit_ladder": [Vector3(1.0, 1.7, 2.5), Vector3(-2.6, -1.5, -0.5)],  # the east side's gap and ladder down
	"desk": [Vector3(5.0, 1.7, 22.3), Vector3(5.0, 0.9, 25.5)],
	"ogutucu": [Vector3(1.1, 1.7, 18.8), Vector3(4.5, 0.8, 21.0)],
	"ogutucu_yakin": [Vector3(3.0, 1.7, 20.6), Vector3(4.2, 0.95, 21.3)],
	"cash": [Vector3(5.4, 1.45, 24.1), Vector3(5.12, 0.95, 25.45)],
	"bulb": [Vector3(1.3, 6.2, 15.3), Vector3(0.0, 6.85, 14.0)],
	"workshop": [Vector3(10.0, 1.7, 21.5), Vector3(10.8, 1.6, 27.9)],
	"festoon": [Vector3(11.8, 1.9, 25.2), Vector3(10.6, 2.9, 27.9)],
	"festoon_up": [Vector3(9.0, 1.7, 17.0), Vector3(12.0, 6.5, 22.0)],
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
	"press": [Vector3(11.0, 1.6, 25.6), Vector3(11.3, 1.25, 27.4)],
	"press_corner": [Vector3(9.5, 1.7, 22.0), Vector3(10.8, 1.2, 27.0)],
}


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()  # no mouse capture, no HUD
	root.add_child(main)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.make_current()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--psx="):
			await process_frame
			var settings: Node = root.get_node("Settings")
			settings.save_path = "user://settings_shots.cfg"  # never the developer's own
			settings.set_value("psx", a.trim_prefix("--psx=").to_int())
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--gold="):
			await process_frame
			var gs := root.get_node("GameState")
			gs.player().gold = a.trim_prefix("--gold=").to_int()
			gs.gold_changed.emit(gs.player().gold)
	if "--open" in OS.get_cmdline_user_args():
		await process_frame
		var gs := root.get_node("GameState")
		for id: String in gs.QUESTS:
			if gs.QUESTS[id].has("unlock") and id not in gs.quests_done:
				gs.quests_done.append(id)
				gs.quest_done.emit(id, 0)
		await create_timer(14.0).timeout  # the drops and their beams (reveal.gd)
	if "--dig" in OS.get_cmdline_user_args():
		await process_frame
		var at := Vector3(-4.0, 0.0, 2.0)
		for i in 150:
			root.get_node("GameState").request_take_bullets(20000, at)
			await physics_frame
		for i in 400:
			await physics_frame
	if "--collapse" in OS.get_cmdline_user_args():
		await process_frame
		root.get_node("GameState").collapse_scrap(Vector2i(95, 120), 12, 5)
	var tag := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--hour="):  # the clock stopped at this hour (22: night), the moon's light with it
			await process_frame
			var gs := root.get_node("GameState")
			gs.hour_rate = 0.0
			gs.hour = a.trim_prefix("--hour=").to_float()
			tag = "_h" + a.trim_prefix("--hour=")
			for f in 3:  # crossing dusk rolls a moon: pick after it
				await process_frame
			for b: String in OS.get_cmdline_user_args():
				if b.begins_with("--moon="):
					gs.moon = b.trim_prefix("--moon=")
			for f in 10:
				await process_frame
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--zombie="):
			var at := a.trim_prefix("--zombie=").split_floats(",")
			root.get_node("GameState").request_debug_spawn("walker", Vector3(at[0], 0.0, at[1]), PI / 2.0, 1)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--news="):  # --news=DAY,LINE: the television on that day's bulletin, at that line
			var nd := a.trim_prefix("--news=").split_floats(",")
			var gs := root.get_node("GameState")
			gs.news_day = int(nd[0])
			gs.news_at = int(nd[1])
			gs._news_wait = 1000.0
			gs.news_line.emit(gs.news_day, gs.news_at)
	var lamp: SpotLight3D = null
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--moon="):
			tag += "_" + a.trim_prefix("--moon=")
		elif a.begins_with("--tag="):
			tag += "_" + a.trim_prefix("--tag=")
		elif a == "--lamp":
			tag += "_lamp"
			lamp = preload("res://scripts/head_lamp.gd").new()
			main.add_child(lamp)
	var only := Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool: return SHOTS.has(a))
	for shot_name in (only if not only.is_empty() else SHOTS.keys()):
		var eye: Vector3 = SHOTS[shot_name][0]
		var aim: Vector3 = SHOTS[shot_name][1]
		if eye.y < 0.0:
			var world_3d := cam.get_world_3d()
			var down := func(at: Vector3) -> float:
				var hit: Dictionary = world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 200.0, at.z), Vector3(at.x, -50.0, at.z)))
				return hit.position.y if not hit.is_empty() else 0.0
			eye.y = down.call(eye) - eye.y
			aim.y = down.call(aim) - aim.y
		cam.look_at_from_position(eye, aim)
		if lamp:
			lamp.set(&"_placed", false)
			lamp.call(&"follow", cam.global_transform, 0.0)
			for f in 60:  # it eases on
				await process_frame
		for f in 30:  # let TAA settle
			await process_frame
		root.get_texture().get_image().save_png("user://shot_%s%s.png" % [shot_name, tag])
		print("saved ", ProjectSettings.globalize_path("user://shot_%s%s.png" % [shot_name, tag]))
	quit()
