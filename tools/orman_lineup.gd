extends SceneTree
## Every tree of the old wood in a row, one PNG per row, to look at the kinds without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1800x620 -s res://tools/orman_lineup.gd
## Lands in user://orman_lineup_<row>.png, the kinds left to right in build_world.gd WOOD_TREES' order.
const P := "res://assets/env/orman/forest_pack_psx.scn"
const AT := "Background_Tree_Atlas%s_Background_Tree_Atlas_0"
const ROWS := [
	[[P, [AT % ""]], [P, [AT % "_001"]], [P, [AT % "_002"]], [P, [AT % "_003"]], [P, [AT % "_004"]], [P, [AT % "_005"]], [P, [AT % "_006"]], [P, [AT % "_007"]]],
	[[P, ["Tree_Trunk_01_Tree_Trunk_01_0", "Tree_Branches_01_001_Tree_Branches_01_0"]], [P, ["Tree_Trunk_01_001_Tree_Trunk_01_0", "Tree_Branches_01_Tree_Branches_01_0"]],
		[P, ["Tree_Trunk_01_002_Tree_Trunk_01_0", "Tree_Branches_01_002_Tree_Branches_01_0"]], [P, ["Tree_Trunk_02_Tree_Trunk_02_0", "Tree_Branches_02_Tree_Branches_02_0"]],
		["res://assets/env/orman/cypress_psx.scn", []], ["res://assets/env/orman/cherry_psx.scn", []]],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.6, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	w.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 40.0
	w.add_child(cam)
	for r in ROWS.size():
		var row := Node3D.new()
		w.add_child(row)
		var kinds: Array = ROWS[r]
		for i in kinds.size():
			var scene: Node = (load(kinds[i][0]) as PackedScene).instantiate()
			var names: Array = kinds[i][1]
			var holder := Node3D.new()
			holder.position = Vector3((i - kinds.size() * 0.5 + 0.5) * 14.0, 0, 0)
			row.add_child(holder)
			var box := AABB()
			var parts := []
			for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
				if not names.is_empty() and not String(mi.name) in names:
					continue
				var x := Transform3D()
				var n: Node = mi
				while n and n != scene:
					x = (n as Node3D).transform * x
					n = n.get_parent()
				parts.append([mi.mesh, x])
				var b: AABB = x * mi.mesh.get_aabb()
				box = b if parts.size() == 1 else box.merge(b)
			scene.free()
			var fit := 24.0 / box.size.y
			for p: Array in parts:
				var m := MeshInstance3D.new()
				m.mesh = p[0]
				m.transform = Transform3D(Basis().scaled(Vector3.ONE * fit), Vector3.ZERO) * Transform3D(Basis(), -Vector3(box.get_center().x, box.position.y, box.get_center().z)) * p[1]
				holder.add_child(m)
		cam.position = Vector3(0, 12, kinds.size() * 14.0 * 0.5 / tan(deg_to_rad(cam.fov) * 0.5) * 0.42)
		cam.look_at(Vector3(0, 12, 0))
		for f in 12:
			await process_frame
		root.get_texture().get_image().save_png("user://orman_lineup_%d.png" % r)
		row.free()
	quit()
