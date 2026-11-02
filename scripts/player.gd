extends CharacterBody3D
## First-person player: walk, sprint, crouch, jump, mouse look, grab bullets from the pile.
## The body moves at the physics rate and is drawn interpolated (physics interpolation is on);
## the head is top level and placed every frame from the interpolated body plus the mouse look,
## so the view never waits a physics tick and never steps on a fast monitor.

const SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.002
const EYE := 1.6         # m, head above the feet
## Ctrl held: crouched. The eye where the bodies' eyes are in the crouching idle (~0.68 of standing,
## remote_players.gd), a capsule that fits under 1.3 m, a slow walk and no sprint.
const CROUCH_EYE := GameState.CROUCH_EYE
const STAND_HEIGHT := 1.8  # m, the capsule (player.tscn)
const CROUCH_HEIGHT := 1.3
const CROUCH_SPEED := 2.5
const CROUCH_RATE := 8.0  # 1/s the view goes down and back up at
const BOB_FREQ := 1.4    # bob cycles per metre walked, scaled by speed
const BOB_AMP := 0.05    # metres
const LAND_AIR_TIME := 0.15  # s in the air before touching down counts as a landing step
const HAND_MAX := 6      # bullets drawn in hand; more are carried but not shown
const ARMED_RISE := 0.6  # bullet lengths/2.9: the armed special stands this far up out of the row
const SPECIAL_IN_HAND := 1.15  # a special round in hand, this many times a plain one
const SPECIAL_ROOM := 1.6  # its share of the row (plain round 1.1): tips are at most 1.25 across (tools/build_tips.py)
const AMMO_WHEEL := preload("res://scripts/ammo_wheel.gd")
const HUD := preload("res://scripts/hud.gd")
const BENCH_MENU := preload("res://scripts/bench_menu.gd")
const BOARD_MENU := preload("res://scripts/quest_board.gd")
const MELTER_MENU := preload("res://scripts/melter_menu.gd")
const PRESS_MENU := preload("res://scripts/press_menu.gd")
const CHARACTER_PICK := preload("res://scripts/character_pick.gd")
const LASER_DOT := Vector2(0.03, 0.012)  # m across the dot: at least, and per metre away (stays visible far off)
const LASER_BEAM := Vector2(0.0006, 0.0005)  # m beam radius at the lens, and per metre on: about a pixel all the way
const WHEEL_HOLD := 0.22  # s R is held before the ammo wheel opens; a shorter press reloads
## Special rounds that hit us (GameState.SPECIALS). Punch: thrown off somewhere near the shot's
## way, tumbling, bounced once on landing, then dizzy for a while: the view sways, the aim drifts,
## the legs wander.
const PUNCH_SPEED := Vector2(17.0, 26.0)  # m/s, picked between
const PUNCH_UP := Vector2(5.5, 8.5)       # m/s; never added on top of a flight already going up
const PUNCH_SPREAD := 0.7  # rad either way off the shot's line
const PUNCH_TUMBLE := Vector2(5.0, 11.0)  # rad/s the view turns over at, on two axes, while flying
const PUNCH_BOUNCE := 0.55  # of the speed kept by the one bounce, off somewhere else
const AIR_DRAG := 0.4      # 1/s: a shove dies slowly in the air, SHOVE_DECAY on the floor
const DIZZY_TIME := 4.0    # s from the hit, fading out
const DIZZY_ROLL := 0.28   # rad the view sways to either side
const DIZZY_DRIFT := Vector2(0.9, 0.5)  # rad/s the aim wanders, sideways and up/down
const DIZZY_WALK := 1.1    # rad the legs head off from where we steer
## The hall: nothing may throw us out of it or over the railing (walls stop 4 m up, the railing
## 3 m, a punch flies higher).
const HALL_IN := 27.6  # m from the centre to a wall's inner face, less our radius
const ROOF_IN := 6.0   # m: the feet stay this low, under the roof beams
const LANTERN_IN := Vector2(14.6, 13.6)  # the glass roof's footprint (build_arena LANTERN) less our radius
const LANTERN_ROOF_IN := 9.5  # m: under the glass the roof is 11.6 m up, so the ~7 m heap's top stays climbable
## Balloon: up for BALLOON_TIME, then a slow drift down; ~8 s in all from the floor (4 m up, under
## the 8 m roof beam even from a step).
const BALLOON_TIME := 4.0  # s
const BALLOON_RISE := 1.0  # m/s
const BALLOON_FALL := 1.0  # m/s at most on the way down
const CHARACTER_DEMO := preload("res://scripts/character_demo.gd")  # K, debug builds, solo
## Scream: the clown's face rushes at the view, holds, shakes, is gone. Its sound is the user's
## recording, played if it is there (no sound is made in code).
const SCREAM_FACE := preload("res://assets/bullet/tips/scream_face.glb")
const SCREAM_RUSH := 0.05  # s: the face lands as the sound's first full blast does (its lead-in is cut)
const SCREAM_HOLD := 0.9  # s: until the scream starts to die down
const SCREAM_DB := 7.6  # the recording is at full scale already; the master limiter catches the rest
const SPECIAL_SOUND := "res://assets/sounds/specials/%s.wav"  # per SPECIALS id
const GRAB_TIME := 0.25  # s for one piece to fly into the hand
const GRAB_GAP := 0.08   # s between bullets of one grab
## Scrap carried: the pieces themselves, shrunk, in a row low in the middle of the view (the gun
## goes down while there is any, viewmodel.gd stowed).
const SCRAP_HAND_POS := Vector3(0.0, -0.15, -0.4)
const SCRAP_IN_HAND := 0.055  # m, a piece in hand at its longest
const SCRAP_STEP := 0.05      # m between pieces in the row
const CASE := preload("res://assets/bullet/bullet_case.glb")  # special rounds: case + TipSocket
const GRAB_REPEAT := 0.02  # s between grabs while E is held
const FLY_POOL := 16       # bullets in flight at most: GRAB_TIME / GRAB_REPEAT plus slack
## View kick: a critically damped spring, so the climb takes a few frames instead of one.
const KICK_OMEGA := 28.0     # rad/s; peak at 1 / KICK_OMEGA ≈ 36 ms
const KICK_CLIMB := 0.35     # share of the kick that stays as aim climb
## Shake: each round adds to a trauma (viewmodel.gd SETS shake) that runs down at SHAKE_DECAY a second;
## the camera wobbles by its square on smooth noise, mostly in roll so the aim point barely moves.
## A spinning gun keeps it at SPIN_SHAKE times its barrel speed. Settings "screen_shake" scales it.
const SHAKE_DECAY := 2.5
const SHAKE_MAX := Vector3(0.006, 0.006, 0.03)  # rad pitch, yaw, roll at full trauma
const SHAKE_SPEED := 24.0  # noise units a second: the wobble's pace
const SPIN_SHAKE := 0.3
## A kill of ours narrows the view for a blink (deg), springing back: a felt "got it", not a zoom.
const KILL_PUNCH := 0.9
const HEAD_PUNCH := 1.6
const PUNCH_OMEGA := 22.0
const ADS_ZOOM := 1.25  # magnification when aimed down the sights
const ADS_WALK := 0.6  # share of walking speed left aimed: aiming while moving is allowed, slowly
const POSE_INTERVAL := 0.05  # s: the body goes out to the other players 20 times a second
const AIR_SHOWN := 0.1  # s off the ground before others see a jump (not every bump and step)
## Walking into another player shoves them with this share of your speed into them; you stay
## in touch and push them along at a crawl. Sent at most every PUSH_INTERVAL.
const PUSH_SHARE := 0.9
const PUSH_INTERVAL := 0.1  # s
const SHOVE_DECAY := 6.0  # 1/s: a shove dies out in about half a second
## Friendly fire throws the aim: up by FF_CLIMB and sideways by up to FF_YAW (rad), eased in.
const FF_CLIMB := Vector2(0.05, 0.1)
const FF_YAW := 0.09
const FF_KICK := 0.06  # rad of view jolt on top
const DOWN_VIEW := preload("res://scripts/down_view.gd")
## Down (GameState.player_downed, docs/ayrintilar.md "Baygınlık"): the view drops to the floor and
## tips over on its side; once dark (GameState.DOWN_TIME) it looks through a standing teammate's
## eyes, left and right click for the next one. Numbers are first guesses.
const DOWN_EYE := 0.22  # m over the feet
const DOWN_ROLL := 1.35  # rad the view tips over
const DOWN_FALL := 0.6  # s to get down there (and back up, revived)
const HURT_SHAKE := 0.55  # trauma a blow adds
const HURT_KICK := 0.05  # rad the view jolts

var _grab_timer := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _climb := 0.0  # rad of aim climb still to add
var _bob := 0.0
var _bob_offset := Vector3.ZERO
var _bob_amount := 0.0  # 0..1, fades the bob in and out without lagging its phase
var _air_time := 0.0
var _recoil := 0.0  # rad of view kick
var _recoil_vel := 0.0
var _trauma := 0.0  # 0..1, see SHAKE_DECAY
var _shake := Vector3.ZERO  # rad pitch, yaw, roll this frame
var _shake_t := 0.0
var _shake_noise := FastNoiseLite.new()
var _punch := 0.0  # deg off the fov
var _punch_vel := 0.0
var _fly: Array[MeshInstance3D] = []
var _next_fly := 0
var _scrap_hand: Node3D  # the scrap carried, shrunk (SCRAP_HAND_POS)
var _scrap_looks: Array[Array] = []  # pile.gd piece_look of the first HAND_MAX pieces carried
var _vm_env: Environment
var _hip_fov := 75.0
var _zoom := 1.0
var _pose_timer := 0.0
var _shove := Vector3.ZERO  # m/s from someone walking into us
var _push_timer := 0.0
var _yaw_climb := 0.0  # rad of sideways aim still to add (friendly fire)
var _wheel: Control  # scripts/ammo_wheel.gd: hold R to pick a round, and the "found one" note
var _pocket_seen: Array[String] = []  # the pocket as last shown, to spot a new special
var _reload_held := 0.0  # s R has been down
var _balloon := 0.0  # s of rising left (balloon round)
var _drifting := false  # coming down slowly after the balloons
var _tumble := Vector2.ZERO  # rad of view turn-over (pitch, roll) from a punch round
var _tumble_vel := Vector2.ZERO  # rad/s while flying
var _bounces := 0  # punch round bounces left
var _dizzy := 0.0  # s left
var _dizzy_t := 0.0  # s into it, for the sways
var _special_sound: AudioStreamPlayer
var crouched := false
var _crouch_view := 0.0  # 0..1, the eye on its way between EYE and CROUCH_EYE
var _down_view := 0.0  # 0..1, the eye on its way down to the floor
var watching := 0  # the teammate whose eyes we look through while down, 0 none
var _down_ui: Control  # scripts/down_view.gd

@onready var _head: Node3D = $Head
@onready var _collision: CollisionShape3D = $Collision
@onready var _shop: CanvasLayer = $UpgradeMenu
var _bench: CanvasLayer = BENCH_MENU.new()  # the workshop bench's view (E in front of it)
var _board_menu: CanvasLayer = BOARD_MENU.new()  # the quest board's screen (E in front of it)
var _melter: CanvasLayer = MELTER_MENU.new()  # the hopper's screen (E beside it pours the hand in)
var _press: CanvasLayer = PRESS_MENU.new()  # the press's screen (E in front of it)
var _pick: CanvasLayer = CHARACTER_PICK.new()  # who to play as, until picked (GameState.CHARACTERS)
var _laser_dot := MeshInstance3D.new()  # where the bought laser says the shot will land
var _laser_beam := MeshInstance3D.new()  # from the laser's lens to the dot, through the air
@onready var _step_sound: AudioStreamPlayer3D = $StepSound
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _reach: RayCast3D = $Head/Camera3D/Reach
@onready var _hand: Node3D = $Head/Camera3D/Hand
@onready var _prompt: Label = $HUD/Prompt  # the scene's old text prompt, freed: key caps replace it
var _grab_hint: Control  # under the crosshair while looking at the heap
var _full_hint: Control
var _board_hint: Control  # at the quest board while something waits there (E claims)
var _bench_hint: Control  # at the open bench (E sits down at it)
var _melt_hint: Control  # at the hopper with rounds in the hand (E pours them in)
var _hopper_hint: Control  # at the hopper, the hand empty (E shows how it melts)
var _press_hint: Control  # at the press (E makes rounds)
var _lever_hint: Control  # at the wave lever with a wave waiting (E pulls it, scripts/waves.gd)
var _table_hint: Control  # looking at the desk at the spawn with the pistol on it (E takes it)
var _hud: Control
## The pistol taken in the warmup, the view turns to the heap while the line about it is said.
const HEAP_LINE := "Bu mermilerin altına 100 milyon dolarlık bir çek bıraktım. Almak istiyorsan mermilerden kurtul."
const HEAP_LINE_TIME := 5.0  # s
const HEAP_TURN := 1.2  # s
var _steered := false  # the view is being turned for us: the mouse waits
@onready var _crosshair: Control = $HUD/Crosshair
@onready var _hit_marker: Control = $HUD/HitMarker
@onready var _vm_camera: Camera3D = $ViewmodelView/SubViewport/Camera
@onready var _viewmodel: Node3D = $ViewmodelView/SubViewport/Camera/Viewmodel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("walker")  # kicks loose bullets around (Pile)
	# The heap stands at 45° and its height field's diagonals reach ~55°: at the default 45° those
	# faces were walls and we snagged on its sides.
	floor_max_angle = deg_to_rad(60.0)
	_collision.shape = _collision.shape.duplicate()  # crouching resizes it
	_go_to_spawn(GameState.spawn_index)
	GameState.spawn_assigned.connect(_go_to_spawn)
	_hip_fov = _camera.fov
	_head.top_level = true
	_head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # placed per frame
	_vm_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_reach.add_exception(self)
	GameState.carried_changed.connect(func(c: int) -> void: _set_hand_count(mini(c, HAND_MAX)))
	# The HUD (scripts/hud.gd, UiStyle) draws counts, gold and guns itself; the scene's old
	# labels stay hidden until the scene's owner takes them out.
	for old: Control in [$HUD/Counter, $HUD/Money, $HUD/Vault]:
		old.visible = false
	_hud = HUD.new()
	$HUD.add_child(_hud)
	_prompt.queue_free()
	_grab_hint = _crosshair_hint(UiStyle.hint("E", "Basılı tut: hurda al"))
	_full_hint = _crosshair_hint(UiStyle.hint("G", "Elin dolu: fırlat"))
	_board_hint = _crosshair_hint(UiStyle.hint("E", "Görev panosu"))
	_bench_hint = _crosshair_hint(UiStyle.hint("E", "Tezgâh: silahını geliştir"))
	_melt_hint = _crosshair_hint(UiStyle.hint("E", "Kurşunları erit"))
	_hopper_hint = _crosshair_hint(UiStyle.hint("E", "Eritme hunisi"))
	_press_hint = _crosshair_hint(UiStyle.hint("E", "Mermi üret"))
	_lever_hint = _crosshair_hint(UiStyle.hint("E", "Dalgayı başlat"))
	add_child(_bench)
	add_child(_board_menu)
	add_child(_melter)
	add_child(_press)
	add_child(_pick)
	_make_laser_dot()
	_table_hint = _crosshair_hint(UiStyle.hint("E", "Tabancayı al"))
	_setup_viewmodel_world()
	_viewmodel.setup(self)
	_viewmodel.kicked.connect(func(a: float, yaw: float) -> void:
		_climb += a * KICK_CLIMB
		_yaw_climb += yaw
		_recoil_vel += a * (1.0 - KICK_CLIMB) * KICK_OMEGA * exp(1.0))  # peak = v / (w·e)
	_viewmodel.shook.connect(func(t: float) -> void:
		_trauma = minf(_trauma + t, 1.0))
	_shake_noise.frequency = 1.0
	GameState.wave_cue.connect(func(cue: Array) -> void:
		if cue[0] == &"die" and cue[3] == GameState.local_peer():
			_punch_vel -= (HEAD_PUNCH if cue[4] else KILL_PUNCH) * PUNCH_OMEGA * exp(1.0))
	_viewmodel.equip(GameState.player().gun)
	GameState.gun_changed.connect(func(peer: int, gun: int) -> void:
		if peer == GameState.local_peer():
			_viewmodel.equip(gun))
	_scrap_hand = Node3D.new()
	_scrap_hand.position = SCRAP_HAND_POS
	_camera.add_child(_scrap_hand)
	for i in FLY_POOL:
		var b := MeshInstance3D.new()
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.visible = false
		b.top_level = true
		b.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # tweened per frame
		add_child(b)
		_fly.append(b)
	GameState.pushed.connect(func(v: Vector3) -> void:
		if v.length() > _shove.length() and not GameState.is_down():
			_shove = v)
	GameState.player_shot.connect(_on_player_shot)
	_wheel = AMMO_WHEEL.new()
	$HUD.add_child(_wheel)
	_down_ui = DOWN_VIEW.new()
	_down_ui.player = self
	$HUD.add_child(_down_ui)
	GameState.health_changed.connect(func(peer: int, _hp: float, _from: Vector3, hurt: bool) -> void:
		if hurt and peer == GameState.local_peer():
			_trauma = minf(_trauma + HURT_SHAKE, 1.0)
			_recoil_vel += HURT_KICK * KICK_OMEGA * exp(1.0))
	GameState.player_downed.connect(func(peer: int) -> void:
		if peer == GameState.local_peer():
			_go_down())
	GameState.player_revived.connect(func(peer: int) -> void:
		if peer == GameState.local_peer():
			_watch(0))
	_wheel.picked.connect(_on_wheel_picked)
	_pocket_seen = GameState.player().specials.duplicate()
	_special_sound = AudioStreamPlayer.new()  # in our ears only: it is our scare
	_special_sound.max_polyphony = 2
	add_child(_special_sound)
	GameState.specials_changed.connect(_on_specials_changed)
	_set_hand_count(mini(GameState.carried, HAND_MAX))
	_place_head()


## Friendly fire: it doesn't hurt, but it throws the aim off right when you need it.
func _on_player_shot(_shooter: int, victim: int, _at: Vector3, dir: Vector3, special: String) -> void:
	if victim != GameState.local_peer():
		return
	_hit_by_special(special, dir)
	_climb += randf_range(FF_CLIMB.x, FF_CLIMB.y)
	_yaw_climb += randf_range(-FF_YAW, FF_YAW)
	_recoil_vel += FF_KICK * KICK_OMEGA * exp(1.0)


## A punch round's throw: along the shot, give or take PUNCH_SPREAD, at a speed of its own.
static func punch_shove(dir: Vector3) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z).normalized().rotated(Vector3.UP, randf_range(-PUNCH_SPREAD, PUNCH_SPREAD))
	return flat * randf_range(PUNCH_SPEED.x, PUNCH_SPEED.y)


## A punch round's one bounce: landing still going fast, off again somewhere else.
static func punch_bounce(shove: Vector3) -> Vector3:
	return shove.rotated(Vector3.UP, randf_range(-1.6, 1.6)) * PUNCH_BOUNCE


## Keeps `body` in the hall and on its side of the railing (`inside`: it was there before moving).
static func keep_in_hall(body: CharacterBody3D, inside: bool) -> void:
	var p := body.global_position
	var x_max := GameState.FIRING_LINE_X - 0.4 if inside else INF
	var roof := LANTERN_ROOF_IN if absf(p.x) < LANTERN_IN.x and absf(p.z) < LANTERN_IN.y else ROOF_IN
	var c := Vector3(clampf(p.x, -HALL_IN, x_max), minf(p.y, roof), clampf(p.z, -HALL_IN, HALL_IN))
	if c != p:
		body.global_position = c
		if c.y < p.y:
			body.velocity.y = minf(body.velocity.y, 0.0)


## A teammate's special round hit us (GameState.SPECIALS); "" was a plain one. Everyone moves
## their own body, so it all plays out here, on the hit player's machine.
func _hit_by_special(special: String, dir: Vector3) -> void:
	if special == "":
		return
	var path := SPECIAL_SOUND % special
	if ResourceLoader.exists(path):
		_special_sound.stream = load(path)
		_special_sound.volume_db = SCREAM_DB if special == "scream" else 0.0
		_special_sound.play()
	match special:
		"punch":
			_shove = punch_shove(dir)
			if velocity.y <= 0.0:  # hit again on the way up: no higher (over the walls)
				velocity.y = randf_range(PUNCH_UP.x, PUNCH_UP.y)
			_tumble_vel = Vector2(randf_range(PUNCH_TUMBLE.x, PUNCH_TUMBLE.y) * signf(randf() - 0.5),
				randf_range(PUNCH_TUMBLE.x, PUNCH_TUMBLE.y) * signf(randf() - 0.5))
			_bounces = 1
			_dizzy = DIZZY_TIME
			_dizzy_t = randf() * 10.0  # each time a different sway
		"balloon":
			_balloon = BALLOON_TIME
			_drifting = true
		"scream":
			_jumpscare()


## The clown's face over everything (drawn by the gun's camera, on its layer): it rushes in from
## the dark, fills the view, shakes, and is gone.
func _jumpscare() -> void:
	var face: Node3D = SCREAM_FACE.instantiate()
	for m: MeshInstance3D in face.find_children("*", "MeshInstance3D"):
		m.layers = 1 << 1
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()  # the face looks at +Z (at us) with its crown on +X: stood upright
	holder.add_child(face)
	face.rotation.z = PI / 2.0
	face.position = Vector3(0.0, -0.5, 0.0)  # its chin is the origin: centre the head
	_vm_camera.add_child(holder)
	var t := holder.create_tween()
	# The head is 1 m tall; at 0.8 m the gun camera's ~50° shows 0.75 m of it: a bit over the view.
	t.tween_property(holder, "position", Vector3(0.0, 0.0, -0.8), SCREAM_RUSH).from(Vector3(0.0, 0.0, -6.0)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_method(func(f: float) -> void:
		holder.position = Vector3(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03), -0.8 + f * 0.1), 0.0, 1.0, SCREAM_HOLD)
	t.tween_callback(holder.queue_free)
	_recoil_vel += FF_KICK * 3.0 * KICK_OMEGA * exp(1.0)  # we flinch


## Solo and the host stand on the first spawn point; each guest gets its own from the host.
func _go_to_spawn(index: int) -> void:
	var spawns := get_tree().get_nodes_in_group("spawn")
	if spawns.is_empty():
		return
	global_transform = (spawns[index % spawns.size()] as Node3D).global_transform
	_yaw = rotation.y
	_pitch = 0.0
	velocity = Vector3.ZERO
	reset_physics_interpolation()


## What other machines show this player doing.
func _act() -> int:
	var clip: String = _viewmodel.clip
	if clip == "fire" and GameState.player().gun != 0:
		return GameState.Act.SHOOTING
	if clip.begins_with("reload"):
		return GameState.Act.RELOADING
	return GameState.Act.WALKING if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.1 else GameState.Act.IDLE


## What other machines show as the gun up at the shoulder: the sights up, or a spinning gun's
## barrels turning (its aim button), as opposed to held low and relaxed.
func aiming() -> bool:
	return _viewmodel.aim > 0.5 or _viewmodel.spin > 0.0


## The gun shares the hall's world, drawn by its own camera (its layer only, at its own fov) over
## the player's view: the hall's lamps and the heap's spots light it, so steel glints under a lamp.
## Its viewport draws no shadows
## (player.tscn) and its camera's environment leaves out what would cost a second time or haze
## it: SDFGI, fog, SSAO, and glow, which halos the gun over the clear background.
func _setup_viewmodel_world() -> void:
	_vm_env = get_world_3d().environment.duplicate()
	# The copy carries the hall's effects as Settings remembered them, and Settings switched SSR,
	# SSAO, fog and glow back on over the gun: SSR (which a transparent viewport drops) took the
	# place of its reflections and the steel and the gold skin drew black. It remembers ours.
	_vm_env.remove_meta(&"built")
	_vm_env.background_mode = Environment.BG_CLEAR_COLOR
	_vm_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_vm_env.ambient_light_color = Color(0.55, 0.53, 0.5)
	_vm_env.ambient_light_energy = 0.55  # roughly what the lamps bounce onto it
	# The steel reflects this (materials/viewmodel_sky.gdshader: LED battens on a dark roof, lit
	# concrete); never drawn, the background stays clear. Not the hall's probes: they hold the night
	# under the glass roof, and in them the gun mirrored black.
	for probe: ReflectionProbe in get_parent().find_children("*", "ReflectionProbe", true, false):
		probe.reflection_mask &= ~(1 << (_viewmodel.LAYER - 1))
	var sky := ShaderMaterial.new()
	sky.shader = preload("res://materials/viewmodel_sky.gdshader")
	_vm_env.sky = Sky.new()
	_vm_env.sky.sky_material = sky
	_vm_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_vm_env.ssao_enabled = false
	_vm_env.ssil_enabled = false
	_vm_env.sdfgi_enabled = false
	_vm_env.volumetric_fog_enabled = false
	_vm_env.glow_enabled = false
	_vm_env.ssr_enabled = false
	_vm_camera.environment = _vm_env
	# A soft key light from over the left shoulder keeps the gun readable between lamps, and a rim
	# from ahead draws a thin line on edges; both on the gun's layer only, or they would light the hall.
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.96, 0.9)
	key.light_energy = 2.2
	key.rotation = Vector3(-0.65, 0.4, 0.0)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.85, 0.9, 1.0)
	rim.light_energy = 0.8
	rim.light_specular = 3.0
	rim.rotation = Vector3(-0.35, PI - 0.6, 0.0)
	for l: DirectionalLight3D in [key, rim]:
		l.light_cull_mask = 1 << 1
		_vm_camera.add_child(l)


## The laser bought at the bench (GameState UPGRADES) on the Deagle in hand: a red dot where the
## shot would land now, along the same line viewmodel.gd fires down (sway, no spread), and a thin
## beam to it from its lens. The dot stands in for the crosshair, which would sit right on it.
func _aim_laser(off: Vector2) -> void:
	var p := GameState.player()
	var on: bool = GameState.upgrade_value("laser") > 0 and GameState.GUNS[p.gun].id == "deagle" 		and _viewmodel.gun == p.gun and not _hands_busy()
	_laser_dot.visible = false
	_laser_beam.visible = false
	if not on:
		return
	var from := _camera.global_position
	var dir := _camera.global_basis * Basis.from_euler(Vector3(off.y, off.x, 0.0)) * Vector3.FORWARD
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * GameState.SHOT_RANGE, GameState.SHOT_MASK)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var at: Vector3 = hit.position
	var far := from.distance_to(at)
	_laser_dot.global_position = at - dir * 0.02
	_laser_dot.scale = Vector3.ONE * maxf(LASER_DOT.x, far * LASER_DOT.y)
	_laser_dot.visible = true
	var lens: Vector3 = _viewmodel.laser_position()
	var length := lens.distance_to(at)
	if length > 0.05:
		var beam := _laser_beam.mesh as CylinderMesh
		beam.height = length
		beam.bottom_radius = LASER_BEAM.x
		beam.top_radius = LASER_BEAM.x + length * LASER_BEAM.y
		var along := (at - lens) / length  # the cylinder stands along y, its top toward the dot
		var side := along.cross(Vector3.UP if absf(along.y) < 0.99 else Vector3.RIGHT).normalized()
		_laser_beam.global_transform = Transform3D(Basis(side, along, side.cross(along)), (lens + at) * 0.5)
		_laser_beam.visible = true


func _make_laser_dot() -> void:
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.gradient = Gradient.new()
	soft.gradient.set_color(0, Color.WHITE)
	soft.gradient.set_color(1, Color(1, 1, 1, 0))
	soft.gradient.add_point(0.25, Color(1, 1, 1, 0.9))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true  # else the quad stays 1 m across whatever LASER_DOT says
	mat.no_depth_test = true  # it sits on what the ray hit: the floor cut it in half
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = soft
	mat.albedo_color = Color(1.0, 0.12, 0.08) * 2.0
	var quad := QuadMesh.new()
	quad.material = mat
	_laser_dot.mesh = quad
	_laser_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser_dot.top_level = true
	_laser_dot.visible = false
	add_child(_laser_dot)
	var beam := CylinderMesh.new()
	beam.radial_segments = 6
	beam.rings = 1
	beam.cap_top = false
	beam.cap_bottom = false
	var glow := ShaderMaterial.new()
	glow.shader = Shader.new()
	glow.shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
void fragment() {
	float edge = abs(dot(NORMAL, VIEW));  // brightest down the middle of the line
	ALBEDO = vec3(1.0, 0.08, 0.05) * 1.8;
	ALPHA = 0.25 + 0.45 * edge;
}"""
	beam.material = glow
	_laser_beam.mesh = beam
	_laser_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser_beam.top_level = true
	_laser_beam.visible = false
	add_child(_laser_beam)


## A menu has the keys: we stand still and grab nothing.
func _hands_busy() -> bool:
	return _shop.visible or _bench.visible or _board_menu.visible \
		or _melter.visible or _press.visible or _pick.visible or GameState.is_down()


## E in the workshop: of the board, bench, hopper and press in reach, the one the view points
## closest to (they stand side by side). "" when none is.
func _station() -> String:
	if _hands_busy():
		return ""
	var spots := {}
	if _board_menu.can_open():
		spots["board"] = GameState.BOARD_POS
	if _bench.can_open():
		spots["bench"] = (get_tree().get_first_node_in_group("workbench") as Node3D).global_position
	if _melter.can_open():
		spots["melter"] = GameState.MELTER_POS
	if _press.can_open():
		spots["press"] = GameState.PRESS_POS
	var waves := get_tree().get_first_node_in_group("waves")
	if waves and waves.can_pull(global_position):
		spots["lever"] = GameState.LEVER_POS
	var look := -_camera.global_basis.z
	var ahead := Vector2(look.x, look.z).normalized()
	var best := ""
	var best_dot := -2.0
	for id: String in spots:
		var to := Vector2(spots[id].x - global_position.x, spots[id].z - global_position.z)
		var dot := ahead.dot(to.normalized()) if to.length() > 0.05 else 1.0
		if dot > best_dot:
			best_dot = dot
			best = id
	return best


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_down() and not (event is InputEventMouseMotion and watching == 0):
		if watching != 0 and event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				_next_watch(1 if event.button_index == MOUSE_BUTTON_LEFT else -1)
		return  # on the floor: looking about is all that is left, then not even that
	if event is InputEventMouseMotion and _wheel.is_open:
		_wheel.steer(event.relative.x)  # the view holds still while picking
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _steered:
		var sens := MOUSE_SENSITIVITY / _zoom  # the same mouse travel moves the same share of the screen
		sens *= Settings.value("sensitivity") * lerpf(1.0, Settings.value("ads_sensitivity") / 100.0, _viewmodel.aim)
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens * (-1.0 if Settings.value("invert_y") else 1.0), -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("infinite_ammo"):
		GameState.request_toggle_infinite_ammo()
	elif event.is_action_pressed("pick_up") and _looking_at_table():
		var warm := GameState.warming() and not GameState.player().has_pistol  # a 2nd E before the table fades
		GameState.request_take_pistol()
		if warm:
			_show_heap()
	elif event.is_action_pressed("pick_up") and _station() != "":
		match _station():
			"board":
				_board_menu.open()
			"bench":
				_bench.open()
			"melter":
				GameState.request_melt()  # the hand goes in first; the screen shows it melt
				_melter.open()
			"press":
				_press.open()
			"lever":
				GameState.request_pull_lever()
	elif event.is_action_pressed("throw"):
		GameState.request_throw(_scrap_hand.global_position, -_camera.global_basis.z)
	elif OS.is_debug_build() and not Net.online and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_K:
		_toggle_mirror(not event.shift_pressed)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 and event.physical_keycode < KEY_1 + GameState.GUNS.size() - 1:
		# 1 draws the first gun; the key of the one in hand puts it away (bare fists).
		GameState.request_select_gun(event.physical_keycode - KEY_1 + 1)


## The warmup's pistol is ours: the view turns to the heap and the bottom of the screen says
## what it is for. Then the Q comes in (hud.gd).
func _show_heap() -> void:
	var heap := _pile() as Node3D
	if heap == null:
		return
	var to := heap.global_position + Vector3.UP * 3.0 - (global_position + Vector3.UP * EYE)
	var yaw := atan2(-to.x, -to.z)
	yaw = _yaw + wrapf(yaw - _yaw, -PI, PI)  # the short way round
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	_steered = true
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_yaw", yaw, HEAP_TURN)
	tw.tween_property(self, "_pitch", pitch, HEAP_TURN)
	tw.chain().tween_callback(func() -> void: _steered = false)
	_hud.say(HEAP_LINE, HEAP_LINE_TIME)


## K: the character test (scripts/character_demo.gd) opens, or puts on the next character;
## Shift+K closes it.
func _toggle_mirror(on: bool) -> void:
	var demo := get_parent().get_node_or_null("CharacterDemo")
	if not on:
		if demo:
			demo.queue_free()
		return
	if demo:
		demo.next_character()
		return
	demo = CHARACTER_DEMO.new()
	demo.name = "CharacterDemo"
	get_parent().add_child(demo)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	var c := _climb * (1.0 - exp(-dt * 30.0))
	_climb -= c
	_pitch = clampf(_pitch + c, -1.5, 1.5)
	var y := _yaw_climb * (1.0 - exp(-dt * 30.0))
	_yaw_climb -= y
	_yaw += y
	# x'' = -w²x - 2w x' (critically damped); a few steps keep it stable at low frame rates
	for i in 4:
		var h := dt / 4.0
		_recoil_vel += (-KICK_OMEGA * KICK_OMEGA * _recoil - 2.0 * KICK_OMEGA * _recoil_vel) * h
		_recoil += _recoil_vel * h
		_punch_vel += (-PUNCH_OMEGA * PUNCH_OMEGA * _punch - 2.0 * PUNCH_OMEGA * _punch_vel) * h
		_punch += _punch_vel * h
	_shake_camera(dt)
	_head_bob(delta)
	_down_view = move_toward(_down_view, 1.0 if GameState.is_down() else 0.0, dt / DOWN_FALL)
	if GameState.is_down() and GameState.player().down_for >= GameState.DOWN_TIME and not _can_watch(watching):
		_next_watch(1)
	_place_head()
	# R held with special rounds in the pocket: the ammo wheel; let go, it loads what was picked
	# (a tap still reloads, viewmodel.gd).
	var p := GameState.player()
	if Input.is_action_pressed("reload") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not p.down and p.gun != 0 and not p.specials.is_empty():
		_reload_held += delta
		if _reload_held >= WHEEL_HOLD and not _wheel.is_open:
			_wheel.open()
			_viewmodel.wheel_used = true
	else:
		_reload_held = 0.0
		_wheel.close()
	_zoom = lerpf(1.0, ADS_ZOOM, _viewmodel.aim)
	_hip_fov = Settings.value("fov")
	_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_hip_fov) * 0.5) / _zoom)) + _punch * Settings.value("screen_shake") / 100.0
	_crosshair.modulate.a = 1.0 - _viewmodel.aim  # the front post is the crosshair now
	_crosshair.visible = _down_view == 0.0  # the laser's dot hides it again below
	# Screen px per unit of tan(angle) off the view axis (fov is vertical).
	var focal := get_viewport().get_visible_rect().size.y * 0.5 / tan(deg_to_rad(_camera.fov) * 0.5)
	var off: Vector2 = _viewmodel.aim_offset
	_crosshair.offset = Vector2(-tan(off.x), -tan(off.y)) * focal
	_crosshair.gap = tan(_viewmodel.spread) * focal
	_crosshair.queue_redraw()
	_hit_marker.center = _crosshair.offset
	_aim_laser(off)
	if _laser_dot.visible:
		_crosshair.visible = false
	_vm_camera.global_transform = _camera.global_transform
	var vm_fov: float = _viewmodel.view_fov
	_vm_camera.fov = _camera.fov if vm_fov == 0.0 else rad_to_deg(2.0 * atan(tan(deg_to_rad(vm_fov) * 0.5) / _zoom))
	if _viewmodel._want_gun != GameState.player().gun:  # e.g. after leaving: local_peer() changed
		_viewmodel.equip(GameState.player().gun)


func _place_head() -> void:
	var rp := get_tree().get_first_node_in_group("remote_players")
	var them: Node3D = rp.character(watching) if rp and watching != 0 else null
	if them:  # down and dark: through a teammate's eyes
		_head.global_transform = them.eye_transform()
		_camera.transform = Transform3D.IDENTITY
		return
	var feet := get_global_transform_interpolated().origin
	var floor_k := smoothstep(0.0, 1.0, _down_view)
	var eye := lerpf(lerpf(EYE, CROUCH_EYE, smoothstep(0.0, 1.0, _crouch_view)), DOWN_EYE, floor_k)
	_head.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), feet + Vector3.UP * eye)
	_camera.position = _bob_offset * (1.0 - floor_k)
	var k := smoothstep(0.0, 1.0, _dizzy / DIZZY_TIME)
	_camera.rotation.x = _recoil + _tumble.x + _shake.x
	_camera.rotation.y = _shake.y
	_camera.rotation.z = _tumble.y + (sin(_dizzy_t * 2.1) + 0.5 * sin(_dizzy_t * 3.7)) / 1.5 * DIZZY_ROLL * k + _shake.z \
		+ DOWN_ROLL * floor_k


## We went down: every screen closes, the overview too, the gun goes away (viewmodel.gd), and the
## view drops to the floor.
func _go_down() -> void:
	if _shop.visible:
		_shop.toggle()
	for m: CanvasLayer in [_bench, _board_menu, _melter, _press]:
		if m.visible:
			m.close()
	_wheel.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Can we look through `peer`'s eyes: a teammate standing, their body here.
func _can_watch(peer: int) -> bool:
	var rp := get_tree().get_first_node_in_group("remote_players")
	return peer != 0 and peer != GameState.local_peer() and not GameState.is_down(peer) \
		and rp != null and rp.character(peer) != null and GameState.slots.has(peer)


## The next standing teammate to watch, `step` along by peer id; none left, none (the screen stays dark).
func _next_watch(step: int) -> void:
	var them: Array = GameState.slots.keys().filter(_can_watch)
	them.sort()
	if them.is_empty():
		_watch(0)
		return
	var i := them.find(watching)
	_watch(them[posmod(i + step, them.size())] if i >= 0 else them[0])


func _watch(peer: int) -> void:
	if peer == watching:
		return
	var rp := get_tree().get_first_node_in_group("remote_players")
	if rp and rp.character(watching):
		rp.character(watching).watched = false
	watching = peer
	if rp and rp.character(peer):
		rp.character(peer).watched = true


## Runs the trauma down (or holds it at a spinning gun's floor) and picks this frame's wobble.
func _shake_camera(dt: float) -> void:
	_trauma = maxf(_trauma - SHAKE_DECAY * dt, _viewmodel.spin * SPIN_SHAKE)
	_shake_t += dt * SHAKE_SPEED
	var k: float = _trauma * _trauma * Settings.value("screen_shake") / 100.0
	_shake = Vector3(_shake_noise.get_noise_2d(_shake_t, 0.0), _shake_noise.get_noise_2d(_shake_t, 50.0),
			_shake_noise.get_noise_2d(_shake_t, 100.0)) * SHAKE_MAX * k


func _physics_process(delta: float) -> void:
	rotation.y = _yaw  # the body faces where the player looks (3rd person, co-op)
	_balloon = maxf(_balloon - delta, 0.0)
	if _balloon > 0.0:
		velocity.y = BALLOON_RISE
	elif not is_on_floor():
		velocity += get_gravity() * delta
		if _drifting:
			velocity.y = maxf(velocity.y, -BALLOON_FALL)
	elif Input.is_action_just_pressed("jump") and not _hands_busy():
		velocity.y = JUMP_VELOCITY
	if is_on_floor() and _balloon == 0.0:
		_drifting = false
	_crouch(delta)

	# A menu open holds us still.
	var input := Vector2.ZERO if _hands_busy() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
	# Dizzy (punch round): the aim wanders off and the legs head somewhere near where we steer.
	_dizzy = maxf(_dizzy - delta, 0.0)
	_dizzy_t += delta
	var k := smoothstep(0.0, 1.0, _dizzy / DIZZY_TIME)
	if k > 0.0:
		_yaw += sin(_dizzy_t * 1.3) * DIZZY_DRIFT.x * k * delta
		_pitch = clampf(_pitch + cos(_dizzy_t * 1.7) * DIZZY_DRIFT.y * k * delta, -1.5, 1.5)
		dir = dir.rotated(Vector3.UP, sin(_dizzy_t * 1.1) * DIZZY_WALK * k)
	# Flying: the view turns over; down again, it rights itself.
	if is_on_floor():
		_tumble_vel = Vector2.ZERO
		_tumble = Vector2(wrapf(_tumble.x, -PI, PI), wrapf(_tumble.y, -PI, PI)) * exp(-8.0 * delta)
	else:
		_tumble += _tumble_vel * delta
	# Turning minigun barrels hold you back too, and you can't sprint with them (viewmodel walk_share).
	var walk: float = _viewmodel.walk_share
	var speed: float = SPRINT_SPEED if Input.is_action_pressed("sprint") and not crouched and _viewmodel.aim == 0.0 and walk == 1.0 		else (CROUCH_SPEED if crouched else SPEED) * lerpf(1.0, ADS_WALK, _viewmodel.aim) * walk
	_shove = _shove * exp(-(SHOVE_DECAY if is_on_floor() else AIR_DRAG) * delta)
	velocity.x = dir.x * speed + _shove.x
	velocity.z = dir.z * speed + _shove.z
	# The firing line always stops you (targets go up from behind it); caught past it somehow you
	# can still walk back out, never in.
	set_collision_mask_value(GameState.FENCE_LAYER, global_position.x < GameState.FIRING_LINE_X)
	var walked := Vector3(velocity.x, 0.0, velocity.z)  # before sliding takes the bump out of it
	var inside := global_position.x <= GameState.FIRING_LINE_X
	var flying := not is_on_floor()
	move_and_slide()
	keep_in_hall(self, inside)
	if flying and is_on_floor() and _bounces > 0 and _shove.length() > 6.0:
		_bounces -= 1
		_shove = punch_bounce(_shove)
		velocity.y = 3.5
		_tumble_vel = Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	_push_others(delta, walked)
	_pose_timer -= delta
	if _pose_timer <= 0.0:
		_pose_timer += POSE_INTERVAL
		GameState.send_pose(global_position, _yaw, _pitch, _act(), _air_time > AIR_SHOWN, crouched, aiming())
	if is_on_floor():
		if _air_time > LAND_AIR_TIME:
			_step_sound.play()
			_bob = PI * floor(_bob / PI) + 0.75 * PI + 0.001  # just past a dip: next step a full stride later
			_bob_amount = maxf(_bob_amount, 0.05)  # keeps the start-off rule from moving the stride
		_air_time = 0.0
	else:
		_air_time += delta

	# Holding E keeps grabbing, one bullet at a time, until the hand is full.
	_grab_timer -= delta
	var looking := _looking_at_pile()
	var heap := _pile()
	if heap:  # the piece E would take, outlined
		heap.highlight(_reach.get_collision_point(), looking, _reach.get_collider_rid())
	if Input.is_action_pressed("pick_up") and _grab_timer <= 0.0 and looking and not _hands_busy():
		_grab_timer = GRAB_REPEAT
		var at := _reach.get_collision_point()
		var shown_before := mini(GameState.carried, HAND_MAX)
		# A loose bullet goes by its id, so every peer removes the same one; else it is the heap.
		var id: int = heap.loose_id(_reach.get_collider(), _reach.get_collider_rid())
		var look: Array = heap.piece_look(_reach.get_collider(), _reach.get_collider_rid())
		var got := GameState.request_pick_up_loose(id) if id >= 0 else GameState.request_pick_up(at, 1)
		if got > 0:
			if look.is_empty():
				look = heap.any_look()
				look[3] = Transform3D(Basis(), at)
			_fly_to_hand(look, shown_before)
	_viewmodel.stowed = GameState.carried > 0

	var room := GameState.carried < GameState.carry_capacity
	_grab_hint.visible = looking and room
	_full_hint.visible = looking and not room
	var station := "" if looking else _station()
	_board_hint.visible = station == "board"
	_bench_hint.visible = station == "bench"
	_melt_hint.visible = station == "melter" and GameState.carried > 0
	if _melt_hint.visible:  # how many go in
		(_melt_hint.get_child(1) as Label).text = "%d kurşunu erit" % GameState.carried
	_hopper_hint.visible = station == "melter" and GameState.carried == 0
	_press_hint.visible = station == "press"
	_lever_hint.visible = station == "lever"
	var p := GameState.player()
	_table_hint.visible = _looking_at_table()
	if p.has_pistol:  # taken here, or on record from before a rejoin
		get_tree().call_group("gun_table", "fade")




## Something heavy knocks us along (scrap tumbling or pouring off the heap, pile.gd); the
## stronger shove wins.
func shove(v: Vector3) -> void:
	if v.length() > _shove.length() and not GameState.is_down():
		_shove = v


## Bumped into another player's body: shove them along with how fast we walked into them.
func _push_others(delta: float, walked: Vector3) -> void:
	_push_timer -= delta
	if _push_timer > 0.0:
		return
	for i in get_slide_collision_count():
		var k := get_slide_collision(i)
		var other := k.get_collider() as Node
		if other == null or not other.has_meta("peer"):
			continue
		var away := -k.get_normal()
		away.y = 0.0
		var into := walked.dot(away.normalized())
		if into > 0.5:
			GameState.request_push(other.get_meta("peer"), away.normalized() * into * PUSH_SHARE)
			_push_timer = PUSH_INTERVAL
		return


## Ctrl held, crouched; let go, up again once there is room over the head.
func _crouch(delta: float) -> void:
	var want := Input.is_action_pressed("crouch") and not _hands_busy()
	if want != crouched and (want or not test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT))):
		crouched = want
		var shape := _collision.shape as CapsuleShape3D
		shape.height = CROUCH_HEIGHT if crouched else STAND_HEIGHT
		_collision.position.y = shape.height * 0.5
	_crouch_view = move_toward(_crouch_view, 1.0 if crouched else 0.0, delta * CROUCH_RATE)


func _head_bob(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and speed > 0.1
	if moving:
		if _bob_amount < 0.05:
			_bob = PI * floor(_bob / PI) + 0.25 * PI  # starting off: first step half a stride in
		var before := _bob
		_bob += delta * speed * BOB_FREQ
		# Two steps per bob cycle, at the bottom of each vertical dip (sin(2·bob) = -1).
		if floor((_bob + PI / 4.0) / PI) != floor((before + PI / 4.0) / PI):
			_step_sound.play()
	_bob_amount = move_toward(_bob_amount, 1.0 if moving else 0.0, delta * 5.0)
	_bob_offset = Vector3(cos(_bob) * BOB_AMP, sin(_bob * 2.0) * BOB_AMP, 0.0) * _bob_amount * Settings.value("head_bob") / 100.0


func _looking_at_table() -> bool:
	if not _reach.is_colliding() or _hands_busy():
		return false
	# What the ray touched can be gone already this frame (a teammate's body when they leave, or
	# the character test's stand-in when it closes).
	var hit := _reach.get_collider()
	return is_instance_valid(hit) and hit is Node and (hit as Node).is_in_group("gun_table")


func _looking_at_pile() -> bool:
	if not _reach.is_colliding():
		return false
	var pile := _pile()
	return pile != null and pile.is_grabbable(_reach.get_collider(), _reach.get_collider_rid(), _reach.get_collision_point())


func _pile() -> Node:
	return get_tree().get_first_node_in_group("bullet_pile")


## The piece `look` (pile.gd piece_look) flies from where it lay into the hand, shrinking on the
## way, and appears in the row as it lands. Flyers come from a small pool: grabbing at 50/s used to
## load and free a scene every grab.
func _fly_to_hand(look: Array, shown_before: int) -> void:
	_set_hand_count(shown_before)
	var slot := mini(shown_before, HAND_MAX - 1)
	if shown_before < HAND_MAX:
		_scrap_looks.resize(mini(_scrap_looks.size(), shown_before))
		while _scrap_looks.size() < shown_before:
			_scrap_looks.append(_pile().any_look())
		_scrap_looks.append(look)
	var b := _fly[_next_fly]
	_next_fly = (_next_fly + 1) % FLY_POOL
	var old: Tween = b.get_meta("tween") if b.has_meta("tween") else null
	if old and old.is_valid():
		old.kill()  # pool wrapped around: the oldest flyer just lands now
	b.mesh = look[0]
	b.visible = true
	var mid: Vector3 = look[1]
	var start: Transform3D = look[3]
	var small := _scrap_scale(look)
	var q0 := start.basis.get_rotation_quaternion()
	var fly := func(f: float) -> void:
		var to := _scrap_hand.global_transform * _scrap_slot(slot, slot + 1)
		var pos := start.origin.lerp(to.origin, f) + Vector3.UP * sin(f * PI) * 0.3
		var rot := Basis(q0.slerp(to.basis.get_rotation_quaternion(), f))
		b.global_transform = Transform3D(rot.scaled(Vector3.ONE * lerpf(1.0, small, f)), pos).translated_local(-mid)
	fly.call(0.0)
	var t := b.create_tween()
	b.set_meta("tween", t)
	t.tween_method(fly, 0.0, 1.0, GRAB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		b.visible = false
		_set_hand_count(mini(shown_before + 1, GameState.carried)))


## Where piece `i` of a scrap row of `n` sits, its box centre in _scrap_hand: side by side across
## the middle, each turned its own way so the row doesn't look stamped.
func _scrap_slot(i: int, n: int) -> Transform3D:
	var tilt := Vector3(0.6 + 0.3 * sin(i * 1.7), i * 1.3, 0.4 * cos(i * 2.1))
	return Transform3D(Basis.from_euler(tilt), Vector3((i - (n - 1) * 0.5) * SCRAP_STEP, 0.0, 0.0))


## How much piece `look` shrinks in the hand: to SCRAP_IN_HAND at its longest.
func _scrap_scale(look: Array) -> float:
	var size: Vector3 = look[2]
	return SCRAP_IN_HAND / maxf(size[size.max_axis_index()], 0.001)


## Shows `n` scrap pieces in the row, and the special rounds in the pocket in the other hand: those
## their faces turned to our eye, the loaded one standing up out of the row. Copies the first
## round as needed.
func _set_hand_count(n: int) -> void:
	n = mini(n, HAND_MAX)
	_scrap_looks.resize(mini(_scrap_looks.size(), GameState.carried))
	var heap := _pile()
	while _scrap_looks.size() < n and heap:  # carried pieces we never saw taken (a rejoin)
		_scrap_looks.append(heap.any_look())
	n = mini(n, _scrap_looks.size())
	while _scrap_hand.get_child_count() < n:
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_scrap_hand.add_child(mi)
	for i in _scrap_hand.get_child_count():
		var mi := _scrap_hand.get_child(i) as MeshInstance3D
		mi.visible = i < n
		if i < n:
			var look: Array = _scrap_looks[i]
			var t := _scrap_slot(i, n)
			mi.mesh = look[0]
			mi.transform = Transform3D(t.basis.scaled(Vector3.ONE * _scrap_scale(look)), t.origin).translated_local(-look[1])
	var p := GameState.player()
	n = mini(p.specials.size(), HAND_MAX)
	var first := _hand.get_child(0) as Node3D
	while _hand.get_child_count() < n:
		_hand.add_child(first.duplicate())
	var armed := p.specials.find(p.armed) if p.armed != "" else -1
	var along := 0.0  # local +y is screen-left, +x up
	for c in _hand.get_child_count():
		var b := _hand.get_child(c) as Node3D
		var id: String = p.specials[c] if c < p.specials.size() else ""
		var s := SPECIAL_IN_HAND if id != "" else 1.0
		b.visible = c < n
		b.scale = Vector3.ONE * s
		var room := (SPECIAL_ROOM if id != "" else 1.1) * s
		b.position = Vector3(ARMED_RISE * s if c == armed else 0.0, along + room * 0.5, 0.0)
		along += room
		_dress_round(b, id)
		if id != "":  # spun about its own axis so the tip's face looks at the eye
			var eye := b.to_local(_camera.global_position)
			b.get_node("Special").rotation.x = atan2(-eye.y, eye.z)
	_hand.visible = n > 0


## A round in hand as plain, or as the special `id`: its case with that special's tip on the socket.
func _dress_round(b: Node3D, id: String) -> void:
	var dressed := b.get_node_or_null("Special")
	if dressed and dressed.get_meta("id") == id:
		return
	if dressed:
		dressed.free()
	b.get_child(0).visible = id == ""  # the plain round
	if id == "":
		return
	dressed = CASE.instantiate()
	dressed.name = "Special"
	dressed.set_meta("id", id)
	b.add_child(dressed)
	dressed.find_child("TipSocket").add_child(load(GameState.SPECIALS[id].tip).instantiate())


## The ammo wheel's pick: a special goes in as the next shot, the plain round takes it back out;
## the hands go through a reload either way.
func _on_wheel_picked(id: String) -> void:
	if id != GameState.player().armed:
		GameState.request_arm_special(id)
		_viewmodel.load_round()


## Pocket changed: a note for each kind there is more of than before, and the hand redrawn.
func _on_specials_changed() -> void:
	var p := GameState.player()
	for id: String in GameState.SPECIALS:
		if p.specials.count(id) > _pocket_seen.count(id):
			_wheel.note(id)
	_pocket_seen = p.specials.duplicate()
	_set_hand_count(GameState.carried)


## A key hint a little under the crosshair.
func _crosshair_hint(hint: Control) -> Control:
	hint.visible = false
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.offset_top = 30
	$HUD.add_child(hint)
	return hint
