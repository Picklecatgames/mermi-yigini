extends Control
## Crosshair hit marker: four short diagonal ticks that flash when the local player's shot pays.

const GAP := 7.0
const LEN := 9.0
const FADE := 0.22  # s

var _alpha := 0.0
var _weak := false  # weak-spot hits flash gold


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.shot_landed.connect(func(peer: int, _at: Vector3, _n: Vector3, _d: Vector3, _t: Node, gold: int, weak: bool, _combo: int) -> void:
		if gold > 0 and peer == GameState.local_peer():
			_alpha = 1.0
			_weak = weak
			queue_redraw())


func _process(delta: float) -> void:
	if _alpha > 0.0:
		_alpha = maxf(_alpha - delta / FADE, 0.0)
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var c := Color(1, 0.8, 0.2, _alpha) if _weak else Color(1, 1, 1, _alpha)
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n := d.normalized()
		draw_line(n * GAP, n * (GAP + LEN), Color(0, 0, 0, _alpha * 0.6), 4.0, true)
		draw_line(n * GAP, n * (GAP + LEN), c, 2.0, true)
