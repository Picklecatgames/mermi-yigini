extends SceneTree
## Headless check for the style rank (scripts/style_rank.gd): points, tiers, staleness, melting
## and that only this player's events count:
##   Godot.exe --headless --path . -s res://tools/style_rank_check.gd

func _initialize() -> void:
	await process_frame  # GameState in the tree, multiplayer up
	var StyleRank: GDScript = load("res://scripts/style_rank.gd")  # after the autoloads
	var gs: Node = root.get_node("GameState")
	var me: int = gs.local_peer()
	var fresh := func() -> Control:
		var r: Control = StyleRank.new()
		root.add_child(r)
		r.set_process(false)  # time moves only by step() here
		return r

	var r: Control = fresh.call()
	assert(r.points == 0.0 and r.tier() == -1, "starts with no rank")
	r.gain(["kill"])
	assert(r.tier() == 0, "a kill is a D")

	# The same move again soon pays less; fresh again after a while of others.
	r = fresh.call()
	var a: float = r.gain(["hit"])
	var b: float = r.gain(["hit"])
	var c: float = r.gain(["hit"])
	assert(b < a and c < b, "repeating a move pays less each time: %s %s %s" % [a, b, c])
	r.step(10.0)
	r.points = 1.0  # same tier as at first, so the tier's scale doesn't hide it
	assert(is_equal_approx(r.gain(["hit"]), a), "fresh again after a few seconds")

	# Variety climbs faster than the same kill over and over.
	var same: Control = fresh.call()
	var mixed: Control = fresh.call()
	var flair := ["head", "air", "bounce", "swap", "close"]
	for i in 10:
		same.gain(["kill"])
		mixed.gain(["kill", flair[i % flair.size()]])
		same.step(2.5)  # past STREAK_TIME: no streak pay in either
		mixed.step(2.5)
		same.points += same.DRAIN[maxi(same.tier(), 0)] * 0.5  # undo the melting past GRACE
		mixed.points += mixed.DRAIN[maxi(mixed.tier(), 0)] * 0.5
	assert(mixed.points > same.points * 1.3, "mixing moves beats repeating: %s vs %s" % [mixed.points, same.points])

	# A stylish run reaches SSS.
	r = fresh.call()
	var tiers := [r.tier()]
	for i in 40:
		var moves := ["kill"]
		moves.append(flair[i % flair.size()])
		if i % 3 == 0:
			moves.append(flair[(i + 2) % flair.size()])
		r.step(0.6)
		r.gain(moves)
		if r.tier() != tiers[-1]:
			tiers.append(r.tier())
	assert(r.tier() == 6, "a long varied streak is SSS, got %d" % r.tier())
	assert(tiers == [-1, 0, 1, 2, 3, 4, 5, 6], "climbed one tier at a time: %s" % [tiers])

	# Melting: nothing during GRACE, then down tier by tier to nothing, faster up high.
	var top: float = r.points
	r.step(r.GRACE - 0.1)
	assert(r.points == top, "no melting during the grace")
	r.step(0.2)
	assert(r.points < top, "melts after the grace")
	var drops := []
	var t := 0.0
	var at_a := -1.0
	while r.tier() >= 0 and t < 120.0:
		var before: int = r.tier()
		r.step(0.1)
		t += 0.1
		if r.tier() != before:
			drops.append(r.tier())
			if before == 4:
				at_a = t
	assert(drops == [5, 4, 3, 2, 1, 0, -1], "melts down a tier at a time to nothing: %s" % [drops])
	assert(at_a > 0.0 and at_a < t - at_a, "the top tiers melt faster than the bottom ones")

	# Only this player's events, from the world signals.
	r = fresh.call()
	gs.shot_landed.emit(me + 1, Vector3.ZERO, Vector3.UP, Vector3.FORWARD, null, 5, false, 1)
	assert(r.points == 0.0, "someone else's hit is theirs")
	gs.shot_landed.emit(me, Vector3.ZERO, Vector3.UP, Vector3.FORWARD, null, 0, false, 0)
	assert(r.points == 0.0, "a miss pays nothing")
	gs.shot_landed.emit(me, Vector3.ZERO, Vector3.UP, Vector3.FORWARD, null, 5, true, 1)
	var head_hit: float = r.points
	assert(head_hit > 0.0, "my paying hit counts")
	gs.gun_changed.emit(me, 2)
	gs.shot_landed.emit(me, Vector3.ZERO, Vector3.UP, Vector3.FORWARD, null, 5, false, 2)
	assert(r.points - head_hit > r.MOVES.hit * r.GAIN[0], "a hit right after a gun swap is worth more")
	var p: float = r.points
	r._on_zombie_killed(me + 1, &"walker", true, Vector3(15, 0, 0), "deagle")
	assert(r.points == p, "someone else's kill is theirs")
	r._on_zombie_killed(me, &"walker", false, Vector3(30, 0, 0), "deagle")
	var far: float = r.points - p
	r.step(10.0)
	r.points = p
	r._on_zombie_killed(me, &"walker", false, Vector3(gs.FIRING_LINE_X + 1.0, 0, 0), "deagle")
	assert(r.points - p > far, "a kill at the railing is worth more than one far off")
	r = fresh.call()
	r._on_zombie_killed(me, &"walker", false, Vector3(30, 0, 0), "deagle")
	r.step(3.0)  # past the streak and the grace
	p = r.points
	r._on_zombie_killed(me, &"walker", false, Vector3(30, 0, 0), "deagle")
	var same_gun: float = r.points - p
	r._stale.clear()
	p = r.points
	r._on_zombie_killed(me, &"walker", false, Vector3(30, 0, 0), "uzi")
	assert(r.points - p > same_gun + r.MOVES.swap * 0.5, "a kill with another gun than the last is a swap")
	p = r.points
	gs.player_shot.emit(me + 1, me, Vector3.ZERO, Vector3.FORWARD, "")
	assert(r.points < p, "a teammate's round knocks it down")
	print("style_rank_check: OK")
	quit()
