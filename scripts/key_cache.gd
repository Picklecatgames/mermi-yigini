extends Node3D
## The twelve crate keys, buried in the bullet heap. Each game puts them somewhere new, but always
## deeper the rarer they are (DEPTHS, measured down from the starting surface), so what a key is
## worth decides how much of the heap has to go before it can be reached.
##
## Why depth is a hard gate: the heap slides at its angle of repose, so uncovering a point D below
## the surface means digging out at least the 30° crater above it, π·D³ m³, however and wherever
## one digs; the sides pour back into anything narrower. `min_bullets(depth)` is that bound, and
## digging straight onto a key in the real heap costs about six times it (tools/keys_check.gd).
## By hand the first fifteen minutes move ~1,500 rounds in all (docs/ajan_kritik/ekonomi.md):
## a common key costs ~300-3,000 in one spot, a rare one ~0.5-1.6 million (belts), a legendary
## one 25 million and up (late automation). A minigun at minute 10 cannot happen.
##
## When digging gets down to a key it pops out onto the surface, glows in its tier's colour and
## lies there until someone walks over it. Placement and the reveal check run where the heap is
## simulated; GameState holds who has what (host-authoritative, like everything else).
## Co-op: the host rolls the layout's seed and sends it (GameState.key_layout); a client lays the
## keys out again from it on its own heap, which is the host's starting heap, so they land on the
## same spots. Only the host's heap decides when one comes out.

const PILE := preload("res://scripts/pile.gd")
## Rank order, most common first: [name, tier]. Models: assets/props/keys/key_NN.glb
## (tools/build_keys.py). Key N opens crate N (scripts/chests.gd; 1-7 were picked to match theirs).
## The 6th opens the mid-game weapon, the 12th the minigun.
const KEYS := [
	["Asma Kilit Anahtarı", 0], ["Paslı Anahtar", 0], ["Kara Demir Anahtar", 0], ["İşlemeli Anahtar", 0],
	["Antika Anahtar", 1], ["Kafatası Anahtarı", 1], ["Buhar Anahtarı", 1], ["Demir İskelet", 1],
	["Viktorya Anahtarı", 1], ["Rulmanlı Anahtar", 2], ["Altın Düğüm", 2], ["Dişli Anahtar", 2],
]
const TIER_NAMES := ["SIRADAN", "NADİR", "EFSANEVİ"]
const TIER_COLORS := [Color(0.85, 0.9, 1.0), Color(0.35, 0.65, 1.0), Color(1.0, 0.72, 0.2)]
## m below the starting surface, by rank. Commons by hand in the first twenty minutes, rares once
## belts dig, legendaries in the last quarter hour.
# ponytail: placeholder until the 60-minute balance pass; min_bullets() shows what each costs.
# ×∛3 since the 45° heap (2026-10-21): its narrower funnel costs a third, so the same rounds reach 1.44× deeper.
const DEPTHS := [0.05, 0.06, 0.072, 0.084, 0.65, 0.735, 0.82, 0.91, 1.01, 2.52, 2.88, 3.31]
const JITTER := 0.08       # ± fraction of a key's depth, so no two games match
const FLOOR_GAP := 0.15    # m of heap kept under a key: never on the bare floor
const SPACING := 1.5       # m between keys
## m from the heap's centre each tier may lie, [inner, outer]. Commons stay on the outer slopes:
## reachable by hand from the floor, and the same dig there costs a fraction of one higher up
## the heap, where everything above slides in (tools/keys_check.gd: ~1,000-3,000 rounds from
## 6 m out, 11,000-15,000 at 3.4-5.4 m).
const RING := [[5.0, 6.5], [0.0, 7.1], [0.0, 7.1]]
const CHECK_INTERVAL := 0.2  # s between looks at buried keys
const PICK_RADIUS := 1.2   # m from a walker's feet
const HOVER := 0.08        # m an exposed key floats over the surface
const SHOW_SCALE := 1.6    # keys are 8-13 cm; drawn a bit larger so they read in the heap

@export var pile_path: NodePath = ^"../Pile"
@export var reveal_sound: AudioStream
@export var take_sound: AudioStream
## 0: a new layout every game.
@export var layout_seed := 0

var _pile: Node3D
var _seed := 0
var _pos := {}    # rank -> world position: buried centre, then where it lies
var _depth := {}  # rank -> m below the starting surface
var _shown := {}  # rank -> Node3D while exposed
var _check := 0.0
var _toast: Label
var _count: Label
var _toast_tween: Tween
var _reveal := AudioStreamPlayer3D.new()
var _take := AudioStreamPlayer.new()


## Least rounds that must leave the heap before a key `depth` m down can be reached.
static func min_bullets(depth: float) -> int:
	# Funnel down to `depth` at the angle of repose: V = π·r²·D / 3 with r = D / SLOPE.
	return int(PI * depth * depth * depth / (3.0 * PILE.SLOPE * PILE.SLOPE * PILE.BULLET_VOLUME))


func _ready() -> void:
	_pile = get_node(pile_path)
	_seed = layout_seed
	while _seed == 0:
		_seed = randi()
	_bury()
	GameState.key_layout.connect(_on_layout)
	GameState.set_key_seed(_seed)
	_reveal.stream = reveal_sound
	_reveal.bus = &"Dunya"
	_reveal.unit_size = 10.0
	add_child(_reveal)
	_take.stream = take_sound
	add_child(_take)
	_build_hud()
	GameState.key_revealed.connect(_on_revealed)
	GameState.key_taken.connect(_on_taken)


## The host's layout: lay the keys out again from its seed.
# ponytail: assumes nothing came out yet (joining at the start); a mid-game join gets the key
# states with the heap (Faz 1/8).
func _on_layout(seed: int) -> void:
	if seed == 0 or seed == _seed:
		return
	_seed = seed
	for n: Node3D in _shown.values():
		n.queue_free()
	_shown.clear()
	_pos.clear()
	_depth.clear()
	GameState.key_states.clear()
	_bury()


## Where each key is, deepest first so the rare ones get the thick middle of the heap.
func _bury() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var placed: Array[Vector3] = []
	var depths: Array[float] = []
	var prev := 0.0
	for i in KEYS.size():  # depths in rank order, never shallower than the rank before
		prev = maxf(DEPTHS[i] * (1.0 + rng.randf_range(-JITTER, JITTER)), prev + 0.005)
		depths.append(prev)
	var centre := _pile.global_position
	for i in range(KEYS.size() - 1, -1, -1):
		var d := depths[i]
		var ring: Array = RING[KEYS[i][1]]
		var spot := Vector3.INF
		for attempt in 400:
			var a := rng.randf() * TAU
			var r := sqrt(lerpf(ring[0] * ring[0], ring[1] * ring[1], rng.randf()))  # even over the ring's area
			var p := centre + Vector3(cos(a) * r, 0.0, sin(a) * r)
			var top: float = _pile.surface_y(p)
			if top - centre.y - d < FLOOR_GAP:
				continue  # heap too thin here for this depth
			var gap := SPACING if attempt < 300 else SPACING * 0.5
			if placed.any(func(q: Vector3) -> bool: return Vector2(q.x - p.x, q.z - p.z).length() < gap):
				continue
			spot = Vector3(p.x, top - d, p.z)
			break
		if spot == Vector3.INF:
			push_error("key %d: no room %.2f m deep" % [i + 1, d])
			continue
		placed.append(spot)
		_pos[i + 1] = spot
		_depth[i + 1] = d
		GameState.key_states[i + 1] = GameState.KeyState.BURIED


## Where key `rank` is now (buried or lying out), and how deep it was put.
func key_position(rank: int) -> Vector3:
	return _pos.get(rank, Vector3.INF)


func key_depth(rank: int) -> float:
	return _depth.get(rank, 0.0)


func _physics_process(delta: float) -> void:
	_check += delta
	if _check < CHECK_INTERVAL:
		return
	_check = 0.0
	for rank: int in _pos:
		var p: Vector3 = _pos[rank]
		match GameState.key_states.get(rank):
			GameState.KeyState.BURIED:
				var top: float = _pile.surface_y(p)
				if top <= p.y + 0.03:
					GameState.request_reveal_key(rank, Vector3(p.x, top, p.z))
			GameState.KeyState.EXPOSED:
				_pos[rank] = Vector3(p.x, _pile.surface_y(p), p.z)  # rides the surface as it sinks
				for w: Node3D in get_tree().get_nodes_in_group("walker"):
					if w.global_position.distance_to(_pos[rank]) < PICK_RADIUS:
						GameState.request_take_key(rank)
						break


func _process(delta: float) -> void:
	for rank: int in _shown:
		var n: Node3D = _shown[rank]
		if n.has_meta("popping"):
			continue
		var t := Time.get_ticks_msec() * 0.001
		n.global_position = n.global_position.lerp(_pos[rank] + Vector3(0, HOVER + sin(t * 2.2 + rank) * 0.025, 0), minf(delta * 8.0, 1.0))
		n.rotate_y(delta * 1.4)
		(n.get_node("Glow") as OmniLight3D).light_energy = 0.9 + sin(t * 3.0 + rank) * 0.35


## Digging reached a key: it jumps out of the heap spinning and settles over the surface.
func _on_revealed(rank: int, at: Vector3) -> void:
	_pos[rank] = at
	var tier: int = KEYS[rank - 1][1]
	var n := Node3D.new()
	var model: Node3D = (load("res://assets/props/keys/key_%02d.glb" % rank) as PackedScene).instantiate()
	model.scale = Vector3.ONE * SHOW_SCALE
	n.add_child(model)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = TIER_COLORS[tier]
	glow.omni_range = 0.9 + tier * 0.4
	glow.shadow_enabled = false
	n.add_child(glow)
	add_child(n)
	n.global_position = at
	_shown[rank] = n
	n.set_meta("popping", true)
	var top := at + Vector3(0, 0.55 + tier * 0.25, 0)
	var t := n.create_tween()  # dies with the key if it is picked up mid-pop
	t.tween_property(n, "global_position", top, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(n, "rotation:y", TAU * 2.0, 0.65)
	t.tween_property(n, "global_position", at + Vector3(0, HOVER, 0), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: n.remove_meta("popping"))
	if _reveal.stream:
		_reveal.global_position = at
		_reveal.play()
	_say("YIĞINDAN BİR ANAHTAR ÇIKTI", TIER_COLORS[tier])


func _on_taken(rank: int, peer: int) -> void:
	if _shown.has(rank):
		(_shown[rank] as Node3D).queue_free()
		_shown.erase(rank)
	if peer != GameState.local_peer():
		return
	var tier: int = KEYS[rank - 1][1]
	_say("ANAHTAR: %s · %s" % [KEYS[rank - 1][0], TIER_NAMES[tier]], TIER_COLORS[tier])
	if _take.stream:
		_take.play()
	_count.text = "Anahtarlar: %d/%d" % [GameState.player().keys.size(), KEYS.size()]


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -400.0
	_toast.offset_right = 400.0
	_toast.offset_top = 90.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.modulate.a = 0.0
	hud.add_child(_toast)
	_count = Label.new()
	_count.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_count.offset_left = 16.0
	_count.offset_top = -44.0
	_count.add_theme_font_size_override("font_size", 20)
	_count.add_theme_constant_override("outline_size", 6)
	_count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_count.text = "Anahtarlar: 0/%d" % KEYS.size()
	hud.add_child(_count)


func _say(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8)
