extends StaticBody3D
## The melting hopper in the workshop (tools/range_dressing.gd _workshop, hopper.glb), showing what
## the team's hopper is doing (GameState melt_bin, melt_level): the rounds poured in lie on its
## grate (as many of the glb's own as the bin's share of FULL), the burner's flame and the
## crucible's melt burn high while it melts and sink back once it is empty, higher a level up, and
## over it a small tag reads how many wait and how long they take. Each peer draws its own from
## GameState, which a client mirrors (melter_changed).

const FULL := 200  # rounds in the bin that show every round on the grate
const TAG_RANGE := 9.0  # m the tag reads from
const TAG_NEAR := 2.4  # m: closer (at its screen, at the press beside it) it is in the way
const TAG_AT := Vector3(0, 1.32, 0)
const EASE := 2.5  # how fast the fire follows: 1/s
const GLOW := Color(1.0, 0.5, 0.18)

var _grate: Array[Node3D] = []
var _flame: MeshInstance3D
var _molten: StandardMaterial3D
var _melt_rest := 6.0  # the molten surface's own glow, idle
var _glow := OmniLight3D.new()
var _tag := Label3D.new()
var _heat := 0.0  # 0 idle .. 1 melting, eased
var _t := 0.0
var _gs: Node  # GameState, found at run time: the arena's build has no autoloads to compile against


func _ready() -> void:
	var glb := get_child(0)
	for m: MeshInstance3D in glb.find_children("HR*", "MeshInstance3D", true, false):
		if (m.global_transform * m.get_aabb()).get_center().y - global_position.y > 0.8:
			_grate.append(m)  # the rounds on the grate; the bucket's and the floor's stay
	_grate.sort_custom(func(a: Node3D, b: Node3D) -> bool: return hash(a.name) < hash(b.name))
	_flame = glb.find_child("Hopper_flame", true, false)
	var molten: MeshInstance3D = glb.find_child("Hopper_molten", true, false)
	if molten and molten.get_active_material(0) is StandardMaterial3D:
		_molten = molten.get_active_material(0).duplicate()
		molten.material_override = _molten
		_melt_rest = _molten.emission_energy_multiplier
	_glow.light_color = GLOW
	_glow.position = Vector3(0, 0.38, 0)
	_glow.omni_range = 2.2
	_glow.light_energy = 0.0
	_glow.shadow_enabled = false
	_glow.light_volumetric_fog_energy = 0.4
	add_child(_glow)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position = TAG_AT
	_tag.font = UiStyle.face(UiStyle.BOLD, 0, true)
	_tag.font_size = 56
	_tag.pixel_size = 0.0022
	_tag.outline_size = 14
	_tag.outline_modulate = Color(0, 0, 0, 0.75)
	_tag.modulate = UiStyle.ACCENT
	_tag.visibility_range_end = TAG_RANGE
	_tag.visibility_range_end_margin = 1.0
	_tag.visibility_range_begin = TAG_NEAR
	_tag.visibility_range_begin_margin = 0.4
	_tag.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_tag.visible = false
	add_child(_tag)
	_gs = get_node("/root/GameState")
	_show_bin()
	_gs.melter_changed.connect(func(_b: int, _r: int, _m: int, _p: int) -> void: _show_bin())


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var bin: int = _gs.melt_bin
	var want := 1.0 if bin > 0 else 0.0
	_heat = move_toward(_heat, want, delta * EASE * (1.0 if want > _heat else 0.5))
	var level := float(_gs.melt_level) / maxf(1.0, _gs.MELT_RATES.size() - 1.0)
	var flicker := 1.0 + 0.08 * sin(_t * 13.0) + 0.05 * sin(_t * 31.0)
	if _flame:
		var s := 1.0 + _heat * (0.6 + 0.6 * level)
		_flame.scale = Vector3(s, s * (1.0 + _heat * 1.5) * flicker, s)
	if _molten:
		_molten.emission_energy_multiplier = _melt_rest * (1.0 + _heat * (0.8 + level)) * flicker
	_glow.light_energy = _heat * (0.9 + 0.6 * level) * flicker
	if bin > 0:
		var rate: float = _gs.MELT_RATES[_gs.melt_level]
		_tag.text = "%s mermi  ·  %s" % [UiStyle.dotted(bin), _time(bin / rate)]
	_tag.visible = bin > 0


## As many grate rounds as the bin's share of FULL, at least one while anything waits.
func _show_bin() -> void:
	var bin: int = _gs.melt_bin
	var shown := 0 if bin <= 0 else clampi(ceili(_grate.size() * minf(1.0, float(bin) / FULL)), 1, _grate.size())
	for i in _grate.size():
		_grate[i].visible = i < shown


## 75 -> "1 dk 15 sn"
func _time(seconds: float) -> String:
	var s := ceili(seconds)
	return "%d sn" % s if s < 60 else "%d dk %d sn" % [floori(s / 60.0), s % 60]
