extends SceneTree
## Headless check of the night's trickle out of the wood (scripts/waves.gd _night_step; 2026-11-05,
## the user: not all at once when the night comes, one or two at random out of the wood, coming at us):
##   Godot.exe --headless --path . -s res://tools/zombie_night_check.gd
## Runs NIGHTS nights on the real clock, quickened (Engine.time_scale), with one player on the pad
## looking about, and prints every group let out: the night, the hour, how far into the night, how
## many and where. Passes when every night lets out its whole wave (waves.gd _plan), one or two at a
## time (packs of dogs or the swarm aside), the first only after a quiet start, the gaps shrinking as
## the night goes on, more every night, each up in the wood, out of sight and away from the player.
## `--nights=N` for more.

const STAND := Vector3(10.0, 0.0, 2.0)
const SPEED := 24.0  # Engine.time_scale: a night in about 25 s

var main: Node
var waves: Node
var gs: Node
var nights := 3


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nights="):
			nights = int(a.trim_prefix("--nights="))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	waves = main.get_node("Waves")
	var me: Node3D = main.get_node("Player")
	for i in 40:
		await physics_frame
	while waves._nav.navigation_mesh == null:
		await process_frame
	gs.hour = 17.0  # the evening before the first night
	Engine.time_scale = SPEED
	var last_log := 0
	var started: int = gs.nights
	var w_start: int = waves.wave
	var yaw := 0.0
	var made := {}  # night -> how many came
	var t0 := Time.get_ticks_msec()
	var ok := true
	while gs.nights < started + nights or gs.night_of(gs.hour) > 0.0:
		await process_frame
		# The player turns slowly on the spot, so "out of sight" is put to the test all round.
		yaw = fmod(yaw + 0.6 * main.get_process_delta_time(), TAU)
		me.global_position = Vector3(STAND.x, me.global_position.y, STAND.z)
		gs.player().pos = me.global_position
		gs.player().has_pose = true
		gs.player().yaw = yaw
		gs.player().hp = gs.HP_MAX
		gs.player().down = false
		for z: Dictionary in waves._zombies.values():  # what came, gone again: the ones still to come have room
			if not z.dead and Vector2(z.node.global_position.x - STAND.x, z.node.global_position.z - STAND.z).length() < 3.0:
				z.node.free()
				waves._zombies.erase(z.id)
				break
		while last_log < waves.night_log.size():
			var e: Array = waves.night_log[last_log]
			last_log += 1
			var at: Vector3 = e[4]
			var off := Vector2(at.x - STAND.x, at.z - STAND.z).length() if at != Vector3.INF else -1.0
			var q: Vector2 = (Vector2(at.x, at.z) - waves.CLEARING_CENTRE) / waves.CLEARING_RADII
			var into: float = (q.length() - 1.0) * minf(waves.CLEARING_RADII.x, waves.CLEARING_RADII.y)
			print("night %d  %05.2f o'clock  %4.0f%% into it  %d up  %5.1f m off the player, %4.1f m into the wood" % [e[0], e[2], e[1] * 100.0, e[3], off, into])
			made[e[0]] = made.get(e[0], 0) + e[3]
			if at == Vector3.INF:
				print("  FAIL: no hidden spot, from the wood's edge instead")
				ok = false
			elif off < waves.HIDE_NEAR or into < 3.0:
				print("  FAIL: too near or not in the wood")
				ok = false
			if e[3] > 2:
				var group_ok := true
				# a pack (dogs, the swarm) may come together
				group_ok = waves.dogs(waves._night_wave) >= e[3] or waves.swarm(waves._night_wave) >= e[3]
				if not group_ok:
					print("  FAIL: more than two at once")
					ok = false
		if Time.get_ticks_msec() - t0 > 600_000:
			print("FAIL: timed out")
			ok = false
			break
	Engine.time_scale = 1.0
	# Per night: the whole wave came, the first after a quiet start, the gaps shrinking, more each night.
	var prev := 0
	for n: int in range(started + 1, started + nights + 1):
		var rows: Array = waves.night_log.filter(func(e: Array) -> bool: return e[0] == n)
		var want: int = waves._plan(w_start + n - started - 1).size()
		if rows.is_empty():
			print("FAIL: night %d let nobody out" % n)
			ok = false
			continue
		var first: float = rows[0][1]
		var gaps := []
		for i in range(1, rows.size()):
			gaps.append(rows[i][1] - rows[i - 1][1])
		var half := gaps.size() / 2
		var early := 0.0
		var late := 0.0
		for i in gaps.size():
			if i < half:
				early += gaps[i]
			else:
				late += gaps[i]
		early /= maxf(half, 1)
		late /= maxf(gaps.size() - half, 1)
		print("night %d: %d came in %d groups, the first %.0f%% in, gaps %.1f%% early, %.1f%% late" % [n, made.get(n, 0), rows.size(), first * 100.0, early * 100.0, late * 100.0])
		if made.get(n, 0) != want:
			print("  FAIL: its wave is %d" % want)
			ok = false
		if first < waves.NIGHT_QUIET * 0.9:
			print("  FAIL: no quiet start")
			ok = false
		if gaps.size() >= 4 and late >= early:
			print("  FAIL: the gaps do not shrink")
			ok = false
		if made.get(n, 0) <= prev:
			print("  FAIL: not more than the night before")
			ok = false
		prev = made.get(n, 0)
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
