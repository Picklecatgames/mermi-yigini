extends CanvasLayer
## Who to play as (GameState.CHARACTERS, 2026-10-30, the user's call): open whenever the local
## player has none, so at the start and on joining someone's session (a new id there). Six steel
## cards, each with the body itself standing in its own little lit world, its name stencilled under
## it; the one under the mouse raises its gun. One each: a card someone else has is dark and carries
## their tag in their colour. A click or 1-6 asks the host (request_pick_character); it closes when
## the answer comes back. Drawn on a 1280x720 canvas scaled to the screen, as the pause menu.

const DESIGN := Vector2(1280, 720)
const REMOTE := preload("res://scripts/remote_players.gd")  # BODIES, ANIMS
const CARD := Vector2(196, 470)  # six side by side on the canvas
const GAP := 14.0
const TOP := 150.0  # px from the top to the cards
const VIEW := Vector2i(400, 720)  # px each body is rendered at
const FOV := 26.0  # degrees, vertical
const TURN := 0.45  # rad, the body's three-quarter turn toward the light
const SPIN := 0.25  # rad/s it turns while the mouse is over it
const TAKEN_TINT := Color(0.45, 0.45, 0.45)

var is_open := false
var _canvas: Control
var _cards := {}  # id -> {button, view, body, anim, tag, name}
var _asked := ""  # what we asked the host for, until it answers
var _hover := ""


func _ready() -> void:
	name = "CharacterPick"  # pause_menu.gd leaves Esc to us while we're open
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var back := UiStyle.backdrop()
	back.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing behind takes a click
	add_child(back)
	_canvas = Control.new()
	_canvas.size = DESIGN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	var title := UiStyle.stencil("KİMSİN?", 46)
	title.size = Vector2(DESIGN.x, 60)
	title.position = Vector2(0, TOP - 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas.add_child(title)
	var ids := GameState.CHARACTERS.keys()
	var left := (DESIGN.x - CARD.x * ids.size() - GAP * (ids.size() - 1)) / 2.0
	for i in ids.size():
		_card(ids[i], i, Vector2(left + i * (CARD.x + GAP), TOP))
	get_viewport().size_changed.connect(_fit)
	GameState.character_changed.connect(func(_p: int, _id: String) -> void: _refresh())
	GameState.player_slots.connect(func(_s: Dictionary) -> void: _refresh())
	_fit()
	_set_open(false)


func _fit() -> void:
	var s := get_viewport().get_visible_rect().size
	var k := minf(s.x / DESIGN.x, s.y / DESIGN.y)
	_canvas.scale = Vector2.ONE * k
	_canvas.position = ((s - DESIGN * k) / 2.0).floor()


## One card: the plate, the key that picks it, the body in its own world, the name, and the tag of
## whoever has it.
func _card(id: String, i: int, at: Vector2) -> void:
	var b := Button.new()
	b.position = at
	b.size = CARD
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UiStyle.plate("card", id, UiStyle.PLATE_GREY, 10))
	b.add_theme_stylebox_override("hover", UiStyle.plate("card", id, UiStyle.PLATE_GREY.lightened(0.25), 10))
	b.add_theme_stylebox_override("pressed", UiStyle.plate("card", id, UiStyle.PLATE_GREY.lightened(0.4), 10))
	b.add_theme_stylebox_override("disabled", UiStyle.plate("hazard", id, TAKEN_TINT, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_pick.bind(id))
	b.mouse_entered.connect(func() -> void: _hover = id)
	b.mouse_exited.connect(func() -> void:
		if _hover == id:
			_hover = "")
	_canvas.add_child(b)
	var view := SubViewport.new()
	view.size = VIEW
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	var shown := SubViewportContainer.new()
	shown.stretch = true
	shown.position = Vector2(10, 8)
	shown.size = Vector2(CARD.x - 20, CARD.y - 64)
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown.add_child(view)
	b.add_child(shown)
	var body := _stage(view, id)
	var key := UiStyle.keycap(str(i + 1), 13)
	key.position = Vector2(12, 10)
	b.add_child(key)
	var label := UiStyle.stencil(String(GameState.CHARACTERS[id]).to_upper(), 30)
	label.size = Vector2(CARD.x, 40)
	label.position = Vector2(0, CARD.y - 56)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(label)
	var tag := Label.new()  # whose it is, on a strip of their colour
	tag.add_theme_font_override("font", UiStyle.face(UiStyle.SEMIBOLD))
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(CARD.x - 40, 24)
	tag.position = Vector2(20, CARD.y - 96)
	tag.visible = false
	b.add_child(tag)
	_cards[id] = {"button": b, "view": view, "body": body, "anim": body.get_node("Anim"), "tag": tag, "name": label}


## The body standing in `view`'s own world: lit from the front left, a rim from behind, the camera
## fitting it head to toe.
func _stage(view: SubViewport, id: String) -> Node3D:
	var body: Node3D = REMOTE.BODIES[id].instantiate()
	body.rotation.y = TURN
	view.add_child(body)
	var skel: Skeleton3D = body.get_node("Skeleton3D")
	skel.motion_scale = skel.get_bone_global_rest(0).origin.y
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	body.add_child(ap)
	ap.root_node = ^".."
	ap.add_animation_library("", REMOTE.ANIMS)
	ap.play("idle")
	var tall := skel.get_bone_global_rest(skel.find_bone("mixamorig_HeadTop_End")).origin.y + 0.12
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.position = Vector3(0, tall * 0.5, tall * 0.5 / tan(deg_to_rad(FOV) * 0.5) * 1.08)
	view.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-30), deg_to_rad(-35), 0)
	key.light_energy = 1.6
	view.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-20), deg_to_rad(160), 0)
	rim.light_energy = 1.1
	rim.light_color = Color(1.0, 0.85, 0.6)  # the heap's brass catching the edge
	view.add_child(rim)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	view.add_child(world)
	return body


func _process(delta: float) -> void:
	var p = GameState.player()
	var want: bool = p != null and p.character == ""
	if want != is_open:
		_set_open(want)
	if not is_open:
		return
	for id: String in _cards:
		var c: Dictionary = _cards[id]
		var raised: bool = id == _hover and not c.button.disabled
		var clip := "pistol_idle" if raised else "idle"
		if c.anim.current_animation != clip:
			c.anim.play(clip, 0.25)
		c.body.rotation.y = c.body.rotation.y + SPIN * delta if raised else lerp_angle(c.body.rotation.y, TURN, 1.0 - exp(-delta * 4.0))


func _set_open(on: bool) -> void:
	is_open = on
	visible = on
	for c: Dictionary in _cards.values():
		c.view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		c.anim.active = on
	if on:
		_asked = ""
		_refresh()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif is_inside_tree():
		var p = GameState.player()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p and p.placing else Input.MOUSE_MODE_CAPTURED


## Whose each card is now: someone else's is shut, with their tag in their colour.
func _refresh() -> void:
	for id: String in _cards:
		var c: Dictionary = _cards[id]
		var owner := _owner_of(id)
		var taken := owner != 0 and owner != GameState.local_peer()
		c.button.disabled = taken
		c.button.modulate = Color.WHITE if not taken else Color(0.75, 0.75, 0.75)
		c.name.modulate = Color(1, 1, 1, 0.45) if taken else Color.WHITE
		c.tag.visible = taken
		if taken:
			c.tag.text = GameState.display_name(owner)
			var box := StyleBoxFlat.new()
			box.bg_color = GameState.color_of(owner)
			c.tag.add_theme_stylebox_override("normal", box)


func _owner_of(id: String) -> int:
	var here: Array = GameState.slots.keys() if not GameState.slots.is_empty() else [GameState.local_peer()]
	for peer: int in here:
		if GameState.player(peer).character == id:
			return peer
	return 0


func _pick(id: String) -> void:
	if not is_open or _asked != "" or GameState.character_taken(id):
		return
	_asked = id
	_refresh()
	GameState.request_pick_character(id)
	# The host may have given it to someone else a moment before: ask again then.
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_open and _asked == id:
			_asked = ""
			_refresh())


func _input(event: InputEvent) -> void:
	if not is_open or not event is InputEventKey:
		return
	var k := event as InputEventKey
	if k.pressed and not k.echo and k.physical_keycode >= KEY_1 and k.physical_keycode < KEY_1 + _cards.size():
		_pick(_cards.keys()[k.physical_keycode - KEY_1])
	get_viewport().set_input_as_handled()  # no walking, guns or menus behind it
