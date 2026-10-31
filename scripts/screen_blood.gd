extends CanvasLayer
## A head blown off close to the camera: a red pulse in from the screen's edges and a few drops of
## the real blood (blood_fx.gd decals) on the glass, gone in about a second. Local, visual only; the
## "Ekranda kan" setting turns it off.
##   ScreenBlood.splash(tree, near, rng)  # near: 0 far off .. 1 right in the face

const FLASH_TIME := 0.25  # s for the red pulse to fade
const DROP_TIME := 1.1  # s the drops hang on
const DROPS := [1, 4]  # how many, from far to near
const RED := Color(0.55, 0.02, 0.02)
const BLOOD := preload("res://scripts/blood_fx.gd")

var _age := 0.0
var _near := 0.0
var _drops: Array[Dictionary] = []  # texture, centre (0..1 of the screen), size (of its height), turn
var _paint: Control
static var _edge: GradientTexture2D


static func splash(tree: SceneTree, near: float, rng: RandomNumberGenerator) -> void:
	var settings := tree.root.get_node_or_null(^"Settings") if tree else null  # (by path: checks load this before the autoloads)
	if settings == null or not settings.value("screen_blood") or near <= 0.0:
		return
	var s: CanvasLayer = tree.root.get_node_or_null(^"ScreenBlood")
	if s == null:
		s = load("res://scripts/screen_blood.gd").new()
		s.name = "ScreenBlood"
		tree.root.add_child(s)
	s._start(clampf(near, 0.0, 1.0), rng)


func _ready() -> void:
	layer = 40
	_paint = Control.new()
	_paint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint.draw.connect(_draw_on)
	add_child(_paint)
	if _edge == null:
		_edge = GradientTexture2D.new()
		_edge.fill = GradientTexture2D.FILL_RADIAL
		_edge.fill_from = Vector2(0.5, 0.5)
		_edge.fill_to = Vector2(1.0, 1.0)
		_edge.gradient = Gradient.new()
		_edge.gradient.set_color(0, Color(RED, 0.0))
		_edge.gradient.set_offset(0, 0.45)
		_edge.gradient.set_color(1, RED)


func _start(near: float, rng: RandomNumberGenerator) -> void:
	_age = 0.0
	_near = near
	_drops.clear()
	for i in roundi(lerpf(DROPS[0], DROPS[1], near)):
		var side := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		side = side / maxf(absf(side.x), absf(side.y))  # out toward an edge: the middle stays clear
		var kind: StringName = [&"drop", &"mist"][rng.randi() % 2]
		_drops.append({"tex": BLOOD._tex(kind, rng.randi() % BLOOD.SETS[kind])[0],
				"at": Vector2(0.5, 0.5) + side * Vector2(rng.randf_range(0.3, 0.45), rng.randf_range(0.3, 0.45)),
				"size": rng.randf_range(0.18, 0.35) * lerpf(0.7, 1.2, near), "turn": rng.randf() * TAU})
	set_process(true)
	_paint.queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	_paint.queue_redraw()
	if _age > DROP_TIME:
		set_process(false)


func _draw_on() -> void:
	if _age > DROP_TIME:
		return
	var view := _paint.size
	var flash := clampf(1.0 - _age / FLASH_TIME, 0.0, 1.0) * lerpf(0.35, 0.7, _near)
	if flash > 0.0:
		_paint.draw_texture_rect(_edge, Rect2(Vector2.ZERO, view), false, Color(1, 1, 1, flash))
	var fade := clampf(1.0 - (_age - DROP_TIME * 0.5) / (DROP_TIME * 0.5), 0.0, 1.0)
	for d in _drops:
		var side: float = d.size * view.y
		var at: Vector2 = d.at * view + Vector2(0, _age * side * 0.15)  # running down the glass a little
		_paint.draw_set_transform(at, d.turn, Vector2.ONE)
		_paint.draw_texture_rect(d.tex, Rect2(-Vector2.ONE * side / 2.0, Vector2.ONE * side), false, Color(1, 1, 1, 0.85 * fade))
	_paint.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
