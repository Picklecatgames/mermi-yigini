extends CanvasLayer
## What the hopper's and the press's screens share (melter_menu.gd, press_menu.gd), in the bench's
## way (bench_menu.gd): the view leaves the player's eyes for a camera on the machine, the HUD and
## the hands go, and the machine stays in sight on the left of the screen. Its name and numbers top
## left, what it sells in cards on the right under the money that pays for it (the vault in co-op,
## else one's own gold). E or Esc closes it.

const FLY_TIME := 0.6  # s between the player's eyes and the machine's camera
const FOV := 50.0

var _cam := Camera3D.new()
var _ui := Control.new()
var _left := VBoxContainer.new()
var _right := VBoxContainer.new()
var _money: Label
var _money_icon: TextureRect
var _fly: Tween
var _fade: Tween
var _closing := false


## The machine's camera, world space: where it stands and what it looks at.
func _view() -> Array:
	return [Vector3.ZERO, Vector3.FORWARD]


## Builds the frame: `title` top left over `_left`, the money top right over `_right`, the keys
## at the foot.
func _build_frame(title: String) -> void:
	layer = 5
	visible = false
	_cam.top_level = true  # else it rides along with the player we hang under
	add_child(_cam)
	add_child(_ui)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.fit_screen(_ui)
	_left.position = Vector2(56, 64)
	_left.custom_minimum_size.x = 340
	_left.add_theme_constant_override("separation", 10)
	_ui.add_child(_left)
	_left.add_child(UiStyle.display(title, 46, UiStyle.BOLD, UiStyle.ACCENT))
	_left.add_child(UiStyle.line(340))
	_right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_right.offset_left = -456
	_right.offset_right = -56
	_right.offset_top = 64
	_right.add_theme_constant_override("separation", 12)
	_ui.add_child(_right)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_END
	head.add_theme_constant_override("separation", 10)
	_right.add_child(head)
	_money_icon = UiStyle.icon("crate", 30, UiStyle.MONEY)
	head.add_child(_money_icon)
	_money = UiStyle.display("", 40, UiStyle.SEMIBOLD, UiStyle.MONEY)
	head.add_child(_money)
	_right.add_child(UiStyle.line())
	var foot := HBoxContainer.new()
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_top = -64
	foot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	foot.add_child(UiStyle.hint(["ESC", "E"], ""))
	_ui.add_child(foot)
	for s: StringName in [&"gold_changed", &"vault_changed"]:
		GameState.connect(s, func(_v: Variant) -> void:
			if visible:
				_refresh())
	GameState.melter_changed.connect(func(_b: int, _r: int, _m: int, _p: int) -> void:
		if visible:
			_refresh())


func _refresh() -> void:
	var vault := GameState.team_vault()
	_money_icon.visible = vault  # the team's money; alone it is one's own
	_money.text = "$" + UiStyle.dotted(int(GameState.vault) if vault else GameState.gold)


## What pays for the machine's upgrades now.
func _have() -> float:
	return GameState.vault if GameState.team_vault() else float(GameState.gold)


func open() -> void:
	visible = true
	_closing = false
	_hide_player(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	var eye := _eye()
	if eye == null:
		return  # no body to fly from (headless checks)
	_cam.global_transform = eye.global_transform
	_cam.fov = eye.fov
	_cam.cull_mask = eye.cull_mask  # not our own body and hands
	_cam.make_current()
	var view := _view()
	var to := Transform3D(Basis.looking_at(view[1] - view[0]), view[0])
	var fly := _new_tweens()
	fly.tween_property(_cam, "global_transform", to, FLY_TIME)
	fly.tween_property(_cam, "fov", FOV, FLY_TIME)
	_ui.modulate.a = 0.0
	_fade.tween_property(_ui, "modulate:a", 1.0, 0.3).set_delay(FLY_TIME * 0.5)


func close() -> void:
	if _closing or not visible:
		return
	_closing = true
	var eye := _eye()
	if eye:
		var fly := _new_tweens()
		_fade.tween_property(_ui, "modulate:a", 0.0, 0.2)
		fly.tween_property(_cam, "global_transform", eye.global_transform, FLY_TIME * 0.8)
		fly.tween_property(_cam, "fov", eye.fov, FLY_TIME * 0.8)
		await fly.finished
		eye.make_current()
	_hide_player(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visible = false


func _eye() -> Camera3D:
	return get_parent().get_node_or_null("Head/Camera3D")


func _hide_player(hide: bool) -> void:
	for path in ["HUD", "ViewmodelView"]:
		var n := get_parent().get_node_or_null(path)
		if n:
			n.visible = not hide


## Fresh camera and UI tweens; the old ones die, so an Esc right after E doesn't flash the UI back.
func _new_tweens() -> Tween:
	for t: Tween in [_fly, _fade]:
		if t:
			t.kill()
	_fly = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fade = create_tween()
	return _fly


func _input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pick_up"):
		close()
	if event is InputEventKey:
		get_viewport().set_input_as_handled()  # no walking, guns, Q or B behind it


## A click the cards let pass would reach player.gd, which takes the mouse back into the game.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


# --- the pieces ---------------------------------------------------------------------------------

## A card on the right: the machine's own green paint (UiStyle.machine_card), `pad` px inside.
func _card(key: Variant = 0, pad := 20) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.machine_card(key, pad))
	return card


## A card's name, what it does under it, and a line for its numbers (returned, filled later).
func _card_words(parent: Control, title: String, what: String) -> Label:
	var about := VBoxContainer.new()
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.add_theme_constant_override("separation", 0)
	parent.add_child(about)
	about.add_child(UiStyle.display(title, 26, UiStyle.BOLD))
	if what != "":
		var l := UiStyle.label(what, 14, UiStyle.REGULAR, UiStyle.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.add_child(l)
	var state := UiStyle.label("", 15, UiStyle.MEDIUM, UiStyle.ACCENT)
	about.add_child(state)
	return state


## A stamped brass button (UiStyle.brass_button): a price in reach, the machine's main act; dark
## steel when it can't be had.
func _price_button(size := Vector2(130, 50), font := 22, key: Variant = 0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = size
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD, 0, true))
	b.add_theme_font_size_override("font_size", font)
	UiStyle.brass_button(b, key)
	return b


## A plain steel button (−, +, HEPSİ).
func _step_button(text: String, width := 48.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(width, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD, 0, true))
	b.add_theme_font_size_override("font_size", 24)
	UiStyle.plate_button(b, text, UiStyle.PLATE_GREY)
	for s: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(s, UiStyle.WHITE)
	return b


## A number beside the thing it counts (UiStyle.item), its small caption over it if it has one,
## for the left column.
func _stat(parent: Control, caption: String, item: String, color: Color) -> Label:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)
	if caption != "":
		col.add_child(UiStyle.label(caption, 15, UiStyle.MEDIUM, UiStyle.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	row.add_child(UiStyle.item(item, 46))
	var n := UiStyle.display("", 40, UiStyle.BOLD, color)
	row.add_child(n)
	return n


## The set's arrow, turned to point right in its file: "this becomes that".
func _arrow(size: float, color: Color) -> TextureRect:
	return UiStyle.icon("arrow", size, color)


## Level boxes: lit up to `level`, of `count`.
func _pips(parent: HBoxContainer, level: int, count: int) -> void:
	for c: Node in parent.get_children():
		c.queue_free()
	for i in count:  # steel studs (UiStyle.pip), the had ones brass
		parent.add_child(UiStyle.pip(i, UiStyle.BRASS if i <= level else Color(0.32, 0.33, 0.32), 14))


## 2.0 -> "2", 0.5 -> "0,5"
static func num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else String.num(x, 1).replace(".", ",")
