extends SceneTree
## Headless check that the dead get through the wood and over the clearing to the player, round the
## trunks, rocks and logs, without standing stuck (2026-11-05, the user: "yarım saattir bir kayaya
## takılmış yavrucak"):
##   Godot.exe --headless --fixed-fps 60 --path . -s res://tools/zombie_stuck_check.gd
## Walkers come up deep in the wood all round the clearing (not in the junk behind the yard) and
## go for one player standing on the pad. Over SIM s of game time every one is watched: one that
## has not gained STUCK_GAIN m on its prey in STUCK_FOR s while still far off is stuck. Passes when
## none is stuck and most reach the player. `--out=<file>` writes every one's track there.

var STAND := Vector3(10.0, 0.0, 2.0)  # on the pad in front of the workshop; `--stand=x,z` elsewhere
const SIM := 120.0  # s
const STUCK_FOR := 6.0  # s
const STUCK_GAIN := 1.0  # m
const SPOTS := 16
const DEEP := 14.0  # m out from the clearing's edge, into the wood
const CLEARING_CENTRE := Vector2(8.0, 0.0)  # tools/build_world.gd
const CLEARING_RADII := Vector2(40.0, 34.0)
const YARD := Rect2(-136.0, -80.0, 130.0, 160.0)

var main: Node
var waves: Node
var gs: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	waves = main.get_node("Waves")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stand="):
			var xz := a.trim_prefix("--stand=").split(",")
			STAND = Vector3(float(xz[0]), 0.0, float(xz[1]))
	for i in 5:
		await physics_frame
	var me: Node3D = main.get_node("Player")
	me.global_position = STAND + Vector3.UP * 0.5
	for i in 30:
		await physics_frame
	var t0 := Time.get_ticks_msec()
	while waves._nav.navigation_mesh == null:  # the bake is async
		await process_frame
		if Time.get_ticks_msec() - t0 > 120_000:
			print("FAIL: the navigation mesh never baked")
			quit(1)
			return
	print("nav baked in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	for i in 5:
		await physics_frame
	var ids := []
	for i in SPOTS:
		var dir := Vector2.from_angle(TAU * (i + 0.5) / SPOTS)
		var p := CLEARING_CENTRE + dir * CLEARING_RADII * (1.0 + DEEP / minf(CLEARING_RADII.x, CLEARING_RADII.y))
		if YARD.has_point(p):
			continue
		var before: Array = waves._zombies.keys()
		var hit := main.get_viewport().world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 60.0, p.y), Vector3(p.x, -20.0, p.y), 1))
		var at: Vector3 = hit.position if hit else Vector3(p.x, 0.0, p.y)
		var to := STAND - at
		waves._summon(&"walker", at, atan2(-to.x, -to.z), 1)
		for id: int in waves._zombies.keys():
			if not id in before:
				ids.append(id)
	print("%d walkers in the wood" % ids.size())
	var track := {}  # id -> [[t, dist, pos], ...]
	var reached := {}
	var stuck := {}
	var t := 0.0
	var dt := 1.0 / 60.0
	var sample := 0.0
	var inside := {}  # id -> samples with its middle inside a trunk, a rock, a wall
	var probe := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.12
	probe.shape = ball
	probe.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = main.get_viewport().world_3d.direct_space_state
	var samples := 0
	while t < SIM:
		await process_frame
		t += dt
		sample -= dt
		me.global_position = Vector3(STAND.x, me.global_position.y, STAND.z)  # held there: the crowd shoves the body
		me.velocity = Vector3.ZERO
		gs.player().pos = me.global_position  # headless, player.gd may not have sent a pose yet
		gs.player().has_pose = true
		gs.player().hp = gs.HP_MAX  # never down: the ones still coming would stand and wait
		gs.player().down = false
		if sample > 0.0:
			continue
		sample = 0.5
		for id: int in ids:
			if not waves._zombies.has(id) or reached.has(id):
				continue
			var node: Node3D = waves._zombies[id].node
			var d := Vector2(node.global_position.x - me.global_position.x, node.global_position.z - me.global_position.z).length()
			if not track.has(id):
				track[id] = []
			var skip := []
			for o: Dictionary in waves._zombies.values():
				skip.append((o.node as CollisionObject3D).get_rid())
			probe.exclude = skip
			probe.transform = Transform3D(Basis(), node.global_position + Vector3.UP * 1.0)
			samples += 1
			var hits := space.intersect_shape(probe, 1)
			if not hits.is_empty():
				inside[id] = inside.get(id, 0) + 1
				if "--verbose" in OS.get_cmdline_user_args():
					var z: Dictionary = waves._zombies[id]
					print("  inside: Z%d t %.1f at (%.1f, %.2f, %.1f) %s, %.1f m off, aware %s, path %d, swinging %s" % [id, t, node.global_position.x,
							node.global_position.y, node.global_position.z, (hits[0].collider as Node).name, d, z.aware, z.path.size(), z.swinging])
			track[id].append([t, d, node.global_position])
			if d < 2.0:
				reached[id] = t
				continue
			var rows: Array = track[id]
			for r: Array in rows:
				if r[0] >= t - STUCK_FOR - 0.01:
					if t >= STUCK_FOR + 1.0 and r[1] - d < STUCK_GAIN and not stuck.has(id):
						stuck[id] = [t, node.global_position, d]
					break
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		for id: int in track:
			for r: Array in track[id]:
				f.store_line("%d\t%.1f\t%.2f\t%.2f\t%.2f" % [id, r[0], r[1], r[2].x, r[2].z])
	for id: int in stuck:
		var s: Array = stuck[id]
		print("  stuck: Z%d at t %.1f s, (%.1f, %.1f), %.1f m off" % [id, s[0], s[1].x, s[1].z, s[2]])
	var times: Array = reached.values()
	times.sort()
	print("reached the player: %d of %d%s" % [reached.size(), ids.size(),
			(", first at %.1f s, last at %.1f s" % [times[0], times[-1]]) if not times.is_empty() else ""])
	print("stuck at some point: %d" % stuck.size())
	var through := 0
	for id: int in inside:
		through += inside[id]
	var freed := 0
	for id: int in ids:
		if waves._zombies.has(id):
			freed += waves._zombies[id].get("unstuck", 0)
	print("inside a trunk, rock or wall: %d of %d looks (%d walkers)" % [through, samples, inside.size()])
	print("found their way again after standing: %d times" % freed)
	var ok := stuck.is_empty() and reached.size() >= ids.size() * 0.9 and through <= samples / 100
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
