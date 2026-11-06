local L = AceLibrary("AceLocale-2.2"):new("Altoholic")
local V = Altoholic.vars
local WHITE		= "|cFFFFFFFF"
local RED		= "|cFFFF0000"
local GREEN		= "|cFF00FF00"
local TEAL		= "|cFF00FF9A"

function Altoholic:Quests_Update()
	local raw = Altoholic:ResolveLinkedChar(V.CurrentFaction, V.CurrentRealm, V.CurrentLinkedAccount, V.CurrentAlt)
	local c = { questlog = (raw and raw.questlog) or {} }
	local VisibleLines = 14
	local frame = "AltoQuests"
	local entry = frame.."Entry"
	local nameSuffix = ""
	if V.CurrentLinkedAccount then
		nameSuffix = " (" .. V.CurrentLinkedAccount .. ")"
	end
	if table.getn(c.questlog) == 0 then
		getglobal("AltoholicFrame_Status"):SetText("|cFFFFD700" .. V.CurrentAlt .. " of ".. V.CurrentRealm .. nameSuffix .. " |cFFFFFFFF" .. "No quests found")
		getglobal("AltoholicFrame_Status"):Show()
		self:ClearScrollFrame(getglobal(frame.."ScrollFrame"), entry, VisibleLines, 18)
		return
	else
		getglobal("AltoholicFrame_Status"):SetText("|cFFFFD700" .. V.CurrentAlt .. " of ".. V.CurrentRealm .. nameSuffix .. " |cFFFFFFFF" .. QUEST_LOG)
		getglobal("AltoholicFrame_Status"):Show()
	end
	local offset = FauxScrollFrame_GetOffset(getglobal(frame.."ScrollFrame"));
	local DisplayedCount = 0
	local VisibleCount = 0
	local DrawGroup
	local i=1
	for line, s in pairs(c.questlog) do
		if (offset > 0) or (DisplayedCount >= VisibleLines) then
			if s.isHeader then
				if not s.isCollapsed then
					DrawGroup = true
				else
					DrawGroup = false
				end
				VisibleCount = VisibleCount + 1
				offset = offset - 1
			elseif DrawGroup then
				VisibleCount = VisibleCount + 1
				offset = offset - 1
			end
		else
			if s.isHeader then
				if not s.isCollapsed then
					getglobal(entry..i.."Collapse"):SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up"); 
					DrawGroup = true
				else
					getglobal(entry..i.."Collapse"):SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
					DrawGroup = false
				end
				getglobal(entry..i.."Collapse"):Show()
				getglobal(entry..i.."QuestLinkNormalText"):SetText(TEAL .. s.name)
				getglobal(entry..i.."QuestLink"):SetID(0)
				getglobal(entry..i.."QuestLink"):SetPoint("TOPLEFT", 25, 0)
				getglobal(entry..i.."Tag"):Hide()
				getglobal(entry..i.."Status"):Hide()
				getglobal(entry..i.."Money"):Hide()
				getglobal(entry..i):SetID(line)
				getglobal(entry..i):Show()
				i = i + 1
				VisibleCount = VisibleCount + 1
				DisplayedCount = DisplayedCount + 1
			elseif DrawGroup then
				getglobal(entry..i.."Collapse"):Hide()	
				local _, id, level = self:GetQuestDetails(s.link)
				getglobal(entry..i.."QuestLinkNormalText"):SetText(WHITE .. "[" .. s.level .. "] " .. s.link)
				getglobal(entry..i.."QuestLink"):SetID(line)
				getglobal(entry..i.."QuestLink"):SetPoint("TOPLEFT", 15, 0)
				if s.tag then 
					getglobal(entry..i.."Tag"):SetText(self:GetQuestTypeString(s.tag, self:SuggestGroupSize(s.tag, s.level)))
					getglobal(entry..i.."Tag"):Show()
				else
					getglobal(entry..i.."Tag"):Hide()
				end
				if s.isComplete then
					if s.isComplete == 1 then
						getglobal(entry..i.."Status"):SetText(GREEN .. COMPLETE)
					elseif s.isComplete == -1 then
						getglobal(entry..i.."Status"):SetText(RED .. FAILED)
					end
					getglobal(entry..i.."Status"):Show()
				else
					getglobal(entry..i.."Status"):Hide()
				end
				if s.money then
					getglobal(entry..i.."Money"):SetText(self:GetMoneyString(s.money))
					getglobal(entry..i.."Money"):Show()
				else
					getglobal(entry..i.."Money"):Hide()
				end
				getglobal(entry..i):SetID(line)
				getglobal(entry..i):Show()
				i = i + 1
				VisibleCount = VisibleCount + 1
				DisplayedCount = DisplayedCount + 1
			end
		end
	end 
	while i <= VisibleLines do
		getglobal(entry..i):SetID(0)
		getglobal(entry..i):Hide()
		i = i + 1
	end
	FauxScrollFrame_Update(getglobal(frame.."ScrollFrame"), VisibleCount, VisibleLines, 18);
end	

function Altoholic:GetQuestDetails(questString)
	if not questString then return nil end
	local _, _, questInfo, questName = Altoholic:strsplit("|", questString)
	local _, questId, questLevel = Altoholic:strsplit(":", questInfo)
	questName = string.sub(questName, 3, -2)
	return questName, questId, questLevel
end

function Altoholic:QuestLink_OnClick(button, id)
    if id == 0 then return end
    if ( button == "LeftButton" ) and ( IsShiftKeyDown() ) then
        local v = Altoholic.vars
        local c = Altoholic:ResolveLinkedChar(v.CurrentFaction, v.CurrentRealm, v.CurrentLinkedAccount, v.CurrentAlt)
        local entry = c and c.questlog and c.questlog[id]
        local link = entry and entry.link
        if not link then return end
        if ( ChatFrameEditBox:IsShown() ) then
            ChatFrameEditBox:Insert(link);
        elseif (WIM_EditBoxInFocus) then
            WIM_EditBoxInFocus:Insert(link);
        end
    end
end

function Altoholic:QuestLink_OnEnter(self)
	local id = self:GetID()
	if id == 0 then return end
	local c = Altoholic:ResolveLinkedChar(V.CurrentFaction, V.CurrentRealm, V.CurrentLinkedAccount, V.CurrentAlt)
	local o = c and c.questlog and c.questlog[id]
	local title = o and o.title
	if not title then return end
	GameTooltip:ClearLines();
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:AddLine("|cffffffff"..(o.questObjectives or "").."|r",1,1,1,true);
	-- "Are also on this quest" only cross-references this account's own
	-- local alts (self.db.account.data) -- doing the same for every linked
	-- account's quest log too is a real feature, not a safe default here,
	-- so it's simply skipped for a linked row rather than guessed at.
	if not V.CurrentLinkedAccount then
		local r = Altoholic.db.account.data[V.CurrentFaction][V.CurrentRealm]
		local questTitle = title
		local bOtherCharsOnQuest
		for CharacterName, c2 in pairs(r.char) do
			if CharacterName ~= V.CurrentAlt then
				for index, q in pairs(c2.questlog or {}) do
					local altQuestTitle = q.title
					if altQuestTitle == questTitle then
						if not bOtherCharsOnQuest then
							GameTooltip:AddLine(" ",1,1,1);
							GameTooltip:AddLine(GREEN .. L["Are also on this quest:"],1,1,1);
							bOtherCharsOnQuest = true
						end
						GameTooltip:AddLine(Altoholic:GetClassColor(c2.class) .. CharacterName,1,1,1);
					end
				end
			end
		end
	end
	GameTooltip:Show();
end

local function GetCurrentCharacter()
	return Altoholic.db.account.data[V.faction][V.realm].char[UnitName("player")]
end

local function CaptureCollapsedQuestHeaders()
	local collapsed = {}
	for i = 1, GetNumQuestLogEntries() do
		local title, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
		if title and isHeader and isCollapsed then
			collapsed[title] = true
		end
	end
	return collapsed
end

local function RestoreCollapsedQuestHeaders(collapsed)
	if not collapsed then return end
	-- Work upward because collapsing a header changes the indices below it.
	for i = GetNumQuestLogEntries(), 1, -1 do
		local title, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
		if title and isHeader and collapsed[title] and not isCollapsed then
			CollapseQuestHeader(i)
		elseif title and isHeader and not collapsed[title] and isCollapsed then
			ExpandQuestHeader(i)
		end
	end
end

local function RestoreQuestSelection(title)
	if not title then return end
	for i = 1, GetNumQuestLogEntries() do
		local rowTitle, _, _, isHeader = GetQuestLogTitle(i)
		if not isHeader and rowTitle == title then
			SelectQuestLogEntry(i)
			return
		end
	end
end

function Altoholic:SaveQuestLogCollapseState()
	local c = GetCurrentCharacter()
	if c then
		c.questlogCollapsedHeaders = CaptureCollapsedQuestHeaders()
	end
end

function Altoholic:UpdateQuestLog()
	local c = GetCurrentCharacter()
	if not c then return end

	-- Restore the last saved layout once per login before taking a fresh
	-- snapshot. Later scans preserve any changes made during this session.
	if not self.questLogCollapseInitialized then
		RestoreCollapsedQuestHeaders(c.questlogCollapsedHeaders)
		self.questLogCollapseInitialized = true
	end

	local collapsedHeaders = CaptureCollapsedQuestHeaders()
	c.questlogCollapsedHeaders = collapsedHeaders

	local oldSelection = GetQuestLogSelection()
	local selectedTitle
	if oldSelection and oldSelection > 0 then
		local title, _, _, isHeader = GetQuestLogTitle(oldSelection)
		if title and not isHeader then selectedTitle = title end
	end

	-- Altoholic needs every quest visible while it creates its character
	-- snapshot. Expand temporarily and restore the player's layout afterward.
	for i = GetNumQuestLogEntries(), 1, -1 do
		local _, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
		if isHeader and isCollapsed then ExpandQuestHeader(i) end
	end

	local q = {}
	for i = 1, GetNumQuestLogEntries() do
		q[i] = {}
		local title, level, questTag, isHeader, _, isComplete = GetQuestLogTitle(i)
		if not isHeader then
			-- Select the matching row before reading its text and reward data.
			SelectQuestLogEntry(i)
			local questDescription, questObjectives = GetQuestLogQuestText()
			q[i].title = title
			q[i].tag = questTag
			q[i].isComplete = isComplete
			q[i].link = "|cffffff00|Hquest:0:0:0:0|h[" .. title .. "]|h|r"
			q[i].level = level
			q[i].questDescription = questDescription
			q[i].questObjectives = questObjectives
			q[i].money = GetQuestLogRewardMoney()
		else
			q[i].name = title
			q[i].isHeader = true
			q[i].isCollapsed = collapsedHeaders[title] and true or false
		end
	end

	RestoreQuestSelection(selectedTitle)
	RestoreCollapsedQuestHeaders(collapsedHeaders)
	c.questlog = q
end

function Altoholic:SuggestGroupSize(tag, level)
    if tag == nil then return end

    if tag == "Elite" then
        return "2+"
    elseif tag == "Dungeon" then
        return "5"
    elseif tag == "PVP" then
        return "5+"
    elseif tag == "Raid" then
        return "10+"
    end
end

-- *** EVENT HANDLERS ***
function Altoholic:UNIT_QUEST_LOG_CHANGED()		-- triggered when accepting/validating a quest .. but too soon to refresh data
	self:RegisterEvent("QUEST_LOG_UPDATE")			-- so register for this one ..
end

function Altoholic:QUEST_LOG_UPDATE()
	self:UnregisterEvent("QUEST_LOG_UPDATE")		-- .. and unregister it right away, since we only want it to be processed once (and it's triggered way too often otherwise)
	self:UpdateQuestLog()	
end
