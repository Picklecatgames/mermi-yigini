extends Node3D
## Gear in the world (yol haritası 10). Every machine builds each piece the host lets up here, as
## Gear_<n> in placement order, so shot and cue events find it by the same path everywhere.
## In placement mode (B) with something in the shared stock, the local player sees a see-through
## copy where they look: mouse wheel picks the piece, R turns it, left click puts it up. Others see
## that copy faint, in the placer's colour. Later turrets and belts go up through the same code.

const REACH := 30.0          # m the preview ray looks
const TURN := PI / 4.0       # R turns by this
const SEND_EVERY := 0.1      # s between preview updates to the others
const GHOST_STALE := 1.5     # s without word before someone else's preview goes
const OK_COLOR := Color(0.35, 1.0, 0.45, 0.38)
const BAD_COLOR := Color(1.0, 0.3, 0.28, 0.38)
const OTHERS_ALPHA := 0.16

var _pick := 0               # index into what the stock has
var _yaw := -PI / 2.0        # facing west, at the shooters, like the fixed targets
var _ghost: Node3D
var _ghost_id := ""
var _spot := Vector3.ZERO
var _spot_ok := false
var _send_in := 0.0
var _sent_id := ""
var _others := {}            # peer -> {node, id, seen}
var _hint: Label


func _ready() -> void:
	GameState.gear_placed.connect(_put_up)
	GameState.preview_received.connect(_on_preview)
	for n in GameState.placed.size():  # already up (scene reloaded)
		_put_up.callv([n] + GameState.placed[n])
	var hud := CanvasLayer.new()
	add_child(hud)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -110
	_hint.offset_bottom = -70
	_hint.offset_left = -400
	_hint.offset_right = 400
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	hud.add_child(_hint)


## Everyone: a piece the host let up.
func _put_up(n: int, id: String, pos: Vector3, yaw: float) -> void:
	var name := "Gear_%d" % n
	if has_node(name):
		return
	var node: Node3D = load(GameState.GEAR[id].scene).instantiate()
	node.name = name
	node.position = pos
	node.rotation.y = yaw
	add_child(node)


func _stocked() -> Array:
	return GameState.GEAR.keys().filter(func(id: String) -> bool: return GameState.gear_stock.get(id, 0) > 0)


func _active() -> bool:
	return GameState.player().placing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _stocked().is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if not _active():
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_pick += 1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and _spot_ok:
			GameState.request_place_gear(_ghost_id, _spot, _yaw)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reload"):
		_yaw = wrapf(_yaw + TURN, -PI, PI)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_own()
	_send_in -= delta
	if _send_in <= 0.0:
		_send_in = SEND_EVERY
		var id := _ghost_id if _ghost and _ghost.visible else ""
		if id != "" or _sent_id != "":
			GameState.send_preview(id, _spot, _yaw)
		_sent_id = id
	var now := Time.get_ticks_msec() / 1000.0
	for peer: int in _others.keys():
		if now - _others[peer].seen > GHOST_STALE:
			_drop_other(peer)


func _update_own() -> void:
	var stock := _stocked()
	if not _active():
		if _ghost:
			_ghost.visible = false
		_hint.visible = false
		return
	_pick = posmod(_pick, stock.size())
	var id: String = stock[_pick]
	if id != _ghost_id:
		if _ghost:
			_ghost.queue_free()
		_ghost = _make_ghost(id)
		_ghost_id = id
		add_child(_ghost)
	var cam := get_viewport().get_camera_3d()
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * REACH, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_ghost.visible = not hit.is_empty()
	if hit.is_empty():
		_spot_ok = false
	else:
		_spot = hit.position
		_spot_ok = hit.normal.y > 0.7 and GameState.can_place(id, _spot)
		_ghost.global_position = _spot
		_ghost.rotation.y = _yaw
		_tint(_ghost, OK_COLOR if _spot_ok else BAD_COLOR)
	_hint.text = "%s  ·  depoda %d\nTekerlek: seç   R: döndür   Sol tık: koy%s" % [GameState.GEAR[id].name, GameState.gear_stock[id],
		"" if _spot_ok or hit.is_empty() else "   (buraya konmaz)"]
	_hint.visible = true


## Someone else's preview: a faint copy in their colour; id "" takes it away.
func _on_preview(peer: int, id: String, pos: Vector3, yaw: float) -> void:
	if id == "" or not GameState.GEAR.has(id):
		_drop_other(peer)
		return
	var o: Dictionary = _others.get(peer, {})
	if o.is_empty() or o.id != id:
		_drop_other(peer)
		var c := GameState.color_of(peer)
		var g := _make_ghost(id)
		_tint(g, Color(c, OTHERS_ALPHA))
		add_child(g)
		o = {"node": g, "id": id}
		_others[peer] = o
	o.seen = Time.get_ticks_msec() / 1000.0
	(o.node as Node3D).global_position = pos
	(o.node as Node3D).rotation.y = yaw


func _drop_other(peer: int) -> void:
	if _others.has(peer):
		(_others[peer].node as Node).queue_free()
		_others.erase(peer)


## A see-through copy of a piece: its meshes only, so none of its scripts, bodies or sounds run.
func _make_ghost(id: String) -> Node3D:
	var src: Node = load(GameState.GEAR[id].scene).instantiate()
	var ghost := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.set_meta("mat", mat)
	for m: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		if not m.mesh:
			continue
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != src and n is Node3D:  # its place under the piece's root, out of the tree
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var copy := MeshInstance3D.new()
		copy.mesh = m.mesh
		copy.transform = t
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
	src.free()
	return ghost


func _tint(ghost: Node3D, color: Color) -> void:
	(ghost.get_meta("mat") as StandardMaterial3D).albedo_color = color
