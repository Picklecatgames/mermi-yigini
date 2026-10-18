extends SceneTree
## Saves the settled starting heap (Pile.HEAP_FILE), then pours the floor spill as real rigid bullets onto the heap foot and the floor, lets Jolt
## settle them, and saves where they rest to Pile.SPILL_FILE. No overlaps, same on every peer.
##   Godot.exe --headless --path . --fixed-fps 60 -s res://tools/bake_spill.gd

const POUR_FRAMES := 240   # bullets arrive over this many frames, like a bucket emptying
const SETTLE_FRAMES := 360


func _initialize() -> void:
	# Loaded at runtime: pile.gd uses the GameState autoload, which a -s script can't see at parse time.
	var Pile: GDScript = load("res://scripts/pile.gd")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Pile.SPILL_FILE))  # start from the unsettled scatter
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Pile.HEAP_FILE))  # Pile settles a fresh heap
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	floor_col.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_col)
	root.add_child(floor_body)
	var pile = load("res://scenes/pile.tscn").instantiate()
	root.add_child(pile)
	await physics_frame
	var heap := FileAccess.open(Pile.HEAP_FILE, FileAccess.WRITE)
	heap.store_buffer(pile._h.to_byte_array())
	heap.close()

	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var targets: Array[Transform3D] = pile.scatter_spill(rng)
	var bodies: Array[RigidBody3D] = []
	var per_frame := ceili(targets.size() / float(POUR_FRAMES))
	for i in targets.size():
		var t := targets[i]
		t.origin.y += rng.randf_range(0.03, 0.12)  # dropped, not placed
		var body: RigidBody3D = Pile.make_body(t)
		root.add_child(body)
		bodies.append(body)
		if i % per_frame == per_frame - 1:
			await physics_frame
	for f in SETTLE_FRAMES:
		await physics_frame

	var buf := PackedFloat32Array()
	var kept := 0
	var lifted := 0
	for body in bodies:
		var t := body.global_transform
		if t.origin.y < -0.05 or t.origin.y > 1.0:
			continue  # fell through or got launched
		# Never below the ground: lowest point of the capsule on the floor or the heap.
		var axis := t.basis.orthonormalized().x
		var low: float = t.origin.y - absf(axis.y) * (Pile.BULLET_LENGTH * 0.5 - Pile.BULLET_RADIUS) - Pile.BULLET_RADIUS
		var ground: float = pile._height_smooth(pile.to_local(t.origin))
		if low < ground:
			t.origin.y += ground - low
			lifted += 1
		var s: float = Pile.BULLET_SCALE
		var b := t.basis.orthonormalized().scaled(Vector3.ONE * s)
		buf.append_array([b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z])
		kept += 1
	var file := FileAccess.open(Pile.SPILL_FILE, FileAccess.WRITE)
	file.store_buffer(buf.to_byte_array())
	file.close()
	var asleep := bodies.filter(func(b: RigidBody3D) -> bool: return b.sleeping).size()
	print("saved %d of %d bullets, %d asleep, %d lifted out of the ground" % [kept, bodies.size(), asleep, lifted])
	quit()
