local PP = PizzaPocket

PP.statsframe = {}
local statsframe = PP.statsframe

local WIDTH, PAD = 228, 10
local COL1, COL2 = -PAD - 84, -PAD
local ACCENT = { 0.63, 0.31, 1 }
local DIM = { 0.55, 0.55, 0.62 }
local BRIGHT = { 0.95, 0.95, 0.97 }
local NONE = '|cff555560-|r'

local frame = CreateFrame('Frame', 'PizzaPocketStatsFrame', UIParent)
frame:SetWidth(WIDTH)
frame:SetHeight(100)
frame:Hide()

local bg = frame:CreateTexture(nil, 'BACKGROUND')
bg:SetAllPoints()
bg:SetTexture(1, 1, 1, 1)
bg:SetGradientAlpha('VERTICAL', 0.03, 0.03, 0.05, 0.8, 0.08, 0.07, 0.11, 0.8)

local accent = frame:CreateTexture(nil, 'BORDER')
accent:SetTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
accent:SetWidth(2)
accent:SetPoint('TOPLEFT', frame, 'TOPLEFT')
accent:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT')

local divider = frame:CreateTexture(nil, 'BORDER')
divider:SetTexture(1, 1, 1, 0.07)
divider:SetHeight(1)
divider:SetPoint('TOPLEFT', frame, 'TOPLEFT', PAD, -50)
divider:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -PAD, -50)

local function text(size, color, side, x, y)
  local t = frame:CreateFontString(nil, 'OVERLAY')
  t:SetFont(STANDARD_TEXT_FONT, size)
  t:SetTextColor(color[1], color[2], color[3])
  t:SetShadowColor(0, 0, 0, 0.9)
  t:SetShadowOffset(1, -1)
  t:SetPoint(side, frame, 'TOP' .. side, x, y)
  return t
end

local function header(y, title, left, right)
  text(9, ACCENT, 'LEFT', PAD + 2, y):SetText(title)
  text(9, DIM, 'RIGHT', COL1, y):SetText(left)
  local last = text(9, DIM, 'RIGHT', COL2, y)
  last:SetText(right)
  return last
end

local function row(y, label)
  text(10, DIM, 'LEFT', PAD + 2, y):SetText(label)
  return text(11, BRIGHT, 'RIGHT', COL1, y), text(11, BRIGHT, 'RIGHT', COL2, y)
end

header(-12, 'RESIST', 'Session', 'All-time')
local sessionRate, alltimeRate = row(-26, 'Rate')
local sessionCount, alltimeCount = row(-40, 'Resisted')
local averageHead = header(-62, 'GOLD', 'This run', 'Average')
local runProfit, avgProfit = row(-76, 'Profit')
local runRate, avgRate = row(-90, 'Per hour')

local function resistCells(s)
  local rate, resisted, total = PP.stats.rate(s)
  if not rate then return NONE, NONE end
  return string.format('%.1f%%', rate), resisted .. '/' .. total
end

local function coins(copper)
  return copper and PP.utils.coins(copper) or NONE
end

function statsframe.anchor()
  frame:ClearAllPoints()
  local regen = getglobal('PizzaRotaRegenTracker')
  if regen then
    frame:SetPoint('TOP', regen, 'BOTTOM', 0, -2)
  else
    frame:SetPoint('TOP', UIParent, 'TOP', 0, -46)
  end
end

function statsframe.update()
  if not frame:IsVisible() then return end

  local rate, count = resistCells(PP.stats.session)
  sessionRate:SetText(rate)
  sessionCount:SetText(count)
  rate, count = resistCells(PP.stats.alltime)
  alltimeRate:SetText(rate)
  alltimeCount:SetText(count)

  local net, perHour = PP.gold.current()
  runProfit:SetText(coins(net))
  runRate:SetText(coins(perHour))

  local avg, avgPerHour, runs = PP.gold.average()
  averageHead:SetText(runs and 'Avg of ' .. runs or 'Average')
  avgProfit:SetText(coins(avg))
  avgRate:SetText(coins(avgPerHour))
end

local function inDungeon()
  local inInstance, instanceType = IsInInstance()
  if not inInstance then return false end
  return instanceType ~= 'pvp'
end

local function smallGroup()
  return GetNumRaidMembers() == 0 and GetNumPartyMembers() <= 1
end

function statsframe.updateAuto()
  -- PLAYER_ENTERING_WORLD can arrive before VARIABLES_LOADED.
  if type(PizzaPocketDB) ~= 'table' or not PizzaPocketDB.autoStats then return end

  local want = inDungeon() and smallGroup()

  if want and not frame:IsVisible() then
    statsframe.anchor()
    frame:Show()
    statsframe.update()
  elseif not want and frame:IsVisible() then
    frame:Hide()
  end
end

function statsframe.show(show)
  if show then
    statsframe.anchor()
    frame:Show()
    statsframe.update()
  else
    frame:Hide()
  end
  PizzaPocketDB.showStats = show
  PP:Print('Stats frame: ' .. (show and 'shown' or 'hidden'))
end

function statsframe.toggle()
  statsframe.show(not frame:IsVisible())
end

function statsframe.stopAuto()
  if not PizzaPocketDB.autoStats then return end
  PizzaPocketDB.autoStats = false
  PP:Print('Auto show off, /pick stats auto turns it back on')
end

function statsframe.restore()
  statsframe.anchor()
  if PizzaPocketDB.autoStats then
    statsframe.updateAuto()
  elseif PizzaPocketDB.showStats then
    frame:Show()
    statsframe.update()
  end
end
