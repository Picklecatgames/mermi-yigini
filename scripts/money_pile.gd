extends MultiMeshInstance3D
## The cash on the boss's desk (tools/range_dressing.gd): strapped bundles heaped by the local
## player's gold, a mound that grows from the middle out and up, 28 bundles a tenfold.
## Decoration only: each machine shows its own player's gold, nothing synced.

const BUNDLE := preload("res://assets/props/office/cash_bundle.gltf")
const SIZE := Vector3(0.085, 0.043, 0.214)  # one bundle (tools/build_office.py)
const CAP := 150  # full at ~$4.5M; more would tower over the desk lamp
const SLOPE := 0.55  # m of height per m out from the middle: how steep the mound stands
## The clear patch of desk top the mound sits on, centred on this node.
@export var area := Vector2(0.62, 0.9)


func _ready() -> void:
	var inst := BUNDLE.instantiate()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = (inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	inst.free()
	var xfs := layout(area)
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	multimesh = mm
	var gs := get_node("/root/GameState")  # by path: tools/build_arena.gd compiles this without autoloads
	gs.gold_changed.connect(_show)
	_show(gs.gold)


## Where each of the CAP bundles lies, in the order they come out: the next one lands where the
## mound is lowest for how far out it is.
static func layout(patch: Vector2) -> Array[Transform3D]:
	var cols := int(patch.x / (SIZE.x + 0.006))
	var rows := int(patch.y / (SIZE.z + 0.012))
	var cell := func(c: int) -> Vector2:
		return Vector2((c % cols - (cols - 1) / 2.0) * patch.x / cols, (c / cols - (rows - 1) / 2.0) * patch.y / rows)
	var tops := PackedFloat32Array()
	tops.resize(cols * rows)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11  # the same heap every run
	var out: Array[Transform3D] = []
	for i in CAP:
		var best := 0
		var best_key := INF
		for c in tops.size():
			var key: float = tops[c] + SLOPE * (cell.call(c) as Vector2).length() + rng.randf() * 0.01
			if key < best_key:
				best_key = key
				best = c
		var at: Vector2 = cell.call(best) + Vector2(rng.randf_range(-0.008, 0.008), rng.randf_range(-0.015, 0.015))
		var yaw := rng.randf_range(-0.12, 0.12) + (PI if rng.randf() < 0.5 else 0.0)
		out.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, tops[best], at.y)))
		tops[best] += SIZE.y
	return out


## $20 → 8 bundles, $2K → 56, $200K → 112, $4.5M → 150 (all).
static func bundles(gold: int) -> int:
	return clampi(int(28.0 * log(1.0 + gold / 20.0) / log(10.0)), 0, CAP)


func _show(gold: int) -> void:
	multimesh.visible_instance_count = bundles(gold)
