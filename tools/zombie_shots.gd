extends SceneTree
## The zombies off Sketchfab in a row on a plain floor, each frozen in the same moment of a clip,
## one picture per action (user://zombies_<action>.png):
##   Godot.exe --path . --position -10000,-10000 --resolution 1600x700 -s res://tools/zombie_shots.gd
## Models after `--` replace the row (default below).

const BODY := preload("res://scripts/zombie_body.gd")
const ROW := [[&"walker", &"hazmat"], [&"walker", &"bloater"], [&"walker", &"melty"], [&"dog", &"dog"],
		[&"blob", &"blob"]]
## action -> how far into its clip (0..1)
const ACTIONS := {"idle": 0.3, "move": 0.4, "attack": 0.45, "hit": 0.3, "scream": 0.4, "die": 1.0}


func _initialize() -> void:
	_run()


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.37, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	floor.mesh.size = Vector2(30, 30)
	stage.add_child(floor)
	var row: Array = ROW
	var names := Array(OS.get_cmdline_user_args())
	if not names.is_empty():
		row = row.filter(func(r: Array) -> bool: return String(r[1]) in names)
	var bodies: Array[Node3D] = []
	for i in row.size():
		var b: Node3D = BODY.new()
		b.kind = row[i][0]
		b.model = row[i][1]
		b.size = 1.0
		b.set("_move", BODY.KINDS[b.kind].move)  # what setup() would set, but with the model chosen
		b.position = Vector3((i - (row.size() - 1) / 2.0) * 1.3, 0, 0)
		b.rotation.y = deg_to_rad(180 - 35)  # they face -Z: turned to the camera, three-quarter
		stage.add_child(b)
		bodies.append(b)
	var cam := Camera3D.new()
	cam.fov = 40
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.4, 2.6 + row.size() * 0.55), Vector3(0, 0.8, 0))
	cam.make_current()
	await process_frame
	for action: String in ACTIONS:
		for b in bodies:
			var ap: AnimationPlayer = b.find_children("*", "AnimationPlayer", true, false)[0]
			b.set("_dead", false)
			b.set("_busy", false)
			match action:
				"idle": b.idle()
				"move": b.move(1.4 if b.kind != &"dog" else 4.0)
				"attack": b.attack()
				"hit": b.call("_one_shot", "hit")
				"scream": b.scream()
				"die": b.die()
			ap.advance(BODY.BLEND + 0.01)
			var anim := ap.get_animation(ap.current_animation)
			ap.seek(anim.length * ACTIONS[action] - 0.001, true)
		for d in stage.get_parent().find_children("*", "Decal", true, false):
			d.queue_free()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("user://zombies_%s.png" % action)
		print("saved ", action)
	quit()
