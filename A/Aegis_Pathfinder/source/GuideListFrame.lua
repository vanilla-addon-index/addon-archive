--[[
	GuideListFrame.lua -- the guide browser.

	Laid out like Zygor's guide menu: HOME, CURRENT and RECENT along the top;
	search and the categories down the left; a category's folders and guides
	in the middle; and on the right the guide you point at -- its picture,
	its levels, how far through it you are, and the buttons that open it.
	Home is four panels: the guides you opened last, what fits you now, the
	time spent at each level, and the gold earned today and this week.

	What it lists is GuideBrowser.lua's, the pictures GuidePictures.lua's.
	The clicks are the old list's: left-click opens a guide beside the one
	you are on, right-click loads it in the tab you are on, shift-click
	resets its progress; picking a RestedXP guide switches to a RestedXP
	route pack, so the route goes on with guides that follow it.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme
local Browser = AegisPathfinder.Browser

local DEFAULT_W, DEFAULT_H = 880, 560
local MIN_W, MIN_H, MAX_W, MAX_H = 820, 520, 1280, 860
local HEADER_H = 30            -- Theme:Header's
local SIDE_W, PANE_W = 196, 268
local BAR_H = 50               -- the title bar over the list
local ROW_H = 26
local MAX_ROWS = math.ceil((MAX_H - HEADER_H - BAR_H) / ROW_H)
local PIC_W, PIC_H = 240, 135
local SEP = " / "

local ui = {}                  -- the widgets, by name
--[[ What the browser shows: `tab` "home", "current" or "recent", or nil
	with `category` open; `path` the folders opened in it, by title; `page`
	"levels" for the level tracker's own page; `search` what is typed in the
	box; `selected` the guide the right pane shows. ]]
local view = { tab = "home", path = {}, offset = 0, search = "" }
local entries = {}             -- the list's rows, as last built

local function Char() return AegisPathfinder.db.char end
local function Refresh() AegisPathfinder:UpdateGuideListPanel() end

-- A colour from Theme as a chat colour code, for text in two colours.
local function Code(c)
	return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

-- A flat fill for a row or panel, `name` a Theme colour.
local function Fill(f, layer, name, alpha)
	local t = f:CreateTexture(nil, layer or "BACKGROUND")
	t:SetTexture(Theme.texture.solid)
	t:SetAllPoints(f)
	Theme:Tint(t, name, alpha)
	return t
end

local function Glyph(f, name, size)
	local t = f:CreateTexture(nil, "ARTWORK")
	t:SetTexture(Theme.glyph[name] or Theme.actionIcon[name] or name)
	t:SetWidth(size)
	t:SetHeight(size)
	return t
end

local function Text(f, role, size, color)
	local fs = f:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(fs, role, size)
	Theme:TextColor(fs, color or "text")
	fs:SetJustifyH("LEFT")
	return fs
end

--[[ Picking a guide ---------------------------------------------------------- ]]

--[[ A guide picked from the browser opens in a tab of its own, or its tab if
	it has one: the guide you are reading keeps its tab and its place. Picking
	one changes nothing else -- not the guide in another tab, not your route
	pack (the Route page's to choose); a guide picked off your route goes on
	by its own next link. Loading over the tab you were on, and switching to a
	RestedXP pack when a RestedXP guide was picked, are what put a Hardcore
	guide in place of the one you were on. ]]
local function PickGuide(name)
	local self = AegisPathfinder
	if not name then return end
	if IsShiftKeyDown() then
		self.db.char.completion[name] = nil
		self.db.char.turnins[name] = {}
		Theme:HideTip()
		return Refresh()
	end
	self:OpenGuideTab(name)
	Refresh()
end

--[[ Where to go ---------------------------------------------------------------- ]]

local function HideOptions()
	if ui.options then ui.options:Hide() end
end

-- Clear the search box without its OnTextChanged starting a search.
local function ClearSearch()
	view.search = ""
	if ui.search then
		ui.quiet = true
		ui.search:SetText("")
		ui.quiet = nil
		ui.search:ClearFocus()
	end
end

--- Open a header tab ("home", "current", "recent"), or with `tab` nil a
--- sidebar category.
local function Open(tab, category)
	view.tab, view.category, view.path, view.page, view.offset = tab, category, {}, nil, 0
	Char().browsertab = tab or category
	ClearSearch()
	HideOptions()
	Refresh()
end

local function Back()
	view.offset = 0
	if view.search ~= "" then
		ClearSearch()
	elseif view.page then
		view.page = nil
	elseif table.getn(view.path) > 0 then
		table.remove(view.path)
	end
	Refresh()
end

--[[ The window ------------------------------------------------------------------ ]]

-- Parented to UIParent, not the guide: a child of a hidden frame cannot be
-- shown, and the guide window can be closed.
local frame = CreateFrame("Frame", "AegisPathfinderGuideList", UIParent)
AegisPathfinder.guidelistframe = frame
frame:SetFrameStrata("DIALOG")
frame:SetWidth(DEFAULT_W)
frame:SetHeight(DEFAULT_H)
frame:SetPoint("TOPRIGHT", AegisPathfinder.objectiveframe, "TOPLEFT", -8, 0)
Theme:Panel(frame, "panel")
frame:Hide()

local header = Theme:Chrome(frame, nil, Theme:PositionSaver("guidelistframe"))
ui.header = header

-- HOME, CURRENT, RECENT: the header's left, an accent line under the one open.
local function HeaderTab(key, label)
	local b = CreateFrame("Button", nil, header)
	b:SetHeight(HEADER_H - 2)
	local fs = Text(b, "display", 13, "textDim")
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	fs:SetText(string.upper(label))
	b:SetWidth(math.ceil(fs:GetStringWidth() or 40) + 18)
	local line = b:CreateTexture(nil, "OVERLAY")
	line:SetTexture(Theme.texture.solid)
	line:SetHeight(2)
	line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 6, 0)
	line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 0)
	Theme:Tint(line, "accent")
	b.label, b.line, b.key = fs, line, key
	function b:SetActive(on)
		self.active = on
		Theme:TextColor(self.label, on and "accent" or "textDim")
		if on then self.line:Show() else self.line:Hide() end
	end
	b:SetScript("OnClick", function() Open(this.key, nil) end)
	b:SetScript("OnEnter", function() if not this.active then Theme:TextColor(this.label, "text") end end)
	b:SetScript("OnLeave", function() if not this.active then Theme:TextColor(this.label, "textDim") end end)
	b:SetActive(false)
	return b
end

ui.tabs = {}
for i, def in ipairs({ { "home", "Home" }, { "current", "Current" }, { "recent", "Recent" } }) do
	local b = HeaderTab(def[1], def[2])
	if i == 1 then b:SetPoint("LEFT", header, "LEFT", 10, 0)
	else b:SetPoint("LEFT", ui.tabs[i - 1], "RIGHT", 4, 0) end
	ui.tabs[i] = b
end

-- Return to Main, beside the close chip, while a guide is open beside the route.
local returnBtn = Theme:PanelButton(header, "Return to Main", 120, 18)
returnBtn:SetPoint("RIGHT", header, "RIGHT", -34, 0)
returnBtn:SetScript("OnClick", function()
	AegisPathfinder:ReturnFromBranch()
	Refresh()
end)
frame.returnBtn = returnBtn

--[[ The sidebar ------------------------------------------------------------------ ]]

local side = CreateFrame("Frame", nil, frame)
side:SetWidth(SIDE_W)
side:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -HEADER_H - 1)
side:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
-- Rounded at the bottom, where it meets the window's corner.
Theme:CapStrip(side, "panel3", "bottom")
local sideEdge = side:CreateTexture(nil, "BORDER")
sideEdge:SetTexture(Theme.texture.solid)
sideEdge:SetWidth(1)
sideEdge:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, 0)
sideEdge:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, 0)
Theme:Tint(sideEdge, "border")
ui.side = side

-- The search box: a dark field, a magnifier, and a hint while it is empty.
local search = CreateFrame("EditBox", nil, side)
search:SetHeight(26)
search:SetPoint("TOPLEFT", side, "TOPLEFT", 10, -12)
search:SetPoint("TOPRIGHT", side, "TOPRIGHT", -10, -12)
search:SetAutoFocus(false)
search:SetTextInsets(24, 6, 0, 0)
search:SetMaxLetters(40)
Theme:SetFont(search, "body", 12)
search:SetTextColor(Theme.color.text[1], Theme.color.text[2], Theme.color.text[3])
Theme:NineSlice(search, Theme.texture.tabFill, "BACKGROUND", "panel2")
Theme:NineSlice(search, Theme.texture.tabBorder, "BORDER", "subtle")
local lens = Glyph(search, "search", 12)
lens:SetPoint("LEFT", search, "LEFT", 7, 0)
Theme:Tint(lens, "textDim")
local hint = Text(search, "body", 12, "textDim")
hint:SetPoint("LEFT", search, "LEFT", 24, 0)
hint:SetText("Search guides")
local function ShowHint()
	if search:GetText() == "" and not search.focused then hint:Show() else hint:Hide() end
end
search:SetScript("OnTextChanged", function()
	ShowHint()
	if ui.quiet then return end
	view.search, view.offset = this:GetText() or "", 0
	HideOptions()
	Refresh()
end)
search:SetScript("OnEditFocusGained", function() this.focused = true; ShowHint() end)
search:SetScript("OnEditFocusLost", function() this.focused = nil; ShowHint() end)
search:SetScript("OnEscapePressed", function() this:SetText(""); this:ClearFocus() end)
search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
search:SetScript("OnHide", function() this:ClearFocus() end)
ui.search = search

-- A sidebar row: a category's badge or glyph, and its name.
local function SideRow(def, y, h)
	local b = CreateFrame("Button", nil, side)
	b:SetHeight(h)
	b:SetPoint("TOPLEFT", side, "TOPLEFT", 8, y)
	b:SetPoint("TOPRIGHT", side, "TOPRIGHT", -9, y)
	b.fill = Fill(b, "BACKGROUND", "tabbg")
	b.fill:Hide()
	b.bar = b:CreateTexture(nil, "BORDER")
	b.bar:SetTexture(Theme.texture.solid)
	b.bar:SetWidth(3)
	b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	Theme:Tint(b.bar, "accent")
	b.bar:Hide()
	Fill(b, "HIGHLIGHT", "text", 0.05)
	if def.badge then
		b.icon = Theme:Badge(b, def.badge, def.badge)
		b.icon:SetPoint("LEFT", b, "LEFT", 10, 0)
	else
		b.icon = Glyph(b, def.glyph, 14)
		b.icon:SetPoint("LEFT", b, "LEFT", 14, 0)
		Theme:Tint(b.icon, def.key == "favorites" and "gold" or "textDim")
	end
	b.label = Text(b, "body", 13)
	b.label:SetPoint("LEFT", b, "LEFT", 44, 0)
	b.label:SetText(def.label)
	b.key = def.key
	return b
end

ui.categories = {}
do
	local y = -50
	for _, def in ipairs(Browser.CATEGORIES) do
		if not def.soon then
			local b = SideRow(def, y, 28)
			b:SetScript("OnClick", function() Open(nil, this.key) end)
			table.insert(ui.categories, b)
			y = y - 30
		end
	end
	local soon = Text(side, "display", 11, "textDim")
	soon:SetPoint("TOPLEFT", side, "TOPLEFT", 18, y - 10)
	soon:SetText("COMING SOON")
	y = y - 30
	for _, def in ipairs(Browser.CATEGORIES) do
		if def.soon then
			local b = SideRow(def, y, 24)
			b:SetAlpha(0.45)
			b:SetScript("OnEnter", function() Theme:ShowTip(this, "RIGHT", "Coming soon") end)
			b:SetScript("OnLeave", function() Theme:HideTip(this) end)
			y = y - 25
		end
	end
end

-- Options, at the bottom: the addon's settings.
local optionsRow = SideRow({ key = "options", label = "Options", glyph = "gear" }, 0, 30)
optionsRow:ClearAllPoints()
optionsRow:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 8, 10)
optionsRow:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -9, 10)
Theme:TextColor(optionsRow.label, "textDim")
optionsRow:SetScript("OnClick", function() AegisPathfinder:ToggleConfigPanel() end)
Theme:Divider(side, optionsRow, "TOPLEFT", 0, 6, SIDE_W - 17)

--[[ The middle: a title bar, and the list or the Home panels under it ------------ ]]

local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1 - PANE_W, 1)
ui.content = content

local bar = CreateFrame("Frame", nil, content)
bar:SetHeight(BAR_H)
bar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
bar:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
local barRule = bar:CreateTexture(nil, "BORDER")
barRule:SetTexture(Theme.texture.solid)
barRule:SetHeight(1)
barRule:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
barRule:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
Theme:Tint(barRule, "tabbg")
ui.back = Theme:GlyphButton(bar, "chevronLeft", 12, 26)
ui.back:SetPoint("LEFT", bar, "LEFT", 8, 0)
ui.back:SetScript("OnClick", Back)
ui.crumb = Text(bar, "body", 11, "textDim")
ui.title = Text(bar, "display", 18)
ui.title:SetPoint("TOPLEFT", ui.crumb, "BOTTOMLEFT", 0, -2)
ui.dots = Theme:GlyphButton(bar, "dots", 14, 26)
ui.dots:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
ui.dots:SetScript("OnClick", function()
	if ui.options:IsShown() then ui.options:Hide() else ui.options:Show() end
end)
ui.dots:SetScript("OnEnter", function()
	Theme:Tint(this.glyph, this.__hover)
	Theme:ShowTip(this, "BOTTOM", view.tab == "home" and not view.page and "Home panels" or "List options")
end)
ui.dots:SetScript("OnLeave", function()
	Theme:Tint(this.glyph, this.__idle)
	Theme:HideTip(this)
end)

--[[ The list ---------------------------------------------------------------- ]]

local list = CreateFrame("Frame", nil, content)
list:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
list:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 4)
ui.list = list

local function ShowHover(row, on)
	if not row.guide then on = false end
	local icons = on or row.favorite
	if icons then row.star:Show() else row.star:Hide() end
	if on then row.load:Show() else row.load:Hide() end
	-- What the row says on the right ("Raid", "45%") moves left of the star
	-- and arrow while they show, and the title stops short of it.
	local edge = icons and 56 or 10
	row.right:ClearAllPoints()
	row.right:SetPoint("RIGHT", row, "RIGHT", -edge, 0)
	local said = row.right:GetText() or ""
	local width = said ~= "" and row.right:GetStringWidth() or 0
	row.text:ClearAllPoints()
	row.text:SetPoint("LEFT", row, "LEFT", 34, 0)
	row.text:SetPoint("RIGHT", row, "RIGHT", -math.max(60, edge + width + 10), 0)
end

local function MarkSelection()
	for _, row in ipairs(ui.rows) do
		local on = row.guide ~= nil and row.guide == view.selected
		if on then row.fill:Show(); row.bar:Show() else row.fill:Hide(); row.bar:Hide() end
	end
end

local PaintPane

local function RowEnter()
	ShowHover(this, true)
	if this.guide and view.selected ~= this.guide then
		view.selected = this.guide
		MarkSelection()
		PaintPane()
	end
end

local function RowLeave() ShowHover(this, false) end

local function RowClick()
	local row = this
	if row.folder then
		table.insert(view.path, row.folder)
		view.offset = 0
		Refresh()
	elseif row.guide then
		PickGuide(row.guide)
	end
end

local function NewRow(i)
	local row = CreateFrame("Button", nil, list)
	row:SetHeight(ROW_H)
	row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * ROW_H)
	row:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -(i - 1) * ROW_H)
	row.fill = Fill(row, "BACKGROUND", "tabbg")
	row.bar = row:CreateTexture(nil, "BORDER")
	row.bar:SetTexture(Theme.texture.solid)
	row.bar:SetWidth(3)
	row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	Theme:Tint(row.bar, "accent")
	row.hl = Fill(row, "HIGHLIGHT", "text", 0.05)
	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.mark:SetWidth(12)
	row.mark:SetHeight(12)
	row.mark:SetPoint("LEFT", row, "LEFT", 14, 0)
	row.badge = Theme:Badge(row, "XP", "xp")
	row.badge:SetPoint("LEFT", row, "LEFT", 10, 0)
	row.text = Text(row, "body", 13)
	row.text:SetPoint("LEFT", row, "LEFT", 34, 0)
	row.text:SetPoint("RIGHT", row, "RIGHT", -60, 0)
	row.right = Text(row, "body", 11, "textDim")
	row.right:SetPoint("RIGHT", row, "RIGHT", -10, 0)
	row.right:SetJustifyH("RIGHT")
	row.tpl = Theme:Badge(row, "TPL", "tpl")
	row.tpl:SetPoint("RIGHT", row, "RIGHT", -54, 0)
	row.star = Theme:GlyphButton(row, "star", 12, 22)
	row.star:SetPoint("RIGHT", row, "RIGHT", -30, 0)
	row.load = Theme:GlyphButton(row, "arrowRight", 10, 22)
	row.load:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", RowClick)
	row:SetScript("OnEnter", RowEnter)
	row:SetScript("OnLeave", RowLeave)
	-- The row's buttons keep its hover icons up while the mouse is on them.
	row.star:SetScript("OnEnter", function()
		local r = this:GetParent()
		ShowHover(r, true)
		Theme:Tint(this.glyph, "gold")
		Theme:ShowTip(this, "TOP", r.favorite and "Remove from Favorites" or "Add to Favorites")
	end)
	row.star:SetScript("OnLeave", function()
		local r = this:GetParent()
		ShowHover(r, false)
		Theme:Tint(this.glyph, (r.favorite or r.suggested) and "gold" or "textDim")
		Theme:HideTip(this)
	end)
	row.star:SetScript("OnClick", function()
		local r = this:GetParent()
		AegisPathfinder:ToggleFavoriteGuide(r.guide)
		Refresh()
	end)
	row.load:SetScript("OnEnter", function()
		ShowHover(this:GetParent(), true)
		Theme:Tint(this.glyph, "accent")
		Theme:ShowTip(this, "TOP", "Open in a new tab")
	end)
	row.load:SetScript("OnLeave", function()
		ShowHover(this:GetParent(), false)
		Theme:Tint(this.glyph, "textDim")
		Theme:HideTip(this)
	end)
	row.load:SetScript("OnClick", function() PickGuide(this:GetParent().guide) end)
	return row
end

ui.rows = {}
for i = 1, MAX_ROWS do ui.rows[i] = NewRow(i) end

ui.empty = Text(list, "body", 13, "textDim")
ui.empty:SetPoint("TOPLEFT", list, "TOPLEFT", 16, -16)
ui.empty:SetPoint("RIGHT", list, "RIGHT", -16, 0)

local slider = Theme:ScrollBar(content, 8)
slider:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -BAR_H - 12)
slider:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -4, 12)
slider:SetMinMaxValues(0, 0)
slider:SetValueStep(1)
slider:SetScript("OnValueChanged", function()
	if slider.updating then return end
	view.offset = math.floor(arg1 or 0)
	ui.PaintRows()
end)
frame.slider, ui.slider = slider, slider

local function VisibleRows()
	return math.max(1, math.min(MAX_ROWS, math.floor((frame:GetHeight() - HEADER_H - BAR_H - 10) / ROW_H)))
end

frame:EnableMouseWheel(true)
frame:SetScript("OnMouseWheel", function()
	if not ui.list:IsShown() then return end
	local most = math.max(0, table.getn(entries) - VisibleRows())
	local v = math.max(0, math.min(most, view.offset - (arg1 or 0) * 3))
	if v ~= view.offset then
		view.offset = v
		ui.PaintRows()
	end
end)

--[[ What a row says ---------------------------------------------------------- ]]

-- How many guides a folder holds, its folders' included.
local function CountGuides(folder)
	local n = 0
	for _, item in ipairs(folder.items) do
		if item.guide then n = n + 1 else n = n + CountGuides(item.folder) end
	end
	return n
end

local function PaintGuideRow(row, e, level, opts)
	local self = AegisPathfinder
	local name = e.guide
	row.guide = name
	row.favorite = self:IsFavoriteGuide(name)
	row.suggested = opts.suggested and opts.suggested[name] or false
	row.text:SetText(Browser.Title(name))
	local done = ((self.db.char.completion or {})[name] or 0) >= 1
	local diff = Char().browsercolour and self:GuideDifficulty(name, level)
	if done and Char().browserticks then
		Theme:TextColor(row.text, "textDim")
	elseif diff then
		Theme:TextColor(row.text, Theme.LEVEL_COLORS[diff])
	else
		Theme:TextColor(row.text, "text")
	end
	if e.badge then
		local kind, text = self:GuideBadge(name)
		row.badge:SetKind(kind, text)
		row.badge:Show()
		row.mark:Hide()
	else
		row.badge:Hide()
		if done and Char().browserticks then
			row.mark:SetTexture(Theme.glyph.tick)
			Theme:Tint(row.mark, "accent")
		else
			row.mark:SetTexture(Theme.texture.circleBorder)
			Theme:Tint(row.mark, "subtle")
		end
		row.mark:Show()
	end
	local right = e.why
	if not right and Char().isbranching and Char().branchsavedguide == name then right = "Your route" end
	if not right then
		local p = self:GuideProgress(name)
		if p > 0 and p < 1 then right = math.floor(p * 100) .. "%" end
	end
	row.right:SetText(right or "")
	if self:IsTemplateGuide(name) then row.tpl:Show() else row.tpl:Hide() end
	Theme:Tint(row.star.glyph, (row.favorite or row.suggested) and "gold" or "textDim")
end

local function PaintRow(row, e, level, opts)
	row.guide, row.folder, row.favorite, row.suggested = nil, nil, nil, nil
	row.badge:Hide()
	row.mark:Hide()
	row.tpl:Hide()
	row.right:SetText("")
	if not e then
		row:Hide()
		return
	end
	row:Show()
	if e.guide then
		PaintGuideRow(row, e, level, opts)
		row:Enable()
	elseif e.folder then
		row.folder = e.folder.title
		row.mark:SetTexture(Theme.glyph.folder)
		Theme:Tint(row.mark, "goldDeep")
		row.mark:Show()
		row.text:SetText(e.folder.title)
		Theme:TextColor(row.text, "text")
		row.right:SetText(tostring(CountGuides(e.folder)))
		row:Enable()
	elseif e.header then
		row.text:SetText(string.upper(e.header))
		Theme:TextColor(row.text, "accent")
		row:Disable()
	else
		-- A line of information: the level tracker's page.
		row.text:SetText(e.info)
		Theme:TextColor(row.text, e.current and "accent" or "text")
		row.right:SetText(e.right or "")
		row:Disable()
	end
	ShowHover(row, false)
end

--- Draw the list's rows from where it is scrolled to.
function ui.PaintRows()
	local shown = VisibleRows()
	local most = math.max(0, table.getn(entries) - shown)
	if view.offset > most then view.offset = most end
	if view.offset < 0 then view.offset = 0 end
	if most > 0 then
		slider.updating = true
		slider:SetMinMaxValues(0, most)
		slider:SetValue(view.offset)
		slider.updating = nil
		slider.step = 3
		slider:Show()
	else
		slider:Hide()
	end
	local level = UnitLevel("player")
	for i, row in ipairs(ui.rows) do
		PaintRow(row, i <= shown and entries[i + view.offset] or nil, level, ui.opts or {})
	end
	MarkSelection()
end

--[[ Home ------------------------------------------------------------------------ ]]

local home = CreateFrame("Frame", nil, content)
home:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
home:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
ui.home = home

local PANELS = {
	{ key = "history", title = "Guides history" },
	{ key = "suggested", title = "Suggested guides" },
	{ key = "levels", title = "Level tracker" },
	{ key = "gold", title = "Gold tracker" },
}

local function Card(def)
	local c = CreateFrame("Frame", nil, home)
	Theme:NineSlice(c, Theme.texture.panelFill, "BACKGROUND", "panel3")
	Theme:NineSlice(c, Theme.texture.panelBorder, "BORDER", "border")
	c.title = Text(c, "display", 15)
	c.title:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -12)
	c.title:SetText(def.title)
	c.key, c.rows = def.key, {}
	c.empty = Text(c, "body", 12, "textDim")
	c.empty:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -40)
	c.empty:SetPoint("RIGHT", c, "RIGHT", -14, 0)
	return c
end

-- A guide on a Home panel: its badge, its name and, for a suggestion, why.
local function CardGuideRow(c, i, h)
	local b = CreateFrame("Button", nil, c)
	b:SetHeight(h)
	b:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -36 - (i - 1) * h)
	b:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -36 - (i - 1) * h)
	Fill(b, "HIGHLIGHT", "text", 0.05)
	b.badge = Theme:Badge(b, "XP", "xp")
	b.badge:SetPoint("LEFT", b, "LEFT", 8, 0)
	b.text = Text(b, "body", 13)
	b.text:SetPoint("LEFT", b, "LEFT", 40, h > 28 and 7 or 0)
	b.text:SetPoint("RIGHT", b, "RIGHT", -26, h > 28 and 7 or 0)
	b.why = Text(b, "body", 11, "textDim")
	b.why:SetPoint("TOPLEFT", b.text, "BOTTOMLEFT", 0, -2)
	b.arrow = Glyph(b, "chevronRight", 10)
	b.arrow:SetPoint("RIGHT", b, "RIGHT", -8, 0)
	Theme:Tint(b.arrow, "textDim")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function() PickGuide(this.guide) end)
	b:SetScript("OnEnter", function()
		Theme:ShowTip(this, "RIGHT", this.guide, { "Click: Open in a new tab" })
	end)
	b:SetScript("OnLeave", function() Theme:HideTip(this) end)
	return b
end

-- Two texts on one line, the right one right-aligned: a level and its time.
local function CardLine(c, y)
	local l = Text(c, "body", 13)
	l:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
	local r = Text(c, "body", 13)
	r:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, y)
	r:SetJustifyH("RIGHT")
	return { l, r }
end

ui.cards = {}
for _, def in ipairs(PANELS) do ui.cards[def.key] = Card(def) end
for i = 1, 5 do
	ui.cards.history.rows[i] = CardGuideRow(ui.cards.history, i, 26)
	ui.cards.suggested.rows[i] = CardGuideRow(ui.cards.suggested, i, 34)
	ui.cards.levels.rows[i] = CardLine(ui.cards.levels, -38 - (i - 1) * 22)
end
ui.cards.gold.rows[1] = CardLine(ui.cards.gold, -44)
ui.cards.gold.rows[2] = CardLine(ui.cards.gold, -72)
ui.cards.gold.rows[1][1]:SetText("Today's earnings")
ui.cards.gold.rows[2][1]:SetText("This week")
do
	local more = CreateFrame("Button", nil, ui.cards.levels)
	more:SetHeight(20)
	more:SetWidth(90)
	more:SetPoint("BOTTOMLEFT", ui.cards.levels, "BOTTOMLEFT", 10, 10)
	more.label = Text(more, "body2", 12, "accentGlow")
	more.label:SetPoint("LEFT", more, "LEFT", 4, 0)
	more.label:SetText("See more")
	more.arrow = Glyph(more, "chevronRight", 9)
	more.arrow:SetPoint("LEFT", more.label, "RIGHT", 4, 0)
	Theme:Tint(more.arrow, "accentGlow")
	more:SetScript("OnClick", function()
		view.page, view.offset = "levels", 0
		HideOptions()
		Refresh()
	end)
	more:SetScript("OnEnter", function() Theme:TextColor(this.label, "text") end)
	more:SetScript("OnLeave", function() Theme:TextColor(this.label, "accentGlow") end)
	ui.cards.levels.more = more
end

-- Where each shown panel goes: two across, two down, in PANELS' order.
local CORNERS = {
	{ "TOPLEFT", "TOPLEFT", 12, -12, "BOTTOMRIGHT", "CENTER", -6, 6 },
	{ "TOPLEFT", "TOP", 6, -12, "BOTTOMRIGHT", "RIGHT", -12, 6 },
	{ "TOPLEFT", "LEFT", 12, -6, "BOTTOMRIGHT", "BOTTOM", -6, 12 },
	{ "TOPLEFT", "CENTER", 6, -6, "BOTTOMRIGHT", "BOTTOMRIGHT", -12, 12 },
}

local function PlaceCards()
	local hidden, n = Char().browserpanels or {}, 0
	for _, def in ipairs(PANELS) do
		local c = ui.cards[def.key]
		if hidden[def.key] then
			c:Hide()
		else
			n = n + 1
			local at = CORNERS[n]
			c:ClearAllPoints()
			c:SetPoint(at[1], home, at[2], at[3], at[4])
			c:SetPoint(at[5], home, at[6], at[7], at[8])
			c:Show()
		end
	end
	ui.homeEmpty = n == 0
end

local function CoinText(copper)
	local out = {}
	for _, part in ipairs(Browser.Coins(copper)) do
		table.insert(out, Code(Theme.COIN_COLORS[part[2]]) .. part[1] .. part[2] .. "|r")
	end
	return table.concat(out, " ")
end

local function PaintGuideCard(c, list, empty)
	for i, b in ipairs(c.rows) do
		local s = list[i]
		if s then
			b.guide = s.guide
			local kind, text = AegisPathfinder:GuideBadge(s.guide)
			b.badge:SetKind(kind, text)
			b.text:SetText(Browser.Title(s.guide))
			b.why:SetText(s.why or "")
			b:Show()
		else
			b.guide = nil
			b:Hide()
		end
	end
	c.empty:SetText(empty)
	if list[1] then c.empty:Hide() else c.empty:Show() end
end

local function PaintHome()
	local self = AegisPathfinder
	PlaceCards()
	local recent = {}
	for _, g in ipairs(self:RecentGuides(5)) do table.insert(recent, { guide = g }) end
	PaintGuideCard(ui.cards.history, recent, "The guides you open show here.")
	PaintGuideCard(ui.cards.suggested, self:BrowserSuggestions(),
		"Nothing new at your level just now: the categories have every guide.")
	local times = self:LevelTimes()
	for i, line in ipairs(ui.cards.levels.rows) do
		local t = times[i]
		if t then
			line[1]:SetText("Level " .. t.level)
			line[2]:SetText(Browser.Duration(t.seconds) .. (t.current and " so far" or ""))
			Theme:TextColor(line[2], t.current and "accent" or "textDim")
		else
			line[1]:SetText("")
			line[2]:SetText("")
		end
	end
	ui.cards.levels.empty:SetText("Counted from now on, while you play.")
	if times[1] then ui.cards.levels.empty:Hide() else ui.cards.levels.empty:Show() end
	local today, week = self:GoldEarned()
	ui.cards.gold.rows[1][2]:SetText(CoinText(today))
	ui.cards.gold.rows[2][2]:SetText(CoinText(week))
	ui.cards.gold.empty:Hide()
end

--[[ The right pane: the guide you point at ------------------------------------- ]]

local pane = CreateFrame("Frame", nil, frame)
pane:SetWidth(PANE_W)
pane:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -HEADER_H - 1)
pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
Theme:CapStrip(pane, "panel3", "bottom")
local paneEdge = pane:CreateTexture(nil, "BORDER")
paneEdge:SetTexture(Theme.texture.solid)
paneEdge:SetWidth(1)
paneEdge:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
paneEdge:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
Theme:Tint(paneEdge, "border")
ui.pane = pane

ui.picture = AegisPathfinder.Pictures:Create(pane, PIC_W, PIC_H)
ui.picture:SetPoint("TOP", pane, "TOP", 0, -14)
ui.name = Text(pane, "display", 17)
ui.name:SetPoint("TOPLEFT", ui.picture, "BOTTOMLEFT", 0, -10)
ui.name:SetWidth(PIC_W)
ui.kind = Text(pane, "body", 12, "textDim")
ui.kind:SetPoint("TOPLEFT", ui.name, "BOTTOMLEFT", 0, -4)
ui.kind:SetWidth(PIC_W)
ui.needs = Text(pane, "body", 12)
ui.needs:SetPoint("TOPLEFT", ui.kind, "BOTTOMLEFT", 0, -2)
ui.progress = Theme:ProgressBar(pane, 6)
ui.progress:SetPoint("TOPLEFT", ui.needs, "BOTTOMLEFT", 0, -12)
ui.progress:SetWidth(PIC_W - 44)
ui.pct = Text(pane, "body", 11, "textDim")
ui.pct:SetPoint("LEFT", ui.progress, "RIGHT", 8, 0)
ui.open = Theme:PanelButton(pane, "Open in a new tab", PIC_W, 26)
ui.open:SetPoint("TOPLEFT", ui.progress, "BOTTOMLEFT", 0, -16)
ui.open:SetScript("OnClick", function() PickGuide(view.selected) end)
ui.paneHint = Theme:FinePrint(pane, PIC_W)
ui.paneHint:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 14, 14)
ui.paneHint:SetText("In the list: click a guide to open it in a new tab, shift-click to reset its progress. The guide you are on keeps its tab.")

local KINDS = {
	optimized = "Optimized route", rxp = "RestedXP route", rxp_hc = "RestedXP Hardcore route",
	zone = "Zone guide", turtle = "Custom zone", dungeon = "Dungeon guide",
	class = "Class quest", profession = "Profession",
}

-- "Levels 20-21", "Level 10", "Skill 1-300".
local function Needs(name, cat)
	local lo, hi = AegisPathfinder:ParseGuideLevelRange(name)
	if not lo then return "" end
	if cat == "profession" then return string.format("Skill %d-%d", lo, hi) end
	if lo == hi then return "Level " .. lo end
	return string.format("Levels %d-%d", lo, hi)
end

PaintPane = function()
	local self = AegisPathfinder
	local name = view.selected
	if name and not self.guides[name] then name = nil end
	ui.picture:SetGuide(name)
	if not name then
		ui.name:SetText("Pick a guide")
		ui.kind:SetText("Point at one in the list to see it here.")
		ui.needs:SetText("")
		ui.progress:Hide(); ui.pct:Hide(); ui.open:Hide()
		return
	end
	local cat = self:GetGuideCategory(name)
	ui.name:SetText(Browser.Title(name))
	ui.kind:SetText(KINDS[cat] or "Guide")
	ui.needs:SetText(Needs(name, cat))
	local diff = self:GuideDifficulty(name, UnitLevel("player"))
	Theme:TextColor(ui.needs, diff and Theme.LEVEL_COLORS[diff] or "text")
	local p = self:GuideProgress(name)
	ui.progress:SetValue(p)
	ui.pct:SetText(math.floor(p * 100) .. "%")
	ui.progress:Show(); ui.pct:Show(); ui.open:Show()
end

--[[ The list's ⋮: its four switches, or on Home which panels show -------------- ]]

local OPTIONS_W = 320
local options = CreateFrame("Frame", nil, frame)
options:SetWidth(OPTIONS_W)
options:SetPoint("TOPRIGHT", ui.dots, "BOTTOMRIGHT", 0, -2)
options:SetFrameLevel(frame:GetFrameLevel() + 30)
Theme:Panel(options, "panel2", false)
options:EnableMouse(true)
options:Hide()
ui.options = options

local LIST_SWITCHES = {
	{ "browsercolour", "Colour guides by difficulty" },
	{ "browserticks", "Tick finished guides" },
	{ "browserhidedone", "Hide finished and outleveled guides" },
	{ "browserstars", "Star suggested guides" },
}

-- A switch in the menu, under the one before it in its set: a label that
-- wraps makes its row taller, and the next goes below it.
local function OptionSwitch(prev, label, onChange)
	local s = Theme:Switch(options, label, onChange)
	if prev then
		s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
	else
		s:SetPoint("TOPLEFT", options, "TOPLEFT", 12, -10)
	end
	s.h = s:Fit(OPTIONS_W - 24)
	return s
end

ui.listSwitches, ui.panelSwitches = {}, {}
for i, def in ipairs(LIST_SWITCHES) do
	local key = def[1]
	ui.listSwitches[i] = OptionSwitch(ui.listSwitches[i - 1], def[2], function(on)
		Char()[key] = on
		Refresh()
	end)
	ui.listSwitches[i].key = key
end
for i, def in ipairs(PANELS) do
	local key = def.key
	ui.panelSwitches[i] = OptionSwitch(ui.panelSwitches[i - 1], "Show " .. string.lower(def.title), function(on)
		local hidden = Char().browserpanels or {}
		Char().browserpanels = hidden
		hidden[key] = not on or nil
		Refresh()
	end)
	ui.panelSwitches[i].key = key
end

-- As tall as the set it shows.
local function OptionsHeight(set)
	local h = 14
	for _, s in ipairs(set) do h = h + s.h + 6 end
	return h
end

local function PaintOptions(homeMenu)
	local hidden = Char().browserpanels or {}
	ui.options:SetHeight(OptionsHeight(homeMenu and ui.panelSwitches or ui.listSwitches))
	for _, s in ipairs(ui.listSwitches) do
		s:SetOn(Char()[s.key])
		if homeMenu then s:Hide() else s:Show() end
	end
	for _, s in ipairs(ui.panelSwitches) do
		s:SetOn(not hidden[s.key])
		if homeMenu then s:Show() else s:Hide() end
	end
end

--[[ Building the view ------------------------------------------------------------ ]]

local function Label(key)
	for _, c in ipairs(Browser.CATEGORIES) do
		if c.key == key then return c.label end
	end
	return key or ""
end

-- The folder `view.path` names in category `key`; any of the path no
-- longer there is dropped.
local function OpenFolder(key)
	local folder = AegisPathfinder:BrowserCategory(key)
	-- The folders above the one open: it is the title, not a crumb.
	local crumbs = {}
	for i, title in ipairs(view.path) do
		local found
		for _, item in ipairs(folder.items) do
			if item.folder and item.folder.title == title then found = item.folder end
		end
		if not found then
			for n = table.getn(view.path), i, -1 do table.remove(view.path, n) end
			break
		end
		table.insert(crumbs, folder.title)
		folder = found
	end
	if not crumbs[1] then crumbs = { "Guides" } end
	return folder, table.concat(crumbs, SEP)
end

local function GuideEntries(list, opts)
	local out, level, hide = {}, UnitLevel("player"), Char().browserhidedone
	for _, item in ipairs(list) do
		-- A folder's items are tables; a search's, guide names.
		local g = type(item) == "table" and item.guide or item
		if type(item) == "table" and item.folder then
			table.insert(out, item)
		elseif not (hide and AegisPathfinder:IsGuideDoneWith(g, level)) then
			table.insert(out, { guide = g, badge = opts.badge, why = type(item) == "table" and item.why or nil })
		end
	end
	return out
end

-- The rows for what is open now, the bar's crumb and title, whether there is
-- a way back, and what to say when there are no rows.
local function Build()
	local self = AegisPathfinder
	if view.search ~= "" then
		return GuideEntries(self:BrowserSearch(view.search), { badge = true }), "Search",
			'"' .. view.search .. '"', true, "No guide's name has that in it."
	end
	if view.page == "levels" then
		local out = {}
		for _, t in ipairs(self:LevelTimes()) do
			table.insert(out, { info = "Level " .. t.level, current = t.current,
				right = Browser.Duration(t.seconds) .. (t.current and " so far" or "") })
		end
		return out, "Home", "Time at each level", true,
			"Nothing counted yet: time is counted from now on, while you play."
	end
	if view.tab == "current" then
		local out = {}
		for i, tab in ipairs(self:EnsureTabs()) do
			if tab.guide and self.guides[tab.guide] then
				table.insert(out, { guide = tab.guide, badge = true, why = i == 1 and "Your route" or "Beside the route" })
			end
		end
		return out, "Open in the guide window", "Current", false, "No guide is open."
	end
	if view.tab == "recent" then
		local out, by = {}, {}
		for _, g in ipairs(self:RecentGuides(Browser.RECENT_MAX)) do
			local cat = self:BrowserCategoryOf(g)
			by[cat] = by[cat] or {}
			table.insert(by[cat], g)
		end
		for _, c in ipairs(Browser.CATEGORIES) do
			if by[c.key] then
				table.insert(out, { header = c.label })
				for _, g in ipairs(by[c.key]) do table.insert(out, { guide = g, badge = true }) end
			end
		end
		return out, "The guides you opened lately", "Recent", false, "The guides you open show here."
	end
	if view.category then
		local folder, crumb = OpenFolder(view.category)
		local empty = view.category == "favorites" and "Star a guide to keep it here: point at it in a list and click its star."
			or "No guides here."
		return GuideEntries(folder.items, { badge = view.category == "favorites" }), crumb, folder.title,
			table.getn(view.path) > 0, empty
	end
	return {}, string.format("Level %d %s", UnitLevel("player") or 1, UnitClass("player") or ""), "Home", false, ""
end

local function PaintHeader()
	local db = Char()
	local noTab = view.search ~= "" or view.page
	for _, b in ipairs(ui.tabs) do b:SetActive(not noTab and b.key == view.tab) end
	for _, b in ipairs(ui.categories) do
		local on = not noTab and view.tab == nil and b.key == view.category
		if on then b.fill:Show(); b.bar:Show() else b.fill:Hide(); b.bar:Hide() end
	end
	if db.isbranching then frame.returnBtn:Show() else frame.returnBtn:Hide() end
end

--- Lay the middle out with or without the right pane beside it.
local function ShowPane(on)
	ui.content:ClearAllPoints()
	ui.content:SetPoint("TOPLEFT", ui.side, "TOPRIGHT", 0, 0)
	ui.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1 - (on and PANE_W or 0), 1)
	if on then ui.pane:Show() else ui.pane:Hide() end
end

function AegisPathfinder:UpdateGuideListPanel()
	if not frame:IsVisible() then return end
	PaintHeader()
	local rows, crumb, title, back, empty = Build()
	entries = rows
	ui.crumb:SetText(crumb)
	ui.title:SetText(title)
	ui.crumb:ClearAllPoints()
	ui.crumb:SetPoint("TOPLEFT", bar, "TOPLEFT", back and 40 or 16, -9)
	if back then ui.back:Show() else ui.back:Hide() end
	local homeView = view.tab == "home" and view.search == "" and not view.page
	PaintOptions(homeView)
	if homeView then
		ui.list:Hide()
		ui.slider:Hide()
		ShowPane(false)
		ui.home:Show()
		PaintHome()
		return
	end
	ui.home:Hide()
	ui.list:Show()
	ShowPane(view.page == nil)
	-- The stars, worked out once rather than for every row.
	local opts = {}
	if Char().browserstars then
		opts.suggested = {}
		for _, s in ipairs(self:BrowserSuggestions()) do opts.suggested[s.guide] = true end
	end
	ui.opts = opts
	ui.empty:SetText(empty)
	if rows[1] then ui.empty:Hide() else ui.empty:Show() end
	ui.PaintRows()
	PaintPane()
end

--[[ Size --------------------------------------------------------------------------- ]]

--- Size the browser `w` by `h`, kept to what fits its layout; `save` keeps
--- it for next time. Nil sizes are the ones saved, or the default.
function AegisPathfinder:SizeGuideBrowser(w, h, save)
	local profile = self.db and self.db.profile or {}
	w = math.max(MIN_W, math.min(MAX_W, math.floor(tonumber(w) or profile.guidelistwidth or DEFAULT_W)))
	h = math.max(MIN_H, math.min(MAX_H, math.floor(tonumber(h) or profile.guidelistheight or DEFAULT_H)))
	frame:SetWidth(w)
	frame:SetHeight(h)
	if save then profile.guidelistwidth, profile.guidelistheight = w, h end
	if frame:IsVisible() and ui.list:IsShown() then ui.PaintRows() end
	return w, h
end

-- Resize grip, bottom right: sized by hand rather than with StartSizing,
-- which re-anchors the window as it sees fit (ObjectivesFrame.lua).
do
	local grip = CreateFrame("Frame", nil, frame)
	grip:SetWidth(12)
	grip:SetHeight(12)
	grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	grip:EnableMouse(true)
	grip:SetFrameLevel(frame:GetFrameLevel() + 6)
	local tex = grip:CreateTexture(nil, "OVERLAY")
	tex:SetTexture(Theme.texture.grip)
	tex:SetAllPoints(grip)
	Theme:Tint(tex, "textDim", 0.55)
	local function cursor()
		local scale = frame:GetEffectiveScale()
		local x, y = GetCursorPosition()
		return x / scale, y / scale
	end
	local function stop()
		grip.sizing = nil
		grip:SetScript("OnUpdate", nil)
		Theme:Tint(tex, "textDim", 0.55)
	end
	local function sizing()
		local s = grip.sizing
		if not s then return end
		if s.poll and not IsMouseButtonDown("LeftButton") then return stop() end
		local x, y = cursor()
		AegisPathfinder:SizeGuideBrowser(s.w + x - s.x, s.h + s.y - y, true)
	end
	grip:SetScript("OnMouseDown", function()
		Theme:Tint(tex, "accentGlow", 1)
		Theme:AnchorTopLeft(frame)
		local x, y = cursor()
		grip.sizing = { x = x, y = y, w = frame:GetWidth(), h = frame:GetHeight(),
			poll = IsMouseButtonDown and IsMouseButtonDown("LeftButton") and true or false }
		grip:SetScript("OnUpdate", sizing)
	end)
	grip:SetScript("OnMouseUp", function()
		sizing()
		stop()
		-- Grown from its top left: keep it there next time it opens.
		Theme:PositionSaver("guidelistframe")(frame)
	end)
	grip:SetScript("OnEnter", function()
		Theme:Tint(tex, "accent", 1)
		Theme:ShowTip(this, "LEFT", "Drag to resize")
	end)
	grip:SetScript("OnLeave", function()
		if not grip.sizing then Theme:Tint(tex, "textDim", 0.55) end
		Theme:HideTip(this)
	end)
	frame.grip = grip
end

--[[ Opening and closing ------------------------------------------------------------ ]]

frame:SetScript("OnShow", function()
	local self = AegisPathfinder
	self:SizeGuideBrowser()
	-- Snap beside the guide only while the player has not dragged frame
	-- window somewhere of their own; reopening must not undo a move.
	if not Theme:RestorePosition(frame, "guidelistframe") then
		local quad, vhalf, hhalf = self.GetQuadrant(self.objectiveframe)
		frame:ClearAllPoints()
		frame:SetPoint(quad, self.objectiveframe, (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf)
	end
	if not view.opened then
		-- Where it was left, from one session to the next: a tab, or a
		-- category's key.
		view.opened = true
		local where = self.db.char.browsertab
		view.tab, view.category = "home", nil
		if where == "current" or where == "recent" then
			view.tab = where
		else
			for _, c in ipairs(Browser.CATEGORIES) do
				if c.key == where and not c.soon then view.tab, view.category = nil, where end
			end
		end
	end
	self:UpdateGuideListPanel()
	frame.fadeTo = self.db and self.db.profile.browseropacity or 1
	Theme:FadeIn(frame, 0.7)
end)
frame:SetScript("OnHide", function()
	HideOptions()
	Theme:HideTip()
end)

table.insert(UISpecialFrames, "AegisPathfinderGuideList")

--- Open the guide browser. `atLevel` opens it on Home, whose Suggested
--- guides panel is what fits your level now (the old list's level filter).
function AegisPathfinder:ShowGuideList(atLevel)
	if atLevel then
		view.opened = true
		view.tab, view.category, view.path, view.page = "home", nil, {}, nil
		self.db.char.browsertab = "home"
	end
	self.guidelistframe:Show()
end

AegisPathfinder.browserview = view
AegisPathfinder.browserui = ui

--- The guide browser's opacity, from the Appearance page: 40% to 100%, the
--- whole window. Applied now if it is open, and as it fades in next time.
function AegisPathfinder:SetBrowserOpacity(v)
	v = math.max(0.4, math.min(1, v or 1))
	self.db.profile.browseropacity = v
	frame.fadeTo = v
	if frame:IsShown() and not frame:GetScript("OnUpdate") then frame:SetAlpha(v) end
	return v
end
