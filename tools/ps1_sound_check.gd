extends SceneTree
## Headless check for the PS1 sound rules (scripts/ps1_sound.gd, data/ses_duzeni.json): the buses
## are made with their effects and sends, every kind's bus resolves, a variant never comes twice in
## a row, pitch and level wander only inside the kind's range, a kind holds to its own voices and
## all of them to the chip's 24, and a bed loops:
##   Godot.exe --headless --path . -s res://tools/ps1_sound_check.gd

var _fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	await process_frame

	# Buses: Settings made them at start (settings.gd _make_buses -> Ps1Sound.buses()).
	for b in Ps1Sound.BUSES:
		var i := AudioServer.get_bus_index(b[0])
		_ok(i >= 0, "bus %s exists" % b[0])
		if i >= 0:
			_ok(AudioServer.get_bus_send(i) == b[1], "%s sends into %s" % [b[0], b[1]])
	var far := AudioServer.get_bus_index(&"PsUzak")
	_ok(AudioServer.get_bus_effect(far, 0) is AudioEffectLowPassFilter and AudioServer.get_bus_effect(far, 1) is AudioEffectReverb, "PsUzak: low-pass, then the hall")
	_ok(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Arayuz")) == 0, "Arayuz is dry")
	var t: Dictionary = Ps1Sound.table()
	_ok(int(t.voices) == 24, "the PS1 chip's 24 voices")
	for k in t.kinds:
		var bus := Ps1Sound.bus_of(k)
		_ok(AudioServer.get_bus_index(bus) >= 0, "%s plays on a bus that exists (%s)" % [k, bus])
		if bus != StringName(t.kinds[k].bus):
			print("  %s: its bus %s isn't made yet here, plays on %s" % [k, t.kinds[k].bus, bus])
		if not DirAccess.dir_exists_absolute(Ps1Sound.ROOT + t.kinds[k].dir):
			print("  %s: no folder yet (assets/%s), made with its first file" % [k, t.kinds[k].dir])

	# Variants: gore/flesh_01..08 and the folder as a whole.
	var flesh := Ps1Sound.files("gore/flesh")
	_ok(flesh.size() >= 5, "gore/flesh has its variants (%d)" % flesh.size())
	_ok(Ps1Sound.files("gore").size() > flesh.size(), "gore alone is the whole folder")
	_ok(Ps1Sound.files("gore/nothing").is_empty(), "an unknown prefix finds nothing")
	var k: Dictionary = Ps1Sound.kind("gore")
	var last := ""
	var repeats := 0
	for i in 40:
		var p: AudioStreamPlayer3D = Ps1Sound.play("gore/flesh", world, Vector3(i, 0, 0))
		var path: String = p.stream.resource_path
		repeats += int(path == last)
		last = path
		_ok(absf(p.pitch_scale - 1.0) <= float(k.perde) + 0.0001, "pitch inside ±%s" % k.perde)
		_ok(absf(p.volume_db) <= float(k.duzey) + 0.0001, "level inside ±%s dB" % k.duzey)
		_ok(p.bus == &"PsAcik", "gore on PsAcik")
	_ok(repeats == 0, "never the same flesh twice in a row")
	_ok(Ps1Sound.sounding("gore") <= int(k.ses), "gore holds to its %d voices (%d)" % [k.ses, Ps1Sound.sounding("gore")])
	await process_frame

	# All kinds together: never past 24.
	for i in 12:
		Ps1Sound.play("zombi/groan", world, Vector3.ZERO)
		Ps1Sound.play("zombi/death", world, Vector3.ZERO)
		Ps1Sound.play("gore/burst", world, Vector3.ZERO)
		Ps1Sound.play("atolye/electric_zap", world, Vector3.ZERO)
		Ps1Sound.play("ortam_olay/bigowl", world, Vector3.ZERO)
		Ps1Sound.play("arayuz/purchase", root)
		Ps1Sound.play("ozel/scream", world)
	print("sounding: %d (zombi %d, gore %d, atolye %d, arayuz %d)" % [Ps1Sound.sounding(), Ps1Sound.sounding("zombi"), Ps1Sound.sounding("gore"), Ps1Sound.sounding("atolye"), Ps1Sound.sounding("arayuz")])
	_ok(Ps1Sound.sounding() <= 24, "never past the chip's 24 voices")
	_ok(Ps1Sound.sounding("zombi") <= 8, "zombi holds to 8")
	await process_frame
	var flat := root.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer and n.bus == &"Arayuz")
	_ok(flat.size() >= 1, "a sound under a plain Node plays flat")

	# A bed loops.
	var bed := Ps1Sound.bed("ortam_yatak/night_outside", world)
	_ok(bed != null and bed.stream.get(&"loop") == true and bed.bus == &"Ambiyans", "a bed loops on Ambiyans")

	print("ps1_sound_check: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + what)
