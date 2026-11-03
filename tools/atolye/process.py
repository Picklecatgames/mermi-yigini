# Blender -b --factory-startup --python process.py -- job.json
# İndirilen modeli metre ölçeğine getirir, parçalara böler, ağırsa düşürür, orijini tabanın
# ortasına koyar, "-convcolonly" ekli dışbükey çarpışma ekler ve parça başına glb yazar.
# job: {src, out, stats, set, scale | height | size, max_tex, alpha, rot_x, pieces: [{id, match, exclude, tris, hull}]}
import bpy, bmesh, sys, json, os, math
from mathutils import Vector, Matrix

job = json.load(open(sys.argv[sys.argv.index('--') + 1], encoding='utf8'))
OUT = job['out']; STATS = job['stats']
os.makedirs(OUT, exist_ok=True); os.makedirs(STATS, exist_ok=True)


def log(*a):
    print('@@', *a, flush=True)


def select_only(objs, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def world_bbox(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def load_source():
    src = job['src']; ext = os.path.splitext(src)[1].lower()
    if ext in ('.gltf', '.glb'):
        bpy.ops.import_scene.gltf(filepath=src)
    elif ext == '.fbx':
        bpy.ops.import_scene.fbx(filepath=src)
    elif ext == '.obj':
        bpy.ops.wm.obj_import(filepath=src)


def bake_transforms():
    # gltf hiyerarşisini düzleştir: her mesh kendi dünya dönüşümüyle tek başına kalsın
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    select_only(meshes)
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o.type != 'MESH': bpy.data.objects.remove(o)
    return meshes


def match(o, p):
    if p.get('names'): return o.name in p['names']
    n =(o.name + '|' + (o.data.name if o.data else '') + '|' + ','.join(m.name for m in o.data.materials if m)).lower()
    # above/below: duvardaki panoyu tezgâhtan ayırmak için nesnenin taban yüksekliği (m)
    z = min((o.matrix_world @ v.co).z for v in o.data.vertices) if ('above' in p or 'below' in p) else 0
    if 'below' in p and z >= p['below']: return False
    if 'above' in p and z >= p['above']: return not (p.get('exclude') and any(s.lower() in n for s in p['exclude']))
    if p.get('match') and not any(s.lower() in n for s in p['match']): return False
    if p.get('exclude') and any(s.lower() in n for s in p['exclude']): return False
    return True


def convex_hull(low, name, limit=48):
    bm = bmesh.new(); bm.from_mesh(low.data)
    r = bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.delete(bm, geom=list({v for v in r['geom_interior'] + r['geom_unused'] if isinstance(v, bmesh.types.BMVert)}), context='VERTS')
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    if len(me.vertices) > limit:
        d = o.modifiers.new('d', 'DECIMATE'); d.ratio = limit / len(me.vertices) * 1.6
        select_only([o]); bpy.ops.object.modifier_apply(modifier='d')
        bm = bmesh.new(); bm.from_mesh(o.data)
        r = bmesh.ops.convex_hull(bm, input=bm.verts)
        bmesh.ops.delete(bm, geom=list({v for v in r['geom_interior'] + r['geom_unused'] if isinstance(v, bmesh.types.BMVert)}), context='VERTS')
        bm.to_mesh(o.data); bm.free()
    return o


def box_hull(low, name):
    mn, mx = world_bbox([low])
    me = bpy.data.meshes.new(name)
    c = [Vector((x, y, z)) for x in (mn.x, mx.x) for y in (mn.y, mx.y) for z in (mn.z, mx.z)]
    me.from_pydata(c, [], [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


def shrink_images(limit):
    for img in bpy.data.images:
        if img.size[0] > limit or img.size[1] > limit:
            k = limit / max(img.size)
            img.scale(max(1, int(img.size[0] * k)), max(1, int(img.size[1] * k)))


bpy.ops.wm.read_factory_settings(use_empty=True)
load_source()
allm = bake_transforms()
src_tris = sum(tri_count(o) for o in allm)

# ölçek bütün sete birden uygulanır, parçalar birbirine göre doğru kalır
if job.get('rot_x'):
    for o in allm: o.data.transform(Matrix.Rotation(math.radians(job['rot_x']), 4, 'X'))
mn, mx = world_bbox(allm)
k = job.get('scale', 1.0)
if job.get('height'): k = job['height'] / (mx.z - mn.z)
if job.get('size'): k = job['size'] / max(mx - mn)
if k != 1.0:
    for o in allm: o.data.transform(Matrix.Scale(k, 4))
shrink_images(job.get('max_tex', 1024))

pieces = job.get('pieces') or [{'id': job['id']}]
for p in pieces:
    objs = [o for o in allm if match(o, p)]
    if not objs:
        log('BOS', p['id']); continue
    dup = []
    for o in objs:
        c = o.copy(); c.data = o.data.copy(); bpy.context.scene.collection.objects.link(c); dup.append(c)
    select_only(dup)
    if len(dup) > 1: bpy.ops.object.join()
    low = bpy.context.view_layer.objects.active
    low.name = p['id']
    tt = p.get('tris', job.get('tris', 8000))
    if tri_count(low) > tt:
        d = low.modifiers.new('dec', 'DECIMATE'); d.ratio = tt / tri_count(low); d.use_collapse_triangulate = True
        select_only([low]); bpy.ops.object.modifier_apply(modifier='dec')
    # orijin tabanın ortasında
    mn, mx = world_bbox([low])
    low.data.transform(Matrix.Translation(-Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))))
    low.matrix_world = Matrix.Identity(4)
    hull_kind = p.get('hull', job.get('hull', 'convex'))
    hull = None
    if hull_kind == 'convex': hull = convex_hull(low, p['id'] + '-convcolonly')
    elif hull_kind == 'box': hull = box_hull(low, p['id'] + '-convcolonly')
    sel = [low] + ([hull] if hull else [])
    select_only(sel, low)
    # aynı setin parçaları dokuları ortak klasörden okur
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, p['id'] + '.gltf'), export_format='GLTF_SEPARATE', use_selection=True,
                              export_texture_dir='doku_' + job['set'],
                              export_image_format='AUTO' if job.get('alpha') else 'JPEG', export_jpeg_quality=88,
                              export_apply=True, export_yup=True, export_animations=False, export_materials='EXPORT')
    mn, mx = world_bbox([low])
    st = dict(id=p['id'], ucgen=tri_count(low), kaynak_ucgen=src_tris, carpisma=hull_kind,
              boyut_m=[round(mx.x - mn.x, 3), round(mx.z - mn.z, 3), round(mx.y - mn.y, 3)], kaynak=job.get('kaynak'))
    json.dump(st, open(os.path.join(STATS, p['id'] + '.json'), 'w', encoding='utf8'), ensure_ascii=False)
    log('OK', p['id'], st['ucgen'], st['boyut_m'])
    for o in sel: bpy.data.objects.remove(o)
