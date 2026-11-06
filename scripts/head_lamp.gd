extends SpotLight3D
## The flashlight's light (2026-11-06, the user: the head lamp becomes a flashlight held in the hand;
## "oyuncu fener ile silah arasında tercih yapmalı"). An old red battery lantern (Poly Haven
## vintage_flashlight): F takes it out (GameState.request_toggle_torch), and then it is the hand's,
## no gun. On whenever it is in hand, day or night: the player decides, not the sun. Every player's,
## the remote ones' too: GameState.torch_changed says whose is out, on every machine.
## player.gd puts it at the lens of the flashlight in the first-person hand, remote_players.gd at the
## lens of the one in the body's hand, each frame (follow): the beam lags the hand a little.
##
## The beam (2026-11-06, the user: "sadece önümüz sarıya boyanıyor gibi oluyor, gerçek bir fener
## mekaniği olsun"; and square, oblong glitches with it on): the world is lit per vertex
## (materials/psx.gdshader, the PS1 look), so a narrow beam with a hard edge lit some corners of a
## big face and not the next, and drew the face's triangles; the projector's hard rim the same. Now
## it is a hot middle falling off softly to the edge, whiter (a bulb run on a fresh battery), strong
## close and weak far (the square of the distance, about), and round it a wide, faint spill
## (SPILL) and the light thrown back near the hand (BOUNCE), as from a real flashlight. Shadows from
## the beam only. The local player's hands take its light from player.gd (LAMP_HANDS, `lit`).
## Two scares ride it (scripts/lamp_flicker.gd picks them on the host, every machine plays them from
## a seed): a flicker now and then (flicker_steps; a loose contact, mostly when something unseen is
## close), and in the wood, seldom, it dies outright (blackout_steps): a stutter, seconds of dark, and
## back with a stutter, sometimes with something standing there. Numbers are mine
## (docs/ayrintilar.md "Fener").

const ENERGY := 26.0
const ON_TIME := 0.06  # s: a switch, not a dimmer
const LAG := 14.0  # 1/s: how fast the beam catches up with the hand
const COLOR := Color(1.0, 0.94, 0.84)
const SPILL := {"angle": 48.0, "share": 0.12, "range": 16.0}
const BOUNCE := {"range": 3.2, "share": 0.05}
const GLOW_SIZE := 0.07  # m: the lens as others see it from in front

## 0 off .. 1 on, times the flicker.
var lit: float:
	get: return _on * flick
var held := false  # in hand (GameState PlayerState.torch of owner_peer(); tools set it by hand)
var flick := 1.0  # the flicker's share of the light; 1 steady
var _on := 0.0
var _steps: Array = []  # the flicker playing (flicker_steps, blackout_steps); empty: none
var _flick_t := 0.0  # s into it
var _blackout := false  # the playing one is a blackout
var _placed := false
var _spill := SpotLight3D.new()
var _bounce := OmniLight3D.new()
var _glow: MeshInstance3D  # the lens, lit, for the other players to see


func _init() -> void:
	light_color = COLOR
	spot_range = 32.0
	spot_angle = 24.0
	spot_angle_attenuation = 1.8  # soft to the edge: no rim for the corners of big faces to catch
	spot_attenuation = 1.0  # bright close, gone by ~25 m
	light_projector = _pattern()
	shadow_enabled = true
	shadow_bias = 0.08
	shadow_normal_bias = 1.5
	light_volumetric_fog_energy = 0.4
	light_specular = 0.3
	light_energy = 0.0
	visible = false
	top_level = true
	_spill.light_color = COLOR
	_spill.spot_angle = SPILL.angle
	_spill.spot_range = SPILL.range
	_spill.spot_angle_attenuation = 1.2
	_spill.spot_attenuation = 1.6
	_spill.shadow_enabled = false
	_spill.light_specular = 0.0
	add_child(_spill)
	_bounce.light_color = COLOR
	_bounce.omni_range = BOUNCE.range
	_bounce.omni_attenuation = 2.0
	_bounce.shadow_enabled = false
	_bounce.light_specular = 0.0
	_bounce.position = Vector3(0.0, 0.0, 0.35)  # behind the lens: the hand and what is next to us
	add_child(_bounce)


func _ready() -> void:
	_spill.light_cull_mask = light_cull_mask
	_bounce.light_cull_mask = light_cull_mask
	var gs := get_node_or_null(^"/root/GameState")
	if gs == null or not gs.has_signal(&"torch_changed"):
		return
	held = gs.player(owner_peer()).torch
	gs.torch_changed.connect(func(peer: int, on: bool) -> void:
		if peer == owner_peer():
			held = on)
	gs.lamp_flicker.connect(func(peer: int, seed: int) -> void:
		if peer == owner_peer() and not _blackout:
			flicker(seed))
	gs.torch_blackout.connect(func(peer: int, seed: int, _creature: bool) -> void:
		if peer == owner_peer():
			blackout(seed))
	if owner_peer() != multiplayer.get_unique_id():
		_glow = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * GLOW_SIZE
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = _pattern()
		m.albedo_color = COLOR * 1.4
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		quad.material = m
		_glow.mesh = quad
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.top_level = true
		add_child(_glow)


## Whose flashlight this is: a remote body's (remote_players.gd Character.peer), else the local player's.
func owner_peer() -> int:
	var p := get_parent()
	if p and &"peer" in p:
		return p.peer
	return multiplayer.get_unique_id()


## Plays the flicker `seed` from its start (one already playing gives way).
func flicker(seed: int) -> void:
	_steps = flicker_steps(seed)
	_flick_t = 0.0
	_blackout = false


## The flashlight dies for a while (blackout_steps `seed`), whatever else was playing.
func blackout(seed: int) -> void:
	_steps = blackout_steps(seed)
	_flick_t = 0.0
	_blackout = true


func flickering() -> bool:
	return not _steps.is_empty()


func blacked_out() -> bool:
	return _blackout and not _steps.is_empty()


## At the lens `lens` (-z along the beam), the beam a little behind where it turns.
func follow(lens: Transform3D, delta: float) -> void:
	if not _placed:
		global_transform = lens
		_placed = true
	else:
		var b := global_basis.orthonormalized().slerp(lens.basis.orthonormalized(), 1.0 - exp(-LAG * delta))
		global_transform = Transform3D(b, lens.origin)
	if _glow:
		_glow.global_position = lens.origin - lens.basis.z * 0.01


func _process(delta: float) -> void:
	_on = move_toward(_on, 1.0 if held else 0.0, delta / ON_TIME)
	if not _steps.is_empty():
		_flick_t += delta
		flick = flicker_level(_steps, _flick_t)
		if _flick_t >= flicker_length(_steps):
			_steps = []
			_blackout = false
			flick = 1.0
	light_energy = ENERGY * lit
	_spill.light_energy = ENERGY * SPILL.share * lit
	_bounce.light_energy = ENERGY * BOUNCE.share * lit
	visible = _on > 0.0
	if _glow:
		_glow.visible = lit > 0.05
		_glow.transparency = 1.0 - lit


## A flicker, the same on every machine from its seed: [s, level at its start, level at its end] one
## after the other, level 1 being the steady beam. A few quick drop-outs (a contact losing touch), and
## a moment dim, sagging and coming back (the battery); now one first, now the other.
static func flicker_steps(seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var cuts := _cuts(r, r.randi_range(2, 4))
	var low := r.randf_range(0.3, 0.55)
	var lower := low * r.randf_range(0.8, 1.0)
	var sag := [[r.randf_range(0.04, 0.08), 1.0, low], [r.randf_range(0.15, 0.35), low, lower],
		[r.randf_range(0.25, 0.45), lower, 1.0]]
	return sag + cuts if r.randf() < 0.3 else cuts + sag


## The flashlight dying in the wood: it stutters, sags to an ember of the filament, out for BLACKOUT
## seconds, then catches again with a stutter or two. The creature, if any, is put up halfway through
## the dark (lamp_flicker.gd CREATURE_AT), so the light comes back on it.
const BLACKOUT := Vector2(2.4, 3.6)
static func blackout_steps(seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var steps := _cuts(r, r.randi_range(3, 5))
	var ember := r.randf_range(0.02, 0.06)
	steps.append([r.randf_range(0.12, 0.25), 1.0, ember])  # the filament going orange, then out
	steps.append([r.randf_range(0.15, 0.3), ember, 0.0])
	steps.append([r.randf_range(BLACKOUT.x, BLACKOUT.y), 0.0, 0.0])
	steps.append_array(_cuts(r, r.randi_range(1, 2), true))
	return steps


## The time the light is all the way out in `steps` begins at, and how long; [-1, 0] if never.
static func dark_span(steps: Array) -> Vector2:
	var t := 0.0
	for s: Array in steps:
		if s[1] == 0.0 and s[2] == 0.0 and s[0] > 1.0:
			return Vector2(t, s[0])
		t += s[0]
	return Vector2(-1.0, 0.0)


## `n` quick drop-outs and catches; `back`: from out, catching (the light coming back on).
static func _cuts(r: RandomNumberGenerator, n: int, back := false) -> Array:
	var cuts := []
	for i in n:
		var out := r.randf_range(0.0, 0.08)  # not always quite out
		if back:
			cuts.append([r.randf_range(0.05, 0.12), 0.9, 0.9])
			cuts.append([r.randf_range(0.06, 0.15), out, out])
		else:
			cuts.append([r.randf_range(0.03, 0.07), out, out])
			cuts.append([r.randf_range(0.04, 0.12), 1.0, 1.0])
	return cuts


static func flicker_length(steps: Array) -> float:
	var n := 0.0
	for s: Array in steps:
		n += s[0]
	return n


## The beam's share at `t` s into `steps`; 1 past its end.
static func flicker_level(steps: Array, t: float) -> float:
	for s: Array in steps:
		if t < s[0]:
			return lerpf(s[1], s[2], smoothstep(0.0, 1.0, t / s[0]))
		t -= s[0]
	return 1.0


## The beam's pattern: a reflector's hot middle falling off to the edge, a faint ring where the
## reflector's lip throws it, a little unevenness from an old dented one; no hard rim (it would draw
## the per-vertex faces' edges). 64 px.
static func _pattern() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.07
	for y in 64:
		for x in 64:
			var r := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var hot := 1.0 - smoothstep(0.0, 0.55, r) * 0.55  # 1 in the middle, 0.45 at half way
			var ring := 0.12 * exp(-pow((r - 0.72) / 0.07, 2.0))
			var v := (hot + ring) * (0.9 + 0.1 * (noise.get_noise_2d(x, y) * 0.5 + 0.5))
			v *= 1.0 - smoothstep(0.75, 1.0, r)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
