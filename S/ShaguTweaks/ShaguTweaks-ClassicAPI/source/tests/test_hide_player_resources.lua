local root=(arg[1] or '.') .. '/'
local function Check(big,timer,hidden,hideName,maskAvailable)
 local modules,frames,pending={},{},{}
 local methods={}
 local function noop() end
 local function new(kind,name,parent)
  local object=setmetatable({kind=kind or 'Frame',name=name,parent=parent,scripts={},width=119,height=12,left=106,top=550,scale=1,alpha=1,visible=true},{__index=function(t,k) if methods[k] then return methods[k] elseif string.find(k,'^[A-Z]') then return noop end end})
  if kind=='Texture' and maskAvailable==false then object.SetMask=false end
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
 function methods:GetStatusBarTexture() return {GetTexture=function() return 'NativeHealthTexture' end} end
 function methods:GetStatusBarColor() return .53,.53,.93,1 end
 function methods:SetText(text) self.text=text end
 function methods:SetTexCoord(a,b,c,d) self.uv={a,b,c,d} end
 function methods:GetTexCoord() return 1,0,1,.78125,.09375,0,.09375,.78125 end
 function methods:SetVertexColor(r,g,b,a) self.color={r,g,b,a} end
 function methods:GetVertexColor() return 1,.78,.4,1 end
 function methods:SetDrawLayer(layer) self.layer=layer end
 function methods:SetAlpha(alpha) self.alpha=alpha end
 function methods:EnableMouse(enabled) self.mouse=enabled end
 function methods:StartMoving() self.moving=true end
 function methods:StopMovingOrSizing() self.moving=false end
 function methods:Hide() self.visible=false end
 function methods:Show() self.visible=true end
 CreateFrame=new
 ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),API={timer=timer}}
 function ShaguTweaks.GetGlobalEnv() return _G end
 dofile(root..'api.lua')
 ShaguTweaks.API.timer=timer
 local keys=false
 ShaguTweaks.API.AreMoveModifiersDown=function() return keys end
 function ShaguTweaks:register(module) modules[module.title]=module;return module end
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
 function UnitClass() return 'Warlock','WARLOCK' end
 function UnitLevel() return 60 end
 ShaguTweaks.ModernClassColors={WARLOCK={r=.53,g=.53,b=.93}}
 PlayerLevelText=new('FontString','PlayerLevelText',PlayerFrame)
 PlayerLevelText.centerX=117;PlayerLevelText.centerY=496
 PlayerFrame.name=new('FontString','PlayerName',PlayerFrame)
 PlayerFrameGroupIndicator=new('Frame','PlayerFrameGroupIndicator',PlayerFrame)
 PlayerPortrait=new('Texture','PlayerPortrait',PlayerFrame);PlayerPortrait.alpha=hidden and 0 or 1
 PlayerRestIcon=new('Texture','PlayerRestIcon',PlayerFrame);PlayerRestIcon.width=31
 PlayerRestIcon.left=101;PlayerRestIcon.top=513
 PlayerStatusGlow=new('Frame','PlayerStatusGlow',PlayerFrame);PlayerStatusGlow.width=32
 PlayerStatusGlow.left=101;PlayerStatusGlow.top=513
 PlayerFrameTexture=new('Texture','PlayerFrameTexture',PlayerFrame);PlayerFrameTexture.path=big and 'BigHealthArt' or 'StockArt'
 PlayerFrameBackground=new('Texture','PlayerFrameBackground',PlayerFrame)
 PlayerFrameNameBackground=new('Texture','PlayerFrameNameBackground',PlayerFrame)
 PlayerFrameHealthBar=new('StatusBar','PlayerFrameHealthBar',PlayerFrame)
 PlayerFrameManaBar=new('StatusBar','PlayerFrameManaBar',PlayerFrame)
 PlayerFrameHealthBar.height=big and 30 or 12
 PlayerFrameHealthBar.TextString=new('FontString',nil,PlayerFrame)
 PlayerFrameManaBar.TextString=new('FontString',nil,PlayerFrame)
 local healthEvent=function() end
 PlayerFrameHealthBar:SetScript('OnEvent',healthEvent)
 local numbers=new('FontString',nil,PlayerFrameHealthBar)
 PlayerStatusTexture=new('Texture','PlayerStatusTexture',PlayerFrame)
 PlayerFrame_UpdateStatus=noop
 local clicked,clickFrame
 PlayerFrame_OnClick=function(button) clicked=button;clickFrame=this end
 ShaguTweaks_config={['Hide Player Frame Resources']=1,['Hide Player Name']=hideName and 1 or 0,['Unit Frame Big Health for Player']=big and 1 or 0,
  PlayerFrameResources=big and {Name={x=420,y=520}} or nil}
 local originalHealth,originalMana,originalPortrait=PlayerFrameHealthBar,PlayerFrameManaBar,PlayerPortrait
 dofile(root..'mods/unitframes-hide-player-name.lua')
 if hideName then modules['Hide Player Name']:enable() end
 dofile(root..'mods/unitframes-hide-player-resources.lua')
 assert(not ShaguTweaks.PlayerFrameResourcesLayout)
 modules['Hide Player Frame Resources']:enable()
 local ready=frames[table.getn(frames)]
 fire(ready,'OnEvent');fire(ready,'OnUpdate')
 if timer then assert(table.getn(pending)==1);pending[1]() else fire(ready,'OnUpdate') end
 local layout=ShaguTweaks.PlayerFrameResourcesLayout
 assert(layout.name.visible==(not hideName))
 assert(PlayerFrameGroupIndicator.alpha==(hideName and 0 or 1))
 PlayerFrameGroupIndicator:Show();PlayerFrameGroupIndicator:SetAlpha(1)
 assert(PlayerFrameGroupIndicator.alpha==(hideName and 0 or 1))
 if not hideName then
  assert(layout.name.points[2]==(big and UIParent or PlayerFrame))
  if big then assert(layout.name.points[4]==420 and layout.name.points[5]==520) end
  fire(layout.name,'OnDragStart');assert(not layout.name.moving)
  fire(layout.name,'OnMouseUp','LeftButton');assert(clicked=='LeftButton' and clickFrame==PlayerFrame)
  keys=true
  local portraitPoint=layout.portrait.points
  fire(layout.name,'OnDragStart');assert(layout.name.moving)
  layout.name.left=300;layout.name.top=400
  fire(layout.name,'OnDragStop');assert(not layout.name.moving)
  assert(ShaguTweaks_config.PlayerFrameResources.Name.x==300 and layout.name.points[2]==UIParent)
  assert(layout.portrait.points==portraitPoint)
  fire(layout.name,'OnMouseUp','RightButton')
  assert(not ShaguTweaks_config.PlayerFrameResources.Name and layout.name.points[2]==PlayerFrame)
  fire(layout.name,'OnDragStart');layout.name.left=350;layout.name.top=450
  fire(layout.name,'OnHide');assert(not layout.name.moving and ShaguTweaks_config.PlayerFrameResources.Name.x==350)
  fire(layout.name,'OnMouseUp','RightButton');keys=false
  fire(layout.name,'OnMouseUp','RightButton');assert(clicked=='RightButton' and clickFrame==PlayerFrame)
  assert(not layout.name:GetScript('OnUpdate'))
 end
 assert(layout.portrait.art.width==40 and layout.portrait.art.height==(maskAvailable==false and 72 or 36) and layout.portrait.artRight.height==36)
 assert(layout.portrait.artBottomRight.height==36)
 if maskAvailable==false then
  assert(not layout.portrait.badge.visible and not layout.portrait.artBottomLeft)
 else
  assert(layout.portrait.artBottomLeft.height==36)
  assert(layout.portrait.badge.mask=='Interface\\CharacterFrame\\TempPortraitAlphaMask')
  assert(layout.portrait.badge:GetParent()==layout.portrait.badgeOverlay)
  assert(layout.portrait.badgeOverlay:GetFrameLevel()>layout.portrait:GetFrameLevel())
  assert(layout.portrait.levelOverlay:GetFrameLevel()>layout.portrait.badgeOverlay:GetFrameLevel())
 end
 assert(PlayerLevelText:GetParent()==layout.portrait.levelOverlay and PlayerLevelText.text==60)
 assert(PlayerLevelText.points[4]==19 and PlayerLevelText.points[5]==-58)
 assert(PlayerRestIcon.points[4]==3 and PlayerStatusGlow.points[4]==3)
 assert(PlayerLevelText.layer=='BACKGROUND' and PlayerRestIcon:GetParent()==layout.portrait.levelOverlay)
 assert(layout.portrait.levelOverlay:GetFrameLevel()>layout.portrait:GetFrameLevel())
 PlayerLevelText:SetText(61);assert(PlayerLevelText.text==61)
 assert(layout.name.classBackground.path=='NativeHealthTexture')
 assert(layout.name.classBackground.color[1]==.53 and layout.name.classBackground.color[3]==.93)
 assert(PlayerFrameNameBackground.alpha==0 and layout.name.classBackground.visible)
 assert(layout and originalHealth==PlayerFrameHealthBar and originalMana==PlayerFrameManaBar and originalPortrait==PlayerPortrait)
 assert(PlayerFrameHealthBar:GetParent()==PlayerFrame and PlayerFrameManaBar:GetParent()==PlayerFrame)
 assert(PlayerPortrait:GetParent()==layout.portrait and PlayerPortrait.alpha==(hidden and 0 or 1))
 assert(numbers:GetParent()==PlayerFrameHealthBar and PlayerFrameHealthBar:GetScript('OnEvent')==healthEvent)
 assert(PlayerFrame.visible and PlayerFrame.mouse~=false and PlayerFrameTexture.alpha==0)
 assert(PlayerFrameHealthBar.alpha==0 and PlayerFrameManaBar.alpha==0)
 assert(PlayerFrameManaBar.height==12 and PlayerFrameHealthBar.height==(big and 30 or 12))
 assert(layout.portrait:GetParent()==PlayerFrame and layout.name:GetParent()==PlayerFrame)
 assert(not ready:GetScript('OnUpdate'))
 PlayerFrameHealthBar:SetAlpha(1);assert(PlayerFrameHealthBar.alpha==0)
 PlayerFrameTexture:SetAlpha(1);assert(PlayerFrameTexture.alpha==0)
 PlayerFrame_UpdateStatus();assert(PlayerStatusTexture.width==72)
end
Check(false,true,false,false);Check(true,true,true,true);Check(false,false,false,true);Check(true,false,false,false);Check(false,true,false,false,false)
print('Hide resources: native bars/events retained, portrait/mask fallback, independent saved name movement/reset/clicks, hidden drag cleanup and raid group hiding passed')
