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
const GRAB_TIME := 0.25  # s for one bullet to fly into the hand
const GRAB_GAP := 0.08   # s between bullets of one grab
const PILE_BULLET_SCALE := 0.03  # matches the pile look; shrinks to hand size in flight
const BULLET := preload("res://assets/bullet/bullet_9mm.glb")
const GRAB_REPEAT := 0.02  # s between grabs while E is held
const FLY_POOL := 16       # bullets in flight at most: GRAB_TIME / GRAB_REPEAT plus slack
## View kick: a critically damped spring, so the climb takes a few frames instead of one.
const KICK_OMEGA := 28.0     # rad/s; peak at 1 / KICK_OMEGA ≈ 36 ms
const KICK_CLIMB := 0.35     # share of the kick that stays as aim climb
const SUN_SHADE_SPEED := 6.0  # 1/s, how fast the gun's sun fades in and out of shade
const ADS_ZOOM := 1.25  # magnification when aimed down the sights
## The gun's world copies the hall's lights nearest the player (both worlds share coordinates), so
## the steel glints under a lamp and goes dark away from them. This many of each kind, re-picked
## this often; the key light dims with how lit the spot is.
const VM_SPOTS := 6
const VM_OMNIS := 2
const VM_LIGHT_PICK := 0.25  # s
const KEY_ENERGY := 2.2
const KEY_DARK := 0.35  # share of the key light left far from any lamp
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
var _vm_sun: DirectionalLight3D
var _world_sun: DirectionalLight3D
var _vm_env: Environment
var _vm_ambient := 1.0
var _hall_lights: Array[Light3D] = []  # every lamp, spot and glow in the level
var _vm_spots: Array[SpotLight3D] = []  # their stand-ins in the gun's world
var _vm_omnis: Array[OmniLight3D] = []
var _vm_key: DirectionalLight3D
var _light_pick := 0.0
var _lit := 1.0  # how lit the player's spot is, smoothed: 0 dark, 1 under a lamp
var _sun_lit := 1.0
var _sun_query := PhysicsRayQueryParameters3D.new()
var _hip_fov := 75.0
var _zoom := 1.0
var _before_placing := []  # [position, yaw, pitch] on our side of the line, for coming back
var _pose_timer := 0.0
var _shove := Vector3.ZERO  # m/s from someone walking into us
var _push_timer := 0.0
var _yaw_climb := 0.0  # rad of sideways aim still to add (friendly fire)
var _gun_bar: HBoxContainer  # GameState.GUNS after the fists, number keys 1-4

@onready var _head: Node3D = $Head
@onready var _step_sound: AudioStreamPlayer3D = $StepSound
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _reach: RayCast3D = $Head/Camera3D/Reach
@onready var _hand: Node3D = $Head/Camera3D/Hand
@onready var _prompt: Label = $HUD/Prompt
@onready var _counter: Label = $HUD/Counter
@onready var _money: Label = $HUD/Money
@onready var _vault: Label = $HUD/Vault
@onready var _crosshair: Control = $HUD/Crosshair
@onready var _hit_marker: Control = $HUD/HitMarker
@onready var _vm_view: SubViewport = $ViewmodelView/SubViewport
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
	_sun_query.collision_mask = 1
	_sun_query.exclude = [get_rid()]
	GameState.pile_changed.connect(_update_counter.unbind(1))
	GameState.carried_changed.connect(_update_counter.unbind(1))
	GameState.carried_changed.connect(func(c: int) -> void: _set_hand_count(mini(c, HAND_MAX)))
	GameState.upgraded.connect(_update_counter.unbind(2))
	GameState.loaded_changed.connect(_update_counter.unbind(1))
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.placing_changed.connect(_on_placing)
	_money.text = "$%d" % GameState.gold
	GameState.vault_changed.connect(func(v: float) -> void: _vault.text = "Kasa $%d" % floori(v))
	_vault.text = "Kasa $%d" % floori(GameState.vault)
	_setup_viewmodel_world()
	_viewmodel.setup(self)
	_viewmodel.kicked.connect(func(a: float) -> void:
		_climb += a * KICK_CLIMB
		_recoil_vel += a * (1.0 - KICK_CLIMB) * KICK_OMEGA * exp(1.0))  # peak = v / (w·e)
	_viewmodel.equip(GameState.player().gun)
	_build_gun_bar()
	GameState.gun_changed.connect(func(peer: int, gun: int) -> void:
		if peer == GameState.local_peer():
			_viewmodel.equip(gun)
			_update_gun_bar())
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
	_update_counter()
	_set_hand_count(mini(GameState.carried, HAND_MAX))
	_place_head()


## Friendly fire: it doesn't hurt, but it throws the aim off right when you need it.
func _on_player_shot(_shooter: int, victim: int, _at: Vector3, _dir: Vector3) -> void:
	if victim != GameState.local_peer():
		return
	_climb += randf_range(FF_CLIMB.x, FF_CLIMB.y)
	_yaw_climb += randf_range(-FF_YAW, FF_YAW)
	_recoil_vel += FF_KICK * KICK_OMEGA * exp(1.0)


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


## The gun is drawn in its own world: it does not need the shed, and sharing the shed's world
## made its viewport render the whole sun shadow map a second time every frame. The sun is
## copied over without shadows and fades out when the player stands in shade.
func _setup_viewmodel_world() -> void:
	# own_world_3d is set in player.tscn: switching it here would move the gun to a new world
	# after it entered the tree, and the arms would lose their skin binding (bind pose).
	_vm_env = get_world_3d().environment.duplicate()
	_vm_env.background_mode = Environment.BG_CLEAR_COLOR
	# The hall has no sky (closed and dark), so the gun gets a dim warm ambient of its own, roughly
	# what the lamps would bounce onto it; otherwise it renders black.
	_vm_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_vm_env.ambient_light_color = Color(0.55, 0.53, 0.5)
	_vm_env.ambient_light_energy = 0.8  # flat light shows no normal map: kept low, the key light below shapes
	# Metal shows what it reflects, and with nothing to reflect the guns rendered black. The hall it
	# stands in (materials/viewmodel_sky.gdshader: LED battens on a dark roof, lit concrete) stands in
	# for it, only in the reflections; the background stays clear.
	var sky := ShaderMaterial.new()
	sky.shader = preload("res://materials/viewmodel_sky.gdshader")
	_vm_env.sky = Sky.new()
	_vm_env.sky.sky_material = sky
	_vm_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_vm_env.ssao_enabled = false
	_vm_env.ssil_enabled = false
	_vm_env.sdfgi_enabled = false  # the gun has no world around it to bounce off, and fog would haze it
	_vm_env.volumetric_fog_enabled = false
	_vm_env.glow_enabled = false  # glow over a transparent background halos the gun's outline
	_vm_ambient = _vm_env.ambient_light_energy
	_vm_camera.environment = _vm_env
	_world_sun = get_parent().find_child("Sun", true, false) as DirectionalLight3D
	if _world_sun:
		_vm_sun = DirectionalLight3D.new()
		_vm_sun.light_color = _world_sun.light_color
		_vm_sun.light_energy = _world_sun.light_energy
		_vm_sun.shadow_enabled = false
		_vm_sun.layers = 0xFFFFF
		_vm_view.add_child(_vm_sun)
		_vm_sun.global_basis = _world_sun.global_basis
	# The ceiling battens are not in this world; a soft top light the colour of theirs stands in.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.95, 0.88)
	fill.light_energy = 1.0
	fill.rotation = Vector3(-PI / 2.0 + 0.3, 0.4, 0.0)
	_vm_view.add_child(fill)
	# Key light riding the gun's camera, from above and behind the left shoulder, so stitching, edges,
	# engraving and the normal maps read whichever way the player looks; a top light alone left the
	# side of the gun and the backs of the gloves in flat ambient.
	var key := DirectionalLight3D.new()
	_vm_key = key
	key.light_color = Color(1.0, 0.96, 0.9)
	key.light_energy = KEY_ENERGY
	key.light_specular = 1.2
	key.rotation = Vector3(-0.65, 0.4, 0.0)
	_vm_camera.add_child(key)
	# Rim light from ahead and to the right, back toward the camera: a thin bright line on the edges
	# of slides, sights and knuckles that lifts them off the dark hall.
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.85, 0.9, 1.0)
	rim.light_energy = 0.9
	rim.light_specular = 2.0
	rim.rotation = Vector3(-0.35, PI - 0.6, 0.0)
	_vm_camera.add_child(rim)
	for l: Light3D in get_parent().find_children("*", "Light3D", true, false):
		if (l is SpotLight3D or l is OmniLight3D) and not is_ancestor_of(l):
			_hall_lights.append(l)
	for i in VM_SPOTS:
		_vm_spots.append(SpotLight3D.new())
	for i in VM_OMNIS:
		_vm_omnis.append(OmniLight3D.new())
	for l: Light3D in _vm_spots + _vm_omnis:
		l.shadow_enabled = false
		l.visible = false
		l.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_vm_view.add_child(l)


## Moves the gun world's stand-in lights onto the hall lights nearest the eye, and dims the key
## light by how much light reaches it from them.
func _mirror_lights(dt: float) -> void:
	_light_pick -= dt
	if _light_pick > 0.0 or _vm_spots.is_empty():
		_vm_key.light_energy = KEY_ENERGY * lerpf(KEY_DARK, 1.0, _lit)
		return
	_light_pick = VM_LIGHT_PICK
	var eye := _camera.global_position
	var near := _hall_lights.filter(func(l: Light3D) -> bool: return is_instance_valid(l) and l.is_visible_in_tree())
	near.sort_custom(func(a: Light3D, b: Light3D) -> bool: return _light_at(a, eye) > _light_at(b, eye))
	var spots := near.filter(func(l: Light3D) -> bool: return l is SpotLight3D)
	var omnis := near.filter(func(l: Light3D) -> bool: return l is OmniLight3D)
	var lit := 0.0
	for i in _vm_spots.size():
		lit += _copy_light(_vm_spots[i], spots[i] if i < spots.size() else null, eye)
	for i in _vm_omnis.size():
		lit += _copy_light(_vm_omnis[i], omnis[i] if i < omnis.size() else null, eye)
	_lit = lerpf(_lit, clampf(lit, 0.0, 1.0), 0.5)


## How much of light `l` reaches `eye`, roughly: energy over the share of its range left, inside a spot's cone.
func _light_at(l: Light3D, eye: Vector3) -> float:
	var range_ := (l as SpotLight3D).spot_range if l is SpotLight3D else (l as OmniLight3D).omni_range
	var to := eye - l.global_position
	var f := clampf(1.0 - to.length() / range_, 0.0, 1.0)
	if l is SpotLight3D and to.length() > 0.01:
		var off := rad_to_deg((-l.global_basis.z).angle_to(to))
		f *= clampf(1.0 - (off - (l as SpotLight3D).spot_angle) / 15.0, 0.0, 1.0)
	return l.light_energy * f * f


func _copy_light(to: Light3D, from: Light3D, eye: Vector3) -> float:
	to.visible = from != null
	if not from:
		return 0.0
	to.global_transform = from.global_transform
	to.light_color = from.light_color
	to.light_energy = from.light_energy
	to.light_specular = maxf(from.light_specular, 1.0)
	if to is SpotLight3D:
		var s := from as SpotLight3D
		(to as SpotLight3D).spot_range = s.spot_range
		(to as SpotLight3D).spot_angle = s.spot_angle
		(to as SpotLight3D).spot_attenuation = s.spot_attenuation
		(to as SpotLight3D).spot_angle_attenuation = s.spot_angle_attenuation
	else:
		(to as OmniLight3D).omni_range = (from as OmniLight3D).omni_range
		(to as OmniLight3D).omni_attenuation = (from as OmniLight3D).omni_attenuation
	return _light_at(from, eye)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 and event.physical_keycode < KEY_1 + GameState.GUNS.size() - 1:
		# 1 draws the first gun; the key of the one in hand puts it away (bare fists).
		GameState.request_select_gun(event.physical_keycode - KEY_1 + 1)


## Bottom centre: one slot per gun, the one in hand lit; a gun not in yet is dimmed. Test bar
## until guns come off the table and out of crates.
func _build_gun_bar() -> void:
	_gun_bar = HBoxContainer.new()
	_gun_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_gun_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_gun_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_gun_bar.offset_bottom = -64  # above placement's stock reminder
	_gun_bar.add_theme_constant_override("separation", 10)
	_gun_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_gun_bar)
	for i in range(1, GameState.GUNS.size()):
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(PLACEMENT._label(str(i), 15, Color(1, 1, 1, 0.6)))
		row.add_child(PLACEMENT._label(GameState.GUNS[i].name, 18, Color.WHITE))
		slot.add_child(row)
		_gun_bar.add_child(slot)
	_update_gun_bar()


func _update_gun_bar() -> void:
	for i in _gun_bar.get_child_count():
		var on := i + 1 == GameState.player().gun
		var box: StyleBoxFlat = PLACEMENT._box(Color(0.05, 0.06, 0.08, 0.82 if on else 0.55), Color(PLACEMENT.GOLD, 0.9) if on else Color(1, 1, 1, 0.2), 16, 8)
		box.set_border_width_all(2 if on else 1)
		var slot: PanelContainer = _gun_bar.get_child(i)
		slot.add_theme_stylebox_override("panel", box)
		slot.modulate = Color.WHITE if on else Color(1, 1, 1, 0.7 if GameState.GUNS[i + 1].ready else 0.3)


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
	_zoom = lerpf(1.0, ADS_ZOOM, _viewmodel.aim)
	_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_hip_fov) * 0.5) / _zoom))
	_crosshair.modulate.a = 1.0 - _viewmodel.aim  # the front post is the crosshair now
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
	_shade_viewmodel(dt)
	_mirror_lights(dt)
	if _viewmodel._want_gun != GameState.player().gun:  # e.g. after leaving: local_peer() changed
		_viewmodel.equip(GameState.player().gun)
		_update_gun_bar()


## Placement mode (B, or buying gear) takes us over the firing line, facing the target area;
## leaving it brings us back to where we stood.
func _on_placing(on: bool) -> void:
	_update_counter()
	_gun_bar.visible = not on  # placement has its own key row down there
	if on and global_position.x < GameState.FIRING_LINE_X:
		_before_placing = [global_position, _yaw, _pitch]
		var zone := GameState.PLACE_ZONE
		_teleport(Vector3(zone.position.x + 0.5, global_position.y, clampf(global_position.z, zone.position.y + 2.0, zone.end.y - 2.0)), -PI / 2.0, -0.3)
	elif not on and global_position.x > GameState.FIRING_LINE_X and not _before_placing.is_empty():
		_teleport(_before_placing[0], _before_placing[1], _before_placing[2])
		_before_placing.clear()


func _teleport(at: Vector3, yaw: float, pitch: float) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_yaw = yaw
	_pitch = pitch
	rotation.y = yaw
	reset_physics_interpolation()
	_place_head()


func _place_head() -> void:
	var feet := get_global_transform_interpolated().origin
	_head.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), feet + Vector3.UP * EYE)
	_camera.position = _bob_offset
	_camera.rotation.x = _recoil


## Gun sun follows whether the eye can see the sky toward the sun (roof, walls, the heap).
func _shade_viewmodel(dt: float) -> void:
	if not _vm_sun:
		return
	var eye := _camera.global_position
	_sun_query.from = eye
	_sun_query.to = eye + _world_sun.global_basis.z * 80.0  # light shines along -z
	var lit := 0.0 if get_world_3d().direct_space_state.intersect_ray(_sun_query) else 1.0
	_sun_lit = move_toward(_sun_lit, lit, dt * SUN_SHADE_SPEED)
	_vm_sun.light_energy = _world_sun.light_energy * _sun_lit
	_vm_env.ambient_light_energy = _vm_ambient * lerpf(0.55, 1.0, _sun_lit)


func _physics_process(delta: float) -> void:
	rotation.y = _yaw  # the body faces where the player looks (3rd person, co-op)
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") and _viewmodel.aim == 0.0 else SPEED
	_shove = _shove * exp(-SHOVE_DECAY * delta)
	velocity.x = dir.x * speed + _shove.x
	velocity.z = dir.z * speed + _shove.z
	# The firing line stops you unless you are placing targets; caught past it (placement mode
	# switched off over there) you can still walk back out, never in.
	set_collision_mask_value(GameState.FENCE_LAYER, not GameState.player().placing and global_position.x < GameState.FIRING_LINE_X)
	var walked := Vector3(velocity.x, 0.0, velocity.z)  # before sliding takes the bump out of it
	move_and_slide()
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
	if Input.is_action_pressed("pick_up") and _grab_timer <= 0.0 and looking:
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


## Shows `n` bullets side by side in the hand, copying the first as needed.
func _set_hand_count(n: int) -> void:
	n = mini(n, HAND_MAX)
	var first := _hand.get_child(0) as Node3D
	while _hand.get_child_count() < n:
		var copy := first.duplicate() as Node3D
		copy.position = Vector3(0.0, _hand.get_child_count() * 1.1, 0.0)  # local +y is screen-left
		_hand.add_child(copy)
	for c in _hand.get_child_count():
		(_hand.get_child(c) as Node3D).visible = c < n
	_hand.visible = n > 0


func _update_counter() -> void:
	_counter.text = "Elde: %d/%d\nŞarjör: %d/%d\nYığın: %s\n[Q] Geliştirmeler%s" % [GameState.carried, GameState.carry_capacity, GameState.loaded, GameState.mag_capacity, _thousands(GameState.pile), ("\nSINIRSIZ MERMİ + PARA (T)" if GameState.infinite_ammo else "")]  # placement mode has its own banner (scripts/placement.gd)


## Money counter: the new amount, and a green pop when it went up.
func _on_gold_changed(gold: int) -> void:
	var up := gold > int(_money.text.trim_prefix("$"))
	_money.text = "$%d" % gold
	if not up:
		return
	_money.pivot_offset = Vector2(_money.size.x, _money.size.y * 0.5)
	_money.scale = Vector2.ONE * 1.25
	create_tween().tween_property(_money, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _thousands(n: int) -> String:
	var s := str(n)
	for i in range(s.length() - 3, 0, -3):
		s = s.insert(i, ".")
	return s
