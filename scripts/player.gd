extends CharacterBody3D
## First-person player: walk, sprint, jump, mouse look, grab bullets from the pile.
## The body moves at the physics rate and is drawn interpolated (physics interpolation is on);
## the head is top level and placed every frame from the interpolated body plus the mouse look,
## so the view never waits a physics tick and never steps on a fast monitor.

const SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.002
const EYE := 1.6         # m, head above the feet
const BOB_FREQ := 1.4    # bob cycles per metre walked, scaled by speed
const BOB_AMP := 0.05    # metres
const LAND_AIR_TIME := 0.15  # s in the air before touching down counts as a landing step
const HAND_MAX := 6      # bullets drawn in hand; more are carried but not shown
const ARMED_RISE := 0.6  # bullet lengths/2.9: the armed special stands this far up out of the row
const SPECIAL_IN_HAND := 1.15  # a special round in hand, this many times a plain one
const SPECIAL_ROOM := 1.6  # its share of the row (plain round 1.1): tips are at most 1.25 across (tools/build_tips.py)
const AMMO_WHEEL := preload("res://scripts/ammo_wheel.gd")
const HUD := preload("res://scripts/hud.gd")
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
## Balloon: up for BALLOON_TIME, then a slow drift down; ~8 s in all from the floor (4 m up, under
## the 8 m roof beam even from a step).
const BALLOON_TIME := 4.0  # s
const BALLOON_RISE := 1.0  # m/s
const BALLOON_FALL := 1.0  # m/s at most on the way down
const SPECIAL_DEMO := preload("res://scripts/special_demo.gd")  # N, debug builds, solo
## Scream: the clown's face rushes at the view, holds, shakes, is gone. Its sound is the user's
## recording, played if it is there (no sound is made in code).
const SCREAM_FACE := preload("res://assets/bullet/tips/scream_face.glb")
const SCREAM_RUSH := 0.05  # s: the face lands as the sound's first full blast does (its lead-in is cut)
const SCREAM_HOLD := 0.9  # s: until the scream starts to die down
const SCREAM_DB := 7.6  # the recording is at full scale already; the master limiter catches the rest
const SPECIAL_SOUND := "res://assets/sounds/specials/%s.wav"  # per SPECIALS id
const GRAB_TIME := 0.25  # s for one bullet to fly into the hand
const GRAB_GAP := 0.08   # s between bullets of one grab
const PILE_BULLET_SCALE := 0.03  # matches the pile look; shrinks to hand size in flight
const BULLET := preload("res://assets/bullet/bullet_9mm.glb")
const CASE := preload("res://assets/bullet/bullet_case.glb")  # special rounds: case + TipSocket
const GRAB_REPEAT := 0.02  # s between grabs while E is held
const FLY_POOL := 16       # bullets in flight at most: GRAB_TIME / GRAB_REPEAT plus slack
## View kick: a critically damped spring, so the climb takes a few frames instead of one.
const KICK_OMEGA := 28.0     # rad/s; peak at 1 / KICK_OMEGA ≈ 36 ms
const KICK_CLIMB := 0.35     # share of the kick that stays as aim climb
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
const PLACEMENT := preload("res://scripts/placement.gd")  # its HUD box and label helpers

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
var _fly: Array[Node3D] = []
var _next_fly := 0
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

@onready var _head: Node3D = $Head
@onready var _shop: CanvasLayer = $UpgradeMenu
@onready var _step_sound: AudioStreamPlayer3D = $StepSound
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _reach: RayCast3D = $Head/Camera3D/Reach
@onready var _hand: Node3D = $Head/Camera3D/Hand
@onready var _prompt: Label = $HUD/Prompt
@onready var _crosshair: Control = $HUD/Crosshair
@onready var _hit_marker: Control = $HUD/HitMarker
@onready var _vm_camera: Camera3D = $ViewmodelView/SubViewport/Camera
@onready var _viewmodel: Node3D = $ViewmodelView/SubViewport/Camera/Viewmodel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("walker")  # kicks loose bullets around (Pile)
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
	$HUD.add_child(HUD.new())
	_prompt.add_theme_font_override("font", UiStyle.face(UiStyle.MEDIUM, 1))
	_prompt.add_theme_font_size_override("font_size", 14)
	_prompt.add_theme_color_override("font_shadow_color", UiStyle.SHADOW)
	_setup_viewmodel_world()
	_viewmodel.setup(self)
	_viewmodel.kicked.connect(func(a: float, yaw: float) -> void:
		_climb += a * KICK_CLIMB
		_yaw_climb += yaw
		_recoil_vel += a * (1.0 - KICK_CLIMB) * KICK_OMEGA * exp(1.0))  # peak = v / (w·e)
	_viewmodel.equip(GameState.player().gun)
	GameState.gun_changed.connect(func(peer: int, gun: int) -> void:
		if peer == GameState.local_peer():
			_viewmodel.equip(gun))
	for i in FLY_POOL:
		var b: Node3D = BULLET.instantiate()
		b.visible = false
		b.top_level = true
		b.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # tweened per frame
		add_child(b)
		_fly.append(b)
	GameState.pushed.connect(func(v: Vector3) -> void:
		if v.length() > _shove.length():
			_shove = v)
	GameState.player_shot.connect(_on_player_shot)
	_wheel = AMMO_WHEEL.new()
	$HUD.add_child(_wheel)
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
	var c := Vector3(clampf(p.x, -HALL_IN, x_max), minf(p.y, ROOF_IN), clampf(p.z, -HALL_IN, HALL_IN))
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


## The gun shares the hall's world, drawn by its own camera (its layer only, at its own fov) over
## the player's view: the hall's lamps, the heap's spots and the reflection probe light it, so
## steel glints under a lamp and goes dark away from them. Its viewport draws no shadows
## (player.tscn) and its camera's environment leaves out what would cost a second time or haze
## it: SDFGI, fog, SSAO, and glow, which halos the gun over the clear background.
func _setup_viewmodel_world() -> void:
	_vm_env = get_world_3d().environment.duplicate()
	_vm_env.background_mode = Environment.BG_CLEAR_COLOR
	_vm_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_vm_env.ambient_light_color = Color(0.55, 0.53, 0.5)
	_vm_env.ambient_light_energy = 0.55  # roughly what the lamps bounce onto it
	# Outside the probe's box the steel reflects this instead (materials/viewmodel_sky.gdshader:
	# LED battens on a dark roof, lit concrete); never drawn, the background stays clear.
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
	key.light_energy = 1.5
	key.rotation = Vector3(-0.65, 0.4, 0.0)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.85, 0.9, 1.0)
	rim.light_energy = 0.5
	rim.light_specular = 2.0
	rim.rotation = Vector3(-0.35, PI - 0.6, 0.0)
	for l: DirectionalLight3D in [key, rim]:
		l.light_cull_mask = 1 << 1
		_vm_camera.add_child(l)


## The overview (B) or the Q menu has the keys: we stand still and grab nothing.
func _hands_busy() -> bool:
	return GameState.player().placing or _shop.visible


func _unhandled_input(event: InputEvent) -> void:
	if GameState.player().placing and not event.is_action_pressed("placement_mode"):
		return  # the overview has the mouse and keys (scripts/placement.gd)
	if event is InputEventMouseMotion and _wheel.is_open:
		_wheel.steer(event.relative.x)  # the view holds still while picking
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENSITIVITY / _zoom  # the same mouse travel moves the same share of the screen
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens, -1.5, 1.5)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("infinite_ammo"):
		GameState.request_toggle_infinite_ammo()
	elif event.is_action_pressed("placement_mode"):
		GameState.request_toggle_placing()
	elif event.is_action_pressed("throw"):
		GameState.request_throw(_hand.global_position, -_camera.global_basis.z)
	elif OS.is_debug_build() and not Net.online and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		_toggle_demo(not event.shift_pressed)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 and event.physical_keycode < KEY_1 + GameState.GUNS.size() - 1:
		# 1 draws the first gun; the key of the one in hand puts it away (bare fists).
		GameState.request_select_gun(event.physical_keycode - KEY_1 + 1)


## N: the special rounds test (scripts/special_demo.gd) opens, or tops the pocket up again;
## Shift+N closes it. Letter keys: not every keyboard has F keys.
func _toggle_demo(on: bool) -> void:
	var demo := get_parent().get_node_or_null("SpecialDemo")
	if not on:
		if demo:
			demo.queue_free()
		return
	if demo:
		demo.refill()
		return
	demo = SPECIAL_DEMO.new()
	demo.name = "SpecialDemo"
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
	_head_bob(delta)
	_place_head()
	# R held with special rounds in the pocket: the ammo wheel; let go, it loads what was picked
	# (a tap still reloads, viewmodel.gd).
	var p := GameState.player()
	if Input.is_action_pressed("reload") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not p.placing and p.gun != 0 and not p.specials.is_empty():
		_reload_held += delta
		if _reload_held >= WHEEL_HOLD and not _wheel.is_open:
			_wheel.open()
			_viewmodel.wheel_used = true
	else:
		_reload_held = 0.0
		_wheel.close()
	_zoom = lerpf(1.0, ADS_ZOOM, _viewmodel.aim)
	_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_hip_fov) * 0.5) / _zoom))
	_crosshair.modulate.a = 1.0 - _viewmodel.aim  # the front post is the crosshair now
	_crosshair.visible = not GameState.player().placing  # the overview has its own cursor
	# Screen px per unit of tan(angle) off the view axis (fov is vertical).
	var focal := get_viewport().get_visible_rect().size.y * 0.5 / tan(deg_to_rad(_camera.fov) * 0.5)
	var off: Vector2 = _viewmodel.aim_offset
	_crosshair.offset = Vector2(-tan(off.x), -tan(off.y)) * focal
	_crosshair.gap = tan(_viewmodel.spread) * focal
	_crosshair.queue_redraw()
	_hit_marker.center = _crosshair.offset
	_vm_camera.global_transform = _camera.global_transform
	var vm_fov: float = _viewmodel.view_fov
	_vm_camera.fov = _camera.fov if vm_fov == 0.0 else rad_to_deg(2.0 * atan(tan(deg_to_rad(vm_fov) * 0.5) / _zoom))
	if _viewmodel._want_gun != GameState.player().gun:  # e.g. after leaving: local_peer() changed
		_viewmodel.equip(GameState.player().gun)


func _place_head() -> void:
	var feet := get_global_transform_interpolated().origin
	_head.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), feet + Vector3.UP * EYE)
	_camera.position = _bob_offset
	var k := smoothstep(0.0, 1.0, _dizzy / DIZZY_TIME)
	_camera.rotation.x = _recoil + _tumble.x
	_camera.rotation.z = _tumble.y + (sin(_dizzy_t * 2.1) + 0.5 * sin(_dizzy_t * 3.7)) / 1.5 * DIZZY_ROLL * k


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

	# Placement mode: WASD moves the overview camera, not us; the Q menu holds us still.
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
	var speed: float = SPRINT_SPEED if Input.is_action_pressed("sprint") and _viewmodel.aim == 0.0 and walk == 1.0 else SPEED * lerpf(1.0, ADS_WALK, _viewmodel.aim) * walk
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
		GameState.send_pose(global_position, _yaw, _pitch, _act(), _air_time > AIR_SHOWN)
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
	if Input.is_action_pressed("pick_up") and _grab_timer <= 0.0 and looking and not _hands_busy():
		_grab_timer = GRAB_REPEAT
		var at := _reach.get_collision_point()
		var shown_before := mini(GameState.carried, HAND_MAX)
		# A loose bullet goes by its id, so every peer removes the same one; else it is the heap.
		var id: int = _pile().loose_id(_reach.get_collider(), _reach.get_collider_rid())
		var got := GameState.request_pick_up_loose(id) if id >= 0 else GameState.request_pick_up(at, 1)
		if got > 0:
			_fly_to_hand(at, shown_before)

	_prompt.visible = looking
	_prompt.text = "[E] Mermi al (basılı tut)" if GameState.carried < GameState.carry_capacity else "Elin dolu  [G] Fırlat"


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
	_bob_offset = Vector3(cos(_bob) * BOB_AMP, sin(_bob * 2.0) * BOB_AMP, 0.0) * _bob_amount


func _looking_at_pile() -> bool:
	if not _reach.is_colliding():
		return false
	var pile := _pile()
	return pile != null and pile.is_grabbable(_reach.get_collider(), _reach.get_collider_rid())


func _pile() -> Node:
	return get_tree().get_first_node_in_group("bullet_pile")


## One bullet flies from where it was grabbed into the hand and appears there as it lands.
## Flyers come from a small pool: grabbing at 50/s used to load and free a scene every grab.
func _fly_to_hand(from: Vector3, shown_before: int) -> void:
	_set_hand_count(shown_before)
	var b := _fly[_next_fly]
	_next_fly = (_next_fly + 1) % FLY_POOL
	var old: Tween = b.get_meta("tween") if b.has_meta("tween") else null
	if old and old.is_valid():
		old.kill()  # pool wrapped around: the oldest flyer just lands now
	b.visible = true
	var start := from + Vector3(randf_range(-0.06, 0.06), 0.0, randf_range(-0.06, 0.06))
	var q0 := Quaternion.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	var fly := func(f: float) -> void:
		var to := _hand.global_transform
		var pos := start.lerp(to.origin, f) + Vector3.UP * sin(f * PI) * 0.3
		var rot := Basis(q0.slerp(to.basis.get_rotation_quaternion(), f))
		b.global_transform = Transform3D(rot.scaled(Vector3.ONE * lerpf(PILE_BULLET_SCALE, to.basis.get_scale().x, f)), pos)
	fly.call(0.0)
	var t := b.create_tween()
	b.set_meta("tween", t)
	t.tween_method(fly, 0.0, 1.0, GRAB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		b.visible = false
		_set_hand_count(mini(shown_before + 1, GameState.carried)))


## Shows `n` plain bullets side by side in the hand, after the special rounds in the pocket: those
## bigger, their faces turned to our eye, the loaded one standing up out of the row. Copies the
## first round as needed.
func _set_hand_count(n: int) -> void:
	var p := GameState.player()
	n = mini(n + p.specials.size(), HAND_MAX)
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
