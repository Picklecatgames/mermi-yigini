extends SceneTree
## Headless co-op check, host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/net_check.gd
## This process hosts and starts the client itself (same script with `-- --client`). The client
## grabs, reloads and fires at the dummy; both sides check they agree on what happened. Also:
## each side gets its own spawn point, sees the other as a third-person character that follows
## its pose, and the host drops a shot whose `from` is nowhere near the shooter.
## The shared world: the host digs the heap while the client is in and both end up with the same
## heights; the client lays its keys out from the host's seed onto the same spots; the plate rack
## raises the same plates, a popper the host knocks stands back up at the same moment and the Texas
## Star points the same way on both (both processes read the same wall clock to line these up).
## Between players: the client shoots the host (no harm, no pay, the host's aim jumps), then
## walks into it: it can't pass through, and the host gets shoved. Name tags take slot colours.
## Guns: the host draws the UZI before the client joins and the client, bare-handed at first, the
## Deagle; each sees the other's character holding the right one. Quests: the host finishes the
## main one as the client joins, the client's grabs and shots count on the host, and both end up
## with the same board.

const PORT := 24691  # not Net.PORT, so a game left running doesn't get in the way
const LOG := "user://net_check_client.log"
const WORLD := "user://net_check_client.json"  # what the client saw of the shared world
## The host digs these [at, rounds] as the client joins, near the heap's top, clear of the keys.
const HEAP := Vector3(-9, 0, 0)  # scenes/main.tscn Pile
const DIGS := [[HEAP + Vector3(1.0, 0, 0.5), 3000], [HEAP + Vector3(-0.8, 0, -1.2), 5000], [HEAP + Vector3(0.3, 0, 1.6), 2000]]
const DUG := 10_000
const CROW_AT := Vector3(18, 0, -20)  # a scarecrow the client lights; the host pays it while it burns
const STAR_EVERY := 0.1  # s between Texas Star samples

var gs: Node
var net: Node
var main: Node
var _log: Array[String] = []
## Wall clock samples: plate rack [t, plate up] and popper [t, down] when they change, star [t, angle].
var seen := {"rack": [], "popper": [], "star": []}
var _star_t := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.add_child(load("res://scenes/test_range.tscn").instantiate())  # the six fixed targets; the game starts with one dummy
	var crow: Node3D = load("res://scenes/scarecrow.tscn").instantiate()  # pays the client while it burns
	crow.name = "Scarecrow"
	crow.position = CROW_AT
	crow.rotation.y = -PI / 2
	main.add_child(crow)
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	for i in 3:
		await physics_frame
	if "--client" in OS.get_cmdline_user_args():
		await _client()
	else:
		await _host()


func _host() -> void:
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	# Taken before anyone joins: the client will reach for the same bullet and must lose it.
	if gs.request_pick_up_loose(0) != 1:
		return _fail("host takes loose bullet 0")
	gs.request_select_gun(2)  # the UZI, before anyone is there to see it
	var client_id := [0]
	gs.multiplayer.peer_connected.connect(func(id: int) -> void:
		client_id[0] = id
		for d in DIGS:  # after GameState has told the newcomer the count and the key seed
			gs.request_take_bullets(d[1], d[0])
		var main_quest: Dictionary = gs.QUESTS[gs.quest_board[0]]  # finished while the client is in
		gs.quest_add(main_quest.kind, 1 << 20, [main_quest.get("with", "")]))
	process_frame.connect(_sample)
	var shots := []
	var rp: Node = main.get_node("RemotePlayers")
	# The dummy connected first, so by now it has reacted; a "+$" over it would be on show.
	var labels: Array = main.get_node("Dummy")._pops._labels
	var paid := [gs.vault / gs.VAULT_SHARE]  # gold paid so far, by anyone (the vault takes its share of each)
	gs.shot_landed.connect(func(_p: int, _a: Vector3, _n: Vector3, _d: Vector3, _t: Node, gold: int, _w: bool, _c: int) -> void:
		paid[0] += gold)
	gs.bonus_paid.connect(func(_p: int, _t: Node, gold: int) -> void: paid[0] += gold)
	var topped := [0.0]  # what the client's T added to the vault on top of the hits
	gs.vault_changed.connect(func(v: float) -> void:
		if v >= gs.TEST_MONEY and topped[0] == 0.0:
			topped[0] = v - paid[0] * gs.VAULT_SHARE)
	gs.shot_landed.connect(func(peer: int, _at: Vector3, _n: Vector3, _d: Vector3, t: Node, gold: int, _w: bool, _c: int) -> void:
		if peer == gs.local_peer() or t == null or t.name == "Scarecrow":
			return  # our own shot at the popper, the client's at us and at the scarecrow
		var who: Node3D = rp.character(peer)
		var sound: Node3D = main.get_node("Impacts")._shot_sounds.get(peer)
		shots.append([peer, t, gold, labels.any(func(l: Label3D) -> bool: return l.visible),
			who.muzzle_position() if who else Vector3.INF, sound.global_position if sound else Vector3.INF,
			gs.player(peer).pos, _holding(who)]))
	var ff := []
	gs.player_shot.connect(func(shooter: int, victim: int, _at: Vector3, _dir: Vector3, _special: String) -> void:
		ff.append([shooter, victim]))
	var me: Node3D = main.get_node("Player")
	var home := me.global_position
	var tag_ok := [false]
	gs.player_slots.connect(func(s: Dictionary) -> void:  # sent again when it leaves
		for id: int in s:
			tag_ok[0] = tag_ok[0] or (id != gs.local_peer() and gs.color_of(id) == gs.PLAYER_COLORS[1]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "-s", "res://tools/net_check.gd", "--", "--client"])
	var t0 := Time.get_ticks_msec()
	var popper: Node3D = main.get_node("LockedTargets/PopperNorth")
	var knocked := false
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() - t0 > 120_000:
			OS.kill(pid)
			return _fail("client timed out")
		# The client is in and watching: knock the popper over, from our side of the line.
		if not knocked and client_id[0] != 0 and gs.player(client_id[0]).has_pose:
			knocked = true
			await create_timer(1.5).timeout
			var paddle: MeshInstance3D = popper._paddle
			var aim := paddle.global_transform * paddle.get_aabb().get_center()
			var from := Vector3(12.0, aim.y, aim.z)
			gs.player().loaded = 1
			gs.player().cooldown = 0.0
			if not _ok(gs.request_fire(from, (aim - from).normalized()) and popper.is_down(), "host knocks the popper over"): return
		await process_frame
	var code := OS.get_process_exit_code(pid)
	print(FileAccess.get_file_as_string(LOG))
	if code != 0:
		return _fail("client side failed (exit %d)" % code)
	var cid: int = client_id[0]
	if not _ok(cid != 0, "client connected"): return
	if not _ok(gs.pile == gs.PILE_START - 2 - DUG, "host pile: its loose bullet, its digs, the client's grab"): return
	if not await _world_agrees(): return
	if not _ok(shots.size() == 1 and shots[0][0] == cid, "host traced one shot, the client's"): return
	if not _ok(shots[0][1] == main.get_node("Dummy") and shots[0][2] == 1, "it hit the dummy for $1"): return
	if not _ok(not shots[0][3], "the client's +$ shows on the client only"): return
	var muzzle: Vector3 = shots[0][4]
	if not _ok(muzzle.distance_to(main.get_node("Dummy").global_position + Vector3(-11, 1.1, 0)) < 1.0,
			"the client's character stood where it fired from"): return
	if not _ok(shots[0][5].distance_to(muzzle) < 0.001, "the shot rang out at that character's muzzle"): return
	if not _ok(shots[0][6].distance_to(Vector3(12, 0, 0)) < 0.3, "the client's pose reached the host"): return
	if not _ok(shots[0][7] == "Deagle", "the client's character fired holding the Deagle (%s)" % shots[0][7]): return
	if not _ok(tag_ok[0], "the client's tag takes slot 1's colour"): return
	print("friendly fire: %s, our aim now pitch %.3f; pushed %.2f m" % [ff, me._pitch, me.global_position.distance_to(home)])
	if not _ok(ff.size() == 1 and ff[0] == [cid, gs.local_peer()], "the client's round hit us"): return
	if not _ok(me._pitch > 0.03, "and threw our aim up"): return
	if not _ok(me.global_position.distance_to(home) > 0.3, "the client walking into us shoved us"): return
	if not await _until(func() -> bool: return rp.character(cid) == null, "the client's character to go"): return
	var p = gs._saved.values()[0] if gs._saved.size() == 1 else null  # under the client's token
	if not _ok(p != null and p.gold == gs.TEST_MONEY + 6 and p.loaded == 0 and p.carried == 0, "host keeps the client's state (its scarecrow $6 too)"): return
	if not _ok(gs.player().carried == 1, "the host's own hand is untouched"): return
	if not _ok(paid[0] >= 1 and topped[0] > 0.0 and is_equal_approx(gs.vault, topped[0] + paid[0] * gs.VAULT_SHARE), "every paid $ put its share in the vault (%.2f of $%.0f)" % [gs.vault, paid[0]]): return
	print("net_check OK")
	quit()


func _client() -> void:
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client, "connect"): return
	if not await _until(func() -> bool: return gs.pile == gs.PILE_START - 1 - DUG, "pile count and the host's digs on join"): return
	if not _ok(gs.key_seed == main.get_node("Keys")._seed and gs.key_seed != 0, "keys laid out from the host's seed"): return
	await create_timer(0.6).timeout  # the star's first word from the host
	process_frame.connect(_sample)
	var watch_from := Time.get_ticks_msec()
	# Our own spawn point, not the host's.
	var me: Node3D = main.get_node("Player")
	var spawns := root.get_tree().get_nodes_in_group("spawn")
	if not await _until(func() -> bool: return gs.spawn_index == 1, "a spawn point from the host"): return
	if not _ok(me.global_position.distance_to(spawns[1].global_position) < 0.5 and spawns[1].global_position.distance_to(spawns[0].global_position) > 2.0,
			"we start on spawn 1, away from the host's"): return
	# The host's body shows up as a character where the host stands.
	var rp: Node = main.get_node("RemotePlayers")
	if not await _until(func() -> bool: return rp.character(1) != null and rp.character(1).visible, "the host's character"): return
	if not _ok(rp.character(1).global_position.distance_to(spawns[0].global_position) < 0.5, "it stands on the host's spawn"): return
	# Guns: the host drew the UZI before we came; we are bare-handed until we draw ours.
	if not _ok(_holding(rp.character(1)) == "UZI", "the host's character holds the UZI (%s)" % _holding(rp.character(1))): return
	if not _ok(gs.player().gun == 0 and not gs.request_fire(me.global_position, Vector3.FORWARD) and gs.request_reload() == 0, "bare fists: nothing to fire or load"): return
	gs.request_select_gun(1)
	if not await _until(gs.synced, "answer to drawing the Deagle"): return
	if not _ok(gs.player().gun == 1, "the host let us draw it"): return
	# Walk up to the line to shoot from there; our pose follows us to the host.
	me.global_position = Vector3(12, 0, 0)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout  # the pose reaches the host, its character catches up
	# A loose bullet the host took before we joined: joining told us (yol haritası 8).
	if not _ok(gs._taken_loose.has(0) and gs.request_pick_up_loose(0) == 0, "joining told us loose bullet 0 is gone"): return
	# The race the join can't cover, both reaching for it at once: forget it, grab, be undone.
	gs._taken_loose.erase(0)
	if not _ok(gs.request_pick_up_loose(0) == 1 and gs.carried == 1, "loose grab predicted"): return
	if not _ok(gs.request_pick_up_loose(0) == 0, "holding E asks only once"): return
	if not await _until(gs.synced, "answer to the loose grab"): return
	if not _ok(gs.carried == 0, "host said no: the bullet is taken back"): return
	# From the heap.
	if not _ok(gs.request_pick_up(HEAP + Vector3(0, 1, 0), 1) == 1, "heap grab predicted"): return
	if not await _until(gs.synced, "answer to the heap grab"): return
	if not _ok(gs.carried == 1 and gs.pile == gs.PILE_START - 2 - DUG, "host agrees: in hand, pile down"): return
	if not _ok(gs.request_reload() == 1, "reload"): return
	if not await _until(gs.synced, "answer to the reload"): return
	if not _ok(gs.loaded == 1 and gs.carried == 0, "round in the gun"): return
	# A shot from five metres off our body: predicted, then the host says it never happened.
	var dummy0: Node3D = main.get_node("Dummy")
	var fake := dummy0.global_position + Vector3(-11, 1.1, 5)
	var any_shot := [false]
	gs.shot_landed.connect(func(_p: int, _a: Vector3, _n: Vector3, _d: Vector3, _t: Node, _g: int, _w: bool, _c: int) -> void: any_shot[0] = true)
	if not _ok(gs.request_fire(fake, Vector3(1, 0, 0)) and gs.loaded == 0, "forged shot predicted"): return
	if not await _until(gs.synced, "answer to the forged shot"): return
	if not _ok(gs.loaded == 1 and not any_shot[0], "host dropped it: round back, nothing landed"): return
	gs.player().cooldown = 0.0
	# One shot at the dummy's body. The client traces the same ray itself to compare.
	var dummy: Node3D = main.get_node("Dummy")
	var from := dummy.global_position + Vector3(-11, 1.1, 0)
	var dir := Vector3(1, 0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * gs.SHOT_RANGE, gs.SHOT_MASK)
	var mine: Dictionary = root.world_3d.direct_space_state.intersect_ray(q)
	if not _ok(not mine.is_empty() and mine.collider == dummy, "local trace hits the dummy"): return
	var shots := []
	gs.shot_landed.connect(func(peer: int, at: Vector3, _n: Vector3, _d: Vector3, t: Node, gold: int, _w: bool, combo: int) -> void:
		shots.append([peer, at, t, gold, combo]))
	if not _ok(gs.request_fire(from, dir) and gs.loaded == 0, "shot predicted, round gone"): return
	if not await _until(func() -> bool: return gs.synced() and shots.size() == 1, "the shot's result"): return
	var s: Array = shots[0]
	_log.append("client saw: peer %d at %v target %s gold %d combo %d" % [s[0], s[1], s[2], s[3], s[4]])
	if not _ok(s[0] == gs.local_peer(), "the event names us as the shooter"): return
	if not _ok(s[1].distance_to(mine.position) < 0.001 and s[2] == dummy, "host's hit = our own trace"): return
	if not _ok(s[3] == 1 and s[4] == 1 and gs.gold == 1, "$1 paid, and it reached us"): return
	if not _ok(is_equal_approx(gs.vault, gs.VAULT_SHARE), "the vault's share of it reached us too"): return
	gs.player().cooldown = 0.0
	if not _ok(not gs.request_fire(from, dir), "empty gun stays quiet"): return
	# Friendly fire: up close to the host on its spawn, shoot it, then walk into it.
	var host_char: Node3D = rp.character(1)
	if not _ok((host_char.get("_tag_box") as StandardMaterial3D).albedo_color.is_equal_approx(Color(gs.PLAYER_COLORS[0], 0.8)), "the host's tag is slot 0's colour"): return
	gs.request_toggle_infinite_ammo()
	if not await _until(gs.synced, "test mode"): return
	var host_at := host_char.global_position
	me.global_position = host_at + Vector3(0, 0, -2.5)
	me._yaw = PI  # facing the host (+Z)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout
	var ff := []
	gs.player_shot.connect(func(shooter: int, victim: int, _at: Vector3, _dir: Vector3, _special: String) -> void: ff.append([shooter, victim]))
	gs.player().cooldown = 0.0
	var eye: Vector3 = me.global_position + Vector3.UP * gs.EYE
	if not _ok(gs.request_fire(eye, (host_at + Vector3.UP * 1.2 - eye).normalized()), "shot at the host"): return
	if not await _until(func() -> bool: return ff.size() == 1, "the friendly fire event"): return
	if not _ok(ff[0] == [gs.local_peer(), 1] and gs.gold == gs.TEST_MONEY, "we hit the host, for nothing"): return
	Input.action_press("move_forward")
	var closest := INF
	var t_push := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_push < 1200:
		await physics_frame
		closest = minf(closest, Vector2(me.global_position.x - host_char.global_position.x, me.global_position.z - host_char.global_position.z).length())
	Input.action_release("move_forward")
	_log.append("walked into the host: closest %.2f m, host moved %.2f m" % [closest, host_char.global_position.distance_to(host_at)])
	if not _ok(closest > 0.6, "the host's body blocks us"): return
	if not _ok(host_char.global_position.distance_to(host_at) > 0.3, "and we shoved it"): return
	# The scarecrow: our hit lights it and the host pays us its burning seconds (bonus_paid).
	me.global_position = Vector3(12, 0, CROW_AT.z)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout
	var gold_before: int = gs.gold
	gs.player().cooldown = 0.0
	var eye_c: Vector3 = me.global_position + Vector3.UP * gs.EYE
	if not _ok(gs.request_fire(eye_c, (CROW_AT + Vector3.UP * 1.1 - eye_c).normalized()), "shot at the scarecrow"): return
	if not await _until(func() -> bool: return gs.gold - gold_before >= 6, "the scarecrow's hit and five burning seconds", 10.0): return
	await create_timer(1.5).timeout
	_log.append("scarecrow paid us %d" % (gs.gold - gold_before))
	if not _ok(gs.gold - gold_before == 6, "scarecrow: $1 for the hit, $5 while it burnt"): return
	gs.request_toggle_infinite_ammo()  # back to the empty gun the host checks for
	if not await _until(gs.synced, "test mode off"): return
	# Keep watching until the host's popper has gone down and up again and the rack has cycled.
	if not await _until(func() -> bool: return Time.get_ticks_msec() - watch_from > 5000 \
			and seen.popper.size() >= 3, "the popper to go down and stand up"): return
	var pile: Node = main.get_node("Pile")
	if not await _until(func() -> bool: return not pile._any_active and pile._digs.is_empty(), "the heap to settle"): return
	var keys: Node = main.get_node("Keys")
	var at := {}
	for rank: int in keys._pos:
		at[str(rank)] = [keys._pos[rank].x, keys._pos[rank].y, keys._pos[rank].z]
	seen.heap = hash(pile._h)
	seen.heights = Marshalls.raw_to_base64(pile._h.to_byte_array())
	seen.keys = at
	seen.quests = JSON.stringify([gs.quest_board, gs.quest_progress, gs.quests_done])
	var f := FileAccess.open(WORLD, FileAccess.WRITE)
	f.store_string(JSON.stringify(seen))
	f.close()
	_log.append("client OK, latency %.3f s" % net.latency())
	_write_log()
	quit()


## The gun mesh a remote character shows, "" bare-handed.
func _holding(who: Node) -> String:
	if who == null or not who._gun.visible:
		return ""
	for m: Node3D in who._fp_skel.get_children():
		if m is MeshInstance3D and m.visible and m.name != "Mesh":
			return m.name
	return "?"


func _sample() -> void:
	var t := Time.get_unix_time_from_system()
	var lt: Node = main.get_node("LockedTargets")
	var up: int = lt.get_node("PlateRack").up_plate()
	if seen.rack.is_empty() or seen.rack[-1][1] != up:
		seen.rack.append([t, up])
	var down: bool = lt.get_node("PopperNorth").is_down()
	if seen.popper.is_empty() or seen.popper[-1][1] != down:
		seen.popper.append([t, down])
	if t - _star_t >= STAR_EVERY:
		_star_t = t
		seen.star.append([t, lt.get_node("TexasStar").angle()])


## Host, after the client has gone: what it saw of the shared world against ours.
func _world_agrees() -> bool:
	var theirs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORLD))
	var pile: Node = main.get_node("Pile")
	if not await _until(func() -> bool: return not pile._any_active and pile._digs.is_empty(), "the heap to settle"): return false
	var h: PackedFloat32Array = Marshalls.base64_to_raw(theirs.heights).to_float32_array()
	var worst := 0.0
	for k in h.size():
		worst = maxf(worst, absf(h[k] - pile._h[k]))
	print("heap: host %d, client %d, largest difference %.6f m" % [hash(pile._h), int(theirs.heap), worst])
	if not _ok(hash(pile._h) == int(theirs.heap), "both heaps have the same heights"): return false
	var quests := JSON.stringify([gs.quest_board, gs.quest_progress, gs.quests_done])
	print("quests: host %s, client %s" % [quests, theirs.quests])
	if not _ok(gs.quests_done.size() >= 1 and quests == theirs.quests, "the client's quest board is the host's"): return false
	var keys: Node = main.get_node("Keys")
	if not _ok(theirs.keys.size() == keys._pos.size(), "as many keys on both"): return false
	for rank: int in keys._pos:
		var p: Array = theirs.keys[str(rank)]
		if not _ok(keys._pos[rank].distance_to(Vector3(p[0], p[1], p[2])) < 1e-4, "key %d on the same spot" % rank): return false
	# Plate rack: every plate the client saw come up, the host raised at the same moment.
	# The first sample is just how it stood: a plate the client raised alone, before joining.
	var raised: Array = theirs.rack.slice(1).filter(func(s: Array) -> bool: return s[1] >= 0)
	print("rack: client saw plates %s" % [raised.map(func(s: Array) -> int: return int(s[1]))])
	if not _ok(raised.size() >= 2, "the client saw the rack raise plates"): return false
	for s: Array in raised:
		if not _ok(seen.rack.any(func(m: Array) -> bool: return m[1] == s[1] and absf(m[0] - s[0]) < 0.3),
				"plate %d came up on the host too" % s[1]): return false
	# Popper: down and back up on both at the same moments.
	var flips: Array = theirs.popper.slice(1)  # the first sample is just how it stood
	if not _ok(flips.size() >= 2, "the client saw the popper go down and up"): return false
	for s: Array in flips:
		if not _ok(seen.popper.any(func(m: Array) -> bool: return m[1] == s[1] and absf(m[0] - s[0]) < 0.3),
				"popper %s on the host at the same time" % ("down" if s[1] else "up")): return false
	# Texas Star: where the host's star pointed at each moment the client looked. Both processes
	# share one CPU, and a frame stalled by the heap's slides shifts a sample by its length
	# (~50 ms, 0.15 rad at 3 rad/s); a plate is 1.26 rad wide.
	var star_worst := 0.0
	for s: Array in theirs.star:
		var near: Array = seen.star[0]
		for m: Array in seen.star:
			if absf(m[0] - s[0]) < absf(near[0] - s[0]):
				near = m
		var host_at: float = near[1] - main.get_node("LockedTargets/TexasStar").SPIN * (s[0] - near[0])
		star_worst = maxf(star_worst, absf(angle_difference(host_at, s[1])))
	print("star: %d samples, largest difference %.3f rad" % [theirs.star.size(), star_worst])
	return _ok(theirs.star.size() >= 20 and star_worst < 0.2, "the Texas Star points the same way on both")


func _until(cond: Callable, what: String, secs := 30.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			_fail("timed out waiting for " + what)
			return false
		await process_frame
	return true


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fail(what)
	return cond


func _fail(what: String) -> void:
	_log.append("net_check FAIL: " + what)
	printerr("net_check FAIL: ", what)
	_write_log()
	quit(1)


func _write_log() -> void:
	if "--client" in OS.get_cmdline_user_args():
		var f := FileAccess.open(LOG, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_log))
