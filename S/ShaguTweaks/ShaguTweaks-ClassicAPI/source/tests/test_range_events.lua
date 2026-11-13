local root=(arg[1] or '.')..'/'
local refs,frames,hooks={},{},{}
local function button(name,slot)
 local b={slot=slot,visible=true,scripts={}}
 function b:IsVisible() return self.visible end
 function b:GetName() return name end
 _G[name]=b;_G[name..'Icon']={SetVertexColor=function(self,...) self.color=arg end}
 return b
end
local main=button('ActionButton1',1);local other=button('MultiBarBottomLeftButton1',1)
CreateFrame=function() local f={events={},RegisterEvent=function(self,e) self.events[e]=true end,SetScript=function(self,k,v) self[k]=v end};table.insert(frames,f);return f end
local module
ShaguTweaks={API={eventutils=true},T=setmetatable({},{__index=function(t,k) return k end}),GetGlobalEnv=function() return getfenv(0) end}
function ShaguTweaks:register(m) module=m;return m end
function ShaguTweaks.hooksecurefunc(name,fn) hooks[name]=fn end
function ShaguTweaks.HookScript(b,k,fn) b.scripts[k]=fn end
C_EventUtils={IsEventValid=function() return true end}
C_ActionBar={EnableActionRangeCheck=function(slot,on) refs[slot]=(refs[slot] or 0)+(on and 1 or -1);assert(refs[slot]>=0) end}
local helpful,assist,usable,mana=false,true,true,false
C_Spell={IsSpellHelpful=function() return helpful end,IsSpellHarmful=function() return false end}
UnitCanAssist=function() return assist end;UnitCanAttack=function() return true end
ShaguTweaks.API.GetActionInfo=function(slot) return slot==2 and 'macro' or 'spell',123 end
ActionButton_GetPagedID=function(b) return b.slot end
IsUsableAction=function() return usable,mana end
dofile(root..'mods/actionbar-range-color.lua')
assert(not next(hooks))
module:enable();assert(not hooks.ActionButton_OnUpdate and refs[1]==2)
local listener=frames[1]
local function eventRange(slot,inRange,checks) event='ACTION_RANGE_CHECK_UPDATE';arg1,arg2,arg3=slot,inRange,checks;listener.OnEvent() end
eventRange(1,false,true);assert(ActionButton1Icon.color[1]==.85 and MultiBarBottomLeftButton1Icon.color[1]==.85)
this=main;hooks.ActionButton_UpdateUsable();assert(ActionButton1Icon.color[1]==.85)
helpful=true;assist=false;eventRange(1,false,true);assert(ActionButton1Icon.color[1]==1)
helpful=false;assist=true;usable=false;mana=true;eventRange(1,true,true);assert(ActionButton1Icon.color[3]==1 and ActionButton1Icon.color[1]==.5)
usable=true;mana=false
main.slot=2;this=main;hooks.ActionButton_Update();assert(refs[1]==1 and refs[2]==1)
eventRange(2,false,true);assert(ActionButton1Icon.color[1]==.85)
event='PLAYER_TARGET_CHANGED';listener.OnEvent();assert(ActionButton1Icon.color[1]==.85) -- unchanged native results need no new event
eventRange(2,false,false);assert(ActionButton1Icon.color[1]==1)
main.visible=false;this=main;main.scripts.OnHide();assert(refs[2]==0)
main.visible=true;main.scripts.OnShow();assert(refs[2]==1)
for i=1,10 do hooks.ActionButton_Update() end;assert(refs[2]==1)
-- Older supported ClassicAPI keeps the existing throttled path.
C_ActionBar=nil;hooks={};module:enable();assert(hooks.ActionButton_OnUpdate)
print('Range events: native refs, duplicate slots, page/hide/show, unchanged state, faction/mana tint and old-version fallback passed')
