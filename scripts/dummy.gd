extends StaticBody3D
## Training dummy. A hit tips the body on its spring pole away from the shot (and twists it when
## the hit is off-centre), flashes it, squashes it a little and pops the payout over the hole.
## Reacts to GameState.shot_landed, so every peer sees every player's hits.

const PAYOUT_POP := preload("res://scripts/payout_pop.gd")
const SWING := 1.5        # rad/s of tip per m of lever arm: a chest hit tips ~4°, a head hit ~8°
const STIFFNESS := 70.0   # 1/s²: ~1.3 Hz wobble
const DAMPING := 3.2      # 1/s: three or four visible swings, settled in ~1.5 s
const MAX_TIP := 0.25     # rad, so a burst can't fold it over
const SQUASH := 0.06
const POP_HEAD_GAP := 0.12  # m above the top of the body

## Base pay per hit before weak spot and combo (GameState reads it).
@export var hit_gold := 1
## Target kind for the combo's variety cap (GameState): every dummy is one kind.
var kind := &"dummy"

var _tip := Vector3.ZERO  # world-space rotation vector of the body about its pivot
var _tip_vel := Vector3.ZERO
var _squash := 0.0
var _pops: Node3D = PAYOUT_POP.new()

@onready var _upper: MeshInstance3D = $Model.find_child("Upper", true, false)
@onready var _rest := _upper.transform
@onready var _hit_sound: AudioStreamPlayer3D = $HitSound
@onready var _flash := StandardMaterial3D.new()
## Hit shapes above the base swing with the body, so aim, holes and the mesh stay together.
@onready var _swing_shapes: Array[Node] = find_children("*", "CollisionShape3D").filter(
		func(n: Node) -> bool: return n.is_in_group("dummy_swing"))
@onready var _pivot := to_local(_upper.global_position)
var _shape_rest := {}
var _cloth: TriangleMesh  # built on the first hit


func _ready() -> void:
	# Additive and faint: the cloth brightens for a moment, it does not turn into a white cutout.
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash.albedo_color = Color.BLACK
	_upper.material_overlay = _flash
	add_child(_pops)
	GameState.shot_landed.connect(_on_shot_landed)
	for c: CollisionShape3D in _swing_shapes:
		_shape_rest[c] = c.transform


## Where a shot really meets the cloth: the hit boxes are coarse, so the ray is traced again
## against the body mesh itself. Returns [point, normal], or [] when it misses the mesh.
func cloth_hit(at: Vector3, dir: Vector3) -> Array:
	if to_local(at).y <= _pivot.y:
		return []
	if _cloth == null:
		_cloth = _upper.mesh.generate_triangle_mesh()
	var inv := _upper.global_transform.affine_inverse()
	var hit := _cloth.intersect_ray(inv * (at - dir * 0.4), inv.basis * dir)
	if hit.is_empty():
		return []
	var n: Vector3 = (_upper.global_basis.inverse().transposed() * hit.normal).normalized()
	return [_upper.global_transform * hit.position, n if n.dot(dir) < 0.0 else -n]


## Bullet holes go on whatever part was hit: the swinging body, or the fixed base.
func decal_parent(at: Vector3) -> Node3D:
	return _upper if to_local(at).y > _pivot.y else self


func _on_shot_landed(_peer: int, at: Vector3, _normal: Vector3, dir: Vector3, target: Node, gold: int, weak: bool, _combo: int) -> void:
	if target != self:
		return
	var r := at - _upper.global_position
	_tip_vel += r.cross(dir) * SWING
	_squash = SQUASH
	_flash.albedo_color = Color(0.22, 0.2, 0.17)
	if _hit_sound.stream:
		_hit_sound.global_position = at
		_hit_sound.play()
	if gold > 0:
		_pops.pop(gold, above_head(), weak)


## Just over the top of the swinging body, wherever the swing has taken it.
func above_head() -> Vector3:
	var box := _upper.global_transform * _upper.get_aabb()
	return Vector3(box.get_center().x, box.end.y + POP_HEAD_GAP, box.get_center().z)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	for i in 4:  # damped spring, a few explicit steps stay stable at low frame rates
		var h := dt / 4.0
		_tip_vel += (-STIFFNESS * _tip - 2.0 * DAMPING * _tip_vel) * h
		_tip += _tip_vel * h
	if _tip.length() > MAX_TIP:
		_tip = _tip.limit_length(MAX_TIP)
		_tip_vel *= 0.5
	_squash = move_toward(_squash, 0.0, dt * SQUASH / 0.12)
	_flash.albedo_color = _flash.albedo_color.lerp(Color.BLACK, minf(dt * 14.0, 1.0))
	var axis := _upper.get_parent_node_3d().global_basis.inverse() * _tip
	var swing := Basis(axis.normalized(), axis.length()) if axis.length() > 1e-5 else Basis()
	var squash := Basis.from_scale(Vector3(1.0 + _squash * 0.5, 1.0 - _squash, 1.0 + _squash * 0.5))
	_upper.transform = Transform3D(swing * _rest.basis * squash, _rest.origin)
	var local_axis := global_basis.inverse() * _tip
	var turn := Basis(local_axis.normalized(), local_axis.length()) if local_axis.length() > 1e-5 else Basis()
	var about_pivot := Transform3D(turn, _pivot) * Transform3D(Basis(), -_pivot)
	for c: CollisionShape3D in _swing_shapes:
		c.transform = about_pivot * (_shape_rest[c] as Transform3D)
