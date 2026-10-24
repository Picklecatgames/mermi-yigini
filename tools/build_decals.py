# Wall and floor decals for tools/hall_dressing.gd. Spray-painted walls (2026-10-24: the tags read "drawn with a
# pen", clean and flat; the user wanted a real abandoned hall). From ambientCG GraffitiSet001's
# opacity map (CC0, 16 hand-styled tags as thin marker lines) each tag is repainted as spray:
#   tags   thicker soft-edged line, overspray haze and grains round it, now and then a second-colour
#          outline, paint runs down from its low edges;
#   throws bubble letters filled in (silver, white, pink...) under a dark outline, a drop shadow,
#          a few shine marks, uneven fill from the can's passes;
#   all    worn: chips flaked off, concrete pores the paint never reached, faded.
# Plus `buff_N` (grey paint rolled over old tags, the old ones bleeding through) and `scribble_N`
# (quick sprayed lines, arrows, crosses). Colours are baked in; the decal's alpha fades them.
# Floor: `litter_N` (dead leaves blown in, paper scraps, glass, butts, grit) and `puddle_N` with
# `puddle_N_orm` (standing water: dark, glassy in the middle, a damp rim).
# Range: `holes_N` (stray rounds through the plywood), `mould_N` (black mould and rot up a sheet's
# foot), `tile_gap_N` (a rubber mat pulled up, bare screed) and `brass_N` (spent cases kicked about).
# Run: python tools/build_decals.py   ->   assets/env/decals/graffiti/*.png (.gdignore'd; the
# arena build caches them as materials/env/decals/spray_*.res, delete those to redo).
import os
import cv2
import numpy as np

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets/env/decals/GraffitiSet001/GraffitiSet001_4K-PNG_Opacity.png")
OUT = os.path.join(ROOT, "assets/env/decals/graffiti")
N = 1024  # px per tag
rng = np.random.default_rng(24)

SILVER = (0.78, 0.79, 0.8)
BLACK = (0.05, 0.05, 0.055)
WHITE = (0.9, 0.89, 0.85)
RED = (0.75, 0.06, 0.05)
PINK = (0.92, 0.35, 0.62)
BLUE = (0.15, 0.4, 0.85)
SKY = (0.4, 0.7, 0.9)
LIME = (0.6, 0.85, 0.15)
ORANGE = (0.95, 0.45, 0.05)
YELLOW = (0.95, 0.8, 0.15)
PURPLE = (0.45, 0.2, 0.65)
MAROON = (0.4, 0.05, 0.08)

# Per atlas cell: style, then (line colour, outline colour or None) for tags,
# (fill, outline, shadow) for throws. Bubble letters (B5D, BUBO, Bout, BUBO) are throw-ups.
STYLE = {
    0: ("tag", BLACK, None), 1: ("tag", RED, None), 2: ("tag", SKY, BLACK), 3: ("throw", SILVER, BLACK, BLUE),
    4: ("throw", PINK, BLACK, None), 5: ("tag", WHITE, None), 6: ("throw", WHITE, RED, BLACK), 7: ("tag", ORANGE, BLACK),
    8: ("tag", LIME, None), 9: ("throw", SILVER, MAROON, BLACK), 10: ("tag", YELLOW, PURPLE), 11: ("tag", BLACK, None),
    12: ("tag", BLUE, WHITE), 13: ("tag", WHITE, BLACK), 14: ("tag", RED, None), 15: ("tag", PURPLE, None),
}


def fbm(shape, scale, octaves=5, seed_rng=rng):
    """Smooth value noise in 0..1, `scale` px for the coarsest octave."""
    h, w = shape
    out = np.zeros(shape, np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        s = max(2, int(max(h, w) / (scale / 2 ** o)))
        small = seed_rng.random((s, s)).astype(np.float32)
        out += cv2.resize(small, (w, h), interpolation=cv2.INTER_CUBIC) * amp
        total += amp
        amp *= 0.5
    out /= total
    return np.clip((out - out.mean()) / (out.std() * 3.0 + 1e-6) + 0.5, 0.0, 1.0)


def blur(a, sigma):
    return cv2.GaussianBlur(a, (0, 0), sigma)


def dilate(mask, r):
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    return cv2.dilate(mask, k)


def spray(mask, hard=1.4, haze=0.35, grains=1.0):
    """Coverage of a sprayed line: a soft core, a wide faint haze, loose grains round the edge."""
    m = mask.astype(np.float32)
    core = np.clip(blur(m, hard) * 1.25, 0, 1)
    halo = blur(m, 9.0) * haze
    near = blur(m, 14.0)
    dots = (rng.random(m.shape) < near * 0.12 * grains).astype(np.float32)
    dots = blur(dots, 0.7) * 2.0
    return np.clip(np.maximum(core, halo + dots * 0.6), 0, 1)


def fill_regions(outline):
    """Inside the letters but not their counters: pixels enclosed by exactly two contour edges."""
    cnts, _ = cv2.findContours(outline, cv2.RETR_TREE, cv2.CHAIN_APPROX_NONE)
    depth = np.zeros(outline.shape, np.int32)
    for c in cnts:
        if cv2.contourArea(c) < 60:
            continue
        one = np.zeros(outline.shape, np.uint8)
        cv2.drawContours(one, [c], -1, 1, -1)
        depth += one
    return ((depth == 2) & (outline == 0)).astype(np.uint8)


def drips(rgba, chance, max_len):
    """Paint run down from the low edges where it went on heavy."""
    n = rgba.shape[0]
    a = rgba[..., 3]
    heavy = (a > 0.8)
    edge = heavy & ~np.roll(heavy, -3, axis=0)  # paint with bare wall right under it
    ys, xs = np.nonzero(edge[: n - 40])
    if len(xs) == 0:
        return
    pick = rng.random(len(xs)) < chance
    for y, x in zip(ys[pick], xs[pick]):
        col = rgba[y, x, :3].copy()
        run = int(rng.uniform(0.15, 1.0) ** 2 * max_len) + 12
        w = rng.uniform(1.2, 3.2)
        wob = rng.uniform(0, 6.28)
        for k in range(run):
            yy = y + k
            if yy >= n - 4:
                break
            t = k / run
            ww = w * (1.0 - 0.55 * t)
            cx = x + 1.2 * np.sin(wob + k * 0.05)
            x0, x1 = int(cx - ww - 1), int(cx + ww + 2)
            for xx in range(max(0, x0), min(rgba.shape[1], x1)):
                cov = np.clip(ww + 0.5 - abs(xx - cx), 0, 1) * (1.0 - 0.3 * t)
                if cov > rgba[yy, xx, 3]:
                    rgba[yy, xx, :3] = col
                    rgba[yy, xx, 3] = cov
        by = min(n - 5, y + run)  # the bead it ends in
        cv2.circle(rgba, (int(x), int(by)), int(w + 1.3), (*[float(c) for c in col], 0.9), -1, cv2.LINE_AA)


def over(dst, col, a):
    """Paint colour `col` with coverage `a` over `dst` (straight alpha)."""
    a = a[..., None]
    out_a = a + dst[..., 3:4] * (1 - a)
    rgb = (np.array(col, np.float32) * a + dst[..., :3] * dst[..., 3:4] * (1 - a)) / np.maximum(out_a, 1e-5)
    dst[..., :3] = rgb
    dst[..., 3:4] = out_a


def weather(rgba, amount):
    """Years on the wall: chips flaked off, pores, sun-faded toward chalky, thinner overall."""
    h, w = rgba.shape[:2]
    chips = fbm((h, w), 45, 5)
    pores = fbm((h, w), 6, 2)
    keep = np.clip((chips - amount * 0.2) * 8.0, 0, 1) * (0.8 + 0.2 * pores)
    rgba[..., 3] *= keep * (1.0 - 0.25 * amount)
    chalk = np.array([0.7, 0.68, 0.64], np.float32)
    rgba[..., :3] = rgba[..., :3] * (1 - 0.25 * amount) + chalk * 0.25 * amount


def tag(cell, i):
    style = STYLE[i]
    m = (cell > 0.35).astype(np.uint8)
    out = np.zeros((N, N, 4), np.float32)
    if style[0] == "tag":
        line, outline = style[1], style[2]
        m = dilate(m, int(rng.integers(2, 5)))
        if outline is not None:
            over(out, outline, spray(dilate(m, 6), hard=1.8, haze=0.25))
        over(out, line, spray(m))
        drips(out, 0.006, 160)
    else:
        fill, outline, shadow = style[1], style[2], style[3]
        ol = dilate(m, 5)
        inside = fill_regions(ol)
        body = np.maximum(ol, inside)
        if shadow is not None:  # drop shadow, down and right
            sh = np.roll(np.roll(dilate(body, 3), 16, axis=0), 12, axis=1)
            over(out, shadow, spray(sh, hard=2.0, haze=0.2, grains=0.5))
        passes = fbm((N, N), 160, 3)  # the can's sweeps: thin and thick bands in the fill
        streak = 0.88 + 0.12 * np.clip(np.sin(np.add.outer(np.arange(N) * 0.07, np.arange(N) * 0.05) + passes * 14) * 0.5 + 0.5, 0, 1)
        over(out, fill, spray(inside, hard=2.5, haze=0.15, grains=0.4) * streak)
        over(out, outline, spray(ol, hard=1.5))
        # Shine: short white strokes high on each letter's fill.
        dist = cv2.distanceTransform(inside, cv2.DIST_L2, 3)
        shine = np.zeros((N, N), np.uint8)
        n, lab, stats, _ = cv2.connectedComponentsWithStats(inside)
        for k in range(1, n):
            x, y, w, h, area = stats[k]
            if area < 1500:
                continue
            ys, xs = np.nonzero((lab[y:y + h // 3 + 1, x:x + w] == k) & (dist[y:y + h // 3 + 1, x:x + w] > 7))
            if len(xs) == 0:
                continue
            j = rng.integers(len(xs))
            cx, cy = int(x + xs[j]), int(y + ys[j])
            cv2.line(shine, (cx - 9, cy + 4), (cx + 9, cy - 4), 1, 4, cv2.LINE_AA)
            cv2.circle(shine, (cx + 16, cy - 8), 3, 1, -1, cv2.LINE_AA)
        over(out, WHITE, spray(shine, hard=1.2, haze=0.1, grains=0.2) * 0.9)
        drips(out, 0.004, 220)
    weather(out, rng.uniform(0.2, 0.55))
    return out


def buff(seed):
    """Grey paint rolled over old tags: a ragged patch, roller lanes, the old paint bleeding through."""
    r = np.random.default_rng(seed)
    h, w = 512, 1024
    out = np.zeros((h, w, 4), np.float32)
    n = fbm((h, w), 120, 5, r)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    box = np.minimum(np.minimum(xx, w - 1 - xx) / 90.0, np.minimum(yy, h - 1 - yy) / 60.0)
    a = np.clip((box + (n - 0.5) * 1.6) * 3.0, 0, 1)
    lanes = 0.97 + 0.03 * np.sin(yy / 22.0 * np.pi + n * 3.0)  # roller passes, roughly level
    col = [(0.52, 0.5, 0.47), (0.62, 0.6, 0.55), (0.42, 0.42, 0.43)][seed % 3]
    out[..., :3] = np.array(col, np.float32) * lanes[..., None]
    out[..., 3] = a * (0.82 + 0.18 * fbm((h, w), 8, 2, r))
    ghost = fbm((h, w), 40, 4, r)  # old letters showing through as darker, blotchy shapes
    g = np.clip((ghost - 0.7) * 4.0, 0, 1) * 0.07
    out[..., :3] *= (1 - g)[..., None]
    return out


def scribble(seed):
    """A quick sprayed mark: a line, an arrow, a cross, a circle or a zig-zag."""
    r = np.random.default_rng(seed)
    m = np.zeros((512, 512), np.uint8)
    kind = seed % 5
    t = int(r.integers(9, 15))
    if kind == 0:
        cv2.line(m, (40, 300), (470, 220), 1, t, cv2.LINE_AA)
    elif kind == 1:
        cv2.arrowedLine(m, (60, 380), (430, 160), 1, t, cv2.LINE_AA, tipLength=0.25)
    elif kind == 2:
        cv2.line(m, (120, 110), (400, 400), 1, t + 3, cv2.LINE_AA)
        cv2.line(m, (400, 120), (110, 390), 1, t + 3, cv2.LINE_AA)
    elif kind == 3:
        cv2.ellipse(m, (256, 256), (190, 150), float(r.uniform(-20, 20)), 20, 350, 1, t, cv2.LINE_AA)
    else:
        pts = np.array([[40 + k * 48, 220 + (60 if k % 2 else -60) + int(r.integers(-20, 20))] for k in range(10)], np.int32)
        cv2.polylines(m, [pts], False, 1, t, cv2.LINE_AA)
    out = np.zeros((512, 512, 4), np.float32)
    over(out, [RED, BLACK, WHITE, BLUE, ORANGE, LIME][seed % 6], spray(m, hard=2.0, haze=0.45, grains=1.5))
    drips(out, 0.01, 120)
    weather(out, r.uniform(0.2, 0.5))
    return out


def litter(seed):
    """2.5 m of floor junk: leaves blown in, paper scraps, glass shards, butts and grit."""
    r = np.random.default_rng(seed)
    n = 1024
    out = np.zeros((n, n, 4), np.float32)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    rad = np.hypot(xx - n / 2, yy - n / 2) / (n / 2)
    density = np.clip((1.0 - rad) * 1.4 + (fbm((n, n), 300, 4, r) - 0.5) * 1.5, 0, 1)  # thick in the middle, ragged edge

    def where():
        while True:
            x, y = r.integers(30, n - 30, 2)
            if r.random() < density[y, x]:
                return int(x), int(y)

    grit = (r.random((n, n)) < density * 0.05).astype(np.float32)
    over(out, (0.25, 0.22, 0.18), blur(grit, 0.6) * 1.5 * density)  # sand and crumbs
    over(out, (0.33, 0.29, 0.22), np.clip(blur(density, 30) * (fbm((n, n), 60, 4, r) - 0.3), 0, 1) * 0.5)  # dust
    leaves, papers, glass = [(40, 6, 30), (12, 6, 4), (10, 2, 26)][seed % 3]
    for k in range(leaves):  # dead leaves: brown and ochre, a midrib, a few curled dark
        x, y = where()
        L = int(r.uniform(14, 34))
        a = float(r.uniform(0, 180))
        col = [(0.42, 0.26, 0.1), (0.55, 0.38, 0.14), (0.3, 0.2, 0.1), (0.5, 0.45, 0.2)][int(r.integers(4))]
        m = np.zeros((n, n), np.uint8)
        cv2.ellipse(m, (x, y), (L, int(L * r.uniform(0.35, 0.55))), a, 0, 360, 1, -1, cv2.LINE_AA)
        shade = np.array(col) * r.uniform(0.7, 1.1)
        over(out, tuple(shade), blur(m.astype(np.float32), 0.8))
        rib = np.zeros((n, n), np.uint8)
        dx, dy = np.cos(np.radians(a)) * L, np.sin(np.radians(a)) * L
        cv2.line(rib, (int(x - dx * 1.2), int(y - dy * 1.2)), (int(x + dx), int(y + dy)), 1, 1, cv2.LINE_AA)
        over(out, tuple(shade * 0.6), rib.astype(np.float32) * 0.8)
    for k in range(papers):  # paper scraps: torn polygons, creased, dirty
        x, y = where()
        s0 = r.uniform(25, 70)
        pts = np.array([[x + np.cos(t) * s0 * r.uniform(0.6, 1.2), y + np.sin(t) * s0 * r.uniform(0.6, 1.2)]
                        for t in np.sort(r.uniform(0, 6.28, int(r.integers(5, 9))))], np.int32)
        m = np.zeros((n, n), np.uint8)
        cv2.fillPoly(m, [pts], 1, cv2.LINE_AA)
        crease = 0.85 + 0.15 * fbm((n, n), 20, 2, r)
        col = [(0.78, 0.76, 0.7), (0.7, 0.62, 0.48), (0.6, 0.6, 0.62)][int(r.integers(3))]
        mm = blur(m.astype(np.float32), 0.7)
        tmp = np.zeros_like(out)
        over(tmp, col, mm)
        tmp[..., :3] *= crease[..., None] * (0.8 + 0.2 * fbm((n, n), 50, 3, r))[..., None]
        over(out, (0, 0, 0), np.zeros((n, n), np.float32))
        a_ = tmp[..., 3:4]
        out[..., :3] = tmp[..., :3] * a_ + out[..., :3] * (1 - a_)
        out[..., 3:4] = np.maximum(out[..., 3:4], a_)
    for k in range(glass):  # broken bottle glass: small sharp shards, green, brown, clear
        x, y = where()
        col = [(0.12, 0.3, 0.12), (0.3, 0.16, 0.05), (0.6, 0.65, 0.65)][int(r.integers(3))]
        for j in range(int(r.integers(1, 5))):
            cx, cy = x + int(r.integers(-25, 25)), y + int(r.integers(-25, 25))
            sz = r.uniform(3, 10)
            pts = np.array([[cx + np.cos(t) * sz * r.uniform(0.3, 1.3), cy + np.sin(t) * sz * r.uniform(0.3, 1.3)] for t in (0, 2.1, 4.2)], np.int32)
            m = np.zeros((n, n), np.uint8)
            cv2.fillPoly(m, [pts], 1, cv2.LINE_AA)
            over(out, col, m.astype(np.float32) * 0.85)
            cv2.circle(m, (cx, cy), 1, 1, -1)
            over(out, (0.9, 0.92, 0.9), (m.astype(np.float32) * 0) + (np.hypot(xx - cx, yy - cy) < 1.5) * 0.9)
    for k in range(int(r.integers(5, 12))):  # cigarette butts
        x, y = where()
        a = r.uniform(0, 6.28)
        dx, dy = np.cos(a) * 7, np.sin(a) * 7
        m = np.zeros((n, n), np.uint8)
        cv2.line(m, (int(x - dx), int(y - dy)), (int(x + dx), int(y + dy)), 1, 4, cv2.LINE_AA)
        over(out, (0.8, 0.78, 0.72), m.astype(np.float32))
        m[:] = 0
        cv2.line(m, (int(x), int(y)), (int(x + dx), int(y + dy)), 1, 4, cv2.LINE_AA)
        over(out, (0.7, 0.45, 0.2), m.astype(np.float32))
    return out


def puddle(seed):
    """Standing water: albedo (dark wet concrete, a damp rim fading out) and its ORM (glassy middle)."""
    r = np.random.default_rng(seed)
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    u = (xx - n / 2) / (n / 2) + (fbm((n, n), 300, 3, r) - 0.5) * 0.8  # warped: a lopsided pool
    v = (yy - n / 2) / (n / 2) + (fbm((n, n), 300, 3, r) - 0.5) * 0.8
    d = np.hypot(u * 1.15, v) + (fbm((n, n), 90, 4, r) - 0.5) * 0.3
    border = np.clip((1.0 - np.maximum(np.abs(xx - n / 2), np.abs(yy - n / 2)) / (n / 2)) * 6.0, 0, 1)
    water = np.clip((0.62 - d) * 14.0, 0, 1)
    damp = np.clip((0.9 - d) * 3.0, 0, 1)
    alb = np.zeros((n, n, 4), np.float32)
    alb[..., :3] = np.array([0.05, 0.048, 0.045], np.float32)
    alb[..., 3] = np.clip(damp * 0.35 + water * 0.2, 0, 1) * border  # wet darkens a little; the water is in the gloss
    orm = np.zeros((n, n, 4), np.float32)
    orm[..., 0] = 1.0
    orm[..., 1] = 0.75 - 0.7 * water - 0.1 * damp  # roughness: 0.05 on the water
    orm[..., 2] = 0.0
    orm[..., 3] = 1.0
    return alb, orm


def holes(seed):
    """0.6 m of plywood shot through: stray rounds in a loose group, each a dark hole in a ragged
    ring of pale torn fibre, a grey lead smudge; the older ones weathered dark."""
    r = np.random.default_rng(seed)
    n = 512  # 0.6 m: ~0.85 px a mm
    out = np.zeros((n, n, 4), np.float32)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    cx0, cy0 = n / 2 + r.normal(0, 30), n / 2 + r.normal(0, 30)
    for k in range(int(r.integers(8, 26))):
        x = float(np.clip(cx0 + r.normal(0, 70), 20, n - 20))
        y = float(np.clip(cy0 + r.normal(0, 70), 20, n - 20))
        old = r.random() < 0.4
        d = np.hypot(xx - x, yy - y)
        ang = np.arctan2(yy - y, xx - x)
        rag = 1.0 + sum(r.uniform(0.05, 0.2) * np.sin(ang * f + r.uniform(0, 6)) for f in (2, 3, 7, 13))
        rag *= 1.0 + 0.6 * np.abs(np.sin(ang))  # the face veneer tears along its grain (up and down)
        hole = r.uniform(3.2, 4.6)
        ring = hole * r.uniform(1.3, 1.8) * rag
        smudge = np.clip(1.0 - d / (hole * 4.5), 0, 1) ** 2 * 0.35
        over(out, (0.22, 0.22, 0.23), smudge)
        fibre = np.clip((ring - d) / 1.5, 0, 1) * (0.45 if old else 0.7)
        over(out, (0.3, 0.25, 0.19) if old else (0.62, 0.52, 0.38), fibre)  # torn veneer, a shade lighter than the weathered face
        over(out, (0.02, 0.018, 0.015), np.clip((hole - d) / 1.0 + 0.5, 0, 1))
    return out


def mould(seed):
    """The foot of a plywood sheet left in the wet: black mould speckle and rot, thick at the
    bottom edge, thinning upward in ragged tongues, a dark water line."""
    r = np.random.default_rng(seed)
    h, w = 512, 1024
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    up = 1.0 - yy / (h - 1)  # 1 at the top
    reach = 0.35 + 0.5 * fbm((h, w), 260, 4, r)  # how high it climbed here
    ends = np.clip(np.minimum(xx, w - 1 - xx) / 60.0, 0, 1)
    dens = np.clip((reach - up) * 3.0, 0, 1) * ends * 0.75
    out = np.zeros((h, w, 4), np.float32)
    over(out, (0.1, 0.09, 0.07), dens * 0.55 * fbm((h, w), 40, 4, r))  # damp stain
    spots = (r.random((h, w)) < dens ** 1.5 * 0.25).astype(np.float32)
    spots = np.clip(blur(spots, 1.2) * 4.0, 0, 1)
    over(out, (0.03, 0.035, 0.025), spots * 0.9)
    clumps = np.clip((fbm((h, w), 25, 3, r) - 0.62) * 5.0, 0, 1) * dens
    over(out, (0.05, 0.06, 0.04), clumps * 0.8)
    line = np.exp(-((up - reach + 0.02) / 0.02) ** 2) * 0.18  # the tide line
    over(out, (0.12, 0.1, 0.07), line * ends)
    return out


def tile_gap(seed):
    """Where a 1 m rubber mat was pulled up: bare grey screed, trowelled glue ridges, grit, a dark
    gap round the edge and a torn strip of rubber still stuck along one side."""
    r = np.random.default_rng(seed)
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    out = np.zeros((n, n, 4), np.float32)
    edge = np.minimum(np.minimum(xx, n - 1 - xx), np.minimum(yy, n - 1 - yy))
    inside = np.clip((edge - 3) / 2.0, 0, 1)
    base = 0.2 + 0.05 * fbm((n, n), 120, 4, r)  # old screed under the lights reads dark grey, not white
    ridge = 0.5 + 0.5 * np.sin((xx * 0.7 + yy * 0.7) / 6.0 + 4 * np.sin(yy / 90.0 + seed))  # notched trowel swirl
    out[..., :3] = (base * (0.9 + 0.1 * ridge))[..., None] * np.array([1.0, 0.97, 0.92], np.float32)
    glue = np.clip((fbm((n, n), 70, 4, r) - 0.45) * 4.0, 0, 1) * ridge
    out[..., :3] = out[..., :3] * (1 - glue[..., None] * 0.3) + np.array([0.12, 0.1, 0.06], np.float32) * glue[..., None] * 0.3
    out[..., 3] = 1.0
    over(out, (0.03, 0.03, 0.03), 1.0 - inside)  # the gap at the edge
    strip_w = int(r.integers(20, 70))
    torn = (yy < strip_w + 18 * (fbm((n, n), 40, 3, r) - 0.5)).astype(np.float32)
    over(out, (0.06, 0.065, 0.07), torn * inside)  # rubber that stayed glued down
    grit = (r.random((n, n)) < 0.02).astype(np.float32)
    over(out, (0.2, 0.18, 0.15), blur(grit, 0.6) * 1.5)
    out[..., 3] *= np.clip(edge / 1.5, 0, 1)
    return out


def brass(seed):
    """2 m of rubber past the railing with spent cases kicked about: little brass cylinders, a dark
    mouth at one end, a glint, a few blackened; soot round where they gathered."""
    r = np.random.default_rng(seed)
    n = 1024  # 2 m: ~0.5 px a mm
    out = np.zeros((n, n, 4), np.float32)
    dens = fbm((n, n), 400, 3, r)
    over(out, (0.05, 0.045, 0.04), np.clip((dens - 0.45) * 2.0, 0, 1) * 0.35 * fbm((n, n), 30, 3, r))
    for k in range(int(r.integers(180, 320))):
        while True:
            x, y = r.uniform(12, n - 12, 2)
            if r.random() < dens[int(y), int(x)] ** 2:
                break
        a = r.uniform(0, np.pi)
        L, W = r.uniform(8, 11), r.uniform(4.0, 5.0)
        dx, dy = np.cos(a) * L / 2, np.sin(a) * L / 2
        col = (0.78, 0.58, 0.24) if r.random() < 0.8 else (0.3, 0.24, 0.14)
        p0 = (int(round(x - dx)), int(round(y - dy)))
        p1 = (int(round(x + dx)), int(round(y + dy)))
        m = np.zeros((n, n), np.uint8)
        cv2.line(m, p0, p1, 1, int(round(W)), cv2.LINE_AA)
        over(out, (0.04, 0.035, 0.03), np.roll(np.roll(blur(m.astype(np.float32), 1.5), 2, 0), 1, 1) * 0.6)  # its shadow
        over(out, col, m.astype(np.float32))
        mm = np.zeros((n, n), np.uint8)
        cv2.circle(mm, p1, 2, 1, -1, cv2.LINE_AA)
        over(out, (0.08, 0.06, 0.04), mm.astype(np.float32) * 0.9)  # the open mouth
        gl = np.zeros((n, n), np.uint8)
        cv2.line(gl, (int(round(x - dx * 0.6)), int(round(y - dy * 0.6))), (int(round(x + dx * 0.3)), int(round(y + dy * 0.3))), 1, 1, cv2.LINE_AA)
        over(out, (1.0, 0.92, 0.7), gl.astype(np.float32) * 0.7)
    return out


def save(img, name):
    px = np.clip(img * 255.0 + 0.5, 0, 255).astype(np.uint8)
    cv2.imwrite(os.path.join(OUT, name), cv2.cvtColor(px, cv2.COLOR_RGBA2BGRA))


def main():
    os.makedirs(OUT, exist_ok=True)
    open(os.path.join(OUT, ".gdignore"), "w").close()
    src = cv2.imread(SRC, cv2.IMREAD_GRAYSCALE).astype(np.float32) / 255.0
    cells = cv2.resize(src, (4 * N, 4 * N), interpolation=cv2.INTER_AREA)
    for i in range(16):
        cell = cells[(i // 4) * N:(i // 4 + 1) * N, (i % 4) * N:(i % 4 + 1) * N]
        save(tag(cell, i), "tag_%02d.png" % i)
    for k in range(3):
        save(buff(k), "buff_%d.png" % k)
    for k in range(6):
        save(scribble(100 + k), "scribble_%d.png" % k)
    for k in range(3):
        save(litter(200 + k), "litter_%d.png" % k)
    for k in range(3):
        alb, orm = puddle(300 + k)
        save(alb, "puddle_%d.png" % k)
        save(orm, "puddle_%d_orm.png" % k)
    for k in range(4):
        save(holes(400 + k), "holes_%d.png" % k)
    for k in range(3):
        save(mould(500 + k), "mould_%d.png" % k)
    for k in range(2):
        save(tile_gap(600 + k), "tile_gap_%d.png" % k)
    for k in range(3):
        save(brass(700 + k), "brass_%d.png" % k)


if __name__ == "__main__":
    main()
