extends Control
## The heads-up display (UiStyle): symmetric about the middle of the screen, no boxes.
## Top centre, the one big thing: what is left of the heap, the game's goal, over a brass progress
## bar, "Yığında kalan" and the keys found under its two ends.
## Bottom left: the magazine big, the hand under it. Bottom right, its mirror: gold big in green,
## the team vault under it. Bottom centre: the guns as key caps with names, the one in hand bright
## and underlined in brass, and above them a special round's state. Top right: the Q key cap and
## "Geliştirmeler", brass when the gold reaches an upgrade. Listens to GameState itself.

const KeyCache := preload("res://scripts/key_cache.gd")
const MARGIN := Vector2(36, 28)  # px from the screen's edges
const BIG := 60  # px, the two big numbers
const HEAP_W := 340.0  # px, the heap's bar
const MONEY := UiStyle.MONEY  # kept for older callers

var _heap: Label
var _heap_meter: Control
var _keys: Label
var _mag_caption: Label
var _mag: Label
var _mag_of: Label
var _hand: Label
var _gold: Label
var _vault: Label
var _special_row: HBoxContainer
var _special: Label
var _special_hint: Control
var _can_buy: Label
var _q: PanelContainer
var _guns: HBoxContainer
var _test: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.fit_screen(self)
	_build_heap()
	_build_sides()
	_build_middle()
	_build_corner()
	_test = UiStyle.hint("T", "Test modu: sınırsız mermi")
	(_test.get_child(1) as Label).add_theme_color_override("font_color", UiStyle.ACCENT)
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
	var col := _column(Control.PRESET_CENTER_TOP)
	col.offset_top = MARGIN.y - 8
	col.add_theme_constant_override("separation", 6)
	_heap = UiStyle.display("", 40, UiStyle.BOLD)
	_heap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_heap)
	_heap_meter = UiStyle.meter(HEAP_W, UiStyle.ACCENT, 3.0)
	_heap_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_heap_meter)
	var under := HBoxContainer.new()
	under.custom_minimum_size.x = HEAP_W
	under.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(under)
	var left := UiStyle.caption("Yığında kalan")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	under.add_child(left)
	_keys = UiStyle.caption("")
	under.add_child(_keys)


func _build_sides() -> void:
	for right in [false, true]:
		var col := _column(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT)
		col.offset_left = 0 if right else MARGIN.x
		col.offset_right = -MARGIN.x if right else 0
		col.offset_bottom = -MARGIN.y
		col.add_theme_constant_override("separation", -6)
		var align := HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		var caption := UiStyle.caption("Altın" if right else "Şarjör")
		caption.horizontal_alignment = align
		col.add_child(caption)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(row)
		var big := UiStyle.display("", BIG, UiStyle.SEMIBOLD, MONEY if right else UiStyle.WHITE)
		row.add_child(big)
		var small := UiStyle.label("", 15, UiStyle.MEDIUM, UiStyle.DIM)
		small.horizontal_alignment = align
		col.add_child(small)
		if right:
			_gold = big
			_vault = small
		else:
			_mag_caption = caption
			_mag = big
			_mag_of = UiStyle.display("", 28, UiStyle.MEDIUM, UiStyle.DIM)
			_mag_of.size_flags_vertical = Control.SIZE_SHRINK_END
			row.add_child(_mag_of)
			_hand = small


func _build_middle() -> void:
	var col := _column(Control.PRESET_CENTER_BOTTOM)
	col.offset_bottom = -MARGIN.y
	col.add_theme_constant_override("separation", 14)
	_special_row = HBoxContainer.new()
	_special_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_special_row.add_theme_constant_override("separation", 12)
	_special_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_special_row)
	_special = UiStyle.label("", 15, UiStyle.SEMIBOLD)
	_special.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_special_row.add_child(_special)
	_special_hint = UiStyle.hint("R", "Basılı tut")
	_special_row.add_child(_special_hint)
	_guns = HBoxContainer.new()
	_guns.alignment = BoxContainer.ALIGNMENT_CENTER
	_guns.add_theme_constant_override("separation", 26)
	_guns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_guns)
	for i in range(1, GameState.GUNS.size()):
		var gun := VBoxContainer.new()
		gun.add_theme_constant_override("separation", 7)
		gun.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UiStyle.keycap(str(i), 13))
		var name_ := UiStyle.display(GameState.GUNS[i].name, 19, UiStyle.SEMIBOLD)
		name_.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_)
		gun.add_child(row)
		var mark := UiStyle.line(0, UiStyle.ACCENT)
		mark.custom_minimum_size.y = 2
		gun.add_child(mark)
		_guns.add_child(gun)


func _build_corner() -> void:
	var corner := _column(Control.PRESET_TOP_RIGHT)
	corner.offset_right = -MARGIN.x
	corner.offset_top = MARGIN.y
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(row)
	_can_buy = UiStyle.label("", 16, UiStyle.SEMIBOLD)
	_can_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_can_buy)
	_q = UiStyle.keycap("Q", 20)
	row.add_child(_q)


## Everything from GameState as it is now.
func refresh() -> void:
	var p := GameState.player()
	_heap.text = UiStyle.dotted(GameState.pile)
	UiStyle.set_meter(_heap_meter, float(GameState.pile) / GameState.PILE_START)
	_keys.text = "Anahtar %d / %d" % [p.keys.size(), KeyCache.KEYS.size()]
	if p.gun == 0:  # bare fists: the hand is all there is
		_mag_caption.text = "Elde"
		_mag.text = str(GameState.carried)
		_mag_of.text = "/ %d" % GameState.carry_capacity
		_hand.text = "Silah yok"
	else:
		_mag_caption.text = "Şarjör"
		_mag.text = str(GameState.loaded)
		_mag_of.text = "/ %d" % GameState.mag_capacity
		_hand.text = "Elde %d / %d" % [GameState.carried, GameState.carry_capacity]
	_mag.add_theme_color_override("font_color", UiStyle.WARN if p.gun != 0 and GameState.loaded == 0 else UiStyle.WHITE)
	_gold.text = "$" + UiStyle.dotted(GameState.gold)
	_vault.text = "Takım kasası $%s" % UiStyle.dotted(floori(GameState.vault))
	_special_row.visible = true
	if p.armed != "":
		_special.text = "%s takılı" % GameState.SPECIALS[p.armed].name
		_special.add_theme_color_override("font_color", UiStyle.ACCENT)
		_special_hint.visible = false
	elif not p.specials.is_empty():
		_special.text = "Özel mermi ×%d" % p.specials.size()
		_special.add_theme_color_override("font_color", UiStyle.WHITE)
		_special_hint.visible = true
	else:
		_special_row.visible = false
	for i in _guns.get_child_count():
		var on := i + 1 == p.gun
		var gun := _guns.get_child(i) as Control
		gun.get_child(1).modulate.a = 1.0 if on else 0.0  # the underline
		gun.modulate.a = 1.0 if on else (0.5 if GameState.gun_open(i + 1) else 0.22)
	_guns.get_parent().visible = not p.placing  # placement keeps its keys here
	var can := GameState.UPGRADES.keys().any(func(id: String) -> bool:
		var costs: Array = GameState.UPGRADES[id].costs
		return p.levels[id] < costs.size() and GameState.gold >= costs[p.levels[id]])
	_can_buy.text = "Geliştirme alınabilir" if can else "Geliştirmeler"
	_can_buy.add_theme_color_override("font_color", UiStyle.ACCENT if can else UiStyle.DIM)
	UiStyle.tint_keycap(_q, UiStyle.ACCENT if can else UiStyle.WHITE)
	_test.visible = GameState.infinite_ammo


## A number that went up gives a small start.
func _pop(l: Label) -> void:
	l.pivot_offset = Vector2(l.size.x, l.size.y * 0.6)
	l.scale = Vector2.ONE * 1.08
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _column(preset: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.set_anchors_and_offsets_preset(preset)  # plain set_anchors_preset freezes today's screen size into the offsets
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_RIGHT, Control.PRESET_TOP_RIGHT] else (Control.GROW_DIRECTION_BOTH if preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM] else Control.GROW_DIRECTION_END)
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM] else Control.GROW_DIRECTION_END
	return col
