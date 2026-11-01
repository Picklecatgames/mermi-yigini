# out/_stats/*.json + galeri → hurda.json
import json,os,sys,glob,re
S=sys.argv[1]; OUT=sys.argv[2]
D=json.load(open(os.path.join(S,'gallery.json'),encoding='utf8'))
E={}
for d in D:
    if d['z']!='eklenecek': continue
    u=d['u'].rstrip('/')
    if 'polyhaven' in u: k=u.split('/')[-1]
    elif 'ambientcg' in u: k=u.split('id=')[1]
    else: k=re.search(r'([0-9a-f]{32})$',u).group(1)
    E[k]=d
SF=json.load(open(os.path.join(S,'sf_meta.json'),encoding='utf8'))
extra=json.load(open(os.path.join(S,'meta_extra.json'),encoding='utf8')) if os.path.exists(os.path.join(S,'meta_extra.json')) else {}
MAT=[('dökme demir','dokme_demir'),('galvaniz','celik'),('yay çeliği','celik'),('dövme çelik','celik'),('çelik','celik'),('demir','demir'),('bakır','bakir'),('pirinç','pirinc'),
     ('teneke','teneke'),('alüminyum','aluminyum'),('kauçuk','kaucuk'),('ahşap','ahsap'),('karton','karton'),('plastik','plastik')]
DENS={'celik':7850,'dokme_demir':7200,'demir':7870,'bakir':8960,'pirinc':8500,'teneke':7850,'aluminyum':2700,'kaucuk':1150,'ahsap':600,'karton':700,'plastik':950}
# dışbükey kabuğun ne kadarı dolu (içi boş kaplar az, döküm/dövme aletler çok)
FILL={'disli':.45,'yay':.08,'boru':.12,'konserve':.03,'jant':.06,'zincir':.15,'civata':.5,'motor':.35,'alet':.3,'kap':.025,'elektronik':.025,'sac':.05,'sandik':.15,'silah':.03}
def main_mat(m):
    # metinde ilk geçen materyal ana materyaldir ("Ahşap, demir çivi" → ahşap)
    m=m.lower(); best=None
    for a,b in MAT:
        i=m.find(a)
        if i>=0 and (best is None or i<best[0]): best=(i,b)
    return best[1] if best else 'celik'
rows=[]
DROP=set(open(os.path.join(S,'drop.txt')).read().split()) if os.path.exists(os.path.join(S,'drop.txt')) else set()
for f in sorted(glob.glob(os.path.join(S,'out','_stats','*.json'))):
    st=json.load(open(f,encoding='utf8')); pid=st['id']
    if pid in DROP: continue
    src=st.get('set') or pid
    key=st.get('kaynak') or (src if src in E else None)
    sfm=SF.get(key)
    if key is None:
        key=next((k for k in E if pid.startswith(k)),None)
    g=E[key]; x=extra.get(pid,{})
    tur=x.get('tur',g['g'])
    mat=x.get('materyal',main_mat(g['m']))
    fill=x.get('dolu',FILL.get(tur,.1))
    nesne=(st.get('kaynak_nesne') or '').lower()
    if 'tire' in pid or 'tyre' in pid or 'tire' in nesne:
        mat,fill,tur='kaucuk',.13,'jant'
    elif 'wood' in nesne:
        mat,tur='ahsap','sac'
    kg=st['hull_hacim_m3']*DENS[mat]*fill
    if 'kutle_kg' in x: kg=x['kutle_kg']
    ad=x.get('ad',g['k'])
    m_=re.search(r'_(\d\d)$',pid)
    if 'ad' not in x and st.get('set') and m_: ad=f"{g['k']} {int(m_.group(1))}"
    rows.append(dict(id=pid,ad=ad,tur=tur,glb=f'res://assets/props/hurda/{pid}.glb',materyal=mat,materyaller=x.get('materyaller',g['m']),
        kutle_kg=round(max(kg,0.02),2),boyut_m=st['boyut_m'],ucgen=st['ucgen'],set=st.get('set'),
        kaynak=g['s'],yazar=(sfm['yazar'] if sfm else g['a']),lisans=('CC-BY 4.0' if sfm and sfm['lisans']=='CC Attribution' else (sfm['lisans'] if sfm else g['l'])),url=re.sub(r'/3d-models/none-','/3d-models/',g['u'])))
json.dump(rows,open(OUT,'w',encoding='utf8'),ensure_ascii=False,indent=1)
print(len(rows))
for r in rows: print(r['id'],r['tur'],r['materyal'],r['kutle_kg'],r['boyut_m'],r['ucgen'])
