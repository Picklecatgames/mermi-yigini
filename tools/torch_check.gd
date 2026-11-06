extends SceneTree
## Headless check of the flashlight (GameState.request_toggle_torch, scripts/head_lamp.gd,
## viewmodel.gd TORCH_*, scripts/lamp_flicker.gd's blackout):
##   Godot.exe --headless --path . -s res://tools/torch_check.gd
## F takes it out and the gun goes, a gun key puts it away; in hand the first-person lantern shows,
## nothing fires, the light is on whatever the hour; out of hand it is off. The blackout: a stutter,
## seconds of dark, back on; only in the wood, only with it in hand, BLACKOUT_GAP and BLACKOUT_NIGHT
## hold; with the creature, a walker stands in front of the player when the light comes back. Off the
## wire: another player's flashlight comes out and dies on this machine as on theirs.

const LAMP := preload("res://scripts/head_lamp.gd")

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
	gs.lamp_flicker_rolls.auto = false
	if await _hand() and _steps() and await _blackout() and await _remote():
		print("TORCH CHECK OK")
	quit(1 if _failed else 0)


func _ok(cond: bool, what: String) -> bool:
	print(("  ok  " if cond else "  FAIL  ") + what)
	if not cond:
		_failed = true
	return cond


func _wait(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await process_frame


func _hand() -> bool:
	var p = gs.player()
	var player: Node = main.get_node("Player")
	var vm: Node = player.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	var lamp: SpotLight3D = player.get(&"_lamp")
	gs.hour_rate = 0.0
	gs.hour = 12.0  # by day: the light is the player's call, not the sun's
	p.has_pistol = true
	gs.request_select_gun(1)
	await _wait(0.5)
	if not _ok(p.gun == 1 and not p.torch and lamp.lit == 0.0, "the pistol in hand, no flashlight, no light"): return false
	gs.request_toggle_torch()
	if not _ok(p.torch and p.gun == 0, "F: the flashlight out, the pistol away"): return false
	await _wait(2.0)
	if not _ok(vm.torch and vm._torch.visible and not vm._can_fire(), "first person: the lantern in the hand, nothing fires"): return false
	if not _ok(lamp.lit == 1.0 and lamp.visible and lamp.light_energy > 1.0, "by day too, the light on (%.1f)" % lamp.light_energy): return false
	var cam: Node3D = vm.get_parent()
	var at: Vector3 = cam.global_transform.affine_inverse() * vm._torch.global_position
	if not _ok(at.z < -0.2 and at.x > 0.0 and at.y < 0.0, "the lantern hangs ahead, right and low (%s)" % at): return false
	var lens: Transform3D = vm.torch_lens()
	var ahead := -cam.global_basis.z
	if not _ok((-lens.basis.z).dot(Vector3(ahead.x, 0.0, ahead.z).normalized()) > 0.7, "its beam goes ahead"): return false
	gs.request_select_gun(1)
	await _wait(1.5)
	if not _ok(not p.torch and p.gun == 1 and not vm.torch and lamp.lit == 0.0, "1: the pistol back, the flashlight away, its light off"): return false
	gs.request_toggle_torch()
	await _wait(1.5)
	return _ok(p.torch and p.gun == 0 and lamp.lit == 1.0, "F again: out again, the pistol away")


func _steps() -> bool:
	for seed in 200:
		var steps: Array = LAMP.blackout_steps(seed)
		var dark: Vector2 = LAMP.dark_span(steps)
		var n: float = LAMP.flicker_length(steps)
		if dark.y < LAMP.BLACKOUT.x or dark.y > LAMP.BLACKOUT.y or LAMP.flicker_level(steps, dark.x + dark.y * 0.5) != 0.0 \
				or n > dark.x + dark.y + 2.0 or dark.x < 0.3 or LAMP.flicker_level(steps, n + 0.01) != 1.0:
			return _ok(false, "blackout %d: dark %s of %.2f s" % [seed, dark, n])
	return _ok(true, "200 blackouts: a stutter, %.1f-%.1f s of dark, back on" % [LAMP.BLACKOUT.x, LAMP.BLACKOUT.y])


func _blackout() -> bool:
	var rolls: Node = gs.lamp_flicker_rolls
	var me: int = gs.local_peer()
	var player: CharacterBody3D = main.get_node("Player")
	var lamp: SpotLight3D = player.get(&"_lamp")
	gs.hour = 0.0
	var wood := Vector3(60.0, 0.0, 0.0)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(wood + Vector3.UP * 80.0, wood + Vector3.DOWN * 50.0, 1))
	wood.y = hit.position.y if not hit.is_empty() else 0.0
	player.global_position = Vector3(8.0, 0.1, 0.0)
	await _wait(0.4)
	if not _ok(not rolls.in_wood(me), "in the middle of the clearing: not the wood"): return false
	player.global_position = wood + Vector3.UP * 0.1
	player._yaw = 0.0
	player._pitch = 0.0
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await _wait(0.5)
	if not _ok(rolls.in_wood(me), "%.0f m out of the clearing: in the wood" % rolls.FOREST.out_of_clearing(gs.player().pos)): return false
	gs.request_toggle_torch()
	if not _ok(not rolls.try_blackout(me), "the flashlight away: no blackout"): return false
	gs.request_toggle_torch()
	await _wait(0.3)
	var waves: Node = main.get_node("Waves")
	var before: Array = waves._zombies.keys()
	if not _ok(rolls.try_blackout(me, 1) and not rolls.try_blackout(me, 1), "it dies; at once again it doesn't (BLACKOUT_GAP)"): return false
	var steps: Array = LAMP.blackout_steps(0)  # (the seed is the host's; only its timing is needed here)
	var t0 := Time.get_ticks_msec()
	var went_dark := false
	var met := false
	while Time.get_ticks_msec() - t0 < 8000:
		await process_frame
		if lamp.blacked_out() and lamp.light_energy == 0.0:
			went_dark = true
		if went_dark and not lamp.flickering():
			break
	var new: Array = waves._zombies.keys().filter(func(id: int) -> bool: return not id in before)
	if not _ok(went_dark and not lamp.flickering() and lamp.lit == 1.0, "our light died, stayed out, came back"): return false
	if new.size() == 1:
		var z: Node3D = waves._zombies[new[0]].node
		var off := z.global_position - player.global_position
		var ahead := Vector3(-sin(player._yaw), 0.0, -cos(player._yaw))
		met = Vector2(off.x, off.z).length() < 4.0 and Vector3(off.x, 0.0, off.z).normalized().dot(ahead) > 0.5
		print("    it stands %.1f m off, %s" % [Vector2(off.x, off.z).length(), off])
	if not _ok(met, "with the light back, a walker stands right in front"): return false
	rolls.now += rolls.BLACKOUT_GAP + 1.0
	if not _ok(rolls.try_blackout(me, 0), "after BLACKOUT_GAP: again, nothing this time"): return false
	rolls.now += rolls.BLACKOUT_GAP + 1.0
	if not _ok(not rolls.try_blackout(me, 0), "a third the same night: no (BLACKOUT_NIGHT %d)" % rolls.BLACKOUT_NIGHT): return false
	var n := 0
	for i in 400:  # the rolls' own dice, in the wood, the night counts let go
		gs.nights = 500 + i
		rolls.now += rolls.BLACKOUT_GAP + 1.0
		rolls._dark_until.clear()
		if randf() < rolls.CHANCE_BLACKOUT * 150.0 and rolls.try_blackout(me):
			n += 1
	var with: int = rolls.blackouts.slice(-n).filter(func(b: Array) -> bool: return b[2]).size()
	return _ok(n > 300 and with > n * 0.3 and with < n * 0.7, "%d blackouts more: %d with something there (CREATURE_CHANCE %.1f)" % [n, with, rolls.CREATURE_CHANCE])


func _remote() -> bool:
	var holder := Node3D.new()  # a remote body: remote_players.gd Character has `peer`
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar peer := 7\n"
	script.reload()
	holder.set_script(script)
	main.add_child(holder)
	var theirs: SpotLight3D = LAMP.new()
	holder.add_child(theirs)
	await process_frame
	if not _ok(not theirs.held, "peer 7's flashlight: away"): return false
	gs._event(&"torch_changed", [7, true])
	await _wait(0.3)
	if not _ok(gs.player(7).torch and theirs.held and theirs.lit == 1.0, "off the wire: peer 7's out, its light on here"): return false
	gs._event(&"torch_blackout", [7, 99, false])
	await _wait(1.5)
	return _ok(theirs.blacked_out(), "off the wire: peer 7's dies here too")
