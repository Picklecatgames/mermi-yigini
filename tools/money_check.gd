extends SceneTree
## Headless check for the cash on the boss's desk (scripts/money_pile.gd):
##   Godot.exe --headless --path . -s res://tools/money_check.gd
## It follows the local player's gold up and down, never shrinks as gold grows, and the full heap
## stays on the desk mat and under the desk lamp's shade.


func _initialize() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var cash := arena.find_child("Cash", true, false) as MultiMeshInstance3D
	assert(cash and cash.multimesh, "desk has its cash")
	var mm := cash.multimesh
	var last := -1
	for g in [0, 1, 20, 500, 2000, 200000, 20000000, 2000000000]:
		gs.player().gold = g
		gs.gold_changed.emit(g)
		var n := mm.visible_instance_count
		assert(n >= last, "$%d shows %d bundles, fewer than before (%d)" % [g, n, last])
		last = n
	assert(mm.visible_instance_count == mm.instance_count, "all bundles out at $2B")
	# The headless renderer keeps no MultiMesh data: read the layout itself.
	var top := 0.0
	for xf: Transform3D in cash.layout(cash.area):
		var p := xf.origin
		assert(absf(p.x) <= cash.area.x / 2.0 and absf(p.z) <= cash.area.y / 2.0, "bundle on the mat: %s" % p)
		top = maxf(top, p.y)
	assert(top > 0.15 and top < 0.5, "heap tops out at %.2f m over the desk" % top)
	gs.player().gold = 0
	gs.gold_changed.emit(0)
	assert(mm.visible_instance_count == 0, "no gold, no cash")
	print("money_check OK: %d bundles, heap %.2f m tall" % [mm.instance_count, top])
	quit()
