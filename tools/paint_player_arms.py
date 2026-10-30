"""Paints the first-person arms for each player character, from the colours tools/build_player_arms.gd
read off the character (assets/characters/players/arms.json): sleeves and the forearm under them in its
forearms' colour, and the hands as the character's own are, band by band from the wrist to the
fingertips (glove_t.png says where each glove texel is along that way). A gloved character's bands
meet in a ragged edge (the Chupacabra's flames at the cuff) and keep the glove's stitching; a bare
hand goes skin, the bands blending into each other with hardly any of the glove's detail left, and
arms.tres tells viewmodel.gd dress() to take the glove's bumps and shine off too. The arms' own maps
(tools/paint_arms.py) are a flat colour times the original's high-pass luminance; dividing that
colour out gives the detail back, and the new colour goes on it.
Writes assets/characters/players/<id>/arms_{gloves,sleeves,body}.png and arms.tres.
    python tools/paint_player_arms.py
"""
import json
import os

import numpy as np
from PIL import Image

ARMS = "assets/weapons/arms/textures/"
DIR = "assets/characters/players/"
GLOVE = np.array([0.20, 0.20, 0.18])  # paint_arms.py's colours, divided out again
SLEEVE = np.array([0.22, 0.22, 0.21])
SKIN_DETAIL = 0.45  # the power bare skin keeps of the detail
FLOOR = 0.07  # black (the Chupacabra's gloves) still shows its seams
BARE_DETAIL = 0.15  # the power a bare hand keeps of the glove's detail: folds, not stitching
GLOVE_MAP = DIR + "raw/glove_t.png"  # tools/build_player_arms.gd GLOVE_MAP, T0, T_SPAN
GLOVE_T0, GLOVE_T_SPAN = -0.5, 2.0
RAGGED = 0.07  # of the wrist-to-tip way a glove's band edges wander, in tongues...
TONGUES = 22.0  # ...about this many across the glove map
## texture -> (arms map, its paint_arms colour, the part whose colour it takes)
MAPS = {
    "gloves": ("Gloves_painted_BaseColor.png", GLOVE, "hand"),
    "sleeves": ("Cloths_painted_BaseColor.png", SLEEVE, "forearm"),
    "body": ("Body_painted_BaseColor.png", SLEEVE, "forearm"),
}
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/normal_map=2
mipmaps/generate=true
roughness/mode=0
"""


def load(name):
    return np.asarray(Image.open(ARMS + name).convert("RGB"), dtype=np.float32) / 255.0


TRES = """[gd_resource type="Resource" format=3]

[resource]
metadata/bare_hands = %s
"""


def along():
    """Each glove texel's way from the wrist (0) to the fingertips (1); unmapped ones mid-hand."""
    m = np.asarray(Image.open(GLOVE_MAP).convert("RGB"), dtype=np.float32) / 255.0
    t = m[..., 0] * GLOVE_T_SPAN + GLOVE_T0
    t[m[..., 1] < 0.5] = 0.5
    return t


def ragged(shape):
    """Smooth noise in -1..1, TONGUES bumps across: a band edge that licks up and down."""
    rng = np.random.default_rng(7)
    small = rng.uniform(-1.0, 1.0, (int(TONGUES), int(TONGUES))).astype(np.float32)
    big = Image.fromarray(((small + 1.0) * 127.5).astype(np.uint8)).resize(shape[::-1], Image.BICUBIC)
    return np.asarray(big, dtype=np.float32) / 127.5 - 1.0


def hands(c, t, noise):
    """The hand's colour per texel from its bands: blended on skin, cut raggedly on a glove."""
    bands = np.array(c["hand_bands"], dtype=np.float32)
    n = len(bands)
    if c["bare_hands"]:
        x = np.clip(t * n - 0.5, 0.0, n - 1.0)
        lo = np.floor(x).astype(int)
        hi = np.minimum(lo + 1, n - 1)
        f = (x - lo)[..., None]
        return bands[lo] * (1.0 - f) + bands[hi] * f
    return bands[np.clip(((t + noise * RAGGED) * n).astype(int), 0, n - 1)]


colours = json.load(open(DIR + "arms.json", encoding="utf-8"))
t = along()
noise = ragged(t.shape)
for cid, c in colours.items():
    open(DIR + "%s/arms.tres" % cid, "w", newline="\n").write(TRES % ("true" if c["bare_hands"] else "false"))
for name, (src, old, part) in MAPS.items():
    base = load(src)
    lum = lambda a: a @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    detail = (lum(base) / float(lum(old)))[..., None]
    for cid, c in colours.items():
        if name == "gloves":
            d = detail ** BARE_DETAIL if c["bare_hands"] else detail
            out = np.clip(np.maximum(hands(c, t, noise), FLOOR) * d, 0.0, 1.0)
        else:
            d = detail ** SKIN_DETAIL if c[part + "_skin"] else detail
            out = np.clip(np.maximum(np.array(c[part], dtype=np.float32), FLOOR) * d, 0.0, 1.0)
        path = DIR + "%s/arms_%s.png" % (cid, name)
        Image.fromarray((out * 255).astype(np.uint8)).save(path)
        if not os.path.exists(path + ".import"):  # Godot's own, once there, keeps the texture's uid
            open(path + ".import", "w", newline="\n").write(IMPORT)
        print("wrote", path)
