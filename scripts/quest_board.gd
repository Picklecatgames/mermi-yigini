extends CanvasLayer
## The quest board's own screen (the investigation board by the bench, GameState.BOARD_POS), opened
## with E in front of it (player.gd). Left, on steel: the main chain, how far along the team is, the
## step now with its bar and what it opens, the next SHOWN_AHEAD steps' unlocks, the rest locked.
## Right, typed on paper like the HUD's list: the pinned quests, each with how far along and what it
## pays; a done one is stamped. "Teslim al" claims everything done (GameState.request_claim_quests:
## the host pays, quest_done follows and the HUD floats the money). Under them the last ones done.
## E or Esc closes it. Each player's own screen; the board is the team's.

const Hud := preload("res://scripts/hud.gd")  # its quest words (KINDS, NAMES)
const PANEL := Vector2(1200, 660)  # px, fits 720p
const CHAIN_W := 380.0
const CARD_W := 360.0
const SHOWN_AHEAD := 2  # main steps past the current one whose unlock is named
const DONE_SHOWN := 6
const TIERS := {"main": "Ana", "easy": "Kolay", "medium": "Orta", "hard": "Zor"}
const STAMP := Color(0.62, 0.12, 0.08, 0.85)  # red rubber stamp

var _chain_count: Label
var _chain_bar: Control
var _chain: VBoxContainer
var _cards: GridContainer
var _done: HBoxContainer
var _claim: Button


func _ready() -> void:
	name = "BoardMenu"  # pause_menu.gd leaves Esc to us while we're open
	layer = 5
	visible = false
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	UiStyle.fit_screen(root)
	root.add_child(UiStyle.backdrop())  # no frame: the board stands over the blurred workshop
	var center := CenterContainer.new()
	root.add_child(center)
	var fit := func() -> void:  # under 1200 px wide the whole board shrinks, as the workshop does
		var s := root.size
		var k := minf(1.0, minf(s.x * 0.94 / PANEL.x, s.y * 0.94 / PANEL.y))
		center.scale = Vector2.ONE * k
		center.position = Vector2.ZERO
		center.size = s / k
	get_viewport().size_changed.connect(fit)  # after fit_screen's, so root is already resized
	fit.call()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.custom_minimum_size = PANEL
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	panel.add_child(row)
	row.add_child(_build_chain())
	row.add_child(_build_board())
	GameState.quests_changed.connect(func(_b: Array, _p: Dictionary, _r: Array) -> void:
		if visible:
			_refresh())


## Standing at the board (player.gd asks, then calls open).
func can_open() -> bool:
	var me: Vector3 = get_parent().global_position
	return not visible and Vector2(me.x - GameState.BOARD_POS.x, me.z - GameState.BOARD_POS.z).length() <= GameState.BOARD_REACH


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pick_up"):
		close()
	if event is InputEventKey:
		get_viewport().set_input_as_handled()  # no walking or guns behind the board


## A click the cards let pass would reach player.gd, which takes the mouse back into the game.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


# --- layout ------------------------------------------------------------------------------------

## The main chain on a sheet of steel of its own.
func _build_chain() -> Control:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiStyle.plate("chain", 0, Color(0.32, 0.33, 0.32), 26))
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = CHAIN_W
	col.add_theme_constant_override("separation", 6)
	plate.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UiStyle.display("Ana görev", 30, UiStyle.BOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_chain_count = UiStyle.display("", 30, UiStyle.BOLD, UiStyle.ACCENT)
	head.add_child(_chain_count)
	_chain_bar = UiStyle.meter(CHAIN_W, UiStyle.ACCENT, 3.0)
	col.add_child(_chain_bar)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	col.add_child(gap)
	_chain = VBoxContainer.new()
	_chain.add_theme_constant_override("separation", 3)
	col.add_child(_chain)
	return plate


func _build_board() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	var cork := PanelContainer.new()  # the paper is pinned to cork
	cork.add_theme_stylebox_override("panel", UiStyle.plate("cork", 0, Color(0.78, 0.78, 0.78), 26))
	cork.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cork)
	_cards = GridContainer.new()
	_cards.columns = 2
	_cards.add_theme_constant_override("h_separation", 18)
	_cards.add_theme_constant_override("v_separation", 16)
	_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cork.add_child(_cards)
	_done = HBoxContainer.new()
	_done.add_theme_constant_override("separation", 16)
	col.add_child(_done)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	col.add_child(foot)
	_claim = Button.new()
	_claim.focus_mode = Control.FOCUS_NONE
	_claim.custom_minimum_size = Vector2(260, 46)
	_claim.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD, 0, true))
	_claim.add_theme_font_size_override("font_size", 26)
	UiStyle.plate_button(_claim, "claim")
	for s in ["font_color", "font_hover_color", "font_pressed_color"]:
		_claim.add_theme_color_override(s, UiStyle.WHITE)
	_claim.add_theme_color_override("font_disabled_color", Color(UiStyle.DIM, 0.5))
	_claim.pressed.connect(func() -> void: GameState.request_claim_quests())
	# Two equal fillers keep the claim under the cork's middle; the E closes it at the right end.
	foot.add_child(_grow(Control.new()))
	foot.add_child(_claim)
	var right := HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(_grow(right))
	var close_key := UiStyle.hint("E", "")
	close_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(close_key)
	return col


# --- contents ----------------------------------------------------------------------------------

func _refresh() -> void:
	_fill_chain()
	_fill_cards()
	_fill_done()
	var gold := 0
	for id: String in GameState.quests_ready:
		gold += GameState.QUESTS[id].reward.get("gold", 0)
	var trip := GameState.quest_board.any(func(id: String) -> bool:
		return id != "" and GameState.QUESTS[id].kind == "board_claim")
	_claim.disabled = GameState.quests_ready.is_empty() and not trip
	_claim.text = "Teslim al" + ("   +$" + UiStyle.dotted(gold) if gold > 0 else "")


func _fill_chain() -> void:
	for n in _chain.get_children():
		n.free()
	var steps: Array = GameState.QUESTS.keys().filter(func(id: String) -> bool:
		return GameState.QUESTS[id].tier == "main" and not GameState.QUESTS[id].get("warmup", false))
	var done: int = steps.filter(func(id: String) -> bool: return id in GameState.quests_done).size()
	_chain_count.text = "%d/%d" % [done, steps.size()]
	UiStyle.set_meter(_chain_bar, float(done) / maxi(steps.size(), 1))
	var now: String = GameState.quest_board[0] if not GameState.quest_board.is_empty() else ""
	var ahead := -1  # steps past the current one, counted as we go
	for id: String in steps:
		var q: Dictionary = GameState.QUESTS[id]
		var opens: String = Hud.NAMES.get(q.get("unlock", ""), q.get("unlock", ""))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		_chain.add_child(line)
		if id in GameState.quests_done:
			line.add_child(UiStyle.icon("check", 16, UiStyle.MONEY))
			line.add_child(_grow(UiStyle.label(q.name, 15, UiStyle.MEDIUM, UiStyle.DIM)))
			line.add_child(UiStyle.label(opens, 14, UiStyle.MEDIUM, Color(UiStyle.DIM, 0.7)))
		elif ahead < 0 and (id == now or (now != "" and GameState.QUESTS[now].get("warmup", false))):
			ahead = 0  # the step now (during the warmup: the chain's first)
			line.add_child(UiStyle.icon("crosshair", 16, UiStyle.ACCENT))
			var mid := VBoxContainer.new()
			mid.add_theme_constant_override("separation", 3)
			_grow(mid)
			mid.add_child(UiStyle.display(q.name, 20, UiStyle.SEMIBOLD))
			var bar := UiStyle.meter(CHAIN_W - 140, UiStyle.ACCENT, 3.0)
			UiStyle.set_meter(bar, float(GameState.quest_progress.get(id, 0)) / maxi(GameState.quest_target(id), 1))
			mid.add_child(bar)
			line.add_child(mid)
			line.add_child(UiStyle.display(opens, 18, UiStyle.SEMIBOLD, UiStyle.ACCENT))
		else:
			ahead += 1
			line.add_child(UiStyle.icon("padlock", 15, Color(UiStyle.DIM, 0.5)))
			line.add_child(_grow(UiStyle.label("", 15)))
			line.add_child(UiStyle.label(opens if ahead <= SHOWN_AHEAD else "?", 14, UiStyle.MEDIUM, Color(UiStyle.DIM, 0.6)))


func _fill_cards() -> void:
	for n in _cards.get_children():
		n.free()
	var k := 0
	for id: String in GameState.quest_board:
		if id != "":
			_cards.add_child(_card(id, k))
			k += 1


## A quest typed on a sheet of paper, pinned a little askew: its name and tier, what to do, how far,
## what it pays; done, a red stamp across it.
func _card(id: String, k: int) -> Control:
	var q: Dictionary = GameState.QUESTS[id]
	var ready := id in GameState.quests_ready
	var target := GameState.quest_target(id)
	var have: int = GameState.quest_progress.get(id, 0)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = CARD_W
	card.add_theme_stylebox_override("panel", UiStyle.paper_box(14))
	card.rotation = deg_to_rad([-0.7, 0.5, -0.3, 0.8, -0.5][k % 5])
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	top.add_child(_grow(UiStyle.typed(q.name, 19)))
	top.add_child(UiStyle.typed(TIERS.get(q.tier, ""), 13, UiStyle.PAPER_FADED))
	var what: String = Hud.KINDS.get(q.kind, q.kind)
	if q.has("with"):
		what += " (%s)" % Hud.NAMES.get(q.with, q.with)
	col.add_child(UiStyle.typed("%s %s" % [what, UiStyle.dotted(target)] if target > 1 else what, 14, UiStyle.PAPER_FADED))
	var bar := UiStyle.meter(CARD_W - 28, UiStyle.PAPER_GREEN if ready else UiStyle.PAPER_INK, 3.0)
	bar.color = Color(0, 0, 0, 0.1)
	UiStyle.set_meter(bar, float(have) / maxi(target, 1))
	col.add_child(bar)
	var pay := HBoxContainer.new()
	pay.add_theme_constant_override("separation", 6)
	col.add_child(pay)
	pay.add_child(_grow(UiStyle.typed(_reward(q), 16)))
	pay.add_child(UiStyle.typed("%s/%s" % [UiStyle.dotted(have), UiStyle.dotted(target)], 13, UiStyle.PAPER_FADED))
	if ready:
		var stamp := UiStyle.stencil("TAMAM", 34, STAMP)
		stamp.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		stamp.rotation = deg_to_rad(-12)
		stamp.position = Vector2(CARD_W - 160, 22)
		card.add_child(stamp)
	return card


## What a quest pays, in a few words: "+$20", "Çift tabanca parçası", a perk, what it opens.
func _reward(q: Dictionary) -> String:
	if q.reward.has("gold"):
		return "+$" + UiStyle.dotted(q.reward.gold)
	if q.reward.has("part"):
		return "%s parçası" % Hud.NAMES.get(q.reward.part, q.reward.part)
	if q.reward.has("perk"):
		return Hud.NAMES.get(q.reward.perk, q.reward.perk)
	if q.has("unlock"):
		return Hud.NAMES.get(q.unlock, q.unlock)
	return ""


## The last few side quests done, newest first.
func _fill_done() -> void:
	for n in _done.get_children():
		n.free()
	var side: Array = Array(GameState.quests_done).filter(func(id: String) -> bool:
		return GameState.QUESTS[id].tier != "main")
	side.reverse()
	for id: String in side.slice(0, DONE_SHOWN):
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.add_child(UiStyle.icon("check", 14, UiStyle.MONEY))
		item.add_child(UiStyle.label(GameState.QUESTS[id].name, 14, UiStyle.MEDIUM, UiStyle.DIM))
		_done.add_child(item)


func _grow(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
