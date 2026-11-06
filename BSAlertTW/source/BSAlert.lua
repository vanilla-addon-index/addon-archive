-- Vérifie la présence d'un buff via texture
function HasBuff(unit, textureName)
  local i = 1
  while UnitBuff(unit, i) do
    local texture = UnitBuff(unit, i)
    if texture and string.find(texture, textureName) then
      return true
    end
    i = i + 1
  end
  return nil
end

-- Variables globales
local BSAlert = nil
local BSAlert_combat = nil
local BSAlert_moveMode = false
local basePixelSize = 640

-- Charge ou initialise la base de données
local function LoadSavedData()
  if not BSAlertDB then BSAlertDB = {} end
  BSAlertDB.posX = BSAlertDB.posX or 0
  BSAlertDB.posY = BSAlertDB.posY or 0
  BSAlertDB.pixelSize = BSAlertDB.pixelSize or 128
end

-- Sauvegarde position et échelle
local function SaveCurrentState()
  if not BSAlert then return end
  local _, _, _, x, y = BSAlert:GetPoint()
  BSAlertDB.posX = x
  BSAlertDB.posY = y
  BSAlertDB.pixelSize = BSAlert:GetWidth()
end

-- Applique la taille exacte en pixels
local function ApplyPixelSize(frame, size)
  if not frame then return end  -- 🔒 Empêche l'erreur
  local s = max(32, min(256, size or 128))
  frame:SetWidth(s)
  frame:SetHeight(s)
end


-- Crée le slider de taille
local function CreateScaleSlider(parent)
  local slider = CreateFrame("Slider", "BSAlertScaleSlider", parent, "OptionsSliderTemplate")
  slider:SetMinMaxValues(64, 256)
  slider:SetValueStep(16)
  slider:SetOrientation("HORIZONTAL")
  slider:SetWidth(128)
  slider:SetHeight(16)
  slider:SetPoint("TOP", parent, "BOTTOM", 0, -8)

  local low = getglobal(slider:GetName().."Low")
  local high = getglobal(slider:GetName().."High")
  local text = getglobal(slider:GetName().."Text")
  if low then low:SetText("64") end
  if high then high:SetText("256") end
  if text then text:SetText("Size") end

  slider:SetScript("OnValueChanged", function()
    if not BSAlert then return end
    local size = slider:GetValue()
    ApplyPixelSize(BSAlert, size)
    BSAlertDB.pixelSize = size
    SaveCurrentState()
  end)

  slider:Hide()
  return slider
end

-- Crée l'icône principale
local function CreateBSIcon()
  local f = CreateFrame("Frame", "BSAlert", UIParent)
  f:SetClampedToScreen(true)
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:EnableMouse(false)
  f:RegisterForDrag("LeftButton")
  f:SetWidth(128)
  f:SetHeight(128)

  f:SetScript("OnDragStart", function()
    if BSAlert_moveMode then this:StartMoving() end
  end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    SaveCurrentState()
  end)

  local tex = f:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints(f)
  tex:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout")
  f.texture = tex

  LoadSavedData()
  f:SetPoint("CENTER", UIParent, "CENTER", BSAlertDB.posX, BSAlertDB.posY)
  ApplyPixelSize(f, BSAlertDB.pixelSize)
  f.scaleSlider = CreateScaleSlider(f)
  f.scaleSlider:SetValue(BSAlertDB.pixelSize)
  f:Hide()

  return f
end

-- Gestion des événements
function BSAlert_OnLoad()
  this:RegisterEvent("VARIABLES_LOADED")
  this:RegisterEvent("PLAYER_REGEN_ENABLED")
  this:RegisterEvent("PLAYER_REGEN_DISABLED")
  this:RegisterEvent("PLAYER_AURAS_CHANGED")
  this:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function BSAlert_OnEvent(event)
  if event == "VARIABLES_LOADED" then
    LoadSavedData()
    BSAlert = CreateBSIcon()
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00BS|rAlert |cff00ff96TW|r: |cff00ffffType /bshelp|r for options.")
  end


  if event == "PLAYER_REGEN_DISABLED" then
    BSAlert_combat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    BSAlert_combat = nil
  end

  if BSAlert and BSAlert_combat and not HasBuff("player", "Ability_Warrior_BattleShout") then
    BSAlert:Show()
  elseif BSAlert and not BSAlert_moveMode then
    BSAlert:Hide()
  end
end

-- /bsmove pour édition
SLASH_BSMOVE1 = "/bsmove"
SlashCmdList["BSMOVE"] = function()
  if not BSAlert then return end
  BSAlert_moveMode = not BSAlert_moveMode

  if BSAlert_moveMode then
    BSAlert:Show()
    BSAlert:EnableMouse(true)
    BSAlert:SetScript("OnMouseDown", BSAlert:GetScript("OnDragStart"))
    BSAlert:SetScript("OnMouseUp", BSAlert:GetScript("OnDragStop"))
    if BSAlert.scaleSlider then
      BSAlert.scaleSlider:SetValue(BSAlertDB.pixelSize)
      BSAlert.scaleSlider:Show()
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[BSAlert]:|r Edit mode enabled. Use the slider.")
  else
    BSAlert:EnableMouse(false)
    BSAlert:SetScript("OnMouseDown", nil)
    BSAlert:SetScript("OnMouseUp", nil)
    if BSAlert.scaleSlider then
      BSAlert.scaleSlider:Hide()
    end
    BSAlert:Hide()
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[BSAlert]:|r Edit mode disabled.")
  end
end

-- /bsreset pour reset position/taille
SLASH_BSRESET1 = "/bsreset"
SlashCmdList["BSRESET"] = function()
  if not BSAlert then return end
  BSAlertDB.posX = 0
  BSAlertDB.posY = 0
  BSAlertDB.pixelSize = 128
  BSAlert:ClearAllPoints()
  BSAlert:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  ApplyPixelSize(BSAlert, 128)
  SaveCurrentState()
  if BSAlert.scaleSlider then
    BSAlert.scaleSlider:SetValue(128)
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[BSAlert]:|r Position and size have been reset.")
end

-- /bshelp pour aide
SLASH_BSHELP1 = "/bshelp"
SlashCmdList["BSHELP"] = function()
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[BSAlert Help]|r Available commands:")
  DEFAULT_CHAT_FRAME:AddMessage("|cffffff00/bsmove|r - Toggle edit mode to move and resize the icon.")
  DEFAULT_CHAT_FRAME:AddMessage("|cffffff00/bsreset|r - Reset the icon's position and size.")
  DEFAULT_CHAT_FRAME:AddMessage("|cffffff00/bshelp|r - Show this help message.")
end
