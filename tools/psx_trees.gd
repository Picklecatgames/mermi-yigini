extends SceneTree
## The desert trees' crowns as PS1 did them (2026-11-03, the user: the trees are bad, find PS1
## ones; the desert's own kinds kept): a few big crossed cards with the crown drawn on them, not
## thousands of scanned leaves. tools/psx_props.gd nature has made each tree's _psx.scn (the wood
## a few hundred triangles); here every mesh in it that has leaves gets them swapped for VIEWS
## vertical cards crossing at the crown's middle, each showing the scan's own leaves (and twigs)
## drawn from that side, unlit, PX px a view, cut out, in the desert's colours. The cards' normals
## point up, so the crown takes the sun as one canopy, never black from behind.
## Needs a window (it renders):
##   Godot.exe --path . --position -10000,-10000 -s res://tools/psx_trees.gd

const PSX := preload("res://tools/psx_props.gd")
const NAMA := "res://assets/env/namaqualand/%s/%s_1k%s"
## id -> the cards' tint: drawn unlit and lit again from straight up, the quiver tree's pale
## rosettes came out paler than the scan, the dark needles of the others nearly black.
const TREES := {"quiver_tree_01": 0.75, "searsia_burchellii": 1.3, "wild_rooibos_bush": 1.4}
const VIEWS := 3
const PX := 128
const DRAW := 512  # px a view is drawn at, then shrunk to PX: the leaves average, not alias

var _view: SubViewport
var _cam: Camera3D
var _keyed := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	_view = SubViewport.new()
	_view.size = Vector2i(DRAW, DRAW)
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_view.add_child(_cam)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_cam.environment = env
	var ok := true
	for id: String in TREES:
		ok = await _tree(id, TREES[id]) and ok
	quit(0 if ok else 1)


func _tree(id: String, tint: float) -> bool:
	var src: Node = (load(NAMA % [id, id, ".gltf"]) as PackedScene).instantiate()
	var out_path: String = NAMA % [id, id, "_psx.scn"]
	var psx: Node = (load(out_path) as PackedScene).instantiate()
	var done := 0
	for mi: MeshInstance3D in psx.find_children("*", "MeshInstance3D", true, false):
		var orig := src.find_child(mi.name, true, false) as MeshInstance3D
		if orig == null or not _has_leaves(mi.mesh):
			continue
		var cards := await _cards(orig.mesh, tint)
		var mesh := ArrayMesh.new()
		for s in mi.mesh.get_surface_count():
			if _is_leaf(mi.mesh.surface_get_material(s)):
				continue
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mi.mesh.surface_get_arrays(s))
			mesh.surface_set_material(mesh.get_surface_count() - 1, mi.mesh.surface_get_material(s))
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cards[0])
		mesh.surface_set_material(mesh.get_surface_count() - 1, cards[1])
		mi.mesh = mesh
		done += 1
	var packed := PackedScene.new()
	var err := packed.pack(psx)
	if err == OK:
		err = ResourceSaver.save(packed, out_path, ResourceSaver.FLAG_COMPRESS)
	print("psx trees %s: %d crowns as cards%s" % [id, done, "" if err == OK else " ERROR %d" % err])
	src.free()
	psx.free()
	return err == OK


static func _is_leaf(m: Material) -> bool:
	if not m is ShaderMaterial:
		return false
	var cut = (m as ShaderMaterial).get_shader_parameter("alpha_cut")
	return cut != null and float(cut) > 0.0


static func _has_leaves(mesh: Mesh) -> bool:
	for s in mesh.get_surface_count():
		if _is_leaf(mesh.surface_get_material(s)):
			return true
	return false


static func _see_through(m: Material) -> bool:
	return m is BaseMaterial3D and (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED


## `img` (DRAW px) down to PX, each pixel its block's colour weighted by alpha: an ordinary shrink
## mixed the clear (black) background into the leaves' edges and the bushes came out black.
static func _shrunk(img: Image) -> Image:
	var out := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	var k := DRAW / PX
	for y in PX:
		for x in PX:
			var sum := Vector3.ZERO
			var a := 0.0
			for j in k:
				for i in k:
					var c := img.get_pixel(x * k + i, y * k + j)
					sum += Vector3(c.r, c.g, c.b) * c.a
					a += c.a
			var rgb := sum / maxf(a, 1e-4)
			out.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, a / (k * k)))
	return out


## The leaves closed up into masses: alpha spread over its 3x3 and cut at MASS, the gaps' colour
## the mean of the leaves round them. At 128 px a crown of single leaves fell apart into specks;
## a PS1 crown was a solid, ragged mass with leaves drawn in it.
const MASS := 0.3


static func _massed(img: Image) -> Image:
	var out := img.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var sum := Vector3.ZERO
			var a := 0.0
			for j in range(-1, 2):
				for i in range(-1, 2):
					var c := img.get_pixel(clampi(x + i, 0, w - 1), clampi(y + j, 0, h - 1))
					sum += Vector3(c.r, c.g, c.b) * c.a
					a += c.a
			var own := img.get_pixel(x, y)
			if own.a >= 0.5:
				out.set_pixel(x, y, Color(own.r, own.g, own.b, 1.0))
			elif a / 9.0 >= MASS:
				var rgb := sum / maxf(a, 1e-4)
				out.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, 1.0))
			else:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	return out


## [card arrays, card material] for the scan mesh `mesh`'s see-through surfaces.
func _cards(mesh: Mesh, tint: float) -> Array:
	var box := AABB()
	var first := true
	for s in mesh.get_surface_count():
		if not _see_through(mesh.surface_get_material(s)):
			continue
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			box = AABB(v, Vector3.ZERO) if first else box.expand(v)
			first = false
	# The leaves alone, unlit: their own colours on the cards; the wood stays 3D.
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		if _see_through(m):
			var flat := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			if not _keyed.has(flat.albedo_texture):
				_keyed[flat.albedo_texture] = PSX.keyed(flat.albedo_texture)  # leaves on black: see psx_props.gd keyed
			flat.albedo_texture = _keyed[flat.albedo_texture]
			flat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			flat.alpha_scissor_threshold = 0.4
			flat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.set_surface_override_material(s, flat)
		else:
			var gone := StandardMaterial3D.new()
			gone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gone.albedo_color = Color(0, 0, 0, 0)
			mi.set_surface_override_material(s, gone)
	_view.add_child(mi)
	var mid := box.get_center()
	var side := maxf(box.size.y, Vector2(box.size.x, box.size.z).length()) * 1.02
	_cam.size = side
	var atlas := Image.create(PX * VIEWS, PX, false, Image.FORMAT_RGBA8)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for k in VIEWS:
		var a := PI * k / VIEWS
		var dir := Vector3(sin(a), 0.0, cos(a))
		_cam.look_at_from_position(mid + dir * (side + 10.0), mid)
		_cam.near = 0.05
		_cam.far = side * 2.0 + 20.0
		for f in 4:
			await process_frame
		var img := _view.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(_shrunk(img), Rect2i(0, 0, PX, PX), Vector2i(PX * k, 0))
		var right := (-dir).cross(Vector3.UP).normalized()
		var base := verts.size()
		for c: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			verts.append(mid + right * (c.x - 0.5) * side + Vector3.UP * (0.5 - c.y) * side)
			uvs.append(Vector2((k + c.x) / VIEWS, c.y))
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	mi.queue_free()
	atlas = _massed(atlas)
	for y in atlas.get_height():
		for x in atlas.get_width():
			var c := atlas.get_pixel(x, y)
			atlas.set_pixel(x, y, PSX._desert(c) if c.a > 0.0 else c)
	atlas.save_png("user://psx_trees_%s.png" % mesh.resource_name.validate_filename())  # to look at
	atlas.generate_mipmaps()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var up := PackedVector3Array()
	up.resize(verts.size())
	up.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = up
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var tex := PortableCompressedTexture2D.new()
	tex.create_from_image(atlas, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	var m := ShaderMaterial.new()
	m.shader = PSX.SHADER_2S
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("alpha_cut", 0.5)
	m.set_shader_parameter("tint", Color(tint, tint, tint * 0.97))
	m.set_shader_parameter("far_colour", Color(0.0, 0.0, 0.0, 0.0))
	return [arrays, m]
