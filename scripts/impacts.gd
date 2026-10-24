extends Node3D
## Where every shot goes, for every player: a faint air trail along it, a puff and a bullet hole. Concrete gets dust,
## sparks and chips; anything with a `cloth_hit()` (dummies) gets burlap dust and straw and a hole
## that smoulders for a few seconds; steel (group "steel") gets sparks and a grey lead splash.
## Marks ride on the part that moves when the target has a `decal_parent()`.

const FX := preload("res://scenes/impact_fx.tscn")
const FX_POOL := 6
const HOLE_POOL := 48
const HOLE_SIZE := 0.065  # m
## Decal width per surface: the mark is drawn to fill it, rays and all.
const MARK_SIZE := {MARK_CONCRETE: 0.09, MARK_BURLAP: 0.065, MARK_STEEL: 0.12}
const MARK_CONCRETE := 0
const MARK_BURLAP := 1
const MARK_STEEL := 2
const MARK_VARIANTS := 4
const MARK_PATH := "res://materials/env/decals/bullet_mark_%d_%d.png"
const SMOKE_TRAIL := preload("res://scenes/smoke_trail.tscn")
const SMOLDER_POOL := 8
const SMOLDER_TIME := 1.4  # s from a faint wisp to nothing
const TRAIL_SHADER := preload("res://materials/bullet_trail.gdshader")
const SMOKE_NOISE := preload("res://materials/smoke_noise.tres")
const TRAIL_POOL := 16  # the SMGs fire up to 10 a second
const TRAIL_TIME := 0.3  # s: a brief streak, gone before you can walk into it
const ROUND_SPEED := 400.0  # m/s the tracer races out at (a 9 mm round flies ~380)
const TRAIL_SKIP := 0.9  # m: other players' shots start this far along, roughly at their muzzle
const VIEWMODEL := preload("res://scripts/viewmodel.gd")
## A spinning gun's rounds stopped coming this long ago (its slow first rounds and the
## network's jitter, GameState.NET_JITTER, included): its loop gives way to the run-down.
const SPIN_GAP := 0.4  # s

var _fx: Array[Node3D] = []
var _next_fx := 0
var _holes: Array[Decal] = []
var _next_hole := 0
var _smolders: Array[GPUParticles3D] = []
var _heat: Array[float] = []  # per smolder, 1 → 0
var _next_smolder := 0
var _trails: Array[MeshInstance3D] = []
var _trail_life: Array[float] = []
var _next_trail := 0
var _shot_from := {}  # peer -> where its last shot started (fired comes just before shot_landed)
var _bounced := {}  # peer -> true while its round flies on off a ricochet plate
var _shot_sounds := {}  # peer -> AudioStreamPlayer3D for other players' shots
var _shot_stream: AudioStream  # ShotSound's own; a spinning gun swaps in its loop
var _spin_quiet := {}  # peer -> s since its last spinning-gun round, while the loop plays
# A few drawn variants of each mark, picked at random and spun, so no two look alike.
var _concrete_tex: Array[Texture2D] = _marks(MARK_CONCRETE)
var _burlap_tex: Array[Texture2D] = _marks(MARK_BURLAP)
var _splash_tex: Array[Texture2D] = _marks(MARK_STEEL)


func _ready() -> void:
	for i in FX_POOL:
		var f: Node3D = FX.instantiate()
		f.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # moved per shot
		add_child(f)
		_fx.append(f)
	for i in HOLE_POOL:
		_holes.append(_new_hole())
	for i in SMOLDER_POOL:
		_smolders.append(_new_smolder())
		_heat.append(0.0)
	for i in TRAIL_POOL:
		var m := MeshInstance3D.new()
		m.mesh = QuadMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = TRAIL_SHADER
		mat.set_shader_parameter("noise_tex", SMOKE_NOISE)
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = 1.0
		m.visible = false
		m.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(m)
		_trails.append(m)
		_trail_life.append(1.0)
	GameState.fired.connect(_on_fired)
	GameState.shot_landed.connect(_on_shot_landed)
	_prewarm.call_deferred()


## Compile the effect shaders at load, not on the first hit: everything plays once in front of
## the camera at a thousandth of its size (anything off-screen is culled and never compiles).
func _prewarm() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var hidden := cam.global_transform * Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0, 0, -1))
	for f in _fx:
		f.global_transform = hidden
		for p: GPUParticles3D in f.get_children():
			p.restart()
	_smolders[0].global_transform = hidden
	_smolders[0].emitting = true
	_heat[0] = 0.01  # a frame or two, then off
	_trails[0].global_transform = hidden
	_trail_life[0] = 0.98
	_trails[0].visible = true


## Someone else's shot flashes at their character's muzzle (scripts/remote_players.gd) and rings
## out there, in this world, so distance, direction and the shed's reverb (bus Dunya) shape it for
## every listener. One sound player per shooter, a copy of the first-person gun's ShotSound, so its
## stream and tuning stay in viewmodel.tscn. Spent shells stay with the shooter's own machine.
func _on_fired(peer: int, from: Vector3, dir: Vector3) -> void:
	if peer == GameState.local_peer():
		_shot_from[peer] = from
		return  # our own shot plays in first person (viewmodel.gd)
	var others := get_tree().get_first_node_in_group("remote_players")
	var who: Node3D = others.character(peer) if others else null
	if who and who.visible:
		who.shoot()
		from = who.muzzle_position()
	else:
		from += dir * TRAIL_SKIP  # no character yet: roughly where a muzzle would be
	_shot_from[peer] = from
	if not _shot_sounds.has(peer):
		var gun := get_tree().get_first_node_in_group("first_person_gun")
		if not gun:
			return
		var s: AudioStreamPlayer3D = gun.get_node("ShotSound").duplicate()
		add_child(s)
		_shot_sounds[peer] = s
		_shot_stream = gun.plain_shot
	var p: AudioStreamPlayer3D = _shot_sounds[peer]
	p.global_position = from
	var kit: Dictionary = VIEWMODEL.SETS.get(GameState.GUNS[GameState.player(peer).gun].id, {})
	# Like our own (viewmodel.gd SPIN_*): one loop while the rounds come, not a shot per round.
	if kit.has("spin"):
		_spin_quiet[peer] = 0.0
		if p.stream != VIEWMODEL.SPIN_LOOP or not p.playing:
			p.stream = VIEWMODEL.SPIN_LOOP
			p.play()
		return
	var shot: AudioStream = kit.get("shot", _shot_stream)
	if p.stream != shot:
		p.stream = shot
	p.play()


func _on_shot_landed(peer: int, at: Vector3, normal: Vector3, dir: Vector3, target: Node, _gold: int, _weak: bool, _combo: int) -> void:
	if _shot_from.has(peer):
		var gun := get_tree().get_first_node_in_group("first_person_gun")
		var bounced := _bounced.has(peer)
		var from: Vector3 = gun.muzzle_position() + dir * 0.05 if gun and peer == GameState.local_peer() and not bounced else _shot_from[peer]
		_trail(from, at)
		_bounced.erase(peer)
		if target and target.is_in_group("ricochet"):  # the round flies on from here
			_shot_from[peer] = at
			_bounced[peer] = true
	if target == null:
		return  # into the sky
	# Armour (group "steel") on a cloth dummy sparks like steel.
	var soft := target.has_method("cloth_hit") and not target.is_in_group("steel")
	var steel := target.is_in_group("steel")
	if soft:  # snap from the coarse hit box onto the cloth itself
		var cloth: Array = target.cloth_hit(at, dir)
		if cloth:
			at = cloth[0]
			normal = cloth[1]
	var basis := _basis_on(normal)
	var f := _fx[_next_fx]
	_next_fx = (_next_fx + 1) % FX_POOL
	f.global_transform = Transform3D(basis, at + normal * 0.01)
	for part in (["Burlap", "Straw"] if soft else ["Sparks"] if steel else ["Dust", "Sparks", "Chips"]):
		(f.get_node(part) as GPUParticles3D).restart()
	if not is_instance_valid(_holes[_next_hole]):  # went with a target that was removed
		_holes[_next_hole] = _new_hole()
	var d := _holes[_next_hole]
	_next_hole = (_next_hole + 1) % HOLE_POOL
	var parent: Node3D = target.decal_parent(at) if target.has_method("decal_parent") else self
	if d.get_parent() != parent:
		d.reparent(parent, false)
	var kind := MARK_BURLAP if soft else MARK_STEEL if steel else MARK_CONCRETE
	var marks: Array[Texture2D] = [_concrete_tex, _burlap_tex, _splash_tex][kind]
	d.texture_albedo = marks[randi() % marks.size()]
	# A dummy's hitbox is coarse; its cloth can sit centimetres in front of or behind the hit.
	var w: float = MARK_SIZE[kind]
	d.size = Vector3(w, 0.4 if soft else 0.08, w)
	d.global_transform = Transform3D(basis, at)
	d.scale = Vector3.ONE * randf_range(0.8, 1.2)
	d.visible = true
	if soft:
		_smolder(parent, Transform3D(Basis(), at + normal * 0.006))  # right at the scorched hole


## A thin thread of smoke from a fresh hole, thinning out over SMOLDER_TIME. It is parented to
## the part that was hit, so it follows a swinging dummy; the smoke itself stays in the world.
func _smolder(parent: Node3D, xf: Transform3D) -> void:
	var i := _next_smolder
	_next_smolder = (_next_smolder + 1) % SMOLDER_POOL
	if not is_instance_valid(_smolders[i]):  # went with a target that was removed
		_smolders[i] = _new_smolder()
	var s := _smolders[i]
	if s.get_parent() != parent:
		s.reparent(parent, false)
	s.global_transform = xf
	s.restart()  # drop the last hole's threads; nothing is drawn between the two holes
	_heat[i] = 1.0
	s.emitting = true


## Bullet holes and smoulders move into whatever they mark, so a removed target takes its share
## of the pool with it; these make the replacements.
func _new_hole() -> Decal:
	var d := Decal.new()
	d.normal_fade = 0.3  # deep boxes, but not through to the far side
	d.visible = false
	d.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(d)
	return d


func _new_smolder() -> GPUParticles3D:
	var s: GPUParticles3D = SMOKE_TRAIL.instantiate()
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Pooled emitters jump from hole to hole; interpolated emission would smear smoke
	# along that jump, out of empty cloth.
	s.interpolate = false
	# Scorched burlap: a couple of hair-thin, faint threads, not a burning fire.
	s.amount = 4
	s.lifetime = 1.6
	var ribbon := (s.draw_pass_1 as RibbonTrailMesh).duplicate() as RibbonTrailMesh
	ribbon.size *= 0.45
	var mat := ribbon.material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("opacity", 0.2)
	ribbon.material = mat
	s.draw_pass_1 = ribbon
	add_child(s)
	return s


func _trail(from: Vector3, to: Vector3) -> void:
	var span := to - from
	if span.length() < 0.5:
		return
	var i := _next_trail
	_next_trail = (_next_trail + 1) % TRAIL_POOL
	var m := _trails[i]
	var x := span
	var y := x.cross(Vector3.UP if absf(x.normalized().y) < 0.95 else Vector3.RIGHT).normalized()
	m.global_transform = Transform3D(Basis(x, y, x.normalized().cross(y)), (from + to) * 0.5)
	(m.material_override as ShaderMaterial).set_shader_parameter("length_m", span.length())
	(m.material_override as ShaderMaterial).set_shader_parameter("head", 0.0)
	_trail_life[i] = 0.0
	m.visible = true


func _process(delta: float) -> void:
	for peer: int in _spin_quiet.keys():
		_spin_quiet[peer] += delta
		if _spin_quiet[peer] > SPIN_GAP:
			_spin_quiet.erase(peer)
			_shot_sounds[peer].stream = VIEWMODEL.SPIN_STOP
			_shot_sounds[peer].play()
	for i in TRAIL_POOL:
		if _trail_life[i] >= 1.0:
			continue
		_trail_life[i] = minf(_trail_life[i] + delta / TRAIL_TIME, 1.0)
		var mat := _trails[i].material_override as ShaderMaterial
		mat.set_shader_parameter("life", _trail_life[i])
		mat.set_shader_parameter("head", _trail_life[i] * TRAIL_TIME * ROUND_SPEED)
		_trails[i].visible = _trail_life[i] < 1.0
	for i in SMOLDER_POOL:
		if _heat[i] <= 0.0:
			continue
		if not is_instance_valid(_smolders[i]):
			_heat[i] = 0.0
			continue
		_heat[i] = maxf(_heat[i] - delta / SMOLDER_TIME, 0.0)
		_smolders[i].amount_ratio = _heat[i]
		_smolders[i].emitting = _heat[i] > 0.0


## +Y along the surface normal, spun randomly around it.
static func _basis_on(normal: Vector3) -> Basis:
	var side := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := Basis(side, normal, side.cross(normal)).orthonormalized()
	return b.rotated(normal, randf() * TAU)


## The drawn variants of one kind of bullet mark (tools/draw_bullet_marks.gd makes them).
static func _marks(kind: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for v in MARK_VARIANTS:
		out.append(load(MARK_PATH % [kind, v]))
	return out
