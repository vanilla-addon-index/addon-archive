local root=(arg[1] or '.')..'/'
local env=setmetatable({},{__index=getfenv(0)});env._G=env
local modules,hooks,frames,power,queries={},{},{},{player=0,target=0,party1=0},{}
local function texture(path)
 local t={path=path,shown=true,coords={0,0,0,1,1,0,1,1},writes=0,crops=0}
 function t:GetTexture()return self.path end
 function t:SetTexture(path)self.path=path;self.writes=self.writes+1 end
 function t:GetTexCoord()return unpack(self.coords)end
 function t:SetTexCoord(l,r,top,bottom)self.coords={l,top,l,bottom,r,top,r,bottom};self.crops=self.crops+1 end
 function t:SetAllPoints()end
 function t:IsShown()return self.shown end
 function t:Show()self.shown=true end
 function t:Hide()self.shown=false end
 return t
end
local function bar(unit)
 local f={unit=unit,fill=texture('original'),color={.2,.3,.4,1},writes=0}
 function f:GetStatusBarTexture()return self.fill end
 function f:SetStatusBarTexture(path)self.fill:SetTexture(path)end
 function f:GetStatusBarColor()return unpack(self.color)end
 function f:SetStatusBarColor(r,g,b,a)self.color={r,g,b,a};self.writes=self.writes+1 end
 function f:CreateTexture()return texture()end
 return f
end
env.PlayerFrameManaBar=bar('player');env.PlayerFrameAlternatePowerBar=bar('player')
env.TargetFrameManaBar=bar('target');env.PartyMemberFrame1ManaBar=bar('party1')
env.MAX_PARTY_MEMBERS=1
env.UnitExists=function(unit)queries[unit]=(queries[unit] or 0)+1;return true end
env.UnitPowerType=function(unit)return power[unit] or 0 end
env.UnitClass=function(unit)return 'Druid','DRUID' end
env.CreateFrame=function()
 local f={scripts={}}
 function f:SetScript(k,v)self.scripts[k]=v end
 function f:RegisterEvent()end
 function f:Hide()end
 table.insert(frames,f);return f
end
env.ShaguTweaks={T=setmetatable({},{__index=function(_,k)return k end}),API={},GetGlobalEnv=function()return env end}
function env.ShaguTweaks:register(m)modules[m.title]=m;return m end
env.ShaguTweaks.hooksecurefunc=function(obj,name,callback)
 if type(obj)=='string' then hooks[obj]=name;return end
 local old=obj[name];obj[name]=function(self,r,g,b,a)old(self,r,g,b,a);callback(self,r,g,b,a)end
end
local function load(path)local f=assert(loadfile(root..path));setfenv(f,env);f()end
load('mods/unitframes-classcolor.lua');modules['Modern Class Colors']:enable()
local player,alt,target,party=env.PlayerFrameManaBar,env.PlayerFrameAlternatePowerBar,env.TargetFrameManaBar,env.PartyMemberFrame1ManaBar
local function reset()
 queries={}
 for _,f in ipairs({player,alt,target,party})do f.writes=0;f.fill.writes=0 end
end
reset();hooks.UnitFrame_UpdateManaType({unit='target',manabar=target})
assert(queries.target==1 and not queries.player and not queries.party1)
assert(target.fill.writes==0 and target.writes==0,'unchanged styles must not repeat texture/tint writes')
-- Native overwrites are corrected even though the cached style key is stable.
target.fill.path='native';target.color={0,0,1,1};hooks.UnitFrame_UpdateManaType({manabar=target})
assert(target.fill.writes==1 and target.writes==1 and target.color[1]==1)
reset();target:SetStatusBarColor(.5,.5,.5,1)
assert(target.writes==2 and not queries.player and not queries.party1)
reset();target.color={.999997,.999997,.999997,.999997};hooks.UnitFrame_UpdateManaType(target)
assert(target.writes==0,'packed native white should not trigger repeated corrective writes')
-- A player form change updates the primary and fixed-mana secondary bar only.
reset();power.player=3;hooks.UnitFrame_UpdateManaType({unit='player'})
assert(queries.player==2 and not queries.target and not queries.party1)
assert(string.find(player.fill.path,'ModernPowerEnergyClass',1,true))
assert(string.find(alt.fill.path,'ModernPowerManaClass',1,true))
reset();hooks.UnitFrame_UpdateManaType({unit='raid40'});assert(not next(queries))
env.this={manabar=party};hooks.UnitFrame_UpdateManaType('party1');env.this=nil
assert(queries.party1==1 and not queries.player)
power.target=7;reset();hooks.UnitFrame_UpdateManaType(target);assert(target.fill.path=='original')
hooks.UnitFrame_UpdateManaType(target);assert(target.fill.writes==1)
-- Keep the explicit full startup refresh after other modules initialize.
reset();env.this=frames[1];frames[1].scripts.OnUpdate();env.this=nil
assert(queries.player==2 and queries.target==1 and queries.party1==1)

local classQueries,players,selfTarget={}, {},false
env.GetAddOnInfo=function()return 'ShaguTweaks','ShaguTweaks' end
env.UnitClass=function(unit)classQueries[unit]=(classQueries[unit] or 0)+1;return 'Druid','DRUID' end
env.UnitIsPlayer=function(unit)return players[unit]~=false end
env.UnitIsUnit=function(a,b)return a==b or selfTarget and ((a=='player' and b=='target')or(a=='target' and b=='player'))end
env.TargetofTarget_OnUpdate=function()end
env.ShaguTweaks.API.UnitGUID=function(unit)return unit..'guid' end
env.PlayerFrame={unit='player',portrait=texture('portrait')}
env.TargetFrame={unit='target',portrait=texture('portrait')}
env.TargetofTargetFrame={unit='targettarget',portrait=texture('portrait')}
for i=1,4 do env['PartyMemberFrame'..i]={unit='party'..i,portrait=texture('portrait')}end
load('mods/unitframes-classportrait.lua');modules['Unit Frame Class Portraits']:enable()
local events=frames[table.getn(frames)]
local function emit(name,unit)
 classQueries={};env.event,env.arg1=name,unit;events.scripts.OnEvent()
end
emit('PLAYER_ENTERING_WORLD')
assert(classQueries.player==1 and classQueries.target==1 and classQueries.party4==1)
emit('UNIT_PORTRAIT_UPDATE','party2');assert(classQueries.party2==1 and not classQueries.player and not classQueries.target)
local portrait=env.PartyMemberFrame2.portrait;local writes,crops=portrait.writes,portrait.crops
emit('UNIT_PORTRAIT_UPDATE','party2');assert(portrait.writes==writes and portrait.crops==crops)
emit('UNIT_PORTRAIT_UPDATE','raid40');assert(not next(classQueries))
selfTarget=true;emit('UNIT_PORTRAIT_UPDATE','player');assert(classQueries.player==1 and classQueries.target==1)
local tf=env.TargetFrame;tf.portrait.path='native';tf.portrait.coords={0,0,0,1,1,0,1,1}
hooks.UnitFrame_Update(tf);assert(string.find(tf.portrait.path,'UI-Classes-Circles',1,true))
tf.portrait.path='native';env.this=tf;hooks.UnitFrame_Update('target');env.this=nil
assert(string.find(tf.portrait.path,'UI-Classes-Circles',1,true))
players.target=false;tf.portrait.path='npc';hooks.UnitFrame_Update(tf)
assert(tf.portrait.path=='npc' and tf.portrait.coords[1]==0 and tf.portrait.coords[5]==1)
env.TargetofTarget_OnUpdate(.3)
assert(string.find(env.TargetofTargetFrame.portrait.path,'UI-Classes-Circles',1,true))
print('Unit-frame styling: affected power/portrait routing, startup refreshes, fixed druid mana, stable keys/live overwrite correction, packed-white tolerance, aliases and native hook contexts passed')
