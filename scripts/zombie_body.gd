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
const SCREEN := preload("res://scripts/screen_blood.gd")
const FLESH := preload("res://materials/env/gore/flesh.tres")
const STUMP := preload("res://materials/env/gore/meat_1.res")
const LIB := preload("res://assets/characters/zombies/zombie_anims.res")
## All PS1 horror (tools/lowpoly_zombie.gd psx): fewer triangles, the real texture small and unfiltered.
const MODELS := {
	&"prisoner": preload("res://assets/characters/zombies/prisoner/prisoner_psx.scn"),
	&"copzombie": preload("res://assets/characters/zombies/copzombie/copzombie_psx.scn"),
	&"parasite": preload("res://assets/characters/zombies/parasite/parasite_psx.scn"),
	&"warzombie": preload("res://assets/characters/zombies/warzombie/warzombie_psx.scn"),
	&"zombiegirl": preload("res://assets/characters/zombies/zombiegirl/zombiegirl_psx.scn"),
	&"yaku": preload("res://assets/characters/zombies/yaku/yaku_psx.scn"),
	&"romero": preload("res://assets/characters/zombies/romero/romero_psx.scn"),
	&"skeletonzombie": preload("res://assets/characters/zombies/skeletonzombie/skeletonzombie_psx.scn"),
	&"whiteclown": preload("res://assets/characters/zombies/whiteclown/whiteclown_psx.scn"),
	&"warrok": preload("res://assets/characters/zombies/warrok/warrok_psx.scn"),
	&"maw": preload("res://assets/characters/zombies/maw/maw_psx.scn"),
	&"demon": preload("res://assets/characters/zombies/demon/demon_psx.scn"),
	&"fleshzombie": preload("res://assets/characters/zombies/fleshzombie/fleshzombie_psx.scn"),
	&"hazmat": preload("res://assets/characters/zombies/hazmat/hazmat_psx.scn"),
	&"bloater": preload("res://assets/characters/zombies/bloater/bloater_psx.scn"),
	&"leaper": preload("res://assets/characters/zombies/leaper/leaper_psx.scn"),  # no legs: its tail is the right leg
	&"spiker": preload("res://assets/characters/zombies/spiker/spiker_psx.scn"),
}
## Not Mixamo (PS1 horror like the rest: tools/lowpoly_zombie.gd psx, the glb with its own clips kept): its scene, the skeleton and the node the squash moves (paths in the scene), which bone
## stands in for "Head" / "Hips" in attach(), its height in m at size 1 (0: as modelled), whether it
## faces +Z as modelled (turned like the Mixamo ones), and its own clips (_creature_library).
const CREATURES := {
	&"blob": {"scene": preload("res://assets/characters/zombies/blob/blob_psx.scn"),
			"skeleton": "Armature/Skeleton3D", "squash": "Armature", "height": 0.0, "turn": false,
			"bones": {"Head": "Bone.003", "Hips": "Bone.001"}},
	&"melty": {"scene": preload("res://assets/characters/zombies/melty/melty_psx.scn"),
			"skeleton": "Sketchfab_model/melty zombie_fbx/Object_2/RootNode/Object_4/Skeleton3D",
			"squash": "Sketchfab_model", "height": 1.8, "turn": true,
			"bones": {"Head": "head_014", "Hips": "hip_016"}},
	&"dog": {"scene": preload("res://assets/characters/zombies/dog/dog_psx.scn"),
			"skeleton": "Armature/Skeleton3D", "squash": "Armature", "height": 0.85, "turn": true,
			"bones": {"Head": "Bone_WH_Head", "Hips": "Bone_WH_Pelvis"}},
}
## kind -> models it wears, clip family ("" zombie, "mutant_" the creature set), its move loop,
## and its size range.
const KINDS := {
	&"walker": {"models": [&"prisoner", &"copzombie", &"warzombie", &"zombiegirl", &"parasite",
			&"yaku", &"romero", &"skeletonzombie", &"fleshzombie", &"hazmat", &"melty"],
			"set": "", "move": "run", "size": [0.95, 1.06]},
	&"runner": {"models": [&"prisoner", &"copzombie", &"zombiegirl", &"parasite", &"yaku",
			&"skeletonzombie", &"fleshzombie", &"hazmat", &"melty"],
			"set": "", "move": "run", "size": [0.95, 1.04]},
	# Roles of their own (waves.gd): each in one look only, so it is known across the hall.
	&"bloater": {"models": [&"bloater"], "set": "", "move": "run", "size": [1.02, 1.1]},
	&"screamer": {"models": [&"whiteclown"], "set": "", "move": "run", "size": [0.97, 1.03]},
	&"crawler": {"models": [&"prisoner", &"warzombie", &"zombiegirl", &"romero", &"skeletonzombie",
			&"fleshzombie", &"hazmat"],
			"set": "", "move": "crawl_run", "size": [0.95, 1.05]},
	&"brute": {"models": [&"warrok", &"maw", &"demon"],  # already ~2.4 m
			"set": "mutant_", "move": "run", "size": [1.0, 1.12]},
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
## Far from the camera, or out of its view, the clips are stepped every LOD_STEP frames (each zombie
## on its own beat), not every frame: a crowd at the gates costs a third, and so do the ones along
## the railing off to the sides. A round about to pass near one brings its pose up to date first
## (catch_up(), waves.gd fit_along), so the hit shapes are where the body is.
const LOD_FAR := 22.0  # m
const LOD_STEP := 3
const LOD_RADIUS := 1.5  # m around the middle of a body that still counts as in view
## How far a loop's playback may be sped up or slowed to match the ground it covers (move()).
const STRIDE := [0.6, 1.8]
## Over and under the railing (waves.gd cross; 2026-11-01). The library has no climb, vault or
## under-crawl, so these are the nearest clips (docs/ayrintilar.md lists the Mixamo ones to fetch):
## the mutant standing jump (crouch to VAULT_OFF s, feet down again at VAULT_LAND), the stumble's
## last part for one shot out of the air (on the floor at KNOCK_FLOOR), the zombie get-up, played
## backwards over DUCK_SECTION to lie down and forwards to stand up, and the belly crawl's low part
## (CREEP_SECTION, between the two times it props itself up; "creep_a", _library()) looped back and
## forth, so the head keeps under the bottom rail. Rates and times are mine.
const VAULT_CLIP := "mutant_jump_a"
const VAULT_OFF := 1.15
const VAULT_LAND := 2.05
const VAULT_RATE := 1.4
const VAULT_AGAIN := 0.45  # s into the clip a hit sends it back to, standing, before the crouch
const KNOCK_CLIP := "fall_a"
const KNOCK_FROM := 1.8
const KNOCK_FLOOR := 2.5
const KNOCK_RATE := 1.6
const DUCK_CLIP := "stand_up_a"
const DUCK_SECTION := [0.15, 2.7]  # flat on its belly at the start
const CREEP_CLIP := "crawl_a"
const CREEP_SECTION := [2.05, 2.95]
const CREEP_RATE := 1.3
const DUCK_RATE := 1.3
const RISE_RATE := 1.3
const FALL_SPEED := 1.5  # the stumble-and-fall clip is slow for a leg torn off
const LIMB_REACH := 0.1  # m at size 1: how far off a limb's bone a round's line may pass and hit it
const TORSO_REACH := 0.15  # the same for the spine, which takes the round if it is first in line
const HEAD_R := 0.1  # m at size 1, about: from the head bone out to where a round goes in
## A head blown off (_blow_head()): the body stands a blink before it goes (s), the neck spurts this
## many more times, and blood lands on the screen when it happened this close to the camera (m: all
## of it at SCREEN_NEAR, none past SCREEN_FAR).
const POP_HOLD := [0.12, 0.3]
const POP_BEATS := [3, 5]
const SCREEN_NEAR := 1.5
const SCREEN_FAR := 4.0
const NECK_SKIN := 0.45  # of the head's size, around the neck's line: skin that stays when the head goes (_make_headless)

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
var _hold := false  # lying where it fell, until get_up()
var _stand_move := ""  # its gait before it went down to go under
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
	var slump := Vector3.ZERO  # the way a headless body sags as it goes down (_collapse())

	func _process_modification() -> void:
		var sk := get_skeleton()
		for b in spine:
			_turn(sk, b, (bend + slump) / spine.size())
		_turn(sk, head, nod)
		for i in arms.size():
			_turn(sk, arms[i], arm_kick[i])
		if head_gone and head >= 0:  # blown off: folded to nothing at the neck
			sk.set_bone_pose_scale(head, Vector3.ONE * 0.001)
			# down into the neck's root too: folded at the neck's top, the skin half on the head
			# was drawn up into a spike there
			sk.set_bone_pose_position(head, Vector3.ZERO)
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
	crawling = _move.begins_with("crawl")  # (a creature never: it has no belly clips)
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
	if ANIM_FPS > 0.0:  # PS1 steps, near or far (_step_ps1)
		_step_ps1(delta)
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var far := cam != null and not _dead and (cam.global_position.distance_squared_to(global_position) > LOD_FAR * LOD_FAR
			or not _in_view(cam, global_position + Vector3.UP * height * 0.5))
	if not far:
		if _ap.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
			_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
			_skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
			_ap.advance(_lod_wait)
			_lod_wait = 0.0
		return
	# The skeleton's springs (Flinch, zombie_hit_react.gd) are laid on with the clips' steps: with
	# them every frame it updated every bone every frame, still or not.
	if _ap.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	_lod_wait += delta
	_lod_beat += 1
	if (_lod_beat + _seed) % LOD_STEP == 0:
		_ap.advance(_lod_wait)
		_skel.advance(_lod_wait)
		_lod_wait = 0.0


## PS1 feel (2026-11-02, the user: the whole game in PS1 horror): the clips go on in steps,
## ANIM_FPS of them a second whatever the frame rate, as on the old console, near or far (the LOD
## steps above only count with it at 0). Where the body goes (waves.gd) and the player stay smooth;
## the springs are laid on with the steps. Each body on its own beat, from `seed`, so a crowd
## doesn't jerk all at once. catch_up() still brings the pose up to date before a round is traced.
## 2026-11-04, the user: raise it, normal movement; so 0, with the LOD steps above for the far ones.
const ANIM_FPS := 0.0  # 0: smooth, every frame


func _step_ps1(delta: float) -> void:
	if _ap.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
		_ap.advance(_lod_wait)  # posed at once, not standing in its rest pose till the first step
		_skel.advance(_lod_wait)
		_lod_wait = float(posmod(_seed, 1000)) / 1000.0 / ANIM_FPS
	_lod_wait += delta
	if _lod_wait >= 1.0 / ANIM_FPS:
		_ap.advance(_lod_wait)
		_skel.advance(_lod_wait)
		_lod_wait = 0.0


## The camera's view as a cone round its corners, worked out once a frame for every body: its eye,
## its forward and the cone's half angle (cos, sin).
static var _view := [Vector3.ZERO, Vector3.FORWARD, 0.0, 1.0]
static var _view_frame := -1


static func _in_view(cam: Camera3D, at: Vector3) -> bool:
	var frame := Engine.get_process_frames()
	if frame != _view_frame:
		_view_frame = frame
		var screen := cam.get_viewport().get_visible_rect().size
		var half := atan(tan(deg_to_rad(cam.fov) * 0.5) * Vector2(screen.x / maxf(screen.y, 1.0), 1.0).length())
		_view = [cam.global_position, -cam.global_basis.z, cos(half), sin(half)]
	var to: Vector3 = at - _view[0]
	var along: float = to.dot(_view[1])
	var across := sqrt(maxf(to.length_squared() - along * along, 0.0))
	return across * _view[2] - along * _view[3] <= LOD_RADIUS


## The clips held back while out of view or far, played now (a round is about to be traced past it).
func catch_up() -> void:
	if _lod_wait > 0.0:
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


## Whether `part` is still there to come off: a Mixamo rig (not a brute's legs, it has no crawl;
## not the leaper's, it has a tail), and neither it nor the limb it hangs from gone.
func can_lose(part: StringName) -> bool:
	if CREATURES.has(model) or part in cuts or LOWER.get(part, &"") in cuts:
		return false
	return (kind != &"brute" and model != &"leaper") or not is_leg(part)


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
## crawls (move()). `roll` (waves.gd, the host's) makes the throw unlike the last one.
func cut(part: StringName, fly := true, roll := 0) -> float:
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
		_reseed("cut%s%d" % [part, roll])
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


## Loops the kind's walk / run / crawl, its stride stretched to `speed` m/s: one of its own gait's
## clips whose stride fits inside STRIDE, else the quicker gait's (a walker driven to a run, one on
## its belly to the running crawl), else the nearest.
## `family`: another gait than its own ("walk" for one stalking, waves.gd), if it has those clips.
func move(speed: float, family := "") -> void:
	_voice.wake()
	var clip := _gait(speed, family)
	var natural := _natural(clip)
	_play_loop(clip, clampf(speed / natural, STRIDE[0], STRIDE[1]) if natural > 0.05 else 1.0)


## Keeps the loop playing as it moves: its stride stretched to `speed` m/s, down to a third of the
## clip's (a braking or staggered one shuffles), without changing clips. Nothing in a one-shot.
func pace(speed: float) -> void:
	if _busy or _dead or _loop == "":
		return
	var natural := _natural(_loop)
	if natural > 0.05:
		_loop_speed = clampf(speed / natural, 0.3, STRIDE[1])
		_ap.speed_scale = _loop_speed


## Whether it is in a one-shot now (a swing, a flinch, a scream, the fall).
func busy() -> bool:
	return _busy


## Whether it goes in the quick gait now (run, running crawl).
func quick() -> bool:
	return _loop.contains("run")


## The slowest and quickest it can go in `family` with its feet keeping to the floor (STRIDE of
## its clips' own pace); zero if it has no such clips.
func gait_span(family: String) -> Vector2:
	var span := Vector2(INF, 0.0)
	for c: String in _clips(_lib, _set + family):
		var nat := _natural(c)
		if nat > 0.05:
			span = Vector2(minf(span.x, nat * STRIDE[0]), maxf(span.y, nat * STRIDE[1]))
	return span if span.y > 0.0 else Vector2.ZERO


func _natural(clip: String) -> float:
	return _lib.get_animation(clip).get_meta("speed", 0.0) * _hip if _lib.has_animation(clip) else 0.0


func _gait(speed: float, own := "") -> String:
	var move := _move
	if own != "" and not crawling and not _clips(_lib, _set + own).is_empty():
		move = own
	var n: int = _count.get(move, 0)
	_count[move] = n + 1
	var near := ""
	var off := INF
	for family in [move, "run" if move == "walk" else "crawl_run" if move == "crawl" else ""]:
		if family == "":
			continue
		var fit := []
		for c: String in _clips(_lib, _set + family):
			var nat := _natural(c)
			if nat <= 0.05:
				return c  # (a creature clip with no stride: as it is)
			var r := speed / nat
			if r >= STRIDE[0] and r <= STRIDE[1]:
				fit.append(c)
			if absf(log(r)) < off:
				off = absf(log(r))
				near = c
		if not fit.is_empty():
			return fit[_roll("%s%d" % [move, n]) % fit.size()]
	return near if near != "" else _pick(move)


## The part of each swing that is played (2026-11-05, the user: the attacks are broken and not
## threatening): clip -> [from, strike, to] s. The strike is where the hands go quickest (measured off
## the clips' bones, tools/zombie_attack_check.gd): the clips stood still for 1-3 s before it and the
## blow landed at half the clip's length, before or long after the hands got there. Now a short
## wind-up (ATTACK_WINDUP s, quickened up to ATTACK_RATE_MAX), the strike, a short recovery. The
## mutant clips c and d step 1.8-2.4 m forward in the hips (root motion played in place: it slid
## out of its body and snapped back), so they are not swung. Times off the bones, the cuts are mine.
const ATTACKS := {
	"attack_a": [0.45, 1.0, 1.6], "attack_b": [2.55, 3.45, 3.95], "attack_d": [0.45, 1.48, 2.0],
	"attack_e": [0.1, 0.62, 1.03], "attack_f": [0.5, 1.17, 1.8], "attack_g": [0.6, 1.22, 1.8],
	"attack_h": [0.05, 0.63, 1.2], "attack_i": [0.5, 1.17, 1.75],
	"mutant_attack_a": [0.6, 1.28, 1.9], "mutant_attack_b": [0.0, 0.3, 1.1],
}
const ATTACK_SKIP: Array[String] = ["mutant_attack_c", "mutant_attack_d"]
const ATTACK_WINDUP := 0.5  # s from the swing's start to the blow
const ATTACK_RATE_MAX := 1.5
## Of the last swing: s from its start to the blow.
var strike := 0.0


## Swing at the fence or a player. Returns its length (s); `strike` is when the blow lands.
func attack() -> float:
	_voice.attack()
	if crawling:  # bites from the floor
		var bite := _one_shot("floor_bite")
		strike = bite * 0.5
		return bite
	var clip := _pick("attack")
	for i in 4:  # a clip that walks out of its body: another
		if not clip in ATTACK_SKIP:
			break
		clip = _pick("attack")
	if clip in ATTACK_SKIP or not ATTACKS.has(clip):
		var whole := _play_once(clip)
		strike = whole * 0.5
		return whole
	var cut: Array = ATTACKS[clip]
	var rate := clampf((cut[1] - cut[0]) / ATTACK_WINDUP, 1.0, ATTACK_RATE_MAX)
	_busy = true
	_ap.play_section(clip, cut[0], cut[2], BLEND * 0.6)
	_ap.speed_scale = rate
	strike = (cut[1] - cut[0]) / rate
	return (cut[2] - cut[0]) / rate


## Flinch from a shot; back to the loop after. Ignored mid-attack, and on its belly (the hit clips
## stand it up): there the spring alone (wound()) jerks it.
func hit() -> void:
	if not _busy and not crawling and not quick():  # running, the clip would stand it still while it slides on
		_one_shot("hit")


## It has seen or heard a player (waves.gd _sense): a shriek and the head jerking up, in its stride.
func notice() -> void:
	if _dead:
		return
	_voice.scream()
	_nod_v += Vector3(-KICK * 1.2, 0.0, 0.0)
	_bend_v += Vector3(KICK * 0.5, 0.0, 0.0)


## Roar (mutants) or scream (zombies). Returns the clip's length (s).
func scream() -> float:
	_voice.scream()
	return _one_shot("scream" if _set == "" else "roar")


## Over the railing (waves.gd cross): the mutant set's standing jump, quickened by VAULT_RATE. It
## crouches for the spring (the clip's first VAULT_OFF s, the moment to shoot it), is in the air
## until VAULT_LAND and comes up out of the landing after. Returns [s to the spring, s in the air].
## Again while it crouches (a hit stops it): back up a little and down into the crouch again.
func vault() -> Array:
	var from := 0.0
	if _ap.current_animation == VAULT_CLIP:
		from = VAULT_AGAIN
		_ap.seek(from, true)
	else:
		_voice.attack()
		_busy = true
		_ap.play(VAULT_CLIP, BLEND)
	_ap.speed_scale = VAULT_RATE
	return [(VAULT_OFF - from) / VAULT_RATE, (VAULT_LAND - VAULT_OFF) / VAULT_RATE]


## Shot out of the air: the stumble's last part, flat on the floor, and it lies there (held) until
## get_up(). Returns s to the floor.
func knocked() -> float:
	if _dead:
		return 0.0
	_busy = true
	_hold = true
	_ap.play(KNOCK_CLIP, 0.1)
	_ap.seek(KNOCK_FROM, true)
	_ap.speed_scale = KNOCK_RATE
	return (KNOCK_FLOOR - KNOCK_FROM) / KNOCK_RATE


## Under the railing (waves.gd cross): down onto its belly, the get-up played backwards, then the
## belly crawl is its loop (crawling, so its hit shapes lie low with it). Returns s till it lies.
func duck() -> float:
	if _dead:
		return 0.0
	_stand_move = _move
	crawling = true
	_move = "crawl"
	_loop = _pick(_move)
	_loop_speed = 1.0
	_busy = true
	_ap.play_section_backwards(DUCK_CLIP, DUCK_SECTION[0], DUCK_SECTION[1], BLEND * 2.0)
	_ap.speed_scale = DUCK_RATE
	return (DUCK_SECTION[1] - DUCK_SECTION[0]) / DUCK_RATE


## The wriggle under the railing (after duck()): the belly crawl's low part, back and forth.
func creep() -> void:
	if _dead:
		return
	_busy = false
	_loop = "creep_a"
	_loop_speed = CREEP_RATE
	_ap.play(_loop, BLEND * 2.0)
	_ap.speed_scale = CREEP_RATE


## Up off the floor (after going under, or shot out of the air) into its standing loop again.
## Nothing with a leg gone: it crawls on. Returns the get-up's length (s).
func get_up() -> float:
	_hold = false
	if _dead:
		return 0.0
	if cuts.any(is_leg):
		_busy = false
		_ap.play(_loop, BLEND)
		_ap.speed_scale = _loop_speed
		return 0.0
	if _stand_move != "":
		_move = _stand_move
		_stand_move = ""
	crawling = false
	_loop = _pick("idle")
	_loop_speed = 1.0
	_busy = true
	_ap.play(DUCK_CLIP, BLEND)
	_ap.speed_scale = RISE_RATE
	return _lib.get_animation(DUCK_CLIP).length / RISE_RATE


## Falls and stays down. Returns the clip's length (s). `gib`: &"head" blows the head off
## (_blow_head()), &"body" bursts the chest; `weak` without a gib: shot through the head, it goes
## down with the head snapped back (_head_shot()). The wave code decides which (waves.gd
## pop_chance()); its `roll`, and `dir` the killing round's way, make this death unlike the last
## one and the same on every peer.
func die(gib := &"", weak := false, roll := 0, dir := Vector3.ZERO) -> float:
	if _dead:
		return 0.0
	if dir.length() > 0.01:
		_last_dir = dir.normalized()
	_dead = true
	var head := _skel.to_global(_skel.get_bone_global_pose(_flinch.head).origin)
	var chest := _skel.to_global(_skel.get_bone_global_pose(_chest).origin)
	_voice.die(head if gib == &"head" else chest, gib != &"", gib == &"head")
	_reseed("die%d" % roll)
	var clip := _death_clip()
	var hold := 0.0
	if gib == &"head":
		hold = _blow_head(head)
	elif gib == &"body":
		var world := _world()
		GIBS.burst(world, chest, _last_dir, global_position.y, 14 + (8 if kind == &"brute" else 0), size, _rng.randi())
		_spray(chest, Vector3.UP, 22, 1.3)
		_spray(chest, _last_dir, 16, 1.2)
		BLOOD.mist(world, chest - _last_dir * 0.1, _aside(_last_dir, 0.3), _rng, 1.2 * size, 0.7)
		BLOOD.mist(world, chest - _last_dir * 0.1, _aside(_last_dir, 0.3), _rng, 1.0 * size, 0.6)
		BLOOD.mist(world, chest, (Vector3.UP + _last_dir).normalized(), _rng, 0.9 * size, 0.6)
		BLOOD.wall(world, chest, _last_dir, _rng, 3.5, 1.4 * size)
		var flat := Vector3(_last_dir.x, 0.0, _last_dir.z).normalized()
		BLOOD.ground(world, chest + flat * _rng.randf_range(0.6, 1.4), global_position.y, [&"spray", &"mist"], _rng,
				1.6 * size, flat)
		_stump(&"Spine1", 0.3)
	elif weak:
		_head_shot(head)
	_ap.speed_scale = 1.0
	var length := _lib.get_animation(clip).length
	if crawling:
		# The deaths start standing: from the belly it only slumps into the last of one.
		_ap.play(clip, 0.6)
		_ap.seek(length * 0.8, true)
		length *= 0.2
	elif hold > 0.0:
		_ap.speed_scale = 0.0  # it stands there a blink, headless, before it goes
		length = _collapse(clip, hold)
	else:
		_ap.play(clip, BLEND)
	_bleed_out(length * 0.7)
	return length


## The death clip this time, picked by the death's roll.
func _death_clip() -> String:
	var clips := _clips(_lib, _set + "death")
	if clips.is_empty():
		clips = _clips(_lib, ("" if _set != "" else "mutant_") + "death")
	return clips[_rng.randi() % clips.size()]


## The head comes apart at `at`: a skull's worth of small pieces (zombie_gibs.gd head()), a hard
## spurt up out of the neck and on along the round, mist, a big splash on whatever is behind, and
## the neck pumping a few more times. How hard, which way and how many are rolled each time.
## Returns how long the body stands before it goes down (s).
func _blow_head(at: Vector3) -> float:
	var world := _world()
	var dir := _last_dir
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.05 else Vector3.RIGHT
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var power := _rng.randf_range(0.8, 1.3)
	GIBS.head(world, at, dir, global_position.y, size, _rng.randi(), power)
	var up := (Vector3.UP + dir * _rng.randf_range(0.1, 0.8) + side * _rng.randf_range(-0.45, 0.45)).normalized()
	_spray(at, up, roundi(28 * power), 1.6 * power)
	_spray(at, (dir + side * _rng.randf_range(-0.5, 0.5) + Vector3.UP * 0.2).normalized(), roundi(22 * power), 1.4 * power)
	_spray(at, (-dir + Vector3.UP * 0.4).normalized(), 6, 0.6)
	BLOOD.mist(world, at - dir * 0.1, _aside(dir, 0.3), _rng, _rng.randf_range(1.0, 1.4) * size, 0.7)
	BLOOD.mist(world, at + dir * 0.1, (dir + Vector3.UP * 0.5).normalized(), _rng, _rng.randf_range(0.9, 1.3) * size, 0.6)
	BLOOD.mist(world, at, up, _rng, _rng.randf_range(0.7, 1.1) * size, 0.5)
	# The big splash on whatever is behind it, and a second one off to a side.
	BLOOD.wall(world, at, (dir + side * _rng.randf_range(-0.25, 0.25)).normalized(), _rng, 4.5, _rng.randf_range(1.7, 2.4) * size)
	BLOOD.wall(world, at, (dir + side * _rng.randf_range(-0.9, 0.9) + Vector3.UP * _rng.randf_range(-0.2, 0.3)).normalized(),
			_rng, 3.5, _rng.randf_range(0.9, 1.4) * size)
	var along := flat.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	BLOOD.ground(world, at + along * _rng.randf_range(0.6, 1.8), global_position.y, [&"spray", &"mist"], _rng,
			_rng.randf_range(1.4, 2.2) * size, along)
	_flinch.head_gone = true
	for hat: Array in _lose_head():
		_throw_hat(hat[0], hat[1])
	_stump(&"Neck", 0.16)
	var neck := _skel.get_bone_parent(_flinch.head)
	_pulse(neck, _rng.randi_range(POP_BEATS[0], POP_BEATS[1]), power)
	VOICE.gore(&"pop", at, 3.0, _rng.randf_range(0.92, 1.08) / sqrt(size))
	VOICE.gore(&"crack", at, -1.0, _rng.randf_range(0.9, 1.15))
	var glass := RandomNumberGenerator.new()  # its own, so the peers' rolls stay in step
	glass.seed = _rng.randi()
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := cam.global_position.distance_to(at)
		SCREEN.splash(get_tree(), clampf((SCREEN_FAR - d) / (SCREEN_FAR - SCREEN_NEAR), 0.0, 1.0), glass)
	return _rng.randf_range(POP_HOLD[0], POP_HOLD[1])


## After standing `hold` s with no head, it goes down: `clip` from a little way in, quicker or
## slower, the body sagging forward, back or to a side as it falls. Returns the whole time (s).
func _collapse(clip: String, hold: float) -> float:
	var speed := _rng.randf_range(0.85, 1.3)
	var skip := _rng.randf_range(0.0, 0.25) * _lib.get_animation(clip).length
	# skeleton space: it faces +Z, so about +X it pitches forward, about Z it leans to a side
	var sag: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][_rng.randi() % 4] * _rng.randf_range(0.25, 0.55)
	_fall_after(clip, hold, speed, skip, sag)
	return hold + (_lib.get_animation(clip).length - skip) / speed


func _fall_after(clip: String, hold: float, speed: float, skip: float, sag: Vector3) -> void:
	await get_tree().create_timer(hold).timeout
	if not is_inside_tree():
		return
	_ap.play(clip, 0.15)
	_ap.seek(skip, true)
	_ap.speed_scale = speed
	var t := create_tween()
	t.tween_property(_flinch, "slump", sag, 0.7 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The neck of a head blown off (bone `b`) spurts `beats` more times with the heart, each weaker,
## each its own way.
func _pulse(b: int, beats: int, power: float) -> void:
	var gaps: Array[float] = []
	var aims: Array[Vector3] = []
	for i in beats:
		gaps.append(_rng.randf_range(0.26, 0.42))
		aims.append(Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4)))
	for i in beats:
		await get_tree().create_timer(gaps[i]).timeout
		if not is_inside_tree():
			return
		var joint := _skel.to_global(_skel.get_bone_global_pose(b).origin)
		var out := joint - _skel.to_global(_skel.get_bone_global_pose(_skel.get_bone_parent(b)).origin)
		var left := 1.0 - float(i) / beats
		_spray(joint, (out.normalized() + aims[i]).normalized(), 4 + roundi(14 * left * power), (0.6 + 0.7 * left) * power)
		if i % 2 == 0:
			VOICE.gore(&"squirt", joint, -8.0 + 5.0 * left)


## Shot through the head and down, the head still on: it snaps back from the round, blood and mist
## come out the back, a hole stays where it went in.
func _head_shot(at: Vector3) -> void:
	var dir := _last_dir
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.01:
		axis = _skel.global_basis.orthonormalized().inverse() * axis.normalized()
		_nod_v += axis * KICK * KICK_HEAD * _rng.randf_range(1.6, 2.4)
		_bend_v += axis * KICK * _rng.randf_range(0.5, 1.1)
	var world := _world()
	_spray(at + dir * 0.08, (dir + Vector3.UP * _rng.randf_range(0.0, 0.4)).normalized(), 18, 1.3)
	BLOOD.mist(world, at + dir * 0.15, dir, _rng, _rng.randf_range(0.8, 1.1) * size, 0.5)
	BLOOD.mist(world, at - dir * 0.1, _aside(dir, 0.4), _rng, 0.7 * size, 0.4)
	BLOOD.wall(world, at, (dir + Vector3.UP * _rng.randf_range(-0.1, 0.2)).normalized(), _rng, 3.0, _rng.randf_range(0.9, 1.3) * size)
	BLOOD.hole(attach("Head"), at - dir * HEAD_R * size, dir, _rng, 0.06 * size)


## Once it is down, a pool spreads under the body.
func _bleed_out(after: float) -> void:
	await get_tree().create_timer(after).timeout
	if not is_inside_tree():
		return
	var hips := _skel.to_global(_skel.get_bone_global_pose(0).origin)
	_reseed("pool")
	BLOOD.ground(_world(), hips, global_position.y, [&"pool"], _rng, 1.4 * size, Vector3.ZERO, 5.0)
	_voice.ooze(hips)


## What hangs off the head but is skinned to the neck and shoulders too (long hair, a fringe, a
## hood) would stay on the neck, drawn in halfway: each mesh is swapped for one where that skin
## hangs on the head alone, so it folds away with it. Returns the hats it wore (_make_headless()),
## each [mesh in the head bone's space, the head's height in it].
func _lose_head() -> Array:
	var hats := []
	for mi: MeshInstance3D in _skel.get_parent().find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null and mi.mesh != null:
			var off := headless(mi.mesh, mi.skin, _skel, _flinch.head)
			mi.mesh = off.mesh
			if off.hat != null:
				hats.append([off.hat, off.crown])
	return hats


## A hat knocked off the falling head: thrown on the way the round went, tumbling, landing on its
## brim or its crown.
func _throw_hat(hat: Mesh, crown: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = hat
	var bone := _skel.global_transform * _skel.get_bone_global_pose(_flinch.head)
	m.transform = bone
	# (its ends around the hat, which sits from about 0.3 to 1.15 of the head's height up the bone)
	GIBS.limb(_world(), m, bone * Vector3(0, crown * 0.4, 0), bone * Vector3(0, crown * 1.1, 0), _last_dir,
			global_position.y, size, _rng.randi(), true)


## `mesh` with the skin that goes with the head on head bone `head` alone, and its hat, made once per
## mesh: {mesh (itself when nothing of it goes), hat (or null), crown}.
static func headless(mesh: Mesh, skin: Skin, sk: Skeleton3D, head: int) -> Dictionary:
	if not _headless.has(mesh):
		_headless[mesh] = _make_headless(mesh, skin, sk, head)
	return _headless[mesh]


static var _headless := {}


## A piece of a mesh (its triangles that share corners, seams welded) goes with the head when the
## head carries most of its weight: hair, glasses, a hood, the head's own skin. Only its part in the
## neck (NECK_SKIN of the head's size around the neck's line, hung on the spine alone) stays as it
## was, blended between the two, or the neck would be left open. The body's skin, which the head
## pulls on only near the neck, stays too.
## A piece wholly on the head that sits on its top and is as wide and deep as it is high (a cap, a
## helmet) is also given as a mesh of its own, in the head bone's space, to be knocked off.
static func _make_headless(mesh: Mesh, skin: Skin, sk: Skeleton3D, head: int) -> Dictionary:
	var inhead := {}
	var todo: Array[int] = [head]
	var top := sk.get_bone_global_rest(head).origin
	var reach := 0.0
	while not todo.is_empty():
		var i: int = todo.pop_back()
		inhead[i] = true
		reach = maxf(reach, sk.get_bone_global_rest(i).origin.y - top.y)  # its crown (not a rope of hair below it)
		todo.append_array(sk.get_bone_children(i))
	var spine := {}  # the bones the head hangs from, down to the root
	var down := sk.get_bone_parent(head)
	while down >= 0:
		spine[down] = true
		down = sk.get_bone_parent(down)
	var neck := top.distance_to(sk.get_bone_global_rest(sk.get_bone_parent(head)).origin)
	if reach < neck * 0.5:  # no bone up at its crown: about as big as its neck is long
		reach = neck
	var crown := reach
	reach *= NECK_SKIN
	var binds: Array[int] = []  # skin bind -> bone
	var to_head := -1
	for b in skin.get_bind_count():
		var name := skin.get_bind_name(b)
		binds.append(sk.find_bone(name) if name != &"" else skin.get_bind_bone(b))
		if binds[b] == head or (to_head < 0 and inhead.has(binds[b])):
			to_head = b
	var kept := {"mesh": mesh, "hat": null, "crown": crown}
	if to_head < 0:
		return kept
	var bind := skin.get_bind_pose(to_head)  # mesh -> the head bone as bound: the neck's top at 0, up its +Y
	var out := ArrayMesh.new()
	var hat := ArrayMesh.new()
	var changed := false
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bones = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var per := 0 if v.is_empty() else w.size() / v.size()
		var piece := _pieces(v, a[Mesh.ARRAY_INDEX])
		var on := PackedFloat32Array()  # how much each vertex hangs on the head
		on.resize(v.size())
		var pull := {}  # piece -> [head weight, vertices, least on the head, box in the head's space]
		for i in v.size():
			for k in per:
				if inhead.has(binds[bones[i * per + k]]):
					on[i] += w[i * per + k]
			var p: Array = pull.get_or_add(piece[i], [0.0, 0, 1.0, AABB(bind * v[i], Vector3.ZERO)])
			p[0] += on[i]
			p[1] += 1
			p[2] = minf(p[2], on[i])
			p[3] = p[3].expand(bind * v[i])
		var hats := {}
		for k in pull:
			var p: Array = pull[k]
			var box: AABB = p[3]
			if p[2] > 0.99 and p[1] >= 30 and box.position.y > crown * 0.3 and box.end.y > crown 					and box.size.x > crown and box.size.z > crown:
				hats[k] = true
		if not hats.is_empty():
			_add_piece(hat, a, piece, hats, bind)
			hat.surface_set_material(hat.get_surface_count() - 1, mesh.surface_get_material(s))
		var moved := 0
		for i in v.size():
			var p: Array = pull[piece[i]]
			if p[0] < p[1] * 0.5 or (w[i * per] > 0.999 and binds[bones[i * per]] == head):
				continue
			if on[i] < 0.99 and _on_spine(i, per, bones, w, binds, inhead, spine):
				var at := bind * v[i]
				if at.y < reach and Vector2(at.x, at.z).length() < reach:  # in the neck, or just over it
					continue
			for k in per:
				bones[i * per + k] = to_head if k == 0 else 0
				w[i * per + k] = 1.0 if k == 0 else 0.0
			moved += 1
		if moved > 0:
			changed = true
			a[Mesh.ARRAY_BONES] = bones
			a[Mesh.ARRAY_WEIGHTS] = w
		var flags: int = mesh.surface_get_format(s) & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), a, [], {}, flags)
		out.surface_set_material(s, mesh.surface_get_material(s))
	if changed:
		kept.mesh = out
	if hat.get_surface_count() > 0:
		kept.hat = hat
	return kept


## The triangles of surface `a` in `pieces` (piece -> true), as a surface of `to`, moved by `bind`.
static func _add_piece(to: ArrayMesh, a: Array, piece: PackedInt32Array, pieces: Dictionary, bind: Transform3D) -> void:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	if index.is_empty():
		index = PackedInt32Array(range(v.size()))
	var turn := bind.basis.orthonormalized()
	var new_at := {}  # old vertex -> new
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_i := PackedInt32Array()
	for t in range(0, index.size(), 3):
		if not pieces.has(piece[index[t]]):
			continue
		for j in 3:
			var i := index[t + j]
			if not new_at.has(i):
				new_at[i] = out_v.size()
				out_v.append(bind * v[i])
				if not n.is_empty():
					out_n.append(turn * n[i])
				if not uv.is_empty():
					out_uv.append(uv[i])
			out_i.append(new_at[i])
	var b := []
	b.resize(Mesh.ARRAY_MAX)
	b[Mesh.ARRAY_VERTEX] = out_v
	b[Mesh.ARRAY_INDEX] = out_i
	if not out_n.is_empty():
		b[Mesh.ARRAY_NORMAL] = out_n
	if not out_uv.is_empty():
		b[Mesh.ARRAY_TEX_UV] = out_uv
	var st := SurfaceTool.new()
	st.create_from_arrays(b)
	if not out_n.is_empty() and not out_uv.is_empty():
		st.generate_tangents()  # (for the normal map)
	st.commit(to)


## Whether vertex `i` hangs on nothing but the head and the neck and spine under it (not a shoulder:
## hair lying on them).
static func _on_spine(i: int, per: int, bones, w: PackedFloat32Array, binds: Array[int], inhead: Dictionary, spine: Dictionary) -> bool:
	for k in per:
		var b: int = binds[bones[i * per + k]]
		if w[i * per + k] > 0.0 and not spine.has(b) and not inhead.has(b):
			return false
	return true


## Which piece each vertex is in: vertices joined by triangles, or at the same spot (a UV seam).
static func _pieces(v: PackedVector3Array, index: PackedInt32Array) -> PackedInt32Array:
	if index.is_empty():
		index = PackedInt32Array(range(v.size()))
	var up := PackedInt32Array()
	up.resize(v.size())
	var at := {}
	for i in v.size():
		up[i] = at.get_or_add(Vector3i((v[i] * 10000.0).round()), i)
	for t in range(0, index.size(), 3):
		var a := _root(up, index[t])
		for j in [1, 2]:
			var b := _root(up, index[t + j])
			if b != a:
				up[b] = a
	for i in v.size():
		up[i] = _root(up, i)
	return up


static func _root(up: PackedInt32Array, i: int) -> int:
	while up[i] != i:
		up[i] = up[up[i]]
		i = up[i]
	return i


## Where a part tore off, on the bone: its raw end, a flattish lump of dark wet meat (GIBS wound) with
## blood soaked over it and down the edge, `width` m across at this size. Not the pink of a lump of
## flesh: the user's call, the neck of a head blown off looked like a sweet.
func _stump(bone: StringName, width: float) -> void:
	var a := attach(bone)
	var m := MeshInstance3D.new()
	m.mesh = STUMP
	m.material_override = GIBS.material(3)
	var s := width * size
	m.scale = Vector3(s, s * 0.45, s) * Vector3(_rng.randf_range(0.9, 1.1), _rng.randf_range(0.8, 1.2), _rng.randf_range(0.9, 1.1))
	m.rotation.y = _rng.randf() * TAU
	a.add_child(m)
	_soak(a, Vector3.ZERO, Vector3.UP, s)


## The same at `offset` (the bone's own space, at size 1: the body's scale carries it) on bone `b`,
## where the limb hanging off it was.
func _stump_on(b: int, offset: Vector3, width: float) -> void:
	var a := BoneAttachment3D.new()
	a.bone_name = _skel.get_bone_name(b)
	_skel.add_child(a)
	var m := MeshInstance3D.new()
	m.mesh = STUMP
	m.material_override = GIBS.material(3)
	m.position = offset
	m.scale = Vector3(width, width * 0.6, width)
	a.add_child(m)
	_soak(a, offset, offset.normalized() if offset.length() > 0.001 else Vector3.UP, width * size)


## Blood over a stump at `at` on `holder` (its own space), facing `out` along the bone, `width` m
## across: one decal soaked down over the raw end and onto the skin around it.
func _soak(holder: Node3D, at: Vector3, out: Vector3, width: float) -> void:
	var top := holder.global_transform * (at + out * width * 0.6)
	var down := holder.global_basis * -out
	BLOOD.hole(holder, top, down, _rng, width * 1.6, &"pool", 0.8)


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


static var _drop_mesh: QuadMesh
static var _drop_mat: ParticleProcessMaterial


func _spray(at: Vector3, dir: Vector3, amount: int, force: float) -> void:
	_drops()
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


## The blood drops' mesh and particle material, made once.
static func _drops() -> void:
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
		# PS1 horror: a blocky drop, unfiltered
		dot.width = 8
		dot.height = 8
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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


## Everything a zombie's blood and pieces draw with, drawn once at `at` (a speck in front of the
## camera) under `world`, so their shaders compile with the hall instead of at the first hit or the
## first head blown off (each of those held up its frame for 20 ms or more), and the meshes a head
## blown off leaves (_lose_head()) worked out. waves.gd does it.
static func prewarm(world: Node, at: Transform3D) -> void:
	_drops()
	var shown: Array[Node3D] = []
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 1
	p.lifetime = 0.1
	p.process_material = _drop_mat
	p.draw_pass_1 = _drop_mesh
	shown.append(p)
	for mesh: Mesh in GIBS.MESHES:
		for i in 4:  # flesh, bone, brain, a stump's end
			var m := MeshInstance3D.new()
			m.mesh = mesh
			m.material_override = GIBS.material(i)
			shown.append(m)
	for n in shown:
		world.add_child(n)
		n.global_transform = at
	p.emitting = true
	BLOOD.prewarm(world, at.origin)
	await world.get_tree().create_timer(0.3).timeout
	for n in shown:
		n.queue_free()
	# Each model's headless meshes, one a frame (the biggest takes ~70 ms to work out).
	var looks := []
	for m in MODELS:
		looks.append([MODELS[m], "Skeleton3D", "mixamorig_Head"])
	for m in CREATURES:
		looks.append([CREATURES[m].scene, CREATURES[m].skeleton, CREATURES[m].bones.Head])
	for look: Array in looks:
		var body: Node3D = look[0].instantiate()
		var sk: Skeleton3D = body.get_node(look[1])
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			if mi.skin != null and mi.mesh != null:
				headless(mi.mesh, mi.skin, sk, sk.find_bone(look[2]))
		body.free()
		if not is_instance_valid(world):
			return
		await world.get_tree().process_frame


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
	return _play_once(_pick(action))


func _play_once(clip: String) -> float:
	if _dead:
		return 0.0
	_busy = true
	_ap.speed_scale = 1.0
	_ap.play(clip, BLEND)
	return _lib.get_animation(clip).length


func _on_finished(_clip: StringName) -> void:
	if _dead or not _busy or _hold:
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
		if a == CREEP_CLIP:
			lib.add_animation("creep_a", _section(anim, CREEP_SECTION[0], CREEP_SECTION[1]))
	_libs[name] = lib
	return lib


## `anim` from `from` to `to` s as a clip of its own, played there and back (LOOP_PINGPONG).
static func _section(anim: Animation, from: float, to: float) -> Animation:
	var out := Animation.new()
	out.length = to - from
	out.loop_mode = Animation.LOOP_PINGPONG
	for t in anim.get_track_count():
		var type := anim.track_get_type(t)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var i := out.add_track(type)
		out.track_set_path(i, anim.track_get_path(t))
		var times := [from, to]
		for k in anim.track_get_key_count(t):
			var at := anim.track_get_key_time(t, k)
			if at > from and at < to:
				times.append(at)
		times.sort()
		for at: float in times:
			match type:
				Animation.TYPE_POSITION_3D:
					out.position_track_insert_key(i, at - from, anim.position_track_interpolate(t, at))
				Animation.TYPE_ROTATION_3D:
					out.rotation_track_insert_key(i, at - from, anim.rotation_track_interpolate(t, at))
				Animation.TYPE_SCALE_3D:
					out.scale_track_insert_key(i, at - from, anim.scale_track_interpolate(t, at))
	return out


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
