// Offline geometry: local clusters -> padded hulls -> compact, unionable scanlines.
// Y is scaled to the world map's ~3:2 aspect ratio for distance calculations.
const GRID = 1280;
const Y_SCALE = 2 / 3;
const LINK = 3.6;
const PAD = 0.85;
function cross(o,a,b) { return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0]); }
function hull(points) {
  const p = points.slice().sort((a,b) => a[0]-b[0] || a[1]-b[1]);
  const lo=[], hi=[];
  for (const v of p) { while(lo.length>1 && cross(lo.at(-2),lo.at(-1),v)<=0) lo.pop(); lo.push(v); }
  for (const v of p.slice().reverse()) { while(hi.length>1 && cross(hi.at(-2),hi.at(-1),v)<=0) hi.pop(); hi.push(v); }
  return lo.slice(0,-1).concat(hi.slice(0,-1));
}
function roundedHull(points) {
  let poly=hull(points);
  // Bounded corner cutting rounds the padded hull without shaving off a large
  // fraction of a long edge or joining separate spawn clusters.
  for(let pass=0;pass<2;pass++) {
    const rounded=[];
    for(let i=0;i<poly.length;i++) {
      const a=poly[i],b=poly[(i+1)%poly.length];
      const length=Math.hypot(b[0]-a[0],(b[1]-a[1])*Y_SCALE);
      const t=Math.min(.25,.45/(length||1));
      rounded.push([a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t]);
      rounded.push([b[0]+(a[0]-b[0])*t,b[1]+(a[1]-b[1])*t]);
    }
    poly=rounded;
  }
  return poly;
}
function clusters(points) {
  const buckets = new Map(), visited = new Set(), result=[];
  const cell = p => [Math.floor(p[0]/LINK), Math.floor(p[1]*Y_SCALE/LINK)];
  points.forEach((p,i) => { const k=cell(p).join(':'); if(!buckets.has(k)) buckets.set(k,[]); buckets.get(k).push(i); });
  points.forEach((p,i) => {
    if(visited.has(i)) return;
    visited.add(i); const queue=[i], group=[];
    for(let q=0; q<queue.length; q++) {
      const current=points[queue[q]], [cx,cy]=cell(current); group.push(current);
      for(let x=cx-1;x<=cx+1;x++) for(let y=cy-1;y<=cy+1;y++) {
        for(const j of buckets.get(x+':'+y)||[]) if(!visited.has(j)) {
          const candidate=points[j];
          if(Math.hypot(candidate[0]-current[0], (candidate[1]-current[1])*Y_SCALE)<=LINK) { visited.add(j); queue.push(j); }
        }
      }
    }
    result.push(group);
  });
  return result.sort((a,b)=>b.length-a.length || a[0][0]-b[0][0] || a[0][1]-b[0][1]);
}
function representative(points) {
  const x=points.reduce((s,p)=>s+p[0],0)/points.length, y=points.reduce((s,p)=>s+p[1],0)/points.length;
  return points.reduce((best,p)=>Math.hypot(p[0]-x,(p[1]-y)*Y_SCALE)<Math.hypot(best[0]-x,(best[1]-y)*Y_SCALE)?p:best,points[0]).slice(0,2);
}
function scanHull(poly, rows) {
  for(let row=0; row<GRID; row++) {
    const y=(row+0.5)*100/GRID, hits=[];
    for(let i=0,j=poly.length-1;i<poly.length;j=i++) {
      const a=poly[j], b=poly[i];
      if((a[1]>y)!==(b[1]>y)) hits.push(a[0]+(y-a[1])*(b[0]-a[0])/(b[1]-a[1]));
    }
    hits.sort((a,b)=>a-b);
    for(let i=0;i+1<hits.length;i+=2) {
      const left=Math.max(0,Math.floor(hits[i]*GRID/100)), right=Math.min(GRID,Math.ceil(hits[i+1]*GRID/100));
      if(right>left) rows[row].push([left,right]);
    }
  }
}
function geometry(points, forcePoints=false) {
  const unique=[...new Map(points.map(p=>[p[0]+':'+p[1],p])).values()];
  const rows=Array.from({length:GRID},()=>[]), markers=[], centers=[];
  for(const group of clusters(unique)) {
    const center=representative(group); centers.push(center);
    const xs=group.map(p=>p[0]), ys=group.map(p=>p[1]);
    if(forcePoints || group.length<4 || Math.hypot(Math.max(...xs)-Math.min(...xs),(Math.max(...ys)-Math.min(...ys))*Y_SCALE)<2) markers.push(center);
    else {
      const expanded=[];
      for(const p of group) for(let a=0;a<8;a++) expanded.push([
        Math.max(0,Math.min(100,p[0]+Math.cos(a*Math.PI/4)*PAD)),
        Math.max(0,Math.min(100,p[1]+Math.sin(a*Math.PI/4)*PAD/Y_SCALE)),
      ]);
      scanHull(roundedHull(expanded),rows);
    }
  }
  const runs=[];
  rows.forEach((spans,y)=>{
    spans.sort((a,b)=>a[0]-b[0]);let current;
    for(const span of spans) {
      if(current&&span[0]<=current[1]) current[1]=Math.max(current[1],span[1]);
      else {if(current)runs.push(y,current[0],current[1]);current=span.slice();}
    }
    if(current) runs.push(y,current[0],current[1]);
  });
  return { anchor:centers[0], points:markers, runs, spawns:unique.length };
}
module.exports={ GRID, geometry, clusters, hull, roundedHull };
