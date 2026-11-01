extends SceneTree
## Photographs the vaulter going over the railing and the creeper going under it (waves.gd cross),
## from the side, for checking how it looks without playing:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/cross_shot.gd
## Saves user://cross_<who>_<n>_<step>.png (not in git): the crouch, the spring, over the rail, the
## landing; the creeper lying down, under the rail, getting up; one shot out of the air.

var gs: Node
var waves: Node
var me: CharacterBody3D
var _lamp: OmniLight3D


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	waves = main.get_node("Waves")
	me = main.get_node("Player")
	await process_frame
	me.get_node("ViewmodelView").visible = false  # the body alone in the frame
	me._hud.visible = false
	_lamp = OmniLight3D.new()  # the fight's red alarms alone leave it too dark to judge the pose
	_lamp.omni_range = 7.0
	_lamp.light_energy = 2.5
	main.add_child(_lamp)
	gs.request_pick_character("boss")
	gs.request_toggle_infinite_ammo()
	gs.cue_wave([&"phase", 16, waves.Phase.FIGHT, 99])
	waves.wave = 16
	var anchor := _spawn(&"walker", Vector3(34, 0, 0))  # never shot: the wave is not cleared under us
	anchor.path = []
	await _vaulter(-8.0, "vault", false)
	await _vaulter(-2.0, "knock", true)
	await _creeper(6.0)
	quit()


func _vaulter(z: float, name: String, knock: bool) -> void:
	_look(Vector3(12.6, 0, z - 3.4), Vector3(14.0, 0.9, z))
	_lamp.global_position = Vector3(12.0, 2.5, z - 1.0)
	var v := _spawn(&"vaulter", Vector3(waves.RAIL_X + 3.0, 0, z))
	await _until(func() -> bool: return v.cross == &"wind")
	await _frames(4)
	_save(name, 0, "arrive")
	await _until(func() -> bool: return v.cross_t > v.cross_wind * 0.7)
	_save(name, 1, "crouch")
	await _until(func() -> bool: return v.cross == &"air")
	if knock:
		await _until(func() -> bool: return v.cross_t > v.cross_air * 0.25)
		_save(name, 2, "air")
		gs.request_select_gun(1)
		waves._on_shot(gs.local_peer(), v.body._bone_at("Spine1"), Vector3.LEFT, Vector3.RIGHT, v.node, 1, false, 1)
		await _frames(8)
		_save(name, 3, "falling")
		await _until(func() -> bool: return v.cross == &"lie")
		await _frames(20)
		_save(name, 4, "down")
		await _until(func() -> bool: return v.cross == &"rise" and v.cross_t > v.cross_wind * 0.6, 10.0)
		_save(name, 5, "getting_up")
	else:
		for i in 4:
			var s: float = [0.2, 0.42, 0.65, 0.9][i]
			await _until(func() -> bool: return v.cross != &"air" or v.cross_t > v.cross_air * s)
			_save(name, 2 + i, "air%d" % roundi(s * 100))
		await _frames(12)
		_save(name, 6, "landed")
	waves._kill(v.id, &"")


func _creeper(z: float) -> void:
	_look(Vector3(12.8, 0, z - 3.0), Vector3(14.2, 0.3, z))
	_lamp.global_position = Vector3(12.5, 2.0, z - 0.5)
	var c := _spawn(&"creeper", Vector3(waves.CREEP_FROM + 3.0, 0, z))
	await _until(func() -> bool: return c.cross == &"duck")
	await _until(func() -> bool: return c.cross_t > c.cross_wind * 0.5)
	_save("creep", 0, "lying_down")
	await _until(func() -> bool: return c.cross == &"creep")
	await _frames(6)
	_save("creep", 1, "down")
	for i in 3:
		var x: float = [14.5, 14.0, 13.4][i]
		await _until(func() -> bool: return c.cross != &"creep" or (c.node as Node3D).global_position.x < x)
		_save("creep", 2 + i, "x%d" % roundi(x * 10))
	await _until(func() -> bool: return c.cross == &"rise" and c.cross_t > c.cross_wind * 0.5, 10.0)
	_save("creep", 5, "getting_up")
	await _until(func() -> bool: return c.inside, 10.0)
	await _frames(10)
	_save("creep", 6, "in")
	waves._kill(c.id, &"")


## One of `type` (not an elite) standing at `at`, off to its spot on the railing in front of it.
func _spawn(type: StringName, at: Vector3) -> Dictionary:
	var z: Dictionary
	while z.is_empty() or z.elite:
		if not z.is_empty():
			waves._kill(z.id, &"")
		waves._queue.assign([type])
		var ph: int = waves.phase
		waves.phase = waves.Phase.READY  # not let out from the pen: we set it walking here
		waves._spawn_next()
		waves.phase = ph
		z = waves._zombies[waves._next_id - 1]
	(z.node as Node3D).global_position = at
	(z.node as Node3D).look_at(at + Vector3.LEFT, Vector3.UP)
	z.rail = Vector3(z.rail.x, 0.0, at.z)
	z.path = [z.rail]
	z.released = true
	z.moving = true
	z.body.move(z.speed)
	return z


func _look(from: Vector3, at: Vector3) -> void:
	me.global_position = from
	me.reset_physics_interpolation()
	var d: Vector3 = at - (from + Vector3.UP * 1.6)
	me._yaw = atan2(-d.x, -d.z)
	me._pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _until(cond: Callable, secs := 15.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < secs * 1000.0:
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(who: String, n: int, step: String) -> void:
	var path := "user://cross_%s_%d_%s.png" % [who, n, step]
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
