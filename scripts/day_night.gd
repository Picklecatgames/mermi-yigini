extends Node
## Day and night (docs/ayrintilar.md "Yeni yön: açık alan", the user: "Gece gündüz döngüsü
## olacak"): shows GameState's clock on the world as it runs. Net.gd adds it; it finds the scene's
## WorldEnvironment and its Sun and takes what they were built with (tools/build_world.gd _sky())
## as the day, so whatever the sky is rebuilt with, the day stays that. Towards night the sun goes
## down, warming as it nears the horizon, and out; the sky and the light it gives go nearly black,
## what is left is a cold dim blue, and the haze darkens and thickens (the night of
## tools/psx_shots.gd, a little less black: shapes read in the open). The workshop's lamps and the
## barrel fire light it. The numbers are first guesses.
##
## N (debug builds) runs the clock on to the next night or morning in GameState.SKIP_TIME, every
## machine seeing it go. Check: tools/day_night_check.gd.

const SUN_SET := -4.0  # deg, the sun's pitch once it is under the horizon
const SUN_WARM := Color(1.0, 0.55, 0.3)  # its colour low in the sky
const SKY_NIGHT := 0.04  # of the sky's brightness left
const AMBIENT_NIGHT := 0.18  # of the ambient light's energy left: shapes still read in the open, colours gone
const AMBIENT_BLUE := Color(0.35, 0.42, 0.6)
const FOG_NIGHT := Color(0.02, 0.025, 0.035)
const FOG_THICK := 2.5  # the haze's density, times, at night
const REFLECT_OFF := 0.9  # darkness past which the sky's reflections go off

var _env: Environment
var _sun: DirectionalLight3D
var _day := {}  # what the scene was built with
var _dark := -1.0  # what was last shown


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
	if is_equal_approx(dark, _dark):
		return
	_dark = dark
	show_dark(dark)


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
	_env.fog_density = lerpf(_day.density, _day.density * FOG_THICK, k)
	_env.fog_sky_affect = lerpf(_day.fog_sky, 1.0, k)
	_env.fog_aerial_perspective = lerpf(_day.aerial, 0.0, k)  # it takes the sky's own (daylit) light: a pale band at the horizon
	_env.volumetric_fog_albedo = (_day.vol_albedo as Color).lerp(Color(0.05, 0.05, 0.06), k)
