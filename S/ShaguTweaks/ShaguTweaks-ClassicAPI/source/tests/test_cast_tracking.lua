local root=(arg[1] or '.')..'/'
local frames,modules,hooks={}, {}, {}
local now,class,fullCast,fullChannel,liveChannel=10,'WARLOCK',false,false,false
GetTime=function() return now end
UnitName=function(unit) return unit=='player' and 'Me' or 'Same NPC Name' end
UnitClass=function() return class,class end
UnitIsUnit=function(a,b) return a==b end
strlower=string.lower;strfind=string.find
local function frame()
 local f={events={},scripts={}}
 function f:RegisterEvent(name) self.events[name]=true end
 function f:SetScript(k,v) self.scripts[k]=v end
 table.insert(frames,f);return f
end
CreateFrame=frame
ShaguTweaks={API={casts=true},L={customcast={AIMEDSHOT='Aimed Shot',MULTISHOT='Multi-Shot'}},mods=modules,
 T=setmetatable({},{__index=function(t,k) return k end}),GetGlobalEnv=function() return getfenv(0) end,GetExpansion=function() return 'vanilla' end}
function ShaguTweaks:register(m) modules[m.title]=m;return m end
ShaguTweaks.hooksecurefunc=function(name,fn) hooks[name]=fn end
ShaguTweaks.libspell={GetSpellInfo=function() return 'Aimed Shot','Rank 1' end}
ShaguTweaks.libtipscan={GetScanner=function() error('No tooltip scanning during native cast tracking') end}
local API=ShaguTweaks.API
API.GetCastInfo=function(unit) if unit=='target' and fullCast then return 'Fireball','','','icon',9000,15000 end end
API.GetChannelInfo=function(unit)
 if unit=='target' and fullChannel then return 'Drain','','','icon',9000,15000,nil,false,202,true end
 if unit=='target' and liveChannel then return nil,nil,nil,nil,nil,nil,nil,false,202,true end
end
API.UnitGUID=function(unit) return unit=='player' and 'PlayerGUID' or 'TargetGUID' end
API.UnitTokenFromGUID=function(guid) if guid=='TargetGUID' then return 'target' end end
UnitCastingInfo=function() error('Do not prefer another mod global over the normalized ClassicAPI wrapper') end
dofile(root..'libs/libcast.lua');local lib=ShaguTweaks.libcast
assert(not next(lib.events) and not next(lib.scripts) and not next(lib.db) and not next(hooks))
fullCast=true;assert(ShaguTweaks.UnitCastingInfo('target')=='Fireball' and not next(lib.db))
fullCast=false;lib.db['Same NPC Name']={cast='Wrong mob',start=10,casttime=5000}
assert(not ShaguTweaks.UnitCastingInfo('target'));lib.db['Same NPC Name']=nil
GetPlayerBuffID=function() end;CombatLogAdd=function() end
local metadataCalls=0
SpellInfo=function(id) metadataCalls=metadataCalls+1;return 'Spell '..id,'rank','icon' end
UNKNOWN='Unknown';ShaguTweaks_config={['Enemy Castbars']=1};modules['Enemy Castbars']={enabled=true}
dofile(root..'mods/superwow.lua');local mod=modules['Super WoW Compatibility']
mod:enable();local count=table.getn(frames);mod:enable();assert(table.getn(frames)==count)
local listener=mod.listener
local changes=0;lib.OnRemoteChanged=function() changes=changes+1 end
local function emit(guid,kind,id,duration)
 arg1,arg3,arg4,arg5=guid,kind,id,duration;listener.scripts.OnEvent()
end
emit('PlayerGUID','START',101,3000);assert(metadataCalls==0 and not next(lib.db))
fullCast=true;emit('TargetGUID','START',101,3000);assert(metadataCalls==0 and not next(lib.db))
fullCast=false;fullChannel=true;emit('TargetGUID','CHANNEL',202,5000);assert(metadataCalls==0 and not next(lib.db))
fullChannel=false;liveChannel=true;emit('TargetGUID','CHANNEL',202,5000)
assert(lib.db.TargetGUID.channel and changes==1)
local f=assert(io.open(root..'mods/target-castbar.lua'));local source=f:read('*a');f:close();assert(loadstring(source))
local a=assert(string.find(source,'local function QuerySuperWoW',1,true));local b=assert(string.find(source,'local POSITION_KEY',a,true))
local query=assert(loadstring('local API=ShaguTweaks.API;local SuperWoWCastingInfo=ShaguTweaks.UnitCastingInfo;local SuperWoWChannelInfo=ShaguTweaks.UnitChannelInfo;'..string.sub(source,a,b-1)..'return QueryCast'))()
local name,_,_,_,startTime,endTime,_,channel=query('target')
assert(name=='Spell 202' and startTime==10000 and endTime==15000 and channel)
liveChannel=false;assert(not query('target')) -- stale channel cannot resurrect without live native identity
liveChannel=true;lib.db.TargetGUID.spellID=999;assert(not query('target'));lib.db.TargetGUID.spellID=202
emit('TargetGUID','FAIL',101,0);assert(lib.db.TargetGUID)
emit('TargetGUID','FAIL',202,0);assert(not lib.db.TargetGUID and changes==2)
emit('TargetGUID','CHANNEL',202,0);assert(not lib.db.TargetGUID)
emit('TargetGUID','CHANNEL',202,5000);now=16;assert(not query('target') and not lib.db.TargetGUID)
for i=1,160 do emit('Remote'..i,'CHANNEL',202,5000) end
local n=0;for key in pairs(lib.db) do n=n+1 end;assert(n==128)
assert(not listener.scripts.OnUpdate)
now=22;emit('Fresh','CHANNEL',202,1000);n=0;for key in pairs(lib.db) do n=n+1 end;assert(n==1)
ShaguTweaks_config['Enemy Castbars']=0;dofile(root..'mods/superwow.lua');count=table.getn(frames)
modules['Super WoW Compatibility']:enable();assert(table.getn(frames)==count)
-- Keep Hunter custom cast timing/stop behavior isolated from other classes.
class='HUNTER';now=30;UnitBuff=function() return nil end;GetNetStats=function() return 0,0,0 end
dofile(root..'libs/libcast.lua');lib=ShaguTweaks.libcast
assert(lib.events.SPELLCAST_STOP and not lib.events.UNIT_SPELLCAST_START)
lib.customcast['aimed shot'](true)
assert(ShaguTweaks.UnitCastingInfo('player')=='Aimed Shot')
lib.scripts.OnEvent();assert(not ShaguTweaks.UnitCastingInfo('player'))
lib.customcast['multi-shot'](true);assert(ShaguTweaks.UnitCastingInfo('player')=='Multi-Shot')
now=31;assert(not ShaguTweaks.UnitCastingInfo('player'))
GetSpellName=function(id) if id==1 then return 'Aimed Shot','Rank 1' end return 'Other Spell','Rank 1' end
GetSpellCooldown=function() return 1 end
IsCurrentAction=function() return true end
hooks.CastSpell(2,'spell');assert(not ShaguTweaks.UnitCastingInfo('player'))
hooks.CastSpell(1,'spell');assert(ShaguTweaks.UnitCastingInfo('player')=='Aimed Shot')
lib.scripts.OnEvent()
hooks.CastSpellByName('Other Spell');assert(not ShaguTweaks.UnitCastingInfo('player'))
hooks.CastSpellByName('Aimed Shot');assert(ShaguTweaks.UnitCastingInfo('player')=='Aimed Shot')
lib.scripts.OnEvent()
API.actioninfo=true;API.GetActionInfo=function() return 'spell',19434 end
API.GetSpellInfo=function() return 'Aimed Shot','Rank 1' end
hooks.UseAction(1);assert(ShaguTweaks.UnitCastingInfo('player')=='Aimed Shot')
lib.scripts.OnEvent()
API.GetActionInfo=function() return 'macro',1 end
hooks.UseAction(1);assert(not ShaguTweaks.UnitCastingInfo('player'))
print('Cast tracking: no native mirror/chat parser, authoritative units, demand/duplicate guards, live channel identity, fail/expiry/cap cleanup and Hunter custom timing passed')
