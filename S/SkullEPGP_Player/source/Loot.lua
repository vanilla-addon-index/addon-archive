-- Loot.lua : the loot history of this session
local P = SkullEPGPP
local L = {}
P.Loot = L

local COLOR = { MIN = "|cff33cc33", NEED = "|cffff8000", MAX = "|cffff3333", ROLL = "|cffcccccc",
	MS = "|cffcccccc", OS = "|cff99bbdd", TMOG = "|cffcc99dd" }
local BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local function Text(parent, text, font, w, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	if text then fs:SetText(text) end
	if w then fs:SetWidth(w) end
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

local function ItemTip(frame, getLink)
	frame:SetScript("OnEnter", function()
		local link = getLink()
		local _, _, str = string.find(link or "", "(item:%d+:%d+:%d+:%d+)")
		if str then GameTooltip:SetOwner(frame, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(str); GameTooltip:Show() end
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-------------------------------------------------------------------------------
-- History window
-------------------------------------------------------------------------------
local HW, HH, HROWS = 380, 400, 15
local hf = CreateFrame("Frame", "SkullEPGPPlayerHistory", UIParent)
hf:SetWidth(HW)
hf:SetHeight(HH)
hf:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
hf:SetFrameStrata("DIALOG")
hf:SetMovable(true)
hf:EnableMouse(true)
hf:SetClampedToScreen(true)
hf:RegisterForDrag("LeftButton")
hf:SetScript("OnDragStart", function() this:StartMoving() end)
hf:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
hf:SetBackdrop(BACKDROP)
hf:Hide()

local htitle = Text(hf, "Skull EPGP - Loot history", "GameFontNormal", 240, "CENTER")
htitle:SetPoint("TOP", hf, "TOP", 0, -14)
local hclose = CreateFrame("Button", "SkullEPGPPlayerHistoryClose", hf, "UIPanelCloseButton")
hclose:SetPoint("TOPRIGHT", hf, "TOPRIGHT", -6, -6)
local hhelp = Text(hf, "Items won during this session (cleared when you reload or disconnect).", "GameFontDisableSmall", HW - 40)
hhelp:SetPoint("TOPLEFT", hf, "TOPLEFT", 22, -38)

local HTOP = 58
local hhdr = CreateFrame("Frame", nil, hf)
hhdr:SetWidth(HW - 70)
hhdr:SetHeight(14)
hhdr:SetPoint("TOPLEFT", hf, "TOPLEFT", 22, -HTOP)
do
	local a = Text(hhdr, "Item", "GameFontNormalSmall"); a:SetPoint("LEFT", hhdr, "LEFT", 0, 0)
	local b = Text(hhdr, "Winner", "GameFontNormalSmall"); b:SetPoint("LEFT", hhdr, "LEFT", 194, 0)
	local c = Text(hhdr, "Bid / roll", "GameFontNormalSmall"); c:SetPoint("LEFT", hhdr, "LEFT", 270, 0)
end
local hrow = {}
for i = 1, HROWS do
	local row = CreateFrame("Frame", nil, hf)
	row:SetWidth(HW - 70)
	row:SetHeight(18)
	row:SetPoint("TOPLEFT", hf, "TOPLEFT", 22, -HTOP - 16 - (i - 1) * 19)
	row:EnableMouse(true)
	row.text = Text(row, "", "GameFontHighlightSmall", 190)
	row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.who = Text(row, "", "GameFontHighlightSmall", 72)
	row.who:SetPoint("LEFT", row, "LEFT", 194, 0)
	row.bid = Text(row, "", "GameFontHighlightSmall", 70)
	row.bid:SetPoint("LEFT", row, "LEFT", 270, 0)
	ItemTip(row, function() return row.entry and row.entry.link end)
	row:Hide()
	hrow[i] = row
end
local hempty = Text(hf, "Nothing won yet.", "GameFontDisableSmall", HW - 50, "CENTER")
hempty:SetPoint("TOPLEFT", hf, "TOPLEFT", 25, -HTOP - 24)
local hmore = Text(hf, "", "GameFontDisableSmall", 200, "RIGHT")
hmore:SetPoint("BOTTOMRIGHT", hf, "BOTTOMRIGHT", -24, 22)
local hclear = CreateFrame("Button", "SkullEPGPPlayerHistoryClear", hf, "UIPanelButtonTemplate")
hclear:SetWidth(120)
hclear:SetHeight(20)
hclear:SetPoint("BOTTOMLEFT", hf, "BOTTOMLEFT", 22, 18)
hclear:SetText("Clear history")
hclear:SetScript("OnClick", function() P.history = {}; L.offset = 0; L:RefreshHistory() end)
hf:EnableMouseWheel(true)
hf:SetScript("OnMouseWheel", function()
	if arg1 > 0 then L.offset = math.max(0, (L.offset or 0) - 1) else L.offset = (L.offset or 0) + 1 end
	L:RefreshHistory()
end)

function L:RefreshHistory()
	if not hf:IsShown() then return end
	local list = P.history
	local n = table.getn(list)
	local off = self.offset or 0
	if off > math.max(0, n - HROWS) then off = math.max(0, n - HROWS) end
	self.offset = off
	for i = 1, HROWS do
		local e = list[off + i]
		local row = hrow[i]
		if e then
			row.entry = e
			row.text:SetText(e.link)
			row.who:SetText(e.char)
			local _, _, tier = string.find(e.bid, "^(%u+)")
			if string.find(e.bid, "^Roll") then tier = "ROLL" end
			row.bid:SetText((COLOR[tier] or "") .. e.bid .. "|r")
			row:Show()
		else
			row.entry = nil
			row:Hide()
		end
	end
	if n == 0 then hempty:Show() else hempty:Hide() end
	hmore:SetText(n > HROWS and (n .. " entries, scroll for more") or "")
end

function L:ToggleHistory()
	if hf:IsShown() then hf:Hide() else self.offset = 0; hf:Show(); self:RefreshHistory() end
end
hf:SetScript("OnShow", function() L:RefreshHistory() end)

-------------------------------------------------------------------------------
function L:Refresh()
	self:RefreshHistory()
end

function L:Show(view)
	self.offset = 0
	hf:Show()
	self:RefreshHistory()
end
