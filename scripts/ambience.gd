extends Node
## The hall's background, every sound from a place in the hall so it turns as the listener turns:
## a low drone up in the roof, the night outside through the east and west walls, a forest
## through the loading door and the north wall, an iron creak from deep in the north-east corner,
## and the hum of the lit lamp nearest the listener, only when standing under it. None of them
## loops: each plays its recording in takes from random points, crossfaded into the next.
## Local decoration only, no sync.

const DIR := "res://assets/sounds/ambience/"
# [file, dB, where]: 2026-10-24, user: the mine creak quieter and always on, the forest as quiet as
# it can be; the night outside up a touch. South is +z (the loading door at x -6), east +x; the walls stand at +-28.
const BEDS := [
	["drone.mp3", -26.0, Vector3(-14, 7, -14)],
	["drone.mp3", -26.0, Vector3(14, 7, 14)],
	["night_outside.mp3", -27.0, Vector3(31, 4, -8)],
	["night_outside.mp3", -27.0, Vector3(-31, 4, 10)],
	["forest_night.mp3", -40.0, Vector3(-6, 1.5, 31)],
	["forest_night.mp3", -40.0, Vector3(12, 4, -31)],
	["mine_cart.mp3", -36.0, Vector3(24, 2, -24)],
]
const TAKE := Vector2(25.0, 50.0)  # s a take plays, cut shorter for a short recording
const FADE := 6.0  # s of crossfade between takes; a quarter of a short recording at most
const PITCH := 0.03  # each take a touch higher or lower, so a short recording does not repeat
const DISTANCE := 25.0  # m at which a bed plays at its dB: nearer is no louder, further is quieter
const BEHIND_DB := -5.0  # stereo cannot say front from back: a sound behind is quieter instead
const HUM_DB := -12.0
const HUM_NEAR := 1.0  # m (on the floor) from a lamp's spot: full hum
const HUM_FAR := 3.5  # m: silent; lamps are 6-7 m apart, so between two it is gone

var beds: Array[Bed] = []
var _lamps: Array[Vector3] = []
var _hum: Bed


func _ready() -> void:
	for b in BEDS:
		beds.append(_bed(b[0], b[1], b[2]))
	for light in get_node("../Arena/Lamps").find_children("*", "SpotLight3D", true, false):
		_lamps.append((light as Node3D).global_position)  # dead bulbs have no light, so no hum
	_hum = _bed("fluorescent.mp3", HUM_DB, Vector3.ZERO)
	for p in _hum.players:
		p.bus = &"AmbiyansYanki"  # the hall's reverb, under the Ambiyans slider (scripts/settings.gd)
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED  # the floor distance below sets it
	_hum.gain = 0.0


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	var best := Vector3.INF
	var best_d := INF
	for l in _lamps:
		var d := Vector2(l.x - at.x, l.z - at.z).length()
		if d < best_d:
			best_d = d
			best = l
	if best_d < INF:
		_hum.position = best
		_hum.gain = 1.0 - smoothstep(HUM_NEAR, HUM_FAR, best_d)
	var ahead := -cam.global_basis.z
	for b in beds + [_hum]:
		b.behind = clampf(-ahead.dot((b.global_position - at).normalized()), 0.0, 1.0)
		b.step(delta)


func _bed(file: String, db: float, at: Vector3) -> Bed:
	var b := Bed.new(load(DIR + file), db)
	b.position = at
	add_child(b)
	return b


## One sound at one place: two players taking turns, each take from a random point of the
## recording and faded into the next before the recording runs out.
class Bed extends Node3D:
	var players: Array[AudioStreamPlayer3D] = []
	var db: float
	var gain := 1.0  # the owner's own fade (the lamp hum)
	var behind := 0.0  # 0 the listener faces it, 1 it is right behind
	var _len: float
	var _fade: float
	var _on := 0  # the player of the current take
	var _left := 0.0  # s until the current take starts fading out
	var _mix := [0.0, 0.0]  # each player's place in its crossfade: the first take fades in too

	func _init(stream: AudioStream, p_db: float) -> void:
		db = p_db
		_len = stream.get_length()
		_fade = minf(FADE, _len * 0.25)
		for i in 2:
			var p := AudioStreamPlayer3D.new()
			p.stream = stream  # imported with loop off: a take never reaches the end anyway
			p.unit_size = DISTANCE
			p.max_db = 0.0
			p.attenuation_filter_cutoff_hz = 20500.0  # no muffling with distance: the hall is not that big
			p.bus = &"Ambiyans"
			players.append(p)
			add_child(p)

	func _ready() -> void:
		_take()

	## The other player starts a new take from somewhere else; the current one fades out.
	func _take() -> void:
		_on = 1 - _on
		var take := minf(randf_range(TAKE.x, TAKE.y), _len - _fade * 2.0)
		var p := players[_on]
		p.pitch_scale = 1.0 + randf_range(-PITCH, PITCH)
		p.play(randf_range(0.0, _len - (take + _fade) * (1.0 + PITCH)))
		_left = take

	func step(delta: float) -> void:
		_left -= delta
		if _left <= 0.0:
			_take()
		for i in 2:
			var to := 1.0 if i == _on else 0.0
			_mix[i] = move_toward(_mix[i], to, delta / _fade)
			var p := players[i]
			if _mix[i] <= 0.0:
				p.stop()
				continue
			p.volume_db = db + BEHIND_DB * Settings.rear_cue() * behind + linear_to_db(maxf(_mix[i] * gain, 0.0001))
