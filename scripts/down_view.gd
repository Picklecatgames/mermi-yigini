extends Control
## What going down looks like on our own screen (docs/ayrintilar.md "Baygınlık"), over the HUD.
## A blow: a blood spray at the screen's edge on the side it came from and a short red pulse round
## the edges (player.gd shakes the view); no words. Down: over DOWN_RED the colour drains, the edges
## close in red and a heartbeat thumps through it, slowing; then black over DOWN_DARK. Once dark
## the view goes to a standing teammate (player.gd watching), the red eases to a faint rim and their
## name shows at the bottom; left and right click for the next. Revived, it all lifts.
## Sounds come from the user (assets/sounds/player/<slot>.ogg|wav): hurt, down, heartbeat, revive.
## A missing file stays silent. Numbers are first guesses.

const BLOOD := preload("res://scripts/blood_fx.gd")
const SOUNDS := "res://assets/sounds/player/"
const MARK_TIME := 0.9  # s a blow's spray stays
const MARK_SIZE := 0.42  # of the screen's height
const MARK_RING := Vector2(0.36, 0.34)  # of the screen, from the middle out to where the sprays sit
const HIT_TIME := 0.35  # s the red pulse round the edges fades in
const LIFT := 0.6  # s the red and the dark take to clear
const WATCH_RED := 0.25  # the rim left while watching a teammate
const BEAT := Vector2(1.3, 0.55)  # beats a second, falling to the floor .. fading out
const SHADER := """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float red = 0.0;   // 0..1, down: colour drains, edges close in
uniform float dark = 0.0;  // 0..1 to black
uniform float beat = 0.0;  // 0..1, a heartbeat's thump
uniform float hit = 0.0;   // 0..1, a blow's pulse round the edges
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(grey), red * 0.85);
	c *= mix(vec3(1.0), vec3(1.0, 0.55, 0.5), red);
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	float r = length(d) * 2.0;
	float close = 1.0 - red * 0.55 - beat * 0.12;
	float edge = smoothstep(close - 0.45, close + 0.35, r) * clamp(red * 1.4, 0.0, 1.0);
	edge = max(edge, smoothstep(0.55, 1.15, r) * hit);
	c = mix(c, vec3(0.32, 0.0, 0.0) * (1.0 + beat * 0.6), edge);
	c *= 1.0 - dark;
	COLOR = vec4(c, 1.0);
}"""

var player: Node  # player.gd, for whom it watches
var _tint := ColorRect.new()
var _marks: Control = Control.new()
var _name: Label
var _hits: Array[Dictionary] = []  # from (world), age, texture
var _hit := 0.0
var _red := 0.0
var _dark := 0.0
var _beat_t := 0.0
var _beat := 0.0
var _rng := RandomNumberGenerator.new()
var _voice := AudioStreamPlayer.new()
var _heart := AudioStreamPlayer.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHADER
	_tint.material = mat
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.visible = false
	add_child(_tint)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_name = UiStyle.display("", 30, UiStyle.BOLD)
	_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_name.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.offset_top = -150
	_name.visible = false
	add_child(_name)
	add_child(_voice)
	add_child(_heart)
	GameState.health_changed.connect(_on_health)
	GameState.player_downed.connect(func(peer: int) -> void: _cry(&"down", peer))
	GameState.player_revived.connect(func(peer: int) -> void: _cry(&"revive", peer))


func _on_health(peer: int, _hp: float, from: Vector3, hurt: bool) -> void:
	if not hurt or peer != GameState.local_peer():
		return
	_hit = 1.0
	_play(_voice, &"hurt")
	if from != Vector3.ZERO:
		_hits.append({"from": from, "age": 0.0, "tex": BLOOD._tex(&"spray", _rng.randi() % BLOOD.SETS[&"spray"])[0]})


## Down or up: ours in our ears, a teammate's from where their body is.
func _cry(slot: StringName, peer: int) -> void:
	if peer == GameState.local_peer():
		_play(_voice, slot)
		return
	var rp := get_tree().get_first_node_in_group("remote_players")
	var them: Node3D = rp.character(peer) if rp else null
	var stream := _stream(slot)
	if them and stream:
		var p := AudioStreamPlayer3D.new()
		p.stream = stream
		them.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)


func _process(delta: float) -> void:
	var p := GameState.player()
	var t := p.down_for
	var watching: int = player.watching if player else 0
	var want_red := 0.0
	var want_dark := 0.0
	if p.down:
		want_red = clampf(t / GameState.DOWN_RED, 0.0, 1.0) if t < GameState.DOWN_TIME else (WATCH_RED if watching != 0 else 1.0)
		want_dark = clampf((t - GameState.DOWN_RED) / GameState.DOWN_DARK, 0.0, 1.0) if watching == 0 else 0.0
	_red = want_red if want_red > _red else move_toward(_red, want_red, delta / LIFT)
	_dark = want_dark if want_dark > _dark else move_toward(_dark, want_dark, delta / LIFT)
	_hit = maxf(_hit - delta / HIT_TIME, 0.0)
	# The heart: thumps while the red comes on, slower as it fades out, still once dark.
	_beat = 0.0
	if p.down and t < GameState.DOWN_TIME:
		var was := _beat_t
		_beat_t += delta * lerpf(BEAT.x, BEAT.y, _red)
		if floorf(_beat_t) != floorf(was):
			_play(_heart, &"heartbeat")
		_beat = pow(maxf(sin(fposmod(_beat_t, 1.0) * TAU), 0.0), 6.0)
	else:
		_beat_t = 0.0
	_tint.visible = _red > 0.001 or _dark > 0.001 or _hit > 0.0
	if _tint.visible:
		var mat := _tint.material as ShaderMaterial
		mat.set_shader_parameter("red", _red)
		mat.set_shader_parameter("dark", _dark)
		mat.set_shader_parameter("beat", _beat * _red)
		mat.set_shader_parameter("hit", _hit)
	_name.visible = p.down and watching != 0
	if _name.visible:
		_name.text = GameState.display_name(watching)
		_name.add_theme_color_override("font_color", GameState.color_of(watching))
	for h in _hits:
		h.age += delta
	_hits = _hits.filter(func(h: Dictionary) -> bool: return h.age < MARK_TIME)
	_marks.queue_redraw()


## A spray per blow, at the edge on the side it came from, its dense end outward.
func _draw_marks() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var view := _marks.size
	var mid := view * 0.5
	for h in _hits:
		var to: Vector3 = cam.global_basis.inverse() * ((h.from as Vector3) - cam.global_position)
		var a := atan2(to.x, -to.z)  # 0 ahead (up the screen), clockwise
		var at := mid + Vector2(sin(a), -cos(a)) * view * MARK_RING
		var tex: Texture2D = h.tex
		var s: float = view.y * MARK_SIZE
		var fade: float = 1.0 - h.age / MARK_TIME
		_marks.draw_set_transform(at, a + PI * 0.5)  # the spray's +u from the edge in toward the middle
		_marks.draw_texture_rect(tex, Rect2(Vector2(-s * 0.5, -s * 0.25), Vector2(s, s * 0.5)), false, Color(1.0, 0.9, 0.9, fade))
	_marks.draw_set_transform(Vector2.ZERO)


func _play(on: AudioStreamPlayer, slot: StringName) -> void:
	var stream := _stream(slot)
	if stream:
		on.stream = stream
		on.play()


func _stream(slot: StringName) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(SOUNDS + String(slot) + ext):
			return load(SOUNDS + String(slot) + ext)
	return null
