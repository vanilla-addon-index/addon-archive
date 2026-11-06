-------------------------------------------------------------------------------
-- SHAlts window. Built to match SHPlates: same 400x514 size, dialog-box frame,
-- grey inset panel, spellbook-style icon tabs down the right edge, a logo in
-- the top-left corner with a ring that turns nonstop, and a grip in the
-- bottom-right corner that scales the whole window.
-------------------------------------------------------------------------------
local S = SHAlts
local UI = {}
S.UI = UI

S.Try("UI.lua", function()

local W, H = 400, 514
local ROW_H = 21
local ROWS = 18
local POP_ROWS = 12
local MIN_SCALE, MAX_SCALE = .6, 1.6

S.tab = "bags"

local TABS = {
	{ key = "bags",     tip = "Bags",        icon = "Interface\\Icons\\INV_Misc_Bag_08" },
	{ key = "bank",     tip = "Bank",        icon = "Interface\\Icons\\INV_Misc_Bag_10" },
	{ key = "mail",     tip = "Mailbox",     icon = "Interface\\Icons\\INV_Letter_15" },
	{ key = "profs",    tip = "Professions", icon = "Interface\\Icons\\Trade_Alchemy" },
	{ key = "gear",     tip = "Gear",        icon = "Interface\\Icons\\INV_Chest_Plate07" },
	{ key = "cd",       tip = "Cooldowns and timers", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
	{ key = "raids",    tip = "Raids: server resets and who is saved", icon = "Interface\\Icons\\INV_Misc_Map_01" },
	{ key = "irc",      tip = "IRC: instance resets and raid lockouts", icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow" },
	{ key = "info",     tip = "Reputation, PvP and time played", icon = "Interface\\Icons\\INV_Misc_Note_01" },
	{ key = "settings", tip = "Settings",    icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

local BOX_BACKDROP = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function AddBlend(tex)
	if tex and tex.SetBlendMode then tex:SetBlendMode("ADD") end
end

-------------------------------------------------------------------------------
-- Spinning logo. 1.12 has no texture rotation, so a turn moves the texture
-- coordinates. The ring turns nonstop on the window; the logo does one quick
-- spin at the start of every ring turn. The minimap button reuses the logo
-- spin but keeps its ring still.
-------------------------------------------------------------------------------
local RING_TURN = 3       -- seconds for one full turn of the ring
local SPIN_TIME = .6      -- how long the logo's spin takes
local SPIN_K = .35355     -- half the diagonal of the visible square
local ringList, spinList = {}, {}
local ringClock = 0
local spinResting = false

function S.SetSpinAngle(tex, a)
	local c, s = math.cos(a), math.sin(a)
	local k = SPIN_K
	tex:SetTexCoord(
		.5 + k * (s - c), .5 - k * (s + c),   -- upper left
		.5 - k * (c + s), .5 + k * (c - s),   -- lower left
		.5 + k * (c + s), .5 + k * (s - c),   -- upper right
		.5 + k * (c - s), .5 + k * (s + c))   -- lower right
end

-- kind "ring": turns nonstop. kind "logo": spins once per ring turn.
function S.AddSpin(tex, owner, kind)
	S.SetSpinAngle(tex, 0)
	local list = spinList
	if kind == "ring" then list = ringList end
	table.insert(list, { tex = tex, owner = owner })
end

local spinFrame = CreateFrame("Frame")
spinFrame:SetScript("OnUpdate", function()
	ringClock = math.mod(ringClock + (arg1 or 0), RING_TURN)
	local ringAngle = -2 * math.pi * ringClock / RING_TURN
	for i = 1, table.getn(ringList) do
		local e = ringList[i]
		if e.owner:IsVisible() then S.SetSpinAngle(e.tex, ringAngle) end
	end
	local t = ringClock / SPIN_TIME
	if t < 1 then
		local eased = t * t * (3 - 2 * t)   -- ease in and out
		local angle = -2 * math.pi * eased
		for i = 1, table.getn(spinList) do
			local e = spinList[i]
			if e.owner:IsVisible() then S.SetSpinAngle(e.tex, angle) end
		end
		spinResting = false
	elseif not spinResting then
		for i = 1, table.getn(spinList) do S.SetSpinAngle(spinList[i].tex, 0) end
		spinResting = true
	end
end)

-------------------------------------------------------------------------------
-- The window
-------------------------------------------------------------------------------
local Config = CreateFrame("Frame", "SHAltsFrame", UIParent)
Config:Hide()
Config:SetWidth(W); Config:SetHeight(H)
Config:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
Config:SetFrameStrata("HIGH")
Config:SetMovable(true)
Config:EnableMouse(true)
Config:SetClampedToScreen(true)
Config:RegisterForDrag("LeftButton")
Config:SetScript("OnDragStart", function() this:StartMoving() end)
Config:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
Config:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
Config:SetBackdropColor(0, 0, 0, .9)
table.insert(UISpecialFrames, "SHAltsFrame")

-- Round logo over the top-left corner
local logoFrame = CreateFrame("Frame", nil, Config)
logoFrame:SetWidth(72); logoFrame:SetHeight(72)
logoFrame:SetPoint("TOPLEFT", Config, "TOPLEFT", -12, 12)
logoFrame:SetFrameLevel(Config:GetFrameLevel() + 5)
local logo = logoFrame:CreateTexture(nil, "ARTWORK")
logo:SetAllPoints(logoFrame)
logo:SetTexture(S.MEDIA .. "Logo")
S.AddSpin(logo, logoFrame, "logo")
-- the ring draws over the logo so their overlap hides the seam
local logoRing = logoFrame:CreateTexture(nil, "OVERLAY")
logoRing:SetAllPoints(logoFrame)
logoRing:SetTexture(S.MEDIA .. "LogoRing")
S.AddSpin(logoRing, logoFrame, "ring")

-- header sits a little right of center to balance the logo
local title = Config:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOP", Config, "TOP", 16, -18)
title:SetText("SHAlts")
local byline = Config:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
byline:SetPoint("TOP", title, "BOTTOM", 0, -2)
byline:SetText("by Fayz")
local statusLine = Config:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
statusLine:SetPoint("TOP", byline, "BOTTOM", 0, -6)
statusLine:SetWidth(W - 110); statusLine:SetHeight(12)

local close = CreateFrame("Button", "SHAltsFrameClose", Config, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", Config, "TOPRIGHT", -6, -6)

-- inset panel that holds the list
local inset = CreateFrame("Frame", nil, Config)
inset:SetPoint("TOPLEFT", Config, "TOPLEFT", 14, -100)
inset:SetPoint("BOTTOMRIGHT", Config, "BOTTOMRIGHT", -14, 28)  -- the strip below holds the scale grip
inset:SetBackdrop(BOX_BACKDROP)
inset:SetBackdropColor(0, 0, 0, .5)
inset:SetBackdropBorderColor(.4, .4, .4, 1)
inset:EnableMouse(true)
inset:EnableMouseWheel(true)

-------------------------------------------------------------------------------
-- Scrolling list
-------------------------------------------------------------------------------
local function GetOffset(list)
	local sf = list.scroll
	if FauxScrollFrame_GetOffset then return FauxScrollFrame_GetOffset(sf) or 0 end
	return sf.offset or 0
end

local function UpdateList(list)
	local n = table.getn(list.data)
	FauxScrollFrame_Update(list.scroll, n, list.nRows, ROW_H)
	local offset = GetOffset(list)
	for i = 1, list.nRows do
		local row = list.rows[i]
		local d = list.data[offset + i]
		if d then
			row.data = d
			list.fill(row, d)
			row:Show()
		else
			row.data = nil
			row:Hide()
		end
	end
end

local function ResetScroll(list)
	local sb = getglobal(list.scroll:GetName() .. "ScrollBar")
	if sb then sb:SetValue(0) end
	list.scroll.offset = 0
end

local function ScrollBy(list, dir)
	if table.getn(list.data) <= list.nRows then return end   -- nothing to scroll
	local sb = getglobal(list.scroll:GetName() .. "ScrollBar")
	if sb then sb:SetValue(sb:GetValue() - dir * ROW_H * 3) end
end

local function MakeRow(list, i)
	local b = CreateFrame("Button", list.name .. "Row" .. i, list.box)
	b:SetWidth(list.rowW); b:SetHeight(ROW_H)
	b:SetPoint("TOPLEFT", list.box, "TOPLEFT", 4, -4 - (i - 1) * ROW_H)
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	b:EnableMouseWheel(true)

	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints(b)
	b.bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	b.bg:Hide()

	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetWidth(16); b.icon:SetHeight(16)
	b.icon:SetPoint("LEFT", b, "LEFT", 4, 0)

	b.right = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.right:SetPoint("RIGHT", b, "RIGHT", -4, 0)
	b.right:SetWidth(list.rightW); b.right:SetHeight(12)
	b.right:SetJustifyH("RIGHT")

	b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.text:SetHeight(12)
	b.text:SetJustifyH("LEFT")

	b:SetScript("OnMouseWheel", function()
		if list.wheel then list.wheel(arg1) else ScrollBy(list, arg1) end
	end)
	b:SetScript("OnEnter", function() if list.enter then list.enter(this) end end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function() if list.click then list.click(this) end end)
	return b
end

-- text starts after the icon when the line has one
local function Layout(row, list, hasIcon)
	local x = 6
	if hasIcon then x = 24 end
	row.text:ClearAllPoints()
	row.text:SetPoint("LEFT", row, "LEFT", x, 0)
	row.text:SetWidth(list.rowW - x - list.rightW - 8)
end

local list = { name = "SHAltsLines", box = inset, nRows = ROWS, rowW = 342, rightW = 104, rows = {}, data = {} }
UI.list = list
do
	local sf = CreateFrame("ScrollFrame", "SHAltsLinesScroll", inset, "FauxScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
	sf:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -22, 4)
	list.scroll = sf
	sf:SetScript("OnVerticalScroll", function()
		FauxScrollFrame_OnVerticalScroll(ROW_H, function() UpdateList(list) end)
	end)
	inset:SetScript("OnMouseWheel", function() ScrollBy(list, arg1) end)
	for i = 1, ROWS do list.rows[i] = MakeRow(list, i) end
end

list.fill = function(row, d)
	if d.icon then
		row.icon:SetTexture(d.icon)
		row.icon:Show()
	else
		row.icon:Hide()
	end
	Layout(row, list, d.icon ~= nil)
	if S.tab == "raids" then
		-- the Raids tab has few lines, so give it bigger, easier to read text
		row.text:SetFont("Fonts\\FRIZQT__.TTF", 13)
		row.right:SetFont("Fonts\\FRIZQT__.TTF", 13)
		row.text:SetHeight(16); row.right:SetHeight(16)
		if (d.right or "") == "" then
			row.text:SetWidth(list.rowW - (d.icon and 24 or 6) - 8)
		end
	else
		row.text:SetFontObject(GameFontHighlightSmall)
		row.right:SetFontObject(GameFontHighlightSmall)
		row.text:SetHeight(12); row.right:SetHeight(12)
	end
	if d.header then
		row.text:SetTextColor(1, .82, 0)
		row.bg:SetVertexColor(1, .82, 0, .12)
		row.bg:Show()
	else
		row.text:SetTextColor(1, 1, 1)
		row.bg:Hide()
	end
	row.text:SetText(d.text or "")
	row.right:SetText(d.right or "")
end

list.enter = function(row)
	local d = row.data
	if not d then return end
	if d.id then
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		-- Only ask the game for items it already has cached; an unknown item
		-- link can disconnect a 1.12 client. Anything else gets a simple tooltip
		-- from what was stored.
		if GetItemInfo(d.id) then
			GameTooltip:SetHyperlink("item:" .. d.id .. ":0:0:0")
		else
			local it = S.db.items[d.id]
			GameTooltip:SetText("|c" .. ((it and it.c) or "ffffffff") .. ((it and it.n) or ("item:" .. d.id)) .. "|r")
			GameTooltip:AddLine("Full details show once this game has seen the item.", .6, .6, .6, 1)
		end
		GameTooltip:AddLine("|cff888888Shift-click to link in chat|r")
		GameTooltip:Show()
	elseif d.tip then
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		GameTooltip:SetText(d.tip[1])
		for i = 2, table.getn(d.tip) do GameTooltip:AddLine(d.tip[i], 1, 1, 1) end
		GameTooltip:Show()
	end
end

-- shift-click puts the item link in chat, ctrl-click tries it on
list.click = function(row)
	local d = row.data
	if d and d.action then d.action(); return end
	if not d or not d.id then return end
	local it = S.db.items[d.id]
	if not it or not it.n then return end
	local link = "|c" .. (it.c or "ffffffff") .. "|Hitem:" .. d.id .. ":0:0:0|h[" .. it.n .. "]|h|r"
	if IsShiftKeyDown() then
		if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
			ChatFrameEditBox:Insert(link)
		elseif ChatFrame_OpenChat then
			ChatFrame_OpenChat(link)
		end
	elseif IsControlKeyDown() and DressUpItemLink and GetItemInfo(d.id) then
		DressUpItemLink(link)
	end
end

-------------------------------------------------------------------------------
-- Alt dropdown
-------------------------------------------------------------------------------
local DD_W = 190

local ddButton = CreateFrame("Button", "SHAltsAltButton", Config)
ddButton:SetWidth(DD_W); ddButton:SetHeight(22)
ddButton:SetPoint("TOPLEFT", Config, "TOPLEFT", 14, -72)
ddButton:SetBackdrop(BOX_BACKDROP)
ddButton:SetBackdropColor(0, 0, 0, .6)
ddButton:SetBackdropBorderColor(.4, .4, .4, 1)
ddButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
AddBlend(ddButton:GetHighlightTexture())
local ddText = ddButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
ddText:SetPoint("LEFT", ddButton, "LEFT", 8, 0)
ddText:SetWidth(DD_W - 34); ddText:SetHeight(12)
ddText:SetJustifyH("LEFT")
local ddArrow = ddButton:CreateTexture(nil, "OVERLAY")
ddArrow:SetWidth(20); ddArrow:SetHeight(20)
ddArrow:SetPoint("RIGHT", ddButton, "RIGHT", -3, 0)
ddArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

local popup = CreateFrame("Frame", "SHAltsAltPopup", Config)
popup:Hide()
popup:SetFrameStrata("DIALOG")
popup:SetWidth(DD_W)
popup:SetPoint("TOPLEFT", ddButton, "BOTTOMLEFT", 0, -2)
popup:SetBackdrop(BOX_BACKDROP)
popup:SetBackdropColor(.05, .05, .05, .97)
popup:SetBackdropBorderColor(.6, .6, .6, 1)
popup:EnableMouse(true)

-- a click anywhere else closes the popup
local catcher = CreateFrame("Button", nil, UIParent)
catcher:Hide()
catcher:SetFrameStrata("DIALOG")
catcher:SetAllPoints(UIParent)
catcher:SetScript("OnClick", function() popup:Hide() end)

local pop = { name = "SHAltsAltPop", box = popup, nRows = POP_ROWS, rowW = DD_W - 8, rightW = 30, rows = {}, data = {} }
local popOffset = 0

local function UpdatePopup()
	local n = table.getn(pop.data)
	local maxOffset = n - POP_ROWS
	if maxOffset < 0 then maxOffset = 0 end
	if popOffset > maxOffset then popOffset = maxOffset end
	if popOffset < 0 then popOffset = 0 end
	local shown = n
	if shown > POP_ROWS then shown = POP_ROWS end
	popup:SetHeight(shown * ROW_H + 8)
	for i = 1, POP_ROWS do
		local row = pop.rows[i]
		local d = pop.data[popOffset + i]
		if d then
			row.data = d
			pop.fill(row, d)
			row:Show()
		else
			row.data = nil
			row:Hide()
		end
	end
end

pop.wheel = function(dir)
	popOffset = popOffset - dir
	UpdatePopup()
end

pop.fill = function(row, d)
	local c = d.c
	row.icon:Hide()
	Layout(row, pop, false)
	row.text:SetTextColor(1, 1, 1)
	row.text:SetText(S.ColoredName(c))
	row.right:SetText("|cffd8d8d8" .. (c.level or "?") .. "|r")
	if d.key == S.selected then
		row.bg:SetVertexColor(.2, .4, .8, .35)
		row.bg:Show()
	else
		row.bg:Hide()
	end
end

pop.click = function(row)
	if not row.data then return end
	S.selected = row.data.key
	popup:Hide()
	ResetScroll(list)
	UI.Refresh()
end

-- hover an alt for its level, class, realm, gold and when it was last seen
pop.enter = function(row)
	local d = row.data
	if not d then return end
	local c = d.c
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetText(S.ColoredName(c))
	GameTooltip:AddLine("Level " .. (c.level or "?") .. " " .. S.ClassName(c.class), 1, 1, 1)
	if c.realm and c.realm ~= "" then GameTooltip:AddLine(c.realm, .7, .7, .7) end
	GameTooltip:AddLine("Gold: " .. S.FormatMoney(c.money), 1, 1, 1)
	if c.seen and c.seen > 0 then GameTooltip:AddLine("Last seen " .. date("%Y-%m-%d %H:%M", c.seen), .6, .6, .6) end
	GameTooltip:Show()
end

for i = 1, POP_ROWS do pop.rows[i] = MakeRow(pop, i) end

popup:SetScript("OnShow", function()
	catcher:SetFrameLevel(popup:GetFrameLevel() - 1)
	catcher:Show()
end)
popup:SetScript("OnHide", function() catcher:Hide() end)

ddButton:SetScript("OnClick", function()
	if popup:IsShown() then
		popup:Hide()
		return
	end
	pop.data = S.SortedChars()
	-- start the list so the selected alt is in view
	popOffset = 0
	for i = 1, table.getn(pop.data) do
		if pop.data[i].key == S.selected then
			if i > POP_ROWS then popOffset = i - POP_ROWS end
			break
		end
	end
	popup:Show()
	UpdatePopup()
end)

-------------------------------------------------------------------------------
-- Search box
-------------------------------------------------------------------------------
local searchBox = CreateFrame("Frame", nil, Config)
searchBox:SetWidth(160); searchBox:SetHeight(22)
searchBox:SetPoint("TOPRIGHT", Config, "TOPRIGHT", -14, -72)
searchBox:SetBackdrop(BOX_BACKDROP)
searchBox:SetBackdropColor(0, 0, 0, .6)
searchBox:SetBackdropBorderColor(.4, .4, .4, 1)

local edit = CreateFrame("EditBox", "SHAltsSearch", searchBox)
edit:SetPoint("TOPLEFT", searchBox, "TOPLEFT", 7, -3)
edit:SetPoint("BOTTOMRIGHT", searchBox, "BOTTOMRIGHT", -7, 3)
edit:SetAutoFocus(false)
edit:SetMaxLetters(32)
edit:SetFontObject(GameFontHighlightSmall)

local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
placeholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
placeholder:SetText("Search all alts...")

local function UpdatePlaceholder()
	if edit:GetText() == "" and not edit.focused then placeholder:Show() else placeholder:Hide() end
end

edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
edit:SetScript("OnEditFocusGained", function() this.focused = true; UpdatePlaceholder() end)
edit:SetScript("OnEditFocusLost", function() this.focused = false; UpdatePlaceholder() end)
edit:SetScript("OnTextChanged", function()
	UpdatePlaceholder()
	ResetScroll(list)
	UI.Refresh()
end)

-------------------------------------------------------------------------------
-- Side tabs, spellbook style, down the right edge
-------------------------------------------------------------------------------
local tabs = {}

local function ShowTab(key)
	S.tab = key
	ResetScroll(list)
	UI.Refresh()
end
UI.ShowTab = ShowTab

for i = 1, table.getn(TABS) do
	local info = TABS[i]
	local t = CreateFrame("CheckButton", "SHAltsTab" .. i, Config)
	t:SetWidth(32); t:SetHeight(32)
	t:SetPoint("TOPLEFT", Config, "TOPLEFT", W - 4, -48 - (i - 1) * 44)
	local bg = t:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
	bg:SetWidth(64); bg:SetHeight(64)
	bg:SetPoint("TOPLEFT", t, "TOPLEFT", -3, 11)
	t:SetNormalTexture(info.icon)
	t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	AddBlend(t:GetHighlightTexture())
	t:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
	AddBlend(t:GetCheckedTexture())
	t.key = info.key
	t.tip = info.tip
	t:SetScript("OnClick", function() ShowTab(this.key) end)
	t:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tip)
		GameTooltip:Show()
	end)
	t:SetScript("OnLeave", function() GameTooltip:Hide() end)
	tabs[i] = t
end

-------------------------------------------------------------------------------
-- Settings tab
-------------------------------------------------------------------------------
local settings = CreateFrame("Frame", "SHAltsSettings", inset)
settings:SetAllPoints(inset)
settings:SetFrameLevel(inset:GetFrameLevel() + 3)
settings:EnableMouse(true)
settings:Hide()

local function SectionLabel(text, y)
	local fs = settings:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", settings, "TOPLEFT", 14, y)
	fs:SetText(text)
	return fs
end

local function Check(name, text, x, y, onClick)
	local cb = CreateFrame("CheckButton", name, settings, "UICheckButtonTemplate")
	cb:SetPoint("TOPLEFT", settings, "TOPLEFT", x, y)
	cb:SetWidth(24); cb:SetHeight(24)
	local label = getglobal(name .. "Text")
	if label then label:SetText(text) end
	cb:SetScript("OnClick", function() onClick(this:GetChecked() and true or false) end)
	return cb
end

local function Button(name, text, x, y, w, onClick)
	local b = CreateFrame("Button", name, settings, "UIPanelButtonTemplate")
	b:SetWidth(w); b:SetHeight(22)
	b:SetPoint("TOPLEFT", settings, "TOPLEFT", x, y)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function Note(text, x, y, w)
	local fs = settings:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	fs:SetPoint("TOPLEFT", settings, "TOPLEFT", x, y)
	fs:SetWidth(w or 330)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	return fs
end

SectionLabel("Window", -8)

-- the stock slider look; if this client lacks that template, a plain bar is used
local okSlider, alphaSlider = pcall(CreateFrame, "Slider", "SHAltsAlphaSlider", settings, "OptionsSliderTemplate")
if not okSlider or not alphaSlider then
	alphaSlider = CreateFrame("Slider", "SHAltsAlphaSlider", settings)
	alphaSlider:SetOrientation("HORIZONTAL")
	alphaSlider:SetBackdrop(BOX_BACKDROP)
	alphaSlider:SetBackdropColor(0, 0, 0, .6)
	alphaSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
end
alphaSlider:SetPoint("TOPLEFT", settings, "TOPLEFT", 24, -40)
alphaSlider:SetWidth(220); alphaSlider:SetHeight(16)
alphaSlider:SetMinMaxValues(.2, 1)
alphaSlider:SetValueStep(.05)
if getglobal("SHAltsAlphaSliderText") then getglobal("SHAltsAlphaSliderText"):SetText("Background opacity") end
if getglobal("SHAltsAlphaSliderLow") then getglobal("SHAltsAlphaSliderLow"):SetText("20%") end
if getglobal("SHAltsAlphaSliderHigh") then getglobal("SHAltsAlphaSliderHigh"):SetText("100%") end
alphaSlider:SetScript("OnValueChanged", function()
	if settings.loading then return end
	S.db.alpha = this:GetValue()
	UI.ApplyLook()
end)

local sortLabel = Note("Sort alts by", 24, -70, 80)
local sortName = Check("SHAltsSortName", "Name", 100, -64, function() S.db.sort = "name"; S.UIChanged() end)
local sortLevel = Check("SHAltsSortLevel", "Level", 170, -64, function() S.db.sort = "level"; S.UIChanged() end)
Button("SHAltsResetSize", "Reset size", 250, -66, 110, function() UI.SetScale(1) end)

SectionLabel("Features", -98)
local minimapCheck = Check("SHAltsMinimapCheck", "Minimap button", 20, -120, function(on)
	S.db.minimapHidden = not on
	if S.UpdateMinimapButton then S.UpdateMinimapButton() end
end)
local alertCheck = Check("SHAltsAlertCheck", "Cooldown alerts", 20, -144, function(on) S.db.alert = on end)
local resetAlertCheck = Check("SHAltsResetAlertCheck", "Reset sound alerts", 20, -168, function(on) S.db.resetAlerts = on end)
local announceCheck = Check("SHAltsAnnounceCheck", "Announce resets", 190, -120, function(on) S.db.resetAnnounce = on end)
local syncCheck = Check("SHAltsSyncCheck", "Share between accounts", 190, -144, function(on)
	S.db.sync = on
	if on and S.Sync then S.Sync() end
end)
local syncNote = Note("", 214, -170, 150)
Button("SHAltsTestAlert", "Test alert", 20, -198, 100, function() S.ShowAlertPreview() end)
Button("SHAltsRescan", "Rescan", 126, -198, 100, function()
	S.ScanAll()
	S.Print("scanned " .. UnitName("player"))
end)
Button("SHAltsChooseCds", "Choose cooldowns", 232, -198, 128, function() ShowTab("track") end)

SectionLabel("Remove an alt", -230)
local delBox = CreateFrame("EditBox", "SHAltsDeleteBox", settings, "InputBoxTemplate")
delBox:SetWidth(180); delBox:SetHeight(20)
delBox:SetPoint("TOPLEFT", settings, "TOPLEFT", 26, -252)
delBox:SetAutoFocus(false)
delBox:SetMaxLetters(24)
local delMsg = Note("", 24, -276, 330)

local function DoDelete()
	local typed = delBox:GetText()
	local n, why = S.DeleteChar(typed)
	if n then
		delMsg:SetText("|cff40ff40Removed " .. typed .. ".|r |cff888888It comes back if you play that character again.|r")
		delBox:SetText("")
	else
		delMsg:SetText("|cffff6060" .. why .. "|r")
	end
	delBox:ClearFocus()
end
Button("SHAltsDeleteButton", "Delete", 214, -250, 80, DoDelete)
delBox:SetScript("OnEnterPressed", DoDelete)
delBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
delBox:SetScript("OnTextChanged", function() if this:GetText() ~= "" then delMsg:SetText("") end end)

-- a timer of your own (an auction, a delivery, anything), shown for this character on all your alts
SectionLabel("Custom timer", -300)
local timerName = CreateFrame("EditBox", "SHAltsTimerName", settings, "InputBoxTemplate")
timerName:SetWidth(160); timerName:SetHeight(20)
timerName:SetPoint("TOPLEFT", settings, "TOPLEFT", 26, -336)
timerName:SetAutoFocus(false)
timerName:SetMaxLetters(30)
local timerTime = CreateFrame("EditBox", "SHAltsTimerTime", settings, "InputBoxTemplate")
timerTime:SetWidth(70); timerTime:SetHeight(20)
timerTime:SetPoint("TOPLEFT", settings, "TOPLEFT", 196, -336)
timerTime:SetAutoFocus(false)
timerTime:SetMaxLetters(14)
local timerMsg = Note("", 24, -360, 336)

local function DoAddTimer()
	local ok, a = S.AddTimer(timerName:GetText(), timerTime:GetText())
	if ok then
		timerMsg:SetText("|cff40ff40Started " .. a .. ".|r |cff888888See it on the Cooldowns tab.|r")
		timerName:SetText("")
		timerTime:SetText("")
	else
		timerMsg:SetText("|cffff6060" .. a .. "|r")
	end
	timerName:ClearFocus()
	timerTime:ClearFocus()
end
Button("SHAltsTimerAdd", "Start", 276, -334, 80, DoAddTimer)
timerName:SetScript("OnEnterPressed", function() timerTime:SetFocus() end)
timerName:SetScript("OnTabPressed", function() timerTime:SetFocus() end)
timerTime:SetScript("OnEnterPressed", DoAddTimer)
timerName:SetScript("OnEscapePressed", function() this:ClearFocus() end)
timerTime:SetScript("OnEscapePressed", function() this:ClearFocus() end)
timerName:SetScript("OnTextChanged", function() if this:GetText() ~= "" then timerMsg:SetText("") end end)
do
	local hint = settings:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", timerName, "TOPLEFT", 2, 1)
	hint:SetText("Name")
	local hint2 = settings:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint2:SetPoint("BOTTOMLEFT", timerTime, "TOPLEFT", 2, 1)
	hint2:SetText("Time, like 24h or 2d")
end

local function RefreshSettings()
	settings.loading = true
	alphaSlider:SetValue(S.db.alpha or .9)
	settings.loading = false
	local byLevel = (S.db.sort == "level")
	sortName:SetChecked(not byLevel and 1 or nil)
	sortLevel:SetChecked(byLevel and 1 or nil)
	minimapCheck:SetChecked(not S.db.minimapHidden and 1 or nil)
	alertCheck:SetChecked(S.db.alert and 1 or nil)
	resetAlertCheck:SetChecked(S.db.resetAlerts and 1 or nil)
	announceCheck:SetChecked(S.db.resetAnnounce and 1 or nil)
	syncCheck:SetChecked(S.db.sync and 1 or nil)
	if S.SyncAvailable and S.SyncAvailable() then
		syncNote:SetText("Alts from your other accounts show up here too.")
	else
		syncNote:SetText("Needs SuperWoW. Without it each account only sees its own alts.")
	end
end

-------------------------------------------------------------------------------
-- Scale grip (bottom-right corner), the same as SHPlates.
-- Drag to scale the whole window, right-click to reset to 100%.
-------------------------------------------------------------------------------
local function SetWindowScale(s, absLeft, absTop)
	if s < MIN_SCALE then s = MIN_SCALE end
	if s > MAX_SCALE then s = MAX_SCALE end
	s = math.floor(s * 100 + .5) / 100
	if not absLeft then
		local eff = Config:GetEffectiveScale()
		absLeft = Config:GetLeft() * eff
		absTop = Config:GetTop() * eff
	end
	Config:SetScale(s)
	-- keep the top-left corner where it was on screen
	local eff = Config:GetEffectiveScale()
	Config:ClearAllPoints()
	Config:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", absLeft / eff, absTop / eff)
	if S.db then S.db.scale = s end
end

local grip = CreateFrame("Button", "SHAltsScaleGrip", Config)
grip:SetWidth(16); grip:SetHeight(16)
grip:SetPoint("BOTTOMRIGHT", Config, "BOTTOMRIGHT", -10, 10)
grip:SetFrameLevel(Config:GetFrameLevel() + 10)
grip:EnableMouse(true)
grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
grip:SetNormalTexture(S.MEDIA .. "SizeGrabber-Up")
grip:SetPushedTexture(S.MEDIA .. "SizeGrabber-Down")
grip:SetHighlightTexture(S.MEDIA .. "SizeGrabber-Highlight")
grip:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText("Drag to resize")
	GameTooltip:AddLine("Right-click to reset", 1, 1, 1)
	GameTooltip:Show()
end)
grip:SetScript("OnLeave", function()
	if not this.sizing then GameTooltip:Hide() end
end)
grip:SetScript("OnMouseDown", function()
	if arg1 == "LeftButton" then
		local eff = Config:GetEffectiveScale()
		this.left = Config:GetLeft() * eff
		this.top = Config:GetTop() * eff
		this.sizing = true
		this:SetButtonState("PUSHED", 1)   -- stay pressed for the whole drag
	elseif arg1 == "RightButton" then
		SetWindowScale(1)
	end
end)
grip:SetScript("OnMouseUp", function()
	if this.sizing then
		this.sizing = false
		this:SetButtonState("NORMAL")
		GameTooltip:Hide()
	end
end)
grip:SetScript("OnUpdate", function()
	if not this.sizing then return end
	local cx, cy = GetCursorPosition()
	-- size the window so its bottom-right corner follows the cursor
	local wantEff = ((cx - this.left) / W + (this.top - cy) / H) / 2
	SetWindowScale(wantEff / UIParent:GetEffectiveScale(), this.left, this.top)
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText("Scale: " .. math.floor((S.db.scale or 1) * 100 + .5) .. "%")
	GameTooltip:Show()
end)

-------------------------------------------------------------------------------
-- Refresh and public functions
-------------------------------------------------------------------------------
local function RefreshInner()
	if not Config:IsShown() or not S.db then return end

	-- make sure something valid is selected
	if not S.selected or not S.db.chars[S.selected] then
		local mine = S.CharKey()
		if S.db.chars[mine] then
			S.selected = mine
		else
			local all = S.SortedChars()
			S.selected = all[1] and all[1].key or nil
		end
	end

	local sel = S.selected and S.db.chars[S.selected]
	if sel then
		ddText:SetText(S.ColoredName(sel) .. "  |cffaaaaaaLevel " .. (sel.level or "?") .. "|r")
	else
		ddText:SetText("|cff888888No characters yet|r")
	end
	if popup:IsShown() then
		pop.data = S.SortedChars()
		UpdatePopup()
	end

	-- the settings tab replaces the list (typing in the search box brings the list back)
	local showSettings = (S.tab == "settings") and edit:GetText() == ""
	if showSettings then
		popup:Hide()
		ddButton:Hide()
		list.data = {}
		UpdateList(list)
		settings:Show()
		RefreshSettings()
	else
		settings:Hide()
		ddButton:Show()
		list.data = S.BuildLines(S.tab, S.selected, edit:GetText())
		UpdateList(list)
	end

	for i = 1, table.getn(tabs) do
		tabs[i]:SetChecked(tabs[i].key == S.tab and 1 or nil)
	end

	local total, n = S.TotalGold()
	local word = "alts"
	if n == 1 then word = "alt" end
	statusLine:SetText("Total " .. S.FormatMoney(total) .. "  |cffaaaaaa(" .. n .. " " .. word .. ")|r")
end

function UI.Refresh()
	local ok, err = pcall(RefreshInner)
	if not ok and not S.refreshWarned then
		S.refreshWarned = true
		S.Print("|cffff5555window error|r " .. tostring(err))
	end
end

function UI.ApplyLook()
	if not S.db then return end
	Config:SetScale(S.db.scale or 1)
	Config:SetBackdropColor(0, 0, 0, S.db.alpha or .9)
end

-- for /shalts scale
function UI.SetScale(s)
	if Config:GetLeft() then
		SetWindowScale(s)
	else
		S.db.scale = s
		UI.ApplyLook()
	end
end

function UI.Show()
	UI.ApplyLook()
	-- pick up anything another account wrote since we last looked
	if S.SyncPull then S.SyncPull() end
	Config:Show()
end

function UI.Toggle()
	if Config:IsShown() then Config:Hide() else UI.Show() end
end

function UI.Search(text)
	UI.Show()
	edit:SetText(text or "")
	UI.Refresh()
end

Config:SetScript("OnShow", function() UI.Refresh() end)
Config:SetScript("OnHide", function() edit:ClearFocus(); popup:Hide() end)

S.On("PLAYER_LOGIN", function() UI.ApplyLook() end)

end)
