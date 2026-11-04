extends SceneTree
## data/heap_mask.json: the junkyard's starting height, coarse, for tools/build_world.gd (it can't load
## scripts/pile.gd). Run after changing the heap's shape, before building the world:
##   Godot.exe --headless --path . -s res://tools/heap_mask.gd
const CELLS := 8  # the heap's cells to one here (2 m)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await physics_frame
	var pile: Node = get_first_node(main)
	var w: int = pile.GRID_X / CELLS
	var h: int = pile.GRID_Z / CELLS
	var data := PackedByteArray()
	data.resize(w * h)
	for j in pile.GRID_Z:
		for i in pile.GRID_X:
			var k: int = j * w_of(pile) + i
			var o: int = (j / CELLS) * w + i / CELLS
			if o < data.size():
				data[o] = maxi(data[o], mini(int(pile._h[k] * 10.0), 255))
	var c: Vector3 = pile._cell_pos(Vector2i.ZERO)
	var out := {"w": w, "h": h, "cell": pile.CELL * CELLS, "x0": c.x + pile.CENTER.x, "z0": c.z + pile.CENTER.y, "data": Marshalls.raw_to_base64(data)}
	var f := FileAccess.open("res://data/heap_mask.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("heap_mask: ", w, " x ", h)
	quit()


func get_first_node(_main: Node) -> Node:
	return root.get_tree().get_first_node_in_group("bullet_pile")


func w_of(pile: Node) -> int:
	return pile.GRID_X
