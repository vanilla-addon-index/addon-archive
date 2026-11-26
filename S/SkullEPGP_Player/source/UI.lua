-- UI.lua : the bidding window of the player addon
local P = SkullEPGPP
local UI = {}
P.UI = UI

local ROWS = 3
local W, H = 300, 291
local BID_COLOR = { MIN = "|cff33cc33", NEED = "|cffff8000", MAX = "|cffff3333", ROLL = "|cffcccccc",
	MS = "|cffcccccc", OS = "|cff99bbdd", TMOG = "|cffcc99dd" }
local function colored(bid, text) return (BID_COLOR[bid] or "|cffcccccc") .. (text or bid) .. "|r" end

local f = CreateFrame("Frame", "SkullEPGPPlayerFrame", UIParent)
f:SetWidth(W)
f:SetHeight(H)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
f:SetFrameStrata("DIALOG")
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function() this:StopMovingOrSizing(); UI:SavePosition() end)
f:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
f:Hide()
UI.frame = f

local function Text(parent, text, font, w, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	if text then fs:SetText(text) end
	if w then fs:SetWidth(w) end
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

local title = Text(f, "EPGP - Loot", "GameFontNormal", 160, "CENTER")
title:SetPoint("TOP", f, "TOP", 0, -14)

local close = CreateFrame("Button", "SkullEPGPPlayerClose", f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

-- opens the pre-bids window
local filterBtn = CreateFrame("Button", "SkullEPGPPlayerFilterBtn", f, "UIPanelButtonTemplate")
filterBtn:SetWidth(62)
filterBtn:SetHeight(18)
filterBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
filterBtn:SetText("Pre-bids")
filterBtn:SetScript("OnClick", function() if P.Options then P.Options:Toggle() end end)
filterBtn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText("Pre-bids")
	GameTooltip:AddLine("Items you bid on automatically when the loot master announces them.", 1, 1, 1, 1)
	GameTooltip:Show()
end)
filterBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- loot history window (next to the close button)
local histBtn = CreateFrame("Button", "SkullEPGPPlayerHistoryBtn", f, "UIPanelButtonTemplate")
histBtn:SetWidth(54)
histBtn:SetHeight(18)
histBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -38, -14)
histBtn:SetText("History")
histBtn:SetScript("OnClick", function() if P.Loot then P.Loot:ToggleHistory() end end)
histBtn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText("History")
	GameTooltip:AddLine("Items won during this session: item, winner and bid / roll.", 1, 1, 1, 1)
	GameTooltip:Show()
end)
histBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- item
local itemBtn = CreateFrame("Button", "SkullEPGPPlayerItem", f)
itemBtn:SetWidth(W - 32)
itemBtn:SetHeight(22)
itemBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -78)
local iconFrame = CreateFrame("Frame", nil, f)
iconFrame:SetWidth(46)
iconFrame:SetHeight(46)
iconFrame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
iconFrame:SetBackdropColor(0, 0, 0, 0.8)
local itemIcon = iconFrame:CreateTexture(nil, "ARTWORK")
itemIcon:SetWidth(38)
itemIcon:SetHeight(38)
itemIcon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
itemIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
iconFrame:Hide()
local itemText = Text(itemBtn, "", "GameFontNormal", W - 32, "CENTER")
itemText:SetPoint("LEFT", itemBtn, "LEFT", 0, 0)
iconFrame:SetPoint("BOTTOM", itemText, "TOP", 0, 2)
local timer = Text(f, "", "GameFontNormal", 60, "RIGHT")
timer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -98)
local function ShowItemTip()
	local a = P.auction
	if not a then return end
	local _, _, str = string.find(a.link or "", "|H(item:[%d:%-]+)|h")
	if str then
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetHyperlink(str)
		GameTooltip:Show()
	end
end
local function HideItemTip() GameTooltip:Hide() end
itemBtn:SetScript("OnEnter", ShowItemTip)
itemBtn:SetScript("OnLeave", HideItemTip)
iconFrame:EnableMouse(true)                 -- the tooltip also shows when hovering the icon
iconFrame:SetScript("OnEnter", ShowItemTip)
iconFrame:SetScript("OnLeave", HideItemTip)

-- my priority
local myPR = Text(f, "", "GameFontHighlightSmall", W - 32 - 64)
myPR:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -100)

-- buttons: Roll MS / Roll OS / Tmog on the first row, MIN / NEED / MAX on the second
local CHOICES = P.CHOICES
local NB = table.getn(CHOICES)
local buttons = {}
for i = 1, NB do
	local choice = CHOICES[i]
	local b = CreateFrame("Button", "SkullEPGPPlayerBtn" .. i, f, "UIPanelButtonTemplate")
	b:SetWidth(86)
	b:SetHeight(22)
	local col, line = math.mod(i - 1, 3), math.floor((i - 1) / 3)
	b:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + col * 90, -118 - line * 24)
	b:SetScript("OnClick", function() P:Choose(choice) end)
	b:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		local a = P.auction
		if a and a.src == "rf" then
			local max = P.RF:RollMax(a, choice)
			GameTooltip:SetText(P.LABEL[choice] .. " (RollFor)")
			if max < 1 then
				GameTooltip:AddLine("Transmog rolls are off for this item.", 1, 1, 1, 1)
			else
				GameTooltip:AddLine("/roll " .. max .. (P.IS_ROLL[choice] and "" or "  (the loot master uses RollFor: a bid is a main-spec roll)"), 1, 1, 1, 1)
			end
			GameTooltip:AddLine("RollFor counts your first roll only.", 0.7, 0.7, 0.7, 1)
		elseif P.IS_ROLL[choice] then
			GameTooltip:SetText(P.LABEL[choice])
			GameTooltip:AddLine("Plain /roll 1-100. No GP is paid, you only win if nobody bids.", 1, 1, 1, 1)
			GameTooltip:AddLine("With the EPGP officer addon, Roll MS, Roll OS and Tmog are the same roll.", 0.7, 0.7, 0.7, 1)
		else
			GameTooltip:SetText(choice .. " (" .. P.db.cfg[choice] .. " GP)")
			GameTooltip:AddLine("Posts \"" .. choice .. "\" in the raid chat. Highest priority wins within a bid level: MAX > NEED > MIN > roll.", 1, 1, 1, 1)
			GameTooltip:AddLine("One choice per item; NEED can be upgraded to MAX.", 0.7, 0.7, 0.7, 1)
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	buttons[i] = b
end

local status = Text(f, "", "GameFontHighlightSmall", W - 32, "CENTER")
status:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -168)

-- list of bids
local hdr = CreateFrame("Frame", nil, f)
hdr:SetWidth(W - 32)
hdr:SetHeight(14)
hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -186)
local COLS = { rank = 2, name = 20, bid = 124, pr = 168, roll = 224 }
local function hdrText(t, x)
	local fs = Text(hdr, t, "GameFontNormalSmall")
	fs:SetPoint("LEFT", hdr, "LEFT", x, 0)
	return fs
end
hdrText("#", COLS.rank); hdrText("Player", COLS.name); hdrText("Bid", COLS.bid); hdrText("Roll", COLS.roll)
local hdrPR = hdrText("PR", COLS.pr)

local rows = {}
for i = 1, ROWS do
	local row = CreateFrame("Frame", nil, f)
	row:SetWidth(W - 32)
	row:SetHeight(15)
	row:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -202 - (i - 1) * 15)
	row.sel = row:CreateTexture(nil, "BACKGROUND")
	row.sel:SetAllPoints(row)
	row.sel:SetTexture(1, 0.82, 0, 0.18)
	row.sel:Hide()
	row.rank = Text(row, "", "GameFontHighlightSmall", 18)
	row.rank:SetPoint("LEFT", row, "LEFT", COLS.rank, 0)
	row.name = Text(row, "", "GameFontHighlightSmall", 100)
	row.name:SetPoint("LEFT", row, "LEFT", COLS.name, 0)
	row.bid = Text(row, "", "GameFontHighlightSmall", 42)
	row.bid:SetPoint("LEFT", row, "LEFT", COLS.bid, 0)
	row.pr = Text(row, "", "GameFontHighlightSmall", 52)
	row.pr:SetPoint("LEFT", row, "LEFT", COLS.pr, 0)
	row.roll = Text(row, "", "GameFontHighlightSmall", 36)
	row.roll:SetPoint("LEFT", row, "LEFT", COLS.roll, 0)
	row:Hide()
	rows[i] = row
end

local empty = Text(f, "No bids yet.", "GameFontDisableSmall", W - 32, "CENTER")
empty:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -206)
local more = Text(f, "", "GameFontDisableSmall", W - 32)
more:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -202 - ROWS * 15)
local winners = Text(f, "", "GameFontNormalSmall", W - 32)
winners:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)

-------------------------------------------------------------------------------
function UI:ShowWindow() f:Show() end
function UI:HideWindow() f:Hide() end
function UI:Toggle()
	if f:IsShown() then f:Hide() else f:Show(); self:Refresh() end
end

function UI:SavePosition()
	if not P.db then return end
	local left, top = f:GetLeft(), f:GetTop()
	if left and top then P.db.x, P.db.y = left, top end
end

function UI:ApplySaved()
	if P.db and P.db.x and P.db.y then
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", P.db.x, P.db.y)
	end
end

function UI:ResetPosition()
	if P.db then P.db.x, P.db.y = nil, nil end
	f:ClearAllPoints()
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	f:Show()
end

local function mmss(s)
	if s < 0 then s = 0 end
	return string.format("%d", math.ceil(s)) .. "s"
end

-- icon of the announced item. GetItemInfo is NOT free for an item this client has never seen (with some client
-- mods it can ask the server), so it is called rarely: at most once every 3 s, 6 times per announcement,
-- and the result is kept in the announcement itself.
function UI:UpdateIcon()
	local a = P.auction
	if not a then iconFrame:Hide(); self.iconPending = nil; return end
	if not a.iconTex and not a.iconGiveUp then
		local now = GetTime()
		if not a.iconNext or now >= a.iconNext then
			local _, _, id = string.find(a.link or "", "|Hitem:(%d+)")
			a.iconTries = (a.iconTries or 0) + 1
			a.iconNext = now + 3
			if id then
				local _, _, q, _, _, _, _, _, t = GetItemInfo("item:" .. id .. ":0:0:0")
				if t then a.iconTex, a.iconQ = t, q; if P.Options and P.Options:IsShown() then P.Options:Refresh() end end
			end
			if not a.iconTex and (a.iconTries >= 6 or not id) then a.iconGiveUp = true end
		end
	end
	if a.iconTex then
		itemIcon:SetTexture(a.iconTex)
		local c = a.iconQ and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[a.iconQ]
		if c then iconFrame:SetBackdropBorderColor(c.r, c.g, c.b, 1) else iconFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end
		iconFrame:Show()
		self.iconPending = nil
	else
		itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		iconFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
		iconFrame:Show()
		self.iconPending = not a.iconGiveUp
	end
end

function UI:UpdateTimer()
	local pa = P.auction
	if self.iconPending and pa and pa.iconNext and GetTime() >= pa.iconNext then self:UpdateIcon() end
	local a = P.auction
	if not a or not f:IsShown() then return end
	if a.state == "open" and not a.timed then
		timer:SetText("|cffffd700" .. (a.tie and "tie" or "rolling") .. "|r")
	elseif a.state == "open" then
		timer:SetText("|cffffd700" .. mmss(a.endTime - GetTime()) .. "|r")
	elseif a.state == "closed" then
		timer:SetText("|cffff8080closed|r")
	elseif a.state == "cancelled" then
		timer:SetText("|cff888888cancelled|r")
	else
		timer:SetText("|cff33cc33awarded|r")
	end
end

function UI:Refresh()
	if not P.db or not f:IsShown() then return end
	local a = P.auction
	local cfg = P.db.cfg
	local rf = a and a.src == "rf"
	title:SetText(rf and "RollFor - Loot" or "EPGP - Loot")
	if rf then hdrPR:Hide() else hdrPR:Show() end

	-- my priority (with RollFor: the roll ranges instead)
	local pr, ep, gp = P:MyPR()
	if rf then
		local th = a.th or {}
		myPR:SetText("|cff888888MS /roll " .. (th.ms or 100) .. ", OS " .. (th.os or 99) .. ((th.tm or 0) > 0 and (", Tmog " .. th.tm) or "") .. "|r")
	elseif pr then
		myPR:SetText(string.format("Priority: |cffffd700%.2f|r  |cff888888(EP %s / GP %s)|r", pr, tostring(math.floor(ep * 10 + 0.5) / 10), tostring(math.floor(gp * 10 + 0.5) / 10)))
	else
		myPR:SetText(P.db.noEntry and "Priority: |cffff8080you are not in the EPGP list|r" or "Priority: |cff888888requesting...|r")
	end

	if not a then
		itemText:SetText("|cff888888No announcement|r")
		iconFrame:Hide()
		timer:SetText("")
		for i = 1, NB do buttons[i]:Disable() end
		status:SetText("")
		for i = 1, ROWS do rows[i]:Hide() end
		empty:Show(); more:SetText(""); winners:SetText("")
		return
	end

	-- item
	itemText:SetText(a.link .. ((a.count or 1) > 1 and ("  |cffffd700x" .. a.count .. "|r") or ""))
	self:UpdateIcon()
	self:UpdateTimer()

	-- buttons
	for i = 1, NB do
		local choice = CHOICES[i]
		if P.IS_ROLL[choice] or rf then buttons[i]:SetText(P.LABEL[choice]) else buttons[i]:SetText(choice .. " (" .. cfg[choice] .. ")") end
		if P:CanChoose(choice) then buttons[i]:Enable() else buttons[i]:Disable() end
	end

	-- status line
	local s = ""
	if P.pending then
		s = "|cffffd700Sent " .. P.pending.choice .. ", waiting for confirmation...|r"
	elseif a.myChoice then
		local label = (a.myChoice == "ROLL" and a.rollLabel) or a.myChoice
		s = "Your choice: " .. colored(label, P.LABEL[label] or label)
		if rf then
			local mine = a.bids[string.lower(UnitName("player"))]
			if mine and mine.roll then s = s .. "  (/roll " .. P.RF:RollMax(a, a.myChoice) .. ": |cffffd700" .. mine.roll .. "|r)" end
		elseif a.myChoice == "NEED" and a.state == "open" then s = s .. "  (you can still go MAX)" end
	elseif a.state == "open" and a.blocked then
		s = "|cffff8080" .. a.blocked .. "|r"
	elseif a.state == "open" and a.tie then
		s = "|cffffd700Tie: roll again (/roll " .. (a.onlyMax or 100) .. ")|r"
	elseif a.state == "open" and a.onlyMax then
		s = "|cff888888Soft-reserved by you: /roll " .. a.onlyMax .. "|r"
	elseif a.state == "open" then
		s = "|cff888888Pick one: Roll MS, Roll OS, Tmog, MIN, NEED or MAX|r"
	elseif a.state == "cancelled" then
		s = "|cff888888Announcement cancelled.|r"
	else
		s = "|cff888888Bidding is over.|r"
	end
	status:SetText(s)

	-- list
	local list = P:SortedBids()
	local me = string.lower(UnitName("player"))
	for i = 1, ROWS do
		local row, b = rows[i], list[i]
		if b then
			row.rank:SetText(i)
			row.name:SetText((string.lower(b.char) == me and "|cffffd700" or "") .. b.char .. ((string.lower(b.char) == me) and "|r" or ""))
			row.bid:SetText(colored(b.bid))
			row.pr:SetText((rf or b.bid == "ROLL") and "" or string.format("%.2f", b.pr))
			row.roll:SetText(b.roll and tostring(b.roll) or "-")
			if string.lower(b.char) == me then row.sel:Show() else row.sel:Hide() end
			row:Show()
		else
			row:Hide()
		end
	end
	empty:SetText(a.state == "awarded" and "" or "No bids yet.")
	if table.getn(list) == 0 then empty:Show() else empty:Hide() end
	if table.getn(list) > ROWS then more:SetText("+ " .. (table.getn(list) - ROWS) .. " more") else more:SetText("") end

	-- winners
	if table.getn(a.winners) > 0 then
		local w = {}
		for _, x in ipairs(a.winners) do
			table.insert(w, x.char .. " (" .. x.bid .. (x.roll and (" " .. x.roll) or "") .. ((x.cost or 0) > 0 and (", " .. x.cost .. " GP") or "") .. ")")
		end
		winners:SetText("Winner: |cff33cc33" .. table.concat(w, ", ") .. "|r")
	else
		winners:SetText("")
	end
end

f:SetScript("OnShow", function() UI:Refresh() end)
