extends SceneTree
# Hurda glb'leri: her birinde tek mesh, tek dışbükey çarpışma; boyut ve taban hurda.json'la uyuşuyor mu
func _init() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/hurda/hurda.json"))
	var bad := 0
	for r in data:
		var ps: PackedScene = load(r.glb)
		if ps == null:
			print("YOK ", r.id); bad += 1; continue
		var n := ps.instantiate()
		var meshes := n.find_children("*", "MeshInstance3D", true, false)
		var shapes := n.find_children("*", "CollisionShape3D", true, false)
		var ok := meshes.size() == 1 and shapes.size() == 1 and shapes[0].shape is ConvexPolygonShape3D
		var aabb: AABB = meshes[0].get_aabb() if meshes.size() > 0 else AABB()
		var d: Vector3 = aabb.size - Vector3(r.boyut_m[0], r.boyut_m[1], r.boyut_m[2])
		if d.length() > 0.02 or abs(aabb.position.y) > 0.015: ok = false
		if not ok:
			bad += 1
			print("HATA ", r.id, " mesh=", meshes.size(), " shape=", shapes.size(), " aabb=", aabb)
		n.free()
	print("KONTROL ", data.size(), " parça, ", bad, " hata")
	quit(1 if bad else 0)
