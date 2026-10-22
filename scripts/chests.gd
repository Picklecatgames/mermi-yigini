extends Node3D
## The crates on the chest stands (tools/build_arena.gd puts a Socket on each, group
## "chest_socket", meta "level"; its +Z faces the heap's side of the hall, so the row looks one way).
## Models: assets/props/chests/chest_NN.glb (tools/build_chests.py), 1 m wide, bottom on the origin,
## front on +Z. Each is drawn wider the higher its level: the reward grows down the row. A level
## without a model yet stays an empty stand. Opening them comes with the keys (yol haritası 13).

const MODELS := "res://assets/props/chests/chest_%02d.glb"
## m wide, level 1 .. 11 (the stands' tops widen 0.75 → 0.95 m); the final one has its big square.
const WIDTH_FIRST := 0.5
const WIDTH_LAST := 0.85
const WIDTH_FINAL := 1.3


static func width(level: int) -> float:
	if level >= 12:
		return WIDTH_FINAL
	return lerpf(WIDTH_FIRST, WIDTH_LAST, (level - 1) / 10.0)


func _ready() -> void:
	for socket: Node3D in get_tree().get_nodes_in_group("chest_socket"):
		var level: int = socket.get_meta("level")
		var path := MODELS % level
		if not ResourceLoader.exists(path):
			continue
		var chest: Node3D = load(path).instantiate()
		chest.name = "Chest%d" % level
		chest.scale = Vector3.ONE * width(level)
		socket.add_child(chest)
		# Solid: a box round it, so players don't walk through and shots stop on it.
		var aabb := AABB()
		for mi: MeshInstance3D in chest.find_children("*", "MeshInstance3D", true, false):
			aabb = aabb.merge(mi.transform * mi.get_aabb())
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = aabb.size
		shape.shape = box
		shape.position = aabb.get_center()
		body.add_child(shape)
		chest.add_child(body)
