extends Node

## Beckett runtime autoload: the ONLY Beckett file that a shipped game ever sees.
##
## Enabling the plugin registers this as a project autoload, so it is baked into
## project.godot and rides along into every export. That makes it the one Beckett
## script whose parse cost is paid by the player, which drives two hard rules:
##
##   1. It must parse on ANY engine build. A custom engine compiled with a build
##      profile can have hundreds of classes stripped from ClassDB, and GDScript
##      resolves class identifiers at PARSE time: one `is MeshInstance3D` against
##      an engine without MeshInstance3D fails the whole script, and a failed
##      autoload script prints errors before the main scene even loads. So this
##      file names nothing but Node, OS and String. Everything with a real type
##      dependency (mcp_runtime.gd and friends: Camera3D, ShaderMaterial,
##      GraphEdit, StreamPeerTCP, ...) is reached through load(), which resolves
##      at RUNTIME and only on the branch that never runs in an export.
##
##   2. It must do nothing outside the editor. The runtime channel exists to serve
##      a game the editor itself launched (EditorInterface.play_main_scene), so
##      "am I running under an editor build" is the exact gate. In an export
##      template OS.has_feature("editor") is false and this node stays an empty,
##      silent Node: no socket, no retry timer, no commands served.
##
## Pair this with core/export_filter.gd, which strips every OTHER Beckett file out
## of the pack, so a shipped game carries this stub and nothing else.

## Resolved at runtime, never preloaded: a preload() is a parse-time dependency and
## would drag mcp_runtime.gd's whole type closure back into this file.
const IMPL_PATH := "res://addons/beckett/runtime/mcp_runtime.gd"
const IMPL_NAME := "BeckettRuntimeImpl"


func _ready() -> void:
	if not OS.has_feature("editor"):
		return

	for sib in get_tree().root.get_children():
		if sib != self and sib.get_script() == get_script() and sib.get_index() < get_index():
			push_warning("[beckett] duplicate runtime autoload '%s' (twin of '%s'), staying dormant; remove the stale autoload entry from project.godot" % [name, sib.name])
			return

	if not ResourceLoader.exists(IMPL_PATH):
		push_warning("[beckett] runtime implementation not present at %s, so the play/observe loop is off; this is expected in an exported pack and means a half-installed addon anywhere else" % IMPL_PATH)
		return
	var impl = load(IMPL_PATH)
	if impl == null:
		push_warning("[beckett] runtime implementation at %s failed to load, so the play/observe loop is off" % IMPL_PATH)
		return

	for sib in get_tree().root.get_children():
		if sib != self and sib.get_script() == impl:
			push_warning("[beckett] a legacy autoload ('%s') still points straight at %s, staying dormant; re-point it at %s so it stops shipping into your exports" % [sib.name, IMPL_PATH, get_script().resource_path])
			return

	process_mode = Node.PROCESS_MODE_ALWAYS

	var node = impl.new()
	node.name = IMPL_NAME
	add_child(node)
