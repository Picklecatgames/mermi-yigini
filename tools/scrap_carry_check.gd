extends SceneTree
## Headless check that a scrap piece stays itself in the hand and out of it (2026-11-05, the user:
## a piece thrown down turned into another, and looked wrong in hand). Picked up, thrown, picked up
## again, a few rounds: GameState's hand (PlayerState.scrap) keeps each piece's part and tone, the
## first-person row draws them as the heap did (its light mesh, its material, its tone), the thrown
## ones land as the same parts and tones, and a piece dug out of the heap keeps the host's roll. A
## client's side: the host's answer (_state) and its thrown event, through the wire's encoding.
##   Godot.exe --headless --path . -s res://tools/scrap_carry_check.gd

const ROUNDS := 3
const TAKE := 4

var _failed := false
var _thrown: Array = []  # [count, first_id, pieces] of the last bullets_thrown


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	gs.request_pick_character("oldman")
	var me: Node3D = main.get_node("Player")
	var pile: Node3D = root.get_tree().get_first_node_in_group("bullet_pile")
	gs.bullets_thrown.connect(func(_f: Vector3, _d: Vector3, count: int, first: int, pieces: Array) -> void:
		_thrown = [count, first, pieces])
	gs.player().carried = 0
	gs.player().scrap.clear()
	gs.player().levels["carry"] = 9  # a hand of 10

	# Some spilled pieces and some of the heap's own surface, different parts.
	var ids: Array[int] = []
	var parts_seen := {}
	for id: int in pile.get(&"_id_index").keys():
		var piece: Array = pile.piece_of(id)
		if not parts_seen.has(piece[0]) and ids.size() < TAKE / 2:
			parts_seen[piece[0]] = true
			ids.append(id)
	var slot_id: Array = pile.get(&"_slot_id")
	for s in slot_id.size():
		var id: int = slot_id[s]
		if id >= 0 and pile.has_loose(id):
			var piece: Array = pile.piece_of(id)
			if not piece.is_empty() and not parts_seen.has(piece[0]):
				parts_seen[piece[0]] = true
				ids.append(id)
				if ids.size() >= TAKE:
					break
	_expect(ids.size() == TAKE, "%d different pieces to take" % TAKE)

	for r in ROUNDS:
		var want: Array = []
		for id in ids:
			var piece: Array = pile.piece_of(id)
			var before: int = gs.carried
			gs.request_pick_up_loose(id)
			if gs.carried > before:  # else it turned out a special round (1 in 75), in the pocket
				want.append(piece)
		_expect(want.size() >= TAKE - 1 and gs.carried == want.size(), "round %d: %d taken, %d in hand" % [r + 1, want.size(), gs.carried])
		var scrap: Array = gs.player().scrap.duplicate(true)
		_expect(_same(scrap, want), "round %d: the hand holds the pieces taken (%s)" % [r + 1, _parts(scrap)])
		await process_frame
		_check_row(me, pile, scrap, "round %d" % (r + 1))
		var parts := _parts(scrap)
		_thrown = []
		gs.request_throw(me.global_position + Vector3.UP * 1.5, Vector3.FORWARD)
		_expect(gs.carried == 0 and gs.player().scrap.is_empty(), "round %d: the hand is empty after the throw" % (r + 1))
		_expect(not _thrown.is_empty() and _same(_thrown[2], scrap), "round %d: what flew is what was held" % (r + 1))
		for i in 90:
			await physics_frame
		ids.clear()
		var landed: Array = []
		for n in _thrown[0]:
			ids.append(_thrown[1] + n)
			landed.append(pile.piece_of(_thrown[1] + n))
		_expect(_same(landed, scrap), "round %d: thrown, they land as the same parts and tones (%s -> %s)" % [r + 1, parts, _parts(landed)])
		print("round %d: %s held, thrown and landed the same" % [r + 1, parts])


	# Dug out of the heap (the mountains' scrap has no pieces of its own): the host's roll, kept.
	var at: Vector3 = pile.top_point()
	var dug: int = gs.request_pick_up(at, 2)
	gs.player().specials.clear()
	var held: Array = gs.player().scrap.duplicate(true)
	_expect(dug > 0 and held.size() == gs.carried and held.all(func(p: Array) -> bool: return p[0] >= 0), "dug pieces are known parts (%s)" % _parts(held))
	await process_frame
	_check_row(me, pile, held, "dug")
	gs.request_throw(me.global_position + Vector3.UP * 1.5, Vector3.FORWARD)
	for i in 60:
		await physics_frame
	var landed: Array = []
	for n in _thrown[0]:
		landed.append(pile.piece_of(_thrown[1] + n))
	_expect(_same(landed, held), "dug and thrown, they land as rolled (%s -> %s)" % [_parts(held), _parts(landed)])

	# A client: what the host says comes over the wire. Its answer (_state) gives the hand the host's
	# pieces in place of the guesses; its thrown event decodes to the same pieces.
	var wire: Array = bytes_to_var(var_to_bytes([held]))[0]
	_expect(_same(wire, held), "pieces survive the wire's encoding")
	var p: Object = gs.player()
	gs.call(&"_state", gs.get(&"_sent_seq"), held.size(), wire, p.loaded, p.gold, p.levels, p.infinite_ammo, p.keys, p.gun, p.specials, p.armed, p.has_pistol, p.rounds)
	await process_frame
	_expect(gs.carried == held.size() and _same(gs.player().scrap, held), "the host's answer sets the client's hand")
	_check_row(me, pile, held, "host's answer")

	print("FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)


## The first-person row shows `scrap` as the heap draws it.
func _check_row(me: Node, pile: Node, scrap: Array, what: String) -> void:
	var row: Node3D = me.get(&"_scrap_hand")
	var low: Array = pile.get(&"_part_low")
	var shown := 0
	for i in row.get_child_count():
		var mi := row.get_child(i) as MultiMeshInstance3D
		if not mi.visible:
			continue
		var piece: Array = scrap[i]
		var mm := mi.multimesh
		# Its tone as player.gd gave it to the MultiMesh (headless, the dummy renderer keeps no colours).
		var tone: Color = (me.get(&"_scrap_looks")[i] as Array)[5]
		_expect(mm.mesh == low[piece[0]] and mi.material_override == pile.get(&"_surface")[piece[0]].material_override and tone.is_equal_approx(piece[1]), "%s: hand piece %d is part %d in its tone (%s, %s)" % [what, i, piece[0], tone, piece[1]])
		var b := mi.transform.basis
		var sx := b.x.length()
		_expect(is_equal_approx(sx, b.y.length()) and is_equal_approx(sx, b.z.length()) and absf(b.x.dot(b.y)) < 1e-4 * sx * sx, "%s: hand piece %d is scaled evenly, not skewed" % [what, i])
		shown += 1
	_expect(shown == mini(scrap.size(), me.HAND_MAX), "%s: %d pieces in the row" % [what, shown])


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].is_empty() or b[i].is_empty() or a[i][0] != b[i][0] or not (a[i][1] as Color).is_equal_approx(b[i][1]):
			return false
	return true


func _parts(pieces: Array) -> String:
	return ",".join(pieces.map(func(p: Array) -> String: return str(p[0]) if not p.is_empty() else "?"))


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
		print("FAIL " + what)
