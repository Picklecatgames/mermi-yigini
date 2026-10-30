extends Control
## The heads-up display (UiStyle): symmetric about the middle of the screen, no boxes. Top centre,
## the one big thing: what is left of the heap, the game's goal, over a brass progress bar, "Yığında
## kalan" and the keys found under its two ends. Bottom left: the magazine big, the hand under it.
## Bottom right, its mirror: gold big in green, the team vault under it and, once the hopper is
## open, the team's brass. Bottom centre: the guns as key caps with names, the one in hand bright
## and underlined in brass, and above them a special round's state. Top right: the Q key cap and
## "Geliştirmeler", brass when the gold reaches an upgrade, and test mode's hint under it; under
## them the quest board (GameState QUESTS), a line and a thin bar a slot, the main quest on top
## saying what to do; a done one turns green with its tick and reward and waits to be claimed at the
## board (E there), then folds away and the next one comes in. Kept short: the screen is for the
## heap. During the warmup the quest list stays away: what to do now is one key and a few words at
## the bottom, over the guns, and the rest of the screen comes in as it is learnt (Q blinks while
## the dummy waits to be bought); arrows point at the pistol and the heap while they are the next
## thing. Something just opened gets a line under the heap and, like the board while a reward waits
## there, an arrow pointing the way (Reveal). say() puts a line of story at the bottom for a while.
## Top centre, once there are waves: the railing's life (GameState.fence), a fence and a gauge; the
## wave lost, the screen says so and darkens until the same wave waits again (scripts/waves.gd).
## Listens to GameState itself.

const KeyCache := preload("res://scripts/key_cache.gd")
const StyleRank := preload("res://scripts/style_rank.gd")
const Waves := preload("res://scripts/waves.gd")
const FENCE_W := 190.0  # px, the railing's gauge
const FENCE_LOW := 0.3  # of its life: the number goes red, the gauge blinks
const MARGIN := Vector2(36, 28)  # px from the screen's edges
const BIG := 60  # px, the two big numbers
const HEAP_W := 200.0  # px, the heap's bar
const MONEY := UiStyle.MONEY  # kept for older callers
const QUEST_W := 230.0  # px, a quest's bar
const KINDS := {"gold_earned": "Altın kazan", "bullets_carried": "Yığından mermi taşı",
	"bullets_fired": "Mermi ateşle", "hits": "Hedefe isabet", "weak_hits": "Kafa isabeti",
	"combo": "Kombo zinciri", "crafted": "Preste pirinç işle", "bullets_melted": "Mermi erit",
	"key_found": "Anahtar bul", "loaded": "Şarjöre mermi koy", "board_claim": "Panoya git", "bench_bought": "Tezgâhta geliştirme al",
	"gear_bought": "Teçhizat al", "gear_placed": "Teçhizat yerleştir", "gun_taken": "Tabancayı al"}
## What a quest's `with`, `unlock`, part and perk are called on screen; guns use their GUNS name.
const NAMES := {"clone": "Klon", "obur": "Obur", "sekme": "Sekme", "yanki": "Yankı",
	"workbench": "Tezgâh", "bucket": "Kova", "blueprints": "Tarif panosu", "hand_press": "Pres",
	"shovel": "Kürek", "melter": "Eritme hunisi", "slot_machine": "Slot makinesi",
	"electric_press": "Elektrikli pres", "wheelbarrow": "El arabası", "melter_speed": "Hızlı huni",
	"melter_yield": "Verimli huni", "sweeper": "Süpürge robotu", "drone_teaser": "Dron planı",
	"dual_pistol": "Çift tabanca", "clone_spread": "Klon yayılımı", "clone_count": "Klon sayısı",
	"clone_count_2": "Klon sayısı II", "obur_more": "Obur iştahı", "sekme_more": "Fazla sekme",
	"yanki_more": "Fazla yankı", "board": "Yan görevler"}
const CLOSE_TIME := 0.45  # s, a claimed card folding away
const BANNER_TIME := 3.5  # s a "… açıldı" line stays
const FLOAT_TIME := 1.8  # s a claimed "+$N" takes to rise and fade
const POINT_EDGE := 70.0  # px from the screen's edge, the arrow to something off screen

var _heap: Label
var _heap_meter: Control
var _keys: Label
var _mag_caption: Label
var _mag: Label
var _mag_of: Label
var _hand: Label
var _gold: Label
var _vault: Label
var _brass: Label  # the team's brass from the hopper (GameState.brass), once it is open
var _special_row: HBoxContainer
var _special: Label
var _special_hint: Control
var _can_buy: Label
var _q: PanelContainer
var _guns: HBoxContainer
var _test: Control
var _quests: VBoxContainer
var _sheet: PanelContainer  # the paper the quests are typed on
var _cards: Array[Dictionary] = []  # per QUEST_SLOTS slot: its nodes and the quest it shows
var _claim: Control  # "[E] Panoda teslim et", while something is done
var _claimed := {}  # quest ids just claimed: their card folds away before the next comes in
var _hint: Control  # bottom centre during the warmup: the quest's key and what to do
var _subtitle: Label  # bottom centre, a line of story for a while (say)
var _left: Control  # the magazine's column
var _right: Control  # gold's column
var _banner: Label  # "Tezgâh açıldı", under the heap for a while
var _floats: CanvasLayer  # claimed money rising off the gold (_float_money)
var _pointer: Control  # arrows to what was just opened and to the board while something waits there
var _fence_row: HBoxContainer  # top centre: the railing's life
var _fence_bar: Control
var _fence_hp: Label
var _lost: Control  # the wave lost: a dark screen and "ÇİT YIKILDI"
var _lost_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.fit_screen(self)
	_build_heap()
	_build_sides()
	_build_middle()
	_build_corner()
	_build_quests()
	_build_fence()
	add_child(StyleRank.new())  # the style rank on the left (style_rank.gd)
	for s: StringName in [&"pile_changed", &"carried_changed", &"loaded_changed", &"gold_changed", &"vault_changed", &"specials_changed", &"placing_changed"]:
		GameState.connect(s, func(_a = null) -> void: refresh())
	GameState.upgraded.connect(refresh.unbind(2))
	GameState.gun_changed.connect(refresh.unbind(2))
	GameState.key_taken.connect(refresh.unbind(2))
	GameState.gold_changed.connect(func(_g: int) -> void: _pop(_gold))
	GameState.melter_changed.connect(func(_b: int, _r: int, _m: int, _p: int) -> void: _show_brass())
	GameState.quest_done.connect(_on_quest_done)
	GameState.quests_changed.connect(func(_b: Array, _p: Dictionary, _r: Array) -> void:
		_refresh_quests()
		refresh())
	GameState.fence_changed.connect(_on_fence)
	GameState.wave_cue.connect(_on_wave_cue)
	_build_pointer()
	refresh()
	_refresh_quests()


func _on_quest_done(id: String, gold: int) -> void:
	_claimed[id] = true
	if gold > 0:  # 0 when a joiner hears of quests done before it came
		_float_money(gold)
	var what: String = GameState.QUESTS[id].get("unlock", "")
	if what != "" and not what.begins_with("hud_"):
		_announce("%s açıldı" % NAMES.get(what, what))
	refresh()


## A claimed reward: "+$N" over the gold, rising and fading out. On a layer of its own, over the
## quest board's screen too.
func _float_money(gold: int) -> void:
	if _floats == null:
		_floats = CanvasLayer.new()
		_floats.layer = 7
		add_child(_floats)
	var l := UiStyle.stencil("+$" + UiStyle.dotted(gold), 46, UiStyle.MONEY)
	_floats.add_child(l)
	var at := _gold.get_global_rect() if _right.visible else Rect2(get_viewport_rect().size * Vector2(0.5, 0.62), Vector2.ZERO)
	l.reset_size()
	l.position = Vector2(at.end.x - l.size.x, at.position.y - l.size.y - 6)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 90, FLOAT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, FLOAT_TIME * 0.6).set_delay(FLOAT_TIME * 0.4)
	tw.chain().tween_callback(l.queue_free)


## One line under the heap for a few seconds: what just opened.
func _announce(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 0.0
	_banner.scale = Vector2.ONE * 1.25
	_banner.pivot_offset = _banner.size * 0.5
	var tw := _banner.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.35)
	tw.tween_interval(BANNER_TIME)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)


## Parts of the screen wait for what they show to be learnt.
func _shown(what: String) -> bool:
	return not GameState.warming() or GameState.unlocked(what)


func _main_kind() -> String:
	var main: String = GameState.quest_board[0] if not GameState.quest_board.is_empty() else ""
	return GameState.QUESTS[main].kind if main != "" else ""


## A line at the bottom for `secs`, over the warmup's hint and the Q, which come back after it.
var _say_tween: Tween


func say(text: String, secs: float) -> void:
	_subtitle.text = text
	_subtitle.visible = true
	_hint.visible = false
	refresh()
	if _say_tween:
		_say_tween.kill()  # an older line's fade would hide this one early
	var tw := _subtitle.create_tween()
	_say_tween = tw
	tw.tween_property(_subtitle, "modulate:a", 1.0, 0.5).from(0.0)
	tw.tween_interval(secs)
	tw.tween_property(_subtitle, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		_subtitle.visible = false
		_hint.set_meta("for", "")  # comes back in, faded in
		_refresh_quests()
		refresh())


func _build_pointer() -> void:
	_pointer = Control.new()
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pointer)
	_pointer.draw.connect(_draw_pointer)


func _process(_delta: float) -> void:
	_pointer.queue_redraw()
	_fence_row.visible = get_tree().get_first_node_in_group("waves") != null 			and (not GameState.warming() or GameState.fence < GameState.FENCE_MAX)
	if GameState.fence <= GameState.FENCE_MAX * FENCE_LOW:  # low: the gauge blinks
		_fence_bar.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 1000.0 * 5.0))
	else:
		_fence_bar.modulate.a = 1.0


## [world point, name] for each thing to point at.
func _point_targets() -> Array:
	var out := []
	for m: Node3D in get_tree().get_nodes_in_group("reveal_marker"):
		out.append([m.global_position + Vector3.UP * m.get_meta("height", 2.0), m.get_meta("label", "")])
	var waits := not GameState.quests_ready.is_empty() or GameState.quest_board.any(func(id: String) -> bool:
		return id != "" and GameState.QUESTS[id].kind == "board_claim")
	if waits:
		out.append([GameState.BOARD_POS + Vector3.UP * 2.3, "Pano"])
	# The warmup's next thing, even right in front of us: the pistol on its desk, then the heap.
	var kind := _main_kind() if GameState.warming() and not _subtitle.visible else ""
	var table := get_tree().get_first_node_in_group("gun_table") as Node3D
	if kind == "gun_taken" and table and not GameState.player().has_pistol:
		out.append([table.global_position + Vector3.UP * 1.3, "Tabanca", true])
	var heap := get_tree().get_first_node_in_group("bullet_pile") as Node3D
	if kind == "bullets_carried" and heap:
		out.append([heap.global_position + Vector3.UP * 3.0, "Mermi", true])
	return out


## On screen: a small chevron over the thing and its name. Off screen (or behind): an arrow at the
## screen's edge turned towards it.
func _draw_pointer() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _pointer.size.x <= POINT_EDGE * 2.0 or _pointer.size.y <= POINT_EDGE * 2.0:
		return
	var font := UiStyle.face(UiStyle.SEMIBOLD)
	var area := Rect2(Vector2.ZERO, _pointer.size)
	var inner := area.grow(-POINT_EDGE)
	var mid := area.get_center()
	for t: Array in _point_targets():
		var at: Vector3 = t[0]
		var name_: String = t[1]
		var s := cam.unproject_position(at) / scale
		var behind := cam.is_position_behind(at)
		var dist := cam.global_position.distance_to(at)
		var label := "%s  %dm" % [name_, roundi(dist)]
		if not behind and inner.has_point(s):
			if dist < 4.5 and t.size() < 3:
				continue  # right there: the crosshair's own hint says it
			var tip := s + Vector2(0, 8)
			_pointer.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-9, -12), tip + Vector2(9, -12)]), UiStyle.ACCENT)
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_pointer.draw_string_outline(font, s + Vector2(-w * 0.5, -14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, UiStyle.SHADOW)
			_pointer.draw_string(font, s + Vector2(-w * 0.5, -14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiStyle.ACCENT)
			continue
		var dir := (s - mid) * (-1.0 if behind else 1.0)
		if dir.length() < 1.0:
			dir = Vector2.DOWN
		dir = dir.normalized()
		# Out from the middle along dir until the inner rectangle's edge.
		var k := minf(absf((inner.size.x * 0.5) / dir.x) if dir.x != 0.0 else INF, absf((inner.size.y * 0.5) / dir.y) if dir.y != 0.0 else INF)
		var p := mid + dir * k
		var side := dir.orthogonal()
		_pointer.draw_colored_polygon(PackedVector2Array([p + dir * 16, p - dir * 8 + side * 12, p - dir * 8 - side * 12]), UiStyle.ACCENT)
		var w2 := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var lp := p - dir * 34 + Vector2(-w2 * 0.5, 5)
		_pointer.draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, UiStyle.SHADOW)
		_pointer.draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.ACCENT)


func _build_heap() -> void:
	var col := _column(Control.PRESET_TOP_LEFT)
	col.offset_left = MARGIN.x
	col.offset_top = MARGIN.y
	col.add_theme_constant_override("separation", 4)
	_heap = UiStyle.display("", 30, UiStyle.BOLD)
	col.add_child(_heap)
	_heap_meter = UiStyle.meter(HEAP_W, UiStyle.ACCENT, 3.0)
	_heap_meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_heap_meter)
	var under := HBoxContainer.new()  # the keys found, at the bar's right end
	under.custom_minimum_size.x = HEAP_W
	under.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	under.alignment = BoxContainer.ALIGNMENT_END
	under.add_theme_constant_override("separation", 5)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(under)
	under.add_child(UiStyle.icon("key", 15))
	_keys = UiStyle.caption("")
	under.add_child(_keys)
	_banner = UiStyle.display("", 24, UiStyle.BOLD, UiStyle.ACCENT)
	_banner.modulate.a = 0.0
	col.add_child(_banner)


func _build_fence() -> void:
	var col := _column(Control.PRESET_CENTER_TOP)
	col.offset_top = MARGIN.y
	_fence_row = HBoxContainer.new()
	_fence_row.add_theme_constant_override("separation", 10)
	_fence_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fence_row.visible = false
	col.add_child(_fence_row)
	_fence_row.add_child(UiStyle.icon("fence", 26, UiStyle.WHITE))
	_fence_bar = UiStyle.bar(FENCE_W, 14.0, "fence")
	_fence_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fence_row.add_child(_fence_bar)
	_fence_hp = UiStyle.stencil("", 26)
	_fence_hp.custom_minimum_size.x = 48
	_fence_row.add_child(_fence_hp)
	_lost = Control.new()  # over everything else on the HUD, under the menus
	_lost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lost.modulate.a = 0.0
	_lost.visible = false
	add_child(_lost)
	var dark := ColorRect.new()
	dark.color = Color(0.03, 0.0, 0.0, 0.85)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.name = "Dark"
	_lost.add_child(dark)
	var word := UiStyle.stencil("ÇİT YIKILDI", 96, UiStyle.WARN)
	word.name = "Word"
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	word.grow_horizontal = Control.GROW_DIRECTION_BOTH
	word.grow_vertical = Control.GROW_DIRECTION_BOTH
	_lost.add_child(word)
	_on_fence(GameState.fence, GameState.fence_wear)


func _on_fence(hp: int, _wear: Array) -> void:
	var was := int(_fence_hp.text) if _fence_hp.text != "" else hp
	_fence_hp.text = str(hp)
	_fence_hp.add_theme_color_override("font_color", UiStyle.WARN if hp <= GameState.FENCE_MAX * FENCE_LOW else UiStyle.WHITE)
	UiStyle.set_bar(_fence_bar, float(hp) / GameState.FENCE_MAX)
	if hp < was and _fence_row.visible:  # clawed: the row jolts
		_fence_row.pivot_offset = _fence_row.size * 0.5
		var tw := _fence_row.create_tween()
		tw.tween_property(_fence_row, "position:x", _fence_row.position.x + 4.0, 0.04)
		tw.tween_property(_fence_row, "position:x", _fence_row.position.x, 0.08)
	elif hp > was:
		_pop(_fence_hp)


## The wave lost (waves.gd FAILED): the word slams in and the screen darkens a little, then nearly
## black over the last of the pause, while the dead are cleared away; the next READY lifts it.
func _on_wave_cue(cue: Array) -> void:
	if cue[0] != &"phase":
		return
	var ph: int = cue[2]
	if ph == Waves.Phase.FAILED:
		if _lost_tween:
			_lost_tween.kill()
		_lost.visible = true
		var dark: ColorRect = _lost.get_node("Dark")
		var word: Label = _lost.get_node("Word")
		word.pivot_offset = word.size * 0.5
		dark.modulate.a = 0.3
		var tw := create_tween()
		_lost_tween = tw
		tw.tween_property(_lost, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(word, "scale", Vector2.ONE, 0.35).from(Vector2.ONE * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(0.0, Waves.FAIL_PAUSE - 1.6))
		tw.tween_property(dark, "modulate:a", 1.0, 1.0)
	elif _lost.visible:
		if _lost_tween:
			_lost_tween.kill()
		var tw := create_tween()
		_lost_tween = tw
		tw.tween_property(_lost, "modulate:a", 0.0, 0.9).set_delay(0.3)
		tw.tween_callback(func() -> void: _lost.visible = false)


func _build_sides() -> void:
	for right in [false, true]:
		var col := _column(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT)
		if right:
			_right = col
		else:
			_left = col
		col.offset_left = 0 if right else MARGIN.x
		col.offset_right = -MARGIN.x if right else 0
		col.offset_bottom = -MARGIN.y
		col.add_theme_constant_override("separation", -6)
		# No captions: the magazine and the gold are the two big numbers; under them, with an icon,
		# the hand (bullets) and the team's vault (a crate).
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(row)
		var big := UiStyle.stencil("", BIG, MONEY if right else UiStyle.WHITE)
		row.add_child(big)
		var under := HBoxContainer.new()
		under.alignment = row.alignment
		under.add_theme_constant_override("separation", 6)
		under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(under)
		var small := UiStyle.display("", 18, UiStyle.SEMIBOLD, UiStyle.DIM)
		if right:
			under.add_child(small)  # the team's vault, co-op only: "Takım $N"
			_gold = big
			_vault = small
			var brass := HBoxContainer.new()  # under it, once the hopper is open: its brass
			brass.alignment = BoxContainer.ALIGNMENT_END
			brass.add_theme_constant_override("separation", 6)
			brass.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(brass)
			brass.add_child(UiStyle.item("ingot", 24))
			_brass = UiStyle.display("", 18, UiStyle.SEMIBOLD, UiStyle.ACCENT)
			brass.add_child(_brass)
		else:
			_mag_caption = UiStyle.caption("")  # kept for the old callers, never shown
			under.add_child(UiStyle.item("round", 22))
			under.add_child(small)
			_mag = big
			_mag_of = UiStyle.stencil("", 28, UiStyle.DIM)
			_mag_of.size_flags_vertical = Control.SIZE_SHRINK_END
			row.add_child(_mag_of)
			_hand = small


func _build_middle() -> void:
	var col := _column(Control.PRESET_CENTER_BOTTOM)
	col.offset_bottom = -MARGIN.y
	col.add_theme_constant_override("separation", 14)
	_subtitle = UiStyle.label("", 24, UiStyle.SEMIBOLD)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size.x = 760
	_subtitle.visible = false
	col.add_child(_subtitle)
	_hint = HBoxContainer.new()  # filled per warmup quest (_show_hint)
	_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hint)
	_special_row = HBoxContainer.new()
	_special_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_special_row.add_theme_constant_override("separation", 12)
	_special_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_special_row)
	_special = UiStyle.label("", 15, UiStyle.SEMIBOLD)
	_special.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_special_row.add_child(_special)
	_special_hint = UiStyle.hint("R", "")
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
	_q = UiStyle.keycap("Q", 20)  # no Q menu any more (everything at the bench): kept hidden, it holds the corner's place
	_q.visible = false
	row.add_child(_q)
	_test = UiStyle.hint("T", "Sınırsız mermi")
	_test.alignment = BoxContainer.ALIGNMENT_END
	(_test.get_child(1) as Label).add_theme_color_override("font_color", UiStyle.ACCENT)
	corner.add_child(_test)


func _build_quests() -> void:
	# Under the Q, at the right edge: the left is the view's.
	# Typed on a sheet of paper, a little askew, like the orders pinned up on the range.
	_quests = VBoxContainer.new()
	_quests.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_q.get_parent().get_parent().add_child(gap)
	_sheet = PanelContainer.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.size_flags_horizontal = Control.SIZE_SHRINK_END
	_sheet.add_theme_stylebox_override("panel", UiStyle.paper_box(14))
	_sheet.rotation = deg_to_rad(-0.8)
	_sheet.add_child(_quests)
	_q.get_parent().get_parent().add_child(_sheet)
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
		var name_ := UiStyle.typed("", 17 if main else 14, UiStyle.PAPER_INK if main else UiStyle.PAPER_FADED)
		name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_)
		var share := UiStyle.typed("", 14 if main else 13, UiStyle.PAPER_FADED)
		share.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(share)
		var bar := UiStyle.meter(QUEST_W, UiStyle.PAPER_INK, 3.0 if main else 2.0)
		bar.color = Color(0, 0, 0, 0.1)  # the track, pencilled on the paper
		card.add_child(bar)
		_quests.add_child(card)
		if main:
			_quests.add_child(UiStyle.line(QUEST_W * 0.4, Color(0, 0, 0, 0.25)))  # the main quest over the rest
		_cards.append({"card": card, "tick": tick, "name": name_, "share": share, "bar": bar,
			"main": main, "id": "", "pulse": null})
	_claim = UiStyle.hint("E", "Pano")
	_claim.alignment = BoxContainer.ALIGNMENT_END
	(_claim.get_child(1) as Label).add_theme_font_override("font", UiStyle.TYPEWRITER)
	(_claim.get_child(1) as Label).add_theme_color_override("font_color", UiStyle.PAPER_GREEN)
	(_claim.get_child(1) as Label).add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_quests.add_child(_claim)


func _tick() -> Control:
	return UiStyle.icon("check", 16, UiStyle.PAPER_GREEN)


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
	_sheet.visible = not GameState.warming() and GameState.quest_board.any(func(id: String) -> bool: return id != "")
	_show_hint(GameState.quest_board[0] if not GameState.quest_board.is_empty() else "")


## The warmup quest's key and what to do, at the bottom; none past the warmup.
func _show_hint(id: String) -> void:
	var hint: Array = GameState.QUESTS[id].get("hint", []) if id != "" else []
	if _hint.get_meta("for", "") == id:
		return
	_hint.set_meta("for", id)
	for n in _hint.get_children():
		n.queue_free()
	_hint.visible = not hint.is_empty() and not _subtitle.visible
	if hint.is_empty():
		return
	var h := UiStyle.hint(hint[0], hint[1], 20)
	_hint.add_child(h)
	h.modulate.a = 0.0
	h.create_tween().tween_property(h, "modulate:a", 1.0, 0.4)


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
	if q.get("warmup", false):
		c.name.text = q.name  # one thing to do, said plainly; no count of 1
	else:
		c.name.text = "%s %s" % [what, UiStyle.dotted(target)]  # what to do beats a name nobody knows yet
	c.name.add_theme_color_override("font_color", UiStyle.PAPER_GREEN if ready else (UiStyle.PAPER_INK if c.main else UiStyle.PAPER_FADED))
	c.share.text = _reward_text(id)  # what it pays, from the start; the bar shows how far
	c.share.add_theme_color_override("font_color", UiStyle.PAPER_GREEN if ready else UiStyle.PAPER_FADED)
	(c.bar.get_child(0) as ColorRect).color = UiStyle.PAPER_GREEN if ready else (UiStyle.PAPER_INK if c.main else UiStyle.PAPER_FADED)
	UiStyle.set_meter(c.bar, float(have) / maxi(target, 1))
	c.tick.visible = ready
	_set_pulse(c, ready)


## The reward in a word or two: "+$30", "Parça", "Perk", what it opens.
func _reward_text(id: String) -> String:
	var q: Dictionary = GameState.QUESTS[id]
	if q.reward.has("gold"):
		return "+$" + UiStyle.dotted(q.reward.gold)
	if q.reward.has("part"):
		return "Parça"
	if q.reward.has("perk"):
		return NAMES.get(q.reward.perk, q.reward.perk)
	return NAMES.get(q.unlock, q.unlock) if q.has("unlock") else ""


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
	_keys.text = "%d/%d" % [p.keys.size(), KeyCache.KEYS.size()]
	_mag.text = str(GameState.carried if p.gun == 0 else GameState.loaded)  # bare fists: the hand is all there is
	_mag_of.text = "/%d" % (GameState.carry_capacity if p.gun == 0 else GameState.mag_capacity)
	_hand.text = "%d/%d" % [GameState.carried, GameState.carry_capacity]
	_hand.get_parent().visible = p.gun != 0
	_mag.add_theme_color_override("font_color", UiStyle.WARN if p.gun != 0 and GameState.loaded == 0 else UiStyle.WHITE)
	_gold.text = "$" + UiStyle.dotted(GameState.gold)
	_vault.text = "Takım $" + UiStyle.dotted(floori(GameState.vault))
	_vault.visible = GameState.team_vault()
	_show_brass()
	_special_row.visible = true
	if p.armed != "":
		_special.text = GameState.SPECIALS[p.armed].name
		_special.add_theme_color_override("font_color", UiStyle.ACCENT)
		_special_hint.visible = false
	elif not p.specials.is_empty():
		_special.text = "%s ×%d" % [GameState.SPECIALS[p.specials[0]].name, p.specials.size()] if p.specials.count(p.specials[0]) == p.specials.size() else "×%d" % p.specials.size()
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
	var can := GameState.UPGRADES.keys().any(func(id: String) -> bool:  # Q's, not the bench's
		var costs: Array = GameState.UPGRADES[id].costs
		if GameState.UPGRADES[id].get("bench", false):
			return false
		return p.levels[id] < costs.size() and GameState.gold >= costs[p.levels[id]])
	_can_buy.visible = false
	_test.visible = GameState.infinite_ammo
	# The warmup opens the screen bit by bit: gold with the bench once the pistol is taken, the hand
	# and guns once a bullet was (GameState QUESTS t00, t03).
	_left.visible = _shown("hud_ammo")
	_guns.visible = _shown("hud_ammo")
	_right.visible = _shown("workbench")


## The brass line: as often as the hopper melts, so only it.
func _show_brass() -> void:
	_brass.text = UiStyle.dotted(GameState.brass)
	_brass.get_parent().visible = GameState.unlocked("melter")


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
