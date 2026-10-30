extends Node3D
## The first-person arms as the player character's own (2026-10-30, the user's call): its arms,
## hands and what it wears on them (assets/characters/players/<id>/fp_arms.scn, cut from the body by
## tools/build_fp_arms.gd), on its own Mixamo skeleton, put each frame where the first-person rig's
## arms are. Every joint sits on the rig's (shoulder, elbow, wrist, each finger's), so the hands close
## on the grips and triggers as the rig's do; each bone is turned as the rig's is, lined up by frames
## both rigs agree on (remote_players.gd _frames: along the bone, the palm's width; the upper arm by
## the way the elbow bends). The arms are sized to the rig's hand, so a Brute's fist fits the guns.
## viewmodel.gd dress() puts it on and hides the rig's own arms.

const REMOTE := preload("res://scripts/remote_players.gd")  # Character: the hand's bones and frames
const ANIMS := preload("res://assets/characters/players/player_anims.res")
const BENT := "pistol_idle"  # a clip with the elbows bent: how this body's elbow hinges
const SIDES := {"L": "Left", "R": "Right"}

var _fp: Skeleton3D  # the first-person rig's, posed by its clips
var _sk: Skeleton3D  # the character's, its arm meshes on it
var _keys: Array[String] = []  # "R_upper", "R_fore", "R_wrist", "R_thumb1"...: parents first
var _bone := {}  # key -> the character's bone
var _fp_bone := {}  # key -> the rig's bone
var _own := {}  # key -> the character's bone frame at rest, from its joints
var _rest := {}  # key -> the character's bone's rest basis, in skeleton space
var _hinge := {}  # side -> the character's elbow axis at rest (the upper arm's frame's side)
var _size := 1.0  # the rig's hand over the character's


## On `fp`, `body` (an fp_arms.scn) in place of its own arms; drawn as `like` is.
func _init(fp: Skeleton3D, body: PackedScene, like: GeometryInstance3D) -> void:
	_fp = fp
	name = "CharacterArms"
	var scene: Node3D = body.instantiate()
	add_child(scene)
	_sk = scene.get_node("Skeleton3D")
	_sk.transform = Transform3D()
	for mi: MeshInstance3D in _sk.find_children("*", "MeshInstance3D", false, false):
		mi.layers = like.layers
		mi.cast_shadow = like.cast_shadow


func _ready() -> void:
	_measure(get_child(0))
	for side: String in SIDES:
		for k: String in ["upper", "fore"] + REMOTE.HAND:
			_keys.append(side + "_" + k)
	var at := {}
	for key in _keys:
		_bone[key] = _sk.find_bone(_mixamo(key))
		_fp_bone[key] = _fp.find_bone(_fp_name(key))
		_rest[key] = _sk.get_bone_global_rest(_bone[key]).basis
		at[key] = _sk.get_bone_global_rest(_bone[key]).origin
		if key.ends_with("3"):  # Mixamo's tips: its last segments' own line
			var tip := key.left(-1) + "4"
			at[tip] = _sk.get_bone_global_rest(_sk.find_bone(REMOTE.Character._mixamo(tip))).origin
	_own = _frames(at, _hinge)
	var fp_hand := _fp.get_bone_global_rest(_fp_bone.R_wrist).origin.distance_to(_fp.get_bone_global_rest(_fp_bone.R_middle1).origin)
	_size = fp_hand / (at.R_wrist as Vector3).distance_to(at.R_middle1)
	_fp.skeleton_updated.connect(_follow)
	_follow()


## The way each elbow hinges, from the body bent in BENT, carried back to the upper arm at rest.
func _measure(scene: Node3D) -> void:
	var ap := AnimationPlayer.new()
	scene.add_child(ap)
	ap.root_node = ^".."
	ap.add_animation_library("", ANIMS)
	ap.play(BENT)
	ap.seek(0.0, true)
	for side: String in SIDES:
		var arm := _sk.find_bone("mixamorig_%sArm" % SIDES[side])
		var fore := _sk.find_bone("mixamorig_%sForeArm" % SIDES[side])
		var hand := _sk.find_bone("mixamorig_%sHand" % SIDES[side])
		var a := _sk.get_bone_global_pose(arm)
		var bend := _bend(a.origin, _sk.get_bone_global_pose(fore).origin, _sk.get_bone_global_pose(hand).origin)
		_hinge[side] = _sk.get_bone_global_rest(arm).basis * (a.basis.inverse() * bend)
	ap.free()
	_sk.reset_bone_poses()


## Each of the rig's arm bones as it stands now, on the character's.
func _follow() -> void:
	var at := {}
	for key in _keys:
		at[key] = _fp.get_bone_global_pose(_fp_bone[key]).origin
	var theirs := _frames(at, {})
	for key in _keys:
		var turn: Basis = theirs[key] * (_own[key] as Basis).inverse() * (_rest[key] as Basis)
		_sk.set_bone_global_pose(_bone[key], Transform3D(turn.orthonormalized().scaled(Vector3.ONE * _size), at[key]))


## Frames for every key from joint positions: the hand's as remote_players.gd makes them, the
## forearm along itself rolled by the palm, the upper arm along itself rolled by the elbow's axis
## (`hinge` per side; empty: from how the elbow is bent in `at`).
static func _frames(at: Dictionary, hinge: Dictionary) -> Dictionary:
	var f: Dictionary = REMOTE.Character._frames(at)
	for side: String in SIDES:
		var sh: Vector3 = at[side + "_upper"]
		var el: Vector3 = at[side + "_fore"]
		var wr: Vector3 = at[side + "_wrist"]
		var palm: Vector3 = at[side + "_pink1"] - at[side + "_point1"]
		var axis: Vector3 = hinge[side] if hinge.has(side) else _bend(sh, el, wr)
		if axis.length() < 0.001:  # a straight arm: no bend to go by, the palm will do
			axis = palm
		f[side + "_upper"] = REMOTE.Character._frame(el - sh, axis)
		f[side + "_fore"] = REMOTE.Character._frame(wr - el, palm)
	return f


static func _bend(sh: Vector3, el: Vector3, wr: Vector3) -> Vector3:
	var n := (el - sh).cross(wr - el)
	return n.normalized() if n.length() > 0.0001 else Vector3.ZERO


static func _mixamo(key: String) -> String:
	var side: String = SIDES[key.left(1)]
	match key.substr(2):
		"upper":
			return "mixamorig_%sArm" % side
		"fore":
			return "mixamorig_%sForeArm" % side
	return REMOTE.Character._mixamo(key)


static func _fp_name(key: String) -> String:
	match key.substr(2):
		"upper":
			return "DEF-upper_arm." + key.left(1)
		"fore":
			return "DEF-forearm." + key.left(1)
	return REMOTE.Character._fp_name(key)
