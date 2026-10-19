class_name SmokeSprite
extends MeshInstance3D
## A single flipbook smoke sprite. One-shot: plays its frames over `duration` while growing,
## drifting and fading out. Looping: cycles the frames for as long as `strength` > 0, so the
## owner fades it by lowering `strength`.

@export var sheet: Texture2D
@export var grid := Vector2i(8, 8)
@export var duration := 1.0     # s for the whole sheet
@export var looping := false
@export var fixed_y := false     # upright plume, anchored at its bottom edge
@export var size := 0.2          # m, quad width
@export var grow := 1.0          # one-shot: scale at the end
@export var drift := Vector3.ZERO  # m/s in the parent's space, one-shot
@export var brightness := 1.5

var strength := 0.0  # alpha multiplier
var _t := 0.0
var _mat := ShaderMaterial.new()
var _start: Vector3


func _ready() -> void:
	var cell := Vector2(sheet.get_width() / float(grid.x), sheet.get_height() / float(grid.y))
	var q := QuadMesh.new()
	q.size = Vector2(size, size * cell.y / cell.x)
	if fixed_y:
		q.center_offset = Vector3(0.0, q.size.y * 0.5, 0.0)
	mesh = q
	_mat.shader = preload("res://materials/flipbook_smoke.gdshader")
	_mat.set_shader_parameter("sheet", sheet)
	_mat.set_shader_parameter("grid", Vector2(grid))
	_mat.set_shader_parameter("fixed_y", fixed_y)
	_mat.set_shader_parameter("brightness", brightness)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false


func play() -> void:
	_t = 0.0
	strength = 1.0
	_start = position
	scale = Vector3.ONE
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var frames := float(grid.x * grid.y)
	var a := strength
	if looping:
		_mat.set_shader_parameter("frame", fmod(_t / duration * frames, frames))
		if strength <= 0.0:
			visible = false
	else:
		var p := _t / duration
		if p >= 1.0:
			visible = false
			return
		_mat.set_shader_parameter("frame", p * (frames - 1.0))
		a *= smoothstep(0.0, 0.04, p) * (1.0 - smoothstep(0.45, 1.0, p))
		scale = Vector3.ONE * lerpf(1.0, grow, 1.0 - pow(1.0 - p, 2.0))
		position = _start + drift * _t
	_mat.set_shader_parameter("alpha", a)
