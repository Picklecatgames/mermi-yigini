class_name UiStyle
## Shared look helpers, in the range's own look (POLİGON 7, docs/ayrintilar.md "Arayüz"): the big
## numbers stencilled like an ammo crate's (Stardos Stencil, `stencil`), orders and quests typed on
## paper (Courier Prime, `typed`, `paper_box`), names and numbers in Oswald, the rest IBM Plex Sans
## Condensed (all OFL, 2026-10-28, the user's call: the Barlow set read as bland). Brass from the
## heap as the one accent, green for money, square dark steel plates where text needs a ground,
## icons from one set (game-icons.net, `icon`) in place of words. Every key the player presses is a
## small key cap (keycap / hint). Few words: a number or an icon says it when it can.

const TEXT := {
	400: preload("res://assets/fonts/IBMPlexSansCondensed-Regular.ttf"),
	500: preload("res://assets/fonts/IBMPlexSansCondensed-Medium.ttf"),
	600: preload("res://assets/fonts/IBMPlexSansCondensed-SemiBold.ttf"),
	700: preload("res://assets/fonts/IBMPlexSansCondensed-Bold.ttf"),
}
const DISPLAY := preload("res://assets/fonts/Oswald.ttf")  # variable: any weight 200-700
const STENCIL := preload("res://assets/fonts/StardosStencil-Bold.ttf")
const TYPEWRITER := preload("res://assets/fonts/CourierPrime-Regular.ttf")
const PAPER := preload("res://assets/ui/paper.jpg")  # ambientCG Paper006, CC0
const PAPER_INK := Color(0.12, 0.11, 0.1)  # typewriter ribbon on paper
const PAPER_FADED := Color(0.12, 0.11, 0.1, 0.62)
const PAPER_GREEN := Color(0.12, 0.45, 0.22)  # a done line, in green pencil
const WHITE := Color(0.933, 0.918, 0.886)  # bone, not paper white
const DIM := Color(0.62, 0.64, 0.66)
const LINE := Color(1, 1, 1, 0.16)
const ACCENT := Color(0.89, 0.69, 0.29)  # the heap's brass
const MONEY := Color(0.42, 0.89, 0.55)
const WARN := Color(1.0, 0.42, 0.3)
const INK := Color(0.075, 0.08, 0.072, 0.94)  # panels: dark olive steel
const SHADOW := Color(0, 0, 0, 0.6)  # keeps text readable over a lit wall
const REGULAR := 400
const MEDIUM := 500
const SEMIBOLD := 600
const BOLD := 700
const LIGHT := REGULAR  # kept for callers; nothing is drawn thinner than regular
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


## IBM Plex Sans Condensed at the nearest weight there is, or Oswald (`condensed`) at exactly
## `weight`; figures all one width so numbers don't jitter as they count, `track` px between letters.
static func face(weight := REGULAR, track := 0, condensed := false) -> FontVariation:
	var key := [condensed, weight, track]
	if not _faces.has(key):
		var ts := TextServerManager.get_primary_interface()
		var f := FontVariation.new()
		if condensed:
			f.base_font = DISPLAY
			f.variation_opentype = {ts.name_to_tag("wght"): clampi(weight, 200, 700)}
		else:
			var best: int = TEXT.keys()[0]
			for w: int in TEXT:
				if absi(w - weight) < absi(best - weight):
					best = w
			f.base_font = TEXT[best]
		f.opentype_features = {ts.name_to_tag("tnum"): 1}
		f.spacing_glyph = track
		_faces[key] = f
	return _faces[key]


static func label(text: String, size: int, weight := REGULAR, color := WHITE, track := 0) -> Label:
	return _styled(text, size, face(weight, track), color)


## Numbers and names: Oswald.
static func display(text: String, size: int, weight := SEMIBOLD, color := WHITE) -> Label:
	return _styled(text, size, face(weight, 0, true), color)


## The small label over or under a number ("Şarjör", "Takım kasası").
static func caption(text: String, color := DIM) -> Label:
	return label(text, 14, MEDIUM, color)


## A big number stencilled like the range's signs.
static func stencil(text: String, size: int, color := WHITE) -> Label:
	return _styled(text, size, STENCIL, color)


## Typed on paper: no shadow, the ribbon's ink.
static func typed(text: String, size: int, color := PAPER_INK) -> Label:
	var l := _styled(text, size, TYPEWRITER, color)
	l.remove_theme_color_override("font_shadow_color")
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


## A sheet of paper to type on, `pad` px inside.
static func paper_box(pad := 12) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = PAPER
	s.modulate_color = Color(0.93, 0.9, 0.82)  # aged, a little warm
	s.region_rect = Rect2(0, 0, 420, 420)  # a patch: the whole 1K sheet shrunk reads as flat
	s.set_content_margin_all(pad)
	return s


## An icon from the one set (assets/ui/icons, game-icons.net: white silhouettes, CC-BY 3.0) in place
## of a word, `size` px, tinted `color`: bullets, magazine, combo, coins, target, key, crate, check.
static func icon(kind: String, size := 16.0, color := DIM) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/ui/icons/%s.svg" % kind)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = color
	return t


## A thing the game has, as itself (assets/ui/items, tools/build_item_icons.py: rendered from its
## own model): round, rounds, clone, electric, heavy, ingot (brass), melt, press. `size` px; shut
## ones dimmed.
static func item(kind: String, size := 32.0, shut := false) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/ui/items/%s.png" % kind)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shut:
		t.modulate = Color(0.62, 0.62, 0.62, 0.85)
	return t


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


## Words the game writes for a key -> its picture in assets/ui/keys (Kenney Input Prompts, CC0).
## Any other key is keyboard_<key>.
const KEY_ART := {"esc": "keyboard_escape", "sol tık": "mouse_left", "sol tik": "mouse_left",
	"sağ tık": "mouse_right", "sağ tik": "mouse_right", "tekerlek": "mouse_scroll"}


## A key on the keyboard or the mouse, Kenney's picture of it, about twice `size` px tall; a range
## ("1-9") is its two ends. `key_color` tints it (the Q turns brass when something can be bought).
static func keycap(key: String, size := 14, key_color := WHITE) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.name = "Keycap"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(row)
	var ends := key.replace(" ", "").split("-") if key.length() > 1 and key.contains("-") else PackedStringArray([key])
	for i in ends.size():
		if i > 0:
			row.add_child(label("–", size, SEMIBOLD))
		var name_: String = KEY_ART.get(ends[i].to_lower(), "keyboard_" + ends[i].to_lower())
		var path := "res://assets/ui/keys/%s.png" % name_
		if not ResourceLoader.exists(path):
			push_warning("no key art for '%s'" % key)
			row.add_child(label(ends[i], size, SEMIBOLD))
			continue
		var t := TextureRect.new()
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2.ONE * roundf(size * 2.0)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(t)
	tint_keycap(cap, key_color)
	return cap


static func tint_keycap(cap: PanelContainer, c: Color) -> void:
	cap.modulate = c


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


## The dark steel plate panels stand on: square-cut (corners at most 2 px whatever `radius` asks),
## `pad` px inside, a lighter top edge where the light catches the sheet.
static func panel_box(radius := 6, pad := 14, fill := INK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = Color(1, 1, 1, 0.06)
	s.set_border_width_all(1)
	s.border_width_top = 2
	s.set_corner_radius_all(mini(radius, 2))
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


## The menus' steel (assets/ui/plates, tools/build_ui_plates.py: ambientCG scans cut to the shape of
## Kenney UI Pack depth buttons, CC0): kind -> [how many variants, their 9-slice corner in px].
const PLATES := {"card": [8, 28], "row": [4, 28], "button": [6, 16], "tray": [1, 28], "chain": [1, 28],
	"cork": [1, 28], "hazard": [8, 16], "machine": [4, 28], "brass": [4, 16], "slot": [3, 12], "fill": [3, 12],
	"pip": [4, 10]}
const LIPS := {"card": 3, "row": 3, "button": 3, "machine": 3, "brass": 3}  # px of a plate's foot under its face
const BACKDROP := preload("res://materials/ui_backdrop.gdshader")
const PLATE_GREY := Color(0.4, 0.41, 0.4)  # a sheet of steel as a card
const PLATE_OLIVE := Color(0.5, 0.68, 0.32)  # painted army green: ready to buy, to claim
const MACHINE_PAINT := Color(0.42, 0.48, 0.43)  # the workshop machines' chipped green, darkened under text
const BRASS := Color(0.96, 0.8, 0.5)
const BRASS_INK := Color(0.16, 0.1, 0.04)  # stamped into the brass
const SLOT_TINT := Color(0.42, 0.43, 0.42)  # a gauge's slot, sunk and in shadow


## Behind a menu, over the whole screen: the game blurred and darkened, darkest at the edges. The
## menu has no frame of its own.
static func backdrop() -> ColorRect:
	var r := ColorRect.new()
	r.material = ShaderMaterial.new()
	(r.material as ShaderMaterial).shader = BACKDROP
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


## A shaped steel plate of `kind` (rounded corners, a rim, an inset line, a lip at the foot), 9-sliced
## to any size; `key` picks one of its variants, so cards side by side are different steel. `tint`
## over it, `pad` px inside. card: a card, row: an upgrade, button: a price in reach, tray: what
## the cards stand in, chain/cork: the quest board's halves, hazard: a shut piece's stage.
static func plate(kind: String, key: Variant = 0, tint := PLATE_GREY, pad := 12) -> StyleBoxTexture:
	var spec: Array = PLATES[kind]
	var s := StyleBoxTexture.new()
	s.texture = load("res://assets/ui/plates/%s_%d.png" % [kind, absi(hash(key)) % spec[0]])
	s.set_texture_margin_all(spec[1])
	s.modulate_color = tint
	s.set_content_margin_all(pad)
	# The depth shapes have a lip at the foot: their face, where text should sit centred, ends above it.
	var lip: int = LIPS.get(kind, 0)
	s.content_margin_top = maxi(pad - lip, 0)
	s.content_margin_bottom = pad + lip
	return s


## A workshop machine's card (the bench, the hopper, the press): the machines' own chipped green
## paint on steel (plate "machine"); `tint` over MACHINE_PAINT for a card that stands out.
static func machine_card(key: Variant = 0, pad := 18, tint := MACHINE_PAINT) -> StyleBoxTexture:
	return plate("machine", key, tint, pad)


## A stamped brass button (a price in reach, a machine's main act): the ink pressed into it, a
## little brighter hovered, darker pressed; shut, dark steel.
static func brass_button(b: Button, key: Variant = 0) -> void:
	b.add_theme_stylebox_override("normal", plate("brass", key, BRASS, 8))
	b.add_theme_stylebox_override("hover", plate("brass", key, BRASS.lightened(0.12), 8))
	b.add_theme_stylebox_override("pressed", plate("brass", key, BRASS.darkened(0.18), 8))
	b.add_theme_stylebox_override("disabled", plate("button", key, Color(0.3, 0.31, 0.3), 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for s: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(s, BRASS_INK)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.7))
	b.add_theme_constant_override("outline_size", 0)


## A plate (`kind`) for a small piece, its 9-slice corners cut to fit `height` px.
static func small_plate(kind: String, key: Variant, tint: Color, height: float) -> StyleBoxTexture:
	var s := plate(kind, key, tint, 0)
	s.set_texture_margin_all(minf(PLATES[kind][1], floorf(height / 2.0)))
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s


## A gauge: a slot sunk in the steel (plate "slot"), brass filling it from the left (plate "fill");
## set_bar says how far. In place of a flat line where something fills or drains.
static func bar(width: float, height := 16.0, key: Variant = 0, tint := BRASS) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("fill", 0.0)
	var slot := small_plate("slot", key, SLOT_TINT, height)
	var lit := small_plate("fill", key, tint, height)
	c.draw.connect(func() -> void:
		c.draw_style_box(slot, Rect2(Vector2.ZERO, c.size))
		draw_fill(c, lit, Rect2(Vector2.ZERO, c.size), c.get_meta("fill")))
	return c


## Brass (`box`, plate "fill") `fill` of the way along a gauge's slot `slot`: inside its rim, never
## past it; a short fill takes its corners in rather than standing out wider than it is.
static func draw_fill(on: CanvasItem, box: StyleBoxTexture, slot: Rect2, fill: float) -> void:
	var inside := slot.grow(-clampf(roundf(slot.size.y * 0.12), 2.0, 5.0))
	var w := inside.size.x * clampf(fill, 0.0, 1.0)
	if w < 2.0:
		return
	box.set_texture_margin_all(minf(PLATES["fill"][1], floorf(minf(w, inside.size.y) / 2.0)))
	on.draw_style_box(box, Rect2(inside.position, Vector2(w, inside.size.y)))


static func set_bar(c: Control, fill: float) -> void:
	c.set_meta("fill", clampf(fill, 0.0, 1.0))
	c.queue_redraw()


## A level box: a small steel stud (plate "pip"), `tint` over it, `size` px square.
static func pip(key: Variant, tint: Color, size := 14.0) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", small_plate("pip", key, tint, size))
	return p


## A plate button: painted army green, a little brighter hovered, pressed darker; shut, dark steel.
static func plate_button(b: Button, key: Variant = 0, tint := PLATE_OLIVE) -> void:
	b.add_theme_stylebox_override("normal", plate("button", key, tint, 8))
	b.add_theme_stylebox_override("hover", plate("button", key, tint.lightened(0.15), 8))
	b.add_theme_stylebox_override("pressed", plate("button", key, tint.darkened(0.2), 8))
	b.add_theme_stylebox_override("disabled", plate("button", key, Color(0.3, 0.31, 0.3), 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## A sheet of scanned steel to stand things on (plate "card"), where a flat dark box would read
## as a placeholder.
static func steel_panel(key: Variant = 0, pad := 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", plate("card", key, PLATE_GREY, pad))
	return p


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
