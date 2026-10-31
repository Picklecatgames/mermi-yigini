extends SceneTree
## Off-screen contact sheet of every Mixamo zombie model with its head blown off (zombie_body.gd
## die(&"head")): what is left on the neck, seen from the front and a little above, 0.15 s after.
## --bare: only the head folded away (no blood, stump or fall), to see the skin left on the neck.
## --whole: the heads left on, to see what they wear.
## --old: without the skin hanging off the head moved onto it (zombie_body.gd _lose_head()), as before.
## Saves user://head_gib_<tag>.png (one tile per model, its name in the order of MODELS, then the
## creatures that lose their heads).
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/head_gib_shot.gd -- --tag=x

const BODY := preload("res://scripts/zombie_body.gd")
const AT := Vector3(20.0, 0.0, 0.0)
const TILE := Vector2i(320, 360)

var _tag := "now"
var _bare := false
var _old := false
var _whole := false


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
		_bare = _bare or a == "--bare"
		_old = _old or a == "--old"
		_whole = _whole or a == "--whole"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	var cam := Camera3D.new()
	cam.fov = 35.0
	main.add_child(cam)
	cam.make_current()
	var light := OmniLight3D.new()
	light.omni_range = 6.0
	light.light_energy = 2.0
	main.add_child(light)
	await process_frame
	var models: Array = BODY.MODELS.keys() + [&"melty", &"dog"]  # (the blob bursts whole)
	var cols := 5
	var sheet := Image.create(TILE.x * cols, TILE.y * ceili(models.size() / float(cols)), false, Image.FORMAT_RGBA8)
	for i in models.size():
		var holder := Node3D.new()
		main.add_child(holder)
		holder.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), AT)  # faces -X
		var body: Node3D = BODY.new()
		body.setup(&"walker", 3)
		body.model = models[i]
		holder.add_child(body)
		await create_timer(0.4).timeout
		var sk: Skeleton3D = body.get("_skel")
		var neck := sk.to_global(sk.get_bone_global_pose(sk.get_bone_parent(body.get("_flinch").head)).origin)
		var head := sk.to_global(sk.get_bone_global_pose(body.get("_flinch").head).origin)
		var ahead := Vector3(head.x - neck.x, 0.0, head.z - neck.z)  # a dog's head is out in front of its neck
		ahead = ahead.normalized() if ahead.length() > 0.1 * body.height else Vector3(-1, 0, 0)
		var side := ahead.cross(Vector3.UP) * -0.5
		var up := 0.35 if body.height > 1.0 else 0.8  # down onto a dog's back
		cam.look_at_from_position(neck + ahead * 1.1 + Vector3.UP * up + side, neck + Vector3(0, 0.05, 0))
		light.global_position = neck + Vector3(-0.8, 0.6, 0.3)
		if _whole:
			pass
		elif _bare:  # the head folded away and nothing else: no blood, no stump, no fall
			body.get("_flinch").head_gone = true
			if not _old:
				body.call("_lose_head")
		else:
			if _old:  # each mesh its own headless one: nothing moves onto the head
				for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
					BODY._headless[mi.mesh] = {"mesh": mi.mesh, "hat": null, "crown": 0.0}
			body.set("_last_dir", Vector3(1, 0, 0))
			body.die(&"head")
		await create_timer(0.15).timeout
		await process_frame
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var cut := img.get_region(Rect2i(640 - TILE.x / 2, 360 - TILE.y / 2, TILE.x, TILE.y))
		sheet.blit_rect(cut, Rect2i(Vector2i.ZERO, TILE), Vector2i((i % cols) * TILE.x, (i / cols) * TILE.y))
		print(i, " ", models[i])
		holder.queue_free()
		await process_frame
	sheet.save_png("user://head_gib_%s.png" % _tag)
	quit()
