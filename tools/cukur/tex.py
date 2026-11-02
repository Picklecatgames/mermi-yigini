# python tex.py <indirme klasörü>: 1K doku seti c (renk, RGBA olabilir), n (normal GL), orm (G pürüz, B metal)
import sys,os,numpy as np
from PIL import Image
S=sys.argv[1]; O=os.path.join(S,'tex'); os.makedirs(O,exist_ok=True)
A=S+'/dl/acg/'; P=S+'/dl/pht/'
R=1024
def ld(p,mode='RGB'): return Image.open(p).convert(mode).resize((R,R),Image.LANCZOS)
def save(name,c,n,r,m):
    c.save(f'{O}/{name}_c.png' if c.mode=='RGBA' else f'{O}/{name}_c.jpg',quality=90)
    n.save(f'{O}/{name}_n.jpg',quality=92)
    Image.merge('RGB',(Image.new('L',(R,R),255),r,m)).save(f'{O}/{name}_orm.jpg',quality=90)
def paint(target_h,sat,val):
    pm=A+'PaintedMetal006/PaintedMetal006_2K-JPG_'
    hsv=np.array(ld(pm+'Color.jpg').convert('HSV')).astype(np.float32)
    h=hsv[...,0]*360/255
    g=np.clip(1-np.abs(h-160)/70,0,1)*np.clip((hsv[...,1]-40)/60,0,1)   # yeşil boya maskesi
    hsv[...,0]=np.where(g>0,target_h*255/360,hsv[...,0])
    hsv[...,1]=hsv[...,1]*(1-g)+np.clip(hsv[...,1]*sat,0,255)*g
    hsv[...,2]=hsv[...,2]*(1-g)+np.clip(hsv[...,2]*val,0,255)*g
    c=Image.fromarray(hsv.astype(np.uint8),'HSV').convert('RGB')
    return c,ld(pm+'NormalGL.jpg'),ld(pm+'Roughness.jpg','L'),ld(pm+'Metalness.jpg','L')
save('sari',*paint(46,1.25,1.35))
save('gri',*paint(210,0.12,0.95))
w=A+'MetalWalkway010/MetalWalkway010_2K-JPG_'
c=ld(w+'Color.jpg'); c.putalpha(ld(w+'Opacity.jpg','L'))
save('izgara',c,ld(w+'NormalGL.jpg'),ld(w+'Roughness.jpg','L'),ld(w+'Metalness.jpg','L'))
for nm,src in (('baklava','metal_plate'),('pasli_sac','metal_grate_rusty'),('astar','rusty_painted_metal')):
    p=P+src+'/'+src+'_'
    m=ld(p+'Metal.jpg','L') if os.path.exists(p+'Metal.jpg') else Image.new('L',(R,R),200)
    save(nm,ld(p+'Diffuse.jpg'),ld(p+'nor_gl.jpg'),ld(p+'Rough.jpg','L'),m)
print(sorted(os.listdir(O)))
