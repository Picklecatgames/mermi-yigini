extends Node
## Being watched from the wood (2026-11-06, the user: "ormanın tenhalığı, izlenme hissi, rastgele
## tıkırtılar, işte çalı sesi, ayak sesi, nadiren 'lan burada birisi mi var' gerilimi"). Now and
## then, out of sight among the trees, one thing: a few steps behind you in time with your own, the
## brush shifting, the crickets going quiet, a sound far off and then the same sound close by. Long
## silences between; rarer by day and out in the middle of the clearing, more often at the edge of
## the wood and in it; never the same thing twice running. Numbers are first guesses
## (docs/ayrintilar.md "Orman: izlenme hissi").
##
## The host picks what happens, when and to whom (all randomness here), and sends it only to that
## player (GameState.presence_to): the others hear nothing, "did you hear that too?". Each player has
## a tension, `presence_tension(peer)`, that every event raises and time lets down: the wave
## director (scripts/waves.gd) can read it, and `fired` says when something was heard.
##
## Sounds are recordings, never made in code (CLAUDE.md). The user's go in PRESENCE_DIR as
## `<kind>_NN.ogg|wav` (NN from 01) and are picked up on their own; till then the steps are the
## player's own (pitched down, muffled) and the brush is cut from the wild pigs' rustling
## (`cut_brush_NN`). See docs/ayrintilar.md for the list asked of the user.

signal fired(peer: int, kind: String)  # host: an event went out to `peer`

const PRESENCE_DIR := "res://assets/sounds/ambience/presence/"
const OWN_STEPS := "res://assets/characters/operator/sounds/step_%02d.wav"
const USER_KINDS := ["brush", "twig", "leafstep", "breath", "whisper"]
const MAX_FILES := 30
## The clearing the wood stands round: tools/build_world.gd CLEARING_CENTRE and _RADII (kept equal).
const CLEARING_CENTRE := Vector2(8.0, 0.0)
const CLEARING_RADII := Vector2(40.0, 34.0)
## How often (all first guesses; the user: "sürekli de tetiklenmesin, hani tadında kalsın her şey"):
## most of the time the wood is only quiet. At night at the wood's edge one event every MEAN_GAP s on
## average once the quiet after the last (MIN_GAP..MIN_GAP·QUIET_SPREAD, random) is over; by day
## DAY_SHARE of that; out in the open middle of the clearing MIDDLE_SHARE; inside the wood WOOD_SHARE.
## At most NIGHT_CAP a night and DAY_CAP a day for each player, and the close ones ("is somebody
## there?": steps right behind, breathing) SCARE_CAP a night, none by day.
const MEAN_GAP := 150.0
const MIN_GAP := 90.0
const QUIET_SPREAD := 2.2
const FIRST_GAP := 60.0  # s before anyone's first, so it never greets you on arrival
const NIGHT_CAP := 4
const DAY_CAP := 1
const SCARE_CAP := 1
const DAY_SHARE := 0.06
const MIDDLE_SHARE := 0.12
const WOOD_SHARE := 1.6
const EDGE_OUT := -6.0  # m out of the clearing's edge where the "edge" rate is full (in the open, near the trees)
const MIDDLE_OUT := -24.0  # m: the open middle from here in
const TENSION_FALL := 150.0  # s for the tension to fall to a third
## [kind, weight to be picked, tension it adds, needs night, needs these files (any)]
const KINDS := [
	["steps", 3.0, 0.35, false, []],
	["brush", 3.0, 0.2, false, []],
	["hush", 2.0, 0.25, true, []],
	["echo", 2.0, 0.3, false, []],
	["breath", 1.0, 0.5, true, ["breath"]],
	["whisper", 0.7, 0.4, true, ["whisper"]],
]
const SOURCE_HEIGHT := 0.3  # m: on the ground among the trees
const IN_WOOD := 3.0  # m out of the clearing's edge a source stands at least, when it can
const FARTHEST := 34.0  # m: a source never further than this, wood or no wood
const STEP_LAG := Vector2(0.12, 0.26)  # s behind each of yours
const STEP_WAIT := 14.0  # s it waits for you to walk; then a single step and nothing
const BUS := &"OrmanBoguk"  # muffled by the trees, under the ambience slider
const CUTOFF := 2600.0  # Hz

var clips := {}  # kind -> Array[AudioStream]
var _rng := RandomNumberGenerator.new()
## Host: per peer {wait, last, tension}.
var _peers := {}
var _shadow := {}  # the steps that follow ours: the cue, and {left, n, queue, prev, extra, waited}
var _body: Node  # the local player, for its steps
var _t := 0.0  # s, this machine's clock for the steps
var shadow_steps := 0  # steps the follower has taken, all told (presence_check)
var _players: Array[AudioStreamPlayer3D] = []
var _echo := {}  # the second half of an echo: {wait, cue}


func _ready() -> void:
	name = "ForestPresence"
	add_to_group("forest_presence")
	_rng.randomize()
	_load_clips()
	_bus()
	for i in 4:
		var p := AudioStreamPlayer3D.new()
		p.bus = BUS
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED  # loudness set here from the distance
		p.max_polyphony = 2
		add_child(p)
		_players.append(p)
	GameState.presence_cue.connect(_on_cue)


## What each kind plays: the user's recordings when there are any, else the stand-ins.
func _load_clips() -> void:
	for kind: String in USER_KINDS:
		clips[kind] = _numbered(PRESENCE_DIR + kind + "_%02d")
	var own: Array[AudioStream] = []
	for i in range(1, 16):
		if ResourceLoader.exists(OWN_STEPS % i):
			own.append(load(OWN_STEPS % i))
	clips.steps = clips.leafstep if not clips.leafstep.is_empty() else own
	var brush: Array = clips.brush if not clips.brush.is_empty() else _numbered(PRESENCE_DIR + "cut_brush_%02d")
	clips.rustle = brush + clips.twig
	clips.echo = clips.twig + clips.whisper if not (clips.twig + clips.whisper).is_empty() else brush


func _numbered(pattern: String) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for i in range(1, MAX_FILES + 1):
		for ext in [".ogg", ".wav"]:
			if ResourceLoader.exists(pattern % i + ext):
				out.append(load(pattern % i + ext))
				break
	return out


func _bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, &"Ambiyans")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = CUTOFF
	AudioServer.add_bus_effect(i, lp)


# --- host: when, what, to whom ---------------------------------------------------------------

## How tense `peer` is, 0 (nothing heard for a long while) to about 1 (one thing after another).
func presence_tension(peer: int) -> float:
	return _peers[peer].tension if _peers.has(peer) else 0.0


## Kinds the files allow (the same on every machine: one build).
func kinds_available() -> Array[String]:
	var out: Array[String] = []
	for k: Array in KINDS:
		var need: Array = k[4]
		if need.is_empty() or need.any(func(n: String) -> bool: return not clips[n].is_empty()):
			out.append(k[0])
	return out


## m out of the clearing's edge, negative inside it.
static func out_of_clearing(at: Vector3) -> float:
	var q := (Vector2(at.x, at.z) - CLEARING_CENTRE) / CLEARING_RADII
	return (q.length() - 1.0) * minf(CLEARING_RADII.x, CLEARING_RADII.y)


## Events a second for someone standing at `at` with the night at `dark` (0 day, 1 night).
static func rate(at: Vector3, dark: float) -> float:
	var out := out_of_clearing(at)
	var place := lerpf(MIDDLE_SHARE, 1.0, smoothstep(MIDDLE_OUT, EDGE_OUT, out))
	place = lerpf(place, WOOD_SHARE, smoothstep(EDGE_OUT, IN_WOOD + 4.0, out))
	return place * lerpf(DAY_SHARE, 1.0, dark) / MEAN_GAP


func _process(delta: float) -> void:
	if _body == null:
		_body = get_node_or_null("../../Player")
		if _body and _body.has_signal(&"stepped"):
			_body.stepped.connect(on_step)
	_play_shadow(delta)
	_play_echo(delta)
	if Net.is_client:
		return
	var here: Array[int] = [GameState.local_peer()]
	if Net.online:
		for id in multiplayer.get_peers():
			here.append(id)
	for id: int in _peers.keys():
		if id not in here:
			_peers.erase(id)
	var dark: float = GameState.night_of(GameState.hour)
	for id in here:
		var p = GameState.player(id)
		if not p.has_pose or p.down:
			continue
		tick(id, p.pos, p.yaw, dark, delta)


## Host: one player's clock. Returns the cue it sent, if any (the check calls it straight).
func tick(peer: int, at: Vector3, yaw: float, dark: float, delta: float) -> Dictionary:
	if not _peers.has(peer):
		_peers[peer] = {"wait": FIRST_GAP, "last": "", "tension": 0.0, "night": dark > 0.5, "count": 0, "scares": 0}
	var s: Dictionary = _peers[peer]
	if (dark > 0.5) != s.night:  # dusk or dawn: a new budget
		s.night = dark > 0.5
		s.count = 0
		s.scares = 0
	if s.count >= (NIGHT_CAP if s.night else DAY_CAP):
		s.tension *= exp(-delta / TENSION_FALL)
		return {}
	s.tension *= exp(-delta / TENSION_FALL)
	s.wait -= delta
	if s.wait > 0.0 or _rng.randf() >= rate(at, dark) * delta:
		return {}
	var cue := pick(peer, at, yaw, dark)
	if cue.is_empty():
		return {}
	s.wait = _rng.randf_range(MIN_GAP, MIN_GAP * QUIET_SPREAD)
	s.last = cue.kind
	s.count += 1
	if is_scare(cue):
		s.scares += 1
	for k: Array in KINDS:
		if k[0] == cue.kind:
			s.tension = minf(s.tension + k[2], 1.0)
	GameState.presence_to(peer, cue)
	fired.emit(peer, cue.kind)
	return cue


## The rare close one: steps right behind, or breathing.
static func is_scare(cue: Dictionary) -> bool:
	return cue.get("kind") == "breath" or cue.get("kind") == "steps" and cue.get("dist", 99.0) < 6.5


## Host: what `peer` hears now, never what it heard last.
func pick(peer: int, at: Vector3, yaw: float, dark: float) -> Dictionary:
	var s: Dictionary = _peers.get(peer, {"last": "", "tension": 0.0, "scares": 0})
	var scare_ok: bool = dark > 0.5 and s.get("scares", 0) < SCARE_CAP
	var can := kinds_available().filter(func(k: String) -> bool:
		if k == s.last:
			return false
		for row: Array in KINDS:
			if row[0] == k and row[3] and dark < 0.5:
				return false
		return k != "breath" or (scare_ok and s.tension > 0.4))  # breathing only once something is already about
	if can.is_empty():
		return {}
	var total := 0.0
	for row: Array in KINDS:
		if row[0] in can:
			total += row[1]
	var roll := _rng.randf() * total
	var kind: String = can[-1]
	for row: Array in KINDS:
		if row[0] in can:
			roll -= row[1]
			if roll <= 0.0:
				kind = row[0]
				break
	var tense: float = s.tension
	match kind:
		"steps":
			# Behind or beside, closer the tenser: now and then right there.
			var close := scare_ok and _rng.randf() < 0.1 + 0.3 * tense
			return {"kind": kind, "angle": PI + _rng.randf_range(-1.1, 1.1), "dist": _rng.randf_range(3.5, 6.0) if close else _rng.randf_range(7.0, 12.0),
				"count": _rng.randi_range(3, 6), "lag": _rng.randf_range(STEP_LAG.x, STEP_LAG.y), "db": _rng.randf_range(-31.0, -25.0),
				"pitch": _rng.randf_range(0.8, 0.92), "clips": _picks(clips.steps.size(), 8), "late": _rng.randf() < 0.8}
		"brush":
			var from := _in_wood(at, yaw, _rng.randf_range(9.0, 22.0))
			return {"kind": kind, "at": from, "drift": _rng.randf_range(-0.6, 0.6), "count": _rng.randi_range(1, 3),
				"apart": _rng.randf_range(0.6, 2.2), "db": _rng.randf_range(-34.0, -26.0), "pitch": _rng.randf_range(0.9, 1.05),
				"clips": _picks(clips.rustle.size(), 3)}
		"hush":
			return {"kind": kind, "down": _rng.randf_range(1.0, 2.0), "hold": _rng.randf_range(3.5, 7.0), "up": _rng.randf_range(2.5, 4.5),
				"depth": _rng.randf_range(-16.0, -10.0)}
		"echo":
			# Once far off, then the very same sound (same pitch: that is the tell) much closer.
			var far := _in_wood(at, yaw, _rng.randf_range(26.0, FARTHEST))
			var near := _in_wood(at, yaw, _rng.randf_range(8.0, 13.0))
			return {"kind": kind, "at": far, "near": near, "after": _rng.randf_range(5.0, 14.0), "db": _rng.randf_range(-38.0, -34.0),
				"near_db": _rng.randf_range(-28.0, -24.0), "pitch": _rng.randf_range(0.92, 1.04), "clips": _picks(clips.echo.size(), 1)}
		"breath":
			return {"kind": kind, "angle": PI + _rng.randf_range(-0.5, 0.5), "dist": _rng.randf_range(2.0, 3.5), "db": _rng.randf_range(-30.0, -24.0),
				"pitch": _rng.randf_range(0.95, 1.02), "clips": _picks(clips.breath.size(), 1)}
		"whisper":
			return {"kind": kind, "at": _in_wood(at, yaw, _rng.randf_range(14.0, 24.0)), "db": _rng.randf_range(-36.0, -30.0),
				"pitch": _rng.randf_range(0.96, 1.02), "clips": _picks(clips.whisper.size(), 1)}
	return {}


func _picks(n: int, count: int) -> Array[int]:
	var out: Array[int] = []
	var last := -1
	for i in count:
		var c := _rng.randi() % maxi(n, 1)
		if c == last and n > 1:
			c = (c + 1) % n
		out.append(c)
		last = c
	return out


## A spot out of sight (behind or beside the way `yaw` looks) about `dist` away, pushed back into the
## trees if it fell in the open, but never past FARTHEST.
func _in_wood(at: Vector3, yaw: float, dist: float) -> Vector3:
	var a := yaw + PI + _rng.randf_range(-1.9, 1.9)  # within 110° of straight behind
	var dir := Vector3(-sin(a), 0.0, -cos(a))  # yaw 0 looks down -Z
	var d := dist
	while d < FARTHEST and out_of_clearing(at + dir * d) < IN_WOOD:
		d += 1.0
	var p := at + dir * minf(d, FARTHEST)
	return Vector3(p.x, SOURCE_HEIGHT, p.z)


# --- every machine: play what the host sent us -----------------------------------------------

func _on_cue(peer: int, cue: Dictionary) -> void:
	if peer != GameState.local_peer():
		return
	play(cue)


func play(cue: Dictionary) -> void:
	match cue.get("kind", ""):
		"steps":
			_shadow = cue.duplicate()
			_shadow.left = int(cue.count)
			_shadow.waited = 0.0
			_shadow.queue = []  # s till each step owed
			_shadow.n = 0
			_shadow.prev = -1.0
			_shadow.extra = -1.0
		"brush":
			var at: Vector3 = cue.at
			for i in int(cue.count):
				_one_later(clips.rustle, cue.clips[i % cue.clips.size()], at + Vector3(cue.drift * i, 0, cue.drift * i * 0.5),
					cue.db - 2.0 * i, cue.pitch, cue.apart * i)
		"hush":
			var amb := get_parent()
			if amb and amb.has_method(&"hush"):
				amb.hush(cue.down, cue.hold, cue.up, cue.depth)
		"echo":
			_one(clips.echo, cue.clips[0], cue.at, cue.db, cue.pitch)
			_echo = {"wait": cue.after, "cue": cue}
		"breath":
			_one(clips.breath, cue.clips[0], _beside(cue.angle, cue.dist), cue.db, cue.pitch)
		"whisper":
			_one(clips.whisper, cue.clips[0], cue.at, cue.db, cue.pitch)


## The listener's own step (player.gd `stepped`): the steps that follow us answer a beat behind, and
## if this was our last, one more comes a stride later, after we have stopped.
func on_step() -> void:
	if _shadow.is_empty() or _shadow.left <= 0:
		return
	var stride := clampf(_t - _shadow.prev, 0.3, 0.7) if _shadow.prev >= 0.0 else 0.5
	_shadow.prev = _t
	var lag: float = _shadow.lag + _rng.randf_range(-0.03, 0.03)  # local jitter: only the timing
	_shadow.queue.append(lag)
	_shadow.extra = lag + stride * 1.1 if _shadow.late else -1.0  # gone if we step again first


func _play_shadow(delta: float) -> void:
	_t += delta
	if _shadow.is_empty():
		return
	var q: Array = _shadow.queue
	for i in q.size():
		q[i] -= delta
	while not q.is_empty() and q[0] <= 0.0:
		q.pop_front()
		_shadow_step()
	if _shadow.left <= 0 and q.is_empty():
		_shadow = {}  # it has stopped (before us)
		return
	_shadow.waited += delta
	if _shadow.extra > 0.0:
		_shadow.extra -= delta
		if _shadow.extra <= 0.0:  # we stopped; it took one step more, and now it is still too
			_shadow_step()
			_shadow = {}
	elif _shadow.n == 0 and _shadow.waited > STEP_WAIT:
		_shadow_step()  # we never walked: one shift of weight in the leaves, nothing more
		_shadow = {}


func _shadow_step() -> void:
	if _shadow.left <= 0:
		return
	_shadow.left -= 1
	shadow_steps += 1
	var i: int = _shadow.n
	_shadow.n += 1
	_one(clips.steps, _shadow.clips[i % _shadow.clips.size()], _beside(_shadow.angle, _shadow.dist), _shadow.db, _shadow.pitch)


func _play_echo(delta: float) -> void:
	if _echo.is_empty():
		return
	_echo.wait -= delta
	if _echo.wait <= 0.0:
		var cue: Dictionary = _echo.cue
		_echo = {}
		_one(clips.echo, cue.clips[0], cue.near, cue.near_db, cue.pitch)


## Where `angle` (from the way we look, PI straight behind) and `dist` put a sound round us now.
func _beside(angle: float, dist: float) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(0, SOURCE_HEIGHT, dist)
	var yaw := cam.global_rotation.y + angle
	var at := cam.global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * dist
	return Vector3(at.x, cam.global_position.y - 1.4, at.z)


func _one_later(pool: Array, pick: int, at: Vector3, db: float, pitch: float, after: float) -> void:
	if after <= 0.0:
		_one(pool, pick, at, db, pitch)
	else:
		get_tree().create_timer(after, false).timeout.connect(_one.bind(pool, pick, at, db, pitch))


func _one(pool: Array, pick: int, at: Vector3, db: float, pitch: float) -> void:
	if pool.is_empty():
		return
	var p: AudioStreamPlayer3D = _players[0]
	for q in _players:
		if not q.playing:
			p = q
			break
	p.stream = pool[pick % pool.size()]
	p.global_position = at
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
