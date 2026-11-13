local root=(arg[1] or '.')..'/'
local f=assert(io.open(root..'mods/health-numbers.lua'));local s=f:read('*a');f:close();assert(loadstring(s))
local a=assert(string.find(s,'  local function AnchorHealth',1,true))
local b=assert(string.find(s,'  local function MatchNameStyle',a,true))
local anchor=assert(loadstring(string.sub(s,a,b-1)..'return AnchorHealth'))()
a=assert(string.find(s,'    local playerHealthY =',1,true))
b=assert(string.find(s,'    AnchorHealth(self.valueTexts.playerHealth',a,true))
local y=assert(loadstring(string.sub(s,a,b-1)..'return playerHealthY,targetHealthY'))
T=setmetatable({},{__index=function(t,k) return k end})
local height=30
PlayerFrameHealthBar={GetHeight=function() return height end}
TargetFrameHealthBar={GetHeight=function() return 30 end}
local function text()
 return {ClearAllPoints=function() end,SetJustifyH=function(self,v) self.justify=v end,
 SetPoint=function(self,...) self.point=arg end}
end
for _,displayEnabled in ipairs({0,1}) do
 ShaguTweaks_config={['Personal Resource Display']=displayEnabled}
 for _,h in ipairs({12,30}) do
  height=h;local py,ty=y()
  assert(py==((h==12) and .5 or -7) and ty==-7)
  local value=text();value.percentText=text()
  anchor(value,PlayerFrameHealthBar,py)
  assert(value.point[1]=='RIGHT' and value.point[4]==-4 and value.point[5]==py)
  assert(value.percentText.point[1]=='LEFT' and value.percentText.point[4]==4 and value.percentText.point[5]==py)
 end
end
print('Native health numbers: grouped alignment retained with independent resource display')
