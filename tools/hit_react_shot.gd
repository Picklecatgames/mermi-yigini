extends SceneTree
## Off-screen strips of where-it-went-in reactions (scripts/zombie_hit_react.gd): a walker at the
## railing takes a Deagle round in the left shoulder, the head, the left shin, and a UZI burst in the
## chest; each strip is 0, 0.05, 0.1, 0.2 and 0.3 s after the round, seen from the side. The blood is
## left out so the pose reads. Saves user://hit_react_<tag>_<case>.png.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/hit_react_shot.gd -- --tag=x

const BODY := preload("res://scripts/zombie_body.gd")
const REACT := preload("res://scripts/zombie_hit_react.gd")
const AT := Vector3(20.0, 0.0, 0.0)
const DIR := Vector3(1, 0, 0)
const TIMES := [0.0, 0.05, 0.1, 0.2, 0.3]

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
	_cam.fov = 40.0
	main.add_child(_cam)
	_cam.make_current()
	_cam.look_at_from_position(AT + Vector3(-1.2, 1.2, 3.4), AT + Vector3(0, 0.95, 0))
	await process_frame
	await _case(main, "shoulder", "LeftArm", "deagle", false, 1)
	await _case(main, "head", "Head", "deagle", true, 1)
	await _case(main, "shin", "LeftLeg", "deagle", false, 1)
	await _case(main, "uzi_chest", "Spine2", "uzi", false, 4)
	quit()


func _case(main: Node, name: String, bone: String, gun: String, head: bool, rounds: int) -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	holder.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), AT)  # faces -X, the railing
	var body: Node3D = BODY.new()
	body.setup(&"walker", 41)
	body.model = &"prisoner"
	holder.add_child(body)
	var react: Node = REACT.new()
	react.setup(body.get("_skel"))
	await create_timer(0.8).timeout
	var strip: Image
	var t0 := 0.0
	var shot := 0
	var at: Vector3 = body.call("_bone_at", bone)
	if bone == "LeftArm":
		at = at.lerp(body.call("_bone_at", "LeftForeArm"), 0.15)
	elif bone == "LeftLeg":
		at = at.lerp(body.call("_bone_at", "LeftFoot"), 0.3)
	at += Vector3(-0.1, 0, 0)  # on its front
	var start := Time.get_ticks_msec()
	react.hit(at, DIR, gun, head)
	shot = 1
	for i in TIMES.size():
		while Time.get_ticks_msec() - start < TIMES[i] * 1000.0:
			if shot < rounds and Time.get_ticks_msec() - start >= shot * 125:  # the UZI's interval
				react.hit(body.call("_bone_at", bone) + Vector3(-0.1, 0.05 * shot, 0.04 * shot), DIR, gun, head)
				shot += 1
			await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		var cut := img.get_region(Rect2i(400, 0, 480, 720))
		if not strip:
			strip = Image.create(480 * TIMES.size(), 720, false, cut.get_format())
		strip.blit_rect(cut, Rect2i(0, 0, 480, 720), Vector2i(480 * i, 0))
	strip.save_png("user://hit_react_%s_%s.png" % [_tag, name])
	holder.queue_free()
	await process_frame
