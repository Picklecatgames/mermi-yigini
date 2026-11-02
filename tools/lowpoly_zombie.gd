extends SceneTree
## A built zombie scene (tools/build_zombies.gd) as its low poly version, next to it as
## <name>_lp.scn (2026-11-02, the user: the game goes low poly). The skeleton, the skin and the
## bone weights stay as they are, so the shared clips (zombie_anims.res) play on it unchanged:
## only the triangles get fewer (meshoptimizer's LODs, the one nearest TRIS) and every triangle
## gets its own flat normal and one flat colour.
## Colour goes by body part, as a low poly character is painted: each triangle belongs to the
## REGIONS part its strongest bone is in (Mixamo names, the same on every zombie), each part gets
## PART_COLOURS colours from the albedo under it (k-means), specks melt into the colour round them
## within the part, and every colour snaps to tools/lowpoly_palette.json.
## Cutout faces (hair, torn cloth) under half alpha are dropped.
##   Godot.exe --headless --path . -s res://tools/lowpoly_zombie.gd -- prisoner [copzombie ...]
## With psx among the args, the PS1 horror version instead, <name>_psx.scn (2026-11-02, the user:
## "close to realistic gore horror", not the flat mobile look): the same fewer triangles and the
## rig untouched, but the real texture kept, shrunk to PSX_TEX, unfiltered, on materials/psx.gdshader.

const OUT := "res://assets/characters/zombies/%s/%s%s.scn"
const TRIS := 2500  # per surface, about: the face and hands keep their shape
const PART_COLOURS := 2  # the part's own colour and one more (a stain, a stripe, a belt)
const SAMPLE_PX := 64
const SMOOTH_PASSES := 6
## Body parts by the first word in a bone's name that matches; anything else is the torso.
const REGIONS := [["Head", "head"], ["Neck", "head"], ["Hand", "hands"], ["Foot", "feet"],
		["Toe", "feet"], ["Leg", "legs"], ["Hips", "legs"]]

const PSX_TEX := 256
const PSX_SHADER := preload("res://materials/psx.gdshader")

var _palette: Array[Color] = []


func _init() -> void:
	var ok := true
	var args := OS.get_cmdline_user_args()
	for model: String in args:
		if model != "psx":
			ok = (_psx(model) if "psx" in args else _convert(model)) and ok
	quit(0 if ok else 1)


func _psx(model: String) -> bool:
	var scene: Node3D = load(OUT % [model, model, ""]).instantiate()
	var before := 0
	var after := 0
	var made := {}
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var src: ArrayMesh = mi.mesh
		var out := ArrayMesh.new()
		for s in src.get_surface_count():
			var arrays := src.surface_get_arrays(s)
			var format := src.surface_get_format(s)
			before += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			arrays[Mesh.ARRAY_INDEX] = _fewer(arrays, format)
			arrays[Mesh.ARRAY_TANGENT] = null  # no normal map
			after += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			var std := src.surface_get_material(s) as StandardMaterial3D
			if not made.has(std):
				var mat := ShaderMaterial.new()
				mat.shader = PSX_SHADER
				if std and std.albedo_texture:
					var img: Image = std.albedo_texture.get_image().duplicate()
					img.decompress()
					img.resize(PSX_TEX, PSX_TEX, Image.INTERPOLATE_LANCZOS)
					mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
				if std:
					mat.set_shader_parameter("tint", std.albedo_color)
					if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						mat.set_shader_parameter("alpha_cut", 0.5)
				made[std] = mat
			out.surface_set_material(s, made[std])
		mi.mesh = out
	var packed := PackedScene.new()
	packed.pack(scene)
	var path := OUT % [model, model, "_psx"]
	var err := ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
	print("%s psx: %d -> %d tris, saved %s err=%d" % [model, before, after, path, err])
	scene.free()
	return err == OK


func _convert(model: String) -> bool:
	var scene: Node3D = load(OUT % [model, model, ""]).instantiate()
	var sk: Skeleton3D = scene.get_node("Skeleton3D")
	var before := 0
	var after := 0
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.85
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var part_of := _parts(mi, sk)
		var src: ArrayMesh = mi.mesh
		var out := ArrayMesh.new()
		for s in src.get_surface_count():
			var arrays := src.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			before += idx.size() / 3
			idx = _fewer(arrays, src.surface_get_format(s))
			var flat := _flat(arrays, idx, src.surface_get_material(s), src.surface_get_format(s), part_of)
			after += (flat[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flat, [], {},
					src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			out.surface_set_material(s, mat)
		mi.mesh = out
	var packed := PackedScene.new()
	packed.pack(scene)
	var path := OUT % [model, model, "_lp"]
	var err := ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
	print("%s: %d -> %d tris, saved %s err=%d" % [model, before, after, path, err])
	scene.free()
	return err == OK


## Body part (an index into the part names) of each bone index the mesh's vertices use.
func _parts(mi: MeshInstance3D, sk: Skeleton3D) -> PackedInt32Array:
	var names := []
	for r: Array in REGIONS:
		if not r[1] in names:
			names.append(r[1])
	names.append("torso")
	var count := mi.skin.get_bind_count() if mi.skin else sk.get_bone_count()
	var out := PackedInt32Array()
	for b in count:
		var bone := String(mi.skin.get_bind_name(b)) if mi.skin else sk.get_bone_name(b)
		if mi.skin and bone == "":
			bone = sk.get_bone_name(mi.skin.get_bind_bone(b))
		var part := names.size() - 1
		for r: Array in REGIONS:
			if bone.contains(r[0]):
				part = names.find(r[1])
				break
		out.append(part)
	return out


## The LOD nearest TRIS triangles, its indices into the surface's own vertices.
func _fewer(arrays: Array, format: int) -> PackedInt32Array:
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if idx.size() / 3 <= TRIS:
		return idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, null, "", format)
	im.generate_lods(25.0, 60.0, [])
	var best := idx
	for l in im.get_surface_lod_count(0):
		var lod := im.get_surface_lod_indices(0, l)
		if absi(lod.size() / 3 - TRIS) < absi(best.size() / 3 - TRIS):
			best = lod
	return best


## Every triangle on its own three vertices: its face normal, its colour, the bones as they were.
func _flat(arrays: Array, idx: PackedInt32Array, src: Material, format: int, part_of: PackedInt32Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] else PackedFloat32Array()
	var per := 8 if format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4
	var std := src as StandardMaterial3D
	var img: Image = null
	if std and std.albedo_texture:
		img = std.albedo_texture.get_image().duplicate()
		img.decompress()
		img.resize(SAMPLE_PX, SAMPLE_PX, Image.INTERPOLATE_BILINEAR)
	var tint: Color = std.albedo_color if std else Color(0.6, 0.6, 0.6)
	var cutout := std != null and std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	# One colour, area and body part per triangle first, then the clustering.
	var cols: Array[Color] = []
	var areas: Array[float] = []
	var part := PackedInt32Array()
	var keep: Array[int] = []
	for t in range(0, idx.size(), 3):
		var c := tint
		if img and uvs.size() > 0:
			var a := uvs[idx[t]]
			var b := uvs[idx[t + 1]]
			var d := uvs[idx[t + 2]]
			var mid := (a + b + d) / 3.0
			var acc := Color(0, 0, 0, 0)
			for p: Vector2 in [mid, a, b, d, (a + b) / 2.0, (b + d) / 2.0, (d + a) / 2.0]:  # the whole face: fine stripes and stains average out
				var x := posmod(int(fposmod(p.x, 1.0) * SAMPLE_PX), SAMPLE_PX)
				var y := posmod(int(fposmod(p.y, 1.0) * SAMPLE_PX), SAMPLE_PX)  # Godot UV v runs down like the image
				acc += img.get_pixel(x, y)
			c = acc / 7.0 * tint
		if cutout and c.a < 0.5:
			continue
		keep.append(t)
		cols.append(c)
		areas.append((verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]]).length())
		var weight := {}
		for j in 3:
			var v := idx[t + j]
			for w in per if bones.size() > 0 else 0:
				var bone := bones[v * per + w]
				weight[bone] = weight.get(bone, 0.0) + weights[v * per + w]
		var strongest := -1
		for bone: int in weight:
			if strongest < 0 or weight[bone] > weight[strongest]:
				strongest = bone
		part.append(part_of[strongest] if strongest >= 0 and strongest < part_of.size() else 0)
	cols = _cluster(cols, areas, part, _neighbours(verts, idx, keep))
	var o_v := PackedVector3Array()
	var o_n := PackedVector3Array()
	var o_c := PackedColorArray()
	var o_b := PackedInt32Array()
	var o_w := PackedFloat32Array()
	for k in keep.size():
		var t := keep[k]
		var p0 := verts[idx[t]]
		var p1 := verts[idx[t + 1]]
		var p2 := verts[idx[t + 2]]
		var n := (p2 - p0).cross(p1 - p0).normalized()  # Godot winds clockwise
		for j in 3:
			var v := idx[t + j]
			o_v.append(verts[v])
			o_n.append(n)
			o_c.append(Color(cols[k], 1.0))
			if bones.size() > 0:
				o_b.append_array(bones.slice(v * per, v * per + per))
				o_w.append_array(weights.slice(v * per, v * per + per))
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = o_v
	out[Mesh.ARRAY_NORMAL] = o_n
	out[Mesh.ARRAY_COLOR] = o_c
	out[Mesh.ARRAY_INDEX] = PackedInt32Array(range(o_v.size()))  # zombie_body.gd cuts limbs off by it
	if bones.size() > 0:
		out[Mesh.ARRAY_BONES] = o_b
		out[Mesh.ARRAY_WEIGHTS] = o_w
	return out


## Per body part, k-means over its triangles' colours (area weighted): PART_COLOURS flat colours.
## Then specks melt: each triangle goes with the colour covering most of it and its neighbours in
## the same part. Labels are part * PART_COLOURS + the part's own colour.
func _cluster(cols: Array[Color], areas: Array[float], part: PackedInt32Array, near: Array) -> Array[Color]:
	var centres := {}
	var label := PackedInt32Array()
	label.resize(cols.size())
	var by_part := {}
	for i in cols.size():
		if not by_part.has(part[i]):
			by_part[part[i]] = []
		by_part[part[i]].append(i)
	for p: int in by_part:
		var members: Array = by_part[p]
		var k := mini(PART_COLOURS, members.size())
		members.sort_custom(func(a: int, b: int) -> bool: return cols[a].get_luminance() < cols[b].get_luminance())
		var c: Array[Color] = []
		for j in k:
			c.append(cols[members[int(float(j) / maxf(k - 1, 1) * (members.size() - 1))]])
		for _i in 10:
			var sum: Array[Vector3] = []
			var wsum: Array[float] = []
			for j in k:
				sum.append(Vector3.ZERO)
				wsum.append(0.0)
			for i: int in members:
				var best := 0
				var bd := INF
				for j in k:
					var dc := Vector3(cols[i].r - c[j].r, cols[i].g - c[j].g, cols[i].b - c[j].b).length_squared()
					if dc < bd:
						bd = dc
						best = j
				label[i] = p * PART_COLOURS + best
				sum[best] += Vector3(cols[i].r, cols[i].g, cols[i].b) * areas[i]
				wsum[best] += areas[i]
			for j in k:
				if wsum[j] > 0.0:
					var m := sum[j] / wsum[j]
					c[j] = Color(m.x, m.y, m.z)
		for j in k:
			centres[p * PART_COLOURS + j] = _to_palette(c[j])
	for _p in SMOOTH_PASSES:
		var next := label.duplicate()
		for i in cols.size():
			var votes := {label[i]: areas[i]}
			for j: int in near[i]:
				if part[j] == part[i]:
					votes[label[j]] = votes.get(label[j], 0.0) + areas[j]
			var best: int = label[i]
			for l: int in votes:
				if votes[l] > votes[best]:
					best = l
			next[i] = best
		label = next
	var out: Array[Color] = []
	for i in cols.size():
		out.append(centres[label[i]])
	return out


## Triangles sharing an edge, by where the edge is (UV seams split the vertices, not the surface).
func _neighbours(verts: PackedVector3Array, idx: PackedInt32Array, keep: Array[int]) -> Array:
	var by_edge := {}
	for k in keep.size():
		var t := keep[k]
		for j in 3:
			var a := Vector3i((verts[idx[t + j]] * 10000.0).round())
			var b := Vector3i((verts[idx[t + (j + 1) % 3]] * 10000.0).round())
			var key := [a, b] if a < b else [b, a]
			if not by_edge.has(key):
				by_edge[key] = []
			by_edge[key].append(k)
	var near := []
	near.resize(keep.size())
	for k in keep.size():
		near[k] = []
	for tris: Array in by_edge.values():
		for a: int in tris:
			for b: int in tris:
				if a != b:
					near[a].append(b)
	return near


## The nearest colour of the shared palette (tools/lowpoly_palette.json), redmean distance, sRGB.
func _to_palette(c: Color) -> Color:
	if _palette.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/lowpoly_palette.json"))
		for h: String in data.colours:
			_palette.append(Color.html(h))
	var best := _palette[0]
	var bd := INF
	for p in _palette:
		var rm := (c.r + p.r) / 2.0
		var d := (2.0 + rm) * pow(c.r - p.r, 2) + 4.0 * pow(c.g - p.g, 2) + (3.0 - rm) * pow(c.b - p.b, 2)
		if d < bd:
			bd = d
			best = p
	return best
