extends SceneTree
## Headless bot test for the quest board (docs/gorev_sistemi_plani.md step 4):
##   Godot.exe --headless --path . -s res://tools/quest_sim.gd
##   ... -- --sweep    tries quest_scale values for 2-4 players instead
##   ... -- --fit      one mid player: when each quest was pinned and done, for tuning targets
## 1-4 bots of three skills play the demo against the real GameState: its quests, upgrades, gear,
## pay (hit_pay) and quest hooks (quest_add, quest_hit). What the game doesn't have yet (carrying
## tools, recipes, the melter) the bots get from the tables below: the sim's own guesses until those
## mechanics are built. No physics: a shot hits by the bot's odds, a trip to the heap takes a time.
## Prints, per run: when each quest was done, when each thing opened and the longest wait between
## two, bullets used up a second (fired + melted) along the way, and what left the heap in 60 min.

const DT := 0.25  # s
const MINUTES := 120.0
const RELOAD := 1.5  # s
const SEEDS := [1, 2, 3]
## Per skill: hit odds, share of hits on the head, a round trip to the heap (s), time lost between
## things (menus, looking around), magazines of each load kept to shoot once the melter is open
## (the rest goes in it), whether upgrades are bought cheapest first or in a fixed, worse order.
const SKILLS := {
	"kötü": {"hit": 0.45, "head": 0.05, "trip": 15.0, "idle": 0.35, "keep": 6, "smart": false},
	"orta": {"hit": 0.65, "head": 0.15, "trip": 11.0, "idle": 0.15, "keep": 4, "smart": true},
	"iyi": {"hit": 0.85, "head": 0.3, "trip": 8.0, "idle": 0.05, "keep": 3, "smart": true},
}
## Guns, best last: GUNS index, what opens it ("" from the start), how much it spoils the aim.
const GUN_STEPS := [[1, "", 1.0], [2, "uzi", 0.85], [3, "scorpion", 0.8]]
## Carrying tools and what one load holds; before them the hand ("carry" upgrade).
const TOOLS := [["bucket", 50], ["shovel", 200], ["wheelbarrow", 1000]]
## Recipes (docs/ayrintilar.md "Mermi tarifi"): bullets a shot eats, its pay against a plain
## round, what has to be open ("bp:" a finished blueprint), the tags its hits carry.
const RECIPES := [
	{"cost": 1, "gold": 1.0, "needs": [], "tags": []},
	{"cost": 2, "gold": 2.4, "needs": ["blueprints"], "tags": ["clone"]},
	{"cost": 4, "gold": 5.0, "needs": ["hand_press"], "tags": ["clone"]},
	{"cost": 12, "gold": 15.0, "needs": ["hand_press", "bp:obur"], "tags": ["obur"]},
	{"cost": 25, "gold": 32.0, "needs": ["electric_press", "bp:sekme"], "tags": ["clone", "sekme"]},
	{"cost": 50, "gold": 65.0, "needs": ["electric_press", "bp:yanki"], "tags": ["yanki"]},
]
const BLUEPRINTS := {"dual_pistol": 3, "obur": 2, "sekme": 2, "yanki": 3}  # pieces each needs
## Melter: bullets a second (faster with "melter_speed"), gold a bullet (more with
## "melter_yield"), the detour to empty a load into it (s).
const MELT_RATE := [20.0, 60.0]
const MELT_GOLD := [0.2, 0.5]
const MELT_WALK := 6.0
## Gear the vault buys, in this order, and what a hit on it pays; the bots shoot the best one.
const TARGETS := [["popper", 3], ["steel_rack", 4], ["plate_rack", 7], ["gold_dummy", 10], ["texas_star", 12]]
## Bullets off the heap by the time the bots have dug out each key (the common ones lie shallow,
## scripts/key_cache.gd); the sim's guess, since its bots dig nowhere in particular.
const KEY_AT := [400, 1200, 2500, 5000, 8000, 60000, 150000]
const DUMB_ORDER := ["gold_bonus", "range_bonus", "combo_cap", "magazine", "carry"]
const BEHIND := 1.0  # m behind the railing they stand
const PLACE_TIME := 12.0  # s: the heap's line, Q, buying the dummy and walking it into place
## Targets: main chain done in these minutes for one mid player, and at least this for four;
## no wait between two unlocks longer than this.
const SOLO := Vector2(55, 65)
const TEAM_MIN := 35.0
const MAX_GAP := 7.0

var gs: Node


class Bot:
	var peer: int
	var skill: Dictionary
	var busy := 0.0  # s left on what it is doing
	var recipe: Dictionary
	var last_hit := -100.0  # s, game time
	var loads := 0  # trips to the heap so far


func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame
	if "--sweep" in OS.get_cmdline_user_args():
		_sweep()
	elif "--fit" in OS.get_cmdline_user_args():
		for s: int in SEEDS:
			var run := _run(1, "orta", s)
			for id: String in gs.QUESTS:
				print("FIT %s %s %s %d" % [id, run.pinned.get(id, -1.0), run.done.get(id, -1.0), gs.QUESTS[id].target])
	else:
		_grid()
	quit()


## Every team size and skill, each over SEEDS; the full log for one mid player and four mid ones.
func _grid() -> void:
	print("quest_scale %.2f" % gs.quest_scale)
	var summary := []
	for n in [1, 2, 3, 4]:
		for skill: String in SKILLS:
			var runs := []
			for s: int in SEEDS:
				runs.append(_run(n, skill, s))
			if skill == "orta" and n in [1, 4]:
				_report(runs[0])
			summary.append([n, skill, runs])
	print("\n| Oyuncu | Beceri | Ana zincir (dk) | En uzun bekleme (dk) | 60 dk'da yığından giden | 60. dk'da mermi/sn |")
	print("|---|---|---|---|---|---|")
	for row: Array in summary:
		var runs: Array = row[2]
		print("| %d | %s | %s | %s | %s | %s |" % [row[0], row[1], _span(runs, "main"), _span(runs, "gap"),
			_span(runs, "removed60", true), _span(runs, "rate60")])
	var solo: Array = summary.filter(func(r: Array) -> bool: return r[0] == 1 and r[1] == "orta")[0][2]
	var four: Array = summary.filter(func(r: Array) -> bool: return r[0] == 4 and r[1] == "orta")[0][2]
	var solo_main := _mean(solo, "main")
	var four_main := _mean(four, "main")
	var worst_gap := 0.0
	for row: Array in summary:
		if row[1] == "orta":
			worst_gap = maxf(worst_gap, _max(row[2], "gap"))
	print("\nhedefler: tek kişi orta %.1f dk (%d-%d) %s, 4 kişi orta %.1f dk (>= %d) %s, en uzun bekleme (orta) %.1f dk (<= %d) %s" % [
		solo_main, SOLO.x, SOLO.y, _mark(solo_main >= SOLO.x and solo_main <= SOLO.y),
		four_main, TEAM_MIN, _mark(four_main >= TEAM_MIN), worst_gap, MAX_GAP, _mark(worst_gap <= MAX_GAP)])


## Mid players, 2-4 of them, at several scales: where four land at TEAM_MIN or later.
func _sweep() -> void:
	var solo := _mean(SEEDS.map(func(s: int) -> Dictionary: return _run(1, "orta", s)), "main")
	print("tek kişi orta: %.1f dk" % solo)
	print("| quest_scale | 2 kişi | 3 kişi | 4 kişi |")
	print("|---|---|---|---|")
	for k in [0.2, 0.3, 0.4, 0.5, 0.6, 0.8]:
		gs.quest_scale = k
		var line := "| %.2f |" % k
		for n in [2, 3, 4]:
			line += " %.1f |" % _mean(SEEDS.map(func(s: int) -> Dictionary: return _run(n, "orta", s)), "main")
		print(line)


## One play-through. Returns when quests finished and things opened (minutes), the bullet rate a
## minute, the main chain's end and the longest wait between unlocks.
func _run(n: int, skill: String, rng_seed: int) -> Dictionary:
	seed(rng_seed)
	gs._players.clear()
	gs.pile = gs.PILE_START
	gs.vault = 0.0
	gs.gear_stock = {}
	gs.slots = {}
	for i in n:
		gs.slots[i + 1] = i
	gs.start_quests()
	var bots: Array[Bot] = []
	for i in n:
		var b := Bot.new()
		b.peer = i + 1
		b.skill = SKILLS[skill]
		b.busy = randf() * 2.0
		b.recipe = RECIPES[0]
		bots.append(b)
	var clock := [0.0]  # s; in an array so the quest_done callback sees it move
	var done := {}  # quest -> minute
	var pinned := {}  # quest -> minute it went up on the board
	var on_board := func(board: Array, _progress: Dictionary, ready: Array) -> void:
		for id: String in board:
			if id != "" and not pinned.has(id):
				pinned[id] = clock[0] / 60.0
		# ponytail: the bots claim the moment a quest is done; the walk to the board (~10 s) isn't counted yet.
		if not ready.is_empty() or board.any(func(id: String) -> bool: return id != "" and gs.QUESTS[id].kind == "board_claim"):
			gs.request_claim_quests()
	on_board.call(gs.quest_board, {}, [])
	gs.quests_changed.connect(on_board)
	var opened := [[0.0, "başlangıç"]]  # [minute, what], unlocks and finished blueprints
	var on_done := func(id: String, _gold: int) -> void:
		var minute: float = clock[0] / 60.0
		done[id] = minute
		var q: Dictionary = gs.QUESTS[id]
		if q.has("unlock"):
			opened.append([minute, q.unlock])
		if q.reward.has("part") and gs.blueprint_parts(q.reward.part) == BLUEPRINTS.get(q.reward.part, -1):
			opened.append([minute, "bp:" + q.reward.part])
	gs.quest_done.connect(on_done)
	var hopper := [0.0]  # bullets waiting in the melter; an array so _act can add to it
	var melt_rest := 0.0
	var melt_pay := 0.0
	var used_min := 0.0  # bullets used up this minute
	var rates := []  # bullets/s, per minute
	var removed60 := 0
	var stats := {"used": 0.0}
	var base := [1]  # what a hit on the best target pays
	var next_target := 0
	var keys := 0  # found so far
	var mains: Array = gs.QUESTS.keys().filter(func(id: String) -> bool: return gs.QUESTS[id].tier == "main")
	while clock[0] < MINUTES * 60.0 and not (done.has(mains[-1]) and clock[0] >= 3600.0):  # at least the hour
		var t: float = clock[0]
		for b in bots:
			b.busy -= DT
			while b.busy <= 0.0:
				b.busy += _act(b, t, base[0], stats, func(m: int) -> void: hopper[0] += m)
		if gs.unlocked("melter") and hopper[0] > 0.0:
			var m := minf(hopper[0], MELT_RATE[1 if gs.unlocked("melter_speed") else 0] * DT)
			hopper[0] -= m
			melt_rest += m
			var whole := floori(melt_rest)
			melt_rest -= whole
			stats.used += whole
			gs.quest_add("bullets_melted", whole)
			melt_pay += whole * MELT_GOLD[1 if gs.unlocked("melter_yield") else 0]
			if melt_pay >= n:  # shared out to everyone, whole dollars
				var each := floori(melt_pay / n)
				melt_pay -= each * n
				for b in bots:
					gs.player(b.peer).gold += each
				gs.vault += each * n * gs.VAULT_SHARE
				gs.quest_add("gold_earned", each * n)
		if keys < KEY_AT.size() and gs.PILE_START - gs.pile >= KEY_AT[keys]:
			keys += 1
			gs.quest_add("key_found", 1)
		if next_target < TARGETS.size() and gs.vault >= gs.GEAR[TARGETS[next_target][0]].cost:
			gs.request_buy_gear(TARGETS[next_target][0], bots[0].peer)
			base[0] = TARGETS[next_target][1]
			next_target += 1
		clock[0] += DT
		if fmod(clock[0], 60.0) < DT * 0.5:
			rates.append((stats.used - used_min) / 60.0)
			used_min = stats.used
			if rates.size() == 60:
				removed60 = gs.PILE_START - gs.pile
	gs.quest_done.disconnect(on_done)
	gs.quests_changed.disconnect(on_board)
	var gap := 0.0
	for i in range(1, opened.size()):
		gap = maxf(gap, opened[i][0] - opened[i - 1][0])
	var end: float = done.get(mains[-1], MINUTES)
	return {"n": n, "skill": skill, "done": done, "pinned": pinned, "opened": opened, "rates": rates, "main": end,
		"gap": gap, "removed60": removed60, "rate60": rates[59]}


## What bot `b` does next, at game time `t`; returns how long it takes (s).
func _act(b: Bot, t: float, base: int, stats: Dictionary, melt: Callable) -> float:
	var p: Object = gs.player(b.peer)
	if not p.has_pistol:  # off the desk at the spawn first
		gs.request_take_pistol(b.peer)
		return RELOAD
	if gs.quest_board[0] != "" and gs.QUESTS[gs.quest_board[0]].kind == "gear_bought":  # the warmup's dummy: Q, buy, put up
		gs.request_buy_gear("dummy", b.peer)
		gs.quest_add("gear_placed", 1)
		return PLACE_TIME
	var guns: Array = GUN_STEPS.filter(func(g: Array) -> bool: return g[1] == "" or gs.unlocked(g[1]))
	var gun: Array = guns[-1]
	for g: Array in guns:  # a pinned quest asks for this gun: take it, as a player would
		if gs.GUNS[g[0]].id in _wanted():
			gun = g
	if p.gun != gun[0]:
		p.carried += p.loaded
		p.loaded = 0
		p.gun = gun[0]
	var r: Dictionary = b.recipe
	if p.loaded < r.cost and p.carried > 0 and p.loaded < gs.mag_capacity_of(b.peer):
		gs.request_reload(b.peer)
		return RELOAD
	if p.loaded > 0:
		if p.loaded < r.cost:  # the last few: as plain rounds
			r = RECIPES[0]
		return _shoot(b, p, r, gun, t, base, stats)
	# Empty: off to the heap, buying upgrades on the way (Q's any time, the bench's once it's open)
	# and, once it's open, by the melter.
	var took := float(b.skill.trip)
	_buy(b)
	var cap: int = gs.carry_capacity_of(b.peer)
	for tool: Array in TOOLS:
		if gs.unlocked(tool[0]):
			cap = maxi(cap, tool[1])
	# Not request_pick_up: the hand is the "carry" upgrade there, the tools aren't in yet.
	var taken: int = gs.request_take_bullets(cap - p.carried, Vector3.ZERO)
	p.carried += taken
	gs.quest_add("bullets_carried", taken)
	if gs.unlocked("melter"):
		var m: int = p.carried - b.skill.keep * gs.mag_capacity_of(b.peer)
		if m > 0:
			p.carried -= m
			melt.call(m)
			took += MELT_WALK
	b.recipe = _best_recipe(b, gun)
	return took * (1.0 + b.skill.idle)


func _shoot(b: Bot, p: Object, r: Dictionary, gun: Array, t: float, base: int, stats: Dictionary) -> float:
	var g: Dictionary = gs.GUNS[gun[0]]
	p.loaded -= r.cost
	stats.used += r.cost
	var tags: Array = [g.id] + r.tags
	gs.quest_add("bullets_fired", r.cost, tags)  # ponytail: request_fire counts 1 until recipes cost more
	if r.cost > 1:
		gs.quest_add("crafted", r.cost)
	if randf() >= b.skill.hit * gun[2]:
		gs._break_chain(p)
		return g.interval
	if t - b.last_hit > gs.COMBO_WINDOW:
		gs._break_chain(p)
	b.last_hit = t
	var weak: bool = randf() < b.skill.head
	var cap: int = gs.upgrade_value("combo_cap", b.peer)
	var chain: int
	if weak:
		p.weak_combo = mini(p.weak_combo + 1, cap)
		chain = p.weak_combo
	else:
		p.combo = mini(p.combo + 1, cap)
		chain = p.combo
	var gold: int = gs.hit_pay(b.peer, roundi(base * r.gold), weak, chain, BEHIND)
	p.gold += gold
	gs.vault += gold * gs.VAULT_SHARE
	gs.quest_hit(tags, weak, chain, gold)
	return g.interval


## What the pinned quests' `with` ask for.
func _wanted() -> Array:
	return gs.quest_board.filter(func(id: String) -> bool: return id != "" and gs.QUESTS[id].has("with")) 		.map(func(id: String) -> String: return gs.QUESTS[id].with)


## The open recipe that pays best a second with this gun and magazine. One a pinned quest asks
## for comes first; while a combo quest is up, every third load goes in plain rounds.
func _best_recipe(b: Bot, gun: Array) -> Dictionary:
	var g: Dictionary = gs.GUNS[gun[0]]
	var mag: int = gs.mag_capacity_of(b.peer)
	var best: Dictionary = RECIPES[0]
	var best_rate := 0.0
	var wanted := _wanted()
	var open := RECIPES.filter(func(r: Dictionary) -> bool: return r.cost <= mag and r.needs.all(_open))
	for r: Dictionary in open:
		if r.tags.any(func(tag: String) -> bool: return tag in wanted):
			return r
	b.loads += 1
	if b.loads % 3 == 0 and gs.quest_board.any(func(id: String) -> bool: return id != "" and gs.QUESTS[id].kind == "combo"):
		return best  # a chain wants many quick shots, not a few dear ones
	for r: Dictionary in open:
		var shots: int = mag / r.cost
		var rate: float = r.gold * shots / (shots * g.interval + RELOAD)
		if rate > best_rate:
			best = r
			best_rate = rate
	return best


func _open(what: String) -> bool:
	if what.begins_with("bp:"):
		var id := what.substr(3)
		return gs.blueprint_parts(id) >= BLUEPRINTS[id]
	return gs.unlocked(what)


## At the bench: every upgrade gold covers, cheapest first (or a poor player's fixed order).
func _buy(b: Bot) -> void:
	while true:
		var p: Object = gs.player(b.peer)
		var pick := ""
		var price := 1 << 30
		var order: Array = gs.UPGRADES.keys() if b.skill.smart else DUMB_ORDER
		if gs.quest_board.any(func(id: String) -> bool: return id != "" and gs.QUESTS[id].kind == "bench_bought"):
			order = ["magazine"] + order  # the quest's hint sends even a careless player to the bench
		for id: String in order:
			if gs.UPGRADES[id].get("bench", false) and not gs.unlocked("workbench"):
				continue
			var lv: int = p.levels[id]
			var costs: Array = gs.UPGRADES[id].costs
			if lv < costs.size() and costs[lv] < price:
				pick = id
				price = costs[lv]
				if not b.skill.smart:
					break  # first one not maxed out, however dear
		if pick == "" or not gs.request_buy_upgrade(pick, b.peer):
			return


func _report(run: Dictionary) -> void:
	print("\n%d kişi, %s (tohum %d):" % [run.n, run.skill, SEEDS[0]])
	var line := ""
	for id: String in gs.QUESTS:
		line += "%s %s  " % [id, ("%.1f" % run.done[id]) if run.done.has(id) else "–"]
	print("  görev bitişleri (dk): " + line)
	print("  açılışlar (dk): " + "  ".join(run.opened.map(func(o: Array) -> String: return "%.1f %s" % [o[0], o[1]])))
	var curve := ""
	for m in range(4, run.rates.size(), 5):
		curve += "%d. dk %.1f  " % [m + 1, run.rates[m]]
	print("  mermi/sn (atılan + eritilen): " + curve)
	print("  ana zincir %.1f dk, en uzun bekleme %.1f dk, 60 dk'da yığından giden %d" % [run.main, run.gap, run.removed60])


func _mean(runs: Array, key: String) -> float:
	return runs.reduce(func(a: float, r: Dictionary) -> float: return a + r[key], 0.0) / runs.size()


func _max(runs: Array, key: String) -> float:
	return runs.reduce(func(a: float, r: Dictionary) -> float: return maxf(a, r[key]), 0.0)


## "mean (min-max)" over the seeds.
func _span(runs: Array, key: String, whole := false) -> String:
	var lo := INF
	var hi := -INF
	for r: Dictionary in runs:
		lo = minf(lo, r[key])
		hi = maxf(hi, r[key])
	if whole:
		return "%s" % UiStyle.dotted(roundi(_mean(runs, key)))
	return "%.1f (%.1f-%.1f)" % [_mean(runs, key), lo, hi]


func _mark(ok: bool) -> String:
	return "TAMAM" if ok else "TUTMUYOR"
