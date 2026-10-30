extends SceneTree
## Off-screen shots of the blood (scripts/blood_fx.gd): a zombie in the hall, shot from the railing the
## way a player sees it (single hits, frames through the puff, then the head blown off), in two
## spots: under a lamp and in the dark between them. Close-ups after. Saves user://blood_<tag>_<n>.png.
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/blood_shot.gd -- --tag=x

const BODY := preload("res://scripts/zombie_body.gd")
const SPOTS := {"lit": Vector3(20.0, 0.0, 0.0), "dark": Vector3(22.0, 0.0, 9.0), "wall": Vector3(26.5, 0.0, 17.0)}
const PUFF := [0.04, 0.15, 0.35, 0.6]  # s after the hit

var _tag := "now"


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	var cam := Camera3D.new()
	cam.fov = 75.0
	main.add_child(cam)
	cam.make_current()
	for spot: String in SPOTS:
		var at: Vector3 = SPOTS[spot]
		var holder := Node3D.new()
		main.add_child(holder)
		holder.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), at)  # faces -X, the railing
		var body: Node3D = BODY.new()
		body.setup(&"walker", 5)
		holder.add_child(body)
		var eye := Vector3(14.5, 1.6, at.z - 0.6)  # a player at the railing
		var dir := (at + Vector3(0, 1.2, 0) - eye).normalized()
		cam.look_at_from_position(eye + dir * (at.x - 14.5 - 4.0), at + Vector3(0, 1.1, 0))  # 4 m off
		await create_timer(1.0).timeout
		body.wound(at + Vector3(-0.15, 1.25, 0.0), dir, false)
		var t := 0.0
		for i in PUFF.size():
			await create_timer(PUFF[i] - t).timeout
			t = PUFF[i]
			await _save("%s_hit%d" % [spot, i])
		await create_timer(1.0).timeout
		body.wound(at + Vector3(-0.08, body.height - 0.15, 0.0), dir, true)
		body.die(&"head")
		await create_timer(0.15).timeout
		await _save("%s_burst" % spot)
		await create_timer(4.0).timeout
		await _save("%s_after" % spot)
		cam.look_at_from_position(at + Vector3(-1.6, 1.0, 1.2), at + Vector3(0.4, 0.2, 0.0))
		await _save("%s_floor" % spot)
		holder.queue_free()
	quit()


func _save(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("user://blood_%s_%s.png" % [_tag, name])
