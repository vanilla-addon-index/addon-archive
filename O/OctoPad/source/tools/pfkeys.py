import os
ADDON = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'OctoPad')
from PIL import Image, ImageDraw, ImageFont
import os
OUT=os.path.join(ADDON, 'Glyphs')
S=4; N=64*S
FB='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def rr(d,box,r,fill=None,outline=None,w=1):
    d.rounded_rectangle([v*S for v in box],radius=r*S,fill=fill,outline=outline,width=w*S)
def save(im,name): im.resize((64,64),Image.LANCZOS).save(os.path.join(OUT,name+'.tga'))
# neutral cap, meant to be tinted with the pfUI colours (flat, rounded, thin border like pfUI buttons)
im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
rr(d,(3,3,61,61),11,fill=(150,150,150,255),outline=(255,255,255,255),w=2)       # border (tinted too)
rr(d,(6,6,58,58),9,fill=(255,255,255,255))                                       # face
d.line([(12*S,8.5*S),(52*S,8.5*S)],fill=(255,255,255,255),width=int(1.5*S))
save(im,'pfcap')
def legend(name,text=None,arrow=None,size=19):
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
    cx,cy=32*S,32*S; ink=(255,255,255,255)
    if arrow:
        r=12*S
        pts={'up':[(cx,cy-r),(cx+r,cy+r*.7),(cx-r,cy+r*.7)],'down':[(cx,cy+r),(cx+r,cy-r*.7),(cx-r,cy-r*.7)],
             'left':[(cx-r,cy),(cx+r*.7,cy-r),(cx+r*.7,cy+r)],'right':[(cx+r,cy),(cx-r*.7,cy-r),(cx-r*.7,cy+r)]}[arrow]
        d.polygon(pts,fill=ink)
    else:
        sz=size
        while True:
            f=ImageFont.truetype(FB,int(sz*S)); b=d.textbbox((0,0),text,font=f)
            if (b[2]-b[0])<=44*S or sz<8: break
            sz-=1
        d.text((cx-(b[0]+b[2])/2,cy-(b[1]+b[3])/2),text,font=f,fill=ink)
    save(im,'pkl_'+name)
for n,t in [('confirm','ENTER'),('back','ESC'),('alt','R-CLK'),('shift','SHIFT'),('tabnext','TAB ►'),('tabprev','◄ TAB'),
            ('scrollup','PG ▲'),('scrolldown','PG ▼'),('destroy','DEL')]:
    legend(n,text=t)
for a in ['up','down','left','right']: legend(a,arrow=a)
print(len([f for f in os.listdir(OUT) if f.startswith(('pkl_','pfcap'))]))
