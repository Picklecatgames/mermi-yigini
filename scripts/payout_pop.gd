extends Node3D
## Pooled "+$n" labels that pop over a target, rise and fade. Fixed size on screen, so they
## read the same from across the range.

const POOL := 8
const RISE := 0.55    # m
const TIME := 0.9     # s
const GREEN := Color(0.33, 1.0, 0.42)
const GOLD := Color(1.0, 0.8, 0.2)  # weak-spot payout

var _labels: Array[Label3D] = []
var _next := 0


func _ready() -> void:
	for i in POOL:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.00066
		l.font_size = 96
		l.outline_size = 22
		l.render_priority = 10
		l.outline_render_priority = 9
		l.visible = false
		l.top_level = true
		add_child(l)
		_labels.append(l)


## Only the shooter (`peer`) sees what they earned; the others still see the target react.
func pop(gold: int, at: Vector3, weak := false, peer := 0) -> void:
	if peer != 0 and peer != GameState.local_peer():
		return
	var l := _labels[_next]
	_next = (_next + 1) % POOL
	var old: Tween = l.get_meta("tween") if l.has_meta("tween") else null
	if old and old.is_valid():
		old.kill()
	var color := GOLD if weak else GREEN
	l.text = "+$%d" % gold
	l.visible = true
	l.global_position = at + Vector3(randf_range(-0.08, 0.08), 0.05, 0.0)
	l.modulate = color
	l.outline_modulate = Color(color.darkened(0.88), 1.0)
	l.scale = Vector3.ONE * 1.6
	var t := create_tween().set_parallel()
	l.set_meta("tween", t)
	t.tween_property(l, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "global_position:y", l.global_position.y + RISE, TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, TIME * 0.45).set_delay(TIME * 0.55)
	t.tween_property(l, "outline_modulate:a", 0.0, TIME * 0.45).set_delay(TIME * 0.55)
	t.chain().tween_callback(func() -> void: l.visible = false)
