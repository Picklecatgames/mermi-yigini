extends SceneTree
## Headless check of the zombies' roles (scripts/waves.gd STATS, TYPES, MIX, DAMAGE): their own hit points,
## limbs that cripple and don't kill, the bar over a hurt one, the screamer's cry sending the crowd
## running, the bloater's burst, the dog's zigzag, the waves getting harder, and every speed a kind
## can walk at kept within what its clips stretch to (no feet sliding over the floor); the types
## coming one by one (wave 1 a few of one type in one look) and their traits (armor, mask, regen,
## rage, elites, the leaper's leap, the spiker's roar).
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
	await _arrival()
	gs.request_toggle_infinite_ammo()  # test mode: every gun opens
	gs.cue_wave([&"phase", 1, waves.Phase.FIGHT, 99])
	_anchor = _spawn(&"walker", Vector3(42, 0, 0))  # never shot: the wave is not cleared under us
	_anchor.path = []
	await _limbs()
	await _screamer()
	await _bloater()
	await _dog()
	await _no_slide()
	await _traits()
	await _leaper()
	await _spiker()
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
		_expect(waves.STATS[fast][0] > waves.STATS[&"walker"][0] * 1.2 and waves.STATS[fast][1] < walker, "%s fast and frail" % fast)
	_expect(waves.STATS[&"dog"][0] > waves.STATS[&"runner"][0], "the dog the quickest")
	for kind: StringName in waves.STATS:
		_expect(kind == &"blob" or waves.STATS[kind][0] >= 2.0, "%s runs (%.1f m/s)" % [kind, waves.STATS[kind][0]])
	_expect(waves.STATS[&"brute"][2] > waves.STATS[&"walker"][2] * 3, "a brute claws the railing hard")
	var paces := {}
	var bites := {}
	for t: StringName in waves.TYPES:
		paces[snappedf(waves.STATS[waves.TYPES[t].kind][0] * waves.TYPES[t].speed, 0.01)] = true
		bites[waves.bite_of(t, 1)] = true
	_expect(paces.size() >= 7 and bites.size() >= 3, "the types differ: %d speeds, %d claws (%s)" % [paces.size(), bites.size(), bites.keys()])
	_expect(waves.bite_of(&"walker", 1) == 1 and waves.bite_of(&"walker", 20) == 2 and waves.bite_of(&"brute", 20) > waves.bite_of(&"brute", 10),
			"claws grow with the waves (walker %d → %d, brute %d → %d → %d)" % [waves.bite_of(&"walker", 1), waves.bite_of(&"walker", 20),
			waves.bite_of(&"brute", 10), waves.bite_of(&"brute", 20), waves.bite_of(&"brute", 30)])
	var rows := []
	var last := {}
	var first: Array = waves._plan(1)
	_expect(first.size() <= 8 and first.all(func(t: StringName) -> bool: return t == &"walker") and waves.looks(&"walker", 1).size() == 1,
			"wave 1: %d of one type in one look (%s)" % [first.size(), waves.looks(&"walker", 1)])
	for t: StringName in waves.TYPES:
		var from: int = waves.TYPES[t].from
		_expect(waves._plan(from).has(t), "%s shows in its first wave, %d" % [t, from])
		_expect(from == 1 or not waves._plan(from - 1).has(t), "no %s before wave %d" % [t, from])
		_expect(waves.STATS.has(waves.TYPES[t].kind), "%s's kind %s has STATS" % [t, waves.TYPES[t].kind])
		for l: Array in waves.TYPES[t].looks:
			_expect(BODY.MODELS.has(l[0]) or BODY.CREATURES.has(l[0]), "%s's look %s is a model" % [t, l[0]])
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
		for k: StringName in waves.TYPES:
			_expect(w >= waves.TYPES[k].from or not plan.has(k), "wave %d: no %s before wave %d" % [w, k, waves.TYPES[k].from])
	_expect(waves._plan(10).has(&"bloater") and waves._plan(10).has(&"runner"), "wave 10 has bloaters and runners")
	print("  ", "\n  ".join(rows))


## Every model of every kind at the slowest and quickest it can go (its roll, the waves' growth, a
## screamer's rush, a torn leg's crawl): the stride is stretched to it inside what move() allows.
func _strides() -> void:
	var lo: float = waves.SPEED_ROLL[0]
	var hi: float = waves.SPEED_ROLL[1] * waves.SPEED_MAX
	for kind: StringName in BODY.KINDS:
		for m: StringName in BODY.KINDS[kind].models:
			var b: Node3D = BODY.new()
			b.setup(kind, 7)
			b.model = m
			root.add_child(b)
			var speeds := [waves.STATS[kind][0] * lo, waves.STATS[kind][0] * hi]
			if not kind in waves.NO_RUSH:  # and driven by a screamer
				for v: float in speeds.duplicate():
					speeds.append(waves._pace({"rush": 1.0, "speed": v, "kind": kind}))
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
			var legless: float = waves.STATS[kind][0] * waves.LEGLESS.get(kind, waves.LEGLESS_ELSE)
			for v: float in [legless * lo, legless * hi]:
				b.move(v)
				var natural: float = b._lib.get_animation(b._ap.current_animation).get_meta("speed", 0.0) * b._hip
				if natural > 0.05:
					_expect(v / natural >= 0.6 and v / natural <= 1.8, "%s %s crawling at %.2f m/s: clip %.2f m/s" % [kind, m, v, natural])
			b.queue_free()
	for t: StringName in waves.TYPES:  # the types' own looks, at the elite's and the rager's pace too
		var kind: StringName = waves.TYPES[t].kind
		for l: Array in waves.TYPES[t].looks:
			if BODY.CREATURES.has(l[0]):
				continue
			var b: Node3D = BODY.new()
			b.setup(kind, 7)
			b.model = l[0]
			root.add_child(b)
			var top: float = hi * (waves.ELITE_SPEED if waves.elite_chance(t, 99) > 0.0 else 1.0)
			if waves.TYPES[t].trait == &"rage":
				top *= waves.RAGE
			var own: float = waves.STATS[kind][0] * waves.TYPES[t].speed
			var speeds := [own * lo, own * top]
			if not kind in waves.NO_RUSH:
				speeds.append(own * top * waves.RUSH)
			for v: float in speeds:
				b.move(v)
				var natural: float = b._lib.get_animation(b._ap.current_animation).get_meta("speed", 0.0) * b._hip
				if natural > 0.05:
					_expect(v / natural >= 0.6 and v / natural <= 1.8, "%s %s at %.2f m/s: clip %.2f m/s (×%.2f)" % [t, l[0], v, natural, v / natural])
			b.queue_free()
	await process_frame


## A zombie of `kind` (or a type) from the host's queue, standing at `at`, walking to the railing.
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
	z.speed = waves.STATS[z.kind][0]
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
	while BODY.CREATURES.has(z.body.model):  # limbs come off Mixamo bodies only
		waves._kill(z.id, &"")
		z = _spawn(&"walker", Vector3(22, 0, -6))
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
	s.cry = 0.5  # its first cry a moment from now
	var cries := []
	var watch := func(cue: Array) -> void:
		if cue[0] == &"scream":
			cries.append(cue)
	gs.wave_cue.connect(watch)
	await process_frame
	var slow: float = near.body._ap.speed_scale / waves._surge(near)  # its pace's own rise and fall left out
	await _wait(func() -> bool: return not cries.is_empty(), "the screamer to cry", 8.0)
	await process_frame
	gs.wave_cue.disconnect(watch)
	_expect(cries.size() == 1 and cries[0][1] == s.id and near.id in cries[0][2] and not far.id in cries[0][2], "it cried, for the one near it only (%s)" % [cries])
	_expect(near.rush > 0.0 and far.rush <= 0.0 and waves._pace(near) > near.speed * 1.1, "the near one runs faster")
	_expect(near.body._ap.speed_scale / waves._surge(near) > slow * 1.1, "its stride quickens with it (%.2f -> %.2f, %s, rush %.1f, busy %s)" % [slow, near.body._ap.speed_scale, near.body._ap.current_animation, near.rush, near.body.busy()])
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


## Wave 1 from the lever: the first of them is at the railing within ARRIVE s.
const ARRIVE := 15.0


func _arrival() -> void:
	var t0 := Time.get_ticks_msec()
	waves._on_lever(gs.local_peer())
	var first := [0.0]
	await _wait(func() -> bool:
		for z: Dictionary in waves._zombies.values():
			if z.released and (z.node as Node3D).global_position.x < waves.RAIL_X + 0.3:
				first[0] = (Time.get_ticks_msec() - t0) / 1000.0
				return true
		return false, "the first at the railing", ARRIVE + 10.0)
	_expect(first[0] > 0.0 and first[0] <= ARRIVE, "wave 1's first at the railing %.1f s after the lever" % first[0])
	gs.cue_wave([&"phase", 1, waves.Phase.READY, 0])  # the lost-wave reset: everyone gone
	await process_frame


## The types' traits, each against a plain walker of the same wave: armor takes body rounds, the
## mask head shots, regen heals when left alone, the rager speeds up under half, an elite has twice
## the life and a longer bar.
func _traits() -> void:
	gs.request_select_gun(DEAGLE)
	var was: int = waves.wave
	waves.wave = waves.TYPES[&"rager"].from  # every trait open, the walkers still Mixamo bodies
	var plain := _plain(&"walker", Vector3(22, 0, -8))
	var cop := _plain(&"armored", Vector3(22, 0, -4))
	var mask := _plain(&"masked", Vector3(22, 0, 0))
	var flesh := _plain(&"regen", Vector3(22, 0, 4))
	var war := _plain(&"rager", Vector3(22, 0, 8))
	for z: Dictionary in [plain, cop, mask, flesh, war]:
		z.path = []
		z.body.idle()
	_expect(cop.body.model == &"copzombie" and mask.body.model == &"hazmat" and flesh.body.model == &"fleshzombie" and war.body.model == &"warzombie",
			"each type in its own look (%s %s %s %s)" % [cop.body.model, mask.body.model, flesh.body.model, war.body.model])
	await create_timer(0.3).timeout
	var left := func(z: Dictionary) -> float: return float(waves._hp[z.id]) / waves._hp_full[z.id]
	for z: Dictionary in [plain, cop]:
		await _shoot(z, z.body._bone_at("Spine1"), Vector3(-1, 0, 0))
	_expect(1.0 - left.call(cop) < (1.0 - left.call(plain)) * 0.6, "armor: a body round takes %.2f of the cop, %.2f of a walker" % [1.0 - left.call(cop), 1.0 - left.call(plain)])
	var p2 := _plain(&"walker", Vector3(22, 0, -12))
	p2.path = []
	await _shoot(p2, p2.body._bone_at("Head"), Vector3(-1, 0, 0), true)
	await _shoot(mask, mask.body._bone_at("Head"), Vector3(-1, 0, 0), true)
	_expect(not mask.dead and 1.0 - left.call(mask) < (1.0 - left.call(p2)) * 0.6, "mask: a head shot takes %.2f of it, %.2f of a walker" % [1.0 - left.call(mask), 1.0 - left.call(p2)])
	await _shoot(flesh, flesh.body._bone_at("Spine1"), Vector3(-1, 0, 0))
	var hurt: float = left.call(flesh)
	await create_timer(waves.REGEN_WAIT + 1.0).timeout
	_expect(left.call(flesh) > hurt + 0.03, "regen: %.2f back to %.2f, left alone" % [hurt, left.call(flesh)])
	var pace: float = war.speed
	var shots := 0
	while not war.raged and not war.dead and shots < 10:
		await _shoot(war, war.body._bone_at("Head"), Vector3(-1, 0, 0), true)
		shots += 1
	await process_frame
	_expect(war.raged and not war.dead and war.speed > pace * 1.2 and war.bite > waves.STATS[&"walker"][2], "rage: under half it goes %.1f → %.1f m/s, claws %d" % [pace, war.speed, war.bite])
	_expect(waves.elite_chance(&"walker", waves.ELITE_FROM - 1) == 0.0 and waves.elite_chance(&"walker", waves.ELITE_FROM) > 0.0 and waves.elite_chance(&"brute", 30) == 0.0,
			"elites from wave %d, never a brute" % waves.ELITE_FROM)
	_expect(waves.hp_of(&"walker", 20, true) >= waves.hp_of(&"walker", 20) * 1.9, "an elite has twice the life")
	var bar_w := func(full: float) -> float:
		var bar: Node3D = waves.BAR.new()
		bar.setup(full, false)
		var width: float = bar._width
		bar.free()
		return width
	_expect(bar_w.call(waves.hp_of(&"brute", 10)) > bar_w.call(waves.hp_of(&"walker", 10)) * 1.4 and bar_w.call(waves.hp_of(&"walker", 20)) > bar_w.call(waves.hp_of(&"walker", 1)) * 1.2,
			"the bar grows with the life (walker 1 %.2f, walker 20 %.2f, brute 10 %.2f m)" % [bar_w.call(waves.hp_of(&"walker", 1)), bar_w.call(waves.hp_of(&"walker", 20)), bar_w.call(waves.hp_of(&"brute", 10))])
	waves.wave = was
	_clear()


## The leaper springs the last LEAP_FROM m in an arc and lands on its spot; a head shot in the air
## takes all its life, its legs (the tail) never come off.
func _leaper() -> void:
	gs.request_select_gun(PISTOL)
	var was: int = waves.wave
	waves.wave = waves.TYPES[&"leaper"].from
	var l := _spawn(&"leaper", Vector3(waves.RAIL_X + 9.0, 0, -4))
	l.speed = waves.STATS[&"crawler"][0] * waves.TYPES[&"leaper"].speed
	_expect(l.body.model == &"leaper" and l.body.crawling, "the leaper comes in its own look, low (%s)" % l.body.model)
	_expect(not l.body.can_lose(&"leg_l") and not l.body.can_lose(&"shin_r") and l.body.can_lose(&"arm_l"), "its tail never comes off, its arms do")
	await _wait(func() -> bool: return l.leap >= 0.0, "the leap", 8.0)
	var from := (l.node as Node3D).global_position.distance_to(l.rail)
	var high := 0.0
	while l.leap < waves.LEAP_TIME * 0.4:
		await process_frame
	high = (l.node as Node3D).global_position.y
	await _shoot(l, l.body._bone_at("Head"), Vector3(-1, 0, 0), true)
	_expect(from > 1.5 and from <= waves.LEAP_FROM + 0.2 and high > 0.6, "it springs from %.1f m out, %.2f m up" % [from, high])
	_expect(l.dead, "one pistol round in the head in the air drops it")
	var l2 := _spawn(&"leaper", Vector3(waves.RAIL_X + 9.0, 0, 4))
	l2.speed = waves.STATS[&"crawler"][0] * waves.TYPES[&"leaper"].speed
	await _wait(func() -> bool: return l2.path.is_empty() and not l2.dead, "the leaper at the railing", 10.0)
	_expect((l2.node as Node3D).global_position.distance_to(l2.rail) < 0.05, "and lands on its spot")
	waves.wave = was
	_clear()


## The spiker's head is weak only while it roars (every MAW_EVERY s); a body round does MAW_BODY.
func _spiker() -> void:
	gs.request_select_gun(DEAGLE)
	var was: int = waves.wave
	waves.wave = waves.TYPES[&"spiker"].from
	var s := _spawn(&"spiker", Vector3(24, 0, -4))
	var b := _spawn(&"brute", Vector3(24, 0, 4))
	_expect(s.body.model == &"spiker" and s.body.height > 2.5, "the spiker in its own look, %.1f m tall" % s.body.height)
	_expect(waves._hp_full[s.id] >= waves._hp_full[b.id] * 1.9, "twice a brute's life (%d, %d)" % [waves._hp_full[s.id], waves._hp_full[b.id]])
	var gone := func(z: Dictionary) -> float: return waves._hp_full[z.id] - waves._hp[z.id]
	await _shoot(s, s.body._bone_at("Spine1"), Vector3(-1, 0, 0))
	await _shoot(b, b.body._bone_at("Spine1"), Vector3(-1, 0, 0))
	_expect(absf(gone.call(s) - gone.call(b) * waves.MAW_BODY) < 0.5, "a body round takes %.0f of it, %.0f of a brute" % [gone.call(s), gone.call(b)])
	var shut: float = gone.call(s)
	await _shoot(s, s.body._bone_at("Head"), Vector3(-1, 0, 0), true)
	var closed: float = gone.call(s) - shut
	s.maw = 0.0  # its roar now
	await _wait(func() -> bool: return s.open > 0.0, "the roar", 2.0)
	_expect(s.hold > 0.0, "it stands while it roars")
	var before: float = gone.call(s)
	await _shoot(s, s.body._bone_at("Head"), Vector3(-1, 0, 0), true)
	var open: float = gone.call(s) - before
	_expect(open > closed * (waves.MAW_HEAD - 0.1), "its head: %.0f a round shut, %.0f roaring" % [closed, open])
	waves.wave = was
	_clear()


## One of `type` that did not come as an elite.
func _plain(type: StringName, at: Vector3) -> Dictionary:
	var z := _spawn(type, at)
	while z.elite:
		waves._kill(z.id, &"")
		z = _spawn(type, at)
	return z


## Its feet stay on the floor through the changes: the stride matches the ground it covers while it
## runs, is hit and brakes; once a swing starts it does not move.
func _no_slide() -> void:
	var z := _spawn(&"walker", Vector3(waves.RAIL_X + 5.0, 0, 2.0))
	var worst := 0.0
	var hit := false
	var braked := INF
	var prev := (z.node as Node3D).global_position
	var t_prev := Time.get_ticks_usec()
	var strides := []
	while not z.path.is_empty():
		await process_frame
		var ap: AnimationPlayer = z.body._ap
		if not z.path.is_empty() and not z.body.busy() and ap.current_animation.contains("run"):
			strides.append(ap.speed_scale * z.body._natural(ap.current_animation))
		var now := (z.node as Node3D).global_position
		var secs := (Time.get_ticks_usec() - t_prev) / 1e6
		if secs < 0.2 and not z.path.is_empty():
			continue
		var v := now.distance_to(prev) / secs  # over a fifth of a second: frames come unevenly
		if not strides.is_empty() and v > 0.3:
			var stride: float = strides.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / strides.size()
			worst = maxf(worst, absf(stride - v) / v)
		if now.x < waves.RAIL_X + 0.8:
			braked = minf(braked, v)
		prev = now
		t_prev = Time.get_ticks_usec()
		strides.clear()
		if not hit and now.x < waves.RAIL_X + 3.5:
			hit = true
			await _shoot(z, now + Vector3.UP * 1.1, Vector3(1, 0, 0))
	_expect(worst < 0.2, "the stride keeps up with the floor, hit and braking too (off by %d%% at worst)" % roundi(worst * 100.0))
	_expect(braked < z.speed * 0.7, "it brakes into its spot (%.2f m/s near it)" % braked)
	await _wait(func() -> bool: return z.body.busy(), "the first swing", 3.0)
	var at := (z.node as Node3D).global_position
	await create_timer(0.5).timeout
	_expect((z.node as Node3D).global_position.distance_to(at) < 0.02, "still while it swings (%.3f m)" % (z.node as Node3D).global_position.distance_to(at))
	_clear()


func _clear() -> void:
	for id: int in waves._zombies.keys():
		if not waves._zombies[id].dead and id != _anchor.id:
			waves._kill(id, &"")
	gs.mend_fence(gs.FENCE_MAX)


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
