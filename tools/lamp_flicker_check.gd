extends SceneTree
## Headless check of the head lamp's flicker (scripts/head_lamp.gd, scripts/lamp_flicker.gd):
##   Godot.exe --headless --path . -s res://tools/lamp_flicker_check.gd
## The flicker itself: a few quick drop-outs and a moment dim, short, back to the steady beam, the
## same from the same seed. The limits, over simulated nights: a player's gap and nightly cap, the
## gap between anyone's, the night's cap, never the same player twice running; with nothing near it
## still happens now and then, far less often. In the world at night: a dead one behind the player,
## or behind a wall in front, counts; one in plain view, or too close or too far, doesn't; a real
## walker from the test menu counts as well. Then the event: only that player's lamp flickers, the
## light dropping and coming back, on a client's copy of it too.

var gs: Node
var main: Node
var _failed := false


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("  FAIL  never finished (a script error above?)")
		quit(1))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	main.get_node("Waves").night_spawns = false
	for i in 5:
		await physics_frame
	var rolls: Node = gs.lamp_flicker_rolls
	rolls.auto = false
	if _shape() and _limits(rolls) and await _world(rolls) and await _lamps():
		print("LAMP FLICKER CHECK OK")
	quit(1 if _failed else 0)


func _ok(cond: bool, what: String) -> bool:
	print(("  ok  " if cond else "  FAIL  ") + what)
	if not cond:
		_failed = true
	return cond


func _shape() -> bool:
	var LAMP := preload("res://scripts/head_lamp.gd")
	var lengths := []
	for seed in 300:
		var steps: Array = LAMP.flicker_steps(seed)
		var n: float = LAMP.flicker_length(steps)
		lengths.append(n)
		var outs := 0
		var was := 1.0
		var dim := 0.0  # s spent between 0.25 and 0.7
		var t := 0.0
		while t < n:
			var v: float = LAMP.flicker_level(steps, t)
			if v < 0.15 and was >= 0.15:
				outs += 1
			if v > 0.25 and v < 0.7:
				dim += 1.0 / 240.0
			was = v
			t += 1.0 / 240.0
		if n <= 0.5 or n >= 2.0:
			return _ok(false, "seed %d: %.2f s long" % [seed, n])
		if outs < 2 or dim < 0.15:
			return _ok(false, "seed %d: %d drop-outs, %.2f s dim" % [seed, outs, dim])
		if LAMP.flicker_level(steps, n + 0.01) != 1.0 or LAMP.flicker_steps(seed) != steps:
			return _ok(false, "seed %d: back to steady, the same again" % seed)
	lengths.sort()
	return _ok(true, "300 flickers: 2-4 drop-outs and a dim moment each, %.2f-%.2f s, back to steady, the same from the same seed" % [lengths[0], lengths[-1]])


## Nights of NIGHT s under the rolls every CHECK s; `near`: whether a dead one is close all night.
func _nights(rolls: Node, peers: Array, near: bool, count: int) -> Array:
	const NIGHT := 480.0  # 21:00 to 05:00 of full dark, an hour a minute
	var out := []
	for night in count:
		gs.nights = 1000 + night
		rolls.history.clear()
		var t := 0.0
		while t < NIGHT:
			rolls.now += rolls.CHECK
			t += rolls.CHECK
			rolls.roll(func(_p: int) -> bool: return near, peers)
		out.append(rolls.history.duplicate())
		rolls.now += 1000.0  # day
	return out


func _limits(rolls: Node) -> bool:
	var nights := _nights(rolls, [1, 2, 3, 4], true, 60)
	var total := 0
	for h: Array in nights:
		total += h.size()
		if h.size() > rolls.ALL_NIGHT:
			return _ok(false, "%d flickers in a night (ALL_NIGHT %d)" % [h.size(), rolls.ALL_NIGHT])
		var per := {}
		for i in h.size():
			per[h[i][1]] = per.get(h[i][1], []) + [h[i][0]]
			if i > 0 and h[i][0] - h[i - 1][0] < rolls.ANY_GAP:
				return _ok(false, "two flickers %.0f s apart (ANY_GAP %.0f)" % [h[i][0] - h[i - 1][0], rolls.ANY_GAP])
			if i > 0 and h[i][1] == h[i - 1][1]:
				return _ok(false, "player %d twice running" % h[i][1])
		for peer: int in per:
			var at: Array = per[peer]
			if at.size() > rolls.PLAYER_NIGHT:
				return _ok(false, "player %d: %d a night" % [peer, at.size()])
			for i in range(1, at.size()):
				if at[i] - at[i - 1] < rolls.PLAYER_GAP:
					return _ok(false, "player %d: %.0f s apart" % [peer, at[i] - at[i - 1]])
	if not _ok(true, "4 players, a dead one always near, 60 nights: %.1f flickers a night, within every limit" % (float(total) / nights.size())): return false
	var solo := _nights(rolls, [1], true, 60)
	var solo_n := 0
	for h: Array in solo:
		solo_n += h.size()
		if h.size() > rolls.PLAYER_NIGHT or (h.size() == 2 and h[1][0] - h[0][0] < rolls.PLAYER_GAP):
			return _ok(false, "solo: %s" % [h])
	if not _ok(solo_n > 0, "solo, always near: %.1f a night, within PLAYER_NIGHT and PLAYER_GAP (alone, twice running is allowed)" % (float(solo_n) / solo.size())): return false
	var empty := _nights(rolls, [1, 2, 3, 4], false, 60)
	var empty_n := 0
	for h: Array in empty:
		empty_n += h.size()
		for f: Array in h:
			if f[2]:
				return _ok(false, "a flicker with nothing there counted as near")
	return _ok(empty_n > 0 and empty_n < total / 3, "nothing near, 4 players, 60 nights: %.2f a night (with one near %.1f)" % [float(empty_n) / empty.size(), float(total) / nights.size()])


func _dummy(at: Vector3) -> StaticBody3D:
	var z := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 0.9
	z.add_child(shape)
	z.add_to_group("target")
	z.set_meta(&"zombie", 900)
	main.add_child(z)
	z.global_position = at
	return z


func _world(rolls: Node) -> bool:
	gs.hour = 0.0  # midnight
	const PEER := 77
	const AT := Vector3(-60.0, 0.0, 60.0)  # out in the open
	var p = gs.player(PEER)
	p.pos = AT
	p.has_pose = true
	p.yaw = 0.0  # looking along -z
	var cases := [  # [offset, unseen near]
		[Vector3(0, 0, 10), true, "10 m behind"],
		[Vector3(9, 0, 0), true, "9 m to the side"],
		[Vector3(0, 0, -10), false, "10 m ahead, in plain view"],
		[Vector3(0, 0, 4), false, "4 m behind: too close, a fight"],
		[Vector3(0, 0, 20), false, "20 m behind: too far"],
	]
	for c: Array in cases:
		var z := _dummy(AT + c[0])
		await physics_frame
		var got: bool = rolls.unseen_near(PEER)
		z.free()
		if not _ok(got == c[1], "%s: %s" % [c[2], "counts" if got else "doesn't"]): return false
	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	box.shape.size = Vector3(3.0, 3.0, 0.4)
	wall.add_child(box)
	main.add_child(wall)
	wall.global_position = AT + Vector3(0, 1.5, -5)
	var z := _dummy(AT + Vector3(0, 0, -10))
	for i in 2:
		await physics_frame
	var hidden: bool = rolls.unseen_near(PEER)
	z.free()
	wall.free()
	if not _ok(hidden, "10 m ahead behind a wall (a tree): counts"): return false
	var waves: Node = main.get_node("Waves")
	var before: Array = waves._zombies.keys()
	gs.request_debug_spawn("walker", AT + Vector3(0, 0, 11), 0.0, 1)
	var new: Array = waves._zombies.keys().filter(func(id: int) -> bool: return not id in before)
	if not _ok(new.size() == 1, "a walker came up from the test menu"): return false
	waves._zombies[new[0]].node.global_position.z = AT.z + 11.0  # the menu puts it up where it likes
	await physics_frame
	var real: bool = rolls.unseen_near(PEER)
	waves._zombies[new[0]].node.global_position.z = AT.z - 11.0
	await physics_frame
	var seen: bool = rolls.unseen_near(PEER)
	return _ok(real and not seen, "a real walker 11 m behind counts, 11 m ahead in view doesn't")


func _lamps() -> bool:
	var LAMP := preload("res://scripts/head_lamp.gd")
	var ours: SpotLight3D = main.get_node("Player").find_children("*", "SpotLight3D", true, false).filter(func(l: Node) -> bool: return l.get_script() == LAMP)[0]
	var holder := Node3D.new()  # a remote body: remote_players.gd Character has `peer`
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar peer := 5\n"
	script.reload()
	holder.set_script(script)
	main.add_child(holder)
	var theirs: SpotLight3D = LAMP.new()
	holder.add_child(theirs)
	gs.request_toggle_torch()  # our flashlight out (F); peer 5's said to be out as well
	theirs.held = true
	var t0 := Time.get_ticks_msec()
	while (ours.lit < 1.0 or theirs.lit < 1.0) and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	if not _ok(ours.lit == 1.0 and theirs.lit == 1.0 and ours.owner_peer() == gs.local_peer() and theirs.owner_peer() == 5, "both flashlights out, full on; ours is the local player's, the other peer 5's"): return false
	# The host's call for us: only our lamp.
	var rolls: Node = gs.lamp_flicker_rolls
	rolls.now += 10000.0
	if not _ok(gs.try_lamp_flicker(gs.local_peer()) and not gs.try_lamp_flicker(gs.local_peer()), "try_lamp_flicker went, at once again it doesn't (PLAYER_GAP)"): return false
	# Frames here are long and uneven: a 30 ms drop-out may fall between two. Each frame the light must
	# be the flicker's own level at the time the lamp is at, and the whole of it must play.
	var steps: Array = ours._steps.duplicate()
	var played := steps.size() > 0
	var off := 0.0  # the worst gap between the light and the flicker's level
	var other_low := 1.0
	var energies := []
	var low := 1.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await process_frame
		var want: float = LAMP.flicker_level(steps, ours._flick_t) if ours.flickering() else 1.0
		off = maxf(off, absf(ours.light_energy / ours.ENERGY - want))
		low = minf(low, ours.light_energy / ours.ENERGY)
		other_low = minf(other_low, theirs.light_energy / theirs.ENERGY)
		energies.append(snappedf(ours.light_energy / ours.ENERGY, 0.01))
	print("    our lamp, frame by frame: ", energies.slice(0, 40))
	if not _ok(played and off < 0.01 and low < 0.7 and other_low == 1.0 and not ours.flickering() and ours.lit == 1.0,
			"our lamp followed its flicker every frame (down to %.2f in the frames drawn) and came back; peer 5's stayed steady" % low): return false
	# A client hears the host's event: peer 5's lamp flickers on its machine.
	gs._event(&"lamp_flicker", [5, 1234])
	await process_frame
	return _ok(theirs.flickering() and not ours.flickering(), "the event off the wire flickers peer 5's lamp only")
