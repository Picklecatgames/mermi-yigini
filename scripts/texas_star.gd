extends StaticBody3D
## Texas Star: five small plates on a star that turns clockwise, fast enough that a hit takes
## real aim. A hit knocks that plate off; it tumbles to the ground, the star lurches on a little
## faster for a moment, and the plate grows back on its spot RESPAWN seconds later. Faces +Z.

const KIT := preload("res://scripts/target_kit.gd")
const MODEL := preload("res://assets/props/targets/texas_star.gltf")
const PAYOUT_POP := preload("res://scripts/payout_pop.gd")
const PLATES := 5
const SPIN := 3.0           # rad/s clockwise as seen by the shooter: a turn in ~2 s
const LURCH := 1.2          # rad/s added by each plate knocked off
const LURCH_DECAY := 1.2    # rad/s² it settles back by
const GRAVITY := 9.8
const RESPAWN := 1.5        # s from a plate falling to it growing back
const POP_TIME := 0.3       # s for a plate to grow back on

## Base pay per hit before weak spot and combo (GameState reads it).
@export var hit_gold := 12
## Target kind for the combo's variety cap.
var kind := &"texas_star"
@export var hit_sound: AudioStream
@export var reset_sound: AudioStream

var _arm: MeshInstance3D
var _arm_rest: Transform3D
var _angle := 0.0
var _lurch := 0.0
var _plates: Array[MeshInstance3D] = []
var _rest: Array[Transform3D] = []  # under the arm
var _on: Array[bool] = []
var _fall_vel: Array[Vector3] = []
var _fall_spin: Array[Vector3] = []
var _shapes: Array[CollisionShape3D] = []
var _back_in: Array[float] = []  # s until each fallen plate grows back
var _hit: AudioStreamPlayer3D
var _reset: AudioStreamPlayer3D
var _pops: Node3D = PAYOUT_POP.new()


func _ready() -> void:
	add_to_group("target")
	add_to_group("steel")
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	_arm = model.get_node("Arm")
	_arm_rest = _arm.transform
	KIT.stand_body(self, model.get_node("Stand"))
	for i in PLATES:
		var p: MeshInstance3D = model.get_node("Plate%d" % (i + 1))
		p.reparent(_arm)  # keeps its place; turns with the star from now on
		_plates.append(p)
		_rest.append(p.transform)
		_on.append(true)
		_fall_vel.append(Vector3.ZERO)
		_fall_spin.append(Vector3.ZERO)
		_back_in.append(0.0)
		_shapes.append(KIT.part_shape(self, p))
	_hit = KIT.sound(self, hit_sound)
	_reset = KIT.sound(self, reset_sound)
	add_child(_pops)
	GameState.shot_landed.connect(_on_shot_landed)


func plates_on() -> int:
	return _on.count(true)


func plate_center(i: int) -> Vector3:
	return _plates[i].global_transform * _plates[i].get_aabb().get_center()


## The plate that was hit, even if it has just been knocked off (its mark falls with it).
func decal_parent(at: Vector3) -> Node3D:
	var best := 0
	for i in PLATES:
		if plate_center(i).distance_to(at) < plate_center(best).distance_to(at):
			best = i
	return _plates[best]


func above_head() -> Vector3:
	return global_transform * Vector3(0, 1.95, 0)


func _nearest(at: Vector3) -> int:
	var best := -1
	for i in PLATES:
		if _on[i] and (best < 0 or plate_center(i).distance_to(at) < plate_center(best).distance_to(at)):
			best = i
	return maxi(best, 0)


func _on_shot_landed(peer: int, at: Vector3, _n: Vector3, dir: Vector3, target: Node, gold: int, weak: bool, _combo: int) -> void:
	if target != self:
		return
	KIT.play(_hit, at)
	if gold == 0:  # from past the firing line: it rings, but nothing falls
		return
	var i := _nearest(at)
	_on[i] = false
	_shapes[i].disabled = true
	var p := _plates[i]
	p.reparent(self)  # off the star, into the world
	var push := Vector3(dir.x, 0.0, dir.z).normalized()
	_fall_vel[i] = push * 1.2 + Vector3.UP * randf_range(0.6, 1.2)
	_fall_spin[i] = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(6.0, 11.0)
	_lurch += LURCH
	_back_in[i] = RESPAWN
	_pops.pop(gold, above_head(), weak, peer)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_lurch = move_toward(_lurch, 0.0, LURCH_DECAY * dt)
	_angle = fmod(_angle - (SPIN + _lurch) * delta, TAU)  # real clock: x10 test speed spins x10
	_arm.transform = Transform3D(Basis(Vector3.BACK, _angle) * _arm_rest.basis, _arm_rest.origin)
	var floor_y := global_position.y + 0.02
	for i in PLATES:
		if _on[i]:
			KIT.follow(_shapes[i], _plates[i])
			continue
		var p := _plates[i]
		if _fall_vel[i] != Vector3.ZERO:  # tumbling down
			_fall_vel[i].y -= GRAVITY * dt
			p.global_position += _fall_vel[i] * dt
			p.global_basis = Basis(_fall_spin[i].normalized(), _fall_spin[i].length() * dt) * p.global_basis
			if p.global_position.y <= floor_y:
				p.global_position.y = floor_y
				_fall_vel[i] = Vector3.ZERO
		_back_in[i] -= delta
		if _back_in[i] <= 0.0:
			_put_back(i)


## A fallen plate grows back on its spot on the star.
func _put_back(i: int) -> void:
	var p := _plates[i]
	p.reparent(_arm)
	p.transform = _rest[i]
	p.scale = Vector3.ONE * 0.01
	create_tween().tween_property(p, "scale", Vector3.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_on[i] = true
	_fall_vel[i] = Vector3.ZERO
	_shapes[i].disabled = false
	KIT.follow(_shapes[i], p)
	KIT.play(_reset, p.global_position)
