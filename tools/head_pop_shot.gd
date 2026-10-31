extends SceneTree
## Off-screen contact sheet of heads blown off (zombie_body.gd die(&"head")): six zombies, each its
## own roll, each a column, seen from the shooter's side at 0, 0.15, 0.3 and 0.5 s after the kill;
## under them a head shot kill that keeps its head (die(&"", true)) at 0.3 s.
## Saves user://head_pop_<tag>.png.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/head_pop_shot.gd -- --tag=x

const BODY := preload("res://scripts/zombie_body.gd")
const AT := Vector3(20.0, 0.0, 0.0)
const LOOKS := [[&"prisoner", 3], [&"zombiegirl", 8], [&"copzombie", 5], [&"warzombie", 21], [&"whiteclown", 13], [&"romero", 34]]
const TIMES := [0.0, 0.15, 0.3, 0.5]
const TILE := Vector2i(384, 216)

var _tag := "now"


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	var cam := Camera3D.new()
	cam.fov = 50.0
	main.add_child(cam)
	cam.make_current()
	var light := OmniLight3D.new()
	light.omni_range = 8.0
	light.light_energy = 2.5
	main.add_child(light)
	await process_frame
	var rows := TIMES.size() + 1
	var sheet := Image.create(TILE.x * LOOKS.size(), TILE.y * rows, false, Image.FORMAT_RGBA8)
	for col in LOOKS.size():
		for pop in [true, false]:
			var holder := Node3D.new()
			main.add_child(holder)
			holder.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), AT)  # faces -X, toward us
			var body: Node3D = BODY.new()
			body.setup(&"walker", LOOKS[col][1])
			body.model = LOOKS[col][0]
			holder.add_child(body)
			await create_timer(0.5).timeout
			var sk: Skeleton3D = body.get("_skel")
			var head := sk.to_global(sk.get_bone_global_pose(body.get("_flinch").head).origin)
			var dir := Vector3(1, -0.05, 0.25 * (col - 2.5) / 2.5).normalized()
			cam.look_at_from_position(head + Vector3(-1.9, 0.25, -0.6), head + Vector3(0.3, -0.45, 0))
			light.global_position = head + Vector3(-1.2, 1.5, 0.5)
			await process_frame  # the camera in place before the first frame is taken
			body.wound(head - dir * 0.1, dir, true)
			var gib := &"head" if pop else &""
			if body.get_method_argument_count("die") > 1:
				body.die(gib, true, 1000 + col * 77, dir)
			else:  # before: die(gib) alone
				body.die(gib)
			var waited := 0.0
			for row in TIMES.size() if pop else 1:
				var t: float = TIMES[row] if pop else 0.3
				if t > waited:
					await create_timer(t - waited).timeout
					waited = t
				await process_frame
				var img := root.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				var view := img.get_size()
				img = img.get_region(Rect2i(view / 2 - view * 3 / 10, view * 3 / 5))  # the middle: the body and what flies off it
				img.resize(TILE.x, TILE.y)
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, (row if pop else TIMES.size()) * TILE.y))
			holder.queue_free()
			for n in main.get_children():  # the pieces and blood of this one go too
				if n.get_script() == BODY.GIBS or n.name == "BloodFx":
					n.queue_free()
			await create_timer(0.2).timeout
		print(col, " ", LOOKS[col][0])
	sheet.save_png("user://head_pop_%s.png" % _tag)
	quit()
