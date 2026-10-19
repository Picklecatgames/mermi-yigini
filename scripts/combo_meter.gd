extends Control
## Combo multiplier over the dummy the local player is chaining hits on: "x5" with a glass bar
## under it that drains over GameState.COMBO_WINDOW while the text fades out. Every hit refills
## it, punches the text, and grows it a little; the growth is logarithmic so x100 from a fast
## gun stays a corner of the screen, not all of it.

const BASE_SIZE := 30.0  # px at x2
const GROW := 0.9        # x100 is (1 + GROW) times the x2 size: ~57 px
const MAX_COMBO := 100.0
const PUNCH := 0.35      # extra scale on each hit, settles in ~0.15 s
const OFFSET := Vector2(48, -6)  # px from the top of the dummy's head, right of the "+$" pop
const BAR_H := 5.0
const WHITE := Color(1.0, 0.96, 0.85)
const GOLD := Color(1.0, 0.76, 0.2)
const RED := Color(1.0, 0.32, 0.14)

var _combo := 0
var _left := 0.0  # s of the window left, game time like GameState's
var _target: Node3D
var _punch := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.shot_landed.connect(_on_shot_landed)


func _on_shot_landed(peer: int, _at: Vector3, _n: Vector3, _d: Vector3, target: Node, _gold: int, _weak: bool, combo: int) -> void:
	if peer != GameState.local_peer():
		return
	_combo = combo
	_left = GameState.COMBO_WINDOW if combo >= 2 else 0.0
	_target = target as Node3D if combo >= 2 else null
	_punch = PUNCH
	queue_redraw()


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	_punch = move_toward(_punch, 0.0, delta * PUNCH / 0.15)
	queue_redraw()


func _draw() -> void:
	if _left <= 0.0 or not is_instance_valid(_target):
		return
	var cam := get_viewport().get_camera_3d()
	var head: Vector3 = _target.above_head()
	if cam == null or cam.is_position_behind(head):
		return
	var frac := _left / GameState.COMBO_WINDOW
	var t := log(float(_combo)) / log(MAX_COMBO)  # 0.15 at x2, 1 at x100
	var size := int(BASE_SIZE * (1.0 + GROW * clampf(t, 0.0, 1.0)))
	var color := WHITE.lerp(GOLD, clampf(t * 2.0, 0.0, 1.0)).lerp(RED, clampf(t * 2.0 - 1.0, 0.0, 1.0))
	var alpha := pow(frac, 0.6)  # holds a while, then fades out as the bar runs dry
	var font := get_theme_default_font()
	var text := "x%d" % _combo
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_set_transform(cam.unproject_position(head) + OFFSET, 0.0, Vector2.ONE * (1.0 + _punch))
	draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(size / 5, 4), Color(0, 0, 0, 0.7 * alpha))
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))
	# Glass bar: a dim frosted track, the time left filled bright over it.
	var bar := Rect2(0.0, size * 0.22, w, BAR_H)
	draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.35 * alpha))
	draw_rect(bar, Color(1, 1, 1, 0.12 * alpha))
	draw_rect(Rect2(bar.position, Vector2(w * frac, BAR_H)), Color(color, 0.75 * alpha))
	draw_rect(Rect2(bar.position, Vector2(w * frac, 1.0)), Color(1, 1, 1, 0.5 * alpha))  # glint
