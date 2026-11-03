extends Node3D
## One zombie's voice, plus the gore sounds every zombie shares (static). Child of zombie_body.gd,
## on the head bone, so the moans come out of the mouth. Sound only: zombie_body calls it from
## idle / move / attack / hit / scream / die / wound. Local and cosmetic: each peer picks its own.
##
## Recordings in assets/sounds/zombies (voices) and assets/sounds/gore (flesh), brought in by
## tools/ses_ekle.py (22 kHz, 12 bits, -20 / -19 LUFS). The mix (docs/ayrintilar.md "Zombi sesi"):
## - One budget for every zombie's mouth: ZOMBIE_VOICES at once, of them at most MOAN_VOICES
##   moaning and HURT_VOICES grunting. A new call over the budget takes the voice of the least
##   important one (the farthest of those), if that one has been going a moment; else it is dropped.
##   Only the NEAREST zombies to our camera moan at all, and a crowd moans less each.
## - Against repetition: every bank is a shuffled bag shared by all zombies, a file heard in the
##   last RECENT seconds is passed over while another is free, every zombie has its own pitch and
##   level from its seed, and each play is nudged in both.
## - The "Zombi" bus (ps1_sound.gd, made with the others): the PS1 chip's band and bits, a short
##   dry yard echo, a compressor; the gore on "ZombiEt", the same chip with no echo. Both into Efekt.
## - Falloff of -6 dB a doubling with the top rolled off far away: near ones are clear and placed,
##   far ones sink into a dull murmur instead of piling up.

const VOICES := "res://assets/sounds/zombies/"
const GORE := "res://assets/sounds/gore/"
## bank -> file prefix, how many
const BANKS := {
	&"groan": ["groan_", 9, VOICES], &"growl": ["growl_", 6, VOICES], &"wet": ["wet_", 7, VOICES],
	&"attack": ["attack_", 6, VOICES], &"scream": ["scream_", 7, VOICES], &"hurt": ["hurt_", 7, VOICES],
	&"death": ["death_", 7, VOICES], &"distant": ["distant_", 3, VOICES],
	&"flesh": ["flesh_", 8, GORE], &"head": ["head_", 5, GORE], &"kill": ["kill_", 2, GORE],
	&"burst": ["burst_", 5, GORE], &"chunk": ["chunk_", 5, GORE], &"ooze": ["ooze_", 5, GORE],
	# A head blown off (zombie_body.gd _blow_head()): the skull going, bone cracking, the neck spurting.
	# Not recorded yet: a bank with no files on disk stays silent.
	&"pop": ["pop_", 4, GORE], &"crack": ["crack_", 4, GORE], &"squirt": ["squirt_", 4, GORE],
}
const UNRECORDED := [&"pop", &"crack", &"squirt"]  # banks still waiting for the user's recordings
## kind -> ambient banks, seconds between them (one zombie, before the crowd stretches it), voice pitch
const KIND_VOICE := {
	&"walker": {"banks": [&"groan", &"groan", &"growl"], "gap": [8.0, 18.0], "pitch": [0.9, 1.08]},
	&"runner": {"banks": [&"growl", &"groan"], "gap": [5.0, 12.0], "pitch": [1.0, 1.12]},
	&"crawler": {"banks": [&"groan", &"wet"], "gap": [10.0, 20.0], "pitch": [0.95, 1.1]},
	&"brute": {"banks": [&"wet", &"growl"], "gap": [9.0, 16.0], "pitch": [0.72, 0.84]},
	&"blob": {"banks": [&"wet"], "gap": [7.0, 14.0], "pitch": [0.6, 0.75]},
	&"dog": {"banks": [&"growl", &"wet"], "gap": [4.0, 9.0], "pitch": [1.25, 1.45]},
	&"bloater": {"banks": [&"wet", &"groan"], "gap": [7.0, 14.0], "pitch": [0.78, 0.9]},
	&"screamer": {"banks": [&"growl", &"groan"], "gap": [6.0, 12.0], "pitch": [1.1, 1.24]},
}

# Level, against the file's own -20 LUFS. -12 puts a groan at arm's length about 6 dB under our
# own pistol (100 ms RMS through the bus chain: groan -26, pistol -21).
const VOICE_DB := -12.0
const SCREAM_DB := 2.0  # brute and screamer: their scream is their thing
const PAIN_DB := 1.0  # a limb torn off
const OOZE_DB := -9.0
const DISTANT_DB := -4.0
const SEED_DB := 2.0  # each zombie's own level, ± from its seed
const PLAY_DB := Vector2(-2.0, 1.0)  # each play's nudge
const PLAY_PITCH := 0.04  # each play's pitch, ± share
const GORE_PITCH := 0.08
const GORE_DB := Vector2(-1.5, 1.0)

# Falloff: the real world's, -6 dB each time the distance doubles (Godot's INVERSE_DISTANCE; its
# INVERSE_SQUARE is -12 a doubling, and a groan at 20 m sank under the night's crickets). At the
# unit size the level is VOICE_DB; nearer it climbs, to max_db 0 at most (Godot caps the sum).
# Gone at MAX_DISTANCE; far ones lose their top.
const UNIT := 5.0
const BRUTE_UNIT := 6.5
const GORE_UNIT := 3.5
const MAX_DISTANCE := 50.0
const FAR_CUTOFF := 2500.0
const FAR_FILTER_DB := -24.0

# The voice budget.
const ZOMBIE_VOICES := 6  # zombie mouths sounding at once, every zombie together
const MOAN_VOICES := 3  # of them, ambient moans
const HURT_VOICES := 2  # of them, hit grunts
## call -> priority: a new call may take the voice of one with the same or a lower priority
const PRIORITY := {&"death": 4, &"scream": 4, &"attack": 3, &"pain": 3, &"hurt": 2, &"moan": 1}
const STEAL_AFTER := 0.25  # s a voice must have been going before it can be taken
const STEAL_FADE := 0.05  # s a taken voice fades out in
const NEAREST := 8  # only these many zombies nearest our camera moan
const NEAREST_EVERY := 0.5  # s between looks at who they are
const MOAN_RANGE := 30.0  # m from the listener; farther ones keep quiet
const CROWD := 10.0  # past this many alive, each zombie's moans come that much less often

# Timing.
const FIRST_MOAN := Vector2(3.0, 10.0)  # s after it is up: a wave doesn't arrive as one roar
const QUIET_AFTER := 4.0  # s after any call before the next moan
const HURT_GAP := 1.5  # s between one zombie's pained grunts
const HURT_CHANCE := 0.3
const HEAD_HURT_CHANCE := 0.6
const HURT_SPACING := 0.15  # s between any two zombies' grunts starting
const ATTACK_GAP := Vector2(2.5, 4.0)  # s, so a zombie clawing at us doesn't shriek every swing
const ATTACK_CHANCE := 0.5
const RECENT := 3.0  # s a file is passed over after anyone played it, while another is free

# Gore.
const FLESH_GAP := 0.07  # s between one zombie's flesh hits (minigun)
const FLESH_SPACING := 0.05  # s between any two flesh or head hits starting
const FLESH_PER_TICK := 2  # flesh hits started across the room per FLESH_TICK
const FLESH_TICK := 0.08
const GORE_POOL := 12
const BUS := &"Zombi"
const GORE_BUS := &"ZombiEt"
const FAR_BUS := &"PsUzak"

var kind := &"walker"
var dead := false

var _player: AudioStreamPlayer3D
var _pitch := 1.0
var _level := 0.0  # dB, this zombie's own
var _awake := false  # idle / move called: moans on a timer
var _next_moan := 0.0
var _next_attack := 0.0
var _last_hurt := -10.0
var _last_flesh := -10.0
var _fade: Tween

static var _streams := {}  # bank -> Array[AudioStream]
static var _warming := {}  # path -> asked of the loader thread (warm())
static var _bags := {}  # bank -> Array[int], what is left to play this round
static var _last := {}  # bank -> index played last
static var _used := {}  # AudioStream -> when it last started
static var _active: Array = []  # [voice, priority, started, call]: the budget's voices
static var _all: Array = []  # every zombie voice in the tree
static var _near := {}  # the NEAREST ones -> true
static var _near_at := -10.0
static var _last_grunt := -10.0
static var _last_hit := -10.0
static var _pool: Array[AudioStreamPlayer3D] = []
static var _next_pool := 0
static var _tick_at := -1.0
static var _tick_count := 0


func setup(p_kind: StringName, seed: int) -> void:
	kind = p_kind if KIND_VOICE.has(p_kind) else &"walker"
	var range_: Array = KIND_VOICE[kind].pitch
	_pitch = lerpf(range_[0], range_[1], float(absi(hash("%d:voice" % seed)) % 1000) / 999.0)
	_level = lerpf(-SEED_DB, SEED_DB, float(absi(hash("%d:level" % seed)) % 1000) / 999.0)


func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_shape(_player, BRUTE_UNIT if kind == &"brute" else UNIT)
	add_child(_player)
	_next_moan = _now() + randf_range(FIRST_MOAN.x, FIRST_MOAN.y)


func _enter_tree() -> void:
	if self not in _all:
		_all.append(self)


func _exit_tree() -> void:
	_release(self)
	_all.erase(self)
	_near.erase(self)


func _process(_delta: float) -> void:
	if dead or not _awake or _now() < _next_moan:
		return
	var gap: Array = KIND_VOICE[kind].gap
	_next_moan = _now() + randf_range(gap[0], gap[1]) * maxf(1.0, _alive() / CROWD)
	if _player.playing or not _is_near() or _far():
		return
	_say(KIND_VOICE[kind].banks.pick_random(), 0.0, &"moan")


## Groans start (pen, walk).
func wake() -> void:
	_awake = true


func scream() -> void:
	if not _say(&"scream", SCREAM_DB if kind in [&"brute", &"screamer"] else 0.0, &"scream"):
		return
	if kind == &"brute":  # a wet growl under the scream: a roar, not a shout
		gore(&"wet", global_position, VOICE_DB + _level, _pitch)


func attack() -> void:
	if _now() < _next_attack:
		return
	_next_attack = _now() + randf_range(ATTACK_GAP.x, ATTACK_GAP.y)
	if randf() < ATTACK_CHANCE:
		_say(&"attack", 0.0, &"attack")


## A round went in: the flesh at `at`, maybe a grunt from the mouth.
func shot(at: Vector3, head: bool) -> void:
	var t := _now()
	if t - _last_flesh >= FLESH_GAP:
		_last_flesh = t
		gore(&"head" if head else &"flesh", at, 2.0 if head else 0.0, 0.8 if kind == &"brute" else 1.0)
	if dead or t - _last_hurt < HURT_GAP or t - _last_grunt < HURT_SPACING:
		return
	_last_hurt = t
	if randf() < (HEAD_HURT_CHANCE if head else HURT_CHANCE) and _say(&"hurt", 0.0, &"hurt"):
		_last_grunt = t


## A limb torn off: it howls whatever the gap since the last grunt.
func pain() -> void:
	if dead:
		return
	_last_hurt = _now()
	_say(&"hurt", PAIN_DB, &"pain")


## Down for good. `headless`: the head is gone, so no death rattle, just the burst.
func die(at: Vector3, burst: bool, headless: bool) -> void:
	if dead:
		return
	dead = true
	_near.erase(self)
	var heavy := 0.8 if kind == &"brute" else 1.0
	gore(&"burst" if burst else &"kill", at, 2.0 if burst else 0.0, heavy)
	if headless:
		_silence()
	else:
		_say(&"death", 0.0, &"death")


## The body has settled and the pool spreads: a quiet wet trickle where it lies.
func ooze(at: Vector3) -> void:
	gore(&"ooze", at, OOZE_DB)


## A crowd heard from far off (already reverberant in the recording), on the far-call bus. Nothing
## calls it since the pens went; kept for the night's horizon.
static func distant(at: Vector3) -> void:
	gore(&"distant", at, DISTANT_DB)


## A gore (or any bank) sound at a spot in the world, on the shared pool, outside the voice budget.
## A burst of flesh hits in one instant is thinned out (FLESH_SPACING, FLESH_PER_TICK).
static func gore(bank: StringName, at: Vector3, db := 0.0, pitch := 1.0) -> void:
	if db <= -60.0:
		return
	var t := _now()
	if bank in [&"flesh", &"head"]:
		if t - _last_hit < FLESH_SPACING:
			return
		_last_hit = t
	if bank in [&"flesh", &"head", &"chunk"]:
		if t - _tick_at > FLESH_TICK:
			_tick_at = t
			_tick_count = 0
		_tick_count += 1
		if _tick_count > FLESH_PER_TICK:
			return
	var stream := _draw(bank)
	var p := _free_player() if stream else null
	if p == null:
		return
	p.bus = _bank_bus(bank)
	p.global_position = at
	p.stream = stream
	p.pitch_scale = pitch * randf_range(1.0 - GORE_PITCH, 1.0 + GORE_PITCH)
	p.volume_db = db + randf_range(GORE_DB.x, GORE_DB.y)
	p.play()


## How many of the budget's voices sound now (all calls, or one: &"moan", &"hurt", ...).
static func voices(call := &"") -> int:
	_prune()
	return _active.filter(func(v: Array) -> bool: return call == &"" or v[3] == call).size()


## One call from this mouth, if the budget lets it through. Returns whether it plays.
func _say(bank: StringName, db: float, call: StringName) -> bool:
	if (dead and call != &"death") or not _claim(self, call):
		return false
	var stream := _draw(bank)
	if stream == null:
		return false
	_release(self)
	if _fade:
		_fade.kill()
	_player.stream = stream
	_player.pitch_scale = _pitch * randf_range(1.0 - PLAY_PITCH, 1.0 + PLAY_PITCH)
	_player.volume_db = VOICE_DB + _level + db + randf_range(PLAY_DB.x, PLAY_DB.y)
	_player.play()
	_active.append([self, PRIORITY[call], _now(), call])
	if call != &"moan":
		_next_moan = maxf(_next_moan, _now() + QUIET_AFTER)
	return true


## Room for `call` from `who`: free, or taken from the least important voice of those it is
## counted against (the farthest of equals), if that one is no more important and has been going
## STEAL_AFTER. Moans never take a voice: they only wait for their next turn.
static func _claim(who: Node, call: StringName) -> bool:
	_prune()
	var others := _active.filter(func(v: Array) -> bool: return v[0] != who)
	var same := others.filter(func(v: Array) -> bool: return v[3] == call)
	var cap: int = {&"moan": MOAN_VOICES, &"hurt": HURT_VOICES}.get(call, ZOMBIE_VOICES)
	var pool: Array
	if same.size() >= cap:
		pool = same
	elif others.size() >= ZOMBIE_VOICES:
		pool = others
	else:
		return true
	if call == &"moan":
		return false
	var cam := _camera(who)
	var victim: Array = pool[0]
	for v: Array in pool:
		if v[1] < victim[1] or (v[1] == victim[1] and _distance(v[0], cam) > _distance(victim[0], cam)):
			victim = v
	if victim[1] > PRIORITY[call] or _now() - victim[2] < STEAL_AFTER:
		return false
	_active.erase(victim)
	victim[0]._fade_out()
	return true


func _fade_out() -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -60.0, STEAL_FADE)
	_fade.tween_callback(_player.stop)


func _silence() -> void:
	if _fade:
		_fade.kill()
	_player.stop()
	_release(self)


static func _release(who: Node) -> void:
	_active = _active.filter(func(v: Array) -> bool: return v[0] != who)


static func _prune() -> void:
	_active = _active.filter(func(v: Array) -> bool: return is_instance_valid(v[0]) and v[0].is_inside_tree() and v[0]._player.playing)


## One of the NEAREST zombies to our camera (looked at every NEAREST_EVERY s, by whoever asks first).
func _is_near() -> bool:
	if _now() - _near_at >= NEAREST_EVERY:
		_near_at = _now()
		var cam := _camera(self)
		var living := _all.filter(func(v: Node) -> bool: return is_instance_valid(v) and not v.dead)
		living.sort_custom(func(a: Node, b: Node) -> bool: return _distance(a, cam) < _distance(b, cam))
		_near.clear()
		for v in living.slice(0, NEAREST):
			_near[v] = true
	return _near.has(self)


static func _alive() -> int:
	return _all.filter(func(v: Node) -> bool: return is_instance_valid(v) and not v.dead).size()


func _far() -> bool:
	var cam := _camera(self)
	return cam != null and cam.global_position.distance_to(global_position) > MOAN_RANGE


## The camera that hears `of`: its own viewport's.
static func _camera(of: Node) -> Camera3D:
	return of.get_viewport().get_camera_3d() if is_instance_valid(of) and of.is_inside_tree() else null


static func _distance(v: Node3D, cam: Camera3D) -> float:
	return cam.global_position.distance_to(v.global_position) if cam and is_instance_valid(v) and v.is_inside_tree() else 0.0


## Starts reading every bank off the disk on a thread: a bank loaded the first time it was needed
## held up that frame (tools/spike_probe.gd). waves.gd calls it with the hall.
static func warm() -> void:
	for bank: StringName in BANKS:
		var b: Array = BANKS[bank]
		for i in b[1]:
			var path := "%s%s%02d.ogg" % [b[2], b[0], i + 1]
			if not _streams.has(bank) and not _warming.has(path) and ResourceLoader.exists(path):
				_warming[path] = ResourceLoader.load_threaded_request(path) == OK


## Next sound of a bank from its shuffled bag; a fresh bag never starts with the one just played,
## and one heard in the last RECENT s (from any zombie) waits while the bag has another.
static func _draw(bank: StringName) -> AudioStream:
	if not _streams.has(bank):
		var b: Array = BANKS[bank]
		var list: Array[AudioStream] = []
		for i in b[1]:
			var path := "%s%s%02d.ogg" % [b[2], b[0], i + 1]
			if _warming.get(path, false):
				_warming[path] = false
				list.append(ResourceLoader.load_threaded_get(path))
			elif ResourceLoader.exists(path):
				list.append(load(path))
		_streams[bank] = list
	var list: Array = _streams[bank]
	if list.is_empty():
		return null
	var bag: Array = _bags.get(bank, [])
	if bag.is_empty():
		for i in list.size():
			bag.append(i)
		bag.shuffle()
		if bag.size() > 1 and bag[-1] == _last.get(bank, -1):
			bag.reverse()
		_bags[bank] = bag
	var t := _now()
	var pick := bag.size() - 1
	for k in range(bag.size() - 1, -1, -1):
		if t - _used.get(list[bag[k]], -RECENT) >= RECENT:
			pick = k
			break
	var i: int = bag.pop_at(pick)
	_last[bank] = i
	_used[list[i]] = t
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
			_shape(p, GORE_UNIT)
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
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = unit
	p.max_db = 0.0
	p.max_distance = MAX_DISTANCE
	p.attenuation_filter_cutoff_hz = FAR_CUTOFF  # far ones lose their edge
	p.attenuation_filter_db = FAR_FILTER_DB
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED


## The bus a pooled sound plays on: flesh on ZombiEt, a far crowd on PsUzak, a voice on Zombi.
static func _bank_bus(bank: StringName) -> StringName:
	_bus()
	if bank == &"distant" and AudioServer.get_bus_index(FAR_BUS) >= 0:
		return FAR_BUS
	return GORE_BUS if BANKS[bank][2] == GORE and AudioServer.get_bus_index(GORE_BUS) >= 0 else BUS


## The "Zombi" bus; ps1_sound.gd makes it (and ZombiEt) with the rest of the PS1 buses.
static func _bus() -> StringName:
	if AudioServer.get_bus_index(BUS) < 0:
		Ps1Sound.buses()
	return BUS


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
