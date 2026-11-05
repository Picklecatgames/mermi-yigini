extends SceneTree
## The player's body since 2026-11-05 (the user: "old man psx", Sketchfab, petya-petyavich, CC-BY; the
## five Mixamo bodies are gone). Reads the download under assets/characters/players/raw/oldman/ (not in
## git, .gitignore), writes assets/characters/players/oldman/oldman.scn and the file's own clip as
## "dance" into player_anims.res, where every body on a Mixamo rig can play it:
##   Godot.exe --headless --path . -s res://tools/build_oldman.gd
##   Godot.exe --headless --path . -s res://tools/lowpoly_zombie.gd -- psx oldman
##   Godot.exe --headless --path . -s res://tools/build_fp_arms.gd --quit-after 600
## Same treatment as build_zombies.gd (one library for every body: rests turned to the skeleton's axes,
## the binds taking the turn back), with two differences. The texture goes into the scene itself, so
## no import step is needed. And this rig's hands have only a thumb and an index finger, while the
## grip (remote_players.gd, fp_arms.gd) lines every finger up with the first-person hand's: the other
## three are added as bones nothing is skinned to, beside the index, so the palm's width is there to
## go by. The mesh's hand is a mitten on the thumb and index anyway.

const RAW := "res://assets/characters/players/raw/oldman/"
const OUT := "res://assets/characters/players/oldman/"
const LIB := "res://assets/characters/players/player_anims.res"
const FPS := 30.0
const SIDES := ["Left", "Right"]
## Added fingers: name -> how far across the palm from the index, per hand length (wrist to index).
## First guesses, nothing is drawn on them; they set the hand's frame and where the gun's grip sits.
const FINGERS := {"Middle": 0.2, "Ring": 0.4, "Pinky": 0.58}
var _done := false
## This rig's index starts halfway up the palm, wrist to fingertip being 2.7 times wrist to index, on
## a real hand about 2. Hands and arms are sized by wrist to middle knuckle (fp_arms.gd, remote_players.gd
## _show_gun), so with the middle beside the index they came out 1.4 times too big and hid the gun.
const KNUCKLE := 1.5
const FINGER_REACH := {"Middle": 1.05, "Ring": 0.95, "Pinky": 0.8}  # of the index's length


## From the first frame, as build_zombies.gd: an AnimationPlayer seeks nothing before the tree runs.
func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var ok := _model() and _dance()
	quit(0 if ok else 1)
	return true


func _load() -> Node3D:
	var doc := FBXDocument.new()
	var st := FBXState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(RAW + "oldman.fbx"), st) != OK:
		push_error("cannot read the raw model: see this script's header")
		return null
	return doc.generate_scene(st, FPS)


func _model() -> bool:
	var scene := _load()
	if scene == null:
		return false
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		ap.free()
	scene.name = "oldman"
	if sk.get_parent() != scene:
		var holder := sk.get_parent()
		holder.remove_child(sk)
		scene.add_child(sk)
		holder.free()
	sk.name = "Skeleton3D"
	var numbered := RegEx.create_from_string("^mixamorig[0-9]*[:_]")
	for i in sk.get_bone_count():
		sk.set_bone_name(i, numbered.sub(sk.get_bone_name(i), "mixamorig_"))
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		if mi.skin:
			for b in mi.skin.get_bind_count():
				mi.skin.set_bind_name(b, numbered.sub(mi.skin.get_bind_name(b), "mixamorig_"))
	# This rig's arms rest about 16 degrees below level; the shared clips take a level T-pose for
	# granted. The rest and the mesh in it are lifted to level (the binds carry the turn), and _dance
	# takes the same turn out of the file's own clip, so both it and the shared clips stay true.
	var lift := _arm_lifts(sk)
	var old_g: Array[Transform3D] = []
	var new_at: Array[Vector3] = []
	for i in sk.get_bone_count():
		old_g.append(sk.get_bone_global_rest(i))
		new_at.append((lift[i] as Transform3D) * old_g[i].origin)
	for i in sk.get_bone_count():
		var p := sk.get_bone_parent(i)
		var rest := Transform3D(Basis(), new_at[i] - (new_at[p] if p >= 0 else Vector3.ZERO))
		sk.set_bone_rest(i, rest)
		sk.set_bone_pose(i, rest)
	var skins := {}
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		if not skins.has(mi.skin):
			var skin := Skin.new()
			for b in mi.skin.get_bind_count():
				var bone := mi.skin.get_bind_bone(b)
				var bname := mi.skin.get_bind_name(b)
				if bname != &"":
					bone = sk.find_bone(bname)
				var bind := Transform3D(Basis(), -new_at[bone]) * (lift[bone] as Transform3D) * old_g[bone] * mi.skin.get_bind_pose(b)
				if bname != &"":
					skin.add_named_bind(bname, bind)
				else:
					skin.add_bind(bone, bind)
			skins[mi.skin] = skin
		mi.skin = skins[mi.skin]
	for side: String in SIDES:
		_add_fingers(sk, side)
	sk.reset_bone_poses()

	# The material, its texture inside the scene.
	var img := Image.load_from_file(ProjectSettings.globalize_path(RAW + "oldman.png"))
	if img == null or img.is_empty():
		push_error("no texture in " + RAW)
		return false
	img.convert(Image.FORMAT_RGB8)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "oldman"
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 0.8
	var tris := 0
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			(mi.mesh as ArrayMesh).surface_set_material(s, mat)
			tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		mi.owner = scene
	sk.owner = scene
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var packed := PackedScene.new()
	packed.pack(scene)
	var err := ResourceSaver.save(packed, OUT + "oldman.scn", ResourceSaver.FLAG_COMPRESS)
	print("saved oldman.scn bones=%d tris=%d texture=%s bone0=%s hips=%.3f top=%.3f err=%d" % [sk.get_bone_count(), tris, img.get_size(),
			sk.get_bone_name(0), sk.get_bone_global_rest(sk.find_bone("mixamorig_Hips")).origin.y,
			sk.get_bone_global_rest(sk.find_bone("mixamorig_HeadTop_End")).origin.y, err])
	scene.free()
	return err == OK


## Per bone, what takes it to the level T-pose: an arm's bones turned about their shoulder joint so
## shoulder to wrist runs level; everything else stays.
func _arm_lifts(sk: Skeleton3D) -> Array:
	var out := []
	out.resize(sk.get_bone_count())
	out.fill(Transform3D())
	for side: String in SIDES:
		var arm := sk.find_bone("mixamorig_%sArm" % side)
		var at := sk.get_bone_global_rest(arm).origin
		var to := (sk.get_bone_global_rest(sk.find_bone("mixamorig_%sHand" % side)).origin - at).normalized()
		var turn := Basis(Quaternion(to, Vector3(to.x, 0.0, to.z).normalized()))
		print("%s arm lifted %.1f degrees" % [side, rad_to_deg(turn.get_rotation_quaternion().get_angle())])
		var lift := Transform3D(Basis(), at) * Transform3D(turn, Vector3.ZERO) * Transform3D(Basis(), -at)
		for i in sk.get_bone_count():
			var b := i
			while b != -1:
				if b == arm:
					out[i] = lift
					break
				b = sk.get_bone_parent(b)
	return out


## Middle, ring and pinky beside the index, on the side away from the thumb. Rests are axis-aligned
## already: each bone's rest is only the step from its parent.
func _add_fingers(sk: Skeleton3D, side: String) -> void:
	var hand := sk.find_bone("mixamorig_%sHand" % side)
	var at := func(b: String) -> Vector3:
		return sk.get_bone_global_rest(sk.find_bone("mixamorig_%sHand%s" % [side, b])).origin
	var wrist := sk.get_bone_global_rest(hand).origin
	var index: Vector3 = at.call("Index1")
	var along: Vector3 = index - wrist
	var length := along.length()
	along = along.normalized()
	var thumb: Vector3 = (at.call("Thumb1") as Vector3) - index
	var across := -(thumb - along * thumb.dot(along)).normalized()
	for finger: String in FINGERS:
		var place: Vector3 = wrist + along * length * KNUCKLE + across * length * float(FINGERS[finger])
		var parent := hand
		var from := wrist
		for k in range(1, 5):
			var seg := Vector3.ZERO
			if k > 1:
				seg = ((at.call("Index%d" % k) as Vector3) - (at.call("Index%d" % (k - 1)) as Vector3)) * float(FINGER_REACH[finger])
			place += seg
			var bone := sk.add_bone("mixamorig_%sHand%s%d" % [side, finger, k])
			sk.set_bone_parent(bone, parent)
			sk.set_bone_rest(bone, Transform3D(Basis(), place - from))
			parent = bone
			from = place


## The file's clip, baked as build_zombies.gd _anims bakes one, in place, looping.
func _dance() -> bool:
	var lib: AnimationLibrary = load(LIB)
	var scene := _load()
	root.add_child(scene)
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var src_name: String = ap.get_animation_list()[0]
	var src := ap.get_animation(src_name)
	var numbered := RegEx.create_from_string("^mixamorig[0-9]*[:_]")
	var hips := -1
	for i in sk.get_bone_count():
		if numbered.sub(sk.get_bone_name(i), "mixamorig_") == "mixamorig_Hips":
			hips = i
	var hip_h := sk.get_bone_global_rest(hips).origin.y
	for i in sk.get_bone_count():  # _arm_lifts looks bones up by their clean names
		sk.set_bone_name(i, numbered.sub(sk.get_bone_name(i), "mixamorig_"))
	var lift := _arm_lifts(sk)
	var anim := Animation.new()
	anim.length = src.length
	anim.loop_mode = Animation.LOOP_LINEAR
	var bones: Array[int] = []
	var tracks := {}
	for i in sk.get_bone_count():
		if src.find_track(NodePath("Skeleton3D:" + sk.get_bone_name(i)), Animation.TYPE_ROTATION_3D) < 0:
			continue
		bones.append(i)
		tracks[i] = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tracks[i], "Skeleton3D:" + numbered.sub(sk.get_bone_name(i), "mixamorig_"))
	if bones.is_empty():
		push_error("no bone tracks in the clip: its paths are not Skeleton3D:<bone>")
		return false
	var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_track, "Skeleton3D:mixamorig_Hips")
	ap.play(src_name)
	var frames := int(round(src.length * FPS))
	var hip_path: Array[Vector3] = []
	for f in frames + 1:
		var time := minf(f / FPS, src.length)
		ap.seek(time, true)
		var turn := {}
		for i in bones:
			turn[i] = (sk.get_bone_global_pose(i).basis.orthonormalized()
					* sk.get_bone_global_rest(i).basis.orthonormalized().inverse()
					* (lift[i] as Transform3D).basis.inverse())
		for i in bones:
			var parent_turn: Basis = turn.get(sk.get_bone_parent(i), Basis())
			anim.rotation_track_insert_key(tracks[i], time, (parent_turn.inverse() * turn[i]).orthonormalized().get_rotation_quaternion())
		hip_path.append(sk.get_bone_global_pose(hips).origin / hip_h)
	# The travel taken out along a straight line, the sway kept: the loop does not jump back.
	var first := hip_path[0]
	var travel := hip_path[-1] - first
	for f in hip_path.size():
		var t := float(f) / maxf(1.0, hip_path.size() - 1)
		var p := hip_path[f]
		anim.position_track_insert_key(pos_track, minf(f / FPS, src.length), Vector3(p.x - first.x - travel.x * t, p.y, p.z - first.z - travel.z * t))
	if lib.has_animation("dance"):
		lib.remove_animation("dance")
	lib.add_animation("dance", anim)
	var err := ResourceSaver.save(lib, LIB, ResourceSaver.FLAG_COMPRESS)
	print("baked dance: %.2f s, %d bones, travel taken out %s; clips in the library %d, err=%d" % [src.length, bones.size(), travel, lib.get_animation_list().size(), err])
	scene.free()
	return err == OK
