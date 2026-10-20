extends Node3D
## Gear in the world (yol haritası 10). Every machine builds each piece the host lets up here, as
## Gear_<n> in placement order, so shot and cue events find it by the same path everywhere.
## Placement mode (B, or buying gear in the workshop) puts the local player past the firing line:
## a see-through copy of the stock piece follows the look (wheel picks, R turns, left click puts it
## up); looking at a placed piece marks it red, and holding X takes it back to the stock. A banner
## on top says what is going on, a row of key prompts at the bottom says what each key does.
## Others see the copy faint, in the placer's colour. Later turrets and belts use the same code.

const REACH := 30.0          # m the look reaches
const TURN := PI / 4.0       # R turns by this
const REMOVE_HOLD := 0.6     # s X is held to take a piece down
const SEND_EVERY := 0.1      # s between preview updates to the others
const GHOST_STALE := 1.5     # s without word before someone else's preview goes
const OK_COLOR := Color(0.35, 1.0, 0.45, 0.38)
const BAD_COLOR := Color(1.0, 0.3, 0.28, 0.38)
const OTHERS_ALPHA := 0.16
const GOLD := Color(1.0, 0.8, 0.3)
const RED := Color(1.0, 0.38, 0.33)
const DIM := Color(0.62, 0.65, 0.7)

var _pick := 0               # index into what the stock has
var _yaw := -PI / 2.0        # facing west, at the shooters, like the fixed targets
var _ghost: Node3D
var _ghost_id := ""
var _spot := Vector3.ZERO
var _spot_ok := false
var _aimed: Node3D           # placed piece under the look
var _hold := 0.0             # s X has been held on _aimed
var _send_in := 0.0
var _sent_id := ""
var _others := {}            # peer -> {node, id, seen}
var _mark_mat := StandardMaterial3D.new()  # red over a piece about to be taken down
var _zone: MeshInstance3D
# HUD
var _banner: Control
var _banner_sub: Label
var _bar: Control
var _keys := {}              # action -> prompt row
var _hold_fill: ColorRect
var _nudge: Label            # outside placement mode, when something waits in the stock


func _ready() -> void:
	add_to_group("placement")
	_mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_mat.albedo_color = Color(RED, 0.35)
	GameState.gear_placed.connect(_put_up)
	GameState.gear_removed.connect(_take_down)
	GameState.preview_received.connect(_on_preview)
	for n in GameState.placed.size():  # already up (scene reloaded)
		if GameState.placed[n]:
			_put_up.callv([n] + GameState.placed[n])
	_build_hud()
	_build_zone()


## Where gear may go, drawn on the floor in placement mode: a faint green field with a 1 m grid
## and a bright edge (GameState.PLACE_ZONE).
func _build_zone() -> void:
	var z := GameState.PLACE_ZONE
	var plane := PlaneMesh.new()
	plane.size = z.size
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color;
uniform vec2 size;
void fragment() {
	vec2 m = UV * size;
	vec2 to_edge = min(UV, 1.0 - UV) * size;
	float edge = 1.0 - smoothstep(0.0, 0.08, min(to_edge.x, to_edge.y));
	vec2 cell = abs(fract(m) - 0.5);
	float grid = step(0.475, max(cell.x, cell.y));  // 5 cm lines on every metre
	ALBEDO = tint.rgb;
	ALPHA = tint.a * (0.18 + grid * 0.25) + edge * 0.7;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", Color(0.35, 1.0, 0.45, 0.6))
	mat.set_shader_parameter("size", z.size)
	plane.material = mat
	_zone = MeshInstance3D.new()
	_zone.mesh = plane
	_zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_zone.position = Vector3(z.get_center().x, 0.015, z.get_center().y)
	_zone.visible = false
	add_child(_zone)


## Workshop: a piece was just bought; have it ready in hand.
func focus(id: String) -> void:
	var i := _stocked().find(id)
	if i >= 0:
		_pick = i


## Everyone: a piece the host let up.
func _put_up(n: int, id: String, pos: Vector3, yaw: float) -> void:
	var node_name := "Gear_%d" % n
	if has_node(node_name):
		return
	var node: Node3D = load(GameState.GEAR[id].scene).instantiate()
	node.name = node_name
	node.position = pos
	node.rotation.y = yaw
	add_child(node)


## Everyone: a piece the host took down.
func _take_down(n: int) -> void:
	var node := get_node_or_null("Gear_%d" % n)
	if node:
		if node == _aimed:
			_aimed = null
		node.queue_free()


func _stocked() -> Array:
	return GameState.GEAR.keys().filter(func(id: String) -> bool: return GameState.gear_stock.get(id, 0) > 0)


func _active() -> bool:
	return GameState.player().placing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _active():
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_pick += 1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and _spot_ok and not _aimed:
			GameState.request_place_gear(_ghost_id, _spot, _yaw)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reload"):
		_yaw = wrapf(_yaw + TURN, -PI, PI)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_own(delta)
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


func _update_own(delta: float) -> void:
	var stock := _stocked()
	var on := _active()
	_banner.visible = on
	_bar.visible = on
	_zone.visible = on
	_nudge.visible = not on and not stock.is_empty() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _nudge.visible:
		var count: int = stock.reduce(func(sum: int, id: String) -> int: return sum + GameState.gear_stock[id], 0)
		_nudge.text = "Depoda %d teçhizat   [B] Yerleştir" % count
	if not on:
		if _ghost:
			_ghost.visible = false
		_set_aimed(null)
		return
	var cam := get_viewport().get_camera_3d()
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * REACH)
	if cam.owner is CollisionObject3D:
		q.exclude = [(cam.owner as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_set_aimed(_placed_piece(hit.get("collider")))

	# Taking a piece down: hold X on it.
	if _aimed and Input.is_physical_key_pressed(KEY_X):
		_hold += delta
		if _hold >= REMOVE_HOLD:
			GameState.request_remove_gear(int(String(_aimed.name).trim_prefix("Gear_")))
			_hold = 0.0
	else:
		_hold = 0.0
	_hold_fill.size.x = _hold_fill.get_parent().size.x * clampf(_hold / REMOVE_HOLD, 0.0, 1.0)

	# Putting one up: the stock piece follows the look.
	var id := ""
	if not stock.is_empty():
		_pick = posmod(_pick, stock.size())
		id = stock[_pick]
		if id != _ghost_id:
			if _ghost:
				_ghost.queue_free()
			_ghost = _make_ghost(id)
			_ghost_id = id
			add_child(_ghost)
	elif _ghost:
		_ghost.queue_free()
		_ghost = null
		_ghost_id = ""
	var floor_hit: bool = not hit.is_empty() and hit.normal.y > 0.7 and not _aimed
	_spot_ok = false
	if _ghost:
		_ghost.visible = floor_hit
		if floor_hit:
			_spot = hit.position
			_spot_ok = GameState.can_place(id, _spot)
			_ghost.global_position = _spot
			_ghost.rotation.y = _yaw
			_tint(_ghost, OK_COLOR if _spot_ok else BAD_COLOR)

	# What the banner and the key row say.
	if _aimed:
		_banner_sub.text = "%s  ·  kurulu" % GameState.GEAR[_aimed.get_meta("gear")].name
		_banner_sub.modulate = Color.WHITE
	elif id != "":
		_banner_sub.text = "%s  ·  depoda %d" % [GameState.GEAR[id].name, GameState.gear_stock[id]]
		_banner_sub.modulate = Color.WHITE if _spot_ok or not floor_hit else RED
		if floor_hit and not _spot_ok:
			_banner_sub.text += "  ·  buraya yerleştirilemez"
	else:
		_banner_sub.text = "Depo boş  ·  teçhizat için [Q]"
		_banner_sub.modulate = DIM
	_show_key("place", id != "" and not _aimed, _spot_ok)
	_show_key("turn", id != "" and not _aimed, true)
	_show_key("pick", stock.size() > 1 and not _aimed, true)
	_show_key("remove", true, _aimed != null)


## The placed piece a collider belongs to, if any (only pieces under this node, not fixed targets).
func _placed_piece(collider: Object) -> Node3D:
	var n := collider as Node
	while n and n.get_parent() != self:
		n = n.get_parent()
	return n as Node3D if n and String(n.name).begins_with("Gear_") else null


func _set_aimed(piece: Node3D) -> void:
	if piece == _aimed:
		return
	if is_instance_valid(_aimed):
		_overlay(_aimed, null)
	_aimed = piece
	_hold = 0.0
	if piece:
		if not piece.has_meta("gear"):
			var n := int(String(piece.name).trim_prefix("Gear_"))
			piece.set_meta("gear", GameState.placed[n][0] if n < GameState.placed.size() and GameState.placed[n] else "dummy")
		_overlay(piece, _mark_mat)


static func _overlay(piece: Node, mat: Material) -> void:
	for m: GeometryInstance3D in piece.find_children("*", "GeometryInstance3D", true, false):
		m.material_overlay = mat


# --- others' previews -------------------------------------------------------------------------

## Someone else's preview: a faint copy in their colour; id "" takes it away.
func _on_preview(peer: int, id: String, pos: Vector3, yaw: float) -> void:
	if id == "" or not GameState.GEAR.has(id):
		_drop_other(peer)
		return
	var o: Dictionary = _others.get(peer, {})
	if o.is_empty() or o.id != id:
		_drop_other(peer)
		var g := _make_ghost(id)
		_tint(g, Color(GameState.color_of(peer), OTHERS_ALPHA))
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


# --- HUD --------------------------------------------------------------------------------------

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 3
	add_child(hud)
	# Banner: what mode this is and what is in hand.
	_banner = PanelContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 18
	_banner.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.08, 0.82), Color(GOLD, 0.6), 18, 10))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_banner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_banner.add_child(col)
	var title := _label("YERLEŞTİRME MODU", 22, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_banner_sub = _label("", 16, Color.WHITE)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_banner_sub)
	# Key row: one prompt per action; the ones that do nothing right now dim or hide.
	_bar = HBoxContainer.new()
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.offset_bottom = -26
	_bar.add_theme_constant_override("separation", 26)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_bar)
	for k in [["place", "Sol Tık", "Yerleştir"], ["turn", "R", "Döndür"], ["pick", "Tekerlek", "Seç"],
			["remove", "X", "Basılı tut: Kaldır"], ["exit", "B", "Çık"]]:
		var row := _key_prompt(k[1], k[2])
		_bar.add_child(row)
		_keys[k[0]] = row
	# The hold bar sits under X.
	var cap: Control = (_keys.remove as Control).get_child(0)
	_hold_fill = ColorRect.new()
	_hold_fill.color = RED
	_hold_fill.position = Vector2(0, 0)
	_hold_fill.size = Vector2(0, 3)
	_hold_fill.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hold_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(_hold_fill)
	# Outside the mode: a quiet reminder that something waits in the stock.
	_nudge = _label("", 16, GOLD)
	_nudge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_nudge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_nudge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_nudge.offset_bottom = -30
	_nudge.add_theme_constant_override("outline_size", 6)
	_nudge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hud.add_child(_nudge)


func _key_prompt(key: String, action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := _label(key, 15, Color.WHITE)
	cap.add_theme_stylebox_override("normal", _box(Color(0.12, 0.13, 0.16, 0.92), Color(1, 1, 1, 0.55), 9, 3))
	cap.clip_contents = true
	row.add_child(cap)
	var text := _label(action, 17, Color.WHITE)
	text.add_theme_constant_override("outline_size", 6)
	text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	row.add_child(text)
	return row


func _show_key(action: String, shown: bool, live: bool) -> void:
	var row: Control = _keys[action]
	row.visible = shown
	row.modulate = Color.WHITE if live else Color(1, 1, 1, 0.38)


static func _box(bg: Color, border: Color, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(6)
	b.content_margin_left = pad_x
	b.content_margin_right = pad_x
	b.content_margin_top = pad_y
	b.content_margin_bottom = pad_y
	return b


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
