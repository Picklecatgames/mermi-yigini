extends SkeletonModifier3D
## Where a round goes in, the body gives: the bone it hit turns away along the round, springs back,
## and the ones above it go a little with it (a shoulder hit swings the shoulder back and twists
## the chest; a head shot throws the head back). A hard round in a leg buckles the knee and drops
## the hips a moment. Laid over whatever the clips posed, after zombie_body.gd's Flinch. Every peer
## runs its own from the shot_landed event (where it went in, its direction, the gun): no dice.
## waves.gd adds one under each zombie's skeleton and calls hit().

## The bones a round can be put on (Mixamo), and how much of a hit each one passes to its parent.
const BONES := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm",
		"LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand",
		"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]
const PASS_ON := [0.6, 0.35, 0.2]  # of the kick to the bone's parent, grandparent and the one above
## gun id -> push (rad/s on the bone hit). The Deagle throws, the SMGs nudge often, the Minigun's
## stream keeps it shaking (the springs add up to MAX and no further).
const PUSH := {"fists": 3.0, "pistol": 6.0, "deagle": 11.0, "uzi": 4.5, "scorpion": 4.0, "minigun": 3.2}
const PUSH_OTHER := 5.0
const HEAD := 1.2  # times on the head
const STIFF := 260.0  # 1/s², ~2.6 Hz: quick out and back
const DAMP := 17.0  # 1/s: one swing past rest and it has settled
const MAX := 0.5  # rad on one bone
## A leg hit at least this hard (push) buckles: the knee bends KNEE rad/s per push, the hips drop.
const BUCKLE_FROM := 5.5
const KNEE := 0.9
const DIP := 0.15  # m/s per push on the hips, down; springs back like the rest
const DIP_MAX := 0.18  # m at size 1

var _sk: Skeleton3D
var _ids: Array[int] = []  # BONES found in this rig
var _turn := {}  # bone -> [angle (axis × rad, skeleton space), its speed]
var _hips := -1
var _dip := 0.0  # m down (skeleton space)
var _dip_v := 0.0


## `skel`: the zombie's skeleton (this goes under it). Creatures: every bone is a candidate.
func setup(skel: Skeleton3D) -> void:
	_sk = skel
	for b in BONES:
		var i := skel.find_bone("mixamorig_" + b)
		if i >= 0:
			_ids.append(i)
	if _ids.is_empty():
		for i in skel.get_bone_count():
			_ids.append(i)
	_hips = skel.find_bone("mixamorig_Hips")
	skel.add_child(self)


## A round in at `at` (world) going along `dir`, from `gun` (GameState.GUNS id); `head`: the weak spot.
func hit(at: Vector3, dir: Vector3, gun: String, head: bool) -> StringName:
	var b := _sk.find_bone("mixamorig_Head") if head else -1  # the weak spot's ball sits on the neck's top
	if b < 0:
		b = _bone_at(at)
	if b < 0:
		return &""
	var inv := _sk.global_transform.affine_inverse()
	var p := inv * at
	var d := (inv.basis * dir).normalized()
	var push: float = PUSH.get(gun, PUSH_OTHER) * (HEAD if head else 1.0)
	var name := _sk.get_bone_name(b).trim_prefix("mixamorig_")
	_kick(b, _axis(b, p, d) * push)
	var up := b
	for k: float in PASS_ON:  # a shoulder hit swings the shoulder back, and the chest twists with it
		up = _sk.get_bone_parent(up)
		if up < 0:
			break
		_kick(up, _axis(up, p, d) * push * k)
	if name.ends_with("Leg") or name.ends_with("Foot"):
		if push >= BUCKLE_FROM:
			var side := "Left" if name.begins_with("Left") else "Right"
			_kick(_sk.find_bone("mixamorig_%sLeg" % side), Vector3.RIGHT * KNEE * push)  # the shin back
			_kick(_sk.find_bone("mixamorig_%sUpLeg" % side), Vector3.LEFT * KNEE * 0.5 * push)  # the thigh up
			_dip_v += DIP * push
	return StringName(name)


## Turns bone `b` about its joint so the spot hit (`p`, skeleton space) goes along the round `d`;
## a round straight down the bone has no lever: it tips it across the round's line instead.
func _axis(b: int, p: Vector3, d: Vector3) -> Vector3:
	var arm := p - _sk.get_bone_global_pose(b).origin
	var axis := arm.cross(d)
	if axis.length() < 0.02 * arm.length() + 0.001:
		axis = Vector3.UP.cross(d)
	return axis.normalized()


func _kick(b: int, v: Vector3) -> void:
	if b < 0:
		return
	var s: Array = _turn.get_or_add(b, [Vector3.ZERO, Vector3.ZERO])
	s[1] += v


## The candidate bone whose stretch to its child passes nearest `at`.
func _bone_at(at: Vector3) -> int:
	var p := _sk.global_transform.affine_inverse() * at
	var best := -1
	var near := INF
	for b in _ids:
		var a := _sk.get_bone_global_pose(b).origin
		var kids := _sk.get_bone_children(b)
		var e := _sk.get_bone_global_pose(kids[0]).origin if kids.size() > 0 else a
		var q := Geometry3D.get_closest_point_to_segment(p, a, e)
		var dd := q.distance_squared_to(p)
		if dd < near:
			near = dd
			best = b
	return best


func _process(delta: float) -> void:
	for b: int in _turn.keys():
		var s: Array = _turn[b]
		s[1] += (-STIFF * s[0] - DAMP * s[1]) * delta
		s[0] = (s[0] + s[1] * delta).limit_length(MAX)
		if s[0].length() < 0.0005 and s[1].length() < 0.01:
			_turn.erase(b)
	_dip_v += (-STIFF * _dip - DAMP * _dip_v) * delta
	_dip = clampf(_dip + _dip_v * delta, -DIP_MAX, DIP_MAX)


func _process_modification() -> void:
	if not _sk:
		return
	var bones: Array = _turn.keys()
	bones.sort()  # parents first (Mixamo's order): each turns on what its parent did
	for b: int in bones:
		var v: Vector3 = _turn[b][0]
		if v.length() < 0.0001:
			continue
		var parent := _sk.get_bone_parent(b)
		var up := _sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var turn := up.inverse() * Basis(v.normalized(), v.length()) * up
		_sk.set_bone_pose_rotation(b, turn.get_rotation_quaternion() * _sk.get_bone_pose_rotation(b))
	if _hips >= 0 and absf(_dip) > 0.0005:
		_sk.set_bone_pose_position(_hips, _sk.get_bone_pose_position(_hips) + Vector3.DOWN * _dip)
