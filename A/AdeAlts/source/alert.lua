-- Ade Alts: alert
local AA = AdeAlts

----------------------------------------------------------------------
-- login alert: small window listing everything that is ready
----------------------------------------------------------------------
local al = CreateFrame("Frame", "AdeAltsAlert", UIParent)
al:SetWidth(300)
al:SetHeight(80)
al:SetPoint("TOP", UIParent, "TOP", 0, -140)
al:SetFrameStrata("DIALOG")
AA.SkinFrame(al, 0.92, true, true)
al:SetMovable(true)
al:EnableMouse(true)
al:RegisterForDrag("LeftButton")
al:SetScript("OnDragStart", function() this:StartMoving() end)
al:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
al:Hide()

local altitle = al:CreateFontString(nil, "OVERLAY", "GameFontNormal")
altitle:SetPoint("TOP", al, "TOP", 0, -10)
altitle:SetText("|cff40ff40Cooldowns ready!|r")

local altext = al:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
altext:SetPoint("TOPLEFT", al, "TOPLEFT", 14, -28)
altext:SetWidth(272)
altext:SetJustifyH("LEFT")

local alclose = CreateFrame("Button", nil, al, "UIPanelButtonTemplate")
alclose:SetWidth(80); alclose:SetHeight(22)
alclose:SetPoint("BOTTOM", al, "BOTTOM", 0, 10)
alclose:SetText("Close")
alclose:SetScript("OnClick", function() al:Hide() end)

function AA.ShowReadyAlert(force)
  if not AA.db then return end
  if AA.db.noAlert and not force then return end
  local nowt = time()
  local text, lines = "", 0
  for _, k in ipairs(AA.SortedChars()) do
    local c = AA.db.chars[k]
    local ready = {}
    for key, exp in pairs(c.cds) do
      if exp <= nowt then table.insert(ready, key) end
    end
    if table.getn(ready) > 0 then
      table.sort(ready)
      text = text .. "|cff" .. AA.ClassHex(c.class) .. c.name .. "|r: " .. table.concat(ready, ", ") .. "\n"
      lines = lines + 1
    end
  end
  if lines == 0 then
    if not force then return end
    text = "|cff808080Nothing is ready right now.\nOpen a profession window on each character\nto record its cooldowns.|r\n"
    lines = 3
  end
  altext:SetText(text)
  al:SetHeight(lines * 14 + 70)
  al:Show()
end

