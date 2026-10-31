extends Control
## Crosshair hit marker: four short diagonal ticks that flash when the local player's shot lands on
## something that counts: a paying target or a zombie. Each kind reads at a glance, the way shooters
## teach it: a body hit is a quick white tick, a head hit gold and bigger, a kill a red X that hangs
## on a little longer, and a head blown off (waves.gd, now and then) the red X with a gold cross over
## it, longest of all, and the game held a blink (HOLD) on the shooter's machine alone. Every one pops
## out a touch and settles, so it lands like a hit, not a blink.

const GAP := 7.0
const LEN := 9.0
## Per kind: colour, tick length and width (× LEN and the line), how long it fades (s), how far
## it pops out on arrival.
const KINDS := {
	&"hit": [Color(1, 1, 1), 1.0, 2.0, 0.22, 1.25],
	&"head": [Color(1, 0.8, 0.2), 1.25, 2.5, 0.28, 1.4],
	&"kill": [Color(1, 0.22, 0.16), 1.5, 3.0, 0.45, 1.6],
	&"pop": [Color(1, 0.22, 0.16), 1.8, 3.5, 0.7, 2.0],
}
const RANK := {&"hit": 0, &"head": 0, &"kill": 1, &"pop": 2}  # a showing one is not cut short by a lower
const POP_CROSS := Color(1, 0.8, 0.2)
## The hold on a head blown off: the game at HOLD_SPEED for HOLD s of real time. Not over the cheat
## menu's own speed.
const HOLD := 0.05
const HOLD_SPEED := 0.05
const POP_TIME := 0.07  # s for a pop to settle back to its size

var _alpha := 0.0
var _kind := &"hit"
var _pop := 1.0
var center := Vector2.ZERO  # px; the player keeps it on the crosshair dot


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.shot_landed.connect(func(peer: int, _at: Vector3, _n: Vector3, _d: Vector3, target: Node, gold: int, weak: bool, _combo: int) -> void:
		if peer != GameState.local_peer():
			return
		if gold > 0 or (target != null and target.has_meta("zombie")):
			show_hit(&"head" if weak else &"hit"))
	# The host says who brought a zombie down (scripts/waves.gd cues): ours outranks the hit.
	GameState.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"die" and cue[3] == GameState.local_peer():
			var pop: bool = cue.size() > 7 and cue[7] == &"head"
			show_hit(&"pop" if pop else &"kill")
			if pop:
				hold())


## The game held for HOLD s of real time (a head blown off by this player).
func hold() -> void:
	if not is_inside_tree() or Engine.time_scale != 1.0:
		return
	Engine.time_scale = HOLD_SPEED
	await get_tree().create_timer(HOLD, true, false, true).timeout
	if Engine.time_scale == HOLD_SPEED:
		Engine.time_scale = 1.0


## Flashes the marker as `kind` (KINDS). A kill in flight is not cut short by the hit that follows it.
func show_hit(kind: StringName) -> void:
	if _alpha > 0.5 and RANK[kind] < RANK[_kind]:
		return
	_kind = kind
	_alpha = 1.0
	_pop = KINDS[kind][4]
	queue_redraw()


func _process(delta: float) -> void:
	if _alpha > 0.0:
		_alpha = maxf(_alpha - delta / float(KINDS[_kind][3]), 0.0)
		_pop = move_toward(_pop, 1.0, delta / POP_TIME * (KINDS[_kind][4] - 1.0))
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var k: Array = KINDS[_kind]
	var c: Color = k[0]
	c.a = _alpha
	var gap := GAP * _pop
	var len := LEN * float(k[1]) * _pop
	var w: float = k[2]
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n := d.normalized()
		draw_line(center + n * gap, center + n * (gap + len), Color(0, 0, 0, _alpha * 0.6), w + 2.0, true)
		draw_line(center + n * gap, center + n * (gap + len), c, w, true)
	if _kind == &"pop":
		var cross := POP_CROSS
		cross.a = _alpha
		for n: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var a := center + n * gap * 1.6
			var b := center + n * (gap * 1.6 + len * 0.6)
			draw_line(a, b, Color(0, 0, 0, _alpha * 0.6), w + 1.0, true)
			draw_line(a, b, cross, w - 1.0, true)
