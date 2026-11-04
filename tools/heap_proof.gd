extends SceneTree
## Can real bodies give the pile the user asked for (2026-11-04, a reference of a tight potato heap: "every
## object reads apart; pull one from below and what is above slides down step by step")?
## A small heap on its own, nothing from the game's heap: real pieces poured on a hidden core and left
## to rest, then taken from the foot. It says what moved and how long a frame took.
##   Godot.exe --path . --fixed-fps 60 --position -10000,-10000 --resolution 1280x720 -s res://tools/heap_proof.gd
## Shots: user://proof_*.png

const PIECES := 6000
const SCALE := 1.0           # pieces this much bigger than in the mountain's list (my guess, to judge)
const SIZE := Vector2(0.12, 0.45)  # m, longest side before SCALE
const THINNEST := 0.04       # m, shortest side before SCALE: no thin rods, they read as noise
const KINDS := ["disli", "konserve", "kap", "jant", "boru", "elektronik"]
const CORE := Vector2(4.0, 2.2)  # hidden cone, radius and height
const POUR := 60
const POUR_EVERY := 10

var _parts: Array[Dictionary] = []
var _bodies: Array[RigidBody3D] = []
var _world: Node3D
var _cam: Camera3D


func _initialize() -> void:
	_run()


func _run() -> void:
	seed(4711)
	_world = Node3D.new()
	root.add_child(_world)
	_stage()
	_load()
	print("parts: ", _parts.size())
	await physics_frame
	var made := 0
	var frame := 0
	while made < PIECES:
		if frame % POUR_EVERY == 0:
			for i in POUR:
				_drop()
				made += 1
		frame += 1
		await physics_frame
	print("poured at frame ", frame)
	# Let it come to rest.
	for i in 900:
		await physics_frame
		if i % 60 == 59:
			var moving := _awake()
			if moving < PIECES / 100:
				print("rested after ", i, " frames, awake ", moving)
				break
	var bare := _keep_on_heap()
	await _hush()
	print("on the heap: ", _bodies.size(), ", rolled away: ", bare)
	await _shot("far", Vector3(9.0, 2.6, 0.0), Vector3(0.0, 1.0, 0.0))
	await _shot("near", Vector3(7.0, 1.8, 0.0), Vector3(3.0, 0.9, 0.0))
	await _shot("close", Vector3(5.6, 1.3, 0.3), Vector3(3.2, 0.5, 0.0))
	await _measure("rest", 60)
	await _take(1, "one")
	await _take(12, "twelve")
	await _take(40, "forty")
	quit()


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.62, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.environment.ambient_light_energy = 0.55
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 55.0, 0.0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	_world.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_world.add_child(_cam)
	_cam.make_current()
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	var floor_look := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	floor_look.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.1, 0.09, 0.07)
	plane.material = floor_mat
	floor_body.add_child(floor_look)
	floor_body.physics_material_override = _rough()
	_world.add_child(floor_body)
	# The hidden core: never drawn, the pieces only need a few layers over it.
	var core := StaticBody3D.new()
	var pts := PackedVector3Array([Vector3(0.0, CORE.y, 0.0)])
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector3(cos(a) * CORE.x, 0.0, sin(a) * CORE.x))
	var cone := ConvexPolygonShape3D.new()
	cone.points = pts
	var core_shape := CollisionShape3D.new()
	core_shape.shape = cone
	core.add_child(core_shape)
	core.physics_material_override = _rough()
	_world.add_child(core)


func _rough() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.friction = 1.0
	m.bounce = 0.02
	return m


func _load() -> void:
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/hurda/hurda.json"))
	var dir := "res://assets/props/hurda/"
	for p: Dictionary in list:
		if p.tur not in KINDS:
			continue
		var dims: Array = (p.boyut_m as Array).duplicate()
		dims.sort()
		if dims[2] < SIZE.x or dims[2] > SIZE.y or dims[0] < THINNEST:
			continue
		var path: String = dir + String(p.glb).get_file().get_basename() + "_psx.scn"
		if not ResourceLoader.exists(path):
			path = dir + String(p.glb).get_file()
		var scene: PackedScene = load(path)
		var inst: Node = scene.instantiate()
		var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
		var mesh: Mesh = mi.mesh
		var box: AABB = mesh.get_aabb()
		var hull: ConvexPolygonShape3D = mesh.create_convex_shape(true, true)
		var pts := PackedVector3Array()
		for v in hull.points:
			pts.append((v - box.get_center()) * SCALE)
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		_parts.append({"id": p.id, "mesh": mesh, "mid": box.get_center(), "shape": shape, "mass": clampf(p.kutle_kg, 0.1, 20.0)})
		inst.free()


func _drop() -> void:
	var part: Dictionary = _parts[randi() % _parts.size()]
	var body := RigidBody3D.new()
	body.mass = part.mass
	body.angular_damp = 2.5
	body.linear_damp = 0.1
	body.physics_material_override = _rough()
	var col := CollisionShape3D.new()
	col.shape = part.shape
	body.add_child(col)
	var look := MeshInstance3D.new()
	look.mesh = part.mesh
	look.scale = Vector3.ONE * SCALE
	look.position = -part.mid * SCALE
	body.add_child(look)
	var r := CORE.x * sqrt(randf())
	var a := randf() * TAU
	var y := CORE.y * (1.0 - r / CORE.x) + 2.5 + randf() * 2.0
	body.position = Vector3(cos(a) * r, y, sin(a) * r)
	body.rotation = Vector3(randf(), randf(), randf()) * TAU
	_world.add_child(body)
	_bodies.append(body)


## Everything still, so that what moves after a take moved because of it. A rest as a game would hold it.
func _hush() -> void:
	for b in _bodies:
		b.sleeping = true
	await physics_frame
	await physics_frame
	print("hushed, awake ", _awake())


func _awake() -> int:
	var n := 0
	for b in _bodies:
		if not b.sleeping:
			n += 1
	return n


## Pieces that rolled off the heap count for nothing; they stay, they are just not measured.
func _keep_on_heap() -> int:
	var keep: Array[RigidBody3D] = []
	var away := 0
	for b in _bodies:
		if Vector2(b.position.x, b.position.z).length() < CORE.x + 1.5:
			keep.append(b)
		else:
			away += 1
	_bodies = keep
	return away


func _shot(label: String, from: Vector3, at: Vector3) -> void:
	_cam.look_at_from_position(from, at)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://proof_%s.png" % label)


## Takes `count` pieces at the foot on the +x side, from the bottom up, and follows what they held.
func _take(count: int, label: String) -> void:
	var foot: Array[RigidBody3D] = []
	for b in _bodies:
		if b.position.x > 2.0 and absf(b.position.z) < 1.2 and b.position.y < 1.0:
			foot.append(b)
	foot.sort_custom(func(l: RigidBody3D, r: RigidBody3D) -> bool: return l.position.y < r.position.y)
	var at := Vector3(6.2, 1.5, 0.2)
	var aim := Vector3(3.0, 0.5, 0.0)
	await _shot(label + "_0", at, aim)
	var start := {}
	for b in _bodies:
		start[b] = b.position
	var centre := Vector3.ZERO
	var taken := mini(count, foot.size())
	for i in taken:
		centre += foot[i].position / taken
		_bodies.erase(foot[i])
		start.erase(foot[i])
		foot[i].queue_free()
	# Removing a body does not wake what lay on it: what touched it has to be woken.
	for b in _bodies:
		if b.position.distance_to(centre) < 0.9:
			b.sleeping = false
	var worst := 0.0
	var last_move := 0
	var peak_awake := 0
	var dt_max := 0.0
	for f in 300:
		await physics_frame
		dt_max = maxf(dt_max, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		if f == 20:
			await _shot(label + "_1", at, aim)
		if f == 90:
			await _shot(label + "_2", at, aim)
		if f % 10 == 0:
			var awake := _awake()
			peak_awake = maxi(peak_awake, awake)
			if awake > 3:
				last_move = f
	var moved := 0
	var far_moved := 0
	var high := -1.0
	for b: RigidBody3D in start:
		if not is_instance_valid(b):
			continue
		var d: float = b.position.distance_to(start[b])
		if d > 0.03:
			moved += 1
			high = maxf(high, start[b].y)
		if d > 0.3:
			far_moved += 1
		worst = maxf(worst, d)
	await _shot(label + "_3", at, aim)
	await _hush()
	print("took %d: moved>3cm %d, moved>30cm %d, furthest %.2f m, highest mover started at y=%.2f (taken at y=%.2f), still moving until %.1f s, peak awake %d, worst physics %.1f ms" % [taken, moved, far_moved, worst, high, centre.y, last_move / 60.0, peak_awake, dt_max * 1000.0])


func _measure(label: String, frames: int) -> void:
	var worst := 0.0
	for f in frames:
		await process_frame
		worst = maxf(worst, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	print("%s: physics worst %.1f ms, draw calls %d, primitives %d, awake %d" % [label, worst * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), _awake()])
