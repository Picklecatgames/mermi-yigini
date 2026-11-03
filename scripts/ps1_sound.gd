class_name Ps1Sound
extends RefCounted
## The PS1 sound rules (docs/ayrintilar.md "PS1 ses düzeni"; the table is data/ses_duzeni.json,
## which tools/ses_ekle.py reads too). The folder a file sits in is its kind, and the kind says the
## bus, how much each play wanders in pitch and level, and how many may sound at once. Like the
## PS1's sound chip there are only `voices` (24) at once: a new one past the limit takes the
## oldest one's voice, the way a PS1 game keyed off its oldest note.
##   Ps1Sound.play("gore/flesh", self)                  # a random flesh_NN, never the last one
##   Ps1Sound.play("dunya/sac_tink", get_parent(), hit)  # at a point in the world
##   Ps1Sound.bed("ortam_yatak/wind_day", self)         # a loop, flat, on Ambiyans
## Recordings only (the user's rule): this plays and shapes them, it never makes a sound.

const TABLE := "res://data/ses_duzeni.json"
const ROOT := "res://assets/"
const EXT := ["ogg", "wav", "mp3"]

## The buses made here, after the PS1 chip's reverb presets (psx-spx "SPU Reverb"): a small room
## for the workshop ("Room"), a dark, late echo off the junk mountain for the open land ("Space
## Echo" in spirit), a dull, wet hall for far calls ("Hall" through a low-pass). Arayuz is dry.
## [name, send, room, damping, predelay ms, predelay feedback, wet, hipass, low-pass Hz (0: none)]
const BUSES := [
	[&"PsOda", &"Efekt", 0.25, 0.55, 12.0, 0.1, 0.18, 0.2, 0.0],
	[&"PsAcik", &"Efekt", 0.5, 0.7, 140.0, 0.35, 0.12, 0.3, 0.0],
	[&"PsUzak", &"Ambiyans", 0.8, 0.6, 60.0, 0.2, 0.3, 0.2, 2200.0],
	[&"Arayuz", &"Efekt", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
]

static var _table: Dictionary = {}
static var _files: Dictionary = {}  # "kind/prefix" -> [paths]
static var _last: Dictionary = {}  # "kind/prefix" -> the path played last
static var _live: Array = []  # [player, kind], oldest first


static func table() -> Dictionary:
	if _table.is_empty():
		_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	return _table


static func kind(name: String) -> Dictionary:
	return table().kinds.get(name, {})


## Makes the buses above if they aren't there yet (settings.gd calls it with its own). The kinds'
## other buses belong to their own scripts (Silah: viewmodel.gd, Zombi: zombie_voice.gd, Adim and
## Ambiyans: the layout and settings.gd); a kind whose bus isn't made yet plays on Efekt.
static func buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b[0]) >= 0:
			continue
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, b[0])
		AudioServer.set_bus_send(i, b[1] if AudioServer.get_bus_index(b[1]) >= 0 else &"Master")
		if b[8] > 0.0:
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = b[8]
			AudioServer.add_bus_effect(i, lp)
		if b[6] > 0.0:
			var r := AudioEffectReverb.new()
			r.room_size = b[2]
			r.damping = b[3]
			r.predelay_msec = b[4]
			r.predelay_feedback = b[5]
			r.wet = b[6]
			r.hipass = b[7]
			r.dry = 1.0
			r.spread = 0.5  # narrow: the PS1 mixed close to mono
			AudioServer.add_bus_effect(i, r)


static func bus_of(kind_name: String) -> StringName:
	buses()
	var b := StringName(kind(kind_name).get("bus", "Efekt"))
	if b == &"Zombi" and AudioServer.get_bus_index(b) < 0:
		b = load("res://scripts/zombie_voice.gd")._bus()
	return b if AudioServer.get_bus_index(b) >= 0 else &"Efekt"


## Every file of "kind/prefix": prefix_NN (or the prefix itself); "kind" alone is the whole folder.
static func files(what: String) -> Array:
	if _files.has(what):
		return _files[what]
	var parts := what.split("/", true, 1)
	var k := kind(parts[0])
	var found: Array = []
	if not k.is_empty():
		var dir: String = ROOT + k.dir + "/"
		var prefix: String = parts[1] if parts.size() > 1 else ""
		for f in ResourceLoader.list_directory(dir):
			if f.get_extension() not in EXT:
				continue
			var base := f.get_basename()
			if prefix == "" or base == prefix or (base.begins_with(prefix + "_") and base.trim_prefix(prefix + "_").is_valid_int()):
				found.append(dir + f)
	found.sort()
	_files[what] = found
	return found


## One play of "kind/prefix". at: a world point (3D, under parent), or null: following parent if
## it is a Node3D, flat otherwise. db is added to the file's own level. Returns the player (freed
## when done), or null when there is no such file.
static func play(what: String, parent: Node, at: Variant = null, db := 0.0) -> Node:
	var list := files(what)
	if list.is_empty():
		push_warning("Ps1Sound: no file for %s" % what)
		return null
	var path: String = list[randi() % list.size()]
	if list.size() > 1:
		while path == _last.get(what, ""):
			path = list[randi() % list.size()]
	_last[what] = path
	var kind_name := what.get_slice("/", 0)
	var k := kind(kind_name)
	var p: Node
	if at is Vector3 or parent is Node3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 4.0
		p3.max_distance = 90.0
		p3.attenuation_filter_cutoff_hz = 5000.0  # far ones lose their edge
		p3.attenuation_filter_db = -12.0
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p = p3
	else:
		p = AudioStreamPlayer.new()
	p.stream = load(path)
	p.bus = bus_of(kind_name)
	p.pitch_scale = 1.0 + randf_range(-1.0, 1.0) * float(k.get("perde", 0.0))
	p.volume_db = db + randf_range(-1.0, 1.0) * float(k.get("duzey", 0.0))
	_take_voice(kind_name, int(k.get("ses", 4)))
	parent.add_child(p)
	if at is Vector3:
		(p as Node3D).global_position = at
	p.finished.connect(p.queue_free)
	p.play()
	_live.append([p, kind_name])
	return p


## A bed: looped, flat (it is all around), on the kind's bus. Not counted against the voices.
static func bed(what: String, parent: Node, db := 0.0) -> AudioStreamPlayer:
	var list := files(what)
	if list.is_empty():
		push_warning("Ps1Sound: no file for %s" % what)
		return null
	var p := AudioStreamPlayer.new()
	var s: AudioStream = load(list[0])
	if &"loop" in s:
		s.set(&"loop", true)
	p.stream = s
	p.bus = bus_of(what.get_slice("/", 0))
	p.volume_db = db
	parent.add_child(p)
	p.play()
	return p


## How many of our one-shots sound now (all kinds, or one).
static func sounding(kind_name := "") -> int:
	_prune()
	return _live.filter(func(v: Array) -> bool: return kind_name == "" or v[1] == kind_name).size()


static func _take_voice(kind_name: String, kind_max: int) -> void:
	_prune()
	var mine := _live.filter(func(v: Array) -> bool: return v[1] == kind_name)
	if mine.size() >= kind_max:
		_stop(mine[0])
	elif _live.size() >= int(table().voices):
		_stop(_live[0])


static func _stop(v: Array) -> void:
	_live.erase(v)
	(v[0] as Node).queue_free()


static func _prune() -> void:
	_live = _live.filter(func(v: Array) -> bool: return is_instance_valid(v[0]) and not (v[0] as Node).is_queued_for_deletion() and v[0].playing)
