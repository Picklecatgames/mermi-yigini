extends SceneTree
## The open ground's two promises (2026-11-04, the user: "walking stays inside a limit"; "what's laid
## out round the area comes in packets, every kind of a tree in one row"):
## 1. Nothing but the ground stops a walker: out of the workshop past the old hall's box, and at each
##    side of the world up to the cliff, which holds them on the map.
## 2. Each scattered thing is one single thing: no scene of several plants, no wood on a grid.
##   Godot.exe --headless --path . -s res://tools/world_limit_check.gd

const WORLD := Rect2(-236.0, -220.0, 500.0, 440.0)  # build_world.gd WORLD
const RIM_CENTRE := Vector2(14.0, 0.0)  # build_world.gd
const RIM_RADII := Vector2(215.0, 190.0)

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	_failed = _failed or not cond


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await physics_frame
	gs.request_pick_character("boss")
	_scatter(main.get_node("World"))
	var me: CharacterBody3D = main.get_node("Player")
	for i in 10:
		await physics_frame
	# Off the pad, well past where the old hall's box stopped us (x 13.6, z 27.6).
	var at := await _walk(me, Vector3(12.0, 0.6, 3.0), Vector3(1, 0, 0.4), 6.0)
	_ok(at.x > 22.0, "walks out of the workshop east, past x 13.6 (to x %.1f)" % at.x)
	at = await _walk(me, Vector3(20.0, 1.0, 15.0), Vector3(0, 0, 1), 6.0)
	_ok(at.z > 29.0, "walks south past z 27.6 (to z %.1f)" % at.z)
	# The belt of fallen trunks closes all round: from inside it, straight out, nothing but the belt stops a ray.
	var belt: Node = main.get_node("World/Forest/RimBelt")
	var others: Array[RID] = [main.get_node("World/Forest/Trunks").get_rid()]
	var gaps := 0
	for i in 1440:
		var dir := Vector2.from_angle(TAU * (i + 0.37) / 1440.0)
		var d := dir / RIM_RADII
		var r := pow(pow(absf(d.x), 4.0) + pow(absf(d.y), 4.0), -0.25)
		var from2 := RIM_CENTRE + dir * (r - 30.0)
		var to2 := RIM_CENTRE + dir * (r + 12.0)
		var space := me.get_world_3d().direct_space_state
		var ground := func(at: Vector2) -> float:
			var fall := PhysicsRayQueryParameters3D.create(Vector3(at.x, 200.0, at.y), Vector3(at.x, -50.0, at.y))
			fall.exclude = others + [belt.get_rid()]
			var h: Dictionary = space.intersect_ray(fall)
			return h.position.y + 3.0 if not h.is_empty() else 5.0  # chest high would pass under the belt's box on a slope
		var level: float = ground.call(RIM_CENTRE + dir * (r - 5.0))  # level, at the belt's height: a slope would pass under its box
		var q := PhysicsRayQueryParameters3D.create(Vector3(from2.x, level, from2.y), Vector3(to2.x, level, to2.y))
		q.exclude = others
		var hit: Dictionary = space.intersect_ray(q)
		# A swell in the ground or a stone on the way doesn't count: past it.
		for tries in 6:
			if hit.is_empty() or hit.collider == belt:
				break
			q.exclude = q.exclude + [hit.rid]
			hit = space.intersect_ray(q)
		if hit.is_empty() or hit.collider != belt:
			gaps += 1
			print("     gap at ray %d: (%.0f, %.0f) to (%.0f, %.0f), last hit %s" % [i, from2.x, from2.y, to2.x, to2.y, str(hit.get("collider", "none"))])
	_ok(gaps == 0, "the belt of fallen trunks closes the map all round (%d rays of 1440 got through)" % gaps)
	# From just inside it, straight out on each side.
	for side: Array in [[Vector3(170.0, 0, 3.0), Vector3.RIGHT], [Vector3(30.0, 0, 150.0), Vector3.BACK], [Vector3(30.0, 0, -150.0), Vector3.FORWARD], [Vector3(-40.0, 0, 70.0), Vector3.BACK], [Vector3(103.0, 0, -22.0), Vector3.RIGHT], [Vector3(103.0, 0, 27.0), Vector3.RIGHT], [Vector3(-124.0, 0, 72.0), Vector3.LEFT]]:
		var from: Vector3 = side[0]
		var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 80.0, from + Vector3.DOWN * 20.0)
		var hit: Dictionary = me.get_world_3d().direct_space_state.intersect_ray(ray)
		at = await _walk(me, (hit.position as Vector3) + Vector3.UP * 0.6, side[1], 12.0)
		_ok(WORLD.grow(-1.0).has_point(Vector2(at.x, at.z)) and at.y > -1.0, "the belt holds them on the map going %s: stopped at (%.1f, %.1f, %.1f)" % [side[1], at.x, at.y, at.z])
	print("world_limit_check: ", "FAILED" if _failed else "passed")
	quit(1 if _failed else 0)


func _walk(me: CharacterBody3D, from: Vector3, dir: Vector3, seconds: float) -> Vector3:
	me.global_position = from
	me.velocity = Vector3.ZERO
	me.rotation.y = atan2(-dir.x, -dir.z)
	me.set("_yaw", me.rotation.y)
	Input.action_press("move_forward")
	for i in int(seconds * 60.0):
		await physics_frame
	Input.action_release("move_forward")
	return me.global_position


func _scatter(world: Node) -> void:
	# No plant in the open is a scene of several: each carries its one mesh, nothing under it.
	var rows := 0
	for n: Node in world.get_node("Wasteland").get_children():
		if n is Node3D and not n is StaticBody3D and (n.get_child_count() > 0 or not n is MeshInstance3D):
			rows += 1
	_ok(rows == 0, "the open ground's plants and stones are single meshes (%d are not)" % rows)
	# The wood: every tree from where the builder stood it (a tree has several posts now); spacing
	# irregular, kinds mixed.
	var forest: Node = world.get_node("Forest")
	var spots: Array[Vector2] = []
	for row: Array in forest.get_meta("stand"):
		spots.append(Vector2(row[1].x, row[1].z))
	_ok(spots.size() > 300, "%d trees in the wood" % spots.size())
	var gaps: Array[float] = []
	for p in spots:
		var best := INF
		for q in spots:
			if p != q:
				best = minf(best, p.distance_squared_to(q))
		gaps.append(sqrt(best))
	gaps.sort()
	var low := gaps[int(gaps.size() * 0.1)]
	var high := gaps[int(gaps.size() * 0.9)]
	print("nearest tree: min %.1f, 10%% %.1f, median %.1f, 90%% %.1f, max %.1f" % [gaps[0], low, gaps[gaps.size() / 2], high, gaps[-1]])
	_ok(gaps[0] >= 2.0, "no two trees on top of each other (closest %.1f m)" % gaps[0])
	_ok(high - low > 1.0, "spacing not even: glades and thickets (%.1f to %.1f m)" % [low, high])
	# Along any straight line through the wood a row would show as many trees at one offset.
	var worst := 0
	for deg in range(0, 180, 3):
		var n := Vector2.from_angle(deg_to_rad(float(deg)))
		var bins := {}
		for p in spots:
			var b := roundi(p.dot(n) / 0.6)
			bins[b] = int(bins.get(b, 0)) + 1
		var top := 0
		for v: int in bins.values():
			top = maxi(top, v)
		var mean := float(spots.size()) / float(bins.size())
		worst = maxi(worst, roundi(top / mean))
	_ok(worst < 5, "no straight rows (fullest line %d x the average)" % worst)
