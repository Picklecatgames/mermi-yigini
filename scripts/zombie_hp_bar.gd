extends Node3D
## The thin bar over a zombie that has been hurt: the style rank's brush stroke (style_rank.gd), a
## dark smear under it, a pale strip for what the last hits took that runs out after them, and the
## red of what is left. Shown when it is hit, gone a while after; no text. Faces the camera.
## waves.gd puts one on each zombie and calls set_left() with what the host says is left.
## The tougher it is, the longer the bar (setup(): the full hit points, ×(full / BASE)^GROW within
## LONG): a brute's or a late wave's stands out from a first wave walker's. An elite's has a gold edge.

const STROKE := preload("res://assets/ui/style/stroke_thin.png")
const SMEAR := preload("res://assets/ui/style/stroke_wide.png")
const WIDTH := 0.62  # m, for BASE hit points
const BASE := 100.0  # a walker of wave 1 (waves.gd STATS)
const GROW := 0.35
const LONG := [0.8, 2.2]
const THIN := 0.5  # the stroke's height squeezed to this: a thin line, not a band
const HOLD := 2.6  # s shown after the last hit
const FADE := 0.4
const LAG_WAIT := 0.3  # s the pale strip waits before running out to the red
const LAG_SPEED := 1.2  # of the bar per second
const RED := Color(0.62, 0.05, 0.03)
const PALE := Color(0.95, 0.42, 0.3, 0.6)  # the fresh wound: a lighter, thinner red
const GOLD := Color(0.85, 0.62, 0.18)  # an elite's edge

var left := 1.0  # 0..1
var _lag := 1.0
var _lag_wait := 0.0
var _shown := 0.0  # s left on screen
var _back: Sprite3D
var _trail: Sprite3D
var _front: Sprite3D
var _width := WIDTH
var _elite := false


## Before it is added: how many hit points it came with, and whether it is an elite.
func setup(full: float, elite: bool) -> void:
	_width = WIDTH * clampf(pow(full / BASE, GROW), LONG[0], LONG[1])
	_elite = elite


func _ready() -> void:
	var px := _width / STROKE.get_width()
	_back = _sprite(SMEAR, _width * (1.2 if _elite else 1.12) / SMEAR.get_width(), GOLD if _elite else Color(0, 0, 0), 0)
	if _elite:
		_back.scale.y = THIN * 1.6
	_back.centered = true
	_trail = _sprite(STROKE, px, PALE, 1)
	_front = _sprite(STROKE, px, RED, 2)
	visible = false
	set_process(false)


func _sprite(tex: Texture2D, px: float, col: Color, order: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = px
	s.modulate = col
	s.scale = Vector3(1.0, THIN, 1.0)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true  # over the crowd in front of it
	s.render_priority = 10 + order
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if tex == STROKE:  # left-anchored, cut from the right as it empties
		s.centered = false
		s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() / 2.0)
		s.region_enabled = true
		s.region_rect = Rect2(Vector2.ZERO, tex.get_size())
	add_child(s)
	return s


## What is left of it, 0..1; shows the bar if it went down.
func set_left(frac: float) -> void:
	frac = clampf(frac, 0.0, 1.0)
	if frac < left:
		_shown = HOLD
		_lag_wait = LAG_WAIT
		visible = true
		set_process(true)
	left = frac
	_lag = maxf(_lag, left)
	_draw()


func hide_now() -> void:
	_shown = 0.0
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_lag_wait -= delta
	if _lag_wait <= 0.0 and _lag > left:
		_lag = maxf(left, _lag - LAG_SPEED * delta)
	_shown -= delta
	if _shown <= 0.0:
		hide_now()
		return
	_draw()


func _draw() -> void:
	var a := clampf(_shown / FADE, 0.0, 1.0)
	_back.modulate.a = (0.8 if _elite else 0.55) * a
	_cut(_trail, _lag, a * PALE.a)
	_cut(_front, left, a)


func _cut(s: Sprite3D, frac: float, a: float) -> void:
	s.region_rect = Rect2(Vector2.ZERO, Vector2(maxf(1.0, STROKE.get_width() * frac), STROKE.get_height()))
	s.modulate.a = a if frac > 0.0 else 0.0
