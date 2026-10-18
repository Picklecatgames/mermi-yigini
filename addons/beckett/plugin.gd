@tool
extends EditorPlugin

## Beckett (MCP for Godot) — EditorPlugin entry point.
## Wires up the embedded MCP server (zero-sidecar) and an optional dock panel.
## The server is OFF by default; it starts only when BECKETT_ENABLE=1 (or via the panel).

const MCPServerScript := preload("res://addons/beckett/core/mcp_server.gd")
const PanelScript := preload("res://addons/beckett/panel/panel.gd")
const MCPClientConfig := preload("res://addons/beckett/core/client_config.gd")
const ExportFilterScript := preload("res://addons/beckett/core/export_filter.gd")

const RUNTIME_AUTOLOAD := "BeckettRuntime"
## A parse-safe stub, NOT the implementation. It is the one Beckett file that reaches a
## shipped game, so it names no engine class that a custom build profile could strip and
## it goes inert outside the editor. See runtime/beckett_autoload.gd for the full why.
const RUNTIME_SCRIPT := "res://addons/beckett/runtime/beckett_autoload.gd"
## What the autoload pointed at before the stub existed; projects set up then get re-pointed.
const LEGACY_RUNTIME_SCRIPT := "res://addons/beckett/runtime/mcp_runtime.gd"

var _server: MCPServerScript = null
var _panel: Control = null
var _dock: Control = null
var _export_filter: EditorExportPlugin = null


func _enter_tree() -> void:
	_install_runtime_autoload()

	_export_filter = ExportFilterScript.new()
	add_export_plugin(_export_filter)

	_server = MCPServerScript.new()
	_server.name = "GodotMCPServer"
	_server.plugin = self
	add_child(_server)
	_server.setup()

	var port := _port()
	if _autostart():
		var err := _server.start_server(port)
		if err == OK:
			print("[beckett] server listening on " + MCPClientConfig.mcp_url(_server.http.port, _server.auth_token())
				+ (" (token auth on)" if _server.auth_enabled() else ""))
		else:
			push_error("[beckett] failed to start server: %s" % error_string(err))

	if _auto_write_config():
		MCPClientConfig.ensure_auto(_server.http.port if _server.is_running() else port, _server.auth_token())

	_panel = PanelScript.new()
	_panel.server = _server
	_panel.plugin = self
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock = ScrollContainer.new()
	_dock.name = "Beckett"
	_dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock.add_child(_panel)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)
	_reveal_dock_once()


## First time the plugin is enabled in a project, bring our dock tab to the front so it's
## discoverable. The editor's right dock can overflow, hiding a 4th tab (ours) behind the
## tab-scroll arrows — and on Godot 4.2-4.4 a control renamed *after* add_control_to_dock
## keeps a blank tab title, so without this the tab is effectively invisible. Gated by a
## project flag so we reveal once (first enable / first launch after update) and never
## fight the user's chosen layout afterward.
func _reveal_dock_once() -> void:
	if bool(ProjectSettings.get_setting("beckett/dock_revealed", false)):
		return
	ProjectSettings.set_setting("beckett/dock_revealed", true)
	ProjectSettings.save()
	get_tree().create_timer(0.7).timeout.connect(_bring_dock_to_front)


func _bring_dock_to_front() -> void:
	if not is_instance_valid(_dock):
		return
	var p: Node = _dock.get_parent()
	while p != null and not (p is TabContainer):
		p = p.get_parent()
	if p is TabContainer:
		var idx := _dock.get_index()
		if idx >= 0:
			(p as TabContainer).current_tab = idx


func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.free()
	_dock = null
	_panel = null
	if is_instance_valid(_server):
		_server.stop_server()
		_server.queue_free()
	_server = null
	if _export_filter != null:
		remove_export_plugin(_export_filter)
	_export_filter = null
	if ProjectSettings.has_setting("autoload/" + RUNTIME_AUTOLOAD):
		remove_autoload_singleton(RUNTIME_AUTOLOAD)


## Register the runtime autoload, or re-point an older one at the stub.
##
## Projects set up before the stub existed have the autoload aimed straight at
## mcp_runtime.gd. That file names Camera3D, MeshInstance3D, ShaderMaterial, GraphEdit and
## friends at parse time, so on an engine built with a stripped class profile it fails to
## parse and the player sees the errors at boot. Re-pointing is the whole upgrade.
func _install_runtime_autoload() -> void:
	var key := "autoload/" + RUNTIME_AUTOLOAD
	if not ProjectSettings.has_setting(key):
		add_autoload_singleton(RUNTIME_AUTOLOAD, RUNTIME_SCRIPT)
		return
	if _autoload_target(str(ProjectSettings.get_setting(key, ""))) != LEGACY_RUNTIME_SCRIPT:
		return
	remove_autoload_singleton(RUNTIME_AUTOLOAD)
	add_autoload_singleton(RUNTIME_AUTOLOAD, RUNTIME_SCRIPT)
	var err := ProjectSettings.save()
	if err != OK:
		push_warning("[beckett] could not save project.godot after re-pointing the runtime autoload: %s" % error_string(err))
		return
	print("[beckett] runtime autoload re-pointed at the export-safe stub (%s)" % RUNTIME_SCRIPT)


## Resolve an [autoload] entry's value to a res:// path.
##
## Two things make a plain string compare wrong: the value carries a leading "*" when the
## autoload is exposed as a singleton, and since 4.4 the editor writes the target as a
## uid:// reference rather than a path, so the stored value for mcp_runtime.gd can read
## "*uid://dspgi2nxto4e8" with the path nowhere in sight.
static func _autoload_target(value: String) -> String:
	var p := value.trim_prefix("*")
	if not p.begins_with("uid://"):
		return p
	var id := ResourceUID.text_to_id(p)
	if id == ResourceUID.INVALID_ID or not ResourceUID.has_id(id):
		return p
	return ResourceUID.get_id_path(id)


## The port we ask for at boot. Shared with the dock (MCPClientConfig.configured_port) so a
## manual Stop→Start can never bind a different port than this did.
func _port() -> int:
	return MCPClientConfig.configured_port()


func _autostart() -> bool:
	var env := OS.get_environment("BECKETT_ENABLE")
	if env != "":
		return env == "1" or env.to_lower() == "true"
	return bool(ProjectSettings.get_setting("beckett/autostart", true))


func _auto_write_config() -> bool:
	var env := OS.get_environment("BECKETT_AUTO_CONFIG")
	if env != "":
		return env == "1" or env.to_lower() == "true"
	return bool(ProjectSettings.get_setting("beckett/auto_write_client_config", true))
