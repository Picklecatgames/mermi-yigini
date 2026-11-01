# Blender -b --python process.py -- job.json
# Kaynak modeli parçalara ayırır, düşürür, yeni UV açar, yüksekten alçağa bake eder,
# pas/kir katmanını bake eder, dışbükey çarpışma ekler ve parça başına glb yazar.
import bpy, bmesh, sys, json, os, math
from mathutils import Vector, Matrix

job = json.load(open(sys.argv[sys.argv.index('--') + 1], encoding='utf8'))
RES = job.get('res', 1024)
OUT = job['out']; THUMBS = job['thumbs']; STATS = os.path.join(OUT, '_stats')
os.makedirs(OUT, exist_ok=True); os.makedirs(THUMBS, exist_ok=True); os.makedirs(STATS, exist_ok=True)
RUST = job['rust_dir']


def log(*a):
    print('@@', *a, flush=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    prefs = bpy.context.preferences.addons['cycles'].preferences
    for dt in (() if os.environ.get('HCPU') else ('OPTIX', 'CUDA')):
        try:
            prefs.compute_device_type = dt
            prefs.get_devices()
            for d in prefs.devices:
                d.use = True
            sc.cycles.device = 'GPU'
            break
        except Exception:
            continue
    sc.cycles.samples = 4
    sc.cycles.use_denoising = False


def load_source():
    src = job['src']; ext = os.path.splitext(src)[1].lower()
    if ext in ('.gltf', '.glb'):
        bpy.ops.import_scene.gltf(filepath=src)
    elif ext == '.fbx':
        bpy.ops.import_scene.fbx(filepath=src)
    elif ext == '.obj':
        bpy.ops.wm.obj_import(filepath=src)
    elif ext == '.blend':
        with bpy.data.libraries.load(src) as (a, b):
            b.objects = a.objects
        for o in b.objects:
            if o: bpy.context.scene.collection.objects.link(o)
    # Kaynak dosyada gömülü olmayan dokular için
    for img in bpy.data.images:
        if img.source == 'FILE' and not img.has_data:
            try: img.reload()
            except Exception: pass


def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == 'MESH']


def select_only(objs, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def bake_world_transforms(objs):
    # Ebeveyn zincirini ve dönüşümleri ağa uygula
    for o in objs:
        mw = o.matrix_world.copy()
        if o.data.users > 1:
            o.data = o.data.copy()
        if o.data.shape_keys:
            mix = o.shape_key_add(name='__mix', from_mix=True)
            for k in [k for k in o.data.shape_keys.key_blocks if k.name != '__mix']:
                o.shape_key_remove(k)
            o.shape_key_remove(o.data.shape_keys.key_blocks['__mix'])
        o.parent = None
        o.data.transform(mw)
        if mw.determinant() < 0:
            o.data.flip_normals()
        o.matrix_world = Matrix.Identity(4)


def join(objs):
    bake_world_transforms(objs)
    if len(objs) > 1:
        select_only(objs)
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active if len(objs) > 1 else objs[0]
    return o


def align_normals(low, high):
    # Düşürme sonrası ters dönen yüzleri yüksek modelin en yakın yüzüne göre çevir
    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromObject(high, bpy.context.evaluated_depsgraph_get())
    bm = bmesh.new(); bm.from_mesh(low.data); bm.faces.ensure_lookup_table()
    flip = []
    for f in bm.faces:
        loc, nrm, idx, dist = bvh.find_nearest(f.calc_center_median())
        if nrm is not None and nrm.dot(f.normal) < 0:
            flip.append(f)
    bmesh.ops.reverse_faces(bm, faces=flip)
    bm.to_mesh(low.data); bm.free()
    log('FLIP', len(flip), len(low.data.polygons))


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def world_bbox(o):
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return mn, mx


def target_tris(L, override=None):
    if override: return override
    if L < 0.1: return 500
    if L < 0.3: return 1200
    if L < 0.6: return 1500
    return 2000


# --- malzeme yardımcıları ---
def principled(mat):
    if not mat or not mat.use_nodes: return None
    return next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)


def output_node(mat):
    return next((n for n in mat.node_tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output), None) or \
        next((n for n in mat.node_tree.nodes if n.type == 'OUTPUT_MATERIAL'), None)


def prep_emit(mat):
    nt = mat.node_tree
    em = nt.nodes.get('__emit') or nt.nodes.new('ShaderNodeEmission'); em.name = '__emit'
    return em


def route(obj, channel):
    """Yüksek modelin malzemelerini channel'ı (base/rough/metal/None=orijinal) emisyona bağlar."""
    for slot in obj.material_slots:
        mat = slot.material
        if not mat: continue
        if not mat.use_nodes:
            mat.use_nodes = True
        nt = mat.node_tree; out = output_node(mat)
        if out is None:
            out = nt.nodes.new('ShaderNodeOutputMaterial')
        bsdf = principled(mat)
        if '__orig' not in mat:
            mat['__orig'] = 1
            if out.inputs['Surface'].is_linked:
                l = out.inputs['Surface'].links[0]
                mat['__orig_node'] = l.from_node.name; mat['__orig_sock'] = l.from_socket.identifier
        for l in list(out.inputs['Surface'].links): nt.links.remove(l)
        if channel is None:
            if mat.get('__orig_node'):
                n = nt.nodes[mat['__orig_node']]
                s = next(s for s in n.outputs if s.identifier == mat['__orig_sock'])
                nt.links.new(s, out.inputs['Surface'])
            continue
        em = prep_emit(mat)
        for l in list(em.inputs['Color'].links): nt.links.remove(l)
        nt.links.new(em.outputs[0], out.inputs['Surface'])
        name = {'base': 'Base Color', 'rough': 'Roughness', 'metal': 'Metallic'}[channel]
        if bsdf is None:
            em.inputs['Color'].default_value = {'base': (0.4, 0.4, 0.4, 1), 'rough': (0.7,) * 3 + (1,), 'metal': (0, 0, 0, 1)}[channel]
            continue
        inp = bsdf.inputs[name]
        if inp.is_linked:
            nt.links.new(inp.links[0].from_socket, em.inputs['Color'])
        else:
            v = inp.default_value
            em.inputs['Color'].default_value = tuple(v) if channel == 'base' else (v, v, v, 1)
        # cam gibi saydam yüzeyler bake'te ışığı geçirmesin
        em.inputs['Strength'].default_value = 1.0


def new_image(name, color=True):
    img = bpy.data.images.new(name, RES, RES, alpha=False, float_buffer=False)
    if not color: img.colorspace_settings.name = 'Non-Color'
    return img


def target_node(mat, img):
    nt = mat.node_tree
    for n in nt.nodes: n.select = False
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = img
    t.select = True; nt.nodes.active = t
    return t


def do_bake(kind, low, high, L, img):
    sc = bpy.context.scene
    mat = low.data.materials[0]
    t = target_node(mat, img)
    sc.render.bake.use_selected_to_active = high is not None
    sc.render.bake.cage_extrusion = 0.02 * L
    sc.render.bake.max_ray_distance = 0.06 * L
    sc.render.bake.margin = 6
    sc.render.bake.use_clear = True
    if high is not None:
        select_only([high, low], low)
    else:
        select_only([low])
    if kind == 'NORMAL':
        sc.render.bake.normal_space = 'TANGENT'
        bpy.ops.object.bake(type='NORMAL')
    else:
        bpy.ops.object.bake(type='EMIT')
    mat.node_tree.nodes.remove(t)
    if os.environ.get('HDEBUG'):
        import array
        a = array.array('f', [0.0]) * (RES * RES * 4); img.pixels.foreach_get(a)
        log('BAKE', kind, img.name, sum(a[::4]) / (RES * RES), sum(a[1::4]) / (RES * RES))


def save_png(img, path):
    img.filepath_raw = path; img.file_format = 'PNG'; img.save()


def fix_normal(img):
    # Alçak ve yüksek yüzün yönü ters düşen yerlerde bake z<0 verir; oralarda düz normal kullan
    import numpy as np
    a = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32); img.pixels.foreach_get(a)
    a = a.reshape(-1, 4)
    bad = a[:, 2] < 0.55
    a[bad, 0:3] = (0.5, 0.5, 1.0)
    img.pixels.foreach_set(a.ravel())
    log('NRMFIX', int(bad.sum()))


def persist(img, noncolor):
    d = os.path.join(STATS, 'tex'); os.makedirs(d, exist_ok=True)
    path = os.path.join(d, img.name + '.png')
    save_png(img, path)
    bpy.data.images.remove(img)
    out = bpy.data.images.load(path)
    if noncolor: out.colorspace_settings.name = 'Non-Color'
    return out


# --- pas katmanı ---
def rust_material(low, base, rough, metal, normal, amt, L, grime, paint):
    mat = bpy.data.materials.new('rust_tmp'); mat.use_nodes = True
    nt = mat.node_tree; N = nt.nodes; Lk = nt.links
    for n in list(N):
        if n.type != 'OUTPUT_MATERIAL': N.remove(n)
    out = output_node(mat)

    def tex(img, noncolor=False):
        t = N.new('ShaderNodeTexImage'); t.image = img
        return t
    tb, tr, tm = tex(base), tex(rough, True), tex(metal, True)
    # Kutu izdüşümlü pas dokusu, gerçek ölçekte (~0.35 m karo)
    co = N.new('ShaderNodeTexCoord')
    mp = N.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (1 / 0.35,) * 3
    Lk.new(co.outputs['Object'], mp.inputs['Vector'])

    def box(path, noncolor=False):
        img = bpy.data.images.load(path, check_existing=True)
        if noncolor: img.colorspace_settings.name = 'Non-Color'
        t = N.new('ShaderNodeTexImage'); t.image = img; t.projection = 'BOX'; t.projection_blend = 0.3
        Lk.new(mp.outputs[0], t.inputs['Vector'])
        return t
    rc = box(os.path.join(RUST, 'Rust009_2K-JPG_Color.jpg'))
    rr = box(os.path.join(RUST, 'Rust009_2K-JPG_Roughness.jpg'), True)

    # Maske: gürültü + kenar (içten AO) + girinti (dıştan AO)
    nz = N.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 6.0 / max(L, 0.05) * 0.25 + 3.0
    nz.inputs['Detail'].default_value = 10; nz.inputs['Roughness'].default_value = 0.65
    Lk.new(co.outputs['Object'], nz.inputs['Vector'])
    dc = N.new('ShaderNodeVertexColor'); dc.layer_name = 'dirt'

    def math(op, a, b=None, clamp=True):
        m = N.new('ShaderNodeMath'); m.operation = op; m.use_clamp = clamp
        for i, v in enumerate((a, b)):
            if v is None: continue
            if isinstance(v, (int, float)): m.inputs[i].default_value = v
            else: Lk.new(v, m.inputs[i])
        return m.outputs[0]
    dv = math('SUBTRACT', dc.outputs['Color'], 0.5, clamp=False)
    cav = math('MULTIPLY', dv, -2.5)                           # girinti
    edge = math('MULTIPLY', dv, 2.5)
    edge = math('POWER', edge, 2.0)                            # dışbükey kenar, yalnız uçlar
    raw = math('ADD', nz.outputs['Fac'], math('ADD', math('MULTIPLY', edge, 0.4), math('MULTIPLY', cav, 0.3)), clamp=False)
    mr = N.new('ShaderNodeMapRange'); mr.interpolation_type = 'SMOOTHSTEP'
    thr = 0.85 - amt * 0.6
    mr.inputs['From Min'].default_value = thr - 0.12; mr.inputs['From Max'].default_value = thr + 0.12
    Lk.new(raw, mr.inputs['Value'])
    # pas metalde tam, boyalı metalde paint kadar (ahşap, karton, kauçukta paint=0)
    rustable = math('ADD', math('MULTIPLY', math('SUBTRACT', 1.0, tm.outputs['Color']), paint), tm.outputs['Color'])
    mask = math('MULTIPLY', mr.outputs['Result'], rustable)
    mask = math('MULTIPLY', mask, 1.0 if amt > 0 else 0.0)
    # geniş, yarı saydam pas lekesi (ince pas)
    mr2 = N.new('ShaderNodeMapRange'); mr2.interpolation_type = 'SMOOTHSTEP'
    mr2.inputs['From Min'].default_value = thr - 0.35; mr2.inputs['From Max'].default_value = thr
    Lk.new(raw, mr2.inputs['Value'])
    stain = math('MULTIPLY', math('MULTIPLY', mr2.outputs['Result'], rustable), 0.45 if amt > 0 else 0.0)
    mask_c = math('MAXIMUM', mask, stain)

    # Renk: taban → pas → kir → ortak renk düzeltmesi
    mix = N.new('ShaderNodeMix'); mix.data_type = 'RGBA'
    Lk.new(mask_c, mix.inputs['Factor']); Lk.new(tb.outputs['Color'], mix.inputs['A']); Lk.new(rc.outputs['Color'], mix.inputs['B'])
    dirt = N.new('ShaderNodeMix'); dirt.data_type = 'RGBA'; dirt.blend_type = 'MULTIPLY'
    Lk.new(math('MINIMUM', math('MULTIPLY', math('ADD', math('MULTIPLY', cav, 0.6), math('MULTIPLY', nz.outputs['Fac'], 0.25)), grime), 0.2), dirt.inputs['Factor'])
    Lk.new(mix.outputs['Result'], dirt.inputs['A']); dirt.inputs['B'].default_value = (0.42, 0.33, 0.24, 1)
    hsv = N.new('ShaderNodeHueSaturation'); hsv.inputs['Saturation'].default_value = 0.92
    Lk.new(dirt.outputs['Result'], hsv.inputs['Color'])
    bc = N.new('ShaderNodeBrightContrast'); bc.inputs['Contrast'].default_value = 0.04
    Lk.new(hsv.outputs['Color'], bc.inputs['Color'])
    warm = N.new('ShaderNodeMix'); warm.data_type = 'RGBA'; warm.blend_type = 'MULTIPLY'; warm.inputs['Factor'].default_value = 0.12
    Lk.new(bc.outputs['Color'], warm.inputs['A']); warm.inputs['B'].default_value = (1.0, 0.86, 0.7, 1)
    col_out = warm.outputs['Result']

    # Pürüz: pasta pas pürüzü, parlak yüzeyler en az 0.38
    rmix = N.new('ShaderNodeMix'); rmix.data_type = 'FLOAT'
    Lk.new(mask, rmix.inputs['Factor']); Lk.new(tr.outputs['Color'], rmix.inputs[2]); Lk.new(rr.outputs['Color'], rmix.inputs[3])
    rough_out = math('MAXIMUM', rmix.outputs[0], 0.38)
    rough_out = math('ADD', rough_out, math('MULTIPLY', cav, 0.15))
    # Metallik: pas metal değil
    metal_out = math('MULTIPLY', tm.outputs['Color'], math('SUBTRACT', 1.0, math('MULTIPLY', mask, 0.95)))

    em = N.new('ShaderNodeEmission'); Lk.new(em.outputs[0], out.inputs['Surface'])
    # AO node'ları bake'te normal haritayı görmez; geometri yeter
    low.data.materials.clear(); low.data.materials.append(mat)
    dbg = {'d_mask': mask_c, 'd_rust': rc.outputs['Color'], 'd_cav': cav, 'd_edge': edge, 'd_mix': mix.outputs['Result'], 'd_dirt': dirt.outputs['Result']}
    return mat, em, dict({'base': col_out, 'rough': rough_out, 'metal': metal_out}, **(dbg if os.environ.get('HDEBUG') else {}))


def final_material(name, col, rough, metal, nrm):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    nt = mat.node_tree; N = nt.nodes; Lk = nt.links
    b = principled(mat)

    def tex(img, nc):
        t = N.new('ShaderNodeTexImage'); t.image = img
        return t
    Lk.new(tex(col, False).outputs['Color'], b.inputs['Base Color'])
    Lk.new(tex(rough, True).outputs['Color'], b.inputs['Roughness'])
    Lk.new(tex(metal, True).outputs['Color'], b.inputs['Metallic'])
    nm = N.new('ShaderNodeNormalMap'); Lk.new(tex(nrm, True).outputs['Color'], nm.inputs['Color'])
    Lk.new(nm.outputs['Normal'], b.inputs['Normal'])
    return mat


def convex_hull(low, name):
    bm = bmesh.new(); bm.from_mesh(low.data)
    res = bmesh.ops.convex_hull(bm, input=bm.verts)
    for g in res.get('geom_interior', []) + res.get('geom_unused', []):
        if isinstance(g, bmesh.types.BMVert) and g.is_valid: pass
    bmesh.ops.delete(bm, geom=list({v for v in res['geom_interior'] + res['geom_unused'] if isinstance(v, bmesh.types.BMVert)}), context='VERTS')
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    o.matrix_world = low.matrix_world.copy()
    if len(me.vertices) > 48:
        d = o.modifiers.new('d', 'DECIMATE'); d.ratio = 48 / len(me.vertices) * 1.6
        select_only([o]); bpy.ops.object.modifier_apply(modifier='d')
        # tekrar dışbükey yap
        bm = bmesh.new(); bm.from_mesh(o.data)
        r = bmesh.ops.convex_hull(bm, input=bm.verts)
        bmesh.ops.delete(bm, geom=list({v for v in r['geom_interior'] + r['geom_unused'] if isinstance(v, bmesh.types.BMVert)}), context='VERTS')
        bm.to_mesh(o.data); bm.free()
    bm = bmesh.new(); bm.from_mesh(o.data); vol = bm.calc_volume(signed=False); bm.free()
    return o, vol


# --- önizleme ---
def render_thumb(objs, path):
    sc = bpy.context.scene
    shown = set(o.name for o in objs)
    hidden = []
    for o in sc.objects:
        if o.type in ('MESH',) and o.name not in shown and not o.hide_render:
            o.hide_render = True; hidden.append(o)
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in objs:
        a, b = world_bbox(o); mn = Vector(map(min, mn, a)); mx = Vector(map(max, mx, b))
    c = (mn + mx) / 2; L = (mx - mn).length
    cam_d = bpy.data.cameras.new('c'); cam_d.type = 'ORTHO'; cam_d.ortho_scale = L * 1.05
    cam = bpy.data.objects.new('cam', cam_d); sc.collection.objects.link(cam)
    d = Vector((1.0, -1.3, 0.9)).normalized()
    cam.location = c + d * L * 2
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sun_d = bpy.data.lights.new('s', 'SUN'); sun_d.energy = 3.2; sun_d.angle = 0.2
    sun = bpy.data.objects.new('sun', sun_d); sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    if not sc.world: sc.world = bpy.data.worlds.new('w')
    sc.world.use_nodes = True
    bg = next(n for n in sc.world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = (0.42, 0.42, 0.44, 1); bg.inputs['Strength'].default_value = 0.9
    sc.render.resolution_x = sc.render.resolution_y = 320
    sc.render.film_transparent = True
    sc.cycles.samples = 48; sc.cycles.use_denoising = True
    sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    sc.cycles.samples = 4; sc.cycles.use_denoising = False
    for o in hidden: o.hide_render = False
    bpy.data.objects.remove(cam); bpy.data.objects.remove(sun)


def match(o, piece):
    n = o.name.lower()
    inc = piece.get('match'); exc = piece.get('exclude', [])
    if any(e.lower() in n for e in exc): return False
    return inc is None or any(i.lower() in n for i in inc)


def clusters(o, min_size, gap):
    """Kopuk adaları ayırıp kutuları kesişenleri birleştirir; her küme bir parça."""
    select_only([o]); bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.separate(type='LOOSE')
    bpy.ops.object.mode_set(mode='OBJECT')
    parts = [x for x in bpy.context.selected_objects]
    boxes = [world_bbox(p) for p in parts]
    parent = list(range(len(parts)))

    def f(i):
        while parent[i] != i: parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for i in range(len(parts)):
        for j in range(i + 1, len(parts)):
            a, b = boxes[i], boxes[j]
            if all(a[0][k] - gap <= b[1][k] and b[0][k] - gap <= a[1][k] for k in range(3)):
                # küçük ada büyüğün içindeyse ya da gerçekten bitişikse birleşir
                parent[f(i)] = f(j)
    groups = {}
    for i, p in enumerate(parts): groups.setdefault(f(i), []).append(p)
    res = []
    for g in groups.values():
        mn = Vector(map(min, *[world_bbox(p)[0] for p in g])); mx = Vector(map(max, *[world_bbox(p)[1] for p in g]))
        if (mx - mn).length < min_size:
            for p in g: bpy.data.objects.remove(p)
            continue
        res.append(g)
    res.sort(key=lambda g: -sum(tri_count(p) for p in g))
    return res


def process_piece(pid, objs, piece, stats_extra):
    if piece.get('local'):
        # iskeletli modellerde ebeveyn dönüşümü bozuk; ağı kendi yerel uzayında al
        for o in objs:
            o.parent = None; o.matrix_world = Matrix.Identity(4); o.modifiers.clear()
    high = join(objs)
    high.name = pid + '_high'
    # birimleri metreye
    if piece.get('rot'):
        r = [math.radians(a) for a in piece['rot']]
        from mathutils import Euler
        high.data.transform(Euler(r, 'XYZ').to_matrix().to_4x4())
    if piece.get('scale'):
        high.data.transform(Matrix.Scale(piece['scale'], 4))
    mn, mx = world_bbox(high)
    if piece.get('size'):
        s = piece['size'] / max(mx - mn)
        high.data.transform(Matrix.Scale(s, 4))
        mn, mx = world_bbox(high)
    # pivot: taban ortası
    off = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    high.data.transform(Matrix.Translation(-off))
    mn, mx = world_bbox(high)
    L = max(mx - mn)
    high.data.update()
    src_tris = tri_count(high)

    render_thumb([high], os.path.join(THUMBS, pid + '_once.png'))

    low = high.copy(); low.data = high.data.copy(); low.name = pid
    bpy.context.scene.collection.objects.link(low)
    if low.data.shape_keys:
        low.shape_key_clear()
    low.data.materials.clear()
    for uv in list(low.data.uv_layers): low.data.uv_layers.remove(uv)
    low.modifiers.clear()
    select_only([low]); bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0004 * L)
    bpy.ops.object.mode_set(mode='OBJECT')
    low.data.validate()
    tt = target_tris(L, piece.get('tris'))
    for _ in range(4):
        if tri_count(low) <= tt * 1.03: break
        d = low.modifiers.new('dec', 'DECIMATE'); d.ratio = tt / tri_count(low); d.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier='dec')
    if tri_count(low) > tt * 1.03:
        # kopuk adası çok olan modellerde collapse yetmiyor; düzlemsel indirme ile tamamla
        d = low.modifiers.new('dec', 'DECIMATE'); d.decimate_type = 'DISSOLVE'; d.angle_limit = math.radians(8); d.use_dissolve_boundaries = False
        bpy.ops.object.modifier_apply(modifier='dec')
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.quads_convert_to_tris(); bpy.ops.object.mode_set(mode='OBJECT')
        if tri_count(low) > tt * 1.03:
            d = low.modifiers.new('dec', 'DECIMATE'); d.ratio = tt / tri_count(low); d.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier='dec')
    # düz gölgeleme yerine açıyla yumuşat
    for p in low.data.polygons: p.use_smooth = True
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
    except Exception:
        pass

    align_normals(low, high)
    # Kenar/girinti maskesi için kir köşe renkleri (AO yerine; ince ve çift kat saçlarda AO tutmuyor)
    ca = low.data.color_attributes.new('dirt', 'FLOAT_COLOR', 'POINT')
    low.data.color_attributes.active_color = ca
    select_only([low])
    try:
        bpy.ops.paint.vertex_color_dirt(blur_strength=1.0, blur_iterations=2, clean_angle=math.pi, dirt_angle=0.0, dirt_only=False, normalize=True)
    except Exception as e:
        log('DIRTFAIL', e)
    # düz yüzey 0.5 olsun: ortancaya göre ölçekle
    import numpy as np
    ca = low.data.color_attributes['dirt']
    a = np.empty(len(ca.data) * 4, dtype=np.float32); ca.data.foreach_get('color', a); a = a.reshape(-1, 4)
    v = a[:, 0]; med = float(np.median(v)); dev = float(np.percentile(np.abs(v - med), 95)) or 1.0
    v = np.clip(0.5 + (v - med) / dev * 0.5, 0, 1)
    a[:, 0] = a[:, 1] = a[:, 2] = v; ca.data.foreach_set('color', a.ravel())
    low.data.uv_layers.new(name='UVMap')
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    try:
        bpy.ops.uv.pack_islands(margin=0.005, rotate=True)
    except Exception:
        pass
    bpy.ops.object.mode_set(mode='OBJECT')
    bmat = bpy.data.materials.new('bake_tmp'); bmat.use_nodes = True; low.data.materials.append(bmat)

    imgs = {}
    route(high, None)
    imgs['nrm'] = new_image(pid + '_n', False); do_bake('NORMAL', low, high, L, imgs['nrm'])
    fix_normal(imgs['nrm'])
    imgs['nrm'] = persist(imgs['nrm'], True)
    for ch, nc in (('base', False), ('rough', True), ('metal', True)):
        route(high, ch)
        imgs[ch] = new_image(pid + '_s1' + ch, not nc); do_bake('EMIT', low, high, L, imgs[ch])
        imgs[ch] = persist(imgs[ch], nc)
    route(high, None)

    # 2. aşama: pas ve kir, yüksek model gizli
    high.hide_render = True
    amt = piece.get('rust', 0.5); grime = piece.get('grime', 0.35)
    if piece.get('base_override') is not None:
        b = imgs['base']; b.pixels[:] = list(piece['base_override']) * (b.size[0] * b.size[1])
    if piece.get('metal_override') is not None:
        px = [piece['metal_override']] * 3 + [1.0]
        imgs['metal'].pixels[:] = px * (imgs['metal'].size[0] * imgs['metal'].size[1])
    rmat, em, outs = rust_material(low, imgs['base'], imgs['rough'], imgs['metal'], imgs['nrm'], amt, L, grime, piece.get('paint', 0.65))
    fin = {}
    chans = [('base', False), ('rough', True), ('metal', True)] + [(k, True) for k in outs if k.startswith('d_')]
    for ch, nc in chans:
        for l in list(em.inputs['Color'].links): rmat.node_tree.links.remove(l)
        rmat.node_tree.links.new(outs[ch], em.inputs['Color'])
        fin[ch] = new_image(pid + {'base': '_c', 'rough': '_r', 'metal': '_m'}.get(ch, '_' + ch), not nc)
        do_bake('EMIT', low, None, L, fin[ch])
        fin[ch] = persist(fin[ch], nc)
    fmat = final_material('hurda_' + pid, fin['base'], fin['rough'], fin['metal'], imgs['nrm'])
    low.data.materials.clear(); low.data.materials.append(fmat)

    hull, vol = convex_hull(low, pid + '-convcolonly')
    render_thumb([low], os.path.join(THUMBS, pid + '_sonra.png'))

    select_only([low, hull], low)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, pid + '.glb'), export_format='GLB', use_selection=True,
                              export_image_format='JPEG', export_jpeg_quality=88, export_apply=True, export_yup=True,
                              export_animations=False, export_materials='EXPORT', export_tangents=False)
    mn, mx = world_bbox(low)
    st = dict(id=pid, ucgen=tri_count(low), kaynak_ucgen=src_tris, boyut_m=[round(mx.x - mn.x, 3), round(mx.z - mn.z, 3), round(mx.y - mn.y, 3)],
              hull_hacim_m3=vol, hull_nokta=len(hull.data.vertices))
    st.update(stats_extra); st['kaynak'] = job.get('kaynak')
    json.dump(st, open(os.path.join(STATS, pid + '.json'), 'w'), ensure_ascii=False)
    log('OK', pid, st['ucgen'], st['boyut_m'])


reset()
if job.get('cluster'):
    cl = job['cluster']
    load_source()
    objs = [o for o in mesh_objects() if match(o, cl)]
    whole = join(objs)
    if cl.get('size_whole'):
        mn, mx = world_bbox(whole); whole.data.transform(Matrix.Scale(cl['size_whole'] / max(mx - mn), 4))
    if cl.get('scale'):
        whole.data.transform(Matrix.Scale(cl['scale'], 4))
    groups = clusters(whole, cl.get('min', 0.0), cl.get('gap', 0.0))
    names = [[p.name for p in g] for g in groups]
    log('CLUSTERS', len(names))
    keep = cl.get('keep')
    for i, g in enumerate(names):
        if keep and i not in keep: continue
        pid = f"{cl['prefix']}_{i + 1:02d}"
        reset(); load_source()
        objs = [o for o in mesh_objects() if match(o, cl)]
        whole = join(objs)
        if cl.get('size_whole'):
            mn, mx = world_bbox(whole); whole.data.transform(Matrix.Scale(cl['size_whole'] / max(mx - mn), 4))
        if cl.get('scale'):
            whole.data.transform(Matrix.Scale(cl['scale'], 4))
        gs = clusters(whole, cl.get('min', 0.0), cl.get('gap', 0.0))
        piece = dict(cl); piece.pop('size', None); piece.pop('scale', None)
        if cl.get('piece_size'): piece['size'] = cl['piece_size']
        try:
            process_piece(pid, gs[i], piece, {'set': cl['prefix']})
        except Exception as e:
            import traceback; traceback.print_exc(); log('FAIL', pid, e)
elif job.get('per_object'):
    po = job['per_object']
    load_source()
    import re
    names = [o.name for o in mesh_objects() if match(o, po) and not (po.get('dedupe') and re.search(r'\.\d{3}', o.name))]
    log('OBJECTS', len(names))
    for i, nm in enumerate(names):
        pid = f"{po['prefix']}_{i + 1:02d}"
        reset(); load_source()
        objs = [o for o in mesh_objects() if o.name == nm]
        piece = dict(po)
        if po.get('piece_size'): piece['size'] = po['piece_size']
        try:
            process_piece(pid, objs, piece, {'set': po['prefix'], 'kaynak_nesne': nm})
        except Exception as e:
            import traceback; traceback.print_exc(); log('FAIL', pid, e)
else:
    for piece in job['pieces']:
        reset(); load_source()
        objs = [o for o in mesh_objects() if match(o, piece)]
        if not objs:
            log('FAIL', piece['id'], 'eşleşen nesne yok'); continue
        try:
            process_piece(piece['id'], objs, piece, {'set': piece.get('set')})
        except Exception as e:
            import traceback; traceback.print_exc(); log('FAIL', piece['id'], e)
