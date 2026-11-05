extends SceneTree
## The junkyard doesn't hold anyone (2026-11-04, the user: "players can get stuck on it"): from spots
## all over its foot and between its heaps a walker heads straight for the workshop and gets clear.
##   Godot.exe --headless --path . -s res://tools/heap_walk_check.gd
const GOAL := Vector3(0.0, 0.0, 0.0)
const SECONDS := 20.0

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await physics_frame
	gs.request_pick_character("oldman")
	var me: CharacterBody3D = main.get_node("Player")
	var pile: Node = root.get_tree().get_first_node_in_group("bullet_pile")
	for i in 10:
		await physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spots := 0
	var tries := 0
	while spots < 24 and tries < 4000:
		tries += 1
		var p := Vector3(rng.randf_range(-70.0, -12.0), 0.0, rng.randf_range(-45.0, 45.0))
		var ground: float = pile.surface_y(p)
		if ground < 0.3 or ground > 9.0:
			continue
		spots += 1
		me.global_position = p + Vector3.UP * (ground + 0.8)
		me.velocity = Vector3.ZERO
		var best := me.global_position.distance_to(GOAL)
		var left := best
		var still := 0.0
		Input.action_press("move_forward")
		for i in int(SECONDS * 60.0):
			var to := GOAL - me.global_position
			# Stopped a moment (a trunk in the way): off to one side, as anyone would.
			var side := 1.2 if int(still * 1.0) % 2 == 1 else -1.2
			me.rotation.y = atan2(-to.x, -to.z) + (side if still > 1.0 else 0.0)
			me.set("_yaw", me.rotation.y)
			await physics_frame
			left = Vector2(me.global_position.x, me.global_position.z).distance_to(Vector2(GOAL.x, GOAL.z))
			if left < best - 0.3:
				best = left
				still = 0.0
			else:
				still += 1.0 / 60.0
			if left < 12.0 or still > 8.0:
				break
		Input.action_release("move_forward")
		# Stopped on the bare floor, it was trunks in the wood round the heap: this walker is no pathfinder.
		var ok: bool = still <= 8.0 or pile.surface_y(me.global_position) < 0.02
		if not ok:
			# Held up on the way, then: is it a trap? Anyone would try another way out.
			var stop := me.global_position
			for n in 8:
				me.rotation.y = TAU * n / 8.0
				me.set("_yaw", me.rotation.y)
				Input.action_press("move_forward")
				for i in 120:
					await physics_frame
				Input.action_release("move_forward")
				ok = ok or me.global_position.distance_to(stop) > 4.0
			print("     held up at %v, tried every way: %s" % [stop, "got out" if ok else "TRAPPED"])
		print(("ok   " if ok else "FAIL ") + "from (%.0f, %.1f, %.0f): got to %.1f m of the workshop, at (%.0f, %.1f, %.0f)" % [p.x, ground, p.z, left, me.global_position.x, me.global_position.y, me.global_position.z])
		_failed = _failed or not ok
	# And the mountains' scrap, which has no pieces of its own, can be taken.
	var spot := Vector3(-60.0, 0.0, 30.0)
	while pile.surface_y(spot) < 1.0 or root.get_tree().get_first_node_in_group("bullet_pile").NEAR.has_point(Vector2(spot.x, spot.z)):
		spot.z -= 1.0
	spot.y = pile.surface_y(spot)
	var at: Variant = pile.far_hit(spot + Vector3.UP * 1.5, spot + Vector3.DOWN)
	var before: int = gs.pile
	gs.carried = 0
	var got: int = gs.request_pick_up(at, 1) if at != null else 0
	var took: bool = at != null and got == 1 and gs.pile == before - 1
	print(("ok   " if took else "FAIL ") + "takes from the mountain at (%.0f, %.1f, %.0f): %d" % [spot.x, spot.y, spot.z, got])
	_failed = _failed or not took
	print("heap_walk_check: ", "FAILED" if _failed else "passed")
	quit(1 if _failed else 0)
