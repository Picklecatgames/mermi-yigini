extends CanvasLayer
## The workshop, toggled with Q (Esc also closes). Two tabs on the left: the player's own upgrades
## (GameState.UPGRADES, paid from their gold) and the team's gear (GameState.GEAR, targets paid
## from the shared vault). Each card shows what the next level gives and how close the money is.
## The game keeps running behind it (co-op).

const INFO := {
	"carry": ["El Kapasitesi", "Yığından bir seferde taşıdığın mermi.", "%d"],
	"magazine": ["Şarjör", "Tek doldurmada şarjöre sığan mermi.", "%d"],
	"combo_cap": ["Kombo Tavanı", "Zincirle ulaşabileceğin en yüksek çarpan.", "x%d"],
	"gold_bonus": ["Altın", "Her isabetin verdiği altına eklenir.", "+%d%%"],
	"range_bonus": ["Uzak Atış", "Korkuluğun her metre gerisinden vuruşa ek altın.", "+%d%%/m"],
}
const GEAR_INFO := {  # name, what it is, gold per hit
	"dummy": ["Saman Kukla", "Çuval kukla. Kafası iki kat öder.", 1],
	"steel_silhouette": ["Çelik Siluet", "İnsan boyu çelik; vurdukça sallanır.", 2],
	"steel_gong": ["Çelik Gong", "Yuvarlak gong, sesi bütün atölyeye yayılır.", 2],
	"popper": ["Popper", "Vurulunca devrilir, biraz sonra kalkar.", 3],
	"steel_rack": ["Plaka Dizisi", "Yan yana küçük çelik plakalar.", 4],
	"plate_rack": ["Köstebek Rafı", "Plakalar sırayla kalkar; kaçırma.", 7],
	"texas_star": ["Texas Star", "Dönen yıldız; plaka düştükçe hızlanır.", 12],
}
const BG := Color(0.07, 0.08, 0.1, 0.97)
const SIDE := Color(0.045, 0.05, 0.065)
const CARD := Color(0.11, 0.12, 0.15)
const CARD_HOVER := Color(0.14, 0.155, 0.19)
const LINE := Color(0.2, 0.22, 0.27)
const GREEN := Color(0.33, 1.0, 0.42)
const GOLD := Color(1.0, 0.8, 0.3)
const DIM := Color(0.6, 0.63, 0.69)
const SHORT := Color(0.95, 0.45, 0.4)
const OFF := Color(0.2, 0.22, 0.26)

var _tab := 0
var _frame: PanelContainer
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _title: Label
var _subtitle: Label
var _money: Label
var _vault: Label
var _cards := {}  # id -> {card, bar, need, button, and level/value/next/pips or stock}


func _ready() -> void:
	layer = 5
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1060, 640)
	_frame = frame
	frame.add_theme_stylebox_override("panel", _box(BG, LINE, 2, 14, 0, Color(0, 0, 0, 0.5), 24))
	center.add_child(frame)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 0)
	frame.add_child(split)
	split.add_child(_sidebar())
	var content := MarginContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 26)
	split.add_child(content)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	content.add_child(col)
	_title = _label("", 30, Color.WHITE)
	col.add_child(_title)
	_subtitle = _label("", 15, DIM)
	col.add_child(_subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	col.add_child(gap)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(stack)
	_pages.append(_page(GameState.UPGRADES.keys(), _upgrade_card))
	_pages.append(_page(GameState.GEAR.keys(), _gear_card))
	for p in _pages:
		stack.add_child(p)
	GameState.gold_changed.connect(_refresh.unbind(1))
	GameState.upgraded.connect(_refresh.unbind(2))
	GameState.vault_changed.connect(_refresh.unbind(1))
	GameState.gear_changed.connect(_refresh.unbind(1))
	_show_tab(0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrades") or (visible and event.is_action_pressed("ui_cancel")):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	if visible:
		_show_tab(_tab)


# --- layout -----------------------------------------------------------------------------------

func _sidebar() -> Control:
	var side := PanelContainer.new()
	side.custom_minimum_size.x = 270
	var sb := _box(SIDE, Color.TRANSPARENT, 0, 0, 20)
	sb.corner_radius_top_left = 14
	sb.corner_radius_bottom_left = 14
	side.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	side.add_child(col)
	col.add_child(_label("ATÖLYE", 14, DIM))
	col.add_child(_tab_button(0, "Kişisel geliştirmeler"))
	col.add_child(_tab_button(1, "Takımın ortak kasasından"))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	var wallet := PanelContainer.new()
	wallet.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.03), LINE, 1, 10, 14))
	col.add_child(wallet)
	var w := VBoxContainer.new()
	w.add_theme_constant_override("separation", 2)
	wallet.add_child(w)
	w.add_child(_label("PARAN", 12, DIM))
	_money = _label("", 30, GREEN)
	w.add_child(_money)
	w.add_child(_label("ORTAK KASA", 12, DIM))
	_vault = _label("", 22, GOLD)
	w.add_child(_vault)
	var hint := _label("[Q] Kapat", 13, DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	return side


## Title and accent are set in _show_tab: the player's name and colour arrive after joining.
func _tab_button(index: int, sub: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 74)
	b.focus_mode = Control.FOCUS_NONE  # mouse only: Space must keep jumping
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	b.add_child(row)
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.custom_minimum_size.x = 5
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var t := _label("", 21, Color.WHITE)
	t.name = "Title"
	text.add_child(t)
	text.add_child(_label(sub, 13, DIM))
	b.pressed.connect(_show_tab.bind(index))
	_tabs.append(b)
	return b


func _show_tab(index: int) -> void:
	_tab = index
	var screen := get_viewport().get_visible_rect().size  # small windows keep a margin round it
	_frame.custom_minimum_size = Vector2(minf(1060.0, screen.x * 0.94), minf(640.0, screen.y * 0.9))
	var titles := [GameState.display_name(), "Teçhizatlar"]
	var accents := [GameState.color_of(GameState.local_peer()), GOLD]
	for i in _tabs.size():
		var on := i == index
		var normal := _box(Color(1, 1, 1, 0.07) if on else Color.TRANSPARENT, Color.TRANSPARENT, 0, 8)
		_tabs[i].add_theme_stylebox_override("normal", normal)
		_tabs[i].add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.1) if on else Color(1, 1, 1, 0.04), Color.TRANSPARENT, 0, 8))
		_tabs[i].add_theme_stylebox_override("pressed", normal)
		(_tabs[i].find_child("Bar", true, false) as ColorRect).color = accents[i] if on else Color(accents[i], 0.15)
		var title := _tabs[i].find_child("Title", true, false) as Label
		title.text = titles[i]
		title.modulate = Color.WHITE if on else Color(1, 1, 1, 0.6)
		_pages[i].visible = on
	_title.text = [GameState.display_name(), "Takımın teçhizatı"][index]
	_subtitle.text = ["Bu geliştirmeler yalnızca senin için geçerlidir.",
		"Ortak kasadan alınır, herkes için. Alınanlar depoya gider; yerleştirme yakında."][index]
	_refresh()


func _page(ids: Array, make: Callable) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for id in ids:
		grid.add_child(make.call(id))
	return scroll


## A card's frame, its hover glow and its buy row; the caller fills in the middle.
func _card(id: String, body: Control, buy: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 168)
	card.add_theme_stylebox_override("panel", _box(CARD, LINE, 1, 10, 16))
	card.mouse_entered.connect(func() -> void: (card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = CARD_HOVER)
	card.mouse_exited.connect(func() -> void: (card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = CARD)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	col.add_child(body)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 3)
	foot.add_child(left)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _box(OFF, Color.TRANSPARENT, 0, 3))
	bar.add_theme_stylebox_override("fill", _box(GREEN, Color.TRANSPARENT, 0, 3))
	left.add_child(bar)
	var need := _label("", 13, DIM)
	left.add_child(need)
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(func() -> void:
		if buy.call():
			_celebrate(card))
	foot.add_child(button)
	_cards[id] = {"card": card, "bar": bar, "need": need, "button": button}
	return card


func _upgrade_card(id: String) -> Control:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	body.add_child(top)
	var title := _label(INFO[id][0], 22, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var level := _label("", 13, DIM)
	top.add_child(level)
	body.add_child(_label(INFO[id][1], 14, DIM))
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 10)
	body.add_child(values)
	var value := _label("", 26, Color.WHITE)
	values.add_child(value)
	var next := _label("", 26, GREEN)
	values.add_child(next)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	for i in GameState.UPGRADES[id].costs.size():  # one pip per level to buy
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(0, 7)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pips.add_child(p)
	body.add_child(pips)
	var card := _card(id, body, func() -> bool: return GameState.request_buy_upgrade(id))
	_cards[id].merge({"level": level, "value": value, "next": next, "pips": pips})
	return card


func _gear_card(id: String) -> Control:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.add_child(_label(GEAR_INFO[id][0], 22, Color.WHITE))
	body.add_child(_label(GEAR_INFO[id][1], 14, DIM))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	body.add_child(chips)
	chips.add_child(_chip("İsabet başı $%d" % GEAR_INFO[id][2], GREEN))
	var stock := _chip("", DIM)
	chips.add_child(stock)
	var card := _card(id, body, func() -> bool: return GameState.request_buy_gear(id))
	_cards[id]["stock"] = stock
	return card


# --- state ------------------------------------------------------------------------------------

func _refresh() -> void:
	_money.text = "$%d" % GameState.gold
	_vault.text = "$%d" % floori(GameState.vault)
	for id in GameState.UPGRADES:
		var c: Dictionary = _cards[id]
		var level: int = GameState.player().levels[id]
		var values: Array = GameState.UPGRADES[id].values
		var costs: Array = GameState.UPGRADES[id].costs
		var maxed := level >= costs.size()
		(c.level as Label).text = "SEVİYE %d / %d" % [level, costs.size()]
		for i in (c.pips as Control).get_child_count():
			((c.pips as Control).get_child(i) as ColorRect).color = (GOLD if maxed else GREEN) if i < level else OFF
		(c.value as Label).text = INFO[id][2] % values[level]
		(c.next as Label).text = "" if maxed else "→  " + INFO[id][2] % values[level + 1]
		_price(c, 0 if maxed else costs[level], GameState.gold, maxed, GREEN)
	for id in GameState.GEAR:
		var c: Dictionary = _cards[id]
		var n: int = GameState.gear_stock.get(id, 0)
		(c.stock as Label).text = "Depoda %d" % n
		(c.stock as Label).modulate = Color.WHITE if n > 0 else Color(1, 1, 1, 0.5)
		_price(c, GameState.GEAR[id].cost, floori(GameState.vault), false, GOLD)


## Bar toward the price, what is still missing, and the button: lit when it can be bought.
func _price(c: Dictionary, cost: int, have: int, maxed: bool, accent: Color) -> void:
	var bar: ProgressBar = c.bar
	var need: Label = c.need
	var b: Button = c.button
	(((c.card as Control).get_theme_stylebox("panel")) as StyleBoxFlat).border_color = GOLD if maxed else LINE
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if maxed:
		bar.max_value = 1
		bar.value = 1
		fill.bg_color = GOLD
		need.text = "En üst seviye"
		need.modulate = GOLD
		b.text = "MAKS"
		b.disabled = true
		_style_button(b, GOLD, false)
		return
	bar.max_value = cost
	bar.value = mini(have, cost)
	var ok := have >= cost
	fill.bg_color = accent if ok else Color(accent, 0.55)
	need.text = "Hazır!" if ok else "$%d eksik" % (cost - have)
	need.modulate = accent if ok else SHORT
	b.text = "$%d  AL" % cost
	b.disabled = not ok
	_style_button(b, accent, ok)


func _style_button(b: Button, accent: Color, lit: bool) -> void:
	var bg := accent if lit else Color(0.15, 0.16, 0.19)
	b.add_theme_stylebox_override("normal", _box(bg, Color.TRANSPARENT, 0, 8))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.15), Color.TRANSPARENT, 0, 8))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.15), Color.TRANSPARENT, 0, 8))
	b.add_theme_stylebox_override("disabled", _box(bg, Color(accent, 0.35), 1, 8))
	b.add_theme_color_override("font_color", Color(0.05, 0.06, 0.07))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.06, 0.07))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.06, 0.07))
	b.add_theme_color_override("font_disabled_color", accent if b.text == "MAKS" else DIM)


## A purchase: the card flashes and swells, and "+1" floats up off it.
func _celebrate(card: Control) -> void:
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2.ONE * 1.05
	card.modulate = Color(1.5, 1.7, 1.5)
	var t := create_tween().set_parallel()
	t.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "modulate", Color.WHITE, 0.35)
	var up := _label("+1 SEVİYE" if _tab == 0 else "+1 DEPOYA", 26, GREEN if _tab == 0 else GOLD)
	up.add_theme_constant_override("outline_size", 8)
	up.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	up.top_level = true  # floats free of the card's container layout
	card.add_child(up)
	up.global_position = card.global_position + Vector2(card.size.x * 0.5 - 60, 6)
	var f := up.create_tween().set_parallel()
	f.tween_property(up, "global_position:y", up.global_position.y - 46, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	f.tween_property(up, "modulate:a", 0.0, 0.5).set_delay(0.25)
	f.chain().tween_callback(up.queue_free)


# --- helpers ----------------------------------------------------------------------------------

func _chip(text: String, color: Color) -> Label:
	var l := _label(text, 13, color)
	var sb := _box(Color(color, 0.1), Color(color, 0.35), 1, 6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", sb)
	return l


static func _box(bg: Color, border: Color, width: int, radius: int, margin := 0, shadow := Color.TRANSPARENT, shadow_size := 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	b.shadow_color = shadow
	b.shadow_size = shadow_size
	return b


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
