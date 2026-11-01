extends Node3D
## Zombie waves (docs/ayrintilar.md "Yeni yön: zombi dalgaları"). A player pulls the wall lever
## when the team is ready; in the user's words "şalter iner, siren ve kırmızı ışıklarla beraber
## ikili kapı ortadan yanlara doğru slide ile açılır", and the dead walk out of the pens, through the
## gates and up to the railing, where they claw at it. When the last one is down the gates close and
## the next wave waits on the lever; every wave is bigger, tougher and a little quicker.
##
## Host-authoritative like GameState: the lever is a request (GameState.request_pull_lever), the
## host plans the wave, rolls every zombie and keeps their hit points, and tells everyone through
## GameState.cue_wave. Every peer builds the same zombie under the same path (Waves/Z<id>), so
## shot_landed names it everywhere; each peer walks and animates its own copy from the cue.
## A joiner gets the phase and the living zombies where they stand (join_cues).
##
## Cues (wave_cue): [&"reset"] (a joiner drops what it had alone) · [&"phase", wave, phase, left] · [&"spawn", id, kind, seed, gate, pos, yaw,
## speed, rail_z, walking, cuts] · [&"die", id, left, killer, weak, at, gun, gib, roll, dir] ·
## [&"limb", id, part, roll] (a limb torn off, zombie_body.gd LIMBS) · [&"hp", [id, left, ...]] (what is left
## of the ones hit lately, 0..1, for the bars) · [&"scream", id, [ids]] (a screamer's cry, and the
## ones it sends running) · [&"blast", id, at] (a bloater bursting) · [&"hole", id, bay, rail_z] (off
## to the hole in `bay`, or with -1 back to clawing at rail_z) · [&"swing", id] (one inside claws at
## a player) · [&"at", [id, pos, ...], [id, pos, yaw, ...]] (where the host has the ones walking
## outside, and the ones inside).
##
## The railing (2026-10-31, the user's call): every bay of it has a life of its own (GameState.fence_bays),
## every claw takes a bite out of the bay in front (STATS); a bay clawed through comes down and the dead
## walk in through the hole, every one outside heading for the nearest hole. Inside they go for the
## nearest player standing (the host picks, GameState.hurt_player at every claw), round the workshop
## and the heap on a navigation mesh baked from the hall. Nobody standing, they wait. The wave is lost
## when everyone is down (GameState.all_down): the dead turn back, the screen says so (hud.gd), the
## holes are patched up and the same wave waits again. It is mended at the workshop bench, bay by bay
## (GameState.request_repair_fence, bench_menu.gd), never on its own between waves. scripts/fence.gd
## shows the wear, the holes and the sparks. The numbers below are first guesses.
##
## Walking (2026-10-31, the user: "zombiler çite çok saçma bir şekilde yürüyor"): each one has a
## heading that turns at TURN, rounds its waypoints instead of turning on them, sways a little off
## its line and surges a little; its spot on the railing lies near the way it comes in, so they
## don't cross the hall; it turns to face the railing as it brakes. The host sends where it has the
## ones walking (`at`): a client's copy is eased back in when it drifts, the ones inside follow the
## host's.
##
## Sounds come from the user (assets/sounds/waves/<slot>.ogg|wav): lever, siren, gate. A missing
## file stays silent.

## On every peer when a zombie goes down: who shot it (peer id), its kind, a head shot or not,
## where it stood (x: how close it got to the railing at 14) and the gun's GameState.GUNS id.
signal zombie_killed(peer: int, kind: StringName, weak: bool, at: Vector3, gun: String)
## On every peer when a claw (or a bloater bursting at it) lands on the railing: the kind, what it
## takes off the railing (STATS, BLAST_FENCE) and where. The host's _bite() does the taking.
signal fence_hit(kind: StringName, damage: int, at: Vector3)

enum Phase { READY, STARTING, FIGHT, CLEARED, FAILED }

const BODY := preload("res://scripts/zombie_body.gd")
const BAR := preload("res://scripts/zombie_hp_bar.gd")
const BLOOD := preload("res://scripts/blood_fx.gd")
const FENCE := preload("res://scripts/fence.gd")
const REACT := preload("res://scripts/zombie_hit_react.gd")
const VOICE := preload("res://scripts/zombie_voice.gd")
const SOUNDS := "res://assets/sounds/waves/"
const LEVER_TIME := 0.6  # s from the pull to the siren and the lights
const GATES_AT := 1.2  # s after the pull the gates start to slide
const GATE_TIME := 2.5  # s to slide open (or shut)
const FIGHT_AT := GATES_AT + GATE_TIME * 0.6  # the dead may walk once the gap is wide enough
const CLEAR_PAUSE := 4.0  # s from the last kill to the lever coming back up
const FAIL_PAUSE := 6.0  # s from the railing going to the same wave waiting again (hud.gd darkens over it)
const DEAD_STAY := 8.0  # s a body lies before it goes
const RAIL_X := 14.8  # where they stop, just past the railing (x 14)
const RAIL_Z := 25.5  # ± along it (its end posts are at ±27.5)
const LANE := 7.0  # m: a railing spot within this of where it comes in from the bay's mouth (times FAN)
const FAN := 1.8  # the bay's mouth is ±DOOR_Z, the railing ±RAIL_Z: the crowd fans out on the way
const POST_CLEAR := 0.45  # m a spot keeps off a post
const HOLE_OUT := 15.2  # x a zombie lines up at in front of a hole
const HOLE_IN := 12.9  # x it walks to through it, on our side
const HOLE_JITTER := 0.7  # m, ± along z off the hole's middle
const GAP := [13.65, 14.35]  # x, the railing's band: only a hole lets anyone stand in it
const TURN := 4.0  # rad/s its heading turns
const LOOK := 2.5  # m: this near a waypoint it starts turning for the next
const WANDER := 0.3  # rad, its sway off its line
const WANDER_LEN := 6.0  # m walked for one sway
const SURGE := 0.08  # its pace rises and falls by this
const FACE_TURN := 5.0  # rad/s, turning to the railing once there
## Inside (numbers mine): it claws a player within REACH m, the claw lands if they are still within
## REACH + REACH_SLACK; PLAYER_HIT times its bite per claw. The host picks prey and paths every HUNT_EVERY s.
const REACH := 1.25
const REACH_SLACK := 0.5
const PLAYER_HIT := 8.0
const HUNT_EVERY := 0.5
const AT_SEND := 0.15  # s between the host's positions of the ones walking
const AT_SLACK := 0.5  # m a client's copy outside may be off before it is pulled in
const AT_SNAP := 3.0  # m off: put there
const DOOR_X := 29.5  # just inside the bay's mouth in the hall's east wall
const DOOR_Z := 9.0  # ± (the opening is ±12)
const BAY_HALF := 12.0  # tools/build_arena.gd
const BAY_END := 36.3
const MAX_ALIVE := 40  # on the floor at once, the rest wait their turn (network load stays flat)
const SPAWN_EVERY := 0.5  # s between the waiting ones once the gates are open
const PEN_BATCH := 8  # made in one frame at the pull: 24 at once held that frame up ~40 ms
## How it comes apart (the host decides, the die cue carries it): a head shot kill now and then
## blows the head off (pop_chance()), SHRED of its hit points taken inside SHRED_TIME (a burst from
## the minigun) bursts the body, a brute, a blob and a bloater always burst (a blob has no head to
## lose). The cue also carries a `roll` made from the zombie's seed, its hits and the round's way, so
## every death comes apart differently and the same on every peer.
const SHRED := 0.85  # of its full hit points
const SHRED_TIME := 0.5
## A head blown off is a reward, not every head shot kill (2026-10-31, the user's call: "Kafa
## patlamaları nadiren girsin, sürekli girmesin; sürekli patlarsa oyuncu iyi vuruş yaptığını
## düşünmez."). The rest go down with the head snapped back, a hole and a puff. The odds follow the
## shot: a heavy gun, a round that took most of its life alone, from close by; and they drop for a
## shooter who blew one off a moment ago. First guesses, about one head shot kill in 6 to 10 on a
## usual mix (tools/head_pop_check.gd measures it).
const POP_BASE := {"pistol": 0.08, "deagle": 0.13, "uzi": 0.06, "scorpion": 0.065, "minigun": 0.07}
const POP_BASE_ELSE := 0.07
const POP_BIG := 0.14  # added when the killing round alone took POP_BIG_SHARE of its full life or more
const POP_BIG_SHARE := 0.6
const POP_NEAR := 0.12  # added at POP_NEAR_M or closer, nothing at twice that
const POP_NEAR_M := 5.0
const POP_AGAIN := 0.4  # times the odds for every head this shooter blew off in the last POP_MEMORY s
const POP_MEMORY := 10.0
const POP_MAX := 0.6
## What a paying hit takes off, by the gun it came from (GameState.GUNS id); a head shot HEAD times
## that. Hit points (STATS) are in the same units: a walker of wave 1 takes 3 Deagle rounds in the
## body, 2 in the head.
const DAMAGE := {"pistol": 20, "deagle": 34, "uzi": 13, "scorpion": 15, "minigun": 11}
const DAMAGE_ELSE := 15
const HEAD := 2.5
## Limbs (Mixamo bodies; zombie_body.gd LIMBS) are hit apart from the body: a round in an arm or a
## leg counts toward that limb's own LIMB_HP (of the zombie's full hit points) and only LIMB_BODY
## of it toward its life, so shooting one apart cripples it rather than kills it. Full, it tears
## off at the joint above the last hit. A torn arm slows its swings by ARM_SLOW of a swing each; a
## torn leg drops it to its belly to crawl at LEGLESS of its speed. A brute keeps its legs.
const LIMB_HP := {"arm": 0.35, "leg": 0.5}
const LIMB_BODY := 0.5
const ARM_SLOW := 0.6
const LEGLESS := {&"runner": 0.65}
const LEGLESS_ELSE := 0.8
## The crowd keeps apart: two closer than SPREAD m (×size; the low ones more) push each other off.
const SPREAD := 0.6
const SPREAD_PUSH := 4.0  # 1/s
## Out of a gate that has just opened they set off within RELEASE_SPREAD s of each other. A hit
## slows one to STAGGER_SLOW for a moment; the last BRAKE m to its spot it slows down to BRAKE_MIN.
const RELEASE_SPREAD := 1.5
const STAGGER_SLOW := 0.5
const BRAKE := 1.5
const BRAKE_MIN := 0.5
const WAYPOINT_SLACK := 0.8  # m: near enough to a gate's mouth on the way (only the railing spot is exact)
## kind -> walk speed (m/s), hit points at wave 1 (DAMAGE units), bite out of the fence per claw.
## Each one's speed is rolled within SPEED_ROLL of it, so a crowd never walks in step. Speeds keep
## the clips' strides on the floor (zombie_body.gd move(), tools/zombie_roles_check.gd).
## Every one runs at you (the user's call, 2026-10-30); they differ in how and how fast.
const STATS := {&"walker": [2.7, 100, 1], &"runner": [3.4, 55, 1], &"crawler": [2.4, 80, 1],
		&"brute": [2.6, 700, 5], &"blob": [1.0, 300, 2], &"dog": [4.6, 40, 1], &"bloater": [2.7, 150, 2],
		&"screamer": [2.9, 90, 1]}
const SPEED_ROLL := [0.85, 1.15]
## Screamer: on its way (inside the bay, x under SCREAM_X) it stops every SCREAM_EVERY s and cries;
## for RUSH_TIME s every other one on its way within SCREAM_REACH m goes RUSH × its speed. Not dogs
## and blobs (NO_RUSH): already as quick as their clips go.
const SCREAM_X := 28.0
const SCREAM_FIRST := [1.5, 3.5]  # s after it is let out
const SCREAM_EVERY := 9.0
const SCREAM_REACH := 9.0
const RUSH := 1.15
const NO_RUSH: Array[StringName] = [&"dog", &"blob", &"screamer"]
const RUSH_TIME := 5.0
## Bloater: bursts when it dies, BLAST damage (×the wave's growth) to every one within BLAST_REACH m,
## credited to whoever shot it; at the railing (within BLAST_RAIL m of it) the railing takes BLAST_FENCE.
const BLAST := 140
const BLAST_REACH := 3.5
const BLAST_RAIL := 1.5
const BLAST_FENCE := 8
## Dog: zigzags on its way, leaning up to ZIG m aside per m on, a swing each way every ZIG_TIME s,
## straight for the last ZIG_STOP m.
const ZIG := 1.2
const ZIG_TIME := 1.4
const ZIG_STOP := 3.0
const HP_SEND := 0.1  # s between the host's hit point updates
## The bone hit shapes and the head's ball are laid on the bones every FIT_EVERY frames (each zombie
## on its own beat): putting 40 zombies' 12 shapes to the physics every frame took ~2 ms. A round
## about to be traced (GameState.fired, before the trace) has the ones within FIT_NEAR m of its line
## fitted first, their clips brought up to date if they were held back (zombie_body.gd catch_up), so
## it meets each body where it is drawn now.
const FIT_EVERY := 3
const FIT_NEAR := 2.5
## The ones that keep low, lying along their way: kind -> trunk radius, trunk length, trunk height,
## head radius (m, ×the body's size; the crawler's is the same at every size).
const LOW := {&"crawler": [0.3, 0.9, 0.35, 0.13], &"blob": [0.42, 1.0, 0.4, 0.2], &"dog": [0.2, 0.9, 0.45, 0.13]}
## A Mixamo body's hit shapes, each a capsule laid along two bones and moved with them every frame,
## so a round meets the body where it is drawn, standing, clawing or on its belly: [from bone, to
## bone, radius (m at size 1), m on past the second bone (the hand, the toes), region (meta "region"
## on the shape: head, torso, arm_l/_r, leg_l/_r), the limb it comes off with (zombie_body.gd LIMBS)].
## The head is the weak spot's ball. Creatures (and the melty) keep one capsule for the trunk.
const BONE_SHAPES := [
	["Hips", "Neck", 0.17, 0.0, &"torso", &""],
	["LeftArm", "LeftForeArm", 0.075, 0.0, &"arm_l", &"arm_l"],
	["LeftForeArm", "LeftHand", 0.065, 0.12, &"arm_l", &"forearm_l"],
	["RightArm", "RightForeArm", 0.075, 0.0, &"arm_r", &"arm_r"],
	["RightForeArm", "RightHand", 0.065, 0.12, &"arm_r", &"forearm_r"],
	["LeftUpLeg", "LeftLeg", 0.1, 0.0, &"leg_l", &"leg_l"],
	["LeftLeg", "LeftFoot", 0.08, 0.0, &"leg_l", &"shin_l"],
	["LeftFoot", "LeftToeBase", 0.06, 0.06, &"leg_l", &"shin_l"],
	["RightUpLeg", "RightLeg", 0.1, 0.0, &"leg_r", &"leg_r"],
	["RightLeg", "RightFoot", 0.08, 0.0, &"leg_r", &"shin_r"],
	["RightFoot", "RightToeBase", 0.06, 0.06, &"leg_r", &"shin_r"],
]
## Zombie types (2026-10-31, the user: "level 1'de 3 çeşit zombi gözükmesin, tek çeşit birkaç zombi
## gelsin, giderek çeşitlendirme artsın, can barları artsın, yeni özellikler getirsinler"; which type,
## when, and every number are mine, not rules). Wave 1 is a few of one type in one look; every wave
## or two a new type comes, each with a look of its own so it is known across the hall, and most with
## a trait. type -> its kind (STATS, zombie_body.gd KINDS), the wave it comes from, hit points × the
## kind's, speed × the kind's, what a claw takes off the railing (in place of the kind's), its trait,
## and the looks it wears with the wave each comes in from (none: the kind's own).
## The second message (the same day): "zombilerin hepsi aynı hızda olmasın, çite vurdukları hasar da
## aynı olmasın, tehlikeleri giderek artsın, ama oyunu bozmayacak şekilde": a claw takes
## ×(1 + BITE_GROW·(n-1)) of it, rounded, so a 1 becomes 2 from wave 14 and a brute's 5 is 8 at 16.
## Traits: armor (a round anywhere but the head does ARMOR of its damage), mask (a head shot only
## MASK_HEAD, never blows it off), regen (REGEN_WAIT s left alone, it heals REGEN of its life a s),
## rage (under RAGE_AT of its life it roars and goes RAGE × as fast, clawing one more), swarm (comes
## as a pack, SWARM_*), leap (springs the last LEAP_FROM m to the railing; a head shot in the air
## kills), maw (the head is weak only while it roars, every MAW_EVERY s; the rest takes MAW_BODY).
const TYPES := {
	&"walker": {"kind": &"walker", "from": 1, "hp": 1.0, "speed": 1.0, "bite": 1, "trait": &"",
			"looks": [[&"prisoner", 1], [&"yaku", 12], [&"parasite", 16], [&"melty", 20]]},
	&"runner": {"kind": &"runner", "from": 2, "hp": 1.0, "speed": 1.0, "bite": 1, "trait": &"", "looks": [[&"zombiegirl", 2]]},
	&"crawler": {"kind": &"crawler", "from": 3, "hp": 1.0, "speed": 1.0, "bite": 1, "trait": &"", "looks": [[&"romero", 3]]},
	&"armored": {"kind": &"walker", "from": 4, "hp": 1.2, "speed": 0.9, "bite": 2, "trait": &"armor", "looks": [[&"copzombie", 4]]},
	&"screamer": {"kind": &"screamer", "from": 5, "hp": 1.0, "speed": 1.0, "bite": 1, "trait": &"", "looks": []},
	&"dog": {"kind": &"dog", "from": 6, "hp": 1.0, "speed": 1.0, "bite": 1, "trait": &"", "looks": []},
	&"bloater": {"kind": &"bloater", "from": 7, "hp": 1.0, "speed": 1.0, "bite": 2, "trait": &"", "looks": []},
	&"masked": {"kind": &"walker", "from": 8, "hp": 1.0, "speed": 1.05, "bite": 1, "trait": &"mask", "looks": [[&"hazmat", 8]]},
	&"regen": {"kind": &"walker", "from": 9, "hp": 1.1, "speed": 0.95, "bite": 1, "trait": &"regen", "looks": [[&"fleshzombie", 9]]},
	&"brute": {"kind": &"brute", "from": 10, "hp": 1.0, "speed": 1.0, "bite": 5, "trait": &"", "looks": []},
	&"rager": {"kind": &"walker", "from": 11, "hp": 1.3, "speed": 1.0, "bite": 2, "trait": &"rage", "looks": [[&"warzombie", 11]]},
	&"swarm": {"kind": &"runner", "from": 13, "hp": 0.5, "speed": 1.1, "bite": 1, "trait": &"swarm", "looks": [[&"skeletonzombie", 13]]},
	&"blob": {"kind": &"blob", "from": 14, "hp": 1.0, "speed": 1.0, "bite": 2, "trait": &"", "looks": []},
	&"leaper": {"kind": &"crawler", "from": 15, "hp": 0.875, "speed": 1.25, "bite": 1, "trait": &"leap", "looks": [[&"leaper", 15]]},
	&"spiker": {"kind": &"brute", "from": 25, "hp": 2.0, "speed": 0.92, "bite": 7, "trait": &"maw", "looks": [[&"spiker", 25]]},
}
const BITE_GROW := 0.04
const ARMOR := 0.4
const MASK_HEAD := 1.2  # instead of HEAD
const REGEN := 0.08
const REGEN_WAIT := 1.5
const RAGE_AT := 0.5
const RAGE := 1.25  # with a screamer's rush on top, as quick as the run clips stretch
const LEAP_FROM := 5.0  # m
const LEAP_TIME := 0.55  # s in the air
const LEAP_HIGH := 1.1  # m at the top of the arc
const MAW_EVERY := 5.0  # s from one roar to the next
const MAW_FIRST := [2.0, 4.0]  # s after it is let out
const MAW_HEAD := 3.0  # instead of HEAD, while it roars; ×1 otherwise
const MAW_BODY := 0.5
## Elite: from ELITE_FROM any one but the big ones (NO_ELITE) may come as an elite, ELITE_CHANCE then,
## ELITE_GROW more each wave, up to ELITE_MAX: ELITE_HP × the life, ELITE_SIZE × as big, ELITE_SPEED ×
## as quick, a claw more, a gold-edged bar.
const ELITE_FROM := 11
const ELITE_CHANCE := 0.05
const ELITE_GROW := 0.01
const ELITE_MAX := 0.15
const ELITE_HP := 2.0
const ELITE_SIZE := 1.15
const ELITE_SPEED := 1.05
const NO_ELITE: Array[StringName] = [&"brute", &"blob", &"dog", &"swarm", &"spiker", &"leaper"]  # leaper: its crawl clip strides no quicker
## Wave n: BASE_COUNT + COUNT_GROW·(n-1) zombies; hit points ×(1 + HP_GROW·(n-1)), speed
## ×(1 + SPEED_GROW·(n-1)) up to SPEED_MAX. MIX: type -> its share the wave it comes (TYPES), how
## much the share grows each wave after, the most it gets; the rest are walkers. Shares are counted,
## not rolled, so a type's first wave always shows a few of it. Screamers come one each from their
## wave, one more every SCREAMER_GROW waves, up to SCREAMER_MAX; brutes one from theirs, one more
## every BRUTE_EVERY. From DOG_FROM a pack of dogs comes on top, all together: DOG_PACK of them, one
## more every DOG_PACK_GROW waves, up to DOG_PACK_MAX; skeletons the same (SWARM_*).
const BASE_COUNT := 6
const COUNT_GROW := 3
const HP_GROW := 0.15
const SPEED_GROW := 0.02
const SPEED_MAX := 1.2
const MIX := {&"runner": [0.2, 0.01, 0.18], &"crawler": [0.12, 0.0, 0.1], &"armored": [0.15, 0.005, 0.13],
		&"bloater": [0.06, 0.01, 0.08], &"masked": [0.12, 0.0, 0.1], &"regen": [0.1, 0.0, 0.1],
		&"rager": [0.1, 0.0, 0.1], &"blob": [0.05, 0.005, 0.06], &"leaper": [0.08, 0.005, 0.12]}
const BLOB_FROM: int = TYPES[&"blob"].from
const SCREAMER_FROM: int = TYPES[&"screamer"].from
const SCREAMER_GROW := 3
const SCREAMER_MAX := 4
const BRUTE_FROM: int = TYPES[&"brute"].from
const BRUTE_EVERY := 5
const SPIKER_FROM: int = TYPES[&"spiker"].from
const SPIKER_EVERY := 10
const DOG_FROM: int = TYPES[&"dog"].from
const DOG_PACK := 2
const DOG_PACK_GROW := 2
const DOG_PACK_MAX := 8
const SWARM_FROM: int = TYPES[&"swarm"].from
const SWARM_PACK := 4
const SWARM_PACK_GROW := 3
const SWARM_PACK_MAX := 8
const STATUS := {Phase.READY: "HAZIR", Phase.STARTING: "AÇILIYOR", Phase.CLEARED: "TEMİZ", Phase.FAILED: "HERKES DÜŞTÜ"}

var wave := 1
var phase := Phase.READY
var left := 0  # zombies of this wave not yet down (waiting ones too)
var fence: int:  # what is left of the railing's bays, all of them (GameState's)
	get: return GameState.fence

var _zombies := {}  # id -> record (see _add_zombie)
var _spawns: Array[Node3D] = []
var _gates: Array[Node3D] = []
var _gate_home := {}  # leaf -> closed position
var _gate_tween: Tween
var _gates_open := false
var _alarms: Array[Node3D] = []
var _spins: Array[Node3D] = []  # turning now
var _spins_paused: Array[Node3D] = []  # the beacons' mirrors while dark
var _lit := false
var _lever: Node3D
var _lever_anim: AnimationPlayer
var _lever_clip := &""
var _number: Label3D
var _status: Label3D
var _shown_wave := -1
var _seq := 0  # bumped by every phase, so a sequence left waiting stops when the next comes
var _fence: Node3D  # scripts/fence.gd: the railing's wear and sparks
# Host only.
var _rng := RandomNumberGenerator.new()
var _queue: Array[StringName] = []
var _hp := {}  # id -> hit points left
var _hp_full := {}  # id -> what it came with
var _limb_hits := {}  # id -> {"arm_l": damage taken, ...}
var _pops := {}  # peer -> times (s) it blew a head off lately
var _hp_news := {}  # id -> left 0..1, not sent yet
var _hp_wait := 0.0
var _next_id := 1
var _next_spawn := 0
var _spawn_wait := 0.0
var _beat := 0  # frames, for FIT_EVERY
var _at_wait := 0.0
var _holes: Array[int] = []  # host: the bays down, as last seen
var _nav: NavigationRegion3D  # our side of the railing, for the ones inside


## A zombie's body: what the shot code and the HUD ask of a target.
class Zombie extends StaticBody3D:
	var tall := 1.8

	func above_head() -> Vector3:
		return global_position + Vector3.UP * (tall + 0.15)


func _ready() -> void:
	add_to_group("waves")
	_rng.randomize()
	for s: Node3D in get_tree().get_nodes_in_group("wave_spawn"):
		_spawns.append(s)
	for g: Node3D in get_tree().get_nodes_in_group("wave_gate"):
		_gates.append(g)
		_gate_home[g] = g.position
	for a: Node3D in get_tree().get_nodes_in_group("wave_alarm"):
		_alarms.append(a)
		var spin := a.find_child("Spin", true, false)
		if spin:
			_spins_paused.append(spin)
	_lever = get_tree().get_first_node_in_group("wave_lever")
	if _lever:
		_lever_anim = _lever.find_child("AnimationPlayer", true, false)
		if _lever_anim and not _lever_anim.get_animation_list().is_empty():
			_lever_clip = _lever_anim.get_animation_list()[0]
			_lever_anim.play(_lever_clip)  # rest on its first frame: up
			_lever_anim.seek(0.0, true)
			_lever_anim.pause()
		_number = _lever.find_child("Number", true, false)
		_status = _lever.find_child("Status", true, false)
	GameState.wave_cue.connect(_on_cue)
	GameState.lever_pulled.connect(_on_lever)
	GameState.shot_landed.connect(_on_shot)
	GameState.fired.connect(func(_peer: int, from: Vector3, dir: Vector3) -> void: fit_along(from, dir))
	BLOOD.warm()
	VOICE.warm()
	_prewarm.call_deferred()
	GameState.fence_changed.connect(_on_fence)
	GameState.all_down.connect(_lose)
	_fence = FENCE.new()
	add_child(_fence)
	_nav = NavigationRegion3D.new()
	add_child(_nav)
	_bake_nav.call_deferred()
	# The host is gone: its timers and hit points went with it, so the wave starts over here.
	multiplayer.server_disconnected.connect(func() -> void: _reset())
	_sign()
	_pen_cries()


## The local player at `at` may pull the lever now (player.gd shows the hint, E pulls it).
func can_pull(at: Vector3) -> bool:
	var to := Vector2(at.x - GameState.LEVER_POS.x, at.z - GameState.LEVER_POS.z)
	return phase == Phase.READY and to.length() <= GameState.STATION_REACH


## Host: what a joiner needs, in order: the phase, then every zombie still standing where it is now.
func join_cues() -> Array:
	var cues := [[&"reset"], [&"phase", wave, phase, left]]
	for id: int in _zombies:
		var z: Dictionary = _zombies[id]
		if not z.dead:
			var node: Node3D = z.node
			cues.append([&"spawn", id, z.kind, z.seed, z.gate, node.global_position, node.global_rotation.y,
					z.speed, z.rail.z, z.moving, z.body.cuts.duplicate(), z.type, z.body.model, z.elite, z.hole, z.inside])
	var hurt := []
	for id: int in _hp:
		if _zombies.has(id) and _hp[id] < _hp_full[id]:
			hurt.append_array([id, float(_hp[id]) / _hp_full[id]])
	if not hurt.is_empty():
		cues.append([&"hp", hurt])
	return cues


func _process(delta: float) -> void:
	for s in _spins:
		s.rotate_object_local(Vector3.UP, TAU * 0.8 * delta)
	for z: Dictionary in _zombies.values():
		if not z.dead:
			_walk(z, delta)
	_spread(delta)
	_beat += 1
	for z: Dictionary in _zombies.values():
		if not z.dead and (_beat + z.id) % FIT_EVERY == 0:
			_fit(z)
	if Net.is_client:
		return
	if phase == Phase.FIGHT and not _queue.is_empty():
		_spawn_wait -= delta
		if _spawn_wait <= 0.0 and _alive() < MAX_ALIVE:
			_spawn_wait = SPAWN_EVERY
			_spawn_next()
	if phase == Phase.FIGHT:
		_screams(delta)
		_maws(delta)
		_regen(delta)
	_at_wait -= delta
	if _at_wait <= 0.0 and Net.online:
		_at_wait = AT_SEND
		_send_at()
	_hp_wait -= delta
	if not _hp_news.is_empty() and _hp_wait <= 0.0:
		_hp_wait = HP_SEND
		var out := []
		for id: int in _hp_news:
			out.append_array([id, _hp_news[id]])
		_hp_news.clear()
		GameState.cue_wave([&"hp", out])


# --- host -----------------------------------------------------------------------------------------

func _on_lever(_peer: int) -> void:
	if phase != Phase.READY or Net.is_client:
		return
	_queue = _plan(wave)
	_hp.clear()
	_hp_full.clear()
	_hp_news.clear()
	_limb_hits.clear()
	_next_spawn = 0
	GameState.cue_wave([&"phase", wave, Phase.STARTING, _queue.size()])
	var seq := _seq
	var fight := get_tree().create_timer(FIGHT_AT)
	for i in mini(_spawns.size(), _queue.size()):  # a pen-full waits behind the gates, PEN_BATCH a frame
		if i > 0 and i % PEN_BATCH == 0:
			await get_tree().process_frame
			if seq != _seq:
				return
		_spawn_next()
	await fight.timeout
	if seq == _seq:
		GameState.cue_wave([&"phase", wave, Phase.FIGHT, left])
		_check_clear()  # shot down in the pens before the gates were wide enough


## What wave `w` sends, in order: the types (TYPES).
func _plan(w: int) -> Array[StringName]:
	var n := BASE_COUNT + COUNT_GROW * (w - 1)
	var out: Array[StringName] = []
	for t: StringName in MIX:
		for i in mini(roundi(share(t, w) * n), n - out.size()):
			out.append(t)
	while out.size() < n:
		out.append(&"walker")
	_shuffle(out)
	for i in screamers(w):  # inside the crowd, where there are others to send running
		out.insert(_rng.randi_range(out.size() / 4, out.size() * 3 / 4), &"screamer")
	for pair: Array in [[&"brute", brutes(w)], [&"spiker", spikers(w)]]:  # not first out of the gate
		for i in pair[1]:
			out.insert(_rng.randi_range(out.size() / 3, out.size()), pair[0])
	for pack: Array in [[&"dog", dogs(w)], [&"swarm", swarm(w)]]:  # a while in, so they come at a railing that is already busy
		var at := _rng.randi_range(out.size() / 4, out.size())
		while at > 0 and at < out.size() and out[at - 1] == out[at] and out[at] in [&"dog", &"swarm"]:
			at += 1  # not into the middle of the other pack
		for i in pack[1]:
			out.insert(at, pack[0])
	return out


## The host's own shuffle (Array.shuffle() takes the global seed).
func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Of wave `w`, the share of `type` (MIX, from its TYPES wave).
static func share(type: StringName, w: int) -> float:
	var m: Array = MIX[type]
	var from: int = TYPES[type].from
	return 0.0 if w < from else minf(m[0] + m[1] * (w - from), maxf(m[0], m[2]))


static func screamers(w: int) -> int:
	return 0 if w < SCREAMER_FROM else mini(1 + (w - SCREAMER_FROM) / SCREAMER_GROW, SCREAMER_MAX)


static func brutes(w: int) -> int:
	return 0 if w < BRUTE_FROM else 1 + (w - BRUTE_FROM) / BRUTE_EVERY


static func spikers(w: int) -> int:
	return 0 if w < SPIKER_FROM else 1 + (w - SPIKER_FROM) / SPIKER_EVERY


static func dogs(w: int) -> int:
	return 0 if w < DOG_FROM else mini(DOG_PACK + (w - DOG_FROM) / DOG_PACK_GROW, DOG_PACK_MAX)


static func swarm(w: int) -> int:
	return 0 if w < SWARM_FROM else mini(SWARM_PACK + (w - SWARM_FROM) / SWARM_PACK_GROW, SWARM_PACK_MAX)


## Of wave `w`, the odds one comes as an elite.
static func elite_chance(type: StringName, w: int) -> float:
	if w < ELITE_FROM or type in NO_ELITE:
		return 0.0
	return minf(ELITE_CHANCE + ELITE_GROW * (w - ELITE_FROM), ELITE_MAX)


## What a claw of `type` takes off the railing in wave `w`.
static func bite_of(type: StringName, w: int, elite := false) -> int:
	var t: Dictionary = TYPES.get(type, {"kind": type})
	var b: float = t.get("bite", STATS[t.kind][2])
	return roundi(b * (1.0 + BITE_GROW * (w - 1))) + (1 if elite else 0)


## Hit points of `type` (or a kind of the same name) in wave `w`.
static func hp_of(type: StringName, w: int, elite := false) -> int:
	var t: Dictionary = TYPES.get(type, {"kind": type, "hp": 1.0})
	return ceili(STATS[t.kind][1] * t.hp * (1.0 + HP_GROW * (w - 1)) * (ELITE_HP if elite else 1.0))


## The looks `type` may wear in wave `w` (empty: whatever its kind wears).
static func looks(type: StringName, w: int) -> Array:
	var out := []
	for l: Array in TYPES.get(type, {"looks": []}).looks:
		if w >= l[1]:
			out.append(l[0])
	return out


func _spawn_next() -> void:
	var type: StringName = _queue.pop_front()
	var t: Dictionary = TYPES.get(type, {"kind": type})
	var kind: StringName = t.kind
	var at: Node3D = _spawns[_next_spawn % _spawns.size()]
	var pos := at.global_position
	if _next_spawn >= _spawns.size():  # a marker used before: not quite on the same spot
		pos += Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4))
	_next_spawn += 1
	var id := _next_id
	_next_id += 1
	var st: Array = STATS[kind]
	var elite := _rng.randf() < elite_chance(type, wave)
	_hp[id] = hp_of(type, wave, elite)
	_hp_full[id] = _hp[id]
	var speed: float = st[0] * t.get("speed", 1.0) * minf(1.0 + SPEED_GROW * (wave - 1), SPEED_MAX) * _rng.randf_range(SPEED_ROLL[0], SPEED_ROLL[1])
	if elite:
		speed *= ELITE_SPEED
	var worn := looks(type, wave)
	var model: StringName = worn[_rng.randi() % worn.size()] if worn else &""
	var lane := 0.0
	for g in _gates:
		if g.get_meta("gate") == at.get_meta("gate"):
			lane = clampf((g.get_meta("mouth") as Vector3).z, -DOOR_Z, DOOR_Z)
	GameState.cue_wave([&"spawn", id, kind, _rng.randi(), at.get_meta("gate"), pos, at.global_rotation.y,
			speed, _rail_spot(lane), phase == Phase.FIGHT, [], type, model, elite])


## Host: a spot along the railing nobody living has (a few tries; with a full railing, any), near
## the way it comes (`lane`, z at the bay's mouth, fanned out) so the crowd doesn't cross the hall,
## and off the posts, where it would claw at nothing.
func _rail_spot(lane: float) -> float:
	var z := 0.0
	var bay := GameState.FENCE_SPAN * 2.0 / GameState.FENCE_BAYS
	for i in 6:
		z = clampf(lane * FAN + _rng.randf_range(-LANE, LANE), -RAIL_Z, RAIL_Z)
		var off := fposmod(z + GameState.FENCE_SPAN, bay)  # from the post below
		z += maxf(0.0, POST_CLEAR - off) - maxf(0.0, off - (bay - POST_CLEAR))
		var free := true
		for o: Dictionary in _zombies.values():
			if not o.dead and absf(o.rail.z - z) < SPREAD * 1.2:
				free = false
				break
		if free:
			break
	return z


func _alive() -> int:
	var n := 0
	for z: Dictionary in _zombies.values():
		if not z.dead:
			n += 1
	return n


## Host: a claw landed on the railing `along` z (or `damage` of something else, a bloater bursting):
## off the bay there. A bay coming down sends the dead through (_on_fence).
func _bite(kind: StringName, along: float, damage := -1) -> void:
	if phase != Phase.FIGHT:
		return
	GameState.hurt_fence(STATS[kind][2] if damage < 0 else damage, along)


## Host: everyone is down (GameState.all_down): the wave is lost. The dead turn back and, once the
## screen has said so, the holes are patched up and the same wave waits again.
func _lose() -> void:
	if Net.is_client or phase != Phase.FIGHT:
		return
	GameState.cue_wave([&"phase", wave, Phase.FAILED, left])
	var seq := _seq
	await get_tree().create_timer(FAIL_PAUSE).timeout
	if seq == _seq:
		GameState.patch_fence()
		GameState.cue_wave([&"phase", wave, Phase.READY, 0])


## Every peer: the railing changed; the host sends the ones outside to the nearest hole when one
## opens, and back to clawing when theirs is mended.
func _on_fence(_bays: Array) -> void:
	_sign()
	if Net.is_client:
		return
	var holes: Array[int] = []
	for b in GameState.FENCE_BAYS:
		if GameState.bay_open(b):
			holes.append(b)
	if holes == _holes:
		return
	_holes = holes
	if phase != Phase.FIGHT:
		return
	for z: Dictionary in _zombies.values():
		_aim(z)


## Host: where `z` (outside) should go now the holes are as they are: the nearest one, or with none,
## its own spot on the railing (a new one in front of it, if its hole was mended).
func _aim(z: Dictionary) -> void:
	if z.dead or z.inside or not z.released:
		return
	var at: Vector3 = (z.node as Node3D).global_position
	var hole := _nearest_hole(at.z)
	if hole == z.hole:
		return
	if hole >= 0:
		GameState.cue_wave([&"hole", z.id, hole, z.rail.z])
	else:
		GameState.cue_wave([&"hole", z.id, -1, _rail_spot(clampf(at.z, -RAIL_Z, RAIL_Z) / FAN)])


## The bay down nearest `along` (z), -1 with none.
func _nearest_hole(along: float) -> int:
	var best := -1
	for b in GameState.FENCE_BAYS:
		if GameState.bay_open(b) and (best < 0 or absf(GameState.bay_mid(b) - along) < absf(GameState.bay_mid(best) - along)):
			best = b
	return best


func _check_clear() -> void:
	if phase != Phase.FIGHT or not _queue.is_empty() or _alive() > 0:
		return
	GameState.cue_wave([&"phase", wave, Phase.CLEARED, 0])
	var seq := _seq
	await get_tree().create_timer(CLEAR_PAUSE).timeout
	if seq == _seq:
		GameState.cue_wave([&"phase", wave + 1, Phase.READY, 0])


# --- every peer -----------------------------------------------------------------------------------

func _on_cue(cue: Array) -> void:
	match cue[0]:
		&"reset":
			_reset()
		&"phase":
			_set_phase(cue[1], cue[2], cue[3])
		&"spawn":
			_add_zombie(cue[1], cue[2], cue[3], cue[4], cue[5], cue[6], cue[7], cue[8], cue[9],
					cue[10] if cue.size() > 10 else [], cue[11] if cue.size() > 11 else cue[2],
					cue[12] if cue.size() > 12 else &"", cue[13] if cue.size() > 13 else false,
					cue[14] if cue.size() > 14 else -1, cue[15] if cue.size() > 15 else false)
		&"hole":
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty() and not z.dead and not z.inside:
				z.hole = cue[2]
				z.rail.z = cue[3]
				if z.moving:  # still waiting to set off, it goes this way when it does
					_set_out(z)
		&"swing":
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty() and not z.dead:
				z.swing = z.body.attack()
				z.moving = false
		&"at":
			if Net.is_client:
				_got_at(cue[1], cue[2])
		&"rage":
			_rage(cue[1])
		&"maw":
			_maw(cue[1])
		&"limb":
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty():
				_cut(z, cue[2], true, cue[3] if cue.size() > 3 else 0)
		&"hp":
			var list: Array = cue[1]
			for i in range(0, list.size() - 1, 2):
				var z: Dictionary = _zombies.get(list[i], {})
				if not z.is_empty() and not z.dead:
					(z.bar as Node).set_left(list[i + 1])
		&"scream":
			_scream(cue[1], cue[2])
		&"blast":
			_blast_fx(cue[2])
			if (cue[2] as Vector3).x < RAIL_X + BLAST_RAIL:
				fence_hit.emit(&"bloater", BLAST_FENCE, cue[2])
		&"die":
			left = cue[2]
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty() and not z.dead:
				zombie_killed.emit(cue[3], z.kind, cue[4], cue[5], cue[6])
			_kill(cue[1], cue[7] if cue.size() > 7 else &"", cue[4], cue[8] if cue.size() > 8 else 0,
					cue[9] if cue.size() > 9 else Vector3.ZERO)
			_sign()
			if not Net.is_client:
				_check_clear()


func _set_phase(w: int, ph: Phase, p_left: int) -> void:
	var was := phase
	wave = w
	phase = ph
	left = p_left
	_seq += 1
	_sign()
	match ph:
		Phase.STARTING:
			_sequence(_seq)
		Phase.FIGHT:
			var skipped := was != Phase.STARTING  # joined mid-wave: no show, it is already so
			if skipped:
				_set_lever(true, true)
			_light(true)
			if not _gates_open:
				_open_gates(skipped)
			for z: Dictionary in _zombies.values():
				if not z.released:
					_release(z, true)
		Phase.CLEARED:
			if was == Phase.READY:  # joined in the pause: as it stands on the host
				_set_lever(true, true)
			_light(false)
			_close_gates(was == Phase.READY)
		Phase.FAILED:
			if was == Phase.READY:
				_set_lever(true, true)
				_open_gates(true)
			for z: Dictionary in _zombies.values():  # everyone is down: they turn back for the pens
				if not z.dead:
					_retreat(z)
			_light(false)
		Phase.READY:
			_set_lever(false, was == Phase.READY)
			_light(false)
			if _gates_open:
				_close_gates(was == Phase.READY)
			for id: int in _zombies.keys():  # the ones a lost wave left standing
				if not _zombies[id].dead:
					_zombies[id].node.queue_free()
					_zombies.erase(id)


## Back to a quiet bay with the lever up, keeping the wave number: a joiner before the host's
## world comes in, or everyone left behind when the host goes.
func _reset() -> void:
	_seq += 1
	for z: Dictionary in _zombies.values():
		if is_instance_valid(z.node):
			z.node.queue_free()
	_zombies.clear()
	_queue.clear()
	_hp.clear()
	phase = Phase.READY
	left = 0
	_set_lever(false, true)
	_light(false)
	_close_gates(true)
	_sign()


## The pull, the siren and the lights, the gates.
func _sequence(seq: int) -> void:
	_set_lever(true, false)
	_sound(&"lever", _lever)
	await get_tree().create_timer(LEVER_TIME).timeout
	if seq != _seq:
		return
	_light(true)
	for a in _alarms:
		if a.get_meta("kind", "") == "beacon":
			_sound(&"siren", a)
	await get_tree().create_timer(GATES_AT - LEVER_TIME).timeout
	if seq == _seq:
		_open_gates(false)


func _set_lever(down: bool, instant: bool) -> void:
	if not _lever_anim or _lever_clip == &"":
		return
	if instant:
		_lever_anim.play(_lever_clip)
		_lever_anim.seek(_lever_anim.current_animation_length if down else 0.0, true)
		_lever_anim.pause()
	elif down:
		_lever_anim.play(_lever_clip)
	else:
		_lever_anim.play_backwards(_lever_clip)


func _light(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	for a in _alarms:
		for n in a.find_children("*", "", true, false) + [a]:
			if n is Light3D:
				n.visible = on
			if n is GeometryInstance3D and n.has_meta("lit_material"):
				if not n.has_meta("dark_material"):
					n.set_meta("dark_material", n.material_override)
				n.material_override = n.get_meta("lit_material" if on else "dark_material")
	if not on:  # the mirrors stop where they are
		_spins_paused = _spins.duplicate()
		_spins.clear()
	elif not _spins_paused.is_empty():
		_spins = _spins_paused.duplicate()
		_spins_paused.clear()


func _open_gates(instant: bool) -> void:
	_gates_open = true
	_slide(true, instant)


func _close_gates(instant: bool) -> void:
	_gates_open = false
	_slide(false, instant)


func _slide(open: bool, instant: bool) -> void:
	if _gate_tween:
		_gate_tween.kill()
	if instant:
		for g in _gates:
			g.position = _gate_home[g] + (g.get_meta("open_offset") if open else Vector3.ZERO)
		return
	_gate_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	for g in _gates:
		_gate_tween.tween_property(g, "position", _gate_home[g] + (g.get_meta("open_offset") if open else Vector3.ZERO), GATE_TIME)
		_sound(&"gate", g)


func _add_zombie(id: int, kind: StringName, seed: int, gate: String, pos: Vector3, yaw: float, speed: float, rail_z: float, walking: bool, cuts: Array = [],
		type := &"", model := &"", elite := false, hole := -1, inside := false) -> void:
	if _zombies.has(id):
		return
	var node := Zombie.new()
	node.name = "Z%d" % id
	node.add_to_group("target")
	node.add_to_group("flesh")  # impacts.gd leaves the wound to zombie_body.gd
	node.set_meta("zombie", id)
	add_child(node)
	node.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	var body: Node3D = BODY.new()
	body.setup(kind, seed)
	if model != &"":
		body.model = model
	if elite:
		body.size *= ELITE_SIZE
	node.add_child(body)
	var tall: float = body.height
	var low: Array = LOW.get(kind, [])
	var k: float = 1.0 if kind == &"crawler" else body.size
	node.tall = 0.9 if kind == &"crawler" else tall
	var bones: Array = [] if BODY.CREATURES.has(body.model) else _bone_shapes(node, body)
	var trunk: CollisionShape3D = bones[0].node if bones else null
	if not trunk:
		trunk = CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = low[0] * k if low else 0.3 * tall / 1.8
		cap.height = low[1] * k if low else tall - 0.25
		trunk.shape = cap
		if low:
			trunk.rotation.x = PI / 2
			trunk.position = Vector3(0, low[2] * k, 0)
		else:
			trunk.position = Vector3(0, cap.height / 2.0, 0)
		trunk.set_meta("region", &"torso")
		node.add_child(trunk)
	var react: Node = REACT.new()
	react.setup(body.get("_skel"))
	var head := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = low[3] * k if low and not bones else 0.13 * tall / 1.8
	head.shape = ball
	head.add_to_group("weak_spot")
	head.set_meta("region", &"head")
	node.add_child(head)
	var mouth := Vector3.ZERO
	for g in _gates:
		if g.get_meta("gate") == gate:
			mouth = g.get_meta("mouth")
	var z := {"id": id, "node": node, "body": body, "kind": kind, "seed": seed, "gate": gate,
			"mouth": mouth, "rail": Vector3(RAIL_X, 0.0, rail_z), "head": body.attach("Head"),
			"head_shape": head, "trunk": trunk, "bones": bones, "react": react, "speed": speed, "dead": false, "path": [],
			"stagger": 0.0, "down": 0.0, "released": false, "moving": false, "hits": [], "count": 0,
			"bar": BAR.new(), "rush": 0.0, "hold": 0.0, "zig": float(absi(seed) % 1000) / 1000.0 * TAU,
			"cry": 0.0, "fit": -1, "type": type if type != &"" else kind, "elite": elite, "raged": false,
			"bite": bite_of(type if type != &"" else kind, wave, elite), "calm": 0.0, "leap": -1.0,
			"leap_from": Vector3.ZERO, "open": 0.0, "roar_due": false,
			"maw": lerpf(MAW_FIRST[0], MAW_FIRST[1], float(absi(seed) % 997) / 996.0),
			"hole": hole, "inside": inside, "heading": Vector3.ZERO, "walked": 0.0, "face": Vector3.ZERO,
			"claws": 0, "fix": Vector3.ZERO, "prey": 0, "think": 0.0, "goal": Vector3.ZERO,
			"swing": 0.0, "swinging": false, "seen": Vector3.INF, "seen_yaw": 0.0, "v": 0.0}
	_zombies[id] = z
	z.bar.setup(_hp_full.get(id, hp_of(z.type, wave, elite)), elite)
	node.add_child(z.bar)
	(z.bar as Node3D).position = Vector3.UP * (node.tall + 0.25)
	_next_id = maxi(_next_id, id + 1)  # should this machine ever be the one handing them out
	body.idle()
	_fit(z)
	for part: StringName in cuts:  # a joiner: what was torn off before it came, already off
		_cut(z, part, false)
	if phase == Phase.FIGHT:  # one still waiting to set off on the host waits a little here too
		_release(z, not walking)


## Sets it walking from where it stands: the gate's mouth (if still in the pen), the bay's mouth,
## its spot on the railing. Out of a gate that has just opened, they don't all set off at once.
func _release(z: Dictionary, stagger: bool) -> void:
	z.released = true
	if z.inside:  # a joiner: one already through a hole, the host's to move
		return
	var r := absi(hash(z.seed))
	if stagger:
		await get_tree().create_timer(float(r % 100) / 100.0 * RELEASE_SPREAD).timeout
		if z.dead or not is_instance_valid(z.node) or phase != Phase.FIGHT:
			return
	if (z.kind == &"brute" and r % 7 < 3) or (z.kind == &"dog" and r % 4 == 0):  # a roar, a howl
		await get_tree().create_timer(z.body.scream()).timeout
		if z.dead or not is_instance_valid(z.node) or phase != Phase.FIGHT:
			return
	z.moving = true
	z.cry = _rng.randf_range(SCREAM_FIRST[0], SCREAM_FIRST[1])  # only the host's counts
	_set_out(z)
	if not Net.is_client:
		_aim(z)  # a hole open already: there instead


## Every peer: the way from where `z` stands outside to its spot on the railing, or through its
## hole (z.hole) to our side. Out of a pen first to its gate's mouth, then the bay's mouth.
func _set_out(z: Dictionary) -> void:
	var at: Vector3 = (z.node as Node3D).global_position
	var to: float = z.rail.z
	var r := absi(hash(z.seed))
	if z.hole >= 0:
		to = GameState.bay_mid(z.hole) + (float(r % 1000) / 1000.0 * 2.0 - 1.0) * HOLE_JITTER
	var path := []
	if absf(at.z) > BAY_HALF - 0.5 or at.x > BAY_END:
		path.append(z.mouth)
	if at.x > DOOR_X:
		path.append(Vector3(DOOR_X, 0.0, clampf(to, -DOOR_Z, DOOR_Z)))
	if z.hole >= 0:
		if at.x > GAP[1]:
			path.append(Vector3(HOLE_OUT, 0.0, to))
		path.append(Vector3(HOLE_IN, 0.0, to + (float(r / 1000 % 1000) / 1000.0 - 0.5) * HOLE_JITTER))
	else:
		path.append(z.rail)
	z.path = path
	z.claws += 1  # whatever clawing it was at stops
	z.moving = true
	if z.down <= 0.0 and z.hold <= 0.0 and not z.body.busy():
		z.body.move(_pace(z))


func _walk(z: Dictionary, delta: float) -> void:
	z.open = maxf(0.0, z.open - delta)
	var falling: bool = z.down > 0.0  # going down on a torn leg: stumbles on a little, then crawls
	z.down = maxf(0.0, z.down - delta)
	if z.rush > 0.0:
		z.rush -= delta
		if z.rush <= 0.0 and not z.path.is_empty() and z.down <= 0.0 and z.hold <= 0.0:
			z.body.move(z.speed)  # back to its own pace
	if z.inside:
		if z.hold > 0.0:
			z.hold -= delta
		elif Net.is_client:
			_follow(z, delta)
		else:
			_hunt(z, delta)
		return
	var node: StaticBody3D = z.node
	if z.fix != Vector3.ZERO:  # a client's copy drifted from the host's: eased back in
		var f: Vector3 = z.fix * minf(1.0, 4.0 * delta)
		node.global_position += f
		z.fix -= f
	if z.path.is_empty():
		if z.face != Vector3.ZERO:  # at its spot: turns the rest of the way to the railing
			_turn_to(node, z.face, FACE_TURN * delta)
		return
	var to: Vector3 = z.path[0] - node.global_position
	to.y = 0.0
	if falling:
		node.global_position += to.limit_length(z.body.fall_speed * delta)
		if z.down <= 0.0:
			z.body.move(_pace(z))
		return
	if z.hold > 0.0:  # a screamer crying where it stands
		z.hold -= delta
		if z.hold <= 0.0:
			z.body.move(_pace(z))
		return
	if z.leap >= 0.0 and z.leap < LEAP_TIME:  # a leaper in the air, on its arc to the railing
		z.leap += delta
		var s := minf(1.0, z.leap / LEAP_TIME)
		node.global_position = (z.leap_from as Vector3).lerp(z.rail, s) + Vector3.UP * sin(PI * s) * LEAP_HIGH
		if s >= 1.0:
			z.path.clear()
			node.look_at(node.global_position + Vector3.LEFT, Vector3.UP)
			z.body.idle()
			if phase == Phase.FIGHT:
				_claw(z)
		return
	if z.body.busy():  # a one-shot plays in place: it stands for it, never slides through it
		return
	z.stagger = maxf(0.0, z.stagger - delta)
	var last: bool = z.path.size() == 1
	var through: bool = z.hole >= 0  # through a hole it walks on in, no braking
	if last and not through and z.leap < 0.0 and to.length() < LEAP_FROM and TYPES.get(z.type, {}).get("trait", &"") == &"leap":
		z.leap = 0.0
		z.leap_from = node.global_position
		node.look_at(node.global_position + to, Vector3.UP)
		z.body.pace(_pace(z) * 2.0)  # a burst of strides in the air
		return
	var v: float = _pace(z) * (STAGGER_SLOW if z.stagger > 0.0 else 1.0)
	v *= _surge(z)  # never quite in step with the next one
	if last and not through:  # brakes into its spot instead of stopping dead from a run
		v *= clampf(to.length() / BRAKE, BRAKE_MIN, 1.0)
	z.body.pace(v)  # the stride keeps up with the floor
	var step := v * delta
	if to.length() <= (step if last else maxf(step, WAYPOINT_SLACK)):  # a crowd at a gate can't all stand on its spot
		if last:
			node.global_position += to
		z.path.pop_front()
		if z.path.is_empty():
			if through:  # in: the host's to hunt with now
				z.hole = -1
				z.inside = true
				z.heading = Vector3.ZERO
				z.moving = false
				z.body.idle()
				return
			z.face = Vector3.LEFT if phase == Phase.FIGHT else Vector3.ZERO
			z.body.idle()  # what it stands in between swings
			if phase == Phase.FIGHT:
				_claw(z)
		return
	var way := _steer(z, to, step, delta, last and not through)
	node.global_position += way * step
	z.walked += step
	var face := way
	if last and not through and to.length() < 2.0:  # braking into its spot: already turning to the railing
		face = way.lerp(Vector3.LEFT, 1.0 - to.length() / 2.0).normalized()
	_turn_to(node, face, TAU * 2.0 * delta)


## Which way `z` goes this frame, `to` its next waypoint: a heading turning at TURN towards it, round
## the corner onto the next leg as it gets near, swaying off the line a little (nothing the last
## metres to its spot, where it goes straight in). Dogs zigzag instead.
func _steer(z: Dictionary, to: Vector3, step: float, delta: float, braking: bool) -> Vector3:
	var node: Node3D = z.node
	var d := to.length()
	var want := to / d
	if z.path.size() > 1 and d < LOOK:
		var next: Vector3 = z.path[1] - node.global_position
		next.y = 0.0
		if next.length() > 0.01:
			want = want.lerp(next.normalized(), 0.5 * (1.0 - d / LOOK)).normalized()
	if z.kind == &"dog" and d > ZIG_STOP and not z.body.crawling:  # side to side, never straight at you
		z.zig += TAU / ZIG_TIME * delta
		return (want + want.cross(Vector3.UP) * sin(z.zig) * ZIG).normalized()
	if braking and d < 1.5:
		z.heading = want
		return want
	var sway := WANDER * sin(z.walked / WANDER_LEN * TAU + z.zig) * clampf((d - 1.5) / 3.0, 0.0, 1.0) if braking else WANDER * sin(z.walked / WANDER_LEN * TAU + z.zig)
	want = want.rotated(Vector3.UP, sway)
	var heading: Vector3 = z.heading
	if heading == Vector3.ZERO:
		heading = -node.global_transform.basis.z
		heading.y = 0.0
		heading = heading.normalized() if heading.length() > 0.01 else want
	var turn := clampf(heading.signed_angle_to(want, Vector3.UP), -TURN * delta, TURN * delta)
	z.heading = heading.rotated(Vector3.UP, turn)
	# Close to the point (closer than it turns round), straight at it: it would circle it otherwise.
	return want if d < maxf(1.0, step) else z.heading


## Turns `node` about y towards facing `dir`, by at most `most` rad.
func _turn_to(node: Node3D, dir: Vector3, most: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var now := -node.global_transform.basis.z
	now.y = 0.0
	var turn := clampf(now.signed_angle_to(dir, Vector3.UP), -most, most)
	node.global_rotation.y += turn


## Its pace rising and falling as it walks (by SURGE), the same on every peer.
func _surge(z: Dictionary) -> float:
	return 1.0 + SURGE * sin(z.walked * 0.8 + z.zig * 1.7)


## How fast it goes now: its own speed, more while a screamer's cry drives it.
func _pace(z: Dictionary) -> float:
	return z.speed * (RUSH if z.rush > 0.0 else 1.0)


func _claw(z: Dictionary) -> void:
	z.claws += 1
	var mine: int = z.claws  # sent on elsewhere (a hole), this clawing stops
	var at_it := func() -> bool: return not z.dead and is_instance_valid(z.node) and phase == Phase.FIGHT 			and z.claws == mine and z.path.is_empty() and not z.inside
	while at_it.call():
		if z.down > 0.0:  # a leg torn off at the railing: down first, then it bites from there
			await get_tree().process_frame
			continue
		if z.roar_due:  # a spiker's roar came while it was clawing
			z.roar_due = false
			z.open = z.body.scream()
			await get_tree().create_timer(z.open).timeout
			continue
		var t: float = z.body.attack()
		await get_tree().create_timer(t * 0.5).timeout
		if not at_it.call():
			return
		fence_hit.emit(z.kind, z.bite, (z.node as Node3D).global_position)
		_fence.struck(z.node.global_position.z, z.kind)  # every peer: the sparks, the clang
		if not Net.is_client:
			_bite(z.kind, z.rail.z, z.bite)
		await get_tree().create_timer(t * (0.5 + ARM_SLOW * z.body.arms_hurt()) + 0.4).timeout


func _on_shot(peer: int, at: Vector3, _n: Vector3, dir: Vector3, target: Node, _gold: int, weak: bool, combo: int) -> void:
	if target == null or not target.has_meta("zombie"):
		return
	var z: Dictionary = _zombies.get(target.get_meta("zombie"), {})
	if z.is_empty() or z.dead:
		return
	var part: StringName = z.body.wound(at, dir, weak)
	z.react.hit(at, dir, GameState.GUNS[GameState.player(peer).gun].id, weak)  # where it went in gives
	z.stagger = 0.7 if BODY.is_leg(part) else 0.35  # held back a moment by the hit, a leg longer
	z.body.hit()
	if Net.is_client or combo == 0 or not _hp.has(z.id):  # combo 0: not a paying hit (wrong side of the line)
		return
	var gun: String = GameState.GUNS[GameState.player(peer).gun].id
	var t: StringName = TYPES.get(z.type, {}).get("trait", &"")
	var dmg: float = DAMAGE.get(gun, DAMAGE_ELSE)
	if weak:
		match t:
			&"mask": dmg *= MASK_HEAD
			&"maw": dmg *= MAW_HEAD if z.open > 0.0 else 1.0
			_: dmg *= HEAD
		if t == &"leap" and z.leap >= 0.0 and z.leap < LEAP_TIME:  # in the air: one round
			dmg = maxf(dmg, _hp[z.id])
	elif t == &"armor":
		dmg *= ARMOR
	elif t == &"maw":
		dmg *= MAW_BODY
	z.count += 1
	if part != &"":
		_limb_hit(z, part, dmg, _roll(z, dir))
		dmg *= LIMB_BODY
	var now := Time.get_ticks_msec() / 1000.0
	z.hits = (z.hits as Array).filter(func(h: Vector2) -> bool: return now - h.x < SHRED_TIME) + [Vector2(now, dmg)]
	_hurt(z, dmg, peer, weak, gun, dir)


## How one zombie's death or torn limb comes apart this time: from its seed, how many rounds it has
## taken and the way the last one went (the host's, sent with the cue).
func _roll(z: Dictionary, dir: Vector3) -> int:
	return hash([z.seed, z.count, dir.snapped(Vector3.ONE * 0.01)]) & 0x7fffffff


## The odds a head shot kill blows the head off: by `gun`, the `share` of its full life the killing
## round took, how far the shooter stood (m) and how many heads they blew off lately.
static func pop_chance(gun: String, share: float, dist: float, recent: int) -> float:
	var p: float = POP_BASE.get(gun, POP_BASE_ELSE)
	if share >= POP_BIG_SHARE:
		p += POP_BIG
	p += POP_NEAR * clampf(2.0 - dist / POP_NEAR_M, 0.0, 1.0)
	return minf(p * pow(POP_AGAIN, recent), POP_MAX)


## Host: takes `dmg` off its life; at 0 it goes down, `peer`'s kill with `gun`, and how it comes
## apart is picked here and sent with the die cue. `dir`: the way the round went (zero for a blast).
func _hurt(z: Dictionary, dmg: float, peer: int, weak: bool, gun: String, dir := Vector3.ZERO) -> void:
	if not _hp.has(z.id):
		return
	_hp[z.id] -= dmg
	z.calm = 0.0
	if _hp[z.id] > 0:
		_hp_news[z.id] = float(_hp[z.id]) / _hp_full[z.id]
		(z.bar as Node).set_left(_hp_news[z.id])  # here at once; the others get it with the next batch
		if not z.raged and _hp_news[z.id] < RAGE_AT and TYPES.get(z.type, {}).get("trait", &"") == &"rage":
			GameState.cue_wave([&"rage", z.id])
		return
	_hp.erase(z.id)
	_hp_news.erase(z.id)
	var gib := &""
	var at := (z.node as Node3D).global_position
	if weak and z.kind != &"blob" and TYPES.get(z.type, {}).get("trait", &"") != &"mask":
		var now := Time.get_ticks_msec() / 1000.0
		var lately: Array = (_pops.get(peer, []) as Array).filter(func(t: float) -> bool: return now - t < POP_MEMORY)
		_pops[peer] = lately
		var p = GameState.player(peer)
		var dist: float = p.pos.distance_to(at) if p and p.has_pose else 10.0
		if _rng.randf() < pop_chance(gun, dmg / _hp_full[z.id], dist, lately.size()):
			gib = &"head"
			lately.append(now)
	# A head shot kill that kept its head goes down whole (the head snapped back), a burst or not.
	if gib == &"" and (z.kind in [&"brute", &"blob", &"bloater"] or (not weak and (z.hits as Array).reduce(
			func(sum: float, h: Vector2) -> float: return sum + h.y, 0.0) >= SHRED * _hp_full[z.id])):
		gib = &"body"
	GameState.cue_wave([&"die", z.id, _queue.size() + _alive() - 1, peer, weak, at, gun, gib, _roll(z, dir), dir])
	if z.kind == &"bloater":
		_burst(z, at, peer, gun)


## Host: a bloater bursts. Everyone near it is hurt, the railing too if it was at it.
func _burst(z: Dictionary, at: Vector3, peer: int, gun: String) -> void:
	GameState.cue_wave([&"blast", z.id, at])
	if at.x < RAIL_X + BLAST_RAIL:
		_bite(z.kind, at.z, BLAST_FENCE)
	var dmg := BLAST * (1.0 + HP_GROW * (wave - 1))
	for other: Dictionary in _zombies.values():
		if not other.dead and other.id != z.id and (other.node as Node3D).global_position.distance_to(at) < BLAST_REACH:
			_hurt.call_deferred(other, dmg, peer, false, gun)  # one bloater may burst the next


## Host: a paying hit of `dmg` on `part`; once that arm or leg has taken its share it goes, at the
## joint above where this one went in.
func _limb_hit(z: Dictionary, part: StringName, dmg: float, roll: int) -> void:
	if not z.body.can_lose(part):
		return
	var limb := ("leg" if BODY.is_leg(part) else "arm") + String(part).right(2)
	var taken: Dictionary = _limb_hits.get_or_add(z.id, {})
	taken[limb] = taken.get(limb, 0.0) + dmg
	if taken[limb] >= LIMB_HP[limb.left(3)] * _hp_full[z.id]:
		taken[limb] = 0.0  # what is left of it (an arm that lost the forearm) can go too
		GameState.cue_wave([&"limb", z.id, part, roll])


## Once the hall is up: the blood, the pieces and the railing's sparks drawn once, a speck in front
## of the camera, so their shaders compile now and not at the first hit (zombie_body.gd prewarm()).
func _prewarm() -> void:
	await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	if cam:
		BODY.prewarm(self, cam.global_transform * Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0, 0, -1)))
		_fence.prewarm(cam.global_transform * Vector3(0, 0, -1))


## Every peer, the wave lost: off back the way it came, to the bay's mouth and its gate.
func _retreat(z: Dictionary) -> void:
	z.released = true
	z.claws += 1
	z.hole = -1
	z.leap = LEAP_TIME  # a leaper in the air lands where it was going and turns from there
	var at: Vector3 = (z.node as Node3D).global_position
	var path := []
	if z.inside or at.x < GAP[1]:  # inside: back out through the nearest hole
		z.inside = false
		var hole := _nearest_hole(at.z)
		var through := GameState.bay_mid(hole) if hole >= 0 else at.z
		path.append(Vector3(HOLE_IN, 0.0, through))
		path.append(Vector3(HOLE_OUT, 0.0, through))
		at = path[-1]
	if at.x < DOOR_X:
		path.append(Vector3(DOOR_X, 0.0, clampf(at.z, -DOOR_Z, DOOR_Z)))
	path.append(z.mouth)
	z.path = path
	z.moving = true
	if z.down <= 0.0:
		z.body.move(z.speed)


## Every peer: `part` comes off (zombie_body.gd cut()). A leg lost drops a standing one to its belly:
## it waits out the fall, then crawls on slower and lies low for the rounds.
func _cut(z: Dictionary, part: StringName, fly: bool, roll := 0) -> void:
	var was_low: bool = z.body.crawling
	z.down = maxf(z.down, z.body.cut(part, fly, roll))
	for s: Dictionary in z.bones:  # what came off takes no more rounds
		if s.limb != &"" and (s.limb == part or BODY.LOWER.get(s.limb, &"") == part) and part in z.body.cuts:
			(s.node as CollisionShape3D).disabled = true
	if was_low or not z.body.crawling:
		return
	z.speed *= LEGLESS.get(z.kind, LEGLESS_ELSE)
	(z.node as Zombie).tall = 0.9
	if not z.bones.is_empty():  # its shapes lie down with its bones
		if z.down <= 0.0 and not z.path.is_empty():
			z.body.move(z.speed)
		return
	var trunk: CollisionShape3D = z.trunk
	var low: Array = LOW[&"crawler"]
	var cap := trunk.shape as CapsuleShape3D
	cap.radius = low[0]
	cap.height = low[1]
	trunk.rotation.x = PI / 2
	trunk.position = Vector3(0, low[2], 0)
	if z.down <= 0.0 and not z.path.is_empty():
		z.body.move(z.speed)


## Host: the regen ones left alone a while heal.
func _regen(delta: float) -> void:
	for z: Dictionary in _zombies.values():
		if z.dead or not _hp.has(z.id) or _hp[z.id] >= _hp_full[z.id] or TYPES.get(z.type, {}).get("trait", &"") != &"regen":
			continue
		z.calm += delta
		if z.calm >= REGEN_WAIT:
			_hp[z.id] = minf(_hp_full[z.id], _hp[z.id] + REGEN * _hp_full[z.id] * delta)
			_hp_news[z.id] = float(_hp[z.id]) / _hp_full[z.id]


## Every peer: a rager under RAGE_AT of its life roars where it stands, then goes faster and claws harder.
func _rage(id: int) -> void:
	var z: Dictionary = _zombies.get(id, {})
	if z.is_empty() or z.dead or z.raged:
		return
	z.raged = true
	z.speed *= RAGE
	z.bite += 1
	if not z.path.is_empty() and z.down <= 0.0 and z.hold <= 0.0 and not z.body.crawling:
		z.hold = z.body.scream()
	elif not z.path.is_empty() and z.down <= 0.0 and z.hold <= 0.0:
		z.body.move(_pace(z))


## Host: each spiker let out counts down to its next roar; the cue makes it roar on every peer.
func _maws(delta: float) -> void:
	for z: Dictionary in _zombies.values():
		if z.dead or not z.released or TYPES.get(z.type, {}).get("trait", &"") != &"maw":
			continue
		z.maw -= delta
		if z.maw <= 0.0:
			z.maw = MAW_EVERY
			GameState.cue_wave([&"maw", z.id])


## Every peer: a spiker roars, its head weak while it lasts: on its way it stops for it, at the
## railing it roars before its next swing.
func _maw(id: int) -> void:
	var z: Dictionary = _zombies.get(id, {})
	if z.is_empty() or z.dead:
		return
	if z.path.is_empty() and not z.inside:
		z.roar_due = true
	elif z.down <= 0.0 and z.hold <= 0.0:
		z.hold = z.body.scream()
		z.open = z.hold


## Host: each screamer on its way through the bay counts down to its next cry; the ones walking
## near it then are named in the cue, so the same ones run on every peer.
func _screams(delta: float) -> void:
	for z: Dictionary in _zombies.values():
		if z.dead or z.kind != &"screamer" or z.path.is_empty() or z.down > 0.0 or z.hold > 0.0:
			continue
		var at: Vector3 = (z.node as Node3D).global_position
		if at.x > SCREAM_X:
			continue
		z.cry -= delta
		if z.cry > 0.0:
			continue
		z.cry = SCREAM_EVERY
		var near := []
		for o: Dictionary in _zombies.values():
			if not o.dead and o.id != z.id and not o.kind in NO_RUSH and o.released 					and (o.node as Node3D).global_position.distance_to(at) < SCREAM_REACH:
				near.append(o.id)
		GameState.cue_wave([&"scream", z.id, near])


## Every peer: the screamer stops and cries, and `ids` run.
func _scream(id: int, ids: Array) -> void:
	var z: Dictionary = _zombies.get(id, {})
	if z.is_empty() or z.dead:
		return
	z.hold = z.body.scream()
	for o_id: int in ids:
		var o: Dictionary = _zombies.get(o_id, {})
		if o.is_empty() or o.dead:
			continue
		var was: bool = o.rush > 0.0
		o.rush = RUSH_TIME
		if not was and not o.path.is_empty() and o.down <= 0.0 and o.hold <= 0.0:
			o.body.move(_pace(o))


## Every peer: a bloater's burst, a ring of blood thrown over the floor around it (the body itself
## bursts with its die cue).
func _blast_fx(at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(at)  # the same splashes on every peer
	for i in 6:
		var way := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 6.0 + rng.randf_range(-0.4, 0.4))
		BLOOD.ground(self, at + way * rng.randf_range(0.8, BLAST_REACH * 0.8), at.y, [&"spray", &"drop"], rng,
				rng.randf_range(0.8, 1.3), way)
	BLOOD.mist(self, at + Vector3.UP * 1.0, Vector3.UP, rng, 2.2, 0.8)
	VOICE.gore(&"burst", at + Vector3.UP, 4.0, 0.7)


## A Mixamo body's hit shapes (BONE_SHAPES) under `node`, sized to its bones as they stand now (a
## bone's length never changes). Each: {node, from, to, past (m), limb}; the torso's first.
func _bone_shapes(node: Node3D, body: Node3D) -> Array:
	var sk: Skeleton3D = body.get("_skel")
	var out := []
	for e: Array in BONE_SHAPES:
		var a := sk.find_bone("mixamorig_" + e[0])
		var b := sk.find_bone("mixamorig_" + e[1])
		if a < 0 or b < 0:
			continue
		var r: float = e[2] * body.size
		var past: float = e[3] * body.size
		var length := sk.to_global(sk.get_bone_global_pose(a).origin).distance_to(sk.to_global(sk.get_bone_global_pose(b).origin))
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = r
		cap.height = length + past + 2.0 * r
		cs.shape = cap
		cs.set_meta("region", e[4])
		if e[5] != &"":
			cs.set_meta("limb", e[5])
		node.add_child(cs)
		out.append({"node": cs, "from": a, "to": b, "past": past, "limb": e[5]})
	return out


## Fits the bone shapes of the living ones near the line from `from` along `dir` (a round about to be
## traced) that were not fitted this frame. A check tracing its own rays calls it too.
func fit_along(from: Vector3, dir: Vector3) -> void:
	dir = dir.normalized()
	for z: Dictionary in _zombies.values():
		if z.dead or z.fit == _beat:
			continue
		var to := (z.node as Node3D).global_position + Vector3.UP - from
		if to.dot(dir) > -FIT_NEAR and to.cross(dir).length() < FIT_NEAR:
			z.body.catch_up()
			_fit(z)


## Lays the head's ball and each of `z`'s bone shapes along its bones as they are posed now. The
## shapes are the body's children: laid in its own space, one transform for the skeleton to it.
## Jolt builds the body's compound shape again on every shape moved in a space (~4 µs each, 12 a
## body): the body leaves its space while they move and is built once as it comes back (~0.6 µs a
## shape), and the rounds traced right after still meet them where they now are.
func _fit(z: Dictionary) -> void:
	z.fit = _beat
	var sk: Skeleton3D = z.body.get("_skel")
	var node: Zombie = z.node
	if z.bones.is_empty():  # the head's ball alone
		(z.head_shape as Node3D).global_position = sk.global_transform * sk.get_bone_global_pose((z.head as BoneAttachment3D).bone_idx).origin
		return
	var rid := node.get_rid()
	var space := PhysicsServer3D.body_get_space(rid)
	PhysicsServer3D.body_set_space(rid, RID())
	# Off the bone's pose, not its attachment: that follows the skeleton's update, a step behind a
	# pose just brought up to date.
	var head: BoneAttachment3D = z.head
	(z.head_shape as Node3D).global_position = sk.global_transform * sk.get_bone_global_pose(head.bone_idx).origin
	var to_body := node.global_transform.affine_inverse() * sk.global_transform
	for s: Dictionary in z.bones:
		var cs: CollisionShape3D = s.node
		if cs.disabled:
			continue
		var a := to_body * sk.get_bone_global_pose(s.from).origin
		var b := to_body * sk.get_bone_global_pose(s.to).origin
		var y := b - a
		if y.length() < 0.001:
			continue
		y = y.normalized()
		b += y * s.past
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		cs.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	PhysicsServer3D.body_set_space(rid, space)
	# It comes back where it last left a space, not where it has walked to since.
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, node.global_transform)


## The region a round went into on a zombie: "head", "torso", "arm_l", "arm_r", "leg_l" or
## "leg_r" (meta on the shape, see BONE_SHAPES). `shape` is hit.shape from the trace.
static func region_at(zombie: CollisionObject3D, shape: int) -> StringName:
	var cs := zombie.shape_owner_get_owner(zombie.shape_find_owner(shape)) as Node
	return cs.get_meta("region", &"torso") if cs else &"torso"


## Keeps the crowd from walking into each other: every pair of the living standing too close is
## pushed apart along the floor, each peer its own. One at the railing stays on its spot (the host
## rolled it, the same everywhere): pushed along it, its copies would drift apart on each peer and a
## client's rounds go where the host has nobody.
func _spread(delta: float) -> void:
	var live: Array[Dictionary] = []
	var reach := PackedFloat32Array()
	var at := PackedVector3Array()  # where each stands, as the pushes move it
	var held: Array[bool] = []  # clawing at the railing: stays put
	for z: Dictionary in _zombies.values():
		if not z.dead and z.released:
			live.append(z)
			reach.append(SPREAD * (1.5 if z.body.crawling or LOW.has(z.kind) else 1.0) * z.body.size)
			at.append((z.node as Node3D).global_position)
			# Clawing at the railing stays put; so does a client's copy inside (the host's moves it).
			held.append(z.path.is_empty() and not z.inside or z.inside and Net.is_client)
	var k := minf(1.0, SPREAD_PUSH * delta)
	var moved: Array[bool] = []
	moved.resize(live.size())
	for i in live.size():
		for j in range(i + 1, live.size()):
			if held[i] and held[j]:  # both on their spots: neither would move
				continue
			var off := at[i] - at[j]
			off.y = 0.0
			var r := (reach[i] + reach[j]) * 0.5
			var d := off.length()
			if d >= r:
				continue
			var push := (off / d if d > 0.001 else Vector3(0, 0, 1)) * (r - d) * 0.5 * k
			if not held[i]:
				at[i] += push
				moved[i] = true
			if not held[j]:
				at[j] -= push
				moved[j] = true
	for i in live.size():
		if moved[i]:
			(live[i].node as Node3D).global_position = _keep_side(at[i])


## `at` kept out of the railing's band unless it is in a hole there (and then off its posts).
func _keep_side(at: Vector3) -> Vector3:
	if at.x <= GAP[0] or at.x >= GAP[1]:
		return at
	var b := GameState.bay_at(at.z)
	if GameState.bay_open(b):
		var half := GameState.FENCE_SPAN / GameState.FENCE_BAYS - 0.3
		at.z = clampf(at.z, GameState.bay_mid(b) - half, GameState.bay_mid(b) + half)
		return at
	at.x = GAP[0] if at.x < GameState.FIRING_LINE_X else GAP[1]
	return at


func _kill(id: int, gib: StringName, weak := false, roll := 0, dir := Vector3.ZERO) -> void:
	var z: Dictionary = _zombies.get(id, {})
	if z.is_empty() or z.dead:
		return
	z.dead = true
	z.path = []
	var node: Node3D = z.node
	node.remove_from_group("target")
	(z.trunk as CollisionShape3D).disabled = true
	(z.head_shape as CollisionShape3D).disabled = true
	(z.bar as Node).hide_now()
	for s: Dictionary in z.bones:
		(s.node as CollisionShape3D).disabled = true
	z.body.die(gib, weak, roll, dir)
	await get_tree().create_timer(DEAD_STAY).timeout
	if is_instance_valid(node):
		node.queue_free()
	if is_same(_zombies.get(id), z):
		_zombies.erase(id)


## While the gates are shut, now and then one of them screams somewhere behind them (each machine
## its own, only a sound).
func _pen_cries() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
		if not _gates_open and not _spawns.is_empty():
			VOICE.distant(_spawns.pick_random().global_position + Vector3.UP * 1.5)


## The mechanical sign over the lever: the wave's number on flip plates, the state under it.
func _sign() -> void:
	if _status:
		var text: String = STATUS.get(phase, "")
		if phase == Phase.FIGHT:  # how many are left and how the railing stands: holes, else bays hurt
			text = "KALAN %d" % left
			if GameState.fence_holes() > 0:
				text += "   DELİK %d" % GameState.fence_holes()
			elif GameState.fence_hurt() > 0:
				text += "   HASAR %d" % GameState.fence_hurt()
		_status.text = text
	if _number and wave != _shown_wave:
		var first := _shown_wave < 0
		_shown_wave = wave
		if first:
			_number.text = "%02d" % wave
			return
		var tw := create_tween()  # the plate flips over to the new number
		tw.tween_property(_number, "scale:y", 0.0, 0.12)
		tw.tween_callback(func() -> void: _number.text = "%02d" % wave)
		tw.tween_property(_number, "scale:y", 1.0, 0.12)


# --- inside -----------------------------------------------------------------------------------------

## Our side of the railing as a navigation mesh, baked once from the hall's world colliders (the
## workshop, the heap, the walls), so the ones through a hole walk round them.
func _bake_nav() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1  # the world layer: not the railing's wall, not loose rounds
	var map := get_world_3d().navigation_map
	mesh.cell_size = NavigationServer3D.map_get_cell_size(map)
	mesh.cell_height = NavigationServer3D.map_get_cell_height(map)
	mesh.agent_radius = 0.5  # (whole cells, or the baker rounds them and says so)
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 30.0  # the heap's sides are no floor
	mesh.filter_baking_aabb = AABB(Vector3(-30.0, -1.0, -29.0), Vector3(30.0 + GameState.FIRING_LINE_X + 0.5, 5.0, 58.0))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, get_parent())
	# The floor's collider is a plane the parser can't take: laid in as a mesh of its own.
	var box := mesh.filter_baking_aabb
	var a := Vector3(box.position.x, 0.0, box.position.z)
	var b := Vector3(box.end.x, 0.0, box.end.z)
	source.add_faces(PackedVector3Array([a, Vector3(b.x, 0.0, a.z), b, a, b, Vector3(a.x, 0.0, b.z)]), Transform3D())
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, func() -> void:
		if is_instance_valid(_nav):
			_nav.navigation_mesh = mesh)


## The way from `from` to `to` on our side, waypoints on the floor; straight there without a mesh.
func _route(from: Vector3, to: Vector3) -> Array:
	var way := []
	if _nav.navigation_mesh != null:
		for p in NavigationServer3D.map_get_path(get_world_3d().navigation_map, from, to, true):
			way.append(Vector3(p.x, 0.0, p.z))
	if way.size() >= 2:
		way.pop_front()  # where it stands
		return way
	return [Vector3(to.x, 0.0, to.z)]


## The players in the hall who are up: peer -> where they stand.
func _standing() -> Dictionary:
	var out := {}
	for peer: int in GameState._slots_now():
		var p = GameState.player(peer)
		if p.has_pose and not GameState.is_down(peer):
			out[peer] = Vector3(p.pos.x, 0.0, p.pos.z)
	return out


## Host: one inside goes for the nearest player standing, round what is in the way, and claws them
## once within REACH. Nobody standing, it waits where it is.
func _hunt(z: Dictionary, delta: float) -> void:
	var node: StaticBody3D = z.node
	var at := node.global_position
	var up := _standing()
	z.think -= delta
	if z.think <= 0.0 or not up.has(z.prey):
		z.think = HUNT_EVERY
		z.prey = 0
		var near := INF
		for peer: int in up:
			if at.distance_to(up[peer]) < near:
				near = at.distance_to(up[peer])
				z.prey = peer
		if z.prey != 0:
			z.goal = up[z.prey]
			z.path = _route(at, z.goal)
	if z.down > 0.0 or z.body.busy() or z.swinging:
		return
	if z.prey == 0:
		_moving(z, 0.0)
		return
	var goal: Vector3 = up[z.prey]
	var off := goal - at
	off.y = 0.0
	if off.length() <= REACH:
		_moving(z, 0.0)
		_turn_to(node, off, FACE_TURN * delta)
		_swing(z)
		return
	if z.path.is_empty() or goal.distance_to(z.goal) > 1.5:
		z.goal = goal
		z.path = _route(at, goal)
	var to: Vector3 = z.path[0] - at
	to.y = 0.0
	if to.length() < WAYPOINT_SLACK and z.path.size() > 1:
		z.path.pop_front()
		to = z.path[0] - at
		to.y = 0.0
	z.stagger = maxf(0.0, z.stagger - delta)
	var v := _pace(z) * (STAGGER_SLOW if z.stagger > 0.0 else 1.0)
	var step := minf(v * delta, maxf(0.0, off.length() - REACH * 0.8))
	if to.length() < 0.01 or step <= 0.0:
		return
	var way := _steer(z, to, step, delta, false)
	var face := way
	# One nearer the player in the way: it edges round it, its own side, or waits behind (a crowd
	# round someone, not one heap on them).
	for o: Dictionary in _zombies.values():
		if o.dead or not o.inside or o.id == z.id:
			continue
		var rel: Vector3 = (o.node as Node3D).global_position - at
		rel.y = 0.0
		var near: float = SPREAD * 1.2 * maxf(z.body.size, o.body.size)
		if rel.length() < near and rel.dot(way) > 0.4 * rel.length() and goal.distance_to((o.node as Node3D).global_position) < off.length():
			var side := 1.0 if z.id % 2 == 0 else -1.0
			way = way.rotated(Vector3.UP, side * PI * 0.45)
			step *= 0.5 if off.length() > REACH * 2.0 else 0.0
			break
	node.global_position = _keep_side(at + way * step)
	z.walked += step
	_turn_to(node, face, TAU * 2.0 * delta)
	_moving(z, step / delta)


## Host: a claw at its prey (every peer sees the swing); it lands if they are still within reach and up.
func _swing(z: Dictionary) -> void:
	z.swinging = true
	GameState.cue_wave([&"swing", z.id])
	var t: float = z.swing
	await get_tree().create_timer(t * 0.5).timeout
	if not z.dead and phase == Phase.FIGHT and z.inside:
		var up := _standing()
		var at := (z.node as Node3D).global_position
		if up.has(z.prey) and at.distance_to(up[z.prey]) <= REACH + REACH_SLACK:
			GameState.hurt_player(z.prey, PLAYER_HIT * z.bite, at)
	await get_tree().create_timer(t * (0.5 + ARM_SLOW * z.body.arms_hurt()) + 0.3).timeout
	z.swinging = false


## Its gait as it goes `v` m/s: walking (its stride kept to the floor) or standing.
func _moving(z: Dictionary, v: float) -> void:
	if z.down > 0.0:  # going down on a torn leg: once down, it sets off in its new gait
		z.moving = false
		return
	if z.body.busy():
		return
	if v > 0.3:
		if not z.moving:
			z.moving = true
			z.body.move(v)
		else:
			z.body.pace(v)
	elif v < 0.1 and z.moving:
		z.moving = false
		z.body.idle()


## Host: where it has the ones walking outside and the ones inside, for the clients.
func _send_at() -> void:
	var out := []
	var inside := []
	for z: Dictionary in _zombies.values():
		if z.dead or not z.released:
			continue
		var node: Node3D = z.node
		if z.inside:
			inside.append_array([z.id, node.global_position, node.global_rotation.y])
		elif not z.path.is_empty():
			out.append_array([z.id, node.global_position])
	if not out.is_empty() or not inside.is_empty():
		GameState.cue_wave([&"at", out, inside])


## Client: the host's positions. One outside drifted more than AT_SLACK is eased back in; the ones
## inside follow the host's.
func _got_at(out: Array, inside: Array) -> void:
	for i in range(0, out.size() - 1, 2):
		var z: Dictionary = _zombies.get(out[i], {})
		if z.is_empty() or z.dead or z.inside:
			continue
		var off: Vector3 = out[i + 1] - (z.node as Node3D).global_position
		off.y = 0.0
		if off.length() > AT_SNAP:
			(z.node as Node3D).global_position = out[i + 1]
			z.fix = Vector3.ZERO
		elif off.length() > AT_SLACK:
			z.fix = off.normalized() * (off.length() - AT_SLACK)
	for i in range(0, inside.size() - 2, 3):
		var z: Dictionary = _zombies.get(inside[i], {})
		if z.is_empty() or z.dead:
			continue
		if not z.inside:
			z.inside = true
			z.hole = -1
			z.path = []
			z.claws += 1
		if z.seen == Vector3.INF or (inside[i + 1] as Vector3).distance_to((z.node as Node3D).global_position) > AT_SNAP:
			(z.node as Node3D).global_position = inside[i + 1]
		z.seen = inside[i + 1]
		z.seen_yaw = inside[i + 2]


## Client: one inside goes where the host has it, as fast as it needs to get there by the next word.
func _follow(z: Dictionary, delta: float) -> void:
	if z.seen == Vector3.INF:
		return
	var node: Node3D = z.node
	var off: Vector3 = z.seen - node.global_position
	off.y = 0.0
	var d := off.length()
	var v := minf(d / AT_SEND, _pace(z) * 1.5) if d > 0.05 else 0.0
	if v > 0.0:
		node.global_position += off / d * minf(d, v * delta)
	z.v = lerpf(z.v, v, minf(1.0, 8.0 * delta))
	node.global_rotation.y = lerp_angle(node.global_rotation.y, z.seen_yaw, minf(1.0, 10.0 * delta))
	if not z.body.busy():
		_moving(z, z.v)


func _sound(slot: StringName, at: Node3D) -> void:
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(SOUNDS + String(slot) + ext):
			stream = load(SOUNDS + String(slot) + ext)
	if stream == null or at == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	at.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
