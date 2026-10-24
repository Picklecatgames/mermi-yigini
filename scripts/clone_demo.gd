extends Node3D
## Stand-alone preview of the Clone blueprint opening on the workshop bench, to get it right before
## it goes into the game. Two takes: 1 is clone_fx.gd, 2 is clone_fx_drop.gd (1 is the default; `-- 2`
## on the command line starts on the second). Space or a click plays it again.

const BENCH := 1.2  # as range_dressing.gd _workshop scales it
const TOP := 0.98 * BENCH  # the top, glb y 0.98
const PAPER := 0.011  # m, the blueprints lying there stand up to this off the top (Paper_blue_01, measured)
const TAKES := [preload("res://scripts/clone_fx.gd"), preload("res://scripts/clone_fx_drop.gd")]

var _fx: Node3D


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.34, 0.33)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.9, 0.5, 0.0)
	key.light_energy = 1.4
	key.shadow_enabled = true
	add_child(key)
	var lamp := OmniLight3D.new()  # a work lamp over the top
	lamp.position = Vector3(-0.1, TOP + 0.7, 0.3)
	lamp.light_color = Color(1.0, 0.9, 0.75)
	lamp.light_energy = 1.2
	lamp.omni_range = 3.0
	lamp.shadow_enabled = true
	add_child(lamp)

	var bench := StaticBody3D.new()
	bench.add_child(load("res://assets/props/workbench/workbench.glb").instantiate())
	bench.scale = Vector3.ONE * BENCH
	bench.set_script(preload("res://scripts/bench_top.gd"))  # clears the top, as in the game
	add_child(bench)

	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	var at := Vector3(-0.09 * BENCH, TOP, 0.05)
	cam.look_at_from_position(at + Vector3(0.0, 0.2, 0.5), at + Vector3(0.0, 0.09, 0.0))
	_take(1 if "2" in OS.get_cmdline_user_args() else 0)


func _take(i: int) -> void:
	if _fx:
		_fx.free()
	_fx = TAKES[i].new()
	_fx.position = Vector3(-0.09 * BENCH, TOP + PAPER, 0.05)
	add_child(_fx)
	_fx.play.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_1, KEY_2]:
		_take(event.keycode - KEY_1)
	elif event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and event.pressed):
		_fx.play()
