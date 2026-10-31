extends SceneTree
## Headless check for the blood (scripts/blood_fx.gd, zombie_body.gd, zombie_gibs.gd): two worlds, as
## two peers would have them, the same zombie (same seed) hit by the same rounds and blown apart the
## same way. Their decals and mist must match one for one, a wall behind the zombie takes a spray,
## the torn-off head leaves flesh on the neck, and a long burst never goes past MAX_DECALS.
##   Godot.exe --headless --path . -s res://tools/blood_check.gd --quit-after 600

const BODY := preload("res://scripts/zombie_body.gd")
const BLOOD := preload("res://scripts/blood_fx.gd")

var _fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var a := _world(Vector3(0, 0, 0))
	var b := _world(Vector3(0, 0, 50))  # far apart, so neither's wall ray finds the other's wall
	await physics_frame
	await physics_frame
	for i in 6:
		_hit(a, i, i == 5)
		_hit(b, i, i == 5)
	var gone_a: float = a.body.die(&"head")
	b.body.die(&"head")
	await create_timer(1.6).timeout  # the gibs land and splash
	var da := _decals(a.world)
	var db := _decals(b.world)
	_expect(da.size() > 6 and da.size() == db.size(), "both peers lay the same number of decals (%d, %d)" % [da.size(), db.size()])
	var same := true
	for i in mini(da.size(), db.size()):
		var x: Decal = da[i]
		var y: Decal = db[i]
		var off := x.global_position - (y.global_position - Vector3(0, 0, 50))
		if off.length() > 0.05 or x.texture_albedo != y.texture_albedo or not x.global_basis.is_equal_approx(y.global_basis):
			same = false
			print("  decal %d: %s vs %s" % [i, x.texture_albedo.resource_path.get_file(), y.texture_albedo.resource_path.get_file()])
	_expect(same, "every decal in the same place with the same texture on both")
	var on_wall := da.filter(func(d: Decal) -> bool: return d.global_basis.y.y < 0.5)
	_expect(not on_wall.is_empty(), "the wall behind took a spray (%d)" % on_wall.size())
	var ma := _mists(a.world)
	var mb := _mists(b.world)
	_expect(ma.size() >= 6 and ma.size() == mb.size(), "mist puffs on both (%d, %d)" % [ma.size(), mb.size()])
	var mist_same := true
	for i in mini(ma.size(), mb.size()):
		if ma[i].material_override != mb[i].material_override \
				or ma[i].get_instance_shader_parameter(&"size") != mb[i].get_instance_shader_parameter(&"size"):
			mist_same = false
	_expect(mist_same, "the same films at the same sizes")
	var stump: Array = a.body.find_children("*", "MeshInstance3D", true, false).filter(
			func(m: MeshInstance3D) -> bool: return m.material_override == BODY.GIBS.material(3))
	_expect(stump.size() == 1, "raw flesh on the neck")
	_expect(a.body.find_children("*", "Decal", true, false).size() >= 1, "blood soaked over it")
	var gibs: Array = a.world.find_children("*", "MeshInstance3D", true, false).filter(
			func(m: MeshInstance3D) -> bool: return m.material_override == BODY.FLESH and not a.body.is_ancestor_of(m))
	_expect(gibs.size() >= 9, "the head's pieces are flesh (%d)" % gibs.size())
	_expect(gone_a > 0.0, "the death clip plays")
	# A minigun's worth on one zombie: the decals stop at the cap and keep being reused.
	var c := _world(Vector3(0, 0, 100))
	await physics_frame
	for i in 300:
		_hit(c, i, i % 7 == 0)
	_expect(BLOOD.decal_count(c.world) == BLOOD.MAX_DECALS, "300 hits, %d decals (cap %d)" % [BLOOD.decal_count(c.world), BLOOD.MAX_DECALS])
	_expect(_mists(c.world).size() == BLOOD.MAX_MISTS, "mist capped at %d" % BLOOD.MAX_MISTS)
	await create_timer(3.0).timeout
	_expect(_mists(c.world).all(func(m: MeshInstance3D) -> bool: return not m.visible), "the mist is gone after its film")
	print("blood_check: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## A floor, a wall 1.5 m behind the zombie (it faces -Z, rounds come from +Z), and the zombie.
func _world(origin: Vector3) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	world.global_position = origin
	for box in [[Vector3(20, 0.2, 20), Vector3(0, -0.1, 0)], [Vector3(6, 4, 0.3), Vector3(0, 2, -1.5)]]:
		var s := StaticBody3D.new()
		var c := CollisionShape3D.new()
		c.shape = BoxShape3D.new()
		c.shape.size = box[0]
		s.add_child(c)
		world.add_child(s)
		s.position = box[1]
	var holder := Node3D.new()
	world.add_child(holder)
	var body: Node3D = BODY.new()
	body.setup(&"walker", 77)
	holder.add_child(body)
	return {"world": world, "body": body, "origin": origin}


func _hit(w: Dictionary, i: int, head: bool) -> void:
	var o: Vector3 = w.origin
	var at := o + Vector3(sin(i * 1.3) * 0.15, 1.7 if head else 1.2 + cos(i * 0.7) * 0.2, 0.1)
	w.body.wound(at, Vector3(sin(i) * 0.1, -0.05, -1.0).normalized(), head)


func _decals(world: Node) -> Array:
	return world.find_children("*", "Decal", true, false)


func _mists(world: Node) -> Array:
	var fx := world.get_node_or_null(^"BloodFx")
	return [] if fx == null else fx.find_children("*", "MeshInstance3D", false, false)


func _expect(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1
