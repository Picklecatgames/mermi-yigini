extends SceneTree
## Headless check for scripts/zombie_voice.gd and zombie_gibs.gd: every bank's files load, a bank
## plays all its sounds before one comes again, never the same twice in a row and not one heard in
## the last RECENT s while another is free; the Zombi and ZombiEt buses have their chain; the
## players fall off as set; the voice budget holds (40 zombies hurt, howling, screaming in one
## frame: never past ZOMBIE_VOICES, grunts past HURT_VOICES; moans past MOAN_VOICES, and only from
## the NEAREST); a death takes a voice; a minigun burst into one zombie is thinned out; and a zombie
## dies whole, headless and burst without errors, its meat landing on the floor.
##   Godot.exe --headless --path . -s res://tools/zombie_sound_check.gd

const VOICE := preload("res://scripts/zombie_voice.gd")
const BODY := preload("res://scripts/zombie_body.gd")
const GIBS := preload("res://scripts/zombie_gibs.gd")
const CROWD := 40
const MOAN_WATCH := 14.0  # s of wall clock: past FIRST_MOAN and a turn of the gaps

var _fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.global_position = Vector3(0, 1.7, 8)

	# Banks: files load, shuffled bags.
	for bank in VOICE.BANKS:
		if bank in VOICE.UNRECORDED:
			print("  (%s: not recorded yet, silent)" % bank)
			continue
		var n: int = VOICE.BANKS[bank][1]
		var seen := {}
		var last: AudioStream = null
		for i in n * 6:
			var s: AudioStream = VOICE._draw(bank)
			_expect(s != null, "%s: a file is missing" % bank)
			_expect(n == 1 or s != last, "%s: same sound twice in a row" % bank)
			last = s
			if i < n:
				seen[s] = true
		_expect(seen.size() == n, "%s: %d of %d in the first round" % [bank, seen.size(), n])
		_expect(n >= 6 or bank in [&"distant", &"head", &"kill", &"burst", &"chunk", &"ooze"], "%s: only %d variants" % [bank, n])
	# One just heard waits while the bag has another, even across a fresh bag.
	VOICE._used.clear()
	VOICE._bags.erase(&"groan")
	var heard: AudioStream = VOICE._draw(&"groan")
	VOICE._bags.erase(&"groan")
	for i in VOICE.BANKS[&"groan"][1] - 1:
		_expect(VOICE._draw(&"groan") != heard, "groan: a file came again inside %s s" % VOICE.RECENT)

	# Buses: the chip's chain, in order, into Efekt.
	_chain(VOICE.BUS, [AudioEffectHighPassFilter, AudioEffectLowPassFilter, AudioEffectDistortion, AudioEffectReverb, AudioEffectCompressor])
	_chain(VOICE.GORE_BUS, [AudioEffectLowPassFilter, AudioEffectDistortion])
	var zb := AudioServer.get_bus_index(VOICE.BUS)
	if zb >= 0:
		var lp := AudioServer.get_bus_effect(zb, 1) as AudioEffectLowPassFilter
		_expect(lp.db == AudioEffectFilter.FILTER_12DB and is_equal_approx(lp.cutoff_hz, 3800.0), "Zombi low-pass: 3800 Hz, 12 dB")
		var lofi := AudioServer.get_bus_effect(zb, 2) as AudioEffectDistortion
		_expect(lofi.mode == AudioEffectDistortion.MODE_LOFI and lofi.resource_name == "SPU", "Zombi: the SPU's bits")
		_expect((AudioServer.get_bus_effect(zb, 3) as AudioEffectReverb).wet < 0.1, "Zombi: a nearly dry echo")

	# A crowd.
	var bodies: Array[Node3D] = []
	for i in CROWD:
		var holder := Node3D.new()
		world.add_child(holder)
		holder.position = Vector3(i % 8 * 1.5 - 5.0, 0, -i / 8 * 2.5)
		var b: Node3D = BODY.new()
		b.setup([&"walker", &"runner", &"crawler", &"brute"][i % 4], i)
		holder.add_child(b)
		bodies.append(b)
	await process_frame

	# Falloff, as set.
	var walker: AudioStreamPlayer3D = bodies[0]._voice._player
	_expect(walker.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE, "voice: inverse distance")
	_expect(walker.unit_size == VOICE.UNIT and walker.max_db == 0.0 and walker.max_distance == VOICE.MAX_DISTANCE, "voice: unit %s, max_db 0, gone at %s m" % [VOICE.UNIT, VOICE.MAX_DISTANCE])
	_expect(walker.attenuation_filter_cutoff_hz == VOICE.FAR_CUTOFF and walker.attenuation_filter_db == VOICE.FAR_FILTER_DB, "voice: far ones dulled")
	_expect(walker.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED and walker.bus == VOICE.BUS, "voice: no doppler, on Zombi")
	_expect(bodies[3]._voice._player.unit_size == VOICE.BRUTE_UNIT, "brute: a bigger voice")

	# Ambient moans: never past MOAN_VOICES, only from the NEAREST to the camera.
	var near := bodies.duplicate()
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(cam.global_position) < b.global_position.distance_to(cam.global_position))
	var nearest := near.slice(0, VOICE.NEAREST).map(func(b: Node3D) -> Node: return b._voice)
	var most := 0
	var strays := 0
	var end := Time.get_ticks_msec() + int(MOAN_WATCH * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		most = maxi(most, VOICE.voices(&"moan"))
		for v: Array in VOICE._active:
			strays += int(v[3] == &"moan" and v[0] not in nearest)
	_expect(most > 0, "nobody moaned in %s s" % MOAN_WATCH)
	_expect(most <= VOICE.MOAN_VOICES, "%d moaning at once" % most)
	_expect(strays == 0, "%d moan frames from past the nearest %d" % [strays, VOICE.NEAREST])
	print("  most moaning at once: %d" % most)

	# Everybody hurt in one frame: the budget holds.
	for b in bodies:
		b._voice.shot(b.global_position + Vector3.UP, true)
	_expect(VOICE.voices(&"hurt") <= VOICE.HURT_VOICES, "%d grunting at once" % VOICE.voices(&"hurt"))
	print("  40 shot in the head: %d grunts" % VOICE.voices(&"hurt"))
	for b in bodies:
		b._voice.pain()
		b._voice.scream()
	print("  40 hurt, howling and screaming: %d voices (%d grunts)" % [VOICE.voices(), VOICE.voices(&"hurt")])
	_expect(VOICE.voices() <= VOICE.ZOMBIE_VOICES, "%d voices at once" % VOICE.voices())
	_expect(VOICE.voices() > 0, "the budget let nobody through")
	# A moment on, a death takes the voice of a lesser call.
	await create_timer(VOICE.STEAL_AFTER + 0.1).timeout
	var quiet: Node3D = bodies.filter(func(b: Node3D) -> bool: return VOICE._active.all(func(v: Array) -> bool: return v[0] != b._voice))[0]
	var lesser := VOICE._active.any(func(v: Array) -> bool: return v[1] <= VOICE.PRIORITY[&"death"])
	quiet._voice.die(quiet.global_position, false, false)
	_expect(not lesser or VOICE._active.any(func(v: Array) -> bool: return v[0] == quiet._voice), "a death didn't get a voice")
	_expect(VOICE.voices() <= VOICE.ZOMBIE_VOICES, "%d voices after a death" % VOICE.voices())

	# A minigun burst: 40 rounds in one frame start at most FLESH_PER_TICK flesh hits.
	await create_timer(VOICE.FLESH_TICK * 2.0).timeout
	var before := _playing()
	for i in 40:
		bodies[4].wound(bodies[4].global_position + Vector3.UP, Vector3.FORWARD, false)
	var started := _playing() - before
	_expect(started <= VOICE.FLESH_PER_TICK, "%d flesh hits started by one burst" % started)

	# Deaths: whole, head off, body burst.
	var is_gib := func(n: Node) -> bool: return n.get_script() == GIBS
	var torn := world.find_children("*", "", false, false).filter(is_gib).size()  # limbs off in the burst
	bodies[5].die()
	bodies[6].die(&"head")
	bodies[7].die(&"body")
	var gibs := world.find_children("*", "", false, false).filter(is_gib)
	_expect(gibs.size() - torn >= 2, "%d gib bursts, wanted 2 (and maybe a hat)" % (gibs.size() - torn))
	await create_timer(3.0).timeout  # by the clock: headless frames go by faster than 60 a second
	for g in gibs:
		var down := 0
		for l in g._lumps:
			down += 1 if l.bounced else 0
			_expect((l.node as Node3D).global_position.y >= -0.01, "a lump went through the floor")
		_expect(down == g._lumps.size(), "%d of %d lumps still in the air after 3 s" % [g._lumps.size() - down, g._lumps.size()])
	_expect(bodies[6]._flinch.head_gone, "head shot kill kept its head")

	for b in bodies:
		b.get_parent().queue_free()
	await process_frame
	await process_frame
	_expect(VOICE.voices() == 0, "%d voices left after they were freed" % VOICE.voices())
	_expect(VOICE._all.is_empty(), "%d voices still listed after they were freed" % VOICE._all.size())
	print("zombie_sound_check: %s" % ("OK" if _fails == 0 else "%d FAIL" % _fails))
	quit(_fails)


func _chain(bus: StringName, types: Array) -> void:
	var i := AudioServer.get_bus_index(bus)
	_expect(i >= 0, "no %s bus" % bus)
	if i < 0:
		return
	_expect(AudioServer.get_bus_send(i) == &"Efekt", "%s sends into %s" % [bus, AudioServer.get_bus_send(i)])
	_expect(AudioServer.get_bus_effect_count(i) == types.size(), "%s: %d effects" % [bus, AudioServer.get_bus_effect_count(i)])
	for e in mini(types.size(), AudioServer.get_bus_effect_count(i)):
		_expect(is_instance_of(AudioServer.get_bus_effect(i, e), types[e]), "%s: effect %d is %s" % [bus, e, AudioServer.get_bus_effect(i, e).get_class()])


## Flesh hits sounding on the gore pool (a limb torn off in the burst plays its own, unthinned).
func _playing() -> int:
	var flesh: Array = VOICE._streams.get(&"flesh", []) + VOICE._streams.get(&"head", [])
	var n := 0
	for p in VOICE._pool:
		n += 1 if is_instance_valid(p) and p.playing and p.stream in flesh else 0
	return n


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL " + what)
