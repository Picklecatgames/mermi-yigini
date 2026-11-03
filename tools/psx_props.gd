extends SceneTree
## The world's props, the workshop's dressing and the scrap as their PS1 horror versions
## (2026-11-02, the user: the whole game in the PSX horror look, not flat "mobile" low poly), each
## next to its source as <name>_psx.scn, as tools/lowpoly_zombie.gd psx does the zombies.
## The scene stays as it was: node names, hierarchy, transforms, collision shapes (bench_top.gd,
## hopper.gd and pile.gd find parts by them). Every mesh gets fewer triangles (meshoptimizer's
## LODs, the one nearest its share of the budget), its unused vertices and tangents dropped. Every
## material becomes materials/psx_prop.gdshader with its base colour shrunk to TEX px and drawn
## unfiltered; normal, roughness and metal maps go. Glowing or see-through materials (hopper.gd and
## barrel_fire.gd tune their emission) stay StandardMaterial3D, made PS1 the same way: lit per
## vertex, unfiltered, small textures.
## tools/build_world.gd (_prop, _cukur) and scripts/pile.gd take the _psx.scn wherever there is one.
##   Godot.exe --headless --path . -s res://tools/psx_props.gd -- [bench workshop hurda cukur ogutucu tex]
## No group: all of them. tex: the workshop's sheet and steel textures (assets/psx/tex/, build_world).

const SHADER := preload("res://materials/psx_prop.gdshader")
const SHADER_2S := preload("res://materials/psx_prop_2s.gdshader")
const M := "res://assets/env/models/%s/%s_1k.gltf"
const TEX_SRC := "res://assets/env/textures/%s/%s_diff_2k.jpg"
const TEX_OUT := "res://assets/psx/tex/%s.res"

## [source, triangles for the whole scene, texture px]
const BENCH := [
	["res://assets/props/workbench/workbench.glb", 4000, 256],
	["res://assets/props/press/press.glb", 1500, 256],
	["res://assets/props/workbench/hopper.glb", 2000, 256],
	["res://assets/props/radio/radio.glb", 800, 256],
	["res://assets/props/wall_lamp/wall_lamp.glb", 1200, 128],
	["res://assets/props/burn_barrel/burn_barrel.glb", 800, 256],
]
const WORKSHOP := [
	["wooden_military_crate", 500, 256], ["steel_frame_shelves_01", 1500, 256], ["metal_tool_chest", 1000, 256],
	["tool_cart", 1200, 256], ["portable_generator", 2000, 256], ["metal_jerrycan", 400, 128],
	["wooden_crate_01", 300, 128], ["small_lpg_tank", 500, 128], ["old_tyre", 600, 128],
	["caged_hanging_light", 1400, 128], ["covered_car", 2500, 256], ["rusted_wheel_rim_01", 500, 128],
	["rusted_wheel_rim_02", 500, 128],
]
const HURDA := "res://assets/props/hurda/hurda.json"
const HURDA_TEX := 128
const CUKUR := "res://assets/props/cukur/"
const OGUTUCU := ["res://assets/props/ogutucu/ogutucu.glb", 3000, 256]
## Workshop sheets and steel (build_world.gd _sheet, _workshop_shed): 128 px over the 2 m they cover.
const SHED_TEX := ["rusty_corrugated_iron", "corrugated_iron_02", "rusted_shutter", "rust_coarse_01"]

var _mats := {}
var _texs := {}
var _sum := [0, 0, 0, 0]  # triangles before, after; bytes before, after


func _init() -> void:
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	var args := OS.get_cmdline_user_args()
	var all := args.is_empty()
	var ok := true
	if all or "tex" in args:
		DirAccess.make_dir_recursive_absolute(TEX_OUT.get_base_dir())
		for id: String in SHED_TEX:
			ok = ResourceSaver.save(_small(load(TEX_SRC % [id, id]), 128), TEX_OUT % id) == OK and ok
	if all or "bench" in args:
		for e: Array in BENCH:
			ok = _convert(e[0], e[1], e[2]) and ok
	if all or "workshop" in args:
		for e: Array in WORKSHOP:
			ok = _convert(M % [e[0], e[0]], e[1], e[2]) and ok
	if all or "ogutucu" in args:
		ok = _convert(OGUTUCU[0], OGUTUCU[1], OGUTUCU[2]) and ok
	if all or "cukur" in args:
		for f in DirAccess.get_files_at(CUKUR):
			if f.get_extension() == "gltf":
				ok = _convert(CUKUR + f, 1000, 128) and ok
	if all or "hurda" in args:
		for p: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(HURDA)):
			var size: Array = p.boyut_m
			var longest: float = size.max()
			ok = _convert(HURDA.get_base_dir().path_join(String(p.glb).get_file()),
					500 if longest > 0.6 else (300 if longest > 0.25 else 200), HURDA_TEX) and ok
	print("psx total: %d -> %d tris, %.1f -> %.1f MB" % [_sum[0], _sum[1], _sum[2] / 1048576.0, _sum[3] / 1048576.0])
	quit(0 if ok else 1)


static func out_path(src: String) -> String:
	return src.get_basename() + "_psx.scn"


func _convert(src: String, budget: int, px: int) -> bool:
	var scene: Node = (load(src) as PackedScene).instantiate()
	scene.scene_file_path = ""  # its own scene, not an instance of the source
	var mis := scene.find_children("*", "MeshInstance3D", true, false)
	var weight := 0.0
	var before := 0
	for mi: MeshInstance3D in mis:
		if mi.mesh:
			before += _tris(mi.mesh)
			weight += pow(_tris(mi.mesh), 0.75)
	var after := 0
	var made := {}
	for mi: MeshInstance3D in mis:
		if mi.mesh == null:
			continue
		if not made.has(mi.mesh):
			var share := maxi(12, int(budget * pow(_tris(mi.mesh), 0.75) / weight))
			made[mi.mesh] = _mesh(mi.mesh, share, px)
		mi.mesh = made[mi.mesh]
		after += _tris(mi.mesh)
		mi.material_override = _material(mi.material_override, px)
		for s in mi.get_surface_override_material_count():
			mi.set_surface_override_material(s, _material(mi.get_surface_override_material(s), px))
	var packed := PackedScene.new()
	var err := packed.pack(scene)
	var out := out_path(src)
	if err == OK:
		err = ResourceSaver.save(packed, out, ResourceSaver.FLAG_COMPRESS)
	scene.free()
	var size_in := _size(src) + (_size(src.get_basename() + ".bin") if src.get_extension() == "gltf" else 0)
	var size_out := _size(out)
	_sum[0] += before
	_sum[1] += after
	_sum[2] += size_in
	_sum[3] += size_out
	print("psx %s: %d -> %d tris, %d -> %d KB%s" % [src.get_file(), before, after, size_in / 1024, size_out / 1024,
			"" if err == OK else " ERROR %d" % err])
	return err == OK


func _mesh(src: Mesh, share: int, px: int) -> Mesh:
	var tris := _tris(src)
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
			for i in idx.size():
				idx[i] = i
			arrays[Mesh.ARRAY_INDEX] = idx
		var skinned: bool = arrays[Mesh.ARRAY_BONES] != null
		if src.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES and not skinned:
			idx = _fewer(arrays, maxi(4, share * (idx.size() / 3) / maxi(1, tris)))
			arrays = _compact(arrays, idx)
		arrays[Mesh.ARRAY_TANGENT] = null  # no normal map
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays)
		var name := (src as ArrayMesh).surface_get_name(s) if src is ArrayMesh else ""
		out.surface_set_name(s, name)
		out.surface_set_material(s, _material(src.surface_get_material(s), px))
	return out


## The LOD nearest `want` triangles, as indices into the surface's own vertices.
func _fewer(arrays: Array, want: int) -> PackedInt32Array:
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if idx.size() / 3 <= want * 1.15 or arrays[Mesh.ARRAY_NORMAL] == null:
		return idx
	if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > idx.size() * 0.8:
		idx = _weld(arrays)  # every triangle its own corners (the coil, the springs): nothing to collapse
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var best := idx
	for l in im.get_surface_lod_count(0):
		var lod := im.get_surface_lod_indices(0, l)
		# the last LODs can drop a lamp to ten triangles: never under 40% of the share
		if lod.size() / 3 >= want * 0.4 and absi(lod.size() / 3 - want) < absi(best.size() / 3 - want):
			best = lod
	# Small things whose LODs stop short (the springs don't simplify at all): corners merged on a
	# grid instead, coarser until it fits. Not on big ones: the grid ate the desk's thin legs.
	var small := AABB()
	for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		small = small.expand(v) if small.size != Vector3.ZERO else AABB(v, Vector3.ONE * 1e-6)
	var cells := 64
	while (small.get_longest_axis_size() < 0.6 or best.size() > idx.size() * 0.6) and best.size() / 3 > want * 2 and cells >= 4:
		best = _cluster(arrays, idx, cells)
		cells /= 2
	return best


## `idx` with the vertices merged per cell of a `cells`-a-side grid over the mesh's box, the
## triangles that collapse dropped.
func _cluster(arrays: Array, idx: PackedInt32Array, cells: int) -> PackedInt32Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var box := AABB(verts[idx[0]], Vector3.ZERO)
	for i in idx:
		box = box.expand(verts[i])
	var step := box.get_longest_axis_size() / cells + 1e-6
	var first := {}
	var to := {}
	for i in idx:
		if to.has(i):
			continue
		var key := Vector3i(((verts[i] - box.position) / step).floor())
		if not first.has(key):
			first[key] = i
		to[i] = first[key]
	var out := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var a: int = to[idx[t]]
		var b: int = to[idx[t + 1]]
		var c: int = to[idx[t + 2]]
		if a != b and b != c and a != c:
			out.append_array([a, b, c])
	return out if out.size() > 0 else idx


## Corners at one spot made one (the first one's UV), smooth normals over them; `arrays` changed.
func _weld(arrays: Array) -> PackedInt32Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var first := {}
	var to := PackedInt32Array()
	to.resize(verts.size())
	for i in verts.size():
		var key := verts[i].snapped(Vector3.ONE * 1e-5)
		if not first.has(key):
			first[key] = i
		to[i] = first[key]
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for t in range(0, idx.size(), 3):
		var a := to[idx[t]]
		var b := to[idx[t + 1]]
		var c := to[idx[t + 2]]
		idx[t] = a
		idx[t + 1] = b
		idx[t + 2] = c
		var n := (verts[c] - verts[a]).cross(verts[b] - verts[a])  # Godot winds clockwise
		normals[a] += n
		normals[b] += n
		normals[c] += n
	var old: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var agree := 0.0
	for i in normals.size():
		normals[i] = normals[i].normalized() if normals[i] != Vector3.ZERO else Vector3.UP
		agree += normals[i].dot(old[i]) if to[i] == i else 0.0
	if agree < 0.0:  # wound the other way round
		for i in normals.size():
			normals[i] = -normals[i]
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	return idx


## The arrays with only the vertices `idx` uses, `idx` renumbered; tangents and custom channels go.
func _compact(arrays: Array, idx: PackedInt32Array) -> Array:
	var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var remap := PackedInt32Array()
	remap.resize(count)
	remap.fill(-1)
	var order := PackedInt32Array()
	var new_idx := PackedInt32Array()
	new_idx.resize(idx.size())
	for i in idx.size():
		var v := idx[i]
		if remap[v] < 0:
			remap[v] = order.size()
			order.append(v)
		new_idx[i] = remap[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arrays[k] == null:
			continue
		var src = arrays[k]
		var dst = src.duplicate()
		dst.resize(order.size())
		for j in order.size():
			dst[j] = src[order[j]]
		out[k] = dst
	out[Mesh.ARRAY_INDEX] = new_idx
	return out


func _material(m: Material, px: int) -> Material:
	if m == null or not m is BaseMaterial3D:
		return m
	if _mats.has(m):
		return _mats[m]
	var b := m as BaseMaterial3D
	var out: Material
	var blend := b.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]
	if b.emission_enabled or blend:
		var c := b.duplicate() as BaseMaterial3D
		c.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		c.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		c.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		c.normal_enabled = false
		c.normal_texture = null
		c.roughness = 1.0
		c.roughness_texture = null
		c.metallic = 0.0
		c.metallic_texture = null
		c.ao_enabled = false
		if c is ORMMaterial3D:
			(c as ORMMaterial3D).orm_texture = null
		c.albedo_texture = _small(b.albedo_texture, px, false)
		c.emission_texture = _small(b.emission_texture, px, false)
		out = c
	else:
		var sm := ShaderMaterial.new()
		sm.shader = SHADER_2S if b.cull_mode == BaseMaterial3D.CULL_DISABLED else SHADER
		if b.albedo_texture:
			sm.set_shader_parameter("albedo_tex", _small(b.albedo_texture, px))
		sm.set_shader_parameter("tint", b.albedo_color)
		if b.uv1_scale != Vector3.ONE or b.uv1_offset != Vector3.ZERO:
			sm.set_shader_parameter("uv_scale", Vector2(b.uv1_scale.x, b.uv1_scale.y))
			sm.set_shader_parameter("uv_offset", Vector2(b.uv1_offset.x, b.uv1_offset.y))
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			sm.set_shader_parameter("alpha_cut", b.alpha_scissor_threshold if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.5)
		out = sm
	_mats[m] = out
	return out


## `tex` no bigger than `px` on its long side, WebP inside the scene (raw for a StandardMaterial3D:
## a WebP texture drew the caged lamp magenta there).
func _small(tex: Texture2D, px: int, webp := true) -> Texture2D:
	if tex == null:
		return null
	var key := [tex, px, webp]
	if _texs.has(key):
		return _texs[key]
	var img: Image = tex.get_image().duplicate()
	img.decompress()
	img.clear_mipmaps()
	var w := img.get_width()
	var h := img.get_height()
	if maxi(w, h) > px:
		var k := float(px) / maxi(w, h)
		img.resize(maxi(1, roundi(w * k)), maxi(1, roundi(h * k)), Image.INTERPOLATE_LANCZOS)
	var out: Texture2D = ImageTexture.create_from_image(img)
	if webp:
		out = PortableCompressedTexture2D.new()
		(out as PortableCompressedTexture2D).create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, false, 0.85)
	_texs[key] = out
	return out


static func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var i: int = mesh.surface_get_array_index_len(s)
		n += (i if i > 0 else mesh.surface_get_array_len(s)) / 3
	return n


static func _size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else 0
