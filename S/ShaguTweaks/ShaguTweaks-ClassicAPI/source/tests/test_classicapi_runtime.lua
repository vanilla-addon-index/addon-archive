local root=(arg[1] or '.')..'/'
local f=assert(io.open(root..'api.lua'));local source=f:read('*a');f:close();assert(loadstring(source))
local a=assert(string.find(source,'API.minimum_version =',1,true))
local b=assert(string.find(source,'API.classicapi =',a,true))
local API={}
API=assert(loadstring('local _G=getfenv(0);local API={};'..string.sub(source,a,b-1)..'return API'))()
CLASSIC_API_VERSION=11810
C_Timer={After=function() end};C_EventUtils={IsEventValid=function() return true end}
C_NamePlate={GetNamePlateForUnit=function() end}
assert(API.IsSupportedRuntime())
CLASSIC_API_VERSION=11809;assert(not API.IsSupportedRuntime())
CLASSIC_API_VERSION=nil;assert(not API.IsSupportedRuntime())
CLASSIC_API_VERSION=11900;assert(API.IsSupportedRuntime())
C_NamePlate=nil;assert(not API.IsSupportedRuntime())
C_NamePlate={GetNamePlateForUnit=function() end}
local frames,scans={},0
CreateFrame=function()
 local f={scripts={},events={}}
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:GetScript(k) return self.scripts[k] end
 function f:RegisterEvent(k) self.events[k]=true end
 table.insert(frames,f);return f
end
WorldFrame={GetNumChildren=function() scans=scans+1;return 0 end,GetChildren=function() end}
ShaguTweaks={API=API,GetGlobalEnv=function() return getfenv(0) end,GetExpansion=function() return 'vanilla' end}
API.nameplateevents=true
dofile(root..'libs/libnameplate.lua')
local lib=ShaguTweaks.libnameplate
lib:EnableIfNeeded();assert(not lib.enabled and scans==0)
table.insert(lib.OnInit,function() end)
CLASSIC_API_VERSION=0;lib:EnableIfNeeded();assert(not lib.enabled)
CLASSIC_API_VERSION=11810;lib:EnableIfNeeded();assert(lib.enabled and not lib.scripts.OnUpdate and scans==0)
local driver,retry
for _,frame in ipairs(frames) do
 if frame.events.NAME_PLATE_UNIT_ADDED then driver=frame end
 if frame.scripts.OnUpdate then retry=frame end
end
assert(driver and retry)
this=retry;retry.scripts.OnUpdate();assert(scans==1 and not retry.scripts.OnUpdate)
driver.scripts.OnEvent();driver.scripts.OnEvent();assert(scans==1)
this=retry;retry.scripts.OnUpdate();assert(scans==2 and not retry.scripts.OnUpdate)
print('ClassicAPI runtime: minimum/missing APIs, dormant nameplate discovery and deferred event coalescing passed')
