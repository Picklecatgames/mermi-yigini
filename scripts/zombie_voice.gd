extends Node3D
## One zombie's voice, plus the gore sounds every zombie shares (static). Child of zombie_body.gd,
## on the head bone, so the moans come out of the mouth. Sound only: zombie_body calls it from
## idle / move / attack / hit / scream / die / wound.
##
## Recordings in assets/sounds/zombies (voices) and assets/sounds/gore (flesh). Against repetition:
## every bank is a shuffled bag (all of a bank plays before one comes again, never the same twice
## in a row, across all zombies), every zombie has its own voice pitch from its seed, each play is
## nudged in pitch and level, and the room has caps: a few moaning at once, a few flesh hits per
## instant (a minigun into a crowd would otherwise be a wall of splats). Everything plays on the
## "Zombi" bus, made here: the concrete pen's reverb, into Efekt.

const VOICES := "res://assets/sounds/zombies/"
const GORE := "res://assets/sounds/gore/"
## bank -> file prefix, how many
const BANKS := {
	&"groan": ["groan_", 9, VOICES], &"growl": ["growl_", 3, VOICES], &"wet": ["wet_", 7, VOICES],
	&"attack": ["attack_", 4, VOICES], &"scream": ["scream_", 3, VOICES], &"hurt": ["hurt_", 7, VOICES],
	&"death": ["death_", 5, VOICES], &"distant": ["distant_", 3, VOICES],
	&"flesh": ["flesh_", 8, GORE], &"head": ["head_", 5, GORE], &"kill": ["kill_", 2, GORE],
	&"burst": ["burst_", 5, GORE], &"chunk": ["chunk_", 5, GORE], &"ooze": ["ooze_", 5, GORE],
}
## kind -> ambient banks, seconds between them, voice pitch range
const KIND_VOICE := {
	&"walker": {"banks": [&"groan", &"groan", &"growl"], "gap": [4.0, 11.0], "pitch": [0.9, 1.08]},
	&"runner": {"banks": [&"growl", &"groan"], "gap": [2.5, 6.0], "pitch": [1.0, 1.12]},
	&"crawler": {"banks": [&"groan", &"wet"], "gap": [5.0, 12.0], "pitch": [0.95, 1.1]},
	&"brute": {"banks": [&"wet", &"growl"], "gap": [5.0, 10.0], "pitch": [0.72, 0.84]},
	&"blob": {"banks": [&"wet"], "gap": [3.0, 8.0], "pitch": [0.6, 0.75]},
	&"dog": {"banks": [&"growl"], "gap": [2.0, 5.0], "pitch": [1.25, 1.45]},
}
const MOANS_AT_ONCE := 5  # ambient voices over the whole room; the rest wait for their next turn
const MOAN_RANGE := 45.0  # m from the listener; farther ones keep quiet
const HURT_GAP := 0.6  # s between one zombie's pained grunts
const HURT_CHANCE := 0.45
const ATTACK_GAP := 1.4  # s, so a zombie clawing at the railing doesn't shriek every swing
const FLESH_GAP := 0.07  # s between one zombie's flesh hits (minigun)
const FLESH_PER_TICK := 3  # flesh hits started across the room per FLESH_TICK
const FLESH_TICK := 0.06
const GORE_POOL := 24
const BUS := &"Zombi"

var kind := &"walker"
var dead := false

var _player: AudioStreamPlayer3D
var _pitch := 1.0
var _talking := false  # the clip now playing is an ambient moan (counts toward MOANS_AT_ONCE)
var _awake := false  # idle / move called: moans on a timer
var _next_moan := 0.0
var _last_hurt := -10.0
var _last_attack := -10.0
var _last_flesh := -10.0

static var _streams := {}  # bank -> Array[AudioStream]
static var _bags := {}  # bank -> Array[int], what is left to play this round
static var _last := {}  # bank -> index played last
static var _moaning := 0
static var _pool: Array[AudioStreamPlayer3D] = []
static var _next_pool := 0
static var _tick_at := -1.0
static var _tick_count := 0


func setup(p_kind: StringName, seed: int) -> void:
	kind = p_kind if KIND_VOICE.has(p_kind) else &"walker"
	var range_: Array = KIND_VOICE[kind].pitch
	_pitch = lerpf(range_[0], range_[1], float(absi(hash("%d:voice" % seed)) % 1000) / 999.0)


func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_shape(_player, 4.0 if kind != &"brute" else 6.0)
	_player.finished.connect(_on_finished)
	add_child(_player)
	_next_moan = _now() + randf_range(0.5, 4.0)


func _exit_tree() -> void:
	if _talking:
		_moaning -= 1
		_talking = false


func _process(_delta: float) -> void:
	if dead or not _awake or _now() < _next_moan:
		return
	var gap: Array = KIND_VOICE[kind].gap
	_next_moan = _now() + randf_range(gap[0], gap[1])
	if _player.playing or _moaning >= MOANS_AT_ONCE or _far():
		return
	_say(KIND_VOICE[kind].banks.pick_random(), 0.0, true)


## Groans start (pen, walk).
func wake() -> void:
	_awake = true


func scream() -> void:
	_say(&"scream", 3.0 if kind == &"brute" else 1.0)
	if kind == &"brute":  # a wet growl under the scream: a roar, not a shout
		gore(&"wet", global_position, 0.0, _pitch)
	_next_moan = _now() + 4.0


func attack() -> void:
	if _now() - _last_attack < ATTACK_GAP or randf() > 0.7:
		return
	_last_attack = _now()
	_say(&"attack", 1.0)
	_next_moan = _now() + 3.0


## A round went in: the flesh at `at`, maybe a grunt from the mouth.
func shot(at: Vector3, head: bool) -> void:
	var t := _now()
	if t - _last_flesh >= FLESH_GAP:
		_last_flesh = t
		gore(&"head" if head else &"flesh", at, 2.0 if head else 0.0, 0.8 if kind == &"brute" else 1.0)
	if dead or t - _last_hurt < HURT_GAP:
		return
	_last_hurt = t
	if head or randf() < HURT_CHANCE:
		_say(&"hurt", 0.0)
		_next_moan = t + 2.5


## Down for good. `headless`: the head is gone, so no death rattle, just the burst.
func die(at: Vector3, burst: bool, headless: bool) -> void:
	if dead:
		return
	dead = true
	var heavy := 0.8 if kind == &"brute" else 1.0
	gore(&"burst" if burst else &"kill", at, 2.0 if burst else 0.0, heavy)
	if headless:
		_player.stop()
		_stop_talking()
	else:
		_say(&"death", 1.0)


## The body has settled and the pool spreads: a quiet wet trickle where it lies.
func ooze(at: Vector3) -> void:
	gore(&"ooze", at, -9.0)


## A pen full of them, heard from far off through the gate (already reverberant in the recording).
static func distant(at: Vector3) -> void:
	gore(&"distant", at, -4.0)


## A gore (or any bank) sound at a spot in the world, on the shared pool. A burst of flesh hits in
## one instant is thinned out (FLESH_PER_TICK).
static func gore(bank: StringName, at: Vector3, db := 0.0, pitch := 1.0) -> void:
	if db <= -60.0:
		return
	if bank in [&"flesh", &"head", &"chunk"]:
		var t := _now()
		if t - _tick_at > FLESH_TICK:
			_tick_at = t
			_tick_count = 0
		_tick_count += 1
		if _tick_count > FLESH_PER_TICK:
			return
	var p := _free_player()
	if p == null:
		return
	p.global_position = at
	p.stream = _draw(bank)
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.volume_db = db + randf_range(-1.5, 1.0)
	p.play()


func _say(bank: StringName, db: float, ambient := false) -> void:
	if dead and bank != &"death":
		return
	_stop_talking()
	_player.stream = _draw(bank)
	_player.pitch_scale = _pitch * randf_range(0.95, 1.05)
	_player.volume_db = db + randf_range(-1.5, 1.0) + (2.0 if kind == &"brute" else 0.0)
	_player.play()
	if ambient:
		_talking = true
		_moaning += 1


func _stop_talking() -> void:
	if _talking:
		_talking = false
		_moaning -= 1


func _on_finished() -> void:
	_stop_talking()


func _far() -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam != null and cam.global_position.distance_to(global_position) > MOAN_RANGE


## Next sound of a bank from its shuffled bag; a fresh bag never starts with the one just played.
static func _draw(bank: StringName) -> AudioStream:
	if not _streams.has(bank):
		var b: Array = BANKS[bank]
		var list: Array[AudioStream] = []
		for i in b[1]:
			list.append(load("%s%s%02d.ogg" % [b[2], b[0], i + 1]))
		_streams[bank] = list
	var list: Array = _streams[bank]
	var bag: Array = _bags.get(bank, [])
	if bag.is_empty():
		for i in list.size():
			bag.append(i)
		bag.shuffle()
		if bag.size() > 1 and bag[-1] == _last.get(bank, -1):
			bag.reverse()
		_bags[bank] = bag
	var i: int = bag.pop_back()
	_last[bank] = i
	return list[i]


static func _free_player() -> AudioStreamPlayer3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	if _pool.is_empty() or not is_instance_valid(_pool[0]) or not _pool[0].is_inside_tree():
		_pool.clear()
		var holder := Node3D.new()
		holder.name = "ZombieGoreSounds"
		tree.current_scene.add_child(holder)
		for i in GORE_POOL:
			var p := AudioStreamPlayer3D.new()
			_shape(p, 3.0)
			holder.add_child(p)
			_pool.append(p)
	# The oldest one that is quiet, else the oldest outright.
	for k in GORE_POOL:
		var p := _pool[(_next_pool + k) % GORE_POOL]
		if not p.playing:
			_next_pool = (_next_pool + k + 1) % GORE_POOL
			return p
	var p := _pool[_next_pool]
	_next_pool = (_next_pool + 1) % GORE_POOL
	return p


static func _shape(p: AudioStreamPlayer3D, unit: float) -> void:
	p.bus = _bus()
	p.unit_size = unit
	p.max_db = 4.0
	p.max_distance = 80.0
	p.attenuation_filter_cutoff_hz = 3500.0  # far ones lose their edge
	p.attenuation_filter_db = -18.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED


## The "Zombi" bus: a bigger, wetter room than Dunya's (bare concrete pens and corridor), into
## Efekt so the effects slider reaches it.
static func _bus() -> StringName:
	if AudioServer.get_bus_index(BUS) < 0:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, BUS)
		var r := AudioEffectReverb.new()
		r.room_size = 0.7
		r.damping = 0.45
		r.predelay_msec = 45.0
		r.predelay_feedback = 0.3
		r.spread = 0.9
		r.hipass = 0.15
		r.wet = 0.22
		r.dry = 1.0
		AudioServer.add_bus_effect(i, r)
		AudioServer.set_bus_send(i, &"Efekt" if AudioServer.get_bus_index(&"Efekt") >= 0 else &"Master")
	return BUS


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
