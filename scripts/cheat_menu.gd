extends CanvasLayer
## Balance panel (yol haritası 11), debug builds only: F9 or P opens it. Game speed, money for yourself
## or the vault, the heap set to a milestone, the Deagle's laser and holo on or off, and what the last game minute earned, so a stage
## of the hour can be timed in a few real minutes. Net.gd adds it.
##
## Co-op: only the host (or a solo player) may use it; speed only solo, since a client's clock
## would run at 1x beside a 10x host. Check: tools/cheat_check.gd.

const SPEEDS := [1.0, 2.0, 5.0, 10.0]
const MONEY := [1_000, 100_000]
const PILES := [99_000_000, 90_000_000, 50_000_000, 10_000_000, 1_000_000, 100]
const WINDOW := 60  # game seconds the rates look back over

var game_time := 0.0  # game seconds since the panel's clock was last reset
var _samples: Array[Vector3] = []  # once a game second: gold, vault, pile
var _since_sample := 0.0
var _panel: PanelContainer
var _info: Label
var _host_only: Array[Button] = []
var _speed_buttons: Array[Button] = []


func _ready() -> void:
	layer = 90
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F9 or event.physical_keycode == KEY_P):  # P: keyboards without F keys
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	var upgrades := get_tree().root.find_child("UpgradeMenu", true, false)
	var busy: bool = GameState.player().placing or (upgrades != null and upgrades.visible)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible or busy else Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if Net.online and Engine.time_scale != 1.0:
		set_speed(1.0)
	game_time += delta
	_since_sample += delta
	while _since_sample >= 1.0:
		_since_sample -= 1.0
		_sample()
	if visible:
		_refresh()


func _sample() -> void:
	if not "pile" in GameState:  # GameState failed to compile (tools/build_arena.gd runs without Net's class)
		return
	_samples.append(Vector3(GameState.gold, GameState.vault, GameState.pile))
	if _samples.size() > WINDOW + 1:
		_samples.pop_front()


## Gold, vault and heap change per game minute over the last WINDOW seconds (fewer just after a reset).
func rates() -> Vector3:
	if _samples.size() < 2:
		return Vector3.ZERO
	return (_samples[-1] - _samples[0]) * 60.0 / (_samples.size() - 1)


func reset_clock() -> void:
	game_time = 0.0
	_samples.clear()
	_since_sample = 0.0
	_sample()


func set_speed(s: float) -> void:
	Engine.time_scale = 1.0 if Net.online else s


func add_gold(n: int) -> void:
	if Net.is_client:
		return
	var p := GameState.player()
	p.gold += n
	GameState.gold_changed.emit(p.gold)


func add_vault(n: int) -> void:
	if Net.is_client:
		return
	GameState.vault += n
	GameState._world(&"vault_changed", [GameState.vault])


## Only the count: the heap's shape stays as dug. Enough for milestones and the money curve.
func set_pile(n: int) -> void:
	if Net.is_client:
		return
	GameState.pile = n
	GameState._world(&"pile_changed", [n])


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 120)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	add_child(_panel)
	var title := Label.new()
	title.text = "DENGE PANELİ (F9 / P)"
	box.add_child(title)

	var row := _row(box, "Hız")
	for s: float in SPEEDS:
		var b := _button(row, "x%d" % s, set_speed.bind(s))
		b.set_meta("speed", s)
		_speed_buttons.append(b)
	for who in ["Paran", "Kasa"]:
		row = _row(box, who)
		for m: int in MONEY:
			_host_only.append(_button(row, "+$%s" % _short(m), (add_gold if who == "Paran" else add_vault).bind(m)))
	row = _row(box, "Yığın")
	for n: int in PILES:
		_host_only.append(_button(row, _short(n), set_pile.bind(n)))
	row = _row(box, "Deagle")  # attachments on and off for free, to try them without the bench
	_button(row, "Tabanca", GameState.request_take_pistol)
	for id in ["laser", "holo"]:
		_button(row, "Lazer" if id == "laser" else "Holo", GameState.request_debug_level_up.bind(id))
	row = _row(box, "Saat")
	_button(row, "Sıfırla", reset_clock)

	_info = Label.new()
	box.add_child(_info)
	reset_clock.call_deferred()  # Net loads before GameState is ready


func _row(box: VBoxContainer, label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var tag := Label.new()
	tag.text = label
	tag.custom_minimum_size.x = 56
	row.add_child(tag)
	box.add_child(row)
	return row


func _button(row: HBoxContainer, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # Space and Enter stay the player's
	b.pressed.connect(action)
	row.add_child(b)
	return b


func _refresh() -> void:
	for b in _host_only:
		b.disabled = Net.is_client
	for b in _speed_buttons:
		b.disabled = Net.online
		b.modulate = Color(1, 0.8, 0.2) if is_equal_approx(b.get_meta("speed"), Engine.time_scale) else Color.WHITE
	var r := rates()
	var t := int(game_time)
	_info.text = "Oyun saati %d:%02d\nSon 1 dk: $%s/dk, kasa $%s/dk, yığın %s/dk%s" % [
		t / 60, t % 60, _short(int(r.x)), _short(int(r.y)), _short(int(-r.z)),
		("\nYalnız host kullanabilir" if Net.is_client else "\nHız yalnız tek kişide" if Net.online else "")]


static func _short(n: int) -> String:
	if absi(n) >= 1_000_000:
		return "%sM" % String.num(n / 1_000_000.0, 1).trim_suffix(".0")
	if absi(n) >= 1_000:
		return "%sK" % String.num(n / 1_000.0, 1).trim_suffix(".0")
	return str(n)
