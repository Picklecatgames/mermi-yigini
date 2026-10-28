extends RefCounted
## The Deagle's attachments (GameState UPGRADES laser and holo), placed in the gun bone's space
## (y up, the barrel along +z, the ejection port on -x): the gun in hand (viewmodel.gd) and the
## one on the workshop bench (bench_menu.gd) hang them on the same way.
## Models: the user's downloads, assets/weapons/attachments (docs/ayrintilar.md "Kullanılan asetler").

const LASER := preload("res://assets/weapons/attachments/laser/laser.fbx")
const HOLO := preload("res://assets/weapons/attachments/holo/holo.fbx")
## As imported the laser's lens looks down -x with its rail clamp underneath: turned over, the clamp
## goes up against the frame under the barrel (y -0.022 from z 0.02 on), the lens just short of
## the muzzle (z 0.111).
const LASER_AT := Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(-1, 0, 0)), Vector3(0, -0.018, 0.098))
const LENS := Vector3(0, -0.032, 0.1)  # where the beam leaves
## The holo already looks down +z; it comes at 100 times size (here ~2.9 cm a side; at 3.7 it
## filled the screen aimed). Its glass centred over the slide's top (x -0.001, y 0.027 there),
## its base sitting on it, between the rear sight (z -0.09) and the ejection port.
const HOLO_SCALE := 0.014
const HOLO_AT := Transform3D(Basis(Vector3(HOLO_SCALE, 0, 0), Vector3(0, HOLO_SCALE, 0), Vector3(0, 0, HOLO_SCALE)),
	Vector3(-0.001, 0.027 + 0.4365 * HOLO_SCALE, -0.031))  # 0.4365: the model's base below its origin
const HOLO_TEX := "res://assets/weapons/attachments/holo/holo_"
## The centre of the holo's glass, measured off the model's see-through texels (in its own space),
## in the gun bone's space. Aimed, it sits on the screen centre (viewmodel.gd).
const HOLO_WINDOW := HOLO_AT * Vector3(0.0, 0.65, 0.667)
const RETICLE_SIZE := 0.004  # m across the dot's glow; aimed, its core is ~7 px at 1080p
## The laser has no textures of its own: black polymer, its two side switches red.
const LASER_BODY := Color(0.035, 0.035, 0.038)
const SWITCHES := ["Solid_9", "Solid_5018"]
const BEAM_LENGTH := 1.6  # m, in the hand: it thins out to nothing; the dot is in the world (player.gd)


static func make(id: String) -> Node3D:
	var n: Node3D = (LASER if id == "laser" else HOLO).instantiate()
	n.name = id
	n.transform = LASER_AT if id == "laser" else HOLO_AT
	var body: BaseMaterial3D = _laser_body() if id == "laser" else _holo_skin()
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		m.material_override = _switch() if id == "laser" and m.name in SWITCHES else body
	return n


## A thin red line from the lens along the barrel, fading out: a child for the gun's laser, in its
## space. Unshaded and added on, so it reads in the dark too.
static func beam() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0007
	mesh.bottom_radius = 0.0007
	mesh.height = BEAM_LENGTH
	mesh.radial_segments = 6
	mesh.rings = 1
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;
void fragment() {
	float near = 1.0 - UV.y;  // the cylinder's UV.y runs from the top (far end) down
	ALBEDO = vec3(1.0, 0.08, 0.05) * 1.6;
	ALPHA = pow(near, 3.0) * 0.55;
}"""
	mesh.material = mat
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.name = "beam"
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Along +z from the lens, in the laser's own (turned) space.
	var along := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), LENS + Vector3(0, 0, BEAM_LENGTH / 2.0))
	m.transform = LASER_AT.affine_inverse() * along
	return m


## The holo's lit reticle: only a red dot (the user's call), on its glass, seen from the eye's side only. A child for the gun's holo, in its space.
static func reticle() -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * RETICLE_SIZE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;  // -1..1 across the quad
	float r = length(p);
	float core = smoothstep(0.45, 0.25, r);
	float glow = smoothstep(1.0, 0.0, r) * 0.25;
	ALBEDO = vec3(1.0, 0.07, 0.04) * 2.2;
	ALPHA = clamp(core + glow, 0.0, 1.0);
}"""
	mesh.material = mat
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.name = "reticle"
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Turned to face back (-z, the eye), a hair behind the glass.
	m.transform = HOLO_AT.affine_inverse() * Transform3D(Basis(Vector3.UP, PI), HOLO_WINDOW - Vector3(0, 0, 0.0005))
	return m


static func _laser_body() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = LASER_BODY
	m.roughness = 0.55
	m.metallic = 0.1
	return m


static func _switch() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.0, 0.0)
	m.roughness = 0.08
	m.emission_enabled = true
	m.emission = Color(1.0, 0.1, 0.05)
	m.emission_energy_multiplier = 0.5
	return m


static func _holo_skin() -> ORMMaterial3D:
	var m := ORMMaterial3D.new()
	m.albedo_texture = load(HOLO_TEX + "albedo.png")  # alpha: the model's opacity map (its glass)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.orm_texture = load(HOLO_TEX + "orm.png")
	m.normal_enabled = true
	m.normal_texture = load(HOLO_TEX + "normal.png")
	m.emission_enabled = true
	m.emission_texture = load(HOLO_TEX + "emission.png")
	m.emission_energy_multiplier = 2.0
	return m
