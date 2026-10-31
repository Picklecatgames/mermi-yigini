extends CanvasLayer
## The workshop, opened over the bench (bench_menu.gd; Esc or E back to it), in UiStyle: a dark steel panel under a brass
## edge, names and numbers in Oswald. Top: the player's gold and what it earns a
## second on the left, the team vault on the right (co-op only), the player's name between them
## over their own upgrades, GameState.UPGRADES, paid from their gold, in long rows.
## Every price is a gauge that fills with brass as the money comes in; full, it turns green, breathes
## and buys. Buying pops the card, throws coins off the gauge, floats "+1" up and the gauge drains
## to what is left. The game keeps running, so the gauges keep filling while the menu is open.

const INFO := {  # name, value format, icon colour, what it does
	"carry": ["El Kapasitesi", "%d", Color(0.36, 0.72, 1.0), "Yığından bir avuçta aldığın mermi"],
	"magazine": ["Şarjör", "%d", Color(1.0, 0.55, 0.25), "Şarjöre giren mermi"],
	"combo_cap": ["Kombo Tavanı", "x%d", Color(0.85, 0.4, 1.0), "Seri isabetle büyüyen çarpanın üst sınırı"],
	"gold_bonus": ["Para Bonusu", "+%d%%", Color(1.0, 0.8, 0.25), "Her isabetten kazandığın paraya eklenen pay"],
	"range_bonus": ["Uzak Atış", "+%d%%/m", Color(0.35, 0.9, 0.75), "Korkuluktan uzaklaştıkça metre başı ek para"],
}
const ICONS := {"carry": "bullets", "magazine": "magazine", "combo_cap": "combo",
	"gold_bonus": "banknote", "range_bonus": "sniper_eye"}  # UiStyle.icon
const GAUGE_W := 210.0  # px, an upgrade row's price gauge
const MAX_SIZE := Vector2(1200, 720)  # px; small windows keep a margin round it
const PAD := 22  # px inside the panel
const HOVER_ROOM := Vector2(PAD, 10)  # px the pages' clip reaches past them, for a hovered card
const SIDE_W := 250.0  # px, the gold and the vault: equal so the tabs sit in the middle
const DEAGLE_ICON := Vector2(96, 48)  # px, the wishlist line's gold Deagle
const RATE_WINDOW := 10.0  # s of income the "+$N / sn" figure averages
const BUY := UiStyle.MONEY  # what the money reaches
const BRASS := UiStyle.ACCENT  # a gauge filling
const MAXED := Color(1.0, 0.78, 0.3)
const SIGNAL := UiStyle.ACCENT  # the open tab
const FX_GLOW := preload("res://assets/ui/fx/circle_05.png")  # a purchase's flash (_burst)
const FX_RING := preload("res://assets/ui/fx/circle_02.png")
const FX_SPARK := preload("res://assets/ui/fx/trace_06.png")
const FX_GLINT := preload("res://assets/ui/fx/star_06.png")
# A card's plate (UiStyle.plate) as things stand: waiting, money enough (a hint of green), maxed (warm).
const CARD := UiStyle.PLATE_GREY
const CARD_READY := Color(0.41, 0.45, 0.39)
const CARD_MAXED := Color(0.52, 0.45, 0.32)
const WAITING := 0.82  # a card the money does not reach yet
const BUY_DB := -12.0  # the till, under the gunfire
const BUY_PITCH := Vector2(0.9, 1.12)  # every purchase rings a little differently

var _tab := 0
var _frame: VBoxContainer
var _center: CenterContainer  # the whole menu, shrunk on screens it would not fit
var _tabs: Array[Button] = []
var _marks: Array[ColorRect] = []  # the open tab's underline
var _pages: Array[Control] = []
var _subtitle: Label
var _money: Label
var _rate: Label
var _vault: Label
var _gold_shown := 0.0  # what the gold figure reads while it counts to the real one
var _last_gold := 0
var _earned: Array = []  # [msec, gold] of every gain in the last RATE_WINDOW
var _shown_at := 0  # msec: cards that come in reach right after opening do not pop
var _till := AudioStreamPlayer.new()
var _cards := {}  # id -> {card, style, need, button, gauge, ready, level, value, next, track}


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
		custom_minimum_size = Vector2(0, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if armed and is_visible_in_tree():
			queue_redraw()  # the next pip beats

	var _pips: Array[StyleBoxTexture] = []  # one plate per pip, made once: the beat redraws every frame

	func _draw() -> void:  # steel studs (plate "pip"), painted the upgrade's colour once bought
		var gap := 4.0
		var w := (size.x - gap * (levels - 1)) / levels
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		for i in levels:
			var r := Rect2(i * (w + gap), 0, w, size.y)
			if i < level:
				var grow := 3.0 * flash if i == level - 1 else 0.0
				draw_style_box(_pip(i, color.lerp(Color.WHITE, flash if i == level - 1 else 0.0)), r.grow(grow))
			elif i == level:
				draw_style_box(_pip(i, Color(0.46, 0.47, 0.46)), r)
				if armed:
					draw_rect(r.grow(1.0), Color(BUY, 0.5 + 0.5 * beat), false, 1.5)
			else:
				draw_style_box(_pip(i, Color(0.26, 0.27, 0.26)), r)

	func _pip(i: int, tint: Color) -> StyleBoxTexture:
		if _pips.size() != levels or not is_equal_approx(_pips[0].get_meta(&"h"), size.y):
			_pips.clear()
			for k in levels:
				_pips.append(UiStyle.small_plate("pip", k, Color.WHITE, size.y))
				_pips[k].set_meta(&"h", size.y)
		_pips[i].modulate_color = tint
		return _pips[i]


## The price: a slot sunk in the steel (plate "slot") that fills with a brass bar (plate "fill") as
## the money nears the cost (it slides there, so a buy drains it); once full, steel painted army
## green, breathing. Its button lies over it and carries the text.
class Gauge extends Control:
	var goal := 0.0  # share of the cost in hand
	var fill := 0.0  # what is drawn, sliding to `goal`
	var full := false
	var maxed := false
	var flash := 0.0:
		set(v):
			flash = v
			queue_redraw()
	var _olive := UiStyle.plate("button", randi(), UiStyle.PLATE_OLIVE, 0)
	var _slot := UiStyle.plate("slot", randi(), UiStyle.SLOT_TINT, 0)
	var _brass := UiStyle.plate("fill", randi(), Color(UiStyle.BRASS, 0.8), 0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		# Drawn again only while it moves: twenty of them redrawn every frame cost ~10 ms.
		if full or fill != goal:
			fill = move_toward(fill, goal, delta * 2.5)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if full:  # breathes a little brighter and back
			var a := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0)
			_olive.modulate_color = UiStyle.PLATE_OLIVE.lerp(Color.WHITE, flash * 0.5 + 0.08 * a)
			draw_style_box(_olive, r)
			return
		_slot.modulate_color = UiStyle.SLOT_TINT.lerp(MAXED, 0.35) if maxed else UiStyle.SLOT_TINT
		draw_style_box(_slot, r)
		if maxed or fill < 0.005:
			return
		_brass.modulate_color = Color(UiStyle.BRASS, 0.8).lerp(Color.WHITE, flash * 0.6)
		UiStyle.draw_fill(self, _brass, r, fill)  # inside the slot's rim, as long as the money is


func _ready() -> void:
	layer = 6  # over the bench it is opened from
	_till.stream = preload("res://assets/sounds/ui/purchase.ogg")
	_till.volume_db = BUY_DB
	add_child(_till)
	visible = false
	add_child(UiStyle.backdrop())  # the menu has no frame: it stands over the blurred range
	_center = CenterContainer.new()
	add_child(_center)
	get_viewport().size_changed.connect(_fit)
	var panel := PanelContainer.new()
	var room := StyleBoxEmpty.new()
	room.set_content_margin_all(PAD)
	panel.add_theme_stylebox_override("panel", room)
	_center.add_child(panel)
	_frame = VBoxContainer.new()
	_frame.add_theme_constant_override("separation", 14)
	panel.add_child(_frame)
	_frame.add_child(_header())
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(stack)
	# The magazine and the gun's parts are bought at the bench (scripts/bench_menu.gd).
	_pages.append(_page(GameState.UPGRADES.keys().filter(func(id: String) -> bool:
		return not GameState.UPGRADES[id].get("bench", false)), _upgrade_card, 1))
	for p in _pages:
		stack.add_child(p)
	var foot := HBoxContainer.new()  # the gold Deagle's line, in the middle under the cards
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_child(_wishlist_row())
	_frame.add_child(foot)
	var close := UiStyle.hint("ESC", "")  # back to the bench it was opened from
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	close.offset_right = -36
	close.offset_top = 28
	add_child(close)
	_last_gold = GameState.gold
	GameState.gold_changed.connect(_count_income)
	GameState.gold_changed.connect(_refresh.unbind(1))
	GameState.upgraded.connect(_refresh.unbind(2))
	GameState.vault_changed.connect(_refresh.unbind(1))
	_show_tab(0)


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pick_up")):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey:
		get_viewport().set_input_as_handled()  # no gun swap, throw or the like behind the menu


## A click or wheel turn the cards let pass would reach player.gd, which takes the mouse back
## into the game: while open the workshop keeps every mouse button to itself.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


## Opened over the bench (bench_menu.gd) on tab `index`: 0 the player's upgrades, the only one.
func open_tab(index: int) -> void:
	_tab = index
	if not visible:
		toggle()
	else:
		_show_tab(index)


func toggle() -> void:
	visible = not visible
	var bench := get_node_or_null("../BenchMenu") as CanvasLayer  # opened from it: back to it on closing
	var at_bench := bench != null and bench.visible
	var hud := get_node_or_null("../HUD") as CanvasLayer  # the player's: its corners would show through
	if hud and not at_bench:
		hud.visible = not visible
	# The bench keeps its cursor when the workshop closes over it.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible or at_bench else Input.MOUSE_MODE_CAPTURED
	if visible:
		_gold_shown = GameState.gold
		_show_tab(_tab)


## Every gain counts towards the "+$N / sn" figure; spending does not.
func _count_income(gold: int) -> void:
	if gold > _last_gold:
		_earned.append([Time.get_ticks_msec(), gold - _last_gold])
	_last_gold = gold


func _process(_delta: float) -> void:
	if not visible:
		return
	var now := Time.get_ticks_msec()
	while not _earned.is_empty() and now - _earned[0][0] > RATE_WINDOW * 1000.0:
		_earned.pop_front()
	var sum := 0
	for e: Array in _earned:
		sum += e[1]
	var rate := sum / RATE_WINDOW
	_rate.text = ("+$%.1f / sn" % rate).replace(".", ",") if rate < 10.0 else "+$%d / sn" % roundi(rate)
	_rate.add_theme_color_override("font_color", BUY if sum > 0 else UiStyle.DIM)


# --- layout -----------------------------------------------------------------------------------

## Gold | tabs over a line on what the tab is | vault.
func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_child(_wallet(false))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 6)
	row.add_child(mid)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 32)
	mid.add_child(tabs)
	tabs.add_child(_tab_button(0))
	_subtitle = _centred(UiStyle.label("", 14, UiStyle.REGULAR, UiStyle.DIM))
	_subtitle.visible = false  # the tabs say it
	mid.add_child(_subtitle)
	row.add_child(_wallet(true))
	return row


## A wallet, a big stencilled sum: left the player's dollars with what they earn a second under them,
## right the team's vault ("Takım", co-op only).
func _wallet(right: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = SIDE_W
	col.add_theme_constant_override("separation", -2)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var big := UiStyle.display("", 46, UiStyle.BOLD, BUY)
	if right:
		var team := UiStyle.display("Takım", 22, UiStyle.SEMIBOLD, UiStyle.DIM)
		team.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(team)
	top.add_child(big)
	var under := UiStyle.label("", 14, UiStyle.MEDIUM, Color(BUY, 0.7))
	under.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(under)
	if right:
		_vault = big
	else:
		_money = big
		_rate = under
	return col


## A tab is a condensed word over an underline, lit brass when open. Names are set in _show_tab:
## the player's arrives after joining.
func _tab_button(index: int) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var b := _flat_button()
	b.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD, 0, true))
	b.add_theme_font_size_override("font_size", 32)
	b.pressed.connect(_show_tab.bind(index))
	col.add_child(b)
	var mark := ColorRect.new()
	mark.custom_minimum_size.y = 3
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(mark)
	_tabs.append(b)
	_marks.append(mark)
	return col


func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	# The cards have fixed widths: a small window shrinks the whole menu rather than the panel.
	var k := minf(1.0, minf(screen.x * 0.94 / MAX_SIZE.x, screen.y * 0.94 / MAX_SIZE.y))
	_center.scale = Vector2.ONE * k
	_center.position = Vector2.ZERO
	_center.size = screen / k


func _show_tab(index: int) -> void:
	_tab = index
	_shown_at = Time.get_ticks_msec()
	_fit()
	_frame.custom_minimum_size = MAX_SIZE - Vector2.ONE * PAD * 2
	var titles := [GameState.display_name()]
	for i in _tabs.size():
		var on := i == index
		var b := _tabs[i]
		b.text = titles[i]
		for s in ["font_color", "font_pressed_color"]:
			b.add_theme_color_override(s, UiStyle.WHITE if on else Color(UiStyle.DIM, 0.6))
		b.add_theme_color_override("font_hover_color", UiStyle.WHITE)
		_marks[i].color = SIGNAL if on else Color(1, 1, 1, 0.0)
		_pages[i].visible = on
	_refresh()


func _page(ids: Array, make: Callable, columns: int) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# The scroll clips: it reaches into the panel's padding and pads the cards back in by the same,
	# so a hovered card grows into room the clip still shows.
	scroll.offset_left = -HOVER_ROOM.x
	scroll.offset_right = HOVER_ROOM.x
	scroll.offset_top = -HOVER_ROOM.y
	scroll.offset_bottom = HOVER_ROOM.y
	var room := MarginContainer.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		room.add_theme_constant_override("margin_" + side, int(HOVER_ROOM.x))
	for side in ["top", "bottom"]:
		room.add_theme_constant_override("margin_" + side, int(HOVER_ROOM.y))
	scroll.add_child(room)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL  # a short page sits in the middle
	room.add_child(center)
	var tray := PanelContainer.new()  # the cards stand in one framed steel tray
	tray.add_theme_stylebox_override("panel", UiStyle.plate("tray", 0, Color(0.26, 0.27, 0.26), 20))
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(tray)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	tray.add_child(grid)
	for id in ids:
		grid.add_child(make.call(id))
	return scroll


## A card: a panel holding the caller's `box` (a row or a column) with the price gauge and its
## button added at the end, what is missing under the gauge. Hovered, it lifts a little.
func _card(id: String, box: BoxContainer, buy: Callable, gauge_w: float, kind: String) -> PanelContainer:
	var card := PanelContainer.new()
	var style := UiStyle.plate(kind, id, CARD, 16)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.resized.connect(func() -> void: card.pivot_offset = card.size / 2.0)
	card.mouse_entered.connect(func() -> void: card.create_tween().tween_property(card, "scale", Vector2.ONE * 1.02, 0.12))
	card.mouse_exited.connect(func() -> void: card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.15))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.custom_minimum_size.x = gauge_w
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(col)
	var gauge := Gauge.new()
	gauge.custom_minimum_size.y = 42
	col.add_child(gauge)
	var button := _flat_button()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD, 0, true))
	button.add_theme_font_size_override("font_size", 24)
	button.mouse_entered.connect(func() -> void: card.mouse_entered.emit())
	button.pressed.connect(func() -> void:
		if buy.call():
			_celebrate(id))
	gauge.add_child(button)
	var need := _centred(UiStyle.label("", 13, UiStyle.MEDIUM, UiStyle.DIM))
	need.custom_minimum_size.y = 16  # keeps the rows level when it is empty
	col.add_child(need)
	_cards[id] = {"card": card, "style": style, "need": need, "button": button, "gauge": gauge, "ready": false}
	return card


## A long row, Cookie Clicker's way: emblem, name and what it does, the level pips, the value now
## and after the next level, the price.
func _upgrade_card(id: String) -> Control:
	var color: Color = INFO[id][2]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.add_child(UiStyle.icon(ICONS.get(id, "bullets"), 44, color))
	var about := VBoxContainer.new()
	about.add_theme_constant_override("separation", -2)
	about.custom_minimum_size.x = 300
	about.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	about.add_child(_stencil(INFO[id][0], 28))
	row.add_child(about)
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var level := UiStyle.label("", 13, UiStyle.MEDIUM, UiStyle.DIM)
	level.visible = false  # the pips count it
	var track := Track.new(GameState.UPGRADES[id].costs.size(), color)
	steps.add_child(track)
	row.add_child(steps)
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 8)
	values.custom_minimum_size.x = 170
	values.alignment = BoxContainer.ALIGNMENT_END
	values.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := UiStyle.display("", 38, UiStyle.SEMIBOLD)
	values.add_child(value)
	var next := UiStyle.display("", 22, UiStyle.SEMIBOLD, BUY)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	values.add_child(next)
	row.add_child(values)
	var card := _card(id, row, func() -> bool: return GameState.request_buy_upgrade(id), GAUGE_W, "row")
	card.custom_minimum_size.x = 1080
	_cards[id].merge({"level": level, "value": value, "next": next, "track": track, "color": color})
	return card


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
	b.add_theme_font_override("font", UiStyle.face(UiStyle.SEMIBOLD))
	b.add_theme_font_size_override("font_size", 16)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(s, Wishlist.GOLD)
	var claimed := func() -> void:
		b.text = "Altın Deagle senin. Teşekkürler!"
		b.disabled = true
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW
	b.text = "İstek listesine ekle, Altın Deagle'ı al"
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


# --- state ------------------------------------------------------------------------------------

func _refresh() -> void:
	if not visible:
		return  # opening refreshes (_show_tab); money changes many times a second while shooting
	if visible and roundi(_gold_shown) != GameState.gold:  # the figure counts to it
		create_tween().tween_method(func(v: float) -> void:
			_gold_shown = v
			_money.text = "$" + UiStyle.dotted(roundi(v)), _gold_shown, float(GameState.gold), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		_gold_shown = GameState.gold
		_money.text = "$" + UiStyle.dotted(GameState.gold)
	_vault.text = "$" + UiStyle.dotted(floori(GameState.vault))
	# Alone, all the money is the player's: the vault is hidden but keeps its room, the tabs centred.
	_vault.get_parent().get_parent().modulate.a = 1.0 if GameState.team_vault() else 0.0
	for id in GameState.UPGRADES:
		if not _cards.has(id):
			continue  # a bench one (scripts/bench_menu.gd)
		var c: Dictionary = _cards[id]
		var level: int = GameState.player().levels[id]
		var values: Array = GameState.UPGRADES[id].values
		var costs: Array = GameState.UPGRADES[id].costs
		var maxed := level >= costs.size()
		(c.level as Label).text = "En üst seviye" if maxed else "Seviye %d / %d" % [level, costs.size()]
		(c.value as Label).text = INFO[id][1] % values[level]
		(c.next as Label).text = "" if maxed else "→ " + INFO[id][1] % values[level + 1]
		_price(c, 0 if maxed else costs[level], GameState.gold, maxed)
		var track: Track = c.track
		track.level = level
		track.armed = c.ready
		track.queue_redraw()


## The gauge, its button and the line under it. Money enough: the gauge is full and green, the
## card's stripe goes green, "$N"; short: the brass shows how far along the money is, the price
## alone, the card a little dimmed. Maxed: a gold "Son" that no
## longer clicks. A card that comes in reach while the menu is open hops.
func _price(c: Dictionary, cost: int, have: int, maxed: bool) -> void:
	var need: Label = c.need
	var b: Button = c.button
	var gauge: Gauge = c.gauge
	var style: StyleBoxTexture = c.style
	var card: Control = c.card
	var was: bool = c.ready
	c.ready = false
	gauge.maxed = maxed
	gauge.full = false
	gauge.queue_redraw()
	if maxed:
		b.text = "Son"
		b.disabled = true
		_text_color(b, MAXED)
		need.text = ""
		need.add_theme_color_override("font_color", MAXED)
		style.modulate_color = CARD_MAXED
		card.modulate.a = 1.0
		return
	var ok := have >= cost
	c.ready = ok
	gauge.full = ok
	gauge.goal = clampf(float(have) / cost, 0.0, 1.0) if cost > 0 else 1.0
	b.text = "$%d" % cost
	b.disabled = not ok
	_text_color(b, UiStyle.WHITE)
	need.text = ""  # the brass in the gauge shows how far
	need.add_theme_color_override("font_color", BUY if ok else UiStyle.DIM)
	style.modulate_color = CARD_READY if ok else CARD
	card.modulate.a = 1.0 if ok else WAITING
	if ok and not was and Time.get_ticks_msec() - _shown_at > 300:
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).from(Vector2.ONE * 1.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		gauge.create_tween().tween_property(gauge, "flash", 0.0, 0.4).from(1.0)


func _text_color(b: Button, color: Color) -> void:
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(s, color)


## A purchase: the card pops and flashes, coins burst off the gauge, which drains to what is left,
## the newest pip swells, the value swells green and settles, and "+1" floats up.
func _celebrate(id: String) -> void:
	_till.pitch_scale = randf_range(BUY_PITCH.x, BUY_PITCH.y)
	_till.play()
	var c: Dictionary = _cards[id]
	var card: Control = c.card
	card.scale = Vector2.ONE * 1.08
	card.create_tween().tween_property(card, "scale", Vector2.ONE * 1.02, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var style: StyleBoxTexture = c.style  # the plate itself flashes and fades back
	card.create_tween().tween_property(style, "modulate_color", style.modulate_color, 0.4).from(style.modulate_color.lerp(Color.WHITE, 0.45))
	var gauge: Gauge = c.gauge
	gauge.fill = 1.0  # and slides down to what is left
	gauge.create_tween().tween_property(gauge, "flash", 0.0, 0.5).from(1.0)
	_burst(card, gauge.global_position + gauge.size / 2.0)
	if c.has("track"):
		var track: Track = c.track
		track.create_tween().tween_property(track, "flash", 0.0, 0.6).from(1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var value: Label = c.value
	value.pivot_offset = Vector2(value.size.x, value.size.y * 0.7) if _tab == 0 else Vector2(0, value.size.y * 0.7)
	value.scale = Vector2.ONE * 1.4
	value.modulate = BUY
	var v := value.create_tween().set_parallel()
	v.tween_property(value, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	v.tween_property(value, "modulate", Color.WHITE, 0.6)
	var up := _stencil("+1", 26, BUY)
	up.top_level = true  # floats free of the card's container layout
	card.add_child(up)
	up.global_position = gauge.global_position + Vector2(gauge.size.x / 2.0 - 52, -30)
	var f := up.create_tween().set_parallel()
	f.tween_property(up, "global_position:y", up.global_position.y - 46, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	f.tween_property(up, "modulate:a", 0.0, 0.5).set_delay(0.4)
	f.chain().tween_callback(up.queue_free)


## The flash off a purchase, in brass, from Kenney's Particle Pack (assets/ui/fx, CC0), added
## light: a soft glow and a ring going out, sparks streaking off and slowing, a few glints that
## twinkle and fade.
func _burst(on: Control, at: Vector2) -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for f: Array in [[FX_GLOW, 0.05, 0.5, 0.35], [FX_RING, 0.03, 0.42, 0.45]]:  # texture, scale from, to, s
		var s := Sprite2D.new()
		s.texture = f[0]
		s.material = add
		s.top_level = true
		s.modulate = MAXED
		on.add_child(s)
		s.global_position = at
		var t := s.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "scale", Vector2.ONE * f[2], f[3]).from(Vector2.ONE * f[1])
		t.tween_property(s, "modulate:a", 0.0, f[3]).from(0.9)
		t.chain().tween_callback(s.queue_free)
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.92, 0.7))
	fade.set_color(1, Color(MAXED, 0.0))
	var swell := Curve.new()  # a glint opens, then shrinks away
	swell.add_point(Vector2(0.0, 0.0))
	swell.add_point(Vector2(0.2, 1.0))
	swell.add_point(Vector2(1.0, 0.0))
	for p: Array in [[FX_SPARK, 22, 0.45, 260.0, 520.0, 0.07, 0.12, true, null],
			[FX_GLINT, 9, 0.75, 40.0, 150.0, 0.06, 0.12, false, swell]]:
		var e := CPUParticles2D.new()
		e.emitting = false  # it would start at the screen's corner the moment it is added
		e.local_coords = true  # born where it stands, not where its transform was a frame ago
		e.texture = p[0]
		e.material = add
		e.top_level = true
		e.one_shot = true
		e.explosiveness = 0.95
		e.amount = p[1]
		e.lifetime = p[2]
		e.spread = 180.0
		e.gravity = Vector2.ZERO
		e.initial_velocity_min = p[3]
		e.initial_velocity_max = p[4]
		e.damping_min = p[4] * 1.2  # they slow as they go
		e.damping_max = p[4] * 1.6
		e.scale_amount_min = p[5]
		e.scale_amount_max = p[6]
		e.particle_flag_align_y = p[7]  # the sparks point the way they fly
		if p[8]:
			e.scale_amount_curve = p[8]
		e.color_ramp = fade
		on.add_child(e)
		e.global_position = at
		e.emitting = true
		e.finished.connect(e.queue_free)


# --- helpers ----------------------------------------------------------------------------------

## A name or headline: Oswald, bold.
func _stencil(text: String, size: int, color := UiStyle.WHITE) -> Label:
	return UiStyle.display(text, size, UiStyle.BOLD, color)


## A rounded box in `fill` with a 1 px `edge`, `pad` px inside.
static func _box(fill: Color, edge: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1 if edge.a > 0.0 else 0)
	s.set_corner_radius_all(mini(radius, 2))  # square-cut plate
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


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
