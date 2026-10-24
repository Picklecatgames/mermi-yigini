extends SceneTree
## Headless check of the Clone opening (scripts/clone_fx.gd) and its preview scene:
##   Godot.exe --headless --path . -s res://tools/clone_check.gd
## Lies on the top, rises and stands up in silence, the sound in once it shakes, shakes down to nothing by the silence,
## shows the twin only in the glitches, and is two rounds GAP apart once the split settles.

const FX := preload("res://scripts/clone_fx.gd")
const DROP := preload("res://scripts/clone_fx_drop.gd")


func _initialize() -> void:
	var ok := true
	var demo: Node = load("res://scenes/clone_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	demo._take(0)
	var fx: Node3D = demo._fx
	var p: Array[Transform3D] = fx.pose(0.0)
	ok = _expect(absf(p[0].origin.y - 0.5 * FX.SCALE) < 0.001, "starts lying on the top") and ok
	p = fx.pose(FX.RISE - 0.001)
	ok = _expect(absf(p[0].origin.y - FX.HOVER) < 0.002, "hovers once it has risen") and ok
	ok = _expect(p[0].basis.x.normalized().dot(Vector3.UP) > 0.99, "stands tip up") and ok
	ok = _expect(FX.SOUND_AT > FX.RISE, "the sound waits for the shake") and ok
	fx.play()
	await create_timer(FX.SOUND_AT - 0.2).timeout
	ok = _expect(not fx._sound.playing, "silent while it rises") and ok
	await create_timer(0.4).timeout
	ok = _expect(fx._sound.playing, "sound in once it shakes") and ok
	var wide := _swing(fx, FX.RISE + 0.2, FX.RISE + 0.4)
	var narrow := _swing(fx, FX.STOP - 0.1, FX.STOP)
	ok = _expect(narrow < wide * 0.2, "the shake closes in (%.4f -> %.4f m)" % [wide, narrow]) and ok
	ok = _expect(fx.pose(FX.STOP + 0.01)[0].origin.is_equal_approx(Vector3(0, FX.HOVER, 0)), "still in the silence") and ok
	ok = _expect(not fx._glitching(1.5) and fx._glitching(FX.GLITCHES[0] + 0.01), "twin shows only in a glitch") and ok
	p = fx.pose(FX.SPLIT + 1.0)
	var apart := p[1].origin.x - p[0].origin.x
	ok = _expect(absf(apart - FX.GAP) < 0.002, "two rounds %.3f m apart" % apart) and ok
	p = fx.pose(FX.END)
	var down := absf(p[0].basis.x.normalized().y) < 0.05 and absf(p[1].basis.x.normalized().y) < 0.05
	ok = _expect(down and absf(p[1].origin.y - 0.5 * FX.SCALE) < 0.0005, "dropped, both lying on the top") and ok
	var hit: float = FX.RELEASE + FX.LAGS[1] + FX.FALL
	ok = _expect(absf(fx.pose(hit)[1].origin.y - FX.REST) < 0.001, "second one's base knock lands as it touches") and ok
	ok = _expect(absf(FX.SOUND.get_length() - 6.0) < 0.05, "sound is %.2f s" % FX.SOUND.get_length()) and ok

	print(" take 2 (clone_fx_drop.gd):")
	demo._take(1)
	fx = demo._fx
	ok = _expect(not fx._b.visible and absf(fx.pose(0.0)[0].origin.y - 0.5 * DROP.SCALE) < 0.002, "one, lying on the top") and ok
	p = fx.pose(DROP.RISE - 0.001)
	ok = _expect(absf(p[0].origin.y - DROP.HOVER) < 0.001 and p[0].basis.x.normalized().dot(Vector3.UP) > 0.99, "up and hovering, in silence") and ok
	p = fx.pose(DROP.KICK_1 + 0.06)
	ok = _expect(p[0].origin.x < -0.015 and p[0].origin.y > DROP.HOVER + 0.01, "first bass: up left") and ok
	p = fx.pose(DROP.KICK_2 + 0.06)
	ok = _expect(p[0].origin.x > 0.015 and p[0].origin.y > DROP.HOVER + 0.01, "second bass: up right") and ok
	p = fx.pose(DROP.SUB - 0.001)
	ok = _expect(p[1].origin.x - p[0].origin.x > 0.1 * DROP.GAP, "split before the sub bass") and ok
	p = fx.pose(DROP.SUB + 1.0)
	ok = _expect(absf(p[1].origin.x - p[0].origin.x - DROP.GAP) < 0.004, "thrown GAP apart") and ok
	p = fx.pose(DROP.END)
	var flat := absf(p[0].basis.x.normalized().y) < 0.05 and absf(p[1].basis.x.normalized().y) < 0.05
	ok = _expect(flat and absf(p[0].origin.y - 0.5 * DROP.SCALE) < 0.0005, "both lying on the top") and ok
	ok = _expect(p[0].origin.distance_to(p[1].origin) > 0.06, "not on top of each other") and ok
	ok = _expect(DROP.RELEASE - DROP.SOUND_AT > DROP.SOUND.get_length() - 1.0, "let go as the sound ends") and ok
	fx.play()
	await create_timer(DROP.SOUND_AT - 0.2).timeout
	ok = _expect(not fx._sound.playing and not fx._b.visible, "silent and one while it rises") and ok
	await create_timer(DROP.SUB - DROP.SOUND_AT + 0.3).timeout
	ok = _expect(fx._sound.playing and fx._b.visible, "sound on, two after the split") and ok
	demo.queue_free()
	await process_frame
	print("clone_check: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


## Widest the round's middle gets from the hover point between `from` and `to` s.
func _swing(fx: Node3D, from: float, to: float) -> float:
	var most := 0.0
	for i in 200:
		var t := lerpf(from, to, i / 199.0)
		if not fx._glitching(t):
			most = maxf(most, fx.pose(t)[0].origin.distance_to(Vector3(0, FX.HOVER, 0)))
	return most


func _expect(cond: bool, what: String) -> bool:
	print("  ", "ok   " if cond else "FAIL ", what)
	return cond
