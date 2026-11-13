local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local hooksecurefunc = ShaguTweaks.hooksecurefunc
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
    title = T["Range Color"],
    description = T["Action buttons will be colored red when out of range."],
    expansions = { ["vanilla"] = true },
    category = T["Action Bar"],
    enabled = nil,
})

-- Modern APIs return booleans; legacy range APIs return 1/0/nil.
-- In Lua, numeric zero is truthy, so normalize both contracts explicitly.
local function NormalizeRange(value)
    if value == true or value == 1 then return 1 end
    if value == false or value == 0 then return 0 end
end

local function GetActionRange(action)
    if not UnitExists("target") then return nil end

    if API and API.GetActionInfo then
        local actionType, id = API.GetActionInfo(action)
        if actionType == "spell" and id and API.spellrange
            and API.IsSpellInRange then
            -- ClassicAPI's check is geometric: it does not reject the wrong
            -- faction. A friendly buff should not turn red against an enemy.
            local spells = _G.C_Spell
            if spells then
                if type(spells.IsSpellHelpful) == "function"
                    and spells.IsSpellHelpful(id) and type(UnitCanAssist) == "function"
                    and not UnitCanAssist("player", "target") then return nil end
                if type(spells.IsSpellHarmful) == "function"
                    and spells.IsSpellHarmful(id) and type(UnitCanAttack) == "function"
                    and not UnitCanAttack("player", "target") then return nil end
            end
            -- nil is authoritative: self/rangeless spells have no range to
            -- fail. Never turn it into an old action-slot false result.
            return NormalizeRange(API.IsSpellInRange(id, "target"))
        elseif actionType == "item" and id and API.itemrange
            and API.IsItemInRange then
            return NormalizeRange(API.IsItemInRange(id, "target"))
        end
    end

    -- Macros, unresolved actions and clients without the native capability
    -- retain the action-slot compatibility fallback.
    return NormalizeRange(IsActionInRange(action))
end

local RANGE_INTERVAL = TOOLTIP_UPDATE_TIME or 0.2

-- Newer ClassicAPI owns the range sampling; Lua reacts only to slot changes.
local function EnableNativeRange()
    local actionbar = _G.C_ActionBar
    if not actionbar or type(actionbar.EnableActionRangeCheck) ~= "function"
        or not API.eventutils or not _G.C_EventUtils.IsEventValid("ACTION_RANGE_CHECK_UPDATE") then return false end
    local states, byButton, ranges = {}, {}, {}
    local function Paint(state)
        local button = state.button
        local slot = state.slot
        if not slot then return end
        local icon = state.icon
        if not icon then return end
        local result = ranges[slot]
        -- Keep invalid-faction spells neutral, as the old module did.
        local kind, id = API.GetActionInfo(slot)
        local spells = _G.C_Spell
        if result == 0 and kind == "spell" and spells then
            if (spells.IsSpellHelpful and spells.IsSpellHelpful(id) and not UnitCanAssist("player", "target"))
                or (spells.IsSpellHarmful and spells.IsSpellHarmful(id) and not UnitCanAttack("player", "target")) then result = nil end
        end
        if result == 0 then
            icon:SetVertexColor(button.r or .85, button.g or .18, button.b or .18, button.a or 1)
        else
            local usable, noMana = IsUsableAction(slot)
            if usable and usable ~= 0 then icon:SetVertexColor(1, 1, 1, 1)
            elseif noMana and noMana ~= 0 then icon:SetVertexColor(.5, .5, 1, 1)
            else icon:SetVertexColor(.4, .4, .4, 1) end
        end
    end
    local function Sync(state)
        local slot = state.button:IsVisible() and ActionButton_GetPagedID(state.button) or nil
        if slot and (slot < 1 or slot > 120) then slot = nil end
        if slot ~= state.slot then
            local old = state.slot
            state.slot = slot
            if old then actionbar.EnableActionRangeCheck(old, false) end
            if slot then
                ranges[slot] = nil
                actionbar.EnableActionRangeCheck(slot, true)
            end
        end
        Paint(state)
    end
    local function ButtonChanged()
        local state = byButton[this]
        if state then Sync(state) end
    end
    local function AllChanged()
        for _, state in ipairs(states) do Sync(state) end
    end
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("ACTION_RANGE_CHECK_UPDATE")
    listener:RegisterEvent("PLAYER_ENTERING_WORLD")
    listener:RegisterEvent("PLAYER_TARGET_CHANGED")
    listener:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    listener:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    listener:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    listener:SetScript("OnEvent", function()
        if event == "ACTION_RANGE_CHECK_UPDATE" then
            ranges[arg1] = arg3 and NormalizeRange(arg2) or nil
            for _, state in ipairs(states) do if state.slot == arg1 then Paint(state) end end
        else
            -- Unchanged native results do not fire again: retain their cached state.
            AllChanged()
        end
    end)
    for _, prefix in ipairs({"ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton", "MultiBarLeftButton", "MultiBarRightButton"}) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then
                local state = {button = button, icon = _G[prefix .. i .. "Icon"]}
                byButton[button] = state
                table.insert(states, state)
                ShaguTweaks.HookScript(button, "OnShow", ButtonChanged)
                ShaguTweaks.HookScript(button, "OnHide", ButtonChanged)
            end
        end
    end
    hooksecurefunc("ActionButton_Update", ButtonChanged)
    hooksecurefunc("ActionButton_UpdateUsable", ButtonChanged)
    AllChanged()
    return true
end

module.enable = function(self)
    if EnableNativeRange() then return end
    hooksecurefunc("ActionButton_OnUpdate", function(elapsed)
        -- Blizzard sets rangeTimer only for actions that have a range. Use our
        -- own countdown instead of sharing it: decrementing rangeTimer here and
        -- testing "<= 0.2" ran this check on every frame for every ranged
        -- button, and kept Blizzard's own range check from ever firing.
        if this.rangeTimer then
            local timer = (this.shaguRangeTimer or 0) - (elapsed or 0)
            if timer > 0 then
                this.shaguRangeTimer = timer
            else
                this.shaguRangeTimer = RANGE_INTERVAL
                local action = ActionButton_GetPagedID(this)
                local inRange = GetActionRange(action)
                -- Look the icon up once instead of building its name each time.
                local icon = this.shaguRangeIcon
                if not icon then
                    icon = _G[this:GetName() .. "Icon"]
                    this.shaguRangeIcon = icon
                end

                if icon then
                    if inRange == 0 then
                        if not this.a then
                            this.r, this.g, this.b, this.a = 0.85, 0.18, 0.18, 1
                        end
                        icon:SetVertexColor(this.r, this.g, this.b, this.a)
                    else
                        -- Restore the normal usability tint even if the old
                        -- red action is now unusable or short of mana.
                        local usable, noMana = IsUsableAction(action)
                        if usable and usable ~= 0 then
                            icon:SetVertexColor(1, 1, 1, 1)
                        elseif noMana and noMana ~= 0 then
                            icon:SetVertexColor(0.5, 0.5, 1, 1)
                        else
                            icon:SetVertexColor(0.4, 0.4, 0.4, 1)
                        end
                    end
                end
            end
        end
    end, true)
end
