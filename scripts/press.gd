extends StaticBody3D
## The round press (tools/build_press.py) on the workshop bench's low stand at its hopper end
## (range_dressing.gd _workshop). A main quest opens it (GameState QUESTS `hand_press`): till then
## it isn't there, then it drops in onto the stand.

const Reveal := preload("res://scripts/reveal.gd")


func _ready() -> void:
	add_to_group("press")
	Reveal.hold(self, "hand_press", "Pres")
