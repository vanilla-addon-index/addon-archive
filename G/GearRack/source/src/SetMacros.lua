if not GearRack.enabled then return end

-- Gear sets on action bars. Each set owns one character macro, "/gr equip <set>",
-- made on the first drag and kept in step when the set is saved or removed.
-- A macro is GearRack's only while its body is exactly that line, so a player's
-- own macro of the same name is never changed or deleted.

local PREFIX = "/gr equip "
local ICONS = "Interface\\Icons\\"

local function sets()
    return GearRackDB.sets[GearRack.CharacterKey()].Sets
end

-- Macro icons live under Interface\Icons; anything else shows the question mark.
local function macro_icon(texture)
    if type(texture)=="string" and string.lower(string.sub(texture,1,#ICONS))==string.lower(ICONS) then
        return string.sub(texture,#ICONS+1)
    end
    return "INV_Misc_QuestionMark"
end

-- The index of the set's macro, if it still exists and is still GearRack's.
local function owned_macro(setname)
    local set = sets()[setname]
    if not set then return end
    for _,name in ipairs({set.macro or setname,setname}) do
        local _,_,body = GetMacroInfo(name)
        if body and string.gsub(body,"%s+$","")==PREFIX..setname then
            set.macro = name
            return GetMacroIndexByName(name)
        end
    end
end

function GearRack.PickupSetMacro(setname)
    local set = setname and sets()[setname]
    if not set then return end
    local index = owned_macro(setname)
    if not index then
        if GetMacroInfo(setname) then
            DEFAULT_CHAT_FRAME:AddMessage("GearRack: a macro named \""..setname.."\" already exists. Rename it in /macro.")
            return
        end
        index = C_Macro.CreateMacro(setname,macro_icon(set.icon),PREFIX..setname,true)
        if not index then
            DEFAULT_CHAT_FRAME:AddMessage("GearRack: character macros are full (18). Free one in /macro.")
            return
        end
        -- The client may shorten the name; keep the one it stored.
        set.macro = GetMacroInfo(index)
    end
    PickupMacro(index)
end

-- After a save: the set's macro takes its new icon.
function GearRack.UpdateSetMacro(setname)
    local index = owned_macro(setname)
    if index then C_Macro.EditMacro(index,nil,macro_icon(sets()[setname].icon),nil) end
end

-- Before a set is removed: its macro goes, and with it its action buttons.
function GearRack.DeleteSetMacro(setname)
    local index = owned_macro(setname)
    if index then DeleteMacro(index) end
end

local function drag(button,setname)
    button:RegisterForDrag("LeftButton")
    button.gearRackDrag = true
    button:SetScript("OnDragStart",function() GearRack.PickupSetMacro(setname(this)) end)
end

-- Drag handles: the chosen-set icon, the saved-set list and the Sets flyout.
function GearRack.CreateSetMacroHandles()
    drag(GearRackUI_Sets_ChosenIcon,function() return GearRackUI_Sets_Name:GetText() end)
    local function saved(row)
        local entry = GearRackUI.SetsList and GearRackUI.SetsList[FauxScrollFrame_GetOffset(GearRackUI_Sets_SavedScrollFrame)+row:GetID()]
        return entry and entry.Name
    end
    for i=1,8 do drag(_G["GearRackUI_Sets_Saved"..i],saved) end
    for i=1,11 do drag(_G["GearRackUI_Sets_Compact"..i],saved) end
end

-- Flyout buttons are made on demand; only the Sets flyout drags.
function GearRack.AddSetMacroHandle(button)
    drag(button,function(self)
        local item = GearRackUI.InvOpen==20 and GearRackUI.BaggedItems[self:GetID()]
        return item and item.name
    end)
end
