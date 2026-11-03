# python -I stats.py <indirme klasörü> <proje kökü>: parça istatistiklerini acik_alan.json ve atolye.json'a toplar
import json, os, sys, glob

S, ROOT = sys.argv[1], sys.argv[2]
st = {os.path.basename(f)[:-5]: json.load(open(f, encoding='utf8')) for f in glob.glob(os.path.join(S, 'stats', '*.json'))}
for base, name in (('assets/env/acik_alan', 'acik_alan.json'), ('assets/props/atolye', 'atolye.json')):
    out = {}
    for d in sorted(os.listdir(os.path.join(ROOT, base))):
        p = os.path.join(ROOT, base, d)
        if not os.path.isdir(p) or d == 'dokular': continue
        for f in sorted(os.listdir(p)):
            if f.endswith('.gltf') and f[:-5] in st:
                s = dict(st[f[:-5]]); s.pop('id', None)
                out[f'{d}/{f}'] = s
    json.dump(out, open(os.path.join(ROOT, base, name), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
    print(name, len(out))
