# glb dokularını parça boyuna göre küçültür (yerinde)
import bpy,sys,json,os
argv=sys.argv[sys.argv.index('--')+1:]
D=argv[0]
rows=json.load(open(os.path.join(D,'hurda.json'),encoding='utf8'))
for r in rows:
    L=max(r['boyut_m']); res=256 if L<0.12 else 512 if L<0.35 else 1024
    if res>=1024: continue
    p=os.path.join(D,r['id']+'.glb')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=p)
    for img in bpy.data.images:
        if img.size[0]>res: img.scale(res,res)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=p,export_format='GLB',use_selection=True,export_image_format='JPEG',export_jpeg_quality=88,export_yup=True,export_animations=False,export_materials='EXPORT',export_tangents=False)
    print('@@',r['id'],res,flush=True)
