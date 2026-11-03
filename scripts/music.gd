extends Node
## The music (2026-11-03, the user: "dediğin vakitlerde çalacak şekilde, kafa sikmeyecek şekilde
## sesi kıs, PS1'e uygun hale getir, fazla bozmadan"). Net.gd adds it beside day_night.gd and it
## follows GameState's clock the same way. By day, now and then, one of the day's guitar pieces
## (assets/sounds/music/day_NN), never the same twice in a row, with a few minutes of nothing but
## the wind between; when dusk comes the day's piece fades out and the dusk drone (dusk_NN) plays
## once into the night. Nothing at night: the night has its own sounds. Flat, quiet, on the Muzik
## bus (its own slider in the pause menu). Local decoration, no sync. The gaps are first guesses.

const DB := -14.0  # under the world: the files are -23 LUFS (data/ses_duzeni.json muzik)
const FIRST_WAIT := Vector2(45.0, 120.0)  # s before the first piece of a day
const GAP := Vector2(120.0, 300.0)  # s of silence between pieces
const DUSK := 0.05  # GameState.night_of past which dusk has come
const FADE := 6.0  # s the day's piece takes to fade when dusk comes

var _player: AudioStreamPlayer
var _wait := 0.0
var _dusk_played := false
var _last := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # paused, it plays on, muffled like the rest
	_player = AudioStreamPlayer.new()
	_set_bus.call_deferred()  # Settings (an autoload after Net) makes the Muzik bus
	_player.volume_db = DB
	add_child(_player)
	_wait = randf_range(FIRST_WAIT.x, FIRST_WAIT.y)


func _set_bus() -> void:
	_player.bus = Ps1Sound.bus_of("muzik")


func _process(delta: float) -> void:
	var dark: float = GameState.night_of(GameState.hour)
	if dark > DUSK:
		if not _dusk_played:
			_dusk_played = true
			if dark < 0.9:  # not when a game starts (or a client joins) deep in the night
				_dusk()
		return
	if _dusk_played:  # morning: a new day, its first piece a while in
		_dusk_played = false
		_wait = randf_range(FIRST_WAIT.x, FIRST_WAIT.y)
	if _player.playing:
		return
	_wait -= delta
	if _wait <= 0.0:
		_play(_pick("muzik/day"), DB)
		_wait = randf_range(GAP.x, GAP.y)


func _dusk() -> void:
	if _player.playing:
		var t := create_tween()
		t.tween_property(_player, "volume_db", -60.0, FADE)
		await t.finished
	_play(_pick("muzik/dusk"), DB)


func _pick(what: String) -> String:
	var list := Ps1Sound.files(what).filter(func(p: String) -> bool: return p != _last)
	if list.is_empty():
		list = Ps1Sound.files(what)
	return "" if list.is_empty() else list[randi() % list.size()]


func _play(path: String, db: float) -> void:
	if path == "":
		return
	_last = path
	_player.stream = load(path)
	_player.volume_db = db
	_player.play()


## What plays now ("" if nothing), for tools/music_check.gd.
func playing() -> String:
	return _last if _player.playing else ""
