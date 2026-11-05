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
##   Godot.exe --headless --path . -s res://tools/psx_props.gd -- [house bench workshop hurda cukur ogutucu tex orman orman_ek]
## No group: all of them. tex: the workshop's sheet and steel textures (assets/psx/tex/, build_world).

const SHADER := preload("res://materials/psx_prop.gdshader")
const SHADER_2S := preload("res://materials/psx_prop_2s.gdshader")
const SHADER_SOFT := preload("res://materials/psx_prop_soft.gdshader")
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
## The house (tools/build_house.py) and what stands only in it; its inside's textures (build_world.gd _house).
const HOUSE := [["res://assets/props/house/house.glb", 5000, 256, 0.62], ["res://assets/props/house/wing.glb", 2500, 256, 0.62],
	["res://assets/props/house/wood_stove.glb", 1500, 256], ["res://assets/props/house/wood_pile.glb", 400, 128],
	["res://assets/props/house/old_rug.glb", 300, 128, 0.7],
	[M % ["old_bed_frame", "old_bed_frame"], 1800, 256, 0.5],
	[M % ["lightbulb_01", "lightbulb_01"], 200, 64],
	[M % ["pull_chain_light_socket", "pull_chain_light_socket"], 600, 128],
	[M % ["Lantern_01", "Lantern_01"], 600, 128],
	[M % ["vintage_oil_lamp", "vintage_oil_lamp"], 600, 128],
	[M % ["WoodenTable_01", "WoodenTable_01"], 600, 128],
	[M % ["WoodenChair_01", "WoodenChair_01"], 600, 128],
	[M % ["wooden_stool_01", "wooden_stool_01"], 600, 128],
	[M % ["painted_wooden_cabinet", "painted_wooden_cabinet"], 1200, 256, 0.5],
	[M % ["wooden_bookshelf_worn", "wooden_bookshelf_worn"], 1400, 256, 0.5],
	[M % ["painted_wooden_nightstand", "painted_wooden_nightstand"], 600, 128, 0.5],
	[M % ["wooden_bucket_01", "wooden_bucket_01"], 600, 128],
	[M % ["wicker_basket_01", "wicker_basket_01"], 600, 128],
	[M % ["rubber_boots", "rubber_boots"], 600, 128],
	[M % ["hatchet", "hatchet"], 600, 128],
	[M % ["tree_stump_01", "tree_stump_01"], 900, 128],
	[M % ["vintage_suitcase", "vintage_suitcase"], 600, 128, 0.5],
	[M % ["pot_enamel_01", "pot_enamel_01"], 600, 128],
	[M % ["russian_food_cans_01", "russian_food_cans_01"], 600, 128],
	[M % ["wooden_broom", "wooden_broom"], 600, 128],
	[M % ["wall_clock", "wall_clock"], 600, 128, 0.5],
	[M % ["street_rat", "street_rat"], 800, 128],
	[M % ["mousetrap", "mousetrap"], 600, 128],
	[M % ["cement_bag", "cement_bag"], 600, 128, 0.5],
	[M % ["Television_01", "Television_01"], 1400, 256],
	[M % ["sofa_02", "sofa_02"], 1500, 256, 0.5],
	[M % ["old_gas_mask", "old_gas_mask"], 600, 128],
	[M % ["clipboard", "clipboard"], 600, 128]]
const HOUSE_TEX := ["raw_plank_wall", "old_wood_floor", "rough_pine_door", "clay_plaster"]
const HURDA := "res://assets/props/hurda/hurda.json"
const HURDA_TEX := 64  # 2026-11-03, the user: hundreds of small pieces boiled at 270p
## Pieces go over to their average colour this far away (m; materials/psx_prop.gdshaderinc far_fade).
const FAR := Vector2(20.0, 60.0)
const HURDA_FAR := Vector2(6.0, 22.0)
## The scrap's far colours go most of the way to one shared rust: in the distance the heap is a
## few close browns, not a mosaic of blue tins and red rust.
const HURDA_RUST := Color(0.42, 0.3, 0.24)
const HURDA_RUST_SHARE := 0.8
## The scrap's colours (2026-11-03, the user: "the heap tires the eyes"; thousands of tins, gears and
## pipes each its own colour crawled at 270p): every scrap texture is pulled into one narrow, dim
## rust-dirt-grey range, so the heap reads as one scrap texture. Its brightness squeezed into
## GRADE_LIGHT, its own colour kept GRADE_OWN of the way (the rest the rust ramp's), that at
## GRADE_SATURATION of its saturation.
const GRADE_DARK := Color(0.13, 0.095, 0.075)
const GRADE_BRIGHT := Color(0.5, 0.38, 0.3)
const GRADE_LIGHT := Vector2(0.15, 0.6)
const GRADE_OWN := 0.3
const GRADE_SATURATION := 0.35
## Wires, chains, cage bars thinner than this (m) are blown up to it along their normals: at 270p a
## thinner one is under a pixel from a few metres and sparkles (2026-11-03, the user). Plates and
## cards (one way facing) stay as they are.
const MIN_THICK := 0.02
const CUKUR := "res://assets/props/cukur/"
const OGUTUCU := ["res://assets/props/ogutucu/ogutucu.glb", 3000, 256]
## Workshop sheets and steel (build_world.gd _sheet, _workshop_shed): 128 px over the 2 m they cover.
const SHED_TEX := ["rust_coarse_01", "metal_plate_02"]
## The ground's (build_world.gd: the desert's sand, cracked earth and gravel, the yard's concrete
## and kerb; 2026-11-03, the user: "the surfaces are bad"): 128 px over their 3-6 m repeat, in the
## desert's colours (NATURE_*), no normal or roughness map (flat_arm stands in).
const GROUND_TEX := ["gravelly_sand", "mud_cracked_dry_03", "sandy_gravel_02", "dirty_concrete", "concrete_slab_wall"]
const GROUND_SATURATION := 0.9
const GROUND_VALUE := 0.82
## The desert's trees, bushes and rocks (Poly Haven's Namaqualand set; 2026-11-03, the user: the
## trees are bad, find PS1 ones, keep the desert's own kinds): [folder, triangles for the whole file
## (every LOD node in it shares them), texture px]. A PS1 tree is a few hundred triangles and its
## leaves are cut out, not blended: the scans' see-through leaves become alpha-cut cards here.
const NAMA := "res://assets/env/namaqualand/%s/%s_1k.gltf"
## A fourth number, where there is one, darkens the texture: the quiver trees' and dead trunks'
## pale bark stood out of the dust as white poles (2026-11-03, the PS1 critic).
const NATURE := [
	["quiver_tree_01", 1400, 128, 0.6], ["quiver_tree_02", 800, 128, 0.6], ["searsia_burchellii", 2400, 128],
	["dead_quiver_trunk", 400, 128, 0.5], ["dead_tree_trunk_02", 500, 128, 0.65], ["dry_branches_medium_01", 600, 64],
	["wild_rooibos_bush", 1200, 64], ["namaqualand_boulder_02", 300, 128], ["namaqualand_boulder_04", 300, 128],
	["namaqualand_boulder_05", 300, 128], ["namaqualand_rocks_01", 400, 64], ["namaqualand_stones_01", 400, 64],
]
## Their colours (the user, 2026-11-03: the scrap's sand-rust-dirt family): saturation down to
## NATURE_SATURATION, then NATURE_DUST of the way to the dust (build_world.gd's fog by day), so the
## green of the leaves goes olive-grey and the red rock dull, all of one desert.
const NATURE_SATURATION := 0.5
## The old, half-dead wood (2026-11-04, the user: not a desert, an old slightly dead forest, these
## models): [file, triangles, texture px]. The pack's trees are 40-340 triangles already and share
## one atlas, so it keeps its triangles and gets a bigger texture; the two scans come down to a
## PS1 tree. Their colours: less of a pull towards the dust than the desert's, an olive one.
const ORMAN := [["res://assets/env/orman/forest_pack.glb", 4000, 1024], ["res://assets/env/orman/cypress.glb", 3000, 512], ["res://assets/env/orman/cherry.glb", 4000, 512]]
const ORMAN_GROUND := ["forest_leaves_04", "mud_forest", "forest_ground_04"]  # the wood's floor, 128 px like the rest of the ground
const ORMAN_VALUE := 0.95  # darker: up close, out of the dark fog, the pale bark went white (2026-11-04, the user)
const ORMAN_GAMMA := 1.1
const ORMAN_SATURATION := 1.0
const ORMAN_DUST := Color(0.36, 0.36, 0.2)
const ORMAN_DUST_SHARE := 0.05
## Under the canopy it's dark (2026-11-04, the user: more unknown, as if something's there): from
## this height (m in the world) down to the ground a tree goes to this share of its light.
const ORMAN_SHADE := Vector2(9.0, 0.42)
const ORMAN_BARK := Color(0.55, 0.52, 0.48)  # dark bark, leaves kept lit: too dark a leaf goes flat in 15-bit colour
const ORMAN_ROCK := Color(0.5, 0.52, 0.42)  # the pack's pale stones stood out of the floor white
const NATURE_DUST := Color(0.5, 0.42, 0.31)
const NATURE_DUST_SHARE := 0.22

var _mats := {}
var _texs := {}
var _sum := [0, 0, 0, 0]  # triangles before, after; bytes before, after
var _far := FAR
var _rust_share := 0.0
var _grade := false  # scrap: textures into the rust range (GRADE_*)
var _nature := false  # trees and rocks: leaves cut out, textures into the desert's range (NATURE_*)
var _ground := false  # the ground's textures: the desert's range, GROUND_*
var _orman := false  # nature, in the old wood's colours (ORMAN_*)
var _tint := Color.WHITE  # the wood's added kinds: this file's colour (tools/orman_kinds.gd)
var _floor := false  # ...and it lies on the floor: no dark foot
var _sat := ORMAN_SATURATION  # ...and how much of its colour stays
var _value := 1.0  # nature: the entry's darkening (NATURE's fourth number)
var _dim := 1.0  # the house: its bright weathered boards and sheet were pale as snow in the low sun
var _thickened := 0  # parts blown up in this scene (_thicken)
var _avg := {}  # small texture: its average colour


func _init() -> void:
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	var args := OS.get_cmdline_user_args()
	var all := args.is_empty()
	var ok := true
	if all or "tex" in args:
		DirAccess.make_dir_recursive_absolute(TEX_OUT.get_base_dir())
		for id: String in SHED_TEX:
			ok = ResourceSaver.save(_small(load(TEX_SRC % [id, id]), 128), TEX_OUT % id) == OK and ok
		_nature = true
		_ground = true
		for id: String in GROUND_TEX:  # raw, not WebP: the kerb is a StandardMaterial3D, and WebP drew it white there
			ok = ResourceSaver.save(_small(load(TEX_SRC % [id, id]), 128, false), TEX_OUT % id) == OK and ok
		_nature = false
		_ground = false
		var flat := Image.create(4, 4, false, Image.FORMAT_RGB8)
		flat.fill(Color(1.0, 1.0, 0.0))  # ambient 1, rough 1, metal 0
		ok = ResourceSaver.save(ImageTexture.create_from_image(flat), TEX_OUT % "flat_arm") == OK and ok
	if all or "house" in args:
		for id: String in HOUSE_TEX:
			ok = ResourceSaver.save(_small(load(TEX_SRC % [id, id]), 128), TEX_OUT % id) == OK and ok
		for e: Array in HOUSE:
			_dim = e[3] if e.size() > 3 else 1.0
			ok = _convert(e[0], e[1], e[2]) and ok
		_dim = 1.0
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
	if all or "nature" in args:
		_nature = true
		for e: Array in NATURE:
			_value = e[3] if e.size() > 3 else 1.0
			ok = _convert(NAMA % [e[0], e[0]], e[1], e[2]) and ok
		_value = 1.0
		_nature = false
	if all or "orman" in args:
		_nature = true
		_orman = true
		for id: String in ORMAN_GROUND:
			ok = ResourceSaver.save(_small(load(TEX_SRC % [id, id]), 128, false), TEX_OUT % id) == OK and ok
		for e: Array in ORMAN:
			ok = _convert(e[0], e[1], e[2]) and ok
		ok = _orman_ek() and ok
		_orman = false
		_nature = false
	if "orman_ek" in args:  # only the wood's added kinds (tools/orman_kinds.gd)
		_nature = true
		_orman = true
		ok = _orman_ek() and ok
		_orman = false
		_nature = false
	if all or "hurda" in args:
		_far = HURDA_FAR
		_rust_share = HURDA_RUST_SHARE
		_grade = true
		for p: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(HURDA)):
			var size: Array = p.boyut_m
			var longest: float = size.max()
			ok = _convert(HURDA.get_base_dir().path_join(String(p.glb).get_file()),
					500 if longest > 0.6 else (300 if longest > 0.25 else 200), HURDA_TEX) and ok
	print("psx total: %d -> %d tris, %.1f -> %.1f MB" % [_sum[0], _sum[1], _sum[2] / 1048576.0, _sum[3] / 1048576.0])
	quit(0 if ok else 1)


func _orman_ek() -> bool:
	var ok := true
	for e: Array in preload("res://tools/orman_kinds.gd").CONVERT:
		_tint = e[4]
		_floor = e[5]
		_sat = e[6] if e.size() > 6 else ORMAN_SATURATION
		ok = _convert("%s%s/%s" % [preload("res://tools/orman_kinds.gd").DIR, e[0], e[1]], e[2], e[3]) and ok
	_tint = Color.WHITE
	_floor = false
	_sat = ORMAN_SATURATION
	return ok


static func out_path(src: String) -> String:
	return src.get_basename() + "_psx.scn"


func _convert(src: String, budget: int, px: int) -> bool:
	_thickened = 0
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
	print("psx %s: %d -> %d tris, %d -> %d KB, %d thin parts thickened%s" % [src.get_file(), before, after, size_in / 1024, size_out / 1024, _thickened,
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
			var want := maxi(4, share * (idx.size() / 3) / maxi(1, tris))
			var bm := src.surface_get_material(s) as BaseMaterial3D
			var leaves := _nature and bm != null and bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			if leaves:
				# Leaves and twigs: never through the LOD, which crushed the quiver tree's rosettes
				# to slivers; whole cards thinned out instead.
				idx = _sparse(arrays, idx, want)
			else:
				idx = _fewer(arrays, want)
				if _orman:
					# A scan in one skin stays whole: corners merged on a grid. Thinned card by
					# card (below) the cherry came apart into floating shreds.
					var cells := 96
					while idx.size() / 3 > want * 1.5 and cells >= 8:
						idx = _cluster(arrays, arrays[Mesh.ARRAY_INDEX], cells)
						cells = int(cells * 0.8)
				elif _nature and idx.size() / 3 > want * 1.5:
					idx = _sparse(arrays, idx, want)
			arrays = _compact(arrays, idx)
			if leaves:
				# Lit as one crown, not card by card: lit per vertex from both sides, the cards
				# facing away from the sun drew black (the thorn tree a cloud of black shards).
				var up := PackedVector3Array()
				up.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
				up.fill(Vector3.UP)
				arrays[Mesh.ARRAY_NORMAL] = up
			_thicken(arrays)
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


## Leaves and twigs as cards LODs can't merge (the thorn tree's thousands): whole cards kept at
## random, about `want` triangles' worth, each kept one grown about its middle so the crown stays
## as full; `arrays`' vertices moved. A PS1 tree's crown was a handful of big cards.
func _sparse(arrays: Array, idx: PackedInt32Array, want: int) -> PackedInt32Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	for i in parent.size():
		parent[i] = i
	for t in range(0, idx.size(), 3):
		for k in [1, 2]:
			var a := _root(parent, idx[t])
			var b := _root(parent, idx[t + k])
			if a != b:
				parent[b] = a
	var cards := {}  # root -> triangle starts
	for t in range(0, idx.size(), 3):
		var r := _root(parent, idx[t])
		if not cards.has(r):
			cards[r] = []
		cards[r].append(t)
	var keep := clampf(float(want) / (idx.size() / 3), 0.05, 1.0)
	var grow := minf(1.0 / sqrt(keep), 1.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = idx.size()
	var out := PackedInt32Array()
	for r: int in cards:
		if rng.randf() > keep:
			continue
		var tris: Array = cards[r]
		var mid := Vector3.ZERO
		var seen := {}
		for t: int in tris:
			for k in 3:
				seen[idx[t + k]] = true
		for v: int in seen:
			mid += verts[v] / seen.size()
		for v: int in seen:
			verts[v] = mid + (verts[v] - mid) * grow
		for t: int in tris:
			out.append_array([idx[t], idx[t + 1], idx[t + 2]])
	arrays[Mesh.ARRAY_VERTEX] = verts
	if out.is_empty():
		out = idx  # one big joined piece, and the dice dropped it: thinned below, not kept whole
	if out.size() / 3 > want * 1.5:
		# Cards joined into a few big pieces (the thorn tree's leaves along their twigs): thinned
		# triangle by triangle then, each kept leaf a ragged triangle, PS1 enough.
		var thin := PackedInt32Array()
		var k := float(want) / (out.size() / 3)
		for t in range(0, out.size(), 3):
			if rng.randf() <= k:
				thin.append_array([out[t], out[t + 1], out[t + 2]])
		out = thin
	return out if out.size() > 0 else idx


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
	if b.emission_enabled or (blend and not _nature):
		var c := b.duplicate() as BaseMaterial3D
		c.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		c.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		c.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
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
		sm.shader = SHADER_SOFT if _orman else (SHADER_2S if b.cull_mode == BaseMaterial3D.CULL_DISABLED else SHADER)
		if b.albedo_texture:
			var tex := b.albedo_texture
			if _nature and b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				tex = _keyed_once(tex)
			sm.set_shader_parameter("albedo_tex", _small(tex, px))
		sm.set_shader_parameter("tint", _graded(b.albedo_color) if _grade else (b.albedo_color * ORMAN_ROCK if _orman and b.resource_name == "Rocks" else (b.albedo_color * ORMAN_BARK if _orman and b.resource_name.contains("Trunk") else b.albedo_color)))
		var avg: Color = _avg.get(sm.get_shader_parameter("albedo_tex"), Color.WHITE) * b.albedo_color
		avg = avg.lerp(HURDA_RUST, _rust_share)
		avg.a = 1.0
		sm.set_shader_parameter("far_colour", avg)
		sm.set_shader_parameter("far_fade", _far)
		if _orman:
			# No flat far colour: from 20 m it turned whole trees to one dark blob that came alive
			# only as you walked up. Each copy's tone in COLOR (build_world.gd _forest).
			sm.set_shader_parameter("far_colour", Color(0, 0, 0, 0))
			sm.set_shader_parameter("vertex_tint", true)
			if _tint != Color.WHITE:
				sm.set_shader_parameter("tint", b.albedo_color * _tint)
			if b.resource_name != "Rocks" and not _floor:
				sm.set_shader_parameter("shade_below", ORMAN_SHADE)
		if b.uv1_scale != Vector3.ONE or b.uv1_offset != Vector3.ZERO:
			sm.set_shader_parameter("uv_scale", Vector2(b.uv1_scale.x, b.uv1_scale.y))
			sm.set_shader_parameter("uv_offset", Vector2(b.uv1_offset.x, b.uv1_offset.y))
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			# Leaves 0.3: at 0.5 their 128 px, mipmapped alpha cut most of a crown away
			sm.set_shader_parameter("alpha_cut", b.alpha_scissor_threshold if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else (0.3 if _nature else 0.5))
		out = sm
	_mats[m] = out
	return out


var _keyed := {}


func _keyed_once(tex: Texture2D) -> Texture2D:
	if not _keyed.has(tex):
		_keyed[tex] = keyed(tex)
	return _keyed[tex]


## `tex` no bigger than `px` on its long side, mipmapped, WebP inside the scene (raw for a StandardMaterial3D:
## a WebP texture drew the caged lamp magenta there).
func _small(tex: Texture2D, px: int, webp := true) -> Texture2D:
	if tex == null:
		return null
	var key := [tex, px, webp, _grade, _nature, _ground, _value, _orman, _sat, _dim]
	if _texs.has(key):
		return _texs[key]
	var img: Image = tex.get_image().duplicate()
	img.decompress()
	img.clear_mipmaps()
	if _orman:
		_bleed(img)
	var w := img.get_width()
	var h := img.get_height()
	if maxi(w, h) > px:
		var k := float(px) / maxi(w, h)
		img.resize(maxi(1, roundi(w * k)), maxi(1, roundi(h * k)), Image.INTERPOLATE_LANCZOS)
	if _grade or _nature:
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, _graded(c, true) if _grade else (_old_wood(c) if _orman else (_desert(c, GROUND_SATURATION, GROUND_VALUE) if _ground else _desert(c, NATURE_SATURATION, _value))))
	if _dim < 1.0:
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * _dim, c.g * _dim, c.b * _dim, c.a))
	img.generate_mipmaps()
	var last := img.duplicate() as Image
	last.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	var out: Texture2D = ImageTexture.create_from_image(img)
	if webp:
		out = PortableCompressedTexture2D.new()
		(out as PortableCompressedTexture2D).create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, false, 0.85)
	_texs[key] = out
	_avg[out] = last.get_pixel(0, 0)
	return out


## The colour under a texture's cut-out pixels made its leaves' average: they're black in these
## files, and every smaller size and mip then drew each leaf with a dark rim.
static func _bleed(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				sum += c
				n += 1
	if n == 0 or n == img.get_width() * img.get_height():
		return
	var avg := Color(sum.r / n, sum.g / n, sum.b / n)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.5:
				img.set_pixel(x, y, Color(avg.r, avg.g, avg.b, c.a))


static func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var i: int = mesh.surface_get_array_index_len(s)
		n += (i if i > 0 else mesh.surface_get_array_len(s)) / 3
	return n


static func _size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else 0


## Thin closed parts of the surface (wires, chains, cage bars, rails) blown up to MIN_THICK: each
## part's thickness is 4 V / A (a tube's diameter, a plate's twice its thickness); plates and cards,
## whose faces mostly look one way, are left alone. Corners at one spot move together, no cracks.
func _thicken(arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if normals == null or idx.is_empty():
		return
	var spot := {}
	var at := PackedInt32Array()
	at.resize(verts.size())
	for i in verts.size():
		var k := verts[i].snapped(Vector3.ONE * 1e-4)
		if not spot.has(k):
			spot[k] = spot.size()
		at[i] = spot[k]
	var parent := PackedInt32Array()
	parent.resize(spot.size())
	for i in parent.size():
		parent[i] = i
	for t in range(0, idx.size(), 3):
		var a := _root(parent, at[idx[t]])
		parent[_root(parent, at[idx[t + 1]])] = a
		parent[_root(parent, at[idx[t + 2]])] = a
	var parts := {}  # root: [area, volume, normal spread (Basis as a 3x3)]
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var b := verts[idx[t + 1]]
		var c := verts[idx[t + 2]]
		var n := (b - a).cross(c - a)
		var area := n.length() * 0.5
		if area < 1e-12:
			continue
		n = n.normalized()
		var r := _root(parent, at[idx[t]])
		if not parts.has(r):
			parts[r] = [0.0, 0.0, Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)]
		var e: Array = parts[r]
		e[0] += area
		e[1] += a.dot(b.cross(c)) / 6.0
		var m: Basis = e[2]
		e[2] = Basis(m.x + n * n.x * area, m.y + n * n.y * area, m.z + n * n.z * area)
	var grow := {}
	for r in parts:
		var e: Array = parts[r]
		var thick: float = absf(e[1]) * 4.0 / e[0]
		if thick >= MIN_THICK or thick < 1e-4:
			continue
		var m: Basis = e[2]
		var v := Vector3(0.58, 0.57, 0.59)
		for i in 8:
			v = (m * v).normalized()
		if v.dot(m * v) / e[0] > 0.7:
			continue  # a plate
		grow[r] = (MIN_THICK - thick) * 0.5
	_thickened += grow.size()
	if grow.is_empty():
		return
	var push := {}
	for i in verts.size():
		if grow.has(_root(parent, at[i])):
			push[at[i]] = push.get(at[i], Vector3.ZERO) + (normals[i] as Vector3)
	for i in verts.size():
		var r := _root(parent, at[i])
		if grow.has(r):
			verts[i] += (push[at[i]] as Vector3).normalized() * grow[r]
	arrays[Mesh.ARRAY_VERTEX] = verts


static func _root(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


## A leaf atlas with its black ground made see-through: the Namaqualand scans' glTFs point their
## see-through leaves at a JPG, no alpha, the leaves on black, so every leaf card drew as a black
## square, the scans' too (2026-11-03: "the trees are bad"). Darker than KEY_BLACK is clear.
const KEY_BLACK := 0.05


static func keyed(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image().duplicate()
	img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			c.a = minf(c.a, smoothstep(KEY_BLACK, KEY_BLACK * 2.0, maxf(c.r, maxf(c.g, c.b))))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## `c` in the old wood's range (ORMAN_*).
func _old_wood(c: Color) -> Color:
	var grey := c.get_luminance()
	var out := Color(grey, grey, grey).lerp(c, _sat)
	out = out.lerp(ORMAN_DUST * (grey / maxf(ORMAN_DUST.get_luminance(), 0.02)), ORMAN_DUST_SHARE)
	out = Color(pow(out.r, ORMAN_GAMMA), pow(out.g, ORMAN_GAMMA), pow(out.b, ORMAN_GAMMA)) * ORMAN_VALUE
	out.a = c.a
	return out


## `c` in the desert's range (NATURE_*).
## The ground keeps more of its own colour and goes a little darker (GROUND_*): graded like the
## plants, the sand and the concrete came out a washed-out grey-white under the dusty sky.
static func _desert(c: Color, saturation := NATURE_SATURATION, value := 1.0) -> Color:
	var grey := c.get_luminance()
	var out := Color(grey, grey, grey).lerp(c, saturation)
	out = out.lerp(NATURE_DUST * (grey / maxf(NATURE_DUST.get_luminance(), 0.02)), NATURE_DUST_SHARE)
	out = out * value
	out.a = c.a
	return out


## `c` in the scrap's rust range (GRADE_*); a tint (`texel` false) only loses saturation, the
## texture does the rest.
static func _graded(c: Color, texel := false) -> Color:
	var grey := c.get_luminance()
	var own := Color(grey, grey, grey, c.a).lerp(c, GRADE_SATURATION)
	if not texel:
		return own
	var l := lerpf(GRADE_LIGHT.x, GRADE_LIGHT.y, grey)
	var ramp := GRADE_DARK.lerp(GRADE_BRIGHT, l)
	var out := ramp.lerp(own * (l / maxf(grey, 0.02)), GRADE_OWN)
	out.a = c.a
	return out
