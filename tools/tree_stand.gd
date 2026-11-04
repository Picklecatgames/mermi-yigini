extends RefCounted
## Where a tree model really stands (2026-11-04, the user: "most of the trees float, and you walk
## through them"): its box says nothing, a stray root or a branch sets the bottom and a crown the
## middle. This cuts the mesh into horizontal slices and follows the trunk from breast height down.


const STEP := 0.1      # m between slices
const JOIN := 0.1     # m: section points this close are one piece of wood (a cut triangle joins its own two)
const BREAST := 1.5    # m over the model's lowest point: where the trunk is looked for
const MAX_SINK := 1.3  # m: no flare sinks a tree further; a crown low on a young tree is no flare
## Roots on stilts as tall as a man: the trunk starts higher and the stilts go underground. By eye, tools/tree_stand_sheet.gd.
const STILTED := {"dead_h": [3.0, 2.4], "birch_a": [BREAST, 0.9]}
## Leaves hang as low as the trunk here and read as a flare: their foot is near the lowest point.
const LOW_CROWN := ["birch_", "young_", "cypress", "card"]
const LOW_CROWN_SINK := 0.3  # m
const FLARE := 2.2     # times the trunk's width: past this the roots have begun, the ground goes there
const POST_AT := [0.4, 1.2, 2.0]  # m over the ground: a collision post at each
const MIN_POST := 0.08  # m
const MAX_POST := 1.0   # m


static func triangles(parts: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for part: Array in parts:
		var m: Mesh = part[0]
		var x: Transform3D = part[1]
		for s in m.get_surface_count():
			var a: Array = m.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				for i in v.size():
					out.append(x * v[i])
			else:
				for i in idx:
					out.append(x * v[i])
	return out


## The pieces of wood the plane at `y` cuts, as Rect2 boxes in (x, z).
## `closed`: only rings: a plane through a trunk closes on itself, through a leaf card it is a line with two ends.
static func _slice(tris: PackedVector3Array, y: float, join: float, whole := false, closed := false) -> Array[Rect2]:
	var cells := {}
	var links := {}  # cell -> cells a cut triangle joins it to: a low-poly trunk's faces are wider than JOIN
	for t in range(0, tris.size() - 2, 3):
		var first := Vector2i.MAX
		for e in 3:
			var a: Vector3 = tris[t + e]
			var b: Vector3 = tris[t + (e + 1) % 3]
			if (a.y < y) == (b.y < y):
				continue
			var p := a.lerp(b, (y - a.y) / (b.y - a.y))
			var c := Vector2i(floori(p.x / join), floori(p.z / join))
			if not cells.has(c):
				cells[c] = Rect2(p.x, p.z, 0.0, 0.0)
				links[c] = []
			else:
				cells[c] = (cells[c] as Rect2).expand(Vector2(p.x, p.z))
			if first == Vector2i.MAX:
				first = c
			elif first != c:
				links[c].append(first)
				links[first].append(c)
	var out: Array[Rect2] = []
	var seen := {}
	for c: Vector2i in cells:
		if seen.has(c):
			continue
		seen[c] = true
		var box: Rect2 = cells[c]
		var open: Array[Vector2i] = [c]
		var loose_ends := 0
		while not open.is_empty():
			var o: Vector2i = open.pop_back()
			var ties := {}
			for t: Vector2i in links[o]:
				ties[t] = true
			if ties.size() == 1:
				loose_ends += 1
			var near: Array = links[o].duplicate()
			for i in range(-1, 2):
				for j in range(-1, 2):
					near.append(o + Vector2i(i, j))
			for n: Vector2i in near:
				if cells.has(n) and not seen.has(n):
					seen[n] = true
					box = box.merge(cells[n])
					open.append(n)
		if not closed or loose_ends == 0 or maxf(box.size.x, box.size.y) < join * 2.5:
			out.append(box)
	if whole and out.size() > 1:
		var one := out[0]
		for r: Rect2 in out:
			one = one.merge(r)
		out = [one]
	return out


static func _radius(r: Rect2) -> float:
	return maxf(r.size.x, r.size.y) * 0.5


## Follows one ring of wood down from `from` at `y`: [[y, the ring, all that touches it there], ...], top first.
## The nearest piece each slice: leaf cards and stray branches cross the trunk without being the trunk.
static func _trace(tris: PackedVector3Array, from: Rect2, y: float, low: float, step: float, join: float, whole := false) -> Array:
	var out := [[y, from, from]]
	var box := from
	var at := y - step
	while at > low:
		var next := Rect2()
		var all := Rect2()
		var any := false
		var best_d := INF
		for r: Rect2 in _slice(tris, at, join, whole):
			if r.grow(join * 2.0).intersects(box):
				all = all.merge(r) if any else r
				any = true
				var d := r.get_center().distance_to(box.get_center())
				if d < best_d:
					best_d = d
					next = r
		if not any:
			break
		out.append([at, next, all])
		box = next
		at -= step
	return out


## `scale`: metres per unit of these parts, about; `hint`: the trunk's radius in m as far as the kinds
## table knows (a card tree's trunk is a picture on a plane, the mesh can't tell). {foot: Vector3 where
## the ground meets the trunk, posts: [[Vector3 centre, radius], ...] in the same units, lowest (m the
## model's lowest point lies under the foot), ok, height, width (m)}.
static func measure(parts: Array, scale: float, hint := 0.0, kind := "") -> Dictionary:
	var tris := triangles(parts)
	# Trunk meshes alone: everything a slice cuts is the trunk, however its low-poly faces fall apart.
	var whole := true
	for part: Array in parts:
		whole = whole and part.size() > 2 and String(part[2]).contains("Trunk")
	var stilted: Array = STILTED.get(kind, [BREAST, MAX_SINK])
	if not STILTED.has(kind):
		for prefix: String in LOW_CROWN:
			if kind.begins_with(prefix):
				stilted = [BREAST, LOW_CROWN_SINK]
	var low := INF
	var high := -INF
	for p in tris:
		low = minf(low, p.y)
		high = maxf(high, p.y)
	var step := STEP / scale
	var join := JOIN / scale
	if stilted[1] == LOW_CROWN_SINK or kind == "birch_a":
		var low_one := _low_trunk(tris, low, high, scale, hint)
		if not low_one.is_empty():
			return low_one
	var best := []
	var look := minf(stilted[0] / scale, (high - low) * 0.4)
	for k in 4:  # a low fork or a gap in the mesh: a little lower
		var y := low + look * (1.0 - k * 0.22)
		# What reaches down near the lowest point and is as wide as a trunk: a thin root or branch
		# hanging as low is not the trunk, nor is a crown.
		var traces := []
		var lowest := INF
		var rings := _slice(tris, y, join, whole, true)
		if rings.is_empty():
			rings = _slice(tris, y, join, whole)
		for r: Rect2 in rings:
			var tr := _trace(tris, r, y, low - step, step, join, whole)
			traces.append(tr)
			lowest = minf(lowest, tr[-1][0])
		var score := INF
		for tr: Array in traces:
			if tr[-1][0] > lowest + 1.5 / scale:
				continue
			var r0: float = maxf(_radius(tr[0][1]), 0.001 / scale)
			# As wide as the table says a trunk of this kind is; with no table, the thickest.
			var off: float = absf(log(r0 * scale / hint)) if hint > 0.0 else -r0
			# A trunk goes on upward; a leaf card that happens to be trunk-wide here stops.
			var goes_on := false
			for up: Rect2 in _slice(tris, y + 3.0 / scale, join, whole):
				goes_on = goes_on or (up.grow(join * 3.0).intersects(tr[0][1]) and _radius(up) * scale < maxf(hint * 3.0, 0.5))
			if not goes_on:
				off += 5.0
			if off < score:
				score = off
				best = tr
		if not best.is_empty():
			break
	if best.is_empty():
		return {"foot": Vector3(0.0, low, 0.0), "posts": [], "lowest": 0.0, "ok": false, "height": (high - low) * scale, "width": 0.0}
	# The trunk's width: the narrowest of the upper part of the trace. A slice through a branch only widens.
	var width := INF
	for i in range(0, ceili(best.size() * 0.6)):
		width = minf(width, _radius(best[i][1]))
	width = maxf(width, MIN_POST / scale)
	# The ground goes where the roots begin: the wood spreads, as one ring or as several apart.
	var foot_i: int = best.size() - 1
	for i in best.size():
		if _radius(best[i][2]) > maxf(width * FLARE, width + 0.35 / scale):
			foot_i = maxi(i - 1, 0)
			break
	# Not higher than a flare can be.
	while foot_i < best.size() - 1 and (best[foot_i][0] - low) * scale > stilted[1]:
		foot_i += 1
	var c: Vector2 = (best[foot_i][1] as Rect2).get_center()
	var foot := Vector3(c.x, best[foot_i][0], c.y)
	# Now the wood just over the ground says how thick the trunk is: higher up a low crown joins in.
	width = INF
	for i in range(maxi(foot_i - ceili(1.0 / STEP), 0), foot_i + 1):
		width = minf(width, _radius(best[i][1]))
	width = maxf(width, MIN_POST / scale)
	if hint > 0.0:
		width = clampf(width, hint * 0.35 / scale, hint * 1.2 / scale)
	var posts := []
	var top_box: Rect2 = best[0][1]
	var last := Vector2(foot.x, foot.z)
	for m: float in POST_AT:
		var y: float = foot.y + m / scale
		var cut := Rect2()
		var found := false
		var near := step
		for e: Array in best:
			if absf(e[0] - y) <= near:
				near = absf(e[0] - y)
				cut = e[1]
				found = true
		if not found:  # above where the trace began: the same trunk, higher
			for r: Rect2 in _slice(tris, y, join, whole):
				if not found and r.grow(join * 3.0).intersects(top_box):
					cut = r
					found = true
		# Much wider than the trunk: a crown or a fork. The trunk goes on from where it was.
		var rc: Vector2 = cut.get_center() if found and _radius(cut) <= width * 1.8 else last
		last = rc
		var post_r: float = minf(_radius(cut), width * 1.3) if found else width
		posts.append([Vector3(rc.x, y, rc.y), clampf(maxf(post_r, hint * 0.35 / scale), MIN_POST / scale, MAX_POST / scale)])
	return {"foot": foot, "posts": posts, "lowest": (foot.y - low) * scale, "ok": true, "height": (high - low) * scale, "width": width * scale}


## A tree whose crown hangs low: over 1 m everything is leaf cards, but right over the ground the only
## closed ring is the trunk. The ring nearest the table's width at 0.5 m or 0.2 m, and the line to it.
static func _low_trunk(tris: PackedVector3Array, low: float, high: float, scale: float, hint: float) -> Dictionary:
	var join := JOIN / scale
	var ring := func(m: float) -> Variant:
		var pick: Variant = null
		var score := INF
		for c: Rect2 in _slice(tris, low + m / scale, join, false, true):
			var radius := _radius(c) * scale
			if radius < 0.05:
				continue
			var off := absf(log(radius / maxf(hint, 0.05)))
			if off < score:
				score = off
				pick = c
		return pick
	var a: Variant = ring.call(0.5)
	if a == null:
		a = ring.call(0.2)
	if a == null:
		return {}
	var at: Vector2 = (a as Rect2).get_center()
	var lean := Vector2.ZERO
	var b: Variant = ring.call(1.0)
	if b != null and (b as Rect2).get_center().distance_to(at) * scale < 0.3:
		lean = ((b as Rect2).get_center() - at) / 0.5
	var width := clampf(_radius(a), MIN_POST / scale, MAX_POST / scale)
	var foot := Vector3(at.x, low, at.y)
	var posts := []
	for m: float in POST_AT:
		var c: Vector2 = at + lean * (m - 0.5)
		posts.append([Vector3(c.x, low + m / scale, c.y), width])
	return {"foot": foot, "posts": posts, "lowest": 0.0, "ok": true, "height": (high - low) * scale, "width": width * scale}


## Is there wood at `metres` over the foot, within reach of the foot? For tools/wood_stand_check.gd.
static func wood_at(parts: Array, foot: Vector3, metres: float, scale: float) -> bool:
	var y := foot.y + metres / scale
	for r: Rect2 in _slice(triangles(parts), y, JOIN / scale):
		if r.grow(0.3 / scale).has_point(Vector2(foot.x, foot.z)):
			return true
	return false
