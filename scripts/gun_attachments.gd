extends RefCounted
## The Deagle's attachment (GameState UPGRADES laser), placed in the gun bone's space
## (y up, the barrel along +z, the ejection port on -x): the gun in hand (viewmodel.gd) and the
## one on the workshop bench (bench_menu.gd) hang it on the same way.
## Model: the user's download, assets/weapons/attachments (docs/ayrintilar.md "Kullanılan asetler").

const LASER := preload("res://assets/weapons/attachments/laser/laser.fbx")
## As imported the laser's lens looks down -x with its rail clamp underneath: turned over, the clamp
## goes up against the frame under the barrel (y -0.022 from z 0.02 on), the lens just short of
## the muzzle (z 0.111).
const LASER_AT := Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(-1, 0, 0)), Vector3(0, -0.018, 0.098))
const LENS := Vector3(0, -0.032, 0.1)  # where the beam leaves (player.gd draws it in the world)
## The laser has no textures of its own: black polymer, its two side switches red.
const LASER_BODY := Color(0.035, 0.035, 0.038)
const SWITCHES := ["Solid_9", "Solid_5018"]
const PSX := preload("res://materials/psx.gdshader")


static func make(id: String) -> Node3D:
	var n: Node3D = LASER.instantiate()
	n.name = id
	n.transform = LASER_AT
	var body := _laser_body()
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		m.material_override = _switch() if m.name in SWITCHES else body
	return n


## The PS1 look as the guns have it (tools/psx_import.gd): lit per vertex, no texture to keep.
static func _laser_body() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PSX
	m.set_shader_parameter("tint", LASER_BODY)
	return m


static func _switch() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.0, 0.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.emission_enabled = true
	m.emission = Color(1.0, 0.1, 0.05)
	m.emission_energy_multiplier = 0.5
	return m

