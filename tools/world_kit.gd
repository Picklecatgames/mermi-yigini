extends SceneTree
## The helpers tools/build_world.gd builds the open ground with (add, worn, pbr_box, _prop, block,
## collide, _lighten). They were tools/build_arena.gd's, the old hall's builder; the hall, its
## railing, range and pit went with the open ground (2026-11-02, the user: "Bugüne kadar kurduğumuz
## tüm yapılar gidecek"), these stayed.

const TEX := "res://assets/env/textures/"
const MODELS := "res://assets/env/models/"
const FLOOR_PAINT := 1 << 5  # the floor alone also sits on layer 6; floor decals print only there

var arena: Node3D  # the scene being built (build_world.gd's World)


func add(node: Node, parent: Node = null) -> Node:
	(parent if parent else arena).add_child(node)
	node.owner = arena
	return node


## A Poly Haven set on materials/env/worn_surface.gdshader (no visible repeat: per-cell tone,
## a big turned sample, grime, rust), saved as `save_as`. `params` set its uniforms.
func worn(id: String, save_as: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://materials/env/worn_surface.gdshader")
	m.set_shader_parameter("albedo_tex", load(TEX + "%s/%s_diff_2k.jpg" % [id, id]))
	m.set_shader_parameter("normal_tex", load(TEX + "%s/%s_nor_gl_2k.jpg" % [id, id]))
	m.set_shader_parameter("arm_tex", load(TEX + "%s/%s_arm_2k.jpg" % [id, id]))
	var noise := FastNoiseLite.new()
	noise.seed = save_as.hash() & 0xffff
	noise.frequency = 0.02
	noise.fractal_octaves = 5
	var grime := NoiseTexture2D.new()
	grime.noise = noise
	grime.seamless = true
	grime.width = 512
	grime.height = 512
	m.set_shader_parameter("grime_tex", grime)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	var path := "res://materials/env/%s.tres" % save_as
	ResourceSaver.save(m, path)
	return load(path)


## The same, mapped by position instead of UVs, a texture repeat every `metres`: world-space
## (seamless across separate meshes) or per object (`world` off: every piece starts its own).
func pbr_box(id: String, metres: float, tint := Color.WHITE, world := true, save_as := "") -> ORMMaterial3D:
	var m := ORMMaterial3D.new()
	m.albedo_texture = load(TEX + "%s/%s_diff_2k.jpg" % [id, id])
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX + "%s/%s_nor_gl_2k.jpg" % [id, id])
	m.orm_texture = load(TEX + "%s/%s_arm_2k.jpg" % [id, id])
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_scale = Vector3.ONE / metres
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var path := "res://materials/env/%s.tres" % (save_as if save_as != "" else id)
	ResourceSaver.save(m, path)
	return load(path)


func block(size: Vector3, at: Vector3, mat: Material, parent: Node, basis := Basis()) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.transform = Transform3D(basis, at)
	add(m, parent)
	return m


func collide(size: Vector3, at: Vector3, parent: Node, basis := Basis()) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.transform = Transform3D(basis, at)
	add(cs, parent)


## A model as a static body, its collision one box round its meshes (loose bits left out).
func _prop(parent: Node, path: String, pos: Vector3, yaw: float, s := 1.0, tilt := Basis()) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = Transform3D((Basis(Vector3.UP, yaw) * tilt).scaled(Vector3.ONE * s), pos)
	add(body, parent)
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	# Parts lying wholly under the floor are leftovers (hopper.glb has rounds a physics sim dropped
	# 100 m down): they'd stretch the collision box into a wall over the whole corner.
	_drop_buried(inst, Transform3D())
	add(inst, body)
	var b := _aabb(inst, Transform3D())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = b.size
	cs.shape = box
	cs.position = b.get_center()
	add(cs, body)
	return body


func _drop_buried(n: Node, xf: Transform3D) -> void:
	var t := xf * (n as Node3D).transform if n is Node3D else xf
	for c in n.get_children():
		_drop_buried(c, t)
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (t * (n as MeshInstance3D).mesh.get_aabb()).end.y < -0.5:
		n.free()


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var t := xf * (n as Node3D).transform if n is Node3D else xf
	var out := AABB()
	var empty := true
	# Loose bits (single rounds strewn round hopper.glb) don't count: they made a wall in front of it.
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as MeshInstance3D).mesh.get_aabb().get_longest_axis_size() * t.basis.get_scale().x > 0.15:
		out = t * (n as MeshInstance3D).mesh.get_aabb()
		empty = false
	for c in n.get_children():
		var cb := _aabb(c, t)
		if cb.size != Vector3.ZERO:
			out = cb if empty else out.merge(cb)
			empty = false
	return out


## Small things fade out with distance (and cast no shadow when tiny); small decals and lamps too.
func _lighten(n: Node, parent_xf: Transform3D) -> void:
	var xf := parent_xf * (n as Node3D).transform if n is Node3D else parent_xf
	for c in n.get_children():
		_lighten(c, xf)
	if n is GeometryInstance3D and not n is MultiMeshInstance3D:
		var g := n as GeometryInstance3D
		var size := g.get_aabb().size.length() * xf.basis.get_scale().x
		if size < 0.5:
			g.visibility_range_end = 18.0
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif size < 1.2:
			g.visibility_range_end = 30.0
		elif size < 2.5:
			g.visibility_range_end = 45.0
		if g.visibility_range_end > 0.0:
			g.visibility_range_end_margin = 2.0  # hysteresis: no flicker at the edge
	elif n is Decal:
		var d := n as Decal
		var size := Vector2(d.size.x, d.size.z).length()
		if size < 4.0:
			d.distance_fade_enabled = true
			d.distance_fade_begin = 16.0 if size < 1.5 else 30.0
			d.distance_fade_length = 6.0
	elif n is OmniLight3D and (n as OmniLight3D).omni_range < 3.5:
		var l := n as OmniLight3D
		l.light_volumetric_fog_energy = 0.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 25.0
		l.distance_fade_length = 5.0
