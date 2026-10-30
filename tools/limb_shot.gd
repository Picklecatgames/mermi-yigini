extends SceneTree
## Off-screen shots of limbs coming off (scripts/zombie_body.gd cut()): a zombie under a lamp in the
## hall, seen from the railing side. A round through its forearm tears it off (frames through the
## throw), then one through its shin drops it (frames through the fall), it crawls and bites from
## the floor; close-ups of the stumps and the pieces on the floor last. A runner losing a leg after.
## Saves user://limb_<tag>_<n>.png.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/limb_shot.gd -- --tag=x

const BODY := preload("res://scripts/zombie_body.gd")
const AT := Vector3(20.0, 0.0, 0.0)

var _tag := "now"
var _cam: Camera3D


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	main.add_child(_cam)
	_cam.make_current()
	await _walker(main)
	await _runner(main)
	quit()


func _walker(main: Node) -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	holder.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), AT)  # faces -X, the railing
	var body: Node3D = BODY.new()
	body.setup(&"walker", 5)
	body.model = &"prisoner"
	holder.add_child(body)
	_cam.look_at_from_position(AT + Vector3(-3.2, 1.5, 1.6), AT + Vector3(0, 0.9, 0))
	await create_timer(1.0).timeout
	await _through(body, &"forearm_l")
	var was := 0.0
	for t: float in [0.05, 0.2, 0.45, 1.2]:  # s after the hit
		await create_timer(t - was).timeout
		was = t
		await _save("arm_%.2f" % t)
	await create_timer(1.0).timeout
	var fall: float = await _through(body, &"shin_r")
	for k in 4:
		await create_timer(fall / 4.0).timeout
		await _save("fall_%d" % k)
	body.move(0.6)
	await create_timer(1.0).timeout
	await _save("crawl")
	body.attack()
	await create_timer(0.8).timeout
	await _save("bite")
	await create_timer(2.0).timeout
	_cam.look_at_from_position(AT + Vector3(-1.4, 0.8, 1.2), AT + Vector3(0.0, 0.25, 0.0))
	await _save("stumps")
	_cam.look_at_from_position(AT + Vector3(-1.5, 2.6, 0.0), AT + Vector3(-0.5, 0.0, 0.0))
	await _save("floor")
	holder.queue_free()


func _runner(main: Node) -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	holder.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), AT)
	var body: Node3D = BODY.new()
	body.setup(&"runner", 2)
	holder.add_child(body)
	_cam.look_at_from_position(AT + Vector3(-3.2, 1.5, 1.6), AT + Vector3(0, 0.9, 0))
	body.move(3.0)
	await create_timer(1.0).timeout
	var fall: float = await _through(body, &"leg_l")
	await create_timer(fall + 0.6).timeout
	body.move(1.35)
	await create_timer(0.4).timeout
	await _save("runner_crawl")
	holder.queue_free()


## A round from the camera's side through the middle of `part`, and the cut the host would send.
func _through(body: Node3D, part: StringName) -> float:
	var a: Vector3 = body.call("_bone_at", BODY.LIMBS[part][0])
	var b: Vector3 = body.call("_bone_at", BODY.LIMBS[part][1])
	var mid := (a + b) / 2.0
	var dir := (mid - _cam.global_position).normalized()
	var found: StringName = body.wound(mid - dir * 0.05, dir, false)
	print("%s: the round found %s" % [part, found])
	return body.cut(part)


func _save(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("user://limb_%s_%s.png" % [_tag, name])
