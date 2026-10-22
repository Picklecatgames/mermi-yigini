extends "res://scripts/dummy.gd"
## Armoured dummy: steel plates front and back and a helmet take ARMOR hits that pay nothing
## (they still build the chain, so the burst that breaks it pays off), and the hit that breaks the
## armour pays BREAK_GOLD. Bare, it is a plain dummy until the armour is back after REGROW.
## Co-op: every peer counts the armour down on the same shot_landed; the host says when it is
## back ([]), a joiner hears how much is left ([&"hp", n]). The piercing round (yol haritası 17)
## will go straight through.

const ARMOR := 10
const BREAK_GOLD := 10
const REGROW := 8.0  # s

@export var break_sound: AudioStream

var _hp := ARMOR
var _regrow_left := INF
var _armor := Node3D.new()  # rides on the swinging body
var _break: AudioStreamPlayer3D


func _ready() -> void:
	super()
	kind = &"armored_dummy"
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.36, 0.37, 0.39)
	steel.metallic = 0.9
	steel.roughness = 0.42
	# Placed by the body mesh's own bounds (assets/props/dummy, Upper: ±0.47 wide, 1.5 tall).
	for z: float in [0.2, -0.22]:
		var plate := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.42, 0.58, 0.035)
		plate.mesh = box
		plate.position = Vector3(0, 0.66, z)
		_armor.add_child(plate)
	var helmet := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.175
	dome.height = 0.2
	dome.is_hemisphere = true
	helmet.mesh = dome
	helmet.position = Vector3(0, 1.33, 0)
	_armor.add_child(helmet)
	for m: MeshInstance3D in _armor.get_children():
		m.material_override = steel
	_upper.add_child(_armor)
	_break = AudioStreamPlayer3D.new()
	_break.stream = break_sound
	_break.unit_size = 6.0
	add_child(_break)
	add_to_group("steel")
	GameState.target_cue.connect(_on_cue)


## Armour hits pay nothing; the one that breaks it pays BREAK_GOLD (before weak spot and combo).
func hit_gold_at(_at: Vector3) -> int:
	if _hp <= 0:
		return hit_gold
	return BREAK_GOLD if _hp == 1 else 0


func _on_shot_landed(peer: int, at: Vector3, normal: Vector3, dir: Vector3, target: Node, gold: int, weak: bool, combo: int) -> void:
	super(peer, at, normal, dir, target, gold, weak, combo)
	if target != self or combo == 0 or _hp <= 0:  # combo 0: from past the firing line
		return
	_hp -= 1
	if _hp == 0:
		_shed()
		if _break.stream:
			_break.global_position = at
			_break.play()
		_regrow_left = INF if Net.is_client else REGROW


func _shed() -> void:
	_hp = 0
	remove_from_group("steel")
	var t := create_tween().set_parallel()
	t.tween_property(_armor, "scale", Vector3.ONE * 1.25, 0.12)
	t.tween_property(_armor, "position:y", 0.15, 0.12)
	t.chain().tween_callback(func() -> void:
		_armor.visible = false
		_armor.scale = Vector3.ONE
		_armor.position = Vector3.ZERO)


func join_cues() -> Array:
	return [[&"hp", _hp]]


func _on_cue(target: Node, cue: Array) -> void:
	if target != self:
		return
	if cue.size() == 2 and cue[0] == &"hp":
		_hp = cue[1]
		if _hp <= 0:
			_shed()
		return
	_hp = ARMOR  # back on
	add_to_group("steel")
	_armor.visible = true
	_armor.scale = Vector3.ONE * 0.6
	create_tween().tween_property(_armor, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	super(delta)
	if _hp <= 0:
		_regrow_left -= delta
		if _regrow_left <= 0.0:
			_regrow_left = INF
			GameState.cue_target(self, [])
