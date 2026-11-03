extends Node
## The open ground's air (autoload `Atmosphere`, 2026-11-03, the user on the PS1 critic's notes):
## the default day is choked, dusty and pale, not a holiday sky, and a short, hard PS1 fog wall
## swallows the far ground: half gone by ~35 m, all dust by FOG_END. Laid over the environment
## tools/build_world.gd built (scenes/world.tscn) as it enters the tree, before anything copies it
## (player.gd's viewmodel), so the scene and its builder stay as they are. The day and night cycle
## takes these values over when it comes; at night the fog goes near black (tools/psx_shots.gd
## `_night`), and the far ground sinks into the dark with it.

const WORLD := "res://scenes/world.tscn"
## Poly Haven's Kloofendal Overcast pure sky (CC0), 1k: drawn unfiltered, its big pixels are the PS1's.
const SKY := preload("res://assets/env/hdri/kloofendal_overcast_puresky_1k.hdr")
const DUST := Color(0.66, 0.56, 0.42)  # the fog by day: warm, sandy dust, yellower than the sky
## Night (night()): dark, but not a black hole (2026-11-03, the PS1 critic: at full black the
## workshop 10 m off was gone, and so were the hands): a deep blue-grey haze that what stands in
## it is a silhouette against, a little moonlight all round, the sky one with the haze.
const NIGHT_FOG := Color(0.07, 0.08, 0.1)
const NIGHT_AMBIENT := Color(0.35, 0.42, 0.6)
const NIGHT_AMBIENT_ENERGY := 0.16
const FOG_BEGIN := 12.0  # m: clear air up to here
const FOG_END := 75.0  # m: nothing but dust past here
const FOG_CURVE := 0.6  # under 1 the fog thickens early: half way in at ~35 m
const SATURATION := 0.75


func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	# A -s tool's world can be in before the autoloads (they join after its _initialize).
	for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_on_node_added(n)


func _on_node_added(n: Node) -> void:
	if n is WorldEnvironment and n.owner != null and n.owner.scene_file_path == WORLD:
		_dust(n as WorldEnvironment)


## Night over `main`'s world, roughly (the day and night cycle, to come, eases into it): the sun
## out, the sky and the light it bounces nearly gone; the lamps and the barrel fire are the light.
## tools/psx_shots.gd shoots its night with it.
func night(main: Node) -> void:
	(main.get_node("World/Sun") as DirectionalLight3D).visible = false
	var env: Environment = (main.get_node("World/WorldEnvironment") as WorldEnvironment).environment
	env.background_energy_multiplier = 0.02
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = NIGHT_AMBIENT
	env.ambient_light_energy = NIGHT_AMBIENT_ENERGY
	env.ambient_light_sky_contribution = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_light_color = NIGHT_FOG
	env.fog_sky_affect = 1.0
	env.volumetric_fog_albedo = Color(0.05, 0.05, 0.06)
	var amb := main.get_node_or_null("Ambience")
	if amb:
		amb.set(&"night", true)


func _dust(we: WorldEnvironment) -> void:
	var env := we.environment
	if env == null or env.has_meta(&"dusted"):
		return
	env.set_meta(&"dusted", true)
	var sky := PanoramaSkyMaterial.new()
	sky.panorama = SKY
	sky.filter = false
	env.sky = env.sky.duplicate() if env.sky else Sky.new()
	env.sky.sky_material = sky
	env.ambient_light_energy = 1.0  # overcast: more of the light comes from all round
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = DUST
	env.fog_density = 1.0  # depth fog: all the way to the colour at FOG_END
	env.fog_depth_begin = FOG_BEGIN
	env.fog_depth_end = FOG_END
	env.fog_depth_curve = FOG_CURVE
	env.fog_sky_affect = 0.6  # the sky goes dusty too, the horizon one with the ground
	env.fog_aerial_perspective = 0.0  # its colour from the dust, not the sky
	env.adjustment_enabled = true
	env.adjustment_saturation = SATURATION
	var sun := we.get_parent().get_node_or_null(^"Sun") as DirectionalLight3D
	if sun:
		sun.light_color = Color(0.96, 0.89, 0.78)
		sun.light_energy = 1.0  # through the overcast
		sun.light_angular_distance = 3.0  # soft-edged shadows
