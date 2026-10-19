extends Node3D
## First-person pistol. The model ships one baked clip; we play sections of it and add what
## it lacks: muzzle flash, smoke, ejected shells, sounds, sway, bob and a view kick.
## Lives under its own camera on render layer 2, so it never clips into walls.

signal kicked(amount: float)

const LAYER := 2
## Sections of the model's single "allanims" clip, in seconds, cut where the pose is at rest.
## Reloads follow the usual rule: with a round chambered only the magazine changes; when empty the
## slide stays locked back through the swap, then the off hand slingshots it home once; with the
## slide closed on an empty chamber (fresh gun) the off hand racks it once after the swap.
const CLIPS := {
	"fire": [0.0, 0.433], "fire_last": [2.833, 3.3], "draw": [5.4, 6.433], "inspect": [7.333, 8.266],
	"reload": [0.433, 1.8],         # magazine swap; the clip's own slide work after it is cut
	"settle": [2.8, 2.833],         # rest pose, eased into from the cut
	"reload_empty": [3.3, 4.53],    # swap with the slide locked; cut before the slide catch drops it
	"slingshot": [5.65, 6.433],     # draw's tail: off hand reaches over, grips the slide, lets go
	"rack": [5.5, 6.433],           # the same, but the hand also pulls a closed slide all the way back
}
const NEXT := {"reload": "settle", "reload_empty": "slingshot"}
const BLEND := {"settle": 0.35, "slingshot": 0.2, "rack": 0.2}  # s; these start away from the previous pose
## The clip moves the slide on its own in these and drags the hammer and slide stop with it
## (they are keyed to the slide), so those tracks are switched off and the parts held where they
## are: a locked-back slide keeps the hammer cocked through the whole reload, a tactical reload
## moves none of them. Slingshot closes all three together the instant the hand lets go.
const SLIDE_HELD := ["reload", "settle", "reload_empty", "slingshot"]
const HELD_PARTS := ["slide", "hammer", "slidecatch"]
## s into a section where the palm leaves the slide: from there the slide slams home on its spring
## instead of following the clip's slow linear key (draw and rack pull it back with the clip first).
const LET_GO := {"slingshot": 0.39, "rack": 0.54, "draw": 0.64}
## Rack blends in from the swap; a blend reads the slide from the previous section even with its
## track off (the reload clip has it back), so the parts stay held until the blend is over.
const HELD_UNTIL := {"rack": 0.21}
const SLIDE_SLAM := 0.04        # s for the recoil spring to drive the slide home (real: 20-40 ms)
const SLIDE_SLAM_JOLT := 0.22   # share of a shot's kick the gun takes when the slide slams home
## When the slide or magazine hits something inside a section (s from its start, read off the
## clip's slide and clip tracks), minus how far into each sample its loudest click sits.
const SLIDE_BACK := preload("res://assets/weapons/heavy_pistol/sounds/slide_back.wav")
const SLIDE_RELEASE := preload("res://assets/weapons/heavy_pistol/sounds/slide_release.wav")
const MAG_OUT := preload("res://assets/weapons/heavy_pistol/sounds/mag_out.wav")
const MAG_ENTER := preload("res://assets/weapons/heavy_pistol/sounds/mag_enter.wav")
const MAG_SEAT := preload("res://assets/weapons/heavy_pistol/sounds/mag_seat.wav")
const CLIP_SOUNDS := {
	"reload": [[0.34, MAG_OUT], [1.06, MAG_ENTER], [1.25, MAG_SEAT]],
	"reload_empty": [[0.27, MAG_OUT], [0.99, MAG_ENTER], [1.19, MAG_SEAT]],
	"draw": [[0.4, SLIDE_BACK], [0.65, SLIDE_RELEASE]],
	"rack": [[0.3, SLIDE_BACK], [0.55, SLIDE_RELEASE]],
	"slingshot": [[0.13, SLIDE_BACK], [0.40, SLIDE_RELEASE]],
}
## Model-space points (cm, gun points +Z): barrel end and ejection port (shooter's right).
const MUZZLE := Vector3(0.0, 7.4, 22.8)
const REAR_SIGHT := Vector3(0.0, 11.022, -2.467)    # top of the rear blades, at the notch (read off the mesh)
const FRONT_SIGHT := Vector3(-0.031, 10.699, 24.64)  # top of the front post
const PORT := Vector3(-2.6, 8.8, 5.0)
## Recoil is a spring on the whole rig: a shot gives it a kick of speed, it flies up and back and
## swings home on its own momentum with one small dip, so the kick and the return are one motion.
## The clip's own fire recoil is linear and starts canted, so in fire sections only the gun's
## moving parts (FIRE_PARTS) are animated. Shot spacing is GameState.fire_interval (fixed);
## holding the trigger fires at that rate.
## Recoil: the hand is shoved back and the gun flips up around the wrist (RECOIL_PIVOT, below and
## behind the grip), so the muzzle rises most. The push springs back with one small dip past aim;
## the gun follows the push through a stiff spring, so the flip snaps up in ~40 ms and eases home.
const RECOIL_PIVOT := Vector3(0.0, 2.0, -8.0)  # Talon space: the wrist
const RECOIL_PITCH := 0.15   # rad of muzzle flip at the peak of one shot from rest
const RECOIL_BACK := 0.035   # m toward the camera at the peak
const RECOIL_UP := 0.01      # m
const RECOIL_YAW := 0.02     # rad, random side each shot
const RECOIL_ROLL := 0.035   # rad, random cant each shot
const RECOIL_DAMPING := 0.55  # below 1 leaves one small dip past aim
const RECOIL_SNAP := 90.0    # rad/s, how stiffly the gun follows the push
const RECOIL_PEAK := 0.75    # peak of the snap spring after a unit push (simulated; RECOIL_SNAP 90, 0.38 s settle)
const RECOIL_SETTLE := 0.45  # s to settle at slow fire rates; faster ones settle before the next shot
const FIRE_PARTS := ["Talon/slide", "Talon/hammer", "Talon/trigger", "Talon/slidecatch", "Talon/clip", "R_point"]  # R_point: the trigger finger
const FIRE_BUFFER := 0.15    # s an early click waits for the gun to be ready
const RELOAD_BUFFER := 0.6   # s an R pressed during a shot or a settle waits for the gun
const KICK := 0.035        # rad of view climb per shot
const SWAY := 0.000008     # m per px/s of mouse speed
const SWAY_MAX := 0.018
const BOB_AMP := Vector2(0.006, 0.004)
const BREATH := Vector2(0.0008, 0.0012)  # m; the model's own idle clip bobs too fast
const ADS_TIME := 0.18     # s to bring the sights up (and to drop them)
const ADS_EYE := 0.22      # m from the eye to the rear sight when aimed
const ADS_STEADY := 0.2    # share of sway, bob and breath left when aimed
const ADS_RECOIL := 0.8    # share of the gun's kick when aimed (braced with both hands)
const ADS_CLIPS := ["", "fire", "fire_last"]  # rest pose only: reloads and the draw drop the sights
const SHELL_POOL := 20
const MUZZLE_FX := preload("res://scenes/muzzle_fx.tscn")
const MUZZLE_FX_POOL := 3
const WISP_TIME := 3.5  # s for a hot barrel's smoke to thin out to nothing
const FLASH_TIME := 0.05  # s

var body: CharacterBody3D  # set via setup(); drives bob and keeps shells off the capsule

var _clip := ""
var _clip_id := 0  # bumps on every section, so a cut-short section's sounds don't fire late
var _slide: Node3D
var _slide_track := -1
var _slide_home: Vector3  # closed (forward) slide position
var _held := {}  # HELD_PARTS name -> [node, track, rest value (position or quaternion)]
var _slide_locked := false
var _rack_after := false  # this reload went into an empty chamber with the slide closed
var _since_fire := 10.0
var _want_fire := 0.0  # s left on a buffered click
var _want_reload := 0.0
var _was_captured := false  # the click that recaptures the mouse must not also shoot
var aim := 0.0  # 0 hip, 1 sights on the screen centre (eased); the player zooms by it
var _aim_lin := 0.0
var _ads_pos: Vector3  # where the gun sits, and how it is turned, with the sights on the view axis
var _ads_rot: Quaternion
var _base: Vector3  # sway + bob + breath, smoothed, before the recoil layer
var _push := 0.0  # where the hand is shoved to; springs back to rest
var _push_vel := 0.0
var _kick := 0.0  # the gun following the push: 1 = peak of one shot from rest
var _kick_vel := 0.0
var _kick_yaw := 0.0
var _kick_roll := 0.0
var _pivot: Vector3  # RECOIL_PIVOT in our own space
var _rig_tracks: Array[int] = []  # everything but FIRE_PARTS, muted while firing
var _rest: Vector3
var _sway := Vector3.ZERO
var _sway_target := Vector3.ZERO
var _mouse := Vector2.ZERO  # mouse travel since the last frame
var _bob := 0.0
var _time := 0.0
var _shells: Array[RigidBody3D] = []
var _next_shell := 0
var _muzzle_fx: Array[Node3D] = []  # powder jet, curling smoke and sparks
var _next_muzzle_fx := 0
var _barrel_heat := 0.0  # 1 right after a shot, 0 when the barrel stops smoking
var _flash_left := 0.0
var _flash_frames := 0
var _dry_armed := true  # an empty gun clicks once per trigger pull, not once per frame held
var _world_flash: OmniLight3D  # the gun lives in its own world; this one lights the shed

@onready var _model: Node3D = $Model
@onready var _anim: AnimationPlayer = $Model/AnimationPlayer
@onready var _muzzle := _marker(MUZZLE)
@onready var _port := _marker(PORT)
@onready var _flash: Node3D = $Flash
@onready var _flash_light: OmniLight3D = $Flash/Light
@onready var _shot_sound: AudioStreamPlayer3D = $ShotSound
@onready var _dry_sound: AudioStreamPlayer3D = $DrySound
@onready var _slide_sound: AudioStreamPlayer3D = $SlideSound
@onready var _mag_sound: AudioStreamPlayer3D = $MagSound
@onready var _wisp: GPUParticles3D = $Wisp  # hot barrel: a cigarette-thin trail plume from the muzzle


func _ready() -> void:
	_rest = position
	add_to_group("first_person_gun")
	# Barrel smoke lives in the world (both worlds share coordinates): swing the gun and the
	# threads stay behind, bend and curl, instead of being glued to the screen.
	_wisp.local_coords = false
	_wisp.amount = 36  # many faint, fine threads braid into one plume, like the reference
	_wisp.lifetime = 3.2
	_wisp.trail_lifetime = 1.4
	var pm := _wisp.process_material.duplicate() as ParticleProcessMaterial
	pm.initial_velocity_min = 0.06
	pm.initial_velocity_max = 0.12
	pm.gravity = Vector3(0, 0.12, 0)  # hot gas rises slowly
	pm.inherit_velocity_ratio = 0.12  # a flick of the gun drags the fresh smoke a little
	pm.turbulence_noise_strength = 2.2
	pm.turbulence_noise_scale = 0.9
	_wisp.process_material = pm
	var ribbon := (_wisp.draw_pass_1 as RibbonTrailMesh).duplicate() as RibbonTrailMesh
	ribbon.size *= 0.8
	var mat := ribbon.material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("opacity", 0.3)  # each thread barely there; overlaps build the body
	mat.set_shader_parameter("softness", 4.0)
	ribbon.material = mat
	_wisp.draw_pass_1 = ribbon
	_wisp.layers = 1 << (LAYER - 1)
	for v in _model.find_children("*", "VisualInstance3D", true, false) + _flash.find_children("*", "VisualInstance3D", true, false):
		v.layers = 1 << (LAYER - 1)
		if v is GeometryInstance3D:  # else a gun shadow floats in front of the player
			(v as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	_anim.animation_finished.connect(_on_clip_finished.unbind(1))
	_slide = _model.find_child("slide", true, false)
	var a := _anim.get_animation("allanims")
	_slide_track = a.find_track(_anim.get_node(_anim.root_node).get_path_to(_slide), Animation.TYPE_POSITION_3D)
	_slide_home = a.position_track_interpolate(_slide_track, CLIPS["settle"][0])
	var root := _anim.get_node(_anim.root_node)
	for part in HELD_PARTS:
		var node: Node3D = _model.find_child(part, true, false)
		var path := root.get_path_to(node)
		var pos := a.find_track(path, Animation.TYPE_POSITION_3D)
		var rot := a.find_track(path, Animation.TYPE_ROTATION_3D)
		var t := pos if pos >= 0 else rot
		var rest: Variant = a.position_track_interpolate(t, CLIPS["settle"][0]) if pos >= 0 else a.rotation_track_interpolate(t, CLIPS["settle"][0])
		_held[part] = [node, t, rest]
	for t in a.get_track_count():
		var path := str(a.track_get_path(t))
		if not FIRE_PARTS.any(func(part: String) -> bool: return part in path):
			_rig_tracks.append(t)
	_anim.play("allanims")
	_anim.seek(CLIPS["settle"][1], true)  # the rest pose every aimable clip ends in
	_anim.advance(0.0)  # seek alone does not pose the rig before the first frame
	_measure_sights()
	_play("draw")


## Aiming moves and turns the gun so the line from the rear notch over the front post runs down
## the view axis, blades level: the post then sits exactly on the screen centre, where shots land.
func _measure_sights() -> void:
	var inv := global_transform.affine_inverse()
	var rear := inv * _marker(REAR_SIGHT).global_position
	_pivot = inv * _marker(RECOIL_PIVOT).global_position
	var front := inv * _marker(FRONT_SIGHT).global_position
	var up := inv.basis * (_model.find_child("Talon", true, false) as Node3D).global_basis.y
	var z := (rear - front).normalized()  # the gun's own back
	var x := up.cross(z).normalized()
	_ads_rot = Basis(x, z.cross(x), z).get_rotation_quaternion().inverse()
	_ads_pos = Vector3(0.0, 0.0, -ADS_EYE) - _ads_rot * rear


## Called by the player once it is ready: shells and smoke live in its level, on layer 1.
func setup(player: CharacterBody3D) -> void:
	body = player
	var level := player.get_parent()
	for i in SHELL_POOL:
		var s := _make_shell()
		level.add_child.call_deferred(s)
		_shells.append(s)
	# Muzzle smoke lives in the gun's camera space (local coords): it moves with the view instead
	# of hanging where the shot was fired, and draws over the shed like the gun does.
	for i in MUZZLE_FX_POOL:
		var f: Node3D = MUZZLE_FX.instantiate()
		f.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # moved per shot, not per tick
		for v: VisualInstance3D in f.get_children():
			v.layers = 1 << (LAYER - 1)
		get_parent().add_child.call_deferred(f)
		_muzzle_fx.append(f)
	_world_flash = OmniLight3D.new()
	_world_flash.light_color = _flash_light.light_color
	_world_flash.omni_range = 6.0
	_world_flash.shadow_enabled = false
	_world_flash.visible = false
	_world_flash.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	level.add_child.call_deferred(_world_flash)
	_prewarm.call_deferred()
	$Shell.queue_free()  # template only


## Runs every effect once, too small to see, so their shaders compile at load instead of
## stalling the first shot (which also used to eat the first muzzle flash).
func _prewarm() -> void:
	# In view but a thousandth of the size: off-screen effects are culled and never compile.
	var cam := get_parent() as Node3D
	var hidden := cam.global_transform * Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0, 0, -1))
	for f in _muzzle_fx:
		f.global_transform = hidden
		_play_fx(f)
	_wisp.emitting = true
	_barrel_heat = 0.01  # drawn for a frame or two at near-zero alpha, then off


## Where shots visibly leave the gun, in world coordinates (both worlds share them).
func muzzle_position() -> Vector3:
	return _muzzle.global_position


func _play_fx(f: Node3D) -> void:
	for c in f.get_children():
		if c is GPUParticles3D:
			(c as GPUParticles3D).restart()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse += event.relative


func _process(delta: float) -> void:
	_since_fire += delta
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if captured and _was_captured:
		if Input.is_action_pressed("fire"):
			_want_fire = FIRE_BUFFER
		elif Input.is_action_just_pressed("reload"):
			_want_reload = RELOAD_BUFFER
	_was_captured = captured
	var want_aim := captured and Input.is_action_pressed("aim") and _clip in ADS_CLIPS
	_aim_lin = move_toward(_aim_lin, 1.0 if want_aim else 0.0, delta / ADS_TIME)
	aim = smoothstep(0.0, 1.0, _aim_lin)
	_want_fire -= delta
	_want_reload -= delta
	if _want_fire > 0.0 and _can_fire():
		_want_fire = 0.0
		fire()
	elif _want_reload > 0.0 and _can_reload():
		_want_reload = 0.0
		reload()
	if not Input.is_action_pressed("fire"):
		_dry_armed = true
	if _flash.visible:  # at least two drawn frames, so a slow frame can't swallow the flash
		_flash_left -= delta
		_flash_frames -= 1
		if _flash_left <= 0.0 and _flash_frames <= 0:
			_flash.visible = false
			_world_flash.visible = false
	_flash.global_transform = _muzzle.global_transform.orthonormalized()
	# World-up, a centimetre past the bore so the plume starts at the opening, not inside the slide.
	var ahead := -(get_parent() as Node3D).global_basis.z
	_wisp.global_transform = Transform3D(Basis(), _muzzle.global_position + ahead * 0.012)
	if _barrel_heat > 0.0:  # the barrel cools: the thread thins out over WISP_TIME
		_barrel_heat = maxf(_barrel_heat - delta / WISP_TIME, 0.0)
		_wisp.amount_ratio = _barrel_heat
		_wisp.emitting = _barrel_heat > 0.0
	_sway_and_bob(delta)


func _can_fire() -> bool:
	return (_clip == "" or _clip == "fire") and _since_fire >= GameState.fire_interval


func fire() -> void:
	if not _can_fire():
		return
	if GameState.loaded <= 0:
		if _dry_armed:
			_dry_armed = false
			if not _slide_locked:  # slide back: the trigger is dead, nothing to click
				_dry_sound.play()
		if GameState.carried > 0:
			reload()
		return
	var cam := get_viewport().get_camera_3d()
	if not GameState.request_fire(cam.global_position, -cam.global_basis.z):
		return
	_add_kick(1.0)
	_kick_yaw = randf_range(-1.0, 1.0)
	_kick_roll = randf_range(-1.0, 1.0)
	_since_fire = 0.0
	_slide_locked = GameState.loaded == 0
	_play("fire_last" if _slide_locked else "fire")
	_effects()
	kicked.emit(KICK * randf_range(0.8, 1.2))


func _can_reload() -> bool:
	return _clip == "" or _clip == "inspect"


func reload() -> void:
	if not _can_reload():
		return
	var chamber_empty := GameState.loaded == 0
	if GameState.request_reload() == 0:
		return
	_rack_after = chamber_empty and not _slide_locked
	_play("reload_empty" if _slide_locked else "reload")
	_slide_locked = false


func _play(clip: String) -> void:
	_clip = clip
	_clip_id += 1
	var a := _anim.get_animation("allanims")
	for t in _rig_tracks:
		a.track_set_enabled(t, clip != "fire" and clip != "fire_last")
	for part in _held:
		a.track_set_enabled(_held[part][1], clip not in SLIDE_HELD and not HELD_UNTIL.has(clip))
	var c: Array = CLIPS[clip]
	# settle is a held pose; stretch it over its blend or the blend gets cut off when it ends
	var speed: float = (c[1] - c[0]) / BLEND[clip] if clip == "settle" else 1.0
	_anim.play_section("allanims", c[0], c[1], BLEND.get(clip, -1.0), speed)
	if not BLEND.has(clip):
		_anim.seek(c[0], true)  # same name twice in a row (a fast second shot) would not restart
	var id := _clip_id
	if HELD_UNTIL.has(clip):
		get_tree().create_timer(HELD_UNTIL[clip]).timeout.connect(func() -> void:
			if id == _clip_id:
				for part in _held:  # the slide stop only rises on an empty magazine, never in a rack
					a.track_set_enabled(_held[part][1], part != "slidecatch"))
	if LET_GO.has(clip):
		get_tree().create_timer(LET_GO[clip]).timeout.connect(func() -> void:
			if id == _clip_id:
				_slam_slide())
	for cue in CLIP_SOUNDS.get(clip, []):
		get_tree().create_timer(cue[0]).timeout.connect(func() -> void:
			if id == _clip_id:
				var p := _mag_sound if cue[1] in [MAG_OUT, MAG_ENTER, MAG_SEAT] else _slide_sound
				p.stream = cue[1]
				p.pitch_scale = randf_range(0.97, 1.03)
				p.play())


## The recoil spring drives the slide home, accelerating all the way (ease in), hammer and slide
## stop riding with it; the gun jolts when it hits.
func _slam_slide() -> void:
	var a := _anim.get_animation("allanims")
	for part in _held:
		a.track_set_enabled(_held[part][1], false)  # the clip let them follow the hand back; now they are ours
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for part in _held:
		var h: Array = _held[part]
		tw.tween_property(h[0], "position" if h[2] is Vector3 else "quaternion", h[2], SLIDE_SLAM)
	tw.chain().tween_callback(_add_kick.bind(SLIDE_SLAM_JOLT))


## Shoves the hand so the gun alone would peak at `amount` (1 = one shot).
func _add_kick(amount: float) -> void:
	_push += amount / RECOIL_PEAK


## Every section ends in the rest pose (or slide-back when empty), so the gun just holds it.
func _on_clip_finished() -> void:
	if _clip == "reload" and _rack_after:
		_rack_after = false
		_play("rack")
	elif NEXT.has(_clip):
		_play(NEXT[_clip])
	else:
		_clip = ""


func _marker(at: Vector3) -> Node3D:
	var m := Node3D.new()
	m.position = at
	_model.find_child("Talon", true, false).add_child(m)
	return m


func _effects() -> void:
	_flash.visible = true
	var quads: Node3D = $Flash/Quads
	quads.rotation.z = randf() * TAU
	quads.scale = Vector3(randf_range(0.85, 1.3), randf_range(0.85, 1.3), randf_range(0.9, 1.5))
	_flash_light.light_energy = randf_range(4.0, 6.0)
	# Same coordinates in both worlds: the gun camera copies the player camera every frame.
	_world_flash.global_position = _muzzle.global_position
	_world_flash.light_energy = _flash_light.light_energy
	_world_flash.omni_range = 8.0
	_world_flash.visible = true
	_flash_left = FLASH_TIME
	_flash_frames = 2
	_shot_sound.play()
	var fx := _muzzle_fx[_next_muzzle_fx]
	_next_muzzle_fx = (_next_muzzle_fx + 1) % MUZZLE_FX_POOL
	fx.global_transform = _muzzle.global_transform.orthonormalized()
	_play_fx(fx)
	_barrel_heat = 1.0
	_wisp.amount_ratio = 1.0
	_wisp.emitting = true
	_eject()


## Throws the oldest pooled shell out of the port: right, up and a little back, spinning.
func _eject() -> void:
	var s := _shells[_next_shell]
	_next_shell = (_next_shell + 1) % SHELL_POOL
	s.freeze = false  # first: Jolt drops velocities set on a frozen (static) body
	s.sleeping = false
	var cam := get_viewport().get_camera_3d().global_basis
	s.global_transform = Transform3D(Basis(cam.x, PI / 2.0) * cam, _port.global_position)
	s.reset_physics_interpolation()  # a teleport, not a move: don't draw it sliding from the floor
	var inherit := body.velocity if body else Vector3.ZERO
	s.linear_velocity = inherit + cam.x * randf_range(1.0, 1.5) + cam.y * randf_range(1.2, 1.7) + cam.z * randf_range(0.0, 0.6)
	s.angular_velocity = Vector3(randf_range(-30, 30), randf_range(-30, 30), randf_range(-30, 30))
	s.set_meta("landed", false)
	s.angular_damp = 3.0
	s.linear_damp = 0.0
	s.visible = true


func _make_shell() -> RigidBody3D:
	var s: RigidBody3D = $Shell.duplicate()
	s.visible = false
	s.freeze = true
	s.contact_monitor = true
	s.max_contacts_reported = 1
	s.body_entered.connect(func(_b: Node) -> void:
		s.angular_damp = 12.0  # brass on concrete stops fast; a free cylinder would roll forever
		s.linear_damp = 1.5
		# Each sample is a whole drop (hit, bounces, roll), so only the first touch plays one.
		var speed := s.linear_velocity.length()
		if not s.get_meta("landed", true) and speed > 0.4:
			s.set_meta("landed", true)
			var t: AudioStreamPlayer3D = s.get_node("Tink")
			t.volume_db = lerpf(-16.0, -8.0, clampf(speed / 4.0, 0.0, 1.0))
			t.play())
	s.add_collision_exception_with(body)
	return s


## Mouse sway goes through two smoothing stages: raw per-frame motion is uneven (mice report
## at their own rate), and a single stage still shows that as jitter.
func _sway_and_bob(delta: float) -> void:
	_time += delta
	var m := _mouse / maxf(delta, 0.001) * SWAY
	_mouse = Vector2.ZERO
	var target := Vector3(clampf(-m.x, -SWAY_MAX, SWAY_MAX), clampf(m.y, -SWAY_MAX, SWAY_MAX), 0.0)
	_sway_target = _sway_target.lerp(target, 1.0 - exp(-delta * 10.0))
	_sway = _sway.lerp(_sway_target, 1.0 - exp(-delta * 6.0))
	var breath := Vector3(sin(_time * 0.7) * BREATH.x, sin(_time * 1.3) * BREATH.y, 0.0)
	var bob := Vector3.ZERO
	if body and body.is_on_floor():
		var speed := Vector2(body.velocity.x, body.velocity.z).length()
		if speed > 0.1:
			_bob += delta * speed * 1.4
			bob = Vector3(sin(_bob) * BOB_AMP.x, -absf(cos(_bob)) * BOB_AMP.y, 0.0) * minf(speed / 5.0, 1.6)
	_base = _base.lerp((_sway + bob + breath) * lerpf(1.0, ADS_STEADY, aim), 1.0 - exp(-delta * 10.0))
	var w := _kick_omega()
	var dt := minf(delta, 0.1)  # a long hitch must not fling the gun
	var steps := maxi(4, ceili(dt * RECOIL_SNAP / 0.25))  # explicit steps stay stable while h * w is small
	var h := dt / steps
	for i in steps:
		_push_vel += (-w * w * _push - 2.0 * RECOIL_DAMPING * w * _push_vel) * h
		_push += _push_vel * h
		_kick_vel += (-RECOIL_SNAP * RECOIL_SNAP * (_kick - _push) - 2.0 * RECOIL_SNAP * _kick_vel) * h
		_kick += _kick_vel * h
	var kick := _kick * lerpf(1.0, ADS_RECOIL, aim)
	# In the gun's own frame, around the wrist: when aimed the front post jumps above the notch.
	var flip := Basis.from_euler(Vector3(RECOIL_PITCH, RECOIL_YAW * _kick_yaw, RECOIL_ROLL * _kick_roll) * kick)
	var recoil := Transform3D(flip, _pivot - flip * _pivot + Vector3(0.0, RECOIL_UP, RECOIL_BACK) * kick)
	transform = Transform3D(Basis(Quaternion.IDENTITY.slerp(_ads_rot, aim)), _rest.lerp(_ads_pos, aim) + _base) * recoil


## Spring frequency: settles (to ~2%) in RECOIL_SETTLE, or before the next shot if that is sooner.
func _kick_omega() -> float:
	return 4.0 / (RECOIL_DAMPING * minf(GameState.fire_interval * 0.9, RECOIL_SETTLE))
