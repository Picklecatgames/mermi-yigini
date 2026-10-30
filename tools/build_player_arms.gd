extends SceneTree
## The first-person arms' colours for each player character, read off the character itself: the
## median albedo under the skin's hand bones (gloves) and forearm bones (sleeves), each vertex
## weighted mostly to that bone sampled at its UV. The hand also in BANDS from the wrist to the
## fingertips, so a glove is told from a bare hand and its cuff from its fingers (the Chupacabra's
## black glove with purple flames at the wrist); and the first-person glove's texels get the same
## measure (GLOVE_MAP: how far each is from the wrist), so the paint lays the bands where they go.
## Writes assets/characters/players/arms.json; tools/paint_player_arms.py paints the arms' textures
## from them. Two steps:
##   Godot.exe --headless --path . -s res://tools/build_player_arms.gd --quit-after 600
##   python tools/paint_player_arms.py

const DIR := "res://assets/characters/players/"
const OUT := DIR + "arms.json"
const PLAYERS := ["boss", "masked", "worker", "brute", "chupacabra", "vegas"]
## What each part is made of, by the bone names its vertices hang on (Mixamo, both sides).
const PARTS := {"hand": ["LeftHand", "RightHand"], "forearm": ["LeftForeArm", "RightForeArm"]}
const HOLD := 0.6  # a vertex counts for a bone only when that bone carries this much of it
## A part whose colour is warm (red over green over blue), not too dark and not as saturated as
## dyed cloth (the worker's orange) is bare skin: the paint keeps less of the arms' stitching and
## weave on it. (The head was the first yardstick; eyes, mouth and hair throw its colour off.)
const SKIN_SAT := 0.75
const SKIN_DARK := 0.3
const BANDS := 5  # wrist (0) to the middle fingertip (1), in equal steps
## Per texel of the first-person glove map: (along - GLOVE_T0) / GLOVE_T_SPAN of the way from the
## wrist to the fingertip in the red channel; nothing drawn there, 0 in green (written: 1).
const GLOVE_MAP := DIR + "raw/glove_t.png"
const GLOVE_T0 := -0.5
const GLOVE_T_SPAN := 2.0
const ARMS := "res://assets/weapons/arms/arms.gltf"


func _init() -> void:
	var out := {}
	for id: String in PLAYERS:
		out[id] = _colours(id)
		print(id, " ", out[id])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("wrote ", OUT)
	_glove_map()
	quit(0)


func _colours(id: String) -> Dictionary:
	var scene: Node3D = load(DIR + "%s/%s.scn" % [id, id]).instantiate()
	var picked := {}  # part -> [Color]
	for part: String in PARTS:
		picked[part] = []
	var banded := []  # BANDS x [Color], the hand's
	for b in BANDS:
		banded.append([])
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
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var per := bones.size() / uvs.size()
			var names := []  # bind -> bone name (the binds are by index)
			for k in mi.skin.get_bind_count():
				var n := mi.skin.get_bind_name(k)
				names.append(str(n) if n != &"" else sk.get_bone_name(mi.skin.get_bind_bone(k)))
			var axes := {}  # "Left"/"Right" -> [wrist, wrist to middle fingertip], bound
			for side in ["Left", "Right"]:
				var w := _bound(mi.skin, names, "mixamorig_%sHand" % side)
				var tip := _bound(mi.skin, names, "mixamorig_%sHandMiddle4" % side)
				if tip == Vector3.INF:  # the tip bone not bound (the worker): the last joint on by the one before
					var m3 := _bound(mi.skin, names, "mixamorig_%sHandMiddle3" % side)
					tip = m3 * 2.0 - _bound(mi.skin, names, "mixamorig_%sHandMiddle2" % side)
				if w != Vector3.INF and tip != Vector3.INF:
					axes[side] = [w, tip - w]
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
					var side := "Left" if str(names[_main_bone(bones, weights, v, per)]).contains("Left") else "Right"
					if part == "hand" and axes.has(side):
						var t := _along(verts[v], axes[side])
						banded[clampi(int(t * BANDS), 0, BANDS - 1)].append(c)
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
		res[part + "_skin"] = _skin(Color(res[part][0], res[part][1], res[part][2]))
	# A bare hand's bands are its skin alone: Big Vegas's gold rings are not a glove. A band no
	# vertex fell in takes its neighbour's colour (the hand's, with none at all).
	var bare: bool = res.hand_skin
	if bare:
		for b in BANDS:
			banded[b] = banded[b].filter(_skin)
	var bands := []
	for b in BANDS:
		var near := b
		while near >= 0 and banded[near].is_empty():
			near -= 1
		if near < 0:
			near = b
			while near < BANDS and banded[near].is_empty():
				near += 1
		var c := _median(banded[near]) if near < BANDS else Color(res.hand[0], res.hand[1], res.hand[2])
		bands.append([snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001)])
	res["hand_bands"] = bands
	res["bare_hands"] = bare  # no glove: the first-person one goes bare too
	return res


static func _skin(c: Color) -> bool:
	return c.r > c.g and c.g > c.b and c.v > SKIN_DARK and c.s < SKIN_SAT


## Where the bone `bone` sits in the mesh's own space (from its bind pose); INF if not bound.
static func _bound(skin: Skin, names: Array, bone: String) -> Vector3:
	var k := names.find(bone)
	return skin.get_bind_pose(k).affine_inverse().origin if k != -1 else Vector3.INF


## How far `at` is from the wrist toward the fingertip: 0 at the wrist, 1 at the tip.
static func _along(at: Vector3, axis: Array) -> float:
	var d: Vector3 = axis[1]
	return (at - (axis[0] as Vector3)).dot(d) / d.length_squared()


static func _main_bone(bones: PackedInt32Array, weights: PackedFloat32Array, v: int, per: int) -> int:
	var best := 0
	for k in per:
		if weights[v * per + k] > weights[v * per + best]:
			best = k
	return bones[v * per + best]


## The first-person glove's texels, each with how far it is from the wrist (GLOVE_MAP), drawn by
## rasterizing the glove's triangles in UV space and blending the measure across each.
func _glove_map() -> void:
	var rig: Node3D = load(ARMS).instantiate()
	var mi: MeshInstance3D = rig.find_child("Skeleton3D", true, false).get_node("Mesh")
	var surface := -1
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m and m.resource_name == "Gloves":
			surface = i
	var tex: Texture2D = (mi.mesh.surface_get_material(surface) as StandardMaterial3D).albedo_texture
	var size := Vector2i(tex.get_width(), tex.get_height())
	var arrays := mi.mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per := bones.size() / verts.size()
	var names := []
	for k in mi.skin.get_bind_count():
		names.append(str(mi.skin.get_bind_name(k)))
	var axes := {}
	for side in ["L", "R"]:
		var w := _bound(mi.skin, names, "DEF-hand." + side)
		var m2 := _bound(mi.skin, names, "DEF-f_middle.02." + side)
		var m3 := _bound(mi.skin, names, "DEF-f_middle.03." + side)
		axes[side] = [w, m3 + (m3 - m2) - w]  # the tip: the last joint on by the segment before it
	var t := PackedFloat32Array()
	t.resize(verts.size())
	for v in verts.size():
		var side := "L" if str(names[_main_bone(bones, weights, v, per)]).ends_with(".L") else "R"
		t[v] = _along(verts[v], axes[side])
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for i in range(0, idx.size(), 3):
		var a := idx[i]
		var b := idx[i + 1]
		var c := idx[i + 2]
		var tile := uvs[a].floor()  # the glove's UVs sit in a UDIM tile of their own (1003)
		var pa := (uvs[a] - tile) * Vector2(size)
		var pb := (uvs[b] - tile) * Vector2(size)
		var pc := (uvs[c] - tile) * Vector2(size)
		var area := (pb - pa).cross(pc - pa)
		if absf(area) < 0.0001:
			continue
		var lo := Vector2i(pa.min(pb).min(pc).floor()).clamp(Vector2i.ZERO, size - Vector2i.ONE)
		var hi := Vector2i(pa.max(pb).max(pc).ceil()).clamp(Vector2i.ZERO, size - Vector2i.ONE)
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var p := Vector2(x + 0.5, y + 0.5)
				var wa := (pb - p).cross(pc - p) / area
				var wb := (pc - p).cross(pa - p) / area
				var wc := 1.0 - wa - wb
				if wa < -0.01 or wb < -0.01 or wc < -0.01:
					continue
				var along := wa * t[a] + wb * t[b] + wc * t[c]
				img.set_pixel(x, y, Color(clampf((along - GLOVE_T0) / GLOVE_T_SPAN, 0.0, 1.0), 1.0, 0.0))
	rig.free()
	img.save_png(ProjectSettings.globalize_path(GLOVE_MAP))
	print("wrote ", GLOVE_MAP)


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
