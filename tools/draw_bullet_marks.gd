extends SceneTree
## Draws the bullet-mark decals scripts/impacts.gd loads (materials/env/decals/bullet_mark_*.png),
## a few variants per surface. Re-run after changing them:
##   Godot.exe --headless --path . -s res://tools/draw_bullet_marks.gd
## then let the editor (or --import) pick the PNGs up.

const MARK_CONCRETE := 0
const MARK_BURLAP := 1
const MARK_STEEL := 2
const MARK_VARIANTS := 4
const MARK_PX := 128
const OUT := "res://materials/env/decals/bullet_mark_%d_%d.png"


func _initialize() -> void:
	for kind in 3:
		for v in MARK_VARIANTS:
			var img := _draw_mark(kind, kind * 100 + v)
			img.clear_mipmaps()
			img.save_png(ProjectSettings.globalize_path(OUT % [kind, v]))
	print("bullet marks drawn")
	quit()


## Bullet marks (MARK_PX square, centred, transparent outside):
## - concrete: a dark pit in a ragged ring of freshly chipped, lighter concrete, hairline cracks
##   running out of it and a faint dust halo;
## - burlap: a small ragged hole with frayed fibres and a scorched brown ring;
## - steel: a flattened lead smear (dark core, grey disc) with thin splash rays and droplets
##   thrown out round it, the way a round leaves paint and lead on a steel plate.
func _draw_mark(kind: int, seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var img := Image.create(MARK_PX, MARK_PX, false, Image.FORMAT_RGBA8)
	var px := 2.0 / MARK_PX  # one pixel in -1..1 units, for soft edges
	# a ragged outline: radius wobbles with angle
	var wob: Array[Vector3] = []  # frequency, phase, amount
	var rough: float = [1.0, 1.6, 0.45][kind]  # lead spreads round; burlap tears ragged
	for f in [3, 5, 8, 13, 21, 34]:
		wob.append(Vector3(f, rng.randf() * TAU, rng.randf_range(0.04, 0.12) * rough * 5.0 / (f + 2.0)))
	var rays: Array[Vector3] = []  # angle, length, half width (in -1..1 units)
	var ray_count: int = [6, 10, 46][kind]
	var ray_alpha: Array[float] = []
	for i in ray_count:
		var length := rng.randf_range(0.45, 0.98)
		var width := rng.randf_range(0.008, 0.02)
		match kind:
			MARK_BURLAP:
				length = rng.randf_range(0.25, 0.42)
				width = rng.randf_range(0.012, 0.035)
			MARK_STEEL:  # a fine spray, mostly short, a few long
				length = 0.3 + pow(rng.randf(), 2.2) * 0.65
				width = rng.randf_range(0.004, 0.014)
		rays.append(Vector3(rng.randf() * TAU, length, width))
		ray_alpha.append(rng.randf_range(0.35, 0.9) if kind == MARK_STEEL else 1.0)
	var drops: Array[Vector3] = []  # x, y, radius
	if kind == MARK_STEEL:
		for i in 7:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.35, 0.85)
			drops.append(Vector3(cos(a) * r, sin(a) * r, rng.randf_range(0.007, 0.016)))
	for y in MARK_PX:
		for x in MARK_PX:
			var u := (x + 0.5) * px - 1.0
			var w := (y + 0.5) * px - 1.0
			var r := sqrt(u * u + w * w)
			var ang := atan2(w, u)
			var edge := 1.0
			for o in wob:
				edge += sin(ang * o.x + o.y) * o.z
			var grain := rng.randf_range(-0.04, 0.04)
			var c := Color(0, 0, 0, 0)
			# rays and cracks: distance across the line, fading toward its tip
			var ray := 0.0
			for k in rays.size():
				var ry := rays[k]
				var along := u * cos(ry.x) + w * sin(ry.x)
				if along <= 0.0 or along > ry.y:
					continue
				var across := absf(-u * sin(ry.x) + w * cos(ry.x))
				var half := ry.z * (1.0 - along / ry.y)
				ray = maxf(ray, (1.0 - smoothstep(half - px, half + px, across)) * pow(1.0 - along / ry.y, 0.6) * ray_alpha[k])
			match kind:
				MARK_CONCRETE:
					var pit := 1.0 - smoothstep(0.13 * edge - px, 0.13 * edge + px, r)
					var chip := 1.0 - smoothstep(0.4 * edge - px, 0.4 * edge + px, r)
					var halo := clampf(1.0 - r / 0.95, 0.0, 1.0) * 0.18
					c = Color(0.62 + grain, 0.6 + grain, 0.57 + grain, maxf(halo, chip * 0.85))
					c = c.lerp(Color(0.08, 0.075, 0.07, 1.0), maxf(ray * 0.75, 0.0) * (1.0 - chip))
					if ray > 0.0 and chip < 1.0:
						c.a = maxf(c.a, ray * 0.7)
					c = c.lerp(Color(0.04, 0.04, 0.04, 1.0), pit)
					# the chipped ring darkens a little toward the pit
					c = c.lerp(Color(0.32, 0.31, 0.3, c.a), chip * (1.0 - pit) * clampf(1.0 - (r - 0.13) / 0.27, 0.0, 1.0) * 0.6)
				MARK_BURLAP:
					var hole := 1.0 - smoothstep(0.2 * edge - px, 0.2 * edge + px, r)
					var scorch := clampf(1.0 - (r - 0.15) / (0.4 * edge), 0.0, 1.0)
					c = Color(0.13 + grain * 0.5, 0.085, 0.045, pow(scorch, 1.4) * 0.85)
					c.a = maxf(c.a, ray * 0.8)
					c = c.lerp(Color(0.015, 0.01, 0.008, 1.0), hole)
				MARK_STEEL:
					var core := 1.0 - smoothstep(0.09 * edge - px, 0.09 * edge + px, r)
					var smear := 1.0 - smoothstep(0.24 * edge - 2.0 * px, 0.24 * edge + 2.0 * px, r)
					grain *= 2.0  # lead is speckled
					var drop := 0.0
					for d in drops:
						var dr := Vector2(u - d.x, w - d.y).length()
						drop = maxf(drop, 1.0 - smoothstep(d.z - px, d.z + px, dr))
					var lead := Color(0.5 + grain, 0.5 + grain, 0.52 + grain, 1.0)
					c = Color(lead, maxf(smear, maxf(ray * 0.9, drop * 0.85)))
					# the smear is lighter at its rim, where the lead spread thin
					c = c.lerp(Color(0.66, 0.66, 0.68, c.a), smear * clampf((r - 0.09) / 0.15, 0.0, 1.0) * 0.5)
					c = c.lerp(Color(0.2, 0.2, 0.21, 1.0), core)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return img
