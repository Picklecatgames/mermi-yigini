# Puts our blueprints (tools/draw_blueprints.py) on the investigation board in place of three of
# its photos: the two mugshots and the street photo over them. Writes the board's base colour atlas
# for tools/build_board.py; the other photos, the newspaper and the #1-#6 cards stay.
# Run: python tools/board_photos.py <DefaultMaterial_Base_color.png> <blueprints dir> <out.png>
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# Each card: its UV island's box in the atlas (u0, v0, u1, v1 px), which way the board's
# right and down run in the atlas, the sheet and the part of it shown.
CARDS = [
    ((3257, 2589, 3484, 2884), ("-u", "-v"), "bp_tesla.png", (36, 36, 828, 1064)),  # the bald man
    ((3612, 2591, 3835, 2888), ("-u", "-v"), "bp_toxin.png", (40, 36, 810, 1064)),  # the curly-haired man
    ((2960, 1449, 3179, 1765), ("+v", "-u"), "bp_clone.png", (0, 0, 1600, 1100)),   # the street over them
]
PAPER = np.array([228, 214, 180], np.float32)  # the print's border, gone yellow


def blotch(rng, h, w, cells, blur):
    """Soft random field 0..1 the size of the card."""
    n = Image.fromarray((rng.random((max(2, h // cells), max(2, w // cells))) * 255).astype(np.uint8))
    return np.asarray(n.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(blur))).astype(np.float32) / 255


def card(sheet, crop, w, h, seed):
    """The sheet as an old print, w by h as it hangs: yellowed border, faded and browned towards
    sepia, scratches, a crease and worn edges."""
    rng = np.random.default_rng(seed)
    b = max(2, round(0.05 * min(w, h)))
    img = sheet.crop(crop).convert("RGB").resize((w - 2 * b, h - 2 * b), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.5))
    img = np.asarray(img).astype(np.float32)
    grey = img.mean(2, keepdims=True)
    img = 0.55 * img + 0.45 * grey * np.array([1.12, 0.96, 0.72])  # toned towards sepia
    img = img * 0.78 + np.array([44, 34, 20])  # faded: the blacks lifted, the whites dulled
    out = np.tile(PAPER, (h, w, 1))
    out[b:h - b, b:w - b] = img
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # yellowing and dirt, heavier at the edges and corners
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy]) / (0.5 * min(w, h))
    wear = np.clip(1 - edge * 3.2, 0, 1) * (0.55 + 0.45 * blotch(rng, h, w, 6, 2))
    out = out * (1 - 0.42 * wear[..., None]) + np.array([92, 64, 30]) * 0.42 * wear[..., None]
    out *= (0.86 + 0.18 * blotch(rng, h, w, 40, 14))[..., None]
    # scratches and a crease, lighter than the print
    lay = Image.new("L", (w, h), 0)
    ld = ImageDraw.Draw(lay)
    for _ in range(rng.integers(5, 9)):
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
        a, l = rng.uniform(0, np.pi), rng.uniform(0.1, 0.45) * min(w, h)
        ld.line([(x0, y0), (x0 + l * np.cos(a), y0 + l * np.sin(a))], fill=int(rng.uniform(60, 140)), width=1)
    a = rng.uniform(-0.4, 0.4) + (np.pi / 2 if rng.random() < 0.5 else 0)
    cx, cy = w / 2 + rng.uniform(-0.15, 0.15) * w, h / 2 + rng.uniform(-0.15, 0.15) * h
    L = max(w, h)
    ld.line([(cx - L * np.cos(a), cy - L * np.sin(a)), (cx + L * np.cos(a), cy + L * np.sin(a))], fill=110, width=1)
    k = np.asarray(lay).astype(np.float32)[..., None] / 255
    out = out * (1 - k) + np.array([235, 225, 200]) * k
    shadow = np.asarray(lay.transform(lay.size, Image.AFFINE, (1, 0, -1, 0, 1, -1))).astype(np.float32)[..., None] / 255
    out *= 1 - 0.25 * shadow
    # nicks in the edges where the paper shows through, and grain
    nick = (blotch(rng, h, w, 2, 0.6) > 0.9) & (edge < 0.035)
    out[nick] = PAPER * 1.04
    out += rng.normal(0, 6, (h, w, 1))
    return out


def main(atlas_path, sheets, out_path):
    atlas = np.asarray(Image.open(atlas_path).convert("RGB")).astype(np.float32)
    for i, ((u0, v0, u1, v1), (right, down), name, crop) in enumerate(CARDS):
        du, dv = u1 - u0, v1 - v0
        w, h = (du, dv) if right[1] == "u" else (dv, du)
        img = card(Image.open(os.path.join(sheets, name)), crop, w, h, 7 + i)
        iv, iu = np.mgrid[0:dv, 0:du]
        pick = {"+u": iu, "-u": du - 1 - iu, "+v": iv, "-v": dv - 1 - iv}
        atlas[v0:v1, u0:u1] = img[pick[down], pick[right]]
    Image.fromarray(np.clip(atlas, 0, 255).astype(np.uint8)).save(out_path)


if __name__ == "__main__":
    main(*sys.argv[1:4])
