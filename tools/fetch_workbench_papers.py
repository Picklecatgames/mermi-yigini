# Fetches the workbench's paper textures from Wikimedia Commons (all public domain or CC0, listed in
# docs/ayrintilar.md): old cartridge drawings and patent pages for the pile of sheets on the desk.
# A few drawings also get a cyanotype copy (white lines on
# Prussian blue), the real blueprint process, to lie on top of the pile.
# Output: assets/props/workbench/textures/ (paper_NN.jpg, blue_NN.jpg).
# Run: python tools/fetch_workbench_papers.py
import io, json, os, time, urllib.parse, urllib.request
from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "workbench", "textures")
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "MermiYigini/1.0 (game asset fetch)"}

PAPERS = [
	"Original 1901 Cartridge drawing 6,5x53,5R Mannlicher Cartridge.jpg",
	"Original 1913 detail cartridge drawing 6,5x53,5R Roumanian Mannlicher Cartridge.jpg",
	"Original 1895 Chamber drawing for the 6,5x53,5 Roumanian Cartridge.jpg",
	"Mk VII .303 cartridge diagram Treatise on Ammunition 1915.jpg",
	"Mk VI .303 cartridge diagram Treatise on Ammunition 1915.jpg",
	"Projectile. - DPLA - 4684256e6d9b944e525edfa1a4bcbf61 (page 1).jpg",
	"Projectile. - DPLA - 52683bd53c69fb7d365f90d0856ed527 (page 2).jpg",
	"Magazine-Projectile - DPLA - 21a48f441badbb362bf7b28222edc4b7 (page 1).jpg",
	"H. Reilly Projectile for Ordnance - DPLA - be67e008145aecb535633cb595baf9f5 (page 1).jpg",
	"Whitworth patent cartridge illustration and section.jpg",
	"Cartridge SA Ball .276 inch (Mark I) L (drawing).jpg",
	"QF 1 pdr Cartridge Diagram.jpg",
]
BLUE = [1, 2, 6, 8, 11, 12]  # 1-based indices into PAPERS that also get a cyanotype copy
PAPER_SIDE = 1024  # longest side kept: a sheet is ~30 cm on the desk


def url_of(title, width):
	q = urllib.parse.urlencode({"action": "query", "prop": "imageinfo", "iiprop": "url",
								"iiurlwidth": width, "format": "json", "titles": "File:" + title})
	page = json.load(urllib.request.urlopen(urllib.request.Request(
		"https://commons.wikimedia.org/w/api.php?" + q, headers=UA)))["query"]["pages"]
	return next(iter(page.values()))["imageinfo"][0]["thumburl"]


def fetch(title, width):
	for attempt in range(5):
		try:
			data = urllib.request.urlopen(urllib.request.Request(url_of(title, width), headers=UA)).read()
			time.sleep(2)  # Commons throttles quick bursts
			return Image.open(io.BytesIO(data))
		except Exception:
			time.sleep(5 * (attempt + 1))
	raise RuntimeError("could not fetch " + title)


def cyanotype(im):
	# Paper white -> dark slate blue, ink -> pale lines (the look of a modern dark blueprint).
	g = ImageOps.autocontrast(im.convert("L"), cutoff=2)
	return ImageOps.colorize(ImageOps.invert(g), black=(26, 36, 50), white=(206, 220, 236))


for i, title in enumerate(PAPERS, 1):
	path = os.path.join(OUT, f"paper_{i:02}.jpg")
	if os.path.exists(path):
		continue
	im = fetch(title, PAPER_SIDE).convert("RGB")
	im.thumbnail((PAPER_SIDE, PAPER_SIDE))
	im.save(path, quality=88)
	if i in BLUE:
		cyanotype(im).save(os.path.join(OUT, f"blue_{i:02}.jpg"), quality=88)
print("ok", sorted(os.listdir(OUT)))
