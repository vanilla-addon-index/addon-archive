QuestieOcto.MinimapButton = QuestieOcto.MinimapButton or {}
local MB = QuestieOcto.MinimapButton

MB.button=nil
MB.defaultPosition=225
MB.stats={created=0,drags=0,clicks=0}

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function PositionDB()
  QuestieOctoGlobalDB=QuestieOctoGlobalDB or {}
  QuestieOctoGlobalDB.minimapButton=QuestieOctoGlobalDB.minimapButton or {}
  return QuestieOctoGlobalDB.minimapButton
end

local function Atan2(y,x)
  if math.atan2 then return math.atan2(y,x) end
  if x>0 then return math.atan(y/x) end
  if x<0 and y>=0 then return math.atan(y/x)+math.pi end
  if x<0 and y<0 then return math.atan(y/x)-math.pi end
  if x==0 and y>0 then return math.pi/2 end
  if x==0 and y<0 then return -math.pi/2 end
  return 0
end

local function IsSquareMinimap()
  if QuestieOcto.Minimap and QuestieOcto.Minimap.UsesSquareMinimap then
    return QuestieOcto.Minimap:UsesSquareMinimap() and true or false
  end
  return false
end

local function Clamp(value,minValue,maxValue)
  if value<minValue then return minValue end
  if value>maxValue then return maxValue end
  return value
end

function MB:UpdatePosition(position)
  local button=self.button
  if not button or not Minimap then return end

  -- Behave like a normal Vanilla minimap button. If another addon reparents
  -- the button into its own button panel, that parent owns visibility and
  -- placement until it returns the button to the Minimap.
  if button.GetParent and button:GetParent()~=Minimap then return end

  position=tonumber(position) or self.defaultPosition
  local angle=math.rad(position)
  local x=math.cos(angle)
  local y=math.sin(angle)
  local w=(Minimap:GetWidth()/2)+5
  local h=(Minimap:GetHeight()/2)+5

  if IsSquareMinimap() then
    -- LibDBIcon-style square placement: project the same angle onto the square
    -- edge instead of forcing a circular orbit around square replacement UIs.
    local diagW=math.sqrt(2*w*w)-10
    local diagH=math.sqrt(2*h*h)-10
    x=Clamp(x*diagW,-w,w)
    y=Clamp(y*diagH,-h,h)
  else
    x=x*w
    y=y*h
  end

  button:ClearAllPoints()
  button:SetPoint("CENTER",Minimap,"CENTER",x,y)
end

function MB:SavePosition(position)
  position=tonumber(position) or self.defaultPosition
  while position<0 do position=position+360 end
  while position>=360 do position=position-360 end
  PositionDB().position=position
  self:UpdatePosition(position)
end

function MB:ResetPosition()
  PositionDB().position=self.defaultPosition
  if self.button then self:UpdatePosition(self.defaultPosition) end
end

local function UpdateDrag()
  local button=this or MB.button
  if not button or not Minimap or not Minimap.GetCenter then return end
  local mx,my=Minimap:GetCenter()
  local px,py=GetCursorPosition()
  if not mx or not my or not px or not py then return end

  local scale=Minimap.GetEffectiveScale and Minimap:GetEffectiveScale() or 1
  if not scale or scale==0 then scale=1 end
  px=px/scale
  py=py/scale

  local angle=math.deg(Atan2(py-my,px-mx))
  MB:SavePosition(angle)
end

local function OnEnter()
  local button=this or MB.button
  if not button or not GameTooltip then return end
  GameTooltip:SetOwner(button,"ANCHOR_LEFT")
  GameTooltip:AddLine("Questie-Octo",1,1,1)
  GameTooltip:AddLine("Left Click: Open settings",0.75,0.75,0.75)
  if not button.GetParent or button:GetParent()==Minimap then
    GameTooltip:AddLine("Drag: Move button",0.75,0.75,0.75)
  end
  GameTooltip:Show()
end

local function OnLeave()
  if GameTooltip then GameTooltip:Hide() end
end

local function OnClick()
  if arg1 and arg1~="LeftButton" then return end
  MB.stats.clicks=MB.stats.clicks+1
  if QuestieOcto.Options and QuestieOcto.Options.Toggle then
    QuestieOcto.Options:Toggle()
  end
end

local function OnDragStart()
  local button=this or MB.button
  if not button then return end
  if button.GetParent and button:GetParent()~=Minimap then return end
  MB.stats.drags=MB.stats.drags+1
  if GameTooltip then GameTooltip:Hide() end
  if button.LockHighlight then button:LockHighlight() end
  button:SetScript("OnUpdate",UpdateDrag)
end

local function OnDragStop()
  local button=this or MB.button
  if not button then return end
  button:SetScript("OnUpdate",nil)
  if button.UnlockHighlight then button:UnlockHighlight() end
end

function MB:Create()
  if self.button or not Minimap then return self.button end

  -- ON uses an ordinary, discoverable Minimap child so any Vanilla minimap
  -- button manager can reparent, hide, show, or arrange it normally. OFF is the
  -- separate safety boundary: Initialize() never calls Create(), so no button
  -- frame exists during that UI session.
  local button=CreateFrame("Button","QuestieOctoMinimapButton",Minimap)

  button:SetWidth(31)
  button:SetHeight(31)
  button:SetFrameStrata("MEDIUM")
  if button.SetFrameLevel and Minimap.GetFrameLevel then
    button:SetFrameLevel(Minimap:GetFrameLevel()+8)
  end
  if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp") end
  if button.RegisterForDrag then button:RegisterForDrag("LeftButton") end

  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local background=button:CreateTexture(nil,"BACKGROUND")
  background:SetWidth(20)
  background:SetHeight(20)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetPoint("TOPLEFT",button,"TOPLEFT",7,-5)

  local icon=button:CreateTexture(nil,"ARTWORK")
  icon:SetWidth(17)
  icon:SetHeight(17)
  icon:SetTexture("Interface\\AddOns\\Questie-Octo\\UI\\Icons\\available.blp")
  icon:SetPoint("TOPLEFT",button,"TOPLEFT",7,-6)
  icon:SetTexCoord(0.05,0.95,0.05,0.95)
  button.icon=icon

  local border=button:CreateTexture(nil,"OVERLAY")
  border:SetWidth(53)
  border:SetHeight(53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT",button,"TOPLEFT",0,0)

  button:SetScript("OnEnter",OnEnter)
  button:SetScript("OnLeave",OnLeave)
  button:SetScript("OnClick",OnClick)
  button:SetScript("OnDragStart",OnDragStart)
  button:SetScript("OnDragStop",OnDragStop)

  self.button=button
  self.stats.created=self.stats.created+1
  self:UpdatePosition(PositionDB().position or self.defaultPosition)
  button:Show()
  return button
end

function MB:Initialize()
  -- This is the safety boundary: OFF means no Questie-Octo minimap button is
  -- instantiated for this UI session. Changing the option requires /reload.
  if not Settings():Get("showMinimapButton") then return end
  self:Create()
end

-- Create the enabled button as soon as Questie-Octo's SavedVariables are
-- available. Vanilla minimap-button panels commonly perform one early startup
-- scan; delaying this until after PLAYER_LOGIN can make them miss the button
-- until a manual rescan. ADDON_LOADED is early enough while still guaranteeing
-- that this addon's SavedVariables have been restored.
--
-- The loader itself is not a Minimap child/button, so OFF still creates no
-- collectable Questie-Octo minimap-button object. PLAYER_LOGIN is only a safe
-- fallback for unusual loaders that do not deliver our ADDON_LOADED event.
local loader=CreateFrame("Frame","QuestieOctoMinimapButtonLoader",UIParent)
local initialized=false

local function InitializeButtonOnce()
  if initialized then return end
  initialized=true
  MB:Initialize()
end

loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent",function()
  if event=="ADDON_LOADED" then
    if arg1~="Questie-Octo" then return end
    loader:UnregisterEvent("ADDON_LOADED")
    loader:UnregisterEvent("PLAYER_LOGIN")
    InitializeButtonOnce()
  elseif event=="PLAYER_LOGIN" then
    loader:UnregisterEvent("ADDON_LOADED")
    loader:UnregisterEvent("PLAYER_LOGIN")
    InitializeButtonOnce()
  end
end)
