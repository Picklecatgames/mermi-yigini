extends SceneTree
## Headless check for the factory (scripts/factory/), three processes:
##   Godot.exe --headless --path . -s res://tools/factory_check.gd
## First the simulation alone: tables, belts round a corner and over a join, a machine's mass balance,
## taking things down, a save through JSON that runs on identically.
## Then for real: a client builds heap -> extractor -> belt -> dismantler -> belt -> kasa through its
## requests; the items reach the shared kasa and the heap's count falls by what was dug. A second
## client joins in the middle and must have the same factory. A client knocked out of step finds out
## by the hash and comes back. The extractor comes down, everything drains, and all three must end
## with the same kasa and the same heap, bit for bit.
## Last it measures: host step time and traffic with the real chain, then with 300 machines and 2000
## items on belts; clients must stay in step through it.

const PORT := 24757  # not Net.PORT or the other checks'
const DIR := "user://factory_check/"
const ENOUGH := 8  # units the chain must deliver before the joiner comes
const MEASURE := 10.0  # s

var gs: Node
var net: Node
var main: Node
var f: Node
var sim: FactorySim
var role := "host"
var _pids := {}
var _results := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.get_slice("=", 1)
	if role == "host":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
		for name in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + name))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	net = root.get_node("Net")
	for i in 3:
		await physics_frame
	f = gs.factory
	sim = f.sim
	match role:
		"host": await _host()
		"builder": await _builder()
		"late": await _late()


# --- The simulation alone ---

func _alone() -> bool:
	var d := FactoryData.shared()
	var parts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/hurda/hurda.json"))
	if not _ok(d.items.size() - d.scrap_first == parts.size(), "every hurda.json part is an item (%d)" % parts.size()): return false
	var one: Dictionary = parts[0]
	var it0: int = d.item_index["hurda/" + one.id]
	if not _ok(d.item_grams[it0] == roundi(float(one.kutle_kg) * 1000.0) and d.item_ids[d.item_material[it0]] == one.materyal, "a part's mass and material come from hurda.json"): return false
	var belt: int = d.kind_index["bant"]
	var dag: int = d.kind_index["cekici"]
	var sok: int = d.kind_index["sokucu"]
	var ez: int = d.kind_index["ezici"]
	var kasa: int = d.kind_index["kasa"]

	# Round a corner into a kasa: the item arrives, and takes as long as the path is.
	var s := FactorySim.new()
	s.apply(["k", d.item_index["demir"], 100000])
	s.apply(["k", d.item_index["celik"], 100000])
	s.apply(["s", 12345])
	for x in range(-30, -26):
		s.apply(["p", belt, x, 0, 0])
	for z in range(0, 3):
		s.apply(["p", belt, -26, z, 1])
	s.apply(["p", kasa, -27, 3, 1])
	s.run_step()
	if not _ok(s.l_slots.size() == 1 and s.l_slots[0].size() == 7, "seven belts round a corner are one line"): return false
	var demir: int = d.item_index["demir"]
	var before := s.stock[demir]
	s.apply(["f", demir, 1])
	var taken := 0
	while s.stock[demir] == before and taken < 200:
		s.run_step()
		taken += 1
	if not _ok(s.stock[demir] == before + 1, "an item comes off the belt into the kasa"): return false
	# It was laid at the very front: it needs one step to go in.
	s.apply(["f", demir, 3])
	var ran := 0
	while s.items_on_belts() > 0 and ran < 200:
		s.run_step()
		ran += 1
	if not _ok(s.stock[demir] == before + 4 and ran <= 3 * 3 + 2, "three in a row go in at the belt's pace"): return false

	# A real time on the belt: one fed in at the tail by an extractor's output takes the length.
	var t := FactorySim.new()
	t.apply(["k", d.item_index["demir"], 100000])
	t.apply(["k", d.item_index["celik"], 100000])
	t.apply(["s", 7])
	t.apply(["p", dag, -40, 0, 0])
	for x in range(-38, -28):
		t.apply(["p", belt, x, 1, 0])
	t.apply(["p", kasa, -28, 0, 0])
	t.apply(["o", 0, 1])
	var steps := 0
	while t.delivered == 0 and steps < 300:
		t.run_step()
		steps += 1
	if not _ok(t.delivered == 1 and absi(steps - 100) <= 5, "1 m/s over 10 m takes 10 s (%d steps)" % steps): return false

	# Two belts join: the far belt starts a line of its own, and nothing is lost.
	var j := FactorySim.new()
	j.apply(["k", d.item_index["demir"], 100000])
	j.apply(["s", 9])
	for x in range(-40, -36):
		j.apply(["p", belt, x, 5, 0])
	for z in range(1, 5):
		j.apply(["p", belt, -36, z, 1])
	for x in range(-36, -32):
		j.apply(["p", belt, x, 5, 0])
	j.apply(["p", kasa, -32, 5, 0])
	j.run_step()
	if not _ok(j.l_slots.size() == 3, "a join makes three lines"): return false
	var st0 := j.stock[demir]
	j.apply(["f", demir, 40])
	var on := j.items_on_belts()
	for i in 600:
		j.run_step()
	if not _ok(j.items_on_belts() == 0 and j.stock[demir] == st0 + on, "all %d through the join" % on): return false

	# A ring keeps its items going round and doesn't lock up with room to spare.
	var r := FactorySim.new()
	r.apply(["k", demir, 100000])
	r.apply(["s", 9])
	_ring(r, belt, -40, 10)
	r.run_step()
	if not _ok(r.l_slots.size() == 1, "a ring is one line"): return false
	r.apply(["f", demir, 10])
	var ring_gaps0 := Array(r.l_items[0])
	for i in 400:
		r.run_step()
	if not _ok(r.items_on_belts() == 10 and ring_gaps0.size() == 10, "a ring keeps what's on it"): return false

	# The dismantler's balance: whole units out, the grams left over stay in it, nothing else.
	var m := FactorySim.new()
	m.apply(["k", demir, 100000])
	m.apply(["k", d.item_index["celik"], 100000])
	m.apply(["s", 4242])
	m.apply(["p", dag, -50, 0, 0])
	m.apply(["p", sok, -48, 0, 0])
	m.apply(["p", kasa, -46, 0, 0])
	m.apply(["o", 0, 30])
	var base := m.stock.duplicate()
	for i in 1500:
		m.run_step()
	if not _ok(m.budget[0] == 0, "the extractor used all 30"): return false
	var made := 0
	for i in d.material_count:
		made += (m.stock[i] - base[i]) * d.grams_per_unit + m.rest[1][i]
	var mass := _mass_of_rolls(d, 4242, 30)
	if not _ok(made == mass, "what the kasa got plus what's left in the machine is what came in: %d g, %d g" % [made, mass]): return false

	# The plain recipe: four tin to a steel, straight from a belt.
	var p := FactorySim.new()
	var tin: int = d.item_index["teneke"]
	var steel: int = d.item_index["celik"]
	p.apply(["k", demir, 100000])
	p.apply(["k", steel, 100000])
	p.apply(["s", 5])
	for x in range(-50, -46):
		p.apply(["p", belt, x, 0, 0])
	p.apply(["p", ez, -46, 0, 0])
	p.apply(["p", kasa, -44, 0, 0])
	p.run_step()
	p.apply(["f", tin, 8])
	var steel0 := p.stock[steel]
	for i in 200:
		p.run_step()
	if not _ok(p.stock[steel] == steel0 + 2 and p.items_on_belts() == 0, "eight tin make two steel (+%d)" % (p.stock[steel] - steel0)): return false

	# Taking things down: items on the belt and what it cost go back to the kasa.
	var q := FactorySim.new()
	q.apply(["k", demir, 100000])
	q.apply(["s", 5])
	for x in range(-50, -40):
		q.apply(["p", belt, x, 0, 0])
	q.run_step()
	q.apply(["f", demir, 20])
	var all0 := q.stock[demir]
	var on_q := q.items_on_belts()
	var mid: int = q.slot_at(-45, 0)
	q.apply(["x", mid])
	for i in 100:
		q.run_step()
	if not _ok(q.count == 9 and q.l_slots.size() == 2, "a belt out of the middle cuts the line in two"): return false
	if not _ok(q.stock[demir] + q.items_on_belts() == all0 + on_q + 1, "nothing lost by taking one down"): return false
	q.apply(["p", belt, -45, 0, 0])  # back on the freed slot
	for i in 300:
		q.run_step()
	if not _ok(q.l_slots.size() == 1 and q.free_slots.is_empty(), "put back, one line again"): return false

	# A save through JSON runs on exactly like the original.
	var a := _busy_sim(d)
	for i in 137:
		a.run_step()
	var json := JSON.stringify(a.to_save())
	var b := FactorySim.new()
	b.from_save(JSON.parse_string(json))
	if not _ok(a.state_hash() == b.state_hash(), "a save comes back with the same hash"): return false
	for i in 300:
		a.run_step()
		b.run_step()
	if not _ok(a.state_hash() == b.state_hash() and a.delivered == b.delivered and a.delivered > 0, "and runs on the same (%d delivered)" % a.delivered): return false
	print("save of that factory: %d bytes as JSON" % json.length())

	# Refused: cells off the grid, what it can't afford, taken cells.
	var e := FactorySim.new()
	if not _ok(not e.can_place(kasa, 500, 0, 0) and not e.can_place(99, -30, 0, 0) and not e.can_place(belt, -30, 0, 7), "off the grid or unknown: no"): return false
	e.apply(["k", demir, -e.stock[demir]])
	if not _ok(not e.can_place(belt, -30, 0, 0), "nothing in the kasa: no belt"): return false
	e.apply(["k", demir, 10])
	e.apply(["p", belt, -30, 0, 0])
	if not _ok(not e.can_place(belt, -30, 0, 0), "a cell holds one thing"): return false
	print("alone: all good")
	return true


func _mass_of_rolls(d: FactoryData, seed0: int, n: int) -> int:
	var rng := seed0
	var total := 0
	for i in n:
		rng = (rng * 1103515245 + 12345) & 0x7fffffff
		total += d.item_grams[d.scrap_first + (rng >> 8) % (d.items.size() - d.scrap_first)]
	return total


func _ring(s: FactorySim, belt: int, x: int, z: int) -> void:
	s.apply(["p", belt, x, z, 0])
	s.apply(["p", belt, x + 1, z, 0])
	s.apply(["p", belt, x + 2, z, 1])
	s.apply(["p", belt, x + 2, z + 1, 1])
	s.apply(["p", belt, x + 2, z + 2, 2])
	s.apply(["p", belt, x + 1, z + 2, 2])
	s.apply(["p", belt, x, z + 2, 3])
	s.apply(["p", belt, x, z + 1, 3])


func _busy_sim(d: FactoryData) -> FactorySim:
	var a := FactorySim.new()
	a.apply(["k", d.item_index["demir"], 100000])
	a.apply(["k", d.item_index["celik"], 100000])
	a.apply(["s", 321])
	a.apply(["p", d.kind_index["cekici"], -50, 0, 0])
	for x in range(-48, -44):
		a.apply(["p", d.kind_index["bant"], x, 1, 0])
	a.apply(["p", d.kind_index["ezici"], -44, 0, 0])
	for x in range(-42, -38):
		a.apply(["p", d.kind_index["bant"], x, 1, 0])
	a.apply(["p", d.kind_index["kasa"], -38, 0, 0])
	a.apply(["o", 0, 500])
	return a


# --- The big one: `triples` of extractor -> dismantler -> kasa, `rings` of belts, items on them ---

func _big(apply_cmd: Callable, the_sim: FactorySim, triples: int, rings: int, items: int) -> void:
	var d := the_sim.data
	var belt: int = d.kind_index["bant"]
	apply_cmd.call(["k", d.item_index["demir"], 1000000])
	apply_cmd.call(["k", d.item_index["celik"], 1000000])
	if the_sim.rng == 0:
		apply_cmd.call(["s", 99])
	var x0 := -60
	var z0 := -40
	# Round what already stands (the live run's chain).
	var put := func(k: int, x: int, z: int, dir: int) -> void:
		if the_sim.can_place(k, x, z, dir):
			apply_cmd.call(["p", k, x, z, dir])
	var extractors := PackedInt32Array()
	for i in triples:
		var x := x0 + (i % 9) * 6
		var z := z0 + (i / 9) * 2
		put.call(d.kind_index["cekici"], x, z, 0)
		extractors.append(the_sim.slot_at(x, z))
		put.call(d.kind_index["sokucu"], x + 2, z, 0)
		put.call(d.kind_index["kasa"], x + 4, z, 0)
	var z1 := z0 + (triples / 9 + 1) * 2
	for i in rings:
		var x := x0 + (i % 18) * 3
		var z := z1 + (i / 18) * 3
		for c: Array in [[x, z, 0], [x + 1, z, 0], [x + 2, z, 1], [x + 2, z + 1, 1], [x + 2, z + 2, 2], [x + 1, z + 2, 2], [x, z + 2, 3], [x, z + 1, 3]]:
			put.call(belt, c[0], c[1], c[2])
	for s in extractors:
		if s >= 0:
			apply_cmd.call(["o", s, 1000000])
	# Twenty kinds of item, so the view has twenty looks to fill.
	var kinds := 20
	for k in kinds:
		var it := d.scrap_first + k * 7 if k >= 10 else k
		apply_cmd.call(["f", it, items / kinds])


func _measure_alone(triples: int, rings: int, items: int) -> String:
	var s := FactorySim.new()
	_big(func(c: Array) -> void: s.apply(c), s, triples, rings, items)
	s.run_step()
	for i in 200:  # machines and belts running
		s.run_step()
	var total := 0
	var worst := 0
	var n := 300
	for i in n:
		var t0 := Time.get_ticks_usec()
		s.run_step()
		var t := Time.get_ticks_usec() - t0
		total += t
		worst = maxi(worst, t)
	var t0 := Time.get_ticks_usec()
	var h := s.state_hash()
	var hash_us := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	var save := s.to_save()
	var save_us := Time.get_ticks_usec() - t0
	return "%d structures, %d on belts, %d lines: step %.2f ms mean, %.2f ms worst; hash %.2f ms (%d), whole state %.1f ms, %d bytes" % [s.count, s.items_on_belts(), s.l_slots.size(), total * 0.001 / n, worst * 0.001, hash_us * 0.001, h & 0xff, save_us * 0.001, var_to_bytes(save).size()]


# --- Host ---

func _host() -> void:
	if not await _alone(): return
	print(_measure_alone(40, 22, 2000))
	print(_measure_alone(100, 83, 2000))
	if net.host(PORT) != OK:
		return _fail("could not host on %d" % PORT)
	var pile0: int = gs.pile
	_pids.builder = _start("builder")
	if not await _until(func() -> bool: return net.multiplayer.get_peers().size() == 1, "the builder to join", 60.0): return
	# The joiner's heap and pieces take a while to go across; the window starts once that's done.
	var settling: Array = await _traffic(2.0)
	while settling[0] > 20000.0:
		settling = await _traffic(2.0)
	var none: Array = await _traffic(MEASURE)  # the rest of the game: poses, the heap's clock
	print("traffic with no factory, one client: %.0f bytes/s, %.1f packets/s" % none)
	_mark("build")

	if not await _until(func() -> bool: return sim.count >= 9, "the client's factory to go up", 60.0): return
	if not _ok(sim.count == 9, "exactly what the client built stands; the forged ones didn't (%d)" % sim.count): return
	if not _ok(gs.stock_of("demir") < 60 and gs.stock_of("celik") < 80, "the building came out of the shared kasa"): return
	f.reset_timing()
	if not await _until(func() -> bool: return sim.delivered >= ENOUGH, "the chain to deliver %d units" % ENOUGH, 180.0): return
	print("chain: %d units in the kasa after step %d; heap count down by %d" % [sim.delivered, sim.step, pile0 - gs.pile])
	if not _ok(pile0 - gs.pile == f.dug and f.dug > 0, "the heap's count fell by what the extractor dug"): return

	var chain_traffic: Array = await _traffic(MEASURE)
	print("traffic with the real chain and one client: %.0f bytes/s, %.1f packets/s" % chain_traffic)
	print("host step, real chain: %.3f ms mean, %.3f ms worst" % [_ms(f.step_us, f.steps_timed), f.step_us_max * 0.001])
	_pids.late = _start("late")
	if not await _mark_wait("late_ok", 90.0): return
	_mark("knock")
	if not await _mark_wait("knocked_ok", 60.0): return

	# Down with the extractor, and let it all drain.
	var ex_at := _extractor_cell()
	gs.request_factory_remove(ex_at.x, ex_at.y)
	if not await _until(_drained, "the factory to drain", 120.0): return
	var pile_node: Node = main.get_node("Pile")
	if not await _until(func() -> bool: return not pile_node._any_active and pile_node._digs.is_empty() and not pile_node._any_slump and pile_node._awake.is_empty(), "the heap to settle", 60.0): return
	_write("final", {"stock": _stock_text(), "delivered": sim.delivered, "step": sim.step, "count": sim.count, "pile": gs.pile, "heap": hash(pile_node._h), "heap_step": pile_node.step})
	if not await _mark_wait("builder_final", 90.0): return
	if not await _mark_wait("late_final", 90.0): return

	# The measuring: 300 machines and 2000 items, with both clients following along.
	var quiet: Array = await _traffic(MEASURE)
	print("traffic with a few idle belts, two clients: %.0f bytes/s, %.1f packets/s" % quiet)
	_big(func(c: Array) -> void: f.command(c), sim, 100, 83, 2000)
	await _frames(30)
	print("live: %d structures, %d items on belts, %d lines" % [sim.count, sim.items_on_belts(), sim.l_slots.size()])
	if not _ok(sim.items_on_belts() >= 1900 and sim.count >= 700, "the big factory is up"): return
	f.reset_timing()
	var worst_draw := 0
	var draw_total := 0
	var frames := 0
	var t0 := Time.get_ticks_msec()
	var big_traffic0: Array = _traffic_now()
	while Time.get_ticks_msec() - t0 < MEASURE * 1000.0:
		await process_frame
		worst_draw = maxi(worst_draw, f.view.draw_us)
		draw_total += f.view.draw_us
		frames += 1
	var big_traffic := _traffic_since(big_traffic0, MEASURE)
	print("traffic with 300 machines and 2000 items, two clients: %.0f bytes/s, %.1f packets/s" % big_traffic)
	print("host step, live: %.3f ms mean, %.3f ms worst over %d steps" % [_ms(f.step_us, f.steps_timed), f.step_us_max * 0.001, f.steps_timed])
	print("view: redraw of %d items %.2f ms (worst %.2f), 30 times a second" % [f.view.drawn, draw_total * 0.001 / maxi(frames, 1), worst_draw * 0.001])
	if not _ok(f.view.drawn > 0, "the view draws the items"): return
	_mark("measured")
	if not await _mark_wait("builder_done", 60.0): return
	if not await _mark_wait("late_done", 60.0): return
	for who in ["builder", "late"]:
		print(who, ": ", FileAccess.get_file_as_string(DIR + who + "_result.txt"))
	var t1 := Time.get_ticks_msec()
	while _running() and Time.get_ticks_msec() - t1 < 20000:
		await process_frame
	for who: String in _pids:
		if OS.get_process_exit_code(_pids[who]) != 0:
			return _fail("%s side failed" % who)
	print("factory_check OK")
	quit()


func _running() -> bool:
	for who: String in _pids:
		if OS.is_process_running(_pids[who]):
			return true
	return false


func _extractor_cell() -> Vector2i:
	for s in sim.kind.size():
		if sim.kind[s] == sim.data.kind_index["cekici"]:
			return Vector2i(sim.cell_x(sim.cell[s]), sim.cell_z(sim.cell[s]))
	return Vector2i.ZERO


func _drained() -> bool:
	if sim.dirty or sim.items_on_belts() > 0:
		return false
	for s in sim.kind.size():
		if sim.kind[s] >= 0 and (sim.timer[s] != 0 or not sim.held[s].is_empty() or not sim.out[s].is_empty() or sim.crafting[s] >= 0):
			return false
	return true


func _stock_text() -> String:
	return JSON.stringify(Array(sim.stock))


func _ms(us: int, n: int) -> float:
	return us * 0.001 / maxi(n, 1)


func _traffic_now() -> Array:
	var host: ENetConnection = (net.multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
	host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)
	return []


func _traffic_since(_from: Array, secs: float) -> Array:
	var host: ENetConnection = (net.multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
	return [host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / secs, host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS) / secs]


func _traffic(secs: float) -> Array:
	var from := _traffic_now()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		await process_frame
	return _traffic_since(from, secs)


# --- The client who builds ---

func _builder() -> void:
	net.join("127.0.0.1", PORT)
	if not await _connected(): return
	if not await _mark_wait("build", 60.0): return
	# Asking for nonsense gets nothing.
	gs.request_factory_place("yok", -10, 0, 0)
	gs.request_factory_place("bant", 500, 500, 0)
	gs.request_factory_place("bant", -10, 0, 9)
	gs.request_factory_remove(-10, 0)
	await _frames(30)
	if not _ok(sim.count == 0, "nothing went up from nonsense"): return
	var at := _extractor_spot()
	if at == Vector2i.MAX:
		return _fail("no spot for an extractor at the heap's foot")
	var x := at.x
	var z := at.y
	gs.request_factory_place("cekici", x, z, 0)
	for i in 3:
		gs.request_factory_place("bant", x + 2 + i, z + 1, 0)
	gs.request_factory_place("sokucu", x + 5, z, 0)
	gs.request_factory_place("bant", x + 7, z + 1, 0)
	gs.request_factory_place("bant", x + 8, z + 1, 0)
	gs.request_factory_place("kasa", x + 9, z, 0)
	if not await _until(func() -> bool: return sim.count == 8 and not sim.dirty, "the factory to reach this client", 30.0): return
	# Same again, from a second request place, so the host's count shows the forged ones are out.
	gs.request_factory_place("bant", x + 3, z + 3, 0)
	if not await _until(func() -> bool: return sim.count == 9, "one more", 30.0): return
	if not await _until(func() -> bool: return sim.delivered >= 1, "the first units here too", 120.0): return
	if not _ok(f.desyncs == 0, "in step all the way"): return
	if not await _mark_wait("knock", 180.0): return
	# Knocked out of step: the next hash says so, and the host's whole state puts it right.
	sim.stock[0] += 1
	if not await _until(func() -> bool: return f.desyncs >= 1, "the hash to catch it", 30.0): return
	var was: int = f.desyncs
	if not await _until(func() -> bool: return not f._asked_resync, "the whole state", 30.0): return
	await _seconds(5.0)
	if not _ok(f.desyncs == was, "in step again after it"): return
	_mark("knocked_ok")
	await _final("builder")
	await _keep_up_and_report("builder")


# --- The client who comes in the middle ---

func _late() -> void:
	net.join("127.0.0.1", PORT)
	if not await _connected(): return
	if not await _until(func() -> bool: return sim.count == 9, "the factory on joining", 30.0): return
	if not _ok(sim.step > 0 and sim.delivered >= ENOUGH, "it came with the kasa as it is (%d delivered)" % sim.delivered): return
	if not await _until(func() -> bool: return f.view.drawn > 0, "items to draw", 30.0): return
	var first: int = sim.delivered
	if not await _until(func() -> bool: return sim.delivered > first, "the joiner's copy to run on", 60.0): return
	await _seconds(6.0)  # a few hashes go by
	if not _ok(f.desyncs == 0, "in step with the host after joining"): return
	_mark("late_ok")
	await _final("late")
	await _keep_up_and_report("late")


func _extractor_spot() -> Vector2i:
	var k: int = sim.data.kind_index["cekici"]
	for x in range(-7, -20, -1):
		for z in range(-12, 12):
			if f.can_build(k, x, z, 0):
				# The rest of the chain must fit too.
				var fits := true
				for i in range(2, 12):
					if not sim.can_place(sim.data.kind_index["bant"], x + i, z + 1, 0):
						fits = false
				if fits:
					return Vector2i(x, z)
	return Vector2i.MAX


func _connected() -> bool:
	return await _until(func() -> bool: return net.is_client and gs.synced() and gs._sent_seq > 0, "connect and hello", 60.0)


func _final(who: String) -> void:
	if not await _until(func() -> bool: return FileAccess.file_exists(DIR + "final.json"), "the host's final word", 200.0): return
	var host: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "final.json"))
	if not await _until(func() -> bool: return sim.step >= int(host.step), "this copy to reach that step", 60.0): return
	var pile_node: Node = main.get_node("Pile")
	if not await _until(func() -> bool: return gs.pile == int(host.pile) and pile_node.step >= int(host.heap_step) and pile_node._pending.is_empty() and not pile_node._any_active and pile_node._digs.is_empty() and not pile_node._any_slump and pile_node._awake.is_empty(), "the heap here to settle", 60.0): return
	if not _ok(_stock_text() == host.stock, "the same kasa as the host"): return
	if not _ok(sim.delivered == int(host.delivered), "the same delivered"): return
	if not _ok(sim.count == int(host.count) and sim.items_on_belts() == 0, "the same factory, drained"): return
	if not _ok(hash(pile_node._h) == int(host.heap), "the heap bit for bit as the host's"): return
	_mark(who + "_final")


func _keep_up_and_report(who: String) -> void:
	if not await _until(func() -> bool: return sim.count >= 700, "the big factory", 120.0): return
	f.reset_timing()
	var was: int = f.desyncs
	if not await _mark_wait("measured", 120.0): return
	await _seconds(2.0)
	if not _ok(f.desyncs == was, "in step all through the big factory"): return
	var lag: int = f._limit - sim.step
	var text := "step %.3f ms mean, %.3f ms worst over %d steps; %d steps behind the clock" % [_ms(f.step_us, f.steps_timed), f.step_us_max * 0.001, f.steps_timed, lag]
	var file := FileAccess.open(DIR + who + "_result.txt", FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_mark(who + "_done")
	await _frames(10)
	quit(0)


# --- Helpers ---

func _mark(name: String) -> void:
	var file := FileAccess.open(DIR + name, FileAccess.WRITE)
	file.store_string("1")
	file.close()


func _write(name: String, what: Dictionary) -> void:
	var tmp := FileAccess.open(DIR + name + ".tmp", FileAccess.WRITE)
	tmp.store_string(JSON.stringify(what))
	tmp.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(DIR + name + ".tmp"), ProjectSettings.globalize_path(DIR + name + ".json"))


func _mark_wait(name: String, secs: float) -> bool:
	return await _until(func() -> bool: return FileAccess.file_exists(DIR + name), name, secs)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await process_frame


func _start(who: String) -> int:
	var engine := ProjectSettings.globalize_path(DIR + who + "_engine.log")
	return OS.create_process(OS.get_executable_path(), ["--headless", "--log-file", engine,
		"--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/factory_check.gd", "--", "--role=" + who])


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
	else:
		print("  ok (", role, "): ", what)
	return cond


func _fail(what: String) -> void:
	printerr("factory_check FAIL (", role, "): ", what)
	if role == "host":
		for who: String in _pids:
			if OS.is_process_running(_pids[who]):
				OS.kill(_pids[who])
			print("--- ", who, " engine output, last lines:\n", "\n".join(FileAccess.get_file_as_string(DIR + who + "_engine.log").split("\n").slice(-30)))
	quit(1)
