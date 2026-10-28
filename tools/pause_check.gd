extends SceneTree
## Headless check for the pause menu (scripts/pause_menu.gd) and the settings behind it
## (scripts/settings.gd):
##   Godot.exe --headless --path . -s res://tools/pause_check.gd
## Esc opens it and stops a solo game, Esc closes it. On every page, at four screen sizes: every
## text fits its box (every option a choice can show, too), no two texts overlap, nothing leaves
## the screen, the hover help fits its strip. Then the settings do what they say: buses, mono,
## night mode, 3D panning, presets, shadows, the camera, a key swap, the file, the reset.

const RESOLUTIONS := [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(2560, 1080)]

var settings: Node
var menu: CanvasLayer


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	settings = root.get_node("Settings")
	settings.save_path = "user://settings_check.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.save_path))
	for c in settings.get_children():
		if c is CanvasLayer and c.has_method("open"):
			menu = c
	assert(menu != null, "Settings made the pause menu")

	# Esc: open, the game stops (solo); Esc again: closed, running.
	_esc()
	await _frames(3)
	assert(menu.is_open and menu.visible and paused, "Esc opens the menu and stops the solo game")
	_esc()
	await _frames(3)
	assert(not menu.is_open and not paused, "Esc closes it and the game runs on")

	menu.open()
	var pages: int = menu.PAGES.size()
	for res in RESOLUTIONS:
		root.size = res
		menu._fit()
		for p in pages:
			menu._show_page(p)
			await _frames(3)
			_check_page(res, p)
	print("layout ok: %d pages at %d sizes" % [pages, RESOLUTIONS.size()])
	_check_help()

	await _check_settings(main)
	menu.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.save_path))
	print("pause_check OK")
	quit()


func _esc() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)


# --- layout ------------------------------------------------------------------------------------

func _check_page(res: Vector2i, p: int) -> void:
	var where := "%s %s" % [res, menu.PAGES[p]]
	var texts: Array[Control] = []
	for c in menu.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		if (ctl is Label or ctl is Button) and ctl.get(&"text") != "":
			texts.append(ctl)
	assert(texts.size() > 10, "%s: texts found" % where)
	var screen := Rect2(Vector2.ZERO, Vector2(res)).grow(0.5)
	for c in texts:
		var label: String = c.get(&"text")
		var names: Array = c.get_meta(&"names", [label])
		for n in names:
			var room := _room(c)
			assert(_text_w(c, n) <= room + 0.5, "%s: \"%s\" fits (%.0f of %.0f px)" % [where, n, _text_w(c, n), room])
		if not (c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF):
			assert(c.get_combined_minimum_size().y <= c.size.y + 0.5, "%s: \"%s\" fits in height" % [where, label])
		var r := c.get_global_rect()
		var scroll := _scroll_of(c)
		if scroll:
			var clip := scroll.get_global_rect().grow(0.5)
			assert(r.position.x >= clip.position.x and r.end.x <= clip.end.x, "%s: \"%s\" stays inside its page across" % [where, label])
		else:
			assert(screen.encloses(r), "%s: \"%s\" on screen (%s)" % [where, label, r])
	for i in texts.size():
		for j in range(i + 1, texts.size()):
			var a := texts[i]
			var b := texts[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var ra := _seen(a).grow(-1.0)
			var rb := _seen(b).grow(-1.0)
			if ra.has_area() and rb.has_area():
				assert(not ra.intersects(rb), "%s: \"%s\" and \"%s\" overlap" % [where, a.get(&"text"), b.get(&"text")])


## The part of `c` on screen: a row scrolled past its page is cut off there, not drawn over the strip.
func _seen(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var scroll := _scroll_of(c)
	return r.intersection(scroll.get_global_rect()) if scroll else r


## Width the text may take inside `c` (its box's padding off), in the control's own px.
func _room(c: Control) -> float:
	var style := c.get_theme_stylebox(&"normal")
	return c.size.x - (style.get_minimum_size().x if style else 0.0)


func _text_w(c: Control, text: String) -> float:
	var font := c.get_theme_font(&"font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size(&"font_size")).x


func _scroll_of(c: Node) -> ScrollContainer:
	var n := c.get_parent()
	while n:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null


## Every row's help fits the strip under the page in two lines.
func _check_help() -> void:
	var info: Label = menu._info
	for row in menu.find_children("*", "PanelContainer", true, false):
		if row.has_meta(&"info"):
			info.text = row.get_meta(&"info")
			assert(info.get_line_count() <= 2, "help in two lines: \"%s\" (%d)" % [info.text, info.get_line_count()])
	print("help strip ok")


# --- settings ----------------------------------------------------------------------------------

func _check_settings(main: Node) -> void:
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 0.05
	settings.set_value("master_vol", 50)
	assert(near.call(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "master at half")
	for n in ["Silahlar", "Efekt", "Ambiyans"]:
		assert(AudioServer.get_bus_index(n) >= 0, "bus " + n)
	var gun := AudioServer.get_bus_index(&"Silah")  # viewmodel.gd GUN_BUS: our own gun, panned right
	assert(AudioServer.get_bus_effect_count(gun) == 2 and AudioServer.get_bus_send(gun) == &"Silahlar", "our gun's bus keeps its effects, under Silahlar")
	settings.set_value("ambience_vol", 0)
	assert(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambiyans")) < -60.0, "ambience slider at 0 is silent")
	assert(AudioServer.get_bus_send(AudioServer.get_bus_index("Dunya")) == &"Efekt", "the hall's sounds under Efekt")
	assert(AudioServer.get_bus_send(AudioServer.get_bus_index("AmbiyansYanki")) == &"Ambiyans", "the lamp hum under Ambiyans")
	var amb: Node = main.get_node("Ambience")
	assert(amb._outside[0].bus == &"Ambiyans" and amb.events[0].player.bus == &"Ambiyans" and amb._hum.bus == &"AmbiyansYanki", "ambience on its buses")
	var on_master := root.find_children("*", "AudioStreamPlayer3D", true, false).filter(func(p: AudioStreamPlayer3D) -> bool: return p.bus == &"Master")
	assert(on_master.is_empty(), "no 3D sound left on Master: %s" % [on_master.map(func(p: Node) -> String: return str(p.get_path()))])
	var mono: int = settings._master_effect("AudioEffectStereoEnhance")
	settings.set_value("mono", true)
	assert(AudioServer.is_bus_effect_enabled(0, mono), "mono on")
	settings.set_value("dynamic_range", 2)
	assert(AudioServer.is_bus_effect_enabled(0, settings._master_effect("AudioEffectCompressor")), "night mode squeezes")
	settings.set_value("output", 1)
	assert(near.call(amb._outside[0].panning_strength, settings.SPEAKER_PAN), "speakers: softer panning")
	settings.set_value("output", 2)
	assert(settings.rear_cue() == 0.0, "surround: no rear cue, the rear speakers say it")
	print("audio ok")

	var env: Environment = main.get_node("Arena/WorldEnvironment").environment
	var lamps := func() -> int: return main.get_node("Arena").find_children("*", "Light3D", true, false).filter(func(l: Light3D) -> bool: return not l is DirectionalLight3D and l.shadow_enabled).size()
	settings.set_value("preset", 0)
	await _frames(2)
	assert(not env.ssao_enabled and not env.volumetric_fog_enabled and near.call(root.get_viewport().scaling_3d_scale, 0.7), "low preset: effects off, 70 %")
	assert(lamps.call() == 0, "low preset: the lamps cast no shadow")
	settings.set_value("ssao", true)
	await _frames(2)
	assert(env.ssao_enabled and settings.value("preset") == settings.CUSTOM, "one effect on by hand: the preset is Özel")
	settings.set_value("preset", 2)
	await _frames(2)
	assert(env.ssao_enabled and env.volumetric_fog_enabled and env.ssr_enabled and lamps.call() > 0, "high preset: as the hall was built")
	settings.set_value("brightness", 150)
	await _frames(2)
	assert(near.call(env.tonemap_exposure, env.get_meta(&"built").exposure * 1.5), "brightness")
	print("graphics ok: %d lamp shadows on high" % lamps.call())

	menu.close()  # the camera only follows while the game runs
	settings.set_value("fov", 90)
	await _frames(3)
	var cam: Camera3D = main.get_node("Player/Head/Camera3D")
	assert(near.call(cam.fov, 90.0), "the camera takes the field of view (%.1f)" % cam.fov)
	menu.open()

	var jump_key: String = settings.bind_text("jump")
	var sprint_ev: InputEvent = InputMap.action_get_events("sprint")[0]
	var other: String = settings.rebind("jump", sprint_ev)
	assert(other == "sprint" and settings.bind_text("sprint") == jump_key, "jump onto sprint's key: they swap")
	print("keys ok: jump %s, sprint %s" % [settings.bind_text("jump"), settings.bind_text("sprint")])

	var saved: Dictionary = settings.values.duplicate()
	settings.values.fov = 61
	settings.load_file()
	assert(settings.values == saved, "the file gives everything back")
	settings.reset(settings.DEFAULTS.keys(), true)
	assert(settings.bind_text("jump") == jump_key and settings.value("fov") == 75, "reset: defaults and the keys back")
	print("file and reset ok")
	var bad := ConfigFile.new()  # an old or hand-edited file: out of every list and range
	bad.set_value("settings", "shadows", 9)
	bad.set_value("settings", "master_vol", 100000)
	bad.set_value("settings", "sensitivity", -1.0)
	bad.save(settings.save_path)
	settings.load_file()
	assert(settings.value("shadows") == 3 and settings.value("master_vol") == 100 and is_equal_approx(settings.value("sensitivity"), 0.1), "a bad file is clamped")
	settings.reset(settings.DEFAULTS.keys(), true)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
