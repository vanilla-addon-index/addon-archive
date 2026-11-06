local BI = LibStub("LibBabble-Inventory-3.0"):GetLookupTable()
local L = AceLibrary("AceLocale-2.2"):new("Altoholic")
local V = Altoholic.vars
local INFO_REALM_LINE = 1
local INFO_CHARACTER_LINE = 2
local INFO_TOTAL_LINE = 3
local TEAL		= "|cFF00FF9A"
local WHITE		= "|cFFFFFFFF"
local GOLD		= "|cFFFFD700"
local GREEN		= "|cFF00FF00"

-- Character lookup for a row (local vs Link-synced) is shared with
-- Modules/Containers.lua via Altoholic:ResolveLinkedChar (Modules/LinkSync.lua).

function Altoholic:AccountSummary_Update()
	local VisibleLines = 14
	local frame = "AltoSummary"
	local entry = frame.."Entry"
	if table.getn(self.CharacterInfo) == 0 then
		self:ClearScrollFrame(getglobal(frame.."ScrollFrame"), entry, VisibleLines, 18)
		return
	end
	local offset = FauxScrollFrame_GetOffset(getglobal(frame.."ScrollFrame"));
	local DisplayedCount = 0
	local VisibleCount = 0
	local DrawRealm
	local CurrentFaction, CurrentRealm, CurrentLinkedAccount
	local i=1
	for line, s in pairs(self.CharacterInfo) do
		if (offset > 0) or (DisplayedCount >= VisibleLines) then		-- if the line will not be visible
			if s.linetype == INFO_REALM_LINE then								-- then keep track of counters
				CurrentFaction = s.faction
				CurrentRealm = s.realm
				CurrentLinkedAccount = s.linkedAccount
				if not s.isCollapsed then
					DrawRealm = true
				else
					DrawRealm = false
				end
				VisibleCount = VisibleCount + 1
				offset = offset - 1		-- no further control, nevermind if it goes negative
			elseif DrawRealm then
				VisibleCount = VisibleCount + 1
				offset = offset - 1		-- no further control, nevermind if it goes negative
			end
		else		-- line will be displayed
			if s.linetype == INFO_REALM_LINE then
				CurrentFaction = s.faction
				CurrentRealm = s.realm
				CurrentLinkedAccount = s.linkedAccount
				if not s.isCollapsed then
					getglobal(entry..i.."Collapse"):SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up");
					DrawRealm = true
				else
					getglobal(entry..i.."Collapse"):SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
					DrawRealm = false
				end
				getglobal(entry..i.."Collapse"):Show()
				local realmText = self:GetFullRealmString(s.faction, s.realm)
				if s.linkedAccount then
					realmText = realmText .. " (" .. s.linkedAccount .. ")"
				end
				getglobal(entry..i.."Name"):SetText(realmText)
				getglobal(entry..i.."Name"):SetJustifyH("LEFT")
				getglobal(entry..i.."Name"):SetPoint("TOPLEFT", 25, 0)
				getglobal(entry..i.."Name"):SetWidth(210)
				getglobal(entry..i.."LevelNormalText"):SetText("")
				getglobal(entry..i.."Talents"):SetText("")
				getglobal(entry..i.."Money"):SetText("")
				getglobal(entry..i.."Played"):SetText("")
				getglobal(entry..i.."Rested"):SetText("")
				getglobal(entry..i):SetID(line)
				getglobal(entry..i):Show()
				i = i + 1
				VisibleCount = VisibleCount + 1
				DisplayedCount = DisplayedCount + 1
			elseif DrawRealm then
				if (s.linetype == INFO_CHARACTER_LINE) then
					-- A resolved record -- local or linked -- can still be
					-- missing individual fields (a barely-played alt that's
					-- never triggered PLAYER_MONEY, a stub entry, etc), not
					-- just be missing outright, so default per-field rather
					-- than only guarding the "nothing found at all" case.
					-- level must stay numeric even as a placeholder: it
					-- feeds GetRestedXP -> GetRestXPRate's
					-- self.XPToNext[level] arithmetic, and a non-numeric
					-- value (e.g. "?") makes that lookup nil and crashes on
					-- the divide.
					local raw = Altoholic:ResolveLinkedChar(CurrentFaction, CurrentRealm, CurrentLinkedAccount, s.name)
					local c = {
						class = (raw and raw.class) or "",
						race = (raw and raw.race) or "",
						level = (raw and raw.level) or 1,
						talent = (raw and raw.talent) or "",
						money = (raw and raw.money) or 0,
						played = (raw and raw.played) or 0,
						restxp = raw and raw.restxp,
						isResting = raw and raw.isResting,
						lastlogout = (raw and raw.lastlogout) or 0,
					}
					local color = self:GetClassColor(c.class)
					getglobal(entry..i.."Collapse"):Hide()
					getglobal(entry..i.."Name"):SetText(color .. s.name)
					getglobal(entry..i.."Name"):SetJustifyH("RIGHT")
					getglobal(entry..i.."Name"):SetPoint("TOPLEFT", 15, 0)
					getglobal(entry..i.."Name"):SetWidth(70)
					getglobal(entry..i.."LevelNormalText"):SetText(color .. "Lv |cFF00FF00" .. c.level .. color .. " " .. c.race .. " " .. c.class)
					getglobal(entry..i.."LevelNormalText"):SetJustifyH("LEFT")
					getglobal(entry..i.."Talents"):SetText(c.talent)
					getglobal(entry..i.."Money"):SetText(self:GetMoneyString(c.money))
					getglobal(entry..i.."Played"):SetText(self:GetTimeString(c.played))
					local restXP
					if s.name == V.player then
						restXP = self:GetRestedXP(c.level, c.restxp, 0, c.isResting)
					else
						restXP = self:GetRestedXP(c.level, c.restxp, c.lastlogout, c.isResting)
					end
					getglobal(entry..i.."Rested"):SetText(restXP)
				elseif (s.linetype == INFO_TOTAL_LINE) then
					getglobal(entry..i.."Collapse"):Hide()
					getglobal(entry..i.."Name"):SetText(L["Totals"])
					getglobal(entry..i.."Name"):SetJustifyH("LEFT")
					getglobal(entry..i.."Name"):SetPoint("TOPLEFT", 15, 0)
					getglobal(entry..i.."Name"):SetWidth(70)
					getglobal(entry..i.."LevelNormalText"):SetText(s.level)
					getglobal(entry..i.."LevelNormalText"):SetJustifyH("RIGHT")
					getglobal(entry..i.."Talents"):SetText("")
					getglobal(entry..i.."Money"):SetText(s.money)
					getglobal(entry..i.."Money"):SetTextColor(1.0, 1.0, 1.0)
					getglobal(entry..i.."Played"):SetText(s.played)
					getglobal(entry..i.."Rested"):SetText("")
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

function Altoholic_AccountSummaryLevel_OnEnter(self)
	local line = self:GetParent():GetID()
	local s = Altoholic.CharacterInfo[line]
	if s.linetype ~= INFO_CHARACTER_LINE then		
		return
	end
	local Faction, Realm, LinkedAccount = Altoholic:GetCharacterInfo(line)
	local raw = Altoholic:ResolveLinkedChar(Faction, Realm, LinkedAccount, s.name)
	if not raw then return end
	-- Same reasoning as AccountSummary_Update: a resolved record can still
	-- be missing individual fields, local or linked.
	local c = {
		class = raw.class or "",
		race = raw.race or "",
		level = raw.level or 1,
		zone = raw.zone or "",
		subzone = raw.subzone or "",
		restxp = raw.restxp,
		SavedInstance = raw.SavedInstance,
		pvp_ArenaPoints = raw.pvp_ArenaPoints,
		pvp_hk = raw.pvp_hk,
		pvp_HonorPoints = raw.pvp_HonorPoints,
		pvp_dk = raw.pvp_dk,
	}
	local suggestion = Altoholic:GetSuggestion("Leveling", c.level)
	AltoTooltip:ClearLines();
	AltoTooltip:SetOwner(self, "ANCHOR_RIGHT");
	AltoTooltip:AddLine(Altoholic:GetClassColor(c.class) .. s.name,1,1,1);
	AltoTooltip:AddLine(L["Level"] .. " " .. GREEN .. c.level .. " |r".. c.race .. " " .. c.class,1,1,1);
	AltoTooltip:AddLine(L["Zone"] .. ": " .. GOLD .. c.zone .. " |r(" .. GOLD .. c.subzone .."|r)",1,1,1);
	if c.restxp then
		AltoTooltip:AddLine(L["Rest XP"] .. ": " .. GREEN .. c.restxp,1,1,1);
	end
	if suggestion then
		AltoTooltip:AddLine(" ",1,1,1);
		AltoTooltip:AddLine(L["Suggested leveling zone: "],1,1,1);
		AltoTooltip:AddLine(TEAL .. suggestion,1,1,1);
	end
	-- parse saved instances
	-- SavedInstance (and the pvp_* fields below) are nil rather than an
	-- empty table when a character has simply never touched that system --
	-- AceDB's own metatable normally auto-vivifies these to {} on first
	-- local access, but a linked account's data is a plain deserialized
	-- table with no such magic, so the gap that was always latent here
	-- only actually surfaces for linked characters.
	local bLineBreak = true
	for InstanceName, InstanceInfo in pairs (c.SavedInstance or {}) do
		if bLineBreak then
			AltoTooltip:AddLine(" ",1,1,1);		-- add a line break only once
			bLineBreak = nil
		end
		if type(InstanceInfo) == "string" then		-- temporary check, can be removed in .014, this is for players who might have saved instance data stored as table
			local id, reset, lastcheck = Altoholic:strsplit("|", InstanceInfo)
			reset = tonumber(reset)
			lastcheck = tonumber(lastcheck)
			local expiresIn = reset - (time() - lastcheck)
			if expiresIn > 0 then
				AltoTooltip:AddDoubleLine(GOLD .. InstanceName .. 
					" (".. WHITE.."ID: " .. GREEN .. id .. "|r)", Altoholic:GetTimeString(expiresIn))
			end
		end
	end
	-- add PVP info if any
	AltoTooltip:AddLine(" ",1,1,1);
	AltoTooltip:AddDoubleLine(WHITE.. L["Arena points: "] .. GREEN .. (c.pvp_ArenaPoints or 0), "HK: " .. GREEN .. (c.pvp_hk or 0) )
	AltoTooltip:AddDoubleLine(WHITE.. L["Honor points: "] .. GREEN .. (c.pvp_HonorPoints or 0), "DK: " .. GREEN .. (c.pvp_dk or 0) )
	AltoTooltip:Show();
end

function Altoholic_AccountSummaryLevel_OnClick(button, id)
    if not this then return end
	local line = this:GetParent():GetID()
	if line == 0 then return end
	local s = Altoholic.CharacterInfo[line]
	if s.linetype ~= INFO_CHARACTER_LINE then
		return
	end
	local Faction, Realm, LinkedAccount = Altoholic:GetCharacterInfo(line)
	-- Linked-account rows (Modules/LinkSync.lua) are a read-only mirror of
	-- another account's data, so the right-click menu is allowed to open
	-- for them, but "Delete this Alt" (Altoholic_DeleteAlt) refuses on its
	-- own when the target is linked -- there's nothing else here to guard,
	-- every "View X" module reads through Altoholic:ResolveLinkedChar.
	if button == "RightButton" then
		V.CharInfoLine = line	-- line containing info about the alt on which action should be taken (delete, ..)
		ToggleDropDownMenu(1, nil, AltoSummaryRightClickMenu, this:GetName(), 0, -5);
		return
	elseif button == "LeftButton" then
		V.CurrentFaction, V.CurrentRealm = Faction, Realm
		V.CurrentLinkedAccount = LinkedAccount
		V.CurrentAlt = s.name
		Altoholic:UpdateContainerCache()
		Altoholic:ClearScrollFrame(getglobal("AltoContainersScrollFrame"), "AltoContainersEntry", 7, 41)
		Altoholic:ActivateMenuItem("AltoContainers")
	end
end

function Summary_RightClickMenu_OnLoad()
	local info = Altoholic_UIDropDownMenu_CreateInfo(); 
	info.text		= L["View bags"]
	info.value		= 1
	info.func		= Altoholic_ViewAltInfo;
	UIDropDownMenu_AddButton(info, 1); 
	info.text		= L["View mailbox"]
	info.value		= 2
	info.func		= Altoholic_ViewAltInfo;
	UIDropDownMenu_AddButton(info, 1); 
	info.text		= L["View quest log"]
	info.value		= 3
	info.func		= Altoholic_ViewAltInfo;
	UIDropDownMenu_AddButton(info, 1); 
	info.text		= L["View auctions"]
	info.value		= 4
	info.func		= Altoholic_ViewAltInfo;
	UIDropDownMenu_AddButton(info, 1); 
	info.text		= L["View bids"]
	info.value		= 5
	info.func		= Altoholic_ViewAltInfo;
	UIDropDownMenu_AddButton(info, 1); 	
	info.text		= L["Delete this Alt"]
	info.func		= Altoholic_DeleteAlt;
	UIDropDownMenu_AddButton(info, 1); 
end

function Altoholic_ViewAltInfo()
	local line = V.CharInfoLine
	V.CharInfoLine = nil
	-- Captured for every row, local or linked (Modules/LinkSync.lua), so
	-- it can't be left stale from an earlier row's selection -- every "View
	-- X" branch below reads through Altoholic:ResolveLinkedChar, which
	-- branches on this.
	V.CurrentFaction, V.CurrentRealm, V.CurrentLinkedAccount = Altoholic:GetCharacterInfo(line)
	V.CurrentAlt = Altoholic.CharacterInfo[line].name
	if this.value == 1 then		-- bags
		Altoholic:UpdateContainerCache()
		Altoholic:ClearScrollFrame(getglobal("AltoContainersScrollFrame"), "AltoContainersEntry", 7, 41)
		Altoholic:ActivateMenuItem("AltoContainers")
	elseif this.value == 2 then		-- mailbox
		Altoholic:ActivateMenuItem("AltoMail")
	elseif this.value == 3 then		-- quest log
		Altoholic:ActivateMenuItem("AltoQuests")
	elseif this.value == 4 then		-- auctions
		V.AuctionType = "auctions"
		Altoholic.Auctions_Update = Altoholic.Auctions_Update_Auctions
		Altoholic:ActivateMenuItem("AltoAuctions")
	elseif this.value == 5 then		-- bids
		V.AuctionType = "bids"
		Altoholic.Auctions_Update = Altoholic.Auctions_Update_Bids
		Altoholic:ActivateMenuItem("AltoAuctions")
	end
end

function Altoholic_DeleteAlt()
	local line = V.CharInfoLine
    V.CharInfoLine = {}
	V.CharInfoLine = nil
	local s = Altoholic.CharacterInfo[line] -- no validity check, this comes from the dropdownmenu, it's been secured earlier
	local AltName = s.name
	local Faction, Realm, LinkedAccount = Altoholic:GetCharacterInfo(line)
	if LinkedAccount then
		-- Unlike every other right-click option, deletion has no meaning
		-- against a linked row: it's a read-only mirror of another
		-- account's data (Modules/LinkSync.lua), and Altoholic.db.account.data
		-- doesn't even have an entry for it to delete.
		DEFAULT_CHAT_FRAME:AddMessage(TEAL .. "Altoholic: " .. WHITE .. L["Cannot delete current character"])
		return
	end
	local r = Altoholic.db.account.data[Faction][Realm]
	if (Faction == V.faction) and (Realm == V.realm) and (AltName == V.player) then
		DEFAULT_CHAT_FRAME:AddMessage(TEAL .. "Altoholic: " .. WHITE .. L["Cannot delete current character"])
		return
	end
	-- delete factions
	for RepName, RepTable in pairs(r.reputation) do
        RepTable[s.name] = {}
		RepTable[s.name] = nil
	end
	-- delete the character
    r.char[s.name] = {}
    r.char[s.name] = nil
	local charCount = 0
	for _, _ in pairs(r.char) do
		charCount = charCount + 1
	end
	if charCount == 0 then
        Altoholic.db.account.data[Faction][Realm] = {}
        Altoholic.db.account.data[Faction][Realm] = nil
	end
	local realmCount = 0			
	for _, _ in pairs(Altoholic.db.account.data[Faction]) do
		realmCount = realmCount + 1
	end
	if realmCount == 0 then
        Altoholic.db.account.data[Faction] = {}
		Altoholic.db.account.data[Faction] = nil
	end	
	Altoholic:BuildCharacterInfoTable()
	Altoholic:BuildContainersSubMenu()
	Altoholic:BuildMailSubMenu()
	Altoholic:BuildEquipmentSubMenu()
	Altoholic:BuildQuestsSubMenu()
	Altoholic:BuildRecipesSubMenu()
	Altoholic:BuildAuctionsSubMenu()
	Altoholic:BuildBidsSubMenu()
	Altoholic:BuildFactionsTable()
	Altoholic:ActivateMenuItem("AltoSummary")
	DEFAULT_CHAT_FRAME:AddMessage(TEAL .. "Altoholic: " .. WHITE .. L["Character "] .. AltName .. L[" successfully deleted"])
end
