extends Node3D
## A rotating warning beacon's lamp pair (tools/hall_dressing.gd _beacon). Local decoration only.

@export var turns_per_second := 0.55


func _process(delta: float) -> void:
	rotate_y(TAU * turns_per_second * delta)
