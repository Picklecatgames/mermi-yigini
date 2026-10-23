extends CanvasLayer
## The workshop, toggled with Q (Esc also closes): a dark panel over the dimmed game. Top: the
## player's gold on the left, the team vault on the right, two tabs between them (the player's own
## upgrades, GameState.UPGRADES, paid from their gold; the team's gear, GameState.GEAR, paid from
## the vault). Below, five columns of cards. An upgrade card has its icon, level, the value now and
## after the next level, a row of level pips and a big buy button; a gear card turns its target's
## model. What the money reaches glows green and its button breathes; the rest wait dimmed. Buying
## pops the card, flashes it, throws coins off the button and floats "+1" up. The game keeps running.

const INFO := {  # name, value format, icon colour
	"carry": ["El Kapasitesi", "%d", Color(0.36, 0.72, 1.0)],
	"magazine": ["Şarjör", "%d", Color(1.0, 0.55, 0.25)],
	"combo_cap": ["Kombo Tavanı", "x%d", Color(0.85, 0.4, 1.0)],
	"gold_bonus": ["Altın", "+%d%%", Color(1.0, 0.8, 0.25)],
	"range_bonus": ["Uzak Atış", "+%d%%/m", Color(0.35, 0.9, 0.75)],
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
const CARD_W := 192.0  # px
const MODEL_H := 110.0  # px, a gear card's turning model
const MAX_SIZE := Vector2(1200, 700)  # px; small windows keep a margin round it
const SIDE_W := 240.0  # px, the gold and the vault: equal so the tabs sit in the middle
const DEAGLE_ICON := Vector2(104, 52)  # px, the wishlist line's gold Deagle
const BUY := Color(0.24, 0.86, 0.38)  # what the money reaches
const MAXED := Color(1.0, 0.78, 0.3)
const PANEL := Color(0.07, 0.08, 0.1, 0.94)
const CARD := Color(0.12, 0.135, 0.16)
const CARD_EDGE := Color(1, 1, 1, 0.08)
const WAITING := 0.6  # a card the money does not reach yet

var _tab := 0
var _frame: VBoxContainer
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _subtitle: Label
var _money: Label
var _vault: Label
var _gold_shown := 0.0  # what the gold figure reads while it counts to the real one
var _models_built := false
var _cards := {}  # id -> {card, style, need, button, ready, and level/value/next/track or stock/model}


## Pips, one per level: bought ones filled in the upgrade's colour, the next one an outline that
## beats when the money reaches it, the rest faint. `flash` (1 just after a buy) swells the newest.
class Track extends Control:
	var levels := 1
	var level := 0
	var color := Color.WHITE
	var armed := false  # the money reaches the next pip
	var flash := 0.0:
		set(v):
			flash = v
			queue_redraw()

	func _init(n: int, c: Color) -> void:
		levels = n
		color = c
		custom_minimum_size = Vector2(0, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if armed and is_visible_in_tree():
			queue_redraw()  # the next pip beats

	func _draw() -> void:
		var gap := 3.0
		var w := (size.x - gap * (levels - 1)) / levels
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		for i in levels:
			var r := Rect2(i * (w + gap), 0, w, size.y)
			if i < level:
				var grow := 3.0 * flash if i == level - 1 else 0.0
				draw_rect(r.grow(grow), color.lerp(Color.WHITE, flash if i == level - 1 else 0.0))
			elif i == level:
				draw_rect(r, Color(1, 1, 1, 0.1))
				draw_rect(r, Color(BUY, 0.5 + 0.5 * beat) if armed else Color(1, 1, 1, 0.3), false, 1.5)
			else:
				draw_rect(r, Color(1, 1, 1, 0.08))


## The upgrade's emblem, drawn: a disc in its colour with a white symbol.
class Icon extends Control:
	var id := ""
	var color := Color.WHITE

	func _init(which: String, c: Color) -> void:
		id = which
		color = c
		custom_minimum_size = Vector2(52, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 26.0, Color(color, 0.18))
		draw_arc(c, 25.0, 0.0, TAU, 48, Color(color, 0.9), 2.0, true)
		var w := Color(1, 1, 1, 0.95)
		match id:
			"carry":  # three rounds standing side by side
				for k in 3:
					var x := c.x - 11.0 + 11.0 * k
					draw_rect(Rect2(x - 3.5, c.y - 4.0, 7.0, 15.0), Color(0.95, 0.75, 0.35))
					draw_colored_polygon(PackedVector2Array([Vector2(x - 3.5, c.y - 4.0), Vector2(x + 3.5, c.y - 4.0), Vector2(x, c.y - 13.0)]), Color(0.8, 0.5, 0.3))
			"magazine":  # a magazine with rounds peeking out the top
				draw_rect(Rect2(c.x - 8.0, c.y - 8.0, 16.0, 22.0), w)
				draw_rect(Rect2(c.x - 5.0, c.y - 14.0, 10.0, 6.0), Color(0.95, 0.75, 0.35))
				for k in 3:
					draw_rect(Rect2(c.x - 5.0, c.y - 3.0 + 5.0 * k, 10.0, 1.5), Color(color, 0.9))
			"combo_cap":  # an x and a rising streak
				draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), w, 4.0, true)
				draw_line(c + Vector2(9, -9), c + Vector2(-9, 9), w, 4.0, true)
				draw_line(c + Vector2(6, -14), c + Vector2(14, -14), Color(color, 1.0), 3.0)
				draw_line(c + Vector2(14, -14), c + Vector2(14, -6), Color(color, 1.0), 3.0)
			"gold_bonus":  # a coin
				draw_circle(c, 13.0, Color(1.0, 0.8, 0.25))
				draw_arc(c, 10.0, 0.0, TAU, 32, Color(0.75, 0.5, 0.1), 2.0, true)
				draw_string(UiStyle.face(UiStyle.BOLD), c + Vector2(-5, 6), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.35, 0.05))
			"range_bonus":  # a target
				for k in 3:
					draw_arc(c, 14.0 - 5.0 * k, 0.0, TAU, 32, w if k % 2 == 0 else Color(color, 1.0), 2.5, true)
				draw_circle(c, 2.5, w)


func _ready() -> void:
	layer = 5
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL, Color(1, 1, 1, 0.1), 16, 28))
	center.add_child(panel)
	_frame = VBoxContainer.new()
	_frame.add_theme_constant_override("separation", 16)
	panel.add_child(_frame)
	_frame.add_child(_header())
	_subtitle = _centred(UiStyle.label("", 14, UiStyle.REGULAR, UiStyle.DIM))
	_frame.add_child(_subtitle)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(stack)
	_pages.append(_page(GameState.UPGRADES.keys(), _upgrade_card))
	_pages.append(_page(GameState.GEAR.keys(), _gear_card))
	for p in _pages:
		stack.add_child(p)
	var foot := HBoxContainer.new()
	foot.add_child(_wishlist_row())
	var close := UiStyle.label("Q  ·  kapat", 14, UiStyle.MEDIUM, UiStyle.DIM)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(close)
	_frame.add_child(foot)
	GameState.gold_changed.connect(_refresh.unbind(1))
	GameState.upgraded.connect(_refresh.unbind(2))
	GameState.vault_changed.connect(_refresh.unbind(1))
	GameState.gear_changed.connect(_refresh.unbind(1))
	_show_tab(0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrades") or (visible and event.is_action_pressed("ui_cancel")):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey:
		get_viewport().set_input_as_handled()  # no gun swap, B, throw or the like behind the menu


## A click or wheel turn the cards let pass would reach player.gd, which takes the mouse back
## into the game: while open the workshop keeps every mouse button to itself.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	var hud := get_node_or_null("../HUD") as CanvasLayer  # the player's: its corners would show through
	if hud:
		hud.visible = not visible
	# The placement overview keeps its cursor when the workshop closes over it.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible or GameState.player().placing else Input.MOUSE_MODE_CAPTURED
	if visible:
		_gold_shown = GameState.gold
		_show_tab(_tab)


## What the money reaches breathes: its button's glow swells and fades.
func _process(_delta: float) -> void:
	if not visible:
		return
	var a := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	for c: Dictionary in _cards.values():
		if c.ready:
			(c.button.get_theme_stylebox("normal") as StyleBoxFlat).shadow_size = roundi(4 + 8 * a)


# --- layout -----------------------------------------------------------------------------------

## Gold | tabs | vault.
func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_child(_wallet("ALTININ", false))
	var tabs := HBoxContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	row.add_child(tabs)
	tabs.add_child(_tab_button(0))
	tabs.add_child(_tab_button(1))
	row.add_child(_wallet("TAKIM KASASI", true))
	return row


func _wallet(caption: String, right: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = SIDE_W
	col.add_theme_constant_override("separation", -4)
	var align := HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	var c := UiStyle.label(caption, 13, UiStyle.BOLD, UiStyle.DIM, UiStyle.CAPTION_TRACK)
	c.horizontal_alignment = align
	col.add_child(c)
	var big := UiStyle.label("", 40, UiStyle.BOLD, HUD.MONEY)
	big.horizontal_alignment = align
	col.add_child(big)
	if right:
		_vault = big
	else:
		_money = big
	return col


## A tab is a pill: filled when open. Names are set in _show_tab: the player's arrives after joining.
func _tab_button(index: int) -> Button:
	var b := _flat_button()
	b.custom_minimum_size = Vector2(150, 42)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD))
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(_show_tab.bind(index))
	_tabs.append(b)
	return b


func _show_tab(index: int) -> void:
	_tab = index
	var screen := get_viewport().get_visible_rect().size
	_frame.custom_minimum_size = Vector2(minf(MAX_SIZE.x, screen.x * 0.92) - 56, minf(MAX_SIZE.y, screen.y * 0.9) - 56)
	var titles := [GameState.display_name(), "Teçhizat"]
	for i in _tabs.size():
		var on := i == index
		var b := _tabs[i]
		b.text = titles[i]
		var fill := Color(1, 1, 1, 0.92) if on else Color(1, 1, 1, 0.06)
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, _box(fill if s != "hover" or on else Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 21, 0))
		for s in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(s, Color(0.08, 0.09, 0.1) if on else UiStyle.WHITE)
		_pages[i].visible = on
	_subtitle.text = ["Kendi altınınla  ·  yalnız senin", "Takım kasasından  ·  bütün takım kullanır  ·  B ile kur"][index]
	if index == 1 and not _models_built:  # built on first look: fifteen small worlds
		_models_built = true
		for id in GameState.GEAR:
			var model: Control = _cards[id].model
			model.add_child(_model_view(id))
			model.move_child(model.get_child(-1), 0)  # under the stock count
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
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 18)
	center.add_child(grid)
	for id in ids:
		grid.add_child(make.call(id))
	return scroll


## A card: a rounded panel holding the caller's body, then what is missing and the buy button.
## Hovered, it lifts a little.
func _card(id: String, body: Control, buy: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = CARD_W
	var style := _box(CARD, CARD_EDGE, 12, 14)
	style.border_width_bottom = 2
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.resized.connect(func() -> void: card.pivot_offset = card.size / 2.0)
	card.mouse_entered.connect(func() -> void: card.create_tween().tween_property(card, "scale", Vector2.ONE * 1.03, 0.12))
	card.mouse_exited.connect(func() -> void: card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.15))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	col.add_child(body)
	var need := _centred(UiStyle.label("", 13, UiStyle.MEDIUM, UiStyle.DIM))
	col.add_child(need)
	var button := _flat_button()
	button.custom_minimum_size.y = 44
	button.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD))
	button.add_theme_font_size_override("font_size", 18)
	button.mouse_entered.connect(func() -> void: card.mouse_entered.emit())
	button.pressed.connect(func() -> void:
		if buy.call():
			_celebrate(id))
	col.add_child(button)
	_cards[id] = {"card": card, "style": style, "need": need, "button": button, "ready": false}
	return card


func _upgrade_card(id: String) -> Control:
	var color: Color = INFO[id][2]
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_child(Icon.new(id, color))
	var level := UiStyle.label("", 13, UiStyle.BOLD, color)
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(level)
	body.add_child(top)
	body.add_child(UiStyle.label(INFO[id][0], 20, UiStyle.BOLD))
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 8)
	body.add_child(values)
	var value := UiStyle.label("", 32, UiStyle.BOLD)
	values.add_child(value)
	var next := UiStyle.label("", 20, UiStyle.BOLD, BUY)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	values.add_child(next)
	var track := Track.new(GameState.UPGRADES[id].costs.size(), color)
	body.add_child(track)
	var card := _card(id, body, func() -> bool: return GameState.request_buy_upgrade(id))
	_cards[id].merge({"level": level, "value": value, "next": next, "track": track})
	return card


func _gear_card(id: String) -> Control:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var stage := PanelContainer.new()  # its turning model comes in on the first look (_show_tab)
	stage.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 8, 0))
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var model := Control.new()
	model.custom_minimum_size = Vector2(0, MODEL_H)
	model.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(model)
	body.add_child(stage)
	var stock := UiStyle.label("", 12, UiStyle.BOLD)  # in the stage's top right corner
	stock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stock.position += Vector2(-8, 6)
	model.add_child(stock)
	body.add_child(UiStyle.label(GameState.GEAR[id].name, 18, UiStyle.BOLD))
	var diff := _pips(5)
	for i in GEAR_INFO[id][1]:
		(diff.get_child(i) as ColorRect).color = Color(1.0, 0.45, 0.3)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UiStyle.label("Zorluk", 12, UiStyle.MEDIUM, UiStyle.DIM))
	diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(diff)
	body.add_child(top)
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 8)
	body.add_child(values)
	var value := UiStyle.label("$%d" % GEAR_INFO[id][0], 28, UiStyle.BOLD, HUD.MONEY)
	values.add_child(value)
	var per := UiStyle.label("isabet başı", 13, UiStyle.MEDIUM, UiStyle.DIM)
	per.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	values.add_child(per)
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
	var turn := Node3D.new()
	var cam := Camera3D.new()
	var holder := _little_world(turn, cam)
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
	var reach := maxf(box.size.y, Vector2(box.size.x, box.size.z).length() * 0.8)
	var far := reach * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 1.25
	var eye := Vector3(0, box.get_center().y + far * 0.25, far)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, box.get_center().y, 0) - eye), eye)
	turn.create_tween().set_loops().tween_property(turn, "rotation:y", TAU, 9.0).from(0.0)
	return holder


## A transparent little world with its own key and rim light, `turn` in its middle seen by `cam`.
func _little_world(turn: Node3D, cam: Camera3D) -> SubViewportContainer:
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
	vp.add_child(turn)
	cam.fov = 30.0
	cam.environment = env
	vp.add_child(cam)
	return holder


## Bottom left: a small gold Deagle and the line that gets it (scripts/wishlist.gd). Claimed, the
## line thanks instead and no longer clicks.
func _wishlist_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := Control.new()
	icon.custom_minimum_size = DEAGLE_ICON
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	icon.add_child(_deagle_view())
	var b := _flat_button()
	b.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD))
	b.add_theme_font_size_override("font_size", 17)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(s, Wishlist.GOLD)
	var claimed := func() -> void:
		b.text = "Altın Deagle senin  ·  teşekkürler"
		b.disabled = true
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW
	b.text = "İstek listesine ekle  ·  Altın Deagle'ı kap"
	b.pressed.connect(func() -> void:
		Wishlist.claim(get_tree())
		claimed.call())
	if Wishlist.golden():
		claimed.call()
	row.add_child(b)
	return row


## The gold Deagle rocking gently, side on. Its parts lie apart in the rest pose, so it is the
## whole arms rig standing in its Idle pose with only the gun shown, framed on the gun bone. Mirror
## gold needs something to mirror: the first-person guns' hall sky (scripts/player.gd).
func _deagle_view() -> SubViewportContainer:
	var turn := Node3D.new()
	var cam := Camera3D.new()
	var holder := _little_world(turn, cam)
	var sky := ShaderMaterial.new()
	sky.shader = preload("res://materials/viewmodel_sky.gdshader")
	cam.environment.sky = Sky.new()
	cam.environment.sky.sky_material = sky
	cam.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var arms: Node3D = preload("res://assets/weapons/arms/arms.gltf").instantiate()
	arms.visible = false  # until posed and framed, once in the tree
	turn.add_child(arms)
	var kit: Dictionary = preload("res://scripts/viewmodel.gd").SETS.deagle
	var pose := func() -> void:
		var anim: AnimationPlayer = arms.find_child("AnimationPlayer", true, false)
		anim.play(kit.clips + "Idle")
		anim.seek(0.0, true)
		anim.advance(0.0)
		anim.pause()
		for m: MeshInstance3D in arms.find_children("*", "MeshInstance3D", true, false):
			m.visible = m.name == kit.mesh
			if m.visible:
				Wishlist.gild(m)
		var skel: Skeleton3D = arms.find_child("Skeleton3D", true, false)
		var gun := arms.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(skel.find_bone(kit.bone))
		gun.basis = gun.basis.orthonormalized()
		# Gun bone space: y up, the barrel along +z; the gun's middle a little under and ahead of it.
		arms.transform = Transform3D(Basis(), -Vector3(0.0, -0.03, 0.01)) * gun.affine_inverse()
		arms.visible = true
		var high := 0.19  # m of view, the gun ~0.28 m long across a 2:1 frame
		cam.transform = Transform3D(Basis.looking_at(Vector3.LEFT), Vector3(high * 0.5 / tan(deg_to_rad(cam.fov * 0.5)), 0, 0))
		var rock := turn.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		rock.tween_property(turn, "rotation:y", 0.35, 2.5).from(-0.35)
		rock.tween_property(turn, "rotation:y", -0.35, 2.5)
	pose.call_deferred()
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
	if not visible:
		return  # opening refreshes (_show_tab); money changes many times a second while shooting
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
		(c.level as Label).text = "MAKS" if maxed else "SV %d / %d" % [level, costs.size()]
		(c.value as Label).text = INFO[id][1] % values[level]
		(c.next as Label).text = "" if maxed else "→ " + INFO[id][1] % values[level + 1]
		_price(c, 0 if maxed else costs[level], GameState.gold, maxed)
		var track: Track = c.track
		track.level = level
		track.armed = c.ready
		track.queue_redraw()
	for id in GameState.GEAR:
		var c: Dictionary = _cards[id]
		var n: int = GameState.gear_stock.get(id, 0)
		(c.stock as Label).text = "depoda %d" % n
		(c.stock as Label).add_theme_color_override("font_color", UiStyle.WHITE if n > 0 else UiStyle.DIM)
		_price(c, GameState.GEAR[id].cost, floori(GameState.vault), false)


## The buy button and the line over it. Money enough: the card's edge and the button go green and
## the button glows (_process); short: a dark button with the price, "$N eksik" over it, the card
## dimmed. Maxed: a gold "MAKS" that no longer clicks.
func _price(c: Dictionary, cost: int, have: int, maxed: bool) -> void:
	var need: Label = c.need
	var b: Button = c.button
	var style: StyleBoxFlat = c.style
	c.ready = false
	if maxed:
		b.text = "MAKS"
		b.disabled = true
		_button_fill(b, Color(MAXED, 0.18), MAXED)
		need.text = "en üst seviye"
		need.add_theme_color_override("font_color", MAXED)
		style.border_color = Color(MAXED, 0.5)
		(c.card as Control).modulate.a = 1.0
		return
	var ok := have >= cost
	c.ready = ok
	b.text = "AL  $%d" % cost
	b.disabled = not ok
	need.text = "hazır" if ok else "$%d eksik" % (cost - have)
	need.add_theme_color_override("font_color", BUY if ok else UiStyle.DIM)
	if ok:
		_button_fill(b, BUY, Color(0.04, 0.12, 0.06))
	else:
		_button_fill(b, Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.55))
	style.border_color = Color(BUY, 0.7) if ok else CARD_EDGE
	(c.card as Control).modulate.a = 1.0 if ok else WAITING


func _button_fill(b: Button, fill: Color, text: Color) -> void:
	var box := _box(fill, Color(0, 0, 0, 0), 10, 0)
	box.shadow_color = Color(fill, 0.45)
	box.shadow_size = 0
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.15)
	var pressed := box.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.15)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", box)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(s, text)


## A purchase: the card pops and flashes white, coins burst off the button, the newest pip swells,
## the value swells green and settles, and "+1" floats up.
func _celebrate(id: String) -> void:
	var c: Dictionary = _cards[id]
	var card: Control = c.card
	card.scale = Vector2.ONE * 1.1
	card.create_tween().tween_property(card, "scale", Vector2.ONE * 1.03, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var style: StyleBoxFlat = c.style  # the card itself flashes white and fades back
	card.create_tween().tween_property(style, "bg_color", CARD, 0.35).from(CARD.lerp(Color.WHITE, 0.35))
	var b: Button = c.button
	var coins := CPUParticles2D.new()
	coins.top_level = true
	coins.position = b.global_position + b.size / 2.0
	coins.one_shot = true
	coins.explosiveness = 1.0
	coins.amount = 24
	coins.lifetime = 0.7
	coins.direction = Vector2.UP
	coins.spread = 70.0
	coins.initial_velocity_min = 180.0
	coins.initial_velocity_max = 360.0
	coins.gravity = Vector2(0, 700)
	coins.scale_amount_min = 3.0
	coins.scale_amount_max = 6.0
	coins.color = MAXED
	card.add_child(coins)
	coins.emitting = true
	coins.finished.connect(coins.queue_free)
	if c.has("track"):
		var track: Track = c.track
		track.create_tween().tween_property(track, "flash", 0.0, 0.6).from(1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var value: Label = c.value
	value.pivot_offset = Vector2(0, value.size.y * 0.7)
	value.scale = Vector2.ONE * 1.4
	value.modulate = BUY
	var v := value.create_tween().set_parallel()
	v.tween_property(value, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	v.tween_property(value, "modulate", Color.WHITE, 0.6)
	var up := UiStyle.label("+1 SEVİYE" if _tab == 0 else "+1 DEPOYA", 20, UiStyle.BOLD, BUY)
	up.top_level = true  # floats free of the card's container layout
	card.add_child(up)
	up.global_position = card.global_position + Vector2(card.size.x / 2.0 - 50, -10)
	var f := up.create_tween().set_parallel()
	f.tween_property(up, "global_position:y", up.global_position.y - 40, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	f.tween_property(up, "modulate:a", 0.0, 0.5).set_delay(0.35)
	f.chain().tween_callback(up.queue_free)


# --- helpers ----------------------------------------------------------------------------------

## A rounded box in `fill` with a 1 px `edge`, `pad` px inside.
static func _box(fill: Color, edge: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1 if edge.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


## A row of short 4 px bars, unlit (difficulty).
func _pips(count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in count:
		var p := UiStyle.line(0, Color(1, 1, 1, 0.12))
		p.custom_minimum_size.y = 4
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
	return row


## A button with no frame of its own, mouse only (Space must keep jumping).
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
