local root=(arg[1] or '.')..'/'
local function Check(native)
 local now,power,mode,combat=0,80,0,false
 local timers,modules={},{}
 local methods={}
 local function noop() end
 local function frame(kind)
  return setmetatable({shown=true,scripts={},events={},height=12}, {__index=function(t,k)
   return methods[k] or (string.find(k,'^[A-Z]') and noop or nil)
  end})
 end
 function methods:SetScript(k,v) self.scripts[k]=v end
 function methods:GetScript(k) return self.scripts[k] end
 function methods:RegisterEvent(k) self.events[k]=true end
 function methods:GetHeight() return self.height end
 function methods:SetHeight(v) self.height=v end
 function methods:SetWidth(v) self.width=v end
 function methods:IsShown() return self.shown end
 function methods:IsVisible() return self.shown end
 function methods:GetValue() return self.value or 80 end
 function methods:Show() local changed=not self.shown;self.shown=true;if changed and self.scripts.OnShow then self.scripts.OnShow() end end
 function methods:Hide() local changed=self.shown;self.shown=false;if changed and self.scripts.OnHide then self.scripts.OnHide() end end
 function methods:CreateTexture() return frame('Texture') end
 function methods:GetStatusBarTexture() self.fill=self.fill or frame('Texture');return self.fill end
 function methods:SetTimerDuration(duration) self.nativeDuration=duration end
 function methods:SetValue(v) self.value=v end
 CreateFrame=frame;PlayerFrameManaBar=frame('StatusBar')
 UnitPowerType=function() return mode end
 UnitMana=function() return power end
 UnitManaMax=function() return 100 end
 UnitAffectingCombat=function() return combat end
 GetTime=function() return now end
 C_DurationUtil={CreateDuration=function() return {SetTimeFromStart=function(self,start,duration) self.start,self.duration=start,duration end} end}
 C_Timer={NewTimer=function(delay,callback)
  local t={at=now+delay,callback=callback};function t:Cancel() self.cancelled=true end
  table.insert(timers,t);return t
 end}
 Enum={StatusBarInterpolation={Immediate=0},StatusBarTimerDirection={ElapsedTime=0}}
 C_Spell={GetSpellPowerCost=function(id) return {{type=0,cost=id==1 and 10 or 0}} end}
 ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),GetGlobalEnv=function() return getfenv(0) end,
  API={durationtimers=native,RegisterUnitEvent=function(f,name,unit) assert(unit=='player');f:RegisterEvent(name) end}}
 if native then
  ShaguTweaks.API.GetSpellInfo=function(id) return 'Spell','Rank 1','icon',id==1 and 10 or 0,false,0 end
  C_Spell.GetSpellPowerCost=function() error('Use positional spell metadata without allocating a cost table') end
 end
 function ShaguTweaks:register(m) modules[m.title]=m;return m end
 function ShaguTweaks.hooksecurefunc(o,k,callback)
  local original=o[k]
  o[k]=function(self,a,b,c) original(self,a,b,c);callback(self,a,b,c) end
 end
 function ShaguTweaks.HookScript(f,k,callback)
  local old=f:GetScript(k);f:SetScript(k,function() if old then old() end;callback() end)
 end
 dofile(root..'mods/unitframes-energy-tick.lua')
 local module=modules['Unit Frame Energy & Mana Tick'];module:enable();local tick=module.tick
 module:enable();assert(module.tick==tick)
 local function emit(name,unit,id) event,arg1,arg3=name,unit,id;tick.scripts.OnEvent() end
 emit('PLAYER_ENTERING_WORLD',true);assert(tick.mode==0 and tick.lastPower==80)
 power=70;emit('UNIT_MANA','target');assert(tick.lastPower==80)
 emit('UNIT_MANA','player');assert(not tick.ruleEnd) -- drain is not an FSR cast
 now=1;power=80;emit('UNIT_MANA','player');assert(tick.phase==1 and tick.period==2)
 local resource=frame('StatusBar');resource.height=24
 local count=table.getn(timers)
 ShaguTweaks.RegisterResourceTickBar(resource)
 local copy=module.resourceTick
 ShaguTweaks.RegisterResourceTickBar(resource);assert(module.resourceTick==copy)
 assert(table.getn(timers)==count and not next(copy.events) and not copy.scripts.OnUpdate)
 assert(copy.spark:IsShown() and copy.spark.height==34)
 resource.height=40;resource.scripts.OnSizeChanged();assert(copy.spark.height==50)
 now=1.8;power=85;emit('UNIT_MANA','player');assert(tick.phase==1) -- mid-period proc
 emit('UNIT_SPELLCAST_SUCCEEDED','player',2);assert(not tick.ruleEnd) -- free cast
 emit('UNIT_SPELLCAST_SUCCEEDED','player',1);assert(tick.ruleEnd==6.8 and tick.period==5)
 now=2;mode=3;power=40;emit('UNIT_DISPLAYPOWER','player')
 assert(tick.lastPower==40 and not tick.phase and not tick.spark:IsShown())
 now=3;power=60;emit('UNIT_ENERGY','player');assert(tick.phase==3 and tick.period==2)
 mode=0;power=75;emit('UNIT_DISPLAYPOWER','player');assert(tick.lastPower==75 and not tick.phase)
 now=4;local finish=tick.ruleEnd;emit('UNIT_SPELLCAST_CHANNEL_STOP','player',999);assert(tick.ruleEnd==finish)
 emit('UNIT_SPELLCAST_CHANNEL_STOP','player',1);assert(tick.ruleEnd==9)
 PlayerFrameManaBar.height=30;PlayerFrameManaBar.scripts.OnSizeChanged();assert(tick.spark.height==40 and tick.spark.width==34)
 local old=tick.wake
 power=100;combat=false;emit('UNIT_MANA','player');assert(not tick:IsShown())
 assert(not copy:IsShown())
 if old then assert(old.cancelled) end
 if native then assert(not tick.scripts.OnUpdate and tick.nativeDuration)
 else assert(tick.scripts.OnUpdate) end
 mode=3;power=50;emit('UNIT_DISPLAYPOWER','player')
 now=10;power=70;emit('UNIT_ENERGY','player')
 now=10.5
 if native then assert(tick.nativeDuration.start==10 and tick.nativeDuration.duration==2)
 else tick.scripts.OnUpdate();assert(tick.value==.25) end
 assert(copy:IsShown() and copy.spark:IsShown())
 if native then assert(copy.nativeDuration==tick.nativeDuration) else assert(copy.value==tick.value) end
 -- A late wake catches up to the observed clock, not to now (no phase drift).
 if native then now=14.2;tick.wake.callback();assert(tick.start==14) end
 local manaParent,manaSource=frame('StatusBar'),frame('StatusBar')
 ShaguTweaks.RegisterDruidManaTickBar(manaParent,manaSource)
 local manaTick=module.druidTick
 now=16;manaSource:SetValue(90)
 if native then assert(manaTick.nativeDuration.start==16 and manaTick.nativeDuration.duration==2)
 else now=16.5;manaTick.scripts.OnUpdate();assert(manaTick.value==.25) end
 manaParent:Hide();assert(not manaTick.scripts.OnUpdate)
end
Check(true);Check(false)
print('Energy/mana tick: login booleans, unit filtering, form samples, cast-only FSR/channel ownership, proc phase rejection, native/fallback sweep, sizing and idle cancellation passed')
