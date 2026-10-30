extends SceneTree
## Builds the Mixamo zombies from the raw FBX under assets/characters/zombies/raw (that folder has a
## .gdignore: Godot never imports the raw files and they never ship). Three steps:
##   Godot.exe --headless --path . -s res://tools/build_zombies.gd --quit-after 600 -- textures
##   Godot.exe --headless --path . --import --quit-after 600
##   Godot.exe --headless --path . -s res://tools/build_zombies.gd --quit-after 600 -- models anims
## Any model names after the steps limit them to those characters. With `players` among the args the
## same steps build the player characters instead (assets/characters/players, PLAYER_MODELS,
## PLAYER_CLIPS -> player_anims.res): one pipeline, so bodies and clips work the same way.
## textures: each character's maps, shrunk (albedo 2K, normal 1K), as PNG next to its scene.
## models:   assets/characters/zombies/<name>/<name>.scn, root Node3D > Skeleton3D > meshes, facing +Z.
## anims:    assets/characters/zombies/zombie_anims.res, one AnimationLibrary for every model.
##
## Sharing one library: every model's bone rests are turned to the skeleton's axes (the skin binds
## take the turn back, so the mesh does not move). Mixamo rigs all rest in a T-pose, so a clip bone's
## turn away from its own rest, D, is then the model bone's global turn as it is, and its local
## rotation is D(parent)⁻¹ · D. Hips positions are stored per metre of hip height; each model's
## Skeleton3D.motion_scale is its own hip height (zombie_body.gd sets it).

var RAW := "res://assets/characters/zombies/raw/"
var OUT := "res://assets/characters/zombies/"
var LIB := OUT + "zombie_anims.res"
const FPS := 30.0
const ALBEDO_SIZE := 2048
const NORMAL_SIZE := 1024
## Mixamo character (raw/chars/<file>.fbx) -> artist, for the credits in docs/ayrintilar.md.
## hazmat and bloater are Sketchfab models on Mixamo rigs, raw/chars/<name>.glb from
## tools/sketchfab_zombies.py.
const MODELS := ["prisoner", "copzombie", "parasite", "warzombie", "zombiegirl", "yaku", "romero",
		"skeletonzombie", "whiteclown", "warrok", "maw", "demon", "fleshzombie", "hazmat", "bloater"]
## Player characters (players/raw/chars/<file>.fbx): The Boss, Ch16 (masked), Ch32 (worker), Brute,
## Ch43 (chupacabra).
const PLAYER_MODELS := ["boss", "masked", "worker", "brute", "chupacabra"]
## Meshes left out of the built scene (what a character carries: the Brute's axe).
const DROP := ["BattleAxe_GEO"]
## Raw clip -> library name. What a clip is comes from the first word of its name that is a KIND;
## LOOPS loop (and anything ending _loop), IN_PLACE lose their travel (the body moves itself).
## "zombie biting" (stands, then goes down to bite the floor) is left out: at the railing it knelt.
const ZOMBIE_CLIPS := {
	"scary_zombie_pack/zombie idle.fbx": "idle_a",
	"scary_zombie_pack/zombie walk.fbx": "walk_a",
	"scary_zombie_pack/zombie run.fbx": "run_a",
	"scary_zombie_pack/zombie crawl.fbx": "crawl_a",
	"scary_zombie_pack/running crawl.fbx": "crawl_run_a",
	"scary_zombie_pack/zombie attack.fbx": "attack_a",
	"scary_zombie_pack/zombie neck bite.fbx": "attack_b",
	"scary_zombie_pack/zombie biting (2).fbx": "floor_bite_a",  # on its belly: a crawler's swing
	"scary_zombie_pack/zombie death.fbx": "death_a",
	"scary_zombie_pack/zombie dying.fbx": "death_b",
	"scary_zombie_pack/zombie scream.fbx": "scream_a",
	"not_so_scary_zombie_pack/zombie idle.fbx": "idle_b",
	"not_so_scary_zombie_pack/zombie idle (2).fbx": "idle_c",
	"not_so_scary_zombie_pack/zombie idle (3).fbx": "idle_d",
	"not_so_scary_zombie_pack/zombie idle (4).fbx": "idle_e",
	"not_so_scary_zombie_pack/zombie scratch idle.fbx": "idle_f",
	"not_so_scary_zombie_pack/zombie agonizing.fbx": "idle_g",
	"not_so_scary_zombie_pack/walking.fbx": "walk_b",
	"not_so_scary_zombie_pack/walking (2).fbx": "walk_c",
	"not_so_scary_zombie_pack/zombie running.fbx": "run_b",
	"not_so_scary_zombie_pack/zombie attack.fbx": "attack_d",
	"not_so_scary_zombie_pack/zombie punching.fbx": "attack_e",
	"not_so_scary_zombie_pack/zombie punching (2).fbx": "attack_f",
	"not_so_scary_zombie_pack/zombie headbutt.fbx": "attack_g",
	"not_so_scary_zombie_pack/zombie kicking.fbx": "attack_h",
	"not_so_scary_zombie_pack/zombie kicking (2).fbx": "attack_i",
	"not_so_scary_zombie_pack/zombie reaction hit.fbx": "hit_a",
	"not_so_scary_zombie_pack/zombie reaction hit (2).fbx": "hit_b",
	"not_so_scary_zombie_pack/zombie stand up.fbx": "stand_up_a",
	"not_so_scary_zombie_pack/zombie stand up (2).fbx": "stand_up_b",
	"not_so_scary_zombie_pack/zombie stand up (3).fbx": "stand_up_c",
	"not_so_scary_zombie_pack/zombie stumbling.fbx": "fall_a",  # stumbles and goes down flat: a leg torn off
	"creature_pack/mutant idle.fbx": "mutant_idle_a",
	"creature_pack/mutant idle (2).fbx": "mutant_idle_b",
	"creature_pack/mutant breathing idle.fbx": "mutant_idle_c",
	"creature_pack/mutant walking.fbx": "mutant_walk_a",
	"creature_pack/mutant run.fbx": "mutant_run_a",
	"creature_pack/mutant swiping.fbx": "mutant_attack_a",
	"creature_pack/mutant punch.fbx": "mutant_attack_b",
	"creature_pack/mutant jump attack.fbx": "mutant_attack_c",
	"creature_pack/jump attack.fbx": "mutant_attack_d",
	"creature_pack/mutant roaring.fbx": "mutant_roar_a",
	"creature_pack/mutant flexing muscles.fbx": "mutant_flex_a",
	"creature_pack/mutant jumping.fbx": "mutant_jump_a",
	"creature_pack/mutant dying.fbx": "mutant_death_a",
}
## Player clips: Mixamo's Pistol/Handgun Locomotion Pack (Deagle, UZI, Scorpion), Rifle 8-Way
## Locomotion Pack (Minigun) and Male Locomotion Pack (fists), all made on Ch43.
const PLAYER_CLIPS := {
	"pistol_pack/pistol idle.fbx": "pistol_idle",
	"pistol_pack/pistol walk.fbx": "pistol_walk",
	"pistol_pack/pistol run.fbx": "pistol_run",
	"pistol_pack/pistol walk backward.fbx": "pistol_walk_back",
	"pistol_pack/pistol run backward.fbx": "pistol_run_back",
	"pistol_pack/pistol strafe.fbx": "pistol_strafe_a",
	"pistol_pack/pistol strafe (2).fbx": "pistol_strafe_b",
	"pistol_pack/pistol jump.fbx": "pistol_jump_a",
	"pistol_pack/pistol jump (2).fbx": "pistol_jump_b",
	"pistol_pack/pistol kneeling idle.fbx": "pistol_kneel_idle",
	"rifle_pack/idle.fbx": "rifle_idle",
	"rifle_pack/idle aiming.fbx": "rifle_aim_idle",
	"rifle_pack/walk forward.fbx": "rifle_walk",
	"rifle_pack/walk backward.fbx": "rifle_walk_back",
	"rifle_pack/walk left.fbx": "rifle_walk_left",
	"rifle_pack/walk right.fbx": "rifle_walk_right",
	"rifle_pack/run forward.fbx": "rifle_run",
	"rifle_pack/run backward.fbx": "rifle_run_back",
	"rifle_pack/run left.fbx": "rifle_run_left",
	"rifle_pack/run right.fbx": "rifle_run_right",
	"rifle_pack/sprint forward.fbx": "rifle_sprint",
	"rifle_pack/jump up.fbx": "rifle_jump_up",
	"rifle_pack/jump loop.fbx": "rifle_jump_loop",
	"rifle_pack/jump down.fbx": "rifle_jump_down",
	"rifle_pack/idle crouching.fbx": "rifle_crouch_idle",
	"rifle_pack/walk crouching forward.fbx": "rifle_crouch_walk",
	"rifle_pack/walk crouching backward.fbx": "rifle_crouch_walk_back",
	"rifle_pack/walk crouching left.fbx": "rifle_crouch_walk_left",
	"rifle_pack/walk crouching right.fbx": "rifle_crouch_walk_right",
	"rifle_pack/walk crouching forward left.fbx": "rifle_crouch_walk_fl",
	"rifle_pack/walk crouching forward right.fbx": "rifle_crouch_walk_fr",
	"rifle_pack/walk crouching backward left.fbx": "rifle_crouch_walk_bl",
	"rifle_pack/walk crouching backward right.fbx": "rifle_crouch_walk_br",
	"rifle_pack/death from the front.fbx": "rifle_death_front",
	"rifle_pack/death from the back.fbx": "rifle_death_back",
	"male_pack/idle.fbx": "idle",
	"male_pack/walking.fbx": "walk",
	"male_pack/standard run.fbx": "run",
	"male_pack/left strafe walking.fbx": "walk_left",
	"male_pack/right strafe walking.fbx": "walk_right",
	"male_pack/left strafe.fbx": "run_left",
	"male_pack/right strafe.fbx": "run_right",
	"male_pack/jump.fbx": "jump",
}
const KINDS := ["idle", "walk", "run", "sprint", "strafe", "crawl", "jump", "attack", "hit", "death",
	"scream", "stand", "roar", "flex", "fall", "bite"]
const LOOPS := ["idle", "walk", "run", "sprint", "strafe", "crawl"]
const IN_PLACE := ["walk", "run", "sprint", "strafe", "crawl", "fall"]  # fall: waves.gd carries it on
var CLIPS := ZOMBIE_CLIPS
## Clips checked joint by joint against the raw file, on the character the pack was made on.
var CHECK := {"model": "prisoner", "slack": 0.03, "clips": [["scary_zombie_pack/zombie walk.fbx", "walk_a"],
		["scary_zombie_pack/zombie death.fbx", "death_a"], ["not_so_scary_zombie_pack/zombie punching.fbx", "attack_e"]]}

var _done := false


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var steps := OS.get_cmdline_user_args()
	var ok := true
	var all: Array = MODELS
	if "players" in steps:
		RAW = "res://assets/characters/players/raw/"
		OUT = "res://assets/characters/players/"
		LIB = OUT + "player_anims.res"
		all = PLAYER_MODELS
		CLIPS = PLAYER_CLIPS
		# chupacabra.fbx and the packs' Ch43 are rigged a few cm apart (hips 7 cm forward): 5 cm slack.
		CHECK = {"model": "chupacabra", "slack": 0.05, "clips": [["pistol_pack/pistol walk.fbx", "pistol_walk"],
				["rifle_pack/run left.fbx", "rifle_run_left"], ["male_pack/jump.fbx", "jump"]]}
	var models: Array = Array(steps).filter(func(a: String) -> bool: return a in all)  # names after the steps: only those
	if models.is_empty():
		models = all
	if "textures" in steps:
		for m in models:
			_textures(m)
	if "models" in steps:
		for m in models:
			ok = _model(m) and ok
	if "anims" in steps:
		ok = _anims() and ok
	quit(0 if ok else 1)
	return true


## A character's raw file: the Mixamo FBX, or the glb a Sketchfab model was turned into.
func _char(model: String) -> String:
	var glb := RAW + "chars/%s.glb" % model
	return glb if FileAccess.file_exists(glb) else RAW + "chars/%s.fbx" % model


func _load(path: String) -> Node3D:
	var doc: GLTFDocument = GLTFDocument.new() if path.ends_with(".glb") else FBXDocument.new()
	var st: GLTFState = GLTFState.new() if path.ends_with(".glb") else FBXState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), st) != OK:
		push_error("cannot read " + path)
		return null
	var scene: Node3D = doc.generate_scene(st, FPS)
	return scene


## Albedo and normal map of every material, as <model>_<k>_albedo.png / _normal.png.
func _textures(model: String) -> void:
	var scene := _load(_char(model))
	var dir := OUT + model
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var seen := {}
	for mat in _materials(scene):
		var k: int = seen.size()
		if seen.has(mat.albedo_texture):
			continue
		seen[mat.albedo_texture] = k
		for pair in [[mat.albedo_texture, "albedo", ALBEDO_SIZE], [mat.normal_texture, "normal", NORMAL_SIZE]]:
			if pair[0] == null:
				continue
			var img: Image = pair[0].get_image().duplicate()
			img.decompress()
			if img.get_width() > pair[2]:
				img.resize(pair[2], pair[2], Image.INTERPOLATE_LANCZOS)
			var file := "%s/%s_%d_%s.png" % [dir, model, k, pair[1]]
			img.save_png(file)
			var normal: bool = pair[1] == "normal"
			var imp := FileAccess.open(file + ".import", FileAccess.WRITE)
			imp.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=2\ncompress/normal_map=%d\nmipmaps/generate=true\nroughness/mode=0\n" % (1 if normal else 2))
			print("wrote ", file, " ", img.get_size())
	scene.free()


func _materials(scene: Node3D) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.name in DROP:
			continue
		for s in mi.mesh.get_surface_count():
			out.append(mi.mesh.surface_get_material(s))
	return out


func _model(model: String) -> bool:
	var scene := _load(_char(model))
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		ap.free()
	scene.name = model
	if sk.get_parent() != scene:  # a glb keeps Blender's Armature node over it
		var holder := sk.get_parent()
		holder.remove_child(sk)
		scene.add_child(sk)
		holder.free()
	sk.name = "Skeleton3D"
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		if mi.name in DROP:
			mi.free()

	# Some exports number the rig (mixamorig5_Hips): one name for all, or the clips miss it.
	var numbered := RegEx.create_from_string("^mixamorig[0-9]+_")
	for i in sk.get_bone_count():
		sk.set_bone_name(i, numbered.sub(sk.get_bone_name(i), "mixamorig_"))
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		if mi.skin:
			for b in mi.skin.get_bind_count():
				mi.skin.set_bind_name(b, numbered.sub(mi.skin.get_bind_name(b), "mixamorig_"))

	# Rests to the skeleton's axes, binds take the turn back.
	var old_g: Array[Transform3D] = []
	for i in sk.get_bone_count():
		old_g.append(sk.get_bone_global_rest(i))
	for i in sk.get_bone_count():
		var p := sk.get_bone_parent(i)
		var rest := Transform3D(Basis(), old_g[i].origin - (old_g[p].origin if p >= 0 else Vector3.ZERO))
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
				var bind := Transform3D(Basis(), -old_g[bone].origin) * old_g[bone] * mi.skin.get_bind_pose(b)
				if bname != &"":
					skin.add_named_bind(bname, bind)
				else:
					skin.add_bind(bone, bind)
			skins[mi.skin] = skin
		mi.skin = skins[mi.skin]

	# Materials onto the shrunk maps. Mixamo alpha (hair, torn cloth, glasses) is a cutout.
	var made := {}
	var seen := {}
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = mi.mesh
		for s in mesh.get_surface_count():
			var src: StandardMaterial3D = mesh.surface_get_material(s)
			if not seen.has(src.albedo_texture):
				seen[src.albedo_texture] = seen.size()
			var k: int = seen[src.albedo_texture]
			var key := "%d_%d" % [k, src.transparency]
			if not made.has(key):
				var mat := StandardMaterial3D.new()
				mat.resource_name = src.resource_name
				var base := OUT + "%s/%s_%d_" % [model, model, k]
				if src.albedo_texture:
					mat.albedo_texture = load(base + "albedo.png")
				else:  # a plain colour (the Brute's earrings)
					mat.albedo_color = src.albedo_color
				if src.normal_texture:
					mat.normal_enabled = true
					mat.normal_texture = load(base + "normal.png")
				mat.roughness = 0.8
				if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					mat.alpha_scissor_threshold = 0.5
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				if src.albedo_texture and mat.albedo_texture == null:
					push_error("%s: textures not imported, run the textures step and --import first" % model)
					return false
				made[key] = mat
			mesh.surface_set_material(s, made[key])
		mi.owner = scene
	sk.owner = scene
	var packed := PackedScene.new()
	packed.pack(scene)
	var path := OUT + "%s/%s.scn" % [model, model]
	var err := ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
	print("saved ", path, " bones=", sk.get_bone_count(), " hips=", sk.get_bone_global_rest(0).origin.y, " err=", err)
	scene.free()
	return err == OK


func _anims() -> bool:
	var lib := AnimationLibrary.new()
	for clip in CLIPS:
		var name: String = CLIPS[clip]
		var scene := _load(RAW + clip)
		if scene == null:
			return false
		root.add_child(scene)
		var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var src_name: String = ap.get_animation_list()[0]
		var src := ap.get_animation(src_name)
		var kind := ""
		for word in name.split("_"):
			if word in KINDS:
				kind = word
				break
		var hips := sk.find_bone("mixamorig_Hips")
		var hip_h := sk.get_bone_global_rest(hips).origin.y

		var anim := Animation.new()
		anim.length = src.length
		anim.loop_mode = Animation.LOOP_LINEAR if kind in LOOPS or name.ends_with("_loop") else Animation.LOOP_NONE
		var bones: Array[int] = []
		var tracks := {}
		for i in sk.get_bone_count():
			var bname := sk.get_bone_name(i)
			if src.find_track(NodePath("Skeleton3D:" + bname), Animation.TYPE_ROTATION_3D) < 0:
				continue
			bones.append(i)
			tracks[i] = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(tracks[i], "Skeleton3D:" + bname)
		var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pos_track, "Skeleton3D:mixamorig_Hips")

		ap.play(src_name)
		var frames := int(round(src.length * FPS))
		var hip_path: Array[Vector3] = []
		for f in frames + 1:
			var time := minf(f / FPS, src.length)
			ap.seek(time, true)
			var turn := {}  # bone -> D, its turn away from rest in skeleton space
			for i in bones:
				turn[i] = (sk.get_bone_global_pose(i).basis.orthonormalized()
						* sk.get_bone_global_rest(i).basis.orthonormalized().inverse())
			for i in bones:
				var p := sk.get_bone_parent(i)
				var parent_turn: Basis = turn.get(p, Basis())
				var local: Basis = (parent_turn.inverse() * turn[i]).orthonormalized()
				anim.rotation_track_insert_key(tracks[i], time, local.get_rotation_quaternion())
			hip_path.append(sk.get_bone_global_pose(hips).origin / hip_h)

		# In place: the travel taken out along a straight line, the sway kept. Everything else
		# starts over the feet. Natural speed (hip heights per second; forward, and as a vector
		# for strafes and backing up) goes in the clip's meta.
		var first := hip_path[0]
		var last := hip_path[-1]
		var travel := last - first
		for f in hip_path.size():
			var t := float(f) / maxf(1.0, hip_path.size() - 1)
			var p := hip_path[f]
			if kind in IN_PLACE:
				p = Vector3(p.x - first.x - travel.x * t, p.y, p.z - first.z - travel.z * t)
			else:
				p = Vector3(p.x - first.x, p.y, p.z - first.z)
			anim.position_track_insert_key(pos_track, minf(f / FPS, src.length), p)
		if kind in IN_PLACE:
			anim.set_meta("speed", travel.z / src.length)
			anim.set_meta("velocity", Vector2(travel.x, travel.z) / src.length)
		_slim(anim)
		lib.add_animation(name, anim)
		print("baked %-34s -> %-16s %5.2f s  %d bones%s" % [clip, name, src.length, bones.size(),
				"  speed %.2f hips/s" % anim.get_meta("speed") if anim.has_meta("speed") else ""])
		scene.free()
	var err := ResourceSaver.save(lib, LIB, ResourceSaver.FLAG_COMPRESS)
	print("saved ", LIB, " err=", err)
	return err == OK and _check(lib)


## On the character a pack was made on (CHECK), the baked clips must put every joint where the raw
## clip does, in place aside.
func _check(lib: AnimationLibrary) -> bool:
	var ok := true
	for pair in CHECK.clips:
		var raw := _load(RAW + pair[0])
		root.add_child(raw)
		var rs: Skeleton3D = raw.find_children("*", "Skeleton3D", true, false)[0]
		var rap: AnimationPlayer = raw.find_children("*", "AnimationPlayer", true, false)[0]
		var model: Node3D = load(OUT + "%s/%s.scn" % [CHECK.model, CHECK.model]).instantiate()
		root.add_child(model)
		var ms: Skeleton3D = model.get_node("Skeleton3D")
		ms.motion_scale = ms.get_bone_global_rest(0).origin.y
		var ap := AnimationPlayer.new()
		model.add_child(ap)
		ap.root_node = ^".."
		ap.add_animation_library("", lib)
		rap.play(rap.get_animation_list()[0])
		ap.play(pair[1])
		var worst := 0.0
		var moved := 0.0
		for k in 5:
			var t: float = lib.get_animation(pair[1]).length * k / 4.0
			rap.seek(t, true)
			ap.seek(t, true)
			var rh := rs.get_bone_global_pose(0).origin
			var mh := ms.get_bone_global_pose(0).origin
			for b in ["mixamorig_Head", "mixamorig_LeftHand", "mixamorig_RightHand", "mixamorig_LeftFoot", "mixamorig_RightToeBase"]:
				var r := rs.get_bone_global_pose(rs.find_bone(b)).origin - rh
				var m := ms.get_bone_global_pose(ms.find_bone(b)).origin - mh
				worst = maxf(worst, r.distance_to(m))
				moved = maxf(moved, m.distance_to(ms.get_bone_global_rest(ms.find_bone(b)).origin - ms.get_bone_global_rest(0).origin))
			worst = maxf(worst, absf(rh.y - mh.y))
		print("check %-10s worst joint miss %.3f m, joints moved up to %.2f m" % [pair[1], worst, moved])
		ok = ok and worst < CHECK.slack and moved > 0.2
		raw.free()
		model.free()
	print("check ", "ok" if ok else "FAILED")
	return ok


## Tracks that never move keep a single key.
func _slim(anim: Animation) -> void:
	for t in anim.get_track_count():
		var n := anim.track_get_key_count(t)
		var v0 = anim.track_get_key_value(t, 0)
		var still := true
		for k in range(1, n):
			var v = anim.track_get_key_value(t, k)
			if (v is Quaternion and absf(v.dot(v0)) < 0.99999) or (v is Vector3 and v.distance_to(v0) > 0.0005):
				still = false
				break
		if still:
			for k in range(n - 1, 0, -1):
				anim.track_remove_key(t, k)
