extends Node
## The connection layer: the only script that knows how peers reach each other (ENet for now).
## Faz 6 swaps ENet for GodotSteam lobbies here and nothing else changes; GameState only asks
## `online` / `is_client` and uses Godot's multiplayer API.
##
## Test: start two copies, one with `-- --host`, the other with `-- --join` (or `--join=IP`).
## In debug builds F7 hosts and F8 joins 127.0.0.1 from inside the game.

signal status_changed(text: String)

const PORT := 24680
## ENet's own brake on unreliable packets (a pose is one): a round trip slower than usual, one long
## frame is enough, and it starts dropping them, down to all of them for a second or more. The host
## then has our body where it stood a second ago, and a round from where we really are is refused as
## forged (GameState.FIRE_FROM_SLACK). A pose every 50 ms is small; nothing here needs braking.
const THROTTLE_INTERVAL := 5000  # ms (ENet's default)
const THROTTLE_UP := 32  # back to full at once
const THROTTLE_DOWN := 0  # never down

var status := ""
var _label: Label


## Connected to a session, as host or as a client that has finished joining.
var online: bool:
	get:
		var p := multiplayer.multiplayer_peer
		return p != null and not p is OfflineMultiplayerPeer \
			and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

## Joined someone else's session: requests go to the host instead of running here.
var is_client: bool:
	get: return online and not multiplayer.is_server()


func _ready() -> void:
	multiplayer.connected_to_server.connect(func() -> void:
		_no_throttle(1)
		_set_status("İSTEMCİ"))
	multiplayer.connection_failed.connect(func() -> void:
		leave()
		_set_status("Bağlanamadı"))
	multiplayer.server_disconnected.connect(func() -> void:
		leave()
		_set_status("Host ayrıldı"))
	multiplayer.peer_connected.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_no_throttle(id)
		_refresh_host())
	multiplayer.peer_disconnected.connect(func(_id: int) -> void: _refresh_host())
	if DisplayServer.get_name() != "headless":
		var layer := CanvasLayer.new()
		layer.layer = 100
		_label = Label.new()
		_label.position = Vector2(12, 8)
		_label.add_theme_font_size_override("font_size", 16)
		_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_label.add_theme_constant_override("outline_size", 4)
		layer.add_child(_label)
		add_child(layer)
	add_child(preload("res://scripts/day_night.gd").new())
	add_child(preload("res://scripts/music.gd").new())  # follows the same clock
	if OS.is_debug_build():
		add_child(preload("res://scripts/cheat_menu.gd").new())
		add_child(preload("res://scripts/spawn_menu.gd").new())
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			host()
		elif arg.begins_with("--join"):
			join(arg.get_slice("=", 1) if "=" in arg else "127.0.0.1")


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F7 and not online:
		host()
	elif event.keycode == KEY_F8 and not online and not multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		join()  # not again while still connecting: the first peer would be left half open


## See THROTTLE_DOWN. Set once connected: the handshake sets it back to ENet's own.
func _no_throttle(id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var link := enet.get_peer(id) if enet else null
	if link:
		link.throttle_configure(THROTTLE_INTERVAL, THROTTLE_UP, THROTTLE_DOWN)


## Seconds a message from the host takes to get here (half the round trip); 0 when not a client.
func latency() -> float:
	if not is_client:
		return 0.0
	var host_peer := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)
	return host_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 2000.0 if host_peer else 0.0


func host(port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, GameState.MAX_PLAYERS - 1)
	if err != OK:
		_set_status("Host açılamadı (port %d: %s)" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	_refresh_host()
	return OK


func join(address := "127.0.0.1", port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_set_status("Bağlanamadı (%s)" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	_set_status("Bağlanıyor: %s:%d" % [address, port])
	return OK


## Back to solo; whatever was mirrored from the host stays as it was.
func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _refresh_host() -> void:
	if multiplayer.is_server() and online:
		_set_status("HOST · %d oyuncu" % (multiplayer.get_peers().size() + 1))


func _set_status(text: String) -> void:
	status = text
	print("[net] ", text)
	if _label:
		_label.text = text
	if DisplayServer.get_name() != "headless":
		get_window().title = "Mermi Yığını · " + text
	status_changed.emit(text)
