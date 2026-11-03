extends CanvasLayer
## The PS1 screen (autoload `PsxScreen`, 2026-11-02, the user: the whole game in PS1 horror style).
## The 3D is drawn `lines` pixels tall and blown up unfiltered (SCALING_3D_MODE_NEAREST), no edge
## smoothing; over it, on this layer, the colour comes down to 15 bits with a 4x4 ordered dither
## (materials/psx_screen.gdshader). The HUD, the menus and their text sit on higher layers and stay
## sharp. The gun in the hand has its own viewport (player.tscn ViewmodelView, on the root canvas
## over this layer): it is drawn just as small and its container gets the same colour
## (materials/psx_view.gdshader).
##
## Settings sets `lines` (the "PS1 ekranı" choice); 0 is off and leaves the viewports to Settings.
## `fine` ("Titreme azaltma", on by default): the 3D drawn twice as tall and each pixel the mean of
## its 2x2 (2026-11-03, the user: zigzag walls and boiling far things "göz kanatıyor"); textures
## on materials/psx.gdshader then take the next smaller mip (psx_mip_bias), as the pixel shown.
## Cost: the 3D draws ~1/20 of the pixels at 1080p and the colour pass is one screen copy, so the
## frame gets cheaper, not dearer: RTX 3090, 1920x1080, GPU 10.1 -> 4.9 ms in the yard by day,
## 8.8 -> 4.1 ms in the workshop at night (tools/psx_shots.gd --game). Each machine draws only its
## own screen, so four players in co-op cost the same per machine.

const VIEWS := ["ViewmodelView"]  # SubViewportContainers that draw 3D over the world
const MIP_BIAS := 0.5  # mips softer on the root viewport's ordinary materials, the PS1 screen on
## The world's own StandardMaterials (the ground, the walls, the scans: not yet PS1 assets), the
## PS1 screen on: their texture shrunk to TEX px and drawn unfiltered, no normal map, no shine
## (2026-11-03, the user: it looks like a modern game with its graphics turned down, not a PS1
## game, and it still crawls). 2K photo scans at 270 lines put a dozen texels in each pixel, and
## that average boils as the view moves; on the old console a texel was bigger than a pixel.
const TEX := 128

var lines := 0
var fine := true
var _rect := ColorRect.new()
var _view_mat := ShaderMaterial.new()
var _views: Array[SubViewportContainer] = []
var _small := {}  # a scan -> its TEX px copy
var _mats := {}  # BaseMaterial3D -> what it was built with: [albedo_texture, texture_filter, normal_enabled, specular_mode]


func _ready() -> void:
	layer = -1  # over the world, under every CanvasLayer and the root canvas (the gun's view)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://materials/psx_screen.gdshader")
	_rect.material = mat
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)
	_view_mat.shader = preload("res://materials/psx_view.gdshader")
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().root.find_children("*", "SubViewportContainer", true, false):
		_on_node_added(n)
	get_viewport().size_changed.connect(_fit)


## Settings calls this after it has set the root viewport's own scaling and smoothing.
func apply(n: int, twice := true) -> void:
	lines = n
	fine = twice
	_fit()


func _on_node_added(n: Node) -> void:
	if n is GeometryInstance3D and lines > 0:
		_ps1_materials.call_deferred(n)  # its mesh and overrides are in by then
	if n is SubViewportContainer and n.name in VIEWS and not n in _views:
		_views.append(n)
		n.tree_exiting.connect(func() -> void: _views.erase(n), CONNECT_ONE_SHOT)
		_fit.call_deferred()  # its SubViewport comes in after it


## `g`'s StandardMaterials the PS1 way (TEX). Only the world's (the root viewport's): the gun in
## the hand has its own viewport and its close-up texture.
func _ps1_materials(g: Node) -> void:
	if not is_instance_valid(g) or not g.is_inside_tree() or g.get_viewport() != get_viewport():
		return
	var mats: Array[Material] = []
	var gi := g as GeometryInstance3D
	if gi.material_override:
		mats.append(gi.material_override)
	if g is MeshInstance3D and (g as MeshInstance3D).mesh:
		var mi := g as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			mats.append(mi.get_surface_override_material(s) if mi.get_surface_override_material(s) else mi.mesh.surface_get_material(s))
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh and (g as MultiMeshInstance3D).multimesh.mesh:
		var mesh := (g as MultiMeshInstance3D).multimesh.mesh
		for s in mesh.get_surface_count():
			mats.append(mesh.surface_get_material(s))
	for m in mats:
		if m is ShaderMaterial:
			_ps1_shader(m as ShaderMaterial)
			continue
		var b := m as BaseMaterial3D
		if b == null or _mats.has(b) or b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			continue  # unshaded: effects and glows, they keep their own look
		_mats[b] = [b.albedo_texture, b.texture_filter, b.normal_enabled, b.specular_mode, b.shading_mode]
		if b.albedo_texture:
			b.albedo_texture = _shrunk(b.albedo_texture)
		b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		b.normal_enabled = false
		b.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if not b.uv1_triplanar:  # triplanar lit per vertex drew the yard's kerb white
			b.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX  # lit per vertex, as the PS1 props and the dead are


## The world's own ground shaders (the desert, the worn concrete): their textures shrunk the same
## way; the filter is the shader's own. Only these: other shaders hold data in their textures
## (the scrap heap's height and cover), and shrunk they drew white specks over the heap.
const GROUND_SHADERS := ["res://materials/env/desert.gdshader", "res://materials/env/worn_surface.gdshader"]


func _ps1_shader(m: ShaderMaterial) -> void:
	if _mats.has(m) or m.shader == null or not m.shader.resource_path in GROUND_SHADERS:
		return
	var was := {}
	for u: Dictionary in m.shader.get_shader_uniform_list():
		var t = m.get_shader_parameter(u.name)
		if t is Texture2D and not (t is NoiseTexture2D):
			was[u.name] = t
			m.set_shader_parameter(u.name, _shrunk(t))
	_mats[m] = was


func _shrunk(tex: Texture2D) -> Texture2D:
	if _small.has(tex):
		return _small[tex]
	var small := tex
	if tex.get_width() > TEX or tex.get_height() > TEX:
		var img := tex.get_image()
		if img:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			if img.has_mipmaps():
				img.clear_mipmaps()
			var k := float(TEX) / maxf(img.get_width(), img.get_height())
			img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
			img.generate_mipmaps()
			small = ImageTexture.create_from_image(img)
	_small[tex] = small
	return small


## The world's materials as they were built (the PS1 screen off).
func _restore_materials() -> void:
	for b: Material in _mats:
		if b is ShaderMaterial and is_instance_valid(b):
			var params: Dictionary = _mats[b]
			for p: StringName in params:
				(b as ShaderMaterial).set_shader_parameter(p, params[p])
		elif is_instance_valid(b):
			var was: Array = _mats[b]
			b.albedo_texture = was[0]
			b.texture_filter = was[1]
			b.normal_enabled = was[2]
			b.specular_mode = was[3]
			b.shading_mode = was[4]
	_mats.clear()


func _fit() -> void:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var taps := 2.0 if fine else 1.0
	var scale := minf(1.0, lines * taps / maxf(size.y, 1.0))
	var small := (size * lines / maxf(size.y, 1.0)).floor().max(Vector2.ONE)
	RenderingServer.global_shader_parameter_set(&"psx_mip_bias", log(taps) / log(2.0) if lines > 0 else 0.0)
	# The materials not yet on psx.gdshader (the scrap, the world's scans) read their textures a
	# mip softer too, or their fine detail boils at 270 lines (2026-11-03, the user: the scrap tires
	# the eyes).
	vp.texture_mipmap_bias = MIP_BIAS if lines > 0 else 0.0
	if lines > 0:
		for g in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
			_ps1_materials(g)
	else:
		_restore_materials()
	_rect.visible = lines > 0
	if lines > 0:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
		vp.scaling_3d_scale = scale
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_taa = false
		for m: ShaderMaterial in [_rect.material, _view_mat]:
			m.set_shader_parameter(&"psx_size", small)
			m.set_shader_parameter(&"psx_taps", taps)
	for c in _views:
		var sub: SubViewport = c.get_child(0) if c.get_child_count() > 0 else null
		if sub == null:
			continue
		if not sub.has_meta(&"built_msaa"):
			sub.set_meta(&"built_msaa", sub.msaa_3d)
		c.material = _view_mat if lines > 0 else null
		sub.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST if lines > 0 else Viewport.SCALING_3D_MODE_BILINEAR
		sub.scaling_3d_scale = scale if lines > 0 else 1.0
		sub.msaa_3d = Viewport.MSAA_DISABLED if lines > 0 else sub.get_meta(&"built_msaa")
