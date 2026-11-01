# Sketchfab indirici: token yalnız SKETCHFAB_API_TOKEN ortam değişkeninden okunur, hiçbir yere yazılmaz
import json,os,sys,urllib.request,zipfile,io,re,subprocess,time
S=sys.argv[1]
tok=os.environ.get('SKETCHFAB_API_TOKEN') or subprocess.run(['powershell','-NoProfile','-c',"[Environment]::GetEnvironmentVariable('SKETCHFAB_API_TOKEN','User')"],capture_output=True,text=True).stdout.strip()
assert tok, 'token yok'
D=json.load(open(os.path.join(S,'gallery.json'),encoding='utf8'))
E=[d for d in D if d['z']=='eklenecek' and d['s']=='Sketchfab']
def api(u,auth=True):
    h={'User-Agent':'mermi-yigini'}
    if auth: h['Authorization']='Token '+tok
    return urllib.request.urlopen(urllib.request.Request(u,headers=h),timeout=120).read()
meta={}
mp=os.path.join(S,'sf_meta.json')
if os.path.exists(mp): meta=json.load(open(mp,encoding='utf8'))
for d in E:
    uid=re.search(r'([0-9a-f]{32})$',d['u'].rstrip('/')).group(1)
    out=os.path.join(S,'dl','sketchfab',uid)
    if uid in meta and os.path.isdir(out): continue
    try:
        m=json.loads(api(f'https://api.sketchfab.com/v3/models/{uid}',auth=False))
        lic=(m.get('license') or {}).get('label')
        dl=json.loads(api(f'https://api.sketchfab.com/v3/models/{uid}/download'))
        kind='glb' if 'glb' in dl else 'gltf'
        data=api(dl[kind]['url'],auth=False)
        os.makedirs(out,exist_ok=True)
        if kind=='glb': open(os.path.join(out,'model.glb'),'wb').write(data)
        else: zipfile.ZipFile(io.BytesIO(data)).extractall(out)
        meta[uid]={'ad':d['k'],'name':m.get('name'),'yazar':(m.get('user') or {}).get('displayName'),'kullanici':(m.get('user') or {}).get('username'),'lisans':lic,'url':d['u'],'kind':kind,'faces':m.get('faceCount')}
        print('ok',uid,kind,lic,d['k'],flush=True)
    except Exception as e:
        print('FAIL',uid,d['k'],type(e).__name__,str(e)[:120],flush=True)
    json.dump(meta,open(mp,'w',encoding='utf8'),ensure_ascii=False,indent=1)
    time.sleep(0.5)
