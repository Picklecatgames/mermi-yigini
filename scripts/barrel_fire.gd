extends Node3D
## The fire in the workshop's barrel stove (range_dressing.gd _workshop): charred logs on a bed of
## embers, flames licking up out of the rim, sparks drifting off, a little smoke, its light
## breathing, and a crackle heard only close by. Put at the barrel's foot. Built at load, local
## decoration only, no sync. The flames are an old console's (2026-11-03, the user: Kenney's soft
## particle flames looked new and out of place): n64guy's 32 px "N64 Fire" frames (CC0,
## assets/vfx/fire_n64) stepped on a few quads that face the camera (materials/psx_flipbook.gdshader),
## and the sparks plain square specks. No smoke.

@export var rim := 0.85  # the drum's top (barrel_stove's; range_dressing sets it for the burn barrel)
@export var inner := 0.27  # its inside radius
@export var bed := 0.61  # the coals' height: on the drum's grate
@export var logs := true  # false when the drum's model brings its own burning wood
const LOG := preload("res://assets/env/models/dead_quiver_branch_02/dead_quiver_branch_02_1k.gltf")
const SHEET := preload("res://assets/vfx/fire_n64/round_natural.png")  # 6 x 5 frames of 32 px
const FLIPBOOK := preload("res://materials/psx_flipbook.gdshader")
## The flame quads: [x, z, width, height, frame offset], the middle one tallest.
const FLAMES := [[0.0, 0.0, 0.62, 0.8, 0.0], [-0.13, 0.05, 0.42, 0.55, 11.0], [0.12, -0.06, 0.44, 0.6, 21.0]]
const CRACKLE := preload("res://assets/props/barrel/fire_crackle.ogg")  # reinsamba, Freesound 18766, CC BY 4.0

var _light: OmniLight3D
var _inside: OmniLight3D
var _bed: StandardMaterial3D
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	_noise.frequency = 1.6
	if logs:
		_logs()
	_embers()
	for f: Array in FLAMES:
		_flame(f)
	_sparks()
	_light = OmniLight3D.new()  # the fire's light on the corner, from up in the flames
	# Up in the flames, not on the rim: the drum's lip burned brighter than the fire (the PS1
	# critic). Far enough to give the hands of whoever stands by it a warm edge.
	_light.position = Vector3(0, rim + 0.5, 0)
	_light.light_color = Color(1.0, 0.45, 0.15)
	_light.omni_range = 13.0  # its warmth reaches across the yard: the one warm thing at night
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = false  # from over the rim the drum threw a hard black disc on the floor round itself
	_light.light_volumetric_fog_energy = 0.6
	add_child(_light)
	_inside = OmniLight3D.new()  # the glow inside the drum: lights the logs from under and the rim's inner wall
	_inside.position = Vector3(0, rim - 0.2, 0)
	_inside.light_color = Color(1.0, 0.38, 0.1)
	_inside.omni_range = 0.7
	add_child(_inside)
	var sound := AudioStreamPlayer3D.new()
	var loop := CRACKLE.duplicate() as AudioStreamOggVorbis
	loop.loop = true
	sound.stream = loop
	sound.bus = &"Dunya"
	sound.volume_db = -4.0
	sound.unit_size = 1.2  # soft, and only near the barrel
	sound.max_distance = 9.0
	sound.position = Vector3(0, rim, 0)
	add_child(sound)
	sound.play(randf() * 80.0)


func _process(delta: float) -> void:
	_t += delta
	var n := _noise.get_noise_1d(_t * 10.0) * 0.6 + _noise.get_noise_1d(_t * 37.0) * 0.4  # slow sway and quick flutter
	_light.light_energy = 3.0 + 0.8 * n
	_inside.light_energy = 1.5 + 0.4 * n
	_bed.emission_energy_multiplier = 2.2 + 0.6 * _noise.get_noise_1d(_t * 2.0 + 50.0)


## Three branches crossed over the embers, burnt nearly black, lit orange from under.
func _logs() -> void:
	var burnt := StandardMaterial3D.new()
	burnt.albedo_texture = preload("res://assets/env/models/dead_quiver_branch_02/textures/dead_quiver_branch_02_diff_1k.jpg")
	burnt.albedo_color = Color(0.22, 0.17, 0.14)
	burnt.normal_enabled = true
	burnt.normal_texture = preload("res://assets/env/models/dead_quiver_branch_02/textures/dead_quiver_branch_02_nor_gl_1k.jpg")
	burnt.roughness = 0.95
	for k in 3:
		var piece: Node3D = LOG.instantiate()
		piece.basis = Basis(Vector3.UP, k * TAU / 3.0 + 0.3) * Basis(Vector3.RIGHT, 0.2 if k == 1 else -0.12)
		piece.position = Vector3(0, rim - 0.22 + k * 0.05, 0)
		add_child(piece)
		for m in piece.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = burnt


## A glowing bed of coals under the logs: dark, orange in the cracks, breathing.
func _embers() -> void:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.frequency = 0.04
	var ramp := Gradient.new()  # the cells' edges (cracks between the coals) glow
	ramp.set_color(0, Color(1.0, 0.55, 0.15))
	ramp.set_color(1, Color(0.0, 0.0, 0.0))
	ramp.add_point(0.25, Color(0.6, 0.12, 0.02))
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	noise.noise = fn
	noise.color_ramp = ramp
	_bed = StandardMaterial3D.new()
	_bed.albedo_color = Color(0.05, 0.04, 0.035)
	_bed.roughness = 1.0
	_bed.emission_enabled = true
	_bed.emission = Color.WHITE
	_bed.emission_texture = noise
	var disc := CylinderMesh.new()
	disc.top_radius = inner
	disc.bottom_radius = inner
	disc.height = 0.03
	var coals := MeshInstance3D.new()
	coals.mesh = disc
	coals.material_override = _bed
	coals.position.y = bed
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coals)


func _sprites(tex: Texture2D, add: bool, amount: int, life: float, size: float) -> GPUParticles3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # the PS1 screen: hard-edged sprites, not a blur
	m.proximity_fade_enabled = true  # sprites fade where they cut into the drum and the wood: no hard edges
	m.proximity_fade_distance = 0.12
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = m
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-1, -0.2, -1), Vector3(2, 3, 2))
	p.process_material = ParticleProcessMaterial.new()
	add_child(p)
	return p


func _ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
	g.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return s[1]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## One flame quad standing in the rim, its foot down among the logs.
func _flame(f: Array) -> void:
	var m := ShaderMaterial.new()
	m.shader = FLIPBOOK
	m.set_shader_parameter(&"sheet", SHEET)
	m.set_shader_parameter(&"offset", f[4])
	var quad := QuadMesh.new()
	quad.size = Vector2(f[2], f[3])
	quad.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(f[0], rim - 0.12 + f[3] * 0.5, f[1])
	add_child(mi)


## Sparks: a few bright specks thrown up, wandering on the heat and winking out a metre or two up.
## Square, no texture: a soft round dot was the modern look.
func _sparks() -> void:
	var p := _sprites(null, true, 12, 2.2, 0.035)
	p.position.y = rim
	p.preprocess = 2.0
	p.randomness = 1.0
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = inner * 0.5
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.3
	pm.gravity = Vector3(0, 0.2, 0)
	pm.damping_min = 0.3
	pm.damping_max = 0.8
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.turbulence_noise_scale = 2.5
	pm.turbulence_influence_min = 0.1
	pm.turbulence_influence_max = 0.3
	pm.color_ramp = _ramp([[0.0, Color(1.0, 0.9, 0.6, 1.0)], [0.5, Color(1.0, 0.5, 0.1, 0.9)], [1.0, Color(0.7, 0.1, 0.0, 0.0)]])
