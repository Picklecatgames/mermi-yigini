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
				var hips := sk.to_global(sk.get_bone_global_pose(sk.find_bone("mixamorig_Hips")).origin) - body.global_position
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
		var skinned := {}  # the bones that carry weight (not IK poles and such)
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			if mi.skin == null:
				continue
			for surf in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(surf)
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				for i in bones.size():
					if weights[i] > 0.05:
						var bind := bones[i]
						skinned[sk.find_bone(mi.skin.get_bind_name(bind)) if mi.skin.get_bind_name(bind) != &"" else mi.skin.get_bind_bone(bind)] = true
		var hips := sk.find_bone(BODY.CREATURES[name].bones.Hips)
		for clip in lib.get_animation_list():
			var anim := lib.get_animation(clip)
			ap.play(clip)
			var low := INF
			var drift := 0.0
			var start := Vector3.INF
			for k in 9:
				ap.seek(anim.length * k / 8.0, true)
				for b in skinned:
					low = minf(low, sk.to_global(sk.get_bone_global_pose(b).origin).y - body.global_position.y)
				var mid := sk.to_global(sk.get_bone_global_pose(hips).origin) - body.global_position
				if start == Vector3.INF:
					start = mid
				drift = maxf(drift, Vector2(mid.x - start.x, mid.z - start.z).length())
			var head := sk.to_global(sk.get_bone_global_pose(sk.find_bone(BODY.CREATURES[name].bones.Head)).origin).y - body.global_position.y
			_expect(low > -0.1, "%s %s: sinks %.2f m into the floor" % [name, clip, low])
			if anim.loop_mode != Animation.LOOP_NONE:
				_expect(drift < 0.2, "%s %s: wanders %.2f m off the spot" % [name, clip, drift])
			if clip.begins_with("death"):
				_expect(head < 0.3 * body.height, "%s %s: still %.2f m up after dying" % [name, clip, head])
		print("%-11s %d clips ok, %.2f m" % [name, lib.get_animation_list().size(), body.height])
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
			var low: bool = a.crawling  # on its belly it idles, swings and flinches there
			var swing_clip := "floor_bite" if low else "attack"
			_expect(String(ap.current_animation).contains("crawl" if low else "idle"), "%s starts on %s" % [kind, ap.current_animation])
			a.move(1.2)
			_expect(ap.current_animation.contains(BODY.KINDS[kind].move), "%s moves with %s" % [kind, ap.current_animation])
			var swing: float = a.attack()
			_expect(swing > 0.5 and ap.current_animation.contains(swing_clip), "%s attacks with %s" % [kind, ap.current_animation])
			a.hit()  # ignored mid-swing
			_expect(ap.current_animation.contains(swing_clip), "%s: a hit cut the attack" % kind)
			ap.advance(swing + 0.1)
			_expect(ap.current_animation.contains(BODY.KINDS[kind].move), "%s back to %s after attacking" % [kind, ap.current_animation])
			a.hit()
			_expect(ap.current_animation.contains(BODY.KINDS[kind].move if low else "hit"), "%s flinches with %s" % [kind, ap.current_animation])
			var fall: float = a.die()
			_expect(fall > 0.5 and ap.current_animation.contains("death"), "%s dies with %s" % [kind, ap.current_animation])
			a.move(1.0)
			_expect(ap.current_animation.contains("death"), "%s got up after dying" % kind)
			_expect(a.attach("Head").get_parent() is Skeleton3D, "%s head attachment" % kind)
			a.free()
	_expect(seen.size() == BODY.MODELS.size() + BODY.CREATURES.size(), "only %s ever picked" % [seen.keys()])
	await _limbs()

	print("zombie_body_check ", "ok" if _fails == 0 else "FAILED (%d)" % _fails)
	quit(1 if _fails else 0)


## Limbs: a round along a limb's line finds it (and the trunk keeps the ones through the chest), a
## cut folds the bone, throws a copy of the limb that shows only that limb, and a leg drops a walker
## to its belly to crawl and bite from there; a brute keeps its legs, a creature has none to lose.
func _limbs() -> void:
	var holder := Node3D.new()  # bodies look for the world two parents up
	root.add_child(holder)
	var parent := Node3D.new()
	holder.add_child(parent)
	var a: Node3D = BODY.new()
	a.setup(&"walker", 3)
	a.model = &"prisoner"
	parent.add_child(a)
	# The pose these rounds were aimed at: the walk this seed played before move() picked clips by
	# speed, stretched as far as it goes.
	a._play_loop("walk_a", 1.8)
	var sk: Skeleton3D = a.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = a.find_children("*", "AnimationPlayer", true, false)[0]
	ap.advance(0.5)
	var bone := func(n: String) -> Vector3: return sk.to_global(sk.get_bone_global_pose(sk.find_bone("mixamorig_" + n)).origin)
	for part: StringName in BODY.LIMBS:
		var mid: Vector3 = (bone.call(BODY.LIMBS[part][0]) + bone.call(BODY.LIMBS[part][1])) / 2.0
		var out: Vector3 = mid - bone.call("Hips")
		out.y = 0.0
		# from out to the side, toward the body: the limb is first in line
		var dir := -out.normalized() if out.length() > 0.05 else Vector3.LEFT
		_expect(a.limb_at(mid - dir * 0.05, dir) == part, "a round across %s finds %s" % [part, a.limb_at(mid - dir * 0.05, dir)])
	var chest: Vector3 = bone.call("Spine2")
	_expect(a.limb_at(chest + Vector3(0, 0, 0.2), Vector3(0, 0, -1)) in [&"", &"arm_l", &"arm_r"], "a round into the chest from the front")
	var pieces := holder.get_child_count()
	var fall: float = a.cut(&"forearm_l")
	_expect(fall == 0.0 and &"forearm_l" in a.cuts and not a.can_lose(&"forearm_l") and a.can_lose(&"arm_l"), "forearm off, the arm still on")
	_expect(holder.get_child_count() > pieces, "the forearm flew off")
	var piece: Node3D = null
	for n in holder.get_children():
		if n.get_script() == preload("res://scripts/zombie_gibs.gd") and n.find_children("*", "Skeleton3D", true, false).size() > 0:
			piece = n
	_expect(piece != null, "the thrown forearm is a copy of the model")
	if piece:
		var psk: Skeleton3D = piece.find_children("*", "Skeleton3D", true, false)[0]
		var hand := psk.get_bone_global_pose(psk.find_bone("mixamorig_LeftHand"))
		var head := psk.get_bone_global_pose(psk.find_bone("mixamorig_Head"))
		_expect(hand.basis.get_scale().x > 0.9 and head.basis.get_scale().x < 0.01, "the copy shows the hand and not the head")
		_expect(psk.to_global(hand.origin).distance_to(bone.call("LeftHand")) < 0.05, "the copy's hand starts where the hand was")
	var folded := [INF]  # the folding is a modifier: read it as the skeleton finishes its update
	var read := func() -> void: folded[0] = sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftHand")).basis.get_scale().x
	sk.skeleton_updated.connect(read)
	await process_frame
	await process_frame
	sk.skeleton_updated.disconnect(read)
	_expect(folded[0] < 0.01, "the body's hand is folded away (%.3f)" % folded[0])
	_expect(a.arms_hurt() == 1, "one arm hurt")
	_expect(not a.crawling, "still on its feet")
	fall = a.cut(&"shin_r")
	_expect(fall > 0.5 and a.crawling and ap.current_animation.begins_with("fall"), "a shin off: it falls (%.2f s, %s)" % [fall, ap.current_animation])
	ap.advance(fall + 0.3)
	_expect(ap.current_animation.begins_with("crawl"), "and crawls after (%s)" % ap.current_animation)
	var bite: float = a.attack()
	_expect(bite > 0.5 and ap.current_animation.begins_with("floor_bite"), "and bites from the floor")
	_expect(a.cut(&"shin_r") == 0.0 and a.cuts.count(&"shin_r") == 1, "a part goes once")
	_expect(a.cut(&"leg_l") == 0.0 and &"leg_l" in a.cuts, "the other leg on the belly: no second fall")
	a.die()
	ap.advance(0.1)
	_expect(ap.current_animation.begins_with("death"), "dies on its belly with %s" % ap.current_animation)
	var brute: Node3D = BODY.new()
	brute.setup(&"brute", 1)
	parent.add_child(brute)
	_expect(not brute.can_lose(&"leg_l") and brute.can_lose(&"arm_l"), "a brute keeps its legs")
	for kind in [&"dog", &"blob"]:
		var c: Node3D = BODY.new()
		c.setup(kind, 1)
		parent.add_child(c)
		_expect(c.limb_at(c.global_position + Vector3(0.3, 0.3, 0), Vector3.LEFT) == &"" and not c.can_lose(&"leg_l"), "%s has no limbs to lose" % kind)
	holder.free()
	print("limbs ok")


func _y(sk: Skeleton3D, bone: String, body: Node3D) -> float:
	return sk.to_global(sk.get_bone_global_pose(sk.find_bone("mixamorig_" + bone)).origin).y - body.global_position.y


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)
