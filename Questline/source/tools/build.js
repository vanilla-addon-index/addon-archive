// Compile Questline presentation views of the pinned OctoQuestDatabase snapshot.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { lua } = require('./lua-data');
const { GRID, geometry } = require('./geometry');
const { packRuns } = require('./packed-runs');
const { mappedVendors } = require('./vendor-locations');
const { scriptedEncounter } = require('./scripted-encounters');
const { mobObjectives, vendorObjectives, mobDropRates, npcQuests, questGivers } = require('./mob-objectives');
const root=path.resolve(__dirname,'..'), dir=path.join(root,'database');
const kinds=['quests','units','objects','items','zones','events','lootGroups','itemUses','scriptedEncounters','reference'];
const db=Object.fromEntries(kinds.map(k=>[k,JSON.parse(fs.readFileSync(path.join(dir,k+'.json'),'utf8'))]));
const sourceManifest=JSON.parse(fs.readFileSync(path.join(dir,'manifest.json'),'utf8'));
const sourceLock=JSON.parse(fs.readFileSync(path.join(root,'database-source.json'),'utf8'));
if(sourceManifest.source!=='OctoQuestDatabase'||sourceManifest.sourceRevision!==sourceLock.revision||sourceManifest.repository!==sourceLock.repository) throw Error('Imported snapshot differs from the pinned source; import before building.');
const sourceRevision=sourceManifest.sourceRevision;
for(const kind of kinds) {
  const file=kind+'.json',entry=sourceManifest.outputs?.find(entry=>entry.file===file);
  const digest=crypto.createHash('sha256').update(fs.readFileSync(path.join(dir,file))).digest('hex');
  if(!entry||digest!==entry.sha256) throw Error('Imported snapshot changed: '+file+'; correct shared source data and reimport.');
}
const issues=[], locations={}, runtimeQuests={}, zoneIndex={};
const tables={unit:'units',object:'objects',item:'items',event:'events',use:'itemUses',zone:'zones'};
function targetName(kind,id) {return db[tables[kind]]?.[id]?.name || (kind==='use'?db.items[id]?.name:'') || (kind==='event'?'Explore the quest location':kind+' '+id);}
function gather(kind,id,seen=new Set(),role='objectiveCreature') {
  const key=kind+':'+id;if(seen.has(key)) return [];
  seen.add(key);
  const record=db[tables[kind]]?.[id];
  if(!record) return [];
  if(record.coordinates) {
    const coordinates=kind==='unit'?(scriptedEncounter(db,id,role)?.coordinates||record.coordinates):record.coordinates;
    return coordinates.map(p=>[p[0],p[1],p[2],p[3],kind,record.name]);
  }
  let points=[];
  function sources(drops) {
    for(const [id,chance] of Object.entries(drops.units||{})) if(Number(chance)>=0) points.push(...gather('unit',id,seen,'objectiveItemSource'));
    for(const [id,chance] of Object.entries(drops.objects||{})) if(Number(chance)>0) points.push(...gather('object',id,seen));
    for(const [id,chance] of Object.entries(drops.groups||{})) if(Number(chance)>=0 && !seen.has('group:'+id)) {
      seen.add('group:'+id);if(db.lootGroups[id]) sources(db.lootGroups[id]);
    }
  }
  if(kind==='item') {
    sources(record.drops);
    for(const id of mappedVendors(record)) for(const point of gather('unit',id,seen,'vendor')) points.push([...point.slice(0,4),'vendor',db.units[id]?.name]);
  }
  if(kind==='use') for(const use of record) points.push(...gather(use.kind,use.id,seen));
  if(kind==='zone'&&record.bounds) {const b=record.bounds;points.push([b.x+b.width/2,b.y+b.height/2,b.parent]);}
  return points;
}
function target(t,turnin) {
  const key=(turnin?'turnin:':'')+t.kind+':'+t.id;
  if(!locations[key]) {
    const points=gather(t.kind,t.id,new Set(),turnin?'turnin':'objectiveCreature'), byZone={};
    for(const p of points) (byZone[p[2]]||=[]).push(p);
    locations[key]={};
    for(const [zone,coords] of Object.entries(byZone)) {
      const areaCoords=coords.filter(p=>p[4]!=='vendor');
      const vendorCoords=coords.filter(p=>p[4]==='vendor');
      const location=geometry(areaCoords.length?areaCoords:vendorCoords,turnin||t.kind==='event'||t.kind==='zone'||!areaCoords.length);
      if(vendorCoords.length && areaCoords.length) {
        const existing=new Set(location.points.map(p=>p[0]+':'+p[1]));
        for(const p of vendorCoords) if(!existing.has(p[0]+':'+p[1])) {location.points.push(p.slice(0,2));existing.add(p[0]+':'+p[1]);}
      }
      if(t.kind==='item' && location.points.length) {
        const vendors=new Set(vendorCoords.map(p=>p[0]+':'+p[1]));
        location.pointKinds=location.points.map(p=>vendors.has(p[0]+':'+p[1])?'v':'');
        const names={};
        for(const p of vendorCoords) if(p[5]) {
          const key=Math.round(p[0]*40)+':'+Math.round(p[1]*40);
          (names[key]||=new Set()).add(p[5]);
        }
        if(Object.keys(names).length) location.vendorNames=Object.fromEntries(Object.entries(names).map(([key,names])=>[key,[...names].sort().join(' / ')]));
      }
      // Keep named drop/interaction sources compact: one packed coordinate
      // string per source, rather than a repeated name at every spawn.
      if(t.kind==='item' || t.kind==='use') {
        const sources=new Map();
        for(const p of areaCoords) if(p[5] && (p[4]==='unit' || p[4]==='object')) {
          const key=p[4]+':'+p[5];
          if(!sources.has(key)) sources.set(key,{name:p[5],kind:p[4],points:new Map()});
          const xy=[Math.round(p[0]*40),Math.round(p[1]*40)];
          sources.get(key).points.set(xy.join(':'),xy);
        }
        if(sources.size) location.sources=[...sources.values()].map(source=>({...source,points:packRuns([...source.points.values()].sort((a,b)=>a[0]-b[0]||a[1]-b[1]).flat())}));
      }
      if(!turnin && ['unit','object','item','use'].includes(t.kind)) {
        const unique=new Map();
        for(const p of coords) {
          const xy=[Math.round(p[0]*40),Math.round(p[1]*40)],key=xy.join(':');
          const kind=t.kind==='item'?(p[4]==='vendor'?'v':p[4]==='object'?'g':'l'):'';
          const previous=unique.get(key);
          unique.set(key,{xy,kind:previous?.kind==='v'?'v':kind||previous?.kind});
        }
        const ordered=[...unique.values()].sort((a,b)=>a.xy[0]-b.xy[0]||a.xy[1]-b.xy[1]);
        location.spawnPoints=packRuns(ordered.flatMap(p=>p.xy));
        if(t.kind==='item') location.spawnKinds=ordered.map(p=>p.kind||'l').join('');
      }
      locations[key][zone]=location;
    }
    if(!points.length) issues.push({target:key,issue:'no-locations'});
  }
  let icon=t.icon || (t.kind==='item'?'loot':t.kind==='object'||t.kind==='use'?'interact':t.kind==='event'||t.kind==='zone'?'explore':'kill');
  if(t.kind==='item') {
    const sources=gather(t.kind,t.id);
    if(sources.length && sources.every(p=>p[4]==='vendor')) icon='buy';
    else if(sources.length && sources.every(p=>p[4]==='object')) icon='interact';
  }
  if(t.kind==='unit' && db.units[t.id]?.faction==='AH') icon='talk';
  if(turnin) icon='turnin';
  const result={kind:t.kind,id:t.id,key,name:targetName(t.kind,t.id),icon};
  if(t.kind==='unit') result.faction=db.units[t.id]?.faction||'';
  const scripted=t.kind==='unit' && scriptedEncounter(db,t.id,turnin?'turnin':'objectiveCreature');
  if(scripted?.note) result.note=scripted.note;
  return result;
}
const blockedBy={};
for(const [id,q] of Object.entries(db.quests)) for(const closed of q.closes) if(Number(id)!==closed) (blockedBy[closed]||=[]).push(Number(id));
for(const [id,q] of Object.entries(db.quests)) {
  const objectives=q.objectives.map(t=>target(t,false)),finishers=q.finishers.map(t=>target(t,true));
  runtimeQuests[id]={title:q.title,level:q.level,minLevel:q.minLevel,raceMask:q.raceMask,classMask:q.classMask,summary:q.summary,description:q.description,objectives,finishers,
    prerequisites:q.prerequisites,blockedBy:blockedBy[id]||[],skill:q.attributes.skill ? (db.reference.professions[q.attributes.skill]||'Unknown profession') : undefined,
    event:q.attributes.event,repeatable:q.attributes.repeatable ? true : undefined,
    disabled:q.attributes.disabled ? true : undefined};
  if(q.attributes.type!==undefined) runtimeQuests[id].questType=q.attributes.type;
  if(q.attributes.preActive) runtimeQuests[id].activePrerequisites=Object.values(q.attributes.preActive).map(Number);
  if(/^\[deprecated\]/i.test(q.title)) runtimeQuests[id].deprecated=true;
  for(const t of [...objectives,...finishers]) for(const zone of Object.keys(locations[t.key])) {
    if(!zoneIndex[zone]) zoneIndex[zone]=new Set();zoneIndex[zone].add(Number(id));
  }
}
const output=path.join(root,'Data');fs.mkdirSync(output,{recursive:true});
function writeTable(file,field,records,append=false) {
  const lines=[];
  for(const [k,record] of Object.entries(records)) {
    const v=field==='locations'?Object.fromEntries(Object.entries(record).map(([zone,data])=>[zone,{...data,runs:packRuns(data.runs)}])):record;
    lines.push('QuestlineDB.'+field+'['+lua(/^-?\d+$/.test(k)?Number(k):k)+']='+lua(v));
  }
  fs[append?'appendFileSync':'writeFileSync'](path.join(output,file),lines.join('\n')+'\n');
}
const digest=crypto.createHash('sha256').update(JSON.stringify(db)).update(sourceRevision).update(fs.readFileSync(__filename)).update(fs.readFileSync(path.join(__dirname,'geometry.js'))).update(fs.readFileSync(path.join(__dirname,'packed-runs.js'))).update(fs.readFileSync(path.join(__dirname,'mob-objectives.js'))).update(fs.readFileSync(path.join(__dirname,'vendor-locations.js'))).update(fs.readFileSync(path.join(__dirname,'scripted-encounters.js'))).digest('hex').slice(0,16);
fs.writeFileSync(path.join(output,'Init.lua'),'QuestlineDB={schemaVersion=2,runEncoding="base64-pairs",profile="octo",locale="enUS",sourceRevision='+lua(sourceRevision)+',build='+lua(digest)+',grid='+GRID+',quests={},locations={},zones={},zoneQuests={},mobObjectives={},objectObjectives={},vendorObjectives={},mobDropRates={},npcQuests={},givers={},zoneGivers={}}\n');
writeTable('Quests.lua','quests',runtimeQuests);
writeTable('Locations.lua','locations',locations);
writeTable('Zones.lua','zones',Object.fromEntries(Object.entries(db.zones).map(([id,zone])=>[id,{...zone,mapSize:db.reference.minimap[id]}])));
writeTable('ZoneQuests.lua','zoneQuests',Object.fromEntries(Object.entries(zoneIndex).map(([k,v])=>[k,[...v].sort((a,b)=>a-b)])));
writeTable('MobObjectives.lua','mobObjectives',mobObjectives(db));
writeTable('MobObjectives.lua','objectObjectives',mobObjectives(db,true),true);
writeTable('MobObjectives.lua','vendorObjectives',vendorObjectives(db),true);
writeTable('MobObjectives.lua','mobDropRates',mobDropRates(db),true);
writeTable('NPCQuests.lua','npcQuests',npcQuests(db));
const giverData=questGivers(db);
writeTable('QuestGivers.lua','givers',giverData.givers);
writeTable('ZoneGivers.lua','zoneGivers',giverData.byZone);
fs.mkdirSync(path.join(root,'reports'),{recursive:true});
const report={build:digest,sourceRevision,grid:GRID,quests:Object.keys(runtimeQuests).length,targets:Object.keys(locations).length,zones:Object.keys(zoneIndex).length,unmappedTargets:issues.length,issues,
  barrens:{quests:zoneIndex[17]?.size,examples:[844,845,903,855,895,881,900].map(id=>({id,title:runtimeQuests[id]?.title,targets:runtimeQuests[id]?.objectives.map(t=>({key:t.key,spawns:locations[t.key][17]?.spawns,scanlines:(locations[t.key][17]?.runs.length||0)/3,points:locations[t.key][17]?.points.length}))}))}};
fs.writeFileSync(path.join(root,'reports','build.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,issues:undefined},null,2));
module.exports={gather};
