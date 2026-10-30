extends RefCounted
## Reveal (preloaded where used). A mechanic's prop that isn't there until a quest opens it (GameState QUESTS `unlock`): then it
## drops into its place and a beam of light stands on it for a while. The beam is in group
## "reveal_marker" with meta "label", so the HUD points the way to it (hud.gd _draw_pointer).

const DROP := 2.4  # m, how high it falls from
const FALL := 0.7  # s
const MARK_TIME := 10.0  # s the beam stays
const BEAM := Color(1.0, 0.78, 0.35)


## Hides `prop` (and its collision) until `what` is unlocked. Already open: nothing happens.
## `extras` (what belongs with it: a radio, lamps, posters) are hidden too and come on, sound and
## all, the moment it lands.
static func hold(prop: Node3D, what: String, label: String, extras: Array = []) -> void:
	if GameState.unlocked(what):
		return
	for n: Node3D in [prop] + extras:
		_set_there(n, false)
	GameState.quest_done.connect(func(id: String, _gold: int) -> void:
		if is_instance_valid(prop) and not prop.visible and GameState.QUESTS[id].get("unlock") == what:
			_drop_in(prop, label, extras))


static func _set_there(n: Node3D, on: bool) -> void:
	n.visible = on
	# Its own body and any under it (the press is a body of its own on the bench). One still held
	# back by its own reveal stays out when its parent comes; its layer is only noted the first time.
	for c: Node in [n] + n.find_children("*", "CollisionObject3D", true, false):
		if not c is CollisionObject3D or (on and c != n and not c.visible):
			continue
		if not on and not c.has_meta("reveal_layer"):
			c.set_meta("reveal_layer", c.collision_layer)
		c.collision_layer = c.get_meta("reveal_layer", c.collision_layer) if on else 0
	# A hidden node still sounds: its players stop and start with it.
	for s: Node in n.find_children("*", "AudioStreamPlayer3D", true, false):
		if not on:
			s.autoplay = false
			s.stop()
		else:
			s.play()


static func _drop_in(prop: Node3D, label: String, extras: Array) -> void:
	_set_there(prop, true)
	var foot := prop.global_position
	var end := prop.position
	var size := prop.scale
	prop.position = end + Vector3.UP * DROP
	var tw := prop.create_tween()
	tw.tween_property(prop, "position", end, FALL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# It lands: squashes a little and springs back.
	tw.tween_callback(func() -> void:
		for n: Node3D in extras:
			if is_instance_valid(n):
				_set_there(n, true))
	tw.tween_property(prop, "scale", size * Vector3(1.06, 0.9, 1.06), 0.08)
	tw.tween_property(prop, "scale", size, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var beam := _beam(label)
	prop.get_parent().add_child(beam)
	beam.global_position = Vector3(foot.x, 0.0, foot.z)


## A tall soft column of light; the HUD aims at `height` over its foot.
static func _beam(label: String) -> Node3D:
	var root := Node3D.new()
	root.add_to_group("reveal_marker")
	root.set_meta("label", label)
	root.set_meta("height", 2.0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.9
	mesh.bottom_radius = 0.9
	mesh.height = 7.0
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(BEAM, 0.0)
	mesh.material = mat
	var cyl := MeshInstance3D.new()
	cyl.mesh = mesh
	cyl.position.y = mesh.height * 0.5
	cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cyl)
	var light := OmniLight3D.new()
	light.light_color = BEAM
	light.omni_range = 4.0
	light.light_energy = 0.0
	light.position.y = 1.6
	root.add_child(light)
	# Fades in, holds, fades out, goes.
	var tw := root.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.16, 0.6)
	tw.parallel().tween_property(light, "light_energy", 2.5, 0.6)
	tw.tween_interval(MARK_TIME)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.2)
	tw.parallel().tween_property(light, "light_energy", 0.0, 1.2)
	tw.tween_callback(root.queue_free)
	return root
