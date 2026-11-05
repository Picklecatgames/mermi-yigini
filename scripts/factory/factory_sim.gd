class_name FactorySim
extends RefCounted
## The factory: structures on a metre grid, items on belts, machines turning scrap into materials,
## the team's one shared stock. No nodes, no scene, no floats: every peer runs this same integer
## simulation step by step (lockstep, like the heap's clock, pile.gd) and only commands cross the
## network, so its traffic doesn't grow with the items on the belts. Commands come from the host
## (scripts/factory/factory.gd), which also rolls the seed and digs the heap.
##
## Belts: a chain of belt cells with one way in and one way out is a line. A line keeps its items as
## gaps, front first: gap[i] is the free room ahead of item i (Factorio's trick). Everything behind
## the first non-zero gap moves when that one gap shrinks, so a tick costs per line, not per item.
## A cell where two belts join, or a machine puts out onto, starts a new line.
## Lines are derived data: remade from the structures whenever those change, keeping every item
## where it lay (_rebuild), so placing and removing needs no special cases.

const TICK_HZ := 10
const CELL_UNITS := 100  # length units per belt cell
const SPACING := 25  # between two items on a belt: 4 a metre
const DIR_X: Array[int] = [1, 0, -1, 0]
const DIR_Z: Array[int] = [0, 1, 0, -1]
const SAVE_VERSION := 1

var data: FactoryData
var step := 0
var rng := 0  # the host's seed, then walked on by every peer alike
var stock := PackedInt64Array()  # item index -> count: the team's, one for everyone
var stock_dirty := false  # for factory.gd to tell the game
var layout_version := 0  # goes up when a structure comes or goes (the view redraws)
var delivered := 0  # items that reached a kasa, ever

var grid := PackedInt32Array()  # cell -> slot + 1
# Structures, by slot; a free slot has kind -1.
var kind := PackedInt32Array()
var cell := PackedInt32Array()  # the footprint's min-x min-z cell
var dir := PackedInt32Array()
var timer := PackedInt32Array()  # ticks left of what it's doing
var recipe := PackedInt32Array()  # -1 none chosen
var budget := PackedInt32Array()  # dag: pieces the host has dug for it and it hasn't brought out
var crafting := PackedInt32Array()  # the scrap piece in the works, -1 none
var held: Array[PackedInt32Array] = []  # items waiting inside
var out: Array[PackedInt32Array] = []  # items waiting to go out
var rest: Array[PackedInt32Array] = []  # per material: grams that didn't make a whole unit yet
var free_slots := PackedInt32Array()
var count := 0  # structures standing
var ticking := PackedInt32Array()  # the slots that do something each tick, in slot order
var port_line := PackedInt32Array()  # machine: the line it puts out on, -1 none
var port_slot := PackedInt32Array()  # machine: the machine it puts straight into, -1 none
var _dead := {}  # slot -> true: gone since the last rebuild, its slot not free yet

# Lines.
var slot_line := PackedInt32Array()  # belt slot -> its line
var l_slots: Array[PackedInt32Array] = []  # tail to head
var l_items: Array[PackedInt32Array] = []  # front first
var l_gaps: Array[PackedInt32Array] = []
var l_len := PackedInt32Array()  # units
var l_tail := PackedInt32Array()  # free room behind the last item
var l_first := PackedInt32Array()  # no non-zero gap before this index
var l_speed := PackedInt32Array()  # units a tick
var l_next := PackedInt32Array()  # the line its front feeds, -1 none
var l_into := PackedInt32Array()  # the machine its front feeds, -1 none
var dirty := false


func _init(tables: FactoryData = null) -> void:
	data = tables if tables else FactoryData.shared()
	stock.resize(data.items.size())
	stock.fill(0)
	for i: int in data.start_stock:
		stock[i] = data.start_stock[i]
	grid.resize(data.area_w * data.area_h)
	grid.fill(0)


# --- Grid ---

func cell_of(x: int, z: int) -> int:
	var cx := x - data.area_x
	var cz := z - data.area_z
	return cz * data.area_w + cx if cx >= 0 and cz >= 0 and cx < data.area_w and cz < data.area_h else -1


func cell_x(c: int) -> int:
	return c % data.area_w + data.area_x


func cell_z(c: int) -> int:
	return c / data.area_w + data.area_z


## Size on the ground (x, z) of `k` facing `d`.
func footprint(k: int, d: int) -> Vector2i:
	var r: Dictionary = data.kinds[k]
	return Vector2i(r.d, r.w) if d % 2 == 0 else Vector2i(r.w, r.d)


## The cell outside `k`'s footprint it puts out into: the middle of its front. As x, z.
func port(k: int, x: int, z: int, d: int) -> Vector2i:
	var s := footprint(k, d)
	match d:
		0: return Vector2i(x + s.x, z + s.y / 2)
		1: return Vector2i(x + s.x / 2, z + s.y)
		2: return Vector2i(x - 1, z + s.y / 2)
	return Vector2i(x + s.x / 2, z - 1)


## Could `k` stand here, as far as the grid and the stock go (factory.gd adds what needs the scene).
func can_place(k: int, x: int, z: int, d: int) -> bool:
	if k < 0 or k >= data.kinds.size() or d < 0 or d > 3:
		return false
	var s := footprint(k, d)
	for j in s.y:
		for i in s.x:
			var c := cell_of(x + i, z + j)
			if c < 0 or data.allowed[c] == 0 or grid[c] != 0:
				return false
	return can_afford(data.kinds[k].cost)


func can_afford(cost: Dictionary) -> bool:
	for i: int in cost:
		if stock[i] < cost[i]:
			return false
	return true


func slot_at(x: int, z: int) -> int:
	var c := cell_of(x, z)
	return grid[c] - 1 if c >= 0 else -1


# --- Commands: the only way the state changes from outside; the same list on every peer ---

## ["s", seed] | ["p", kind, x, z, dir] | ["x", slot] | ["o", slot, pieces] | ["k", item, delta]
## | ["f", item, n]: see the functions below. The host checks them before they are sent.
func apply(cmd: Array) -> void:
	match cmd[0]:
		"s":
			rng = cmd[1]
		"p":
			_place(cmd[1], cmd[2], cmd[3], cmd[4])
		"x":
			_remove(cmd[1])
		"o":
			if kind[cmd[1]] >= 0 and not _dead.has(cmd[1]):
				budget[cmd[1]] += cmd[2]
		"k":
			stock[cmd[1]] += cmd[2]
			stock_dirty = true
		"f":
			_debug_fill(cmd[1], cmd[2])


func _place(k: int, x: int, z: int, d: int) -> void:
	var s: int
	if free_slots.is_empty():
		s = kind.size()
		kind.append(-1)
		cell.append(0)
		dir.append(0)
		timer.append(0)
		recipe.append(-1)
		budget.append(0)
		crafting.append(-1)
		port_line.append(-1)
		port_slot.append(-1)
		slot_line.append(-1)
		held.append(PackedInt32Array())
		out.append(PackedInt32Array())
		rest.append(PackedInt32Array())
	else:
		s = free_slots[-1]
		free_slots.remove_at(free_slots.size() - 1)
	var row: Dictionary = data.kinds[k]
	kind[s] = k
	cell[s] = cell_of(x, z)
	dir[s] = d
	timer[s] = 0
	recipe[s] = -1
	budget[s] = 0
	crafting[s] = -1
	if row.tur_i == FactoryData.Tur.DONUSTURUCU and rest[s].is_empty():
		var r := PackedInt32Array()
		r.resize(data.material_count)
		r.fill(0)
		rest[s] = r
	var f := footprint(k, d)
	for j in f.y:
		for i in f.x:
			grid[cell_of(x + i, z + j)] = s + 1
	for i: int in row.cost:
		stock[i] -= row.cost[i]
	stock_dirty = stock_dirty or not row.cost.is_empty()
	count += 1
	dirty = true
	layout_version += 1


## Taking something down gives back what it cost and all it held, into the stock; what lay on a
## belt follows when the lines are remade (_rebuild). Pieces dug for it and not brought out stay gone.
func _remove(s: int) -> void:
	var k := kind[s]
	if k < 0 or _dead.has(s):
		return
	var row: Dictionary = data.kinds[k]
	var f := footprint(k, dir[s])
	var x := cell_x(cell[s])
	var z := cell_z(cell[s])
	for j in f.y:
		for i in f.x:
			grid[cell_of(x + i, z + j)] = 0
	for i: int in row.cost:
		stock[i] += row.cost[i]
	for it: int in held[s]:
		stock[it] += 1
	for it: int in out[s]:
		stock[it] += 1
	if crafting[s] >= 0:
		stock[crafting[s]] += 1
	held[s] = PackedInt32Array()
	out[s] = PackedInt32Array()
	rest[s] = PackedInt32Array()
	crafting[s] = -1
	budget[s] = 0
	stock_dirty = true
	_dead[s] = true
	count -= 1
	dirty = true
	layout_version += 1


# --- The step ---

## One tick; commands stamped with this step go in before it (factory.gd).
func run_step() -> void:
	if dirty:
		_rebuild()
	_tick_machines()
	_move_lines()
	step += 1


func _tick_machines() -> void:
	for s in ticking:
		var row: Dictionary = data.kinds[kind[s]]
		if row.tur_i == FactoryData.Tur.DAG:
			if timer[s] > 0:
				timer[s] -= 1
			if timer[s] == 0 and budget[s] > 0 and out[s].size() < row.out_cap:
				rng = (rng * 1103515245 + 12345) & 0x7fffffff
				var n := data.items.size() - data.scrap_first
				out[s].append(data.scrap_first + (rng >> 8) % n)
				budget[s] -= 1
				timer[s] = row.ticks
		else:
			_tick_converter(s, row)
		if not out[s].is_empty():
			var it: int = out[s][0]
			var line := port_line[s]
			if line >= 0:
				if l_tail[line] >= SPACING:
					_insert_tail(line, it)
					out[s].remove_at(0)
			elif port_slot[s] >= 0 and _accept(port_slot[s], it):
				out[s].remove_at(0)


func _tick_converter(s: int, row: Dictionary) -> void:
	if timer[s] > 0:
		timer[s] -= 1
		if timer[s] > 0:
			return
		_finish(s)
	if recipe[s] < 0 or out[s].size() >= row.out_cap:
		return
	var r: Dictionary = data.recipes[recipe[s]]
	var h := held[s]
	if r.scrap:
		if h.is_empty():
			recipe[s] = -1
			return
		crafting[s] = h[0]
		h.remove_at(0)
	else:
		for i in r.inputs.size():
			if h.count(r.inputs[i]) < r.counts[i]:
				if h.is_empty():
					recipe[s] = -1
				return
		for i in r.inputs.size():
			for n in r.counts[i]:
				h.remove_at(h.find(r.inputs[i]))
	timer[s] = r.ticks


func _finish(s: int) -> void:
	var r: Dictionary = data.recipes[recipe[s]]
	if r.scrap:
		var it := crafting[s]
		crafting[s] = -1
		var m := data.item_material[it]
		var got: int = rest[s][m] + data.item_grams[it] * r.yield_pct / 100
		while got >= data.grams_per_unit:
			out[s].append(m)
			got -= data.grams_per_unit
		rest[s][m] = got
	else:
		for it: int in r.outputs:
			for n in r.outputs[it]:
				out[s].append(it)
	if held[s].is_empty():
		recipe[s] = -1


## Machine `s` takes item `it` from a belt or another machine, or doesn't. A new kind of machine
## that takes things (a turret's ammo) answers here.
func _accept(s: int, it: int) -> bool:
	var row: Dictionary = data.kinds[kind[s]]
	match row.tur_i:
		FactoryData.Tur.KASA:
			stock[it] += 1
			stock_dirty = true
			delivered += 1
			return true
		FactoryData.Tur.DONUSTURUCU:
			if recipe[s] < 0:
				recipe[s] = _recipe_for(row, it)
				if recipe[s] < 0:
					return false
			var r: Dictionary = data.recipes[recipe[s]]
			if r.scrap:
				if it < data.scrap_first or held[s].size() >= r.counts[0] * 2:
					return false
			else:
				var i: int = r.inputs.find(it)
				if i < 0 or held[s].count(it) >= r.counts[i] * 2:
					return false
			held[s].append(it)
			return true
	return false


func _recipe_for(row: Dictionary, it: int) -> int:
	for ri: int in row.recipes:
		var r: Dictionary = data.recipes[ri]
		if it >= data.scrap_first:
			if r.scrap:
				return ri
		elif r.inputs.has(it):
			return ri
	return -1


func _move_lines() -> void:
	for l in l_len.size():
		var items := l_items[l]
		var n := items.size()
		if n == 0:
			continue
		var gaps := l_gaps[l]
		if gaps[0] == 0:
			var next := l_next[l]
			var ok := false
			if next >= 0:
				ok = l_tail[next] >= SPACING
			elif l_into[l] >= 0:
				ok = _accept(l_into[l], items[0])
			if ok:
				var it := items[0]
				if n > 1:
					gaps[1] += SPACING
				items.remove_at(0)
				gaps.remove_at(0)
				n -= 1
				l_first[l] = 0
				if n == 0:
					l_tail[l] = l_len[l]
				if next >= 0:
					_insert_tail(next, it)
					n = items.size()  # a ring feeds itself
				if n == 0:
					continue
		# The items behind the first gap move by what that gap gives up; past it, the next one.
		var left := l_speed[l]
		var i := l_first[l]
		var moved := 0
		while left > 0 and i < n:
			var g := gaps[i]
			if g == 0:
				i += 1
				continue
			var take := mini(g, left)
			gaps[i] = g - take
			left -= take
			moved += take
			if take == g:
				i += 1
		l_first[l] = i
		l_tail[l] += moved


func _insert_tail(l: int, it: int) -> void:
	var gap := l_len[l] if l_items[l].is_empty() else l_tail[l] - SPACING
	l_items[l].append(it)
	l_gaps[l].append(gap)
	l_tail[l] = 0


# --- Lines from structures ---

func _rebuild() -> void:
	dirty = false
	var at := _items_by_slot()
	_topology()
	for l in l_slots.size():
		_lay_back(l, at)
	# What's left lay on a belt that's gone: into the stock; the slots free up only now.
	for s: int in at:
		var entries: PackedInt32Array = at[s]
		for i in range(1, entries.size(), 2):
			stock[entries[i]] += 1
			stock_dirty = true
	for s: int in _dead:
		kind[s] = -1
		free_slots.append(s)
	_dead.clear()


## What lies on each belt now: slot -> [offset, item, offset, item...], frontmost first.
func _items_by_slot() -> Dictionary:
	var at := {}
	for l in l_slots.size():
		var items := l_items[l]
		var gaps := l_gaps[l]
		var slots := l_slots[l]
		var d := 0
		for i in items.size():
			d += gaps[i] + (SPACING if i > 0 else 0)
			var u := l_len[l] - d
			var c := mini(u / CELL_UNITS, slots.size() - 1)
			var s := slots[c]
			if not at.has(s):
				at[s] = PackedInt32Array()
			var entries: PackedInt32Array = at[s]
			entries.append(u - c * CELL_UNITS)
			entries.append(items[i])
	return at


func _lay_back(l: int, at: Dictionary) -> void:
	var slots := l_slots[l]
	var total := l_len[l]
	var prev := -SPACING
	for c in range(slots.size() - 1, -1, -1):
		var s := slots[c]
		if not at.has(s):
			continue
		var entries: PackedInt32Array = at[s]
		for i in range(0, entries.size(), 2):
			var d := maxi(total - c * CELL_UNITS - entries[i], prev + SPACING)
			if d > total:  # squeezed off the back of a join: nothing lost
				stock[entries[i + 1]] += 1
				stock_dirty = true
				continue
			l_items[l].append(entries[i + 1])
			l_gaps[l].append(d - prev - SPACING)
			prev = d
		at.erase(s)
	l_tail[l] = total - prev if not l_items[l].is_empty() else total


## Who feeds whom, and the lines that makes. Slot order throughout, so every peer gets the same list.
func _topology() -> void:
	var size := kind.size()
	var feeds := _filled(size, -1)  # belt -> the belt it feeds
	var into := _filled(size, -1)  # belt -> the machine it feeds
	var ins := _filled(size, 0)  # belt -> how many things feed it
	var from := _filled(size, -1)  # belt -> a belt that feeds it
	var machine_in := _filled(size, 0)  # belt -> a machine puts out onto it
	var new_ticking := PackedInt32Array()
	for s in size:
		if kind[s] < 0 or _dead.has(s):
			continue
		var row: Dictionary = data.kinds[kind[s]]
		var x := cell_x(cell[s])
		var z := cell_z(cell[s])
		var d := dir[s]
		if row.tur_i == FactoryData.Tur.BANT:
			var t := slot_at(x + DIR_X[d], z + DIR_Z[d])
			if t < 0:
				continue
			if data.kinds[kind[t]].tur_i == FactoryData.Tur.BANT:
				if dir[t] != (d + 2) % 4:
					feeds[s] = t
					ins[t] += 1
					from[t] = s
			else:
				into[s] = t
			continue
		if row.tur_i != FactoryData.Tur.KASA:
			new_ticking.append(s)
		port_line[s] = -1
		port_slot[s] = -1
		var p := port(kind[s], x, z, d)
		var t := slot_at(p.x, p.y)
		if t < 0:
			continue
		if data.kinds[kind[t]].tur_i == FactoryData.Tur.BANT:
			if dir[t] != (d + 2) % 4:
				machine_in[t] = 1
				port_slot[s] = -t - 2  # a belt: its line is known after the walk below
		else:
			port_slot[s] = t
	ticking = new_ticking

	l_slots = []
	l_items = []
	l_gaps = []
	l_len = PackedInt32Array()
	l_tail = PackedInt32Array()
	l_first = PackedInt32Array()
	l_speed = PackedInt32Array()
	l_next = PackedInt32Array()
	l_into = PackedInt32Array()
	var seen := _filled(size, 0)
	var heads := _filled(size, 0)
	var belts := PackedInt32Array()
	for s in size:
		if kind[s] < 0 or _dead.has(s) or data.kinds[kind[s]].tur_i != FactoryData.Tur.BANT:
			continue
		belts.append(s)
		slot_line[s] = -1
		if ins[s] != 1 or machine_in[s] != 0 or kind[from[s]] != kind[s]:
			heads[s] = 1
	for s in belts:
		if heads[s] != 0:
			_walk(s, feeds, heads, seen)
	for s in belts:  # what's left has no start: rings
		if seen[s] == 0:
			_walk(s, feeds, heads, seen)
	for l in l_slots.size():
		var last: int = l_slots[l][-1]
		l_next[l] = slot_line[feeds[last]] if feeds[last] >= 0 else -1
		l_into[l] = into[last]
	for s in ticking:
		if port_slot[s] <= -2:
			port_line[s] = slot_line[-port_slot[s] - 2]
			port_slot[s] = -1


func _filled(size: int, v: int) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(size)
	a.fill(v)
	return a


func _walk(start: int, feeds: PackedInt32Array, heads: PackedInt32Array, seen: PackedInt32Array) -> void:
	var l := l_slots.size()
	var slots := PackedInt32Array()
	var s := start
	while true:
		slots.append(s)
		seen[s] = 1
		slot_line[s] = l
		var n := feeds[s]
		if n < 0 or heads[n] != 0 or seen[n] != 0:
			break
		s = n
	l_slots.append(slots)
	l_items.append(PackedInt32Array())
	l_gaps.append(PackedInt32Array())
	l_len.append(slots.size() * CELL_UNITS)
	l_tail.append(slots.size() * CELL_UNITS)
	l_first.append(0)
	l_speed.append(data.kinds[kind[start]].speed)
	l_next.append(-1)
	l_into.append(-1)


# --- Checks, saves, joiners ---

## All the state in one number: two peers at the same step must agree on it (factory.gd sends it).
func state_hash() -> int:
	if dirty:
		_rebuild()
	return hash([step, rng, stock, kind, cell, dir, timer, recipe, budget, crafting, held, out, rest, l_items, l_gaps])


func items_on_belts() -> int:
	var n := 0
	for a in l_items:
		n += a.size()
	return n


## The whole factory and stock, by name, in JSON-safe values: a save file holds this, a joiner gets it.
func to_save() -> Dictionary:
	if dirty:
		_rebuild()
	var by_id := {}
	for i in stock.size():
		if stock[i] != 0:
			by_id[data.item_ids[i]] = stock[i]
	var slots := []
	for s in kind.size():
		if kind[s] < 0:
			slots.append(null)
			continue
		var e := {"k": data.kind_ids[kind[s]], "c": cell[s], "d": dir[s]}
		if timer[s] != 0:
			e.t = timer[s]
		if recipe[s] >= 0:
			e.r = data.recipes[recipe[s]].id
		if budget[s] != 0:
			e.b = budget[s]
		if crafting[s] >= 0:
			e.w = data.item_ids[crafting[s]]
		if not held[s].is_empty():
			e.h = _names(held[s])
		if not out[s].is_empty():
			e.o = _names(out[s])
		for m in rest[s].size():
			if rest[s][m] != 0:
				e.g = Array(rest[s])  # in the table's material order; bump SAVE_VERSION if that moves
				break
		slots.append(e)
	var items := []
	var gaps := []
	for l in l_items.size():
		items.append(_names(l_items[l]))
		gaps.append(Array(l_gaps[l]))
	return {"v": SAVE_VERSION, "step": step, "rng": rng, "delivered": delivered, "stock": by_id, "slots": slots,
		"free": Array(free_slots), "items": items, "gaps": gaps}


## Back from to_save(). Replaces everything here.
func from_save(save: Dictionary) -> void:
	step = int(save.step)
	rng = int(save.rng)
	delivered = int(save.delivered)
	stock.fill(0)
	for id: String in save.stock:
		if data.item_index.has(id):
			stock[data.item_index[id]] = int(save.stock[id])
	grid.fill(0)
	var slots: Array = save.slots
	var size := slots.size()
	kind = _filled(size, -1)
	cell = _filled(size, 0)
	dir = _filled(size, 0)
	timer = _filled(size, 0)
	recipe = _filled(size, -1)
	budget = _filled(size, 0)
	crafting = _filled(size, -1)
	port_line = _filled(size, -1)
	port_slot = _filled(size, -1)
	slot_line = _filled(size, -1)
	held = []
	out = []
	rest = []
	count = 0
	_dead.clear()
	for s in size:
		held.append(PackedInt32Array())
		out.append(PackedInt32Array())
		rest.append(PackedInt32Array())
		var e: Variant = slots[s]
		if e == null or not data.kind_index.has(e.k):
			continue
		var k: int = data.kind_index[e.k]
		kind[s] = k
		cell[s] = int(e.c)
		dir[s] = int(e.d)
		timer[s] = int(e.get("t", 0))
		budget[s] = int(e.get("b", 0))
		if e.has("r"):
			for ri in data.recipes.size():
				if data.recipes[ri].id == e.r:
					recipe[s] = ri
		if e.has("w"):
			crafting[s] = data.item_index.get(e.w, -1)
		held[s] = _indices(e.get("h", []))
		out[s] = _indices(e.get("o", []))
		if data.kinds[k].tur_i == FactoryData.Tur.DONUSTURUCU:
			var r := _filled(data.material_count, 0)
			var g: Array = e.get("g", [])
			for m in mini(g.size(), data.material_count):
				r[m] = int(g[m])
			rest[s] = r
		var f := footprint(k, dir[s])
		for j in f.y:
			for i in f.x:
				grid[cell[s] + j * data.area_w + i] = s + 1
		count += 1
	free_slots = PackedInt32Array()
	for s: Variant in save.free:
		free_slots.append(int(s))
	dirty = false
	stock_dirty = true
	layout_version += 1
	_topology()
	var items: Array = save.items
	var gaps: Array = save.gaps
	for l in mini(items.size(), l_slots.size()):
		l_items[l] = _indices(items[l])
		var g := PackedInt32Array()
		var d := 0
		for i in (gaps[l] as Array).size():
			g.append(int(gaps[l][i]))
			d += g[i] + (SPACING if i > 0 else 0)
		l_gaps[l] = g
		l_tail[l] = l_len[l] - d if not g.is_empty() else l_len[l]


func _names(a: PackedInt32Array) -> Array:
	var names := []
	for i in a:
		names.append(data.item_ids[i])
	return names


func _indices(names: Array) -> PackedInt32Array:
	var a := PackedInt32Array()
	for id: String in names:
		if not data.item_index.has(id):
			push_warning("factory save: no item '%s' any more, it counts as the first material" % id)
		a.append(data.item_index.get(id, 0))
	return a


## Test only (tools/factory_check.gd): `n` items of `it`, handed round the belt lines that have room.
func _debug_fill(it: int, n: int) -> void:
	if dirty:
		_rebuild()
	var left := n
	var more := true
	while left > 0 and more:
		more = false
		for l in l_len.size():
			if left > 0 and l_tail[l] >= SPACING * 2:
				var first := l_items[l].is_empty()
				l_items[l].append(it)
				l_gaps[l].append(0)
				l_tail[l] = l_len[l] - (l_items[l].size() - 1) * SPACING
				left -= 1
				more = true
				if first:
					l_first[l] = 0
