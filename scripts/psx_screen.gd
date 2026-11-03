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
const MIP_BIAS := 1.5  # mips softer on the root viewport's ordinary materials, the PS1 screen on

var lines := 0
var fine := true
var _rect := ColorRect.new()
var _view_mat := ShaderMaterial.new()
var _views: Array[SubViewportContainer] = []


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
	if n is SubViewportContainer and n.name in VIEWS and not n in _views:
		_views.append(n)
		n.tree_exiting.connect(func() -> void: _views.erase(n), CONNECT_ONE_SHOT)
		_fit.call_deferred()  # its SubViewport comes in after it


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
