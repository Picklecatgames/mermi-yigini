extends Node3D
## One zombie's look and animation: a Mixamo model and clips from the shared library
## (assets/characters/zombies/zombie_anims.res, built by tools/build_zombies.gd), or a creature off
## another rig (CREATURES) with clips of its own. Visual only: the
## wave code moves this node and calls idle / move / attack / hit / die / scream. Faces -Z.
##
## Everything is picked from `seed`, which the host hands out with the zombie, so every peer dresses
## and animates it the same way. Clips are in place; move() matches the stride to the speed.
##   var body := ZOMBIE_BODY.new()
##   body.setup(&"walker", seed)
##   add_child(body)
## Sounds come from a zombie_voice.gd child on the head bone; die(&"head") / die(&"body") tears it
## apart (zombie_gibs.gd) instead of letting it fall whole. The blood is blood_fx.gd's, and every
## splash of it is rolled from `seed` and the count of hits, so it lands the same on every peer.

const VOICE := preload("res://scripts/zombie_voice.gd")
const GIBS := preload("res://scripts/zombie_gibs.gd")
const BLOOD := preload("res://scripts/blood_fx.gd")
const FLESH := preload("res://materials/env/gore/flesh.tres")
const STUMP := preload("res://materials/env/gore/meat_1.res")
const LIB := preload("res://assets/characters/zombies/zombie_anims.res")
const MODELS := {
	&"prisoner": preload("res://assets/characters/zombies/prisoner/prisoner.scn"),
	&"copzombie": preload("res://assets/characters/zombies/copzombie/copzombie.scn"),
	&"parasite": preload("res://assets/characters/zombies/parasite/parasite.scn"),
	&"warzombie": preload("res://assets/characters/zombies/warzombie/warzombie.scn"),
	&"zombiegirl": preload("res://assets/characters/zombies/zombiegirl/zombiegirl.scn"),
	&"yaku": preload("res://assets/characters/zombies/yaku/yaku.scn"),
	&"romero": preload("res://assets/characters/zombies/romero/romero.scn"),
	&"skeletonzombie": preload("res://assets/characters/zombies/skeletonzombie/skeletonzombie.scn"),
	&"whiteclown": preload("res://assets/characters/zombies/whiteclown/whiteclown.scn"),
	&"warrok": preload("res://assets/characters/zombies/warrok/warrok.scn"),
	&"maw": preload("res://assets/characters/zombies/maw/maw.scn"),
	&"demon": preload("res://assets/characters/zombies/demon/demon.scn"),
	&"fleshzombie": preload("res://assets/characters/zombies/fleshzombie/fleshzombie.scn"),
	&"hazmat": preload("res://assets/characters/zombies/hazmat/hazmat.scn"),
	&"bloater": preload("res://assets/characters/zombies/bloater/bloater.scn"),
}
## Not Mixamo: its scene, the skeleton and the node the squash moves (paths in the scene), which bone
## stands in for "Head" / "Hips" in attach(), its height in m at size 1 (0: as modelled), whether it
## faces +Z as modelled (turned like the Mixamo ones), and its own clips (_creature_library).
const CREATURES := {
	&"blob": {"scene": preload("res://assets/characters/zombies/blob/blob.glb"),
			"skeleton": "Armature/Skeleton3D", "squash": "Armature", "height": 0.0, "turn": false,
			"bones": {"Head": "Bone.003", "Hips": "Bone.001"}},
	&"melty": {"scene": preload("res://assets/characters/zombies/melty/melty.glb"),
			"skeleton": "Sketchfab_model/melty zombie_fbx/Object_2/RootNode/Object_4/Skeleton3D",
			"squash": "Sketchfab_model", "height": 1.8, "turn": true,
			"bones": {"Head": "head_014", "Hips": "hip_016"}},
	&"dog": {"scene": preload("res://assets/characters/zombies/dog/dog.glb"),
			"skeleton": "Armature/Skeleton3D", "squash": "Armature", "height": 0.85, "turn": true,
			"bones": {"Head": "Bone_WH_Head", "Hips": "Bone_WH_Pelvis"}},
}
## kind -> models it wears, clip family ("" zombie, "mutant_" the creature set), its move loop,
## and its size range.
const KINDS := {
	&"walker": {"models": [&"prisoner", &"copzombie", &"warzombie", &"zombiegirl", &"parasite",
			&"yaku", &"romero", &"skeletonzombie", &"whiteclown", &"fleshzombie", &"hazmat", &"bloater",
			&"melty"],
			"set": "", "move": "walk", "size": [0.95, 1.06]},
	&"runner": {"models": [&"prisoner", &"copzombie", &"zombiegirl", &"parasite", &"yaku",
			&"skeletonzombie", &"whiteclown", &"fleshzombie", &"hazmat", &"melty"],
			"set": "", "move": "run", "size": [0.95, 1.04]},
	&"crawler": {"models": [&"prisoner", &"warzombie", &"zombiegirl", &"romero", &"skeletonzombie",
			&"fleshzombie", &"hazmat"],
			"set": "", "move": "crawl", "size": [0.95, 1.05]},
	&"brute": {"models": [&"warrok", &"maw", &"demon"],  # already ~2.4 m
			"set": "mutant_", "move": "walk", "size": [1.0, 1.12]},
	&"blob": {"models": [&"blob"],  # 0.79 m as modelled
			"set": "", "move": "crawl", "size": [1.3, 1.6]},
	&"dog": {"models": [&"dog"], "set": "", "move": "run", "size": [0.9, 1.1]},
}
const BLEND := 0.25  # s of crossfade between clips
## Every shot bends the upper body away from it at once, whatever clip is playing: a spring on the
## spine (and the head, harder, for head shots) laid over the animation.
const KICK := 2.4  # rad/s per shot
const KICK_HEAD := 2.5  # times that on the head
const KICK_STIFF := 160.0  # 1/s², ~2 Hz
const KICK_DAMP := 15.0  # 1/s: one swing back and it has settled
const KICK_MAX := 0.6  # rad, so a burst can't fold it in two
const KICK_ARM := 3.0  # times KICK on the arm a round hit
## Limbs that come off (Mixamo rigs only): part -> the bone it comes off at and the one at its far
## end. A round is put on the first limb along its line (limb_at); the host counts the hits and
## sends the cut (waves.gd), so the same part goes on every peer. An arm can lose its forearm first
## and the rest after; a leg likewise from the knee.
const LIMBS := {
	&"arm_l": ["LeftArm", "LeftForeArm"], &"forearm_l": ["LeftForeArm", "LeftHand"],
	&"arm_r": ["RightArm", "RightForeArm"], &"forearm_r": ["RightForeArm", "RightHand"],
	&"leg_l": ["LeftUpLeg", "LeftLeg"], &"shin_l": ["LeftLeg", "LeftFoot"],
	&"leg_r": ["RightUpLeg", "RightLeg"], &"shin_r": ["RightLeg", "RightFoot"],
}
const LOWER := {&"forearm_l": &"arm_l", &"forearm_r": &"arm_r", &"shin_l": &"leg_l", &"shin_r": &"leg_r"}
## Far from the camera the clips are stepped every LOD_STEP frames (each zombie on its own beat), not
## every frame: a crowd at the gates costs a third.
const LOD_FAR := 22.0  # m
const LOD_STEP := 3
const FALL_SPEED := 1.5  # the stumble-and-fall clip is slow for a leg torn off
const LIMB_REACH := 0.1  # m at size 1: how far off a limb's bone a round's line may pass and hit it
const TORSO_REACH := 0.15  # the same for the spine, which takes the round if it is first in line

var kind := &"walker"
var model := &""
var size := 1.0
var height := 1.8  # m, top of the head at this size (for hit shapes)

var _seed := 0
var _set := ""
var _lib: AnimationLibrary  # this model's clips
var _move := "walk"
var _ap: AnimationPlayer
var _skel: Skeleton3D
var _hip := 1.0  # m, the model's hip height at this size
var _loop := ""  # the loop to come back to after a one-shot
var _loop_speed := 1.0
var _busy := false  # in an attack, hit or scream
var _dead := false
var _count := {}  # action -> how many times it has played, so each pick differs but agrees on peers
var _flinch := Flinch.new()
var _bend := Vector3.ZERO  # skeleton-space rotation vectors and their speeds
var _bend_v := Vector3.ZERO
var _nod := Vector3.ZERO
var _nod_v := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _wounds := 0  # hits taken: with `_seed` it seeds each hit's blood
var _voice: Node3D
var _chest := -1  # the bone a body burst comes out of
var _last_dir := Vector3.FORWARD  # the way the last round went, for where the pieces fly
var cuts: Array[StringName] = []  # LIMBS parts gone
var crawling := false  # on its belly: a crawler, or one that lost a leg
var _lod_wait := 0.0  # s of animation held back while far
var _lod_beat := 0
var fall_speed := 0.0  # m/s it stumbles on while going down (the clip is in place)
var _arm_kick := [Vector3.ZERO, Vector3.ZERO]  # left, right: the springs on the upper arms
var _arm_kick_v := [Vector3.ZERO, Vector3.ZERO]


## Lays the spring's bend over whatever the animation posed.
class Flinch extends SkeletonModifier3D:
	var bend := Vector3.ZERO
	var nod := Vector3.ZERO
	var spine: Array[int] = []
	var head := -1
	var head_gone := false
	var arms: Array[int] = []  # the upper arms' bones, and their kicks
	var arm_kick: Array = []
	var cut: Array[int] = []  # bones folded to nothing: the limb hanging off them is gone

	func _process_modification() -> void:
		var sk := get_skeleton()
		for b in spine:
			_turn(sk, b, bend / spine.size())
		_turn(sk, head, nod)
		for i in arms.size():
			_turn(sk, arms[i], arm_kick[i])
		if head_gone and head >= 0:  # blown off: folded to nothing at the neck
			sk.set_bone_pose_scale(head, Vector3.ONE * 0.001)
		for b in cut:
			sk.set_bone_pose_scale(b, Vector3.ONE * 0.001)

	func _turn(sk: Skeleton3D, b: int, v: Vector3) -> void:
		if b < 0 or v.length() < 0.0001:
			return
		var up := sk.get_bone_global_pose(sk.get_bone_parent(b)).basis.orthonormalized()
		var turn := up.inverse() * Basis(v.normalized(), v.length()) * up
		sk.set_bone_pose_rotation(b, turn.get_rotation_quaternion() * sk.get_bone_pose_rotation(b))


## Picks the model, size and clip family. Call before adding to the tree.
func setup(p_kind: StringName, p_seed: int) -> void:
	kind = p_kind
	_seed = p_seed
	var k: Dictionary = KINDS[kind]
	_set = k.set
	_move = k.move
	var models: Array = k.models
	model = models[_roll("model") % models.size()]
	size = lerpf(k.size[0], k.size[1], float(_roll("size") % 1000) / 999.0)


func _ready() -> void:
	if model == &"":
		setup(kind, _seed)
	if CREATURES.has(model):
		_ready_creature()
		return
	var body: Node3D = MODELS[model].instantiate()
	body.rotation.y = PI  # Mixamo faces +Z
	body.scale = Vector3.ONE * size
	add_child(body)
	_skel = body.get_node("Skeleton3D")
	var hips := _skel.find_bone("mixamorig_Hips")
	_skel.motion_scale = _skel.get_bone_global_rest(hips).origin.y
	_hip = _skel.motion_scale * size
	height = (_skel.get_bone_global_rest(_skel.find_bone("mixamorig_HeadTop_End")).origin.y) * size
	_ap = AnimationPlayer.new()
	body.add_child(_ap)
	_ap.root_node = ^".."
	_lib = _library(model, _skel)
	_ap.add_animation_library("", _lib)
	_ap.animation_finished.connect(_on_finished)
	for b in ["Spine", "Spine1", "Spine2", "Neck"]:
		_flinch.spine.append(_skel.find_bone("mixamorig_" + b))
	_flinch.head = _skel.find_bone("mixamorig_Head")
	_flinch.arms = [_skel.find_bone("mixamorig_LeftArm"), _skel.find_bone("mixamorig_RightArm")]
	_flinch.arm_kick = _arm_kick
	_chest = _flinch.spine[1]
	_skel.add_child(_flinch)
	crawling = _move == "crawl"  # (a creature never: it has no belly clips)
	_add_voice()
	idle()


func _add_voice() -> void:
	_voice = VOICE.new()
	_voice.setup(kind, _seed)
	attach("Head").add_child(_voice)


## A creature has no spine to bend; a shot squashes it instead (hit()).
func _ready_creature() -> void:
	var c: Dictionary = CREATURES[model]
	var body: Node3D = c.scene.instantiate()
	add_child(body)
	for old in body.find_children("*", "AnimationPlayer", true, false):
		old.free()
	_skel = body.get_node(c.skeleton)
	var top := rest_box(body).end.y
	var fit: float = c.height / top if c.height > 0.0 else 1.0
	body.scale = Vector3.ONE * size * fit
	if c.turn:
		body.rotation.y = PI
	height = top * fit * size
	_hip = size  # creature clips keep their speed in m/s at size 1
	_ap = AnimationPlayer.new()
	body.add_child(_ap)
	_ap.root_node = ^".."
	_lib = _creature_library(model)
	_ap.add_animation_library("", _lib)
	_ap.animation_finished.connect(_on_finished)
	_flinch.head = _skel.find_bone(c.bones.Head)
	_chest = _skel.find_bone(c.bones.Hips)
	_skel.add_child(_flinch)
	_add_voice()
	idle()


func _process(delta: float) -> void:
	_step_clips(delta)
	_bend_v += (-KICK_STIFF * _bend - KICK_DAMP * _bend_v) * delta
	_bend = (_bend + _bend_v * delta).limit_length(KICK_MAX)
	_nod_v += (-KICK_STIFF * _nod - KICK_DAMP * _nod_v) * delta
	_nod = (_nod + _nod_v * delta).limit_length(KICK_MAX)
	_flinch.bend = _bend
	_flinch.nod = _nod
	for i in 2:
		_arm_kick_v[i] += (-KICK_STIFF * _arm_kick[i] - KICK_DAMP * _arm_kick_v[i]) * delta
		_arm_kick[i] = (_arm_kick[i] + _arm_kick_v[i] * delta).limit_length(KICK_MAX * 1.5)


func _step_clips(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var far := cam != null and not _dead and cam.global_position.distance_squared_to(global_position) > LOD_FAR * LOD_FAR
	if not far:
		if _ap.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
			_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
			_ap.advance(_lod_wait)
			_lod_wait = 0.0
		return
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_lod_wait += delta
	_lod_beat += 1
	if (_lod_beat + _seed) % LOD_STEP == 0:
		_ap.advance(_lod_wait)
		_lod_wait = 0.0


## A round went in at `at` travelling along `dir`: the body jerks away from it, blood sprays out
## the back and a little back toward the shooter, and drops land on the floor behind. Returns the
## limb it went into (limb_at), &"" for the head or the trunk; an arm swings back with the hit.
func wound(at: Vector3, dir: Vector3, head: bool) -> StringName:
	dir = dir.normalized()
	_last_dir = dir
	var part := &"" if head else limb_at(at, dir)
	_reseed("wound%d" % _wounds)
	_wounds += 1
	_voice.shot(at, head)
	if not _dead:
		var axis := Vector3.UP.cross(dir)
		if axis.length() > 0.01:
			axis = _skel.global_basis.orthonormalized().inverse() * axis.normalized()
			if head:
				_nod_v += axis * KICK * KICK_HEAD
			elif String(part).contains("arm"):
				var i := 0 if part.ends_with("_l") else 1
				_arm_kick_v[i] += axis * KICK * KICK_ARM
				_bend_v += axis * KICK * 0.4
			else:
				_bend_v += axis * KICK * (0.5 if part != &"" else 1.0)  # a leg: it stumbles instead
	_spray(at, dir, 12 if head else 7, 1.0)
	_spray(at, -dir, 4, 0.5)
	var world := _world()
	# The puff the shooter sees comes back out of the entry and off to the side; blown on along the
	# round it would point straight away from the camera and read as a smudge. A step toward the
	# shooter, so the body it came out of doesn't swallow it.
	BLOOD.mist(world, at - dir * 0.1, _aside(dir, 0.5), _rng, (0.9 if head else 0.7) * size, 0.5)
	BLOOD.mist(world, at + dir * 0.15, dir, _rng, (0.6 if head else 0.45) * size, 0.35)  # the exit
	BLOOD.wall(world, at, dir, _rng, 2.5 if head else 1.6, (0.9 if head else 0.55) * size)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	BLOOD.ground(world, at + flat * _rng.randf_range(0.4, 1.6), global_position.y, [&"drop", &"spray"], _rng,
			_rng.randf_range(0.35, 0.7) * (1.4 if head else 1.0), flat)
	return part


## The limb a round at `at` going along `dir` went into: the first bone along its line that it
## passes within reach of, or &"" if the trunk is first (or it has no limbs to lose: creatures).
## Each peer asks its own copy; only the host's answer counts toward a cut.
func limb_at(at: Vector3, dir: Vector3) -> StringName:
	if CREATURES.has(model) or _dead:
		return &""
	var from := at - dir * 0.4  # the shapes are rough: from a little before where it touched them
	var to := at + dir * 0.8
	var best := &""
	var first := INF
	var hips := _bone_at("Hips")
	var pts := Geometry3D.get_closest_points_between_segments(from, to, hips, _bone_at("Neck"))
	if pts[0].distance_to(pts[1]) < TORSO_REACH * size:
		first = from.distance_to(pts[0])
	for part: StringName in LIMBS:
		if not can_lose(part):
			continue
		pts = Geometry3D.get_closest_points_between_segments(from, to, _bone_at(LIMBS[part][0]), _bone_at(LIMBS[part][1]))
		if pts[0].distance_to(pts[1]) < LIMB_REACH * size and from.distance_to(pts[0]) < first:
			first = from.distance_to(pts[0])
			best = part
	return best


## Whether `part` is still there to come off: a Mixamo rig (not a brute's legs, it has no crawl),
## and neither it nor the limb it hangs from gone.
func can_lose(part: StringName) -> bool:
	if CREATURES.has(model) or part in cuts or LOWER.get(part, &"") in cuts:
		return false
	return kind != &"brute" or not is_leg(part)


static func is_leg(part: StringName) -> bool:
	return part.begins_with("leg") or part.begins_with("shin")


## Arms that lost something: each one makes its swings slower (waves.gd).
func arms_hurt() -> int:
	var n := 0
	for side in ["_l", "_r"]:
		if (&"arm" + side) in cuts or (&"forearm" + side) in cuts:
			n += 1
	return n


## Takes `part` off. `fly`: it tears off now, thrown along the last round with a spurt of blood
## (zombie_gibs.gd limb()); without, it is simply gone (a joiner seeing it already off). A leg drops
## it to its belly: returns how long the fall takes (s, 0 if it was down already), after which it
## crawls (move()).
func cut(part: StringName, fly := true) -> float:
	if not can_lose(part):
		return 0.0
	var b := _skel.find_bone("mixamorig_" + LIMBS[part][0])
	var joint := _skel.to_global(_skel.get_bone_global_pose(b).origin)
	if fly:
		var tip := _skel.to_global(_skel.get_bone_global_pose(_skel.find_bone("mixamorig_" + LIMBS[part][1])).origin)
		if part.begins_with("forearm") or part.begins_with("shin"):  # the hand and the foot go with it
			var end := _skel.find_bone("mixamorig_" + ("LeftHand" if part == &"forearm_l" else "RightHand" if part == &"forearm_r" else
					"LeftToeBase" if part == &"shin_l" else "RightToeBase"))
			tip = _skel.to_global(_skel.get_bone_global_pose(end).origin)
		_reseed("cut" + part)
		GIBS.limb(_world(), _piece(b), joint, tip, _last_dir, global_position.y, size, _rng.randi())
	cuts.append(part)
	_flinch.cut.append(b)
	if LOWER.has(part):
		_stump_on(_skel.get_bone_parent(b), _skel.get_bone_rest(b).origin, 0.13 if is_leg(part) else 0.1)
	else:
		_stump_on(_skel.get_bone_parent(b), _skel.get_bone_rest(b).origin, 0.17 if is_leg(part) else 0.13)
	if fly:
		var out := (joint - _skel.to_global(_skel.get_bone_global_pose(_skel.get_bone_parent(b)).origin)).normalized()
		_spray(joint, out, 18, 1.2)
		_spray(joint, Vector3.UP, 10, 0.9)
		var world := _world()
		BLOOD.mist(world, joint, _aside(_last_dir, 0.4), _rng, 0.8 * size, 0.5)
		BLOOD.ground(world, joint, global_position.y, [&"spray", &"drop"], _rng, 0.9 * size, Vector3(out.x, 0, out.z).normalized())
		VOICE.gore(&"burst", joint, -2.0, 1.2 if is_leg(part) else 1.35)
		_voice.pain()
		_pump(b)
	if is_leg(part) and not crawling:
		return _go_down(fly)
	return 0.0

## Loops one of the kind's idles (in the pen, at the gate). One on its belly creeps on the spot.
func idle() -> void:
	_voice.wake()
	if crawling:
		_play_loop(_pick(_move), 0.35)
		return
	_play_loop(_pick("idle"), 1.0)


## Loops the kind's walk / run / crawl, its stride stretched to `speed` m/s.
func move(speed: float) -> void:
	_voice.wake()
	var clip := _pick(_move)
	var natural: float = _lib.get_animation(clip).get_meta("speed", 0.0) * _hip
	_play_loop(clip, clampf(speed / natural, 0.6, 1.8) if natural > 0.05 else 1.0)


## Swing at the fence or a player. Returns the clip's length (s).
func attack() -> float:
	_voice.attack()
	if crawling:  # bites from the floor
		return _one_shot("floor_bite")
	return _one_shot("attack")


## Flinch from a shot; back to the loop after. Ignored mid-attack, and on its belly (the hit clips
## stand it up): there the spring alone (wound()) jerks it.
func hit() -> void:
	if not _busy and not crawling:
		_one_shot("hit")


## Roar (mutants) or scream (zombies). Returns the clip's length (s).
func scream() -> float:
	_voice.scream()
	return _one_shot("scream" if _set == "" else "roar")


## Falls and stays down. Returns the clip's length (s). `gib`: &"head" blows the head off in a
## spray of meat (no death rattle, the mouth is gone), &"body" bursts the chest; the wave code
## decides when (a head shot kill, a burst of rounds, a brute going down).
func die(gib := &"") -> float:
	if _dead:
		return 0.0
	var clip := _pick("death")
	_dead = true
	var head := _skel.to_global(_skel.get_bone_global_pose(_flinch.head).origin)
	var chest := _skel.to_global(_skel.get_bone_global_pose(_chest).origin)
	_voice.die(head if gib == &"head" else chest, gib != &"", gib == &"head")
	_reseed("die")
	if gib != &"":
		var from := head if gib == &"head" else chest
		var world := _world()
		GIBS.burst(world, from, _last_dir, global_position.y,
				(9 if gib == &"head" else 14) + (8 if kind == &"brute" else 0), size, _rng.randi())
		_spray(from, Vector3.UP, 22, 1.3)
		_spray(from, _last_dir, 16, 1.2)
		BLOOD.mist(world, from - _last_dir * 0.1, _aside(_last_dir, 0.3), _rng, 1.2 * size, 0.7)
		BLOOD.mist(world, from - _last_dir * 0.1, _aside(_last_dir, 0.3), _rng, 1.0 * size, 0.6)
		BLOOD.mist(world, from, (Vector3.UP + _last_dir).normalized(), _rng, 0.9 * size, 0.6)
		BLOOD.wall(world, from, _last_dir, _rng, 3.5, 1.4 * size)
		var flat := Vector3(_last_dir.x, 0.0, _last_dir.z).normalized()
		BLOOD.ground(world, from + flat * _rng.randf_range(0.6, 1.4), global_position.y, [&"spray", &"mist"], _rng,
				1.6 * size, flat)
		if gib == &"head":
			_flinch.head_gone = true
			_stump(&"Neck", 0.16)
		else:
			_stump(&"Spine1", 0.3)
	_ap.speed_scale = 1.0
	var length := _lib.get_animation(clip).length
	if crawling:
		# The deaths start standing: from the belly it only slumps into the last of one.
		_ap.play(clip, 0.6)
		_ap.seek(length * 0.8, true)
		length *= 0.2
	else:
		_ap.play(clip, BLEND)
	_bleed_out(length * 0.7)
	return length


## Once it is down, a pool spreads under the body.
func _bleed_out(after: float) -> void:
	await get_tree().create_timer(after).timeout
	if not is_inside_tree():
		return
	var hips := _skel.to_global(_skel.get_bone_global_pose(0).origin)
	_reseed("pool")
	BLOOD.ground(_world(), hips, global_position.y, [&"pool"], _rng, 1.4 * size, Vector3.ZERO, 5.0)
	_voice.ooze(hips)


## Raw meat where a part tore off: a lump of flesh on the bone, `width` m across at this size.
func _stump(bone: StringName, width: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = STUMP
	m.material_override = FLESH
	var s := width * size
	m.scale = Vector3(s, s * 0.7, s)
	attach(bone).add_child(m)


## The same at `offset` (the bone's own space, at size 1: the body's scale carries it) on bone `b`,
## where the limb hanging off it was.
func _stump_on(b: int, offset: Vector3, width: float) -> void:
	var a := BoneAttachment3D.new()
	a.bone_name = _skel.get_bone_name(b)
	_skel.add_child(a)
	var m := MeshInstance3D.new()
	m.mesh = STUMP
	m.material_override = FLESH
	m.position = offset
	m.scale = Vector3(width, width * 0.8, width)
	a.add_child(m)


## Where bone "mixamorig_<name>" is now, in the world.
func _bone_at(name: String) -> Vector3:
	return _skel.to_global(_skel.get_bone_global_pose(_skel.find_bone("mixamorig_" + name)).origin)


## A torn limb's stump spurts a few more times as the heart beats on, out of bone `b`'s joint.
func _pump(b: int) -> void:
	for i in 3:
		await get_tree().create_timer(0.35 + 0.1 * i).timeout
		if not is_inside_tree():
			return
		var joint := _skel.to_global(_skel.get_bone_global_pose(b).origin)
		var out := joint - _skel.to_global(_skel.get_bone_global_pose(_skel.get_bone_parent(b)).origin)
		_spray(joint, (out.normalized() + Vector3.UP * 0.3).normalized(), 9 - 2 * i, 0.8 - 0.15 * i)


## The limb hanging off bone `b`, as it is posed now, for the throw: a second copy of the model
## with every other bone folded to nothing at the joint (so their skin hides inside the torn end).
## Each bone's pose is set from where it must be in the skeleton, so the folding doesn't add up
## down the chain.
func _piece(b: int) -> Node3D:
	var copy: Node3D = MODELS[model].instantiate()
	var sk: Skeleton3D = copy.get_node("Skeleton3D")
	var keep := {}
	var todo: Array[int] = [b]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		keep[i] = true
		todo.append_array(_skel.get_bone_children(i))
	var hide := Transform3D(Basis.from_scale(Vector3.ONE * 0.001), _skel.get_bone_global_pose(b).origin)
	var global := {}
	todo.assign(sk.get_parentless_bones())
	while not todo.is_empty():
		var i: int = todo.pop_back()
		var g: Transform3D = _skel.get_bone_global_pose(i) if keep.has(i) else hide
		var p := sk.get_bone_parent(i)
		sk.set_bone_pose(i, global[p].affine_inverse() * g if p >= 0 else g)
		global[i] = g
		todo.append_array(sk.get_bone_children(i))
	copy.transform = (_skel.get_parent() as Node3D).global_transform * _skel.transform
	return copy


## Drops to its belly (a leg is gone) and crawls from here on: the fall, unless `fall` is off,
## then the crawl as its loop (a runner's quick one). Returns the fall's length.
func _go_down(fall: bool) -> float:
	crawling = true
	_move = "crawl_run" if _move == "run" else "crawl"
	_loop = _pick(_move)
	_loop_speed = 1.0
	if not fall or _dead:
		_busy = false
		_ap.play(_loop, BLEND)
		return 0.0
	var length := _one_shot("fall") / FALL_SPEED
	_ap.speed_scale = FALL_SPEED
	fall_speed = _lib.get_animation(_ap.current_animation).get_meta("speed", 0.0) * _hip * FALL_SPEED
	return length


## A way out of a hit going along `dir`: back toward the shooter by `back`, mostly to one side, a little up.
func _aside(dir: Vector3, back: float) -> Vector3:
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.05 else Vector3.RIGHT
	return (-dir * back + side * (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(0.6, 1.0)
			+ Vector3.UP * _rng.randf_range(0.1, 0.5)).normalized()


## Blood and pieces are decals and nodes in the wave's world, so they stay put while the body moves.
func _world() -> Node:
	return get_parent().get_parent()


func _reseed(salt: String) -> void:
	_rng.seed = hash("%d:blood:%s" % [_seed, salt])
	_rng.state = 0


static var _drop_mesh: QuadMesh
static var _drop_mat: ParticleProcessMaterial


func _spray(at: Vector3, dir: Vector3, amount: int, force: float) -> void:
	if _drop_mesh == null:
		var m := StandardMaterial3D.new()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		# A round drop, red through: the old splat texture times dark red came out as black ink.
		var dot := GradientTexture2D.new()
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5, 0.5)
		dot.fill_to = Vector2(0.5, 0.0)
		dot.width = 32
		dot.height = 32
		dot.gradient = Gradient.new()
		dot.gradient.set_color(0, Color(1, 1, 1, 1))
		dot.gradient.set_color(1, Color(1, 1, 1, 0))
		m.albedo_texture = dot
		m.albedo_color = Color(0.55, 0.035, 0.03)
		m.emission_enabled = true  # still red in the dark between lamps
		m.emission = Color(0.55, 0.035, 0.03)
		m.emission_energy_multiplier = 0.25
		m.metallic_specular = 0.6
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.roughness = 0.15
		_drop_mesh = QuadMesh.new()
		_drop_mesh.size = Vector2(0.035, 0.035)  # billboarded particles drew at the quad's size, scale or not
		_drop_mesh.material = m
		_drop_mat = ParticleProcessMaterial.new()
		_drop_mat.direction = Vector3(0, 0, -1)
		_drop_mat.spread = 28.0
		_drop_mat.initial_velocity_min = 1.5
		_drop_mat.initial_velocity_max = 4.5
		_drop_mat.gravity = Vector3(0, -9.8, 0)
		_drop_mat.scale_min = 0.33
		_drop_mat.scale_max = 1.0
		_drop_mat.damping_min = 1.0
		_drop_mat.damping_max = 2.0
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.speed_scale = force
	p.process_material = _drop_mat
	p.use_fixed_seed = true  # the same drops on every peer
	p.seed = _rng.randi()
	p.draw_pass_1 = _drop_mesh
	get_parent().get_parent().add_child(p)
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	p.global_transform = Transform3D(Basis.looking_at(dir, up), at)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Node that follows a bone, for hit shapes (the head's weak spot) or effects.
func attach(bone: String) -> BoneAttachment3D:
	var a := BoneAttachment3D.new()
	a.bone_name = CREATURES[model].bones.get(bone, bone) if CREATURES.has(model) else "mixamorig_" + bone
	_skel.add_child(a)
	return a


func _play_loop(clip: String, speed: float) -> void:
	if _dead:
		return
	_loop = clip
	_loop_speed = speed
	if not _busy:
		if _ap.current_animation != clip:
			_ap.play(clip, BLEND)
		_ap.speed_scale = speed


func _one_shot(action: String) -> float:
	if _dead:
		return 0.0
	var clip := _pick(action)
	_busy = true
	_ap.speed_scale = 1.0
	_ap.play(clip, BLEND)
	return _lib.get_animation(clip).length


func _on_finished(_clip: StringName) -> void:
	if _dead or not _busy:
		return
	_busy = false
	_ap.play(_loop, BLEND)
	_ap.speed_scale = _loop_speed


## The family's clips named <set><action>_*, one picked per play. Zombie actions with no mutant
## clip fall back to the zombie set and the other way round.
func _pick(action: String) -> String:
	var clips := _clips(_lib, _set + action)
	if clips.is_empty():
		clips = _clips(_lib, ("" if _set != "" else "mutant_") + action)
	var n: int = _count.get(action, 0)
	_count[action] = n + 1
	return clips[_roll("%s%d" % [action, n]) % clips.size()]


static var _by_prefix := {}


static func _clips(lib: AnimationLibrary, prefix: String) -> Array:
	var key := "%d:%s" % [lib.get_instance_id(), prefix]
	if not _by_prefix.has(key):
		var out := []
		for a in lib.get_animation_list():
			if a.begins_with(prefix + "_") and a.trim_prefix(prefix + "_").length() == 1:
				out.append(String(a))
		_by_prefix[key] = out
	return _by_prefix[key]


static var _roll_rng := RandomNumberGenerator.new()


## The string hash alone leaves gaps modulo some sizes (with 11 models four were never picked), so
## it seeds a PCG draw instead. Same on every peer.
func _roll(salt: String) -> int:
	_roll_rng.seed = hash("%d:%s" % [_seed, salt])
	return _roll_rng.randi() & 0x7fffffff


static var _libs := {}


## The shared library without tracks for bones this model lacks (eyes, mostly), so the player
## never warns about them. Built once per model.
static func _library(name: StringName, skel: Skeleton3D) -> AnimationLibrary:
	if _libs.has(name):
		return _libs[name]
	var lib := AnimationLibrary.new()
	for a in LIB.get_animation_list():
		var anim: Animation = LIB.get_animation(a)
		var missing := []
		for t in anim.get_track_count():
			if skel.find_bone(String(anim.track_get_path(t).get_subname(0))) < 0:
				missing.append(t)
		if not missing.is_empty():
			anim = anim.duplicate()
			missing.reverse()
			for t in missing:
				anim.remove_track(t)
		lib.add_animation(a, anim)
	_libs[name] = lib
	return lib


## The meshes' box in `body`'s space as they stand at rest. A skinned mesh is drawn through its binds,
## which may scale it (the melty zombie's do, 2.6 times), so its own box is no guide.
static func rest_box(body: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var to_body := body.global_transform.affine_inverse()
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		var xf := mi.global_transform
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if mi.skin and sk and mi.skin.get_bind_count() > 0:
			var bone := mi.skin.get_bind_bone(0)
			if mi.skin.get_bind_name(0) != &"":
				bone = sk.find_bone(mi.skin.get_bind_name(0))
			xf = sk.global_transform * sk.get_bone_global_rest(bone) * mi.skin.get_bind_pose(0)
		var b := to_body * xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## A creature's clips, built once: the blob's from its pulse, the melty zombie's renamed from its own,
## the dog's made on its bones around its howl.
static func _creature_library(name: StringName) -> AnimationLibrary:
	if _libs.has(name):
		return _libs[name]
	var c: Dictionary = CREATURES[name]
	var src: Node3D = c.scene.instantiate()
	var src_ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var lib: AnimationLibrary
	match name:
		&"blob":
			lib = _blob_library(src_ap.get_animation(&"pulse"), c.squash)
		&"melty":
			lib = AnimationLibrary.new()
			for clip: String in MELTY_CLIPS:
				var anim: Animation = src_ap.get_animation(MELTY_CLIPS[clip][0]).duplicate()
				var kind := clip.get_slice("_", 0)
				anim.loop_mode = Animation.LOOP_LINEAR if kind in ["idle", "walk", "run"] else Animation.LOOP_NONE
				if MELTY_CLIPS[clip][1] > 0.0:
					anim.set_meta("speed", MELTY_CLIPS[clip][1])
				# Its hips are keyed under a root turned a quarter about Z, a turn the glb lost.
				var root := anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(root, "%s:root_061" % c.skeleton)
				anim.rotation_track_insert_key(root, 0.0, Quaternion(Vector3.BACK, PI / 2.0))
				lib.add_animation(clip, anim)
		&"dog":
			lib = _dog_library(src, src_ap.get_animation(&"howl"), c)
	src.free()
	_libs[name] = lib
	return lib


## The melty zombie's clips: library name -> its own clip and its natural speed (m/s at 1.8 m; its
## clips are in place). It has no crawl, so it never crawls. It dies with "down", the fall ("death" is
## it twitching once down); "caution", a crouched snarl, is its scream.
const MELTY_CLIPS := {
	"idle_a": ["idle01", 0.0], "idle_b": ["idle02", 0.0],
	"walk_a": ["walk01", 0.55], "walk_b": ["walk02", 0.4], "run_a": ["run", 3.2],
	"attack_a": ["attack01", 0.0], "attack_b": ["attack02", 0.0], "hit_a": ["damage", 0.0],
	"death_a": ["down", 0.0], "scream_a": ["caution", 0.0],
}


## The blob comes with one clip, a 3 s pulse. Its moves are that pulse, sped up or slowed, under a
## squash and stretch of the whole body (the "squash" node): crawl_a heaves forward in place,
## attack_a rears back and lunges, hit_a flattens, scream_a swells and shakes, death_a bursts up then
## slumps flat.
static func _blob_library(pulse: Animation, squash: String) -> AnimationLibrary:
	var one := Vector3.ONE
	var zero := Vector3.ZERO
	# clip: [length s, pulse rate, loops, squash keys [time, scale, position]]
	var moves := {
		"idle_a": [3.0, 1.0, true, [[0.0, one, zero]]],
		"crawl_a": [1.0, 3.0, true, [[0.0, one, zero], [0.3, Vector3(0.94, 1.1, 1.12), Vector3(0, 0.03, -0.06)],
				[0.65, Vector3(1.1, 0.88, 0.92), Vector3(0, 0, 0.04)], [1.0, one, zero]]],
		"attack_a": [1.1, 2.5, false, [[0.0, one, zero], [0.4, Vector3(1.08, 0.86, 1.1), Vector3(0, 0, 0.18)],
				[0.6, Vector3(0.85, 1.15, 1.35), Vector3(0, 0.06, -0.55)],
				[0.8, Vector3(1.1, 0.9, 1.05), Vector3(0, 0, -0.35)], [1.1, one, zero]]],
		"hit_a": [0.4, 2.0, false, [[0.0, one, zero], [0.08, Vector3(1.16, 0.78, 1.16), zero],
				[0.22, Vector3(0.95, 1.06, 0.95), zero], [0.4, one, zero]]],
		"scream_a": [1.6, 4.0, false, [[0.0, one, zero], [0.3, Vector3(1.22, 1.3, 1.22), zero],
				[0.38, Vector3(1.28, 1.24, 1.28), zero], [0.46, Vector3(1.2, 1.32, 1.2), zero],
				[0.54, Vector3(1.28, 1.24, 1.28), zero], [0.62, Vector3(1.2, 1.32, 1.2), zero],
				[0.7, Vector3(1.28, 1.24, 1.28), zero], [1.6, one, zero]]],
		"death_a": [1.6, 3.0, false, [[0.0, one, zero], [0.25, Vector3(1.2, 1.25, 1.2), zero],
				[0.6, Vector3(1.45, 0.5, 1.45), zero], [1.6, Vector3(1.7, 0.14, 1.7), zero]]],
	}
	var lib := AnimationLibrary.new()
	for clip: String in moves:
		var m: Array = moves[clip]
		var length: float = m[0]
		var rate: float = m[1]
		var anim := Animation.new()
		anim.length = length
		anim.loop_mode = Animation.LOOP_LINEAR if m[2] else Animation.LOOP_NONE
		if m[2]:  # a whole number of beats, so the loop closes
			rate = maxf(1.0, roundf(length * rate / pulse.length)) * pulse.length / length
		for t in pulse.get_track_count():
			var type := pulse.track_get_type(t)
			var nt := anim.add_track(type)
			anim.track_set_path(nt, pulse.track_get_path(t))
			for f in int(roundf(length * 30.0)) + 1:
				var k := minf(f / 30.0, length)
				var at := fmod(k * rate, pulse.length)
				if clip == "death_a":  # the pulse dies away with it
					at *= 1.0 - k / length
				match type:
					Animation.TYPE_ROTATION_3D:
						anim.rotation_track_insert_key(nt, k, pulse.rotation_track_interpolate(t, at))
					Animation.TYPE_SCALE_3D:
						anim.scale_track_insert_key(nt, k, pulse.scale_track_interpolate(t, at))
					Animation.TYPE_POSITION_3D:
						anim.position_track_insert_key(nt, k, pulse.position_track_interpolate(t, at))
		var st := anim.add_track(Animation.TYPE_SCALE_3D)
		anim.track_set_path(st, squash)
		var pt := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pt, squash)
		for key: Array in m[3]:
			anim.scale_track_insert_key(st, key[0], key[1])
			anim.position_track_insert_key(pt, key[0], key[2])
		if clip == "crawl_a":
			anim.set_meta("speed", 0.6)  # m/s at size 1
		lib.add_animation(clip, anim)
	return lib


## The dog comes with a howl, its scream. The rest is made on its bones, each turned about the side
## axis (it faces +Z as modelled, so X) by a wave: [bone, amplitude rad, phase in cycles, offset rad].
## Hind legs swing together and the front pair against them, a gallop; the spine flexes with them.
## A positive turn drops the head.
const DOG_GAITS := {
	# clip: [length s, waves, squash keys [time, position in heights, rotation about Z deg]]
	"idle_a": [2.4, [["Spine3", 0.03, 0.0, 0.0], ["Neck", 0.05, 0.25, 0.0], ["Head", 0.06, 0.4, 0.0],
			["Face_Jaw", 0.08, 0.0, 0.1], ["Tail_1", 0.15, 0.0, 0.0], ["Tail_2", 0.2, 0.15, 0.0]], []],
	"run_a": [0.5, [["Thigh_L", 0.55, 0.0, 0.0], ["Thigh_R", 0.55, 0.08, 0.0], ["Calf_L", 0.45, 0.2, 0.25],
			["Calf_R", 0.45, 0.28, 0.25], ["UpperArm_L", 0.6, 0.5, 0.0], ["UpperArm_R", 0.6, 0.58, 0.0],
			["ForeArm_L", 0.5, 0.7, -0.3], ["ForeArm_R", 0.5, 0.78, -0.3], ["Spine1", 0.12, 0.25, 0.0],
			["Spine2", 0.12, 0.25, 0.0], ["Neck", 0.1, 0.75, 0.0], ["Head", 0.12, 0.85, 0.0],
			["Face_Jaw", 0.15, 0.0, 0.25], ["Tail_1", 0.25, 0.5, 0.0], ["Tail_2", 0.3, 0.6, 0.0]],
			[[0.0, Vector3(0, 0.0, 0), 0.0], [0.25, Vector3(0, 0.05, 0), 0.0], [0.5, Vector3(0, 0.0, 0), 0.0]]],
	"attack_a": [0.9, [["Neck", -0.4, 0.0, 0.0], ["Head", -0.3, 0.05, 0.0], ["Face_Jaw", 0.35, 0.0, 0.35],
			["Thigh_L", 0.5, 0.0, 0.0], ["Thigh_R", 0.5, 0.0, 0.0], ["UpperArm_L", 0.6, 0.5, 0.0],
			["UpperArm_R", 0.6, 0.5, 0.0]],
			[[0.0, Vector3.ZERO, 0.0], [0.3, Vector3(0, -0.05, -0.1), 0.0], [0.5, Vector3(0, 0.08, 0.45), 0.0],
			[0.9, Vector3.ZERO, 0.0]]],
	"hit_a": [0.35, [["Spine2", -0.2, 0.0, 0.0], ["Neck", -0.35, 0.1, 0.0], ["Face_Jaw", 0.2, 0.0, 0.2]],
			[[0.0, Vector3.ZERO, 0.0], [0.08, Vector3(0, -0.06, -0.06), 0.0], [0.35, Vector3.ZERO, 0.0]]],
	"death_a": [1.2, [["Neck", 0.4, 0.0, 0.0], ["Face_Jaw", 0.4, 0.0, 0.4], ["Thigh_L", 0.3, 0.0, 0.3],
			["Thigh_R", 0.3, 0.0, 0.3], ["UpperArm_L", 0.4, 0.0, -0.4], ["UpperArm_R", 0.4, 0.0, -0.4]],
			[[0.0, Vector3.ZERO, 0.0], [0.3, Vector3(0, 0.05, 0), 15.0], [0.8, Vector3(0.45, 0.2, 0), 90.0],
			[1.2, Vector3(0.5, 0.18, 0), 88.0]]],
}


static func _dog_library(src: Node3D, howl: Animation, c: Dictionary) -> AnimationLibrary:
	var sk: Skeleton3D = src.get_node(c.skeleton)
	var top: float = sk.get_bone_global_rest(sk.find_bone("Bone_WH_Spine2")).origin.y  # the back
	var lib := AnimationLibrary.new()
	var scream := howl.duplicate()
	scream.loop_mode = Animation.LOOP_NONE
	lib.add_animation("scream_a", scream)
	for clip: String in DOG_GAITS:
		var g: Array = DOG_GAITS[clip]
		var length: float = g[0]
		var once := clip in ["attack_a", "hit_a", "death_a"]
		var anim := Animation.new()
		anim.length = length
		anim.loop_mode = Animation.LOOP_NONE if once else Animation.LOOP_LINEAR
		for w: Array in g[1]:
			var b := sk.find_bone("Bone_WH_" + w[0])
			var axis := sk.get_bone_global_rest(b).basis.orthonormalized().inverse() * Vector3.RIGHT
			var rest := sk.get_bone_rest(b).basis.get_rotation_quaternion()
			var t := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, "%s:%s" % [c.skeleton, sk.get_bone_name(b)])
			for f in int(roundf(length * 30.0)) + 1:
				var k := minf(f / 30.0, length)
				var p := k / length
				# a loop is a full wave around the offset, a one-shot one swell and back; death stays
				var angle: float = w[1] * sin(TAU * (p + w[2])) + w[3]
				if clip == "death_a":
					angle = (w[1] + w[3]) * smoothstep(0.0, 0.7, p)
				elif once:
					angle = (w[1] + w[3]) * sin(PI * p)
				anim.rotation_track_insert_key(t, k, rest * Quaternion(axis.normalized(), angle))
		if not g[2].is_empty():
			var pt := anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(pt, c.squash)
			var rt := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(rt, c.squash)
			for key: Array in g[2]:
				anim.position_track_insert_key(pt, key[0], key[1] * top)
				anim.rotation_track_insert_key(rt, key[0], Quaternion(Vector3.FORWARD, deg_to_rad(key[2])))
		if clip == "run_a":
			anim.set_meta("speed", 4.0)  # m/s at 0.85 m
		lib.add_animation(clip, anim)
	return lib
