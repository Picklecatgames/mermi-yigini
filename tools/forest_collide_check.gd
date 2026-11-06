extends SceneTree
## Nothing in the wood is walked through, and nothing stands inside anything (2026-11-06, the user: "some
## trees are walked through"; a trunk standing in the middle of a car's bonnet). Reads the built scene.
## Two checks, each against what is drawn, not against the collision it is checking:
## 1. Walk-through: for every tree, at 0.5, 1.0 and 1.5 m over the ground, the trunk as the mesh draws it
##    (the plane cuts the tree's own triangles; the cut nearest its foot), and from 8 sides a ball the
##    player's capsule's width moved in at it until the physics stops it. Further into the wood than SINK:
##    walked through. The same for every floor thing, story prop and wasteland prop tall enough to be in
##    the way (build_world.gd FLOOR_SOLID_FROM), at its own height.
## 2. Inside each other: a trunk's drawn wood (up to 2.4 m, near its axis) inside a prop's or a floor
##    thing's box (shrunk a little: a box is wider than a rock); two trunks through each other; a tree on the pad.
## Results per tree kind and per thing.
##   Godot.exe --headless --path . -s res://tools/forest_collide_check.gd
const R := 0.35  # scenes/player.tscn body_shape
const HEIGHTS := [0.5, 1.0, 1.5]
const DIRS := 8
const SINK := [0.3, 0.15, 0.15]  # m the ball may reach into the drawn wood at each height: a root's flare at the foot is wider than a body's knee
const FAT := 0.6  # m of air between ball and wood: noted
const SOLID_FROM := 0.5  # build_world.gd FLOOR_SOLID_FROM
const BAND := 2.4
const SHRINK := 0.85  # a box's share that is really the thing
const PAD := Rect2(-6.0, -14.0, 32.0, 28.0)

var space: PhysicsDirectSpaceState3D
var exclude: Array[RID] = []
var ball := SphereShape3D.new()
var debug := "--debug" in OS.get_cmdline_user_args()
var last_push := ""
var dbg_n := 0
var near := 0.0  # --near=m: only what stands this close to the clearing's middle (a quick look)


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--near="):
			near = a.trim_prefix("--near=").to_float()
	_run.call_deferred()


func _run() -> void:
	var world: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	var forest: Node3D = world.get_node("Forest")
	var kinds: Array = forest.get_meta("tree_kinds", [])
	var rows: Array = forest.get_meta("stand")
	var floor_kinds: Array = forest.get_meta("floor_kinds", [])
	var floor_rows: Array = forest.get_meta("floor_rows", [])
	var moved := [forest]
	for n in ["Wasteland"]:
		if world.has_node(n):
			moved.append(world.get_node(n))
	for n: Node in moved:
		world.remove_child(n)
		if n == forest:
			n.set_script(null)
		root.add_child(n)
	await physics_frame
	await physics_frame
	space = forest.get_world_3d().direct_space_state
	ball.radius = R
	if forest.has_node("RimBelt"):
		exclude.append((forest.get_node("RimBelt") as CollisionObject3D).get_rid())
	if kinds.is_empty():
		print("forest_collide_check: the scene has no tree_kinds meta (build_world.gd too old)")
		quit(1)
		return
	if debug:
		var post: Vector3 = (rows[0][4] as PackedVector3Array)[1]
		var qs := PhysicsShapeQueryParameters3D.new()
		qs.shape = ball
		qs.transform = Transform3D(Basis(), post)
		print("debug: overlap at a post: ", space.intersect_shape(qs).size(), "; ray: ", space.intersect_ray(PhysicsRayQueryParameters3D.create(post + Vector3(3, 0, 0), post)))
		qs.transform = Transform3D(Basis(), post + Vector3(3, 0, 0))
		qs.motion = Vector3(-3, 0, 0)
		print("debug: cast at a post: ", space.cast_motion(qs), " physics engine: ", ProjectSettings.get_setting("physics/3d/physics_engine"))
	var buckets := []
	for k: Array in kinds:
		buckets.append(_buckets(k[1]))
	# 1. Trees.
	var per_kind := {}  # name -> [tested, through, fat, no trunk seen]
	var through_at := []
	var tree_pts := {}  # tree index -> its drawn wood near the axis, world
	for i in rows.size():
		var row: Array = rows[i]
		if row.size() < 8:
			continue
		var kind: int = row[5]
		var xf: Transform3D = row[6]
		if near > 0.0 and Vector2(xf.origin.x, xf.origin.z).distance_to(Vector2(8, 0)) > near:
			continue
		var name: String = kinds[kind][0]
		if not per_kind.has(name):
			per_kind[name] = [0, 0, 0, 0]
		per_kind[name][0] += 1
		var ground: float = row[2]
		var tris := _band(buckets[kind], xf, ground)
		var foot := Vector2(xf.origin.x, xf.origin.z)
		var seen := false
		var bad := false
		var fat := false
		for hi in HEIGHTS.size():
			var y: float = ground + HEIGHTS[hi]
			var piece := _trunk_cut(tris, y, foot)
			if piece.is_empty():
				continue
			seen = true
			var r := _push(piece.segs, piece.centre, y, SINK[hi])
			if r == 1 and debug and per_kind[name][1] == 0 and not bad:
				print("  %s at %s, h %.1f: wood's middle %s, %d cut pieces; posts %s radii %s; %s" % [name, xf.origin, HEIGHTS[hi], piece.centre, piece.segs.size() / 2, row[4], row[7], last_push])
			bad = bad or r == 1
			fat = fat or r == 2
		if not seen:
			per_kind[name][3] += 1
		if bad:
			per_kind[name][1] += 1
			if through_at.size() < 12:
				through_at.append("%s at (%.1f, %.1f)" % [name, foot.x, foot.y])
		if fat:
			per_kind[name][2] += 1
	print("(trees looked at in %.0f s)" % (Time.get_ticks_msec() / 1000.0))
	var tree_fail := 0
	print("trees (kind: tested, walked through, collision fat, no trunk cut):")
	var names := per_kind.keys()
	names.sort()
	for n: String in names:
		var v: Array = per_kind[n]
		tree_fail += v[1]
		print("  %-34s %5d %4d %4d %4d%s" % [n, v[0], v[1], v[2], v[3], "  FAIL" if v[1] > 0 else ""])
	for s: String in through_at:
		print("  walked through: ", s)
	# Things: floor rows and props, each [name, tris world, box local, xf].
	var things := []
	var kind_tris := {}
	for fr: Array in floor_rows:
		var fk: Array = floor_kinds[fr[1]]
		if not kind_tris.has(fr[1]):
			kind_tris[fr[1]] = TREE_STAND_TRIS.call(fk[1])
		things.append([String(fr[0]) + ":" + String(fk[0]), kind_tris[fr[1]], fr[2], fk[2], fr[3] if fr.size() > 3 else NAN])
	for n: Node in moved:
		if n != forest:
			_props_of(n, things)
	if forest.has_node("Abandoned"):
		_props_of(forest.get_node("Abandoned"), things)
	var per_thing := {}  # name -> [tested, through, fat, trunk inside]
	var thing_through := []
	var inside_at := []
	var grid := {}  # trees by 4 m cell
	for i in rows.size():
		var row: Array = rows[i]
		if row.size() < 8:
			continue
		var c := Vector2i(floori(row[6].origin.x / 4.0), floori(row[6].origin.z / 4.0))
		if not grid.has(c):
			grid[c] = []
		grid[c].append(i)
	for t: Array in things:
		var name: String = t[0]
		if not per_thing.has(name):
			per_thing[name] = [0, 0, 0, 0]
		var xf: Transform3D = t[2]
		var box: AABB = t[3]
		if near > 0.0 and Vector2(xf.origin.x, xf.origin.z).distance_to(Vector2(8, 0)) > near:
			continue
		var wbox: AABB = xf * box
		var ground: float = wbox.position.y if t.size() < 5 or is_nan(t[4]) else t[4]
		var tall := wbox.end.y - ground
		# Inside each other: any tree near whose drawn wood lies in the box.
		var small := AABB(box.get_center() - box.size * SHRINK * 0.5, box.size * SHRINK)
		var inv := xf.affine_inverse()
		var hit := false
		var reach := Rect2(wbox.position.x, wbox.position.z, wbox.size.x, wbox.size.z).grow(1.0)
		for ci in range(floori((wbox.position.x - 2.0) / 4.0), floori((wbox.end.x + 2.0) / 4.0) + 1):
			for cj in range(floori((wbox.position.z - 2.0) / 4.0), floori((wbox.end.z + 2.0) / 4.0) + 1):
				for ti: int in grid.get(Vector2i(ci, cj), []):
					if hit:
						break
					if not reach.has_point(Vector2(rows[ti][6].origin.x, rows[ti][6].origin.z)):
						continue
					if not tree_pts.has(ti):
						tree_pts[ti] = _near_axis(buckets[rows[ti][5]], rows[ti][6], rows[ti][2])
					for p: Vector3 in tree_pts[ti]:
						if small.has_point(inv * p):
							hit = true
							if inside_at.size() < 16:
								inside_at.append("%s at (%.1f, %.1f): %s" % [name, xf.origin.x, xf.origin.z, kinds[rows[ti][5]][0]])
							break
		if hit:
			per_thing[name][3] += 1
		if tall < SOLID_FROM:
			continue
		per_thing[name][0] += 1
		var tris := PackedVector3Array()
		for p: Vector3 in t[1]:
			tris.append(xf * p)
		var y := ground + minf(0.45, tall * 0.6)
		var segs := _slice(tris, y)
		if segs.is_empty():
			continue
		var bb := Rect2(segs[0], Vector2.ZERO)
		for p: Vector2 in segs:
			bb = bb.expand(p)
		var r := _push(segs, bb.get_center(), y, 0.15)
		if r == 1:
			per_thing[name][1] += 1
			if thing_through.size() < 12:
				thing_through.append("%s at (%.1f, %.1f)" % [name, xf.origin.x, xf.origin.z])
		elif r == 2:
			per_thing[name][2] += 1
	print("(things looked at by %.0f s)" % (Time.get_ticks_msec() / 1000.0))
	var thing_fail := 0
	var inside_fail := 0
	print("things (name: tested, walked through, collision fat, a trunk inside):")
	names = per_thing.keys()
	names.sort()
	for n: String in names:
		var v: Array = per_thing[n]
		thing_fail += v[1]
		inside_fail += v[3]
		if v[1] > 0 or v[3] > 0 or v[0] > 0:
			print("  %-40s %5d %4d %4d %4d%s" % [n, v[0], v[1], v[2], v[3], "  FAIL" if v[1] + v[3] > 0 else ""])
	for s: String in thing_through:
		print("  walked through: ", s)
	for s: String in inside_at:
		print("  trunk inside: ", s)
	# Two trunks through each other; a tree on the pad.
	var crossed := 0
	var on_pad := 0
	for i in rows.size():
		var a: Array = rows[i]
		if a.size() < 8:
			continue
		var pa := Vector2(a[6].origin.x, a[6].origin.z)
		if PAD.has_point(pa):
			on_pad += 1
		var c := Vector2i(floori(pa.x / 4.0), floori(pa.y / 4.0))
		for ci in range(-1, 2):
			for cj in range(-1, 2):
				for j: int in grid.get(c + Vector2i(ci, cj), []):
					if j <= i:
						continue
					var b: Array = rows[j]
					# At a metre up: lower, two feet's roots may well run into each other.
					var ia := mini(2, (a[4] as PackedVector3Array).size() - 1)
					var ib := mini(2, (b[4] as PackedVector3Array).size() - 1)
					if ia < 0 or ib < 0:
						continue
					var ca: Vector3 = a[4][ia]
					var cb: Vector3 = b[4][ib]
					if Vector2(ca.x, ca.z).distance_to(Vector2(cb.x, cb.z)) < (a[7] as PackedFloat32Array)[ia] + (b[7] as PackedFloat32Array)[ib] - 0.05:
						crossed += 1
						print("  trunks through each other: %s and %s at (%.1f, %.1f)" % [kinds[a[5]][0], kinds[b[5]][0], pa.x, pa.y])
	print("trees walked through: ", tree_fail, ", things walked through: ", thing_fail, ", things with a trunk inside: ", inside_fail,
		", trunks through each other: ", crossed, ", trees on the pad: ", on_pad)
	var failed := tree_fail + thing_fail + inside_fail + crossed + on_pad > 0
	print("forest_collide_check: ", "FAILED" if failed else "passed")
	world.free()
	quit(1 if failed else 0)


## A body's drawn things: its meshes in its own space, its name from the scene it holds or its own.
func _props_of(parent: Node, out: Array) -> void:
	for body in parent.get_children():
		if not body is StaticBody3D or (body as StaticBody3D).collision_layer == 0 or not body.find_children("*", "CollisionShape3D", false, false).filter(func(c: Node) -> bool: return c.shape is CylinderShape3D).is_empty():
			continue  # walked over; or a tree of the clearing (its posts), looked at with the trees
		var name := String(body.name).get_slice("@", 0)
		var tris := PackedVector3Array()
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var x := Transform3D()
			var n: Node = mi
			while n and n != body:
				x = (n as Node3D).transform * x
				if n.scene_file_path != "" and name.begins_with("StaticBody3D"):
					name = n.scene_file_path.get_file().get_basename()
				n = n.get_parent()
			var t := TREE_STAND_TRIS.call([[mi.mesh, x]]) as PackedVector3Array
			tris.append_array(t)
			box = x * mi.mesh.get_aabb() if first else box.merge(x * mi.mesh.get_aabb())
			first = false
		if not first:
			out.append(["prop:" + name, tris, (body as Node3D).global_transform, box])


var TREE_STAND_TRIS := func(parts: Array) -> PackedVector3Array:
	return preload("res://tools/tree_stand.gd").triangles(parts)


## A kind's triangles by height (its own units), so a tree's lowest 2.4 m comes out without going through all of them.
func _buckets(parts: Array) -> Dictionary:
	var tris: PackedVector3Array = TREE_STAND_TRIS.call(parts)
	var out := {}
	for t in range(0, tris.size() - 2, 3):
		var lo := minf(tris[t].y, minf(tris[t + 1].y, tris[t + 2].y))
		var hi := maxf(tris[t].y, maxf(tris[t + 1].y, tris[t + 2].y))
		for b in range(floori(lo * 4.0), floori(hi * 4.0) + 1):
			if not out.has(b):
				out[b] = PackedVector3Array()
			var a: PackedVector3Array = out[b]
			a.append(tris[t])
			a.append(tris[t + 1])
			a.append(tris[t + 2])
			out[b] = a
			break  # in its lowest bucket only; _band takes the buckets under the band's top
	return out


## The tree's triangles that reach into its lowest BAND m, in the world.
func _band(buckets: Dictionary, xf: Transform3D, ground: float) -> PackedVector3Array:
	var s := xf.basis.get_scale().y
	var inv_top := (ground + BAND - xf.origin.y) / s + 0.2
	var out := PackedVector3Array()
	var lowest := INF
	for b: int in buckets:
		lowest = minf(lowest, b)
	for b: int in buckets:
		if b * 0.25 > inv_top:
			continue
		for p: Vector3 in buckets[b]:
			out.append(xf * p)
	return out


## The drawn wood within a metre of the trunk's axis up to BAND: vertices and the middles of the triangles.
func _near_axis(buckets: Dictionary, xf: Transform3D, ground: float) -> PackedVector3Array:
	var tris := _band(buckets, xf, ground)
	var foot := Vector2(xf.origin.x, xf.origin.z)
	var out := PackedVector3Array()
	for t in range(0, tris.size() - 2, 3):
		for p: Vector3 in [tris[t], tris[t + 1], tris[t + 2], (tris[t] + tris[t + 1] + tris[t + 2]) / 3.0]:
			if p.y > ground - 0.05 and p.y < ground + BAND and Vector2(p.x, p.z).distance_to(foot) < 1.0:
				out.append(p)
	return out


## Where the plane at `y` cuts the triangles: segments, two points each.
func _slice(tris: PackedVector3Array, y: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for t in range(0, tris.size() - 2, 3):
		var pts := PackedVector2Array()
		for e in 3:
			var a: Vector3 = tris[t + e]
			var b: Vector3 = tris[t + (e + 1) % 3]
			if (a.y < y) == (b.y < y):
				continue
			var p := a.lerp(b, (y - a.y) / (b.y - a.y))
			pts.append(Vector2(p.x, p.z))
		if pts.size() == 2:
			out.append(pts[0])
			out.append(pts[1])
	return out


## The piece of the cut nearest the foot: segments joined end to end. {segs, centre} or {}.
func _trunk_cut(tris: PackedVector3Array, y: float, foot: Vector2) -> Dictionary:
	var segs := _slice(tris, y)
	if segs.is_empty():
		return {}
	var parent := PackedInt32Array()
	parent.resize(segs.size() / 2)
	for i in parent.size():
		parent[i] = i
	var at := {}
	for i in parent.size():
		for p: Vector2 in [segs[i * 2], segs[i * 2 + 1]]:
			var key := Vector2i(roundi(p.x * 50.0), roundi(p.y * 50.0))
			if at.has(key):
				_union(parent, i, at[key])
			else:
				at[key] = i
	var boxes := {}
	for i in parent.size():
		var r := _find(parent, i)
		var b: Rect2 = Rect2(segs[i * 2], Vector2.ZERO).expand(segs[i * 2 + 1])
		boxes[r] = (boxes[r] as Rect2).merge(b) if boxes.has(r) else b
	var best := -1
	var best_d := 1.5
	for r: int in boxes:
		var b: Rect2 = boxes[r]
		if maxf(b.size.x, b.size.y) > 3.0:
			continue
		var d := b.get_center().distance_to(foot)
		if d < best_d:
			best_d = d
			best = r
	if best < 0:
		return {}
	var mine := PackedVector2Array()
	for i in parent.size():
		if _find(parent, i) == best:
			mine.append(segs[i * 2])
			mine.append(segs[i * 2 + 1])
	return {"segs": mine, "centre": (boxes[best] as Rect2).get_center()}


func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	parent[_find(parent, a)] = _find(parent, b)


## From DIRS sides a ball the capsule's width moved at the drawn wood round `centre` at height `y`.
## 0 fine, 1 into the wood further than `sink` (walked through), 2 stopped further than FAT off it.
func _push(segs: PackedVector2Array, centre: Vector2, y: float, sink: float) -> int:
	var out := 0
	for k in DIRS:
		var d := Vector2.from_angle(TAU * k / DIRS)
		var from := centre + d * 4.0
		var surface := -1.0  # how far out from the centre the wood is, this side
		for s in range(0, segs.size() - 1, 2):
			var hit: Variant = Geometry2D.segment_intersects_segment(from, centre, segs[s], segs[s + 1])
			if hit != null:
				surface = maxf(surface, (hit as Vector2).distance_to(centre))
		if surface < 0.0:
			continue
		# Jolt counts a ball that starts touching as free all the way: start where it touches nothing.
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = ball
		q.exclude = exclude
		var out_by := surface + R + 0.3
		q.transform = Transform3D(Basis(), Vector3(centre.x + d.x * out_by, y, centre.y + d.y * out_by))
		while not space.intersect_shape(q, 1).is_empty() and out_by < surface + R + 1.0:
			out_by += 0.1
			q.transform = Transform3D(Basis(), Vector3(centre.x + d.x * out_by, y, centre.y + d.y * out_by))
		if not space.intersect_shape(q, 1).is_empty():  # something else round it (a neighbour): stopped out here
			out = 2 if out_by - R - surface > FAT else out
			continue
		var start := centre + d * out_by
		var go := (centre - start)
		q.motion = Vector3(go.x, 0.0, go.y)
		var r := space.cast_motion(q)
		if r.is_empty():
			continue
		var stop := start + go * r[0]
		var front := stop.distance_to(centre) - R
		if r[0] >= 1.0 or surface - front > sink:
			last_push = "side %d: wood %.2f m out, ball's front stopped %.2f m out (moved %.2f of the way)" % [k, surface, front, r[0]]
			return 1
		if front - surface > FAT:
			out = 2
	return out
