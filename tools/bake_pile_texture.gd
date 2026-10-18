extends SceneTree
## Bakes a tileable top-down "heap of cartridges" texture set from the real bullet mesh:
## albedo, world-space normal (y up) and height. The bullets are poured as rigid bodies and
## settle on each other, so none overlap. Kinematic copies one tile over on every side make
## the tile wrap like a torus, so it repeats seamlessly. Needs a GPU, so run without --headless:
##   Godot.exe --path . --fixed-fps 60 --position -10000,-10000 --resolution 64x64 -s res://tools/bake_pile_texture.gd

const TILE := 0.9          # m covered by one texture tile, at the heap's 3x bullet size
const SIZE := 2048         # px
const COUNT := 1100        # bullets per tile, ~3 layers deep
const MAX_H := 0.09        # m, height that maps to white (settled tiles top out ~0.085)
const POUR_FRAMES := 300
const SETTLE_FRAMES := 300
const OUT := "res://materials/pile_"

const NORMAL_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform int mode;  // 0 normal, 1 height
uniform float max_h;
varying vec3 wn;
varying float wy;
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
void vertex() {
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	vec3 c = mode == 0 ? normalize(wn) * 0.5 + 0.5 : vec3(clamp(wy / max_h, 0.0, 1.0));
	ALBEDO = to_linear(c);  // undo the viewport's linear->sRGB so the PNG holds raw values
}
"""


func _initialize() -> void:
	var Pile: GDScript = load("res://scripts/pile.gd")
	var glb: Node = load("res://assets/bullet/bullet_9mm.glb").instantiate()
	var mesh_inst := glb.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mesh_inst.mesh
	var albedo_mat: BaseMaterial3D = (mesh_inst.get_active_material(0) as BaseMaterial3D).duplicate()
	albedo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glb.free()

	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	await process_frame  # nodes enter the tree on the next frame

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = TILE
	cam.near = 0.01
	cam.far = 1.0
	cam.position = Vector3(TILE * 0.5, 0.5, TILE * 0.5)
	cam.rotation = Vector3(-PI * 0.5, 0.0, 0.0)  # looking down: image x = world +x, image y = world +z
	vp.add_child(cam)

	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	floor_col.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_col)
	vp.add_child(floor_body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bodies: Array[RigidBody3D] = []
	var ghosts: Array[RigidBody3D] = []  # 8 per body, at the neighbouring tiles' offsets
	var offsets: Array[Vector3] = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx != 0 or dz != 0:
				offsets.append(Vector3(dx * TILE, 0.0, dz * TILE))
	var per_frame := ceili(COUNT / float(POUR_FRAMES))
	for i in COUNT:
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var p := Vector3(rng.randf() * TILE, rng.randf_range(0.15, 0.35), rng.randf() * TILE)
		var body: RigidBody3D = Pile.make_body(Transform3D(b, p))
		body.continuous_cd = false
		vp.add_child(body)
		bodies.append(body)
		for o in offsets:
			var g: RigidBody3D = Pile.make_body(Transform3D(b, p + o))
			g.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			g.freeze = true
			vp.add_child(g)
			ghosts.append(g)
		if i % per_frame == per_frame - 1:
			await _step(bodies, ghosts, offsets)
	for f in SETTLE_FRAMES:
		await _step(bodies, ghosts, offsets)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = COUNT * 9  # each bullet plus 8 wrapped copies so the tile repeats seamlessly
	var k := 0
	var top := 0.0
	for body in bodies:
		var t := body.global_transform
		t.origin = Vector3(fposmod(t.origin.x, TILE), t.origin.y, fposmod(t.origin.z, TILE))
		top = maxf(top, t.origin.y)
		for o in offsets + [Vector3.ZERO]:
			mm.set_instance_transform(k, Transform3D(t.basis.scaled(Vector3.ONE * 0.03), t.origin + o))
			k += 1
	print("settled, top bullet at %.3f m (MAX_H %.3f)" % [top, MAX_H])
	for body in bodies + ghosts:
		body.free()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	vp.add_child(mmi)

	var data_mat := ShaderMaterial.new()
	data_mat.shader = Shader.new()
	data_mat.shader.code = NORMAL_SHADER
	data_mat.set_shader_parameter("max_h", MAX_H)

	var passes := [
		["albedo", albedo_mat, Color.BLACK, 0],
		["normal", data_mat, Color(0.214, 1.0, 0.214), 0],  # linear of (0.5, 1, 0.5) = straight up
		["height", data_mat, Color.BLACK, 1],
	]
	for pass_info in passes:
		mmi.material_override = pass_info[1]
		env.background_color = pass_info[2]
		data_mat.set_shader_parameter("mode", pass_info[3])
		for f in 4:
			await process_frame
		var img := vp.get_texture().get_image()
		var path: String = OUT + pass_info[0] + ".png"
		img.save_png(path)
		print("saved ", path)
	quit()


## One physics step with each ghost mirroring its body one tile over. Bodies are never
## teleported back into the tile (a jumping ghost would launch its neighbours); the render
## wraps them instead.
func _step(bodies: Array[RigidBody3D], ghosts: Array[RigidBody3D], offsets: Array[Vector3]) -> void:
	for i in bodies.size():
		var t := bodies[i].global_transform
		for g in offsets.size():
			ghosts[i * offsets.size() + g].global_transform = Transform3D(t.basis, t.origin + offsets[g])
	await physics_frame
