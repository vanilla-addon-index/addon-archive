-- AdeLazyBuffs reminder: plain outlined text that lists the blessings that are due (like the SmartBuff reminder).
-- Written for the Lua 5.0 client: no '#', no '%', no select(), no string.match.

local A = AdeLazyBuffs
local f
local MAXL = 6

A.FONTS = {
  { "Default font", nil },
  { "Arial Narrow", "Fonts\\ARIALN.TTF" },
  { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
  { "Skurri", "Fonts\\skurri.ttf" },
  { "Morpheus", "Fonts\\MORPHEUS.ttf" },
}

function A.FontName()
  local e = A.FONTS[(A.DB and A.DB.remindFont) or 1] or A.FONTS[1]
  return A.T(e[1])
end

local function FontPath()
  local e = A.FONTS[(A.DB and A.DB.remindFont) or 1] or A.FONTS[1]
  return e[2] or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function Clock(sec)
  if not sec or sec <= 0 then return "0:00" end
  sec = math.floor(sec)
  return string.format("%d:%02d", math.floor(sec / 60), math.mod(sec, 60))
end

local function Place()
  local p = A.DB.remindPos
  f:ClearAllPoints()
  if p and p[1] then
    f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
  end
end

local function Build()
  f = CreateFrame("Frame", "AdeLazyBuffsReminder", UIParent)
  f:SetWidth(200)
  f:SetHeight(30)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function()
    if not A.DB.remindLock then this:StartMoving() end
  end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local p, _, rp, x, y = this:GetPoint()
    A.DB.remindPos = { p, rp, x, y }
  end)
  f.texts = {}
  local i
  for i = 0, MAXL do
    local l = f:CreateFontString(nil, "OVERLAY")
    l:SetJustifyH("CENTER")
    f.texts[i] = l          -- 0 = title line
  end
  Place()
  f:Hide()
end

-- font, size and outline for every line
local function Style()
  local size = A.DB.remindSize or 14
  local path = FontPath()
  local i
  for i = 0, MAXL do
    local l = f.texts[i]
    if not l:SetFont(path, size, "OUTLINE") then
      l:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
    l:SetHeight(size + 2)
    l:SetWidth(600)
    l:ClearAllPoints()
    l:SetPoint("TOP", f, "TOP", 0, -(i * (size + 3)))
  end
end

function A.RefreshReminder()
  local DB = A.DB
  if not DB then return end
  local list = A.due
  local count = list and table.getn(list) or 0
  local win = getglobal("AdeLazyBuffsWindow")
  local preview = win and win:IsVisible() and count == 0
  if not DB.enabled or not DB.remind or (count == 0 and not preview) then
    if f then f:Hide() end
    return
  end
  if not f then Build() end
  Style()
  local i
  local lines = 0
  if count == 0 then
    f.texts[0]:SetText("|cffffd100" .. A.T("Reminder window - drag to move") .. "|r")
    for i = 1, MAXL do f.texts[i]:SetText("") end
  else
    f.texts[0]:SetText("|cffffd100" .. A.T("Rebuff needed:") .. "|r")
    local shown = count
    if shown > MAXL then shown = MAXL end
    lines = shown
    for i = 1, MAXL do
      local d = list[i]
      if d and i <= shown then
        local tail
        if d.gone then tail = "|cffff4040" .. A.T("gone") .. "|r" else tail = Clock(d.rem) end
        f.texts[i]:SetText("|cffffd100" .. d.name .. "|r  " .. d.spell .. "  " .. tail)
      else
        f.texts[i]:SetText("")
      end
    end
  end
  local w = 0
  for i = 0, lines do
    local sw = f.texts[i]:GetStringWidth()
    if type(sw) == "number" and sw > w then w = sw end
  end
  local size = DB.remindSize or 14
  f:SetWidth(w + 10)
  f:SetHeight((lines + 1) * (size + 3))
  f:Show()
end

function A.ResetReminderPos()
  A.DB.remindPos = nil
  if f then Place() end
end
