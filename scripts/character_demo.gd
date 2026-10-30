extends Node3D
## Character test (debug builds, solo; K in player.gd): a mirror in front of us. A stand-in
## teammate wearing our character copies every move we make, reflected, and is drawn the way a
## teammate's machine draws us (remote_players.gd, from the poses this node sends): body, stance,
## gun, the look pitch, reloads, shots, jumps. K puts on the next character (arms and body), L opens
## the pick screen (character_pick.gd) as at the start, Shift+K closes it.

const PEER := 990002  # nobody's id (special_demo.gd has 990001)
const GAP := 5.0  # m in front of us, at the start
const NEAREST := 1.2  # m it keeps off us when we walk into the mirror

var _p: Node  # the player (player.gd): its pose
var _mid := Vector3.ZERO  # a point on the mirror
var _n := Vector3.FORWARD  # the mirror's normal, from us toward it
var _hint: Label


func _ready() -> void:
	_p = get_tree().get_first_node_in_group("walker")
	_n = -_p.global_basis.z
	_n.y = 0.0
	_n = _n.normalized()
	_mid = _p.global_position + _n * GAP * 0.5
	var me := GameState.player()
	var them := GameState.player(PEER)
	them.gun = me.gun
	them.levels.grip = me.levels.grip
	them.character = me.character
	GameState.character_changed.connect(_on_character)
	GameState.gun_changed.connect(_on_gun)
	GameState.pistol_grip.connect(_on_grip)
	GameState.fired.connect(_on_fired)
	_hint = UiStyle.caption("Karakter denemesi\nK: sonraki karakter\nL: seçim ekranı\nShift K: kapat")
	_hint.position = Vector2(36, 110)
	_p.get_node("HUD").add_child(_hint)


func _exit_tree() -> void:
	_hint.queue_free()
	var others := _others()
	if others:
		others._drop(PEER)
	GameState._players.erase(PEER)


func _others() -> Node:
	return get_tree().get_first_node_in_group("remote_players")


## K: the next of GameState.CHARACTERS after ours (the first, before we have one).
func next_character() -> void:
	var ids: Array = GameState.CHARACTERS.keys()
	var at := ids.find(GameState.player().character)
	GameState.request_pick_character(ids[(at + 1) % ids.size()])


## L: back to no character, so the pick screen opens as it does at the start.
func open_pick() -> void:
	GameState.player().character = ""
	GameState.character_changed.emit(GameState.local_peer(), "")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L:
		open_pick()
		get_viewport().set_input_as_handled()


func _on_character(who: int, id: String) -> void:
	if who == GameState.local_peer():
		GameState.player(PEER).character = id
		GameState.character_changed.emit(PEER, id)


func _on_gun(who: int, g: int) -> void:
	if who == GameState.local_peer():
		GameState.player(PEER).gun = g
		GameState.gun_changed.emit(PEER, g)


func _on_grip(who: int, level: int) -> void:
	if who == GameState.local_peer():
		GameState.player(PEER).levels.grip = level
		GameState.pistol_grip.emit(PEER, level)


## Our shot: the stand-in's chest kicks and its muzzle flashes (the sound is already ours).
func _on_fired(peer: int, _from: Vector3, _dir: Vector3) -> void:
	var others := _others()
	var c: Node3D = others.character(PEER) if others and peer == GameState.local_peer() else null
	if c and c.visible:
		c.shoot()


## Our pose, reflected in the mirror, goes out as the stand-in's.
func _physics_process(_delta: float) -> void:
	var pos: Vector3 = _p.global_position
	var off := minf((pos - _mid).dot(_n), -NEAREST * 0.5)
	var at := pos - _n * off * 2.0
	var yaw: float = _p._yaw
	var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw))
	ahead -= _n * ahead.dot(_n) * 2.0
	var air: bool = _p._air_time > _p.AIR_SHOWN
	GameState.pose_received.emit(PEER, Time.get_ticks_msec() / 1000.0, at, atan2(-ahead.x, -ahead.z), _p._pitch, _p._act(), air, _p.crouched)
