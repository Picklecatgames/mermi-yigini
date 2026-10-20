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
## right wrist, and both hands close round it as the first-person hands do (_grip).
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
## Hand bones, parents first, each with "L_"/"R_" in front; the operator's 4th (tip) segment stays as animated.
const HAND := ["wrist", "thumb1", "thumb2", "thumb3", "point1", "point2", "point3", "middle1", "middle2",
	"middle3", "ring1", "ring2", "ring3", "pink1", "pink2", "pink3"]
const LEFT_LET_GO := 0.2  # s for the left hand to leave the gun for a reload, and to come back
const SPINE_SHARE := 0.35  # of the pitch; the chest takes the rest, so arms and gun aim with all of it
const PITCH_MAX := 1.2  # rad either way; beyond it the torso would fold
const FLASH_TIME := 0.05  # s
const LABEL_HEIGHT := 2.1  # m above the feet
## Render layer 3: the world camera sees it, floor decals and bullet holes don't land on it.
const BODY_LAYER := 4
## The body other players bump into (player.tscn's capsule) and friendly fire hits.
const BODY_RADIUS := 0.35
const BODY_HEIGHT := 1.8
const TAG_FONT := 32
const TAG_PAD := Vector2(18, 8)  # px around the name

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
	var _gun_in_hand: Transform3D  # the gun relative to the right wrist bone, as the clips move it
	var _hand := {}  # "R_point1" etc. -> bone
	var _on_gun := {}  # "R_point1" etc. -> that bone's turn in gun space, from the first-person grip
	var _left_wrist_on_gun: Vector3
	var _on_gun_at := {}  # "R_point3" etc. -> where the first-person joint is on the gun
	var _left_hold := 1.0  # 0 while the left hand is off the gun for a reload
	## The first-person hand's size over the operator's (~0.83): on the gun the operator's hand
	## shrinks to it, or the same finger pose reaches past the trigger.
	var _hand_scale := 1.0
	var _hips_hold: Basis  # the hips standing in the pistol pose; the upper body keeps to it
	var _spine := -1
	var _chest := -1
	var _wrist := -1
	var _flash: Node3D
	var _flash_left := 0.0
	var _fx: Node3D
	var _tag_box: StandardMaterial3D
	## What others collide with and shoot at; carries the peer id as meta "peer".
	var body: AnimatableBody3D

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
		# The heavy pistol on its own: the first-person model's gun part. Its arms only lend their
		# grip: where each hand bone sits on the gun in the rest pose.
		var whole: Node3D = GUN.instantiate()
		add_child(whole)
		_gun = whole.find_child("Talon", true, false)
		var on_gun := _grip_points(whole)
		_gun.get_parent().remove_child(_gun)
		remove_child(whole)
		whole.free()
		_model.add_child(_gun)
		# Hand bones turned in gun space as the first-person hands are: line each one's own frame
		# (along the bone, rolled by the palm's width) up with the first-person bone's.
		var rest := {}
		for side in ["L", "R"]:
			for h: String in HAND:
				var key: String = side + "_" + h
				_hand[key] = _find(_skel, key)
				rest[key] = _skel.get_bone_global_rest(_hand[key]).origin
				if h.ends_with("3"):  # the operator's tips: its last segments' own line
					rest[key.left(-1) + "4"] = _skel.get_bone_global_rest(_find(_skel, key.left(-1) + "4")).origin
		var own := _frames(rest)
		var theirs := _frames(on_gun)
		for key: String in _hand:
			var r := _skel.get_bone_global_rest(_hand[key]).basis.orthonormalized()
			_on_gun[key] = theirs[key] * own[key].inverse() * r
		_left_wrist_on_gun = on_gun["L_wrist"]
		_on_gun_at = on_gun
		_hand_scale = on_gun["R_wrist"].distance_to(on_gun["R_middle1"]) / (rest["R_wrist"] as Vector3).distance_to(rest["R_middle1"])
		# Aimed straight ahead (the model's +Z), the right wrist where the first-person one is.
		var hand := _skel.get_bone_global_pose(_wrist)
		_gun_in_hand = hand.affine_inverse() * Transform3D(Basis(), hand.origin - on_gun["R_wrist"])
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
		body = AnimatableBody3D.new()
		body.sync_to_physics = false  # placed with the character every frame
		body.set_meta("peer", peer)
		var shape := CollisionShape3D.new()
		shape.shape = CapsuleShape3D.new()
		shape.shape.radius = BODY_RADIUS
		shape.shape.height = BODY_HEIGHT
		shape.position.y = BODY_HEIGHT * 0.5
		body.add_child(shape)
		add_child(body)
		_name_tag()

	## "Oyuncu N" in a box of the player's colour, the same size on screen at any distance, seen
	## through walls and the heap so teammates stay findable.
	func _name_tag() -> void:
		var label := Label3D.new()
		label.text = "Oyuncu %d" % peer  # ponytail: Steam name in Faz 6
		label.position.y = LABEL_HEIGHT
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0012
		label.font_size = TAG_FONT
		label.outline_size = 6
		label.render_priority = 2  # over the box
		label.outline_render_priority = 1
		add_child(label)
		var px := label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT) if label.font 			else ThemeDB.fallback_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT)
		var quad := QuadMesh.new()
		quad.size = (Vector2(px.x, TAG_FONT) + TAG_PAD * 2.0) * label.pixel_size
		_tag_box = StandardMaterial3D.new()
		_tag_box.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tag_box.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_tag_box.fixed_size = true
		_tag_box.no_depth_test = true
		_tag_box.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tag_box.render_priority = 0
		quad.material = _tag_box
		var box := MeshInstance3D.new()
		box.mesh = quad
		box.layers = BODY_LAYER
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box.position.y = LABEL_HEIGHT
		add_child(box)
		_tint_tag()
		GameState.player_slots.connect(_tint_tag.unbind(1))

	func _tint_tag() -> void:
		var c := GameState.color_of(peer)
		c.a = 0.8
		_tag_box.albedo_color = c

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
		_grip(delta)
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

	## Both hands on the gun as the first-person hands hold it, over whatever the clips did: the right
	## one wraps the grip with the index on the trigger guard, the left cups it from below. The left
	## arm reaches for its place with two-bone IK and lets go while a reload plays.
	func _grip(delta: float) -> void:
		var reloading: bool = _tree.get("parameters/reload/active")
		_left_hold = move_toward(_left_hold, 0.0 if reloading else 1.0, delta / LEFT_LET_GO)
		var gun := _gun.transform
		_hold("R", gun, 1.0)
		if _left_hold > 0.0:
			var w := _hand["L_wrist"] as int
			var to := _skel.get_bone_global_pose(w).origin.lerp(gun * _left_wrist_on_gun, _left_hold)
			_reach(w, to)
			_hold("L", gun, _left_hold)

	## One hand's bones turned toward their place on the gun, by `weight`.
	func _hold(side: String, gun: Transform3D, weight: float) -> void:
		var glob := {}  # bone -> global basis, as set
		for h: String in HAND:
			var i: int = _hand[side + "_" + h]
			var p := _skel.get_bone_parent(i)
			var pg: Basis = glob[p] if glob.has(p) else _skel.get_bone_global_pose(p).basis.orthonormalized()
			var want := (pg.inverse() * gun.basis * (_on_gun[side + "_" + h] as Basis)).get_rotation_quaternion()
			var q := _skel.get_bone_pose_rotation(i).slerp(want, weight)
			_skel.set_bone_pose_rotation(i, q)
			glob[i] = pg * Basis(q)
		_skel.set_bone_pose_scale(_hand[side + "_wrist"], Vector3.ONE * lerpf(1.0, _hand_scale, weight))
		# The operator's fingers are thicker and root higher: each one turns at its knuckle until
		# its last joint points where the first-person one is (the index's onto the trigger).
		for finger in ["thumb", "point", "middle", "ring", "pink"]:
			var root: int = _hand["%s_%s1" % [side, finger]]
			var g := _skel.get_bone_global_pose(root)
			var last := _skel.get_bone_global_pose(_hand["%s_%s3" % [side, finger]]).origin
			var want: Vector3 = gun * _on_gun_at["%s_%s3" % [side, finger]]
			var turned := _swing(last - g.origin, want - g.origin) * g.basis.orthonormalized()
			var pg := _skel.get_bone_global_pose(_skel.get_bone_parent(root)).basis.orthonormalized()
			var q := _skel.get_bone_pose_rotation(root).slerp((pg.inverse() * turned).get_rotation_quaternion(), weight)
			_skel.set_bone_pose_rotation(root, q)

	## The upper arm and forearm above `wrist` turned so it lands on `to`, the elbow staying on its side.
	func _reach(wrist: int, to: Vector3) -> void:
		var elbow := _skel.get_bone_parent(wrist)
		var arm := _skel.get_bone_parent(elbow)
		var a := _skel.get_bone_global_pose(arm)
		var e := _skel.get_bone_global_pose(elbow)
		var pw := _skel.get_bone_global_pose(wrist).origin
		var l1 := a.origin.distance_to(e.origin)
		var l2 := e.origin.distance_to(pw)
		var reach := to - a.origin
		var dist := clampf(reach.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
		var fwd := reach.normalized()
		var pole := (e.origin - a.origin) - fwd * (e.origin - a.origin).dot(fwd)
		pole = pole.normalized() if pole.length() > 0.001 else Vector3.DOWN
		var cos_a := (l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist)
		var new_e := a.origin + (fwd * cos_a + pole * sqrt(maxf(0.0, 1.0 - cos_a * cos_a))) * l1
		var turn := _swing(e.origin - a.origin, new_e - a.origin)
		var arm_g := turn * a.basis.orthonormalized()
		var fore := _swing(turn * (pw - e.origin), a.origin + fwd * dist - new_e) * turn * e.basis.orthonormalized()
		var shoulder := _skel.get_bone_global_pose(_skel.get_bone_parent(arm)).basis.orthonormalized()
		_skel.set_bone_pose_rotation(arm, (shoulder.inverse() * arm_g).get_rotation_quaternion())
		_skel.set_bone_pose_rotation(elbow, (arm_g.inverse() * fore).get_rotation_quaternion())

	## Where each hand bone of the first-person arms sits on the gun (Talon space) in the rest pose
	## every first-person clip ends in. `whole` (the first-person model) is in the tree.
	func _grip_points(whole: Node3D) -> Dictionary:
		var sk: Skeleton3D = whole.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = whole.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("allanims")
		ap.seek(VIEWMODEL.CLIPS["settle"][1], true)
		var to_gun := _gun.global_transform.affine_inverse() * sk.global_transform
		var at := {}
		for side in ["L", "R"]:
			for h: String in HAND:
				at[side + "_" + h] = to_gun * sk.get_bone_global_pose(_find(sk, side + "_" + h)).origin
		return at

	## A bone by name without its numeric suffix ("R_thumb3" finds "R_thumb3_00").
	static func _find(sk: Skeleton3D, key: String) -> int:
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).begins_with(key + "_"):
				return i
		push_error("no bone " + key)
		return -1

	## Each hand bone's frame from joint positions alone (x along the bone, y toward the palm's
	## width), so two different rigs agree on it. With no tip joint (the first-person rig) the last
	## segment bends on from the middle one as the middle bends from the first, or the fingertips
	## would stick out straight instead of closing on the grip and the trigger.
	static func _frames(at: Dictionary) -> Dictionary:
		var f := {}
		for side in ["L", "R"]:
			var width: Vector3 = at[side + "_pink1"] - at[side + "_point1"]
			f[side + "_wrist"] = _frame(at[side + "_middle1"] - at[side + "_wrist"], width)
			for h: String in HAND.slice(1):
				var seg: String = side + "_" + h
				var next := seg.left(-1) + str(int(h.right(1)) + 1)
				if at.has(next):
					f[seg] = _frame(at[next] - at[seg], width)
				else:
					var first: Basis = f[seg.left(-1) + "1"]
					var mid: Basis = f[seg.left(-1) + "2"]
					f[seg] = Basis((mid * first.inverse()).get_rotation_quaternion()) * mid
		return f

	static func _frame(dir: Vector3, side: Vector3) -> Basis:
		var x := dir.normalized()
		var z := x.cross(side).normalized()
		return Basis(x, z.cross(x), z)

	static func _swing(from: Vector3, to: Vector3) -> Basis:
		var axis := from.cross(to)
		if axis.length() < 0.00001:
			return Basis()
		return Basis(axis.normalized(), from.angle_to(to))
