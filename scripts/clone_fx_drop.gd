extends Node3D
## The Clone opening on the bass stutter drop (assets/sounds/recipes/clone_drop.wav), as the user
## laid it out (2026-10-24): the round rises off the top on its own, in silence. Then the sound;
## on its first bass hit the round lurches left, on the second right, as if the one inside were
## trying to get out. In the gap before the sub bass it splits down the middle, and the sub bass
## throws the halves apart. They hang there shivering, and the moment the sound is over they drop
## as if let go: falling free, hitting the top on their bases and falling over onto their sides.
## Sound times are measured (sub-bass envelope). The split goes along this node's X.
## play() starts it over; pose(t) is the whole animation.

const SOUND := preload("res://assets/sounds/recipes/clone_drop.wav")
const BULLET := preload("res://assets/bullet/bullet_9mm.glb")
const SCALE := 0.03  # pile.gd BULLET_SCALE: the model is ~2.9 units long, ~1 thick, tip at +X
const RISE := 1.6  # s, the silent lift off the top
const SOUND_AT := RISE + 0.3  # s, the sound comes in once it hangs there
const KICK_1 := SOUND_AT + 0.63  # s, the first loud bass hit starts (its peak is ~90 ms later): it jumps up left, sparking
const KICK_2 := SOUND_AT + 1.03  # s, the second: up right
const JUMP_1 := Vector3(-0.022, 0.016, 0.0)  # m, where each hit throws it from the hover
const JUMP_2 := Vector3(0.022, 0.016, 0.0)
const SPLIT := SOUND_AT + 1.20  # s, splitting while the second hit dies away into the gap
const SUB := SOUND_AT + 1.335  # s, the sub bass comes in out of the silence: thrown apart
const CUT := SOUND_AT + 3.55  # s, the drop cuts off, the tail is quieter
const RELEASE := SOUND_AT + 9.6  # s, the sound has died out: let go (the user's call), they drop
const HOVER := 0.12  # m from the top to the round's middle
const REST := 1.4576 * SCALE  # m, a round's middle standing on its base
const FALL := sqrt(2.0 * (HOVER - REST) / 9.8)  # s, dropped from the hover to the top, ~0.15
const TOPPLE := 0.32  # s from landing on its base to lying on its side
const END := RELEASE + FALL + TOPPLE + 0.9  # s, settled
const GAP := 0.05  # m between the two once apart
const YAWS := [2.5, -0.5]  # rad, which way each one falls over: away from the other

var _t := END
var _a: Node3D
var _b: Node3D
var _sound := AudioStreamPlayer3D.new()
var _sparks: Array[CPUParticles3D] = []  # one burst per hit


func _ready() -> void:
	_a = BULLET.instantiate()
	_b = BULLET.instantiate()
	add_child(_a)
	add_child(_b)
	var streak := BoxMesh.new()  # stretched along its flight
	streak.size = Vector3(0.0012, 0.01, 0.0012)
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.vertex_color_use_as_albedo = true
	hot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.material = hot
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.7))
	fade.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	for jump: Vector3 in [JUMP_1, JUMP_2]:
		var s := CPUParticles3D.new()
		s.emitting = false
		s.one_shot = true
		s.amount = 30
		s.lifetime = 0.45
		s.explosiveness = 1.0
		s.local_coords = false
		s.mesh = streak
		s.direction = jump.normalized()
		s.spread = 35.0
		s.initial_velocity_min = 0.5
		s.initial_velocity_max = 1.5
		s.gravity = Vector3(0.0, -5.0, 0.0)
		s.particle_flag_align_y = true
		s.color_ramp = fade
		add_child(s)
		_sparks.append(s)
	_sound.stream = SOUND
	_sound.bus = &"Dunya"
	_sound.unit_size = 4.0
	_sound.position.y = HOVER
	add_child(_sound)
	_show(0.0)


func play() -> void:
	_t = 0.0
	_sound.stop()
	_show(0.0)


func _exit_tree() -> void:
	_sound.stop()  # freed while playing, its playback would outlive it


func _process(delta: float) -> void:
	if _t >= END:
		return
	var was := _t
	_t = minf(_t + delta, END)
	if was < SOUND_AT and _t >= SOUND_AT:
		_sound.play(_t - SOUND_AT)
	for i in 2:
		var kick: float = [KICK_1, KICK_2][i]
		if was < kick and _t >= kick:  # sparks off the round's side, the way it jumps
			_sparks[i].position = Vector3(0.0, HOVER, 0.0) + [JUMP_1, JUMP_2][i].normalized() * 0.4 * SCALE
			_sparks[i].restart()
	_show(_t)


func _show(t: float) -> void:
	var p := pose(t)
	_a.transform = p[0]
	_b.transform = p[1]
	_b.visible = t >= SPLIT


## Both rounds at `t` s, in this node's space. The second sits inside the first until the split.
func pose(t: float) -> Array[Transform3D]:
	var up := Basis(Vector3.BACK, PI / 2.0)  # +X, the tip, turned to +Y
	var mid := Vector3(0.0, HOVER, 0.0)
	if t < RISE:  # off the top on its own, standing up on the way, a little unsteady
		var k := _ease(t / RISE)
		var turn := _ease(clampf((t / RISE - 0.2) / 0.6, 0.0, 1.0))
		var sway := 0.04 * sin(t * 5.0) * sin(PI * t / RISE)
		var basis := Basis(Vector3.BACK, sway) * Basis.IDENTITY.slerp(up, turn)
		var one := Transform3D(basis * _size(1.0), Vector3(0.0, lerpf(0.5 * SCALE, HOVER, k), 0.0))
		return [one, one]
	if t < SPLIT:
		# Hanging there; the riser's stutter makes it hum, then each hit snaps it up to one side,
		# leaning that way and shuddering, as if the one inside were kicking.
		var j := _jump(t)
		var hum := 0.0006 * clampf((t - SOUND_AT) / 0.7, 0.0, 1.0) * sin(t * 190.0)
		var shudder := 0.0
		for kick: float in [KICK_1, KICK_2]:
			if t >= kick:
				shudder += 0.0015 * exp(-14.0 * (t - kick)) * sin((t - kick) * 160.0)
		var at := mid + j + Vector3(hum + shudder, 0.0, 0.0)
		var one := Transform3D(Basis(Vector3.BACK, -9.0 * j.x) * up * _size(1.0), at)
		return [one, one]
	if t < SUB:  # splitting down the middle: both thin at the seam, pulling apart, settling back
		var k := _ease((t - SPLIT) / (SUB - SPLIT))
		var side := Vector3(0.18 * GAP * k, 0.0, 0.0)
		var j := _jump(t)
		var shape := Basis(Vector3.BACK, -9.0 * j.x) * up * _size(1.0, 1.0 - 0.3 * sin(PI * minf(k * 1.3, 1.0)))
		return [Transform3D(shape, mid + j - side), Transform3D(shape, mid + j + side)]
	if t < RELEASE:  # thrown apart by the sub bass, then shivering in the air
		var s := t - SUB
		var k := minf(s / 0.3, 1.0)
		var out := 0.36 + 0.64 * (1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0))  # overshooting a little
		var side := Vector3(0.5 * GAP * out, 0.0, 0.0)
		var flung := 0.22 * exp(-6.0 * s) * cos(11.0 * s)  # tops out, then upright
		var lift := Vector3(0.0, 0.007 * exp(-8.0 * s) + 0.0015 * sin(TAU * 0.6 * s), 0.0)
		var shiver := 0.0011 if t < CUT else 0.0004  # the drop, then its quieter tail
		var pa := mid + lift - side + shiver * Vector3(sin(t * 211.0), 0.4 * sin(t * 157.0), cos(t * 173.0))
		var pb := mid + lift + side + shiver * Vector3(sin(t * 197.0 + 1.0), 0.4 * sin(t * 149.0 + 2.0), cos(t * 181.0 + 3.0))
		return [
			Transform3D(Basis(Vector3.BACK, flung) * up * _size(1.0), pa),
			Transform3D(Basis(Vector3.BACK, -flung) * up * _size(1.0), pb),
		]
	return [_drop(t - RELEASE, 0), _drop(t - RELEASE, 1)]


## The `i`th round `s` s after it's let go: falling free, landing on its base with a hop,
## tipping over away from the other one (YAWS[i]) and rocking to rest on its side.
func _drop(s: float, i: int) -> Transform3D:
	var up := Basis(Vector3.BACK, PI / 2.0)
	var yaw := Basis(Vector3.UP, YAWS[i])
	var away: Vector3 = yaw * Vector3.RIGHT  # where its tip ends up
	var base := Vector3((-0.5 if i == 0 else 0.5) * GAP, 0.0, 0.0)
	if s < FALL:  # free fall, already starting to lean
		var lean := 0.12 * s / FALL
		return Transform3D(yaw * up.slerp(Basis.IDENTITY, lean / (PI / 2.0)) * _size(1.0), base + Vector3(0.0, HOVER - 4.9 * s * s, 0.0))
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
	return Transform3D(basis * _size(1.0), at)


## Scale for a round `long` times its length and `wide` times its width.
func _size(long: float, wide := -1.0) -> Basis:
	if wide < 0.0:
		wide = long
	return Basis.from_scale(Vector3(long, wide, wide) * SCALE)


## Off the hover at `t`: snapped up left by the first hit, across to up right by the second, then
## drifting back to the middle by the sub bass.
func _jump(t: float) -> Vector3:
	if t < KICK_1:
		return Vector3.ZERO
	var snap := func(s: float) -> float: return 1.0 - exp(-45.0 * s)  # there in ~50 ms
	if t < KICK_2:
		return JUMP_1 * snap.call(t - KICK_1)
	var j := JUMP_1.lerp(JUMP_2, snap.call(t - KICK_2))
	return j * clampf(1.0 - (t - KICK_2 - 0.08) / (SUB - KICK_2 - 0.08), 0.0, 1.0)


func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)
