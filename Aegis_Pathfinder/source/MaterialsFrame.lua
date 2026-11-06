--[[
	MaterialsFrame.lua -- the shopping list, and sending it to Aegis: Exchange.

	The reference document the profession guides came from prints one shopping
	list per profession, totalled from skill 1. That is the wrong number for
	anyone who is already part-way through: it counts reagents for crafts you
	have done.

	This totals the reagents the *remaining* steps call for, from wherever you
	currently are, which is the number you actually want standing at the
	auction house -- or just the craft you are on, whichever the tab at the
	top says. Beside each is what your bags already hold. The arithmetic is
	in Professions.lua; this shows it.

	It pops out beside the guide panel until you drag it somewhere of your own.

	Beside it, Cheapest route opens the crafting route window: the same
	profession planned again at today's prices (CraftRouteFrame.lua).

	With Aegis: Exchange loaded, one button puts the same list on Exchange's
	Crafting tab -- one project per craft still ahead -- where its shopping
	list prices every line at the auction house. From then on it is kept in
	step: finish a craft and it leaves Exchange too.

	It works for any guide carrying |MATS| tags, not only profession guides --
	there is nothing profession-specific in the panel itself.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local WIDTH = 280
local PAD = 12
local ROW_H = 16
local MAX_ROWS = 14         -- more than this and the list scrolls
local MIN_ROWS = 3          -- fewer, and the window still looks like a list
local TAB_H = 20
local BUTTON_H = 22
local SCROLL_W = 10

-- Header plus subhead, the concept's chrome on every window.
local CHROME_TOP = 30 + 18
local TABS_TOP = CHROME_TOP + 8
local SUMMARY_TOP = TABS_TOP + TAB_H + 8
local LIST_TOP = SUMMARY_TOP + 14 + 9
local FOOT_H = BUTTON_H + PAD * 2

-- How often a burst of bag updates may repaint the counts.
local BAG_THROTTLE = 0.25

local SCOPES = { "step", "route" }
local SCOPE_LABEL = { step = "This step", route = "Whole route" }

local rows = {}
local offset = 0

local function Scope()
	local profile = AegisPathfinder.db and AegisPathfinder.db.profile
	return profile and profile.shoppingscope == "step" and "step" or "route"
end

function AegisPathfinder:CreateMaterialsPanel()
	local frame = CreateFrame("Frame", "AegisPathfinderMaterials", UIParent)
	self.materialsframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(WIDTH)
	frame:SetHeight(LIST_TOP + MAX_ROWS * ROW_H + FOOT_H)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	Theme:Panel(frame, "panel")
	frame:Hide()

	Theme:Chrome(frame, "Shopping list", Theme:PositionSaver("materialsframe"))

	-- The two scopes, as the branch modal's tabs.
	frame.tabs = {}
	local tabW = (WIDTH - PAD * 2 - 4) / 2
	for i, scope in ipairs(SCOPES) do
		local tab = Theme:Tab(frame, SCOPE_LABEL[scope], tabW, TAB_H)
		tab:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (i - 1) * (tabW + 4), -TABS_TOP)
		tab.scope = scope
		tab:SetScript("OnClick", function()
			AegisPathfinder.db.profile.shoppingscope = this.scope
			offset = 0
			AegisPathfinder:UpdateMaterialsPanel()
		end)
		frame.tabs[scope] = tab
	end

	local subtitle = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(subtitle, "body", 10)
	subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -SUMMARY_TOP)
	subtitle:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	subtitle:SetHeight(12)
	subtitle:SetJustifyH("LEFT")
	Theme:TextColor(subtitle, "textDim")
	frame.subtitle = subtitle

	Theme:Divider(frame, subtitle, "BOTTOMLEFT", 0, -6)

	for i = 1, MAX_ROWS do
		local row = CreateFrame("Frame", nil, frame)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(LIST_TOP + (i - 1) * ROW_H))
		row:SetPoint("RIGHT", frame, "RIGHT", -PAD - SCROLL_W - 6, 0)

		-- Have / need: "12/40". Wide enough for "999/999".
		local qty = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(qty, "display", 11)
		qty:SetPoint("LEFT", row, "LEFT", 0, 0)
		qty:SetWidth(54)
		qty:SetJustifyH("RIGHT")

		local name = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(name, "body", 11)
		name:SetPoint("LEFT", qty, "RIGHT", 8, 0)
		name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		name:SetJustifyH("LEFT")

		row.qty, row.name = qty, name
		rows[i] = row
	end

	-- The theme's scroll bar, not UIPanelScrollBarTemplate's Blizzard art.
	local slider = Theme:ScrollBar(frame, SCROLL_W)
	slider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(LIST_TOP + SCROLL_W))
	slider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, FOOT_H + SCROLL_W)
	slider:SetMinMaxValues(0, 0)
	slider:SetValueStep(1)
	slider:SetValue(0)
	slider:SetScript("OnValueChanged", function()
		if slider.updating then return end
		offset = math.floor(arg1 or slider:GetValue() or 0)
		AegisPathfinder:UpdateMaterialsPanel()
	end)
	frame.slider = slider

	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function() slider:Nudge(-(arg1 or 0)) end)

	-- Sending the list to Aegis: Exchange, or taking it back out.
	local half = (WIDTH - PAD * 2 - 6) / 2
	local exchange = Theme:PanelButton(frame, "Send to Exchange", half, BUTTON_H)
	exchange:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
	exchange:SetScript("OnClick", function() AegisPathfinder:ToggleExchange() end)
	local enter, leave = exchange:GetScript("OnEnter"), exchange:GetScript("OnLeave")
	exchange:SetScript("OnEnter", function()
		enter()
		Theme:ShowTip(this, "BOTTOM", AegisPathfinder:ExchangeHint())
	end)
	exchange:SetScript("OnLeave", function()
		leave()
		Theme:HideTip(this)
	end)
	frame.exchange = exchange

	-- The same profession, planned at today's prices (CraftRouteFrame.lua).
	local cheapest = Theme:PanelButton(frame, "Cheapest route", half, BUTTON_H)
	cheapest:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
	cheapest:SetScript("OnClick", function() AegisPathfinder:ToggleCraftRoutePanel() end)
	local center, cleave = cheapest:GetScript("OnEnter"), cheapest:GetScript("OnLeave")
	cheapest:SetScript("OnEnter", function()
		center()
		Theme:ShowTip(this, "BOTTOM", "The cheapest way to 300 at today's prices", {
			"Plans the route again from auction and merchant prices, and can load it as a guide.",
		})
	end)
	cheapest:SetScript("OnLeave", function()
		cleave()
		Theme:HideTip(this)
	end)
	frame.cheapest = cheapest

	--[[ Counts follow the bags. BAG_UPDATE comes in bursts -- a stack
		split, a loot, a trade -- so the event only marks the list stale and
		the repaint happens at most every BAG_THROTTLE seconds, and only
		while the window is open. ]]
	frame:RegisterEvent("BAG_UPDATE")
	frame:SetScript("OnEvent", function() this.dirty = true end)
	frame:SetScript("OnUpdate", function()
		if not this.dirty then return end
		local now = GetTime()
		if this.painted and now - this.painted < BAG_THROTTLE then return end
		AegisPathfinder:UpdateMaterialsPanel()
	end)

	frame:SetScript("OnShow", function()
		offset = 0
		-- Beside the guide, unless the player has dragged it somewhere.
		local guide = AegisPathfinder.objectiveframe
		if not Theme:RestorePosition(this, "materialsframe") and guide and AegisPathfinder.GetQuadrant then
			local _, _, hhalf = AegisPathfinder.GetQuadrant(guide)
			this:ClearAllPoints()
			if hhalf == "LEFT" then
				this:SetPoint("TOPLEFT", guide, "TOPRIGHT", 8, 0)
			else
				this:SetPoint("TOPRIGHT", guide, "TOPLEFT", -8, 0)
			end
		end
		AegisPathfinder:UpdateMaterialsPanel()
	end)

	table.insert(UISpecialFrames, "AegisPathfinderMaterials")
end

--- Alphabetical: this is a list you read while looking for one item, not a
--- ranking. Quantity-ordered would bury Peacebloom under Dreamfoil, and a
--- list sorted by what is still short would move lines under the cursor as
--- you buy.
local function ByName(a, b)
	return a.item < b.item
end

local function ClearRows()
	for _, row in ipairs(rows) do
		row.qty:SetText("")
		row.name:SetText("")
		row:Hide()
	end
end

-- Fit the window to `count` rows: a three-reagent craft is a small card, not
-- a tall empty panel.
local function FitRows(frame, count)
	local shown = math.max(MIN_ROWS, math.min(MAX_ROWS, count))
	frame:SetHeight(LIST_TOP + shown * ROW_H + 6 + FOOT_H)
	return shown
end

function AegisPathfinder:UpdateMaterialsPanel()
	local frame = self.materialsframe
	if not frame or not frame:IsVisible() then return end
	frame.dirty = nil
	frame.painted = GetTime()

	local scope = Scope()
	for s, tab in pairs(frame.tabs) do tab:SetActive(s == scope) end
	self:PaintExchangeButton()

	local list, step = self:GetShoppingList(scope)

	if not list then
		if scope == "step" and self:GuideHasMaterials() then
			frame.subtitle:SetText("No crafting left in this guide.")
		else
			frame.subtitle:SetText("This guide lists no materials.")
		end
		ClearRows()
		FitRows(frame, 0)
		frame.slider:Hide()
		return
	end

	table.sort(list, ByName)

	local total, short = table.getn(list), 0
	for _, entry in ipairs(list) do
		if entry.have < entry.need then short = short + 1 end
	end

	local what
	if scope == "step" then
		local _, title = self:GetObjectiveInfo(step)
		what = title or "This step"
	else
		what = self.db.char.currentguide or "This guide"
	end
	if short == 0 then
		frame.subtitle:SetText(string.format("%s \194\183 all %d in your bags", what, total))
	else
		frame.subtitle:SetText(string.format("%s \194\183 %d of %d still to get", what, short, total))
	end

	local shown = FitRows(frame, total)
	local maxOffset = math.max(0, total - shown)
	if offset > maxOffset then offset = maxOffset end
	if offset < 0 then offset = 0 end

	if maxOffset > 0 then
		frame.slider:Show()
		frame.slider.updating = true
		frame.slider:SetMinMaxValues(0, maxOffset)
		frame.slider:SetValue(offset)
		frame.slider.updating = nil
	else
		frame.slider:Hide()
	end

	for i, row in ipairs(rows) do
		local entry = i <= shown and list[i + offset]
		if entry then
			row:Show()
			row.qty:SetText(string.format("%d/%d", math.min(entry.have, entry.need), entry.need))
			row.name:SetText(entry.item)
			-- Gold for what is still to get; covered lines step back.
			if entry.have >= entry.need then
				Theme:TextColor(row.qty, "accent")
				Theme:TextColor(row.name, "textDim")
			else
				Theme:TextColor(row.qty, "gold")
				Theme:TextColor(row.name, "text")
			end
		else
			row.qty:SetText("")
			row.name:SetText("")
			row:Hide()
		end
	end
end

function AegisPathfinder:ToggleMaterialsPanel()
	if not self.materialsframe then
		self:CreateMaterialsPanel()
	end

	if self.materialsframe:IsShown() then
		self.materialsframe:Hide()
	else
		self.materialsframe:Show()
	end
end

--[[ Aegis: Exchange.

	Exchange keeps crafting projects -- { name, itemId, made, want, reagents }
	-- and builds its shopping list from all of them, priced at the auction
	house and against what you carry. Its public calls are used and nothing
	else: craft.Projects, craft.AddProject and craft.DeleteProject.

	Projects sent from here carry `pathfinder` (the guide's name), which is
	how they are found again to update or take back out; projects you
	captured in Exchange yourself are never touched. If one of ours has the
	same name as one of yours, Exchange keeps one project per name, so yours
	is held inside ours as `replaced` and put back when ours goes.
]]

local function ExchangeCraft()
	local x = AegisExchange
	local craft = x and x.craft
	if craft and craft.Projects and craft.AddProject and craft.DeleteProject then
		return craft, x
	end
end

--- "missing" (Exchange is not loaded), "demo" (its demo mode is on, which
--- shows made-up projects in place of the saved ones) or "ready".
function AegisPathfinder:ExchangeState()
	local craft, x = ExchangeCraft()
	if not craft then return "missing" end
	if x.db and x.db.demo then return "demo" end
	return "ready"
end

--- True when this guide's list is on Exchange's Crafting tab.
function AegisPathfinder:IsInExchange()
	local guide = self.db and self.db.char.currentguide
	return guide ~= nil and self.db.char.exchangeguide == guide
end

local function Repaint()
	local ui = AegisExchange and AegisExchange.ui
	-- Exchange's own repaint; if it has changed shape, its tab catches up
	-- the next time it paints itself, which is no reason to error here.
	if ui and ui.RefreshCraft then pcall(ui.RefreshCraft) end
end

-- Take out every project sent from here, and put back any of the player's
-- own that one of them stood in for. Returns how many were taken out.
local function RemoveOurs(craft)
	local list, restore, removed = craft.Projects(), {}, 0
	for i = table.getn(list), 1, -1 do
		local p = list[i]
		if p.pathfinder then
			craft.DeleteProject(i)
			removed = removed + 1
			if p.replaced then table.insert(restore, p.replaced) end
		end
	end
	for _, p in ipairs(restore) do craft.AddProject(p) end
	return removed
end

-- What makes one set of projects different from another, so an unchanged
-- list is not rewritten on every step update.
local function Signature(projects)
	local parts = {}
	for _, p in ipairs(projects) do
		local r = {}
		for _, x in ipairs(p.reagents) do table.insert(r, x.count .. "x" .. x.name) end
		table.insert(parts, p.want .. " " .. p.name .. ": " .. table.concat(r, ","))
	end
	return table.concat(parts, "; ")
end

local lastSignature

-- Write `projects` to Exchange in place of whatever was sent before. Returns
-- how many were written, or nil if Exchange would not take them.
local function WriteOurs(craft, projects, guide)
	RemoveOurs(craft)

	-- Backwards, because each goes in at the top: the route's next craft
	-- should be the first thing on Exchange's list.
	for i = table.getn(projects), 1, -1 do
		local p = projects[i]
		p.pathfinder = guide

		for _, mine in ipairs(craft.Projects()) do
			if mine.name == p.name and not mine.pathfinder then
				p.replaced = mine
				-- A recipe captured from the profession window carries exact
				-- item ids; better those than a lookup by name.
				p.itemId = mine.itemId or p.itemId
				for _, r in ipairs(p.reagents) do
					for _, theirs in ipairs(mine.reagents or {}) do
						if theirs.name == r.name and theirs.itemId then r.itemId = theirs.itemId end
					end
				end
				break
			end
		end

		if not craft.AddProject(p) then return nil end
	end
	return table.getn(projects)
end

--- Bring Exchange in line with the guide, if this guide's list was sent.
--- `force` rewrites it even if nothing seems to have changed.
function AegisPathfinder:SyncExchange(force)
	if not self:IsInExchange() or self:ExchangeState() ~= "ready" then return end
	local craft = ExchangeCraft()

	local projects = self:GetRemainingCrafts()
	if not projects then
		-- The route is done: nothing left to shop for.
		RemoveOurs(craft)
		self.db.char.exchangeguide, lastSignature = nil, nil
		Repaint()
		return 0
	end

	local signature = Signature(projects)
	if not force and signature == lastSignature then return end

	local written = WriteOurs(craft, projects, self.db.char.currentguide)
	lastSignature = written and signature or nil
	Repaint()
	return written, projects
end

--- Put the current guide's remaining crafts on Exchange's Crafting tab.
function AegisPathfinder:SendShoppingListToExchange()
	local state = self:ExchangeState()
	if state == "missing" then
		self:Print("Aegis: Exchange isn't loaded, so there is nowhere to send the list.")
		return false
	elseif state == "demo" then
		self:Print("Aegis: Exchange is in demo mode. Turn demo mode off to send it your list.")
		return false
	end

	local guide = self.db.char.currentguide
	if not guide or not self:GetRemainingCrafts() then
		self:Print("Nothing left to craft in this guide, so there is nothing to send.")
		return false
	end

	self.db.char.exchangeguide = guide
	local written, projects = self:SyncExchange(true)
	if not written then
		self.db.char.exchangeguide = nil
		self:Print("Aegis: Exchange wouldn't take the list. Open it once so it can load its data, then try again.")
		return false
	end

	local unknown = 0
	for _, p in ipairs(projects) do
		for _, r in ipairs(p.reagents) do
			if not r.itemId then unknown = unknown + 1 end
		end
	end

	self:Print(string.format("Sent %d craft%s from %s to Aegis: Exchange. Its Crafting tab prices the list at the auction house, and it will follow your progress.",
		written, written == 1 and "" or "s", guide))
	if unknown > 0 then
		self:Print(string.format("%d reagent%s could not be matched to an item yet; Exchange lists them once it has seen them.",
			unknown, unknown == 1 and "" or "s"))
	end
	self:UpdateMaterialsPanel()
	return true
end

--- Take the list back out of Exchange.
function AegisPathfinder:RemoveShoppingListFromExchange()
	local craft = ExchangeCraft()
	local removed = 0
	-- Demo mode shows Exchange's made-up list in place of the saved one, so
	-- there is nothing of ours to find in it until it is turned off.
	if craft and self:ExchangeState() == "ready" then removed = RemoveOurs(craft) end
	self.db.char.exchangeguide, lastSignature = nil, nil
	Repaint()
	self:Print(string.format("Took %d craft%s back out of Aegis: Exchange.", removed, removed == 1 and "" or "s"))
	self:UpdateMaterialsPanel()
	return removed
end

--- The shopping list's button, and /apg exchange.
function AegisPathfinder:ToggleExchange()
	if self:IsInExchange() then
		return self:RemoveShoppingListFromExchange()
	end
	return self:SendShoppingListToExchange()
end

--- What the button would do, for its tooltip: the hint, and detail lines.
function AegisPathfinder:ExchangeHint()
	local state = self:ExchangeState()
	if state == "missing" then
		return "Aegis: Exchange isn't loaded", {
			"With it, this list goes to its Crafting tab, priced at the auction house.",
		}
	elseif state == "demo" then
		return "Aegis: Exchange is in demo mode", { "Turn demo mode off to send it your list." }
	elseif self:IsInExchange() then
		return "On Aegis: Exchange's Crafting tab", {
			"Kept in step as you craft. Click to take it back out.",
		}
	end
	return "Send to Aegis: Exchange", {
		"Adds each craft still ahead to its Crafting tab, where the shopping list is priced at the auction house.",
	}
end

function AegisPathfinder:PaintExchangeButton()
	local b = self.materialsframe and self.materialsframe.exchange
	if not b then return end
	b:SetText(self:IsInExchange() and "Remove from Exchange" or "Send to Exchange")
end

--[[ Keeping up with the guide.

	Called whenever the current step settles. Step updates arrive in bursts
	(a turn-in fires several events), so this only marks the list stale; one
	OnUpdate later the open window repaints and Exchange is brought in line,
	once.
]]
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
	this:Hide()
	local frame = AegisPathfinder.materialsframe
	if frame and frame:IsVisible() then AegisPathfinder:UpdateMaterialsPanel() end
	AegisPathfinder:SyncExchange()
end)
AegisPathfinder.shoppingDriver = driver

function AegisPathfinder:RefreshShoppingList()
	driver:Show()
end
