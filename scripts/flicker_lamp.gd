extends SpotLight3D
## A failing bulb: mostly on, now and then a burst of quick blinks. Its bulb (sibling `Diffuser`,
## own material) and the light filling its shade (`Diffuser/Fill`) dim with it. Local decoration
## only, no sync.

var _on_energy := 0.0
var _lens: StandardMaterial3D
var _lens_energy := 0.0
var _fill: Light3D
var _fill_energy := 0.0
var _wait := 0.0
var _blinks := 0


func _ready() -> void:
	_on_energy = light_energy
	var bulb := get_parent().get_node("Diffuser") as MeshInstance3D
	_lens = bulb.material_override
	_lens_energy = _lens.emission_energy_multiplier
	_fill = bulb.get_node_or_null("Fill")
	if _fill:
		_fill_energy = _fill.light_energy
	_wait = randf_range(1.0, 4.0)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	if _blinks == 0:
		_blinks = randi_range(2, 7) * 2  # off/on pairs
	_blinks -= 1
	var lit := _blinks % 2 == 0
	light_energy = _on_energy if lit else _on_energy * 0.05
	_lens.emission_energy_multiplier = _lens_energy if lit else 0.1
	if _fill:
		_fill.light_energy = _fill_energy if lit else 0.0
	_wait = randf_range(0.03, 0.12) if _blinks > 0 else randf_range(2.0, 7.0)
