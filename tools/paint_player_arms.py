"""Paints the first-person arms for each player character, from the colours tools/build_player_arms.gd
read off the character (assets/characters/players/arms.json): gloves in its hands' colour, sleeves and
the forearm under them in its forearms'. The arms' own maps (tools/paint_arms.py) are a flat colour
times the original's high-pass luminance; dividing that colour out gives the detail back, and the new
colour goes on it. Bare skin keeps less of the detail (stitching on a hand reads as a glove).
Writes assets/characters/players/<id>/arms_{gloves,sleeves,body}.png; viewmodel.gd dress() wears them.
    python tools/paint_player_arms.py
"""
import json

import numpy as np
from PIL import Image

ARMS = "assets/weapons/arms/textures/"
DIR = "assets/characters/players/"
GLOVE = np.array([0.20, 0.20, 0.18])  # paint_arms.py's colours, divided out again
SLEEVE = np.array([0.22, 0.22, 0.21])
SKIN_DETAIL = 0.45  # the power bare skin keeps of the detail
FLOOR = 0.07  # black (the Chupacabra's gloves) still shows its seams
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


colours = json.load(open(DIR + "arms.json", encoding="utf-8"))
for name, (src, old, part) in MAPS.items():
    base = load(src)
    lum = lambda a: a @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    detail = (lum(base) / float(lum(old)))[..., None]
    for cid, c in colours.items():
        d = detail ** SKIN_DETAIL if c[part + "_skin"] else detail
        out = np.clip(np.maximum(np.array(c[part], dtype=np.float32), FLOOR) * d, 0.0, 1.0)
        path = DIR + "%s/arms_%s.png" % (cid, name)
        Image.fromarray((out * 255).astype(np.uint8)).save(path)
        open(path + ".import", "w", newline="\n").write(IMPORT)
        print("wrote", path)
