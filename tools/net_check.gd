extends SceneTree
## Headless co-op check, host and client in two processes on 127.0.0.1:
##   Godot.exe --headless --path . -s res://tools/net_check.gd
## This process hosts and starts the client itself (same script with `-- --client`). The host puts a
## zombie past the railing before anyone joins; the client gets it on joining, grabs, reloads and
## fires at it; both sides check they agree on what happened. Also:
## each side gets its own spawn point, sees the other as a third-person character that follows
## its pose, and the host drops a shot whose `from` is nowhere near the shooter.
## The shared world: the host digs the heap while the client is in and both end up with the same
## heights; the client lays its keys out from the host's seed onto the same spots.
## Between players: the client shoots the host (no harm, no pay, the host's aim jumps), then
## walks into it: it can't pass through, and the host gets shoved. Name tags take slot colours.
## Guns: the host draws the UZI before the client joins and the client, bare-handed at first, the
## starting pistol, then gives it its wooden grips; each sees the other's character holding the
## right one, the host the client's with the wooden grips. Characters: the host plays the Boss; the
## client joins to the pick screen, can't have the Boss, takes the worker, and each sees the other's
## body. Quests: the host finishes the
## main one as the client joins, the client claims its reward (C) through the host, the client's
## grabs and shots count on the host, and both end up with the same board. Workshop: the hopper the
## host fills melts on the host and the client sees its brass; the client presses clones from it.

const PORT := 24691  # not Net.PORT, so a game left running doesn't get in the way
const LOG := "user://net_check_client.log"
const ENGINE_LOG := "user://net_check_client_engine.log"  # the client's engine output: script errors, a crash
const WORLD := "user://net_check_client.json"  # what the client saw of the shared world
## The host digs these [at, rounds] as the client joins, near the heap's top, clear of the keys.
const HEAP := Vector3(-16, 0, 0)  # on the scrap heap's face (scripts/pile.gd CENTER x -20)
const DIGS := [[HEAP + Vector3(1.0, 0, 0.5), 3000], [HEAP + Vector3(-0.8, 0, -1.2), 5000], [HEAP + Vector3(0.3, 0, 1.6), 2000]]
const DUG := 10_000
## Once the client has pressed its clones (its last step against the clock), part of the face gives
## way (pile.gd scrap_collapse: cell, radius in cells, seed): both heaps must come down the same.
const COLLAPSE := [Vector2i(95, 120), 10, 77]
## The zombie the host puts up (scripts/waves.gd; added straight, it has no life to lose). The
## client fires at its chest from FIRE_FROM: over the railing's top rail (1.1 m, it takes rounds),
## not level along it.
const ZOMBIE := 901
const ZOMBIE_AT := Vector3(23, 0, 0)
const FIRE_FROM := Vector3(12, 1.5, 0)

var gs: Node
var net: Node
var main: Node
var _log: Array[String] = []
## Client: the step it is waiting on or the last check it passed. A script error ends the client's
## coroutine without quitting, so the host kills it after a while: this line then says where it was.
var _at := ""
var seen := {}  # client: what it saw of the shared world, for the host to compare
var _client_pid := 0  # host: the client's process, till it has gone and passed


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
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
	gs.request_select_gun(3)  # the UZI, before anyone is there to see it
	main.get_node("Waves")._add_zombie(ZOMBIE, &"walker", 7, "", ZOMBIE_AT, PI / 2, 1.0, ZOMBIE_AT.z, false)
	gs.request_pick_character("oldman")
	while gs.QUESTS[gs.quest_board[0]].get("warmup", false):  # past the warmup, to a quest that waits for its claim
		gs._finish_quest(gs.quest_board[0])
	for id: String in gs.QUESTS:  # the hopper and the press open: the joiner hears of it
		if gs.QUESTS[id].get("unlock") in ["melter", "hand_press"]:
			gs.quests_done.append(id)
	var client_id := [0]
	gs.multiplayer.peer_connected.connect(func(id: int) -> void:
		client_id[0] = id
		for d in DIGS:  # after GameState has told the newcomer the count and the key seed
			gs.request_take_bullets(d[1], d[0])
		gs.melt_bin = 6  # in the hopper: the host melts it, the client presses it
		gs._melter_now(true)
		var main_quest: Dictionary = gs.QUESTS[gs.quest_board[0]]  # finished while the client is in
		gs.quest_add(main_quest.kind, 1 << 20, [main_quest.get("with", "")]))
	var had_brass := [false]
	var collapsed := [false]
	gs.melter_changed.connect(func(_bin: int, brass: int, _ml: int, _pl: int) -> void:
		if brass > 0:
			had_brass[0] = true
		elif had_brass[0]:  # the client pressed it all
			had_brass[0] = false
			collapsed[0] = true
			gs.collapse_scrap(COLLAPSE[0], COLLAPSE[1], COLLAPSE[2]))
	var shots := []
	var rp: Node = main.get_node("RemotePlayers")
	var paid := [gs.vault / gs.VAULT_SHARE]  # gold paid so far, by anyone (the vault takes its share of each)
	gs.shot_landed.connect(func(_p: int, _a: Vector3, _n: Vector3, _d: Vector3, _t: Node, gold: int, _w: bool, _c: int) -> void:
		paid[0] += gold)
	var topped := [0.0]  # what the client's T added to the vault on top of the hits
	gs.vault_changed.connect(func(v: float) -> void:
		if v >= gs.TEST_MONEY and topped[0] == 0.0:
			topped[0] = v - paid[0] * gs.VAULT_SHARE)
	gs.shot_landed.connect(func(peer: int, _at: Vector3, _n: Vector3, _d: Vector3, t: Node, gold: int, _w: bool, _c: int) -> void:
		if peer == gs.local_peer() or t == null:
			return  # the client's shot at us
		var who: Node3D = rp.character(peer)
		var sound: Node3D = main.get_node("Impacts")._shot_sounds.get(peer)
		shots.append([peer, t, gold, false,
			who.muzzle_position() if who else Vector3.INF, sound.global_position if sound else Vector3.INF,
			gs.player(peer).pos, _holding(who), _wooden(who), who.look if who else ""]))
	var ff := []
	gs.player_shot.connect(func(shooter: int, victim: int, _at: Vector3, _dir: Vector3, _special: String) -> void:
		ff.append([shooter, victim]))
	var me: Node3D = main.get_node("Player")
	var home := me.global_position
	var tag_ok := [false]
	gs.player_slots.connect(func(s: Dictionary) -> void:  # sent again when it leaves
		for id: int in s:
			tag_ok[0] = tag_ok[0] or (id != gs.local_peer() and gs.color_of(id) == gs.PLAYER_COLORS[1]))
	_client_pid = _start_client("res://tools/net_check.gd")
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(_client_pid):
		if Time.get_ticks_msec() - t0 > 120_000:
			return _fail("client timed out")  # its log's last line says where it stopped
		await process_frame
	var code := OS.get_process_exit_code(_client_pid)
	if code != 0:
		return _fail("client side failed (exit %d)" % code)
	_client_pid = 0
	print(FileAccess.get_file_as_string(LOG))
	var cid: int = client_id[0]
	if not _ok(cid != 0, "client connected"): return
	var grabs: int = JSON.parse_string(FileAccess.get_file_as_string(WORLD)).grabs
	if not _ok(gs.pile == gs.PILE_START - 1 - grabs - DUG, "host pile: its loose bullet, its digs, the client's %d grab(s)" % grabs): return
	if not _ok(collapsed[0], "part of the heap's face gave way while the client was in"): return
	if not await _world_agrees(): return
	if not _ok(shots.size() == 1 and shots[0][0] == cid, "host traced one shot, the client's"): return
	if not _ok(shots[0][1] == main.get_node("Waves/Z%d" % ZOMBIE) and shots[0][2] == 1, "it hit the zombie for $1"): return
	var muzzle: Vector3 = shots[0][4]
	if not _ok(muzzle.distance_to(FIRE_FROM) < 1.0,
			"the client's character stood where it fired from"): return
	if not _ok(shots[0][5].distance_to(muzzle) < 0.001, "the shot rang out at that character's muzzle"): return
	if not _ok(shots[0][6].distance_to(Vector3(12, 0, 0)) < 0.3, "the client's pose reached the host"): return
	if not _ok(shots[0][7] == "ServicePistol", "the client's character fired holding the starting pistol (%s)" % shots[0][7]): return
	if not _ok(shots[0][8], "with the wooden grips it gave it"): return
	if not _ok(shots[0][9] == "oldman", "in the old man's body (%s)" % shots[0][9]): return
	if not _ok(tag_ok[0], "the client's tag takes slot 1's colour"): return
	print("friendly fire: %s, our aim now pitch %.3f; pushed %.2f m" % [ff, me._pitch, me.global_position.distance_to(home)])
	if not _ok(ff.size() == 1 and ff[0] == [cid, gs.local_peer()], "the client's round hit us"): return
	if not _ok(me._pitch > 0.03, "and threw our aim up"): return
	if not _ok(me.global_position.distance_to(home) > 0.3, "the client walking into us shoved us"): return
	if not await _until(func() -> bool: return rp.character(cid) == null, "the client's character to go"): return
	var p = gs._saved.values()[0] if gs._saved.size() == 1 else null  # under the client's token
	if not _ok(p != null and p.gold == gs.TEST_MONEY and p.loaded == 0 and p.carried == 0, "host keeps the client's state"): return
	# Its loose bullet may have come out a special round (GameState._roll_specials): pocket, not hand.
	if not _ok(gs.player().carried + gs.player().specials.size() == 1, "the host's own hand is untouched"): return
	if not _ok(p.rounds.get("clone", 0) == 3 and gs.brass == 0 and gs.melt_bin == 0, "the client pressed three clones from the team's brass"): return
	if not _ok(paid[0] >= 1 and topped[0] > 0.0 and is_equal_approx(gs.vault, topped[0] + paid[0] * gs.VAULT_SHARE), "every paid $ put its share in the vault (%.2f of $%.0f)" % [gs.vault, paid[0]]): return
	print("net_check OK")
	quit()


func _client() -> void:
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client, "connect"): return
	if not await _until(func() -> bool: return gs.pile == gs.PILE_START - 1 - DUG, "pile count and the host's digs on join"): return
	if not _ok(gs.key_seed == main.get_node("Keys")._seed and gs.key_seed != 0, "keys laid out from the host's seed"): return
	if not await _until(func() -> bool: return gs.quests_ready.size() == 1, "the host's main quest done, waiting for its claim"): return
	var main_quest: String = gs.quests_ready[0]
	gs.request_claim_quests()
	if not await _until(func() -> bool: return main_quest in gs.quests_done and gs.quests_ready.is_empty(), "our claim to come back from the host"): return
	# The host's zombie, from the wave cues on joining: where the host has it.
	if not await _until(func() -> bool: return main.has_node("Waves/Z%d" % ZOMBIE), "the host's zombie"): return
	var zombie: Node3D = main.get_node("Waves/Z%d" % ZOMBIE)
	if not _ok(zombie.global_position.distance_to(ZOMBIE_AT) < 0.01, "it stands where the host put it (%s)" % zombie.global_position): return
	# Our own spawn point, not the host's.
	var me: Node3D = main.get_node("Player")
	var spawns := root.get_tree().get_nodes_in_group("spawn")
	if not await _until(func() -> bool: return gs.spawn_index == 1, "a spawn point from the host"): return
	if not _ok(me.global_position.distance_to(spawns[1].global_position) < 0.5 and spawns[1].global_position.distance_to(spawns[0].global_position) > 1.2,
			"we start on spawn 1, away from the host's"): return
	# Joined as somebody new: one body, so no pick screen; both of us wear it.
	if not await _until(func() -> bool: return gs.player(1).character == "oldman", "the host's body"): return
	if not await _until(func() -> bool: return gs.player().character == "oldman", "ours, the same one"): return
	if not _ok(not me._pick.is_open, "no pick screen"): return
	# The host's body shows up as a character where the host stands.
	var rp: Node = main.get_node("RemotePlayers")
	if not await _until(func() -> bool: return rp.character(1) != null and rp.character(1).visible, "the host's character"): return
	if not _ok(rp.character(1).global_position.distance_to(spawns[0].global_position) < 0.5, "it stands on the host's spawn"): return
	if not _ok(rp.character(1).look == "oldman" and rp.character(1)._model != null, "it wears the old man's body"): return
	# Guns: the host drew the UZI before we came; we are bare-handed until we draw ours.
	if not _ok(_holding(rp.character(1)) == "UZI", "the host's character holds the UZI (%s)" % _holding(rp.character(1))): return
	if not _ok(gs.player().gun == 0 and not gs.request_fire(me.global_position, Vector3.FORWARD) and gs.request_reload() == 0, "bare fists: nothing to fire or load"): return
	gs.request_select_gun(1)
	if not _ok(gs.player().gun == 0, "the pistol stays shut until it is taken off the table"): return
	gs.request_take_pistol()  # takes it and draws it: two requests, in order
	if not await _until(gs.synced, "answer to drawing the pistol"): return
	if not _ok(gs.player().gun == 1, "the host let us draw it"): return
	gs.request_debug_level_up("grip")  # the wooden grips: the host shows them on our character
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
	# From the heap. About 1 in 75 grabs is a special round (GameState._roll_specials): the host puts
	# it in the pocket, not the hand, and we grab again.
	seen.grabs = 0
	while gs.carried == 0:
		if not _ok(seen.grabs < 5 and gs.request_pick_up(HEAP + Vector3(0, 1, 0), 1) == 1, "heap grab predicted"): return
		seen.grabs += 1
		if not await _until(gs.synced, "answer to the heap grab"): return
		if gs.carried == 0:
			if not _ok(gs.player().specials.size() == seen.grabs, "the grab the host took back is in our pocket (%s)" % [gs.player().specials]): return
			_log.append("heap grab %d came out a special round: %s" % [seen.grabs, gs.player().specials.back()])
	if not _ok(gs.carried == 1 and gs.pile == gs.PILE_START - 1 - seen.grabs - DUG, "host agrees: in hand, pile down (carried %d, pile %d short)" % [gs.carried, gs.PILE_START - gs.pile]): return
	if not _ok(gs.request_reload() == 1, "reload"): return
	if not await _until(gs.synced, "answer to the reload"): return
	if not _ok(gs.loaded == 1 and gs.carried == 0, "round in the gun"): return
	# A shot from five metres off our body: predicted, then the host says it never happened.
	var fake := FIRE_FROM + Vector3(0, 0, 5)
	var any_shot := [false]
	gs.shot_landed.connect(func(_p: int, _a: Vector3, _n: Vector3, _d: Vector3, _t: Node, _g: int, _w: bool, _c: int) -> void: any_shot[0] = true)
	if not _ok(gs.request_fire(fake, Vector3(1, 0, 0)) and gs.loaded == 0, "forged shot predicted"): return
	if not await _until(gs.synced, "answer to the forged shot"): return
	if not _ok(gs.loaded == 1 and not any_shot[0], "host dropped it: round back, nothing landed"): return
	gs.player().cooldown = 0.0
	# One shot at the zombie's chest. The client traces the same ray itself to compare.
	var body: Node = main.get_node("Waves")._zombies[ZOMBIE].body
	body.catch_up()
	var from := FIRE_FROM
	var dir: Vector3 = (body.call("_bone_at", "Spine2") - from).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * gs.SHOT_RANGE, gs.SHOT_MASK)
	var mine: Dictionary = root.world_3d.direct_space_state.intersect_ray(q)
	if not _ok(not mine.is_empty() and mine.collider == zombie, "local trace hits the zombie (%s)" % (mine.collider.get_path() if mine else "nothing")): return
	var shots := []
	gs.shot_landed.connect(func(peer: int, at: Vector3, _n: Vector3, _d: Vector3, t: Node, gold: int, _w: bool, combo: int) -> void:
		shots.append([peer, at, t, gold, combo]))
	if not _ok(gs.request_fire(from, dir) and gs.loaded == 0, "shot predicted, round gone"): return
	if not await _until(func() -> bool: return gs.synced() and shots.size() == 1, "the shot's result"): return
	var s: Array = shots[0]
	_log.append("client saw: peer %d at %v target %s gold %d combo %d" % [s[0], s[1], s[2], s[3], s[4]])
	if not _ok(s[0] == gs.local_peer(), "the event names us as the shooter"): return
	# Its idle sway runs on each machine's own clock: the chest is where ours is give or take a little.
	if not _ok(s[1].distance_to(mine.position) < 0.1 and s[2] == zombie, "host's hit = our own trace (%.3f m off)" % s[1].distance_to(mine.position)): return
	if not _ok(s[3] == 1 and s[4] == 1 and gs.gold == gs.START_GOLD + 1, "$1 paid, and it reached us"): return
	if not _ok(is_equal_approx(gs.vault, gs.START_GOLD + gs.VAULT_SHARE), "the vault's share of it reached us too"): return
	gs.player().cooldown = 0.0
	if not _ok(not gs.request_fire(from, dir), "empty gun stays quiet"): return
	# Friendly fire: up close to the host on its spawn, shoot it, then walk into it.
	var host_char: Node3D = rp.character(1)
	if not _ok((host_char.get("_tag_mat") as StandardMaterial3D).albedo_color.is_equal_approx(Color(gs.PLAYER_COLORS[0], 0.8)), "the host's tag is slot 0's colour"): return
	gs.request_toggle_infinite_ammo()
	if not await _until(gs.synced, "test mode"): return
	var host_at := host_char.global_position
	me.global_position = host_at + Vector3(0, 0, -2.5)
	me._yaw = PI  # facing the host (+Z)
	me.reset_physics_interpolation()
	await create_timer(0.5).timeout  # the pose reaches the host
	# (It used not to, under load: ENet's throttle on unreliable packets had gone to 0, net.gd.)
	var link := (gs.multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)
	if not _ok(link.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE) == ENetPacketPeer.PACKET_THROTTLE_SCALE, "no throttle on our poses (%d)" % link.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)): return
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
	gs.request_toggle_infinite_ammo()  # back to the empty gun the host checks for
	if not await _until(gs.synced, "test mode off"): return
	# The workshop: the host's hopper melts and we see the brass; we press it at the press.
	if not await _until(func() -> bool: return gs.brass == 6 and gs.melt_bin == 0, "the host's hopper to melt (%d, %d)" % [gs.melt_bin, gs.brass], 10.0): return
	me.global_position = gs.PRESS_POS + Vector3(0, 0, -1.2)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout  # our pose reaches the host
	if not _ok(gs.request_press("clone", 9) == 3, "the press makes what the brass allows"): return
	if not await _until(gs.synced, "the press"): return
	if not _ok(gs.player().rounds.get("clone", 0) == 3, "three clones are ours"): return
	if not await _until(func() -> bool: return gs.brass == 0, "the brass spent on the host"): return
	var pile: Node = main.get_node("Pile")
	if not await _until(func() -> bool: return pile._pending.is_empty() and pile.step >= pile._host_step and not pile._any_active and pile._digs.is_empty() and not pile._any_slump, "the heap to settle"): return
	var keys: Node = main.get_node("Keys")
	var at := {}
	for rank: int in keys._pos:
		at[str(rank)] = [keys._pos[rank].x, keys._pos[rank].y, keys._pos[rank].z]
	seen.heap = hash(pile._h)
	seen.heights = Marshalls.raw_to_base64(pile._h.to_byte_array())
	seen.keys = at
	seen.quests = JSON.stringify([gs.quest_board, gs.quest_progress, gs.quests_done, gs.quests_ready])
	var f := FileAccess.open(WORLD, FileAccess.WRITE)
	f.store_string(JSON.stringify(seen))
	f.close()
	_log.append("client OK, latency %.3f s" % net.latency())
	_at = ""
	_write_log()
	quit()


## The gun mesh a remote character shows, "" bare-handed.
func _holding(who: Node) -> String:
	if who == null or not who._gun.visible:
		return ""
	for m: Node in who._fp_skel.get_children():
		if (m is MeshInstance3D or m.name == "ServicePistol") and m.visible and m.name != "Mesh":
			return m.name
	return "?"


## `who`'s starting pistol has its wooden grips on, not the tape.
func _wooden(who: Node) -> bool:
	var gun: Node = who._fp_skel.get_node_or_null("ServicePistol") if who else null
	return gun != null and gun.get_node("frame_wood").visible and not gun.get_node("frame_tape").visible


## Host, after the client has gone: what it saw of the shared world against ours.
func _world_agrees() -> bool:
	var theirs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORLD))
	var pile: Node = main.get_node("Pile")
	if not await _until(func() -> bool: return pile._pending.is_empty() and pile.step >= pile._host_step and not pile._any_active and pile._digs.is_empty() and not pile._any_slump, "the heap to settle"): return false
	var h: PackedFloat32Array = Marshalls.base64_to_raw(theirs.heights).to_float32_array()
	var worst := 0.0
	for k in h.size():
		worst = maxf(worst, absf(h[k] - pile._h[k]))
	print("heap: host %d, client %d, largest difference %.6f m" % [hash(pile._h), int(theirs.heap), worst])
	if not _ok(hash(pile._h) == int(theirs.heap), "both heaps have the same heights"): return false
	var quests := JSON.stringify([gs.quest_board, gs.quest_progress, gs.quests_done, gs.quests_ready])
	print("quests: host %s, client %s" % [quests, theirs.quests])
	if not _ok(gs.quests_done.size() >= 1 and quests == theirs.quests, "the client's quest board is the host's"): return false
	var keys: Node = main.get_node("Keys")
	if not _ok(theirs.keys.size() == keys._pos.size(), "as many keys on both"): return false
	for rank: int in keys._pos:
		var p: Array = theirs.keys[str(rank)]
		if not _ok(keys._pos[rank].distance_to(Vector3(p[0], p[1], p[2])) < 1e-4, "key %d on the same spot" % rank): return false
	return true


func _until(cond: Callable, what: String, secs := 30.0) -> bool:
	var t0 := Time.get_ticks_msec()
	if not cond.call():
		_at = "waiting for " + what
		_write_log()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			_fail("timed out waiting for " + what)
			return false
		await process_frame
	return true


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fail(what)
	elif "--client" in OS.get_cmdline_user_args():
		_at = "last check passed: " + what
		_write_log()
	return cond


func _fail(what: String) -> void:
	_log.append("net_check FAIL: " + what)
	_at = ""
	_stop_client()
	printerr("net_check FAIL: ", what)
	_write_log()
	quit(1)


## Host: the client, this script again with `-- --client`, its engine output in ENGINE_LOG.
func _start_client(script: String) -> int:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ENGINE_LOG))
	return OS.create_process(OS.get_executable_path(), ["--headless", "--log-file", ProjectSettings.globalize_path(ENGINE_LOG),
		"--path", ProjectSettings.globalize_path("res://"), "-s", script, "--", "--client"])


## Host, failing with the client still about: stops it and shows its log and the end of its engine
## output, so a hang, a script error or a crash on its side says where.
func _stop_client() -> void:
	if _client_pid == 0:
		return
	if OS.is_process_running(_client_pid):
		OS.kill(_client_pid)
	_client_pid = 0
	print("--- client log:\n", FileAccess.get_file_as_string(LOG))
	var engine := FileAccess.get_file_as_string(ENGINE_LOG).split("\n")
	print("--- client engine output, last lines:\n", "\n".join(engine.slice(-40)))


func _write_log() -> void:
	if "--client" in OS.get_cmdline_user_args():
		var lines := _log.duplicate()
		if _at:
			lines.append(_at)
		var f := FileAccess.open(LOG, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(lines))
