extends SceneTree
## Headless check for the wishlist reward (scripts/wishlist.gd): the Q workshop shows the small gold
## Deagle beside its line, and gilding turns every surface of the first-person Deagle to gold with
## the glint pass on it. Claiming itself is left out: it opens the store page.
##   Godot.exe --headless --path . -s res://tools/wishlist_check.gd


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await physics_frame
	var menu: Node = main.find_child("UpgradeMenu", true, false)
	var icon := menu.find_children("*", "SubViewportContainer", true, false).filter(
		func(v: Node) -> bool: return v.get_parent().custom_minimum_size == menu.DEAGLE_ICON)
	assert(icon.size() == 1, "the workshop has one small Deagle")
	var shown: Array = icon[0].find_children("*", "MeshInstance3D", true, false).filter(
		func(m: MeshInstance3D) -> bool: return m.visible)
	assert(shown.size() == 1 and _gold(shown[0]), "the small Deagle is gold")
	var gun: Node = root.get_tree().get_first_node_in_group("first_person_gun")
	var deagle: MeshInstance3D = gun._skel.get_node("Deagle")
	assert(not _gold(deagle) or Wishlist.golden(), "the Deagle is plain until claimed")
	gun.gild()
	assert(_gold(deagle), "gilded, every surface of the Deagle is gold")
	print("wishlist_check ok")
	quit()


func _gold(mi: MeshInstance3D) -> bool:
	for i in mi.mesh.get_surface_count():
		var m := mi.get_active_material(i) as StandardMaterial3D
		if not m or not m.next_pass or m.albedo_color != Wishlist.GOLD:
			return false
	return true
