extends SceneTree
## Close looks at the hands on each gun, first person and on the other players' bodies, for checking
## the grip (fingers round the grip and on the trigger, the left hand on the gun, the arm's angle)
## without playing. Every character, every gun; relaxed, aimed (the minigun: barrels turning), at
## the peak of a round's kick and walking:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/hands_shot.gd -- --tag=before
## Saves user://hands_<tag>_fp_<gun>_<character>.png and user://hands_<tag>_tp_<gun>_<character>.png:
## one row per state; first person the player's view and the arms alone from its right, its left and
## below, third person the body's hands from its right, its left and ahead. Needs a window: headless does not draw.
## --guns=uzi,minigun only those; --chars=worker only those.

const CELL := Vector2i(400, 300)
const STATES := ["rest", "aim", "fire", "walk"]
const BG := Color(0.55, 0.6, 0.65)
## Third person: [hand looked at ("R", "L" or between them), camera offset (m) in the world, the body
## facing -Z: x its right, y up].
const TP_VIEWS := {"right": ["R", Vector3(0.4, 0.08, 0.12)], "left": ["L", Vector3(-0.4, 0.1, -0.12)],
	"whole": ["", Vector3(0.9, 0.3, -1.3)]}
## First person: the same in the view camera's frame (x right, y up, -z ahead).
const FP_VIEWS := {"right": ["R", Vector3(0.25, 0.05, 0.02)], "left": ["L", Vector3(-0.25, 0.05, 0.0)],
	"below": ["", Vector3(0.05, -0.3, -0.05)]}

var _tag := "now"
var _guns: Array = []
var _chars: Array = []
var _gs: Node
var _raw := false  # --raw: every picture also whole, user://hands_<tag>/
var _rig := false  # --rig: the first-person rig's own gloved arms drawn too, on the bodies


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
		elif a.begins_with("--guns="):
			_guns = a.trim_prefix("--guns=").split(",")
		elif a.begins_with("--chars="):
			_chars = a.trim_prefix("--chars=").split(",")
		elif a == "--raw":
			_raw = true
		elif a == "--rig":
			_rig = true
	Engine.max_fps = 60
	_gs = root.get_node("GameState")
	if _chars.is_empty():
		_chars = _gs.CHARACTERS.keys()
	print("pictures in ", OS.get_user_data_dir())
	if _raw:
		DirAccess.make_dir_recursive_absolute("user://hands_" + _tag)
	await _first_person()
	await _third_person()
	quit()


func _wanted(g: int) -> bool:
	return g > 0 and _gs.GUNS[g].ready and (_guns.is_empty() or _gs.GUNS[g].id in _guns)


# --- First person ---

func _first_person() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	var vm: Node3D = player.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	var view: Camera3D = player.get_node("ViewmodelView/SubViewport/Camera")
	var sub: SubViewport = player.get_node("ViewmodelView/SubViewport")
	var close := Camera3D.new()
	close.cull_mask = view.cull_mask
	close.fov = 50.0
	close.near = 0.01
	sub.add_child(close)
	var lamp := DirectionalLight3D.new()  # the hall is dark; the arms alone, lit from the camera
	lamp.light_cull_mask = view.cull_mask & ~1
	lamp.light_energy = 4.0
	lamp.visible = false
	sub.add_child(lamp)
	await process_frame
	_gs.infinite_ammo = true
	_gs.player().levels["magazine"] = 6
	_gs.player().carried = 400
	_gs.player().has_pistol = true
	_gs.player().levels.deagle = 1
	var sheets := {}  # gun -> cells, row by row
	for ch: String in _chars:
		_gs.request_pick_character(ch)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if _rig:
			await process_frame
			vm.dress(vm._skel, "")
		for g in _gs.GUNS.size():
			if not _wanted(g):
				continue
			var id: String = _gs.GUNS[g].id
			_gs.request_select_gun(g)
			while vm.gun != g or vm.clip != "":
				await process_frame
			for st: String in STATES:
				player.global_position = Vector3(12.0, 0.0, -3.0)
				player._yaw = -PI / 2.0
				player._pitch = -0.05
				player.velocity = Vector3.ZERO
				player.reset_physics_interpolation()
				await _wait(0.5)
				match st:
					"aim":
						Input.action_press("aim")
						await _wait(0.6)
					"fire":
						Input.action_press("aim")  # the minigun's barrels up first
						await _wait(0.8 if vm._kit.has("spin") else 0.3)
						Input.action_press("fire")
						await _wait(0.45)
					"walk":
						Input.action_press("move_left")
						await _wait(0.55)
				var cells: Array = sheets.get_or_add(id + "_" + ch, [])
				close.current = false
				await _frames(2)
				cells.append(_grab(root.get_texture().get_image(), "fp_%s_%s_%s_view" % [id, ch, st]))
				for v: String in FP_VIEWS:
					var at := _between(vm._skel, "DEF-hand.R", "DEF-hand.L", FP_VIEWS[v][0])
					close.look_at_from_position(at + view.global_basis * (FP_VIEWS[v][1] as Vector3), at, view.global_basis.y)
					lamp.global_basis = close.global_basis
					close.current = true
					lamp.visible = true
					await _frames(2)
					cells.append(_grab(sub.get_texture().get_image(), "fp_%s_%s_%s_%s" % [id, ch, st, v]))
				close.current = false
				lamp.visible = false
				view.current = true
				for a: String in ["aim", "fire", "move_left"]:
					Input.action_release(a)
				print("fp %s %s %s" % [ch, id, st])
	for id: String in sheets:
		_sheet(sheets[id], FP_VIEWS.size() + 1, "hands_%s_fp_%s" % [_tag, id])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.free()
	await _frames(2)


# --- Third person ---

var _mgr: Node3D
var _aim := false
var _pos := Vector3.ZERO
var _walk := false


func _third_person() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = BG
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.01
	root.add_child(cam)
	cam.make_current()
	_mgr = load("res://scripts/remote_players.gd").new()
	root.add_child(_mgr)
	await process_frame
	await _hold(0.2)
	if _rig:
		(_mgr.character(7)._fp_skel.get_node("Mesh") as Node3D).visible = true
	var sheets := {}
	for ch: String in _chars:
		_gs.character_changed.emit(7, ch)
		await _hold(0.5)
		for g in _gs.GUNS.size():
			if not _wanted(g):
				continue
			var id: String = _gs.GUNS[g].id
			_gs.gun_changed.emit(7, g)
			for st: String in STATES:
				_pos = Vector3.ZERO
				_aim = st == "aim" or (st == "fire" and _gs.GUNS[g].id == "minigun")
				_walk = st == "walk"
				await _hold(0.9)
				if st == "fire":
					_mgr.character(7).shoot()
					await _hold(0.035)
				var c = _mgr.character(7)
				var cells: Array = sheets.get_or_add(id + "_" + ch, [])
				for v: String in TP_VIEWS:
					var sk: Skeleton3D = c._skel
					var at := _between(sk, sk.get_bone_name(c._hand["R_wrist"]), sk.get_bone_name(c._hand["L_wrist"]), TP_VIEWS[v][0])
					var off: Vector3 = TP_VIEWS[v][1]
					cam.look_at_from_position(at + off * (1.0 if v != "whole" else c._size), at)
					await RenderingServer.frame_post_draw
					cells.append(_grab(root.get_texture().get_image(), "tp_%s_%s_%s_%s" % [id, ch, st, v]))
				print("tp %s %s %s" % [ch, id, st])
	for id: String in sheets:
		_sheet(sheets[id], TP_VIEWS.size(), "hands_%s_tp_%s" % [_tag, id])


func _hold(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		var t := Time.get_ticks_msec() / 1000.0
		if _walk:
			_pos = Vector3(0.0, 0.0, -3.0 * (Time.get_ticks_msec() - t0) / 1000.0)
		_mgr._on_pose(7, t, _pos, 0.0, 0.0, 0, false, false, _aim)
		await process_frame


## Where hand `which` ("R", "L"; "" between the two) of `sk` is, a little past the wrist into the palm.
func _between(sk: Skeleton3D, right: String, left: String, which: String) -> Vector3:
	var r := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(right))
	var l := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(left))
	match which:
		"R":
			return r.origin
		"L":
			return l.origin
	return r.origin.lerp(l.origin, 0.5)


# --- Pictures ---

func _grab(img: Image, file: String) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(BG)
	out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	if _raw:
		out.save_png("user://hands_%s/%s.png" % [_tag, file])
	# The middle 4:3 of the picture.
	var w := mini(out.get_width(), out.get_height() * 4 / 3)
	var crop := out.get_region(Rect2i((out.get_width() - w) / 2, 0, w, out.get_height()))
	crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	return crop


func _sheet(cells: Array, cols: int, file: String) -> void:
	var rows := ceili(cells.size() / float(cols))
	var img := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in cells.size():
		img.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % cols, i / cols) * CELL)
	img.save_png("user://%s.png" % file)
	print("saved ", file)


func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
