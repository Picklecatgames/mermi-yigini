# python -I tex.py <indirme klasörü> <proje kökü>
# Zemin ve atölye dokuları: <ad>_diff_2k.jpg, <ad>_nor_gl_2k.jpg, <ad>_arm_2k.jpg (R AO, G pürüz, B metal)
# ve yanına dünya boyutunda tekrarlanan bir ORMMaterial3D (.tres). HDRI'ları da kopyalar.
import sys, os, shutil
from PIL import Image

S, ROOT = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, 'assets/env/acik_alan/dokular')
HDR = os.path.join(ROOT, 'assets/env/hdri')
R = 2048
# ad: (kaynak, kaynak klasörü, dokunun dünyadaki boyu m)
TEX = {
    'dry_ground_rocks': ('pht', 'dry_ground_rocks', 3.0),
    'brown_mud_dry': ('pht', 'brown_mud_dry', 3.0),
    'burned_ground_01': ('pht', 'burned_ground_01', 3.0),
    'road_damaged': ('pht', 'road_damaged', 4.0),
    'gravelly_sand': ('pht', 'gravelly_sand', 2.0),
    'worn_concrete_floor': ('pht', 'worn_concrete_floor', 3.0),
    'worn_corrugated_iron': ('pht', 'worn_corrugated_iron', 2.0),
    'ground110': ('acg', 'Ground110', 2.0),
    'asphalt026c': ('acg', 'Asphalt026C', 2.0),
    'rubber004': ('acg', 'Rubber004', 1.0),
    # çöl ve atölye betonu (2026-11-02 kararı: dışarısı çöl gibi wasteland, atölye ve çevresi beton)
    'red_sand': ('pht', 'red_sand', 3.0),
    'sandy_gravel_02': ('pht', 'sandy_gravel_02', 2.5),
    'mud_cracked_dry_03': ('pht', 'mud_cracked_dry_03', 1.5),
    'mud_cracked_dry_riverbed_002': ('pht', 'mud_cracked_dry_riverbed_002', 2.0),
    'sandstone_cracks': ('pht', 'sandstone_cracks', 2.0),
    'ground097': ('acg', 'Ground097', 2.0),
    'ground096a': ('acg', 'Ground096A', 2.0),
    'cracked_concrete': ('pht', 'cracked_concrete', 2.0),
    'concrete_floor_damaged_01': ('pht', 'concrete_floor_damaged_01', 5.0),
    'concrete_floor_02': ('pht', 'concrete_floor_02', 2.0),
    'damaged_concrete_floor_02': ('pht', 'damaged_concrete_floor_02', 3.5),
}


def ld(p, mode='RGB'):
    im = Image.open(p).convert(mode)
    return im if im.size == (R, R) else im.resize((R, R), Image.LANCZOS)


def tres(name, size):
    p = f'res://assets/env/acik_alan/dokular/{name}/{name}'
    return f'''[gd_resource type="ORMMaterial3D" load_steps=4 format=3]

[ext_resource type="Texture2D" path="{p}_diff_2k.jpg" id="1"]
[ext_resource type="Texture2D" path="{p}_nor_gl_2k.jpg" id="2"]
[ext_resource type="Texture2D" path="{p}_arm_2k.jpg" id="3"]

[resource]
albedo_texture = ExtResource("1")
orm_texture = ExtResource("3")
normal_enabled = true
normal_texture = ExtResource("2")
uv1_scale = Vector3({1 / size:.4f}, {1 / size:.4f}, {1 / size:.4f})
uv1_triplanar = true
uv1_world_triplanar = true
'''


for name, (kind, src, size) in TEX.items():
    d = os.path.join(OUT, name); os.makedirs(d, exist_ok=True)
    o = os.path.join(d, name)
    if kind == 'pht':
        p = f'{S}/dl/pht/{src}/{src}_'
        ld(p + 'Diffuse.jpg').save(o + '_diff_2k.jpg', quality=90)
        ld(p + 'nor_gl.jpg').save(o + '_nor_gl_2k.jpg', quality=92)
        ld(p + 'arm.jpg').save(o + '_arm_2k.jpg', quality=90)
    else:
        p = f'{S}/dl/acg/{src}/{src}_2K-JPG_'
        ld(p + 'Color.jpg').save(o + '_diff_2k.jpg', quality=90)
        ld(p + 'NormalGL.jpg').save(o + '_nor_gl_2k.jpg', quality=92)
        ao = ld(p + 'AmbientOcclusion.jpg', 'L') if os.path.exists(p + 'AmbientOcclusion.jpg') else Image.new('L', (R, R), 255)
        mt = ld(p + 'Metalness.jpg', 'L') if os.path.exists(p + 'Metalness.jpg') else Image.new('L', (R, R), 0)
        Image.merge('RGB', (ao, ld(p + 'Roughness.jpg', 'L'), mt)).save(o + '_arm_2k.jpg', quality=90)
    open(o + '.tres', 'w', encoding='utf8').write(tres(name, size))
    print('doku', name)

os.makedirs(HDR, exist_ok=True)
for r, _, fs in os.walk(f'{S}/dl/hdr'):
    for f in fs:
        if f.endswith('.hdr'):
            shutil.copy(os.path.join(r, f), os.path.join(HDR, f)); print('hdri', f)
