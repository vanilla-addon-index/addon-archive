import os
ADDON = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'OctoPad')
from PIL import Image, ImageDraw, ImageFont
import os
OUT=os.path.join(ADDON, 'Glyphs')
S=4; N=64*S
FB='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(sz): return ImageFont.truetype(FB, int(sz*S))
def new(): return Image.new('RGBA',(N,N),(0,0,0,0))
def finish(im,name):
    im=im.resize((64,64),Image.LANCZOS)
    im.save(os.path.join(OUT,name+'.tga'))
def c(rgb): return tuple(int(v*255) for v in rgb)
def center_text(d,txt,sz,col,cx=N/2,cy=N/2):
    f=font(sz); b=d.textbbox((0,0),txt,font=f)
    d.text((cx-(b[0]+b[2])/2, cy-(b[1]+b[3])/2), txt, font=f, fill=col)
def disc(ring):
    im=new(); d=ImageDraw.Draw(im)
    m=3*S
    d.ellipse((m,m,N-m,N-m),fill=(28,30,36,255),outline=ring,width=4*S)
    return im,d
def symbol(d,kind,col):
    cx=cy=N/2; r=17*S; w=int(5*S)
    if kind=='cross':
        d.line((cx-r*.8,cy-r*.8,cx+r*.8,cy+r*.8),fill=col,width=w)
        d.line((cx-r*.8,cy+r*.8,cx+r*.8,cy-r*.8),fill=col,width=w)
    elif kind=='circle':
        d.ellipse((cx-r,cy-r,cx+r,cy+r),outline=col,width=w)
    elif kind=='square':
        d.rectangle((cx-r*.85,cy-r*.85,cx+r*.85,cy+r*.85),outline=col,width=w)
    elif kind=='tri':
        pts=[(cx,cy-r*1.05),(cx+r*1.0,cy+r*.8),(cx-r*1.0,cy+r*.8)]
        d.polygon(pts,outline=col,fill=None); d.line(pts+[pts[0]],fill=col,width=w,joint='curve')
def pill(text,col,ring):
    im=new(); d=ImageDraw.Draw(im)
    d.rounded_rectangle((2*S,12*S,N-2*S,N-12*S),radius=10*S,fill=(28,30,36,255),outline=ring,width=3*S)
    center_text(d,text,22,col)
    return im
XB=[(.25,.8,.25),(.25,.5,1),(1,.8,.1),(.9,.25,.25)]
PSC=[(.4,.6,1),(.95,.55,.85),(.25,.8,.6),(.9,.25,.25)]
PSK=['cross','square','tri','circle']
GREY=(.85,.85,.85)
STY={
 'xbox':dict(face=['A','X','Y','B'],bump=['RB','LB'],trig=['LT','RT']),
 'ps':dict(face=None,bump=['R1','L1'],trig=['L2','R2']),
 'switch':dict(face=['B','Y','X','A'],bump=['RB','LB'],trig=['LT','RT']),
 'switchn':dict(face=['A','X','Y','B'],bump=['RB','LB'],trig=['LT','RT']),
}
for sty,v in STY.items():
    for i in range(4):
        if sty=='xbox': col=c(XB[i]); im,d=disc(col); center_text(d,v['face'][i],30,col)
        elif sty=='ps': col=c(PSC[i]); im,d=disc((90,92,100,255)); symbol(d,PSK[i],col)
        else: im,d=disc((110,112,120,255)); center_text(d,v['face'][i],30,c(GREY))
        finish(im,'%s_%d'%(sty,i+1))
    ring=(110,112,120,255)
    finish(pill(v['bump'][0],c(GREY),ring),sty+'_9')
    finish(pill(v['bump'][1],c(GREY),ring),sty+'_10')
    finish(pill(v['trig'][0],c(GREY),ring),sty+'_t1')
    finish(pill(v['trig'][1],c(GREY),ring),sty+'_t2')
# d-pad: 5 down, 6 left, 7 up, 8 right
dirs={5:(0,1),6:(-1,0),7:(0,-1),8:(1,0)}
for k,(dx,dy) in dirs.items():
    im=new(); d=ImageDraw.Draw(im)
    d.ellipse((3*S,3*S,N-3*S,N-3*S),fill=(28,30,36,255),outline=(110,112,120,255),width=4*S)
    a=13*S; t=7*S
    # cross arms (grey)
    d.rectangle((N/2-t,N/2-a*1.9,N/2+t,N/2+a*1.9),fill=(90,92,100,255))
    d.rectangle((N/2-a*1.9,N/2-t,N/2+a*1.9,N/2+t),fill=(90,92,100,255))
    # highlighted arm
    ex,ey=N/2+dx*a*1.9,N/2+dy*a*1.9
    if dx==0: d.rectangle((N/2-t,min(N/2,ey),N/2+t,max(N/2,ey)),fill=(240,240,240,255))
    else: d.rectangle((min(N/2,ex),N/2-t,max(N/2,ex),N/2+t),fill=(240,240,240,255))
    finish(im,'dpad_%d'%k)
print(len(os.listdir(OUT)),'files')
