local root=(arg[1] or '.')..'/'
local function read(path)local f=assert(io.open(root..path));local s=f:read('*a');f:close();return s end
local function Check(native)
 local env=setmetatable({},{__index=getfenv(0)});env._G=env
 local frames,modules,timers,queue={},{},{},{}
 local now,cast,channel,selfTarget,queries=10,nil,nil,false,0
 local keys,remote=false,nil
 local methods={}
 local function object(kind,name,parent)
  local f=setmetatable({kind=kind,name=name,parent=parent,scripts={},events={},shown=true,width=140,alpha=1},
   {__index=function(_,key)return methods[key] or (string.find(key,'^[A-Z]') and function()end or nil)end})
  table.insert(frames,f);if name then env[name]=f end;return f
 end
 function methods:SetScript(k,v)self.scripts[k]=v end
 function methods:GetScript(k)return self.scripts[k]end
 function methods:RegisterEvent(k)self.events[k]=true end
 function methods:Hide()self.shown=false end
 function methods:Show()self.shown=true end
 function methods:IsShown()return self.shown end
 function methods:SetPoint(...)self.point=arg end
 function methods:ClearAllPoints()self.point=nil end
 function methods:GetFont()return 'font',12,'' end
 function methods:GetAlpha()return self.alpha end
 function methods:SetAlpha(a)self.alpha=a end
 function methods:SetWidth(w)self.width=w end
 function methods:GetWidth()return self.width end
 function methods:GetHeight()return 10 end
 function methods:GetEffectiveScale()return 1 end
 function methods:SetTexture(t)self.path=t end
 function methods:SetText(t)self.text=t end
 function methods:SetVertexColor(...)self.tint=arg end
 function methods:SetBackdropBorderColor(...)self.rim=arg end
 function methods:SetMinMaxValues(a,b)self.low,self.high=a,b;self.timer=nil end
 function methods:SetValue(v)self.value=v;self.writes=(self.writes or 0)+1 end
 function methods:SetTimerDuration(d,_,direction)self.timer,self.direction=d,direction end
 function methods:GetStatusBarTexture()if not self.fill then self.fill=object('Texture')end;return self.fill end
 function methods:CreateTexture()return object('Texture')end
 function methods:CreateFontString()return object('FontString')end
 env.CreateFrame=object
 env.UIParent=object('Frame');env.TargetFrame=object('Frame');env.TargetofTargetFrame=object('Frame')
 env.TargetFrameBuff1=object('Texture');env.TargetFrameBuff1:Hide()
 env.TargetofTargetFrame:Hide()
 env.CastingBarFrame=object('StatusBar');env.CastingBarText=object('FontString')
 env.GetTime=function()return now end
 env.UnitExists=function()return true end
 env.UnitIsUnit=function(a,b)return a==b or selfTarget and ((a=='target' and b=='player') or (b=='target' and a=='player'))end
 env.Enum={StatusBarInterpolation={Immediate=0},StatusBarTimerDirection={ElapsedTime=0,RemainingTime=1}}
 env.C_EventUtils={IsEventValid=function()return true end}
 env.C_Timer={NewTimer=function(delay,callback)
  local t={at=now+delay,callback=callback};function t:Cancel()self.cancelled=true end
  table.insert(timers,t);return t
 end}
 env.C_DurationUtil={CreateDuration=function()
  local d={}
  function d:SetTimeSpan(a,b)self.start,self.finish=a,b end
  function d:GetStartTime()return self.start end
  function d:GetEndTime()return self.finish end
  return d
 end,CreateDurationTextBinding=function()
  local b={};function b:SetFontString(v)self.text=v end
  function b:SetFormatter(v)self.formatter=v end
  function b:SetExpiredText(v)self.expired=v end
  function b:SetDuration(v)self.duration=v end
  function b:Enable()self.enabled=true end
  function b:Disable()self.enabled=false end
  return b
 end}
 env.C_StringUtil={CreateNumericRuleFormatter=function()return {AddBreakpoint=function(self,v)self.rule=v end}end}
 local suppliedDuration
 env.UnitCastingDuration=function()return suppliedDuration end
 env.UnitChannelDuration=env.UnitCastingDuration
 env.ShaguTweaks={T=setmetatable({},{__index=function(_,k)return k end}),API={durationtimers=native,casts=true,eventutils=true,timer=true},
  libcast={db={}},GetGlobalEnv=function()return env end}
 env.ShaguTweaks.UnitCastingInfo=function()
  if remote then return 'Remote','','','remote',remote.start*1000,remote.finish*1000 end
 end
 function env.ShaguTweaks:register(m)modules[m.title]=m;return m end
 env.ShaguTweaks.HookScript=function(frame,name,callback)
  local original=frame.scripts[name];frame.scripts[name]=function()if original then original()end;callback()end
 end
 env.ShaguTweaks.QueueFunction=function(callback)table.insert(queue,callback)end
 local API=env.ShaguTweaks.API
 API.Defer=env.ShaguTweaks.QueueFunction
 API.RegisterUnitEvent=function(f,e,a,b)f.events[e]={a,b}end
 API.AreMoveModifiersDown=function()return keys end
 API.UnitGUID=function()return 'guid' end
 API.GetCastInfo=function()queries=queries+1;if cast then return cast.name or 'Cast','','','icon',cast.start*1000,cast.finish*1000 end end
 API.GetChannelInfo=function()if channel then return 'Channel','','','icon',channel.start*1000,channel.finish*1000 end end
 local src=read('api.lua');local a=assert(string.find(src,'API.GetCastDuration = function',1,true));local b=assert(string.find(src,'API.IsSpellInRange =',a,true))
 local helper=assert(loadstring('local API=ShaguTweaks.API;local _G=ShaguTweaks.GetGlobalEnv();'..string.sub(src,a,b-1)));setfenv(helper,env);helper()
 local function load(path)local fn=assert(loadfile(root..path));setfenv(fn,env);fn()end
 load('mods/target-castbar.lua');modules['Enemy Castbars']:enable()
 load('mods/improved-castbar.lua');modules['Improved Castbar']:enable()
 local target,player=env.ShaguTargetCastbar,env.STImprovedCastbar
 assert(player.timerText.point[1]=='LEFT' and player.timerText.point[2]==env.CastingBarFrame
  and player.timerText.point[3]=='RIGHT' and player.timerText.point[4]>0,
  'player countdown is outside the right edge for both timer paths')
 local function emit(name,unit)
  env.event,env.arg1=name,unit
  for _,frame in ipairs(frames)do if frame.events[name] and frame.scripts.OnEvent then env.this=frame;frame.scripts.OnEvent()end end
  env.this=nil
 end
 local function runQueue()local work=queue;queue={};for _,fn in ipairs(work)do fn()end end
 cast={start=9,finish=15}
 suppliedDuration=env.C_DurationUtil.CreateDuration();suppliedDuration:SetTimeSpan(9,15)
 emit('UNIT_SPELLCAST_START','target');emit('UNIT_SPELLCAST_START','player')
 assert(target.shown and player.shown)
 if native then
  assert(target.timer==suppliedDuration and target.direction==0 and not target.scripts.OnUpdate)
  assert(target.spark.point[2]==target:GetStatusBarTexture())
  assert(player.timerBinding.enabled and player.timerBinding.duration==suppliedDuration and not player.scripts.OnUpdate)
  assert(player.timerBinding.formatter.rule.format=='%.1fs')
  assert(env.CastingBarFrame.timer==nil,'player native fill/fade must remain untouched')
  local old=target.expiry
  -- Pushback replaces the snapshot and cancels the previous expiry.
  cast.finish=17;emit('UNIT_SPELLCAST_DELAYED','target');emit('UNIT_SPELLCAST_DELAYED','player')
  assert(old.cancelled and target.timer.finish==17 and player.timerBinding.duration.finish==17)
  assert(suppliedDuration.finish==15,'a mismatched engine snapshot must not be mutated')
  local fallback=target.fallbackDuration
  cast=nil;suppliedDuration=nil;channel={start=10,finish=18};emit('UNIT_SPELLCAST_CHANNEL_START','target');emit('UNIT_SPELLCAST_CHANNEL_START','player')
  assert(target.direction==1 and target.fallbackDuration==fallback and player.timerBinding.enabled)
  channel.finish=16;emit('UNIT_SPELLCAST_CHANNEL_UPDATE','target');assert(target.timer.finish==16)
  -- Aura layout work coalesces; animation does not query casts or write values.
  emit('UNIT_AURA','target');emit('UNIT_AURA','target');assert(table.getn(queue)==1);runQueue()
  env.TargetofTargetFrame:Show();env.TargetofTargetFrame.scripts.OnShow();runQueue();assert(target.positionY==-24)
  local activeTimer=target.timer
  env.ShaguTweaks.UITint={r=1,g=.78,b=.4,a=1};env.ShaguTweaks.UIBorder={r=.8,g=.62,b=.32,a=1}
  keys=true;emit('MODIFIER_STATE_CHANGED');assert(env.ShaguTweaksTargetCastBarMover.shown and target.timer==activeTimer)
  assert(env.ShaguTweaksTargetCastBarMover.border.tint[2]==.78 and env.ShaguTweaksTargetCastBarMover.icon.rim[1]==.8)
  keys=false;emit('MODIFIER_STATE_CHANGED');assert(not env.ShaguTweaksTargetCastBarMover.shown)
  local before=queries;now=11;assert(queries==before and not target.writes)
  -- Cancel/stop clears target immediately, retaining player text for native fade.
  channel=nil;emit('UNIT_SPELLCAST_INTERRUPTED','target');emit('UNIT_SPELLCAST_STOP','player')
  assert(not target.shown and not target.timer and not player.timerBinding.enabled and player.shown)
  env.CastingBarFrame.scripts.OnHide();assert(not player.shown)
  -- Missing STOP still expires; replacement casts cannot be hidden by old timers.
  cast={start=11,finish=15};emit('UNIT_SPELLCAST_START','target');local expiry=target.expiry
  cast.finish=19;emit('UNIT_SPELLCAST_DELAYED','target');assert(expiry.cancelled)
  now=19;target.expiry.callback();assert(not target.shown and not target.timer)
  -- Player-only events refresh a self-target; unrelated player casts do not.
  now=20;cast={start=20,finish=25};selfTarget=true;emit('UNIT_SPELLCAST_START','player');assert(target.shown)
  cast=nil;emit('UNIT_SPELLCAST_STOP','player');assert(not target.shown)
  selfTarget=false;cast={start=20,finish=25};emit('UNIT_SPELLCAST_START','player');assert(not target.shown)
  cast=nil;emit('PLAYER_TARGET_CHANGED');assert(not target.shown)
  -- Complete remote timing still uses the optional GUID cache complement.
  env.ShaguTweaks.superwow_active=true;env.ShaguTweaks.libcast.db.guid={cast='Remote'}
  remote={start=20,finish=26};env.ShaguTweaks.libcast.OnRemoteChanged('guid')
  assert(target.shown and target.timer.finish==26 and target.text.text=='Remote')
  remote=nil;env.ShaguTweaks.libcast.db.guid=nil;env.ShaguTweaks.libcast.OnRemoteChanged('guid')
  assert(not target.shown)
 else
  assert(target.scripts.OnUpdate and player.scripts.OnUpdate and not player.timerBinding)
  env.this=target;target.scripts.OnUpdate();assert(target.value==1)
  env.this=player;env.arg1=.1;player.scripts.OnUpdate();assert(player.timerText.text=='5.0s')
 end
end
Check(true);Check(false)
print('Castbars: native snapshot/fallback durations, fill/spark/text ownership, delay/channel replacement, cancellation/expiry, player fade, self-target routing and older API animation passed')
