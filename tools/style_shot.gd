extends SceneTree
## Every style rank tier on the real HUD, saved as PNGs: one in the middle of the tier up's slam
## and one settled, then one melting down:
##   Godot.exe --path . --position -10000,-10000 --resolution 1280x720 -s res://tools/style_shot.gd

func _initialize() -> void:
	var StyleRank: GDScript = load("res://scripts/style_rank.gd")  # after the autoloads
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	await _frames(10)
	gs.request_take_pistol()
	var rank: Control
	for n in root.find_children("*", "Control", true, false):
		if n.get_script() == StyleRank:
			rank = n
	assert(rank, "the HUD has a style rank")
	for t in StyleRank.TIERS.size():
		rank.points = t * StyleRank.TIER_SIZE + 70.0
		rank._since = 0.0
		await _shot("%d_%s_slam" % [t, StyleRank.TIERS[t]], 4)
		rank._since = 0.0
		await _shot("%d_%s" % [t, StyleRank.TIERS[t]], 50)
	rank.points = 4 * StyleRank.TIER_SIZE + 2.0  # about to drop from S to A
	rank._since = StyleRank.GRACE
	await _shot("melt", 20)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name_: String, wait: int) -> void:
	await _frames(wait)
	var path := "user://style_%s.png" % name_
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
