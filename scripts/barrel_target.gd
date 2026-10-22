extends StaticBody3D
## Explosive barrel: a hit blows it up, and the blast pays for every other target standing within
## BLAST of it (their base pay, on top of the barrel's own), so it is worth putting up in the
## middle of a cluster. It is gone for BACK_AFTER and then rises back up.
## Co-op: the host says when it is back (GameState.cue_target, []); a joiner learns it is gone
## ([&"down"]). Later the explosive round (yol haritası 17) turns any hit into a blast like this.

const KIT := preload("res://scripts/target_kit.gd")
const FX := preload("res://scripts/fire_fx.gd")
const PAYOUT_POP := preload("res://scripts/payout_pop.gd")
const BLAST := 3.5        # m
const BACK_AFTER := 8.0   # s

## The barrel's own pay, before the blast adds what stands round it.
@export var hit_gold := 5
@export var hit_sound: AudioStream
@export var blast_sound: AudioStream
var kind := &"barrel"

var _down := false
var _back_left := INF
var _pops: Node3D = PAYOUT_POP.new()
var _hit: AudioStreamPlayer3D
var _blast: AudioStreamPlayer3D
var _ball: GPUParticles3D
@onready var _model: Node3D = $Model
@onready var _shape: CollisionShape3D = $Shape


func _ready() -> void:
	add_to_group("target")
	add_to_group("steel")
	add_child(_pops)
	_hit = KIT.sound(self, hit_sound)
	_blast = KIT.sound(self, blast_sound)
	_blast.unit_size = 12.0  # a blast carries across the shed
	_ball = FX.fireball(self)
	_ball.position.y = 0.6
	GameState.shot_landed.connect(_on_shot_landed)
	GameState.target_cue.connect(_on_cue)


## Gone, until it comes back: the blast skips it, so does a neighbouring barrel's.
func is_down() -> bool:
	return _down


## The barrel's pay plus every standing target's base pay within BLAST (barrels left out, so two
## side by side don't count each other twice).
func hit_gold_at(_at: Vector3) -> int:
	var sum := hit_gold
	for t: Node in get_tree().get_nodes_in_group("target"):
		if t == self or t.get("kind") == &"barrel" or (t.has_method("is_down") and t.is_down()):
			continue
		var g = t.get("hit_gold")
		var d := (t as Node3D).global_position - global_position
		if g is int and Vector2(d.x, d.z).length() <= BLAST:
			sum += g
	return sum


func above_head() -> Vector3:
	return global_position + Vector3.UP * 1.3


func _on_shot_landed(peer: int, at: Vector3, _n: Vector3, _d: Vector3, target: Node, gold: int, weak: bool, _combo: int) -> void:
	if target != self:
		return
	KIT.play(_hit, at)
	if gold == 0:  # from past the firing line: it clangs and stays
		return
	_go_down()
	FX.boom(_ball)
	KIT.play(_blast, global_position)
	_pops.pop(gold, above_head(), weak, peer)
	_back_left = INF if Net.is_client else BACK_AFTER


func _go_down() -> void:
	_down = true
	_model.visible = false
	_shape.disabled = true  # now, so the next round in the same burst goes past


## Host: cues that bring a player joining mid-game up to now.
func join_cues() -> Array:
	return [[&"down"]] if _down else []


func _on_cue(target: Node, cue: Array) -> void:
	if target != self:
		return
	if cue == [&"down"]:
		_go_down()
	elif _down:
		_down = false
		_model.visible = true
		_shape.disabled = false
		_model.scale = Vector3.ONE * 0.2
		create_tween().tween_property(_model, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _down:
		_back_left -= delta
		if _back_left <= 0.0:
			_back_left = INF
			GameState.cue_target(self, [])
