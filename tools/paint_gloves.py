"""Paints the first-person arms' bare skin into a dark tactical glove.

The glove keeps the hand's own sculpted detail (knuckles, creases, nails) by multiplying a flat
glove colour with the skin's high-pass luminance, and gets matte fabric roughness. Reads the
untouched model textures, writes the *_gloved_* ones the glTF points at.
    python tools/paint_gloves.py
"""
import numpy as np
from PIL import Image, ImageFilter

DIR = "assets/weapons/heavy_pistol/textures/"
GLOVE = np.array([0.20, 0.20, 0.18])  # dark olive-black, in the 0.25-0.3 brightness band once lit
DETAIL = 1.8       # how hard the skin's creases and knuckles show through
ROUGHNESS = 0.78   # matte fabric/leather

base = np.asarray(Image.open(DIR + "arms_baseColor.png").convert("RGB"), dtype=np.float32) / 255.0
mr = np.asarray(Image.open(DIR + "arms_metallicRoughness.png").convert("RGB"), dtype=np.float32) / 255.0

lum = base @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
# Skin: warm (red over blue), down into the dark creases between fingers. The jacket is grey.
skin = ((lum > 0.06) & (base[..., 0] > base[..., 2] + 0.05)).astype(np.float32)
mask = np.asarray(Image.fromarray((skin * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)), dtype=np.float32)[..., None] / 255.0

# High-pass: the hand's shading against its neighbourhood, so creases survive but skin tone goes.
lum_img = Image.fromarray((lum * 255).astype(np.uint8))
blur = np.asarray(lum_img.filter(ImageFilter.GaussianBlur(24)), dtype=np.float32) / 255.0
detail = np.clip((lum / np.maximum(blur, 0.05)) ** DETAIL, 0.35, 1.8)[..., None]
glove = np.clip(GLOVE * detail, 0.0, 1.0)

out = base * (1.0 - mask) + glove * mask
Image.fromarray((out * 255).astype(np.uint8)).save(DIR + "arms_gloved_baseColor.png")

rough = np.clip(ROUGHNESS + (detail[..., 0] - 1.0) * -0.15, 0.6, 0.95)  # creases a touch rougher
mr_out = mr.copy()
mr_out[..., 1] = mr[..., 1] * (1.0 - mask[..., 0]) + rough * mask[..., 0]
mr_out[..., 2] = mr[..., 2] * (1.0 - mask[..., 0])  # not metal
Image.fromarray((mr_out * 255).astype(np.uint8)).save(DIR + "arms_gloved_metallicRoughness.png")
print("gloves painted, skin share %.1f%%" % (skin.mean() * 100))
