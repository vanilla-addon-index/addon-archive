// Original, deterministic vector-style symbols rasterized to Vanilla-compatible TGA.
const fs=require('node:fs'),path=require('node:path');
const dir=path.resolve(__dirname,'../Textures');fs.mkdirSync(dir,{recursive:true});
function line(x,y,ax,ay,bx,by,width){const dx=bx-ax,dy=by-ay,t=Math.max(0,Math.min(1,((x-ax)*dx+(y-ay)*dy)/(dx*dx+dy*dy)));return Math.hypot(x-ax-t*dx,y-ay-t*dy)<width;}
function icon(name,x,y){
  if(name==='kill') return line(x,y,-.42,.44,.4,-.4,.075)||line(x,y,-.4,-.4,.42,.44,.075)||line(x,y,-.5,.12,-.13,.49,.07)||line(x,y,.15,.49,.5,.14,.07);
  if(name==='loot') return (Math.abs(x)<.35&&y>-.16&&y<.4)||(Math.abs(x)<.18&&y>-.44&&y<-.18)||line(x,y,-.28,-.16,.28,-.16,.04);
  if(name==='interact') {const r=Math.hypot(x,y),a=Math.atan2(y,x);return r>.2&&r<.37+(Math.cos(8*a)>.1?.12:0);}
  if(name==='talk') return (x*x/.22+y*y/.14<1&&y<.25)||(x>-.35&&x<-.12&&y>.15&&y<.42);
  if(name==='explore') return Math.abs(x)+Math.abs(y)<.52&&Math.abs(x)+Math.abs(y)>.30;
  if(name==='turnin') return (line(x,y,-.19,-.32,-.05,-.44,.07)||line(x,y,-.05,-.44,.2,-.32,.07)||line(x,y,.2,-.32,.2,-.1,.07)||line(x,y,.2,-.1,0,.04,.07)||line(x,y,0,.04,0,.18,.07)||Math.hypot(x,y-.39)<.085);
  return false;
}
for(const name of ['circle','circle-selected','kill','loot','interact','talk','explore','turnin']) {
  const size=32,header=Buffer.alloc(18);header[2]=2;header.writeUInt16LE(size,12);header.writeUInt16LE(size,14);header[16]=32;header[17]=8;
  const pixels=Buffer.alloc(size*size*4);
  for(let j=0;j<size;j++) for(let i=0;i<size;i++) {
    const total=[0,0,0,0];
    for(let sy=0;sy<4;sy++) for(let sx=0;sx<4;sx++) {
      const x=(i+(sx+.5)/4-size/2)/(size/2),y=(size/2-j-(sy+.5)/4)/(size/2),r=Math.hypot(x,y);
      let c=[0,0,0,0];
      if(r<.91) c=[17,24,32,240];
      if(r>.72&&r<.88) c=name==='circle-selected'?[114,211,255,255]:[191,144,57,255];
      if(name==='circle-selected'&&r<.72) c=[23,89,121,255];
      if(icon(name,x,y)) c=[255,225,143,255];
      for(let n=0;n<4;n++) total[n]+=c[n]/16;
    }
    const offset=(j*size+i)*4;pixels[offset]=Math.round(total[2]);pixels[offset+1]=Math.round(total[1]);pixels[offset+2]=Math.round(total[0]);pixels[offset+3]=Math.round(total[3]);
  }
  fs.writeFileSync(path.join(dir,name+'.tga'),Buffer.concat([header,pixels]));
}
console.log('Built 8 original TGA symbols.');
require('./contour-assets').build();
require('./minimap-blips').build();
