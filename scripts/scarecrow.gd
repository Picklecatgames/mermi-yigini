extends "res://scripts/dummy.gd"
## Scarecrow: a dummy that catches fire. A hit sets it burning for BURN seconds, and while it burns
## it pays whoever lit it BURN_GOLD a second (GameState.pay_bonus), so it earns while they shoot
## something else. Burnt out, it smoulders for COOL before it takes fire again; its own hits pay
## the dummy's way all along. The fire round (yol haritası 17) will light it for longer.
## Co-op: everyone lights it on the same shot_landed; only the host pays the seconds.

const FX := preload("res://scripts/fire_fx.gd")
const BURN := 5.0      # s
const COOL := 6.0      # s
const BURN_GOLD := 1   # $ a second
# Where the flames rise from, on the body (assets/props/scarecrow): the robe and the chest.
const FIRE_AT := Vector3(0, 1.15, 0.2)  # a little in front, so the robe doesn't hide it
const FIRE_BOX := Vector3(0.2, 0.45, 0.1)

@export var burn_sound: AudioStream

var _burn_left := 0.0
var _cool_left := 0.0
var _tick := 0.0
var _lighter := 0
var _fire: GPUParticles3D
var _crackle: AudioStreamPlayer3D


func _ready() -> void:
	super()
	kind = &"scarecrow"
	_fire = FX.flames(_upper, FIRE_BOX)
	_fire.position = FIRE_AT
	_crackle = AudioStreamPlayer3D.new()
	_crackle.stream = burn_sound
	_crackle.unit_size = 4.0
	add_child(_crackle)
	GameState.bonus_paid.connect(_on_bonus)
	GameState.target_cue.connect(_on_cue)


func is_burning() -> bool:
	return _burn_left > 0.0


func _on_shot_landed(peer: int, at: Vector3, normal: Vector3, dir: Vector3, target: Node, gold: int, weak: bool, combo: int) -> void:
	super(peer, at, normal, dir, target, gold, weak, combo)
	if target != self or gold == 0 or _burn_left > 0.0 or _cool_left > 0.0:
		return
	_light(peer, BURN)


func _light(peer: int, secs: float) -> void:
	_burn_left = secs
	_tick = 1.0
	_lighter = peer
	FX.burn(_fire, true)
	if _crackle.stream:
		_crackle.play()


## A joiner sees it burning (or smouldering) as the host does.
func join_cues() -> Array:
	if _burn_left > 0.0:
		return [[&"burn", _lighter, _burn_left]]
	if _cool_left > 0.0:
		return [[&"cool", _cool_left]]
	return []


func _on_cue(target: Node, cue: Array) -> void:
	if target != self or not Net.is_client:
		return
	if cue[0] == &"burn":
		_light(cue[1], cue[2])
	elif cue[0] == &"cool":
		_cool_left = cue[1]
		(_fire.get_meta("smoke") as GPUParticles3D).emitting = true


func _on_bonus(peer: int, target: Node, gold: int) -> void:
	if target == self:
		_pops.pop(gold, above_head(), false, peer)


func _process(delta: float) -> void:
	super(delta)
	FX.flicker(_fire)
	if _burn_left > 0.0:
		_burn_left -= delta
		_tick -= delta
		if _tick <= 0.0:
			_tick += 1.0
			GameState.pay_bonus(_lighter, self, BURN_GOLD)  # host only; a client's is dropped
		if _burn_left <= 0.0:
			FX.burn(_fire, false)
			(_fire.get_meta("smoke") as GPUParticles3D).emitting = true  # it smoulders
			_crackle.stop()
			_cool_left = COOL
	elif _cool_left > 0.0:
		_cool_left -= delta
		if _cool_left <= 0.0:
			(_fire.get_meta("smoke") as GPUParticles3D).emitting = false
