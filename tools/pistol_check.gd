extends SceneTree
## Headless check of the starting pistol (2026-10-30): the desk shows it taped; taken, it is the
## first gun, in hand on the Deagle's clips with every part on the gun at Idle, its magazine out
## and back in a reload, its own shot sound. The bench's wooden grips swap the frame and trigger
## and take recoil off; the Deagle stays shut until bought there.
##   Godot.exe --headless --path . -s res://tools/pistol_check.gd

const ON_GUN := 0.002  # m a part may sit off where the gun bone puts it

var _fail := false


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	await process_frame
	var me: CharacterBody3D = main.get_node("Player")
	var vm: Node3D = me._viewmodel
	var table: Node3D = get_first_node_in_group("gun_table")
	var on_table: Array = table._gun.get_children().map(func(m: MeshInstance3D) -> Mesh: return m.mesh)
	_ok(on_table.size() == 5 and on_table.all(func(m: Mesh) -> bool: return m != null), "the desk shows the pistol's five parts")
	_ok(gs.GUNS[1].id == "pistol" and gs.GUNS[2].id == "deagle", "the pistol first, the Deagle after it")
	gs.request_take_pistol()
	_ok(gs.player().gun == 1, "taken off the desk, the pistol is drawn")
	gs.request_select_gun(2)
	_ok(gs.player().gun == 1, "the Deagle stays shut until it is bought")
	if not await _until(func() -> bool: return vm.gun == 1 and vm.clip == "", 6.0):
		_ok(false, "the pistol drawn and at rest (%d, %s)" % [vm.gun, vm.clip])
	var skel: Skeleton3D = vm._skel
	var gun: Node3D = skel.get_node("ServicePistol")
	_ok(gun.visible and not (skel.get_node("Deagle") as Node3D).visible, "its parts show, the Deagle's mesh doesn't")
	_ok(gun.get_node("frame_tape").visible and not gun.get_node("frame_wood").visible, "taped")
	var weapon := func() -> Transform3D: return skel.global_transform * skel.get_bone_global_pose(skel.find_bone("Weapon"))
	var off := func(part: String) -> float:
		var mi: MeshInstance3D = gun.get_node("%s/%s" % [part, part])
		return mi.global_position.distance_to(weapon.call().origin) / skel.global_transform.basis.get_scale().x
	for part: String in ["frame_tape", "trigger_tape", "slide", "hammer", "magazine"]:
		_ok(off.call(part) < ON_GUN, "at Idle the %s sits on the gun (%.1f mm off)" % [part, off.call(part) * 1000.0])
	_ok(vm._shot_sound.stream == vm.SETS.pistol.shot, "its own shot sound")
	# A reload from empty: the magazine leaves the grip, and one is back in it at the end.
	gs.player().carried = 5
	gs.player().loaded = 0
	vm.reload()
	var farthest := 0.0
	await process_frame
	while vm.clip != "":
		farthest = maxf(farthest, off.call("magazine"))
		await process_frame
	_ok(farthest > 0.05, "the reload takes the magazine out (%.0f mm)" % (farthest * 1000.0))
	var home := minf(off.call("magazine"), off.call("magazine_2"))
	_ok(home < ON_GUN, "and a magazine is back in the grip (%.1f mm off)" % (home * 1000.0))
	_ok(gs.loaded > 0, "loaded")
	# The bench's wooden grips: the pistol's tab has the magazine and them; bought, the gun turns
	# round with them on, here and in hand.
	var kick: float = vm._held()
	gs.quests_done.append("t00")  # it opens the bench
	gs.player().gold = 1000
	var bench: CanvasLayer = me.get_node("BenchMenu")
	bench.visible = true
	bench._pick("pistol")
	_ok(bench._parts_of("pistol") == ["magazine", "grip"] and bench._cards.grip.card.visible and not bench._cards.laser.card.visible,
		"the pistol on the bench: magazine and grips")
	var on_bench: Node3D = bench._skel.get_node("ServicePistol")
	_ok(on_bench.visible and on_bench.get_node("frame_tape").visible, "it lies there taped")
	bench._buy("grip")
	_ok(gs.upgrade_value("grip") == 1 and gs.player().gold == 1000 - gs.UPGRADES.grip.costs[0], "the grips bought")
	await create_timer(1.0).timeout
	_ok(on_bench.get_node("frame_wood").visible and not on_bench.get_node("frame_tape").visible and not bench._busy, "turned round with them on")
	_ok(gun.get_node("frame_wood").visible and gun.get_node("trigger_wood").visible and not gun.get_node("frame_tape").visible, "the wooden grips on in hand")
	_ok(vm._held() < kick, "they take recoil off (%.2f)" % vm._held())
	bench._pick("deagle")
	_ok(bench._parts_of("deagle") == ["deagle"], "the Deagle's tab sells the gun first")
	bench._buy("deagle")
	_ok(bench._parts_of("deagle") == ["magazine", "laser"], "then its parts")
	bench.visible = false
	gs.request_select_gun(2)
	_ok(gs.player().gun == 2, "bought, the Deagle can be drawn")
	if await _until(func() -> bool: return vm.gun == 2, 6.0):
		_ok(not gun.visible and vm._held() == 1.0, "the Deagle in hand: the pistol hides, its grips do nothing")
	print("pistol_check ", "FAILED" if _fail else "OK")
	quit(1 if _fail else 0)


func _until(cond: Callable, secs: float) -> bool:
	var end := Time.get_ticks_msec() + secs * 1000.0
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await process_frame
	return true


func _ok(cond: bool, what: String) -> void:
	print("ok   " if cond else "FAIL ", what)
	_fail = _fail or not cond
