extends Node3D
## First-person arms and gun. One pair of arms (assets/weapons/arms, tools/build_arms.py) holds every
## gun: the guns are meshes on the same rig, each with its own clips ("<Gun>_Fire" ...), so switching
## swaps the mesh and the clip set and the gloves never change. Bare fists play their own clips on the
## same arms. We add what the clips lack: muzzle flash, smoke, ejected shells, sounds, sway, bob and
## a view kick. Lives under its own camera on render layer 2, so it never clips into walls.
# ponytail: no reload sounds yet (real recordings come from the user, synced to each Reload clip).

signal kicked(amount: float, yaw: float)  # rad of view climb, and of sideways throw

const LAYER := 2
## Per GameState.GUNS id. eye: the set's camera in our glTF space (y up, looking +Z), printed by
## build_arms.py; the clips were framed for it. bone: the gun's own bone; muzzle / port (ejection) and
## rear / front (sights, aimed by moving the whole rig) are in its space, read off the meshes at Idle.
## fov: the clips were framed for a ~34 mm lens (~33° tall); at the game's 75° the cut-off sleeves come
## into view. aim_clips: the set has its own Aim_In / Aim_Out, so aiming is the clip's job.
## Fists: an FBX on a body with shorter arms; ours keep their length, so the eye sits where theirs
## would over our shoulders (theirs: 1.4069 m over 1.2516 m shoulders).
## How each one shoots (GameState.GUNS has the rate): move is its share of the moving penalty (the
## heavy pistol worst, the Scorpion best); kick is the spring's push per round, climb and
## yaw the view's rise and sideways throw per round (rad), bloom the spread each round adds, jiggle
## the random wobble, flash the muzzle flash's size. clip_fire plays the set's Fire clip on every
## round; the SMGs fire 8-10 a second, where restarting a 0.3 s clip only stutters, so they kick
## on the spring alone, which settles inside one interval: a steady buzz that climbs. The Deagle
## is one heavy shove and flip; the UZI's heavy open bolt a regular, mostly vertical thump; the
## Scorpion lighter per round, faster, and the more it fires the more it wanders sideways.
## paint lifts the gun's colour map: the SMGs' are near black (linear 0.02-0.04, the Deagle's ~0.1)
## and in the hall they drew as a flat silhouette with none of the map's wear and parts showing.
## Kept low: at 2.5-4 the dark steel washed out into flat grey plastic.
const SETS := {
	"fists": {"mesh": "", "clips": "Fists_", "bone": "DEF-hand.R", "eye": Vector3(-0.0082, 1.4656, 0.0167), "fov": 50.0},
	"deagle": {"mesh": "Deagle", "clips": "Deagle_", "bone": "Weapon", "eye": Vector3(-0.0082, 1.4864, 0.0221), "fov": 50.0,
		"muzzle": Vector3(-0.0006, 0.0099, 0.111), "port": Vector3(-0.0202, 0.0184, -0.037),
		"rear": Vector3(0.0, 0.027, -0.09), "front": Vector3(0.0, 0.031, 0.10), "ads_eye": 0.32,
		"clip_fire": true, "move": 1.0, "kick": 0.35, "climb": 0.035, "yaw": 0.004, "bloom": 0.0032, "jiggle": 1.0, "flash": 1.0},
	"uzi": {"mesh": "UZI", "clips": "UZI_", "bone": "UZI Body", "eye": Vector3(0.0, 1.4742, 0.0221), "fov": 50.0,
		"muzzle": Vector3(0.0078, 0.0034, 0.2585), "port": Vector3(-0.018, 0.0227, 0.0396), "aim_clips": true, "paint": 1.6,
		"clip_fire": false, "move": 0.9, "kick": 0.354, "climb": 0.0106, "yaw": 0.0035, "bloom": 0.0019, "jiggle": 0.3, "flash": 0.75},
	"scorpion": {"mesh": "CZScorpion", "clips": "Scorpion_", "bone": "Scorpion Weapon", "eye": Vector3(-0.0082, 1.4864, 0.0221), "fov": 50.0,
		"muzzle": Vector3(-0.0007, 0.0102, 0.2749), "port": Vector3(-0.0325, 0.0314, 0.0339), "paint": 2.0,
		"rear": Vector3(0.0, 0.079, -0.11), "front": Vector3(0.0, 0.077, 0.13), "ads_eye": 0.34,
		"clip_fire": false, "move": 0.75, "kick": 0.26, "climb": 0.0071, "yaw": 0.0089, "bloom": 0.0013, "jiggle": 0.22, "flash": 0.65},
	# Held at the hip, no sights: the aim button spins the barrels up without firing. spin: we turn
	# the barrel bone ourselves (axis in its space, speed rad/s: the set's Fire clip turns them at
	# ~675°/s), so they keep turning over Idle, Walk and Sprint. They get up to speed in up s (Fire_Start
	# takes ~0.6 s), no round before that; the rate then ramps from first to GameState's interval
	# over ramp s of firing. Let go and they run down in down s (Fire_Stop: 1.3 s); pressing again
	# picks up from the speed they still have. walk: share of walking speed left while they turn
	# (no sprint); rumble: the gun's shake at full speed. Heaviest to move with, lightest kick per round.
	"minigun": {"mesh": "Minigun", "clips": "Minigun_", "bone": "Minigun_M-134_Body", "eye": Vector3(-0.0082, 1.4235, 0.0212), "fov": 50.0,
		"muzzle": Vector3(0.0, 0.9167, -0.0359), "port": Vector3(0.126, 0.124, -0.025), "run": "Sprint", "no_aim": true, "paint": 1.6,
		"spin": {"bone": "Minigun_M-134_Guns", "axis": Vector3.DOWN, "speed": 11.8, "up": 0.6, "down": 1.3,
			"ramp": 1.5, "first": 0.16, "walk": 0.5, "rumble": 0.25},
		"clip_fire": false, "move": 1.4, "kick": 0.12, "climb": 0.0028, "yaw": 0.0035, "bloom": 0.0009, "jiggle": 0.15, "flash": 0.8},
}
const FISTS := preload("res://assets/weapons/arms/fists.gltf")
## A spinning gun is one sound, not one per round: barrels coming up, a firing loop while rounds
## leave, the run-down when they stop (all cut from one recording).
const SPIN_START := preload("res://assets/weapons/sounds/minigun_start.wav")
const SPIN_LOOP := preload("res://assets/weapons/sounds/minigun_loop.wav")
const SPIN_STOP := preload("res://assets/weapons/sounds/minigun_stop.wav")
## Our section names (the player reports them to others) -> the set's clips.
const CLIPS := {"fire": "Fire", "reload": "Reload", "reload_empty": "Reload_Empty", "draw": "Equip", "holster": "Unequip"}
const PUNCHES := ["Punch", "Punch_2"]  # fists' "fire", taking turns
const CLIP_BLEND := 0.08  # s
## The guns' roughness maps are made for a lit studio; in the dark hall the lamp streaks spread into a
## dull sheen. A share of it sharpens them into the glints of oiled steel.
const GUN_ROUGHNESS := 0.7
const RUN_SPEED := 6.5  # m/s; faster plays Run instead of Walk
## Recoil is a spring on the whole rig: a shot gives it a kick of speed, it flies up and back and
## swings home on its own momentum with one small dip, so the kick and the return are one motion.
## Shot spacing is GameState.fire_interval, the gun's own; held, an automatic one fires at that rate.
## Recoil: the hand is shoved back and the gun flips up around the grip (the gun bone), so the
## muzzle rises most. The push springs back with one small dip past aim; the gun follows the push
## through a stiff spring, so the flip snaps up in ~40 ms and eases home.
const RECOIL_PITCH := 0.15   # rad of muzzle flip at the peak of one shot from rest
const RECOIL_BACK := 0.035   # m toward the camera at the peak
const RECOIL_UP := 0.01      # m
const RECOIL_YAW := 0.02     # rad, random side each shot
const RECOIL_ROLL := 0.035   # rad, random cant each shot
const RECOIL_DAMPING := 0.55  # below 1 leaves one small dip past aim
const RECOIL_SNAP := 90.0    # rad/s, how stiffly the gun follows the push
const RECOIL_PEAK := 0.75    # peak of the snap spring after a unit push (simulated; RECOIL_SNAP 90, 0.38 s settle)
const RECOIL_SETTLE := 0.45  # s to settle at slow fire rates; faster ones settle before the next shot
const FIRE_BUFFER := 0.15    # s an early click waits for the gun to be ready
const RELOAD_BUFFER := 0.6   # s an R pressed during a shot waits for the gun
const SWAY := 0.000008     # m per px/s of mouse speed
const SWAY_MAX := 0.018
const BOB_AMP := Vector2(0.01, 0.007)
const BOB_ROLL := 0.012    # rad the gun rocks with each step
## Jelly: an underdamped spring on the gun's angle and position around the wrist, so it lags
## turns, leans into strafes, rides jumps and wobbles past rest instead of sitting on the screen.
const JELLY_OMEGA := 11.0     # rad/s, ~1.8 wobbles a second
const JELLY_DAMPING := 0.25   # below 1 overshoots; lower wobbles longer
const SWAY_ROT := Vector3(0.00006, 0.000075, 0.00005)  # rad per px/s of mouse speed: pitch, yaw, roll
const SWAY_ROT_MAX := 0.15
const STRAFE_ROLL := 0.0125   # rad per m/s sideways
const AIR_LIFT := 0.003       # m per m/s of vertical speed: up on the jump, down on the fall
const AIR_LIFT_MAX := 0.02
const AIR_PITCH := 0.0125     # rad of muzzle rise per m/s of vertical speed
const AIR_PITCH_MAX := 0.075
const LAND_DIP := 0.06        # m/s of downward shove per m/s of landing speed
const LAND_TILT := 0.15       # rad/s of muzzle dip per m/s of landing speed
const FIRE_JIGGLE := Vector3(0.6, 0.8, 1.1)  # rad/s of random wobble a shot adds: pitch, yaw, roll
## Where the shot goes follows a share of the jelly, and spreads from the hip while moving or
## shooting fast; standing still (or aimed) it stays dead on. The crosshair draws both.
const AIM_FOLLOW := 0.35      # share of the gun's sway the shot (and the dot) takes
## Shooting fast blooms the cone (SETS bloom); it fades at SPREAD_RECOVER.
## Moving costs accuracy (2026-10-22; it used to cost almost none, so walking and shooting lost
## nothing): the cone widens with ground speed, wider still sprinting and in the air, and once the
## feet stop the hands settle back in STEADY_TIME. Stop, aim, fire is the rhythm that pays, and
## tapping the opposite key to stop dead pays sooner. Aimed, MOVE_ADS of it is left (and the player
## walks slower, player.gd ADS_WALK). Each gun takes its own share of it (SETS move).
const SPREAD_MOVE := 0.026    # rad cone half-angle at walking speed (5 m/s), hip; ~1.5°
const SPREAD_AIR := 0.05      # rad in the air
const STEADY_TIME := 0.2      # s for the hands to settle once the feet stop
const UNSTEADY_TIME := 0.05   # s for moving to throw the aim off
const MOVE_ADS := 0.4         # share of the movement spread left when aimed
const SPREAD_RECOVER := 0.015 # rad/s
const SPREAD_ADS := 0.15      # share left when aimed
const BREATH := Vector2(0.0008, 0.0012)  # m; the model's own idle clip bobs too fast
const ADS_TIME := 0.18     # s to bring the sights up (and to drop them)
const ADS_STEADY := 0.2    # share of sway, bob and breath left when aimed
const ADS_RECOIL := 0.8    # share of the gun's kick when aimed (braced with both hands)
const ADS_CLIPS := ["", "fire"]  # rest pose only: reloads and the draw drop the sights
## Placing gear the gun goes away: it dips around the wrist and sinks out of view, then hides;
## the arms are one rig, so any pose that keeps them on screen leaves a hand hanging in the air.
const LOW_ROT := Vector3(-0.5, 0.0, 0.15)  # euler (pitch, yaw, roll) at the bottom
const LOW_POS := Vector3(0.0, -0.3, 0.05)  # m, down and a little back
const LOW_TIME := 0.25  # s down, and back up
const SHELL_POOL := 20
const TINK_EVERY := Vector2i(10, 15)  # inside a burst, one shell clinks every this many
const TINK_GAP := 1.5   # s without a shot before the next one counts as a lone shot
const TINK_TAIL := 0.3  # s after landing with no newer shot: it was the burst's last shell
const MUZZLE_FX := preload("res://scenes/muzzle_fx.tscn")
const MUZZLE_FX_POOL := 3
const WISP_TIME := 1.6  # s for a hot barrel's smoke to thin out to nothing
const FLASH_TIME := 0.05  # s

var body: CharacterBody3D  # set via setup(); drives bob and keeps shells off the capsule
## Vertical fov (degrees) the gun's own camera draws it at, before the aim zoom; 0 follows the
## player's camera. A gun animated for a narrower lens shows its cut-off sleeves wider than that.
var view_fov := 0.0

## GameState.GUNS index in hand (-1 before the first draw), and its SETS entry.
var gun := -1
var _kit := {}
var _want_gun := 0  # drawn once the one in hand is put away
var _clip := ""
var _punch := 0
var _burst := 0  # rounds in the current burst
## Spinning guns (SETS spin): barrel speed 0 stopped → 1 up to speed, the fire rate's ramp 0 → 1,
## and how far the barrels have turned (rad).
var spin := 0.0
var _ramp := 0.0
var _barrel := 0.0
var walk_share: float:  # of walking speed, while barrels turn (the player reads it)
	get: return lerpf(1.0, float(_kit.spin.walk), spin) if _kit.has("spin") else 1.0
var _aim_pose := false  # aim_clips: holding Aim_In's end
var _attach: BoneAttachment3D  # rides the gun bone: muzzle and ejection port hang off it
var _since_fire := 10.0
var _want_fire := 0.0  # s left on a buffered click
var _want_reload := 0.0
var wheel_used := false  # this R press opened the ammo wheel (player.gd): letting go is no reload
var _was_captured := false  # the click that recaptures the mouse must not also shoot
var clip: String:  # the section playing ("" at rest), so the player can tell others
	get: return _clip
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
var _pivot: Vector3  # the grip in our own space: recoil and sway turn about it
var _sway := Vector3.ZERO
var _sway_target := Vector3.ZERO
var _mouse := Vector2.ZERO  # mouse travel since the last frame
var _mouse_vel := Vector2.ZERO  # px/s, smoothed
var _jelly_rot := Vector3.ZERO  # euler, rad
var _jelly_rot_vel := Vector3.ZERO
var _jelly_pos := Vector3.ZERO
var _jelly_pos_vel := Vector3.ZERO
var _low_lin := 0.0  # 0 up and live, 1 at low ready (placement mode); linear
var _lowered := 0.0  # the same, eased
var _fall_speed := 0.0  # m/s down on the last airborne frame
var aim_offset := Vector2.ZERO  # rad (yaw left, pitch up) the shot leaves the screen centre by
var spread := 0.0  # rad, cone half-angle of the next shot
var _bloom := 0.0  # rad of spread from recent shots
var _unsteady := 0.0  # rad of spread from moving, settling after the feet stop
var _was_on_floor := true
var _bob := 0.0
var _time := 0.0
var _shells: Array[RigidBody3D] = []
var _next_shell := 0
var _shot_no := 0          # shells thrown so far; a landed shell checks whether it was the last
var _last_eject_ms := -100000
var _tink_in := 0          # shells left until the next one clinks inside a burst
var _muzzle_fx: Array[Node3D] = []  # powder jet, curling smoke and sparks
var _next_muzzle_fx := 0
var _barrel_heat := 0.0  # 1 right after a shot, 0 when the barrel stops smoking
var _wisp_pm: ParticleProcessMaterial
var _flash_left := 0.0
var _flash_frames := 0
var _dry_armed := true  # an empty gun clicks once per trigger pull, not once per frame held
var _world_flash: OmniLight3D  # the gun lives in its own world; this one lights the shed

@onready var _model: Node3D = $Model
@onready var _anim: AnimationPlayer = $Model/AnimationPlayer
@onready var _skel: Skeleton3D = _model.find_child("Skeleton3D", true, false)
@onready var _muzzle := Node3D.new()
@onready var _port := Node3D.new()
@onready var _flash: Node3D = $Flash
@onready var _flash_light: OmniLight3D = $Flash/Light
@onready var _shot_sound: AudioStreamPlayer3D = $ShotSound
@onready var _dry_sound: AudioStreamPlayer3D = $DrySound
@onready var _slide_sound: AudioStreamPlayer3D = $SlideSound
@onready var _mag_sound: AudioStreamPlayer3D = $MagSound
@onready var _spin_sound: AudioStreamPlayer3D = _shot_sound.duplicate()  # same place and loudness as a shot
@onready var _wisp: GPUParticles3D = $Wisp  # hot barrel: a cigarette-thin trail plume from the muzzle


func _ready() -> void:
	add_to_group("first_person_gun")
	add_child(_spin_sound)
	_spin_sound.max_polyphony = 1
	var loop: AudioStreamWAV = SPIN_LOOP
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD  # the file's end is crossfaded into its start
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	# The import auto-generates LODs and the arms are skinned: Godot judges their distance off the
	# rest pose and draws the hands as a coarse blob. The gun is always at arm's length; full detail.
	get_viewport().mesh_lod_threshold = 0.0
	# Barrel smoke lives in the camera's space: left in the world the threads hung in the air for
	# seconds; stuck to the gun bone the whole plume swung with the gun and cut through it. Here it
	# keeps on screen as the view turns, the gun swings out of it, and each frame the emitter is put
	# on the muzzle tip (_wisp_follow), so new smoke always leaves the opening and rises world-up.
	_wisp.local_coords = true
	_wisp.amount = 36  # many faint, fine threads braid into one plume, like the reference
	_wisp.lifetime = 1.2
	_wisp.trail_lifetime = 0.5
	var pm := _wisp.process_material.duplicate() as ParticleProcessMaterial
	pm.initial_velocity_min = 0.06
	pm.initial_velocity_max = 0.12
	pm.inherit_velocity_ratio = 0.0  # a turning view would throw it sideways through the gun
	pm.turbulence_noise_strength = 1.4  # curls, but doesn't blow back down the barrel
	pm.turbulence_noise_scale = 0.9
	_wisp.process_material = pm
	_wisp_pm = pm
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
	_flash_light.light_cull_mask = 1 << (LAYER - 1)  # the hall gets its own flash (_world_flash)
	_anim.animation_finished.connect(_on_clip_finished.unbind(1))
	_anim.mixer_applied.connect(_turn_barrels)
	_attach = BoneAttachment3D.new()
	_skel.add_child(_attach)
	_attach.add_child(_muzzle)
	_attach.add_child(_port)
	_wisp.reparent.call_deferred(get_parent(), false)  # the camera; still setting up its children
	load_clips(_anim, _skel)
	for g: Dictionary in GameState.GUNS:
		assert(not g.ready or SETS.has(g.id), "GameState.GUNS %s is ready but has no SETS entry" % g.id)
	for each: Dictionary in SETS.values():
		if each.mesh != "":
			var mi: MeshInstance3D = _skel.get_node(NodePath(each.mesh))
			for i in mi.mesh.get_surface_count():
				var steel := mi.mesh.surface_get_material(i).duplicate() as StandardMaterial3D
				steel.roughness *= GUN_ROUGHNESS
				var k: float = each.get("paint", 1.0)
				steel.albedo_color = Color(k, k, k)
				mi.set_surface_override_material(i, steel)
	if Wishlist.golden():
		gild()


## The wishlist reward (scripts/wishlist.gd): the Deagle in gold. Also called on the claim.
func gild() -> void:
	Wishlist.gild(_skel.get_node(NodePath(SETS.deagle.mesh)))


## The sets' clips only key the bones they move; a bone left out would keep the last clip's pose
## (a gun's pose under the fists). Each clip gets every bone: its own set's rest turn, our rest
## place and size (the fists' shorter arms keep our length). The fists' clips come from their own
## file onto the same arms. Shared by every copy of the arms (the remote players' too); done once.
static func load_clips(anim: AnimationPlayer, skel: Skeleton3D) -> void:
	var lib := anim.get_animation_library("")
	if lib.has_meta("filled"):
		return
	lib.set_meta("filled", true)
	var fists: Node = FISTS.instantiate()
	var their: Skeleton3D = fists.find_child("Skeleton3D", true, false)
	var their_lib := (fists.find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation_library("")
	for n in their_lib.get_animation_list():
		lib.add_animation(n, their_lib.get_animation(n))
	var at := str(anim.get_node(anim.root_node).get_path_to(skel)) + ":"
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		var rest_of := their if n.begins_with("Fists_") else skel
		for b in skel.get_bone_count():
			var bone := skel.get_bone_name(b)
			var path := NodePath(at + bone)
			var rb := rest_of.find_bone(bone)
			var rot := (rest_of.get_bone_rest(rb) if rb >= 0 else skel.get_bone_rest(b)).basis.get_rotation_quaternion()
			for kind: int in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				if a.find_track(path, kind) >= 0:
					continue
				var t := a.add_track(kind)
				a.track_set_path(t, path)
				match kind:
					Animation.TYPE_POSITION_3D: a.position_track_insert_key(t, 0.0, skel.get_bone_rest(b).origin)
					Animation.TYPE_ROTATION_3D: a.rotation_track_insert_key(t, 0.0, rot)
					Animation.TYPE_SCALE_3D: a.scale_track_insert_key(t, 0.0, skel.get_bone_rest(b).basis.get_scale())
		# Only these loop; any other clip must end, or the gun would wait on it forever.
		var loops := n.ends_with("_Idle") or n.ends_with("_Walk") or n.ends_with("_Run") or n.ends_with("_Sprint")
		a.loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
	fists.free()


## Puts the one in hand away (its Unequip clip) and draws GameState.GUNS[`i`]; the player calls
## it when the gun in hand changes (GameState.gun_changed).
func equip(i: int) -> void:
	_want_gun = i
	if gun == -1:
		_swap()
	elif _clip != "holster" and _want_gun != gun:
		_play("holster")


## Shows the wanted gun's mesh on the arms and stands the arms where its clips were framed.
func _swap() -> void:
	gun = _want_gun
	_kit = SETS[GameState.GUNS[gun].id]
	for each: Dictionary in SETS.values():
		if each.mesh != "":
			(_skel.get_node(NodePath(each.mesh)) as Node3D).visible = each == _kit
	var eye: Vector3 = _kit.eye
	_model.transform = Transform3D(Basis(Vector3.UP, PI), Basis(Vector3.UP, PI) * -eye)
	view_fov = _kit.fov
	_attach.bone_name = _kit.bone
	_muzzle.position = _kit.get("muzzle", Vector3.ZERO)
	_port.position = _kit.get("port", Vector3.ZERO)
	_aim_pose = false
	spin = 0.0
	_ramp = 0.0
	_spin_sound.stop()
	_want_fire = 0.0  # a click or R from before the swap is not for this gun
	_want_reload = 0.0
	_anim.play(_kit.clips + "Idle")
	_anim.seek(0.0, true)
	_anim.advance(0.0)  # seek alone does not pose the rig before the first frame
	_measure_sights()
	_play("draw")


## Where `at` (in the gun bone's space) is now, in our own space.
func _on_gun(at: Vector3) -> Vector3:
	var bone := _skel.find_bone(_kit.bone)
	return global_transform.affine_inverse() * (_skel.global_transform * _skel.get_bone_global_pose(bone) * at)


## Aiming moves and turns the whole rig so the line from the rear sight over the front one runs down
## the view axis, level: the front sight then sits exactly on the screen centre, where shots land.
## Sets with their own aim clips (aim_clips) and the fists leave the rig where it is.
func _measure_sights() -> void:
	_pivot = _on_gun(Vector3.ZERO)
	_ads_pos = Vector3.ZERO
	_ads_rot = Quaternion.IDENTITY
	if not _kit.has("rear"):
		return
	var rear := _on_gun(_kit.rear)
	var front := _on_gun(_kit.front)
	var up := _on_gun(_kit.rear + Vector3.UP) - rear
	var z := (rear - front).normalized()  # the gun's own back
	var x := up.cross(z).normalized()
	_ads_rot = Basis(x, z.cross(x), z).get_rotation_quaternion().inverse()
	_ads_pos = Vector3(0.0, 0.0, -float(_kit.ads_eye)) - _ads_rot * rear


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


## Where shots visibly leave the gun: tracers and the world's flash start here.
func muzzle_position() -> Vector3:
	return in_view(_muzzle.global_position)


## The gun is drawn by its own camera at its own fov (view_fov), narrower than the player's: a point
## on it shows on screen somewhere else than the same point seen by the player's camera, nearer the
## centre, so a tracer from the true muzzle seemed to come out of the hand. This is the point the
## player's camera shows at the gun's spot on screen, at the same depth.
func in_view(at: Vector3) -> Vector3:
	var own := get_parent() as Camera3D
	var theirs := body.get_node("Head/Camera3D") as Camera3D if body else null
	if not theirs or is_equal_approx(own.fov, theirs.fov):
		return at
	var k := tan(deg_to_rad(theirs.fov) * 0.5) / tan(deg_to_rad(own.fov) * 0.5)
	var local := own.global_transform.affine_inverse() * at
	return own.global_transform * Vector3(local.x * k, local.y * k, local.z)


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
	# Placing gear (B): left click puts it up and R turns it (scripts/placement.gd), so the gun goes
	# to low ready, and is only live again once it is all the way back up.
	var placing := GameState.player().placing
	_low_lin = move_toward(_low_lin, 1.0 if placing else 0.0, delta / LOW_TIME)
	_lowered = smoothstep(0.0, 1.0, _low_lin)
	var live := _low_lin == 0.0
	if captured and _was_captured and live:
		if Input.is_action_just_pressed("fire") or (Input.is_action_pressed("fire") and GameState.GUNS[maxi(gun, 0)].auto):
			_want_fire = FIRE_BUFFER
		# With special rounds in the pocket R is a tap or a hold: the tap reloads when let go, the
		# hold opens the ammo wheel (player.gd, ammo_wheel.gd) and loads what it picks instead.
		elif GameState.player().specials.is_empty() and Input.is_action_just_pressed("reload"):
			_want_reload = RELOAD_BUFFER
		elif Input.is_action_just_released("reload"):
			if not wheel_used and not GameState.player().specials.is_empty():
				_want_reload = RELOAD_BUFFER
			wheel_used = false
	_was_captured = captured
	var want_aim := captured and live and gun > 0 and Input.is_action_pressed("aim") and _clip in ADS_CLIPS
	if _kit.has("spin"):
		_spin(delta, want_aim)
	if _kit.get("no_aim", false):
		want_aim = false  # no sights (the minigun's aim button only turns the barrels)
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
	_rest_clip()
	_flash.global_transform = _muzzle.global_transform.orthonormalized()
	if _barrel_heat > 0.0:  # the barrel cools: the thread thins out over WISP_TIME
		_barrel_heat = maxf(_barrel_heat - delta / WISP_TIME, 0.0)
		_wisp.amount_ratio = _barrel_heat
		_wisp.emitting = _barrel_heat > 0.0
	_sway_and_bob(delta)
	if _barrel_heat > 0.0:
		_wisp_follow()


## Puts the smoke's emitter on the muzzle tip as the gun sits this frame, in the camera's space,
## a little past the opening so it never starts inside the barrel; it rises world-up.
func _wisp_follow() -> void:
	var to_cam := (get_parent() as Node3D).global_transform.affine_inverse()
	_wisp_pm.emission_shape_offset = to_cam * (_muzzle.global_transform * Vector3(0.0, 0.0, 0.015))
	var up := (to_cam.basis * Vector3.UP).normalized()
	_wisp_pm.direction = up
	_wisp_pm.gravity = up * 0.08  # hot gas rises slowly


## Barrels turn while the trigger or the aim button is held at rest (a reload or a draw lets
## them run down). Up to speed, holding the trigger ramps the rate; let go, the ramp falls back.
func _spin(delta: float, aim_held: bool) -> void:
	var s: Dictionary = _kit.spin
	var firing := _want_fire > 0.0 or Input.is_action_pressed("fire") and _was_captured
	var turning := (firing or aim_held) and _clip in ADS_CLIPS and _low_lin == 0.0
	if turning and spin == 0.0:
		_spin_play(SPIN_START)
	elif _spin_sound.stream == SPIN_LOOP and _spin_sound.playing and _since_fire > _interval() * 1.5:
		_spin_play(SPIN_STOP)  # rounds stopped leaving
	spin = move_toward(spin, 1.0 if turning else 0.0, delta / float(s.up if turning else s.down))
	_ramp = move_toward(_ramp, 1.0 if firing and spin == 1.0 else 0.0, delta / float(s.ramp))
	_barrel = fmod(_barrel + spin * float(s.speed) * delta, TAU)
	_jelly_rot_vel += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * float(s.rumble) * spin * delta * 60.0


func _spin_play(what: AudioStream) -> void:
	_spin_sound.stream = what
	_spin_sound.play()


## After the clip has posed the rig: the barrels' turn on top of it.
func _turn_barrels() -> void:
	if _kit.has("spin") and _barrel != 0.0:
		var b := _skel.find_bone(_kit.spin.bone)
		_skel.set_bone_pose_rotation(b, _skel.get_bone_pose_rotation(b) * Quaternion(_kit.spin.axis, _barrel))


## s between rounds now: the gun's own, or a spinning gun's ramp toward it.
func _interval() -> float:
	if _kit.has("spin"):
		return lerpf(float(_kit.spin.first), GameState.fire_interval, _ramp)
	return GameState.fire_interval


func _can_fire() -> bool:
	if gun == 0:
		return _clip == ""  # a punch plays out before the next
	if _kit.has("spin") and spin < 1.0:
		return false  # no round until the barrels are up to speed
	return gun > 0 and (_clip == "" or _clip == "fire") and _since_fire >= _interval()


func fire() -> void:
	if not _can_fire():
		return
	if gun == 0:  # bare fists throw a punch, nothing leaves
		_punch = (_punch + 1) % PUNCHES.size()
		_play("fire")
		return
	if GameState.loaded <= 0:
		if _dry_armed:
			_dry_armed = false
			_dry_sound.play()
		if GameState.carried > 0:
			reload()
		return
	var cam := get_viewport().get_camera_3d()
	var cone := Vector2.from_angle(randf() * TAU) * spread * sqrt(randf())  # uniform over the disc
	var off := aim_offset + cone
	if not GameState.request_fire(cam.global_position, cam.global_basis * Basis.from_euler(Vector3(off.y, off.x, 0.0)) * Vector3.FORWARD):
		return
	# A burst: rounds within two intervals of each other; the Scorpion wanders more the longer it runs.
	_burst = _burst + 1 if _since_fire < _interval() * 2.0 else 0
	_bloom += float(_kit.bloom)
	_kick_yaw = randf_range(-1.0, 1.0)
	_kick_roll = randf_range(-1.0, 1.0)
	_since_fire = 0.0
	_add_kick(float(_kit.kick) * (ADS_RECOIL if aim > 0.5 else 1.0))
	_jelly_rot_vel += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * FIRE_JIGGLE * float(_kit.jiggle)
	# Aimed through an aim clip, the gun stays on the sights: the Fire clip is hip-fired and would drop them.
	if _kit.clip_fire and not _aim_pose:
		_play("fire")
	_effects()
	var wander := 1.0 + minf(_burst, 20) * 0.08
	kicked.emit(float(_kit.climb) * randf_range(0.8, 1.2), float(_kit.yaw) * randf_range(-1.0, 1.0) * wander)


func _can_reload() -> bool:
	return gun > 0 and _clip == ""


## The ammo wheel loaded a special round (or took it back out): the hands go through a reload.
func load_round() -> void:
	if _can_reload():
		_play("reload")


func reload() -> void:
	if not _can_reload():
		return
	var empty := GameState.loaded == 0
	if GameState.request_reload() == 0:
		return
	_play("reload_empty" if empty else "reload")


func _play(clip: String) -> void:
	_clip = clip
	_aim_pose = false
	var name: String = PUNCHES[_punch] if gun == 0 and clip == "fire" else CLIPS[clip]
	_anim.play(_kit.clips + name, CLIP_BLEND)
	_anim.seek(0.0, true)  # a second shot before the first ends restarts it


## Shoves the hand so the gun alone would peak at `amount` (1 = one shot).
func _add_kick(amount: float) -> void:
	_push += amount / RECOIL_PEAK


## Back to Idle / Walk / Run (_rest_clip); a finished put-away draws the next gun.
func _on_clip_finished() -> void:
	if _clip == "holster":
		_swap()
	else:
		_clip = ""


## At rest: Aim_In / Aim_Out on the right button (aim_clips), else Idle, Walk or Run by speed.
func _rest_clip() -> void:
	if _clip != "" or _kit.is_empty():
		return
	if _kit.get("aim_clips", false):
		var want_aim := _aim_lin > 0.0
		if want_aim != _aim_pose:
			_aim_pose = want_aim
			_anim.play(_kit.clips + ("Aim_In" if want_aim else "Aim_Out"), CLIP_BLEND)
			return
		if _aim_pose or (_anim.is_playing() and _anim.current_animation == _kit.clips + "Aim_Out"):
			return
	var speed := Vector2(body.velocity.x, body.velocity.z).length() if body else 0.0
	var idle := "Idle"
	# Firing on the run drops the Run carry (muzzle up) for Walk: the gun levels, the bob still swings it.
	var shooting := _since_fire < 0.35
	if body and body.is_on_floor() and speed > 0.5:
		idle = _kit.get("run", "Run") if speed > RUN_SPEED and not shooting else "Walk"
	if _anim.current_animation != _kit.clips + idle:
		_anim.play(_kit.clips + idle, 0.1 if shooting else 0.25)


func _effects() -> void:
	_flash.visible = true
	var quads: Node3D = $Flash/Quads
	quads.rotation.z = randf() * TAU
	quads.scale = Vector3(randf_range(0.85, 1.3), randf_range(0.85, 1.3), randf_range(0.9, 1.5)) * float(_kit.flash)
	_flash_light.light_energy = randf_range(4.0, 6.0)
	# Same coordinates in both worlds: the gun camera copies the player camera every frame.
	_world_flash.global_position = muzzle_position()
	_world_flash.light_energy = _flash_light.light_energy
	_world_flash.omni_range = 8.0
	_world_flash.visible = true
	_flash_left = FLASH_TIME
	_flash_frames = 2
	if not _kit.has("spin"):
		_shot_sound.play()
	elif _spin_sound.stream != SPIN_LOOP or not _spin_sound.playing:
		_spin_play(SPIN_LOOP)
	var fx := _muzzle_fx[_next_muzzle_fx]
	_next_muzzle_fx = (_next_muzzle_fx + 1) % MUZZLE_FX_POOL
	fx.global_transform = _muzzle.global_transform.orthonormalized().translated_local(Vector3(0.0, 0.0, 0.015))  # past the opening
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
	s.global_transform = Transform3D(Basis(cam.x, PI / 2.0) * cam, in_view(_port.global_position))
	s.reset_physics_interpolation()  # a teleport, not a move: don't draw it sliding from the floor
	var inherit := body.velocity if body else Vector3.ZERO
	s.linear_velocity = inherit + cam.x * randf_range(1.0, 1.5) + cam.y * randf_range(1.2, 1.7) + cam.z * randf_range(0.0, 0.6)
	s.angular_velocity = Vector3(randf_range(-30, 30), randf_range(-30, 30), randf_range(-30, 30))
	s.set_meta("landed", false)
	s.set_meta("audible", _shell_audible())
	s.set_meta("shot", _shot_no)
	s.angular_damp = 3.0
	s.linear_damp = 0.0
	s.visible = true


## Shell drops, the way shooters thin them out: a lone shot always clinks, inside a burst only
## every TINK_EVERY-th shell does, and the burst's last one clinks once firing stops. Every shell
## clinking at 143 rounds a minute turns into a tiring high-pitched rattle.
func _shell_audible() -> bool:
	var now := Time.get_ticks_msec()
	var lone := now - _last_eject_ms > TINK_GAP * 1000.0
	_last_eject_ms = now
	_shot_no += 1
	_tink_in -= 1
	if lone or _tink_in <= 0:
		_tink_in = randi_range(TINK_EVERY.x, TINK_EVERY.y)
		return true
	return false


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
			t.volume_db = lerpf(-20.0, -12.0, clampf(speed / 4.0, 0.0, 1.0))
			if s.get_meta("audible"):
				t.play()
			else:  # the burst's last shell: still no newer shot a moment after it lands
				var shot: int = s.get_meta("shot")
				get_tree().create_timer(TINK_TAIL).timeout.connect(func() -> void:
					if shot == _shot_no:
						t.play()))
	s.add_collision_exception_with(body)
	return s


## Mouse sway goes through two smoothing stages: raw per-frame motion is uneven (mice report
## at their own rate), and a single stage still shows that as jitter.
func _sway_and_bob(delta: float) -> void:
	_time += delta
	var mv := _mouse / maxf(delta, 0.001)
	var m := mv * SWAY
	_mouse = Vector2.ZERO
	_mouse_vel = _mouse_vel.lerp(mv, 1.0 - exp(-delta * 10.0))
	# Lags the turn: swing right and the muzzle trails left, cants, then wobbles back past centre.
	var rot_target := Vector3(_mouse_vel.y * SWAY_ROT.x, _mouse_vel.x * SWAY_ROT.y, _mouse_vel.x * SWAY_ROT.z).clampf(-SWAY_ROT_MAX, SWAY_ROT_MAX)
	var pos_target := Vector3.ZERO
	if body:
		var local_v := (get_parent() as Node3D).global_basis.inverse() * body.velocity
		rot_target.z -= local_v.x * STRAFE_ROLL  # leans into the strafe
		pos_target.y = clampf(body.velocity.y * AIR_LIFT, -AIR_LIFT_MAX, AIR_LIFT_MAX)
		rot_target.x += clampf(body.velocity.y * AIR_PITCH, -AIR_PITCH_MAX, AIR_PITCH_MAX)
		var on_floor := body.is_on_floor()
		if not on_floor:
			_fall_speed = maxf(-body.velocity.y, 0.0)
		elif not _was_on_floor and _fall_speed > 1.0:  # landing: shoved down, muzzle dips, bounces back
			_jelly_pos_vel.y -= _fall_speed * LAND_DIP
			_jelly_rot_vel.x -= _fall_speed * LAND_TILT
		_was_on_floor = on_floor
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
			rot_target.z += sin(_bob) * BOB_ROLL * minf(speed / 5.0, 1.6)
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
		_jelly_rot_vel += (-JELLY_OMEGA * JELLY_OMEGA * (_jelly_rot - rot_target) - 2.0 * JELLY_DAMPING * JELLY_OMEGA * _jelly_rot_vel) * h
		_jelly_rot += _jelly_rot_vel * h
		_jelly_pos_vel += (-JELLY_OMEGA * JELLY_OMEGA * (_jelly_pos - pos_target) - 2.0 * JELLY_DAMPING * JELLY_OMEGA * _jelly_pos_vel) * h
		_jelly_pos += _jelly_pos_vel * h
	var steady := lerpf(1.0, ADS_STEADY, aim)
	# Aimed, the shot goes where the sights point; from the hip only a share of the sway.
	aim_offset = Vector2(_jelly_rot.y, _jelly_rot.x) * steady * lerpf(AIM_FOLLOW, 1.0, aim)
	_bloom = maxf(_bloom - SPREAD_RECOVER * dt, 0.0)
	var move := 0.0
	if body:
		move = SPREAD_AIR if not body.is_on_floor() else SPREAD_MOVE * minf(Vector2(body.velocity.x, body.velocity.z).length() / 5.0, 1.6)
	_unsteady = lerpf(_unsteady, move, 1.0 - exp(-dt / (UNSTEADY_TIME if move > _unsteady else STEADY_TIME / 3.0)))
	spread = _unsteady * float(_kit.get("move", 1.0)) * lerpf(1.0, MOVE_ADS, aim) + _bloom * lerpf(1.0, SPREAD_ADS, aim)
	var jb := Basis.from_euler(_jelly_rot * steady)
	var jelly := Transform3D(jb, _pivot - jb * _pivot + _jelly_pos * steady)
	var kick := _kick * lerpf(1.0, ADS_RECOIL, aim)
	# In the gun's own frame, around the wrist: when aimed the front post jumps above the notch.
	var flip := Basis.from_euler(Vector3(RECOIL_PITCH, RECOIL_YAW * _kick_yaw, RECOIL_ROLL * _kick_roll) * kick)
	var recoil := Transform3D(flip, _pivot - flip * _pivot + Vector3(0.0, RECOIL_UP, RECOIL_BACK) * kick)
	# Put away for placing: the muzzle dips and the whole rig sinks below the screen.
	visible = _lowered < 0.98
	var lb := Basis.from_euler(LOW_ROT * _lowered)
	var low := Transform3D(lb, _pivot - lb * _pivot + LOW_POS * _lowered)
	transform = Transform3D(Basis(Quaternion.IDENTITY.slerp(_ads_rot, aim)), _ads_pos * aim + _base) * low * jelly * recoil


## Spring frequency: settles (to ~2%) in RECOIL_SETTLE, or before the next shot if that is sooner.
func _kick_omega() -> float:
	return 4.0 / (RECOIL_DAMPING * minf(GameState.fire_interval * 0.9, RECOIL_SETTLE))
