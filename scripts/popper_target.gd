extends StaticBody3D
## Steel popper: a paddle with a round head on a ground hinge. A hit knocks it flat (it takes no
## hits on the way down), it lies there a few seconds and springs back up with a small
## overshoot. The round head is the weak spot. Faces +Z.
## Co-op: the host rolls how long it stays down and says when it stands (GameState.cue_target);
## a client's popper lies there until then.

const KIT := preload("res://scripts/target_kit.gd")
const MODEL := preload("res://assets/props/targets/popper.gltf")
const PAYOUT_POP := preload("res://scripts/payout_pop.gd")
const DOWN := -1.3         # rad: lying back (it already leans back ~15° standing)
const KNOCK := 3.0         # rad/s it starts falling at
const FALL := 16.0         # rad/s² it speeds up at on the way down
const BOUNCE := 0.25       # of the speed it comes off the ground with
const RISE_K := 160.0      # 1/s²: spring back up
const RISE_C := 13.0       # 1/s: a little overshoot, settles in ~0.4 s
const LIVE := -0.3         # rad: above this it takes hits again
const HEAD_FROM := 0.49    # m up the paddle where the round head starts

## Base pay per hit before weak spot and combo (GameState reads it).
@export var hit_gold := 3
## Target kind so GameState can tell targets apart; a pair of poppers counts once.
var kind := &"popper"
## Seconds it stays down, picked at random in this range.
@export var down_time := Vector2(2.0, 3.5)
@export var hit_sound: AudioStream
@export var rise_sound: AudioStream

var _angle := 0.0
var _vel := 0.0
var _down_left := 0.0
var _knocked := false
var _paddle: MeshInstance3D
var _rest: Transform3D
var _shape: CollisionShape3D
var _hit: AudioStreamPlayer3D
var _rise: AudioStreamPlayer3D
var _pops: Node3D = PAYOUT_POP.new()


func _ready() -> void:
	add_to_group("target")
	add_to_group("steel")
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	_paddle = model.get_node("Target")
	_rest = _paddle.transform
	KIT.stand_body(self, model.get_node("Stand"))
	_shape = KIT.part_shape(self, _paddle)
	_hit = KIT.sound(self, hit_sound)
	_rise = KIT.sound(self, rise_sound)
	add_child(_pops)
	GameState.shot_landed.connect(_on_shot_landed)
	GameState.target_cue.connect(_on_cue)


## Lying down after a hit, until it stands back up.
func is_down() -> bool:
	return _knocked


func is_weak(at: Vector3) -> bool:
	return _paddle.to_local(at).y > HEAD_FROM


func decal_parent(_at: Vector3) -> Node3D:
	return _paddle


func above_head() -> Vector3:
	return global_transform * Vector3(0, 0.95, 0)


func _on_shot_landed(peer: int, at: Vector3, _n: Vector3, _d: Vector3, target: Node, gold: int, weak: bool, _combo: int) -> void:
	if target != self:
		return
	KIT.play(_hit, at)
	if gold == 0:  # from past the firing line: it rings, but stays up
		return
	_knocked = true
	_vel = minf(_vel, -KNOCK)
	_down_left = INF if Net.is_client else randf_range(down_time.x, down_time.y)
	_shape.disabled = true  # now, so the next round in the same burst goes past it
	_pops.pop(gold, above_head(), weak, peer)


## Host: cues that bring a player joining mid-game up to now.
func join_cues() -> Array:
	return [[&"down"]] if _knocked else []


## The host's call: stand back up ([]), or for a joiner, it is lying down ([&"down"]).
func _on_cue(target: Node, cue: Array) -> void:
	if target != self:
		return
	if cue == [&"down"]:
		_knocked = true
		_angle = DOWN
		_vel = 0.0
		_down_left = INF
		_shape.disabled = true
	elif _knocked:
		_knocked = false
		KIT.play(_rise, global_position)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if _knocked:
		_down_left -= delta  # real clock: only the springs are clamped
		if _down_left <= 0.0:
			_down_left = INF
			GameState.cue_target(self, [])
	for i in 4:
		var h := dt / 4.0
		if _knocked:
			_vel -= FALL * h
		else:
			_vel += (-RISE_K * _angle - RISE_C * _vel) * h
		_angle += _vel * h
		if _angle < DOWN:
			_angle = DOWN
			_vel = -_vel * BOUNCE
	if not _knocked and _angle > LIVE:
		_shape.disabled = false
	_paddle.transform = KIT.tipped(_rest, _angle)
	KIT.follow(_shape, _paddle)
