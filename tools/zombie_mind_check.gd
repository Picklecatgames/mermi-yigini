extends SceneTree
## Headless check of the hunter's tricks and the director (scripts/waves.gd _direct, _play_role;
## 2026-11-06, the user: "nadiren arkamızda gizlensinler, ormanlıkta bazen saklansınlar, oyuncuya
## atlasınlar"; "tadında kalsın"):
##   Godot.exe --headless --fixed-fps 60 --path . -s res://tools/zombie_mind_check.gd
## Windowed (`--position -10000,-10000 --resolution 1280x720 ... -- --shots --tag=T`) it also saves
## frame strips from a camera beside the zombie: user://zombi_<tag>_<moment>.png.
## - ambush: one given the ambush stops short, goes behind a trunk near the player and waits there,
##   hidden from them; the player walks up to it and it leaps out (coil, flight, landing) only then.
## - shy: one far off, looked at, freezes a moment, slips behind a trunk; their back to it, it comes on.
## - sneak: the player busy at the heap, one comes round behind them, unheard, and leaps at the end.
## - shot: one in the middle of a trick, shot, drops it and goes for the shooter at once.
## - lamp: at night, the dead in a head lamp's beam stop short now and then, not every time.
## - director: one night of a calm player with the dead about: every trick's count within the
##   night's budget, EVENT_GAP s apart at least, never the same twice running, none in the
##   QUIET_AFTER_HIT s after a blow; most of the dead never get a trick.
## - room: none ever stands inside the player's body (they shoved it about).

const STAND := Vector3(40.0, 0.0, 4.0)  # in the clearing near its east edge, the wood ahead
const STRIP := Vector2i(300, 360)

var main: Node
var waves: Node
var gs: Node
var me: Node3D
var peer := 1
var yaw := -PI / 2  # looking along +x, into the wood
var at := STAND
var busy := false
var shots := false
var tag := "mind"
var ok := true
var nearest := INF  # the nearest any zombie stood to the player's middle


func _initialize() -> void:
	shots = "--shots" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	waves = main.get_node("Waves")
	waves.night_spawns = false
	me = main.get_node("Player")
	for i in 40:
		await physics_frame
	while waves._nav.navigation_mesh == null:
		await process_frame
	while not waves.nav_live:  # the map takes the mesh in on threads, some frames on (waves.gd _nav_watch)
		await physics_frame
	at = _ground(STAND)
	peer = gs.local_peer()
	await _hold(0.5)
	waves._direct_wait = 1e9  # the director waits till its own part
	await _ambush()
	await _shy()
	await _sneak()
	await _shot_rage()
	await _lamp()
	await _director()
	_ok(nearest >= waves.PLAYER_ROOM - 0.05, "none stood inside the player's body (nearest %.2f m)" % nearest)
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _ok(cond: bool, what: String) -> bool:
	print(("ok: " if cond else "FAIL: ") + what)
	ok = ok and cond
	return cond


## Every frame: the player held at `at` looking along `yaw`, never down; busy at the heap if `busy`.
func _hold(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await process_frame
		t += main.get_process_delta_time()
		_pin()


func _pin() -> void:
	me.global_position = Vector3(at.x, me.global_position.y, at.z)
	me.velocity = Vector3.ZERO
	me.set("_yaw", yaw)
	me.set("_pitch", -0.05)
	var p = gs.player()
	p.pos = me.global_position
	p.has_pose = true
	p.yaw = yaw
	p.hp = gs.HP_MAX
	p.down = false
	if busy:
		p.busy_at = Time.get_ticks_msec() / 1000.0
	for z: Dictionary in waves._zombies.values():
		if not z.dead and is_instance_valid(z.node) and not z.get("leap_on", false):
			nearest = minf(nearest, _flat(z.node.global_position, at))


func _ground(p: Vector3) -> Vector3:
	var hit := main.get_viewport().world_3d.direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(p.x, 60.0, p.z), Vector3(p.x, -20.0, p.z), 1))
	return hit.position if hit else p


func _one(p: Vector3) -> Dictionary:
	var before: Array = waves._zombies.keys()
	var spot := _ground(p)
	var on := NavigationServer3D.map_get_closest_point(main.get_viewport().world_3d.navigation_map, spot)
	waves._summon(&"walker", _ground(on), 0.0, 1)
	for id: int in waves._zombies.keys():
		if not id in before:
			return waves._zombies[id]
	return {}


func _clear() -> void:
	for id: int in waves._zombies.keys():
		waves._zombies[id].node.free()
	waves._zombies.clear()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Degrees between where the player looks and `p`.
func _off_look(p: Vector3) -> float:
	var rel := p - at
	rel.y = 0.0
	return rad_to_deg(Vector3(-sin(yaw), 0.0, -cos(yaw)).angle_to(rel))


func _events(id: int, what: StringName) -> Array:
	return waves.event_log.filter(func(e: Array) -> bool: return e[3] == id and e[2] == what)


## Windowed: `count` frames, `every` s apart, from a camera `side` m beside `node` (square to the line
## from the player to it), side by side in one picture. The world goes on meanwhile (the player held).
func _strip(name: String, node: Node3D, count: int, every: float, side := 3.5) -> void:
	if not shots:
		await _hold(count * every)
		return
	var cam := Camera3D.new()
	cam.fov = 45.0
	main.add_child(cam)
	var old := main.get_viewport().get_camera_3d()
	cam.current = true
	var sheet := Image.create(STRIP.x * count, STRIP.y, false, Image.FORMAT_RGBA8)
	for i in count:
		var to := node.global_position - at
		to.y = 0.0
		var across := to.normalized().cross(Vector3.UP)
		cam.global_position = node.global_position + across * side - to.normalized() * 1.0 + Vector3.UP * 1.3
		cam.look_at(node.global_position + Vector3.UP * 0.9)
		await RenderingServer.frame_post_draw
		var img := main.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var size := img.get_size()
		var w := size.y * STRIP.x / STRIP.y
		var part := img.get_region(Rect2i((size.x - w) / 2, 0, w, size.y))
		part.resize(STRIP.x, STRIP.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(part, Rect2i(Vector2i.ZERO, STRIP), Vector2i(STRIP.x * i, 0))
		await _hold(every)
	cam.queue_free()
	if old:
		old.current = true
	var path := "user://zombi_%s_%s.png" % [tag, name]
	sheet.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _ambush() -> void:
	print("--- ambush")
	yaw = -PI / 2
	at = _ground(STAND)
	var z := _one(at + Vector3(26.0, 0.0, 6.0))
	waves.give_role(z, &"ambush", peer)
	var node: Node3D = z.node
	await _strip("pusu_irkilip_gidiyor", node, 8, 0.25, 4.0)
	var t := 2.0
	while _events(z.id, &"waiting").is_empty() and t < 30.0:
		await _hold(0.25)
		t += 0.25
	if not _ok(not _events(z.id, &"waiting").is_empty(), "it stopped short, then went to a trunk and waits (%.1f s)" % t): return
	await _strip("pusu_bekliyor", node, 8, 0.4, 2.5)
	var d := _flat(node.global_position, at)
	_ok(z.role == &"ambush" and waves._is_hidden(at, node.global_position) and d > waves.POUNCE_NEAR,
			"3 s on it still waits, %.1f m off, behind a trunk from the player, in cover (%s)" % [d, z.mode])
	_ok(not z.aware, "unheard: no shriek yet")
	# The player walks up to it.
	var target := node.global_position
	var pounced_at := -1.0
	var leapt := false
	t = 0.0
	while t < 20.0:
		await process_frame
		var dt: float = main.get_process_delta_time()
		t += dt
		var to := target - at
		to.y = 0.0
		if z.role == &"ambush" and to.length() > 1.0:
			at += to.normalized() * 1.5 * dt
		_pin()
		if z.role != &"ambush" and pounced_at < 0.0:
			pounced_at = _flat(node.global_position, at)
			leapt = z.leap_on
			await _strip("pusu_atliyor", node, 10, 0.1, 3.0)
		if pounced_at >= 0.0 and _flat(node.global_position, at) < 2.0:
			break
	_ok(pounced_at >= 0.0 and pounced_at <= waves.POUNCE_NEAR + 0.5 and z.aware and leapt,
			"it leapt out as the player came within %.1f m (coil, flight, landing)" % pounced_at)
	_ok(_flat(node.global_position, at) < 2.0, "and was on them %.1f s later" % t)
	_clear()


func _shy() -> void:
	print("--- shy")
	yaw = -PI / 2
	at = _ground(STAND)
	var z := _one(at + Vector3(22.0, 0.0, 2.0))
	var node: Node3D = z.node
	_ok(_off_look(node.global_position) < waves.SHY_SEEN, "the player looks right at it (%.0f degrees off)" % _off_look(node.global_position))
	var d0 := _flat(node.global_position, at)
	waves.give_role(z, &"shy", peer)
	await _strip("bakinca_saklaniyor", node, 10, 0.2, 3.5)
	var t := 2.0
	while t < 10.0 and not waves._is_hidden(at, node.global_position):
		await _hold(0.25)
		t += 0.25
	_ok(waves._is_hidden(at, node.global_position) and not _events(z.id, &"hiding").is_empty(), "looked at, it froze, then went behind a trunk in %.1f s" % t)
	await _hold(2.0)
	var d1 := _flat(node.global_position, at)
	_ok(z.role == &"shy" and d1 > d0 - 6.0, "and stays back while watched (%.1f -> %.1f m)" % [d0, d1])
	yaw = PI / 2  # their back to it
	await _hold(4.0)
	var d2 := _flat(node.global_position, at)
	_ok(d2 < d1 - 4.0, "the player's back to it, it comes on (%.1f -> %.1f m)" % [d1, d2])
	_clear()


func _sneak() -> void:
	print("--- sneak")
	yaw = PI / 2  # into the clearing, the wood behind
	at = _ground(STAND)
	busy = true
	var z := _one(at + Vector3(16.0, 0.0, 14.0))
	var node: Node3D = z.node
	var t := 0.0
	await _hold(0.2)
	_ok(waves._is_busy(peer), "digging at the heap counts as busy")
	waves.give_role(z, &"sneak", peer)
	var worst := 180.0
	var shot := false
	var heard := false
	while z.role == &"sneak" and t < 50.0:
		await _hold(0.1)
		t += 0.1
		heard = heard or z.aware
		var d := _flat(node.global_position, at)
		if d < 8.0:
			worst = minf(worst, _off_look(node.global_position))
			if not shot and d < 5.0:
				shot = true
				yaw += PI  # the player turns round
				_pin()
				await _strip("arkadan_sizdi", node, 8, 0.12, 3.0)
				yaw -= PI
	var d := _flat(node.global_position, at)
	_ok(z.role == &"" and d <= 5.5 and not heard, "it came in behind them unheard; the player turned round at 5 m and it leapt (%.1f m, %.1f s)" % [d, t])
	_ok(worst > 110.0, "the last 8 m from behind (never nearer than %.0f degrees to where they look)" % worst)
	busy = false
	_clear()


func _shot_rage() -> void:
	print("--- shot")
	yaw = -PI / 2
	at = _ground(STAND)
	var z := _one(at + Vector3(24.0, 0.0, 6.0))
	var node: Node3D = z.node
	waves.give_role(z, &"ambush", peer)
	await _hold(3.0)
	var chest := node.global_position + Vector3.UP * 1.2
	var dir := (chest - (at + Vector3.UP * 1.6)).normalized()
	waves._on_shot(peer, chest, -dir, dir, node, 0, false, 0)
	await _strip("vurulunca", node, 10, 0.08, 3.0)
	var d0 := _flat(node.global_position, at)
	await _hold(2.0)
	var d1 := _flat(node.global_position, at)
	_ok(z.role == &"" and z.aware and z.grudge == peer and d1 < d0 - 3.0,
			"shot mid-trick, it dropped it and came for the shooter (%.1f -> %.1f m)" % [d0, d1])
	_clear()


func _lamp() -> void:
	print("--- lamp")
	yaw = -PI / 2
	at = _ground(STAND)
	gs.hour = 23.0
	await _hold(0.2)
	var ids := []
	for i in 6:
		var z := _one(at + Vector3(12.0 + i * 0.8, 0.0, -1.5 + i * 0.6))
		z.aware = true
		ids.append(z.id)
	var held := 0
	var t := 0.0
	var n0: int = waves.event_log.filter(func(e: Array) -> bool: return e[2] == &"startle").size()
	while t < 12.0:
		await _hold(0.1)
		t += 0.1
		for id: int in ids:
			if waves._zombies.has(id) and waves._zombies[id].hold > 0.0:
				held += 1
				break
		for id: int in ids:  # the near ones back off, so the rest stay in the beam
			if waves._zombies.has(id) and _flat(waves._zombies[id].node.global_position, at) < 4.0:
				waves._zombies[id].node.global_position += Vector3(10.0, 0.0, 0.0)
	var startles: Array = waves.event_log.filter(func(e: Array) -> bool: return e[2] == &"startle")
	var n := startles.size() - n0
	_ok(n >= 1 and held > 0, "in the beam at night one stopped short (%d times in 12 s)" % n)
	_ok(n <= ceili(12.0 / waves.LAMP_GAP) + 1, "not every time: %d of 6 in the beam, at most one per %.0f s" % [n, waves.LAMP_GAP])
	gs.hour = 9.0
	_clear()


func _director() -> void:
	print("--- director")
	yaw = -PI / 2
	at = _ground(STAND)
	waves.event_log.clear()
	waves._direct_wait = 0.0
	waves._last_event.clear()
	waves._last_trick.clear()
	waves._last_hit.clear()
	waves._tension.clear()
	waves._last_any = -INF
	waves._tricks_night = -1
	var spots := []
	for i in 6:
		spots.append(at + Vector3.FORWARD.rotated(Vector3.UP, -PI / 2 + (i - 2.5) * 0.35) * 30.0)
	var came := 0
	for s: Vector3 in spots:
		_one(s)
		came += 1
	Engine.time_scale = 6.0
	var hit_at := -1.0
	var t0: float = waves._clock
	var night: float = (waves.NIGHT_END + 24.0 - waves.NIGHT_START) * gs.DAY_SECONDS / 24.0  # s of a night
	while waves._clock - t0 < night:
		await process_frame
		yaw = fmod(yaw + 0.25 * main.get_process_delta_time(), TAU)  # looking about
		_pin()
		if hit_at < 0.0 and waves._clock - t0 > night * 0.45:
			hit_at = waves._clock  # a blow, as _swing lands it
			waves._last_hit[peer] = hit_at
			waves._tension[peer] = 0.6
		for z: Dictionary in waves._zombies.values():  # one on them: back to the wood, a fresh one
			if not z.dead and (_flat(z.node.global_position, at) < 3.0 or z.aware and z.role == &""):
				z.node.free()
				waves._zombies.erase(z.id)
				_one(spots[randi() % spots.size()])
				came += 1
				break
	Engine.time_scale = 1.0
	var tricks: Array = waves.event_log.filter(func(e: Array) -> bool: return e[2] in [&"ambush", &"shy", &"sneak"])
	for e: Array in tricks:
		print("  %5.1f s: %s (Z%d)" % [e[0] - t0, e[2], e[3]])
	var counts := {}
	for e: Array in tricks:
		counts[e[2]] = counts.get(e[2], 0) + 1
	print("  a night (%.0f s): %s; %d of the dead came, %d got a trick" % [night, counts, came, tricks.size()])
	_ok(tricks.size() >= 2 and tricks.size() <= waves.NIGHT_TRICKS_ALL, "%d tricks in the night (budget %d)" % [tricks.size(), waves.NIGHT_TRICKS_ALL])
	var each_ok := true
	for t: StringName in counts:
		each_ok = each_ok and counts[t] <= waves.NIGHT_TRICKS[t]
	_ok(each_ok, "each trick within its night's budget %s" % [waves.NIGHT_TRICKS])
	var gap_ok := true
	var same_ok := true
	var quiet_ok := true
	for i in tricks.size():
		if i > 0:
			gap_ok = gap_ok and tricks[i][0] - tricks[i - 1][0] >= waves.EVENT_GAP - 0.01
			same_ok = same_ok and tricks[i][2] != tricks[i - 1][2]
		quiet_ok = quiet_ok and not (tricks[i][0] > hit_at and tricks[i][0] - hit_at < waves.QUIET_AFTER_HIT)
	_ok(gap_ok, "at least %.0f s between them" % waves.EVENT_GAP)
	_ok(same_ok, "never the same trick twice running")
	_ok(quiet_ok, "none within %.0f s after the blow at %.0f s" % [waves.QUIET_AFTER_HIT, hit_at - t0])
	_clear()
