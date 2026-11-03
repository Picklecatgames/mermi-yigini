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
			out.surface_set_material(s, made[std])
		mi.mesh = out
		report.append("%s %d->%d" % [mi.name, counts[mi], after])
	print("psx %s: %s" % [file, ", ".join(report)])
	return scene


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
