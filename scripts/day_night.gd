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
## shapes, colours gone. Each night has its own moon (GameState.moon, the host's pick at dusk; the
## user: "dolunay kızıl ay farklı ay çeşitleri, hatta boss günlerinde gece iyice garipleşsin, birkaç
## ay olsun yukarıda"): MOONS gives each its discs, its light, and the night's ambient and haze, so
## under the blood moon the whole night goes a dull rust, and a boss night has three moons, a murky
## haze and moonlight that wavers. The numbers are first guesses.
##
## N (debug builds) runs the clock on to the next night or morning in GameState.SKIP_TIME, every
## machine seeing it go. Check: tools/day_night_check.gd.

const SUN_SET := -4.0  # deg, the sun's pitch once it is under the horizon
const SUN_WARM := Color(1.0, 0.55, 0.3)  # its colour low in the sky
const SKY_NIGHT := 0.04  # of the sky's brightness left
const FOG_THICK := 1.5  # an exponential haze's density, times, at night
const REFLECT_OFF := 0.9  # darkness past which the sky's reflections go off
const MOON_FROM := [0.5, 0.85]  # darkness over which the moon rises in, after the sun is out
const MOON_FAR := 300.0  # m off the eye, the discs
const MOON_SIZE := 0.08  # of MOON_FAR across at size 1: ~4.5 deg, a big moon
const MOON_PX := 48  # a face's pixels across
## Per moon (GameState.MOONS, and "boss"): its discs [yaw, pitch (deg), size, tint, phase (1 full),
## and what else its shader takes (materials/moon.gdshader: limb, halo, halo_color, eclipse)], the
## first one the light's; the light's colour and energy; the night's ambient colour and energy (of
## the day's); its haze, which is also the sky's colour at night (moonlit haze: what stands in front
## of it reads dark against it); how much the light wavers (0 steady). The blood moon and the boss
## night (2026-11-03, the user, of the first ones: "kızılay yeşilay kötü olmuş, daha oturaklı
## korkutucu gergin bir cinsten yap"): no bright colours. The blood moon is an eclipsed one, dark
## copper and dim, the night a dull rust; the boss night a huge dim copper moon, a small bone-white
## one and a black eclipse with a burning rim over a murky brown haze, the light wavering.
const MOONS := {
	"full": {"discs": [[75.0, 34.0, 1.0, Color(0.85, 0.9, 1.0), 1.0, {"halo": 0.18, "halo_color": Color(0.5, 0.56, 0.68)}]],
		"light": Color(0.62, 0.72, 0.92), "energy": 0.6,
		"ambient": Color(0.4, 0.48, 0.66), "ambient_energy": 0.3, "fog": Color(0.085, 0.1, 0.13), "waver": 0.0},
	"pale": {"discs": [[70.0, 24.0, 0.8, Color(0.72, 0.74, 0.76), 1.0, {"halo": 0.25, "halo_color": Color(0.4, 0.42, 0.44)}]],
		"light": Color(0.6, 0.63, 0.68), "energy": 0.35,
		"ambient": Color(0.38, 0.4, 0.45), "ambient_energy": 0.24, "fog": Color(0.075, 0.078, 0.085), "waver": 0.0},
	"crescent": {"discs": [[80.0, 40.0, 1.0, Color(0.9, 0.9, 0.85), 0.22, {}]], "light": Color(0.55, 0.62, 0.8), "energy": 0.18,
		"ambient": Color(0.35, 0.4, 0.56), "ambient_energy": 0.2, "fog": Color(0.045, 0.052, 0.07), "waver": 0.0},
	"blood": {"discs": [[75.0, 22.0, 1.6, Color(0.52, 0.17, 0.1), 1.0, {"limb": 0.4, "halo": 0.22, "halo_color": Color(0.3, 0.09, 0.05)}]],
		"light": Color(0.62, 0.3, 0.22), "energy": 0.45,
		"ambient": Color(0.42, 0.27, 0.24), "ambient_energy": 0.24, "fog": Color(0.07, 0.035, 0.03), "waver": 0.0},
	"boss": {"discs": [[75.0, 18.0, 2.5, Color(0.45, 0.16, 0.1), 1.0, {"limb": 0.4, "halo": 0.3, "halo_color": Color(0.25, 0.08, 0.05)}],
			[44.0, 36.0, 0.55, Color(0.78, 0.74, 0.64), 0.62, {"limb": 0.5}],
			[112.0, 16.0, 0.8, Color(0.85, 0.42, 0.2), 1.0, {"eclipse": 1.0, "halo": 0.16, "halo_color": Color(0.35, 0.14, 0.06)}]],
		"light": Color(0.6, 0.48, 0.4), "energy": 0.45,
		"ambient": Color(0.38, 0.3, 0.3), "ambient_energy": 0.32, "fog": Color(0.055, 0.045, 0.038), "waver": 0.45},
}
const WAVER_SPEED := 1.7  # how fast a wavering moon's light comes and goes

var _env: Environment
var _sun: DirectionalLight3D
var _day := {}  # what the scene was built with
var _dark := -1.0  # what was last shown
var _kind := ""  # the moon shown
var _moon: DirectionalLight3D
var _world: Node
var _discs: Array[MeshInstance3D] = []
var _face: ImageTexture
var _up := 0.0  # how far the moon has risen in
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # paused, the sky still matches the clock


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:  # N: gece (2026-11-03, the user: not an F key)
		GameState.request_skip_time()
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:  # B: gece ve dalga
		GameState.request_debug_raid()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_instance_valid(_env) or not is_instance_valid(_sun):
		if not _find():
			return
	if GameState.moon != _kind:
		_set_moon(GameState.moon)
	var dark: float = GameState.night_of(GameState.hour)
	if dark != _dark:  # exactly: a last few ten-thousandths of dusk must still give way to the day as built
		_dark = dark
		show_dark(dark)
	var m: Dictionary = MOONS[_kind]
	_t += delta
	if m.waver > 0.0 and _up > 0.0:  # two slow waves against each other: never a beat
		var w := 0.5 + 0.25 * sin(_t * WAVER_SPEED) + 0.25 * sin(_t * WAVER_SPEED * 2.37 + 1.3)
		_moon.light_energy = m.energy * _up * (1.0 - m.waver * w)
	var eye := get_viewport().get_camera_3d()
	if eye and _up > 0.0:  # far off along each moon's way, wherever the eye goes
		for i in _discs.size():
			var d: Array = m.discs[i]
			_discs[i].global_position = eye.global_position + _toward(d[0], d[1]) * MOON_FAR


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
	_world = sun.get_parent()
	_day = {"pitch": sun.rotation_degrees.x, "color": sun.light_color, "energy": sun.light_energy,
		"sky": _env.background_energy_multiplier, "ambient": _env.ambient_light_energy,
		"sky_light": _env.ambient_light_sky_contribution, "ambient_color": _env.ambient_light_color,
		"fog": _env.fog_light_color, "density": _env.fog_density, "fog_sky": _env.fog_sky_affect,
		"aerial": _env.fog_aerial_perspective,
		"vol_albedo": _env.volumetric_fog_albedo, "reflect": _env.reflected_light_source}
	_add_moon()
	_set_moon(GameState.moon)
	return true


## The world at darkness `dark` (0 day, 1 night). The sun sinks where it stands and comes up there
## again (turning it would swing every shadow across the yard).
func show_dark(dark: float) -> void:
	var m: Dictionary = MOONS[_kind]
	# The sun: down to the horizon over the first half, warming; out under it.
	var low := minf(1.0, dark * 2.0)
	_sun.rotation_degrees.x = lerpf(_day.pitch, SUN_SET, low)
	_sun.light_color = (_day.color as Color).lerp(SUN_WARM, sin(low * PI * 0.5) * (1.0 - smoothstep(0.6, 1.0, low) * 0.3))
	_sun.light_energy = _day.energy * (1.0 - smoothstep(0.35, 0.55, dark))
	_sun.visible = _sun.light_energy > 0.001
	# The sky and what it lights, towards tonight's.
	var k := smoothstep(0.0, 1.0, dark)
	_env.background_energy_multiplier = lerpf(_day.sky, _day.sky * SKY_NIGHT, k)
	_env.ambient_light_energy = lerpf(_day.ambient, _day.ambient * m.ambient_energy, k)
	_env.ambient_light_sky_contribution = lerpf(_day.sky_light, 0.0, k)
	_env.ambient_light_color = (_day.ambient_color as Color).lerp(m.ambient, k)
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if dark > REFLECT_OFF else _day.reflect
	_env.fog_light_color = (_day.fog as Color).lerp(m.fog, k)
	if _env.fog_mode == Environment.FOG_MODE_EXPONENTIAL:  # a depth haze has its own reach
		_env.fog_density = lerpf(_day.density, _day.density * FOG_THICK, k)
	_env.fog_sky_affect = lerpf(_day.fog_sky, 1.0, k)
	_env.fog_aerial_perspective = lerpf(_day.aerial, 0.0, k)  # it takes the sky's own (daylit) light: a pale band at the horizon
	_env.volumetric_fog_albedo = (_day.vol_albedo as Color).lerp(Color(0.05, 0.05, 0.06), k)
	# The moon, once the sun is out.
	_up = smoothstep(MOON_FROM[0], MOON_FROM[1], dark)
	_moon.light_energy = m.energy * _up
	_moon.visible = _moon.light_energy > 0.001
	for d in _discs:
		(d.material_override as ShaderMaterial).set_shader_parameter(&"fade", _up)
		d.visible = _up > 0.0


## Tonight's moon is `kind`: its discs and its light's colour and way; the rest follows at show_dark.
func _set_moon(kind: String) -> void:
	_kind = kind if MOONS.has(kind) else "full"
	var m: Dictionary = MOONS[_kind]
	for d in _discs:
		d.queue_free()
	_discs.clear()
	for spec: Array in m.discs:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://materials/moon.gdshader")
		mat.set_shader_parameter(&"face", _face)
		mat.set_shader_parameter(&"tint", spec[3])
		mat.set_shader_parameter(&"phase", spec[4])
		for k: String in spec[5]:
			mat.set_shader_parameter(StringName(k), spec[5][k])
		var disc := MeshInstance3D.new()
		disc.name = "MoonDisc"
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * MOON_FAR * MOON_SIZE * spec[2] / 0.55  # the disc fills 0.55 of it (moon.gdshader DISC)
		disc.mesh = quad
		disc.material_override = mat
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.extra_cull_margin = 16384.0  # it moves with the eye; never culled by a stale box
		disc.visible = false
		_world.add_child(disc)
		_discs.append(disc)
	var first: Array = m.discs[0]
	_moon.basis = Basis.looking_at(-_toward(first[0], first[1]))  # it shines from there
	_moon.light_color = m.light
	_dark = -1.0


## The way to a moon `yaw` deg round (0 is +z, 90 is +x) and `pitch` deg over the horizon.
static func _toward(yaw: float, pitch: float) -> Vector3:
	return Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0.0)).z


## The moon's light beside the sun, and the one face every disc wears, drawn here once MOON_PX
## across: grey with darker seas and a few craters, from a fixed seed, the same on every machine.
func _add_moon() -> void:
	if is_instance_valid(_moon):
		_moon.queue_free()
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.light_energy = 0.0
	_moon.shadow_enabled = true
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_moon.directional_shadow_max_distance = 60.0
	_moon.light_angular_distance = 0.0  # hard edged, as the PS1 screen wants them
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_moon.visible = false
	_world.add_child(_moon)
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
	_face = ImageTexture.create_from_image(img)
