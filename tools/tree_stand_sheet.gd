extends SceneTree
## Every tree's bottom 7 m from two sides, on a floor where tools/tree_stand.gd says the ground goes,
## its collision posts red: to see that each one stands and that the posts are in the trunk.
##   Godot.exe --path . --position -10000,-10000 --resolution 300x300 -s res://tools/tree_stand_sheet.gd
## Lands in user://tree_stand_<n>.png, 20 kinds to a sheet, left to right, two tiles each.
const STAND := preload("res://tools/tree_stand.gd")
const K := preload("res://tools/orman_kinds.gd")
const P := "res://assets/env/orman/forest_pack_psx.scn"
const CYPRESS := "res://assets/env/orman/cypress_psx.scn"
const CHERRY := "res://assets/env/orman/cherry_psx.scn"
const TILE := 300
const COLS := 8
const ROWS := 5
const PACK := [
	["Tree_Trunk_01_Tree_Trunk_01_0", "Tree_Branches_01_001_Tree_Branches_01_0", 1.55],
	["Tree_Trunk_01_001_Tree_Trunk_01_0", "Tree_Branches_01_Tree_Branches_01_0", 1.12],
	["Tree_Trunk_01_002_Tree_Trunk_01_0", "Tree_Branches_01_002_Tree_Branches_01_0", 1.22],
	["Tree_Trunk_02_Tree_Trunk_02_0", "Tree_Branches_02_Tree_Branches_02_0", 1.55],
]


func _initialize() -> void:
	_run.call_deferred()


func _parts(file: String, names: Array) -> Array:
	var scene: Node = (load(file) as PackedScene).instantiate()
	var parts := []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if not names.is_empty() and not String(mi.name) in names:
			continue
		var x := Transform3D()
		var n: Node = mi
		while n and n != scene:
			x = (n as Node3D).transform * x
			n = n.get_parent()
		parts.append([mi.mesh, x, String(mi.name)])
	scene.free()
	return parts


func _run() -> void:
	var kinds := []
	if "under" in OS.get_cmdline_user_args():
		kinds.append(["under_010", _parts(P, ["Background_Tree_Atlas_010_Background_Tree_Atlas_0"]), 1.0, 0.05])
		kinds.append(["under_010", _parts(P, ["Background_Tree_Atlas_010_Background_Tree_Atlas_0"]), 1.0, 0.05])
	else:
		_all_kinds(kinds)
	await _sheet(kinds)
	quit()


func _all_kinds(kinds: Array) -> void:
	for n in ["", "_001", "_002", "_003", "_004", "_005", "_006", "_007"]:
		kinds.append(["card" + n, _parts(P, ["Background_Tree_Atlas%s_Background_Tree_Atlas_0" % n]), 0.85, 0.45])
	for k: Array in PACK:
		kinds.append([k[0], _parts(P, [k[0], k[1]]), k[2], 0.7])
	kinds.append(["cypress", _parts(CYPRESS, []), 2.8, 0.34])
	kinds.append(["cherry", _parts(CHERRY, []), 2.8, 0.56])
	for k: Array in K.TREES:
		var ps := _parts(K.scene(k[0]), k[1])
		var box := AABB()
		for i in ps.size():
			var a: AABB = ps[i][1] * (ps[i][0] as Mesh).get_aabb()
			box = a if i == 0 else box.merge(a)
		kinds.append([k[2], ps, (k[4].x + k[4].y) * 0.5 / box.size.y, k[5]])


func _sheet(kinds: Array) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.6, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	world.add_child(sun)
	var floor_look := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(60.0, 4.0, 60.0)
	floor_look.position.y = -2.0
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.42, 0.25)
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = floor_mat
	floor_look.mesh = plane
	world.add_child(floor_look)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.1, 0.1, 0.55)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 10.0
	world.add_child(cam)
	cam.make_current()
	var sheet: Image = null
	var slot := 0
	var sheet_n := 0
	for k: Array in kinds:
		var parts: Array = k[1]
		var solid := []
		for part: Array in parts:
			if String(part[2]).contains("Trunk"):
				solid.append(part)
		if solid.is_empty():
			solid = parts
		var m := STAND.measure(solid, k[2], k[3], String(k[0]))
		print("%-34s H %4.1f  sunk %.2f  width %.2f  ok %s" % [String(k[0]).left(34), m.height, m.lowest, m.width, m.ok])
		var holder := Node3D.new()
		holder.scale = Vector3.ONE * k[2]
		holder.position = -m.foot * k[2]
		world.add_child(holder)
		for part: Array in parts:
			var mi := MeshInstance3D.new()
			mi.mesh = part[0]
			mi.transform = part[1]
			holder.add_child(mi)
		for post: Array in m.posts:
			var c := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = post[1]
			cyl.bottom_radius = post[1]
			cyl.height = 0.8 / k[2]
			cyl.material = red
			c.mesh = cyl
			c.position = post[0]
			holder.add_child(c)
		for side in 2:
			cam.look_at_from_position(Vector3(0.0, 4.0, 45.0) if side == 0 else Vector3(45.0, 4.0, 0.0), Vector3(0.0, 4.0, 0.0))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(TILE, TILE)
			if sheet == null:
				sheet = Image.create(TILE * COLS, TILE * ROWS, false, Image.FORMAT_RGB8)
			sheet.blit_rect(img, Rect2i(0, 0, TILE, TILE), Vector2i(slot % COLS, slot / COLS) * TILE)
			slot += 1
		holder.free()
		if slot == COLS * ROWS:
			sheet.save_png("user://tree_stand_%d.png" % sheet_n)
			sheet_n += 1
			sheet = null
			slot = 0
	if sheet != null:
		sheet.save_png("user://tree_stand_%d.png" % sheet_n)
