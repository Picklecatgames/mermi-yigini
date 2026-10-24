extends StaticBody3D
## The workshop bench (range_dressing.gd _workshop) with its top cleared: upgrades are shown
## happening there (2026-10-24, the user's call). Left on it: the blueprints and the Tesla coil in
## the back right corner. Done at load because parts freed inside the glb instance at build time
## aren't saved in arena.tscn. Shelves and the low-deck drill press stay.

## The wooden vise on the top, part of the desk's own mesh (glb space): its triangles are dropped.
const VISE := AABB(Vector3(-0.37, 0.985, -0.16), Vector3(0.74, 0.3, 0.73))
const HOOK := AABB(Vector3(-0.37, 0.5, 0.375), Vector3(0.74, 0.7, 0.5))  # its handle, hung over the front edge (z 0.366)


func _ready() -> void:
	var glb := get_child(0)
	for n: Node3D in glb.get_children():
		if n.name == "Desk":
			_drop_vise(n)
		elif n.name == "P_tesla_coil":
			n.position = Vector3(0.33, 0.98, -0.25)  # back right seen from the hall, inside the shelf post
		elif n.name.begins_with("Wire") or (not n.name.begins_with("Paper_blue")
				and n.position.y > 0.9 and n.position.y < 1.1):  # the top is at 0.98 in the glb
			n.queue_free()


func _drop_vise(desk: MeshInstance3D) -> void:
	var src := desk.mesh
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var mid := desk.transform * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
		if not VISE.has_point(mid) and not HOOK.has_point(mid):
			kept.append_array([idx[t], idx[t + 1], idx[t + 2]])
	arrays[Mesh.ARRAY_INDEX] = kept
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, src.surface_get_material(0))
	desk.mesh = mesh
