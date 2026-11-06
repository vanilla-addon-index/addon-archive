const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const {readLua,lua,luaparse}=require('../tools/lua-data');
const {geometry,GRID}=require('../tools/geometry');
const {badge,glow,area}=require('../tools/contour-assets');
const {packRuns,unpackRuns}=require('../tools/packed-runs');
const {mobObjectives,vendorObjectives,mobDropRates,npcQuests,questGivers}=require('../tools/mob-objectives');
const {mappedVendors}=require('../tools/vendor-locations');
let fengari;
try { fengari=require('fengari'); } catch (_) { fengari=require(path.join(root,'../.test-tools/node_modules/fengari')); }
const {lua:Lapi,lauxlib,lualib,to_luastring,to_jsstring}=fengari;
let checks=0;
checks+=require('./database-pipeline')();
const check=(value,message)=>{checks++;assert.ok(value,message);};
const originalBlips=fs.readFileSync(path.join(root,'tools/sources/minimap-objecticons.blp'));
const hiddenBlips=fs.readFileSync(path.join(root,'Textures/minimap-blips.blp'));
const {hideTurnIn}=require('../tools/minimap-blips');
check(hiddenBlips.equals(hideTurnIn(originalBlips)),'shipped minimap atlas matches reproducible build');
assert.throws(()=>hideTurnIn(Buffer.alloc(100)),/Unexpected native/);checks++;
const allowedChanges=new Set();
let removedAlpha=0;
for(let mip=0;mip<16;mip++) {
  const offset=originalBlips.readUInt32LE(20+mip*4),width=Math.max(1,128>>>mip);
  if(!offset||width<4) continue;
  for(let y=0;y<width;y++) for(let x=0;x<width;x++) {
    const pixel=(y%4)*4+x%4;
    const byte=offset+(Math.floor(y/4)*Math.ceil(width/4)+Math.floor(x/4))*16+Math.floor(pixel/2);
    const shift=(pixel%2)*4,oldAlpha=(originalBlips[byte]>>>shift)&15,newAlpha=(hiddenBlips[byte]>>>shift)&15;
    if(x>=width*3/4&&y<width/4) {
      assert.equal(newAlpha,0,'turn-in alpha cleared at mip '+mip);
      removedAlpha+=oldAlpha;allowedChanges.add(byte);
    } else assert.equal(newAlpha,oldAlpha,'other sprite alpha preserved at mip '+mip);
  }
}
check(removedAlpha>0,'native turn-in dot had visible pixels to remove');
check(originalBlips.length===hiddenBlips.length,'native atlas size preserved');
for(let i=0;i<originalBlips.length;i++) if(!allowedChanges.has(i)) assert.equal(hiddenBlips[i],originalBlips[i],'non-turn-in bytes preserved at '+i);
checks++;
const read=k=>JSON.parse(fs.readFileSync(path.join(root,'database',k+'.json'),'utf8'));
const quests=read('quests'),units=read('units'),items=read('items');
const {scriptedEncounter}=require('../tools/scripted-encounters');
const encounterDb={units,objects:read('objects'),scriptedEncounters:read('scriptedEncounters')};
const lillith=scriptedEncounter(encounterDb,1946,'objectiveCreature');
check(units[1946].coordinates.length===0,'summoning guidance does not invent ordinary Lillith spawns');
assert.deepEqual(lillith.coordinates,encounterDb.objects[1557].coordinates,'Lillith guidance uses upstream dinner-table coordinates');checks++;
check(!scriptedEncounter(encounterDb,1946,'turnin')&&!scriptedEncounter(encounterDb,1946,'vendor'),'summoning guidance cannot become a turn-in or vendor destination');
check(!scriptedEncounter({...encounterDb,units:{...units,1946:{coordinates:[[10,20,85]]}}},1946,'objectiveCreature'),'canonical creature spawns take priority');
check(Object.keys(quests).length>6000,'merged quests retained');
check(!quests[1],'upstream underscore tombstone honored');
check(quests[934]&&quests[7383]?.objectives.some(target=>target.kind==='item'&&target.id===18151),'both upstream Crown of the Earth records retained without local deletion');
check(units[92012].coordinates[0][2]===8,'Octo manual relocation applied');
check(!units[15350].coordinates.some(point=>point[2]===130||point[2]===215),'Horde Warbringer city spawns do not leak onto Silverpine or Mulgore');
check(units[15350].coordinates.some(point=>point[2]===1497)&&units[15350].coordinates.some(point=>point[2]===1638),'Horde Warbringer retains both real city destinations');
const warbringerGivers=questGivers({quests,units,objects:read('objects')});
check(!warbringerGivers.byZone[130]?.includes(15350)&&!warbringerGivers.byZone[215]?.includes(15350),'Wrong-map Warbringer pickups are absent from generated zone indexes');
check(warbringerGivers.byZone[1497]?.includes(15350)&&warbringerGivers.byZone[1638]?.includes(15350),'Warbringer pickups remain indexed on their city maps');
check(items[51220].drops.units[50610]===100,'Octo manual interaction applied');
check(mappedVendors(items[2320]).includes('2118'),'Coarse Thread includes Abigail Shiel as a vendor destination');
const commonVendors=Object.fromEntries(Array.from({length:10},(_,i)=>[i+1,0]));
assert.deepEqual(mappedVendors({vendors:commonVendors}),Object.keys(commonVendors),'widely stocked supplies retain every upstream vendor');checks++;
assert.deepEqual(mappedVendors({vendors:{1:0,2:0}}),['1','2'],'specialty vendor destinations remain mapped');checks++;
assert.deepEqual(mappedVendors({vendors:Object.fromEntries(Array.from({length:10},(_,i)=>[i+1,1]))}),Object.keys(commonVendors),'limited-stock items remain mapped');checks++;
check(quests[900].objectives.length===3,'all valve interactions preserved');
const mobIndex=mobObjectives({quests,units,items,lootGroups:read('lootGroups')});
check(mobIndex['rattlecage soldier'].includes('item:3162'),'Rattlecage Soldier drops Notched Rib');
check(mobIndex['young night web spider'].includes('unit:1504'),'kill objectives are indexed by mob name');
const lootFixture=mobObjectives({
  quests:{1:{objectives:[{kind:'item',id:10},{kind:'unit',id:1}]}},
  units:{1:{name:'Test Mob'},2:{name:'Quest Drop Mob'},3:{name:'Vendor Only'},4:{name:'Disabled Drop'}},
  items:{10:{drops:{units:{1:25,4:-1},groups:{20:100}},vendors:{3:1}}},
  lootGroups:{20:{units:{2:0},groups:{21:100}},21:{units:{1:50},groups:{20:100}}}
});
assert.deepEqual(lootFixture['test mob'],['item:10','unit:1']);checks++;
check(lootFixture['quest drop mob'].includes('item:10'),'zero-rate quest drops and cyclic reference loot resolve');
check(!lootFixture['vendor only']&&!lootFixture['disabled drop'],'vendors and disabled drops are excluded');
const vendorIndex=vendorObjectives({quests,units,items});
check(vendorIndex['abigail shiel'].includes('item:2320'),'vendor tooltip index connects Abigail Shiel to Coarse Thread');
const realRates=mobDropRates({quests,units,items,lootGroups:read('lootGroups')});
check(realRates['adult plainstrider']['item:7097']===10.4,'Leg Meat uses the owned Adult Plainstrider rate, not the example percentage');
check(realRates['rattlecage soldier']['item:3162']===40,'Notched Rib percentage is retained');
const rateFixture=mobDropRates({
  quests:{1:{objectives:[{kind:'item',id:10},{kind:'unit',id:1}]}},
  units:{1:{name:'Direct'},2:{name:'Reference'},3:{name:'Unknown'},4:{name:'Vendor'},5:{name:'Disabled'},
    6:{name:'Same Name'},7:{name:'Same Name'},8:{name:'Invalid'},10:{name:'Tiny'},11:{name:'Member'},12:{name:'Conflicting references'}},
  items:{10:{drops:{units:{1:25,3:0,5:-1,6:20,7:50,8:101,10:.0065},groups:{20:12.5,21:70}},vendors:{4:1}}},
  lootGroups:{20:{units:{1:50,2:4,11:0},groups:{22:100}},22:{units:{12:100},groups:{20:100}},21:{units:{12:100}}}
});
check(rateFixture.direct['item:10']===25,'direct unit rates take priority over reference membership');
check(rateFixture.reference['item:10']===12.5&&rateFixture.member['item:10']===12.5,'item reference percentage is used without multiplying membership flags');
check(!rateFixture.unknown&&!rateFixture.invalid&&!rateFixture.disabled&&!rateFixture.vendor,'unknown, invalid and vendor-only percentages are omitted');
check(!rateFixture['same name']&&!rateFixture['conflicting references'],'conflicting same-name variants and reference paths do not invent a rate');
check(rateFixture.tiny['item:10']===.0065,'small positive percentages are retained');
const npcFixture={
  quests:{1:{starters:[{kind:'unit',id:1},{kind:'unit',id:1},{kind:'object',id:4}],finishers:[{kind:'unit',id:2}]},
    2:{starters:[{kind:'unit',id:1}],finishers:[{kind:'unit',id:1}]},
    3:{starters:[{kind:'unit',id:3},{kind:'unit',id:999}],finishers:[]}},
  units:{1:{name:'  Quest   Giver ',coordinates:[[52.2,31,17,300],[52.2,31,17],[20,30,14]]},
    2:{name:'Turn-in Only',coordinates:[[50,50,17]]},3:{name:'Unlocated Giver',coordinates:[]}},
  objects:{4:{name:'Wanted!',coordinates:[[60,50,17],[60,50,17]]}}
};
const npcIndex=npcQuests(npcFixture),giverIndex=questGivers(npcFixture);
assert.deepEqual(npcIndex['quest giver'],{starters:[1,2],finishers:[2],factions:{1:'AH',2:'AH'}});checks++;
assert.deepEqual(npcIndex['turn-in only'],{starters:[],finishers:[1]});checks++;
assert.deepEqual(giverIndex.givers[1].quests,[1,2]);checks++;
assert.deepEqual(giverIndex.givers[1].coordinates,[[52.2,31,17],[20,30,14]]);checks++;
assert.deepEqual(giverIndex.byZone,{14:[1],17:[1,-4]});checks++;
assert.deepEqual(giverIndex.givers[-4],{name:'Wanted!',kind:'object',quests:[1],coordinates:[[60,50,17]]});checks++;
check(!giverIndex.givers[2]&&!giverIndex.givers[4]&&!giverIndex.givers[999],'turn-in-only NPCs and unresolved starters do not create giver pins');
const giverData=questGivers({quests,units,objects:read('objects')});
check(giverData.byZone[85].includes(-711)&&giverData.givers[-711].name==='Wanted!'&&giverData.givers[-711].quests.includes(398),'Maggot Eye wanted poster is compiled from upstream object starters');
check(giverData.byZone[17].includes(3338)&&giverData.givers[3338].quests.includes(844),'real Barrens starter and its quest chain are compiled');
for(const [id,quest] of [[1155,41905],[1156,41906],[62414,41850]]) {
  check(quests[quest].raceMask===0&&giverData.givers[id].faction==='A','reported quest has no race mask but retains its Alliance starter: '+quest);
  check(npcQuests({quests,units})[units[id].name.toLowerCase()].factions[quest]==='A','NPC tooltip index retains the reported starter faction: '+quest);
}
const factionFixture={quests:{1:{starters:[{kind:'unit',id:1},{kind:'unit',id:2}]},2:{starters:[{kind:'unit',id:1},{kind:'unit',id:3}]},3:{starters:[{kind:'object',id:1}]}},
  units:{1:{name:'Same Name',faction:'A'},2:{name:'Same Name',faction:'H'},3:{name:'Same Name'}},
  objects:{1:{name:'Alliance Poster',faction:'A',coordinates:[[10,20,17]]}}};
assert.deepEqual(npcQuests(factionFixture)['same name'].factions,{1:'AH',2:'AH'},'same-name variants merge factions per quest and keep unknown factions permissive');checks++;
check(questGivers(factionFixture).givers[-1].faction==='A','object starter factions are compiled separately from NPC IDs');
const sources=JSON.parse(fs.readFileSync(path.join(root,'reports/import.json'),'utf8'));
const manifest=JSON.parse(fs.readFileSync(path.join(root,'database/manifest.json'),'utf8'));
const lock=JSON.parse(fs.readFileSync(path.join(root,'database-source.json'),'utf8'));
check(manifest.source==='OctoQuestDatabase'&&manifest.sourceRevision===lock.revision&&manifest.inputs.some(input=>input.file==='source/quests.json'),'Pinned shared database provenance is recorded');
check(sources.policy.includes('OctoQuestDatabase is the sole database authority'),'Shared database import policy is recorded');
for(const output of manifest.outputs) assert.equal(require('../tools/shared-database').sha256(fs.readFileSync(path.join(root,'database',output.file))),output.sha256,'Snapshot hash: '+output.file);
checks++;
const generatedSource={QuestlineDB:{}};
readLua(path.join(root,'Data/Init.lua'),generatedSource);
check(generatedSource.QuestlineDB.sourceRevision===lock.revision,'Generated runtime records the pinned shared revision');
for(const kind of ['units','objects','events']) for(const [id,r] of Object.entries(read(kind))) {
  const seen=new Set();
  for(const p of r.coordinates) {
    assert.ok(p[0]>=0&&p[0]<=100&&p[1]>=0&&p[1]<=100&&p[2]>0,kind+':'+id+' bounds');
    const key=p.slice(0,3).join(':');assert.ok(!seen.has(key),kind+':'+id+' duplicate');seen.add(key);
  }
}
checks++;
const single=geometry([[40,40,17]]);check(single.runs.length===0&&single.points.length===1,'one target becomes icon');
const points=[[10,10],[10,11],[11,10],[11,12],[12,11],[12,12],[80,80],[80,81],[81,80],[81,82],[82,81],[82,82]];
const grouped=geometry(points);check(grouped.runs.length>0,'dense clusters become areas');
let middle=false;for(let i=0;i<grouped.runs.length;i+=3) if(grouped.runs[i]>GRID*.3&&grouped.runs[i]<GRID*.7) middle=true;
check(!middle,'distant areas never joined across empty zone');
check(geometry(points,true).runs.length===0,'turn-in targets remain points');
check(JSON.stringify(geometry(points))===JSON.stringify(grouped),'geometry deterministic');
assert.deepEqual(unpackRuns(packRuns(grouped.runs)),grouped.runs,'packed scanlines retain geometry exactly');checks++;
assert.deepEqual(unpackRuns(packRuns([0,63,64,1279,1280,4095])),[0,63,64,1279,1280,4095],'packed coordinate boundaries');checks++;
assert.throws(()=>unpackRuns('abc'),/Truncated/);assert.throws(()=>packRuns([4096]),/range/);checks++;
for(let i=0;i<grouped.runs.length;i+=3) check(grouped.runs[i]>=0&&grouped.runs[i]<GRID&&grouped.runs[i+1]>=0&&grouped.runs[i+2]<=GRID,'raster bounds');
check(badge(0,0,true)[1]>180&&badge(0,0,false)[1]<50,'selected fill is yellow; normal fill is burgundy');
check(glow(.7,0)[3]>0&&glow(1,0)[3]===0,'halo fades to transparent without square corners');
let seamChecks=0;
for(let a=0;a<16;a++) for(let b=0;b<16;b++) for(const t of [.1,.25,.49,.5,.51,.75,.9]) {
  if(Boolean(a&2)===Boolean(b&1)&&Boolean(a&4)===Boolean(b&8)) {
    const left=area(a,1,t),right=area(b,0,t);
    left.forEach((c,i)=>assert.ok(Math.abs(c-right[i])<1e-8,'horizontal contour seam '+a+':'+b));seamChecks++;
  }
  if(Boolean(a&8)===Boolean(b&1)&&Boolean(a&4)===Boolean(b&2)) {
    const top=area(a,t,1),bottom=area(b,t,0);
    top.forEach((c,i)=>assert.ok(Math.abs(c-bottom[i])<1e-8,'vertical contour seam '+a+':'+b));seamChecks++;
  }
}
check(seamChecks>800,'all compatible atlas edge orientations join seamlessly');
const fixture={pfDB:{units:{data:{}}}};
readLua(path.join(__dirname,'fixture.lua'),fixture);
check(fixture.pfDB.units.data[1].name==="L'épreuve",'UTF-8 and Lua apostrophe escapes preserved');
check(!fixture.pfDB.units.data[2]&&fixture.pfDB.units.data[3]==='_','patch deletion and tombstone distinguished');
if(fs.existsSync(path.join(root,'reports/Barrens-preview.html'))) {
  const preview=fs.readFileSync(path.join(root,'reports/Barrens-preview.html'),'utf8');
  const script=preview.match(/<script>([\s\S]*)<\/script>/)[1];
  const elements={};
  require('node:vm').runInNewContext(script,{document:{querySelector:key=>elements[key]||(elements[key]={})}});
  check(elements['#map'].innerHTML.includes('<rect'),'offline preview renders compiled areas');
  check(elements['#quests'].innerHTML.includes('Plainstrider Menace'),'offline preview includes quest selectors');
}

// Parse every runtime file and disallow syntax introduced after Lua 5.0.
const toc=fs.readFileSync(path.join(root,'Questline.toc'),'utf8');
const files=toc.split(/\r?\n/).filter(s=>s&&!s.startsWith('#')).map(s=>s.replace(/\\/g,'/'));
function walk(node,visit) {if(!node||typeof node!=='object')return;visit(node);for(const v of Object.values(node)) if(Array.isArray(v))v.forEach(n=>walk(n,visit));else if(v&&typeof v==='object')walk(v,visit);}
for(const name of files) {
  const code=fs.readFileSync(path.join(root,name),'utf8');
  const ast=luaparse.parse(code,{luaVersion:'5.1',comments:false});
  let constants=new Set();
  walk(ast,node=>{assert.notEqual(node.operator,'#',name+' uses Lua 5.1 length operator');assert.notEqual(node.operator,'%',name+' uses Lua 5.1 modulo operator');assert.notEqual(node.type,'VarargLiteral',name+' uses Lua 5.1 vararg expression');if(node.type==='StringLiteral'||node.type==='NumericLiteral')constants.add(node.raw);});
  check(constants.size<65536,name+' fits Vanilla constant table');
}
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
function run(code,name) {
  let status=lauxlib.luaL_loadbuffer(L,to_luastring(code),null,to_luastring(name));
  if(status===Lapi.LUA_OK) status=Lapi.lua_pcall(L,0,0,0);
  if(status!==Lapi.LUA_OK) throw Error(name+': '+to_jsstring(Lapi.lua_tostring(L,-1)));
}
run(fs.readFileSync(path.join(__dirname,'runtime.lua'),'utf8'),'runtime stubs');
for(const name of files) run(fs.readFileSync(path.join(root,name),'utf8'),name);
run('local count=0;for id in pairs(QuestlineDB.quests) do count=count+1 end;assert(count=='+Object.keys(quests).length+',"compiled snapshot must retain every upstream quest");assert(QuestlineDB.quests[934],"upstream quest 934 must not be deleted locally")','database authority');
run('runTests()','runtime tests');
run(`local Q=Questline;local data=QuestlineDB.quests[409];local target=data.objectives[1];local location=QuestlineDB.locations[target.key][85];assert(location and math.abs(location.anchor[1]-66.6)<.01 and math.abs(location.anchor[2]-44.9)<.01,"Lillith summoning table mapped");local entry={id=409,key="409",title=data.title,level=data.level,data=data,objectives={{text="Lillith Nefara slain: 0/1",kind="monster",done=false}}};assert(Q:HasLocations(entry) and not Q:MissingLocationHint(entry),"summoning objective mapped without missing-location warning");WorldMapFrame:Show();Q:ShowQuestTooltip(Q.tracker,entry,target,"Lillith Nefara");local text=WorldMapTooltip:GetText();assert(string.find(text,"Lillith Nefara\\n",1,true)==1 and string.find(text,"Lillith Nefara slain: 0/1",1,true),"NPC-first live objective");assert(string.find(text,"Candle of Beckoning",1,true) and string.find(text,"Dinner Table",1,true),"summoning instruction");entry.objectives[1].done=true;assert(table.getn(Q:Targets(entry))==0,"completed objective cleared");entry.complete=true;assert(Q:Targets(entry)[1].name=="Gunther Arcanus","real finisher retained");WorldMapTooltip:Hide();Q.partyQuestTooltip=nil;WorldMapFrame:Hide()`,'summoned objective regression');
run('local threadLocation=QuestlineDB.locations["item:2320"][85];assert(threadLocation and threadLocation.pointKinds and threadLocation.pointKinds[1]=="v","Coarse Thread vendors are compiled as vendor pins");local abigail=false;for i,p in ipairs(threadLocation.points) do if math.abs(p[1]-61)<.1 and math.abs(p[2]-52.4)<.1 and threadLocation.pointKinds[i]=="v" then abigail=true end end;assert(abigail,"Abigail Shiel is mapped in Brill");assert(string.len(QuestlineDB.locations["item:2876"][85].runs)>0,"Duskbat hunting area remains mapped");local thread=false;for _,t in ipairs(QuestlineDB.quests[375].objectives) do if t.key=="item:2320" and t.icon=="buy" then thread=true end end;assert(thread,"vendor-only thread objective uses the buy icon")','vendor display policy');
if(process.argv.includes('--review')) {
  const id=Number(Object.keys(quests).find(id=>quests[id].title==='Preventing Poison'))||845;
  const source='return Questline:ContourPatches(Questline:AreaRows(QuestlineDB.quests['+id+'].objectives,17))';
  let status=lauxlib.luaL_loadstring(L,to_luastring(source));
  if(status===Lapi.LUA_OK)status=Lapi.lua_pcall(L,0,1,0);
  if(status!==Lapi.LUA_OK)throw Error(to_jsstring(Lapi.lua_tostring(L,-1)));
  const patches=[];
  for(let i=1;i<=Lapi.lua_rawlen(L,-1);i++) {
    Lapi.lua_rawgeti(L,-1,i);const p=[];
    for(let j=1;j<=5;j++){Lapi.lua_rawgeti(L,-1,j);p.push(Lapi.lua_tonumber(L,-1));Lapi.lua_pop(L,1);}
    patches.push(p);Lapi.lua_pop(L,1);
  }
  Lapi.lua_pop(L,1);
  const x1=Math.min(...patches.map(p=>p[0]))-4,y1=Math.min(...patches.map(p=>p[1]))-4;
  const x2=Math.max(...patches.map(p=>p[2]))+4,y2=Math.max(...patches.map(p=>p[3]))+4;
  const width=720,height=Math.round(width*(y2-y1)/(x2-x1)*2/3),buckets={};
  const {bitmap,writePNG}=require('../tools/texture-format');
  writePNG(path.join(root,'reports','Rounded-area.png'),bitmap(width,height,(px,py)=>{
    const x=x1+px/width*(x2-x1),y=y1+py/height*(y2-y1),key=Math.floor(y*4);
    if(!buckets[key])buckets[key]=patches.filter(p=>p[1]<(key+1)/4&&p[3]>key/4);
    const patch=buckets[key].find(p=>x>=p[0]&&x<p[2]&&y>=p[1]&&y<p[3]);
    const color=patch?area(patch[4],(x-patch[0])/(patch[2]-patch[0]),(y-patch[1])/(patch[3]-patch[1])):[0,0,0,0];
    const a=color[3]/255,bg=[147,110,56];
    return [...bg.map((v,i)=>v*(1-a)+color[i]*a),255];
  },4));
  console.log('Rendered review for '+quests[id].title+' from '+patches.length+' actual Lua contour patches.');
}
console.log('Database / geometry / compatibility: '+checks+' checks passed. '+files.length+' Lua files parsed and executed.');
