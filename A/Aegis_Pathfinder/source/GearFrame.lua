--[[ GearFrame.lua -- the Item Score page: the stat weights behind the item
	score, in the options window under Gear.

	Zygor's Item Score page, in this addon's language: the spec you are
	scored as (Auto follows your talents), a line saying where that came from,
	which set of weights it is (leveling until 60, or 60) and whether they are
	the defaults or yours, "Show all stats", and every weight down the left, a
	box each. Only the stats your spec weighs are listed until "Show all
	stats" is on. Beside them, the weights as a string in OctoPawn's format,
	to import or export; under them, Reset weights.

	Above the weights, Pawn's specs: a switch for each spec of your class to
	score as well as yours -- a line each on tooltips, weighed against the
	best you have worn for it -- the chat notice for their upgrades, and
	"Forget best items" to start remembering again.

	It used to be a window of its own. The page grows with the list, and the
	options window scrolls it.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

-- The page's name in the options window's list.
AegisPathfinder.ITEM_SCORE_PAGE = "Item Score"

-- Layout, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local L = {
	-- The name column fits "Armor Penetration" and "Casting Regen %" on a line:
	-- at 100px they wrapped, two cramped lines in a 26px row (seen in game).
	ROW_H = 26, BOX_W = 58, BOX_H = 20, LIST_W = 206, GAP = 16, BUTTON_H = 22,
	SPEC_W = 200, NOTE_H = 44, LABEL_X = 8, RESET_W = 136, STATUS_H = 44,
}

--- "SPELL POWER" -> "Spell Power", "WEAPON DPS" -> "Weapon DPS".
function AegisPathfinder.StatLabel(stat)
	local Data = AegisPathfinder.ItemScoreData
	local text = string.lower(Data.labels[stat] or stat)
	text = string.gsub(text, "(%a)([%w']*)", function(a, b) return string.upper(a) .. b end)
	text = string.gsub(text, "Dps", "DPS")
	return text
end

local function trimNum(v)
	local s = string.format("%.2f", v or 0)
	s = string.gsub(s, "0+$", "")
	return (string.gsub(s, "%.$", ""))
end

--- A box to type into, in the theme: a dark field with a hairline edge.
local function Field(parent, width, height)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetWidth(width)
	box:SetHeight(height)
	box:SetAutoFocus(false)
	box:SetTextInsets(6, 6, 0, 0)
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
	box.bg, box.edge = bg, edge
	box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	-- A page changing or the window closing takes the keyboard back.
	box:SetScript("OnHide", function() this:ClearFocus() end)
	return box
end

--- Put the box's number into effect, or put back the one it had.
local function Commit(box)
	local v = tonumber(box:GetText())
	if v then
		AegisPathfinder.ItemScore:SetWeight(box.stat, v)
	else
		box:SetText(trimNum(box.shown))
	end
end

--[[ Build the page into the options window's `body`, from `top` down.
	`bottom` is the space the window leaves under a page. The list's length
	changes with the spec and "Show all stats", so the page's height is set
	each time it is drawn (UpdateItemScorePage), not here. ]]
function AegisPathfinder:CreateItemScorePage(body, width, top, bottom)
	local page = { body = body, width = width, cells = {}, bottom = bottom or 0 }
	self.itemscorepage = page
	local y = top

	local spec = Theme:Dropdown(body, L.SPEC_W, function(value)
		AegisPathfinder.ItemScore:SetSpec(value ~= "auto" and value or nil)
	end)
	spec:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
	local class = body:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(class, "display", 12)
	class:SetPoint("LEFT", spec, "RIGHT", 10, 0)
	class:SetPoint("RIGHT", body, "RIGHT", 0, 0)
	class:SetJustifyH("RIGHT")
	Theme:TextColor(class, "textDim")
	y = y + 30 + 6

	local note = Theme:FinePrint(body, width)
	note:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
	y = y + L.NOTE_H

	local showAll = Theme:Switch(body, "Show all stats", function(on)
		AegisPathfinder.ItemScore.Settings().showall = on
		AegisPathfinder:UpdateItemScorePage()
	end)
	showAll:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
	y = y + showAll:Fit(width) + 12

	-- Pawn's specs: which to score, the notice, and forgetting.
	local IS = AegisPathfinder.ItemScore
	local specsCaption = body:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(specsCaption, "display", 11)
	specsCaption:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
	specsCaption:SetText("SCORE FOR THESE SPECS")
	Theme:TextColor(specsCaption, "accent")
	y = y + 18
	page.specSwitches = {}
	for _, spec in ipairs(IS:Specs(IS:Class())) do
		local key = spec
		local sw = Theme:Switch(body, IS:SpecLabel(key), function(on)
			AegisPathfinder.ItemScore:SetSpecActive(key, on)
		end)
		sw.spec = key
		sw:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
		y = y + sw:Fit(width) + 4
		table.insert(page.specSwitches, sw)
	end
	local notify = Theme:Switch(body, "Tell me when a drop beats my best for another spec", function(on)
		AegisPathfinder.ItemScore.Settings().notify = on
	end)
	notify:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(y + 4))
	y = y + 4 + notify:Fit(width) + 6
	local specsNote = Theme:FinePrint(body, width)
	specsNote:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
	specsNote:SetText("Each spec on gets a line on item tooltips, weighed against the best you "
		.. "have worn for it, as Pawn does: it remembers as you change gear.")
	y = y + L.NOTE_H - 10
	local forget = Theme:PanelButton(body, "Forget best items", 150, L.BUTTON_H)
	forget:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
	forget:SetScript("OnClick", function()
		AegisPathfinder.ItemScore:ForgetBest()
		page.said = "Forgotten: remembering again from what you wear now."
		AegisPathfinder:UpdateItemScorePage()
	end)
	y = y + L.BUTTON_H + 16
	page.notify, page.specsNote, page.forget = notify, specsNote, forget
	page.listTop = y

	-- Beside the weights: the weights as a string, to import or export.
	local rx = L.LIST_W + L.GAP
	local rw = width - rx
	local caption = body:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(caption, "display", 11)
	caption:SetPoint("TOPLEFT", body, "TOPLEFT", rx, -y)
	caption:SetText("SHARE WEIGHTS")
	Theme:TextColor(caption, "accent")
	local share = Field(body, rw, L.BUTTON_H + 2)
	share:SetPoint("TOPLEFT", body, "TOPLEFT", rx, -(y + 16))
	share:SetMaxLetters(2000)
	Theme:SetFont(share, "body", 11)
	share:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	local import = Theme:PanelButton(body, "Import", rw, L.BUTTON_H)
	import:SetPoint("TOPLEFT", share, "BOTTOMLEFT", 0, -6)
	import:SetScript("OnClick", function()
		local ok, why = AegisPathfinder.ItemScore:Import(share:GetText())
		page.said = ok and "Imported." or why
		share:ClearFocus()
		AegisPathfinder:UpdateItemScorePage()
	end)
	local export = Theme:PanelButton(body, "Export", rw, L.BUTTON_H)
	export:SetPoint("TOPLEFT", import, "BOTTOMLEFT", 0, -6)
	export:SetScript("OnClick", function()
		share:SetText(AegisPathfinder.ItemScore:Export())
		share:SetFocus()
		share:HighlightText()
		page.said = "Copy it with Ctrl+C. OctoPawn reads it too."
		AegisPathfinder:UpdateItemScorePage()
	end)
	local status = Theme:FinePrint(body, rw)
	status:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -8)
	page.shareH = 16 + (L.BUTTON_H + 2) + 6 + L.BUTTON_H + 6 + L.BUTTON_H + 8 + L.STATUS_H

	-- Under the weights: back to the defaults. Placed as the list is drawn.
	local reset = Theme:PanelButton(body, "Reset weights", L.RESET_W, L.BUTTON_H)
	reset:SetScript("OnClick", function()
		AegisPathfinder.ItemScore:ResetWeights()
		page.said = "Back to the default weights."
		AegisPathfinder:UpdateItemScorePage()
	end)

	page.spec, page.class, page.note, page.showAll = spec, class, note, showAll
	page.share, page.import, page.export, page.status, page.reset = share, import, export, status, reset
	--- The page at another width, as the window is resized: the note, and
	--- the share column out to the new edge.
	function page:Resize(w)
		self.width = w
		self.note:SetWidth(w)
		self.showAll:Fit(w)
		for _, sw in ipairs(self.specSwitches) do sw:Fit(w) end
		self.notify:Fit(w)
		self.specsNote:SetWidth(w)
		local cw = w - L.LIST_W - L.GAP
		for _, r in ipairs({ self.share, self.import, self.export, self.status }) do r:SetWidth(cw) end
	end

	-- Drawn afresh whenever the page is turned to, last time's word gone.
	body.refresh = function()
		page.said = nil
		AegisPathfinder:UpdateItemScorePage()
	end

	AegisPathfinder.ItemScore:OnChange(function()
		if body:IsVisible() then AegisPathfinder:UpdateItemScorePage() end
	end)
	return page
end

--- One stat's label and box, made the first time it is needed.
function AegisPathfinder:ItemScoreCell(stat)
	local page = self.itemscorepage
	local cell = page.cells[stat]
	if cell then return cell end
	cell = CreateFrame("Frame", nil, page.body)
	cell:SetWidth(L.LIST_W)
	cell:SetHeight(L.ROW_H)
	local label = cell:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(label, "body", 12)
	label:SetPoint("LEFT", cell, "LEFT", L.LABEL_X, 0)
	label:SetWidth(L.LIST_W - L.BOX_W - L.LABEL_X - 6)
	label:SetJustifyH("LEFT")
	Theme:TextColor(label, "text")
	label:SetText(AegisPathfinder.StatLabel(stat))
	local box = Field(cell, L.BOX_W, L.BOX_H)
	box:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
	box:SetMaxLetters(8)
	box.stat = stat
	box:SetScript("OnEnterPressed", function() Commit(this); this:ClearFocus() end)
	box:SetScript("OnEditFocusLost", function() Commit(this) end)
	box:SetScript("OnEscapePressed", function()
		this:SetText(trimNum(this.shown))
		this:ClearFocus()
	end)
	cell.label, cell.box = label, box
	page.cells[stat] = cell
	return cell
end

--- The stats listed: those the spec weighs, or all of them.
function AegisPathfinder:ItemScoreStats(weights)
	local IS, Data = self.ItemScore, self.ItemScoreData
	local out = {}
	for _, stat in ipairs(Data.stats) do
		if IS.Settings().showall or (weights[stat] or 0) ~= 0 then table.insert(out, stat) end
	end
	return out
end

function AegisPathfinder:UpdateItemScorePage()
	local page = self.itemscorepage
	if not page then return end
	local IS = self.ItemScore
	local class = IS:Class()
	local spec, why = IS:Spec()
	local weights = IS:Weights(class, spec)

	-- The spec picker: Auto, naming what Auto is now, then each spec.
	local detected = IS:DetectSpec(class)
	local items = { { value = "auto", label = "Auto (" .. IS:SpecLabel(detected or spec) .. ")" } }
	for _, s in ipairs(IS:Specs(class)) do table.insert(items, { value = s, label = IS:SpecLabel(s) }) end
	page.spec:SetItems(items)
	page.spec:SetValue(IS.Settings().spec or "auto")
	page.class:SetText(UnitClass("player") or class)

	local whence = (why == "picked" and "the spec you picked")
		or (why == "talents" and "your talents")
		or "your class's usual leveling spec, until you have talents"
	-- Which set: leveling's below 60, then 60's; a tank's is the same throughout.
	local _, set = IS:Defaults(class, spec)
	local which = (set == "leveling" and "Leveling weights, until level " .. IS.MAX_LEVEL)
		or (IS:Level() < IS.MAX_LEVEL and "Tank weights, the same at every level")
		or "Level " .. IS.MAX_LEVEL .. " weights"
	page.note:SetText("Scoring as " .. IS:SpecLabel(spec) .. ", from " .. whence .. ".\n" .. which
		.. (IS:IsCustom(class, spec) and ", with your own changes." or ": the defaults."))
	page.status:SetText(page.said or "")
	page.showAll:SetOn(IS.Settings().showall)
	-- Your spec is always scored; the others are yours to switch on.
	for _, sw in ipairs(page.specSwitches) do
		local mine = sw.spec == spec
		sw.label:SetText(IS:SpecLabel(sw.spec) .. (mine and "  (your spec)" or ""))
		sw:SetOn(IS:IsSpecActive(sw.spec))
		sw:SetLocked(mine)
	end
	page.notify:SetOn(IS.Settings().notify)

	-- The weights, one to a row down the left.
	for _, cell in pairs(page.cells) do cell:Hide() end
	local stats = self:ItemScoreStats(weights)
	for i, stat in ipairs(stats) do
		local cell = self:ItemScoreCell(stat)
		cell:ClearAllPoints()
		cell:SetPoint("TOPLEFT", page.body, "TOPLEFT", 0, -(page.listTop + (i - 1) * L.ROW_H))
		cell.box.shown = weights[stat] or 0
		cell.box:SetText(trimNum(cell.box.shown))
		cell:Show()
	end

	-- Reset under whichever column is longer, and the page as tall as that.
	local listH = table.getn(stats) * L.ROW_H
	local resetTop = page.listTop + math.max(listH, page.shareH) + 10
	page.reset:ClearAllPoints()
	page.reset:SetPoint("TOPLEFT", page.body, "TOPLEFT", 0, -resetTop)
	page.body.contentHeight = resetTop + L.BUTTON_H + page.bottom
	page.body:SetHeight(page.body.contentHeight)
	if self.SizeConfigPage then self:SizeConfigPage(true) end
end

--- /apg gear: the options window at this page, or closed if it is on it.
function AegisPathfinder:ToggleItemScorePage()
	if not self.optionsframe then self:CreateConfigPanel() end
	local frame = self.optionsframe
	if frame:IsShown() and frame.page == self.ITEM_SCORE_PAGE then
		frame:Hide()
		return
	end
	frame:Show()
	self:ShowConfigPage(self.ITEM_SCORE_PAGE)
end
