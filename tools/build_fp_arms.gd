extends SceneTree
## The first-person arms of each player character, cut from the character itself: every triangle of
## its skinned meshes whose corners all hang mostly on an arm bone (upper arm, forearm, hand and
## fingers, both sides), with what it wears there: sleeves, gloves, rings. The skeleton comes along
## whole; scripts/fp_arms.gd poses its arms from the first-person rig. Writes
## assets/characters/players/<id>/fp_arms.scn:
##   Godot.exe --headless --path . -s res://tools/build_fp_arms.gd --quit-after 600
## Cut from the full character (<id>.scn), not its PS1 version: the PS1 material is lit per vertex
## and the gun's own key and rim (player.gd) never reached it, the hands drew black by day
## (2026-11-03). Their texture still goes the PS1 way: the body's dirty palette
## (lowpoly_zombie.gd PSX_GRADE_OF), PSX_TEX px, unfiltered, no normal map.

const DIR := "res://assets/characters/players/"
const ARM := ["Arm", "ForeArm", "Hand"]  # after "mixamorig_Left"/"mixamorig_Right"; the hand's fingers too
const PSX := preload("res://tools/lowpoly_zombie.gd")
## Over the body's grade, the arms' own (2026-11-06, the hands drew pale grey plastic by day): a
## little blood back under the skin [tone, how much], blotches of it [colour, at most], and no
## shine (the gun's rim light glossed them). The body itself keeps PSX_GRADE_OF. My guess, not a rule.
const SKIN_OF := {"oldman": {"warm": [Color(0.6, 0.45, 0.38), 0.16], "blotch": [Color(0.42, 0.27, 0.22), 0.3],
	"dark": 0.9, "specular": 0.12, "roughness": 1.0}}


func _initialize() -> void:
	var bodies: Dictionary = load("res://scripts/remote_players.gd").BODIES
	for id: String in bodies:
		var scene: Node3D = (load(DIR + "%s/%s.scn" % [id, id]) as PackedScene).instantiate()
		var made := {}
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var std := mi.get_active_material(s) as BaseMaterial3D
				if std != null:
					if not made.has(std):
						made[std] = _ps1(std, id)
					mi.set_surface_override_material(s, made[std])
		var sk: Skeleton3D = scene.get_node("Skeleton3D")
		var kept := 0
		for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", false, false):
			var mesh := _arms_of(mi, sk) if mi.skin else null
			if mesh == null:
				sk.remove_child(mi)
				mi.free()
				continue
			mi.mesh = mesh
			kept += mesh.get_surface_count()
		for n in scene.get_children():
			if n != sk:
				scene.remove_child(n)
				n.free()
		var packed := PackedScene.new()
		packed.pack(scene)
		ResourceSaver.save(packed, DIR + "%s/fp_arms.scn" % id)
		print("%s: %d surfaces" % [id, kept])
		scene.free()
	quit()


## `mi`'s mesh with only its arm triangles (null if it has none), each surface's vertices packed.
func _arms_of(mi: MeshInstance3D, sk: Skeleton3D) -> ArrayMesh:
	var names := []  # bind -> bone name
	for k in mi.skin.get_bind_count():
		var n := mi.skin.get_bind_name(k)
		names.append(str(n) if n != &"" else sk.get_bone_name(mi.skin.get_bind_bone(k)))
	var out := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per := bones.size() / count
		var arm := PackedByteArray()
		arm.resize(count)
		for v in count:
			var best := 0
			for k in per:
				if weights[v * per + k] > weights[v * per + best]:
					best = k
			arm[v] = 1 if _is_arm(names[bones[v * per + best]]) else 0
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for i in range(0, idx.size(), 3):
			if arm[idx[i]] and arm[idx[i + 1]] and arm[idx[i + 2]]:
				keep.append_array([idx[i], idx[i + 1], idx[i + 2]])
		if keep.is_empty():
			continue
		# Only the vertices the kept triangles use, renumbered.
		var remap := {}
		var order := PackedInt32Array()
		for i in keep.size():
			if not remap.has(keep[i]):
				remap[keep[i]] = order.size()
				order.append(keep[i])
			keep[i] = remap[keep[i]]
		var packed := []
		packed.resize(Mesh.ARRAY_MAX)
		for a in Mesh.ARRAY_MAX:
			packed[a] = _pick(arrays[a], order, count) if a != Mesh.ARRAY_INDEX else keep
		for a in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM3 + 1):
			packed[a] = null  # left over from the import; the materials don't read them
		var format: int = mi.mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, packed, [], {}, format)
		out.surface_set_material(out.get_surface_count() - 1, mi.get_active_material(s))
	return out if out.get_surface_count() > 0 else null


## `std` with its texture graded, small and unfiltered.
static func _ps1(std: BaseMaterial3D, id: String) -> BaseMaterial3D:
	var m := std.duplicate() as BaseMaterial3D
	m.normal_enabled = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if std.albedo_texture:
		var img: Image = std.albedo_texture.get_image().duplicate()
		img.decompress()
		img.resize(PSX.PSX_TEX, PSX.PSX_TEX, Image.INTERPOLATE_LANCZOS)
		if PSX.PSX_GRADE_OF.has(id):
			PSX._grade(img, PSX.PSX_GRADE_OF[id])
		if SKIN_OF.has(id):
			_skin(img, SKIN_OF[id])
		img.generate_mipmaps()
		m.albedo_texture = ImageTexture.create_from_image(img)
	if SKIN_OF.has(id):
		m.metallic_specular = SKIN_OF[id].specular
		m.roughness = SKIN_OF[id].roughness
	return m


## SKIN_OF on a graded texture, in place.
static func _skin(img: Image, k: Dictionary) -> void:
	var spots := FastNoiseLite.new()
	spots.seed = 23
	spots.frequency = 0.06
	spots.fractal_octaves = 3
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var d: Color = c.lerp(k.warm[0], k.warm[1]) * float(k.dark)
			var b := clampf(spots.get_noise_2d(x, y) * 2.2 - 0.25, 0.0, 1.0) * float(k.blotch[1])
			d = d.lerp(k.blotch[0] * (0.6 + c.v * 0.6), b)
			d.a = c.a
			img.set_pixel(x, y, d)


static func _is_arm(bone: String) -> bool:
	for side in ["mixamorig_Left", "mixamorig_Right"]:
		if bone.begins_with(side):
			var rest := bone.trim_prefix(side)
			return rest in ARM or rest.begins_with("Hand")
	return false


## The entries of one vertex array at `order`, however many values a vertex has there.
static func _pick(array: Variant, order: PackedInt32Array, count: int) -> Variant:
	if array == null:
		return null
	var out: Variant = array.duplicate()
	out.resize(0)
	var per: int = array.size() / count
	for v in order:
		for k in per:
			out.append(array[v * per + k])
	return out
