extends SceneTree
## Plays the operator's baked clips live in a window, to look at them by eye:
##   Godot.exe --path . -s res://tools/anim_viewer.gd
## Left/Right: previous/next clip. Mouse drag: turn the camera. Up/Down: zoom. Esc: quit.

const LIB := "res://assets/characters/animations/operator_anims.res"

var _ap: AnimationPlayer
var _label: Label
var _clips: PackedStringArray
var _i := 0
var _pivot: Node3D
var _cam: Camera3D
var _held := {}  # key -> was down last frame


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	floor.mesh = pm
	world.add_child(floor)

	var op: Node3D = load("res://assets/characters/operator/operator.gltf").instantiate()
	op.scale = Vector3.ONE * 0.01
	world.add_child(op)
	_ap = AnimationPlayer.new()
	op.add_child(_ap)
	_ap.root_node = NodePath("..")
	_ap.add_animation_library("", load(LIB))
	_clips = _ap.get_animation_list()
	# Clips that don't loop on their own repeat here, so there is time to look.
	_ap.animation_finished.connect(func(_n: StringName) -> void: _ap.play(_clips[_i]))

	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 1.0, 0)
	_pivot.rotation_degrees = Vector3(-10, 30, 0)
	world.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 0, 3.5)
	_pivot.add_child(_cam)
	_cam.make_current()

	var ui := CanvasLayer.new()
	root.add_child(ui)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 22)
	ui.add_child(_label)
	_play()


func _play() -> void:
	_ap.play(_clips[_i])
	_label.text = "%s   (%d/%d)\n← → klip   ·   fareyle sürükle: döndür   ·   ↑ ↓ yakınlaş   ·   Esc: çık" % [_clips[_i], _i + 1, _clips.size()]


func _process(delta: float) -> bool:
	if _pressed(KEY_RIGHT):
		_i = (_i + 1) % _clips.size()
		_play()
	if _pressed(KEY_LEFT):
		_i = (_i - 1 + _clips.size()) % _clips.size()
		_play()
	if Input.is_key_pressed(KEY_UP):
		_cam.position.z = maxf(_cam.position.z - 3.0 * delta, 1.0)
	if Input.is_key_pressed(KEY_DOWN):
		_cam.position.z = minf(_cam.position.z + 3.0 * delta, 12.0)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var v := Input.get_last_mouse_velocity() * delta
		_pivot.rotation_degrees.y -= v.x * 0.4
		_pivot.rotation_degrees.x = clampf(_pivot.rotation_degrees.x - v.y * 0.3, -80, 30)
	return Input.is_key_pressed(KEY_ESCAPE)


## True on the frame the key goes down.
func _pressed(key: Key) -> bool:
	var down := Input.is_key_pressed(key)
	var was: bool = _held.get(key, false)
	_held[key] = down
	return down and not was
