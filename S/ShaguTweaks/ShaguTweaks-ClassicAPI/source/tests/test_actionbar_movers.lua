local root=(arg[1] or '.') .. '/'
local function Check(reduced,actionOption,nativeEvents,timer)
 local progressOption=actionOption
 local modules,frames,pending={},{},{}
 local methods={}
 local noop=function() end
 local function new(kind,name,parent)
  local frame=setmetatable({name=name,parent=parent,scripts={},visible=true,width=200,height=36,scale=1,points={}},{__index=function(t,k) if methods[k] then return methods[k] elseif k~='ShaguTweaksMouseoverController' and string.find(k,'^[A-Z]') then return noop end end})
  table.insert(frames,frame);if name then _G[name]=frame end;return frame
 end
 function methods:GetName() return self.name end
 function methods:GetParent() return self.parent end
 function methods:SetPoint(p,relative,rp,x,y) self.points={{p,relative,rp,x or 0,y or 0}} end
 function methods:ClearAllPoints() self.points={} end
 function methods:GetPoint(i) local p=self.points[i or 1];if p then return unpack(p) end end
 function methods:GetNumPoints() return table.getn(self.points) end
 function methods:GetLeft()
  local p=self.points[1];if not p then return self.left or 0 end
  return (p[2] and p[2]~=UIParent and p[2]:GetLeft() or 0)+p[4]
 end
 function methods:GetTop()
  local p=self.points[1];if not p then return self.top or 0 end
  return (p[2] and p[2]~=UIParent and p[2]:GetTop() or 0)+p[5]
 end
 function methods:GetWidth() return self.width end
 function methods:GetHeight() return self.height end
 function methods:SetWidth(w) self.width=w end
 function methods:SetHeight(h) self.height=h end
 function methods:SetScale(s) self.scale=s end
 function methods:GetEffectiveScale() return self.scale end
 function methods:SetAllPoints(f) self.allPoints=f end
 function methods:SetScript(k,v) self.scripts[k]=v end
 function methods:GetScript(k) return self.scripts[k] end
 function methods:IsVisible() return self.visible and (not self.parent or self.parent:IsVisible()) end
 function methods:Show() local changed=not self.visible;self.visible=true;if changed and self.scripts.OnShow then local before=this;this=self;self.scripts.OnShow();this=before end end
 function methods:Hide() local changed=self.visible;self.visible=false;if changed and self.scripts.OnHide then local before=this;this=self;self.scripts.OnHide();this=before end end
 function methods:StartMoving() self.moving=true end
 function methods:SetMovable(value) self.movable=value end
 function methods:SetUserPlaced(value)
  assert(self.movable, 'Frame is not movable or resizable')
  self.userPlaced=value
 end
 function methods:StopMovingOrSizing() self.moving=false end
 function methods:CreateFontString() return new('FontString',nil,self) end
 function methods:SetText(t) self.text=t end
 CreateFrame=new
 UIParent=new('Frame','UIParent')
 local names={'MainMenuBar','MultiBarBottomLeft','MultiBarBottomRight','MultiBarRight','MultiBarLeft','PetActionBarFrame','ShapeshiftBarFrame','MainMenuExpBar','ReputationWatchBar'}
 for i,name in ipairs(names) do new('Frame',name,UIParent):SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',10*i,100+i*20) end
 MainMenuExpBar:SetPoint('TOPLEFT',MainMenuBar,'TOPLEFT',0,20)
 ReputationWatchBar:SetPoint('TOPLEFT',MainMenuExpBar,'TOPLEFT',0,8)
 MultiBarBottomLeft:SetPoint('TOPLEFT',MainMenuExpBar,'TOPLEFT',0,30)
 MultiBarBottomRight:SetPoint('TOPLEFT',MultiBarBottomLeft,'TOPLEFT',0,40)
 local nativeClick=function() end
 ActionButton1=new('Button','ActionButton1',MainMenuBar);ActionButton1:SetScript('OnClick',nativeClick)
 ActionButton12=new('Button','ActionButton12',MainMenuBar)
 PetActionButton1=new('Button','PetActionButton1',PetActionBarFrame)
 PetActionButton10=new('Button','PetActionButton10',PetActionBarFrame)
 BonusActionBarFrame=new('Frame','BonusActionBarFrame',MainMenuBar);BonusActionBarFrame:Hide()
 MainMenuExpBar:Hide();ReputationWatchBar:Hide()
 MultiBarRight:Hide();MultiBarRight.ShaguTweaksMouseoverController={enabled=true}
 local originalMainSetPoint=MainMenuBar.SetPoint
 local keys=false
 ShaguTweaks={mods=modules,T=setmetatable({},{__index=function(t,k) return k end}),API={timer=timer,modifierstate=nativeEvents}}
 function ShaguTweaks.GetGlobalEnv() return _G end
 dofile(root..'api.lua')
 ShaguTweaks.API.timer=timer;ShaguTweaks.API.modifierstate=nativeEvents
 function ShaguTweaks:register(m) modules[m.title]=m;return m end
 ShaguTweaks.API.IsShiftKeyDown=function() return keys end
 ShaguTweaks.API.IsControlKeyDown=ShaguTweaks.API.IsShiftKeyDown
 ShaguTweaks.API.IsAltKeyDown=ShaguTweaks.API.IsShiftKeyDown
 function ShaguTweaks.API.Defer(callback) table.insert(pending,callback) end
 function ShaguTweaks.HookScript(frame,event,callback)
  local original=frame:GetScript(event)
  frame:SetScript(event,function() if original then original() end;callback() end)
 end
 local layouts=0
 function UIParent_ManageFramePositions()
  layouts=layouts+1
  MainMenuBar:ClearAllPoints();MainMenuBar:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',10,120)
  MultiBarBottomLeft:ClearAllPoints();MultiBarBottomLeft:SetPoint('TOPLEFT',MainMenuExpBar,'TOPLEFT',0,30)
 end
 function ReputationWatchBar_Update()
  ReputationWatchBar:ClearAllPoints();ReputationWatchBar:SetPoint('TOPLEFT',MainMenuExpBar,'TOPLEFT',0,8)
 end
 local config={['Reduced Actionbar Size']=reduced and 1 or 0,ActionBarPositions={}}
 ShaguTweaks_config=config
 dofile(root..'mods/actionbar-move.lua')
 local baseline=table.getn(frames)
 assert(not modules['Movable Action Bars'])
 if actionOption then ShaguTweaks.EnableActionBarMovers() end
 assert(not modules['Movable XP & Reputation Bars'])
 if not reduced or (not actionOption and not progressOption) then
  assert(table.getn(frames)==baseline and MainMenuBar.SetPoint==originalMainSetPoint)
  return
 end
 local ready=frames[table.getn(frames)]
 local function fire(frame,script,button)
  local priorThis,priorArg=this,arg1;this,arg1=frame,button
  frame:GetScript(script)();this,arg1=priorThis,priorArg
 end
 fire(ready,'OnEvent');fire(ready,'OnUpdate')
 if timer then pending[1]() end
 local state=ShaguTweaks.ActionBarMovers
 assert(state and table.getn(state.states)==((actionOption and reduced) and 7 or 0)+(progressOption and 2 or 0))
 -- Snap to a neighbour's original relative placement; leave distant drops
 -- and hidden targets alone. Coordinates are compared in UIParent units.
 local snapTarget=new('Frame',nil,UIParent)
 snapTarget:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',100,200)
 local snapState={frame=MainMenuBar,snapOffsets={{target={frame=snapTarget},x=4,y=42}}}
 local sx,sy=state.Snap(snapState,109,235)
 assert(sx==104 and sy==242)
 sx,sy=state.Snap(snapState,130,235);assert(sx==130 and sy==235)
 snapTarget:Hide();sx,sy=state.Snap(snapState,109,235);assert(sx==109 and sy==235)
 snapTarget:Show();snapTarget:SetScale(.5);MainMenuBar:SetScale(.5)
 sx,sy=state.Snap(snapState,110,280);assert(sx==108 and sy==284)
 MainMenuBar:SetScale(1)
 snapTarget:SetScale(1)
 local candidate=snapState.snapOffsets[1].target
 local oldLevel,oldWatched,oldStatus=UnitLevel,GetWatchedFactionInfo,ReputationWatchStatusBar
 candidate.name='MainMenuExpBar'
 UnitLevel=function() return 60 end
 sx,sy=state.Snap(snapState,109,235);assert(sx==109 and sy==235)
 UnitLevel=function() return 40 end
 sx,sy=state.Snap(snapState,109,235);assert(sx==104 and sy==242)
 candidate.name='ReputationWatchBar'
 GetWatchedFactionInfo=function() return nil end
 ReputationWatchStatusBar=new('Frame',nil,snapTarget)
 sx,sy=state.Snap(snapState,109,235);assert(sx==109 and sy==235)
 GetWatchedFactionInfo=function() return 'Stormwind' end
 sx,sy=state.Snap(snapState,109,235);assert(sx==104 and sy==242)
 ReputationWatchStatusBar:Hide()
 sx,sy=state.Snap(snapState,109,235);assert(sx==109 and sy==235)
 ReputationWatchStatusBar:Show()
 snapTarget.GetAlpha=function() return 0 end
 sx,sy=state.Snap(snapState,109,235);assert(sx==109 and sy==235)
 UnitLevel,GetWatchedFactionInfo,ReputationWatchStatusBar=oldLevel,oldWatched,oldStatus
 assert(table.getn(state.states[1].snapOffsets)>0)
 -- Native main-frame top sits 40 units above its buttons. Snapping must
 -- leave six units between visible rows, not preserve that artwork gap.
 local lower=new('Frame',nil,UIParent);lower:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',100,200)
 local upper=new('Frame',nil,UIParent);upper:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',100,300)
 local lowerButton=new('Button','SnapLower',lower)
 lowerButton.GetLeft=function() return 110 end;lowerButton.GetTop=function() return 160 end
 lowerButton.GetRight=function() return 210 end;lowerButton.GetBottom=function() return 124 end
 local upperButton=new('Button','SnapUpper',upper)
 upperButton.GetLeft=function() return 110 end;upperButton.GetTop=function() return 300 end
 upperButton.GetRight=function() return 210 end;upperButton.GetBottom=function() return 264 end
 local lowerState={name='MainMenuBar',frame=lower,first='SnapLower',last='SnapLower',snapOffsets={}}
 local upperState={name='MultiBarBottomLeft',frame=upper,first='SnapUpper',last='SnapUpper',snapOffsets={}}
 lowerState.snapOffsets={{target=upperState,x=0,y=-80}} -- incorrect legacy gap
 local allStates=state.states;state.states={lowerState,upperState}
 sx,sy=state.Snap(lowerState,103,295);assert(sx==100 and sy==298)
 assert((264-(sy-40))==6)
 sx,sy=state.Snap(lowerState,100,220);assert(sy==220) -- legacy gap cannot attract
 lowerState.name='ShaguTweaksExtraActionBar6';lowerState.extra=true
 sx,sy=state.Snap(lowerState,103,295);assert(sx==100 and sy==298)
 lowerState.name='ShaguTweaksExtraActionBar7';lowerState.vertical=true
 upperState.name='MultiBarLeft';upperState.vertical=true
 sx,sy=state.Snap(lowerState,204,342);assert(sx==206 and sy==340)
 upper:Hide()
 sx,sy=state.Snap(lowerState,204,342);assert(sx==204 and sy==342)
 state.states=allStates
 assert(not ready:GetScript('OnUpdate'))
 if nativeEvents then assert(not state.events:GetScript('OnUpdate')) end
 assert(ActionButton1:GetScript('OnClick')==nativeClick)
 local target=state.states[1]
 assert(not target.marker.visible)
 keys=true
 fire(state.events,'OnEvent')
 assert(target.marker.visible)
 local oldX,oldY=target.frame:GetLeft(),target.frame:GetTop()
 local oldXPX,oldRepX=MainMenuExpBar:GetLeft(),ReputationWatchBar:GetLeft()
 -- Model a compact visible row offset inside a larger native artwork frame.
 target.marker:ClearAllPoints();target.marker:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',oldX+25,oldY-18)
 target.marker:SetWidth(120);target.marker:SetHeight(32)
 ActionButton1:ClearAllPoints();ActionButton1:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',oldX+27,oldY-20)
 ActionButton12.GetRight=function() return oldX+143 end
 ActionButton12.GetBottom=function() return oldY-48 end
 fire(target.marker,'OnDragStart')
 assert(state.dragging==target and state.outline.moving)
 assert(state.outline:GetWidth()==120 and state.outline:GetHeight()==32)
 assert(state.outline:GetLeft()==oldX+25 and state.outline:GetTop()==oldY-18)
 assert(target.frame:GetLeft()==oldX and target.frame:GetTop()==oldY) -- drag only the empty outline
 state.outline:ClearAllPoints();state.outline:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',355,422)
 keys=false;fire(state.events,'OnEvent')
 assert(not state.dragging and not state.outline.visible and not state.outline.moving)
 assert(target.frame:GetLeft()==330 and target.frame:GetTop()==440)
 assert(config.ActionBarPositions[target.name][1]==330)
 target.frame:ClearAllPoints();target.frame:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',1,2)
 assert(target.frame:GetLeft()==330 and target.frame:GetTop()==440) -- native layout cannot erase a saved anchor
 target.clear(target.frame);target.point(target.frame,'TOPLEFT',UIParent,'BOTTOMLEFT',0,0)
 local savedEvent=event;event='PLAYER_ENTERING_WORLD';fire(state.events,'OnEvent');event=savedEvent
 assert(target.frame:GetLeft()==330 and target.frame:GetTop()==440)
 keys=true;fire(state.events,'OnEvent');fire(target.marker,'OnClick','RightButton')
 assert(not config.ActionBarPositions[target.name] and layouts>0)
 if progressOption then
  local count=0
  for _,s in ipairs(state.states) do if s.progress then count=count+1;assert(s.marker.visible) end end
  assert(count==2) -- markers are available even at max level/no watched reputation
 end
 if actionOption and reduced then
  for _,s in ipairs(state.states) do if s.name=='MultiBarRight' then assert(s.marker.visible) end end
  if progressOption then assert(config.ActionBarPositions.MainMenuExpBar and MainMenuExpBar:GetLeft()==oldXPX and ReputationWatchBar:GetLeft()==oldRepX) end
  local pet
  for _,s in ipairs(state.states) do if s.name=='PetActionBarFrame' then pet=s end end
  assert(pet and pet.marker.visible)
  assert(pet.marker:GetPoint(1)=='BOTTOMRIGHT') -- mock retains the last anchor
  PetActionBarFrame:Hide();assert(not pet.marker.visible)
  PetActionBarFrame:Show();assert(pet.marker.visible)
  pet.marker:ClearAllPoints();pet.marker:SetPoint('TOPLEFT',PetActionBarFrame,'TOPLEFT',0,0)
  local petX,petY=PetActionBarFrame:GetLeft(),PetActionBarFrame:GetTop()
  PetActionButton1:ClearAllPoints();PetActionButton1:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',petX+12,petY-8)
  PetActionButton10.GetRight=function() return petX+168 end
  PetActionButton10.GetBottom=function() return petY-38 end
  fire(pet.marker,'OnDragStart')
  assert(state.outline:GetWidth()==160 and state.outline:GetHeight()==34)
  assert(state.outline:GetLeft()==petX+10 and state.outline:GetTop()==petY-6)
  state.outline:ClearAllPoints();state.outline:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',510,594)
  fire(pet.marker,'OnDragStop')
  assert(PetActionBarFrame:GetLeft()==500 and PetActionBarFrame:GetTop()==600)
  assert(config.ActionBarPositions.PetActionBarFrame[1]==500)
  fire(pet.marker,'OnClick','RightButton')
  assert(not config.ActionBarPositions.PetActionBarFrame)
 end
end
Check(false,true,true,true)
Check(true,false,true,true)
Check(true,true,true,true)
Check(true,true,false,false)
print('Action movers: reduced-layout prerequisite, single combined option, outline drag, saved-anchor protection, dependent pinning, reset, hidden progress/mouseover markers and idle setup passed')
-- A detached progress bar must not pull Reduced Actionbar's automatic stack
-- along with it. Execute that module's actual layout callback in isolation.
local f=assert(io.open(root..'mods/reduced-actionbar.lua','r'));local reducedSource=f:read('*a');f:close();assert(loadstring(reducedSource))
local a=assert(string.find(reducedSource,'  local function UpdateActionBarPositions()',1,true))
local b=assert(string.find(reducedSource,'  hooksecurefunc("UIParent_ManageFramePositions"',a,true))
local widgets={'MainMenuExpBar','ReputationWatchBar','MultiBarBottomLeft','MultiBarBottomRight','PetActionBarFrame','ShapeshiftBarFrame','MainMenuBarArtFrame','MainMenuBar','ActionButton1','CastingBarFrame'}
for _,name in ipairs(widgets) do
 _G[name]={visible=true,IsVisible=function(self) return self.visible end,ClearAllPoints=function(self) self.point=nil end,SetPoint=function(self,...) self.point=arg end}
end
local moved={}
ShaguTweaks.ActionBarMovers={IsMoved=function(name) return moved[name] end}
local relayout=assert(loadstring(string.sub(reducedSource,a,b-1)..'return UpdateActionBarPositions'))()
relayout();assert(MultiBarBottomLeft.point[2]==ReputationWatchBar)
moved.ReputationWatchBar=true;relayout();assert(MultiBarBottomLeft.point[2]==MainMenuExpBar)
moved.MainMenuExpBar=true;relayout();assert(MultiBarBottomLeft.point[2]==MainMenuBar)
print('Reduced Actionbar: detached progress bars no longer become automatic action-stack anchors')
