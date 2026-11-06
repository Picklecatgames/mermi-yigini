extends SpotLight3D
## A head lamp (2026-11-03, the user: "Yes, a head lamp", after the PS1 critic found the open
## desert at night unplayable in the dark): a warm, narrow beam from the eyes where the head looks,
## every player's, the remote ones' too. It lights itself when the world's sun goes down and goes
## out at dawn, easing; the day and night cycle (scripts/day_night.gd) needs to do nothing for it.
## Each machine decides it alike from its own sun, so there is nothing to sync.
## player.gd and remote_players.gd place it at the eyes each frame (follow): it lags the head a
## little, a lamp strapped on, not a camera's vignette (2026-11-03, the PS1 critic). An old bulb
## behind a dented reflector: yellowish, a hard edge with a brighter ring, a blotchy middle
## (PATTERN). The local player's hands and gun take its light from player.gd (LAMP_HANDS).
## Now and then it flickers (2026-11-06, the coordinator's brief: a cheap battery or a loose contact,
## mostly when something unseen is close): the host picks when and whose (scripts/lamp_flicker.gd),
## GameState.lamp_flicker carries the peer and a seed, and every machine plays the same flicker on
## that player's lamp (flicker_steps), its own and the others' alike. `lit` takes it, so the hands
## flicker with the beam.

const ENERGY := 6.0
const EASE := 1.5  # 1/s
const DUSK := 0.3  # the sun under this share of its daytime energy: night
const LAG := 14.0  # 1/s: how fast the beam catches up with the head

## 0 off .. 1 on: eased on and off with the night, times the flicker.
var lit: float:
	get: return _on * flick
var flick := 1.0  # the flicker's share of the light; 1 steady
var _on := 0.0  # eased
var _steps: Array = []  # the flicker playing (flicker_steps); empty: none
var _flick_t := 0.0  # s into it
var _sun: DirectionalLight3D
var _day := 0.0
var _look_again := 0.0  # s till the next search for a sun: a scene with none (the checks) must not search the tree every frame
var _placed := false


func _init() -> void:
	light_color = Color(1.0, 0.88, 0.66)
	spot_range = 22.0
	spot_angle = 22.0
	spot_angle_attenuation = 0.35  # a hard edge
	spot_attenuation = 0.7  # reaches ~15 m before it fades
	light_projector = _pattern()
	shadow_enabled = true
	light_volumetric_fog_energy = 0.0
	light_energy = 0.0
	visible = false
	top_level = true


func _ready() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	if gs and gs.has_signal(&"lamp_flicker"):
		gs.lamp_flicker.connect(func(peer: int, seed: int) -> void:
			if peer == owner_peer():
				flicker(seed))


## Whose lamp this is: a remote body's (remote_players.gd Character.peer), else the local player's.
func owner_peer() -> int:
	var p := get_parent()
	if p and &"peer" in p:
		return p.peer
	return multiplayer.get_unique_id()


## Plays the flicker `seed` from its start (one already playing gives way).
func flicker(seed: int) -> void:
	_steps = flicker_steps(seed)
	_flick_t = 0.0


func flickering() -> bool:
	return not _steps.is_empty()


## At the eyes `eye`, the beam a little behind where they turn.
func follow(eye: Transform3D, delta: float) -> void:
	if not _placed:
		global_transform = eye
		_placed = true
		return
	var b := global_basis.orthonormalized().slerp(eye.basis.orthonormalized(), 1.0 - exp(-LAG * delta))
	global_transform = Transform3D(b, eye.origin)


func _process(delta: float) -> void:
	if _sun == null or not is_instance_valid(_sun):
		_look_again -= delta
		if _look_again <= 0.0:
			_look_again = 2.0
			_find_sun()
	var night := _sun != null and (not _sun.is_visible_in_tree() or _sun.light_energy < _day * DUSK)
	_on = move_toward(_on, 1.0 if night else 0.0, EASE * delta)
	if not _steps.is_empty():
		_flick_t += delta
		flick = flicker_level(_steps, _flick_t)
		if _flick_t >= flicker_length(_steps):
			_steps = []
			flick = 1.0
	light_energy = ENERGY * lit
	visible = _on > 0.0


func _find_sun() -> void:
	var world := get_tree().current_scene.get_node_or_null(^"World") if get_tree().current_scene else null
	if world == null:
		for n in get_tree().root.find_children("World", "Node3D", true, false):
			world = n
			break
	_sun = world.get_node_or_null(^"Sun") as DirectionalLight3D if world else null
	if _sun:
		_day = _sun.light_energy


## A flicker, the same on every machine from its seed: [s, level at its start, level at its end] one
## after the other, level 1 being the steady beam. A few quick drop-outs (a contact losing touch), and
## a moment dim, sagging and coming back (the battery); now one first, now the other. The numbers
## are mine (docs/ayrintilar.md "Kafa lambası titremesi").
static func flicker_steps(seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var cuts := []
	for i in r.randi_range(2, 4):
		var out := r.randf_range(0.0, 0.08)  # not always quite out
		cuts.append([r.randf_range(0.03, 0.07), out, out])
		cuts.append([r.randf_range(0.04, 0.12), 1.0, 1.0])
	var low := r.randf_range(0.3, 0.55)
	var lower := low * r.randf_range(0.8, 1.0)
	var sag := [[r.randf_range(0.04, 0.08), 1.0, low], [r.randf_range(0.15, 0.35), low, lower],
		[r.randf_range(0.25, 0.45), lower, 1.0]]
	return sag + cuts if r.randf() < 0.3 else cuts + sag


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


## The beam's pattern: a blotchy middle, a brighter ring near the edge, nothing past it. 64 px.
static func _pattern() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.09
	for y in 64:
		for x in 64:
			var r := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var v := 0.72 + 0.28 * (noise.get_noise_2d(x, y) * 0.5 + 0.5)
			v = maxf(v, smoothstep(0.78, 0.88, r) * (1.0 - smoothstep(0.9, 0.97, r)) * 1.0)
			v *= 1.0 - smoothstep(0.95, 1.0, r)
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)
