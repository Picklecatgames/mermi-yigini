"""Paints the first-person arms (tools/build_arms.py) in our viewmodel's colours: the old pistol arms' dark
olive glove and black sleeves; and scrubs the maker's name off the Deagle's slide (no real brands in game).

The UV layouts differ, so the old texture can't be copied over; like paint_gloves.py, a flat colour is
multiplied with the original's high-pass luminance, so seams, stitching and folds stay, and the
normal maps are untouched. Reads the textures build_arms.py wrote, writes *_painted_* ones, points
the glTF at them and deletes the originals it replaced (build_arms.py writes them again).
    python tools/paint_arms.py
"""
import json
import os

import numpy as np
from PIL import Image, ImageFilter

DIR = "assets/weapons/arms/"
GLOVE = np.array([0.20, 0.20, 0.18])  # same as paint_gloves.py
SLEEVE = np.array([0.22, 0.22, 0.21])  # charcoal: near black (0.11) swallowed the weave and seams
DETAIL = 1.6
ROUGHNESS = 0.78
## The engraving on the Deagle slide (measured on the 2K map, x0, y0, x1, y1; scaled to the map's size) and clean rows of the same panel (y0, y1)
## that get tiled over it: brushed steel runs along the panel, so whole columns carry on unbroken.
SLIDE = "T_Deagle_Slide_"
SCRUB = [((505, 1135, 582, 1497), (1500, 1695)), ((608, 1312, 674, 1676), (1205, 1312))]
FEATHER = 6  # px the patch fades in over at its top and bottom


def load(name):
    return np.asarray(Image.open(DIR + "textures/" + name).convert("RGB"), dtype=np.float32) / 255.0


def save(arr, name):
    Image.fromarray((np.clip(arr, 0.0, 1.0) * 255).astype(np.uint8)).save(DIR + "textures/" + name)


def detail_of(base):
    lum = base @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    blur = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(24)), dtype=np.float32) / 255.0
    return np.clip((lum / np.maximum(blur, 0.05)) ** DETAIL, 0.35, 1.8)[..., None]


def scrub(name):
    img = Image.open(DIR + "textures/" + name)
    a = np.asarray(img).copy()
    k = img.width // 2048  # SCRUB is measured on the 2K map
    for (x0, y0, x1, y1), (s0, s1) in [([v * k for v in r], [v * k for v in c]) for r, c in SCRUB]:
        rows = np.arange(y0, y1)
        patch = a[s0 + (rows - y0) % (s1 - s0), x0:x1]
        w = np.clip(np.minimum(rows - y0, y1 - 1 - rows) / (FEATHER * k), 0.0, 1.0)[:, None, None]
        a[y0:y1, x0:x1] = (patch * w + a[y0:y1, x0:x1] * (1.0 - w)).astype(a.dtype)
    Image.fromarray(a).save(DIR + "textures/" + name)


GLOVE_MR = "Gloves_Metallic_1003-Gloves_Roughness_1003.png"  # glTF packing: G roughness, B metal
RENAME = {"Gloves_BaseColor.1003.png": "Gloves_painted_BaseColor.png", GLOVE_MR: "Gloves_painted_MR.png",
          "Cloths_BaseColor.1002.png": "Cloths_painted_BaseColor.png",
          "Face_Basecolor.png": "Body_painted_BaseColor.png"}  # the bare forearm, sleeved over

gloves = detail_of(load("Gloves_BaseColor.1003.png"))
save(GLOVE * gloves, RENAME["Gloves_BaseColor.1003.png"])
mr = load(GLOVE_MR)
mr[..., 1] = np.clip(ROUGHNESS + (gloves[..., 0] - 1.0) * -0.15, 0.6, 0.95)
mr[..., 2] = 0.0  # not metal
save(mr, RENAME[GLOVE_MR])
save(SLEEVE * detail_of(load("Cloths_BaseColor.1002.png")), RENAME["Cloths_BaseColor.1002.png"])
save(SLEEVE * detail_of(load("Face_Basecolor.png")), RENAME["Face_Basecolor.png"])
for m in ("BaseColor.png", "Normal.png", "Metallic-T_Deagle_Slide_Roughness.png"):
    scrub(SLIDE + m)

path = DIR + "arms.gltf"
gltf = json.load(open(path, encoding="utf-8"))
for img in gltf["images"]:
    name = img["uri"].removeprefix("textures/")
    if name in RENAME:
        img["uri"] = "textures/" + RENAME[name]
json.dump(gltf, open(path, "w", encoding="utf-8"))
for name in RENAME:
    os.remove(DIR + "textures/" + name)
print("arms painted")
