extends "res://scripts/station_view.gd"
## The melting hopper's screen (GameState.MELTER_POS), opened with E beside it (player.gd), which
## first pours the hand in (GameState.request_melt). In the bench's way (station_view.gd): the
## camera goes to the hopper. Left, in things and numbers with no captions (the user: "too much
## text"): what it is for (round -> crucible -> ingot -> press), how fast it melts, what waits in it
## and how long that takes, the team's brass. Right: the next burner for sale. The hopper is the
## team's, the screen each player's own.


var _rate: Label
var _bin: Label
var _eta: Label
var _eta_icon: TextureRect
var _bin_bar: Control
var _brass: Label
var _pip_row: HBoxContainer
var _state: Label
var _buy: Button
var _till := AudioStreamPlayer.new()
var _peak := 0  # the bin's fullest since it was last empty, for its bar


func _ready() -> void:
	name = "MelterMenu"  # pause_menu.gd leaves Esc to us while we're open
	_build_frame("ERİTME HUNİSİ")
	_till.stream = preload("res://assets/sounds/ui/purchase.ogg")
	_till.bus = &"Arayuz"
	_till.volume_db = -12.0  # as the bench's till
	add_child(_till)
	_left.add_child(_flow())
	_left.add_child(_gap(8))
	_rate = _stat(_left, "", "melt", UiStyle.ACCENT)  # how fast: the crucible and "2/sn"
	_left.add_child(_gap(4))
	var bin := HBoxContainer.new()
	_left.add_child(bin)
	_bin = _stat(bin, "", "rounds", UiStyle.WHITE)  # what waits: rounds, their time, the bar
	_bin.get_parent().get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var eta := HBoxContainer.new()
	eta.add_theme_constant_override("separation", 6)
	eta.size_flags_vertical = Control.SIZE_SHRINK_END
	bin.add_child(eta)
	_eta_icon = UiStyle.icon("hourglass", 20)
	eta.add_child(_eta_icon)
	_eta = UiStyle.display("", 26, UiStyle.MEDIUM, UiStyle.DIM)
	eta.add_child(_eta)
	_bin_bar = UiStyle.bar(340, 16, "bin")
	_left.add_child(_bin_bar)
	_left.add_child(_gap(4))
	_brass = _stat(_left, "", "ingot", UiStyle.ACCENT)  # the brass: the ingot says it

	var card := _card("burner")
	_right.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(UiStyle.item("melt", 52))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_state = _card_words(words, "BRÜLÖR", "")
	_pip_row = HBoxContainer.new()
	_pip_row.add_theme_constant_override("separation", 4)
	words.add_child(_pip_row)
	_buy = _price_button(Vector2(130, 50), 22, "burner")
	_buy.pressed.connect(func() -> void:
		if GameState.request_upgrade_station("melter"):
			_till.play()
		_refresh())
	row.add_child(_buy)


## round -> crucible -> ingot -> press, as the things themselves: the hopper's place in the workshop.
func _flow() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var steps := ["round", "melt", "ingot", "press"]
	for i in steps.size():
		if i > 0:
			row.add_child(_arrow(16, Color(UiStyle.DIM, 0.7)))
		row.add_child(UiStyle.item(steps[i], 44))
	return row


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


## Beside the hopper once it is open (player.gd asks, then calls open).
func can_open() -> bool:
	if visible or not GameState.unlocked("melter"):
		return false
	var me: Vector3 = get_parent().global_position
	return Vector2(me.x - GameState.MELTER_POS.x, me.z - GameState.MELTER_POS.z).length() <= GameState.STATION_REACH


func open() -> void:
	_peak = GameState.melt_bin
	super.open()


## In front of the hopper, a little above its grate: the bin, the crucible's glow under it, the
## bucket beside it.
func _view() -> Array:
	var at := GameState.MELTER_POS
	return [at + Vector3(0.0, 1.5, -1.45), at + Vector3(0.0, 0.55, 0.0)]


func _refresh() -> void:
	super._refresh()
	var level := GameState.melt_level
	var rate: float = GameState.MELT_RATES[level]
	var bin := GameState.melt_bin
	_peak = maxi(_peak, bin) if bin > 0 else 0
	_rate.text = "%s/sn" % num(rate)
	_bin.text = UiStyle.dotted(bin)
	_eta.text = _time(bin / rate) if bin > 0 else "Huni boş"
	_eta_icon.visible = bin > 0
	UiStyle.set_bar(_bin_bar, 1.0 - float(bin) / _peak if _peak > 0 else 0.0)
	_brass.text = UiStyle.dotted(GameState.brass)
	_pips(_pip_row, level, GameState.MELT_RATES.size())
	var costs: Array = GameState.MELT_COSTS
	if level >= costs.size():
		_state.text = "%s/sn" % num(rate)
		_buy.text = "EN ÜST"
		_buy.disabled = true
		return
	_state.text = "%s  →  %s/sn" % [num(rate), num(GameState.MELT_RATES[level + 1])]
	var cost: int = costs[level]
	_buy.text = "$" + UiStyle.dotted(cost)
	_buy.disabled = _have() < cost


## 75 -> "1 dk 15 sn"
func _time(seconds: float) -> String:
	var s := ceili(seconds)
	return "%d sn" % s if s < 60 else "%d dk %d sn" % [floori(s / 60.0), s % 60]
