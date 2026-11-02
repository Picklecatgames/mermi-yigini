# python sheet.py <preview.py çıkışı> <jpg>: satırları boş kenarlarından kırpıp alt alta dizer
import sys
from PIL import Image, ImageChops

src, out = sys.argv[1:3]
rows = []
for r in ('cit', 'merdiven', 'zemin'):
    im = Image.open(f'{src}/{r}.png').convert('RGB')
    bg = Image.new('RGB', im.size, im.getpixel((2, 2)))
    l, t, rr, b = ImageChops.difference(im, bg).point(lambda v: 255 if v > 18 else 0).getbbox()
    rows.append(im.crop((max(l - 30, 0), max(t - 30, 0), min(rr + 30, im.width), min(b + 30, im.height))))
W = max(r.width for r in rows)
sheet = Image.new('RGB', (W, sum(r.height for r in rows)), rows[0].getpixel((2, 2)))
y = 0
for r in rows:
    sheet.paste(r, ((W - r.width) // 2, y)); y += r.height
if W > 2400:
    sheet = sheet.resize((2400, sheet.height * 2400 // W), Image.LANCZOS)
sheet.save(out, quality=88)
