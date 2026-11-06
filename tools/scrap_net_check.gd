extends SceneTree
## Headless two-player scrap check, host and client in two processes on 127.0.0.1 (F7/F8 as
## tools/net_check.gd does it):
##   Godot.exe --headless --path . -s res://tools/scrap_net_check.gd
## A scrap piece keeps its part and tone (pile.gd piece_of: [part, tone]) through every hand, on
## both machines (2026-11-05, the user: a piece thrown down turned into another; the fix in
## GameState/pile.gd/player.gd was only checked alone, tools/scrap_carry_check.gd):
##   1. the client picks a few pieces off the heap's face and throws them;
##   2. the host picks those up off the ground and throws them again;
##   3. the client picks them up off the ground once more and throws them;
##   4. the client digs some out of the heap (the host rolls what they are) and throws them.
## At every step both sides note what the hand held (the client's after the host's answer, the
## host's own copy of the client's hand) and what landed under each thrown id; the host compares
## the two machines at the end. A special round (1 in ~75 picks, GameState.SPECIALS) goes in the
## pocket instead of the hand: the hand is then the pieces taken less those.

const PORT := 24693  # not Net.PORT nor net_check's
const LOG := "user://scrap_net_client.log"
const ENGINE_LOG := "user://scrap_net_client_engine.log"
const SEEN := "user://scrap_net_client.json"  # what the client saw, for the host to compare
const TAKE := 4  # pieces off the face (different parts)
const DIG := 3
const LAND := 120  # physics frames for thrown pieces to come down
## The client writes here what it has noted, so the host picks up the client's throw only after the
## client has seen it land (else the host's loose_taken can beat the client's look at it).
const STEP := "user://scrap_net_client_step.txt"

var gs: Node
var net: Node
var main: Node
var pile: Node
var _log: Array[String] = []
var _at := ""
var _failed := false
var seen := {}  # step -> [[part, r, g, b], ...]
var _thrown: Array = []  # every bullets_thrown here: [count, first_id, pieces]
var _client_pid := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	for i in 3:
		await physics_frame
	pile = root.get_tree().get_first_node_in_group("bullet_pile")
	gs.bullets_thrown.connect(func(_f: Vector3, _d: Vector3, count: int, first: int, pieces: Array) -> void:
		_thrown.append([count, first, pieces.duplicate(true)]))
	if "--client" in OS.get_cmdline_user_args():
		await _client()
	else:
		await _host()


func _host() -> void:
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	gs.request_pick_character("oldman")
	gs.player().levels["carry"] = 9  # a hand of 10
	var cid := [0]
	gs.multiplayer.peer_connected.connect(func(id: int) -> void:
		cid[0] = id
		gs.player(id).levels["carry"] = 9)
	# Every frame, even while the steps below wait: the client's hand as the host keeps it, by how
	# many throws went before it.
	process_frame.connect(func() -> void:
		if cid[0] != 0:
			_note_hand("h_client_hand_%d" % _thrown.size(), gs.player(cid[0]).scrap))
	_client_pid = _start_client()
	var me: Node3D = main.get_node("Player")
	var t0 := Time.get_ticks_msec()
	var step := 0  # 1 once the host has picked up and thrown the client's first throw
	while OS.is_process_running(_client_pid):
		if Time.get_ticks_msec() - t0 > 180_000:
			return _fail("client timed out")
		if step == 0 and _thrown.size() == 1:
			# 2. The client's throw has flown: let it land, note it, pick it all up, throw it again.
			step = 1
			for i in LAND:
				await physics_frame
			var t: Array = _thrown[0]
			_note_landed("landed_1", t)
			var w0 := Time.get_ticks_msec()
			while FileAccess.get_file_as_string(STEP) != "landed_1":
				if Time.get_ticks_msec() - w0 > 60_000:
					return _fail("the client never noted its first throw landing")
				await process_frame
			var specials: int = gs.player().specials.size()
			var taken := []
			for n in t[0]:
				var piece: Array = pile.piece_of(t[1] + n)
				if gs.request_pick_up_loose(t[1] + n) == 1:
					taken.append(piece)
			_ok(taken.size() == t[0], "host picks up all %d the client threw" % t[0])
			var hand: Array = gs.player().scrap.duplicate(true)
			_ok(_hand_of(hand, taken, gs.player().specials.size() - specials), "host's hand holds what it picked up (%s)" % _parts(hand))
			_ok(_same(taken, t[2]), "what the host picked up is what the client threw (%s -> %s)" % [_parts(t[2]), _parts(taken)])
			_note("h_host_hand", hand)
			gs.request_throw(me.global_position + Vector3(-1.0, 1.5, 0.0), Vector3.FORWARD)
			_ok(gs.player().scrap.is_empty() and gs.carried == 0, "host's hand empty after its throw")
			_ok(_thrown.size() == 2 and _same(_thrown[1][2], hand), "what the host threw is what it held")
			for i in LAND:
				await physics_frame
			_note_landed("landed_2", _thrown[1])
		await process_frame
	var code := OS.get_process_exit_code(_client_pid)
	_client_pid = 0
	print(FileAccess.get_file_as_string(LOG))
	if code != 0:
		return _fail("client side failed (exit %d)" % code)
	if not _ok(cid[0] != 0, "client connected"): return
	# The client's throws 3 and 4 landed here too.
	if not _ok(_thrown.size() == 4, "host saw four throws (client, host, client, client's dig): %d" % _thrown.size()): return
	for i in LAND:
		await physics_frame
	_note_landed("landed_3", _thrown[2])
	_note_landed("landed_4", _thrown[3])
	var theirs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SEEN))
	if not _ok(theirs != null and not theirs.is_empty(), "the client's notes"): return
	# Both machines: every hand and every landing the same pieces in the same tones. The host's
	# copy of the client's first hand is what its own heap had under the ids the client reached for.
	_ok(_same_noted(seen.get("h_client_hand_0"), theirs.get("hand_1")), "host's copy of the client's first hand = the client's (%s)" % _noted_parts(theirs.get("hand_1")))
	_ok(_same_noted(seen.get("landed_1"), theirs.get("landed_1")), "the client's first throw landed the same on both (%s)" % _noted_parts(seen.get("landed_1")))
	_ok(_same_noted(seen.get("landed_1"), theirs.get("hand_1")), "and as the client held it")
	_ok(_same_noted(seen.get("landed_2"), theirs.get("landed_2")), "the host's throw landed the same on both (%s)" % _noted_parts(seen.get("landed_2")))
	_ok(_same_noted(seen.get("landed_2"), seen.get("h_host_hand")), "and as the host held it")
	_ok(_same_noted(seen.get("h_client_hand_2"), theirs.get("hand_3")), "host's copy of the client's third hand = the client's (%s)" % _noted_parts(theirs.get("hand_3")))
	_ok(_same_noted(seen.get("landed_3"), theirs.get("landed_3")), "the client's second throw landed the same on both (%s)" % _noted_parts(seen.get("landed_3")))
	_ok(_same_noted(seen.get("landed_3"), theirs.get("hand_3")), "and as the client held it")
	_ok(_same_noted(seen.get("h_client_hand_3"), theirs.get("dug")), "host's copy of the client's dug hand = the client's (%s)" % _noted_parts(theirs.get("dug")))
	_ok(_same_noted(seen.get("landed_4"), theirs.get("landed_4")), "the dug pieces landed the same on both (%s)" % _noted_parts(seen.get("landed_4")))
	_ok(_same_noted(seen.get("landed_4"), theirs.get("dug")), "and as the host rolled them")
	print("FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)


func _client() -> void:
	net.join("127.0.0.1", PORT)
	if not await _until(func() -> bool: return net.is_client, "connect"): return _done()
	# The heap as the host has it: the join snapshot, then a few frames for the face to come up.
	for i in 30:
		await physics_frame
	gs.player().levels["carry"] = 9
	var me: Node3D = main.get_node("Player")
	# 1. Pieces off the heap's face, all different parts.
	var ids: Array[int] = []
	var parts := {}
	var slot_id: Array = pile.get(&"_slot_id")
	for s in slot_id.size():
		var id: int = slot_id[s]
		if id >= 0 and pile.has_loose(id):
			var piece: Array = pile.piece_of(id)
			if not piece.is_empty() and not parts.has(piece[0]):
				parts[piece[0]] = true
				ids.append(id)
				if ids.size() >= TAKE:
					break
	if not _ok(ids.size() == TAKE, "%d different pieces on the face" % TAKE): return _done()
	var taken := []
	for id in ids:
		taken.append(pile.piece_of(id))
	_note("face", taken)
	if not await _pick(ids, taken, "hand_1"): return _done()
	gs.request_throw(me.global_position + Vector3(0.0, 1.5, 1.0), Vector3.FORWARD)
	if not await _until(func() -> bool: return _thrown.size() == 1, "our throw back from the host"): return _done()
	var hand: Array = _noted("hand_1")
	_ok(_same(_thrown[0][2], hand), "what flew is what we held (%s)" % _parts(_thrown[0][2]))
	for i in LAND:
		await physics_frame
	_note_landed("landed_1", _thrown[0])
	var f := FileAccess.open(STEP, FileAccess.WRITE)  # the host may pick it up now
	f.store_string("landed_1")
	f.close()
	# 2. The host picks ours up and throws it.
	if not await _until(func() -> bool: return _thrown.size() == 2, "the host's throw", 60.0): return _done()
	_ok(_same(_thrown[1][2], hand), "the host threw what we threw (%s)" % _parts(_thrown[1][2]))
	for i in LAND:
		await physics_frame
	_note_landed("landed_2", _thrown[1])
	# 3. We pick the host's throw off the ground.
	var t: Array = _thrown[1]
	ids.clear()
	taken.clear()
	for n in t[0]:
		ids.append(t[1] + n)
		taken.append(pile.piece_of(t[1] + n))
	_ok(_same(taken, t[2]), "the host's throw lies here as it threw it (%s)" % _parts(taken))
	if not await _pick(ids, taken, "hand_3"): return _done()
	gs.request_throw(me.global_position + Vector3(0.0, 1.5, -1.0), Vector3.FORWARD)
	if not await _until(func() -> bool: return _thrown.size() == 3, "our second throw back from the host"): return _done()
	_ok(_same(_thrown[2][2], _noted("hand_3")), "what flew is what we held (%s)" % _parts(_thrown[2][2]))
	for i in LAND:
		await physics_frame
	_note_landed("landed_3", _thrown[2])
	# 4. Dug out of the heap: we guess unknown pieces, the host's answer says what they are.
	var specials: int = gs.player().specials.size()
	var dug: int = gs.request_pick_up(pile.top_point(), DIG)
	if not _ok(dug == DIG, "we dig %d out of the heap" % DIG): return _done()
	if not await _until(func() -> bool: return gs.player().scrap.size() + gs.player().specials.size() - specials == DIG \
			and gs.player().scrap.all(func(p: Array) -> bool: return p[0] >= 0), "the host's roll for what we dug"): return _done()
	_note("dug", gs.player().scrap)
	gs.request_throw(me.global_position + Vector3(1.0, 1.5, 0.0), Vector3.FORWARD)
	if not await _until(func() -> bool: return _thrown.size() == 4, "the dug pieces' throw back from the host"): return _done()
	_ok(_same(_thrown[3][2], _noted("dug")), "what flew is what was dug (%s)" % _parts(_thrown[3][2]))
	for i in LAND:
		await physics_frame
	_note_landed("landed_4", _thrown[3])
	_done()


## Client: picks up `ids` (their pieces `taken`), waits for the host's answer, notes the hand.
func _pick(ids: Array, taken: Array, note: String) -> bool:
	var specials: int = gs.player().specials.size()
	for id: int in ids:
		gs.request_pick_up_loose(id)
	_ok(gs.carried == ids.size() and _same(gs.player().scrap, taken), "%s: our guess is the pieces we reached for" % note)
	# The host's word: its _state comes back after every request; a special round shows there.
	for i in 30:
		await process_frame
	if not await _until(func() -> bool: return gs.get(&"_acked_seq") == gs.get(&"_sent_seq"), "the host's answer to our picks"): return false
	var hand: Array = gs.player().scrap.duplicate(true)
	if not _ok(_hand_of(hand, taken, gs.player().specials.size() - specials), "%s: the host's answer keeps the pieces (%s of %s, %d special)" % [note, _parts(hand), _parts(taken), gs.player().specials.size() - specials]): return false
	_note(note, hand)
	return true


func _done() -> void:
	var f := FileAccess.open(SEEN, FileAccess.WRITE)
	f.store_string(JSON.stringify(seen))
	f.close()
	_write_log()
	quit(1 if _failed else 0)


## `hand` is `taken` less `specials` of them (the ones that came up special rounds), in order.
func _hand_of(hand: Array, taken: Array, specials: int) -> bool:
	if hand.size() + specials != taken.size():
		return false
	var j := 0
	for piece: Array in taken:
		if j < hand.size() and _same([hand[j]], [piece]):
			j += 1
	return j == hand.size()


func _note(key: String, pieces: Array) -> void:
	seen[key] = pieces.map(func(p: Array) -> Array: return [p[0], p[1].r, p[1].g, p[1].b] if not p.is_empty() else [])


func _noted(key: String) -> Array:
	return (seen.get(key, []) as Array).map(func(p: Array) -> Array: return [int(p[0]), Color(p[1], p[2], p[3])] if not p.is_empty() else [])


## Host: a hand note, once its contents settle for a throw (kept as last seen before the throw).
func _note_hand(key: String, pieces: Array) -> void:
	if not pieces.is_empty():
		_note(key, pieces)


func _note_landed(key: String, t: Array) -> void:
	var landed := []
	for n in t[0]:
		landed.append(pile.piece_of(t[1] + n))
	_note(key, landed)
	_ok(_same(landed, t[2]), "%s: they land as the same parts and tones (%s -> %s)" % [key, _parts(t[2]), _parts(landed)])


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].is_empty() or b[i].is_empty() or a[i][0] != b[i][0] or not (a[i][1] as Color).is_equal_approx(b[i][1]):
			return false
	return true


## Two notes (JSON-decoded or not) hold the same pieces; tones within a hair (the wire and JSON).
func _same_noted(a: Variant, b: Variant) -> bool:
	if not a is Array or not b is Array or a.is_empty() or a.size() != b.size():
		return false
	for i in a.size():
		var x: Array = a[i]
		var y: Array = b[i]
		if x.size() != 4 or y.size() != 4 or int(x[0]) != int(y[0]):
			return false
		for c in range(1, 4):
			if absf(float(x[c]) - float(y[c])) > 1e-4:
				return false
	return true


func _parts(pieces: Array) -> String:
	return ",".join(pieces.map(func(p: Array) -> String: return str(p[0]) if not p.is_empty() else "?"))


func _noted_parts(n: Variant) -> String:
	return ",".join((n as Array).map(func(p: Array) -> String: return str(int(p[0])) if not p.is_empty() else "?")) if n is Array else "?"


func _until(cond: Callable, what: String, secs := 30.0) -> bool:
	_at = "waiting: " + what
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			_ok(false, what + " (timed out)")
			return false
		await process_frame
	return true


func _ok(cond: bool, what: String) -> bool:
	var line := ("ok   " if cond else "FAIL ") + what
	_log.append(line)
	print(line)
	if not cond:
		_failed = true
	return cond


func _fail(what: String) -> void:
	_ok(false, what)
	if _client_pid != 0:
		if OS.is_process_running(_client_pid):
			OS.kill(_client_pid)
		print("--- client log:\n", FileAccess.get_file_as_string(LOG))
		var engine := FileAccess.get_file_as_string(ENGINE_LOG).split("\n")
		print("--- client engine output, last lines:\n", "\n".join(engine.slice(-40)))
	quit(1)


func _start_client() -> int:
	for p in [LOG, ENGINE_LOG, SEEN, STEP]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	return OS.create_process(OS.get_executable_path(), ["--headless", "--log-file", ProjectSettings.globalize_path(ENGINE_LOG),
		"--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/scrap_net_check.gd", "--", "--client"])


func _write_log() -> void:
	var lines := _log.duplicate()
	if _at:
		lines.append(_at)
	var f := FileAccess.open(LOG, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
