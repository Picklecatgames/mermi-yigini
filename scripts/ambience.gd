extends Node
## The open ground's background (2026-11-03, the user: rebuild it for the open ground, list the
## recordings it lacks). `night` (false: day; the day and night cycle sets it, none yet): at night
## the crickets and the forest from all round, flat, at one level; the hum of the lit workshop lamp
## nearest the listener, only when standing under it, day or night; and a living night round the
## base (`EVENTS`): owls, a dormouse, wild pigs through the brush, a red deer roaring, each at its
## own natural, random interval, from a new direction, near or far, a passer-by moving as it
## sounds. By day nothing yet: wind, blowing sand and creaking sheet are the user's to bring
## (docs/ayrintilar.md, PS1 eleştirmeni turu 1); owls and crickets under the midday sun were
## wrong. The hall's "louder at a wall", its village and the mine cart inside are gone with the
## hall. Local decoration only, no sync.
## Beds hold nothing memorable, so their loop goes unnoticed; anything that stands out is a one-shot
## at random times, never in a loop (2026-10-24: the owl in the old 8 s night loop came round every
## 6.5 s, the user; 2026-10-25: a world that keeps changing, "half an hour on, something passes by
## on the left", the user).

const DIR := "res://assets/sounds/ambience/"
## Files are mastered to about -26 LUFS with seamless loops (2026-10-24), so these dB are the real mix.
# The hall had them faint through its walls (2026-10-24, the user: the crickets were far too loud
# and close); out in the open they sit at its "at a wall" level.
const NIGHT_DB := -37.0  # crickets
const FOREST_DB := -38.0  # the brush round the base, a touch under the crickets
const BED_EASE := 0.5  # 1/s: the beds fade in at dusk and out at dawn
# The night's events. Clips are cut from the user's recordings (wild/: Ivo Vicic, see docs) and
# normalised alike, so `db` sets them: each play picks a level in it, most often near the quiet
# end (far off), now and then loud (close by). [name, clips, seconds between, db quiet..loud,
# height m, sweep rad over the clip (0: stays put; a passer-by moves along the hall), inside]
const EVENTS := [
	["owl", ["owl_1", "owl_2", "owl_3", "owl_4", "owl_5", "wild/bigowl_1", "wild/bigowl_2", "wild/bigowl_3",
		"wild/bigowl_4", "wild/bigowl_5", "wild/bigowl_6", "wild/bigowl_7", "wild/bigowl_8"],
		Vector2(50.0, 160.0), Vector2(-44.0, -31.0), 9.0, 0.0, false],
	["dormouse", ["wild/dormouse_1", "wild/dormouse_2", "wild/dormouse_3", "wild/dormouse_4", "wild/dormouse_5"],
		Vector2(100.0, 260.0), Vector2(-46.0, -36.0), 3.0, 0.0, false],
	["pigs", ["wild/pigs_1", "wild/pigs_2", "wild/pigs_3", "wild/pigs_4", "wild/pigs_5"],
		Vector2(300.0, 720.0), Vector2(-44.0, -30.0), 0.5, 0.4, false],
	["deer", ["wild/deer_1", "wild/deer_2", "wild/deer_3", "wild/deer_4", "wild/deer_5"],
		Vector2(240.0, 600.0), Vector2(-42.0, -27.0), 2.0, 0.25, false],
]
const MAX_AT_ONCE := 2  # outside events sounding together; a third waits a little
const PITCH := 0.03  # each play up to 3 % higher or lower: the same clip is never quite the same
const HUM_DB := -19.0  # 2026-10-24: -8 was too loud next to a lamp (the user); file now 3 LU louder
const HUM_NEAR := 1.0  # m (on the floor) from a lamp's spot: full hum
const HUM_FAR := 3.5  # m: silent; lamps are 6-7 m apart, so between two it is gone
const HUM_EASE := 4.0  # 1/s: the hum swells and fades instead of snapping as you walk

var night := false
var _lamps: Array[Vector3] = []
var _outside: Array[AudioStreamPlayer] = []  # crickets, forest
var _hum: AudioStreamPlayer
var events: Array[Dictionary] = []  # per EVENTS row: player, wait, last clip, angle, sweep, started


func _ready() -> void:
	for file: String in ["night_outside.ogg", "forest_night.ogg"]:
		var bed := AudioStreamPlayer.new()  # flat: it is all round, not from somewhere
		bed.stream = _stream(file, true)
		bed.bus = &"Ambiyans"
		bed.volume_linear = 0.0
		bed.autoplay = true
		add_child(bed)
		_outside.append(bed)
	for light in get_node("../World/Lamps").find_children("*", "SpotLight3D", true, false):
		_lamps.append((light as Node3D).global_position)  # dead bulbs have no light, so no hum
	# Flat, not 3D: a source right overhead swung hard left-right with every step under the lamp.
	_hum = AudioStreamPlayer.new()
	_hum.stream = _stream("fluorescent.ogg", true)
	_hum.bus = &"AmbiyansYanki"  # Dunya's reverb, under the ambience slider (settings.gd)
	_hum.volume_linear = 0.0
	_hum.autoplay = true
	add_child(_hum)
	for e in EVENTS:
		var gap: Vector2 = e[2]
		var clips: Array[AudioStream] = []
		for c: String in e[1]:
			clips.append(_stream(c + ".ogg", false))
		# The first of each comes early enough to be heard soon, never all together.
		events.append({"row": e, "clips": clips, "player": _player("", -80.0, false), "last": -1,
			"wait": randf_range(gap.x * 0.15, gap.x * 0.8), "angle": 0.0, "sweep": 0.0, "length": 1.0})


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	var best_d := INF
	for l in _lamps:
		best_d = minf(best_d, Vector2(l.x - at.x, l.z - at.z).length())
	var target := db_to_linear(HUM_DB) * (1.0 - smoothstep(HUM_NEAR, HUM_FAR, best_d))
	_hum.volume_linear = lerpf(_hum.volume_linear, target, 1.0 - exp(-HUM_EASE * delta))
	for i in _outside.size():
		var to := db_to_linear([NIGHT_DB, FOREST_DB][i]) if night else 0.0
		_outside[i].volume_linear = lerpf(_outside[i].volume_linear, to, 1.0 - exp(-BED_EASE * delta))
	if night:
		_events(delta)


func _events(delta: float) -> void:
	var sounding := 0
	for ev in events:
		var p: AudioStreamPlayer3D = ev.player
		if p.playing and not ev.row[6]:
			sounding += 1
	for ev in events:
		var p: AudioStreamPlayer3D = ev.player
		var row: Array = ev.row
		if p.playing:
			if ev.sweep != 0.0:  # a passer-by: along its arc as the clip goes
				_place(p, ev.angle + ev.sweep * p.get_playback_position() / ev.length, row)
			continue
		ev.wait -= delta
		if ev.wait > 0.0:
			continue
		if not row[6] and sounding >= MAX_AT_ONCE:
			ev.wait = randf_range(8.0, 20.0)  # the night is busy: in a little while
			continue
		var gap: Vector2 = row[2]
		ev.wait = randf_range(gap.x, gap.y)
		var pick: int = randi() % ev.clips.size()
		if pick == ev.last and ev.clips.size() > 1:
			pick = (pick + 1) % ev.clips.size()
		ev.last = pick
		p.stream = ev.clips[pick]
		p.pitch_scale = randf_range(1.0 - PITCH, 1.0 + PITCH)
		var db: Vector2 = row[3]
		p.volume_db = lerpf(db.x, db.y, pow(randf(), 1.8))  # mostly far, now and then close
		ev.angle = randf() * TAU
		ev.sweep = float(row[5]) * (1.0 if randf() < 0.5 else -1.0)
		ev.length = maxf(p.stream.get_length(), 0.1)
		_place(p, ev.angle, row)
		p.play()
		if not row[6]:
			sounding += 1


## Puts an event's player at `angle` round the base: close by (26 m) or out in the dark (40 m).
func _place(p: AudioStreamPlayer3D, angle: float, row: Array) -> void:
	var r := 26.0 if row[6] else 40.0
	p.global_position = Vector3(cos(angle) * r, row[4], sin(angle) * r)


func _player(file: String, db: float, looped: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	if file:
		p.stream = _stream(file, looped)
	p.volume_db = db
	p.bus = &"Ambiyans"  # else it lands on Efekt and the ambience slider can't reach it
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED  # loudness set here, the source only gives direction
	p.autoplay = looped
	add_child(p)
	return p


func _stream(file: String, looped: bool) -> AudioStreamOggVorbis:
	var s := (load(DIR + file) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	s.loop = looped
	return s
