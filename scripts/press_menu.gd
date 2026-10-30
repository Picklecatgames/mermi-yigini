extends "res://scripts/station_view.gd"
## The press's screen (GameState.PRESS_POS, the bench's low stand), opened with E in front of it
## (player.gd). In the bench's way (station_view.gd): the camera goes to the press. Left: the
## team's brass (an ingot and a number) and the rounds the press makes (GameState.PRESS_ROUNDS), the
## ones past its level shut. Right: the one picked, what it does, how many the player has, how many
## to make (−, +, HEPSİ, the wheel; Shift ×10), brass in -> rounds out, "ÜRET"
## (GameState.request_press: the team's brass, the player's rounds; the handle turns down); under it
## the next die and the round it makes, paid like the hopper's. Few words, few numbers (the user).

const PULL := 1.1  # rad the handle turns down per pull
const ICONS := {"clone": "clone", "electric": "electric", "heavy": "heavy"}  # UiStyle.item

var _brass: Label
var _list: VBoxContainer
var _icon: TextureRect
var _name: Label
var _desc: Label
var _owned: Label
var _next_icon: TextureRect  # the round the next die makes
var _count: Label
var _in: Label
var _out: Label
var _out_icon: TextureRect
var _make: Button
var _made: Label  # "+12" floating up after a pull
var _level_state: Label
var _buy: Button
var _till := AudioStreamPlayer.new()
var _picked := "clone"
var _amount := 1


func _ready() -> void:
	name = "PressMenu"  # pause_menu.gd leaves Esc to us while we're open
	_build_frame("PRES")
	_till.stream = preload("res://assets/sounds/ui/purchase.ogg")
	_till.bus = &"Arayuz"
	_till.volume_db = -12.0  # as the bench's till
	add_child(_till)
	_brass = _stat(_left, "", "ingot", UiStyle.ACCENT)  # the brass: the ingot says it
	_left.add_child(UiStyle.line(340))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_left.add_child(_list)
	_right.add_child(_build_round())
	_right.add_child(_build_level())
	GameState.rounds_changed.connect(func() -> void:
		if visible:
			_refresh())


## The round picked: itself, its name, what it does, how many are ours; how many to make; brass in,
## rounds out; make. No more words or numbers than that (2026-10-28, the user: "too much text").
func _build_round() -> Control:
	var card := _card("round", 22)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	_icon = UiStyle.item("clone", 56)
	top.add_child(_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	top.add_child(words)
	_name = UiStyle.display("", 28, UiStyle.BOLD)
	words.add_child(_name)
	_desc = UiStyle.label("", 14, UiStyle.REGULAR, UiStyle.DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_desc)
	_owned = UiStyle.display("", 28, UiStyle.BOLD)  # "×12": how many are ours
	_owned.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_owned)

	# How many: − n + and all the brass allows.
	var amount := HBoxContainer.new()
	amount.add_theme_constant_override("separation", 8)
	col.add_child(amount)
	var less := _step_button("−")
	less.pressed.connect(func() -> void: _step(-1))
	amount.add_child(less)
	_count = UiStyle.display("", 40, UiStyle.BOLD)
	_count.custom_minimum_size.x = 96
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_child(_count)
	var more := _step_button("+")
	more.pressed.connect(func() -> void: _step(1))
	amount.add_child(more)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.add_child(room)
	var all := _step_button("HEPSİ", 96)
	all.pressed.connect(func() -> void:
		_amount = maxi(1, _most())
		_refresh())
	amount.add_child(all)

	# What goes in, what comes out.
	var sum := HBoxContainer.new()
	sum.add_theme_constant_override("separation", 10)
	sum.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(sum)
	sum.add_child(UiStyle.item("ingot", 40))
	_in = UiStyle.display("", 32, UiStyle.BOLD, UiStyle.ACCENT)
	sum.add_child(_in)
	sum.add_child(_arrow(22, UiStyle.DIM))
	_out_icon = UiStyle.item("clone", 40)
	sum.add_child(_out_icon)
	_out = UiStyle.display("", 32, UiStyle.BOLD, UiStyle.MONEY)
	sum.add_child(_out)

	_make = _price_button(Vector2(0, 56), 28, "make")
	_make.text = "ÜRET"
	_make.pressed.connect(_press)
	col.add_child(_make)
	_made = UiStyle.display("", 30, UiStyle.BOLD, UiStyle.MONEY)
	_made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_made.modulate.a = 0.0
	_made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_made)  # over the card, out of its layout
	return card


## The press's next die: the round it makes, its price.
func _build_level() -> Control:
	var card := _card("die")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	_next_icon = UiStyle.item("electric", 52)
	row.add_child(_next_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_level_state = _card_words(words, "YENİ KALIP", "")
	_buy = _price_button(Vector2(130, 50), 22, "die")
	_buy.pressed.connect(func() -> void:
		if GameState.request_upgrade_station("press"):
			_till.play()
		_refresh())
	row.add_child(_buy)
	return card


## In front of the press, at its head: the handle on the right of the view, the stand under it.
func _view() -> Array:
	var at := GameState.PRESS_POS
	return [at + Vector3(0.0, 1.75, -1.25), at + Vector3(0.0, 1.4, 0.0)]


## In front of the press once it is open (player.gd asks, then calls open).
func can_open() -> bool:
	if visible or not GameState.unlocked("hand_press"):
		return false
	var me: Vector3 = get_parent().global_position
	return Vector2(me.x - GameState.PRESS_POS.x, me.z - GameState.PRESS_POS.z).length() <= GameState.STATION_REACH


func open() -> void:
	if GameState.PRESS_ROUNDS[_picked].level > GameState.press_level:
		_picked = "clone"
	_amount = maxi(1, mini(_amount, _most()))
	super.open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventMouseButton:
		return
	var b := event as InputEventMouseButton
	if b.pressed and b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_step((1 if b.button_index == MOUSE_BUTTON_WHEEL_UP else -1) * (10 if b.shift_pressed else 1))
	get_viewport().set_input_as_handled()


func _step(by: int) -> void:
	if Input.is_key_pressed(KEY_SHIFT) and absi(by) == 1:
		by *= 10
	_amount = clampi(_amount + by, 1, maxi(1, _most()))
	_refresh()


## As many of the picked round as the brass makes.
func _most() -> int:
	return floori(GameState.brass / float(GameState.PRESS_ROUNDS[_picked].brass))


func _press() -> void:
	var made := GameState.request_press(_picked, _amount)
	if made > 0:
		_pull()
		_float_made(made)
	_amount = maxi(1, mini(_amount, _most()))
	_refresh()


## The handle on the press turns down and springs back.
func _pull() -> void:
	var press := get_tree().get_first_node_in_group("press")
	var handle: Node3D = press.find_child("Handle", true, false) if press else null
	if handle == null:
		return
	if not handle.has_meta("rest"):
		handle.set_meta("rest", handle.rotation.x)
	var rest: float = handle.get_meta("rest")
	var tw := handle.create_tween()
	tw.tween_property(handle, "rotation:x", rest - PULL, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(handle, "rotation:x", rest, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## "+12" rises off the count the player has, where they went, and fades.
func _float_made(n: int) -> void:
	_made.text = "+" + UiStyle.dotted(n)
	_made.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var r := _owned.get_global_rect()
	_made.size = Vector2(160, 40)
	var at := Vector2(r.end.x - 160 - r.size.x - 8, r.position.y)
	_made.global_position = at
	_made.modulate.a = 1.0
	var tw := _made.create_tween().set_parallel()
	tw.tween_property(_made, "global_position:y", at.y - 28, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_made, "modulate:a", 0.0, 0.5).set_delay(0.5)
	_owned.pivot_offset = _owned.size * Vector2(1.0, 0.5)
	var pop := _owned.create_tween()
	pop.tween_property(_owned, "scale", Vector2.ONE * 1.3, 0.08)
	pop.tween_property(_owned, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	super._refresh()
	_brass.text = UiStyle.dotted(GameState.brass)
	_fill_list()
	var r: Dictionary = GameState.PRESS_ROUNDS[_picked]
	var per: int = r.brass
	_icon.texture = load("res://assets/ui/items/%s.png" % ICONS[_picked])
	_out_icon.texture = _icon.texture
	_name.text = String(r.name).to_upper()
	_desc.text = r.desc
	_owned.text = "×" + UiStyle.dotted(GameState.player().rounds.get(_picked, 0))
	var most := _most()
	_amount = clampi(_amount, 1, maxi(1, most))
	_count.text = UiStyle.dotted(_amount)
	_in.text = UiStyle.dotted(_amount * per)
	_out.text = UiStyle.dotted(_amount)
	var short := most < 1
	_in.add_theme_color_override("font_color", UiStyle.WARN if short else UiStyle.ACCENT)
	_make.disabled = short
	_make.text = "PİRİNÇ YETMİYOR" if short else "ÜRET"

	var level := GameState.press_level
	_buy.get_parent().get_parent().visible = level < GameState.PRESS_COSTS.size()  # every die had: no card
	if level >= GameState.PRESS_COSTS.size():
		_buy.text = "EN ÜST"
		_buy.disabled = true
		return
	for id: String in GameState.PRESS_ROUNDS:
		if GameState.PRESS_ROUNDS[id].level == level + 1:
			_level_state.text = GameState.PRESS_ROUNDS[id].name
			_next_icon.texture = load("res://assets/ui/items/%s.png" % ICONS[id])
	var cost: int = GameState.PRESS_COSTS[level]
	_buy.text = "$" + UiStyle.dotted(cost)
	_buy.disabled = _have() < cost


## One row per round, as the bench's gun rows: itself and its name; past the press's level shut.
func _fill_list() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	for id: String in GameState.PRESS_ROUNDS:
		var r: Dictionary = GameState.PRESS_ROUNDS[id]
		var shut: bool = r.level > GameState.press_level
		var on := id == _picked
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = Vector2(340, 58)
		b.disabled = shut
		var tint := Color(0.62, 0.58, 0.46) if on else UiStyle.PLATE_GREY  # the picked one warmer
		for s: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var t := tint.lightened(0.12) if s == "hover" else (Color(0.26, 0.27, 0.26) if s == "disabled" else tint)
			b.add_theme_stylebox_override(s, UiStyle.plate("row", id, t, 10) if s != "focus" else StyleBoxEmpty.new())
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 14
		row.offset_right = -14
		row.add_theme_constant_override("separation", 10)
		b.add_child(row)
		row.add_child(UiStyle.item(ICONS[id], 40, shut))
		var n := UiStyle.display(String(r.name).to_upper(), 24, UiStyle.BOLD, Color(UiStyle.DIM, 0.55) if shut else UiStyle.WHITE)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(n)
		if shut:
			row.add_child(UiStyle.icon("padlock", 18, Color(UiStyle.DIM, 0.7)))
		b.pressed.connect(func() -> void:
			_picked = id
			_amount = maxi(1, mini(_amount, _most()))
			_refresh())
		_list.add_child(b)
