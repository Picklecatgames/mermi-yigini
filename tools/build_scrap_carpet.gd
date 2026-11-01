extends SceneTree
## Bakes the scrap heap's under-surface (materials/scrap_heap.gdshader) from the real pieces: a
## TILE-metre square packed with them a few deep, shot straight down. Pieces near an edge are
## repeated across it, so the square tiles without a seam. Writes
##   materials/scrap/scrap_carpet_col.res  colour darkened in the cracks; alpha = height
##   materials/scrap/scrap_carpet_nrm.res  normal map (OpenGL), from the height
## A window is needed (headless renders nothing); it opens off screen:
##   Godot.exe --path . --position -10000,-10000 -s res://tools/build_scrap_carpet.gd

const TILE := 2.0        # m one repeat covers
const SHOT := 2048       # px rendered; saved at OUT
const OUT := 1024
const DEPTH := 0.3       # m of jumble the height channel spans
const FILL := 4.5        # times the square's area in footprints: four or so deep
const MAX_PIECE := 0.4   # m: crates, cans and tyres are the drawn pieces' job; under them, small stuff
const CAVITY_PX := 10    # blur radius the cracks are measured against
const DIR := "res://materials/scrap/"

var _vp: SubViewport


func _initialize() -> void:
	var pile = load("res://scripts/pile.gd").new()  # untyped: Pile needs the autoloads to compile
	pile._load_parts()
	_vp = SubViewport.new()
	_vp.size = Vector2i(SHOT, SHOT)
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	_vp.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = TILE
	cam.near = 0.1
	cam.far = 10.0
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(TILE * 0.5, 3.0, TILE * 0.5), Vector3(TILE * 0.5, 0.0, TILE * 0.5), Vector3.FORWARD)
	cam.make_current()

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var meshes: Array[MeshInstance3D] = []
	var area := 0.0
	while area < TILE * TILE * FILL:
		var part: int = pile._pick_part(rng.randf())
		var s: Vector3 = pile._part_size[part]
		if s[s.max_axis_index()] > MAX_PIECE:
			continue
		area += pile._part_foot[part]
		var thin := 0 if s.x <= s.y and s.x <= s.z else (1 if s.y <= s.z else 2)
		var lay := Basis()
		if thin == 0:
			lay = Basis(Vector3.BACK, PI * 0.5)
		elif thin == 2:
			lay = Basis(Vector3.RIGHT, PI * 0.5)
		var tumble := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.7))
		var b := tumble * Basis(Vector3.UP, rng.randf() * TAU) * lay
		var o := Vector3(rng.randf() * TILE, rng.randf_range(0.0, DEPTH - s[thin] * 0.5), rng.randf() * TILE)
		var reach := s.length() * 0.5
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var at := o + Vector3(dx * TILE, 0.0, dz * TILE)
				if at.x < -reach or at.x > TILE + reach or at.z < -reach or at.z > TILE + reach:
					continue
				var mi := MeshInstance3D.new()
				mi.mesh = pile._part_mesh[part]
				mi.transform = Transform3D(b, at).translated_local(-pile._part_mid[part])
				_vp.add_child(mi)
				meshes.append(mi)
	print("%d pieces" % meshes.size())

	_vp.debug_draw = Viewport.DEBUG_DRAW_UNSHADED  # albedo only: no light baked in
	var col := await _shoot()
	var height := ShaderMaterial.new()
	height.shader = Shader.new()
	height.shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
varying float y;
void vertex() { y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() { ALBEDO = vec3(clamp(y / %f, 0.0, 1.0)); }
""" % DEPTH
	for mi in meshes:
		mi.material_override = height
	_vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED
	var h_img := await _shoot()
	h_img.srgb_to_linear()  # the unshaded output went through the sRGB curve

	var n := OUT
	var h := PackedFloat32Array()
	h.resize(n * n)
	for y in n:
		for x in n:
			h[y * n + x] = h_img.get_pixel(x, y).r
	var blur := _blur(h, n, CAVITY_PX)
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var nrm := Image.create(n, n, false, Image.FORMAT_RGB8)
	var px := TILE / n
	for y in n:
		for x in n:
			var k := y * n + x
			# Cracks: lower than what is round them; the deeper down, the darker; bare gaps near black.
			var crack := clampf((blur[k] - h[k]) * 6.0, 0.0, 0.75)
			var shade := (1.0 - crack) * lerpf(0.25, 1.0, h[k]) * (0.05 if h[k] < 0.01 else 1.0)
			var c := col.get_pixel(x, y)
			out.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade, h[k]))
			var dx := (h[y * n + (x + 1) % n] - h[y * n + (x + n - 1) % n]) * DEPTH / (2.0 * px)
			var dy := (h[((y + 1) % n) * n + x] - h[((y + n - 1) % n) * n + x]) * DEPTH / (2.0 * px)
			# Image rows run toward +z, the map's v; OpenGL green points up the image.
			var v := Vector3(-dx, dy, 1.0).normalized()
			nrm.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, v.z * 0.5 + 0.5))
	out.save_png("user://scrap_carpet_col.png")  # to look at
	_save(out, "scrap_carpet_col.res", false)
	_save(nrm, "scrap_carpet_nrm.res", true)
	print("saved ", ProjectSettings.globalize_path(DIR + "scrap_carpet_col.res"))
	quit()


## Saved as a ready texture, mipmapped and VRAM-compressed (S3TC: desktop), with no import step.
func _save(img: Image, file: String, normal_map: bool) -> void:
	img.generate_mipmaps(normal_map)
	var tex := PortableCompressedTexture2D.new()
	tex.keep_compressed_buffer = true  # outside the editor it is dropped, and nothing gets saved
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_S3TC, normal_map)
	DirAccess.make_dir_recursive_absolute(DIR)
	var err := ResourceSaver.save(tex, DIR + file)
	assert(err == OK, "saved %s" % file)


## The viewport's picture at OUT pixels, once it has settled.
func _shoot() -> Image:
	for f in 8:
		await process_frame
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(OUT, OUT, Image.INTERPOLATE_LANCZOS)
	return img


## Box blur of a wrapping n×n field, radius r, rows then columns.
func _blur(src: PackedFloat32Array, n: int, r: int) -> PackedFloat32Array:
	var a := src
	for pass_i in 2:
		var b := PackedFloat32Array()
		b.resize(n * n)
		for line in n:
			var sum := 0.0
			for i in range(-r, r + 1):
				sum += a[_at(line, (i + n) % n, n, pass_i)]
			for i in n:
				b[_at(line, i, n, pass_i)] = sum / (2 * r + 1)
				sum += a[_at(line, (i + r + 1) % n, n, pass_i)] - a[_at(line, (i - r + n) % n, n, pass_i)]
		a = b
	return a


static func _at(line: int, i: int, n: int, vertical: int) -> int:
	return i * n + line if vertical else line * n + i
