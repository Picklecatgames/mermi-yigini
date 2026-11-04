class_name FactoryData
extends RefCounted
## The factory's tables (data/items.json, recipes.json, machines.json), turned into plain int-indexed
## arrays the simulation can run on. The order is the files' order, so every peer's indices agree;
## a save holds names (factory_sim.gd to_save), not these indices.

const ANY_SCRAP := -2  # a recipe input: any scrap piece
enum Tur { BANT, DAG, DONUSTURUCU, KASA }
const TUR := {"bant": Tur.BANT, "dag": Tur.DAG, "donusturucu": Tur.DONUSTURUCU, "kasa": Tur.KASA}

static var _shared: FactoryData

var item_ids := PackedStringArray()
var item_index := {}  # id -> index
var items: Array[Dictionary] = []  # materials' rows, then hurda.json's
var material_count := 0  # materials come first in `items`, scrap after them
var scrap_first := 0
var item_grams := PackedInt32Array()  # a scrap piece's mass, 0 for anything else
var item_material := PackedInt32Array()  # a scrap piece's material (item index), -1 for anything else
var grams_per_unit := 1000
var start_stock := {}  # item index -> count

var kinds: Array[Dictionary] = []  # machines.json rows + tur_i, w, d, ticks, speed, out_cap, batch, reach, cost, recipes
var kind_index := {}  # id -> index
var kind_ids := PackedStringArray()
var recipes: Array[Dictionary] = []  # + inputs, counts (parallel), outputs (item -> n), ticks, yield_pct, scrap
var area_x := 0
var area_z := 0
var area_w := 1
var area_h := 1
var allowed := PackedByteArray()  # per grid cell: may be built on


## One loaded copy per process: the tables never change while the game runs.
static func shared() -> FactoryData:
	if _shared == null:
		_shared = FactoryData.new()
		_shared._load()
	return _shared


func _load() -> void:
	var it: Dictionary = _read("res://data/items.json")
	for m: Dictionary in it.malzemeler:
		_add_item(m.id, m, 0, -1)
	material_count = items.size()
	scrap_first = items.size()
	grams_per_unit = roundi(float(it.birim_kg) * 1000.0)
	for p: Dictionary in _read(it.hurda_kaynak):
		if not item_index.has(p.materyal):
			push_error("items.json: hurda.json's material '%s' (%s) has no row" % [p.materyal, p.id])
			continue
		_add_item("hurda/" + p.id, p, roundi(float(p.kutle_kg) * 1000.0), item_index[p.materyal])
	for id: String in it.baslangic:
		start_stock[item_index[id]] = int(it.baslangic[id])

	var ma: Dictionary = _read("res://data/machines.json")
	for row: Dictionary in ma.makineler:
		var k := row.duplicate()
		k.tur_i = TUR[row.tur]
		k.w = int(row.boyut[0])
		k.d = int(row.boyut[1])
		k.ticks = maxi(roundi(float(row.get("sure", 0.0)) * FactorySim.TICK_HZ), 1)
		k.speed = maxi(roundi(float(row.get("hiz", 0.0)) * FactorySim.CELL_UNITS / FactorySim.TICK_HZ), 1)
		k.out_cap = int(row.get("cikis_kapasite", 1))
		k.batch = int(row.get("parti", 0))
		k.reach = int(row.get("erisim", 0))
		k.cost = _counts(row.get("maliyet", {}))
		k.recipes = PackedInt32Array()
		kind_index[row.id] = kinds.size()
		kind_ids.append(row.id)
		kinds.append(k)
	_load_area(ma.alanlar)

	for row: Dictionary in _read("res://data/recipes.json").tarifler:
		var r := row.duplicate()
		r.inputs = PackedInt32Array()
		r.counts = PackedInt32Array()
		r.scrap = false
		for id: String in row.girdi:
			r.inputs.append(ANY_SCRAP if id == "@hurda" else item_index[id])
			r.counts.append(int(row.girdi[id]))
			r.scrap = r.scrap or id == "@hurda"
		r.outputs = _counts(row.get("cikti", {}))
		r.ticks = maxi(roundi(float(row.sure) * FactorySim.TICK_HZ), 1)
		r.yield_pct = roundi(float(row.get("verim", 1.0)) * 100.0)
		kinds[kind_index[row.makine]].recipes.append(recipes.size())
		recipes.append(r)


func _add_item(id: String, row: Dictionary, grams: int, material: int) -> void:
	item_index[id] = items.size()
	item_ids.append(id)
	items.append(row)
	item_grams.append(grams)
	item_material.append(material)


func _load_area(rects: Array) -> void:
	var x0 := 1 << 30
	var z0 := 1 << 30
	var x1 := -x0
	var z1 := -z0
	for r: Array in rects:
		x0 = mini(x0, int(r[0]))
		z0 = mini(z0, int(r[1]))
		x1 = maxi(x1, int(r[0] + r[2]))
		z1 = maxi(z1, int(r[1] + r[3]))
	area_x = x0
	area_z = z0
	area_w = x1 - x0
	area_h = z1 - z0
	allowed.resize(area_w * area_h)
	allowed.fill(0)
	for r: Array in rects:
		for z in range(int(r[1]), int(r[1] + r[3])):
			for x in range(int(r[0]), int(r[0] + r[2])):
				allowed[(z - z0) * area_w + x - x0] = 1


func _counts(by_id: Dictionary) -> Dictionary:
	var out := {}
	for id: String in by_id:
		out[item_index[id]] = int(by_id[id])
	return out


func _read(path: String) -> Variant:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if v == null:
		push_error("factory: could not read " + path)
	return v
