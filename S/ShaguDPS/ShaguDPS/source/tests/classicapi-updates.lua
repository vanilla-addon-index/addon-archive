-- Exercise native event handlers and the real counter storage with Lua 5.0.
dofile('tests/dispels.lua')
CombatLogGetCurrentEventInfo=function() end
UnitOwnerGUID=function() end
local oldName, oldExists = UnitName, UnitExists
UnitName=function(unit) if unit=='0xTARGET' then return 'Mage' end return oldName(unit) end
UnitExists=function(unit) return unit=='0xTARGET' or oldExists(unit) end
local visible=true
UnitIsVisible=function() return visible end
UnitHealthMax=function() return 1000 end
UnitHealth=function() return 950 end
UNKNOWN,UNKNOWNOBJECT='Unknown','Unknown'
local p,d=ShaguDPS.parser,ShaguDPS.data
p.RegisterEvent=function() end
p.SetScript=function(self,key,fn) self[key]=fn end
dofile('parser-native.lua')
p.sources.classicapi.enable()
local function heal(over)
 local previous=d.heal[0].Priest and d.heal[0].Priest._esum or 0
 arg2,arg3,arg4,arg5,arg6,arg8,arg9='SPELL_HEAL',false,'0xPRIEST','Priest',1025,'0xTARGET','Mage'
 arg12,arg13,arg14,arg15,arg16=1,'Heal',2,100,over
 p.OnEvent()
 return d.heal[0].Priest._esum-previous
end
assert(heal(0)==50,'old zero-overheal builds use health fallback')
assert(heal(60)==40,'positive event overheal overrides health approximation')
assert(heal(0)==100,'known new runtime with visible absolute health can trust zero')
visible=false
assert(heal(0)==50,'unavailable health still requires fallback')
assert(heal(101)==50 and heal(-1)==50,'invalid suffixes do not corrupt totals')
visible=true
local function shield(id,name)
 arg2,arg3,arg4,arg5,arg6,arg8,arg9='DAMAGE_SHIELD',false,'0xPRIEST','Priest',1025,'0xENEMY','Enemy'
 arg12,arg13,arg14,arg15=id,name,8,25
 p.OnEvent()
end
shield(467,'Thorns')
assert(d.damage[0].Priest.Thorns==25)
shield(0,nil)
assert(d.damage[0].Priest['Reflect (Nature)']==25)
-- Independent listener: names enrich the breakdown without altering counts.
dofile('parser.lua')
local frame=ShaguDPS.dispels
local before=d.dispels_done[0].Priest and d.dispels_done[0].Priest._sum or 0
event,arg2,arg3,arg5,arg9,arg12,arg13,arg15,arg16='COMBAT_LOG_EVENT_UNFILTERED','SPELL_DISPEL',false,'Priest','Mage',527,'Dispel Magic',123,'Magic debuff'
frame.scripts.OnEvent()
assert(d.dispels_done[0].Priest._sum==before+1)
assert(d.dispels_done[0].Priest._abilities['Dispel Magic']==1)
arg12,arg13=0,nil
frame.scripts.OnEvent()
assert(d.dispels_done[0].Priest._abilities['Unknown ability']>=1)
assert(d.dispels_received[0].Mage._abilities['Dispel Magic']==1)
print('ClassicAPI named spells and healing compatibility checks passed (Lua 5.0)')
