extends Node3D
## The Electric round built on the bench (2026-10-28, the user's scene): a plain .338 lies on the
## top, rises and stands; the case is cut through twice, the slice between is thrown out and the top
## half opens up; an empty spool slides into the gap, the top comes back down onto it and copper
## winds on turn by turn while the round turns; a steel ring clicks on from below, another from above; the bullet is unscrewed
## and lifted away, the quartz reactor drops into the neck, the sharp nose comes down turning, catches and is pressed home; then the
## Tesla coil on the bench charges for a few seconds, an arc jumps to the round and its reactor
## lights up ice blue and stays lit. The model is tools/build_electric_round.py's, each part apart.
## The sounds are placeholders (assets/sounds/recipes/electric_*.wav) until the real ones come.
## Set `tesla` (the bench's P_tesla_coil) before play(); without it there's no charge or arc.

const ROUND := preload("res://assets/bullet/electric_round.glb")
const SCALE := 1.5  # the real .338 is 9.4 cm; a bit bigger reads on the bench
const LEN := 0.0935 * SCALE  # m, the plain round, foot to tip
const R := 0.0083 * SCALE  # m, the case's radius: what it lies on
const HOVER := 0.05  # m from the top to its foot while it's worked on
const WINDOW := Vector3(0.0, 0.078, 0.0)  # the reactor's window, model space (tools/build_electric_round.py)
const TOP := Vector3(0.0, 0.1028, 0.0)  # the nose's point, model space
const CUTS := [0.0118, 0.0382]  # m up the case where it's cut through, model space
const BODY := 0.0083  # m, the case's radius, model space
const GAP := 0.02  # m the top half opens up by, model space

const RISE := Vector2(0.6, 2.0)  # s, lying still a moment, then off the top and standing
const CUT := 2.4  # s, the case is cut through
const OPEN := Vector2(2.4, 2.8)  # s, the top half lifts GAP; the slice between flies out
const SPOOL := Vector2(2.9, 3.2)  # s, the empty spool slides into the gap from the side
## Every part comes straight in and stops dead where it goes, fast and hard, never past it
## (the user's call: the reactor overshooting sank into the case). Each starts out of the close
## shot (electric_demo.gd), so none pops up in mid-air.
const CLOSE := Vector2(3.3, 3.6)  # s, the top half comes back down onto it
const WIND := Vector2(3.75, 5.35)  # s, the copper winds on, fast; the round turns WIND_TURNS
const WIND_TURNS := 3.0
## The two rings start the moment the winding is done, together, no wait (the user's call).
const RING_LOW := Vector2(WIND.y, WIND.y + 0.2)  # s, up from below, clicks on at the end
const RING_HIGH := RING_LOW  # s, down from above, at the same time
## Each step follows the last without a dead pause (the user's call: the still gaps read as freezes).
const UNSCREW := Vector2(5.7, 6.15)  # s, the plain bullet turns loose
const LIFT := Vector2(6.15, 6.5)  # s, and goes up out of sight
const REACTOR := Vector2(6.6, 6.95)  # s, the reactor drops into the neck
## The nose comes down turning and catches on the reactor, starting just over the close shot so
## it's seen coming (the user saw it pop on: from 15 cm up in a quarter second it was off frame).
const NOSE := Vector2(7.1, 7.5)
const PRESS := Vector2(7.65, 7.73)  # s, a short push seats it (the user's call: no hanging in the air)
const CATCH := 0.0015  # m it stands proud once caught, model space
const CHARGE := PRESS.y + 0.55  # s, the coil starts to charge
const ZAP := CHARGE + 7.1  # s, the first strike: on the charge sound's peak, its last moment
## The coil charges to its sound (the user's call): electric_charge.wav's brightness every 0.1 s,
## smoothed, never falling back, 0 -> 1. It drives how full the coil is and how fast the ball
## runs round its rings (charge, _turn).
const CHARGE_CURVE := [0.00, 0.00, 0.00, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.09, 0.12, 0.12, 0.12, 0.12, 0.12, 0.13, 0.13, 0.20, 0.20, 0.24, 0.28, 0.28, 0.29, 0.35, 0.38, 0.38, 0.45, 0.45, 0.45, 0.45, 0.45, 0.45, 0.49, 0.49, 0.50, 0.50, 0.50, 0.50, 0.52, 0.52, 0.52, 0.55, 0.65, 0.67, 0.74, 0.81, 0.88, 0.88, 0.94, 0.97, 0.99, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00]
## Four big strikes from the coil to the round, each a fifth of a second of flicker, branching,
## sparks flying off both ends; the room goes dark for the charge so their light shows on
## everything round them (the user's call: bigger, more, dramatic).
const STRIKES := [0.0, 0.34, 0.72, 1.12]  # s after ZAP
const STRIKE := 0.2  # s each lasts
const ARC := 1.32  # s from the first strike to the end of the last
const DARK := Vector2(CHARGE - 0.6, CHARGE + 0.8)  # s, the room's lights go down
## Charged, the round hangs there crackling to electric_zapping.wav (the user's call): its four
## bursts, s after ZAPPING, each throwing arcs off the round, and every crack in them (ZAP_HITS,
## measured off the recording) a spray of sparks from a new spot on it.
const ZAPPING := ZAP + ARC + 0.3
const ZAP_BURSTS := [Vector2(0.05, 0.85), Vector2(1.35, 1.95), Vector2(2.45, 3.2), Vector2(3.65, 4.7)]
const ZAP_HITS := [0.06, 0.16, 0.48, 1.38, 1.55, 1.62, 1.69, 1.85, 2.65, 2.83, 2.9, 2.97, 3.07, 3.68, 3.85, 4.16, 4.53]
const LIGHT := Vector2(ZAPPING + 4.8, ZAPPING + 6.0)  # s, the room's lights come back up
const SETTLE := Vector2(ZAPPING + 4.9, ZAPPING + 5.4)  # s, set down standing on the top
const END := ZAPPING + 6.3
const CLICKS := [CLOSE.y, RING_LOW.y, PRESS.y]

## The user's recordings (docs/ayrintilar.md "Kullanılan asetler"), cut, softened and timed to
## the moments below (2026-10-29); the coil's charge is still a placeholder.
const SOUNDS := {
	"rise": preload("res://assets/sounds/recipes/electric_rise.wav"),  # laser whoosh, peaks 0.43 s in
	"cut": preload("res://assets/sounds/recipes/electric_cut.wav"),  # whoosh and slam, the slam 0.30 s in
	"mount": preload("res://assets/sounds/recipes/electric_mount.wav"),  # wrench crank, 0.11 s in
	"whoosh": preload("res://assets/sounds/recipes/electric_whoosh.wav"),  # deep soft whoosh, peaks 0.33 s in
	"clash": preload("res://assets/sounds/recipes/electric_clash.wav"),  # a part going on, pitched per part
	"wind": preload("res://assets/sounds/recipes/electric_wind.wav"),  # fishing reel, 1.75 s
	"charge": preload("res://assets/sounds/recipes/electric_charge.wav"),
	"zapping": preload("res://assets/sounds/recipes/electric_zapping.wav"),  # four bursts of crackle, 4.85 s
	"reactor": preload("res://assets/sounds/recipes/electric_reactor.wav"),  # neon buzz, a seamless 1.15 s loop
}
## Every strike cracks with the same recording ("cinematic sparking electric intro", from its hit),
## each at its own pitch (the user's call), on its own player.
const ZAP_SOUND := preload("res://assets/sounds/recipes/electric_zap.wav")
const ZAP_PITCH := [1.0, 0.88, 1.12, 0.8]
## [time, where ("round" or "tesla"), sound, pitch, fade in s]: each starts so its own peak lands
## on its moment. The longer ones swell in rather than start at full (the user's call: every sound
## came in like a clip waiting its turn), the coil's charge most of all; hits stay sharp.
const CUES := [
	[RISE.x - 0.02, "round", "rise", 1.0, 0.25], [CUT - 0.3, "round", "cut", 1.0, 0.08],
	[CLOSE.y - 0.11, "round", "mount", 1.0, 0.0],  # the crank as the round closes on the spool (the user's call)
	[WIND.x, "round", "wind", 1.0, 0.3], [RING_LOW.y, "round", "clash", 0.85, 0.0],
	[REACTOR.y, "round", "clash", 1.2, 0.0], [PRESS.y, "round", "clash", 0.75, 0.0],
	[CHARGE, "tesla", "charge", 1.0, 1.6], [ZAPPING, "round", "zapping", 1.0, 0.0],
]
const HUM_IN := 1.0  # s, the reactor's hum swelling in
## A whoosh carried by every part that flies in or out (the user's call), so it's heard coming
## from where the part comes from and moves with it: [part, when, pitch, dB, arriving]. An arriving
## one's peak lands on its arrival. Kept well under the rest and pitched up by how small the part
## is, which also makes it shorter: a small part only flicks past (the user's call: the whoosh was
## far too big for them). Spool, slice, bullet, nose, reactor, rings.
const WHOOSH_PEAK := 0.33  # s into electric_whoosh.wav
const WHOOSHES := [
	["Spool", SPOOL.y, 1.1, -12.0, true], ["CaseMid", CUT, 1.25, -13.0, false],
	["Tip", LIFT.x, 1.45, -15.0, false], ["Nose", NOSE.y, 1.55, -15.0, true],
	["Reactor", REACTOR.y, 1.7, -16.0, true],
	["RingLow", RING_LOW.y, 2.0, -18.0, true], ["RingHigh", RING_HIGH.y, 2.0, -18.0, true],
]
const ICE := Color(0.62, 0.86, 1.0)
## Lightning's own colour (the user's call: electric blue, white-blue, not white): the halo of
## every bolt and the light the strikes and cracks throw; the cores stay white-blue.
const BOLT_BLUE := Color(0.42, 0.65, 1.0)
const BOLT_CORE := Color(0.82, 0.9, 1.0)

const COIL_SHADER := "shader_type spatial;
uniform float progress = 1.0;
void fragment() {
	if (UV.x > progress) { discard; }
	ALBEDO = vec3(0.93, 0.5, 0.32);
	METALLIC = 1.0;
	ROUGHNESS = 0.3;
}"
## The lit tube: a soft ice-blue fill, brightest through its middle, breathing and flickering a
## little; additive and drawn behind nothing, so it reads as light inside the glass.
const CORE_SHADER := "shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform float glow = 0.0;
void fragment() {
	float face = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	float breathe = 0.85 + 0.1 * sin(TIME * 6.0) + 0.05 * sin(TIME * 53.0);
	ALBEDO = vec3(0.3, 0.7, 1.0) * (0.35 + 0.9 * face) * glow * breathe;
}"
## The charge as a ball of lightning run up the coil like a particle accelerator (the user's call,
## "like CERN's rings"): round the lowest, widest ring clockwise, faster and faster, up to the next
## and round it the other way, up to the top one and round it again, then up to the tip, where it
## bursts as the first strike leaves for the round. The sound's curve sets how fast it goes.
## The coil's three rings, lowest first (measured off its mesh's width up its height, 2026-10-29):
## height up the coil (its foot 0, its top 1) and outer radius in the coil's own metres.
const RING_H := [0.455, 0.54, 0.635]
const RING_RAD := [0.046, 0.040, 0.035]
const COIL_SCALE := 1.2  # the bench's scale (range_dressing.gd _workshop, electric_demo.gd BENCH)
const ORBITS := [Vector2(0.0, 3.0), Vector2(3.3, 5.2), Vector2(5.5, 6.6)]  # s after CHARGE, round each ring
const TURN_DIR := [1.0, -1.0, 1.0]  # +1 is clockwise seen from above
const TO_TIP := Vector2(6.6, 7.1)  # s after CHARGE: off the top ring to the tip, arriving on ZAP
## The ring the ball is on glows round its edge (wider than RING_R from the axis: the pole through
## the rings stays dark). y0/y1: the coil's foot and top, world height; axis: world x, z.
const RING_SHADER := "shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform float glow = 0.0;
uniform float ring_h = 0.5;
uniform float y0 = 0.0;
uniform float y1 = 1.0;
uniform vec2 axis = vec2(0.0);
uniform float ring_r = 0.025;
varying float h;
varying float r;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = (w.y - y0) / (y1 - y0);
	r = length(w.xz - axis);
}
void fragment() {
	float on_ring = smoothstep(ring_r * 0.85, ring_r, r) * exp(-(h - ring_h) * (h - ring_h) * 1500.0);
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	float hum = 0.85 + 0.15 * sin(TIME * 45.0 + r * 400.0);
	ALBEDO = vec3(0.5, 0.82, 1.0) * on_ring * glow * hum * (0.45 + rim);
}"
const RING_R := 0.025
## Electric textures (assets/vfx/electric, CC0; docs/ayrintilar.md "Kullanılan asetler"): Kenney's
## crackle sprites for the corona on the coil's top, his trace streaks for flying sparks, his soft
## light for the hot spot and, sampled across each stroke, the falloff that gives a bolt its body.
## The strikes are lightning, not noise (the user's call: the arc strips looked like static): one
## jagged channel with a white-hot core and a blue halo, forking, tapering off at its ends.
const CRACKLE := preload("res://assets/vfx/electric/crackle_atlas.png")  # 2 x 2 frames
const TRACE := preload("res://assets/vfx/electric/trace.png")
const GLOW_TEX := preload("res://assets/vfx/electric/glow.png")
## The round taking the strike: a cold blue edge light crawling over every part of it while a
## strike is on, dying away after (the user's call: the coil's charge has to be seen going into it).
const SHOCK_SHADER := "shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform float shock = 0.0;
void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.5);
	float crawl = 0.7 + 0.3 * sin(TIME * 60.0);  // all of it at once: bands up its height striped it
	ALBEDO = vec3(0.45, 0.8, 1.0) * rim * shock * crawl * 2.0;
}"

var tesla: Node3D

var _t := END
var _round: Node3D
var _parts := {}
var _coil := ShaderMaterial.new()
var _glow := StandardMaterial3D.new()
var _glass := StandardMaterial3D.new()
var _core := ShaderMaterial.new()
var _reactor_light := OmniLight3D.new()
var _tesla_light := OmniLight3D.new()
var _flash := OmniLight3D.new()
var _bolts := MeshInstance3D.new()
var _lines := ImmediateMesh.new()
var _snd := {}
var _hum := AudioStreamPlayer3D.new()
var _tesla_top := Vector3.ZERO
var _warming := false
var _zaps: Array[AudioStreamPlayer3D] = []  # one per strike: they overlap, none cuts the last off
var _next_round := 0  # the round's three players take turns, so one sound doesn't cut another
var _whooshes: Array[AudioStreamPlayer3D] = []  # one per WHOOSHES, on its part
var _fades := []  # [player, from t, over s, to dB]: a sound swelling in
var _sparks_hit: CPUParticles3D  # off the nose on every strike
var _sparks_coil: CPUParticles3D  # off the coil's top
var _sparks_skin: CPUParticles3D  # a few off the round's surface on each crack while it hangs charged
var _corona: CPUParticles3D  # crackling on the coil's top while it charges
var _climb := ShaderMaterial.new()  # the ring the ball is on, glowing
var _turned := PackedFloat32Array()  # the ball's angle round the coil every 0.01 s from CHARGE
var _ball := MeshInstance3D.new()
var _ball_light := OmniLight3D.new()
var _burst := MeshInstance3D.new()  # the ball bursting on the tip
var _burst_mat: StandardMaterial3D
var _axis := Vector2.ZERO  # the coil's axis, world x, z
var _coil_y := Vector2(0.0, 1.0)  # its foot and top, world height
var _round_corona: CPUParticles3D  # crackling on the round as it takes the strikes
var _shock := ShaderMaterial.new()
var _hit := MeshInstance3D.new()  # the hot spot where a strike meets the nose
var _crack := MeshInstance3D.new()  # the flash where a crack's spark leaves the round
var _crack_mat: StandardMaterial3D
var _crack_light := OmniLight3D.new()  # what a crack lights round it: the round, the top under it
## Behind the round, away from the camera, lit only by the flashes: the room stays dark, but each
## strike and crack outlines the round against it (the user's call).
var _rim := OmniLight3D.new()
var _bolt_mat: StandardMaterial3D  # the soft falloff across a stroke
var _line_mat := StandardMaterial3D.new()  # the cut lines


func _ready() -> void:
	_round = ROUND.instantiate()
	add_child(_round)
	for n in ["CaseWhole", "CaseLow", "CaseMid", "CaseHigh", "Tip", "Spool", "Coil", "RingLow", "RingHigh", "Reactor", "Nose", "Window", "Tube", "Filament", "Core"]:
		_parts[n] = _round.find_child(n, true, false)
	var sh := Shader.new()
	sh.code = COIL_SHADER
	_coil.shader = sh
	_parts.Coil.material_override = _coil
	# Clear quartz, its edges catching light (the user's reference: you see the coil through it),
	# tinted ice blue from inside once the reactor is lit.
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.albedo_color = Color(0.8, 0.92, 1.0, 0.07)
	_glass.roughness = 0.02
	_glass.metallic_specular = 1.0
	_glass.rim_enabled = true
	_glass.rim = 0.6
	_glass.rim_tint = 0.3
	_glass.emission_enabled = true
	_glass.emission = ICE
	_glass.emission_energy_multiplier = 0.0
	_glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_parts.Window.material_override = _glass
	var tube := _glass.duplicate()
	tube.albedo_color = Color(0.85, 0.95, 1.0, 0.04)
	tube.cull_mode = BaseMaterial3D.CULL_DISABLED
	_parts.Tube.material_override = tube
	# The copper filament: bare copper, white-blue hot when lit.
	_glow.albedo_color = Color(0.93, 0.5, 0.3)
	_glow.metallic = 1.0
	_glow.roughness = 0.3
	_glow.emission_enabled = true
	_glow.emission = Color(0.8, 0.94, 1.0)
	_parts.Filament.material_override = _glow
	var cs := Shader.new()
	cs.code = CORE_SHADER
	_core.shader = cs
	_parts.Core.material_override = _core
	_reactor_light.light_color = ICE
	_reactor_light.omni_range = 0.35
	_reactor_light.light_specular = 0.2
	_reactor_light.top_level = true  # the round is scaled; kept on the window by _show
	add_child(_reactor_light)

	_tesla_light.light_color = BOLT_BLUE
	_tesla_light.omni_range = 2.0
	_tesla_light.shadow_enabled = true
	_tesla_light.top_level = true
	add_child(_tesla_light)
	_flash.light_color = BOLT_BLUE
	_flash.omni_range = 2.6
	_flash.shadow_enabled = true
	_flash.top_level = true
	add_child(_flash)
	_sparks_hit = _sparks(40)
	_sparks_coil = _sparks(60)
	_sparks_skin = _sparks(12)
	_sparks_skin.initial_velocity_min = 0.4
	_sparks_skin.initial_velocity_max = 1.2
	_sparks_skin.spread = 50.0  # outward, round the way the surface faces
	_corona = _make_corona()
	var cl := Shader.new()
	cl.code = RING_SHADER
	_climb.shader = cl
	var ang := 0.0
	for i in int((ZAP - CHARGE) * 100.0) + 1:  # rad/s: a slow start to a blur as the sound climbs
		_turned.append(ang)
		var at := CHARGE + i * 0.01
		ang += _dir(at - CHARGE) * lerpf(3.0, 34.0, pow(_curve(CHARGE_CURVE, at), 1.2)) * 0.01
	_ball.mesh = _glow_quad(0.04, Color(0.8, 1.1, 1.4))  # the user's call: it was too bright
	var core := MeshInstance3D.new()
	core.mesh = _glow_quad(0.014, Color(1.3, 1.35, 1.4))
	_ball.add_child(core)
	_ball.top_level = true
	_ball.visible = false
	add_child(_ball)
	_ball_light.light_color = ICE
	_ball_light.omni_range = 0.3
	_ball_light.top_level = true
	add_child(_ball_light)
	_burst.mesh = _glow_quad(0.05, Color(2.5, 2.9, 3.4))
	_burst_mat = (_burst.mesh as QuadMesh).material
	_burst.top_level = true
	_burst.visible = false
	add_child(_burst)
	_round_corona = _make_corona()
	_round_corona.emission_sphere_radius = 0.03
	(_round_corona.mesh as QuadMesh).size = Vector2(0.06, 0.06)
	var sh2 := Shader.new()
	sh2.code = SHOCK_SHADER
	_shock.shader = sh2
	for m: Node in _round.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = _shock
	var spot := QuadMesh.new()
	spot.size = Vector2(0.05, 0.05)
	var sm := _additive()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.albedo_texture = _soft()
	sm.albedo_color = Color(1.6, 2.2, 2.8)
	sm.no_depth_test = true  # on the nose, not cut by it
	spot.material = sm
	_hit.mesh = spot
	_hit.top_level = true
	_hit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hit.visible = false
	add_child(_hit)
	_crack.mesh = _glow_quad(0.022, Color(1.0, 1.5, 2.4))
	_crack_mat = (_crack.mesh as QuadMesh).material
	_crack_mat.no_depth_test = true
	_crack.top_level = true
	_crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crack.visible = false
	add_child(_crack)
	_crack_light.light_color = BOLT_BLUE
	_crack_light.omni_range = 0.3
	_crack_light.light_specular = 0.3
	_crack_light.top_level = true
	add_child(_crack_light)
	_rim.light_color = BOLT_BLUE
	_rim.omni_range = 0.18  # the round's edges only, not the wall behind
	_rim.light_specular = 0.25  # metal right next to it blew out white (the user saw it)
	_rim.top_level = true
	add_child(_rim)
	_bolt_mat = _additive()
	_bolt_mat.albedo_texture = GLOW_TEX
	_bolt_mat.albedo_color = Color(1.8, 1.9, 2.1)  # past white, so the glow blooms off it
	_line_mat = _additive()
	_line_mat.albedo_color = Color(1.5, 1.5, 1.5)
	_bolts.mesh = _lines
	_bolts.top_level = true
	_bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bolts)

	for where in ["round_0", "round_1", "round_2", "tesla"]:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"Dunya"
		p.unit_size = 3.0
		add_child(p)
		_snd[where] = p
	_snd.tesla.top_level = true
	for i in STRIKES.size():
		var z := AudioStreamPlayer3D.new()
		z.bus = &"Dunya"
		z.unit_size = 4.0
		z.stream = ZAP_SOUND
		z.pitch_scale = ZAP_PITCH[i]
		z.volume_db = -7.0  # four overlapping would clip at full
		z.top_level = true
		add_child(z)
		_zaps.append(z)
	var loop: AudioStreamWAV = SOUNDS.reactor.duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	_hum.stream = loop
	_hum.bus = &"Dunya"
	_hum.unit_size = 1.5
	_hum.volume_db = -14.0
	_round.add_child(_hum)
	for w: Array in WHOOSHES:
		var p := AudioStreamPlayer3D.new()
		p.stream = SOUNDS.whoosh
		p.bus = &"Dunya"
		p.pitch_scale = w[2]
		p.volume_db = w[3]
		p.unit_size = 0.6
		p.panning_strength = 3.0  # a few cm off the round is no stereo otherwise
		_parts[w[0]].add_child(p)
		_whooshes.append(p)
	_show(0.0)
	_warm_up()


## A one-shot burst of hot blue-white sparks, thrown every way and falling.
func _sparks(amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.particle_flag_align_y = true  # a streak along where it flies
	var quad := QuadMesh.new()
	quad.size = Vector2(0.0025, 0.02)
	var m := _additive()
	m.albedo_texture = TRACE
	m.albedo_color = Color(2.5, 2.8, 3.2)
	quad.material = m
	p.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0))
	fade.set_color(1, Color(ICE, 0.0))
	p.color_ramp = fade
	p.top_level = true
	add_child(p)
	return p


## A soft round light, `size` m, always facing the camera, drawn over what's in front.
func _glow_quad(size: float, color: Color) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := _additive()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _soft()
	m.albedo_color = color
	q.material = m
	return q


## A plain soft round light, bright in the middle and gone at the edge: the hot spots and the
## ball (Kenney's light has rings in it, a target where a spark leaves the round).
func _soft() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color.BLACK)  # black, not clear: added light ignores alpha
	g.add_point(0.3, Color(0.35, 0.35, 0.35))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


## Unlit, adding its light, both faces, tinted by vertex colour.
func _additive() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


## Short-lived crackle sprites on the coil's top, each a random frame turned any way: the corona
## a real coil wears before it discharges. Emitting while it charges, bigger as it fills.
func _make_corona() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 10
	p.lifetime = 0.09
	p.explosiveness = 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.025
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.05
	p.gravity = Vector3.ZERO
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.anim_offset_min = 0.0
	p.anim_offset_max = 1.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var m := _additive()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.particles_anim_h_frames = 2
	m.particles_anim_v_frames = 2
	m.albedo_texture = CRACKLE
	m.albedo_color = Color(1.2, 1.6, 2.2)
	quad.material = m
	p.mesh = quad
	p.top_level = true
	add_child(p)
	return p


## Every part, the arc and the reactor drawn a few frames, too small to see, before anything
## happens: a material's first draw compiles its shader, and done the moment a part flew in
## that showed as a hitch or a wrong frame (the user saw it before each part came).
func _warm_up() -> void:
	_warming = true
	var kept := {}
	for n: Node3D in _parts.values():
		kept[n] = [n.transform, n.visible]
		n.transform = n.transform.scaled_local(Vector3.ONE * 0.001)
		n.visible = true
	_coil.set_shader_parameter("progress", 1.0)
	_glow.emission_energy_multiplier = 1.0
	for m: Material in [_bolt_mat, _line_mat]:
		_lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES, m)
		for v in [Vector3.ZERO, Vector3(0.0001, 0, 0), Vector3(0, 0.0001, 0)]:
			_lines.surface_set_uv(Vector2.ZERO)
			_lines.surface_add_vertex(global_position + v if is_inside_tree() else v)
		_lines.surface_end()
	for i in 3:
		await get_tree().process_frame
	for n: Node3D in kept:
		n.transform = kept[n][0]
		n.visible = kept[n][1]
	_warming = false
	_show(_t if _t < END else 0.0)


func play() -> void:
	_t = 0.0
	for p: AudioStreamPlayer3D in _snd.values() + _zaps + _whooshes:
		p.stop()
	_hum.stop()
	_fades.clear()
	if tesla:
		var box := AABB()
		var first := true
		for m: Node in tesla.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var b := mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		_tesla_top = Vector3(box.get_center().x, box.end.y, box.get_center().z)
		_climb.set_shader_parameter("y0", box.position.y)
		_climb.set_shader_parameter("y1", box.end.y)
		_climb.set_shader_parameter("axis", Vector2(box.get_center().x, box.get_center().z))
		_climb.set_shader_parameter("ring_r", RING_R)
		_axis = Vector2(box.get_center().x, box.get_center().z)
		_coil_y = Vector2(box.position.y, box.end.y)
		for m: Node in tesla.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = _climb
		_tesla_light.global_position = _tesla_top
		_snd.tesla.global_position = _tesla_top
		_corona.global_position = _tesla_top
		for z in _zaps:
			z.global_position = _tesla_top
	_show(0.0)


func _exit_tree() -> void:
	for p: AudioStreamPlayer3D in _snd.values() + _zaps + _whooshes:
		p.stop()
	_hum.stop()


func _process(delta: float) -> void:
	if _t >= END or _warming:  # held still the few frames it warms up
		return
	var was := _t
	_t = minf(_t + delta, END)
	for c: Array in CUES:
		if was < c[0] and _t >= c[0] and (c[1] == "round" or tesla):
			var p: AudioStreamPlayer3D = _snd.tesla
			if c[1] == "round":
				p = _snd["round_%d" % _next_round]
				_next_round = (_next_round + 1) % 3
			p.stream = SOUNDS[c[2]]
			p.pitch_scale = c[3]
			p.volume_db = 0.0
			if c[4] > 0.0:
				_fades.append([p, c[0], c[4], 0.0])
			p.play()
	for i in STRIKES.size():
		var at: float = ZAP + STRIKES[i]
		if tesla and was < at and _t >= at:
			_zaps[i].play()
			_sparks_hit.global_position = _round.global_transform * TOP
			_sparks_hit.restart()
			_sparks_coil.global_position = _tesla_top
			_sparks_coil.restart()
	for i in WHOOSHES.size():
		var w: Array = WHOOSHES[i]
		var at: float = w[1] - (WHOOSH_PEAK / w[2] if w[4] else 0.0)
		if was < at and _t >= at:
			_whooshes[i].play()
	for i in ZAP_HITS.size():  # a spray of sparks off the round on every crack
		var at: float = ZAPPING + ZAP_HITS[i]
		if tesla and was < at and _t >= at:
			_sparks_skin.global_position = _round.global_transform * _spot(i)
			_sparks_skin.direction = _round.global_transform.basis * _out(i)
			_sparks_skin.restart()
	if was < ZAP + 0.25 and _t >= ZAP + 0.25:
		_fades.append([_hum, ZAP + 0.25, HUM_IN, -14.0])
		_hum.play()
	for f: Array in _fades:  # rising on an even loudness curve, from nothing
		var k := clampf((_t - f[1]) / f[2], 0.0, 1.0)
		(f[0] as AudioStreamPlayer3D).volume_db = f[3] + linear_to_db(maxf(k * k, 0.001))
	_fades = _fades.filter(func(f: Array) -> bool: return _t < f[1] + f[2])
	_show(_t)


func _show(t: float) -> void:
	_round.transform = round_pose(t)
	for n in ["CaseWhole", "CaseLow", "CaseMid", "CaseHigh", "Tip", "Spool", "RingLow", "RingHigh", "Reactor", "Nose"]:
		var node: Node3D = _parts[n]
		var at = part(n, t)
		node.visible = at != null
		if at != null:
			node.transform = at
	_coil.set_shader_parameter("progress", coil(t))
	_parts.Coil.visible = coil(t) > 0.0
	var g := glow(t)
	_glow.emission_energy_multiplier = 2.5 * g  # the coil shows hot through the glass, not a blob of light
	_core.set_shader_parameter("glow", 0.18 * g)
	_glass.emission_energy_multiplier = 0.03 * g
	_reactor_light.light_energy = 0.7 * g  # it sits in the tube: any more washes the coil out
	if is_inside_tree():
		_reactor_light.global_position = _round.global_transform * WINDOW
	var c := charge(t)
	_corona.emitting = t >= CHARGE + TO_TIP.x and t < ZAP + ARC  # the tip crackles once the ball heads for it
	var at = ball(t)
	_ball.visible = at != null
	_ball_light.light_energy = 0.6 if at != null else 0.0
	if at != null:
		_ball.global_position = at
		_ball_light.global_position = at
		_ball.scale = Vector3.ONE * (0.85 + 0.15 * sin(t * 61.0) + 0.25 * pow(_curve(CHARGE_CURVE, t), 2.0))
	var ring := on_ring(t)
	_climb.set_shader_parameter("glow", 0.0 if ring < 0 else 0.5 + 0.9 * _curve(CHARGE_CURVE, t))
	if ring >= 0:
		_climb.set_shader_parameter("ring_h", RING_H[ring])
	# A crack while it hangs charged: only a flash where its spark leaves the surface (the user's
	# call: the whole round lighting up looked wrong), gone in a few frames.
	_crack.visible = false
	_crack_light.light_energy = 0.0
	for i in ZAP_HITS.size():
		var since: float = t - ZAPPING - ZAP_HITS[i]
		if tesla and since >= 0.0 and since < 0.15 and is_inside_tree():
			_crack.visible = true
			_crack.global_position = _round.global_transform * _spot(i)
			_crack_mat.albedo_color = Color(1.0, 1.5, 2.4) * (1.0 - since / 0.15)
			_crack_light.global_position = _crack.global_position
			_crack_light.light_energy = 0.8 * (1.0 - since / 0.15)  # a touch of blue on the round, not a white-out
	var b := t - ZAP
	_burst.visible = tesla != null and b >= 0.0 and b < 0.4
	if _burst.visible:  # swells fast and fades
		_burst.global_position = _tesla_top
		_burst.scale = Vector3.ONE * (1.0 + 14.0 * sqrt(b / 0.4))
		_burst_mat.albedo_color = Color(2.5, 2.9, 3.4) * (1.0 - b / 0.4)
	var sk := shock(t)
	_shock.set_shader_parameter("shock", sk)
	_round_corona.emitting = sk > 0.3 and not zapping(t)  # its sprites sit in the round: strikes only
	_hit.visible = arcing(t)
	if is_inside_tree():
		_round_corona.global_position = _round.global_transform * Vector3(0.0, 0.05, 0.0)
		_hit.global_position = _round.global_transform * TOP
		_hit.scale = Vector3.ONE * (0.8 + 0.4 * sin(t * 97.0))
	_corona.scale_amount_max = 0.3 + 0.9 * c
	_tesla_light.light_energy = 0.9 * c * (0.75 + 0.25 * sin(t * 37.0)) + (1.2 if arcing(t) else 0.0)
	var f := 0.0
	_flash.light_color = BOLT_BLUE
	if arcing(t):
		f = 6.0  # each strike throws the dark room into blue light for an instant
		if is_inside_tree():
			_flash.global_position = (_tesla_top + _round.global_transform * TOP) * 0.5
	elif cutting(t) > 0.0:
		f = 2.5 * cutting(t)
		_flash.light_color = Color(1.0, 0.7, 0.4)
		if is_inside_tree():
			_flash.global_position = _round.global_transform * Vector3(0.0, (CUTS[0] + CUTS[1]) * 0.5, 0.0)
	_flash.light_energy = f
	var rim := 0.0
	if arcing(t):
		rim = 0.7
	elif _crack.visible:
		rim = 0.3 * _crack_light.light_energy / 0.8
	_rim.light_energy = rim
	if is_inside_tree():
		var cam := get_viewport().get_camera_3d()
		var mid := _round.global_transform * Vector3(0.0, 0.05, 0.0)
		var away := Vector3(0.0, 0.0, -1.0) if cam == null else (mid - cam.global_position) * Vector3(1, 0, 1)
		_rim.global_position = mid + away.normalized() * 0.06 + Vector3(0.0, 0.03, 0.0)
	_draw_bolts(t)


## The whole round in this node's space: lying on the top, up to the hover standing, turning
## while it's wound, a jolt on every click, set down on the top at the end.
func round_pose(t: float) -> Transform3D:
	var shape := Basis.from_scale(Vector3.ONE * SCALE)
	var lying := Basis(Vector3.BACK, -PI / 2.0)  # its axis (+Y) along +X, tip that way
	if t < RISE.y:
		var k := _phase(t, RISE)
		var lift := _smooth(k)
		var turn := _smooth(clampf((k - 0.2) / 0.6, 0.0, 1.0))
		var at := Vector3(-0.5 * LEN, R, 0.0).lerp(Vector3(0.0, HOVER, 0.0), lift)
		return Transform3D(lying.slerp(Basis.IDENTITY, turn) * shape, at)
	var y := HOVER + 0.0018 * sin((t - RISE.y) * 2.2)  # never quite still while it hangs there
	for c: float in CLICKS:
		if t >= c:
			y -= 0.0012 * exp(-(t - c) * 35.0)  # knocked down a hair and back, no wobble
	if t >= SETTLE.x:
		var k := clampf((t - SETTLE.x) / (SETTLE.y - SETTLE.x), 0.0, 1.0)
		y = lerpf(HOVER, 0.0, k * k)  # let down, faster as it goes
		if t >= SETTLE.y:
			y = 0.003 * exp(-(t - SETTLE.y) * 16.0) * absf(sin((t - SETTLE.y) * 28.0))
	var spin := WIND_TURNS * TAU * _smooth(clampf((t - WIND.x) / (WIND.y - WIND.x), 0.0, 1.0))
	return Transform3D(Basis(Vector3.UP, spin) * shape, Vector3(0.0, y, 0.0))


## A part's transform inside the round (model space, m) at `t`, or null while it isn't there.
func part(n: String, t: float) -> Variant:
	match n:
		"Tip":
			if t < UNSCREW.x:
				return Transform3D(Basis.IDENTITY, Vector3(0.0, opened(t), 0.0))  # goes with the top half
			if t < UNSCREW.y:
				var k := (t - UNSCREW.x) / (UNSCREW.y - UNSCREW.x)
				return Transform3D(Basis(Vector3.UP, -TAU * 1.5 * _smooth(k)), Vector3(0.0, 0.012 * k, 0.0))  # backs out far enough to see
			if t < LIFT.y:
				var k := (t - LIFT.x) / (LIFT.y - LIFT.x)
				return Transform3D(Basis(Vector3.UP, -TAU * 1.5), Vector3(0.0, 0.012 + 0.16 * k * k, 0.0))
			return null
		"CaseWhole":
			return Transform3D.IDENTITY if t < CUT else null
		"CaseLow":
			return Transform3D.IDENTITY if t >= CUT else null
		"CaseHigh":
			return Transform3D(Basis.IDENTITY, Vector3(0.0, opened(t), 0.0)) if t >= CUT else null
		"CaseMid":
			var s := t - CUT
			if s < 0.0 or s > 0.9:
				return null
			var g := 9.8 / SCALE  # it falls in model space
			return Transform3D(Basis(Vector3.BACK, -7.0 * s), Vector3(0.16 * s, 0.05 * s - 0.5 * g * s * s, 0.03 * s))
		"Spool":
			if t < SPOOL.x:
				return null
			return Transform3D(Basis.IDENTITY, Vector3(-0.2 * (1.0 - _slam(_phase(t, SPOOL))), 0.0, 0.0))
		"RingLow":
			return _ring(t, RING_LOW, -0.12)
		"RingHigh":
			return _ring(t, RING_HIGH, 0.12)
		"Reactor":
			if t < REACTOR.x:
				return null
			return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.09 * (1.0 - _slam(_phase(t, REACTOR))), 0.0))
		"Nose":
			if t < NOSE.x:
				return null
			if t < PRESS.x:  # down hard, a turn on the way, and caught
				var k := _phase(t, NOSE)
				return Transform3D(Basis(Vector3.UP, TAU * _slam(k)), Vector3(0.0, lerpf(0.07, CATCH, _slam(k)), 0.0))
			return Transform3D(Basis.IDENTITY, Vector3(0.0, CATCH * (1.0 - _slam(_phase(t, PRESS))), 0.0))
	return Transform3D.IDENTITY


## How far the top half (and the bullet in it) stands off the cut, model m.
func opened(t: float) -> float:
	if t < CUT:
		return 0.0
	if t < CLOSE.x:
		return GAP * (1.0 - pow(1.0 - _phase(t, OPEN), 3.0))
	var k := _phase(t, CLOSE)
	return GAP * (1.0 - k * k)  # comes down faster as it goes, onto the click


## The cut's glow, 0 -> 1: the two lines heat up and go out as the slice comes free.
func cutting(t: float) -> float:
	var s := t - (CUT - 0.2)
	if s < 0.0 or s > 0.35:
		return 0.0
	return s / 0.2 if s < 0.2 else 1.0 - (s - 0.2) / 0.15


## How much of the winding is on, 0 -> 1.
func coil(t: float) -> float:
	return clampf((t - WIND.x) / (WIND.y - WIND.x), 0.0, 1.0)


## The Tesla coil's charge, 0 -> 1 up to the first strike, spent over the four.
func charge(t: float) -> float:
	if not tesla or t < CHARGE:
		return 0.0
	if t < ZAP:
		return _curve(CHARGE_CURVE, t)
	return maxf(1.0 - (t - ZAP) / (ARC + 0.3), 0.0)


## Which way the ball runs `s` s into the charge: each ring its own way; on the way up to the
## next it keeps going the way it was.
func _dir(s: float) -> float:
	for i in ORBITS.size():
		if s < ORBITS[i].y:
			return TURN_DIR[i] if s >= ORBITS[i].x or i == 0 else TURN_DIR[i - 1]
	return TURN_DIR[ORBITS.size() - 1]


## The ball's angle round the coil at `t`, rad.
func _turn(t: float) -> float:
	var at := clampf((t - CHARGE) * 100.0, 0.0, _turned.size() - 1.0)
	var i := mini(int(at), _turned.size() - 2)
	return lerpf(_turned[i], _turned[i + 1], at - i)


## The ring the ball is going round (0 lowest) at `t`, or -1 between rings and outside the charge.
func on_ring(t: float) -> int:
	if not tesla:
		return -1
	for i in ORBITS.size():
		if t >= CHARGE + ORBITS[i].x and t < CHARGE + ORBITS[i].y:
			return i
	return -1


## Where the ball is at `t`, world, or null outside the charge: just off ring i's edge, on its
## way up between two, or rising from the top ring to the tip, faster as it nears it.
func ball(t: float) -> Variant:
	if not tesla or t < CHARGE or t >= ZAP:
		return null
	var s := t - CHARGE
	var ang := _turn(t)
	for i in ORBITS.size():
		if s < ORBITS[i].y:
			if s >= ORBITS[i].x:
				return _round_ring(i, ang)
			var k := _smooth((s - ORBITS[i - 1].y) / (ORBITS[i].x - ORBITS[i - 1].y))
			return _round_ring(i - 1, ang).lerp(_round_ring(i, ang), k)
	var k := clampf((s - TO_TIP.x) / (TO_TIP.y - TO_TIP.x), 0.0, 1.0)
	return _round_ring(ORBITS.size() - 1, ang).lerp(_tesla_top, k * k)


func _round_ring(i: int, ang: float) -> Vector3:
	var r: float = RING_RAD[i] * COIL_SCALE * 1.12  # just off the edge
	var y: float = lerpf(_coil_y.x, _coil_y.y, RING_H[i])
	return Vector3(_axis.x + cos(ang) * r, y, _axis.y + sin(ang) * r)


## A per-0.1 s table from CHARGE, read at `t` between its samples.
func _curve(table: Variant, t: float) -> float:
	var at := clampf((t - CHARGE) * 10.0, 0.0, table.size() - 1.0)
	var i := mini(int(at), table.size() - 2)
	return lerpf(table[i], table[i + 1], at - i)


## Which strike is on at `t`, or -1.
func strike(t: float) -> int:
	if not tesla:
		return -1
	for i in STRIKES.size():
		var s: float = t - ZAP - STRIKES[i]
		if s >= 0.0 and s < STRIKE:
			return i
	return -1


## How electrified the round is, 0 -> 1: full while a strike is on it, dying away after each.
func shock(t: float) -> float:
	var s := 0.0
	if not tesla:
		return s
	for at: float in STRIKES:
		var d: float = t - ZAP - at
		if d >= 0.0:
			s = maxf(s, 1.0 if d < STRIKE else exp(-(d - STRIKE) * 4.0))
	return s


## A crackle burst of electric_zapping.wav is on.
func zapping(t: float) -> bool:
	if not tesla:
		return false
	for b: Vector2 in ZAP_BURSTS:
		if t >= ZAPPING + b.x and t < ZAPPING + b.y:
			return true
	return false


## The `i`th spot on the round a crack comes off, model space: up and round its body, nose to foot.
## Just off the surface, never inside it (the user's call: the sparks came out of the round).
func _spot(i: int) -> Vector3:
	var a := i * 2.4
	var y := 0.015 + fmod(i * 0.037, 0.085)
	var r := (BODY if y < 0.072 else 0.0045) * 1.15
	return Vector3(cos(a) * r, y, sin(a) * r)


## The way out of the round's surface at the `i`th spot, model space: straight out, a little up.
func _out(i: int) -> Vector3:
	var a := i * 2.4
	return Vector3(cos(a), 0.35, sin(a)).normalized()


## A strike is on and this frame of its flicker is lit.
func arcing(t: float) -> bool:
	var i := strike(t)
	return i >= 0 and int((t - ZAP - STRIKES[i]) * 45.0) % 4 != 3


## How dark the room is, 0 -> 1: down for the charge, back once the strikes are over.
func darkness(t: float) -> float:
	if not tesla:
		return 0.0
	return _smooth(_phase(t, DARK)) * (1.0 - _smooth(_phase(t, LIGHT)))


## How hard the strikes shake things, each kicking in and dying away fast.
func shake(t: float) -> float:
	var s := 0.0
	if not tesla:
		return s
	for at: float in STRIKES:
		if t >= ZAP + at:
			s += exp(-(t - ZAP - at) * 10.0)
	return s


## The reactor: dark until the first strike, a surge on each one, then lit for good at about half.
func glow(t: float) -> float:
	var s := t - (ZAP + 0.05)
	if s < 0.0:
		return 0.0
	if s < 0.15:
		return s / 0.15
	var settled := lerpf(1.0, 0.55, minf((s - 0.15) / (ARC + 0.6), 1.0))
	if s < ARC:
		settled *= 0.75 + 0.25 * sin(s * 90.0)
	for at: float in STRIKES:
		if t >= ZAP + at:
			settled += 0.8 * exp(-(t - ZAP - at) * 7.0)
	return minf(settled, 1.6)


func _ring(t: float, when: Vector2, from: float) -> Variant:
	if t < when.x:
		return null
	return Transform3D(Basis.IDENTITY, Vector3(0.0, from * (1.0 - _slam(_phase(t, when))), 0.0))


func _draw_bolts(t: float) -> void:
	_lines.clear_surfaces()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var heat := cutting(t)
	if heat > 0.0 and is_inside_tree():  # the two cut lines, glowing round the case
		_lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _line_mat)
		var eye := cam.global_position if cam else global_position + Vector3(0, 0, 1)
		for z: float in CUTS:
			var ring := []
			for i in 49:
				var a := TAU * i / 48.0
				ring.append(_round.global_transform * Vector3(BODY * 1.01 * cos(a), z, BODY * 1.01 * sin(a)))
			_ribbon(ring, 0.004 * heat, Color(1.0, 0.55, 0.2) * heat * 0.5, eye)
			_ribbon(ring, 0.0015, Color(1.0, 0.9, 0.7) * heat, eye)
		_lines.surface_end()
	if not tesla or t < CHARGE:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t * 20.0)  # a new shape 20 times a second
	var c := charge(t)
	var eye := cam.global_position if cam else _tesla_top + Vector3(0, 0, 1)
	var running := ball(t) != null and ball(t - 0.012) != null  # a trail needs two points
	var crackling := tesla != null and ZAP_HITS.any(func(h: float) -> bool: return t - ZAPPING - h >= 0.0 and t - ZAPPING - h < 0.12)  # an empty surface is an error
	if not running and not arcing(t) and not crackling:
		return
	_lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _bolt_mat)
	if running:  # the ball's trail: where it was over the last moments, thinning out behind
		var trail := []
		for k in 16:
			var p = ball(t - k * 0.012)
			if p == null:
				break
			trail.append(p)
		if trail.size() > 1:
			_stroke(trail, 0.018, 0.002, ICE * 0.35, eye)
			_stroke(trail, 0.006, 0.001, Color(0.55, 0.6, 0.65), eye)
		if c > 0.4:  # crackling off it, more as it speeds up
			for i in int(c * 3.0):
				var from: Vector3 = trail[0]
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
				_lightning(from, from + dir * rng.randf_range(0.02, 0.06), 0.0015, rng, eye, 0)
	if arcing(t):
		rng.seed = strike(t) * 1000 + int(t * 12.0)  # each strike its own channel, twitching as it flickers
		_lightning(_tesla_top, _round.global_transform * TOP, 0.006, rng, eye, 2)
		var ground := Vector3(_tesla_top.x + rng.randf_range(-0.35, 0.2), global_position.y, _tesla_top.z + rng.randf_range(-0.1, 0.25))
		_lightning(_tesla_top, ground, 0.004, rng, eye, 1)  # one goes to ground on the top
	if crackling:  # one small arc off the round's surface on each crack, there for an instant
		for i in ZAP_HITS.size():
			var since: float = t - ZAPPING - ZAP_HITS[i]
			if since >= 0.0 and since < 0.12:
				rng.seed = i * 97  # its own shape, held for its life: a vein, not static
				var from := _round.global_transform * _spot(i)
				var dir := (_round.global_transform.basis * _out(i)).normalized()
				dir = (dir + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.3), rng.randf_range(-0.3, 0.3))).normalized()
				_lightning(from, from + dir * rng.randf_range(0.04, 0.07), 0.0042 * (1.0 - since / 0.12 * 0.5), rng, eye, 0, 3, 0.1)
	_lines.surface_end()


## A bolt from a to b: a jagged channel, a white-hot core in a wider blue halo, thinning toward
## b; `forks` levels of branches split off it, shorter and thinner, off the way it's going.
func _lightning(a: Vector3, b: Vector3, width: float, rng: RandomNumberGenerator, eye: Vector3, forks: int, levels := 5, rough := 0.16) -> void:
	var pts := _zigzag(a, b, rng, levels, rough)
	_stroke(pts, width * 6.0, width * 2.0, BOLT_BLUE * 0.6, eye)
	_stroke(pts, width, width * 0.4, BOLT_CORE, eye)
	if forks <= 0:
		return
	for i in rng.randi_range(2, 4):
		var at := rng.randi_range(3, pts.size() - 6)
		var from: Vector3 = pts[at]
		var way: Vector3 = (pts[at + 3] - from).normalized()
		var dir := (way + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.7).normalized()
		_lightning(from, from + dir * a.distance_to(b) * rng.randf_range(0.12, 0.3), width * 0.45, rng, eye, forks - 1)


## A lightning path from a to b: halved five times, each new point thrown sideways off its segment
## by a share of its length that shrinks every halving, so it kinks hard at large scale, finely after.
func _zigzag(a: Vector3, b: Vector3, rng: RandomNumberGenerator, levels := 5, rough := 0.16) -> Array:
	var pts := [a, b]
	var amp := a.distance_to(b) * rough
	for level in levels:
		var next := [pts[0]]
		for i in pts.size() - 1:
			var p: Vector3 = pts[i]
			var q: Vector3 = pts[i + 1]
			var seg := (q - p).normalized()
			var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			off -= seg * off.dot(seg)  # sideways only: it doesn't bunch up along itself
			next.append_array([(p + q) * 0.5 + off * amp, q])
		pts = next
		amp *= 0.5
	return pts


## pts as a ribbon facing the eye, from w0 wide to w1, coloured `color`; across it the soft light's
## middle row, bright in the centre and gone at the edges.
func _stroke(pts: Array, w0: float, w1: float, color: Color, eye: Vector3) -> void:
	var n := pts.size() - 1
	for i in n:
		var p: Vector3 = pts[i]
		var q: Vector3 = pts[i + 1]
		var sp := (q - p).cross(eye - p).normalized() * lerpf(w0, w1, float(i) / n) * 0.5
		var sq := (q - p).cross(eye - q).normalized() * lerpf(w0, w1, float(i + 1) / n) * 0.5
		for v in [[p - sp, 1.0], [p + sp, 0.0], [q + sq, 0.0], [p - sp, 1.0], [q + sq, 0.0], [q - sq, 1.0]]:
			_lines.surface_set_color(color)
			_lines.surface_set_uv(Vector2(0.5, v[1]))
			_lines.surface_add_vertex(v[0])


## A line through pts as a ribbon `width` wide, turned to face the eye.
func _ribbon(pts: Array, width: float, color: Color, eye: Vector3) -> void:
	for i in pts.size() - 1:
		var p: Vector3 = pts[i]
		var q: Vector3 = pts[i + 1]
		var side := (q - p).cross(eye - p).normalized() * width * 0.5
		for v in [p - side, p + side, q + side, p - side, q + side, q - side]:
			_lines.surface_set_color(color)
			_lines.surface_add_vertex(v)


func _phase(t: float, span: Vector2) -> float:
	return clampf((t - span.x) / (span.y - span.x), 0.0, 1.0)


func _smooth(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## Speeds up all the way and stops dead at 1: a hard arrival, never past it.
func _slam(k: float) -> float:
	return k * k
