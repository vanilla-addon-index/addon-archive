local x, m, r, b 
local f = CreateFrame("Button", "Bubbles", UIParent)

f:ClearAllPoints()
f:SetWidth(100)
f:SetHeight(25)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetFrameStrata("HIGH")

f.text = f:CreateFontString("Status", "LOW", "GameFontNormal")
f.text:SetFont("Fonts\\ARIALN.TTF", 13, "OUTLINE")
f.text:ClearAllPoints()
f.text:SetAllPoints(f)
f.text:SetPoint("LEFT", 0, 0)
f.text:SetJustifyH("LEFT")
f.text:SetFontObject(GameFontWhite)

local lastUpdate = GetTime()
local lastXP = GetXPExhaustion() or 0
local lastTents = 0
local elapsed = 0
local tents = 0

local remaining = 0
local time = nil

f:SetScript("OnUpdate", function()
  local now = GetTime()
  local delta = now - lastUpdate
  local threshold = 1

  lastUpdate = now
  elapsed = elapsed + delta

  if elapsed >= threshold then
    elapsed = 0

    r = GetXPExhaustion() or 0
    local gained = r - lastXP
    lastXP = r

    m = UnitXPMax("player")
    local rate = (gained / m) * 100
    -- ty to https://github.com/Pizzahawaiii/PizzaWorldBuffs/blob/dbfef375451131c62d26db4c15cee5bae5b41133/src/tents.lua#L69
    tents = math.floor(rate / (0.13 * threshold))

    local p = 0.13 * math.max(tents, 1) / threshold
    remaining = (1 - r / (m * 1.5)) * (100 / p)

    local mins = math.floor(math.floor(remaining) / 60)
    local secs = math.floor(remaining) - (mins * 60)
    
    if secs < 10 then
      time = mins .. ":0" .. secs
    else
      time = mins .. ":" .. secs
    end

    if tents ~= lastTents then
      this = f
      f:GetScript("OnEvent")()
      lastTents = tents
    end
  end
end)

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("PLAYER_UPDATE_RESTING")
f:SetScript("OnEvent", function()
  x = UnitXP("player")
  m = UnitXPMax("player")
  r = GetXPExhaustion() or 0

  if -1 == (r or -1) then
    b = 0
  else
    -- ty to https://forum.turtle-wow.org/viewtopic.php?p=65081#p65081
    b = math.floor(20 * r / m + 0.5)
  end

  local text
  if tents > 0 and tents < 10 then
    text = "|cfff58cba" .. b .. "|cffffffff Bubbles / |cfff58cba" .. tents
  else 
    text = "|cfff58cba" .. b .. "|cffffffff Bubbles"
  end
  
  f.text:SetText(text)
  f:SetWidth(f.text:GetStringWidth() + 10)
end)

f:SetMovable(true)
f:EnableMouse(true)
f:SetScript("OnMouseDown", function()
  this:StartMoving()
end)

f:SetScript("OnMouseUp", function()
  this:StopMovingOrSizing()
  this:SetUserPlaced(true)
end)

f:SetScript("OnEnter", function()
  GameTooltip:SetOwner(f, "ANCHOR_NONE")
  GameTooltip:ClearAllPoints()

  GameTooltip:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, (CONTAINER_OFFSET_Y or 0) + 13)
  GameTooltip:SetClampedToScreen(true)

  if -1 == (r or -1) then
    b = 0
  else
    b = math.floor(20 * r / m + 0.5)
  end
  
  GameTooltip:AddLine("|cfff58cbaBubbles (|cffffffff" .. b .. "|cfff58cba)")
  GameTooltip:AddLine("|cffaaaaaaMaximum amount of rested bubbles is 30. To fully rest with one tent takes around 13 minutes. Multiple tents can stack and speed up resting.", 0, 0, 0, true)
  GameTooltip:AddLine(" ")
  GameTooltip:AddDoubleLine("|cffffffffRested", "|cffaaaaaa" .. r .. " XP")
  if r + x > m then
    GameTooltip:AddDoubleLine("|cffffffffRested+", "|cffaaaaaa" .. r + x - m .. " XP")
  end
  GameTooltip:AddDoubleLine("|cffffffffStill", "|cffaaaaaa" .. m - x .. " XP")
  GameTooltip:AddDoubleLine("|cffffffffPercent", "|cffaaaaaa" .. math.floor(x / m * 100) .. "%")
  
  GameTooltip:AddDoubleLine("|cffffffffTime to full rest", "|cfff58cba" .. time .. " |cffaaaaaamin")

  if tents > 0 then
    GameTooltip:AddDoubleLine("|cffffffffStatus", "|cffaaaaaaGaining from " .. tents .. " tent(s)")
  end

  GameTooltip:Show()
end)

f:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

SLASH_BUBBLES1 = "/bubbles"
SLASH_BUBBLES2 = "/b"

SlashCmdList["BUBBLES"] = function(msg)
  msg = string.lower(msg or "")

  if msg == "reset" then
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetUserPlaced(false)
    DEFAULT_CHAT_FRAME:AddMessage("|cfff58cbaBubbles|cffffffff frame reset to center.")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cfff58cbaBubbles commands:")
    DEFAULT_CHAT_FRAME:AddMessage("|cffffffff/b reset - Reset frame to center")
  end
end

DEFAULT_CHAT_FRAME:AddMessage("|cfff58cbaBubbles |cffffffff1.1 loaded")
