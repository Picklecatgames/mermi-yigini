extends Node
## Headless check for how often shell drops clink (scripts/viewmodel.gd `_shell_audible`):
## a lone shot always does, inside a burst one in every 10-15 does.
##   Godot.exe --headless --path . res://tools/shell_tink_check.tscn

func _ready() -> void:
	var vm: Node = load("res://scripts/viewmodel.gd").new()
	assert(vm._shell_audible(), "a lone shot clinks")
	var gaps: Array[int] = []
	var since := 0
	for i in 300:  # one long burst, no pause between shells
		since += 1
		if vm._shell_audible():
			gaps.append(since)
			since = 0
	assert(gaps.size() >= 300 / 15 and gaps.size() <= 300 / 10, "clinks in a burst: %d" % gaps.size())
	for g in gaps:
		assert(g >= 10 and g <= 15, "gap %d" % g)
	vm._last_eject_ms -= 2000  # a pause longer than TINK_GAP
	assert(vm._shell_audible(), "the first shot after a pause clinks")
	print("shell_tink_check OK: %d clinks in 300 burst shells" % gaps.size())
	vm.free()
	get_tree().quit()
