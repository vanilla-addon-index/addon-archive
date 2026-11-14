-- Minimap button: left click opens the options, right click switches the role, drag to move it around the minimap.
-- Target: Lua 5.0.

local AG = AdeGear
local Mini = {}
AG.Minimap = Mini

local button = nil
local dragging = false

local ROLES = { "auto", "tank", "heal", "dmg" }
local ROLE_NAME = { auto = "Auto (from talents)", tank = "Tank", heal = "Healer", dmg = "Damage" }

-- pfUI makes the minimap square: the button then slides along the square edge
local function IsSquare()
  if AG.Get("minimapShape") == "round" then return false end
  if AG.Get("minimapShape") == "square" then return true end
  return (pfUI ~= nil and pfUI.minimap ~= nil)
end

function Mini.Place()
  if not button then return end
  local angle = math.rad(AG.Get("minimapAngle") or 225)
  local cx, cy = math.cos(angle), math.sin(angle)
  local half = (Minimap:GetWidth() or 140) / 2
  local x, y
  if IsSquare() then
    local m = math.max(math.abs(cx), math.abs(cy))
    x, y = cx / m * (half + 2), cy / m * (half + 2)
  else
    x, y = cx * (half + 5), cy * (half + 5)
  end
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function Drag()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  if not mx or not px then return end
  px, py = px / scale, py / scale
  local angle = math.deg(math.atan2(py - my, px - mx))
  if angle < 0 then angle = angle + 360 end
  AdeGearDB = AdeGearDB or {}
  AdeGearDB.minimapAngle = angle
  Mini.Place()
end

local function Tip()
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:AddLine("AdeGear", AG.C.accent[1], AG.C.accent[2], AG.C.accent[3])
  if AG.GearScore then
    local ok, total = pcall(AG.GearScore.Own)
    if ok and total then GameTooltip:AddLine("GearScore: " .. math.floor(total + 0.5), 1, 0.82, 0) end
  end
  GameTooltip:AddLine("Left click: options", 1, 1, 1)
  GameTooltip:AddLine("Right click: switch role (now: " .. tostring(ROLE_NAME[AG.Get("role")] or AG.Get("role")) .. ")", 1, 1, 1)
  GameTooltip:AddLine("Drag: move the button", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

function Mini.Create()
  if button or not Minimap then return end
  local b = CreateFrame("Button", "AdeGearMinimapButton", Minimap)
  button = b
  b:SetWidth(31)
  b:SetHeight(31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  icon:SetWidth(19)
  icon:SetHeight(19)
  icon:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -6)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(52)
  border:SetHeight(52)
  border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

  b:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      local cur = AG.Get("role")
      local nextRole = ROLES[1]
      for i = 1, table.getn(ROLES) do
        if ROLES[i] == cur then nextRole = ROLES[i + 1] or ROLES[1] end
      end
      AG.Set("role", nextRole)
      AG.Msg("role: " .. nextRole)
      if GameTooltip:IsOwned(this) then Tip() end
    else
      AG.Options.Toggle()
    end
  end)
  b:SetScript("OnDragStart", function()
    dragging = true
    this:SetScript("OnUpdate", Drag)
    GameTooltip:Hide()
  end)
  b:SetScript("OnDragStop", function()
    dragging = false
    this:SetScript("OnUpdate", nil)
  end)
  b:SetScript("OnEnter", function() if not dragging then Tip() end end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  Mini.Place()
  Mini.Update()
end

function Mini.Update()
  if not button then return end
  if AG.Get("minimap") then button:Show() else button:Hide() end
end

local oldConfig = AG.OnConfig
AG.OnConfig = function(key, value)
  if oldConfig then oldConfig(key, value) end
  if key == "minimap" then Mini.Update() end
end

-- built once the saved settings are loaded
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  Mini.Create()
  Mini.Update()
end)
