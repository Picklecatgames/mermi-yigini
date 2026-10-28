extends Node3D
## Gear in the world (yol haritası 10). Every machine builds each piece the host lets up here, as
## Gear_<n> in placement order, so shot and cue events find it by the same path everywhere.
## Placement mode (B, or buying gear in the workshop): the player stands still behind the railing
## (player.gd) and the view cuts to a bird's-eye camera over the range, with the roof, lamps and the
## bay's lid left out (GameState.OVERHEAD_LAYER) so it reads like a plan. The mouse is free: a
## see-through copy of the chosen piece follows the cursor on a half-metre grid, left click puts it
## up, right click on a placed piece takes it back to the stock, R turns, F puts the whole stock up,
## holding X takes everything down; WASD pans, the wheel zooms, B or Esc goes back. The floor shows
## where gear may go (green), and a red disc round every target already up. On the right, the team's
## stock: one card per kind owned, how many wait and how many are up; a kind that is all up fades.
## Others see the copy faint, in the placer's colour. Everything goes through the host's
## request_place_gear / request_remove_gear, so co-op needs nothing more. Later turrets and belts
## use the same code.

const SNAP := 0.5            # m grid the copy sits on; the zone draws a line every other step
const MAX_SHOWN := 32        # targets the zone can draw a keep-off disc round
const TURN := PI / 4.0       # R turns by this
const CLEAR_HOLD := 0.8      # s X is held to take everything down
const SEND_EVERY := 0.1      # s between preview updates to the others
const GHOST_STALE := 1.5     # s without word before someone else's preview goes
const VIEW_TILT := 1.2       # rad the overview looks down from level (~69°)
const VIEW_HEIGHT := Vector2(9.0, 34.0)  # m, zoomed in .. out
const VIEW_FOCUS := Rect2(14.0, -27.0, 28.0, 50.0)  # where the overview may look (x, z)
const VIEW_FOV := 55.0
const VIEW_EASE := 12.0      # 1/s: the cut from the eyes settles in about a quarter second
const PAN_SPEED := 22.0      # m/s, zoomed all the way out
const OK_COLOR := Color(0.35, 1.0, 0.45, 0.38)
const BAD_COLOR := Color(1.0, 0.3, 0.28, 0.38)
const OTHERS_ALPHA := 0.16
const RED := Color(1.0, 0.38, 0.33)

var _pick_id := ""           # GEAR id in hand
var _yaw := -PI / 2.0        # facing west, at the shooters, like the fixed targets
var _ghost: Node3D
var _ghost_id := ""
var _spot := Vector3.ZERO
var _spot_ok := false
var _aimed: Node3D           # placed piece under the cursor
var _clear_hold := 0.0       # s X has been held
var _send_in := 0.0
var _sent_id := ""
var _others := {}            # peer -> {node, id, seen}
var _mark_mat := StandardMaterial3D.new()  # red over a piece under the cursor
var _zone: MeshInstance3D
# Overview
var _cam: Camera3D
var _eyes: Camera3D          # the player's camera, back when placement ends
var _focus := Vector2(25.0, -2.5)
var _height := 30.0
var _overhead: Array[RID] = []  # bodies the cursor's ray looks through (bay lid, baffles)
# HUD
var _banner: Control
var _banner_sub: Label
var _bar: Control
var _keys := {}              # action -> prompt row
var _hold_fill: ColorRect
var _nudge: HBoxContainer    # outside placement mode, when something waits in the stock
var _panel: Control
var _cards: VBoxContainer


func _ready() -> void:
	add_to_group("placement")
	_mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_mat.albedo_color = Color(RED, 0.35)
	GameState.gear_placed.connect(_put_up)
	GameState.gear_removed.connect(_take_down)
	GameState.preview_received.connect(_on_preview)
	GameState.placing_changed.connect(_on_placing)
	GameState.gear_changed.connect(_refresh_panel.unbind(1))
	for n in GameState.placed.size():  # already up (scene reloaded)
		if GameState.placed[n]:
			_put_up.callv([n] + GameState.placed[n])
	_cam = Camera3D.new()
	_cam.name = "Overview"
	_cam.top_level = true
	_cam.fov = VIEW_FOV
	_cam.cull_mask = 0xFFFFF & ~(1 << 1) & ~(1 << (GameState.OVERHEAD_LAYER - 1))  # no gun, no roof
	add_child(_cam)
	_build_hud()
	_build_zone()
	_refresh_panel()


## Workshop: a piece was just bought; have it ready in hand.
func focus(id: String) -> void:
	_pick_id = id
	_refresh_panel()


## Into placement mode: cut to the overview, free the mouse. Out: back to the eyes.
func _on_placing(on: bool) -> void:
	if on:
		_eyes = get_viewport().get_camera_3d()
		if _eyes and _eyes != _cam:
			_cam.global_transform = _eyes.global_transform  # the ease starts from the eyes
		_cam.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_overhead.clear()
		for body: Node in get_tree().get_nodes_in_group("overhead"):
			if body is CollisionObject3D:
				_overhead.append((body as CollisionObject3D).get_rid())
		_refresh_panel()
	else:
		if is_instance_valid(_eyes) and _eyes != _cam:
			_eyes.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_clear_hold = 0.0


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
	_refresh_panel()


## Everyone: a piece the host took down.
func _take_down(n: int) -> void:
	var node := get_node_or_null("Gear_%d" % n)
	if node:
		if node == _aimed:
			_aimed = null
		node.queue_free()
	_refresh_panel()


## How many of each kind are up, from GameState.placed.
func _placed_counts() -> Dictionary:
	var up := {}
	for p in GameState.placed:
		if p:
			up[p[0]] = up.get(p[0], 0) + 1
	return up


## Kinds the team owns (waiting or up), in the workshop's order.
func _owned() -> Array:
	var up := _placed_counts()
	return GameState.GEAR.keys().filter(func(id: String) -> bool: return GameState.gear_stock.get(id, 0) + up.get(id, 0) > 0)


func _placing() -> bool:
	return GameState.player().placing


func _unhandled_input(event: InputEvent) -> void:
	if not _placing():
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				_height = clampf(_height + (2.5 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -2.5), VIEW_HEIGHT.x, VIEW_HEIGHT.y)
			MOUSE_BUTTON_LEFT:
				if _spot_ok and not _aimed:
					GameState.request_place_gear(_ghost_id, _spot, _yaw)
			MOUSE_BUTTON_RIGHT:
				if _aimed:
					GameState.request_remove_gear(_index_of(_aimed))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reload"):
		_yaw = wrapf(_yaw + TURN, -PI, PI)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		GameState.request_toggle_placing()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		var owned := _owned()
		if key >= KEY_1 and key < KEY_1 + mini(owned.size(), 9):
			_pick_id = owned[key - KEY_1]
			_refresh_panel()
			get_viewport().set_input_as_handled()
		elif key == KEY_F:
			_place_all()
			get_viewport().set_input_as_handled()


func _index_of(piece: Node) -> int:
	return int(String(piece.name).trim_prefix("Gear_"))


## F: the whole stock goes up in tidy rows, nearest the railing first, centre outward; each piece
## is a separate request the host checks, so in co-op it is the same as clicking them one by one.
func _place_all() -> void:
	var taken: Array[Vector3] = []  # asked for here, not up yet on a client
	var zs: Array[float] = [0.0]
	for k in range(1, 10):
		zs.append_array([-2.5 * k, 2.5 * k])
	for id: String in GameState.GEAR:
		for k in GameState.gear_stock.get(id, 0):
			var spot := Vector3.INF
			for x in [18.0, 21.5, 25.0, 29.0, 33.0, 37.0]:
				for z in zs:
					var p := Vector3(x, 0, z)
					if GameState.can_place(id, p) and taken.all(func(t: Vector3) -> bool: return t.distance_to(p) >= GameState.PLACE_GAP):
						spot = p
						break
				if spot != Vector3.INF:
					break
			if spot == Vector3.INF:
				return  # the range is full
			GameState.request_place_gear(id, spot, -PI / 2.0)
			taken.append(spot)


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


## WASD pans the overview (W away from the railing), the wheel set its height; it eases there.
func _move_view(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_focus += Vector2(-input.y, input.x) * PAN_SPEED * (_height / VIEW_HEIGHT.y) * delta
	_focus = _focus.clamp(VIEW_FOCUS.position, VIEW_FOCUS.end)
	var look := Vector3(_focus.x, 0.0, _focus.y)
	var from := look + Vector3(-_height / tan(VIEW_TILT), _height, 0.0)
	var want := Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	var t := 1.0 - exp(-VIEW_EASE * delta)
	_cam.global_transform = _cam.global_transform.interpolate_with(want, t)
	_cam.fov = lerpf(_cam.fov, VIEW_FOV, t)


func _update_own(delta: float) -> void:
	var on := _placing()
	var stock_total := 0
	for id: String in GameState.gear_stock:
		stock_total += GameState.gear_stock[id]
	_banner.visible = on
	_bar.visible = on
	_panel.visible = on
	_zone.visible = on
	_nudge.visible = not on and stock_total > 0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _nudge.visible:
		(_nudge.get_child(0) as Label).text = "Depoda %d teçhizat var, kurmak için" % stock_total
	if not on:
		if _ghost:
			_ghost.visible = false
		_set_aimed(null)
		return
	_move_view(delta)

	# The cursor: a ray for placed pieces (through the bay's lid), the floor plane for the spot.
	var mouse := get_viewport().get_mouse_position()
	var origin := _cam.project_ray_origin(mouse)
	var dir := _cam.project_ray_normal(mouse)
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 150.0)
	q.collision_mask = 0xFFFFFFFF & ~(1 << (GameState.FENCE_LAYER - 1))
	var skip := _overhead.duplicate()
	var cam_owner := _eyes.owner if is_instance_valid(_eyes) else null
	if cam_owner is CollisionObject3D:
		skip.append((cam_owner as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_set_aimed(null if over_ui else _placed_piece(hit.get("collider")))
	var ground: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)

	# Holding X takes everything down.
	if Input.is_physical_key_pressed(KEY_X):
		_clear_hold += delta
		if _clear_hold >= CLEAR_HOLD:
			for n in GameState.placed.size():
				if GameState.placed[n]:
					GameState.request_remove_gear(n)
			_clear_hold = -INF  # once per hold
	else:
		_clear_hold = 0.0
	_hold_fill.size.x = _hold_fill.get_parent().size.x * clampf(_clear_hold / CLEAR_HOLD, 0.0, 1.0)

	# The piece in hand follows the cursor.
	if GameState.gear_stock.get(_pick_id, 0) <= 0:  # used up: the next kind still waiting
		for id: String in GameState.GEAR:
			if GameState.gear_stock.get(id, 0) > 0:
				_pick_id = id
				_refresh_panel()
				break
	var id := _pick_id if GameState.gear_stock.get(_pick_id, 0) > 0 else ""
	if id != _ghost_id:
		if _ghost:
			_ghost.queue_free()
			_ghost = null
		if id != "":
			_ghost = _make_ghost(id)
			add_child(_ghost)
		_ghost_id = id
	var on_floor: bool = ground != null and not _aimed and not over_ui
	_spot_ok = false
	var problem := ""
	if _ghost:
		_ghost.visible = on_floor
		if on_floor:
			var at: Vector3 = ground
			_spot = Vector3(snappedf(at.x, SNAP), 0.0, snappedf(at.z, SNAP))
			problem = GameState.place_problem(id, _spot)
			_spot_ok = problem == ""
			_ghost.global_position = _spot
			_ghost.rotation.y = _yaw
			_tint(_ghost, OK_COLOR if _spot_ok else BAD_COLOR)
	_update_zone(_spot_ok)

	# What the banner and the key row say.
	if _aimed:
		_banner_sub.text = "%s kurulu. Sağ tık kaldırır." % GameState.GEAR[_aimed.get_meta("gear")].name
		_banner_sub.modulate = Color.WHITE
	elif id != "":
		_banner_sub.text = "%s, depoda %d" % [GameState.GEAR[id].name, GameState.gear_stock[id]]
		_banner_sub.modulate = Color.WHITE if _spot_ok or not on_floor else UiStyle.WARN
		if on_floor and not _spot_ok:
			_banner_sub.text += ". " + problem[0].to_upper() + problem.substr(1)
	else:
		_banner_sub.text = "Depo boş. Teçhizat almak için Q."
		_banner_sub.modulate = UiStyle.DIM
	var up := not GameState.placed.all(func(p: Variant) -> bool: return p == null)
	_show_key("place", id != "", _spot_ok and not _aimed)
	_show_key("remove", true, _aimed != null)
	_show_key("turn", id != "", true)
	_show_key("pick", _owned().size() > 1, true)
	_show_key("all", stock_total > 0, true)
	_show_key("clear", up, true)


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
	if piece:
		if not piece.has_meta("gear"):
			var n := _index_of(piece)
			piece.set_meta("gear", GameState.placed[n][0] if n < GameState.placed.size() and GameState.placed[n] else "dummy")
		_overlay(piece, _mark_mat)


static func _overlay(piece: Node, mat: Material) -> void:
	for m: GeometryInstance3D in piece.find_children("*", "GeometryInstance3D", true, false):
		m.material_overlay = mat


# --- the zone on the floor --------------------------------------------------------------------

## Where gear may go, drawn on the floor in placement mode (GameState.PLACE_ZONES): a faint green
## field with a 1 m grid and a bright, slowly breathing edge round the whole shape; a red disc
## round every target already up (GameState.PLACE_GAP, the closest a new one may stand) and a
## ring under the copy, green or red.
func _build_zone() -> void:
	var bounds := GameState.PLACE_ZONES[0]
	var rects := PackedVector4Array()
	for r in GameState.PLACE_ZONES:
		bounds = bounds.merge(r)
		rects.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	var plane := PlaneMesh.new()
	plane.size = bounds.size
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color;
uniform vec4 bad : source_color;
uniform vec4 rects[%d];  // x, z, width, depth
uniform vec2 targets[%d];
uniform int target_count;
uniform float gap;
uniform vec4 cursor;  // x, z, ring radius (< 0: none), 1 if it may go there
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float box(vec2 p, vec4 r) {
	vec2 d = abs(p - r.xy - r.zw * 0.5) - r.zw * 0.5;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
void fragment() {
	vec2 p = world.xz;
	float d = 1e6;
	for (int i = 0; i < rects.length(); i++) {
		d = min(d, box(p, rects[i]));
	}
	if (d > 0.0) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.0, 0.1, -d);
	vec2 cell = abs(fract(p) - 0.5);
	float grid = step(0.475, max(cell.x, cell.y));  // 5 cm lines on every metre
	float near = 0.0;
	for (int i = 0; i < target_count; i++) {
		float r = length(p - targets[i]);
		near = max(near, 1.0 - smoothstep(gap - 0.06, gap, r));
		near = max(near, (1.0 - smoothstep(0.0, 0.05, abs(r - gap))) * 1.6);  // its rim
	}
	vec3 col = mix(tint.rgb, bad.rgb, clamp(near, 0.0, 1.0));
	float a = tint.a * (0.16 + grid * 0.25) + edge * (0.55 + 0.25 * sin(TIME * 3.0));
	a = mix(a, 0.3, clamp(near, 0.0, 1.0)) + max(near - 1.0, 0.0) * 0.6;
	float ring = 1.0 - smoothstep(0.0, 0.05, abs(length(p - cursor.xy) - cursor.z));
	col = mix(col, mix(bad.rgb, tint.rgb, cursor.w), ring);
	ALBEDO = col;
	ALPHA = clamp(max(a, ring * 0.9), 0.0, 1.0);
}
""" % [rects.size(), MAX_SHOWN]
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", Color(0.35, 1.0, 0.45, 0.6))
	mat.set_shader_parameter("bad", Color(1.0, 0.3, 0.28))
	mat.set_shader_parameter("rects", rects)
	mat.set_shader_parameter("gap", GameState.PLACE_GAP)
	plane.material = mat
	_zone = MeshInstance3D.new()
	_zone.mesh = plane
	_zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_zone.position = Vector3(bounds.get_center().x, 0.015, bounds.get_center().y)
	_zone.visible = false
	add_child(_zone)


## Feeds the zone shader the targets now up and where the copy stands.
func _update_zone(ok: bool) -> void:
	var mat := (_zone.mesh as PlaneMesh).material as ShaderMaterial
	var targets := get_tree().get_nodes_in_group("target")
	var spots := PackedVector2Array()
	for t: Node in targets:
		if spots.size() < MAX_SHOWN:
			var at := (t as Node3D).global_position
			spots.append(Vector2(at.x, at.z))
	spots.resize(MAX_SHOWN)  # the array uniform wants every slot
	mat.set_shader_parameter("targets", spots)
	mat.set_shader_parameter("target_count", mini(targets.size(), MAX_SHOWN))
	var shown := _ghost != null and _ghost.visible
	mat.set_shader_parameter("cursor", Vector4(_spot.x, _spot.z, GameState.PLACE_ROOM if shown else -1.0, 1.0 if ok else 0.0))


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
## Many pieces (pendulum, bank-shot plate, popper) build their meshes in _ready, so the original
## enters the tree for a moment, hidden and still, and is freed before the frame ends.
func _make_ghost(id: String) -> Node3D:
	var src: Node3D = load(GameState.GEAR[id].scene).instantiate()
	src.process_mode = Node.PROCESS_MODE_DISABLED
	src.visible = false
	add_child(src)
	var ghost := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.set_meta("mat", mat)
	for m: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		if not m.mesh:
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = m.mesh
		copy.transform = src.global_transform.affine_inverse() * m.global_transform  # its place under the piece's root
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
	src.free()
	return ghost


func _tint(ghost: Node3D, color: Color) -> void:
	(ghost.get_meta("mat") as StandardMaterial3D).albedo_color = color


# --- HUD --------------------------------------------------------------------------------------

## In UiStyle: the mode and what is in hand top centre under the heap's line, the keys as key
## caps along the bottom on a dark strip, the team's stock as a panel on the right.
func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 3
	add_child(hud)
	# Banner: what mode this is and what is in hand.
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.offset_top = 28  # hud.gd MARGIN; the heap's count sits in the top left now
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(col)
	_banner = col
	col.add_child(_centred(UiStyle.display("Yerleştirme modu", 26, UiStyle.BOLD, UiStyle.ACCENT)))
	_banner_sub = _centred(UiStyle.label("", 16, UiStyle.MEDIUM))
	col.add_child(_banner_sub)
	# Key row: one prompt per action; the ones that do nothing right now dim or hide.
	_bar = UiStyle.panel(10, 6)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.offset_bottom = -24
	hud.add_child(_bar)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 22)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(keys)
	for k in [["place", ["Sol tık"], "Yerleştir"], ["remove", ["Sağ tık"], "Kaldır"], ["turn", ["R"], "Döndür"],
			["pick", ["1-9"], "Seç"], ["all", ["F"], "Hepsini kur"], ["clear", ["X"], "Basılı tut: hepsini kaldır"],
			["view", ["W", "A", "S", "D", "Tekerlek"], "Kamera"], ["exit", ["B"], "Çık"]]:
		var row := UiStyle.hint(k[1], k[2])
		keys.add_child(row)
		_keys[k[0]] = row
	# The hold line fills under X's words.
	var under := UiStyle.line(0)
	under.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	under.offset_top = 4
	under.offset_bottom = 5
	(_keys.clear as Control).get_child(1).add_child(under)  # under the words, not a third item in the row
	_hold_fill = ColorRect.new()
	_hold_fill.color = UiStyle.ACCENT
	_hold_fill.size = Vector2(0, 1)
	_hold_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.add_child(_hold_fill)
	# The team's stock, on the right.
	var box := UiStyle.panel(14, 6)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.offset_right = -36  # hud.gd MARGIN
	box.custom_minimum_size.x = 270
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	hud.add_child(box)
	_panel = box
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stack)
	stack.add_child(UiStyle.display("Depo", 22, UiStyle.BOLD))  # bought at the bench
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 0)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_cards)
	# Outside the mode: a quiet reminder that something waits in the stock, over the guns.
	_nudge = UiStyle.hint("B", "")
	var nudge_text := UiStyle.label("", 14, UiStyle.SEMIBOLD, UiStyle.ACCENT)
	nudge_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_nudge.add_child(nudge_text)
	_nudge.move_child(nudge_text, 0)  # the words, then the key
	_nudge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_nudge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_nudge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_nudge.offset_bottom = -132
	hud.add_child(_nudge)


## One row per kind the team owns, a rule over each: its key, name, how many wait and how many
## are up. The one in hand has its name in the accent; a kind with none left waiting fades.
## Click a row to pick.
func _refresh_panel() -> void:
	if not _cards:
		return
	for c in _cards.get_children():
		c.queue_free()
	var up := _placed_counts()
	var owned := _owned()
	if owned.is_empty():
		_cards.add_child(UiStyle.line())
		var empty := UiStyle.label("Depo boş", 15, UiStyle.REGULAR, UiStyle.DIM)
		empty.custom_minimum_size.y = 44
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cards.add_child(empty)
		_cards.add_child(UiStyle.line())
		return
	for i in owned.size():
		var id: String = owned[i]
		var waiting: int = GameState.gear_stock.get(id, 0)
		var used: int = up.get(id, 0)
		var picked := id == _pick_id and waiting > 0
		_cards.add_child(UiStyle.line())
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 52
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.modulate.a = 1.0 if waiting > 0 else 0.42
		row.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and GameState.gear_stock.get(id, 0) > 0:
				_pick_id = id
				_refresh_panel())
		_cards.add_child(row)
		if i < 9:
			row.add_child(UiStyle.keycap(str(i + 1), 13, UiStyle.ACCENT if picked else UiStyle.WHITE))
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(UiStyle.display(GameState.GEAR[id].name, 20, UiStyle.SEMIBOLD, UiStyle.ACCENT if picked else UiStyle.WHITE))
		text.add_child(UiStyle.label("Hepsi kurulu" if waiting == 0 else "%d kurulu" % used if used > 0 else "Henüz kurulmadı", 13, UiStyle.MEDIUM, UiStyle.DIM))
		var count := UiStyle.display("×%d" % waiting, 26, UiStyle.SEMIBOLD)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(count)
	_cards.add_child(UiStyle.line())


func _show_key(action: String, shown: bool, live: bool) -> void:
	var row: Control = _keys[action]
	row.visible = shown
	row.modulate.a = 1.0 if live else 0.38


static func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
