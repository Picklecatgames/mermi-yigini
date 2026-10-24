class_name UiStyle
## Shared look helpers. Barlow for reading, Barlow Condensed for numbers and names (both OFL);
## brass from the heap as the one accent, green for money, a dark steel panel where text needs a
## ground. Every key the player presses is drawn as a small key cap (keycap / hint). Text is in
## sentence case.

const TEXT := {
	400: preload("res://assets/fonts/Barlow-Regular.ttf"),
	500: preload("res://assets/fonts/Barlow-Medium.ttf"),
	600: preload("res://assets/fonts/Barlow-SemiBold.ttf"),
}
const DISPLAY := {
	500: preload("res://assets/fonts/BarlowCondensed-Medium.ttf"),
	600: preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf"),
	700: preload("res://assets/fonts/BarlowCondensed-Bold.ttf"),
}
const WHITE := Color(0.933, 0.918, 0.886)  # bone, not paper white
const DIM := Color(0.62, 0.64, 0.66)
const LINE := Color(1, 1, 1, 0.16)
const ACCENT := Color(0.89, 0.69, 0.29)  # the heap's brass
const MONEY := Color(0.42, 0.89, 0.55)
const WARN := Color(1.0, 0.42, 0.3)
const INK := Color(0.07, 0.078, 0.086, 0.9)  # panels: dark steel
const SHADOW := Color(0, 0, 0, 0.6)  # keeps text readable over a lit wall
const REGULAR := 400
const MEDIUM := 500
const SEMIBOLD := 600
const BOLD := 700
const LIGHT := REGULAR  # kept for callers; Barlow is never drawn thinner than regular
const BASE_HEIGHT := 1080.0  # px, the screen height the sizes here are drawn for

static var _faces := {}  # [condensed, weight, tracking] -> FontVariation


## Keeps a screen-wide control over the whole screen as the window changes, scaled past
## BASE_HEIGHT so text keeps its size on 1440p and 4K (never shrunk below 1).
static func fit_screen(c: Control) -> void:
	var vp := c.get_viewport()
	var fit := func() -> void:
		if not is_instance_valid(c):
			return
		var s := vp.get_visible_rect().size
		var k := maxf(1.0, s.y / BASE_HEIGHT)
		c.scale = Vector2.ONE * k
		c.position = Vector2.ZERO
		c.size = s / k
	vp.size_changed.connect(fit)
	fit.call()


## Barlow (or Barlow Condensed) at the nearest weight there is, figures all one width so numbers
## don't jitter as they count, `track` px between letters.
static func face(weight := REGULAR, track := 0, condensed := false) -> FontVariation:
	var key := [condensed, weight, track]
	if not _faces.has(key):
		var set_: Dictionary = DISPLAY if condensed else TEXT
		var best: int = set_.keys()[0]
		for w: int in set_:
			if absi(w - weight) < absi(best - weight):
				best = w
		var f := FontVariation.new()
		f.base_font = set_[best]
		f.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
		f.spacing_glyph = track
		_faces[key] = f
	return _faces[key]


static func label(text: String, size: int, weight := REGULAR, color := WHITE, track := 0) -> Label:
	return _styled(text, size, face(weight, track), color)


## Numbers and names: Barlow Condensed.
static func display(text: String, size: int, weight := SEMIBOLD, color := WHITE) -> Label:
	return _styled(text, size, face(weight, 0, true), color)


## The small label over or under a number ("Şarjör", "Takım kasası").
static func caption(text: String, color := DIM) -> Label:
	return label(text, 14, MEDIUM, color)


static func _styled(text: String, size: int, font: Font, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 4)
	return l


## A key on the keyboard: its letter in a small rounded cap. `key_color` tints the cap's edge and
## letter (the Q turns brass when something can be bought).
static func keycap(key: String, size := 14, key_color := WHITE) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.name = "Keycap"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.11, 0.12, 0.82)
	box.set_border_width_all(1)
	box.border_width_bottom = 2  # a key's lip
	box.set_corner_radius_all(4)
	box.content_margin_left = roundi(size * 0.45)
	box.content_margin_right = roundi(size * 0.45)
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	box.anti_aliasing = true
	cap.add_theme_stylebox_override("panel", box)
	var l := label(key, size, SEMIBOLD)  # normal width: a condensed Q reads as 0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = size * 0.7
	l.remove_theme_constant_override("shadow_outline_size")
	cap.add_child(l)
	tint_keycap(cap, key_color)
	return cap


static func tint_keycap(cap: PanelContainer, c: Color) -> void:
	(cap.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(c, 0.55)
	(cap.get_child(0) as Label).add_theme_color_override("font_color", c)


## A key cap and what it does: "[R] Basılı tut". Several keys share one action: ["W", "A", "S", "D"].
static func hint(keys: Variant, action: String, size := 14) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Hint"
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k: String in (keys if keys is Array else [keys]):
		row.add_child(keycap(k, size - 1))
	if action != "":
		var l := label(action, size, MEDIUM, DIM)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
	return row


## The dark steel ground panels stand on: `radius` px corners, `pad` px inside.
static func panel_box(radius := 6, pad := 14, fill := INK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = Color(1, 1, 1, 0.07)
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


static func panel(pad := 14, radius := 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", panel_box(radius, pad))
	return p


## A 1 px rule, `width` px long (0: as wide as its container lets it).
static func line(width := 0.0, color := LINE) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(width, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A progress bar `width` x `height` px; set_meter lights a share of it in `color`.
static func meter(width: float, color := WHITE, height := 1.0) -> Control:
	var track := line(width, Color(1, 1, 1, 0.12))
	track.custom_minimum_size.y = height
	var lit := ColorRect.new()
	lit.color = color
	lit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lit.size = Vector2(0, height)
	track.add_child(lit)
	return track


static func set_meter(track: Control, fill: float) -> void:
	var m := track.custom_minimum_size
	(track.get_child(0) as ColorRect).size = Vector2(m.x * clampf(fill, 0.0, 1.0), m.y)


## 1234567 -> "1.234.567"
static func dotted(n: int) -> String:
	var s := str(absi(n))
	for i in range(s.length() - 3, 0, -3):
		s = s.insert(i, ".")
	return ("-" if n < 0 else "") + s
