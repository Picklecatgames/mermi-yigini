extends Control
## The heads-up display (UiStyle): symmetric about the middle of the screen, no boxes.
## Top centre, the one big thing: what is left of the heap, the game's goal, over a brass progress
## bar, "Yığında kalan" and the keys found under its two ends.
## Bottom left: the magazine big, the hand under it. Bottom right, its mirror: gold big in green,
## the team vault under it. Bottom centre: the guns as key caps with names, the one in hand bright
## and underlined in brass, and above them a special round's state. Top right: the Q key cap and
## "Geliştirmeler", brass when the gold reaches an upgrade, and test mode's hint under it; under
## them the quest board (GameState QUESTS), a line and a thin bar a slot, the main quest on top saying
## what to do; a done one turns green with its tick and reward and waits for C, then folds away and
## the next one comes in. Kept short: the screen is for the heap.
## Listens to GameState itself.

const KeyCache := preload("res://scripts/key_cache.gd")
const MARGIN := Vector2(36, 28)  # px from the screen's edges
const BIG := 60  # px, the two big numbers
const HEAP_W := 340.0  # px, the heap's bar
const MONEY := UiStyle.MONEY  # kept for older callers
const QUEST_W := 230.0  # px, a quest's bar
const KINDS := {"gold_earned": "Altın kazan", "bullets_carried": "Yığından mermi taşı",
	"bullets_fired": "Mermi ateşle", "hits": "Hedefe isabet", "weak_hits": "Kafa isabeti",
	"combo": "Kombo zinciri", "crafted": "Tarife mermi işle", "bullets_melted": "Mermi erit",
	"key_found": "Anahtar bul"}
## What a quest's `with`, `unlock`, part and perk are called on screen; guns use their GUNS name.
const NAMES := {"clone": "Klon", "obur": "Obur", "sekme": "Sekme", "yanki": "Yankı",
	"workbench": "Tezgâh", "bucket": "Kova", "blueprints": "Tarif panosu", "hand_press": "El presi",
	"shovel": "Kürek", "melter": "Eritme hunisi", "slot_machine": "Slot makinesi",
	"electric_press": "Elektrikli pres", "wheelbarrow": "El arabası", "melter_speed": "Hızlı huni",
	"melter_yield": "Verimli huni", "sweeper": "Süpürge robotu", "drone_teaser": "Dron planı",
	"dual_pistol": "Çift tabanca", "clone_spread": "Klon yayılımı", "clone_count": "Klon sayısı",
	"clone_count_2": "Klon sayısı II", "obur_more": "Obur iştahı", "sekme_more": "Fazla sekme",
	"yanki_more": "Fazla yankı"}
const CLOSE_TIME := 0.45  # s, a claimed card folding away

var _heap: Label
var _heap_meter: Control
var _keys: Label
var _mag_caption: Label
var _mag: Label
var _mag_of: Label
var _hand: Label
var _gold: Label
var _vault: Label
var _special_row: HBoxContainer
var _special: Label
var _special_hint: Control
var _can_buy: Label
var _q: PanelContainer
var _guns: HBoxContainer
var _test: Control
var _quests: VBoxContainer
var _cards: Array[Dictionary] = []  # per QUEST_SLOTS slot: its nodes and the quest it shows
var _claim: Control  # "[C] Ödülü al", while something is done
var _claimed := {}  # quest ids just claimed: their card folds away before the next comes in


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.fit_screen(self)
	_build_heap()
	_build_sides()
	_build_middle()
	_build_corner()
	_build_quests()
	for s: StringName in [&"pile_changed", &"carried_changed", &"loaded_changed", &"gold_changed", &"vault_changed", &"specials_changed", &"placing_changed"]:
		GameState.connect(s, func(_a = null) -> void: refresh())
	GameState.upgraded.connect(refresh.unbind(2))
	GameState.gun_changed.connect(refresh.unbind(2))
	GameState.key_taken.connect(refresh.unbind(2))
	GameState.gold_changed.connect(func(_g: int) -> void: _pop(_gold))
	GameState.quest_done.connect(func(id: String, _gold: int) -> void: _claimed[id] = true)
	GameState.quests_changed.connect(func(_b: Array, _p: Dictionary, _r: Array) -> void: _refresh_quests())
	refresh()
	_refresh_quests()


func _build_heap() -> void:
	var col := _column(Control.PRESET_CENTER_TOP)
	col.offset_top = MARGIN.y - 8
	col.add_theme_constant_override("separation", 6)
	_heap = UiStyle.display("", 40, UiStyle.BOLD)
	_heap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_heap)
	_heap_meter = UiStyle.meter(HEAP_W, UiStyle.ACCENT, 3.0)
	_heap_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_heap_meter)
	var under := HBoxContainer.new()
	under.custom_minimum_size.x = HEAP_W
	under.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(under)
	var left := UiStyle.caption("Yığında kalan")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	under.add_child(left)
	_keys = UiStyle.caption("")
	under.add_child(_keys)


func _build_sides() -> void:
	for right in [false, true]:
		var col := _column(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT)
		col.offset_left = 0 if right else MARGIN.x
		col.offset_right = -MARGIN.x if right else 0
		col.offset_bottom = -MARGIN.y
		col.add_theme_constant_override("separation", -6)
		var align := HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		var caption := UiStyle.caption("Altın" if right else "Şarjör")
		caption.horizontal_alignment = align
		col.add_child(caption)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(row)
		var big := UiStyle.display("", BIG, UiStyle.SEMIBOLD, MONEY if right else UiStyle.WHITE)
		row.add_child(big)
		var small := UiStyle.label("", 15, UiStyle.MEDIUM, UiStyle.DIM)
		small.horizontal_alignment = align
		col.add_child(small)
		if right:
			_gold = big
			_vault = small
		else:
			_mag_caption = caption
			_mag = big
			_mag_of = UiStyle.display("", 28, UiStyle.MEDIUM, UiStyle.DIM)
			_mag_of.size_flags_vertical = Control.SIZE_SHRINK_END
			row.add_child(_mag_of)
			_hand = small


func _build_middle() -> void:
	var col := _column(Control.PRESET_CENTER_BOTTOM)
	col.offset_bottom = -MARGIN.y
	col.add_theme_constant_override("separation", 14)
	_special_row = HBoxContainer.new()
	_special_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_special_row.add_theme_constant_override("separation", 12)
	_special_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_special_row)
	_special = UiStyle.label("", 15, UiStyle.SEMIBOLD)
	_special.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_special_row.add_child(_special)
	_special_hint = UiStyle.hint("R", "Basılı tut")
	_special_row.add_child(_special_hint)
	_guns = HBoxContainer.new()
	_guns.alignment = BoxContainer.ALIGNMENT_CENTER
	_guns.add_theme_constant_override("separation", 26)
	_guns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_guns)
	for i in range(1, GameState.GUNS.size()):
		var gun := VBoxContainer.new()
		gun.add_theme_constant_override("separation", 7)
		gun.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UiStyle.keycap(str(i), 13))
		var name_ := UiStyle.display(GameState.GUNS[i].name, 19, UiStyle.SEMIBOLD)
		name_.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_)
		gun.add_child(row)
		var mark := UiStyle.line(0, UiStyle.ACCENT)
		mark.custom_minimum_size.y = 2
		gun.add_child(mark)
		_guns.add_child(gun)


func _build_corner() -> void:
	var corner := _column(Control.PRESET_TOP_RIGHT)
	corner.offset_right = -MARGIN.x
	corner.offset_top = MARGIN.y
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(row)
	_can_buy = UiStyle.label("", 16, UiStyle.SEMIBOLD)
	_can_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_can_buy)
	_q = UiStyle.keycap("Q", 20)
	row.add_child(_q)
	_test = UiStyle.hint("T", "Test modu: sınırsız mermi")
	_test.alignment = BoxContainer.ALIGNMENT_END
	(_test.get_child(1) as Label).add_theme_color_override("font_color", UiStyle.ACCENT)
	corner.add_child(_test)


func _build_quests() -> void:
	# Under the Q, at the right edge: the left is the view's.
	_quests = VBoxContainer.new()
	_quests.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quests.size_flags_horizontal = Control.SIZE_SHRINK_END
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_q.get_parent().get_parent().add_child(gap)
	_q.get_parent().get_parent().add_child(_quests)
	_quests.add_theme_constant_override("separation", 9)
	for i in GameState.QUEST_SLOTS.size():
		var main := i == 0
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 3)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.custom_minimum_size.x = QUEST_W
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 6)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(top)
		var tick := _tick()
		top.add_child(tick)
		var name_ := UiStyle.display("", 18 if main else 15, UiStyle.SEMIBOLD, UiStyle.WHITE if main else UiStyle.DIM)
		name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_)
		var share := UiStyle.label("", 14 if main else 13, UiStyle.SEMIBOLD, UiStyle.DIM)
		share.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(share)
		var bar := UiStyle.meter(QUEST_W, UiStyle.WHITE, 3.0 if main else 2.0)
		card.add_child(bar)
		_quests.add_child(card)
		if main:
			_quests.add_child(UiStyle.line(QUEST_W * 0.4))  # the main quest over the rest
		_cards.append({"card": card, "tick": tick, "name": name_, "share": share, "bar": bar,
			"main": main, "id": "", "pulse": null})
	_claim = UiStyle.hint("C", "Ödülü al")
	UiStyle.tint_keycap(_claim.get_child(0) as PanelContainer, UiStyle.ACCENT)
	(_claim.get_child(1) as Label).add_theme_color_override("font_color", UiStyle.ACCENT)
	_quests.add_child(_claim)


## A check mark, drawn: Barlow has no glyph for it.
func _tick() -> Control:
	var t := Control.new()
	t.custom_minimum_size = Vector2(16, 16)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.draw.connect(func() -> void:
		t.draw_polyline(PackedVector2Array([Vector2(2, 8.5), Vector2(6.5, 13), Vector2(14, 3.5)]), UiStyle.MONEY, 2.6, true))
	return t


## The board as GameState has it. A slot whose quest was just claimed folds its card away first.
func _refresh_quests() -> void:
	for c: Dictionary in _cards:
		var i := _cards.find(c)
		var id: String = GameState.quest_board[i] if i < GameState.quest_board.size() else ""
		if c.id != id and _claimed.has(c.id):
			_claimed.erase(c.id)
			_fold(c)
		elif not c.has("folding"):
			_show_quest(c, id)
	_claim.visible = not GameState.quests_ready.is_empty()


## A claimed card: ticked, it fades and shrinks away, then the slot's next quest comes in.
func _fold(c: Dictionary) -> void:
	c.folding = true
	_set_pulse(c, false)
	c.tick.visible = true
	c.share.text = "Alındı"
	var card: Control = c.card
	card.pivot_offset = Vector2(0, card.size.y * 0.5)
	var tw := card.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.25)
	tw.tween_property(card, "modulate:a", 0.0, CLOSE_TIME)
	tw.parallel().tween_property(card, "scale:y", 0.6, CLOSE_TIME)
	tw.tween_callback(func() -> void:
		c.erase("folding")
		card.scale = Vector2.ONE
		var i := _cards.find(c)
		_show_quest(c, GameState.quest_board[i] if i < GameState.quest_board.size() else "")
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.3))


func _show_quest(c: Dictionary, id: String) -> void:
	c.id = id
	(c.card as Control).visible = id != ""
	if id == "":
		_set_pulse(c, false)
		return
	var q: Dictionary = GameState.QUESTS[id]
	var target := GameState.quest_target(id)
	var have: int = GameState.quest_progress.get(id, 0)
	var ready := id in GameState.quests_ready
	# One line: what to do (the main quest says it plainly, the rest by name), the share done; a done
	# one swaps the share for its reward.
	var what: String = KINDS.get(q.kind, q.kind)
	if q.has("with"):
		what += " (%s)" % _with_name(q.with)
	c.name.text = ("%s %s" % [what, UiStyle.dotted(target)]) if c.main else q.name
	c.name.add_theme_color_override("font_color", UiStyle.MONEY if ready else (UiStyle.WHITE if c.main else UiStyle.DIM))
	c.share.text = _reward_text(id) if ready else "%" + str(floori(100.0 * have / maxi(target, 1)))
	c.share.add_theme_color_override("font_color", UiStyle.MONEY if ready else UiStyle.DIM)
	(c.bar.get_child(0) as ColorRect).color = UiStyle.MONEY if ready else (UiStyle.ACCENT if c.main else Color(UiStyle.WHITE, 0.6))
	UiStyle.set_meter(c.bar, float(have) / maxi(target, 1))
	c.tick.visible = ready
	_set_pulse(c, ready)


## The reward in a word or two: "+$30", "Parça", "Perk", what it opens.
func _reward_text(id: String) -> String:
	var q: Dictionary = GameState.QUESTS[id]
	if q.reward.has("gold"):
		return "+$" + UiStyle.dotted(q.reward.gold)
	if q.has("unlock"):
		return NAMES.get(q.unlock, q.unlock)
	return "Parça" if q.reward.has("part") else "Perk"


## A done card breathes until it is claimed: brighter and back, a little bigger and back.
func _set_pulse(c: Dictionary, on: bool) -> void:
	var card: Control = c.card
	if on == (c.pulse != null):
		return
	if c.pulse:
		(c.pulse as Tween).kill()
		c.pulse = null
		card.modulate = Color.WHITE
		card.scale = Vector2.ONE
		return
	card.pivot_offset = Vector2(0, card.size.y * 0.5)
	var tw := card.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(card, "modulate", Color(1.35, 1.2, 0.85), 0.55)
	tw.parallel().tween_property(card, "scale", Vector2.ONE * 1.03, 0.55)
	tw.tween_property(card, "modulate", Color.WHITE, 0.55)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.55)
	c.pulse = tw


func _with_name(with: String) -> String:
	for g: Dictionary in GameState.GUNS:
		if g.id == with:
			return g.name
	return NAMES.get(with, with)


## Everything from GameState as it is now.
func refresh() -> void:
	var p := GameState.player()
	_heap.text = UiStyle.dotted(GameState.pile)
	UiStyle.set_meter(_heap_meter, float(GameState.pile) / GameState.PILE_START)
	_keys.text = "Anahtar %d / %d" % [p.keys.size(), KeyCache.KEYS.size()]
	if p.gun == 0:  # bare fists: the hand is all there is
		_mag_caption.text = "Elde"
		_mag.text = str(GameState.carried)
		_mag_of.text = "/ %d" % GameState.carry_capacity
		_hand.text = "Silah yok"
	else:
		_mag_caption.text = "Şarjör"
		_mag.text = str(GameState.loaded)
		_mag_of.text = "/ %d" % GameState.mag_capacity
		_hand.text = "Elde %d / %d" % [GameState.carried, GameState.carry_capacity]
	_mag.add_theme_color_override("font_color", UiStyle.WARN if p.gun != 0 and GameState.loaded == 0 else UiStyle.WHITE)
	_gold.text = "$" + UiStyle.dotted(GameState.gold)
	_vault.text = "Takım kasası $%s" % UiStyle.dotted(floori(GameState.vault))
	_special_row.visible = true
	if p.armed != "":
		_special.text = "%s takılı" % GameState.SPECIALS[p.armed].name
		_special.add_theme_color_override("font_color", UiStyle.ACCENT)
		_special_hint.visible = false
	elif not p.specials.is_empty():
		_special.text = "Özel mermi ×%d" % p.specials.size()
		_special.add_theme_color_override("font_color", UiStyle.WHITE)
		_special_hint.visible = true
	else:
		_special_row.visible = false
	for i in _guns.get_child_count():
		var on := i + 1 == p.gun
		var gun := _guns.get_child(i) as Control
		gun.get_child(1).modulate.a = 1.0 if on else 0.0  # the underline
		gun.get_child(0).get_child(1).visible = on  # the others are only their key
		gun.modulate.a = 1.0 if on else (0.5 if GameState.gun_open(i + 1) else 0.22)
	_guns.get_parent().visible = not p.placing  # placement keeps its keys here
	var can := GameState.UPGRADES.keys().any(func(id: String) -> bool:
		var costs: Array = GameState.UPGRADES[id].costs
		return p.levels[id] < costs.size() and GameState.gold >= costs[p.levels[id]])
	_can_buy.text = "Geliştirme alınabilir" if can else "Geliştirmeler"
	_can_buy.add_theme_color_override("font_color", UiStyle.ACCENT if can else UiStyle.DIM)
	UiStyle.tint_keycap(_q, UiStyle.ACCENT if can else UiStyle.WHITE)
	_test.visible = GameState.infinite_ammo


## A number that went up gives a small start.
func _pop(l: Label) -> void:
	l.pivot_offset = Vector2(l.size.x, l.size.y * 0.6)
	l.scale = Vector2.ONE * 1.08
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _column(preset: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.set_anchors_and_offsets_preset(preset)  # plain set_anchors_preset freezes today's screen size into the offsets
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_RIGHT, Control.PRESET_TOP_RIGHT] else (Control.GROW_DIRECTION_BOTH if preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM] else Control.GROW_DIRECTION_END)
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM] else Control.GROW_DIRECTION_END
	return col
