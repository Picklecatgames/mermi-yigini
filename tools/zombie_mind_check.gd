extends SceneTree
## Headless check of the hunter's tricks and the director (scripts/waves.gd _direct, _play_role;
## 2026-11-06, the user: "nadiren arkamızda gizlensinler, ormanlıkta bazen saklansınlar, oyuncuya
## atlasınlar"):
##   Godot.exe --headless --fixed-fps 60 --path . -s res://tools/zombie_mind_check.gd
## Windowed (`--position -10000,-10000 --resolution 1280x720 ... -- --shots --tag=T`) it also saves
## what the player sees at each moment: user://zombi_<tag>_<moment>.png.
## - ambush: one given the ambush goes behind a trunk near the player and waits there, hidden from
##   them; the player walks up to it and it leaps out (shrieks, comes on at POUNCE) only then.
## - shy: one far off, looked at, goes behind a trunk; with the player's back to it, it comes on.
## - sneak: the player busy at the heap, one comes round behind them, unheard, and leaps at the end.
## - director: a calm player with the dead about: tricks now and then, EVENT_GAP s apart at least,
##   never the same twice running, none in the QUIET_AFTER_HIT s after a blow.

const STAND := Vector3(40.0, 0.0, 4.0)  # in the clearing near its east edge, the wood ahead

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
	await _director()
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


func _ground(p: Vector3) -> Vector3:
	var hit := main.get_viewport().world_3d.direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(p.x, 60.0, p.z), Vector3(p.x, -20.0, p.z), 1))
	return hit.position if hit else p


func _one(p: Vector3) -> Dictionary:
	var before: Array = waves._zombies.keys()
	var spot := _ground(p)
	var on := NavigationServer3D.map_get_closest_point(main.get_viewport().world_3d.navigation_map, spot)
	if on == Vector3.ZERO:
		var m: NavigationMesh = waves._nav.navigation_mesh
		print("  no closest point: map iteration %d, mesh polygons %d, region map %s vs %s" % [NavigationServer3D.map_get_iteration_id(main.get_viewport().world_3d.navigation_map),
				m.get_polygon_count(), waves._nav.get_navigation_map(), main.get_viewport().world_3d.navigation_map])
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


func _shot(name: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	var path := "user://zombi_%s_%s.png" % [tag, name]
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _ambush() -> void:
	print("--- ambush")
	yaw = -PI / 2
	at = _ground(STAND)
	var z := _one(at + Vector3(26.0, 0.0, 6.0))
	print("  player at %s, it at %s" % [at, z.node.global_position])
	waves.give_role(z, &"ambush", peer)
	var node: Node3D = z.node
	var t := 0.0
	while _events(z.id, &"waiting").is_empty() and t < 30.0:
		await _hold(0.25)
		t += 0.25
	if not _ok(not _events(z.id, &"waiting").is_empty(), "it went to a trunk and waits (%.1f s)" % t): return
	await _hold(3.0)
	var d := _flat(node.global_position, at)
	_ok(z.role == &"ambush" and waves._is_hidden(at, node.global_position) and d > waves.POUNCE_NEAR,
			"3 s on it still waits, %.1f m off, behind a trunk from the player" % d)
	_ok(not z.aware, "unheard: no shriek yet")
	await _shot("pusu_bekliyor")
	# The player walks up to it.
	var target := node.global_position
	var pounced_at := -1.0
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
			await _shot("pusu_atliyor")
		if pounced_at >= 0.0 and _flat(node.global_position, at) < 2.0:
			break
	_ok(pounced_at >= 0.0 and pounced_at <= waves.POUNCE_NEAR + 0.5 and z.aware, "it leapt out as the player came within %.1f m" % pounced_at)
	_ok(_flat(node.global_position, at) < 2.0, "and was on them %.1f s later" % t)
	_clear()


func _shy() -> void:
	print("--- shy")
	yaw = -PI / 2
	at = _ground(STAND)
	var z := _one(at + Vector3(22.0, 0.0, 2.0))
	var node: Node3D = z.node
	_ok(_off_look(node.global_position) < waves.SHY_SEEN, "the player looks right at it (%.0f degrees off)" % _off_look(node.global_position))
	waves.give_role(z, &"shy", peer)
	print("  cover: %s, from %s" % [waves._cover(at, node.global_position, Vector2(maxf(4.0, d0x(node) - 4.0), d0x(node) + 4.0)), node.global_position])
	var t := 0.0
	var d0 := _flat(node.global_position, at)
	while t < 10.0 and not waves._is_hidden(at, node.global_position):
		await _hold(0.25)
		t += 0.25
		if int(t * 4) % 4 == 0:
			print("    t %.1f at %s hide %s role %s moving %s pace %.2f" % [t, node.global_position, z.hide, z.role, z.moving, z.pace_now])
	_ok(waves._is_hidden(at, node.global_position) and not _events(z.id, &"hiding").is_empty(), "looked at, it went behind a trunk in %.1f s" % t)
	await _hold(2.0)
	var d1 := _flat(node.global_position, at)
	_ok(z.role == &"shy" and d1 > d0 - 6.0, "and stays back while watched (%.1f -> %.1f m)" % [d0, d1])
	await _shot("bakinca_saklandi")
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
	while z.role == &"sneak" and t < 50.0:
		await _hold(0.1)
		t += 0.1
		var d := _flat(node.global_position, at)
		if d < 8.0:
			worst = minf(worst, _off_look(node.global_position))
			if not shot and d < 5.0:
				shot = true
				yaw += PI  # the player turns round
				_pin()
				await _shot("arkadan_sizdi")
				yaw -= PI
	var d := _flat(node.global_position, at)
	_ok(z.role == &"" and d <= 5.5, "it came in behind them unheard; the player turned round at 5 m and it leapt (%.1f m, %.1f s)" % [d, t])
	_ok(worst > 110.0, "the last 8 m from behind (never nearer than %.0f degrees to where they look)" % worst)
	busy = false
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
	var spots := []
	for i in 6:
		spots.append(at + Vector3.FORWARD.rotated(Vector3.UP, -PI / 2 + (i - 2.5) * 0.35) * 30.0)
	for s: Vector3 in spots:
		_one(s)
	Engine.time_scale = 6.0
	var hit_at := -1.0
	var t0: float = waves._clock
	while waves._clock - t0 < 420.0:
		await process_frame
		yaw = fmod(yaw + 0.25 * main.get_process_delta_time(), TAU)  # looking about
		_pin()
		if hit_at < 0.0 and waves._clock - t0 > 200.0:
			hit_at = waves._clock  # a blow, as _swing lands it
			waves._last_hit[peer] = hit_at
			waves._tension[peer] = 0.6
		for z: Dictionary in waves._zombies.values():  # one on them: back to the wood
			if not z.dead and (_flat(z.node.global_position, at) < 3.0 or z.aware and z.role == &""):
				z.node.free()
				waves._zombies.erase(z.id)
				_one(spots[randi() % spots.size()])
				break
	Engine.time_scale = 1.0
	var tricks: Array = waves.event_log.filter(func(e: Array) -> bool: return e[2] in [&"ambush", &"shy", &"sneak"])
	for e: Array in tricks:
		print("  %5.1f s: %s (Z%d)" % [e[0] - t0, e[2], e[3]])
	_ok(tricks.size() >= 3, "%d tricks in 420 s" % tricks.size())
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


func d0x(node: Node3D) -> float:
	return _flat(node.global_position, at)
