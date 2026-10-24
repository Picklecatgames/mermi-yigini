extends Node3D
## The Clone blueprint opened on the bench (2026-10-24, the user's scene): the round lying here
## rises slowly, trembling a little, and stands up; it starts to shake and only then the sound
## comes in; the shake gets faster and tighter, and the moment it's down to nothing a second round
## slides out of it; once the sound has died out the two drop, as if let go, and fall over on the
## top. Timed to its sound (assets/sounds/recipes/clone.wav, measured): the glitches
## on its bursts, the dead stop on its 40 ms of silence, the split on the zap.
## The split goes along this node's X. play() starts it over; pose(t) is the whole animation.

const SOUND := preload("res://assets/sounds/recipes/clone.wav")
const BULLET := preload("res://assets/bullet/bullet_9mm.glb")
const SCALE := 0.03  # pile.gd BULLET_SCALE: the model is ~2.9 units long, ~1 thick, tip at +X
const RISE := 1.6  # s, the silent lift off the top
const SOUND_AT := RISE + 0.3  # s, the sound comes in once the shake has started
const STOP := SOUND_AT + 2.795  # s, the sound goes silent: the shake is down to nothing
const SPLIT := SOUND_AT + 2.845  # s, the zap
const SPREAD := 0.35  # s for the two rounds to slide apart
const RELEASE := SOUND_AT + 5.8  # s, the sound has died out: they drop, as if let go (the user's call)
const HOVER := 0.12  # m from the top to the round's middle
const REST := 1.4576 * SCALE  # m, a round's middle standing on its base
const FALL := sqrt(2.0 * (HOVER - REST) / 9.8)  # s, dropped from the hover to the top, ~0.15
const TOPPLE := 0.32  # s from landing on its base to lying on its side
const YAWS := [2.5, -0.5]  # rad, which way each one falls over: away from the other
const LAGS := [0.0, 0.07]  # s each one lets go after RELEASE: two knocks, not one
const WIDEN := 0.6  # m each knock is heard out to its own side, past where its round lies
const END := RELEASE + LAGS[1] + FALL + TOPPLE + 0.9  # s, settled
## Per round: its base hitting the top, then its side with the rattle after (two of the six drops
## in smokinghotdog's "Metal Object Falling", split there and pitched up 1.5x: a small round, not the recording's big piece).
const LANDS := [
	[preload("res://assets/sounds/recipes/land_base_1.wav"), preload("res://assets/sounds/recipes/land_side_1.wav")],
	[preload("res://assets/sounds/recipes/land_base_2.wav"), preload("res://assets/sounds/recipes/land_side_2.wav")],
]
const GAP := 0.05  # m between the two rounds once apart
const TREMBLE := 0.0007  # m, the uneasy wobble while it rises
const SHAKE := 0.004  # m at its widest, as it starts
const GLITCHES := [SOUND_AT + 2.05, SOUND_AT + 2.40, SOUND_AT + 2.55]  # s, the sound's bursts: the twin shows through
const GLITCH := 0.05  # s each

var _t := END
var _a: Node3D
var _b: Node3D
var _sound := AudioStreamPlayer3D.new()
var _knocks: Array[AudioStreamPlayer3D] = []  # one per round, at it when it hits


func _ready() -> void:
	_a = BULLET.instantiate()
	_b = BULLET.instantiate()
	add_child(_a)
	add_child(_b)
	_sound.stream = SOUND
	_sound.bus = &"Dunya"
	_sound.unit_size = 4.0
	_sound.position.y = HOVER
	add_child(_sound)
	for i in 2:
		var k := AudioStreamPlayer3D.new()
		k.bus = &"Dunya"
		k.unit_size = 2.0
		k.volume_db = -8.0 - 1.5 * i  # a small round on wood, under the clone sound
		k.pitch_scale = [0.9, 1.12][i]  # the two don't ring the same (the user's call: you hear two)
		k.panning_strength = 3.0  # 5 cm apart is no stereo at all; with WIDEN, left and right
		add_child(k)
		_knocks.append(k)
	_show(0.0)


func play() -> void:
	_t = 0.0
	_sound.stop()
	_show(0.0)


func _exit_tree() -> void:
	_sound.stop()  # freed while playing, its playback would outlive it
	for k in _knocks:
		k.stop()


func _process(delta: float) -> void:
	if _t >= END:
		return
	var was := _t
	_t = minf(_t + delta, END)
	if was < SOUND_AT and _t >= SOUND_AT:
		_sound.play(_t - SOUND_AT)
	for i in 2:
		var base: float = RELEASE + LAGS[i] + FALL
		for j in 2:  # its base on the top, then its side
			var hit := base + TOPPLE * j
			if was < hit and _t >= hit:
				_knocks[i].position = pose(hit)[i].origin + Vector3((-1.0 if i == 0 else 1.0) * WIDEN, 0.0, 0.0)
				_knocks[i].stream = LANDS[i][j]
				_knocks[i].play()
	_show(_t)


func _show(t: float) -> void:
	var p := pose(t)
	_a.transform = p[0]
	_b.transform = p[1]
	_b.visible = t >= SPLIT or _glitching(t)


## Both rounds at `t` s, in this node's space. The second sits inside the first until the split.
func pose(t: float) -> Array[Transform3D]:
	var up := Basis(Vector3.BACK, PI / 2.0)  # +X, the tip, turned to +Y
	if t < RISE:
		var k := t / RISE
		var lift := k * k * (3.0 - 2.0 * k)  # slow off the top, slow into the hover
		var turn := clampf((k - 0.25) / 0.6, 0.0, 1.0)  # leaves the top flat, stands up on the way
		turn = turn * turn * (3.0 - 2.0 * turn)
		var lying := Vector3(0.0, 0.5 * SCALE, 0.0)
		var at := lying.lerp(Vector3(0.0, HOVER, 0.0), lift)
		var amp := TREMBLE * minf(t / 0.3, 1.0)  # not yet on the top itself
		at += amp * Vector3(sin(t * 41.0) + 0.5 * sin(t * 73.0), 0.3 * sin(t * 57.0), cos(t * 37.0))
		var basis := Basis.IDENTITY.slerp(up, turn) * Basis.from_euler(amp * 8.0 * Vector3(sin(t * 29.0), 0.0, cos(t * 47.0)))
		var pose_at := Transform3D(basis.scaled(Vector3.ONE * SCALE), at)
		return [pose_at, pose_at]
	var mid := Vector3(0.0, HOVER, 0.0)
	if t < SPLIT:
		var tilt := Vector3.ZERO
		if t < STOP:
			# Faster and tighter: 9 Hz -> 60 Hz while the swing closes in to nothing.
			var d := STOP - RISE
			var k := (t - RISE) / d
			var phase := TAU * (9.0 * (t - RISE) + 51.0 * d * k * k * k / 3.0)
			var amp := lerpf(TREMBLE, SHAKE, minf(k / 0.12, 1.0)) * pow(1.0 - k, 1.5)  # grows out of the tremble
			mid += amp * Vector3(sin(phase), 0.3 * sin(phase * 1.7 + 1.0), cos(phase * 1.31))
			tilt = amp * 6.0 * Vector3(cos(phase * 1.13), 0.0, sin(phase * 0.87))
		var shook := Transform3D(Basis.from_euler(tilt) * up.scaled(Vector3.ONE * SCALE), mid)
		if _glitching(t):  # snapped to one side, the twin on the other: no easing, it jumps
			var side := Vector3(0.35 * GAP if int(t * 60.0) % 2 == 0 else -0.35 * GAP, 0.0, 0.0)
			return [shook.translated(-side), shook.translated(side)]
		return [shook, shook]
	if t >= RELEASE:
		return [_drop(t - RELEASE - LAGS[0], 0), _drop(t - RELEASE - LAGS[1], 1)]
	var s := t - SPLIT
	var k := minf(s / SPREAD, 1.0)
	var out := 1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)  # ease out, overshooting a little
	var kick := Vector3(0.0, 0.006 * exp(-10.0 * s) + 0.002 * sin(TAU * 0.8 * s), 0.0)  # pushed up, then bobbing
	var lean := 0.14 * exp(-7.0 * s) * cos(14.0 * s)  # the two lean apart, then settle upright
	var scaled := up.scaled(Vector3.ONE * SCALE)
	var side := Vector3(0.5 * GAP * out, 0.0, 0.0)
	return [
		Transform3D(Basis(Vector3.BACK, lean) * scaled, mid + kick - side),
		Transform3D(Basis(Vector3.BACK, -lean) * scaled, mid + kick + side),
	]


## The `i`th round `s` s after it's let go: falling free, landing on its base with a hop,
## tipping over away from the other one (YAWS[i]) and rocking to rest on its side.
# ponytail: same fall as clone_fx_drop.gd _drop; keep one once a take is picked.
func _drop(s: float, i: int) -> Transform3D:
	s = maxf(s, 0.0)  # not let go yet
	var up := Basis(Vector3.BACK, PI / 2.0)
	var yaw := Basis(Vector3.UP, YAWS[i])
	var away: Vector3 = yaw * Vector3.RIGHT  # where its tip ends up
	var base := Vector3((-0.5 if i == 0 else 0.5) * GAP, 0.0, 0.0)
	var shape := Basis.from_scale(Vector3.ONE * SCALE)
	if s < FALL:  # free fall, already starting to lean
		var lean := 0.12 * s / FALL
		return Transform3D(yaw * up.slerp(Basis.IDENTITY, lean / (PI / 2.0)) * shape, base + Vector3(0.0, HOVER - 4.9 * s * s, 0.0))
	var u := s - FALL
	var k := minf(u / TOPPLE, 1.0)
	var tip := lerpf(0.12, PI / 2.0, k * k)  # falling over gets faster, like a pushed bottle
	var basis := yaw * up.slerp(Basis.IDENTITY, tip / (PI / 2.0))
	# Pivoting on its bottom edge, r out from its axis: the middle swings out and down that way.
	var r := 0.5 * SCALE
	var at := base + away * (r - r * cos(tip) + REST * sin(tip)) + Vector3(0.0, r * sin(tip) + REST * cos(tip), 0.0)
	at.y += 0.004 * exp(-18.0 * u) * absf(sin(u * 30.0))  # the hop as the base hits
	var after := u - TOPPLE
	if after > 0.0:  # down on its side: a bounce and a rock
		at.y += 0.003 * exp(-10.0 * after) * absf(sin(after * 22.0))
		basis = basis * Basis(Vector3.RIGHT, 0.15 * exp(-5.0 * after) * sin(after * 15.0))
	return Transform3D(basis * shape, at)


func _glitching(t: float) -> bool:
	for g: float in GLITCHES:
		if t >= g and t < g + GLITCH:
			return true
	return false
