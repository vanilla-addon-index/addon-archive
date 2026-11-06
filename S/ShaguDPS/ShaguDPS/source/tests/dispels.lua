-- Lua 5.0, run from the repository root.
local now, combat = 1, false
function GetTime() return now end
function GetNumRaidMembers() return 2 end
function GetNumPartyMembers() return 0 end
function UnitName(unit)
 if unit=='player' or unit=='raid1' then return 'Priest' end
 if unit=='raid2' then return 'Mage' end
 if unit=='target' then return 'Boss' end
end
function UnitExists(unit) return UnitName(unit)~=nil end
function UnitIsPlayer(unit) return unit~='target' and UnitExists(unit) end
function UnitClass(unit) return 'Priest', unit=='raid2' and 'MAGE' or 'PRIEST' end
function UnitIsFriend(_,unit) return unit~='target' end
function UnitIsDead() return false end
function UnitClassification() return 'worldboss' end
function UnitLevel() return -1 end
function UnitAffectingCombat(unit) return combat and UnitExists(unit) end
function CreateFrame()
 return {events={}, scripts={},RegisterEvent=function(self,k) self.events[k]=true end,SetScript=function(self,k,fn) self.scripts[k]=fn end}
end
CombatLogGetCurrentEventInfo=function() end
gsub,strsub=string.gsub,string.sub
ShaguDPS={parser={},config={merge_pets=1},data={damage={[0]={},[1]={}},heal={[0]={},[1]={}},classes={}}}
dofile('parser.lua')
dofile('fights.lua')
local p,d,f=ShaguDPS.parser,ShaguDPS.data,ShaguDPS.fights
local listener=ShaguDPS.dispels
assert(listener.available and listener.events.COMBAT_LOG_EVENT_UNFILTERED)
local function dispel(source,target,aura,kind)
 event,arg2,arg3,arg5,arg9,arg15,arg16='COMBAT_LOG_EVENT_UNFILTERED',kind or 'SPELL_DISPEL',false,source,target,123,aura
 listener.scripts.OnEvent()
end
p.combat:UpdateState()
combat=true
p.combat:UpdateState()
dispel('Priest','Mage','Curse')
assert(d.dispels_done[1].Priest._sum==1 and d.dispels_received[1].Mage._sum==1)
assert(d.dispels_done[1].Priest._auras.Curse==1 and d.dispels_done[1].Priest._players.Mage==1)
assert(d.dispels_received[1].Mage._players.Priest==1)
now=2
this=f;f.scripts.OnUpdate()
dispel('Priest','Mage','Disease')
dispel('Mage','Priest','Poison')
dispel('Priest','Enemy','Magic buff') -- offensive dispel
assert(d.dispels_done[1].Priest._sum==3 and not d.dispels_received[1].Enemy)
dispel('Enemy','Priest','Friendly buff') -- received hostile dispel
assert(d.dispels_received[1].Priest._sum==2 and not d.dispels_done[1].Enemy)
dispel('Priest','Mage','Curse','SPELL_DISPEL_FAILED')
dispel('Priest','Mage','Curse','SPELL_CAST_SUCCESS')
assert(d.dispels_done[1].Priest._sum==3, 'failed dispels and casts do not count')
dispel('Enemy','Other enemy','Magic buff')
assert(not d.dispels_done[1].Enemy)
now,combat=12,false
p.combat:UpdateState()
assert(table.getn(f.list)==1, 'dispel-only boss fight is saved')
assert(f.list[1].dispels_done.Priest._sum==3 and f.list[1].classes.Priest=='PRIEST')
now,combat=20,true
p.combat:UpdateState()
dispel('Mage','Priest','Curse')
assert(not d.dispels_done[1].Priest and d.dispels_done[1].Mage._sum==1, 'new segment starts clean')
assert(d.dispels_done[0].Priest._sum==3 and d.dispels_done[0].Mage._sum==2)
assert(f.list[1].dispels_done.Priest._sum==3, 'saved data is an independent copy')
-- Older history entries have no dispel fields but remain selectable.
f.list[2]={id=99,classes={Priest='PRIEST'},damage={},heal={}}
assert(f:ForWindow({fight=99}).dispels_done==nil)
-- No ClassicAPI: no registration or inferred events.
CombatLogGetCurrentEventInfo=nil
dofile('parser.lua')
assert(not ShaguDPS.dispels.available and not ShaguDPS.dispels.events.COMBAT_LOG_EVENT_UNFILTERED)
print('Dispels event, segmentation, history and compatibility checks passed (Lua 5.0)')
