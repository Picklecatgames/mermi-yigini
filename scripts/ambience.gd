extends Node
## The hall's background: a low drone and the night outside, always on and quiet; a mine cart
## somewhere in the building now and then, barely heard; and the hum of the lit lamp nearest the
## listener, only when standing under it. Local decoration only, no sync.

const DIR := "res://assets/sounds/ambience/"
const DRONE_DB := -26.0
const NIGHT_DB := -32.0
const CART_DB := -30.0
const CART_GAP := Vector2(90.0, 240.0)  # s between carts: rare enough to wonder if you heard it
const HUM_DB := -8.0
const HUM_NEAR := 1.0  # m (on the floor) from a lamp's spot: full hum
const HUM_FAR := 3.5  # m: silent; lamps are 6-7 m apart, so between two it is gone

var _lamps: Array[Vector3] = []
var _hum: AudioStreamPlayer3D
var _cart: AudioStreamPlayer3D
var _cart_wait := 0.0


func _ready() -> void:
	_loop("drone.mp3", DRONE_DB)
	_loop("night_outside.mp3", NIGHT_DB)
	for light in get_node("../Arena/Lamps").find_children("*", "SpotLight3D", true, false):
		_lamps.append((light as Node3D).global_position)  # dead bulbs have no light, so no hum
	_hum = _player("fluorescent.mp3", HUM_DB, true)
	_hum.bus = &"Dunya"
	_hum.volume_linear = 0.0
	_cart = _player("mine_cart.mp3", CART_DB, false)
	_cart_wait = randf_range(CART_GAP.x * 0.5, CART_GAP.x)


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
		_hum.global_position = best
		_hum.volume_db = HUM_DB
		_hum.volume_linear *= 1.0 - smoothstep(HUM_NEAR, HUM_FAR, best_d)
	_cart_wait -= delta
	if _cart_wait <= 0.0:
		_cart_wait = randf_range(CART_GAP.x, CART_GAP.y)
		var a := randf() * TAU  # from somewhere off by the hall's walls
		_cart.global_position = Vector3(cos(a) * 26.0, 1.0, sin(a) * 26.0)
		_cart.play()


func _loop(file: String, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(file, true)
	p.volume_db = db
	p.autoplay = true
	add_child(p)


func _player(file: String, db: float, looped: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(file, looped)
	p.volume_db = db
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED  # loudness set here, the source only gives direction
	p.autoplay = looped
	add_child(p)
	return p


func _stream(file: String, looped: bool) -> AudioStreamMP3:
	var s := (load(DIR + file) as AudioStreamMP3).duplicate() as AudioStreamMP3
	s.loop = looped
	return s
