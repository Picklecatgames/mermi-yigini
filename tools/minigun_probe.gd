extends SceneTree
## The minigun's first use the way a player does it: 5 pressed and the trigger held from that
## moment, through the draw, the barrels coming up and the first rounds, at a crowd on the railing.
## Every frame of the first 3 s with what the gun was doing and what compiled; then the same again
## (the second use, for comparison). Off screen:
##   Godot.exe --path . --position -10000,-10000 --resolution 1920x1080 -s res://tools/minigun_probe.gd -- [tag=x] [crowd=0]
## Writes user://minigun_<tag>.txt as well as printing.

const SLOW_MS := 22.0
const WINDOW := 9.0

var gs: Node
var main: Node
var waves: Node
var player: Node3D
var vm: Node3D
var _tag := "now"
var _on := ""
var _last := 0
var _rows := {}  # attempt -> Array of frame ms
var _slow: Array[String] = []
var _events: Array[String] = []
var _out: Array[String] = []
var _kind_last := [0, 0, 0, 0, 0]
var _t0 := 0
var _count := {}  # attempt -> event -> times
var _first_round := {}  # attempt -> s to the first round


class Clock extends Node:
	var probe: Object

	func _process(_d: float) -> void:
		probe._tick()


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			_tag = a.trim_prefix("tag=")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	waves = main.get_node("Waves")
	player = main.get_node("Player")
	vm = player.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	await process_frame
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gs.request_pick_character("worker")
	gs.request_toggle_infinite_ammo()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	gs.wave_cue.connect(_on_cue)
	gs.shot_landed.connect(func(_p: int, _at: Vector3, _n: Vector3, _d: Vector3, t: Node, _g: int, _w: bool, _c: int) -> void:
		_events.append("hit" if t and t.has_meta("zombie") else "miss"))
	var clock := Clock.new()
	clock.probe = self
	clock.process_priority = 1000
	root.add_child(clock)
	player.global_position = Vector3(12.6, 0.0, 0.0)
	player.reset_physics_interpolation()
	_aim(Vector3(30.0, 1.4, 0.0))
	await _wait(2.0)
	if not "crowd=0" in OS.get_cmdline_user_args():
		await _crowd()
	await _draw(2)
	await _wait(1.0)
	await _attempt("ilk")
	await _draw(2)
	await _wait(1.0)
	await _attempt("ikinci")
	_report()
	quit()


## Wave 10 pulled until a crowd stands at the railing.
func _crowd() -> void:
	waves.wave = 10
	gs.lever_pulled.emit(gs.local_peer())
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25_000:
		gs.mend_fence(gs.FENCE_MAX)
		await process_frame
		var near := 0
		for z: Dictionary in waves._zombies.values():
			if not z.dead and (z.node as Node3D).global_position.x < 18.0:
				near += 1
		if near >= 15 and Time.get_ticks_msec() - t0 > 8_000:
			break
	_say("crowd: %d alive" % waves._alive())


func _attempt(name: String) -> void:
	_on = name
	_rows[name] = []
	_t0 = Time.get_ticks_usec()
	_kinds()
	gs.request_select_gun(5)
	while (Time.get_ticks_usec() - _t0) / 1e6 < WINDOW:
		gs.mend_fence(gs.FENCE_MAX)
		var z := _nearest()
		if not z.is_empty():
			_aim((z.trunk as Node3D).global_position)
		vm._want_fire = 0.15  # the trigger held, as the input does every frame
		await process_frame
	_on = ""


func _tick() -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_last = now
	if _on == "":
		_events.clear()
		return
	var c: Dictionary = _count.get_or_add(_on, {})
	for e in _events:
		c[e] = c.get(e, 0) + 1
	if not _first_round.has(_on) and not _events.is_empty():
		_first_round[_on] = (now - _t0) / 1e6
	(_rows[_on] as Array).append(ms)
	var kinds := _kinds()
	if ms > SLOW_MS or kinds != "":
		var vp := root.get_viewport_rid()
		_slow.append("%-7s %5.2fs %6.1f ms  proc %5.1f phys %5.1f rcpu %5.1f gpu %5.1f  gun %d clip %-8s spin %.2f  %s %s" % [_on, (now - _t0) / 1e6, ms,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp),
				vm.gun, vm.clip, vm.spin, kinds, ", ".join(_events)])
	_events.clear()


## Pipelines compiled since the last call, by kind; "" when none.
func _kinds() -> String:
	var now := []
	for m in [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH,
			Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW,
			Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]:
		now.append(int(Performance.get_monitor(m)))
	var out := ""
	for i in 5:
		if now[i] != _kind_last[i]:
			out += "%s+%d " % [["c", "m", "s", "d", "sp"][i], now[i] - _kind_last[i]]
	_kind_last = now
	return out


func _on_cue(cue: Array) -> void:
	if cue[0] == &"die":
		_events.append("die%s" % ("" if cue.size() < 8 or cue[7] == &"" else "/" + String(cue[7])))
	elif cue[0] in [&"limb", &"blast"]:
		_events.append(String(cue[0]))


func _wait(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		gs.mend_fence(gs.FENCE_MAX)
		await process_frame


func _draw(g: int) -> void:
	if vm.gun != g:
		gs.request_select_gun(g)
	var t0 := Time.get_ticks_msec()
	while (vm.gun != g or vm.clip != "") and Time.get_ticks_msec() - t0 < 3000:
		await process_frame


func _nearest() -> Dictionary:
	var best := {}
	var d := INF
	for z: Dictionary in waves._zombies.values():
		var at: Vector3 = (z.node as Node3D).global_position
		if not z.dead and z.released and at.x < 26.0 and at.x - 12.6 < d:
			d = at.x - 12.6
			best = z
	return best


func _aim(at: Vector3) -> void:
	var eye: Vector3 = player.global_position + Vector3.UP * gs.EYE
	var d := (at - eye).normalized()
	player._yaw = atan2(-d.x, -d.z)
	player._pitch = asin(d.y)


func _report() -> void:
	for a: String in ["ilk", "ikinci"]:
		var ms: Array = (_rows.get(a, []) as Array).duplicate()
		if ms.is_empty():
			continue
		ms.sort()
		var total: float = ms.reduce(func(x: float, y: float) -> float: return x + y, 0.0)
		_say("%-7s %4d kare  ort %5.0f fps  en uzun %6.1f ms  >25 ms: %d" % [a, ms.size(), 1000.0 * ms.size() / total, ms.back(),
				ms.filter(func(m: float) -> bool: return m > 25.0).size()])
		_say("        ilk mermi %.2f s, %s" % [_first_round.get(a, -1.0), _count.get(a, {})])
	_say("\nyavas ya da derleme olan kareler:")
	for s in _slow:
		_say(s)
	var f := FileAccess.open("user://minigun_%s.txt" % _tag, FileAccess.WRITE)
	f.store_string("\n".join(_out))


func _say(s: String) -> void:
	print(s)
	_out.append(s)
