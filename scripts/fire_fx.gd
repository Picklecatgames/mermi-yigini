extends RefCounted
## Fire for the burning targets, from Kenney's particle sprites (assets/vfx/fire, CC0): a looping
## flame with its own flickering light (a scarecrow), and a one-shot fireball with smoke (a barrel).

const FLAME := preload("res://assets/vfx/fire/flame_01.png")
const FIRE := preload("res://assets/vfx/fire/fire_01.png")
const SMOKE := preload("res://assets/vfx/fire/smoke_04.png")
const ORANGE := Color(1.0, 0.55, 0.15)


static func _sprites(parent: Node3D, tex: Texture2D, glow: bool, amount: int, life: float, size: float) -> GPUParticles3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if glow else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = m
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = ParticleProcessMaterial.new()
	parent.add_child(p)
	return p


static func _fade(from: Color, to: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, Color(to, 0.0))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _shrink() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.2))
	var t := CurveTexture.new()
	t.curve = c
	return t


## Flames licking up a box of `extents` round the parent's origin. Off until `burn(p, true)`.
static func flames(parent: Node3D, extents: Vector3) -> GPUParticles3D:
	var p := _sprites(parent, FLAME, true, 56, 0.8, 0.75)
	p.emitting = false
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.gravity = Vector3(0, 2.2, 0)
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.angle_min = -20.0
	pm.angle_max = 20.0
	pm.scale_curve = _shrink()
	pm.color_ramp = _fade(Color(1.0, 0.5, 0.1), Color(0.8, 0.08, 0.0))
	var smoke := _sprites(p, SMOKE, false, 10, 1.8, 0.8)
	smoke.position.y = extents.y
	var sm := smoke.process_material as ParticleProcessMaterial
	sm.gravity = Vector3(0, 1.2, 0)
	sm.spread = 20.0
	sm.direction = Vector3.UP
	sm.initial_velocity_min = 0.3
	sm.initial_velocity_max = 0.6
	sm.color_ramp = _fade(Color(0.12, 0.11, 0.1, 0.5), Color(0.2, 0.2, 0.2))
	sm.scale_curve = _shrink()
	smoke.emitting = false
	var light := OmniLight3D.new()
	light.light_color = ORANGE
	light.omni_range = 4.0
	light.light_energy = 0.0
	p.add_child(light)
	p.set_meta("light", light)
	p.set_meta("smoke", smoke)
	return p


static func burn(p: GPUParticles3D, on: bool) -> void:
	p.emitting = on
	(p.get_meta("smoke") as GPUParticles3D).emitting = on
	if not on:
		(p.get_meta("light") as OmniLight3D).light_energy = 0.0


## Each frame while burning: the light flickers.
static func flicker(p: GPUParticles3D) -> void:
	if p.emitting:
		(p.get_meta("light") as OmniLight3D).light_energy = randf_range(1.2, 2.2)


## A fireball, with smoke and a flash, ready to go off with `boom()`.
static func fireball(parent: Node3D) -> GPUParticles3D:
	var p := _sprites(parent, FIRE, true, 32, 0.7, 1.1)
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.damping_min = 6.0
	pm.damping_max = 9.0
	pm.gravity = Vector3(0, 1.5, 0)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_curve = _shrink()
	pm.color_ramp = _fade(Color(1.0, 0.85, 0.5), Color(0.8, 0.1, 0.02))
	var smoke := _sprites(p, SMOKE, false, 18, 2.6, 1.6)
	smoke.one_shot = true
	smoke.explosiveness = 0.8
	smoke.emitting = false
	var sm := smoke.process_material as ParticleProcessMaterial
	sm.direction = Vector3.UP
	sm.spread = 70.0
	sm.initial_velocity_min = 1.0
	sm.initial_velocity_max = 2.5
	sm.damping_min = 1.0
	sm.damping_max = 2.0
	sm.gravity = Vector3(0, 0.6, 0)
	sm.color_ramp = _fade(Color(0.1, 0.09, 0.08, 0.7), Color(0.25, 0.25, 0.25))
	sm.scale_curve = _shrink()
	var light := OmniLight3D.new()
	light.light_color = ORANGE
	light.omni_range = 9.0
	light.light_energy = 0.0
	p.add_child(light)
	p.set_meta("light", light)
	p.set_meta("smoke", smoke)
	return p


static func boom(p: GPUParticles3D) -> void:
	p.restart()
	(p.get_meta("smoke") as GPUParticles3D).restart()
	var light: OmniLight3D = p.get_meta("light")
	light.light_energy = 8.0
	p.create_tween().tween_property(light, "light_energy", 0.0, 0.5).set_ease(Tween.EASE_OUT)
