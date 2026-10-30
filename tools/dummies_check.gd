extends SceneTree
## Headless check for the gear targets of 2026-10-22 (varil, korkuluk, zırhlı, sarkaç, çift gong,
## altın kukla, sekme plakası): what each pays and how it reacts.
##   Godot.exe --headless --path . -s res://tools/dummies_check.gd

var gs: Node
var main: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	var put := func(scene: String, z: float) -> Node3D:
		var n: Node3D = load(scene).instantiate()
		n.position = Vector3(20, 0, z)
		n.rotation.y = -PI / 2  # faces the firing line, as placement turns them
		main.add_child(n)
		return n
	var twin: Node3D = put.call("res://scenes/twin_gong.tscn", 16.0)
	var pend: Node3D = put.call("res://scenes/pendulum.tscn", 9.0)
	var armored: Node3D = put.call("res://scenes/armored_dummy.tscn", 4.0)
	var crow: Node3D = put.call("res://scenes/scarecrow.tscn", -4.0)
	var barrel: Node3D = put.call("res://scenes/barrel_target.tscn", -9.0)
	put.call("res://scenes/dummy.tscn", -11.0)  # the barrel's neighbour
	var gold: Node3D = put.call("res://scenes/gold_dummy.tscn", -17.5)
	var bank: Node3D = put.call("res://scenes/ricochet_plate.tscn", -22.0)
	for i in 3:
		await physics_frame
	gs.request_take_pistol()  # off the desk at the spawn: drawn at once
	gs.infinite_ammo = true
	gs.player().loaded = 1
	gs.player().levels["combo_cap"] = 4  # x20

	# Varil: its own 5 and the dummy 2 m away; then it is gone.
	assert(_shot(barrel.global_position + Vector3(0, 0.5, 0)) == 6, "barrel: 5 + the dummy's 1")
	assert(barrel.is_down(), "barrel: blown up")
	assert(_shot(barrel.global_position + Vector3(0, 0.5, 0)) == 0, "barrel: nothing left to hit")
	barrel._process(barrel.BACK_AFTER + 0.1)
	await physics_frame
	assert(not barrel.is_down(), "barrel: back after a while")

	# Korkuluk: a hit lights it, it pays $1 a second for 5 s to whoever lit it.
	assert(_shot(crow.global_position + Vector3(0, 1.1, 0)) == 1, "scarecrow: a hit pays 1")
	assert(crow.is_burning(), "scarecrow: lit")
	var before: int = gs.player().gold
	for i in 6:
		crow._process(1.0)
	assert(gs.player().gold - before == 5, "scarecrow: 5 burning seconds, $5")
	assert(not crow.is_burning(), "scarecrow: burnt out")

	# Zırhlı: nine hits on the armour pay nothing, the tenth breaks it for 10 x chain 10.
	gs._process(gs.COMBO_WINDOW + 0.1)
	var chest: Vector3 = armored.global_position + Vector3(0, 1.1, 0)
	for i in 9:
		assert(_shot(chest, false) == 0, "armour hit %d pays nothing" % (i + 1))
	assert(_shot(chest, false) == 100, "the breaking hit pays 10 x10")
	assert(_shot(chest, false) == 11, "bare: a dummy's 1 x11")
	armored._process(armored.REGROW + 0.1)
	assert(_shot(chest) == 0, "armour back on")

	# Sarkaç: fastest through the bottom, slowest at the ends.
	pend._phase = 0.0
	pend._place()
	await physics_frame
	assert(_shot(pend._upper.global_transform * Vector3(0, 0.67, 0)) == 8, "pendulum: 8 at the bottom")
	pend._phase = PI / 2
	pend._place()
	await physics_frame
	assert(_shot(pend._upper.global_transform * Vector3(0, 0.67, 0)) == 2, "pendulum: 2 at the end")

	# Çift gong: both rung together, every hit of the pair pays x5 in all.
	gs._process(gs.COMBO_WINDOW + 0.1)
	before = gs.player().gold
	_shot(_plate_center(twin.get_node("Left")), false)
	_shot(_plate_center(twin.get_node("Right")), false)
	assert(gs.player().gold - before == (2 + 4) * 5, "twin gong: (2 + 2x2) x5")

	# Altın kukla: nothing to hit until it comes up, then 10 a hit.
	assert(_shot(gold.global_position + Vector3(0, 1.1, 0)) == 0, "gold dummy: down, nothing to hit")
	gs.cue_target(gold, [&"up", 6.0])
	await physics_frame
	assert(_shot(gold.global_position + Vector3(0, 1.1, 0)) == 10, "gold dummy: up, 10")

	# Sekme plakası: the plate throws the round onto the hidden popper, x3.
	var plate: Node3D = bank.get_node("Plate")
	var paid: int = _shot(plate.global_position + Vector3(0, -0.1, 0))
	assert(paid == 9 or paid == 18, "ricochet: popper body 3 x3 or head 6 x3, got %d" % paid)
	print("dummies_check: ok")
	quit()


## Fires from 11 m in front (−X) at `point`; returns what it paid. `fresh`: the chain starts over.
func _shot(point: Vector3, fresh := true) -> int:
	if fresh:
		gs._process(gs.COMBO_WINDOW + 0.1)
	var start := point + Vector3(-11, 0.4, 0)  # a little above: level at 1.1 m the railing's top rail is in the way
	var before: int = gs.player().gold
	gs.player().cooldown = 0.0
	gs.request_fire(start, (point - start).normalized())
	return gs.player().gold - before


func _plate_center(gong: Node) -> Vector3:
	for m: MeshInstance3D in gong.find_children("*", "MeshInstance3D", true, false):
		if m.get_parent().has_method("_on_shot_landed") and m.get_parent().get("hit_gold") != null:
			return m.global_transform * m.get_aabb().get_center()
	return Vector3.ZERO
