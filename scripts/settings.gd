extends Node
## The player's own settings (autoload `Settings`): what they are, saved to user://settings.cfg and
## put to work on the audio buses, the hall's rendering, the window and the input map. Local only,
## nothing here goes over the network. scripts/pause_menu.gd is the page that changes them.
##
## Sounds are sorted onto buses as they enter the tree (_sort_sound): a player still on Master
## goes to Silahlar if it belongs to a gun, to Efekt otherwise; the hall's own buses (Dunya, Adim)
## and the guns' panned bus send into those. Ambience puts its own players on Ambiyans.

signal changed(key: String)

const PATH := "user://settings.cfg"
const BUSES := {"Silahlar": "weapon_vol", "Efekt": "effect_vol", "Ambiyans": "ambience_vol", "Muzik": "music_vol"}
const GUN_SOUNDS := ["ShotSound", "DrySound", "SlideSound", "MagSound", "Tink"]  # viewmodel.tscn
# The actions the player may move to another key, in the order the page lists them.
const ACTIONS := [
	["move_forward", "İleri"], ["move_back", "Geri"], ["move_left", "Sola"], ["move_right", "Sağa"],
	["jump", "Zıpla"], ["sprint", "Koş"], ["crouch", "Eğil"], ["fire", "Ateş et"], ["aim", "Nişan al"],
	["reload", "Şarjör / mermi çarkı"], ["pick_up", "Hurda al"], ["throw", "Hurda fırlat"],
]
const PRESETS := ["Düşük", "Orta", "Yüksek", "Ultra"]
const PRESET_VALUES := [  # what each preset sets; anything else changed by hand makes it "Özel"
	{"render_scale": 70, "upscaler": 1, "antialias": 1, "shadows": 0, "ssao": false, "ssil": false, "ssr": false, "fog": false, "glow": true},
	{"render_scale": 85, "upscaler": 1, "antialias": 2, "shadows": 1, "ssao": true, "ssil": false, "ssr": false, "fog": true, "glow": true},
	{"render_scale": 100, "upscaler": 0, "antialias": 4, "shadows": 2, "ssao": true, "ssil": true, "ssr": true, "fog": true, "glow": true},
	{"render_scale": 100, "upscaler": 0, "antialias": 4, "shadows": 3, "ssao": true, "ssil": true, "ssr": true, "fog": true, "glow": true},
]
const CUSTOM := 4  # preset index: "Özel"
const FPS_LIMITS := [30, 60, 90, 120, 144, 165, 240, 0]
const CROSSHAIR_COLORS := [Color(1, 1, 1), Color(0.35, 1.0, 0.45), Color(1.0, 0.9, 0.25), Color(0.3, 0.95, 1.0), Color(1.0, 0.42, 0.24)]
const SHADOW_ATLAS := [1024, 2048, 4096, 8192]  # px, per shadow level
const SOFT_SHADOWS := [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
const SPEAKER_PAN := 0.6  # 3D panning on speakers: both ears hear both speakers anyway
const PAUSE_MUFFLE_HZ := 900.0
const PSX_LINES := [0, 225, 270, 360, 480, 720]  # "PS1 ekranı": off, then how tall the 3D is drawn (scripts/psx_screen.gd)
## 480 by default (2026-11-03, the user: "oyun pixelart oldu, ben lowpoly PS1 tarzı istemiştim"): at
## 270 the screen's big pixels read as pixel art; low poly, unfiltered textures and the dither stay.

const DEFAULTS := {
	# audio
	"master_vol": 100, "weapon_vol": 100, "effect_vol": 100, "ambience_vol": 100, "music_vol": 100,
	"output": 0,  # 0 headphones, 1 stereo speakers, 2 surround
	"rear_cue": 100,  # % of the "behind you" cue (headphones and stereo cannot say front from back)
	"dynamic_range": 0,  # 0 wide, 1 medium, 2 night (loud shots squeezed)
	"mono": false, "mute_unfocused": true, "pause_muffle": true, "device": "Default",
	# graphics
	"preset": 2, "window_mode": 0, "vsync": true, "fps_limit": 7,
	"render_scale": 100, "upscaler": 0, "antialias": 4, "shadows": 2,
	"ssao": true, "ssil": true, "ssr": true, "fog": true, "glow": true, "brightness": 100,
	"psx": 4, "psx_fine": true,
	# controls
	"sensitivity": 1.0, "ads_sensitivity": 100, "invert_y": false,
	# game
	"fov": 75, "head_bob": 100, "screen_shake": 100, "screen_blood": true, "crosshair_color": 0, "crosshair_size": 100, "crosshair_dot": false, "show_fps": false,
}

# What a loaded number may be: the pause menu's own slider and choice ranges.
const RANGES := {
	"master_vol": Vector2(0, 100), "weapon_vol": Vector2(0, 100), "effect_vol": Vector2(0, 100),
	"ambience_vol": Vector2(0, 100), "music_vol": Vector2(0, 100), "output": Vector2(0, 2), "rear_cue": Vector2(0, 100),
	"dynamic_range": Vector2(0, 2), "preset": Vector2(0, 4), "window_mode": Vector2(0, 2),
	"fps_limit": Vector2(0, 7), "render_scale": Vector2(50, 100), "upscaler": Vector2(0, 2),
	"antialias": Vector2(0, 5), "shadows": Vector2(0, 3), "brightness": Vector2(50, 150), "psx": Vector2(0, 5),
	"sensitivity": Vector2(0.1, 4.0), "ads_sensitivity": Vector2(20, 150), "fov": Vector2(60, 110),
	"head_bob": Vector2(0, 100), "screen_shake": Vector2(0, 100), "crosshair_color": Vector2(0, 4), "crosshair_size": Vector2(50, 200),
}

var values := {}
var binds := {}  # action -> [kind, code]: "k" physical key, "m" mouse button; only the moved ones
var save_path := PATH  # the checks point this elsewhere
var _defaults_binds := {}  # action -> first event as the project ships it
var _graphics_queued := false
var _fps: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		var evs := InputMap.action_get_events(a[0])
		_defaults_binds[a[0]] = evs[0] if evs.size() > 0 else null
	values = DEFAULTS.duplicate()
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		_set_preset_values(0)  # scripts/graphics.gd: the full hall froze an integrated GPU
	if DisplayServer.get_name() != "headless":
		load_file()  # the checks run on the defaults, never on the developer's own settings
	_make_buses()
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().root.find_children("*", "", true, false):  # whatever came in before us
		_on_node_added(n)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_fps = UiStyle.label("", 13, UiStyle.MEDIUM, UiStyle.DIM)
	_fps.position = Vector2(12, 8)
	layer.add_child(_fps)
	add_child(preload("res://scripts/pause_menu.gd").new())
	apply_all()


func _process(_delta: float) -> void:
	_fps.visible = values.show_fps
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		var away: bool = what == NOTIFICATION_APPLICATION_FOCUS_OUT and values.get("mute_unfocused", false)
		AudioServer.set_bus_mute(0, away)


func value(key: String) -> Variant:
	return values[key]


## Sets one setting, puts it to work and saves. A graphics setting moved by hand makes the preset
## "Özel"; the preset itself sets its whole row.
func set_value(key: String, v: Variant) -> void:
	if values.get(key) == v:
		return
	values[key] = v
	if key == "preset":
		if v != CUSTOM:
			_set_preset_values(v)
	elif PRESET_VALUES[0].has(key) and values.preset != CUSTOM and PRESET_VALUES[values.preset][key] != v:
		values.preset = CUSTOM
	apply_all()
	save_file()
	changed.emit(key)


func reset(keys: Array, with_binds := false) -> void:
	for k in keys:
		values[k] = DEFAULTS[k]
	if with_binds:
		for a in binds.keys():
			_bind_event(a, _defaults_binds[a])
		binds.clear()
	apply_all()
	save_file()
	changed.emit("")


func _set_preset_values(i: int) -> void:
	values.preset = i
	for k in PRESET_VALUES[i]:
		values[k] = PRESET_VALUES[i][k]


# --- keys ------------------------------------------------------------------------------------

## The key or button an action fires on now, as the page writes it.
func bind_text(action: String) -> String:
	var evs := InputMap.action_get_events(action)
	return event_text(evs[0]) if evs.size() > 0 else "—"


static func event_text(e: InputEvent) -> String:
	if e is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "Sol tık", MOUSE_BUTTON_RIGHT: "Sağ tık", MOUSE_BUTTON_MIDDLE: "Orta tık",
			MOUSE_BUTTON_WHEEL_UP: "Teker yukarı", MOUSE_BUTTON_WHEEL_DOWN: "Teker aşağı",
			MOUSE_BUTTON_XBUTTON1: "Fare 4", MOUSE_BUTTON_XBUTTON2: "Fare 5"}.get((e as InputEventMouseButton).button_index, "Fare")
	if e is InputEventKey:
		var k := e as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		var names := {KEY_SPACE: "Boşluk", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_TAB: "Tab",
			KEY_CAPSLOCK: "Caps Lock", KEY_ENTER: "Enter", KEY_BACKSPACE: "Geri sil", KEY_UP: "Yukarı ok",
			KEY_DOWN: "Aşağı ok", KEY_LEFT: "Sol ok", KEY_RIGHT: "Sağ ok"}
		if names.has(code):
			return names[code]
		# What the key says on this keyboard's layout (Turkish Q: the key right of L is Ş).
		var local := code < KEY_SPECIAL and DisplayServer.get_name() != "headless"
		return OS.get_keycode_string(DisplayServer.keyboard_get_label_from_physical(code) if local else code)
	return "—"


## Moves `action` to `e`. An action already on that key takes this one's old key (a swap), so no
## two actions ever share one; returns that action, or "".
func rebind(action: String, e: InputEvent) -> String:
	var old: InputEvent = null
	var evs := InputMap.action_get_events(action)
	if evs.size() > 0:
		old = evs[0]
	var other := ""
	for a in ACTIONS:
		if a[0] != action and _same(InputMap.action_get_events(a[0]), e):
			other = a[0]
	_bind_event(action, e)
	binds[action] = _pack(e)
	if other != "" and old != null:
		_bind_event(other, old)
		binds[other] = _pack(old)
	save_file()
	changed.emit("binds")
	return other


func _same(evs: Array, e: InputEvent) -> bool:
	for x in evs:
		if _pack(x) == _pack(e):
			return true
	return false


static func _pack(e: InputEvent) -> Array:
	if e is InputEventMouseButton:
		return ["m", (e as InputEventMouseButton).button_index]
	var k := e as InputEventKey
	return ["k", k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode]


static func _unpack(p: Array) -> InputEvent:
	if p[0] == "m":
		var m := InputEventMouseButton.new()
		m.button_index = p[1]
		return m
	var k := InputEventKey.new()
	k.physical_keycode = p[1]
	return k


func _bind_event(action: String, e: InputEvent) -> void:
	InputMap.action_erase_events(action)
	if e:
		InputMap.action_add_event(action, e)


# --- file ------------------------------------------------------------------------------------

func save_file() -> void:
	if DisplayServer.get_name() == "headless" and save_path == PATH:
		return
	var f := ConfigFile.new()
	for k in values:
		f.set_value("settings", k, values[k])
	for a in binds:
		f.set_value("binds", a, binds[a])
	f.save(save_path)


func load_file() -> void:
	var f := ConfigFile.new()
	if f.load(save_path) != OK:
		return
	for k in DEFAULTS:
		var v: Variant = f.get_value("settings", k, values[k])
		if typeof(v) == typeof(DEFAULTS[k]) or (DEFAULTS[k] is float and v is int):
			values[k] = v  # a hand-edited file with a wrong type keeps the default
			if RANGES.has(k):  # an old or edited file can't index past a list or go to +80 dB
				values[k] = clampf(v, RANGES[k].x, RANGES[k].y) if DEFAULTS[k] is float else clampi(v, int(RANGES[k].x), int(RANGES[k].y))
	for a in ACTIONS:
		var p: Variant = f.get_value("binds", a[0]) if f.has_section_key("binds", a[0]) else null
		if p is Array and p.size() == 2 and p[0] in ["k", "m"] and p[1] is int:
			binds[a[0]] = p
			_bind_event(a[0], _unpack(p))


# --- putting it to work ----------------------------------------------------------------------

func apply_all() -> void:
	_apply_audio()
	_apply_window()
	_queue_graphics()


func _make_buses() -> void:
	for n in BUSES:
		if AudioServer.get_bus_index(n) < 0:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, &"Master")
	Ps1Sound.buses()  # the PS1 reverb buses and Arayuz, into the ones above
	# Ambience heard in the hall's reverb (the lamp hum): Dunya's effects, into Ambiyans.
	var dunya := AudioServer.get_bus_index(&"Dunya")
	if AudioServer.get_bus_index(&"AmbiyansYanki") < 0:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, &"AmbiyansYanki")
		AudioServer.set_bus_send(i, &"Ambiyans")
		if dunya >= 0:
			for e in AudioServer.get_bus_effect_count(dunya):
				AudioServer.add_bus_effect(i, AudioServer.get_bus_effect(dunya, e))
	for n in [&"Dunya", &"Adim"]:
		if AudioServer.get_bus_index(n) >= 0:
			AudioServer.set_bus_send(AudioServer.get_bus_index(n), &"Efekt")
	var vm: GDScript = load("res://scripts/viewmodel.gd")
	if vm and vm.can_instantiate():  # not when a check loads us before the autoloads it needs
		var gun_bus: StringName = vm.gun_bus()
		AudioServer.set_bus_send(AudioServer.get_bus_index(gun_bus), &"Silahlar")  # our own gun, panned right
	# Master's own: night mode, mono, the pause muffle; switched in _apply_audio.
	var comp := AudioEffectCompressor.new()
	comp.attack_us = 2000.0
	comp.release_ms = 250.0
	comp.gain = 3.0
	var mono := AudioEffectStereoEnhance.new()
	mono.pan_pullout = 0.0  # both sides summed into the middle
	var muffle := AudioEffectLowPassFilter.new()
	muffle.cutoff_hz = PAUSE_MUFFLE_HZ
	for e in [comp, mono, muffle]:
		AudioServer.add_bus_effect(0, e)


func _master_effect(type: String) -> int:
	for e in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, e).is_class(type):
			return e
	return -1


func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, _db(values.master_vol))
	for n in BUSES:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(n), _db(values[BUSES[n]]))
	var comp := _master_effect("AudioEffectCompressor")
	AudioServer.set_bus_effect_enabled(0, comp, values.dynamic_range > 0)
	var c := AudioServer.get_bus_effect(0, comp) as AudioEffectCompressor
	c.threshold = [0.0, -14.0, -24.0][values.dynamic_range]
	c.ratio = [1.0, 3.0, 8.0][values.dynamic_range]
	AudioServer.set_bus_effect_enabled(0, _master_effect("AudioEffectStereoEnhance"), values.mono)
	set_paused_sound(false)
	if values.device in AudioServer.get_output_device_list():
		AudioServer.output_device = values.device
	for p in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		(p as AudioStreamPlayer3D).panning_strength = pan_strength()


## While the game stands paused the world is heard as through a wall.
func set_paused_sound(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(0, _master_effect("AudioEffectLowPassFilter"), on and values.pause_muffle)


static func _db(percent: float) -> float:
	return linear_to_db(maxf(percent / 100.0, 0.0001))


func pan_strength() -> float:
	return SPEAKER_PAN if values.output == 1 else 1.0


## How much a sound behind is turned down (0..1): real rear speakers need none.
func rear_cue() -> float:
	return 0.0 if values.output == 2 else values.rear_cue / 100.0


func _on_node_added(n: Node) -> void:
	if n is AudioStreamPlayer3D:
		(n as AudioStreamPlayer3D).panning_strength = pan_strength()
	if n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D:
		_sort_sound.call_deferred(n)  # after the node's own _ready has picked its bus
	elif n is WorldEnvironment or n is Light3D or n is Camera3D:
		_remember_built(n)  # now, before anything (scripts/graphics.gd) switches it in its _ready
		_queue_graphics()


func _sort_sound(n: Variant) -> void:  # untyped: the node may be gone by now
	if not is_instance_valid(n) or n.get(&"bus") != &"Master":
		return
	var parent: Node = n.get_parent()
	var gun: bool = n.name in GUN_SOUNDS or (parent != null and parent.name == "Viewmodel")
	n.set(&"bus", &"Silahlar" if gun else &"Efekt")


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode: int = [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN][values.window_mode]
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_LIMITS[values.fps_limit]


func _queue_graphics() -> void:
	if not _graphics_queued:
		_graphics_queued = true
		apply_graphics.call_deferred()


## The hall's rendering. An effect switched on goes back to what the hall was built with (an
## effect the hall never had stays off); the lamps' shadows likewise.
func apply_graphics() -> void:
	_graphics_queued = false
	var vp := get_viewport()
	vp.scaling_3d_mode = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_FSR2][values.upscaler]
	vp.scaling_3d_scale = values.render_scale / 100.0
	var aa: int = values.antialias  # off, FXAA, MSAA 2x, MSAA 4x, MSAA 4x + FXAA, TAA
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X, Viewport.MSAA_DISABLED][aa]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 or aa == 4 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = aa == 5 and values.upscaler != 2  # FSR 2 does its own
	# The PS1 screen on (2026-11-03): the modern passes the old console never had go (screen-space
	# shading and reflections, light shafts, bloom), and shadows are coarse and hard: a sharp
	# 1080p-grade shadow edge crawls when drawn 270 lines tall.
	var psx: bool = values.psx > 0
	var atlas: int = mini(SHADOW_ATLAS[values.shadows], 2048) if psx else SHADOW_ATLAS[values.shadows]
	var soft: int = RenderingServer.SHADOW_QUALITY_HARD if psx else SOFT_SHADOWS[values.shadows]
	vp.positional_shadow_atlas_size = atlas
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	var root := get_tree().root
	for light: Light3D in root.find_children("*", "Light3D", true, false):
		if light is DirectionalLight3D or light.get_viewport() != vp:
			continue
		_remember_built(light)
		light.shadow_enabled = light.get_meta(&"built_shadow") and values.shadows > 0  # low: the moon alone
	PsxScreen.apply(PSX_LINES[values.psx], values.psx_fine)  # on, it draws the 3D small itself: scale, upscaler and smoothing step aside
	var envs: Array[Environment] = []
	for w: WorldEnvironment in root.find_children("*", "WorldEnvironment", true, false):
		if w.environment:
			envs.append(w.environment)
	for c: Camera3D in root.find_children("*", "Camera3D", true, false):
		if c.environment and not c.environment in envs:
			envs.append(c.environment)
	for env in envs:
		_remember_env(env)
		var built: Dictionary = env.get_meta(&"built")
		env.ssao_enabled = built.ssao and values.ssao and not psx
		env.ssil_enabled = built.ssil and values.ssil and not psx
		env.ssr_enabled = built.ssr and values.ssr and not psx
		env.volumetric_fog_enabled = built.fog and values.fog and not psx
		env.glow_enabled = built.glow and values.glow and not psx
		env.tonemap_exposure = built.exposure * values.brightness / 100.0


## What a light or an environment was built with, the first time it is seen.
func _remember_built(n: Node) -> void:
	if n is Light3D and not n.has_meta(&"built_shadow"):
		n.set_meta(&"built_shadow", (n as Light3D).shadow_enabled)
	elif n is WorldEnvironment and (n as WorldEnvironment).environment:
		_remember_env((n as WorldEnvironment).environment)
	elif n is Camera3D and (n as Camera3D).environment:
		_remember_env((n as Camera3D).environment)


func _remember_env(env: Environment) -> void:
	if not env.has_meta(&"built"):
		env.set_meta(&"built", {"ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "ssr": env.ssr_enabled,
			"fog": env.volumetric_fog_enabled, "glow": env.glow_enabled, "exposure": env.tonemap_exposure})
