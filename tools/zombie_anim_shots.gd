extends SceneTree
## Frame strips of the zombies' gaits and swings (2026-11-05, the user: their walks and attacks were
## broken and not threatening), on a checkered floor so a foot sliding shows, as PNG contact sheets:
##   Godot.exe --path . --fixed-fps 60 --position -10000,-10000 --resolution 1280x720 -s res://tools/zombie_anim_shots.gd -- --tag=T
## user://zombi_<tag>_<kind>_<strip>.png, each a row of frames left to right:
## - stalk: walking up at its stalking pace in its walk clips (waves.gd STALK, _moving)
## - run: running at its pace
## - attack: the swing as now played (zombie_body.gd ATTACKS): start, wind-up, the blow, after
## - attack_old: the whole clip as before, the frame where the blow used to land (half the clip)
##   beside the frame where the hands really strike
## The body is moved along the floor at the pace given, as waves.gd moves it; the camera follows.

const BODY := preload("res://scripts/zombie_body.gd")
const KINDS := [[&"walker", &"fleshzombie"], [&"walker", &"prisoner"], [&"brute", &"warrok"]]
const FRAME := Vector2i(320, 400)

var tag := "anim"
var stage: Node3D
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	stage = Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.35)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	floor.mesh.size = Vector2(80, 80)
	var mat := StandardMaterial3D.new()
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, Color(0.75, 0.75, 0.72) if ((x / 8) + (y / 8)) % 2 == 0 else Color(0.35, 0.35, 0.33))
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(40, 40, 1)  # 0.5 m squares
	floor.material_override = mat
	stage.add_child(floor)
	cam = Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	cam.current = true
	for k: Array in KINDS:
		await _kind(k[0], k[1])
	quit()


func _kind(kind: StringName, model: StringName) -> void:
	var body: Node3D = BODY.new()
	body.setup(kind, 11)
	body.model = model
	stage.add_child(body)
	body.position = Vector3.ZERO
	body.rotation.y = -PI / 2  # walking along +x
	await _frames(3)
	var name := "%s_%s" % [kind, model]
	var walk: Vector2 = body.gait_span("walk")
	var stalk: float = clampf(2.7 * 0.45, walk.x, walk.y * 0.95) if walk.y > 0.0 else 1.2
	body.move(stalk, "walk")
	await _travel(body, stalk, 0.6)
	await _strip(body, stalk, name + "_stalk", [0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	var run := 2.7 if kind == &"walker" else 2.6
	body.move(run)
	await _travel(body, run, 0.6)
	await _strip(body, run, name + "_run", [0.0, 0.08, 0.16, 0.24, 0.32, 0.4])
	body.idle()
	await _travel(body, 0.0, 0.5)
	var whole: float = body.attack()
	var strike: float = body.strike
	await _strip(body, 0.0, name + "_attack", [0.0, strike * 0.35, strike * 0.7, strike, strike + 0.15, whole - 0.05])
	await _travel(body, 0.0, whole + 0.3)
	# As before: the whole clip from its start; the blow used to land at half its length.
	var ap: AnimationPlayer = body.get("_ap")
	body.set("_busy", true)
	var picked := ""
	for c: String in ap.get_animation_list():
		if c.contains("attack") and BODY.ATTACKS.has(c) and (kind == &"brute") == c.begins_with("mutant_"):
			picked = c
			break
	if picked != "":
		ap.play(picked, 0.0)
		ap.speed_scale = 1.0
		var length := ap.get_animation(picked).length
		var real_strike: float = BODY.ATTACKS[picked][1]
		await _strip(body, 0.0, name + "_attack_old", [0.0, length * 0.5, real_strike], true)
	body.queue_free()
	await _frames(2)


## Moves `body` along +x at `v` m/s for `secs` s, the camera following.
func _travel(body: Node3D, v: float, secs: float) -> void:
	var t := 0.0
	while t < secs:
		await process_frame
		var dt := 1.0 / 60.0
		t += dt
		body.position.x += v * dt
		_aim(body)


func _aim(body: Node3D) -> void:
	cam.position = body.position + Vector3(0.6, 1.3, 4.2)
	cam.look_at(body.position + Vector3(0.3, 0.95, 0.0))


## One picture per time in `at` (s from now), side by side, saved as zombi_<tag>_<name>.png.
## `seek`: the times are into the clip as it plays from its start (paused at each).
func _strip(body: Node3D, v: float, name: String, at: Array, seek := false) -> void:
	var sheet := Image.create(FRAME.x * at.size(), FRAME.y, false, Image.FORMAT_RGBA8)
	var ap: AnimationPlayer = body.get("_ap")
	var now := 0.0
	for i in at.size():
		var when: float = at[i]
		if seek:
			ap.seek(when, true)
			ap.pause()
			_aim(body)
			await _frames(2)
		else:
			await _travel(body, v, maxf(0.0, when - now))
			now = when
			await RenderingServer.frame_post_draw
		var shot := root.get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		var size := shot.get_size()
		var w := size.y * FRAME.x / FRAME.y
		var crop := Rect2i((size.x - w) / 2, 0, w, size.y)
		var part := shot.get_region(crop)
		part.resize(FRAME.x, FRAME.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(part, Rect2i(Vector2i.ZERO, FRAME), Vector2i(FRAME.x * i, 0))
	if seek:
		ap.play()
	var path := "user://zombi_%s_%s.png" % [tag, name]
	sheet.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(n: int) -> void:
	for i in n:
		await process_frame
