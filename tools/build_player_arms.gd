extends SceneTree
## The first-person arms' colours for each player character, read off the character itself: the
## median albedo under the skin's hand bones (gloves) and forearm bones (sleeves), each vertex
## weighted mostly to that bone sampled at its UV. Writes assets/characters/players/arms.json;
## tools/paint_player_arms.py paints the arms' textures from it. Two steps:
##   Godot.exe --headless --path . -s res://tools/build_player_arms.gd --quit-after 600
##   python tools/paint_player_arms.py

const DIR := "res://assets/characters/players/"
const OUT := DIR + "arms.json"
const PLAYERS := ["boss", "masked", "worker", "brute", "chupacabra"]
## What each part is made of, by the bone names its vertices hang on (Mixamo, both sides).
const PARTS := {"hand": ["LeftHand", "RightHand"], "forearm": ["LeftForeArm", "RightForeArm"]}
const HOLD := 0.6  # a vertex counts for a bone only when that bone carries this much of it
## A part whose colour is warm (red over green over blue), not too dark and not as saturated as
## dyed cloth (the worker's orange) is bare skin: the paint keeps less of the arms' stitching and
## weave on it. (The head was the first yardstick; eyes, mouth and hair throw its colour off.)
const SKIN_SAT := 0.75
const SKIN_DARK := 0.3


func _init() -> void:
	var out := {}
	for id: String in PLAYERS:
		out[id] = _colours(id)
		print(id, " ", out[id])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("wrote ", OUT)
	quit(0)


func _colours(id: String) -> Dictionary:
	var scene: Node3D = load(DIR + "%s/%s.scn" % [id, id]).instantiate()
	var picked := {}  # part -> [Color]
	for part: String in PARTS:
		picked[part] = []
	var images := {}
	var sk: Skeleton3D = scene.get_node("Skeleton3D")
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if mat == null or mat.albedo_texture == null:
				continue
			var path := mat.albedo_texture.resource_path
			if not images.has(path):
				images[path] = Image.load_from_file(ProjectSettings.globalize_path(path))
			var img: Image = images[path]
			var arrays := mi.mesh.surface_get_arrays(s)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var per := bones.size() / uvs.size()
			var names := []  # bind -> bone name (the binds are by index)
			for k in mi.skin.get_bind_count():
				var n := mi.skin.get_bind_name(k)
				names.append(str(n) if n != &"" else sk.get_bone_name(mi.skin.get_bind_bone(k)))
			for v in uvs.size():
				var part := ""
				for k in per:
					if weights[v * per + k] >= HOLD:
						part = _part_of(names[bones[v * per + k]])
				if part == "":
					continue
				var uv := uvs[v]
				var px := Vector2i(posmod(int(uv.x * img.get_width()), img.get_width()),
						posmod(int(uv.y * img.get_height()), img.get_height()))
				var c := img.get_pixelv(px)
				if c.a > 0.5:
					picked[part].append(c)
	scene.free()
	var res := {}
	for part: String in PARTS:
		if picked[part].is_empty():
			push_error("%s: no %s vertices" % [id, part])
			res[part] = [0.5, 0.5, 0.5]
			continue
		var c := _median(picked[part])
		res[part] = [snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001)]
	for part: String in PARTS:
		var c := Color(res[part][0], res[part][1], res[part][2])
		res[part + "_skin"] = c.r > c.g and c.g > c.b and c.v > SKIN_DARK and c.s < SKIN_SAT
	return res


static func _part_of(bone: String) -> String:
	bone = bone.trim_prefix("mixamorig_")
	for part: String in PARTS:
		for b: String in PARTS[part]:
			# The hand's fingers are its own ("RightHandIndex2"); "RightForeArm" is not "RightHand".
			if bone == b or (part == "hand" and bone.begins_with(b)):
				return part
	return ""


static func _median(cs: Array) -> Color:
	var ch := [[], [], []]
	for c: Color in cs:
		ch[0].append(c.r)
		ch[1].append(c.g)
		ch[2].append(c.b)
	for a: Array in ch:
		a.sort()
	return Color(ch[0][ch[0].size() / 2], ch[1][ch[1].size() / 2], ch[2][ch[2].size() / 2])
