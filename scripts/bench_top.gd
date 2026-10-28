extends StaticBody3D
## The workshop bench (range_dressing.gd _workshop) with its top cleared: upgrades are shown
## happening there (2026-10-24, the user's call). Left on it: the blueprints and the Tesla coil in
## the back right corner. Done at load because parts freed inside the glb instance at build time
## aren't saved in arena.tscn. Shelves and the low-deck drill press stay.

## The wooden vise on the top, part of the desk's own mesh (glb space): its triangles are dropped.
const VISE := AABB(Vector3(-0.37, 0.985, -0.16), Vector3(0.74, 0.3, 0.73))
const HOOK := AABB(Vector3(-0.37, 0.5, 0.375), Vector3(0.74, 0.7, 0.5))  # its handle, hung over the front edge (z 0.366)


const Reveal := preload("res://scripts/reveal.gd")


## The corner round the bench (range_dressing.gd _workshop), world x: on the wall over it the radio,
## posters and their tape, the guns on nails, the lamp (z past WALL_Z; the string of bulbs hangs in
## front of that and stays), low in front of it the carpet and the warm bounce light.
const CORNER_X := Vector2(9.2, 14.0)
const WALL_Z := 27.9
const FLOOR_Z := 26.2
const HOPPER_REACH := 0.8  # m round the hopper: its glow and sticker go with it
const BELONGS := ["radio", "wall_lamp"]  # the bench's own, wherever they stand (their glb's root)


func _ready() -> void:
	# The first main quest opens the bench (GameState QUESTS m01), the corner coming on with it; the
	# hopper waits for the melter.
	var corner := []
	var hopper := []
	var hopper_body: Node3D = null
	for n: Node in get_parent().get_children():
		if n is Node3D and n != self and n.get_child_count() > 0 and String(n.get_child(0).name) == "hopper":
			hopper_body = n
	for n: Node in get_parent().get_children():
		if not n is Node3D or n == self or n == hopper_body:
			continue
		var at: Vector3 = n.global_position
		if hopper_body and at.y < 1.5 and Vector2(at.x, at.z).distance_to(Vector2(hopper_body.global_position.x, hopper_body.global_position.z)) < HOPPER_REACH:
			hopper.append(n)
		elif _in_corner(n, at):
			corner.append(n)
	Reveal.hold(self, "workbench", "Tezgâh", corner)
	if hopper_body:
		Reveal.hold(hopper_body, "melter", "Eritme hunisi", hopper)
	var glb := get_child(0)
	for n: Node3D in glb.get_children():
		if n.name == "Desk":
			_drop_vise(n)
		elif n.name == "P_tesla_coil":
			n.position = Vector3(0.33, 0.98, -0.25)  # back right seen from the hall, inside the shelf post
		elif n.name.begins_with("Wire") or (not n.name.begins_with("Paper_blue")
				and n.position.y > 0.9 and n.position.y < 1.1):  # the top is at 0.98 in the glb
			n.queue_free()


func _in_corner(n: Node3D, at: Vector3) -> bool:
	if n.get_child_count() > 0 and String(n.get_child(0).name) in BELONGS:
		return true  # by name: the arena build may move them
	if at.x < CORNER_X.x or at.x > CORNER_X.y:
		return false
	return at.z >= WALL_Z or (at.z >= FLOOR_Z and at.y < 1.0)


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
