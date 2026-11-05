extends StaticBody3D
## The old tube television in the house (2026-11-05, the user: "her gün haberler olacak"; tools/build_world.gd
## _workshop_inside). Always on: between bulletins it shows the day's card, while one runs the line being
## read, both under the set's own grain and roll (materials/tv_screen.gdshader). Which day and which line is the host's
## (GameState.news_changed, news_line); this only shows it, the same on every machine. The spoken line
## comes from assets/sounds/tv/ once the recordings are here (docs/tv_ses_listesi.md); till then it is silent.
## No GameState by name in here: the builder runs without autoloads and wouldn't attach this script.

const SCREEN_AT := Vector3(-0.068, 0.25, 0.2)  # the tube's middle, the model's space
const SCREEN_SIZE := Vector2(0.4, 0.31)
const CARD_SIZE := Vector2i(160, 120)  # the picture as a tube of the time would draw it
const NOISE := {"normal": 0.16, "gecici": 0.34, "korsan": 0.5, "sessiz": 0.24, "kesik": 1.0}
const INK := Color(0.82, 0.86, 0.78)
const SOUNDS := "res://assets/sounds/tv/gun%02d_%02d.ogg"
const FLICKER := 0.5  # of the glow's strength, its swing
const GLOW := 0.95  # by night the room's one honest light

var _gs: Node
var _card: SubViewport
var _title: Label
var _line: Label
var _back: ColorRect
var _screen: ShaderMaterial
var _glow: OmniLight3D
var _voice: AudioStreamPlayer3D
var _time := 0.0
var _noise := 0.2


func _ready() -> void:
	add_to_group("tv")
	_gs = get_node_or_null("/root/GameState")
	if _gs == null:
		return
	_build_card()
	var mi := MeshInstance3D.new()
	mi.name = "Screen"
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	mi.mesh = quad
	mi.position = SCREEN_AT
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_screen = ShaderMaterial.new()
	_screen.shader = preload("res://materials/tv_screen.gdshader")
	_screen.set_shader_parameter("card", _card.get_texture())
	mi.material_override = _screen
	add_child(mi)
	_glow = OmniLight3D.new()
	_glow.position = SCREEN_AT + Vector3(0, 0, 0.45)
	_glow.light_color = Color(0.62, 0.72, 0.85)
	_glow.omni_range = 4.0
	_glow.omni_attenuation = 1.4
	_glow.light_energy = GLOW
	add_child(_glow)
	_voice = AudioStreamPlayer3D.new()
	_voice.position = SCREEN_AT
	_voice.bus = &"Master"
	_voice.unit_size = 3.0
	_voice.max_distance = 14.0
	add_child(_voice)
	_gs.news_changed.connect(func(_day: int) -> void: _show())
	_gs.news_line.connect(func(_day: int, _line_no: int) -> void: _show(true))
	_show()


func _process(delta: float) -> void:
	if _gs == null:
		return
	_time += delta
	# A tube's light never holds still: two beats and a dip now and then, from the clock alone.
	var beat := sin(_time * 13.0) * 0.5 + sin(_time * 31.0) * 0.5
	var dip := 0.5 if fmod(_time, 7.3) < 0.09 else 1.0
	_glow.light_energy = GLOW * (1.0 + beat * FLICKER * 0.3) * dip * (0.45 if _noise >= 1.0 else 1.0)


## What the set is showing now, from GameState. `speak`: a line just changed.
func _show(speak := false) -> void:
	var entry: Dictionary = _gs.news_entry(_gs.news_day)
	var lines: Array = entry.get("satirlar", [])
	var at: int = _gs.news_at
	var channel: String = entry.get("kanal", "normal")
	_noise = NOISE.get(channel, 0.2)
	_screen.set_shader_parameter("noise", _noise)
	_title.text = entry.get("baslik", "")
	_line.text = lines[at] if at >= 0 and at < lines.size() else ""
	_back.color = Color(0.05, 0.07, 0.09) if channel == "normal" else Color(0.08, 0.05, 0.04) if channel == "korsan" else Color(0.03, 0.03, 0.035)
	_card.render_target_update_mode = SubViewport.UPDATE_ONCE
	if speak:
		_speak(at)


## The recorded line, where there is one (docs/tv_ses_listesi.md).
func _speak(at: int) -> void:
	_voice.stop()
	if at < 0:
		return
	var path: String = SOUNDS % [_gs.news_day, at + 1]
	if ResourceLoader.exists(path):
		_voice.stream = load(path)
		_voice.play()


func _build_card() -> void:
	_card = SubViewport.new()
	_card.size = CARD_SIZE
	_card.disable_3d = true
	_card.transparent_bg = false
	_card.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_card)
	_back = ColorRect.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(_back)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 8
	col.offset_right = -8
	col.offset_top = 10
	col.offset_bottom = -8
	col.add_theme_constant_override("separation", 8)
	_card.add_child(col)
	_title = _label(12)
	col.add_child(_title)
	_line = _label(11)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(_line)


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
