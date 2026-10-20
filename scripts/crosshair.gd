extends Control
## Hip crosshair: one small ring where the shot will go. It breathes with the spread (moving,
## jumping, firing), easing in and out so the change is seen, never jumping between shapes.
## The player sets `offset` and `gap` (px) every frame from the gun's aim.

const RADIUS := 3.0  # px at rest
const EASE := 12.0   # 1/s, how fast the ring follows the spread

var offset := Vector2.ZERO
var gap := 0.0
var _shown := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_shown = lerpf(_shown, gap, 1.0 - exp(-delta * EASE))
	queue_redraw()


func _draw() -> void:
	var r := RADIUS + _shown
	draw_arc(offset, r, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 3.0, true)
	draw_arc(offset, r, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 1.5, true)
