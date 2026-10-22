extends SceneTree
## Headless check for the HUD's layout (scripts/hud.gd): it covers the whole window however the
## window is resized, its corners stay in the corners, and past 1080p it grows with the screen.
## (It once froze at the window's starting size and sat in the top left of a full screen.)
##   Godot.exe --headless --path . -s res://tools/hud_check.gd

func _initialize() -> void:
	var screen := SubViewport.new()  # the headless window won't resize; a SubViewport stands in
	screen.size = Vector2i(1152, 648)
	root.add_child(screen)
	var hud: Control = load("res://scripts/hud.gd").new()
	screen.add_child(hud)
	for s: Vector2i in [Vector2i(1152, 648), Vector2i(2560, 1440), Vector2i(1280, 720), Vector2i(3840, 2160)]:
		screen.size = s
		await process_frame
		await process_frame
		var k := hud.scale.x
		assert(is_equal_approx(k, maxf(1.0, s.y / 1080.0)), "scale %.2f at %s" % [k, s])
		assert((hud.size * k).is_equal_approx(Vector2(s)), "covers %s, got %s" % [s, hud.size * k])
		var gold: Control = hud._gold.get_parent().get_parent()
		var right_gap := s.x - (gold.position.x + gold.size.x) * k
		assert(absf(right_gap - hud.MARGIN.x * k) < 2.0, "gold sits on the right edge at %s (gap %.0f)" % [s, right_gap])
		var heap: Control = hud._heap.get_parent()
		var mid := (heap.position.x + heap.size.x * 0.5) * k
		assert(absf(mid - s.x * 0.5) < 2.0, "heap is centred at %s (%.0f)" % [s, mid])
		print("%s ok  scale %.2f" % [s, k])
	print("hud_check ok")
	quit()
