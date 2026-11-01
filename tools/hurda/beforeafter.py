import sys,os,json
from PIL import Image,ImageDraw,ImageFont
S=sys.argv[1]; out=sys.argv[2]; ids=sys.argv[3].split(',')
W=210; cols=4; rows=(len(ids)+cols-1)//cols; pad=10; lab=26
cw=cols*(2*W+pad)+pad; ch=rows*(W+lab)+pad+40
c=Image.new('RGBA',(cw,ch),(58,58,62,255)); d=ImageDraw.Draw(c)
try: f=ImageFont.truetype('arial.ttf',15); fb=ImageFont.truetype('arialbd.ttf',20)
except Exception: f=fb=None
d.text((pad,10),'Hurda: önce (indirilen) → sonra (paslı, düşürülmüş, oyuna hazır)',fill=(235,235,235,255),font=fb)
for i,pid in enumerate(ids):
    x=pad+(i%cols)*(2*W+pad); y=40+(i//cols)*(W+lab)
    d.rectangle([x,y,x+2*W-1,y+W-1],fill=(72,72,77,255))
    for j,k in enumerate(('once','sonra')):
        c.alpha_composite(Image.open(os.path.join(S,'thumbs',f'{pid}_{k}.png')).resize((W,W)),(x+j*W,y))
    st=json.load(open(os.path.join(S,'out','_stats',pid+'.json')))
    d.text((x+4,y+W+4),f"{pid}   {st['kaynak_ucgen']}→{st['ucgen']} üçgen",fill=(220,220,220,255),font=f)
c.convert('RGB').save(out,quality=88)
