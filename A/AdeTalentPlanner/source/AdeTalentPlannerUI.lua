--[[
	AdeTalentPlanner - window
	Replaces the default talent frame (talent key and micro button open this one).
]]

ATPUI = {}
local UI = ATPUI
local ATP = ATP
local getn = table.getn

local TREE_W, TREE_H = 300, 350
local BTN = 32
local OFFX, OFFY = 44, 30
local COL_STEP, TIER_STEP = 64, 46
local HEADER_H = 92
local FOOTER_H = 34
local TREE_GAP = 6

local BRANCH_TEX = "Interface\\TalentFrame\\UI-TalentBranches"
local ARROW_TEX = "Interface\\TalentFrame\\UI-TalentArrows"
local V_COORDS = { [1] = { 0.12890625, 0.25390625, 0, 0.484375 }, [-1] = { 0.12890625, 0.25390625, 0.515625, 1.0 } }
local H_COORDS = { [1] = { 0.2578125, 0.3828125, 0, 0.5 }, [-1] = { 0.2578125, 0.3828125, 0.5, 1.0 } }
local A_COORDS = {
	top = { [1] = { 0, 0.5, 0, 0.5 }, [-1] = { 0, 0.5, 0.5, 1.0 } },
	right = { [1] = { 1.0, 0.5, 0, 0.5 }, [-1] = { 1.0, 0.5, 0.5, 1.0 } },
	left = { [1] = { 0.5, 1.0, 0, 0.5 }, [-1] = { 0.5, 1.0, 0.5, 1.0 } },
}

local CYAN = "|cff00ffff"
local GOLD = "|cffffd100"
local GREY = "|cff808080"

UI.trees = {}
UI.mode = "learn"

-------------------------------------------------------------------------------
-- look: "blizz" (default art) or "pfui" (pfUI skin, used when pfUI is loaded)
-------------------------------------------------------------------------------
local function PfuiAvailable()
	return (pfUI and pfUI.api and pfUI.api.CreateBackdrop and pfUI.api.SkinButton) and true or false
end
UI.PfuiAvailable = PfuiAvailable

-- settings.style: nil = automatic, "blizz", "pfui"
function UI:WantedStyle()
	local s = ATP.db.settings.style
	if s == "blizz" then return "blizz" end
	if PfuiAvailable() then return "pfui" end
	return "blizz"
end

local function Try(f, a1, a2, a3, a4, a5)
	if type(f) ~= "function" then return false end
	return pcall(f, a1, a2, a3, a4, a5)
end

function UI:SkinButton(b)
	if self.style == "pfui" then Try(pfUI.api.SkinButton, b) end
end

function UI:SkinFont(fs, delta)
	if self.style ~= "pfui" or not pfUI.font_default then return end
	local size = 12
	if pfUI_config and pfUI_config.global and tonumber(pfUI_config.global.font_size) then
		size = tonumber(pfUI_config.global.font_size)
	end
	fs:SetFont(pfUI.font_default, size + (delta or 0), "OUTLINE")
end

-- border colour of a talent: r == nil means "not available"
function UI:SetTalentColor(b, r, g, bl)
	if self.style == "pfui" and b.backdrop then
		if r then
			b.backdrop:SetBackdropBorderColor(r, g, bl, 1)
		else
			b.backdrop:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
		end
	else
		b.slot:SetVertexColor(r or 0.5, g or 0.5, bl or 0.5)
	end
end

-------------------------------------------------------------------------------
-- helpers
-------------------------------------------------------------------------------
local btnCount = 0
local function MakeButton(parent, text, w, tip, onClick)
	btnCount = btnCount + 1
	local b = CreateFrame("Button", "ATPButton" .. btnCount, parent, "UIPanelButtonTemplate")
	b:SetWidth(w)
	b:SetHeight(22)
	b:SetText(text)
	b.tip = tip
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function()
		if this.tip then
			GameTooltip:SetOwner(this, "ANCHOR_TOP")
			GameTooltip:SetText(this.tip, 1, 1, 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	UI:SkinButton(b)
	return b
end

local function BtnXY(tier, col)
	return OFFX + (col - 1) * COL_STEP, -(OFFY + (tier - 1) * TIER_STEP)
end

function UI:CurrentClass()
	if self.linked then return self.linked.class end
	return self.viewClass or ATP.playerClass
end

function UI:CurrentTree()
	local class = self:CurrentClass()
	return class, ATP:GetTree(class)
end

function UI:IsOwnView()
	return self:CurrentClass() == ATP.playerClass
end

-- "learn" only when looking at your own class and not at a linked build
function UI:Mode()
	if self.linked or not self:IsOwnView() then return "plan" end
	return self.mode
end

function UI:LearnedRanks()
	local r = {}
	local n = GetNumTalentTabs() or 0
	for t = 1, n do
		r[t] = {}
		for i = 1, (GetNumTalents(t) or 0) do
			local _, _, _, _, rank = GetTalentInfo(t, i)
			if rank and rank > 0 then r[t][i] = rank end
		end
	end
	return r
end

-------------------------------------------------------------------------------
-- popups
-------------------------------------------------------------------------------
StaticPopupDialogs["ATP_NAME"] = {
	text = "%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 40,
	OnShow = function()
		local eb = getglobal(this:GetName() .. "EditBox")
		eb:SetText(UI.popupDefault or "")
		eb:SetFocus()
		eb:HighlightText()
	end,
	OnAccept = function()
		local eb = getglobal(this:GetParent():GetName() .. "EditBox")
		if UI.popupAction then UI.popupAction(eb:GetText()) end
	end,
	EditBoxOnEnterPressed = function()
		if UI.popupAction then UI.popupAction(this:GetText()) end
		this:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

StaticPopupDialogs["ATP_CONFIRM"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function() if UI.confirmAction then UI.confirmAction() end end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

function UI:AskName(question, default, action)
	self.popupDefault = default
	self.popupAction = action
	StaticPopup_Show("ATP_NAME", question)
end

function UI:Confirm(question, action)
	self.confirmAction = action
	StaticPopup_Show("ATP_CONFIRM", question)
end

-------------------------------------------------------------------------------
-- build selection
-------------------------------------------------------------------------------
function UI:SelectBuild()
	local class = self.viewClass
	local list = ATP:GetBuilds(class)
	self.buildList = list
	local selId = ATP.char.sel[class]
	local b
	for _, x in ipairs(list) do
		if x.id == selId then b = x end
	end
	if not b then b = list[1] end
	self.build = b
	if b then ATP.char.sel[class] = b.id end
	self.ranks = (b and ATP.Decode(b.code)) or {}
	local tree = ATP:GetTree(class)
	if tree then ATP.Clamp(tree, self.ranks) end
end

function UI:SetBuild(b)
	if not b then return end
	ATP.char.sel[b.class] = b.id
	self:SelectBuild()
	self:Refresh()
end

function UI:StepBuild(dir)
	local list = self.buildList or {}
	local n = getn(list)
	if n == 0 then return end
	local pos = 0
	for k, b in ipairs(list) do
		if self.build and b.id == self.build.id then pos = k end
	end
	pos = pos + dir
	if pos < 1 then pos = n elseif pos > n then pos = 1 end
	self:SetBuild(list[pos])
end

function UI:SaveCurrent()
	local class, tree = self:CurrentTree()
	local numTabs = (tree and tree.numTabs) or 3
	if self.linked then
		self.linked.code = ATP.Encode(self.ranks, numTabs)
		return
	end
	if not self.build then
		self.build = ATP:CreateBuild(class, ATP:NextBuildName(class), "")
		ATP.char.sel[class] = self.build.id
		self.buildList = ATP:GetBuilds(class)
	end
	ATP:SaveBuild(self.build, self.ranks, numTabs)
end

function UI:ChangePoint(btn, delta)
	local class, tree = self:CurrentTree()
	if not tree then return end
	local ok
	if delta > 0 then
		ok = ATP.AddPoint(tree, self.ranks, btn.tab, btn.index, ATP.db.settings.maxPoints)
	else
		ok = ATP.RemovePoint(tree, self.ranks, btn.tab, btn.index)
	end
	if not ok then return end
	self:SaveCurrent()
	self:Refresh()
	if GameTooltip:IsOwned(btn) then self:TalentEnter(btn) end
end

-------------------------------------------------------------------------------
-- actions (header buttons)
-------------------------------------------------------------------------------
function UI:DoNew()
	local class = self.viewClass
	self:AskName("Name for the new build:", ATP:NextBuildName(class), function(text)
		UI:SetBuild(ATP:CreateBuild(class, text, ""))
	end)
end

function UI:DoCopy()
	local class, tree = self:CurrentTree()
	local code = ATP.Encode(self.ranks, (tree and tree.numTabs) or 3)
	local base = self.build and self.build.name or "Build"
	self:AskName("Name for the copy:", base .. " copy", function(text)
		UI:SetBuild(ATP:CreateBuild(class, text, code))
	end)
end

function UI:DoFromSpec()
	if not self:IsOwnView() then return end
	local code = ATP.Encode(self:LearnedRanks(), GetNumTalentTabs())
	self:AskName("Save your current talents as:", "Current spec", function(text)
		UI:SetBuild(ATP:CreateBuild(ATP.playerClass, text, code))
	end)
end

function UI:DoRename()
	local b = self.build
	if not b then return end
	self:AskName("Rename build:", b.name, function(text)
		ATP:RenameBuild(b, text)
		UI:Refresh()
	end)
end

function UI:DoDelete()
	local b = self.build
	if not b then return end
	self:Confirm("Delete build \"" .. b.name .. "\" for every character and account?", function()
		ATP:DeleteBuild(b)
		ATP.char.sel[b.class] = nil
		UI:SelectBuild()
		UI:Refresh()
	end)
end

function UI:DoReset(t)
	local question = t and "Remove all planned points from this tree?" or "Remove all planned points from this build?"
	self:Confirm(question, function()
		if t then UI.ranks[t] = {} else UI.ranks = {} end
		UI:SaveCurrent()
		UI:Refresh()
	end)
end

function UI:DoSaveLinked()
	local l = self.linked
	if not l then return end
	local tree = ATP:GetTree(l.class)
	local code = tree and ATP.Encode(self.ranks, tree.numTabs) or l.code
	local b = ATP:CreateBuild(l.class, l.name, code)
	ATP.char.sel[l.class] = b.id
	self.linked = nil
	self.viewClass = l.class
	self:SelectBuild()
	self:Refresh()
	ATP.Print("saved \"" .. b.name .. "\" to your " .. ((tree and tree.className) or l.class) .. " builds.")
end

function UI:DoBack()
	self.linked = nil
	self:SelectBuild()
	self:Refresh()
end

-- put the build you are looking at into chat
function UI:LinkCurrent()
	if not ATP.db then return end
	local class, tree = self:CurrentTree()
	local numTabs = (tree and tree.numTabs) or 3
	local code, name
	if self:Mode() == "learn" then
		code = ATP.Encode(self:LearnedRanks(), numTabs)
		name = (UnitName("player") or "My") .. " spec"
	elseif self.linked then
		code = tree and ATP.Encode(self.ranks, numTabs) or self.linked.code
		name = self.linked.name
	else
		if not self.build and not self.ranks then self:SelectBuild() end
		code = ATP.Encode(self.ranks or {}, numTabs)
		name = self.build and self.build.name or "Empty"
	end
	ATP.InsertChat(ATP:BuildChatText(class, code, name))
end

function UI:ClassList()
	local list = {}
	for class, tree in pairs(ATP.db.trees) do tinsert(list, class) end
	local have = false
	for _, c in ipairs(list) do if c == ATP.playerClass then have = true end end
	if not have then tinsert(list, ATP.playerClass) end
	table.sort(list, function(a, b)
		local ta, tb = ATP.db.trees[a], ATP.db.trees[b]
		return ((ta and ta.className) or a) < ((tb and tb.className) or b)
	end)
	return list
end

function UI:StepClass(dir)
	if self.linked then return end
	local list = self:ClassList()
	local n = getn(list)
	local pos = 1
	for k, c in ipairs(list) do if c == self.viewClass then pos = k end end
	pos = pos + dir
	if pos < 1 then pos = n elseif pos > n then pos = 1 end
	self.viewClass = list[pos]
	self:SelectBuild()
	self:Refresh()
end

function UI:DoSwitchStyle()
	local target = (self.style == "pfui") and "blizz" or "pfui"
	if target == "pfui" and not PfuiAvailable() then
		ATP.Print("pfUI is not loaded.")
		return
	end
	local label = (target == "pfui") and "pfUI" or "Blizzard"
	self:Confirm("Switch AdeTalentPlanner to the " .. label .. " look?\nYour UI will reload.", function()
		ATP.db.settings.style = target
		ReloadUI()
	end)
end

function UI:ToggleMode()
	if self.mode == "learn" then self.mode = "plan" else self.mode = "learn" end
	ATP.db.settings.mode = self.mode
	self:Refresh()
end

-------------------------------------------------------------------------------
-- talent buttons
-------------------------------------------------------------------------------
local function Fmt(global, fallback, a, b)
	local f = global
	if type(f) ~= "string" then f = fallback end
	return string.format(f, a, b)
end

function UI:TalentEnter(btn)
	local class, tree = self:CurrentTree()
	if not tree then return end
	local t, i = btn.tab, btn.index
	local tab = tree.tabs[t]
	local tal = tab.talents[i]
	if not tal then return end
	local mode = self:Mode()
	local own = (class == ATP.playerClass)
	local planned = (self.ranks[t] and self.ranks[t][i]) or 0
	GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")

	-- Learning mode: the game's own tooltip (your real rank)
	if mode == "learn" then
		GameTooltip:SetTalent(t, i)
		if planned > 0 then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Planned rank " .. planned .. "/" .. tal.max, 0, 1, 1)
		end
		GameTooltip:AddLine("Shift-click: link this talent in chat", 0.6, 0.6, 0.6)
		GameTooltip:Show()
		return
	end

	-- Planning mode: tooltip for the planned rank
	local shownRank = planned
	if shownRank < 1 then shownRank = 1 end
	local text = ATP:RankText(class, t, i, shownRank)
	if not text then
		-- no description source for this rank: fall back to what the game gives
		if own then
			GameTooltip:SetTalent(t, i)
		else
			GameTooltip:SetText(tal.name, 1, 1, 1)
			GameTooltip:AddLine("Max rank " .. tal.max, 1, 0.82, 0)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Planned rank " .. planned .. "/" .. tal.max, 0, 1, 1)
		GameTooltip:AddLine("Install AdeTalents or SuperWoW to see the text for every rank.", 0.6, 0.6, 0.6, 1)
		GameTooltip:AddLine("Shift-click: link this talent in chat", 0.6, 0.6, 0.6)
		GameTooltip:Show()
		return
	end

	GameTooltip:SetText(tal.name, 1, 1, 1)
	GameTooltip:AddLine(Fmt(TOOLTIP_TALENT_RANK, "Rank %d/%d", planned, tal.max), 0, 1, 1)
	if own and not self.linked then
		local _, _, _, _, learned = GetTalentInfo(t, i)
		if (learned or 0) ~= planned then
			GameTooltip:AddLine("Learned rank " .. (learned or 0) .. "/" .. tal.max, 1, 0.82, 0)
		end
	end

	-- requirements, red while not met by the plan
	local ranks = self.ranks
	if planned < tal.max then
		local need = (tal.tier - 1) * 5
		if need > 0 and ATP.PointsBelowTier(ranks, tree, t, tal.tier) < need then
			GameTooltip:AddLine(Fmt(TOOLTIP_TALENT_TIER_POINTS, "Requires %d points in %s Talents", need, tab.name), 1, 0.1, 0.1)
		end
		if tal.rt and not ATP.PrereqMet(ranks, tree, t, tal) then
			local pi = ATP.FindTalent(tree, t, tal.rt, tal.rc)
			local pre = pi and tab.talents[pi]
			if pre then
				GameTooltip:AddLine(Fmt(TOOLTIP_TALENT_PREREQ, "Requires %d points in %s", pre.max, pre.name), 1, 0.1, 0.1)
			end
		end
	end

	GameTooltip:AddLine(text, 1, 0.82, 0, 1)
	if planned > 0 and planned < tal.max then
		local nextText = ATP:RankText(class, t, i, planned + 1)
		if nextText then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(type(TOOLTIP_TALENT_NEXT_RANK) == "string" and TOOLTIP_TALENT_NEXT_RANK or "Next rank:", 1, 1, 1)
			GameTooltip:AddLine(nextText, 1, 0.82, 0, 1)
		end
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Shift-click: link this talent in chat", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function UI:TalentClick(btn, mouse)
	local class, tree = self:CurrentTree()
	if not tree then return end
	local t, i = btn.tab, btn.index
	local mode = self:Mode()
	if IsShiftKeyDown() then
		local rank = (self.ranks[t] and self.ranks[t][i]) or 0
		if mode == "learn" or rank == 0 then
			if class == ATP.playerClass then
				local _, _, _, _, learned = GetTalentInfo(t, i)
				if mode == "learn" or (learned or 0) > 0 then rank = learned or 0 end
			end
		end
		ATP.InsertChat(ATP:TalentLink(class, t, i, rank))
		return
	end
	if mode == "learn" then
		if mouse == "LeftButton" and (not ATP.db.settings.ctrlLearn or IsControlKeyDown()) then
			LearnTalent(t, i)
		end
		return
	end
	if IsControlKeyDown() and mouse == "LeftButton" and class == ATP.playerClass and not self.linked then
		LearnTalent(t, i)
		return
	end
	if mouse == "LeftButton" then
		self:ChangePoint(btn, 1)
	elseif mouse == "RightButton" then
		self:ChangePoint(btn, -1)
	end
end

function UI:TalentWheel(btn, delta)
	if self:Mode() ~= "plan" then return end
	if delta > 0 then self:ChangePoint(btn, 1) else self:ChangePoint(btn, -1) end
end

function UI:GetButton(tf, t, i)
	local b = tf.buttons[i]
	if b then return b end
	local name = "ATPTree" .. t .. "Talent" .. i
	b = CreateFrame("Button", name, tf)
	b:SetWidth(BTN)
	b:SetHeight(BTN)
	b.tab = t
	b.index = i

	b.slot = b:CreateTexture(nil, "BACKGROUND")
	b.slot:SetTexture("Interface\\Buttons\\UI-EmptySlot-White")
	b.slot:SetWidth(55)
	b.slot:SetHeight(55)
	b.slot:SetPoint("CENTER", b, "CENTER", 0, 0)

	b.icon = b:CreateTexture(nil, "BORDER")
	b.icon:SetAllPoints(b)

	b.rankBorder = b:CreateTexture(nil, "OVERLAY")
	b.rankBorder:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder")
	b.rankBorder:SetWidth(24)
	b.rankBorder:SetHeight(24)
	b.rankBorder:SetPoint("CENTER", b, "BOTTOMRIGHT", 0, 0)
	b.rankText = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.rankText:SetPoint("CENTER", b.rankBorder, "CENTER", 0, 0)

	b.planBorder = b:CreateTexture(nil, "OVERLAY")
	b.planBorder:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder")
	b.planBorder:SetWidth(24)
	b.planBorder:SetHeight(24)
	b.planBorder:SetPoint("CENTER", b, "BOTTOMLEFT", 0, 0)
	b.planText = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.planText:SetPoint("CENTER", b.planBorder, "CENTER", 0, 0)
	b.planText:SetTextColor(0, 1, 1)

	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	hl:SetBlendMode("ADD")
	hl:SetAllPoints(b)
	if self.style == "pfui" then
		b.slot:Hide()
		Try(pfUI.api.CreateBackdrop, b)
		b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.rankBorder:SetTexture(nil)
		b.planBorder:SetTexture(nil)
		b.rankText:ClearAllPoints()
		b.rankText:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -1)
		b.planText:ClearAllPoints()
		b.planText:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -1, -1)
		self:SkinFont(b.rankText)
		self:SkinFont(b.planText)
	end
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:EnableMouseWheel(1)
	b:SetScript("OnClick", function() UI:TalentClick(this, arg1) end)
	b:SetScript("OnMouseWheel", function() UI:TalentWheel(this, arg1) end)
	b:SetScript("OnEnter", function() UI:TalentEnter(this) end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)

	tf.buttons[i] = b
	return b
end

-------------------------------------------------------------------------------
-- branches / arrows
-------------------------------------------------------------------------------
local function NextLine(tf)
	tf.lineIdx = tf.lineIdx + 1
	local tex = tf.lines[tf.lineIdx]
	if not tex then
		tex = tf:CreateTexture(nil, "ARTWORK")
		tex:SetTexture(BRANCH_TEX)
		tf.lines[tf.lineIdx] = tex
	end
	tex:ClearAllPoints()
	tex:Show()
	return tex
end

local function NextArrow(tf)
	tf.arrowIdx = tf.arrowIdx + 1
	local tex = tf.arrows[tf.arrowIdx]
	if not tex then
		tex = tf.arrowFrame:CreateTexture(nil, "OVERLAY")
		tex:SetTexture(ARROW_TEX)
		tex:SetWidth(32)
		tex:SetHeight(32)
		tf.arrows[tf.arrowIdx] = tex
	end
	tex:ClearAllPoints()
	tex:Show()
	return tex
end

local function Line(tf, vertical, x, y, len, s)
	if len <= 0 then return end
	local tex = NextLine(tf)
	local c
	if vertical then
		c = V_COORDS[s]
		tex:SetWidth(BTN)
		tex:SetHeight(len)
	else
		c = H_COORDS[s]
		tex:SetWidth(len)
		tex:SetHeight(BTN)
	end
	tex:SetTexCoord(c[1], c[2], c[3], c[4])
	tex:SetPoint("TOPLEFT", tf, "TOPLEFT", x, y)
end

local function Arrow(tf, kind, x, y, s)
	local tex = NextArrow(tf)
	local c = A_COORDS[kind][s]
	tex:SetTexCoord(c[1], c[2], c[3], c[4])
	tex:SetPoint("TOPLEFT", tf, "TOPLEFT", x, y)
end

local function DrawPrereq(tf, tier, col, rt, rc, on)
	local s = on and 1 or -1
	local bx, by = BtnXY(tier, col)
	local px, py = BtnXY(rt, rc)
	if rc == col then
		Line(tf, true, bx, py - BTN, (py - BTN) - by, s)
		Arrow(tf, "top", bx, by + BTN / 2, s)
	elseif rt == tier then
		local left, right
		if px < bx then left, right = px + BTN, bx else left, right = bx + BTN, px end
		Line(tf, false, left, by, right - left, s)
		if px > bx then
			Arrow(tf, "right", bx + BTN / 2 + 5, by, s)
		else
			Arrow(tf, "left", bx - BTN / 2 - 5, by, s)
		end
	else
		-- across on the prerequisite's row, then down into the talent
		if px < bx then
			Line(tf, false, px + BTN, py, (bx + BTN / 2 + 5) - (px + BTN), s)
		else
			Line(tf, false, bx + BTN / 2 - 5, py, px - (bx + BTN / 2 - 5), s)
		end
		Line(tf, true, bx, py - BTN / 2 + 5, (py - BTN / 2 + 5) - by, s)
		Arrow(tf, "top", bx, by + BTN / 2, s)
	end
end

-------------------------------------------------------------------------------
-- tree frames
-------------------------------------------------------------------------------
function UI:GetTreeFrame(t)
	local tf = self.trees[t]
	if tf then return tf end
	tf = CreateFrame("Frame", "ATPTree" .. t, self.frame)
	tf:SetWidth(TREE_W)
	tf:SetHeight(TREE_H)
	tf:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 12 + (t - 1) * (TREE_W + TREE_GAP), -HEADER_H)

	local function bg(w, h, x, y, crop)
		local tex = tf:CreateTexture(nil, "BACKGROUND")
		tex:SetWidth(w)
		tex:SetHeight(h)
		tex:SetPoint("TOPLEFT", tf, "TOPLEFT", x, y)
		if crop then tex:SetTexCoord(0, w / 64, 0, 1) end
		return tex
	end
	tf.bgTL = bg(256, 256, 0, 0)
	tf.bgTR = bg(TREE_W - 256, 256, 256, 0, true)
	tf.bgBL = bg(256, 128, 0, -256)
	tf.bgBR = bg(TREE_W - 256, 128, 256, -256, true)
	self:SetTreeHeight(tf, TREE_H)
	if self.style == "pfui" then Try(pfUI.api.CreateBackdrop, tf) end

	tf.title = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	tf.title:SetPoint("TOP", tf, "TOP", 0, -8)
	self:SkinFont(tf.title, 1)

	tf.lines, tf.arrows, tf.buttons = {}, {}, {}
	tf.lineIdx, tf.arrowIdx = 0, 0
	tf.arrowFrame = CreateFrame("Frame", nil, tf)
	tf.arrowFrame:SetAllPoints(tf)
	tf.arrowFrame:SetFrameLevel(tf:GetFrameLevel() + 5)

	tf.resetBtn = MakeButton(tf, "x", 22, "Remove planned points from this tree", function() UI:DoReset(this.tab) end)
	tf.resetBtn:SetHeight(18)
	tf.resetBtn.tab = t
	tf.resetBtn:SetPoint("TOPRIGHT", tf, "TOPRIGHT", -4, -4)
	tf.resetBtn:SetFrameLevel(tf:GetFrameLevel() + 6)

	self.trees[t] = tf
	return tf
end

-- bottom art is cropped so the tree ends right under its last tier
function UI:SetTreeHeight(tf, h)
	tf:SetHeight(h)
	local bottom = h - 256
	if bottom < 1 then bottom = 1 end
	local v = bottom / 128
	if v > 1 then v = 1 end
	tf.bgBL:SetHeight(bottom)
	tf.bgBL:SetTexCoord(0, 1, 0, v)
	tf.bgBR:SetHeight(bottom)
	tf.bgBR:SetTexCoord(0, (TREE_W - 256) / 64, 0, v)
end

function UI:DrawTree(t, class, tree, mode, own, unspent, treeH)
	local tab = tree.tabs[t]
	local tf = self:GetTreeFrame(t)
	if tf.height ~= treeH then
		self:SetTreeHeight(tf, treeH)
		tf.height = treeH
	end
	tf:Show()

	local base = "Interface\\TalentFrame\\" .. (tab.bg or "MageFire") .. "-"
	tf.bgTL:SetTexture(base .. "TopLeft")
	tf.bgTR:SetTexture(base .. "TopRight")
	tf.bgBL:SetTexture(base .. "BottomLeft")
	tf.bgBR:SetTexture(base .. "BottomRight")

	local ranks = self.ranks
	local planned = ATP.TreePoints(ranks, t)
	local spent = 0
	if own then
		local _, _, s = GetTalentTabInfo(t)
		spent = s or 0
	end
	local title = CYAN .. planned .. "|r  " .. tab.name
	if own then title = title .. "  " .. GOLD .. spent .. "|r" end
	tf.title:SetText(title)
	if mode == "plan" then tf.resetBtn:Show() else tf.resetBtn:Hide() end

	tf.lineIdx, tf.arrowIdx = 0, 0
	local maxPoints = ATP.db.settings.maxPoints
	local learnedOf = {}

	for i = 1, tab.num do
		local tal = tab.talents[i]
		local b = self:GetButton(tf, t, i)
		if tal then
			local x, y = BtnXY(tal.tier, tal.col)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", tf, "TOPLEFT", x, y)
			b.icon:SetTexture(tal.icon)

			local pr = (ranks[t] and ranks[t][i]) or 0
			local lr, meets = 0, nil
			if own then
				local _, _, _, _, r, _, _, m = GetTalentInfo(t, i)
				lr = r or 0
				meets = m
			end
			learnedOf[i] = lr

			if own and lr > 0 then
				b.rankText:SetText(lr)
				if lr < tal.max then b.rankText:SetTextColor(0.1, 1, 0.1) else b.rankText:SetTextColor(1, 0.82, 0) end
				b.rankText:Show()
				b.rankBorder:Show()
			else
				b.rankText:Hide()
				b.rankBorder:Hide()
			end
			if pr > 0 then
				b.planText:SetText(pr)
				b.planText:Show()
				b.planBorder:Show()
			else
				b.planText:Hide()
				b.planBorder:Hide()
			end

			local cur, available
			if mode == "learn" then
				cur = lr
				available = lr < tal.max and meets and unspent > 0 and spent >= (tal.tier - 1) * 5
			else
				cur = pr
				available = ATP.CanAdd(tree, ranks, t, i, maxPoints)
			end

			if cur > 0 or available then
				b.icon:SetAlpha(1)
				b.icon:SetVertexColor(1, 1, 1)
			elseif self.style == "pfui" then
				-- pfUI: keep locked icons solid, just darker, so they stay readable
				b.icon:SetAlpha(0.9)
				b.icon:SetVertexColor(0.45, 0.45, 0.45)
			else
				b.icon:SetAlpha(0.35)
				b.icon:SetVertexColor(0.6, 0.6, 0.6)
			end
			if cur >= tal.max then
				self:SetTalentColor(b, 1, 0.82, 0)
			elseif mode == "learn" and available and pr > lr then
				self:SetTalentColor(b, 0, 1, 1)         -- planned: learn this next
			elseif available then
				self:SetTalentColor(b, 0.1, 1, 0.1)
			else
				self:SetTalentColor(b, nil)
			end
			b:Show()
		else
			b:Hide()
		end
	end
	for i = tab.num + 1, getn(tf.buttons) do tf.buttons[i]:Hide() end

	-- prerequisite branches
	for i = 1, tab.num do
		local tal = tab.talents[i]
		if tal and tal.rt then
			local pi = ATP.FindTalent(tree, t, tal.rt, tal.rc)
			if pi then
				local pmax = tab.talents[pi].max
				local have
				if mode == "learn" then have = learnedOf[pi] or 0 else have = (ranks[t] and ranks[t][pi]) or 0 end
				DrawPrereq(tf, tal.tier, tal.col, tal.rt, tal.rc, have >= pmax)
			end
		end
	end
	for k = tf.lineIdx + 1, getn(tf.lines) do tf.lines[k]:Hide() end
	for k = tf.arrowIdx + 1, getn(tf.arrows) do tf.arrows[k]:Hide() end
end

-------------------------------------------------------------------------------
-- main frame
-------------------------------------------------------------------------------
function UI:Create()
	if self.frame then return end
	self.style = self:WantedStyle()
	local f = CreateFrame("Frame", "AdeTalentPlannerFrame", UIParent)
	self.frame = f
	f:SetFrameStrata("HIGH")
	if f.SetToplevel then f:SetToplevel(1) end
	f:SetWidth(24 + 3 * TREE_W + 2 * TREE_GAP)
	f:SetHeight(HEADER_H + TREE_H + FOOTER_H)
	if self.style == "pfui" then
		Try(pfUI.api.CreateBackdrop, f)
		Try(pfUI.api.CreateBackdropShadow, f)
	else
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end
	f:EnableMouse(1)
	f:SetMovable(1)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing(); UI:SavePosition() end)
	f:SetScript("OnShow", function()
		PlaySound("TalentScreenOpen")
		UpdateMicroButtons()
		UI:Refresh()
	end)
	f:SetScript("OnHide", function()
		PlaySound("TalentScreenClose")
		UI.linked = nil
		UpdateMicroButtons()
	end)
	tinsert(UISpecialFrames, "AdeTalentPlannerFrame")
	f:Hide()

	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetPoint("TOP", f, "TOP", 0, -16)

	local close = CreateFrame("Button", "AdeTalentPlannerFrameClose", f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
	if self.style == "pfui" then Try(pfUI.api.SkinCloseButton, close, f, -8, -8) end

	-- row 2: build list and build actions (left), Ctrl-to-learn (right)
	local y = -36
	f.prev = MakeButton(f, "<", 24, "Previous build", function() UI:StepBuild(-1) end)
	f.prev:SetPoint("TOPLEFT", f, "TOPLEFT", 18, y)
	f.next = MakeButton(f, ">", 24, "Next build", function() UI:StepBuild(1) end)
	f.next:SetPoint("LEFT", f.prev, "RIGHT", 2, 0)
	f.buildText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.buildText:SetWidth(210)
	f.buildText:SetHeight(20)
	f.buildText:SetJustifyH("LEFT")
	f.buildText:SetPoint("LEFT", f.next, "RIGHT", 8, 0)

	f.newBtn = MakeButton(f, "New", 46, "New empty build for this class", function() UI:DoNew() end)
	f.newBtn:SetPoint("LEFT", f.buildText, "RIGHT", 4, 0)
	f.copyBtn = MakeButton(f, "Copy", 50, "Copy this build", function() UI:DoCopy() end)
	f.copyBtn:SetPoint("LEFT", f.newBtn, "RIGHT", 2, 0)
	f.specBtn = MakeButton(f, "From spec", 76, "New build from the talents you have learned", function() UI:DoFromSpec() end)
	f.specBtn:SetPoint("LEFT", f.copyBtn, "RIGHT", 2, 0)
	f.renameBtn = MakeButton(f, "Rename", 62, "Rename this build", function() UI:DoRename() end)
	f.renameBtn:SetPoint("LEFT", f.specBtn, "RIGHT", 2, 0)
	f.deleteBtn = MakeButton(f, "Delete", 56, "Delete this build", function() UI:DoDelete() end)
	f.deleteBtn:SetPoint("LEFT", f.renameBtn, "RIGHT", 2, 0)
	f.resetBtn = MakeButton(f, "Reset", 52, "Remove all planned points", function() UI:DoReset() end)
	f.resetBtn:SetPoint("LEFT", f.deleteBtn, "RIGHT", 2, 0)

	-- linked-build view buttons (same spot as New/Copy)
	f.saveBtn = MakeButton(f, "Save build", 84, "Save this linked build to your builds for that class", function() UI:DoSaveLinked() end)
	f.saveBtn:SetPoint("LEFT", f.buildText, "RIGHT", 4, 0)
	f.backBtn = MakeButton(f, "Back", 50, "Back to your own builds", function() UI:DoBack() end)
	f.backBtn:SetPoint("LEFT", f.saveBtn, "RIGHT", 2, 0)

	f.linkBtn = MakeButton(f, "Link", 50, "Put this build in chat.\nIn Learning mode it links your learned talents.", function() UI:LinkCurrent() end)
	f.linkBtn:SetPoint("LEFT", f.resetBtn, "RIGHT", 8, 0)

	f.ctrlCheck = CreateFrame("CheckButton", "ATPCtrlCheck", f, "UICheckButtonTemplate")
	f.ctrlCheck:SetWidth(22)
	f.ctrlCheck:SetHeight(22)
	f.ctrlCheck:SetPoint("TOPRIGHT", f, "TOPRIGHT", -140, y)
	f.ctrlText = getglobal("ATPCtrlCheckText")
	f.ctrlText:SetText("Ctrl-click to learn")
	f.ctrlCheck:SetScript("OnClick", function()
		if this:GetChecked() then ATP.db.settings.ctrlLearn = 1 else ATP.db.settings.ctrlLearn = nil end
		UI:Refresh()
	end)
	if self.style == "pfui" then Try(pfUI.api.SkinCheckbox, f.ctrlCheck, 14) end

	-- row 3: points (left), class / mode / look (right)
	local y3 = -62
	f.pointsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.pointsText:SetPoint("TOPLEFT", f, "TOPLEFT", 22, y3 - 5)
	f.pointsText:SetJustifyH("LEFT")

	f.styleBtn = MakeButton(f, "Look", 112, "Switch between the Blizzard look and the pfUI look.\nThe UI reloads to apply it.", function() UI:DoSwitchStyle() end)
	f.styleBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, y3)
	f.modeBtn = MakeButton(f, "Mode", 116, "Learning: click learns talents.\nPlanning: click plans points.", function() UI:ToggleMode() end)
	f.modeBtn:SetPoint("RIGHT", f.styleBtn, "LEFT", -4, 0)
	f.classBtn = MakeButton(f, "Class", 128, "Left-click: next class, right-click: previous.\nA class appears here after you log in a character of it once.", function()
		if arg1 == "RightButton" then UI:StepClass(-1) else UI:StepClass(1) end
	end)
	f.classBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.classBtn:SetPoint("RIGHT", f.modeBtn, "LEFT", -4, 0)

	-- footer
	f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.hint:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)

	f.noData = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.noData:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.noData:SetWidth(600)

	self:SkinFont(f.title, 2)
	self:SkinFont(f.buildText)
	self:SkinFont(f.pointsText)
	self:SkinFont(f.hint)
	self:SkinFont(f.noData)
	self:SkinFont(f.ctrlText)

	self:ApplyScale()
	self:RestorePosition()
end

function UI:ApplyScale()
	if self.frame then self.frame:SetScale(ATP.db.settings.scale or 1) end
end

function UI:SavePosition()
	local f = self.frame
	ATP.db.settings.point = { f:GetLeft(), f:GetTop() }
end

function UI:RestorePosition()
	local f = self.frame
	local p = ATP.db.settings.point
	f:ClearAllPoints()
	if p and p[1] and p[2] then
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
	end
end

function UI:Refresh()
	local f = self.frame
	if not f or not f:IsVisible() or not ATP.db then return end
	local class, tree = self:CurrentTree()
	local own = (class == ATP.playerClass)
	local mode = self:Mode()
	local s = ATP.db.settings
	local cname = (tree and tree.className) or class

	f.title:SetText("AdeTalentPlanner - " .. cname)

	-- header buttons
	local linked = self.linked ~= nil
	local normal = { f.prev, f.next, f.newBtn, f.copyBtn, f.specBtn, f.renameBtn, f.deleteBtn, f.resetBtn }
	for _, b in ipairs(normal) do if linked then b:Hide() else b:Show() end end
	if linked then f.saveBtn:Show(); f.backBtn:Show() else f.saveBtn:Hide(); f.backBtn:Hide() end
	f.linkBtn:ClearAllPoints()
	if linked then f.linkBtn:SetPoint("LEFT", f.backBtn, "RIGHT", 8, 0) else f.linkBtn:SetPoint("LEFT", f.resetBtn, "RIGHT", 8, 0) end

	if linked then
		f.buildText:SetText(CYAN .. "Linked:|r " .. self.linked.name)
	else
		local list = self.buildList or {}
		local pos = 0
		for k, b in ipairs(list) do if self.build and b.id == self.build.id then pos = k end end
		if self.build then
			f.buildText:SetText(GREY .. pos .. "/" .. getn(list) .. "|r " .. self.build.name)
		else
			f.buildText:SetText(GREY .. "no builds yet - just start planning|r")
		end
		if self.build then f.renameBtn:Enable(); f.deleteBtn:Enable() else f.renameBtn:Disable(); f.deleteBtn:Disable() end
		if own then f.specBtn:Enable() else f.specBtn:Disable() end
		if getn(list) > 1 then f.prev:Enable(); f.next:Enable() else f.prev:Disable(); f.next:Disable() end
	end

	f.classBtn:SetText("Class: " .. cname)
	if linked then f.classBtn:Disable() else f.classBtn:Enable() end
	if own and not linked then
		f.modeBtn:Enable()
		f.modeBtn:SetText(mode == "learn" and "Mode: Learning" or "Mode: Planning")
	else
		f.modeBtn:Disable()
		f.modeBtn:SetText("Mode: Planning")
	end
	f.ctrlCheck:SetChecked(s.ctrlLearn and 1 or 0)
	f.styleBtn:SetText(self.style == "pfui" and "Look: pfUI" or "Look: Blizzard")
	if self.style == "blizz" and not PfuiAvailable() then f.styleBtn:Disable() else f.styleBtn:Enable() end
	if own and not linked then f.ctrlCheck:Show() else f.ctrlCheck:Hide() end

	-- no tree data for this class yet
	if not tree then
		for _, tf in pairs(self.trees) do tf:Hide() end
		f.noData:SetText("No talent data for " .. cname .. " yet.\nLog in a " .. cname .. " once (on any account if you use SuperWoW) and it will show up here."
			.. (linked and "\nYou can still press Save build now." or ""))
		f.noData:Show()
		f.pointsText:SetText("")
		f.hint:SetText("")
		return
	end
	f.noData:Hide()

	local numTabs = tree.numTabs
	f:SetWidth(24 + numTabs * TREE_W + (numTabs - 1) * TREE_GAP)

	-- trees end just under their lowest tier (more tiers on custom servers -> taller)
	local maxTier = 1
	for t = 1, numTabs do
		local tab = tree.tabs[t]
		for i = 1, tab.num do
			local tal = tab.talents[i]
			if tal and tal.tier > maxTier then maxTier = tal.tier end
		end
	end
	local treeH = OFFY + (maxTier - 1) * TIER_STEP + BTN + 12
	if treeH < TREE_H then treeH = TREE_H end
	f:SetHeight(HEADER_H + treeH + FOOTER_H)

	local unspent = 0
	if own then unspent = UnitCharacterPoints("player") or 0 end
	for t = 1, numTabs do self:DrawTree(t, class, tree, mode, own, unspent, treeH) end
	for t, tf in pairs(self.trees) do if t > numTabs then tf:Hide() end end

	-- points line
	local planned = ATP.PointsString(self.ranks, numTabs) .. " = " .. ATP.TotalPoints(self.ranks) .. "/" .. s.maxPoints
	local text = CYAN .. "Planned:|r " .. planned
	if own and not linked then
		local learned = {}
		local total = 0
		for t = 1, numTabs do
			local _, _, sp = GetTalentTabInfo(t)
			learned[t] = sp or 0
			total = total + (sp or 0)
		end
		local maxp = UnitLevel("player") - 9
		if maxp < 0 then maxp = 0 end
		text = GOLD .. "Learned:|r " .. table.concat(learned, "/") .. " = " .. total .. "/" .. maxp
			.. "   " .. GOLD .. "Unspent:|r " .. unspent .. "      " .. text
	end
	f.pointsText:SetText(text)

	if mode == "learn" then
		f.hint:SetText((s.ctrlLearn and "Ctrl-click" or "Click") .. ": learn talent      Shift-click: link talent in chat      Cyan frame: planned, learn next")
	else
		local h = "Left-click / wheel up: add point      Right-click / wheel down: remove      Shift-click: link talent in chat"
		if own and not linked then h = h .. "      Ctrl-click: learn" end
		f.hint:SetText(h)
	end
end

-------------------------------------------------------------------------------
-- entry points
-------------------------------------------------------------------------------
function UI:Init()
	self.viewClass = ATP.playerClass
	self.mode = ATP.db.settings.mode or "learn"
end

function UI:Toggle()
	if not ATP.db then return end
	if not self.frame then self:Create() end
	if self.frame:IsVisible() then
		self.frame:Hide()
	else
		if not ATP.treeCached then ATP:CacheOwnTree() end
		self.linked = nil
		self.viewClass = ATP.playerClass
		self:SelectBuild()
		self.frame:Show()
	end
end

function UI:ShowLinked(class, code, name)
	if not ATP.db then return end
	if not self.frame then self:Create() end
	self.linked = { class = class, code = code, name = ATP.CleanName(name) }
	self.ranks = ATP.Decode(code) or {}
	local tree = ATP:GetTree(class)
	if tree then ATP.Clamp(tree, self.ranks) end
	if self.frame:IsVisible() then
		self:Refresh()
	else
		self.frame:Show()
	end
end

function UI:OnDataChanged()
	if not self.frame or self.linked then return end
	if self.viewClass then self:SelectBuild() end
	self:Refresh()
end

function UI:OnTalentsChanged()
	self:Refresh()
end

-- talent key / micro button open this window instead of Blizzard's
function ToggleTalentFrame()
	UI:Toggle()
end

local origUpdateMicroButtons = UpdateMicroButtons
function UpdateMicroButtons()
	origUpdateMicroButtons()
	if UI.frame and UI.frame:IsVisible() and TalentMicroButton then
		TalentMicroButton:SetButtonState("PUSHED", 1)
	end
end
