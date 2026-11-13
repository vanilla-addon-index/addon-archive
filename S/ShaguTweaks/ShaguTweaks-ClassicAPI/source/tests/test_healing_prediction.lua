local root=(arg[1] or '.')..'/'
local frames,modules={},{},{}
local methods={}
local function object()
 return setmetatable({scripts={},events={},visible=true,width=100,height=12},{__index=function(t,k) return methods[k] or function() end end})
end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:RegisterEvent(e) self.events[e]=true end
function methods:RegisterUnitEvent(e) self.events[e]=true end
function methods:UnregisterAllEvents() self.events={} end
function methods:CreateTexture() self.fill=object();return self.fill end
function methods:SetTexture(v) self.path=v end
function methods:GetTexture() return self.path end
function methods:GetStatusBarTexture() return {GetTexture=function() return 'HealthTexture' end} end
function methods:SetPoint(...) self.point=arg end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:IsVisible() return self.visible end
function methods:Hide() self.visible=false end
function methods:Show() self.visible=true end
function methods:SetValue() end
function methods:SetMinMaxValues() end
function methods:SetStatusBarTexture() end
CreateFrame=function() local f=object();table.insert(frames,f);return f end
PlayerFrameHealthBar=object();TargetFrameHealthBar=object()
local now=10;GetTime=function() return now end
local gear='Original robe'
GetInventoryItemLink=function(_,slot) if slot==5 then return gear end end
local names={player='Me',target='Friend'}
local current,max,dead,friendly=500,1000,false,true
UnitExists=function(u) return names[u]~=nil end
UnitName=function(u) return names[u] end
UnitIsDeadOrGhost=function() return dead end
UnitCanAssist=function() return friendly end
UnitIsUnit=function(a,b) return names[a]==names[b] end
UnitHealth=function() return current end;UnitHealthMax=function() return max end
UnitGUID=function(unit) return unit=='player' and 'PlayerGUID' or unit=='target' and 'FriendGUID' or unit=='party1' and 'HealerGUID' end
GetNumRaidMembers=function() return 0 end;GetNumPartyMembers=function() return 0 end
SendAddonMessage=function() error('Solo player must not broadcast') end
C_EventUtils={IsEventValid=function() return true end}
ShaguTweaks={GetGlobalEnv=function() return getfenv(0) end,T=setmetatable({},{__index=function(t,k) return k end}),API={}}
function ShaguTweaks:register(m) modules[m.title]=m;return m end
ShaguTweaks.API.UnitCastingInfo=function() return 'Heal','Heal','icon',10000,13000 end
ShaguTweaks.API.RegisterUnitEvent=function(f,e) f:RegisterEvent(e) end
function ShaguTweaks.hooksecurefunc(o,k,fn) local original=o[k];o[k]=function(self,...) original(self,unpack(arg));fn() end end
function ShaguTweaks.HookScript(f,k,fn) f.scripts[k]=fn end
dofile(root..'libs/libpredict.lua');local P=ShaguTweaks.libpredict
dofile(root..'mods/unitframes-healing-prediction.lua');local mod=modules['Healing Predictions']
assert(not mod.enabled and not P.enabled and table.getn(frames)==0)
mod:enable();local count=table.getn(frames)
local driver
for _,f in ipairs(frames) do if f.events.CHAT_MSG_ADDON then driver=f end end
P:ParseComm('Healer','Heal/Friend/200/3000/')
assert(P:UnitGetIncomingHeals('target')==200)
local fill=TargetFrameHealthBar.fill
assert(fill.visible and fill.width==20 and fill.point[4]==50)
P:ParseComm('Other','Heal/Friend/500/3000/');assert(fill.width==50) -- clamp overheal
P:ParseComm('Other','Healstop');assert(fill.width==20)
TargetFrameHealthBar.height=30;TargetFrameHealthBar.scripts.OnSizeChanged();assert(fill.height==30)
current=900;TargetFrameHealthBar:SetValue(900);assert(fill.width==10 and fill.point[4]==90)
current=1000;TargetFrameHealthBar:SetValue(1000);assert(not fill.visible)
current=500;max=100;TargetFrameHealthBar:SetValue(50);assert(not fill.visible)
max=1000;dead=true;TargetFrameHealthBar:SetValue(500);assert(not fill.visible)
dead=false;friendly=false;TargetFrameHealthBar:SetValue(500);assert(not fill.visible)
friendly=true;names.target='SomeoneElse';TargetFrameHealthBar:SetValue(500);assert(not fill.visible)
names.target='Friend';now=14;this=driver;arg1=.2;driver.scripts.OnUpdate();assert(not fill.visible and not driver.scripts.OnUpdate)
P:ParseComm('Healer','Heal/Friend/not-a-number/3000/');assert(not next(P.pending))
-- Learn own direct heal from the native payload, then predict the next cast.
event='COMBAT_LOG_EVENT_UNFILTERED';arg1=nil;arg2='SPELL_HEAL';arg4='PlayerGUID';arg12=123;arg15=250;arg18=false;driver.scripts.OnEvent()
now=10;event='UNIT_SPELLCAST_SENT';arg1='player';arg2='Friend';arg3='cast-1';arg4=123;driver.scripts.OnEvent()
event='UNIT_SPELLCAST_START';arg2='cast-1';arg3=123;driver.scripts.OnEvent();assert(P:UnitGetIncomingHeals('target')==250)
event='UNIT_SPELLCAST_INTERRUPTED';arg2='old-cast';driver.scripts.OnEvent();assert(P:UnitGetIncomingHeals('target')==250)
arg2='cast-1';driver.scripts.OnEvent();assert(P:UnitGetIncomingHeals('target')==0 and not fill.visible)
assert(not driver.events.SPELLS_CHANGED)
event='UNIT_SPELLCAST_SENT';arg1='player';arg2='Friend';arg3='cast-2';arg4=123;driver.scripts.OnEvent()
event='UNIT_SPELLCAST_START';arg2='cast-2';arg3=123;driver.scripts.OnEvent()
assert(P:UnitGetIncomingHeals('target')==250)
event='SPELLS_CHANGED';driver.scripts.OnEvent()
event='UNIT_INVENTORY_CHANGED';arg1='player';driver.scripts.OnEvent()
assert(P:UnitGetIncomingHeals('target')==250 and fill.visible) -- form-related notifications retain estimates
gear='Different robe';driver.scripts.OnEvent()
assert(P:UnitGetIncomingHeals('target')==0 and not fill.visible) -- actual gear change invalidates
event='UNIT_SPELLCAST_SENT';arg2='Friend';arg3='cast-3';arg4=123;driver.scripts.OnEvent()
event='UNIT_SPELLCAST_START';arg2='cast-3';arg3=123;driver.scripts.OnEvent()
assert(P:UnitGetIncomingHeals('target')==0) -- must learn again with different gear
P:Heal('Healer','Me',100,3000);assert(PlayerFrameHealthBar.fill.visible)
mod:disable();assert(not P.enabled and not PlayerFrameHealthBar.fill.visible and not next(driver.events) and not driver.scripts.OnUpdate)
mod:enable();assert(table.getn(frames)==count and not next(P.pending))
-- Standalone mode adds one upcoming tick for each live, identified HoT.
local auras={}
C_UnitAuras={UnitBuff=function(unit,index)
 local a=unit=='target' and auras[index]
 if a then return a.name,'icon',1,nil,a.duration,a.expires,a.source,nil,nil,a.spell end
end}
local function AuraChanged() event='UNIT_AURA';arg1='target';driver.scripts.OnEvent() end
local function Tick(source,spell,amount,critical)
 event='COMBAT_LOG_EVENT_UNFILTERED';arg2='SPELL_PERIODIC_HEAL';arg4=source;arg8='FriendGUID';arg12=spell;arg15=amount;arg18=critical
 driver.scripts.OnEvent()
end
now=10
auras[1]={name='Rejuvenation',duration=12,expires=22,source='player',spell=774}
AuraChanged();assert(P:UnitGetIncomingHeals('target')==0) -- no guessed amount before observation
now=13;Tick('PlayerGUID',774,50,false);assert(P:UnitGetIncomingHeals('target')==50 and fill.width==5)
auras[2]={name='Regrowth',duration=21,expires=31,source='player',spell=8936}
Tick('PlayerGUID',8936,20,false);assert(P:UnitGetIncomingHeals('target')==70)
P:Heal('Me','Friend',200,3000);assert(P:UnitGetIncomingHeals('target')==270)
P:HealStop('Me');assert(P:UnitGetIncomingHeals('target')==70) -- stopping cast leaves both HoTs
auras[1]=auras[2];auras[2]=nil;AuraChanged();assert(P:UnitGetIncomingHeals('target')==20)
now=32;arg1=.2;driver.scripts.OnUpdate();assert(not fill.visible and not driver.scripts.OnUpdate)
now=40
auras[1]={name='Rejuvenation',duration=12,expires=52,source='player',spell=774}
auras[2]={name='Rejuvenation',duration=12,expires=52,source='party1',spell=774}
AuraChanged();Tick('HealerGUID',774,80,false);assert(P:UnitGetIncomingHeals('target')==130)
AuraChanged();assert(P:UnitGetIncomingHeals('target')==130) -- refresh does not duplicate same aura
Tick('HealerGUID',774,160,true);assert(P:UnitGetIncomingHeals('target')==130) -- crit does not inflate next tick
gear='New robe';event='UNIT_INVENTORY_CHANGED';arg1='player';driver.scripts.OnEvent()
assert(P:UnitGetIncomingHeals('target')==80, tostring(P:UnitGetIncomingHeals('target'))) -- only own gear-dependent tick samples invalidated
auras={};AuraChanged();arg1=.2;if driver.scripts.OnUpdate then driver.scripts.OnUpdate() end
assert(P:UnitGetIncomingHeals('target')==0 and not fill.visible and not driver.scripts.OnUpdate)
-- Resource copies attach once and share the same estimator/events, including
-- when the native bar has been made transparent by resource hiding.
local copy=object();copy.width=200;copy.personalResourceDisplay=true
local before=table.getn(frames)
ShaguTweaks.RegisterHealingPredictionBar('player',copy)
local copyFill=copy.fill
ShaguTweaks.RegisterHealingPredictionBar('player',copy)
assert(copy.fill==copyFill and table.getn(frames)==before)
P:Heal('Healer','Me',200,3000)
assert(copyFill.visible and copyFill.width==40 and copyFill.path==1)
copy:SetWidth(300);copy:SetHeight(40)
assert(copyFill.width==60 and copyFill.height==40 and copyFill.point[4]==150)
mod:disable();assert(not copyFill.visible)
local late=object()
ShaguTweaks.RegisterHealingPredictionBar('player',late);assert(not rawget(late,'fill'))
ShaguTweaks.PersonalResourceDisplay={health={bar=late}}
mod:enable();assert(late.fill and table.getn(frames)==before)
mod:disable()
local file=assert(io.open(root..'main.lua'));local source=file:read('*a');file:close();assert(loadstring(source))
local first=assert(string.find(source,'  local prediction =',1,true))
local last=assert(string.find(source,'  -- Retire the removed duplicate toggle',first,true))
local migrate=assert(loadstring(string.sub(source,first,last-1)))
ShaguTweaks_config={['Enable Healing Prediction']=1};migrate();assert(ShaguTweaks_config['Healing Predictions']==1 and not ShaguTweaks_config['Enable Healing Prediction'])
ShaguTweaks_config={['Enable Healing Prediction on Unit Frames']=1,['Healing Predictions']=0};migrate();assert(ShaguTweaks_config['Healing Predictions']==0)
print('Healing prediction: dormant option, clamped geometry, Big Health sizing, target/death/hostility guards, HealComm/expiry, learned casts, form/gear changes, interrupt ownership and disable/re-enable passed')
