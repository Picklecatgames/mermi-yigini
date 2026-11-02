# Blender -b --factory-startup --python preview.py -- <assets/props/cukur> <çıkış klasörü>
# Her grup için bir ortografik çekim (cit.png, merdiven.png, zemin.png); birleştirmeyi çağıran yapar.
import bpy, sys, os, math
from mathutils import Vector

SRC, OUT = sys.argv[sys.argv.index('--') + 1:][:2]
ROWS = {
    'cit': ['korkuluk_2m', 'korkuluk_1m', 'korkuluk_direk', 'korkuluk_kapi_1m', 'tel_cit_1m', 'tel_cit_2m',
            'tel_cit_direk', 'tel_cit_bitis', 'tel_cit_kapi', 'yangin_korkuluk_4_7m', 'yangin_korkuluk_2_2m'],
    'merdiven': ['kafesli_merdiven_3m', 'kafesli_merdiven_cikis', 'dam_merdiveni_3m', 'merdiven_rampa_1_8m',
                 'merdiven_rampa_3_6m', 'yangin_merdiveni', 'yangin_dik_merdiven_6_5m'],
    'zemin': ['zemin_izgara_2x1', 'zemin_izgara_1x1', 'zemin_baklava_2x1', 'zemin_pasli_sac_2x1', 'kiris_I_2m',
              'kiris_I_4m', 'kolon_2m', 'yangin_platform_a', 'yangin_platform_b'],
}

for row, names in ROWS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 48; sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 2400, 900
    sc.view_settings.view_transform = 'AgX'
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.55, 0.58, 0.62, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.8
    x = 0.0; lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for n in names:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, n + '.gltf'))
        objs = [o for o in bpy.data.objects if o not in before]
        for o in objs:
            if '-convcolonly' in o.name or o.name.endswith('-convcolonly'):
                bpy.data.objects.remove(o)
        objs = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        mn = Vector([min(p[i] for p in pts) for i in range(3)]); mx = Vector([max(p[i] for p in pts) for i in range(3)])
        dx = x - mn.x
        for o in objs:
            if o.parent is None: o.location.x += dx
        t = bpy.data.curves.new(n, 'FONT'); t.body = n.replace('_', ' '); t.size = 0.22; t.align_x = 'CENTER'
        to = bpy.data.objects.new(n + '_t', t); sc.collection.objects.link(to)
        to.location = (x + (mx.x - mn.x) / 2, mn.y - 0.4, 0.002)
        tm = bpy.data.materials.new('t'); tm.use_nodes = True
        next(k for k in tm.node_tree.nodes if k.type == 'BSDF_PRINCIPLED').inputs['Base Color'].default_value = (0.02, 0.02, 0.02, 1)
        t.materials.append(tm)
        lo = Vector((min(lo.x, x), min(lo.y, mn.y - 0.5), min(lo.z, mn.z)))
        hi = Vector((max(hi.x, x + mx.x - mn.x), max(hi.y, mx.y), max(hi.z, mx.z)))
        x += max(mx.x - mn.x, 1.3) + 0.4
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, min(lo.z, 0) - 0.001))
    fm = bpy.data.materials.new('f'); fm.use_nodes = True
    next(k for k in fm.node_tree.nodes if k.type == 'BSDF_PRINCIPLED').inputs['Base Color'].default_value = (0.42, 0.42, 0.42, 1)
    bpy.context.active_object.data.materials.append(fm)
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); sc.collection.objects.link(sun)
    sun.data.energy = 3.5; sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    el = math.radians(22); az = math.radians(-12)
    c = (lo + hi) / 2
    d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    cam.location = c + d * 60
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam.data.clip_end = 200
    cam.data.ortho_scale = max((hi.x - lo.x) * 1.04, (hi.z - lo.z + 1.5) * 2400 / 900)
    sc.render.filepath = os.path.join(OUT, row + '.png')
    bpy.ops.render.render(write_still=True)
    print('@@', row, flush=True)
