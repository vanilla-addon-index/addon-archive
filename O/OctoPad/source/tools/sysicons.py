import os
ADDON = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'OctoPad')
from PIL import Image, ImageDraw, ImageFont
import math, os
GL=os.path.join(ADDON, 'Glyphs')
IC=os.path.join(ADDON, 'Icons')
S=4; N=64*S
FB='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def F(sz): return ImageFont.truetype(FB,int(sz*S))
def px(v): return v*S
WHITE=(236,238,242,255)
THEMES={'xbox':(112,200,90,255),'ps':(86,142,255,255),'switch':(236,74,64,255)}
def base(acc):
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
    d.rounded_rectangle((px(5),px(5),px(59),px(59)),radius=px(11),fill=(24,26,32,255),outline=acc,width=px(3))
    return im,d
def line(d,pts,col,w=4): d.line([(px(x),px(y)) for x,y in pts],fill=col,width=px(w),joint='curve')
def poly(d,pts,col): d.polygon([(px(x),px(y)) for x,y in pts],fill=col)
def circ(d,cx,cy,r,fill=None,outline=None,w=3):
    d.ellipse((px(cx-r),px(cy-r),px(cx+r),px(cy+r)),fill=fill,outline=outline,width=px(w))
def rect(d,a,b,c,e,fill=None,outline=None,w=3,r=0):
    if r: d.rounded_rectangle((px(a),px(b),px(c),px(e)),radius=px(r),fill=fill,outline=outline,width=px(w))
    else: d.rectangle((px(a),px(b),px(c),px(e)),fill=fill,outline=outline,width=px(w))
def text(d,t,cx,cy,sz,col):
    f=F(sz); b=d.textbbox((0,0),t,font=f); d.text((px(cx)-(b[0]+b[2])/2,px(cy)-(b[1]+b[3])/2),t,font=f,fill=col)
def cross(d,cx,cy,r,col,w=3):
    circ(d,cx,cy,r,outline=col,w=w)
    line(d,[(cx-r-5,cy),(cx-r+5,cy)],col,w); line(d,[(cx+r-5,cy),(cx+r+5,cy)],col,w)
    line(d,[(cx,cy-r-5),(cx,cy-r+5)],col,w); line(d,[(cx,cy+r-5),(cx,cy+r+5)],col,w)
def paw(d,cx,cy,col,s=1.0):
    d.ellipse((px(cx-8*s),px(cy-1*s),px(cx+8*s),px(cy+10*s)),fill=col)
    for dx,dy,r in((-11,-6,4),(-4,-12,4),(4,-12,4),(11,-6,4)):
        circ(d,cx+dx*s,cy+dy*s,r*s,fill=col)
def person(d,cx,cy,col,s=1.0):
    circ(d,cx,cy-8*s,6*s,fill=col)
    d.pieslice((px(cx-12*s),px(cy+0*s),px(cx+12*s),px(cy+24*s)),180,360,fill=col)
def arrowhead(d,x,y,dx,dy,col,s=7):
    # triangle pointing along (dx,dy) with tip at x,y
    l=math.hypot(dx,dy); dx/=l; dy/=l; nx,ny=-dy,dx
    poly(d,[(x,y),(x-dx*s*1.4+nx*s*.9,y-dy*s*1.4+ny*s*.9),(x-dx*s*1.4-nx*s*.9,y-dy*s*1.4-ny*s*.9)],col)
def sword(d,x1,y1,x2,y2,col,acc):
    line(d,[(x1,y1),(x2,y2)],col,4)
    dx,dy=x2-x1,y2-y1; l=math.hypot(dx,dy); nx,ny=-dy/l,dx/l
    gx,gy=x1+dx*.28,y1+dy*.28
    line(d,[(gx-nx*8,gy-ny*8),(gx+nx*8,gy+ny*8)],acc,4)
    circ(d,x1-dx*.06,y1-dy*.06,3,fill=acc)

def chev(d,cx,cy,w,h,dirn,col,t=6):
    # chevron centred at cx,cy; dirn up/down/left/right; w = half span across, h = half depth
    if dirn=='up': pts=[(cx-w,cy+h),(cx,cy-h),(cx+w,cy+h)]
    elif dirn=='down': pts=[(cx-w,cy-h),(cx,cy+h),(cx+w,cy-h)]
    elif dirn=='left': pts=[(cx+h,cy-w),(cx-h,cy),(cx+h,cy+w)]
    else: pts=[(cx-h,cy-w),(cx+h,cy),(cx-h,cy+w)]
    line(d,pts,col,t)
def brackets(d,col,cx=32,cy=32,r=17,l=9,t=5):
    for sx in(-1,1):
        for sy in(-1,1):
            x,y=cx+sx*r,cy+sy*r
            line(d,[(x-sx*l,y),(x,y),(x,y-sy*l)],col,t)
RED=(240,90,80,255); GRN=(110,220,120,255)
def draw(name,d,acc):
    W=WHITE
    if name=='JUMP':
        line(d,[(18,34),(32,20),(46,34)],W,6); line(d,[(18,48),(32,34),(46,48)],acc,6)
    elif name=='AUTORUN':
        for ox in (-8,6):
            line(d,[(22+ox,20),(34+ox,32),(22+ox,44)],W if ox>0 else acc,6)
    elif name=='INTERACT':
        rect(d,26,9,38,38,fill=W,r=5); circ(d,32,49,6.5,fill=acc)
    elif name=='SITSTAND':
        circ(d,32,15,6.5,fill=W)
        line(d,[(32,23),(32,38)],W,9)
        line(d,[(29,26),(18,38)],W,4); line(d,[(35,26),(46,38)],W,4)
        line(d,[(32,40),(14,44)],W,6); line(d,[(32,40),(50,44)],W,6)
        line(d,[(14,44),(40,52)],W,6); line(d,[(50,44),(24,52)],W,6)
        line(d,[(10,56),(54,56)],acc,3)
    elif name=='BACK':
        chev(d,26,32,13,9,'left',W,6); line(d,[(24,32),(48,32)],acc,6)
    elif name=='INSPECT':
        chev(d,32,24,16,8,'up',W,6); chev(d,32,40,16,8,'down',W,6); circ(d,32,32,4.5,fill=acc)
    elif name.startswith('TARGET_ENEMY') or name.startswith('TARGET_FRIEND'):
        col=RED if 'ENEMY' in name else GRN
        brackets(d,col); circ(d,32,32,4,fill=col)
        if name.endswith('PREV'): chev(d,18,52,5,4,'left',W,3)
        else: chev(d,46,52,5,4,'right',W,3)
        if 'FRIEND' in name:
            line(d,[(32,26),(32,38)],col,3); line(d,[(26,32),(38,32)],col,3)
    elif name=='ASSIST':
        brackets(d,W); circ(d,32,29,4,fill=acc); chev(d,32,46,9,6,'up',acc,5)
    elif name=='TARGET_PET': paw(d,32,34,W,1.15)
    elif name=='CLEAR_TARGET':
        brackets(d,W); line(d,[(25,25),(39,39)],RED,5); line(d,[(39,25),(25,39)],RED,5)
    elif name=='CYCLE_PARTY':
        rect(d,22,14,52,22,fill=acc,r=3); rect(d,22,28,52,36,fill=W,r=3); rect(d,22,42,52,50,fill=W,r=3)
        chev(d,13,18,5,4,'right',acc,4)
    elif name=='ATTACK':
        sword(d,16,48,46,18,W,acc); sword(d,48,48,18,18,W,acc)
    elif name=='STOP_ATTACK':
        sword(d,16,48,46,18,(150,152,160,255),(100,102,110,255)); sword(d,48,48,18,18,(150,152,160,255),(100,102,110,255))
        circ(d,32,32,17,outline=RED,w=4); line(d,[(20,44),(44,20)],RED,4)
    elif name=='PET_ATTACK':
        paw(d,26,38,W,.9); chev(d,46,22,6,5,'up',acc,5); chev(d,46,34,6,5,'up',acc,5)
    elif name=='ZOOM_IN':
        chev(d,32,20,16,8,'down',W,6); chev(d,32,44,16,8,'up',acc,6)
    elif name=='ZOOM_OUT':
        chev(d,32,20,16,8,'up',acc,6); chev(d,32,44,16,8,'down',W,6)
    elif name=='MAP':
        circ(d,32,26,13,fill=W); poly(d,[(21,33),(43,33),(32,53)],W); circ(d,32,26,5,fill=(24,26,32,255)); circ(d,32,26,2.5,fill=acc)
    elif name=='BAGS':
        rect(d,15,24,49,52,outline=W,w=5,r=8); line(d,[(24,24),(24,18),(40,18),(40,24)],W,5)
        chev(d,32,38,9,5,'down',acc,5)
    elif name=='CHARACTER':
        circ(d,32,21,8,fill=W); chev(d,32,44,15,8,'up',acc,7)
    elif name=='SPELLBOOK':
        line(d,[(12,20),(32,30),(52,20)],W,6); line(d,[(12,34),(32,44),(52,34)],acc,6); line(d,[(32,30),(32,44)],W,4)
    elif name=='TALENTS':
        pts=[]
        for i in range(10):
            r=17 if i%2==0 else 7; a=-math.pi/2+i*math.pi/5; pts.append((32+r*math.cos(a),33+r*math.sin(a)))
        poly(d,pts,acc)
    elif name=='QUESTS':
        text(d,'?',32,32,46,W); 
    elif name=='SOCIAL':
        circ(d,21,22,6,fill=W); chev(d,21,42,8,5,'up',W,5)
        circ(d,43,22,6,fill=acc); chev(d,43,42,8,5,'up',acc,5)
    elif name=='CHAT':
        rect(d,12,15,52,43,fill=W,r=7); poly(d,[(21,42),(21,54),(34,42)],W)
        for x in (23,32,41): circ(d,x,29,3,fill=(24,26,32,255))
    elif name=='RADIAL':
        circ(d,32,32,4.5,fill=acc)
        chev(d,32,16,8,5,'up',W,5); chev(d,32,48,8,5,'down',W,5); chev(d,16,32,8,5,'left',W,5); chev(d,48,32,8,5,'right',W,5)
    elif name=='GAMEMENU':
        for y in (22,32,42): line(d,[(18,y),(46,y)],W,5)
    elif name=='OCTOPAD':
        circ(d,32,32,13,outline=W,w=5)
        for i in range(8):
            a=i*math.pi/4; line(d,[(32+13*math.cos(a),32+13*math.sin(a)),(32+19*math.cos(a),32+19*math.sin(a))],W,5)
        circ(d,32,32,4,fill=acc)


def draw_ui(name,d,acc):
    W=WHITE
    if name=='UI_UP': chev(d,32,38,17,10,'up',acc,6); chev(d,32,26,17,10,'up',W,7)
    elif name=='UI_DOWN': chev(d,32,26,17,10,'down',acc,6); chev(d,32,38,17,10,'down',W,7)
    elif name=='UI_LEFT': chev(d,38,32,17,10,'left',acc,6); chev(d,26,32,17,10,'left',W,7)
    elif name=='UI_RIGHT': chev(d,26,32,17,10,'right',acc,6); chev(d,38,32,17,10,'right',W,7)
    elif name=='UI_CONFIRM': line(d,[(15,33),(27,45),(49,19)],GRN,8)
    elif name=='UI_BACK': chev(d,26,32,13,9,'left',W,6); line(d,[(24,32),(48,32)],RED,6)
    elif name=='UI_ALT':
        rect(d,19,10,45,54,outline=W,w=4,r=13); line(d,[(32,12),(32,30)],W,3); line(d,[(19,30),(45,30)],W,3)
        d.pieslice((px(21),px(12),px(43),px(34)),270,360,fill=acc)
        d.rectangle((px(32),px(20),px(43),px(29)),fill=acc)
    elif name=='UI_SHIFT': chev(d,32,24,16,9,'up',W,7); line(d,[(18,40),(46,40)],acc,6); line(d,[(18,50),(46,50)],acc,6)
    elif name=='UI_TAB_NEXT': chev(d,28,32,13,10,'right',W,7); line(d,[(47,18),(47,46)],acc,6)
    elif name=='UI_TAB_PREV': chev(d,36,32,13,10,'left',W,7); line(d,[(17,18),(17,46)],acc,6)
    elif name=='UI_SCROLL_UP': chev(d,32,20,15,8,'up',W,6); rect(d,25,32,39,52,fill=acc,r=6)
    elif name=='UI_SCROLL_DOWN': chev(d,32,44,15,8,'down',W,6); rect(d,25,12,39,32,fill=acc,r=6)
    elif name=='UI_DESTROY':
        line(d,[(20,24),(44,48)],RED,8); line(d,[(44,24),(20,48)],RED,8); line(d,[(18,14),(46,14)],W,5)
UI_NAMES=['UI_UP','UI_DOWN','UI_LEFT','UI_RIGHT','UI_CONFIRM','UI_BACK','UI_ALT','UI_SHIFT','UI_TAB_NEXT','UI_TAB_PREV','UI_SCROLL_UP','UI_SCROLL_DOWN','UI_DESTROY']
for th,acc in THEMES.items():
    for nm in UI_NAMES:
        im,d=base(acc); draw_ui(nm,d,acc)
        im.resize((64,64),Image.LANCZOS).save(os.path.join(IC,'%s_%s.tga'%(th,nm)))

NAMES=['JUMP','INTERACT','BACK','INSPECT','AUTORUN','SITSTAND','TARGET_ENEMY','TARGET_ENEMY_PREV','TARGET_FRIEND','TARGET_FRIEND_PREV',
 'ASSIST','TARGET_PET','CLEAR_TARGET','CYCLE_PARTY','ATTACK','STOP_ATTACK','PET_ATTACK','ZOOM_IN','ZOOM_OUT','MAP','BAGS','CHARACTER',
 'SPELLBOOK','TALENTS','QUESTS','SOCIAL','CHAT','RADIAL','GAMEMENU','OCTOPAD']
for th,acc in THEMES.items():
    for nm in NAMES:
        im,d=base(acc); draw(nm,d,acc)
        im.resize((64,64),Image.LANCZOS).save(os.path.join(IC,'%s_%s.tga'%(th,nm)))

# controller glyphs: Start / Select per style
def disc(ring):
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
    d.ellipse((px(3),px(3),px(61),px(61)),fill=(28,30,36,255),outline=ring,width=px(4)); return im,d
GRY=(110,112,120,255)
def pill():
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
    d.rounded_rectangle((px(2),px(14),px(62),px(50)),radius=px(14),fill=(28,30,36,255),outline=GRY,width=px(3)); return im,d
def save(im,n): im.resize((64,64),Image.LANCZOS).save(os.path.join(GL,n+'.tga'))
for sty in ('xbox','switch','switchn','ps'):
    if sty in('xbox',):
        im,d=disc(GRY)
        for y in (24,32,40): line(d,[(21,y),(43,y)],WHITE,4)
        save(im,sty+'_start')
        im,d=disc(GRY)
        rect(d,19,24,38,40,outline=WHITE,w=3,r=3); rect(d,26,28,45,44,outline=WHITE,w=3,r=3); save(im,sty+'_select')
    elif sty=='ps':
        im,d=pill()
        for y in (26,32,38): line(d,[(20,y),(44,y)],WHITE,3)
        save(im,'ps_start')
        im,d=pill()
        rect(d,20,28,44,42,outline=WHITE,w=3,r=3); line(d,[(32,34),(32,20)],WHITE,3); arrowhead(d,32,17,0,-1,WHITE,6); save(im,'ps_select')
    else:
        im,d=disc(GRY); line(d,[(32,20),(32,44)],WHITE,5); line(d,[(20,32),(44,32)],WHITE,5); save(im,sty+'_start')
        im,d=disc(GRY); line(d,[(20,32),(44,32)],WHITE,5); save(im,sty+'_select')
print(len(os.listdir(IC)),len(os.listdir(GL)))

# minimap button: round disc with the chevron mark
for th,acc in THEMES.items():
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
    d.ellipse((px(2),px(2),px(62),px(62)),fill=(24,26,32,255),outline=acc,width=px(4))
    chev(d,32,29,15,9,'up',WHITE,7); chev(d,32,43,15,9,'up',acc,7)
    im.resize((64,64),Image.LANCZOS).save(os.path.join(IC,'%s_MINIMAP.tga'%th))
