extends Node
## Debug builds only, until the real build menu: put factory pieces down by hand.
## F2 next piece (the last one: off), F3 turn, F4 put down, F5 take down what's looked at, F6 print
## what the kasa holds. Green or red ghost on the ground where the camera looks.

var factory: Node
var _kind := -1  # data.kinds index, -1 off
var _dir := 0
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _nose: MeshInstance3D
var _ghost_kind := -1


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var sim: FactorySim = factory.sim
	match event.keycode:
		KEY_F2:
			_kind += 1
			if _kind >= sim.data.kinds.size():
				_kind = -1
			print("[factory] ", sim.data.kind_ids[_kind] if _kind >= 0 else "off")
		KEY_F3:
			_dir = (_dir + 1) % 4
		KEY_F4:
			var at: Variant = _aim()
			if _kind >= 0 and at != null:
				GameState.request_factory_place(sim.data.kind_ids[_kind], at.x, at.y, _dir)
		KEY_F5:
			var at: Variant = _aim()
			if at != null:
				GameState.request_factory_remove(at.x, at.y)
		KEY_F6:
			var left := {}
			for i in sim.stock.size():
				if sim.stock[i] != 0:
					left[sim.data.item_ids[i]] = sim.stock[i]
			print("[factory] step %d, %d structures, %d on belts, kasa %s" % [sim.step, sim.count, sim.items_on_belts(), left])


func _process(_delta: float) -> void:
	if _kind < 0:
		if _ghost:
			_ghost.visible = false
		return
	var at: Variant = _aim()
	if at == null:
		if _ghost:
			_ghost.visible = false
		return
	var sim: FactorySim = factory.sim
	_show_ghost(sim)
	var f := sim.footprint(_kind, _dir)
	_ghost.visible = true
	_ghost.global_position = Vector3(at.x + f.x * 0.5, sim.data.kinds[_kind].kutu[1] * 0.5, at.y + f.y * 0.5)
	_ghost.rotation.y = -_dir * PI * 0.5
	var ok: bool = factory.can_build(_kind, at.x, at.y, _dir)
	_ghost_mat.albedo_color = Color(0.2, 0.9, 0.3, 0.4) if ok else Color(0.9, 0.2, 0.2, 0.4)


func _show_ghost(sim: FactorySim) -> void:
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost_mat = StandardMaterial3D.new()
		_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost.material_override = _ghost_mat
		_nose = MeshInstance3D.new()  # which way it faces
		var nose := BoxMesh.new()
		nose.size = Vector3(0.2, 0.2, 0.2)
		_nose.mesh = nose
		_nose.material_override = _ghost_mat
		_ghost.add_child(_nose)
		factory.add_child(_ghost)
	if _ghost_kind != _kind:
		_ghost_kind = _kind
		var row: Dictionary = sim.data.kinds[_kind]
		var box := BoxMesh.new()
		box.size = Vector3(row.d, row.kutu[1], row.w)
		_ghost.mesh = box
		_nose.position = Vector3(row.d * 0.5 + 0.1, 0.0, 0.0)


## The grid cell the camera looks at on the ground, x and z; null when it looks at the sky.
func _aim() -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var from := cam.global_position
	var along := -cam.global_basis.z
	if along.y > -0.02:
		return null
	var p := from + along * (from.y / -along.y)
	return Vector2i(floori(p.x), floori(p.z))
