extends Node3D
## Steel targets from the Steel Targets Pack: a static mount with plates hanging on a bar or pegs
## (`tools/build_steel_targets.py` puts each "Plate*" node's origin on its hinge). Every plate is a
## pendulum: a hit adds angular momentum from the bullet's push and its lever arm round the hinge,
## so a low hit swings harder than a high one, a hit above the hinge (a silhouette's head) swings it
## the other way, and an off-centre hit twists it. Nothing caps the swing: a light plate hit again
## while it is still swinging back goes right over the bar.

const PAYOUT_POP := preload("res://scripts/payout_pop.gd")
const GRAVITY := 9.8
const SUBSTEPS := 4

## Base pay per hit before combo (GameState reads it from the plate).
@export var hit_gold := 2
## kg of each plate: the heavier, the less a hit moves it.
@export var plate_mass := 2.0
## N·s one round pushes with. A game value, not the real one, tuned so light plates flip.
@export var kick := 1.5
## How freely a plate turns about the vertical: 1 on a single tab, low on two hooks or pegs,
## 0 when it is welded to its hinge and only swings back and forth.
@export var twist := 1.0
@export var hit_sound: AudioStream
## Short ring-shake of a plate right after a hit; off for plates welded to a rack.
@export var shiver := true


func _ready() -> void:
	for n in find_children("Mount*", "MeshInstance3D"):
		n.create_trimesh_collision()  # rounds spark off the frame instead of passing through
		n.get_child(0).add_to_group("steel")
	for n in find_children("Plate*", "MeshInstance3D"):
		Plate.new().setup(self, n)


class Plate extends StaticBody3D:
	const AIR := 0.35        # 1/s
	const FRICTION := 0.8    # rad/s² of hinge drag, lets a swing come to rest
	const TWIST_K := 40.0    # 1/s²: hooks pulling a twisted plate back square, ~1 Hz
	const SHIVER := 0.003    # m of ring right after a hit
	const SHIVER_TIME := 0.25

	var hit_gold := 2
	var kind: StringName  # so GameState can tell targets apart: one per target scene, all its plates alike
	var _target: Node3D
	var _rest: Transform3D  # hinge in the target's space
	var _com := 0.0         # m from the hinge down to the centre of mass
	var _inertia := 1.0     # kg·m² about the hinge
	var _inertia_y := 1.0   # kg·m² about the vertical
	var _mass := 1.0
	var _kick := 1.0
	var _twist_free := 1.0
	var _swing := 0.0
	var _swing_vel := 0.0
	var _twist := 0.0
	var _twist_vel := 0.0
	var _shiver := 0.0
	var _top := 0.0
	var _sound := AudioStreamPlayer3D.new()
	var _pops: Node3D = PAYOUT_POP.new()

	func setup(target: Node3D, mesh: MeshInstance3D) -> void:
		_target = target
		hit_gold = target.hit_gold
		kind = StringName(target.scene_file_path.get_file().get_basename())
		_mass = target.plate_mass
		_kick = target.kick
		_twist_free = target.twist
		name = mesh.name
		_rest = target.global_transform.affine_inverse() * mesh.global_transform
		var box := mesh.get_aabb()
		_com = -box.get_center().y
		_top = box.end.y
		# a flat plate: parallel axis from its own centre out to the hinge
		_inertia = _mass * (_com * _com + box.size.y * box.size.y / 12.0)
		_inertia_y = _mass * box.size.x * box.size.x / 12.0
		mesh.get_parent().remove_child(mesh)
		mesh.transform = Transform3D.IDENTITY
		add_child(mesh)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_convex_shape()
		add_child(shape)
		_sound.stream = target.hit_sound
		_sound.volume_db = 4.0
		_sound.unit_size = 4.0  # dry and falling off: a far plate sounds far
		_sound.attenuation_filter_db = 0.0
		_sound.max_polyphony = 3
		add_child(_sound)
		add_child(_pops)
		add_to_group("target")
		add_to_group("steel")
		target.add_child(self)
		transform = _rest
		GameState.shot_landed.connect(_on_shot_landed)

	## Lead splashes stay on the plate as it swings.
	func decal_parent(_at: Vector3) -> Node3D:
		return self

	func above_head() -> Vector3:
		return _target.global_transform * (_rest.origin + Vector3(0, _top + 0.2, 0))

	func _on_shot_landed(peer: int, at: Vector3, _n: Vector3, dir: Vector3, target: Node, gold: int, weak: bool, _combo: int) -> void:
		if target != self:
			return
		# torque of the push about the hinge, in the plate's own axes (x along the bar)
		var p := global_transform.affine_inverse() * at
		var j := global_basis.inverse() * dir.normalized() * _kick
		var torque := p.cross(j)
		_swing_vel += torque.x / _inertia
		_twist_vel += torque.y / _inertia_y * _twist_free
		_shiver = 1.0 if _target.shiver else 0.0
		if _sound.stream:
			_sound.global_position = at
			_sound.play()
		if gold > 0:
			_pops.pop(gold, above_head(), weak, peer)

	func _physics_process(delta: float) -> void:
		var h := delta / SUBSTEPS
		for i in SUBSTEPS:  # a few explicit steps stay stable through a fast flip
			var acc := -_mass * GRAVITY * _com / _inertia * sin(_swing) - AIR * _swing_vel
			_swing_vel = move_toward(_swing_vel + acc * h, 0.0, FRICTION * h)
			_swing = wrapf(_swing + _swing_vel * h, -PI, PI)
			_twist_vel += (-TWIST_K * _twist - 3.0 * _twist_vel) * h
			_twist += _twist_vel * h
		_shiver = move_toward(_shiver, 0.0, delta / SHIVER_TIME)
		var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * SHIVER * _shiver
		transform = Transform3D(_rest.basis * Basis(Vector3.UP, _twist) * Basis(Vector3.RIGHT, _swing), _rest.origin + _rest.basis * jitter)
