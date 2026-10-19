extends StaticBody3D
## Six steel plates on a rack, played like whack-a-mole: they all lie down and one at a time
## springs up for a moment. Hit it and it slaps down and the next comes up sooner; every hit in
## a row also shortens how long the next one stays up. If one gets away it sinks back and the
## pace starts over. Faces +Z.

const KIT := preload("res://scripts/target_kit.gd")
const MODEL := preload("res://assets/props/targets/plate_rack.gltf")
const PAYOUT_POP := preload("res://scripts/payout_pop.gd")
const PLATES := 6
const DOWN := -1.45        # rad: lying back on the rack
const UP_TIME := 1.6       # s a plate stays up at the start of a run
const UP_MIN := 0.9        # s: the fastest it gets
const SPEED_UP := 0.92     # up time kept after each hit
const GAP := 0.7           # s before the next plate after one got away
const GAP_HIT := 0.3       # s before the next plate after a hit
const KNOCK := 4.0         # rad/s a hit plate starts falling at
const FALL := 22.0         # rad/s² it speeds up at
const BOUNCE := 0.2
const RISE_K := 260.0      # 1/s²: snaps up with a small overshoot
const RISE_C := 18.0
const SINK_K := 40.0       # 1/s²: an unhit plate sinks back slowly
const SINK_C := 12.0
const LIVE := -0.5         # rad: above this the up plate takes hits

## Base pay per hit before weak spot and combo (GameState reads it).
@export var hit_gold := 7
## Target kind for the combo's variety cap.
var kind := &"plate_rack"
@export var hit_sound: AudioStream
@export var rise_sound: AudioStream

var _plates: Array[MeshInstance3D] = []
var _rest: Array[Transform3D] = []
var _angle: Array[float] = []
var _vel: Array[float] = []
var _knocked: Array[bool] = []
var _shapes: Array[CollisionShape3D] = []
var _current := -1   # the plate that is up, or -1
var _last := 0       # last plate that came up, so the same one never comes twice running
var _up_time := UP_TIME
var _up_left := 0.0
var _gap := 1.0
var _hit: AudioStreamPlayer3D
var _rise: AudioStreamPlayer3D
var _pops: Node3D = PAYOUT_POP.new()


func _ready() -> void:
	add_to_group("target")
	add_to_group("steel")
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	KIT.stand_body(self, model.get_node("Stand"))
	KIT.stand_body(self, model.get_node("ResetArm"))
	for i in PLATES:
		var p: MeshInstance3D = model.get_node("Plate%d" % (i + 1))
		_plates.append(p)
		_rest.append(p.transform)
		_angle.append(DOWN)
		_vel.append(0.0)
		_knocked.append(false)
		p.transform = KIT.tipped(p.transform, DOWN)
		var c := KIT.part_shape(self, p)
		c.disabled = true
		_shapes.append(c)
	_hit = KIT.sound(self, hit_sound)
	_rise = KIT.sound(self, rise_sound)
	add_child(_pops)
	GameState.shot_landed.connect(_on_shot_landed)


## The plate that is up right now, or -1 (for tests and tutorials).
func up_plate() -> int:
	return _current if _current >= 0 and _angle[_current] > LIVE else -1


func plate_center(i: int) -> Vector3:
	return _plates[i].global_transform * _plates[i].get_aabb().get_center()


func decal_parent(at: Vector3) -> Node3D:
	return _plates[_nearest(at)]


## Over the plate that is up (or was last), so the combo reads where you are aiming.
func above_head() -> Vector3:
	return _plates[_last].global_position + Vector3(0, 0.45, 0)


func _nearest(at: Vector3) -> int:
	var best := 0
	for i in PLATES:
		if plate_center(i).distance_to(at) < plate_center(best).distance_to(at):
			best = i
	return best


func _on_shot_landed(_peer: int, at: Vector3, _n: Vector3, _d: Vector3, target: Node, gold: int, weak: bool, _combo: int) -> void:
	if target != self or _current < 0:
		return
	KIT.play(_hit, at)
	if gold == 0:  # from past the firing line: it rings, but stays up
		return
	var i := _current
	_knocked[i] = true
	_vel[i] = minf(_vel[i], -KNOCK)
	_shapes[i].disabled = true
	_current = -1
	_gap = GAP_HIT
	_up_time = maxf(_up_time * SPEED_UP, UP_MIN)
	_pops.pop(gold, above_head(), weak)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if _current < 0:
		_gap -= delta  # real clock: only the springs are clamped
		if _gap <= 0.0:
			_current = (_last + 1 + randi() % (PLATES - 1)) % PLATES
			_last = _current
			_knocked[_current] = false
			_up_left = _up_time
			KIT.play(_rise, _plates[_current].global_position)
	else:
		_up_left -= delta
		if _up_left <= 0.0:  # got away: sinks back, and the pace starts over
			_shapes[_current].disabled = true
			_current = -1
			_gap = GAP
			_up_time = UP_TIME
	for i in PLATES:
		for s in 4:
			var h := dt / 4.0
			if _knocked[i]:
				_vel[i] -= FALL * h
			elif i == _current:
				_vel[i] += (-RISE_K * _angle[i] - RISE_C * _vel[i]) * h
			else:
				_vel[i] += (SINK_K * (DOWN - _angle[i]) - SINK_C * _vel[i]) * h
			_angle[i] += _vel[i] * h
			if _angle[i] < DOWN:
				_angle[i] = DOWN
				_vel[i] = -_vel[i] * BOUNCE
		if i == _current and _angle[i] > LIVE:
			_shapes[i].disabled = false
		_plates[i].transform = KIT.tipped(_rest[i], _angle[i])
		KIT.follow(_shapes[i], _plates[i])
