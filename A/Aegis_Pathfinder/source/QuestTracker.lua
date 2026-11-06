-- QuestTracker.lua
-- Quest log scanning and completion detection for AegisPathfinder

local AegisPathfinder = AegisPathfinder
local L = AegisPathfinder.Locale


-- QUEST_ACCEPTED and QUEST_TURNED_IN are synthesized by ClassicAPI (a hard
-- requirement, enforced in Core.lua OnEnable)
AegisPathfinder.TrackEvents = {
	"UI_INFO_MESSAGE", "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM",
	"QUEST_WATCH_UPDATE", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
	"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "MINIMAP_ZONE_CHANGED",
	"ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "ADDON_LOADED",
	"CRAFT_SHOW", "PLAYER_DEAD", "SKILL_LINES_CHANGED", "SPELLS_CHANGED",
	"QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "HEARTHSTONE_BOUND",
	"BAG_UPDATE_DELAYED", "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL",
	"QUEST_PROGRESS", "QUEST_COMPLETE", "CHAT_MSG_COMBAT_HOSTILE_DEATH"
}


-- AceEvent-2.0 passes event args directly (no event name); the event itself
-- is available as self.currentEvent when needed
function AegisPathfinder:ADDON_LOADED(addon)
	if addon ~= "Blizzard_TrainerUI" then return end

	self:UnregisterEvent("ADDON_LOADED")

	local f = CreateFrame("Frame", nil, ClassTrainerFrame)
	f:SetScript("OnShow", function()
		if self:GetObjectiveInfo() == "TRAIN" then self:SetTurnedIn() end
	end)
end

function AegisPathfinder:SKILL_LINES_CHANGED()
	self:ScheduleStatusUpdate()
end

function AegisPathfinder:SPELLS_CHANGED()
	self:ScheduleStatusUpdate()
end

--[[ A level up. A level gate waiting on it -- a grind step or a level note
	with |LV| -- is done; then a starting zone outlevelled hands over to the
	shared route (Core.lua, CheckStartingZoneCompletion), counting that step.
	On a quest's own steps |LV| is only the level it needs: reaching it does
	not turn the quest in.

	Core.lua had a handler of this name for the starting zone, and this one,
	loaded after it, replaced it: the starting zone only let go at the next
	login. The level is the event's -- UnitLevel can still say the old one
	while it fires. ]]
function AegisPathfinder:PLAYER_LEVEL_UP(newlevel)
	newlevel = tonumber(newlevel)
	local level = tonumber((self:GetObjectiveTag("LV")))
	local action = self:GetObjectiveInfo()
	self:Debug("PLAYER_LEVEL_UP", newlevel, level)
	if level and newlevel and newlevel >= level and (action == "GRIND" or action == "NOTE") then self:SetTurnedIn() end
	local db = self.db.char
	if db.startingzoneselected and not db.startingzonecomplete then
		self:CheckStartingZoneCompletion(newlevel)
	end
end

--[[ A travel step is done on reaching its zone or subzone (GuideEngine.lua,
	ArrivedAt). An optional one may be behind you now that you are in the next
	step's zone (PassedTravel), which the scan decides. ]]
function AegisPathfinder:ZONE_CHANGED()
	if not self:IsTravelStep() then return end
	if self:ArrivedAt() then
		self:Debug(string.format("Detected zone change %q - %q", self:GetObjectiveInfo()))
		return self:SetTurnedIn()
	end
	if self:IsWayThere() then self:ScheduleStatusUpdate() end
end

AegisPathfinder.ZONE_CHANGED_INDOORS = AegisPathfinder.ZONE_CHANGED
AegisPathfinder.MINIMAP_ZONE_CHANGED = AegisPathfinder.ZONE_CHANGED
AegisPathfinder.ZONE_CHANGED_NEW_AREA = AegisPathfinder.ZONE_CHANGED


-- Fires on the bind-point update packet (ClassicAPI); no payload, re-read
-- GetBindLocation() for the new home
function AegisPathfinder:HEARTHSTONE_BOUND()
	local loc = GetBindLocation()
	local action, quest = self:GetObjectiveInfo()
	self:Debug(string.format("Detected setting hearth to %q", loc))
	self.db.char.hearth = loc
	if action == "SETHEARTH" and loc == quest then self:SetTurnedIn() end
end

function AegisPathfinder:CHAT_MSG_SYSTEM(msg)
	local action, quest = self:GetObjectiveInfo()

	if action == "PET" then
		local _, _, text = string.find(msg, L["You have learned a new spell: (.*)."])
		local nextEntry = table.getn(self.db.char.petskills) + 1
		self.db.char.petskills[nextEntry] = text
		if text and quest == text then
			self:Debug(string.format("Detected pet skill train %q", quest))
			return self:SetTurnedIn()
		end
	end
end

--- Who died, from the combat log: "<name> dies." (UNITDIESOTHER), "You have
--- slain <name>!" when the killing blow is yours (SELFKILLOTHER), or "<name>
--- is slain by <who>!" (PARTYKILLOTHER); nil for any other line.
function AegisPathfinder:DeathName(msg)
	if not msg then return end
	local formats = { UNITDIESOTHER or "%s dies.", SELFKILLOTHER or "You have slain %s!",
		PARTYKILLOTHER or "%s is slain by %s!" }
	for _, format in ipairs(formats) do
		-- The name is the first %s; any other is someone else.
		local pattern, first = string.gsub(format, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"), true
		pattern = string.gsub(pattern, "%%s", function()
			if first then first = false return "(.+)" end
			return ".+"
		end)
		local _, _, name = string.find(msg, "^" .. pattern .. "$")
		if name then return name end
	end
end

--[[ A dungeon guide's boss step (|BOSS|) ticks itself when the boss dies: the
	first step not yet ticked that names it, which is the one for this visit
	when a guide goes in more than once. ]]
function AegisPathfinder:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
	local name = self:DeathName(msg)
	if not name or not self.actions or not self.turnedin then return end
	for i in ipairs(self.actions) do
		local list = self:GetObjectiveTag("BOSS", i)
		if list and not self.turnedin[self.quests[i]] then
			for boss in string.gfind(list, "[^;]+") do
				if boss == name then
					self:Debug(string.format("Detected the death of %q", name))
					return self:SetTurnedIn(i, true)
				end
			end
		end
	end
end

function AegisPathfinder:QUEST_WATCH_UPDATE(event)
	if self:GetObjectiveInfo() == "COMPLETE" then self:ScheduleStatusUpdate() end
end

function AegisPathfinder:QUEST_LOG_UPDATE(event)
	local action = self:GetObjectiveInfo()
	local _, logi, complete = self:GetObjectiveStatus()

	self:Debug("QUEST_LOG_UPDATE", action, logi, complete)

	-- A header collapsed over one of the guide's quests (GuideEngine.lua).
	if self:RevealGuideQuests() then self:ScheduleStatusUpdate() end

	-- UpdateStatusFrame gates on the delayed step itself, so run it whenever a
	-- delayed update is pending; checking the current step's logi here would
	-- miss turnins recorded for a step other than the current one. A travel
	-- step is done once its |QID| quest is in the log, and an optional one
	-- once the step after it is done (PassedTravel): Teldrassil's "Gnarlpine
	-- Hold" stayed on after The Glowing Fruit was taken, as nothing rescanned.
	if self.updatedelay or action == "ACCEPT" or action == "COMPLETE" or self:IsTravelStep() then
		self:ScheduleStatusUpdate()
	end

	if action == "KILL" or action == "NOTE" then
		local quest, questtext = self:GetObjectiveTag("Q"), self:GetObjectiveTag("QO")
		if not quest or not questtext then return end

		local qi = self:GetQuestLogIndexByName(quest)
		for i = 1, GetNumQuestLeaderBoards(qi) do
			if GetQuestLogLeaderBoard(i, qi) == questtext then self:SetTurnedIn() end
		end
	elseif action == "COMPLETE" then
		local skipNext = self:GetObjectiveTag("S")
		if self.db.char.skipfollowups and skipNext and QuestFrame:IsVisible() then
			CloseQuest()
			AegisPathfinder:Say(L["Automatically skipping the follow-up"])
		end
	end
end

function AegisPathfinder:UNIT_QUEST_LOG_CHANGED(unit)
	if unit ~= "player" then return end
	local action = self:GetObjectiveInfo()
	if action == "COMPLETE" then
		self:ScheduleStatusUpdate()
	end
end

-- Legacy BUY steps without an |L| tag can only be matched by looted item
-- name; |L|-tagged collect steps are counted in BAG_UPDATE_DELAYED instead
function AegisPathfinder:CHAT_MSG_LOOT(msg)
	local action, quest = self:GetObjectiveInfo()
	if action ~= "BUY" or self:GetObjectiveTag("L") then return end

	local _, _, _, name = string.find(msg, L["^You .*Hitem:(%d+).*(%[.+%])"])
	if name and string.sub(name, 2, -2) == quest then
		self:Debug(string.format("Detected buy %q", quest))
		self:SetTurnedIn()
	end
end

-- Fires once per bag-content batch (ClassicAPI): loot, mail, trade, vendor,
-- AH. Count |L|-tagged collect steps by itemID instead of parsing loot
-- messages; this also catches items that never produce a loot message.
function AegisPathfinder:BAG_UPDATE_DELAYED()
	local action = self:GetObjectiveInfo()
	if action ~= "BUY" and action ~= "KILL" and action ~= "NOTE" and action ~= "COMPLETE" then return end

	local lootitem, lootqty = self:GetLootRequirement()
	if not lootitem then return end

	if C_Item.GetItemCount(lootitem) >= lootqty then
		self:Debug(string.format("Detected item count met %s x%d", lootitem, lootqty))
		self:SetTurnedIn()
	end
end

function AegisPathfinder:PLAYER_DEAD()
	if self:GetObjectiveInfo() == "DIE" then
		self:Debug("Player has died")
		self:SetTurnedIn()
	end
end

function AegisPathfinder:UI_INFO_MESSAGE(msg)
	if msg == ERR_NEWTAXIPATH and self:GetObjectiveInfo() == "GETFLIGHTPOINT" then
		self:Debug("Discovered flight point")
		self:SetTurnedIn()
	end
end

-- Detect NPC interaction for GETFLIGHTPOINT objectives
local flightEventFrame = CreateFrame("Frame")
flightEventFrame:RegisterEvent("TAXIMAP_OPENED")
flightEventFrame:RegisterEvent("GOSSIP_SHOW")
flightEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
flightEventFrame:SetScript("OnEvent", function()
	if AegisPathfinder:GetObjectiveInfo() ~= "GETFLIGHTPOINT" then return end

	if event == "TAXIMAP_OPENED" or event == "GOSSIP_SHOW" then
		AegisPathfinder:Debug(event .. " - completing GETFLIGHTPOINT")
		AegisPathfinder:SetTurnedIn()
	elseif event == "PLAYER_TARGET_CHANGED" then
		-- Check if targeting a friendly NPC (likely the flight master)
		if UnitExists("target") and not UnitIsPlayer("target") and not UnitCanAttack("player", "target") then
			AegisPathfinder:Debug("Targeted friendly NPC - completing GETFLIGHTPOINT")
			AegisPathfinder:SetTurnedIn()
		end
	end
end)


function AegisPathfinder:CRAFT_SHOW()
	if not GetCraftName() == "Beast Training" then return end
	for i = 1, GetNumCrafts() do
		local name, rank = GetCraftInfo(i)
		self.db.char.petskills[name .. (rank == "" and "" or (" (" .. rank .. ")"))] = true
	end
	if self:GetObjectiveInfo() == "PET" then self:UpdateStatusFrame() end
end

-- During NPC interaction self.current lags behind: the advance past a
-- just-finished step happens on the next quest log update, often after the
-- follow-up QUEST_DETAIL or reopened gossip has already fired. Resolve the
-- first step at or after current that is not already turned in, so automation
-- never keys off a stale step. A travel step is passed too: talking to the
-- next step's NPC, or clicking its object, means you got there.
local function PendingStep()
	local i = AegisPathfinder.current
	if not i or not AegisPathfinder.actions then return end
	while AegisPathfinder.actions[i] and (AegisPathfinder:GetObjectiveStatus(i) or AegisPathfinder:IsTravelStep(i)) do
		i = i + 1
	end
	if AegisPathfinder.actions[i] then return i end
end

-- Returns the clean quest name and step index when the pending step matches
-- the action
local function CurrentStepName(action)
	local i = PendingStep()
	if not i then return end
	local a, quest = AegisPathfinder:GetObjectiveInfo(i)
	if a ~= action or not quest then return end
	return (string.gsub(quest, L.PART_GSUB, "")), i
end

-- Quest accept detection. QUEST_ACCEPTED carries the questID, so ACCEPT steps
-- match by |QID| tag instead of parsing the "Quest accepted:" system message.
function AegisPathfinder:QUEST_ACCEPTED(questLogIndex, questID)
	questID = tonumber(questID)
	self:Debug("QUEST_ACCEPTED", questLogIndex, questID)
	if not questID then return end

	local quest, i = CurrentStepName("ACCEPT")
	if not quest then return end

	local qid = tonumber((self:GetObjectiveTag("QID", i)))
	if qid then
		if qid == questID then
			self:Debug(string.format("Detected quest accept by QID %d %q", questID, quest))
			self:UpdateStatusFrame()
		end
		return
	end

	-- Step has no |QID| tag; compare titles instead
	local title = C_QuestLog.GetTitleForQuestID(questID)
	if title and quest == title then
		self:Debug(string.format("Detected quest accept %q", quest))
		self:UpdateStatusFrame()
	end
end

-- Quest turnin tracking. QUEST_TURNED_IN fires on server confirmation and
-- carries the questID, so it also catches turnins for quests outside the
-- loaded guide.
function AegisPathfinder:QUEST_TURNED_IN(questID, xpReward, moneyReward)
	questID = tonumber(questID)
	self:Debug("QUEST_TURNED_IN", questID, xpReward, moneyReward)
	if not questID then return end

	self.db.char.completedquestsbyid[questID] = true

	if not self:CompleteQuestByQid(questID, true) then
		-- No |QID| match in the guide; track and match by title instead
		local title = C_QuestLog.GetTitleForQuestID(questID)
		if title then
			self.db.char.completedquests[title] = true
			self:CompleteQuest(title, true)
		end
	end

	-- The quest is usually still in the log here; the removal arrives via
	-- the follow-up log update and fires QUEST_REMOVED, which advances.
	-- This covers the other ordering, should a server remove it inline.
	if self.current and not C_QuestLog.IsOnQuest(questID) then
		self:UpdateStatusFrame()
	end
end

-- Quest left the log (ClassicAPI event; fires for turn-ins and abandons).
-- For turn-ins it follows QUEST_TURNED_IN, so the step is already marked
-- and the removal is the moment the delayed update can advance. A removal
-- with no turn-in confirmation is an abandon: rescan so the guide routes
-- back to the abandoned quest's accept step.
function AegisPathfinder:QUEST_REMOVED(questID)
	questID = tonumber(questID)
	self:Debug("QUEST_REMOVED", questID)
	if not questID then return end

	if self.db.char.completedquestsbyid[questID] then
		if self.current then self:UpdateStatusFrame() end
		return
	end

	-- Grace period in case a late QUEST_TURNED_IN is still in flight
	C_Timer.After(0.5, function()
		if not self.current or not self.actions then return end
		if self.db.char.completedquestsbyid[questID] then return end
		self:Debug(string.format("QID %d abandoned - rescanning", questID))
		self:UpdateStatusFrame()
	end)
end


---------------------------------
--  Quest automation           --
---------------------------------

-- Hold SHIFT while talking to an NPC to suspend automation
local function AutomationSuspended()
	return not AegisPathfinder.db.char.autoquest or IsShiftKeyDown()
end

--[[ The Automation page's two under it: "All quests, not only the guide's",
	and picking the guide's quest from an NPC's list (on unless switched off;
	it governs every pick from a list, all quests' too). ]]
local function AllQuests() return AegisPathfinder.db.char.allquests end
local function PicksFromList() return AegisPathfinder.db.char.autogossip ~= false end

-- MAX_QUESTLOG_QUESTS less two: all quests leaves room for the guide's.
local QUEST_ROOM = 18

--[[ A quest worth taking for all quests: not grey to you -- the grey line by
	level, as the client draws it -- and with room in the log to spare. ]]
local function WorthTaking(questLevel)
	local _, quests = GetNumQuestLogEntries()
	if (quests or 0) >= QUEST_ROOM then return false end
	local level = UnitLevel("player") or 1
	local grey
	if level <= 5 then grey = 0
	elseif level <= 39 then grey = level - math.floor(level / 10) - 5
	elseif level <= 59 then grey = level - math.floor(level / 5) - 1
	else grey = level - 9 end
	return not questLevel or questLevel > grey
end

-- Quest frame titles may carry a [level] prefix depending on server settings
local function QuestFrameTitle()
	return (string.gsub(GetTitleText() or "", "%[[0-9%+%-]+]%s", ""))
end

-- Auto-select the pending step's quest from the gossip list, matched by QID
-- (by title for untagged steps)
function AegisPathfinder:GOSSIP_SHOW()
	if AutomationSuspended() or not PicksFromList() then return end

	local name, i = CurrentStepName("ACCEPT")
	if name then
		local qid = tonumber((self:GetObjectiveTag("QID", i)))
		for _, q in ipairs(C_GossipInfo.GetAvailableQuests()) do
			if qid == q.questID or (not qid and q.title == name) then
				self:Debug(string.format("Auto-selecting available quest %d %q", q.questID, q.title))
				return C_GossipInfo.SelectAvailableQuest(q.questID)
			end
		end
	end

	name, i = CurrentStepName("TURNIN")
	if name then
		local qid = tonumber((self:GetObjectiveTag("QID", i)))
		for _, q in ipairs(C_GossipInfo.GetActiveQuests()) do
			if q.isComplete and (qid == q.questID or (not qid and q.title == name)) then
				self:Debug(string.format("Auto-selecting active quest %d %q", q.questID, q.title))
				return C_GossipInfo.SelectActiveQuest(q.questID)
			end
		end
	end

	-- All quests: a finished one to hand in first, then one on offer.
	if not AllQuests() then return end
	for _, q in ipairs(C_GossipInfo.GetActiveQuests()) do
		if q.isComplete then return C_GossipInfo.SelectActiveQuest(q.questID) end
	end
	for _, q in ipairs(C_GossipInfo.GetAvailableQuests()) do
		if WorthTaking(q.questLevel) then return C_GossipInfo.SelectAvailableQuest(q.questID) end
	end
end

-- Greeting panel (quest NPCs without gossip text). The greeting API is
-- index-based and carries no questIDs, so titles are the only match key.
function AegisPathfinder:QUEST_GREETING()
	if AutomationSuspended() or not PicksFromList() then return end

	local name = CurrentStepName("ACCEPT")
	if name then
		for i = 1, GetNumAvailableQuests() do
			if GetAvailableTitle(i) == name then
				self:Debug(string.format("Auto-selecting available quest (greeting) %q", name))
				return SelectAvailableQuest(i)
			end
		end
	end

	name = CurrentStepName("TURNIN")
	if name then
		for i = 1, GetNumActiveQuests() do
			if GetActiveTitle(i) == name then
				self:Debug(string.format("Auto-selecting active quest (greeting) %q", name))
				return SelectActiveQuest(i)
			end
		end
	end

	--[[ All quests. The greeting's own API has titles alone; ClassicAPI's
		lists say which are finished and at what level, and are matched back
		to the greeting's rows by title. ]]
	if not AllQuests() then return end
	local done, levels = {}, {}
	for _, q in ipairs(C_GossipInfo.GetActiveQuests()) do if q.isComplete then done[q.title] = true end end
	for _, q in ipairs(C_GossipInfo.GetAvailableQuests()) do levels[q.title] = q.questLevel end
	for i = 1, GetNumActiveQuests() do
		if done[GetActiveTitle(i)] then return SelectActiveQuest(i) end
	end
	for i = 1, GetNumAvailableQuests() do
		if WorthTaking(levels[GetAvailableTitle(i)]) then return SelectAvailableQuest(i) end
	end
end

function AegisPathfinder:QUEST_DETAIL()
	if not AutomationSuspended() then
		local name = CurrentStepName("ACCEPT")
		if name and QuestFrameTitle() == name then
			self:Debug(string.format("Auto-accepting %q", name))
			AcceptQuest()
		elseif AllQuests() and WorthTaking(nil) then
			self:Debug(string.format("Auto-accepting %q (all quests)", QuestFrameTitle()))
			AcceptQuest()
		end
	end
	self:UpdateStatusFrame()
end

function AegisPathfinder:QUEST_PROGRESS()
	if AutomationSuspended() then return end
	local name = CurrentStepName("TURNIN")
	if ((name and QuestFrameTitle() == name) or AllQuests()) and IsQuestCompletable() then
		self:Debug(string.format("Auto-completing %q", QuestFrameTitle()))
		CompleteQuest()
	end
end

-- Claim the reward when there is no choice to make; with a choice, the Gear
-- Advisor takes the best one if it has been asked to (GearAdvisor.lua).
function AegisPathfinder:QUEST_COMPLETE()
	if not AutomationSuspended() then
		local name = CurrentStepName("TURNIN")
		local ours = (name and QuestFrameTitle() == name) or AllQuests()
		if ours and GetNumQuestChoices() <= 1 then
			self:Debug(string.format("Auto-claiming reward for %q", QuestFrameTitle()))
			GetQuestReward(GetNumQuestChoices())
		elseif ours and self.GearAdvisor then
			self.GearAdvisor:MarkReward(true)
		end
	end
	self:UpdateStatusFrame()
end

-- The quest windows outlive the step that opened them: a follow-up
-- QUEST_DETAIL or reopened gossip arrives before the status frame advances
-- past the finished step, and no further event fires once it does. Called
-- from UpdateStatusFrame after the step advances to feed the still-open
-- window back through the handlers above.
local redriving
function AegisPathfinder:RedriveQuestAutomation()
	if redriving or AutomationSuspended() then return end
	redriving = true
	if GossipFrame and GossipFrame:IsVisible() then
		self:GOSSIP_SHOW()
	elseif QuestFrame and QuestFrame:IsVisible() then
		if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() then
			self:QUEST_GREETING()
		elseif QuestFrameDetailPanel:IsVisible() then
			self:QUEST_DETAIL()
		elseif QuestFrameProgressPanel:IsVisible() then
			self:QUEST_PROGRESS()
		elseif QuestFrameRewardPanel:IsVisible() then
			self:QUEST_COMPLETE()
		end
	end
	redriving = false
end


-- Hook UseContainerItem to detect USE objective completion
local origUseContainerItem = UseContainerItem
UseContainerItem = function(bag, slot, ...)
	local action = AegisPathfinder:GetObjectiveInfo()
	local useitem = AegisPathfinder:GetObjectiveTag("U")

	if action == "USE" and useitem and C_Container.GetContainerItemID(bag, slot) == tonumber(useitem) then
		AegisPathfinder:Debug("Detected USE item from bag: " .. useitem)
		-- Delay slightly to allow the item use to complete
		C_Timer.After(0.3, function()
			if AegisPathfinder:GetObjectiveInfo() == "USE" then
				AegisPathfinder:Debug("Completing USE objective after item use")
				AegisPathfinder:SetTurnedIn()
			end
		end)
	end

	return origUseContainerItem(bag, slot, unpack(arg))
end


-- Distance-based arrival detection for travel objectives. Runs for every
-- waypoint provider: only TomTom offers arrival callbacks of its own, and this
-- check is cheap enough to run alongside them.
local ARRIVAL_CHECK_INTERVAL = 0.5 -- Check every 0.5 seconds
local ARRIVAL_DISTANCE = 0.005     -- Map coordinate distance threshold (~15-18 yards)
-- A point on a continent's map (RestedXP's "Travel to Kalimdor" steps) is
-- written to a tenth of a percent of the whole continent, up to twenty yards
-- out, so it is measured in yards with room for that.
local CONTINENT_ARRIVAL_YARDS = 30

-- Zone name to continent/zone index lookup (built from Navigation.lua pattern)
local zonei, zonec, continents = {}, {}, {}
for ci, c in pairs({ GetMapContinents() }) do
	continents[c] = ci
	for zi, z in pairs({ GetMapZones(ci) }) do
		zonei[z], zonec[z] = zi, ci
	end
end

-- Check if current objective completion conditions are already met
local function RecheckCurrentObjective()
	if not AegisPathfinder.current or not AegisPathfinder.actions then return end

	local action = AegisPathfinder:GetObjectiveInfo()
	if not action then return end

	AegisPathfinder:Debug("Rechecking completion for: " .. action)

	-- GETFLIGHTPOINT: Check if targeting friendly NPC
	if action == "GETFLIGHTPOINT" then
		if UnitExists("target") and not UnitIsPlayer("target") and not UnitCanAttack("player", "target") then
			AegisPathfinder:Debug("Recheck: Already targeting friendly NPC - completing GETFLIGHTPOINT")
			AegisPathfinder:SetTurnedIn()
			return
		end
	end

	-- Travel objectives: Will be caught by the distance check below
end

C_Timer.NewTicker(ARRIVAL_CHECK_INTERVAL, function()
	-- Flush an expired delayed update even when no quest events arrive;
	-- UpdateStatusFrame clears updatedelay once its gate passes
	if AegisPathfinder.updatedelay and GetTime() - (AegisPathfinder.updatedelaytime or 0) >= 3 then
		AegisPathfinder:ScheduleStatusUpdate()
	end

	-- Check if we need to re-evaluate after rewind
	if AegisPathfinder.recheckCompletion then
		AegisPathfinder.recheckCompletion = nil
		RecheckCurrentObjective()
	end

	-- Only check if guide is loaded
	if not AegisPathfinder.current or not AegisPathfinder.actions then return end

	local action, quest = AegisPathfinder:GetObjectiveInfo()
	if not action then return end

	-- Only check for travel/arrival objectives
	if action ~= "RUN" and action ~= "FLY" and action ~= "HEARTH" and action ~= "BOAT" and action ~= "GETFLIGHTPOINT" then return end

	-- Get target coordinates from note
	local note = AegisPathfinder:GetObjectiveTag("N")
	if not note then return end

	local targetX, targetY
	for x, y in string.gfind(note, L.COORD_MATCH) do
		targetX, targetY = tonumber(x) / 100, tonumber(y) / 100
		break -- Use first coordinate found
	end

	if not targetX or not targetY then return end

	-- Get target zone
	local targetZone = AegisPathfinder:GetObjectiveTag("Z") or AegisPathfinder.zonename

	--[[ A point on a continent's map. Read against the map of the zone you
		are in, the same numbers are another place entirely, and a step
		could tick there. Astrolabe measures it; without Astrolabe it is
		left to the waypoint addon. ]]
	local targetC = targetZone and continents[targetZone]
	if targetC then
		if not (Astrolabe and Astrolabe.GetCurrentPlayerPosition and Astrolabe.ComputeDistance) then return end
		local ok, pc, pz, px, py = pcall(Astrolabe.GetCurrentPlayerPosition, Astrolabe)
		if not ok or not pc or pc == 0 or not px then return end
		local ok2, yards = pcall(Astrolabe.ComputeDistance, Astrolabe, pc, pz, px, py, targetC, 0, targetX, targetY)
		-- 0 is Astrolabe's answer for a map it has no dimensions for
		if ok2 and yards and yards > 0 and yards <= CONTINENT_ARRIVAL_YARDS then
			AegisPathfinder:Debug(string.format("Arrived on the %s map: %.0f yd from target", targetZone, yards))
			AegisPathfinder:SetTurnedIn()
		end
		return
	end

	-- Get player position safely without interrupting the map view if open
	local playerC, playerZ, playerX, playerY
	local wasShown = WorldMapFrame:IsShown()

	if wasShown then
		-- If map is open, check if it's currently showing the player's zone
		local currentZoneName = GetRealZoneText()
		local playerZC, playerZI = zonec[currentZoneName], zonei[currentZoneName]
		local mapC, mapZ = GetCurrentMapContinent(), GetCurrentMapZone()

		if playerZC and playerZI and mapC == playerZC and mapZ == playerZI then
			playerC, playerZ = mapC, mapZ
			playerX, playerY = GetPlayerMapPosition("player")
		else
			-- Player is looking at a different map or zoomed out, skip check to avoid resetting their view
			return
		end
	else
		-- Map is hidden, safe to set to current zone and get position
		SetMapToCurrentZone()
		playerC, playerZ = GetCurrentMapContinent(), GetCurrentMapZone()
		playerX, playerY = GetPlayerMapPosition("player")
	end

	-- If target zone is specified, check we're in the right zone
	if targetZone then
		local targetZI, targetZC = zonei[targetZone], zonec[targetZone]
		if targetZC and targetZI and (playerC ~= targetZC or playerZ ~= targetZI) then
			return -- Not in target zone yet
		end
	end

	-- Skip if we couldn't get player position
	if playerX == 0 and playerY == 0 then return end

	-- Calculate distance (simple Euclidean in map coordinates)
	local dx, dy = playerX - targetX, playerY - targetY
	local distance = math.sqrt(dx * dx + dy * dy)

	if distance <= ARRIVAL_DISTANCE then
		AegisPathfinder:Debug(string.format("Arrived at destination: %.3f from target (threshold %.3f)", distance,
			ARRIVAL_DISTANCE))
		AegisPathfinder:SetTurnedIn()
	end
end)
