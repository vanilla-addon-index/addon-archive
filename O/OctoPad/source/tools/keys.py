import os
ADDON = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'OctoPad')
from PIL import Image, ImageDraw, ImageFont
import os
OUT=os.path.join(ADDON, 'Glyphs')
S=4; N=64*S
FB='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
PAL={'beige':((222,214,192),(150,142,122)),'green':((130,196,116),(72,122,66)),
     'red':((214,108,96),(134,62,56)),'blue':((172,192,208),(104,120,136))}
def rr(d,box,r,fill=None,outline=None,w=1):
    d.rounded_rectangle([v*S for v in box],radius=r*S,fill=fill,outline=outline,width=w*S)
def cap(name,pal,legend=None,arrow=None,size=19):
    top,side=PAL[pal]
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
    dark=tuple(int(v*.55) for v in side)
    rr(d,(2,8,62,62),9,fill=side,outline=dark,w=1)              # lower lip
    rr(d,(4,3,60,53),8,fill=top,outline=dark,w=1)               # cap face
    hi=tuple(min(255,v+28) for v in top)
    d.line([(10*S,5.5*S),(54*S,5.5*S)],fill=hi,width=int(1.5*S))  # top highlight
    inner=tuple(int(v*.92) for v in top)
    rr(d,(10,10,54,47),6,fill=inner,outline=tuple(int(v*.78) for v in top),w=1)   # dished recess
    cx,cy=32*S,28*S; ink=(48,44,38,255)
    if arrow:
        r=11*S
        pts={'up':[(cx,cy-r),(cx+r,cy+r*.7),(cx-r,cy+r*.7)],'down':[(cx,cy+r),(cx+r,cy-r*.7),(cx-r,cy-r*.7)],
             'left':[(cx-r,cy),(cx+r*.7,cy-r),(cx+r*.7,cy+r)],'right':[(cx+r,cy),(cx-r*.7,cy-r),(cx-r*.7,cy+r)]}[arrow]
        d.polygon(pts,fill=ink)
    else:
        sz=size
        while True:
            f=ImageFont.truetype(FB,int(sz*S)); b=d.textbbox((0,0),legend,font=f)
            if (b[2]-b[0])<=38*S or sz<8: break
            sz-=1
        d.text((cx-(b[0]+b[2])/2,cy-(b[1]+b[3])/2),legend,font=f,fill=ink)
    im.resize((64,64),Image.LANCZOS).save(os.path.join(OUT,name+'.tga'))
cap('key_confirm','green','ENTER')
cap('key_back','red','ESC')
cap('key_alt','beige','R-CLK')
cap('key_shift','beige','SHIFT')
cap('key_up','blue',arrow='up'); cap('key_down','blue',arrow='down')
cap('key_left','blue',arrow='left'); cap('key_right','blue',arrow='right')
cap('key_tabnext','beige','TAB ►'); cap('key_tabprev','beige','◄ TAB')
cap('key_scrollup','beige','PG ▲'); cap('key_scrolldown','beige','PG ▼')
cap('key_destroy','red','DEL')
sheet=Image.new('RGBA',(64*7,128),(60,60,60,255))
fs=sorted(f for f in os.listdir(OUT) if f.startswith('key_'))
for i,f in enumerate(fs): sheet.alpha_composite(Image.open(os.path.join(OUT,f)).convert('RGBA'),((i%7)*64,(i//7)*64))
sheet.save('/tmp/claude-0/-home-claude/ffa77758-080f-5f8f-b896-259ac9121755/scratchpad/keys.png')
print(len(fs))
