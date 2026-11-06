--[[ TalentWindow.lua -- the Talent Advisor, on Blizzard's talent window.

	Laid over the client's own window (Blizzard_TalentUI, loaded when it is
	first opened), and over pfUI's skin of it:

	  * a strip above the window: the build followed, as a menu to pick
	    another, and a card for the next point -- the talent's icon, "Take
	    Shield Slam", its rank and tree and the points to spend -- with how
	    many points are off the build under it, or why the build is not
	    followed;
	  * on each talent of the tree shown, a badge with the points the build
	    puts there: green while some are still to take, a tick once you have
	    them all, amber "+N" for points the build does not put there;
	  * a gold ring and "NEXT" over the talent the next point goes to, and its
	    tree's tab lit gold. The window opens on that tree;
	  * a line on the talent's tooltip.

	And off the window, so a point is not missed: a card when you level up
	-- "Level 30: a talent point. Take Shield Slam" with Open talents and
	Later -- and the talents button lit, with the points to spend on it.

	It only marks; the points are yours to spend. What it shows is
	TalentAdvisor.lua's; this is the drawing of it. TalentModern.lua puts the
	same marks on Modern Spellbook's talent window.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme
local TA = AegisPathfinder.TalentAdvisor

local TW = {}
TA.Window = TW

-- Layout, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local G = {
	-- The menu has a row of its own: beside Following the window is too
	-- narrow for the builds' names.
	PAD = 10, ROW1 = -9, DROP = -24, CARD_TOP = -60, CARD_H = 44, ICON = 36,
	NOTE_H = 18, WARN_H = 18, BOTTOM = 8,
	-- Where the strip sits on the client's window art: over its frame's top
	-- edge, as wide as the frame. pfUI's backdrop is the frame there.
	ART_LEFT = 12, ART_RIGHT = -34, ART_TOP = -10,
	-- NEXT sits clear of the badge at the talent's top right.
	BADGE_H = 16, GLOW = 72, NEXT_W = 40, NEXT_H = 14, NEXT_LIFT = 10, DOT = 8, TICK = 10,
	-- The mock-up's colours: the gold of "next", the amber of "+N", the grey
	-- of a talent done, and the dark text on them.
	GOLD = { 1, 0.82, 0 }, CARD = { 0.18, 0.16, 0.11 }, CARD_TEXT = { 0.91, 0.89, 0.78 },
	AMBER = { 0.94, 0.71, 0.24 }, ON_AMBER = { 0.10, 0.07, 0.02 }, ON_ACCENT = { 0.04, 0.04, 0.04 },
	DONE = { 0.35, 0.35, 0.35 },
	TOAST_W = 340, TOAST_SHOWS = 30, MICRO_GLOW = 2.4,
}
TW.G = G

local BADGE_GEOM = { corner = 8 }

--[[ The strip ---------------------------------------------------------------- ]]

local function Text(parent, role, size, color)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(fs, role, size)
	fs:SetJustifyH("LEFT")
	Theme:TextColor(fs, color)
	return fs
end

--- The card for the next point: the talent's icon in a gold edge, its title
--- in gold and a line under it. Used on this window and Modern Spellbook's.
function TW:Card(parent, iconSize)
	iconSize = iconSize or G.ICON
	local card = CreateFrame("Frame", nil, parent)
	local bg = card:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(Theme.texture.solid)
	bg:SetAllPoints(card)
	bg:SetVertexColor(G.CARD[1], G.CARD[2], G.CARD[3], 0.95)
	local edge = card:CreateTexture(nil, "BORDER")
	edge:SetTexture(Theme.texture.solid)
	edge:SetWidth(iconSize + 4); edge:SetHeight(iconSize + 4)
	edge:SetPoint("LEFT", card, "LEFT", 4, 0)
	edge:SetVertexColor(G.GOLD[1], G.GOLD[2], G.GOLD[3])
	local icon = card:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(iconSize); icon:SetHeight(iconSize)
	icon:SetPoint("CENTER", edge, "CENTER", 0, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local title = Text(card, "body", 14, G.GOLD)
	title:SetPoint("BOTTOMLEFT", edge, "RIGHT", 10, 1)
	title:SetPoint("RIGHT", card, "RIGHT", -8, 0)
	local detail = Text(card, "body", 12, G.CARD_TEXT)
	detail:SetPoint("TOPLEFT", edge, "RIGHT", 10, -2)
	detail:SetPoint("RIGHT", card, "RIGHT", -8, 0)
	card.icon, card.title, card.detail = icon, title, detail
	return card
end

--- Fill a card from TA:NextCard; hidden when there is none.
function TW:FillCard(card, title, detail, icon)
	if not title then
		card:Hide()
		return false
	end
	card.title:SetText(title)
	card.detail:SetText(detail or "")
	card.icon:SetTexture(icon)
	card:Show()
	return true
end

function TW:BuildStrip()
	local strip = CreateFrame("Frame", "AegisPathfinderTalentStrip", TalentFrame)
	strip:SetHeight(G.CARD_H - G.CARD_TOP + G.BOTTOM)
	strip:SetFrameLevel(TalentFrame:GetFrameLevel() + 6)
	strip:EnableMouse(true)
	Theme:CapStrip(strip, "panel2", "top")

	local brand = Text(strip, "display", 12, "accentGlow")
	brand:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, G.ROW1)
	brand:SetText("PATHFINDER")
	local following = Text(strip, "body", 12, "textDim")
	following:SetPoint("LEFT", brand, "RIGHT", 8, 0)
	following:SetText("Following")

	local drop = Theme:Dropdown(strip, 200, function(value) TW:Choose(value) end)
	drop:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, G.DROP)
	drop:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -G.PAD, G.DROP)

	local card = self:Card(strip)
	card:SetHeight(G.CARD_H)
	card:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, G.CARD_TOP)
	card:SetPoint("RIGHT", strip, "RIGHT", -G.PAD, 0)
	card:Hide()

	local note = Text(strip, "body", 12, "text")
	note:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, G.CARD_TOP)
	note:SetPoint("RIGHT", strip, "RIGHT", -G.PAD, 0)
	note:SetHeight(14)
	local warn = Text(strip, "body", 11, G.AMBER)
	warn:SetPoint("RIGHT", strip, "RIGHT", -G.PAD, 0)
	warn:SetHeight(14)

	strip.drop, strip.card, strip.note, strip.warn = drop, card, note, warn
	self.strip = strip
	strip:Hide()
	return strip
end

--- Over the window's frame, or pfUI's backdrop of it; the menu's list as
--- wide as the strip.
function TW:Place()
	local strip, bd = self.strip, TalentFrame.backdrop
	strip:ClearAllPoints()
	if bd then
		strip:SetPoint("BOTTOMLEFT", bd, "TOPLEFT", 0, 1)
		strip:SetPoint("BOTTOMRIGHT", bd, "TOPRIGHT", 0, 1)
	else
		strip:SetPoint("BOTTOMLEFT", TalentFrame, "TOPLEFT", G.ART_LEFT, G.ART_TOP)
		strip:SetPoint("BOTTOMRIGHT", TalentFrame, "TOPRIGHT", G.ART_RIGHT, G.ART_TOP)
	end
	local w = strip:GetWidth()
	if w and w > 0 then strip.drop.list:SetWidth(w - 2 * G.PAD) end
end

--- The card for the next point, or the line in its place; the warning
--- under either. Returns the strip's height.
function TW:PaintStrip(state)
	local strip = self.strip
	strip.drop:SetItems(TA:BuildItems(state))
	strip.drop:SetValue(state.choice or "auto")
	local line, warn = TA:StripLines(state)
	local y = G.CARD_TOP
	if self:FillCard(strip.card, TA:NextCard(state)) then
		strip.note:SetText("")
		y = y - G.CARD_H - 4
	else
		strip.note:SetText(line or "")
		if line then y = y - G.NOTE_H end
	end
	strip.warn:SetText(warn or "")
	strip.warn:ClearAllPoints()
	strip.warn:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, y)
	strip.warn:SetPoint("RIGHT", strip, "RIGHT", -G.PAD, 0)
	if warn then y = y - G.WARN_H end
	strip:SetHeight(G.BOTTOM - y)
	strip:Show()
end

--- A build picked from the strip's menu: the same setting as the options'.
function TW:Choose(value)
	local s = TA:Settings()
	if not s then return end
	s.talentbuild = value
	TA:Refresh()
	AegisPathfinder:RefreshConfigPanel()
end

--[[ The marks ---------------------------------------------------------------- ]]

--- A talent button's marks, made the first time: the badge at the top right
--- of `anchor` (the button, or the icon inside it), the gold ring and "NEXT"
--- over it. `glow` sizes the ring to the icon.
function TW:Marks(button, anchor, glowSize)
	if button.apMarks then return button.apMarks end
	anchor = anchor or button
	local m = CreateFrame("Frame", nil, button)
	m:SetAllPoints(button)
	m:SetFrameLevel(button:GetFrameLevel() + 5)

	local glow = m:CreateTexture(nil, "OVERLAY")
	glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	glow:SetBlendMode("ADD")
	glow:SetWidth(glowSize or G.GLOW); glow:SetHeight(glowSize or G.GLOW)
	glow:SetPoint("CENTER", anchor, "CENTER", 0, 0)
	glow:SetVertexColor(G.GOLD[1], G.GOLD[2], G.GOLD[3])

	local tag = CreateFrame("Frame", nil, m)
	tag:SetWidth(G.NEXT_W); tag:SetHeight(G.NEXT_H)
	tag:SetPoint("BOTTOM", anchor, "TOP", 0, G.NEXT_LIFT)
	Theme:Strip(tag, G.GOLD)
	local tagText = tag:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(tagText, "display", 10)
	tagText:SetPoint("CENTER", tag, "CENTER", 0, 0)
	tagText:SetTextColor(G.ON_ACCENT[1], G.ON_ACCENT[2], G.ON_ACCENT[3])
	tagText:SetText("NEXT")

	local badge = CreateFrame("Frame", nil, m)
	badge:SetHeight(G.BADGE_H)
	badge:SetPoint("CENTER", anchor, "TOPRIGHT", -1, -1)
	badge.fill = Theme:NineSlice(badge, Theme.texture.pillFill, "BACKGROUND", "accent", nil, BADGE_GEOM)
	badge.border = Theme:NineSlice(badge, Theme.texture.pillBorder, "BORDER", "accent", nil, BADGE_GEOM)
	badge.text = badge:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(badge.text, "display", 11)
	badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
	badge.tick = badge:CreateTexture(nil, "OVERLAY")
	badge.tick:SetTexture(Theme.glyph.tick)
	badge.tick:SetWidth(G.TICK); badge.tick:SetHeight(G.TICK)
	badge.tick:SetPoint("CENTER", badge, "CENTER", 0, 0)
	badge.tick:SetVertexColor(1, 1, 1)

	m.glow, m.tag, m.badge = glow, tag, badge
	button.apMarks = m
	return m
end

-- Each kind of badge: its fill, its edge, its text. Done shows a tick.
local BADGE = {
	todo = { "accent", "accent", G.ON_ACCENT },
	done = { G.DONE, G.DONE, { 1, 1, 1 } },
	off = { G.AMBER, G.AMBER, G.ON_AMBER },
}

function TW:PaintMark(button, state, name, anchor, glowSize)
	local m = self:Marks(button, anchor, glowSize)
	local kind, text, isNext
	if name and button:IsShown() then kind, text, isNext = TA.Mark(state, name) end
	local badge = m.badge
	if kind then
		local look = BADGE[kind]
		badge.fill:SetTint(look[1])
		badge.border:SetTint(look[2])
		Theme:TextColor(badge.text, look[3])
		badge.text:SetText(text)
		if kind == "done" then
			badge.text:Hide()
			badge.tick:Show()
			badge:SetWidth(G.BADGE_H)
		else
			badge.text:Show()
			badge.tick:Hide()
			badge:SetWidth(math.max(G.BADGE_H, badge.text:GetStringWidth() + 10))
		end
		badge:Show()
	else
		badge:Hide()
	end
	if isNext then m.glow:Show(); m.tag:Show() else m.glow:Hide(); m.tag:Hide() end
	m:Show()
end

--- The tab of the tree the next point goes to: a gold dot left of its name
--- and the tab lit gold.
function TW:PaintDot(tab, on)
	if not tab.apDot then
		local dot = tab:CreateTexture(nil, "OVERLAY")
		dot:SetTexture(Theme.texture.circleFill)
		dot:SetWidth(G.DOT); dot:SetHeight(G.DOT)
		local label = getglobal(tab:GetName() .. "Text")
		if label then dot:SetPoint("RIGHT", label, "LEFT", -3, 0) else dot:SetPoint("LEFT", tab, "LEFT", 6, 0) end
		dot:SetVertexColor(G.GOLD[1], G.GOLD[2], G.GOLD[3])
		tab.apDot = dot
		local lit = tab:CreateTexture(nil, "OVERLAY")
		lit:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
		lit:SetBlendMode("ADD")
		lit:SetPoint("TOPLEFT", tab, "TOPLEFT", 4, -2)
		lit:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 2)
		lit:SetVertexColor(G.GOLD[1], G.GOLD[2], G.GOLD[3])
		tab.apLit = lit
	end
	if on then tab.apDot:Show(); tab.apLit:Show() else tab.apDot:Hide(); tab.apLit:Hide() end
end

function TW:Clear()
	for i = 1, (MAX_NUM_TALENTS or 20) do
		local button = getglobal("TalentFrameTalent" .. i)
		if button and button.apMarks then button.apMarks:Hide() end
	end
	for i = 1, (MAX_TALENT_TABS or 5) do
		local tab = getglobal("TalentFrameTab" .. i)
		if tab and tab.apDot then tab.apDot:Hide(); tab.apLit:Hide() end
	end
end

--[[ Painting ----------------------------------------------------------------- ]]

--- The advisor's state while it is on and has a build for your class.
function TW.Current()
	local s = TA:Settings()
	if not (s and s.talentadvisor) then return nil end
	return TA:State()
end

--- Mark the window as it is now: after the client has drawn it.
function TW:Paint()
	if not (self.strip and TalentFrame and TalentFrame:IsShown()) then return end
	self:HideToast()
	local state = TW.Current()
	if not state then
		self.strip:Hide()
		return self:Clear()
	end
	self:Place()
	self:PaintStrip(state)
	if not state.fits then return self:Clear() end
	local tab = PanelTemplates_GetSelectedTab(TalentFrame) or 1
	local count = GetNumTalents(tab) or 0
	for i = 1, (MAX_NUM_TALENTS or 20) do
		local button = getglobal("TalentFrameTalent" .. i)
		if button then
			local name = i <= count and GetTalentInfo(tab, i) or nil
			self:PaintMark(button, state, name)
		end
	end
	local t = state.next and state.tree.talent[state.next]
	for i = 1, (MAX_TALENT_TABS or 5) do
		local tabButton = getglobal("TalentFrameTab" .. i)
		if tabButton then self:PaintDot(tabButton, t and t.tab == i) end
	end
end

--- Draw it all again, the client's part too, if the window is open; and the
--- talents button.
function TW:Repaint()
	if TalentFrame and TalentFrame:IsShown() and TalentFrame_Update then TalentFrame_Update() end
	self:PaintMicro()
end

--- Open on the tree the next point goes to.
function TW:ShowNextTree()
	local state = TW.Current()
	local t = state and state.fits and state.next and state.tree.talent[state.next]
	if t then PanelTemplates_SetTab(TalentFrame, t.tab) end
end

--- The talent's tooltip: the advisor's lines under the client's.
function TW:AddTip(tip, tab, index)
	local name = GetTalentInfo(tab, index)
	local state = name and TW.Current()
	if not (state and state.fits) then return end
	local lines = TA:TipLines(state, name)
	if table.getn(lines) == 0 then return end
	local c = Theme.color.accentGlow
	tip:AddLine(" ")
	for _, line in ipairs(lines) do tip:AddLine(line, c[1], c[2], c[3], 1) end
	tip:Show()
end

--[[ Off the window: the card on a level up, and the talents button ----------- ]]

--- The settings say to point out a point: on, with the advisor.
local function Nudging()
	local s = TA:Settings()
	return s and s.talentadvisor and s.talentnudge ~= false
end

function TW:BuildToast()
	local f = CreateFrame("Frame", "AegisPathfinderTalentToast", UIParent)
	f:SetWidth(G.TOAST_W); f:SetHeight(96)
	f:SetFrameStrata("DIALOG")
	f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -24, 150)
	f:EnableMouse(true)
	Theme:Panel(f, "panel", true)
	Theme:RegisterWindow(f)
	local edge = f:CreateTexture(nil, "BORDER")
	edge:SetTexture(Theme.texture.solid)
	edge:SetWidth(44); edge:SetHeight(44)
	edge:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
	edge:SetVertexColor(G.GOLD[1], G.GOLD[2], G.GOLD[3])
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(40); icon:SetHeight(40)
	icon:SetPoint("CENTER", edge, "CENTER", 0, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local title = Text(f, "display", 15, G.GOLD)
	title:SetPoint("TOPLEFT", edge, "TOPRIGHT", 10, 0)
	title:SetPoint("RIGHT", f, "RIGHT", -12, 0)
	local line = Text(f, "body", 13, G.CARD_TEXT)
	line:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	line:SetPoint("RIGHT", f, "RIGHT", -12, 0)
	local open = Theme:Pill(f, "Open talents", 110, 24)
	open:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -8)
	open:SetActive(true)
	open:SetScript("OnClick", function()
		TW:HideToast()
		TA:OpenWindow()
	end)
	local later = Theme:Pill(f, "Later", 70, 24)
	later:SetPoint("LEFT", open, "RIGHT", 6, 0)
	later:SetScript("OnClick", function() TW:HideToast() end)
	-- Gone by itself after a while.
	f:SetScript("OnUpdate", function()
		if GetTime() - (this.shownAt or 0) > G.TOAST_SHOWS then this:Hide() end
	end)
	f.icon, f.title, f.line, f.open, f.later = icon, title, line, open, later
	f:Hide()
	self.toast = f
	return f
end

--- On a level up with a point: "Level 30: a talent point", the talent to
--- take, Open talents and Later. Not while a talent window is open.
function TW:Toast(level, state)
	if not (Nudging() and state and state.next) then return end
	if (TalentFrame and TalentFrame:IsShown()) or (ModernTalentTreeFrame and ModernTalentTreeFrame:IsShown()) then
		return
	end
	local f = self.toast or self:BuildToast()
	local t = state.tree.talent[state.next]
	f.icon:SetTexture(t.icon)
	f.title:SetText("Level " .. level .. ": a talent point")
	f.line:SetText("Take " .. state.next .. " (rank " .. state.rank .. " of " .. t.max .. ") in "
		.. state.tree.tabs[t.tab].name .. ".")
	f.shownAt = GetTime()
	f:Show()
end

function TW:HideToast()
	if self.toast then self.toast:Hide() end
end

--- The talents button lit, with the points to spend on it, while you have
--- some and the advisor is on.
function TW:PaintMicro()
	local button = TalentMicroButton
	if not button then return end
	if not button.apGlow then
		local glow = button:CreateTexture(nil, "OVERLAY")
		glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		glow:SetBlendMode("ADD")
		glow:SetWidth(button:GetWidth() * G.MICRO_GLOW); glow:SetHeight(button:GetHeight() * 1.6)
		glow:SetPoint("CENTER", button, "CENTER", 0, -6)
		glow:SetVertexColor(G.GOLD[1], G.GOLD[2], G.GOLD[3])
		button.apGlow = glow
		local count = CreateFrame("Frame", nil, button)
		count:SetWidth(16); count:SetHeight(16)
		count:SetPoint("CENTER", button, "TOPRIGHT", -4, -6)
		count:SetFrameLevel(button:GetFrameLevel() + 3)
		count.fill = Theme:NineSlice(count, Theme.texture.pillFill, "BACKGROUND", G.GOLD, nil, BADGE_GEOM)
		count.text = count:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(count.text, "display", 10)
		count.text:SetPoint("CENTER", count, "CENTER", 0, 0)
		count.text:SetTextColor(G.ON_ACCENT[1], G.ON_ACCENT[2], G.ON_ACCENT[3])
		button.apCount = count
	end
	local points = (UnitCharacterPoints("player")) or 0
	if Nudging() and points > 0 and (UnitLevel("player") or 0) >= TA.FIRST_LEVEL then
		button.apCount.text:SetText(tostring(points))
		button.apGlow:Show()
		button.apCount:Show()
	else
		button.apGlow:Hide()
		button.apCount:Hide()
	end
end

--[[ Hooks -------------------------------------------------------------------- ]]

--[[ The client's window calls its functions by name -- on showing, on a tab
	clicked, on points spent -- so each is wrapped where it is kept. Once:
	when Blizzard_TalentUI has loaded. ]]
function TW:Hook()
	if self.hooked or not (TalentFrame and TalentFrame_Update) then return end
	self.hooked = true
	self:BuildStrip()
	local update, onShow = TalentFrame_Update, TalentFrame_OnShow
	TalentFrame_Update = function()
		update()
		TW:Paint()
	end
	TalentFrame_OnShow = function()
		TW:ShowNextTree()
		onShow()
	end
end

-- The tooltip is the client's own, for every talent; the line is added after.
local setTalent = GameTooltip.SetTalent
GameTooltip.SetTalent = function(tip, tab, index)
	setTalent(tip, tab, index)
	TW:AddTip(tip, tab, index)
end

local events = CreateFrame("Frame")
TW.events = events
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function()
	if arg1 == "Blizzard_TalentUI" then TW:Hook() end
end)
-- Another addon may have loaded it already.
if IsAddOnLoaded and IsAddOnLoaded("Blizzard_TalentUI") then TW:Hook() end

--- Open the talent window, as its key does: from level 10.
function TA:OpenWindow()
	if (UnitLevel("player") or 0) < TA.FIRST_LEVEL then
		return AegisPathfinder:Print("Talents come at level " .. TA.FIRST_LEVEL .. ".")
	end
	if ToggleTalentFrame then ToggleTalentFrame() end
end
