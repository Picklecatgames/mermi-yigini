extends SceneTree
## Headless check for the scrap heap (scripts/pile.gd): it starts at rest under the roof with its
## volume matching the count; taking from the foot of the face lets what is above settle; enough
## takes off one steep spot make that part of the face give way, the top comes down, pieces
## tumble off it and shove a player standing below; through all of it no volume is made or lost.
##   Godot.exe --headless --path . -s res://tools/scrap_check.gd

var _collapses := 0


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var pile: Node3D = main.get_node("Pile")
	print("heap built in %d ms (with the hall)" % (Time.get_ticks_msec() - t0))
	gs.scrap_collapse.connect(func(_c: Vector2i, _r: int, _s: int, _at: int) -> void: _collapses += 1)
	for i in 3:
		await physics_frame
	var h: PackedFloat32Array = pile._h
	var gx: int = pile.GRID_X
	var gz: int = pile.GRID_Z
	var worst := 0.0
	var over := 0.0
	var top := 0.0
	for j in gz - 1:
		for i in gx - 1:
			var k := j * gx + i
			worst = maxf(worst, maxf(absf(h[k] - h[k + 1]), absf(h[k] - h[k + gx])))
			over = maxf(over, h[k] - pile._ceil[k])
			top = maxf(top, h[k])
	print("unit %.7f m³, top %.2f m, steepest step %.3f (lock %.3f)" % [pile.unit, top, worst, pile.LOCK_STEP])
	assert(worst <= pile.LOCK_STEP + 1e-4, "the heap starts at rest")
	assert(over <= 1e-4, "nothing over the roof")
	assert(top > 8.5, "packed up to the roof")
	assert(not pile._any_active, "nothing sliding at the start")
	var v0 := _volume(pile)
	var expect: float = (gs.PILE_START - pile.spill_pieces) * pile.unit
	assert(absf(v0 - expect) / expect < 1e-4, "the heap holds the count (%.1f m³, %.1f expected)" % [v0, expect])
	assert(pile._id_index.size() == pile.spill_pieces, "loose pieces on the floor")

	# The steepest spot on the lower face, near the middle of the hall.
	var dig := Vector2i(-1, -1)
	var steep := 0.0
	for j in range(gz / 2 - 30, gz / 2 + 30):
		for i in range(1, gx - 1):
			var k := j * gx + i
			if h[k] > 0.6 and h[k] < 1.6:
				var s := absf(h[k + 1] - h[k - 1])
				if s > steep:
					steep = s
					dig = Vector2i(i, j)
	assert(dig.x >= 0, "a foot to dig at")
	var at: Vector3 = pile.cell_world(dig)
	var above := dig + Vector2i(-4, 0)  # uphill: the face rises to the west
	var above_h: float = h[above.y * gx + above.x]
	print("digging at %s (%.2f m up), %.2f m above it at the start" % [at, at.y, above_h])

	# A player standing in front of the foot, in the way of what comes down.
	var pl: CharacterBody3D = main.get_node("Player")
	pl.global_position = at + Vector3(1.6, 0, 0)
	pl.global_position.y = pile.surface_y(pl.global_position) + 0.05
	var shoved := 0.0
	var taken := 0
	var settled_seen := false
	for n in 400:
		taken += gs.request_take_bullets(4000, Vector3(at.x, pile.surface_y(at), at.z))
		for f in 30:
			await physics_frame
			shoved = maxf(shoved, pl._shove.length())
		if not settled_seen and pile._h[above.y * gx + above.x] < above_h - 0.01:
			settled_seen = true
			print("after %d pieces the scrap above came down %.2f m" % [taken, above_h - pile._h[above.y * gx + above.x]])
		if _collapses > 0:
			break
	assert(settled_seen, "taking from the foot lets the scrap above settle")
	assert(_collapses > 0, "takes off one steep spot make the face give way")
	var debris: int = pile._debris.size()
	print("face gave way after %d pieces taken; %d pieces tumbling" % [taken, debris])
	assert(debris > 0, "pieces tumble off the face")
	for f in 240:
		await physics_frame
		shoved = maxf(shoved, pl._shove.length())
		if not pile._any_active:
			break
	print("player shoved at up to %.2f m/s" % shoved)
	assert(shoved > 0.5, "the fall shoves the player")
	for f in 1200:
		if not pile._any_active and pile._digs.is_empty():
			break
		await physics_frame
	assert(not pile._any_active, "the face comes to rest")
	assert(not pile._any_slump, "and locks again")
	var v1 := _volume(pile)
	var gone: float = taken * pile.unit
	print("volume %.3f -> %.3f m³, %.3f taken" % [v0, v1, gone])
	assert(absf((v0 - v1) - gone) < 0.02, "nothing made or lost but what was taken")
	await _pieces(gs, pile)
	print("scrap_check OK")
	quit()


## Every piece of the heap is its own (2026-11-02): a ray onto a face piece hits that piece, it
## is outlined and taken by its id; the one under it shows, lower, and is taken the same way;
## dig the heap away under one and it falls, still there to pick up.
func _pieces(gs: Node, pile: Node3D) -> void:
	# Looking down onto the face a little way up it, toward the north wall: away from where the
	# rest of this check digs. Some of the face shows between its pieces (~13% with only small
	# pieces, tools/build_scrap_face.gd prints it), so 25 rays over a metre: most hit a piece, and
	# the first that does goes on.
	var space := pile.get_world_3d().direct_space_state
	var hit := {}
	var on_piece := 0
	for k in 25:
		var at := Vector3(-5.0 + (k % 5) * 0.25, 0.0, -18.0 + (k / 5) * 0.25)
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 12.0, at + Vector3.DOWN)
		ray.collision_mask = pile.SCRAP_LAYER | 1
		var h := space.intersect_ray(ray)
		if not h.is_empty() and pile._rid_slot.has(h.rid):
			on_piece += 1
			if hit.is_empty():
				hit = h
	assert(on_piece >= 17, "aimed at the heap, a piece is hit, not the heap under it (%d of 25)" % on_piece)
	var s: int = pile._rid_slot[hit.rid]
	assert(pile.is_grabbable(hit.collider, hit.rid, hit.position) and pile.loose_id(hit.collider, hit.rid) == pile._slot_id[s], "that piece is the one taken")
	pile.highlight(hit.position, true, hit.rid)
	assert(pile._marked == s and pile._mark_mi.visible, "and outlined")
	var id: int = pile._slot_id[s]
	var y: float = (pile.global_transform * pile._slot_at(s)).origin.y
	print("aimed at piece %d (%s), %.2f m up, the heap %.2f m there" % [s, pile._slot_part[s], y, pile.surface_y(hit.position)])
	var v0 := _volume(pile)
	for n in 5:
		gs.player().carried = 0
		assert(gs.request_pick_up_loose(id) == 1, "piece %d is taken" % n)
		for f in 3:
			await physics_frame
		assert(not pile.has_loose(id), "and gone")
		# What shows there next: the piece that lay under it, or (where what is above slid into
		# the gap and covered it) a new one in the face's own slot.
		var under := -1
		var where := Transform3D()
		for other: int in pile._id_index:
			if pile.is_heap_id(other) and pile._slot_of_id(other) == s and other != id:
				under = other
				where = pile._id_index[other][3]
		if under < 0 and pile._slot_id[s] >= 0 and pile._slot_id[s] != id:
			under = pile._slot_id[s]
			where = pile._slot_at(s)
		assert(under >= 0 and pile.has_loose(under), "the next piece shows")
		var at: float = (pile.global_transform * where).origin.y
		print("piece %d taken at %.2f m; the next one at %.2f m (%s)" % [n, y, at, "under it" if pile._id_index.has(under) else "slid over it"])
		# A thin piece leaves little room: the next layer starts right there, never floating up.
		assert(at < y + 0.15 and at > pile.surface_y(pile.global_transform * where.origin) - 0.05, "lying on the heap where the taken one was")
		id = under
		y = at
	assert(_volume(pile) < v0, "their room dug out of the heap")
	pile.highlight(Vector3.ZERO, false)
	# One that tumbled off the face earlier lies on the heap as a loose piece of its own: dig the
	# heap out from under it and it falls, and can still be picked up.
	id = -1
	for other: int in pile._id_index:
		if pile.is_heap_id(other) and pile._height_at(pile._id_index[other][3].origin) > 0.3:
			id = other
			break
	assert(id >= 0, "pieces off the fallen face lie on the heap, each its own")
	var local: Vector3 = pile._id_index[id][3].origin
	for n in 40:
		gs.request_take_bullets(4000, pile.global_transform * local)
		await physics_frame
	var fell := false
	for f in 240:
		await physics_frame
		if pile._moving(id) != null:
			fell = true
		if fell and pile._id_index.has(id):
			break
	assert(fell, "with the heap gone from under it, it falls")
	assert(pile.has_loose(id), "and is still there to pick up (%s)" % ("lying" if pile._id_index.has(id) else "moving"))
	print(("dug out from under, it fell and lies at %.2f m" % (pile.global_transform * pile._id_index[id][3]).origin.y) if pile._id_index.has(id) else "dug out from under, it is still rolling")
	gs.player().carried = 0


func _volume(pile: Node) -> float:
	var v := 0.0
	for y in pile._h:
		v += y
	return v * pile.CELL * pile.CELL
