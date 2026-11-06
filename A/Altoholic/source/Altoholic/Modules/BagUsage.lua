local L = AceLibrary("AceLocale-2.2"):new("Altoholic")
local BI = LibStub("LibBabble-Inventory-3.0"):GetLookupTable()
local V = Altoholic.vars
local INFO_REALM_LINE = 1
local INFO_CHARACTER_LINE = 2
local INFO_TOTAL_LINE = 3
local GREEN		= "|cFF00FF00"
local YELLOW	= "|cFFFFFF00"
local GOLD		= "|cFFFFD700"
local CYAN		= "|cFF1CFAFE"

function Altoholic:BagUsage_Update()
	local VisibleLines = 14
	local frame = "AltoBags"
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
				getglobal(entry..i.."Level"):SetText("")
				getglobal(entry..i.."BagSlotsNormalText"):SetText("")
				getglobal(entry..i.."BankSlotsNormalText"):SetText("")
				getglobal(entry..i):SetID(line)
				getglobal(entry..i):Show()
				i = i + 1
				VisibleCount = VisibleCount + 1
				DisplayedCount = DisplayedCount + 1
			elseif DrawRealm then
				if (s.linetype == INFO_CHARACTER_LINE) then
					-- Any of these can be individually missing on a real
					-- record, local or linked, not just absent outright.
					local raw = Altoholic:ResolveLinkedChar(CurrentFaction, CurrentRealm, CurrentLinkedAccount, s.name)
					local c = {
						class = (raw and raw.class) or "",
						race = (raw and raw.race) or "",
						level = (raw and raw.level) or 1,
						bags = (raw and raw.bags) or "",
					}
					local color = self:GetClassColor(c.class)
				
					getglobal(entry..i.."Collapse"):Hide()
					getglobal(entry..i.."Name"):SetText(color .. s.name)
					getglobal(entry..i.."Name"):SetJustifyH("RIGHT")
					getglobal(entry..i.."Name"):SetPoint("TOPLEFT", 15, 0)
					getglobal(entry..i.."Name"):SetWidth(70)
					getglobal(entry..i.."Level"):SetText(color .. "Lv |cFF00FF00" .. c.level .. color .. " " .. c.race .. " " .. c.class)
					getglobal(entry..i.."Level"):SetJustifyH("LEFT")
					getglobal(entry..i.."BagSlotsNormalText"):SetText(c.bags)
					getglobal(entry..i.."BankSlotsNormalText"):SetText(s.bankslots)
				elseif (s.linetype == INFO_TOTAL_LINE) then
					getglobal(entry..i.."Collapse"):Hide()
					getglobal(entry..i.."Name"):SetText(L["Totals"])
					getglobal(entry..i.."Name"):SetJustifyH("LEFT")
					getglobal(entry..i.."Name"):SetPoint("TOPLEFT", 15, 0)
					getglobal(entry..i.."Name"):SetWidth(70)
					getglobal(entry..i.."Level"):SetText(s.level)
					getglobal(entry..i.."Level"):SetJustifyH("RIGHT")
					getglobal(entry..i.."BagSlotsNormalText"):SetText("")
					getglobal(entry..i.."BankSlotsNormalText"):SetText("")
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

function Altoholic_BagUsage_OnEnter(self)
	local line = self:GetParent():GetID()
	local s = Altoholic.CharacterInfo[line]
	
	if s.linetype ~= INFO_CHARACTER_LINE then		
		return
	end
	
	local Faction, Realm, LinkedAccount = Altoholic:GetCharacterInfo(line)
	local raw = Altoholic:ResolveLinkedChar(Faction, Realm, LinkedAccount, s.name)
	if not raw then return end
	local c = raw
	if not c.bag then
		-- Nothing to show slot-by-slot for a record with no bag table at
		-- all (e.g. a stub/incomplete entry) -- the header alone would be
		-- misleading without any of the slot math below it.
		return
	end

	AltoTooltip:ClearLines();
	AltoTooltip:SetOwner(self, "ANCHOR_RIGHT");
	AltoTooltip:AddLine(Altoholic:GetClassColor(c.class) .. s.name,1,1,1);
	AltoTooltip:AddLine(L["Level"] .. " " .. GREEN .. (c.level or 1) .. " |r".. (c.race or "") .. " " .. (c.class or ""),1,1,1);
	AltoTooltip:AddLine(" ",1,1,1);

	local id = self:GetID()
	local numSlots
	local numFree = 0
	
	-- Every size/freeslots read below goes through "or 0": AceDB strips a
	-- field equal to its default (0) when saving, so a linked account's
	-- plain deserialized copy reads back nil for any empty/zero value, and
	-- a bag slot that was never stored at all is simply absent.
	if id == 1 then		-- 1 for player bags, 2 for bank bags
		local bag0 = c.bag["Bag0"] or {}
		local bag0Free = bag0.freeslots or 0
		AltoTooltip:AddLine(GOLD .. "16 |r" .. L["slots"] .. " (" .. GREEN
			.. bag0Free .. "|r " .. L["free"] .. ") [" .. BACKPACK_TOOLTIP .. "]",1,1,1);

		numSlots = 16
		numFree = bag0Free
		for i = 1, 4 do
			local b = c.bag["Bag"..i]
			if b and b.link ~= nil then
				local bag
				if (b.bagtype == nil) or (b.bagtype == 0) then
					bag = ""
				else
					bag = YELLOW .. "(" .. Altoholic:GetBagTypeString(b.bagtype) .. ")"
				end

				AltoTooltip:AddLine(GOLD .. (b.size or 0) .. " |r" .. L["slots"] .. " ("  .. GREEN
						.. (b.freeslots or 0) ..  "|r " ..L["free"] .. ") " .. b.link .. " " .. bag ,1,1,1);
				numSlots = numSlots + (b.size or 0)
				numFree = numFree + (b.freeslots or 0)
			end
		end
	elseif (c.bankslots == nil) or (c.bankslots == "") then
		AltoTooltip:AddLine(L["Bank not visited yet"],1,1,1);
		AltoTooltip:Show();
		return
	else
		local bank = c.bag["Bag100"] or {}
		local bankSize = Altoholic:GetStoredBankSize(bank)
		local bankFree = bank.freeslots or 0
		AltoTooltip:AddLine(GOLD .. bankSize .. " |r" .. L["slots"] .. " (" .. GREEN
						.. bankFree ..  "|r " .. L["free"] .. ") [" .. L["Bank"] .. "]",1,1,1);
		numSlots = bankSize
		numFree = bankFree
		local firstBankBag, lastBankBag = Altoholic:GetBankBagRange()
		for i = firstBankBag, lastBankBag do
			local b = c.bag["Bag"..i]
			if b and b.link ~= nil then
				local bag
				if (b.bagtype == nil) or (b.bagtype == 0) then
					bag = ""
				else
					bag = YELLOW .. "(" .. Altoholic:GetBagTypeString(b.bagtype) .. ")"
				end

				AltoTooltip:AddLine(GOLD .. (b.size or 0) .. " |r" .. L["slots"] .. " ("  .. GREEN
						.. (b.freeslots or 0) ..  "|r " ..L["free"] .. ") " .. b.link .. " " .. bag ,1,1,1);
				numSlots = numSlots + (b.size or 0)
				numFree = numFree + (b.freeslots or 0)
			end
		end
	end
	
	AltoTooltip:AddLine(" ",1,1,1);
	AltoTooltip:AddLine(CYAN .. numSlots .. " |r" .. L["slots"] .. " ("  .. GREEN .. numFree .. "|r " ..L["free"] .. ") ",1,1,1);
	AltoTooltip:Show();	
end

function Altoholic:GetBagTypeString(bagType)
	if bagType == 0 then
		return ""
	elseif bagType == 1 then
		return BI["Quiver"]
	elseif bagType == 2 then
		return BI["Ammo Pouch"]
	elseif bagType == 4 then
		return BI["Soul Bag"]
	elseif bagType == 8 then
		return BI["Leatherworking Bag"]
	elseif bagType == 32 then
		return BI["Herb Bag"]
	elseif bagType == 64 then
		return BI["Enchanting Bag"]
	elseif bagType == 128 then
		return BI["Engineering Bag"]
	elseif bagType == 512 then
		return BI["Gem Bag"]
	elseif bagType == 1024 then
		return BI["Mining Bag"]
	end
	return L["Unknown"]
end
