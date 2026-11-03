extends Node
## All game state lives here. Player actions are request_* commands:
## solo they run directly, in co-op they will be routed to the host.
## The world (pile, loose bullets) is shared; each player has their own hands, gun, gold and
## upgrades, kept per peer id. `peer` 0 in a request means the local player.
##
## Co-op (scripts/net.gd connects): only the host changes state. A client's request runs here
## too, as a prediction on its own PlayerState so the gun and hands answer at once, and goes to
## the host (_request), which runs it for real and answers with that player's state (_state).
## World changes (pile, loose bullets, keys, shots) happen on the host alone and reach every
## peer as events (_world -> _event), so a client never digs, traces or pays by itself.

signal pile_changed(count: int)
## Local player only; other players' state reaches their own machines over the network.
signal carried_changed(count: int)
## Where bullets left the pile, so the heap can dig there (hands, robots, belts).
signal bullets_taken(at: Vector3, count: int, step: int)
## Carried bullets thrown back out; they land as loose spill and count as pile again.
## They get ids first_id .. first_id + count - 1.
signal bullets_thrown(from: Vector3, dir: Vector3, count: int, first_id: int)
## A loose bullet (spilled or thrown) was picked up, by id; every peer removes the same one.
signal loose_taken(id: int)
## Part of the scrap heap's face gives way round `cell` (pile.gd): the host decides when and how
## big, `seed` throws the pieces that tumble off it the same way on every peer.
signal scrap_collapse(cell: Vector2i, radius: int, seed: int, step: int)
## The host's scrap heap clock (pile.gd step): a client's heap runs up to it and no further.
signal heap_clock(step: int)
## A piece of the scrap heap itself (pile.gd heap ids) was taken: at heap step `step` every peer
## digs out its room and shows the piece under it. Comes right after its loose_taken.
signal heap_piece_taken(id: int, step: int)
signal upgraded(id: String, level: int)  # local player
signal loaded_changed(count: int)        # local player
## A round left someone's gun: every peer plays the flash, shell and sound locally from this,
## first person for its own shots, in the world for everyone else's.
signal fired(peer: int, from: Vector3, dir: Vector3)
## Where that round landed. `target` is what it hit (null for a miss into the sky), `gold` what
## the shooter earned for it, `weak` whether it struck a weak spot (a zombie's head), `combo`
## the shooter's chain after it (0 when the hit paid nothing).
## Zombies react to this; impacts are drawn from it.
signal shot_landed(peer: int, at: Vector3, normal: Vector3, dir: Vector3, target: Node, gold: int, weak: bool, combo: int)
signal gold_changed(gold: int)  # local player
## Crate keys buried in the heap (scripts/key_cache.gd). Digging reached one: it pops out at `at`.
signal key_revealed(rank: int, at: Vector3)
## Someone picked a key up; every peer removes it from the heap.
signal key_taken(rank: int, peer: int)
## Another player's body moved: feet `pos`, look `yaw`/`pitch`, what they are doing (Act),
## whether they are off the ground (`air`, a jump or a fall), whether they crouch. `time` is on
## that player's own clock (seconds), so the receiver can space snapshots evenly.
signal pose_received(peer: int, time: float, pos: Vector3, yaw: float, pitch: float, act: int, air: bool, crouch: bool, aim: bool)
## The host gave this machine's player its own spawn point (index into group "spawn").
signal spawn_assigned(index: int)
## Where the keys are buried: the host rolls the seed, a client lays its keys out again from it
## (scripts/key_cache.gd).
signal key_layout(seed: int)
## The shared vault: the team's stations and the fence are paid from it. Every paying hit adds
## VAULT_SHARE of its pay on top (the shooter keeps all of theirs). Float, so $1 hits add up.
signal vault_changed(vault: float)
## Friendly fire: `shooter`'s round struck `victim`. It does no harm; it throws the victim's aim.
signal player_shot(shooter: int, victim: int, at: Vector3, dir: Vector3, special: String)
## Who stands on which spawn point (peer -> slot, the host 0); a player's colour follows it.
signal player_slots(slots: Dictionary)
## Someone walked into the local player: shove it this way (m/s), on top of its own walking.
signal pushed(vel: Vector3)
## What `peer` holds now: an index into GUNS (0 is bare fists).
signal gun_changed(peer: int, gun: int)
## `peer`'s starting pistol has wooden grips (level 1) or its tape (0): everyone's third-person view.
signal pistol_grip(peer: int, level: int)
## `peer` plays as CHARACTERS `id` now ("" before picking): their body for everyone, their arms in first person.
signal character_changed(peer: int, id: String)
signal specials_changed  # local player: the special rounds pocket, or which one is armed
## The hopper and the press, the team's: rounds waiting in the hopper's bin, the brass melted from
## them, each one's level. On a client it follows the host's, a few times a second.
signal melter_changed(bin: int, brass: int, melt_level: int, press_level: int)
signal rounds_changed  # local player: the rounds made at the press (PlayerState.rounds)
## The quest board moved: what is pinned (one id per QUEST_SLOTS slot, "" when that pool is dry),
## how far along each pinned quest is (id -> count) and which are done, their reward waiting.
signal quests_changed(board: Array, progress: Dictionary, ready: Array)
## Quest `id`'s reward was claimed; its unlock and part are the team's now, every player got `gold`.
signal quest_done(id: String, gold: int)
## Zombie waves (scripts/waves.gd): its host-side decisions, sent to everyone (see waves.gd's header).
signal wave_cue(cue: Array)
## Host only: someone pulled the wave lever (scripts/waves.gd decides whether a wave starts).
signal lever_pulled(peer: int)
## The railing's bays: what is left of each (FENCE_BAYS, from -z to +z, BAY_HP whole, 0 torn down
## and open). Host's, told to everyone (scripts/fence.gd shows it, waves.gd sends the dead through).
signal fence_changed(bays: Array)
## A player's life (docs/ayrintilar.md "Baygınlık"): `hurt` when a blow took it down (`from`, where
## it came from), else it is regen or a revive. Host's, told to everyone.
signal health_changed(peer: int, hp: float, from: Vector3, hurt: bool)
## Down at 0 life: on the floor, no moving, no shooting; the screen reddens, darkens and then
## watches a teammate (player.gd, down_view.gd). Up again when revived, or when a lost wave waits again.
signal player_downed(peer: int)
signal player_revived(peer: int)
## Host: nobody is standing any more, DOWN_TIME after the last went down (waves.gd makes it a lost wave).
signal all_down
## The day-night clock (scripts/day_night.gd shows it): the hour, 0..24, and how fast it runs, in
## hours a game second. Host's, told to everyone whenever its pace changes; every machine runs it
## on from there.
signal clock_changed(hour: float, rate: float)
## Host only: the zombie test menu asked for `count` of waves.gd TYPES `type`, in front of someone
## standing at `at` looking along `yaw` (scripts/spawn_menu.gd, debug builds; waves.gd puts them up).
signal debug_spawn_asked(type: String, at: Vector3, yaw: float, count: int)

const PILE_START := 100_000_000
## The day (2026-11-03, first guesses: the user hasn't set its length, docs/ayrintilar.md open
## questions). Night is NIGHT_FROM..NIGHT_TO in full, dusk and dawn the TWILIGHT hours before and after.
const DAY_SECONDS := 1440.0  # one day and night: an hour a minute
const START_HOUR := 9.0
const NIGHT_FROM := 21.0
const NIGHT_TO := 5.0
const TWILIGHT := 2.5
const SKIP_TO := {false: 21.5, true: 8.0}  # N (debug) by day runs the clock on to night, by night to morning
const SKIP_TIME := 5.0  # s it takes, nearly all of it dusk (or dawn)
const CLOCK_SEND := 10.0  # s between the host's clock to clients, against drift
const DEBUG_SPAWN_MAX := 20
const MAX_PLAYERS := 4
## Loose bullet ids: the baked spill is 0 .. its size - 1, thrown bullets count up from here.
const THROWN_ID_START := 1 << 20

## Upgrade tree: value per level (level 0 = start) and gold cost to reach each next level.
## All personal: each player buys their own, nothing carries over to the others.
# ponytail: placeholder numbers until the 60-minute balance pass.
const UPGRADES := {
	"carry": {"values": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "costs": [6, 15, 30, 55, 90, 140, 210, 300, 420]},
	# Up to the heavy pistol's 7-round magazine. First level in ~20 s of play, the last ~10 min in.
	# bench: bought at the workshop bench (scripts/bench_menu.gd), not in the Q menu.
	"magazine": {"values": [1, 2, 3, 4, 5, 6, 7], "costs": [8, 20, 45, 90, 160, 280], "bench": true},
	# The Deagle's attachment, put on at the bench (2026-10-28, the user's call): the laser shows
	# where the shot will land and weak spots pay LASER_WEAK_MULT on it.
	"laser": {"values": [0, 1], "costs": [40], "bench": true},
	# The starting pistol's wooden grips in place of the tape (2026-10-30, the user's call: the table
	# gives the taped one, the bench makes it the wooden one): it kicks less (viewmodel.gd SETS grip).
	# Others see it (pistol_grip).
	"grip": {"values": [0, 1], "costs": [30], "bench": true},
	# The heavy pistol, bought at the bench once the starting pistol is in hand (GUNS "bought").
	"deagle": {"values": [0, 1], "costs": [120], "bench": true},
	# The highest a combo chain can reach, on every target. The last level is COMBO_MAX.
	"combo_cap": {"values": [2, 5, 10, 15, 20], "costs": [15, 60, 180, 450]},
	# Extra gold per hit on every target, in percent.
	"gold_bonus": {"values": [0, 10, 20, 30, 40, 50, 60], "costs": [25, 60, 120, 220, 380, 600]},
	# Extra gold in percent for every metre the shooter stands behind the firing line, every target.
	"range_bonus": {"values": [0, 1, 2, 3, 4, 5], "costs": [30, 80, 180, 350, 600]},
}
## What a player can hold, in the order the bar and the number keys list them (1 = the first gun);
## everyone starts with bare fists. A gun without its model yet is not `ready`: nobody can draw it.
## Each step up empties the heap faster: interval is s between rounds (fixed, not an upgrade),
## auto fires while the button is held (else one round per click), mag multiplies the Şarjör
## upgrade (a 7-round SMG would spend more time reloading than firing). Real rates: the Uzi
## ~600 rounds/min, the Scorpion EVO 3 ~1150; here 480 and 600 (2026-10-22: both cut back, a
## Scorpion at 800 emptied the heap too easily).
## How each one kicks is the first-person gun's (scripts/viewmodel.gd SETS).
## Who a player can be, picked on joining (2026-10-30, the user's call; one each, nobody twice).
## id -> the name on the pick screen. Bodies: assets/characters/players/<id>, built by
## tools/build_zombies.gd players.
const CHARACTERS := {"boss": "Patron", "masked": "Maskeli", "worker": "İşçi", "brute": "Brute", "chupacabra": "Chupacabra"}
const GUNS := [
	{"id": "fists", "name": "Yumruk", "ready": true, "interval": 0.42, "auto": false, "mag": 0},
	# table: shut until the player takes it off the table at the spawn (request_take_pistol).
	# A 9 mm service pistol, its grip taped up; the bench gives it wooden grips (UPGRADES grip).
	{"id": "pistol", "name": "Tabanca", "ready": true, "interval": 0.5, "auto": false, "mag": 1, "table": true},
	# bought: shut until that UPGRADES level is bought at the bench.
	{"id": "deagle", "name": "Ağır Tabanca", "ready": true, "interval": 0.42, "auto": false, "mag": 1, "bought": "deagle"},
	{"id": "uzi", "name": "Mikro SMG", "ready": true, "interval": 0.125, "auto": true, "mag": 4},
	{"id": "scorpion", "name": "Kompakt SMG", "ready": true, "interval": 0.1, "auto": true, "mag": 5},
	# Final, from the 12th crate. Spins up before the first round and ramps up to this rate (the
	# first-person gun paces it; the host holds it to the top rate). crate: shut until that crate
	# opens (gun_open).
	{"id": "minigun", "name": "Minigun", "ready": true, "interval": 0.05, "auto": true, "mag": 30, "crate": 12},
]
## A weak spot pays this many times over: a collision shape in group "weak_spot" (a zombie's head).
const WEAK_MULT := 2
const LASER_WEAK_MULT := 3  # the same with the laser on the Deagle in hand: it puts the dot on the head
## Combo: each paying hit within this long of the last one adds 1 to the chain, and the chain is
## the multiplier (x3 pays 3 times over), up to the player's "combo_cap" upgrade. Weak spot hits and body hits keep
## separate chains, so a chain built on easy body shots never pays out on a head. A gap this long
## starts a chain over; a miss starts both over.
const COMBO_WINDOW := 1.5  # s
const COMBO_MAX := 20  # combo_cap's last level; the combo meter's full size and colour
const SHOT_RANGE := 300.0  # m
const SHOT_MASK := 1 | 1 << 5  # world layer (walls, floor, heap, zombies) and the railing's bars (RAIL_LAYER)
## The firing line: a railing across the shed at this x, the zombies' side past it. Players
## never cross it, and rounds fired from past it pay nothing and build no combo.
const FIRING_LINE_X := 14.0
## Physics layer of the railing's wall: it stops players (mask), never rounds (SHOT_MASK).
const FENCE_LAYER := 4
## Physics layer of the railing's posts and rails as drawn: rounds stop on them, players never meet them.
const RAIL_LAYER := 6
## A client's shots reach the host up to this much closer together than its gun's interval
## (network jitter); the host lets them through rather than eat a round the client already fired.
const NET_JITTER := 0.15  # s
## The eye above the feet (player.gd EYE): where a player's rounds leave from.
const EYE := 1.6  # m
const CROUCH_EYE := 1.1  # m, crouched (player.gd)
## A client's round must leave from within this of its synced eye (pose lag plus a sprint step);
## anything farther is a forged `from` and the host drops the shot.
const FIRE_FROM_SLACK := 1.5  # m
## A push only counts between players this close (feet, from their poses), and is never faster
## than a sprint, so a forged one cannot fling anybody across the shed.
const PUSH_REACH := 1.5  # m
const PUSH_MAX := 8.0  # m/s
const VAULT_SHARE := 0.2  # placeholder (yol haritası 7)
## Rare rounds that come out of the heap now and then (rolled on the host, per bullet picked up):
## `chance` is 1 in that many, about 1 in 75 for any of them. They go in a pocket of their own,
## not the hand; the player arms one (request_arm_special) and the next shot is that round.
## Troll rounds act on the teammate they hit. `tip` sits on the case's TipSocket
## (assets/bullet/bullet_case.glb; tools/build_tips.py).
# ponytail: placeholder odds until playtests.
const SPECIALS := {
	"punch": {"name": "Yumruk", "chance": 150, "tip": "res://assets/bullet/tips/punch.glb",
		"desc": "Vurduğun takım arkadaşını çok uzağa uçurur."},
	"balloon": {"name": "Balon", "chance": 250, "tip": "res://assets/bullet/tips/balloon.glb",
		"desc": "Vurduğun takım arkadaşı balonlarla havalanır, yavaşça süzülür."},
	"scream": {"name": "Çığlık", "chance": 400, "tip": "res://assets/bullet/tips/scream.glb",
		"desc": "Vurduğun takım arkadaşının ekranına palyaço fırlar, çığlık atar."},
}
## The quest board (docs/ayrintilar.md "Görev ağacı ve görev tahtası"), the team's: everyone's
## work counts and there is no accepting, every pinned quest moves at once. The main slot walks the
## main chain in order; each other slot draws from its tier's pool when its quest is done.
const QUEST_SLOTS := ["main", "easy", "medium", "medium", "hard"]
## Per tier, easiest first. kind: what counts (quest_add); target: how much for one player
## (quest_target scales it with the team); with: only a hit or shot with that gun or round counts;
## needs: drawn only once that is unlocked; unlock: the mechanic it opens; reward: gold (to every
## player), part (a blueprint piece for the team), perk (a mastery perk).
## Kinds: gold_earned, bullets_carried (off the heap), bullets_fired, hits, weak_hits, combo (the
## longest chain), crafted (bullets made into recipe rounds), bullets_melted, key_found, loaded
## (rounds put in a magazine), board_claim (someone at the board pressed E), gun_taken (the pistol
## off the table at the spawn), bench_bought (an upgrade bought at the workshop bench).
## The demo's pool draft (docs/gorev_sistemi_plani.md, "Görev havuzu"); numbers from tools/quest_sim.gd.
## warmup: the first minutes (docs/ayrintilar.md "Pano = teslim yeri ve ısınma zinciri"), one thing
## each; the target doesn't grow with the team and the quest is done the moment it is reached, no
## trip to the board, except t03, which is the trip. hint: the key and what to do, for the HUD.
## Their unlocks open parts of the HUD; "board" also lets the four pool slots draw.
# ponytail: crafted and bullets_melted have no hook until the bench and the melter exist (plan 6, 9).
const QUESTS := {
	"t00": {"tier": "main", "warmup": true, "name": "Tabancayı al", "kind": "gun_taken", "target": 1,
		"unlock": "workbench", "hint": ["E", "Masadaki tabancayı al"], "reward": {}},  # the bench drops in, gold shows
	"t01": {"tier": "main", "warmup": true, "name": "Hurda topla", "kind": "bullets_carried", "target": 1,
		"unlock": "hud_ammo", "hint": ["E", "Dağdan bir parça hurda al"], "reward": {}},  # the hand holds 1 at first
	"t02": {"tier": "main", "warmup": true, "name": "Hurdadan mermi yap", "kind": "loaded", "target": 1,
		"hint": ["R", "Hurdayı mermiye çevir"], "reward": {}},
	"t03": {"tier": "main", "warmup": true, "name": "Görevlerine bak", "kind": "board_claim", "target": 1,
		"unlock": "board", "hint": ["E", "Görevlerine panodan bak"], "reward": {"gold": 10}},
	# The bench is open from the pistol on (t00); a couple of quests, then the first thing on it.
	"m01": {"tier": "main", "name": "İlk kazanç", "kind": "gold_earned", "target": 6, "reward": {}},
	"m01b": {"tier": "main", "name": "İsabet serisi", "kind": "hits", "target": 12, "reward": {}},
	"m01c": {"tier": "main", "name": "Silahını geliştir", "kind": "bench_bought", "target": 1,
		"hint": ["E", "Tezgâhta silahını geliştir"], "reward": {"gold": 10}},
	"m02": {"tier": "main", "name": "Avuç avuç", "kind": "bullets_carried", "target": 19, "unlock": "bucket", "reward": {}},
	"m03": {"tier": "main", "name": "Kova dolusu", "kind": "bullets_fired", "target": 130, "unlock": "uzi", "reward": {}},
	"m04": {"tier": "main", "name": "Seri atış", "kind": "bullets_fired", "with": "uzi", "target": 420, "unlock": "blueprints", "reward": {}},
	"m05": {"tier": "main", "name": "İlk tarif", "kind": "bullets_fired", "with": "clone", "target": 520, "unlock": "hand_press", "reward": {}},
	"m06": {"tier": "main", "name": "Pres başında", "kind": "crafted", "target": 650, "unlock": "shovel", "reward": {}},
	"m07": {"tier": "main", "name": "Kürek kürek", "kind": "bullets_carried", "target": 1500, "unlock": "melter", "reward": {}},
	"m08": {"tier": "main", "name": "İlk erime", "kind": "bullets_melted", "target": 730, "unlock": "slot_machine", "reward": {}},
	"m09": {"tier": "main", "name": "Kumarbaz", "kind": "gold_earned", "target": 20000, "unlock": "scorpion", "reward": {}},
	"m10": {"tier": "main", "name": "Kompakt", "kind": "bullets_fired", "with": "scorpion", "target": 1000, "unlock": "electric_press", "reward": {}},
	"m11": {"tier": "main", "name": "Seri üretim", "kind": "crafted", "target": 750, "unlock": "wheelbarrow", "reward": {}},
	"m12": {"tier": "main", "name": "El arabası", "kind": "bullets_carried", "target": 8600, "unlock": "melter_speed", "reward": {}},
	"m13": {"tier": "main", "name": "Harlı pota", "kind": "bullets_melted", "target": 9200, "unlock": "melter_yield", "reward": {}},
	"m14": {"tier": "main", "name": "Pirinç nehri", "kind": "bullets_melted", "target": 9600, "unlock": "sweeper", "reward": {}},
	"m15": {"tier": "main", "name": "Yarım plan", "kind": "bullets_fired", "target": 1600, "unlock": "drone_teaser", "reward": {}},
	"e01": {"tier": "easy", "name": "Kafadan", "kind": "weak_hits", "target": 4, "reward": {"gold": 20}},
	"e02": {"tier": "easy", "name": "Seri", "kind": "combo", "target": 5, "reward": {"gold": 30}},
	"e03": {"tier": "easy", "name": "Hamal", "kind": "bullets_carried", "target": 420, "reward": {"gold": 40}},
	"e04": {"tier": "easy", "name": "İsabetçi", "kind": "hits", "target": 250, "reward": {"gold": 50}},
	"e05": {"tier": "easy", "name": "Tetik", "kind": "bullets_fired", "target": 640, "needs": "uzi", "reward": {"gold": 120}},
	"e06": {"tier": "easy", "name": "Uzun seri", "kind": "combo", "target": 8, "needs": "workbench", "reward": {"gold": 150}},
	"e07": {"tier": "easy", "name": "Nişancı", "kind": "weak_hits", "target": 24, "needs": "uzi", "reward": {"gold": 300}},
	"e08": {"tier": "easy", "name": "Isınma", "kind": "bullets_melted", "target": 650, "needs": "melter", "reward": {"gold": 600}},
	"e09": {"tier": "easy", "name": "Taşıyıcı", "kind": "bullets_carried", "target": 1500, "needs": "shovel", "reward": {"gold": 1000}},
	"e10": {"tier": "easy", "name": "Kombo ustası", "kind": "combo", "target": 10, "needs": "workbench", "reward": {"gold": 2000}},
	"o01": {"tier": "medium", "name": "Sabırlı", "kind": "bullets_fired", "target": 140, "reward": {"part": "dual_pistol"}},
	"o02": {"tier": "medium", "name": "Kova kova", "kind": "bullets_carried", "target": 180, "reward": {"part": "dual_pistol"}},
	"o03": {"tier": "medium", "name": "Mikro", "kind": "bullets_fired", "with": "uzi", "target": 970, "needs": "uzi", "reward": {"part": "obur"}},
	"o04": {"tier": "medium", "name": "Çırak", "kind": "crafted", "target": 1500, "needs": "blueprints", "reward": {"part": "dual_pistol"}},
	"o05": {"tier": "medium", "name": "Kafa avcısı", "kind": "weak_hits", "target": 61, "needs": "uzi", "reward": {"part": "obur"}},
	"o06": {"tier": "medium", "name": "Pota bekçisi", "kind": "bullets_melted", "target": 1200, "needs": "melter", "reward": {"part": "sekme"}},
	"o07": {"tier": "medium", "name": "Klon yağmuru", "kind": "bullets_fired", "with": "clone", "target": 1600, "needs": "hand_press", "reward": {"part": "sekme"}},
	"o08": {"tier": "medium", "name": "Akrep", "kind": "bullets_fired", "with": "scorpion", "target": 1700, "needs": "scorpion", "reward": {"part": "yanki"}},
	"o09": {"tier": "medium", "name": "Usta", "kind": "crafted", "target": 1200, "needs": "electric_press", "reward": {"part": "yanki"}},
	"o10": {"tier": "medium", "name": "Erime noktası", "kind": "bullets_melted", "target": 12000, "needs": "melter_speed", "reward": {"part": "yanki"}},
	"z01": {"tier": "hard", "name": "Kazıcı", "kind": "key_found", "target": 1, "reward": {"perk": "clone_spread"}},
	"z02": {"tier": "hard", "name": "Ritim", "kind": "combo", "target": 12, "needs": "workbench", "reward": {"perk": "clone_count"}},
	"z03": {"tier": "hard", "name": "Klon ordusu", "kind": "bullets_fired", "with": "clone", "target": 2800, "needs": "hand_press", "reward": {"perk": "clone_count_2"}},
	"z04": {"tier": "hard", "name": "Doymaz", "kind": "bullets_melted", "target": 20000, "needs": "melter", "reward": {"perk": "obur_more"}},
	"z05": {"tier": "hard", "name": "Anahtarcı", "kind": "key_found", "target": 3, "reward": {"perk": "sekme_more"}},
	"z06": {"tier": "hard", "name": "Servet", "kind": "gold_earned", "target": 43000, "needs": "scorpion", "reward": {"perk": "yanki_more"}},
}
## Kinds counted as the best single value rather than a sum (the longest combo chain).
const QUEST_PEAK_KINDS := ["combo"]
## Kinds that don't grow with the team: a combo chain is one player's, the keys are only so many,
## and the melter is one for everybody (more hands don't melt faster).
const QUEST_FIXED_KINDS := ["combo", "key_found", "bullets_melted", "bench_bought"]
## Each player past the first adds this share of a quest's target (quest_target). A var only so
## tools/quest_sim.gd can sweep it.
var quest_scale := 0.5  # tools/quest_sim.gd --sweep: four mid players finish the main chain in ~36 min
## A pool slot draws at random among this many of the easiest quests left in it.
const QUEST_DRAW := 2
## The quest board (investigation board, tools/range_dressing.gd), feet; rewards are claimed there.
const BOARD_POS := Vector3(8.85, 0.0, 26.72)
const BOARD_REACH := 3.0  # m
## The melting hopper and the press (docs/ayrintilar.md "Pres", docs/uretim_agaci.md), one each
## for the team. Rounds poured into the hopper melt MELT_RATES[melt_level] a second into brass, the
## team's; the press makes rounds out of it, each player's own. Upgrades are paid like the fence: from
## the vault in co-op, alone from one's own gold. Numbers are placeholders.
const MELTER_POS := Vector3(10.24, 0.0, 27.15)  # tools/range_dressing.gd _workshop
const PRESS_POS := Vector3(11.34, 0.0, 27.53)  # on the bench's low stand
const LEVER_POS := Vector3(8.2, 0.0, -27.6)  # the wave lever on the north wall (tools/zombie_bay.gd _lever)
const STATION_REACH := 2.0  # m from its middle, feet
## The railing's bays (docs/ayrintilar.md "Çit", 2026-10-31, the user's call: no one life for the
## whole fence; each bay has its own, a bay clawed through comes down and the dead walk in through
## the hole; it is mended at the workshop bench, bay by bay). The dead claw it down (scripts/waves.gd
## STATS: per claw, by kind); mended for gold (bench_menu.gd), never on its own between waves; a lost
## wave patches every bay up to BAY_PATCH for free. Numbers are mine, not the user's.
const BAY_HP := 12
## The railing's build, read from here alone (2026-11-01, the user: "çiti ileride hem görsel hem
## yapısal bir değişikliğe ve level sistemine göre çeşitlendireceğiz"; how is not settled yet): its
## kind, its height (the posts' tops), its rails' heights (m, the middle of each), their square
## section, how many bays (between bays + 1 posts) and the end posts' ± z. tools/build_arena.gd
## builds it from this, scripts/fence.gd reads the rails off the built one, and the ones that go over
## or under it (waves.gd cross_of) measure it by fence_top() and fence_gap().
const FENCE := {"kind": &"rail", "height": 1.1, "rails": [1.075, 0.55], "bar": 0.05, "bays": 20, "span": 27.5}
const FENCE_BAYS: int = FENCE.bays
const FENCE_MAX := BAY_HP * FENCE_BAYS  # every bay whole
const FENCE_SPAN: float = FENCE.span  # ± along z, its end posts
const BAY_PATCH := 4
const FENCE_REPAIR_COST := 3  # gold a point
const FENCE_SEND := 0.25  # s between the host's updates of the clawing to clients
const REPAIR_POS := Vector3(12.2, 0.0, 26.85)  # in front of the workshop bench (tools/range_dressing.gd _workshop)
const REPAIR_REACH := 2.5  # m, feet: bench_menu.gd opens within REACH of its front edge
## Going down (docs/ayrintilar.md "Baygınlık", 2026-10-31, the user's call: the zombies in through a
## broken bay go for the players, a player at 0 life falls, the screen reddens, darkens and then
## watches another, and after a cleared wave a teammate can raise them at a high price). The numbers
## are first guesses.
const HP_MAX := 100.0
const HP_REGEN := 10.0  # a second, outside a fight (between waves); none while the wave is on
const HP_SEND := 0.25  # s between the host's regen updates to clients
const DOWN_RED := 8.0  # s the screen reddens on the floor
const DOWN_DARK := 1.2  # s from there to black; then the view goes to a teammate, and alone (or all down) all_down
const DOWN_TIME := DOWN_RED + DOWN_DARK
const REVIVE_COST := 300  # at the first wave cleared: as much as the whole railing
const REVIVE_GROW := 100  # more per wave after it
const REVIVE_HP := 50.0  # what a raised player stands up with; the pause between waves fills the rest
## What a downed client may still ask for.
const DOWN_REQUESTS := [&"request_hello", &"request_pick_character"]
## waves.gd Phase, as the wave cues carry it.
const WAVE_READY := 0
const WAVE_STARTING := 1
const WAVE_FIGHT := 2
const WAVE_CLEARED := 3
const WAVE_FAILED := 4
const MELT_RATES := [2.0, 4.0, 8.0, 16.0, 32.0, 64.0]  # rounds a second, per level
const MELT_COSTS := [120, 500, 2000, 8000, 30000]  # to the next level
const PRESS_COSTS := [1500, 9000]
## What the press makes: brass per round, and the press level that can.
const PRESS_ROUNDS := {
	"clone": {"name": "Klon", "brass": 2, "level": 0, "desc": "Ateşlenince ikiye bölünür."},
	"electric": {"name": "Elektrikli", "brass": 6, "level": 1, "desc": "İsabette yandaki hedefe sıçrar."},
	"heavy": {"name": "Ağır", "brass": 24, "level": 2, "desc": "Hedeften seker, üçe bölünür."},
}
const MELTER_SEND := 0.25  # s between the host's updates of the melting to clients
## Name tag colour per spawn slot, until players pick their own (Faz 6, step 25).
const PLAYER_COLORS: Array[Color] = [Color(0.95, 0.55, 0.1), Color(0.2, 0.6, 1.0), Color(0.35, 0.8, 0.3), Color(0.85, 0.3, 0.75)]
## What a player is doing, sent with its pose so other machines can show it.
enum Act { IDLE, WALKING, RELOADING, SHOOTING }

## What a client may ask the host for, with its argument count (`peer` comes from the sender).
const REQUESTS := {
	&"request_buy_upgrade": 1, &"request_debug_level_up": 1, &"request_pick_up": 2,
	&"request_pick_up_loose": 1, &"request_reload": 0,
	&"request_toggle_infinite_ammo": 0, &"request_fire": 2, &"request_take_key": 1,
	&"request_throw": 2, &"request_push": 2, &"request_hello": 1,
	&"request_select_gun": 1, &"request_arm_special": 1,
	&"request_claim_quests": 0, &"request_take_pistol": 0, &"request_melt": 0,
	&"request_upgrade_station": 1, &"request_press": 2, &"request_pick_character": 1,
	&"request_pull_lever": 0, &"request_repair_fence": 0, &"request_revive": 1,
	&"request_skip_time": 0, &"request_debug_spawn": 4,
}
## Uzak Atış counts at most this many metres behind the railing (+60% at 5%/m, Altın's top).
const RANGE_BONUS_MAX := 12.0
## Render layer of what hangs over the range (roof, lamps, the bay's lid and baffles, ducts); some
## lights reach only it (tools/build_arena.gd overhead()).
const OVERHEAD_LAYER := 3
const TOKEN_FILE := "user://player_token.txt"
## World signals: emitted on the host and sent on to every client.
const EVENTS: Array[StringName] = [&"pile_changed", &"bullets_taken", &"bullets_thrown",
	&"loose_taken", &"scrap_collapse", &"heap_clock", &"heap_piece_taken", &"fired", &"shot_landed", &"key_revealed", &"key_taken", &"key_layout",
	&"player_shot", &"player_slots", &"vault_changed", &"gun_changed",
	&"quests_changed", &"quest_done", &"melter_changed", &"pistol_grip", &"character_changed", &"wave_cue",
	&"fence_changed", &"health_changed", &"player_downed", &"player_revived", &"all_down", &"clock_changed"]
## Events with a node in them, and where: nodes travel as paths, every peer runs the same scenes.
const NODE_ARG := {&"shot_landed": 4}


class PlayerState:
	var carried := 0
	var loaded := 0  # rounds in the gun
	var gold := 0
	var levels := {"carry": 0, "magazine": 0, "combo_cap": 0, "gold_bonus": 0, "range_bonus": 0, "laser": 0,
		"grip": 0, "deagle": 0}
	var gold_rest := 0.0  # the fraction of a dollar the percent bonuses left over, paid on later hits
	var cooldown := 0.0  # s; game time, so it follows Engine.time_scale like the gun does
	var combo := 0  # body hits in the current chain
	var weak_combo := 0  # weak spot hits in their own chain
	var saved_loaded := -1  # rounds in the gun before test mode (T) filled it
	var keys: Array[int] = []  # crate key ranks held (1 = most common)
	var combo_left := 0.0  # s until the body chain breaks; game time
	var weak_left := 0.0  # s until the weak spot chain breaks
	var gun := 0  # GUNS index in hand; 0 is bare fists
	var specials: Array[String] = []  # SPECIALS ids in the pocket, one per round
	var armed := ""  # the special the next shot fires; "" for a plain round
	var infinite_ammo := false  # test mode (T)
	var has_pistol := false  # took it off the table at the spawn (scripts/gun_table.gd)
	var rounds := {}  # PRESS_ROUNDS id -> made at the press, not fired yet
	var pos := Vector3.ZERO  # feet, from the last pose
	var has_pose := false
	var crouch := false  # from the last pose
	var character := ""  # CHARACTERS id; "" until picked
	var hp := HP_MAX
	var down := false
	var down_for := 0.0  # s on the floor, game time; every machine counts it from when it heard
	var down_pos := Vector3.ZERO  # host: where they fell; their poses stay there
	var hp_news := false  # host: regen not told yet


## What everyone starts with; the co-op vault starts with as much.
const START_GOLD := 20
var pile: int = PILE_START
var vault := float(START_GOLD)
var _players := {}  # peer id -> PlayerState
var _next_loose_id := THROWN_ID_START
# ponytail: grows by one per loose grab; the save system can prune ids no longer in the world.
var _taken_loose := {}
# Client side: requests sent to the host, and the last one it has answered. The host's answer is
# taken as the truth only once every request has been answered, so it never undoes a prediction
# still on its way.
var _sent_seq := 0
var _acked_seq := 0
var _claimed := {}  # loose bullet ids asked for and not answered yet, so E held asks once
var spawn_index := 0  # this machine's spawn point; the host is 0
var _spawned := false  # client: the host has placed us; until then our body stays unseen
var slots := {}  # peer -> spawn slot, everyone in the session (player_slots)
var key_seed := 0  # the key layout's seed; 0 until scripts/key_cache.gd has rolled or received one
var _spawn_slots := {}  # host: peer -> spawn index
# Host: who is who across reconnects. A client says its token on joining (request_hello); a
# leaver's state waits under it until the same token comes back.
# ponytail: a token file per machine; Steam IDs replace it in Faz 6 (step 22).
var _token_of := {}  # peer -> token
var _saved := {}     # token -> PlayerState of a player who left
var key_at := {}     # rank -> where an exposed key came out, for joiners
var quest_board := []      # pinned quest per QUEST_SLOTS slot, "" when its pool has none left
var quest_progress := {}   # pinned quest -> how far along
var quests_done: Array[String] = []  # claimed, in that order
var quests_ready: Array[String] = []  # target reached, reward not claimed yet: still pinned
var melt_bin := 0  # rounds in the hopper, waiting to melt
var brass := 0  # melted, for the press
var melt_level := 0
var press_level := 0
var _melt_part := 0.0  # host: the round melting now, how far
var _melter_wait := 0.0  # host: s until clients hear of the melting again
var _melter_news := false  # host: something changed since they last did
var fence_bays: Array[int] = []  # per FENCE_BAYS bay, from -z to +z: what is left of it
var fence: int:  # what is left of them all (checks, the repair price; nothing shows it)
	get:
		var n := 0
		for hp in fence_bays:
			n += hp
		return n
var _fence_wait := 0.0  # host: s until clients hear of the clawing again
var hour := START_HOUR  # the day-night clock, 0..24
var hour_rate := 24.0 / DAY_SECONDS  # hours a game second
var _skip_left := 0.0  # host: s of N's run still to go
var _skip_to := 0.0  # host: the hour it ends on
var _clock_wait := CLOCK_SEND
var _fence_news := false
var wave_phase := WAVE_READY  # from the wave cues, on every machine
var wave_cleared := 0  # the last wave cleared, for the revive's price
var _hp_wait := 0.0
var _all_down_sent := false  # host: once until the next READY

# The local player's view, for HUD and first-person code.
var carried: int:
	get: return player().carried
var loaded: int:
	get: return player().loaded
var gold: int:
	get: return player().gold
var carry_capacity: int:
	get: return carry_capacity_of(0)
var mag_capacity: int:
	get: return mag_capacity_of(0)
## How many play together; quest targets grow with it.
var quest_players: int:
	get: return maxi(1, slots.size())
## Seconds between shots of the gun in hand.
var fire_interval: float:
	get: return GUNS[player().gun].interval


## Offline this is 1, the same id the host has in co-op.
func local_peer() -> int:
	return multiplayer.get_unique_id()


func player(peer := 0) -> PlayerState:
	if peer == 0:
		peer = local_peer()
	if not _players.has(peer):
		_players[peer] = PlayerState.new()
		_players[peer].gold = START_GOLD
	return _players[peer]


func _is_local(peer: int) -> bool:
	return peer == 0 or peer == local_peer()


func upgrade_value(id: String, peer := 0) -> int:
	return UPGRADES[id].values[player(peer).levels[id]] if UPGRADES.has(id) else 0


func carry_capacity_of(peer: int) -> int:
	return upgrade_value("carry", peer)


func mag_capacity_of(peer: int) -> int:
	return upgrade_value("magazine", peer) * GUNS[player(peer).gun].mag


func _ready() -> void:
	_reset_quests()  # Net isn't in the tree yet; a joiner gets the host's board on joining
	fence_bays.resize(FENCE_BAYS)
	fence_bays.fill(BAY_HP)
	wave_cue.connect(_on_wave_cue)
	# Someone joined: they get the world as it is now, in one go, before any later event.
	multiplayer.peer_connected.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_event.rpc_id(id, &"pile_changed", [pile])
			_event.rpc_id(id, &"key_layout", [key_seed])
			_event.rpc_id(id, &"vault_changed", [vault])
			_event.rpc_id(id, &"melter_changed", [melt_bin, brass, melt_level, press_level])
			_event.rpc_id(id, &"fence_changed", [fence_bays])
			_event.rpc_id(id, &"clock_changed", [hour, hour_rate])
			for q: String in quests_done:  # no gold: what the team got before is not theirs
				_event.rpc_id(id, &"quest_done", [q, 0])
			_event.rpc_id(id, &"quests_changed", [quest_board, quest_progress, quests_ready])
			var heap := get_tree().get_first_node_in_group("bullet_pile")
			_join.rpc_id(id, heap.snapshot() if heap else [], _taken_loose.keys())
			for rank: int in key_states:
				if key_states[rank] != KeyState.BURIED:
					_event.rpc_id(id, &"key_revealed", [rank, key_at.get(rank, Vector3.ZERO)])
				if key_states[rank] == KeyState.TAKEN:
					_event.rpc_id(id, &"key_taken", [rank, _holder_of(rank)])
			for peer: int in _players:
				if _players[peer].gun != 0 and peer != id:
					_event.rpc_id(id, &"gun_changed", [peer, _players[peer].gun])
				if _players[peer].levels.grip > 0 and peer != id:
					_event.rpc_id(id, &"pistol_grip", [peer, _players[peer].levels.grip])
				if _players[peer].character != "" and peer != id:
					_event.rpc_id(id, &"character_changed", [peer, _players[peer].character])
				if peer != id:
					_event.rpc_id(id, &"health_changed", [peer, _players[peer].hp, Vector3.ZERO, false])
					if _players[peer].down:
						_event.rpc_id(id, &"player_downed", [peer])
			for w: Node in get_tree().get_nodes_in_group("waves"):
				for cue: Array in w.join_cues():
					_event.rpc_id(id, &"wave_cue", [cue])
			# Each player starts on a spawn point of their own: the first one nobody holds.
			var slot := 1
			while slot in _spawn_slots.values():
				slot += 1
			_spawn_slots[id] = slot
			_spawn.rpc_id(id, slot)
			slots = _slots_now()
			_world(&"player_slots", [slots]))
	multiplayer.connected_to_server.connect(func() -> void: request_hello(_token()))
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		_spawn_slots.erase(id)
		if multiplayer.is_server():
			if _token_of.has(id) and _players.has(id):
				_saved[_token_of[id]] = _players[id]  # gold, upgrades, hand, gun, keys: back when they are
			_token_of.erase(id)
			_players.erase(id)
			slots = _slots_now()
			_world(&"player_slots", [slots]))


func _slots_now() -> Dictionary:
	var all := _spawn_slots.duplicate()
	all[local_peer()] = 0
	return all


## The colour standing for `peer` (name tag).
func color_of(peer: int) -> Color:
	return PLAYER_COLORS[slots.get(peer, 0) % PLAYER_COLORS.size()]


## Every request from this peer has been answered by the host (always true solo and on the host).
func synced() -> bool:
	return _acked_seq == _sent_seq


func _process(delta: float) -> void:
	for p: PlayerState in _players.values():
		p.cooldown = maxf(p.cooldown - delta, 0.0)
		p.combo_left = maxf(p.combo_left - delta, 0.0)
		p.weak_left = maxf(p.weak_left - delta, 0.0)
		if p.combo_left == 0.0:
			p.combo = 0
		if p.weak_left == 0.0:
			p.weak_combo = 0
		if p.down:
			p.down_for += delta
	hour = fposmod(hour + hour_rate * delta, 24.0)
	if Net.is_client:
		return  # the hopper melts on the host
	_clock(delta)
	_health(delta)
	if melt_bin > 0:
		_melt_part += MELT_RATES[melt_level] * delta
		var n := mini(int(_melt_part), melt_bin)
		if n > 0:
			_melt_part -= n
			melt_bin -= n
			brass += n
			if melt_bin == 0:
				_melt_part = 0.0  # an empty hopper doesn't run ahead
			quest_add("bullets_melted", n)
			_melter_now()
	_melter_wait -= delta
	if _melter_news and _melter_wait <= 0.0:
		_melter_now(true)
	_fence_wait -= delta
	if _fence_news and _fence_wait <= 0.0:
		_fence_now(true)


## Host: N's run ends on its hour, and back to the day's own pace; clients hear of the clock now and then.
func _clock(delta: float) -> void:
	if _skip_left > 0.0:
		_skip_left -= delta
		if _skip_left <= 0.0:
			hour = _skip_to
			hour_rate = 24.0 / DAY_SECONDS
			_world(&"clock_changed", [hour, hour_rate])
	_clock_wait -= delta
	if _clock_wait <= 0.0:
		_clock_wait = CLOCK_SEND
		if Net.online:
			_event.rpc(&"clock_changed", [hour, hour_rate])


## How dark the hour `h` is: 0 by day, 1 at night, easing through dusk and dawn.
static func night_of(h: float) -> float:
	var dusk := smoothstep(NIGHT_FROM - TWILIGHT, NIGHT_FROM, h)
	var dawn := 1.0 - smoothstep(NIGHT_TO, NIGHT_TO + TWILIGHT, h)
	return maxf(dusk, dawn)


## Debug builds: the clock runs on to the night (by day) or the morning (by night) in SKIP_TIME,
## so the change is seen happening. From full day it first jumps to where dusk begins (from full
## night, dawn), which shows nothing: the light only follows how dark it is.
func request_skip_time(peer := 0) -> void:
	if not OS.is_debug_build() or _send(&"request_skip_time", [], peer) or Net.is_client:
		return
	var day := night_of(_skip_to if _skip_left > 0.0 else hour) < 0.5  # again mid-run: back the other way
	if _skip_left <= 0.0 and night_of(hour) == (0.0 if day else 1.0):
		hour = NIGHT_FROM - TWILIGHT if day else NIGHT_TO
	_skip_to = SKIP_TO[not day]
	_skip_left = SKIP_TIME
	hour_rate = fposmod(_skip_to - hour, 24.0) / SKIP_TIME
	_world(&"clock_changed", [hour, hour_rate])


## Debug builds: `count` zombies of waves.gd TYPES `type` in front of the asker (scripts/spawn_menu.gd).
func request_debug_spawn(type: String, at: Vector3, yaw: float, count: int, peer := 0) -> void:
	if not OS.is_debug_build() or _send(&"request_debug_spawn", [type, at, yaw, count], peer) or Net.is_client:
		return
	debug_spawn_asked.emit(type, at, yaw, clampi(count, 1, DEBUG_SPAWN_MAX))


## Host: the hopper or the press changed. Here at once; to clients now if `send`, else at most
## every MELTER_SEND (melting goes on many times a second).
func _melter_now(send := false) -> void:
	var args := [melt_bin, brass, melt_level, press_level]
	if not send:
		melter_changed.emit(melt_bin, brass, melt_level, press_level)
		_melter_news = true
		return
	_melter_news = false
	_melter_wait = MELTER_SEND
	_world(&"melter_changed", args)


## The bay `along` (z) falls in.
static func bay_at(along: float) -> int:
	return clampi(floori((along + FENCE_SPAN) / (FENCE_SPAN * 2.0) * FENCE_BAYS), 0, FENCE_BAYS - 1)


## The middle of bay `b` along the railing (z).
static func bay_mid(b: int) -> float:
	return -FENCE_SPAN + (b + 0.5) * FENCE_SPAN * 2.0 / FENCE_BAYS


## The railing's top (m): its highest rail's upper face, or the posts' tops if higher.
static func fence_top() -> float:
	return maxf(FENCE.height, (FENCE.rails as Array).max() + FENCE.bar * 0.5)


## The room under its lowest rail (m), floor to the rail's lower face.
static func fence_gap() -> float:
	return (FENCE.rails as Array).min() - FENCE.bar * 0.5


## Bay `b` is torn down: the dead walk through it.
func bay_open(b: int) -> bool:
	return b >= 0 and b < fence_bays.size() and fence_bays[b] <= 0


## How many bays are torn down / hurt (torn down ones too).
func fence_holes() -> int:
	return fence_bays.count(0)


func fence_hurt() -> int:
	return fence_bays.filter(func(hp: int) -> bool: return hp < BAY_HP).size()


## Host (or solo): a claw took `amount` off the bay at `along` (z); none of it goes past a bay
## already down. Clients hear of it at most every FENCE_SEND; a bay coming down at once. A
## client's own call is dropped.
func hurt_fence(amount: int, along: float) -> void:
	var bay := bay_at(along)
	if Net.is_client or amount <= 0 or fence_bays[bay] <= 0:
		return
	fence_bays[bay] -= mini(amount, fence_bays[bay])
	_fence_now(fence_bays[bay] == 0)


## Host (or solo): `amount` points back on the railing, free or paid for: the worst bay first, up
## to whole, then the next worst.
func mend_fence(amount: int) -> void:
	if Net.is_client:
		return
	while amount > 0:
		var worst := 0
		for b in FENCE_BAYS:
			if fence_bays[b] < fence_bays[worst]:
				worst = b
		if fence_bays[worst] >= BAY_HP:
			break
		var n := mini(amount, BAY_HP - fence_bays[worst])
		fence_bays[worst] += n
		amount -= n
	_fence_now(true)


## Host (or solo): a lost wave's free patch: every bay up to BAY_PATCH at least, the holes shut.
func patch_fence() -> void:
	if Net.is_client:
		return
	for b in FENCE_BAYS:
		fence_bays[b] = maxi(fence_bays[b], BAY_PATCH)
	_fence_now(true)


## Mends the railing from the workshop bench (bench_menu.gd), as much of it as the money covers
## (FENCE_REPAIR_COST a point), worst bay first, during a wave too: from the vault in co-op, alone
## from one's own gold. Returns the points mended (a client's guess; fence_changed says what came of it).
func request_repair_fence(peer := 0) -> int:
	var p := player(peer)
	var slack := 0.0 if _is_local(peer) else 1.0
	if fence >= FENCE_MAX or (p.has_pose and Vector2(p.pos.x - REPAIR_POS.x, p.pos.z - REPAIR_POS.z).length() > REPAIR_REACH + slack):
		return 0
	var money := vault if team_vault() else float(p.gold)
	var n := mini(FENCE_MAX - fence, int(money) / FENCE_REPAIR_COST)
	if n <= 0 or _send(&"request_repair_fence", [], peer):
		return maxi(n, 0)
	if team_vault():
		vault -= n * FENCE_REPAIR_COST
		_world(&"vault_changed", [vault])
	else:
		p.gold -= n * FENCE_REPAIR_COST
		if _is_local(peer):
			gold_changed.emit(p.gold)
	mend_fence(n)
	return n


## What mending the whole railing costs now.
func fence_repair_price() -> int:
	return (FENCE_MAX - fence) * FENCE_REPAIR_COST


## Host: the railing changed. Here at once; to clients now if `send`, else at most every FENCE_SEND.
func _fence_now(send := false) -> void:
	if not send:
		fence_changed.emit(fence_bays)
		_fence_news = true
		return
	_fence_news = false
	_fence_wait = FENCE_SEND
	_world(&"fence_changed", [fence_bays.duplicate()])


## Host (or solo): a blow from `from` takes `amount` off `peer`'s life (0: the local player); at 0
## they go down. Only a standing player is hurt. A client's own call is dropped.
func hurt_player(peer: int, amount: float, from: Vector3) -> void:
	if peer == 0:
		peer = local_peer()
	if Net.is_client or amount <= 0.0 or not (_is_local(peer) or _players.has(peer)):
		return
	var p := player(peer)
	if p.down:
		return
	p.hp = maxf(p.hp - amount, 0.0)
	p.hp_news = false
	_world(&"health_changed", [peer, p.hp, from, true])
	if p.hp > 0.0:
		return
	p.down = true
	p.down_for = 0.0
	p.down_pos = p.pos
	_world(&"player_downed", [peer])


## Whether `peer` (0: the local player) is down.
func is_down(peer := 0) -> bool:
	var p: PlayerState = _players.get(local_peer() if peer == 0 else peer)
	return p != null and p.down


## Everyone in the session (alone, just us).
func everyone() -> Array:
	return slots.keys() if Net.online and not slots.is_empty() else [local_peer()]


## Raises downed `peer` from the workshop bench, for REVIVE_COST plus REVIVE_GROW a wave cleared
## since the first: from the vault in co-op (it is the team's teammate), alone from one's own gold.
## Only once a wave is cleared (CLEARED, or READY after it), never during one. The place is
## temporary (bench_menu.gd), a revive point comes later.
func request_revive(target: int, peer := 0) -> bool:
	var p := player(peer)
	var t: PlayerState = _players.get(target)
	var slack := 0.0 if _is_local(peer) else 1.0
	if p.down or t == null or not t.down or not revive_open() \
			or (p.has_pose and Vector2(p.pos.x - REPAIR_POS.x, p.pos.z - REPAIR_POS.z).length() > REPAIR_REACH + slack):
		return false
	var price := revive_price()
	if (vault if team_vault() else float(p.gold)) < price:
		return false
	if _send(&"request_revive", [target], peer):
		return true
	if team_vault():
		vault -= price
		_world(&"vault_changed", [vault])
	else:
		p.gold -= price
		if _is_local(peer):
			gold_changed.emit(p.gold)
	_raise(target, REVIVE_HP)
	return true


## Reviving is open: the wave is cleared, or the next one waits after a cleared one.
func revive_open() -> bool:
	return wave_phase == WAVE_CLEARED or (wave_phase == WAVE_READY and wave_cleared > 0)


func revive_price() -> int:
	return REVIVE_COST + REVIVE_GROW * maxi(wave_cleared - 1, 0)


## Host: `peer` stands up with `hp`.
func _raise(peer: int, hp: float) -> void:
	var p := player(peer)
	p.down = false
	p.down_for = 0.0
	p.hp = hp
	p.hp_news = false
	_world(&"health_changed", [peer, hp, Vector3.ZERO, false])
	_world(&"player_revived", [peer])


## Host: regen between waves, and all_down once nobody stands.
func _health(delta: float) -> void:
	_hp_wait -= delta
	var calm := wave_phase != WAVE_FIGHT and wave_phase != WAVE_STARTING
	for peer: int in _players:
		var p: PlayerState = _players[peer]
		if calm and not p.down and p.hp < HP_MAX:
			p.hp = minf(p.hp + HP_REGEN * delta, HP_MAX)
			p.hp_news = true
		if p.hp_news and (_hp_wait <= 0.0 or p.hp == HP_MAX):
			p.hp_news = false
			_world(&"health_changed", [peer, p.hp, Vector3.ZERO, false])
	if _hp_wait <= 0.0:
		_hp_wait = HP_SEND
	if _all_down_sent:
		return
	for peer: int in everyone():
		var p: PlayerState = _players.get(peer)
		if p == null or not p.down or p.down_for < DOWN_TIME:
			return
	_all_down_sent = true
	_world(&"all_down", [])


## Every machine: the wave's phase, for regen and reviving. On the host a lost wave waiting again
## stands everyone up.
func _on_wave_cue(cue: Array) -> void:
	if cue[0] == &"reset":
		wave_phase = WAVE_READY
		return
	if cue[0] != &"phase":
		return
	var was := wave_phase
	wave_phase = cue[2]
	if wave_phase == WAVE_CLEARED:
		wave_cleared = cue[1]
	elif wave_phase == WAVE_READY:
		wave_cleared = cue[1] - 1  # waiting on wave n: n - 1 are behind us (a joiner learns it so too)
		_all_down_sent = false
		if was == WAVE_FAILED and not Net.is_client:
			for peer: int in _players:
				var p: PlayerState = _players[peer]
				if p.down:
					_raise(peer, HP_MAX)
				elif p.hp < HP_MAX:
					p.hp = HP_MAX
					p.hp_news = true


## Feet within reach of a station (MELTER_POS, PRESS_POS). The host allows a metre more for
## someone else: their pose is up to 50 ms old.
func near_station(at: Vector3, peer := 0) -> bool:
	var p := player(peer)
	if not p.has_pose:
		return true  # no body yet (checks, the first frames)
	var slack := 0.0 if _is_local(peer) else 1.0
	return Vector2(p.pos.x - at.x, p.pos.z - at.z).length() <= STATION_REACH + slack


## Pours everything in the hand into the hopper. Returns how many went in.
func request_melt(peer := 0) -> int:
	var p := player(peer)
	var n := p.carried
	if n <= 0 or not unlocked("melter") or not near_station(MELTER_POS, peer):
		return 0
	var sent := _send(&"request_melt", [], peer)
	_set_carried(peer, 0)
	if sent:
		return n  # the bin is the host's: melter_changed brings it
	melt_bin += n
	_melter_now(true)
	return n


## The next level of the hopper ("melter": melts faster) or the press ("press": new rounds).
func request_upgrade_station(what: String, peer := 0) -> bool:
	var costs: Array = MELT_COSTS if what == "melter" else PRESS_COSTS if what == "press" else []
	var level := melt_level if what == "melter" else press_level
	if costs.is_empty() or level >= costs.size() or not unlocked("melter" if what == "melter" else "hand_press"):
		return false
	var cost: int = costs[level]
	if _send(&"request_upgrade_station", [what], peer):
		return vault >= cost  # no guess: melter_changed says what came of it
	if not team_vault():
		var p := player(peer)
		if p.gold < cost:
			return false
		p.gold -= cost
		if _is_local(peer):
			gold_changed.emit(p.gold)
	elif vault < cost:
		return false
	else:
		vault -= cost
		_world(&"vault_changed", [vault])
	if what == "melter":
		melt_level += 1
	else:
		press_level += 1
	_melter_now(true)
	return true


## Makes `count` rounds of `id` at the press out of the team's brass, for this player. Returns how
## many it made (fewer if the brass runs short).
func request_press(id: String, count: int, peer := 0) -> int:
	if not PRESS_ROUNDS.has(id) or count <= 0 or not unlocked("hand_press") or not near_station(PRESS_POS, peer):
		return 0
	var r: Dictionary = PRESS_ROUNDS[id]
	count = mini(count, brass / int(r.brass))
	if r.level > press_level or count <= 0:
		return 0
	if _send(&"request_press", [id, count], peer):
		return count  # the host's answer brings the rounds, melter_changed the brass left
	var p := player(peer)
	brass -= count * int(r.brass)
	p.rounds[id] = p.rounds.get(id, 0) + count
	quest_add("crafted", count * int(r.brass))
	_melter_now(true)
	if _is_local(peer):
		rounds_changed.emit()
	return count


## Buys the next level of an upgrade if there is one and gold covers it.
func request_buy_upgrade(id: String, peer := 0) -> bool:
	if not UPGRADES.has(id):  # ids will come from peers in co-op
		return false
	if UPGRADES[id].get("bench", false) and not unlocked("workbench"):
		return false  # the bench menu hides these; the host checks too
	var p := player(peer)
	var level: int = p.levels[id]
	var costs: Array = UPGRADES[id].costs
	if level >= costs.size() or p.gold < costs[level]:
		return false
	_send(&"request_buy_upgrade", [id], peer)
	p.gold -= costs[level]
	p.levels[id] = level + 1
	if UPGRADES[id].get("bench", false):
		quest_add("bench_bought", 1)  # the host's; a client's call is dropped there
	if id == "grip" and not Net.is_client:
		_world(&"pistol_grip", [local_peer() if peer == 0 else peer, level + 1])
	if _is_local(peer):
		upgraded.emit(id, level + 1)
		gold_changed.emit(p.gold)
	return true


## The team's shared vault is a co-op thing: alone, all the money is the player's.
func team_vault() -> bool:
	return Net.online


## The team is still in the warmup (GameState QUESTS t00-t03): parts of the game wait for it.
func warming() -> bool:
	var main: String = quest_board[0] if not quest_board.is_empty() else ""
	return main != "" and QUESTS[main].get("warmup", false)


## What a player is called on screen (name tag, Q menu).
func display_name(peer := 0) -> String:
	return "Oyuncu %d" % (slots.get(local_peer() if peer == 0 else peer, 0) + 1)  # ponytail: Steam name in Faz 6


## Demo key: next level of an upgrade for free, back to the start after the last one.
func request_debug_level_up(id: String, peer := 0) -> void:
	if not OS.is_debug_build() or not UPGRADES.has(id):
		return
	_send(&"request_debug_level_up", [id], peer)
	var p := player(peer)
	p.levels[id] = (p.levels[id] + 1) % UPGRADES[id].values.size()
	if id == "grip" and not Net.is_client:
		_world(&"pistol_grip", [local_peer() if peer == 0 else peer, p.levels[id]])
	if _is_local(peer):
		upgraded.emit(id, p.levels[id])


## Takes up to `count` bullets off the pile at world point `at`, returns how many were taken.
## Host only: a client digs through its own requests.
func request_take_bullets(count: int, at: Vector3) -> int:
	if Net.is_client:
		return 0
	var taken: int = clampi(count, 0, pile)
	if taken > 0:
		pile -= taken
		_world(&"pile_changed", [pile])
		_world(&"bullets_taken", [at, taken, _heap_step()])
	return taken


## Host: part of the heap's face gives way (pile.gd decides it from the strain of takes on it).
func collapse_scrap(cell: Vector2i, radius: int, seed: int) -> void:
	if Net.is_client:
		return
	_world(&"scrap_collapse", [cell, radius, seed, _heap_step()])


## Host: where the heap's clock is, for the clients' heaps to run up to (pile.gd).
func send_heap_clock(step: int) -> void:
	if Net.online and multiplayer.is_server():
		_world(&"heap_clock", [step])


## The heap's step now: heap events carry it, so every machine applies them at the same step.
func _heap_step() -> int:
	var heap := get_tree().get_first_node_in_group("bullet_pile")
	return heap.step if heap else 0


## Player grabs bullets at `at` by hand, up to carry capacity and at most `limit`.
func request_pick_up(at: Vector3, limit := 1 << 30, peer := 0) -> int:
	var p := player(peer)
	var want := mini(carry_capacity_of(peer) - p.carried, limit)
	if want <= 0:
		return 0  # a full hand asks nobody (E held sends a request every frame otherwise)
	if _send(&"request_pick_up", [at, limit], peer):
		# The host digs; if the pile ran dry first, its answer takes the bullet back.
		var guess := clampi(want, 0, pile)
		_set_carried(peer, p.carried + guess)
		return guess
	var taken := request_take_bullets(want, at)
	if taken > 0:
		_set_carried(peer, p.carried + taken - _roll_specials(peer, taken))
		quest_add("bullets_carried", taken)
	return taken


## Host: each of `n` bullets just picked up may turn out to be a special round (SPECIALS); those
## go in the pocket. Returns how many did.
func _roll_specials(peer: int, n: int) -> int:
	var p := player(peer)
	var got := 0
	for i in n:
		var r := randf()
		for id: String in SPECIALS:
			r -= 1.0 / SPECIALS[id].chance
			if r < 0.0:
				p.specials.append(id)
				got += 1
				break
	if got > 0 and _is_local(peer):
		specials_changed.emit()
	return got


## Arms special round `id` from the pocket: the next shot is that round, on top of the magazine
## (it fires with the magazine empty too). The armed one again, or "", disarms.
func request_arm_special(id: String, peer := 0) -> void:
	var p := player(peer)
	if id != "" and id not in p.specials:
		return
	_send(&"request_arm_special", [id], peer)
	p.armed = "" if id == p.armed else id
	if _is_local(peer):
		specials_changed.emit()


## Player picks up the loose bullet `id`. The first request wins; later ones for the same
## bullet (another player, same frame) get nothing.
func request_pick_up_loose(id: int, peer := 0) -> int:
	var p := player(peer)
	if _taken_loose.has(id) or p.carried >= carry_capacity_of(peer) or pile <= 0:
		return 0
	if Net.is_client and peer == 0:
		if _claimed.has(id):
			return 0
		_claimed[id] = true
	if _send(&"request_pick_up_loose", [id], peer):
		_set_carried(peer, p.carried + 1)  # the bullet itself goes when the host says loose_taken
		return 1
	var heap := get_tree().get_first_node_in_group("bullet_pile")
	if heap and not heap.has_loose(id):
		return 0  # no such bullet lying here: a made-up id would only grow _taken_loose
	_taken_loose[id] = true
	pile -= 1
	_world(&"pile_changed", [pile])
	_set_carried(peer, p.carried + 1 - _roll_specials(peer, 1))
	_world(&"loose_taken", [id])
	var off_heap: bool = heap != null and heap.is_heap_id(id)
	if off_heap:
		_world(&"heap_piece_taken", [id, _heap_step()])
	if id < THROWN_ID_START or off_heap:  # off the heap only: throwing and re-picking a hand would farm it
		quest_add("bullets_carried", 1)
	return 1


## Moves carried bullets into the gun up to its capacity; returns how many went in.
func request_reload(peer := 0) -> int:
	var p := player(peer)
	if p.gun == 0:
		return 0
	var n := mini(mag_capacity_of(peer) - p.loaded, p.carried)
	if n <= 0:
		return 0
	_send(&"request_reload", [], peer)
	_set_carried(peer, p.carried - n)
	_set_loaded(peer, p.loaded + n)
	quest_add("loaded", n)
	return n


## Puts away what is in hand and draws GUNS[`gun`]; the same one again goes back to bare fists.
## Everyone sees it (gun_changed): the first-person arms and others' third-person hold follow it.
func request_select_gun(gun: int, peer := 0) -> void:
	var p := player(peer)
	if gun < 0 or gun >= GUNS.size() or not gun_open(gun, peer):
		return
	if gun == p.gun:
		gun = 0
	var sent := _send(&"request_select_gun", [gun], peer)
	# Each gun has its own magazine: what was in the last one goes back into the hand.
	if p.loaded > 0 and not p.infinite_ammo:
		_set_carried(peer, p.carried + p.loaded)
		_set_loaded(peer, 0)
	p.gun = gun
	if p.infinite_ammo:
		_set_loaded(peer, mag_capacity_of(peer))
	if sent:
		gun_changed.emit(local_peer(), gun)  # predicted; the host's answer (_state) settles it
		return
	_world(&"gun_changed", [local_peer() if peer == 0 else peer, gun])


## Play as CHARACTERS `id`, if nobody else has it. The host decides (two clients can ask for the
## same one at once); everyone hears it from character_changed, the picker too.
func request_pick_character(id: String, peer := 0) -> void:
	if not CHARACTERS.has(id) or character_taken(id, peer):
		return
	if _send(&"request_pick_character", [id], peer):
		return
	var who := local_peer() if peer == 0 else peer
	player(who).character = id
	_world(&"character_changed", [who, id])


## Whether someone other than `peer` plays as `id`.
func character_taken(id: String, peer := 0) -> bool:
	var me := local_peer() if peer == 0 else peer
	for other: int in _players:
		# Only those still here: a client keeps the record of someone who left.
		if other != me and _players[other].character == id and (slots.is_empty() or slots.has(other)):
			return true
	return false


## The pistol off the table at the spawn (scripts/gun_table.gd): drawn at once, its magazine empty.
## Online the draw is a request of its own, after this one: the host has the pistol on record by then.
func request_take_pistol(peer := 0) -> void:
	var p := player(peer)
	if p.has_pistol:
		return
	_send(&"request_take_pistol", [], peer)
	p.has_pistol = true
	quest_add("gun_taken", 1)
	if peer == 0 and p.gun != 1:
		request_select_gun(1)


## Whether GUNS[`gun`] can be drawn. A crate gun stays shut until its crate opens; crates are not
## in yet (yol haritası 13), so for now only test mode (T, debug builds) opens them. A table gun
## until it is taken, a bought one until it is bought at the bench.
func gun_open(gun: int, peer := 0) -> bool:
	var p := player(peer)
	return GUNS[gun].ready and (not GUNS[gun].has("crate") or p.infinite_ammo) and (not GUNS[gun].has("table") or p.has_pistol or p.infinite_ammo) \
		and (not GUNS[gun].has("bought") or p.levels[GUNS[gun].bought] > 0 or p.infinite_ammo)


## Test mode (T): the gun never runs dry, for trying the feel and effects. Per player.
var infinite_ammo: bool:
	get: return player().infinite_ammo
	set(v): player().infinite_ammo = v

const TEST_MONEY := 1_000_000_000  # what T tops gold and the vault up to


## Debug builds only. Switching it off puts back what was in the gun, so it never leaves free
## rounds behind. Switching it on also tops up gold and the vault, for trying the shop.
func request_toggle_infinite_ammo(peer := 0) -> void:
	if not OS.is_debug_build():
		return
	_send(&"request_toggle_infinite_ammo", [], peer)
	var p := player(peer)
	p.infinite_ammo = not p.infinite_ammo
	if p.infinite_ammo:
		p.saved_loaded = p.loaded
		_set_loaded(peer, mag_capacity_of(peer))
		# ponytail: the money stays after T goes off; a test build only, so not worth undoing.
		p.gold = maxi(p.gold, TEST_MONEY)
		if _is_local(peer):
			gold_changed.emit(p.gold)
		if not Net.is_client:  # the vault is the host's
			vault = maxf(vault, TEST_MONEY)
			_world(&"vault_changed", [vault])
	elif p.saved_loaded >= 0:
		_set_loaded(peer, mini(p.saved_loaded, mag_capacity_of(peer)))
		p.saved_loaded = -1
	if not gun_open(p.gun, peer):  # T off with a crate gun in hand: it goes back
		request_select_gun(0, peer)
	if _is_local(peer):
		loaded_changed.emit(player(peer).loaded)


## Fires one loaded round from `from` along `dir`. The host traces it, so who hit what and
## how much it paid is decided in one place.
func request_fire(from: Vector3, dir: Vector3, peer := 0) -> bool:
	var p := player(peer)
	# Slack for frame timing on the caller, more for a remote one's network jitter, never so much
	# that a client could fire faster than its gun does.
	var interval: float = GUNS[p.gun].interval
	if p.gun == 0 or p.down or (p.loaded <= 0 and p.armed == "") or p.cooldown > (0.02 if _is_local(peer) else minf(NET_JITTER, interval * 0.5)):
		return false
	# A remote round leaves from that player's synced eye, or not at all.
	if not _is_local(peer) and not (p.has_pose and from.distance_to(p.pos + Vector3.UP * (CROUCH_EYE if p.crouch else EYE)) <= FIRE_FROM_SLACK):
		return false
	p.cooldown += interval  # the slack is lent, not given: early shots make the next one wait longer
	var special := p.armed
	if special != "":  # an armed special goes instead of a magazine round
		p.specials.erase(special)
		p.armed = ""
		if _is_local(peer):
			specials_changed.emit()
	elif not p.infinite_ammo:
		_set_loaded(peer, p.loaded - 1)
	# A client's gun kicks and flashes now; where the round went comes back as shot_landed.
	if _send(&"request_fire", [from, dir], peer):
		return true
	var who := local_peer() if peer == 0 else peer
	_world(&"fired", [who, from, dir])
	var tags := [GUNS[p.gun].id, special]  # what quests with `with` look for
	quest_add("bullets_fired", 1, tags)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * SHOT_RANGE, SHOT_MASK)
	var own := _body_of(who)  # the round starts inside the shooter
	if own:
		q.exclude = [own.get_rid()]
	var space := get_viewport().world_3d.direct_space_state
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		_break_chain(p)
		_world(&"shot_landed", [who, from + dir * SHOT_RANGE, -dir, dir, null, 0, false, 0])
		return true
	var target: Node = hit.collider
	var victim := _peer_of(target)
	if victim != 0:  # friendly fire: no pay, no harm, the chain breaks and their aim jumps
		_break_chain(p)
		_world(&"shot_landed", [who, hit.position, hit.normal, dir, null, 0, false, 0])
		_world(&"player_shot", [who, victim, hit.position, dir, special])
		return true
	var gold := 0
	var weak := false
	var chain := 0
	# Pays only from the shooter's side of the firing line, at a target on the far side.
	# A zombie counts wherever it is: leaning over the railing, or come over, under or through it
	# (waves.gd) to our side; it could not be killed there otherwise.
	var zombie := target.has_meta("zombie")
	if target.is_in_group("target") and from.x <= FIRING_LINE_X and (zombie or hit.position.x > FIRING_LINE_X):
		var shape: Node = target.shape_owner_get_owner(target.shape_find_owner(hit.shape))
		weak = shape.is_in_group("weak_spot")
		var cap := upgrade_value("combo_cap", peer)
		if weak:
			p.weak_combo = mini(p.weak_combo + 1, cap)
			p.weak_left = COMBO_WINDOW
			chain = p.weak_combo
		else:
			p.combo = mini(p.combo + 1, cap)
			p.combo_left = COMBO_WINDOW
			chain = p.combo
		gold = hit_pay(peer, 1, weak, chain, FIRING_LINE_X - from.x)  # a zombie hit is $1 before the multipliers
		p.gold += gold
		if _is_local(peer):
			gold_changed.emit(p.gold)
		if not Net.is_client and team_vault():  # a client's prediction leaves the shared vault to the host
			vault += gold * VAULT_SHARE
			_world(&"vault_changed", [vault])
	else:
		_break_chain(p)
	_world(&"shot_landed", [who, hit.position, hit.normal, dir, target, gold, weak, chain])
	if chain > 0:  # a paying hit
		quest_hit(tags, weak, chain, gold)
	return true


## What a paying hit gives `peer`: the target's `base`, twice on a weak spot (three times with the laser), times the chain, with
## the percent upgrades for standing `behind` m back of the railing. The cents left over wait for
## the next hit. tools/quest_sim.gd pays its bots with it too.
func hit_pay(peer: int, base: int, weak: bool, chain: int, behind: float) -> int:
	var p := player(peer)
	var bonus := upgrade_value("gold_bonus", peer) + roundi(upgrade_value("range_bonus", peer) * clampf(behind, 0.0, RANGE_BONUS_MAX))
	var head := LASER_WEAK_MULT if upgrade_value("laser", peer) > 0 and GUNS[p.gun].id == "deagle" else WEAK_MULT
	var raw := float(base * (head if weak else 1) * chain) * (100 + bonus) / 100.0 + p.gold_rest
	var gold := floori(raw)
	p.gold_rest = raw - gold
	return gold


## Host (or solo): a paying hit, for the quests. tools/quest_sim.gd counts its bots' hits here too.
func quest_hit(tags: Array, weak: bool, chain: int, gold: int) -> void:
	quest_add("hits", 1, tags)
	if weak:
		quest_add("weak_hits", 1, tags)
	quest_add("combo", chain, tags)
	quest_add("gold_earned", gold)


## The body standing for `peer` here: this machine's own player, or another's character.
func _body_of(peer: int) -> CollisionObject3D:
	if peer == local_peer():
		return get_tree().get_first_node_in_group("walker") as CollisionObject3D
	var rp := get_tree().get_first_node_in_group("remote_players")
	var c: Node = rp.character(peer) if rp else null
	return c.body if c else null


## Which player a collider is (0 if it is no player).
func _peer_of(collider: Node) -> int:
	if collider.is_in_group("walker"):
		return local_peer()
	return collider.get_meta("peer", 0)


## The local player walked into `target`'s body: shove them along with `vel`. The shoved player's
## own machine moves them (everyone moves their own body), so this goes there through the host.
func request_push(target: int, vel: Vector3, peer := 0) -> void:
	if _send(&"request_push", [target, vel], peer):
		return
	var who := local_peer() if peer == 0 else peer
	var a := player(who)
	var b: PlayerState = _players.get(target)
	if target == who or not b or not b.has_pose or not a.has_pose or a.pos.distance_to(b.pos) > PUSH_REACH:
		return
	vel = Vector3(vel.x, 0.0, vel.z).limit_length(PUSH_MAX)
	if target == local_peer():
		pushed.emit(vel)
	elif Net.online:
		_pushed.rpc_id(target, vel)


## Client: someone walked into us (from the host).
@rpc("authority", "call_remote", "reliable")
func _pushed(vel: Vector3) -> void:
	pushed.emit(vel)


## Host (or solo): a fresh board, nothing done.
func start_quests() -> void:
	if Net.is_client:
		return
	_reset_quests()
	_world(&"quests_changed", [quest_board, quest_progress, quests_ready])


func _reset_quests() -> void:
	quests_done.clear()
	quests_ready.clear()
	quest_progress.clear()
	quest_board.clear()
	quest_board.resize(QUEST_SLOTS.size())
	quest_board.fill("")
	_fill_quests()


## How much of quest `id` the team has to do, for as many as play now.
func quest_target(id: String) -> int:
	var q: Dictionary = QUESTS[id]
	if q.kind in QUEST_FIXED_KINDS or q.get("warmup", false):
		return q.target
	return ceili(q.target * (1.0 + quest_scale * (quest_players - 1)))


## Whether a claimed quest has opened mechanic `what`.
func unlocked(what: String) -> bool:
	return quests_done.any(func(id: String) -> bool: return QUESTS[id].get("unlock") == what)


## Blueprint pieces of `id` the team has from claimed quests.
func blueprint_parts(id: String) -> int:
	return quests_done.filter(func(q: String) -> bool: return QUESTS[q].reward.get("part") == id).size()


## Host (or solo): `amount` more of `kind` happened. Every pinned quest of that kind counts it,
## unless it asks for a gun or round (`with`) that isn't among `tags`. One that reaches its target
## waits, done, until someone claims it at the board; a warmup one is done right away. A client's
## own call is dropped; it hears of the board from quests_changed.
func quest_add(kind: String, amount: int, tags: Array = []) -> void:
	if Net.is_client or amount <= 0:
		return
	var moved := false
	var warm := []
	for id: String in quest_board:
		if id == "" or id in quests_ready or QUESTS[id].kind != kind or (QUESTS[id].has("with") and QUESTS[id].with not in tags):
			continue
		var was: int = quest_progress[id]
		quest_progress[id] = mini(maxi(was, amount) if kind in QUEST_PEAK_KINDS else was + amount, quest_target(id))
		moved = moved or quest_progress[id] != was
		if quest_progress[id] >= quest_target(id):
			if QUESTS[id].get("warmup", false):
				warm.append(id)
			else:
				quests_ready.append(id)
				moved = true  # already at a target a smaller team lowered: the board must hear it
	for id: String in warm:  # after the loop: the next one comes in fresh, not counting this
		_finish_quest(id)
	if moved:
		_world(&"quests_changed", [quest_board, quest_progress, quests_ready])


## Anyone at the board (E) claims every done quest's reward for the team; the host decides, the
## board follows (quest_done for each, then quests_changed). Too far from it, nothing happens
## (a player the host has no pose of yet, or a headless check, is let through).
func request_claim_quests(peer := 0) -> void:
	if _send(&"request_claim_quests", [], peer):
		return
	var p := player(peer)
	if p.has_pose and Vector2(p.pos.x - BOARD_POS.x, p.pos.z - BOARD_POS.z).length() > BOARD_REACH + 1.0:
		return  # +1 m: the pose is up to 50 ms old
	quest_add("board_claim", 1)
	if quests_ready.is_empty():
		return
	for id: String in quests_ready.duplicate():
		_finish_quest(id)
	_world(&"quests_changed", [quest_board, quest_progress, quests_ready])


func _finish_quest(id: String) -> void:
	quest_board[quest_board.find(id)] = ""
	quest_progress.erase(id)
	quests_ready.erase(id)
	quests_done.append(id)
	var gold: int = QUESTS[id].reward.get("gold", 0)
	if gold > 0:
		player()  # the host's own record, even before it did anything
		for peer: int in _players:
			_players[peer].gold += gold
		gold_changed.emit(player().gold)
	_world(&"quest_done", [id, gold])
	_fill_quests()


## Host: every empty slot draws its next quest. The main slot takes the chain's next one; a pool
## slot rolls among the QUEST_DRAW easiest left, so the board climbs without being the same each game.
func _fill_quests() -> void:
	for i in QUEST_SLOTS.size():
		if quest_board[i] != "":
			continue
		if QUEST_SLOTS[i] != "main" and not unlocked("board"):
			continue  # the warmup first: one thing at a time
		var left := QUESTS.keys().filter(func(id: String) -> bool:
			var q: Dictionary = QUESTS[id]
			return q.tier == QUEST_SLOTS[i] and id not in quests_done and id not in quest_board \
				and (not q.has("needs") or unlocked(q.needs)))
		if left.is_empty():
			continue  # tried again when the next quest is done (a `needs` may have opened)
		var id: String = left[0] if QUEST_SLOTS[i] == "main" else left[randi() % mini(QUEST_DRAW, left.size())]
		quest_board[i] = id
		quest_progress[id] = 0


enum KeyState { BURIED, EXPOSED, TAKEN }
var key_states := {}  # rank -> KeyState, for every key the heap holds


## Host (or solo): the key layout's seed, told to everyone.
func set_key_seed(seed: int) -> void:
	if not Net.is_client:
		key_seed = seed
		_world(&"key_layout", [seed])


## Host (or solo): a wave's decision, told to everyone (scripts/waves.gd). A client's own calls are dropped.
func cue_wave(cue: Array) -> void:
	if not Net.is_client:
		_world(&"wave_cue", [cue])


## Pulls the wave lever, if within reach of it. The host's Waves node decides what that does.
func request_pull_lever(peer := 0) -> void:
	if not near_station(LEVER_POS, peer) or _send(&"request_pull_lever", [], peer):
		return
	lever_pulled.emit(local_peer() if peer == 0 else peer)


## The heap uncovered key `rank`; only buried keys can be revealed, once.
## Host only: the host's heap says when a key comes out.
func request_reveal_key(rank: int, at: Vector3) -> bool:
	if Net.is_client or key_states.get(rank, -1) != KeyState.BURIED:
		return false
	key_states[rank] = KeyState.EXPOSED
	key_at[rank] = at
	_world(&"key_revealed", [rank, at])
	return true


## Host: who holds taken key `rank` (a player who left still counts, under their old id).
func _holder_of(rank: int) -> int:
	for peer: int in _players:
		if rank in _players[peer].keys:
			return peer
	return 0


## A client says who it is, once connected; the host gives back what it had when it left.
func request_hello(token: String, peer := 0) -> void:
	if _send(&"request_hello", [token], peer) or peer == 0:
		return
	if token.is_empty() or token in _token_of.values():
		return  # a second window on the same machine plays as somebody new
	_token_of[peer] = token
	if _saved.has(token):
		var p: PlayerState = _saved[token]
		_saved.erase(token)
		p.cooldown = 0.0
		p.has_pose = false
		_players[peer] = p  # the answer to this request (_state) carries it to the client
		_world(&"health_changed", [peer, p.hp, Vector3.ZERO, false])
		if p.down:  # left on the floor: back on it, wherever they come in (leaving is no revive)
			p.down_pos = Vector3.INF
			_world(&"player_downed", [peer])
		if p.gun != 0:
			_world(&"gun_changed", [peer, p.gun])
		if p.levels.grip > 0:
			_world(&"pistol_grip", [peer, p.levels.grip])
		if p.character != "" and character_taken(p.character, peer):
			p.character = ""  # someone took it while they were away: they pick again
		if p.character != "":
			_world(&"character_changed", [peer, p.character])


## This machine's player token, made once and kept in user://.
func _token() -> String:
	if FileAccess.file_exists(TOKEN_FILE):
		return FileAccess.get_file_as_string(TOKEN_FILE).strip_edges()
	var t := "%x%x" % [randi(), Time.get_ticks_usec()]
	var f := FileAccess.open(TOKEN_FILE, FileAccess.WRITE)
	if f:
		f.store_string(t)
	return t


## Joiner: the heap and loose bullets as the host has them now (pile.gd snapshot()).
@rpc("authority", "call_remote", "reliable")
func _join(heap: Array, taken: Array) -> void:
	var node := get_tree().get_first_node_in_group("bullet_pile")
	if node and not heap.is_empty():
		node.restore(heap)
	for id: int in taken:
		_taken_loose[id] = true
		loose_taken.emit(id)


## A player picks up an exposed key; the first request wins.
func request_take_key(rank: int, peer := 0) -> bool:
	if key_states.get(rank, -1) != KeyState.EXPOSED:
		return false
	if _send(&"request_take_key", [rank], peer):
		return true  # no guess: two players may reach for it, the host's key_taken says who won
	key_states[rank] = KeyState.TAKEN
	player(peer).keys.append(rank)
	_world(&"key_taken", [rank, local_peer() if peer == 0 else peer])
	quest_add("key_found", 1)
	return true


func _break_chain(p: PlayerState) -> void:
	p.combo = 0
	p.combo_left = 0.0
	p.weak_combo = 0
	p.weak_left = 0.0


## Player throws everything they carry from `from` toward `dir`; it goes back to the pile.
func request_throw(from: Vector3, dir: Vector3, peer := 0) -> int:
	var n := player(peer).carried
	if n == 0:
		return 0
	_set_carried(peer, 0)
	if _send(&"request_throw", [from, dir], peer):
		return n  # the bullets fly when the host's bullets_thrown hands out their ids
	pile += n
	var first_id := _next_loose_id
	_next_loose_id += n
	_world(&"pile_changed", [pile])
	_world(&"bullets_thrown", [from, dir, n, first_id])
	return n


func _set_carried(peer: int, n: int) -> void:
	player(peer).carried = n
	if _is_local(peer):
		carried_changed.emit(n)


func _set_loaded(peer: int, n: int) -> void:
	player(peer).loaded = n
	if _is_local(peer):
		loaded_changed.emit(n)


# --- Co-op plumbing ---------------------------------------------------------------------------

## The local player's request, while joined to someone else's session, goes to the host as
## well. Returns true then; the caller predicts what it can and leaves the world to the host.
func _send(method: StringName, args: Array, peer: int) -> bool:
	if peer != 0 or not Net.is_client:
		return false
	_sent_seq += 1
	_request.rpc_id(1, method, args, _sent_seq)
	return true


## Host: a client's request. Runs it for that peer and answers with the peer's state.
@rpc("any_peer", "call_remote", "reliable")
func _request(method: StringName, args: Array, seq: int) -> void:
	if not multiplayer.is_server() or REQUESTS.get(method, -1) != args.size():
		return  # anything else off the wire is ignored
	var peer := multiplayer.get_remote_sender_id()
	if not is_down(peer) or method in DOWN_REQUESTS:  # down: no moving, shooting or buying; still answered
		callv(method, args + [peer])
	var p := player(peer)
	_state.rpc_id(peer, seq, p.carried, p.loaded, p.gold, p.levels, p.infinite_ammo, p.keys, p.gun, p.specials, p.armed, p.has_pistol, p.rounds)


## Client: the host's word on our own state, after request `seq`.
@rpc("authority", "call_remote", "reliable")
func _state(seq: int, carried_: int, loaded_: int, gold_: int, levels: Dictionary, infinite: bool, keys: Array, gun: int, specials: Array, armed: String, pistol: bool, rounds: Dictionary) -> void:
	_acked_seq = seq
	if seq != _sent_seq:
		return  # newer requests are still on their way; their answer will have it all
	_claimed.clear()
	var p := player()
	p.keys.assign(keys)
	p.infinite_ammo = infinite
	p.has_pistol = pistol
	if p.specials != specials or p.armed != armed:
		p.specials.assign(specials)  # the host rolls them: a client only learns of them here
		p.armed = armed
		specials_changed.emit()
	if p.rounds != rounds:
		p.rounds = rounds.duplicate()
		rounds_changed.emit()
	if p.carried != carried_:
		_set_carried(0, carried_)
	if p.loaded != loaded_:
		_set_loaded(0, loaded_)
	if p.gold != gold_:
		p.gold = gold_
		gold_changed.emit(gold_)
	for id: String in levels:
		if p.levels.get(id) != levels[id]:
			p.levels[id] = levels[id]
			upgraded.emit(id, levels[id])
	if p.gun != gun:  # a pick the host turned down, or the gun we had before rejoining
		p.gun = gun
		gun_changed.emit(local_peer(), gun)


## The local player's body, ~20 times a second (player.gd). Online it goes to the host, which
## keeps it (request_fire checks `from` against it) and passes it on to everyone else. Poses are
## unreliable on a channel of their own: a lost one is replaced 50 ms later anyway.
func send_pose(pos: Vector3, yaw: float, pitch: float, act: int, air: bool, crouch: bool, aim: bool) -> void:
	var p := player()
	p.pos = pos
	p.has_pose = true
	p.crouch = crouch
	if not Net.online or (Net.is_client and not _spawned):
		return  # a joiner stands on the host's spot until its own comes: bodies would collide
	var t := Time.get_ticks_msec() / 1000.0
	if multiplayer.is_server():
		_pose_of.rpc(local_peer(), t, pos, yaw, pitch, act, air, crouch, aim)
	else:
		_pose.rpc_id(1, t, pos, yaw, pitch, act, air, crouch, aim)


## Host: a client's pose.
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _pose(t: float, pos: Vector3, yaw: float, pitch: float, act: int, air: bool, crouch: bool, aim: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var p := player(peer)
	if p.down:  # on the floor where they fell, whatever their machine says
		if p.down_pos == Vector3.INF:
			p.down_pos = pos
		pos = p.down_pos
		crouch = false
	p.pos = pos
	p.has_pose = true
	p.crouch = crouch
	pose_received.emit(peer, t, pos, yaw, pitch, act, air, crouch, aim)
	for id in multiplayer.get_peers():
		if id != peer:
			_pose_of.rpc_id(id, peer, t, pos, yaw, pitch, act, air, crouch, aim)


## Client: someone else's pose, from the host.
@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _pose_of(peer: int, t: float, pos: Vector3, yaw: float, pitch: float, act: int, air: bool, crouch: bool, aim: bool) -> void:
	if peer != local_peer():
		pose_received.emit(peer, t, pos, yaw, pitch, act, air, crouch, aim)


## Client: the host's pick of our spawn point.
@rpc("authority", "call_remote", "reliable")
func _spawn(index: int) -> void:
	spawn_index = index
	spawn_assigned.emit(index)
	_spawned = true


## A world signal: emitted here, and on the host sent on to every client as well.
func _world(event: StringName, args: Array) -> void:
	callv(&"emit_signal", [event] + args)
	if Net.online and multiplayer.is_server():
		if NODE_ARG.has(event):
			var i: int = NODE_ARG[event]
			args[i] = args[i].get_path() if args[i] else NodePath()
		_event.rpc(event, args)


## Client: a world event from the host. Mirrors the shared state, then emits it as the host did.
@rpc("authority", "call_remote", "reliable")
func _event(event: StringName, args: Array) -> void:
	if event not in EVENTS:
		return
	match event:
		&"pile_changed":
			pile = args[0]
		&"loose_taken":
			_taken_loose[args[0]] = true
		&"bullets_thrown":
			_next_loose_id = maxi(_next_loose_id, args[3] + args[2])
		&"key_revealed":
			key_states[args[0]] = KeyState.EXPOSED
		&"key_taken":
			key_states[args[0]] = KeyState.TAKEN
			player(args[1]).keys.append(args[0])
		&"key_layout":
			key_seed = args[0]
		&"player_slots":
			slots = args[0]
		&"vault_changed":
			vault = args[0]
		&"fence_changed":
			fence_bays.assign(args[0])
		&"clock_changed":
			hour = args[0]
			hour_rate = args[1]
		&"health_changed":
			player(args[0]).hp = args[1]
		&"player_downed":
			player(args[0]).down = true
			player(args[0]).down_for = 0.0
		&"player_revived":
			player(args[0]).down = false
			player(args[0]).down_for = 0.0
		&"melter_changed":
			melt_bin = args[0]
			brass = args[1]
			melt_level = args[2]
			press_level = args[3]
		&"quests_changed":
			quest_board = args[0].duplicate()
			quest_progress = args[1].duplicate()
			quests_ready.assign(args[2])
		&"quest_done":
			if args[0] not in quests_done:
				quests_done.append(args[0])
			if args[1] > 0:  # the host's _state carries it too; this shows it now
				player().gold += args[1]
				gold_changed.emit(player().gold)
		&"gun_changed":
			if args[0] == local_peer():
				return  # our own: predicted, and settled by the host's answer (_state)
			player(args[0]).gun = args[1]
		&"pistol_grip":
			if args[0] == local_peer():
				return  # ours: bought here, and the host's answer (_state) settles it
			player(args[0]).levels.grip = args[1]
		&"character_changed":
			player(args[0]).character = args[1]
	if NODE_ARG.has(event):
		# A node only the host has lands as null (spent shells are on no layer, so none yet).
		var i: int = NODE_ARG[event]
		var path: NodePath = args[i]
		args[i] = null if path.is_empty() else get_node_or_null(path)
	callv(&"emit_signal", [event] + args)
