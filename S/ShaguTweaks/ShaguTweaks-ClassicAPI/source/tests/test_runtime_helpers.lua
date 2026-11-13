local root=(arg[1] or '.')..'/'
local pending,frames={},{}
CreateFrame=function()
 local f={scripts={},events={},shown=true}
 function f:RegisterEvent(name) self.events[name]=true end
 function f:UnregisterAllEvents() self.events={} end
 function f:SetScript(name,callback) self.scripts[name]=callback end
 function f:Show() self.shown=true end
 function f:Hide() self.shown=false end
 table.insert(frames,f);return f
end
C_Timer={After=function(delay,callback) assert(delay==0);table.insert(pending,callback) end}
ShaguTweaks={GetGlobalEnv=function() return getfenv(0) end}
dofile(root..'api.lua')
local API=ShaguTweaks.API
-- All eight merged-key combinations, then left/right ClassicAPI state with
-- conflicting vanilla keys: native state must win.
local shift,control,alt=false,false,false
IsShiftKeyDown=function() return shift end
IsControlKeyDown=function() return control end
IsAltKeyDown=function() return alt end
for s=0,1 do for c=0,1 do for a=0,1 do
 shift,control,alt=s==1,c==1,a==1
 assert(API.AreMoveModifiersDown()==(shift and control and alt))
end end end
API.modifierkeys=true
local left,right={false,false,false},{false,false,false}
IsLeftShiftKeyDown=function() return left[1] end
IsRightShiftKeyDown=function() return right[1] end
IsLeftControlKeyDown=function() return left[2] end
IsRightControlKeyDown=function() return right[2] end
IsLeftAltKeyDown=function() return left[3] end
IsRightAltKeyDown=function() return right[3] end
assert(not API.AreMoveModifiersDown())
left[1],right[2],left[3]=true,true,true
assert(API.AreMoveModifiersDown())
left[3]=false;assert(not API.AreMoveModifiersDown())
right[3]=true;assert(API.AreMoveModifiersDown())
local function idle(f)
 assert(not next(f.events) and not f.scripts.OnEvent and not f.scripts.OnUpdate and not f.shown)
end
local count=0
local function callback() count=count+1 end
-- Independent requests wait through world entry and first update, then each
-- receives exactly one native deferred callback. Idle drivers retain no scripts.
local first=API.AfterWorldReady(callback)
local second=API.AfterWorldReady(callback,true)
assert(count==0 and first.events.PLAYER_ENTERING_WORLD and not first.scripts.OnUpdate)
first.scripts.OnEvent();second.scripts.OnEvent();assert(count==0)
first.scripts.OnUpdate();second.scripts.OnUpdate()
idle(first);idle(second);assert(count==0 and table.getn(pending)==2)
pending[1]();pending[2]();assert(count==2)
API.timer=false
first=API.AfterWorldReady(callback);second=API.AfterWorldReady(callback,true)
first.scripts.OnEvent();second.scripts.OnEvent()
first.scripts.OnUpdate();idle(first);assert(count==3)
second.scripts.OnUpdate();assert(count==3 and second.shown and second.scripts.OnUpdate)
second.scripts.OnUpdate();idle(second);assert(count==4)
print('Runtime helpers: modifier combinations/native left-right precedence, independent one-shot startup timing, fallback extra frame and idle cleanup passed')
