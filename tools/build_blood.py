# Real blood for the zombies, from footage and scans in assets/vfx/blood/raw/ (gitignored, the raw files
# can't be shipped; only what this writes goes in the game). Run from the project root:
#   python tools/build_blood.py
#
# Mist: ActionVFX "FREE - Blood Mist" shots 11-15 (2026-10-30, the user picked these five), 2K 60 fps,
# blood blown across a white backdrop left to right. Every other frame from the first puff on, 64
# frames in an 8x8 atlas, 2K. The white is turned into alpha from how much green the blood took out
# (it absorbs green, the backdrop doesn't), the colour is what's left once the white is divided back
# out. mist.json says where in the square the puff starts (uv), so the hit sits on that point and the
# cloud flies on along the round.
#
# Decals: ActionVFX "FREE - Blood Textures" (alpha PNGs, 2592x1944): cropped to the blood, 1K at most,
# with a normal map from the blood's thickness (its alpha, blurred) and an ORM where thick blood is
# wet and shiny and the thin rim dull.
#
# Flesh: TextureCan "Bloody Organ, Intestine or Flesh" (CC0), 4K to 2K; AO and roughness packed as ORM.

import json
import os
import subprocess

import numpy as np
from PIL import Image, ImageFilter

RAW = "assets/vfx/blood/raw"
OUT = "assets/vfx/blood"
GORE = "materials/env/gore"

MISTS = {  # shot -> name
    11: "curl", 12: "puff", 13: "small", 14: "streak", 15: "burst",
}
FIRST = 3  # the frame the puff appears in
STEP = 2  # 60 fps -> 30
GRID = 8
CELL = 256
W, H = 1024, 540  # the footage at half size: plenty for 256 px cells

DECALS = {  # out name -> source in the zip
    "pool_0": "Blood Pool 2", "pool_1": "Blood Pool 3", "pool_2": "Blood Pool 4",
    "pool_3": "Blood Pool 5", "pool_4": "Blood Pool 10", "pool_5": "Blood Pool 26",
    "drop_0": "Blood Pool 17", "drop_1": "Blood Pool 22", "drop_2": "Blood Pool 24", "drop_3": "Blood Pool 27",
    "smear_0": "Blood Pool 13", "smear_1": "Blood Pool 14", "smear_2": "Blood Pool 1",
    "mist_0": "Blood Spray 1", "mist_1": "Blood Spray 3",
    "spray_0": "Blood Spray 4", "spray_1": "Blood Spray 5", "spray_2": "Blood Spray 6", "spray_3": "Blood Spray 7",
    "hand_0": "Bloody Handprints 2", "hand_1": "Bloody Handprints 3", "foot_0": "Bloody Footprints 2",
}
DECAL_MAX = 1024


def frames(path: str, args: list) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", *args[:2], "-i", path, *args[2:], "-vf", f"scale={W}:{H}",
            "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3).astype(np.float32) / 255.0


def mist(shot: int, name: str) -> dict:
    path = [f for f in os.listdir(f"{RAW}/mist") if f.startswith(f"Blood_Mist_{shot}_")][0]
    src = f"{RAW}/mist/{path}"
    bg = np.median(frames(src, ["-sseof", "-0.25"]), axis=0)  # the backdrop alone, its uneven light included
    pick = frames(src, ["-ss", "0", "-frames:v", str(FIRST + GRID * GRID * STEP)])[FIRST::STEP]
    take = 1.0 - pick[..., 1] / np.maximum(bg[..., 1], 0.05)
    alpha = np.clip((take - 0.025) / 0.7, 0.0, 1.0) ** 0.85
    # where it is in the shot: every frame's blood together, a square round it
    peak = np.asarray(Image.fromarray((alpha.max(0) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)))
    ys, xs = np.where(peak > 30)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    side = int(max(x1 - x0, y1 - y0) * 1.12) + 8
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    left, top = int(cx - side / 2), int(cy - side / 2)
    # the puff's start: the middle of the first frame's blood
    a0 = alpha[0]
    w0 = a0 * (a0 > 0.1)
    yy, xx = np.mgrid[0:H, 0:W]
    ex, ey = (xx * w0).sum() / w0.sum(), (yy * w0).sum() / w0.sum()
    atlas = Image.new("RGBA", (GRID * CELL, GRID * CELL))
    blood = np.array([0.32, 0.025, 0.02])
    for i in range(GRID * GRID):
        a = alpha[i]
        c = pick[i]
        # what's left of the colour once the white behind it is divided out
        col = (c - bg * (1.0 - a[..., None])) / np.maximum(a[..., None], 0.05)
        col = np.clip(col, 0.0, 1.0) * np.array([0.8, 0.42, 0.42])  # backlit on white it reads pink
        k = np.clip(a * 3.0, 0.0, 1.0)[..., None]
        col = blood + (col - blood) * k  # the thin edge is noise: plain blood there
        rgba = np.dstack([col * a[..., None], a])  # premultiplied for the downscale
        pad = np.zeros((side, side, 4), np.float32)
        sx0, sy0 = max(left, 0), max(top, 0)
        sx1, sy1 = min(left + side, W), min(top + side, H)
        pad[sy0 - top:sy1 - top, sx0 - left:sx1 - left] = rgba[sy0:sy1, sx0:sx1]
        im = Image.fromarray((pad * 255).astype(np.uint8), "RGBA").resize((CELL, CELL), Image.LANCZOS)
        p = np.asarray(im).astype(np.float32) / 255.0
        a = p[..., 3:4]
        p[..., :3] = np.where(a > 0.003, p[..., :3] / np.maximum(a, 0.003), blood)
        # nothing may touch the cell's edge, or the next frame's blood bleeds in when mipmapped
        d = np.minimum(np.arange(CELL), np.arange(CELL)[::-1])
        p[..., 3] *= np.clip(np.minimum(d[None, :], d[:, None]) / 6.0, 0.0, 1.0)
        atlas.paste(Image.fromarray((np.clip(p, 0, 1) * 255).astype(np.uint8), "RGBA"),
                ((i % GRID) * CELL, (i // GRID) * CELL))
    atlas.save(f"{OUT}/mist_{name}.png")
    return {"emit": [round((ex - left) / side, 3), round((ey - top) / side, 3)]}


def decal(name: str, src: str) -> None:
    im = Image.open(f"{RAW}/textures/2.5K/{src}.png").convert("RGBA")
    if name.startswith("spray"):  # laid along +u, its dense end at u = 0, so it can point along the round
        a = np.asarray(im.getchannel("A")).astype(np.float32)
        ys, xs = np.nonzero(a > 20)
        w = a[ys, xs]
        mx, my = np.average(xs, weights=w), np.average(ys, weights=w)
        cov = np.cov(np.vstack([xs - mx, ys - my]), aweights=w)
        vx, vy = np.linalg.eigh(cov)[1][:, -1]
        ang = np.degrees(np.arctan2(vy, vx))
        im = im.rotate(ang, Image.BICUBIC, expand=True)  # PIL turns counter-clockwise, image y is down
        a = np.asarray(im.getchannel("A")).astype(np.float32)
        col = a.sum(0)
        mid = int(np.average(np.arange(len(col)), weights=col))
        if (a ** 2).sum(0)[:mid].sum() < (a ** 2).sum(0)[mid:].sum():  # the dense end goes left
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
    box = im.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
    l, t, r, b = box
    m = 12
    im = im.crop((max(l - m, 0), max(t - m, 0), min(r + m, im.width), min(b + m, im.height)))
    s = min(1.0, DECAL_MAX / max(im.size))
    im = im.resize((max(4, round(im.width * s)), max(4, round(im.height * s))), Image.LANCZOS)
    # square, so the decal's size is its width both ways
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (40, 2, 2, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    a = np.asarray(sq).astype(np.float32)[..., 3] / 255.0
    # thickness: a pool stands up from the floor in a rounded edge, a fine spray barely at all
    soft = np.asarray(sq.getchannel("A").filter(ImageFilter.GaussianBlur(side / 220.0))).astype(np.float32) / 255.0
    lum = np.asarray(sq.convert("L")).astype(np.float32) / 255.0
    height = np.sqrt(soft) * 6.0 + (1.0 - lum) * a * 1.5  # dark = deep
    gy, gx = np.gradient(height)
    n = np.dstack([-gx, gy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(f"{OUT}/decals/{name}_normal.png")
    rough = 0.55 - 0.47 * np.clip(soft * 1.4, 0, 1)  # wet and glossy where it is thick
    orm = np.dstack([np.ones_like(a), rough, np.zeros_like(a)])
    Image.fromarray((orm * 255).astype(np.uint8), "RGB").save(f"{OUT}/decals/{name}_orm.png")
    sq.save(f"{OUT}/decals/{name}_albedo.png")


def flesh() -> None:
    f = f"{RAW}/flesh/others_0001_"
    Image.open(f + "color_4k.jpg").convert("RGB").resize((2048, 2048), Image.LANCZOS).save(f"{GORE}/flesh_albedo.jpg", quality=92)
    Image.open(f + "normal_opengl_4k.png").convert("RGB").resize((2048, 2048), Image.LANCZOS).save(f"{GORE}/flesh_normal.png")
    ao = Image.open(f + "ao_4k.jpg").convert("L").resize((2048, 2048), Image.LANCZOS)
    rough = Image.open(f + "roughness_4k.jpg").convert("L").resize((2048, 2048), Image.LANCZOS)
    Image.merge("RGB", (ao, rough, Image.new("L", (2048, 2048), 0))).save(f"{GORE}/flesh_orm.png")


if __name__ == "__main__":
    os.makedirs(f"{OUT}/decals", exist_ok=True)
    if "--mist" not in os.sys.argv:
        flesh()
        for name, src in DECALS.items():
            decal(name, src)
    meta = {"grid": GRID, "fps": 60.0 / STEP}
    for shot, name in MISTS.items():
        meta[name] = mist(shot, name)
        print("mist", name, meta[name])
    with open(f"{OUT}/mist.json", "w") as fh:
        json.dump(meta, fh, indent=1)
