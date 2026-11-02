extends SceneTree
## Measures what a take sets moving on the scrap heap (scripts/pile.gd _wake_over): takes 40
## pieces lying under others, one after another, and prints how many fell and how far.
##   Godot.exe --headless --path . -s res://tools/wake_probe.gd


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var pile: Node3D = main.get_node("Pile")
	for i in 3:
		await physics_frame
	var space := pile.get_world_3d().direct_space_state
	var woke := 0
	var falls := PackedFloat32Array()
	var takes := 0
	for s in range(0, pile._slot_part.size(), 997):
		if takes >= 40:
			break
		if pile._slot_id[s] < 0 or not pile._slot_rid[s].is_valid():
			continue
		var t: Transform3D = pile._slot_at(s)
		if pile._height_at(t.origin) < 0.5:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = pile._part_hull[pile._slot_part[s]]
		q.transform = pile.global_transform * t * pile._part_hull_at[pile._slot_part[s]]
		q.margin = pile.WAKE_MARGIN
		q.collision_mask = pile.SCRAP_LAYER
		var over := {}
		for h in space.intersect_shape(q, 16):
			if pile._rid_slot.has(h.rid):
				var o: int = pile._rid_slot[h.rid]
				if pile._slot_at(o).origin.y > t.origin.y:
					over[pile._slot_id[o]] = pile._slot_at(o).origin
		if over.is_empty():
			continue
		gs.player().carried = 0
		gs.request_pick_up_loose(pile._slot_id[s])
		takes += 1
		var moving := {}
		for f in 240:
			await physics_frame
			for body: RigidBody3D in pile._debris:
				if body.has_meta("soft"):
					moving[body.get_meta("id")] = true
			if f > 10 and not pile._debris.any(func(b: RigidBody3D) -> bool: return b.has_meta("soft")):
				break
		woke += moving.size()
		for id: int in moving:
			if pile._id_index.has(id) and over.has(id):
				falls.append((over[id] as Vector3).distance_to((pile._id_index[id][3] as Transform3D).origin))
	falls.sort()
	print("%d takes, %d pieces let go; of the ones right over the taken piece, moved: %s" % [takes, woke, Array(falls).map(func(x: float) -> String: return "%.2f" % x)])
	quit()
