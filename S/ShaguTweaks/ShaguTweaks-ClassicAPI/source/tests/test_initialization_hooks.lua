local root=(arg[1] or '.')..'/'
local file=assert(io.open(root..'helpers.lua'));local source=file:read('*a');file:close()
assert(loadstring(source))
local first=assert(string.find(source,'-- One event listener for deferred',1,true))
local last=assert(string.find(source,'ShaguTweaks.hooksecurefunc =',first,true))
local frames,loaded,checks,errors={},{},{},{}
ShaguTweaks={}
function CreateFrame()
 local frame={events={},scripts={}}
 function frame:RegisterEvent(e) self.events[e]=true end
 function frame:UnregisterAllEvents() self.events={} end
 function frame:SetScript(k,v) self.scripts[k]=v end
 table.insert(frames,frame);return frame
end
function IsAddOnLoaded(name) checks[name]=(checks[name] or 0)+1;return loaded[name] end
function geterrorhandler() return function(message) table.insert(errors,message) end end
local chunk=assert(loadstring('local _G=getfenv(0)\n'..string.sub(source,first,last-1)))
chunk()
assert(table.getn(frames)==0)
local hook=ShaguTweaks.HookAddonOrVariable
local calls={}
local function emit(name,payload)
 local oldThis,oldEvent,oldArg=this,event,arg1
 this,event,arg1=frames[1],name,payload
 frames[1].scripts.OnEvent()
 assert(this==frames[1] and event==name and arg1==payload)
 this,event,arg1=oldThis,oldEvent,oldArg
end
loaded.Already=true
hook('Already',function(frame)
 assert(frame==this and frame.func and event=='ADDON_LOADED' and arg1=='Payload')
 table.insert(calls,'first');arg1='changed';event='changed';this=nil
 hook('Nested',function() table.insert(calls,'nested') end)
 -- Reentrant events may not drain/overwrite the active callback snapshot.
 emit('ADDON_LOADED','Inner')
end)
hook('Already',function() assert(arg1=='Payload');table.insert(calls,'second') end)
_G.ExistingGlobal={}
hook('ExistingGlobal',function() table.insert(calls,'global') end)
hook('Missing',function() table.insert(calls,'missing') end)
loaded.Nested=true
assert(table.getn(frames)==1 and table.getn(calls)==0 and not frames[1].scripts.OnUpdate)
emit('ADDON_LOADED','Payload')
assert(table.concat(calls,',')=='first,second,global')
assert(checks.Already==1 and checks.ExistingGlobal==1 and checks.Missing==1)
emit('VARIABLES_LOADED')
assert(calls[4]=='nested' and frames[1].events.ADDON_LOADED)
loaded.Missing=true
emit('PLAYER_ENTERING_WORLD')
assert(calls[5]=='missing' and not next(frames[1].events))
emit('ADDON_LOADED');assert(table.getn(calls)==5)
-- Reactivate the same listener; one failed callback must not block the next.
hook('Already',function() error('expected initialization failure') end)
hook('Already',function() table.insert(calls,'after-error') end)
assert(frames[1].events.VARIABLES_LOADED and table.getn(frames)==1)
emit('ADDON_LOADED')
assert(table.getn(errors)==1 and calls[6]=='after-error' and not next(frames[1].events))
emit('ADDON_LOADED');assert(table.getn(errors)==1 and table.getn(calls)==6)
-- Global truthiness preserves the old contract, including numeric zero.
_G.LaterGlobal=false;hook('LaterGlobal',function() table.insert(calls,'later') end)
emit('VARIABLES_LOADED');assert(table.getn(calls)==6)
_G.LaterGlobal=0;emit('PLAYER_ENTERING_WORLD');assert(calls[7]=='later')
assert(not next(frames[1].events) and table.getn(frames)==1)
print('Initialization hooks: one lazy listener, deferred readiness, deduplicated checks, ordered callbacks, nested/reentrant registration, context, error isolation, teardown and rearming passed')
