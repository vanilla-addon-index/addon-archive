-- Ade Alts: cdwin
local AA = AdeAlts

----------------------------------------------------------------------
-- main window
----------------------------------------------------------------------
AA.f = CreateFrame("Frame", "AdeAltsFrame", UIParent)
AA.f:SetWidth(400)
AA.f:SetHeight(100)
AA.f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
AA.f:SetFrameStrata("DIALOG")
AA.SkinFrame(AA.f, 1, true, true)
AA.f:SetMovable(true)
AA.f:EnableMouse(true)
AA.f:RegisterForDrag("LeftButton")
AA.f:SetScript("OnDragStart", function() this:StartMoving() end)
AA.f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
AA.f:Hide()
table.insert(UISpecialFrames, "AdeAltsFrame")

local cdTitle = AA.f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cdTitle:SetPoint("TOPLEFT", AA.f, "TOPLEFT", 12, -10)
cdTitle:SetText("Profession Cooldowns")

local close = CreateFrame("Button", nil, AA.f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", AA.f, "TOPRIGHT", -2, -2)

local cdLeft = AA.f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
cdLeft:SetPoint("TOPLEFT", AA.f, "TOPLEFT", 12, -32)
cdLeft:SetWidth(250)
cdLeft:SetJustifyH("LEFT")

local cdRight = AA.f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
cdRight:SetPoint("TOPRIGHT", AA.f, "TOPRIGHT", -12, -32)
cdRight:SetWidth(110)
cdRight:SetJustifyH("RIGHT")

AA.RefreshCD = function()
  if not AA.db or not AA.f:IsVisible() then return end
  local txtL, txtR, lines = "", "", 0
  local list = AA.Entries()
  for _, e in ipairs(list) do
    txtL = txtL .. e.l .. "\n"
    txtR = txtR .. e.r .. "\n"
    lines = lines + 1
  end
  if lines == 0 then
    txtL = "|cff808080No data yet. Open a profession window on each character.|r"
    lines = 1
  end
  cdLeft:SetText(txtL)
  cdRight:SetText(txtR)
  local h = 44 + lines * 12
  if h > 700 then h = 700 end
  AA.f:SetHeight(h)
end

AA.Refresh = function()
  AA.RefreshCD()
  if AA.RefreshManager then AA.RefreshManager() end
end

AA.f:SetScript("OnUpdate", function()
  this.t = (this.t or 0) + arg1
  if this.t >= 1 then
    this.t = 0
    AA.RefreshCD()
  end
end)
AA.f:SetScript("OnShow", function() if AA.FileMerge then AA.FileMerge() end AA.RefreshCD() end)

function AA.ToggleWindow()
  if AA.f:IsVisible() then AA.f:Hide() else AA.f:Show() end
end

