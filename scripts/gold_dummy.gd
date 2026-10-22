extends "res://scripts/dummy.gd"
## Gold dummy: waits under its rail most of the time. Every SHOW_EVERY (rolled on the host) it
## springs up for SHOW seconds, slides to and fro along the rail and pays hit_gold a hit, with a
## call over it everyone sees through walls, so the whole team turns to it.
## Co-op: the host says when it comes up ([&"up", seconds left]); each peer runs the slide and the
## drop on its own clock from there.

const SHOW := 6.0                     # s
const SHOW_EVERY := Vector2(45, 90)   # s
const SLIDE := 1.4                    # m to each side
const SLIDE_PERIOD := 2.2             # s

@export var appear_sound: AudioStream

var _up := false
var _left := 0.0
var _t := 0.0
var _next := INF
var _home: Vector3
var _shout := Label3D.new()
var _appear: AudioStreamPlayer3D
@onready var _shapes: Array[Node] = find_children("*", "CollisionShape3D")


func _ready() -> void:
	super()
	kind = &"gold_dummy"
	hit_gold = 10
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.77, 0.3)
	gold.metallic = 1.0
	gold.roughness = 0.28
	for m: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		m.material_override = gold
	_home = position
	var rail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SLIDE * 2 + 0.7, 0.08, 0.5)
	rail.mesh = box
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.25, 0.25, 0.26)
	steel.metallic = 0.8
	steel.roughness = 0.5
	rail.material_override = steel
	var bed := StaticBody3D.new()  # rounds spark off it; placement mode can pick the piece by it
	bed.name = "Rail"
	bed.add_to_group("steel")
	bed.top_level = true  # stays put while the dummy slides
	bed.add_child(rail)
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	c.shape = shape
	bed.add_child(c)
	add_child(bed)
	bed.global_transform = Transform3D(global_basis, global_position + Vector3.UP * 0.04)
	_shout.text = "ALTIN KUKLA!"
	_shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_shout.no_depth_test = true
	_shout.fixed_size = true
	_shout.pixel_size = 0.0008
	_shout.font_size = 72
	_shout.outline_size = 18
	_shout.modulate = Color(1.0, 0.82, 0.25)
	_shout.render_priority = 10
	add_child(_shout)
	_appear = AudioStreamPlayer3D.new()
	_appear.stream = appear_sound
	_appear.unit_size = 20.0
	add_child(_appear)
	_hide()
	if not Net.is_client:
		_next = randf_range(SHOW_EVERY.x, SHOW_EVERY.y)
	GameState.target_cue.connect(_on_cue)


## Down under the rail: nothing to hit, a blast next to it skips it.
func is_down() -> bool:
	return not _up


func _hide() -> void:
	_up = false
	$Model.visible = false
	_shout.visible = false
	for c: CollisionShape3D in _shapes:
		c.disabled = true
	position = _home


func _show(left: float) -> void:
	_up = true
	_left = left
	_t = 0.0
	$Model.visible = true
	_shout.visible = true
	for c: CollisionShape3D in _shapes:
		c.disabled = false
	$Model.scale = Vector3(1, 0.1, 1)
	create_tween().tween_property($Model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _appear.stream:
		_appear.play()


func join_cues() -> Array:
	return [[&"up", _left]] if _up else []


func _on_cue(target: Node, cue: Array) -> void:
	if target == self and cue.size() == 2 and cue[0] == &"up":
		_show(cue[1])


func _process(delta: float) -> void:
	super(delta)
	if _up:
		_t += delta
		_left -= delta
		position = _home + basis.x * SLIDE * sin(_t * TAU / SLIDE_PERIOD)
		_shout.global_position = above_head() + Vector3.UP * 0.35
		if _left <= 0.0:
			_hide()
			if not Net.is_client:
				_next = randf_range(SHOW_EVERY.x, SHOW_EVERY.y)
	elif not Net.is_client:
		_next -= delta
		if _next <= 0.0:
			_next = INF
			GameState.cue_target(self, [&"up", SHOW])
