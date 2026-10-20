extends Node3D
## Everyone else in the session, as third-person characters (the bumstrum operator with the heavy
## pistol in both hands). One per peer whose pose arrives; gone when that peer leaves. The local
## player never gets one. Poses come ~20 times a second (GameState.pose_received) and are drawn
## DELAY behind, between the two snapshots around that moment, so the body glides instead of
## stepping or jittering with the network.
##
## Animation (assets/characters/animations/operator_anims.res, Quaternius UAL baked onto the
## operator by tools/retarget_ual.gd): the legs walk, jog or sprint with how fast the body moves
## and jump when the pose says it is off the ground; from the spine up it holds the pistol, and
## plays the reload when the player reloads and the shot when they fire. The look pitch bends spine
## and chest on top of that, so arms, gun and head aim where the player looks; the gun rides the
## right wrist.
# ponytail: one forward cycle for every direction; strafing and walking backwards slide sideways.
# A directional BlendSpace2D needs strafe clips (UAL has them) when it bothers anyone.

const MODEL := preload("res://assets/characters/operator/operator.gltf")
const ANIMS := preload("res://assets/characters/animations/operator_anims.res")
const GUN := preload("res://assets/weapons/heavy_pistol/heavy_pistol.gltf")
const MUZZLE_FX := preload("res://scenes/muzzle_fx.tscn")
const VIEWMODEL := preload("res://scripts/viewmodel.gd")  # MUZZLE, in the gun's own (Talon) space
const DELAY := 0.1  # s behind the newest pose: two snapshots in hand even when one is late
const KEEP := 0.6   # s of snapshots kept
const UNIT := 0.01  # the model is in centimetres
## Ground speed (m/s) each cycle is blended in at: the player walks at 5 and sprints at 8.
const GAITS := {"idle": 0.0, "walk": 1.5, "jog": 5.0, "sprint": 8.0}
const MOVING := 0.5  # m/s; slower than this lands standing (the full crouch), faster runs on
## Where the gun sits in the right hand, in its own (Talon) space: the wrist, behind the grip.
const WRIST_ON_GUN := Vector3(0.0, 2.0, -8.0)
const SPINE_SHARE := 0.35  # of the pitch; the chest takes the rest, so arms and gun aim with all of it
const PITCH_MAX := 1.2  # rad either way; beyond it the torso would fold
const FLASH_TIME := 0.05  # s
const LABEL_HEIGHT := 2.1  # m above the feet
## Render layer 3: the world camera sees it, floor decals and bullet holes don't land on it.
const BODY_LAYER := 4

var _chars := {}  # peer -> Character


func _ready() -> void:
	add_to_group("remote_players")
	GameState.pose_received.connect(_on_pose)
	multiplayer.peer_disconnected.connect(_drop)
	multiplayer.server_disconnected.connect(func() -> void:
		for peer in _chars.keys():
			_drop(peer))


## The character standing in for `peer`, or null if there is none (yet).
func character(peer: int) -> Character:
	return _chars.get(peer)


func _on_pose(peer: int, t: float, pos: Vector3, yaw: float, pitch: float, act: int, air: bool) -> void:
	if peer == GameState.local_peer():
		return
	if not _chars.has(peer):
		var c := Character.new(peer)
		add_child(c)
		_chars[peer] = c
	(_chars[peer] as Character).push(t, pos, yaw, pitch, act, air)


func _drop(peer: int) -> void:
	if _chars.has(peer):
		_chars[peer].queue_free()
		_chars.erase(peer)


class Character extends Node3D:
	# Sounds (Faz 6, step 25): steps and reloads play from this node, shots from muzzle_position().
	var peer: int
	var act := GameState.Act.IDLE
	var air := false
	var speed := 0.0  # m/s along the ground, as drawn
	var _snaps: Array = []  # [local time, pos, yaw, pitch, act, air], oldest first
	var _clock := 0.0  # the sender's clock minus ours, smoothed
	var _pitch := 0.0
	var _last_pos := Vector3.INF
	var _model: Node3D
	var _skel: Skeleton3D
	var _tree: AnimationTree
	var _gun: Node3D
	var _gun_in_hand: Transform3D  # the gun relative to the right wrist bone
	var _hips_hold: Basis  # the hips standing in the pistol pose; the upper body keeps to it
	var _spine := -1
	var _chest := -1
	var _wrist := -1
	var _flash: Node3D
	var _flash_left := 0.0
	var _fx: Node3D

	func _init(id: int) -> void:
		peer = id
		name = "Player%d" % id
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # placed per frame
		visible = false  # until the first pose places it

	func _ready() -> void:
		_model = MODEL.instantiate()
		_model.scale = Vector3.ONE * UNIT
		_model.rotation.y = PI  # it faces +Z; the player's forward is -Z
		add_child(_model)
		_skel = _model.find_children("*", "Skeleton3D", true, false)[0]
		_spine = _skel.find_bone("spine_012")
		_chest = _skel.find_bone("chest_013")
		_wrist = _skel.find_bone("R_wrist_041")
		_tree = _animation_tree()
		_model.add_child(_tree)
		_tree.advance(0.0)  # in the pistol pose now, to fit the gun to the hand
		_hips_hold = _skel.get_bone_global_pose(_skel.get_bone_parent(_spine)).basis
		# The heavy pistol on its own: the first-person model's gun part, without the arms.
		var whole: Node3D = GUN.instantiate()
		_gun = whole.find_child("Talon", true, false)
		_gun.get_parent().remove_child(_gun)
		whole.free()
		_model.add_child(_gun)
		# Aimed straight ahead (the model's +Z) with its grip in the hand of the idle pistol pose.
		var hand := _skel.get_bone_global_pose(_wrist)
		_gun_in_hand = hand.affine_inverse() * Transform3D(Basis(), hand.origin - WRIST_ON_GUN)
		# Off the floor paint's layer: its decals (cull_mask 1) were printing onto boots and legs.
		for v: VisualInstance3D in _model.find_children("*", "VisualInstance3D", true, false):
			v.layers = BODY_LAYER
		# The first-person gun's flash, copied into this world (its layer there is the gun's own).
		var fp := get_tree().get_first_node_in_group("first_person_gun")
		if fp:
			_flash = fp.get_node("Flash").duplicate()
			for v: VisualInstance3D in _flash.find_children("*", "VisualInstance3D", true, false):
				v.layers = 1
			_flash.visible = false
			_flash.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			add_child(_flash)
		_fx = MUZZLE_FX.instantiate()
		_fx.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_fx)
		var label := Label3D.new()
		label.text = "Oyuncu %d" % peer  # ponytail: Steam name in Faz 6
		label.position.y = LABEL_HEIGHT
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true  # teammates stay findable behind the heap
		label.fixed_size = true
		label.pixel_size = 0.0012
		label.font_size = 24
		label.outline_size = 8
		add_child(label)

	## Legs: a gait blend by speed inside a jump state machine. Spine up: the pistol pose, with the
	## reload and the shot as one-shots over it. Advanced by hand (_process), so the pitch bend
	## goes on after the clips have posed the bones.
	func _animation_tree() -> AnimationTree:
		var gaits := AnimationNodeBlendSpace1D.new()
		gaits.min_space = 0.0
		gaits.max_space = GAITS.sprint
		for clip: String in GAITS:
			gaits.add_blend_point(_clip(clip), GAITS[clip], -1, clip)
		var legs := AnimationNodeStateMachine.new()
		legs.add_node("ground", gaits)
		for clip in ["jump_start", "jump"]:
			legs.add_node(clip, _clip(clip))
		legs.add_transition("Start", "ground", _go(""))
		legs.add_transition("ground", "jump_start", _go("air"))
		legs.add_transition("jump_start", "jump", _go("", true))
		legs.add_transition("jump_start", "ground", _go("landed"))
		legs.add_transition("jump", "ground", _go("landed"))
		var body := AnimationNodeBlendTree.new()
		body.add_node("legs", legs)
		# Touching down standing still: the full crouch over the legs (running on, it is skipped).
		body.add_node("land_clip", _clip("jump_land"))
		var land := AnimationNodeOneShot.new()
		land.fadein_time = 0.05
		land.fadeout_time = 0.3
		body.add_node("land", land)
		body.connect_node("land", 0, "legs")
		body.connect_node("land", 1, "land_clip")
		body.add_node("hold", _clip("pistol_idle"))
		body.add_node("reload_clip", _clip("pistol_reload"))
		body.add_node("shoot_clip", _clip("pistol_shoot"))
		var reload := AnimationNodeOneShot.new()
		reload.fadein_time = 0.15
		reload.fadeout_time = 0.25
		body.add_node("reload", reload)
		var shoot := AnimationNodeOneShot.new()
		shoot.fadein_time = 0.03
		shoot.fadeout_time = 0.15
		body.add_node("shoot", shoot)
		var mix := AnimationNodeBlend2.new()
		mix.filter_enabled = true
		var track := str(ANIMS.get_animation("idle").track_get_path(0))
		var skel_path := track.substr(0, track.find(":") + 1)
		for b in _skel.get_bone_count():
			if _is_upper(b):
				mix.set_filter_path(NodePath(skel_path + _skel.get_bone_name(b)), true)
		body.add_node("mix", mix)
		body.connect_node("reload", 0, "hold")
		body.connect_node("reload", 1, "reload_clip")
		body.connect_node("shoot", 0, "reload")
		body.connect_node("shoot", 1, "shoot_clip")
		body.connect_node("mix", 0, "land")
		body.connect_node("mix", 1, "shoot")
		body.connect_node("output", 0, "mix")
		var tree := AnimationTree.new()
		tree.add_animation_library("", ANIMS)
		tree.root_node = ^".."  # the operator scene root: the clips' track paths start there
		tree.tree_root = body
		tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		tree.set("parameters/mix/blend_amount", 1.0)
		tree.active = true
		return tree

	func _is_upper(bone: int) -> bool:
		while bone != -1:
			if bone == _spine:
				return true
			bone = _skel.get_bone_parent(bone)
		return false

	static func _clip(clip: String) -> AnimationNodeAnimation:
		var a := AnimationNodeAnimation.new()
		a.animation = clip
		return a

	## A state machine step: on `condition` (none: right away), or when the clip ends (`at_end`).
	static func _go(condition: StringName, at_end := false, xfade := 0.15) -> AnimationNodeStateMachineTransition:
		var t := AnimationNodeStateMachineTransition.new()
		t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		t.advance_condition = condition
		t.xfade_time = xfade
		if at_end:
			t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		return t

	## One snapshot from the network, on the sender's clock.
	func push(t: float, pos: Vector3, yaw: float, pitch: float, a: int, in_air: bool) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		var gap := now - t
		_clock = gap if _snaps.is_empty() else lerpf(_clock, gap, 0.05)  # evens out network jitter
		var at := t + _clock
		if not _snaps.is_empty() and at <= _snaps[-1][0]:
			return  # late or repeated
		_snaps.append([at, pos, yaw, pitch, a, in_air])
		while _snaps.size() > 2 and _snaps[1][0] < now - KEEP:
			_snaps.pop_front()

	func _process(delta: float) -> void:
		if _snaps.is_empty():
			return
		var t := Time.get_ticks_msec() / 1000.0 - DELAY
		var a: Array = _snaps[0]
		var b: Array = a
		for s: Array in _snaps:
			b = s
			if s[0] >= t:
				break
			a = s
		var f := 0.0 if b[0] <= a[0] else clampf((t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
		global_position = (a[1] as Vector3).lerp(b[1], f)
		rotation.y = lerp_angle(a[2], b[2], f)
		if _last_pos != Vector3.INF and delta > 0.0:
			var step := (global_position - _last_pos) * Vector3(1, 0, 1)
			speed = lerpf(speed, step.length() / delta, 1.0 - exp(-delta * 10.0))
		_last_pos = global_position
		if b[4] == GameState.Act.RELOADING and act != GameState.Act.RELOADING:
			_tree.set("parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		if air and not b[5] and speed < MOVING:
			_tree.set("parameters/land/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		act = b[4]
		air = b[5]
		_tree.set("parameters/legs/ground/blend_position", speed)
		_tree.set("parameters/legs/conditions/air", air)
		_tree.set("parameters/legs/conditions/landed", not air)
		_tree.advance(delta)
		_pitch = lerpf(_pitch, clampf(lerpf(a[3], b[3], f), -PITCH_MAX, PITCH_MAX), 1.0 - exp(-delta * 20.0))
		_bend(_pitch)
		_gun.transform = _skel.get_bone_global_pose(_wrist) * _gun_in_hand
		if _flash:
			_flash.global_transform = Transform3D(_gun.global_basis.orthonormalized(), muzzle_position())
			_flash_left -= delta
			_flash.visible = _flash_left > 0.0
		visible = true

	## Where this character's rounds visibly leave its gun.
	func muzzle_position() -> Vector3:
		return _gun.global_transform * VIEWMODEL.MUZZLE

	## A round left this player's gun: the shot clip, the flash and the powder jet at the muzzle.
	func shoot() -> void:
		_tree.set("parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_flash_left = FLASH_TIME
		_fx.global_transform = Transform3D(_gun.global_basis.orthonormalized(), muzzle_position())
		for p in _fx.get_children():
			if p is GPUParticles3D:
				(p as GPUParticles3D).restart()

	## Looking up or down, on top of the clips: the spine turns a share, the chest the rest (arms,
	## gun and head ride on it), both about the body's own side axis. The hips' sway and lean in a
	## run is taken out above them first, or the gun would wave off the aim with every stride.
	func _bend(pitch: float) -> void:
		var parent := _skel.get_bone_global_pose(_skel.get_bone_parent(_spine)).basis
		var steady := _hips_hold * parent.orthonormalized().inverse()
		var spine := Basis(Vector3.RIGHT, -pitch * SPINE_SHARE) * steady * _skel.get_bone_global_pose(_spine).basis
		var chest := Basis(Vector3.RIGHT, -pitch * (1.0 - SPINE_SHARE)) * spine * Basis(_skel.get_bone_pose_rotation(_chest))
		_skel.set_bone_pose_rotation(_spine, (parent.inverse() * spine).get_rotation_quaternion())
		_skel.set_bone_pose_rotation(_chest, (spine.inverse() * chest).get_rotation_quaternion())
