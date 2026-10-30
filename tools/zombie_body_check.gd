extends SceneTree
## Headless check for scripts/zombie_body.gd and the Mixamo zombies: every model plays every clip of
## the shared library standing on the floor, in place where it should be, and the same seed dresses
## a zombie the same way. Creatures (the blob) go through their own clips the same way.
##   Godot.exe --headless --path . -s res://tools/zombie_body_check.gd --quit-after 600

const BODY := preload("res://scripts/zombie_body.gd")

var _fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # the root is in the tree from here on
	# Each model through every clip.
	for name in BODY.MODELS:
		var body: Node3D = BODY.new()
		body.kind = &"walker"
		body.model = name
		root.add_child(body)
		var ap: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
		var lib := ap.get_animation_library("")
		ap.stop()
		sk.reset_bone_poses()
		var toe := body.to_local(sk.to_global(sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftToeBase")).origin))
		var heel := body.to_local(sk.to_global(sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftFoot")).origin))
		_expect(toe.z < heel.z - 0.05, "%s faces backwards (toes %.2f, heel %.2f)" % [name, toe.z, heel.z])
		for t in BODY.LIB.get_animation("walk_a").get_track_count():
			var bone := String(BODY.LIB.get_animation("walk_a").track_get_path(t).get_subname(0))
			if sk.find_bone(bone) < 0:
				print("  %s has no %s (track dropped)" % [name, bone])
		# Bosses (worn by the brute only) play the creature set and the hit flinches, nothing else:
		# their long arms go through the floor in a zombie crawl.
		var boss := true
		for kind in BODY.KINDS:
			if kind != &"brute" and name in BODY.KINDS[kind].models:
				boss = false
		for clip in lib.get_animation_list():
			if boss and not (clip.begins_with("mutant_") or clip.begins_with("hit_")):
				continue
			var anim := lib.get_animation(clip)
			ap.play(clip)
			var low := INF
			var high := -INF
			var drift := 0.0
			for k in 9:
				var at := anim.length * k / 8.0
				ap.seek(at, true)
				var feet := minf(_y(sk, "LeftToeBase", body), _y(sk, "RightToeBase", body))
				low = minf(low, minf(feet, _y(sk, "LeftHand", body)))
				high = maxf(high, _y(sk, "Head", body))
				var hips := sk.to_global(sk.get_bone_global_pose(0).origin) - body.global_position
				drift = maxf(drift, Vector2(hips.x, hips.z).length())
				if k == 8 and clip.contains("death"):
					var head := _y(sk, "Head", body)
					_expect(head < 0.6, "%s %s: head still %.2f m up after dying" % [name, clip, head])
			var kind := String(clip).trim_prefix("mutant_").get_slice("_", 0)
			_expect(low > -0.2, "%s %s: sinks %.2f m into the floor" % [name, clip, low])
			if kind in ["idle", "walk", "run"]:
				_expect(high > 0.55 * body.height and high < body.height, "%s %s: head at %.2f m of %.2f" % [name, clip, high, body.height])
			if kind in ["walk", "run", "crawl"]:
				_expect(drift < 0.45, "%s %s: wanders %.2f m off the spot" % [name, clip, drift])
		print("%-11s %d clips ok" % [name, lib.get_animation_list().size()])
		body.free()

	# Creatures through their own clips: every bone above the floor, the loops on the spot, flat
	# once dead.
	for name in BODY.CREATURES:
		var body: Node3D = BODY.new()
		body.kind = name
		body.model = name
		body.size = 1.0
		root.add_child(body)
		var ap: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
		var lib := ap.get_animation_library("")
		_expect(body.height > 0.5, "%s only %.2f m tall" % [name, body.height])
		for clip in lib.get_animation_list():
			var anim := lib.get_animation(clip)
			ap.play(clip)
			var low := INF
			var drift := 0.0
			for k in 9:
				ap.seek(anim.length * k / 8.0, true)
				for b in sk.get_bone_count():
					low = minf(low, sk.to_global(sk.get_bone_global_pose(b).origin).y - body.global_position.y)
				var mid := sk.to_global(sk.get_bone_global_pose(0).origin) - body.global_position
				drift = maxf(drift, Vector2(mid.x, mid.z).length())
			var head := sk.to_global(sk.get_bone_global_pose(sk.find_bone(BODY.CREATURES[name].bones.Head)).origin).y - body.global_position.y
			_expect(low > -0.1, "%s %s: sinks %.2f m into the floor" % [name, clip, low])
			if anim.loop_mode != Animation.LOOP_NONE:
				_expect(drift < 0.2, "%s %s: wanders %.2f m off the spot" % [name, clip, drift])
			if clip.begins_with("death"):
				_expect(head < 0.3 * body.height, "%s %s: still %.2f m up after dying" % [name, clip, head])
		print("%-11s %d clips ok" % [name, lib.get_animation_list().size()])
		body.free()

	# Kinds, seeds, actions.
	var seen := {}
	for kind in BODY.KINDS:
		for seed in 24:
			var a: Node3D = BODY.new()
			a.setup(kind, seed)
			var b: Node3D = BODY.new()
			b.setup(kind, seed)
			_expect(a.model == b.model and a.size == b.size, "%s seed %d dressed two ways" % [kind, seed])
			seen[a.model] = true
			root.add_child(a)
			var ap: AnimationPlayer = a.find_children("*", "AnimationPlayer", true, false)[0]
			_expect(String(ap.current_animation).contains("idle"), "%s starts on %s" % [kind, ap.current_animation])
			a.move(1.2)
			_expect(ap.current_animation.contains(BODY.KINDS[kind].move), "%s moves with %s" % [kind, ap.current_animation])
			var swing: float = a.attack()
			_expect(swing > 0.5 and ap.current_animation.contains("attack"), "%s attacks with %s" % [kind, ap.current_animation])
			a.hit()  # ignored mid-swing
			_expect(ap.current_animation.contains("attack"), "%s: a hit cut the attack" % kind)
			ap.advance(swing + 0.1)
			_expect(ap.current_animation.contains(BODY.KINDS[kind].move), "%s back to %s after attacking" % [kind, ap.current_animation])
			a.hit()
			_expect(ap.current_animation.contains("hit"), "%s flinches with %s" % [kind, ap.current_animation])
			var fall: float = a.die()
			_expect(fall > 0.5 and ap.current_animation.contains("death"), "%s dies with %s" % [kind, ap.current_animation])
			a.move(1.0)
			_expect(ap.current_animation.contains("death"), "%s got up after dying" % kind)
			_expect(a.attach("Head").get_parent() is Skeleton3D, "%s head attachment" % kind)
			a.free()
	_expect(seen.size() == BODY.MODELS.size() + BODY.CREATURES.size(), "only %s ever picked" % [seen.keys()])

	print("zombie_body_check ", "ok" if _fails == 0 else "FAILED (%d)" % _fails)
	quit(1 if _fails else 0)


func _y(sk: Skeleton3D, bone: String, body: Node3D) -> float:
	return sk.to_global(sk.get_bone_global_pose(sk.find_bone("mixamorig_" + bone)).origin).y - body.global_position.y


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)
