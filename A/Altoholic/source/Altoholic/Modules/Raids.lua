local BI = LibStub("LibBabble-Inventory-3.0"):GetLookupTable()
local L = AceLibrary("AceLocale-2.2"):new("Altoholic")
local V = Altoholic.vars
local INFO_REALM_LINE = 1
local INFO_CHARACTER_LINE = 2
local INFO_TOTAL_LINE = 3
local WHITE		= "|cFFFFFFFF"
local TEAL		= "|cFF00FF9A"
local RED		= "|cFFFF0000"
local ORANGE	= "|cFFFF7F00"
local YELLOW	= "|cFFFFFF00"
local GREEN		= "|cFF00FF00"

-- sorted
local RaidNames = {
	"K10",
	"ZG",
	"AQ20",
	"MC",
	"Ony",
	"BWL",
	"ES",
	"AQ40",
	"Naxx",
	"K40",
}

-- map to raid info name
local RaidLongNames = { 
	["K10"]	 = "Lower",
	["ZG"]	 = "Zul'Gurub",
	["AQ20"] = "Ruins",
	["MC"]   = "Molten",
	["Ony"]  = "Onyxia",
	["BWL"]  = "Blackw",
	["ES"]   = "Emerald",
	["AQ40"] = "Ahn'Qir",
	["Naxx"] = "Naxxram",
	["K40"]  = "Upper",
}


local TotalLockouts = {}


-- we have already found the correct row, check times
local function raidid(info, abbr)
	-- DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "parsing " .. info)
	local id, reset, lastcheck = Altoholic:strsplit("|", info)
	reset = tonumber(reset)
	lastcheck = tonumber(lastcheck)
	local expiresIn = reset - (time() - lastcheck)
	if expiresIn > 0 then
		if TotalLockouts[abbr] == nil then 
			TotalLockouts[abbr] = 1
		else
			TotalLockouts[abbr] = TotalLockouts[abbr] + 1
		end
		return id
	else
		return GREEN .. "-"
	end
end	

-- check where the raid is in our table if at all
local function getraidid(instancelist, raidabbrev)
	for name, info in pairs(instancelist) do
		local longname = RaidLongNames[raidabbrev]
		if (string.sub(name, 1, string.len(longname)) == longname) then
			return raidid(info, raidabbrev)
		end
	end
	return "-"
end

function Altoholic:Raids_Update()
	local VisibleLines = 14
	local frame = "AltoRaids"
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
	TotalLockouts = {}
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
			for _, raidname in pairs(RaidNames) do
				getglobal(entry..i..raidname):SetWidth(35)
			end

			if s.linetype == INFO_REALM_LINE then
				CurrentFaction = s.faction
				CurrentRealm = s.realm
				CurrentLinkedAccount = s.linkedAccount
				TotalLockouts = {}
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
				getglobal(entry..i.."Name"):SetWidth(100)

				for _, raidname in pairs(RaidNames) do
					getglobal(entry..i..raidname):SetText(WHITE .. raidname)
				end

				getglobal(entry..i):SetID(line)
				getglobal(entry..i):Show()
				i = i + 1
				VisibleCount = VisibleCount + 1
				DisplayedCount = DisplayedCount + 1
			elseif DrawRealm then
				if (s.linetype == INFO_CHARACTER_LINE) then
					local raw = Altoholic:ResolveLinkedChar(CurrentFaction, CurrentRealm, CurrentLinkedAccount, s.name)
					local c = {
						class = (raw and raw.class) or "",
						SavedInstance = raw and raw.SavedInstance,
					}
					local color = self:GetClassColor(c.class)
					getglobal(entry..i.."Collapse"):Hide()
					getglobal(entry..i.."Name"):SetText(color .. s.name)
					getglobal(entry..i.."Name"):SetJustifyH("LEFT")
					getglobal(entry..i.."Name"):SetPoint("TOPLEFT", 25, 0)
					getglobal(entry..i.."Name"):SetWidth(100)
					for _, raidname in pairs(RaidNames) do
						getglobal(entry..i..raidname):SetText(getraidid(c.SavedInstance or {}, raidname))
					end
				elseif (s.linetype == INFO_TOTAL_LINE) then
					getglobal(entry..i.."Collapse"):Hide()
					getglobal(entry..i.."Name"):SetText(L["Totals"])
					getglobal(entry..i.."Name"):SetJustifyH("LEFT")
					getglobal(entry..i.."Name"):SetPoint("TOPLEFT", 25, 0)
					getglobal(entry..i.."Name"):SetWidth(100)
					for _, raidname in pairs(RaidNames) do
						getglobal(entry..i..raidname):SetText(TotalLockouts[raidname] or "")
					end
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

function Altoholic_Raid_OnEnter(self)
	local line = self:GetParent():GetID()
	local s = Altoholic.CharacterInfo[line]
	-- DEFAULT_CHAT_FRAME:AddMessage("Onenter linetype "..s.linetype.."id"..self:GetID())
	if s.linetype ~= INFO_CHARACTER_LINE and s.linetype ~= INFO_REALM_LINE then
		-- DEFAULT_CHAT_FRAME:AddMessage("returning as linetype is "..s.linetype)
		return
	end
	local id = self:GetID()
	if id <= 0 or id > 10 then
		-- DEFAULT_CHAT_FRAME:AddMessage("returning as ID is "..id)
		return 
	end

	AltoTooltip:ClearLines();
	AltoTooltip:SetOwner(self, "ANCHOR_RIGHT");

	local longname = RaidLongNames[RaidNames[id]]

	if s.linetype == INFO_REALM_LINE then
		-- DEFAULT_CHAT_FRAME:AddMessage(GREEN .. "In realm info")
		local basetime, resetdays
		if s.realm == "Nordanaar" then
			-- There is no common base as Kara and Ony share 5 days
			-- reset but Kara is 1 day later on Nordanaar
			if id == 1 then		-- K10
				basetime = 1663128000 - 86400
				resetdays = 5
			elseif id == 2 or id == 3 then -- AQ20 ZG
				basetime = 1663128000 - 2 * 86400
				resetdays = 3
			elseif id == 5 then	-- ONY
				basetime = 1663128000 - 2 * 86400
				resetdays = 5
			else
				basetime = 1663128000
				resetdays = 7
			end
		else				-- Tel'Abim
			if id == 1 then		-- K10
				basetime = 1663128000 + 2 * 86400
				resetdays = 5
			elseif id == 2 or id == 3 then -- AQ20 ZG
				basetime = 1663128000 - 86400
				resetdays = 3
			elseif id == 5 then	-- ONY
				basetime = 1663128000 + 2 * 86400
				resetdays = 5
			else
				basetime = 1663128000 + 86400
				resetdays = 7
			end
		end
		local now = time()
		local passedresets = math.floor((now - basetime) / (resetdays * 86400))
		local lastreset = basetime + passedresets * resetdays * 86400
		local nextreset = lastreset + resetdays * 86400
		AltoTooltip:AddLine("Last reset: "..Altoholic:GetTimeString(now - lastreset) .. " ago")
		AltoTooltip:AddLine("Next reset: in "..Altoholic:GetTimeString(nextreset - now))
		local wallclockdate = date("%A, %H:%M", nextreset)
		AltoTooltip:AddLine("Next reset date: " .. ORANGE .. wallclockdate)
	end

	if s.linetype == INFO_CHARACTER_LINE then
		local Faction, Realm, LinkedAccount = Altoholic:GetCharacterInfo(line)
		local c = Altoholic:ResolveLinkedChar(Faction, Realm, LinkedAccount, s.name)
		if not c then return end
		for name, info in pairs(c.SavedInstance or {}) do
			if (string.sub(name, 1, string.len(longname)) == longname) then
				local id, reset, lastcheck = Altoholic:strsplit("|", info)
				reset = tonumber(reset)
				lastcheck = tonumber(lastcheck)
				local expiresIn = reset - (time() - lastcheck)

				AltoTooltip:AddLine(name, 1, 1, 1);
				if (expiresIn > 0) then
					AltoTooltip:AddLine("Expires in ".. RED .. Altoholic:GetTimeString(expiresIn))
				else
					AltoTooltip:AddLine("Expired ".. GREEN .. Altoholic:GetTimeString(-expiresIn) .. WHITE .. " ago")
				end
			end
		end
	end

	AltoTooltip:Show();

	return
end
