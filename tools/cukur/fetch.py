# python -I fetch.py <indirme klasörü> ph:<id> pht:<id> acg:<id> sf:<uid> ...
# Sketchfab token'ı yalnız SKETCHFAB_API_TOKEN ortam değişkeninden okunur
import json,os,sys,urllib.request,zipfile,io,re,subprocess
sys.stdout.reconfigure(encoding="utf8",errors="replace")
S=sys.argv[1]; DL=os.path.join(S,'dl')
def get(u,h=None):
    return urllib.request.urlopen(urllib.request.Request(u,headers=dict({'User-Agent':'mermi-yigini'},**(h or {}))),timeout=300).read()
tok=os.environ.get('SKETCHFAB_API_TOKEN') or subprocess.run(['powershell','-NoProfile','-c',"[Environment]::GetEnvironmentVariable('SKETCHFAB_API_TOKEN','User')"],capture_output=True,text=True).stdout.strip()
for a in sys.argv[2:]:
    kind,i=a.split(':',1)
    out=os.path.join(DL,kind,i)
    if os.path.isdir(out) and os.listdir(out): continue
    os.makedirs(out,exist_ok=True)
    try:
        if kind=='ph':
            f=json.loads(get('https://api.polyhaven.com/files/'+i))
            res='2k'
            g=f['gltf'][res]['gltf']
            for rel,v in g['include'].items():
                p=os.path.join(out,rel); os.makedirs(os.path.dirname(p),exist_ok=True); open(p,'wb').write(get(v['url']))
            open(os.path.join(out,i+'.gltf'),'wb').write(get(g['url']))
        elif kind=='pht':
            f=json.loads(get('https://api.polyhaven.com/files/'+i))
            for m in ('Diffuse','nor_gl','Rough','arm','Displacement','AO','Metal'):
                if m in f: 
                    v=f[m]['2k'].get('jpg') or f[m]['2k'].get('png')
                    open(os.path.join(out,i+'_'+m+os.path.splitext(v['url'])[1]),'wb').write(get(v['url']))
        elif kind=='acg':
            zipfile.ZipFile(io.BytesIO(get(f'https://ambientcg.com/get?file={i}_2K-JPG.zip'))).extractall(out)
        elif kind=='sf':
            dl=json.loads(get(f'https://api.sketchfab.com/v3/models/{i}/download',{'Authorization':'Token '+tok}))
            k='glb' if 'glb' in dl else 'gltf'
            data=get(dl[k]['url'])
            if k=='glb': open(os.path.join(out,'model.glb'),'wb').write(data)
            else: zipfile.ZipFile(io.BytesIO(data)).extractall(out)
        print('ok',a,flush=True)
    except Exception as e:
        print('HATA',a,e,flush=True); import shutil,time; shutil.rmtree(out,ignore_errors=True); time.sleep(30)
