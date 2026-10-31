extends SceneTree
## A new player's firsts: the load and each first moment of the first waves (the first shot, the
## first blood, the first head and the first blast, the first minigun, the bench, the Q menu, the
## railing torn down), each one's frames: average, 1% low, the longest and the pipelines compiled then.
## Meant for a cold start, with no shader or pipeline cache as on a new machine. The user dir (and
## Godot's caches in it) lives under %APPDATA% and NVIDIA's own pipeline cache follows
## __GL_SHADER_DISK_CACHE_PATH, so point both at empty folders for the run (the real ones are left alone):
##   APPDATA=<empty> __GL_SHADER_DISK_CACHE_PATH=<empty> Godot.exe --path . --position -10000,-10000 --resolution 1920x1080 -s res://tools/first_probe.gd -- tag=soguk
## Run it a second time with the same folders for the warm numbers. Writes user://first_<tag>.txt.

const HITCH_MS := 25.0
const WINDOW := 1.5  # s of frames counted as one moment's

var gs: Node
var main: Node
var waves: Node
var player: Node3D
var vm: Node3D
var _tag := "now"
var _moment := ""
var _rows := {}  # moment -> Array of frame ms
var _pipes := {}  # moment -> pipelines compiled in it
var _order: Array[String] = []
var _last := 0
var _out: Array[String] = []


class Clock extends Node:
	var probe: Object

	func _process(_d: float) -> void:
		probe._tick()


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			_tag = a.trim_prefix("tag=")
	if "adds" in OS.get_cmdline_user_args():
		node_added.connect(_on_added)
	var clock := Clock.new()
	clock.probe = self
	clock.process_priority = 1000
	root.add_child(clock)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_say("user dir: " + OS.get_user_data_dir())
	# The load: the hall read and built, then its first two seconds (the prewarms run in them).
	var t0 := Time.get_ticks_usec()
	_begin("yukleme")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_last = t0  # the build is one long frame of its own
	await process_frame
	var built := (Time.get_ticks_usec() - t0) / 1e6
	gs = root.get_node("GameState")
	waves = main.get_node("Waves")
	player = main.get_node("Player")
	vm = player.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gs.request_pick_character("worker")
	gs.wave_cue.connect(_on_cue)
	gs.request_toggle_infinite_ammo()
	_stand(Vector3(12.6, 0.0, 0.0))
	_aim(Vector3(30.0, 1.4, 0.0))
	await _wait(2.0)
	_pipes["yukleme"] = _pipelines() - _pipes["yukleme"]
	_say("yukleme: sahne %.2f s, ilk 2 s ile %.2f s" % [built, (Time.get_ticks_usec() - t0) / 1e6])
	await _moment_of("bos", func() -> void: pass)
	await _moment_of("ilk_ates", func() -> void: await _draw(2); _aim(Vector3(30.0, 1.4, 0.0)); vm.fire())
	await _moment_of("ilk_uzi", func() -> void: await _draw(3); _aim(Vector3(30.0, 1.4, 2.0)); await _hold(0.6, false))
	await _moment_of("ilk_dalga", _first_wave)
	await _moment_of("ilk_kan", func() -> void: await _draw(2); await _hit(false, 1))
	await _moment_of("ilk_kafa", func() -> void: await _hit(true, 3))
	await _moment_of("ilk_minigun", func() -> void: await _draw(5); await _hold(1.2, false))
	await _moment_of("ilk_scorpion", func() -> void: await _draw(4); await _hold(1.0, false))
	await _moment_of("ilk_patlama", _blast)
	await _moment_of("ilk_tezgah", _bench)
	await _moment_of("ilk_q_menu", func() -> void: player.get_node("UpgradeMenu").toggle(); await _wait(1.0); player.get_node("UpgradeMenu").toggle())
	await _moment_of("ilk_cit_kirilmasi", func() -> void: gs.hurt_fence(gs.fence, 0.0))
	_report()
	quit()


var _moment_t0 := 0


func _begin(moment: String) -> void:
	_moment = moment
	_moment_t0 = Time.get_ticks_usec()
	_rows[moment] = []
	_pipes[moment] = _pipelines()
	_order.append(moment)


## Runs `body` as the moment `moment` and counts its frames until WINDOW s after it began.
func _moment_of(moment: String, body: Callable) -> void:
	await _wait(0.5)  # a quiet gap between moments
	_moment = ""
	var t0 := Time.get_ticks_msec()
	_begin(moment)
	await body.call()
	while Time.get_ticks_msec() - t0 < WINDOW * 1000.0:
		await process_frame
	_pipes[moment] = _pipelines() - _pipes[moment]
	_moment = ""


func _tick() -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_last = now
	var kinds := _kinds()
	if _moment != "":
		(_rows[_moment] as Array).append(ms)
		# A frame's draw is timed in the next one: what it drew is in the frame before's events.
		if kinds.contains(" s") and not kinds.contains(" s0 ") and "adds" in OS.get_cmdline_user_args():
			_hitches.append("    new: " + ", ".join(_adds_before + _adds))
		if ms > HITCH_MS or kinds.contains(" s") and not kinds.contains(" s0 "):
			_hitches.append("%-18s %4.2fs %7.1f ms  %s  gun %d %s  %s | before: %s" % [_moment, (now - _moment_t0) / 1e6, ms, kinds,
					vm.gun if vm else -1, vm.clip if vm else "", ", ".join(_events), ", ".join(_before)])
	_before = _events.duplicate()
	_events.clear()
	_adds_before = _adds.duplicate()
	_adds.clear()


var _events: Array[String] = []  # what happened since the last frame
var _before: Array[String] = []  # and in the frame before
var _adds: Array[String] = []  # meshes that came into the tree since the last frame (adds)
var _adds_before: Array[String] = []


func _on_added(n: Node) -> void:
	if n is GeometryInstance3D:
		var what := n.get_class()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			what += ":" + (n as MeshInstance3D).mesh.resource_path.get_file() + "/" + (n as MeshInstance3D).mesh.get_class()
		_adds.append("%s<%s" % [n.name, n.get_parent().name if n.get_parent() else ""] + "(" + what + ")")


func _on_cue(cue: Array) -> void:
	if cue[0] == &"spawn":
		_events.append("spawn %s" % cue[2])
	elif cue[0] == &"die":
		_events.append("die%s %s" % ["" if cue.size() < 8 or cue[7] == &"" else "/" + String(cue[7]), _model(cue[1])])
	elif cue[0] in [&"limb", &"blast"]:
		_events.append("%s %s" % [cue[0], _model(cue[1])])


func _model(id: int) -> String:
	return String(waves._zombies[id].body.model) if waves and waves._zombies.has(id) else "?"


var _hitches: Array[String] = []
var _kind_last := [0, 0, 0, 0, 0]


## Pipelines compiled since the last call by kind: canvas, mesh, surface, draw, specialization.
func _kinds() -> String:
	var now := []
	for m in [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH,
			Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW,
			Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]:
		now.append(int(Performance.get_monitor(m)))
	var out := "c%d m%d s%d d%d sp%d" % [now[0] - _kind_last[0], now[1] - _kind_last[1], now[2] - _kind_last[2], now[3] - _kind_last[3], now[4] - _kind_last[4]]
	_kind_last = now
	return out


func _pipelines() -> int:
	var n := 0
	for m in [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH,
			Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW,
			Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]:
		n += int(Performance.get_monitor(m))
	return n


func _first_wave() -> void:
	waves.wave = 1
	gs.lever_pulled.emit(gs.local_peer())
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20_000 and _nearest().is_empty():
		_keep_fence()
		await process_frame


## Shots at the nearest zombie, its head or its trunk, until `n` landed or it is down.
func _hit(head: bool, n: int) -> void:
	var t0 := Time.get_ticks_msec()
	var landed := [0]
	var count := func(_p: int, _at: Vector3, _n: Vector3, _d: Vector3, t: Node, _g: int, _w: bool, _c: int) -> void:
		if t and t.has_meta("zombie"):
			landed[0] += 1
	gs.shot_landed.connect(count)
	while landed[0] < n and Time.get_ticks_msec() - t0 < 4000:
		_keep_fence()
		var z := _nearest()
		if not z.is_empty():
			_aim((z.head_shape as Node3D).global_position if head else (z.trunk as Node3D).global_position)
			vm.fire()
		await process_frame
	gs.shot_landed.disconnect(count)


## The trigger held for `s` s on the nearest zombie (or down the range).
func _hold(s: float, head: bool) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		_keep_fence()
		var z := _nearest()
		if not z.is_empty():
			_aim((z.head_shape as Node3D).global_position if head else (z.trunk as Node3D).global_position)
		if vm._kit.has("spin"):
			vm.spin = 1.0
		vm.fire()
		await process_frame


## A bloater let out just past the railing, shot in the body until it bursts.
func _blast() -> void:
	var id: int = waves._next_id
	waves._hp[id] = waves.hp_of(&"bloater", 1)
	waves._hp_full[id] = waves._hp[id]
	gs.cue_wave([&"spawn", id, &"bloater", 9000, "n", Vector3(17.0, 0.0, 1.5), PI / 2.0, 2.5, 1.5, true])
	await _draw(2)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000 and waves._zombies.has(id) and not waves._zombies[id].dead:
		_keep_fence()
		_aim((waves._zombies[id].trunk as Node3D).global_position)
		vm.fire()
		await process_frame


func _bench() -> void:
	var menu: Node = null
	for c in player.get_children():
		if c.get_script() == player.BENCH_MENU:
			menu = c
	if not menu:
		_say("no bench menu")
		return
	menu.open()
	await _wait(1.2)
	menu.close()


func _keep_fence() -> void:
	if gs.fence < gs.FENCE_MAX:
		gs.mend_fence(gs.FENCE_MAX)


func _wait(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		_keep_fence()
		await process_frame


func _draw(g: int) -> void:
	if vm.gun != g:
		gs.request_select_gun(g)
	var t0 := Time.get_ticks_msec()
	while (vm.gun != g or vm.clip != "") and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	if vm.gun != g:
		_say("gun %d not drawn (%d)" % [g, vm.gun])


func _nearest() -> Dictionary:
	var best := {}
	var d := INF
	for z: Dictionary in waves._zombies.values():
		var at: Vector3 = (z.node as Node3D).global_position
		if not z.dead and z.released and at.x < 26.0 and at.x - 12.6 < d:
			d = at.x - 12.6
			best = z
	return best


func _stand(at: Vector3) -> void:
	player.global_position = at
	player.reset_physics_interpolation()


func _aim(at: Vector3) -> void:
	var eye: Vector3 = player.global_position + Vector3.UP * gs.EYE
	var d := (at - eye).normalized()
	player._yaw = atan2(-d.x, -d.z)
	player._pitch = asin(d.y)


func _report() -> void:
	_say("\n%-18s %6s %8s %8s %9s %6s %10s" % ["an", "kare", "ort ms", "1% low", "en uzun", ">25ms", "pipeline"])
	for m: String in _order:
		var ms: Array = (_rows[m] as Array).duplicate()
		if ms.is_empty():
			continue
		ms.sort()
		var total: float = ms.reduce(func(a: float, b: float) -> float: return a + b, 0.0)
		var worst: Array = ms.slice(int(ms.size() * 0.99))
		var low: float = worst.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / worst.size()
		_say("%-18s %6d %8.2f %8.1f %7.1f ms %6d %10d" % [m, ms.size(), total / ms.size(), low, ms.back(),
				ms.filter(func(v: float) -> bool: return v > HITCH_MS).size(), _pipes[m]])
	_say("\ntakilmalar (> %d ms):" % HITCH_MS)
	for h in _hitches:
		_say(h)
	var f := FileAccess.open("user://first_%s.txt" % _tag, FileAccess.WRITE)
	f.store_string("\n".join(_out))


func _say(s: String) -> void:
	print(s)
	_out.append(s)
