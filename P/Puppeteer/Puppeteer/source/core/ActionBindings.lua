PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
local util = PTUtil
local colorize = util.Colorize


ActionBinds = {}
ActionBindsMap = {}
ActionBindNames = {}

function RegisterActionBind(bindTable)
    table.insert(ActionBinds, bindTable)
    ActionBindsMap[bindTable.Name] = bindTable
    table.insert(ActionBindNames, bindTable.Name)
end

RegisterActionBind({
    Name = "Target",
    Description = "Target the unit",
    Script = function(unit, unitFrame)
        TargetUnit(unit)
    end
})
RegisterActionBind({
    Name = "Assist",
    Description = "Target the unit's target",
    Script = function(unit, unitFrame)
        AssistUnit(unit)
    end
})
RegisterActionBind({
    Name = "Follow",
    Description = "Follow the unit",
    Script = function(unit, unitFrame)
        FollowUnit(unit)
    end
})
RegisterActionBind({
    Name = "Menu",
    Description = "Opens the context menu for the unit, if applicable",
    Script = function(unit, unitFrame)
        -- Resolve focus to a proper unit if possible
        if AllCustomUnitsSet[unit] then
            unit = PTUnitProxy.ResolveCustomUnit(unit)
            if not unit then
                return
            end
        end

        local dropdown

        local specialContexts = {
            ["player"] = _G["PlayerFrameDropDown"],
            ["target"] = _G["TargetFrameDropDown"],
            ["pet"] = _G["PetFrameDropDown"]
        }
        if specialContexts[unit] then
            dropdown = specialContexts[unit]
        elseif util.StartsWith(unit, "raid") and not util.StartsWith(unit, "raidpet") then
            FriendsDropDown.displayMode = "MENU"
            FriendsDropDown.initialize = function()
                UnitPopup_ShowMenu(_G[UIDROPDOWNMENU_OPEN_MENU], "PARTY", unit, nil, string.sub(unit, 5))
            end
            dropdown = FriendsDropDown
        elseif util.StartsWith(unit, "party") and not util.StartsWith(unit, "partypet") then
            dropdown = _G["PartyMemberFrame"..string.sub(unit, 6).."DropDown"]
        end


        if dropdown then
            local frame = unitFrame:GetRootContainer()
            ToggleDropDownMenu(1, nil, dropdown, frame:GetName(), frame:GetWidth(), 0)
        end
    end
})
RegisterActionBind({
    Name = "Role",
    Description = "Open a menu to assign a player's role",
    Script = function(unit, unitFrame)
        if not UnitIsPlayer(unit) then
            return
        end
        RoleAssignInfo.Name = UnitName(unit)
        RoleAssignInfo.Class = util.GetClass(unit)
        RoleAssignInfo.ClassColor = util.GetClassColor(util.GetClass(unit), true)
        RoleAssignInfo.FrameGroup = unitFrame.owningGroup
        local frame = unitFrame:GetRootContainer()
        RoleDropdown:SetToggleState(false)
        RoleDropdown:SetToggleState(true, frame, frame:GetWidth(), frame:GetHeight())
        RoleDropdown:SetKeepOpen(true)
        PlaySound("igMainMenuOpen")
    end
})
RegisterActionBind({
    Name = "Role: Tank",
    Description = "Set the player's role as Tank",
    Script = function(unit, unitFrame)
        SetUnitRoleAndUpdate(unit, "Tank")
    end
})
RegisterActionBind({
    Name = "Role: Healer",
    Description = "Set the player's role as Healer",
    Script = function(unit, unitFrame)
        SetUnitRoleAndUpdate(unit, "Healer")
    end
})
RegisterActionBind({
    Name = "Role: Damage",
    Description = "Set the player's role as Damage",
    Script = function(unit, unitFrame)
        SetUnitRoleAndUpdate(unit, "Damage")
    end
})
RegisterActionBind({
    Name = "Role: None",
    Description = "Remove the player's role",
    Script = function(unit, unitFrame)
        SetUnitRoleAndUpdate(unit, nil)
    end
})
RegisterActionBind({
    Name = "Focus",
    Description = "Add/remove a unit to your Focus frames",
    Script = function(unit, unitFrame)
        if not util.IsSuperWowPresent() then
            DEFAULT_CHAT_FRAME:AddMessage(colorize("You need SuperWoW to focus targets.", 1, 0.5, 0.5))
            return
        end

        ToggleFocusUnit(unit)
    end
})
RegisterActionBind({
    Name = "Promote Focus",
    Description = "Move a focus to the top",
    Script = function(unit, unitFrame)
        if not util.IsSuperWowPresent() then
            DEFAULT_CHAT_FRAME:AddMessage(colorize("You need SuperWoW to focus targets.", 1, 0.5, 0.5))
            return
        end

        PromoteFocus(unit)
    end
})
--[[
RegisterActionBind({
    Name = "Demote Focus",
    Description = "Move a focus to the bottom",
    Script = function(unit, unitFrame)
        if not util.IsSuperWowPresent() then
            DEFAULT_CHAT_FRAME:AddMessage(colorize("You need SuperWoW to focus targets.", 1, 0.5, 0.5))
            return
        end
        -- TODO: Logic flawed
        local guid = PTGuidRoster.GetUnitGuid(unit)

        PT_UnfocusUnit(unit)
        PT_FocusUnit(guid)
    end
})
]]