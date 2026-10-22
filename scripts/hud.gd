extends Control
## The heads-up display (UiStyle): symmetric about the middle of the screen, no boxes.
## Top centre: what is left of the heap, the game's goal, over a thin progress rule, and the keys
## found in it.
## Bottom left: the magazine big, the hand under a rule. Bottom right, its mirror: gold big, the
## team vault under a rule. Bottom centre: the guns, the one in hand underlined, and above them a
## special round's state (loaded, or how many in the pocket). Top right: the way to the workshop,
## a big Q in a 1 px key outline beside "geliştirmeler", all in the accent when the gold reaches
## an upgrade. Listens to GameState itself.

const KeyCache := preload("res://scripts/key_cache.gd")
const MARGIN := Vector2(30, 24)  # px from the screen's edges
const BIG := 46  # px, the two big numbers
const SIDE_RULE := 130.0  # px
const MONEY := Color(0.33, 1.0, 0.42)  # dollar green

var _heap: Label
var _heap_meter: Control
var _keys: Label
var _mag_caption: Label
var _mag: Label
var _mag_of: Label
var _hand: Label
var _gold: Label
var _vault: Label
var _special: Label
var _can_buy: Label
var _q: Label
var _q_key: StyleBoxFlat
var _guns: HBoxContainer
var _test: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.fit_screen(self)
	_build_heap()
	_build_sides()
	_build_middle()
	_test = UiStyle.caption("test modu  ·  T", UiStyle.ACCENT)
	_test.position = MARGIN
	add_child(_test)
	for s: StringName in [&"pile_changed", &"carried_changed", &"loaded_changed", &"gold_changed", &"vault_changed", &"specials_changed", &"placing_changed"]:
		GameState.connect(s, func(_a = null) -> void: refresh())
	GameState.upgraded.connect(refresh.unbind(2))
	GameState.gun_changed.connect(refresh.unbind(2))
	GameState.key_taken.connect(refresh.unbind(2))
	GameState.gold_changed.connect(func(_g: int) -> void: _pop(_gold))
	refresh()


func _build_heap() -> void:
	var col := _column(Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	col.offset_top = MARGIN.y - 6
	_heap = UiStyle.label("", 15)
	_heap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_heap)
	_heap_meter = UiStyle.meter(260)
	_heap_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_heap_meter)
	_keys = _centred(UiStyle.caption(""))
	col.add_child(_keys)


func _build_sides() -> void:
	for right in [false, true]:
		var col := _column(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT, HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)
		col.offset_left = 0 if right else MARGIN.x
		col.offset_right = -MARGIN.x if right else 0
		col.offset_bottom = -MARGIN.y
		var align := HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		var caption := UiStyle.caption(" " if right else "şarjör")  # the gold's "$" says enough; the blank keeps the corners level
		caption.horizontal_alignment = align
		col.add_child(caption)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(row)
		var big := UiStyle.label("", BIG, UiStyle.LIGHT, MONEY if right else UiStyle.WHITE)
		row.add_child(big)
		var rule := UiStyle.line(SIDE_RULE)
		rule.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
		col.add_child(rule)
		var small := UiStyle.label("", 14, UiStyle.REGULAR, UiStyle.DIM)
		small.horizontal_alignment = align
		col.add_child(small)
		if right:
			_gold = big
			_vault = small
		else:
			_mag_caption = caption
			_mag = big
			_mag_of = UiStyle.label("", 22, UiStyle.LIGHT, UiStyle.DIM)
			_mag_of.size_flags_vertical = Control.SIZE_SHRINK_END
			_mag_of.custom_minimum_size.y = 0
			row.add_child(_mag_of)
			_hand = small


func _build_middle() -> void:
	var col := _column(Control.PRESET_CENTER_BOTTOM, HORIZONTAL_ALIGNMENT_CENTER)
	col.offset_bottom = -MARGIN.y
	col.add_theme_constant_override("separation", 10)
	_special = UiStyle.caption("")
	_special.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_special)
	_guns = HBoxContainer.new()
	_guns.alignment = BoxContainer.ALIGNMENT_CENTER
	_guns.add_theme_constant_override("separation", 28)
	_guns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_guns)
	for i in range(1, GameState.GUNS.size()):
		var gun := VBoxContainer.new()
		gun.add_theme_constant_override("separation", 5)
		gun.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gun.add_child(_centred(UiStyle.label(GameState.GUNS[i].name, 14)))
		gun.add_child(UiStyle.line(0, UiStyle.WHITE))
		gun.add_child(_centred(UiStyle.caption(str(i))))
		_guns.add_child(gun)
	var corner := _column(Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	corner.offset_right = -MARGIN.x
	corner.offset_top = MARGIN.y
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(row)
	_can_buy = UiStyle.caption("")
	_can_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_can_buy)
	var key := PanelContainer.new()  # a key's outline, not a filled button (UiStyle)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_q_key = StyleBoxFlat.new()
	_q_key.draw_center = false
	_q_key.set_border_width_all(1)
	_q_key.set_content_margin_all(0)
	key.add_theme_stylebox_override("panel", _q_key)
	key.custom_minimum_size = Vector2(52, 52)
	_q = _centred(UiStyle.label("Q", 30, UiStyle.MEDIUM))
	_q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_child(_q)
	row.add_child(key)


## Everything from GameState as it is now.
func refresh() -> void:
	var p := GameState.player()
	_heap.text = _dotted(GameState.pile)
	UiStyle.set_meter(_heap_meter, float(GameState.pile) / GameState.PILE_START)
	_keys.text = "yığında kalan  ·  anahtar %d / %d" % [p.keys.size(), KeyCache.KEYS.size()]
	if p.gun == 0:  # bare fists: the hand is all there is
		_mag_caption.text = "elde"
		_mag.text = str(GameState.carried)
		_mag_of.text = "/ %d" % GameState.carry_capacity
		_hand.text = "silah yok"
	else:
		_mag_caption.text = "şarjör"
		_mag.text = str(GameState.loaded)
		_mag_of.text = "/ %d" % GameState.mag_capacity
		_hand.text = "elde %d / %d" % [GameState.carried, GameState.carry_capacity]
	_gold.text = "$" + _dotted(GameState.gold)
	_vault.text = "takım kasası $%s" % _dotted(floori(GameState.vault))
	if p.armed != "":
		_special.text = "%s takılı" % GameState.SPECIALS[p.armed].name.to_lower()
		_special.add_theme_color_override("font_color", UiStyle.ACCENT)
	elif not p.specials.is_empty():
		_special.text = "özel mermi %d  ·  R basılı tut" % p.specials.size()
		_special.add_theme_color_override("font_color", UiStyle.DIM)
	else:
		_special.text = ""
	for i in _guns.get_child_count():
		var on := i + 1 == p.gun
		var gun := _guns.get_child(i) as Control
		gun.get_child(1).modulate.a = 1.0 if on else 0.0  # the underline
		gun.modulate.a = 1.0 if on else (0.45 if GameState.gun_open(i + 1) else 0.2)
	_guns.get_parent().visible = not p.placing  # placement keeps its keys here
	var can := GameState.UPGRADES.keys().any(func(id: String) -> bool:
		var costs: Array = GameState.UPGRADES[id].costs
		return p.levels[id] < costs.size() and GameState.gold >= costs[p.levels[id]])
	_can_buy.text = "geliştirme alınabilir" if can else "geliştirmeler"
	_can_buy.add_theme_color_override("font_color", UiStyle.ACCENT if can else UiStyle.DIM)
	_q.add_theme_color_override("font_color", UiStyle.ACCENT if can else UiStyle.WHITE)
	_q_key.border_color = UiStyle.ACCENT if can else Color(1, 1, 1, 0.6)
	_test.visible = GameState.infinite_ammo


## A number that went up gives a small start.
func _pop(l: Label) -> void:
	l.pivot_offset = Vector2(l.size.x, l.size.y * 0.6)
	l.scale = Vector2.ONE * 1.08
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _column(preset: int, _align: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.set_anchors_and_offsets_preset(preset)  # plain set_anchors_preset freezes today's screen size into the offsets
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_RIGHT, Control.PRESET_TOP_RIGHT] else (Control.GROW_DIRECTION_BOTH if preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM] else Control.GROW_DIRECTION_END)
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM] else Control.GROW_DIRECTION_END
	return col


func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## 1234567 -> "1.234.567"
static func _dotted(n: int) -> String:
	var s := str(n)
	for i in range(s.length() - 3, 0, -3):
		s = s.insert(i, ".")
	return s
