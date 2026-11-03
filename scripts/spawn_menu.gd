extends CanvasLayer
## Zombie test menu, debug builds only: Z opens it. Pick how many, then a type (waves.gd TYPES),
## and they come up a few metres in front of you, facing you, and come for you
## (GameState.request_debug_spawn; the host puts them up, waves.gd _debug_spawn). The menu closes
## on the pick, so the gun is in hand at once. Net.gd adds it. Check: tools/day_night_check.gd.

## waves.gd TYPES in the order they first come in, with the names docs/ayrintilar.md gives them.
const NAMES := [["walker", "Yürüyen"], ["runner", "Koşan"], ["crawler", "Sürünen"], ["armored", "Zırhlı"],
	["screamer", "Çığlıkçı"], ["dog", "Köpek"], ["bloater", "Şişko"], ["masked", "Maskeli"],
	["regen", "Yenilenen"], ["brute", "Dev"], ["rager", "Öfkeli"], ["vaulter", "Atlayan"],
	["swarm", "İskelet"], ["blob", "Blob"], ["leaper", "Sıçrayan"], ["creeper", "Altından geçen"],
	["spiker", "Dikenli"]]
const COUNTS := [1, 3, 5, 10]

var count := 1
var _count_buttons: Array[Button] = []


func _ready() -> void:
	layer = 90
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Z:  # Z: zombi (2026-11-03, the user: not an F key)
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED


## `count` of `type` in front of the local player.
func spawn(type: String) -> void:
	var player := get_tree().get_first_node_in_group("walker") as Node3D  # the local player (player.gd)
	if player == null:
		return
	GameState.request_debug_spawn(type, player.global_position, float(player.get(&"_yaw")), count)
	if visible:
		toggle()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)  # the balance panel (F9) is on the left
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.position.y = 120
	panel.position.x -= 12
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	add_child(panel)
	var title := Label.new()
	title.text = "ZOMBİ (Z)"
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	for n: int in COUNTS:
		var b := _button(row, "x%d" % n, _set_count.bind(n))
		b.set_meta("count", n)
		_count_buttons.append(b)
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	for pair: Array in NAMES:
		var b := _button(grid, pair[1], spawn.bind(pair[0]))
		b.custom_minimum_size.x = 120
	_set_count(count)


func _set_count(n: int) -> void:
	count = n
	for b in _count_buttons:
		b.modulate = Color(1, 0.8, 0.2) if b.get_meta("count") == n else Color.WHITE


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # Space and Enter stay the player's
	b.pressed.connect(action)
	parent.add_child(b)
	return b
