extends SceneTree
## Headless check of the house and the television's daily bulletin (scripts/tv.gd, data/bultenler.json),
## host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/tv_check.gd
## The table: 14 days, Turkish, day 5 and on another voice, the air goes dead at the end. The host's clock
## goes round to morning: day 2 comes in. The client joins mid-bulletin and must see that day and line;
## asks for the bulletin itself; both end on the same day and line, the same text. Too far from the set the
## host says no. The house: from the yard and through both doors, a walker's way and a player's feet both
## get in; the spawns stand clear inside; a dead on the far side of the house finds its way to a player.

const PORT := 24699
const LOG := "user://tv_check_client.log"
const ENGINE_LOG := "user://tv_check_client_engine.log"

var gs: Node
var net: Node
var main: Node
var _log: Array[String] = []
var _client_pid := 0
var _fail := false


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	for i in 5:
		await physics_frame
	if "--client" in OS.get_cmdline_user_args():
		await _client()
	else:
		await _host()


func _ok(cond: bool, what: String) -> bool:
	print(("ok   " if cond else "FAIL ") + what)
	_log.append(("ok   " if cond else "FAIL ") + what)
	_fail = _fail or not cond
	return cond


func _until(cond: Callable, what: String, secs := 20.0) -> bool:
	var left := secs
	while not cond.call():
		await physics_frame
		left -= 1.0 / 60.0
		if left <= 0.0:
			_ok(false, "timed out waiting for " + what)
			return false
	return true


func _host() -> void:
	_table()
	await _house()
	# Alone first: too far, nothing; near, it reads; it moves on by itself and ends.
	var me: CharacterBody3D = main.get_node("Player")
	var p: Object = gs.player()
	gs.request_pick_character("oldman")
	for i in 5:
		await physics_frame
	p.has_pose = true
	me.global_position = Vector3(14.0, 0.05, 0)
	await physics_frame
	await physics_frame
	p.pos = me.global_position
	gs.request_watch_news()
	_ok(gs.news_at == -1, "too far from the set: nothing")
	me.global_position = gs.TV_POS + Vector3(1.5, 0.05, 0)
	await physics_frame
	await physics_frame
	p.pos = me.global_position
	gs.request_watch_news()
	_ok(gs.news_at == 0, "in reach: line 1 of day 1")
	gs._news_wait = 0.0
	await physics_frame
	await physics_frame
	_ok(gs.news_at == 1, "the next line comes by itself")
	var lines: Array = gs.news_entry(1).satirlar
	for i in lines.size() + 2:
		gs._news_wait = 0.0
		await physics_frame
	_ok(gs.news_at == -1, "and it ends")
	# Morning brings the next day: night passes on the clock.
	gs.hour = 20.5
	await _until(func() -> bool: return gs.nights >= 1, "dusk")
	gs.hour = 8.0
	await _until(func() -> bool: return gs.news_day == 2, "morning's bulletin")
	_ok(gs.news_day == 2 and gs.nights == 1, "morning after night 1 is day 2")
	if net.host(PORT) != OK:
		_ok(false, "could not host on %d" % PORT)
		return _end()
	var exe := OS.get_executable_path()
	_client_pid = OS.create_process(exe, ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", ProjectSettings.globalize_path(ENGINE_LOG), "-s", "res://tools/tv_check.gd", "--", "--client"])
	# The bulletin is already running when they come in: they must come in on it.
	p.pos = gs.TV_POS + Vector3(1.5, 0, 0)
	gs.request_watch_news()
	gs._news_wait = 0.0
	await physics_frame
	await physics_frame
	gs._news_wait = 1000.0
	var line_when_joined: int = gs.news_at
	_ok(line_when_joined == 1, "host: day 2's line 2 is on")
	var joined := await _until(func() -> bool: return not root.multiplayer.get_peers().is_empty(), "the client", 40.0)
	if not joined:
		return _end()
	# The client reports what it saw on joining, then asks for the bulletin after this one ends.
	await _until(func() -> bool: return FileAccess.file_exists(LOG + ".joined"), "the client's report on joining", 30.0)
	gs._news_wait = 0.0
	while gs.news_at >= 0:  # ended
		gs._news_wait = 0.0
		await physics_frame
	await _until(func() -> bool: return gs.news_at >= 0, "the client's request", 30.0)
	_ok(gs.news_day == 2 and gs.news_at == 0, "the client's request reads it from the top, on the host")
	gs._news_wait = 0.0
	await physics_frame
	await physics_frame
	gs._news_wait = 1000.0
	var f := FileAccess.open(LOG + ".host", FileAccess.WRITE)
	f.store_string(JSON.stringify({"day": gs.news_day, "line": gs.news_at, "text": gs.news_entry(gs.news_day).satirlar[gs.news_at]}))
	f.close()
	await _until(func() -> bool: return FileAccess.file_exists(LOG), "the client's log", 30.0)
	await create_timer(0.5).timeout
	var text := FileAccess.get_file_as_string(LOG)
	for l: String in text.split("\n", false):
		print("client: ", l)
		_fail = _fail or l.begins_with("FAIL")
	_ok(text.contains("ok   same bulletin"), "the client reports the same bulletin")
	_end()


func _end() -> void:
	if _client_pid > 0 and OS.is_process_running(_client_pid):
		OS.kill(_client_pid)
	print("TV CHECK ", "FAILED" if _fail else "PASSED")
	quit(1 if _fail else 0)


func _client() -> void:
	for suffix: String in ["", ".joined", ".host"]:
		if FileAccess.file_exists(LOG + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG + suffix))
	var seen: Array = []
	gs.news_line.connect(func(day: int, line: int) -> void: seen.append([day, line]))
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.online and gs.news_day == 2 and gs.news_at >= 0, "joining mid-bulletin", 40.0):
		return _finish()
	_ok(gs.news_day == 2 and gs.news_at == 1, "joined mid-bulletin: day 2, line 2 (%d, %d)" % [gs.news_day, gs.news_at])
	var tv: Node = get_first_node_in_group("tv")
	_ok(tv != null, "the set is in the house here too")
	var mark := FileAccess.open(LOG + ".joined", FileAccess.WRITE)
	mark.store_string("1")
	mark.close()
	# The host lets it run out; then we ask, from the set.
	await _until(func() -> bool: return gs.news_at == -1, "the bulletin's end", 30.0)
	gs.player().has_pose = true
	main.get_node("Player").global_position = gs.TV_POS + Vector3(1.5, 0.05, 0)
	for i in 10:
		await physics_frame  # our pose reaches the host
	gs.request_watch_news()
	_ok(gs.news_at == -1, "no reading before the host says so")
	await _until(func() -> bool: return FileAccess.file_exists(LOG + ".host"), "the host's word", 30.0)
	await _until(func() -> bool: return gs.news_at == 1, "the line from the host", 10.0)
	var host_says: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOG + ".host"))
	var mine: String = gs.news_entry(gs.news_day).satirlar[gs.news_at]
	_ok(int(host_says.day) == gs.news_day and int(host_says.line) == gs.news_at and host_says.text == mine, "same bulletin: day %d line %d" % [gs.news_day, gs.news_at])
	_ok(not seen.is_empty(), "lines came as events (%d)" % seen.size())
	_finish()


func _finish() -> void:
	var f := FileAccess.open(LOG, FileAccess.WRITE)
	f.store_string("\n".join(_log))
	f.close()
	quit()


## The table itself.
func _table() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(gs.NEWS_FILE))
	var all: Array = data.bultenler
	_ok(all.size() >= 14, "%d bulletins for a full game of about 14 nights" % all.size())
	var demo := all.filter(func(b: Dictionary) -> bool: return b.get("demo", false))
	_ok(demo.size() == 5, "5 for the demo")
	for i in all.size():
		var b: Dictionary = all[i]
		_ok(int(b.gun) == i + 1 and b.bilgi != "", "day %d in its place, says something true" % (i + 1))
	_ok(all[0].spiker == "A" and all[4].spiker == "B", "the voice has changed by day 5")
	_ok(all[0].satirlar.any(func(s: String) -> bool: return s.contains("Ses yapmayın")) , "day 1: keep quiet")
	_ok(all[0].satirlar.any(func(s: String) -> bool: return s.contains("ilk gün")), "day 1: the first day")
	_ok(gs.news_entry(99).kanal == "kesik" and gs.news_entry(99).satirlar.is_empty(), "past the last: dead air")


## The house: its doors, the spawns, a dead's way in.
func _house() -> void:
	var me: CharacterBody3D = main.get_node("Player")
	gs.request_pick_character("oldman")
	for i in 10:
		await physics_frame
	var spawns := get_nodes_in_group("spawn")
	_ok(spawns.size() == 4, "four spawns")
	var space := me.get_world_3d().direct_space_state
	for s: Node3D in spawns:
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.75
		q.shape = cap
		q.transform = Transform3D(Basis(), s.global_position + Vector3(0, 0.95, 0))
		q.exclude = [me.get_rid()]
		_ok(space.intersect_shape(q, 4).is_empty(), "spawn at %s stands clear" % s.global_position)
		_ok((s.global_basis * Vector3.FORWARD).x < -0.9, "looks at the mountain")
	# On foot, through each door. Standing in the yard, walking straight in.
	for way: Array in [[Vector3(13.0, 0.05, 0.9), Vector3(-1, 0, 0), 5.5, "front door and veranda"],
			[Vector3(-0.5, 0.05, -3.0), Vector3(1, 0, 0), 3.5, "back door from the mountain"]]:
		var end: Vector3 = await _walk(me, way[0], way[1], 4.0)
		var into: float = (end - way[0]).dot(way[1])
		_ok(into > way[2], "on foot through the %s (%.1f m in)" % [way[3], into])
	# Nothing walks through a window or a wall.
	var end: Vector3 = await _walk(me, Vector3(0.0, 0.05, 1.4), Vector3(1, 0, 0), 2.0)
	_ok(end.x < 1.6, "no way in through the mountain's window (stopped at x %.1f)" % end.x)
	# The dead's way: the waves' mesh goes through the doors.
	var waves: Node = main.get_node("Waves")
	if not await _until(func() -> bool: return waves._nav.navigation_mesh != null, "the waves' navigation mesh", 40.0):
		return
	await physics_frame
	await physics_frame
	var map: RID = me.get_world_3d().navigation_map
	for pair: Array in [[Vector3(13.0, 0, 0.9), Vector3(5.5, 0, 1.8), "yard to the room"], [Vector3(-2.0, 0, -3.0), Vector3(7.0, 0, -1.4), "mountain to the room"],
			[Vector3(6.0, 0, 2.5), Vector3(3.2, 0, 1.6), "room to the sleeping corner"]]:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, pair[0], pair[1], true)
		var last: Vector3 = path[path.size() - 1] if path.size() > 0 else pair[0]
		_ok(path.size() >= 2 and last.distance_to(pair[1]) < 0.8, "navigation: %s (ends %.2f m off, %d points)" % [pair[2], last.distance_to(pair[1]), path.size()])
	# A real one: comes at a player standing inside from the far side of the house.
	me.global_position = Vector3(5.5, 0.05, 1.8)
	for i in 10:
		await physics_frame
	gs.request_debug_spawn("walker", Vector3(-1.0, 0, -6.0), 0.0, 1)
	var got := await _until(func() -> bool:
		for z: Dictionary in waves._zombies.values():
			if not z.dead and is_instance_valid(z.node) and z.node.global_position.distance_to(me.global_position) < 2.2:
				return true
		return false, "a walker to reach a player in the house", 75.0)
	_ok(got, "a walker walks round the house and in, to the player")
	for z: Dictionary in waves._zombies.values():
		if is_instance_valid(z.node):
			print("  walker at ", z.node.global_position)
	me.global_position = Vector3(7.3, 0.05, 0.9)
	for z: Dictionary in waves._zombies.values():
		if is_instance_valid(z.node):
			z.node.queue_free()
	waves._zombies.clear()


func _walk(me: CharacterBody3D, from: Vector3, dir: Vector3, secs: float) -> Vector3:
	me.global_position = from
	me.velocity = Vector3.ZERO
	var steps := int(secs * 60.0)
	for i in steps:
		me.velocity = dir.normalized() * 4.0 + Vector3(0, -0.1, 0)
		me.move_and_slide()
		await physics_frame
	return me.global_position
