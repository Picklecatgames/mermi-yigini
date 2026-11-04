extends SceneTree
## The game's zombies in another look, to compare (2026-11-04, the user sent a shot: a low-poly figure
## close up, bright flat light, strong colours, fine dotted screen, colours slipping apart at the
## edges, and above all textures that look painted by hand). So every texture is repainted when it
## first shows: flat strokes (PAINT, a Kuwahara filter), then dark lines where the strokes meet and
## stronger colour (INK). A small lit room: nearly no shadow, so the texture is what you read. The
## screen: 480 lines, single pass, 15-bit colour with the ordered dither on, red and blue a little
## apart (LOOK).
##   Godot.exe --path . -s res://tools/painted_demo.gd     WASD, mouse, Shift fast
##   ... -- --shot                                           user://painted_demo_<n>.png, quits
## Keys: G the look on and off, H the head of the zombie nearest the view's middle, R up again. Esc quits.

const DEMO := preload("res://tools/ps1_demo.gd")
const ZOMBIE_BODY := preload("res://scripts/zombie_body.gd")
const TEX := "res://assets/psx/tex/%s.res"
const ZOMBIES := ["zombiegirl", "copzombie", "prisoner"]
const TEXELS := 64.0  # texture pixels a metre, as in tools/ps1_demo.gd
const DITHER := 0.55
const PAINTED := 512  # px, each texture repainted this big: strokes finer than the 128-256 px source
const PAINT := """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D src : filter_linear, repeat_enable;
const int R = 4;  // the stroke, in painted pixels
void fragment() {
	vec2 px = vec2(1.0 / 512.0);
	vec3 best = vec3(0.0);
	float least = 1e9;
	for (int q = 0; q < 4; q++) {
		vec2 dir = vec2(q % 2 == 0 ? 1.0 : -1.0, q < 2 ? 1.0 : -1.0);
		vec3 sum = vec3(0.0);
		vec3 sq = vec3(0.0);
		for (int y = 0; y <= R; y++) {
			for (int x = 0; x <= R; x++) {
				vec3 c = texture(src, UV + vec2(float(x), float(y)) * dir * px).rgb;
				sum += c;
				sq += c * c;
			}
		}
		float n = float((R + 1) * (R + 1));
		vec3 v = sq / n - (sum / n) * (sum / n);
		float spread = v.r + v.g + v.b;
		if (spread < least) {
			least = spread;
			best = sum / n;
		}
	}
	COLOR = vec4(best, texture(src, UV).a);
}
"""
const INK := """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D src : filter_linear, repeat_enable;
float lum(vec2 uv) { return dot(texture(src, uv).rgb, vec3(0.299, 0.587, 0.114)); }
void fragment() {
	vec2 px = vec2(1.5 / 512.0);
	vec4 c = texture(src, UV);
	float dx = lum(UV + vec2(px.x, 0.0)) - lum(UV - vec2(px.x, 0.0));
	float dy = lum(UV + vec2(0.0, px.y)) - lum(UV - vec2(0.0, px.y));
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float bands = floor(l * 7.0 + 0.5) / 7.0;  // shading in flat steps
	vec3 g = c.rgb * mix(1.0, bands / max(l, 0.04), 0.4);
	g = mix(vec3(dot(g, vec3(0.299, 0.587, 0.114))), g, 1.22);
	g = mix(g * vec3(0.8, 0.86, 1.05), g * vec3(1.06, 1.0, 0.92), smoothstep(0.1, 0.55, l));  // cool darks, warm lights
	float ink = smoothstep(0.1, 0.28, length(vec2(dx, dy)));
	COLOR = vec4(mix(g, vec3(0.03, 0.02, 0.04), ink * 0.7), c.a);
}
"""
const LOOK := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float slip = 1.5;  // pixels red and blue slip apart, more toward the edges
uniform float saturation = 1.08;
void fragment() {
	vec2 from = SCREEN_UV - 0.5;
	vec2 off = (from * length(from) * 2.0 * slip + vec2(slip * 0.5, 0.0)) * SCREEN_PIXEL_SIZE;
	vec3 c = vec3(texture(screen, SCREEN_UV + off).r, texture(screen, SCREEN_UV).g, texture(screen, SCREEN_UV - off).b);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(l), c, saturation), 1.0);
}
"""

var _world := Node3D.new()
var _zombies: Array[Node3D] = []
var _cam: Camera3D
var _rect := ColorRect.new()
var _label := Label.new()
var _on := true
var _painted := {}  # the source texture -> its painted copy
var _mats: Array[ShaderMaterial] = []  # every material painted, with its source in meta "source"
var _queue: Array[ShaderMaterial] = []
var _painting := false


func _initialize() -> void:
	root.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.97, 0.92)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -25, 0)
	key.light_color = Color(1.0, 0.93, 0.82)
	key.light_energy = 0.55
	_world.add_child(key)
	_room()
	_stand_up()
	_cam = DEMO.FlyCam.new()
	_cam.fov = 48.0
	_world.add_child(_cam)
	_cam.look_at_from_position(Vector3(-1.2, 1.5, 0.15), Vector3(-1.5, 1.35, -1.5))
	_cam.sync_angles()
	var layer := CanvasLayer.new()
	layer.layer = 0  # over the PS1 screen (-1)
	root.add_child(layer)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = LOOK
	_rect.material = m
	layer.add_child(_rect)
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
	_look(true)
	if "--shot" in OS.get_cmdline_user_args():
		for i in 10:
			await process_frame
		while _painting:
			await process_frame
		var views := [[Vector3(-1.2, 1.5, 0.15), Vector3(-1.5, 1.35, -1.5)], [Vector3(0.2, 1.6, 2.4), Vector3(0.0, 1.2, -1.5)]]
		for n in views.size():
			_cam.look_at_from_position(views[n][0], views[n][1])
			for i in 40:
				await process_frame
			var file := "user://painted_demo_%d.png" % n
			root.get_viewport().get_texture().get_image().save_png(file)
			print(ProjectSettings.globalize_path(file))
		quit()
		return
	_cam.on_key = func(k: Key) -> void:
		if k == KEY_G:
			_look(not _on)
		elif k == KEY_H:
			_pop()
		elif k == KEY_R:
			_stand_up()


func _look(on: bool) -> void:
	_on = on
	var psx: Node = root.get_node("PsxScreen")
	psx.apply(480 if on else 0, false)
	psx._rect.material.set_shader_parameter(&"psx_dither", DITHER)
	psx._rect.material.set_shader_parameter(&"psx_grade", 0.0)
	_rect.visible = on
	for m in _mats:
		var source: Texture2D = m.get_meta(&"source")
		m.set_shader_parameter(&"albedo_tex", _painted.get(source, source) if on else source)
	_label.text = "G Tarz   H Kafa   R Yeniden      %s" % ("Açık" if on else "Kapalı")


func _pop() -> void:
	var best: Node3D = null
	var near := -2.0
	var ahead := -_cam.global_basis.z
	for z in _zombies:
		if z.get_child(0)._dead:
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
		holder.position = Vector3(-1.6 + i * 1.6, 0, -1.5)
		holder.rotation.y = PI + (i - 1) * 0.3  # the body faces -Z: turned round to the camera
		var body: Node3D = ZOMBIE_BODY.new()
		body.setup(&"walker", 11)  # the upright idle (idle_f), the look is what is on show
		body.model = StringName(ZOMBIES[i])
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
				_paint(mat)


## `m` wears the painted copy of its texture, as soon as there is one.
func _paint(m: ShaderMaterial) -> void:
	var source: Texture2D = m.get_shader_parameter(&"albedo_tex")
	if source == null:
		return
	m.set_meta(&"source", source)
	_mats.append(m)
	_queue.append(m)
	if not _painting:
		_paint_all()


func _paint_all() -> void:
	_painting = true
	while not _queue.is_empty():
		var m: ShaderMaterial = _queue.pop_back()
		var source: Texture2D = m.get_meta(&"source")
		if not _painted.has(source):
			var strokes := await _pass(source, PAINT)
			_painted[source] = await _pass(strokes, INK)
		if _on:
			m.set_shader_parameter(&"albedo_tex", _painted[source])
	_painting = false


## `tex` drawn through `code` in a small viewport of its own, read back.
func _pass(tex: Texture2D, code: String) -> ImageTexture:
	var vp := SubViewport.new()
	vp.size = Vector2i(PAINTED, PAINTED)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(PAINTED, PAINTED)
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = code
	m.set_shader_parameter(&"src", tex)
	rect.material = m
	vp.add_child(rect)
	root.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	vp.queue_free()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _plane(tex: String, size: Vector2, at: Vector3, rot: Vector3, tint: Color) -> void:
	var p := PlaneMesh.new()
	p.orientation = PlaneMesh.FACE_Z
	p.size = size
	p.subdivide_width = int(size.x * 2)
	p.subdivide_depth = int(size.y * 2)
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.position = at
	mi.rotation = rot
	var m := ShaderMaterial.new()
	m.shader = preload("res://materials/psx.gdshader")
	m.set_shader_parameter(&"albedo_tex", load(TEX % tex))
	m.set_shader_parameter(&"uv_scale", size * TEXELS / 128.0)
	m.set_shader_parameter(&"snap", 0.0)
	m.set_shader_parameter(&"tint", tint)
	mi.material_override = m
	_paint(m)
	_world.add_child(mi)
	var body := StaticBody3D.new()  # so blood finds it
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(size.x, size.y, 0.1)
	body.add_child(shape)
	mi.add_child(body)


func _room() -> void:
	_plane("gravelly_sand", Vector2(10, 10), Vector3.ZERO, Vector3(-PI * 0.5, 0, 0), Color(0.34, 0.31, 0.3))
	_plane("concrete_slab_wall", Vector2(10, 3.4), Vector3(0, 1.7, -3.0), Vector3.ZERO, Color(0.42, 0.44, 0.47))
	_plane("dirty_concrete", Vector2(10, 3.4), Vector3(-4.0, 1.7, 0), Vector3(0, PI * 0.5, 0), Color(0.42, 0.44, 0.47))
	_plane("dirty_concrete", Vector2(10, 3.4), Vector3(4.0, 1.7, 0), Vector3(0, -PI * 0.5, 0), Color(0.42, 0.44, 0.47))
