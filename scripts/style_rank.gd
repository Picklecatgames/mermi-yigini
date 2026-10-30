extends Control
## The style rank on the left of the screen (docs/ayrintilar.md "Stil sıralaması"): kills and
## flashy moves fill a meter, every TIER_SIZE points of it is a tier, D up to SSS. Nothing for a
## while (GRACE) and it melts away, faster the higher it is. A move done again soon pays less
## (`_stale`), so mixing them up is what climbs. Each player has their own, worked out on their own
## machine from the host's world signals (shot_landed, gun_changed, waves.gd's zombie_killed), with
## what only this machine knows about its own player (in the air) added in. Drawn with real
## assets: Rubik Wet Paint letters on grunge splatters, Kenney flares and sparks (assets/ui/style).
## A tier up slams the letter in, shakes it and flashes; the bar under it is what is left of the
## tier, melting. Sounds go in SOUNDS' paths once the user brings them.

const TIERS := ["D", "C", "B", "A", "S", "SS", "SSS"]
const TIER_SIZE := 100.0
const GRACE := 2.0  # s after the last gain before the meter starts to melt
const DRAIN := [6.0, 10.0, 14.0, 20.0, 28.0, 36.0, 46.0]  # points/s melting, by tier
const GAIN := [1.2, 1.0, 0.9, 0.75, 0.6, 0.5, 0.4]  # a gain's scale, by the tier it lands in
## Points a move is worth fresh. A kill is "kill" plus whichever of the rest it was.
const MOVES := {
	"kill": 22.0,   # a zombie down
	"head": 18.0,   # ... by the head
	"air": 20.0,    # ... or a hit, while off the floor
	"bounce": 28.0, # ... or a hit, off the bank-shot plate
	"swap": 18.0,   # within SWAP_TIME of drawing another gun
	"close": 22.0,  # a zombie down within CLOSE_DIST of the railing
	"hit": 3.0,     # a paying hit on a target
	"headhit": 5.0, # ... on its weak spot
	"combo": 8.0,   # the hit chain at a multiple of 5
}
const STALE_PER_USE := 1.0
const STALE_DECAY := 0.35  # 1/s: a move is fresh again after a few seconds of others
const STALE_K := 0.6  # pay = MOVES[m] / (1 + STALE_K * stale)
const STREAK_TIME := 2.0  # s between kills that keeps a streak going
const STREAK_PAY := 6.0  # each kill past the first in a streak, up to STREAK_MAX of them
const STREAK_MAX := 5
const SWAP_TIME := 2.0  # s
const CLOSE_DIST := 3.0  # m past the railing (GameState.FIRING_LINE_X)
const BOUNCE_MS := 150  # a hit this soon after a round glanced off the plate came off it
const HIT_TAKEN := 60.0  # points lost to a teammate's round, or 2/3 of it for firing one
## Sound slots: drop the user's recordings here (ogg or wav); nothing plays while they're missing.
const SOUNDS := {"up": "res://assets/sounds/style/rank_up_%d", "down": "res://assets/sounds/style/rank_down"}

# Look.
const FONT := preload("res://assets/fonts/RubikWetPaint-Regular.ttf")
const SPLATS := [preload("res://assets/ui/style/splat_0.png"), preload("res://assets/ui/style/splat_1.png"),
	preload("res://assets/ui/style/splat_2.png"), preload("res://assets/ui/style/splat_3.png"),
	preload("res://assets/ui/style/splat_4.png"), preload("res://assets/ui/style/splat_5.png")]
const DROPS := [preload("res://assets/ui/style/drops_0.png"), preload("res://assets/ui/style/drops_1.png")]
const STROKE := preload("res://assets/ui/style/stroke_thin.png")
const SMEAR := preload("res://assets/ui/style/stroke_wide.png")
const GLOW := preload("res://assets/ui/style/light_02.png")
const FLARE := preload("res://assets/ui/style/flare_01.png")
const RING := preload("res://assets/ui/style/circle_02.png")
const STARS := [preload("res://assets/ui/style/star_04.png"), preload("res://assets/ui/style/star_06.png"),
	preload("res://assets/ui/style/star_08.png")]
const BOLTS := [preload("res://assets/ui/style/spark_05.png"), preload("res://assets/ui/style/spark_06.png")]
const SWOOSH := preload("res://assets/ui/style/slash_02.png")
const COLORS := [Color(0.78, 0.75, 0.69), Color(0.82, 0.55, 0.3), Color(0.92, 0.7, 0.26), Color(1.0, 0.47, 0.14),
	Color(0.96, 0.17, 0.1), Color(0.9, 0.06, 0.32), Color(1.0, 0.86, 0.42)]
const AT := Vector2(150, 330)  # the letter's middle, in HUD px (1080 tall, UiStyle.fit_screen)
const LETTER := [96, 100, 106, 112, 122, 110, 98]  # px, by tier (SS/SSS are wider)
const BAR := Vector2(230, 52)  # px, the melting stroke under the letter
const SLAM_TIME := 0.22  # s, the letter coming down onto the screen
const FLASH_TIME := 0.5
const SHAKE := 16.0  # px at a tier up, dying out over SHAKE_TIME
const SHAKE_TIME := 0.4

var points := 0.0
var _since := GRACE  # s since the last gain
var _stale := {}  # move -> how used up it is
var _streak := 0
var _since_kill := INF
var _since_swap := INF
var _bounce_ms := -100000
var _kill_gun := ""  # the gun of the last kill (GameState.GUNS id)
var _waves: Node  # waves.gd, once it is in the world
var _tier := -1  # what is on screen
var _time := 0.0
var _slam := 1.0  # 0 → 1 as the letter comes down
var _flash := 0.0
var _shake := 0.0
var _down := 0.0  # 1 → 0 as a lost tier's letter falls away
var _lost := -1
var _alpha := 0.0
var _splat := 0
var _gained := 0.0  # a small kick on every gain
var _sound: AudioStreamPlayer
var _layers: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for draw: Callable in [_draw_back, _draw_glow, _draw_letter, _draw_sparks]:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if draw == _draw_glow or draw == _draw_sparks:
			c.material = add
		c.draw.connect(draw)
		add_child(c)
		_layers.append(c)
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -6.0
	add_child(_sound)
	GameState.shot_landed.connect(_on_shot_landed)
	GameState.gun_changed.connect(func(peer: int, _gun: int) -> void:
		if peer == GameState.local_peer():
			_since_swap = 0.0)
	GameState.player_shot.connect(func(shooter: int, victim: int, _at: Vector3, _d: Vector3, _s: String) -> void:
		if victim == GameState.local_peer():
			lose(HIT_TAKEN)
		elif shooter == GameState.local_peer():
			lose(HIT_TAKEN * 2.0 / 3.0))


func tier() -> int:
	return -1 if points <= 0.0 else mini(int(points / TIER_SIZE), TIERS.size() - 1)


## Of the tier's stretch of the meter, how much is left (the bar). SSS fills from 600 to 700.
func fill() -> float:
	return clampf(points / TIER_SIZE - tier(), 0.0, 1.0) if points > 0.0 else 0.0


## What `moves` together pay now (each one less the more it was just used), and then using them.
func gain(moves: Array) -> float:
	var total := 0.0
	for m: String in moves:
		total += MOVES[m] / (1.0 + STALE_K * _stale.get(m, 0.0))
		_stale[m] = _stale.get(m, 0.0) + STALE_PER_USE
	if moves.has("kill"):
		_streak = _streak + 1 if _since_kill < STREAK_TIME else 1
		_since_kill = 0.0
		total += STREAK_PAY * mini(_streak - 1, STREAK_MAX)  # many at once is always fresh
	total *= GAIN[maxi(tier(), 0)]
	points = minf(points + total, TIER_SIZE * TIERS.size() - 0.01)
	_since = 0.0
	_gained = 1.0
	_show()
	return total


func lose(amount: float) -> void:
	points = maxf(points - amount, 0.0)
	_since = 0.0  # no melting on top of it right away
	_show()


## Moves the meter on by `delta` s: melting after GRACE, the moves getting fresh again.
func step(delta: float) -> void:
	_since += delta
	_since_kill += delta
	_since_swap += delta
	for m: String in _stale:
		_stale[m] = maxf(_stale[m] - STALE_DECAY * delta, 0.0)
	if _since > GRACE and points > 0.0:
		points = maxf(points - DRAIN[tier()] * delta, 0.0)
	_show()


func _on_shot_landed(peer: int, at: Vector3, _n: Vector3, _d: Vector3, target: Node, gold: int, weak: bool, combo: int) -> void:
	if peer != GameState.local_peer():
		return
	if target and target.is_in_group("ricochet"):
		_bounce_ms = Time.get_ticks_msec()
		return
	if gold <= 0 and combo <= 0:
		return
	var moves := ["headhit" if weak else "hit"]
	moves.append_array(_flair())
	if combo > 0 and combo % 5 == 0:
		moves.append("combo")
	gain(moves)


## The wave code's kill (waves.gd zombie_killed, on every peer), `at` where the zombie stood.
## Downing one with another gun than the last one, soon after, counts as a swap too.
func _on_zombie_killed(peer: int, _kind: StringName, weak: bool, at: Vector3, gun: String) -> void:
	if peer != GameState.local_peer():
		return
	var moves := ["kill"]
	if weak:
		moves.append("head")
	moves.append_array(_flair())
	if not moves.has("swap") and _kill_gun != "" and gun != _kill_gun and _since_kill < SWAP_TIME * 2.0:
		moves.append("swap")
	_kill_gun = gun
	if at.x - GameState.FIRING_LINE_X < CLOSE_DIST:
		moves.append("close")
	gain(moves)


## The Waves node comes into the world after the HUD; its kills are hooked up once it is there.
func _hook_waves() -> void:
	var waves := get_tree().get_first_node_in_group("waves")
	if waves and waves.has_signal(&"zombie_killed"):
		waves.connect(&"zombie_killed", _on_zombie_killed)
		_waves = waves


## The moves a hit or kill right now is done with, besides itself.
func _flair() -> Array:
	var out := []
	var body := get_tree().get_first_node_in_group("walker") as CharacterBody3D
	if body and not body.is_on_floor():
		out.append("air")
	if Time.get_ticks_msec() - _bounce_ms < BOUNCE_MS:
		out.append("bounce")
	if _since_swap < SWAP_TIME:
		out.append("swap")
	return out


## Tier changes on screen: a slam up, a fall down.
func _show() -> void:
	var t := tier()
	if t == _tier:
		return
	if t > _tier:
		_slam = 0.0
		_flash = 1.0
		_shake = 1.0
		_splat = (_splat + 1 + randi() % (SPLATS.size() - 1)) % SPLATS.size()
		_play(SOUNDS.up % t)
	else:
		_lost = _tier
		_down = 1.0
		if t >= 0:
			_play(SOUNDS.down)
	_tier = t


func _play(base: String) -> void:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(base + ext):
			_sound.stream = load(base + ext)
			_sound.play()
			return


func _process(delta: float) -> void:
	if not is_instance_valid(_waves):
		_hook_waves()
	step(delta)
	_time += delta
	_slam = minf(_slam + delta / SLAM_TIME, 1.0)
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	_shake = maxf(_shake - delta / SHAKE_TIME, 0.0)
	_down = maxf(_down - delta / 0.45, 0.0)
	_gained = maxf(_gained - delta / 0.12, 0.0)
	_alpha = move_toward(_alpha, 1.0 if _tier >= 0 else 0.0, delta / 0.3)
	for c in _layers:
		c.queue_redraw()


func _energy() -> float:
	return maxf(_tier, 0) / float(TIERS.size() - 1)  # 0 at D, 1 at SSS


## Where the letter sits now: AT, shaken, lifted a hair on a gain.
func _center() -> Vector2:
	var e := _energy()
	var jitter := Vector2(sin(_time * 53.0), cos(_time * 47.0)) * SHAKE * _shake * _shake
	jitter += Vector2(sin(_time * 31.0), cos(_time * 37.0)) * (0.6 + 1.6 * e) * e  # SSS hums
	return AT + jitter + Vector2(0, -4) * _gained


func _color(t: int) -> Color:
	return COLORS[clampi(t, 0, COLORS.size() - 1)]


func _tex(c: Control, tex: Texture2D, at: Vector2, size: Vector2, rot: float, col: Color) -> void:
	c.draw_set_transform(at, rot, Vector2.ONE)
	c.draw_texture_rect(tex, Rect2(-size / 2.0, size), false, col)


## Under the letter: the tier's splatter, the smear behind the bar and the bar melting.
func _draw_back() -> void:
	var c := _layers[0]
	if _alpha <= 0.0 or _tier < 0:
		return
	var col := _color(_tier)
	var e := _energy()
	var at := _center()
	var grow := lerpf(1.6, 1.0, ease(_slam, 0.4))
	var s := (150.0 + 70.0 * e) * grow
	_tex(c, SPLATS[_splat], at + Vector2(-6, 4), Vector2(s * 1.15, s), -0.25 + 0.12 * _splat, Color(col.darkened(0.55), 0.82 * _alpha * _slam))
	# Thrown drops as it lands.
	if _flash > 0.0:
		var f := 1.0 - _flash
		for i in 2:
			var dir := Vector2.from_angle(-0.6 + 2.6 * i + _splat)
			_tex(c, DROPS[i], at + dir * (40.0 + 90.0 * f), Vector2(70, 70) * (0.6 + f), _splat + i, Color(col.darkened(0.3), _flash * _alpha))
	# The bar: a dark smear as the track, the tier's stroke cut to what is left of it.
	var bar := Rect2(at + Vector2(-BAR.x / 2.0 + 14, 70), BAR)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_texture_rect(SMEAR, bar.grow_individual(16, 6, 16, 6), false, Color(0, 0, 0, 0.55 * _alpha))
	var left := fill()
	var src := Rect2(Vector2.ZERO, Vector2(STROKE.get_width() * left, STROKE.get_height()))
	c.draw_texture_rect_region(STROKE, Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), src, Color(col.lightened(0.1), _alpha))


## Behind the letter, added light: a glow that breathes faster and brighter up the tiers, the
## tier up's flare and ring.
func _draw_glow() -> void:
	var c := _layers[1]
	if _alpha <= 0.0 or _tier < 0:
		return
	var col := _color(_tier)
	var e := _energy()
	var at := _center()
	var breathe := 0.5 + 0.5 * sin(_time * lerpf(2.0, 9.0, e))
	var g := (0.08 + 0.22 * e) * (0.75 + 0.25 * breathe) + 0.5 * _flash
	_tex(c, GLOW, at, Vector2(230, 230) * (1.0 + 0.25 * e), 0.0, Color(col, g * _alpha))
	if _flash > 0.0:
		var f := 1.0 - _flash
		_tex(c, RING, at, Vector2(120, 120) * (0.5 + 2.4 * f), 0.0, Color(col.lightened(0.3), _flash * _alpha))
		_tex(c, FLARE, at, Vector2(520, 160) * (0.6 + f), 0.0, Color(col.lightened(0.5), _flash * _alpha))
		_tex(c, SWOOSH, at + Vector2(0, 10), Vector2(260, 260) * (0.8 + 0.4 * f), PI, Color(col, 0.7 * _flash * _alpha))
	# SSS: lightning crackling up the sides now and then.
	if _tier == TIERS.size() - 1:
		var k := int(_time * 9.0)
		if k % 3 != 0:
			var side := -1.0 if k % 2 == 0 else 1.0
			_tex(c, BOLTS[k % 2], at + Vector2(side * 70, -6), Vector2(90, 200), side * 0.25 + (k % 5) * 0.05, Color(col.lightened(0.4), 0.8 * _alpha))


## The letter: slammed down from big, white hot at first; a lost tier's one falling away under it.
func _draw_letter() -> void:
	var c := _layers[2]
	if _down > 0.0 and _lost >= 0:
		var a := _down * _alpha
		_letter(c, _lost, AT + Vector2(-20, 60) * (1.0 - _down), 1.0 - 0.3 * (1.0 - _down), 0.4 * (1.0 - _down), Color(_color(_lost), a))
	if _alpha <= 0.0 or _tier < 0:
		return
	var t := ease(_slam, 0.35)
	var k := lerpf(2.6, 1.0, t) + 0.06 * _gained
	var tilt := -0.12 + 0.03 * sin(_time * (3.0 + 6.0 * _energy())) * _energy()
	var col := _color(_tier).lerp(Color.WHITE, 0.8 * _flash)
	_letter(c, _tier, _center(), k, tilt, Color(col, _alpha * clampf(_slam * 3.0, 0.0, 1.0)))


func _letter(c: Control, t: int, at: Vector2, k: float, rot: float, col: Color) -> void:
	var text: String = TIERS[t]
	var size: int = LETTER[t]
	var spacing := -size * 0.36 * (text.length() - 1) / maxf(text.length(), 1)
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing * (text.length() - 1)
	c.draw_set_transform(at, rot, Vector2.ONE * k)
	var x := -w / 2.0
	for i in text.length():
		var ch := text[i]
		var p := Vector2(x, size * 0.35)
		c.draw_string_outline(FONT, p + Vector2(4, 5), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0, 0, 0, 0.5 * col.a))
		c.draw_string_outline(FONT, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 9, Color(0.05, 0.03, 0.03, col.a))
		c.draw_string(FONT, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing


## Over the letter, added light: sparkles from S up, more and faster the higher.
func _draw_sparks() -> void:
	var c := _layers[3]
	if _alpha <= 0.0 or _tier < 4:
		return
	var col := _color(_tier).lightened(0.5)
	var n := 2 + (_tier - 4) * 2
	var at := _center()
	for i in n:
		var period := 0.9 - 0.15 * (_tier - 4)
		var ph := fmod(_time / period + i * 0.37, 1.0)
		var roll := int(_time / period + i * 0.37) * 7 + i * 13
		var spot := Vector2(float(roll * 37 % 140) - 70.0, float(roll * 53 % 110) - 60.0)
		var tw := sin(ph * PI)
		_tex(c, STARS[roll % STARS.size()], at + spot, Vector2(70, 70) * tw, ph * 1.5, Color(col, tw * _alpha))
