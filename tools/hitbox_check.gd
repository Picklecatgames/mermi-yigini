extends SceneTree
## Headless check of what a round hits on a zombie (scripts/waves.gd hit shapes, GameState's trace):
##   Godot.exe --headless --path . -s res://tools/hitbox_check.gd --quit-after 3000
## Zombies of every kind stand idle, clawing and walking up; from a few metres off (eye height and
## crouched) rounds go at the head, the chest, the hips, every limb's middle and the shins of each.
## Each must hit the zombie (it pays). Nothing else stands in the way on the pad.

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
	gs.request_toggle_infinite_ammo()
	gs.request_select_gun(4)  # the Scorpion: test mode opens it
	var id := 900
	for kind: StringName in KINDS:
		for pose in ["idle", "claw", "walk"]:
			id += 1
			await _zombie(id, kind, pose)
	await _legless()
	print("hitbox_check: %d rounds, %d wrong" % [_shots, _fails])
	print("hitbox_check OK" if _fails == 0 else "hitbox_check FAILED")
	quit(1 if _fails else 0)


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
	# Out of the camera's view its clips are stepped every few frames; a trace brings them up to date
	# first (fit_along), so the aims are taken from that pose.
	body.catch_up()
	var aims := {}  # name -> world point
	var sk: Skeleton3D = body.get("_skel")
	aims["head"] = sk.global_transform * sk.get_bone_global_pose((z.head as BoneAttachment3D).bone_idx).origin
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
		# (reached over the railing, it is hit on our side: it still pays, GameState counts a zombie
		# by where it stands)
		for eye in [gs.EYE, gs.CROUCH_EYE]:
			var from := Vector3(SHOOT_X, eye, at.z + 0.6)
			var dir := (at - from).normalized()
			var hit := _trace(from, from + dir * 40.0)
			_shots += 1
			var ok: bool = not hit.is_empty() and hit.collider == z.node
			if ok and name == "head" and pose == "idle" and kind in [&"walker", &"runner"]:  # the weak spot, named for whoever counts regions (arms out or a blob's bulk may come first otherwise)
				ok = waves.region_at(z.node, hit.shape) == &"head"
			_ok(ok, "%s %s %s, eye %.1f: %s at %s" % [kind, pose, name, eye, _what(hit), at])
	waves._zombies.erase(id)
	(z.node as Node).free()


## A walker that lost a leg at the railing: down on its belly, rounds at it still land.
func _legless() -> void:
	var id := 990
	waves._add_zombie(id, &"walker", 3, "", Vector3(waves.RAIL_X, 0, 0.5), PI / 2, 1.0, 0.5, false)
	var z: Dictionary = waves._zombies[id]
	waves._cut(z, &"leg_l", false)
	var gone := (z.bones as Array).filter(func(b: Dictionary) -> bool: return (b.node as CollisionShape3D).disabled)
	_ok(gone.size() == 3 and gone.all(func(b: Dictionary) -> bool: return b.node.get_meta("region") == &"leg_l"),
			"the torn leg's three shapes take no more rounds (%d off)" % gone.size())
	z.down = 0.0
	z.body.move(0.5)
	for i in 60:
		await process_frame
	await physics_frame
	var body: Node3D = z.body
	body.catch_up()
	for name in ["Head", "Spine2", "Hips", "RightLeg", "RightForeArm", "LeftForeArm"]:
		var at: Vector3 = body.call("_bone_at", name)
		var from := Vector3(SHOOT_X, gs.EYE, at.z + 0.6)
		var hit := _trace(from, from + (at - from).normalized() * 40.0)
		if not hit.is_empty() and hit.collider.name == "FiringLineBars":
			continue
		_shots += 1
		_ok(not hit.is_empty() and hit.collider == z.node,
				"legless walker %s: %s at %s" % [name, _what(hit), at])
		if name == "Head" and hit.collider == z.node:  # its head over the railing: still a paying hit
			var before: int = gs.player().gold
			gs.player().cooldown = 0.0
			gs.request_fire(from, (at - from).normalized())
			_ok(gs.player().gold > before, "a head reaching over the railing (hit at x %.2f) pays" % hit.position.x)
	waves._zombies.erase(id)
	(z.node as Node).free()


func _trace(from: Vector3, to: Vector3) -> Dictionary:
	waves.fit_along(from, to - from)  # as GameState's trace has them (its fired signal)
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
