local root=(arg[1] or '.')..'/'
assert(loadfile(root..'mods/cooldown-numbers.lua'))
local function read(path)local f=assert(io.open(root..path));local s=f:read('*a');f:close();return s end
local helpers=read('helpers.lua')
local a=assert(string.find(helpers,'ShaguTweaks.TimeConvert = function',1,true))
local b=assert(string.find(helpers,'\nend',a,true))
local reference={ShaguTweaks={},ceil=math.ceil}
setmetatable(reference,{__index=getfenv(0)})
local chunk=assert(loadstring(string.sub(helpers,a,b+3)));setfenv(chunk,reference);chunk()
local env=setmetatable({},{__index=getfenv(0)});env._G=env
local frames,formatted,cvar,now={},0,'1',101
local nativeFactory
local function newFrame(parent)
 local f={parent=parent,scripts={},visible=true,alpha=1}
 function f:GetParent()return self.parent end
 function f:GetHeight()return self.height or 36 end
 function f:GetFrameLevel()return 4 end
 function f:GetAlpha()return self.alpha end
 function f:SetAlpha(n)self.alpha=n end
 function f:SetAllPoints()end
 function f:SetFrameLevel()end
 function f:SetScript(k,v)self.scripts[k]=v end
 function f:RegisterEvent(k)self.event=k end
 function f:Hide()self.visible=false end
 function f:Show()self.visible=true end
 function f:CreateFontString()
  local text={}
  function text:SetFont(font,size,flags)self.font,self.size,self.flags=font,size,flags end
  function text:ClearAllPoints()end
  function text:SetPoint()end
  function text:SetTextColor()end
  function text:SetText(value)self.value=value end
  return text
 end
 return f
end
env.CreateFrame=function(kind,_,parent)
 if kind=='Cooldown' and env.createNative then return env.createNative(parent) end
 local f=newFrame(parent);table.insert(frames,f);return f
end
env.GetTime=function()return now end
env.GetCVar=function()return cvar end
env.SetCVar=function()error('must not change global cooldown policy')end
env.STANDARD_TEXT_FONT='font'
env.Enum={NumericRuleFormatRounding={Up=1}}
env.C_StringUtil={CreateNumericRuleFormatter=function()
 formatted=formatted+1
 local formatter={}
 function formatter:SetBreakpoints(rules)self.rules=rules end
 function formatter:FormatNumber(n)
  local rule
  for _,candidate in ipairs(self.rules)do if n>=candidate.threshold then rule=candidate end end
  local function round(value,step)if step then return math.ceil(value/step)*step end;return value end
  local value=round(n,rule.step)
  if rule.components then value=round(value/rule.components[1].div,rule.components[1].step)end
  return string.format(rule.format,value)
 end
 return formatter
end}
nativeFactory=env.C_StringUtil.CreateNumericRuleFormatter
local set
env.hooksecurefunc=function(name,callback)assert(name=='CooldownFrame_SetTimer');set=callback end
env.ShaguTweaks={T={},API={nativecooldowns=false},GetGlobalEnv=function()return env end,GetExpansion=function()return 'vanilla' end,
 TimeConvert=reference.ShaguTweaks.TimeConvert,register=function(_,module)env.module=module;return module end}
local load=assert(loadfile(root..'mods/cooldown-numbers.lua'));setfenv(load,env);load();env.module:enable()
local parent=newFrame();parent.height=18
local function native(owner)
 local f=newFrame(owner or parent);f.nativeText=f:CreateFontString()
 function f:GetCountdownFontString()return self.nativeText end
 function f:SetCountdownFormatter(value)self.formatter=value end
 function f:SetMinimumCountdownDuration(value)self.minimum=value end
 function f:SetHideCountdownNumbers(value)self.hidden=value end
 function f:SetDrawSwipe(value)self.swipe=value end
 function f:SetDrawEdge(value)self.edge=value end
 function f:SetDrawBling(value)self.bling=value end
 function f:SetCooldown(start,duration)self.start,self.duration=start,duration;self.visible=true;self.starts=(self.starts or 0)+1 end
 return f
end
local cd=native();set(cd,100,20,1)
assert(not cd.cooldowntext and not cd.scripts.OnUpdate and not cd.hidden)
assert(cd.minimum==1999 and cd.nativeText.size==18*.64)
assert(table.getn(frames)==1 and frames[1].event=='CVAR_UPDATE')
local second=native();set(second,100,20,1)
assert(formatted==1 and second.formatter==cd.formatter,'one shared native formatter')
for _,n in ipairs({.01,.99,1,4.01,4.99,5,5.01,9.99,10,59,59.99,60,60.01,3599.99,3600,86399.99,86400,172801})do
 assert(cd.formatter:FormatNumber(n)==reference.ShaguTweaks.TimeConvert(n),'TimeConvert mismatch at '..n)
end
set(cd,100,1.5,1);assert(cd.hidden and not cd.cooldowntext)
set(cd,100,2,1);assert(not cd.hidden)
set(cd,0,20,1);assert(cd.hidden)
set(cd,100,20,0);assert(cd.hidden)
set(cd,100,20,1);cd.noCooldownCount=true;set(cd,100,20,1);assert(cd.hidden)
cd.noCooldownCount=nil;cd.pfCooldownType='spell';set(cd,100,20,1);assert(cd.hidden)
cd.pfCooldownType=nil;cd.readable=true;set(cd,100,20,1);assert(cd.hidden)
cd.readable=nil
local foreign=native();foreign.pfCooldownType='spell';set(foreign,100,20,1)
assert(foreign.hidden==nil and foreign.formatter==nil,'must leave foreign-owned native setup alone')
local excluded=native();excluded.noCooldownCount=true;set(excluded,100,20,1)
assert(excluded.hidden and not excluded.cooldowntext and not excluded.formatter)
-- CVar changes switch existing native indicators without setting the CVar.
local watcher=frames[1]
cvar='0';watcher.scripts.OnEvent()
assert(cd.cooldowntext and cd.cooldowntext.visible and cd.hidden)
local function tick(frame,dt)env.this,env.arg1=frame,dt;frame.scripts.OnUpdate();env.this,env.arg1=nil,nil end
tick(cd.cooldowntext,.1);assert(cd.cooldowntext.text.value==reference.ShaguTweaks.TimeConvert(19))
local frameCount=table.getn(frames);watcher.scripts.OnEvent();assert(table.getn(frames)==frameCount)
cvar='1';watcher.scripts.OnEvent();assert(not cd.cooldowntext.visible and not cd.hidden)
-- Legacy Models keep the old renderer, including alpha, expiry and clock wrap.
local model=newFrame(parent);set(model,100,20,1);assert(model.cooldowntext.visible)
model.alpha=.4;tick(model.cooldowntext,.1);assert(model.cooldowntext.alpha==.4)
now=121;tick(model.cooldowntext,.1);assert(not model.cooldowntext.visible)
local cycle=2^32/1000;now=1;set(model,cycle-2,10,1);tick(model.cooldowntext,.1)
assert(model.cooldowntext.text.value==reference.ShaguTweaks.TimeConvert(7))
-- Native numeric children optimize legacy Models without changing their sweep.
env.ShaguTweaks.API.nativecooldowns=true;env.createNative=native
local legacy=newFrame(parent);set(legacy,1,20,1)
local numbers=legacy.stCountdownNativeFrame
assert(numbers and not legacy.cooldowntext and not numbers.scripts.OnUpdate)
assert(numbers.parent==legacy and numbers.start==1 and numbers.duration==20)
assert(numbers.swipe==false and numbers.edge==false and numbers.bling==false)
local starts=numbers.starts;set(numbers,1,20,1)
assert(numbers.starts==starts,'native helper must not recursively decorate itself')
set(legacy,1,1,1);assert(not numbers.visible)
set(legacy,1,20,1);assert(numbers.visible)
cvar='0';watcher.scripts.OnEvent();assert(not numbers.visible and legacy.cooldowntext.visible)
cvar='1';watcher.scripts.OnEvent();assert(numbers.visible and not legacy.cooldowntext.visible)
assert(legacy.stCountdownNativeFrame==numbers)
legacy.noCooldownCount=true;set(legacy,1,20,1);assert(not numbers.visible)
-- A rejected native frame creation safely falls back and is not retried.
local attempts=0;env.createNative=function()attempts=attempts+1;error('unsupported frame')end
local unsupported=newFrame(parent);set(unsupported,1,20,1);set(unsupported,1,20,1)
assert(unsupported.cooldowntext.visible and attempts==1)
env.ShaguTweaks.API.nativecooldowns=false
-- Missing formatter APIs retain one renderer, suppressing native duplicates.
env.C_StringUtil.CreateNumericRuleFormatter=nil
local older=native();set(older,1,20,1)
assert(older.hidden and older.cooldowntext.visible)
env.C_StringUtil.CreateNumericRuleFormatter=nativeFactory
set(model,1,1,1);assert(not model.cooldowntext.visible)
model.noCooldownCount=true;set(model,1,20,1);assert(not model.cooldowntext.visible)
print('Cooldown numbers: shared native formatter, TimeConvert boundaries, global-CVar ownership/live changes, foreign flags, GCDs, legacy/older API fallback, alpha/expiry and clock wrap passed')
