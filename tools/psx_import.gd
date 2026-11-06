@tool
extends EditorScenePostImport
## Import script of the guns and the first-person arms (assets/weapons: arms.gltf, the service
## pistol, the laser), the PS1 horror look (2026-11-02, the user: the whole game PS1 horror, "close
## to realistic gore horror", not the flat mobile look). As tools/lowpoly_zombie.gd psx does for the
## zombies: fewer triangles (meshoptimizer's LODs, the one nearest the mesh's budget), the skin and
## bone weights as they are, so every clip and the magazine bones play unchanged; the real colour
## map kept but shrunk to TEX px, unfiltered, on materials/psx.gdshader; no normal or roughness map.
## The source files stay as they are; reimporting them gives the PS1 version.

const Convert := preload("res://tools/psx_convert.gd")
## Triangle budget per mesh node in arms.gltf (the name, or the first name up its path that has
## one): our arms are one mesh for both, each gun one mesh.
const BUDGET := {"Mesh": 2000, "Deagle": 2500, "UZI": 2500, "CZScorpion": 2500, "Minigun": 3000}
## The other files' budget for all their meshes, shared out by each mesh's own count; the rest TRIS.
const FILE_BUDGET := {"service_pistol.glb": 2500, "laser.fbx": 500, "bullet_case.glb": 300,
	"bullet_9mm.glb": 300}
const TRIS := 600  # a special round's tip
const LEAST := 24  # no part goes under this: a hammer, a switch, a screw keep their shape


func _post_import(scene: Node) -> Object:
	var meshes: Array[MeshInstance3D] = []
	var counts := {}
	var total := 0
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is ArrayMesh:
			meshes.append(mi)
			var count := 0
			for s in mi.mesh.get_surface_count():
				count += _tris(mi.mesh, s)
			counts[mi] = count
			total += count
	var file := get_source_file().get_file()
	var made := {}
	var report := []
	for mi in meshes:
		var src := mi.mesh as ArrayMesh
		var tris: int = _budget(mi) if file == "arms.gltf" else int(FILE_BUDGET.get(file, TRIS) * float(counts[mi]) / maxi(total, 1))
		var out := ArrayMesh.new()
		out.resource_name = src.resource_name
		var after := 0
		for s in src.get_surface_count():
			var arrays := src.surface_get_arrays(s)
			var format := src.surface_get_format(s)
			if not arrays[Mesh.ARRAY_INDEX]:
				arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(range((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()))
			# each surface its share of the mesh's budget
			arrays[Mesh.ARRAY_INDEX] = Convert.fewer(arrays, format, maxi(int(tris * float(_tris(src, s)) / counts[mi]), LEAST))
			arrays[Mesh.ARRAY_TANGENT] = null  # no normal map
			after += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			out.surface_set_name(s, src.surface_get_name(s))
			var std := src.surface_get_material(s) as BaseMaterial3D
			if not made.has(std):
				made[std] = Convert.material(std)
				if file == "service_pistol.glb":
					_age_pistol(made[std])
			out.surface_set_material(s, made[std])
		mi.mesh = out
		report.append("%s %d->%d" % [mi.name, counts[mi], after])
	print("psx %s: %s" % [file, ", ".join(report)])
	return scene


## The service pistol's map, old (2026-11-06, the user: its grip drew blue and white): the bright
## blue tape a dark, grimy cloth tape, the steel darker and dull with a brown tinge where it wears,
## the yellow and orange marks faded. Numbers are my guess, not a rule.
static func _age_pistol(mat: ShaderMaterial) -> void:
	var tex := mat.get_shader_parameter("albedo_tex") as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var grime := FastNoiseLite.new()
	grime.seed = 11
	grime.frequency = 0.09
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var n := grime.get_noise_2d(x, y) * 0.5 + 0.5
			var d: Color
			if c.s > 0.3 and c.h > 0.53 and c.h < 0.78:  # blue tape: near black, a little brown
				d = Color(0.085, 0.075, 0.062) * (0.55 + 0.9 * c.v) * (0.8 + 0.4 * n)
			elif c.s < 0.22 and c.v > 0.7 and _near_tape(img, x, y):  # the tape's white scuffs
				d = Color(0.16, 0.15, 0.13) * (0.8 + 0.4 * n)
			elif c.s > 0.35 and (c.h < 0.2 or c.h > 0.9) and c.h > 0.0:  # wood, yellow and orange: duller
				d = Color.from_hsv(c.h, c.s * (0.55 if c.h > 0.09 else 0.85), c.v * 0.75)
			else:  # steel: darker, flatter, worn brown in blotches
				var g := Color.from_hsv(c.h, c.s * 0.5, c.v * 0.62)
				d = g.lerp(Color(0.2, 0.15, 0.11) * (0.6 + c.v), clampf(n * 1.6 - 0.75, 0.0, 0.45))
			d.a = c.a
			img.set_pixel(x, y, d)
	mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))


## Whether blue tape is within 3 px of (x, y).
static func _near_tape(img: Image, x: int, y: int) -> bool:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var px := clampi(x + dx, 0, img.get_width() - 1)
			var py := clampi(y + dy, 0, img.get_height() - 1)
			var c := img.get_pixel(px, py)
			if c.s > 0.3 and c.h > 0.53 and c.h < 0.78:
				return true
	return false


static func _tris(mesh: Mesh, s: int) -> int:
	if mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX:
		return mesh.surface_get_array_index_len(s) / 3
	return mesh.surface_get_array_len(s) / 3


func _budget(mi: Node) -> int:
	var n := mi
	while n:
		if BUDGET.has(String(n.name)):
			return BUDGET[String(n.name)]
		n = n.get_parent()
	return TRIS
