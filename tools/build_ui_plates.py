# The steel the menus are made of (UiStyle.plate / hazard_box), from ambientCG scans (CC0) lit from
# the top left with their own normal maps, so scratches and dents catch the light the way they would
# on the range's walls. Each piece is cut to the shape of a Kenney UI Pack depth button (CC0): its
# rounded corners, its bright rim, the line inset in it and its dark lip at the foot shade the steel.
# Several of each, every one from another patch of steel, so no two cards side by side match.
# Brightness and tint are set in Godot.
# Run: python tools/build_ui_plates.py   (downloads the scans and the pack into a temp folder)
import io, os, tempfile, urllib.request, zipfile
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui", "plates")
LIGHT = np.array([-0.5, 0.55, 0.68])  # top left, GL normals (green up)
LIGHT /= np.linalg.norm(LIGHT)
FACE = 218.0  # a Kenney shape's face grey: drawn as the steel is, the rest lighter or darker
MARGIN = 28  # px of the 128 px shapes taken as their corners; drawn this big unless `corner` says
# smaller (the 9-slice margins in UiStyle.PLATES must match)


def fetch(url, name):
    d = os.path.join(tempfile.gettempdir(), name)
    if not os.path.isdir(d):
        req = urllib.request.Request(url, headers={"User-Agent": "mermi-yigini build"})
        zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(req).read())).extractall(d)
    return d


def scan(asset):
    d = fetch("https://ambientcg.com/get?file=%s_1K-JPG.zip" % asset, "acg_" + asset)
    def load(kind):
        p = os.path.join(d, "%s_1K-JPG_%s.jpg" % (asset, kind))
        return np.asarray(Image.open(p).convert("RGB"), np.float32) / 255.0 if os.path.exists(p) else None
    return load("Color"), load("NormalGL"), load("AmbientOcclusion")


def lit(asset, strength=1.0):
    col, nor, ao = scan(asset)
    n = nor * 2.0 - 1.0
    shade = np.clip(n @ LIGHT, 0.0, 1.0) / LIGHT[2]  # a flat texel stays as scanned
    shade = 1.0 + (shade - 1.0) * strength
    out = col * shade[..., None]
    if ao is not None:
        out *= ao[..., :1]
    return out


KENNEY = os.path.join(fetch("https://opengameart.org/sites/default/files/kenney_ui-pack.zip", "kenney_ui-pack"), "PNG", "Grey", "Double")


def shape(name, size, corner):
    """A Kenney shape 9-sliced to `size`: its corners drawn `corner` px, its edges and middle stretched."""
    src = Image.open(os.path.join(KENNEY, name + ".png")).convert("RGBA")
    w, h = size
    m, s, c = MARGIN, src.width, corner
    out = Image.new("RGBA", size)
    xs = [(0, m, 0, c), (m, s - m, c, w - c), (s - m, s, w - c, w)]
    ys = [(0, m, 0, c), (m, s - m, c, h - c), (s - m, s, h - c, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            out.paste(src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.LANCZOS), (dx0, dy0))
    a = np.asarray(out, np.float32) / 255.0
    return a[..., :3].mean(axis=2, keepdims=True) * 255.0 / FACE, a[..., 3:]


def patch(sheet, size, k):
    """A `size` px patch of a tiling scan, somewhere else for every k."""
    w, h = size
    big = np.tile(sheet, (3, 3, 1))
    rng = np.random.default_rng(k * 7919 + w * 31 + h)
    x, y = rng.integers(0, sheet.shape[1]), rng.integers(0, sheet.shape[0])
    return big[y:y + h, x:x + w]


def bake(sheet, name, size, form, count, contrast=1.0, corner=MARGIN):
    for k in range(count):
        light, alpha = shape(form, size, corner)
        light = 1.0 + (light - 1.0) * contrast
        rgb = np.clip(patch(sheet, size, k) * light, 0, 1)
        im = np.concatenate([rgb, alpha], axis=2)
        Image.fromarray((im * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "%s_%d.png" % (name, k)))


os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):  # what an earlier run made, so a smaller count leaves nothing behind
    if f.endswith(".png") or f.endswith(".jpg"):
        os.remove(os.path.join(OUT, f))
steel = lit("MetalPlates013")  # scratched, rust-streaked sheet
bake(steel, "card", (192, 224), "button_square_depth_line", 8)  # a gear card
bake(steel, "row", (1120, 88), "button_square_depth_line", 4)  # an upgrade's row
bake(steel, "button", (220, 46), "button_square_depth_flat", 6, corner=16)  # a price in reach, tinted green
bake(steel, "tray", (1180, 480), "button_square_depth_border", 1, 0.8)  # the cards stand in it
bake(steel, "chain", (430, 660), "button_square_depth_line", 1)  # the quest board's main chain
bake(lit("Cork002", 0.7), "cork", (720, 560), "button_square_depth_border", 1, 0.7)  # pinned paper
stripes = np.asarray(Image.fromarray((lit("PaintedMetal016") * 255).clip(0, 255).astype(np.uint8)).resize((360, 360), Image.LANCZOS), np.float32) / 255.0
bake(stripes, "hazard", (164, 74), "button_square_flat", 8, corner=16)  # a locked piece's stage, stripes shrunk to read
# The workshop machines' screens (scripts/station_view.gd): their cards are the machines' own
# chipped green paint, their price and make buttons stamped brass.
def shrunk(sheet, px):
    """A scan cut down to `px`, so its chips and scratches come out small on a card."""
    im = Image.fromarray((sheet * 255).clip(0, 255).astype(np.uint8)).resize((px, px), Image.LANCZOS)
    return np.asarray(im, np.float32) / 255.0


bake(shrunk(lit("PaintedMetal006"), 300), "machine", (440, 210), "button_square_depth_line", 4)
bake(shrunk(lit("Metal007", 1.4), 360), "brass", (220, 52), "button_square_depth_flat", 4, 1.3, corner=16)
# Gauges and level boxes (UiStyle.bar, upgrade_menu.gd Gauge and Track): a slot pressed into the
# steel (the shape's shading turned over, so its rim reads as sunk), a brass bar filling it, small
# steel studs for levels, tinted in Godot.
bake(steel, "slot", (260, 42), "button_square_depth_border", 3, -0.9, corner=12)
bake(shrunk(lit("Metal007", 1.4), 360), "fill", (260, 42), "button_square_flat", 3, 1.0, corner=12)
bake(steel, "pip", (36, 36), "button_square_depth_flat", 4, 1.2, corner=10)
print("ok", OUT)
