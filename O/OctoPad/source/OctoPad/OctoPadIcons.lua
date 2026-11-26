--[[
OctoPad Icons  -  choose an icon for a system-action button, like the macro icon dialog.

  * grid of icons (the same list the macro dialog uses: GetMacroIconInfo), 48 per page
  * search box filters by name (try "heal", "sword", "bag")
  * type an icon name or path for anything not in the list
  * click an icon to select it, then Okay
  * "Apply to all buttons using this action" also changes the radial menu icon
  * "Default icon" removes your choice

Open it from menu > Slots (the small icon next to a slot's Game action), or with
/opad icon <slot> <IconName|default>.
]]

local OP = OctoPad

local picker
local fullList, lowerList, filtered
local page = 1
local PER = 48
local COLS = 8

-- used when the client has no macro icon list, and always merged in
local FALLBACK = {
  "INV_Misc_QuestionMark", "Spell_Nature_Levitate", "Ability_Rogue_Sprint", "Spell_Nature_Sleep",
  "Spell_Holy_LayOnHands", "Spell_ChargeNegative", "Spell_ChargePositive", "Ability_Hunter_EagleEye",
  "Ability_Marksmanship", "Spell_Holy_Heal", "Ability_Hunter_BeastCall", "Ability_SteelMelee",
  "Ability_Warrior_Disarm", "Ability_GhoulFrenzy", "Spell_Holy_MindVision", "INV_Misc_Map_01",
  "INV_Misc_Bag_08", "INV_Shirt_White_01", "INV_Misc_Book_09", "Ability_Warrior_StrengthOfArms",
  "INV_Misc_Note_01", "INV_Misc_Note_02", "INV_Letter_15", "INV_Misc_Gear_01", "INV_Misc_Key_03",
  "Spell_Holy_PrayerOfHealing", "Spell_Shadow_AntiShadow", "Ability_Hunter_MarkedForDeath",
  "Spell_Holy_CircleOfRenewal", "Spell_Nature_HealingTouch", "Spell_Holy_PowerWordShield",
  "Spell_Fire_FlameBolt", "Spell_Frost_FrostBolt02", "Spell_Shadow_ShadowBolt", "Spell_Nature_Lightning",
  "Ability_Rogue_Feint", "Ability_Stealth", "Ability_Warrior_Charge", "Ability_Whirlwind",
  "INV_Sword_04", "INV_Shield_05", "INV_Potion_54", "INV_Potion_51", "INV_Misc_Food_15",
  "INV_Misc_Bandage_01", "INV_Hammer_20", "INV_Misc_Gem_01", "INV_Misc_Coin_01",
}

local function NormalizeIcon(t)
  if not t or t == "" then return nil end
  if not string.find(t, "\\", 1, true) and not string.find(t, "/", 1, true) then
    t = "Interface\\Icons\\" .. t
  end
  return t
end

local function ShortName(t)
  if not t then return "" end
  local s = string.gsub(t, "^Interface\\Icons\\", "")
  return s
end

local function BuildList()
  if fullList then return end
  fullList = {}
  lowerList = {}
  local seen = {}
  local function add(t)
    t = NormalizeIcon(t)
    if t and not seen[t] then
      seen[t] = true
      table.insert(fullList, t)
    end
  end
  local n = 0
  if GetNumMacroIcons then n = GetNumMacroIcons() or 0 end
  local i
  if n > 0 and GetMacroIconInfo then
    for i = 1, n do add(GetMacroIconInfo(i)) end
  end
  for i = 1, table.getn(FALLBACK) do add(FALLBACK[i]) end
  local id
  for id in pairs(OP.ACTIONS) do add(OP.ACTIONS[id].icon) end
  for i = 1, table.getn(fullList) do lowerList[i] = string.lower(fullList[i]) end
end

local function ApplyFilter()
  BuildList()
  local text = string.lower(picker.search:GetText() or "")
  if text == "" then
    filtered = fullList
  else
    filtered = {}
    local i
    for i = 1, table.getn(fullList) do
      if string.find(lowerList[i], text, 1, true) then table.insert(filtered, fullList[i]) end
    end
  end
  page = 1
end

local function ShowPreview()
  local t = picker.selected
  if t then
    picker.preview:SetTexture(t)
    picker.preview:Show()
    picker.path:SetText(ShortName(t))
  else
    picker.preview:Hide()
    picker.path:SetText("(none selected)")
  end
end

local function ShowPage()
  local total = table.getn(filtered)
  local pages = math.max(1, math.ceil(total / PER))
  if page > pages then page = pages end
  if page < 1 then page = 1 end
  local k
  for k = 1, PER do
    local b = picker.btns[k]
    local t = filtered[(page - 1) * PER + k]
    if t then
      b.tex = t
      b.icon:SetTexture(t)
      if t == picker.selected then OP.BD(b):SetBackdropBorderColor(1, .85, 0, 1) else OP.BD(b):SetBackdropBorderColor(.35, .35, .35, 1) end
      b:Show()
    else
      b.tex = nil
      b:Hide()
    end
  end
  picker.pageText:SetText("Page " .. page .. " / " .. pages .. "   (" .. total .. " icons)")
end

local function Apply(clear)
  local cfg = OP.cfg
  local n = picker.slot
  local id = OP.ProxyFor(n)
  local all = picker.all:GetChecked()
  if clear then
    cfg.icons[n] = nil
    if all and id then cfg.aicons[id] = nil end
  else
    local t = picker.selected
    if not t then return end
    if all and id then
      cfg.aicons[id] = t
      cfg.icons[n] = nil
    else
      cfg.icons[n] = t
    end
  end
  picker:Hide()
  OP.NotifyChanged()
end

local function Build()
  if picker then return end
  picker = CreateFrame("Frame", "OctoPadIconPicker", UIParent)
  picker:SetWidth(372)
  picker:SetHeight(490)
  picker:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
  picker:SetFrameStrata("FULLSCREEN_DIALOG")
  picker:SetMovable(true)
  picker:EnableMouse(true)
  picker:EnableMouseWheel(true)
  picker:SetClampedToScreen(true)
  picker:RegisterForDrag("LeftButton")
  picker:SetScript("OnDragStart", function() this:StartMoving() end)
  picker:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  if not OP.Round(picker, .92) then
    picker:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end
  picker:Hide()
  tinsert(UISpecialFrames, "OctoPadIconPicker")

  picker.title = picker:CreateFontString(nil, "OVERLAY")
  picker.title:SetFont(OP.Font(), 13, "OUTLINE")
  picker.title:SetPoint("TOP", picker, "TOP", 0, -14)

  local close = CreateFrame("Button", "OctoPadIconPickerClose", picker, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -6, -6)

  -- search
  local sl = picker:CreateFontString(nil, "OVERLAY")
  sl:SetFont(OP.Font(), 11)
  sl:SetPoint("TOPLEFT", picker, "TOPLEFT", 20, -42)
  sl:SetTextColor(.8, .8, .8)
  sl:SetText("Search")
  picker.search = CreateFrame("EditBox", "OctoPadIconSearch", picker, "InputBoxTemplate")
  picker.search:SetWidth(200)
  picker.search:SetHeight(20)
  picker.search:SetPoint("TOPLEFT", picker, "TOPLEFT", 90, -38)
  picker.search:SetAutoFocus(false)
  picker.search:SetMaxLetters(40)
  picker.search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  picker.search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  picker.search:SetScript("OnTextChanged", function()
    if picker.building then return end
    ApplyFilter()
    ShowPage()
  end)

  -- typed name / path
  local cl = picker:CreateFontString(nil, "OVERLAY")
  cl:SetFont(OP.Font(), 11)
  cl:SetPoint("TOPLEFT", picker, "TOPLEFT", 20, -68)
  cl:SetTextColor(.8, .8, .8)
  cl:SetText("Icon name")
  picker.custom = CreateFrame("EditBox", "OctoPadIconCustom", picker, "InputBoxTemplate")
  picker.custom:SetWidth(200)
  picker.custom:SetHeight(20)
  picker.custom:SetPoint("TOPLEFT", picker, "TOPLEFT", 90, -64)
  picker.custom:SetAutoFocus(false)
  picker.custom:SetMaxLetters(120)
  picker.custom:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  local function UseCustom()
    local t = NormalizeIcon(picker.custom:GetText())
    if t then
      picker.selected = t
      ShowPreview()
      ShowPage()
    end
    picker.custom:ClearFocus()
  end
  picker.custom:SetScript("OnEnterPressed", UseCustom)
  local useBtn = CreateFrame("Button", "OctoPadIconUse", picker, "UIPanelButtonTemplate")
  useBtn:SetWidth(50)
  useBtn:SetHeight(22)
  useBtn:SetPoint("TOPLEFT", picker, "TOPLEFT", 296, -63)
  useBtn:SetText("Use")
  useBtn:SetScript("OnClick", UseCustom)

  -- preview
  picker.previewFrame = CreateFrame("Frame", nil, picker)
  picker.previewFrame:SetWidth(36)
  picker.previewFrame:SetHeight(36)
  picker.previewFrame:SetPoint("TOPLEFT", picker, "TOPLEFT", 20, -96)
  if not OP.Round(picker.previewFrame, .6) then
    picker.previewFrame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    picker.previewFrame:SetBackdropColor(0, 0, 0, .6)
    picker.previewFrame:SetBackdropBorderColor(.5, .5, .5, 1)
  end
  picker.preview = picker.previewFrame:CreateTexture(nil, "ARTWORK")
  picker.preview:SetPoint("TOPLEFT", picker.previewFrame, "TOPLEFT", 2, -2)
  picker.preview:SetPoint("BOTTOMRIGHT", picker.previewFrame, "BOTTOMRIGHT", -2, 2)
  picker.preview:SetTexCoord(.07, .93, .07, .93)
  picker.path = picker:CreateFontString(nil, "OVERLAY")
  picker.path:SetFont(OP.Font(), 11)
  picker.path:SetPoint("TOPLEFT", picker, "TOPLEFT", 64, -106)
  picker.path:SetJustifyH("LEFT")
  picker.path:SetWidth(280)
  picker.path:SetTextColor(1, .85, 0)

  -- grid
  picker.btns = {}
  local k
  for k = 1, PER do
    local b = CreateFrame("Button", "OctoPadIconBtn" .. k, picker)
    b:SetWidth(38)
    b:SetHeight(38)
    local col = math.mod(k - 1, COLS)
    local row = math.floor((k - 1) / COLS)
    b:SetPoint("TOPLEFT", picker, "TOPLEFT", 20 + col * 42, -142 - row * 42)
    if not OP.Round(b, .6) then
      b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
      })
      b:SetBackdropColor(0, 0, 0, .6)
    end
    OP.BD(b):SetBackdropBorderColor(.35, .35, .35, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(.07, .93, .07, .93)
    b.hi = b:CreateTexture(nil, "HIGHLIGHT")
    b.hi:SetAllPoints(b)
    b.hi:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    b.hi:SetBlendMode("ADD")
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function()
      if this.tex then
        picker.selected = this.tex
        ShowPreview()
        ShowPage()
      end
    end)
    b:SetScript("OnEnter", function()
      if this.tex then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(ShortName(this.tex))
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    picker.btns[k] = b
  end

  -- pager
  local prev = CreateFrame("Button", "OctoPadIconPrev", picker, "UIPanelButtonTemplate")
  prev:SetWidth(30)
  prev:SetHeight(22)
  prev:SetPoint("TOPLEFT", picker, "TOPLEFT", 20, -400)
  prev:SetText("<")
  prev:SetScript("OnClick", function() page = page - 1; ShowPage() end)
  local nxt = CreateFrame("Button", "OctoPadIconNext", picker, "UIPanelButtonTemplate")
  nxt:SetWidth(30)
  nxt:SetHeight(22)
  nxt:SetPoint("TOPLEFT", picker, "TOPLEFT", 326, -400)
  nxt:SetText(">")
  nxt:SetScript("OnClick", function() page = page + 1; ShowPage() end)
  picker.pageText = picker:CreateFontString(nil, "OVERLAY")
  picker.pageText:SetFont(OP.Font(), 10)
  picker.pageText:SetPoint("TOP", picker, "TOP", 0, -405)
  picker.pageText:SetTextColor(.8, .8, .8)
  picker:SetScript("OnMouseWheel", function()
    page = page - arg1
    ShowPage()
  end)

  -- options + buttons
  picker.all = CreateFrame("CheckButton", "OctoPadIconAll", picker, "UICheckButtonTemplate")
  picker.all:SetWidth(24)
  picker.all:SetHeight(24)
  picker.all:SetPoint("TOPLEFT", picker, "TOPLEFT", 16, -426)
  getglobal("OctoPadIconAllText"):SetText("Apply to all buttons using this action")
  picker.all:SetChecked(1)

  local ok = CreateFrame("Button", "OctoPadIconOkay", picker, "UIPanelButtonTemplate")
  ok:SetWidth(90)
  ok:SetHeight(22)
  ok:SetPoint("TOPLEFT", picker, "TOPLEFT", 20, -456)
  ok:SetText("Okay")
  ok:SetScript("OnClick", function() Apply(false) end)
  local def = CreateFrame("Button", "OctoPadIconDefault", picker, "UIPanelButtonTemplate")
  def:SetWidth(120)
  def:SetHeight(22)
  def:SetPoint("TOPLEFT", picker, "TOPLEFT", 120, -456)
  def:SetText("Default icon")
  def:SetScript("OnClick", function() Apply(true) end)
  local cancel = CreateFrame("Button", "OctoPadIconCancel", picker, "UIPanelButtonTemplate")
  cancel:SetWidth(90)
  cancel:SetHeight(22)
  cancel:SetPoint("TOPLEFT", picker, "TOPLEFT", 250, -456)
  cancel:SetText("Cancel")
  cancel:SetScript("OnClick", function() picker:Hide() end)
end

-- Open the picker for slot n (1..40). Only system actions have a custom icon;
-- ability slots always show the ability's own icon.
function OP.OpenIconPicker(n)
  local id = OP.ProxyFor(n)
  if not id or not OP.ACTIONS[id] then
    OP.Print("Slot " .. n .. " (" .. OP.SlotName(n) .. ") holds an ability or is empty: it shows the ability's own icon. Set its Game action to a system action first.")
    return
  end
  BuildList()
  Build()
  picker.slot = n
  picker.title:SetText("Choose an icon:  " .. OP.ACTIONS[id].short .. "  on  " .. OP.SlotName(n))
  picker.building = true
  picker.search:SetText("")
  picker.custom:SetText("")
  picker.building = false
  picker.selected = OP.IconFor(n, id)
  ApplyFilter()
  ShowPreview()
  ShowPage()
  picker:Show()
end
