extends SceneTree
## Headless check of what a round hits at the railing (scripts/waves.gd hit shapes, GameState's trace):
##   Godot.exe --headless --path . -s res://tools/hitbox_check.gd --quit-after 2000
## Zombies of every kind stand at the railing, idle, clawing and walking up; from behind the railing
## (x 12.5, eye height and crouched) rounds go through the gaps between its rails and posts at the
## head, the chest, the hips, every limb's middle and the shins of each. Each must hit the zombie past
## the line (it pays). Rounds at the posts and rails must stop on them, never fly on.

const SHOOT_X := 12.5
const KINDS := [&"walker", &"runner", &"brute", &"crawler", &"dog", &"blob"]

var gs: Node
var waves: Node
var _fails := 0
var _shots := 0


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	gs = root.get_node("GameState")
	waves = main.get_node("Waves")
	for i in 3:
		await physics_frame
	await _railing()
	var id := 900
	for kind: StringName in KINDS:
		for pose in ["idle", "claw", "walk"]:
			id += 1
			await _zombie(id, kind, pose)
	await _legless()
	print("hitbox_check: %d rounds, %d wrong" % [_shots, _fails])
	print("hitbox_check OK" if _fails == 0 else "hitbox_check FAILED")
	quit(1 if _fails else 0)


## Rounds straight at the railing's posts and rails stay on them.
func _railing() -> void:
	var space := root.get_world_3d().direct_space_state
	var x: float = gs.FIRING_LINE_X
	var posts := root.find_child("FiringLine", true, false)
	if not _ok(posts != null, "the railing is there"): return
	var bars := 0
	for c in posts.get_children():
		if c is MeshInstance3D and (c.mesh as BoxMesh).size.y > 0.5:  # a post
			var at: Vector3 = c.global_position
			if absf(at.z) > 20.0:
				continue
			var from := Vector3(SHOOT_X, 0.8, at.z)
			var hit := _trace(from, Vector3(x, 0.8, at.z))
			_ok(not hit.is_empty() and hit.position.x < x + 0.05 and hit.position.x > x - 0.1,
					"a round at the post at z %.1f stops on it (%s)" % [at.z, _what(hit)])
			bars += 1
	for y in [1.075, 0.55]:
		var hit := _trace(Vector3(SHOOT_X, y, 0.37), Vector3(x, y, 0.37))
		_ok(not hit.is_empty() and absf(hit.position.x - x) < 0.1, "a round at the rail at %.2f m stops on it (%s)" % [y, _what(hit)])
	_ok(bars > 10, "%d posts tried" % bars)
	# Between them nothing: a round at the gap flies past the line.
	for y in [0.3, 0.8, 1.4]:
		var hit := _trace(Vector3(SHOOT_X, y, 0.0), Vector3(x + 3.0, y, 0.0))
		_ok(hit.is_empty() or hit.position.x > x + 0.2, "a round through the gap at %.1f m flies on (%s)" % [y, _what(hit)])


## One zombie at its railing spot in `pose`; rounds at its parts through the railing.
func _zombie(id: int, kind: StringName, pose: String) -> void:
	var z_at := -6.0 + (id % 7) * 2.0  # clear of the posts' spacing by chance only: the gap rounds dodge them
	var x: float = waves.RAIL_X if pose != "walk" else waves.RAIL_X + 2.5
	waves._add_zombie(id, kind, 7 + id, "", Vector3(x, 0, z_at), PI / 2, 1.0, z_at, false)
	var z: Dictionary = waves._zombies[id]
	var body: Node3D = z.body
	match pose:
		"claw":
			body.attack()
		"walk":
			body.move(1.0)
	for i in 20:
		await process_frame
	await physics_frame
	await physics_frame
	var aims := {}  # name -> world point
	aims["head"] = (z.head as Node3D).global_position
	if body.CREATURES.has(body.model):
		var tr: Node3D = z.trunk
		aims["trunk"] = tr.global_position
	else:
		aims["chest"] = body.call("_bone_at", "Spine2")
		aims["hips"] = body.call("_bone_at", "Hips")
		for part: StringName in body.LIMBS:
			var a: Vector3 = body.call("_bone_at", body.LIMBS[part][0])
			var b: Vector3 = body.call("_bone_at", body.LIMBS[part][1])
			aims[String(part)] = a.lerp(b, 0.5)
		aims["foot_l"] = body.call("_bone_at", "LeftLeg").lerp(body.call("_bone_at", "LeftFoot"), 0.85)
		aims["foot_r"] = body.call("_bone_at", "RightLeg").lerp(body.call("_bone_at", "RightFoot"), 0.85)
	for name: String in aims:
		var at: Vector3 = aims[name]
		if at.x < gs.FIRING_LINE_X + 0.05:  # reached over the railing: on our side, no pay is right
			continue
		for eye in [gs.EYE, gs.CROUCH_EYE]:
			var from := Vector3(SHOOT_X, eye, at.z + 0.6)
			var dir := (at - from).normalized()
			var hit := _trace(from, from + dir * 40.0)
			if not hit.is_empty() and hit.collider.get_parent() and hit.collider.name == "FiringLine":
				continue  # a post or rail in the way: the railing test above covers those
			_shots += 1
			var ok: bool = not hit.is_empty() and hit.collider == z.node and hit.position.x > gs.FIRING_LINE_X
			_ok(ok, "%s %s %s, eye %.1f: %s at %s" % [kind, pose, name, eye, _what(hit), at])
	waves._zombies.erase(id)
	(z.node as Node).free()


## A walker that lost a leg at the railing: down on its belly, rounds at it still land.
func _legless() -> void:
	var id := 990
	waves._add_zombie(id, &"walker", 3, "", Vector3(waves.RAIL_X, 0, 0.5), PI / 2, 1.0, 0.5, false)
	var z: Dictionary = waves._zombies[id]
	waves._cut(z, &"leg_l", false)
	z.down = 0.0
	z.body.move(0.5)
	for i in 60:
		await process_frame
	await physics_frame
	var body: Node3D = z.body
	for name in ["Head", "Spine2", "Hips", "RightLeg", "RightForeArm", "LeftForeArm"]:
		var at: Vector3 = body.call("_bone_at", name)
		if at.x < gs.FIRING_LINE_X + 0.05:
			continue
		var from := Vector3(SHOOT_X, gs.EYE, at.z + 0.6)
		var hit := _trace(from, from + (at - from).normalized() * 40.0)
		if not hit.is_empty() and hit.collider.name == "FiringLine":
			continue
		_shots += 1
		_ok(not hit.is_empty() and hit.collider == z.node and hit.position.x > gs.FIRING_LINE_X,
				"legless walker %s: %s at %s" % [name, _what(hit), at])
	waves._zombies.erase(id)
	(z.node as Node).free()


func _trace(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, gs.SHOT_MASK)
	return root.get_world_3d().direct_space_state.intersect_ray(q)


func _what(hit: Dictionary) -> String:
	if hit.is_empty():
		return "nothing"
	return "%s at (%.2f, %.2f, %.2f)" % [hit.collider.name, hit.position.x, hit.position.y, hit.position.z]


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fails += 1
		print("FAIL: " + what)
	return cond
