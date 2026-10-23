class_name UiStyle
## Shared look helpers: the face (Inter), the few colours, labels with a soft shadow, thin lines
## and the screen-fit scaling.

const FACE := preload("res://assets/fonts/Inter.ttf")
const WHITE := Color(0.953, 0.957, 0.961)
const DIM := Color(0.64, 0.66, 0.68)
const LINE := Color(1, 1, 1, 0.22)
const ACCENT := Color(1.0, 0.42, 0.24)
const SHADOW := Color(0, 0, 0, 0.55)  # keeps white text readable over a lit wall
const CAPTION_TRACK := 2  # px between letters of the small labels
const LIGHT := 300
const REGULAR := 400
const MEDIUM := 500
const BOLD := 700
const BASE_HEIGHT := 1080.0  # px, the screen height the sizes here are drawn for

static var _faces := {}  # [weight, tracking] -> FontVariation


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


## Inter at `weight`, figures all one width (numbers don't jitter as they count), `track` px
## between letters.
static func face(weight := REGULAR, track := 0) -> FontVariation:
	var key := [weight, track]
	if not _faces.has(key):
		var ts := TextServerManager.get_primary_interface()
		var f := FontVariation.new()
		f.base_font = FACE
		f.variation_opentype = {ts.name_to_tag("wght"): weight}
		f.opentype_features = {ts.name_to_tag("tnum"): 1}
		f.spacing_glyph = track
		_faces[key] = f
	return _faces[key]


static func label(text: String, size: int, weight := REGULAR, color := WHITE, track := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", face(weight, track))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 4)
	return l


## The small spaced-out label over a number ("şarjör", "altın").
static func caption(text: String, color := DIM) -> Label:
	return label(text, 12, REGULAR, color, CAPTION_TRACK)


## A 1 px rule, `width` px long (0: as wide as its container lets it).
static func line(width := 0.0, color := LINE) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(width, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A thin progress rule `width` px long; set_meter lights a share of it.
static func meter(width: float, color := WHITE) -> Control:
	var track := line(width)
	var lit := ColorRect.new()
	lit.color = color
	lit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lit.size = Vector2(0, 1)
	track.add_child(lit)
	return track


static func set_meter(track: Control, fill: float) -> void:
	(track.get_child(0) as ColorRect).size = Vector2(track.custom_minimum_size.x * clampf(fill, 0.0, 1.0), 1)
