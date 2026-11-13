local root=(arg[1] or '.')..'/'
local function Check(native)
 local env=setmetatable({},{__index=getfenv(0)});env._G=env
 local modules,frames,timers,slots,effects={},{},{},{},{}
 local now,keys,totemReads,effectReads,schoolReads=10,false,0,0,0
 local methods={}
 local function object(kind,name,parent)
  local f=setmetatable({kind=kind,parent=parent,scripts={},events={},shown=true,writes=0},
   {__index=function(_,key)return methods[key] or (string.find(key,'^[A-Z]') and function()end or nil)end})
  table.insert(frames,f);if name then env[name]=f end;return f
 end
 function methods:RegisterEvent(name)self.events[name]=true end
 function methods:UnregisterAllEvents()self.events={}end
 function methods:SetScript(k,v)self.scripts[k]=v end
 function methods:Show()self.shown=true end
 function methods:Hide()self.shown=false end
 function methods:IsShown()return self.shown end
 function methods:CreateTexture()return object('Texture',nil,self)end
 function methods:CreateFontString()return object('FontString',nil,self)end
 function methods:SetTexture(path)self.path=path;self.writes=self.writes+1 end
 function methods:SetText(text)self.text=text;self.writes=self.writes+1 end
 function methods:SetTextColor(...)self.textColor=arg end
 function methods:SetStatusBarColor(...)self.color=arg end
 function methods:SetVertexColor(...)self.color=arg end
 function methods:SetWidth(n)self.width=n end
 function methods:SetStatusBarTexture(p)self.path=p end
 function methods:SetMinMaxValues()self.timer=nil end
 function methods:SetValue(v)self.value=v end
 function methods:SetTimerDuration(d,_,direction)self.timer,self.direction=d,direction end
 env.CreateFrame=object;env.UIParent=object('Frame')
 env.SlashCmdList={};env.ShaguTweaks_config={}
 env.GetTime=function()return now end
 env.UnitClass=function()return 'Shaman','SHAMAN' end
 env.GameTooltip={Hide=function()end,SetOwner=function()end,SetTotem=function()end}
 env.Enum={StatusBarInterpolation={Immediate=0},StatusBarTimerDirection={RemainingTime=1},NumericRuleFormatRounding={Down=2}}
 env.C_Timer={NewTimer=function(delay,fn)
  local t={at=now+delay,callback=fn};function t:Cancel()self.cancelled=true end
  table.insert(timers,t);return t
 end}
 env.C_DurationUtil={CreateDuration=function()
  local d={finish=0,total=0}
  function d:SetTimeFromEnd(finish,total)self.finish,self.total=finish,total end
  function d:GetRemainingDuration()return math.max(0,self.finish-now)end
  return d
 end,CreateDurationTextBinding=function()
  local b={}
  function b:SetFontString(text)self.text=text end
  function b:SetDuration(d)self.duration=d end
  function b:SetFormatter(f)self.formatter=f end
  function b:SetExpiredText(t)self.expired=t end
  function b:SetUpdateInterval(t)self.interval=t end
  function b:Enable()self.enabled=true end
  function b:Disable()self.enabled=false end
  return b
 end}
 env.C_StringUtil={CreateNumericRuleFormatter=function()return {SetBreakpoints=function(self,rules)self.rules=rules end}end}
 env.GetTotemInfo=function(slot)
  local data=slots[slot]
  if data then return true,'Totem',data.start,data.total,'icon' end
  return false,'',0,0,''
 end
 env.GetTotemTimeLeft=function(slot)totemReads=totemReads+1;local s=slots[slot];return s and math.max(0,s.start+s.total-now)or 0 end
 env.GetTotemDuration=function(slot)
  local d=env.C_DurationUtil.CreateDuration();local s=slots[slot]
  if s then d:SetTimeFromEnd(s.start+s.total,s.total)end
  return d
 end
 env.C_LossOfControl={GetActiveLossOfControlDataCount=function()effectReads=effectReads+1;return table.getn(effects)end,
 GetActiveLossOfControlData=function(i)
  local e=effects[i]
  return {locType=e.kind,timeRemaining=e.finish and math.max(0,e.finish-now),duration=e.total,
   displayText=e.label or e.kind,lockoutSchool=e.mask or 0,iconTexture='effect'}
 end,GetSchoolLockout=function()
  schoolReads=schoolReads+1;local mask,left=0,0
  for _,e in ipairs(effects)do if e.kind=='SCHOOL_INTERRUPT' and e.finish>now then mask=e.mask;left=math.max(left,e.finish-now)end end
  return mask,mask~=0 and left or nil
 end}
 env.C_Spell={GetSchoolString=function()return 'Nature' end}
 env.ShaguTweaks={T=setmetatable({},{__index=function(_,k)return k end}),
  API={durationtimers=native,AreMoveModifiersDown=function()return keys end},GetGlobalEnv=function()return env end}
 function env.ShaguTweaks:register(m)modules[m.title]=m;return m end
 local function load(path)local f=assert(loadfile(root..path));setfenv(f,env);f()end
 local function emit(name)
  env.event=name
  for _,f in ipairs(frames)do if f.events[name]then env.this=f;f.scripts.OnEvent()end end
  env.this=nil
 end
 local function advance(delta)
  local finish=now+delta
  for iteration=1,1000 do
   local nextTimer
   for _,t in ipairs(timers)do
    if not t.cancelled and not t.fired and t.at<=finish and (not nextTimer or t.at<nextTimer.at)then nextTimer=t end
   end
   if not nextTimer then now=finish;return end
   now=nextTimer.at;nextTimer.fired=true;nextTimer.callback()
  end
  error('timer loop')
 end
 slots[1]={start=9,total=30};slots[3]={start=9,total=60}
 load('mods/totem-timers.lua');modules['Totem Timers']:enable()
 local totem=env.ShaguTweaksTotem1;local holder=env.ShaguTweaksTotemTimers
 local function formatted(formatter,n)
  local rule
  for _,candidate in ipairs(formatter.rules)do if n>=candidate.threshold then rule=candidate end end
  local function rounded(v,step,mode)
   if not step then return v end
   return (mode==2 and math.floor(v/step) or math.floor(v/step+.5))*step
  end
  n=rounded(n,rule.step,rule.rounding)
  if rule.components then
   local values={}
   for _,part in ipairs(rule.components)do
    local v=n;if part.div then v=v/part.div end;if part.mod then v=math.mod(v,part.mod)end
    table.insert(values,rounded(v,part.step,part.rounding))
   end
   return string.format(rule.format,unpack(values))
  end
  return string.format(rule.format,n)
 end
 if native then
  assert(not holder.scripts.OnUpdate and totem.binding.enabled and totem.bar.timer.total==30 and totem.bar.direction==1)
  assert(totem.binding.formatter==env.ShaguTweaksTotem3.binding.formatter)
  assert(totem.binding.formatter.rules[4].format=='|cffffffff%d:%02d')
  assert(formatted(totem.binding.formatter,5)=='|cffff33335')
  assert(formatted(totem.binding.formatter,5.001)=='|cffffe6335')
  assert(formatted(totem.binding.formatter,10)=='|cffffe63310')
  assert(formatted(totem.binding.formatter,10.001)=='|cffffffff10')
  assert(formatted(totem.binding.formatter,61.9)=='|cffffffff1:01')
  local original=totem.expiry;slots[1]={start=10,total=60};emit('PLAYER_TOTEM_UPDATE')
  assert(original.cancelled and totem.bar.timer.finish==70)
  local oldTimer=totem.expiry;keys=true;emit('MODIFIER_STATE_CHANGED')
  assert(oldTimer.cancelled and not totem.binding.enabled and totem.bar.value==1)
  keys=false;emit('MODIFIER_STATE_CHANGED');assert(totem.binding.enabled)
  local before=totemReads;advance(61);assert(totemReads==before and not holder.shown)
  assert(not totem.binding.enabled and not totem.shown)
  slots[2]={start=now,total=30};emit('PLAYER_TOTEM_UPDATE')
  local earth=env.ShaguTweaksTotem2;local pending=earth.expiry
  modules['Totem Timers']:disable();assert(pending.cancelled and not earth.binding.enabled)
  modules['Totem Timers']:enable();assert(earth.binding.enabled)
 else
  assert(holder.scripts.OnUpdate and not totem.binding)
  assert(totem.time.text=='29')
  now=36;env.arg1=.1;holder.scripts.OnUpdate();assert(totem.time.text=='3' and totem.time.textColor[2]==.2)
 end
 modules['Totem Timers']:disable()
 effects={{kind='ROOT',finish=now+20,total=20},{kind='STUN',finish=now+4,total=4}}
 load('mods/loss-of-control.lua');modules['Loss of Control Alert']:enable()
 local alert=env.ShaguTweaksLossOfControl
 assert(alert.title.text=='Stunned')
 if native then
  assert(not alert.scripts.OnUpdate and alert.bar.timer.total==4)
  local before=effectReads;local writes=alert.icon.writes
  advance(2);assert(effectReads==before and alert.icon.writes==writes,'native animation must not rescan/repaint')
  advance(2.1);assert(alert.title.text=='Rooted' and alert.shown)
  effects={};emit('LOSS_OF_CONTROL_UPDATE');assert(not alert.shown)
  effects={{kind='STUN'}};emit('LOSS_OF_CONTROL_UPDATE')
  assert(alert.shown and alert.time.text=='' and not alert.bar.shown)
  keys=true;emit('MODIFIER_STATE_CHANGED');assert(alert.time.text=='8.0' and alert.bar.value==1)
  keys=false;emit('MODIFIER_STATE_CHANGED');assert(alert.time.text=='' and alert.shown)
  effects={{kind='SCHOOL_INTERRUPT',mask=8,finish=now+6,total=6}}
  emit('LOSS_OF_CONTROL_UPDATE');local listReads=effectReads;advance(.4)
  assert(effectReads==listReads and schoolReads>0,'steady lockouts use scalar queries only')
  local oldEnd=alert.bar.timer.finish
  effects[1].finish=now+10;effects[1].total=10
  advance(.3);assert(alert.bar.timer.finish>oldEnd and effectReads>listReads)
  local scalarQuery=env.C_LossOfControl.GetSchoolLockout
  env.C_LossOfControl.GetSchoolLockout=nil
  listReads=effectReads;advance(.3);assert(effectReads>listReads,'older scalar-less API must still detect extensions')
  env.C_LossOfControl.GetSchoolLockout=scalarQuery
  advance(6);assert(alert.shown,'old expiry must not hide the extended lockout')
  local beforeDisable=effectReads
  modules['Loss of Control Alert']:disable();advance(20)
  assert(not alert.shown and effectReads==beforeDisable)
  modules['Loss of Control Alert']:enable();assert(not alert.shown)
  -- A higher-priority newly applied effect replaces the lockout immediately.
  effects={{kind='ROOT',finish=now+10,total=10}};emit('LOSS_OF_CONTROL_UPDATE')
  table.insert(effects,{kind='FEAR',finish=now+3,total=3});emit('LOSS_OF_CONTROL_ADDED')
  assert(alert.title.text=='Feared');advance(3.1);assert(alert.title.text=='Rooted')
 else
  assert(alert.scripts.OnUpdate and alert.time.text=='4.0')
  env.arg1=.05;alert.scripts.OnUpdate();assert(alert.title.text=='Stunned')
 end
 modules['Loss of Control Alert']:disable()
end
Check(true);Check(false)
print('Control timers: native totem fill/text/expiry, replacements, preview/disable cleanup, loss-of-control priority/untimed effects, school extension scalar checks and older API fallback passed')
