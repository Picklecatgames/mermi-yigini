# Blender -b --factory-startup --python parts.py -- <doku klasörü> <çıkış> <istatistik>
# Atölye çatısının basit parçaları: ahşap direk ve kiriş, kare profil çelik direk, yağmur oluğu,
# oluklu sac çatı paneli, EUR paleti.
# Ölçüler gerçek; dokular dünyada metre başına bir kez tekrar eder (küp izdüşümü).
import bpy, bmesh, sys, os, json, math
from mathutils import Vector, Matrix

TEX, OUT, STATS = sys.argv[sys.argv.index('--') + 1:][:3]
os.makedirs(OUT, exist_ok=True); os.makedirs(STATS, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

# anahtar: Poly Haven doku öneki (diff / nor_gl / arm, 2k)
MATS = {'ahsap': 'fine_grained_wood', 'pas': 'rusty_metal_02'}


def material(key):
    if key in bpy.data.materials: return bpy.data.materials[key]
    f = MATS[key]
    m = bpy.data.materials.new(key); m.use_nodes = True
    N = m.node_tree.nodes; L = m.node_tree.links
    b = next(n for n in N if n.type == 'BSDF_PRINCIPLED')

    def tex(name, non_color):
        t = N.new('ShaderNodeTexImage')
        t.image = bpy.data.images.load(os.path.join(TEX, f, f'{f}_{name}.jpg'))
        if non_color: t.image.colorspace_settings.name = 'Non-Color'
        t.image.scale(1024, 1024)
        return t
    L.new(tex('Diffuse', False).outputs['Color'], b.inputs['Base Color'])
    arm = tex('arm', True); sep = N.new('ShaderNodeSeparateColor')
    L.new(arm.outputs['Color'], sep.inputs['Color'])
    L.new(sep.outputs['Green'], b.inputs['Roughness']); L.new(sep.outputs['Blue'], b.inputs['Metallic'])
    nm = N.new('ShaderNodeNormalMap'); L.new(tex('nor_gl', True).outputs['Color'], nm.inputs['Color'])
    L.new(nm.outputs['Normal'], b.inputs['Normal'])
    return m


def box_uv(bm, scale=1.0):
    # her yüz baskın eksenine göre izdüşür, 1 m = 1 tekrar
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal; a = max(range(3), key=lambda i: abs(n[i]))
        u, v = [(1, 2), (0, 2), (0, 1)][a]
        for l in f.loops:
            l[uv].uv = (l.vert.co[u] * scale, l.vert.co[v] * scale)


def box(bm, mn, mx):
    vs = [bm.verts.new((x, y, z)) for x in (mn[0], mx[0]) for y in (mn[1], mx[1]) for z in (mn[2], mx[2])]
    for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([vs[i] for i in q])


def finish(pid, bm, mat, hull_boxes, smooth=False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    box_uv(bm)
    me = bpy.data.meshes.new(pid); bm.to_mesh(me); bm.free()
    me.materials.append(material(mat))
    for p in me.polygons: p.use_smooth = smooth
    o = bpy.data.objects.new(pid, me); bpy.context.scene.collection.objects.link(o)
    objs = [o]
    for i, (mn, mx) in enumerate(hull_boxes):
        hb = bmesh.new(); box(hb, mn, mx)
        hm = bpy.data.meshes.new(f'{pid}_{i}-convcolonly'); hb.to_mesh(hm); hb.free()
        h = bpy.data.objects.new(f'{pid}_{i}-convcolonly', hm); bpy.context.scene.collection.objects.link(h); objs.append(h)
    bpy.ops.object.select_all(action='DESELECT')
    for x in objs: x.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, pid + '.gltf'), export_format='GLTF_SEPARATE', use_selection=True,
                              export_texture_dir='doku_parca',
                              export_image_format='JPEG', export_jpeg_quality=88, export_yup=True, export_materials='EXPORT')
    pts = [v.co for v in me.vertices]
    sz = [round(max(p[i] for p in pts) - min(p[i] for p in pts), 3) for i in (0, 2, 1)]
    st = dict(id=pid, ucgen=sum(len(p.vertices) - 2 for p in me.polygons), boyut_m=sz, carpisma='box', kaynak='kendi modelim (tools/atolye/parts.py)')
    json.dump(st, open(os.path.join(STATS, pid + '.json'), 'w', encoding='utf8'), ensure_ascii=False)
    print('@@ OK', pid, st['ucgen'], sz, flush=True)
    for x in objs: bpy.data.objects.remove(x)


def post(pid, w, h, mat, plate=None):
    bm = bmesh.new(); box(bm, (-w / 2, -w / 2, 0), (w / 2, w / 2, h))
    hulls = [((-w / 2, -w / 2, 0), (w / 2, w / 2, h))]
    if plate:  # taban ve tepe plakası
        pw, pt = plate
        box(bm, (-pw / 2, -pw / 2, 0), (pw / 2, pw / 2, pt))
        box(bm, (-pw / 2, -pw / 2, h - pt), (pw / 2, pw / 2, h))
    finish(pid, bm, mat, hulls)


def beam(pid, length, w, h, mat):
    bm = bmesh.new(); box(bm, (-length / 2, -w / 2, 0), (length / 2, w / 2, h))
    finish(pid, bm, mat, [((-length / 2, -w / 2, 0), (length / 2, w / 2, h))])


def gutter(pid, length, r=0.065, t=0.002, seg=10):
    # yarım daire oluk, ağzı yukarı, X boyunca; uçlarda kapak yok
    bm = bmesh.new()
    prof = []
    for i in range(seg + 1):
        a = math.pi + math.pi * i / seg
        prof.append((math.cos(a), math.sin(a)))
    rings = []
    for x in (-length / 2, length / 2):
        outer = [bm.verts.new((x, c * r, r + s * r)) for c, s in prof]
        inner = [bm.verts.new((x, c * (r - t), r + s * (r - t))) for c, s in prof]
        rings.append((outer, inner))
    (o0, i0), (o1, i1) = rings
    for k in range(seg):
        bm.faces.new((o0[k], o0[k + 1], o1[k + 1], o1[k]))
        bm.faces.new((i0[k], i1[k], i1[k + 1], i0[k + 1]))
    for a, b in ((o0, i0), (o1, i1)):
        for k in range(seg):
            bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
    for k in (0, seg):  # dudaklar
        bm.faces.new((o0[k], i0[k], i1[k], o1[k]))
    finish(pid, bm, 'pas', [((-length / 2, -r, 0), (length / 2, r, r))])


def corrugated(pid, length, width, pitch=0.076, depth=0.018, t=0.0008):
    # dalgalar X boyunca (eğimden aşağı akar), genişlik Y boyunca; iki yüzlü ince sac
    bm = bmesh.new()
    n = int(round(width / pitch)) * 8
    rows = []
    for x in (0.0, length):
        top, bot = [], []
        for i in range(n + 1):
            y = -width / 2 + width * i / n
            z = depth / 2 * (1 + math.sin(2 * math.pi * y / pitch))
            top.append(bm.verts.new((x - length / 2, y, z + t))); bot.append(bm.verts.new((x - length / 2, y, z)))
        rows.append((top, bot))
    (t0, b0), (t1, b1) = rows
    for i in range(n):
        bm.faces.new((t0[i], t0[i + 1], t1[i + 1], t1[i]))
        bm.faces.new((b0[i], b1[i], b1[i + 1], b0[i + 1]))
    finish(pid, bm, 'pas', [((-length / 2, -width / 2, 0), (length / 2, width / 2, depth + t))], smooth=True)


def pallet(pid):
    # EUR palet 1.2 x 0.8 x 0.144: üst 5 tahta, 3 alt kızak, 9 takoz
    bm = bmesh.new(); L, W = 1.2, 0.8
    for y in (-0.3275, -0.16375, 0, 0.16375, 0.3275):
        box(bm, (-L / 2, y - 0.0725, 0.122), (L / 2, y + 0.0725, 0.144))
    for y in (-0.3275, 0, 0.3275):
        box(bm, (-L / 2, y - 0.0725, 0.0), (L / 2, y + 0.0725, 0.022))
        for x in (-0.5275, 0, 0.5275):
            box(bm, (x - 0.0725, y - 0.0725, 0.022), (x + 0.0725, y + 0.0725, 0.122))
    finish(pid, bm, 'ahsap', [((-L / 2, -W / 2, 0), (L / 2, W / 2, 0.144))])


post('ahsap_direk_3m', 0.12, 3.0, 'ahsap')
beam('ahsap_kiris_4m', 4.0, 0.08, 0.16, 'ahsap')
beam('ahsap_asik_4m', 4.0, 0.06, 0.08, 'ahsap')
post('celik_direk_3m', 0.10, 3.0, 'pas', plate=(0.24, 0.012))
beam('celik_kare_profil_4m', 4.0, 0.08, 0.08, 'pas')
gutter('oluk_2m', 2.0)
corrugated('oluklu_sac_2x1m', 2.0, 1.0)
corrugated('oluklu_sac_3x1m', 3.0, 1.0)
pallet('palet')
