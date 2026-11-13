local root=(arg[1] or '.')..'/'
local function Check(player,target)
 local mods,frames,hooks={},{},{}
 local methods={}
 local function obj() return setmetatable({height=12},{__index=methods}) end
 function methods:SetTexture(v) self.texture=v end
 function methods:SetHeight(v) self.height=v end
 function methods:SetPoint() end
 function methods:SetVertexColor() end
 function methods:GetVertexColor() return .2,.5,.8,0 end -- suppressed native name background
 function methods:GetTexCoord() return 0,0,0,1,1,0,1,1 end
 function methods:GetWidth() return 256 end
 function methods:SetWidth() end
 function methods:SetTexCoord() end
 function methods:Hide() self.hidden=true end
 function methods:SetScript(k,v) self[k]=v end
 function methods:RegisterEvent() end
 function methods:UnregisterAllEvents() end
 function methods:SetStatusBarColor(r,g,b,a) self.color={r,g,b,a} end
 for _,name in ipairs({'PlayerFrameTexture','PlayerStatusTexture','PlayerFrameHealthBar','PlayerFrameNameBackground','TargetFrameTexture','TargetFrameHealthBar','TargetFrameNameBackground'}) do _G[name]=obj() end
 ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),UITint={r=.5,g=.5,b=.5,a=1}}
 function ShaguTweaks:register(m) mods[m.title]=m;return m end
 hooksecurefunc=function(object,key,fn)
  if type(object)=='string' then hooks[object]=key
  else local original=object[key];object[key]=function(self,...) original(self,unpack(arg));fn(self,unpack(arg)) end end
 end
 GetAddOnInfo=function() return nil end
 IsResting=function() return false end
 UnitClassification=function() return 'elite' end
 TargetFrame_CheckFaction=function() end
 CreateFrame=function() local f=obj();table.insert(frames,f);return f end
 dofile(root..'mods/unitframes-bighealth.lua')
 assert(not mods['Unit Frame Big Health'])
 if player then mods['Unit Frame Big Health for Player']:enable() end
 if target then mods['Unit Frame Big Health for Target']:enable() end
 for _,f in ipairs(frames) do if f.OnUpdate then this=f;f.OnUpdate() end end
 assert(PlayerFrameHealthBar.height==(player and 30 or 12))
 assert(TargetFrameHealthBar.height==(target and 30 or 12))
 assert((PlayerFrameNameBackground.hidden or false)==player)
 assert((TargetFrameNameBackground.hidden or false)==target)
 assert((hooks.PlayerFrame_UpdateStatus~=nil)==player)
 assert((hooks.TargetFrame_CheckClassification~=nil)==target)
 if player then
  PlayerFrameHealthBar:SetStatusBarColor(1,0,0,1) -- health loss triggers native recoloring
  assert(PlayerFrameHealthBar.color[1]==.2 and PlayerFrameHealthBar.color[4]==1)
 end
 if target then assert(TargetFrameHealthBar.color[4]==1) end
end
Check(false,false);Check(true,false);Check(false,true);Check(true,true)
local f=assert(io.open(root..'main.lua'));local s=f:read('*a');f:close();assert(loadstring(s))
local a=assert(string.find(s,'  local oldBigHealth =',1,true))
local b=assert(string.find(s,'  -- initialize overwrites',a,true))
local migrate=assert(loadstring(string.sub(s,a,b-1)))
ShaguTweaks_config={['Unit Frame Big Health']=1};migrate()
assert(ShaguTweaks_config['Unit Frame Big Health for Player']==1 and ShaguTweaks_config['Unit Frame Big Health for Target']==1)
ShaguTweaks_config={['Unit Frame Big Health']=1,['Unit Frame Big Health for Player']=0};migrate()
assert(ShaguTweaks_config['Unit Frame Big Health for Player']==0 and not ShaguTweaks_config['Unit Frame Big Health'])
print('Big Health: all four option combinations, independent artwork/hooks and old-setting migration passed')
