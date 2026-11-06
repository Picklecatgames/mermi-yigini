extends Node3D
## The crates on the chest stands (a Socket on each, group "chest_socket", meta "level"; its +Z
## faces the row's front). The old hall's builder put the stands up; the open ground
## (tools/build_world.gd) has none yet, so nothing shows (docs/ayrintilar.md "Eski tasarımdan kodda kalanlar").
## Models: assets/props/chests/chest_NN.gltf, textures in chest_NN/ (tools/build_chests.py), 1 m wide, bottom on the origin,
## front on +Z. Each is drawn wider the higher its level: the reward grows down the row. A level
## without a model yet stays an empty stand. Opening them comes with the keys (yol haritası 13).

const MODELS := "res://assets/props/chests/chest_%02d.gltf"
## m wide, level 1 .. 11; the final one has its big square. The stands' tops widen 0.75 → 0.95 m:
## a crate fills its top and overhangs a little, big enough to look like a prize (2026-10-22: at
## 0.5 → 0.85 they read as trinkets).
const WIDTH_FIRST := 0.8
const WIDTH_LAST := 1.15
const WIDTH_FINAL := 1.8


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
