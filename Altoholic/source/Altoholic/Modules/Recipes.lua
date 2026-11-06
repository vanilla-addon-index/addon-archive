local BI = LibStub("LibBabble-Inventory-3.0"):GetLookupTable()
local L = AceLibrary("AceLocale-2.2"):new("Altoholic")
local V = Altoholic.vars
local TEAL		= "|cFF00FF9A"

function Altoholic:Recipes_Update()
	local raw = Altoholic:ResolveLinkedChar(V.CurrentFaction, V.CurrentRealm, V.CurrentLinkedAccount, V.CurrentAlt)		-- current alt
	local profession = raw and raw.recipes and raw.recipes[V.CurrentProfession]
	local VisibleLines = 14
	local frame = "AltoRecipes"
	local entry = frame.."Entry"
	local nameSuffix = ""
	if V.CurrentLinkedAccount then
		nameSuffix = " (" .. V.CurrentLinkedAccount .. ")"
	end
	if (not profession) or profession.ScanFailed then
		getglobal("AltoholicFrame_Status"):SetText(L["No data: "] .. V.CurrentProfession .. L[" scan failed for "] .. ": |cFFFFD700" .. V.CurrentAlt .. " of ".. V.CurrentRealm .. nameSuffix)
		getglobal("AltoholicFrame_Status"):Show()
		self:ClearScrollFrame(getglobal(frame.."ScrollFrame"), entry, VisibleLines, 18)
		return
	else
		getglobal("AltoholicFrame_Status"):SetText("|cFFFFD700" .. V.CurrentAlt .. " of ".. V.CurrentRealm .. nameSuffix .. " |cFFFFFFFF" .. V.CurrentProfession .. ": " .. V.CurrentProfessionLevel)
		getglobal("AltoholicFrame_Status"):Show()
	end
	local offset = FauxScrollFrame_GetOffset(getglobal(frame.."ScrollFrame"));
	local DisplayedCount = 0
	local VisibleCount = 0
	local DrawGroup = true
	local i=1
    for line, s in pairs(profession.list or {}) do
		if (offset > 0) or (DisplayedCount >= VisibleLines) then		-- if the line will not be visible
			if s.isHeader then													-- then keep track of counters
				if not s.isCollapsed then
					DrawGroup = true
				else
					DrawGroup = false
				end
				VisibleCount = VisibleCount + 1
				offset = offset - 1		-- no further control, nevermind if it goes negative
			elseif DrawGroup then
				VisibleCount = VisibleCount + 1
				offset = offset - 1		-- no further control, nevermind if it goes negative
			end
		else		-- line will be displayed
			if s.isHeader then
				if not s.isCollapsed then
					getglobal(entry..i.."Collapse"):SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up"); 
					DrawGroup = true
				else
					getglobal(entry..i.."Collapse"):SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
					DrawGroup = false
				end
				getglobal(entry..i.."Collapse"):Show()
				getglobal(entry..i.."RecipeLinkNormalText"):SetText(TEAL .. s.name)
				getglobal(entry..i.."RecipeLink"):SetID(0)
				getglobal(entry..i.."RecipeLink"):SetPoint("TOPLEFT", 25, 0)
                for j=1, 8 do
					getglobal(entry..i .. "Item" .. j):Hide()
				end
				getglobal(entry..i):SetID(line)
				getglobal(entry..i):Show()
				i = i + 1
				VisibleCount = VisibleCount + 1
				DisplayedCount = DisplayedCount + 1		
			elseif DrawGroup then
				getglobal(entry..i.."Collapse"):Hide()
				getglobal(entry..i.."RecipeLinkNormalText"):SetText(s.link)
				getglobal(entry..i.."RecipeLink"):SetID(line)
				getglobal(entry..i.."RecipeLink"):SetPoint("TOPLEFT", 15, 0)
                local numReagents = s.numReagents
				for j=1, 8 do
					local itemName = entry..i .. "Item" .. j;
                    local _, _, first, second, third, fourth, fifth, sixth, seventh, eighth = string.find(s.reagents, "(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)")
                    local _, _, first, second, third, fourth, fifth, sixth, seventh = string.find(s.reagents, "(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)")
                    local _, _, first, second, third, fourth, fifth, sixth = string.find(s.reagents, "(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)")
                    local _, _, first, second, third, fourth, fifth = string.find(s.reagents, "(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)")
                    local _, _, first, second, third, fourth = string.find(s.reagents, "(%d+:%d+)|(%d+:%d+)|(%d+:%d+)|(%d+:%d+)")
                    local _, _, first, second, third = string.find(s.reagents, "(%d+:%d+)|(%d+:%d+)|(%d+:%d+)")
                    local _, _, first, second = string.find(s.reagents, "(%d+:%d+)|(%d+:%d+)")
                    local _, _, first = string.find(s.reagents, "(%d+:%d+)")
                    if eighth ~= nil and j == 8 then
                        reagent = eighth
                    elseif seventh ~= nil and j == 7 then
                        reagent = seventh
                    elseif sixth ~= nil and j == 6 then
                        reagent = sixth
                    elseif fifth ~= nil and j == 5 then
                        reagent = fifth
                    elseif fourth ~= nil and j == 4 then
                        reagent = fourth
                    elseif third ~= nil and j == 3 then
                        reagent = third
                    elseif second ~= nil and j == 2 then
                        reagent = second
                    elseif first ~= nil and j == 1 then
                        reagent = first
                    else
                        reagent = nil
                    end
					if reagent then
                        local _, _, reagentID, reagentCount = string.find(reagent, "(%d+):(%d+)")
                        reagentID = tonumber(reagentID)
						reagentCount = tonumber(reagentCount)
						local itemButton = getglobal(itemName);
						itemButton:SetID(reagentID)
						local itemTexture = getglobal(itemName .. "IconTexture")
                        local _, _, _, _, _, _, _, _, itexture  = GetItemInfo(reagentID)
						itemTexture:SetTexture(itexture);
						itemTexture:SetWidth(18);
						itemTexture:SetHeight(18);
						itemTexture:SetAllPoints(itemButton);
						local itemCount = getglobal(itemName .. "Count")
						itemCount:SetText(reagentCount);
						itemCount:Show();
						getglobal(itemName):Show()
					else
						getglobal(itemName):Hide()
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

function Altoholic:Recipes_OnClick(button, id)
    local button = arg1
    if ( button == "LeftButton" ) and ( IsShiftKeyDown() ) then
        local v = Altoholic.vars
        local c = Altoholic:ResolveLinkedChar(v.CurrentFaction, v.CurrentRealm, v.CurrentLinkedAccount, v.CurrentAlt)
        local profession = c and c.recipes and c.recipes[v.CurrentProfession]
        local r = profession and profession.list
        if not r then return end
        local link = r[id] and r[id].link
        if not link then return end
        if ( ChatFrameEditBox:IsShown() ) then
            ChatFrameEditBox:Insert(link);
        elseif (WIM_EditBoxInFocus) then
            WIM_EditBoxInFocus:Insert(link);
        end
    end
end

function Altoholic:Recipes_OnEnter(self)
    local id = self:GetParent():GetID()
    local c = Altoholic:ResolveLinkedChar(V.CurrentFaction, V.CurrentRealm, V.CurrentLinkedAccount, V.CurrentAlt)
    local profession = c and c.recipes and c.recipes[V.CurrentProfession]
    local entry = profession and profession.list and profession.list[id]
    if not entry or entry.isHeader then return end
    local itemLink = itemLink
    if V.CurrentProfession == "Enchanting" then
        itemLink = Altoholic:GetEnchantIDFromLink(tostring(entry.link))
    else
        local item = entry.id
        if not item then item=16893 end
        _, itemLink = GetItemInfo(item)
    end
    if not itemLink then return end
    GameTooltip:SetOwner(this, "ANCHOR_LEFT");
    GameTooltip:SetHyperlink(itemLink);
    GameTooltip:Show();
end
