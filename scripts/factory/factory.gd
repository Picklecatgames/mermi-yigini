extends Node
## Runs the factory's simulation (factory_sim.gd) on this machine and keeps it in step with the host.
## Lives under GameState, which holds it as `factory`; its requests are GameState's request_factory_*.
##
## The host steps at TICK_HZ, checks every command and applies it at once, sending it stamped with the
## step it went in at, and tells everyone the step now and then (GameState factory_clock). A client
## runs the same simulation up to that step and no further, applying each command at its stamp, the
## way the heap does (pile.gd). So the traffic is commands and a clock, however many items there are.
## Now and then the clock carries the state's hash: a client that disagrees asks for the whole state
## (request_factory_resync), which is also what a joiner gets. Only the host rolls (the seed) and only
## the host digs the heap: the pieces it took reach the simulation as a command, so a dry heap stops
## the extractors on every peer on the same step.

const CLOCK_STEPS := 5  # the host says where it is twice a second...
const HASH_STEPS := 20  # ...and every other second what the state should be
const BUILD_REACH := 40.0  # m: how far from a client's body it may build (a first guess)
const CATCH_UP_MAX := 3  # steps a frame after a slow frame, on the host
const RESYNC_WAIT := 5.0  # s: at most one whole state per peer this often
const DT := 1.0 / FactorySim.TICK_HZ
const WANT_LAG := 5.0  # steps a client stays behind the clock, so it never has to wait for the next one

var sim := FactorySim.new()
var view: Node3D
var desyncs := 0  # client: hashes that didn't match
var dug := 0  # host: pieces taken from the heap
var granted := 0  # host: pieces handed to extractors
# Measured, for tools/factory_check.gd.
var step_us := 0
var step_us_max := 0
var steps_timed := 0

var _accum := 0.0
var _limit := 0  # client: how far the host has said it is
var _pending: Array = []  # client: [stamp, cmd], in order
var _expect := {}  # client: step -> hash
var _asked_resync := false  # client: one request at a time
var _resync_at := {}  # host: peer -> when it last got a whole state


func _ready() -> void:
	GameState.factory_cmd.connect(_on_cmd)
	GameState.factory_clock.connect(_on_clock)
	GameState.factory_snapshot.connect(_on_snapshot)
	multiplayer.peer_connected.connect(func(id: int) -> void:
		if multiplayer.is_server():
			GameState.send_factory_snapshot(id))
	view = preload("res://scripts/factory/factory_view.gd").new()
	view.factory = self
	add_child(view)
	if OS.is_debug_build():
		var tool: Node = preload("res://scripts/factory/factory_debug.gd").new()
		tool.factory = self
		add_child(tool)


func _process(delta: float) -> void:
	if Net.is_client:
		_run_client(delta)
	else:
		_run_host(delta)
	if sim.stock_dirty:
		sim.stock_dirty = false
		GameState.stock_changed.emit()


# --- Host ---

func _run_host(delta: float) -> void:
	_accum += delta
	var n := 0
	while _accum >= DT and n < CATCH_UP_MAX:
		_accum -= DT
		n += 1
		_timed_step()
		var s := sim.step
		if sim.count > 0 and s % CLOCK_STEPS == 0:
			if Net.online:
				GameState._world(&"factory_clock", [s, sim.state_hash() if s % HASH_STEPS == 0 else 0])
			_dig_for_extractors()
	if _accum > 1.0:
		_accum = 0.0  # a long stall isn't made up


func _timed_step() -> void:
	var t0 := Time.get_ticks_usec()
	sim.run_step()
	var t := Time.get_ticks_usec() - t0
	step_us += t
	step_us_max = maxi(step_us_max, t)
	steps_timed += 1


func reset_timing() -> void:
	step_us = 0
	step_us_max = 0
	steps_timed = 0


## Host: goes in now, and to everyone stamped with this step.
func command(cmd: Array) -> void:
	sim.apply(cmd)
	GameState._world(&"factory_cmd", [sim.step, cmd])


func _ensure_seed() -> void:
	if sim.rng == 0:
		command(["s", randi_range(1, 0x7fffffff)])  # rolled here alone


## Host: can `k` go up here, for this player. The ghost asks the same on any peer.
func can_build(k: int, x: int, z: int, d: int) -> bool:
	if not sim.can_place(k, x, z, d):
		return false
	if sim.data.kinds[k].tur_i == FactoryData.Tur.DAG:
		return _dig_spot(_centre(k, x, z, d), d, sim.data.kinds[k].reach) != Vector3.INF
	return true


func request_place(id: String, x: int, z: int, d: int, peer: int) -> bool:
	if not sim.data.kind_index.has(id):
		return false
	var k: int = sim.data.kind_index[id]
	if not can_build(k, x, z, d) or not _in_reach(peer, x, z):
		return false
	_ensure_seed()
	command(["p", k, x, z, d])
	return true


func request_remove(x: int, z: int, peer: int) -> bool:
	var s := sim.slot_at(x, z)
	if s < 0 or not _in_reach(peer, x, z):
		return false
	command(["x", s])
	return true


func _in_reach(peer: int, x: int, z: int) -> bool:
	if peer == 0 or peer == GameState.local_peer():
		return true
	var p = GameState.player(peer)
	return not p.has_pose or Vector2(p.pos.x - x, p.pos.z - z).length() <= BUILD_REACH


## Host: each extractor that is running low gets its next batch out of the heap, off the mountain's
## own count and dug at the spot it reaches. Nothing there, or the count dry: it runs out and stands.
func _dig_for_extractors() -> void:
	for s in sim.ticking:
		var row: Dictionary = sim.data.kinds[sim.kind[s]]
		if row.tur_i != FactoryData.Tur.DAG or sim.budget[s] * 2 >= row.batch:
			continue
		var x := sim.cell_x(sim.cell[s])
		var z := sim.cell_z(sim.cell[s])
		var at := _dig_spot(_centre(sim.kind[s], x, z, sim.dir[s]), sim.dir[s], row.reach)
		if at == Vector3.INF:
			continue
		var each: int = row.get("dag_sayi", 1)
		var taken: int = GameState.request_take_bullets(row.batch * each, at)
		if taken >= each:
			dug += taken
			granted += taken / each
			command(["o", s, taken / each])


func _centre(k: int, x: int, z: int, d: int) -> Vector3:
	var f := sim.footprint(k, d)
	return Vector3(x + f.x * 0.5, 0.0, z + f.y * 0.5)


## Where an extractor at `from` facing `d` bites: the first heap it meets going backwards, Vector3.INF
## when there is none in reach. It stands on the ground, so what it reaches moves as the heap goes.
func _dig_spot(from: Vector3, d: int, reach: int) -> Vector3:
	var heap := get_tree().get_first_node_in_group("bullet_pile") as Pile
	if heap == null:
		return Vector3.INF
	var back := Vector3(-FactorySim.DIR_X[d], 0.0, -FactorySim.DIR_Z[d])
	for i in range(2, reach * 2 + 1):
		var p := from + back * (i * 0.5)
		if heap.surface_y(p) - heap.global_position.y > 0.3:
			return p
	return Vector3.INF


## Host: a part of the stock spent by something other than a build (later: a turret's rounds, the
## workbench). False, and nothing taken, if the kasa is short.
func take_stock(cost: Dictionary) -> bool:
	if Net.is_client or not sim.can_afford(cost):
		return false
	for i: int in cost:
		command(["k", i, -cost[i]])
	return true


# --- Client ---

func _run_client(delta: float) -> void:
	var lag := _limit - sim.step
	if lag <= 0:
		return
	# Runs at the host's pace; a little slower close to the clock, faster far behind it.
	_accum += delta * clampf(1.0 + (lag - WANT_LAG) * 0.1, 0.8, 4.0)
	while _accum >= DT and sim.step < _limit:
		_accum -= DT
		_apply_stamped()
		_timed_step()
		_check_hash()
	if sim.step >= _limit:
		_accum = minf(_accum, DT)


func _apply_stamped() -> void:
	var n := 0
	while n < _pending.size() and _pending[n][0] <= sim.step:
		sim.apply(_pending[n][1])
		n += 1
	if n > 0:
		_pending = _pending.slice(n)


func _check_hash() -> void:
	if not _expect.has(sim.step):
		return
	var want: int = _expect[sim.step]
	_expect.erase(sim.step)
	if want != sim.state_hash():
		desyncs += 1
		push_warning("factory: out of step at %d, asking for the whole state" % sim.step)
		if not _asked_resync:
			_asked_resync = true
			GameState.request_factory_resync()


func _on_cmd(stamp: int, cmd: Array) -> void:
	if not Net.is_client:
		return
	# Nothing standing: no clock comes (host's _run_host) and nothing would change by running.
	if sim.count == 0 and _pending.is_empty() and stamp > sim.step:
		sim.step = stamp
		_limit = stamp
	_pending.append([stamp, cmd])


func _on_clock(s: int, check: int) -> void:
	if not Net.is_client:
		return
	_limit = maxi(_limit, s)
	if check != 0:
		_expect[s] = check
		if s == sim.step:  # got here first; what's stamped s hasn't gone in yet
			_check_hash()


func _on_snapshot(state: Dictionary) -> void:
	if not Net.is_client:
		return
	sim.from_save(state)
	_limit = sim.step
	_pending.clear()
	_expect.clear()
	_accum = 0.0
	_asked_resync = false


## Host: may `peer` have the whole state again now.
func resync_allowed(peer: int) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_resync_at.get(peer, -RESYNC_WAIT)) < RESYNC_WAIT:
		return false
	_resync_at[peer] = now
	return true
