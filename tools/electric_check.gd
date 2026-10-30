extends SceneTree
## Headless check of the Electric round's build on the bench (scripts/electric_fx.gd) and its
## preview scene:
##   Godot.exe --headless --path . -s res://tools/electric_check.gd
## Starts as a plain round lying on the top and stands up; spool, winding, rings, reactor and nose
## come on in order, each ending where it belongs; the plain bullet is gone before the reactor
## comes; the Tesla coil charges up to the zap, the arc flickers, the reactor stays lit after.

const FX := preload("res://scripts/electric_fx.gd")


func _initialize() -> void:
	var ok := true
	var demo: Node = load("res://scenes/electric_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	var fx: Node3D = demo._fx
	ok = _expect(fx.tesla != null, "the demo hands it the bench's Tesla coil") and ok
	ok = _expect(fx._parts.values().all(func(n): return n != null), "the model has every part") and ok
	var p: Transform3D = fx.round_pose(0.0)
	ok = _expect(absf(p.origin.y - FX.R) < 0.001 and absf(p.basis.y.normalized().y) < 0.01, "starts lying on the top") and ok
	ok = _expect(fx.round_pose(FX.RISE.x - 0.01).is_equal_approx(p), "lies still a moment first") and ok
	p = fx.round_pose(FX.RISE.y)
	ok = _expect(p.basis.y.normalized().dot(Vector3.UP) > 0.99 and absf(p.origin.y - FX.HOVER) < 0.002, "stands up, hovering") and ok
	ok = _expect(fx.part("CaseWhole", FX.CUT - 0.01) != null and fx.part("CaseLow", FX.CUT - 0.01) == null, "whole until the cut") and ok
	ok = _expect(fx.part("CaseWhole", FX.CUT) == null and fx.part("CaseLow", FX.CUT) != null and fx.part("CaseHigh", FX.CUT) != null, "in pieces after it") and ok
	ok = _expect(fx.cutting(FX.CUT - 0.01) > 0.9 and fx.cutting(FX.RISE.y) == 0.0, "the cut lines glow just before") and ok
	ok = _expect(absf(fx.opened(FX.OPEN.y) - FX.GAP) < 0.0005 and fx.part("Tip", FX.OPEN.y).origin.y == fx.part("CaseHigh", FX.OPEN.y).origin.y, "top half and bullet open up together") and ok
	ok = _expect(fx.part("CaseMid", FX.CUT + 0.5).origin.x > 0.05 and fx.part("CaseMid", FX.CUT + 1.0) == null, "the slice flies out and is gone") and ok
	ok = _expect(fx.opened(FX.CLOSE.y) == 0.0 and FX.SPOOL.y < FX.CLOSE.x, "spool is in before the top closes on it") and ok
	ok = _expect(fx.part("Spool", FX.SPOOL.x - 0.01) == null and fx.part("Spool", FX.SPOOL.y + 0.3).origin.length() < 0.0005, "spool slides on and sits") and ok
	ok = _expect(fx.coil(FX.WIND.x) == 0.0 and absf(fx.coil((FX.WIND.x + FX.WIND.y) / 2.0) - 0.5) < 0.01 and fx.coil(FX.WIND.y) == 1.0, "copper winds on over WIND") and ok
	ok = _expect(fx.part("RingLow", FX.RING_LOW.x + 0.05).origin.y < 0.0 and fx.part("RingHigh", FX.RING_HIGH.x + 0.05).origin.y > 0.0, "rings come from below and from above") and ok
	ok = _expect(fx.part("RingLow", FX.RING_LOW.y + 0.5).origin.length() < 0.0001 and fx.part("RingHigh", FX.RING_HIGH.y + 0.5).origin.length() < 0.0001, "both rings clicked into place") and ok
	var past := 0.0  # how far any part ever goes beyond where it stops
	for i in 400:
		var t: float = FX.SPOOL.x + (FX.END - FX.SPOOL.x) * i / 399.0
		past = maxf(past, fx.part("Spool", t).origin.x if fx.part("Spool", t) else 0.0)
		for n in ["Reactor", "RingHigh"]:
			var at = fx.part(n, t)
			past = maxf(past, -at.origin.y if at else 0.0)
		var low = fx.part("RingLow", t)
		past = maxf(past, low.origin.y if low else 0.0)
	ok = _expect(past < 0.00001, "nothing comes in past its place (%.5f m)" % past) and ok
	ok = _expect(fx.part("Tip", FX.LIFT.y + 0.01) == null and FX.REACTOR.x > FX.LIFT.y, "the plain bullet is gone before the reactor comes") and ok
	var n0: Transform3D = fx.part("Nose", FX.NOSE.y)
	var n1: Transform3D = fx.part("Nose", FX.PRESS.y)
	ok = _expect(absf(n0.origin.y - FX.CATCH) < 0.0001 and fx.part("Nose", FX.PRESS.x).origin.y == n0.origin.y, "nose catches just proud, no hanging") and ok
	ok = _expect(n1.origin.length() < 0.0001 and n1.basis.is_equal_approx(Basis.IDENTITY) and FX.PRESS.x - FX.NOSE.y < 0.2, "then a short push seats it") and ok
	ok = _expect(fx.charge(FX.CHARGE) == 0.0 and fx.charge(FX.ZAP - 0.01) > 0.95 and fx.charge(FX.ZAP + FX.ARC + 0.31) == 0.0, "the coil charges up to the first strike, spent over them") and ok
	ok = _expect(fx.arcing(FX.ZAP) and not fx.arcing(FX.ZAP + FX.ARC + 0.01), "the strikes flicker for ARC") and ok
	var hits := 0
	for i in 400:
		var t: float = FX.ZAP - 0.1 + (FX.ARC + 0.2) * i / 399.0
		if fx.strike(t) >= 0 and (i == 0 or fx.strike(FX.ZAP - 0.1 + (FX.ARC + 0.2) * (i - 1) / 399.0) != fx.strike(t)):
			hits += 1
	ok = _expect(hits == 4, "four strikes (%d)" % hits) and ok
	var charge_len: float = FX.SOUNDS.charge.get_length()
	ok = _expect(absf(charge_len - (FX.ZAP - FX.CHARGE)) < 0.05, "the first strike lands on the charge sound's peak (%.2f s)" % charge_len) and ok
	var b0: Vector3 = fx.ball(FX.CHARGE + 0.1)
	var y0: float = lerpf(fx._coil_y.x, fx._coil_y.y, FX.RING_H[0])
	ok = _expect(absf(b0.y - y0) < 0.002 and absf(Vector2(b0.x, b0.z).distance_to(fx._axis) - FX.RING_RAD[0] * FX.COIL_SCALE * 1.12) < 0.002, "the ball starts round the lowest, widest ring") and ok
	var spin := func(a: float, b: float) -> float: return (fx._turn(FX.CHARGE + b) - fx._turn(FX.CHARGE + a)) / (b - a)
	var w0: float = spin.call(0.2, 1.0)
	var w1: float = spin.call(3.5, 4.5)
	var w2: float = spin.call(5.7, 6.5)
	ok = _expect(w0 > 0.0 and w1 < 0.0 and w2 > 0.0, "clockwise, then the other way, then clockwise again (%.1f, %.1f, %.1f rad/s)" % [w0, w1, w2]) and ok
	ok = _expect(absf(w2) > absf(w0) * 4.0 and absf(w1) > absf(w0), "faster on every ring, with the sound") and ok
	ok = _expect(fx.on_ring(FX.CHARGE + 4.0) == 1 and fx.on_ring(FX.CHARGE + 6.0) == 2, "up a ring at a time") and ok
	var last: Vector3 = fx.ball(FX.ZAP - 0.001)
	ok = _expect(last.distance_to(fx._tesla_top) < 0.005 and fx.ball(FX.ZAP) == null and fx.arcing(FX.ZAP), "it reaches the tip as the first strike leaves") and ok
	ok = _expect(fx.shock(FX.ZAP - 0.01) == 0.0 and fx.shock(FX.ZAP + 0.05) == 1.0 and fx.shock(FX.ZAP + FX.ARC + 1.5) < 0.05, "the round lights up with each strike, then calms") and ok
	ok = _expect(fx.part("Spool", FX.SPOOL.y) != null, "the bobbin is there") and ok
	ok = _expect(fx.darkness(FX.CHARGE - 1.0) == 0.0 and fx.darkness(FX.ZAP) == 1.0 and fx.darkness(FX.END) == 0.0, "the room goes dark for the charge and comes back") and ok
	ok = _expect(fx.glow(FX.ZAP - 0.1) == 0.0 and fx.glow(FX.END) > 0.5, "the reactor is dark, then stays lit") and ok
	p = fx.round_pose(FX.END)
	ok = _expect(absf(p.origin.y) < 0.0005 and p.basis.y.normalized().dot(Vector3.UP) > 0.99, "set down standing on the top") and ok
	fx.play()
	await create_timer(FX.RISE.x + 0.3).timeout
	ok = _expect(fx._snd.round_0.playing and fx._snd.round_0.stream == FX.SOUNDS.rise, "the rise sound plays as it lifts") and ok
	await create_timer(FX.SPOOL.y - FX.RISE.x - 0.3).timeout
	ok = _expect(fx._whooshes[0].playing and fx._whooshes[0].get_parent() == fx._parts.Spool, "the spool whooshes in, the sound riding on it") and ok
	await create_timer(FX.CLOSE.y - FX.SPOOL.y).timeout
	var mount := (fx._snd.values() as Array).any(func(p): return p.playing and p.stream == FX.SOUNDS.mount)
	ok = _expect(mount, "the crank sounds as the round closes on the spool") and ok
	ok = _expect(fx.zapping(FX.ZAPPING + 0.3) and not fx.zapping(FX.ZAPPING + 1.1) and FX.SETTLE.x > FX.ZAPPING + FX.ZAP_BURSTS[-1].y and FX.SOUNDS.zapping.get_length() < FX.SETTLE.x - FX.ZAPPING + 0.2, "it hangs crackling through the zapping sound's bursts, then is set down") and ok
	var swell: Array = FX.CUES.filter(func(c): return c[2] == "charge")[0]
	ok = _expect(swell[4] >= 1.5 and FX.WHOOSHES.all(func(w): return w[3] <= -12.0), "the charge swells in; the whooshes sit well under the rest") and ok
	ok = _expect(FX.SOUNDS.reactor.get_length() > 1.0 and FX.ZAP_PITCH.size() == FX.STRIKES.size(), "a pitch for every strike, a hum to loop") and ok
	print("ELECTRIC CHECK ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


func _expect(cond: bool, what: String) -> bool:
	print(("  ok   " if cond else "  FAIL ") + what)
	return cond
