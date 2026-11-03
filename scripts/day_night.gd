extends Node
## Day and night (docs/ayrintilar.md "Yeni yön: açık alan", the user: "Gece gündüz döngüsü
## olacak"): shows GameState's clock on the world as it runs. Net.gd adds it; it finds the scene's
## WorldEnvironment and its Sun and takes what they were built with (tools/build_world.gd _sky())
## as the day, so whatever the sky is rebuilt with, the day stays that. Towards night the sun goes
## down, warming as it nears the horizon, and out; the sky and the light it gives go nearly black,
## what is left is a cold dim blue, and the haze darkens. Then the moon (2026-11-03, the user: "gece
## çok karanlık oluyor, dolunay falan ekle; çevre ve zombiler görünebilsin"): a low-res disc over the
## desert (materials/moon.gdshader) and a cold light of its own with hard shadows, the "Moon" beside
## the Sun, so the sun still goes out (scripts/head_lamp.gd lights when it does). By its light and
## the blue-grey haze the workshop, the railing, the heap's outline and the dead read at 20-30 m as
## shapes, colours gone. Every night has it for now; `phase` is how full it is (docs/ayrintilar.md
## "Gökyüzü çeşitleri": the full moon was to be a rare sky). The numbers are first guesses.
##
## N (debug builds) runs the clock on to the next night or morning in GameState.SKIP_TIME, every
## machine seeing it go. Check: tools/day_night_check.gd.

const SUN_SET := -4.0  # deg, the sun's pitch once it is under the horizon
const SUN_WARM := Color(1.0, 0.55, 0.3)  # its colour low in the sky
const SKY_NIGHT := 0.04  # of the sky's brightness left
const AMBIENT_NIGHT := 0.3  # of the ambient light's energy left
const AMBIENT_BLUE := Color(0.4, 0.48, 0.66)
const FOG_NIGHT := Color(0.085, 0.1, 0.13)  # moonlit haze: what stands in front of it reads dark against it
const FOG_THICK := 1.5  # an exponential haze's density, times, at night
const REFLECT_OFF := 0.9  # darkness past which the sky's reflections go off
const MOON_ANGLE := Vector3(-34.0, 75.0, 0.0)  # deg: low over the desert, away from the heap
const MOON_COLOR := Color(0.62, 0.72, 0.92)
const MOON_LIGHT := 0.6  # energy, full
const MOON_FROM := [0.5, 0.85]  # darkness over which it rises in, after the sun is out
const MOON_FAR := 300.0  # m off the eye, the disc
const MOON_SIZE := 0.08  # of MOON_FAR across: ~4.5 deg, a big moon
const MOON_PX := 48  # its face's pixels across

## How full the moon is: 1 full (every night for now), 0.5 half, 0 none.
var phase := 1.0:
	set(v):
		phase = clampf(v, 0.0, 1.0)
		_dark = -1.0

var _env: Environment
var _sun: DirectionalLight3D
var _day := {}  # what the scene was built with
var _dark := -1.0  # what was last shown
var _moon: DirectionalLight3D
var _disc: MeshInstance3D
var _disc_mat: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # paused, the sky still matches the clock


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:  # N: gece (2026-11-03, the user: not an F key)
		GameState.request_skip_time()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_instance_valid(_env) or not is_instance_valid(_sun):
		if not _find():
			return
	var dark: float = GameState.night_of(GameState.hour)
	if not is_equal_approx(dark, _dark):
		_dark = dark
		show_dark(dark)
	var eye := get_viewport().get_camera_3d()
	if _disc.visible and eye:  # far off along the moon's way, wherever the eye goes
		_disc.global_position = eye.global_position + _moon.global_basis.z * MOON_FAR


## The scene's sky and sun, and what they were built with; false while there are none (a menu).
func _find() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:  # a tool's -s script puts the game under the root itself
		scene = get_tree().root
	var we := scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	var sun := scene.find_child("Sun", true, false) as DirectionalLight3D
	if we == null or we.environment == null or sun == null:
		return false
	_env = we.environment
	_sun = sun
	_add_moon(sun.get_parent())
	_day = {"pitch": sun.rotation_degrees.x, "color": sun.light_color, "energy": sun.light_energy,
		"sky": _env.background_energy_multiplier, "ambient": _env.ambient_light_energy,
		"sky_light": _env.ambient_light_sky_contribution, "ambient_color": _env.ambient_light_color,
		"fog": _env.fog_light_color, "density": _env.fog_density, "fog_sky": _env.fog_sky_affect,
		"aerial": _env.fog_aerial_perspective,
		"vol_albedo": _env.volumetric_fog_albedo, "reflect": _env.reflected_light_source}
	_dark = -1.0
	return true


## The world at darkness `dark` (0 day, 1 night). The sun sinks where it stands and comes up there
## again (turning it would swing every shadow across the yard).
func show_dark(dark: float) -> void:
	# The sun: down to the horizon over the first half, warming; out under it.
	var low := minf(1.0, dark * 2.0)
	_sun.rotation_degrees.x = lerpf(_day.pitch, SUN_SET, low)
	_sun.light_color = (_day.color as Color).lerp(SUN_WARM, sin(low * PI * 0.5) * (1.0 - smoothstep(0.6, 1.0, low) * 0.3))
	_sun.light_energy = _day.energy * (1.0 - smoothstep(0.35, 0.55, dark))
	_sun.visible = _sun.light_energy > 0.001
	# The sky and what it lights.
	var k := smoothstep(0.0, 1.0, dark)
	_env.background_energy_multiplier = lerpf(_day.sky, _day.sky * SKY_NIGHT, k)
	_env.ambient_light_energy = lerpf(_day.ambient, _day.ambient * AMBIENT_NIGHT, k)
	_env.ambient_light_sky_contribution = lerpf(_day.sky_light, 0.0, k)
	_env.ambient_light_color = (_day.ambient_color as Color).lerp(AMBIENT_BLUE, k)
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if dark > REFLECT_OFF else _day.reflect
	_env.fog_light_color = (_day.fog as Color).lerp(FOG_NIGHT, k)
	if _env.fog_mode == Environment.FOG_MODE_EXPONENTIAL:  # a depth haze has its own reach
		_env.fog_density = lerpf(_day.density, _day.density * FOG_THICK, k)
	_env.fog_sky_affect = lerpf(_day.fog_sky, 1.0, k)
	_env.fog_aerial_perspective = lerpf(_day.aerial, 0.0, k)  # it takes the sky's own (daylit) light: a pale band at the horizon
	_env.volumetric_fog_albedo = (_day.vol_albedo as Color).lerp(Color(0.05, 0.05, 0.06), k)
	# The moon, once the sun is out.
	var up := smoothstep(MOON_FROM[0], MOON_FROM[1], dark)
	_moon.light_energy = MOON_LIGHT * up * phase
	_moon.visible = _moon.light_energy > 0.001
	_disc_mat.set_shader_parameter(&"fade", up)
	_disc_mat.set_shader_parameter(&"phase", phase)
	_disc.visible = up > 0.0 and phase > 0.0


## The moon's light and disc, beside the sun. Its face is drawn here once, MOON_PX across: grey with
## darker seas and a few craters, from a fixed seed, so it is the same moon every night everywhere.
func _add_moon(world: Node) -> void:
	if is_instance_valid(_moon):
		_moon.queue_free()
		_disc.queue_free()
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.rotation_degrees = MOON_ANGLE
	_moon.light_color = MOON_COLOR
	_moon.light_energy = 0.0
	_moon.shadow_enabled = true
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_moon.directional_shadow_max_distance = 60.0
	_moon.light_angular_distance = 0.0  # hard edged, as the PS1 screen wants them
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_moon.visible = false
	world.add_child(_moon)
	var img := Image.create(MOON_PX, MOON_PX, false, Image.FORMAT_RGB8)
	var seas := FastNoiseLite.new()
	seas.seed = 7
	seas.frequency = 0.06
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var craters := []
	for i in 9:
		craters.append(Vector3(rng.randf_range(4, MOON_PX - 4), rng.randf_range(4, MOON_PX - 4), rng.randf_range(1.0, 3.5)))
	for y in MOON_PX:
		for x in MOON_PX:
			var v := 0.82 - maxf(0.0, seas.get_noise_2d(x, y)) * 0.55
			for c: Vector3 in craters:
				var d := Vector2(x - c.x, y - c.y).length()
				if d < c.z:
					v *= 0.78
				elif d < c.z + 1.0:
					v *= 1.08  # its lit rim
			img.set_pixel(x, y, Color(v, v, v * 1.02))
	_disc_mat = ShaderMaterial.new()
	_disc_mat.shader = preload("res://materials/moon.gdshader")
	_disc_mat.set_shader_parameter(&"face", ImageTexture.create_from_image(img))
	_disc = MeshInstance3D.new()
	_disc.name = "MoonDisc"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * MOON_FAR * MOON_SIZE
	_disc.mesh = quad
	_disc.material_override = _disc_mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.extra_cull_margin = 16384.0  # it moves with the eye; never culled by a stale box
	_disc.visible = false
	world.add_child(_disc)
