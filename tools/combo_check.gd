extends SceneTree
## Headless check for weak spot and combo payouts, on a zombie standing past the railing
## (scripts/waves.gd; added straight, so it has no life to lose and takes every round):
##   Godot.exe --headless --path . -s res://tools/combo_check.gd

const AT := Vector3(20.0, 0.0, 1.375)  # halfway between two of the railing's posts
const SHOOT_X := 12.5  # behind the railing


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	var waves: Node = main.get_node("Waves")
	for i in 3:
		await physics_frame
	waves._add_zombie(901, &"walker", 7, "", AT, PI / 2, 1.0, AT.z, false)
	var z: Dictionary = waves._zombies[901]
	for i in 20:
		await process_frame
	await physics_frame
	# Where its head and chest are now: its idle sway moves them a little between shots.
	var part := func(head: bool) -> Vector3:
		z.body.catch_up()
		if head:
			var sk: Skeleton3D = z.body.get("_skel")
			return sk.global_transform * sk.get_bone_global_pose((z.head as BoneAttachment3D).bone_idx).origin
		return z.body.call("_bone_at", "Spine2")
	gs.quest_board.fill("")  # no quests: a finished one's gold reward would land in the totals
	assert(not gs.request_fire(Vector3.ZERO, Vector3.FORWARD), "bare fists fire nothing")
	gs.request_take_pistol()  # off the desk at the spawn: drawn at once
	assert(gs.player().gun == 1, "number key 1 draws the first gun")
	gs.infinite_ammo = true
	gs.player().loaded = 1
	gs.player().levels["combo_cap"] = 4  # x20; the cap itself is checked further down
	# Straight down the range from `from_x` at the head or the chest; what it paid.
	var shot := func(head: bool, from_x := SHOOT_X) -> int:
		var to: Vector3 = part.call(head)
		var from := Vector3(from_x, to.y, to.z)
		var before: int = gs.player().gold
		gs.player().cooldown = 0.0
		gs.request_fire(from, (to - from).normalized())
		return gs.player().gold - before
	assert(shot.call(false) == 1, "first hit pays 1")
	assert(shot.call(false) == 2, "2nd body hit: chain x2")
	assert(shot.call(true) == 2, "a head starts its own chain: 1 x2 weak x1")
	assert(shot.call(false) == 3, "3rd body hit: chain x3, the head did not add to it")
	assert(shot.call(true) == 4, "2nd head: 1 x2 weak x2")
	assert(gs.player().combo == 3 and gs.player().weak_combo == 2, "two chains")
	gs._process(gs.COMBO_WINDOW + 0.1)  # let the window run out
	assert(gs.player().combo == 0, "a gap breaks the chain")
	assert(shot.call(false) == 1, "chain starts over")
	gs._process(gs.COMBO_WINDOW - 0.1)  # just inside the window
	assert(shot.call(false) == 2, "a hit just in time keeps it")
	gs.player().cooldown = 0.0
	gs.request_fire(Vector3(SHOOT_X, 8.0, AT.z), Vector3(1, 0, 0))  # over its head: a miss
	assert(gs.player().combo == 0, "a miss breaks the chain")
	# Out in the open a zombie pays from wherever we stand, past the old firing line too.
	var close := Vector3(AT.x - 3.0, 1.3, AT.z)
	assert(shot.call(false, close.x) > 0, "pays from past the old line")
	# The chain is the multiplier all the way to COMBO_MAX, then holds there.
	gs._process(gs.COMBO_WINDOW + 0.1)
	var got := 0
	for i in gs.COMBO_MAX + 3:
		got = shot.call(false)
		if i < gs.COMBO_MAX:
			assert(got == i + 1, "hit %d pays x%d" % [i + 1, i + 1])
	assert(got == gs.COMBO_MAX, "capped at x%d" % gs.COMBO_MAX)
	# Q upgrades: a fresh player's combo stops at x2, and +10% gold adds up.
	gs.player().levels["combo_cap"] = 0
	gs.player().levels["gold_bonus"] = 1
	gs.player().gold_rest = 0.0
	gs._process(gs.COMBO_WINDOW + 0.1)
	var total := 0
	for i in 10:
		total += shot.call(false)
	assert(gs.player().combo == 2, "combo capped at x2 before the upgrade")
	assert(total == 20, "1.1 + 9 x 2.2 = 20.9: whole dollars paid, the 0.9 carried")
	gs.player().levels["gold_bonus"] = 0
	# Range: +4%/m from 5 m behind the railing (clear of the heap) is +20%.
	gs.player().levels["range_bonus"] = 4
	gs.player().gold_rest = 0.0
	gs._process(gs.COMBO_WINDOW + 0.1)
	total = 0
	for i in 5:
		total += shot.call(false, gs.FIRING_LINE_X - 5.0)
	assert(total == 10, "1.2 + 4 x 2.4 = 10.8 from 5 m back")
	gs.player().levels["range_bonus"] = 0
	gs.player().levels["combo_cap"] = 4
	# Hand and magazine grow apart.
	gs.player().levels["carry"] = 4
	assert(gs.carry_capacity == 5 and gs.mag_capacity == 1, "carry and magazine are separate upgrades")
	gs.player().levels["carry"] = 0
	# Test mode (T) gives the gun back as it was.
	gs.infinite_ammo = false  # the test turned it on directly at the start
	gs.player().levels["magazine"] = 3  # room for more than the 2 rounds below
	gs.player().loaded = 2
	gs.request_toggle_infinite_ammo()
	gs.request_toggle_infinite_ammo()
	assert(gs.player().loaded == 2, "T on and off leaves no free rounds")
	var pl: CharacterBody3D = main.get_node("Player")
	# Moving costs accuracy, and stopping wins it back within a quarter second.
	var vm: Node3D = pl.get_node("ViewmodelView/SubViewport/Camera/Viewmodel")
	vm.set_process(false)
	var settle := func(v: Vector3, frames: int) -> float:
		for i in frames:
			pl.velocity = v
			vm._sway_and_bob(1.0 / 60.0)
		return vm.spread
	var still: float = settle.call(Vector3.ZERO, 60)
	var walking: float = settle.call(Vector3(5, 0, 0), 12)
	var stopped: float = settle.call(Vector3.ZERO, 15)
	print("spread still %.4f, walking %.4f, 0.25 s after stopping %.4f rad" % [still, walking, stopped])
	assert(pl.is_on_floor() and still < 0.004 and walking > 0.018 and stopped < walking * 0.3, "moving costs accuracy, stopping wins it back")
	vm.set_process(true)
	# Guns: each one up the order fires faster; an SMG's magazine is the upgrade times its own; a
	# round before the gun is ready again is refused; switching guns puts the magazine back in hand.
	for i in range(2, gs.GUNS.size()):
		assert(gs.GUNS[i].interval < gs.GUNS[i - 1].interval, "%s fires faster than %s" % [gs.GUNS[i].id, gs.GUNS[i - 1].id])
	gs.infinite_ammo = false
	gs.player().levels["magazine"] = 2
	gs.request_select_gun(3)
	assert(gs.player().gun == 3 and gs.mag_capacity == gs.upgrade_value("magazine") * gs.GUNS[3].mag, "the UZI's magazine")
	gs.player().carried = 10
	gs.request_reload()
	var in_mag: int = gs.loaded
	gs.player().cooldown = 0.0
	assert(gs.request_fire(close, Vector3(1, 0, 0)) and not gs.request_fire(close, Vector3(1, 0, 0)), "one round per interval")
	gs.request_select_gun(4)
	assert(gs.loaded == 0 and gs.carried == 10 - in_mag + in_mag - 1, "the UZI's rounds went back into the hand")
	print("combo_check OK")
	quit()
