extends SceneTree
## The old wood's promise (2026-11-04, the user: "I don't want to see two alike side by side"): for
## each tree the nearest copy of the same mesh, and how many kinds of things lie in each 20 m square
## of its floor. Reads the Forest node of scenes/world.tscn, as built.
##   Godot.exe --headless --path . -s res://tools/wood_mix_check.gd
const MIN_SAME := 6.0  # m: no two trees of one mesh closer (WOOD_APART asks 10, a crowded spot may give less)
const MIN_KINDS := 25
const MIN_FLOOR_KINDS := 60


func _initialize() -> void:  # (not _init: the world's scripts name the autoloads, not in yet then)
	var world: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	var forest: Node = world.get_node("Forest")
	var trees: Dictionary = forest.get_meta("tree_families")  # family -> PackedVector2Array
	var floor_cells := {}  # Vector2i -> {Mesh: true}
	var floor_meshes := {}
	var floor_total := 0
	for g: Array in forest.get("groups"):
		var m: Mesh = g[0]
		var xfs: PackedFloat32Array = g[5]
		var box := m.get_aabb()
		var foot := Vector3(box.get_center().x, box.position.y, box.get_center().z)
		for i in range(0, xfs.size(), 12):
			var x := Transform3D(Vector3(xfs[i], xfs[i + 1], xfs[i + 2]), Vector3(xfs[i + 3], xfs[i + 4], xfs[i + 5]), Vector3(xfs[i + 6], xfs[i + 7], xfs[i + 8]), Vector3(xfs[i + 9], xfs[i + 10], xfs[i + 11]))
			if not g[4]:  # casts no shadow: on the floor
				var at: Vector3 = x * foot
				floor_total += 1
				floor_meshes[m] = true
				var c := Vector2i(floori(at.x / 20.0), floori(at.z / 20.0))
				if not floor_cells.has(c):
					floor_cells[c] = {}
				floor_cells[c][m] = true
	var worst := INF
	var under := 0
	var count := 0
	var sum := 0.0
	for family: String in trees:
		var ps: PackedVector2Array = trees[family]
		for a in ps.size():
			var near := INF
			for b in ps.size():
				if a != b:
					near = minf(near, ps[a].distance_to(ps[b]))
			if near < INF:
				worst = minf(worst, near)
				sum += near
				count += 1
				if near < 10.0:
					under += 1
	var kinds_in := 0
	for c: Vector2i in floor_cells:
		kinds_in += (floor_cells[c] as Dictionary).size()
	print("tree families %d, nearest of one family: worst %.1f m, mean %.1f m, %d of %d under 10 m" % [trees.size(), worst, sum / maxi(1, count), under, count])
	print("floor: %d things, %d meshes, %.1f kinds per 20 m square" % [floor_total, floor_meshes.size(), float(kinds_in) / maxi(1, floor_cells.size())])
	var ok := worst >= MIN_SAME and trees.size() >= MIN_KINDS and floor_meshes.size() >= MIN_FLOOR_KINDS
	print("wood_mix_check: ", "passed" if ok else "FAILED")
	world.free()
	quit(0 if ok else 1)
