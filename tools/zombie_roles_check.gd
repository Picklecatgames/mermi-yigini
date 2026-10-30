extends SceneTree
## Headless check of the zombies' roles (scripts/waves.gd STATS, MIX, DAMAGE): their own hit points,
## limbs that cripple and don't kill, the bar over a hurt one, the screamer's cry sending the crowd
## running, the bloater's burst, the dog's zigzag, the waves getting harder, and every speed a kind
## can walk at kept within what its clips stretch to (no feet sliding over the floor).
##   Godot.exe --headless --path . -s res://tools/zombie_roles_check.gd --quit-after 100000

const BODY := preload("res://scripts/zombie_body.gd")
const DEAGLE := 2  # GameState.GUNS
const PISTOL := 1

var gs: Node
var main: Node
var waves: Node
var _fails := 0
var _anchor: Dictionary


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	waves = main.get_node("Waves")
	for i in 3:
		await physics_frame
	_numbers()
	await _strides()
	gs.request_toggle_infinite_ammo()  # test mode: every gun opens
	gs.cue_wave([&"phase", 1, waves.Phase.FIGHT, 99, waves.FENCE_HP])
	_anchor = _spawn(&"walker", Vector3(42, 0, 0))  # never shot: the wave is not cleared under us
	_anchor.path = []
	await _limbs()
	await _screamer()
	await _bloater()
	await _dog()
	print("zombie_roles_check %s" % ("OK" if _fails == 0 else "FAILED (%d)" % _fails))
	quit(1 if _fails else 0)


## The table: every kind has its numbers, a Deagle needs a few rounds for a walker and many for the
## big ones, and each wave is bigger, tougher and more mixed than the one before.
func _numbers() -> void:
	for kind in BODY.KINDS:
		_expect(waves.STATS.has(kind), "%s has no STATS" % kind)
	var deagle: float = waves.DAMAGE["deagle"]
	var pistol: float = waves.DAMAGE["pistol"]
	var walker: int = waves.hp_of(&"walker", 1)
	_expect(ceili(walker / deagle) >= 3 and ceili(walker / (deagle * waves.HEAD)) >= 2,
			"a walker takes %d Deagle rounds in the body, %d in the head" % [ceili(walker / deagle), ceili(walker / (deagle * waves.HEAD))])
	_expect(ceili(walker / pistol) >= 4, "a walker takes %d pistol rounds" % ceili(walker / pistol))
	for big in [&"brute", &"blob", &"bloater"]:
		_expect(waves.hp_of(big, 1) > walker, "%s tougher than a walker" % big)
	_expect(waves.hp_of(&"brute", 1) / deagle >= 15, "a brute takes %d Deagle rounds" % ceili(waves.hp_of(&"brute", 1) / deagle))
	for fast in [&"runner", &"dog"]:
		_expect(waves.STATS[fast][0] > waves.STATS[&"walker"][0] * 2 and waves.STATS[fast][1] < walker, "%s fast and frail" % fast)
	_expect(waves.STATS[&"brute"][2] > waves.STATS[&"walker"][2] * 3, "a brute claws the railing hard")
	var rows := []
	var last := {}
	for w in [1, 2, 3, 4, 6, 10, 20]:
		var plan: Array = waves._plan(w)
		var mix := {}
		for k: StringName in plan:
			mix[k] = mix.get(k, 0) + 1
		rows.append("wave %d: %d %s" % [w, plan.size(), mix])
		if not last.is_empty():
			_expect(plan.size() > last.size and waves.hp_of(&"walker", w) > waves.hp_of(&"walker", last.w), "wave %d bigger and tougher" % w)
			_expect(mix.size() >= last.kinds, "wave %d no less mixed" % w)
		last = {"size": plan.size(), "w": w, "kinds": mix.size()}
		_expect(plan.count(&"screamer") == waves.screamers(w), "wave %d: %d screamers" % [w, waves.screamers(w)])
		for k: StringName in waves.MIX:
			_expect(w >= waves.MIX[k][0] or not plan.has(k), "wave %d: no %s before wave %d" % [w, k, waves.MIX[k][0]])
	_expect(waves._plan(10).has(&"bloater") and waves._plan(10).has(&"runner"), "wave 10 has bloaters and runners")
	print("  ", "\n  ".join(rows))


## Every model of every kind at the slowest and quickest it can go (its roll, the waves' growth, a
## screamer's rush, a torn leg's crawl): the stride is stretched to it inside what move() allows.
func _strides() -> void:
	var lo: float = waves.SPEED_ROLL[0]
	var hi: float = waves.SPEED_ROLL[1] * waves.SPEED_MAX * waves.RUSH
	for kind: StringName in BODY.KINDS:
		for m: StringName in BODY.KINDS[kind].models:
			var b: Node3D = BODY.new()
			b.setup(kind, 7)
			b.model = m
			root.add_child(b)
			var speeds := [waves.STATS[kind][0] * lo, waves.STATS[kind][0] * hi]
			for v: float in speeds:
				b.move(v)
				var ap: AnimationPlayer = b._ap
				var natural: float = b._lib.get_animation(ap.current_animation).get_meta("speed", 0.0) * b._hip
				if natural > 0.05:
					var r := v / natural
					_expect(r >= 0.6 and r <= 1.8, "%s %s at %.2f m/s: its %s clip is %.2f m/s (×%.2f)" % [kind, m, v, ap.current_animation, natural, r])
			if b.crawling or kind in [&"brute", &"blob", &"dog"] or BODY.CREATURES.has(m):
				b.queue_free()
				continue
			b._go_down(false)  # a leg gone: the crawl at LEGLESS of it
			var legless: float = waves.STATS[kind][0] * waves.LEGLESS.get(kind, 0.6)
			for v: float in [legless * lo, legless * hi]:
				b.move(v)
				var natural: float = b._lib.get_animation(b._ap.current_animation).get_meta("speed", 0.0) * b._hip
				if natural > 0.05:
					_expect(v / natural >= 0.6 and v / natural <= 1.8, "%s %s crawling at %.2f m/s: clip %.2f m/s" % [kind, m, v, natural])
			b.queue_free()
	await process_frame


## A zombie of `kind` from the host's queue, standing at `at`, walking to the railing.
func _spawn(kind: StringName, at: Vector3) -> Dictionary:
	waves._queue.assign([kind])
	var ph: int = waves.phase
	waves.phase = waves.Phase.READY  # not let out from the pen: we set it walking here
	waves._spawn_next()
	waves.phase = ph
	var z: Dictionary = waves._zombies[waves._next_id - 1]
	(z.node as Node3D).global_position = at
	z.rail = Vector3(waves.RAIL_X, 0.0, at.z)
	(z.node as Node3D).look_at(at + Vector3.LEFT, Vector3.UP)
	z.speed = waves.STATS[kind][0]
	z.path = [z.rail]
	z.released = true
	z.moving = true
	z.body.move(z.speed)
	return z


## A paying round from the Deagle at `at`, coming in along `dir`.
func _shoot(z: Dictionary, at: Vector3, dir: Vector3, weak := false) -> void:
	waves._on_shot(gs.local_peer(), at, -dir, dir.normalized(), z.node, 1, weak, 1)
	await process_frame


func _limbs() -> void:
	gs.request_select_gun(DEAGLE)
	var z := _spawn(&"walker", Vector3(22, 0, -6))
	z.path = []  # stands still, so the bones stay where we aim
	z.body.idle()
	await create_timer(0.3).timeout
	var full: int = waves._hp_full[z.id]
	var torso: Vector3 = z.body._bone_at("Spine1")
	var cut := [0]
	var watch := func(cue: Array) -> void:
		if cue[0] == &"limb" and cue[1] == z.id:
			cut[0] += 1
	gs.wave_cue.connect(watch)
	for i in 6:
		if z.body.cuts.size() > 0:
			break
		var arm: Vector3 = z.body._bone_at("LeftForeArm")
		var dir := Vector3(torso.x - arm.x, 0.0, torso.z - arm.z)
		await _shoot(z, arm - dir.normalized() * 0.05, dir)
	_expect(cut[0] == 1 and not z.dead and waves._hp.get(z.id, 0) > 0, "an arm off and the walker still up (%s, %s of %d left)" % [z.body.cuts, waves._hp.get(z.id), full])
	var bar: Node3D = z.bar
	_expect(bar.visible and bar.left < 1.0 and bar.left > 0.0, "its bar shows what is left (%.2f)" % bar.left)
	for i in 6:
		if z.body.crawling:
			break
		var knee: Vector3 = z.body._bone_at("RightLeg")
		var hip: Vector3 = z.body._bone_at("Hips")
		var dir := Vector3(hip.x - knee.x, 0.0, hip.z - knee.z)
		await _shoot(z, knee - dir.normalized() * 0.05, dir)
	_expect(z.body.crawling and not z.dead, "a leg off: down crawling, still alive (%s left)" % waves._hp.get(z.id))
	gs.wave_cue.disconnect(watch)
	var shots := 0
	while not z.dead and shots < 20:
		await _shoot(z, z.body._bone_at("Head"), Vector3(-1, 0, 0), true)
		shots += 1
	_expect(z.dead, "head shots finish it (%d)" % shots)
	_expect(not bar.visible, "the bar goes with it")
	# A fresh one: the Deagle in the head, twice.
	var w := _spawn(&"walker", Vector3(22, 0, 4))
	w.path = []
	await _shoot(w, w.body._bone_at("Head"), Vector3(-1, 0, 0), true)
	_expect(not w.dead, "one Deagle head shot does not drop a walker")
	await _shoot(w, w.body._bone_at("Head"), Vector3(-1, 0, 0), true)
	_expect(w.dead, "two do")
	var b := _spawn(&"brute", Vector3(22, 0, 8))
	b.path = []
	for i in 8:
		await _shoot(b, b.body._bone_at("Head"), Vector3(-1, 0, 0), true)
	_expect(not b.dead, "eight Deagle head shots don't drop a brute (%s left)" % waves._hp.get(b.id))
	_clear()


func _screamer() -> void:
	var s := _spawn(&"screamer", Vector3(24, 0, 0))
	var near := _spawn(&"walker", Vector3(24, 0, 3))
	var far := _spawn(&"walker", Vector3(24, 0, -16))
	var cries := []
	var watch := func(cue: Array) -> void:
		if cue[0] == &"scream":
			cries.append(cue)
	gs.wave_cue.connect(watch)
	var slow: float = near.body._ap.speed_scale
	await _wait(func() -> bool: return not cries.is_empty(), "the screamer to cry", 8.0)
	gs.wave_cue.disconnect(watch)
	_expect(cries.size() == 1 and cries[0][1] == s.id and near.id in cries[0][2] and not far.id in cries[0][2], "it cried, for the one near it only (%s)" % [cries])
	_expect(near.rush > 0.0 and far.rush <= 0.0 and waves._pace(near) > near.speed * 1.4, "the near one runs")
	_expect(near.body._ap.speed_scale > slow * 1.3, "its stride quickens with it (%.2f -> %.2f)" % [slow, near.body._ap.speed_scale])
	_expect(s.hold > 0.0, "the screamer stands while it cries")
	var x0: float = (near.node as Node3D).global_position.x
	var t := 1.0
	await create_timer(t).timeout
	var went := x0 - (near.node as Node3D).global_position.x
	_expect(went > near.speed * waves.RUSH * t * 0.8, "running: %.2f m in %.1f s" % [went, t])
	_clear()


func _bloater() -> void:
	var fence_hits := []
	var watch := func(kind: StringName, dmg: int, _at: Vector3) -> void:
		fence_hits.append([kind, dmg])
	waves.fence_hit.connect(watch)
	var fence: int = waves.fence
	var bl := _spawn(&"bloater", Vector3(waves.RAIL_X, 0, 0))
	bl.path = []
	var w := _spawn(&"walker", Vector3(waves.RAIL_X + 1.5, 0, 1.0))
	w.path = []
	var away := _spawn(&"walker", Vector3(waves.RAIL_X + 1.0, 0, 10.0))
	away.path = []
	waves._hp[w.id] = 50
	var blasts := [0]
	var cue_watch := func(cue: Array) -> void:
		if cue[0] == &"blast":
			blasts[0] += 1
	gs.wave_cue.connect(cue_watch)
	var shots := 0
	while not bl.dead and shots < 40:
		await _shoot(bl, (bl.node as Node3D).global_position + Vector3.UP * 1.1, Vector3(-1, 0, 0))
		shots += 1
	await process_frame
	await process_frame
	gs.wave_cue.disconnect(cue_watch)
	waves.fence_hit.disconnect(watch)
	_expect(bl.dead and blasts[0] == 1, "the bloater burst (%d rounds)" % shots)
	_expect(w.dead and not away.dead, "it took the one beside it, not the one far off")
	_expect(waves.fence == fence - waves.BLAST_FENCE and [&"bloater", waves.BLAST_FENCE] in fence_hits,
			"the railing took %d (%d -> %d) and fence_hit said so" % [waves.BLAST_FENCE, fence, waves.fence])
	_clear()


func _dog() -> void:
	var d := _spawn(&"dog", Vector3(28, 0, 0))
	d.rail = Vector3(waves.RAIL_X, 0, 0)
	d.path = [d.rail]
	var most := 0.0
	var t0 := Time.get_ticks_msec()
	while (d.node as Node3D).global_position.x > waves.RAIL_X + waves.ZIG_STOP and Time.get_ticks_msec() - t0 < 6000:
		most = maxf(most, absf((d.node as Node3D).global_position.z))
		await process_frame
	_expect(most > 0.4, "the dog zigzags (%.2f m off its line)" % most)
	await _wait(func() -> bool: return d.path.is_empty(), "the dog at the railing", 4.0)
	_expect(absf((d.node as Node3D).global_position.z) < 0.3, "and still gets to its spot")
	_clear()


func _clear() -> void:
	for id: int in waves._zombies.keys():
		if not waves._zombies[id].dead and id != _anchor.id:
			waves._kill(id, &"")
	waves.fence = waves.FENCE_HP


func _wait(cond: Callable, what: String, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			_expect(false, "waited for " + what)
			return false
		await process_frame
	return true


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok: ", what)
	else:
		_fails += 1
		printerr("zombie_roles_check FAIL: ", what)
