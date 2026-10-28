# Blueprints for the investigation board (docs/ayrintilar.md "Kullanılan asetler"): engineering
# sheets for the special rounds, drawn here and aged like an old print. Each round stands upright
# with every part named by a leader; beside it the maths, section A-A, a magnified detail, a
# sequence or circuit box, a figure, a parts list and a title block. Each sheet has its own paper.
# Fonts from assets/fonts (all SIL OFL).
# Run: python tools/draw_blueprints.py <out dir>
import math, os, random, sys
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

FONTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "fonts")
W, H, S = 1600, 1100, 2  # final size; drawn at S× and scaled down for clean lines
BG = (30, 70, 124)
INK = (228, 238, 250)
DIM = (168, 196, 230)
RED = (226, 78, 64)
GREEN = (70, 200, 96)
FILES = {"mono": "JetBrainsMono.ttf", "cond": "BarlowCondensed-SemiBold.ttf",
         "bold": "BarlowCondensed-Bold.ttf", "hand": "Caveat.ttf"}
_fonts = {}


def font(kind, size):
    k = (kind, size)
    if k not in _fonts:
        _fonts[k] = ImageFont.truetype(os.path.join(FONTS, FILES[kind]), int(size * S))
    return _fonts[k]


def dashes(pts, pattern):
    out, cur, i, left, on = [], [pts[0]], 0, pattern[0], True
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        seg, t = math.hypot(x2 - x1, y2 - y1), 0.0
        while seg - t > left:
            t += left
            p = (x1 + (x2 - x1) * t / seg, y1 + (y2 - y1) * t / seg)
            if on:
                cur.append(p)
                out.append(cur)
            cur, on, i = [p], not on, i + 1
            left = pattern[i % len(pattern)]
        left -= seg - t
        cur.append((x2, y2))
    if on and len(cur) > 1:
        out.append(cur)
    return out


CHAIN = (22, 4, 4, 4)
HIDDEN = (7, 4)


class Sheet:
    def __init__(self, seed):
        self.rnd = random.Random(seed)
        self.im = Image.new("RGBA", (W * S, H * S), BG + (255,))
        self.d = ImageDraw.Draw(self.im)

    # --- primitives (all coordinates in final pixels) ---
    def line(self, pts, w=1.3, col=INK, dash=None):
        pts = [(x * S, y * S) for x, y in pts]
        for part in (dashes(pts, [v * S for v in dash]) if dash else [pts]):
            self.d.line(part, fill=col, width=max(1, round(w * S)), joint="curve")

    def poly(self, pts, w=1.3, col=INK, fill=None, dash=None):
        if fill:
            self.d.polygon([(x * S, y * S) for x, y in pts], fill=fill)
        self.line(list(pts) + [pts[0]], w, col, dash)

    def circle(self, c, r, w=1.3, col=INK, fill=None, dash=None):
        if dash:
            n = max(24, int(r))
            self.line([(c[0] + r * math.cos(2 * math.pi * i / n), c[1] + r * math.sin(2 * math.pi * i / n)) for i in range(n + 1)], w, col, dash)
            return
        self.d.ellipse([(c[0] - r) * S, (c[1] - r) * S, (c[0] + r) * S, (c[1] + r) * S], fill=fill,
                       outline=col if w else None, width=max(1, round(w * S)))

    def rect(self, x, y, w, h, lw=1.3, col=INK, fill=None):
        self.d.rectangle([x * S, y * S, (x + w) * S, (y + h) * S], fill=fill, outline=col if lw else None, width=max(1, round(lw * S)))

    def text(self, x, y, s, kind="mono", size=13, col=INK, anchor="la", back=False):
        f = font(kind, size)
        if back:
            b = self.d.textbbox((x * S, y * S), s, font=f, anchor=anchor)
            self.d.rectangle([b[0] - 3 * S, b[1] - 2 * S, b[2] + 3 * S, b[3] + 2 * S], fill=BG + (255,))
        self.d.text((x * S, y * S), s, font=f, fill=col, anchor=anchor)

    def rtext(self, x, y, s, kind="hand", size=26, col=INK, angle=0.0, alpha=235):
        """Rotated text centred on (x, y): handwriting, stamps, vertical dimensions."""
        f = font(kind, size)
        b = self.d.textbbox((0, 0), s, font=f)
        lay = Image.new("RGBA", (b[2] - b[0] + 20 * S, b[3] - b[1] + 20 * S), (0, 0, 0, 0))
        ImageDraw.Draw(lay).text((10 * S - b[0], 10 * S - b[1]), s, font=f, fill=col + (alpha,))
        lay = lay.rotate(angle, resample=Image.BICUBIC, expand=True)
        self.im.alpha_composite(lay, (int(x * S - lay.width / 2), int(y * S - lay.height / 2)))

    def mask_poly(self, pts):
        m = Image.new("L", self.im.size, 0)
        ImageDraw.Draw(m).polygon([(x * S, y * S) for x, y in pts], fill=255)
        return m

    def hatch(self, mask, angle=45, sp=6.0, col=DIM, w=0.8):
        bb = mask.getbbox()
        if not bb:
            return
        x0, y0, x1, y1 = bb
        lay = Image.new("L", (x1 - x0, y1 - y0), 0)
        ld = ImageDraw.Draw(lay)
        a = math.radians(angle)
        dx, dy, diag = math.cos(a), -math.sin(a), (x1 - x0) + (y1 - y0)
        cx, cy = lay.width / 2, lay.height / 2
        for k in range(-int(diag / (sp * S)) - 1, int(diag / (sp * S)) + 2):
            ox, oy = cx - dy * k * sp * S, cy + dx * k * sp * S
            ld.line([(ox - dx * diag, oy - dy * diag), (ox + dx * diag, oy + dy * diag)], fill=255, width=max(1, round(w * S)))
        lay = ImageChops.multiply(lay, mask.crop(bb))
        self.im.paste(col + (255,), bb, lay)

    def stipple(self, mask, n, r=0.9, col=DIM):
        bb = mask.getbbox()
        if not bb:
            return
        for _ in range(n):
            x, y = self.rnd.uniform(bb[0], bb[2] - 1), self.rnd.uniform(bb[1], bb[3] - 1)
            if mask.getpixel((int(x), int(y))):
                rr = r * S * self.rnd.uniform(0.6, 1.4)
                self.d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=col)

    def clear(self, mask):
        self.im.paste(BG + (255,), (0, 0), mask)

    def arrow(self, tip, frm, size=8, col=INK):
        a = math.atan2(tip[1] - frm[1], tip[0] - frm[0])
        p = [tip, (tip[0] - size * math.cos(a - 0.3), tip[1] - size * math.sin(a - 0.3)),
             (tip[0] - size * math.cos(a + 0.3), tip[1] - size * math.sin(a + 0.3))]
        self.d.polygon([(x * S, y * S) for x, y in p], fill=col)

    # --- drafting conventions ---
    def dim_h(self, x1, x2, y, label, e1=None, e2=None, col=DIM):
        for x, e in ((x1, e1), (x2, e2)):
            if e is not None:
                self.line([(x, e + (3 if y > e else -3)), (x, y + (5 if y > e else -5))], 0.8, col)
        self.line([(x1, y), (x2, y)], 0.9, col)
        self.arrow((x1, y), (x2, y), col=col)
        self.arrow((x2, y), (x1, y), col=col)
        self.text((x1 + x2) / 2, y - 3, label, size=12, col=INK, anchor="mb", back=True)

    def dim_v(self, y1, y2, x, label, e=None, col=DIM):
        if e is not None:
            for y in (y1, y2):
                self.line([(e - 3, y), (x - 5, y)], 0.8, col)
        self.line([(x, y1), (x, y2)], 0.9, col)
        self.arrow((x, y1), (x, y2), col=col)
        self.arrow((x, y2), (x, y1), col=col)
        self.rtext(x - 10, (y1 + y2) / 2, label, "mono", 12, INK, 90, 255)

    def balloon(self, n, target, pos, col=INK):
        a = math.atan2(target[1] - pos[1], target[0] - pos[0])
        self.line([(pos[0] + 11 * math.cos(a), pos[1] + 11 * math.sin(a)), target], 0.8, col)
        self.circle(target, 1.8, 0, fill=col)
        self.circle(pos, 11, 1.1, col, fill=BG)
        self.text(pos[0], pos[1] + 1, str(n), "cond", 14, col, "mm")

    def leader(self, target, pos, s, size=12, anchor="lm"):
        self.line([target, pos, (pos[0] + (14 if anchor[0] == "l" else -14), pos[1])], 0.8, DIM)
        self.circle(target, 1.6, 0, fill=DIM)
        self.text(pos[0] + (17 if anchor[0] == "l" else -17), pos[1], s, size=size, anchor=anchor)

    def note(self, x, y, s, size=27, col=INK, angle=0.0, alpha=225):
        self.rtext(x, y, s, "hand", size, col, angle, alpha)

    def scrawl(self, pts, col=RED, w=2.0):
        """A hand-drawn line: wobbly, through the given points."""
        out = []
        for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
            n = max(2, int(math.hypot(x2 - x1, y2 - y1) / 12))
            out += [(x1 + (x2 - x1) * i / n + self.rnd.uniform(-1, 1), y1 + (y2 - y1) * i / n + self.rnd.uniform(-1, 1)) for i in range(n)]
        out.append(pts[-1])
        self.line(out, w, col)

    def ring(self, c, rx, ry, col=RED, w=2.0):
        pts = [(c[0] + rx * (1 + self.rnd.uniform(-.04, .04)) * math.cos(t), c[1] + ry * (1 + self.rnd.uniform(-.04, .04)) * math.sin(t))
               for t in np.linspace(-0.3, 2 * math.pi + 0.4, 40)]
        self.line(pts, w, col)

    def stamp(self, s, x, y, angle, size=40, col=RED):
        f = font("bold", size)
        b = self.d.textbbox((0, 0), s, font=f)
        pad = 12 * S
        lay = Image.new("RGBA", (b[2] - b[0] + 2 * pad, b[3] - b[1] + 2 * pad), (0, 0, 0, 0))
        ld = ImageDraw.Draw(lay)
        ld.rectangle([2 * S, 2 * S, lay.width - 2 * S, lay.height - 2 * S], outline=col + (255,), width=3 * S)
        ld.rectangle([6 * S, 6 * S, lay.width - 6 * S, lay.height - 6 * S], outline=col + (255,), width=1 * S)
        ld.text((pad - b[0], pad - b[1]), s, font=f, fill=col + (255,))
        a = np.asarray(lay).copy()
        wear = np.random.default_rng(self.rnd.randrange(1 << 30)).random(a.shape[:2])
        a[..., 3] = (a[..., 3] * np.clip((wear - 0.12) * 1.6, 0, 0.82)).astype(np.uint8)
        lay = Image.fromarray(a).rotate(angle, resample=Image.BICUBIC, expand=True)
        self.im.alpha_composite(lay, (int(x * S - lay.width / 2), int(y * S - lay.height / 2)))

    def magnify(self, src, r_src, dst, r_dst, label, letter):
        """Detail view: the drawing around src, enlarged into a circle at dst."""
        k = r_dst / r_src
        box = [int((src[0] - r_src) * S), int((src[1] - r_src) * S), int((src[0] + r_src) * S), int((src[1] + r_src) * S)]
        part = self.im.crop(box).resize((int(2 * r_dst * S), int(2 * r_dst * S)), Image.BICUBIC)
        m = Image.new("L", part.size, 0)
        ImageDraw.Draw(m).ellipse([0, 0, part.width - 1, part.height - 1], fill=255)
        self.im.paste(BG + (255,), (int((dst[0] - r_dst) * S), int((dst[1] - r_dst) * S)), m)
        self.im.paste(part, (int((dst[0] - r_dst) * S), int((dst[1] - r_dst) * S)), m)
        self.circle(dst, r_dst, 1.6)
        self.circle(src, r_src, 1.1, dash=HIDDEN)
        self.text(src[0] + r_src * 0.75, src[1] + r_src * 0.75 + 4, letter, "cond", 16, anchor="lt", back=True)
        self.text(dst[0], dst[1] + r_dst + 8, label, "cond", 17, anchor="mt")
        self.text(dst[0], dst[1] + r_dst + 28, "SCALE %d:1" % round(4 * k), size=11, col=DIM, anchor="mt")

    def turn(self, box, c0, angle, c1, reach=520):
        """Lift the drawing inside box, turn it by angle degrees round c0 and set it down round c1."""
        canvas = Image.new("RGBA", (2 * reach * S, 2 * reach * S), BG + (255,))
        canvas.paste(self.im.crop([v * S for v in box]), (int((box[0] - c0[0] + reach) * S), int((box[1] - c0[1] + reach) * S)))
        ink = ImageChops.difference(canvas.convert("RGB"), Image.new("RGB", canvas.size, BG)).convert("L").point(lambda v: min(255, v * 40))
        canvas = canvas.rotate(angle, Image.BICUBIC, fillcolor=BG + (255,))
        ink = ink.rotate(angle, Image.BICUBIC)
        self.im.paste(BG + (255,), [v * S for v in box])
        self.im.paste(canvas, (int((c1[0] - reach) * S), int((c1[1] - reach) * S)), ink)

    def box(self, x, y, w, h, title):
        self.rect(x, y, w, h, 1.2)
        self.rect(x, y, w, 24, 0, fill=INK)
        self.text(x + 8, y + 12, title, "bold", 16, BG, "lm")

    def table(self, x, y, cols, rows, rh=18):
        tw = sum(c for c, _ in cols)
        self.rect(x, y, tw, rh * (len(rows) + 1), 1.2)
        self.rect(x, y, tw, rh, 0, fill=INK)
        cx = x
        for c, head in cols:
            self.text(cx + 5, y + rh / 2, head, "bold", 13, BG, "lm")
            if cx > x:
                self.line([(cx, y), (cx, y + rh * (len(rows) + 1))], 0.8)
            cx += c
        for i, row in enumerate(rows):
            ry = y + rh * (i + 1)
            self.line([(x, ry), (x + tw, ry)], 0.6, DIM)
            cx = x
            for (c, _), v in zip(cols, row):
                self.text(cx + 5, ry + rh / 2, v, size=11, anchor="lm")
                cx += c

    def plot(self, x, y, w, h, xr, yr, xlabel, ylabel, xt, yt):
        """Axes and grid; returns a function mapping data to page coordinates."""
        px, py, pw, ph = x + 46, y + 10, w - 60, h - 40
        f = lambda u, v: (px + (u - xr[0]) / (xr[1] - xr[0]) * pw, py + ph - (v - yr[0]) / (yr[1] - yr[0]) * ph)
        for u in xt:
            self.line([f(u, yr[0]), f(u, yr[1])], 0.5, DIM, (2, 3))
            self.text(*f(u, yr[0]), ("%g" % u), size=10, col=DIM, anchor="mt")
        for v in yt:
            self.line([f(xr[0], v), f(xr[1], v)], 0.5, DIM, (2, 3))
            self.text(f(xr[0], v)[0] - 4, f(xr[0], v)[1], ("%g" % v), size=10, col=DIM, anchor="rm")
        self.line([f(xr[0], yr[1]), f(xr[0], yr[0]), f(xr[1], yr[0])], 1.2)
        self.arrow(f(xr[1], yr[0]), f(xr[0], yr[0]))
        self.arrow(f(xr[0], yr[1]), f(xr[0], yr[0]))
        self.text(px + pw, py + ph + 16, xlabel, size=11, anchor="rt")
        self.rtext(x + 8, py + ph / 2, ylabel, "mono", 11, INK, 90, 255)
        return f

    def frame(self, title, sub, dwg, sheet, rev):
        self.rect(14, 14, W - 28, H - 28, 1.0, DIM)
        self.rect(34, 34, W - 68, H - 68, 2.0)
        for i in range(8):  # zone markers
            x = 34 + (W - 68) * (i + 0.5) / 8
            for y in (24, H - 24):
                self.text(x, y, str(8 - i), "cond", 12, DIM, "mm")
            self.line([(34 + (W - 68) * i / 8, 14), (34 + (W - 68) * i / 8, 34)], 0.8, DIM)
            self.line([(34 + (W - 68) * i / 8, H - 34), (34 + (W - 68) * i / 8, H - 14)], 0.8, DIM)
        for i in range(6):
            y = 34 + (H - 68) * (i + 0.5) / 6
            for x in (24, W - 24):
                self.text(x, y, "ABCDEF"[i], "cond", 12, DIM, "mm")
        self.text(58, 50, title, "bold", 46)
        self.text(60, 104, sub, size=13, col=DIM)
        # revision block
        self.table(1000, 46, [(36, "REV"), (150, "DESCRIPTION"), (70, "DATE")],
                   [("A", "INITIAL LAYOUT", "19██-03"), ("B", "RETEST AFTER FAILURE", "19██-05"), (rev, "RECOVERED FROM PILE", "██-██")], 17)
        # title block
        x, y, w = 1188, 976, 344
        self.rect(x, y, w, 76, 1.6)
        self.text(x + 8, y + 6, "RANGE 7 · PILE COMPANY — ANOMALOUS ORDNANCE", "cond", 14)
        self.line([(x, y + 26), (x + w, y + 26)], 0.8)
        self.text(x + 8, y + 31, title, "cond", 15, DIM)
        self.line([(x, y + 51), (x + w, y + 51)], 0.8)
        cx = x
        for i, (cw, s) in enumerate(zip((120, 62, 82, 80), ["DWG " + dwg, "REV " + rev, "SCALE 4:1", "SHEET %d/3" % sheet])):
            self.text(cx + 8, y + 63, s, size=11, anchor="lm")
            if i:
                self.line([(cx, y + 51), (cx, y + 76)], 0.8)
            cx += cw
        self.text(x - 10, y + 63, "DRAWN ████████   CHK —", size=11, col=DIM, anchor="rm")

    def glow(self, polys, w=1.4, col=INK):
        """Lines that light the paper around them (arcs, crystals)."""
        lay = Image.new("L", self.im.size, 0)
        ld = ImageDraw.Draw(lay)
        for p in polys:
            ld.line([(x * S, y * S) for x, y in p], fill=255, width=round(w * 5 * S), joint="curve")
        lay = lay.filter(ImageFilter.GaussianBlur(7 * S)).point(lambda v: int(v * 0.7))
        self.im.paste(col + (255,), (0, 0), lay)
        for p in polys:
            self.line(p, w, col)

    def finish(self, path, paper=None):
        """paper: (background, ink, red[, green]) to print the sheet on instead of blueprint blue."""
        im = self.im.convert("RGB").filter(ImageFilter.GaussianBlur(0.5 * S)).resize((W, H), Image.LANCZOS)
        a = np.asarray(im).astype(np.float32) / 255
        if paper:  # every pixel is the paper plus some ink, red and green: reprint it in the new colours
            src = [np.array(c, np.float32) / 255 for c in (BG, INK, RED, GREEN)]
            dst = [np.array(c, np.float32) / 255 for c in tuple(paper) + (GREEN,) * (4 - len(paper))]
            k = np.clip((a - src[0]) @ np.linalg.inv(np.stack([c - src[0] for c in src[1:]], 1)).T, 0, 1.2)
            a = dst[0] + sum(k[..., i:i + 1] * (dst[i + 1] - dst[0]) for i in range(3))
        rng = np.random.default_rng(self.rnd.randrange(1 << 30))
        def blur_noise(cells, radius):
            n = Image.fromarray((rng.random((H // cells + 1, W // cells + 1)) * 255).astype(np.uint8))
            return np.asarray(n.resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255
        a *= (0.86 + 0.26 * blur_noise(60, 40))[..., None]  # uneven exposure of the print
        a *= (0.95 + 0.08 * blur_noise(6, 2))[..., None]   # paper fibre
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2))
        a *= (1 - 0.32 * np.clip(r - 0.35, 0, None) ** 1.6)[..., None]
        fx, fy = W * self.rnd.uniform(0.47, 0.53), H * self.rnd.uniform(0.45, 0.52)  # folds: a light crest and a shadow
        a += (0.07 * np.exp(-((xx - fx) / 2.5) ** 2) - 0.05 * np.exp(-((xx - fx - 5) / 4) ** 2))[..., None]
        a += (0.06 * np.exp(-((yy - fy) / 2.5) ** 2) - 0.04 * np.exp(-((yy - fy - 5) / 4) ** 2))[..., None]
        edge = np.clip(1 - np.minimum.reduce([xx, yy, W - xx, H - yy]) / 26, 0, 1)
        a = a * (1 - 0.5 * edge[..., None]) + np.array([0.62, 0.66, 0.62]) * 0.5 * edge[..., None]  # sun-bleached edge
        a += rng.normal(0, 0.018, (H, W, 1))
        Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(path)


def calcs(sh, x, y, w, h, blocks):
    sh.box(x, y, w, h, "CALCULATIONS")
    cy = y + 38
    for head, lines in blocks:
        sh.text(x + 12, cy, head, "bold", 15)
        cy += 22
        for ln in lines:
            sh.text(x + 26, cy, ln, size=13)
            cy += 19
        cy += 9


def bom(sh, rows, rh=17):
    sh.table(1188, 970 - rh * (len(rows) + 1), [(32, "ITEM"), (150, "DESCRIPTION"), (124, "MATERIAL / SPEC"), (38, "QTY")], rows, rh)


def disc(c, r, n=90):
    return [(c[0] + r * math.cos(t), c[1] + r * math.sin(t)) for t in np.linspace(0, 2 * math.pi, n)]


def annulus(sh, c, r0, r1):
    return ImageChops.subtract(sh.mask_poly(disc(c, r0)), sh.mask_poly(disc(c, r1)))


def jagged(rnd, a, b, depth=5, amp=0.22):
    if depth == 0:
        return [a, b]
    l = math.hypot(b[0] - a[0], b[1] - a[1]) or 1
    o = rnd.uniform(-amp, amp) * l
    m = ((a[0] + b[0]) / 2 - (b[1] - a[1]) / l * o, (a[1] + b[1]) / 2 + (b[0] - a[0]) / l * o)
    return jagged(rnd, a, m, depth - 1, amp)[:-1] + jagged(rnd, m, b, depth - 1, amp)


# =====================================================================================
def nose_poly(cx, base, h, w, k=1.0, rot=0.0):
    """The pointed nose of the clone round, tip up; rot turns it round the middle of its base."""
    ys = np.linspace(0, 1, 30)
    side = [(w * k * (1 - (1 - t) ** 2) ** 0.6, h * k * (1 - t)) for t in ys]
    pts = [(-x, y) for x, y in side[::-1]] + [(x, y) for x, y in side[1:]]
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    return [(cx + x * c + y * s, base - y * c + x * s) for x, y in pts]


def sheet_clone(out):
    sh = Sheet(11)
    sh.frame("CLONE ROUND  Mk.I  \"SPLITTER\"", "9×19 · A SEED CRYSTAL PRINTS TWO IMAGES OF THE ROUND, THE NOSE SPLITS INTO THREE · EXTERIOR VIEW",
             "PO-BP-0001", 1, "C")
    rnd = sh.rnd
    vcase(sh, 842, False)
    # mass reservoir: tungsten discs behind three slots, knurled band
    sh.rect(CX - 62, 700, 124, 142, 1.8, fill=BG)
    sh.hatch(rect_mask(sh, CX + 42, 700, CX + 62, 820), 90, 3, w=0.6)
    for sx in (-34, 0, 34):
        sh.rect(CX + sx - 9, 712, 18, 104, 1.2, fill=BG)
        for y in range(716, 814, 11):
            sh.rect(CX + sx - 7, y, 14, 8, 0.9, fill=BG)
            sh.hatch(rect_mask(sh, CX + sx - 7, y, CX + sx + 7, y + 8), 45, 2.2, w=0.5)
    sh.rect(CX - 66, 820, 132, 22, 1.5, fill=BG)
    for x in range(CX - 62, CX + 66, 6):
        sh.line([(x, 822), (x, 840)], 0.8)
    ell(sh, CX, 842, 66, 5, 1.3, a0=0, a1=180)
    # phase drivers: three emitters seen through a window
    sh.rect(CX - 58, 628, 116, 72, 1.8, fill=BG)
    sh.rect(CX - 48, 636, 96, 56, 1.2, fill=BG)
    for sx in (-30, 0, 30):
        sh.rect(CX + sx - 10, 642, 20, 44, 1.2, fill=BG)
        for y in range(646, 684, 5):
            sh.line([(CX + sx - 10, y), (CX + sx + 10, y + 2)], 0.9)
        sh.poly([(CX + sx - 6, 642), (CX + sx + 6, 642), (CX + sx, 634)], 1.1, fill=GREEN)
    ell(sh, CX, 700, 58, 6, 1.3, a0=0, a1=180)
    # splitter charge with its three detonator pins
    sh.rect(CX - 62, 600, 124, 28, 1.6, fill=BG)
    sh.hatch(rect_mask(sh, CX - 62, 600, CX + 62, 628), 45, 3)
    sh.hatch(rect_mask(sh, CX - 62, 600, CX + 62, 628), -45, 3)
    for sx in (-30, 0, 30):
        sh.circle((CX + sx, 614), 5, 1.3, fill=BG)
        sh.circle((CX + sx, 614), 1.6, 0, fill=INK)
    ell(sh, CX, 628, 62, 6, 1.3, a0=0, a1=180)
    # replicator chamber: quartz, two side rails, the seed crystal in gyro rings
    sh.rect(CX - 56, 350, 112, 250, 1.8, fill=BG)
    for x in (CX - 50, CX + 50):
        sh.line([(x, 354), (x, 596)], 0.8, DIM)
    gc = (CX, 468)

    def gyro(rot, front):
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        ts = np.linspace(0, math.pi, 60) if front else np.linspace(math.pi, 2 * math.pi, 60)
        return [(gc[0] + 46 * math.cos(t) * c - 13 * math.sin(t) * s, gc[1] + 46 * math.cos(t) * s + 13 * math.sin(t) * c) for t in ts]
    for rot in (-22, 22):
        sh.line(gyro(rot, False), 1.0, DIM, (4, 3))
    crystal = [(CX, 382), (CX + 24, 404), (CX + 24, 532), (CX, 560), (CX - 24, 532), (CX - 24, 404)]
    sh.glow([crystal + [crystal[0]]], 1.6, GREEN)
    sh.poly(crystal, 1.6, fill=GREEN)
    sh.hatch(sh.mask_poly([(CX, 382), (CX + 24, 404), (CX + 24, 532), (CX, 560)]), 90, 3, INK, 0.6)
    for a, b in (((CX - 24, 404), (CX, 418)), ((CX + 24, 404), (CX, 418)), ((CX - 24, 532), (CX, 520)),
                 ((CX + 24, 532), (CX, 520)), ((CX, 382), (CX, 418)), ((CX, 418), (CX, 520)), ((CX, 520), (CX, 560))):
        sh.line([a, b], 1.0)
    for x, y, r in ((CX - 10, 450, 2), (CX + 8, 490, 1.5), (CX - 6, 512, 1.2)):
        sh.circle((x, y), r, 0, fill=BG)
    sh.glow([[(CX, 382), (CX + dx, 352)] for dx in (-30, 0, 30)], 1.2, GREEN)
    for rot in (-22, 22):
        sh.line(gyro(rot, True), 2.2)
    for s in (-1, 1):  # rails
        x0 = CX - 56 if s < 0 else CX + 50
        sh.rect(x0, 350, 6, 250, 1.2, fill=BG)
        sh.hatch(rect_mask(sh, x0, 350, x0 + 6, 600), 0, 3)
    ell(sh, CX, 600, 56, 6, 1.4, a0=0, a1=180)
    sh.line([(CX - 40, 360), (CX - 40, 590)], 2.8, BG)
    # timing fuse ring with detents and its pointer
    sh.rect(CX - 62, 330, 124, 20, 1.6, fill=BG)
    for i, x in enumerate(range(CX - 58, CX + 62, 10)):
        sh.line([(x, 332), (x, 340 if i % 3 else 346)], 1.0)
    sh.poly([(CX - 5, 352), (CX + 5, 352), (CX, 344)], 1.0, fill=RED)
    ell(sh, CX, 350, 62, 6, 1.4, a0=0, a1=180)
    ell(sh, CX, 330, 62, 6, 1.4, fill=BG)
    # the clone images either side, then the nose in three petals
    for rot in (-13, 13):
        g = nose_poly(CX, 330, 180, 56, rot=rot)
        sh.poly(g, 1.1, DIM, dash=(6, 4))
        tip = g[len(g) // 2]
        for k in (1, 2, 3):
            sh.line([(tip[0] + math.copysign(6 * k, rot), tip[1] + 10 * k), (tip[0] + math.copysign(6 * k + 10, rot), tip[1] + 10 * k + 4)], 0.8, DIM)
    nose = nose_poly(CX, 330, 180, 56)
    sh.poly(nose, 1.9, fill=BG)
    sh.hatch(ImageChops.multiply(sh.mask_poly(nose), rect_mask(sh, CX + 26, 0, W, H)), 90, 3, w=0.6)
    for s in (-1, 1):  # petal seams at ±60° round the nose
        seam = [(CX + s * 0.866 * (px - CX), py) for px, py in nose[29:]]
        sh.line(seam, 1.6)
        sh.line([(x + s * 2.5, y) for x, y in seam[2:]], 0.7, DIM)
    sh.glow([jagged(rnd, (CX, 152), (CX + dx, 128), 3, 0.3) for dx in (-14, 0, 14)], 0.9, GREEN)
    sh.circle((CX, 154), 3, 0, fill=GREEN)

    # in flight: the whole round turns nose up-right, its images peel off the nose
    phi, c0, c1 = math.radians(54.8), (CX, 579), (470, 545)
    u, ax = (math.cos(phi), math.sin(phi)), (math.sin(phi), -math.cos(phi))  # across the round, towards its nose

    def T(x, y):
        dx, dy = x - c0[0], y - c0[1]
        return (c1[0] + dx * u[0] - dy * u[1], c1[1] + dx * u[1] + dy * u[0])
    sh.turn((37, 120, 452, 1054), c0, -math.degrees(phi), c1)
    for off, y0, y1 in ((-104, 560, 770), (-96, 640, 720), (104, 500, 690), (112, 580, 640), (-40, 1022, 1070), (0, 1022, 1090), (40, 1022, 1064)):
        sh.line([T(CX + off, y0), T(CX + off, y1)], 0.9, DIM)
    # cut A-A across the chamber
    m = T(CX, 468)
    sh.line([(m[0] - 108 * u[0], m[1] - 108 * u[1]), (m[0] + 108 * u[0], m[1] + 108 * u[1])], 1.0, INK, CHAIN)
    for s in (-1, 1):
        e = (m[0] + s * 108 * u[0], m[1] + s * 108 * u[1])
        sh.line([e, (e[0] + 14 * ax[0], e[1] + 14 * ax[1])], 2.0)
        sh.arrow((e[0] + 20 * ax[0], e[1] + 20 * ax[1]), e, 9)
        sh.text(e[0] + s * 14 * u[0], e[1] + s * 14 * u[1], "A", "bold", 18, anchor="mm")
    # dimensions along the axis, down-right of the round
    def adim(y0, y1, off, label, ext=True):
        p0, p1 = T(CX + off, y0), T(CX + off, y1)
        sh.line([p0, p1], 0.9, DIM)
        sh.arrow(p0, p1, col=DIM)
        sh.arrow(p1, p0, col=DIM)
        if ext:
            for y, w in ((y0, 6), (y1, 6)):
                sh.line([T(CX + 78, y), T(CX + off + w, y)], 0.8, DIM)
        mid = ((p0[0] + p1[0]) / 2 + 11 * u[0], (p0[1] + p1[1]) / 2 + 11 * u[1])
        sh.rtext(*mid, label, "mono", 12, INK, 90 - math.degrees(phi), 255)
    for y0, y1 in ((150, 330), (350, 600), (700, 842), (842, 1008)):
        adim(y0, y1, 96, "%.1f" % ((y1 - y0) / PX_MM))
    adim(150, 1008, 128, "%.1f OAL" % (858 / PX_MM))
    sh.line([T(CX + 4, 150), T(CX + 134, 150)], 0.8, DIM)
    # labels: front half above the round, back half below it
    for n, (x, y), (lx, ly), name, spec in (
        (1, (CX - 30, 262), (470, 152), "PETAL NOSE ×3", "W-Cu · 2.67 g EACH · SCORED @120°"),
        (2, (CX - 80, 255), (470, 204), "CLONE IMAGES ×2", "PHASE GHOSTS · VISIBLE 2 ms BEFORE SPLIT"),
        (3, (CX - 62, 340), (470, 256), "TIMING FUSE RING", "DELAY 5.6 ms · 12 DETENTS"),
        (4, (CX - 56, 420), (64, 300), "REPLICATOR CHAMBER", "QUARTZ · 2 RAILS · VACUUM"),
        (5, (CX - 18, 470), (64, 352), "SEED CRYSTAL", "UNKNOWN LATTICE · GLOWS WHEN ARMED"),
        (6, (CX - 44, 500), (64, 404), "GYRO RINGS ×2", "PHASE LOCK 3 : 1 · 40 000 rpm"),
        (7, (CX + 62, 614), (604, 640), "SPLITTER CHARGE", "PETN · 3 DETONATOR PINS"),
        (8, (CX + 52, 664), (604, 692), "PHASE DRIVERS ×3", "ONE PER PETAL · Cu COIL"),
        (9, (CX + 62, 760), (604, 744), "MASS RESERVOIR", "W-Cu DISCS · 3 × 9 · FEEDS THE COPIES"),
        (10, (CX + 72, 910), (604, 796), "CARTRIDGE CASE", "BRASS C26000 · 9×19 · KNURLED BAND"),
        (11, (CX + 74, 998), (604, 848), "RIM + PRIMER", "BOXER · SMALL PISTOL")):
        p = T(x, y)
        sh.line([p, (lx - 22, ly), (lx - 10, ly)], 0.9)
        sh.circle(p, 2.2, 0, fill=INK)
        sh.circle((lx, ly), 10, 1.1, fill=BG)
        sh.text(lx, ly + 1, str(n), "cond", 13, anchor="mm")
        sh.text(lx + 16, ly - 1, name, "bold", 17, anchor="lb")
        sh.text(lx + 17, ly + 3, spec, size=11, col=DIM, anchor="lt")

    right_panel(sh, [
        ("1 · SPLIT TIMING", ["t = d / v0 = 2.00 m / 360 m/s = 5.56 ms",
                              "fuse ring: 12 detents × 0.46 ms ≈ 5.6 ms"]),
        ("2 · PETAL SPREAD AT THE RAIL (x = 14 m)", ["Δy = (x − d) · tan θ = 12.0 · tan 4.8° ≈ 1.01 m"]),
        ("3 · MOMENTUM", ["m · v0 = Σ m' · v'      m' = m / 3 = 8.0 g / 3 = 2.67 g",
                          "v_perp = v0 · sin θ = 360 · 0.0837 ≈ 30.1 m/s"]),
        ("4 · ENERGY PER PETAL", ["E' = ½ · m' · v0² = ½ · 0.00267 · 360² ≈ 173 J      ΣE = 519 J"]),
        ("5 · PAYOUT", ["G = n · g_hit = 3 · g_hit",
                        "with RICOCHET (4 bounces):  3 · 4 = ×12"]),
    ], "SECTION A-A", (T(CX + 36, 330), 30, (1160, 610), 80, "DETAIL B", "B"), "SPLIT SEQUENCE")
    # section A-A through the chamber: quartz wall, rails, gyro ring, crystal
    c = (985, 610)
    sh.hatch(annulus(sh, c, 58, 52), 70, 3)
    sh.circle(c, 58, 1.5)
    sh.circle(c, 52, 1.0)
    for a in (0, math.pi):
        bx, by = c[0] + 55 * math.cos(a), c[1] + 55 * math.sin(a)
        sh.rect(bx - 4, by - 7, 8, 14, 1.2, fill=BG)
        sh.hatch(rect_mask(sh, bx - 4, by - 7, bx + 4, by + 7), 0, 2.5)
    sh.circle(c, 46, 1.1, dash=(4, 3))
    hexa = [(c[0] + 25 * math.cos(math.pi / 6 + k * math.pi / 3), c[1] + 25 * math.sin(math.pi / 6 + k * math.pi / 3)) for k in range(6)]
    sh.glow([hexa + [hexa[0]]], 1.4, GREEN)
    sh.poly(hexa, 1.5, fill=GREEN)
    for p in hexa[::2]:
        sh.line([c, p], 0.9)
    # split sequence: four frames
    for i, label in enumerate(("t = 0", "2.0 ms", "4.0 ms", "5.6 ms")):
        x, base = 1322 + i * 62, 700
        if i == 0:
            sh.poly(nose_poly(x, base, 120, 18), 1.3, fill=BG)
        elif i == 1:
            for rot in (-10, 10):
                sh.poly(nose_poly(x, base, 120, 18, rot=rot), 0.9, DIM, dash=(4, 3))
            sh.poly(nose_poly(x, base, 120, 18), 1.3, fill=BG)
        elif i == 2:
            for rot, dx in ((-7, -7), (0, 0), (7, 7)):
                sh.poly(nose_poly(x + dx, base, 110, 9, rot=rot), 1.2, fill=BG)
        else:
            for rot, dx in ((-14, -16), (0, 0), (14, 16)):
                sh.poly(nose_poly(x + dx, base - 6, 70, 8, rot=rot), 1.2, fill=GREEN)
        sh.text(x, base + 10, label, size=10, anchor="mt")
        if i:
            sh.arrow((x - 24, 640), (x - 38, 640), 7)
    sh.text(1417, 740, "IMAGES FIRST, THEN THE MASS", size=10, col=DIM, anchor="mt")
    # fig: petal paths seen from above
    sh.box(440, 878, 440, 170, "FIG. 1 — PETAL PATHS (TOP VIEW)")
    f = sh.plot(444, 906, 432, 140, (0, 14.5), (-1.3, 1.3), "RANGE x [m]", "y [m]", range(0, 15, 2), (-1, 0, 1))
    sh.line([f(0, 0), f(2, 0)], 2.0)
    for s in (-1, 0, 1):
        sh.line([f(2, 0), f(14, s * 1.01)], 1.6, INK, None if s == 0 else (8, 3))
        sh.rect(f(14, s * 1.01)[0] - 2, f(14, s * 1.01)[1] - 8, 6, 16, 1.2, fill=GREEN if s else BG)
    sh.circle(f(2, 0), 4, 1.4)
    sh.text(f(2, 0)[0] + 6, f(2, 0)[1] - 14, "SPLIT d = 2 m", size=10, back=True)
    bom(sh, [("1", "PETAL NOSE", "W-Cu 2.67 g", "3"), ("2", "CLONE IMAGE", "— (PHASE)", "2"),
             ("3", "TIMING FUSE RING", "DELAY 5.6 ms", "1"), ("4", "REPLICATOR CHAMBER", "QUARTZ", "1"),
             ("5", "SEED CRYSTAL", "UNKNOWN", "1"), ("6", "GYRO RING", "Ti-6Al-4V", "2"),
             ("7", "SPLITTER CHARGE", "PETN PELLET", "1"), ("8", "PHASE DRIVER", "Cu COIL", "3"),
             ("9", "MASS RESERVOIR", "W-Cu, 27 DISCS", "1"), ("10", "CARTRIDGE CASE", "BRASS C26000", "1"),
             ("11", "PRIMER, BOXER", "SMALL PISTOL", "1")], 15)
    sh.stamp("CLASSIFIED", 1380, 66, -6, 34)
    sh.stamp("RECOVERED", 190, 478, -7, 22)
    sh.note(1030, 790, "×12 ?!!  w/ Ricochet", 30, RED, 3)
    sh.ring((1035, 790), 120, 22)
    sh.note(1030, 850, "found at 4.1 cm depth, ring 7", 22, RED, -2)
    sh.note(1030, 905, "the ghosts show up BEFORE it splits??", 20, INK, -2)
    sh.ring(T(CX, 468), 100, 92, RED, 1.6)
    sh.finish(os.path.join(out, "bp_clone.png"), (BG, INK, RED, (255, 190, 70)))


# =====================================================================================
# Upright sheets: the round stands on its case, every part named by a leader on the right.
CX = 235  # axis of the upright drawings
PX_MM = 25.0


def ell(sh, cx, cy, rx, ry, w=1.3, col=INK, fill=None, a0=0, a1=360, dash=None):
    """Ellipse, or the part of it from a0 to a1 degrees (0..180 is the front half)."""
    if fill is not None:
        sh.d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=fill)
    pts = [(cx + rx * math.cos(t), cy + ry * math.sin(t)) for t in np.linspace(math.radians(a0), math.radians(a1), 72)]
    sh.line(pts, w, col, dash)


def smooth(pts, n=4):
    for _ in range(n):  # Chaikin corner cutting
        out = [pts[0]]
        for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
            out += [(0.75 * x1 + 0.25 * x2, 0.75 * y1 + 0.25 * y2), (0.25 * x1 + 0.75 * x2, 0.25 * y1 + 0.75 * y2)]
        pts = out + [pts[-1]]
    return pts


def rect_mask(sh, x0, y0, x1, y1):
    return sh.mask_poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])


def vcase(sh, top=842, flange=True):
    """The brass case, and the seal flange over it."""
    body = rect_mask(sh, CX - 72, top, CX + 72, 976)
    sh.rect(CX - 72, top, 144, 976 - top, 1.8, fill=BG)
    sh.hatch(ImageChops.multiply(body, rect_mask(sh, CX + 28, 0, W, H)), 90, 3.2, w=0.7)
    sh.hatch(ImageChops.multiply(body, rect_mask(sh, CX - 72, 0, CX - 60, H)), 90, 3.2, w=0.5)
    sh.line([(CX - 44, 850), (CX - 44, 968)], 0.8, DIM)
    sh.rect(CX - 62, 976, 124, 12, 1.4, fill=BG)
    sh.hatch(rect_mask(sh, CX - 62, 976, CX + 62, 988), 0, 3)
    sh.rect(CX - 74, 988, 148, 20, 1.8, fill=BG)
    sh.hatch(rect_mask(sh, CX + 30, 988, CX + 74, 1008), 90, 3.2, w=0.7)
    ell(sh, CX, 1008, 74, 5, 1.4, a0=0, a1=180)
    if not flange:
        return
    sh.rect(CX - 120, 818, 240, 20, 1.6, fill=BG)
    sh.hatch(rect_mask(sh, CX - 120, 818, CX + 120, 838), 45, 4)
    ell(sh, CX, 818, 120, 8, 1.6, fill=BG)
    ell(sh, CX, 838, 120, 8, 1.6, a0=0, a1=180)
    for bx in (-90, -30, 30, 90):
        sh.circle((CX + bx, 829), 4, 1.2, fill=BG)
        sh.line([(CX + bx - 2.5, 829), (CX + bx + 2.5, 829)], 1.0)


def vlabels(sh, items, y0, step):
    """items: (number, point on the part, name, spec). Leaders run right to a column of names."""
    for i, (n, p, name, spec) in enumerate(items):
        y = y0 + i * step
        sh.line([p, (402, y), (424, y)], 0.9, INK)
        sh.circle(p, 2.2, 0, fill=INK)
        sh.circle((436, y), 10, 1.1, fill=BG)
        sh.text(436, y + 1, str(n), "cond", 13, anchor="mm")
        sh.text(452, y - 1, name, "bold", 17, anchor="lb")
        sh.text(453, y + 3, spec, size=11, col=DIM, anchor="lt")


def vdims(sh, segs, total):
    x = 96
    for y0, y1, label in segs:
        sh.dim_v(y0, y1, x, label)
        for y in (y0, y1):
            sh.line([(x - 4, y), (x + 10, y)], 0.8, DIM)
    sh.dim_v(total[0], total[1], 60, total[2])
    for y in total[:2]:
        sh.line([(56, y), (x - 6, y)], 0.8, DIM)


def vcut(sh, y, half=104):
    sh.line([(CX - half, y), (CX + half, y)], 1.0, INK, CHAIN)
    for s in (-1, 1):
        x = CX + s * half
        sh.line([(x, y), (x, y - 14)], 2.0)
        sh.arrow((x, y - 20), (x, y), 9)
        sh.text(x + s * 10, y - 14, "A", "bold", 18, anchor="lm" if s > 0 else "rm")


def skull(sh, x, y):
    for s in (-1, 1):  # crossbones behind
        a, b = (x - 46 * s, y - 6), (x + 46 * s, y + 46)
        sh.line([a, b], 9, INK)
        sh.line([a, b], 5.6, BG)
        d = ((b[0] - a[0]) / math.hypot(b[0] - a[0], b[1] - a[1]), (b[1] - a[1]) / math.hypot(b[0] - a[0], b[1] - a[1]))
        for p in (a, b):
            for o in (-4.2, 4.2):
                sh.circle((p[0] - d[1] * o, p[1] + d[0] * o), 4.6, 1.2, fill=BG)
    sh.d.rounded_rectangle([(x - 19) * S, (y + 4) * S, (x + 19) * S, (y + 28) * S], radius=6 * S, fill=BG, outline=INK, width=round(1.5 * S))
    sh.circle((x, y - 12), 30, 1.6, fill=BG)
    sh.rect(x - 18, y + 2, 36, 8, 0, fill=BG)
    for ex in (-12, 12):
        sh.d.ellipse([(x + ex - 9) * S, (y - 19) * S, (x + ex + 9) * S, (y - 1) * S], fill=INK)
    sh.d.polygon([(x * S, (y + 1) * S), ((x - 4) * S, (y + 9) * S), ((x + 4) * S, (y + 9) * S)], fill=INK)
    sh.line([(x - 15, y + 17), (x + 15, y + 17)], 1.0)
    for tx in range(-12, 13, 6):
        sh.line([(x + tx, y + 11), (x + tx, y + 25)], 1.0)
    sh.line([(x + 9, y - 41), (x + 5, y - 34), (x + 9, y - 30), (x + 4, y - 24)], 1.0)


def helix(side):
    """A feed tube from the flask shoulder round the barrel up to the hub: (x, y, in front?)."""
    th0 = -math.pi / 2 if side < 0 else math.pi / 2
    pts = [(CX + side * 70, 610, True)]
    for t in np.linspace(0, 1, 200):
        th = th0 + 3 * math.pi * t
        r = 66 - 38 * max(0.0, (t - 0.82) / 0.18)
        pts.append((CX + r * math.sin(th), 592 - 262 * t, math.cos(th) >= 0))
    return pts


def runs(pts):
    out, cur = [], [pts[0]]
    for p in pts[1:]:
        if p[2] != cur[-1][2]:
            out.append(cur)
            cur = [cur[-1]]
        cur.append(p)
    out.append(cur)
    return [([(x, y) for x, y, _ in r], r[-1][2]) for r in out]


def right_panel(sh, calc, sec_title, detail, box_title):
    calcs(sh, 896, 140, 648, 360, calc)
    sh.text(985, 700, sec_title, "cond", 17, anchor="mt")
    sh.text(985, 720, "SCALE 4:1", size=11, col=DIM, anchor="mt")
    sh.magnify(*detail)
    sh.box(1290, 515, 254, 255, box_title)


# =====================================================================================
def sheet_tesla(out):
    sh = Sheet(22)
    sh.frame("TESLA ROUND  Mk.II  \"STORMCOIL\"", "9×19 · A RESONANT COIL CHARGES IN FLIGHT, THE TOP SPHERE ARCS TO NEARBY TARGETS · EXTERIOR VIEW",
             "PO-BP-0002", 2, "D")
    rnd = sh.rnd
    vcase(sh)
    # capacitor bank: a ring of cans seen through a window, status LED
    sh.rect(CX - 62, 692, 124, 126, 1.8, fill=BG)
    sh.hatch(rect_mask(sh, CX + 40, 692, CX + 62, 818), 90, 3.2, w=0.6)
    sh.rect(CX - 50, 702, 100, 108, 1.3, fill=BG)
    for cx in (-32, 0, 32):
        sh.rect(CX + cx - 12, 716, 24, 88, 1.3, fill=BG)
        ell(sh, CX + cx, 716, 12, 4, 1.2, fill=BG)
        sh.hatch(rect_mask(sh, CX + cx + 4, 718, CX + cx + 12, 804), 90, 2.5, w=0.6)
        sh.line([(CX + cx - 12, 730), (CX + cx + 12, 730)], 0.8)
        sh.text(CX + cx, 760, "+", "bold", 13, anchor="mm")
    sh.circle((CX + 50, 698), 3.5, 1.0, fill=RED)
    # resonant coil on its bobbin, a quartz core tube with the arc inside
    sh.rect(CX - 34, 528, 68, 166, 1.6, fill=BG)
    sh.line([(CX - 28, 532), (CX - 28, 690)], 0.8, DIM)
    sh.line([(CX + 28, 532), (CX + 28, 690)], 0.8, DIM)
    ell(sh, CX, 528, 34, 6, 1.4, fill=BG)
    for i in range(7):
        ell(sh, CX, 556 + i * 20, 88, 12, 1.0, DIM, a0=180, a1=360, dash=(4, 3))
    core = smooth([(CX, 534)] + [(CX + rnd.uniform(-14, 14), y) for y in range(552, 680, 16)] + [(CX, 690)], 1)
    arcs = [jagged(rnd, core[i], core[i + 1], 3, 0.3) for i in range(len(core) - 1)]
    arcs = [sum((a[:-1] for a in arcs), []) + [core[-1]]]
    for k in range(4):
        p = arcs[0][rnd.randrange(10, len(arcs[0]) - 10)]
        arcs.append(jagged(rnd, p, (p[0] + rnd.choice((-1, 1)) * rnd.uniform(12, 24), p[1] + rnd.uniform(-14, 14)), 3, 0.3))
    sh.glow(arcs, 1.3)
    for y in (540, 684):  # bobbin flanges
        sh.d.ellipse([(CX - 94) * S, (y - 13) * S, (CX + 94) * S, (y + 13) * S], fill=BG)
        ell(sh, CX, y, 94, 13, 1.5)
        ell(sh, CX, y + 4, 94, 13, 1.2, a0=0, a1=180)
    sh.line([(CX - 34, 527), (CX - 34, 553)], 1.4)
    sh.line([(CX + 34, 527), (CX + 34, 553)], 1.4)
    for i in range(7):  # the turns in front, thick copper
        y = 556 + i * 20
        ell(sh, CX, y, 88, 12, 5.2, INK, a0=0, a1=180)
        ell(sh, CX, y, 88, 12, 2.0, BG, a0=8, a1=172)
    # electronics bay: window on a control board with chips, heat sinks either side
    sh.rect(CX - 58, 300, 116, 228, 1.8, fill=BG)
    ell(sh, CX, 528, 58, 8, 1.4, a0=0, a1=180)
    sh.hatch(rect_mask(sh, CX + 46, 300, CX + 58, 528), 90, 3, w=0.6)
    sh.rect(CX - 46, 312, 92, 206, 1.3, fill=BG)
    sh.rect(CX - 40, 318, 80, 194, 1.0, DIM)
    sh.hatch(rect_mask(sh, CX - 40, 318, CX + 40, 512), 0, 9, w=0.4)
    chips = [(CX - 32, 330, 30, 26, "U1"), (CX + 2, 372, 32, 34, "U2"), (CX - 30, 436, 26, 22, "Q1"), (CX + 6, 456, 26, 40, "U3")]
    for x, y, w, h, name in chips:
        sh.rect(x, y, w, h, 1.3, fill=INK)
        for py in np.arange(y + 4, y + h - 2, 5):
            sh.line([(x - 4, py), (x, py)], 1.0)
            sh.line([(x + w, py), (x + w + 4, py)], 1.0)
        sh.text(x + w / 2, y + h / 2, name, "cond", 11, BG, "mm")
    for tr in ([(CX - 17, 356), (CX - 17, 368), (CX + 2, 380)], [(CX + 18, 406), (CX + 18, 420), (CX - 17, 436)],
               [(CX - 4, 447), (CX + 6, 466)], [(CX - 34, 360), (CX - 34, 500), (CX + 19, 500)], [(CX + 34, 330), (CX + 34, 372)]):
        sh.line(tr, 1.0)
    for x, y in ((CX + 22, 336), (CX - 22, 482), (CX - 8, 500)):
        sh.circle((x, y), 4, 1.1, fill=BG)
        sh.line([(x - 2.5, y), (x + 2.5, y)], 0.9)
    sh.rect(CX - 38, 410, 20, 7, 1.0, fill=BG)
    sh.d.ellipse([(CX + 14) * S, 326 * S, (CX + 30) * S, 334 * S], outline=INK, width=round(1.1 * S))
    for s in (-1, 1):
        x0, x1 = CX + s * 58, CX + s * 84
        sh.poly([(x0, 330), (x1, 320), (x1, 478), (x0, 486)], 1.5, fill=BG)
        for y in range(330, 478, 8):
            sh.line([(x0, y + 4), (x1, y)], 1.0)
    # insulator neck with sheds
    prof = [(18, 300), (18, 292), (28, 290), (28, 284), (18, 282), (18, 274), (28, 272), (28, 266), (18, 264), (18, 256), (24, 254), (24, 246)]
    neck = [(CX - w, y) for w, y in prof] + [(CX + w, y) for w, y in prof[::-1]]
    sh.poly(neck, 1.5, fill=BG)
    sh.hatch(sh.mask_poly([(CX + 6, y) for _, y in prof] + [(CX + w, y) for w, y in prof[::-1]]), 90, 2.8, w=0.6)
    # HV leads up the outside, clipped on
    for s in (-1, 1):
        lead = smooth([(CX + s * 60, 812), (CX + s * 100, 770), (CX + s * 106, 640), (CX + s * 100, 520), (CX + s * 94, 420),
                       (CX + s * 92, 300), (CX + s * 64, 258), (CX + s * 26, 250)], 4)
        sh.line(lead, 6.0)
        sh.line(lead, 2.6, BG)
        for k in (0.18, 0.42, 0.7):
            x, y = lead[int(k * (len(lead) - 1))]
            sh.rect(x - 6, y - 3, 12, 6, 1.2, fill=BG)
    # top: a rod and the sphere, two side electrodes with balls, arcs between
    sh.rect(CX - 5, 196, 10, 50, 1.3, fill=BG)
    for s in (-1, 1):
        base, end = (CX + s * 20, 252), (CX + s * 78, 202)
        sh.line([base, end], 5.0)
        sh.line([base, end], 2.0, BG)
        sh.circle(end, 9, 1.5, fill=BG)
        sh.hatch(sh.mask_poly(disc((end[0] + 3, end[1] + 3), 7)), 45, 2.2, w=0.5)
    sph = (CX, 182)
    sh.circle(sph, 32, 1.8, fill=BG)
    sh.hatch(ImageChops.subtract(sh.mask_poly(disc(sph, 31)), sh.mask_poly(disc((sph[0] - 9, sph[1] - 9), 30))), 45, 2.4, w=0.6)
    sh.line([(sph[0] + 22 * math.cos(t), sph[1] + 22 * math.sin(t)) for t in np.linspace(3.5, 4.4, 12)], 2.2)
    sp = []
    for s in (-1, 1):
        sp.append(jagged(rnd, (CX + s * 70, 198), (CX + s * 30, 186), 4, 0.35))
        sp.append(jagged(rnd, (CX + s * 74, 194), (CX + s * 26, 170), 4, 0.35))
    for ang in (-2.2, -1.57, -0.9):
        p = (sph[0] + 32 * math.cos(ang), sph[1] + 32 * math.sin(ang))
        sp.append(jagged(rnd, p, (p[0] + 34 * math.cos(ang), p[1] + 30 * math.sin(ang)), 4, 0.3))
    sh.glow(sp, 1.1)

    vcut(sh, 600, 116)
    lead_r = smooth([(CX + 60, 812), (CX + 100, 770), (CX + 106, 640), (CX + 100, 520), (CX + 94, 420),
                     (CX + 92, 300), (CX + 64, 258), (CX + 26, 250)], 4)
    vlabels(sh, [
        (1, (CX + 23, 160), "TOP SPHERE", "SPUN Al · Ø2.6 · ARCS FROM HERE"),
        (2, (CX + 84, 196), "SIDE ELECTRODES ×2", "W-Th ROD · BALL Ø0.7 · GAP 1.8"),
        (3, (CX + 28, 270), "INSULATOR NECK", "ALUMINA 99.5 % · 3 SHEDS"),
        (4, (CX + 34, 390), "CONTROL BOARD", "4-LAYER · U1 TIMER · U2 RF · Q1 IGBT"),
        (5, (CX + 84, 420), "HEAT SINKS ×2", "Al 6063 · 18 FINS EACH"),
        (6, lead_r[int(0.42 * (len(lead_r) - 1))], "HV LEADS ×2", "SILICONE 20 kV · 3 CLIPS"),
        (7, (CX + 20, 566), "CORE TUBE", "QUARTZ · ARGON 0.2 bar"),
        (8, (CX + 88, 636), "RESONANT COIL", "Cu Ø0.4 · 7 T ON PEEK BOBBIN"),
        (9, (CX + 40, 760), "CAPACITOR BANK", "6 × 0.47 µF · 9 kV"),
        (10, (CX + 112, 826), "SEAL FLANGE", "FKM · 4 BOLTS"),
        (11, (CX + 60, 910), "CARTRIDGE CASE", "BRASS C26000 · 9×19"),
        (12, (CX + 50, 998), "RIM + PRIMER", "BOXER · SMALL PISTOL"),
    ], 160, 62)
    vdims(sh, [(150, 246, "%.1f" % (96 / PX_MM)), (300, 528, "%.1f" % (228 / PX_MM)), (540, 684, "%.1f" % (144 / PX_MM)),
               (842, 1008, "%.1f" % (166 / PX_MM))], (150, 1008, "%.1f OAL" % (858 / PX_MM)))
    sh.dim_h(CX - 94, CX + 94, 1034, "Ø%.2f COIL" % (188 / PX_MM))

    right_panel(sh, [
        ("1 · CAPACITOR BANK", ["C = 6 × 0.47 µF = 2.82 µF      V = 9 kV",
                                "E = ½ · C · V² = ½ · 2.82e-6 · (9e3)² ≈ 114 J"]),
        ("2 · RESONANT COIL", ["L = µ0 · N² · A / ℓ = 4π·1e-7 · 7² · π(3.5 mm)² / 6 mm ≈ 0.40 µH",
                               "f = 1 / (2π · √(L · C)) = 1 / (2π · 1.06e-6) ≈ 150 kHz"]),
        ("3 · TRIGGER (U1)", ["t = 1.1 · R · C = 1.1 · 10 kΩ · 0.1 µF = 1.1 ms after muzzle exit"]),
        ("4 · ARC CHAIN", ["n = floor(E / E_arc) = floor(114 J / 30 J) = 3 TARGETS",
                           "reach ≈ 3.2 cm in clean air, ≈ 1.3 m along the ionised trail"]),
        ("5 · HEAT (Q1)", ["P = I² · R = (40 A)² · 0.05 Ω = 80 W for 0.2 ms → 16 mJ, fins take it"]),
    ], "SECTION A-A", ((CX - 6, 380), 34, (1160, 610), 80, "DETAIL B", "B"), "CIRCUIT")
    # section A-A through the coil: the turn, potting, quartz tube, the arc
    c, s = (985, 610), 0.78
    sh.hatch(annulus(sh, c, 92 * s, 84 * s), 45, 2.6)
    sh.circle(c, 92 * s, 1.5)
    sh.circle(c, 84 * s, 1.1)
    sh.stipple(annulus(sh, c, 83 * s, 35 * s), 220, 0.8)
    sh.hatch(annulus(sh, c, 34 * s, 28 * s), 0, 2.5)
    sh.circle(c, 34 * s, 1.3)
    sh.circle(c, 28 * s, 1.0)
    sh.stipple(sh.mask_poly(disc(c, 27 * s)), 60, 0.6, INK)
    sh.glow([jagged(rnd, (c[0] - 6, c[1] - 4), (c[0] + 6, c[1] + 4), 3, 0.5)], 1.2)
    for sx in (-1, 1):
        sh.circle((c[0] + sx * 106 * s, c[1]), 4.5, 1.4, fill=BG)
        sh.circle((c[0] + sx * 106 * s, c[1]), 1.6, 0, fill=INK)
    # circuit: bank, gap, coil, sphere, target; then the chips
    X0, y0 = 1306, 590
    sh.line([(X0, y0 - 18), (X0, y0 - 4)], 1.2)
    sh.line([(X0 - 10, y0 - 4), (X0 + 10, y0 - 4)], 2.0)
    sh.line([(X0 - 10, y0 + 4), (X0 + 10, y0 + 4)], 2.0)
    sh.line([(X0, y0 + 4), (X0, y0 + 22), (X0 + 60, y0 + 22)], 1.2)
    sh.text(X0 - 14, y0, "C", size=10, anchor="rm")
    sh.line([(X0, y0 - 18), (X0 + 16, y0 - 18)], 1.2)
    sh.arrow((X0 + 23, y0 - 18), (X0 + 16, y0 - 18), 6)
    sh.arrow((X0 + 27, y0 - 18), (X0 + 34, y0 - 18), 6)
    sh.text(X0 + 25, y0 - 26, "Q1", size=9, anchor="mb")
    sh.line([(X0 + 34, y0 - 18), (X0 + 60, y0 - 18), (X0 + 60, y0 - 14)], 1.2)
    for k in range(3):
        yy = y0 - 14 + 6 + k * 12
        sh.line([(X0 + 60 + 6 * math.sin(t), yy - 6 * math.cos(t)) for t in np.linspace(0, math.pi, 10)], 1.2)
    sh.line([(X0 + 60, y0 + 22), (X0 + 60, y0 + 22)], 1.2)
    sh.text(X0 + 74, y0, "L", size=10, anchor="lm")
    sh.line([(X0 + 60, y0 - 18), (X0 + 60, y0 - 40), (X0 + 118, y0 - 40)], 1.2)
    sh.circle((X0 + 126, y0 - 40), 8, 1.3)
    sh.glow([jagged(rnd, (X0 + 134, y0 - 40), (X0 + 196, y0 - 40), 4, 0.35)], 1.0)
    sh.rect(X0 + 198, y0 - 56, 7, 32, 1.2, fill=BG)
    sh.text(X0 + 202, y0 - 18, "TARGET", size=9, anchor="mt")
    for i, s_ in enumerate(["U1  TIMER, 1.1 ms DELAY", "U2  RF TRIGGER / PROXIMITY", "U3  CHARGE CONTROL",
                            "Q1  IGBT 1.2 kV, 40 A", "C   6 × 0.47 µF, 9 kV"]):
        sh.text(1302, 650 + i * 21, s_, size=11)
    # ring-down
    sh.box(440, 878, 440, 170, "FIG. 2 — RING-DOWN AT THE SPHERE")
    f = sh.plot(444, 906, 432, 140, (0, 40), (-10, 10), "t [µs]", "V [kV]", (0, 10, 20, 30, 40), (-9, 0, 9))
    sh.line([f(t, 9 * math.exp(-t / 12) * math.cos(2 * math.pi * 0.150 * t)) for t in np.linspace(0, 40, 500)], 1.3)
    for sg in (-1, 1):
        sh.line([f(t, sg * 9 * math.exp(-t / 12)) for t in np.linspace(0, 40, 50)], 0.9, INK, (4, 3))
    bom(sh, [("1", "TOP SPHERE", "SPUN Al 1100", "1"), ("2", "SIDE ELECTRODE", "W-Th, BALL Ø0.7", "2"),
             ("3", "INSULATOR NECK", "ALUMINA 99.5 %", "1"), ("4", "CONTROL BOARD", "FR4, U1-U3, Q1", "1"),
             ("5", "HEAT SINK", "Al 6063", "2"), ("6", "HV LEAD", "SILICONE 20 kV", "2"),
             ("7", "CORE TUBE", "QUARTZ, ARGON", "1"), ("8", "RESONANT COIL", "Cu Ø0.4, 7 T", "1"),
             ("9", "CAPACITOR BANK", "6 × 0.47 µF", "1"), ("10", "SEAL FLANGE", "FKM + 4 BOLTS", "1"),
             ("11", "CARTRIDGE CASE", "BRASS C26000", "1"), ("12", "PRIMER, BOXER", "SMALL PISTOL", "1")], 15)
    sh.stamp("CLASSIFIED", 1380, 66, -6, 34)
    sh.stamp("LIVE — 9 kV", 770, 850, 7, 22)
    sh.note(1030, 790, "DO NOT HOLD WHILE CHARGED!!", 23, RED, -2)
    sh.scrawl([(900, 805), (1165, 800)])
    sh.note(1030, 850, "Lightning + Ricochet = ???", 25, RED, 3)
    sh.note(1040, 905, "board fried twice. fins help", 22, INK, -2)
    sh.ring((CX, 612), 118, 92, RED, 1.6)
    sh.finish(os.path.join(out, "bp_tesla.png"), ((12, 22, 40), (150, 232, 255), (255, 100, 84)))


# =====================================================================================
def sheet_toxin(out):
    sh = Sheet(33)
    sh.frame("TOXIN ROUND  Mk.III  \"VIPER\"", "9×19 · A GLASS FLASK FEEDS THE NEEDLE THROUGH TWO COILED TUBES · EXTERIOR VIEW",
             "PO-BP-0003", 3, "C")
    vcase(sh, 860, False)
    # knurled collar from the case mouth up to the cradle
    sh.rect(CX - 80, 836, 160, 24, 1.6, fill=BG)
    for x in range(CX - 76, CX + 80, 6):
        sh.line([(x, 838), (x, 858)], 0.8)
    sh.hatch(rect_mask(sh, CX + 44, 836, CX + 80, 860), 90, 3, w=0.6)
    ell(sh, CX, 860, 80, 6, 1.4, a0=0, a1=180)
    # the flask of agent with the skull insert floating in it
    fc, fr, level = (CX, 705), 112, 640
    sh.circle(fc, fr, 1.9, fill=BG)
    inner = sh.mask_poly(disc(fc, fr - 5, 120))
    liq = ImageChops.multiply(inner, rect_mask(sh, 0, level, W, H))
    sh.im.paste(GREEN + (255,), (0, 0), liq)
    sh.hatch(ImageChops.multiply(liq, rect_mask(sh, CX + 52, 0, W, H)), 90, 3, INK, 0.5)
    hc = math.sqrt((fr - 5) ** 2 - (fc[1] - level) ** 2)
    ell(sh, CX, level, hc, 6, 1.1)
    sh.circle(fc, fr - 5, 1.0)
    skull(sh, CX, 716)
    for dx, y, r in ((-66, 694, 5), (-54, 740, 3), (60, 686, 4), (72, 730, 2.5), (34, 660, 2.2), (-40, 656, 1.8), (10, 752, 2.4)):
        sh.circle((CX + dx, y), r, 0.9, fill=BG)
    sh.line([(fc[0] + (fr - 14) * math.cos(t), fc[1] + (fr - 14) * math.sin(t)) for t in np.linspace(2.55, 3.05, 14)], 3.2, BG)
    sh.line([(fc[0] + (fr - 12) * math.cos(t), fc[1] + (fr - 12) * math.sin(t)) for t in np.linspace(3.5, 4.2, 16)], 1.3)
    sh.text(CX + 60, level - 10, "0.12", size=9, anchor="lm")
    sh.line([(CX + 50, level), (CX + 58, level)], 1.0)
    # cradle: a bronze cup holding the lower flask, four claws up the glass
    cup = smooth([(CX - 82, 836), (CX - 92, 812), (CX - 100, 786), (CX - 104, 762)], 3)
    cup = cup + [(CX + 104, 762)] + [(2 * CX - x, y) for x, y in cup[::-1]]
    sh.poly(cup, 1.8, fill=BG)
    cm = sh.mask_poly(cup)
    sh.hatch(ImageChops.multiply(cm, rect_mask(sh, CX + 52, 0, W, H)), 90, 3, w=0.6)
    sh.hatch(ImageChops.multiply(cm, rect_mask(sh, 0, 0, CX - 84, H)), 90, 3, w=0.5)
    for y, rx in ((786, 100), (812, 92)):
        ell(sh, CX, y, rx, 8, 1.0, DIM, a0=0, a1=180)
    ell(sh, CX, 762, 104, 9, 1.8, a0=0, a1=180)
    ell(sh, CX, 836, 82, 6, 1.3, a0=0, a1=180)
    sh.circle((CX, 824), 4, 1.2, fill=BG)  # gas port
    for s in (-1, 1):  # side claws along the silhouette
        a0, a1 = math.asin((762 - 705) / 116), math.asin((672 - 705) / 116)
        ts = np.linspace(a0, a1, 16)
        side = [(CX + s * 112 * math.cos(t), 705 + 112 * math.sin(t)) for t in ts]
        rim = [(CX + s * 122 * math.cos(t), 705 + 122 * math.sin(t)) for t in ts]
        sh.poly(side + rim[::-1], 1.5, fill=BG)
        sh.hatch(sh.mask_poly(side + rim[::-1]), 45, 2.6)
        sh.circle(((side[-1][0] + rim[-1][0]) / 2, (side[-1][1] + rim[-1][1]) / 2), 4.5, 1.3, fill=BG)
    for s in (-1, 1):  # front claws lying on the glass
        lats = np.linspace(math.asin((705 - 764) / 112), math.asin((705 - 668) / 112), 16)
        edge = lambda k: [(CX + s * (112 * math.cos(la) * (0.60 + k)), 705 - 112 * math.sin(la)) for la in lats]
        strip = edge(-0.045) + edge(0.045)[::-1]
        sh.poly(strip, 1.5, fill=BG)
        sh.hatch(sh.mask_poly(strip), 45, 2.6)
        tip = (CX + s * 112 * math.cos(lats[-1]) * 0.60, 705 - 112 * math.sin(lats[-1]))
        sh.circle(tip, 5, 1.3, fill=BG)
        sh.circle(tip, 1.5, 0, fill=INK)
    # cap over the flask mouth: two tube ports, the clamp ring above it
    cap = [(CX - 30, 556), (CX + 30, 556), (CX + 30, 580), (CX + 64, 604), (CX + 66, 620), (CX - 66, 620), (CX - 64, 604), (CX - 30, 580)]
    sh.poly(cap, 1.6, fill=BG)
    sh.hatch(ImageChops.multiply(sh.mask_poly(cap), rect_mask(sh, CX + 20, 0, W, H)), 90, 3, w=0.6)
    ell(sh, CX, 620, 66, 6, 1.4, a0=0, a1=180)
    for bx in (-44, 0, 44):
        sh.circle((CX + bx, 610), 3.2, 1.1, fill=BG)
    for s in (-1, 1):
        sh.poly([(CX + s * 58, 598), (CX + s * 72, 604), (CX + s * 72, 616), (CX + s * 60, 616)], 1.3, fill=BG)
    sh.rect(CX - 40, 566, 80, 18, 1.4, fill=BG)
    sh.hatch(rect_mask(sh, CX - 40, 566, CX + 40, 584), -45, 3)
    for sx in (-33, 33):
        sh.circle((CX + sx, 575), 3, 1.0, fill=BG)
    # injector barrel, full of agent, graduated
    sh.rect(CX - 52, 344, 104, 212, 1.7, fill=BG)
    sh.im.paste(GREEN + (255,), (0, 0), rect_mask(sh, CX - 47, 362, CX + 47, 552))
    sh.hatch(rect_mask(sh, CX + 26, 362, CX + 47, 552), 90, 3, INK, 0.5)
    ell(sh, CX, 362, 47, 6, 1.1)
    sh.line([(CX - 34, 374), (CX - 34, 540)], 3.2, BG)
    for x in (CX - 47, CX + 47):
        sh.line([(x, 350), (x, 552)], 1.0)
    pts = [helix(-1), helix(1)]
    for p in pts:  # the turns behind the glass
        for r, front in runs(p):
            if not front:
                sh.line(r, 1.2, DIM, (5, 3))
    for i in range(17):
        y = 548 - i * 11.5
        sh.line([(CX - 47, y), (CX - 47 + (12 if i % 4 == 0 else 6), y)], 1.1)
        if i % 4 == 0:
            sh.text(CX - 60, y, "%.2f" % (0.01 * i / 4), size=9, anchor="rm", back=True)
    ell(sh, CX, 344, 52, 9, 1.5, fill=BG)
    ell(sh, CX, 556, 52, 9, 1.5, a0=0, a1=180)
    sh.line([(CX - 47, 352), (CX + 47, 352)], 2.0)
    # hub, luer ring, needle and a drop at its tip
    sh.poly([(CX - 6, 300), (CX + 6, 300), (CX + 26, 338), (CX - 26, 338)], 1.4, fill=BG)
    sh.hatch(sh.mask_poly([(CX - 6, 300), (CX + 6, 300), (CX + 26, 338), (CX - 26, 338)]), 45, 3)
    sh.rect(CX - 30, 330, 60, 14, 1.4, fill=BG)
    sh.hatch(rect_mask(sh, CX - 30, 330, CX + 30, 344), -45, 3)
    sh.rect(CX - 3.5, 168, 7, 132, 1.3, fill=BG)
    sh.poly([(CX - 3.5, 168), (CX + 3.5, 150), (CX + 3.5, 168)], 1.2, fill=BG)
    sh.line([(CX, 162), (CX, 298)], 0.7, DIM, (4, 3))
    sh.circle((CX + 10, 162), 3.6, 1.0, fill=GREEN)
    sh.poly([(CX + 7, 160), (CX + 10, 152), (CX + 13, 160)], 0.9, fill=GREEN)
    # the tubes in front, full of agent, with the flow marked
    for p in pts:
        for r, front in runs(p):
            if front:
                sh.line(r, 8.4)
                sh.line(r, 4.8, GREEN)
                for i in range(12, len(r) - 6, 26):
                    sh.arrow(r[i + 4], r[i], 6, INK)
    sh.circle((CX - 66, 612), 5, 1.2, fill=BG)
    sh.circle((CX + 66, 612), 5, 1.2, fill=BG)

    vcut(sh, 470, 104)
    front_r = [q for r, fr_ in runs(helix(1)) if fr_ for q in r]
    tube_pt = min(front_r, key=lambda q: abs(q[1] - 420) + abs(q[0] - CX - 60) * 0.3)
    vlabels(sh, [
        (1, (CX + 3, 200), "INJECTOR NEEDLE", "316L · 23G · BEVEL 12°"),
        (2, (CX + 24, 336), "NEEDLE HUB + FOIL", "LUER LOCK · PET FOIL 12 µm, BURSTS ON IMPACT"),
        (3, tube_pt, "FEED TUBES ×2", "PTFE Ø1.2 · 1.5 TURNS ROUND THE BARREL"),
        (4, (CX + 50, 500), "INJECTOR BARREL", "BOROSILICATE · 0.04 ml / DIV 0.0025"),
        (5, (CX + 52, 606), "FLASK CAP + CLAMP", "BRASS · 2 TUBE PORTS · 2 × M1 SCREW"),
        (6, (CX + 97, 650), "TOXIN FLASK", "GLASS 0.4 mm WALL · Ø9.0"),
        (7, (CX + 66, 770), "AGENT \"V-7\"", "0.12 ml · GREEN · VISCOUS"),
        (8, (CX + 22, 708), "SKULL INSERT", "BONE CERAMIC · BATCH MARK, FLOATS"),
        (9, (CX + 98, 800), "FLASK CRADLE", "Al BRONZE · 4 CLAWS · FKM SEAT · GAS PORT"),
        (10, (CX + 60, 930), "CARTRIDGE CASE", "BRASS C26000 · 9×19 · KNURLED COLLAR"),
        (11, (CX + 50, 998), "RIM + PRIMER", "BOXER · SMALL PISTOL"),
    ], 168, 66)
    vdims(sh, [(150, 344, "%.1f" % (194 / PX_MM)), (344, 556, "%.1f" % (212 / PX_MM)), (593, 817, "Ø%.1f" % (224 / PX_MM)),
               (836, 1008, "%.1f" % (172 / PX_MM))], (150, 1008, "%.1f OAL" % (858 / PX_MM)))
    sh.dim_h(CX - 104, CX + 104, 1034, "Ø%.2f CRADLE" % (208 / PX_MM))

    right_panel(sh, [
        ("1 · FLASK FILL", ["V = 4/3 · π · r³ = 4/3 · π · (4.3 mm)³ ≈ 333 mm³",
                            "fill 36 %  →  0.12 ml of agent"]),
        ("2 · GAS DRIVE", ["p = n · R · T / V = 2.0e-6 mol · 8.314 · 1200 K / 5.0e-8 m³ ≈ 399 kPa",
                           "bled from the propellant through the cradle port"]),
        ("3 · FEED TUBES (POISEUILLE)", ["Q = π · r⁴ · Δp / (8 · η · ℓ)",
                                         "  = π · (0.3 mm)⁴ · 399 kPa / (8 · 0.05 Pa·s · 42 mm) ≈ 0.60 ml/s",
                                         "two tubes: 1.2 ml/s  →  flask empties in 0.10 s"]),
        ("4 · DAMAGE OVER TIME", ["D(t) = D0 · e^(−k·t)   k = 0.35 1/s   ∫ D dt = D0 / k ≈ 2.86 · D0"]),
    ], "SECTION A-A", ((CX, 330), 28, (1160, 610), 80, "DETAIL B", "B"), "FLOW PATH")
    # section A-A through the barrel and both tubes
    c, s = (985, 610), 1.05
    sh.hatch(annulus(sh, c, 52 * s, 47 * s), 70, 3)
    sh.circle(c, 52 * s, 1.5)
    sh.im.paste(GREEN + (255,), (0, 0), sh.mask_poly(disc(c, 47 * s)))
    sh.circle(c, 47 * s, 1.0)
    for side in (-1, 1):
        th = (-math.pi / 2 if side < 0 else math.pi / 2) + 3 * math.pi * (592 - 470) / 262
        p = (c[0] + 66 * s * math.sin(th), c[1] + 66 * s * math.cos(th))
        sh.circle(p, 6.5, 1.4, fill=BG)
        sh.circle(p, 3.8, 0, fill=GREEN)
    sh.circle((c[0] - 14, c[1] - 10), 5, 1.0, fill=BG)
    sh.line([(c[0] - 80, c[1]), (c[0] + 80, c[1])], 0.7, DIM, CHAIN)
    # flow path
    steps = ["FLASK · 0.12 ml", "FEED TUBES ×2", "BARREL · 0.04 ml", "FOIL BURSTS ON IMPACT", "NEEDLE", "TARGET · DoT 0.5 s"]
    for i, s_ in enumerate(steps):
        y = 548 + i * 37
        sh.rect(1317, y, 200, 24, 1.2, fill=BG)
        sh.text(1417, y + 12, s_, size=11, anchor="mm")
        if i:
            sh.line([(1417, y - 13), (1417, y - 2)], 2.4, GREEN)
            sh.arrow((1417, y), (1417, y - 8), 7, GREEN)
    sh.box(440, 878, 440, 170, "FIG. 3 — DOSE ON TARGET")
    f = sh.plot(444, 906, 432, 140, (0, 8), (0, 1.1), "t [s]", "D / D0", range(0, 9), (0, 0.5, 1))
    for i in range(1, 14):
        t = i * 0.5
        y = math.exp(-0.35 * t)
        sh.rect(f(t, 0)[0] - 5, f(t, y)[1], 10, f(t, 0)[1] - f(t, y)[1], 1.0, INK, GREEN)
    sh.line([f(t, math.exp(-0.35 * t)) for t in np.linspace(0, 8, 80)], 2.0)
    sh.line([f(0, 0.1), f(8, 0.1)], 0.9, INK, (6, 3))
    bom(sh, [("1", "INJECTOR NEEDLE", "316L, 23G", "1"), ("2", "NEEDLE HUB + FOIL", "LUER / PET 12 µm", "1"),
             ("3", "FEED TUBE", "PTFE Ø1.2", "2"), ("4", "INJECTOR BARREL", "BOROSIL. 0.04 ml", "1"),
             ("5", "FLASK CAP + CLAMP", "BRASS + 2 × M1", "1"), ("6", "TOXIN FLASK", "GLASS 0.4 WALL", "1"),
             ("7", "AGENT V-7", "0.12 ml, GREEN", "1"), ("8", "SKULL INSERT", "BONE CERAMIC", "1"),
             ("9", "FLASK CRADLE", "Al BRONZE, 4 CLAWS", "1"), ("10", "CARTRIDGE CASE", "BRASS C26000", "1"),
             ("11", "PRIMER, BOXER", "SMALL PISTOL", "1")], 15)
    hx, hy = 1470, 455  # hazard tag: a skull in a diamond
    sh.poly([(hx, hy - 30), (hx + 30, hy), (hx, hy + 30), (hx - 30, hy)], 2.0, RED)
    sh.circle((hx, hy - 6), 10, 0, fill=RED)
    sh.rect(hx - 5, hy + 1, 10, 8, 0, fill=RED)
    for ex in (-4, 4):
        sh.circle((hx + ex, hy - 6), 2.7, 0, fill=BG)
    for sg in (-1, 1):
        sh.line([(hx - 14, hy + 7 + 7 * sg), (hx + 14, hy + 7 - 7 * sg)], 2.2, RED)
    sh.stamp("CLASSIFIED", 1380, 66, -6, 34)
    sh.stamp("REJECTED", 760, 128, -7, 22)
    sh.note(1040, 790, "LEAKS!!  attempt #3", 30, RED, 3)
    sh.note(1040, 850, "tubes kink at the 2nd turn", 24, INK, -2)
    sh.note(1040, 905, "who filled the last batch?", 22, INK, -3)
    sh.ring((CX, 714), 72, 60, RED, 1.6)
    sh.finish(os.path.join(out, "bp_toxin.png"), ((228, 222, 200), (52, 50, 118), (196, 44, 40), (64, 168, 58)))


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    sheet_clone(out)
    sheet_tesla(out)
    sheet_toxin(out)
