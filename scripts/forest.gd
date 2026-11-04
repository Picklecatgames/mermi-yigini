extends Node3D
## The dry wood round the pad (tools/build_world.gd _forest), drawn at load: a MultiMesh per tree
## kind per chunk, a light copy near and a lighter one far. The builder runs headless, where a
## MultiMesh's transforms aren't kept, so they're saved here as plain numbers instead.

## Each: [near mesh, far mesh (or null), near end m (0: always), far end m, cast shadow, transforms (12 floats each), a tone each (Color, optional)]
@export var groups: Array = []


func _ready() -> void:
	for g: Array in groups:
		var xfs: PackedFloat32Array = g[5]
		var tones: PackedColorArray = g[6] if g.size() > 6 else PackedColorArray()
		_add(g[0], xfs, 0.0, g[2], g[4], tones)
		if g[1]:
			_add(g[1], xfs, g[2], g[3], false, tones)


func _add(mesh: Mesh, xfs: PackedFloat32Array, near: float, far: float, shadow: bool, tones: PackedColorArray) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not tones.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size() / 12
	for i in mm.instance_count:
		var o := i * 12
		mm.set_instance_transform(i, Transform3D(Vector3(xfs[o], xfs[o + 1], xfs[o + 2]), Vector3(xfs[o + 3], xfs[o + 4], xfs[o + 5]),
			Vector3(xfs[o + 6], xfs[o + 7], xfs[o + 8]), Vector3(xfs[o + 9], xfs[o + 10], xfs[o + 11])))
		if not tones.is_empty():
			mm.set_instance_color(i, tones[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_begin = near
	mmi.visibility_range_end = far
	mmi.visibility_range_end_margin = 4.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
