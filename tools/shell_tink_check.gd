extends SceneTree
## Headless check for how often shell drops clink (scripts/viewmodel.gd `_shell_audible`):
## a lone shot always does, inside a burst one in every 10-15 does.
##   Godot.exe --headless --path . -s res://tools/shell_tink_check.gd

func _initialize() -> void:
	var vm: Node = load("res://scripts/viewmodel.gd").new()
	var bad: Array[String] = []
	if not vm._shell_audible():
		bad.append("a lone shot clinks")
	var gaps: Array[int] = []
	var since := 0
	for i in 300:  # one long burst, no pause between shells
		since += 1
		if vm._shell_audible():
			gaps.append(since)
			since = 0
	if gaps.size() < 300 / 15 or gaps.size() > 300 / 10:
		bad.append("clinks in a burst: %d" % gaps.size())
	for g in gaps:
		if g < 10 or g > 15:
			bad.append("gap %d" % g)
	vm._last_eject_ms -= 2000  # a pause longer than TINK_GAP
	if not vm._shell_audible():
		bad.append("the first shot after a pause clinks")
	vm.free()
	if bad.is_empty():
		print("shell_tink_check OK: %d clinks in 300 burst shells" % gaps.size())
	else:
		print("shell_tink_check FAILED: ", ", ".join(bad))
	quit(0 if bad.is_empty() else 1)
