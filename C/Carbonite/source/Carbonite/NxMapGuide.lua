---------------------------------------------------------------------------------------
-- NxMapGuide - Map guide code
-- Copyright 2007-2012 Carbon Based Creations, LLC
---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
-- Carbonite - Addon for World of Warcraft(tm)
-- Copyright 2007-2012 Carbon Based Creations, LLC
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Tables

Nx.GuideAbr = {
	["K"] = "Kalimdor",
	["E"] = "Eastern Kingdoms",
	["O"] = "Outlands",
	["N"] = "Northrend",
	["M"] = "The Maelstrom",
	["P"] = "Pandaria",
}

Nx.GuideInfo = {
	Name = "All",
	Tx = "INV_Misc_QuestionMark",
	{
		T = "Auctioneer",
		Tx = "Racial_Dwarf_FindTreasure",
	},
	{
		T = "Banker",
		Tx = "INV_Misc_Coin_02",
	},
	{
		T = "Barber",
		Tx = "INV_Misc_Comb_02",
	},
	{
		T = "Flight Master",
		Tx = "Ability_Druid_FlightForm",
	},
	{
		T = "Innkeeper",
		Tx = "Spell_Shadow_Twilight",
	},
	{
		T = "Mailbox",
		Tx = "INV_Letter_15",
	},
	{
		Name = "Quest Givers",
		T = "&",
		Tx = "INV_Misc_Note_02",
		Persist = "QMapShowQuestGivers3",
	},
--[[
	{
		T = "Repair",
		Tx = "Ability_Repair",
	},
--]]
	{
		T = "Stable Master",
		Tx = "Ability_Hunter_BeastTaming",
	},
	{
		Name = "Trade Skill",
		Tx = "INV_Misc_Note_04",
		-- {
		-- 	T = "Alchemy Lab",
		-- 	Tx = "INV_Potion_06",
		-- },
		-- {
		-- 	T = "Altar Of Shadows",
		-- 	Tx = "INV_Fabric_Felcloth_Ebon",
		-- },
		{
			T = "Anvil",
			Tx = "Trade_BlackSmithing",
		},
		{
			T = "Forge",
			Tx = "INV_Sword_09",
		},
		-- {
		-- 	T = "Mana Loom",
		-- 	Tx = "INV_Fabric_Netherweave_Bolt_Imbued",
		-- },
		-- {
		-- 	T = "Moonwell",
		-- 	Tx = "INV_Fabric_MoonRag_Primal",
		-- },
	},
	{
		Name = "Trainer",
		T = "^C",
		Tx = "INV_Misc_Book_01",
		{
			Name = "Class Trainer",
			T = "^C",
			Tx = "INV_Misc_Book_01",
			{
				T = "Death Knight Trainer",
				Tx = "Spell_Deathknight_ClassIcon",
			},
			{
				T = "Druid Trainer",
				Tx = "Ability_Druid_Maul",
			},
			{
				T = "Hunter Trainer",
				Tx = "INV_Weapon_Bow_07",
			},
			{
				T = "Mage Trainer",
				Tx = "INV_Staff_13",
			},
			{
				T = "Paladin Trainer",
				Tx = "INV_Hammer_01",
			},
			{
				T = "Priest Trainer",
				Tx = "INV_Staff_30",
			},
			{
				T = "Rogue Trainer",
				Tx = "INV_ThrowingKnife_04",
			},
			{
				T = "Shaman Trainer",
				Tx = "Spell_Nature_BloodLust",
			},
			{
				T = "Warlock Trainer",
				Tx = "Spell_Nature_FaerieFire",
			},
			{
				T = "Warrior Trainer",
				Tx = "INV_Sword_27",
			},
		},
		{
			Pre = "Alchemy",
			Name = "Trainer",
			T = "^P",
			Tx = "Trade_Alchemy",
		},
		-- {
		-- 	Pre = "Archaeology",
		-- 	Name = "Trainer",
		-- 	T = "^P",
		-- 	Tx = "trade_archaeology",
		-- },
		{
			Pre = "Blacksmithing",
			Name = "Trainer",
			T = "^P",
			Tx = "Trade_BlackSmithing",
		},
		{
			Pre = "Enchanting",
			Name = "Trainer",
			T = "^P",
			Tx = "Trade_Engraving",
		},
		{
			Pre = "Engineering",
			Name = "Trainer",
			T = "^P",
			Tx = "Trade_Engineering",
		},
		{
			Pre = "Herbalism",
			Name = "Trainer",
			T = "^P",
			Tx = "Trade_Herbalism",
		},
		-- {
		-- 	Pre = "Inscription",
		-- 	Name = "Trainer",
		-- 	T = "^P",
		-- 	Tx = "INV_Inscription_Tradeskill01",
		-- },
		-- {
		-- 	Pre = "Jewelcrafting",
		-- 	Name = "Trainer",
		-- 	T = "^P",
		-- 	Tx = "INV_Misc_Gem_02",
		-- },
		{
			Pre = "Leatherworking",
			Name = "Trainer",
			T = "^P",
			Tx = "INV_Misc_ArmorKit_17",
		},
		{
			Pre = "Mining",
			Name = "Trainer",
			T = "^P",
			Tx = "Trade_Mining",
		},
		{
			Pre = "Skinning",
			Name = "Trainer",
			T = "^P",
			Tx = "INV_Misc_Pelt_Wolf_01",
		},
		{
			Pre = "Tailoring",
			Name = "Trainer",
			T = "^P",
			Tx = "Trade_Tailoring",
		},
		{
			Pre = "Cooking",
			Name = "Trainer",
			T = "^S",
			Tx = "INV_Misc_Food_15",
		},
		{
			Pre = "First Aid",
			Name = "Trainer",
			T = "^S",
			Tx = "Spell_Holy_SealOfSacrifice",
		},
		{
			Pre = "Fishing",
			Name = "Trainer",
			T = "^S",
			Tx = "Trade_Fishing",
		},
		-- {
		-- 	Pre = "Flying",
		-- 	Name = "Trainer",
		-- 	T = "^S",
		-- 	Tx = "inv_scroll_11",
		-- },
		{
			Pre = "Riding",
			Name = "Trainer",
			T = "^S",
			Tx = "spell_nature_swiftness",
		},
	},
	{
		Name = "Travel",
		Tx = "Ability_Townwatch",
	},
	{
		T = "Items",
		Tx = "Achievement_Arena_3v3_4",
	},
	{
		Name = "Visited Vendor",
		Tx = "INV_Misc_Coin_05",
		{
			Name = "All Items",
			NoShowChild = true,
		},
	},
	{
		Name = "Gather",
		Tx = "INV_Misc_Bag_10",
		{
			Name = "Herb",
			Tx = "INV_Misc_Flower_02",
			Persist = "MapShowGatherH",
		},
		{
			Name = "Ore",
			Tx = "INV_Ore_Copper_01",
			Persist = "MapShowGatherM",
		},
		{
			Name = "Artifacts",
			T = "$ A",
			Id = "Art",
			Tx = "Trade_Archaeology",
			Persist = "MapShowGatherA",
		},
		{
			Name = NXlEverfrost,
			T = "$ E",
			Id = "Everfrost",
			Tx = "spell_shadow_teleport",
		},
		{
			Name = NXlGas,
			T = "$ G",
			Id = "Gas",
			Tx = "inv_gizmo_zapthrottlegascollector",
		},
	},
	{
		Name = "Instances",
		Tx = "INV_Misc_ShadowEgg",
		{
			Name = "@K",
			Inst = 1
		},
		{
			Name = "@E",
			Inst = 2
		},
		-- {
		-- 	Name = "@O",
		-- 	Inst = 3
		-- },
		-- {
		-- 	Name = "@N",
		-- 	Inst = 4
		-- },
		-- {
		-- 	Name = "@M",
		-- 	Inst = 5
		-- },
		-- {
		-- 	Name = "@P",
		-- 	Inst = 6
		-- },
	},
	{
		Name = "Zone",
		Tx = "INV_Misc_Map_01",
		{
			Name = "All",
			Map = 0
		},
		{
			Name = "@K",
			Map = 1
		},
		{
			Name = "@E",
			Map = 2
		},
		-- {
		-- 	Name = "@O",
		-- 	Map = 3
		-- },
		-- {
		-- 	Name = "@N",
		-- 	Map = 4
		-- },
		-- {
		-- 	Name = "@M",
		-- 	Map = 5
		-- },
		-- {
		-- 	Name = "@P",
		-- 	Map = 6
		-- },
	},
	{
		Name = "PVP",
		Tx = "INV_Misc_Coin_05",
		{
			T = "Alterac Valley Battlemaster",
			Tx = "INV_Jewelry_Necklace_21"
		},
		{
			T = "Arathi Basin Battlemaster",
			Tx = "INV_Jewelry_Amulet_07"
		},
		{
			T = "Arena Battlemaster",
			Tx = "Spell_Holy_PrayerOfHealing"
		},
		{
			T = "Eye Of The Storm Battlemaster",
			Tx = "Spell_Nature_EyeOfTheStorm"
		},
		{
			T = "Strand of the Ancients Battlemaster",
			Tx = "INV_Jewelry_Amulet_01"
		},
		{
			T = "Warsong Gulch Battlemaster",
			Tx = "INV_Misc_Rune_07"
		},
	},
}

--[[
Nx.GuideTrainerInfo = {
	"Apprentice", "Journeyman", "Expert", "Artisan", "Master",
	[11] = "1-75", [12] = "76-150 (50)", [13] = "151-225 (125)", [14] = "226-300 (200)", [15] = "301-375 (275)"
}
--]]

--------
-- Create a guide

function Nx.Map.Guide:Create (map)

	local g = {}

	setmetatable (g, self)
	self.__index = self

	g.Map = map
	g.GuideIndex = map.MapIndex

	local opts = NxMapOpts.NXMaps[g.GuideIndex]

	g.TitleH = 0
	g.ToolBarW = 0
	g.PadX = 0

	g:ItemInit()
	g:PatchFolder (Nx.GuideInfo, nil)

	g.PathHistory = {}
	g.PathHistory[1] = Nx.GuideInfo

	g.PathHistorySel = {}	-- Remember list selection

	g.ShowFolders = {}

	g.ShowQuestGiverCompleted = true			-- For free version

	-- Create Window

	local win = Nx.Window:Create ("NxGuide" .. g.GuideIndex, nil, nil, nil, 1)
	g.Win = win
	win.Frm.NxInst = g

	win:SetUser (g, g.OnWin)
	win:RegisterHide()

	win:CreateButtons (true)
	win:SetTitleLineH (18)
	win:SetTitleXOff (50)

	win:InitLayoutData (nil, -.15, -.2, -.63, -.5)
	win.Frm:SetToplevel (true)

	win:Show (false)

	tinsert (UISpecialFrames, win.Frm:GetName())

	-- Back button

	local but = Nx.Button:Create (win.Frm, "Txt64", "Back", nil, 0, 0, "TOPLEFT", 100, 24, self.But_OnBack, g)

	win:Attach (but.Frm, 1.01, 1.01+44, -10020, -10001)

	-- List

	Nx.List:SetCreateFont ("FontM", 28)

	local list = Nx.List:Create (false, 0, 0, 1, 1, win.Frm)
	g.List = list

	list:SetUser (g, g.OnListEvent)

	list:SetLineHeight (16, 3)

	list:ColumnAdd ("", 1, 35)
	list:ColumnAdd ("", 2, 900)

	win:Attach (list.Frm, 0, .33, 0, 1)

	g:CreateMenu()

	-- Item List

	Nx.List:SetCreateFont ("FontM", 28)

	local list = Nx.List:Create (false, 0, 0, 1, 1, win.Frm)
	g.List2 = list

	list:SetUser (g, g.OnList2Event)

	list:SetLineHeight (16, 11)

	list:ColumnAdd ("", 1, 35)
	list:ColumnAdd ("Name", 2, 220)
	list:ColumnAdd ("Info", 3, 60)
	list:ColumnAdd ("Info2", 4, 100)
	list:ColumnAdd ("Info3", 5, 300)

	win:Attach (list.Frm, .33, 1, 18, 1)

	-- Filter Edit Box

	g.EditBox = Nx.EditBox:Create (win.Frm, g, g.OnEditBox, 30)

	win:Attach (g.EditBox.Frm, .33, 1, 0, 18)

	--

	g:ClearShowFolders()		-- Make persistent ones show

	g:UpdateVisitedVendors()
	g:Update()

	map:InitIconType ("!POI", "WP", "", 1, 1)		-- Setting of alpha needs this first
	map:InitIconType ("!POIIn", "WP", "", 1, 1)	-- Setting of alpha needs this first

	--

	return g
end

--------
-- Create menu

function Nx.Map.Guide:CreateMenu()

	local menu = Nx.Menu:Create (self.List.Frm)
	self.Menu = menu

	self.MenuIDelete = menu:AddItem (0, "Delete", self.Menu_OnDelete, self)

	self.MenuIGotoQ = menu:AddItem (0, "Add Goto Quest", self.Menu_OnAddGotoQ, self)

	local item = menu:AddItem (0, "Show On All Continents", self.Menu_OnShowAllCont, self)
	item:SetChecked (true)
	self.ShowAllCont = true

	local function func (self, item)
		self.ShowQuestGiverCompleted = item:GetChecked()
		self:Update()
	end

	local item = menu:AddItem (0, "Show Completed Quest Givers", func, self)
	item:SetChecked (false)
	self.ShowQuestGiverCompleted = false

	local str = UnitFactionGroup ("player") == "Horde" and "Alliance" or "Horde"

	local item = menu:AddItem (0, "Show " .. str, self.Menu_OnShowEnemy, self)
	item:SetChecked (false)

	menu:AddItem (0, "Clear Selection", self.Menu_OnClearSel, self)

	local function func()
		Nx.Opts:Open ("Guide")
	end

	menu:AddItem (0, "Options...", func, self)
end

--------
-- Open menu

function Nx.Map.Guide:OpenMenu (item)

--	Nx.prtVar ("item", item)

	self.MenuCurItem = item

	local canDel = false
	local canGotoQ = false

	if type (item) == "table" then

		if item.T then

			local mode = strbyte (item.T)

			if mode == 40 then		-- ( (Visited vendor)
				canDel = true
			end
		end

		if item.QId then
			canGotoQ = true
		end
	end

	self.MenuIDelete:Show (canDel)
	self.MenuIGotoQ:Show (canGotoQ)

	self.Menu:Open()
end

function Nx.Map.Guide:Menu_OnDelete()

	local item = self.MenuCurItem
	local mode = strbyte (item.T)

	if mode == 40 then		-- ( (Visited vendor)
		local npcName = Nx.compat:strsub (item.T, 2)
		local vv = NxData.NXVendorV

--		Nx.prtVar ("VV", vv)

		vv[npcName] = nil
	end

	self:UpdateVisitedVendors()

	local parent = Nx.GuideInfo

	for n = 2, Nx.compat:tsize (self.PathHistory) do
		local i = max (min (self.PathHistorySel[n - 1], Nx.compat:tsize (parent)), 1)
		self.PathHistory[n] = parent[i]
		parent = self.PathHistory[n]
	end

	self:ClearAll()
	self:SelectLists()
end

function Nx.Map.Guide:Menu_OnAddGotoQ()

	local item = self.MenuCurItem

	if item.QId then
		Nx.Quest:Goto (item.QId)
	end
end

function Nx.Map.Guide:Menu_OnShowAllCont (item)
	self.ShowAllCont = item:GetChecked()
	self:Update()
end

function Nx.Map.Guide:Menu_OnShowEnemy (item)
	self.ShowEnemy = item:GetChecked()
	self:ClearAll()
--	self:Update()
end

function Nx.Map.Guide:Menu_OnClearSel()
	self:ClearAll()
end

--------

function Nx.Map.Guide:But_OnBack()
	self:Back()
end

--------
-- Show or hide guide

function Nx:NXGuideKeyToggleShow()

	local map = Nx.Map:GetMap (1)
	map.Guide:ToggleShow()
end

--------
-- Show or hide guide

function Nx.Map.Guide:ToggleShow()

	Nx.Sec:ValidateMsg()
end

--------
-- Show or hide guide

function Nx.Map.Guide:ToggleShow_()

	self.Win:Show (not self.Win:IsShown())
end

--------

function Nx.Map.Guide:OnWin (typ)

	if typ == "Hide" then
		self:ItemsFree()
	end
end

--------
-- On list control updates

function Nx.Map.Guide:OnListEvent (eventName, sel, val2, click)

	self:OnListEventDo (self.List, eventName, sel, val2, click)
end

function Nx.Map.Guide:OnList2Event (eventName, sel, val2, click)

	self:OnListEventDo (self.List2, eventName, sel, val2, click)
end

function Nx.Map.Guide:OnListEventDo (list, eventName, sel, val2, click)

--	Nx.prt ("Guide list event "..eventName)

	local typ = list:ItemGetData (sel) or 0

	local pathI = max (Nx.compat:tsize (self.PathHistory) - 1, 1)

	if list == self.List2 then
		pathI = Nx.compat:tsize (self.PathHistory)
	end

	if eventName == "select" or eventName == "mid" or eventName == "menu" then

		self.PathHistorySel[pathI] = sel

		local folder = self.PathHistory[pathI]
		local item = folder[typ]

--		Nx.prtVar ("item", item)

		if eventName ~= "menu" or list == self.List then

			if type (item) == "table" then

				if item[1] or item.Item then						-- Not empty or generated items?
					self.PathHistory[pathI + 1] = item			-- Go into
					self.PathHistorySel[pathI + 1] = 1
					self:SelectLists()
				else
					if list == self.List then
						if Nx.compat:tsize (self.PathHistory) == 2 then
							self:Back()
						end
					end
				end
			end
		end

		if type (item) == "number" then

--			Nx.prt ("Folder %s", item)

			local id = item

			if IsControlKeyDown() then
				DressUpItemLink (format ("item:%d", id))
			else

				local name, link = GetItemInfo (id)
				SetItemRef (format ("item:%d", id), link)
			end
		else
			if IsControlKeyDown() then
				if item.Link then
					DressUpItemLink (item.Link)
				end
			end
		end

		self:Update()

		if eventName == "menu" then
			self:OpenMenu (item)
		end

	elseif eventName == "back" then

		self:Back()

	elseif eventName == "sort" then

--		Nx.prt ("Guide list sort")

		if list == self.List2 then
			list:ColumnSort (val2)
			self:Update()
		end

	elseif eventName == "button" then	-- Button icon

		local pressed = val2

		if typ > 0 then

			local map = self.Map

			local folder = self.PathHistory[pathI]

			if type (folder[typ]) == "table" then
				folder = folder[typ]
			end

			if folder.TrialMsg then
				Nx.ShowMessageTrial()
			end

			local single = not (IsShiftKeyDown() or click == "MiddleButton")

			if folder.MId and pressed then
				map:SetCurrentMap (folder.MId)
				map:CenterMap (folder.MId, 1)
				Nx.Quest.List:Update()
				single = true
			end

			if single then
				self:ClearShowFolders()
				map:ClearTargets (not pressed and "Guide")

			elseif not pressed then
				local typ, id = map:GetTargetInfo()
				if id == folder then
					map:ClearTargets()
				end
			end

			if folder.Persist and not pressed then

				local v = Nx.CharOpts[folder.Persist]

				if not v or v == 1 then
					self:AddShowFolders (folder, not pressed)
				end

			else
				self:AddShowFolders (folder, not pressed)
			end

			self:Update()

			if single and pressed then

				local typ, filt = self:CalcType (folder)

				self.FindingClosest = typ

				if typ then

					local npcI, mapId, x, y = self:FindClosest (typ)
					if npcI then

						Nx.Quest.Watch:ClearAutoTarget()
						map:SetTarget ("Guide", x, y, x, y, false, folder, folder.Name, false, mapId)
						map:GotoPlayer()
					end
				else
					PlaySound ("igPlayerInviteDecline")
				end
			end
		end
	end
end

function Nx.Map.Guide:Back()

	if Nx.compat:tsize (self.PathHistory) > 1 then
		tremove (self.PathHistory)
	end

	self:Update()
	self:SelectLists()
end

function Nx.Map.Guide:SelectLists()

	local i = self.PathHistorySel[max (Nx.compat:tsize (self.PathHistory) - 1, 1)]
	if i and i <= self.List:ItemGetNum() then
		self.List:Select (i)
	end

	self.List:Update()

	local i = self.PathHistorySel[Nx.compat:tsize (self.PathHistory)]
	if i and i <= self.List2:ItemGetNum() then
		self.List2:Select (i)
	end

	self.List2:Update()
end

--------
-- Handle filter edit box

function Nx.Map.Guide:OnEditBox (editbox, message)

	if message == "Changed" then
		self:Update()
	end
end

--------
-- Patch folder data and any children

function Nx.Map.Guide:PatchFolder (folder, parent)

	local trainer
	if folder.Name == "Trainer" and folder.Pre then
		trainer = true
--[[
		for n, typ in ipairs (Nx.GuideTrainerInfo) do
			local child = {}
			child.Name = format ("%s %s %s", folder.Pre, typ, Nx.GuideTrainerInfo[n + 10])
			child.T = folder.Pre .. " Trainer"	--typ
			child.Tx = folder.Tx
			folder[n] = child
		end
--]]
	end

	if folder.Pre and folder.Name then
		folder.Name = folder.Pre .. folder.Name
		folder.Name = Nx.compat:strtrim (gsub (folder.Name, "(%u)", " %1"), " ")	-- Space out capped words
	end

	if parent and parent.Pre and folder.T then
		folder.T = parent.Pre .. folder.T
	end

	if not folder.Name and folder.T then
		local name = Nx.compat:strsplit ("%^", folder.T)
		folder.Name = Nx.compat:strtrim (gsub (name, "(%u)", " %1"), " ")
	end

	if folder.Name then
		folder.Name = gsub (folder.Name, " Trainer", "")	-- Remove trainer at end
	end

	if not folder.Tx then
		folder.Tx = parent.Tx
	end

	if not trainer then
		for showType, child in ipairs (folder) do
			if type (child) == "table" then
				self:PatchFolder (child, folder)
			end
		end
	end

	if folder.Name == "Travel" then

		local txT = {
			["Boat"] = "Spell_Shadow_DemonBreath",
			["Portal"] = "INV_Misc_QuestionMark",
			["Tram"] = "INV_Misc_MissileSmall_White",
			["Zeppelin"] = "INV_Misc_MissileSmall_Red",
		}
		local portalT = {
			["Blasted Lands"] = "Achievement_Zone_BlastedLands_01",
			["Darnassus"] = "Spell_Arcane_TeleportDarnassus",
			["Exodar"] = "Spell_Arcane_TeleportExodar",
			["Hellfire Peninsula"] = "Achievement_Zone_HellfirePeninsula_01",
			["Ironforge"] = "Spell_Arcane_TeleportIronForge",
			["Isle of Quel'Danas"] = "Achievement_Zone_IsleOfQuelDanas",
			["Lake Wintergrasp"] = "Ability_WIntergrasp_rank1",
			["Orgrimmar"] = "Spell_Arcane_TeleportOrgrimmar",
			["Shattrath"] = "Spell_Arcane_TeleportShattrath",
			["Silvermoon"] = "Spell_Arcane_TeleportSilvermoon",
			["Stormwind"] = "Spell_Arcane_TeleportStormWind",
			["Thunder Bluff"] = "Spell_Arcane_TeleportThunderBluff",
			["Undercity"] = "Spell_Arcane_TeleportUnderCity",
		}
		
		for i, str in ipairs (Nx.ZoneConnections) do

			local flags, conTime, mapId1, x1, y1, mapId2, x2, y2, name1, name2 = Nx.Map:ConnectionUnpack (str)
			if conTime ~= 1 then

--				Nx.prt ("Travel %s %s, flags %x", name1, name2, flags)

				local fac = bit.band (flags, 6) / 2
				local facStr = fac == 1 and "^FA" or fac == 2 and "^FH" or ""

				if Nx.compat:tsize (name1) > 0 then

					local f = {}
					tinsert (folder, f)

					f.Name = format ("%s", name1)
					f.Fac = fac
					f.MapId = mapId1
					f.ConIndex = i
					f.T = "*" .. i .. facStr

					local typ, locName = Nx.compat:strmatch (name1, "(%S+) to (.+)")
					f.Tx = typ == "Portal" and portalT[locName] or txT[typ]

--					Nx.prt ("%s", typ or "nil")
				end

				if Nx.compat:tsize (name2) > 0 and bit.band (flags, 1) ~= 0 then

					local f = {}
					tinsert (folder, f)

					f.Name = format ("%s", name2)
					f.Fac = fac
					f.MapId = mapId2
					f.ConIndex = i
					f.Con2 = true
					f.T = "*b" .. i .. facStr

					local typ, locName = Nx.compat:strmatch (name2, "(%S+) to (.+)")
					f.Tx = typ == "Portal" and portalT[locName] or txT[typ]

--					Nx.prt ("%s", typ or "nil")
				end
			end
		end

		sort (folder, function (a, b) return a.Name < b.Name end)

	elseif folder.Name == "Herb" then

		for n = 1, 499 do
			local name, tx, skill = Nx:GetGather ("H", n)
			if not name then
				break
			end

			local f = {}
			f.Name = name
			f.Column2 = format ("%3d", skill)
			f.T = "$H" .. n
			f.Tx = tx
			f.Id = n
			folder[n] = f
		end

	elseif folder.Name == "Ore" then

		for n = 1, 499 do
			local name, tx, skill = Nx:GetGather ("M", n)
			if not name then
				break
			end

			local f = {}
			f.Name = name
			f.Column2 = format ("%3d", skill)
			f.T = "$M" .. (n + 500)
			f.Tx = tx
			f.Id = n
			folder[n] = f
		end

	elseif folder.Map and folder.Map <= 2 then		-- Map

		-- if folder.Map == 4 and not Nx.V30 then
		-- 	parent[5] = nil	-- Careful!
		-- 	return
		-- end

		local Map = Nx.Map
		local cont1 = folder.Map
		local cont2 = cont1

		if cont1 == 0 then
			cont1 = 1
			cont2 = Map.ContCnt
		end

		for cont = cont1, cont2 do

			local info = Map.MapInfo[cont]
			for id = info.Min, info.Max do

				if Nx.V30 or id ~= 2030 then		-- Skip DK starting area

					local f = {}
					local color, infoStr, minLvl = Map:GetMapNameDesc (id)
					local name = Map:IdToName (id)

					f.Name = format ("%s%s", color, name)
					f.Column2 = infoStr
					f.T = "#Map" .. id
					f.Tx = parent.Tx
					f.MId = id
					f.SrtN = name
					f.Srt = minLvl
					tinsert (folder, f)
				end
			end
		end

		if folder.Map == 0 then
			sort (folder, function (a, b) if a.Srt == b.Srt then return a.SrtN < b.SrtN else return a.Srt < b.Srt end end)
		else
			sort (folder, function (a, b) return a.SrtN < b.SrtN end)
		end

	elseif folder.Inst then		-- Instance

--		if folder.Inst == 4 and not Nx.V30 then
--			parent[4] = nil	-- Careful!
--			return
--		end

		local fcont = folder.Inst
		local n = 1

--		local guideInstStr = "!"

		for nxid, v in ipairs (Nx.Zones) do

			local longname, minLvl, maxLvl, faction, typ, owner, x, y, numPlyr = Nx.compat:strsplit ("!", v)

			if faction == "3" then		-- Instance

				local mapId = Nx.Map.NxzoneToMapId[nxid]
				if mapId then

					local cont = Nx.Map:IdToContZone (mapId)

--					Nx.prt ("%s %s %s", longname, mapId, cont)

					if cont == fcont then

						if not numPlyr then
							Nx.prt ("%s [%s] %s", longname, nxid, v)
						end

						local f = {}
						local numPlyrStr = numPlyr
						if tonumber (numPlyr) == 1025 then
							numPlyrStr = "10/25"
						end

						local plStr = format ("|cffff4040 %s-Man", numPlyrStr)

						f.Name = format ("%s %s", longname, plStr)

						f.Column2 = "?"

						if minLvl ~= "0" then
							if minLvl == maxLvl then
								f.Column2 = format ("%d", minLvl)
							else
								f.Column2 = format ("%d-%d", minLvl, maxLvl)
							end
						end

						f.T = "%In" .. nxid
						f.InstMapId = mapId

						local ownName = Nx.compat:strsplit ("!", Nx.Zones[tonumber (owner)])
						--local x, y = Nx.Quest:UnpackLocPt (pos)
						f.InstTip = format ("%s |cffe0e040Lvl %s\n|r%s (%.1f %.1f)", f.Name, f.Column2, ownName, x, y)

						f.Tx = parent.Tx
						folder[n] = f
						n = n + 1

--						assert (nxid < 221)
--						guideInstStr = format ("%s#%c", guideInstStr, nxid + 35)
					end
				end
			end
		end

	end
end

--------
-- Patch folder data and any children with trial messages

--[[
function Nx.Map.Guide:PatchFolderPaid (folder, parent)

	if not folder.Paid then

		if folder.Name == "Visited Vendor" then
			return
		end

--		Nx.prt ("In Pro %s", folder.Name)
		if folder.Name then
			folder.Name = format ("%s %s", folder.Name, Nx.FreeMsgSP)
		end

		folder.T = nil
		folder.TrialMsg = true
	end

	for showType, child in ipairs (folder) do
		if type (child) == "table" then
			self:PatchFolderPaid (child, folder)
		end
	end
end
--]]

--------
-- Calculate type or folder. Decode custom types ("^C" player class)
-- (folder)
-- ret: type (or nil which will hide), custom (true or nil)

function Nx.Map.Guide:CalcType (folder)

	local typ = type (folder) == "table" and folder.T

	if typ then

		local s1, s2 = Nx.compat:strsplit ("%^", typ)
		-- Nx.prt("%s - %s", s1 or "nil",s2  or "nil")
		if s2 then

			local s21 = Nx.compat:strsub (s2, 1, 1)

			if s2 == "C" then

				local _, cls = UnitClass ("player")
				cls = Nx.Util_CapStr (cls)
				cls = gsub (cls, "Deathknight", "Death Knight")
				return cls .. " Trainer", true

			elseif s21 == "F" then	-- Faction specific

				local s22 = Nx.compat:strsub (s2, 2, 2)
				local fac = self:GetHideFaction()

				if s22 == "A" and fac == 1 then
					return
				end
				if s22 == "H" and fac == 2 then
					return
				end

				return s1

			elseif s21 == "P" then	-- Profession
				local name = Nx.compat:strsub (s2, 2)	-- Get any override for profession name (Herbalism)
				if name == "" then
					name = folder.Pre
				end

				local t = self:GetProfessionTrainer (name)
				t = folder.Pre .. t
				return t, true

			elseif s21 == "S" then	-- Secondary profession
				local name = Nx.compat:strsub (s2, 2)	-- Get any override for secondary name
				if name == "" then
					name = folder.Pre
				end

				local t = self:GetSecondaryTrainer (name)
				t = folder.Pre .. t
				return t, true

			elseif s21 == "G" then
				
				return
			end
		end

		return s1
	end
end

--------
-- Clear all guide folders being shown

function Nx.Map.Guide:ClearAll()

	self.Map:ClearTargets ("Guide")

	self:ClearShowFolders()
	self:Update()
end

function Nx.Map.Guide:ClearShowFolders()

	local opts = Nx:GetGlobalOpts()

	self.ShowFolders = {}

	local gFolder = self:FindFolder ("Gather")

	if Nx.CharOpts["MapShowGatherH"] then
		local folder = self:FindFolder ("Herb", gFolder)
		self:AddShowFolders (folder)
	end

	if Nx.CharOpts["MapShowGatherM"] then
		local folder = self:FindFolder ("Ore", gFolder)
		self:AddShowFolders (folder)
	end

	if Nx.CharOpts["MapShowGatherA"] then
		local folder = self:FindFolder ("Artifacts", gFolder)
		self:AddShowFolders (folder)
	end

	if Nx.CharOpts["QMapShowQuestGivers3"] > 1 then
		local folder = self:FindFolder ("Quest Givers")
		self:AddShowFolders (folder)
	end
end

function Nx.Map.Guide:UpdateGatherFolders()
	self:ClearShowFolders()
	self:Update()
end

--------
-- Add or remove folder to show and any children

function Nx.Map.Guide:AddShowFolders (folder, remove, filter)

	if type (folder) == "table" then

		local typ, filt = self:CalcType (folder)

		filter = filter or filt and typ

		if filter and typ ~= filter and not remove then
			typ = nil
		end

		if typ then
			self.ShowFolders[typ] = not remove and folder or nil
			-- Nx.prt ("Show %s %s", typ, remove and "yes" or "not")
		end

		if remove or not folder.NoShowChild then

			for showType, childFolder in ipairs (folder) do
				self:AddShowFolders (childFolder, remove, filter)
			end
		end
	end
end

--------
-- Is my folder or a childs shown?

function Nx.Map.Guide:IsShowFolders (folder)

	if folder.T then

		local t = self:CalcType (folder)
--		local t = Nx.compat:strsplit ("%^", folder.T)		-- Remove extra stuff

		if self.ShowFolders[t] then
			return true
		end
	end

	for showType, child in ipairs (folder) do
		if type (child) == "table" then
			if self:IsShowFolders (child) then
				return true
			end
		end
	end
end

--------
-- Find folder by name in a folder

function Nx.Map.Guide:FindFolder (name, folder)

	folder = folder or Nx.GuideInfo

	for n, child in ipairs (folder) do

		local cname = gsub (child.Name or child.T, "   >>", "")

		if cname == name then
			return child, n
		end
	end
end

--------
-- Update guide

function Nx.Map.Guide:Update()

--PAIDS!

--	Nx.prt ("Nx.Map.Guide:Update %s\n%s", Nx.Tick, debugstack (2, 3, 0))

	-- Title

	local path = ""

	for n = 2, Nx.compat:tsize (self.PathHistory) do

		local folder = self.PathHistory[n]

		local name = folder.Name
		if strbyte (name) == 64 then		-- @
			name = Nx.GuideAbr[Nx.compat:strsub (name, 2)]
		end

		if n == 2 then
			path = name
		else
			path = path .. "." .. name
		end
	end

	self.Win:SetTitle (path)

	local i = max (Nx.compat:tsize (self.PathHistory) - 1, 1)
	self:UpdateList (self.List, i, 1)

	local i = Nx.compat:tsize (self.PathHistory)
	if i <= 1 then
		i = 0				-- Turn off
	end
	self:UpdateList (self.List2, i, 2)

--PAIDE!

	self:UpdateMapIcons()
end

--------
-- Update guide list

function Nx.Map.Guide:UpdateList (list, pathI, listSide)

	list:Empty()

	local curFolder = self.PathHistory[pathI]

	if curFolder then

		local filterStr = strlower (self.EditBox:GetText())

		if listSide == 1 then	-- Left list?
			filterStr = ""
		end

		if curFolder.Item then
			self:ItemsUpdateFolder (curFolder)
		end

		for index, folder in ipairs (curFolder) do

--			Nx.prtVar ("Folder", folder)

			if type (folder) == "number" then

				local id = folder

				Nx.Item:Load (id)

				local name, iLink, iRarity, minLvl, type, subType, stackCount, equipLoc, tx = GetItemInfo (id)

				local show = true

				if filterStr ~= "" then
					local lstr = strlower (format ("%s", name))
					show = strfind (lstr, filterStr, 1, true)

--					Nx.prt ("Filter %s %s = %s", filterStr, lstr, show or "nil")
				end

				if show then

					if not name then
						name = id .. "?"
						tx = "Interface\\Icons\\INV_Misc_QuestionMark"
					else
						name = Nx.compat:strsub (iLink, 1, 10) .. name	-- Add color
					end

					list:ItemAdd (index)
					list:ItemSet (2, format ("%s", name))

					local tip = iLink and format ("!%s", iLink) or folder.Tip
					list:ItemSetButton ("Guide", false, tx, tip)
				end
			else

				local add = true

				if folder.T then
					add = self:CalcType (folder)		-- Factions are removed here
				end

				if add then

					local name = folder.Name

					if strbyte (name) == 64 then		-- @
						name = Nx.GuideAbr[Nx.compat:strsub (name, 2)]
					end

					local show = true
					local column4

					if filterStr ~= "" then

						local ft = folder.FilterText
						local lstr = strlower (ft or name)
						show = strfind (lstr, filterStr, 1, true)

						if show and ft then
							for n = show, 10, -1 do	-- Search for last newline
								if strbyte (ft, n) == 10 or n == 10 then

									local ftEnd = strfind (ft, "\n", n + 1, true)
									column4 = Nx.compat:strsub (ft, n + 1, ftEnd)
									break
								end
							end
						end

--						Nx.prt ("Filter %s %s = %s", filterStr, lstr, show or "nil")
					end

--					Nx.prt ("Guide %s", name)

					if show then

						local col = "|cffdfdfdf"

						if folder[1] or folder.Item then
							col = "|cff8fdf8f"
							name = name .. "  |cffbf6f6f>>"
						end

						list:ItemAdd (index)
						list:ItemSet (2, format ("%s%s", col, name))

						if listSide == 2 then	-- Right side?

							if folder.Column2 then
								list:ItemSet (3, folder.Column2)
							end

							if folder.Column3 then
								list:ItemSet (4, folder.Column3)
							end

							if column4 then
								list:ItemSet (5, column4)
							end

							if folder.Column4 then
								list:ItemSet (5, folder.Column4)
							end
						end

						local pressed = self:IsShowFolders (folder)

						local tx = folder.Tx

						if not tx then
							for n = Nx.compat:tsize (self.PathHistory), 1, -1 do
								local folder = self.PathHistory[n]
								tx = folder.Tx
								if tx then
									break
								end
							end
						end

						tx = "Interface\\Icons\\" .. tx
						local tip = folder.Link and format ("!%s^%s", folder.Link, folder.Tip or "") or folder.Tip

						list:ItemSetButton ("Guide", pressed, tx, tip)
					end
				end
			end
		end
	end

	list:Update()
end

--------
-- Update map icons

function Nx.Map.Guide:UpdateMapIcons()

	local Nx = Nx
	local Quest = Nx.Quest
	local Map = Nx.Map
	local map = self.Map

	assert (map)

	local hideFac = self:GetHideFaction()

	map:InitIconType ("!G", "WP", "", 16, 16)
	map:SetIconTypeChop ("!G", true)

	map:InitIconType ("!GIn", "WP", "", 20, 20)	-- Instance
	map:SetIconTypeChop ("!GIn", true)

	map:InitIconType ("!Ga", "WP", "", 12, 12)
	local a = map.GOpts["MapIconGatherA"]
	map:SetIconTypeAlpha ("!Ga", a, a < 1 and a * .5)
	map:SetIconTypeChop ("!Ga", true)
	map:SetIconTypeAtScale ("!Ga", map.GOpts["MapIconGatherAtScale"])

	map:InitIconType ("!GQ", "WP", "", 16, 16)
	map:SetIconTypeChop ("!GQ", true)
	map:SetIconTypeLevel ("!GQ", 1)

	map:InitIconType ("!GQC", "WP", "", 10, 10)
	map:SetIconTypeChop ("!GQC", true)

	local cont1 = 1
	local cont2 = Map.ContCnt
	local mapId = map:GetCurrentMapId()

	if not self.ShowAllCont then
		cont1 = map:IdToContZone (mapId)
		cont2 = cont1
	end

	for showType, folder in pairs (self.ShowFolders) do

--		Nx.prt ("folder (%s) %s", showType, folder.Name)

		local mode = strbyte (showType)

		local tx = "Interface\\Icons\\" .. (folder.Tx or "")

		if mode == 36 then		-- $ (Gather)

--			Nx.prt ("Gath icon update %s", GetTime())

			local type = Nx.compat:strsub (showType, 2, 2)
			local longType = type == "H" and "Herb" or type == "M" and "Mine"

			local fid = folder.Id
			local data = longType and Nx:GetData (longType) or NxData.NXGather["Misc"]

			local zoneT = data[mapId]
			if zoneT then

				local nodeT = zoneT[fid]
				if nodeT then

					local iconType = fid == "Art" and "!G" or "!Ga"

					for k, node in ipairs (nodeT) do

--						Nx.prt ("Gath %s %d %d %s %d", showType, k, mid, longType, item.NXId)

						local x, y = Nx:GatherUnpack (node)

						local name, tex, skill = Nx:GetGather (type, fid)
						assert (name)

						local wx, wy = Map:GetWorldPos (mapId, x, y)
						icon = map:AddIconPt (iconType, wx, wy, nil, "Interface\\Icons\\"..tex)

						if skill > 0 then
							name = name .. " " .. skill
						end
						map:SetIconTip (icon, name)
					end
				end
			end

		elseif mode == 35 then		-- # (Map or creature)

		elseif mode == 37 then		-- % (Instance)

			local mapId = folder.InstMapId
			local winfo = Map.MapWorldInfo[mapId]
			local wx = winfo[2]
			local wy = winfo[3]

			local icon = map:AddIconPt ("!GIn", wx, wy, nil, tx)

			map:SetIconTip (icon, folder.InstTip)
			map:SetIconUserData (icon, folder.InstMapId)

		elseif mode == 38 then		-- & (Quest givers)

			if Quest and Quest.QGivers then	-- Nil on init

				local mapId = map:GetCurrentMapId()
				local zone = Nx.MapIdToNxzone[mapId]
				local stzone = Quest.QGivers[zone]

				-- Nx.prt ("%s, %s", zone, stzone or "nil")

				if stzone then

					local opts = Nx:GetGlobalOpts()
					local minLvl = Nx.CurCharacter["Level"] - opts["QMapQuestGiversLowLevel"]
					local maxLvl = Nx.CurCharacter["Level"] + opts["QMapQuestGiversHighLevel"]
					local state = Nx.CharOpts[folder.Persist]

					local debugMap = NxData.DebugMap

					local showComplete = self.ShowQuestGiverCompleted
					local qIds = Quest.QIds

					for namex, qdata in pairs (stzone) do

						local name = Nx.compat:strsplit ("=", namex)
						local anyDaily
						local show
						local s = name
						local qids = {Nx.compat:strsplit("~", qdata)}

						for _, qId in ipairs(qids) do

							local qId = tonumber(qId)
							local quest = Quest.IdToQuest[qId]
							local qname, _, lvl, minlvl = Quest:Unpack (quest[1])

							if lvl < 1 then	-- Some have 0
								lvl = Nx.CurCharacter["Level"]
							end

							if lvl >= minLvl and lvl <= maxLvl then

								local col = "|r"
								local daily = Quest.DailyIds[qId] or Quest.DailyDungeonIds[qId]
								anyDaily = anyDaily or daily

								local status, qTime = Nx:GetQuest (qId)
								if daily then
									col = "|cffa0a0ff"
									show = true
								elseif status == "C" then
									col = "|cff808080"
								else
									if qIds[qId] then
										col = "|cff80f080"
									end

									show = true
								end

								-- local qcati = Quest:UnpackCategory (quest[1])

								-- if qcati > 0 then
								-- 	qname = qname .. " <" .. Nx.QuestCategory[qcati] .. ">"
								-- end

								s = format ("%s\n|cffbfbfbf%d%s %s", s, lvl, col, qname)
								if quest.CNum then
									s = s .. format (" (Part %d)", quest.CNum)
								end
								if daily then

									s = s .. (Quest.DailyDungeonIds[qId] and " (Dungeon Daily" or " (Daily")

									local typ, money, rep, req = Nx.compat:strsplit ("%^", daily)
									if rep and Nx.compat:tsize (rep) > 0 then

										s = s .. ", "

										for n = 0, 1 do	-- Only support 2 reps
											local i = n * 4 + 1
											local repChar = Nx.compat:strsub (rep or "", i, i)
											if repChar == "" then
												break
											end
											s = s .. " " .. Quest.Reputations[repChar]
										end
									end

									s = s .. ")"

								end
								if debugMap then
									s = s .. format (" [%d]", qId)
								end
							end
						end

						if state == 3 and not anyDaily then
							show = false
							showComplete = false
						end

						if show or showComplete then
							local qId = Nx.compat:strsplit("~", qdata)
							local quest = Quest.IdToQuest[tonumber(qId)]
							local startName, zone, x, y = Quest:GetSEPos (quest[2])

							local wx, wy = Map:GetWorldPos (mapId, x, y)
							local tx = anyDaily and "Interface\\AddOns\\Carbonite\\Gfx\\Map\\IconExclaimB" or tx
							local icon = map:AddIconPt (show and "!GQ" or "!GQC", wx, wy, nil, tx)

							map:SetIconTip (icon, s)

--							icon.UDataQuestGiver = name
							icon.UDataQuestGiverD = qdata
						end
					end
				end
			end

		elseif mode == 40 then		-- ( (Visited vendor)

--			Nx.prt ("VendorPos %s", folder.VendorPos or "nil")

			local mapId, x, y = Nx.compat:strsplit ("%^", folder.VendorPos)
			mapId = tonumber (mapId)
			x = tonumber (x)
			y = tonumber (y)
			local wx, wy = Map:GetWorldPos (mapId, x, y)
			local icon = map:AddIconPt ("!G", wx, wy, nil, tx)

			map:SetIconTip (icon, folder.Name)

		elseif mode == 41 then		-- ) (Visited vendor item)

			local vv = NxData.NXVendorV

--			Nx.prtVar ("Item Vendor", folder)

			local t = { Nx.compat:strsplit ("%^", folder.ItemSource) }

			for _, npcName in pairs (t) do

--				Nx.prt ("%s Item VendorPos %s", npcName, vv[npcName]["POS"] or "nil")

				local npc = vv[npcName]		-- Can be nil if you delete while tracking
				if npc then
					local links = npc["POS"]

					local mapId, x, y = Nx.compat:strsplit ("%^", links)
					mapId = tonumber (mapId)
					x = tonumber (x)
					y = tonumber (y)
					local wx, wy = Map:GetWorldPos (mapId, x, y)
					local icon = map:AddIconPt ("!G", wx, wy, nil, tx)

					local tag, name = Nx.compat:strsplit ("~", npcName)
					local iname = Nx.compat:strsplit ("\n", folder.Name)
					map:SetIconTip (icon, format ("%s\n%s\n%s", name, tag, iname))
				end
			end

		elseif mode == 42 then		-- * (Travel)

			local conStr = Nx.ZoneConnections[folder.ConIndex]
			local flags, conTime, mapId1, x1, y1, mapId2, x2, y2, name1, name2 = Nx.Map:ConnectionUnpack (conStr)

			if folder.Con2 then
				mapId1, x1, y1, name1 = mapId2, x2, y2, name2
			end

			local wx, wy = Map:GetWorldPos (mapId1, x1, y1)
			local icon = map:AddIconPt ("!G", wx, wy, nil, tx)
			-- Nx.prt("mapId1 %s", mapId1)
			map:SetIconTip (icon, format ("%s\n%s %.1f %.1f", name1, Nx.MapIdToName[mapId1], x1, y1))

--			Nx.prt ("Travel %s, flags %x", name1, flags)

		else

			for cont = cont1, cont2 do
				self:UpdateMapGeneralIcons (cont, showType, hideFac, tx, folder.Name, "!G")
			end
		end
	end
end

function Nx.Map.Guide:UpdateMapGeneralIcons (cont, showType, hideFac, tx, name, iconType, showMapId)

	if cont >= 90 then
		return
	end

	local Quest = Nx.Quest
	local Map = Nx.Map
	local map = self.Map

	if not Nx.GuideData[showType] then
		Nx.prt ("guide showType %s", showType)
		return
	end

	if Nx.GuideData[showType][cont] then
		for mapId, b in pairs(Nx.GuideData[showType][cont]) do
			if not showMapId or mapId == showMapId then
				for c,d in pairs({Nx.compat:strsplit("|",b)}) do
					local fac,x,y = Nx.compat:strsplit(",",d)
					fac,x,y = tonumber(fac), tonumber(x), tonumber(y)
					if fac ~= hideFac then
						local wx, wy = map:GetWorldPos(mapId, x, y)
						local icon = map:AddIconPt (iconType, wx, wy, nil, tx)
						local npcName = Nx.NPCNames[mapId..","..d] and ( "\n" .. Nx.NPCNames[mapId..","..d]) or ""
						local str = format ("%s\n%s %.1f %.1f", name .. npcName , Nx.MapIdToName[mapId], x, y)
						map:SetIconTip (icon, str)
					end
				end
			end
		end	
	end
end

--------
-- Update zone POI type icons (common stuff)

Nx.GuidePOI = {
	"Auctioneer~Racial_Dwarf_FindTreasure",
	"Banker~INV_Misc_Coin_02",
	"Flight Master~Ability_Druid_FlightForm",
	"Innkeeper~Spell_Shadow_Twilight",
	"Mailbox~INV_Letter_15",
--[[
	"AzuremistIsleBoat~Spell_Shadow_DemonBreath",
	"BootyBayBoat~Spell_Shadow_DemonBreath",
	"MenethilHarborBoat~Spell_Shadow_DemonBreath",
	"RatchetBoat~Spell_Shadow_DemonBreath",
	"TeldrassilBoat~Spell_Shadow_DemonBreath",
	"TheramoreBoat~Spell_Shadow_DemonBreath",
	"DarnassusPortal~Spell_Arcane_TeleportDarnassus",
	"ExodarPortal~Spell_Arcane_TeleportExodar",
	"IronforgePortal~Spell_Arcane_TeleportIronForge",
	"OrgrimmarPortal~Spell_Arcane_TeleportOrgrimmar",
	"SilvermoonPortal~Spell_Arcane_TeleportSilvermoon",
	"StormwindPortal~Spell_Arcane_TeleportStormWind",
	"ThunderBluffPortal~Spell_Arcane_TeleportThunderBluff",
	"UndercityPortal~Spell_Arcane_TeleportUnderCity",
	"Grom'golZeppelin~INV_Misc_MissileSmall_Red",
	"OrgrimmarZeppelin~INV_Misc_MissileSmall_Red",
	"UndercityZeppelin~INV_Misc_MissileSmall_Red",
--]]
	"Alterac Valley Battlemaster~INV_Jewelry_Necklace_21",
	"Arathi Basin Battlemaster~INV_Jewelry_Amulet_07",
	"Arena Battlemaster~Spell_Holy_PrayerOfHealing",
	"Eye Of The Storm Battlemaster~Spell_Nature_EyeOfTheStorm",
	"Strand of the Ancients Battlemaster~INV_Jewelry_Amulet_01",
	"Warsong Gulch Battlemaster~INV_Misc_Rune_07",

	-- Add connections
}

function Nx.Map.Guide:UpdateZonePOIIcons()

	local Quest = Nx.Quest
	local Map = Nx.Map
	local map = self.Map

	local mapId = map.MapId

	local atScale = map.LOpts.NXPOIAtScale
	local alphaRange = atScale * .25
	local s = atScale - alphaRange

	local draw = map.ScaleDraw > s and map.GOpts["MapShowPOI"]

	local alpha = min ((map.ScaleDraw - s) / alphaRange, 1) * map.GOpts["MapIconPOIAlpha"]
	map:SetIconTypeAlpha ("!POI", alpha)
	map:SetIconTypeAlpha ("!POIIn", alpha)

--	Nx.prtCtrl ("%s", alphaPer)

	if mapId == self.POIMapId and draw == self.POIDraw then
		return
	end

	self.POIMapId = mapId
	self.POIDraw = draw

	map:InitIconType ("!POI", "WP", "", 17, 17)
	map:InitIconType ("!POIIn", "WP", "", 21, 21)

	if not draw then
		return
	end

--FREES!
	if Nx.Free then
		if mapId ~= Nx.MapIdFree1 and mapId ~= Nx.MapIdFree2 then
			return
		end
	end
--FREEE!

	map:SetIconTypeChop ("!POI", true)
	map:SetIconTypeAlpha ("!POI", alpha)
	map:SetIconTypeChop ("!POIIn", true)
	map:SetIconTypeAlpha ("!POIIn", alpha)

	local hideFac = UnitFactionGroup ("player") == "Horde" and 1 or 2

	local cont = map:IdToContZone (mapId)

--	Nx.prt ("zpoi mapid %s, cont %s", mapId, cont)

	if cont > 0 and cont <= Map.ContCnt then

		for k, name in ipairs (Nx.GuidePOI) do

			local showType, tx = Nx.compat:strsplit ("~", name)

			if showType == "Mailbox" then
				showType = map.GOpts["MapShowMailboxes"] and showType
			end

			if showType then
				tx = "Interface\\Icons\\" .. tx
				self:UpdateMapGeneralIcons (cont, showType, hideFac, tx, showType, "!POI", mapId)
			end
		end

		self:UpdateInstanceIcons (cont)
		self:UpdateTravelIcons (hideFac)
	end
end

--------
-- Update map icons

function Nx.Map.Guide:UpdateInstanceIcons (cont)

	local Map = Nx.Map
	local map = self.Map

	local folder = self:FindFolder ("Instances")
	local inst = folder[cont]

	if not inst then	-- Happens for WotLK
		return
	end

	for showType, folder in ipairs (inst) do

		local mapId = folder.InstMapId
		local winfo = Map.MapWorldInfo[mapId]

		if winfo.EntryMId == map.MapId then

			local wx = winfo[2]
			local wy = winfo[3]

			local icon = map:AddIconPt ("!POIIn", wx, wy, nil, "Interface\\Icons\\INV_Misc_ShadowEgg")

			map:SetIconTip (icon, folder.InstTip)
			map:SetIconUserData (icon, folder.InstMapId)
		end
	end
end

--------
-- Update map icons

function Nx.Map.Guide:UpdateTravelIcons (hideFac)

	local Map = Nx.Map
	local map = self.Map
	local mapId = map.MapId

	local folder = self:FindFolder ("Travel")

	for showType, folder in ipairs (folder) do

		if folder.MapId == mapId and folder.Fac ~= hideFac then

			local conStr = Nx.ZoneConnections[folder.ConIndex]
			local flags, conTime, mapId1, x1, y1, mapId2, x2, y2, name1, name2 = Nx.Map:ConnectionUnpack (conStr)

			if folder.Con2 then
				mapId1, x1, y1, name1 = mapId2, x2, y2, name2
			end

			local wx, wy = Map:GetWorldPos (mapId1, x1, y1)
			local icon = map:AddIconPt ("!POI", wx, wy, nil, "Interface\\Icons\\" .. folder.Tx)

			map:SetIconTip (icon, format ("%s\n%s %.1f %.1f", name1, Nx.MapIdToName[mapId1], x1, y1))
		end
	end

	local winfo = Map.MapWorldInfo[mapId]
	if winfo then

		if winfo.Connections then

			for id, zcon in pairs (winfo.Connections) do
				for n, con in ipairs (zcon) do

					local wx, wy = con.StartX, con.StartY
--					local wx, wy = Map:GetWorldPos (mapId1, x1, y1)
					local icon = map:AddIconPt ("!POI", wx, wy, nil, "Interface\\Icons\\Spell_Nature_FarSight")
					map:SetIconTip (icon, "Connection to " .. Nx.MapIdToName[con.EndMapId])

					local wx, wy = con.EndX, con.EndY
					local icon = map:AddIconPt ("!POI", wx, wy, nil, "Interface\\Icons\\Spell_Nature_FarSight")
--					map:SetIconTip (icon, "Connection")
				end
			end
		end
	end
end

--------

function Nx.Map.Guide:OnMapUpdate()

	local typ = self.FindingClosest
	if typ then

		local t, folder = self.Map:GetTargetInfo()
		if t == "Guide" and type (folder) == "table" then

			local npcI, mapId, x, y = self:FindClosest (typ)

			if npcI then
				self.Map:SetTarget ("Guide", x, y, x, y, false, folder, folder.Name, false, mapId)
			end
		end
	end

end

--------
-- Find closest

function Nx.Map.Guide:FindClosest (findType)

	local Quest = Nx.Quest
	local Map = Nx.Map
	local map = self.Map
	assert (map)

	local cont1 = 1
	local cont2 = Map.ContCnt

	if not self.ShowAllCont then
		local mapId = map.RMapId
		cont1 = map:IdToContZone (mapId)
		cont2 = cont1
	end

	local hideFac = self:GetHideFaction()

	local close
	local closeMapId, closeX, closeY
	local closeDist = 999999999

	local px = map.PlyrX
	local py = map.PlyrY

--	local dist = ((midX - px) ^ 2 + (midY - py) ^ 2) ^ .5 * 4.575

--	Nx.prt ("FindClose %s", findType)

	for showType, folder in pairs (self.ShowFolders) do

		if showType == findType then

			local mode = strbyte (showType)

			if mode == 36 then		-- $

				local type = Nx.compat:strsub (showType, 2, 2)
				local longType = type == "H" and "Herb" or type == "M" and "Mine"

				if longType then

					local fid = folder.Id
					local data = Nx:GetData (longType)

					for cont = cont1, cont2 do

						local idmin = Map.MapInfo[cont].Min
						local idmax = Map.MapInfo[cont].Max

						for mapId = idmin, idmax do

							local zoneT = data[mapId]
							if zoneT then

								local nodeT = zoneT[fid]
								if nodeT then

									for k, node in ipairs (nodeT) do

--										Nx.prt ("Gath %d %s", mapId, longType)

										local x, y = Nx:GatherUnpack (node)
										local wx, wy = Map:GetWorldPos (mapId, x, y)

										local dist = (wx - px) ^ 2 + (wy - py) ^ 2
										if dist < closeDist then

											closeDist = dist
											close = 0
											closeMapId = mapId
											closeX, closeY = wx, wy
										end
									end
								end
							end
						end
					end
				end

			elseif mode == 35 then		-- #

			elseif mode == 37 then		-- %

			elseif mode == 38 then		-- &

			elseif mode == 40 then		-- (

				local mapId, x, y = Nx.compat:strsplit ("%^", folder.VendorPos)
				mapId = tonumber (mapId)
				x = tonumber (x)
				y = tonumber (y)
				local wx, wy = Map:GetWorldPos (mapId, x, y)

				local dist = (wx - px) ^ 2 + (wy - py) ^ 2
				if dist < closeDist then

					closeDist = dist
					close = 0
					closeMapId = mapId
					closeX, closeY = wx, wy
				end

			elseif mode == 41 then		-- )

				local vv = NxData.NXVendorV

--				Nx.prtVar ("Item Vendor", folder)

				local t = { Nx.compat:strsplit ("%^", folder.ItemSource) }

				for _, npcName in pairs (t) do

--					Nx.prt ("%s Item VendorPos %s", npcName, vv[npcName]["POS"] or "nil")

					local links = vv[npcName]["POS"]

					local mapId, x, y = Nx.compat:strsplit ("%^", links)
					mapId = tonumber (mapId)
					x = tonumber (x)
					y = tonumber (y)
					local wx, wy = Map:GetWorldPos (mapId, x, y)

					local dist = (wx - px) ^ 2 + (wy - py) ^ 2
					if dist < closeDist then

						closeDist = dist
						close = 0
						closeMapId = mapId
						closeX, closeY = wx, wy
					end
				end

			elseif mode == 42 then		-- *

			else
				for cont = cont1, cont2 do

					local data0 = Nx.GuideData[showType]
					if not data0 then
						return
					end

					if data0[cont] then
						for mapId, b in pairs(data0[cont]) do
							if mapId then
								local temp_arr = { Nx.compat:strsplit("|",b) }
								for c,d in pairs(temp_arr) do
									local fac,x,y = Nx.compat:strsplit(",",d)
									fac,x,y = tonumber(fac), tonumber(x), tonumber(y)
									if fac ~= hideFac then
										local wx, wy = map:GetWorldPos (mapId, x, y)
										local dist = (wx - px) ^ 2 + (wy - py) ^ 2
										if dist < closeDist then
--											Nx.prt ("FindClose %s %d", showType, n)
											closeDist = dist
											close = 0
											closeMapId = mapId
											closeX, closeY = wx, wy
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	return close, closeMapId, closeX, closeY
end

--------
-- Get faction we are hiding
-- ret 1 Alliance or 2 Horde

function Nx.Map.Guide:GetHideFaction()

	local fac = UnitFactionGroup ("player") == "Horde" and 1 or 2

	if self.ShowEnemy then
		fac = fac == 1 and 2 or 1	-- Flip
	end

	return fac
end

--------
-- Get profession trainer name rank

function Nx.Map.Guide:GetProfessionTrainer (profName)

--[[
	local trainer = "Apprentice"
	local hIndex
	local open

	for n = 1, GetNumSkillLines() do
		local name, hdr, expanded = GetSkillLineInfo (n)
		if name == "Professions" and hdr then
			hIndex = n
			if not expanded then
				ExpandSkillHeader (n)
				open = n
			end
			break
		end
	end

	if hIndex then
		for n = hIndex + 1, GetNumSkillLines() do

			local name, hdr, expanded, rank, tempPoints, modifier = GetSkillLineInfo (n)

			if hdr then
				break
			end

			if name == profName then
--				rank = tonumber (rank)
--				Nx.prtVar ("rank", rank)

				trainer = rank >= 275 and "Master" or rank >= 200 and "Artisan" or rank >= 125 and "Expert" or rank >= 50 and "Journeyman" or "Apprentice"

--				Nx.prt ("%s %d %d %s %s %s = %s", name, hdr or 0, expanded or 0, rank, tempPoints, modifier, trainer)
			end
		end
	end

	if open then
		CollapseSkillHeader (open)
	end

	return trainer
--]]

	return " Trainer"
end

--------
-- Get profession trainer name rank

function Nx.Map.Guide:GetSecondaryTrainer (profName)

--[[
	local trainer = "Apprentice"
	local hIndex
	local open

	for n = 1, GetNumSkillLines() do
		local name, hdr, expanded = GetSkillLineInfo (n)
		if name == "Secondary Skills" and hdr then
			hIndex = n
			if not expanded then
				ExpandSkillHeader (n)
				open = n
			end
			break
		end
	end

	if hIndex then
		for n = hIndex + 1, GetNumSkillLines() do

			local name, hdr, expanded, rank, tempPoints, modifier = GetSkillLineInfo (n)

			if hdr then
				break
			end

			if name == profName then
--				rank = tonumber (rank)
--				Nx.prtVar ("rank", rank)

				trainer = rank >= 275 and "Master" or rank >= 225 and "Artisan" or rank >= 125 and "Expert" or rank >= 50 and "Journeyman" or "Apprentice"

--				Nx.prt ("%s %d %d %s %s %s = %s", name, hdr or 0, expanded or 0, rank, tempPoints, modifier, trainer)
			end
		end
	end

	if open then
		CollapseSkillHeader (open)
	end

	return trainer
--]]

	return " Trainer"
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Guide visited capturing

--Nx.Map.Guide.MUCnt = 0

function Nx.Map.Guide.OnPlayer_target_changed()

	local self = Nx.Map.Guide

--	Nx.prt ("OnPLAYER_TARGET_CHANGED")

	if UnitPlayerControlled ("target") or not UnitName ("target") then
		return
	end

	if Nx.compat:tsize (self.PlayerTargets) > 5 then
		tremove (self.PlayerTargets)
	end

	local tag = GameTooltipTextLeft2:GetText() or ""
	local lvl = GameTooltipTextLeft3:GetText() or ""
	local faction = GameTooltipTextLeft4:GetText() or ""
	if strfind (tag, "%^" .. NXlLEVELSPC) then
		tag = ""
		faction = lvl
	end

	local str = format ("%s~%s~%s", tag, GameTooltipTextLeft1:GetText() or "", faction)
	tinsert (self.PlayerTargets, 1, str)

--	Nx.prt ("Target %s (%s)", UnitName ("target") or "nil", self.PlayerTargets[1])
end

--------
-- Save target info for current NPC

function Nx.Map.Guide:SavePlayerNPCTarget()

	local npcName = UnitName ("NPC") or "?"
	self.PlayerNPCTarget = "?~" .. npcName

	for n, str in ipairs (self.PlayerTargets) do

		local tag, name = Nx.compat:strsplit ("~", str)
		if npcName == name then
			self.PlayerNPCTarget = str
			break
		end
	end

	local map = Nx.Map:GetMap (1)
	local s = Nx:PackXY (map.PlyrRZX, map.PlyrRZY)
	self.PlayerNPCTargetPos = format ("%d^%s", Nx.MapIdToNxzone[map.RMapId] or 0, s)
end

--------

function Nx.Map.Guide.OnGossip_show()

	local self = Nx.Map.Guide

--	Nx.prt ("OnGossip_show")

	self:SavePlayerNPCTarget()
	self:CaptureNPC ("G")
end

function Nx.Map.Guide.OnTrainer_show()

	local self = Nx.Map.Guide

--	Nx.prt ("OnTRAINER_SHOW")

	self:SavePlayerNPCTarget()
	self:CaptureNPC ("T")
end

--------
-- Capture a NPC

function Nx.Map.Guide:CaptureNPC (data)

	local opts = Nx:GetGlobalOpts()

	if not opts["CaptureEnable"] then
		return
	end

	local cap = Nx:GetCap()

	local npcs = Nx:CaptureFind (cap, "NPC")

	local len = 0

	for _, str in pairs (npcs) do
		len = len + 4 + Nx.compat:tsize (str) + 1
	end

	if len > 5 * 1024 then		-- About 250
		return
	end

	local name = self.PlayerNPCTarget
	local facI = UnitFactionGroup ("player") == "Horde" and 1 or 0

	npcs[name] = format ("%s^%d^%s", self.PlayerNPCTargetPos, facI, data)

--	Nx.prt ("%s = %s", name, npcs[name])
end

-------------------------------------------------------------------------------
-- Guide visited vendor capturing

--------

function Nx.Map.Guide.OnMerchant_show()

	local self = Nx.Map.Guide

--	Nx.prt ("OnMerchant_show")

	self:SavePlayerNPCTarget()
	self.VendorRepair = CanMerchantRepair()

	self:CaptureNPC (format ("M%s", self.VendorRepair and 1 or 0))

--	Nx.prt ("Tar %s (%s)", UnitName ("NPC") or "nil", self.PlayerNPCTarget)

	self.CanCap = true
	self.OnMerchant_update()
end

--------
-- Merchant update event (happens over 30 times if items not in cache)

function Nx.Map.Guide.OnMerchant_update()

--	Nx.prt ("OnMerchant_update")

	local self = Nx.Map.Guide

	if self.CanCap then
		Nx.Timer:Start ("Vendor", .3, self, self.CapTimer)		-- Buffer if many events
	end

--	self.MUCnt = self.MUCnt + 1
--	Nx.prt ("OnMerchant_update %s", self.MUCnt)
end

function Nx.Map.Guide:CapTimer()

--	Nx.prt ("CapTimer %s", self.MUCnt or "nil")
	Nx.Timer:ProfilerStart ("Guide CapTimer")

	local map = Nx.Map:GetMap (1)
	local g = map.Guide

	local ok = g:CaptureItems()

	g:UpdateVisitedVendors()
	g:Update()

	Nx.Timer:ProfilerEnd ("Guide CapTimer")

	if not ok and MerchantFrame:IsVisible() then
		if Nx.LootOn then
			Nx.prt ("CapTimer retry")
		end
		return .5
	end

	self.CanCap = false		-- One cap per merchant show
end

function Nx.Map.Guide:UpdateVisitedVendors()

--	Nx.prt ("UpdateVisitedVendors")

	local vv = NxData.NXVendorV

	if not vv or (NxData.NXVendorVVersion or 0) < Nx.VERSIONVENDORV then
		vv = {}
		NxData.NXVendorV = vv
		NxData.NXVendorVVersion = Nx.VERSIONVENDORV
	end

	local folder = self:FindFolder ("Visited Vendor")
	assert (folder)

	if folder then

		local allFolder = folder[1]
		for n = 1, Nx.compat:tsize (allFolder) do
			allFolder[n] = nil
		end

		for n = 2, Nx.compat:tsize (folder) do	-- Skip all folder
			folder[n] = nil
		end

		local unique = {}

		for npcName, links in pairs (vv) do
			local tag = Nx.compat:strsplit ("~", npcName)
			unique [tag] = true
		end

		local uniqueTag
		local tagFolder

		local uniqueItems = {}

		local vsorted = {}

		for npcName, links in pairs (vv) do
			tinsert (vsorted, npcName)
		end

		sort (vsorted)
--		sort (vsorted, function (a, b) return NxData.NXVendorV[a]["T"] > NxData.NXVendorV[b]["T"] end)

		for _, npcName in ipairs (vsorted) do

			local tag, name = Nx.compat:strsplit ("~", npcName)

			if uniqueTag ~= tag then

				uniqueTag = tag
				tagFolder = {}
				tagFolder.Name = format ("%s", tag)
				tinsert (folder, tagFolder)
			end

			local links = vv[npcName]

--			Nx.prt ("%s", npcName)

			local npcF = {}

			local mapId = Nx.compat:strsplit ("%^", links["POS"])
			mapId = tonumber (mapId)

			npcF.T = "(" .. npcName
			npcF.Tx = "INV_Misc_Coin_05"
			local repair = links["R"] and " (Repair)" or ""
			npcF.Name = format ("%s  |cff8080c0%s\n|cffc0c0c0%s%s", tag, Nx.Map:IdToName (mapId), name, repair)
			npcF.VendorPos = links["POS"]
			npcF.NoShowChild = true

			tinsert (tagFolder, npcF)

			local n = 1
			while n <= Nx.compat:tsize (links) do

				local id = Nx.compat:strsplit ("%^", links[n])
				local name = GetItemInfo (id)
				if not name then
					if Nx.Item:Load (id) then	-- Failed before?
						tremove (links, n)
						Nx.prt ("Removed old vendor item %s", id)
						n = n - 1
					end
				end
				n = n + 1
			end

			for _, item in ipairs (links) do

				local id, price = Nx.compat:strsplit ("%^", item)
				local name, iLink, iRarity, minLvl, type, subType, stackCount, equipLoc, tx = GetItemInfo (id)

				name = name or format ("%s", id)

				local itemF = uniqueItems[id]

				if itemF then

					itemF.ItemSource = itemF.ItemSource .. "^" .. npcName

				else

					itemF = {}

					itemF.ItemSource = npcName
					itemF.SortName = name

					uniqueItems[id] = itemF

					itemF.T = ")" .. id

					if iLink then

--						Nx.prt (" Item %s (%s)", name, tx)

						local col = Nx.compat:strsub (iLink, 1, 10)

						itemF.Name = format ("%s%s\n   %s", col, name, price)
--						itemF.Name = itemF.Name .. " " .. id
						itemF.Link = iLink
						itemF.Tx = gsub (tx, "Interface\\Icons\\", "")

--						local minStr = ""
						if minLvl > 1 then
--							minStr = format (" (%d)", minLvl)
							itemF.Column2 = format ("L%2d", minLvl)
						end

					else
						itemF.Name = name
						itemF.Tx = "INV_Misc_QuestionMark"
					end
				end

				tinsert (npcF, itemF)
			end

			sort (npcF, function (a, b) return a.SortName < b.SortName end)
		end

		for _, itemF in pairs (uniqueItems) do
			tinsert (allFolder, itemF)
		end

		sort (allFolder, function (a, b) return a and b and (a.SortName < b.SortName) end)
	end

	Nx.Timer:ProfilerStart ("Guide CapTimer gc")
	collectgarbage ()
	Nx.Timer:ProfilerEnd ("Guide CapTimer gc")
end

Nx.VendorCostAbr = {
	["INV_Jewelry_Amulet_07"] = "AB",
	["INV_Jewelry_Necklace_21"] = "AV",
	["Spell_Nature_EyeOfTheStorm"] = "EOS",
	["INV_Misc_Rune_07"] = "WG",
	["Spell_Holy_ChampionsBond"] = "Badge of Justice", -- Shatar
	["INV_Misc_Dust_06"] = "Holy Dust",			-- Alder
	["INV_Misc_Rune_05"] = "Arcane Rune",		-- Scyer
---[[
	["INV_Chest_Chain_03"] = "Chestguard Token", -- of the Fallen Defender",
	["INV_Gauntlets_27"] = "Gloves Token",
	["INV_Helmet_24"] = "Helm Token",
	["INV_Pants_Plate_17"] = "Leggings Token",
	["INV_Shoulder_22"] = "Pauldrons Token",
	["INV_Misc_Apexis_Shard"] = "Apexis Shard",
	["INV_Misc_Apexis_Crystal"] = "Apexis Crystal",
	["INV_Misc_Token_Thrallmar"] = "Thrallmar Token",
	["INV_Misc_Rune_08"] = "Battle Token",
	["INV_Misc_Rune_09"] = "Research Token",
	["Spell_Holy_ProclaimChampion"] = "Emblem of Heroism",
	["Spell_Holy_ProclaimChampion_02"] = "Emblem of Valor",
	["INV_Misc_Platnumdisks"] = "Stone Keeper's Shard",
	["INV_Enchant_AbyssCrystal"] = "Abyss Crystal",
	["INV_Enchant_DreamShard_02"] = "Dream Shard",
	["INV_Misc_LeatherScrap_19"] = "Heavy Borean Leather",
	["INV_Misc_Pelt_14"] = "Arctic Fur",
--]]
}

function Nx.Map.Guide:CaptureItems()

	if not NxData.NXVendorV then
		return
	end

	local opts = Nx:GetGlobalOpts()

--	NxData.VendorV = nil

	local map = Nx.Map:GetMap (1)

	if MerchantFrame:IsVisible() then

		local vcabr = Nx.VendorCostAbr
		local npc = self.PlayerNPCTarget
		local tag, name = Nx.compat:strsplit ("~", npc)
		npc = format ("%s~%s", tag, name)

--		Nx.prt ("%s", npc)

		local links = {}

		links["POS"] = format ("%d^%s^%s", map.RMapId, map.PlyrRZX, map.PlyrRZY)
		links["T"] = time()
		links["R"] = self.VendorRepair

--		Nx.prtVar ("links2", links)

		for n = 1, GetMerchantNumItems() do

			local name, tx, price, quantity, numAvail, usable, exCost = GetMerchantItemInfo (n)
			local link = GetMerchantItemLink (n)

--			Nx.prt ("%s", gsub (link or "nil link", "|", "x"))

			if not name then
--				Nx.prt ("Vendor %s missing item %s (%s)", npc, n, name or "nil")
				return	-- Retry
			end

			if not link then
				link = " :" .. name	-- Use name for id
			end

			local priceStr = Nx.Util_GetMoneyStr (price)

			if exCost then
				local iCnt = GetMerchantItemCostInfo (n)	--V4

				if price <= 0 then
					priceStr = ""
				else
					priceStr = priceStr .. " "
				end

				if iCnt > 0 then

					for i = 1, MAX_ITEM_COST do

						local tx, value = GetMerchantItemCostItem (n, i)
						if tx and value and value > 0 then

--							Nx.prt ("cost %s", tx)

							tx = gsub (tx, "Interface\\Icons\\", "")

							if strfind (tx, "-Honor-") then	--V4
								tx = " honor"
							end

							if strfind (tx, "-justice") then	--V4
								tx = " justice"
							end

							if strfind (tx, "-valor") then	--V4.2
								tx = " valor"
							end

							priceStr = priceStr .. format (" |r%d %s", value, vcabr[tx] or tx)

--							Nx.prt ("price %s", priceStr)
						end
					end
				end
			end

			local _, id = Nx.compat:strsplit (":", link)
			links[n] = id .. "^" .. Nx.compat:strtrim (priceStr)

--			Nx.prt ("%s", links[n])
		end

		local vv = NxData.NXVendorV

--		NxData.VendorCap = nil

		vv[npc] = links

		local oName
		local maxCnt = min (max (1, opts["GuideVendorVMax"]), 1000)
		opts["GuideVendorVMax"] = maxCnt

		while true do

			local old = 999999999999
			local cnt = 0

			for npcName, links in pairs (vv) do
				cnt = cnt + 1
				if links["T"] < old then	-- Oldest
					old = links["T"]
					oName = npcName
				end
			end

			if cnt <= maxCnt then		-- Ok?
				break
			end

			vv[oName] = nil	-- Kill
		end

		if Nx.LootOn then
			Nx.prt ("Captured %s (%d)", npc, Nx.compat:tsize (links))
		end

		return true
	end
end

-------------------------------------------------------------------------------

--------
-- Find taxi using localized name

function Nx.Map.Guide:FindTaxis (campName)

	local Map = Nx.Map
	local Quest = Nx.Quest
	local hideFac = UnitFactionGroup ("player") == "Horde" and 1 or 2

	for cont = 1, Map.ContCnt do
		for mapId, data in pairs(Nx.GuideData["Flight Master"][cont] or {}) do
			local dataTbl = {Nx.compat:strsplit ("|", data)}
			for i, fxy in pairs(dataTbl) do
				local fac, x, y = Nx.compat:strsplit (",", fxy)
				if fac ~= hideFac then
					local namecamp = Nx.NPCNames[mapId..","..fxy]
					local name, camp = Nx.compat:strsplit (",", namecamp)
					camp = Nx.compat:strsub(camp,2)
					camp = NXlTaxiNames[camp] or camp	-- Localize it
					if camp == campName then
						local wx, wy = Map:GetWorldPos (mapId, x, y)
						return name, wx, wy
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------

Nx.Map.Guide.ItemCats = {
	{
		Name = "Armor",
		Tx = "Spell_Holy_ArdentDefender",
		{
			Name = "Cloth",
			Tx = "INV_Chest_Cloth_21",
			{
				Name = "Head",
				T = "Cloth",
				Tx = "INV_Helmet_31",
				Item = 1,
			},
			{
				Name = "Shoulders",
				T = "Cloth",
				Tx = "INV_Shoulder_09",
				Item = 3,
			},
			{
				Name = "Chest",
				T = "Cloth",
				Tx = "INV_Chest_Cloth_21",
				Item = 5,
			},
			{
				Name = "Wrists",
				T = "Cloth",
				Tx = "INV_Bracer_10",
				Item = 9,
			},
			{
				Name = "Hands",
				T = "Cloth",
				Tx = "INV_Gauntlets_18",
				Item = 10,
			},
			{
				Name = "Waist",
				T = "Cloth",
				Tx = "INV_Belt_02",
				Item = 6,
			},
			{
				Name = "Legs",
				T = "Cloth",
				Tx = "INV_Pants_Cloth_01",
				Item = 7,
			},
			{
				Name = "Feet",
				T = "Cloth",
				Tx = "INV_Boots_Cloth_03",
				Item = 8,
			},
			{
				Name = "Back",
				T = "Cloth",
				Tx = "INV_Misc_Cape_10",
				Item = 16,
			},
		},
		{
			Name = "Leather",
			Tx = "INV_Chest_Leather_01",
			{
				Name = "Head",
				T = "Leather",
				Tx = "INV_Helmet_43",
				Item = 1,
			},
			{
				Name = "Shoulders",
				T = "Leather",
				Tx = "INV_Shoulder_09",
				Item = 3,
			},
			{
				Name = "Chest",
				T = "Leather",
				Tx = "INV_Chest_Cloth_21",
				Item = 5,
			},
			{
				Name = "Wrists",
				T = "Leather",
				Tx = "INV_Bracer_10",
				Item = 9,
			},
			{
				Name = "Hands",
				T = "Leather",
				Tx = "INV_Gauntlets_18",
				Item = 10,
			},
			{
				Name = "Waist",
				T = "Leather",
				Tx = "INV_Belt_02",
				Item = 6,
			},
			{
				Name = "Legs",
				T = "Leather",
				Tx = "INV_Pants_Cloth_01",
				Item = 7,
			},
			{
				Name = "Feet",
				T = "Leather",
				Tx = "INV_Boots_Cloth_03",
				Item = 8,
			},
		},
		{
			Name = "Mail",
			Tx = "INV_Chest_Chain_05",
			{
				Name = "Head",
				T = "Mail",
				Tx = "INV_Helmet_43",
				Item = 1,
			},
			{
				Name = "Shoulders",
				T = "Mail",
				Tx = "INV_Shoulder_09",
				Item = 3,
			},
			{
				Name = "Chest",
				T = "Mail",
				Tx = "INV_Chest_Cloth_21",
				Item = 5,
			},
			{
				Name = "Wrists",
				T = "Mail",
				Tx = "INV_Bracer_10",
				Item = 9,
			},
			{
				Name = "Hands",
				T = "Mail",
				Tx = "INV_Gauntlets_18",
				Item = 10,
			},
			{
				Name = "Waist",
				T = "Mail",
				Tx = "INV_Belt_02",
				Item = 6,
			},
			{
				Name = "Legs",
				T = "Mail",
				Tx = "INV_Pants_Cloth_01",
				Item = 7,
			},
			{
				Name = "Feet",
				T = "Mail",
				Tx = "INV_Boots_Cloth_03",
				Item = 8,
			},
		},
		{
			Name = "Plate",
			Tx = "INV_Chest_Plate05",
			{
				Name = "Head",
				T = "Plate",
				Tx = "INV_Helmet_43",
				Item = 1,
			},
			{
				Name = "Shoulders",
				T = "Plate",
				Tx = "INV_Shoulder_09",
				Item = 3,
			},
			{
				Name = "Chest",
				T = "Plate",
				Tx = "INV_Chest_Cloth_21",
				Item = 5,
			},
			{
				Name = "Wrists",
				T = "Plate",
				Tx = "INV_Bracer_10",
				Item = 9,
			},
			{
				Name = "Hands",
				T = "Plate",
				Tx = "INV_Gauntlets_18",
				Item = 10,
			},
			{
				Name = "Waist",
				T = "Plate",
				Tx = "INV_Belt_02",
				Item = 6,
			},
			{
				Name = "Legs",
				T = "Plate",
				Tx = "INV_Pants_Cloth_01",
				Item = 7,
			},
			{
				Name = "Feet",
				T = "Plate",
				Tx = "INV_Boots_Cloth_03",
				Item = 8,
			},
		},
		{
--			Name = "Shields",
			T = "Shields",
			Tx = "INV_Shield_04",
			Item = -9,
		},
	},
	{
		Name = "Consumables",
		Tx = "INV_Alchemy_Elixir_Empty",
		{
			Name = "Foods & Drinks",
			T = "Food & Drink",
			Tx = "INV_Misc_Food_64",
			Item = -9,
		},
		{
			Name = "Potions & Elixirs",
			T = "Potion^Elixir",
			Tx = "INV_Alchemy_Elixir_05",
			Item = -9,
		},
		{
			Name = "Flasks",
			T = "Flask",
			Tx = "INV_Alchemy_EndlessFlask_03",
			Item = -9,
		},
	},
	{
		Name = "Miscellaneous",
		Tx = "INV_Jewelry_Ring_42",
		{
			Name = "Gems",
			Tx = "INV_Jewelcrafting_IceDiamond_02",
			{
				Name = "Six Colors",
				T = "Red^Orange^Yellow^Green^Blue^Purple",
				Tx = "INV_Jewelcrafting_Gem_01",
				Item = -9,
			},
			{
				T = "Red",
				Tx = "INV_Jewelcrafting_LivingRuby_03",
				Item = -9,
			},
			{
				T = "Orange",
				Tx = "INV_Jewelcrafting_NobleTopaz_03",
				Item = -9,
			},
			{
				T = "Yellow",
				Tx = "INV_Jewelcrafting_Dawnstone_03",
				Item = -9,
			},
			{
				T = "Green",
				Tx = "INV_Jewelcrafting_Talasite_03",
				Item = -9,
			},
			{
				T = "Blue",
				Tx = "INV_Jewelcrafting_StarOfElune_03",
				Item = -9,
			},
			{
				T = "Purple",
				Tx = "INV_Jewelcrafting_Nightseye_03",
				Item = -9,
			},
			{
				T = "Meta",
				Item = -9,
			},
			{
				T = "Prismatic",
				Tx = "INV_Enchant_PrismaticSphere",
				Item = -9,
			},
		},
		{
			Name = "Glyphs",
			Tx = "INV_Glyph_MajorDeathKnight",
			{
				Name = "Death Knight",		-- Need name because of space
				T = "Death Knight",
				Item = -9,
			},
			{
				T = "Druid",
				Item = -9,
			},
			{
				T = "Hunter",
				Item = -9,
			},
			{
				T = "Mage",
				Item = -9,
			},
			{
				T = "Paladin",
				Item = -9,
			},
			{
				T = "Priest",
				Item = -9,
			},
			{
				T = "Rogue",
				Item = -9,
			},
			{
				T = "Shaman",
				Item = -9,
			},
			{
				T = "Warlock",
				Item = -9,
			},
			{
				T = "Warrior",
				Item = -9,
			},
			-- {
			-- 	T = "Monk",
			-- 	Item = -9,
			-- },
		},
		{
			Name = "Necklaces",
			T = "Miscellaneous",
			Tx = "INV_Jewelry_Necklace_02",
			Item = 2,
		},
		{
			Name = "Rings",
			T = "Miscellaneous",
			Tx = "INV_Jewelry_Ring_03",
			Item = 11,
		},
		{
			Name = "Trinkets",
			T = "Miscellaneous",
			Tx = "INV_Jewelry_TrinketPVP_02",
			Item = 12,
		},
		{
			Name = "Off-Hand",
			T = "Miscellaneous",
			Tx = "INV_Offhand_Hyjal_D_01",
			Item = 23,
		},
		{
			Name = "Idols",
			T = "Idols",
			Tx = "INV_Misc_Idol_03",
			Item = -9,
		},
		{
			Name = "Librams",
			T = "Librams",
			Tx = "INV_Misc_Idol_03",
			Item = -9,
		},
		{
			Name = "Sigils",
			T = "Sigils",
			Tx = "INV_Misc_Idol_03",
			Item = -9,
		},
		{
			Name = "Totems",
			T = "Totems",
			Tx = "INV_Misc_Idol_03",
			Item = -9,
		},
	},
	{
		Name = "Professions",
		Tx = "Trade_Tailoring",
		{
			Name = "Alchemy",
			T = "Alchemy",
			Tx = "Trade_Alchemy",
			Item = -9,
		},
		{
			Name = "Blacksmithing",
			T = "Blacksmithing",
			Tx = "Trade_Blacksmithing",
			Item = -9,
		},
		{
			Name = "Cooking",
			T = "Cooking",
			Tx = "INV_Misc_Food_15",
			Item = -9,
		},
		{
			Name = "Enchanting",
			T = "Enchanting",
			Tx = "Trade_Engraving",
			Item = -9,
		},
		{
			Name = "Engineering",
			T = "Engineering",
			Tx = "Trade_Engineering",
			Item = -9,
		},
		-- {
		-- 	Name = "Jewelcrafting",
		-- 	T = "Jewelcrafting",
		-- 	Tx = "INV_Misc_Gem_02",
		-- 	Item = -9,
		-- },
		{
			Name = "Leatherworking",
			T = "Leatherworking",
			Tx = "INV_Misc_ArmorKit_17",
			Item = -9,
		},
		{
			Name = "Tailoring",
			T = "Tailoring",
			Tx = "Trade_Tailoring",
			Item = -9,
		},
	},
	{
		Name = "Weapons",
		Tx = "Achievement_Arena_3v3_4",
		{
			Name = "One-Handed",
			Tx = "INV_Sword_04",
			{
				Name = "Daggers",
				T = "Daggers",
				Tx = "INV_Weapon_ShortBlade_01",
				Item = -9,
			},
			{
				Name = "Fist Weapons",
				T = "Fist Weapons",
				Tx = "INV_Weapon_Hand_02",
				Item = -9,
			},
			{
				Name = "One-Handed Axes",
				T = "One-Handed Axes",
				Tx = "INV_Axe_01",
				Item = -9,
			},
			{
				Name = "One-Handed Maces",
				T = "One-Handed Maces",
				Tx = "INV_Mace_04",
				Item = -9,
			},
			{
				Name = "One-Handed Swords",
				T = "One-Handed Swords",
				Tx = "INV_Sword_04",
				Item = -9,
			},
		},
		{
			Name = "Two-Handed",
			Tx = "INV_Sword_25",
			{
				Name = "Polearms",
				T = "Polearms",
				Tx = "INV_Spear_06",
				Item = -9,
			},
			{
				Name = "Staves",
				T = "Staves",
				Tx = "INV_Staff_10",
				Item = -9,
			},
			{
				Name = "Two-Handed Axes",
				T = "Two-Handed Axes",
				Tx = "INV_Axe_01",
				Item = -9,
			},
			{
				Name = "Two-Handed Maces",
				T = "Two-Handed Maces",
				Tx = "INV_Mace_04",
				Item = -9,
			},
			{
				Name = "Two-Handed Swords",
				T = "Two-Handed Swords",
				Tx = "INV_Sword_25",
				Item = -9,
			},
		},
		{
			Name = "Ranged",
			Tx = "INV_Weapon_Bow_07",
			{
				Name = "Arrows",
				T = "Arrow",
				Tx = "INV_Misc_Ammo_Arrow_01",
				Item = -9,
			},
			{
				Name = "Bullets",
				T = "Bullet",
				Tx = "INV_Misc_Ammo_Bullet_02",
				Item = -9,
			},
			{
				Name = "Bows",
				T = "Bows",
				Tx = "INV_Weapon_Bow_07",
				Item = -9,
			},
			{
				Name = "Crossbows",
				T = "Crossbows",
				Tx = "INV_Weapon_Crossbow_02",
				Item = -9,
			},
			{
				Name = "Guns",
				T = "Guns",
				Tx = "INV_Weapon_Rifle_01",
				Item = -9,
			},
			{
				Name = "Thrown",
				T = "Thrown",
				Tx = "INV_ThrowingKnife_02",
				Item = -9,
			},
			{
				Name = "Wands",
				T = "Wands",
				Tx = "INV_Wand_11",
				Item = -9,
			},
		},
	},
	{
		Name = "Creatures",
		Tx = "Spell_Frost_Stun",
		Item = -8,
	},
}

Nx.Map.Guide.ItemStatNames = {
	"",				-- Allowable Classes
	"^%d - %d %s",					-- Damage
	"^\tSpeed %.2f\n",
	"^+%d - %d %s\n",				-- Damage2 (extra stuff)
	"^(%.1f damage per second)\n",
	"Armor^%d Armor\n",
	"Block^%d Block\n",
	"Stamina",
	"Agility",
	"Strength",
	"Intellect",
	"Spirit",
	"Attack Power",
	"Spell Power",
	"Crit Rating",
	"Haste Rating",
	"Hit Rating",
	"Resilience",
	"Defense Rating",
	"Dodge Rating",
	"Parry Rating",
	"Shield Block Rating",
	"Expertise Rating",
	"Arcane Resistance",
	"Fire Resistance",
	"Frost Resistance",
	"Nature Resistance",
	"Shadow Resistance",
	"^|TInterface\\ItemSocketingFrame\\UI-EmptySocket-Meta:16:16|t Meta Socket\n",
	"^|TInterface\\ItemSocketingFrame\\UI-EmptySocket-Red:16:16|t Red Socket\n",
	"^|TInterface\\ItemSocketingFrame\\UI-EmptySocket-Yellow:16:16|t Yellow Socket\n",
	"^|TInterface\\ItemSocketingFrame\\UI-EmptySocket-Blue:16:16|t Blue Socket\n",
	"",	-- Required skill
}

Nx.Map.Guide.ItemStatLen = {
	-3,
	-1, 3, -1, 3,
	2,	2, 2, 2, 2, 2, 2, 2, 2,
	1,
	2,
	1, 1, 1, 1, 2, 1, 1,
	1, 1, 1, 1, 1,
	0, 0, 0, 0,
	-2
}

Nx.Map.Guide.ItemStatAllowableClass = {
	"Death Knight",
	"Druid",
	"Hunter",
	"Mage",
	"Paladin",
	"Priest",
	"Rogue",
	"Shaman",
	"Warlock",
	"Warrior",
	-- "Monk",
}

Nx.Map.Guide.ItemStatRequiredSkill = {
	"Alchemy",
	"Blacksmithing",
	"Cooking",
	"Enchanting",
	"Engineering",
	"First Aid",
	"Fishing",
	"Herbalism",
	"Jewelcrafting",
	"Leatherworking",
	"Mining",
	"Inscription",
	"Riding",
	"Tailoring"
}

Nx.Map.Guide.ItemTypeNames = {
	"Arrow^Projectile","Bullet^Projectile","Bow^Ranged","Crossbow^Ranged","Gun^Ranged",
	"Fist Weapon","Dagger","Axe","Mace","Sword",
	"Polearm^Two-Hand","Staff^Two-Hand","Axe^Two-Hand","Mace^Two-Hand","Sword^Two-Hand",
	"Thrown^Thrown", "Wand^Ranged",
	"Idol^Relic", "Libram^Relic", "Sigil^Relic", "Totem^Relic",
	"Shield^Off Hand",
	"Cloth^1",
	"Cloth^3",
	"Cloth^5",
	"Cloth^6",
	"Cloth^7",
	"Cloth^8",
	"Cloth^9",
	"Cloth^10",
	"Cloth^16",
	"Leather^1",
	"Leather^3",
	"Leather^5",
	"Leather^6",
	"Leather^7",
	"Leather^8",
	"Leather^9",
	"Leather^10",
	"Mail^1",
	"Mail^3",
	"Mail^5",
	"Mail^6",
	"Mail^7",
	"Mail^8",
	"Mail^9",
	"Mail^10",
	"Plate^1",
	"Plate^3",
	"Plate^5",
	"Plate^6",
	"Plate^7",
	"Plate^8",
	"Plate^9",
	"Plate^10",
	"Miscellaneous^2",
	"Miscellaneous^11",
	"Miscellaneous^12",
	"Miscellaneous^23",
	"Alchemy","Blacksmithing","Cooking","Enchanting","Engineering",
	"Jewelcrafting","Leatherworking","Tailoring",
	"Food",
	"Elixir",
	"Flask",
	"Potion",
	"Death Knight",		-- Glyphs
	"Druid",
	"Hunter",
	"Mage",
	"Paladin",
	"Priest",
	"Rogue",
	"Shaman",
	"Warlock",
	"Warrior",
	"Monk",
	"Red",					-- Gems
	"Yellow",
	"Blue",
	"Orange",
	"Green",
	"Purple",
	"Meta",
	"Prismatic",
}

Nx.Map.Guide.ItemSlotNames = {
	"Head", "Neck", "Shoulder", "", "Chest",
	"Waist", "Legs", "Feet", "Wrist", "Hands",
	"Finger", "Trinket",
	[16] = "Back",
	[23] = "Off Hand",
}

--Interface\ICONS\INV_Pants_02
--Interface\ICONS\INV_Gauntlets_18
--Interface\ICONS\INV_Belt_02
--Interface\ICONS\INV_Boots_03
--Interface\ICONS\INV_Sword_04

function Nx.Map.Guide:ItemInit()

	self.ItemBindT = { "", "Binds when picked up\n", "Binds when equipped\n", "Binds when used\n" }
	self.ItemHandT = { "One-Hand", "Main Hand", "Off Hand" }
	self.ItemDamageT = { "Damage", "Holy Damage", "Fire Damage", "Nature Damage", "Frost Damage", "Shadow Damage", "Arcane Damage" }
	self.ItemTriggerT = { "Use: ", "Equip: ", "Chance on hit: ", "", "", "", "Use: " }	-- #4 is mine for descriptions

	local folder = self:FindFolder ("Items")
	assert (folder)

	for n, data in pairs (self.ItemCats) do
--		Nx.prt ("Item %s", data.T)
		folder[n] = data	-- Copy over
	end

	self.ItemCats = nil
end

function Nx.Map.Guide:ItemsUpdateFolder (folder)

	if folder[1] then		-- Have items?
		return
	end

--	Nx.prt ("ItemsUpdateFolder %s", folder.Name)

	self:ItemsLoad()

	local root = CarboniteItems
	if not root then
		folder[1] = { Name = "CarboniteItems addon missing" }
		return
	end

	if folder.Item == -8 then
		if not folder[1] then		-- Not created?
			self:ItemsInitCreatureFolders (folder)
		end
		return
	end

	local typs = { Nx.compat:strsplit ("%^", folder.T) }

	for _, typ in ipairs (typs) do

		local items = folder.ItemData or root[folder.Item < 0 and typ or typ .. folder.Item]

--		Nx.prt ("%s %s cat %s", folder.Name, typ, folder.Item or "nil")

		assert (items)

		for n = 1, Nx.compat:tsize (items), 3 do
			local id = (strbyte (items, n) - 35) * 48841 + (strbyte (items, n + 1) - 35) * 221 + strbyte (items, n + 2) - 35
			self:ItemsAddItem (folder, id)
		end

		sort (folder, function (a, b) return a.Sort < b.Sort end)	-- Default to alphabetical

	end
end

function Nx.Map.Guide:ItemsInitCreatureFolders (folder)

	local cSrc = CarboniteItems["CSrc"]

	for areaName, areaData in pairs (cSrc) do

		local areaT = {}
		tinsert (folder, areaT)

		areaT.Name = Nx.compat:strsub (areaName, 4)
		local aMin = strbyte (areaName) - 35
		local aMax = strbyte (areaName, 2) - 35
		local aGroup = strbyte (areaName, 3) - 35
		if aMin == aMax then
			areaT.Column2 = format ("%2d", aMin)
		else
			areaT.Column2 = format ("%2d-%d", aMin, aMax)
		end
		areaT.Column3 = format ("%2d-Man", aGroup)

		for cName, cData in pairs (areaData) do

			local cT = {}
			tinsert (areaT, cT)

			local dif = strbyte (cName)
			cName = Nx.compat:strsub (cName, 2)
			if dif - 35 > 1 then
				cName = cName .. " (Heroic)"
			end
			cT.Name = cName
			cT.T = "#"
			cT.Item = -9
			cT.ItemData = cData

--			for n = 1, #cData, 3 do
--				local id = (strbyte (cData, n) - 35) * 48841 + (strbyte (cData, n + 1) - 35) * 221 + strbyte (cData, n + 2) - 35
--				self:ItemsAddItem (cT, id)
--			end

--			sort (cT, function (a, b) return a.Name < b.Name end)	-- Default to alphabetical
		end

		sort (areaT, function (a, b) return a.Name < b.Name end)	-- Default to alphabetical
	end

	sort (folder, function (a, b) return a.Name < b.Name end)	-- Default to alphabetical
end

function Nx.Map.Guide:ItemsAddItem (folder, id)

	local root = CarboniteItems

	local info, stats, statsExtra, src = Nx.compat:strsplit ("\t", root["Items"][id])

	if not info then
		Nx.prt ("bad %s", id)
	end

	local flags = strbyte (info, 2) - 35

--	if id == 49968 then
--		Nx.prt ("%d flags %x", id, flags)
--	end

	local unique = bit.band (flags, 4) > 0
	local binding = bit.band (bit.rshift (flags, 3), 3) + 1

	local iMin = strbyte (info, 3) - 35
	local iLvl = (strbyte (info, 4) - 35) * 221 + strbyte (info, 5) - 35
	local quality = strbyte (info, 6) - 35

	local name = ""

	for n = 7, Nx.compat:tsize (info) - 1, 2 do
		local h, l = strbyte (info, n, n + 1)
		name = name .. root.Words[(h - 35) * 221 + l - 35] .. " "
	end

	item = {}
	tinsert (folder, item)

	item.Name = Nx.QualityColors[quality] .. name
	item.Sort = name

	stats = self:ItemsUnpackStats (stats)
	statsExtra = self:ItemsUnpackStatsExtra (statsExtra, id)
	local srcStr = self:ItemsUnpackSource (src, item)

	local im = max (iMin, 0)
	item.Column2 = format ("L%2d i%3d", im, iLvl)

	item.Column3 = format ("%s", srcStr)

	local _, iLink, iRarity, minLvl, iType, subType, stackCount, equipLoc, tx = GetItemInfo (id)
	item.Link = iLink

--	item.Link = format ("|cffffff00|Hitem:%s:0:0:0:0:0:0:0|h[%s]|h|r", id, id)

	item.Tx = tx and gsub (tx, "Interface\\Icons\\", "") or "INV_Misc_QuestionMark"

--	Nx.prt ("Tx %s %s", name, tx or "nil")

	local typ, slot = Nx.compat:strsplit ("%^", self.ItemTypeNames[strbyte (info) - 35])

	local i = tonumber (slot)
	if i then
		slot = self.ItemSlotNames[i]

	elseif not slot then

		local i = bit.band (flags, 3)
		if i > 0 then		-- One handed item?
			slot = self.ItemHandT[i]
		else
			slot = typ		-- Switch to left column
			typ = ""
		end
	end

	local s = item.Name .. "\n" .. self.ItemBindT[binding]

	if unique then
		s = s .. "Unique\n"
	end

	if iMin > 0 then	-- Have min?
		if bit.band (flags, tonumber("0x20", 16)) == 0 then		-- Not from a quest?
			stats = stats .. format ("Requires Level %d\n", iMin)
		else
			stats = stats .. format ("Quest Level %d\n", iMin)
		end
	end

	item.Tip = format ("%s%s\n%s%s%s",
			s,
			slot .. "\t" .. typ,
			stats, statsExtra, srcStr)

	item.FilterText = item.Tip

end

function Nx.Map.Guide:ItemsUnpackStats (stats)

	if Nx.compat:tsize (stats) == 0 then
		return ""
	end

	local sb = strbyte

	local out = ""

	local n = 1
	while n <= Nx.compat:tsize (stats) do

--		Nx.prtStrHex ("Stat", Nx.compat:strsub (stats, n, n + 3))
--		assert (sb (stats, n + 3))

		local typ = sb (stats, n) - 35

		local name, spec = Nx.compat:strsplit ("%^", self.ItemStatNames[typ] or "?")

		local val = 0

		local len = self.ItemStatLen[typ]
		if len == 1 then

			val = sb (stats, n + 1) - 35
			n = n + 2

		elseif len == 2 then
			val = (sb (stats, n + 1) - 35) * 221 + sb (stats, n + 2) - 35 - 1000
			n = n + 3

		elseif len == 3 then

			val = ((sb (stats, n + 1) - 35) * 48841 + (sb (stats, n + 2) - 35) * 221 + sb (stats, n + 3) - 35 - 1000) * .1
			n = n + 4

		elseif len == -1 then	-- Damage

			local damTyp = sb (stats, n + 1) - 34		-- Base 1
			local damMin = (sb (stats, n + 2) - 35) * 221 + sb (stats, n + 3) - 35
			local damMax = (sb (stats, n + 4) - 35) * 221 + sb (stats, n + 5) - 35

			if damMin == damMax then
				spec = gsub (spec, " -- %%d", "")
				out = out .. format (spec, damMin, self.ItemDamageT[damTyp])
--				Nx.prt (spec, damMin, self.ItemDamageT[damTyp])
			else
				out = out .. format (spec, damMin, damMax, self.ItemDamageT[damTyp])
			end

			n = n + 6

		elseif len == -2 then	-- Required skill

			local skTyp = sb (stats, n + 1) - 35
			local skill = (sb (stats, n + 2) - 35) * 221 + sb (stats, n + 3) - 35

			out = out .. format ("Requires %s (%d)\n", self.ItemStatRequiredSkill[skTyp], skill)

			n = n + 4

		elseif len == -3 then	-- Allowable Classes

			local s = ""

			local cnt = sb (stats, n + 1) - 35
			for n2 = 1, cnt do
				local cls = sb (stats, n + 1 + n2) - 35
				s = s .. format ("%s, ", self.ItemStatAllowableClass[cls])
			end

			out = out .. format ("Classes: %s\n", s)

			n = n + 2 + cnt

		else
			n = n + 1

		end

		if len >= 0 then
			if spec then
				out = out .. format (spec, val)
			else
				out = out .. format ("%+d %s\n", val, name)
			end
		end
	end

	return out
end

function Nx.Map.Guide:ItemsUnpackStatsExtra (stats, id)

	if Nx.compat:tsize (stats) == 0 then
		return ""
	end

--	Nx.prt ("Item %s", id)

	local sb = strbyte

	local words = CarboniteItems["Words"]
	local out = ""

	local n = 1
	while n < Nx.compat:tsize (stats) do

		local trigger = sb (stats, n) - 35
		local len = sb (stats, n + 1) - 35
--		local len = (sb (stats, n + 1) - 35) * 221 + sb (stats, n + 2) - 35
--		local desc = Nx.compat:strsub (stats, n + 3, n + 2 + len)

		local desc = ""
		for n2 = n + 2, n + 1 + len, 2 do
			local h, l = strbyte (stats, n2, n2 + 1)
--			if not h or id == 9492 then
--				Nx.prtStrHex (format ("%s %s %s", id, n2, len), stats)
--			end
			desc = desc .. words[(h - 35) * 221 + l - 35] .. " "
		end

		out = out .. format ("|cff10f010%s%s\n", self.ItemTriggerT[trigger], desc)

		n = n + 2 + len
	end

	return out
end

function Nx.Map.Guide:ItemsUnpackSource (src, item)

	if Nx.compat:tsize (src) == 0 then
		return ""
	end

	local itemDiff = { "", "normal", "heroic" }
	local ratesT = { ".1%", "1-2%", "3-14%", "15-24%", "25-50%", "51%-99%", "100%" }

	local s = ""

	local typ = strbyte (src, 1)

	if typ == 99 then		-- c (creature drop)

		local cnt = strbyte (src, 2) - 35
		for n = 1, cnt do
		end

		local rate = ratesT[strbyte (src, 2) - 34]	-- Make base 1

		local i = (strbyte (src, 3) - 35) * 221 + strbyte (src, 4) - 35
		local creature = CarboniteItems["Sources"][i]

		local dif = itemDiff[strbyte (creature, 1) - 34]	-- Make base 1

		s = format ("Creature drop: %s %s (%s)", Nx.compat:strsub (creature, 2), dif, rate)

	elseif typ == 111 then		-- o (object)

		s = format ("Container: %s", Nx.compat:strsub (src, 2))

	elseif typ == 113 then		-- q (quest)

		local cnt = strbyte (src, 2) - 35
		local qs = ""

		for n = 1, cnt do
			if n > 1 then
				qs = qs .. ", "
			end
			local i = n * 2
			local id = (strbyte (src, 1 + i) - 35) * 221 + strbyte (src, 2 + i) - 35
			local q = Nx.Quest.IdToQuest[id]
			if q then

				item.QId = id
				local qName, _, lvl = Nx.Quest:Unpack (q[1])
				qs = qs .. format ("[%d] %s", lvl, qName)

			else
				qs = qs .. id
			end
		end

		s = format ("Quest: %s", qs)

	elseif typ == 115 then		-- s (spell)

--		local cnt = strbyte (src, 2) - 35
		s = format ("Spell")

	elseif typ == 118 then		-- v (vendor)

		local cnt = strbyte (src, 2) - 35
		local i = (strbyte (src, 3) - 35) * 221 + strbyte (src, 4) - 35
		local vendor = CarboniteItems["Sources"][i]

		s = format ("Vendor: %s", vendor)
		if cnt > 4 then
			s = s .. " (" .. cnt .. " Total)"
		end

	elseif typ == 119 then		-- w (world drop)

		if Nx.compat:tsize (src) == 1 then
			return "World drop"
		end

		local maxRate = ratesT[strbyte (src, 2) - 34]	-- Make base 1
		local cnt = strbyte (src, 3) - 35

		s = format ("World drop: %s (%s)", Nx.compat:strsub (src, 4), maxRate)

		if cnt > 1 then
			s = s .. " (" .. cnt .. " Total)"
		end

	else
		s = format ("%s?", typ)
	end

	return "|cff8080e0" .. s
end

function Nx.Map.Guide:ItemsLoad()

	if CarboniteItems then
		return
	end

	if not LoadAddOn ("CarboniteItems") then
		Nx.prt ("CarboniteItems addon could not be loaded!")
		return
	end

	if not CarboniteItems then
		Nx.prt ("CarboniteItems addon error!")
		return
	end

	Nx.prt ("CarboniteItems loaded")
end

--------

function Nx.Map.Guide:ItemsFree()

--	Nx.prt ("Guide free")

	local folder = self:FindFolder ("Items")
	self:ItemsFreeChildren (folder)

	collectgarbage ()
end

function Nx.Map.Guide:ItemsFreeChildren (folder)

	for n, v in ipairs (folder) do

		if folder.Item and folder.Item ~= -8 then
			folder[n] = nil
--			Nx.prt ("free %s", v.Name or "nil")
		else
			self:ItemsFreeChildren (v)
		end
	end
end

-------------------------------------------------------------------------------
-- EOF














