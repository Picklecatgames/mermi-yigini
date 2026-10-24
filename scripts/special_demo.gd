extends Node3D
## Special rounds test (debug builds, solo; N in player.gd): a stand-in teammate in front of us,
## drawn like any other player (remote_players.gd, from the poses this node sends), and a pocket
## full of every special (GameState.SPECIALS, so new ones show up here by themselves).
## Shooter: hold R, pick one on the ammo wheel and shoot the teammate; the round goes the real way (request_fire ->
## player_shot) and this node plays what it does to them. Target: J has the teammate shoot us
## with the armed special (not spent), through the same player_shot our own machine answers.
# ponytail: the stand-in's moves copy player.gd's special physics; keep the two in step.

var _p: Node  # the player (player.gd): its effect numbers and HUD helpers
const PEER := 990001  # nobody's id
const EACH := 3  # of every special in the pocket, topped up on N
const GAP := 6.0  # m in front of us
const SHOOT_SHOWN := 0.25  # s the stand-in's pose says SHOOTING

var _body: CharacterBody3D
var _shove := Vector3.ZERO
var _balloon := 0.0
var _drifting := false
var _shooting := 0.0
var _bounces := 0
var _spin := 0.0  # rad/s it turns round while thrown
var _turned := 0.0  # rad off facing us
var _hint: Label


func _ready() -> void:
	var me := _me()
	_p = me
	var ahead := -me.global_basis.z
	ahead.y = 0.0
	var at := me.global_position + ahead.normalized() * GAP
	at.x = minf(at.x, GameState.FIRING_LINE_X - 1.0)  # on our side of the railing
	_body = CharacterBody3D.new()
	_body.collision_layer = 0  # rounds hit the drawn character's body, not this one
	_body.collision_mask = 1 | (1 << (GameState.FENCE_LAYER - 1))
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.shape.radius = 0.35
	shape.shape.height = 1.8
	shape.position.y = 0.9
	_body.add_child(shape)
	add_child(_body)
	_body.global_position = at + Vector3.UP * 0.5
	GameState.player(PEER).gun = 1
	GameState.player_shot.connect(_on_player_shot)
	refill()
	# Top left, out of the HUD's symmetric middle (scripts/hud.gd).
	_hint = UiStyle.caption("Özel mermi denemesi\nR basılı tut: mermi seç\nSol tık: arkadaşına sık\nJ: arkadaşın sana sıksın\nN: doldur    Shift N: kapat")
	_hint.position = Vector2(30, 24)
	me.get_node("HUD").add_child(_hint)


func _exit_tree() -> void:
	_hint.queue_free()
	var others := get_tree().get_first_node_in_group("remote_players")
	if others:
		others._drop(PEER)
	GameState._players.erase(PEER)


func _me() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("walker")


## Every special EACH times in the pocket, and a gun in hand to shoot them with.
func refill() -> void:
	var p := GameState.player()
	p.specials.clear()
	for id: String in GameState.SPECIALS:
		for i in EACH:
			p.specials.append(id)
	GameState.specials_changed.emit()
	if p.gun == 0:
		GameState.request_select_gun(1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		shoot_us()


## The stand-in fires the armed special (or a plain round) at our chest.
func shoot_us() -> void:
	var me := _me()
	var from: Vector3 = _body.global_position + Vector3.UP * _p.EYE
	var at := me.global_position + Vector3.UP * 1.2
	var dir: Vector3 = (at - from).normalized()
	_shooting = SHOOT_SHOWN
	GameState.fired.emit(PEER, from, dir)
	GameState.shot_landed.emit(PEER, at, -dir, dir, null, 0, false, 0)
	GameState.player_shot.emit(PEER, GameState.local_peer(), at, dir, GameState.player().armed)


## Our round hit the stand-in: what a teammate's machine would play for them.
func _on_player_shot(_shooter: int, victim: int, _at: Vector3, dir: Vector3, special: String) -> void:
	if victim != PEER:
		return
	match special:
		"punch":
			_shove = _p.punch_shove(dir)
			if _body.velocity.y <= 0.0:
				_body.velocity.y = randf_range(_p.PUNCH_UP.x, _p.PUNCH_UP.y)
			_bounces = 1
			_spin = randf_range(8.0, 14.0) * signf(randf() - 0.5)
		"balloon":
			_balloon = _p.BALLOON_TIME
			_drifting = true


func _physics_process(delta: float) -> void:
	var on_floor := _body.is_on_floor()
	_balloon = maxf(_balloon - delta, 0.0)
	if _balloon > 0.0:
		_body.velocity.y = _p.BALLOON_RISE
	elif not on_floor:
		_body.velocity += _body.get_gravity() * delta
		if _drifting:
			_body.velocity.y = maxf(_body.velocity.y, -_p.BALLOON_FALL)
	if on_floor and _balloon == 0.0:
		_drifting = false
	_shove *= exp(-(_p.SHOVE_DECAY if on_floor else _p.AIR_DRAG) * delta)
	_body.velocity.x = _shove.x
	_body.velocity.z = _shove.z
	var inside := _body.global_position.x <= GameState.FIRING_LINE_X
	_body.move_and_slide()
	_p.keep_in_hall(_body, inside)
	if not on_floor and _body.is_on_floor():
		if _bounces > 0 and _shove.length() > 6.0:
			_bounces -= 1
			_shove = _p.punch_bounce(_shove)
			_body.velocity.y = 3.5
		else:
			_spin = 0.0
	_turned = wrapf(_turned + _spin * delta, -PI, PI) if _spin != 0.0 else _turned * exp(-6.0 * delta)
	# Faces us, as a teammate turning to watch would (spinning while thrown); its pose goes out
	# like a real player's.
	var to := _me().global_position - _body.global_position
	var yaw := atan2(-to.x, -to.z) + _turned
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	_shooting = maxf(_shooting - delta, 0.0)
	var act := GameState.Act.SHOOTING if _shooting > 0.0 else GameState.Act.IDLE
	GameState.pose_received.emit(PEER, Time.get_ticks_msec() / 1000.0, _body.global_position, yaw, pitch, act, not _body.is_on_floor())
