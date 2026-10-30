extends SceneTree
## Hitches in play: the frame times of the real hall with the real player through a run of fixed
## scenes, each frame's CPU (scripts, physics, render submit) and GPU time, and every long frame with
## what happened in it (pipelines compiled, zombies spawned, kills, limbs, blasts). Off screen:
##   Godot.exe --path . --position -10000,-10000 --resolution 1920x1080 -s res://tools/spike_probe.gd -- [tag=x]
## Scenes, in this order (the first time of everything is in the run, as for a new player):
##   bos       the empty range from the railing
##   dalga     wave 10 pulled, the dead walk out to the railing (up to 40 at once)
##   kalabalik the crowd clawing at the railing, nobody shooting
##   minigun   the minigun held down on the crowd (bodies burst, limbs fly)
##   kafa      the heavy pistol at heads (heads burst)
##   sisko     bloaters at the railing shot down (blasts)
##   suru      the Scorpion sprayed over a full railing
## For a cold start (no shader or pipeline cache, as on a new machine) move the user dir's
## shader_cache and vulkan folders aside first. Writes user://spike_<tag>.txt as well as printing.

const SCENES := ["bos", "dalga", "kalabalik", "minigun", "kafa", "sisko", "suru"]
const HITCH_MS := 25.0  # a frame this long is felt at any frame rate the game runs at
const WAVE := 10

var gs: Node
var main: Node
var waves: Node
var player: Node3D
var vm: Node3D
var _tag := "now"
var _scene := ""
var _events: Array[String] = []  # what happened since the last frame
var _frames := {}  # scene -> Array of [ms, process ms, physics ms, render cpu ms, gpu ms]
var _hitches: Array[String] = []
var _last := 0
var _pipes := 0
var _out: Array[String] = []
var _stop := false
var _t0 := 0


class Clock extends Node:
	var probe: Object

	func _process(_d: float) -> void:
		probe._tick()


## Stamps the time as the tree's processing passes its priority; with `seg` set, the span from the
## stamp before it is that segment's.
class Mark extends Node:
	var probe: Object
	var seg := ""

	func _init(p: Object, priority: int, s := "") -> void:
		probe = p
		process_priority = priority
		seg = s

	func _process(_d: float) -> void:
		probe._mark(seg)
		if seg == "rest":  # queued after the skeletons' own deferred updates: their span
			probe._mark.call_deferred("skel")


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
	_hook()
	_switch_off()
	var clock := Clock.new()
	clock.probe = self
	clock.process_priority = 1000
	root.add_child(clock)
	# The spans of one frame's processing: before the waves, the waves, the zombies' scripts, their
	# animation players, everything after (the skeletons and their modifiers come later, deferred).
	waves.process_priority = 100
	for m in [Mark.new(self, -100000), Mark.new(self, 99, "other"), Mark.new(self, 101, "waves"),
			Mark.new(self, 201, "bodies"), Mark.new(self, 301, "anim"), Mark.new(self, 999, "rest")]:
		root.add_child(m)
	waves.child_entered_tree.connect(func(n: Node) -> void: _order.call_deferred(n))
	_stand(Vector3(12.6, 0.0, 0.0))
	_aim(Vector3(30.0, 1.4, 0.0))
	for f in 120:  # the hall's own first frames are loading, not play
		await process_frame
	_say("pipelines in loading: %d" % _pipelines())
	await _run("bos", func() -> void: await _wait(5.0))
	await _run("dalga", _dalga)
	await _run("kalabalik", func() -> void: await _wait(5.0))
	await _run("minigun", func() -> void: await _shoot(5, 10.0, false))
	await _run("kafa", func() -> void: await _shoot(2, 8.0, true))
	await _run("sisko", _sisko)
	await _run("suru", func() -> void: await _shoot(4, 8.0, false))
	_report()
	quit()


## off=a,b: parts switched off from the start, to price them (as in perf_probe.gd, and the zombies':
## zshadow their meshes casting no shadow, react the hit springs, bars the hit point bars).
var _off: PackedStringArray = []


func _switch_off() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("off="):
			_off = a.trim_prefix("off=").split(",")
	var env: Environment = (main.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	for f in _off:
		match f:
			"ssr", "ssil", "ssao", "glow":
				env.set(f + "_enabled", false)
			"fog":
				env.volumetric_fog_enabled = false
			"shadows":
				for l: Light3D in main.find_children("*", "Light3D", true, false):
					if not l is DirectionalLight3D:
						l.shadow_enabled = false
			"lamp_shadows":
				for l: SpotLight3D in main.find_children("*", "SpotLight3D", true, false):
					if l.distance_fade_enabled:
						l.shadow_enabled = false
		_say("off: " + f)
	if "alarm" in _off:
		waves._alarms.clear()
	if "sparks" in _off:
		waves._fence.set("_sparks", 1 << 20)
	if "zshadow" in _off or "bars" in _off or "react" in _off or "fit" in _off or "anim" in _off:
		waves.child_entered_tree.connect(func(n: Node) -> void: _strip.call_deferred(n))


func _strip(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if "fit" in _off and n.has_meta("zombie") and waves._zombies.has(n.get_meta("zombie")):
		waves._zombies[n.get_meta("zombie")].bones = []
	for c in n.find_children("*", "", true, false):
		if "zshadow" in _off and c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if "bars" in _off and c.get_script() == waves.BAR:
			c.queue_free()
		if "react" in _off and c is SkeletonModifier3D:
			(c as SkeletonModifier3D).active = false
		if "anim" in _off and c is AnimationPlayer:
			(c as AnimationPlayer).active = false


func _run(scene: String, body: Callable) -> void:
	if _stop:
		return
	_scene = scene
	_frames[scene] = []
	_last = Time.get_ticks_usec()
	_t0 = _last
	_pipes = _pipelines()
	await body.call()
	_scene = ""
	_stop = _stop or ("stop=" + scene) in OS.get_cmdline_user_args()


var _stamp := 0
var _segs := {}  # scene -> seg -> total usec


func _mark(seg: String) -> void:
	var now := Time.get_ticks_usec()
	if seg != "" and _scene != "":
		var d: Dictionary = _segs.get_or_add(_scene, {})
		d[seg] = d.get(seg, 0) + now - _stamp
	_stamp = now


## A zombie's script nodes go in the "bodies" span, its animation player in "anim".
func _order(n: Node) -> void:
	if not is_instance_valid(n):
		return
	for c in n.find_children("*", "", true, false):
		if c is AnimationMixer:
			c.process_priority = 300
		elif c.get_script() != null:
			c.process_priority = 200


func _tick() -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_last = now
	if _scene == "":
		_events.clear()
		return
	var vp := root.get_viewport_rid()
	var row := [ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp)]
	(_frames[_scene] as Array).append(row)
	var pipes := _pipelines()
	var kinds := _kinds()
	if ms > HITCH_MS:
		_hitches.append("%-8s %5.1fs %6.1f ms  proc %5.1f  phys %5.1f  rcpu %5.1f  gpu %5.1f  pipelines +%d %s  %s" % [_scene, (now - _t0) / 1e6, ms, row[1], row[2], row[3], row[4],
				pipes - _pipes, kinds, ", ".join(_events)])
	_pipes = pipes
	_events.clear()


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


func _hook() -> void:
	gs.wave_cue.connect(_on_cue)
	gs.shot_landed.connect(func(_p: int, _at: Vector3, _n: Vector3, _d: Vector3, t: Node, _g: int, _w: bool, _c: int) -> void:
		_events.append("hit" if t and t.has_meta("zombie") else "miss"))


func _on_cue(cue: Array) -> void:
	if cue[0] == &"spawn":
		_events.append("spawn %s" % cue[2])
	elif cue[0] == &"die":
		_events.append("die%s" % ("" if cue.size() < 8 or cue[7] == &"" else "/" + String(cue[7])))
	elif cue[0] in [&"limb", &"blast"]:
		_events.append(String(cue[0]))


func _stand(at: Vector3) -> void:
	player.global_position = at
	player.reset_physics_interpolation()


func _aim(at: Vector3) -> void:
	var eye: Vector3 = player.global_position + Vector3.UP * gs.EYE
	var d := (at - eye).normalized()
	player._yaw = atan2(-d.x, -d.z)
	player._pitch = asin(d.y)


func _wait(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		gs.mend_fence(gs.FENCE_MAX)
		await process_frame


func _dalga() -> void:
	waves.wave = WAVE
	gs.lever_pulled.emit(gs.local_peer())  # (the lever is out of reach from the railing)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25_000:
		gs.mend_fence(gs.FENCE_MAX)
		await process_frame
		var near := 0
		for z: Dictionary in waves._zombies.values():
			if not z.dead and (z.node as Node3D).global_position.x < 18.0:
				near += 1
		if near >= 25 and Time.get_ticks_msec() - t0 > 12_000:
			break
	_say("dalga: %d alive, %d waiting" % [waves._alive(), waves._queue.size()])


## Holds gun `g` on the nearest living zombie for `s` s: at its head or its trunk.
func _shoot(g: int, s: float, head: bool) -> void:
	await _draw(g)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		gs.mend_fence(gs.FENCE_MAX)
		var z := _nearest()
		if not z.is_empty():
			var at: Vector3 = (z.head_shape as Node3D).global_position if head else (z.trunk as Node3D).global_position
			_aim(at)
			if vm._kit.has("spin"):
				vm.spin = 1.0
			vm.fire()
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


## Six bloaters let out just past the railing, shot in the body with the heavy pistol.
func _sisko() -> void:
	for i in 6:
		var id: int = waves._next_id
		waves._hp[id] = waves.hp_of(&"bloater", WAVE)
		waves._hp_full[id] = waves._hp[id]
		gs.cue_wave([&"spawn", id, &"bloater", 9000 + i, "n", Vector3(19.0, 0.0, -6.0 + 2.4 * i), PI / 2.0, 2.5, -6.0 + 2.4 * i, true])
	await _wait(0.5)
	await _draw(2)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		gs.mend_fence(gs.FENCE_MAX)
		var z := {}
		for o: Dictionary in waves._zombies.values():
			if not o.dead and o.kind == &"bloater":
				z = o
				break
		if z.is_empty():
			break
		_aim((z.trunk as Node3D).global_position)
		vm.fire()
		await process_frame
	await _wait(2.0)


func _report() -> void:
	_say("\n%-8s %7s %7s %7s %8s %8s %7s %7s %7s %6s" % ["sahne", "kare", "ort fps", "1% low", "en uzun", "takilma", "proc", "phys", "rcpu", "gpu"])
	for s: String in SCENES:
		var rows: Array = _frames.get(s, [])
		if rows.is_empty():
			continue
		var ms: Array = rows.map(func(r: Array) -> float: return r[0])
		ms.sort()
		var total: float = ms.reduce(func(a: float, b: float) -> float: return a + b, 0.0)
		var worst: Array = ms.slice(int(ms.size() * 0.99))
		var low: float = worst.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / worst.size()
		var avg := [0.0, 0.0, 0.0, 0.0]
		for r: Array in rows:
			for i in 4:
				avg[i] += r[i + 1] / rows.size()
		_say("%-8s %7d %7.0f %7.0f %6.1f ms %8d %7.2f %7.2f %7.2f %6.2f" % [s, rows.size(), 1000.0 * rows.size() / total, 1000.0 / low,
				ms.back(), ms.filter(func(m: float) -> bool: return m > HITCH_MS).size(), avg[0], avg[1], avg[2], avg[3]])
	_say("\nkare basina ms, isleme sirasindaki bolumler:")
	for sc: String in SCENES:
		if not _segs.has(sc):
			continue
		var n: int = (_frames[sc] as Array).size()
		var line := "%-9s" % sc
		for seg in ["other", "waves", "bodies", "anim", "rest", "skel"]:
			line += "  %s %5.2f" % [seg, _segs[sc].get(seg, 0) / 1000.0 / n]
		_say(line)
	_say("\ntakilmalar (> %d ms):" % HITCH_MS)
	for h in _hitches:
		_say(h)
	var f := FileAccess.open("user://spike_%s.txt" % _tag, FileAccess.WRITE)
	f.store_string("\n".join(_out))


func _say(s: String) -> void:
	print(s)
	_out.append(s)
