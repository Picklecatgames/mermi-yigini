extends Control
## The special rounds on screen (GameState.SPECIALS, UiStyle): the round picker and the "found one"
## note. Picker: hold R (player.gd) and the view dims, a row of columns comes up in the middle
## parted by thin rules: the plain round first, then each special in the pocket, every one its
## turning 3D model with name and count; the picked one is bright with a short accent rule and what
## it does, the rest faded. Moving the mouse sideways picks; letting R go loads it: a special becomes
## the next shot (request_arm_special), the plain round takes it back out.
## Note: picking up a special brings its model, name and use up top for a few seconds.

signal picked(id: String)  # "" for the plain round

const CASE := preload("res://assets/bullet/bullet_case.glb")
const PLAIN := preload("res://assets/bullet/bullet_9mm.glb")
const COLUMN := 190.0  # px
const MODEL_PX := 170
const PICK_STEP := 140.0  # px of mouse travel from one column to the next
const NOTE_TIME := 3.5  # s
const FADED := 0.38

var _dim: ColorRect
var _picker: VBoxContainer
var _row: HBoxContainer
var _ids: Array[String] = []
var _pick := 0
var _travel := 0.0
var _note: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()  # the view goes quiet behind the choice
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_picker = VBoxContainer.new()
	_picker.set_anchors_preset(Control.PRESET_CENTER)
	_picker.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_picker.grow_vertical = Control.GROW_DIRECTION_BOTH
	_picker.add_theme_constant_override("separation", 22)
	_picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picker.visible = false
	add_child(_picker)
	_picker.add_child(_centred(UiStyle.caption("mermi seç")))
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 0)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picker.add_child(_row)
	_picker.add_child(_centred(UiStyle.caption("fare ile kaydır  ·  R bırak")))


var is_open: bool:
	get: return _picker.visible


## Opens the picker on what is in the pocket now, the loaded one picked.
func open() -> void:
	var p := GameState.player()
	_ids.assign([""])
	for id: String in GameState.SPECIALS:
		if id in p.specials:
			_ids.append(id)
	for c in _row.get_children():
		c.free()
	for i in _ids.size():
		if i > 0:
			var rule := UiStyle.line()
			rule.custom_minimum_size = Vector2(1, 0)
			_row.add_child(rule)
		var id := _ids[i]
		_row.add_child(column(id, GameState.carried + GameState.loaded if id == "" else p.specials.count(id)))
	_pick = maxi(_ids.find(p.armed), 0)
	_travel = 0.0
	_picker.visible = true
	_dim.visible = true
	_light()


## Closes it and says what was picked.
func close() -> void:
	if not is_open:
		return
	_picker.visible = false
	_dim.visible = false
	picked.emit(_ids[_pick])


## Mouse travel while open (the view stays still).
func steer(dx: float) -> void:
	_travel += dx
	var step := roundi(_travel / PICK_STEP)
	if step != 0:
		_travel -= step * PICK_STEP
		_pick = clampi(_pick + step, 0, _ids.size() - 1)
		_light()


func _light() -> void:
	for i in _ids.size():
		var on := i == _pick
		var col := _row.get_child(i * 2) as Control  # rules sit between the columns
		col.modulate.a = 1.0 if on else FADED
		col.get_node("Mark").modulate.a = 1.0 if on else 0.0
		col.get_node("Use").visible = on


## A round's column: its model turning, name, count, an accent mark and what it does (picked only).
func column(id: String, count: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = COLUMN
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(round_view(id))
	col.add_child(_centred(UiStyle.label("Normal" if id == "" else GameState.SPECIALS[id].name, 17, UiStyle.MEDIUM)))
	col.add_child(_centred(UiStyle.caption(str(count))))
	var mark := UiStyle.line(28, UiStyle.ACCENT)
	mark.name = "Mark"
	mark.custom_minimum_size.y = 2
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(mark)
	var use := UiStyle.label("Şarjördeki sıradan mermi." if id == "" else GameState.SPECIALS[id].desc, 13, UiStyle.REGULAR, UiStyle.DIM)
	use.name = "Use"
	use.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	use.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	use.custom_minimum_size = Vector2(COLUMN - 30, 40)
	use.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(use)
	return col


## The round standing up, face to the camera, swaying a little: its own world and no backdrop,
## so it stands on the view like the text does.
func round_view(id: String, px := MODEL_PX) -> SubViewportContainer:
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	holder.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0, 0.5, 8.4)  # the tallest round, case + tip, is ~4 long
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.58, 0.55)
	cam.environment = env
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.5, 0.5, 0.0)
	key.light_energy = 1.6
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI - 0.4, 0.0)
	rim.light_energy = 0.8
	vp.add_child(rim)
	var stand := Node3D.new()  # the round lies along +X, its face to +Z: stood up on its base
	stand.rotation.z = PI / 2.0
	vp.add_child(stand)
	var model: Node3D = PLAIN.instantiate() if id == "" else CASE.instantiate()
	if id != "":
		model.find_child("TipSocket").add_child(load(GameState.SPECIALS[id].tip).instantiate())
	stand.add_child(model)
	model.position.x = -0.6 if id != "" else 0.0  # its middle, roughly, on the turning axis
	var t := stand.create_tween().set_loops()
	t.tween_property(stand, "rotation:y", 0.45, 1.6).from(-0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(stand, "rotation:y", -0.45, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return holder


## "Found one": the special's model, name and use up top, a few seconds.
func note(id: String) -> void:
	if is_instance_valid(_note):
		_note.queue_free()
	var n := VBoxContainer.new()
	n.add_theme_constant_override("separation", 4)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(_centred(UiStyle.caption("özel mermi buldun", UiStyle.ACCENT)))
	n.add_child(round_view(id, 120))
	n.add_child(_centred(UiStyle.label(GameState.SPECIALS[id].name, 22, UiStyle.MEDIUM)))
	var rule := UiStyle.line(120)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	n.add_child(rule)
	n.add_child(_centred(UiStyle.label(GameState.SPECIALS[id].desc, 13, UiStyle.REGULAR, UiStyle.DIM)))
	n.add_child(_centred(UiStyle.caption("R basılı tut  ·  seç")))
	add_child(n)
	n.set_anchors_preset(Control.PRESET_CENTER_TOP)
	n.grow_horizontal = Control.GROW_DIRECTION_BOTH
	n.offset_top = 70  # under the heap's line
	n.modulate.a = 0.0
	var t := n.create_tween()
	t.tween_property(n, "modulate:a", 1.0, 0.2)
	t.tween_interval(NOTE_TIME)
	t.tween_property(n, "modulate:a", 0.0, 0.5)
	t.tween_callback(n.queue_free)
	_note = n


func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
