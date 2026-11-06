// Exercise the data-only dependency boundary with isolated fixtures.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
const {loadDatabase,inspectDatabase}=require('../tools/shared-database');
module.exports=function() {
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'questline-database-'));
  const addon=path.join(temp,'addon'),source=path.join(temp,'source');
  fs.mkdirSync(addon);fs.mkdirSync(path.join(source,'source'),{recursive:true});
  let checks=0;
  try {
    const names=['quests','items','units','objects','refloot','quests-itemreq','zones','areatrigger','minimap','meta','locales','scriptedEncounters','supplemental'];
    for(const name of names) fs.writeFileSync(path.join(source,'source',name+'.json'),'{}\n');
    fs.writeFileSync(path.join(source,'LICENSE'),'MIT fixture\n');fs.writeFileSync(path.join(source,'NOTICE.md'),'Attribution fixture\n');
    assert.throws(()=>loadDatabase(addon,[source]),/revision differs/);checks++;
    const loaded=loadDatabase(addon,[source,'--update-lock']);
    assert.equal(loaded.lock.revision,inspectDatabase(source).manifest.revision);checks++;
    assert.equal(loaded.lock.schemaVersion,2);checks++;
    assert.deepEqual(loadDatabase(addon,[source]).data.quests,{});checks++;
    const lockFile=path.join(addon,'database-source.json'),pinned=fs.readFileSync(lockFile,'utf8');
    const questsFile=path.join(source,'source/quests.json');
    fs.writeFileSync(questsFile,JSON.stringify({2:{pre:[787],coords:[[12.34567,50,17,300]],signed:{'-1557':0},disabled:1,flag:false,unknown:'_'}})+'\n');
    assert.throws(()=>loadDatabase(addon,[source]),/revision differs/);checks++;
    assert.equal(fs.readFileSync(lockFile,'utf8'),pinned);checks++;
    const adopted=loadDatabase(addon,[source,'--update-lock']);
    assert.deepEqual(adopted.data.quests[2],{pre:{1:787},coords:{1:{1:12.34567,2:50,3:17,4:300}},signed:{'-1557':0},disabled:1,flag:false,unknown:'_'});checks++;
    fs.writeFileSync(path.join(source,'README.md'),'Documentation does not change the data pin\n');
    assert.equal(loadDatabase(addon,[source]).lock.revision,adopted.lock.revision);checks++;
    fs.appendFileSync(path.join(source,'NOTICE.md'),'Updated attribution\n');
    assert.throws(()=>loadDatabase(addon,[source]),/revision differs/);checks++;
    fs.writeFileSync(questsFile,'[]\n');assert.throws(()=>loadDatabase(addon,[source,'--update-lock']),/Expected shared source table/);checks++;
    fs.writeFileSync(questsFile,'{"2":{"pre":[null]}}\n');assert.throws(()=>loadDatabase(addon,[source,'--update-lock']),/JSON null/);checks++;
    fs.writeFileSync(questsFile,'{}\n');fs.unlinkSync(path.join(source,'source/units.json'));
    assert.throws(()=>loadDatabase(addon,[source,'--update-lock']),/Missing shared source table: units/);checks++;
    fs.writeFileSync(path.join(source,'source/units.json'),'{}\n');fs.writeFileSync(path.join(source,'source/unexpected.lua'),'return {}');
    assert.throws(()=>loadDatabase(addon,[source,'--update-lock']),/Unsupported shared source file/);checks++;
    assert.throws(()=>loadDatabase(addon,[source,'--unknown']),/Usage/);checks++;
  } finally {
    const resolved=path.resolve(temp),tempRoot=path.resolve(os.tmpdir())+path.sep;
    assert.ok(resolved.startsWith(tempRoot)&&path.basename(resolved).startsWith('questline-database-'));
    fs.rmSync(resolved,{recursive:true,force:true});
  }
  return checks;
};
