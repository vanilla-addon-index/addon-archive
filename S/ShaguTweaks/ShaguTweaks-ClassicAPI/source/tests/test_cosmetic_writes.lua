local root=(arg[1] or '.')..'/'
local env=setmetatable({},{__index=getfenv(0)});env._G=env
local partyCalls,frames,partyNames=0,{}, {'Alice','Bob'}
local function texture(path)
 local t={path=path,writes=0,tints=0}
 function t:GetTexture()return self.path end
 function t:SetTexture(p)self.path=p;self.writes=self.writes+1 end
 function t:SetVertexColor(r,g,b)self.r,self.g,self.b=r,g,b;self.tints=self.tints+1 end
 function t:SetPoint()end
 return t
end
env.GetAddOnInfo=function()return nil,'ShaguTweaks' end
env.UnitExists=function()return true end
env.UnitName=function(unit)
 local _,_,id=string.find(unit,'party(%d)')
 if id then partyCalls=partyCalls+1;return partyNames[tonumber(id)]end
 return 'Remote'
end
env.UnitClass=function()return 'Mage','MAGE' end
env.RAID_CLASS_COLORS={WARLOCK={r=.5,g=.5,b=.9},MAGE={r=.2,g=.8,b=.9}}
env.WorldMapFrame={}
env.CreateFrame=function()
 local f={scripts={}}
 function f:SetScript(k,v)self.scripts[k]=v end
 function f:RegisterEvent()end
 function f:UnregisterEvent()self.unregistered=true end
 table.insert(frames,f);return f
end
env.ShaguTweaks={T={},GetGlobalEnv=function()return env end,GetUnitData=function()return 'WARLOCK' end}
function env.ShaguTweaks:register(m)env.module=m;return m end
for i,name in ipairs({'Alice','Other','Third'})do
 local f={name=name,frameName='WorldMapRaid'..i}
 function f:GetName()return self.frameName end
 function f:IsVisible()return self.visible~=false end
 function f:CreateTexture()return texture()end
 env[f.frameName]=f;env[f.frameName..'Icon']=texture('native')
end
local chunk=assert(loadfile(root..'mods/worldmap-colors.lua'));setfenv(chunk,env);chunk();env.module:enable()
local updater=frames[1]
local function tick()env.this,env.arg1=updater,.1;updater.scripts.OnUpdate()end
tick();assert(partyCalls==4,'party roster should be read once, not once per visible icon')
assert(env.WorldMapRaid1.texture.ingroup=='PARTY' and env.WorldMapRaid2.texture.ingroup=='RAID')
for i=1,3 do assert(env['WorldMapRaid'..i].texture.tints==1 and env['WorldMapRaid'..i..'Icon'].writes==1)end
tick();assert(partyCalls==8)
for i=1,3 do assert(env['WorldMapRaid'..i].texture.tints==1 and env['WorldMapRaid'..i..'Icon'].writes==1)end
partyNames={};tick();assert(env.WorldMapRaid1.texture.ingroup=='RAID')
env.WorldMapRaid2.name=nil;env.WorldMapRaid2.unit='raid10';tick()
assert(env.WorldMapRaid2.texture.r==.2,'packed map icons must use their actual unit')
env.WorldMapRaid2Icon.path='native again';tick();assert(env.WorldMapRaid2Icon.writes==2)
for i=1,3 do env['WorldMapRaid'..i].visible=false end
local before=partyCalls;tick();assert(partyCalls==before,'solo/empty maps should not query party names')
env.BattlefieldMinimap={};env.this=frames[2];frames[2].scripts.OnEvent();assert(frames[2].unregistered)

-- Exercise the actual spam cache helpers while retaining the table identities.
local f=assert(io.open(root..'mods/chat-spam-filter.lua'));local source=f:read('*a');f:close()
local a=assert(string.find(source,'local COOLDOWN =',1,true))
local b=assert(string.find(source,'-- SuperWoW exposes',a,true))
local now=0
env.GetTime=function()return now end
env.API={}
chunk=assert(loadstring(string.sub(source,a,b-1)..'return IsDuplicate, cache'))
setfenv(chunk,env);local duplicate,cache=chunk()
local tab1,tab2={},{}
assert(not duplicate(tab1,'repeat') and duplicate(tab1,'repeat'))
assert(not duplicate(tab2,'repeat'),'each chat tab has an independent cache')
local original=cache[tab1]
now=31;assert(not duplicate(tab1,'new') and cache[tab1]==original)
now=61;assert(duplicate(tab1,'repeat') and cache[tab1]==original)
now=70;assert(not duplicate(tab1,'repeat'),'duplicates must not extend their original 70s window')
now=101;assert(not duplicate(tab1,'later') and not original.new and not cache[tab2])
assert(cache[tab1]==original,'pruning must retain the active per-tab table')
print('Cosmetic/cache writes: four party-name lookups per map pass, stable tint/icon writes skipped, live roster/unit/native changes retained, in-place spam pruning and per-tab cooldowns passed')
