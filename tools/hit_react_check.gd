extends SceneTree
## Headless check of where-it-went-in reactions (scripts/zombie_hit_react.gd):
##   Godot.exe --headless --path . -s res://tools/hit_react_check.gd --quit-after 100000
## Twins (same seed, same clip, side by side) facing the railing; one is shot, the other not, and
## the shot one's bones are read against its twin's: a round in the left shoulder from the front
## pushes that shoulder back (along the round) and the far one barely; a head shot throws the head
## back; a Deagle round in the shin bends the knee and drops the hips; a UZI round moves less than a
## Deagle's. Everything is back where the twin is a second later, and two twins shot alike end alike.

const BODY := preload("res://scripts/zombie_body.gd")
const REACT := preload("res://scripts/zombie_hit_react.gd")
const DIR := Vector3(1, 0, 0)  # from the railing, into the hall
## What is read for a hit on a bone: the end it swings (its own joint doesn't move when it turns).
const PROBE := {"LeftArm": "LeftForeArm", "LeftLeg": "LeftFoot"}

var _fails := 0


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	for i in 3:
		await process_frame
	await _case(main, "LeftArm", "deagle", false, "the left shoulder goes back", 0.04)
	await _case(main, "Head", "deagle", true, "the head is thrown back", 0.05)
	await _case(main, "LeftLeg", "deagle", false, "the shin hit buckles the knee", 0.03)
	var uzi: float = await _case(main, "LeftArm", "uzi", false, "a UZI round moves it too", 0.01)
	var deagle: float = await _case(main, "LeftArm", "deagle", false, "", 0.0)
	_ok(uzi < deagle * 0.7, "a UZI round moves the shoulder less than a Deagle's (%.3f vs %.3f m)" % [uzi, deagle])
	await _same(main)
	print("hit_react_check OK" if _fails == 0 else "hit_react_check FAILED")
	quit(1 if _fails else 0)


func _pair(main: Node, z: float) -> Array:
	var out := []
	for dz in [0.0, 1.6]:
		var holder := Node3D.new()
		main.add_child(holder)
		holder.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(20.0, 0.0, z + dz))  # faces -X
		var body: Node3D = BODY.new()
		body.setup(&"walker", 41)
		body.model = &"prisoner"
		holder.add_child(body)
		var react: Node = REACT.new()
		react.setup(body.get("_skel"))
		var seen := {}  # bone -> where it was drawn last frame (the modified pose lasts only so long)
		react.modification_processed.connect(func() -> void:
			for bone in ["LeftArm", "LeftForeArm", "RightArm", "Head", "LeftLeg", "LeftFoot", "Hips", "Spine2", "RightFoot", "RightLeg"]:
				seen[bone] = body.call("_bone_at", bone))
		out.append([holder, body, react, seen])
	return out


## Shoots one twin at `bone` and returns how far (m, along the round) that bone went at most within
## 0.3 s, against the other twin; then both must agree again after a second.
func _case(main: Node, bone: String, gun: String, head: bool, what: String, need: float) -> float:
	var twins := _pair(main, -3.0)
	await create_timer(0.5).timeout
	var a: Node3D = twins[0][1]
	var b: Node3D = twins[1][1]
	var off := Vector3(0, 0, 1.6)
	var at: Vector3 = a.call("_bone_at", bone)
	if bone != "Head":
		at = at.lerp(a.call("_bone_at", {"LeftArm": "LeftForeArm", "LeftLeg": "LeftFoot"}[bone]), 0.3)
	var got: StringName = twins[0][2].hit(at, DIR, gun, head)
	var most := 0.0
	var dip := 0.0
	var other := 0.0
	var joint := 0.0  # the bone's own joint (a shoulder hit: the shoulder itself)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300:
		await process_frame
		var sa: Dictionary = twins[0][3]
		var sb: Dictionary = twins[1][3]
		if sa.is_empty() or sb.is_empty():
			continue
		var moved: Vector3 = sa[PROBE.get(bone, bone)] - (sb[PROBE.get(bone, bone)] - off)
		most = maxf(most, moved.dot(DIR))
		joint = maxf(joint, (sa[bone] - (sb[bone] - off)).dot(DIR))
		dip = maxf(dip, sb.Hips.y - sa.Hips.y)
		other = maxf(other, (sa.RightArm - (sb.RightArm - off)).dot(DIR))
	if what != "":
		_ok(most >= need, "%s: %s (put on %s) %.3f m along the round" % [what, bone, got, most])
	if bone == "LeftArm" and gun == "deagle" and what != "":
		_ok(joint >= 0.015, "the shoulder joint itself goes back (%.3f m)" % joint)
		_ok(other < joint, "the far shoulder goes back less, if at all (%.3f m)" % other)
	if bone == "LeftLeg":
		_ok(dip > 0.01, "the hips drop (%.3f m)" % dip)
	await create_timer(1.2).timeout
	var back: float = (twins[0][3][bone] - (twins[1][3][bone] - off)).length()
	_ok(back < 0.01, "%s %s: back with its twin a second later (%.4f m apart)" % [bone, gun, back])
	for t in twins:
		t[0].queue_free()
	return most


## Two twins shot alike are posed alike: nothing random in it.
func _same(main: Node) -> void:
	var twins := _pair(main, 4.0)
	await create_timer(0.5).timeout
	var off := Vector3(0, 0, 1.6)
	for t in twins:
		var body: Node3D = t[1]
		var o: Vector3 = Vector3.ZERO if t == twins[0] else off
		for bone in [["LeftArm", "LeftForeArm"], ["Spine1", "Spine2"], ["RightLeg", "RightFoot"]]:  # mid-bone: no ties
			var mid: Vector3 = twins[0][1].call("_bone_at", bone[0]).lerp(twins[0][1].call("_bone_at", bone[1]), 0.4)
			t[2].hit(mid + o, DIR, "deagle", false)
	var worst := 0.0
	for k in 10:
		await process_frame
		for bone in ["LeftArm", "Head", "RightFoot", "Hips"]:  # (as drawn)
			worst = maxf(worst, (twins[0][3][bone] - (twins[1][3][bone] - off)).length())
	_ok(worst < 0.002, "two twins shot alike stay alike (%.4f m)" % worst)


func _ok(cond: bool, what: String) -> bool:
	if not cond:
		_fails += 1
		print("FAIL: " + what)
	else:
		print("ok: " + what)
	return cond
