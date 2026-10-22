extends CanvasLayer
## The workshop, toggled with Q (Esc also closes), in UiStyle: no boxes, text on the dimmed view.
## Top: the player's gold on the left, the team vault mirrored on the right, the two tabs between
## them (the player's own upgrades, GameState.UPGRADES, paid from their gold; the team's gear,
## GameState.GEAR, paid from the vault). Under a rule, five columns of cards, each standing under
## its own thin rule. An upgrade card walks a track of its levels (bought lit, the next one in the
## accent, beating); a gear card turns its target's model. Whatever the money reaches is bright,
## its price line and "al" in the accent; the rest wait faded. Buying sweeps the accent along the
## card's rule, lights the new level and swells the new value. The game keeps running behind it.

const INFO := {
	"carry": ["El Kapasitesi", "%d"],
	"magazine": ["Şarjör", "%d"],
	"combo_cap": ["Kombo Tavanı", "x%d"],
	"gold_bonus": ["Altın", "+%d%%"],
	"range_bonus": ["Uzak Atış", "+%d%%/m"],
}
const GEAR_INFO := {  # gold per hit, difficulty 1-5 (name: GameState.GEAR)
	"dummy": [1, 1],
	"popper": [3, 2],
	"steel_rack": [4, 3],
	"plate_rack": [7, 4],
	"texas_star": [12, 5],
	"barrel": [5, 2],
	"scarecrow": [1, 1],
	"armored_dummy": [10, 3],
	"pendulum": [8, 4],
	"twin_gong": [2, 4],
	"gold_dummy": [10, 4],
	"ricochet": [9, 5],
}
const HUD := preload("res://scripts/hud.gd")  # its dotted numbers
const COLUMNS := 5
const CARD_W := 188.0  # px
const MODEL_H := 120.0  # px, a gear card's turning model
const MAX_SIZE := Vector2(1180, 680)  # px; small windows keep a margin round it
const SIDE_W := 220.0  # px, the gold and the vault: equal so the tabs sit in the middle
const WAITING := 0.55  # a card the money does not reach yet

var _tab := 0
var _frame: VBoxContainer
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _subtitle: Label
var _money: Label
var _vault: Label
var _gold_shown := 0.0  # what the gold figure reads while it counts to the real one
var _models_built := false
var _cards := {}  # id -> {card, meter, need, button, ready, and level/value/next/track or stock/model}


## A level track: one mark per level on a thin line; bought ones lit, the next one in the accent
## and beating, the rest faint. `flash` (1 just after a buy) swells the newest mark.
class Track extends Control:
	var levels := 1
	var level := 0
	var flash := 0.0:
		set(v):
			flash = v
			queue_redraw()

	func _init(n: int) -> void:
		levels = n
		custom_minimum_size = Vector2(0, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if level < levels and is_visible_in_tree():
			queue_redraw()  # the next mark beats

	func _draw() -> void:
		var y := roundf(size.y / 2.0)
		var at := func(i: int) -> float: return roundf(3.0 + (size.x - 6.0) * i / maxf(levels - 1, 1))
		draw_rect(Rect2(0, y, size.x, 1), UiStyle.LINE)
		if level > 0:
			draw_rect(Rect2(0, y, at.call(level - 1), 1), UiStyle.WHITE)
		var beat := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		for i in levels:
			var x: float = at.call(i)
			var s := 4.0
			var c := Color(1, 1, 1, 0.35)
			if i < level:
				s = 6.0 + (8.0 * flash if i == level - 1 else 0.0)
				c = UiStyle.WHITE.lerp(UiStyle.ACCENT, flash) if i == level - 1 else UiStyle.WHITE
			elif i == level:
				s = 8.0
				c = Color(UiStyle.ACCENT, beat)
			draw_rect(Rect2(x - s / 2.0, y - s / 2.0 + 0.5, s, s).abs(), c)


func _ready() -> void:
	layer = 5
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_frame = VBoxContainer.new()
	_frame.add_theme_constant_override("separation", 14)
	center.add_child(_frame)
	_frame.add_child(_header())
	_frame.add_child(UiStyle.line())
	_subtitle = _centred(UiStyle.caption(""))
	_frame.add_child(_subtitle)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(stack)
	_pages.append(_page(GameState.UPGRADES.keys(), _upgrade_card))
	_pages.append(_page(GameState.GEAR.keys(), _gear_card))
	for p in _pages:
		stack.add_child(p)
	_frame.add_child(_centred(UiStyle.caption("q  ·  kapat")))
	GameState.gold_changed.connect(_refresh.unbind(1))
	GameState.upgraded.connect(_refresh.unbind(2))
	GameState.vault_changed.connect(_refresh.unbind(1))
	GameState.gear_changed.connect(_refresh.unbind(1))
	_show_tab(0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrades") or (visible and event.is_action_pressed("ui_cancel")):
		toggle()
		get_viewport().set_input_as_handled()


## A click or wheel turn the cards let pass would reach player.gd, which takes the mouse back
## into the game: while open the workshop keeps every mouse button to itself.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	var hud := get_node_or_null("../HUD") as CanvasLayer  # the player's: its top line would cross the tabs
	if hud:
		hud.visible = not visible
	# The placement overview keeps its cursor when the workshop closes over it.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible or GameState.player().placing else Input.MOUSE_MODE_CAPTURED
	if visible:
		_gold_shown = GameState.gold
		_show_tab(_tab)


## What the money reaches beats softly: its "al" breathes in the accent.
func _process(_delta: float) -> void:
	if not visible:
		return
	var a := 0.72 + 0.28 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	for c: Dictionary in _cards.values():
		(c.button as Control).modulate.a = a if c.ready else 1.0


# --- layout -----------------------------------------------------------------------------------

## Gold | tabs | vault, the two sides mirrored like the HUD's corners.
func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_child(_wallet("", false))  # the player's own: "$" says enough
	var tabs := HBoxContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 44)
	row.add_child(tabs)
	tabs.add_child(_tab_button(0))
	tabs.add_child(_tab_button(1))
	row.add_child(_wallet("takım kasası", true))
	return row


func _wallet(caption: String, right: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = SIDE_W
	col.add_theme_constant_override("separation", 0)
	var align := HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	var c := UiStyle.caption(caption if caption != "" else " ")  # blank still holds the line: the figures stay level
	c.horizontal_alignment = align
	col.add_child(c)
	var big := UiStyle.label("", 36, UiStyle.LIGHT, HUD.MONEY)
	big.horizontal_alignment = align
	col.add_child(big)
	if right:
		_vault = big
	else:
		_money = big
	return col


## A tab is its name in text, underlined when open. Names are set in _show_tab: the player's
## name arrives after joining.
func _tab_button(index: int) -> Button:
	var b := _flat_button()
	b.custom_minimum_size.y = 32
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # the header row is as tall as the big numbers
	var title := UiStyle.label("", 20, UiStyle.MEDIUM)
	title.name = "Title"
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	b.add_child(title)
	var under := UiStyle.line(0, UiStyle.WHITE)
	under.name = "Under"
	under.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	under.offset_top = -1
	b.add_child(under)
	b.pressed.connect(_show_tab.bind(index))
	_tabs.append(b)
	return b


func _show_tab(index: int) -> void:
	_tab = index
	var screen := get_viewport().get_visible_rect().size
	_frame.custom_minimum_size = Vector2(minf(MAX_SIZE.x, screen.x * 0.92), minf(MAX_SIZE.y, screen.y * 0.9))
	var titles := [GameState.display_name(), "Teçhizat"]
	for i in _tabs.size():
		var on := i == index
		var title := _tabs[i].find_child("Title", true, false) as Label
		title.text = titles[i]
		_tabs[i].custom_minimum_size.x = title.get_minimum_size().x
		_tabs[i].modulate.a = 1.0 if on else 0.45
		(_tabs[i].find_child("Under", true, false) as Control).visible = on
		_pages[i].visible = on
	_subtitle.text = ["", "ortak kasadan  ·  bütün takım kullanır  ·  b ile kur"][index]
	if index == 1 and not _models_built:  # built on first look: fifteen small worlds
		_models_built = true
		for id in GameState.GEAR:
			(_cards[id].model as Control).add_child(_model_view(id))
	_refresh()


func _page(ids: Array, make: Callable) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL  # a short page sits in the middle
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 30)
	center.add_child(grid)
	for id in ids:
		grid.add_child(make.call(id))
	return scroll


## A card: its rule on top, the caller's middle, a line toward the price, what is missing and "al".
func _card(id: String, body: Control, buy: Callable) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = CARD_W
	card.add_theme_constant_override("separation", 8)
	var rule := UiStyle.line()
	card.add_child(rule)
	card.add_child(body)
	var meter := UiStyle.meter(CARD_W)
	card.add_child(meter)
	var foot := HBoxContainer.new()
	card.add_child(foot)
	var need := UiStyle.caption("")
	need.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	need.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(need)
	var button := _flat_button()
	button.add_theme_font_override("font", UiStyle.face(UiStyle.MEDIUM))
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_hover_color", UiStyle.WHITE)
	button.add_theme_color_override("font_pressed_color", UiStyle.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(UiStyle.DIM, 0.6))
	button.pressed.connect(func() -> void:
		if buy.call():
			_celebrate(id, rule))
	foot.add_child(button)
	_cards[id] = {"card": card, "meter": meter, "need": need, "button": button, "ready": false}
	return card


func _upgrade_card(id: String) -> Control:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var level := UiStyle.caption("")
	body.add_child(level)
	body.add_child(UiStyle.label(INFO[id][0], 18, UiStyle.MEDIUM))
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 10)
	body.add_child(values)
	var value := UiStyle.label("", 30, UiStyle.LIGHT)
	values.add_child(value)
	var next := UiStyle.label("", 18, UiStyle.LIGHT, UiStyle.ACCENT)
	next.size_flags_vertical = Control.SIZE_SHRINK_END
	values.add_child(next)
	var track := Track.new(GameState.UPGRADES[id].costs.size())
	body.add_child(track)
	var card := _card(id, body, func() -> bool: return GameState.request_buy_upgrade(id))
	_cards[id].merge({"level": level, "value": value, "next": next, "track": track})
	return card


func _gear_card(id: String) -> Control:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var model := Control.new()  # its turning model comes in on the first look (_show_tab)
	model.custom_minimum_size = Vector2(CARD_W, MODEL_H)
	model.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(model)
	var hard: int = GEAR_INFO[id][1]
	var diff := _pips(5)
	for i in hard:
		(diff.get_child(i) as ColorRect).color = UiStyle.WHITE
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UiStyle.caption("zorluk"))
	diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(diff)
	body.add_child(top)
	body.add_child(UiStyle.label(GameState.GEAR[id].name, 18, UiStyle.MEDIUM))
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 10)
	body.add_child(values)
	var value := UiStyle.label("$%d" % GEAR_INFO[id][0], 30, UiStyle.LIGHT)
	values.add_child(value)
	var per := UiStyle.caption("isabet başı")
	per.size_flags_vertical = Control.SIZE_SHRINK_END
	values.add_child(per)
	var stock := UiStyle.caption("")
	body.add_child(stock)
	var card := _card(id, body, func() -> bool:
		if not GameState.request_buy_gear(id):
			return false
		_to_placing.call_deferred(id)  # after the "+1" floats up: shut the workshop, go put it up
		return true)
	_cards[id].merge({"stock": stock, "model": model, "value": value})
	return card


## The piece turning slowly on its own, lit like the round picker's rounds: a copy of its meshes
## (with their own materials) in a little world of its own, framed to fit.
func _model_view(id: String) -> SubViewportContainer:
	var holder := SubViewportContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	holder.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.58, 0.55)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.6, 0.0)
	key.light_energy = 1.6
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI - 0.4, 0.0)
	rim.light_energy = 0.8
	vp.add_child(rim)
	var turn := Node3D.new()
	vp.add_child(turn)
	# Many pieces build their meshes in _ready: the original enters the tree a moment, hidden and
	# still, and is freed at once (as placement.gd's see-through copy does).
	var src: Node3D = load(GameState.GEAR[id].scene).instantiate()
	src.process_mode = Node.PROCESS_MODE_DISABLED
	src.visible = false
	add_child(src)
	var box := AABB()
	for m: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		if not m.mesh:
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = m.mesh
		copy.transform = src.global_transform.affine_inverse() * m.global_transform
		copy.material_override = m.material_override
		for s in m.get_surface_override_material_count():
			copy.set_surface_override_material(s, m.get_surface_override_material(s))
		turn.add_child(copy)
		var b := copy.transform * m.mesh.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	src.free()
	for c: Node3D in turn.get_children():  # its middle on the turning axis
		c.position -= Vector3(box.get_center().x, 0.0, box.get_center().z)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.environment = env
	var reach := maxf(box.size.y, Vector2(box.size.x, box.size.z).length() * 0.8)
	var far := reach * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 1.25
	var eye := Vector3(0, box.get_center().y + far * 0.25, far)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, box.get_center().y, 0) - eye), eye)
	vp.add_child(cam)
	turn.create_tween().set_loops().tween_property(turn, "rotation:y", TAU, 9.0).from(0.0)
	return holder


## Just bought a piece: straight into placement mode with it in hand, over the firing line.
func _to_placing(id: String) -> void:
	await get_tree().create_timer(0.35).timeout
	if visible:
		toggle()
	if not GameState.player().placing:
		GameState.request_toggle_placing()
	var placement := get_tree().get_first_node_in_group("placement")
	if placement:
		placement.focus(id)


# --- state ------------------------------------------------------------------------------------

func _refresh() -> void:
	if visible and roundi(_gold_shown) != GameState.gold:  # the figure counts to it
		create_tween().tween_method(func(v: float) -> void:
			_gold_shown = v
			_money.text = "$" + HUD._dotted(roundi(v)), _gold_shown, float(GameState.gold), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		_gold_shown = GameState.gold
		_money.text = "$" + HUD._dotted(GameState.gold)
	_vault.text = "$" + HUD._dotted(floori(GameState.vault))
	for id in GameState.UPGRADES:
		var c: Dictionary = _cards[id]
		var level: int = GameState.player().levels[id]
		var values: Array = GameState.UPGRADES[id].values
		var costs: Array = GameState.UPGRADES[id].costs
		var maxed := level >= costs.size()
		(c.level as Label).text = "seviye %d / %d" % [level, costs.size()]
		(c.track as Track).level = level
		(c.track as Track).queue_redraw()
		(c.value as Label).text = INFO[id][1] % values[level]
		(c.next as Label).text = "" if maxed else "→  " + INFO[id][1] % values[level + 1]
		_price(c, 0 if maxed else costs[level], GameState.gold, maxed)
	for id in GameState.GEAR:
		var c: Dictionary = _cards[id]
		var n: int = GameState.gear_stock.get(id, 0)
		(c.stock as Label).text = "depoda %d" % n
		(c.stock as Label).add_theme_color_override("font_color", UiStyle.WHITE if n > 0 else UiStyle.DIM)
		_price(c, GameState.GEAR[id].cost, floori(GameState.vault), false)


## The line toward the price, what is still missing, and "al". When the money reaches it the
## card is bright and its line, "hazır" and "al" turn to the accent; short of it the card fades.
func _price(c: Dictionary, cost: int, have: int, maxed: bool) -> void:
	var need: Label = c.need
	var b: Button = c.button
	var lit := (c.meter as Control).get_child(0) as ColorRect
	b.visible = not maxed
	c.ready = false
	if maxed:
		UiStyle.set_meter(c.meter, 1.0)
		lit.color = UiStyle.WHITE
		need.text = "en üst seviye"
		need.add_theme_color_override("font_color", UiStyle.DIM)
		(c.card as Control).modulate.a = 1.0
		return
	UiStyle.set_meter(c.meter, float(have) / cost)
	var ok := have >= cost
	c.ready = ok
	lit.color = UiStyle.ACCENT if ok else UiStyle.WHITE
	need.text = "hazır" if ok else "$%d eksik" % (cost - have)
	need.add_theme_color_override("font_color", UiStyle.ACCENT if ok else UiStyle.DIM)
	b.text = "al  $%d" % cost
	b.disabled = not ok
	b.add_theme_color_override("font_color", UiStyle.ACCENT if ok else UiStyle.WHITE)
	(c.card as Control).modulate.a = 1.0 if ok else WAITING


## A purchase: the accent sweeps along the card's rule, the new level's mark swells and settles,
## the value swells, and "+1" floats up.
func _celebrate(id: String, rule: Control) -> void:
	var c: Dictionary = _cards[id]
	var sweep := ColorRect.new()
	sweep.color = UiStyle.ACCENT
	sweep.size = Vector2(0, 1)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.add_child(sweep)
	var s := sweep.create_tween()
	s.tween_property(sweep, "size:x", rule.size.x, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	s.tween_property(sweep, "modulate:a", 0.0, 0.5)
	s.tween_callback(sweep.queue_free)
	if c.has("track"):
		var track: Track = c.track
		track.create_tween().tween_property(track, "flash", 0.0, 0.6).from(1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var value: Label = c.value
	value.pivot_offset = Vector2(0, value.size.y * 0.7)
	value.scale = Vector2.ONE * 1.3
	value.modulate = UiStyle.ACCENT
	var v := value.create_tween().set_parallel()
	v.tween_property(value, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	v.tween_property(value, "modulate", Color.WHITE, 0.6)
	var card: Control = c.card
	var up := UiStyle.label("+1 seviye" if _tab == 0 else "+1 depoya", 15, UiStyle.MEDIUM, UiStyle.ACCENT)
	up.top_level = true  # floats free of the card's container layout
	card.add_child(up)
	up.global_position = card.global_position + Vector2(0, -22)
	var f := up.create_tween().set_parallel()
	f.tween_property(up, "global_position:y", up.global_position.y - 30, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	f.tween_property(up, "modulate:a", 0.0, 0.5).set_delay(0.25)
	f.chain().tween_callback(up.queue_free)


# --- helpers ----------------------------------------------------------------------------------

## A row of short 2 px marks, unlit (difficulty).
func _pips(count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in count:
		var p := UiStyle.line(0, UiStyle.LINE)
		p.custom_minimum_size.y = 2
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
	return row


## A button that is only its text: no frame, no fill, mouse only (Space must keep jumping).
static func _flat_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	return b


func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
