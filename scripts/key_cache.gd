extends Node3D
## The twelve crate keys, buried in the scrap heap. Each game puts them somewhere new, but always
## costlier to reach the rarer they are (COSTS), so what a key is worth decides how much of the
## heap has to go before it can be reached.
##
## Why the cost is a hard gate: no slope in the heap stands steeper than Pile.LOCK_SLOPE, so before
## the surface over a key comes down to it, everything above a cone at that slope with its tip on
## the key has to go, however and wherever one digs (pile.gd min_take). A key is put where that
## cone holds its cost: the commons in the thin foot, reachable by hand from the floor, the
## legendaries deep under the roof.
## By hand the first fifteen minutes move ~1,500 pieces in all (docs/ajan_kritik/ekonomi.md).
##
## When digging gets down to a key it pops out onto the surface, glows in its tier's colour and
## lies there until someone walks over it. Placement and the reveal check run where the heap is
## simulated; GameState holds who has what (host-authoritative, like everything else).
## Co-op: the host rolls the layout's seed and sends it (GameState.key_layout); a client lays the
## keys out again from it on its own heap, which is the host's starting heap, so they land on the
## same spots. Only the host's heap decides when one comes out.

## Rank order, most common first: [name, tier]. Models: assets/props/keys/key_NN.glb
## (tools/build_keys.py). Key N opens crate N (scripts/chests.gd; 1-7 were picked to match theirs).
## The 6th opens the mid-game weapon, the 12th the minigun.
const KEYS := [
	["Asma Kilit Anahtarı", 0], ["Paslı Anahtar", 0], ["Kara Demir Anahtar", 0], ["İşlemeli Anahtar", 0],
	["Antika Anahtar", 1], ["Kafatası Anahtarı", 1], ["Buhar Anahtarı", 1], ["Demir İskelet", 1],
	["Viktorya Anahtarı", 1], ["Rulmanlı Anahtar", 2], ["Altın Düğüm", 2], ["Dişli Anahtar", 2],
]
const TIER_NAMES := ["Sıradan", "Nadir", "Efsanevi"]
const TIER_COLORS := [Color(0.85, 0.9, 1.0), Color(0.35, 0.65, 1.0), Color(1.0, 0.72, 0.2)]
## Least pieces dug before each key can come out, by rank: commons and rares what the bullet
## heap's depths cost (2026-10-21 numbers); commons by hand in the first twenty minutes, rares
## once belts dig. Legendaries go deep under the glass roof, where the heap is thickest: the
## cone there holds ~2M at most (4.4-10M on the bullet heap), and reaching one really means
## clearing the face in front of it, many times that.
# ponytail: placeholder until the 60-minute balance pass; keys_check.gd prints what each costs.
const COSTS := [34, 60, 103, 164, 75_900, 110_000, 153_000, 209_000, 285_000, 1_200_000, 1_400_000, 1_600_000]
const JITTER := 0.15       # ± fraction of a key's cost, so no two games match
const FLOOR_GAP := 0.15    # m of heap kept under a key: never on the bare floor
const SPACING := 1.5       # m between keys
## Surface height over a spot each tier may lie under, [low, high] m: commons in the foot, the
## others anywhere the heap is thick enough.
const BAND := [[0.3, 1.6], [1.0, 99.0], [9.5, 99.0]]
const TRIES := 260         # spots looked at per key
const MIN_DEPTH := 0.08    # m under the surface: a key is never showing from the start
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
var _cost := {}   # rank -> least pieces dug before it can come out, as buried
var _shown := {}  # rank -> Node3D while exposed
var _check := 0.0
var _toast: Label
var _toast_tween: Tween
var _reveal := AudioStreamPlayer3D.new()
var _take := AudioStreamPlayer.new()


func _ready() -> void:
	_pile = get_node(pile_path)
	_seed = layout_seed if layout_seed != 0 else GameState.key_seed  # the host's may be here already
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
	_cost.clear()
	GameState.key_states.clear()
	_bury()


## Where each key is: commonest first, each costing more than the one before. A spot in its
## tier's band, then the depth there whose cone holds the key's cost (cost grows with depth).
func _bury() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var placed: Array[Vector3] = []
	var prev := 0
	var cells: Vector2i = _pile.cells()
	for i in KEYS.size():
		var band: Array = BAND[KEYS[i][1]]
		var want := maxi(int(COSTS[i] * (1.0 + rng.randf_range(-JITTER, JITTER))), int(prev * 1.05) + 1)
		var best := Vector3.INF
		var best_cost := 0
		for attempt in TRIES:
			var g: Vector3 = _pile.cell_world(Vector2i(rng.randi_range(1, cells.x - 2), rng.randi_range(1, cells.y - 2)))
			var floor_y := _pile.global_position.y
			if g.y - floor_y < band[0] or g.y - floor_y > band[1]:
				continue
			var gap := SPACING if attempt < TRIES * 3 / 4 else SPACING * 0.5
			if placed.any(func(q: Vector3) -> bool: return Vector2(q.x - g.x, q.z - g.z).length() < gap):
				continue
			var lo := floor_y + FLOOR_GAP  # deepest allowed: costs the most
			var hi := g.y - MIN_DEPTH
			if lo >= hi:
				continue
			var most: int = _pile.min_take(Vector3(g.x, lo, g.z))
			if most < want:
				if most > best_cost and most > prev:
					best_cost = most
					best = Vector3(g.x, lo, g.z)
				continue
			for n in 18:  # cost falls as the key comes up: find where it holds `want`
				var mid := (lo + hi) * 0.5
				if _pile.min_take(Vector3(g.x, mid, g.z)) >= want:
					lo = mid
				else:
					hi = mid
			best = Vector3(g.x, lo, g.z)
			best_cost = _pile.min_take(best)
			break
		if best == Vector3.INF:
			push_error("key %d: no room for %d pieces" % [i + 1, want])
			continue
		placed.append(best)
		prev = best_cost
		_pos[i + 1] = best
		_depth[i + 1] = _pile.surface_y(best) - best.y
		_cost[i + 1] = best_cost
		GameState.key_states[i + 1] = GameState.KeyState.BURIED


## Where key `rank` is now (buried or lying out), and how deep it was put.
func key_position(rank: int) -> Vector3:
	return _pos.get(rank, Vector3.INF)


func key_depth(rank: int) -> float:
	return _depth.get(rank, 0.0)


## Least pieces that had to leave the heap before key `rank` could come out, as it was buried.
func key_cost(rank: int) -> int:
	return _cost.get(rank, 0)


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
					GameState.request_reveal_key(rank, Vector3(p.x, _pile.walk_y(p), p.z))
			GameState.KeyState.EXPOSED:
				_pos[rank] = Vector3(p.x, _pile.walk_y(p), p.z)  # on the pieces, riding the heap as it sinks
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
	_say("Yığından bir anahtar çıktı", TIER_COLORS[tier])


func _on_taken(rank: int, peer: int) -> void:
	if _shown.has(rank):
		(_shown[rank] as Node3D).queue_free()
		_shown.erase(rank)
	if peer != GameState.local_peer():
		return
	var tier: int = KEYS[rank - 1][1]
	_say("Anahtar alındı: %s (%s)" % [KEYS[rank - 1][0], TIER_NAMES[tier].to_lower()], TIER_COLORS[tier])
	if _take.stream:
		_take.play()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	# The count lives in the HUD under the heap (scripts/hud.gd); this is only the news.
	_toast = UiStyle.display("", 32, UiStyle.BOLD)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -500.0
	_toast.offset_right = 500.0
	_toast.offset_top = 112.0  # under the heap's lines (up to 1440p's HUD scale)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	hud.add_child(_toast)


func _say(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8)
