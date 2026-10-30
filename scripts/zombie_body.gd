extends Node3D
## One zombie's look and animation: a Mixamo model and clips from the shared library
## (assets/characters/zombies/zombie_anims.res, built by tools/build_zombies.gd). Visual only: the
## wave code moves this node and calls idle / move / attack / hit / die / scream. Faces -Z.
##
## Everything is picked from `seed`, which the host hands out with the zombie, so every peer dresses
## and animates it the same way. Clips are in place; move() matches the stride to the speed.
##   var body := ZOMBIE_BODY.new()
##   body.setup(&"walker", seed)
##   add_child(body)
## Sounds come from a zombie_voice.gd child on the head bone; die(&"head") / die(&"body") tears it
## apart (zombie_gibs.gd) instead of letting it fall whole.

const VOICE := preload("res://scripts/zombie_voice.gd")
const GIBS := preload("res://scripts/zombie_gibs.gd")
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
}
## kind -> models it wears, clip family ("" zombie, "mutant_" the creature set), its move loop,
## and its size range.
const KINDS := {
	&"walker": {"models": [&"prisoner", &"copzombie", &"warzombie", &"zombiegirl", &"parasite",
			&"yaku", &"romero", &"skeletonzombie", &"whiteclown", &"fleshzombie"],
			"set": "", "move": "walk", "size": [0.95, 1.06]},
	&"runner": {"models": [&"prisoner", &"copzombie", &"zombiegirl", &"parasite", &"yaku",
			&"skeletonzombie", &"whiteclown", &"fleshzombie"],
			"set": "", "move": "run", "size": [0.95, 1.04]},
	&"crawler": {"models": [&"prisoner", &"warzombie", &"zombiegirl", &"romero", &"skeletonzombie",
			&"fleshzombie"],
			"set": "", "move": "crawl", "size": [0.95, 1.05]},
	&"brute": {"models": [&"warrok", &"maw", &"demon"],  # already ~2.4 m
			"set": "mutant_", "move": "walk", "size": [1.0, 1.12]},
}
const BLEND := 0.25  # s of crossfade between clips
## Every shot bends the upper body away from it at once, whatever clip is playing: a spring on the
## spine (and the head, harder, for head shots) laid over the animation.
const KICK := 2.4  # rad/s per shot
const KICK_HEAD := 2.5  # times that on the head
const KICK_STIFF := 160.0  # 1/s², ~2 Hz
const KICK_DAMP := 15.0  # 1/s: one swing back and it has settled
const KICK_MAX := 0.6  # rad, so a burst can't fold it in two
const SPLATS := [
	preload("res://materials/env/decals/blood_splat_0.res"),
	preload("res://materials/env/decals/blood_splat_1.res"),
	preload("res://materials/env/decals/blood_splat_2.res"),
]
const POOL := preload("res://materials/env/decals/blood_pool_0.res")
const FLOOR_MARKS := 10  # splats one zombie leaves on the floor before its oldest is reused

var kind := &"walker"
var model := &""
var size := 1.0
var height := 1.8  # m, top of the head at this size (for hit shapes)

var _seed := 0
var _set := ""
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
var _marks: Array[Decal] = []
var _next_mark := 0
var _voice: Node3D
var _last_dir := Vector3.FORWARD  # the way the last round went, for where the pieces fly


## Lays the spring's bend over whatever the animation posed.
class Flinch extends SkeletonModifier3D:
	var bend := Vector3.ZERO
	var nod := Vector3.ZERO
	var spine: Array[int] = []
	var head := -1
	var head_gone := false

	func _process_modification() -> void:
		var sk := get_skeleton()
		for b in spine:
			_turn(sk, b, bend / spine.size())
		_turn(sk, head, nod)
		if head_gone and head >= 0:  # blown off: folded to nothing at the neck
			sk.set_bone_pose_scale(head, Vector3.ONE * 0.001)

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
	_ap.add_animation_library("", _library(model, _skel))
	_ap.animation_finished.connect(_on_finished)
	for b in ["Spine", "Spine1", "Spine2", "Neck"]:
		_flinch.spine.append(_skel.find_bone("mixamorig_" + b))
	_flinch.head = _skel.find_bone("mixamorig_Head")
	_skel.add_child(_flinch)
	_voice = VOICE.new()
	_voice.setup(kind, _seed)
	attach("Head").add_child(_voice)
	idle()


func _process(delta: float) -> void:
	_bend_v += (-KICK_STIFF * _bend - KICK_DAMP * _bend_v) * delta
	_bend = (_bend + _bend_v * delta).limit_length(KICK_MAX)
	_nod_v += (-KICK_STIFF * _nod - KICK_DAMP * _nod_v) * delta
	_nod = (_nod + _nod_v * delta).limit_length(KICK_MAX)
	_flinch.bend = _bend
	_flinch.nod = _nod


func _exit_tree() -> void:
	for d in _marks:
		if is_instance_valid(d):
			d.queue_free()


## A round went in at `at` travelling along `dir`: the body jerks away from it, blood sprays out
## the back and a little back toward the shooter, and drops land on the floor behind.
func wound(at: Vector3, dir: Vector3, head: bool) -> void:
	dir = dir.normalized()
	_last_dir = dir
	_voice.shot(at, head)
	if not _dead:
		var axis := Vector3.UP.cross(dir)
		if axis.length() > 0.01:
			axis = _skel.global_basis.orthonormalized().inverse() * axis.normalized()
			if head:
				_nod_v += axis * KICK * KICK_HEAD
			else:
				_bend_v += axis * KICK
	_spray(at, dir, 22 if head else 14, 1.0)
	_spray(at, -dir, 6, 0.5)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	_mark(at + flat * randf_range(0.4, 1.6), SPLATS.pick_random(), randf_range(0.35, 0.7) * (1.4 if head else 1.0))


## Loops one of the kind's idles (in the pen, at the gate).
func idle() -> void:
	_voice.wake()
	_play_loop(_pick("idle"), 1.0)


## Loops the kind's walk / run / crawl, its stride stretched to `speed` m/s.
func move(speed: float) -> void:
	_voice.wake()
	var clip := _pick(_move)
	var natural: float = LIB.get_animation(clip).get_meta("speed", 0.0) * _hip
	_play_loop(clip, clampf(speed / natural, 0.6, 1.8) if natural > 0.05 else 1.0)


## Swing at the fence or a player. Returns the clip's length (s).
func attack() -> float:
	_voice.attack()
	return _one_shot("attack")


## Flinch from a shot; back to the loop after. Ignored mid-attack.
func hit() -> void:
	if not _busy:
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
	var chest := _skel.to_global(_skel.get_bone_global_pose(_flinch.spine[1]).origin)
	_voice.die(head if gib == &"head" else chest, gib != &"", gib == &"head")
	if gib != &"":
		var from := head if gib == &"head" else chest
		GIBS.burst(get_parent().get_parent(), from, _last_dir, global_position.y,
				(9 if gib == &"head" else 14) + (8 if kind == &"brute" else 0), size)
		_spray(from, Vector3.UP, 40, 1.3)
		_spray(from, _last_dir, 30, 1.2)
		if gib == &"head":
			_flinch.head_gone = true
	_ap.speed_scale = 1.0
	_ap.play(clip, BLEND)
	var length := LIB.get_animation(clip).length
	_bleed_out(length * 0.7)
	return length


## Once it is down, a pool spreads under the body.
func _bleed_out(after: float) -> void:
	await get_tree().create_timer(after).timeout
	if not is_inside_tree():
		return
	var hips := _skel.to_global(_skel.get_bone_global_pose(0).origin)
	var d := _mark(hips, POOL, 0.3)
	_voice.ooze(hips)
	create_tween().tween_property(d, "size", Vector3(1.4, 0.6, 1.4) * size, 5.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)


## A blood decal on the floor under `at`, in the world (it stays put while the zombie walks on).
func _mark(at: Vector3, tex: Texture2D, width: float) -> Decal:
	var d: Decal
	if _marks.size() < FLOOR_MARKS:
		d = Decal.new()
		d.normal_fade = 0.5
		get_parent().get_parent().add_child(d)
		_marks.append(d)
	else:
		d = _marks[_next_mark]
		_next_mark = (_next_mark + 1) % FLOOR_MARKS
	d.texture_albedo = tex
	d.size = Vector3(width, 0.6, width)
	d.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), Vector3(at.x, global_position.y + 0.1, at.z))
	return d


static var _drop_mesh: QuadMesh
static var _drop_mat: ParticleProcessMaterial


func _spray(at: Vector3, dir: Vector3, amount: int, force: float) -> void:
	if _drop_mesh == null:
		var m := StandardMaterial3D.new()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_texture = SPLATS[0]
		m.albedo_color = Color(0.5, 0.03, 0.03)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.3
		m.roughness = 0.25
		_drop_mesh = QuadMesh.new()
		_drop_mesh.material = m
		_drop_mat = ParticleProcessMaterial.new()
		_drop_mat.direction = Vector3(0, 0, -1)
		_drop_mat.spread = 28.0
		_drop_mat.initial_velocity_min = 1.5
		_drop_mat.initial_velocity_max = 4.5
		_drop_mat.gravity = Vector3(0, -9.8, 0)
		_drop_mat.scale_min = 0.03
		_drop_mat.scale_max = 0.09
		_drop_mat.damping_min = 1.0
		_drop_mat.damping_max = 2.0
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 0.95
	p.speed_scale = force
	p.process_material = _drop_mat
	p.draw_pass_1 = _drop_mesh
	get_parent().get_parent().add_child(p)
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	p.global_transform = Transform3D(Basis.looking_at(dir, up), at)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Node that follows a bone, for hit shapes (the head's weak spot) or effects.
func attach(bone: String) -> BoneAttachment3D:
	var a := BoneAttachment3D.new()
	a.bone_name = "mixamorig_" + bone
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
	return LIB.get_animation(clip).length


func _on_finished(_clip: StringName) -> void:
	if _dead or not _busy:
		return
	_busy = false
	_ap.play(_loop, BLEND)
	_ap.speed_scale = _loop_speed


## The family's clips named <set><action>_*, one picked per play. Zombie actions with no mutant
## clip fall back to the zombie set and the other way round.
func _pick(action: String) -> String:
	var clips := _clips(_set + action)
	if clips.is_empty():
		clips = _clips(("" if _set != "" else "mutant_") + action)
	var n: int = _count.get(action, 0)
	_count[action] = n + 1
	return clips[_roll("%s%d" % [action, n]) % clips.size()]


static var _by_prefix := {}


static func _clips(prefix: String) -> Array:
	if not _by_prefix.has(prefix):
		var out := []
		for a in LIB.get_animation_list():
			if a.begins_with(prefix + "_") and a.trim_prefix(prefix + "_").length() == 1:
				out.append(String(a))
		_by_prefix[prefix] = out
	return _by_prefix[prefix]


func _roll(salt: String) -> int:
	return absi(hash("%d:%s" % [_seed, salt]))


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
