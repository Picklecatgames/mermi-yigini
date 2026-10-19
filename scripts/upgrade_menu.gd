extends CanvasLayer
## Upgrade screen, toggled with Q (Esc also closes). Rows come from GameState.UPGRADES, so a
## new upgrade only needs a name and description here. The game keeps running behind it (co-op).

const INFO := {
	"capacity": ["Kapasite", "Elde ve şarjörde taşınan mermi"],
}
const GREEN := Color(0.33, 1.0, 0.42)
const DIM := Color(0.62, 0.65, 0.7)
const LOCKED := Color(0.95, 0.42, 0.38)

var _money: Label
var _rows := {}  # id -> {value, button, pips}


func _ready() -> void:
	layer = 5
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.09, 0.11, 0.96)
	box.border_color = Color(0.22, 0.25, 0.3)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(_label("GELİŞTİRMELER", 28, Color.WHITE))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_money = _label("", 28, GREEN)
	head.add_child(_money)
	col.add_child(HSeparator.new())
	for id in GameState.UPGRADES:
		col.add_child(_row(id))
	col.add_child(HSeparator.new())
	var hint := _label("[Q] Kapat", 15, DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	GameState.gold_changed.connect(_refresh.unbind(1))
	GameState.upgraded.connect(_refresh.unbind(2))
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrades") or (visible and event.is_action_pressed("ui_cancel")):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	if visible:
		_refresh()


func _row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	left.add_child(_label(INFO[id][0], 22, Color.WHITE))
	left.add_child(_label(INFO[id][1], 15, DIM))
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 5)
	for i in GameState.UPGRADES[id].values.size():
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(22, 8)
		pips.add_child(p)
	left.add_child(pips)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	var value := _label("", 20, Color.WHITE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(value)
	var button := Button.new()
	button.custom_minimum_size = Vector2(170, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_NONE  # mouse only: Space must keep jumping, not buy
	var off := StyleBoxFlat.new()  # disabled still reads as a button, just not a pressable one
	off.bg_color = Color(0.12, 0.13, 0.15)
	off.border_color = Color(0.3, 0.32, 0.36)
	off.set_border_width_all(1)
	off.set_corner_radius_all(4)
	button.add_theme_stylebox_override("disabled", off)
	button.pressed.connect(func() -> void:
		if GameState.request_buy_upgrade(id):
			_bump(row))
	right.add_child(button)
	_rows[id] = {"value": value, "button": button, "pips": pips}
	return row


func _refresh() -> void:
	_money.text = "$%d" % GameState.gold
	for id in _rows:
		var r: Dictionary = _rows[id]
		var level: int = GameState.player().levels[id]
		var values: Array = GameState.UPGRADES[id].values
		var costs: Array = GameState.UPGRADES[id].costs
		for i in (r.pips as Control).get_child_count():
			((r.pips as Control).get_child(i) as ColorRect).color = GREEN if i <= level else Color(0.22, 0.24, 0.28)
		var b: Button = r.button
		if level >= costs.size():
			(r.value as Label).text = str(values[level])
			b.text = "MAKS"
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", GREEN)
			continue
		(r.value as Label).text = "%d  →  %d" % [values[level], values[level + 1]]
		b.text = "$%d  Satın al" % costs[level]
		b.disabled = GameState.gold < costs[level]
		b.add_theme_color_override("font_disabled_color", LOCKED)


func _bump(row: Control) -> void:
	row.pivot_offset = row.size / 2.0
	row.scale = Vector2.ONE * 1.04
	row.modulate = Color(1.4, 1.6, 1.4)
	var t := create_tween().set_parallel()
	t.tween_property(row, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(row, "modulate", Color.WHITE, 0.3)


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
