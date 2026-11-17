-- pfQuest xpGuide: the question that comes with every xpGuide Fast guide you pick from the guide list: the experience rate of
-- your server (1x or 2x) and your professions. The class's suggested professions are ticked, the ones you have are ticked and
-- show your skill. "Start" keeps the answers (Character.lua) and starts the guide.

local ER = pfQuest_xpGuide
local GOLD, WHITE, GREY, END = ER.GOLD, ER.WHITE, ER.GREY, ER.END

local W = 400
local F = {}
ER.FastSetupInfo = F

local function Tip(b, title, text)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    if text then GameTooltip:AddLine(text, 1, 1, 1, 1) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Heading(f, text, y)
  local fs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  fs:SetPoint("TOPLEFT", f, "TOPLEFT", 16, y)
  fs:SetText(GOLD .. string.upper(text) .. END)
  local line = f:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 6, 0)
  line:SetPoint("RIGHT", f, "LEFT", W - 16, 0)
  line:SetTexture(1, 1, 1, 0.1)
  return fs
end

local function Check(f, name, x, y, label, onClick)
  local b = CreateFrame("CheckButton", name, f, "UICheckButtonTemplate")
  b:SetWidth(24)
  b:SetHeight(24)
  b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
  local text = getglobal(name .. "Text")
  if text then
    text:ClearAllPoints()
    text:SetPoint("LEFT", b, "RIGHT", 0, 1)
    text:SetJustifyH("LEFT")
    text:SetText(label)
  end
  b:SetScript("OnClick", onClick)
  return b, text
end

local function Build()
  local f = CreateFrame("Frame", "pfQuest_xpGuideFastSetup", UIParent)
  F.frame = f
  f:SetWidth(W)
  f:SetFrameStrata("DIALOG")
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.03, 0.03, 0.05, 0.95)
  f:SetBackdropBorderColor(0.85, 0.65, 0.3, 1)
  if ER.Skin and ER.Skin.Window then ER.Skin.Window(f, 0.95) end
  if UISpecialFrames then table.insert(UISpecialFrames, "pfQuest_xpGuideFastSetup") end

  F.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  F.title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
  F.title:SetJustifyH("LEFT")
  F.intro = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  F.intro:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -34)
  F.intro:SetWidth(W - 32)
  F.intro:SetJustifyH("LEFT")
  F.intro:SetText(GREY .. "The guide plans around your server's experience and your professions: where to train, what to gather on the way." .. END)

  local y = -66
  Heading(f, "Experience rate", y)
  y = y - 18
  F.rate = {}
  local function Rate(r, x, tip)
    local b = Check(f, "pfQuest_xpGuideFastSetupRate" .. r, x, y, r .. "x experience", function()
      F.pickRate = r
      F.Fill()
    end)
    Tip(b, r .. "x experience", tip)
    F.rate[r] = b
  end
  Rate(1, 16, "Normal rates. The guide keeps all of its quests.")
  Rate(2, 200, "Double experience. The guide leaves out the quests a 1x server needs for the same levels.")
  y = y - 30

  F.primaryHead = Heading(f, "Primary professions", y)
  y = y - 18
  F.prof = {}
  for i, name in ipairs(ER.PRIMARY) do
    local col, row = math.mod(i - 1, 2), math.floor((i - 1) / 2)
    local b, text = Check(f, "pfQuest_xpGuideFastSetupProf" .. i, 16 + col * 184, y - row * 22, name, function()
      local n = this.prof
      if this:GetChecked() then
        if F.Count() > 2 then
          this:SetChecked(nil)
          ER.Print("a character has two primary professions at most.")
          return
        end
        F.pickProf[n] = true
      else
        F.pickProf[n] = false
      end
      F.Fill()
    end)
    b.prof, b.label, b.primary = name, text, true
    F.prof[name] = b
  end
  y = y - 5 * 22 - 6

  Heading(f, "Secondary professions", y)
  y = y - 18
  for i, name in ipairs(ER.SECONDARY) do
    local col, row = math.mod(i - 1, 2), math.floor((i - 1) / 2)
    local b, text = Check(f, "pfQuest_xpGuideFastSetupSec" .. i, 16 + col * 184, y - row * 22, name, function()
      F.pickProf[this.prof] = this:GetChecked() and true or false
      F.Fill()
    end)
    b.prof, b.label = name, text
    F.prof[name] = b
  end
  y = y - 2 * 22 - 6

  F.note = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  F.note:SetPoint("TOPLEFT", f, "TOPLEFT", 16, y)
  F.note:SetWidth(W - 32)
  F.note:SetJustifyH("LEFT")
  y = y - 30

  local go = CreateFrame("Button", "pfQuest_xpGuideFastSetupStart", f, "UIPanelButtonTemplate")
  go:SetWidth(120)
  go:SetHeight(22)
  go:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14)
  go:SetText("Start the guide")
  go:SetScript("OnClick", function() F.Accept() end)
  local no = CreateFrame("Button", "pfQuest_xpGuideFastSetupCancel", f, "UIPanelButtonTemplate")
  no:SetWidth(120)
  no:SetHeight(22)
  no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14)
  no:SetText("Cancel")
  no:SetScript("OnClick", function() F.frame:Hide() end)
  f:SetHeight(-y + 44)
  f:Hide()
end

-- How many primary professions are ticked.
function F.Count()
  local n = 0
  for _, name in ipairs(ER.PRIMARY) do
    if F.prof[name] and F.prof[name]:GetChecked() then n = n + 1 end
  end
  return n
end

-- The ticks and the words from the picks so far.
function F.Fill()
  local info = F.guide
  F.title:SetText(GOLD .. "xpGuide Fast: " .. WHITE .. ((info and (info.title or info.name)) or "") .. END)
  for r = 1, 2 do F.rate[r]:SetChecked(F.pickRate == r and 1 or nil) end
  local primary = 0
  for _, name in ipairs(ER.PRIMARY) do
    local b = F.prof[name]
    local has = ER.KnowsProf(name)
    local on = has or F.pickProf[name]
    b:SetChecked(on and 1 or nil)
    if has then b:Disable() else b:Enable() end
    if on then primary = primary + 1 end
  end
  for _, name in ipairs(ER.SECONDARY) do
    local b = F.prof[name]
    local has = ER.KnowsProf(name)
    local on = has or F.pickProf[name]
    b:SetChecked(on and 1 or nil)
    if has then b:Disable() else b:Enable() end
  end
  for name, b in pairs(F.prof) do
    if b.label then
      local detail = ER.ProfDetail(name)
      local colour = ER.KnowsProf(name) and WHITE or GREY
      b.label:SetText(name .. "  " .. colour .. detail .. END .. (ER.Recommended(name) and not ER.KnowsProf(name) and "  " .. GOLD .. "*" .. END or ""))
    end
  end
  local _, class = UnitClass("player")
  F.note:SetText(GREY .. "Ticked and starred ones are suggested for your class" .. (class and (" (" .. string.upper(string.sub(class, 1, 1)) .. string.lower(string.sub(class, 2)) .. ")") or "") ..
    "; professions you have are ticked from your skill list. Two primary professions at most (" .. primary .. " now)." .. END)
end

-- Keeps the answers and starts the guide.
function F.Accept()
  local g = F.guide
  F.frame:Hide()
  if not g then return end
  if ER.SetXPRate then ER.SetXPRate(F.pickRate, true) end
  for name, v in pairs(F.pickProf) do
    if not ER.KnowsProf(name) then ER.SetProf(name, v) end
  end
  ER.Print("Fast guide: " .. GOLD .. F.pickRate .. "x" .. END .. " experience, professions " .. GOLD ..
    (table.getn(ER.ProfList()) > 0 and table.concat(ER.ProfList(), ", ") or "none") .. END .. ".")
  ER.StartGuide(ER.Steps.Key(g), nil, nil, true)
end

-- Picking a guide in the guide list: an xpGuide Fast guide asks first, any other starts at once.
function ER.ChooseGuide(g)
  if not g then return end
  if not g.fast then
    ER.StartGuide(ER.Steps.Key(g), nil, nil, true)
    return
  end
  if not F.frame then Build() end
  F.guide = g
  F.pickRate = ER.XPRate()
  F.pickProf = {}
  for _, name in ipairs(ER.PRIMARY) do F.pickProf[name] = ER.HasProf(name) and true or false end
  for _, name in ipairs(ER.SECONDARY) do F.pickProf[name] = ER.HasProf(name) and true or false end
  F.Fill()
  F.frame:Show()
end

ER.Loaded("FastSetup.lua")
