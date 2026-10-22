extends StaticBody3D
## Pendulum: the dummy's body hangs on a chain from a steel frame and swings side to side on its
## own. A hit pays by how fast it is going: MIN_GOLD at the ends of the swing, MAX_GOLD through the
## bottom, so it pays to time the shot. The head is the weak spot. Faces +Z.
## Co-op: the swing runs on its own clock everywhere; the host sends its phase now and then
## (GameState.cue_target, [&"phase", p]) and a client runs it on by the network delay.

const PAYOUT_POP := preload("res://scripts/payout_pop.gd")
const DUMMY := preload("res://assets/props/dummy/dummy.glb")
const HIT_SOUND := preload("res://assets/props/dummy/sounds/hit.tres")
const PIVOT_Y := 3.1    # m
const CHAIN := 0.55     # m from the pivot to the head
const BODY := 1.5       # m: the dummy body's height (assets/props/dummy, Upper)
const AMP := 0.6        # rad
const PERIOD := 2.6     # s
const POST_X := 2.0     # m
const MIN_GOLD := 2
const MAX_GOLD := 8
const SYNC_EVERY := 1.0  # s

## Base pay, what a blast next to it counts (barrel_target.gd); a hit pays hit_gold_at.
var hit_gold := MIN_GOLD
var kind := &"pendulum"

var _phase := 0.0
var _sync := 0.0
var _swing := Node3D.new()  # turns about the pivot
var _upper: MeshInstance3D
var _shapes := {}  # CollisionShape3D -> its place on the swing
var _pops: Node3D = PAYOUT_POP.new()
var _hit := AudioStreamPlayer3D.new()


func _ready() -> void:
	add_to_group("target")
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.3, 0.31, 0.33)
	steel.metallic = 0.85
	steel.roughness = 0.5
	var frame := StaticBody3D.new()
	frame.name = "Frame"  # a fixed name: shot_landed finds it by path on every peer
	frame.add_to_group("steel")
	add_child(frame)
	for part: Array in [[Vector3(-POST_X, PIVOT_Y / 2, 0), Vector3(0.1, PIVOT_Y, 0.1)],
			[Vector3(POST_X, PIVOT_Y / 2, 0), Vector3(0.1, PIVOT_Y, 0.1)],
			[Vector3(0, PIVOT_Y + 0.05, 0), Vector3(POST_X * 2 + 0.1, 0.1, 0.1)],
			[Vector3(-POST_X, 0.03, 0), Vector3(0.5, 0.06, 0.6)],
			[Vector3(POST_X, 0.03, 0), Vector3(0.5, 0.06, 0.6)]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[1]
		mesh.mesh = box
		mesh.material_override = steel
		mesh.position = part[0]
		frame.add_child(mesh)
		var c := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = part[1]
		c.shape = shape
		c.position = part[0]
		frame.add_child(c)
	_swing.position = Vector3(0, PIVOT_Y, 0)
	add_child(_swing)
	var chain := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.012
	rod.bottom_radius = 0.012
	rod.height = CHAIN
	chain.mesh = rod
	chain.material_override = steel
	chain.position.y = -CHAIN / 2
	_swing.add_child(chain)
	var dummy: Node3D = DUMMY.instantiate()
	_upper = dummy.get_node("Upper")
	dummy.remove_child(_upper)
	dummy.free()
	_upper.position.y = -CHAIN - BODY
	_swing.add_child(_upper)
	# Hit boxes as on scenes/dummy.tscn, in the body's own space.
	for s: Array in [[Vector3(0, 0.67, 0), _box(Vector3(0.42, 0.97, 0.3)), false],
			[Vector3(0, 0.99, 0), _box(Vector3(0.94, 0.25, 0.3)), false],
			[Vector3(0, 1.32, 0), _head(), true]]:
		var c := CollisionShape3D.new()
		c.shape = s[1]
		if s[2]:
			c.add_to_group("weak_spot")
		add_child(c)
		_shapes[c] = s[0]
	_hit.stream = HIT_SOUND
	_hit.volume_db = 4.0
	_hit.unit_size = 4.0
	_hit.max_polyphony = 3
	add_child(_hit)
	add_child(_pops)
	GameState.shot_landed.connect(_on_shot_landed)
	GameState.target_cue.connect(_on_cue)
	_place()


static func _box(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


static func _head() -> CapsuleShape3D:
	var c := CapsuleShape3D.new()
	c.radius = 0.15
	c.height = 0.44
	return c


## 0 at the ends of the swing, 1 through the bottom.
func speed() -> float:
	return absf(cos(_phase))


func hit_gold_at(_at: Vector3) -> int:
	return roundi(lerpf(MIN_GOLD, MAX_GOLD, speed() * speed()))


## Impacts: burlap puffs where the hit box was struck, holes ride on the body.
func cloth_hit(_at: Vector3, _dir: Vector3) -> Array:
	return []


func decal_parent(_at: Vector3) -> Node3D:
	return _upper


func above_head() -> Vector3:
	return _upper.global_transform * Vector3(0, BODY + 0.15, 0)


func _on_shot_landed(peer: int, at: Vector3, _n: Vector3, _d: Vector3, target: Node, gold: int, weak: bool, _combo: int) -> void:
	if target != self:
		return
	_hit.global_position = at
	_hit.play()
	if gold > 0:
		_pops.pop(gold, above_head(), weak, peer)


func join_cues() -> Array:
	return [[&"phase", _phase]]


func _on_cue(target: Node, cue: Array) -> void:
	if target == self and Net.is_client:
		_phase = fmod(cue[1] + TAU / PERIOD * Net.latency(), TAU)


func _process(delta: float) -> void:
	_phase = fmod(_phase + TAU / PERIOD * delta, TAU)
	if not Net.is_client:
		_sync -= delta
		if _sync <= 0.0:
			_sync = SYNC_EVERY
			GameState.cue_target(self, [&"phase", _phase])
	_place()


func _place() -> void:
	_swing.rotation.z = AMP * sin(_phase)
	for c: CollisionShape3D in _shapes:
		c.transform = global_transform.affine_inverse() * _upper.global_transform * Transform3D(Basis(), _shapes[c])
