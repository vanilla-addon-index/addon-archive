-- LinkSync.lua -- optional cross-account visibility via the Link DLL.
-- Every function here gates on `Link_Write` existing, the same
-- feature-detection Link's own README recommends for every caller, so this
-- file is a complete no-op when Link isn't installed.
--
-- Behavior is fully automatic -- there is no on/off setting. Installing
-- Link.dll alongside Altoholic is itself the opt-in; anyone who didn't want
-- this wouldn't have added the DLL to dlls.txt in the first place.

local L = AceLibrary("AceLocale-2.2"):new("Altoholic")
local BI = LibStub("LibBabble-Inventory-3.0"):GetLookupTable()

local L_ADDON = "Altoholic"
local L_FILE  = "data.lua"

Altoholic.LinkedAccounts = {}

-- ---------------------------------------------------------------------------
-- Minimal table <-> Lua-chunk serialization. Link only moves text, so the
-- saved-account tree has to become a loadstring-able chunk on write and come
-- back the same way on read -- same shape SavedVariables itself already
-- uses, just driven by hand since nothing here exposes the client's own
-- serializer to an addon. Every value already has to be string/number/
-- boolean/table, since this same tree is already written by the client's
-- own SavedVariables save every logout.
-- ---------------------------------------------------------------------------

local function SerializeKey(k)
	local t = type(k)
	if t == "string" then
		return "[" .. string.format("%q", k) .. "]"
	elseif t == "number" then
		return "[" .. tostring(k) .. "]"
	end
	-- other key types don't occur in db.account.data -- drop rather than error
end

local function SerializeValue(v)
	local t = type(v)
	if t == "string" then
		return string.format("%q", v)
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		local parts = {}
		for k, val in pairs(v) do
			local ks = SerializeKey(k)
			local vs = SerializeValue(val)
			if ks and vs then
				table.insert(parts, ks .. "=" .. vs)
			end
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	-- function/userdata/thread: unserializable and shouldn't occur -- drop
end

local function Serialize(tbl)
	return "return " .. SerializeValue(tbl)
end

-- pcall guards the loadstring() call the same way any SavedVariables load
-- effectively already is: the text on disk was written by another account's
-- copy of this same function, but Link explicitly makes no promise about
-- who else can write into Link_SharedData (see README.md "Namespacing") --
-- a malformed or hand-edited file must fail to load, not error out.
local function Deserialize(text)
	if not text then return nil end
	local chunk = loadstring(text)
	if not chunk then return nil end
	local ok, result = pcall(chunk)
	if not ok or type(result) ~= "table" then return nil end
	return result
end

-- ---------------------------------------------------------------------------
-- Account label. Link never exposes the real WoW account name (nothing in
-- 1.12 Lua can), so callers pick their own -- see README.md's worked
-- example. Default to whichever character is logged in the first time this
-- runs, and remember it from then on.
-- ---------------------------------------------------------------------------

local function GetOrCreateAccountLabel()
	local O = Altoholic.db.account.options
	if not O.LinkAccountLabel then
		O.LinkAccountLabel = UnitName("player") or "account1"
	end
	return O.LinkAccountLabel
end

-- ---------------------------------------------------------------------------
-- Shared character lookup. Character detail is never stored on a UI row or
-- in module-level selection state -- every consumer (AccountSummary,
-- Containers, ...) looks it up live by faction/realm/name each time it's
-- needed. A Link-synced selection carries the same faction/realm/name shape
-- but its detail lives in Altoholic.LinkedAccounts, not self.db.account.data,
-- so every one of those lookups branches on which account it actually came
-- from. One shared method here instead of a copy per consuming module.
-- ---------------------------------------------------------------------------

function Altoholic:ResolveLinkedChar(faction, realm, linkedAccount, name)
	if linkedAccount then
		local acct = Altoholic.LinkedAccounts and Altoholic.LinkedAccounts[linkedAccount]
		local f = acct and acct[faction]
		local r = f and f[realm]
		return r and r.char and r.char[name]
	end
	local f = Altoholic.db.account.data[faction]
	local r = f and f[realm]
	return r and r.char and r.char[name]
end

-- ---------------------------------------------------------------------------
-- Sync. WriteOut covers this account's own alt data out to disk; ReadIn
-- pulls every other account's copy back in. Neither ever touches
-- self.db.account.data -- LinkedAccounts is a separate, read-only tree, so a
-- bad or stale file from another account can never overwrite this
-- account's own saved data.
-- ---------------------------------------------------------------------------

local function WriteOut()
	if not Link_Write then return end
	local label = GetOrCreateAccountLabel()
	Link_Write(label, L_ADDON, L_FILE, Serialize(Altoholic.db.account.data))
end

local function ReadIn()
	if not (Link_Write and Link_ListAccounts and Link_Read) then return end
	local myLabel = GetOrCreateAccountLabel()
	local accounts = Link_ListAccounts()
	local linked = {}
	for i = 1, table.getn(accounts) do
		local label = accounts[i]
		if label ~= myLabel then
			local data = Deserialize(Link_Read(label, L_ADDON, L_FILE))
			if data then
				linked[label] = data
			end
		end
	end
	Altoholic.LinkedAccounts = linked
	-- Keeps every sidebar's per-account realm entries
	-- (Altoholic.lua:Build*SubMenu) in step with LinkedAccounts -- otherwise
	-- the very first PLAYER_LOGIN builds these menus from whatever was
	-- already known (nothing, the first time -- ReadIn hasn't run yet at
	-- OnEnable) and never revisits them, so a linked account never appears
	-- in the sidebar even though AccountSummary/ResolveLinkedChar already
	-- see it fine.
	Altoholic:BuildContainersSubMenu()
	Altoholic:BuildMailSubMenu()
	Altoholic:BuildEquipmentSubMenu()
	Altoholic:BuildQuestsSubMenu()
	Altoholic:BuildRecipesSubMenu()
	Altoholic:BuildAuctionsSubMenu()
	Altoholic:BuildBidsSubMenu()
end

SLASH_ALTOHOLICLINK1 = "/altoholiclink"
SlashCmdList["ALTOHOLICLINK"] = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "" then
		DEFAULT_CHAT_FRAME:AddMessage("Altoholic Link: this account is shared as \""
			.. GetOrCreateAccountLabel() .. "\". Usage: /altoholiclink <name> to rename.")
		return
	end
	Altoholic.db.account.options.LinkAccountLabel = msg
	-- Re-pull immediately rather than waiting for the next PLAYER_LOGIN --
	-- otherwise a rename leaves Altoholic.LinkedAccounts (and anything
	-- already showing an old foreign-account row for the label just
	-- adopted) stale until the next full login. BuildCharacterInfoTable
	-- rebuilds self.CharacterInfo immediately after (re-triggering the
	-- AppendLinkedRows hook below), so the row list and LinkedAccounts
	-- never go out of sync with each other for the window between a
	-- rename and the next time the main frame happens to reopen.
	ReadIn()
	Altoholic:BuildCharacterInfoTable()
	DEFAULT_CHAT_FRAME:AddMessage("Altoholic Link: renamed to \"" .. msg .. "\".")
end

-- ---------------------------------------------------------------------------
-- AccountSummary display. Altoholic.lua:BuildCharacterInfoTable() rebuilds
-- self.CharacterInfo (the row list AccountSummary_Update renders) from
-- self.db.account.data every time the main window opens. A SecureHook runs
-- this appender right after it, every time, so linked accounts' characters
-- show up in the same list without editing that function directly. These
-- rows carry `linkedAccount` (checked in Modules/AccountSummary.lua's
-- ResolveChar/OnClick) so they read from Altoholic.LinkedAccounts instead of
-- self.db.account.data, and so right-click delete / bag-mail-quest
-- navigation -- which have no data source for another account -- never
-- fires on them.
-- ---------------------------------------------------------------------------

local INFO_REALM_LINE = 1     -- must match Modules/AccountSummary.lua's local
local INFO_CHARACTER_LINE = 2 -- constants of the same name -- not shared

-- ---------------------------------------------------------------------------
-- Shared menu traversal. Every Build*SubMenu function in Altoholic.lua
-- (Mail, Equipment, Quests, Recipes, Auctions, Bids -- Containers already
-- uses this shape too) walks self.db.account.data the same way to build its
-- own sidebar tree. Rather than duplicate the walk-LinkedAccounts,
-- collect-and-sort-characters version of that six more times, one shared
-- iterator here; each caller supplies only its own per-module menu-entry
-- shape via callback(label, faction, realm, sortedNames, charTable).
-- ---------------------------------------------------------------------------

function Altoholic:ForEachLinkedRealm(callback)
	for label, accountData in pairs(Altoholic.LinkedAccounts) do
		for factionName, f in pairs(accountData) do
			for realmName, r in pairs(f) do
				if r.char then
					local names = {}
					for charName in pairs(r.char) do
						table.insert(names, charName)
					end
					table.sort(names)
					if table.getn(names) > 0 then
						callback(label, factionName, realmName, names, r.char)
					end
				end
			end
		end
	end
end

-- Same idea as Altoholic:Get_Sorted_Character_List, for one linked
-- account's realm -- Equipment.lua needs the plain name list (not the
-- level-sorted one, since that reads self.db.account.data directly and
-- doesn't know about linked accounts) to draw its side-by-side compare view.
function Altoholic:GetLinkedCharacterNames(label, faction, realm)
	local acct = Altoholic.LinkedAccounts and Altoholic.LinkedAccounts[label]
	local f = acct and acct[faction]
	local r = f and f[realm]
	if not (r and r.char) then return {} end
	local names = {}
	for charName in pairs(r.char) do
		table.insert(names, charName)
	end
	table.sort(names)
	return names
end

local function AppendLinkedRows()
	for label, accountData in pairs(Altoholic.LinkedAccounts) do
		for factionName, f in pairs(accountData) do
			for realmName, r in pairs(f) do
				if r.char then
					local names = {}
					for charName in pairs(r.char) do
						table.insert(names, charName)
					end
					table.sort(names)
					if table.getn(names) > 0 then
						table.insert(Altoholic.CharacterInfo, {
							linetype = INFO_REALM_LINE,
							isCollapsed = false,
							faction = factionName,
							-- Raw realm name, not a display string: this is also
							-- the lookup key ResolveChar() indexes
							-- Altoholic.LinkedAccounts[label][faction][realm]
							-- with. The "(label)" suffix is added purely at
							-- render time in AccountSummary.lua instead.
							realm = realmName,
							linkedAccount = label,
						})
						for i = 1, table.getn(names) do
							-- Skills.lua and BagUsage.lua read skillName1/
							-- skillRank1/.../bankslots straight off the row,
							-- not through ResolveLinkedChar -- they're never
							-- populated by anything else for a linked row, so
							-- computed here the same way
							-- Altoholic.lua:BuildCharacterInfoTable does for
							-- a local one, from the same source shape.
							local c = r.char[names[i]]
							local skill = c.skill or {}
							local profs = skill[L["Professions"]] or {}
							local secondary = skill[L["Secondary Skills"]] or {}
							local skillNames, skillRanks = {}, {}
							local j = 1
							for skillName, rankString in pairs(profs) do
								skillRanks[j] = Altoholic:GetSkillInfo(rankString)
								skillNames[j] = skillName
								j = j + 1
							end
							local bank
							if (c.bankslots == nil) or (c.bankslots == "") then
								bank = L["Bank not visited yet"]
							else
								bank = c.bankslots
							end
							table.insert(Altoholic.CharacterInfo, {
								linetype = INFO_CHARACTER_LINE,
								name = names[i],
								bankslots = bank,
								skillRank1 = skillRanks[1] or 0,
								skillName1 = skillNames[1] or "",
								skillRank2 = skillRanks[2] or 0,
								skillName2 = skillNames[2] or "",
								cooking = Altoholic:GetSkillInfo(secondary[BI["Cooking"]]),
								firstaid = Altoholic:GetSkillInfo(secondary[BI["First Aid"]]),
								fishing = Altoholic:GetSkillInfo(secondary[BI["Fishing"]]),
								riding = Altoholic:GetSkillInfo(secondary[L["Riding"]]),
							})
						end
					end
				end
			end
		end
	end
end

Altoholic:SecureHook(Altoholic, "BuildCharacterInfoTable", AppendLinkedRows)

-- A dedicated frame rather than piggybacking on Altoholic's own AceEvent
-- dispatch (Altoholic:PLAYER_LOGOUT etc. in Altoholic.lua) -- that dispatch
-- requires a method named exactly after the event on the Altoholic object
-- itself, and redefining one here would silently replace Altoholic's
-- existing handler instead of adding to it.
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function()
	if event == "PLAYER_LOGIN" then
		ReadIn()
	elseif event == "PLAYER_LOGOUT" then
		WriteOut()
	end
end)
