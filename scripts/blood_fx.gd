extends Node3D
## Real blood (tools/build_blood.py, from ActionVFX footage and scans): filmed mist puffs where a round
## goes in (materials/blood_mist.gdshader) and decals on the floor and walls. One of these per world,
## made on first use; it holds every mist quad and every decal, so a long wave can't pile them up: past
## MAX_DECALS / MAX_MISTS the oldest is taken back.
##
## Visual only. Every call takes a RandomNumberGenerator the caller seeded from the zombie and the hit
## (zombie_body.gd), and the walls are found with a ray against the static world, so every peer draws
## the same blood in the same places.
##   BloodFx.mist(world, at, dir, rng, size, life)
##   BloodFx.wall(world, at, dir, rng, reach, width)  # the round flew on: a spray where it lands
##   BloodFx.ground(world, at, floor_y, kinds, rng, width, along, grow)

const MAX_DECALS := 64
const MAX_MISTS := 16
## A hit is a short red puff that thins out in under half a second, not the film's two-second cloud:
## the puff's first MIST_FRAMES frames squeezed into `life` s, fading over the last MIST_FADE of it.
const MIST_FRAMES := 44.0
const MIST_FADE := 0.6
const DIR := "res://assets/vfx/blood/"
const MISTS := [&"curl", &"puff", &"small", &"streak", &"burst"]
## Where in each square the puff comes out (mist.json, written by build_blood.py).
const EMIT := {
	&"curl": Vector2(0.296, 0.295), &"puff": Vector2(0.089, 0.414), &"small": Vector2(0.154, 0.361),
	&"streak": Vector2(0.35, 0.376), &"burst": Vector2(0.284, 0.264),
}
## Decal sets (assets/vfx/blood/decals/<name>_albedo/_normal/_orm.png). Sprays lie along +u with the
## dense end at u = 0, so they can point the way the blood flew.
const SETS := {
	&"pool": 6, &"drop": 4, &"smear": 3, &"mist": 2, &"spray": 4, &"hand": 2, &"foot": 1,
}
const WALL_MASK := 1  # GameState.SHOT_MASK: walls, floor, pillars

static var _textures := {}  # name -> [albedo, normal, orm]
static var _materials := {}  # mist name -> ShaderMaterial
static var _quad: QuadMesh
static var _warming := {}  # path -> asked of the loader thread (warm())

var _decals: Array[Decal] = []
var _next_decal := 0
var _grow := {}  # decal -> its tween, killed when the decal is taken back
var _mists: Array[MeshInstance3D] = []
var _next_mist := 0
var _age := {}  # mist -> [s so far, life s]


## A puff of mist at `at`, blown on along `dir`. `size`: the square's side (m); `life`: s it lasts.
static func mist(world: Node, at: Vector3, dir: Vector3, rng: RandomNumberGenerator, size := 0.6, life := 0.45) -> void:
	_of(world)._mist(at, dir, rng, size, life)


## A spray on whatever wall or pillar is within `reach` m behind `at` along `dir`, pointing the way the
## blood flew. Nothing if it's open air, or another zombie, or anything that moves.
static func wall(world: Node, at: Vector3, dir: Vector3, rng: RandomNumberGenerator, reach := 2.5, width := 0.8) -> void:
	var fx := _of(world)
	var space := fx.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at, at + dir.normalized() * reach, WALL_MASK)
	var hit := space.intersect_ray(q)
	if hit.is_empty() or not hit.collider is StaticBody3D or hit.collider.has_meta("zombie") \
			or (hit.collider as Node).is_in_group("target"):
		return
	var n: Vector3 = hit.normal
	if n.y > 0.7:  # the floor: the zombie's own floor marks do that
		return
	var far := clampf(at.distance_to(hit.position) / reach, 0.0, 1.0)
	fx._place(hit.position, n, dir, &"spray" if far < 0.6 else &"mist", rng, width * lerpf(0.8, 1.4, far))


## A decal flat on the floor at `at` (y from `floor_y`), one of `kinds` picked by `rng`. `along`: the way
## it points (sprays), zero for a turn picked by `rng`. `grow` > 0: it spreads out to `width` over that
## many seconds from a fifth of it. Returns the decal.
static func ground(world: Node, at: Vector3, floor_y: float, kinds: Array, rng: RandomNumberGenerator,
		width: float, along := Vector3.ZERO, grow := 0.0) -> Decal:
	var fx := _of(world)
	var kind: StringName = kinds[rng.randi() % kinds.size()]
	var d: Decal = fx._place(Vector3(at.x, floor_y, at.z), Vector3.UP, along, kind, rng, width)
	if grow > 0.0:
		var full := d.size
		d.size = Vector3(full.x * 0.2, full.y, full.z * 0.2)
		var t := d.create_tween()
		t.tween_property(d, "size", full, grow).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		fx._grow[d] = t
	return d


## Starts reading every decal set and mist off the disk on a thread, so none is loaded in the middle
## of a fight: each took 15-70 ms the first time it came up (tools/spike_probe.gd). waves.gd calls it
## with the hall; whatever is asked for before it is in waits for it then.
static func warm() -> void:
	var paths: Array[String] = []
	for kind: StringName in SETS:
		for i in SETS[kind]:
			for part in ["_albedo.png", "_normal.png", "_orm.png"]:
				paths.append(DIR + "decals/%s_%d%s" % [kind, i, part])
	for name: StringName in MISTS:
		paths.append(DIR + "mist_%s.png" % name)
	for path in paths:
		if not _warming.has(path):
			_warming[path] = ResourceLoader.load_threaded_request(path) == OK


static func decal_count(world: Node) -> int:
	var fx := world.get_node_or_null(^"BloodFx")
	return 0 if fx == null else fx._decals.size()


static func _of(world: Node) -> Node3D:
	var fx := world.get_node_or_null(^"BloodFx")
	if fx == null:
		fx = load("res://scripts/blood_fx.gd").new()
		fx.name = "BloodFx"
		world.add_child(fx)
	return fx


func _place(at: Vector3, n: Vector3, along: Vector3, kind: StringName, rng: RandomNumberGenerator, width: float) -> Decal:
	var d: Decal
	if _decals.size() < MAX_DECALS:
		d = Decal.new()
		d.normal_fade = 0.4
		d.upper_fade = 0.2
		d.lower_fade = 0.4
		d.cull_mask = 1
		add_child(d)
		_decals.append(d)
	else:
		d = _decals[_next_decal]
		_next_decal = (_next_decal + 1) % MAX_DECALS
		if _grow.has(d):
			(_grow[d] as Tween).kill()
			_grow.erase(d)
	var tex := _tex(kind, rng.randi() % SETS[kind])
	d.texture_albedo = tex[0]
	d.texture_normal = tex[1]
	d.texture_orm = tex[2]
	d.albedo_mix = 1.0
	# the decal projects down its -Y: Y out of the surface, X the way the blood went
	var x := along - n * along.dot(n)
	if x.length() < 0.05:
		var side := n.cross(Vector3.FORWARD if absf(n.z) < 0.9 else Vector3.RIGHT).normalized()
		x = side.rotated(n, rng.randf() * TAU)
	x = x.normalized()
	var basis := Basis(x, n, x.cross(n))
	var w := width * rng.randf_range(0.85, 1.15)
	d.size = Vector3(w, 0.3, w)
	d.global_transform = Transform3D(basis, at + n * 0.08)
	d.visible = true
	return d


## Every mist drawn once at `at` (a speck in front of the camera), so its shader and atlases are in
## before the first hit (zombie_body.gd prewarm()). Then, once warm() has read them all, every decal
## set is held in the renderer's decal atlas by a hidden decal of its own: a texture new to the atlas
## had it built over again, ~10 ms, at the first splash of each kind and whenever the pool let one go.
static func prewarm(world: Node, at: Vector3) -> void:
	var fx := _of(world)
	var rng := RandomNumberGenerator.new()
	for name: StringName in MISTS:
		fx._mist(at, Vector3.UP, rng, 0.001, 0.1, name)
	while fx.is_inside_tree() and _warming.keys().any(func(path: String) -> bool:
			return _warming[path] and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS):
		await fx.get_tree().process_frame
	if not fx.is_inside_tree():
		return
	for kind: StringName in SETS:
		for i in SETS[kind]:
			var tex := _tex(kind, i)
			var d := Decal.new()
			d.texture_albedo = tex[0]
			d.texture_normal = tex[1]
			d.texture_orm = tex[2]
			d.visible = false
			fx.add_child(d)


func _mist(at: Vector3, dir: Vector3, rng: RandomNumberGenerator, size: float, life: float, name := &"") -> void:
	var m: MeshInstance3D
	if _mists.size() < MAX_MISTS:
		if _quad == null:
			_quad = QuadMesh.new()
		m = MeshInstance3D.new()
		m.mesh = _quad
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_mists.append(m)
	else:
		m = _mists[_next_mist]
		_next_mist = (_next_mist + 1) % MAX_MISTS
	if name == &"":
		name = MISTS[rng.randi() % MISTS.size()]
	m.material_override = _mist_material(name)
	size *= rng.randf_range(0.85, 1.2)
	m.custom_aabb = AABB(Vector3.ONE * -size, Vector3.ONE * size * 2.0)  # the shader moves the corners
	m.global_transform = Transform3D(Basis(), at)
	m.set_instance_shader_parameter(&"size", size)
	m.set_instance_shader_parameter(&"dir", dir.normalized())
	m.set_instance_shader_parameter(&"emit", EMIT[name])
	m.set_instance_shader_parameter(&"flip", -1.0 if rng.randf() < 0.5 else 1.0)
	m.set_instance_shader_parameter(&"frame", 0.0)
	m.set_instance_shader_parameter(&"fade", 1.0)
	m.visible = true
	_age[m] = [0.0, life * rng.randf_range(0.85, 1.15)]


func _process(delta: float) -> void:
	for m: MeshInstance3D in _age.keys():
		var a: Array = _age[m]
		a[0] += delta
		var k: float = a[0] / a[1]
		if k >= 1.0:
			m.visible = false
			_age.erase(m)
			continue
		# fast at first, the way a puff bursts out and then hangs
		m.set_instance_shader_parameter(&"frame", (1.0 - pow(1.0 - k, 1.6)) * MIST_FRAMES)
		m.set_instance_shader_parameter(&"fade", clampf((1.0 - k) / MIST_FADE, 0.0, 1.0))


static func _mist_material(name: StringName) -> ShaderMaterial:
	if not _materials.has(name):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://materials/blood_mist.gdshader")
		mat.set_shader_parameter(&"atlas", _load(DIR + "mist_%s.png" % name))
		_materials[name] = mat
	return _materials[name]


static func _tex(kind: StringName, i: int) -> Array:
	var key := "%s_%d" % [kind, i]
	if not _textures.has(key):
		var base := DIR + "decals/" + key
		_textures[key] = [_load(base + "_albedo.png"), _load(base + "_normal.png"), _load(base + "_orm.png")]
	return _textures[key]


static func _load(path: String) -> Resource:
	if _warming.get(path, false):
		_warming[path] = false
		return ResourceLoader.load_threaded_get(path)
	return load(path)
