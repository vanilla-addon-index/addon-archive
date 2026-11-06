--[[ GearAdvisor.lua -- telling you about upgrades, as Zygor's Gear Advisor does.

	Three things, all on the item score (ItemScore.lua):

	  Upgrades in your bags   When something you picked up beats what you wear
	                          and you can wear it now, a window says so: the
	                          item, how much better, what it replaces, and
	                          Equip or Decline. Declined items are not offered
	                          again until you clear the list. With "equip for
	                          me" on, an upgrade is put on straight away --
	                          never one that would bind to you on equip; that
	                          one still asks.
	  Quest rewards           When a quest offers a choice, the best one is
	                          marked: the biggest upgrade, else the one a vendor
	                          pays most for. With "pick for me" on and quests
	                          turning in automatically, it is taken.
	  Your bags               Upgrades get a border in the bags, so they are
	                          easy to find (the default bag frames).

	The advisor can be switched off, or off once you are level 60.

	Other specs     With more than one spec scored (Item Score page), a
	                new item in your bags that beats the best you have worn
	                for one of the others is named in the chat, once: "...
	                is an upgrade for your Protection gear (+12%)". What was
	                in your bags when you logged in is not new.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local GA = {}
AegisPathfinder.GearAdvisor = GA

-- Layout and timing, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local L = {
	WIDTH = 300, PAD = 12, ICON = 36, BUTTON_H = 22, CHROME_TOP = 30 + 18,
	SCAN_DELAY = 0.4,          -- a burst of bag events is scanned once
	REWARD_WAIT = 3,           -- how long to wait for reward items to load
	MAX_LEVEL = 60,
}

local DEFAULTS = {
	enabled = true,       -- the advisor at all
	maxlevel = false,     -- off at level 60
	popups = true,        -- the upgrade window
	questmark = true,     -- mark the best quest reward
	questpick = false,    -- take it, when the quest turns in by itself
	autoequip = false,    -- equip upgrades without asking
	bagmark = true,       -- border upgrades in the bags
}

local function settings()
	local db = AegisPathfinder.db.char
	db.gear = db.gear or {}
	local s = db.gear
	for k, v in pairs(DEFAULTS) do
		if s[k] == nil then s[k] = v end
	end
	s.declined = s.declined or {}
	return s
end
GA.Settings = settings

function GA:Active()
	local s = settings()
	if not s.enabled then return false end
	if s.maxlevel and (UnitLevel("player") or 1) >= L.MAX_LEVEL then return false end
	return true
end

--[[ Upgrades in your bags ]]

local found = {}       -- "bag:slot" -> upgrade
local offered = {}     -- item string -> true: already shown this session
local queue = {}       -- upgrades waiting for the window
local pending          -- an upgrade to equip once combat ends
local stocked          -- link -> true: in the bags already (NotifySpecs)
local told = {}        -- "spec|link" -> true: named in the chat

--- Every upgrade in your bags you can wear now.
function GA:Scan()
	found = {}
	if not self:Active() then return found end
	local IS = AegisPathfinder.ItemScore
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local up, c = IS:IsUpgrade(link)
				if up then
					local info = IS:Read(link)
					found[bag .. ":" .. slot] = {
						bag = bag, slot = slot, link = link, item = info.item,
						compare = c, boe = info.boe,
					}
				end
			end
		end
	end
	return found
end

function GA:Found() return found end

--- Where an upgrade has gone, if it moved since it was found.
local function relocate(rec)
	if GetContainerItemLink(rec.bag, rec.slot) == rec.link then return true end
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			if GetContainerItemLink(bag, slot) == rec.link then
				rec.bag, rec.slot = bag, slot
				return true
			end
		end
	end
	return false
end

--- Put an upgrade on, in the slot it was weighed against. In combat it
--- waits: the client will not change armour mid-fight.
function GA:Equip(rec)
	if UnitAffectingCombat("player") then
		pending = rec
		AegisPathfinder:Say("Upgrade: " .. rec.link .. " goes on when this fight is over.")
		return "combat"
	end
	if not relocate(rec) then return false end
	PickupContainerItem(rec.bag, rec.slot)
	EquipCursorItem(rec.compare.slot)
	if CursorHasItem and CursorHasItem() then ClearCursor() end
	return true
end

function GA:Decline(rec)
	settings().declined[rec.item] = true
	self:Dirty()
end

--- A new session: what was shown last time may be shown again; what was
--- declined stays declined.
function GA:ResetSession()
	offered, queue, pending = {}, {}, nil
	stocked, told = nil, {}
end

function GA:ClearDeclined()
	settings().declined = {}
	offered = {}
	self:Dirty()
end

--[[ Upgrades for your other specs.

	Said in the chat, not offered: you are not wearing that spec's gear, so
	there is nothing to swap. Only for what is new in your bags -- the first
	look after logging in takes stock without a word -- and each item once
	a spec. ]]
function GA:NotifySpecs()
	local IS = AegisPathfinder.ItemScore
	local first = stocked == nil
	stocked = stocked or {}
	local quiet = first or not IS.Settings().notify
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local link = GetContainerItemLink(bag, slot)
			if link and not stocked[link] then
				stocked[link] = true
				if not quiet then
					for _, up in ipairs(IS:SpecUpgrades(link)) do
						local key = up.spec .. "|" .. link
						if not told[key] then
							told[key] = true
							AegisPathfinder:Say(string.format("%s is an upgrade for your %s gear (%s).",
								link, IS:SpecLabel(up.spec), GA.Gain(up.compare)))
						end
					end
				end
			end
		end
	end
end

--- After a scan: equip what may be equipped for you, offer the rest.
function GA:Process()
	self:NotifySpecs()
	self:Scan()
	local s = settings()
	local fresh = {}
	for _, rec in pairs(found) do
		if not s.declined[rec.item] and not offered[rec.item] then table.insert(fresh, rec) end
	end
	table.sort(fresh, function(a, b) return (a.compare.delta or 0) > (b.compare.delta or 0) end)
	for _, rec in ipairs(fresh) do
		offered[rec.item] = true
		if s.autoequip and not rec.boe and not UnitAffectingCombat("player") then
			if self:Equip(rec) == true then
				AegisPathfinder:Say("Equipped " .. rec.link .. " " .. GA.Gain(rec.compare) .. ".")
			end
		elseif s.popups then
			table.insert(queue, rec)
		end
	end
	self:MarkBags()
	self:ShowNext()
end

--- "+12%", "for an empty slot", or -- against something that scores
--- nothing for your spec -- the points it adds.
function GA.Gain(c)
	if c.emptySlot then return "for an empty slot" end
	if not c.pct then return string.format("+%.1f", c.delta or 0) end
	return string.format("+%.0f%%", c.pct)
end

--[[ The upgrade window ]]

function GA:CreatePopup()
	local frame = CreateFrame("Frame", "AegisPathfinderUpgrade", UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(L.WIDTH)
	frame:SetHeight(L.CHROME_TOP + L.ICON + 44 + L.BUTTON_H + L.PAD)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -160)
	Theme:Panel(frame, "panel")
	frame:Hide()
	Theme:Chrome(frame, "Upgrade found", Theme:PositionSaver("upgradeframe"))

	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(L.ICON)
	icon:SetHeight(L.ICON)
	icon:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -(L.CHROME_TOP + 8))
	frame.icon = icon

	local name = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(name, "display", 13)
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
	name:SetPoint("RIGHT", frame, "RIGHT", -L.PAD, 0)
	name:SetJustifyH("LEFT")
	frame.name = name

	local gain = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(gain, "body", 12)
	gain:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
	gain:SetPoint("RIGHT", frame, "RIGHT", -L.PAD, 0)
	gain:SetJustifyH("LEFT")
	Theme:TextColor(gain, "accent")
	frame.gain = gain

	local detail = Theme:FinePrint(frame, L.WIDTH - L.PAD * 2)
	detail:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
	frame.detail = detail

	local half = math.floor((L.WIDTH - L.PAD * 2 - 6) / 2)
	local equip = Theme:PanelButton(frame, "Equip", half, L.BUTTON_H)
	equip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", L.PAD, L.PAD)
	equip:SetScript("OnClick", function()
		local rec = frame.rec
		frame:Hide()
		if rec then GA:Equip(rec) end
		GA:ShowNext()
	end)
	local decline = Theme:PanelButton(frame, "Decline", half, L.BUTTON_H)
	decline:SetPoint("LEFT", equip, "RIGHT", 6, 0)
	decline:SetScript("OnClick", function()
		local rec = frame.rec
		frame:Hide()
		if rec then GA:Decline(rec) end
		GA:ShowNext()
	end)
	frame.equip, frame.decline = equip, decline
	self.popup = frame
end

--- The next upgrade in the queue that is still in your bags and still an
--- upgrade, in the window; or the window closed if there is none.
function GA:ShowNext()
	if self.popup and self.popup:IsShown() then return end
	local rec
	while table.getn(queue) > 0 do
		local r = table.remove(queue, 1)
		if relocate(r) and found[r.bag .. ":" .. r.slot] and self:Active() and settings().popups then
			rec = r
			break
		end
	end
	if not rec then return end
	if not self.popup then self:CreatePopup() end
	local f = self.popup
	f.rec = rec
	local itemName, _, quality = GetItemInfo(rec.item)
	local _, _, _, hex = GetItemQualityColor(quality or 1)
	f.name:SetText((hex or "|cffffffff") .. (itemName or "?") .. "|r")
	f.icon:SetTexture((GetContainerItemInfo(rec.bag, rec.slot)))
	local IS = AegisPathfinder.ItemScore
	f.gain:SetText(GA.Gain(rec.compare) .. " for " .. IS:SpecLabel((IS:Spec())))
	local worn = GetInventoryItemLink("player", rec.compare.slot)
	local wornName = worn and GetItemInfo(IS:BaseItem(worn))
	local more = table.getn(queue)
	f.detail:SetText((wornName and ("Replaces " .. wornName .. ".") or "Nothing is worn there now.")
		.. (more > 0 and string.format(" %d more after this.", more) or ""))
	f:Show()
end

--[[ Quest rewards ]]

--- The reward to take: the index, and why -- "upgrade" with its comparison,
--- or "sell" with what a vendor pays. Nil and "wait" while an item has not
--- loaded; nil and "none" when there is nothing to go on.
function GA:RecommendReward()
	local n = GetNumQuestChoices() or 0
	if n < 2 then return nil, "none" end
	local IS, sell = AegisPathfinder.ItemScore, AegisPathfinder.GearData.sell
	local best, bestDelta, bestCompare = nil, 0, nil
	local richest, richestValue = nil, 0
	for i = 1, n do
		local link = GetQuestItemLink("choice", i)
		if not link or not GetItemInfo(IS:BaseItem(link)) then return nil, "wait" end
		local c = IS:Compare(link)
		if c and c.usable and not c.later and not c.noCompare and (c.delta or 0) > bestDelta then
			best, bestDelta, bestCompare = i, c.delta, c
		end
		local _, _, id = string.find(link, "item:(%d+)")
		local _, _, count = GetQuestItemInfo("choice", i)
		local value = (sell[tonumber(id)] or 0) * (count or 1)
		if value > richestValue then richest, richestValue = i, value end
	end
	if best then return best, "upgrade", bestCompare end
	if richest then return richest, "sell", richestValue end
	return nil, "none"
end

local function Mark(button, on, text)
	local m = button.__aegisMark
	if not m then
		if not on then return end
		m = CreateFrame("Frame", nil, button)
		m:SetAllPoints(button)
		m:SetFrameLevel(button:GetFrameLevel() + 2)
		m.edges = {}
		for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 2 },
			{ "TOPLEFT", "BOTTOMLEFT", 2, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 2, 0 } }) do
			local t = m:CreateTexture(nil, "OVERLAY")
			t:SetTexture(Theme.texture.solid)
			t:SetPoint(p[1], m, p[1])
			t:SetPoint(p[2], m, p[2])
			if p[3] > 0 then t:SetWidth(p[3]) else t:SetHeight(p[4]) end
			Theme:Tint(t, "accent")
			m.edges[i] = t
		end
		m.label = m:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(m.label, "display", 10, "OUTLINE")
		-- Inside the button's corner: above it would cover the row above.
		m.label:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -3, 3)
		Theme:TextColor(m.label, "accent")
		button.__aegisMark = m
	end
	m.label:SetText(text or "")
	if on then m:Show() else m:Hide() end
end
GA.Mark = Mark

local rewardWait, rewardPick

--- Mark the recommended reward on the quest window, and take it if asked
--- to. Waits (a few seconds at most) for the items to load first.
function GA:MarkReward(pick)
	if pick then rewardPick = true end
	local index, why, extra = self:RecommendReward()
	if why == "wait" then
		rewardWait = rewardWait or GetTime()
		if GetTime() - rewardWait < L.REWARD_WAIT then GA.events.rewardDirty = true end
		return nil, "wait"
	end
	rewardWait = nil
	self:ClearRewardMarks()
	if not index then
		rewardPick = nil
		return nil, why
	end
	local s = settings()
	if s.questmark and self:Active() then
		local button = getglobal("QuestRewardItem" .. index)
		if button then
			local text = why == "upgrade" and ("Upgrade " .. GA.Gain(extra))
				or ("Sells for " .. AegisPathfinder.FormatCopper(extra))
			Mark(button, true, text)
		end
	end
	if rewardPick and s.questpick and self:Active() and QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() then
		rewardPick = nil
		GetQuestReward(index)
		return index, why
	end
	rewardPick = nil
	return index, why
end

function GA:ClearRewardMarks()
	for i = 1, 6 do
		local button = getglobal("QuestRewardItem" .. i)
		if button then Mark(button, false) end
	end
end

--[[ Your bags ]]

function GA:MarkFrame(frame)
	if not frame or not frame.GetID then return end
	local bag = frame:GetID()
	local on = settings().bagmark and self:Active()
	for j = 1, frame.size or 0 do
		local button = getglobal(frame:GetName() .. "Item" .. j)
		if button then
			local rec = found[bag .. ":" .. button:GetID()]
			Mark(button, on and rec ~= nil)
		end
	end
end

function GA:MarkBags()
	for i = 1, NUM_CONTAINER_FRAMES or 12 do
		local frame = getglobal("ContainerFrame" .. i)
		if frame and frame:IsShown() then self:MarkFrame(frame) end
	end
end

--[[ Events ]]

function GA:Dirty()
	self.events.dirty = GetTime()
end

local events = CreateFrame("Frame")
GA.events = events
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("QUEST_COMPLETE")
events:RegisterEvent("QUEST_FINISHED")
events:SetScript("OnEvent", function()
	-- Your gear and bags arriving at login come before the addon has its
	-- settings; Initialize starts it afresh once they are there.
	if not AegisPathfinder.db then return end
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then
			local rec = pending
			pending = nil
			GA:Equip(rec)
		end
	elseif event == "QUEST_COMPLETE" then
		GA:MarkReward()
	elseif event == "QUEST_FINISHED" then
		rewardWait, rewardPick = nil, nil
		GA:ClearRewardMarks()
	elseif event ~= "UNIT_INVENTORY_CHANGED" or arg1 == "player" then
		GA:Dirty()
	end
end)
events:SetScript("OnUpdate", function()
	if not AegisPathfinder.db then return end
	if this.dirty and GetTime() - this.dirty >= L.SCAN_DELAY then
		this.dirty = nil
		GA:Process()
	end
	if this.rewardDirty then
		this.rewardDirty = nil
		GA:MarkReward()
	end
end)

function GA:Initialize()
	self:ResetSession()
	AegisPathfinder.ItemScore:OnChange(function() GA:Dirty() end)
	-- The default bags repaint through this; the border goes on after.
	if ContainerFrame_Update and not GA.hookedBags then
		GA.hookedBags = true
		local original = ContainerFrame_Update
		ContainerFrame_Update = function(frame)
			original(frame)
			GA:MarkFrame(frame)
		end
	end
	self:Dirty()
end
