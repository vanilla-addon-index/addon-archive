--[[ GearFinderTab.lua -- the Gear Finder, as a tab on the character panel.

	Laid out like Zygor's Gear Finder, in the addon's theme:

	  * a tab after the character panel's own -- Character, Pet, Reputation,
	    Skills, Honor -- styled like them, after whichever is last shown (the
	    Pet tab comes and goes), and with pfUI's look when pfUI has skinned
	    the others;
	  * its page over the character panel, wider than it, with the tabs still
	    underneath. The page is one of CHARACTERFRAME_SUBFRAMES, so the client's
	    own ToggleCharacter swaps it with the other pages, and closing it
	    closes the character panel as closing any of them does;
	  * a cell per slot, as the character sheet has them: two columns of
	    eight, and the ranged slot under the suggested dungeon. A cell shows
	    the slot's biggest upgrade -- its %, where it drops, "at level N" if
	    you cannot wear it yet -- or the one you picked from its list. A slot
	    with none shows its empty picture and "No upgrade found";
	  * clicking a cell opens the slot's list beside it: every upgrade for it,
	    biggest first. Picking one makes it the cell's, and the suggested
	    dungeon follows;
	  * the suggested dungeon on the right: its loading screen, the spec it
	    scores for, the dungeon the cells' items drop in most, arrows through
	    the rest in order, and its guide;
	  * a footer saying where it looked, and a cog for the Gear options.

	What it shows is GearFinder.lua's; this is the drawing of it.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme
local GF = AegisPathfinder.GearFinder

-- Layout, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local G = {
	PAGE = "AegisPathfinderGearFinderPage",
	W = 714, HEADER = 30, FOOTER = 28,
	COL_X = { 10, 245, 482 }, CELL_W = 227, RIGHT_W = 222,
	TOP = 8, ROW_H = 44, CELL_H = 41, ICON = 30,
	LIST_W = 240, LIST_ROW = 38, LIST_HEAD = 28, LIST_FOOT = 30, LIST_ROWS = 8,
	PIC_W = 202, PIC_H = 101, BODY_H = 370,
	-- Blizzard's tabs overlap by 16; a skin's may not, so the gap is measured.
	TAB_GAP = -16,
	-- Where the page sits on the client's own character panel art: over its
	-- frame, down to where its tabs hang.
	ART_TOP = { 6, -6 }, ART_BOTTOM = { 6, 78 },
}

-- The drawing's helpers, in one table for the same reason.
local H = {}

--- An upgrade's gain, as a cell says it.
function H.Gain(e)
	local c = e.compare
	if c.emptySlot then return "Empty slot" end
	if c.pct then return string.format("+%.0f%%", c.pct) end
	return string.format("+%.1f", c.delta or 0)
end

--- Show the game's own tooltip for an item -- only it can show one.
function H.ItemTip(owner, e, hint)
	if not e or not GetItemInfo(e.item) then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(e.item)
	if hint then GameTooltip:AddLine(hint, 0.78, 0.78, 0.74) end
	GameTooltip:Show()
end

-- A font string; with `lines`, that many lines high, so a longer text ends
-- in "..." where the client would otherwise wrap it onto the cell below.
function H.Text(parent, role, size, color, lines)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(fs, role, size)
	fs:SetJustifyH("LEFT")
	if color then Theme:TextColor(fs, color) end
	if lines then fs:SetHeight(lines * (size + 2)) end
	return fs
end

--[[ The tab ------------------------------------------------------------------ ]]

-- The first CharacterFrameTab number nobody has: 6, unless another addon
-- added a tab first. The client's PanelTemplates walk the tabs by number.
local function FreeTab()
	local i = 1
	while getglobal("CharacterFrameTab" .. i) do i = i + 1 end
	return i
end

--- Put the tab after the last of the character panel's tabs that is shown,
--- spaced as those before it are: Blizzard's overlap, or a skin's gap.
function GF:PlaceTab()
	local tab = self.tab
	if not tab then return end
	local shown = {}
	for i = 1, tab:GetID() - 1 do
		local t = getglobal("CharacterFrameTab" .. i)
		if t and t:IsShown() then table.insert(shown, t) end
	end
	local n = table.getn(shown)
	if n == 0 then return end
	local last, before = shown[n], shown[n - 1]
	local gap = G.TAB_GAP
	if before and last:GetLeft() and before:GetRight() then
		gap = math.floor(last:GetLeft() - before:GetRight() + 0.5)
	end
	-- pfUI skins the panel's tabs by number, one to five; ours gets the same.
	if last.backdrop and not tab.skinned and pfUI and pfUI.api and pfUI.api.SkinTab then
		tab.skinned = pcall(pfUI.api.SkinTab, tab)
	end
	tab:ClearAllPoints()
	tab:SetPoint("LEFT", last, "RIGHT", gap, 0)
	-- As this file loads there are no settings yet: shown until there are.
	if not AegisPathfinder.db or GF.Settings().enabled then tab:Show() else tab:Hide() end
end

--- The page over the character panel: over its frame, or pfUI's backdrop
--- of it, down to where the tabs hang; wider than the panel, to the right.
function GF:AnchorPage()
	local page = self.panel
	page:ClearAllPoints()
	local bd = CharacterFrame.backdrop
	if bd then
		page:SetPoint("TOPLEFT", bd, "TOPLEFT", 0, 0)
		page:SetPoint("BOTTOMLEFT", bd, "BOTTOMLEFT", 0, 0)
	else
		page:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", G.ART_TOP[1], G.ART_TOP[2])
		page:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", G.ART_BOTTOM[1], G.ART_BOTTOM[2])
	end
	page:SetWidth(G.W)
	-- Over the panel's art and close button, under its tabs, which hang
	-- over the page's edge as they do over the panel's.
	page:SetFrameLevel(CharacterFrame:GetFrameLevel() + 3)
end

--- Open the character panel on the Gear Finder, or close it if it is open
--- there: the options' button, /apg finder and the Gear Advisor use this.
function AegisPathfinder:ToggleGearFinder()
	if GF.panel then ToggleCharacter(G.PAGE) end
end

--[[ A cell ---------------------------------------------------------------------- ]]

function H.NewCell(body, def)
	local b = CreateFrame("Button", nil, body)
	b:SetWidth(def.col == 3 and G.RIGHT_W or G.CELL_W)
	b:SetHeight(G.CELL_H)
	b:SetPoint("TOPLEFT", body, "TOPLEFT", G.COL_X[def.col], -(G.TOP + (def.row - 1) * G.ROW_H))
	b.key = def.key

	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetTexture(Theme.texture.solid)
	b.bg:SetAllPoints(b)
	b.bar = b:CreateTexture(nil, "BORDER")
	b.bar:SetTexture(Theme.texture.solid)
	b.bar:SetWidth(2)
	b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	Theme:Tint(b.bar, "accent")
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(Theme.texture.solid)
	hl:SetAllPoints(b)
	hl:SetVertexColor(1, 1, 1, 0.05)

	-- The item's icon in a 1px frame of its quality's colour.
	b.edge = b:CreateTexture(nil, "BORDER")
	b.edge:SetTexture(Theme.texture.solid)
	b.edge:SetWidth(G.ICON + 2)
	b.edge:SetHeight(G.ICON + 2)
	b.edge:SetPoint("LEFT", b, "LEFT", 6, 0)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetWidth(G.ICON)
	b.icon:SetHeight(G.ICON)
	b.icon:SetPoint("CENTER", b.edge, "CENTER", 0, 0)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	b.name = H.Text(b, "body", 11, nil, 1)
	b.where = H.Text(b, "body", 10, "textDim", 1)
	b.later = H.Text(b, "body", 10, "gold", 1)
	b.gain = H.Text(b, "display", 13, "accentGlow")
	b.gain:SetJustifyH("RIGHT")
	b.gain:SetPoint("TOPRIGHT", b, "TOPRIGHT", -7, -5)
	b.chip = H.Text(b, "display", 9, "accent")
	b.chip:SetJustifyH("RIGHT")
	b.chip:SetPoint("TOPRIGHT", b.gain, "BOTTOMRIGHT", 0, -2)
	b.chip:SetText("YOUR PICK")

	b:SetScript("OnClick", function() GF:ToggleList(this.key) end)
	b:SetScript("OnEnter", function()
		local cell = this.cell
		if cell and cell.shown then
			H.ItemTip(this, cell.shown, table.getn(cell.entries) > 1
				and ("Click to see every upgrade for " .. cell.label) or nil)
		end
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

-- Name, where and "at level" stacked in the cell's height; two lines when
-- there is no level to wait for. Each line stops short of what is on its
-- right: the gain beside the name, the "your pick" tag beside where.
function H.Stack(b, three, nameRight, whereRight)
	local x = G.ICON + 14
	b.name:ClearAllPoints()
	b.where:ClearAllPoints()
	b.later:ClearAllPoints()
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", x, three and -3 or -8)
	b.name:SetPoint("RIGHT", b, "RIGHT", -nameRight, 0)
	b.where:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
	b.where:SetPoint("RIGHT", b, "RIGHT", -whereRight, 0)
	b.later:SetPoint("TOPLEFT", b.where, "BOTTOMLEFT", 0, -2)
end

-- How far in from the right a line has to stop for `fs` beside it.
function H.Room(fs, shown)
	if not shown then return 8 end
	return math.floor((fs:GetStringWidth() or 40) + 0.5) + 15
end

function H.PaintCell(b, cell, open, here)
	b.cell = cell
	Theme:Tint(b.bg, open and "tabbg" or "text", not open and 0.03 or nil)
	if open then b.bar:Show() else b.bar:Hide() end
	local e = cell.shown
	if e then
		local name, _, quality, _, _, _, _, _, texture = GetItemInfo(e.item)
		local r, g, bl = GetItemQualityColor(quality or 2)
		b.icon:SetTexture(texture)
		b.icon:SetVertexColor(1, 1, 1)
		b.icon:SetAlpha(1)
		b.edge:SetVertexColor(r, g, bl)
		b.edge:Show()
		b.name:SetText(name or ("item " .. e.id))
		b.name:SetTextColor(r, g, bl)
		b.where:SetText(GF.Where(e))
		-- An upgrade from the dungeon on the right says so in the accent.
		Theme:TextColor(b.where, here and "accentGlow" or "textDim")
		local later = e.level > (UnitLevel("player") or 1)
		b.later:SetText(later and ("at level " .. e.level) or "")
		b.gain:SetText(H.Gain(e))
		b.gain:Show()
		if cell.picked then b.chip:Show() else b.chip:Hide() end
		H.Stack(b, later, H.Room(b.gain, true), H.Room(b.chip, cell.picked))
	else
		local _, texture = GetInventorySlotInfo(cell.inv)
		b.icon:SetTexture(texture)
		b.icon:SetVertexColor(0.55, 0.55, 0.55)
		b.icon:SetAlpha(0.6)
		b.edge:Hide()
		b.name:SetText("No upgrade found")
		Theme:TextColor(b.name, "subtle")
		b.where:SetText(cell.label)
		Theme:TextColor(b.where, "subtle")
		b.later:SetText("")
		H.Stack(b, false, 8, 8)
		b.gain:Hide()
		b.chip:Hide()
	end
end

--[[ A slot's list ------------------------------------------------------------- ]]

function H.NewListRow(list, i)
	local row = CreateFrame("Button", nil, list)
	row:SetHeight(G.LIST_ROW)
	row:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -(G.LIST_HEAD + (i - 1) * G.LIST_ROW))
	row:SetPoint("RIGHT", list, "RIGHT", -1, 0)
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetTexture(Theme.texture.solid)
	row.bg:SetAllPoints(row)
	Theme:Tint(row.bg, "tabbg")
	row.bar = row:CreateTexture(nil, "BORDER")
	row.bar:SetTexture(Theme.texture.solid)
	row.bar:SetWidth(2)
	row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	Theme:Tint(row.bar, "accent")
	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(Theme.texture.solid)
	hl:SetAllPoints(row)
	hl:SetVertexColor(1, 1, 1, 0.05)
	row.edge = row:CreateTexture(nil, "BORDER")
	row.edge:SetTexture(Theme.texture.solid)
	row.edge:SetWidth(26)
	row.edge:SetHeight(26)
	row.edge:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(24)
	row.icon:SetHeight(24)
	row.icon:SetPoint("CENTER", row.edge, "CENTER", 0, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.name = H.Text(row, "body", 11, nil, 1)
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 42, -5)
	row.name:SetPoint("RIGHT", row, "RIGHT", -58, 0)
	row.where = H.Text(row, "body", 10, "textDim", 1)
	row.where:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
	row.where:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.gain = H.Text(row, "display", 12, "accentGlow")
	row.gain:SetJustifyH("RIGHT")
	row.gain:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -5)
	row.mark = H.Text(row, "body", 9, "accentGlow")
	row.mark:SetJustifyH("RIGHT")
	row.mark:SetPoint("TOPRIGHT", row.gain, "BOTTOMRIGHT", 0, -2)
	row:SetScript("OnClick", function()
		GF:Pick(this.key, this.entry and this.entry.id)
	end)
	row:SetScript("OnEnter", function() H.ItemTip(this, this.entry) end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:EnableMouseWheel(true)
	row:SetScript("OnMouseWheel", function() GF:ScrollList(arg1) end)
	return row
end

function H.NewList(body)
	local list = CreateFrame("Frame", nil, body)
	list:SetWidth(G.LIST_W)
	list:SetFrameLevel(body:GetFrameLevel() + 20)
	Theme:Panel(list, "panel2")
	list:EnableMouse(true)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function() GF:ScrollList(arg1) end)
	list:Hide()

	list.title = H.Text(list, "display", 12, "text")
	list.title:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -8)
	list.count = H.Text(list, "body", 10, "textDim")
	list.count:SetPoint("LEFT", list.title, "RIGHT", 8, 0)
	local close = Theme:GlyphButton(list, "close", 9, 18)
	close:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, -5)
	close:SetScript("OnClick", function() GF:ToggleList(nil) end)

	list.rows = {}
	for i = 1, G.LIST_ROWS do list.rows[i] = H.NewListRow(list, i) end

	list.hint = H.Text(list, "body", 10, "subtle")
	list.hint:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 10, 10)
	list.hint:SetText("Picks are kept for this character")
	list.clear = Theme:PanelButton(list, "Clear my pick", 92, 20)
	list.clear:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -6, 5)
	list.clear:SetScript("OnClick", function() GF:Pick(GF.ui.listKey, nil) end)
	return list
end

--- Open the list of cell `key` beside it, or close it if it is open; nil
--- closes whichever is open.
function GF:ToggleList(key)
	local ui = self.ui
	if not ui then return end
	if key == nil or ui.listKey == key then
		ui.listKey = nil
	else
		local cell
		for _, c in ipairs(self:Cells()) do if c.key == key then cell = c end end
		-- Nothing to choose from in an empty slot.
		if not cell or table.getn(cell.entries) == 0 then return end
		ui.listKey, ui.listOffset = key, 0
	end
	self:Paint()
end

function GF:ScrollList(delta)
	local ui = self.ui
	if not ui or not ui.listKey then return end
	ui.listOffset = math.max(0, (ui.listOffset or 0) - (delta or 0))
	self:Paint()
end

--- Make upgrade `id` cell `key`'s choice (nil: the biggest again). The
--- suggested dungeon goes back to the top of the new order.
function GF:Pick(key, id)
	if not key then return end
	self:SetPick(key, id)
	if self.ui then self.ui.listKey, self.ui.sugIndex = nil, 1 end
	self:Paint()
end

function H.PaintList(ui, cells)
	local list = ui.list
	local cell
	for _, c in ipairs(cells) do if c.key == ui.listKey then cell = c end end
	if not cell or table.getn(cell.entries) == 0 then
		ui.listKey = nil
		list:Hide()
		return
	end
	local entries = cell.entries
	local n = table.getn(entries)
	local shownRows = math.min(n, G.LIST_ROWS)
	ui.listOffset = math.min(ui.listOffset or 0, n - shownRows)
	list.title:SetText(string.upper(cell.label))
	list.count:SetText(n .. (n == 1 and " upgrade" or " upgrades") .. (n > G.LIST_ROWS and " \194\183 scroll for more" or ""))
	local level = UnitLevel("player") or 1
	for i, row in ipairs(list.rows) do
		local e = entries[i + ui.listOffset]
		if i <= shownRows and e then
			local name, _, quality, _, _, _, _, _, texture = GetItemInfo(e.item)
			local r, g, bl = GetItemQualityColor(quality or 2)
			row.key, row.entry = cell.key, e
			row.icon:SetTexture(texture)
			row.edge:SetVertexColor(r, g, bl)
			row.name:SetText(name or ("item " .. e.id))
			row.name:SetTextColor(r, g, bl)
			local where = GF.Where(e)
			if e.chance then where = where .. " \194\183 " .. e.chance .. "%" end
			if e.level > level then where = where .. " \194\183 at level " .. e.level end
			row.where:SetText(where)
			row.gain:SetText(H.Gain(e))
			local on = cell.shown and cell.shown.id == e.id
			if on then row.bg:Show(); row.bar:Show() else row.bg:Hide(); row.bar:Hide() end
			row.mark:SetText(on and (cell.picked and "Your pick" or "Biggest") or "")
			row.name:SetPoint("RIGHT", row, "RIGHT", -H.Room(row.gain, true), 0)
			row.where:SetPoint("RIGHT", row, "RIGHT", -H.Room(row.mark, on), 0)
			row:Show()
		else
			row.entry = nil
			row:Hide()
		end
	end
	if cell.picked then list.clear:Show() else list.clear:Hide() end
	local h = G.LIST_HEAD + shownRows * G.LIST_ROW + G.LIST_FOOT
	list:SetHeight(h)
	-- Beside the cell, over the other column; over the left one for the
	-- ranged cell. Kept inside the page.
	local def = cell
	local left = def.col == 1 and (G.COL_X[1] + G.CELL_W + 6) or (G.COL_X[def.col] - G.LIST_W - 6)
	local bodyH = ui.body:GetHeight()
	if not bodyH or bodyH <= 0 then bodyH = G.BODY_H end
	local top = math.max(4, math.min(G.TOP + (def.row - 1) * G.ROW_H - 3, bodyH - h - 4))
	list:ClearAllPoints()
	list:SetPoint("TOPLEFT", ui.body, "TOPLEFT", left, -top)
	list:Show()
end

--[[ The suggested dungeon ------------------------------------------------------- ]]

--- The guide for dungeon `name`, for your side: "Dungeons/The Deadmines
--- (17-24)", or nil if it has none.
function GF:DungeonGuide(name)
	local prefix = "Dungeons/" .. name
	for _, guide in ipairs(AegisPathfinder.guidelist or {}) do
		local rest = string.sub(guide, string.len(prefix) + 1)
		if string.sub(guide, 1, string.len(prefix)) == prefix
			and (string.sub(rest, 1, 2) == " (" or string.sub(rest, 1, 1) == ":") then
			return guide
		end
	end
end

function H.NewRight(body)
	local rp = CreateFrame("Frame", nil, body)
	rp:SetWidth(G.RIGHT_W)
	rp:SetHeight(7 * G.ROW_H - 4)
	rp:SetPoint("TOPLEFT", body, "TOPLEFT", G.COL_X[3], -G.TOP)
	Theme:NineSlice(rp, Theme.texture.panelFill, "BACKGROUND", "panel3")
	Theme:NineSlice(rp, Theme.texture.panelBorder, "BORDER", "border")

	-- The dungeon's loading screen, or the logo when there is none to suggest.
	rp.pic = AegisPathfinder.Pictures:Create(rp, G.PIC_W, G.PIC_H)
	rp.pic:SetPoint("TOPLEFT", rp, "TOPLEFT", 10, -10)

	-- The spec it scores for, shown either way: a spec with nothing to
	-- suggest is one you may want to switch back from.
	local scoring = H.Text(rp, "body", 11, "textDim")
	scoring:SetPoint("TOPLEFT", rp.pic, "BOTTOMLEFT", 0, -11)
	scoring:SetText("Scoring for")
	local IS = AegisPathfinder.ItemScore
	rp.spec = Theme:Dropdown(rp, 104, function(spec) IS:SetSpec(spec) end)
	rp.spec:SetHeight(22)
	rp.spec:SetPoint("TOPRIGHT", rp.pic, "BOTTOMRIGHT", 0, -6)
	local line = rp:CreateTexture(nil, "ARTWORK")
	line:SetTexture(Theme.texture.solid)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", rp.pic, "BOTTOMLEFT", 0, -34)
	line:SetPoint("TOPRIGHT", rp.pic, "BOTTOMRIGHT", 0, -34)
	Theme:Tint(line, "tabbg")

	-- The dungeon: name, how many upgrades, its guide.
	local d = CreateFrame("Frame", nil, rp)
	d:SetAllPoints(rp)
	rp.dungeon = d
	local label = H.Text(d, "display", 10, "textDim")
	label:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -7)
	label:SetText("SUGGESTED DUNGEON")
	rp.prev = Theme:GlyphButton(d, "chevronLeft", 10, 22)
	rp.prev:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -2, -6)
	rp.prev:SetScript("OnClick", function() GF:StepDungeon(-1) end)
	rp.next = Theme:GlyphButton(d, "chevronRight", 10, 22)
	rp.next:SetPoint("TOPRIGHT", line, "BOTTOMRIGHT", 2, -25)
	rp.next:SetScript("OnClick", function() GF:StepDungeon(1) end)
	rp.name = H.Text(d, "display", 15, "text", 1)
	rp.name:SetJustifyH("CENTER")
	rp.name:SetPoint("TOPLEFT", rp.prev, "TOPRIGHT", 2, 1)
	rp.name:SetPoint("RIGHT", rp.next, "LEFT", -2, 0)
	rp.levels = H.Text(d, "body", 10, "textDim", 1)
	rp.levels:SetJustifyH("CENTER")
	rp.levels:SetPoint("TOPLEFT", rp.name, "BOTTOMLEFT", 0, -2)
	rp.levels:SetPoint("RIGHT", rp.name, "RIGHT", 0, 0)
	rp.count = H.Text(d, "display", 13, "accentGlow", 1)
	rp.count:SetJustifyH("CENTER")
	rp.count:SetPoint("TOPLEFT", rp.levels, "BOTTOMLEFT", -24, -8)
	rp.count:SetPoint("RIGHT", rp.levels, "RIGHT", 24, 0)
	rp.slots = H.Text(d, "body", 10, "textDim", 2)
	rp.slots:SetJustifyH("CENTER")
	rp.slots:SetPoint("TOPLEFT", rp.count, "BOTTOMLEFT", 0, -3)
	rp.slots:SetPoint("RIGHT", rp.count, "RIGHT", 0, 0)
	rp.rank = H.Text(d, "body", 10, "subtle", 1)
	rp.rank:SetJustifyH("CENTER")
	rp.rank:SetPoint("TOPLEFT", rp.slots, "BOTTOMLEFT", 0, -3)
	rp.rank:SetPoint("RIGHT", rp.slots, "RIGHT", 0, 0)
	rp.guide = Theme:PanelButton(d, "Open the guide", G.PIC_W, 24)
	rp.guide:SetPoint("BOTTOM", rp, "BOTTOM", 0, 10)
	rp.guide:SetActive(true)
	rp.guide.__active = true
	rp.guide:SetScript("OnClick", function()
		if not this.guideName then return end
		AegisPathfinder:OpenGuideTab(this.guideName)
		if AegisPathfinder.objectiveframe then AegisPathfinder.objectiveframe:Show() end
	end)

	-- Nothing to suggest: why, where the dungeon would be.
	local e = CreateFrame("Frame", nil, rp)
	e:SetAllPoints(rp)
	rp.empty = e
	rp.emptyTitle = H.Text(e, "display", 15, "text")
	rp.emptyTitle:SetJustifyH("CENTER")
	rp.emptyTitle:SetPoint("TOP", line, "BOTTOM", 0, -24)
	rp.emptyText = Theme:FinePrint(e, G.PIC_W - 10)
	rp.emptyText:SetJustifyH("CENTER")
	rp.emptyText:SetPoint("TOP", rp.emptyTitle, "BOTTOM", 0, -6)
	return rp
end

function GF:StepDungeon(by)
	local ui = self.ui
	if not ui then return end
	ui.sugIndex = (ui.sugIndex or 1) + by
	self:Paint()
end

function H.PaintRight(ui, ranked, any, nothing)
	local rp = ui.right
	local n = table.getn(ranked)
	local cur = ranked[ui.sugIndex]
	local IS = AegisPathfinder.ItemScore
	local items = {}
	for _, spec in ipairs(IS:Specs()) do table.insert(items, { value = spec, label = IS:SpecLabel(spec) }) end
	rp.spec:SetItems(items)
	rp.spec:SetValue((IS:Spec()))
	rp.pic:SetDungeon(cur and cur.name)
	if cur then
		rp.dungeon:Show()
		rp.empty:Hide()
		rp.name:SetText(cur.name)
		rp.levels:SetText(cur.lo and ((cur.kind == "raid" and "Raid, level " or "Levels ") .. cur.lo
			.. (cur.hi and cur.hi ~= cur.lo and ("\226\128\147" .. cur.hi) or "")) or "")
		rp.count:SetText(cur.n .. (cur.n == 1 and " upgrade here" or " upgrades here"))
		rp.slots:SetText(table.concat(cur.slots, ", "))
		rp.rank:SetText(ui.sugIndex .. " of " .. n .. (n == 1 and " dungeon with upgrades" or " dungeons with upgrades"))
		if n > 1 then rp.prev:Show(); rp.next:Show() else rp.prev:Hide(); rp.next:Hide() end
		local guide = GF:DungeonGuide(cur.name)
		rp.guide.guideName = guide
		if guide then rp.guide:Show() else rp.guide:Hide() end
	else
		rp.dungeon:Hide()
		rp.empty:Show()
		if any then
			rp.emptyTitle:SetText("No dungeon to suggest")
			rp.emptyText:SetText("Every upgrade found comes from a quest, a vendor or crafting.")
		else
			rp.emptyTitle:SetText(GF.Settings().enabled and "Nothing to upgrade" or "Switched off")
			rp.emptyText:SetText(nothing)
		end
	end
end

--[[ The page -------------------------------------------------------------------- ]]

function GF:BuildPage()
	local page = self.panel
	Theme:Panel(page, "panel")
	local ui = {}

	local header = Theme:Header(page, G.HEADER)
	header.wordmark:Hide()
	local title = H.Text(header, "display", 14, "text")
	title:SetPoint("LEFT", header, "LEFT", 12, 0)
	title:SetText("GEAR FINDER")
	ui.sub = H.Text(header, "body", 11, "textDim")
	ui.sub:SetPoint("LEFT", title, "RIGHT", 10, 0)
	local close = Theme:ChipButton(header, "close")
	close:SetPoint("RIGHT", header, "RIGHT", -8, 0)
	close:SetScript("OnClick", function() HideUIPanel(CharacterFrame) end)

	local footer = CreateFrame("Frame", nil, page)
	footer:SetHeight(G.FOOTER)
	footer:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 1, 1)
	footer:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -1, 1)
	Theme:CapStrip(footer, "panel2", "bottom")
	ui.status = H.Text(footer, "body", 10, "textDim", 1)
	ui.status:SetPoint("LEFT", footer, "LEFT", 12, 0)
	ui.status:SetPoint("RIGHT", footer, "RIGHT", -34, 0)
	local cog = Theme:GlyphButton(footer, "gear", 12, 22)
	cog:SetPoint("RIGHT", footer, "RIGHT", -6, 0)
	cog:SetScript("OnClick", function()
		local A = AegisPathfinder
		if not A.optionsframe then A:CreateConfigPanel() end
		A.optionsframe:Show()
		A:ShowConfigPage("Gear")
	end)
	cog:SetScript("OnEnter", function()
		Theme:Tint(this.glyph, "accent")
		Theme:ShowTip(this, "TOP", "Gear options", { "Upgrade sources, and what else it looks at" })
	end)
	cog:SetScript("OnLeave", function()
		Theme:Tint(this.glyph, "textDim")
		Theme:HideTip(this)
	end)
	ui.cog = cog

	local body = CreateFrame("Frame", nil, page)
	body:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -G.HEADER)
	body:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, G.FOOTER)
	ui.body = body

	ui.cells = {}
	for i, def in ipairs(GF.CELLS) do ui.cells[i] = H.NewCell(body, def) end
	ui.right = H.NewRight(body)
	ui.list = H.NewList(body)
	ui.sugIndex = 1
	self.ui = ui
end

function GF:Paint()
	local ui = self.ui
	if not ui or not self:Showing() then return end
	local cells = self:Cells()
	local ranked = self:Suggest(cells)
	local n = table.getn(ranked)
	-- The arrows go round.
	if n > 0 then ui.sugIndex = math.mod(math.mod((ui.sugIndex or 1) - 1, n) + n, n) + 1 end
	local cur = ranked[ui.sugIndex]
	local any = false
	for i, cell in ipairs(cells) do
		if cell.shown then any = true end
		H.PaintCell(ui.cells[i], cell, ui.listKey == cell.key,
			cur and cell.shown and cell.shown.code == cur.code)
	end
	local status, nothing = self:Status()
	H.PaintRight(ui, ranked, any, nothing)
	H.PaintList(ui, cells)
	ui.status:SetText(status)
	local _, class = UnitClass("player")
	ui.sub:SetText(string.format("Level %d %s %s", UnitLevel("player") or 1, UnitRace("player") or "",
		UnitClass("player") or class or ""))
end

--[[ On the character panel ----------------------------------------------------- ]]

if CharacterFrame then
	local id = FreeTab()
	local page = CreateFrame("Frame", G.PAGE, CharacterFrame)
	page:SetID(id)
	page:SetWidth(G.W)
	page:EnableMouse(true)
	page:Hide()
	GF.panel = page
	-- Dragging the page moves the character panel, which it hangs from, as
	-- pfUI lets you drag the panel's other pages; without pfUI the client
	-- puts the panel back where its panels go the next time it opens.
	page:RegisterForDrag("LeftButton")
	page:SetScript("OnDragStart", function()
		CharacterFrame:SetMovable(true)
		CharacterFrame:StartMoving()
	end)
	page:SetScript("OnDragStop", function() CharacterFrame:StopMovingOrSizing() end)
	page:SetScript("OnShow", function()
		GF:AnchorPage()
		GF:PlaceTab()
		if not GF.ui then GF:BuildPage() end
		GF.ui.listKey, GF.ui.sugIndex = nil, 1
		-- pfUI turns the mouse off on the panel's pages, for its own
		-- dragging; this one drags itself, and has buttons.
		page:EnableMouse(true)
		-- The panel's own close button sits over the page's header, which
		-- has its own; back when the page goes, unless something else hid it.
		local close = CharacterFrameCloseButton
		if close and close:IsShown() then
			close:Hide()
			GF.hidClose = true
		end
		GF:Refresh()
	end)
	page:SetScript("OnHide", function()
		if GF.ui then GF.ui.listKey = nil end
		if GF.hidClose then
			CharacterFrameCloseButton:Show()
			GF.hidClose = nil
		end
		-- Let go of the panel if it closes mid-drag.
		CharacterFrame:StopMovingOrSizing()
		GameTooltip:Hide()
	end)

	local tab = CreateFrame("Button", "CharacterFrameTab" .. id, CharacterFrame, "CharacterFrameTabButtonTemplate")
	tab:SetID(id)
	tab:SetText("Gear Finder")
	tab:SetScript("OnClick", function()
		ToggleCharacter(G.PAGE)
		PlaySound("igCharacterInfoTab")
	end)
	tab:SetScript("OnEnter", function()
		Theme:ShowTip(this, "TOP", "Gear Finder",
			{ "Upgrades in the dungeons at your level, and where to run for most of them" })
	end)
	tab:SetScript("OnLeave", function() Theme:HideTip(this) end)
	GF.tab = tab

	-- One of the character panel's pages, which ToggleCharacter swaps and
	-- PanelTemplates marks the tab of.
	table.insert(CHARACTERFRAME_SUBFRAMES, G.PAGE)
	PanelTemplates_SetNumTabs(CharacterFrame, id)

	-- The tab goes after the last tab shown, which changes as the Pet tab
	-- comes and goes; and the panel may be reskinned after this file loads.
	local onShow = CharacterFrame:GetScript("OnShow")
	CharacterFrame:SetScript("OnShow", function()
		if onShow then onShow() end
		GF:PlaceTab()
	end)
	if PetTab_Update then
		local petTab = PetTab_Update
		PetTab_Update = function()
			petTab()
			GF:PlaceTab()
		end
	end
	GF:PlaceTab()
end
