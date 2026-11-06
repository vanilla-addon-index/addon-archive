-- EGM options window (EGMOptionsFrame): same look as the main window, i.e. Blizzard's AuctionFrame art (Bid set: plain
-- panel), portrait at 12,-8, gold title at the top, UIPanelCloseButton, UIPanelButtonTemplate buttons, AH label fonts.
-- Only the top tiles (full) and the bottom edge of the bottom tiles (cropped) are used to get a small window.
EGM = EGM or {}
EGM.Options = EGM.Options or {}
local O = EGM.Options

local W, H = 512, 396
local BOT = H - 256 -- visible height of the cropped bottom tiles (they start right below the 256 px top tiles)
local USED = 191 -- rows of a bottom tile that carry window art (AuctionFrame: 447 - 256); the rest of the tile is transparent
local frame = nil
local boxes = {}
local slider, scaleLabel
local syncing = false

local function char() return (EGM.DB and EGM.DB.char) or {} end

local ROWS = {
  { key = "whisper", label = "Whisper buyer after delivery", default = true },
  { key = "autopay", label = "Auto-pay verified C.O.D. (off by default)", default = false },
  { key = "openAtMailbox", label = "Open with the mailbox", default = true },
  { key = "minimap", label = "Show minimap button", default = true },
  { key = "tooltip", label = "Show guild orders in item tooltips", default = true },
  { key = "confirmDeliver", label = "Confirm before delivering", default = true },
}

O.rows = ROWS

local function scaleText(v) return string.format("UI scale: %.2f", v) end

local function refresh()
  for i = 1, table.getn(boxes) do
    local cb = boxes[i]
    local v = char()[cb.egmKey]
    if v == nil then v = cb.egmDefault end
    cb:SetChecked(v and 1 or nil)
  end
  if slider then
    local s = EGM.Util.getScale()
    syncing = true
    slider:SetValue(s)
    syncing = false
    scaleLabel:SetText(scaleText(s))
  end
end

local function build()
  if frame then return end
  local f = CreateFrame("Frame", "EGMOptionsFrame", UIParent)
  f:SetWidth(W); f:SetHeight(H)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetScript("OnShow", function() EGM.Options.refresh() end)
  f:SetScale(EGM.Util.getScale())

  local portrait = f:CreateTexture("EGMOptionsPortrait", "BACKGROUND")
  portrait:SetWidth(58); portrait:SetHeight(58)
  portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)
  if SetPortraitTexture then SetPortraitTexture(portrait, "player") end

  local names = { "TopLeft", "TopRight", "BotLeft", "BotRight" }
  for i = 1, 4 do
    local t = f:CreateTexture("EGMOptions" .. names[i], "BORDER")
    t:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-" .. names[i])
    t:SetWidth(256)
    local x = 0
    if i == 2 or i == 4 then x = 256 end
    if i <= 2 then
      t:SetHeight(256); t:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
    else
      t:SetHeight(BOT); t:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(H - BOT))
      t:SetTexCoord(0, 1, (USED - BOT) / 256, USED / 256)
    end
  end

  local title = f:CreateFontString("EGMOptionsTitle", "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetText("|cffd94f2bERROR|r Guild Market - Options")

  local close = CreateFrame("Button", "EGMOptionsClose", f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 3, -8)

  for i = 1, table.getn(ROWS) do
    local r = ROWS[i]
    local name = "EGMOptionsCheck" .. i
    local cb = CreateFrame("CheckButton", name, f, "UICheckButtonTemplate")
    cb:SetWidth(24); cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -88 - (i - 1) * 28)
    local text = getglobal(name .. "Text")
    if text then
      text:SetText(r.label)
      if GameFontHighlight and text.SetFontObject then text:SetFontObject(GameFontHighlight) end
    end
    cb.egmKey = r.key
    cb.egmDefault = r.default
    cb:SetScript("OnClick", function()
      char()[this.egmKey] = (this:GetChecked() == 1)
      if this.egmKey == "minimap" and EGM.Minimap and EGM.Minimap.update then EGM.Minimap.update() end
    end)
    table.insert(boxes, cb)
  end

  scaleLabel = f:CreateFontString("EGMOptionsScaleLabel", "ARTWORK", "GameFontNormalSmall")
  scaleLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 38, -(88 + table.getn(ROWS) * 28 + 14))
  scaleLabel:SetText(scaleText(EGM.Util.getScale()))

  slider = CreateFrame("Slider", "EGMOptionsScale", f, "OptionsSliderTemplate")
  slider:SetWidth(240); slider:SetHeight(16)
  slider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -14)
  slider:SetMinMaxValues(EGM.Util.SCALE_MIN, EGM.Util.SCALE_MAX)
  slider:SetValueStep(EGM.Util.SCALE_STEP)
  slider:SetValue(EGM.Util.getScale())
  local lo, hi, tx = getglobal("EGMOptionsScaleLow"), getglobal("EGMOptionsScaleHigh"), getglobal("EGMOptionsScaleText")
  if lo then lo:SetText(string.format("%.1f", EGM.Util.SCALE_MIN)) end
  if hi then hi:SetText(string.format("%.1f", EGM.Util.SCALE_MAX)) end
  if tx then tx:SetText("") end
  slider:SetScript("OnValueChanged", function()
    if syncing then return end
    local s = EGM.Options.setScale(this:GetValue())
    scaleLabel:SetText(scaleText(s))
  end)

  -- the three slots of the AH bottom art: version box, then two button slots left of Close
  local ver = f:CreateFontString("EGMOptionsVersion", "ARTWORK", "NumberFontNormal")
  ver:SetWidth(180); ver:SetHeight(22)
  ver:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 32, 14) -- left padding like the AH input box
  if ver.SetJustifyH then ver:SetJustifyH("LEFT") end
  if ver.SetJustifyV then ver:SetJustifyV("MIDDLE") end
  ver:SetText("EGM " .. tostring(EGM.VERSION or "?"))

  local function tip(btn, title, text)
    btn:SetScript("OnEnter", function()
      if GameTooltip then GameTooltip:SetOwner(this, "ANCHOR_TOP"); GameTooltip:SetText(title, 1, 0.82, 0); GameTooltip:AddLine(text, 1, 1, 1, 1); GameTooltip:Show() end
    end)
    btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  end

  local done = CreateFrame("Button", "EGMOptionsDoneBtn", f, "UIPanelButtonTemplate")
  done:SetWidth(80); done:SetHeight(22)
  done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 14) -- same offset as the Close button of the main window / AH art slot
  done:SetText("Close")
  done:SetScript("OnClick", function() EGMOptionsFrame:Hide() end)

  local reset = CreateFrame("Button", "EGMOptionsResetWindowBtn", f, "UIPanelButtonTemplate")
  reset:SetWidth(80); reset:SetHeight(22)
  reset:SetPoint("RIGHT", done, "LEFT", 0, 0)
  reset:SetText("Reset")
  reset:SetScript("OnClick", function() if EGM.UI and EGM.UI.resetWindow then EGM.UI.resetWindow() end end)
  tip(reset, "Reset", "Window position and scale back to default: the EGM and options windows return to their default place and the UI scale is set to 1.0.")
  local defs = CreateFrame("Button", "EGMOptionsDefaultsBtn", f, "UIPanelButtonTemplate")
  defs:SetWidth(80); defs:SetHeight(22)
  defs:SetPoint("RIGHT", reset, "LEFT", 0, 0)
  defs:SetText("Defaults")
  defs:SetScript("OnClick", function() EGM.Options.resetDefaults() end)
  tip(defs, "Defaults", "Resets all options on this page and the UI scale to their default values.")

  frame = f
  if UISpecialFrames then table.insert(UISpecialFrames, "EGMOptionsFrame") end
  f:Hide()
end

function O.refresh() refresh() end

-- recenters the options window
function O.center()
  if frame then frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
end

-- "Defaults" button: every option back to its default and the scale to 1.0; checkboxes and slider follow
function O.resetDefaults()
  local c = char()
  for k, v in pairs(EGM.DB.defaults or {}) do c[k] = v end
  O.setScale(EGM.Util.SCALE_DEFAULT)
  if EGM.Minimap and EGM.Minimap.update then EGM.Minimap.update() end
  refresh()
end

-- scales this window to the saved value (called by UI.setScale and on build)
function O.applyScale()
  if frame then frame:SetScale(EGM.Util.getScale()) end
  if slider then refresh() end -- slider position and label follow every path (load, restore, UI.setScale)
end

-- slider callback: saves, scales all EGM windows; returns the snapped value
function O.setScale(v)
  if EGM.UI and EGM.UI.setScale then return EGM.UI.setScale(v) end
  local s = EGM.Util.saveScale(v)
  O.applyScale()
  return s
end

function O.toggle()
  build()
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

function O.show()
  build()
  frame:Show()
end
