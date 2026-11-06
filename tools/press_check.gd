extends SceneTree
## Headless check for the round press on the workshop bench's stand in the open ground's house
## (tools/build_world.gd, scripts/press.gd):
##   Godot.exe --headless --path . -s res://tools/press_check.gd
## Before its quest it is neither seen nor in the way, even once the bench it stands on has come;
## once the quest opening `hand_press` is done it drops in, lands where it was built, solid again.

var _failed := false
var _gs: Node


func _initialize() -> void:
	_gs = root.get_node("GameState")
	var world: Node = load("res://scenes/world.tscn").instantiate()  # the old hall (arena.tscn) is gone
	root.add_child(world)
	await process_frame
	var press: StaticBody3D = get_first_node_in_group("press")
	_ok(press != null, "the press is in the house")
	if press == null:
		quit(1)
		return
	var bench := press.get_parent() as Node3D
	_ok(bench.is_in_group("workbench"), "it stands on the bench")
	var built := press.position
	_ok(not press.visible and press.collision_layer == 0, "hidden before anything opens")

	await _open("workbench")
	_ok(bench.visible and (bench as StaticBody3D).collision_layer != 0, "the bench comes")
	_ok(not press.visible and press.collision_layer == 0, "the press still out with the bench there")

	await _open("hand_press")
	_ok(press.is_visible_in_tree(), "there once its quest is done")
	_ok(press.position.distance_to(built) < 0.001, "landed where it was built")
	_ok(press.collision_layer != 0, "solid again")
	_ok(press.find_child("Handle", true, false) != null, "the feed handle is a part of its own")
	print("press_check: ", "FAILED" if _failed else "ok")
	quit(1 if _failed else 0)


## Marks the quest that opens `what` done, then waits out the drop (reveal.gd).
func _open(what: String) -> void:
	var id: String = _gs.QUESTS.keys().filter(func(q: String) -> bool: return _gs.QUESTS[q].get("unlock") == what)[0]
	_gs.quests_done.append(id)
	_gs.quest_done.emit(id, 0)
	await create_timer(1.5).timeout


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_failed = true
		print("FAIL: ", what)
