local root=(arg[1] or '.') .. '/'
assert(loadfile(root..'mods/unitframes-classcolor.lua'))
local modules={}
ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end})}
function ShaguTweaks.GetGlobalEnv() return _G end
function ShaguTweaks:register(module) modules[module.title]=module; return module end
function ShaguTweaks.hooksecurefunc(object,name,callback)
 if type(object)=='string' then
  local original=_G[object]
  _G[object]=function(...) original(unpack(arg));name(unpack(arg)) end
  return
 end
 local original=object[name]; object[name]=function(self,a,b,c,d) original(self,a,b,c,d); callback(self,a,b,c,d) end
end
MAX_PARTY_MEMBERS=0
local deferred
function CreateFrame() return {SetScript=function(self,event,callback) if callback then deferred={frame=self,callback=callback} end end,Hide=function() end} end
function UnitClass() return 'Warlock','WARLOCK' end
function TargetFrame_CheckFaction() end
local function texture()
 return {SetTexture=function(self,p) self.path=p end,SetVertexColor=function(self,r,g,b,a) self.r=r end}
end
PlayerFrameNameBackground=texture(); TargetFrameNameBackground=texture()
PlayerFrameHealthBar={SetStatusBarTexture=function(self,p) self.path=p end,GetStatusBarColor=function() return 1,1,1,1 end,SetStatusBarColor=function() end}
dofile(root..'mods/unitframes-classcolor.lua')
modules['Modern Class Colors']:enable()
this=deferred.frame; deferred.callback(); this=nil
local expected='Interface\\AddOns\\ShaguTweaks\\img\\BlizzardRetailBar'
assert(PlayerFrameNameBackground.path==expected and TargetFrameNameBackground.path==expected and PlayerFrameHealthBar.path==expected)
print('Lua 5.0: matching modern name/health artwork passed')

local function healthBar()
 return { SetStatusBarColor=function(self,r,g,b) self.color={r,g,b} end }
end
local units={player='WARLOCK', pet='WARRIOR', party1='HUNTER', partypet1='WARRIOR'}
function UnitClass(unit) return units[unit],units[unit] end
local targetUnit
function UnitExists(unit) return units[unit=='target' and targetUnit or unit]~=nil end
function UnitIsUnit(first,second) return first=='target' and targetUnit==second end
function UnitIsPlayer(unit) return unit=='party1' end
function UnitIsPet(unit) return unit=='target' and targetUnit=='remotePet' end
function UnitOwnerGUID() return 'owner-guid' end
ShaguTweaks.API={UnitTokenFromGUID=function(guid) if guid=='owner-guid' then return 'party1' end end}
PetFrameHealthBar=healthBar()
PartyMemberFrame1PetFrameHealthBar=healthBar()
TargetFrameHealthBar=healthBar()
TargetFrameHealthBar:SetStatusBarColor(0,1,0)
function TargetFrameHealthBar:GetStatusBarColor() return unpack(self.color) end
MAX_PARTY_MEMBERS=1
local scripts={}
function CreateFrame() return {RegisterEvent=function() end, SetScript=function(_,k,v) scripts[k]=v end} end
modules['Pets Use Owner Class Color']:enable()
assert(PetFrameHealthBar.color[3]==.93 and PartyMemberFrame1PetFrameHealthBar.color[1]==.67)
PetFrameHealthBar:SetStatusBarColor(0,1,0)
assert(PetFrameHealthBar.color[3]==.93)
targetUnit='pet';TargetFrame_CheckFaction()
assert(TargetFrameHealthBar.color[3]==.93)
-- Big Health captures the setter and applies the faction tint through it.
local bigHealthSetter=TargetFrameHealthBar.SetStatusBarColor
bigHealthSetter(TargetFrameHealthBar,0,0,1,1)
assert(TargetFrameHealthBar.color[3]==.93)
targetUnit='partypet1';TargetFrame_CheckFaction()
assert(TargetFrameHealthBar.color[1]==.67)
units.remotePet='WARRIOR'
targetUnit='remotePet';TargetFrame_CheckFaction()
assert(TargetFrameHealthBar.color[1]==.67)
TargetFrameHealthBar:SetStatusBarColor(0,1,0)
units.npc='WARRIOR'
targetUnit='npc';TargetFrame_CheckFaction()
assert(TargetFrameHealthBar.color[2]==1 and TargetFrameHealthBar.color[3]==0)
units.party1='WARLOCK'
event,arg1='UNIT_PET','party1';scripts.OnEvent()
assert(PartyMemberFrame1PetFrameHealthBar.color[3]==.93)
units.partypet1=nil
PartyMemberFrame1PetFrameHealthBar:SetStatusBarColor(0,1,0)
assert(PartyMemberFrame1PetFrameHealthBar.color[2]==1)

function UnitReaction() return 5 end
function UnitIsPlayer() return false end
local name={GetFont=function() return 'font',12 end, SetFont=function() end}
PlayerFrame={name=name,CreateTexture=function()
 local strip=texture()
 strip.SetWidth=function() end;strip.SetHeight=function() end;strip.SetPoint=function() end
 strip.Hide=function(self) self.hidden=true end
 return strip
end}
TargetFrame={name=name}
TargetFrameNameBackground.Hide=function() end
for _,hide in ipairs({0,1}) do
 ShaguTweaks_config={["Player's Name No Class Color"]=hide}
 modules['Unit Frame Class Colors']:enable()
 assert((PlayerFrameNameBackground.hidden or false)==(hide==1))
 assert(PlayerFrameNameBackground.r==.53)
end
print('Player name and pet options: hidden name strip keeps its class tint for Big Health, pet bars follow their owners')

-- Hiding the player name never affects the grouped player frame.
dofile(root..'mods/unitframes-hide-player-name.lua')
local nameHidden=false
ShaguTweaks.PlayerFrameResourcesLayout={name={Hide=function() nameHidden=true end}}
ShaguTweaks_config={['Hide Player Frame Resources']=0}
modules['Hide Player Name']:enable();assert(not nameHidden)
ShaguTweaks_config['Hide Player Frame Resources']=1
modules['Hide Player Name']:enable();assert(nameHidden)
print('Hide Player Name: hide-resources guard passed')
-- Removed options must not be loaded or retain saved switches.
local file=assert(io.open(root..'ShaguTweaks.toc'));local toc=file:read('*a');file:close()
assert(not string.find(toc,'unitframes-hide-player-portrait.lua',1,true))
assert(not string.find(toc,'unitframes-standalone-player.lua',1,true))
file=assert(io.open(root..'main.lua'));local source=file:read('*a');file:close()
local first=assert(string.find(source,'  -- Gold numbers belong',1,true))
local last=assert(string.find(source,'  -- Split the former shared setting',first,true))
local retire=assert(loadstring(string.sub(source,first,last-1)))
ShaguTweaks_config={['Hide Player Portrait']=1,['Unit Frame Health Colors']=1,
 ['Hide Player Frame Resources']=1,['Personal Resource Display']=1}
retire()
assert(not ShaguTweaks_config['Hide Player Portrait'] and not ShaguTweaks_config['Unit Frame Health Colors'])
assert(ShaguTweaks_config['Hide Player Frame Resources']==1 and ShaguTweaks_config['Personal Resource Display']==1)
print('Removed player options: absent from manifest and saved toggles retired without changing current options')
