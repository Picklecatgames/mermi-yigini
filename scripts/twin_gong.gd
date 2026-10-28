extends Node3D
## Twin gongs, GAP apart: each pays like a gong, and both rung within WINDOW of each other pay every
## hit of the pair PAIR_MULT times over (the rest on top, as a bonus). One player with a fast gun can
## just about swing between them; two players counting down get it every time.
## Co-op: the host times the pair and pays (GameState.pay_bonus); everyone sees it over the gongs.

const PAYOUT_POP := preload("res://scripts/payout_pop.gd")
const WINDOW := 0.4  # s
const PAIR_MULT := 5

var _last := [{}, {}]  # per gong: the last paying hit, {msec, peer, gold}
var _pops: Node3D = PAYOUT_POP.new()
var _flash := Label3D.new()
var _flash_tween: Tween
@onready var _gongs: Array[Node3D] = [$Left, $Right]


func _ready() -> void:
	add_child(_pops)
	_flash.text = "x%d" % PAIR_MULT
	_flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_flash.fixed_size = true
	_flash.pixel_size = 0.0009
	_flash.font_size = 96
	_flash.outline_size = 24
	_flash.modulate = Color(1.0, 0.8, 0.2)
	_flash.position = Vector3(0, 2.2, 0)
	_flash.visible = false
	add_child(_flash)
	GameState.shot_landed.connect(_on_shot_landed)
	GameState.bonus_paid.connect(_on_bonus)


func _side(target: Node) -> int:
	for i in 2:
		if target and _gongs[i].is_ancestor_of(target):
			return i
	return -1


func _on_shot_landed(peer: int, _at: Vector3, _n: Vector3, _d: Vector3, target: Node, gold: int, _weak: bool, _combo: int) -> void:
	var i := _side(target)
	if i < 0 or gold == 0 or Net.is_client:
		return
	var now := Time.get_ticks_msec()
	_last[i] = {"msec": now, "peer": peer, "gold": gold}
	var other: Dictionary = _last[1 - i]
	if other.is_empty() or now - other.msec > WINDOW * 1000.0:
		return
	for j in 2:
		GameState.pay_bonus(_last[j].peer, _gongs[j], _last[j].gold * (PAIR_MULT - 1))
	_last = [{}, {}]


func _on_bonus(peer: int, target: Node, gold: int) -> void:
	var i := _gongs.find(target)
	if i < 0:
		return
	_pops.pop(gold, _gongs[i].global_position + Vector3.UP * 2.0, true, peer)
	_flash.visible = true
	_flash.scale = Vector3.ONE * 1.8
	if _flash_tween:
		_flash_tween.kill()  # the other gong's would hide this flash early
	var t := create_tween()
	_flash_tween = t
	t.tween_property(_flash, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.6)
	t.tween_callback(func() -> void: _flash.visible = false)
