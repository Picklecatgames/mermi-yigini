# Blender -b --factory-startup --python wasteland.py -- <proje kökü> <indirme klasörü>/dl/pht <istatistik>
# Çöl wasteland parçaları: kum tepeleri (yükseklik alanı), hurdadan sac çitler, lastik ve varil yığınları.
# Kum tepeleri acik_alan/dokular'daki Ground097 dokusunu, çit ve variller Poly Haven pas dokularını,
# lastik yığınları projedeki Poly Haven old_tyre modelini kullanır. Rastgelelik sabit tohumlu.
import bpy, bmesh, sys, os, json, math, random
from mathutils import Vector, Matrix, noise

ROOT, PHT, STATS = sys.argv[sys.argv.index('--') + 1:][:3]
ENV = os.path.join(ROOT, 'assets/env/acik_alan')
MODELS = os.path.join(ROOT, 'assets/env/models')
os.makedirs(STATS, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def log(*a):
    print('@@', *a, flush=True)


def pbr(name, diff, arm, nrm, size=1024):
    m = bpy.data.materials.new(name); m.use_nodes = True
    N = m.node_tree.nodes; L = m.node_tree.links
    b = next(n for n in N if n.type == 'BSDF_PRINCIPLED')

    def tex(p, nc):
        t = N.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(p)
        if nc: t.image.colorspace_settings.name = 'Non-Color'
        if t.image.size[0] > size: t.image.scale(size, size)
        return t
    L.new(tex(diff, False).outputs['Color'], b.inputs['Base Color'])
    sep = N.new('ShaderNodeSeparateColor'); L.new(tex(arm, True).outputs['Color'], sep.inputs['Color'])
    L.new(sep.outputs['Green'], b.inputs['Roughness']); L.new(sep.outputs['Blue'], b.inputs['Metallic'])
    nm = N.new('ShaderNodeNormalMap'); L.new(tex(nrm, True).outputs['Color'], nm.inputs['Color'])
    L.new(nm.outputs['Normal'], b.inputs['Normal'])
    return m


def ph_mat(name, f):
    p = os.path.join(PHT, f, f + '_')
    return pbr(name, p + 'Diffuse.jpg', p + 'arm.jpg', p + 'nor_gl.jpg')


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def hull_of(o, name, limit=48):
    bm = bmesh.new(); bm.from_mesh(o.data)
    r = bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.delete(bm, geom=list({v for v in r['geom_interior'] + r['geom_unused'] if isinstance(v, bmesh.types.BMVert)}), context='VERTS')
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    h = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(h)
    if len(me.vertices) > limit:
        d = h.modifiers.new('d', 'DECIMATE'); d.ratio = limit / len(me.vertices) * 1.6
        bpy.context.view_layer.objects.active = h; bpy.ops.object.select_all(action='DESELECT'); h.select_set(True)
        bpy.ops.object.modifier_apply(modifier='d')
    return h


def box_obj(name, mn, mx):
    me = bpy.data.meshes.new(name)
    c = [Vector((x, y, z)) for x in (mn[0], mx[0]) for y in (mn[1], mx[1]) for z in (mn[2], mx[2])]
    me.from_pydata(c, [], [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


def export(o, hulls, out, tex_dir, extra=None):
    os.makedirs(out, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for x in [o] + hulls: x.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, o.name + '.gltf'), export_format='GLTF_SEPARATE', use_selection=True,
                              export_texture_dir=tex_dir, export_image_format='JPEG', export_jpeg_quality=88,
                              export_apply=True, export_yup=True, export_animations=False, export_materials='EXPORT')
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    sz = [round(max(p[i] for p in pts) - min(p[i] for p in pts), 3) for i in (0, 2, 1)]
    st = dict(ucgen=tri_count(o), boyut_m=sz, carpisma='convex' if hulls else 'none')
    st.update(extra or {})
    json.dump(st, open(os.path.join(STATS, o.name + '.json'), 'w', encoding='utf8'), ensure_ascii=False)
    log('OK', o.name, st['ucgen'], sz)
    for x in [o] + hulls: bpy.data.objects.remove(x)


# ---------- kum tepeleri ----------
# barkan biçimi: rüzgâr yüzü (-X) yatık, rüzgâraltı (+X) dik; tepe eğrisi iki yana boynuz gibi uzar.
def dune(pid, L, W, H, seed, n=72, horns=0.35):
    rnd = random.Random(seed); off = Vector((rnd.uniform(0, 100), rnd.uniform(0, 100), 0))
    bm = bmesh.new(); uv = bm.loops.layers.uv.verify()
    grid = []
    for j in range(n + 1):
        row = []
        for i in range(n + 1):
            x = (i / n - 0.5) * L; y = (j / n - 0.5) * W
            v = y / (W / 2)
            crest = L * 0.12 + horns * L * v * v          # tepe çizgisi kenarlara doğru rüzgâraltına kayar
            d = x - crest
            prof = math.exp(-(d / (L * 0.32)) ** 2) if d < 0 else math.exp(-(d / (L * 0.11)) ** 2)
            fall = max(0.0, 1 - v * v) ** 1.5
            edge = min(1.0, (0.5 - abs(i / n - 0.5)) * 8) * min(1.0, (0.5 - abs(j / n - 0.5)) * 8)
            h = H * prof * fall
            h += H * 0.06 * noise.noise(off + Vector((x / 9, y / 9, 0))) * fall
            h = max(0.0, h) * edge
            row.append(bm.verts.new((x, y, h)))
        grid.append(row)
    for j in range(n):
        for i in range(n):
            f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
            for l in f.loops: l[uv].uv = (l.vert.co.x / 2.0, l.vert.co.y / 2.0)
    # kenarı biraz yere gömüp alttan görünmesini önle
    for row in grid:
        for v in row:
            if v.co.z < 0.001: v.co.z = -0.05
    me = bpy.data.meshes.new(pid); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    o = bpy.data.objects.new(pid, me); bpy.context.scene.collection.objects.link(o)
    me.materials.append(KUM)
    # yükseklik 0 seviyesinden ölçülür; gömülü kenar tabanın altında kalır
    export(o, [hull_of(o, pid + '-convcolonly', 64)], os.path.join(ENV, 'kum_tepeleri'), 'doku_kum',
           dict(kaynak='kendi modelim (tools/atolye/wasteland.py), doku ambientCG Ground097, CC0'))


D = os.path.join(ENV, 'dokular/ground097/ground097_')
KUM = pbr('kum', D + 'diff_2k.jpg', D + 'arm_2k.jpg', D + 'nor_gl_2k.jpg', 2048)
dune('kum_tepesi_kucuk', 24, 18, 2.5, 1)
dune('kum_tepesi_orta', 45, 32, 5.0, 2)
dune('kum_tepesi_buyuk', 80, 60, 10.0, 3, n=96)
dune('kum_tepesi_uzun', 60, 26, 4.0, 4, horns=0.15)


# ---------- hurdadan sac çit ----------
# paslı sac ve varil dokuları; çitte her sac rastgele birini alır, son malzeme direklerin ahşabı
SACLAR = [ph_mat('pas_kaba', 'rust_coarse_01'), ph_mat('yesil_pas', 'green_metal_rust'),
          ph_mat('boyali_pas', 'rusty_painted_metal'), ph_mat('pas', 'rusty_metal_02')]
AHSAP = ph_mat('ahsap', 'fine_grained_wood')
# sacın yerel ekseni: x boyu (dünya Z), y eni (dünya X), z normali (dünya Y)
UPRIGHT = Matrix(((0, 1, 0, 0), (0, 0, 1, 0), (1, 0, 0, 0), (0, 0, 0, 1)))


def sheet(bm, mtx, length, width, mat_i, pitch=0.076, depth=0.018, t=0.0008, dent=0.0, rnd=None, uv_off=(0, 0)):
    # oluklu sac, yerel X boyunca uzun (dalgalar X'e paralel), Y genişlik; mtx ile yerleşir
    n = int(round(width / pitch)) * 6; m = 6
    uv = bm.loops.layers.uv.verify()
    top = [[None] * (n + 1) for _ in range(m + 1)]; bot = [[None] * (n + 1) for _ in range(m + 1)]
    for a in range(m + 1):
        x = length * a / m - length / 2
        for b in range(n + 1):
            y = -width / 2 + width * b / n
            z = depth / 2 * (1 + math.sin(2 * math.pi * y / pitch))
            if dent: z += dent * math.sin(math.pi * a / m) * math.sin(math.pi * b / n) * rnd.uniform(0.5, 1.0)
            top[a][b] = bm.verts.new(mtx @ Vector((x, y, z + t))); bot[a][b] = bm.verts.new(mtx @ Vector((x, y, z)))
    for a in range(m):
        for b in range(n):
            for grid, rev in ((top, False), (bot, True)):
                q = [grid[a][b], grid[a + 1][b], grid[a + 1][b + 1], grid[a][b + 1]]
                f = bm.faces.new(q[::-1] if rev else q); f.material_index = mat_i; f.smooth = True
                for l, (aa, bb) in zip(f.loops, ([(a, b), (a + 1, b), (a + 1, b + 1), (a, b + 1)][::-1] if rev else [(a, b), (a + 1, b), (a + 1, b + 1), (a, b + 1)])):
                    l[uv].uv = (uv_off[0] + aa * length / m / 2, uv_off[1] + bb * width / n / 2)  # doku 2 m'de bir


def post(bm, x, y, w, h, mat_i, tilt=0.0):
    uv = bm.loops.layers.uv.verify()
    mtx = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(tilt, 4, 'Y')
    vs = [bm.verts.new(mtx @ Vector((sx * w / 2, sy * w / 2, z))) for sx in (-1, 1) for sy in (-1, 1) for z in (0, h)]
    for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6)):
        f = bm.faces.new([vs[i] for i in q]); f.material_index = mat_i
        for l in f.loops:
            c = mtx.inverted() @ l.vert.co; l[uv].uv = (c.x + c.y, c.z)


def scrap_fence(pid, seed, span=2.4, h=2.0):
    # iki ahşap direk, aralarında üç yatay kuşak boyunca üst üste binen, eğri büğrü dikili saclar
    rnd = random.Random(seed)
    bm = bmesh.new()
    for x in (-span / 2, span / 2):
        post(bm, x, 0.06, 0.1, h + rnd.uniform(0.05, 0.3), len(SACLAR), rnd.uniform(-0.05, 0.05))
    x = -span / 2 - 0.15
    while x < span / 2 + 0.1:
        w = rnd.uniform(0.6, 0.95); hh = h * rnd.uniform(0.82, 1.0)
        lean = rnd.uniform(-0.06, 0.06); twist = rnd.uniform(-0.04, 0.04)
        mtx = (Matrix.Translation((x + w / 2, rnd.uniform(0.0, 0.03), hh / 2 + rnd.uniform(-0.05, 0.05)))
               @ Matrix.Rotation(twist, 4, 'Z') @ Matrix.Rotation(lean, 4, 'Y') @ UPRIGHT)
        sheet(bm, mtx, hh, w, rnd.randrange(len(SACLAR)), dent=0.04, rnd=rnd, uv_off=(rnd.random(), rnd.random()))
        x += w * rnd.uniform(0.7, 0.85)
    me = bpy.data.meshes.new(pid); bm.to_mesh(me); bm.free()
    for m in SACLAR + [AHSAP]: me.materials.append(m)
    o = bpy.data.objects.new(pid, me); bpy.context.scene.collection.objects.link(o)
    mn = [min(v.co[i] for v in me.vertices) for i in range(3)]; mx = [max(v.co[i] for v in me.vertices) for i in range(3)]
    me.transform(Matrix.Translation((-(mn[0] + mx[0]) / 2, -(mn[1] + mx[1]) / 2, -mn[2])))
    mn = [min(v.co[i] for v in me.vertices) for i in range(3)]; mx = [max(v.co[i] for v in me.vertices) for i in range(3)]
    export(o, [box_obj(pid + '-convcolonly', mn, mx)], os.path.join(ROOT, 'assets/props/atolye/yapi'), 'doku_cit',
           dict(kaynak='kendi modelim (tools/atolye/wasteland.py), dokular Poly Haven rust_coarse_01, green_metal_rust, rusty_painted_metal, rusty_metal_02, fine_grained_wood, CC0'))


scrap_fence('sac_cit_a', 11)
scrap_fence('sac_cit_b', 12)
scrap_fence('sac_cit_c', 13, span=3.0, h=2.3)


# ---------- lastik ve varil yığınları ----------
def load_parts(rel, flat=False):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, rel))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1: bpy.ops.object.join()
    src = bpy.context.view_layer.objects.active
    for o in new:
        if o != src and o.name in bpy.data.objects: bpy.data.objects.remove(o)
    if flat:  # en ince ekseni yukarı çevir (lastik yatsın)
        pts = [v.co for v in src.data.vertices]
        ext = [max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3)]
        k = ext.index(min(ext))
        if k == 1: src.data.transform(Matrix.Rotation(math.pi / 2, 4, 'X'))
        elif k == 0: src.data.transform(Matrix.Rotation(math.pi / 2, 4, 'Y'))
    pts = [v.co for v in src.data.vertices]
    mn = Vector([min(p[i] for p in pts) for i in range(3)]); mx = Vector([max(p[i] for p in pts) for i in range(3)])
    src.data.transform(Matrix.Translation(-Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))))
    src.hide_set(True)
    return src, mx - mn


def pile(pid, items, out, tex_dir, kaynak):
    objs = []
    for src, mtx in items:
        c = src.copy(); c.data = src.data.copy(); bpy.context.scene.collection.objects.link(c)
        c.hide_set(False); c.matrix_world = mtx; objs.append(c)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = pid
    pts = [v.co for v in o.data.vertices]
    mn = Vector([min(p[i] for p in pts) for i in range(3)]); mx = Vector([max(p[i] for p in pts) for i in range(3)])
    o.data.transform(Matrix.Translation(-Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))))
    export(o, [hull_of(o, pid + '-convcolonly')], out, tex_dir, dict(kaynak=kaynak))


T = Matrix.Translation; R = Matrix.Rotation
tyre, ts = load_parts('old_tyre/old_tyre_1k.gltf', flat=True)
flat = Matrix.Identity(4)
th = ts.z; dia = max(ts.x, ts.y)
rnd = random.Random(21)
st = []
for k in range(5):  # dik kule, hafif kaymış
    st.append((tyre, T((rnd.uniform(-0.04, 0.04), rnd.uniform(-0.04, 0.04), k * th * 0.97)) @ R(rnd.uniform(0, 6.28), 4, 'Z') @ R(rnd.uniform(-0.04, 0.04), 4, 'X') @ flat))
pile('lastik_kulesi', st, os.path.join(ENV, 'yiginlar'), 'doku_lastik', 'Poly Haven old_tyre, CC0; dizilim benim')
st = []
for k, (x, y) in enumerate(((0, 0), (dia * 0.98, 0), (dia * 0.49, dia * 0.85), (-dia * 0.2, dia * 0.95))):  # yayvan yığın
    st.append((tyre, T((x, y, 0)) @ R(rnd.uniform(0, 6.28), 4, 'Z') @ flat))
st.append((tyre, T((dia * 0.45, dia * 0.3, th * 0.95)) @ R(0.12, 4, 'X') @ flat))
st.append((tyre, T((dia * 0.1, dia * 0.5, th * 1.0)) @ R(-0.15, 4, 'Y') @ flat))
st.append((tyre, T((dia * 0.3, dia * 0.4, th * 1.95)) @ R(0.05, 4, 'X') @ flat))
st.append((tyre, T((dia * 1.4, -dia * 0.2, dia * 0.5)) @ R(1.2, 4, 'Z') @ R(math.pi / 2 - 0.25, 4, 'X') @ flat))  # yaslanmış
pile('lastik_yigini', st, os.path.join(ENV, 'yiginlar'), 'doku_lastik', 'Poly Haven old_tyre, CC0; dizilim benim')

# 200 litrelik varil: 58,5 cm çap, 88 cm boy, iki yuvarlanma çemberi, kenar kıvrımları
def drum(pid, mat, seed, dent=0.012):
    rnd = random.Random(seed); r = 0.2925; h = 0.88; seg = 32
    # (z, yarıçap) profili
    prof = [(0.0, r - 0.006), (0.012, r + 0.004), (0.025, r), (0.29, r), (0.30, r + 0.012), (0.31, r),
            (0.57, r), (0.58, r + 0.012), (0.59, r), (h - 0.025, r), (h - 0.012, r + 0.004), (h, r - 0.006)]
    bm = bmesh.new(); uv = bm.loops.layers.uv.verify()
    rings = []
    for z, rr in prof:
        ring = []
        for k in range(seg + 1):
            a = 2 * math.pi * k / seg
            d = 1 - dent * max(0.0, noise.noise(Vector((math.cos(a) * 2 + seed, math.sin(a) * 2, z * 3))))
            ring.append(bm.verts.new((math.cos(a) * rr * d, math.sin(a) * rr * d, z)))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for k in range(seg):
            f = bm.faces.new((rings[j][k], rings[j][k + 1], rings[j + 1][k + 1], rings[j + 1][k])); f.smooth = True
            for l, (jj, kk) in zip(f.loops, ((j, k), (j, k + 1), (j + 1, k + 1), (j + 1, k))):
                l[uv].uv = (2 * math.pi * r * kk / seg / 1.5, prof[jj][0] / 1.5)
    for ring, z, up in ((rings[0], 0.003, False), (rings[-1], h - 0.006, True)):  # içe çökük kapaklar
        c = bm.verts.new((0, 0, z)); ring = ring[:-1]
        for k in range(seg):
            q = (c, ring[k], ring[(k + 1) % seg]) if up else (c, ring[(k + 1) % seg], ring[k])
            f = bm.faces.new(q)
            for l in f.loops: l[uv].uv = (l.vert.co.x / 1.5 + 0.5, l.vert.co.y / 1.5 + 0.5)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    me = bpy.data.meshes.new(pid); bm.to_mesh(me); bm.free(); me.materials.append(mat)
    o = bpy.data.objects.new(pid, me); bpy.context.scene.collection.objects.link(o)
    return o


VARIL = []
for i, (ad, m) in enumerate((('varil_yesil', 1), ('varil_pasli', 0), ('varil_boyali', 2))):
    o = drum(ad, SACLAR[m], i + 31)
    VARIL.append(o.copy()); VARIL[-1].data = o.data.copy(); bpy.context.scene.collection.objects.link(VARIL[-1]); VARIL[-1].hide_set(True)
    export(o, [hull_of(o, ad + '-convcolonly')], os.path.join(ENV, 'yiginlar'), 'doku_varil',
           dict(kaynak='kendi modelim (tools/atolye/wasteland.py), dokular Poly Haven green_metal_rust, rust_coarse_01, rusty_painted_metal, CC0'))
va, vb, vc = VARIL
d = 0.6; h2 = 0.88
st = [(va, T((0, 0, 0)) @ R(0.3, 4, 'Z')), (vb, T((d, 0.05, 0)) @ R(1.1, 4, 'Z')), (vc, T((d * 0.5, d * 0.86, 0)) @ R(2.0, 4, 'Z')),
      (vb, T((d * 0.5, d * 0.3, h2)) @ R(0.7, 4, 'Z')),
      (vc, T((-d * 0.9, d * 0.4, 0.2925)) @ R(0.4, 4, 'Z') @ R(math.pi / 2, 4, 'Y'))]  # yatık varil
pile('varil_yigini', st, os.path.join(ENV, 'yiginlar'), 'doku_varil', 'kendi modelim, Poly Haven pas dokuları, CC0')
st = [(vb, T((0, 0, 0))), (va, T((d * 0.98, 0, 0)) @ R(2.5, 4, 'Z')), (vc, T((d * 1.7, d * 0.7, 0.02)) @ R(math.radians(10), 4, 'X'))]
pile('varil_sirasi', st, os.path.join(ENV, 'yiginlar'), 'doku_varil', 'kendi modelim, Poly Haven pas dokuları, CC0')
