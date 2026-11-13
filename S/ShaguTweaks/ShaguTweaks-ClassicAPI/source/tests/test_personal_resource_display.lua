local root=(arg[1] or '.') .. '/'
local function Check(big,timer,hideResources,druid,noNameColor)
 local modules,frames,pending={},{},{}
 local methods={}
 local function noop() end
 local function new(kind,name,parent)
  local object=setmetatable({kind=kind or 'Frame',name=name,parent=parent,scripts={},width=119,height=12,left=106,top=550,scale=1,alpha=1,visible=true},{__index=function(t,k) if methods[k] then return methods[k] elseif string.find(k,'^[A-Z]') then return noop end end})
  table.insert(frames,object); if name then _G[name]=object end; return object
 end
 function methods:GetName() return self.name end
 function methods:GetObjectType() return self.kind end
 function methods:SetParent(parent) self.parent=parent end
 function methods:GetParent() return self.parent end
 function methods:SetWidth(w) self.width=w end
 function methods:SetHeight(h) self.height=h end
 function methods:GetWidth() return self.width end
 function methods:GetHeight() return self.height end
 function methods:GetLeft() return self.left end
 function methods:GetTop() return self.top end
 function methods:GetCenter() return self.centerX,self.centerY end
 function methods:ClearAllPoints() self.points={} end
 function methods:SetPoint(p,relative,rp,x,y) self.points={p,relative,rp,x,y}; if rp=='BOTTOMLEFT' then self.left=x;self.top=y end end
 function methods:SetAllPoints(relative) self.allPoints=relative end
 function methods:SetScale(scale) self.scale=scale end
 function methods:GetEffectiveScale() return self.scale end
 function methods:SetFrameLevel(level) self.level=level end
 function methods:GetFrameLevel() return self.level or 1 end
 function methods:GetFrameStrata() return 'BACKGROUND' end
 function methods:SetScript(script,callback) self.scripts[script]=callback end
 function methods:GetScript(script) return self.scripts[script] end
 function methods:CreateTexture() return new('Texture',nil,self) end
 function methods:SetMask(path) self.mask=path end
 function methods:SetTexture(path) self.path=path end
 function methods:SetBackdrop(backdrop) self.backdrop=backdrop end
 function methods:GetTexture() return self.path end
 function methods:GetStatusBarTexture() local path=self.barPath or 'NativeHealthTexture';return {GetTexture=function() return path end} end
 function methods:SetStatusBarTexture(path) self.barPath=path;self.textureWrites=(self.textureWrites or 0)+1 end
 function methods:GetStatusBarColor() return unpack(self.barColor or {.53,.53,.93,1}) end
 function methods:SetText(text) self.text=text end
 function methods:SetTexCoord(a,b,c,d) self.uv={a,b,c,d} end
 function methods:GetTexCoord() return 1,0,1,.78125,.09375,0,.09375,.78125 end
 function methods:SetVertexColor(r,g,b,a) self.color={r,g,b,a} end
 function methods:GetVertexColor() return 1,.78,.4,1 end
 function methods:SetDrawLayer(layer) self.layer=layer end
 function methods:SetAlpha(alpha) self.alpha=alpha end
 function methods:EnableMouse(enabled) self.mouse=enabled end
 function methods:StartMoving() self.moving=true end
 function methods:StopMovingOrSizing() self.moving=false;self.sizing=false end
 function methods:Hide() self.visible=false end
 function methods:Show() self.visible=true end
 function methods:IsShown() return self.visible end
 CreateFrame=new
 local keys=false
 ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),API={timer=timer}}
 function ShaguTweaks.GetGlobalEnv() return _G end
 dofile(root..'api.lua')
 ShaguTweaks.API.modifierstate=timer
 ShaguTweaks.API.timer=timer
 function ShaguTweaks:register(module) modules[module.title]=module;return module end
 function ShaguTweaks.HookScript(frame,key,callback)
  local original=frame:GetScript(key)
  frame:SetScript(key,function() if original then original() end;callback() end)
 end
 ShaguTweaks.API.IsShiftKeyDown=function() return keys end
 ShaguTweaks.API.IsControlKeyDown=ShaguTweaks.API.IsShiftKeyDown
 ShaguTweaks.API.IsAltKeyDown=ShaguTweaks.API.IsShiftKeyDown
 function ShaguTweaks.API.Defer(callback) table.insert(pending,callback) end
 function ShaguTweaks.hooksecurefunc(object,name,callback)
  if type(object)=='string' then callback=name;name=object;object=_G end
  local original=object[name] or noop
  object[name]=function(a,b,c,d) original(a,b,c,d);callback(a,b,c,d) end
 end
 local oldThis,oldArg
 local function fire(frame,script,button)
  oldThis,oldArg=this,arg1;this,arg1=frame,button; local callback=frame:GetScript(script); if callback then callback() end; this,arg1=oldThis,oldArg
 end
 UIParent=new('Frame','UIParent');PlayerFrame=new('Button','PlayerFrame',UIParent)
 PlayerFrame.width=232;PlayerFrame.height=100
 function UnitClass() return druid and 'Druid' or 'Warlock',druid and 'DRUID' or 'WARLOCK' end
 local powerType=druid and 3 or 0
 function UnitPowerType() return powerType end
 function UnitLevel() return 60 end
 ShaguTweaks.ModernClassColors={WARLOCK={r=.53,g=.53,b=.93}}
 PlayerLevelText=new('FontString','PlayerLevelText',PlayerFrame)
 PlayerLevelText.centerX=117;PlayerLevelText.centerY=496
 PlayerFrame.name=new('FontString','PlayerName',PlayerFrame)
 PlayerPortrait=new('Texture','PlayerPortrait',PlayerFrame)
 PlayerRestIcon=new('Texture','PlayerRestIcon',PlayerFrame);PlayerRestIcon.width=31
 PlayerRestIcon.left=101;PlayerRestIcon.top=513
 PlayerStatusGlow=new('Frame','PlayerStatusGlow',PlayerFrame);PlayerStatusGlow.width=32
 PlayerStatusGlow.left=101;PlayerStatusGlow.top=513
 PlayerFrameTexture=new('Texture','PlayerFrameTexture',PlayerFrame);PlayerFrameTexture.path=big and 'BigHealthArt' or 'StockArt'
 PlayerFrameBackground=new('Texture','PlayerFrameBackground',PlayerFrame)
 PlayerFrameNameBackground=new('Texture','PlayerFrameNameBackground',PlayerFrame)
 PlayerFrameHealthBar=new('StatusBar','PlayerFrameHealthBar',PlayerFrame)
 PlayerFrameManaBar=new('StatusBar','PlayerFrameManaBar',PlayerFrame)
 PlayerFrameAlternatePowerBar=druid and new('StatusBar','PlayerFrameAlternatePowerBar',PlayerFrame) or nil
 PlayerFrameHealthBar.height=big and 30 or 12
 PlayerFrameHealthBar.TextString=new('FontString',nil,PlayerFrame)
 PlayerFrameManaBar.TextString=new('FontString',nil,PlayerFrame)
 local healthEvent=function() end
 PlayerFrameHealthBar:SetScript('OnEvent',healthEvent)
 local numbers=new('FontString',nil,PlayerFrameHealthBar)
 PlayerStatusTexture=new('Texture','PlayerStatusTexture',PlayerFrame)
 PlayerFrame_UpdateStatus=noop
 function methods:CreateFontString() return new('FontString',nil,self) end
 function methods:SetMinMaxValues(a,b) self.minimum=a;self.maximum=b end
 function methods:GetMinMaxValues() return self.minimum or 0,self.maximum or 100 end
 function methods:SetValue(v) self.value=v end
 function methods:GetValue() return self.value or 75 end
 function methods:SetStatusBarColor(r,g,b,a) self.barColor={r,g,b,a};self.colorWrites=(self.colorWrites or 0)+1 end
 function methods:StartSizing(direction) self.sizing=direction end
 ShaguTweaks.Abbreviate=function(v) return tostring(v) end
 ShaguTweaks_config={['Hide Player Frame Resources']=hideResources and 1 or 0,
  ["Player's Name No Class Color"]=noNameColor and 1 or 0,
  ['Unit Frame Big Health for Player']=big and 1 or 0,
  PersonalResourceDisplay={Health={x=420,y=520,width=180,height=40}}}
 local nativeHeight=PlayerFrameHealthBar:GetHeight()
 if hideResources then
  dofile(root..'mods/unitframes-hide-player-resources.lua')
  modules['Hide Player Frame Resources']:enable()
  local ready=frames[table.getn(frames)]
  fire(ready,'OnEvent');fire(ready,'OnUpdate')
  if timer then pending[1]();pending={} else fire(ready,'OnUpdate') end
  local name=ShaguTweaks.PlayerFrameResourcesLayout.name
  assert((name.classBackground~=nil)==not noNameColor)
  assert(PlayerFrame.name:GetParent()==name)
 end
 local parent=PlayerFrameHealthBar:GetParent()
 local alpha=PlayerFrameHealthBar.alpha
 local healthPoints=PlayerFrameHealthBar.points
 local nameParent=PlayerFrame.name:GetParent()
 dofile(root..'mods/unitframes-personal-resource-display.lua')
 modules['Personal Resource Display']:enable()
 local ready=frames[table.getn(frames)]
 fire(ready,'OnEvent');fire(ready,'OnUpdate')
 if timer then pending[1]() else fire(ready,'OnUpdate') end
 local display=ShaguTweaks.PersonalResourceDisplay
 if druid then
  assert(display.mana and display.mana:GetParent()==display.power and display.mana.visible)
  assert(display.mana.points[1]=='TOP' and display.mana.points[3]=='BOTTOM' and display.mana.points[5]==5)
  assert(display.mana:GetFrameLevel()<display.power:GetFrameLevel())
  assert(display.mana.bar:GetFrameLevel()<display.power:GetFrameLevel())
  assert(table.getn(modules['Personal Resource Display'].states)==2)
  PlayerFrameAlternatePowerBar:SetMinMaxValues(0,1000);PlayerFrameAlternatePowerBar:SetValue(600)
  assert(display.mana.bar.maximum==1000 and display.mana.bar.value==600)
  PlayerFrameAlternatePowerBar:Hide();assert(not display.mana.visible)
  PlayerFrameAlternatePowerBar:Show();assert(display.mana.visible)
  powerType=0;PlayerFrameAlternatePowerBar:SetValue(650);assert(not display.mana.visible)
  powerType=1;PlayerFrameAlternatePowerBar:SetValue(700);assert(display.mana.visible)
  display.power:SetWidth(250);fire(display.power,'OnSizeChanged')
  assert(display.mana.width==150 and display.mana.bar.width==142)
 else assert(not display.mana) end
 assert(display and display.health.bar~=PlayerFrameHealthBar)
 assert(PlayerFrameHealthBar:GetParent()==parent and PlayerFrameHealthBar.alpha==alpha)
 assert(PlayerFrameHealthBar.points==healthPoints and PlayerFrameHealthBar:GetHeight()==nativeHeight)
 assert(PlayerFrameHealthBar:GetScript('OnEvent')==healthEvent and PlayerFrame.name:GetParent()==nameParent)
 assert(PlayerFrame.visible and PlayerFrame.mouse~=false)
 assert(display.health:GetParent()==UIParent and display.power:GetParent()==UIParent)
 assert(display.health.width==180 and display.health.height==40 and display.health.left==420)
 assert(display.power.height==(big and 36 or 18))
 assert(display.health.bar.value==75 and display.health.bar.maximum==100)
 local copy=display.health.bar
 local textureWrites,colorWrites=copy.textureWrites,copy.colorWrites
 local r,g,b=PlayerFrameHealthBar:GetStatusBarColor()
 for i=1,100 do PlayerFrameHealthBar:SetStatusBarColor(r,g,b,1) end
 assert(copy.textureWrites==textureWrites and copy.colorWrites==colorWrites,'unchanged native colors must not rewrite copies')
 PlayerFrameHealthBar:SetStatusBarColor(.1,.2,.3,1)
 assert(copy.textureWrites==textureWrites and copy.colorWrites==colorWrites+1,'color-only update must not refresh prediction texture')
 PlayerFrameHealthBar:SetStatusBarTexture('ChangedHealthTexture')
 assert(copy.textureWrites==textureWrites+1 and copy.colorWrites==colorWrites+1)
 PlayerFrameHealthBar:SetStatusBarTexture('ChangedHealthTexture')
 assert(copy.textureWrites==textureWrites+1)
 PlayerFrameHealthBar:SetMinMaxValues(0,1000);PlayerFrameHealthBar:SetValue(400)
 assert(display.health.bar.value==400 and display.health.bar.maximum==1000)
 PlayerFrameHealthBar:SetStatusBarColor(.2,.3,.4,0)
 assert(display.health.bar.barColor[1]==.2 and display.health.bar.barColor[4]==1)
 local events=modules['Personal Resource Display'].events
 assert((events:GetScript('OnUpdate')==nil)==timer)
 assert(not display.health.mouse and not display.health.resourceState.grip.visible)
 keys=true
 if timer then fire(events,'OnEvent') else fire(events,'OnUpdate',.1) end
 assert(display.health.mouse and display.health.resourceState.grip.visible)
 fire(display.health,'OnDragStart');assert(display.health.moving)
 display.health.left=300;display.health.top=400
 fire(display.health,'OnDragStop')
 assert(ShaguTweaks_config.PersonalResourceDisplay.Health.x==300)
 local grip=display.health.resourceState.grip
 fire(grip,'OnDragStart');assert(display.health.sizing=='BOTTOMRIGHT')
 display.health:SetWidth(220);display.health:SetHeight(48)
 fire(display.health,'OnSizeChanged')
 assert(display.health.bar.width==212 and display.health.bar.height==42)
 keys=false
 if timer then fire(events,'OnEvent') else fire(events,'OnUpdate',.1) end
 assert(not display.health.sizing and ShaguTweaks_config.PersonalResourceDisplay.Health.width==220)
 keys=true
 fire(display.health,'OnMouseDown','RightButton')
 assert(not ShaguTweaks_config.PersonalResourceDisplay.Health)
 assert(display.health.width==127 and display.health.height==nativeHeight+6)
 assert(not ready:GetScript('OnUpdate'))
end
Check(false,true,false);Check(true,true,false);Check(false,true,true);Check(true,true,true)
Check(false,false,false);Check(true,false,true)
Check(false,true,false,true);Check(true,true,true,true)
Check(true,true,true,true,true)
-- Migration preserves explicit new choices and old health/power positions.
local f=assert(io.open(root..'main.lua'));local s=f:read('*a');f:close()
local a=assert(string.find(s,'  -- Replace detached native bars',1,true))
local b=assert(string.find(s,'  -- initialize overwrites',a,true))
local migrate=assert(loadstring(string.sub(s,a,b-1)))
ShaguTweaks_config={['Standalone Player Frame']=1,StandalonePlayerFrame={Health={x=10,y=20}}}
migrate()
assert(ShaguTweaks_config['Personal Resource Display']==1 and not ShaguTweaks_config['Hide Player Frame Resources'])
assert(ShaguTweaks_config.PersonalResourceDisplay.Health.x==10 and not ShaguTweaks_config.StandalonePlayerFrame)
ShaguTweaks_config={['Standalone Player Frame']=1,['Personal Resource Display']=0,
 PersonalResourceDisplay={Health={x=30}},StandalonePlayerFrame={Health={x=10},Power={x=40}}}
migrate()
assert(ShaguTweaks_config['Personal Resource Display']==0 and ShaguTweaks_config.PersonalResourceDisplay.Health.x==30)
assert(ShaguTweaks_config.PersonalResourceDisplay.Power.x==40)
print('Personal resources: independent native/copy layout combinations, source updates, resizing, drag/reset, modifier release, fallback and migration passed')
