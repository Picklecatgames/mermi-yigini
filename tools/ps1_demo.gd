extends SceneTree
## A small PS1 horror test yard (2026-11-03, the user: "oyun pixelart oldu, ben lowpoly PS1 tarzı
## istemiştim"; try the reference look on a few zombies first). The rule taken from the references
## (The Soul, Puppet Combo-like shots): the texture's pixels are big, the screen's are not. So the
## 3D is drawn fine (480 lines or the full window), no dither, and the 128 px textures are stretched
## coarse over the surfaces (~64 texels a metre), unfiltered and unblurred. No vertex jitter: the
## user saw it as flicker.
## The night (the user: a stylised palette, scarier, gloomier, not overdone; the reference a figure
## against a navy, cloudy, starry sky): a dark cloud sky with a few stars, cold blue-grey moonlight,
## one dim, unsteady warm lamp, and a grade over the 3D (GRADE): colour drained but blood kept red,
## shadows pushed to a cold teal, lights a dirty amber, a soft vignette.
## The zombies are the game's own (scripts/zombie_body.gd), so the head comes apart as in the game.
##   Godot.exe --path . -s res://tools/ps1_demo.gd             walk around: WASD, mouse, Shift fast
##   ... -- --shot                                               user://ps1_demo_<n>.png, quits
## Keys: 1 the full window, 2 480 lines, 3 the old screen (270 lines, dithered) to compare;
## H blows the head of the zombie nearest the middle of the view, Q slow motion on and off,
## R stands them all up again. Esc quits.
## Silent Hill 2's air (2026-11-04, the user asked to try it): F steps through the yard's own night,
## a dark that swallows all but a torch, and a grey fog by day; G grain on and off. Three more of
## the dead stand out on the open side, behind the first view, to be lost in it.

const ZOMBIE_BODY := preload("res://scripts/zombie_body.gd")
const TEX := "res://assets/psx/tex/%s.res"
const SKY := "res://assets/env/hdri/kloofendal_48d_partly_cloudy_puresky_4k.hdr"
const ZOMBIES := ["prisoner", "copzombie", "zombiegirl"]
const TEXELS := 64.0  # texture pixels a metre: a 128 px texture covers 2 m
const FAR := [Vector3(-1.5, 0, 8.0), Vector3(1.8, 0, 12.0), Vector3(-0.5, 0, 17.0)]
const MODES := ["Tam ekran", "480p", "Eski 270p"]
const SLOW := 0.15  # time scale in slow motion
## F's airs: fog colour, density, ambient energy, moon energy, the lamp, the torch.
const AIRS := [
	{"name": "Gece", "fog": Color(0.03, 0.035, 0.05), "density": 0.07, "ambient": 0.3, "moon": 0.22, "sky": 0.15, "lamp": true, "torch": false, "grade": 1.0, "levels": 31.0},
	{"name": "Karanlık + fener", "fog": Color(0.006, 0.007, 0.009), "density": 0.13, "ambient": 0.1, "moon": 0.0, "sky": 1.0, "lamp": false, "torch": true, "grade": 0.6, "levels": 255.0},
	{"name": "Gri sis", "fog": Color(0.4, 0.42, 0.42), "density": 0.17, "ambient": 1.1, "moon": 0.0, "sky": 1.0, "lamp": false, "torch": false, "grade": 0.25, "levels": 255.0},
]
const GRAIN_AMOUNT := 0.07
const GRAIN := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount = 0.07;
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec3 p = fract(vec3(floor(FRAGCOORD.xy / 2.0), floor(TIME * 18.0)).xyx * 0.1031);  // 18 new grains a second
	p += dot(p, p.yzx + 33.33);
	float n = fract((p.x + p.y) * p.z) - 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(c + n * amount * mix(1.0, 0.45, l), 1.0);
}
"""
const GRADE := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float red = clamp((c.r - max(c.g, c.b)) * 3.0, 0.0, 1.0);  // blood
	c = mix(vec3(l), c, mix(0.45, 0.9, red));
	vec3 low = vec3(0.62, 0.84, 0.92);  // cold teal shadows
	vec3 high = vec3(1.1, 0.96, 0.8);  // dirty amber lights
	c *= mix(low, high, smoothstep(0.02, 0.4, l));
	c = pow(max(c, 0.0), vec3(1.12));
	float v = length((SCREEN_UV - 0.5) * vec2(1.1, 1.0));
	c *= mix(1.0, 0.5, smoothstep(0.35, 0.85, v));
	COLOR = vec4(c, 1.0);
}
"""
const NIGHT_SKY := """
shader_type sky;
uniform sampler2D pano : source_color, filter_linear;
void sky() {
	vec3 d = EYEDIR;
	vec2 uv = vec2(atan(d.x, -d.z) / (2.0 * PI) + 0.5, acos(clamp(d.y, -1.0, 1.0)) / PI);
	float cloud = dot(texture(pano, uv).rgb, vec3(0.3, 0.59, 0.11));
	cloud = smoothstep(0.55, 1.4, cloud);
	vec3 col = mix(vec3(0.012, 0.017, 0.035), vec3(0.04, 0.047, 0.065), cloud);
	vec3 cell = floor(d * 260.0);
	float h = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	col += vec3(step(0.9975, h) * (1.0 - cloud) * smoothstep(0.08, 0.35, d.y) * 0.5);
	col = mix(col, vec3(0.07, 0.05, 0.055), (1.0 - smoothstep(0.0, 0.22, d.y)) * 0.7);  // dusty horizon
	COLOR = d.y < 0.0 ? vec3(0.01) : col;
}
"""

var _label := Label.new()
var _cam: FlyCam
var _world := Node3D.new()
var _zombies: Array[Node3D] = []
var _mode_now := 1
var _grade := ColorRect.new()  # the screen's own grade (psx_screen.gdshaderinc) where the PS1 screen is off
var _grain := ColorRect.new()
var _env: Environment
var _flicker: OmniLight3D
var _moon: DirectionalLight3D
var _torch: Torch
var _air_now := 0


func _initialize() -> void:
	root.add_child(_world)
	_environment()
	_ground()
	_walls()
	_lamp()
	_stand_up()
	_cam = FlyCam.new()
	_cam.fov = 70.0
	_world.add_child(_cam)
	_cam.look_at_from_position(Vector3(0.3, 1.65, 3.2), Vector3(0, 1.3, -1.5))
	_cam.sync_angles()
	var grade := CanvasLayer.new()
	grade.layer = 0  # over the PS1 screen (-1), under the label
	root.add_child(grade)
	var rect := _grade
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = Shader.new()
	gm.shader.code = GRADE
	rect.material = gm
	grade.add_child(rect)
	var grain := CanvasLayer.new()
	grain.layer = 1  # over the grade, under the label
	root.add_child(grain)
	_grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gr := ShaderMaterial.new()
	gr.shader = Shader.new()
	gr.shader.code = GRAIN
	gr.set_shader_parameter(&"amount", GRAIN_AMOUNT)
	_grain.material = gr
	_grain.visible = false
	grain.add_child(_grain)
	_torch = Torch.new()
	_torch.eye = _cam
	_torch.visible = false
	_world.add_child(_torch)
	var ui := CanvasLayer.new()
	ui.layer = 10
	root.add_child(ui)
	_label.position = Vector2(16, 12)
	_label.modulate = Color(1, 1, 1, 0.6)
	ui.add_child(_label)
	_run.call_deferred()


func _run() -> void:
	for i in 3:
		await process_frame  # Settings puts its own PS1 screen on first
	_mode(1)
	if "--sh2" in OS.get_cmdline_user_args():
		_grain.visible = true
		for a in [1, 2]:
			_air(a)
			for dir: Vector3 in [Vector3(0, 1.3, -1.5), Vector3(0.3, 1.3, 12.0)]:
				_cam.look_at_from_position(Vector3(0.3, 1.65, 3.2), dir)
				for i in 90:
					await process_frame
				_save(10 * a + int(dir.z > 0.0))
		quit()
		return
	if "--shot" in OS.get_cmdline_user_args():
		for i in 20:
			await process_frame
		_save(0)
		_pop()
		for i in 6:
			await process_frame
		_save(1)
		quit()
		return
	_cam.on_key = func(k: Key) -> void:
		if k >= KEY_1 and k <= KEY_3:
			_mode(k - KEY_1)
		elif k == KEY_H:
			_pop()
		elif k == KEY_Q:
			Engine.time_scale = SLOW if Engine.time_scale == 1.0 else 1.0
			_mode(_mode_now)
		elif k == KEY_R:
			_stand_up()
		elif k == KEY_F:
			_air((_air_now + 1) % AIRS.size())
		elif k == KEY_G:
			_grain.visible = not _grain.visible
			_mode(_mode_now)


func _air(a: int) -> void:
	_air_now = a
	var air: Dictionary = AIRS[a]
	_env.fog_light_color = air.fog
	_env.fog_density = air.density
	_env.fog_sky_affect = air.sky
	_env.ambient_light_energy = air.ambient
	_moon.light_energy = air.moon
	_moon.visible = air.moon > 0.0
	_flicker.visible = air.lamp
	_torch.visible = air.torch
	_mode(_mode_now)
	_screen_air()


## The air's own grade and colour steps on the PS1 screen, which apply() may have just made anew.
func _screen_air() -> void:
	var rect: ColorRect = root.get_node("PsxScreen")._rect
	rect.material.set_shader_parameter(&"psx_grade", AIRS[_air_now].grade)
	rect.material.set_shader_parameter(&"psx_levels", AIRS[_air_now].levels)


func _save(n: int) -> void:
	var file := "user://ps1_demo_%d.png" % n
	root.get_viewport().get_texture().get_image().save_png(file)
	print(ProjectSettings.globalize_path(file))


func _mode(m: int) -> void:
	_mode_now = m
	var psx: Node = root.get_node("PsxScreen")
	psx.apply([0, 480, 270][m], m == 1)  # 480: drawn twice as fine and averaged, edges stop crawling
	psx._rect.material.set_shader_parameter(&"psx_dither", 0.5 if m == 2 else 0.0)
	_grade.visible = m == 0
	var vp := root.get_viewport()
	vp.texture_mipmap_bias = 1.5 if m == 2 else 0.0  # the old screen softened every texture
	if m == 0:
		vp.scaling_3d_scale = 1.0
		vp.msaa_3d = Viewport.MSAA_DISABLED
	_screen_air()
	_label.text = "1 Tam ekran   2 480p   3 Eski 270p   H Kafa   Q Yavaş çekim   R Yeniden   F Hava   G Gren      %s   %s%s%s" % [
			MODES[m], AIRS[_air_now].name, "   GREN" if _grain.visible else "", "   YAVAŞ" if Engine.time_scale < 1.0 else ""]


## The zombie nearest the middle of the view loses its head.
func _pop() -> void:
	var best: Node3D = null
	var near := -2.0
	var ahead := -_cam.global_basis.z
	for z in _zombies:
		var body: Node3D = z.get_child(0)
		if body._dead:
			continue
		var to := (z.global_position + Vector3.UP * 1.5 - _cam.global_position).normalized()
		if ahead.dot(to) > near:
			near = ahead.dot(to)
			best = z
	if best:
		var dir := best.global_position + Vector3.UP * 1.5 - _cam.global_position
		best.get_child(0).die(&"head", false, randi(), dir.normalized())


func _stand_up() -> void:
	for z in _zombies:
		z.queue_free()
	_zombies.clear()
	for c in _world.get_children():  # the last ones' gibs and hats
		if c is RigidBody3D or (c is MeshInstance3D and c.has_meta(&"gib")):
			c.queue_free()
	for i in ZOMBIES.size():
		var holder := Node3D.new()
		holder.position = Vector3(-1.6 + i * 1.6, 0, -1.5 - absf(i - 1) * 0.6)
		holder.rotation.y = PI + (i - 1) * 0.35  # the body faces -Z: turned round to the camera
		var body: Node3D = ZOMBIE_BODY.new()
		body.setup(&"walker", 11 + i)
		body.model = StringName(ZOMBIES[i])
		holder.add_child(body)
		_world.add_child(holder)
		_zombies.append(holder)
		_unjitter.call_deferred(body)
	for i in FAR.size():  # out on the open side, facing the yard
		var holder := Node3D.new()
		holder.position = FAR[i]
		var body: Node3D = ZOMBIE_BODY.new()
		body.setup(&"walker", 21 + i)
		body.model = StringName(ZOMBIES[i % ZOMBIES.size()])
		holder.add_child(body)
		_world.add_child(holder)
		_zombies.append(holder)
		_unjitter.call_deferred(body)


func _unjitter(body: Node3D) -> void:
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat is ShaderMaterial:
				mat = mat.duplicate()
				mat.set_shader_parameter(&"snap", 0.0)
				mi.set_surface_override_material(s, mat)


func _psx(tex: String, uv: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://materials/psx.gdshader")
	m.set_shader_parameter(&"albedo_tex", load(TEX % tex))
	m.set_shader_parameter(&"uv_scale", uv)
	m.set_shader_parameter(&"snap", 0.0)  # no vertex jitter: it bent the edges and the user saw it as flicker
	m.set_shader_parameter(&"mip_bias", -0.5)  # with the 2x2 pass (+1) a half mip softer: no boiling far off
	return m


func _environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = Shader.new()
	sky_mat.shader.code = NIGHT_SKY
	sky_mat.set_shader_parameter(&"pano", load(SKY))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.24, 0.32)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.035, 0.05)
	env.fog_density = 0.07
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)


## A static body under `mi`, so blood finds it (blood_fx.gd WALL_MASK).
func _solid(mi: MeshInstance3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	mi.add_child(body)


func _ground() -> void:
	var size := 60.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 90  # the lamp lights vertices: they need to be near it
	plane.subdivide_depth = 90
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = _psx("gravelly_sand", Vector2.ONE * size * TEXELS / 128.0)
	_world.add_child(mi)
	_solid(mi, Vector3(size, 0.02, size))
	var slab := PlaneMesh.new()  # a concrete pad under the lamp
	slab.size = Vector2(5, 4)
	slab.subdivide_width = 10
	slab.subdivide_depth = 8
	var pad := MeshInstance3D.new()
	pad.mesh = slab
	pad.position = Vector3(0, 0.01, -1.6)
	pad.material_override = _psx("dirty_concrete", Vector2(5, 4) * TEXELS / 128.0)
	_world.add_child(pad)


## A wall of `w` x `h` metres, its face toward +Z before `rot`.
func _wall(tex: String, w: float, h: float, at: Vector3, rot: float) -> void:
	var p := PlaneMesh.new()
	p.orientation = PlaneMesh.FACE_Z
	p.size = Vector2(w, h)
	p.subdivide_width = int(w * 2)
	p.subdivide_depth = int(h * 2)
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.position = at + Vector3(0, h * 0.5, 0)
	mi.rotation.y = rot
	mi.material_override = _psx(tex, Vector2(w, h) * TEXELS / 128.0)
	_world.add_child(mi)
	_solid(mi, Vector3(w, h, 0.1))


func _walls() -> void:
	_wall("concrete_slab_wall", 8.0, 3.0, Vector3(0, 0, -4.5), 0.0)
	_wall("rust_coarse_01", 6.0, 2.6, Vector3(-4.0, 0, -1.5), PI * 0.5)
	_wall("metal_plate_02", 6.0, 2.6, Vector3(4.0, 0, -1.5), -PI * 0.5)


func _lamp() -> void:
	var lamp := Flicker.new()
	lamp.position = Vector3(0.4, 2.6, -1.2)
	lamp.light_color = Color(1.0, 0.58, 0.3)
	lamp.omni_range = 8.0
	lamp.omni_attenuation = 1.6
	lamp.shadow_enabled = true
	_world.add_child(lamp)
	_flicker = lamp
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, 40, 0)
	moon.light_color = Color(0.5, 0.6, 0.8)
	moon.light_energy = 0.22
	_world.add_child(moon)
	_moon = moon


## A work lamp on a tired line: mostly steady, now and then it sags and catches again.
class Flicker extends OmniLight3D:
	const BASE := 2.0
	var _t := 0.0
	var _dip := 0.0

	func _process(dt: float) -> void:
		_t += dt
		if randf() < dt * 0.4:
			_dip = randf_range(0.3, 0.7)
		_dip = move_toward(_dip, 0.0, dt * 2.5)
		light_energy = BASE * (1.0 - _dip) * (0.96 + 0.04 * sin(_t * 23.0))


## A torch in the hand: it follows the eye a moment late, so its shadows swing as the view turns.
class Torch extends SpotLight3D:
	const LAG := 9.0
	var eye: Camera3D

	func _ready() -> void:
		light_color = Color(1.0, 0.93, 0.78)
		light_energy = 10.0
		spot_range = 18.0
		spot_angle = 24.0
		spot_attenuation = 0.8
		spot_angle_attenuation = 1.6
		shadow_enabled = true

	func _process(dt: float) -> void:
		if not eye.is_inside_tree():
			return
		global_position = eye.global_transform * Vector3(0.22, -0.22, 0.0)
		var k := 1.0 - exp(-LAG * dt / Engine.time_scale)
		global_basis = global_basis.orthonormalized().slerp(eye.global_basis.orthonormalized(), k)


class FlyCam extends Camera3D:
	var on_key: Callable
	var _yaw := 0.0
	var _pitch := 0.0

	func _ready() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	func sync_angles() -> void:
		_yaw = rotation.y
		_pitch = rotation.x

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= e.relative.x * 0.003
			_pitch = clampf(_pitch - e.relative.y * 0.003, -1.4, 1.4)
			rotation = Vector3(_pitch, _yaw, 0)
		elif e is InputEventKey and e.pressed and not e.echo:
			if e.keycode == KEY_ESCAPE:
				get_tree().quit()
			elif on_key.is_valid():
				on_key.call(e.keycode)

	func _process(dt: float) -> void:
		var d := Vector3(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), 0,
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		var speed := 6.0 if Input.is_key_pressed(KEY_SHIFT) else 2.0
		position += basis * d.normalized() * speed * dt / Engine.time_scale  # slow motion slows the world, not the walk
