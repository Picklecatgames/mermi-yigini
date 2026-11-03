extends SpotLight3D
## A head lamp (2026-11-03, the user: "Yes, a head lamp", after the PS1 critic found the open
## desert at night unplayable in the dark): a warm, narrow beam from the eyes where the head looks,
## every player's, the remote ones' too. It lights itself when the world's sun goes down and goes
## out at dawn, easing; the day and night cycle (to come) needs to do nothing for it. Each machine
## decides it alike from its own sun, so there is nothing to sync.
## player.gd hangs it on its camera; remote_players.gd places the others' at their eyes each frame.

const ENERGY := 6.0
const EASE := 1.5  # 1/s
const DUSK := 0.3  # the sun under this share of its daytime energy: night

var lit := 0.0  # 0 off .. 1 on, eased; player.gd lights the hands from it
var _sun: DirectionalLight3D
var _day := 0.0
var _look_again := 0.0  # s till the next search for a sun: a scene with none (the checks) must not search the tree every frame


func _init() -> void:
	light_color = Color(1.0, 0.92, 0.78)  # an old bulb, warm
	spot_range = 22.0
	spot_angle = 28.0
	spot_angle_attenuation = 0.6
	spot_attenuation = 0.7  # reaches ~15 m before it fades
	shadow_enabled = true
	light_volumetric_fog_energy = 0.0
	light_energy = 0.0
	visible = false


func _process(delta: float) -> void:
	if _sun == null or not is_instance_valid(_sun):
		_look_again -= delta
		if _look_again <= 0.0:
			_look_again = 2.0
			_find_sun()
	var night := _sun != null and (not _sun.is_visible_in_tree() or _sun.light_energy < _day * DUSK)
	lit = move_toward(lit, 1.0 if night else 0.0, EASE * delta)
	light_energy = ENERGY * lit
	visible = lit > 0.0


func _find_sun() -> void:
	var world := get_tree().current_scene.get_node_or_null(^"World") if get_tree().current_scene else null
	if world == null:
		for n in get_tree().root.find_children("World", "Node3D", true, false):
			world = n
			break
	_sun = world.get_node_or_null(^"Sun") as DirectionalLight3D if world else null
	if _sun:
		_day = _sun.light_energy
