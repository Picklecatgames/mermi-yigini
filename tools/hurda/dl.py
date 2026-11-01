import json,sys,os,urllib.request,hashlib,zipfile,io
S=sys.argv[1]
D=json.load(open(os.path.join(S,'gallery.json'),encoding='utf8'))
E=[d for d in D if d['z']=='eklenecek']
def get(u):
    r=urllib.request.Request(u,headers={'User-Agent':'mermi-yigini-asset-fetch'})
    return urllib.request.urlopen(r,timeout=120).read()
for d in E:
    if d['s']=='Poly Haven':
        i=d['u'].rstrip('/').split('/')[-1]
        out=os.path.join(S,'dl','polyhaven',i)
        if os.path.exists(os.path.join(out,i+'.gltf')): continue
        f=json.loads(get('https://api.polyhaven.com/files/'+i))
        g=f['gltf']['2k']['gltf']
        os.makedirs(out,exist_ok=True)
        for rel,v in g['include'].items():
            p=os.path.join(out,rel); os.makedirs(os.path.dirname(p),exist_ok=True)
            open(p,'wb').write(get(v['url']))
        open(os.path.join(out,i+'.gltf'),'wb').write(get(g['url']))
        print('ph',i,flush=True)
    elif d['s']=='ambientCG':
        i=d['u'].split('id=')[1]
        out=os.path.join(S,'dl','ambientcg',i)
        if os.path.isdir(out): continue
        z=get(f'https://ambientcg.com/get?file={i}_2K-JPG.zip')
        zipfile.ZipFile(io.BytesIO(z)).extractall(out)
        print('acg',i,flush=True)
