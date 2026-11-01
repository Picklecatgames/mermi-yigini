extends CanvasLayer
## The workshop bench (scripts/bench_top.gd), opened with E in front of it once a quest has opened
## it (GameState QUESTS m01b). The view leaves the player's eyes for a camera over the bench: on the
## left the guns, on the right what the bench sells for the one picked (GameState UPGRADES marked
## bench, paid from the player's gold). Picking a gun slides it in from the left to the middle of
## the bench, where it hovers. Buying puts the part on with a small show (2026-10-28, the user's
## call): the laser rises from under the barrel and clamps on, landing with a knock, a click,
## sparks and a warm flash. A magazine level swaps the
## magazine. The starting pistol's tape comes off for wooden grips: the gun spins once and comes round
## with them. The Deagle is bought here first. Only these two have parts so far. Local: each player's
## bench shows their own gun.
## Sounds are the guns' own recordings (assets/weapons/sounds).

const Attachments := preload("res://scripts/gun_attachments.gd")
const ARMS := preload("res://assets/weapons/arms/arms.gltf")
const TOP := 0.98  # the bench top in the glb's space (bench_top.gd)
const REACH := 1.9  # m from the bench's front edge that E opens it
## Bench space, metres off the middle of its top: x to the right as seen from the hall, y up, z out
## toward the hall. The gun hovers left of the middle, the cards cover the right of the screen.
const GUN_AT := Vector3(-0.12, 0.2, 0.06)  # the grip's foot clear of the papers on the top
const GUN_FROM := Vector3(-1.1, 0.2, 0.06)  # off the left of the view
const GUN_YAW := -0.25  # rad, the muzzle turned a little toward us
const EYE := Vector3(-0.094, 0.3, 0.6)
const LOOK := Vector3(-0.094, 0.15, 0.06)
const FOV := 40.0
const FLY_TIME := 0.7  # s between the player's eyes and the bench camera
const SLIDE_TIME := 0.6
const BOB := 0.003  # m the hovering gun rises and falls
## Gun space (gun_attachments.gd): from where a part sets off, and the gap it hangs at before the
## last snap home.
const LASER_START := Vector3(0, -0.13, 0.04)  # down by the bench top
const HANG := 0.012
## The Deagle's own magazine bones (the rig's reload clip moves them): the one in the grip, and the
## fresh one the clip brings in, parked out of sight at rest. Out of the grip it slides this far along
## the grip, in gun space (read off Deagle_Reload, 1.05-1.15 s).
const MAGS := ["Magazine", "Magazine_2"]
const MAG_OUT_ALONG := Vector3(0.001, -0.108, -0.017)
const MAG_AWAY := Vector3(-0.32, -0.02, 0.02)  # then toward us (gun -x), level, off the bottom of the view
const MAG_LIFT := 0.06  # m the gun rises for the swap: the magazine's way out stays over the top, the gun in view
## GameState GUNS id and name; only those in GUN_PARTS have parts yet.
const GUNS := [["pistol", "Tabanca"], ["deagle", "Desert Eagle"], ["uzi", "UZI"], ["scorpion", "Scorpion"], ["minigun", "Minigun"]]
const PARTS := {  # bench upgrade -> name, what it does
	"deagle": ["Desert Eagle", ""],  # the gun itself
	"magazine": ["Şarjör", ""],  # "2 → 3 mermi" under it says it
	"grip": ["Ahşap kabza", "Daha az tepme"],
	"laser": ["Lazer nişangâh", "Kafa vuruşu ×3"],
}
## Per gun, its cards; a gun bought here (GameState GUNS "bought") shows only that card until it is.
const GUN_PARTS := {"pistol": ["magazine", "grip"], "deagle": ["deagle", "magazine", "laser"]}
const VIEWMODEL := preload("res://scripts/viewmodel.gd")
const KEY_LIGHT := Color(1.0, 0.88, 0.74)
const FLASH := Color(1.0, 0.62, 0.3)
const CARD_DONE := Color(0.66, 0.6, 0.42)  # a part on for good: the card warms toward brass
const ROW_ON := Color(0.62, 0.58, 0.46)  # the gun on the bench, its row warmer
const ROW_SHUT := Color(0.26, 0.27, 0.26)
const MAG_OUT := preload("res://assets/weapons/sounds/mag_out.wav")
const MAG_IN := preload("res://assets/weapons/sounds/mag_enter.wav")
const MAG_SEAT := preload("res://assets/weapons/sounds/mag_seat.wav")
const SLIDE_BACK := preload("res://assets/weapons/sounds/slide_back.wav")
const SLIDE_HOME := preload("res://assets/weapons/sounds/slide_release.wav")
const TILL := preload("res://assets/sounds/ui/purchase.ogg")

var _bench: Node3D
var _cam := Camera3D.new()
var _stage := Node3D.new()  # bench space, at the middle of the top
var _holder := Node3D.new()  # slides in and out
var _bob := Node3D.new()  # hovers
var _shake := Node3D.new()  # knocked by a part landing; the gun bone's space
var _key := OmniLight3D.new()  # our own light on the gun while the bench is open
var _flash := OmniLight3D.new()
var _gun: Node3D  # the arms rig standing as the gun on the bench alone, made when it is picked
var _skel: Skeleton3D
var _gun_bone := Transform3D()  # the gun bone in the skeleton's space, at rest
var _mag_rest := {}  # MAGS bone -> its rest pose in gun space
var _on_bench := ""  # GUNS id lying there
var _busy := false  # a part is going on: no other buys meanwhile
var _closing := false
var _t := 0.0
var _sfx: Array[AudioStreamPlayer] = []
var _ui := Control.new()
var _gold: Label
var _guns_box: VBoxContainer
var _parts_box: VBoxContainer
var _pick_hint: Label
var _cards := {}  # id -> {card, state, button, style}
var _repair: Button  # mends the railing (GameState.request_repair_fence), its price on it


func _ready() -> void:
	name = "BenchMenu"  # pause_menu.gd leaves Esc to us while we're open
	layer = 5
	visible = false
	_cam.top_level = true  # else they ride along with the player we hang under
	_stage.top_level = true
	add_child(_cam)
	_cam.fov = FOV
	add_child(_stage)
	_stage.add_child(_holder)
	_holder.add_child(_bob)
	_bob.add_child(_shake)
	_holder.visible = false
	for l: OmniLight3D in [_key, _flash]:
		_stage.add_child(l)
		l.visible = false
	_key.light_color = KEY_LIGHT
	_key.light_energy = 0.9
	_key.omni_range = 1.4
	_key.shadow_enabled = true
	_key.position = Vector3(0.15, 0.55, 0.45)
	_flash.light_color = FLASH
	_flash.omni_range = 0.9
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = &"Silah"
		add_child(p)
		_sfx.append(p)
	_build_ui()
	GameState.gold_changed.connect(_refresh.unbind(1))
	GameState.fence_changed.connect(_refresh.unbind(1))
	GameState.vault_changed.connect(_refresh.unbind(1))
	GameState.upgraded.connect(_refresh.unbind(2))


## Standing at the open bench, not busy with anything else (player.gd asks, then calls open).
func can_open() -> bool:
	if visible or not GameState.unlocked("workbench") or not _find_bench():
		return false
	var front := _at(Vector3(0, 0, 0.55))
	var me: Vector3 = get_parent().global_position
	return Vector2(me.x - front.x, me.z - front.z).length() < REACH


func open() -> void:
	_find_bench()
	visible = true
	_closing = false
	_place_stage()
	_hide_player(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var eye: Camera3D = get_parent().get_node("Head/Camera3D")
	_cam.global_transform = eye.global_transform
	_cam.fov = eye.fov
	_cam.make_current()
	var to := _stage.global_transform * Transform3D(Basis.looking_at(LOOK - EYE), EYE)
	var fly := _new_tweens()
	fly.tween_property(_cam, "global_transform", to, FLY_TIME)
	fly.tween_property(_cam, "fov", FOV, FLY_TIME)
	_key.visible = true
	_ui.modulate.a = 0.0
	_fade.tween_property(_ui, "modulate:a", 1.0, 0.35).set_delay(FLY_TIME * 0.5)
	_show_parts(false)
	_refresh()


func close() -> void:
	if _closing:
		return
	_closing = true
	var eye: Camera3D = get_parent().get_node("Head/Camera3D")
	var fly := _new_tweens()
	_fade.tween_property(_ui, "modulate:a", 0.0, 0.2)
	fly.tween_property(_cam, "global_transform", eye.global_transform, FLY_TIME * 0.8)
	fly.tween_property(_cam, "fov", eye.fov, FLY_TIME * 0.8)
	await fly.finished
	eye.make_current()
	_hide_player(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_key.visible = false
	_holder.visible = false
	_on_bench = ""
	visible = false


var _fly: Tween
var _fade: Tween


## Fresh camera and UI tweens; the old ones die, so an Esc right after E doesn't flash the UI back.
func _new_tweens() -> Tween:
	for t: Tween in [_fly, _fade]:
		if t:
			t.kill()
	_fly = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fade = create_tween()
	return _fly


func _input(event: InputEvent) -> void:
	if not visible or get_parent().get_node("UpgradeMenu").visible:
		return  # the upgrades over the bench have the keys; Esc there goes back to the bench
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pick_up"):
		close()
	if event is InputEventKey:
		get_viewport().set_input_as_handled()  # no walking, guns, Q or B behind the bench


## A click the cards let pass would reach player.gd, which takes the mouse back into the game.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_place_stage()  # the bench may still be settling from its drop (reveal.gd)
	_bob.position.y = sin(_t * 1.6) * BOB
	_bob.rotation.x = sin(_t * 1.1) * 0.012


# --- the stage --------------------------------------------------------------------------------

func _find_bench() -> bool:
	_bench = get_tree().get_first_node_in_group("workbench") as Node3D
	return _bench != null


## Bench space (metres, see GUN_AT) to the world.
func _at(p: Vector3) -> Vector3:
	return _stage_transform() * p


func _stage_transform() -> Transform3D:
	if not is_instance_valid(_bench) and not _find_bench():
		return Transform3D(Basis(), Vector3(0, TOP, 0))  # no bench in this level (the checks)
	var b := _bench.global_transform
	return Transform3D(b.basis.orthonormalized(), b * Vector3(0, TOP, 0))


func _place_stage() -> void:
	_stage.global_transform = _stage_transform()


func _hide_player(hide: bool) -> void:
	var me := get_parent()
	for path in ["HUD", "ViewmodelView"]:
		var n := me.get_node_or_null(path)
		if n:
			n.visible = not hide


## The arms rig in the gun's Idle pose with only the gun shown, moved so the gun bone sits at
## _shake's origin (as upgrade_menu.gd's gold Deagle). Parts already bought go on with it.
func _make_gun(id: String) -> void:
	for n: Node in _shake.get_children():
		n.queue_free()
	var kit: Dictionary = VIEWMODEL.SETS[id]
	_gun = ARMS.instantiate()
	_shake.add_child(_gun)
	var skel: Skeleton3D = _gun.find_child("Skeleton3D", true, false)
	var pistol := VIEWMODEL.add_pistol(skel)
	VIEWMODEL.pistol_grip(skel, GameState.upgrade_value("grip") > 0)
	pistol.visible = kit.mesh == pistol.name
	var anim: AnimationPlayer = _gun.find_child("AnimationPlayer", true, false)
	anim.play(kit.clips + "Idle")
	anim.seek(0.0, true)
	anim.advance(0.0)
	anim.pause()
	for m: MeshInstance3D in _gun.find_children("*", "MeshInstance3D", true, false):
		m.visible = m.name == kit.mesh or pistol.is_ancestor_of(m)
	_skel = skel
	_gun_bone = skel.get_bone_global_pose(skel.find_bone(kit.bone))
	for m: String in MAGS:
		_mag_rest[m] = _gun_bone.affine_inverse() * skel.get_bone_global_pose(skel.find_bone(m))
	var bone := _gun.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(skel.find_bone(kit.bone))
	bone.basis = bone.basis.orthonormalized()
	_gun.transform = bone.affine_inverse()
	# Gun space to bench space: the barrel to the right, its port side (-x) toward the hall.
	_shake.transform = Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT), Vector3.ZERO)
	if id == "deagle" and GameState.upgrade_value("laser") > 0:
		_shake.add_child(Attachments.make("laser"))


func _pick(id: String) -> void:
	if _busy or _on_bench == id or not GUN_PARTS.has(id):
		return
	_on_bench = id
	_make_gun(id)
	_holder.visible = true
	_holder.position = GUN_FROM
	_holder.rotation = Vector3(0, GUN_YAW + 0.5, 0.06)
	_play(SLIDE_BACK, -8.0, 0.8)
	var t := create_tween().set_parallel()
	t.tween_property(_holder, "position", GUN_AT, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_holder, "rotation", Vector3(0, GUN_YAW, 0), SLIDE_TIME * 1.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(_play.bind(SLIDE_HOME, -10.0, 1.1)).set_delay(SLIDE_TIME * 0.55)
	_refresh()
	_show_parts(true)


## The bench sells it: the part goes on, then the cards catch up.
func _buy(id: String) -> void:
	if _busy or id not in _parts_of(_on_bench) or not GameState.request_buy_upgrade(id):
		return
	_busy = true
	_play(TILL, -12.0, randf_range(0.95, 1.08))
	_refresh()
	if id == "magazine":
		await _swap_magazine()
	elif id == "grip":
		await _turn_grip()
	elif id == "deagle":
		_play(SLIDE_HOME, -8.0, 0.9)
		_banner("Desert Eagle alındı")
		_show_parts(true)  # its own cards now
	else:
		await _fit(id)
	_busy = false
	_refresh()


## The laser flies in from below, turning to face the gun, hangs a moment a finger's width off,
## then snaps home.
func _fit(id: String) -> void:
	var part := Attachments.make(id)
	_shake.add_child(part)
	var home := part.transform
	var start := home
	start.origin += LASER_START
	start.basis = Basis(Vector3.FORWARD, 0.9) * home.basis
	var hang := home
	hang.origin += Vector3(0, -HANG, 0)
	part.transform = start
	_play(SLIDE_BACK, -14.0, 1.4)
	var t := create_tween()
	t.tween_property(part, "transform", hang, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.18)
	t.tween_property(part, "transform", home, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	_knock(Vector3.UP, home.origin)
	_play(MAG_SEAT, -2.0, 1.15)
	await get_tree().create_timer(0.16).timeout
	_play(MAG_IN, -6.0, 1.3)
	await get_tree().create_timer(0.25).timeout  # its lens lights up: on
	_play(SLIDE_HOME, -14.0, 1.8)
	_banner(PARTS[id][0] + " takıldı")


## The tape comes off: the gun spins once about its barrel and comes round with wooden grips,
## landing back level with a knock.
func _turn_grip() -> void:
	_play(SLIDE_BACK, -12.0, 1.2)
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_holder, "rotation:x", PI, 0.35)
	t.tween_callback(VIEWMODEL.pistol_grip.bind(_skel, true))
	t.tween_property(_holder, "rotation:x", TAU, 0.35)
	await t.finished
	_holder.rotation.x = 0.0
	_knock(Vector3.UP, Vector3(0, -0.05, -0.08))
	_play(MAG_SEAT, -2.0, 0.9)
	_banner(PARTS.grip[0] + " takıldı")


## The gun rises and tips its grip toward us, its own magazine drops out along the grip and is
## taken away toward us, off the bottom of the view and over the bench top (it went through the top
## before, 2026-10-28); the fresh one (the rig's second magazine) comes back that way, lines up under
## the grip and is pushed home with a knock. Then the two swap back unseen (the same model), so the
## gun is at rest again, and it settles back down.
func _swap_magazine() -> void:
	var tip := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tip.tween_property(_holder, "rotation:x", -0.45, 0.3)
	tip.tween_property(_holder, "position:y", GUN_AT.y + MAG_LIFT, 0.3)
	await tip.finished
	var seated: Transform3D = _mag_rest[MAGS[0]]
	var below := seated.translated(MAG_OUT_ALONG * 1.25)
	var away := Transform3D(Basis(Vector3.FORWARD, -0.7) * seated.basis, seated.origin + MAG_OUT_ALONG + MAG_AWAY)
	_play(MAG_OUT, -2.0, 1.0)
	var t := create_tween()
	t.tween_method(_pose_mag.bind(MAGS[0], seated, seated.translated(MAG_OUT_ALONG)), 0.0, 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_interval(0.15)
	t.tween_method(_pose_mag.bind(MAGS[0], seated.translated(MAG_OUT_ALONG), away), 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_pose_mag.bind(1.0, MAGS[0], _mag_rest[MAGS[1]], _mag_rest[MAGS[1]]))  # parked
	t.tween_method(_pose_mag.bind(MAGS[1], away, below), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(_play.bind(MAG_IN, -2.0, 1.0))
	t.tween_interval(0.1)
	t.tween_method(_pose_mag.bind(MAGS[1], below, seated), 0.0, 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	_play(MAG_SEAT, 0.0, 1.0)
	_knock(Vector3.UP, seated.origin)
	_pose_mag(1.0, MAGS[0], seated, seated)  # the swap back: the gun at rest again
	_pose_mag(1.0, MAGS[1], _mag_rest[MAGS[1]], _mag_rest[MAGS[1]])
	var back := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(_holder, "rotation:x", 0.0, 0.35).set_delay(0.15)
	back.tween_property(_holder, "position:y", GUN_AT.y, 0.4).set_delay(0.15)
	await back.finished
	_banner("Şarjör: %d mermi" % GameState.upgrade_value("magazine"))


## Magazine bone `mag` `k` of the way from `from` to `to` (gun space). They hang off no other
## bone, so their pose is in the skeleton's space; the rig's clip is paused, nothing overwrites it.
func _pose_mag(k: float, mag: String, from: Transform3D, to: Transform3D) -> void:
	_skel.set_bone_pose(_skel.find_bone(mag), _gun_bone * from.interpolate_with(to, k))


## A part landing: the gun jolts along `dir` (gun space) and springs back, sparks fly off `at`,
## a warm flash, the camera shakes a little.
func _knock(dir: Vector3, at: Vector3) -> void:
	_shake.position = _shake.basis * dir * 0.006
	var spring := create_tween()
	spring.tween_property(_shake, "position", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 18
	sparks.lifetime = 0.35
	sparks.direction = -dir
	sparks.spread = 70.0
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 1.1
	sparks.gravity = Vector3(0, -6, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.0012
	mesh.height = 0.0024
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.75, 0.4)
	mesh.material = hot
	sparks.mesh = mesh
	sparks.position = at
	_shake.add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	_flash.visible = true
	_flash.global_position = _shake.global_transform * at + Vector3.UP * 0.08
	var f := create_tween()
	f.tween_property(_flash, "light_energy", 0.0, 0.35).from(2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	f.tween_callback(func() -> void: _flash.visible = false)
	var shake := create_tween()
	for k in 4:
		shake.tween_property(_cam, "h_offset", randf_range(-1.0, 1.0) * 0.004 * (4 - k) / 4.0, 0.03)
		shake.parallel().tween_property(_cam, "v_offset", randf_range(-1.0, 1.0) * 0.004 * (4 - k) / 4.0, 0.03)
	shake.tween_property(_cam, "h_offset", 0.0, 0.05)
	shake.parallel().tween_property(_cam, "v_offset", 0.0, 0.05)


func _play(stream: AudioStream, db: float, pitch: float) -> void:
	for p in _sfx:
		if not p.playing:
			p.stream = stream
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return


# --- the screen -------------------------------------------------------------------------------

func _build_ui() -> void:
	add_child(_ui)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.fit_screen(_ui)
	# Left: the bench's name, the guns.
	var left := VBoxContainer.new()
	left.position = Vector2(56, 64)
	left.add_theme_constant_override("separation", 10)
	_ui.add_child(left)
	left.add_child(UiStyle.display("TEZGÂH", 46, UiStyle.BOLD, UiStyle.ACCENT))
	left.add_child(UiStyle.line(260))
	_guns_box = VBoxContainer.new()
	_guns_box.add_theme_constant_override("separation", 6)
	left.add_child(_guns_box)
	for g: Array in GUNS:
		_guns_box.add_child(_gun_row(g[0], g[1]))
	# What the Q menu was (scripts/upgrade_menu.gd): the player's own upgrades, opened over the
	# bench (2026-10-28, the user's call: everything is bought here).
	left.add_child(UiStyle.line(260))
	var upgrades := _gun_row("", "GELİŞTİRMELER")
	upgrades.text = "  GELİŞTİRMELER"
	upgrades.disabled = false
	upgrades.pressed.connect(func() -> void: get_parent().get_node("UpgradeMenu").open_tab(0))
	left.add_child(upgrades)
	# The railing is mended here (2026-10-31, the user's call: at the workshop bench, not the desk).
	_repair = _gun_row("", "ÇİTİ ONAR")
	_repair.disabled = false
	_repair.pressed.connect(func() -> void:
		if GameState.request_repair_fence() > 0:
			_banner("Çit onarıldı"))
	left.add_child(_repair)
	# Right: gold, then the parts for the gun on the bench.
	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -436
	right.offset_right = -56
	right.offset_top = 64
	right.add_theme_constant_override("separation", 12)
	_ui.add_child(right)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(head)
	_gold = UiStyle.display("", 40, UiStyle.SEMIBOLD, UiStyle.MONEY)
	head.add_child(_gold)
	right.add_child(UiStyle.line())
	_pick_hint = UiStyle.label("", 16, UiStyle.MEDIUM, UiStyle.DIM)  # the guns on the left say it
	_pick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_pick_hint)
	_parts_box = VBoxContainer.new()
	_parts_box.add_theme_constant_override("separation", 10)
	right.add_child(_parts_box)
	for id: String in PARTS:
		_parts_box.add_child(_part_card(id))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 22)
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_top = -64
	foot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	foot.add_child(UiStyle.hint(["ESC", "E"], ""))
	_ui.add_child(foot)


func _gun_row(id: String, title: String) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(300, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD, 1, true))
	b.add_theme_font_size_override("font_size", 24)
	var has_parts := GUN_PARTS.has(id)
	b.text = "  " + title.to_upper() + ("" if has_parts else "      yakında")
	b.disabled = not has_parts
	for s: String in ["normal", "hover", "pressed", "disabled", "focus"]:  # steel rows, as the press's
		var t := UiStyle.PLATE_GREY.lightened(0.12) if s == "hover" else (ROW_SHUT if s == "disabled" else UiStyle.PLATE_GREY)
		b.add_theme_stylebox_override(s, UiStyle.plate("row", title, t, 10) if s != "focus" else StyleBoxEmpty.new())
	b.add_theme_color_override("font_disabled_color", Color(UiStyle.DIM, 0.45))
	b.pressed.connect(_pick.bind(id))
	b.set_meta("id", id)
	return b


func _part_card(id: String) -> Control:
	var card := PanelContainer.new()
	var style := UiStyle.machine_card(id, 20)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var about := VBoxContainer.new()
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.add_theme_constant_override("separation", 0)
	row.add_child(about)
	about.add_child(UiStyle.display(PARTS[id][0].to_upper(), 26, UiStyle.BOLD))
	var what := UiStyle.label(PARTS[id][1], 14, UiStyle.REGULAR, UiStyle.DIM)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.visible = PARTS[id][1] != ""
	about.add_child(what)
	var state := UiStyle.label("", 14, UiStyle.MEDIUM, UiStyle.ACCENT)
	about.add_child(state)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(124, 48)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", UiStyle.face(UiStyle.BOLD, 0, true))
	b.add_theme_font_size_override("font_size", 22)
	UiStyle.brass_button(b, id)
	b.pressed.connect(_buy.bind(id))
	row.add_child(b)
	_cards[id] = {"card": card, "state": state, "button": b, "style": style}
	return card


## The cards of the gun on the bench: a gun still to buy has only its own.
func _parts_of(gun: String) -> Array:
	var parts: Array = GUN_PARTS.get(gun, [])
	if gun in parts:
		return [gun] if GameState.upgrade_value(gun) == 0 else parts.filter(func(p: String) -> bool: return p != gun)
	return parts


## The cards come in from the right, one after another, once a gun is on the bench.
func _show_parts(on: bool) -> void:
	_pick_hint.visible = not on
	_parts_box.visible = on
	if not on:
		return
	var i := 0
	for id: String in PARTS:
		var card: Control = _cards[id].card
		card.visible = id in _parts_of(_on_bench)
		if not card.visible:
			continue
		card.modulate.a = 0.0
		var t := card.create_tween().set_parallel()
		t.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(SLIDE_TIME * 0.5 + i * 0.08)
		t.tween_property(card, "position:x", 0.0, 0.35).from(60.0).set_delay(SLIDE_TIME * 0.5 + i * 0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		i += 1


func _refresh() -> void:
	if not visible:
		return
	_gold.text = "$" + UiStyle.dotted(GameState.gold)
	var price := GameState.fence_repair_price()
	var money := GameState.vault if GameState.team_vault() else float(GameState.gold)
	_repair.text = "  ÇİT SAĞLAM" if price == 0 else "  ÇİTİ ONAR   $" + UiStyle.dotted(price)
	_repair.disabled = price == 0 or money < GameState.FENCE_REPAIR_COST  # short of it all: as much as the money covers
	for b: Button in _guns_box.get_children():
		var on: bool = b.get_meta("id") == _on_bench
		(b.get_theme_stylebox("normal") as StyleBoxTexture).modulate_color = ROW_ON if on else UiStyle.PLATE_GREY
	for id: String in PARTS:
		var c: Dictionary = _cards[id]
		var level: int = GameState.player().levels[id]
		var costs: Array = GameState.UPGRADES[id].costs
		var maxed := level >= costs.size()
		var b: Button = c.button
		var state: Label = c.state
		if id == "magazine":
			state.text = "%d mermi · en çok" % GameState.upgrade_value(id) if maxed \
				else "%d → %d mermi" % [GameState.upgrade_value(id), GameState.UPGRADES[id].values[level + 1]]
		else:
			state.text = ""  # the button says "Takılı"
		state.visible = state.text != ""
		var cost: int = 0 if maxed else costs[level]
		b.text = ("Tamam" if id == "magazine" else "Takılı") if maxed else "$%d" % cost
		b.disabled = maxed or _busy or GameState.gold < cost
		(c.style as StyleBoxTexture).modulate_color = CARD_DONE if maxed 			else (UiStyle.MACHINE_PAINT.lightened(0.12) if not b.disabled else UiStyle.MACHINE_PAINT.darkened(0.15))


## A line over the gun for a moment: what just went on.
func _banner(text: String) -> void:
	var l := UiStyle.display(text.to_upper(), 34, UiStyle.BOLD, UiStyle.ACCENT)
	_ui.add_child(l)
	var over := _cam.unproject_position(_holder.global_position + Vector3.UP * 0.14) / _ui.scale
	l.reset_size()
	l.position = over - Vector2(l.size.x / 2.0, l.size.y)
	l.pivot_offset = l.size / 2.0
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.3).from(Vector2.ONE * 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 1.0, 0.15).from(0.0)
	t.tween_interval(1.2)
	t.tween_property(l, "modulate:a", 0.0, 0.4)
	t.tween_callback(l.queue_free)
