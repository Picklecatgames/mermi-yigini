extends Node3D
## Bank shot: a steel plate turned 45° throws a round sideways (group "ricochet", GameState
## request_fire) onto a popper hidden behind a low concrete wall, which pays RICOCHET_MULT times
## over when the round reached it that way. Faces +Z: the plate stands left, the popper right,
## the wall shields it from the firing line. The ricochet round (yol haritası 17) will bounce on.

const POPPER := preload("res://scenes/popper_target.tscn")
const CONCRETE := preload("res://materials/concrete.tres")
const HIT_SOUND := preload("res://assets/props/steel_targets/sounds/heavy.tres")
const KIT := preload("res://scripts/target_kit.gd")

var _plate: StaticBody3D
var _ring: AudioStreamPlayer3D


func _ready() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.57, 0.6)
	steel.metallic = 0.9
	steel.roughness = 0.3
	_plate = _block("Plate", Vector3(0.7, 0.7, 0.03), Vector3(-1.0, 0.55, 0), steel)
	_plate.rotation.y = PI / 4
	_plate.add_to_group("ricochet")
	_block("Post", Vector3(0.08, 0.2, 0.08), Vector3(-1.0, 0.1, 0), steel)
	_block("Wall", Vector3(2.4, 1.5, 0.25), Vector3(1.5, 0.75, 0.85), CONCRETE)
	var popper: Node3D = POPPER.instantiate()
	popper.name = "Popper"
	popper.position = Vector3(2.0, 0, 0)
	popper.rotation.y = -PI / 2  # faces the plate
	add_child(popper)
	_ring = KIT.sound(self, HIT_SOUND)
	GameState.shot_landed.connect(_on_shot_landed)


func _on_shot_landed(_p: int, at: Vector3, _n: Vector3, _d: Vector3, target: Node, _g: int, _w: bool, _c: int) -> void:
	if target == _plate:
		KIT.play(_ring, at)


func _block(name_: String, size: Vector3, at: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_  # a fixed name: shot_landed finds it by path on every peer
	if mat != CONCRETE:
		body.add_to_group("steel")
	body.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	c.shape = shape
	body.add_child(c)
	add_child(body)
	return body
