local root=(arg[1] or '.')..'/'
local frames,listeners,notified={}, {}, 0
local compatible=true
UnitExists=function(unit) return true,compatible and (unit=='player' and 'SelfGUID' or 'TargetGUID') or 'WrongGUID' end
UnitGUID=function(unit) return unit=='player' and 'SelfGUID' or 'TargetGUID' end
UnitName=function(unit) return unit=='player' and 'Self' or 'Friend' end
UnitIsDeadOrGhost=function() return false end
UnitCanAssist=function() return true end
GetTime=function() return 10 end
CreateFrame=function()
 local f={events={},scripts={}}
 function f:RegisterEvent(name) self.events[name]=true end
 function f:UnregisterAllEvents() self.events={} end
 function f:SetScript(name,fn) self.scripts[name]=fn end
 table.insert(frames,f);return f
end
ShaguTweaks={GetGlobalEnv=function() return getfenv(0) end,API={RegisterUnitEvent=function(f,e) f:RegisterEvent(e) end}}
C_EventUtils={IsEventValid=function() return true end}
local value=370
PTHealPredict={GetIncomingHealing=function(guid) assert(guid=='SelfGUID' or guid=='TargetGUID');return value,300 end,
 HookUpdates=function(fn) table.insert(listeners,fn) end}
dofile(root..'libs/libpredict.lua')
local P=ShaguTweaks.libpredict;P.changed=function() notified=notified+1 end
P:Enable();assert(P.external==PTHealPredict and P.source=='Puppeteer' and table.getn(frames)==0)
assert(P:UnitGetIncomingHeals('target')==370) -- use provider total, not total plus direct
P:Heal('Other','Friend',1000,3000);assert(not next(P.pending))
local before=notified;listeners[1]('TargetGUID');assert(notified==before+1)
P:Disable();before=notified;listeners[1]('TargetGUID');assert(notified==before)
P:Enable();assert(table.getn(listeners)==1 and table.getn(frames)==0)
P:Disable();compatible=false;P:Enable()
assert(not P.external and P.source=='ClassicAPI + HealComm' and table.getn(frames)==1)
local driver=frames[1];assert(driver.events.COMBAT_LOG_EVENT_UNFILTERED)
compatible=true;event='PLAYER_ENTERING_WORLD';driver.scripts.OnEvent()
assert(P.external==PTHealPredict and not next(driver.events) and not driver.scripts.OnUpdate and table.getn(listeners)==1)
print('Shared Puppeteer: direct+HoT total once, no second driver, one callback, disabled guard, GUID compatibility and late activation passed')
