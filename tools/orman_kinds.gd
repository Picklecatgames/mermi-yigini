extends RefCounted
## What grows and lies about in the old wood beyond the first pack (2026-11-04, the user: "the trees
## repeat; I don't want to see two alike side by side; more kinds of trees, rocks, rubbish, bones,
## things you'd find in a wood; it's too sterile"). One table for the three tools that need it:
## tools/psx_props.gd orman (the PS1 versions), tools/build_world.gd _wood (what stands where) and
## tools/orman_lineup.gd (to look at them). Sources and licences: docs/ayrintilar.md.

const DIR := "res://assets/env/orman_ek/"
const H := "res://assets/props/hurda/%s_psx.scn"

## The PS1 conversion: [folder, source file, triangles for the whole file, texture px, tint, a floor thing, saturation (optional)].
## Tint: the colour pulled down into the wood's dim range (pale bark, white bones, red caps).
## A floor thing gets no dark foot (shade_below): it lies in the dark foot and would go black.
const BARK := Color(0.62, 0.58, 0.52)
const LEAF := Color(0.8, 0.8, 0.68)
const ROCK := Color(0.9, 0.92, 0.82)
const BONE := Color(0.5, 0.46, 0.36)
const WOOD := Color(0.62, 0.58, 0.52)
const JUNK := Color(0.55, 0.52, 0.46)
const CAP := Color(0.62, 0.55, 0.48)
const CONVERT := [
	# trees
	["psx_dead_pack", "model.glb", 1400, 256, BARK, false],
	["ps1_dead", "model.glb", 300, 128, BARK, false],
	["ps1_birch_pack", "model.glb", 300, 256, LEAF, false],
	["psx_birch", "model.glb", 60, 256, LEAF, false],
	["psx_autumn", "model.glb", 2900, 256, Color(0.56, 0.54, 0.42), false, 0.7],
	["psx_style_trees", "model.glb", 310, 256, LEAF, false],
	["psx_forest_pack", "model.glb", 900, 128, LEAF, false],
	["lowpoly_dead", "model.glb", 1950, 256, BARK, false],
	["dead_tree_max", "model.glb", 1600, 256, BARK, false],
	["dead_flare", "model.glb", 600, 64, Color(0.34, 0.3, 0.26), false],
	["old_tree", "model.glb", 2600, 256, BARK, false],
	["broken_stump", "model.glb", 500, 256, Color(0.38, 0.34, 0.3), true],
	["old_rotten", "model.glb", 460, 256, BARK, true],
	# stumps, logs, roots
	["stump_scan", "model.glb", 500, 256, WOOD, true],
	["tree_stump_01", "tree_stump_01.gltf", 300, 256, WOOD, true],
	["tree_stump_02", "tree_stump_02.gltf", 300, 256, WOOD, true],
	["mossy_log", "model.glb", 350, 256, WOOD, true],
	["old_logs", "model.glb", 310, 128, WOOD, true],
	["dead_tree_trunk", "dead_tree_trunk.gltf", 260, 256, WOOD, true],
	["root_cluster_01", "root_cluster_01.gltf", 450, 256, WOOD, true],
	["root_cluster_02", "root_cluster_02.gltf", 500, 256, WOOD, true],
	["pine_roots", "pine_roots.gltf", 400, 256, WOOD, true],
	["bark_debris_01", "bark_debris_01.gltf", 200, 128, WOOD, true],
	# rocks
	["rock_moss_set_01", "rock_moss_set_01.gltf", 1800, 256, ROCK, true],
	["rock_moss_set_02", "rock_moss_set_02.gltf", 1800, 256, ROCK, true],
	["boulder_01", "boulder_01.gltf", 500, 256, ROCK, true],
	["rock_07", "rock_07.gltf", 160, 128, ROCK, true],
	["rock_09", "rock_09.gltf", 160, 128, ROCK, true],
	["stone_01", "stone_01.gltf", 160, 128, ROCK, true],
	# bones
	["bone_pile", "model.glb", 300, 128, BONE, true],
	["bone_pile2", "model.glb", 700, 128, BONE, true],
	["ribcage", "model.glb", 400, 128, BONE, true],
	["ribcage2", "model.glb", 350, 128, BONE, true],
	["deer_skull", "model.glb", 600, 256, BONE, true],
	["goat_skull", "model.glb", 800, 256, BONE, true],
	["human_skull", "model.glb", 400, 128, BONE, true],
	# mushrooms and low green
	["mushrooms", "model.glb", 400, 64, CAP, true, 0.5],
	["mushroom_set", "model.glb", 2400, 128, CAP, true, 0.4],
	["fern_02", "fern_02.gltf", 6300, 128, LEAF, true],
	["moss_01", "moss_01.gltf", 210, 128, LEAF, true],
	# rubbish
	["can_rusted", "can_rusted.gltf", 50, 64, JUNK, true],
	["metal_trash_can", "metal_trash_can.gltf", 500, 128, JUNK, true],
	["wooden_bucket_01", "wooden_bucket_01.gltf", 200, 128, JUNK, true],
	["rusty_bucket", "model.glb", 250, 128, JUNK, true],
	["plastic_jerrycan", "plastic_jerrycan.gltf", 180, 128, Color(0.34, 0.32, 0.27), true],
	["plastic_bottle_gallon", "plastic_bottle_gallon.gltf", 100, 64, Color(0.34, 0.32, 0.27), true],
	["barrel_03", "barrel_03.gltf", 220, 128, JUNK, true],
	["oil_tin", "oil_tin.gltf", 80, 64, JUNK, true],
	["small_oil_can_01", "small_oil_can_01.gltf", 80, 64, JUNK, true],
	["street_rat", "street_rat.gltf", 150, 64, JUNK, true],
	# the wood's stories (build_world.gd _terk; Poly Haven, CC0)
	["stone_fire_pit", "stone_fire_pit.gltf", 500, 128, ROCK, true],
	["modular_chainlink_fence", "modular_chainlink_fence.gltf", 1200, 128, Color(0.34, 0.31, 0.27), false, 0.5],
	["modular_electricity_poles", "modular_electricity_poles.gltf", 2400, 128, WOOD, false],
	["rubber_boots", "rubber_boots.gltf", 400, 64, JUNK, true],
	["pot_enamel_01", "pot_enamel_01.gltf", 200, 64, JUNK, true],
	["folding_wooden_stool", "folding_wooden_stool.gltf", 300, 128, WOOD, true],
]


## The PS1 scene of a CONVERT folder, or a res:// path as it is (the scrap's).
static func scene(name: String) -> String:
	if name.begins_with("res://"):
		return name
	for c: Array in CONVERT:
		if c[0] == name:
			return DIR + "%s/%s_psx.scn" % [name, String(c[1]).get_basename()]
	push_error("no such kind folder: " + name)
	return ""


## Trees: [folder, mesh nodes (none: all), family, share, height range m, trunk radius m, near].
## A family's members are one silhouette: never neighbours (build_world.gd WOOD_APART). `near`: fine
## to walk up to; false: a whole crown on a few cards, kept 14 m in (WOOD_NEAR_EDGE), like the pack's.
const TREES := [
	["psx_dead_pack", ["Tree 1_Material_001_0"], "dead_a", 0.05, Vector2(11.0, 17.0), 0.35, true],
	["psx_dead_pack", ["Tree2_Material_002_0"], "dead_b", 0.05, Vector2(13.0, 20.0), 0.35, true],
	["psx_dead_pack", ["Tree3_Material_003_0"], "dead_c", 0.05, Vector2(11.0, 17.0), 0.35, true],
	["ps1_dead", [], "dead_d", 0.05, Vector2(9.0, 15.0), 0.3, true],
	["lowpoly_dead", [], "dead_e", 0.05, Vector2(8.0, 13.0), 0.45, true],
	["dead_tree_max", [], "dead_f", 0.05, Vector2(9.0, 15.0), 0.45, true],
	["dead_flare", [], "dead_g", 0.04, Vector2(8.0, 13.0), 0.3, true],
	["old_tree", [], "dead_h", 0.05, Vector2(9.0, 16.0), 0.35, true],
	["broken_stump", [], "snag_a", 0.04, Vector2(2.2, 4.5), 0.3, true],
	["old_rotten", [], "snag_b", 0.03, Vector2(2.5, 4.0), 0.5, true],
	["ps1_birch_pack", ["Tree_Birch_T1_Tree_Birch_0"], "birch_a", 0.05, Vector2(13.0, 21.0), 0.25, false],
	["ps1_birch_pack", ["Tree_Birch_T2_Tree_Birch_0"], "birch_b", 0.05, Vector2(13.0, 21.0), 0.25, false],
	["ps1_birch_pack", ["Tree_Birch_T3_Tree_Birch_0"], "birch_c", 0.05, Vector2(12.0, 19.0), 0.25, false],
	["psx_birch", [], "birch_d", 0.04, Vector2(10.0, 17.0), 0.25, false],
	["psx_autumn", ["Object_12"], "autumn_a", 0.04, Vector2(8.0, 13.0), 0.3, false],
	["psx_autumn", ["Object_14"], "autumn_b", 0.05, Vector2(12.0, 19.0), 0.3, false],
	["psx_style_trees", ["Tree_Tree 1_0", "Bark_Bark_0"], "pine_a", 0.04, Vector2(13.0, 20.0), 0.3, false],
	["psx_style_trees", ["Tree_1_Tree 2_0", "Bark_1_Bark_0"], "pine_b", 0.04, Vector2(12.0, 19.0), 0.35, false],
	# Young ones: a thin stem and a few cards, in among the big trunks.
	["psx_forest_pack", ["Object_50", "Object_52", "Object_54", "Object_56", "Object_58"], "young_a", 0.03, Vector2(3.5, 6.5), 0.1, false],
	["psx_forest_pack", ["Object_60", "Object_62", "Object_64", "Object_66", "Object_68"], "young_b", 0.03, Vector2(3.5, 6.5), 0.1, false],
	["psx_forest_pack", ["Object_70", "Object_72", "Object_74", "Object_76", "Object_78"], "young_c", 0.03, Vector2(3.5, 6.5), 0.1, false],
	["psx_forest_pack", ["Object_80", "Object_82", "Object_84", "Object_86", "Object_88"], "young_d", 0.03, Vector2(3.5, 6.5), 0.1, false],
	["psx_forest_pack", ["Object_90", "Object_92", "Object_94", "Object_96", "Object_98"], "young_e", 0.03, Vector2(3.5, 6.5), 0.1, false],
	["psx_forest_pack", ["Object_100", "Object_102", "Object_104", "Object_106", "Object_108"], "young_f", 0.03, Vector2(3.5, 6.5), 0.1, false],
]

## The floor, by what it is: {group: [[scene, mesh nodes, longest side range m], ...]}. No collision.
const FLOOR := {
	"boulder": [
		["rock_moss_set_01", ["rock_moss_set_01_rock01"], Vector2(1.2, 2.6)], ["rock_moss_set_01", ["rock_moss_set_01_rock02"], Vector2(1.2, 2.6)],
		["rock_moss_set_01", ["rock_moss_set_01_rock03"], Vector2(1.0, 2.2)], ["rock_moss_set_01", ["rock_moss_set_01_rock04"], Vector2(1.2, 2.4)],
		["rock_moss_set_01", ["rock_moss_set_01_rock05"], Vector2(1.2, 2.6)], ["rock_moss_set_01", ["rock_moss_set_01_rock06"], Vector2(1.0, 2.4)],
		["boulder_01", [], Vector2(1.0, 2.0)],
	],
	"rock": [
		["rock_moss_set_02", ["rock_moss_set_02_rock07"], Vector2(0.5, 1.2)], ["rock_moss_set_02", ["rock_moss_set_02_rock08"], Vector2(0.4, 1.0)],
		["rock_moss_set_02", ["rock_moss_set_02_rock09"], Vector2(0.5, 1.2)], ["rock_moss_set_02", ["rock_moss_set_02_rock10"], Vector2(0.5, 1.2)],
		["rock_moss_set_02", ["rock_moss_set_02_rock11"], Vector2(0.5, 1.2)], ["rock_moss_set_02", ["rock_moss_set_02_rock12"], Vector2(0.4, 1.0)],
		["rock_moss_set_02", ["rock_moss_set_02_rock13"], Vector2(0.5, 1.2)],
	],
	"stone": [["rock_07", [], Vector2(0.15, 0.4)], ["rock_09", [], Vector2(0.12, 0.3)], ["stone_01", [], Vector2(0.12, 0.3)]],
	"log": [
		["mossy_log", [], Vector2(2.0, 3.2)], ["dead_tree_trunk", [], Vector2(2.4, 4.0)],
		["old_logs", ["Log 1_low_003_Log 1_low_0"], Vector2(1.2, 2.2)], ["old_logs", ["Log 2_low_006_Log 2_low_0"], Vector2(1.2, 2.2)], ["old_logs", ["Log 3_low_003_Log 3_low_0"], Vector2(1.2, 2.2)],
	],
	"stump": [["tree_stump_01", [], Vector2(1.0, 1.6)], ["tree_stump_02", [], Vector2(1.0, 1.6)], ["stump_scan", [], Vector2(1.0, 1.8)]],
	"root": [["root_cluster_01", [], Vector2(1.8, 3.0)], ["root_cluster_02", ["root_cluster_02_a"], Vector2(1.5, 2.4)], ["pine_roots", ["pine_roots_a"], Vector2(1.2, 2.0)], ["pine_roots", ["pine_roots_b"], Vector2(1.2, 2.0)]],
	"twig": [
		["bark_debris_01", ["bark_debris_01_a"], Vector2(0.4, 0.8)], ["bark_debris_01", ["bark_debris_01_b"], Vector2(0.4, 0.8)],
		["bark_debris_01", ["bark_debris_01_c"], Vector2(0.5, 0.9)], ["bark_debris_01", ["bark_debris_01_d"], Vector2(0.5, 0.9)],
		["root_cluster_02", ["root_cluster_02_b"], Vector2(0.6, 1.2)], ["root_cluster_02", ["root_cluster_02_d"], Vector2(0.6, 1.2)],
		["root_cluster_02", ["root_cluster_02_f"], Vector2(0.7, 1.4)], ["root_cluster_02", ["root_cluster_02_g"], Vector2(0.5, 0.9)],
	],
	"skull": [["deer_skull", [], Vector2(0.35, 0.6)], ["goat_skull", [], Vector2(0.35, 0.55)], ["human_skull", ["Object_3"], Vector2(0.2, 0.26)]],
	"bones": [
		["bone_pile", [], Vector2(0.5, 0.9)], ["ribcage", [], Vector2(0.5, 0.8)], ["ribcage2", [], Vector2(0.5, 0.8)],
		["bone_pile2", ["Object_4"], Vector2(0.3, 0.5)], ["bone_pile2", ["Object_6"], Vector2(0.3, 0.55)], ["bone_pile2", ["Object_8"], Vector2(0.3, 0.5)],
		["bone_pile2", ["Object_10"], Vector2(0.3, 0.5)], ["bone_pile2", ["Object_12"], Vector2(0.3, 0.5)],
	],
	"mushroom": [
		["mushrooms", [], Vector2(0.15, 0.35)],
		["mushroom_set", ["Object_4"], Vector2(0.12, 0.28)], ["mushroom_set", ["Object_6"], Vector2(0.12, 0.3)], ["mushroom_set", ["Object_8"], Vector2(0.08, 0.2)],
		["mushroom_set", ["Object_10"], Vector2(0.12, 0.25)], ["mushroom_set", ["Object_12"], Vector2(0.12, 0.28)], ["mushroom_set", ["Object_16"], Vector2(0.12, 0.25)],
		["mushroom_set", ["Object_20"], Vector2(0.14, 0.3)], ["mushroom_set", ["Object_26"], Vector2(0.1, 0.2)], ["mushroom_set", ["Object_28"], Vector2(0.1, 0.2)],
	],
	"green": [
		["fern_02", ["fern_02_a"], Vector2(0.5, 1.0)], ["fern_02", ["fern_02_d"], Vector2(0.5, 0.9)],
		["psx_forest_pack", ["Object_14", "Object_16", "Object_18", "Object_20"], Vector2(0.7, 1.3)], ["psx_forest_pack", ["Object_22", "Object_24", "Object_26", "Object_28"], Vector2(0.6, 1.1)],
		["psx_autumn", ["Object_8"], Vector2(0.8, 1.5)], ["psx_autumn", ["Object_10"], Vector2(0.8, 1.5)],
	],
	"moss": [
		["moss_01", ["moss_01_a_LOD0"], Vector2(0.2, 0.5)], ["moss_01", ["moss_01_c_LOD0"], Vector2(0.2, 0.5)], ["moss_01", ["moss_01_d_LOD0"], Vector2(0.2, 0.45)],
		["moss_01", ["moss_01_tall_a_LOD0"], Vector2(0.25, 0.5)], ["moss_01", ["moss_01_tall_b_LOD0"], Vector2(0.25, 0.5)],
	],
	"junk": [
		["can_rusted", [], Vector2(0.12, 0.16)], ["wooden_bucket_01", ["wooden_bucket_01", "wooden_bucket_01_handle"], Vector2(0.3, 0.4)],
		["rusty_bucket", [], Vector2(0.3, 0.4)], ["plastic_jerrycan", [], Vector2(0.3, 0.42)], ["plastic_bottle_gallon", [], Vector2(0.22, 0.3)], ["barrel_03", [], Vector2(0.75, 0.95)],
		["metal_trash_can", ["metal_trash_can_rust", "metal_trash_can_rust_handle_left", "metal_trash_can_rust_handle_right"], Vector2(0.8, 0.95)],
		["metal_trash_can", ["metal_trash_can_rust_lid"], Vector2(0.5, 0.6)],
		[H % "dirty_tire_01", [], Vector2(0.55, 0.65)], [H % "dirty_tire_03", [], Vector2(0.55, 0.65)],
		["oil_tin", [], Vector2(0.15, 0.25)], ["small_oil_can_01", [], Vector2(0.18, 0.28)], ["street_rat", [], Vector2(0.22, 0.3)],
	],
}
