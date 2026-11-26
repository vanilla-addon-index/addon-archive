-- Options.lua : minimap button + pre-bids window
local P = SkullEPGPP
local O = {}
P.Options = O

-------------------------------------------------------------------------------
-- Minimap button
-------------------------------------------------------------------------------
local M = {}
P.Minimap = M
local btn = CreateFrame("Button", "SkullEPGPPlayerMinimapButton", Minimap)
btn:SetWidth(32)
btn:SetHeight(32)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:RegisterForDrag("LeftButton")
local icon = btn:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 6, -6)
local border = btn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(52)
border:SetHeight(52)
border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

function M:SetPosition(angle)
	angle = tonumber(angle) or 200
	local rad = math.rad(angle)
	btn:ClearAllPoints()
	btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(rad)), (80 * math.sin(rad)) - 52)
end

function M:Apply()
	if not P.db then return end
	-- positioned only once (pfUI and co. re-parent minimap buttons into their own bar)
	if not self.positioned then
		self.positioned = true
		self:SetPosition(P.db.minimapAngle)
	end
	if P.db.minimapHidden then btn:Hide() else btn:Show() end
end

btn:SetScript("OnDragStart", function()
	this:LockHighlight()
	this:SetScript("OnUpdate", function()
		local mx, my = GetCursorPosition()
		local scale = UIParent:GetScale()
		local x = Minimap:GetLeft() - mx / scale + 70
		local y = my / scale - Minimap:GetBottom() - 70
		local angle = math.deg(math.atan2(y, x))
		if angle < 0 then angle = angle + 360 end
		P.db.minimapAngle = angle
		M:SetPosition(angle)
	end)
end)
btn:SetScript("OnDragStop", function()
	this:SetScript("OnUpdate", nil)
	this:UnlockHighlight()
end)
btn:SetScript("OnClick", function()
	if arg1 == "RightButton" then P.UI:Toggle() else O:Toggle() end
end)
btn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText("Skull EPGP - Player")
	GameTooltip:AddLine("Click: pre-bids", 1, 1, 1)
	GameTooltip:AddLine("Right-click: show / hide the bidding window", 1, 1, 1)
	GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-------------------------------------------------------------------------------
-- Pre-bids window
-------------------------------------------------------------------------------
local ROWS, W, H, PITCH = 8, 360, 440, 28
local BIDNAME = { MS = "Roll MS", OS = "Roll OS", TMOG = "Tmog", ROLL = "Roll MS", MIN = "Min", NEED = "Need", MAX = "Max" }
local COLOR = { MIN = "|cff33cc33", NEED = "|cffff8000", MAX = "|cffff3333", ROLL = "|cffcccccc",
	MS = "|cffcccccc", OS = "|cff99bbdd", TMOG = "|cffcc99dd" }
local f = CreateFrame("Frame", "SkullEPGPPlayerOptions", UIParent)
f:SetWidth(W)
f:SetHeight(H)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetFrameStrata("DIALOG")
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
f:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
f:Hide()

local function Text(parent, text, font, w, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	if text then fs:SetText(text) end
	if w then fs:SetWidth(w) end
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

local title = Text(f, "Skull EPGP - Pre-bids", "GameFontNormal", 240, "CENTER")
title:SetPoint("TOP", f, "TOP", 0, -14)
local close = CreateFrame("Button", "SkullEPGPPlayerOptionsClose", f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

local onlyCheck = CreateFrame("CheckButton", "SkullEPGPPlayerOnlyPrebids", f, "UICheckButtonTemplate")
onlyCheck:SetWidth(24)
onlyCheck:SetHeight(24)
onlyCheck:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -34)
local onlyLabel = Text(f, "Only pre-bids: never open the bidding window by itself", "GameFontNormalSmall", W - 80)
onlyLabel:SetPoint("LEFT", onlyCheck, "RIGHT", 4, 0)
onlyCheck:SetScript("OnClick", function()
	P.db.onlyPrebids = (this:GetChecked() and true or false)
end)

local intro = Text(f, "When the loot master announces one of these items, your bid is sent automatically in the chat. The item is removed from the list when you win it.", "GameFontHighlightSmall", W - 40)
intro:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -62)

-- add bar (top of the list)
local box = CreateFrame("EditBox", "SkullEPGPPlayerPrebidBox", f, "InputBoxTemplate")
box:SetWidth(220)
box:SetHeight(20)
box:SetAutoFocus(false)
box:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -108)
box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
local function DoAdd()
	local text = box:GetText()
	if text and text ~= "" then
		local ok = P:AddToList("prebid", text)
		if ok then box:SetText(""); box:ClearFocus(); O:Refresh() else P:Print("Could not add this item.") end
	end
end
box:SetScript("OnEnterPressed", DoAdd)
local add = CreateFrame("Button", "SkullEPGPPlayerPrebidAdd", f, "UIPanelButtonTemplate")
add:SetWidth(60)
add:SetHeight(22)
add:SetPoint("LEFT", box, "RIGHT", 6, 0)
add:SetText("Add")
add:SetScript("OnClick", DoAdd)
local addHelp = Text(f, "Shift-click an item (bag or chat) into the box, or type its id / name.", "GameFontDisableSmall", W - 40)
addHelp:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -132)

-- preview of what is typed: icon + link (the lookup waits 0.5 s after the last key: an id passes through many unknown ids)
local function ShowPreview(p, text)
	local link, tex = P:ResolveItem(text)
	p.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
	if link then p.text:SetText(link) else p.text:SetText("|cffaaaaaa" .. text .. " (not found: will be matched by name / id)|r") end
end
local prev = CreateFrame("Frame", nil, f)
prev:SetWidth(W - 56)
prev:SetHeight(26)
prev:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -148)
prev.icon = prev:CreateTexture(nil, "ARTWORK")
prev.icon:SetWidth(24)
prev.icon:SetHeight(24)
prev.icon:SetPoint("LEFT", prev, "LEFT", 0, 0)
prev.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
prev.text = Text(prev, "", "GameFontNormalSmall", W - 90)
prev.text:SetPoint("LEFT", prev.icon, "RIGHT", 6, 0)
prev:SetScript("OnUpdate", function()
	if prev.due and GetTime() >= prev.due then prev.due = nil; ShowPreview(prev, prev.want) end
end)
prev:Hide()

-- last announced item
local cur = CreateFrame("Frame", "SkullEPGPPlayerPrebidLast", f)
cur:SetWidth(W - 56)
cur:SetHeight(26)
cur:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -148)
local curText = Text(cur, "", "GameFontNormalSmall", W - 56 - 74)
curText:SetPoint("LEFT", cur, "LEFT", 0, 0)
local curAdd = CreateFrame("Button", "SkullEPGPPlayerPrebidAddCurrent", cur, "UIPanelButtonTemplate")
curAdd:SetWidth(64)
curAdd:SetHeight(22)
curAdd:SetPoint("RIGHT", cur, "RIGHT", 0, 0)
curAdd:SetText("Add")
curAdd:SetScript("OnClick", function()
	local a = P.auction
	if a and a.link and P:AddToList("prebid", a.link) then P:Print("Pre-bid list: added " .. a.link) end
	O:Refresh()
end)
cur:Hide()

box:SetScript("OnTextChanged", function()
	local t = box:GetText()
	if not t or t == "" then
		prev.due = nil; prev:Hide()
	else
		prev.want = t; prev.due = GetTime() + 0.5
		prev.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		prev.text:SetText("|cffaaaaaa...|r")
		prev:Show()
	end
	O:Refresh()
end)

-- rows
local rows = {}
for i = 1, ROWS do
	local row = CreateFrame("Frame", nil, f)
	row:SetWidth(W - 70)
	row:SetHeight(24)
	row:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -184 - (i - 1) * PITCH)
	row:EnableMouse(true)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(22)
	row.icon:SetHeight(22)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.text = Text(row, "", "GameFontHighlightSmall", W - 70 - 28 - 122)
	row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.drop = CreateFrame("Frame", "SkullEPGPPlayerPrebidDrop" .. i, row, "UIDropDownMenuTemplate")
	row.drop:SetPoint("RIGHT", row, "RIGHT", -16, -2)
	UIDropDownMenu_SetWidth(64, row.drop)
	UIDropDownMenu_Initialize(row.drop, function()
		local e = row.key and P.db.lists.prebid[row.key]
		for k = 1, table.getn(P.BIDS) do
			local info = {}
			local bid = P.BIDS[k]          -- local of the loop body: one per entry (this.value is not reliable here)
			info.text = BIDNAME[bid]
			info.value = bid
			info.checked = (e and (e.bid or "NEED") == bid)
			info.func = function()
				if row.key then P:SetPrebid(row.key, bid); P:Print("Pre-bid set to " .. BIDNAME[bid]) end
				O:Refresh()
			end
			UIDropDownMenu_AddButton(info)
		end
	end)
	row.del = CreateFrame("Button", nil, row, "UIPanelCloseButton")
	row.del:SetWidth(22)
	row.del:SetHeight(22)
	row.del:SetPoint("RIGHT", row, "RIGHT", 4, 0)
	row.del:SetScript("OnClick", function()
		if row.key then P:RemoveFromList("prebid", row.key); O:Refresh() end
	end)
	row:SetScript("OnEnter", function()
		if row.link then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			local _, _, str = string.find(row.link, "(item:%d+:%d+:%d+:%d+)")
			if str then GameTooltip:SetHyperlink(str) end
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:Hide()
	rows[i] = row
end
local empty = Text(f, "(no pre-bid yet)", "GameFontDisableSmall", 200)
empty:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -188)
f:EnableMouseWheel(true)
f:SetScript("OnMouseWheel", function()
	if arg1 > 0 then O.offset = math.max(0, (O.offset or 0) - 1) else O.offset = (O.offset or 0) + 1 end
	O:Refresh()
end)

-- scrollbar
local setting = false
local bar = CreateFrame("Slider", "SkullEPGPPlayerPrebidScroll", f)
bar:SetWidth(16)
bar:SetHeight(ROWS * PITCH - 4)
bar:SetPoint("TOPLEFT", f, "TOPLEFT", W - 34, -184)
bar:SetOrientation("VERTICAL")
bar:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
	tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } })
bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
local thumb = bar:GetThumbTexture()
if thumb then thumb:SetWidth(18); thumb:SetHeight(24) end
bar:SetMinMaxValues(0, 1)
bar:SetValueStep(1)
bar:SetValue(0)
bar:SetScript("OnValueChanged", function()
	if setting then return end
	O.offset = math.floor((arg1 or 0) + 0.5)
	O:Refresh()
end)
bar:Hide()

-- shift-click on an item while the box has the keyboard focus: put the item in the box
local function BoxHasFocus() return GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() == box end
local oldSetItemRef = SetItemRef
if oldSetItemRef then
	SetItemRef = function(link, text, button)
		if IsShiftKeyDown() and BoxHasFocus() and text and string.find(text, "Hitem:") then
			box:SetText(text)
			return
		end
		return oldSetItemRef(link, text, button)
	end
end
local oldContainerClick = ContainerFrameItemButton_OnClick
if oldContainerClick then
	ContainerFrameItemButton_OnClick = function(button, ignoreModifiers)
		if IsShiftKeyDown() and BoxHasFocus() and button == "LeftButton" then
			local link = GetContainerItemLink(this:GetParent():GetID(), this:GetID())
			if link then box:SetText(link); return end
		end
		return oldContainerClick(button, ignoreModifiers)
	end
end

function O:Refresh()
	if not P.db then return end
	onlyCheck:SetChecked(P.db.onlyPrebids and 1 or nil)
	local a = P.auction
	if a and a.link and box:GetText() == "" then
		curText:SetText("Last: " .. a.link)
		if P:InList("prebid", a.link) then curAdd:Disable() else curAdd:Enable() end
		cur:Show()
	else
		cur:Hide()
	end
	local list = P:ListEntries("prebid")
	local n = table.getn(list)
	local maxOff = math.max(0, n - ROWS)
	if (self.offset or 0) > maxOff then self.offset = maxOff end
	if (self.offset or 0) < 0 then self.offset = 0 end
	for i = 1, ROWS do
		local it = list[(self.offset or 0) + i]
		local row = rows[i]
		if it then
			local lk = P:MakeLink(it.e.id, it.e.link); if lk then it.e.link = lk end
			row.key = it.key
			row.link = it.e.link
			if not it.e.tex and it.e.id and (it.e.tries or 0) < 3 then
				it.e.tries = (it.e.tries or 0) + 1
				local _, _, _, _, _, _, _, _, t = GetItemInfo("item:" .. it.e.id .. ":0:0:0")
				if t then it.e.tex = t end
			end
			row.icon:SetTexture(it.e.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
			row.text:SetText(it.e.link or ("|cffffffff[" .. (it.e.name or "?") .. "]|r"))
			local b = it.e.bid or "NEED"
			UIDropDownMenu_SetText((COLOR[b] or "") .. BIDNAME[b] .. "|r", row.drop)
			row:Show()
		else
			row.key = nil; row.link = nil; row:Hide()
		end
	end
	if n == 0 then empty:Show() else empty:Hide() end
	setting = true
	bar:SetMinMaxValues(0, maxOff)
	bar:SetValue(self.offset or 0)
	setting = false
	if maxOff > 0 then bar:Show() else bar:Hide() end
end

-- icons of items this client has not seen yet: retried once a second (3 tries per item)
local acc = 0
f:SetScript("OnUpdate", function()
	acc = acc + (arg1 or 0)
	if acc < 1 then return end
	acc = 0
	for _, e in pairs(P.db.lists.prebid) do
		if not e.tex and e.id and (e.tries or 0) < 3 then O:Refresh(); return end
	end
end)

function O:IsShown() return f:IsShown() end

function O:Toggle()
	if f:IsShown() then f:Hide() else f:Show(); self:Refresh() end
end
f:SetScript("OnShow", function() O:Refresh() end)
