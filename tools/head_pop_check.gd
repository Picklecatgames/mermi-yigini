extends SceneTree
## Headless check for heads blown off (scripts/waves.gd pop_chance(), zombie_gibs.gd head()):
##   Godot.exe --headless --path . -s res://tools/head_pop_check.gd --quit-after 100000
## The odds: on a usual mix of guns, waves and distances, one head shot kill in 6 to 10 blows the
## head off; a Deagle round that takes most of a zombie's life from close by far more often than an
## UZI from across the hall; a shooter who just blew one off less often for a while. The host's own
## path: head shot kills in a real wave send die cues with a gib, a roll and the round's way, the
## rolls all different. The pieces: small next to the head, the same from the same roll on every
## peer, and six rolls six different bursts.

var WAVES: GDScript  # (loaded once the autoloads are in: it names GameState)
const GIBS := preload("res://scripts/zombie_gibs.gd")
## A usual mix: gun -> share of the head shot kills
const MIX := {"pistol": 0.15, "deagle": 0.25, "uzi": 0.2, "scorpion": 0.2, "minigun": 0.2}
const KILLS := 20000
const KILL_GAP := [1.0, 4.0]  # s between one player's head shot kills
const NEAR := [2.0, 14.0]  # m from the shooter
const WAVES_SEEN := 10

var _fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	WAVES = load("res://scripts/waves.gd")
	_odds()
	await _host()
	await _pieces()
	print("head_pop_check: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## The formula on its own over many kills, one shooter, with the memory of their last pops.
func _odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var now := 0.0
	var pops: Array[float] = []
	var popped := 0
	var by_gun := {}
	for i in KILLS:
		now += rng.randf_range(KILL_GAP[0], KILL_GAP[1])
		var gun := _pick(rng)
		var hp: float = ceilf(WAVES.STATS[&"walker"][1] * (1.0 + WAVES.HP_GROW * rng.randi_range(0, WAVES_SEEN - 1)))
		var share: float = WAVES.DAMAGE[gun] * WAVES.HEAD / hp  # what the killing head shot takes by itself
		pops = pops.filter(func(t: float) -> bool: return now - t < WAVES.POP_MEMORY)
		var p: float = WAVES.pop_chance(gun, share, rng.randf_range(NEAR[0], NEAR[1]), pops.size())
		var hit: bool = rng.randf() < p
		if hit:
			pops.append(now)
			popped += 1
		var g: Array = by_gun.get_or_add(gun, [0, 0])
		g[0] += 1
		g[1] += 1 if hit else 0
	var one_in := float(KILLS) / maxi(popped, 1)
	_expect(one_in >= 6.0 and one_in <= 10.0, "one head shot kill in %.1f blows the head off (6-10)" % one_in)
	for gun in by_gun:
		print("  %-9s one in %.1f" % [gun, float(by_gun[gun][0]) / maxi(by_gun[gun][1], 1)])
	var deagle: float = WAVES.pop_chance("deagle", 0.85, 3.0, 0)
	var uzi: float = WAVES.pop_chance("uzi", 0.3, 15.0, 0)
	_expect(deagle > uzi * 4.0, "a close Deagle one-shot (%.2f) beats a far UZI (%.2f) by 4x or more" % [deagle, uzi])
	_expect(WAVES.pop_chance("deagle", 0.85, 3.0, 1) < deagle * 0.5, "a shooter who just blew one off waits for the next")
	_expect(WAVES.pop_chance("deagle", 0.85, 1.0, 0) <= WAVES.POP_MAX, "never past POP_MAX")


## A real wave alone: every zombie put down by a head shot through the host's own _hurt().
func _host() -> void:
	var gs: Node = root.get_node("GameState")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var waves: Node = main.get_node("Waves")
	var cues: Array = []
	gs.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"die":
			cues.append(cue))
	for i in 3:
		await physics_frame
	var me: Node3D = main.get_node("Player")
	me.global_position = gs.LEVER_POS + Vector3(0, 0, 0.6)
	me.reset_physics_interpolation()
	await create_timer(0.3).timeout  # our pose catches up
	gs.request_pull_lever()
	while not waves._queue.is_empty():  # the whole wave out of the wood's edge, hit points and all
		waves._spawn_next()
	var dir := Vector3(1, 0, 0.1).normalized()
	for z: Dictionary in waves._zombies.values().duplicate():
		if z.dead or not waves._hp.has(z.id):
			continue
		z.count += 1
		waves._hurt(z, 9999.0, gs.local_peer(), true, "deagle", dir.rotated(Vector3.UP, z.id * 0.1))
	await process_frame
	_expect(cues.size() >= 6, "head shot kills sent die cues (%d)" % cues.size())
	var shaped := cues.all(func(c: Array) -> bool: return c.size() >= 10 and c[7] in [&"", &"head", &"body"] and c[9] is Vector3)
	_expect(shaped, "each die cue carries its gib, roll and the round's way")
	var rolls := {}
	for c: Array in cues:
		rolls[c[8]] = true
	_expect(rolls.size() == cues.size(), "every death its own roll (%d of %d)" % [rolls.size(), cues.size()])
	var heads := cues.filter(func(c: Array) -> bool: return c[7] == &"head").size()
	print("  %d of %d head shot kills blew the head off (a close Deagle, one after another)" % [heads, cues.size()])
	_expect(heads < cues.size(), "not every head shot kill blows the head off")
	main.queue_free()
	await process_frame


## zombie_gibs.gd head(): its bulk, the same roll twice alike, six rolls each its own.
func _pieces() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var bulk := 0.0
	var once := _burst(world, 11)
	for m: MeshInstance3D in once:
		var box := m.mesh.get_aabb()
		bulk += box.size.x * box.size.y * box.size.z * m.scale.x * m.scale.y * m.scale.z * 0.5
	var head := PI / 6.0 * pow(GIBS.HEAD_SIZE, 3)
	_expect(bulk < head, "a skull's pieces (%d) together %.0f%% of the head" % [once.size(), bulk / head * 100.0])
	var big: float = once.reduce(func(a: float, m: MeshInstance3D) -> float: return maxf(a, m.get_aabb().size.length() * m.scale.x), 0.0)
	_expect(big < GIBS.HEAD_SIZE * 0.5, "the biggest under half the head (%.3f m)" % big)
	var again := _burst(world, 11)
	var alike := once.size() == again.size()
	for i in mini(once.size(), again.size()):
		alike = alike and once[i].global_position.is_equal_approx(again[i].global_position) and once[i].scale.is_equal_approx(again[i].scale)
	_expect(alike, "the same roll comes apart the same (every peer)")
	var looks := {}
	for seed in [1, 2, 3, 4, 5, 6]:
		var b := _burst(world, seed)
		var sig := "%d" % b.size()
		for m: MeshInstance3D in b.slice(0, 3):
			sig += ":%.2f,%.2f" % [m.global_position.x, m.scale.x * 100.0]
		looks[sig] = true
	_expect(looks.size() == 6, "six rolls, six different bursts")
	world.queue_free()


func _burst(world: Node3D, seed: int) -> Array:
	var before := world.get_child_count()
	GIBS.head(world, Vector3(0, 1.7, 0), Vector3(0, 0, -1), 0.0, 1.0, seed, 1.0)
	var g: Node = world.get_child(before)
	for i in 3:  # let them fly a little
		g._process(0.02)
	return g.get_children()


func _pick(rng: RandomNumberGenerator) -> String:
	var x := rng.randf()
	for gun: String in MIX:
		x -= MIX[gun]
		if x <= 0.0:
			return gun
	return "deagle"


func _expect(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1
