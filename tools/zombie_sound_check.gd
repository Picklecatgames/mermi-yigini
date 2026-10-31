extends SceneTree
## Headless check for scripts/zombie_voice.gd and zombie_gibs.gd: every bank's files load, a bank
## plays all its sounds before one comes again and never the same twice in a row, the room never
## has more than MOANS_AT_ONCE moaning, a minigun burst into one zombie is thinned out, and a zombie
## dies whole, headless and burst without errors, its meat landing on the floor.
##   Godot.exe --headless --path . -s res://tools/zombie_sound_check.gd --quit-after 2000

const VOICE := preload("res://scripts/zombie_voice.gd")
const BODY := preload("res://scripts/zombie_body.gd")
const GIBS := preload("res://scripts/zombie_gibs.gd")

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

	# A crowd: never more than MOANS_AT_ONCE ambient voices.
	var bodies: Array[Node3D] = []
	for i in 20:
		var holder := Node3D.new()
		world.add_child(holder)
		holder.position = Vector3(i % 5, 0, -i / 5.0)
		var b: Node3D = BODY.new()
		b.setup([&"walker", &"runner", &"crawler", &"brute"][i % 4], i)
		holder.add_child(b)
		bodies.append(b)
	var most := 0
	for f in 600:
		await process_frame
		most = maxi(most, VOICE._moaning)
	_expect(most > 0, "nobody moaned in 600 frames")
	_expect(most <= VOICE.MOANS_AT_ONCE, "%d moaning at once" % most)
	print("  most moaning at once: %d" % most)
	_expect(AudioServer.get_bus_index(VOICE.BUS) >= 0, "no Zombi bus")

	# A minigun burst: 40 rounds in one frame start at most FLESH_PER_TICK flesh hits.
	var before := _playing()
	for i in 40:
		bodies[0].wound(bodies[0].global_position + Vector3.UP, Vector3.FORWARD, false)
	var started := _playing() - before
	_expect(started <= VOICE.FLESH_PER_TICK + 1, "%d sounds started by one burst" % started)

	# Deaths: whole, head off, body burst.
	bodies[1].die()
	bodies[2].die(&"head")
	bodies[3].die(&"body")
	var gibs := world.find_children("*", "", false, false).filter(func(n: Node) -> bool: return n.get_script() == GIBS)
	_expect(gibs.size() == 2, "%d gib bursts, wanted 2" % gibs.size())
	await create_timer(3.0).timeout  # by the clock: headless frames go by faster than 60 a second
	for g in gibs:
		var down := 0
		for l in g._lumps:
			down += 1 if l.bounced else 0
			_expect((l.node as Node3D).global_position.y >= -0.01, "a lump went through the floor")
		_expect(down == g._lumps.size(), "%d of %d lumps still in the air after 3 s" % [g._lumps.size() - down, g._lumps.size()])
	_expect(bodies[2]._flinch.head_gone, "head shot kill kept its head")

	for b in bodies:
		b.get_parent().queue_free()
	await process_frame
	await process_frame
	_expect(VOICE._moaning == 0, "moan count left at %d after they were freed" % VOICE._moaning)
	print("zombie_sound_check: %s" % ("OK" if _fails == 0 else "%d FAIL" % _fails))
	quit(_fails)


func _playing() -> int:
	var n := 0
	for p in VOICE._pool:
		n += 1 if is_instance_valid(p) and p.playing else 0
	return n


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL " + what)
