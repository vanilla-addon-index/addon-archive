// Code-drawn bevels and filtered coverage tiles for the existing UI asset system.
const fs=require('node:fs'),path=require('node:path');
const {bitmap,writeTGA,writePNG}=require('./texture-format');
const clamp=(n,lo=0,hi=1)=>Math.max(lo,Math.min(hi,n));
const mix=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*clamp(t));
const smooth=(a,b,x)=>{const t=clamp((x-a)/(b-a));return t*t*(3-2*t);};
function badge(x,y,selected=false) {
  const r=Math.hypot(x,y);
  if(r>1) return [0,0,0,0];
  // Coordinates increase downwards. Light comes from the upper left.
  const light=clamp(.52-(x*.45+y*.7)/(r||1),.08,1);
  if(r>.92) return [10,5,3,255*(1-smooth(.92,1,r))*(selected?.9:.65)];
  if(selected) {
    if(r>.84) return [...mix([42,29,7],[136,101,31],light),255];
    if(r>.74) return [...mix([139,91,20],[255,237,134],light*.65+(1-Math.abs((r-.79)/.05))*.35),255];
    const dome=clamp(1-r*r/(.74*.74));
    const gleam=Math.exp(-((x+.16)**2/.30+(y+.24)**2/.15));
    return [...mix([213,152,34],[255,237,119],dome*.55+gleam*.45),255];
  }
  if(r>.84) return [...mix([65,39,13],[219,183,96],light),255];
  if(r>.74) {
    const crest=1-Math.abs((r-.79)/.05);
    const gold=mix([111,72,24],[255,240,175],light*.73+crest*.27);
    return [...mix(gold,[255,241,153],selected?.28:0),255];
  }
  if(r>.69) return [...mix([36,13,7],[139,94,31],1-light),255];
  const dome=clamp(1-r*r/(.69*.69));
  const highlight=Math.exp(-((x+.22)**2/.24+(y+.29)**2/.09));
  const red=mix([36,7,5],[104,26,16],dome*.50+highlight*.5);
  return [...mix(red,[146,42,21],selected?.20:0),255];
}
function glow(x,y) {
  const r=Math.hypot(x,y);
  const alpha=.70*Math.exp(-Math.pow(Math.max(0,r-.50)/.23,2))*(1-smooth(.94,1,r));
  return [255,221,65,alpha*255];
}
// Marching-square bits: top-left 1, top-right 2, bottom-right 4, bottom-left 8.
// Quarter circles replace right-angle corners; diagonal islands stay separate.
function distance(mask,x,y) {
  if(mask===0) return -1;
  if(mask===15) return 1;
  if(mask===3) return .5-y;
  if(mask===6) return x-.5;
  if(mask===12) return y-.5;
  if(mask===9) return .5-x;
  const d=[.5-Math.hypot(x,y),.5-Math.hypot(1-x,y),.5-Math.hypot(1-x,1-y),.5-Math.hypot(x,1-y)];
  if(mask===5) return Math.max(d[0],d[2]);
  if(mask===10) return Math.max(d[1],d[3]);
  for(let i=0;i<4;i++) {
    if(mask===(1<<i)) return d[i];
    if(mask===(15^(1<<i))) return -d[i];
  }
  throw Error('Invalid contour mask '+mask);
}
function area(mask,x,y) {
  const d=distance(mask,x,y),fill=.30*smooth(-.025,.025,d),stroke=.72*(1-smooth(.20,.48,Math.abs(d)));
  const alpha=stroke+fill*(1-stroke);
  const rgb=[.30,.73,1].map((v,i)=>alpha?(v*stroke+[.10,.43,1][i]*fill*(1-stroke))/alpha*255:0);
  return [...rgb,alpha*255];
}
function atlas() {
  // Duplicated gutters prevent filtering from sampling a neighboring tile.
  return bitmap(256,256,(x,y)=>{
    const col=Math.floor(x/64),row=Math.floor(y/64),u=clamp((x-col*64-2)/60),v=clamp((y-row*64-2)/60);
    return area(row*4+col,u,v);
  },4);
}
function build() {
  const dir=path.resolve(__dirname,'../Textures');fs.mkdirSync(dir,{recursive:true});
  for(const selected of [false,true]) writeTGA(path.join(dir,selected?'circle-selected-v2.tga':'circle-v2.tga'),bitmap(64,64,(x,y)=>badge(x/32-1,y/32-1,selected),4));
  writeTGA(path.join(dir,'circle-glow-v2.tga'),bitmap(64,64,(x,y)=>glow(x/32-1,y/32-1),4));
  writeTGA(path.join(dir,'turnin-glow.tga'),bitmap(64,64,(x,y)=>[55,165,255,glow(x/32-1,y/32-1)[3]],4));
  writeTGA(path.join(dir,'area-contours.tga'),atlas());
  const preview=bitmap(384,192,(x,y)=>{
    const background=[30,25,20,255],selected=x>=192;
    const size=y<110?72:28,cx=selected?288:96,cy=y<110?56:150;
    let bg=background.slice(0,3);
    if(selected) {const c=glow((x-cx)/(size*.78),(y-cy)/(size*.78));bg=mix(bg,c.slice(0,3),c[3]/255);}
    if(Math.abs(x-cx)>size/2||Math.abs(y-cy)>size/2) return [...bg,255];
    const c=badge((x-cx)/(size/2),(y-cy)/(size/2),selected),a=c[3]/255;
    return [...mix(bg,c.slice(0,3),a),255];
  },4);
  fs.mkdirSync(path.resolve(__dirname,'../reports'),{recursive:true});
  writePNG(path.resolve(__dirname,'../reports/Badge-style.png'),preview);
  console.log('Built beveled badges and the filtered contour atlas.');
}
if(require.main===module) build();
module.exports={badge,glow,area,distance,atlas,build};
