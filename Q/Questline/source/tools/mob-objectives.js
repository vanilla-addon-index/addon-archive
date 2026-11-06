// A small tooltip index, compiled from our owned database. No spawn tables needed.
function mobObjectives(db,objectMode=false) {
  const byName=new Map(), visited=new Set();
  function add(unitId,key) {
    const name=(objectMode?db.objects:db.units)?.[unitId]?.name?.trim().toLowerCase().replace(/\s+/g,' ');
    if(!name) return;
    if(!byName.has(name)) byName.set(name,new Set());
    byName.get(name).add(key);
  }
  function drops(record,key,groups) {
    for(const [id,chance] of Object.entries((objectMode?record?.objects:record?.units)||{})) if(Number(chance)>=0) add(id,key);
    for(const [id,chance] of Object.entries(record?.groups||{})) {
      if(Number(chance)<0 || groups.has(id)) continue;
      groups.add(id);drops(db.lootGroups[id],key,groups);
    }
  }
  for(const quest of Object.values(db.quests)) for(const target of quest.objectives) {
    const key=target.kind+':'+target.id;
    if(visited.has(key)) continue;
    visited.add(key);
    if(target.kind===(objectMode?'object':'unit')) add(target.id,key);
    // Follow loot sources, not vendors or inventory-container contents.
    if(target.kind==='item') drops(db.items[target.id]?.drops,key,new Set());
  }
  return Object.fromEntries([...byName].sort(([a],[b])=>a<b?-1:a>b?1:0).map(([name,keys])=>[name,[...keys].sort()]));
}
function vendorObjectives(db) {
  const result={};
  for(const quest of Object.values(db.quests)) for(const target of quest.objectives||[]) {
    if(target.kind!=='item') continue;
    const key='item:'+target.id;
    for(const id of Object.keys(db.items[target.id]?.vendors||{})) {
      const name=db.units[id]?.name?.trim().toLowerCase().replace(/\s+/g,' ');
      if(name && !(result[name]||=[]).includes(key)) result[name].push(key);
    }
  }
  return Object.fromEntries(Object.entries(result).sort(([a],[b])=>a<b?-1:a>b?1:0).map(([name,keys])=>[name,keys.sort()]));
}
function npcQuests(db) {
  const result={};
  for(const [id,quest] of Object.entries(db.quests)) for(const role of ['starters','finishers']) {
    for(const target of quest[role]||[]) {
      if(target.kind!=='unit') continue;
      const name=db.units[target.id]?.name?.trim().toLowerCase().replace(/\s+/g,' ');
      if(!name) continue;
      const entry=result[name]||(result[name]={starters:[],finishers:[]});
      if(!entry[role].includes(Number(id))) entry[role].push(Number(id));
      if(role==='starters') {
        // Same-name NPC variants may serve different factions. Unknown faction
        // is permissive, just like an explicitly neutral starter.
        const faction=db.units[target.id].faction||'AH';
        const factions=entry.factions||(entry.factions={});
        factions[id]=[...new Set((factions[id]||'')+faction)].sort().join('');
      }
    }
  }
  return Object.fromEntries(Object.entries(result).sort(([a],[b])=>a<b?-1:a>b?1:0));
}
function mobDropRates(db) {
  const result={},visited=new Set();
  const valid=value=>Number.isFinite(Number(value))&&Number(value)>0&&Number(value)<=100 ? Number(value) : null;
  for(const quest of Object.values(db.quests)) for(const target of quest.objectives||[]) {
    if(target.kind!=='item'||visited.has(target.id))continue;
    visited.add(target.id);
    const drops=db.items[target.id]?.drops||{},rates=new Map(),direct=new Set();
    function add(unit,value) {
      if(!rates.has(unit))rates.set(unit,value);
      else if(rates.get(unit)!==value)rates.set(unit,null);
    }
    for(const [unit,value] of Object.entries(drops.units||{})) {
      if(Number(value)<0)continue;
      direct.add(unit);rates.set(unit,valid(value));
    }
    function group(id,rate,path) {
      if(path.has(id))return;
      const next=new Set(path);next.add(id);
      const record=db.lootGroups[id];if(!record)return;
      // Reference records identify members; the item's reference chance is the
      // percentage, as in pfQuest. Membership values are NOT extra percentages.
      for(const [unit,value] of Object.entries(record.units||{})) {
        if(Number(value)>=0&&!direct.has(unit))add(unit,rate);
      }
      for(const [child,value] of Object.entries(record.groups||{})) if(Number(value)>=0)group(child,rate,next);
    }
    for(const [id,value] of Object.entries(drops.groups||{})) if(Number(value)>=0)group(id,valid(value),new Set());
    const names=new Map();
    for(const [unit,rate] of rates) {
      const name=db.units[unit]?.name?.trim().toLowerCase().replace(/\s+/g,' ');if(!name)continue;
      if(!names.has(name))names.set(name,rate);
      else if(names.get(name)!==rate)names.set(name,null);
    }
    // A name can refer to multiple NPC IDs. Omit conflicting/unknown rates
    // rather than applying one variant's percentage to every mob with that name.
    for(const [name,rate] of names) if(rate!==null)(result[name]||={})['item:'+target.id]=rate;
  }
  return Object.fromEntries(Object.entries(result).sort(([a],[b])=>a<b?-1:a>b?1:0));
}
function questGivers(db) {
  const givers={},byZone={};
  for(const [id,quest] of Object.entries(db.quests)) for(const target of quest.starters||[]) {
    if(target.kind!=='unit' && target.kind!=='object') continue;
    const source=(target.kind==='object'?db.objects:db.units)?.[target.id];if(!source?.name) continue;
    // Object and unit IDs are separate namespaces. Negative map keys keep
    // objects distinct while preserving existing numeric NPC identities.
    const key=target.kind==='object'?-target.id:target.id;
    const giver=givers[key]||(givers[key]={name:source.name,kind:target.kind,quests:[],coordinates:[]});
    if(source.faction) giver.faction=source.faction;
    if(!giver.quests.includes(Number(id))) giver.quests.push(Number(id));
  }
  for(const [id,giver] of Object.entries(givers)) {
    const seen=new Set();
    const source=giver.kind==='object'?db.objects[-id]:db.units[id];
    for(const p of source.coordinates||[]) {
      const key=p.slice(0,3).join(':');if(seen.has(key)) continue;seen.add(key);
      giver.coordinates.push(p.slice(0,3));
      const list=byZone[p[2]]||(byZone[p[2]]=[]);if(!list.includes(Number(id)))list.push(Number(id));
    }
  }
  return {givers,byZone};
}
module.exports={mobObjectives,vendorObjectives,mobDropRates,npcQuests,questGivers};
