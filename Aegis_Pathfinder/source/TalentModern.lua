--[[ TalentModern.lua -- the Talent Advisor on Modern Spellbook's talent window.

	Modern Spellbook (github.com/lioryx/ModernSpellBook, by lioryx) opens its
	own talent window in place of Blizzard's while its talents are switched
	on (/msb talents): every tree side by side, a talent's own art, and plans
	-- a working plan, a list of saved ones, its Apply to learn one, and share
	strings to pass a build on. Nothing of it is copied here; this reads its
	window and calls its plan functions, as an addon of its own.

	Laid over its window, as on Blizzard's (TalentWindow.lua):

	  * a strip above it: PATHFINDER, the build followed as a menu, the card
	    for the next point, and three buttons -- Plan to my level, Whole build
	    as a plan, Share;
	  * on each talent of every tree, the badge with the points the build puts
	    there, and the gold ring and NEXT on the next point's; "NEXT POINT
	    HERE" by its tree's name. Shown on your learned talents: while it
	    shows a plan, the marks step aside;
	  * the advisor's line on the tooltip, which it shows with the client's
	    SetTalent, so TalentWindow.lua's line comes with it.

	A plan goes in Modern Spellbook's own list, made the working plan, for
	its Apply to learn; Pathfinder never spends a point. Share gives the
	build as its share string, and takes one -- a friend's, or a plan of its
	-- for the advisor to follow.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme
local TA = AegisPathfinder.TalentAdvisor
local TW = TA.Window

local MW = {}
TA.Modern = MW

-- Layout, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local G = {
	STRIP_H = 60, WARN_H = 18, LIFT = 10, PAD = 14, BRAND_W = 128, DROP_W = 340, DROP_H = 24, CARD_H = 46, ICON = 30,
	PLAN_W = 140, WHOLE_W = 180, SHARE_W = 80, BUTTON_H = 30, GLOW = 62, PILL_H = 16,
	SHARE_WIDTH = 560, SHARE_HEIGHT = 340, FIELD_H = 28,
}

--- Modern Spellbook's talent window, if it is there: its TalentTree.
function MW:Tree()
	local tree = TalentTree
	if type(tree) == "table" and tree.frame and tree.specs and tree.Refresh then return tree end
	return nil
end

--- Whether it has plans to save to, without making them to find out.
function MW:HasPlans()
	return TalentSimulation ~= nil or CTalentSimulation ~= nil
end

--- Its plans (TalentSimulation), made as its own window makes them, the
--- first time they are wanted.
function MW:Simulation()
	if not TalentSimulation and CTalentSimulation then
		TalentSimulation = CTalentSimulation()
		TalentSimulation:Load()
	end
	return TalentSimulation
end

local function Text(parent, role, size, color)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(fs, role, size)
	fs:SetJustifyH("LEFT")
	Theme:TextColor(fs, color)
	return fs
end

--[[ The strip ---------------------------------------------------------------- ]]

function MW:BuildStrip(frame)
	local strip = CreateFrame("Frame", "AegisPathfinderModernStrip", frame)
	strip:SetHeight(G.STRIP_H)
	strip:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 6, G.LIFT)
	strip:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -6, G.LIFT)
	strip:SetFrameLevel(frame:GetFrameLevel() + 20)
	strip:EnableMouse(true)
	Theme:Panel(strip, "panel", false)

	-- Every piece hung from the strip's top, at set places: a warning adds a
	-- row underneath, and the card takes the room between the menu and the
	-- buttons, however wide its window is.
	local menuX = G.PAD + G.BRAND_W
	local cardX = menuX + G.DROP_W + 16
	local buttonsW = G.PLAN_W + G.WHOLE_W + G.SHARE_W + 12
	local brand = Text(strip, "display", 14, "accentGlow")
	brand:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, -23)
	brand:SetText("PATHFINDER")
	local rule = strip:CreateTexture(nil, "ARTWORK")
	rule:SetTexture(Theme.texture.solid)
	rule:SetWidth(1); rule:SetHeight(28)
	rule:SetPoint("TOPLEFT", strip, "TOPLEFT", menuX - 14, -16)
	Theme:Tint(rule, "border")

	local following = Text(strip, "body", 11, "textDim")
	following:SetPoint("TOPLEFT", strip, "TOPLEFT", menuX, -9)
	following:SetText("Following")
	local drop = Theme:Dropdown(strip, G.DROP_W, function(value) MW:Choose(value) end)
	drop:SetHeight(G.DROP_H)
	drop:SetPoint("TOPLEFT", strip, "TOPLEFT", menuX, -24)

	local card = TW:Card(strip, G.ICON)
	card:SetPoint("TOPLEFT", strip, "TOPLEFT", cardX, -(G.STRIP_H - G.CARD_H) / 2)
	card:SetPoint("BOTTOMRIGHT", strip, "TOPRIGHT", -(G.PAD + buttonsW + 16), -(G.STRIP_H + G.CARD_H) / 2)
	local note = Text(strip, "body", 12, "text")
	note:SetPoint("TOPLEFT", strip, "TOPLEFT", cardX, -23)
	note:SetPoint("RIGHT", strip, "RIGHT", -(G.PAD + buttonsW + 16), 0)
	local warn = Text(strip, "body", 11, TW.G.AMBER)
	warn:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, -G.STRIP_H + 2)
	warn:SetPoint("RIGHT", strip, "RIGHT", -G.PAD, 0)

	local top = -(G.STRIP_H - G.BUTTON_H) / 2
	local share = Theme:Pill(strip, "Share", G.SHARE_W, G.BUTTON_H)
	share:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -G.PAD, top)
	share:SetScript("OnClick", function() MW:ShowShare() end)
	local whole = Theme:Pill(strip, "Whole build as a plan", G.WHOLE_W, G.BUTTON_H)
	whole:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -(G.PAD + G.SHARE_W + 6), top)
	whole:SetScript("OnClick", function() MW:SavePlan(true) end)
	local mine = Theme:Pill(strip, "Plan to my level", G.PLAN_W, G.BUTTON_H)
	mine:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -(G.PAD + G.SHARE_W + G.WHOLE_W + 12), top)
	mine:SetActive(true)
	mine:SetScript("OnClick", function() MW:SavePlan(false) end)

	strip.drop, strip.card, strip.note, strip.warn = drop, card, note, warn
	strip.share, strip.whole, strip.mine = share, whole, mine
	self.strip = strip
	return strip
end

--- A button that can't be pressed now: dimmed and deaf.
local function Able(button, on)
	button:SetAlpha(on and 1 or 0.45)
	button:EnableMouse(on and true or false)
end

function MW:PaintStrip(state)
	local strip = self.strip
	strip.drop:SetItems(TA:BuildItems(state))
	strip.drop:SetValue(state.choice or "auto")
	local w = strip:GetWidth()
	if w and w > 0 then strip.drop.list:SetWidth(G.DROP_W + 60) end
	local line, warn = TA:StripLines(state)
	if TW:FillCard(strip.card, TA:NextCard(state)) then
		strip.note:SetText("")
	else
		strip.note:SetText(line or "")
	end
	strip.warn:SetText(warn or "")
	strip:SetHeight(G.STRIP_H + (warn and G.WARN_H or 0))
	local plans = state.fits and self:HasPlans()
	Able(strip.mine, plans)
	Able(strip.whole, plans)
	Able(strip.share, state.fits)
	strip:Show()
end

--- A build picked from the strip's menu: the same setting as the options'.
function MW:Choose(value)
	local s = TA:Settings()
	if not s then return end
	s.talentbuild = value
	TA:Refresh()
	AegisPathfinder:RefreshConfigPanel()
end

--[[ The marks ---------------------------------------------------------------- ]]

--- "NEXT POINT HERE" by a tree's name.
function MW:PaintPill(spec, on)
	if not spec.apPill then
		local pill = CreateFrame("Frame", nil, spec.panel)
		pill:SetHeight(G.PILL_H)
		pill:SetPoint("LEFT", spec.header, "RIGHT", 8, 0)
		pill:SetFrameLevel(spec.panel:GetFrameLevel() + 12)
		pill.fill = Theme:NineSlice(pill, Theme.texture.pillFill, "BACKGROUND", TW.G.GOLD, nil, { corner = 8 })
		local fs = pill:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(fs, "display", 10)
		fs:SetPoint("CENTER", pill, "CENTER", 0, 0)
		fs:SetTextColor(TW.G.ON_ACCENT[1], TW.G.ON_ACCENT[2], TW.G.ON_ACCENT[3])
		fs:SetText("NEXT POINT HERE")
		pill:SetWidth(math.max(110, fs:GetStringWidth() + 14))
		pill.text = fs
		spec.apPill = pill
	end
	if on then spec.apPill:Show() else spec.apPill:Hide() end
end

--- Every talent of a tree's grid: its icon's marks, centred on the icon.
function MW:PaintGrid(grid, state)
	for _, icon in ipairs(grid and grid.icons or {}) do
		TW:PaintMark(icon.frame, state, icon.talent_name, icon.border_frame or icon.frame, G.GLOW)
	end
end

local function ClearGrid(grid)
	for _, icon in ipairs(grid and grid.icons or {}) do
		if icon.frame.apMarks then icon.frame.apMarks:Hide() end
	end
end

function MW:Clear()
	local tree = self:Tree()
	if not tree then return end
	for _, spec in ipairs(tree.specs) do
		ClearGrid(spec.grid)
		if spec.apPill then spec.apPill:Hide() end
	end
	local ev = tree.expanded_view
	for _, grid in pairs(ev and ev.grids_by_tab or {}) do ClearGrid(grid) end
end

--- Mark the window as it is now: after it has drawn itself.
function MW:Paint()
	local tree = self:Tree()
	if not (tree and self.hooked) then return end
	if not self.strip then self:BuildStrip(tree.frame) end
	local state = TW.Current()
	if not state then
		self.strip:Hide()
		return self:Clear()
	end
	if tree.frame:IsShown() then TW:HideToast() end
	self:PaintStrip(state)
	local sim = TalentSimulation
	if not state.fits or (sim and sim.IsSimulated and sim:IsSimulated()) then return self:Clear() end
	local t = state.next and state.tree.talent[state.next]
	for _, spec in ipairs(tree.specs) do
		self:PaintGrid(spec.grid, state)
		self:PaintPill(spec, t and t.tab == spec.tab_index)
	end
	local ev = tree.expanded_view
	if tree.expanded_spec and ev and ev.grid then self:PaintGrid(ev.grid, state) end
end

--[[ Plans -------------------------------------------------------------------- ]]

--- Save the build as a plan in Modern Spellbook's list -- to your level, or
--- the whole build -- and make it the plan its window shows, for its Apply.
function MW:SavePlan(whole)
	local state = TW.Current()
	local sim = self:Simulation()
	if not (state and state.fits and sim) then return end
	local mine, all = TA.PlanSizes(state)
	local n = whole and all or mine
	local ranks = TA.PlanRanks(state, n)
	sim:NewWorkingPlan()
	local plan = sim:GetPlan()
	local points = 0
	for name, r in pairs(ranks) do
		local t = state.tree.talent[name]
		plan[t.tab][t.index] = r
		plan[t.tab].points = plan[t.tab].points + r
		points = points + r
	end
	plan.points = points
	local name = TA:PlanName(state, not whole and state.level or nil)
	sim:SaveWorkingPlan(name)
	-- Its list holds 20, and says so itself when full; the plan is still
	-- the one its window shows.
	local saved = false
	for _, p in ipairs(sim:GetSavedPlans() or {}) do
		if p.name == name then saved = true end
	end
	sim:SetMode("simulated")
	local tree = self:Tree()
	if tree then
		if tree.UpdateSimControls then tree:UpdateSimControls() end
		tree:Refresh()
	end
	if saved then
		AegisPathfinder:Print("Saved \"" .. name .. "\" in Modern Spellbook's plans: " .. points .. " points. "
			.. "It's the plan its window shows now; press its Apply to learn them.")
	else
		AegisPathfinder:Print("\"" .. name .. "\" (" .. points .. " points) is the plan Modern Spellbook's window "
			.. "shows now, but its list is full, so it isn't saved there. Press its Apply to learn them.")
	end
	if self.share then self:PaintShare() end
end

--[[ Share and plan ----------------------------------------------------------- ]]

--- A box to type into, in the theme: a dark field with a hairline edge.
local function Field(parent)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetHeight(G.FIELD_H)
	box:SetAutoFocus(false)
	box:SetTextInsets(8, 8, 0, 0)
	Theme:SetFont(box, "body", 12)
	box:SetTextColor(1, 1, 1)
	local edge = box:CreateTexture(nil, "BACKGROUND")
	edge:SetTexture(Theme.texture.solid)
	edge:SetAllPoints(box)
	Theme:Tint(edge, "text", 0.22)
	local bg = box:CreateTexture(nil, "BORDER")
	bg:SetTexture(Theme.texture.solid)
	bg:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
	bg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
	bg:SetVertexColor(0, 0, 0, 0.85)
	box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	box:SetScript("OnHide", function() this:ClearFocus() end)
	return box
end

function MW:BuildShare()
	local f = CreateFrame("Frame", "AegisPathfinderTalentShare", UIParent)
	f:SetWidth(G.SHARE_WIDTH); f:SetHeight(G.SHARE_HEIGHT)
	f:SetFrameStrata("DIALOG")
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	Theme:Panel(f, "panel", true)
	Theme:RegisterWindow(f)
	local header = Theme:Header(f, 40)
	header.wordmark:Hide()
	header:MakeDragHandle(f)
	local title = Text(header, "display", 16, "text")
	title:SetPoint("CENTER", header, "CENTER", 0, 0)
	title:SetText("SHARE AND PLAN")
	local close = Theme:CloseChip(header, f)
	close:SetPoint("RIGHT", header, "RIGHT", -8, 0)
	table.insert(UISpecialFrames, "AegisPathfinderTalentShare")

	local x, w = 16, G.SHARE_WIDTH - 32
	local shareTitle = Text(f, "body", 14, "text")
	shareTitle:SetPoint("TOPLEFT", f, "TOPLEFT", x, -56)
	local shareHint = Text(f, "body", 12, "textDim")
	shareHint:SetPoint("TOPLEFT", shareTitle, "BOTTOMLEFT", 0, -6)
	shareHint:SetText("A Modern Spellbook string: paste it into its Import, or send it to a friend.")
	local shareBox = Field(f)
	shareBox:SetWidth(w)
	shareBox:SetPoint("TOPLEFT", shareHint, "BOTTOMLEFT", 0, -6)
	-- It is there to be copied: whatever is typed, it goes back to the string.
	shareBox:SetScript("OnTextChanged", function()
		if this.text and this:GetText() ~= this.text then
			this:SetText(this.text)
			this:HighlightText()
		end
	end)
	shareBox:SetScript("OnEditFocusGained", function() this:HighlightText() end)
	local copyHint = Text(f, "body", 12, "textDim")
	copyHint:SetPoint("TOPLEFT", shareBox, "BOTTOMLEFT", 0, -4)
	copyHint:SetText("Selected for you: press Ctrl+C to copy.")

	local followTitle = Text(f, "body", 14, "text")
	followTitle:SetPoint("TOPLEFT", copyHint, "BOTTOMLEFT", 0, -16)
	followTitle:SetText("Follow a shared build")
	local followHint = Text(f, "body", 12, "textDim")
	followHint:SetPoint("TOPLEFT", followTitle, "BOTTOMLEFT", 0, -6)
	followHint:SetText("Paste a Modern Spellbook string. The advisor follows it, biggest tree first, a row at a time.")
	local followBox = Field(f)
	followBox:SetWidth(w - 110)
	followBox:SetPoint("TOPLEFT", followHint, "BOTTOMLEFT", 0, -6)
	local follow = Theme:Pill(f, "Follow it", 100, G.FIELD_H)
	follow:SetPoint("LEFT", followBox, "RIGHT", 10, 0)
	local said = Text(f, "body", 12, "text")
	said:SetPoint("TOPLEFT", followBox, "BOTTOMLEFT", 0, -4)
	said:SetWidth(w)
	local function DoFollow()
		local ok, why = TA:Follow(followBox:GetText())
		if ok then
			followBox:SetText("")
			followBox:ClearFocus()
			Theme:TextColor(said, "accentGlow")
			said:SetText("Following it. Pick it again any time under Following: Shared build.")
			TA:Refresh()
			AegisPathfinder:RefreshConfigPanel()
			MW:PaintShare()
		else
			Theme:TextColor(said, TW.G.AMBER)
			said:SetText(why)
		end
	end
	follow:SetScript("OnClick", DoFollow)
	followBox:SetScript("OnEnterPressed", DoFollow)

	local planTitle = Text(f, "body", 14, "text")
	planTitle:SetPoint("TOPLEFT", said, "BOTTOMLEFT", 0, -14)
	planTitle:SetText("A plan in Modern Spellbook")
	local planHint = Text(f, "body", 12, "textDim")
	planHint:SetPoint("TOPLEFT", planTitle, "BOTTOMLEFT", 0, -6)
	planHint:SetWidth(w)
	planHint:SetText("Saved as a plan in Modern Spellbook's list. Press its Apply to learn the points; "
		.. "Pathfinder never spends one itself.")
	local mine = Theme:Pill(f, "Plan to my level", (w - 8) / 2, 34)
	mine:SetPoint("TOPLEFT", planHint, "BOTTOMLEFT", 0, -10)
	mine:SetActive(true)
	mine:SetScript("OnClick", function() MW:SavePlan(false) end)
	local whole = Theme:Pill(f, "Whole build", (w - 8) / 2, 34)
	whole:SetPoint("LEFT", mine, "RIGHT", 8, 0)
	whole:SetScript("OnClick", function() MW:SavePlan(true) end)

	f.shareTitle, f.shareBox, f.followBox, f.follow, f.said = shareTitle, shareBox, followBox, follow, said
	f.planTitle, f.planHint, f.mine, f.whole = planTitle, planHint, mine, whole
	f:Hide()
	self.share = f
	return f
end

--- Fill the dialog for the build followed now.
function MW:PaintShare()
	local f = self.share
	local state = TW.Current()
	local text = TA:ShareText(state)
	if text then
		f.shareTitle:SetText("Share " .. TA:Label(state))
		f.shareBox.text = text
		f.shareBox:SetText(text)
		f.shareBox:HighlightText()
	else
		f.shareTitle:SetText("Share")
		f.shareBox.text = ""
		f.shareBox:SetText("")
	end
	local plans = text and self:HasPlans()
	if plans then
		local mine, all = TA.PlanSizes(state)
		f.mine.label:SetText(string.upper("Plan to my level · " .. mine .. " points"))
		f.whole.label:SetText(string.upper("Whole build · " .. all .. " points"))
	end
	Able(f.mine, plans)
	Able(f.whole, plans)
end

function MW:ShowShare()
	local f = self.share or self:BuildShare()
	f.said:SetText("")
	self:PaintShare()
	f:Show()
	if f.shareBox.text ~= "" then
		f.shareBox:SetFocus()
		f.shareBox:HighlightText()
	end
end

--[[ Hooks -------------------------------------------------------------------- ]]

--[[ Its window draws itself in its Refresh -- opening, a point spent, a plan
	changed -- so that is wrapped, on the window it made (TalentTree); and its
	frame's showing. Once: when Modern Spellbook has loaded. ]]
function MW:Hook()
	local tree = self:Tree()
	if self.hooked or not tree then return end
	self.hooked = true
	local refresh = tree.Refresh
	tree.Refresh = function(t)
		refresh(t)
		MW:Paint()
	end
	local onShow, onHide = tree.frame:GetScript("OnShow"), tree.frame:GetScript("OnHide")
	tree.frame:SetScript("OnShow", function()
		if onShow then onShow() end
		MW:Paint()
	end)
	tree.frame:SetScript("OnHide", function()
		if onHide then onHide() end
		if MW.share then MW.share:Hide() end
	end)
end

local events = CreateFrame("Frame")
MW.events = events
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	if event == "PLAYER_LOGIN" or arg1 == "ModernSpellBook" then MW:Hook() end
end)
-- Loaded before this, it is there already.
MW:Hook()
