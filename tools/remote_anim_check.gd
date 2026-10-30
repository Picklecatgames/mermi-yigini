extends SceneTree
## Headless check of another player's third-person character (scripts/remote_players.gd):
##   Godot.exe --headless --path . -s res://tools/remote_anim_check.gd
## Feeds it poses like the network would and checks, in every body (GameState.CHARACTERS), that it
## stands, holds every gun with both hands and aims it where the player looks, runs forward,
## sideways and backwards in the right clips, jumps, lands with a crouch, reloads and fires, crouches
## (Ctrl) still and walking with the gun held and stands up again; that bare-handed it holds nothing;
## and that before picking there is no body.

var mgr: Node3D
var gs: Node
var ok := true


func _initialize() -> void:
	gs = root.get_node("GameState")
	mgr = load("res://scripts/remote_players.gd").new()
	root.add_child(mgr)
	await process_frame
	var p := Vector3.ZERO
	await _hold(p, 0.0, 0, false, 0.2)
	_ok(mgr.character(7)._model == null and mgr.character(7).visible, "no body before picking, the tag shows")
	for id: String in gs.CHARACTERS:
		gs.character_changed.emit(7, id)
		gs.gun_changed.emit(7, 0)
		await _hold(p, 0.0, 0, false, 0.4)
		var c = mgr.character(7)
		_ok(c.look == id and c._model != null, "%s: wears its body" % id)
		_ok(c.speed < 0.1 and _foot(c) < 0.15 and not c._gun.visible, "%s: stands bare-handed, no gun" % id)
		for g in range(1, gs.GUNS.size()):
			if not gs.GUNS[g].ready:
				continue
			var gun: String = gs.GUNS[g].id
			gs.gun_changed.emit(7, g)
			await _hold(p, 0.0, 0, false, 0.3)
			_ok(_left_off_gun(c) < 0.01, "%s %s: both hands on the gun (%.1f cm off)" % [id, gun, _left_off_gun(c) * 100.0])
			_ok(_aim(c, 0.0) > 0.995, "%s %s: aims ahead (%.3f)" % [id, gun, _aim(c, 0.0)])
			await _hold(p, 0.7, 0, false, 1.6)  # the head looks up at once, the body and gun after it
			_ok(_aim(c, 0.7) > 0.995 and c.muzzle_position().y > 1.5, "%s %s: aims up with the look (%.3f)" % [id, gun, _aim(c, 0.7)])
			await _hold(p, 0.0, 0, false, 1.6)
		# Running: forward, to the right (+X with the player facing -Z), backwards, in the pistol stance.
		gs.gun_changed.emit(7, 1)
		# A big body (the Brute) takes 5 m/s nearer its walk than its run.
		for way: Array in [[Vector3.FORWARD, ["pistol_run", "pistol_walk"]], [Vector3.RIGHT, ["pistol_strafe_b"]],
				[Vector3.BACK, ["pistol_run_back", "pistol_walk_back"]]]:
			p = await _run(p, way[0] * 5.0, 0.8)
			_ok(absf(c.speed - 5.0) < 1.0 and _strongest(c) in way[1] and _foot(c) < 0.25,
					"%s: runs %s at about 5 m/s (%s, %.1f m/s)" % [id, way[1][0], _strongest(c), c.speed])
		await _hold(p, 0.0, 0, false, 0.4)
		await _hold(p, 0.0, 0, true, 0.4)
		_ok(_legs(c) in ["jump_up", "jump"], "%s: jumps (%s)" % [id, _legs(c)])
		await _hold(p, 0.0, 0, false, 0.25)
		var hips: float = c._skel.get_bone_global_pose(0).origin.y
		_ok(c._tree.get("parameters/land/active") and hips < c._hip * 0.97, "%s: lands with a crouch (hips %.2f of %.2f)" % [id, hips, c._hip])
		await _hold(p, 0.0, gs.Act.RELOADING, false, 0.5)
		_ok(_left_off_gun(c) > 0.03, "%s: reloads, left hand off the gun" % id)
		await _hold(p, 0.0, 0, false, 0.4)
		c.shoot()
		await process_frame
		_ok(c._kick > 0.0 and c._flash_left > 0.0, "%s: fires: kick and flash" % id)
		await _hold(p, 0.0, 0, false, 0.6, true)
		var low: float = c._skel.get_bone_global_pose(0).origin.y
		var eye := _eye(c)
		_ok(c._ground == "crouch" and low < c._hip * 0.8 and _foot(c) < 0.15 and absf(c._shape.height - 1.3) < 0.01,
				"%s: crouches (hips %.2f of %.2f, capsule %.2f m)" % [id, low, c._hip, c._shape.height])
		_ok(absf(eye - gs.CROUCH_EYE) < 0.2, "%s: crouched eyes near the crouched view (%.2f m)" % [id, eye])
		_ok(_left_off_gun(c) < 0.01 and _aim(c, 0.0) > 0.995, "%s: crouched, holds and aims the gun (%.1f cm, %.3f)" % [id, _left_off_gun(c) * 100.0, _aim(c, 0.0)])
		p = await _run(p, Vector3.FORWARD * 2.5, 0.8, true)
		_ok(_strongest(c) == "rifle_crouch_walk" and absf(c.speed - 2.5) < 0.6 and _foot(c) < 0.25,
				"%s: walks crouched (%s, %.1f m/s)" % [id, _strongest(c), c.speed])
		await _hold(p, 0.0, 0, false, 0.6)
		_ok(c._ground == "pistol" and c._skel.get_bone_global_pose(0).origin.y > c._hip * 0.9 and absf(c._shape.height - 1.8) < 0.01,
				"%s: stands up again" % id)
	print("remote_anim_check OK" if ok else "remote_anim_check FAIL")
	quit(0 if ok else 1)


func _ok(good: bool, what: String) -> void:
	print("%s %s" % ["ok  " if good else "FAIL", what])
	ok = ok and good


func _hold(pos: Vector3, pitch: float, act: int, air: bool, secs: float, crouch := false) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		mgr._on_pose(7, Time.get_ticks_msec() / 1000.0, pos, 0.0, pitch, act, air, crouch)
		await create_timer(0.05).timeout


func _run(pos: Vector3, vel: Vector3, secs: float, crouch := false) -> Vector3:
	var t0 := Time.get_ticks_msec()
	var last := t0
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		# By the clock, not the timer: on a busy machine the timer comes late and the run came out slow.
		var now := Time.get_ticks_msec()
		pos += vel * (now - last) / 1000.0
		last = now
		mgr._on_pose(7, now / 1000.0, pos, 0.0, 0.0, 1, false, crouch)
		await create_timer(0.05).timeout
	return pos


## How well the gun points along the look at `pitch`.
func _aim(c, pitch: float) -> float:
	var look := Basis.from_euler(Vector3(pitch, c.rotation.y, 0.0)) * Vector3.FORWARD
	return c._gun.global_basis.z.normalized().dot(look)


func _legs(c) -> String:
	return (c._tree.get("parameters/legs/playback") as AnimationNodeStateMachinePlayback).get_current_node()


## The clip the ground's blend space (the stance's, or crouching's) leans on most where the
## character is moving.
func _strongest(c) -> String:
	var space: AnimationNodeBlendSpace2D = c._tree.tree_root.get_node("legs").get_node("ground").get_node(c._ground)
	var at: Vector2 = c._tree.get("parameters/legs/ground/%s/blend_position" % c._ground)
	var best := ""
	var near := INF
	for i in space.get_blend_point_count():
		var d := space.get_blend_point_position(i).distance_to(at)
		if d < near:
			near = d
			best = (space.get_blend_point_node(i) as AnimationNodeAnimation).animation
	return best


## Metres between the left wrist and its place on the gun.
func _left_off_gun(c) -> float:
	var w: Vector3 = c._skel.get_bone_global_pose(c._hand["L_wrist"]).origin
	return w.distance_to(c._gun.transform * c._left_wrist_on_gun)


## How high the body's eyes are (m above its feet): as far up the head as remote_players.gd puts them.
func _eye(c) -> float:
	var sk: Skeleton3D = c._skel
	var head: Vector3 = sk.get_bone_global_pose(sk.find_bone("mixamorig_Head")).origin
	var crown: Vector3 = sk.get_bone_global_pose(sk.find_bone("mixamorig_HeadTop_End")).origin
	return (c._model.global_transform * head.lerp(crown, mgr.get_script().EYE_UP)).y - c.global_position.y


func _foot(c) -> float:
	var sk: Skeleton3D = c._skel
	var l: Vector3 = c._model.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftToeBase")).origin
	var r: Vector3 = c._model.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightToeBase")).origin
	return minf(l.y, r.y)
