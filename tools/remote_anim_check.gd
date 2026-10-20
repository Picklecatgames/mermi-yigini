extends SceneTree
## Headless check of another player's third-person character (scripts/remote_players.gd):
##   Godot.exe --headless --path . -s res://tools/remote_anim_check.gd
## Feeds it poses like the network would and checks that it stands, aims where the player looks,
## jogs, jumps, lands with a crouch, reloads and fires.

var mgr: Node3D
var ok := true


func _initialize() -> void:
	mgr = load("res://scripts/remote_players.gd").new()
	root.add_child(mgr)
	await process_frame
	var p := Vector3.ZERO
	await _hold(p, 0.0, 0, false, 0.5)
	_check("ground", 0.0, "stands", func(c) -> bool: return c.speed < 0.1 and _foot(c) < 0.15)
	await _hold(p, 0.7, 0, false, 0.4)
	_check("ground", 0.7, "aims up with the look", func(c) -> bool: return c.muzzle_position().y > 1.7)
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
	_check("", -1.0, "reloads", func(c) -> bool: return c._tree.get("parameters/reload/active"))
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


func _foot(c) -> float:
	var sk: Skeleton3D = c._skel
	var l: Vector3 = c._model.global_transform * sk.get_bone_global_pose(sk.find_bone("L_foot_05")).origin
	var r: Vector3 = c._model.global_transform * sk.get_bone_global_pose(sk.find_bone("R_foot_010")).origin
	return minf(l.y, r.y)
