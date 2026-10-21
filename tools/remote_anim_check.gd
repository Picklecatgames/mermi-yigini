extends SceneTree
## Headless check of another player's third-person character (scripts/remote_players.gd):
##   Godot.exe --headless --path . -s res://tools/remote_anim_check.gd
## Feeds it poses like the network would and checks that it stands, holds every gun with both hands
## and aims it where the player looks, jogs, jumps, lands with a crouch, reloads and fires; and that
## bare-handed it holds nothing.

var mgr: Node3D
var ok := true


func _initialize() -> void:
	mgr = load("res://scripts/remote_players.gd").new()
	root.add_child(mgr)
	await process_frame
	var p := Vector3.ZERO
	var gs := root.get_node("GameState")
	await _hold(p, 0.0, 0, false, 0.5)
	_check("ground", -1.0, "stands bare-handed, no gun", func(c) -> bool: return c.speed < 0.1 and _foot(c) < 0.15 and not c._gun.visible)
	for g in range(1, gs.GUNS.size()):
		if not gs.GUNS[g].ready:
			continue
		gs.gun_changed.emit(7, g)
		await _hold(p, 0.0, 0, false, 0.3)
		_check("", -1.0, "%s: both hands on the gun (%.1f cm off)" % [gs.GUNS[g].id, _left_off_gun(mgr.character(7))], func(c) -> bool: return _left_off_gun(c) < 0.5)
		_check("ground", 0.0, "%s: aims ahead" % gs.GUNS[g].id, func(c) -> bool: return c._gun.visible)
		await _hold(p, 0.7, 0, false, 0.4)
		_check("ground", 0.7, "%s: aims up with the look" % gs.GUNS[g].id, func(c) -> bool: return c.muzzle_position().y > 1.7)
		await _hold(p, 0.0, 0, false, 0.3)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800:
		p.z -= 5.0 * 0.05
		mgr._on_pose(7, Time.get_ticks_msec() / 1000.0, p, 0.0, 0.0, 1, false)
		await create_timer(0.05).timeout
	_check("ground", 0.0, "jogs at about 5 m/s", func(c) -> bool: return absf(c.speed - 5.0) < 1.0)
	await _hold(p, 0.0, 0, true, 0.4)
	_check("jump_start", 0.0, "jumps, feet tucked up", func(c) -> bool: return _foot(c) > 0.3)
	await _hold(p, 0.0, 0, false, 0.3)
	_check("ground", 0.0, "lands with a crouch", func(c) -> bool: return c._tree.get("parameters/land/active") and c.muzzle_position().y < 1.2)
	await _hold(p, 0.0, root.get_node("GameState").Act.RELOADING, false, 0.5)
	_check("", -1.0, "reloads, left hand off the gun", func(c) -> bool: return c._tree.get("parameters/reload/active") and _left_off_gun(c) > 3.0)
	mgr.character(7).shoot()
	await process_frame  # emitted before the nodes process: the second one has advanced the tree
	await process_frame
	_check("", -1.0, "fires: shot clip and flash", func(c) -> bool: return c._tree.get("parameters/shoot/active") and c._flash_left > 0.0)
	print("remote_anim_check OK" if ok else "remote_anim_check FAIL")
	quit(0 if ok else 1)


func _hold(pos: Vector3, pitch: float, act: int, air: bool, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		mgr._on_pose(7, Time.get_ticks_msec() / 1000.0, pos, 0.0, pitch, act, air)
		await create_timer(0.05).timeout


## `state`: the legs' state machine node ("" any); `pitch` >= 0: the gun must aim along that look.
func _check(state: String, pitch: float, what: String, cond: Callable) -> void:
	var c = mgr.character(7)
	var legs: AnimationNodeStateMachinePlayback = c._tree.get("parameters/legs/playback")
	var look := Basis.from_euler(Vector3(pitch, c.rotation.y, 0.0)) * Vector3.FORWARD
	var aim: float = c._gun.global_basis.z.normalized().dot(look)
	var good: bool = (state == "" or legs.get_current_node() == state) and (pitch < 0.0 or aim > 0.995) and cond.call(c)
	print("%s %s (legs %s, aim %.3f, speed %.1f)" % ["ok  " if good else "FAIL", what, legs.get_current_node(), aim, c.speed])
	ok = ok and good


## Centimetres between the left wrist and its place on the gun.
func _left_off_gun(c) -> float:
	var w: Vector3 = c._skel.get_bone_global_pose(c._hand["L_wrist"]).origin
	return w.distance_to(c._gun.transform * c._left_wrist_on_gun)


func _foot(c) -> float:
	var sk: Skeleton3D = c._skel
	var l: Vector3 = c._model.global_transform * sk.get_bone_global_pose(sk.find_bone("L_foot_05")).origin
	var r: Vector3 = c._model.global_transform * sk.get_bone_global_pose(sk.find_bone("R_foot_010")).origin
	return minf(l.y, r.y)
