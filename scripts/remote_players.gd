extends Node3D
## Everyone else in the session, as third-person characters: the Mixamo body they picked
## (GameState.CHARACTERS) with the gun they hold in both hands, or bare-handed. One per peer whose
## pose arrives; gone when that peer leaves. The local player never gets one. Poses come ~20 times a
## second (GameState.pose_received) and are drawn DELAY behind, between the two snapshots around
## that moment, so the body glides instead of stepping or jittering with the network.
##
## Animation (assets/characters/players/player_anims.res, Mixamo's locomotion packs baked by
## tools/build_zombies.gd players): the whole body walks and runs in the stance of what is in hand
## (STANCES: bare fists, a pistol or SMG, the minigun as a rifle), in the direction it moves, the
## stride sped up past the clips' own pace. In the air the rifle pack's jump plays under the
## stance's arms; touching down standing still, its landing. The packs have no shot or reload: a
## shot kicks the chest up, a reload takes the left hand off the gun to the belt and tips the gun
## up. The look pitch bends spine and chest on top of that, so arms, gun and head aim where the
## player looks. Not aiming, the gun is held low and relaxed (LOWER); the sights up, a spinning
## gun's barrels turning or a shot from the hip bring it up to the shoulder. A shot flips the gun
## about the grip and shoves it back, the hands with it, and throws a shell; the gun rides the right wrist, and both hands close round it as the first-person
## hands do (_grip). The gun is the first-person one: the same arms rig (assets/weapons/arms) posed
## at the gun's Idle with the arms hidden, so every gun the player can draw is there and the grip
## comes from where its first-person hands are. Before they have picked, only the name tag shows.

const BODIES := {
	"boss": preload("res://assets/characters/players/boss/boss.scn"),
	"masked": preload("res://assets/characters/players/masked/masked.scn"),
	"worker": preload("res://assets/characters/players/worker/worker.scn"),
	"brute": preload("res://assets/characters/players/brute/brute.scn"),
	"chupacabra": preload("res://assets/characters/players/chupacabra/chupacabra.scn"),
}
const ANIMS := preload("res://assets/characters/players/player_anims.res")
const ARMS := preload("res://assets/weapons/arms/arms.gltf")
const MUZZLE_FX := preload("res://scenes/muzzle_fx.tscn")
const VIEWMODEL := preload("res://scripts/viewmodel.gd")  # SETS: each gun's mesh, clips, bone, muzzle
const PLAYER := preload("res://scripts/player.gd")  # the special rounds' effect times
const DELAY := 0.1  # s behind the newest pose: two snapshots in hand even when one is late
const KEEP := 0.6   # s of snapshots kept
## Stance -> its standing clip and the moving clips laid out by the way they travel (the clip's
## "velocity" meta, hip heights per second in the model's frame). A clip name with "<" plays
## backwards, the other way (the male pack has no walking backwards).
const STANCES := {
	"fists": ["idle", ["walk", "run", "walk_left", "walk_right", "run_left", "run_right", "<walk", "<run"]],
	"pistol": ["pistol_idle", ["pistol_walk", "pistol_run", "pistol_walk_back", "pistol_run_back",
			"pistol_strafe_a", "pistol_strafe_b"]],
	"rifle": ["rifle_idle", ["rifle_walk", "rifle_run", "rifle_sprint", "rifle_walk_back", "rifle_run_back",
			"rifle_walk_left", "rifle_walk_right", "rifle_run_left", "rifle_run_right"]],
}
## GUNS id -> stance; anything else held is a pistol's.
const STANCE_OF := {"fists": "fists", "minigun": "rifle"}
## Crouched (Ctrl), whatever is in hand: the rifle pack's crouching legs, laid out the same way
## (a ground of its own next to the stances'), the stance's arms over them as in the air.
const CROUCH := ["rifle_crouch_idle", ["rifle_crouch_walk", "rifle_crouch_walk_back", "rifle_crouch_walk_left",
		"rifle_crouch_walk_right", "rifle_crouch_walk_fl", "rifle_crouch_walk_fr", "rifle_crouch_walk_bl",
		"rifle_crouch_walk_br"]]
const CROUCH_RATE := 6.0  # 1/s the capsule and the name tag go down and back up at
const MOVING := 0.5  # m/s; slower than this lands standing (the full crouch), faster runs on
const AIR_ARMS := 8.0  # 1/s the stance's arms take over in the air, and give back on the ground
## Hand bones, parents first, each with "L_"/"R_" in front; Mixamo's 4th (tip) segment stays as animated.
const HAND := ["wrist", "thumb1", "thumb2", "thumb3", "point1", "point2", "point3", "middle1", "middle2",
	"middle3", "ring1", "ring2", "ring3", "pink1", "pink2", "pink3"]
## The same fingers on the first-person (Rigify) arms: "R_point2" is "DEF-f_index.02.R".
const FP_FINGER := {"thumb": "thumb", "point": "f_index", "middle": "f_middle", "ring": "f_ring", "pink": "f_pinky"}
## And on the Mixamo rig: "R_point2" is "mixamorig_RightHandIndex2".
const MIXAMO_FINGER := {"thumb": "Thumb", "point": "Index", "middle": "Middle", "ring": "Ring", "pink": "Pinky"}
const LEFT_LET_GO := 0.2  # s for the left hand to leave the gun for a reload, and to come back
## Reloading, the left hand goes to the belt (m off the hips: out to its side, forward, down) and
## the gun tips up this far (rad).
const BELT := Vector3(0.18, -0.05, 0.12)
const RELOAD_TIP := 0.45
## A shot kicks the chest up by KICK (rad), springing back in KICK_BACK (1/s).
const KICK := 0.07
const KICK_BACK := 14.0
const SPINE_SHARE := 0.35  # of the pitch; the chest takes the rest, so arms and gun aim with all of it
const PITCH_MAX := 1.2  # rad either way; beyond it the torso would fold
## The head looks where the player looks; the body (arms and gun with it) comes after it, so a
## quick nod or shake of the mouse is a nod or a shake of the head, a yes or a no, the hands staying
## put. The head turns this far off the body (rad: yaw, pitch) before the body is pulled along...
const HEAD_FREE := Vector2(1.1, 0.6)
## ...and the body catches up this fast (1/s), much faster while shooting so the gun points true.
const BODY_CATCH := 2.5
const BODY_CATCH_SHOOTING := 18.0
const NECK_SHARE := 0.35  # of the head's turn the neck takes, the head the rest
const FLASH_TIME := 0.05  # s
## Not aiming, the gun swings down this far about the right shoulder (rad, per stance): held low
## and relaxed. It comes up to the shoulder while the sights are up (player.gd aiming(): the right
## mouse button, or a spinning gun's barrels turning) and for HIP_HOLD after a shot from the hip.
const LOWER := {"fists": 0.0, "pistol": 0.75, "rifle": 0.3}
const RAISE_TIME := 0.2  # s up to the shoulder and back down (the first-person sights take 0.18)
const RAISE_TIME_SHOT := 0.08  # s a shot from low brings it up in
const HIP_HOLD := 0.6  # s it stays up after the last shot
## The gun's own kick on top of the chest's, scaled by its SETS kick (the Deagle's 0.35 is 1): it
## flips up about the grip, the wrist with it, is shoved back and thrown a random way sideways each
## round. The SMGs (no Fire clip, SETS clip_fire) flip less per round and buzz; the Deagle snaps.
## A spring, as the first-person recoil: rounds faster than it settles pile up into a shake.
const RECOIL_FLIP := 0.4  # rad
const RECOIL_BACK := 0.06  # m
const RECOIL_SIDE := 0.06  # rad of yaw and of roll at most
const RECOIL_SMG := 0.45  # share of the flip without a Fire clip
const RECOIL_OMEGA := 30.0  # rad/s
const RECOIL_DAMPING := 0.55  # one small dip past rest
const RECOIL_PUSH := 57.0  # spring speed per round: peaks at about 1
const RUMBLE := 0.012  # rad of a spinning gun's shake at full speed
const SPIN_GAP := 0.4  # s after the last round a spinning gun's barrels start running down (unaimed)
const SHELL_SEEN := 30.0  # m; farther off its shells are not thrown, ours keep the shared pool
const LABEL_OVER := 0.25  # m over the top of the head
## Of the way from the head bone to the crown, where the eyes are on the bodies with an eye bone
## (The Boss 0.42, the Brute 0.44; the masked one's eye meshes too).
const EYE_UP := 0.43
const LABEL_HEIGHT := 2.0  # m above the feet before there is a body
## Render layer 3: the world camera sees it, floor decals and bullet holes don't land on it.
const BODY_LAYER := 4
## The body other players bump into (player.tscn's capsule) and friendly fire hits.
const BODY_RADIUS := 0.35
const BODY_HEIGHT := 1.8
const TAG_FONT := 24
const TAG_PAD := Vector2(8, 2)  # px around the name

var _chars := {}  # peer -> Character
## Our own body, drawn only into the lights' shadows: the camera never sees it, the floor gets our
## shadow (the first-person view has no body of its own). Fed our pose straight from player.gd.
var _own_shadow: Character


func _ready() -> void:
	add_to_group("remote_players")
	GameState.pose_received.connect(_on_pose)
	GameState.player_shot.connect(func(_s: int, victim: int, _a: Vector3, _d: Vector3, special: String) -> void:
		if special == "balloon" and _chars.has(victim):
			(_chars[victim] as Character).balloons())
	multiplayer.peer_disconnected.connect(_drop)
	multiplayer.server_disconnected.connect(func() -> void:
		for peer in _chars.keys():
			_drop(peer))


## The character standing in for `peer`, or null if there is none (yet).
func character(peer: int) -> Character:
	return _chars.get(peer)


func _physics_process(_delta: float) -> void:
	var me := get_tree().get_first_node_in_group("walker") as CharacterBody3D
	if me == null:
		return
	if _own_shadow == null:
		_own_shadow = Character.new(GameState.local_peer(), true)
		add_child(_own_shadow)
	_own_shadow.peer = GameState.local_peer()  # a new id on joining someone
	_own_shadow.push(Time.get_ticks_msec() / 1000.0, me.global_position, me._yaw, me._pitch, me._act(),
			me._air_time > me.AIR_SHOWN, me.crouched, me.aiming())


func _on_pose(peer: int, t: float, pos: Vector3, yaw: float, pitch: float, act: int, air: bool,
		crouch := false, aim := false) -> void:
	if peer == GameState.local_peer():
		return
	if not _chars.has(peer):
		var c := Character.new(peer)
		add_child(c)
		_chars[peer] = c
	(_chars[peer] as Character).push(t, pos, yaw, pitch, act, air, crouch, aim)


func _drop(peer: int) -> void:
	if _chars.has(peer):
		_chars[peer].queue_free()
		_chars.erase(peer)


class Character extends Node3D:
	# Sounds (Faz 6, step 25): steps and reloads play from this node, shots from muzzle_position().
	var peer: int
	var shadow_only := false  # our own body (_own_shadow): no tag, nothing to bump, not seen
	var _delay := DELAY
	var act := GameState.Act.IDLE
	var air := false
	var crouch := false
	var aim := false  # the gun up at the shoulder (player.gd aiming())
	var _raise := 0.0  # 0 held low .. 1 up at the shoulder
	var _since_shot := INF  # s
	var _crouch_drop := 0.0  # 0..1, the capsule and the tag on their way down to crouching
	var _ground := ""  # the ground clips playing: the stance's, or "crouch"
	var speed := 0.0  # m/s along the ground, as drawn
	var look := ""  # CHARACTERS id worn; "" until they pick
	var stance := "fists"
	var _vel := Vector2.ZERO  # m/s in the model's frame (x its left, y its forward), smoothed
	var _snaps: Array = []  # [local time, pos, yaw, pitch, act, air, crouch, aim], oldest first
	var _clock := 0.0  # the sender's clock minus ours, smoothed
	var _pitch := 0.0  # rad the body leans to look, after the head (HEAD_FREE)
	var _look_pitch := 0.0  # rad the player looks, smoothed
	var _body_yaw := INF  # rad the body faces; the look's yaw is the head's
	var _look_yaw := 0.0
	var _last_pos := Vector3.INF
	var _model: Node3D  # the body, null before they pick
	var _skel: Skeleton3D
	var _tree: AnimationTree
	var _hip := 1.0  # m, the body's hip height: the clips' strides and hips are per hip height
	## The body's size here: its eyes at the player's (player.gd EYE), where its own camera is, or a
	## Brute stood a head taller than the player wearing it sees himself.
	var _size := 1.0
	var _paces := {}  # stance -> [[direction, m/s]] of its moving clips, for the stride's pace
	var _air_arms := 0.0  # 0..1, the stance's arms over the jump
	var _gun: Node3D  # holds the first-person rig, in the body's frame
	var _fp_skel: Skeleton3D
	var _rig: Node3D  # the first-person arms under _gun, sized to this body's hand (_show_gun)
	var _fp_anim: AnimationPlayer
	var _muzzle: Node3D
	var _port: Node3D  # the ejection port
	var gun := 0  # GameState.GUNS index shown; 0 is bare fists
	var _kit := {}  # its VIEWMODEL.SETS entry; {} bare-handed
	var _recoil := 0.0  # the gun's kick spring: 1 about the peak of one round
	var _recoil_vel := 0.0
	var _recoil_flip := 0.0  # rad and m of the last round's kick at 1
	var _recoil_back := 0.0
	var _recoil_side := Vector2.ZERO  # rad of yaw and roll at 1
	var _barrel := -1  # a spinning gun's barrel bone on the first-person rig, -1 for the others
	var _barrel_rest: Quaternion  # its pose at Idle
	var _spin := 0.0  # 0 stopped .. 1 up to speed
	var _barrel_turn := 0.0  # rad
	var _step := Vector3.ZERO  # m/s the character moves, as drawn
	var _hand_hold: Transform3D  # the right wrist in the stance, before the pitch bend
	var _spine_hold: Basis  # the spine standing in the stance; the upper body keeps to it
	var _gun_in_hand: Transform3D  # the gun relative to the right wrist bone, as the clips move it
	## How far the gun comes back toward the body (m, its own -Z): the stance holds the arms out,
	## and on a gun whose support hand sits ahead of the grip the left one would fall short; the
	## right arm bends to the grip instead (_grip).
	var _pull := 0.0
	var _right_wrist_on_gun: Vector3
	var _left_shoulder: Vector3  # the left arm's root in the stance, and how far it reaches
	var _left_reach := 0.0
	var _hand := {}  # "R_point1" etc. -> bone
	var _on_gun := {}  # "R_point1" etc. -> that bone's turn in gun space, from the first-person grip
	var _left_wrist_on_gun: Vector3
	var _on_gun_at := {}  # "R_point3" etc. -> where the first-person joint is on the gun
	var _left_hold := 1.0  # 0 while the left hand is off the gun for a reload
	## The first-person hand's size over the body's: on the gun the body's hand shrinks or grows to
	## it, or the same finger pose reaches past the trigger.
	var _hand_scale := 1.0
	var _kick := 0.0  # rad the chest is thrown up by the last shot
	var _spine := -1
	var _chest := -1
	var _wrist := -1
	var _neck := -1
	var _head := -1
	var _flash: Node3D
	var _flash_left := 0.0
	var _fx: Node3D
	var _tag_box: MeshInstance3D
	var _tag_mat: StandardMaterial3D
	var _tag_label: Label3D
	var _tag_y := LABEL_HEIGHT  # standing
	var _shape: CapsuleShape3D
	## What others collide with and shoot at; carries the peer id as meta "peer".
	var body: AnimatableBody3D

	## The balloon round's balloons over their head, for as long as it lifts and lets them down
	## (player.gd BALLOON_*: up and down at the same speed).
	func balloons() -> void:
		var old := get_node_or_null("Balloons")
		if old:
			old.free()
		var b: Node3D = load(GameState.SPECIALS.balloon.tip).instantiate()
		b.name = "Balloons"
		b.rotation.z = PI / 2.0  # the bunch grows along +X: up
		b.scale = Vector3.ONE * 0.9
		b.position.y = _tag_label.position.y + 0.2
		add_child(b)
		var t := b.create_tween()
		t.tween_interval(PLAYER.BALLOON_TIME * 2.0)
		t.tween_callback(b.queue_free)

	func _init(id: int, shadow := false) -> void:
		peer = id
		shadow_only = shadow
		_delay = 0.0 if shadow else DELAY  # our pose is here already, no network to wait for
		name = "Player%d" % id if not shadow else "OwnShadow"
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # placed per frame
		visible = false  # until the first pose places it

	func _ready() -> void:
		# The first-person arms with every gun on them; only the gun in hand shows, and the arms
		# only lend their grip. Carried over from body to body.
		_gun = Node3D.new()
		_rig = ARMS.instantiate()
		_gun.add_child(_rig)
		_fp_skel = _rig.find_child("Skeleton3D", true, false)
		_fp_anim = _rig.find_child("AnimationPlayer", true, false)
		(_fp_skel.get_node("Mesh") as Node3D).visible = false
		VIEWMODEL.load_clips(_fp_anim, _fp_skel)
		VIEWMODEL.add_pistol(_fp_skel)
		_muzzle = Node3D.new()
		_gun.add_child(_muzzle)
		_port = Node3D.new()
		_gun.add_child(_port)
		add_child(_gun)
		_gun.visible = false
		for v: VisualInstance3D in _gun.find_children("*", "VisualInstance3D", true, false):
			v.layers = BODY_LAYER
		# The first-person gun's flash, copied into this world (its layer there is the gun's own).
		var fp := get_tree().get_first_node_in_group("first_person_gun")
		if fp and not shadow_only:
			_flash = fp.get_node("Flash").duplicate()
			for v: VisualInstance3D in _flash.find_children("*", "VisualInstance3D", true, false):
				v.layers = 1
			_flash.visible = false
			_flash.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			add_child(_flash)
		_fx = MUZZLE_FX.instantiate()
		_fx.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_fx)
		if not shadow_only:
			body = AnimatableBody3D.new()
			body.sync_to_physics = false  # placed with the character every frame
			body.set_meta("peer", peer)
			var shape := CollisionShape3D.new()
			_shape = CapsuleShape3D.new()
			_shape.radius = BODY_RADIUS
			_shape.height = BODY_HEIGHT
			shape.shape = _shape
			shape.position.y = BODY_HEIGHT * 0.5
			body.add_child(shape)
			add_child(body)
		_name_tag()
		if shadow_only:
			_tag_label.visible = false
			_tag_box.visible = false
		gun = GameState.player(peer).gun
		_dress(GameState.player(peer).character)
		GameState.character_changed.connect(func(who: int, id: String) -> void:
			if who == peer:
				_dress(id))
		GameState.gun_changed.connect(func(who: int, g: int) -> void:
			if who == peer:
				_show_gun(g))
		GameState.pistol_grip.connect(func(who: int, level: int) -> void:
			if who == peer:
				VIEWMODEL.pistol_grip(_fp_skel, level > 0))
		_shadow_only()

	## Puts on CHARACTERS `id`'s body (none for ""), its animation and its hands' place on the gun.
	func _dress(id: String) -> void:
		if id == look and (_model != null or id == ""):
			return
		look = id
		if _model:
			_gun.reparent(self, false)
			_model.free()
			_model = null
			_skel = null
			_tree = null
		if not BODIES.has(id):
			_gun.visible = false
			_tag_y = LABEL_HEIGHT
			_place_tag()
			return
		_model = BODIES[id].instantiate()
		_model.rotation.y = PI  # it faces +Z; the player's forward is -Z
		add_child(_model)
		_skel = _model.get_node("Skeleton3D")
		_hip = _skel.get_bone_global_rest(0).origin.y
		_skel.motion_scale = _hip
		_size = PLAYER.EYE / _eye_height()
		_model.scale = Vector3.ONE * _size
		_spine = _skel.find_bone("mixamorig_Spine")
		_chest = _skel.find_bone("mixamorig_Spine1")
		_wrist = _skel.find_bone("mixamorig_RightHand")
		_neck = _skel.find_bone("mixamorig_Neck")
		_head = _skel.find_bone("mixamorig_Head")
		_hand.clear()
		for side in ["L", "R"]:
			for h: String in HAND:
				_hand[side + "_" + h] = _skel.find_bone(_mixamo(side + "_" + h))
		var top := _skel.find_bone("mixamorig_HeadTop_End")
		_tag_y = _skel.get_bone_global_rest(top).origin.y * _size + LABEL_OVER
		_place_tag()
		_paces.clear()
		for s: String in _grounds():
			_paces[s] = []
			for clip: String in _grounds()[s][1]:
				_paces[s].append(_clip_velocity(clip))
		_tree = _animation_tree()
		_model.add_child(_tree)
		_gun.reparent(_model, false)
		# Off the floor paint's layer: its decals (cull_mask 1) were printing onto boots and legs.
		for v: VisualInstance3D in _model.find_children("*", "VisualInstance3D", true, false):
			v.layers = BODY_LAYER
		_show_gun(gun)
		_shadow_only()

	## Our own body (shadow_only): every part of it cast into the lights' shadows, none drawn.
	func _shadow_only() -> void:
		if not shadow_only:
			return
		for g: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	## Shows GameState.GUNS[`g`] in the hands and fits the hands to it: the first-person rig posed at
	## the gun's Idle, its hands' joints on the gun are where the body's go (_grip). Bare fists
	## hide it and let the arms swing with the legs.
	func _show_gun(g: int) -> void:
		gun = g
		if _model == null:
			return
		stance = STANCE_OF.get(GameState.GUNS[g].id, "pistol")
		_ground = ""
		_pick_ground()
		_tree.set("parameters/arms/transition_request", stance)
		_hold_pose()
		_gun.visible = g != 0
		_kit = {}
		_barrel = -1
		_recoil = 0.0
		_recoil_vel = 0.0
		if g == 0:
			for side in ["L", "R"]:  # the grip resized them to the first-person hand's
				_skel.set_bone_pose_scale(_hand[side + "_wrist"], Vector3.ONE)
			return
		var set: Dictionary = VIEWMODEL.SETS[GameState.GUNS[g].id]
		_kit = set
		for each: Dictionary in VIEWMODEL.SETS.values():
			if each.mesh != "":
				(_fp_skel.get_node(NodePath(each.mesh)) as Node3D).visible = each == set
		VIEWMODEL.pistol_grip(_fp_skel, GameState.player(peer).levels.grip > 0)
		_fp_anim.play(set.clips + "Idle")
		_fp_anim.seek(0.0, true)
		_fp_anim.advance(0.0)
		_fp_anim.pause()  # held still: the body's own clips move the hands
		VIEWMODEL.fix_pose(_fp_skel, set)
		if set.has("spin"):  # turned here, as viewmodel.gd turns ours
			_barrel = _fp_skel.find_bone(set.spin.bone)
			_barrel_rest = _fp_skel.get_bone_pose_rotation(_barrel)
		_gun.transform = Transform3D()
		# The gun grows with the hand holding it: a Brute's fist round the first-person pistol made
		# it look a toy. The rig is scaled so its hand is this body's, and the body's hand stays as is.
		var fp_hand := _fp_skel.get_bone_global_rest(_fp_skel.find_bone(_fp_name("R_wrist"))).origin.distance_to(
				_fp_skel.get_bone_global_rest(_fp_skel.find_bone(_fp_name("R_middle1"))).origin)
		var own_hand := _skel.get_bone_global_rest(_hand["R_wrist"]).origin.distance_to(
				_skel.get_bone_global_rest(_hand["R_middle1"]).origin)
		_rig.scale = Vector3.ONE * own_hand / fp_hand
		var to_gun := _gun.global_transform.affine_inverse() * _fp_skel.global_transform
		var on_gun := {}
		for key: String in _hand:
			on_gun[key] = to_gun * _fp_skel.get_bone_global_pose(_fp_skel.find_bone(_fp_name(key))).origin
		var bone := _fp_skel.find_bone(set.bone)
		_muzzle.position = to_gun * (_fp_skel.get_bone_global_pose(bone) * (set.muzzle as Vector3))
		_port.position = to_gun * (_fp_skel.get_bone_global_pose(bone) * (set.port as Vector3))
		# Hand bones turned in gun space as the first-person hands are: line each one's own frame
		# (along the bone, rolled by the palm's width) up with the first-person bone's.
		var rest := {}
		for key: String in _hand:
			rest[key] = _skel.get_bone_global_rest(_hand[key]).origin
			if key.ends_with("3"):  # Mixamo's tips: its last segments' own line
				rest[key.left(-1) + "4"] = _skel.get_bone_global_rest(_skel.find_bone(_mixamo(key.left(-1) + "4"))).origin
		var own := _frames(rest)
		var theirs := _frames(on_gun)
		for key: String in _hand:
			var r := _skel.get_bone_global_rest(_hand[key]).basis.orthonormalized()
			_on_gun[key] = theirs[key] * own[key].inverse() * r
		_left_wrist_on_gun = on_gun["L_wrist"]
		_right_wrist_on_gun = on_gun["R_wrist"]
		_on_gun_at = on_gun
		_hand_scale = on_gun["R_wrist"].distance_to(on_gun["R_middle1"]) / (rest["R_wrist"] as Vector3).distance_to(rest["R_middle1"])
		# Aimed straight ahead (the model's +Z), the right wrist where the first-person one is.
		_gun_in_hand = _hand_hold.affine_inverse() * Transform3D(Basis(), _hand_hold.origin - on_gun["R_wrist"])
		# Back toward the body only as far as the left hand needs to reach its place (m), and no
		# further than it brings the place nearer: a short-armed, wide body never gets there, and the
		# gun went on into his face.
		_pull = 0.0
		var far := INF
		while _pull < 0.4:
			var d := _left_shoulder.distance_to(_hand_hold * _gun_in_hand * Transform3D(Basis(), Vector3(0.0, 0.0, -_pull)) * _left_wrist_on_gun)
			if d <= _left_reach * 0.97:
				break
			if d >= far:
				_pull -= 0.005
				break
			far = d
			_pull += 0.005

	## How high this body's eyes are standing with a pistol (m, its own size): its eye bone, or as
	## far up the head as the ones that have one (EYE_UP), carried through the pose; the stance's
	## bent knees take a few centimetres off the rest pose.
	func _eye_height() -> float:
		var head := _skel.find_bone("mixamorig_Head")
		var head_rest := _skel.get_bone_global_rest(head)
		var eye := _skel.find_bone("mixamorig_LeftEye")
		var at: Vector3
		if eye >= 0:
			at = _skel.get_bone_global_rest(eye).origin
		else:
			var crown := _skel.get_bone_global_rest(_skel.find_bone("mixamorig_HeadTop_End")).origin
			at = head_rest.origin.lerp(crown, EYE_UP)
		var in_head := head_rest.affine_inverse() * at
		var ap := AnimationPlayer.new()
		_model.add_child(ap)
		ap.root_node = ^".."
		ap.add_animation_library("", ANIMS)
		ap.play(STANCES.pistol[0])
		ap.seek(0.0, true)
		var y := (_skel.get_bone_global_pose(head) * in_head).y
		ap.free()
		return y

	## The body standing in the stance's first frame, measured: where the right wrist holds the gun,
	## how the spine stands, where the left arm starts and how far it reaches. The tree poses it
	## again on its next step.
	func _hold_pose() -> void:
		var ap := AnimationPlayer.new()
		_model.add_child(ap)
		ap.root_node = ^".."
		ap.add_animation_library("", ANIMS)
		ap.play(STANCES[stance][0])
		ap.seek(0.0, true)
		_hand_hold = _skel.get_bone_global_pose(_wrist)
		_spine_hold = _skel.get_bone_global_pose(_spine).basis.orthonormalized()
		var elbow := _skel.get_bone_parent(_hand["L_wrist"])
		var upper := _skel.get_bone_parent(elbow)
		var at_elbow := _skel.get_bone_global_pose(elbow).origin
		_left_shoulder = _skel.get_bone_global_pose(upper).origin
		_left_reach = _left_shoulder.distance_to(at_elbow) + at_elbow.distance_to(_skel.get_bone_global_pose(_hand["L_wrist"]).origin)
		ap.free()

	## The clip's way and pace of travel on this body: [direction, m/s] in the model's frame.
	func _clip_velocity(clip: String) -> Array:
		var back := clip.begins_with("<")
		var v: Vector2 = ANIMS.get_animation(clip.trim_prefix("<")).get_meta("velocity") * _hip * _size
		return [-v if back else v]

	## "Oyuncu N" in a box of the player's colour, the same size on screen at any distance, seen
	## through walls and the heap so teammates stay findable.
	func _name_tag() -> void:
		var label := Label3D.new()
		label.text = GameState.display_name(peer)
		label.position.y = LABEL_HEIGHT
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.001
		label.font_size = TAG_FONT
		label.outline_size = 6
		label.render_priority = 2  # over the box
		label.outline_render_priority = 1
		add_child(label)
		_tag_label = label
		var px := label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT) if label.font 			else ThemeDB.fallback_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT)
		var quad := QuadMesh.new()
		quad.size = (Vector2(px.x, TAG_FONT) + TAG_PAD * 2.0) * label.pixel_size
		_tag_mat = StandardMaterial3D.new()
		_tag_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tag_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_tag_mat.fixed_size = true
		_tag_mat.no_depth_test = true
		_tag_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tag_mat.render_priority = 0
		quad.material = _tag_mat
		_tag_box = MeshInstance3D.new()
		_tag_box.mesh = quad
		_tag_box.layers = BODY_LAYER
		_tag_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tag_box.position.y = LABEL_HEIGHT
		add_child(_tag_box)
		_tint_tag()
		GameState.player_slots.connect(_tint_tag.unbind(1))

	func _tint_tag() -> void:
		_tag_label.text = GameState.display_name(peer)  # the slot may come after the player
		var c := GameState.color_of(peer)
		c.a = 0.8
		_tag_mat.albedo_color = c

	## On the ground, each stance's clips blended by the way and pace it moves (a 2D blend space
	## each, one of them on at a time), sped up past their top pace. In the air the rifle pack's
	## jump; landing standing, its landing as a one-shot. From the spine up the stance's standing
	## clip over the jump and the landing. Advanced by hand (_process), so the pitch bend and the
	## grip go on after the clips have posed the bones.
	func _animation_tree() -> AnimationTree:
		var ground := AnimationNodeBlendTree.new()
		var pick := AnimationNodeTransition.new()
		pick.xfade_time = 0.2
		var upper := AnimationNodeTransition.new()
		upper.xfade_time = 0.2
		var grounds := _grounds()
		for s: String in grounds:
			var space := AnimationNodeBlendSpace2D.new()
			space.min_space = Vector2(-12, -12)
			space.max_space = Vector2(12, 12)
			space.add_blend_point(_clip(grounds[s][0]), Vector2.ZERO, -1, "stand")
			for clip: String in grounds[s][1]:
				space.add_blend_point(_clip(clip), _clip_velocity(clip)[0], -1, clip.replace("<", "back_"))
			ground.add_node(s, space)
			pick.add_input(s)
		for s: String in STANCES:
			upper.add_input(s)
		ground.add_node("stance", pick)
		for i in grounds.size():
			ground.connect_node("stance", i, grounds.keys()[i])
		ground.add_node("pace", AnimationNodeTimeScale.new())
		ground.connect_node("pace", 0, "stance")
		ground.connect_node("output", 0, "pace")
		var legs := AnimationNodeStateMachine.new()
		legs.add_node("ground", ground)
		legs.add_node("jump_up", _clip("rifle_jump_up"))
		legs.add_node("jump", _clip("rifle_jump_loop"))
		legs.add_transition("Start", "ground", _go(""))
		legs.add_transition("ground", "jump_up", _go("air"))
		legs.add_transition("jump_up", "jump", _go("", true))
		legs.add_transition("jump_up", "ground", _go("landed"))
		legs.add_transition("jump", "ground", _go("landed"))
		var body := AnimationNodeBlendTree.new()
		body.add_node("legs", legs)
		# Touching down standing still: the full crouch over the legs (running on, it is skipped).
		body.add_node("land_clip", _clip("rifle_jump_down"))
		var land := AnimationNodeOneShot.new()
		land.fadein_time = 0.05
		land.fadeout_time = 0.3
		body.add_node("land", land)
		body.connect_node("land", 0, "legs")
		body.connect_node("land", 1, "land_clip")
		for s: String in STANCES:
			body.add_node("hold_" + s, _clip(STANCES[s][0]))
		body.add_node("arms", upper)
		for i in STANCES.size():
			body.connect_node("arms", i, "hold_" + STANCES.keys()[i])
		var mix := AnimationNodeBlend2.new()
		mix.filter_enabled = true
		for b in _skel.get_bone_count():
			if _is_upper(b):
				mix.set_filter_path(NodePath("Skeleton3D:" + _skel.get_bone_name(b)), true)
		body.add_node("mix", mix)
		body.connect_node("mix", 0, "land")
		body.connect_node("mix", 1, "arms")
		body.connect_node("output", 0, "mix")
		var tree := AnimationTree.new()
		tree.add_animation_library("", ANIMS)
		tree.root_node = ^".."  # the body's scene root: the clips' track paths start there
		tree.tree_root = body
		tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
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
		a.animation = clip.trim_prefix("<")
		if clip.begins_with("<"):
			a.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
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

	## The ground clips by name: every stance's, and crouching's.
	static func _grounds() -> Dictionary:
		var all := STANCES.duplicate()
		all["crouch"] = CROUCH
		return all

	## The legs on the stance's ground clips, or on the crouching ones.
	func _pick_ground() -> void:
		var want := "crouch" if crouch else stance
		if want != _ground:
			_ground = want
			_tree.set("parameters/legs/ground/stance/transition_request", want)

	func _place_tag() -> void:
		var y := _tag_y - (PLAYER.EYE - PLAYER.CROUCH_EYE) * smoothstep(0.0, 1.0, _crouch_drop)
		_tag_label.position.y = y
		_tag_box.position.y = y

	## One snapshot from the network, on the sender's clock.
	func push(t: float, pos: Vector3, yaw: float, pitch: float, a: int, in_air: bool, crouched := false, aimed := false) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		var gap := now - t
		_clock = gap if _snaps.is_empty() else lerpf(_clock, gap, 0.05)  # evens out network jitter
		var at := t + _clock
		if not _snaps.is_empty() and at <= _snaps[-1][0]:
			return  # late or repeated
		_snaps.append([at, pos, yaw, pitch, a, in_air, crouched, aimed])
		while _snaps.size() > 2 and _snaps[1][0] < now - KEEP:
			_snaps.pop_front()

	func _process(delta: float) -> void:
		if _snaps.is_empty():
			return
		var t := Time.get_ticks_msec() / 1000.0 - _delay
		var a: Array = _snaps[0]
		var b: Array = a
		for s: Array in _snaps:
			b = s
			if s[0] >= t:
				break
			a = s
		var f := 0.0 if b[0] <= a[0] else clampf((t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
		global_position = (a[1] as Vector3).lerp(b[1], f)
		_look_yaw = lerp_angle(a[2], b[2], f)
		_since_shot += delta
		# The SMGs and the minigun play no Fire clip (act stays put): their rounds tell.
		var shooting: bool = b[4] == GameState.Act.SHOOTING or _since_shot < HIP_HOLD
		var catch := BODY_CATCH_SHOOTING if shooting else BODY_CATCH
		if _body_yaw == INF:
			_body_yaw = _look_yaw
		_body_yaw = lerp_angle(_body_yaw, _look_yaw, 1.0 - exp(-delta * catch))
		var off := wrapf(_look_yaw - _body_yaw, -PI, PI)
		_body_yaw = _look_yaw - clampf(off, -HEAD_FREE.x, HEAD_FREE.x)
		rotation.y = _body_yaw
		if _last_pos != Vector3.INF and delta > 0.0:
			var step := (global_position - _last_pos) * Vector3(1, 0, 1) / delta
			_step = step
			var local := global_basis.inverse() * step  # forward is -Z here, +Z on the model
			_vel = _vel.lerp(Vector2(-local.x, -local.z), 1.0 - exp(-delta * 10.0))
			speed = _vel.length()
		_last_pos = global_position
		var was_air := air
		act = b[4]
		air = b[5]
		crouch = b[6]
		aim = b[7]
		visible = true
		_crouch_drop = move_toward(_crouch_drop, 1.0 if crouch else 0.0, delta * CROUCH_RATE)
		if _shape:  # others bump into and shoot at the lower body
			_shape.height = lerpf(BODY_HEIGHT, PLAYER.CROUCH_HEIGHT, _crouch_drop)
			(body.get_child(0) as Node3D).position.y = _shape.height * 0.5
		_place_tag()
		if _model == null:
			return
		_pick_ground()
		if was_air and not air and speed < MOVING:
			_tree.set("parameters/land/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_tree.set("parameters/legs/ground/%s/blend_position" % _ground, _vel)
		_tree.set("parameters/legs/ground/pace/scale", _pace())
		_tree.set("parameters/legs/conditions/air", air)
		_tree.set("parameters/legs/conditions/landed", not air)
		var landing: bool = _tree.get("parameters/land/active")
		_air_arms = move_toward(_air_arms, 1.0 if (air or landing or crouch) and stance != "rifle" else 0.0, delta * AIR_ARMS)
		_tree.set("parameters/mix/blend_amount", _air_arms)
		_tree.advance(delta)
		_kick = move_toward(_kick, 0.0, _kick * KICK_BACK * delta + 0.0001)
		_look_pitch = lerpf(_look_pitch, clampf(lerpf(a[3], b[3], f), -PITCH_MAX, PITCH_MAX), 1.0 - exp(-delta * 20.0))
		_pitch = lerpf(_pitch, _look_pitch, 1.0 - exp(-delta * catch))
		_pitch = _look_pitch - clampf(_look_pitch - _pitch, -HEAD_FREE.y, HEAD_FREE.y)
		_bend(_pitch + _kick)
		_left_hold = move_toward(_left_hold, 0.0 if act == GameState.Act.RELOADING else 1.0, delta / LEFT_LET_GO)
		var hip := _since_shot < HIP_HOLD
		_raise = move_toward(_raise, 1.0 if aim or hip else 0.0, delta / (RAISE_TIME_SHOT if hip else RAISE_TIME))
		_spring(delta)
		if gun != 0:
			var tip := Transform3D(Basis(Vector3.RIGHT, -RELOAD_TIP * (1.0 - _left_hold)), Vector3.ZERO)
			var held := _skel.get_bone_global_pose(_wrist) * _gun_in_hand * Transform3D(Basis(), Vector3(0.0, 0.0, -_pull)) * tip
			_gun.transform = _kicked(_lowered(held), delta)
			_grip()
		_turn_head(wrapf(_look_yaw - _body_yaw, -PI, PI), _look_pitch - _pitch)
		if _flash:
			_flash.global_transform = Transform3D(_gun.global_basis.orthonormalized(), muzzle_position())
			_flash_left -= delta
			_flash.visible = _flash_left > 0.0

	## How much faster than its clips the stride goes: the moving clip pointing most the way it
	## goes sets the top pace that way.
	func _pace() -> float:
		if speed < MOVING:
			return 1.0
		var top := 0.0
		var dir := _vel / speed
		for p: Array in _paces[_ground]:
			var v: Vector2 = p[0]
			top = maxf(top, v.dot(dir))
		return maxf(1.0, speed / top) if top > 0.1 else 1.0

	## Where this character's rounds visibly leave its gun (bare-handed: the right hand).
	func muzzle_position() -> Vector3:
		if _model == null:
			return global_position + Vector3.UP * 1.4
		if gun == 0:
			return _model.global_transform * _skel.get_bone_global_pose(_wrist).origin
		return _muzzle.global_position

	## A round left this player's gun: the chest and the gun kick, the flash and the powder jet at
	## the muzzle, a shell out of the port. Held low, the gun comes up first (HIP_HOLD).
	func shoot() -> void:
		var k := float(_kit.get("kick", 0.35)) / 0.35
		_kick = KICK * k
		_since_shot = 0.0
		_flash_left = FLASH_TIME
		_fx.global_transform = Transform3D(_gun.global_basis.orthonormalized(), muzzle_position())
		for p in _fx.get_children():
			if p is GPUParticles3D:
				(p as GPUParticles3D).restart()
		if _kit.is_empty() or _model == null:
			return
		_recoil_flip = RECOIL_FLIP * k * (1.0 if _kit.get("clip_fire", false) else RECOIL_SMG)
		_recoil_back = RECOIL_BACK * k
		_recoil_side = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * RECOIL_SIDE * k
		_recoil_vel += RECOIL_PUSH
		var fp := get_tree().get_first_node_in_group("first_person_gun")
		var cam := get_viewport().get_camera_3d()
		if fp and fp.has_method("eject_from") and cam and not shadow_only \
				and cam.global_position.distance_to(_port.global_position) < SHELL_SEEN:
			var g := _gun.global_basis.orthonormalized()  # as a camera behind the gun: x right, z back
			fp.eject_from(Basis(g.y.cross(-g.z), g.y, -g.z), _port.global_position, _step, body)

	## The gun's kick spring, in small steps: a slow frame would throw it off.
	func _spring(delta: float) -> void:
		var left := delta
		while left > 0.0:
			var dt := minf(left, 1.0 / 120.0)
			left -= dt
			_recoil_vel -= (RECOIL_OMEGA * RECOIL_OMEGA * _recoil + 2.0 * RECOIL_DAMPING * RECOIL_OMEGA * _recoil_vel) * dt
			_recoil += _recoil_vel * dt

	## The gun as held (the model's space) swung down about the right shoulder, as far as it is not raised.
	func _lowered(held: Transform3D) -> Transform3D:
		var down := float(LOWER[stance]) * (1.0 - smoothstep(0.0, 1.0, _raise))
		if down == 0.0:
			return held
		var shoulder := _skel.get_bone_global_pose(_skel.get_bone_parent(_skel.get_bone_parent(_wrist))).origin
		var turn := Basis(Vector3.RIGHT, down)  # the model faces +Z: down
		return Transform3D(turn, shoulder - turn * shoulder) * held

	## The gun with the last rounds' kick on it, about the grip (the right wrist's place on it); a
	## spinning gun's barrels turned and its shake.
	func _kicked(held: Transform3D, delta: float) -> Transform3D:
		var yaw := _recoil_side.x * _recoil
		var roll := _recoil_side.y * _recoil
		if _barrel >= 0:
			var s: Dictionary = _kit.spin
			var turning := aim or _since_shot < SPIN_GAP
			_spin = move_toward(_spin, 1.0 if turning else 0.0, delta / float(s.up if turning else s.down))
			_barrel_turn = fmod(_barrel_turn + _spin * float(s.speed) * delta, TAU)
			_fp_skel.set_bone_pose_rotation(_barrel, _barrel_rest * Quaternion(s.axis, _barrel_turn))
			yaw += randf_range(-1.0, 1.0) * RUMBLE * _spin
			roll += randf_range(-1.0, 1.0) * RUMBLE * _spin
		var turn := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -_recoil_flip * _recoil) * Basis(Vector3.BACK, roll)
		var grip := _right_wrist_on_gun
		return held * Transform3D(turn, grip + Vector3(0.0, 0.0, -_recoil_back * _recoil) - turn * grip)

	## Looking up or down, on top of the clips: the spine turns a share, the chest the rest (arms,
	## gun and head ride on it), both about the body's own side axis. With a gun the spine first
	## stands as it does in the stance, or the gun would wave off the aim with every stride and
	## a strafe's turned hips would turn it away.
	func _bend(pitch: float) -> void:
		var parent := _skel.get_bone_global_pose(_skel.get_bone_parent(_spine)).basis.orthonormalized()
		var spine := _spine_hold if gun != 0 else _skel.get_bone_global_pose(_spine).basis.orthonormalized()
		spine = Basis(Vector3.RIGHT, -pitch * SPINE_SHARE) * spine
		var chest := Basis(Vector3.RIGHT, -pitch * (1.0 - SPINE_SHARE)) * spine * Basis(_skel.get_bone_pose_rotation(_chest))
		_skel.set_bone_pose_rotation(_spine, (parent.inverse() * spine).get_rotation_quaternion())
		_skel.set_bone_pose_rotation(_chest, (spine.inverse() * chest).get_rotation_quaternion())

	## The head's own turn off the body's (rad, about the body's up and side), shared with the neck.
	func _turn_head(yaw: float, pitch: float) -> void:
		# Some bodies have a second neck bone between: whatever is between turns with the neck.
		var parent := _skel.get_bone_global_pose(_skel.get_bone_parent(_neck)).basis.orthonormalized()
		var neck := _skel.get_bone_global_pose(_neck).basis.orthonormalized()
		var above := _skel.get_bone_global_pose(_skel.get_bone_parent(_head)).basis.orthonormalized()
		var head := _skel.get_bone_global_pose(_head).basis.orthonormalized()
		var by_neck := Basis(Vector3.UP, yaw * NECK_SHARE) * Basis(Vector3.RIGHT, -pitch * NECK_SHARE)
		var turned_head := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch) * head
		_skel.set_bone_pose_rotation(_neck, (parent.inverse() * by_neck * neck).get_rotation_quaternion())
		_skel.set_bone_pose_rotation(_head, ((by_neck * above).inverse() * turned_head).get_rotation_quaternion())

	## Both hands on the gun as the first-person hands hold it, over whatever the clips did: the right
	## one wraps the grip with the index on the trigger guard, the left cups it from below. The left
	## arm reaches for its place with two-bone IK; for a reload it goes to the belt and back.
	func _grip() -> void:
		var gun_at := _gun.transform
		_reach(_wrist, gun_at * _right_wrist_on_gun)  # lowered, kicked or pulled in: off the clip's place
		_hold("R", gun_at, 1.0)
		var w := _hand["L_wrist"] as int
		var hips := _skel.get_bone_global_pose(0)
		var belt := hips.origin + hips.basis.orthonormalized() * BELT
		_reach(w, belt.lerp(gun_at * _left_wrist_on_gun, _left_hold))
		if _left_hold > 0.0:
			_hold("L", gun_at, _left_hold)
		else:
			_skel.set_bone_pose_scale(w, Vector3.ONE)

	## One hand's bones turned toward their place on the gun, by `weight`.
	func _hold(side: String, gun_at: Transform3D, weight: float) -> void:
		var glob := {}  # bone -> global basis, as set
		for h: String in HAND:
			var i: int = _hand[side + "_" + h]
			var p := _skel.get_bone_parent(i)
			var pg: Basis = glob[p] if glob.has(p) else _skel.get_bone_global_pose(p).basis.orthonormalized()
			var want := (pg.inverse() * gun_at.basis * (_on_gun[side + "_" + h] as Basis)).get_rotation_quaternion()
			var q := _skel.get_bone_pose_rotation(i).slerp(want, weight)
			_skel.set_bone_pose_rotation(i, q)
			glob[i] = pg * Basis(q)
		_skel.set_bone_pose_scale(_hand[side + "_wrist"], Vector3.ONE * lerpf(1.0, _hand_scale, weight))
		# The fingers root elsewhere on the two rigs: each one turns at its knuckle until its last
		# joint points where the first-person one is (the index's onto the trigger).
		for finger in ["thumb", "point", "middle", "ring", "pink"]:
			var root: int = _hand["%s_%s1" % [side, finger]]
			var g := _skel.get_bone_global_pose(root)
			var last := _skel.get_bone_global_pose(_hand["%s_%s3" % [side, finger]]).origin
			var want: Vector3 = gun_at * _on_gun_at["%s_%s3" % [side, finger]]
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

	## The first-person arms' bone for one of ours: "R_wrist" is "DEF-hand.R", "L_point2" "DEF-f_index.02.L".
	static func _fp_name(key: String) -> String:
		var side := key.left(1)
		var h := key.substr(2)
		if h == "wrist":
			return "DEF-hand." + side
		return "DEF-%s.0%s.%s" % [FP_FINGER[h.left(-1)], h.right(1), side]

	## The Mixamo bone for one of ours: "R_wrist" is "mixamorig_RightHand", "L_point4" "mixamorig_LeftHandIndex4".
	static func _mixamo(key: String) -> String:
		var side := "Right" if key.left(1) == "R" else "Left"
		var h := key.substr(2)
		if h == "wrist":
			return "mixamorig_%sHand" % side
		return "mixamorig_%sHand%s%s" % [side, MIXAMO_FINGER[h.left(-1)], h.right(1)]

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
