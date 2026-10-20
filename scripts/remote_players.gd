extends Node3D
## Everyone else in the session, as third-person characters (the bumstrum operator with the heavy
## pistol in both hands). One per peer whose pose arrives; gone when that peer leaves. The local
## player never gets one. Poses come ~20 times a second (GameState.pose_received) and are drawn
## DELAY behind, between the two snapshots around that moment, so the body glides instead of
## stepping or jittering with the network.
##
## No animation: the arms are posed once (two-bone IK onto the gun), the spine and chest bend
## with the look pitch, the body turns with the yaw and bobs a little while walking.
# ponytail: feet slide while walking; a walk cycle (Mixamo / Quaternius) can come with the art pass.

const MODEL := preload("res://assets/characters/operator/operator.gltf")
const GUN := preload("res://assets/weapons/heavy_pistol/heavy_pistol.gltf")
const MUZZLE_FX := preload("res://scenes/muzzle_fx.tscn")
const VIEWMODEL := preload("res://scripts/viewmodel.gd")  # MUZZLE, in the gun's own (Talon) space
const DELAY := 0.1  # s behind the newest pose: two snapshots in hand even when one is late
const KEEP := 0.6   # s of snapshots kept
const UNIT := 0.01  # the model is in centimetres
## Model space (cm, faces +Z, +X is the character's left): where the gun sits, aimed straight
## ahead at shoulder height, and where each wrist goes to hold it.
const GUN_AT := Vector3(-5.0, 145.0, 45.0)
const RIGHT_WRIST := Vector3(-5.0, 144.0, 37.0)
const LEFT_WRIST := Vector3(1.0, 141.0, 37.0)
const SPINE_SHARE := 0.35  # of the pitch; the chest takes the rest, so arms and gun aim with all of it
const PITCH_MAX := 1.2  # rad either way; beyond it the torso would fold
const RELOAD_PITCH := -0.45  # rad: head and gun drop to look at the reload
const BOB_FREQ := 9.0  # rad/s while walking
const BOB_AMP := 0.025  # m
const FLASH_TIME := 0.05  # s
const LABEL_HEIGHT := 2.1  # m above the feet

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


func _on_pose(peer: int, t: float, pos: Vector3, yaw: float, pitch: float, act: int) -> void:
	if peer == GameState.local_peer():
		return
	if not _chars.has(peer):
		var c := Character.new(peer)
		add_child(c)
		_chars[peer] = c
	(_chars[peer] as Character).push(t, pos, yaw, pitch, act)


func _drop(peer: int) -> void:
	if _chars.has(peer):
		_chars[peer].queue_free()
		_chars.erase(peer)


class Character extends Node3D:
	# Sounds (Faz 6, step 25): steps and reloads play from this node, shots from muzzle_position().
	var peer: int
	var act := GameState.Act.IDLE
	var _snaps: Array = []  # [local time, pos, yaw, pitch, act], oldest first
	var _clock := 0.0  # the sender's clock minus ours, smoothed
	var _pitch := 0.0
	var _bob := 0.0
	var _model: Node3D
	var _skel: Skeleton3D
	var _gun: Node3D
	var _gun_in_chest: Transform3D  # the gun's place relative to the chest bone
	var _spine := -1
	var _chest := -1
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
		_reach(_skel.find_bone("R_arm_039"), _skel.find_bone("R_elbow_040"), _skel.find_bone("R_wrist_041"), RIGHT_WRIST, Vector3(-0.6, -1.0, 0.0))
		_reach(_skel.find_bone("L_arm_015"), _skel.find_bone("L_elbow_016"), _skel.find_bone("L_wrist_017"), LEFT_WRIST, Vector3(0.6, -1.0, 0.0))
		# The heavy pistol on its own: the first-person model's gun part, without the arms.
		var whole: Node3D = GUN.instantiate()
		_gun = whole.find_child("Talon", true, false)
		_gun.get_parent().remove_child(_gun)
		whole.free()
		_gun.transform = Transform3D(Basis(), GUN_AT)
		_model.add_child(_gun)
		_gun_in_chest = _skel.get_bone_global_rest(_chest).affine_inverse() * _gun.transform
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

	## One snapshot from the network, on the sender's clock.
	func push(t: float, pos: Vector3, yaw: float, pitch: float, a: int) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		var gap := now - t
		_clock = gap if _snaps.is_empty() else lerpf(_clock, gap, 0.05)  # evens out network jitter
		var at := t + _clock
		if not _snaps.is_empty() and at <= _snaps[-1][0]:
			return  # late or repeated
		_snaps.append([at, pos, yaw, pitch, a])
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
		act = b[4]
		var pitch: float = RELOAD_PITCH if act == GameState.Act.RELOADING else lerpf(a[3], b[3], f)
		_pitch = lerpf(_pitch, clampf(pitch, -PITCH_MAX, PITCH_MAX), 1.0 - exp(-delta * 20.0))
		_bend(_pitch)
		_bob = _bob + delta * BOB_FREQ if act == GameState.Act.WALKING else 0.0
		_model.position.y = absf(sin(_bob)) * BOB_AMP
		_gun.transform = _skel.get_bone_global_pose(_chest) * _gun_in_chest
		if _flash:
			_flash.global_transform = Transform3D(_gun.global_basis.orthonormalized(), muzzle_position())
			_flash_left -= delta
			_flash.visible = _flash_left > 0.0
		visible = true

	## Where this character's rounds visibly leave its gun.
	func muzzle_position() -> Vector3:
		return _gun.global_transform * VIEWMODEL.MUZZLE

	## A round left this player's gun: the flash and the powder jet, at the muzzle.
	func shoot() -> void:
		_flash_left = FLASH_TIME
		_fx.global_transform = Transform3D(_gun.global_basis.orthonormalized(), muzzle_position())
		for p in _fx.get_children():
			if p is GPUParticles3D:
				(p as GPUParticles3D).restart()

	## Looking up or down: the spine takes a share, the chest (arms, gun and head ride on it) the rest.
	func _bend(pitch: float) -> void:
		var up := Basis(Vector3.RIGHT, -pitch)  # model space: tips +Z (forward) toward +Y
		var hips := _skel.get_bone_global_rest(_skel.get_bone_parent(_spine)).basis
		var spine := Basis(Vector3.RIGHT, -pitch * SPINE_SHARE) * _skel.get_bone_global_rest(_spine).basis
		var chest := up * _skel.get_bone_global_rest(_chest).basis
		_skel.set_bone_pose_rotation(_spine, (hips.inverse() * spine).get_rotation_quaternion())
		_skel.set_bone_pose_rotation(_chest, (spine.inverse() * chest).get_rotation_quaternion())

	## Two-bone IK at rest, once: upper arm and forearm turned so the wrist lands on `target`, the
	## elbow bending toward `pole`. Both are kept as poses under the chest, so they ride its bend.
	func _reach(arm: int, elbow: int, wrist: int, target: Vector3, pole: Vector3) -> void:
		var ga := _skel.get_bone_global_rest(arm)
		var ge := _skel.get_bone_global_rest(elbow)
		var gw := _skel.get_bone_global_rest(wrist)
		var s := ga.origin
		var la := s.distance_to(ge.origin)
		var lb := ge.origin.distance_to(gw.origin)
		var to := target - s
		var d := clampf(to.length(), absf(la - lb) + 0.01, la + lb - 0.01)
		var u := to.normalized()
		var v := (pole - u * pole.dot(u)).normalized()
		var cos_a := (la * la + d * d - lb * lb) / (2.0 * la * d)
		var e := s + la * (u * cos_a + v * sqrt(maxf(1.0 - cos_a * cos_a, 0.0)))
		var w := s + u * d
		var qa := Quaternion((ge.origin - s).normalized(), (e - s).normalized())
		var qe := Quaternion(qa * (gw.origin - ge.origin).normalized(), (w - e).normalized())
		var arm_b := Basis(qa) * ga.basis.orthonormalized()
		var elbow_b := Basis(qe * qa) * ge.basis.orthonormalized()
		var parent_b := _skel.get_bone_global_rest(_skel.get_bone_parent(arm)).basis.orthonormalized()
		_skel.set_bone_pose_rotation(arm, (parent_b.inverse() * arm_b).get_rotation_quaternion())
		_skel.set_bone_pose_rotation(elbow, (arm_b.inverse() * elbow_b).get_rotation_quaternion())
