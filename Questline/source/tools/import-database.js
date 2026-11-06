// Questline adapter: normalize the pinned shared tables into its imported JSON schema.
// Development dependency only; generated Lua and JSON are committed for standalone releases.
const fs = require('node:fs');
const path = require('node:path');
const { loadDatabase, copyNotices, sha256 } = require('./shared-database');
const root = path.resolve(__dirname, '..');
const {data,manifest,lock,sourceRoot} = loadDatabase(root);
copyNotices(sourceRoot,manifest,path.join(root,'licenses/OctoQuestDatabase'));
const inputs = manifest.files;
const runtime = {};
for (const name of ['quests','items','units','objects','refloot','quests-itemreq','zones','areatrigger']) runtime[name]={data:data[name]};
for (const name of ['minimap','meta']) runtime[name]=data[name];
for (const name of ['items','quests','objects','units','zones','professions']) (runtime[name]||={}).enUS=data.locales[name]||{};
const env = {QuestieOcto:{RuntimeScriptedEncounters:data.scriptedEncounters}};

const values = value => Object.values(value || {});
const issues = [], stats = {coordinatesRead:0,invalidCoordinates:0,duplicateCoordinates:0};
function coords(raw, kind, id) {
  const result=[], seen=new Set();
  for (const c of values(raw)) {
    stats.coordinatesRead++;
    const x=Number(c[1]), y=Number(c[2]), zone=Number(c[3]);
    if (!Number.isFinite(x)||!Number.isFinite(y)||x<0||x>100||y<0||y>100||!Number.isInteger(zone)||zone<=0||(x===0&&y===0)) {
      stats.invalidCoordinates++; issues.push({kind,id:Number(id),issue:'invalid-coordinate',coordinate:c}); continue;
    }
    const point=[Math.round(x*1000)/1000,Math.round(y*1000)/1000,zone];
    if (c[4]!==undefined && Number.isFinite(Number(c[4]))) point.push(Number(c[4]));
    const key=point.slice(0,3).join(':');
    if (seen.has(key)) { stats.duplicateCoordinates++; continue; }
    seen.add(key); result.push(point);
  }
  return result.sort((a,b)=>a[2]-b[2]||a[0]-b[0]||a[1]-b[1]);
}
const typeNames={U:'unit',O:'object',I:'item',A:'event',IR:'use',Z:'zone'};
function targets(raw, owner) {
  const result=[];
  for (const [code,ids] of Object.entries(raw||{})) {
    if (!typeNames[code]) { issues.push({issue:'unknown-target-kind',owner,code}); continue; }
    for (const id of values(ids)) result.push({kind:typeNames[code],id:Number(id)});
  }
  return result;
}
function extras(raw, keys) { return Object.fromEntries(Object.entries(raw).filter(([key])=>!keys.includes(key))); }
const db={schemaVersion:1,locale:'enUS',profile:'octo',quests:{},units:{},objects:{},items:{},zones:{},events:{},lootGroups:{},itemUses:{},scriptedEncounters:{}};
for (const [id,r] of Object.entries(env.QuestieOcto.RuntimeScriptedEncounters||{})) db.scriptedEncounters[id]={
  roles:r.roles||{},coordinates:coords(r.coords,'scriptedEncounter',id),anchorObject:r.anchorObject,displayName:r.displayName,note:r.note};
for (const [id,r] of Object.entries(runtime.quests.data)) {
  const localized=runtime.quests.enUS[id];
  if (!localized || typeof localized!=='object' || !localized.T) { issues.push({kind:'quest',id:Number(id),issue:'missing-title'}); continue; }
  db.quests[id]={title:localized.T,level:Number(r.lvl)||0,minLevel:Number(r.min)||0,raceMask:Number(r.race)||0,classMask:Number(r.class)||0,
    description:localized.D||'',summary:localized.O||'',starters:targets(r.start,'quest:'+id),finishers:targets(r.end,'quest:'+id),objectives:targets(r.obj,'quest:'+id),
    prerequisites:values(r.pre).map(Number),closes:values(r.close).map(Number),attributes:extras(r,['lvl','min','race','class','start','end','obj','pre','close'])};
}
for (const kind of ['units','objects']) for (const [id,r] of Object.entries(runtime[kind].data)) db[kind][id]={
  name:runtime[kind].enUS[id]||'',coordinates:coords(r.coords,kind,id),faction:r.fac||'',level:r.lvl||'',attributes:extras(r,['coords','fac','lvl'])};
for (const [id,r] of Object.entries(runtime.items.data)) db.items[id]={name:runtime.items.enUS[id]||'',drops:{units:r.U||{},objects:r.O||{},groups:r.R||{}},vendors:r.V||{},attributes:extras(r,['U','O','R','V'])};
for (const [id,r] of Object.entries(runtime.refloot.data)) db.lootGroups[id]={units:r.U||{},objects:r.O||{},groups:r.R||{},attributes:extras(r,['U','O','R'])};
for (const [id,r] of Object.entries(runtime['quests-itemreq'].data)) db.itemUses[id]=Object.entries(r).map(([target,spell])=>({kind:Number(target)<0?'object':'unit',id:Math.abs(Number(target)),spell:Number(spell)}));
for (const [id,r] of Object.entries(runtime.areatrigger.data)) db.events[id]={coordinates:coords(r.coords,'event',id),attributes:extras(r,['coords'])};
const zoneWeight={};
for (const kind of ['units','objects','events']) for (const r of Object.values(db[kind])) for (const p of r.coordinates) zoneWeight[p[2]]=(zoneWeight[p[2]]||0)+1;
for (const [id,name] of Object.entries(runtime.zones.enUS)) {
  const r=runtime.zones.data[id]; db.zones[id]={name:name.trim(),coordinateCount:zoneWeight[id]||0};
  if (r) db.zones[id].bounds={parent:Number(r[1]),width:Number(r[2]),height:Number(r[3]),x:Number(r[4]),y:Number(r[5])};
}
const groups={};
for (const [id,z] of Object.entries(db.zones)) (groups[z.name]||=[]).push(Number(id));
for (const [name,ids] of Object.entries(groups)) if (ids.length>1) issues.push({issue:'duplicate-zone-name',name,ids,preferred:ids.sort((a,b)=>(zoneWeight[b]||0)-(zoneWeight[a]||0)||a-b)[0]});
const kindTable={unit:'units',object:'objects',item:'items',event:'events',use:'itemUses',zone:'zones'};
for (const [id,q] of Object.entries(db.quests)) for (const target of [...q.starters,...q.finishers,...q.objectives]) if (!db[kindTable[target.kind]]?.[target.id]) issues.push({issue:'missing-reference',quest:Number(id),target});

const output=path.join(root,'database'); fs.mkdirSync(output,{recursive:true}); fs.mkdirSync(path.join(root,'reports'),{recursive:true});
const outputs=[];
function writeRecords(name, records) {
  const bytes='{\n'+Object.entries(records).map(([k,v])=>'  '+JSON.stringify(k)+': '+JSON.stringify(v)).join(',\n')+'\n}\n';
  fs.writeFileSync(path.join(output,name+'.json'),bytes);
  outputs.push({file:name+'.json',sha256:sha256(bytes)});
}
for (const [kind,records] of Object.entries(db)) if (typeof records==='object') writeRecords(kind,records);
writeRecords('reference',{meta:runtime.meta||{},minimap:runtime.minimap||{},professions:runtime.professions.enUS||{}});
const counts=Object.fromEntries(Object.entries(db).filter(([,v])=>typeof v==='object').map(([k,v])=>[k,Object.keys(v).length]));
fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify({schemaVersion:1,locale:db.locale,profile:db.profile,source:'OctoQuestDatabase',sourceRevision:lock.revision,repository:lock.repository,inputs,outputs,counts,stats},null,2)+'\n');
fs.writeFileSync(path.join(root,'reports','import.json'),JSON.stringify({policy:'OctoQuestDatabase is the sole database authority. This adapter consumes the pinned effective source tables. Coordinates are validated and deduplicated; zone IDs are preserved. No local overrides or fallback database are applied.',issues},null,2)+'\n');
console.log(JSON.stringify({counts,stats,issues:issues.length},null,2));
