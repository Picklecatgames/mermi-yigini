extends Node3D
## Stand-alone preview of the Electric round being built on the workshop bench
## (scripts/electric_fx.gd), to get it right before it goes into the game. The camera holds close
## on the round while it's assembled, pulls back to take in the Tesla coil for the charge and the
## strikes, and comes back in on the lit reactor. The room's lights go down for the charge
## (electric_fx.gd darkness) so the coil and the strikes light it, and each strike shakes the
## camera. Space or a click plays it again.

const FX := preload("res://scripts/electric_fx.gd")
const BENCH := 1.2  # the bench's scale (tools/build_world.gd BENCH_SCALE)
const TOP := 0.98 * BENCH  # the top, glb y 0.98
const PAPER := 0.011  # m, the blueprints lying there stand up to this off the top (Paper_blue_01, measured)
const AT := Vector3(-0.09 * BENCH, TOP + PAPER, 0.05)  # where the round is worked on

var _fx: Node3D
var _cam := Camera3D.new()
var _tesla: Node3D
var _env: Environment
var _lights := {}  # each room light and its own energy, dimmed by the fx's darkness
## A soft light from the camera's side on the round, on only while the room is dark: the room
## goes black, the round still reads (the user's call: it was lost in the dark).
var _fill := OmniLight3D.new()
const AMBIENT := Color(0.35, 0.34, 0.33)


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true  # the strikes and the reactor bloom
	env.glow_intensity = 0.8
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.5  # only what is really bright blooms; no haze over the whole frame
	_env = env
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
	_lights = {key: key.light_energy, lamp: lamp.light_energy}
	_fill.position = AT + Vector3(0.12, 0.2, 0.3)
	_fill.light_color = Color(0.75, 0.85, 1.0)
	_fill.omni_range = 0.6
	_fill.light_specular = 0.3
	add_child(_fill)

	# The bench is there from the first frame: held back for its quest, it dropped in from above
	# over the round's first second (the user saw the round under the table).
	for id: String in GameState.QUESTS:
		if GameState.QUESTS[id].get("unlock") == "workbench" and not id in GameState.quests_done:
			GameState.quests_done.append(id)
	# Heard even with the window in the background (recording it, watching it beside the editor):
	# for this run only, the file keeps the player's own setting.
	Settings.values["mute_unfocused"] = false
	AudioServer.set_bus_mute(0, false)
	var bench := StaticBody3D.new()
	bench.add_child(load("res://assets/props/workbench/workbench.glb").instantiate())
	bench.scale = Vector3.ONE * BENCH
	bench.set_script(preload("res://scripts/bench_top.gd"))  # clears the top, as in the game
	add_child(bench)
	_tesla = bench.get_child(0).get_node(^"P_tesla_coil")

	_cam.fov = 40.0
	add_child(_cam)
	_fx = FX.new()
	_fx.position = AT
	_fx.tesla = _tesla
	add_child(_fx)
	_process(0.0)  # the camera on the round from the first frame
	_fx.play.call_deferred()


func _process(_delta: float) -> void:
	var t: float = _fx._t
	var close_at := AT + Vector3(0.0, 0.11, 0.0)
	var close_from := close_at + Vector3(0.0, 0.04, 0.4)
	var top := _tesla.global_position + Vector3(0.0, 0.3, 0.0)
	var wide_at := (close_at + top) * 0.5
	var wide_from := wide_at + Vector3(-0.3, 0.12, 0.95)
	# Out once the nose is home (not as it lands), back in on the charged round as the strikes end.
	var out := _ease((t - (FX.PRESS.y + 0.35)) / 0.8) * (1.0 - _ease((t - (FX.ZAP + FX.ARC + 0.3)) / 0.8))
	var jolt: float = 0.006 * _fx.shake(t)
	var kick := Vector3(sin(t * 83.0), cos(t * 71.0), sin(t * 59.0)) * jolt
	_cam.look_at_from_position(close_from.lerp(wide_from, out) + kick, close_at.lerp(wide_at, out))
	var dark: float = _fx.darkness(t)
	for l: Light3D in _lights:
		l.light_energy = _lights[l] * lerpf(1.0, 0.03, dark)  # dark: the flashes are what show the room
	_env.ambient_light_color = AMBIENT * lerpf(1.0, 0.04, dark)
	_fill.light_energy = 0.55 * dark


func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and event.pressed):
		_fx.play()
