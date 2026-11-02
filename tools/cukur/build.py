# Blender -b --factory-startup --python build.py -- <indirilenler> <1k dokular> <çıkış>
# Hurda çukurunun çevresi: çit, merdiven, demir zemin. Poly Haven parçaları bölünüp sadeleşir,
# korkuluk / kafesli merdiven / rampa merdiven / zemin / kiriş burada gerçek ölçüyle kurulur.
# Her gltf'te görünen tek mesh ve "-convcolonly" ekli dışbükey çarpışmalar var.
import bpy, bmesh, sys, os, json, math
from mathutils import Vector, Matrix

DL, TEX, OUT = sys.argv[sys.argv.index('--') + 1:][:3]
os.makedirs(OUT, exist_ok=True)
STATS = {}
TRI_MAX = 5000


def log(*a):
    print('@@', *a, flush=True)


bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------- malzemeler ----------
# anahtar: (dosya öneki, dokunun dünyadaki boyu m, alfa)
MATS = {
    'sari': ('sari', 1.0, False),         # ambientCG PaintedMetal006, boyası sarıya çevrildi
    'gri': ('gri', 1.0, False),           # aynı doku, gri boya
    'izgara': ('izgara', 1.0, True),      # ambientCG MetalWalkway010
    'baklava': ('baklava', 0.5, False),   # Poly Haven metal_plate
    'pasli_sac': ('pasli_sac', 0.5, False),  # Poly Haven metal_grate_rusty
    'astar': ('astar', 1.5, False),       # Poly Haven rusty_painted_metal
}


def material(key):
    name = 'cukur_' + key
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    f, _, alpha = MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    nt = m.node_tree; N = nt.nodes; L = nt.links
    b = next(n for n in N if n.type == 'BSDF_PRINCIPLED')

    def img(suffix, color):
        ext = 'png' if (suffix == 'c' and alpha) else 'jpg'
        t = N.new('ShaderNodeTexImage')
        t.image = bpy.data.images.load(os.path.join(TEX, f'{f}_{suffix}.{ext}'))
        if not color:
            t.image.colorspace_settings.name = 'Non-Color'
        return t
    c = img('c', True)
    L.new(c.outputs['Color'], b.inputs['Base Color'])
    if alpha:
        rnd = N.new('ShaderNodeMath'); rnd.operation = 'ROUND'
        L.new(c.outputs['Alpha'], rnd.inputs[0]); L.new(rnd.outputs[0], b.inputs['Alpha'])
        m.use_backface_culling = False
    # hazır ORM (G pürüz, B metal): dışa aktarıcı yeniden paketlemesin, jpg kalsın
    sep = N.new('ShaderNodeSeparateColor')
    L.new(img('orm', False).outputs['Color'], sep.inputs['Color'])
    L.new(sep.outputs[1], b.inputs['Roughness']); L.new(sep.outputs[2], b.inputs['Metallic'])
    nm = N.new('ShaderNodeNormalMap')
    L.new(img('n', False).outputs['Color'], nm.inputs['Color']); L.new(nm.outputs['Normal'], b.inputs['Normal'])
    return m


# ---------- geometri ----------
class Builder:
    def __init__(self):
        self.bm = bmesh.new(); self.mats = []

    def _mi(self, key):
        if key not in self.mats: self.mats.append(key)
        return self.mats.index(key)

    def _faces(self, faces, key):
        mi = self._mi(key)
        for f in faces: f.material_index = mi

    def box(self, a, b, key):
        a = Vector(a); b = Vector(b)
        v = [self.bm.verts.new((x, y, z)) for x in (a.x, b.x) for y in (a.y, b.y) for z in (a.z, b.z)]
        idx = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        self._faces([self.bm.faces.new([v[i] for i in q]) for q in idx], key)

    def obox(self, c, size, rotz, key):
        # z çevresinde döndürülmüş kutu
        n0 = len(self.bm.verts)
        self.box([-s / 2 for s in size], [s / 2 for s in size], key)
        self.bm.verts.ensure_lookup_table()
        M = Matrix.Translation(Vector(c)) @ Matrix.Rotation(rotz, 4, 'Z')
        for v in self.bm.verts[n0:]: v.co = M @ v.co

    def prism(self, poly, y0, y1, key):
        # xz düzlemindeki çokgen, y boyunca kalınlık
        a = [self.bm.verts.new((x, y0, z)) for x, z in poly]
        b = [self.bm.verts.new((x, y1, z)) for x, z in poly]
        fs = [self.bm.faces.new(a[::-1]), self.bm.faces.new(b)]
        n = len(poly)
        for i in range(n):
            j = (i + 1) % n
            fs.append(self.bm.faces.new((a[i], a[j], b[j], b[i])))
        self._faces(fs, key)

    def pipe(self, pts, r, key, segs=10):
        pts = [Vector(p) for p in pts]
        rings = []
        for i, p in enumerate(pts):
            t = ((pts[min(i + 1, len(pts) - 1)] - p).normalized() + (p - pts[max(i - 1, 0)]).normalized()).normalized()
            up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            u = t.cross(up).normalized(); w = t.cross(u)
            rings.append([self.bm.verts.new(p + (u * math.cos(a) + w * math.sin(a)) * r)
                          for a in (2 * math.pi * s / segs for s in range(segs))])
        fs = []
        for ra, rb in zip(rings, rings[1:]):
            for s in range(segs):
                fs.append(self.bm.faces.new((ra[s], ra[(s + 1) % segs], rb[(s + 1) % segs], rb[s])))
        fs.append(self.bm.faces.new(rings[0][::-1])); fs.append(self.bm.faces.new(rings[-1]))
        self._faces(fs, key)


def arc(c, r, a0, a1, z, n):
    return [(c[0] + r * math.cos(a0 + (a1 - a0) * i / n), c[1] + r * math.sin(a0 + (a1 - a0) * i / n), z) for i in range(n + 1)]


def box_uv(bm, mats):
    uv = bm.loops.layers.uv.new('UVMap')
    for f in bm.faces:
        size = MATS[mats[f.material_index]][1]
        n = f.normal; ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            co = l.vert.co
            u, v = {0: (co.y, co.z), 1: (co.x, co.z), 2: (co.x, co.y)}[ax]
            l[uv].uv = (u / size, v / size)


def finish(name, B):
    bmesh.ops.recalc_face_normals(B.bm, faces=B.bm.faces)
    box_uv(B.bm, B.mats)
    me = bpy.data.meshes.new(name); B.bm.to_mesh(me); B.bm.free()
    for k in B.mats: me.materials.append(material(k))
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


def convex(name, pts):
    bm = bmesh.new()
    for p in pts: bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


def cbox(name, a, b):
    return convex(name, [(x, y, z) for x in (a[0], b[0]) for y in (a[1], b[1]) for z in (a[2], b[2])])


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def export(name, vis, cols, note=''):
    bpy.ops.object.select_all(action='DESELECT')
    for o in [vis] + cols: o.select_set(True)
    for i, c in enumerate(cols): c.name = f'{name}_c{i}-convcolonly'
    vis.name = name
    bpy.context.view_layer.objects.active = vis
    # dokular bütün modellerin paylaştığı textures/ klasöründe
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + '.gltf'), export_format='GLTF_SEPARATE',
                              export_texture_dir='textures', use_selection=True,
                              export_apply=True, export_yup=True, export_image_format='AUTO')
    bb = [vis.matrix_world @ Vector(c) for c in vis.bound_box]
    mn = [min(v[i] for v in bb) for i in range(3)]; mx = [max(v[i] for v in bb) for i in range(3)]
    # Godot ekseninde: x genişlik, y yükseklik, z derinlik
    STATS[name] = dict(size=[round(mx[0] - mn[0], 2), round(mx[2] - mn[2], 2), round(mx[1] - mn[1], 2)],
                       tris=tris(vis), note=note)
    log(name, STATS[name])
    for o in [vis] + cols: bpy.data.objects.remove(o)


# ---------- 1. çit: sarı boru korkuluk ----------
R_POST = 0.024   # 48,3 mm boru
TOP, MID = 1.1, 0.55


def post(B, x, y=0.0, h=TOP):
    B.box((x - 0.07, y - 0.07, 0), (x + 0.07, y + 0.07, 0.012), 'sari')
    B.pipe([(x, y, 0.012), (x, y, h - R_POST)], R_POST, 'sari')
    B.pipe([(x, y, h - R_POST), (x, y, h + 0.002)], R_POST * 1.05, 'sari', 10)   # tepe kapağı


def railing(name, L):
    B = Builder()
    post(B, 0)
    B.pipe([(0, 0, TOP - R_POST), (L, 0, TOP - R_POST)], R_POST, 'sari')
    B.pipe([(0, 0, MID), (L, 0, MID)], 0.021, 'sari')
    B.box((0.03, -0.005, 0.012), (L - 0.03, 0.005, 0.16), 'sari')   # süpürgelik
    o = finish(name, B)
    export(name, o, [cbox('c', (-0.04, -0.04, 0), (L, 0.04, TOP))],
           f'orijin direğin dibinde, +X yönüne {L} m; bitişe korkuluk_direk')


railing('korkuluk_2m', 2.0)
railing('korkuluk_1m', 1.0)
B = Builder(); post(B, 0)
export('korkuluk_direk', finish('korkuluk_direk', B), [cbox('c', (-0.04, -0.04, 0), (0.04, 0.04, TOP))],
       'tek direk: sıranın sonu ya da giriş açıklığının kenarı')

# Giriş açıklığı için zincirli geçiş: iki direk arası 1 m, sarkık zincir yerine sarı boru kapı kolu
B = Builder(); post(B, 0); post(B, 1.0)
B.pipe([(0.03, 0, 0.95), (0.97, 0, 0.95)], 0.017, 'sari')
B.pipe([(0.03, 0, 0.5), (0.97, 0, 0.5)], 0.017, 'sari')
B.pipe([(0.5, 0, 0.5), (0.5, 0, 0.95)], 0.012, 'sari')
export('korkuluk_kapi_1m', finish('korkuluk_kapi_1m', B), [cbox('c', (-0.04, -0.04, 0), (1.04, 0.04, TOP))],
       'iki direkli 1 m kapı; açılacaksa kapı kolu ayrı değil, parça olarak kaldırılır')


# ---------- 2. merdivenler ----------
RW = 0.25           # dikmelerin merkezden uzaklığı
WALL = 0.2          # basamak ekseninden duvara


def ladder_core(B, z0, z1, rung0, key='gri', brackets=True):
    for s in (-1, 1):
        B.box((s * RW - 0.006, -0.03, z0), (s * RW + 0.006, 0.03, z1), key)
    z = rung0
    while z < z1 - 0.05:
        B.pipe([(-RW, 0, z), (RW, 0, z)], 0.0125, key, 8)
        z += 0.3
    if brackets:
        for zb in (z0 + 0.6, z1 - 0.6):
            for s in (-1, 1):
                B.box((s * RW - 0.006, 0.03, zb - 0.03), (s * RW + 0.006, WALL, zb + 0.03), key)
                B.box((s * RW - 0.05, WALL - 0.008, zb - 0.06), (s * RW + 0.05, WALL, zb + 0.06), key)


def cage(B, z0, z1, hoops, key='sari'):
    c = (0, -0.33); r = math.hypot(RW, 0.33)
    a0 = math.atan2(0 - c[1], RW); a1 = math.pi - a0
    # halkalar dikmeden dikmeye arkadan dolanır
    for z in hoops:
        B.pipe(arc(c, r, a0, a1 - 2 * math.pi, z, 14)[::-1], 0.01, key, 6)
    for k in range(5):
        a = a0 - (2 * math.pi - (a1 - a0)) * (k + 0.5) / 5
        B.obox((c[0] + r * math.cos(a), c[1] + r * math.sin(a), (z0 + z1) / 2), (0.008, 0.05, z1 - z0), a, key)


B = Builder()
ladder_core(B, 0, 3, 0.15)
cage(B, 0, 3, (0.75, 2.25))
export('kafesli_merdiven_3m', finish('kafesli_merdiven_3m', B), [cbox('c', (-0.28, -0.04, 0), (0.28, 0.04, 3))],
       'üst üste dizilir (basamak 30 cm); duvar -Z tarafında 20 cm geride, kafes +Z tarafında')

B = Builder()
ladder_core(B, 0, 3, 0.15, brackets=True)
export('dam_merdiveni_3m', finish('dam_merdiveni_3m', B), [cbox('c', (-0.28, -0.04, 0), (0.28, 0.04, 3))],
       'kafessiz sabit merdiven; duvar -Z tarafında 20 cm geride')

# Çıkış: orijin platform yüzeyinde. Dikmeler boru olup 1,1 m yükselir ve platforma kıvrılır.
B = Builder()
for s in (-1, 1):
    B.box((s * RW - 0.006, -0.03, -1.5), (s * RW + 0.006, 0.03, 0), 'gri')
    bend = [(s * RW, 0.3 - 0.3 * math.cos(a), 0.8 + 0.3 * math.sin(a)) for a in (math.pi * i / 8 for i in range(9))]
    B.pipe([(s * RW, 0, -0.1)] + bend + [(s * RW, 0.6, 0.012)], 0.021, 'sari')
    B.box((s * RW - 0.07, 0.53, 0), (s * RW + 0.07, 0.67, 0.012), 'sari')
z = -1.35
while z < 0:
    B.pipe([(-RW, 0, z), (RW, 0, z)], 0.0125, 'gri', 8); z += 0.3
cage(B, -1.5, -0.1, (-0.75,))
export('kafesli_merdiven_cikis', finish('kafesli_merdiven_cikis', B),
       [cbox('c', (-0.28, -0.04, -1.5), (0.28, 0.04, 0))],
       'orijin platform yüzeyi ve basamak düzlemi; kafesli_merdiven_3m yığınının tepesi orijinin 1,5 m altında; '
       'tutamaklar platforma (-Z) kıvrılır')


def ramp(name, n, R=0.18, G=0.25, W=0.9):
    B = Builder()
    xe = (n - 1) * G
    H = n * R
    pitch = lambda x: R * (x / G + 1)
    ys = W / 2 + 0.006
    xa = G * (0.16 / R - 1); xb = G * (-0.06 / R - 1)
    poly = [(xb, 0), (xa, 0), (xe, pitch(xe) - 0.16), (xe, pitch(xe) + 0.06)]
    for s in (-1, 1):
        B.prism(poly, s * ys - 0.006, s * ys + 0.006, 'astar')
    for i in range(1, n):
        B.box(((i - 1) * G - 0.025, -W / 2, i * R - 0.035), (i * G, W / 2, i * R), 'pasli_sac')
        B.box(((i - 1) * G - 0.025, -W / 2, i * R - 0.06), ((i - 1) * G - 0.02, W / 2, i * R - 0.035), 'pasli_sac')
    # korkuluk: dikmeler stringerin dışında, tutamak eğim çizgisinin 0,9 m üstünde
    nposts = max(2, math.ceil((xe - 0.2) / 1.5) + 1)
    xs = [0.1 + (xe - 0.2) * k / (nposts - 1) for k in range(nposts)]
    yr = ys + 0.03
    for s in (-1, 1):
        for x in xs:
            B.pipe([(x, s * yr, pitch(x) - 0.12), (x, s * yr, pitch(x) + 0.9)], 0.021, 'sari')
        for h, r in ((0.9, 0.021), (0.45, 0.017)):
            B.pipe([(xs[0] - 0.05, s * yr, pitch(xs[0] - 0.05) + h), (xs[-1] + 0.05, s * yr, pitch(xs[-1] + 0.05) + h)], r, 'sari')
    o = finish(name, B)
    cols = [convex('c', [(x, y, z) for y in (-ys, ys) for x, z in ((xb, 0), (xe, 0), (xe, H), (-G, 0))])]
    for s in (-1, 1):
        cols.append(convex('c', [(x, s * yr + d, pitch(x) + h) for x in (xs[0], xs[-1]) for d in (-0.03, 0.03)
                                 for h in (0.0, 0.92)]))
    export(name, o, cols, f'{n} rıht x {int(R * 100)} cm, basamak {int(G * 100)} cm, net en {W} m; '
                          f'orijin alt basamağın önü, +X yönünde çıkar, üst sahanlık x={xe:.2f} m, y={H:.2f} m')


ramp('merdiven_rampa_1_8m', 10)
ramp('merdiven_rampa_3_6m', 20)


# ---------- 3. demir zemin ----------
def tile_grating(name, sx, sy, t=0.03):
    B = Builder()
    # üst yüz: alfa ızgara
    v =[B.bm.verts.new((x, y, t)) for x, y in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2))]
    B._faces([B.bm.faces.new(v)], 'izgara')
    # taşıyıcı lamalar ve köşebent çerçeve
    k = 0.04
    for a, b in (((-sx / 2, -sy / 2), (sx / 2, -sy / 2 + 0.005)), ((-sx / 2, sy / 2 - 0.005), (sx / 2, sy / 2)),
                 ((-sx / 2, -sy / 2), (-sx / 2 + 0.005, sy / 2)), ((sx / 2 - 0.005, -sy / 2), (sx / 2, sy / 2))):
        B.box((a[0], a[1], 0), (b[0], b[1], t), 'gri')
    x = -sx / 2 + 0.5
    while x < sx / 2 - 0.01:
        B.box((x - 0.003, -sy / 2, 0), (x + 0.003, sy / 2, t - 0.002), 'gri'); x += 0.5
    o = finish(name, B)
    export(name, o, [cbox('c', (-sx / 2, -sy / 2, 0), (sx / 2, sy / 2, t))],
           f'{sx}x{sy} m ızgara, {int(t * 100)} cm; orijin alt orta')


def tile_plate(name, sx, sy, key, t=0.01):
    B = Builder(); B.box((-sx / 2, -sy / 2, 0), (sx / 2, sy / 2, t), key)
    export(name, finish(name, B), [cbox('c', (-sx / 2, -sy / 2, 0), (sx / 2, sy / 2, t))],
           f'{sx}x{sy} m sac, {int(t * 1000)} mm; orijin alt orta')


tile_grating('zemin_izgara_2x1', 2.0, 1.0)
tile_grating('zemin_izgara_1x1', 1.0, 1.0)
tile_plate('zemin_baklava_2x1', 2.0, 1.0, 'baklava')
tile_plate('zemin_pasli_sac_2x1', 2.0, 1.0, 'pasli_sac')


def ibeam(name, L, h=0.2, b=0.1, tw=0.0056, tf=0.0085):
    B = Builder()
    B.box((-L / 2, -b / 2, 0), (L / 2, b / 2, tf), 'astar')
    B.box((-L / 2, -b / 2, h - tf), (L / 2, b / 2, h), 'astar')
    B.box((-L / 2, -tw / 2, tf), (L / 2, tw / 2, h - tf), 'astar')
    export(name, finish(name, B), [cbox('c', (-L / 2, -b / 2, 0), (L / 2, b / 2, h))],
           f'IPE 200 kiriş, {L} m, X boyunca; orijin alt orta')


ibeam('kiris_I_2m', 2.0)
ibeam('kiris_I_4m', 4.0)

B = Builder()
B.box((-0.15, -0.15, 0), (0.15, 0.15, 0.015), 'astar')
for s in (-1, 1):
    B.box((s * 0.06 - 0.004, -0.06, 0.015), (s * 0.06 + 0.004, 0.06, 1.99), 'astar')
    B.box((-0.056, s * 0.06 - 0.004, 0.015), (0.056, s * 0.06 + 0.004, 1.99), 'astar')
B.box((-0.1, -0.1, 1.99), (0.1, 0.1, 2.0), 'astar')
export('kolon_2m', finish('kolon_2m', B), [cbox('c', (-0.15, -0.15, 0), (0.15, 0.15, 2.0))],
       '120x120 kutu profil, 2 m; tepesinde kiriş için başlık plakası')


# ---------- Poly Haven parçaları ----------
def ph_pieces(src, jobs):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=src)
    new = [o for o in bpy.data.objects if o not in before]
    for img in bpy.data.images:
        if img.size[0] > 1024: img.scale(1024, 1024)
    # tel örgü BLEND geliyor: Godot'da sıralama derdi olmasın diye MASK (ROUND düğümü), opaklar tek yüzlü
    for m in {s.material for o in new if o.type == 'MESH' for s in o.material_slots if s.material}:
        b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        if b.inputs['Alpha'].is_linked:
            lk = b.inputs['Alpha'].links[0]
            if lk.from_node.type != 'MATH':
                r = m.node_tree.nodes.new('ShaderNodeMath'); r.operation = 'ROUND'
                m.node_tree.links.new(lk.from_socket, r.inputs[0]); m.node_tree.links.new(r.outputs[0], b.inputs['Alpha'])
            m.use_backface_culling = False
        else:
            m.use_backface_culling = True
    by = {o.name: o for o in new}
    for name, parts, origin, col, note in jobs:
        objs = []
        for p in parts:
            o = by[p].copy(); o.data = by[p].data.copy(); bpy.context.scene.collection.objects.link(o)
            o.data.transform(by[p].matrix_world); o.matrix_world = Matrix(); o.parent = None
            objs.append(o)
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs: o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1: bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        vs = [v.co for v in o.data.vertices]
        mn = Vector([min(v[i] for v in vs) for i in range(3)]); mx = Vector([max(v[i] for v in vs) for i in range(3)])
        oz = mn.z if origin == 'taban' else origin(o, mn, mx)
        sh = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, oz))
        o.data.transform(Matrix.Translation(-sh))
        mn -= sh; mx -= sh
        t = tris(o)
        if t > TRI_MAX:
            d = o.modifiers.new('d', 'DECIMATE'); d.ratio = TRI_MAX * 0.95 / t; d.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier='d')
        cols = col(o, mn, mx)
        export(name, o, cols, note)
    for o in new: bpy.data.objects.remove(o)


def deck_top(o, mn, mx):
    # yürüme yüzeyi: en çok yüzün baktığı yukarı düzlem
    zs = {}
    for p in o.data.polygons:
        if p.normal.z > 0.95:
            k = round(p.center.z, 2); zs[k] = zs.get(k, 0) + p.area
    return max(zs, key=zs.get)


full = lambda o, mn, mx: [cbox('c', mn, mx)]
slab = lambda o, mn, mx: [cbox('c', (mn.x, mn.y, -0.06), (mx.x, mx.y, 0))]


def stairs_col(o, mn, mx):
    # yüksek uç hangi tarafta: üst yarıdaki köşelerin x ortalaması
    hi = [v.co.x for v in o.data.vertices if v.co.z > (mn.z + mx.z) / 2]
    xh, xl = (mn.x, mx.x) if sum(hi) / len(hi) < (mn.x + mx.x) / 2 else (mx.x, mn.x)
    return [convex('c', [(x, y, z) for y in (mn.y, mx.y) for x, z in ((xh, mx.z), (xl, mn.z), (xh, mn.z))])]


FE = os.path.join(DL, 'ph', 'modular_fire_escape', 'modular_fire_escape.gltf')
CL = os.path.join(DL, 'ph', 'modular_chainlink_fence', 'modular_chainlink_fence.gltf')
ph_pieces(FE, [
    ('yangin_platform_a', ['modular_fire_escape_platform_bottom'], deck_top, slab,
     'ızgaralı platform 4,8x1,4 m; orijin yürüme yüzeyi, konsollar altta'),
    ('yangin_platform_b', ['modular_fire_escape_platform_middle'], deck_top, slab,
     'merdiven boşluklu platform; orijin yürüme yüzeyi'),
    ('yangin_korkuluk_4_7m', ['modular_fire_escape_railing_middle'], 'taban', full, 'siyah kaynaklı korkuluk'),
    ('yangin_korkuluk_2_2m', ['modular_fire_escape_platform_railing'], 'taban', full, 'kısa köşe korkuluğu'),
    ('yangin_merdiveni', ['modular_fire_escape_stairs'], 'taban', stairs_col, 'eğik basamaklı merdiven, 4 m yükselir'),
    ('yangin_dik_merdiven_6_5m', ['modular_fire_escape_ladder_bottom'], 'taban', full, 'dikey merdiven 6,5 m'),
])
ph_pieces(CL, [
    ('tel_cit_1m', ['modular_chainlink_fence'], 'taban', full, 'tel panel, direkler arası 1 m'),
    ('tel_cit_2m', ['modular_chainlink_fence_double'], 'taban', full, 'tel panel, direkler arası 2 m'),
    ('tel_cit_direk', ['modular_chainlink_fence_post'], 'taban', full, 'ara direk 2,5 m'),
    ('tel_cit_bitis', ['modular_chainlink_fence_end_01'], 'taban', full, 'uç direk, kelepçeli'),
    ('tel_cit_kapi', ['modular_chainlink_fence_door_frame', 'modular_chainlink_fence_door_gate',
                      'modular_chainlink_fence_door_latch'], 'taban', full, 'kapılı 2 m bölme'),
])

json.dump(STATS, open(os.path.join(OUT, 'cukur.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
log('bitti', len(STATS))
