extends Node3D
## Runs its first child (a target) back and forth along a floor rail on local Z, slowing into
## each end like a winch reversing. The rail is built in code.

@export var length := 7.0  # m of travel
@export var speed := 1.6   # m/s at the middle

var _phase := 0.0
var _rider: Node3D


func _ready() -> void:
	_rider = get_child(0)
	var steel: Material = load("res://materials/env/metal_plate_02.tres")
	var run := length + 1.2
	for x in [-0.22, 0.22]:
		_box(Vector3(0.05, 0.05, run), Vector3(x, 0.025, 0), steel)
	for i in int(run / 0.6) + 1:  # sleepers
		_box(Vector3(0.62, 0.025, 0.1), Vector3(0, 0.0125, -run / 2.0 + i * 0.6), steel)
	_rider.position.y = 0.05


func _box(size: Vector3, at: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at
	add_child(m)


func _physics_process(delta: float) -> void:
	_phase = fmod(_phase + delta * speed / (length / 2.0), TAU)
	_rider.position.z = sin(_phase) * length / 2.0
