extends SceneTree
## Bakes Quaternius Universal Animation Library clips onto the bumstrum operator skeleton, so the
## operator's own bone names and rests stay untouched (remote_players.gd poses those bones by name).
##   Godot.exe --headless --path . -s res://tools/retarget_ual.gd
## Output: assets/characters/animations/operator_anims.res, an AnimationLibrary whose tracks are
## relative to the operator scene root (give the AnimationPlayer root_node = the operator instance).
##
## Per bone, in skeleton space: target = D * C * target_rest, where D is the source bone's turn away
## from its own rest this frame and C is a fixed swing that lines the operator's rest bone up with
## the source's rest bone (Quaternius rests in a T-pose, the operator in an A-pose). Only the hips
## move, scaled by hip height; everything else is rotation.
# ponytail: swing-only correction, no twist matching; good enough at third-person distance.

const SRC := "res://assets/characters/animations/ual_standard.glb"
const DST := "res://assets/characters/operator/operator.gltf"
const OUT := "res://assets/characters/animations/operator_anims.res"
const FPS := 30.0
## Source clip -> name in the library.
const CLIPS := {
	"Idle": "idle", "Walk": "walk", "Jog_Fwd": "jog", "Sprint": "sprint",
	"Jump_Start": "jump_start", "Jump": "jump", "Jump_Land": "jump_land",
	"Pistol_Idle": "pistol_idle", "Pistol_Reload": "pistol_reload", "Pistol_Shoot": "pistol_shoot",
	"Pistol_Aim_Up": "pistol_aim_up", "Pistol_Aim_Neutral": "pistol_aim_neutral",
	"Pistol_Aim_Down": "pistol_aim_down", "Hit_Chest": "hit",
}
## operator bone: [source bone, operator child for the rest direction ("" = take the parent's swing)]
const MAP := {
	"hips_01": ["DEF-hips", "spine_012"],
	"spine_012": ["DEF-spine.001", "chest_013"],
	"chest_013": ["DEF-spine.003", "neck_061"],
	"neck_061": ["DEF-neck", "head_062"],
	"head_062": ["DEF-head", ""],
	"L_leg_02": ["DEF-thigh.L", "L_knee_03"], "L_knee_03": ["DEF-shin.L", "L_ankle_04"],
	"L_ankle_04": ["DEF-foot.L", "L_foot_05"], "L_foot_05": ["DEF-toe.L", "L_toes_06"],
	"R_leg_07": ["DEF-thigh.R", "R_knee_08"], "R_knee_08": ["DEF-shin.R", "R_ankle_09"],
	"R_ankle_09": ["DEF-foot.R", "R_foot_010"], "R_foot_010": ["DEF-toe.R", "R_toes_011"],
	"L_shoulder_014": ["DEF-shoulder.L", "L_arm_015"], "L_arm_015": ["DEF-upper_arm.L", "L_elbow_016"],
	"L_elbow_016": ["DEF-forearm.L", "L_wrist_017"], "L_wrist_017": ["DEF-hand.L", "L_middle1_026"],
	"R_shoulder_038": ["DEF-shoulder.R", "R_arm_039"], "R_arm_039": ["DEF-upper_arm.R", "R_elbow_040"],
	"R_elbow_040": ["DEF-forearm.R", "R_wrist_041"], "R_wrist_041": ["DEF-hand.R", "R_middle1_049"],
}
## Fingers: operator segments 1-3 <- source .01-.03; segment 4 is the tip, left at rest.
const FINGERS := {"thumb": "thumb", "point": "f_index", "middle": "f_middle", "ring": "f_ring", "pink": "f_pinky"}
## Source bones with several children: the one their rest direction points at.
const SRC_CHILD := {
	"DEF-hips": "DEF-spine.001", "DEF-spine.003": "DEF-neck",
	"DEF-hand.L": "DEF-f_middle.01.L", "DEF-hand.R": "DEF-f_middle.01.R",
}

var _done := false


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var src: Node3D = load(SRC).instantiate()
	var dst: Node3D = load(DST).instantiate()
	root.add_child(src)
	root.add_child(dst)
	var ss: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var ds: Skeleton3D = dst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var map := _full_map(ds)

	# Operator bones parents-first, and each one's fixed swing C.
	var order: Array[int] = []
	for i in ds.get_bone_count():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return _depth(ds, a) < _depth(ds, b))
	var swing := {}  # operator bone -> Basis
	for i in order:
		var name := ds.get_bone_name(i)
		if not map.has(name):
			continue
		var s := ss.find_bone(map[name][0])
		var child: String = map[name][1]
		if child == "":
			var p := ds.get_bone_parent(i)
			swing[i] = swing.get(p, Basis())
			continue
		var c := ds.find_bone(child)
		var dir_t := (ds.get_bone_global_rest(c).origin - ds.get_bone_global_rest(i).origin).normalized()
		var dir_s := _src_dir(ss, s)
		swing[i] = _swing(dir_t, dir_s)

	var hip_t := ds.find_bone("hips_01")
	var hip_s := ss.find_bone("DEF-hips")
	var scale := ds.get_bone_global_rest(hip_t).origin.y / ss.get_bone_global_rest(hip_s).origin.y
	var skel_path := str(dst.get_path_to(ds))

	var lib := AnimationLibrary.new()
	for clip in CLIPS:
		var a_src := ap.get_animation(clip)
		var anim := Animation.new()
		anim.length = a_src.length
		anim.loop_mode = a_src.loop_mode
		var tracks := {}
		for i in order:
			if map.has(ds.get_bone_name(i)):
				var t := anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(t, skel_path + ":" + ds.get_bone_name(i))
				tracks[i] = t
		var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pos_track, skel_path + ":hips_01")
		ap.play(clip)
		var frames := int(ceil(a_src.length * FPS))
		for f in frames + 1:
			var time := minf(f / FPS, a_src.length)
			ap.seek(time, true)
			var glob := {}  # operator bone -> Transform3D in skeleton space
			for i in order:
				var p := ds.get_bone_parent(i)
				var parent_g: Transform3D = glob[p] if p >= 0 else Transform3D()
				var name := ds.get_bone_name(i)
				if not map.has(name):
					glob[i] = parent_g * ds.get_bone_rest(i)
					continue
				var s := ss.find_bone(map[name][0])
				var d := ss.get_bone_global_pose(s).basis.orthonormalized() * ss.get_bone_global_rest(s).basis.orthonormalized().inverse()
				var g := Transform3D(d * swing[i] * ds.get_bone_global_rest(i).basis.orthonormalized(), parent_g * ds.get_bone_rest(i).origin)
				if i == hip_t:
					var moved := (ss.get_bone_global_pose(s).origin - ss.get_bone_global_rest(s).origin) * scale
					g.origin = ds.get_bone_global_rest(i).origin + moved
				glob[i] = g
				var local := parent_g.affine_inverse() * g
				anim.rotation_track_insert_key(tracks[i], time, local.basis.get_rotation_quaternion())
				if i == hip_t:
					anim.position_track_insert_key(pos_track, time, local.origin)
		lib.add_animation(CLIPS[clip], anim)
		print("baked ", clip, " -> ", CLIPS[clip], " (", frames + 1, " frames)")
	var err := ResourceSaver.save(lib, OUT)
	print("saved ", OUT, " err=", err)
	_check(dst, ds, lib)
	quit(0 if err == OK else 1)
	return true


## Plays walk and jump_start on the operator and checks the body stays a body: feet near the floor,
## head at head height, the feet trading places while walking.
func _check(dst: Node3D, ds: Skeleton3D, lib: AnimationLibrary) -> void:
	var ap := AnimationPlayer.new()
	dst.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", lib)
	var lf := ds.find_bone("L_ankle_04")
	var rf := ds.find_bone("R_ankle_09")
	var head := ds.find_bone("head_062")
	ap.play("walk")
	var spread := []
	for k in 4:
		ap.seek(lib.get_animation("walk").length * k / 4.0, true)
		var l := ds.get_bone_global_pose(lf).origin
		var r := ds.get_bone_global_pose(rf).origin
		var h := ds.get_bone_global_pose(head).origin
		print("walk %d/4: L foot %s  R foot %s  head %s" % [k, l, r, h])
		assert(l.y > -5.0 and l.y < 40.0 and r.y > -5.0 and r.y < 40.0, "feet off the floor")
		assert(h.y > 140.0 and h.y < 185.0, "head not at head height")
		spread.append(l.z - r.z)
	assert(spread.max() > 10.0 and spread.min() < -10.0, "feet do not trade places")
	print("check ok")


func _full_map(ds: Skeleton3D) -> Dictionary:
	var m := MAP.duplicate()
	for side in ["L", "R"]:
		for f in FINGERS:
			var bones := []
			for i in ds.get_bone_count():
				var n := ds.get_bone_name(i)
				if n.begins_with("%s_%s" % [side, f]):
					bones.append(n)
			bones.sort()  # thumb1 < thumb2 < thumb3 < thumb4
			for k in 3:
				var src := "DEF-%s.0%d.%s" % [FINGERS[f], k + 1, side]
				m[bones[k]] = [src, bones[k + 1]]
	return m


## The source bone's rest direction: toward its child when it has one, else its own +Y (Blender rig).
func _src_dir(ss: Skeleton3D, s: int) -> Vector3:
	var kids := ss.get_bone_children(s)
	var name := ss.get_bone_name(s)
	if SRC_CHILD.has(name):
		kids = PackedInt32Array([ss.find_bone(SRC_CHILD[name])])
	var o := ss.get_bone_global_rest(s).origin
	for k in kids:
		var d := ss.get_bone_global_rest(k).origin - o
		if d.length() > 0.001:
			return d.normalized()
	return ss.get_bone_global_rest(s).basis.y.normalized()


func _swing(from: Vector3, to: Vector3) -> Basis:
	var axis := from.cross(to)
	if axis.length() < 0.00001:
		return Basis()
	return Basis(axis.normalized(), from.angle_to(to))


func _depth(sk: Skeleton3D, i: int) -> int:
	var d := 0
	while sk.get_bone_parent(i) >= 0:
		i = sk.get_bone_parent(i)
		d += 1
	return d
