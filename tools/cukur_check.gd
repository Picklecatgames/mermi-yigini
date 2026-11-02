extends SceneTree
# Çukur asetleri (assets/props/cukur): her gltf'te tek görünen mesh, en az bir dışbükey çarpışma,
# boyut ve üçgen sayısı cukur.json'la uyuşuyor mu, üçgen 5.000'i geçmiyor mu
#   Godot.exe --headless --path . -s res://tools/cukur_check.gd

const DIR := "res://assets/props/cukur/"


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "cukur.json"))
	var bad := 0
	for name in data:
		var e: Dictionary = data[name]
		var ps: PackedScene = load(DIR + name + ".gltf")
		if ps == null:
			print("YOK ", name); bad += 1; continue
		var root := ps.instantiate()
		var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
		var shapes: Array = root.find_children("*", "CollisionShape3D", true, false)
		var tris := 0
		var box := AABB()
		for m: MeshInstance3D in meshes:
			for s in m.mesh.get_surface_count():
				tris += m.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
			box = m.get_aabb() if box.size == Vector3.ZERO else box.merge(m.get_aabb())
		var convex := shapes.filter(func(c): return c.shape is ConvexPolygonShape3D).size()
		var want: Array = e.size
		var ok: bool = meshes.size() == 1 and convex >= 1 and convex == shapes.size() and tris <= 5000 \
			and abs(tris - int(e.tris)) <= 2 \
			and box.size.distance_to(Vector3(want[0], want[1], want[2])) < 0.03
		if not ok:
			bad += 1
		print("%s %s mesh=%d convex=%d/%d tris=%d size=%s" % ["OK " if ok else "HATA", name, meshes.size(), convex, shapes.size(), tris, box.size])
		root.free()
	print("SONUC ", "TAMAM" if bad == 0 else "%d HATA" % bad)
	quit(1 if bad else 0)
