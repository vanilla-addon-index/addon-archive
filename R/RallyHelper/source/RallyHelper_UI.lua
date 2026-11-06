-- RallyHelper_UI v 1.4.7
RHGlobal = RHGlobal or {}
RHGlobal.Unconfirmed = RHGlobal.Unconfirmed or {}

local ui
local settingsUI
local firstTimeUI
local unconfUI

local BUFF_ICONS = {
  ONY = "Interface\\Icons\\INV_Misc_Head_Dragon_Red",
  NEF = "Interface\\Icons\\INV_Misc_Head_Dragon_Blue",
  WB = "Interface\\Icons\\Spell_Nature_BloodLust",
  ZG = "Interface\\Icons\\Ability_Mount_JungleTiger",
  DMF = "Interface\\Icons\\INV_Misc_Ticket_Tarot_01",
}

local ONY_ICON = BUFF_ICONS.ONY
local NEF_ICON = BUFF_ICONS.NEF
local WB_ICON = BUFF_ICONS.WB
local ZG_ICON = BUFF_ICONS.ZG
local DMF_ICON = BUFF_ICONS.DMF

local DEFAULT_W = 460
local DEFAULT_H = 200
local DEFAULT_SCALE = 1.0
local floor = math.floor

local function GetCharDB()
  return RallyHelperCharDB or {}
end

local function GetDB()
  local realm = GetRealmName() or "UnknownRealm"
  if type(RallyHelperDB) == "table" and RallyHelperDB[realm] then
    return RallyHelperDB[realm]
  end
  return RallyHelperDB or {}
end

local function IsLocked()
  local cdb = GetCharDB()
  return cdb and cdb.locked
end

local function FormatTime(sec)
  if not sec or sec <= 0 then return "ready", 0 end
  local h = floor(sec / 3600)
  local m = floor((sec - h * 3600) / 60)
  if h > 0 then return h .. "h " .. m .. "m", sec end
  return m .. "m", sec
end

local function Colorize(text, sec)
  if not sec or sec <= 0 then
    return "|cff33ff33" .. text .. "|r"
  elseif sec < 1800 then
    return "|cffffff33" .. text .. "|r"
  else
    return "|cffff3333" .. text .. "|r"
  end
end

local function FormatAgo(ts)
  if not ts then return "unknown" end
  local d = time() - ts
  if d < 60 then return d .. "s ago" end
  if d < 3600 then return floor(d / 60) .. "m ago" end
  local h = floor(d / 3600)
  local m = floor((d - h * 3600) / 60)
  return h .. "h " .. m .. "m ago"
end

local function EnsureUISettings()
  local cdb = GetCharDB()
  cdb.ui = cdb.ui or {}
  cdb.ui.w = tonumber(cdb.ui.w) or DEFAULT_W
  cdb.ui.h = tonumber(cdb.ui.h) or DEFAULT_H
  cdb.ui.scale = tonumber(cdb.ui.scale) or DEFAULT_SCALE
  return cdb.ui
end

local function ShouldShowEvent(ev)
  if type(RH_ShouldShowEvent) == "function" then
    return RH_ShouldShowEvent(ev)
  end
  return true
end

function ApplyLayout()
  if not ui or not ui.initialized then return end

  local W = ui:GetWidth()
  local H = ui:GetHeight()
  local PAD = 20
  local filter = RH_GetFactionFilter()
  local COL_W = (W - PAD*3) / 2

  if ui.onyIcon then ui.onyIcon:Hide() end
  if ui.nefIcon then ui.nefIcon:Hide() end

  ui.onyTitle:ClearAllPoints()
  ui.nefTitle:ClearAllPoints()

  if filter == "BOTH" then
    ui.onyTitle:SetPoint("TOPLEFT", PAD, -36)
    ui.onyTitle:SetWidth(COL_W - 10)
    ui.onyTitle:SetText("Horde")
    ui.onyTitle:Show()

    ui.nefTitle:SetPoint("TOPLEFT", PAD + COL_W + PAD, -36)
    ui.nefTitle:SetWidth(COL_W - 10)
    ui.nefTitle:SetText("Alliance")
    ui.nefTitle:Show()
  else
    ui.onyTitle:SetPoint("TOPLEFT", PAD, -36)
    ui.onyTitle:SetWidth(W - PAD*2)
    ui.onyTitle:SetText(filter == "HORDE" and "Horde" or "Alliance")
    ui.onyTitle:Show()
    ui.nefTitle:Hide()
  end

  local function PlaceIcon(row)
    if row and row.icon then
      row.icon:ClearAllPoints()
      row.icon:SetPoint("LEFT", row, "LEFT", -20, 0)
      row.icon:Show()
    end
  end

  local yLeft = -68
  local yRight = -68

  local function PlaceLeft(row, width)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", PAD, yLeft)
    row:SetWidth(width)
    row:Show()
    PlaceIcon(row)
    yLeft = yLeft - 22
  end

  local function PlaceRight(row, width)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", PAD + COL_W + PAD, yRight)
    row:SetWidth(width)
    row:Show()
    PlaceIcon(row)
    yRight = yRight - 22
  end

  local function PlaceSingle(row)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", PAD, yLeft)
    row:SetWidth(W - PAD*2)
    row:Show()
    PlaceIcon(row)
    yLeft = yLeft - 22
  end

  for _, r in pairs({ui.onySW, ui.onyOG, ui.nefSW, ui.nefOG, ui.zg, ui.dmf, ui.wb}) do
    if r then r:Hide() end
  end

  if filter == "BOTH" then
    if ui.onyOG and ShouldShowEvent("ONY_H") then PlaceLeft(ui.onyOG, COL_W) end
    if ui.nefOG and ShouldShowEvent("NEF_H") then PlaceLeft(ui.nefOG, COL_W) end
    if ui.wb and ShouldShowEvent("WB") then PlaceLeft(ui.wb, COL_W) end
    if ui.onySW and ShouldShowEvent("ONY_A") then PlaceRight(ui.onySW, COL_W) end
    if ui.nefSW and ShouldShowEvent("NEF_A") then PlaceRight(ui.nefSW, COL_W) end

    local y = math.min(yLeft, yRight) - 20
    if ui.zg and ShouldShowEvent("ZG") then
      ui.zg:ClearAllPoints()
      ui.zg:SetPoint("TOPLEFT", PAD, y)
      ui.zg:SetWidth(W - PAD*2)
      ui.zg:Show()
      PlaceIcon(ui.zg)
      y = y - 24
    end
    if ui.dmf and ShouldShowEvent("DMF") then
      ui.dmf:ClearAllPoints()
      ui.dmf:SetPoint("TOPLEFT", PAD, y)
      ui.dmf:SetWidth(W - PAD*2)
      ui.dmf:Show()
      PlaceIcon(ui.dmf)
      y = y - 24
    end

    local needed = math.abs(y) + 40
    if needed > H then ui:SetHeight(needed) end
    return
  end

  if filter == "HORDE" then
    if ui.onyOG and ShouldShowEvent("ONY_H") then PlaceSingle(ui.onyOG) end
    if ui.nefOG and ShouldShowEvent("NEF_H") then PlaceSingle(ui.nefOG) end
    if ui.wb and ShouldShowEvent("WB") then PlaceSingle(ui.wb) end
  else
    if ui.onySW and ShouldShowEvent("ONY_A") then PlaceSingle(ui.onySW) end
    if ui.nefSW and ShouldShowEvent("NEF_A") then PlaceSingle(ui.nefSW) end
  end

  if ui.zg and ShouldShowEvent("ZG") then PlaceSingle(ui.zg) end
  if ui.dmf and ShouldShowEvent("DMF") then PlaceSingle(ui.dmf) end

  local needed = math.abs(yLeft) + 40
  if needed > H then ui:SetHeight(needed) end
end

function UpdateTexts()
  if not ui or not ui.initialized then return end

  local db = GetDB()
  if not db then return end

  local t = time()

  local ONY_CD = 2 * 60 * 60
  local NEF_CD = 2 * 60 * 60
  local WB_CD  = 3 * 60 * 60

  local function FormatUnconfirmed(ev, label)
    local u = RHGlobal.Unconfirmed[ev]
    if not u then return nil end
    return "|cFFAAAAAA" .. label .. ": unconfirmed (" .. FormatAgo(u.ts) .. ")|r"
  end

  if ui.onySW then
    ui.onySW:SetText(
      FormatUnconfirmed("ONY_A", "Onyxia") or
      ("Onyxia: " .. Colorize(FormatTime(db.lastOnyA and (db.lastOnyA + ONY_CD - t) or 0)))
    )
  end

  if ui.onyOG then
    ui.onyOG:SetText(
      FormatUnconfirmed("ONY_H", "Onyxia") or
      ("Onyxia: " .. Colorize(FormatTime(db.lastOnyH and (db.lastOnyH + ONY_CD - t) or 0)))
    )
  end

  if ui.nefSW then
    ui.nefSW:SetText(
      FormatUnconfirmed("NEF_A", "Nefarian") or
      ("Nefarian: " .. Colorize(FormatTime(db.lastNefA and (db.lastNefA + NEF_CD - t) or 0)))
    )
  end

  if ui.nefOG then
    ui.nefOG:SetText(
      FormatUnconfirmed("NEF_H", "Nefarian") or
      ("Nefarian: " .. Colorize(FormatTime(db.lastNefH and (db.lastNefH + NEF_CD - t) or 0)))
    )
  end

  if ui.zg then
    ui.zg:SetText("ZG last drop: " .. (db.lastZG and FormatAgo(db.lastZG) or "unknown"))
  end

  if ui.dmf then
    ui.dmf:SetText("DMF: " .. (db.lastDMFTime and (FormatAgo(db.lastDMFTime) .. " in " .. (db.lastDMFZone or "unknown")) or "unknown"))
  end

  if ui.wb then
    ui.wb:SetText(
      FormatUnconfirmed("WB", "Rend") or
      ("Rend: " .. Colorize(FormatTime(db.lastWB and (db.lastWB + WB_CD - t) or 0)))
    )
  end
end

_G.RallyHelper_UpdateUI = function()
  if ui then
    ApplyLayout()
    UpdateTexts()
  end
end

local function CreateUI()
  local S = EnsureUISettings()
  ui = ui or CreateFrame("Frame", "RH_UIFrame", UIParent)

  ui:SetWidth(tonumber(S.w) or DEFAULT_W)
  ui:SetHeight(tonumber(S.h) or DEFAULT_H)
  ui:SetClampedToScreen(true)
  ui:SetMovable(true)
  ui:SetScale(tonumber(S.scale) or DEFAULT_SCALE)

  if S.x and S.y then
    ui:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", S.x, S.y)
  else
    ui:SetPoint("CENTER", UIParent, "CENTER")
  end

  ui.bgFrame = ui.bgFrame or CreateFrame("Frame", nil, ui)
  ui.bgFrame:SetAllPoints()
  ui.bgFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "",
  })
  ui.bgFrame:SetBackdropColor(0, 0, 0, 0.02)

  if not ui.initialized then
    ui.initialized = true

    ui.onyIcon = ui:CreateTexture(nil, "ARTWORK")
    ui.onyIcon:SetTexture(ONY_ICON)
    ui.onyIcon:SetWidth(24)
    ui.onyIcon:SetHeight(24)

    ui.nefIcon = ui:CreateTexture(nil, "ARTWORK")
    ui.nefIcon:SetTexture(NEF_ICON)
    ui.nefIcon:SetWidth(24)
    ui.nefIcon:SetHeight(24)

    local function CreateFS(size, r, g, b)
      local f = ui:CreateFontString(nil, "OVERLAY")
      f:SetFont("Fonts\\FRIZQT__.TTF", size or 16, "THICKOUTLINE")
      f:SetShadowColor(0, 0, 0, 0.95)
      f:SetShadowOffset(2, -2)
      if r then f:SetTextColor(r, g, b) end
      f:SetJustifyH("LEFT")
      return f
    end

    ui.onyTitle = CreateFS(18, 1, 1, 1)
    ui.nefTitle = CreateFS(18, 1, 1, 1)

    ui.onySW = CreateFS(15, 0.4, 0.8, 1)
    ui.onyOG = CreateFS(15, 1, 0.4, 0.4)
    ui.nefSW = CreateFS(15, 0.4, 0.8, 1)
    ui.nefOG = CreateFS(15, 1, 0.4, 0.4)
    ui.zg     = CreateFS(14.5, 0.2, 1, 0.2)
    ui.dmf    = CreateFS(14.5, 0.9, 0.6, 1)
    ui.wb     = CreateFS(14.5, 1, 0.8, 0.2)

    local function CreateBuffIcon(tex)
      local t = ui:CreateTexture(nil, "ARTWORK")
      t:SetTexture(tex)
      t:SetWidth(16)
      t:SetHeight(16)
      t:Hide()
      return t
    end

    ui.onySW.icon = CreateBuffIcon(BUFF_ICONS.ONY)
    ui.onyOG.icon = CreateBuffIcon(BUFF_ICONS.ONY)
    ui.nefSW.icon = CreateBuffIcon(BUFF_ICONS.NEF)
    ui.nefOG.icon = CreateBuffIcon(BUFF_ICONS.NEF)
    ui.zg.icon    = CreateBuffIcon(BUFF_ICONS.ZG)
    ui.dmf.icon   = CreateBuffIcon(BUFF_ICONS.DMF)
    ui.wb.icon    = CreateBuffIcon(BUFF_ICONS.WB)

    ui:EnableMouse(true)
    ui:RegisterForDrag("LeftButton")

    ui:SetScript("OnDragStart", function()
      if not IsLocked() then ui:StartMoving() end
    end)

    ui:SetScript("OnDragStop", function()
      ui:StopMovingOrSizing()
      local S = EnsureUISettings()
      S.x = ui:GetLeft()
      S.y = ui:GetBottom()
    end)

    ui:SetScript("OnEnter", function() ui.bgFrame:SetBackdropColor(0, 0, 0, 0.15) end)
    ui:SetScript("OnLeave", function() ui.bgFrame:SetBackdropColor(0, 0, 0, 0.02) end)

    ui:SetScript("OnUpdate", function()
      if (GetTime() - (ui._last or 0)) > 0.4 then
        ui._last = GetTime()
        UpdateTexts()
      end
    end)
  end

  ApplyLayout()
  UpdateTexts()
end

function CreateFirstTimeSetup()
  if firstTimeUI then return end
  firstTimeUI = CreateFrame("Frame", "RallyHelperFirstTimeFrame", UIParent)
  firstTimeUI:SetWidth(420)
  firstTimeUI:SetHeight(280)
  firstTimeUI:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
  firstTimeUI:SetFrameStrata("FULLSCREEN_DIALOG")
  firstTimeUI:EnableMouse(true)

  firstTimeUI:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left=11, right=12, top=12, bottom=11 }
  })

  local title = firstTimeUI:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -20)
  title:SetText("RallyHelper - Welcome!")

  local text = firstTimeUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("TOP", 0, -55)
  text:SetWidth(380)
  text:SetJustifyH("LEFT")
  text:SetText(
    "Welcome to RallyHelper!\n\n" ..
    "Please select which world buffs you want to track:\n\n" ..
    "|cff33ff99Horde|r: Onyxia, Nefarian, Warchief's Blessing, ZG, DMF\n" ..
    "|cff3399ffAlliance|r: Onyxia, Nefarian, ZG, DMF\n" ..
    "|cffffffffBoth|r: All buffs from both factions\n\n" ..
    "You can change this later with /rally settings"
  )

  local yPos = -165

  local hordeBtn = CreateFrame("Button", nil, firstTimeUI, "UIPanelButtonTemplate")
  hordeBtn:SetWidth(110) hordeBtn:SetHeight(28) hordeBtn:SetPoint("TOP", -120, yPos)
  hordeBtn:SetText("|cffff3333Horde|r")
  hordeBtn:SetScript("OnClick", function()
    if type(RH_SetFactionFilter) == "function" then RH_SetFactionFilter("HORDE") end
    firstTimeUI:Hide()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RallyHelper]|r Faction filter set to Horde")
    if ui then ApplyLayout() end
  end)

  local allianceBtn = CreateFrame("Button", nil, firstTimeUI, "UIPanelButtonTemplate")
  allianceBtn:SetWidth(110) allianceBtn:SetHeight(28) allianceBtn:SetPoint("TOP", 0, yPos)
  allianceBtn:SetText("|cff3399ffAlliance|r")
  allianceBtn:SetScript("OnClick", function()
    if type(RH_SetFactionFilter) == "function" then RH_SetFactionFilter("ALLIANCE") end
    firstTimeUI:Hide()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RallyHelper]|r Faction filter set to Alliance")
    if ui then ApplyLayout() end
  end)

  local bothBtn = CreateFrame("Button", nil, firstTimeUI, "UIPanelButtonTemplate")
  bothBtn:SetWidth(110) bothBtn:SetHeight(28) bothBtn:SetPoint("TOP", 120, yPos)
  bothBtn:SetText("Both")
  bothBtn:SetScript("OnClick", function()
    if type(RH_SetFactionFilter) == "function" then RH_SetFactionFilter("BOTH") end
    firstTimeUI:Hide()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RallyHelper]|r Faction filter set to Both")
    if ui then ApplyLayout() end
  end)
end

_G.RallyHelper_ShowFirstTimeSetup = function()
  if not firstTimeUI then CreateFirstTimeSetup() end
  firstTimeUI:Show()
end

function CreateSettingsUI()
  if settingsUI then return end

  local S = EnsureUISettings()
  local DB = GetDB()

  settingsUI = CreateFrame("Frame", "RallyHelperSettingsFrame", UIParent)
  settingsUI:SetWidth(480)
  settingsUI:SetHeight(420)
  settingsUI:SetPoint("CENTER", UIParent, "CENTER")
  settingsUI:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left=11, right=12, top=12, bottom=11 }
  })
  settingsUI:EnableMouse(true)
  settingsUI:SetMovable(true)
  settingsUI:RegisterForDrag("LeftButton")
  settingsUI:SetScript("OnDragStart", function() settingsUI:StartMoving() end)
  settingsUI:SetScript("OnDragStop", function() settingsUI:StopMovingOrSizing() end)

  local function CreateFS(parent, size, r, g, b)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont("Fonts\\FRIZQT__.TTF", size or 13, "OUTLINE")
    if r then f:SetTextColor(r, g, b) end
    f:SetJustifyH("LEFT")
    f:SetShadowColor(0, 0, 0, 1)
    f:SetShadowOffset(1, -1)
    return f
  end

  local title = settingsUI:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -18)
  title:SetText("RallyHelper Settings")

  local factionLabel = CreateFS(settingsUI, 14, 1, 1, 1)
  factionLabel:SetPoint("TOPLEFT", 25, -55)
  factionLabel:SetText("Faction Filter:")

  local currentFilter = CreateFS(settingsUI, 13, 0.8, 0.8, 0.8)
  currentFilter:SetPoint("TOPLEFT", 25, -75)

  local function UpdateFilterDisplay()
    local filter = "Both"
    if type(RH_GetFactionFilter) == "function" then 
      filter = RH_GetFactionFilter() 
    end
    local txt = filter
    if filter == "HORDE" then txt = "|cffff3333Horde|r"
    elseif filter == "ALLIANCE" then txt = "|cff3399ffAlliance|r" end
    currentFilter:SetText("Current: " .. txt)
  end
  UpdateFilterDisplay()

  local yPos = -100

  local hordeBtn = CreateFrame("Button", nil, settingsUI, "UIPanelButtonTemplate")
  hordeBtn:SetWidth(100) hordeBtn:SetHeight(24) hordeBtn:SetPoint("TOPLEFT", 25, yPos)
  hordeBtn:SetText("Horde")
  hordeBtn:SetScript("OnClick", function()
    if type(RH_SetFactionFilter) == "function" then RH_SetFactionFilter("HORDE") end
    UpdateFilterDisplay()
    ApplyLayout()
    UpdateTexts()
  end)

  local allianceBtn = CreateFrame("Button", nil, settingsUI, "UIPanelButtonTemplate")
  allianceBtn:SetWidth(100) allianceBtn:SetHeight(24) allianceBtn:SetPoint("TOPLEFT", 135, yPos)
  allianceBtn:SetText("Alliance")
  allianceBtn:SetScript("OnClick", function()
    if type(RH_SetFactionFilter) == "function" then RH_SetFactionFilter("ALLIANCE") end
    UpdateFilterDisplay()
    ApplyLayout()
    UpdateTexts()
  end)

  local bothBtn = CreateFrame("Button", nil, settingsUI, "UIPanelButtonTemplate")
  bothBtn:SetWidth(100) bothBtn:SetHeight(24) bothBtn:SetPoint("TOPLEFT", 245, yPos)
  bothBtn:SetText("Both")
  bothBtn:SetScript("OnClick", function()
    if type(RH_SetFactionFilter) == "function" then RH_SetFactionFilter("BOTH") end
    UpdateFilterDisplay()
    ApplyLayout()
    UpdateTexts()
  end)

  local uiLabel = CreateFS(settingsUI, 14, 1, 1, 1)
  uiLabel:SetPoint("TOPLEFT", 25, -145)
  uiLabel:SetText("UI Settings:")

  local widthText = CreateFS(settingsUI, 13)
  widthText:SetPoint("TOPLEFT", 25, -170)
  widthText:SetText("Width")

  local widthSlider = CreateFrame("Slider", nil, settingsUI, "OptionsSliderTemplate")
  widthSlider:SetPoint("TOPLEFT", 25, -188)
  widthSlider:SetWidth(420)
  widthSlider:SetMinMaxValues(300, 700)
  widthSlider:SetValueStep(10)
  widthSlider:SetValue(S.w or DEFAULT_W)
  widthSlider:SetScript("OnValueChanged", function()
    local v = floor(widthSlider:GetValue() + 0.5)
    S.w = v
    if ui then
      ui:SetWidth(v)
      ApplyLayout()
    end
  end)

  local heightText = CreateFS(settingsUI, 13)
  heightText:SetPoint("TOPLEFT", 25, -225)
  heightText:SetText("Height")

  local heightSlider = CreateFrame("Slider", nil, settingsUI, "OptionsSliderTemplate")
  heightSlider:SetPoint("TOPLEFT", 25, -243)
  heightSlider:SetWidth(420)
  heightSlider:SetMinMaxValues(140, 400)
  heightSlider:SetValueStep(10)
  heightSlider:SetValue(S.h or DEFAULT_H)
  heightSlider:SetScript("OnValueChanged", function()
    local v = floor(heightSlider:GetValue() + 0.5)
    S.h = v
    if ui then
      ui:SetHeight(v)
      ApplyLayout()
    end
  end)

  local scaleText = CreateFS(settingsUI, 13)
  scaleText:SetPoint("TOPLEFT", 25, -280)
  scaleText:SetText("Scale")

  local scaleSlider = CreateFrame("Slider", nil, settingsUI, "OptionsSliderTemplate")
  scaleSlider:SetPoint("TOPLEFT", 25, -298)
  scaleSlider:SetWidth(420)
  scaleSlider:SetMinMaxValues(0.4, 1.5)
  scaleSlider:SetValueStep(0.05)
  scaleSlider:SetValue(S.scale or DEFAULT_SCALE)
  scaleSlider:SetScript("OnValueChanged", function()
    local v = floor(scaleSlider:GetValue() * 100 + 0.5) / 100
    S.scale = v
    if ui then ui:SetScale(v) end
  end)

  local lockCB = CreateFrame("CheckButton", nil, settingsUI, "UICheckButtonTemplate")
  lockCB:SetPoint("TOPLEFT", 25, -335)
  lockCB:SetChecked(IsLocked())
  lockCB.text = lockCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lockCB.text:SetPoint("LEFT", lockCB, "RIGHT", 4, 0)
  lockCB.text:SetText("Lock UI Position")
  lockCB:SetScript("OnClick", function()
    local cdb = GetCharDB()
    cdb.locked = lockCB:GetChecked()
  end)

  local soundCB = CreateFrame("CheckButton", nil, settingsUI, "UICheckButtonTemplate")
  soundCB:SetPoint("TOPLEFT", 25, -365)
  soundCB:SetChecked(DB.rhSounds and DB.rhSounds.enabled)
  soundCB.text = soundCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  soundCB.text:SetPoint("LEFT", soundCB, "RIGHT", 4, 0)
  soundCB.text:SetText("Enable Buff Sounds")
  soundCB:SetScript("OnClick", function()
    if DB.rhSounds then 
      DB.rhSounds.enabled = soundCB:GetChecked() 
    end
  end)

  local close = CreateFrame("Button", nil, settingsUI, "UIPanelButtonTemplate")
  close:SetWidth(100) 
  close:SetHeight(26) 
  close:SetPoint("BOTTOM", 0, 18)
  close:SetText("Close")
  close:SetScript("OnClick", function() settingsUI:Hide() end)
end

_G.RallyHelper_ToggleSettings = function()
  if not settingsUI then CreateSettingsUI() end
  if settingsUI:IsShown() then settingsUI:Hide() else settingsUI:Show() end
end

RallyHelperDB = RallyHelperDB or {}
RallyHelperDB.unconfFilter = RallyHelperDB.unconfFilter or {
  ALLIANCE = true,
  HORDE = true,
  ZG = true,
  WB = true,
}

local FILTER = RallyHelperDB.unconfFilter
local MAX_UNCONFIRMED = 20

function CreateUnconfirmedUI()
  if unconfUI then return end

  unconfUI = CreateFrame("Frame", "RallyHelperUnconfirmedFrame", UIParent)
  unconfUI:SetWidth(340)
  unconfUI:SetHeight(260)
  unconfUI:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  unconfUI:SetFrameStrata("DIALOG")
  unconfUI:SetMovable(true)
  unconfUI:EnableMouse(true)
  unconfUI:RegisterForDrag("LeftButton")
  unconfUI:SetScript("OnDragStart", function() unconfUI:StartMoving() end)
  unconfUI:SetScript("OnDragStop", function() unconfUI:StopMovingOrSizing() end)

  unconfUI:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left=4, right=4, top=4, bottom=4 }
  })
  unconfUI:SetBackdropColor(0, 0, 0, 0.4)

  local function AddCheck(label, key, x)
    local cb = CreateFrame("CheckButton", nil, unconfUI, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", unconfUI, "TOPLEFT", x, -6)
    cb:SetChecked(FILTER[key])

    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.text:SetText(label)

    cb:SetScript("OnClick", function()
      FILTER[key] = cb:GetChecked()
      RallyHelper_UpdateUnconfirmed()
    end)
  end

  AddCheck("Alliance", "ALLIANCE", 10)
  AddCheck("Horde",    "HORDE",    90)
  AddCheck("ZG",       "ZG",       170)
  AddCheck("Warchief", "WB",       230)

  local scroll = CreateFrame("ScrollFrame", nil, unconfUI)
  scroll:SetPoint("TOPLEFT", unconfUI, "TOPLEFT", 8, -32)
  scroll:SetPoint("BOTTOMRIGHT", unconfUI, "BOTTOMRIGHT", -28, 8)

  local child = CreateFrame("Frame", nil, scroll)
  child:SetWidth(280)
  child:SetHeight(600)
  scroll:SetScrollChild(child)

  unconfUI.child = child
  unconfUI.scroll = scroll

  local slider = CreateFrame("Slider", nil, unconfUI, "UIPanelScrollBarTemplate")
  slider:SetPoint("TOPRIGHT", unconfUI, "TOPRIGHT", -4, -40)
  slider:SetPoint("BOTTOMRIGHT", unconfUI, "BOTTOMRIGHT", -4, 20)
  slider:SetMinMaxValues(0, 200)
  slider:SetValueStep(10)
  slider:SetWidth(16)

  slider:SetScript("OnValueChanged", function(_, v)
    if not unconfUI.scroll then return end
    local child = unconfUI.scroll:GetScrollChild()
    if not child then return end
    if v == nil then return end
    if v < 0 then v = 0 end
    unconfUI.scroll:SetVerticalScroll(v)
  end)

  scroll:SetScript("OnMouseWheel", function(_, delta)
    if not unconfUI.slider then return end
    local new = unconfUI.slider:GetValue() - delta * 20
    if new < 0 then new = 0 end
    unconfUI.slider:SetValue(new)
  end)
  
  unconfUI.slider = slider
end

function RallyHelper_UpdateUnconfirmed()
  if not unconfUI then return end

  local child = unconfUI.child
  if not child then return end

  for _, f in ipairs(child.lines or {}) do f:Hide() end
  child.lines = child.lines or {}

  local list = {}
  for ev, data in pairs(RHGlobal.Unconfirmed) do
    table.insert(list, { ev = ev, ts = data.ts, zone = data.zone })
  end

  table.sort(list, function(a, b) return a.ts > b.ts end)

  while table.getn(list) > MAX_UNCONFIRMED do
    table.remove(list)
  end

  local i = 0

  for _, entry in ipairs(list) do
    local ev = entry.ev
    local ts = entry.ts

    local label, color, category

    if ev == "ONY_A" then
      label = "Ony_Alliance" color = "|cff3399ff" category = "ALLIANCE"
    elseif ev == "NEF_A" then
      label = "Nef_Alliance" color = "|cff3399ff" category = "ALLIANCE"
    elseif ev == "ONY_H" then
      label = "Ony_Horde" color = "|cffff3333" category = "HORDE"
    elseif ev == "NEF_H" then
      label = "Nef_Horde" color = "|cffff3333" category = "HORDE"
    elseif ev == "ZG" then
      label = "ZG" color = "|cff33ff33" category = "ZG"
    elseif ev == "WB" then
      label = "Warchief" color = "|cffffaa33" category = "WB"
    else
      label = ev color = "|cFFAAAAAA" category = "OTHER"
    end

    if FILTER[category] then
      i = i + 1

      local line = child.lines[i]
      if not line then
        line = child:CreateFontString(nil, "OVERLAY")
        line:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        line:SetJustifyH("LEFT")
        line:SetShadowColor(0, 0, 0, 1)
        line:SetShadowOffset(1, -1)
        child.lines[i] = line
      end

      line:SetPoint("TOPLEFT", 0, - (i - 1) * 20)

      line:SetText(
        color .. label .. "|r" ..
        "  |cFFAAAAAA" .. (verify and verify[ev] and table.getn(verify[ev]) or 0) .. "/2 Unconfirmed  " .. FormatAgo(ts) .. "|r"
      )
      line:Show()
    end
  end

  if i == 0 then
    unconfUI.slider:SetMinMaxValues(0, 0)
    unconfUI.slider:SetValue(0)
    return
  end

  unconfUI.slider:SetMinMaxValues(0, math.max(0, i * 20 - 200))
end

function RallyHelper_ToggleUnconfirmed()
  if not unconfUI then CreateUnconfirmedUI() end
  if unconfUI:IsShown() then
    unconfUI:Hide()
  else
    RallyHelper_UpdateUnconfirmed()
    unconfUI:Show()
  end
end

_G.RallyHelper_ToggleUI = function()
  if not ui then CreateUI() end
  if ui:IsShown() then ui:Hide() else ui:Show() end
end

_G.RH_CreateUI = CreateUI
