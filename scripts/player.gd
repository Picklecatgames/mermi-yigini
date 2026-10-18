extends CharacterBody3D
## First-person player: walk, sprint, jump, mouse look, grab bullets from the pile.

const SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.002
const BOB_FREQ := 1.4    # bob cycles per metre walked, scaled by speed
const BOB_AMP := 0.05    # metres
const HAND_MAX := 6      # bullets drawn in hand; more are carried but not shown
const GRAB_TIME := 0.25  # s for one bullet to fly into the hand
const GRAB_GAP := 0.08   # s between bullets of one grab
const PILE_BULLET_SCALE := 0.03  # matches the pile look; shrinks to hand size in flight
const BULLET := preload("res://assets/bullet/bullet_9mm.glb")
const GRAB_REPEAT := 0.02  # s between grabs while E is held

var _grab_timer := 0.0

var _bob := 0.0

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _reach: RayCast3D = $Head/Camera3D/Reach
@onready var _hand: Node3D = $Head/Camera3D/Hand
@onready var _prompt: Label = $HUD/Prompt
@onready var _counter: Label = $HUD/Counter


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("walker")  # kicks loose bullets around (Pile)
	GameState.pile_changed.connect(_update_counter.unbind(1))
	GameState.carried_changed.connect(_update_counter.unbind(1))
	GameState.carried_changed.connect(func(c: int) -> void: _set_hand_count(mini(c, HAND_MAX)))
	GameState.upgraded.connect(_update_counter.unbind(2))
	_update_counter()
	_set_hand_count(mini(GameState.carried, HAND_MAX))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		_head.rotation.x = clampf(_head.rotation.x, -1.5, 1.5)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("throw"):
		GameState.request_throw(_hand.global_position, -_camera.global_basis.z)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := transform.basis * Vector3(input.x, 0.0, input.y)
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
	_head_bob(delta)

	# Holding E keeps grabbing, one bullet at a time, until the hand is full.
	_grab_timer -= delta
	if Input.is_action_pressed("pick_up") and _grab_timer <= 0.0 and _looking_at_pile():
		_grab_timer = GRAB_REPEAT
		var at := _reach.get_collision_point()
		var shown_before := mini(GameState.carried, HAND_MAX)
		# A loose bullet goes by its id, so every peer removes the same one; else it is the heap.
		var id: int = _pile().loose_id(_reach.get_collider(), _reach.get_collider_rid())
		var got := GameState.request_pick_up_loose(id) if id >= 0 else GameState.request_pick_up(at, 1)
		if got > 0:
			_fly_to_hand(at, shown_before, 1)

	_prompt.visible = _looking_at_pile()
	_prompt.text = "[E] Mermi al (basılı tut)" if GameState.carried < GameState.carry_capacity else "Elin dolu  [Q] Fırlat"


func _head_bob(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and speed > 0.1
	if moving:
		_bob += delta * speed * BOB_FREQ
	var target := Vector3(cos(_bob) * BOB_AMP, sin(_bob * 2.0) * BOB_AMP, 0.0) if moving else Vector3.ZERO
	_camera.position = _camera.position.lerp(target, minf(delta * 10.0, 1.0))


func _looking_at_pile() -> bool:
	if not _reach.is_colliding():
		return false
	var pile := _pile()
	return pile != null and pile.is_grabbable(_reach.get_collider(), _reach.get_collider_rid())


func _pile() -> Node:
	return get_tree().get_first_node_in_group("bullet_pile")


## Bullets fly one after another from where they were grabbed into the hand; each one
## appears in the hand as it lands.
func _fly_to_hand(from: Vector3, shown_before: int, count: int) -> void:
	_set_hand_count(shown_before)
	for i in count:
		var b: Node3D = BULLET.instantiate()
		get_tree().current_scene.add_child(b)
		var start := from + Vector3(randf_range(-0.06, 0.06), 0.0, randf_range(-0.06, 0.06))
		var q0 := Quaternion.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
		var fly := func(f: float) -> void:
			var to := _hand.global_transform
			var pos := start.lerp(to.origin, f) + Vector3.UP * sin(f * PI) * 0.3
			var rot := Basis(q0.slerp(to.basis.get_rotation_quaternion(), f))
			b.global_transform = Transform3D(rot.scaled(Vector3.ONE * lerpf(PILE_BULLET_SCALE, to.basis.get_scale().x, f)), pos)
		fly.call(0.0)
		var t := b.create_tween()
		t.tween_interval(i * GRAB_GAP)
		t.tween_method(fly, 0.0, 1.0, GRAB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void:
			b.queue_free()
			_set_hand_count(shown_before + i + 1))


## Shows `n` bullets side by side in the hand, copying the first as needed.
func _set_hand_count(n: int) -> void:
	n = mini(n, HAND_MAX)
	var first := _hand.get_child(0) as Node3D
	while _hand.get_child_count() < n:
		var copy := first.duplicate() as Node3D
		copy.position = Vector3(0.0, _hand.get_child_count() * 1.1, 0.0)  # local +y is screen-left
		_hand.add_child(copy)
	for c in _hand.get_child_count():
		(_hand.get_child(c) as Node3D).visible = c < n
	_hand.visible = n > 0


func _update_counter() -> void:
	_counter.text = "Elde: %d/%d\nYığın: %s" % [GameState.carried, GameState.carry_capacity, _thousands(GameState.pile)]


static func _thousands(n: int) -> String:
	var s := str(n)
	for i in range(s.length() - 3, 0, -3):
		s = s.insert(i, ".")
	return s
