extends CanvasLayer
## The pause menu (Esc), in the workshop's kit: the game blurred and dimmed behind, a rail on the
## left (MOLA stencilled over a hazard stripe, the pages, quit) and an olive panel on the right
## with the open page, its rows and, under them, what the row under the mouse does. Solo it stops
## the game; in co-op the world keeps going (the host cannot stop it for one player).
## Drawn on a 1280x720 canvas scaled to the screen, so nothing moves about on other sizes.
## Settings live in the `Settings` autoload; this is only the page that changes them.

const DESIGN := Vector2(1280, 720)
const STENCIL := UiStyle.STENCIL
const HUD := preload("res://scripts/hud.gd")  # its money green and dotted numbers
const BRASS := Color(0.85, 0.64, 0.26)
const SIGNAL := UiStyle.ACCENT
const PANEL := Color(0.105, 0.115, 0.09, 0.97)
const ROW_HOVER := Color(1, 1, 1, 0.045)
const RAIL_X := 56.0
const RAIL_W := 280.0
const PANEL_RECT := Rect2(372, 44, 860, 632)
const NAME_W := 330.0  # px, a row's name
const CONTROL_W := 400.0  # px, a row's control
const ROW_H := 46.0
const PAGES := ["DURUM", "SES", "GÖRÜNTÜ", "KONTROLLER", "OYUN"]
const SUBTITLES := [
	"Oyun nerede, tuşlar ne",
	"Seviyeler, 3B ses ve çıkış",
	"Pencere, kalite ve efektler",
	"Tuş atamaları ve fare",
	"Görüş, nişangâh ve ekran",
]
const BLUR := """
shader_type canvas_item;
uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 3.5).rgb;
	c = mix(c, vec3(0.05, 0.06, 0.04), 0.6);
	float v = smoothstep(1.05, 0.25, length(UV - vec2(0.5)) * 1.3);
	COLOR = vec4(c * mix(0.45, 1.0, v), 1.0);
}
"""

var is_open := false
var page := 0
var listening := ""  # the action waiting for its new key
var _canvas: Control  # the 1280x720 design, scaled to the screen
var _nav: Array[Button] = []
var _bars: Array[ColorRect] = []
var _pages: Array[Control] = []
var _title: Label
var _subtitle: Label
var _info: Label
var _reset: Button
var _quit: Button
var _session: Label
var _quit_armed := 0.0  # s left to click quit a second time
var _refresh: Array[Callable] = []  # every row's "show the current value"
var _status: Dictionary = {}  # DURUM tiles: name -> value label
var _keys_list: GridContainer
var _knob: ImageTexture


func _ready() -> void:
	layer = 30
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var back := ColorRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = BLUR
	back.material = m
	back.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing behind takes a click
	add_child(back)
	_canvas = Control.new()
	_canvas.size = DESIGN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_knob = _circle(18, BRASS)
	_build_rail()
	_build_panel()
	_show_page(0)
	get_viewport().size_changed.connect(_fit)
	Settings.changed.connect(func(_k: String) -> void: _refresh_rows())
	_fit()


func _fit() -> void:
	var s := get_viewport().get_visible_rect().size
	var k := minf(s.x / DESIGN.x, s.y / DESIGN.y)
	_canvas.scale = Vector2.ONE * k
	_canvas.position = ((s - DESIGN * k) / 2.0).floor()


func _process(delta: float) -> void:
	if not is_open:
		return
	if _quit_armed > 0.0:
		_quit_armed -= delta
		if _quit_armed <= 0.0:
			_quit.text = "MASAÜSTÜNE ÇIK"
	if page == 0:
		_update_status()


# --- opening -----------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if listening != "":
		_listen(event)
		return
	if event.is_action_pressed("ui_cancel"):
		if is_open:
			close()
		elif _may_open():
			open()
		else:
			return
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey:
		get_viewport().set_input_as_handled()  # no walking, guns or the workshop behind the menu


## Not over the workshop, the bench, the quest board or the placement overview: Esc is theirs then.
func _may_open() -> bool:
	var p = GameState.player()
	if p and p.placing:
		return false
	for menu: String in ["UpgradeMenu", "BenchMenu", "BoardMenu", "MelterMenu", "PressMenu", "CharacterPick"]:
		for n in get_tree().root.find_children(menu, "CanvasLayer", true, false):
			if (n as CanvasLayer).visible:
				return false
	return true


func open() -> void:
	is_open = true
	visible = true
	_quit_armed = 0.0
	_quit.text = "MASAÜSTÜNE ÇIK"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var solo := not Net.online
	get_tree().paused = solo
	Settings.set_paused_sound(solo)
	_session.text = "TEK OYUNCU  ·  OYUN DURDU" if solo else "CO-OP  ·  %d OYUNCU  ·  OYUN SÜRÜYOR" % maxi(1, GameState.slots.size())
	_refresh_rows()
	_show_page(0)


func close() -> void:
	is_open = false
	visible = false
	listening = ""
	get_tree().paused = false
	Settings.set_paused_sound(false)
	var p = GameState.player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p and p.placing else Input.MOUSE_MODE_CAPTURED


# --- the rail ----------------------------------------------------------------------------------

func _build_rail() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(RAIL_X, 44)
	col.size = Vector2(RAIL_W, 632)
	col.add_theme_constant_override("separation", 0)
	_canvas.add_child(col)
	col.add_child(UiStyle.label("MERMİ YIĞINI", 13, UiStyle.MEDIUM, UiStyle.DIM, 4))
	var title := _stencil("MOLA", 84, UiStyle.WHITE)
	title.custom_minimum_size.y = 96
	col.add_child(title)
	col.add_child(_hazard(RAIL_W, 10))
	col.add_child(_gap(28))
	var resume := _nav_button("DEVAM ET", -1)
	resume.pressed.connect(close)
	col.add_child(resume.get_parent())
	col.add_child(_gap(10))
	for i in PAGES.size():
		var b := _nav_button(PAGES[i], i)
		b.pressed.connect(_show_page.bind(i))
		col.add_child(b.get_parent())
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fill)
	_quit = _nav_button("MASAÜSTÜNE ÇIK", -1)
	_quit.add_theme_color_override("font_color", Color(UiStyle.DIM, 0.9))
	_quit.add_theme_color_override("font_hover_color", SIGNAL)
	_quit.pressed.connect(_on_quit)
	col.add_child(_quit.get_parent())
	col.add_child(_gap(14))
	col.add_child(UiStyle.line(RAIL_W))
	col.add_child(_gap(10))
	_session = UiStyle.label("", 12, UiStyle.BOLD, BRASS, 2)
	col.add_child(_session)


## A stencilled rail entry with an orange bar on its left when its page is open (index -1: none).
func _nav_button(text: String, index: int) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 26)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.color = Color(SIGNAL, 0.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var b := _flat_button(text, 26)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(RAIL_W - 16, 42)
	row.add_child(b)
	if index >= 0:
		_nav.append(b)
		_bars.append(bar)
	return b


func _on_quit() -> void:
	if _quit_armed > 0.0:
		get_tree().quit()
		return
	_quit_armed = 3.0
	_quit.text = "EMİN MİSİN? TIKLA"


# --- the panel ---------------------------------------------------------------------------------

func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	var style := _box(PANEL, Color(BRASS, 0.5), 10, 0)
	style.set_border_width_all(0)
	style.border_width_top = 3
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 22
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(panel)
	_canvas.add_child(_brackets(PANEL_RECT.grow(8)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	_title = _stencil("", 36, UiStyle.WHITE)
	head.add_child(_title)
	_subtitle = UiStyle.label("", 15, UiStyle.REGULAR, UiStyle.DIM)
	_subtitle.size_flags_vertical = Control.SIZE_SHRINK_END
	_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle.custom_minimum_size.y = 30
	head.add_child(_subtitle)
	_reset = _small_button("VARSAYILANA DÖN")
	_reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reset.pressed.connect(_reset_page)
	head.add_child(_reset)
	col.add_child(UiStyle.line())
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stack)
	for build in [_status_page, _audio_page, _video_page, _controls_page, _game_page]:
		var p: Control = build.call()
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(p)
		_pages.append(p)
	col.add_child(UiStyle.line())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	var mark := ColorRect.new()
	mark.color = BRASS
	mark.custom_minimum_size = Vector2(3, 40)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(mark)
	_info = UiStyle.label("", 14, UiStyle.REGULAR, UiStyle.DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(0, 40)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_info)


func _show_page(i: int) -> void:
	page = i
	for j in _pages.size():
		_pages[j].visible = j == i
		_nav[j].add_theme_color_override("font_color", BRASS if j == i else UiStyle.WHITE)
		_bars[j].color = Color(SIGNAL, 1.0 if j == i else 0.0)
	_title.text = PAGES[i]
	_subtitle.text = ""  # the title says it
	_reset.visible = i > 0
	_info.text = ""
	if i == 0:
		_update_status()


func _reset_page() -> void:
	var keys: Array = _pages[page].get_meta(&"keys", [])
	Settings.reset(keys, page == 3)
	_info.text = ""  # the rows moving back say it


func _refresh_rows() -> void:
	for f in _refresh:
		f.call()
	_fill_keys_list()


# --- pages -------------------------------------------------------------------------------------

## A page that scrolls: rows and group headings, `keys` the settings its reset puts back.
func _scroll_page(keys: Array) -> Array:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta(&"keys", keys)
	var bar := scroll.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", _box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 3, 0))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, _box(Color(BRASS, 0.55 if state == "grabber" else 0.9), Color(0, 0, 0, 0), 3, 0))
	bar.custom_minimum_size.x = 6
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	return [scroll, list]


func _status_page() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	for t in [["pile", "YIĞINDA KALAN"], ["done", "BİTEN"], ["gold", "PARAN"], ["vault", "TAKIM KASASI"], ["gun", "ELİNDEKİ SİLAH"], ["keys", "ANAHTARLAR"]]:
		grid.add_child(_tile(t[0], t[1]))
	col.add_child(_heading("TUŞLAR"))
	_keys_list = GridContainer.new()
	_keys_list.columns = 2
	_keys_list.add_theme_constant_override("h_separation", 40)
	_keys_list.add_theme_constant_override("v_separation", 2)
	col.add_child(_keys_list)
	_fill_keys_list()
	return col


func _tile(id: String, caption: String) -> Control:
	var tile := PanelContainer.new()
	var s := _box(Color(0.15, 0.165, 0.13), Color(1, 1, 1, 0.06), 8, 14)
	s.set_border_width_all(0)
	s.border_width_left = 3
	s.border_color = Color(BRASS, 0.7)
	tile.add_theme_stylebox_override("panel", s)
	tile.custom_minimum_size = Vector2(254, 84)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	tile.add_child(col)
	col.add_child(UiStyle.caption(caption))
	var v := UiStyle.label("", 26, UiStyle.BOLD)
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.custom_minimum_size.x = 220
	col.add_child(v)
	_status[id] = v
	return tile


func _update_status() -> void:
	var p = GameState.player()
	var pile: int = GameState.pile
	_status.pile.text = UiStyle.dotted(pile)
	_status.done.text = "%" + ("%.4f" % (100.0 * (1.0 - float(pile) / GameState.PILE_START))).replace(".", ",")
	_status.gold.text = "$" + UiStyle.dotted(p.gold if p else 0)
	_status.vault.text = "$" + UiStyle.dotted(int(GameState.vault))
	_status.gun.text = GameState.GUNS[p.gun].name if p else "—"
	_status.keys.text = "%d / 12" % (p.keys.size() if p else 0)
	_status.pile.add_theme_color_override("font_color", BRASS)
	_status.gold.add_theme_color_override("font_color", HUD.MONEY)
	_status.vault.add_theme_color_override("font_color", HUD.MONEY)


func _fill_keys_list() -> void:
	if not _keys_list:
		return
	for c in _keys_list.get_children():
		_keys_list.remove_child(c)
		c.queue_free()
	var lines: Array = []
	for a in Settings.ACTIONS:
		lines.append([a[1], Settings.bind_text(a[0])])
	lines.append(["Silah seç", "1 - 4"])
	lines.append(["Oyunu durdur", "Esc"])
	for l in lines:
		var row := HBoxContainer.new()
		row.custom_minimum_size.x = 370
		var n := UiStyle.label(l[0], 14, UiStyle.REGULAR, UiStyle.DIM)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(_keycap(l[1]))
		_keys_list.add_child(row)


func _audio_page() -> Control:
	var keys := ["master_vol", "weapon_vol", "effect_vol", "ambience_vol", "output", "rear_cue", "dynamic_range", "mono", "mute_unfocused", "pause_muffle", "device"]
	var pl := _scroll_page(keys)
	var list: VBoxContainer = pl[1]
	list.add_child(_heading("SEVİYELER"))
	list.add_child(_slider("master_vol", "Genel ses", 0, 100, 1, "%d%%", ""))
	list.add_child(_slider("weapon_vol", "Silahlar", 0, 100, 1, "%d%%", ""))
	list.add_child(_slider("effect_vol", "Efektler", 0, 100, 1, "%d%%", ""))
	list.add_child(_slider("ambience_vol", "Ambiyans", 0, 100, 1, "%d%%", ""))
	list.add_child(_heading("3B SES"))
	list.add_child(_choice("output", "Çıkış türü", ["Kulaklık", "Stereo hoparlör", "Surround 5.1 / 7.1"],
		"Surround için Windows'ta 5.1/7.1 açık olmalı."))
	list.add_child(_slider("rear_cue", "Arkadan gelen ses ipucu", 0, 100, 5, "%d%%",
		"Arkandaki ses biraz kısılır, o yöne dönünce açılır. Surround'da kapalı."))
	list.add_child(_heading("KARIŞIM"))
	list.add_child(_choice("dynamic_range", "Dinamik aralık", ["Geniş", "Orta", "Gece modu"],
		"Gece modu yüksek sesleri bastırır, kısıkları açar."))
	list.add_child(_toggle("mono", "Mono ses", ""))
	list.add_child(_toggle("pause_muffle", "Durunca sesi boğ", ""))
	list.add_child(_toggle("mute_unfocused", "Arka planda sessiz", ""))
	var devices := Array(AudioServer.get_output_device_list())
	list.add_child(_choice_values("device", "Çıkış cihazı", devices, devices.map(func(d: String) -> String: return "Sistem varsayılanı" if d == "Default" else d),
		""))
	return pl[0]


func _video_page() -> Control:
	var keys := ["preset", "window_mode", "vsync", "fps_limit", "render_scale", "upscaler", "antialias", "shadows", "ssao", "ssil", "ssr", "fog", "glow", "brightness"]
	var pl := _scroll_page(keys)
	var list: VBoxContainer = pl[1]
	list.add_child(_heading("EKRAN"))
	list.add_child(_choice("window_mode", "Pencere", ["Pencere", "Kenarsız tam ekran", "Tam ekran"], ""))
	list.add_child(_toggle("vsync", "Dikey senkron (V-Sync)", ""))
	list.add_child(_choice("fps_limit", "Kare sınırı", ["30", "60", "90", "120", "144", "165", "240", "Sınırsız"], ""))
	list.add_child(_slider("brightness", "Parlaklık", 50, 150, 5, "%d%%", ""))
	list.add_child(_heading("KALİTE"))
	list.add_child(_choice("preset", "Hazır ayar", Settings.PRESETS + ["Özel"], "Tek bir ayarı değiştirince Özel olur."))
	list.add_child(_slider("render_scale", "Çözünürlük ölçeği", 50, 100, 5, "%d%%", ""))
	list.add_child(_choice("upscaler", "Büyütme", ["Doğrusal", "AMD FSR 1", "AMD FSR 2"], "Ölçek %100'ün altındayken. FSR 2 en keskini, en ağırı."))
	list.add_child(_choice("antialias", "Kenar yumuşatma", ["Kapalı", "FXAA", "MSAA 2x", "MSAA 4x", "MSAA 4x + FXAA", "TAA"], ""))
	list.add_child(_choice("shadows", "Gölgeler", ["Düşük", "Orta", "Yüksek", "Ultra"], ""))
	list.add_child(_heading("EFEKTLER"))
	list.add_child(_toggle("ssao", "Ortam kapatma (SSAO)", ""))
	list.add_child(_toggle("ssil", "Dolaylı ışık (SSIL)", ""))
	list.add_child(_toggle("ssr", "Yansımalar (SSR)", ""))
	list.add_child(_toggle("fog", "Hacimsel sis", "En ağır efekt."))
	list.add_child(_toggle("glow", "Işık parlaması", ""))
	return pl[0]


func _controls_page() -> Control:
	var keys := ["sensitivity", "ads_sensitivity", "invert_y"]
	var pl := _scroll_page(keys)
	var list: VBoxContainer = pl[1]
	list.add_child(_heading("FARE"))
	list.add_child(_slider("sensitivity", "Fare hassasiyeti", 0.1, 4.0, 0.05, "%.2f×", ""))
	list.add_child(_slider("ads_sensitivity", "Nişandayken hassasiyet", 20, 150, 5, "%d%%", "%100'de aynı fare hareketi ekranda aynı yolu alır."))
	list.add_child(_toggle("invert_y", "Dikey ekseni ters çevir", ""))
	list.add_child(_heading("TUŞLAR"))
	for a in Settings.ACTIONS:
		list.add_child(_bind(a[0], a[1]))
	return pl[0]


func _game_page() -> Control:
	var keys := ["fov", "head_bob", "screen_shake", "crosshair_color", "crosshair_size", "crosshair_dot", "show_fps"]
	var pl := _scroll_page(keys)
	var list: VBoxContainer = pl[1]
	list.add_child(_heading("KAMERA"))
	list.add_child(_slider("fov", "Görüş açısı", 60, 110, 1, "%d°", ""))
	list.add_child(_slider("head_bob", "Kafa sallantısı", 0, 100, 5, "%d%%", ""))
	list.add_child(_slider("screen_shake", "Ekran sarsıntısı", 0, 100, 5, "%d%%", ""))
	list.add_child(_heading("NİŞANGÂH"))
	list.add_child(_choice("crosshair_color", "Renk", ["Beyaz", "Yeşil", "Sarı", "Camgöbeği", "Turuncu"], ""))
	list.add_child(_slider("crosshair_size", "Boyut", 50, 200, 10, "%d%%", ""))
	list.add_child(_toggle("crosshair_dot", "Orta nokta", ""))
	list.add_child(_heading("EKRAN BİLGİSİ"))
	list.add_child(_toggle("show_fps", "FPS göstergesi", ""))
	return pl[0]


# --- rows --------------------------------------------------------------------------------------

## A row: the name on the left, `control` on the right; hovered, it lights and tells what it does.
func _row(title: String, info: String, control: Control) -> PanelContainer:
	var row := PanelContainer.new()
	var calm := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 0)
	calm.content_margin_left = 12
	calm.content_margin_right = 18  # clear of the scroll bar
	var lit := calm.duplicate() as StyleBoxFlat
	lit.bg_color = ROW_HOVER
	row.add_theme_stylebox_override("panel", calm)
	row.custom_minimum_size.y = ROW_H
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.set_meta(&"info", info)  # tools/pause_check.gd: the strip must hold it
	row.mouse_entered.connect(func() -> void:
		row.add_theme_stylebox_override("panel", lit)
		_info.text = info)
	row.mouse_exited.connect(func() -> void: row.add_theme_stylebox_override("panel", calm))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var name := UiStyle.label(title, 17, UiStyle.MEDIUM)
	name.custom_minimum_size.x = NAME_W
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(name)
	control.custom_minimum_size.x = CONTROL_W
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(control)
	return row


func _heading(text: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(_gap(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiStyle.label(text, 12, UiStyle.BOLD, SIGNAL, 3))
	var l := UiStyle.line(0, Color(1, 1, 1, 0.1))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	col.add_child(row)
	return col


func _slider(key: String, title: String, lo: float, hi: float, step: float, fmt: String, info: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	_style_slider(s)
	h.add_child(s)
	var v := UiStyle.label("", 16, UiStyle.BOLD, BRASS)
	v.custom_minimum_size.x = 70
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	var show := func() -> void:
		s.set_value_no_signal(Settings.value(key))
		v.text = (fmt % Settings.value(key)).replace(".", ",")  # Turkish decimals
	s.value_changed.connect(func(x: float) -> void:
		Settings.set_value(key, x if Settings.DEFAULTS[key] is float else int(x)))
	_refresh.append(show)
	show.call()
	return _row(title, info, h)


func _choice(key: String, title: String, options: Array, info: String) -> Control:
	return _choice_values(key, title, range(options.size()), options, info)


## ◀ value ▶: the arrows (or a click on the value) step through `values`, written as `names`.
func _choice_values(key: String, title: String, values: Array, names: Array, info: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var prev := _small_button("◀")
	prev.custom_minimum_size = Vector2(44, 34)
	h.add_child(prev)
	var mid := _small_button("")
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.custom_minimum_size.y = 34
	mid.clip_text = true
	mid.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD))
	mid.add_theme_font_size_override("font_size", 15)
	mid.set_meta(&"names", names)  # tools/pause_check.gd: every one must fit
	h.add_child(mid)
	var next := _small_button("▶")
	next.custom_minimum_size = Vector2(44, 34)
	h.add_child(next)
	var at := func() -> int: return maxi(0, values.find(Settings.value(key)))
	var step := func(d: int) -> void:
		if values.size() > 0:
			Settings.set_value(key, values[wrapi(at.call() + d, 0, values.size())])
	prev.pressed.connect(step.bind(-1))
	next.pressed.connect(step.bind(1))
	mid.pressed.connect(step.bind(1))
	var show := func() -> void:
		mid.text = names[at.call()] if names.size() > 0 else "—"
		mid.add_theme_color_override("font_color", UiStyle.DIM if key == "preset" and Settings.value(key) == Settings.CUSTOM else BRASS)
	_refresh.append(show)
	show.call()
	return _row(title, info, h)


func _toggle(key: String, title: String, info: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.alignment = BoxContainer.ALIGNMENT_END
	var off := _small_button("KAPALI")
	var on := _small_button("AÇIK")
	for b in [off, on]:
		b.custom_minimum_size = Vector2(110, 34)
		h.add_child(b)
	off.pressed.connect(func() -> void: Settings.set_value(key, false))
	on.pressed.connect(func() -> void: Settings.set_value(key, true))
	var show := func() -> void:
		var v: bool = Settings.value(key)
		_segment(off, not v, Color(0.55, 0.55, 0.55))
		_segment(on, v, Color(0.24, 0.86, 0.38))
	_refresh.append(show)
	show.call()
	return _row(title, info, h)


func _segment(b: Button, lit: bool, color: Color) -> void:
	var s := _box(Color(color, 0.22) if lit else Color(0, 0, 0, 0.25), Color(color, 0.8) if lit else Color(1, 1, 1, 0.1), 4, 6)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", UiStyle.WHITE if lit else UiStyle.DIM)


func _bind(action: String, title: String) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	var b := _small_button("")
	b.custom_minimum_size = Vector2(220, 34)
	b.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD))
	b.add_theme_font_size_override("font_size", 15)
	b.set_meta(&"names", ["Bir tuşa bas…", "Teker aşağı", "Caps Lock"])
	h.add_child(b)
	b.pressed.connect(func() -> void:
		listening = action
		b.text = "Bir tuşa bas…"
		b.add_theme_color_override("font_color", SIGNAL)
		_info.text = "%s için bir tuşa ya da fare tuşuna bas. Esc vazgeçer." % title)
	var show := func() -> void:
		b.text = Settings.bind_text(action)
		b.add_theme_color_override("font_color", UiStyle.WHITE)
	_refresh.append(show)
	show.call()
	return _row(title, "Başka bir işin tuşunu seçersen ikisi yer değiştirir.", h)


## The next key or button goes to the action waiting; Esc gives up.
func _listen(event: InputEvent) -> void:
	var e: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			listening = ""
			_refresh_rows()
			_info.text = "Vazgeçildi."
			get_viewport().set_input_as_handled()
			return
		var k := InputEventKey.new()
		k.physical_keycode = (event as InputEventKey).physical_keycode
		e = k
	elif event is InputEventMouseButton and event.pressed:
		var m := InputEventMouseButton.new()
		m.button_index = (event as InputEventMouseButton).button_index
		e = m
	if e == null:
		return
	get_viewport().set_input_as_handled()
	var action := listening
	listening = ""
	var other := Settings.rebind(action, e)
	_info.text = "%s artık %s." % [_action_name(action), Settings.bind_text(action)]
	if other != "":
		_info.text += " %s, %s tuşuna geçti." % [_action_name(other), Settings.bind_text(other)]


static func _action_name(action: String) -> String:
	for a in Settings.ACTIONS:
		if a[0] == action:
			return a[1]
	return action


# --- looks -------------------------------------------------------------------------------------

func _stencil(text: String, size: int, color: Color) -> Label:
	var l := UiStyle.label(text, size, UiStyle.REGULAR, color)
	l.add_theme_font_override("font", STENCIL)
	return l


func _flat_button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", STENCIL)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", UiStyle.WHITE)
	b.add_theme_color_override("font_hover_color", BRASS)
	b.add_theme_color_override("font_pressed_color", SIGNAL)
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, none)
	return b


func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD, 1))
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", UiStyle.WHITE)
	b.add_theme_color_override("font_hover_color", BRASS)
	b.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.1), 4, 8))
	b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.06), Color(BRASS, 0.7), 4, 8))
	b.add_theme_stylebox_override("pressed", _box(Color(BRASS, 0.18), Color(BRASS, 0.9), 4, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _keycap(text: String) -> Label:
	var l := UiStyle.label(text, 13, UiStyle.BOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 120
	l.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.16), 4, 3))
	return l


func _style_slider(s: HSlider) -> void:
	var track := _box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 3, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := _box(Color(BRASS, 0.85), Color(0, 0, 0, 0), 3, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", _knob)
	s.add_theme_icon_override("grabber_highlight", _knob)
	s.custom_minimum_size.y = 20


static func _box(fill: Color, edge: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Yellow and black hazard stripes, `w` by `h` px.
func _hazard(w: float, h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.clip_contents = true
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.08, 0.08, 0.07))
		var x := -h
		while x < c.size.x + h:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + h, 0), Vector2(x + h * 2, 0), Vector2(x + h, h)]), Color(0.95, 0.72, 0.1))
			x += h * 2.0)
	return c


## Brass corner marks round `r`, like a sight's frame.
func _brackets(r: Rect2) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var arm := 22.0
		var col := Color(BRASS, 0.8)
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var p: Vector2 = corner * c.size
			var dx := arm if corner.x == 0 else -arm
			var dy := arm if corner.y == 0 else -arm
			c.draw_line(p, p + Vector2(dx, 0), col, 2.0)
			c.draw_line(p, p + Vector2(0, dy), col, 2.0))
	return c


static func _circle(d: int, color: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			var edge := clampf(r - 2.0 - dist, 0.0, 1.0)  # a dark rim
			img.set_pixel(x, y, Color(color.lerp(Color(0.1, 0.08, 0.04), 1.0 - edge), a))
	return ImageTexture.create_from_image(img)
