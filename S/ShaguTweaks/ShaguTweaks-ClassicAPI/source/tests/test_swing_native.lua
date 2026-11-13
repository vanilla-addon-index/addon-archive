local root=(arg[1] or '.')..'/'
local function Check(native,methodAvailable,class)
 class=class or 'HUNTER'
 local now,keys=0,false
 local frames,modules,timers={},{},{}
 local methods={}
 local noop=function() end
 local function object(kind,name,parent)
  local f=setmetatable({scripts={},events={},shown=true,parent=parent,kind=kind},
   {__index=function(t,k) return methods[k] or (string.find(k,'^[A-Z]') and noop or nil) end})
  if kind=='StatusBar' and not methodAvailable then f.SetTimerDuration=false end
  if name then _G[name]=f end
  table.insert(frames,f);return f
 end
 function methods:RegisterEvent(name) self.events[name]=true end
 function methods:RegisterUnitEvent(name) self.events[name]=true end
 function methods:SetScript(name,callback) self.scripts[name]=callback end
 function methods:Show() self.shown=true end
 function methods:Hide() self.shown=false end
 function methods:IsShown() return self.shown end
 function methods:CreateTexture(_,layer)local t=object('Texture',nil,self);t.layer=layer;return t end
 function methods:CreateFontString() return object('FontString',nil,self) end
 function methods:SetText(value) self.text=value end
 function methods:SetStatusBarColor(...) self.color=arg end
 function methods:SetVertexColor(...) self.tint=arg end
 function methods:SetBackdropBorderColor(...) self.borderColor=arg end
 function methods:SetPoint(...) self.point=arg end
 function methods:GetStatusBarTexture() self.fill=self.fill or object('Texture');return self.fill end
 function methods:SetMinMaxValues(low,high) self.low,self.high=low,high;self.nativeTimer=nil end
 function methods:SetValue(value) self.value=value end
 function methods:SetTimerDuration(duration) self.nativeTimer=duration end
 function methods:ClearAllPoints() self.point=nil end
 function methods:GetLeft() return 20 end
 function methods:GetBottom() return 40 end
 CreateFrame=object
 UIParent=object('Frame');CastingBarFrame=object('StatusBar')
 GetTime=function() return now end
 UnitClass=function() return class,class end
 UnitAffectingCombat=function() return false end
 UnitAttackSpeed=function() return 2,2 end
 UnitRangedDamage=function() return 2 end
 GetInventoryItemTexture=function() return 'weapon' end
 C_Item={GetItemInventoryType=function() return 13 end}
 local swingType={MainHand=1,OffHand=2,Ranged=3}
 Enum={PlayerSwingType=swingType,StatusBarInterpolation={Immediate=0},StatusBarTimerDirection={ElapsedTime=0},NumericRuleFormatRounding={Down=0}}
 C_SwingTimer={EnableRangeCheck=noop,IsTargetWithinSwingRange=function() return true end}
 C_EventUtils={IsEventValid=function() return true end}
 local queued=false
 C_Spell={IsNextMeleeSpell=function(id) return id==6807 end,GetSpellName=function() return 'Maul' end}
 GetActionInfo=function(slot) if slot==1 then return 'spell',6807 end end
 IsCurrentAction=function(slot) return slot==1 and queued end
 C_Timer={NewTimer=function(delay,callback)
  local timer={at=now+delay,callback=callback,cancelled=false}
  function timer:Cancel() self.cancelled=true end
  table.insert(timers,timer);return timer
 end}
 C_DurationUtil={CreateDuration=function()
  local d={}
  function d:SetTimeFromEnd(finish,total) self.finish,self.total=finish,total end
  function d:GetRemainingDuration() return math.max(0,(self.finish or 0)-now) end
  return d
 end,CreateDurationTextBinding=function()
  local b={enabled=false}
  function b:SetFontString(text) self.text=text end
  function b:SetDuration(d) self.duration=d end
  function b:SetFormatter(formatter) self.formatter=formatter end
  function b:SetExpiredText(text) self.expired=text end
  function b:Enable() self.enabled=true end
  function b:Disable() self.enabled=false end
  return b
 end}
 C_StringUtil={CreateNumericRuleFormatter=function() return {AddBreakpoint=function(self,v) assert(v.step==.1);self.rule=v end} end}
 ShaguTweaks_config={}
 ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),GetGlobalEnv=function() return getfenv(0) end,
  API={durationtimers=native,AreMoveModifiersDown=function() return keys end}}
 if not native then C_DurationUtil.CreateDurationTextBinding=nil end
 dofile(root..'api.lua')
 ShaguTweaks.API.AreMoveModifiersDown=function() return keys end
 assert((ShaguTweaks.API.durationtimers and true or false)==native)
 function ShaguTweaks:register(m) modules[m.title]=m;return m end
 dofile(root..'mods/swing-timer.lua')
 modules['Swing Timer']:enable();modules['Wand Timer']:enable()
 local mh,oh,ra=ShaguTweaksSwingTimer_mainhand,ShaguTweaksSwingTimer_offhand,ShaguTweaksSwingTimer_ranged
 -- All timer variants, including previews created before the palette, use
 -- the same theme colors without changing the progress fill or weapon icon.
 for _,palette in ipairs({{r=.3,g=.3,b=.3,a=.9},{r=1,g=.78,b=.4,a=1},{r=1,g=1,b=1,a=1}})do
  ShaguTweaks.UITint=palette
  ShaguTweaks.UIBorder={r=palette.r*.8,g=palette.g*.8,b=palette.b*.8,a=palette.a}
  for _,bar in ipairs({mh,oh,ra})do
   local fill=bar.color
   this=bar;bar.scripts.OnShow();this=nil
   assert(bar.border.layer=='OVERLAY' and bar.border.tint[1]==palette.r and bar.border.tint[4]==palette.a)
   assert(bar.icon.borderColor[1]==palette.r*.8 and bar.icon.borderColor[4]==palette.a)
   assert(bar.color==fill and not bar.icon.texture.tint)
  end
 end
 ShaguTweaks.UITint,ShaguTweaks.UIBorder=nil,nil
 for _,bar in ipairs({mh,oh,ra})do
  this=bar;bar.scripts.OnShow();this=nil
  assert(bar.border.tint[1]==1 and bar.icon.borderColor[1]==1)
 end
 local listener,driver
 for _,frame in ipairs(frames) do
  if frame.events.PLAYER_SWING then listener=frame end
  if frame.scripts.OnUpdate then driver=frame end
 end
 local useNative=native and methodAvailable
 assert((driver==nil)==useNative)
 local function emit(name,a,b,c,d)
  event,arg1,arg2,arg3,arg4=name,a,b,c,d;listener.scripts.OnEvent()
 end
 local function advance(seconds)
  local finish=now+seconds
  while true do
   local nextTimer
   for _,timer in ipairs(timers) do
    if not timer.cancelled and timer.at<=finish and (not nextTimer or timer.at<nextTimer.at) then nextTimer=timer end
   end
   if not nextTimer then break end
   now=nextTimer.at;nextTimer.cancelled=true;nextTimer.callback()
  end
  now=finish
 end
 emit('PLAYER_REGEN_DISABLED');emit('START_AUTOATTACK')
 emit('PLAYER_SWING',1,1)
 assert(mh.active and mh:IsShown() and mh.max==2)
 if class=='DRUID' then
  assert(listener.events.ACTIONBAR_UPDATE_STATE)
  queued=true;emit('UNIT_SPELLCAST_SENT','player',nil,nil,6807)
  assert(mh.color[1]==1 and mh.color[2]==.55)
  queued=false;emit('ACTIONBAR_UPDATE_STATE')
  assert(mh.color[1]==1 and mh.color[2]==.7)
  queued=true;emit('UNIT_SPELLCAST_SENT','player',nil,nil,6807)
  emit('UNIT_SPELLCAST_FAILED','player',nil,6807);assert(mh.color[2]==.7)
  emit('PLAYER_DEAD');assert(not mh.active)
  return
 end
 if useNative then
  assert(mh.binding.enabled and mh.nativeTimer==mh.binding.duration and mh.duration.total==2)
  assert(mh.spark.point[2]==mh:GetStatusBarTexture())
  local first=mh.wake;emit('PLAYER_SWING',.8,1);assert(first.cancelled)
  advance(.8);assert(not mh.binding.enabled and mh.active and mh.text.text=='0.0')
  advance(.16);assert(mh.active) -- full while auto attack continues
  emit('STOP_AUTOATTACK');assert(not mh.active and not mh:IsShown())
  emit('START_AUTOREPEAT_SPELL');emit('PLAYER_SWING',2,3)
  assert(ra.color[1]==.3)
  advance(1.5);assert(ra.color[1]==1 and ra.color[2]==0)
  emit('PLAYER_SWING_RANGE_UPDATE',3,false,true);assert(ra.color[1]==.5)
  emit('PLAYER_SWING_RANGE_UPDATE',3,true,true)
  emit('PLAYER_SWING',2,1)
  keys=true;emit('MODIFIER_STATE_CHANGED')
  assert(not mh.binding.enabled and not mh.nativeTimer and mh.text.text=='Main Hand')
  advance(.2);assert(mh.text.text=='Main Hand')
  keys=false;emit('MODIFIER_STATE_CHANGED')
  assert(mh.binding.enabled and mh.nativeTimer and mh.spark.point[2]==mh:GetStatusBarTexture())
  emit('PLAYER_DEAD')
  assert(not mh.active and not ra.active and not mh.binding.enabled and not ra.binding.enabled)
  advance(5);assert(not mh.active and not ra.active)
  emit('START_AUTOREPEAT_SPELL');emit('PLAYER_SWING',.1,3)
  advance(.3);assert(ra.active);emit('STOP_AUTOREPEAT_SPELL');assert(not ra.active)
  for _,frame in ipairs(frames) do assert(not frame.scripts.OnUpdate) end
 else
  this=driver;arg1=.05;driver.scripts.OnUpdate();assert(mh.lastTenth==9)
  emit('PLAYER_DEAD');assert(not mh.active)
 end
end
Check(true,true);Check(false,true);Check(true,false)
Check(true,true,'DRUID')
print('Swing timers: native fill/text ownership, no Lua driver, reset cancellation, grace/stop, Hunter/range colors, preview suspension, death and older API/method fallbacks passed')
