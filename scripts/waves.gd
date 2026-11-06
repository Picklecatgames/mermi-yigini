extends Node3D
## Zombie waves. The open ground (2026-11-02) has no pens, gates, lever or railing: a wave is called the
## same way, but it steps out of the wood's edge (_step_out) and hunts the nearest player from the start
## (_hunt); nothing walks the old way below. The old way, kept until the clean-up, is what follows:
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
## outside, and the ones inside) · [&"cross", id, step, from, to] (going over or under the railing, cross_of:
## &"wind" crouching to spring over from `from` to `to`, again after a hit · &"duck" down to crawl
## under · &"fall" shot out of the air at `from`, down at `to`).
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
const SOUND_UNIT := 6.0  # m: lever, siren and gates at full level up to here (_sound)
const SOUND_RANGE := 60.0  # m, silent past it
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
const WANDER_AFIELD := 0.35  # of it on the open ground: between the trunks it sways into them, and it means to get you
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
## kills), maw (the head is weak only while it roars, every MAW_EVERY s; the rest takes MAW_BODY),
## over and under (cross_of, below).
const TYPES := {
	&"walker": {"kind": &"walker", "from": 1, "hp": 1.0, "speed": 1.0, "bite": 1, "trait": &"",
			"looks": [[&"prisoner", 1], [&"melty", 20]]},
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
	&"vaulter": {"kind": &"runner", "from": 12, "hp": 1.6, "speed": 0.95, "bite": 1, "trait": &"over", "looks": [[&"yaku", 12]]},
	&"creeper": {"kind": &"walker", "from": 16, "hp": 0.9, "speed": 1.0, "bite": 1, "trait": &"under", "looks": [[&"parasite", 16]]},
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
## Over and under (2026-11-01, the user: "altından geçen tipler de olacak, ekle"; types, waves and
## numbers are mine): at its spot on a bay still standing, the vaulter crouches (zombie_body.gd
## vault(), the moment to stop it: a hit there sends it back into the crouch, BALK_AFTER s into it
## at the soonest) and springs over in an arc whose top clears the railing by VAULT_CLEAR, down at
## VAULT_TO on our side; shot in the air it falls (FALL_TIME), on our side if past the railing,
## else back on its own, lies FALL_LIE s, gets up and goes again. The creeper lies down (duck()) and
## crawls under the bottom rail at CREEP_SPEED to CREEP_TO, low the whole way, then gets up. Then
## both are inside like the ones through a hole. Only these types: a cripple on its belly claws on,
## and a vaulter that loses a leg can't spring. The railing is measured (GameState.fence_top(),
## fence_gap()): taller than VAULT_MAX, nobody springs it; less room under it than CREEP_MIN, nobody
## gets under. The host starts each crossing (`cross` cue) and every peer plays it from there.
const VAULT_TO := 12.9  # x it comes down at
const VAULT_CLEAR := 0.1  # m
const VAULT_TUCK := 0.75  # m its feet tuck up under its middle at the top of the jump clip
const VAULT_MAX := 1.6
const BALK_AFTER := 0.15
const FALL_TIME := 0.45
const FALL_LIE := 1.2
const CREEP_FROM := 15.7  # x its spot is at: lying down it reaches forward, its head still short of the railing
const CREEP_TO := 12.6
const CREEP_SPEED := 0.65  # m/s it slides along wriggling (zombie_body.gd creep())
const CREEP_MIN := 0.4
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
const NO_ELITE: Array[StringName] = [&"brute", &"blob", &"dog", &"swarm", &"spiker", &"leaper", &"creeper"]  # leaper: its crawl clip strides no quicker; creeper: a bigger one would not get under
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
const MIX_ALL := 0.85  # the most all the shares together take: the rest (15% at least) walkers
const MIX := {&"runner": [0.2, 0.01, 0.18], &"crawler": [0.12, 0.0, 0.1], &"armored": [0.15, 0.005, 0.13],
		&"bloater": [0.06, 0.01, 0.08], &"masked": [0.12, 0.0, 0.1], &"regen": [0.1, 0.0, 0.1],
		&"rager": [0.1, 0.0, 0.1], &"blob": [0.05, 0.005, 0.06], &"leaper": [0.08, 0.005, 0.12],
		&"vaulter": [0.06, 0.005, 0.1], &"creeper": [0.06, 0.005, 0.1]}
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
## The zombie test menu (scripts/spawn_menu.gd): they come up this far in front of the one who
## asked, SUMMON_GAP apart side by side, in rows of SUMMON_ROW.
const SUMMON_AHEAD := 6.0
const SUMMON_GAP := 1.2
const SUMMON_ROW := 5
## When no hidden spot is found (_let_out), the wood's edge (_step_out): this many of its spots a night.
const RAID_FROM := 3
const GROUND_EVERY := 4  # frames between a test zombie's looks at the ground under it

## The hunt on the open ground (2026-11-05, the user: "orada burada dolanıyorlar sadece; güzel bir
## yapay zekâ, daha saldırgan agresif bir zekâ ver; daha korkutucu"). Every number here is my guess,
## not the user's (docs/ayrintilar.md "Zombi zekâsı ve gece akışı"). Until one has seen or heard a
## player it stalks: comes on at a walk (STALK of its pace, in its walk clips' stride) towards the
## nearest. It notices one within HEAR m whatever is between, within NOTICE m that it can see
## (a ray past the trunks), any it is shot by, and any firing within SHOT_HEAR m; then it shrieks
## (body.notice) and runs, and never lets go. It runs at the one it picked a little ahead of where
## they are going (LEAD_MAX s), a little quicker far off (CATCH_UP past CATCH_FAR m); several on one
## player come at them from the sides (FLANK_M m off the line, nothing inside FLANK_NEAR m). The
## last LUNGE_FROM m it bursts forward (LUNGE times its pace for LUNGE_TIME s) and swings, still
## coming on through the wind-up (SWING_STEP m/s): backing off is not enough, running away is.
## It picks among the players by distance, sticks to its pick (STICK m), is drawn off one many
## already go for (CROWDED m each) and goes for one who shot it (GRUDGE m, for GRUDGE_TIME s).
const STALK := 0.45
const STALK_MIN := 0.8  # m/s: a stalk slower than this never gets there
const HEAR := 12.0
const NOTICE := 32.0
const SHOT_HEAR := 45.0
const LEAD_MAX := 0.7
const CATCH_UP := 1.15
const CATCH_FAR := 14.0
const FLANK_M := 5.0
const FLANK_NEAR := 6.0
const LUNGE_FROM := 3.4
const LUNGE := 1.45
const LUNGE_TIME := 0.6
const LUNGE_COOL := 2.5
const SWING_STEP := 1.4
const DIRECT := 2.5  # m: this near, straight at its prey, no path
const NAV_POKE := 2.0  # s (_nav_watch)
const ROUTE_SHORT := 3.0  # m: a way ending further than this from where it was asked to goes nowhere near (_route)
const ACCEL := 7.0  # m/s² up to its pace and down from it: it springs into a run, never at once
const STICK := 4.0
const CROWDED := 3.0
const GRUDGE := 8.0
const GRUDGE_TIME := 5.0
const GAIT_WALK := 0.55  # of its pace: slower than this it walks (its walk clips), quicker it runs
const GAIT_RUN := 0.7
## Stuck (2026-11-05, the user: "yarım saattir bir kayaya takılmış"): one that has gone less than
## STUCK_MOVED m in STUCK_EVERY s while it means to walk finds its way again (a fresh path), then
## steps aside DETOUR m for DETOUR_TIME s, and at the STUCK_SNAP-th time is put back on the mesh.
const STUCK_EVERY := 1.2
const STUCK_MOVED := 0.4
const DETOUR := 2.5
const DETOUR_TIME := 1.2
const STUCK_SNAP := 4
## The walkable mesh on the open ground: the clearing and the wood round it out to here (x0, z0, x1, z1).
const NAV_AREA := Rect2(-64.0, -68.0, 146.0, 136.0)

## The director and the tricks (2026-11-06, the user: "nadiren arkamızda gizlensinler, ormanlıkta
## bazen saklansınlar, oyuncuya atlasınlar"; numbers mine, docs/ayrintilar.md "Avcı zekâsı"). See _direct.
const DIRECTOR_EVERY := 2.0
const CALM := 0.3
const EVENT_GAP := 120.0  # s between two tricks on one player
const TRICK_GAP := 45.0  # s between any two tricks, whoever they are on
const QUIET_AFTER_HIT := 30.0
const EVENT_CHANCE := 0.25
## A night's budget (2026-11-06, the user: "sürekli de tetiklenmesin, tadında kalsın"): of each
## trick at most this many a night, all of them together at most NIGHT_TRICKS_ALL (more players,
## a few more: NIGHT_TRICKS_PER_PLAYER each past the first). The rest of the dead simply come.
const NIGHT_TRICKS := {&"ambush": 2, &"shy": 1, &"sneak": 1}
const NIGHT_TRICKS_ALL := 3
const NIGHT_TRICKS_PER_PLAYER := 1
## The moment before a trick: it stops short, the head jerks round (REACT_PAUSE s), then it goes.
const REACT_PAUSE := 0.55
## Making for cover: COVER_PACE of its pace, unsteady (COVER_JERK), slowing over the last COVER_BRAKE m.
const COVER_PACE := 0.75
const COVER_JERK := 0.3
const COVER_BRAKE := 1.8
## The leap (zombie_body.gd leap): from within LEAP_MAX m (and past LEAP_MIN), onto LEAP_SHORT m short of them.
const LEAP_MAX := 5.5
const LEAP_MIN := 1.8
const LEAP_SHORT := 1.0
## Never into a player's body (2026-11-06, the user: they shove the player): kept PLAYER_ROOM m off.
const PLAYER_ROOM := 0.75
## Caught in a head lamp's beam (within LAMP_CONE degrees, LAMP_REACH m), at night, now and then
## (LAMP_CHANCE a look, LAMP_EVERY s apart): it stops short (STARTLE_HOLD s) and jerks; one zombie
## at most every STARTLE_AGAIN s, one player's beam every LAMP_GAP s.
const LAMP_EVERY := 0.5
const LAMP_REACH := 14.0
const LAMP_CONE := 12.0
const LAMP_CHANCE := 0.25
const STARTLE_HOLD := 0.45
const STARTLE_AGAIN := 25.0
const LAMP_GAP := 12.0
const TENSE_HIT := 0.5
const TENSE_NEAR := 0.12
const TENSE_NEAR_M := 10.0
const TENSE_FALL := 0.03
const BUSY_FOR := 1.5  # s after the last dig at the heap a player still counts as busy at it
const NO_TRICKS: Array[StringName] = [&"dog", &"blob", &"crawler", &"brute"]
const TRICK_FROM := 9.0  # m from the player, one given a trick
const TRICK_TO := 45.0
## Ambush: it waits behind a trunk AMBUSH_RING m from them (going there at AMBUSH_PACE of its
## stalk), and leaps out once they are within POUNCE_NEAR m, or with their back to it (more than
## POUNCE_BACK degrees off it) within POUNCE_BACK_M m after AMBUSH_MIN_WAIT s, or after AMBUSH_GIVE_UP s.
const AMBUSH_RING := Vector2(7.0, 14.0)
const AMBUSH_PACE := 1.0
const POUNCE_NEAR := 5.0
const POUNCE_BACK := 100.0
const POUNCE_BACK_M := 12.0
const AMBUSH_MIN_WAIT := 2.0
const AMBUSH_GIVE_UP := 40.0
const POUNCE := 1.8  # times its pace, for POUNCE_TIME s: the leap out
const POUNCE_TIME := 0.9
## Shy: within SHY_SEEN degrees of where they look it goes behind the nearest trunk; past SHY_AWAY it
## comes on at SHY_COME times its pace; within SHY_OUT m, or after SHY_GIVE_UP s, it runs at them.
const SHY_SEEN := 30.0
const SHY_AWAY := 70.0
const SHY_COME := 1.0
const SHY_OUT := 8.0
const SHY_GIVE_UP := 45.0
## Sneak: round to SNEAK_BEHIND m behind them at its stalk, then in; out within SNEAK_OUT m, or
## when they turn to it (SNEAK_SEEN degrees) within SNEAK_SEEN_M m, or after SNEAK_GIVE_UP s.
const SNEAK_BEHIND := 7.0
const SNEAK_OUT := 3.0
const SNEAK_SEEN := 35.0
const SNEAK_SEEN_M := 15.0
const SNEAK_GIVE_UP := 45.0
const TRUNK_CELL := 8.0
const TRUNK_MIN := 0.18  # m: thinner trunks hide nobody
const HIDE_BEHIND := 1.5  # m: a trunk this near what it hides
const COVER_GAP := 0.35  # m behind the trunk's side

## The night (2026-11-05, the user: "gece olduktan sonra bir anda tüm zombiler saldırıya geçmesin;
## bir iki tane rastgele ormanın içinden spawn olup bize doğru gelsinler"): from NIGHT_START to
## NIGHT_END o'clock, while it is dark (GameState.night_of >= NIGHT_DARK), the night's wave (_plan of
## `wave`, one wave a night, so every night is harder) comes out of the wood one or two at a time.
## The gaps are random and shrink as the night goes on (the n-th of N groups comes at ((n+u)/N)^(1/
## NIGHT_RISE) of what is left of the night, u random), the first soon after NIGHT_QUIET of it; a pair
## comes more often every night (PAIR, PAIR_GROW, PAIR_MAX); dogs and the swarm keep to their packs.
## Each comes up HIDE_DEEP m into the wood past the clearing's edge, at least HIDE_NEAR m from every
## player and out of the sight of any looking its way within HIDE_SEEN m (HIDE_CONE degrees off where
## they look, and nothing between). Numbers mine.
const NIGHT_START := 20.0
const NIGHT_END := 6.0
const NIGHT_DARK := 0.6
const NIGHT_QUIET := 0.04
const NIGHT_FIRST := 0.06  # of the night after the quiet, at most, the first group comes
const NIGHT_RISE := 1.6
const NIGHT_SPARE := 0.08  # of the night at its end with nobody new: the last come before the light
const PAIR := 0.25
const PAIR_GROW := 0.08
const PAIR_MAX := 0.6
const HIDE_DEEP := [9.0, 22.0]
const HIDE_NEAR := 24.0
const HIDE_SEEN := 60.0
const HIDE_CONE := 70.0
const CLEARING_CENTRE := Vector2(8.0, 0.0)  # tools/build_world.gd
const CLEARING_RADII := Vector2(40.0, 34.0)
const JUNK_YARD := Rect2(-136.0, -80.0, 130.0, 160.0)  # tools/build_world.gd YARD: nobody comes out of the junk
const STATUS := {Phase.READY: "HAZIR", Phase.STARTING: "AÇILIYOR", Phase.CLEARED: "TEMİZ", Phase.FAILED: "HERKES DÜŞTÜ"}

var wave := 1
var phase := Phase.READY
var left := 0  # zombies of this wave not yet down (waiting ones too)
var _raiding := false  # host: B's wave is still coming out (_debug_raid)
var fence: int:  # what is left of the railing's bays, all of them (GameState's)
	get: return GameState.fence

var _zombies := {}  # id -> record (see _add_zombie)
var _spawns: Array[Node3D] = []
var _edges: Array[Node3D] = []  # host, no pens: the wood's edge spots this wave comes from (_step_out)
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
var _nav: NavigationRegion3D  # our side of the railing, for the ones inside; the open ground's clearing and wood
## Host: the night's trickle (_night_step). Checks may stop it (night_spawns = false).
var night_spawns := true
var _night := -1  # GameState.nights the plan below is for
var _night_wave := 0
var _night_groups: Array = []  # [[types...], due (night 0..1)], in order
var event_log: Array = []  # host: [clock, peer, what, zombie id] of every trick given and played out (tools/zombie_mind_check.gd)
var _clock := 0.0  # host: s, game time
var _tension := {}  # host: peer -> 0..1
var _last_event := {}  # host: peer -> _clock of the last trick
var _last_trick := {}  # host: peer -> which
var _last_hit := {}  # host: peer -> _clock of the last blow on them
var _direct_wait := 0.0
var _last_any := -INF  # host: _clock of the last trick on anyone
var _last_any_trick := &""
var _presence: Node  # forest_presence.gd, found on first need
var _presence_looked := false
var _night_tricks := {}  # host: trick -> how many tonight (the night: _tricks_night)
var _tricks_night := -1
var _lamp_wait := 0.0
var _last_startle := {}  # host: peer -> _clock
var _trunks := {}
var _trunks_built := false
var nav_live := false  # the navigation map has taken our mesh in (_nav_watch)
var _nav_wait := 0.0
var night_log: Array = []  # host: [night, its 0..1, hour, how many, where] of every group let out (tools/zombie_night_check.gd)


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
	GameState.debug_spawn_asked.connect(_debug_spawn)
	GameState.debug_raid_asked.connect(_debug_raid)
	GameState.shot_landed.connect(_on_shot)
	GameState.fired.connect(func(peer: int, from: Vector3, dir: Vector3) -> void:
		fit_along(from, dir)
		_heard(peer, from))
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


## The local player at `at` may pull the lever now (player.gd shows the hint, E pulls it).
func can_pull(at: Vector3) -> bool:
	if not _lever:  # the open ground has none (build_world.gd): nothing to walk up to
		return false
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
			if z.cross in [&"wind", &"duck", &"creep"]:  # crossing, from where it is now (in the air or down, the next `at` puts it)
				var at := node.global_position
				at.y = 0.0
				cues.append([&"cross", id, &"wind" if z.cross == &"wind" else &"duck", at, z.cross_to])
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
	_keep_off_players()
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
	_nav_watch(delta)
	_night_step()
	_direct(delta)
	_lamps(delta)
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
	_edges.clear()
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


## Host: the test menu's zombies (debug builds): `count` of TYPES `type` in rows in front of one
## standing at `at` looking along `yaw`, facing them. They are inside from the start, so they go for
## the nearest player standing at once (_hunt) and claw, wave or no wave; dressed as in the first
## wave the type comes in, or this one if later. The next wave's lever coming back clears them.
func _debug_spawn(type: String, at: Vector3, yaw: float, count: int) -> void:
	var t: Dictionary = TYPES.get(StringName(type), {})
	if Net.is_client or t.is_empty():
		return
	var w := maxi(wave, t.from)
	var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var side := ahead.cross(Vector3.UP)
	var space := get_world_3d().direct_space_state
	for i in count:
		var row := i / SUMMON_ROW
		var in_row := mini(SUMMON_ROW, count - row * SUMMON_ROW)
		var pos := at + ahead * (SUMMON_AHEAD + row * SUMMON_GAP * 1.5) + side * ((i % SUMMON_ROW) - (in_row - 1) / 2.0) * SUMMON_GAP
		pos += Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.2, 0.2))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 2.2, pos + Vector3.DOWN * 6.0, 1))  # from under the house's ceiling, not onto its roof
		pos.y = hit.position.y if hit else at.y
		_summon(StringName(type), pos, yaw + PI, w)


## Host: one zombie of TYPES `type` on the open ground at `pos` facing `yaw`, dressed and paced for
## wave `w`, going for the nearest player from the start (_hunt).
func _summon(type: StringName, pos: Vector3, yaw: float, w: int, elite := false) -> void:
	var t: Dictionary = TYPES[type]
	var id := _next_id
	_next_id += 1
	_hp[id] = hp_of(type, w, elite)
	_hp_full[id] = _hp[id]
	var speed: float = STATS[t.kind][0] * t.speed * minf(1.0 + SPEED_GROW * (w - 1), SPEED_MAX) * _rng.randf_range(SPEED_ROLL[0], SPEED_ROLL[1])
	if elite:
		speed *= ELITE_SPEED
	var worn := looks(type, w)
	var model: StringName = worn[_rng.randi() % worn.size()] if worn else &""
	GameState.cue_wave([&"spawn", id, t.kind, _rng.randi(), "", pos, yaw, speed, 0.0, true, [],
			type, model, elite, -1, true])
	var z: Dictionary = _zombies[id]
	z.released = true  # the host sends where it has them (_send_at), wave or no wave
	z.afield = true


## Host: B (debug builds; GameState.request_debug_raid). Once it is dark, the night's trickle
## (_night_step) lets its next group out of the wood at once instead of when it is due, so there is
## something to see straight away; the rest come as they would.
func _debug_raid() -> void:
	if Net.is_client or _raiding:
		return
	if get_tree().get_first_node_in_group("forest_edge") == null:
		return
	_raiding = true
	var seq := _seq
	while GameState.night_of(GameState.hour) < NIGHT_DARK or night_progress(GameState.hour) < 0.0:  # the light goes first
		await get_tree().process_frame
		if seq != _seq:
			_raiding = false
			return
	var p := night_progress(GameState.hour)
	if _night != GameState.nights:
		_plan_night(GameState.nights, p)
	if not _night_groups.is_empty():
		_let_out(_night_groups.pop_front()[0], _night_wave, p)
	_raiding = false


## Host: one of `type` for wave `w` steps out of the wood's edge at one of RAID_FROM spots picked for
## this wave (false if the world has no such edge).
func _step_out(type: StringName, w: int) -> bool:
	if _edges.is_empty():
		for m: Node3D in get_tree().get_nodes_in_group("forest_edge"):
			_edges.append(m)
		if _edges.is_empty():
			return false
		_shuffle(_edges)
		_edges.resize(mini(RAID_FROM, _edges.size()))
	var edge := _edges[_next_spawn % _edges.size()]
	_next_spawn += 1
	var pos := edge.global_position + Vector3(_rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-3.0, 3.0))
	var to := Vector3(GameState.LEVER_POS.x, 0.0, GameState.LEVER_POS.z) - pos
	pos.y += 3.0  # the marker is on the ground; from over it, so a rise near it is found too
	_summon(type, _on_ground(pos), atan2(-to.x, -to.z), w, _rng.randf() < elite_chance(type, w))
	return true


## `at` dropped (or raised, a step at most) onto the world layer below it; as it was if there is none.
## `body`: the zombie itself, which is on that layer too.
func _on_ground(at: Vector3, body: CollisionObject3D = null) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 8.0, 1)
	if body:
		ray.exclude = [body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.position if hit else at


## What wave `w` sends, in order: the types (TYPES).
func _plan(w: int) -> Array[StringName]:
	var n := BASE_COUNT + COUNT_GROW * (w - 1)
	var out: Array[StringName] = []
	var all := 0.0
	for t: StringName in MIX:
		all += share(t, w)
	var k := minf(1.0, MIX_ALL / all) if all > 0.0 else 1.0  # more types than room: each gives a little
	for t: StringName in MIX:
		for i in mini(roundi(share(t, w) * k * n), n - out.size()):
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
	if _spawns.is_empty():  # the open ground: no pens to come out of (build_world.gd "forest_edge")
		if not _step_out(type, wave):
			push_error("waves: no pens and no wood's edge, %s has nowhere to come from" % type)
		return
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
	if z.dead or z.inside or not z.released or z.cross != &"":
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
			if not z.is_empty() and not z.dead and not z.inside and z.cross == &"":
				z.hole = cue[2]
				z.rail.z = cue[3]
				if z.moving:  # still waiting to set off, it goes this way when it does
					_set_out(z)
		&"cross":
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty() and not z.dead and not z.inside:
				_cross(z, cue[2], cue[3], cue[4])
		&"swing":
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty() and not z.dead:
				z.swing = z.body.attack()
				z.moving = false
				z.gait = ""
		&"notice":
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty() and not z.dead:
				z.aware = true
				z.body.notice()
		&"mode":
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty() and not z.dead:
				z.mode = cue[2]
				z.body.set_mode(cue[2])
		&"leap":
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty() and not z.dead:
				z.aware = true
				z.mode = &""
				z.leap_times = z.body.leap()
				z.leap_on = true
				z.leap_t = 0.0
				z.leap_a = cue[2]
				z.leap_b = cue[3]
				z.moving = false
		&"startle":
			var z: Dictionary = _zombies.get(cue[1], {})
			if not z.is_empty() and not z.dead:
				z.body.startle()
				z.hold = STARTLE_HOLD
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
			if not _spawns.is_empty() and (cue[2] as Vector3).x < RAIL_X + BLAST_RAIL:
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
	if _gates.is_empty():  # the open ground: nothing to slide, and a tween with nothing in it complains
		return
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
			"mouth": mouth, "rail": Vector3(_spot_x(type if type != &"" else kind), 0.0, rail_z), "head": body.attach("Head"),
			"head_shape": head, "trunk": trunk, "bones": bones, "react": react, "speed": speed, "dead": false, "path": [],
			"stagger": 0.0, "down": 0.0, "released": false, "moving": false, "hits": [], "count": 0,
			"bar": BAR.new(), "rush": 0.0, "hold": 0.0, "zig": float(absi(seed) % 1000) / 1000.0 * TAU,
			"cry": 0.0, "fit": -1, "type": type if type != &"" else kind, "elite": elite, "raged": false,
			"bite": bite_of(type if type != &"" else kind, wave, elite), "calm": 0.0, "leap": -1.0,
			"leap_from": Vector3.ZERO, "open": 0.0, "roar_due": false,
			"maw": lerpf(MAW_FIRST[0], MAW_FIRST[1], float(absi(seed) % 997) / 996.0),
			"hole": hole, "inside": inside, "heading": Vector3.ZERO, "walked": 0.0, "face": Vector3.ZERO,
			"claws": 0, "fix": Vector3.ZERO, "prey": 0, "think": 0.0, "goal": Vector3.ZERO,
			"swing": 0.0, "swinging": false, "seen": Vector3.INF, "seen_yaw": 0.0, "v": 0.0,
			"cross": &"", "cross_t": 0.0, "cross_from": Vector3.ZERO, "cross_to": Vector3.ZERO, "cross_wind": 0.0, "cross_air": 0.0,
			"aware": false, "grudge": 0, "grudge_t": 0.0, "prey_last": Vector3.INF, "prey_v": Vector3.ZERO,
			"flank": (1.0 if seed % 2 == 0 else -1.0) * lerpf(0.5, 1.0, float(absi(seed) % 101) / 100.0),
			"lunge": 0.0, "lunge_cool": 0.0, "pace_now": 0.0, "gait": "",
			"stuck_t": 0.0, "stuck_from": pos, "stuck_n": 0, "detour": Vector3.ZERO, "detour_t": 0.0,
			"role": &"", "role_t": 0.0, "role_wait": 0.0, "role_route": 0.0, "hide": Vector3.INF, "recheck": 0.0, "pounce": 0.0,
			"pause_t": 0.0, "mode": &"", "watched": false, "leap_ready": false, "leap_on": false, "leap_t": 0.0,
			"leap_times": [0.0, 0.0, 0.0], "leap_a": Vector3.ZERO, "leap_b": Vector3.ZERO, "startle_cd": 0.0}
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
	if z.cross != &"":  # a joiner: the host had it crossing already (its cue came while this waited)
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
		if z.get("leap_on", false):
			_leaping(z, delta)
		elif z.hold > 0.0:
			z.hold -= delta
		elif Net.is_client:
			_follow(z, delta)
		else:
			_hunt(z, delta)
		return
	if z.cross != &"":
		_crossing(z, delta)
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
				_arrive(z)
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
	var wander := WANDER * (WANDER_AFIELD if z.has("afield") else 1.0)
	var sway := wander * sin(z.walked / WANDER_LEN * TAU + z.zig) * clampf((d - 1.5) / 3.0, 0.0, 1.0) if braking else wander * sin(z.walked / WANDER_LEN * TAU + z.zig)
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


## At its spot on the railing: it claws at it, or (cross_of) the host has it go over or under; a
## client's copy stands there until the host's cue.
func _arrive(z: Dictionary) -> void:
	var how := cross_of(z)
	if how == &"":
		_claw(z)
	elif not Net.is_client:
		var at: Vector3 = (z.node as Node3D).global_position
		at.y = 0.0
		var over := how == &"over"
		GameState.cue_wave([&"cross", z.id, &"wind" if over else &"duck", at, Vector3(VAULT_TO if over else CREEP_TO, 0.0, at.z)])


## x of the spot along the railing a `type` makes for: a creeper lies down further out (CREEP_FROM).
func _spot_x(type: StringName) -> float:
	var under: bool = TYPES.get(type, {}).get("trait", &"") == &"under" and GameState.fence_gap() >= CREEP_MIN
	return CREEP_FROM if under else RAIL_X


## How `z` gets past the railing where it stands: &"over", &"under" or &"" (it claws at it). Its
## type's trait alone, never one on its belly going over, and only a railing it can (VAULT_MAX, CREEP_MIN).
func cross_of(z: Dictionary) -> StringName:
	match TYPES.get(z.type, {}).get("trait", &""):
		&"over":
			if not z.body.crawling and GameState.fence_top() <= VAULT_MAX:
				return &"over"
		&"under":
			if GameState.fence_gap() >= CREEP_MIN:
				return &"under"
	return &""


## Every peer, the host's `cross` cue: `z` starts that step of its crossing, `from` -> `to`.
func _cross(z: Dictionary, step: StringName, from: Vector3, to: Vector3) -> void:
	z.path = []
	z.claws += 1  # whatever clawing it was at stops
	z.moving = false
	z.cross = step
	z.cross_t = 0.0
	z.cross_from = from
	z.cross_to = to
	match step:
		&"wind":
			var t: Array = z.body.vault()
			z.cross_wind = t[0]
			z.cross_air = t[1]
		&"duck":
			z.cross_wind = z.body.duck()
		&"fall":
			z.body.knocked()
			(z.node as Node3D).global_position = from


## Every peer: a step of the crossing, from its cue: the crouch (or lying down) on its spot, the arc
## over, the crawl under, the fall, lying there, getting up. Through, it is inside.
func _crossing(z: Dictionary, delta: float) -> void:
	var node: Node3D = z.node
	z.cross_t += delta
	var t: float = z.cross_t
	var from: Vector3 = z.cross_from
	var to: Vector3 = z.cross_to
	match z.cross:
		&"wind", &"duck":  # on its spot (a client's copy eased onto the host's), facing over
			node.global_position = node.global_position.move_toward(from, 3.0 * delta)
			_turn_to(node, Vector3.LEFT, FACE_TURN * delta)
			if t >= z.cross_wind:
				z.cross_t = 0.0
				z.cross = &"air" if z.cross == &"wind" else &"creep"
				if z.cross == &"creep":
					z.body.creep()
		&"air":
			var s := minf(1.0, t / z.cross_air)
			var top := GameState.fence_top() + VAULT_CLEAR - VAULT_TUCK
			node.global_position = from.lerp(to, s) + Vector3.UP * sin(PI * s) * top
			if s >= 1.0:
				node.global_position = to
				_in(z)
		&"creep":
			var off: Vector3 = to - node.global_position
			off.y = 0.0
			var step := CREEP_SPEED * delta
			_turn_to(node, Vector3.LEFT, FACE_TURN * delta)
			if off.length() > step:
				node.global_position += off.normalized() * step
				return
			node.global_position = to
			_get_up(z)
		&"fall":
			var s := minf(1.0, t / FALL_TIME)
			var p := from.lerp(to, s)
			p.y = from.y * (1.0 - s * s)
			node.global_position = p
			if s >= 1.0:
				z.cross = &"lie"
				z.cross_t = 0.0
		&"lie":
			if t >= FALL_LIE:
				_get_up(z)
		&"rise":
			if t < z.cross_wind:
				return
			if node.global_position.x < GameState.FIRING_LINE_X:
				_in(z)
				return
			z.cross = &""  # fell back on its own side: at the railing again, and the host sends it over again
			z.face = Vector3.LEFT
			if phase == Phase.FIGHT:
				_arrive(z)


func _get_up(z: Dictionary) -> void:
	z.cross = &"rise"
	z.cross_t = 0.0
	z.cross_wind = z.body.get_up()  # 0 with a leg gone: it crawls on from where it lies


## Over or under: on our side now, the host's to hunt with like the ones through a hole.
func _in(z: Dictionary) -> void:
	z.cross = &""
	z.inside = true
	z.hole = -1
	z.heading = Vector3.ZERO
	z.moving = false
	if not z.body.busy():
		z.body.idle()


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
	match z.cross:
		&"wind":  # stopped in the crouch: back into it
			if z.cross_t >= BALK_AFTER:
				GameState.cue_wave([&"cross", z.id, &"wind", z.cross_from, z.cross_to])
		&"air":  # shot out of the air: down on whichever side it is over
			var now_at: Vector3 = (z.node as Node3D).global_position
			var past := now_at.x < GameState.FIRING_LINE_X
			GameState.cue_wave([&"cross", z.id, &"fall", now_at, Vector3(VAULT_TO if past else RAIL_X, 0.0, now_at.z)])
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
	if z.has("afield") and _hp[z.id] > 0:  # shot: it goes for the one who did it, in a rage
		z.grudge = peer
		z.grudge_t = GRUDGE_TIME
		if z.role != &"":
			z.prey = peer if _standing().has(peer) else z.prey
			_pounce(z)
		else:
			_alert(z)
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
	if not _spawns.is_empty() and at.x < RAIL_X + BLAST_RAIL:  # (no pens, no railing)
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
	if z.cross in [&"air", &"fall"]:  # the same for a vaulter
		(z.node as Node3D).global_position = z.cross_to
	if z.cross in [&"fall", &"lie"]:
		z.body.get_up()
	z.cross = &""
	var at: Vector3 = (z.node as Node3D).global_position
	var path := []
	if z.inside or at.x < GAP[1]:  # inside: back out through the nearest hole
		z.inside = false
		var hole := _nearest_hole(at.z)
		if hole < 0:  # in over or under the railing and no hole to go back by: it stays (the lost wave clears it)
			z.path = []
			z.moving = false
			if not z.body.busy():
				z.body.idle()
			return
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
	if z.cross == &"wind" and z.body.crawling:  # a leg gone in the crouch: no spring, it claws from the floor
		z.cross = &""
		z.face = Vector3.LEFT
		if phase == Phase.FIGHT:
			_claw(z)
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
			(live[i].node as Node3D).global_position = at[i] if live[i].has("afield") else _keep_side(at[i])


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
	z.cross = &""
	var node: Node3D = z.node
	if node.global_position.y > 0.01:  # killed in the air (a leaper's or a vaulter's spring): down to the floor
		node.create_tween().tween_property(node, "global_position:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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

## The ground round the base as a navigation mesh, baked once from the world's colliders (the shed,
## the heap, the trunks), so the ones hunting walk round them. The ground is a real collider now: no
## flat floor laid in over it, that was a second surface where the dunes meet it, and the "more than 2
## edges" warning.
func _bake_nav() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1  # the world layer: not the railing's wall, not loose rounds
	var map := get_world_3d().navigation_map
	mesh.cell_size = NavigationServer3D.map_get_cell_size(map)
	mesh.cell_height = NavigationServer3D.map_get_cell_height(map)
	mesh.agent_radius = 0.25  # whole cells, or the baker rounds them and says so; 0.5 closed the house's 1.2-1.3 m doors
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 30.0  # the heap's sides are no floor
	if get_tree().get_first_node_in_group("forest_edge") != null:  # the open ground: the clearing and the wood round it
		mesh.filter_baking_aabb = AABB(Vector3(NAV_AREA.position.x, -8.0, NAV_AREA.position.y), Vector3(NAV_AREA.size.x, 20.0, NAV_AREA.size.y))
	else:
		mesh.filter_baking_aabb = AABB(Vector3(-30.0, -1.0, -29.0), Vector3(30.0 + GameState.FIRING_LINE_X + 0.5, 5.0, 58.0))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, get_parent())
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, func() -> void:
		if is_instance_valid(_nav):
			_nav.navigation_mesh = mesh)


## Host: the mesh baked, whether the navigation map has it yet. Now and then it never does (its
## regions settle on threads, 2026-11-06: in one run of three the map stayed empty for good, every
## way straight and every nearest point at the origin): given again every NAV_POKE s till it has.
func _nav_watch(delta: float) -> void:
	if nav_live or _nav.navigation_mesh == null:
		return
	_nav_wait -= delta
	if _nav_wait > 0.0:
		return
	_nav_wait = NAV_POKE
	var v := _nav.navigation_mesh.get_vertices()
	if v.is_empty():
		return
	if NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, v[0]) != Vector3.ZERO:
		nav_live = true
		return
	var mesh := _nav.navigation_mesh
	_nav.navigation_mesh = null
	_nav.navigation_mesh = mesh


## The way from `from` to `to`, waypoints on the floor; straight there without a mesh, and straight
## there when the mesh does not join them (2026-11-05: one in a patch the trunks and logs close in,
## or off the mesh, went to the patch's edge nearest the player, stepped off it, was sent back to
## it by the next way, and so on for good: the stuck one by the rock). Walked straight, it is through
## the gap and on the mesh again in a step or two. A way ending off the mesh at `to` (a player on a
## rock, past the bake's area) goes on to `to` from its end.
func _route(from: Vector3, to: Vector3) -> Array:
	var way := []
	if _nav.navigation_mesh != null:
		for p in NavigationServer3D.map_get_path(get_world_3d().navigation_map, from, to, true):
			way.append(Vector3(p.x, 0.0, p.z))
	if way.size() >= 2:
		way.pop_front()  # where it stands
		var end: Vector3 = way[-1]
		var short := Vector2(end.x - to.x, end.z - to.z).length()
		if short > ROUTE_SHORT:
			return [Vector3(to.x, 0.0, to.z)]  # not joined: straight on
		if short > WAYPOINT_SLACK:
			way.append(Vector3(to.x, 0.0, to.z))
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


## Host: which of the players up `z` goes for: the nearest, its own pick and one who shot it drawing
## it, one many already go for less (STICK, CROWDED, GRUDGE).
func _pick_prey(z: Dictionary, at: Vector3, up: Dictionary) -> int:
	var on := {}
	for o: Dictionary in _zombies.values():
		if not o.dead and o.id != z.id and o.prey != 0:
			on[o.prey] = on.get(o.prey, 0) + 1
	var best := 0
	var low := INF
	for peer: int in up:
		var score: float = Vector2(up[peer].x - at.x, up[peer].z - at.z).length() + CROWDED * on.get(peer, 0)
		if peer == z.prey:
			score -= STICK
		if peer == z.grudge and z.grudge_t > 0.0:
			score -= GRUDGE
		if score < low:
			low = score
			best = peer
	return best


## Host: whether `z` notices its prey `peer` (at `prey`, on the floor) now; once it has, it never lets go.
func _sense(z: Dictionary, at: Vector3, peer: int, prey: Vector3) -> void:
	if z.aware:
		return
	var d := Vector2(prey.x - at.x, prey.z - at.z).length()
	if d > NOTICE:
		return
	if d > HEAR:
		var eye := (z.node as Zombie).above_head() - Vector3.UP * 0.2
		var p = GameState.player(peer)
		var ray := PhysicsRayQueryParameters3D.create(eye, p.pos + Vector3.UP * 1.4, 1)
		ray.exclude = [(z.node as CollisionObject3D).get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(ray):
			return  # a trunk, a wall between: it comes on as it was
	_alert(z)


## Host: `z` has seen or heard a player: it shrieks and runs (every peer hears it).
func _alert(z: Dictionary) -> void:
	if z.aware or z.dead:
		return
	z.aware = true
	GameState.cue_wave([&"notice", z.id])


## Host: a shot fired at `from` by `peer`: every one within SHOT_HEAR m knows where they are now.
func _heard(peer: int, from: Vector3) -> void:
	if Net.is_client:
		return
	for z: Dictionary in _zombies.values():
		if z.dead or not z.inside or not z.has("afield"):
			continue
		if (z.node as Node3D).global_position.distance_to(from) <= SHOT_HEAR:
			if not z.aware:
				z.grudge = peer
				z.grudge_t = GRUDGE_TIME * 0.5
			_alert(z)


## Host: where `z` runs to for its prey at `prey`: ahead of where they are going, off to its own
## side when others are on them too.
func _aim_for(z: Dictionary, at: Vector3, prey: Vector3) -> Vector3:
	var off := prey - at
	off.y = 0.0
	var d := off.length()
	if not z.aware:
		return prey
	var goal: Vector3 = prey + z.prey_v * clampf(d / maxf(_pace(z), 0.5), 0.0, LEAD_MAX)
	var others := 0
	for o: Dictionary in _zombies.values():
		if not o.dead and o.id != z.id and o.prey == z.prey and o.aware:
			others += 1
	if others > 0 and d > FLANK_NEAR and d > 0.01:
		goal += (off / d).cross(Vector3.UP) * z.flank * minf(FLANK_M, (d - FLANK_NEAR) * 0.4)
	return goal


## Host: one inside (the old hall) or on the open ground goes for a player standing, round what is in
## the way, and swings at them once within REACH. Nobody standing, it waits where it is. On the open
## ground it stalks till it notices one, then runs them down (see STALK above).
func _hunt(z: Dictionary, delta: float) -> void:
	var node: StaticBody3D = z.node
	var at := node.global_position
	var up := _standing()
	var afield: bool = z.has("afield")
	z.think -= delta
	z.grudge_t = maxf(0.0, z.grudge_t - delta)
	z.lunge_cool = maxf(0.0, z.lunge_cool - delta)
	if not afield:
		z.aware = true  # the hall's: they come at the railing knowing
	if z.think <= 0.0 or not up.has(z.prey):
		z.think = HUNT_EVERY
		var was: int = z.prey
		z.prey = _pick_prey(z, at, up)
		if z.prey != 0:
			var prey: Vector3 = up[z.prey]
			z.prey_v = (prey - z.prey_last) / HUNT_EVERY if was == z.prey and z.prey_last != Vector3.INF else Vector3.ZERO
			z.prey_v = (z.prey_v as Vector3).limit_length(8.0)
			z.prey_last = prey
			if afield and z.role == &"":
				_sense(z, at, z.prey, prey)
			z.goal = _aim_for(z, at, prey)
			z.path = _route(at, z.goal)
	if z.down > 0.0 or z.body.busy() or z.swinging:
		z.stuck_t = 0.0
		z.stuck_from = at
		return
	if z.prey == 0:
		_moving(z, 0.0)
		return
	var prey: Vector3 = up[z.prey]
	if afield and z.role != &"" and _play_role(z, delta, at, prey):
		return
	z.pounce = maxf(0.0, z.pounce - delta)
	var off := prey - at
	off.y = 0.0
	if z.leap_ready:
		if off.length() <= LEAP_MIN or z.body.crawling:
			z.leap_ready = false
		elif off.length() <= LEAP_MAX:
			_leap(z, prey)
			return
	if off.length() <= REACH:
		_moving(z, 0.0)
		_turn_to(node, off, FACE_TURN * delta)
		_swing(z)
		return
	# Its way: the last metres straight at them, else along its path (stepping aside when stuck).
	var to := off
	if z.detour_t > 0.0:
		z.detour_t -= delta
		to = z.detour - at
		to.y = 0.0
		if to.length() < 0.3:
			z.detour_t = 0.0
	elif off.length() > DIRECT:
		while z.path.size() > 1 and Vector2(z.path[0].x - at.x, z.path[0].z - at.z).length() < WAYPOINT_SLACK:
			z.path.pop_front()
		if z.path.is_empty():
			z.path = _route(at, z.goal)
		to = z.path[0] - at
		to.y = 0.0
		if to.length() < 0.05:  # on its last point and they are not there: straight on
			to = off
	z.stagger = maxf(0.0, z.stagger - delta)
	if z.aware and z.lunge <= 0.0 and z.lunge_cool <= 0.0 and off.length() < LUNGE_FROM and not z.body.crawling:
		z.lunge = LUNGE_TIME
		z.lunge_cool = LUNGE_COOL
	z.lunge = maxf(0.0, z.lunge - delta)
	var want := _pace(z)
	if not z.aware:
		want = _stalk_pace(z)
	elif z.pounce > 0.0:
		want *= POUNCE
	elif z.lunge > 0.0:
		want *= LUNGE
	elif off.length() > CATCH_FAR:
		want *= CATCH_UP
	if z.stagger > 0.0:
		want *= STAGGER_SLOW
	z.pace_now = move_toward(z.pace_now, want, ACCEL * delta)
	var step := minf(z.pace_now * delta, maxf(0.0, off.length() - REACH * 0.8))
	if to.length() < 0.01 or step <= 0.0:
		_moving(z, 0.0)
		return
	var way := _steer(z, to, step, delta, z.aware and off.length() < LOOK * 2.0)
	var face := way
	# One nearer the player in the way: it edges round it on its own side (a crowd round someone,
	# not one heap on them), slower, never standing behind it.
	for o: Dictionary in _zombies.values():
		if o.dead or not o.inside or o.id == z.id:
			continue
		var rel: Vector3 = (o.node as Node3D).global_position - at
		rel.y = 0.0
		var near: float = SPREAD * 1.2 * maxf(z.body.size, o.body.size)
		if rel.length() < near and rel.dot(way) > 0.4 * rel.length() and prey.distance_to((o.node as Node3D).global_position) < off.length():
			var side := 1.0 if z.id % 2 == 0 else -1.0
			way = way.rotated(Vector3.UP, side * PI * 0.45)
			step *= 0.6
			break
	node.global_position = at + way * step if afield else _keep_side(at + way * step)
	if afield and (_beat + z.id) % GROUND_EVERY == 0:  # across the open ground, on it
		node.global_position = _on_ground(node.global_position, node)
	z.walked += step
	_turn_to(node, face, TAU * 2.0 * delta)
	_moving(z, step / delta)
	_unstick(z, at, to, delta)


## Host: `z` meant to walk this frame (from `at`, towards `to`). Gone nowhere for STUCK_EVERY s: a
## fresh way, then a step aside, then back onto the mesh.
func _unstick(z: Dictionary, at: Vector3, to: Vector3, delta: float) -> void:
	z.stuck_t += delta
	if z.stuck_t < STUCK_EVERY:
		return
	var moved := Vector2(at.x - z.stuck_from.x, at.z - z.stuck_from.z).length()
	z.stuck_t = 0.0
	z.stuck_from = at
	if moved >= STUCK_MOVED:
		z.stuck_n = 0
		return
	z.stuck_n += 1
	z["unstuck"] = z.get("unstuck", 0) + 1  # tools/zombie_stuck_check.gd
	z.think = 0.0  # a fresh pick and way at once
	z.path = []
	if z.stuck_n >= STUCK_SNAP and _nav.navigation_mesh != null:
		var on := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, at)
		if on != Vector3.ZERO:  # zero: the map has not taken the mesh in yet (its regions settle on threads)
			(z.node as Node3D).global_position = _on_ground(Vector3(on.x, at.y + 0.5, on.z), z.node)
		z.stuck_n = 0
	elif z.stuck_n >= 2:
		var side := to.normalized().cross(Vector3.UP) * (1.0 if (z.stuck_n + z.id) % 2 == 0 else -1.0)
		var aside := at + (side - to.normalized() * 0.5).normalized() * DETOUR
		if _nav.navigation_mesh != null:
			var on := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, aside)
			aside = on if on != Vector3.ZERO else aside
		z.detour = Vector3(aside.x, 0.0, aside.z)
		z.detour_t = DETOUR_TIME


## Its stalking pace: STALK of its own, within its walk clips' stride (its own gait if it has none).
func _stalk_pace(z: Dictionary) -> float:
	var span: Vector2 = z.body.gait_span("walk")
	var v := _pace(z) * STALK
	if span.y * 0.95 < STALK_MIN:  # its walk clips crawl along (0.15 m/s on some): its own gait instead
		return v
	return clampf(v, maxf(span.x, STALK_MIN), span.y * 0.95)


## Host: a swing at its prey (every peer sees it). Through the wind-up it keeps coming at them; the
## blow lands at the clip's strike (zombie_body.gd ATTACKS) if they are still within reach and up.
func _swing(z: Dictionary) -> void:
	z.swinging = true
	z.pace_now = 0.0
	GameState.cue_wave([&"swing", z.id])
	var t: float = z.swing
	var strike: float = minf(z.body.strike, t)
	var node: Node3D = z.node
	var left := strike
	while left > 0.0:
		await get_tree().process_frame
		if not is_instance_valid(node) or z.dead:
			return
		var dt := get_process_delta_time()
		left -= dt
		var up := _standing()
		if up.has(z.prey) and not z.body.crawling:
			var off: Vector3 = up[z.prey] - node.global_position
			off.y = 0.0
			if off.length() > REACH * 0.6:
				var step := minf(SWING_STEP * dt, off.length() - REACH * 0.6)
				node.global_position += off.normalized() * step
				if z.has("afield") and (_beat + z.id) % GROUND_EVERY == 0:
					node.global_position = _on_ground(node.global_position, node)
			_turn_to(node, off, FACE_TURN * dt)
	if not z.dead and (phase == Phase.FIGHT or z.has("afield")) and z.inside:
		var up := _standing()
		var at := node.global_position
		at.y = 0.0  # _standing() has them on the floor; the ground out here rolls
		if up.has(z.prey) and at.distance_to(up[z.prey]) <= REACH + REACH_SLACK:
			GameState.hurt_player(z.prey, PLAYER_HIT * z.bite, at)
			_tension[z.prey] = minf(1.0, _tension.get(z.prey, 0.0) + TENSE_HIT)
			_last_hit[z.prey] = _clock
	await get_tree().create_timer(maxf(0.0, t - strike) + ARM_SLOW * z.body.arms_hurt() * t + 0.1).timeout
	z.swinging = false


## Its gait as it goes `v` m/s: walking or running by how quick that is for it (GAIT_WALK, GAIT_RUN:
## a stalking one in its walk clips), its stride kept to the floor; or standing. The same on every
## peer from the speed alone.
func _moving(z: Dictionary, v: float) -> void:
	if z.down > 0.0:  # going down on a torn leg: once down, it sets off in its new gait
		z.moving = false
		return
	if z.body.busy():
		return
	if v > 0.3:
		var gait: String = z.gait
		var span: Vector2 = z.body.gait_span("walk")
		if span.y <= 0.0 or z.body.crawling:
			gait = ""
		elif v < _pace(z) * GAIT_WALK and v <= span.y:
			gait = "walk"
		elif v > _pace(z) * GAIT_RUN or v > span.y:
			gait = ""
		if not z.moving or gait != z.gait:
			z.moving = true
			z.gait = gait
			z.body.move(v, gait)
		else:
			z.body.pace(v)
	elif v < 0.1 and z.moving:
		z.moving = false
		z.gait = ""
		z.body.idle()


## Host: the night's trickle out of the wood (see NIGHT_START above). Each night once it is dark: its
## wave planned and spread over what is left of the night in groups of one or two.
func _night_step() -> void:
	if not night_spawns or get_tree().get_first_node_in_group("forest_edge") == null:
		return
	if not nav_live:  # the night waits for the way through the wood (_bake_nav, ~20 s after the start)
		return
	var p := night_progress(GameState.hour)
	if p < 0.0 or GameState.night_of(GameState.hour) < NIGHT_DARK:
		return
	if _night != GameState.nights:
		_plan_night(GameState.nights, p)
	while not _night_groups.is_empty() and (_night_groups[0][1] as float) <= p:
		if _alive() + (_night_groups[0][0] as Array).size() > MAX_ALIVE:
			return  # too many up: it waits its turn
		var group: Array = _night_groups.pop_front()[0]
		_let_out(group, _night_wave, p)


## How far through the night `h` o'clock is, 0 at NIGHT_START to 1 at NIGHT_END; -1 by day.
static func night_progress(h: float) -> float:
	var span := fposmod(NIGHT_END - NIGHT_START, 24.0)
	var p := fposmod(h - NIGHT_START, 24.0) / span
	return p if p < 1.0 else -1.0


## Host: night `n`'s plan from `p` (0..1) on: `wave`'s types, in groups, each with its time.
func _plan_night(n: int, p: float) -> void:
	_night = n
	_night_wave = wave
	wave += 1
	var plan := _plan(_night_wave)
	var groups: Array = []
	var pair := minf(PAIR + PAIR_GROW * (_night_wave - 1), PAIR_MAX)
	var i := 0
	while i < plan.size():
		var t: StringName = plan[i]
		var g: Array = [t]
		i += 1
		if t in [&"dog", &"swarm"]:  # a pack comes as one
			while i < plan.size() and plan[i] == t:
				g.append(plan[i])
				i += 1
		elif i < plan.size() and not plan[i] in [&"dog", &"swarm"] and _rng.randf() < pair:
			g.append(plan[i])
			i += 1
		groups.append(g)
	var from := minf(p + NIGHT_QUIET, 1.0 - NIGHT_SPARE)
	var span := maxf(0.0, 1.0 - NIGHT_SPARE - from)
	_night_groups.clear()
	var dues := []
	for k in groups.size():
		dues.append(from + span * pow((k + _rng.randf_range(0.15, 0.85)) / groups.size(), 1.0 / NIGHT_RISE))
	dues.sort()
	if not dues.is_empty():  # a lone one early, so the night is known to have begun; the rest build up
		dues[0] = from + span * _rng.randf_range(0.0, NIGHT_FIRST)
	for k in groups.size():
		_night_groups.append([groups[k], dues[k]])


## Host: `group` (types) of wave `w` comes up in the wood, out of sight, and makes for the players.
func _let_out(group: Array, w: int, p: float) -> void:
	var spot := _hidden_spot()
	if spot == Vector3.INF:
		for t: StringName in group:
			_step_out(t, w)
		night_log.append([_night, p, GameState.hour, group.size(), Vector3.INF])
		return
	var to := Vector3(CLEARING_CENTRE.x, 0.0, CLEARING_CENTRE.y) - spot
	for k in group.size():
		var at := spot + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
		if _nav.navigation_mesh != null:
			var on := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, at)
			if on != Vector3.ZERO:
				at = on
		_summon(group[k], _on_ground(at + Vector3.UP * 3.0), atan2(-to.x, -to.z), w, _rng.randf() < elite_chance(group[k], w))
	night_log.append([_night, p, GameState.hour, group.size(), spot])


## Host: a spot in the wood HIDE_DEEP m past the clearing's edge that no player is near or can see
## (see HIDE_NEAR above), on the walkable mesh; INF if none of a few tries is.
func _hidden_spot() -> Vector3:
	var up := {}
	for peer: int in GameState._slots_now():
		var pl = GameState.player(peer)
		if pl.has_pose and not GameState.is_down(peer):
			up[peer] = pl
	var space := get_world_3d().direct_space_state
	var map := get_world_3d().navigation_map
	for attempt in 40:
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		var deep: float = _rng.randf_range(HIDE_DEEP[0], HIDE_DEEP[1])
		var p := CLEARING_CENTRE + dir * CLEARING_RADII * (1.0 + deep / minf(CLEARING_RADII.x, CLEARING_RADII.y))
		if JUNK_YARD.has_point(p) or not NAV_AREA.grow(-2.0).has_point(p):
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 60.0, p.y), Vector3(p.x, -20.0, p.y), 1))
		if not hit:
			continue
		var at: Vector3 = hit.position
		if _nav.navigation_mesh != null:
			var on := NavigationServer3D.map_get_closest_point(map, at)
			if Vector2(on.x - at.x, on.z - at.z).length() > 1.0:
				continue  # in a thicket, a rock: nowhere to stand
			at = on
		var seen := false
		for peer: int in up:
			var pl = up[peer]
			var rel: Vector3 = at - pl.pos
			rel.y = 0.0
			var d := rel.length()
			if d < HIDE_NEAR:
				seen = true
				break
			var look := Vector3(-sin(pl.yaw), 0.0, -cos(pl.yaw))
			if d < HIDE_SEEN and rad_to_deg(look.angle_to(rel)) < HIDE_CONE:
				var ray := PhysicsRayQueryParameters3D.create(pl.pos + Vector3.UP * 1.6, at + Vector3.UP * 1.2, 1)
				if not space.intersect_ray(ray):
					seen = true
					break
		if not seen:
			return at
	return Vector3.INF


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
			if z.cross != &"":  # through on the host before this copy was: on the floor, up, as the host has it
				if z.cross in [&"duck", &"creep", &"fall", &"lie"]:
					z.body.get_up()
				z.cross = &""
				(z.node as Node3D).global_position.y = 0.0
			z.inside = true
			z.hole = -1
			z.path = []
			z.claws += 1
		if z.get("leap_on", false):
			continue  # in the air on its own timeline (_leaping): the host's word would tug it
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
	node.global_position.y = lerpf(node.global_position.y, z.seen.y, minf(1.0, 8.0 * delta))  # the ground out here rolls
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
	p.bus = Ps1Sound.bus_of("dunya")  # PsAcik: the open land's echo
	p.unit_size = SOUND_UNIT
	p.max_distance = SOUND_RANGE
	at.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# --- the director and the hunter's tricks (2026-11-06) ------------------------------------------

## Host: every player's tension, and now and then one of the dead given a trick to play on them
## (DIRECTOR_EVERY): when they are calm (tension under CALM), nothing was played on them for
## EVENT_GAP s, nothing hit them for QUIET_AFTER_HIT s, at EVENT_CHANCE a look; never the same
## trick twice running on one player. Tension: TENSE_HIT a blow, TENSE_NEAR a second for every one
## running at them within TENSE_NEAR_M m, down by TENSE_FALL a second.
func _direct(delta: float) -> void:
	_clock += delta
	var up := _standing()
	for peer: int in up:
		var near := 0
		for z: Dictionary in _zombies.values():
			if not z.dead and z.aware and z.role == &"" and z.prey == peer \
					and (z.node as Node3D).global_position.distance_to(up[peer]) < TENSE_NEAR_M:
				near += 1
		_tension[peer] = clampf(_tension.get(peer, 0.0) + (TENSE_NEAR * near - TENSE_FALL) * delta, 0.0, 1.0)
	_direct_wait -= delta
	if _direct_wait > 0.0:
		return
	_direct_wait = DIRECTOR_EVERY
	if _tricks_night != GameState.nights:
		_tricks_night = GameState.nights
		_night_tricks.clear()
	for peer: int in up:
		if _clock - _last_any < TRICK_GAP or tricks_tonight() >= NIGHT_TRICKS_ALL + NIGHT_TRICKS_PER_PLAYER * (up.size() - 1):
			return
		if tension_of(peer) > CALM or _clock - _last_event.get(peer, -INF) < EVENT_GAP \
				or _clock - _last_hit.get(peer, -INF) < QUIET_AFTER_HIT:
			continue
		if _rng.randf() >= EVENT_CHANCE:
			continue
		var tricks: Array[StringName] = [&"ambush", &"shy"]
		if _is_busy(peer):
			tricks = [&"sneak", &"sneak", &"ambush"]  # a player at the bench or the heap: mostly from behind
		var last: StringName = _last_trick.get(peer, &"")
		var last_any: StringName = _last_any_trick
		for t: StringName in tricks.duplicate():
			if t == last or t == last_any or _night_tricks.get(t, 0) >= NIGHT_TRICKS[t]:
				tricks.erase(t)
		_shuffle(tricks)
		for trick: StringName in tricks:
			if _play(trick, peer, up[peer]):
				break


## Host: how tense `peer` is: ours (the dead about them, blows) or the wood's watching
## (forest_presence.gd presence_tension), whichever is higher: one budget for both.
func tension_of(peer: int) -> float:
	if not _presence_looked:
		_presence_looked = true
		for n: Node in get_tree().root.find_children("*", "Node", true, false):
			if n.has_method("presence_tension"):
				_presence = n
				break
	var wood: float = _presence.presence_tension(peer) if _presence and is_instance_valid(_presence) else 0.0
	return maxf(_tension.get(peer, 0.0), wood)


## Host: tricks given tonight, all of them.
func tricks_tonight() -> int:
	var n := 0
	for t: StringName in _night_tricks:
		n += _night_tricks[t]
	return n


## Host: whether `peer` is at something with their eyes on it: a menu of the workshop open
## (GameState.Act.BUSY, player.gd) or digging at the heap lately (GameState PlayerState.busy_at).
func _is_busy(peer: int) -> bool:
	var p = GameState.player(peer)
	return p.act == GameState.Act.BUSY or Time.get_ticks_msec() / 1000.0 - p.busy_at < BUSY_FOR


## Host: `trick` given to one of the dead that fits it, to play on `peer`; false if none does.
func _play(trick: StringName, peer: int, prey: Vector3) -> bool:
	var best: Dictionary = {}
	var near := INF
	for z: Dictionary in _zombies.values():
		if z.dead or not z.has("afield") or z.role != &"" or z.kind in NO_TRICKS or z.body.crawling:
			continue
		var d := Vector2((z.node as Node3D).global_position.x - prey.x, (z.node as Node3D).global_position.z - prey.z).length()
		if d < TRICK_FROM or d > TRICK_TO or (z.aware and trick != &"ambush"):
			continue
		if d < near:
			near = d
			best = z
	if best.is_empty():
		return false
	give_role(best, trick, peer)
	return true


## Host: `z` plays `trick` on `peer` from now (the director's pick; checks call it too). Logged.
func give_role(z: Dictionary, trick: StringName, peer: int) -> void:
	z.role = trick
	z.prey = peer
	z.role_t = 0.0
	z.hide = Vector3.INF
	z.path = []
	z.role_wait = 0.0
	_last_event[peer] = _clock
	_last_trick[peer] = trick
	_last_any = _clock
	_last_any_trick = trick
	_night_tricks[trick] = _night_tricks.get(trick, 0) + 1
	z.pause_t = REACT_PAUSE
	_set_mode(z, &"glance")
	event_log.append([_clock, peer, trick, z.id])


## Host: `z`'s bearing (zombie_body.gd set_mode) on every peer.
func _set_mode(z: Dictionary, m: StringName) -> void:
	if z.get("mode", &"") == m:
		return
	z.mode = m
	GameState.cue_wave([&"mode", z.id, m])


## Host: the end of a trick: it shrieks and comes on at once (POUNCE times its pace for POUNCE_TIME s).
func _pounce(z: Dictionary) -> void:
	z.role = &""
	z.lunge_cool = 0.0
	z.think = 0.0
	event_log.append([_clock, z.prey, &"pounce", z.id])
	var up := _standing()
	var d := Vector2((z.node as Node3D).global_position.x - up[z.prey].x, (z.node as Node3D).global_position.z - up[z.prey].z).length() if up.has(z.prey) else INF
	if d <= LEAP_MAX and d > LEAP_MIN and not z.body.crawling:
		_leap(z, up[z.prey])  # near: straight out at them
		return
	_set_mode(z, &"")
	z.aware = false  # so _alert sends the shriek
	_alert(z)
	z.pounce = POUNCE_TIME
	z.leap_ready = true  # it leaps once near (_hunt)


## Host: `z` leaps at its prey at `prey` (on the floor): every peer plays the coil, the flight and
## the landing from the cue (_leaping); it comes down LEAP_SHORT m short of where they stood.
func _leap(z: Dictionary, prey: Vector3) -> void:
	var node: Node3D = z.node
	var from := node.global_position
	var off := prey - from
	off.y = 0.0
	var to := from + off.normalized() * maxf(0.0, off.length() - LEAP_SHORT)
	to = _on_ground(to + Vector3.UP * 1.0, node)
	z.leap_ready = false
	z.pounce = 0.0
	z.aware = true
	z.mode = &""
	GameState.cue_wave([&"leap", z.id, from, to])
	event_log.append([_clock, z.prey, &"leap", z.id])


## Every peer: `z` in its leap, from the cue: still through the coil (facing where it goes), along
## a smooth arc over the ground in the flight (the clip itself rises and falls), still in the landing.
## Done, the host swings if they are still there.
func _leaping(z: Dictionary, delta: float) -> void:
	var node: Node3D = z.node
	z.leap_t += delta
	var times: Array = z.leap_times
	var a: Vector3 = z.leap_a
	var b: Vector3 = z.leap_b
	var t: float = z.leap_t
	if t < times[0]:
		_turn_to(node, b - a, FACE_TURN * 2.0 * delta)
		return
	var s := clampf((t - times[0]) / maxf(times[1], 0.01), 0.0, 1.0)
	node.global_position = a.lerp(b, smoothstep(0.0, 1.0, s))
	if t < times[0] + times[1] + times[2]:
		return
	z.leap_on = false
	z.moving = false
	z.gait = ""
	z.pace_now = _pace(z) * 0.5
	if not Net.is_client:
		var up := _standing()
		if up.has(z.prey) and Vector2(node.global_position.x - up[z.prey].x, node.global_position.z - up[z.prey].z).length() <= REACH + REACH_SLACK:
			_swing(z)


## Host: `z` playing its trick on its prey at `prey` (on the floor). True while it does (it moved).
func _play_role(z: Dictionary, delta: float, at: Vector3, prey: Vector3) -> bool:
	z.role_t += delta
	if z.pause_t > 0.0:  # the moment it stops short, its head round
		z.pause_t -= delta
		z.pace_now = 0.0
		_moving(z, 0.0)
		if z.pause_t <= 0.0:
			_set_mode(z, &"crouch")
		return true
	var p = GameState.player(z.prey)
	var look := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))
	var rel := at - prey
	rel.y = 0.0
	var d := rel.length()
	var looked := rad_to_deg(look.angle_to(rel)) if d > 0.01 else 0.0  # 0: they look right at it
	match z.role:
		&"ambush":
			# Behind a trunk on its side of them, waiting; out when they come near or turn their back.
			var waited: float = z.role_t - z.role_wait if z.role_wait > 0.0 else 0.0
			if z.role_t > AMBUSH_GIVE_UP or d < POUNCE_NEAR or waited > AMBUSH_MIN_WAIT and d < POUNCE_BACK_M and looked > POUNCE_BACK:
				_pounce(z)
				return false
			var look_again: bool = z.role_t >= z.recheck
			if look_again:
				z.recheck = z.role_t + 1.0
			if z.hide == Vector3.INF or look_again and not _is_hidden(prey, z.hide):
				z.hide = _cover(prey, at, AMBUSH_RING)
				if z.hide == Vector3.INF:
					_pounce(z)  # no trunk to wait at: it simply comes
					return false
			if _go(z, at, z.hide, _cover_pace(z), delta, 0.08, true):
				if z.role_wait <= 0.0:
					z.role_wait = z.role_t
					event_log.append([_clock, z.prey, &"waiting", z.id])
				_set_mode(z, &"cover")
				_turn_to(z.node, -rel, FACE_TURN * 0.5 * delta)  # slowly round to them
			else:
				_set_mode(z, &"crouch")
			return true
		&"shy":
			# Far off: looked at, it goes behind the nearest trunk; with their back to it, it comes on quick.
			if z.role_t > SHY_GIVE_UP or d < SHY_OUT:
				_pounce(z)
				return false
			if looked < SHY_SEEN:
				if not z.watched:  # their eyes on it: it freezes a moment, then slips away
					z.watched = true
					z.pause_t = REACT_PAUSE
					_set_mode(z, &"")
					_turn_to(z.node, -rel, PI)
					return true
				if z.hide == Vector3.INF or not _is_hidden(prey, z.hide):
					z.hide = _cover(prey, at, Vector2(maxf(4.0, d - 4.0), d + 4.0))
					if z.hide != Vector3.INF:
						event_log.append([_clock, z.prey, &"hiding", z.id])
				if z.hide != Vector3.INF and _go(z, at, z.hide, _cover_pace(z), delta, 0.08, true):
					_set_mode(z, &"cover")
					_turn_to(z.node, -rel, FACE_TURN * 0.5 * delta)
				else:
					_set_mode(z, &"crouch")
				return true
			z.watched = false
			if looked > SHY_AWAY:
				z.hide = Vector3.INF
				_set_mode(z, &"crouch")
				_go(z, at, prey, _pace(z) * SHY_COME, delta)
				return true
			z.pace_now = 0.0
			_moving(z, 0.0)  # half watched: it holds still
			_turn_to(z.node, -rel, FACE_TURN * delta)
			return true
		&"sneak":
			# Round behind them, wide, at a walk; then in. Seen (they turn to it) or near: out.
			if z.role_t > SNEAK_GIVE_UP or d < SNEAK_OUT or looked < SNEAK_SEEN and d < SNEAK_SEEN_M:
				_pounce(z)
				return false
			_set_mode(z, &"crouch")
			var behind := prey - look * SNEAK_BEHIND
			var to := behind if looked < 150.0 and d > SNEAK_BEHIND * 0.7 else prey
			_go(z, at, to, _stalk_pace(z), delta)
			return true
	z.role = &""
	return false


## Making for cover: quick and unsteady, never at an even pace.
func _cover_pace(z: Dictionary) -> float:
	return _pace(z) * COVER_PACE * (1.0 + COVER_JERK * sin(z.walked * 2.7 + z.zig) * sin(z.walked * 1.3 + z.zig * 2.0))


## Host: `z` (at `at`) one step towards `to` at `pace` m/s, round what is in the way; true once there.
func _go(z: Dictionary, at: Vector3, to: Vector3, pace: float, delta: float, near := 0.35, brake := false) -> bool:
	var off := to - at
	off.y = 0.0
	if off.length() < near:
		z.pace_now = 0.0
		_moving(z, 0.0)
		return true
	z.role_route -= delta
	if z.path.is_empty() or z.role_route <= 0.0:
		z.role_route = HUNT_EVERY
		z.path = _route(at, to)
	while z.path.size() > 1 and Vector2(z.path[0].x - at.x, z.path[0].z - at.z).length() < WAYPOINT_SLACK:
		z.path.pop_front()
	var way: Vector3 = (z.path[0] if not z.path.is_empty() else to) - at
	way.y = 0.0
	if way.length() < 0.05:
		way = off
	if brake:  # into cover: easing off over the last metres
		pace *= clampf(off.length() / COVER_BRAKE, 0.3, 1.0)
	z.pace_now = move_toward(z.pace_now, pace, ACCEL * delta)
	var step := minf(z.pace_now * delta, off.length())
	var node: Node3D = z.node
	node.global_position = at + way.normalized() * step
	if (_beat + z.id) % GROUND_EVERY == 0:
		node.global_position = _on_ground(node.global_position, node)
	z.walked += step
	_turn_to(node, way, TAU * 2.0 * delta)
	_moving(z, step / delta)
	_unstick(z, at, way, delta)
	return false


## The tree trunks of the open ground (their posts, tools/build_world.gd _posts) in cells of
## TRUNK_CELL m: cell -> [[x, z, radius], ...]. Built once.
func _trunk_cells() -> Dictionary:
	if _trunks_built:
		return _trunks
	_trunks_built = true
	var stack: Array[Node] = [get_parent()]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var cs := n as CollisionShape3D
		if cs and cs.shape is CylinderShape3D and cs.get_parent() is StaticBody3D:
			var r: float = (cs.shape as CylinderShape3D).radius * cs.global_basis.get_scale().x
			if r < TRUNK_MIN:
				continue
			var p := cs.global_position
			var key := Vector2i(floori(p.x / TRUNK_CELL), floori(p.z / TRUNK_CELL))
			if not _trunks.has(key):
				_trunks[key] = []
			_trunks[key].append(Vector3(p.x, p.z, r))
	return _trunks


## Whether something at `at` is behind a trunk from `eye` (both on the floor): a trunk across the
## line between them, near the far end.
func _is_hidden(eye: Vector3, at: Vector3) -> bool:
	var cells := _trunk_cells()
	var a := Vector2(eye.x, eye.z)
	var b := Vector2(at.x, at.z)
	var lo := Vector2i(floori(minf(a.x, b.x) / TRUNK_CELL) - 1, floori(minf(a.y, b.y) / TRUNK_CELL) - 1)
	var hi := Vector2i(floori(maxf(a.x, b.x) / TRUNK_CELL) + 1, floori(maxf(a.y, b.y) / TRUNK_CELL) + 1)
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for t: Vector3 in cells.get(Vector2i(x, y), []):
				var c := Vector2(t.x, t.y)
				var along := (c - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001)
				if along <= 0.0 or along >= 1.0 or (b - c).length() > HIDE_BEHIND:
					continue
				if (a + (b - a) * along).distance_to(c) < t.z * 0.9:
					return true
	return false


## A spot right behind a trunk from `eye`, `ring` (min, max) m from it, the nearest to `from`; on
## the walkable mesh and not in the clearing's open middle. INF if none.
func _cover(eye: Vector3, from: Vector3, ring: Vector2) -> Vector3:
	var cells := _trunk_cells()
	var best := Vector3.INF
	var near := INF
	var reach := ceili(ring.y / TRUNK_CELL) + 1
	var at := Vector2i(floori(eye.x / TRUNK_CELL), floori(eye.z / TRUNK_CELL))
	var map := get_world_3d().navigation_map
	for x in range(at.x - reach, at.x + reach + 1):
		for y in range(at.y - reach, at.y + reach + 1):
			for t: Vector3 in cells.get(Vector2i(x, y), []):
				var c := Vector2(t.x, t.y)
				var away := c - Vector2(eye.x, eye.z)
				var d := away.length()
				if d < ring.x or d > ring.y:
					continue
				var spot2 := c + away / d * (t.z + COVER_GAP)
				var cost := spot2.distance_to(Vector2(from.x, from.z))
				if cost >= near:
					continue
				var spot := Vector3(spot2.x, from.y, spot2.y)
				if _nav.navigation_mesh != null:
					var on := NavigationServer3D.map_get_closest_point(map, spot)
					if Vector2(on.x - spot.x, on.z - spot.z).length() > 0.3:
						continue
					spot = on
				if not _is_hidden(eye, spot):  # put back onto the mesh, out from behind it
					continue
				near = cost
				best = spot
	return best


## Every peer: none of the dead stands in a player's body (it shoved them about: the host's moves
## it into them, a capsule against a capsule). Each is put PLAYER_ROOM m off every player standing
## (here: the host's word for all; a client its own player, the rest it follows).
func _keep_off_players() -> void:
	var at := []
	if Net.is_client:
		var me = GameState.player()
		if me.has_pose:
			at.append(me.pos)
	else:
		at = _standing().values()
	if at.is_empty():
		return
	for z: Dictionary in _zombies.values():
		if z.dead or not z.released or z.get("leap_on", false):
			continue
		var node: Node3D = z.node
		for p: Vector3 in at:
			var off := node.global_position - p
			off.y = 0.0
			var d := off.length()
			if d < PLAYER_ROOM:
				var out := off / d if d > 0.01 else (-node.global_transform.basis.z).normalized()
				node.global_position += out * (PLAYER_ROOM - d)


## Host: a head lamp catching one of the dead now and then (see LAMP_REACH above).
func _lamps(delta: float) -> void:
	for z: Dictionary in _zombies.values():
		z.startle_cd = maxf(0.0, z.startle_cd - delta)
	_lamp_wait -= delta
	if _lamp_wait > 0.0 or GameState.night_of(GameState.hour) < 0.5:
		return
	_lamp_wait = LAMP_EVERY
	for peer: int in GameState._slots_now():
		var p = GameState.player(peer)
		if not p.has_pose or GameState.is_down(peer) or _clock - _last_startle.get(peer, -INF) < LAMP_GAP:
			continue
		var look := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))
		for z: Dictionary in _zombies.values():
			if z.dead or not z.has("afield") or z.startle_cd > 0.0 or z.swinging or z.get("leap_on", false) or z.role != &"":
				continue
			var rel: Vector3 = (z.node as Node3D).global_position - p.pos
			rel.y = 0.0
			if rel.length() > LAMP_REACH or rel.length() < 2.5 or rad_to_deg(look.angle_to(rel)) > LAMP_CONE:
				continue
			z.startle_cd = STARTLE_AGAIN
			if _rng.randf() >= LAMP_CHANCE:
				continue
			_last_startle[peer] = _clock
			event_log.append([_clock, peer, &"startle", z.id])
			GameState.cue_wave([&"startle", z.id])
			break
