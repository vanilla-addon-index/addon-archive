-------------------------------------------------------------------------------
-- RelationshipsDashboard - Character Stats, GearScore & Repair Cost for Turtle WoW / OctoWoW
-- Compatible with WoW 1.12.1 (Interface 11200) / Lua 5.0
-------------------------------------------------------------------------------

-- Constants
local RELATIONSHIPS_DASHBOARD_VERSION = "1.0.0";

-- Current unit being displayed. Defaults to "player"; switched to "target"
-- when the InspectFrame opens on another player.
RD_UNIT = "player";

-- Equipment slot IDs (vanilla 1.12)
local EQUIPMENT_SLOTS = {
    1,   -- HeadSlot
    2,   -- NeckSlot
    3,   -- ShoulderSlot
    5,   -- ChestSlot
    6,   -- WaistSlot
    7,   -- LegsSlot
    8,   -- FeetSlot
    9,   -- WristSlot
    10,  -- HandsSlot
    11,  -- Finger0Slot
    12,  -- Finger1Slot
    13,  -- Trinket0Slot
    14,  -- Trinket1Slot
    15,  -- BackSlot
    16,  -- MainHandSlot
    17,  -- OffHandSlot
    18,  -- RangedSlot
};

-- Slot names for display
local SLOT_NAMES = {
    [1]  = "Head",
    [2]  = "Neck",
    [3]  = "Shoulder",
    [5]  = "Chest",
    [6]  = "Waist",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [11] = "Ring 1",
    [12] = "Ring 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
    [18] = "Ranged",
};

-- Note: The GearScore formula (rarity * itemLevel) does not use slot weights or quality multipliers.
-- These constants are kept for potential future use in advanced scoring modes.
-- Current GearScore formula: score = rarity * itemLevel * (twoHand ? 2 : 1)

-- Resistance indices in vanilla WoW
-- 1=Holy, 2=Fire, 3=Nature, 4=Frost, 5=Shadow, 6=Arcane
local RESISTANCE_INDICES = {
    arcane = 6,
    fire   = 2,
    nature = 3,
    frost  = 4,
    shadow = 5,
};

-- School indices for spell crit/hit (vanilla 1.12)
-- 1=Physical, 2=Holy, 3=Fire, 4=Nature, 5=Frost, 6=Shadow, 7=Arcane
local SPELL_SCHOOL_INDEX = 6; -- Use Arcane as representative for generic spell stats

-- Tooltip scanner for item info
local RelationshipsDashboardTooltip = nil;

-------------------------------------------------------------------------------
-- Durability persistence system: Tracks durability loss from deaths, combat
-- hits, and repair events. When GetInventoryItemDurability() fails (which is
-- common on Turtle WoW / OctoWoW outside repair NPCs), we use these stored
-- estimates as a fallback so the dashboard always shows meaningful values.
--
-- How it works:
--   1. On PLAYER_ENTERING_WORLD and after each update, try to read actual
--      durability via GetInventoryItemDurability or tooltip scanning.
--   2. When actual values are available, store them in RD_SavedDurability.
--   3. When a player dies (PLAYER_DEAD), reduce all items' estimated
--      durability by 10% (standard WoW death penalty = 10% of max dur).
--   4. While in combat, increment hit counters. On UNIT_HEALTH damage taken,
--      apply small durability decay proportional to hits received.
--   5. At repair NPCs, use GetRepairAllCost() as exact ground truth.
--   6. When displaying, use actual if available, else use saved estimates.
-------------------------------------------------------------------------------
-- NOTE: RD_SavedDurability is intentionally GLOBAL (no `local`) so that it
-- can be persisted through the SavedVariable RelationshipsDashboardDB_SavedDurability
-- across /reload and sessions. Rebound in OnLoad after saved vars load.
RD_SavedDurability = {};  -- [slotId] = { cur = X, max = Y }
local RD_InCombat = false;
local RD_CombatHitCount = 0;
local RD_LastHealth = 0;
local RD_InBattleground = false;  -- True while in a BG (no durability loss in BGs)
local RD_InDuel = false;          -- True during a duel (no durability loss in duels)

-- Track ghost state so we can detect spirit-healer resurrection
-- (25% durability loss to all equipped + inventory items).
RD_WasGhost = false;
RD_PendingSpiritRez = false;
RD_LastMoney = 0;  -- Track for detecting non-merchant repair (e.g. guild bank repair)
-- True while a repair-CAPABLE merchant window is open. Used to decide when a
-- durability reading of "full" can be trusted (see CalculateDurabilityAndRepair).
RD_AtRepairMerchant = false;
-- Per-character multiplier that scales our away-from-merchant repair estimate so
-- it matches the exact cost the game charges. Learned automatically the first
-- time the player opens a repair merchant with damaged gear. Persisted in
-- RelationshipsDashboardDB.repairCalibration.
RD_RepairCalibration = 1.0;
local RD_REPAIR_CALIBRATION_VERSION = 2;

-- Battleground zone names for vanilla WoW 1.12 (English only — these match GetRealZoneText())
local RD_BATTLEGROUND_ZONES = {
    -- Blizzard vanilla battlegrounds
    ["Alterac Valley"] = true,
    ["Warsong Gulch"] = true,
    ["Arathi Basin"] = true,
    -- Turtle WoW / OctoWoW custom or renamed battlegrounds
    ["Gurubashi Arena"] = true,
    ["Silithus"] = false, -- world PvP zone, NOT a real BG; do not skip durability here
    ["Warsong Battleground"] = true,
    ["Sunnyglade Valley"] = true,     -- Turtle WoW custom BG
    ["Blackrock Depths (Arena)"] = true,
    ["Lower Blackrock Spire"] = false, -- not a BG (guard against false positives)
};

-- Extra localized BG names Turtle/OctoWoW clients ship with. Kept separate
-- so the vanilla table above stays authoritative; both are consulted.
local RD_BATTLEGROUND_ZONES_EXTRA = {
    -- German
    ["Alteractal"] = true,
    ["Kriegshymnenschlucht"] = true,
    ["Arathibecken"] = true,
    -- French
    ["Vallee d'Alterac"] = true,
    ["Vall\195\169e d'Alterac"] = true,
    ["Goulet des Chanteguerres"] = true,
    ["Bassin d'Arathi"] = true,
    -- Spanish / Portuguese
    ["Valle de Alterac"] = true,
    ["Garganta Grito de Guerra"] = true,
    ["Cuenca de Arathi"] = true,
    -- Russian
    [chr and chr(1040) or "\208\144"] = false, -- placeholder, real names below
    ["\208\144\208\187\209\140\209\130\208\181\209\128\208\176\208\186\209\129\208\186\208\176\209\143 \208\180\208\190\208\187\208\184\208\189\208\176"] = true,
};

-- Slots that can have durability (armor + weapons, NOT accessories)
local RD_DURABILITY_SLOTS = {
    [1]  = true,   -- HeadSlot
    [3]  = true,   -- ShoulderSlot
    [5]  = true,   -- ChestSlot
    [7]  = true,   -- LegsSlot
    [8]  = true,   -- FeetSlot
    [9]  = true,   -- WristSlot
    [10] = true,   -- HandsSlot
    [15] = true,   -- BackSlot (some cloaks have durability)
    [16] = true,   -- MainHandSlot
    [17] = true,   -- OffHandSlot
    [18] = true,   -- RangedSlot
};

-- Default max durability for items when we can't read it
-- Vanilla WoW items typically have 35-165 max durability based on slot
local RD_DEFAULT_MAX_DURABILITY = {
    [1]  = 85,   -- HeadSlot
    [3]  = 85,   -- ShoulderSlot
    [5]  = 135,  -- ChestSlot
    [7]  = 105,  -- LegsSlot
    [8]  = 85,   -- FeetSlot
    [9]  = 55,   -- WristSlot
    [10] = 85,   -- HandsSlot
    [15] = 55,   -- BackSlot
    [16] = 105,  -- MainHandSlot
    [17] = 105,  -- OffHandSlot
    [18] = 85,   -- RangedSlot
};

-- Helper: Reset tooltip for fresh scan
-- In vanilla 1.12, tooltips can get "stuck" with stale data
-- Always call this before SetInventoryItem or SetHyperlink
local function RelationshipsDashboard_ResetTooltip()
    if RelationshipsDashboardTooltip then
        RelationshipsDashboardTooltip:SetOwner(WorldFrame, "ANCHOR_NONE");
        RelationshipsDashboardTooltip:ClearLines();
    end
end

-- Player class cached on login
local RelationshipsDashboard_PlayerClass = nil;

-------------------------------------------------------------------------------
-- Helper: Check if the player is currently in a battleground
-- In vanilla WoW 1.12, players do NOT take durability loss from death or
-- combat while in a battleground. We check using zone name and also
-- MiniMapBattlefieldFrame visibility as a fallback.
-------------------------------------------------------------------------------
local function RelationshipsDashboard_IsInBattleground()
    -- Method 1: Zone name check (English + a few localized variants)
    local zone = GetRealZoneText and GetRealZoneText() or nil;
    if zone and (RD_BATTLEGROUND_ZONES[zone] or RD_BATTLEGROUND_ZONES_EXTRA[zone]) then
        return true;
    end
    local subZone = GetSubZoneText and GetSubZoneText() or nil;
    if subZone and (RD_BATTLEGROUND_ZONES[subZone] or RD_BATTLEGROUND_ZONES_EXTRA[subZone]) then
        return true;
    end
    -- Method 2: PvP zone info reports "combat" for active battlefields
    if GetZonePVPInfo then
        local pvpType = GetZonePVPInfo();
        if pvpType == "combat" then
            return true;
        end
    end
    -- Method 3: Ask the battlefield queue system directly. In 1.12 there are
    -- up to MAX_BATTLEFIELD_QUEUES (3) slots. A status of "active" means the
    -- player is currently inside that battleground. This is the most reliable
    -- signal on Turtle WoW / OctoWoW even when zone strings do not match.
    if GetBattlefieldStatus then
        local maxQueues = MAX_BATTLEFIELD_QUEUES or 3;
        for i = 1, maxQueues do
            local status = GetBattlefieldStatus(i);
            if status == "active" then
                return true;
            end
        end
    end
    -- Method 4: MiniMapBattlefieldFrame is shown when inside a BG (fallback)
    if MiniMapBattlefieldFrame and MiniMapBattlefieldFrame:IsVisible() then
        local status = MiniMapBattlefieldFrame.status;
        if status == "active" then
            return true;
        end
    end
    return false;
end

-- Snapshot of equipped durability captured on BG entry so we can restore
-- exactly if any event mutates our tracker mid-BG (deaths, spirit rez, etc).
RD_BG_DurabilitySnapshot = nil;

local function RelationshipsDashboard_SnapshotDurabilityForBG()
    RD_BG_DurabilitySnapshot = {};
    for slotId, _ in pairs(RD_DURABILITY_SLOTS) do
        local saved = RD_SavedDurability and RD_SavedDurability[slotId];
        if saved and saved.max then
            RD_BG_DurabilitySnapshot[slotId] = { cur = saved.cur, max = saved.max };
        end
    end
end

local function RelationshipsDashboard_RestoreDurabilityFromBGSnapshot()
    if not RD_BG_DurabilitySnapshot then return; end
    for slotId, snap in pairs(RD_BG_DurabilitySnapshot) do
        local saved = RD_SavedDurability and RD_SavedDurability[slotId];
        if saved then
            saved.cur = snap.cur;
            saved.max = snap.max;
        end
    end
end
-- Tracked mana values for when druid shifts to feral forms
-- In vanilla 1.12, UnitMana(RD_UNIT) returns the current form's power only
-- We store the caster-form mana to display it alongside Energy/Rage
local RelationshipsDashboard_LastKnownMana = 0;
local RelationshipsDashboard_LastKnownMaxMana = 0;

-------------------------------------------------------------------------------
-- Helper: Check if player's class uses mana (has a mana pool regardless of form)
-- This is class-based, not form-based, so druids in feral forms still return true
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetUnitClass()
    -- Get class for RD_UNIT (defaults to "player", switches to "target" during inspect)
    local _, class = UnitClass(RD_UNIT);
    if not class or class == "" then
        if RD_UNIT == "player" then
            if not RelationshipsDashboard_PlayerClass then
                _, RelationshipsDashboard_PlayerClass = UnitClass("player");
            end
            class = RelationshipsDashboard_PlayerClass;
        end
    end
    -- Cache player class when we can
    if RD_UNIT == "player" and class and class ~= "" then
        RelationshipsDashboard_PlayerClass = class;
    end
    return class;
end

local function RelationshipsDashboard_ClassUsesMana()
    local class = RelationshipsDashboard_GetUnitClass();
    return class == "MAGE"
        or class == "WARLOCK"
        or class == "PRIEST"
        or class == "DRUID"
        or class == "SHAMAN"
        or class == "PALADIN"
        or class == "HUNTER";
end

-------------------------------------------------------------------------------
-- Helper: Check if unit is currently displaying mana (powerType == 0)
-------------------------------------------------------------------------------
local function RelationshipsDashboard_IsManaUser()
    local powerType = UnitPowerType(RD_UNIT);
    return powerType == 0;
end

-------------------------------------------------------------------------------
-- Helper: Check if unit uses spell power (caster class)
-------------------------------------------------------------------------------
local function RelationshipsDashboard_IsCaster()
    local class = RelationshipsDashboard_GetUnitClass();
    return class == "MAGE"
        or class == "WARLOCK"
        or class == "PRIEST"
        or class == "DRUID"
        or class == "SHAMAN"
        or class == "PALADIN";
end

-------------------------------------------------------------------------------
-- Helper: Check if unit uses ranged weapons (Hunter primarily)
-------------------------------------------------------------------------------
local function RelationshipsDashboard_HasRanged()
    local class = RelationshipsDashboard_GetUnitClass();
    return class == "HUNTER"
        or class == "WARRIOR"
        or class == "ROGUE";
end

-------------------------------------------------------------------------------
-- Dynamic layout system: Re-anchors all visible rows sequentially after
-- class visibility is applied. This eliminates gaps from hidden rows
-- (e.g., hidden Ranged stats in Enhancements, hidden Block in Defenses).
--
-- Layout order definition:
--   Each section = { headerName, { row1, row2, ... } }
--   Rows are re-anchored TOPLEFT to the previous visible element's BOTTOMLEFT.
--   Section headers get a -4 spacing gap from the previous row.
-------------------------------------------------------------------------------
local RelationshipsDashboard_LayoutSections = {
    { "", {
        "RelationshipsDashboardGearScoreRow",
        "RelationshipsDashboardAvgILvlRow",
    }},
    { "RDHeaderGeneral", {
        "RelationshipsDashboardHealthRow",
        "RelationshipsDashboardPowerRow",
        "RelationshipsDashboardManaRow",
        "RelationshipsDashboardArmorRow",
        "RelationshipsDashboardMovementRow",
        "RelationshipsDashboardDurabilityRow",
        "RelationshipsDashboardRepairCostRow",
    }},
    { "RDHeaderAttributes", {
        "RelationshipsDashboardStrengthRow",
        "RelationshipsDashboardAgilityRow",
        "RelationshipsDashboardStaminaRow",
        "RelationshipsDashboardIntellectRow",
        "RelationshipsDashboardSpiritRow",
    }},
    { "RDHeaderOffense", {
        "RelationshipsDashboardMeleeDmgRow",
        "RelationshipsDashboardMeleeAPRow",
        "RelationshipsDashboardMeleeSpeedRow",
        "RelationshipsDashboardWeaponDPSRow",
        "RelationshipsDashboardWeaponSkillRow",
        "RelationshipsDashboardMeleeHitRow",
        "RelationshipsDashboardMeleeCritRow",
    }},
    { "RDHeaderEnhancements", {
        "RelationshipsDashboardRangedAPRow",
        "RelationshipsDashboardRangedCritRow",
        "RelationshipsDashboardRangedSpeedRow",
        "RelationshipsDashboardRangedDmgRow",
        "RelationshipsDashboardSpellPowerRow",
        "RelationshipsDashboardHealingPowerRow",
        "RelationshipsDashboardSpellHitRow",
        "RelationshipsDashboardSpellCritRow",
        "RelationshipsDashboardManaRegenRow",
    }},
    { "RDHeaderDefenses", {
        "RelationshipsDashboardDefenseRow",
        "RelationshipsDashboardDodgeRow",
        "RelationshipsDashboardParryRow",
        "RelationshipsDashboardBlockRow",
        "RelationshipsDashboardAvoidanceRow",
    }},
    { "RDHeaderResistances", {
        "RelationshipsDashboardArcaneResRow",
        "RelationshipsDashboardFireResRow",
        "RelationshipsDashboardNatureResRow",
        "RelationshipsDashboardFrostResRow",
        "RelationshipsDashboardShadowResRow",
    }},
};

-------------------------------------------------------------------------------
-- Helper: iterate every frame that lives inside the scrollable stat content.
-- Vanilla 1.12 ScrollFrames do not clip nested child Frames reliably, so these
-- frames need explicit level management and viewport culling.
-------------------------------------------------------------------------------
local function RelationshipsDashboard_ForEachScrollElement(callback)
    for secIdx = 1, table.getn(RelationshipsDashboard_LayoutSections) do
        local section = RelationshipsDashboard_LayoutSections[secIdx];
        local headerName = section[1];
        local rowNames = section[2];

        if headerName and headerName ~= "" then
            local header = getglobal(headerName);
            if header then
                callback(header);
            end
        end

        for rowIdx = 1, table.getn(rowNames) do
            local row = getglobal(rowNames[rowIdx]);
            if row then
                callback(row);
            end
        end
    end
end

local function RelationshipsDashboard_SetLayoutShown(element, shown)
    if not element then return; end

    -- rdLayoutShown is the real layout intent. Do NOT infer layout from
    -- IsShown(), because viewport clipping also uses Hide()/Show() and can
    -- temporarily hide otherwise-valid rows while they are scrolled out.
    element.rdLayoutShown = shown;
    element.rdIntendedShown = shown;

    if shown then
        if not element:IsShown() then element:Show(); end
    else
        if element:IsShown() then element:Hide(); end
    end
end

-------------------------------------------------------------------------------
-- Hard clip workaround for Vanilla/Turtle clients.
-- The ScrollFrame viewport clips the ScrollChild's own regions, but child Frames
-- inside that ScrollChild can still draw outside the viewport. We hide any row
-- or header that is not fully inside the scroll viewport, preventing text from
-- drawing above the title bar or below the panel.
-------------------------------------------------------------------------------
function RelationshipsDashboard_UpdateViewportClip()
    if not RelationshipsDashboardScrollFrame then return; end

    local viewTop = RelationshipsDashboardScrollFrame:GetTop();
    local viewBottom = RelationshipsDashboardScrollFrame:GetBottom();
    if not viewTop or not viewBottom then return; end

    -- Vanilla/Turtle 1.12: SetAlpha(0) does NOT cascade to child FontStrings
    -- inside a Frame, so alpha-clipping leaves overlapping labels visible when
    -- rows scroll out of the viewport. We must Hide()/Show() the actual row
    -- frames instead. To avoid re-showing rows that ApplyClassVisibility
    -- intentionally hid (e.g. Ranged stats for casters), we consult the
    -- `rdIntendedShown` flag set at the end of ApplyClassVisibility.
    RelationshipsDashboard_ForEachScrollElement(function(element)
        -- Never override an intentional class-based hide.
        if element.rdIntendedShown == false then
            if element:IsShown() then element:Hide(); end
            return;
        end

        local elemTop = element:GetTop();
        local elemBottom = element:GetBottom();
        local inView = elemTop and elemBottom
            and elemTop <= (viewTop + 0.5)
            and elemBottom >= (viewBottom - 0.5);

        if inView then
            if not element:IsShown() then element:Show(); end
            element:SetAlpha(1);
        else
            if element:IsShown() then element:Hide(); end
        end
    end);
end

-------------------------------------------------------------------------------
-- Show/Hide stats based on class role, then re-anchor all visible rows
-- so hidden rows don't leave gaps in the layout.
-------------------------------------------------------------------------------
local function RelationshipsDashboard_ApplyClassVisibility()
    local class = RelationshipsDashboard_GetUnitClass();
    local isCaster = RelationshipsDashboard_IsCaster();
    local hasRanged = RelationshipsDashboard_HasRanged();
    local isManaUser = RelationshipsDashboard_IsManaUser();
    local classUsesMana = RelationshipsDashboard_ClassUsesMana();

    -- Reset every header/row to its normal layout state before applying
    -- class-specific hides. This deliberately undoes viewport clipping hides;
    -- clipping is re-applied after the rows are re-anchored below.
    RelationshipsDashboard_ForEachScrollElement(function(element)
        RelationshipsDashboard_SetLayoutShown(element, true);
    end);

    -- ManaRow: Show for classes that have a mana pool, but only when
    -- the current power type is NOT mana (druid in feral form shows
    -- Energy/Rage on PowerRow + Mana on separate ManaRow).
    -- When already showing mana on PowerRow, hide the duplicate ManaRow.
    if classUsesMana and not isManaUser then
        -- Class has mana but current form shows different power (e.g., druid bear/cat)
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardManaRow, true);
    else
        -- Either already showing mana on PowerRow, or class doesn't use mana at all
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardManaRow, false);
    end

    -- Ranged stats: show for Hunter/Warrior/Rogue, hide for others
    if hasRanged then
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardRangedAPRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardRangedCritRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardRangedSpeedRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardRangedDmgRow, true);
    else
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardRangedAPRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardRangedCritRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardRangedSpeedRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardRangedDmgRow, false);
    end

    -- Spell stats: show for mana users/casters, hide for pure melee
    if isCaster or classUsesMana then
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardSpellPowerRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardHealingPowerRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardSpellHitRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardSpellCritRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardManaRegenRow, true);
    else
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardSpellPowerRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardHealingPowerRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardSpellHitRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardSpellCritRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardManaRegenRow, false);
    end

    -- Melee stats: hide for pure casters (Mage, Warlock, Priest)
    if class == "MAGE" or class == "WARLOCK" or class == "PRIEST" then
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardMeleeDmgRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardMeleeAPRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardMeleeSpeedRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardWeaponDPSRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardWeaponSkillRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardMeleeHitRow, false);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardMeleeCritRow, false);
    else
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardMeleeDmgRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardMeleeAPRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardMeleeSpeedRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardWeaponDPSRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardWeaponSkillRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardMeleeHitRow, true);
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardMeleeCritRow, true);
    end

    -- Block: only show for Warrior/Paladin/Shaman (classes that can use shields)
    if class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN" then
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardBlockRow, true);
    else
        RelationshipsDashboard_SetLayoutShown(RelationshipsDashboardBlockRow, false);
    end

    -- ==== Dynamic re-anchoring: eliminate gaps from hidden rows ====
    -- Walk through all sections and rows, re-anchor each visible element
    -- to the bottom of the previous visible element.
    local prevElement = nil;  -- last visible frame we anchored to
    local stripeOn = false;   -- alternating row stripe state

    for secIdx = 1, table.getn(RelationshipsDashboard_LayoutSections) do
        local section = RelationshipsDashboard_LayoutSections[secIdx];
        local headerName = section[1];
        local rowNames = section[2];
        local header = getglobal(headerName);

        -- Count visible rows in this section BEFORE deciding whether to show its header.
        -- Without this, class-hidden sections still render a title bar that visually
        -- collides with rows from adjacent sections after re-anchoring.
        local sectionHasVisibleRow = false;
        for rowIdx = 1, table.getn(rowNames) do
            local r = getglobal(rowNames[rowIdx]);
            if r and r.rdLayoutShown ~= false then
                sectionHasVisibleRow = true;
                break;
            end
        end

        if header and sectionHasVisibleRow then
            if prevElement then
                -- Section header: anchor below previous visible element with gap
                header:ClearAllPoints();
                header:SetPoint("TOPLEFT", prevElement, "BOTTOMLEFT", 0, -4);
            else
                -- First section: anchor to content top
                header:ClearAllPoints();
                header:SetPoint("TOPLEFT", RelationshipsDashboardContent, "TOPLEFT", 0, 0);
            end
            RelationshipsDashboard_SetLayoutShown(header, true);
            prevElement = header;
        elseif header then
            -- Every row in this section is class-hidden — hide the title too.
            RelationshipsDashboard_SetLayoutShown(header, false);
        end

        for rowIdx = 1, table.getn(rowNames) do
            local rowName = rowNames[rowIdx];
            local row = getglobal(rowName);
            if row and row.rdLayoutShown ~= false then
                row:ClearAllPoints();
                if prevElement then
                    row:SetPoint("TOPLEFT", prevElement, "BOTTOMLEFT", 0, 0);
                else
                    -- No previous element (first row, no section header): anchor to content top
                    row:SetPoint("TOPLEFT", RelationshipsDashboardContent, "TOPLEFT", 0, 0);
                end
                prevElement = row;

                -- Apply alternating row stripes
                local bg = getglobal(rowName .. "BG");
                if bg then
                    if stripeOn then
                        bg:Show();
                        bg:SetAlpha(0.04);
                        row.stripeOn = true;
                    else
                        bg:Hide();
                        row.stripeOn = false;
                    end
                end
                stripeOn = not stripeOn;
            end
        end
    end

    -- Update scroll child height based on last visible element.
    -- IMPORTANT: do NOT clamp tall content down to the visible viewport. If the
    -- ScrollChild is shorter than the actual rows, Vanilla lets nested row Frames
    -- bleed outside the frame while the ScrollFrame has the wrong scroll range.
    if prevElement then
        local scrollFrame = RelationshipsDashboardScrollFrame;
        local scrollVisibleHeight = scrollFrame:GetHeight() or 400;
        local contentTop = RelationshipsDashboardContent:GetTop() or 0;
        local elemBottom = prevElement:GetBottom() or 0;
        local usedHeight = math.ceil(contentTop - elemBottom) + 10;
        if usedHeight < 100 then
            usedHeight = 100;
        end
        if usedHeight < scrollVisibleHeight then
            usedHeight = scrollVisibleHeight;
        end
        RelationshipsDashboardContent:SetHeight(usedHeight);

        if scrollFrame.UpdateScrollChildRect then
            scrollFrame:UpdateScrollChildRect();
        end

        local scrollBar = getglobal("RelationshipsDashboardScrollFrameScrollBar");
        if scrollBar then
            local minVal, maxVal = scrollBar:GetMinMaxValues();
            if scrollBar:GetValue() > maxVal then
                scrollBar:SetValue(maxVal);
            elseif scrollBar:GetValue() < minVal then
                scrollBar:SetValue(minVal);
            end
        end
    end

    -- Snapshot which elements are legitimately shown right now (post class-filter
    -- + relayout). UpdateViewportClip uses this to decide which rows may be
    -- Show()n back into the viewport during scrolling, and which must stay
    -- hidden because a class role rule hid them.
    RelationshipsDashboard_ForEachScrollElement(function(element)
        element.rdIntendedShown = (element.rdLayoutShown ~= false);
    end);

    RelationshipsDashboard_BoostMaskLevels();
    RelationshipsDashboard_UpdateViewportClip();
end

-------------------------------------------------------------------------------
-- Helper: Extract item ID from an item link string
-- Vanilla 1.12 item link format: |cffXXXXXX|Hitem:itemId:enchantId:suffixId:uniqueId|h[Name]|h|r
-- We need to parse out the numeric item ID for database lookup
-------------------------------------------------------------------------------
local function RelationshipsDashboard_ExtractItemID(itemLink)
    if not itemLink then return nil; end
    local _, _, itemID = strfind(itemLink, "item:(%d+):%d+:%d+:%d+");
    if itemID then
        return tonumber(itemID);
    end
    return nil;
end

-------------------------------------------------------------------------------
-- Helper: Safe wrapper for SetInventoryItem that catches errors
-------------------------------------------------------------------------------
local function RelationshipsDashboardTooltip_SetInventoryItemSafe(unit, slot)
    if not RelationshipsDashboardTooltip then return false; end
    local ok, err = pcall(function() RelationshipsDashboardTooltip:SetInventoryItem(unit, slot); end);
    return ok;
end

-------------------------------------------------------------------------------
-- Helper: Format money (copper) to gold/silver/copper string
-------------------------------------------------------------------------------
local function RelationshipsDashboard_FormatMoney(copper)
    if copper <= 0 then
        return "|cff00ff000g 0s 0c|r";
    end
    local gold = floor(copper / 10000);
    local silver = floor(mod(copper, 10000) / 100);
    local copperRem = mod(copper, 100);
    local result = "";
    if gold > 0 then
        result = result .. "|cffffff00" .. gold .. "g|r ";
    end
    if silver > 0 or gold > 0 then
        result = result .. "|cffc0c0c0" .. silver .. "s|r ";
    end
    result = result .. "|cffcc8844" .. copperRem .. "c|r";
    return result;
end

-------------------------------------------------------------------------------
-- Helper: Format percentage
-------------------------------------------------------------------------------
local function RelationshipsDashboard_FormatPercent(value)
    return string.format("%.2f%%", value);
end

-------------------------------------------------------------------------------
-- Helper: Format decimal
-------------------------------------------------------------------------------
local function RelationshipsDashboard_FormatDecimal(value)
    return string.format("%.2f", value);
end

-------------------------------------------------------------------------------
-- Helper: Get item quality from item link
-- Item links in vanilla: |Hitem:itemId:enchantId:suffixId:uniqueId|h[name]|h[qualityCode]
-- Actually in 1.12: |cffXXXXXX|Hitem:itemId:enchant:suffix:unique|h[Name]|h|r
-- The color code maps to quality:
--   |cff9d9d9d = 0 (Poor), |cffffffff = 1 (Common), |cff1eff00 = 2 (Uncommon)
--   |cff0070dd = 3 (Rare), |cffa335ee = 4 (Epic), |cffff8000 = 5 (Legendary)
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetItemQualityFromLink(itemLink)
    if not itemLink then return 0; end
    -- Match the color prefix to determine quality
    local quality = 0;
    if strfind(itemLink, "|cff9d9d9d") then
        quality = 0;
    elseif strfind(itemLink, "|cffffffff") then
        quality = 1;
    elseif strfind(itemLink, "|cff1eff00") then
        quality = 2;
    elseif strfind(itemLink, "|cff0070dd") then
        quality = 3;
    elseif strfind(itemLink, "|cffa335ee") then
        quality = 4;
    elseif strfind(itemLink, "|cffff8000") then
        quality = 5;
    else
        -- Fallback: try to use GetItemQualityColor if we can parse itemId
        -- This shouldn't normally happen
        quality = 1;
    end
    return quality;
end

-------------------------------------------------------------------------------
-- Helper: Get item level using the built-in item database
-- Primary method: Look up itemID in RelationshipsDashboardDB_ItemLevels
-- Fallback method: Try GetItemInfo (works for cached items)
-- Last resort: Tooltip scanning
-- This is the proven approach for vanilla 1.12 where GetItemInfo is unreliable
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetItemLevel(itemLink)
    if not itemLink then return 0; end

    -- Method 1: Extract itemID and look up in our database (most reliable)
    local itemID = RelationshipsDashboard_ExtractItemID(itemLink);
    if itemID and RelationshipsDashboardDB_ItemLevels then
        local dbLevel = RelationshipsDashboardDB_ItemLevels[itemID];
        if dbLevel and dbLevel > 0 then
            return dbLevel;
        end
    end

    -- Method 2: Try GetItemInfo (works for items cached in current session)
    local _, _, _, itemLevel = GetItemInfo(itemLink);
    if itemLevel and itemLevel > 0 then
        return itemLevel;
    end

    -- Method 3: Tooltip scanning as last resort
    if RelationshipsDashboardTooltip then
        RelationshipsDashboard_ResetTooltip();
        local ok, err = pcall(function() RelationshipsDashboardTooltip:SetHyperlink(itemLink); end);
        if ok then
            for i = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        local _, _, iLvl = strfind(text, "Item Level (%d+)");
                        if iLvl then
                            return tonumber(iLvl);
                        end
                    end
                end
            end
        end
    end

    return 0;
end

-------------------------------------------------------------------------------
-- Helper: Check if an item is a two-handed weapon
-- Uses itemEquipLoc from GetItemInfo (equipped items are always cached)
-- INVTYPE_2HWEAPON is the equip location for two-hand weapons
-------------------------------------------------------------------------------
local function RelationshipsDashboard_IsTwoHandWeapon(itemLink)
    if not itemLink then return false; end
    -- Vanilla 1.12 GetItemInfo returns: name(1), link(2), quality(3), iLevel(4),
    -- minLevel(5), type(6), subType(7), stackCount(8), equipLoc(9), texture(10).
    -- The equipLoc is the 9th return, not the 8th.
    local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink);
    if itemEquipLoc == "INVTYPE_2HWEAPON" then
        return true;
    end
    return false;
end

-------------------------------------------------------------------------------
-- Calculate GearScore based on equipped items
-- Formula: score = rarity * itemLevel per item, x2 bonus for two-hand weapons
-- Also calculates average item level from the database
-------------------------------------------------------------------------------
local function RelationshipsDashboard_CalculateGearScore()
    local totalScore = 0;
    local totalILvl = 0;
    local equippedCount = 0;   -- items with a known item level (for avg ilvl)
    local slotCount = 0;       -- items equipped at all

    -- GearScoreLite-style quality scalar (rewards higher rarities much more,
    -- so a low-level player in white/green gear can't out-score a mid-level
    -- character in blue/purple gear like on real WoW).
    local qualityScalar = {
        [0] = 0.00,
        [1] = 0.005,  -- Common (white)
        [2] = 0.25,   -- Uncommon (green)
        [3] = 0.50,   -- Rare (blue)
        [4] = 0.75,   -- Epic (purple)
        [5] = 1.00,   -- Legendary (orange)
    };

    -- Slot weights approximate the TBC / WotLK GearScore standard
    local slotWeight = {
        [1]  = 1.0000, [2]  = 0.5625, [3]  = 0.7500, [5]  = 1.0000,
        [6]  = 0.7500, [7]  = 1.0000, [8]  = 0.7500, [9]  = 0.5625,
        [10] = 0.7500, [11] = 0.5625, [12] = 0.5625, [13] = 0.5625,
        [14] = 0.5625, [15] = 0.5625, [16] = 1.0000, [17] = 1.0000,
        [18] = 0.3164,
    };

    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local itemLink = GetInventoryItemLink(RD_UNIT, slotId);
        if itemLink then
            slotCount = slotCount + 1;
            local itemID = RelationshipsDashboard_ExtractItemID(itemLink);
            local itemLevel = 0;
            if itemID and RelationshipsDashboardDB_ItemLevels then
                itemLevel = RelationshipsDashboardDB_ItemLevels[itemID] or 0;
            end
            if itemLevel == 0 then
                local _, _, _, giItemLevel = GetItemInfo(itemLink);
                if giItemLevel and giItemLevel > 0 then
                    itemLevel = giItemLevel;
                end
            end

            -- Fallback for items missing from the DB and uncached from
            -- GetItemInfo (common on Turtle WoW custom items, ESPECIALLY the
            -- 2H weapon the player just equipped). Approximate from the
            -- wearer's level so the score still reflects the equip/unequip.
            if itemLevel == 0 then
                local plvl = UnitLevel(RD_UNIT) or 1;
                if plvl < 1 then plvl = 1; end
                itemLevel = plvl;
            end

            local quality = RelationshipsDashboard_GetItemQualityFromLink(itemLink);
            local qf = qualityScalar[quality] or 0.005;
            local sw = slotWeight[slotId] or 0.5625;

            -- Discount very low ilvl items (matches retail formula behavior)
            local ilvlBase = itemLevel - 4;
            if ilvlBase < 0 then ilvlBase = 0; end

            -- 9th return of GetItemInfo is equipLoc in vanilla 1.12.
            local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink);
            local twoHandMult = 1;
            if itemEquipLoc == "INVTYPE_2HWEAPON" then
                twoHandMult = 2;
            end

            -- Scale factor tuned so a full T2 (ilvl 76 epic) player lands
            -- around ~2800 GearScore, a full BiS pre-raid ~2000, greens
            -- at level 60 ~800-1000, and level 20 greens ~150.
            local itemScore = ilvlBase * qf * sw * twoHandMult * 8;

            totalScore = totalScore + itemScore;
            totalILvl = totalILvl + itemLevel;
            equippedCount = equippedCount + 1;
        end
    end

    local avgILvl = 0;
    if equippedCount > 0 then
        avgILvl = totalILvl / equippedCount;
    end

    return floor(totalScore), avgILvl, equippedCount;
end

-------------------------------------------------------------------------------
-- Calculate durability and repair costs
-- Primary method: GetInventoryItemDurability (vanilla 1.12 API, works without repair NPC)
-- Fallback: Tooltip scanning for "Durability: XX / XX" pattern
-- Repair cost is estimated from durability ratio, item quality, item level, and slot type
-- When a repair merchant is open, GetRepairAllCost() provides the exact cost
-------------------------------------------------------------------------------

-- Slots that never have durability in vanilla WoW (accessories)
local SLOTS_NO_DURABILITY = {
    [2] = true,   -- NeckSlot
    [11] = true,  -- Finger0Slot
    [12] = true,  -- Finger1Slot
    [13] = true,  -- Trinket0Slot
    [14] = true,  -- Trinket1Slot
};

-- Slot type multipliers for repair cost estimation
-- These represent the relative cost weight of each armor slot
-- Based on vanilla WoW's internal repair cost distribution
local SLOT_REPAIR_MULTIPLIER = {
    [1]  = 0.88,  -- HeadSlot
    [3]  = 0.75,  -- ShoulderSlot
    [5]  = 1.00,  -- ChestSlot (highest)
    [6]  = 0.50,  -- WaistSlot (no durability in vanilla, but just in case)
    [7]  = 0.88,  -- LegsSlot
    [8]  = 0.75,  -- FeetSlot
    [9]  = 0.50,  -- WristSlot
    [10] = 0.75,  -- HandsSlot
    [15] = 0.50,  -- BackSlot (usually no durability, but some cloaks do)
    [16] = 0.38,  -- MainHandSlot
    [17] = 0.38,  -- OffHandSlot
    [18] = 0.38,  -- RangedSlot
};

-- DBC-backed repair multipliers from modern Classic Era DurabilityCosts.dbc.
-- Server formula used by newer cores:
--   repairCopper = lostDurability * DurabilityCosts[itemLevel][class/subclass]
--                  * DurabilityQuality[(quality + 1) * 2]
-- This is much closer to WoW/Turtle/OctoWoW repair totals than a generic
-- ilvl/slot approximation, and it naturally takes the equipped gear type,
-- quality, and item level into account.
local RD_DBC_REPAIR_ARMOR = {
    1,1,1,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,
    5,5,5,6,6,6,7,7,7,8,8,9,9,10,11,12,13,14,15,16,
    17,19,21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,51,53,55,
    57,59,61,63,65,67,69,71,73,75,77,79,81,83,85,87,89,91,93,95,
    97,99,101,103,105,107,109,111,113,115,117,119,121,123,125,127,129,131,133,135,
};

local RD_DBC_REPAIR_SHIELD = {
    1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,6,
    6,6,7,7,7,8,8,9,9,10,11,12,13,14,15,16,17,19,21,23,
    25,27,29,31,33,35,37,39,41,43,45,47,49,51,53,55,57,59,61,63,
    65,67,69,71,73,75,77,79,81,83,85,87,89,91,93,95,97,99,101,103,
    105,107,109,111,113,115,117,119,121,123,125,127,129,131,133,135,137,139,42,43,
};

local RD_DBC_REPAIR_WEAPON = {
    1,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,
    5,6,6,6,7,7,7,8,8,9,9,10,11,12,13,14,15,16,17,19,
    21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,51,53,55,57,59,
    61,63,65,67,69,71,73,75,77,79,81,83,85,87,89,91,93,95,97,99,
    101,103,105,107,109,111,113,115,117,119,121,123,125,127,129,131,133,135,137,139,
};

local RD_DBC_REPAIR_WEAPON_2H = {
    1,1,1,1,1,3,3,3,3,4,4,4,4,6,6,6,6,7,7,7,
    7,9,9,9,10,10,10,12,12,13,13,15,16,18,19,21,22,24,25,28,
    31,34,37,40,43,46,49,52,55,58,61,64,67,70,73,76,79,82,85,88,
    91,94,97,100,103,106,109,112,115,118,121,124,127,130,133,136,139,142,145,148,
    151,154,157,160,163,166,169,172,175,178,181,184,187,190,193,196,199,202,205,208,
};

local RD_DBC_REPAIR_WEAPON_SMALL = {
    1,1,1,1,1,1,1,1,1,2,2,2,2,3,3,3,3,3,3,3,
    3,4,4,4,5,5,5,6,6,6,6,7,8,9,9,10,11,12,12,14,
    15,17,18,20,21,23,24,26,27,29,30,32,33,35,36,38,39,41,42,44,
    45,47,48,50,51,53,54,56,57,59,60,62,63,65,66,68,69,71,72,74,
    75,77,78,80,81,83,84,86,87,89,90,92,93,95,96,98,99,101,102,104,
};

local RD_DBC_REPAIR_FISHING = {
    1,1,1,1,1,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,
    4,4,4,4,5,5,5,6,6,6,7,7,8,8,8,9,9,9,9,9,
    9,10,10,10,11,11,11,12,12,12,13,13,13,14,14,14,14,14,14,15,
    15,15,16,16,16,17,17,17,18,18,18,18,18,18,19,19,19,20,20,20,
    21,21,21,22,22,22,23,23,23,23,23,23,24,24,24,25,25,25,26,26,
};

local RD_DBC_REPAIR_QUALITY = {
    [0] = 0.60,  -- Poor
    [1] = 0.80,  -- Common
    [2] = 1.00,  -- Uncommon
    [3] = 1.25,  -- Rare
    [4] = 2.50,  -- Epic
    [5] = 3.00,  -- Legendary
};

local function RelationshipsDashboard_GetRepairMultiplier(slotId, itemLink, itemLevel)
    local ilvl = itemLevel or 1;
    if ilvl < 1 then ilvl = 1; end
    if ilvl > 100 then ilvl = 100; end
    ilvl = floor(ilvl + 0.5);

    local _, _, _, _, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink);
    local subTypeLower = itemSubType and strlower(itemSubType) or "";

    if itemEquipLoc == "INVTYPE_SHIELD" or strfind(subTypeLower, "shield") then
        return RD_DBC_REPAIR_SHIELD[ilvl] or 0;
    end

    if itemType == "Armor"
            or itemEquipLoc == "INVTYPE_HEAD"
            or itemEquipLoc == "INVTYPE_SHOULDER"
            or itemEquipLoc == "INVTYPE_CHEST"
            or itemEquipLoc == "INVTYPE_ROBE"
            or itemEquipLoc == "INVTYPE_WAIST"
            or itemEquipLoc == "INVTYPE_LEGS"
            or itemEquipLoc == "INVTYPE_FEET"
            or itemEquipLoc == "INVTYPE_WRIST"
            or itemEquipLoc == "INVTYPE_HAND"
            or itemEquipLoc == "INVTYPE_CLOAK"
            or (slotId ~= 16 and slotId ~= 17 and slotId ~= 18) then
        return RD_DBC_REPAIR_ARMOR[ilvl] or 0;
    end

    if strfind(subTypeLower, "fishing") then
        return RD_DBC_REPAIR_FISHING[ilvl] or 0;
    end
    if strfind(subTypeLower, "dagger") or strfind(subTypeLower, "wand") then
        return RD_DBC_REPAIR_WEAPON_SMALL[ilvl] or 0;
    end
    if itemEquipLoc == "INVTYPE_2HWEAPON"
            or strfind(subTypeLower, "two%-hand")
            or strfind(subTypeLower, "staff")
            or strfind(subTypeLower, "staves")
            or strfind(subTypeLower, "polearm")
            or strfind(subTypeLower, "crossbow") then
        return RD_DBC_REPAIR_WEAPON_2H[ilvl] or 0;
    end

    return RD_DBC_REPAIR_WEAPON[ilvl] or 0;
end

local RelationshipsDashboard_CalculateInventoryRepairCost;

local function RelationshipsDashboard_CalculateDurabilityAndRepair()
    local totalCurrentDur = 0;
    local totalMaxDur = 0;
    local repairCost = 0;
    local slotsWithDurability = 0;

    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local hasDurability = false;
        local curDur, maxDur;

        -- Skip slots that never have durability
        if SLOTS_NO_DURABILITY[slotId] then
            -- Skip accessory slots entirely
        elseif not RD_DURABILITY_SLOTS[slotId] then
            -- Skip slots we don't track (e.g. waist in vanilla has no dur)
        else
            local itemLink = GetInventoryItemLink("player", slotId);
            if itemLink then
                local itemID = RelationshipsDashboard_ExtractItemID(itemLink);
                local existingSaved = RD_SavedDurability[slotId];
                if existingSaved and existingSaved.itemID and itemID and existingSaved.itemID ~= itemID then
                    RD_SavedDurability[slotId] = nil;
                end
                -- Method 1: GetInventoryItemDurability (vanilla 1.12 API)
                -- Returns currentDurability, maxDurability for the slot.
                -- This is the most reliable method and works without a repair NPC.
                if GetInventoryItemDurability then
                    curDur, maxDur = GetInventoryItemDurability(slotId);
                    if curDur and maxDur and maxDur > 0 then
                        -- Only TRUST this reading when it reports actual damage
                        -- (curDur < maxDur) or when a repair merchant is open.
                        -- On Turtle/OctoWoW the API frequently reports FULL
                        -- durability outside a merchant (notably right after a
                        -- /reload or login). Trusting a bogus "full" reading
                        -- would wipe our tracked estimate and falsely snap the
                        -- dashboard back to 100%. When it looks full and we are
                        -- not at a merchant, fall through to the saved estimate.
                        if curDur < maxDur or RD_AtRepairMerchant then
                            hasDurability = true;
                            RD_SavedDurability[slotId] = { cur = curDur, max = maxDur, itemID = itemID };
                        end
                    end
                end

                -- Method 2: Tooltip scanning for durability (fallback)
                if not hasDurability and RelationshipsDashboardTooltip then
                    RelationshipsDashboard_ResetTooltip();
                    RelationshipsDashboardTooltip_SetInventoryItemSafe("player", slotId);

                    for j = 1, RelationshipsDashboardTooltip:NumLines() do
                        local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. j);
                        if textLine then
                            local text = textLine:GetText();
                            if text then
                                local _, _, dCur, dMax = strfind(text, "Durability:%s*(%d+)%s*/%s*(%d+)");
                                if dCur and dMax then
                                    curDur = tonumber(dCur);
                                    maxDur = tonumber(dMax);
                                    -- Same trust rule as the API path: a "full"
                                    -- reading outside a repair merchant may be a
                                    -- server quirk, so keep the saved estimate
                                    -- instead of resetting to 100%.
                                    if maxDur and maxDur > 0
                                            and (curDur < maxDur or RD_AtRepairMerchant) then
                                        hasDurability = true;
                                        RD_SavedDurability[slotId] = { cur = curDur, max = maxDur, itemID = itemID };
                                    end
                                    break;
                                end
                            end
                        end
                    end
                end

                -- Method 3: Use saved/estimated durability (fallback when API fails)
                -- This ensures we always show a meaningful value even when not
                -- at a repair NPC and the vanilla API returns nothing.
                if not hasDurability then
                    local saved = RD_SavedDurability[slotId];
                    if saved and saved.max and saved.max > 0 then
                        -- Use the saved estimate
                        curDur = saved.cur;
                        maxDur = saved.max;
                        saved.itemID = itemID;
                        hasDurability = true;
                    else
                        -- No saved data: item is likely at full durability
                        -- (newly equipped or first time reading)
                        -- Use default max durability for the slot
                        local defaultMax = RD_DEFAULT_MAX_DURABILITY[slotId] or 85;
                        maxDur = defaultMax;
                        curDur = defaultMax; -- Assume full when unknown
                        hasDurability = true;
                        -- Save for future tracking
                        RD_SavedDurability[slotId] = { cur = curDur, max = maxDur, itemID = itemID };
                    end
                end
            else
                -- No item in this slot — clear saved data
                RD_SavedDurability[slotId] = nil;
            end
        end

        if hasDurability and maxDur > 0 then
            totalCurrentDur = totalCurrentDur + curDur;
            totalMaxDur = totalMaxDur + maxDur;
            slotsWithDurability = slotsWithDurability + 1;

            -- Estimate repair cost for this item when merchant is not open
            -- Vanilla WoW repair formula is approximately:
            --   cost = (maxDur - curDur) * slotMultiplier * qualityFactor * (itemLevel / 50)
            -- where qualityFactor depends on item quality and slotMultiplier varies by slot
            local itemLink = GetInventoryItemLink("player", slotId);
            if itemLink then
                local quality = RelationshipsDashboard_GetItemQualityFromLink(itemLink);
                local itemLevel = RelationshipsDashboard_GetItemLevel(itemLink);
                local durLost = maxDur - curDur;

                if durLost > 0 then
                    local dmultiplier = RelationshipsDashboard_GetRepairMultiplier(slotId, itemLink, itemLevel);
                    local qFactor = RD_DBC_REPAIR_QUALITY[quality] or 1.0;
                    local slotRepairCost = floor((durLost * dmultiplier * qFactor) + 0.5);
                    repairCost = repairCost + slotRepairCost;
                end
            end
        end
    end

    repairCost = repairCost + RelationshipsDashboard_CalculateInventoryRepairCost();

    -- If a repair merchant is open, GetRepairAllCost() gives the exact cost.
    -- This is handled separately in RelationshipsDashboard_UpdateRepairFromMerchant
    -- and applied in UpdateStats when RelationshipsDashboard_MerchantRepairCost > 0.

    local avgDurability = 100;
    if totalMaxDur > 0 then
        avgDurability = (totalCurrentDur / totalMaxDur) * 100;
    end

    return avgDurability, repairCost, slotsWithDurability;
end

-- Ensure RD_SavedDurability[slotId] exists for an equipped durability item so
-- that death / spirit-healer / combat penalties can decrement it even when the
-- character panel has never been opened yet (in which case CalculateDurability
-- would not have populated saved state yet).
local function RelationshipsDashboard_EnsureSavedDurability(slotId)
    local saved = RD_SavedDurability[slotId];
    local itemLink = GetInventoryItemLink("player", slotId);
    local itemID = RelationshipsDashboard_ExtractItemID(itemLink);
    if saved and saved.max and saved.max > 0 and (not itemID or not saved.itemID or saved.itemID == itemID) then
        saved.itemID = itemID;
        return saved;
    end
    if saved and itemID and saved.itemID and saved.itemID ~= itemID then
        RD_SavedDurability[slotId] = nil;
    end
    local curDur, maxDur;
    if GetInventoryItemDurability then
        curDur, maxDur = GetInventoryItemDurability(slotId);
    end
    if not (curDur and maxDur and maxDur > 0) and RelationshipsDashboardTooltip then
        RelationshipsDashboard_ResetTooltip();
        RelationshipsDashboardTooltip_SetInventoryItemSafe("player", slotId);
        for j = 1, RelationshipsDashboardTooltip:NumLines() do
            local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. j);
            if textLine then
                local text = textLine:GetText();
                if text then
                    local _, _, dCur, dMax = strfind(text, "Durability:%s*(%d+)%s*/%s*(%d+)");
                    if dCur and dMax then
                        curDur = tonumber(dCur);
                        maxDur = tonumber(dMax);
                        break;
                    end
                end
            end
        end
    end
    if not (curDur and maxDur and maxDur > 0) then
        maxDur = RD_DEFAULT_MAX_DURABILITY[slotId] or 85;
        curDur = maxDur;
    end
    RD_SavedDurability[slotId] = { cur = curDur, max = maxDur, itemID = itemID };
    return RD_SavedDurability[slotId];
end

local function RelationshipsDashboard_ReadContainerDurability(bag, slot)
    local curDur, maxDur;
    if GetContainerItemDurability then
        local ok, c, m = pcall(function() return GetContainerItemDurability(bag, slot); end);
        if ok then
            curDur = c;
            maxDur = m;
        end
    end
    if not (curDur and maxDur and maxDur > 0) and RelationshipsDashboardTooltip then
        RelationshipsDashboard_ResetTooltip();
        local ok = pcall(function() RelationshipsDashboardTooltip:SetBagItem(bag, slot); end);
        if ok then
            for j = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. j);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        local _, _, dCur, dMax = strfind(text, "Durability:%s*(%d+)%s*/%s*(%d+)");
                        if dCur and dMax then
                            curDur = tonumber(dCur);
                            maxDur = tonumber(dMax);
                            break;
                        end
                    end
                end
            end
        end
    end
    return curDur, maxDur;
end

local function RelationshipsDashboard_GetSavedBagKey(bag, slot)
    return "bag" .. bag .. ":" .. slot;
end

local function RelationshipsDashboard_GetDefaultMaxForItemLink(itemLink)
    local _, _, _, _, _, _, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink);
    local subTypeLower = itemSubType and strlower(itemSubType) or "";
    if itemEquipLoc == "INVTYPE_CHEST" or itemEquipLoc == "INVTYPE_ROBE" then return RD_DEFAULT_MAX_DURABILITY[5]; end
    if itemEquipLoc == "INVTYPE_LEGS" then return RD_DEFAULT_MAX_DURABILITY[7]; end
    if itemEquipLoc == "INVTYPE_HEAD" then return RD_DEFAULT_MAX_DURABILITY[1]; end
    if itemEquipLoc == "INVTYPE_SHOULDER" then return RD_DEFAULT_MAX_DURABILITY[3]; end
    if itemEquipLoc == "INVTYPE_FEET" then return RD_DEFAULT_MAX_DURABILITY[8]; end
    if itemEquipLoc == "INVTYPE_WRIST" then return RD_DEFAULT_MAX_DURABILITY[9]; end
    if itemEquipLoc == "INVTYPE_HAND" then return RD_DEFAULT_MAX_DURABILITY[10]; end
    if itemEquipLoc == "INVTYPE_CLOAK" then return RD_DEFAULT_MAX_DURABILITY[15]; end
    if itemEquipLoc == "INVTYPE_WEAPON" or itemEquipLoc == "INVTYPE_WEAPONMAINHAND" or itemEquipLoc == "INVTYPE_WEAPONOFFHAND" then return 90; end
    if itemEquipLoc == "INVTYPE_2HWEAPON" or itemEquipLoc == "INVTYPE_RANGED" or itemEquipLoc == "INVTYPE_RANGEDRIGHT" or itemEquipLoc == "INVTYPE_SHIELD" then return 100; end
    if strfind(subTypeLower, "shield") then return 100; end
    return nil;
end

local function RelationshipsDashboard_EstimateSingleRepairCost(slotId, itemLink, curDur, maxDur)
    if not itemLink or not curDur or not maxDur or maxDur <= 0 then return 0; end
    local durLost = maxDur - curDur;
    if durLost <= 0 then return 0; end
    local quality = RelationshipsDashboard_GetItemQualityFromLink(itemLink);
    local itemLevel = RelationshipsDashboard_GetItemLevel(itemLink);
    if not itemLevel or itemLevel <= 0 then
        itemLevel = UnitLevel("player") or 1;
    end
    local dmultiplier = RelationshipsDashboard_GetRepairMultiplier(slotId, itemLink, itemLevel);
    local qFactor = RD_DBC_REPAIR_QUALITY[quality] or 1.0;
    return floor((durLost * dmultiplier * qFactor) + 0.5);
end

RelationshipsDashboard_CalculateInventoryRepairCost = function()
    local repairCost = 0;
    if not GetContainerNumSlots or not GetContainerItemLink then return 0; end

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag) or 0;
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot);
            if itemLink then
                local itemID = RelationshipsDashboard_ExtractItemID(itemLink);
                local key = RelationshipsDashboard_GetSavedBagKey(bag, slot);
                local saved = RD_SavedDurability[key];
                if saved and itemID and saved.itemID and saved.itemID ~= itemID then
                    saved = nil;
                    RD_SavedDurability[key] = nil;
                end

                local curDur, maxDur = RelationshipsDashboard_ReadContainerDurability(bag, slot);
                if curDur and maxDur and maxDur > 0 then
                    if curDur < maxDur or RD_AtRepairMerchant then
                        RD_SavedDurability[key] = { cur = curDur, max = maxDur, itemID = itemID };
                        saved = RD_SavedDurability[key];
                    end
                end

                if saved and saved.max and saved.max > 0 then
                    saved.itemID = itemID;
                    repairCost = repairCost + RelationshipsDashboard_EstimateSingleRepairCost(16, itemLink, saved.cur, saved.max);
                end
            else
                RD_SavedDurability[RelationshipsDashboard_GetSavedBagKey(bag, slot)] = nil;
            end
        end
    end

    return repairCost;
end

local function RelationshipsDashboard_SyncEquippedDurabilityFromGame(allowFull)
    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        if RD_DURABILITY_SLOTS[slotId] and not SLOTS_NO_DURABILITY[slotId] then
            local itemLink = GetInventoryItemLink("player", slotId);
            if itemLink then
                local itemID = RelationshipsDashboard_ExtractItemID(itemLink);
                local curDur, maxDur;
                if GetInventoryItemDurability then
                    curDur, maxDur = GetInventoryItemDurability(slotId);
                end
                if curDur and maxDur and maxDur > 0 and (allowFull or curDur < maxDur) then
                    RD_SavedDurability[slotId] = { cur = curDur, max = maxDur, itemID = itemID };
                elseif RelationshipsDashboardTooltip then
                    RelationshipsDashboard_ResetTooltip();
                    RelationshipsDashboardTooltip_SetInventoryItemSafe("player", slotId);
                    for j = 1, RelationshipsDashboardTooltip:NumLines() do
                        local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. j);
                        if textLine then
                            local text = textLine:GetText();
                            if text then
                                local _, _, dCur, dMax = strfind(text, "Durability:%s*(%d+)%s*/%s*(%d+)");
                                if dCur and dMax then
                                    curDur = tonumber(dCur);
                                    maxDur = tonumber(dMax);
                                    if maxDur and maxDur > 0 and (allowFull or curDur < maxDur) then
                                        RD_SavedDurability[slotId] = { cur = curDur, max = maxDur, itemID = itemID };
                                    end
                                    break;
                                end
                            end
                        end
                    end
                end
            else
                RD_SavedDurability[slotId] = nil;
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Apply death penalty: Reduce all equipped items' estimated durability by 10%
-- In vanilla WoW, dying costs 10% durability on all equipped items.
-- This is applied even to items that already have 0 durability (they go negative
-- in the internal representation, but we clamp to 0 for display).
-------------------------------------------------------------------------------
local function RelationshipsDashboard_ApplyDeathPenalty()
    -- No durability loss in battlegrounds or duels. Re-check live BG status
    -- here in case ZONE_CHANGED has not yet updated the cached flag (some
    -- Turtle WoW / OctoWoW builds fire PLAYER_DEAD before ZONE_CHANGED on
    -- battleground entries that kill on-arrival).
    if not RD_InBattleground then
        RD_InBattleground = RelationshipsDashboard_IsInBattleground();
    end
    if RD_InBattleground then
        -- Belt-and-suspenders: if we somehow had already applied wear before
        -- realizing we were in a BG, restore the snapshot taken on entry.
        RelationshipsDashboard_RestoreDurabilityFromBGSnapshot();
        return;
    end
    if RD_InDuel then return; end
    for i = 1, table.getn(EQUIPMENT_SLOTS) do

        local slotId = EQUIPMENT_SLOTS[i];
        if RD_DURABILITY_SLOTS[slotId] and not SLOTS_NO_DURABILITY[slotId] then
            local itemLink = GetInventoryItemLink("player", slotId);
            if itemLink then
                -- Make sure we have a baseline for this slot even if the
                -- character panel has never been opened this session.
                local saved = RelationshipsDashboard_EnsureSavedDurability(slotId);
                if saved and saved.max and saved.max > 0 then
                    -- Death penalty: lose 10% of max durability
                    local loss = floor(saved.max * 0.10);
                    if loss < 1 then loss = 1; end
                    saved.cur = saved.cur - loss;
                    if saved.cur < 0 then saved.cur = 0; end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Apply combat wear: Small durability loss from taking hits in combat.
-- Each time the player takes damage while in combat, there's a chance
-- of durability loss on armor pieces. In vanilla WoW, durability loss from
-- combat hits is approximately 0.1-0.5 durability per hit depending on damage.
-- We use a simplified model: every N damage events, lose 1 durability point
-- distributed across armor slots.
-------------------------------------------------------------------------------
local function RelationshipsDashboard_ApplyCombatWear(damageAmount)
    if not RD_InCombat then return; end
    -- No durability loss in battlegrounds or duels
    if not RD_InBattleground then
        RD_InBattleground = RelationshipsDashboard_IsInBattleground();
    end
    if RD_InBattleground then return; end
    if RD_InDuel then return; end

    if not damageAmount or damageAmount <= 0 then return; end

    RD_CombatHitCount = RD_CombatHitCount + 1;

    -- Every 20 combat hits, apply 1 durability point loss to a random armor slot
    -- This approximates vanilla WoW's combat durability wear rate
    -- (roughly 0.05-0.1 dur per hit depending on damage magnitude)
    if RD_CombatHitCount >= 20 then
        RD_CombatHitCount = 0;

        -- Pick armor slots to lose durability (not weapons, those don't decay from hits)
        local armorSlots = { 1, 3, 5, 7, 8, 9, 10, 15 }; -- Head, Shoulder, Chest, Legs, Feet, Wrist, Hands, Back
        -- Pick a random slot
        local slotIdx = random(1, table.getn(armorSlots));
        local slotId = armorSlots[slotIdx];

        local itemLink = GetInventoryItemLink("player", slotId);
        if itemLink then
            local saved = RelationshipsDashboard_EnsureSavedDurability(slotId);
            if saved and saved.max and saved.max > 0 then
                saved.cur = saved.cur - 1;
                if saved.cur < 0 then saved.cur = 0; end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Reset all saved durability to full (used when player repairs at a merchant)
-------------------------------------------------------------------------------
local function RelationshipsDashboard_ResetDurabilityToFull()
    for key, saved in pairs(RD_SavedDurability) do
        if saved and saved.max and saved.max > 0 then
            saved.cur = saved.max; -- Fully repaired
        end
    end
end

-------------------------------------------------------------------------------
-- Apply spirit-healer resurrection penalty.
-- Spirit Healers resurrect a dead player at the cost of 25% durability loss
-- to ALL items (equipped + inventory). We can only reliably estimate the
-- equipped portion; inventory durability isn't cheaply readable in 1.12.
-- Characters level 10 and under do NOT lose durability from spirit rez.
-------------------------------------------------------------------------------
local function RelationshipsDashboard_ApplySpiritHealerPenalty()
    -- No durability loss in battlegrounds or duels (duels never trigger a
    -- spirit-healer rez, but guard defensively in case the state races).
    if not RD_InBattleground then
        RD_InBattleground = RelationshipsDashboard_IsInBattleground();
    end
    if RD_InBattleground then
        RelationshipsDashboard_RestoreDurabilityFromBGSnapshot();
        return;
    end
    if RD_InDuel then return; end
    if UnitLevel("player") <= 10 then return; end

    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        if RD_DURABILITY_SLOTS[slotId] and not SLOTS_NO_DURABILITY[slotId] then
            local itemLink = GetInventoryItemLink("player", slotId);
            if itemLink then
                local saved = RelationshipsDashboard_EnsureSavedDurability(slotId);
                if saved and saved.max and saved.max > 0 then
                    -- Spirit healer: lose 25% of max durability on top of the
                    -- 10% death penalty already applied by PLAYER_DEAD.
                    local loss = floor(saved.max * 0.25);
                    if loss < 1 then loss = 1; end
                    saved.cur = saved.cur - loss;
                    if saved.cur < 0 then saved.cur = 0; end
                end
            end
        end
    end

    -- Spirit healer repair bills include durability loss on damaged items in
    -- bags as well. Track the equipped part exactly and bag items when the
    -- client exposes their durability; otherwise seed a reasonable max from
    -- equip type so the repair total does not ignore inventory damage.
    if GetContainerNumSlots and GetContainerItemLink then
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag) or 0;
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot);
                if itemLink then
                    local itemID = RelationshipsDashboard_ExtractItemID(itemLink);
                    local key = RelationshipsDashboard_GetSavedBagKey(bag, slot);
                    local curDur, maxDur = RelationshipsDashboard_ReadContainerDurability(bag, slot);
                    if not (curDur and maxDur and maxDur > 0) then
                        maxDur = RelationshipsDashboard_GetDefaultMaxForItemLink(itemLink);
                        curDur = maxDur;
                    end
                    if curDur and maxDur and maxDur > 0 then
                        local saved = RD_SavedDurability[key];
                        if not saved or not saved.max or saved.max <= 0 or (itemID and saved.itemID and saved.itemID ~= itemID) then
                            saved = { cur = curDur, max = maxDur, itemID = itemID };
                            RD_SavedDurability[key] = saved;
                        end
                        local loss = floor(saved.max * 0.25);
                        if loss < 1 then loss = 1; end
                        saved.cur = saved.cur - loss;
                        if saved.cur < 0 then saved.cur = 0; end
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Try to get actual repair cost from an open merchant
-- This is called when MERCHANT_SHOW / MERCHANT_UPDATE events fire
-- Uses GetRepairAllCost() - the correct vanilla 1.12 API
-- Returns repairAllCost, canRepair (only works at a repair-capable merchant)
-------------------------------------------------------------------------------
local RelationshipsDashboard_MerchantRepairCost = 0;

-- Tracks the previous non-zero repair cost while a repair merchant is open.
-- When the reported cost transitions from >0 to 0, or the player's gold drops
-- by approximately that amount, we know a repair just happened and can safely
-- reset saved durability to full WITHOUT needing a /reload.
RD_PrevMerchantRepairCost = 0;

local function RelationshipsDashboard_UpdateRepairFromMerchant()
    -- GetRepairAllCost is the correct vanilla 1.12 API function name
    -- It only returns a value when a repair-capable merchant window is open
    if not GetRepairAllCost then return; end

    local cost, canRepair = GetRepairAllCost();
    -- Track whether a repair-capable merchant is currently open so the rest
    -- of the addon knows it can trust "full" durability readings.
    if canRepair then
        RD_AtRepairMerchant = true;
    else
        RD_AtRepairMerchant = false;
    end

    if not canRepair then
        -- Merchant can't repair at all. Clear the transient state so a later
        -- MERCHANT_UPDATE at a real repair NPC starts from a clean slate.
        RelationshipsDashboard_MerchantRepairCost = 0;
        RD_PrevMerchantRepairCost = 0;
        return;
    end

    -- CRITICAL: refresh actual durability from the API BEFORE we do anything
    -- else. At a repair merchant GetInventoryItemDurability is reliable, so we
    -- want RD_SavedDurability to reflect ground truth before we (a) calibrate
    -- against the reported cost, or (b) decide the player just repaired.
    RelationshipsDashboard_SyncEquippedDurabilityFromGame(true);

    if cost and cost > 0 then
        RelationshipsDashboard_MerchantRepairCost = cost;
        RD_PrevMerchantRepairCost = cost;
        -- Calibrate our away-from-merchant estimate against the exact cost
        -- the game reports. We recompute our DBC-based estimate for the CURRENT
        -- (freshly-updated) damaged gear and store a narrow ratio, so future
        -- estimates match this server while still staying grounded in gear data.
        local _, rawEstimate = RelationshipsDashboard_CalculateDurabilityAndRepair();
        if rawEstimate and rawEstimate > 0 then
            local factor = cost / rawEstimate;
            if factor < 0.5 then factor = 0.5; end
            if factor > 2.0 then factor = 2.0; end
            RD_RepairCalibration = factor;
            if RelationshipsDashboardDB then
                RelationshipsDashboardDB.repairCalibration = factor;
                RelationshipsDashboardDB.repairCalibrationVersion = RD_REPAIR_CALIBRATION_VERSION;
            end
        end
    else
        -- Repair cost is 0 at a repair-capable merchant. Two possibilities:
        --   (a) Player just clicked Repair All / repaired every item.
        --   (b) All gear was already at full durability when they opened
        --       the merchant.
        -- Either way the correct visible state is "everything full". Reset.
        RelationshipsDashboard_MerchantRepairCost = 0;
        RD_PrevMerchantRepairCost = 0;
        RelationshipsDashboard_ResetDurabilityToFull();
    end
end

-------------------------------------------------------------------------------
-- Get melee hit chance
-- In vanilla 1.12, melee hit rating doesn't exist as a rating.
-- Hit chance comes from gear bonuses (+X% hit) and the base 5% against same level.
-- We scan the paper doll tooltip for hit chance, or use GetCombatRatingBonus if available.
-- For vanilla: scan tooltip of CharacterDamageFrame or use stat bonus calculations.
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetMeleeHitChance()
    -- In vanilla 1.12, there's no direct API for hit chance from gear
    -- The best approach is to calculate from hit rating on gear if available,
    -- or scan the character's melee hit bonus from tooltip
    
    -- Try using GetCombatRating / GetCombatRatingBonus if available (Turtle WoW extension)
    if GetCombatRating and GetCombatRatingBonus then
        -- CR_HIT_MELEE = 6 in later patches, may not exist in 1.12
        local hitRating = GetCombatRating(6);
        if hitRating then
            local hitBonus = GetCombatRatingBonus(6);
            if hitBonus then
                return 5.0 + hitBonus; -- Base 5% + gear bonus
            end
        end
    end

    -- Fallback: try scanning the paper doll melee tooltip
    -- In vanilla, hovering over the melee damage stat shows hit chance
    if RelationshipsDashboardTooltip then
        RelationshipsDashboard_ResetTooltip();
        -- Set to the melee damage tooltip
        RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, 16); -- Main hand

        for i = 1, RelationshipsDashboardTooltip:NumLines() do
            local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
            if textLine then
                local text = textLine:GetText();
                if text then
                    -- Look for hit chance modifiers on weapon tooltip
                    local _, _, hitVal = strfind(text, "improves your chance to hit by (%d+)%%");
                    if hitVal then
                        return 5.0 + tonumber(hitVal);
                    end
                    local _, _, hitVal2 = strfind(text, "%+(%d+)%% Hit");
                    if hitVal2 then
                        return 5.0 + tonumber(hitVal2);
                    end
                end
            end
        end
    end

    -- Final fallback: base hit chance is 5% for melee against same-level target
    -- We'll try to accumulate +hit from equipment via tooltip scanning
    local hitBonus = 0;
    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local itemLink = GetInventoryItemLink(RD_UNIT, slotId);
        if itemLink and RelationshipsDashboardTooltip then
            RelationshipsDashboard_ResetTooltip();
            RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, slotId);
            for i = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        local _, _, val = strfind(text, "%+(%d+)%% chance to hit");
                        if val then hitBonus = hitBonus + tonumber(val); end
                        local _, _, val2 = strfind(text, "Equip: Increases your chance to hit by (%d+)%%");
                        if val2 then hitBonus = hitBonus + tonumber(val2); end
                    end
                end
            end
        end
    end
    return 5.0 + hitBonus;
end

-------------------------------------------------------------------------------
-- Get spell hit chance
-- Similar approach to melee hit - scan gear for +spell hit bonuses
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetSpellHitChance()
    -- Try GetCombatRatingBonus if available
    if GetCombatRating and GetCombatRatingBonus then
        -- CR_HIT_SPELL = 8
        local hitRating = GetCombatRating(8);
        if hitRating then
            local hitBonus = GetCombatRatingBonus(8);
            if hitBonus then
                return 5.0 + hitBonus; -- Base 5% + gear bonus
            end
        end
    end

    -- Fallback: scan equipment for +spell hit
    local hitBonus = 0;
    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local itemLink = GetInventoryItemLink(RD_UNIT, slotId);
        if itemLink and RelationshipsDashboardTooltip then
            RelationshipsDashboard_ResetTooltip();
            RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, slotId);
            for i = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        local _, _, val = strfind(text, "chance to hit with spells by (%d+)%%");
                        if val then hitBonus = hitBonus + tonumber(val); end
                        local _, _, val2 = strfind(text, "%+(%d+)%% Spell Hit");
                        if val2 then hitBonus = hitBonus + tonumber(val2); end
                        local _, _, val3 = strfind(text, "Increases your chance to hit with spells by (%d+)%%");
                        if val3 then hitBonus = hitBonus + tonumber(val3); end
                    end
                end
            end
        end
    end
    return 5.0 + hitBonus;
end

-------------------------------------------------------------------------------
-- Get spell crit chance
-- In vanilla 1.12, there's GetSpellCritChance() available as a global
-- Or we can use UnitStat-based formulas and intellect contribution
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetSpellCritChance()
    -- Method 1: Try GetSpellCritChance (may be available in Turtle WoW's extended API)
    if GetSpellCritChance then
        local crit = GetSpellCritChance(SPELL_SCHOOL_INDEX);
        if crit and crit > 0 then
            return crit;
        end
    end

    -- Method 2: Base spell crit + Intellect contribution
    -- Base spell crit by class:
    local _, class = UnitClass(RD_UNIT);
    local baseSpellCrit = 0;
    if class == "MAGE" then baseSpellCrit = 3.2;
    elseif class == "WARLOCK" then baseSpellCrit = 2.6;
    elseif class == "PRIEST" then baseSpellCrit = 2.4;
    elseif class == "DRUID" then baseSpellCrit = 2.4;
    elseif class == "SHAMAN" then baseSpellCrit = 2.4;
    elseif class == "PALADIN" then baseSpellCrit = 2.4;
    else baseSpellCrit = 0; end

    -- Intellect contribution: roughly 1% crit per 59.5 intellect at level 60
    local level = UnitLevel(RD_UNIT);
    local intStat = UnitStat(RD_UNIT, 4); -- Intellect
    local intPerCrit = 59.5;
    if level < 60 then
        intPerCrit = 59.5 * (level / 60);
    end
    local intCritBonus = intStat / intPerCrit;

    -- Scan gear for +spell crit
    local gearCritBonus = 0;
    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local itemLink = GetInventoryItemLink(RD_UNIT, slotId);
        if itemLink and RelationshipsDashboardTooltip then
            RelationshipsDashboard_ResetTooltip();
            RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, slotId);
            for i = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        local _, _, val = strfind(text, "critical strike chance with spells by (%d+)%%");
                        if val then gearCritBonus = gearCritBonus + tonumber(val); end
                        local _, _, val2 = strfind(text, "%+(%d+)%% Spell Crit");
                        if val2 then gearCritBonus = gearCritBonus + tonumber(val2); end
                        local _, _, val3 = strfind(text, "Improves your chance to get a critical strike with spells by (%d+)%%");
                        if val3 then gearCritBonus = gearCritBonus + tonumber(val3); end
                    end
                end
            end
        end
    end

    return baseSpellCrit + intCritBonus + gearCritBonus;
end

-------------------------------------------------------------------------------
-- Get melee crit chance
-- In vanilla 1.12: base melee crit + agility contribution + gear bonuses
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetMeleeCritChance()
    -- Method 1: Try GetCritChance (may be available in Turtle WoW)
    if GetCritChance then
        local crit = GetCritChance();
        if crit and crit > 0 then
            return crit;
        end
    end

    -- Method 2: Calculate from base + agility + gear
    local _, class = UnitClass(RD_UNIT);
    local level = UnitLevel(RD_UNIT);

    -- Base crit rate by class (approximate)
    local baseCrit = 5.0; -- All classes have 5% base melee crit in vanilla

    -- Agility per crit varies by class and level
    -- At level 60: Warrior=20, Rogue=~29, Hunter=~53, Paladin=~20, etc.
    local agiPerCrit = 20;
    if class == "WARRIOR" then agiPerCrit = 20;
    elseif class == "ROGUE" then agiPerCrit = 29;
    elseif class == "HUNTER" then agiPerCrit = 53;
    elseif class == "PALADIN" then agiPerCrit = 20;
    elseif class == "DRUID" then agiPerCrit = 20;
    elseif class == "SHAMAN" then agiPerCrit = 20;
    end

    -- Scale for level (these values are for level 60)
    if level > 0 and level < 60 then
        agiPerCrit = agiPerCrit * (level / 60);
        if agiPerCrit < 1 then agiPerCrit = 1; end
    end

    local agiStat = UnitStat(RD_UNIT, 2); -- Agility
    local agiCritBonus = agiStat / agiPerCrit;

    -- Scan gear for +melee crit
    local gearCritBonus = 0;
    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local itemLink = GetInventoryItemLink(RD_UNIT, slotId);
        if itemLink and RelationshipsDashboardTooltip then
            RelationshipsDashboard_ResetTooltip();
            RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, slotId);
            for i = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        local _, _, val = strfind(text, "critical strike chance by (%d+)%%");
                        if val then gearCritBonus = gearCritBonus + tonumber(val); end
                        local _, _, val2 = strfind(text, "%+(%d+)%% Crit");
                        if val2 then gearCritBonus = gearCritBonus + tonumber(val2); end
                        local _, _, val3 = strfind(text, "Improves your chance to get a critical strike by (%d+)%%");
                        if val3 then gearCritBonus = gearCritBonus + tonumber(val3); end
                    end
                end
            end
        end
    end

    return baseCrit + agiCritBonus + gearCritBonus;
end

-------------------------------------------------------------------------------
-- Get ranged crit chance
-- For Hunters primarily - based on agility + gear
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetRangedCritChance()
    -- Method 1: Try GetRangedCritChance (Turtle WoW extension)
    if GetRangedCritChance then
        local crit = GetRangedCritChance();
        if crit and crit > 0 then
            return crit;
        end
    end

    -- Method 2: Similar to melee crit but with ranged-specific agi ratios
    local _, class = UnitClass(RD_UNIT);
    local level = UnitLevel(RD_UNIT);
    local baseCrit = 5.0;

    -- Ranged crit from agility (Hunter-focused)
    local agiPerCrit = 53; -- Hunter value
    if class ~= "HUNTER" then
        agiPerCrit = 40; -- Other classes
    end
    if level > 0 and level < 60 then
        agiPerCrit = agiPerCrit * (level / 60);
        if agiPerCrit < 1 then agiPerCrit = 1; end
    end

    local agiStat = UnitStat(RD_UNIT, 2);
    local agiCritBonus = agiStat / agiPerCrit;

    -- Scan gear for +ranged crit
    local gearCritBonus = 0;
    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local itemLink = GetInventoryItemLink(RD_UNIT, slotId);
        if itemLink and RelationshipsDashboardTooltip then
            RelationshipsDashboard_ResetTooltip();
            RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, slotId);
            for i = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        local _, _, val = strfind(text, "critical strike chance with ranged by (%d+)%%");
                        if val then gearCritBonus = gearCritBonus + tonumber(val); end
                        local _, _, val2 = strfind(text, "%+(%d+)%% Ranged Crit");
                        if val2 then gearCritBonus = gearCritBonus + tonumber(val2); end
                    end
                end
            end
        end
    end

    return baseCrit + agiCritBonus + gearCritBonus;
end

-------------------------------------------------------------------------------
-- Get spell power (highest school bonus)
-- In vanilla 1.12, spell power is per-school. We show the highest.
-- Uses GetSpellBonusDamage if available, or scans gear.
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetSpellPower()
    -- Method 1: Try GetSpellBonusDamage (Turtle WoW extension)
    if GetSpellBonusDamage then
        local maxPower = 0;
        -- School indices: 2=Holy, 3=Fire, 4=Nature, 5=Frost, 6=Shadow, 7=Arcane
        for school = 2, 7 do
            local power = GetSpellBonusDamage(school);
            if power and power > maxPower then
                maxPower = power;
            end
        end
        return maxPower;
    end

    -- Method 2: Scan gear for +spell damage
    local spellPower = 0;
    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local itemLink = GetInventoryItemLink(RD_UNIT, slotId);
        if itemLink and RelationshipsDashboardTooltip then
            RelationshipsDashboard_ResetTooltip();
            RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, slotId);
            for i = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        local _, _, val = strfind(text, "%+(%d+) Spell Damage");
                        if val then spellPower = spellPower + tonumber(val); end
                        local _, _, val1b = strfind(text, "%+(%d+) Spell Damage and Healing");
                        if val1b then spellPower = spellPower + tonumber(val1b); end
                        local _, _, val1c = strfind(text, "%+(%d+) damage and healing");
                        if val1c then spellPower = spellPower + tonumber(val1c); end
                        local _, _, val1d = strfind(text, "%+(%d+) to Healing Spells");
                        if val1d then spellPower = spellPower + tonumber(val1d); end
                        local _, _, val2 = strfind(text, "up to (%d+) additional spell damage");
                        if val2 then spellPower = spellPower + tonumber(val2); end
                        local _, _, val3 = strfind(text, "Increases damage done by magical spells and effects by up to (%d+)");
                        if val3 then spellPower = spellPower + tonumber(val3); end
                        local _, _, val3b = strfind(text, "damage done by magical spells and effects by up to (%d+)");
                        if val3b then spellPower = spellPower + tonumber(val3b); end
                        local _, _, val3c = strfind(text, "Damage Bonus: (%d+)");
                        if val3c then spellPower = spellPower + tonumber(val3c); end
                        local _, _, val4 = strfind(text, "%+(%d+) Fire Damage");
                        if val4 then spellPower = spellPower + tonumber(val4); end
                        local _, _, val5 = strfind(text, "%+(%d+) Frost Damage");
                        if val5 then spellPower = spellPower + tonumber(val5); end
                        local _, _, val6 = strfind(text, "%+(%d+) Arcane Damage");
                        if val6 then spellPower = spellPower + tonumber(val6); end
                        local _, _, val7 = strfind(text, "%+(%d+) Shadow Damage");
                        if val7 then spellPower = spellPower + tonumber(val7); end
                        local _, _, val8 = strfind(text, "%+(%d+) Nature Damage");
                        if val8 then spellPower = spellPower + tonumber(val8); end
                        local _, _, val9 = strfind(text, "%+(%d+) Holy Damage");
                        if val9 then spellPower = spellPower + tonumber(val9); end
                    end
                end
            end
        end
    end
    return spellPower;
end

-------------------------------------------------------------------------------
-- Get healing power
-- In vanilla 1.12, healing power is separate from spell damage
-- Uses GetSpellBonusHealing if available, or scans gear.
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetHealingPower()
    -- Method 1: Try GetSpellBonusHealing (Turtle WoW extension)
    if GetSpellBonusHealing then
        local healing = GetSpellBonusHealing();
        if healing then
            return healing;
        end
    end

    -- Method 2: Scan gear for +healing
    local healingPower = 0;
    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local itemLink = GetInventoryItemLink(RD_UNIT, slotId);
        if itemLink and RelationshipsDashboardTooltip then
            RelationshipsDashboard_ResetTooltip();
            RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, slotId);
            for i = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        local _, _, val = strfind(text, "healing spells by up to (%d+)");
                        if val then healingPower = healingPower + tonumber(val); end
                        local _, _, val1b = strfind(text, "%+(%d+) to Healing Spells");
                        if val1b then healingPower = healingPower + tonumber(val1b); end
                        local _, _, val1c = strfind(text, "%+(%d+) to Healing");
                        if val1c then healingPower = healingPower + tonumber(val1c); end
                        local _, _, val2 = strfind(text, "%+(%d+) Healing");
                        if val2 then healingPower = healingPower + tonumber(val2); end
                        local _, _, val2b = strfind(text, "%+(%d+) Spell Damage and Healing");
                        if val2b then healingPower = healingPower + tonumber(val2b); end
                        local _, _, val2c = strfind(text, "%+(%d+) Spell Power");
                        if val2c then healingPower = healingPower + tonumber(val2c); end
                        local _, _, val3 = strfind(text, "Increases healing done by spells and effects by up to (%d+)");
                        if val3 then healingPower = healingPower + tonumber(val3); end
                        local _, _, val3b = strfind(text, "healing done by spells and effects by up to (%d+)");
                        if val3b then healingPower = healingPower + tonumber(val3b); end
                    end
                end
            end
        end
    end
    return healingPower;
end

-------------------------------------------------------------------------------
-- Get mana regeneration (spirit-based formula)
-- In vanilla 1.12, mana regen comes from spirit (out of FSR) and gear bonuses
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetManaRegen()
    -- Method 1: Try GetManaRegen (Turtle WoW extension)
    if GetManaRegen then
        local base, casting = GetManaRegen();
        if base then
            return base;
        end
    end

    -- Method 2: Calculate from spirit
    -- Spirit-based mana regen formula (out of combat, not casting):
    -- Regen per tick (2 seconds) varies by class:
    --   Priest: Spirit * 0.125
    --   Mage: Spirit * 0.125  
    --   Warlock: Spirit * 0.1
    --   Druid: Spirit * 0.125
    --   Shaman: Spirit * 0.1
    --   Paladin: Spirit * 0.1
    -- Per second = tickRegen / 2
    local _, class = UnitClass(RD_UNIT);
    local spirit = UnitStat(RD_UNIT, 5);

    -- Only show for mana classes
    local powerType = UnitPowerType(RD_UNIT);
    if powerType ~= 0 then
        return 0; -- Not a mana user
    end

    local spiritFactor = 0;
    if class == "PRIEST" then spiritFactor = 0.125;
    elseif class == "MAGE" then spiritFactor = 0.125;
    elseif class == "WARLOCK" then spiritFactor = 0.1;
    elseif class == "DRUID" then spiritFactor = 0.125;
    elseif class == "SHAMAN" then spiritFactor = 0.1;
    elseif class == "PALADIN" then spiritFactor = 0.1;
    else return 0; end

    local baseRegen = spirit * spiritFactor / 2; -- per second

    -- Scan gear for +mana regen
    local gearRegen = 0;
    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local itemLink = GetInventoryItemLink(RD_UNIT, slotId);
        if itemLink and RelationshipsDashboardTooltip then
            RelationshipsDashboard_ResetTooltip();
            RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, slotId);
            for i = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        local _, _, val = strfind(text, "mana every (%d+) sec");
                        if val then
                            gearRegen = gearRegen + (tonumber(val) / 5); -- Convert per-5sec to per-second
                        end
                        local _, _, val2 = strfind(text, "%+(%d+) mana per 5 sec");
                        if val2 then
                            gearRegen = gearRegen + (tonumber(val2) / 5);
                        end
                        local _, _, val3 = strfind(text, "Allows (%d+) mana per 5 sec");
                        if val3 then
                            gearRegen = gearRegen + (tonumber(val3) / 5);
                        end
                    end
                end
            end
        end
    end

    return baseRegen + gearRegen;
end

-------------------------------------------------------------------------------
-- Get weapon skill for current weapon
-- In vanilla 1.12, weapon skill affects hit/miss/glancing blow calculations
-- We show the skill for the currently equipped main hand weapon type
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetWeaponSkill()
    local itemLink = GetInventoryItemLink(RD_UNIT, 16); -- Main hand
    if not itemLink then return "--"; end

    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink);
    if not itemSubType then return "--"; end

    -- Map weapon subtypes to skill line indices
    -- In vanilla, skill lines are accessed by name
    -- The skill value = min(level * 5, baseSkill + racialBonus + gearBonus)
    local skillName = nil;
    if itemSubType == "Axes" or itemSubType == "One-Handed Axes" then skillName = "Axes";
    elseif itemSubType == "Two-Handed Axes" then skillName = "Two-Handed Axes";
    elseif itemSubType == "Maces" or itemSubType == "One-Handed Maces" then skillName = "Maces";
    elseif itemSubType == "Two-Handed Maces" then skillName = "Two-Handed Maces";
    elseif itemSubType == "Swords" or itemSubType == "One-Handed Swords" then skillName = "Swords";
    elseif itemSubType == "Two-Handed Swords" then skillName = "Two-Handed Swords";
    elseif itemSubType == "Daggers" then skillName = "Daggers";
    elseif itemSubType == "Fist Weapons" then skillName = "Unarmed";
    elseif itemSubType == "Polearms" then skillName = "Polearms";
    elseif itemSubType == "Staves" then skillName = "Staves";
    elseif itemSubType == "Bows" then skillName = "Bows";
    elseif itemSubType == "Crossbows" then skillName = "Crossbows";
    elseif itemSubType == "Guns" then skillName = "Guns";
    elseif itemSubType == "Thrown" then skillName = "Thrown";
    end

    if not skillName then return "--"; end

    -- Try to get skill value from the skills API
    -- In vanilla 1.12, we iterate skill lines
    local numSkills = GetNumSkillLines();
    if numSkills then
        for i = 1, numSkills do
            local skillName2, _, _, skillRank = GetSkillLineInfo(i);
            if skillName2 == skillName then
                return skillRank or "--";
            end
        end
    end

    -- Fallback: max skill for level = level * 5
    local level = UnitLevel(RD_UNIT);
    return level * 5 .. " (max)";
end

-------------------------------------------------------------------------------
-- Get defense skill
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetDefense()
    -- Method 1: Try GetDefense (Turtle WoW)
    if GetDefense then
        local base, mod = GetDefense("player");
        if base then
            return (base + (mod or 0));
        end
    end

    -- Method 2: From skill lines
    local numSkills = GetNumSkillLines();
    if numSkills then
        for i = 1, numSkills do
            local skillName, _, _, skillRank = GetSkillLineInfo(i);
            if skillName == "Defense" then
                return skillRank or 0;
            end
        end
    end

    return 0;
end

-------------------------------------------------------------------------------
-- Get block chance and value
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetBlockChance()
    if GetBlockChance then
        return GetBlockChance();
    end
    -- Only warriors and paladins can block (with shield equipped)
    return 0;
end

-------------------------------------------------------------------------------
-- Get parry chance
-------------------------------------------------------------------------------
local function RelationshipsDashboard_GetParryChance()
    if GetParryChance then
        return GetParryChance();
    end
    -- Base parry is 5% for most melee classes
    local _, class = UnitClass(RD_UNIT);
    if class == "WARRIOR" or class == "PALADIN" or class == "ROGUE" or class == "HUNTER" or class == "DRUID" then
        return 5.0;
    end
    return 0;
end

-------------------------------------------------------------------------------
-- Main Stats Update Function
-- Called on show and on relevant events
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- INSPECT ESTIMATION
-- In vanilla 1.12 the client does NOT expose another player's computed stats
-- (UnitStat/UnitArmor/UnitAttackPower/UnitResistance/GetDodgeChance etc. all
-- return the *player's* own values for a target). The only reliable target
-- data available while inspecting is the equipped item set (item links +
-- tooltips) plus level and class. So when inspecting we ESTIMATE every stat
-- from the target's gear and level. Values are approximate.
-------------------------------------------------------------------------------

-- Approximate un-geared primary stats at level 60, tuned to real vanilla
-- values (roughly the human baseline). Race adjustments applied below.
-- Index: 1=STR 2=AGI 3=STA 4=INT 5=SPI
local RD_BASE_STATS_60 = {
    WARRIOR = { 105, 75,  105, 30, 45 },
    PALADIN = { 100, 60,  95,  65, 75 },
    HUNTER  = { 60,  115, 90,  60, 65 },
    ROGUE   = { 85,  115, 85,  35, 50 },
    PRIEST  = { 40,  50,  70,  115, 125 },
    SHAMAN  = { 80,  60,  90,  85, 90 },
    MAGE    = { 35,  50,  65,  120, 115 },
    WARLOCK = { 50,  55,  80,  105, 105 },
    DRUID   = { 70,  60,  80,  95, 95 },
};

-- Per-race stat modifiers at level 60 relative to the human baseline above.
-- Values are typical vanilla deltas; missing entries default to 0.
-- Index: 1=STR 2=AGI 3=STA 4=INT 5=SPI
local RD_RACE_MODS_60 = {
    Human    = { 0,  0,  0,  0,  0 },
    Dwarf    = { 5, -4,  1, -1, -1 },
    Gnome    = { -5, 2, -1,  3,  0 },
    NightElf = { -4, 4,  0,  0,  0 },
    Orc      = { 3, -3,  1, -3,  2 },
    Undead   = { -1, -2, 0, -2,  5 },
    Tauren  = { 5, -4,  1, -3, -2 },
    Troll   = { 1,  2,  0, -4,  1 },
    Scourge  = { -1, -2, 0, -2,  5 },  -- alt name for Undead
    Goblin   = { -3, 3, -1,  3,  0 },
    HighElf  = { -4, 4,  0,  1, -1 },
};

-- Rough Agility-per-1%-crit (and used for dodge) by class.
local RD_AGI_PER_CRIT = {
    WARRIOR = 20, PALADIN = 20, DRUID = 20, SHAMAN = 20,
    ROGUE = 29, HUNTER = 53, MAGE = 20, PRIEST = 20, WARLOCK = 20,
};

-- Classes that can parry in vanilla.
local RD_CAN_PARRY = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, SHAMAN = true,
};

-- Passive racial resistances (vanilla / Turtle / OctoWoW).
-- Applied on top of gear resistances during inspect. Keys must match the
-- normalized race name (spaces stripped) produced in UpdateStatsInspect.
local RD_RACE_RES = {
    Dwarf    = { frost = 10 },
    Gnome    = { arcane = 10 },
    NightElf = { nature = 10 },
    Tauren   = { nature = 10 },
    Troll    = { nature = 10 },
    Undead   = { shadow = 10 },
    Scourge  = { shadow = 10 },
    HighElf  = { arcane = 10 },
    Goblin   = { fire = 5 },
};

-- Passive racial dodge (% points) — Night Elf Quickness.
local RD_RACE_DODGE = {
    NightElf = 1,
};

-- Passive racial health multiplier — Tauren Endurance (+5% base health).
-- Not applied to Stamina directly because health is read from UnitHealthMax,
-- but kept here for completeness / future use.
local RD_RACE_HEALTH_MULT = {
    Tauren = 1.05,
};

-- Parse a buff/racial tooltip line and add any recognized primary-stat,
-- resistance, spell-power, AP, crit, hit, or mp5 bonuses into `est`.
-- Mirrors the item parser but omits weapon-slot specific fields.
-- Also handles the two common buff phrasings:
--   "+X to Strength"  (Mark of the Wild, Blessing of Kings post-scaling, etc.)
--   "Increases Strength by X"
--   "+X Strength"     (item-style, same as gear)
local function RD_ParseBuffLineInto(est, text)
    if not text then return; end
    local v;

    local function addPrimary(stat, amt)
        if not amt then return; end
        amt = tonumber(amt); if not amt then return; end
        if stat == "str" then est.str = est.str + amt;
        elseif stat == "agi" then est.agi = est.agi + amt;
        elseif stat == "sta" then est.sta = est.sta + amt;
        elseif stat == "int" then est.int = est.int + amt;
        elseif stat == "spi" then est.spi = est.spi + amt;
        elseif stat == "all" then est.allStats = est.allStats + amt; end
    end

    -- "+X <Stat>" (Blessing of Might reads "+X Attack Power", Fortitude
    -- reads "+X Stamina" on Turtle, etc.)
    _,_,v = strfind(text, "%+(%d+) Strength");     addPrimary("str", v);
    _,_,v = strfind(text, "%+(%d+) Agility");      addPrimary("agi", v);
    _,_,v = strfind(text, "%+(%d+) Stamina");      addPrimary("sta", v);
    _,_,v = strfind(text, "%+(%d+) Intellect");    addPrimary("int", v);
    _,_,v = strfind(text, "%+(%d+) Spirit");       addPrimary("spi", v);
    _,_,v = strfind(text, "%+(%d+) to All Stats"); addPrimary("all", v);
    if not v then _,_,v = strfind(text, "%+(%d+) All Stats"); addPrimary("all", v); end

    -- "Increases <Stat> by X" (Arcane Intellect, Divine Spirit, PW:F, etc.)
    _,_,v = strfind(text, "[Ii]ncreases Strength by (%d+)");  addPrimary("str", v);
    _,_,v = strfind(text, "[Ii]ncreases Agility by (%d+)");   addPrimary("agi", v);
    _,_,v = strfind(text, "[Ii]ncreases Stamina by (%d+)");   addPrimary("sta", v);
    _,_,v = strfind(text, "[Ii]ncreases Intellect by (%d+)"); addPrimary("int", v);
    _,_,v = strfind(text, "[Ii]ncreases Spirit by (%d+)");    addPrimary("spi", v);
    _,_,v = strfind(text, "[Ii]ncreases all attributes by (%d+)"); addPrimary("all", v);
    _,_,v = strfind(text, "all party members by (%d+)");  -- Mark/Gift of the Wild form: "...by X"
    if v and strfind(text, "attribute") then addPrimary("all", v); end

    -- Resistances (Shadow Protection, Prayer of Shadow, etc.)
    _,_,v = strfind(text, "%+(%d+) Arcane Resistance"); if v then est.resArcane = est.resArcane + v; end
    _,_,v = strfind(text, "%+(%d+) Fire Resistance");   if v then est.resFire = est.resFire + v; end
    _,_,v = strfind(text, "%+(%d+) Nature Resistance"); if v then est.resNature = est.resNature + v; end
    _,_,v = strfind(text, "%+(%d+) Frost Resistance");  if v then est.resFrost = est.resFrost + v; end
    _,_,v = strfind(text, "%+(%d+) Shadow Resistance"); if v then est.resShadow = est.resShadow + v; end
    _,_,v = strfind(text, "%+(%d+) to All Resistances"); if v then est.allRes = est.allRes + v; end
    _,_,v = strfind(text, "resistance to all schools of magic by (%d+)");
    if v then est.allRes = est.allRes + v; end
    _,_,v = strfind(text, "[Ss]hadow resistance by (%d+)"); if v then est.resShadow = est.resShadow + v; end
    _,_,v = strfind(text, "[Ff]rost resistance by (%d+)");  if v then est.resFrost = est.resFrost + v; end
    _,_,v = strfind(text, "[Ff]ire resistance by (%d+)");   if v then est.resFire = est.resFire + v; end
    _,_,v = strfind(text, "[Nn]ature resistance by (%d+)"); if v then est.resNature = est.resNature + v; end
    _,_,v = strfind(text, "[Aa]rcane resistance by (%d+)"); if v then est.resArcane = est.resArcane + v; end

    -- Attack power (Battle Shout, Trueshot Aura, Blessing of Might)
    _,_,v = strfind(text, "melee attack power by (%d+)"); if v then est.ap = est.ap + v; end
    _,_,v = strfind(text, "ranged attack power by (%d+)"); if v then est.rap = est.rap + v; end
    _,_,v = strfind(text, "attack power by (%d+)");
    if v and not strfind(text, "ranged") then est.ap = est.ap + v; end
    _,_,v = strfind(text, "%+(%d+) Attack Power"); if v then est.ap = est.ap + v; end

    -- Spell power / healing (Arcane Brilliance variants, Blessing of Wisdom, world buffs, etc.
    -- typical is "+X Spell Damage" or "+X Healing")
    _,_,v = strfind(text, "%+(%d+) Spell Damage"); if v then est.spellDmg = est.spellDmg + v; end
    _,_,v = strfind(text, "%+(%d+) Spell Power");  if v then est.spellDmg = est.spellDmg + v; est.healing = est.healing + v; end
    _,_,v = strfind(text, "%+(%d+) Spell Damage and Healing"); if v then est.spellDmg = est.spellDmg + v; est.healing = est.healing + v; end
    _,_,v = strfind(text, "%+(%d+) damage and healing"); if v then est.spellDmg = est.spellDmg + v; est.healing = est.healing + v; end
    _,_,v = strfind(text, "%+(%d+) Healing"); if v then est.healing = est.healing + v; end
    _,_,v = strfind(text, "%+(%d+) to Healing Spells"); if v then est.healing = est.healing + v; end
    _,_,v = strfind(text, "%+(%d+) to Healing"); if v then est.healing = est.healing + v; end
    _,_,v = strfind(text, "[Ii]ncreases healing done by spells and effects by up to (%d+)"); if v then est.healing = est.healing + v; end
    _,_,v = strfind(text, "healing done by spells and effects by up to (%d+)"); if v then est.healing = est.healing + v; end
    _,_,v = strfind(text, "[Ii]ncreases damage done by magical spells and effects by up to (%d+)"); if v then est.spellDmg = est.spellDmg + v; end
    _,_,v = strfind(text, "damage done by magical spells and effects by up to (%d+)"); if v then est.spellDmg = est.spellDmg + v; end

    -- Crit % (Rallying Cry, Moonkin Aura, world buffs, etc.)
    _,_,v = strfind(text, "critical strike with spells by (%d+)%%");
    if v then est.critSpell = est.critSpell + v; end
    _,_,v = strfind(text, "[Ii]ncreases spell critical chance by (%d+)%%");
    if v then est.critSpell = est.critSpell + v; end
    _,_,v = strfind(text, "[Ii]ncreases critical strike chance by (%d+)%%");
    if v then est.critMelee = est.critMelee + v; est.critSpell = est.critSpell + v; end
    _,_,v = strfind(text, "critical strike by (%d+)%%");
    if v then est.critMelee = est.critMelee + v; end
    _,_,v = strfind(text, "critical hit chance by (%d+)%%");
    if v then est.critMelee = est.critMelee + v; est.critSpell = est.critSpell + v; end

    -- Mp5 (Blessing of Wisdom)
    _,_,v = strfind(text, "Restores (%d+) mana per 5"); if v then est.mp5 = est.mp5 + v; end
    _,_,v = strfind(text, "(%d+) mana every 5"); if v then est.mp5 = est.mp5 + v; end

    -- Armor (Inner Fire, Devotion Aura, Frost Armor, etc.)
    _,_,v = strfind(text, "[Ii]ncreases armor by (%d+)"); if v then est.armor = est.armor + v; end
    _,_,v = strfind(text, "%+(%d+) Armor"); if v then est.armor = est.armor + v; end

    -- Defense (Blessing of Sanctuary etc.)
    _,_,v = strfind(text, "%+(%d+) Defense"); if v then est.defense = est.defense + v; end

    -- Dodge (Cat form etc.)
    _,_,v = strfind(text, "chance to dodge by (%d+)%%"); if v then est.dodge = est.dodge + v; end
end

-- Walk every visible buff on the inspected unit and fold recognized stat
-- bonuses into `est`. Uses the standard UnitBuff / GameTooltip:SetUnitBuff
-- flow available in 1.12. Silently skipped if the APIs are unavailable.
local function RelationshipsDashboard_ScanInspectBuffs(est)
    if not est then return; end
    if not RelationshipsDashboardTooltip then return; end
    if not UnitBuff then return; end

    for i = 1, 32 do
        local buffTex = UnitBuff(RD_UNIT, i);
        if not buffTex then break; end
        RelationshipsDashboard_ResetTooltip();
        -- SetUnitBuff exists on 1.12 clients that support inspect; guard it.
        local ok = pcall(function()
            RelationshipsDashboardTooltip:SetUnitBuff(RD_UNIT, i);
        end);
        if ok then
            for j = 1, RelationshipsDashboardTooltip:NumLines() do
                local tl = getglobal("RelationshipsDashboardTooltipTextLeft" .. j);
                local text = tl and tl:GetText();
                RD_ParseBuffLineInto(est, text);
            end
        end
    end
end


-- Scan every equipped item on the inspected unit and sum up the stat bonuses
-- printed on their tooltips. Returns a table of accumulated values.
local function RelationshipsDashboard_ScanInspectGear()
    local est = {
        str = 0, agi = 0, sta = 0, int = 0, spi = 0, allStats = 0,
        armor = 0,
        resArcane = 0, resFire = 0, resNature = 0, resFrost = 0, resShadow = 0, allRes = 0,
        ap = 0, rap = 0,
        critMelee = 0, critSpell = 0, hitMelee = 0, hitSpell = 0,
        spellDmg = 0, healing = 0,
        defense = 0, dodge = 0, parry = 0, block = 0, blockValue = 0,
        mp5 = 0,
        mhMin = 0, mhMax = 0, mhSpeed = 0,
        ohMin = 0, ohMax = 0, ohSpeed = 0,
        rMin = 0, rMax = 0, rSpeed = 0,
    };

    if not RelationshipsDashboardTooltip then return est; end

    -- Parse a single tooltip text line and fold any recognized stat bonuses
    -- into `est`. `slotId` is passed through so weapon/ranged lines can be
    -- routed correctly. Kept local so both the item-body loop and the
    -- set-bonus loop can share exactly the same parsing (no divergence).
    local function parseStatLine(text, slotId)
        if not text then return; end
        local v;

        -- Primary attributes
        _,_,v = strfind(text, "%+(%d+) Strength");  if v then est.str = est.str + v; end
        _,_,v = strfind(text, "%+(%d+) Agility");   if v then est.agi = est.agi + v; end
        _,_,v = strfind(text, "%+(%d+) Stamina");   if v then est.sta = est.sta + v; end
        _,_,v = strfind(text, "%+(%d+) Intellect"); if v then est.int = est.int + v; end
        _,_,v = strfind(text, "%+(%d+) Spirit");    if v then est.spi = est.spi + v; end
        _,_,v = strfind(text, "%+(%d+) to All Stats"); if v then est.allStats = est.allStats + v; end
        if not v then _,_,v = strfind(text, "%+(%d+) All Stats"); if v then est.allStats = est.allStats + v; end end

        -- Armor
        _,_,v = strfind(text, "(%d+) Armor");
        if v and not strfind(text, "Penetration") then est.armor = est.armor + v; end

        -- Resistances
        _,_,v = strfind(text, "%+(%d+) Arcane Resistance"); if v then est.resArcane = est.resArcane + v; end
        _,_,v = strfind(text, "%+(%d+) Fire Resistance");   if v then est.resFire = est.resFire + v; end
        _,_,v = strfind(text, "%+(%d+) Nature Resistance"); if v then est.resNature = est.resNature + v; end
        _,_,v = strfind(text, "%+(%d+) Frost Resistance");  if v then est.resFrost = est.resFrost + v; end
        _,_,v = strfind(text, "%+(%d+) Shadow Resistance"); if v then est.resShadow = est.resShadow + v; end
        _,_,v = strfind(text, "%+(%d+) to All Resistances"); if v then est.allRes = est.allRes + v; end
        if not v then _,_,v = strfind(text, "%+(%d+) All Resistances"); if v then est.allRes = est.allRes + v; end end

        -- Attack power (ranged first)
        _,_,v = strfind(text, "ranged attack power by (%d+)");
        if v then
            est.rap = est.rap + v;
        else
            _,_,v = strfind(text, "attack power by (%d+)"); if v then est.ap = est.ap + v; end
            _,_,v = strfind(text, "%+(%d+) Attack Power");  if v then est.ap = est.ap + v; end
        end

        -- Crit
        _,_,v = strfind(text, "critical strike with spells by (%d+)%%");
        if v then
            est.critSpell = est.critSpell + v;
        else
            _,_,v = strfind(text, "critical strike by (%d+)%%"); if v then est.critMelee = est.critMelee + v; end
        end

        -- Hit
        _,_,v = strfind(text, "chance to hit with spells by (%d+)%%");
        if v then
            est.hitSpell = est.hitSpell + v;
        else
            _,_,v = strfind(text, "chance to hit by (%d+)%%"); if v then est.hitMelee = est.hitMelee + v; end
        end

        -- Spell damage / healing
        _,_,v = strfind(text, "damage and healing done by magical spells and effects by up to (%d+)");
        if v then
            est.spellDmg = est.spellDmg + v;
            est.healing = est.healing + v;
        else
            _,_,v = strfind(text, "damage done by magical spells and effects by up to (%d+)");
            if v then est.spellDmg = est.spellDmg + v; end
            _,_,v = strfind(text, "healing done by spells and effects by up to (%d+)");
            if v then est.healing = est.healing + v; end
            _,_,v = strfind(text, "healing spells by up to (%d+)");
            if v then est.healing = est.healing + v; end
            _,_,v = strfind(text, "%+(%d+) Healing"); if v then est.healing = est.healing + v; end
            _,_,v = strfind(text, "%+(%d+) to Healing Spells"); if v then est.healing = est.healing + v; end
            _,_,v = strfind(text, "%+(%d+) to Healing"); if v then est.healing = est.healing + v; end
            _,_,v = strfind(text, "%+(%d+) Spell Damage"); if v then est.spellDmg = est.spellDmg + v; end
            _,_,v = strfind(text, "%+(%d+) Spell Damage and Healing"); if v then est.spellDmg = est.spellDmg + v; est.healing = est.healing + v; end
            _,_,v = strfind(text, "%+(%d+) damage and healing"); if v then est.spellDmg = est.spellDmg + v; est.healing = est.healing + v; end
            _,_,v = strfind(text, "%+(%d+) Spell Power");  if v then est.spellDmg = est.spellDmg + v; est.healing = est.healing + v; end
            _,_,v = strfind(text, "%+(%d+) Fire Damage");   if v then est.spellDmg = est.spellDmg + v; end
            _,_,v = strfind(text, "%+(%d+) Frost Damage");  if v then est.spellDmg = est.spellDmg + v; end
            _,_,v = strfind(text, "%+(%d+) Arcane Damage"); if v then est.spellDmg = est.spellDmg + v; end
            _,_,v = strfind(text, "%+(%d+) Shadow Damage"); if v then est.spellDmg = est.spellDmg + v; end
            _,_,v = strfind(text, "%+(%d+) Nature Damage"); if v then est.spellDmg = est.spellDmg + v; end
            _,_,v = strfind(text, "%+(%d+) Holy Damage");   if v then est.spellDmg = est.spellDmg + v; end
            _,_,v = strfind(text, "Damage Bonus: (%d+)"); if v then est.spellDmg = est.spellDmg + v; end
        end

        -- Defense
        _,_,v = strfind(text, "%+(%d+) Defense");        if v then est.defense = est.defense + v; end
        _,_,v = strfind(text, "Increased Defense %+(%d+)"); if v then est.defense = est.defense + v; end

        -- Dodge / Parry / Block
        _,_,v = strfind(text, "chance to dodge an attack by (%d+)%%"); if v then est.dodge = est.dodge + v; end
        _,_,v = strfind(text, "%+(%d+)%% Dodge"); if v then est.dodge = est.dodge + v; end
        _,_,v = strfind(text, "chance to parry an attack by (%d+)%%"); if v then est.parry = est.parry + v; end
        _,_,v = strfind(text, "%+(%d+)%% Parry"); if v then est.parry = est.parry + v; end
        _,_,v = strfind(text, "chance to block attacks with a shield by (%d+)%%"); if v then est.block = est.block + v; end
        _,_,v = strfind(text, "block value of your shield by (%d+)"); if v then est.blockValue = est.blockValue + v; end

        -- Mana per 5
        _,_,v = strfind(text, "Restores (%d+) mana per 5"); if v then est.mp5 = est.mp5 + v; end
        if not v then _,_,v = strfind(text, "%+(%d+) mana per 5"); if v then est.mp5 = est.mp5 + v; end end
        if not v then _,_,v = strfind(text, "(%d+) [Mm]ana [Pp]er 5"); if v then est.mp5 = est.mp5 + v; end end
        if not v then _,_,v = strfind(text, "(%d+) mana every 5"); if v then est.mp5 = est.mp5 + v; end end

        -- Turtle/1.12 additional tooltip variants
        _,_,v = strfind(text, "[Ii]ncreases healing done by .- up to (%d+)");
        if v then est.healing = est.healing + v; end
        _,_,v = strfind(text, "%+(%d+) [Ss]pell [Cc]rit");
        if v then est.critSpell = est.critSpell + v; end
        _,_,v = strfind(text, "%+(%d+)%% [Ss]pell [Cc]rit");
        if v then est.critSpell = est.critSpell + v; end
        _,_,v = strfind(text, "[Ii]ncreases attack power in Cat, Bear.- forms by (%d+)");
        if v then est.ap = est.ap + v; end   -- Druid feral AP
        _,_,v = strfind(text, "Feral Attack Power[:%s]+(%d+)");
        if v then est.ap = est.ap + v; end
        -- Turtle common enchant / item phrasing without "Equip:" prefix
        _,_,v = strfind(text, "%+(%d+) [Ww]eapon [Dd]amage");
        if v and (slotId == 16 or slotId == 17 or slotId == 18) then
            if slotId == 16 then est.mhMin = est.mhMin + v; est.mhMax = est.mhMax + v;
            elseif slotId == 17 then est.ohMin = est.ohMin + v; est.ohMax = est.ohMax + v;
            else est.rMin = est.rMin + v; est.rMax = est.rMax + v; end
        end
        _,_,v = strfind(text, "Increases the block value of your shield by (%d+)");
        if v then est.blockValue = est.blockValue + v; end

        -- Weapon / ranged damage + speed (only for the weapon slots)
        if slotId == 16 or slotId == 17 or slotId == 18 then
            local _, _, dMin, dMax = strfind(text, "(%d+) %- (%d+) Damage");
            local _, _, spd = strfind(text, "Speed (%d+%.%d+)");
            if slotId == 16 then
                if dMin then est.mhMin = tonumber(dMin); est.mhMax = tonumber(dMax); end
                if spd then est.mhSpeed = tonumber(spd); end
            elseif slotId == 17 then
                if dMin then est.ohMin = tonumber(dMin); est.ohMax = tonumber(dMax); end
                if spd then est.ohSpeed = tonumber(spd); end
            else
                if dMin then est.rMin = tonumber(dMin); est.rMax = tonumber(dMax); end
                if spd then est.rSpeed = tonumber(spd); end
            end
        end
    end

    -- Sets whose bonuses we have already folded in. Each set's bonus lines
    -- are printed on EVERY equipped piece's tooltip, so we must apply them
    -- exactly once per set no matter how many pieces the target wears.
    local processedSets = {};

    for i = 1, table.getn(EQUIPMENT_SLOTS) do
        local slotId = EQUIPMENT_SLOTS[i];
        local itemLink = GetInventoryItemLink(RD_UNIT, slotId);
        if itemLink then
            RelationshipsDashboard_ResetTooltip();
            RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, slotId);

            local inSet = false;         -- currently inside a set block?
            local setSkip = false;       -- skip stats for this block?
            local setEquipped = 0;       -- how many pieces of this set are equipped
            for j = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. j);
                local text = textLine and textLine:GetText();
                if text then
                    -- Set header of the form "SetName (equipped/total)".
                    -- Also matches "Set: SetName (equipped/total)".
                    local _, _, eqStr, totStr = strfind(text, "%((%d+)/(%d+)%)");
                    if eqStr and totStr then
                        inSet = true;
                        setEquipped = tonumber(eqStr) or 0;
                        -- Derive a stable set name key by stripping the count.
                        local name = gsub(text, "%s*%(%d+/%d+%)%s*$", "");
                        name = gsub(name, "^%s*[Ss]et:%s*", "");
                        name = gsub(name, "^%s+", "");
                        name = gsub(name, "%s+$", "");
                        if name == "" then name = "unnamed"; end
                        if processedSets[name] then
                            setSkip = true;
                        else
                            processedSets[name] = true;
                            setSkip = false;
                        end
                        -- Header line itself carries no stats.
                    elseif inSet then
                        -- Inside a set block. Bonus lines can look like:
                        --   "(3) +25 Strength"
                        --   "(3) Set: +25 Strength"
                        --   "  Set: (3) +25 Strength"
                        --   "Set 3: +25 Strength"           (Turtle/custom)
                        -- Piece-list lines have no "(N)" marker.
                        --
                        -- Detection strategy:
                        --   1) If we can find a required-piece count anywhere
                        --      in the line, treat it as a bonus line and apply
                        --      when the target has enough pieces equipped.
                        --   2) As a fallback (in case a tooltip format hides
                        --      the count), use the FontString color: vanilla
                        --      renders ACTIVE set bonus lines in green
                        --      (~0,1,0) and inactive ones in gray (~0.5s).
                        --      Green => apply, gray => skip. This makes us
                        --      robust to header/format differences on
                        --      Turtle WoW / OctoWoW where the plain regex
                        --      previously dropped every set bonus during
                        --      inspect.
                        local _, _, reqStr = strfind(text, "%((%d+)%)");
                        if not reqStr then
                            _,_,reqStr = strfind(text, "[Ss]et%s+(%d+)%s*:");
                        end

                        local isBonus = false;
                        local active = false;
                        if reqStr then
                            isBonus = true;
                            local req = tonumber(reqStr) or 99;
                            active = req <= setEquipped;
                        end

                        -- Color-based override / fallback. GetTextColor() may
                        -- not exist on very old clients — pcall for safety.
                        local ok, r, g, b = pcall(function()
                            return textLine:GetTextColor();
                        end);
                        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                            -- Green = active set bonus.
                            if g > 0.6 and r < 0.4 and b < 0.4 then
                                isBonus = true;
                                active = true;
                            -- Gray = inactive set bonus (only override when we
                            -- already thought it was a bonus line).
                            elseif isBonus and r > 0.4 and r < 0.7
                                and g > 0.4 and g < 0.7
                                and b > 0.4 and b < 0.7
                                and math.abs(r - g) < 0.1 and math.abs(g - b) < 0.1 then
                                active = false;
                            end
                        end

                        if isBonus and active and not setSkip then
                            parseStatLine(text, slotId);
                        end
                    else
                        -- Normal item body line.
                        parseStatLine(text, slotId);
                    end
                end
            end
        end
    end



    -- Fold "all stats" / "all resistances" into the individual buckets.
    if est.allStats > 0 then
        est.str = est.str + est.allStats; est.agi = est.agi + est.allStats;
        est.sta = est.sta + est.allStats; est.int = est.int + est.allStats;
        est.spi = est.spi + est.allStats;
    end
    if est.allRes > 0 then
        est.resArcane = est.resArcane + est.allRes; est.resFire = est.resFire + est.allRes;
        est.resNature = est.resNature + est.allRes; est.resFrost = est.resFrost + est.allRes;
        est.resShadow = est.resShadow + est.allRes;
    end

    return est;
end

-- Helper: format an estimated number.
local function RD_EstNum(n)
    return tostring(floor(n + 0.5));
end

-- Helper: format an estimated percentage.
local function RD_EstPct(n)
    return string.format("%.1f%%", n);
end

-- Populate every dashboard row with estimates derived from the inspected
-- unit's equipped gear and level. Called from UpdateStats when RD_UNIT is not
-- "player".
function RelationshipsDashboard_UpdateStatsInspect()
    local _, class = UnitClass(RD_UNIT);
    class = class or "WARRIOR";
    local level = UnitLevel(RD_UNIT) or 1;
    if level < 1 then level = 1; end

    local est = RelationshipsDashboard_ScanInspectGear();

    -- Fold active buffs on the target into the same estimate bucket. This
    -- covers Mark/Gift of the Wild, PW:Fortitude, Divine Spirit, Arcane
    -- Intellect, Blessing of Kings/Might/Wisdom, Battle Shout, Trueshot
    -- Aura, Shadow/Nature/etc. Protection, Inner Fire, and similar. The
    -- personal panel gets these automatically via UnitStat; inspect does
    -- not, so we parse buff tooltips. Re-fold allStats/allRes afterwards
    -- because Gift of the Wild etc. add to those buckets.
    local buffAllStatsBefore = est.allStats;
    local buffAllResBefore   = est.allRes;
    RelationshipsDashboard_ScanInspectBuffs(est);
    local dAll = est.allStats - buffAllStatsBefore;
    if dAll > 0 then
        est.str = est.str + dAll; est.agi = est.agi + dAll;
        est.sta = est.sta + dAll; est.int = est.int + dAll;
        est.spi = est.spi + dAll;
    end
    local dRes = est.allRes - buffAllResBefore;
    if dRes > 0 then
        est.resArcane = est.resArcane + dRes; est.resFire = est.resFire + dRes;
        est.resNature = est.resNature + dRes; est.resFrost = est.resFrost + dRes;
        est.resShadow = est.resShadow + dRes;
    end


    -- Base primary stats scaled by level, plus per-race offset, plus gear.
    local anchors = RD_BASE_STATS_60[class] or RD_BASE_STATS_60.WARRIOR;
    local _, raceKey = UnitRace(RD_UNIT);
    if not raceKey then raceKey = UnitRace(RD_UNIT) or "Human"; end
    -- Normalize race key: strip spaces (e.g. "Night Elf" -> "NightElf") and
    -- collapse to the table's naming.
    if raceKey then raceKey = gsub(raceKey, "%s+", ""); end
    local raceMods = RD_RACE_MODS_60[raceKey] or RD_RACE_MODS_60.Human;
    -- Vanilla base stats don't grow linearly from level 1. Blizzard's
    -- curve is roughly quadratic: growth per level starts small and
    -- accelerates. Fit: at L1 primaries are ~20, at L60 they match the
    -- class anchor. Approximate with (L-1)/59 raised to ~1.4 so mid-level
    -- (30-45) values match Turtle character sheets more closely than
    -- straight linear scaling did.
    local function baseStat(idx)
        local anchor = anchors[idx] + (raceMods[idx] or 0);
        if level >= 60 then return anchor; end
        local low = 20;                          -- level-1 baseline
        if anchor < low then low = anchor; end
        local t = (level - 1) / 59;              -- 0..1
        if t < 0 then t = 0; end
        -- power curve; exp=1.35 matches vanilla growth within a couple points
        local frac = t ^ 1.35;
        local b = floor(low + (anchor - low) * frac + 0.5);
        if b < 1 then b = 1; end
        return b;
    end
    local totStr = baseStat(1) + est.str;
    local totAgi = baseStat(2) + est.agi;
    local totSta = baseStat(3) + est.sta;
    local totInt = baseStat(4) + est.int;
    local totSpi = baseStat(5) + est.spi;

    -- Passive racial resistances (Dwarf +10 Frost, Gnome +10 Arcane,
    -- Undead +10 Shadow, NightElf/Tauren/Troll +10 Nature, etc.).
    local raceRes = RD_RACE_RES[raceKey];
    if raceRes then
        est.resArcane = est.resArcane + (raceRes.arcane or 0);
        est.resFire   = est.resFire   + (raceRes.fire   or 0);
        est.resNature = est.resNature + (raceRes.nature or 0);
        est.resFrost  = est.resFrost  + (raceRes.frost  or 0);
        est.resShadow = est.resShadow + (raceRes.shadow or 0);
    end
    -- Passive racial dodge (Night Elf Quickness = +1%).
    est.dodge = est.dodge + (RD_RACE_DODGE[raceKey] or 0);


    -- ==== General ====
    -- Health and mana ARE visible for a target, so use the real values.
    local health = UnitHealth(RD_UNIT);
    local maxHealth = UnitHealthMax(RD_UNIT);
    if maxHealth and maxHealth > 0 then
        RelationshipsDashboardHealthRowValue:SetText(health .. " / " .. maxHealth);
    else
        RelationshipsDashboardHealthRowValue:SetText("--");
    end
    RelationshipsDashboardHealthRowValue:SetTextColor(0.2, 1, 0.2);

    local powerType = UnitPowerType(RD_UNIT);
    local power = UnitMana(RD_UNIT);
    local maxPower = UnitManaMax(RD_UNIT);
    if powerType == 1 then RelationshipsDashboardPowerRowLabel:SetText("Rage:");
    elseif powerType == 2 then RelationshipsDashboardPowerRowLabel:SetText("Focus:");
    elseif powerType == 3 then RelationshipsDashboardPowerRowLabel:SetText("Energy:");
    else RelationshipsDashboardPowerRowLabel:SetText("Mana:"); end
    if maxPower and maxPower > 0 then
        RelationshipsDashboardPowerRowValue:SetText(power .. " / " .. maxPower);
    else
        RelationshipsDashboardPowerRowValue:SetText("--");
    end
    RelationshipsDashboardPowerRowValue:SetTextColor(0.3, 0.6, 1);

    if RelationshipsDashboard_ClassUsesMana() and powerType ~= 0 then
        RelationshipsDashboardManaRowLabel:SetText("Mana:");
        RelationshipsDashboardManaRowValue:SetText("--");
        RelationshipsDashboardManaRowValue:SetTextColor(0.3, 0.6, 1);
    end

    -- Armor = item armor + Agility contribution (2 per Agi in vanilla).
    local armorEst = est.armor + totAgi * 2;
    RelationshipsDashboardArmorRowValue:SetText(RD_EstNum(armorEst));
    RelationshipsDashboardArmorRowValue:SetTextColor(1, 1, 1);

    -- Movement / durability / repair are not knowable for another player.
    RelationshipsDashboardMovementRowValue:SetText("--");
    RelationshipsDashboardDurabilityRowValue:SetText("--");
    RelationshipsDashboardDurabilityRowValue:SetTextColor(1, 1, 1);
    RelationshipsDashboardRepairCostRowValue:SetText("--");

    -- GearScore + average item level work off the target's gear directly.
    local gearScore, avgILvl = RelationshipsDashboard_CalculateGearScore();
    if gearScore and gearScore > 0 then
        RelationshipsDashboardGearScoreRowValue:SetText(tostring(gearScore));
    else
        RelationshipsDashboardGearScoreRowValue:SetText("--");
    end
    if gearScore >= 3500 then RelationshipsDashboardGearScoreRowValue:SetTextColor(1, 0.5, 0);
    elseif gearScore >= 2000 then RelationshipsDashboardGearScoreRowValue:SetTextColor(0.8, 0.2, 1);
    elseif gearScore >= 1200 then RelationshipsDashboardGearScoreRowValue:SetTextColor(0, 0.44, 0.87);
    elseif gearScore >= 500 then RelationshipsDashboardGearScoreRowValue:SetTextColor(0.12, 1, 0);
    else RelationshipsDashboardGearScoreRowValue:SetTextColor(1, 1, 1); end
    if avgILvl and avgILvl > 0 then
        RelationshipsDashboardAvgILvlRowValue:SetText(string.format("%.1f", avgILvl));
    else
        RelationshipsDashboardAvgILvlRowValue:SetText("--");
    end

    -- ==== Attributes ====
    RelationshipsDashboardStrengthRowValue:SetText(RD_EstNum(totStr));
    RelationshipsDashboardAgilityRowValue:SetText(RD_EstNum(totAgi));
    RelationshipsDashboardStaminaRowValue:SetText(RD_EstNum(totSta));
    RelationshipsDashboardIntellectRowValue:SetText(RD_EstNum(totInt));
    RelationshipsDashboardSpiritRowValue:SetText(RD_EstNum(totSpi));

    -- ==== Offense ====
    -- Melee attack power by class formula.
    local ap;
    if class == "WARRIOR" or class == "PALADIN" then ap = level * 3 + totStr * 2 - 20;
    elseif class == "SHAMAN" then ap = level * 2 + totStr * 2 - 20;
    elseif class == "DRUID" then ap = totStr * 2 - 20;
    elseif class == "ROGUE" or class == "HUNTER" then ap = level * 2 + totStr + totAgi - 20;
    else ap = totStr - 10; end
    if ap < 0 then ap = 0; end
    ap = ap + est.ap;
    est.apTotal = ap;

    -- Melee damage: weapon base + AP contribution (AP/14 per second).
    if est.mhSpeed > 0 and est.mhMax > 0 then
        local swingBonus = (ap / 14) * est.mhSpeed;
        local effMin = est.mhMin + swingBonus;
        local effMax = est.mhMax + swingBonus;
        RelationshipsDashboardMeleeDmgRowValue:SetText(floor(effMin) .. " - " .. floor(effMax));
        RelationshipsDashboardWeaponDPSRowValue:SetText(string.format("%.1f", (effMin + effMax) / 2 / est.mhSpeed));
    else
        RelationshipsDashboardMeleeDmgRowValue:SetText("--");
        RelationshipsDashboardWeaponDPSRowValue:SetText("--");
    end

    RelationshipsDashboardMeleeAPRowValue:SetText(RD_EstNum(ap));

    if est.mhSpeed > 0 then
        if est.ohSpeed > 0 then
            RelationshipsDashboardMeleeSpeedRowValue:SetText(RelationshipsDashboard_FormatDecimal(est.mhSpeed) .. " / " .. RelationshipsDashboard_FormatDecimal(est.ohSpeed));
        else
            RelationshipsDashboardMeleeSpeedRowValue:SetText(RelationshipsDashboard_FormatDecimal(est.mhSpeed));
        end
    else
        RelationshipsDashboardMeleeSpeedRowValue:SetText("--");
    end

    -- Weapon skill: player skill API is unavailable for a target, so show the
    -- level cap (level * 5).
    RelationshipsDashboardWeaponSkillRowValue:SetText(tostring(level * 5) .. " (max)");

    RelationshipsDashboardMeleeHitRowValue:SetText(RD_EstPct(est.hitMelee));

    local agiPerCrit = RD_AGI_PER_CRIT[class] or 20;
    local meleeCrit = 5 + totAgi / agiPerCrit + est.critMelee;
    RelationshipsDashboardMeleeCritRowValue:SetText(RD_EstPct(meleeCrit));

    -- Ranged Attack Power (Turtle/1.12): Hunters get level*2 + Agi*2 - 20
    -- (2 RAP per Agility, not 1); other classes just use Agility - 10.
    local rap;
    if class == "HUNTER" then rap = level * 2 + totAgi * 2 - 20;
    else rap = totAgi - 10; end
    if rap < 0 then rap = 0; end
    rap = rap + est.rap;
    RelationshipsDashboardRangedAPRowValue:SetText(RD_EstNum(rap));

    -- Ranged crit: base 5% + Agi/agiPerCrit + gear ranged crit (falls back
    -- to melee crit bucket because most 1.12 items list a single crit stat).
    local rangedCrit = 5 + totAgi / agiPerCrit + est.critMelee;
    RelationshipsDashboardRangedCritRowValue:SetText(RD_EstPct(rangedCrit));

    if est.rSpeed > 0 then
        RelationshipsDashboardRangedSpeedRowValue:SetText(RelationshipsDashboard_FormatDecimal(est.rSpeed));
    else
        RelationshipsDashboardRangedSpeedRowValue:SetText("--");
    end
    if est.rMax > 0 then
        RelationshipsDashboardRangedDmgRowValue:SetText(est.rMin .. " - " .. est.rMax);
    else
        RelationshipsDashboardRangedDmgRowValue:SetText("--");
    end

    RelationshipsDashboardSpellPowerRowValue:SetText(RD_EstNum(est.spellDmg));
    RelationshipsDashboardHealingPowerRowValue:SetText(RD_EstNum(est.healing));
    RelationshipsDashboardSpellHitRowValue:SetText(RD_EstPct(est.hitSpell));

    -- Spell crit per Intellect varies by class in vanilla/Turtle.
    -- Values are Int-per-1%-crit at level 60.
    local intPerSpellCrit;
    if class == "MAGE"    then intPerSpellCrit = 59.5;
    elseif class == "PRIEST"  then intPerSpellCrit = 59.2;
    elseif class == "WARLOCK" then intPerSpellCrit = 60.6;
    elseif class == "DRUID"   then intPerSpellCrit = 60.0;
    elseif class == "SHAMAN"  then intPerSpellCrit = 59.2;
    elseif class == "PALADIN" then intPerSpellCrit = 54.0;
    else intPerSpellCrit = 60.0; end
    local spellCrit = 5 + totInt / intPerSpellCrit + est.critSpell;
    RelationshipsDashboardSpellCritRowValue:SetText(RD_EstPct(spellCrit));

    -- Mana regen: spirit-based (if a mana class) + gear mp5.
    local spiritFactor = 0;
    if class == "PRIEST" or class == "MAGE" or class == "DRUID" then spiritFactor = 0.125;
    elseif class == "WARLOCK" or class == "SHAMAN" or class == "PALADIN" then spiritFactor = 0.1; end
    local manaRegen = 0;
    if spiritFactor > 0 then manaRegen = totSpi * spiritFactor / 2; end
    manaRegen = manaRegen + est.mp5 / 5;
    if manaRegen > 0 then
        RelationshipsDashboardManaRegenRowValue:SetText(string.format("%.1f/s", manaRegen));
    else
        RelationshipsDashboardManaRegenRowValue:SetText("--");
    end

    -- ==== Defenses ====
    local defense = level * 5 + est.defense;
    RelationshipsDashboardDefenseRowValue:SetText(RD_EstNum(defense));

    local dodge = totAgi / agiPerCrit + est.dodge;
    RelationshipsDashboardDodgeRowValue:SetText(RD_EstPct(dodge));

    if RD_CAN_PARRY[class] then
        RelationshipsDashboardParryRowValue:SetText(RD_EstPct(5 + est.parry));
    else
        RelationshipsDashboardParryRowValue:SetText("--");
    end

    if est.block > 0 or est.blockValue > 0 then
        RelationshipsDashboardBlockRowValue:SetText(RD_EstPct(est.block));
    else
        RelationshipsDashboardBlockRowValue:SetText("--");
    end

    -- Avoidance: rough miss (5%) + dodge + parry + block.
    local avoidance = 5 + dodge + (RD_CAN_PARRY[class] and (5 + est.parry) or 0) + est.block;
    RelationshipsDashboardAvoidanceRowValue:SetText(RD_EstPct(avoidance));

    -- ==== Resistances ====
    RelationshipsDashboardArcaneResRowValue:SetText(RD_EstNum(est.resArcane));
    RelationshipsDashboardFireResRowValue:SetText(RD_EstNum(est.resFire));
    RelationshipsDashboardNatureResRowValue:SetText(RD_EstNum(est.resNature));
    RelationshipsDashboardFrostResRowValue:SetText(RD_EstNum(est.resFrost));
    RelationshipsDashboardShadowResRowValue:SetText(RD_EstNum(est.resShadow));

    -- Apply class-specific visibility (hide irrelevant stats).
    RelationshipsDashboard_ApplyClassVisibility();
end

-------------------------------------------------------------------------------
-- Update throttling / coalescing.
--
-- RelationshipsDashboard_UpdateStats_Impl() is the heavy per-frame refresh
-- (iterates every equipment slot, scans tooltips for durability, walks buffs,
-- computes GearScore and repair costs). Vanilla WoW fires the events that
-- trigger it (UNIT_HEALTH, UNIT_MANA, UNIT_INVENTORY_CHANGED, PLAYER_MONEY,
-- etc.) in dense bursts — sometimes many per frame — which produces a
-- visible frame-time spike each time the panel is open.
--
-- To fix that we split UpdateStats into two entry points:
--   * RelationshipsDashboard_UpdateStats()    -> mark dirty, defer to next tick
--   * RelationshipsDashboard_UpdateStatsNow() -> run immediately (used when
--                                                the panel first opens so the
--                                                user never sees stale data)
--
-- The OnUpdate handler flushes at most once per RD_UPDATE_THROTTLE seconds,
-- which collapses a whole burst of events into a single refresh.
-------------------------------------------------------------------------------
local RD_UPDATE_THROTTLE = 0.15;   -- seconds between coalesced refreshes
RD_StatsDirty = false;
RD_StatsLastUpdate = 0;
RD_StatsAccum = 0;

function RelationshipsDashboard_UpdateStatsNow()
    RD_StatsDirty = false;
    RD_StatsAccum = 0;
    RelationshipsDashboard_UpdateStats_Impl();
end

function RelationshipsDashboard_UpdateStats()
    if not RelationshipsDashboardFrame:IsVisible() then
        return;
    end
    -- Defer: OnUpdate will flush this within RD_UPDATE_THROTTLE seconds.
    RD_StatsDirty = true;
end

function RelationshipsDashboard_FlushPendingStats(elapsed)
    if not RD_StatsDirty then return; end
    RD_StatsAccum = RD_StatsAccum + (elapsed or 0);
    if RD_StatsAccum < RD_UPDATE_THROTTLE then return; end
    RD_StatsAccum = 0;
    RD_StatsDirty = false;
    if RelationshipsDashboardFrame:IsVisible() then
        RelationshipsDashboard_UpdateStats_Impl();
    end
end

function RelationshipsDashboard_UpdateStats_Impl()

    if not RelationshipsDashboardFrame:IsVisible() then
        return;
    end

    -- Update title text to reflect the unit being displayed
    if RelationshipsDashboardTitleText then
        local uName = UnitName(RD_UNIT);
        if RD_UNIT == "player" or not uName or uName == "" then
            RelationshipsDashboardTitleText:SetText("Character Dashboard");
        else
            local _, uClass = UnitClass(RD_UNIT);
            local uLevel = UnitLevel(RD_UNIT);
            local lvlStr = (uLevel and uLevel > 0) and (" (Lvl " .. uLevel .. ")") or "";
            RelationshipsDashboardTitleText:SetText(uName .. lvlStr .. (uClass and (" - " .. uClass) or ""));
        end
    end

    -- When inspecting another player, the client does not expose their computed
    -- stats. Estimate everything from their equipped gear + level instead.
    if RD_UNIT ~= "player" then
        RelationshipsDashboard_UpdateStatsInspect();
        return;
    end

    -- ==== Section: General ====
    -- Health
    local health = UnitHealth(RD_UNIT);
    local maxHealth = UnitHealthMax(RD_UNIT);
    if maxHealth > 0 then
        RelationshipsDashboardHealthRowValue:SetText(health .. " / " .. maxHealth);
    else
        RelationshipsDashboardHealthRowValue:SetText("--");
    end
    RelationshipsDashboardHealthRowValue:SetTextColor(0.2, 1, 0.2);

    -- Power (Mana/Rage/Energy)
    -- When a mana-capable class is in a non-mana form (e.g., druid bear/cat),
    -- PowerRow shows the form's power (Rage/Energy), and ManaRow shows base Mana.
    local powerType = UnitPowerType(RD_UNIT);
    local power = UnitMana(RD_UNIT);
    local maxPower = UnitManaMax(RD_UNIT);
    local classUsesMana = RelationshipsDashboard_ClassUsesMana();

    -- Track mana values when in caster form for use when shifted
    if powerType == 0 then
        -- Currently in caster form with mana bar visible
        RelationshipsDashboard_LastKnownMana = power;
        RelationshipsDashboard_LastKnownMaxMana = maxPower;
    end

    if powerType == 1 then
        RelationshipsDashboardPowerRowLabel:SetText("Rage:");
        RelationshipsDashboardPowerRowValue:SetText(power .. " / " .. maxPower);
        RelationshipsDashboardPowerRowValue:SetTextColor(1, 0.2, 0.2);
    elseif powerType == 2 then
        RelationshipsDashboardPowerRowLabel:SetText("Focus:");
        RelationshipsDashboardPowerRowValue:SetText(power .. " / " .. maxPower);
        RelationshipsDashboardPowerRowValue:SetTextColor(1, 0.8, 0);
    elseif powerType == 3 then
        RelationshipsDashboardPowerRowLabel:SetText("Energy:");
        RelationshipsDashboardPowerRowValue:SetText(power .. " / " .. maxPower);
        RelationshipsDashboardPowerRowValue:SetTextColor(1, 1, 0);
    else
        RelationshipsDashboardPowerRowLabel:SetText("Mana:");
        if maxPower > 0 then
            RelationshipsDashboardPowerRowValue:SetText(power .. " / " .. maxPower);
        else
            RelationshipsDashboardPowerRowValue:SetText("--");
        end
        RelationshipsDashboardPowerRowValue:SetTextColor(0.3, 0.6, 1);
    end

    -- ManaRow: Show base mana for mana-capable classes in non-mana forms
    -- (e.g., druid in bear/cat form shows Rage/Energy on PowerRow + Mana on ManaRow)
    -- When already in caster form, ManaRow is hidden by ApplyClassVisibility
    if classUsesMana and powerType ~= 0 then
        local mana = RelationshipsDashboard_LastKnownMana or 0;
        local maxMana = RelationshipsDashboard_LastKnownMaxMana or 0;
        -- Try to get current mana directly (some vanilla clients allow this)
        -- UnitMana with powerType 0 doesn't work when shifted, so use stored values
        RelationshipsDashboardManaRowLabel:SetText("Mana:");
        if maxMana > 0 then
            RelationshipsDashboardManaRowValue:SetText(mana .. " / " .. maxMana);
        else
            RelationshipsDashboardManaRowValue:SetText("--");
        end
        RelationshipsDashboardManaRowValue:SetTextColor(0.3, 0.6, 1);
    end

    -- Armor
    local baseArmor, effectiveArmor, armorBonus, posBuff, negBuff = UnitArmor(RD_UNIT);
    if effectiveArmor then
        if armorBonus and armorBonus ~= 0 then
            RelationshipsDashboardArmorRowValue:SetText(effectiveArmor .. " (+" .. armorBonus .. ")");
        else
            RelationshipsDashboardArmorRowValue:SetText(tostring(effectiveArmor));
        end
    elseif baseArmor then
        RelationshipsDashboardArmorRowValue:SetText(tostring(baseArmor));
    else
        RelationshipsDashboardArmorRowValue:SetText("--");
    end

    -- Movement Speed
    -- GetUnitSpeed() does NOT exist in vanilla 1.12 / TurtleWoW / OctoWoW
    -- Calculate movement speed from known speed-boosting buffs instead
    local speedPct = 100; -- Base run speed = 7 yards/sec = 100%
    local _, playerClass = UnitClass(RD_UNIT);

    -- Check for speed-increasing buffs by spell name
    -- Ghost Wolf (Shaman): 40% bonus = 140%
    -- Aspect of the Cheetah (Hunter): 30% bonus = 130%
    -- Aspect of the Pack (Hunter): 30% bonus = 130%
    -- Sprint (Rogue): 70% bonus = 170%
    -- Dash (Druid cat): 70% bonus = 170%
    -- Travel Form (Druid): 40% bonus = 140%
    -- Cheeta (Druid travel): 40% bonus = 140%
    -- Sprint (item/enchant): minor bonus
    -- Swiftness potions: 50% bonus = 150%
    -- Carrot on a Stick: 3% mounted bonus
    -- Mithril Spurs: 4% mounted bonus
    -- Riding enchant: 2% mounted bonus
    -- Nifty Stopwatch: 5% bonus

    -- Check if mounted (mount speed varies by riding skill)
    local isMounted = false;
    for i = 1, 32 do
        local texture, applications, spellName = UnitBuff(RD_UNIT, i);
        if not texture then break; end
        if spellName then
            -- Mount detection
            if strfind(spellName, "Mount") or strfind(spellName, "Steed") or
               strfind(spellName, "Charger") or strfind(spellName, "Warhorse") or
               strfind(spellName, "Kodo") or strfind(spellName, "Mechanostrider") or
               strfind(spellName, "Ram") or strfind(spellName, "Tiger") or
               strfind(spellName, "Wolf") or strfind(spellName, "Raptor") or
               strfind(spellName, "Skeletal") or strfind(spellName, "Frostsaber") or
               strfind(spellName, "Nightsaber") or strfind(spellName, "Horse") or
               strfind(spellName, "Palomino") or strfind(spellName, "Pinto") or
               strfind(spellName, "Stallion") or strfind(spellName, "Mare") then
                isMounted = true;
                speedPct = 160; -- Epic mount = 100% bonus (200% total = 160% of base run)
                -- Check for standard vs epic mount: we can't easily distinguish
                -- Default to showing 200% for epic mount speed
                speedPct = 200;
                break;
            end
        end
    end

    if not isMounted then
        -- Check for speed-boosting buffs
        for i = 1, 32 do
            local texture, applications, spellName = UnitBuff(RD_UNIT, i);
            if not texture then break; end
            if spellName then
                -- Shaman: Ghost Wolf = 140% speed
                if spellName == "Ghost Wolf" then speedPct = 140; break; end
                -- Hunter: Aspect of the Cheetah/Pack = 130% speed
                if spellName == "Aspect of the Cheetah" then speedPct = 130; break; end
                if spellName == "Aspect of the Pack" then speedPct = 130; break; end
                -- Rogue: Sprint = 170% speed
                if spellName == "Sprint" then speedPct = 170; break; end
                -- Druid: Travel Form / Swift Flight Form
                if spellName == "Travel Form" then speedPct = 140; break; end
                if spellName == "Dash" then speedPct = 170; break; end
                if spellName == "Cat Form" then speedPct = 100; break; end
                -- Swiftness Potion
                if spellName == "Swiftness" then speedPct = 150; break; end
                -- Nifty Stopwatch
                if spellName == "Speed" then speedPct = 105; break; end
                -- Any other speed buff (generic check)
                if strfind(strlower(spellName), "sprint") then speedPct = 170; break; end
                if strfind(strlower(spellName), "dash") then speedPct = 170; break; end
                if strfind(strlower(spellName), "speed") then speedPct = 105; break; end
            end
        end
    end

    RelationshipsDashboardMovementRowValue:SetText(string.format("%.0f%%", speedPct));

    -- Durability
    local avgDurability, repairCost, slotsWithDur = RelationshipsDashboard_CalculateDurabilityAndRepair();
    if RelationshipsDashboard_MerchantRepairCost > 0 then
        -- At a repair merchant: show the exact cost the game charges.
        repairCost = RelationshipsDashboard_MerchantRepairCost;
    else
        -- Away from a merchant: scale the raw estimate by the calibration factor
        -- learned from the last real merchant repair cost so it matches reality.
        repairCost = floor(repairCost * (RD_RepairCalibration or 1));
    end
    local durText = RelationshipsDashboard_FormatPercent(avgDurability);
    if avgDurability >= 75 then
        RelationshipsDashboardDurabilityRowValue:SetTextColor(0.2, 1, 0.2);
    elseif avgDurability >= 50 then
        RelationshipsDashboardDurabilityRowValue:SetTextColor(1, 1, 0);
    elseif avgDurability >= 25 then
        RelationshipsDashboardDurabilityRowValue:SetTextColor(1, 0.5, 0);
    else
        RelationshipsDashboardDurabilityRowValue:SetTextColor(1, 0.2, 0.2);
    end
    RelationshipsDashboardDurabilityRowValue:SetText(durText);

    -- Repair Total
    RelationshipsDashboardRepairCostRowValue:SetText(RelationshipsDashboard_FormatMoney(repairCost));

    -- GearScore
    local gearScore, avgILvl, equippedCount = RelationshipsDashboard_CalculateGearScore();
    if gearScore > 0 then
        RelationshipsDashboardGearScoreRowValue:SetText(tostring(gearScore));
    else
        RelationshipsDashboardGearScoreRowValue:SetText("--");
    end
    if gearScore >= 3500 then
        RelationshipsDashboardGearScoreRowValue:SetTextColor(1, 0.5, 0);
    elseif gearScore >= 2000 then
        RelationshipsDashboardGearScoreRowValue:SetTextColor(0.8, 0.2, 1);
    elseif gearScore >= 1200 then
        RelationshipsDashboardGearScoreRowValue:SetTextColor(0, 0.44, 0.87);
    elseif gearScore >= 500 then
        RelationshipsDashboardGearScoreRowValue:SetTextColor(0.12, 1, 0);
    else
        RelationshipsDashboardGearScoreRowValue:SetTextColor(1, 1, 1);
    end

    -- Avg Item Level
    if avgILvl > 0 then
        RelationshipsDashboardAvgILvlRowValue:SetText(string.format("%.1f", avgILvl));
    else
        RelationshipsDashboardAvgILvlRowValue:SetText("--");
    end

    -- ==== Section: Attributes ====
    -- UnitStat indices: 1=STR, 2=AGI, 3=STA, 4=INT, 5=SPI
    local baseStr, effectiveStr = UnitStat(RD_UNIT, 1);
    if effectiveStr then
        local bonus = effectiveStr - baseStr;
        if bonus ~= 0 then
            RelationshipsDashboardStrengthRowValue:SetText(effectiveStr .. " (" .. baseStr .. " +" .. bonus .. ")");
        else
            RelationshipsDashboardStrengthRowValue:SetText(tostring(effectiveStr));
        end
    else
        RelationshipsDashboardStrengthRowValue:SetText(tostring(baseStr));
    end

    local baseAgi, effectiveAgi = UnitStat(RD_UNIT, 2);
    if effectiveAgi then
        local bonus = effectiveAgi - baseAgi;
        if bonus ~= 0 then
            RelationshipsDashboardAgilityRowValue:SetText(effectiveAgi .. " (" .. baseAgi .. " +" .. bonus .. ")");
        else
            RelationshipsDashboardAgilityRowValue:SetText(tostring(effectiveAgi));
        end
    else
        RelationshipsDashboardAgilityRowValue:SetText(tostring(baseAgi));
    end

    local baseSta, effectiveSta = UnitStat(RD_UNIT, 3);
    if effectiveSta then
        local bonus = effectiveSta - baseSta;
        if bonus ~= 0 then
            RelationshipsDashboardStaminaRowValue:SetText(effectiveSta .. " (" .. baseSta .. " +" .. bonus .. ")");
        else
            RelationshipsDashboardStaminaRowValue:SetText(tostring(effectiveSta));
        end
    else
        RelationshipsDashboardStaminaRowValue:SetText(tostring(baseSta));
    end

    local baseInt, effectiveInt = UnitStat(RD_UNIT, 4);
    if effectiveInt then
        local bonus = effectiveInt - baseInt;
        if bonus ~= 0 then
            RelationshipsDashboardIntellectRowValue:SetText(effectiveInt .. " (" .. baseInt .. " +" .. bonus .. ")");
        else
            RelationshipsDashboardIntellectRowValue:SetText(tostring(effectiveInt));
        end
    else
        RelationshipsDashboardIntellectRowValue:SetText(tostring(baseInt));
    end

    local baseSpi, effectiveSpi = UnitStat(RD_UNIT, 5);
    if effectiveSpi then
        local bonus = effectiveSpi - baseSpi;
        if bonus ~= 0 then
            RelationshipsDashboardSpiritRowValue:SetText(effectiveSpi .. " (" .. baseSpi .. " +" .. bonus .. ")");
        else
            RelationshipsDashboardSpiritRowValue:SetText(tostring(effectiveSpi));
        end
    else
        RelationshipsDashboardSpiritRowValue:SetText(tostring(baseSpi));
    end

    -- ==== Section: Offense ====
    -- Damage (first in DejaStats Offense section)
    local minDamage, maxDamage, minOff, maxOff, posBuffDmg, negBuffDmg = UnitDamage(RD_UNIT);
    if minDamage and maxDamage then
        local effectiveMin = minDamage + (posBuffDmg or 0) + (negBuffDmg or 0);
        local effectiveMax = maxDamage + (posBuffDmg or 0) + (negBuffDmg or 0);
        local dmgText = floor(effectiveMin) .. " - " .. floor(effectiveMax);
        if minOff and maxOff and minOff > 0 then
            local effectiveMinOff = minOff + (posBuffDmg or 0) + (negBuffDmg or 0);
            local effectiveMaxOff = maxOff + (posBuffDmg or 0) + (negBuffDmg or 0);
            dmgText = dmgText .. " / " .. floor(effectiveMinOff) .. " - " .. floor(effectiveMaxOff);
        end
        RelationshipsDashboardMeleeDmgRowValue:SetText(dmgText);
    else
        RelationshipsDashboardMeleeDmgRowValue:SetText("--");
    end

    -- Attack Power
    local baseAP, posBuffAP, negBuffAP = UnitAttackPower(RD_UNIT);
    if baseAP then
        local totalAP = baseAP + (posBuffAP or 0) + (negBuffAP or 0);
        local apBonus = (posBuffAP or 0) + (negBuffAP or 0);
        if apBonus ~= 0 then
            RelationshipsDashboardMeleeAPRowValue:SetText(totalAP .. " (+" .. apBonus .. ")");
        else
            RelationshipsDashboardMeleeAPRowValue:SetText(tostring(totalAP));
        end
    else
        RelationshipsDashboardMeleeAPRowValue:SetText("--");
    end

    -- Attack Speed
    local mainSpeed, offSpeed = UnitAttackSpeed(RD_UNIT);
    if mainSpeed then
        if offSpeed and offSpeed > 0 then
            RelationshipsDashboardMeleeSpeedRowValue:SetText(RelationshipsDashboard_FormatDecimal(mainSpeed) .. " / " .. RelationshipsDashboard_FormatDecimal(offSpeed));
        else
            RelationshipsDashboardMeleeSpeedRowValue:SetText(RelationshipsDashboard_FormatDecimal(mainSpeed));
        end
    else
        RelationshipsDashboardMeleeSpeedRowValue:SetText("--");
    end

    -- Weapon DPS
    if mainSpeed and minDamage and maxDamage then
        local effectiveMin = minDamage + (posBuffDmg or 0) + (negBuffDmg or 0);
        local effectiveMax = maxDamage + (posBuffDmg or 0) + (negBuffDmg or 0);
        local avgDmg = (effectiveMin + effectiveMax) / 2;
        local weaponDPS = avgDmg / mainSpeed;
        RelationshipsDashboardWeaponDPSRowValue:SetText(string.format("%.2f", weaponDPS));
    else
        RelationshipsDashboardWeaponDPSRowValue:SetText("--");
    end

    -- Weapon Skill
    RelationshipsDashboardWeaponSkillRowValue:SetText(RelationshipsDashboard_GetWeaponSkill());

    -- Hit Chance
    local meleeHit = RelationshipsDashboard_GetMeleeHitChance();
    RelationshipsDashboardMeleeHitRowValue:SetText(RelationshipsDashboard_FormatPercent(meleeHit));

    -- Crit Chance
    local meleeCrit = RelationshipsDashboard_GetMeleeCritChance();
    RelationshipsDashboardMeleeCritRowValue:SetText(RelationshipsDashboard_FormatPercent(meleeCrit));

    -- ==== Section: Enhancements ====
    -- Ranged Attack Power
    local baseRAP, posBuffRAP, negBuffRAP = UnitRangedAttackPower(RD_UNIT);
    if baseRAP then
        local totalRAP = baseRAP + (posBuffRAP or 0) + (negBuffRAP or 0);
        RelationshipsDashboardRangedAPRowValue:SetText(tostring(totalRAP));
    else
        RelationshipsDashboardRangedAPRowValue:SetText("--");
    end

    -- Ranged Crit
    local rangedCrit = RelationshipsDashboard_GetRangedCritChance();
    RelationshipsDashboardRangedCritRowValue:SetText(RelationshipsDashboard_FormatPercent(rangedCrit));

    -- Ranged Speed
    -- UnitRangedDamage does NOT exist in vanilla 1.12
    -- Get ranged attack speed from the equipped ranged weapon's tooltip
    local rangedSpeedVal = nil;
    local rangedItemLink = GetInventoryItemLink(RD_UNIT, 18);
    if rangedItemLink and RelationshipsDashboardTooltip then
        RelationshipsDashboard_ResetTooltip();
        local ok, err = pcall(function() RelationshipsDashboardTooltip:SetInventoryItem(RD_UNIT, 18); end);
        if ok then
            for i = 1, RelationshipsDashboardTooltip:NumLines() do
                local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
                if textLine then
                    local text = textLine:GetText();
                    if text then
                        -- Match weapon speed pattern: "Speed XX.XX"
                        local _, _, spd = strfind(text, "Speed (%d+%.%d+)");
                        if spd then
                            rangedSpeedVal = tonumber(spd);
                            break;
                        end
                    end
                end
            end
        end
    end
    if rangedSpeedVal then
        RelationshipsDashboardRangedSpeedRowValue:SetText(RelationshipsDashboard_FormatDecimal(rangedSpeedVal));
    else
        RelationshipsDashboardRangedSpeedRowValue:SetText("--");
    end

    -- Ranged Damage
    local rangedItemLink = GetInventoryItemLink(RD_UNIT, 18);
    if rangedItemLink and RelationshipsDashboardTooltip then
        RelationshipsDashboard_ResetTooltip();
        RelationshipsDashboardTooltip_SetInventoryItemSafe(RD_UNIT, 18);
        for i = 1, RelationshipsDashboardTooltip:NumLines() do
            local textLine = getglobal("RelationshipsDashboardTooltipTextLeft" .. i);
            if textLine then
                local text = textLine:GetText();
                if text then
                    local _, _, dMin, dMax = strfind(text, "(%d+)%s*-%s*(%d+)%s+Damage");
                    if dMin and dMax then
                        RelationshipsDashboardRangedDmgRowValue:SetText(dMin .. " - " .. dMax);
                        break;
                    end
                end
            end
        end
    else
        RelationshipsDashboardRangedDmgRowValue:SetText("--");
    end

    -- Spell Power
    local spellPower = RelationshipsDashboard_GetSpellPower();
    RelationshipsDashboardSpellPowerRowValue:SetText(tostring(spellPower));

    -- Healing Power
    local healingPower = RelationshipsDashboard_GetHealingPower();
    RelationshipsDashboardHealingPowerRowValue:SetText(tostring(healingPower));

    -- Spell Hit
    local spellHit = RelationshipsDashboard_GetSpellHitChance();
    RelationshipsDashboardSpellHitRowValue:SetText(RelationshipsDashboard_FormatPercent(spellHit));

    -- Spell Crit
    local spellCrit = RelationshipsDashboard_GetSpellCritChance();
    RelationshipsDashboardSpellCritRowValue:SetText(RelationshipsDashboard_FormatPercent(spellCrit));

    -- Mana Regen
    local manaRegen = RelationshipsDashboard_GetManaRegen();
    if manaRegen > 0 then
        RelationshipsDashboardManaRegenRowValue:SetText(string.format("%.1f/s", manaRegen));
    else
        RelationshipsDashboardManaRegenRowValue:SetText("--");
    end

    -- ==== Section: Defenses ====
    -- Defense
    local defense = RelationshipsDashboard_GetDefense();
    RelationshipsDashboardDefenseRowValue:SetText(tostring(defense));

    -- Dodge
    if GetDodgeChance then
        RelationshipsDashboardDodgeRowValue:SetText(RelationshipsDashboard_FormatPercent(GetDodgeChance()));
    else
        RelationshipsDashboardDodgeRowValue:SetText("--");
    end

    -- Parry
    local parryChance = RelationshipsDashboard_GetParryChance();
    RelationshipsDashboardParryRowValue:SetText(RelationshipsDashboard_FormatPercent(parryChance));

    -- Block
    local blockChance = RelationshipsDashboard_GetBlockChance();
    RelationshipsDashboardBlockRowValue:SetText(RelationshipsDashboard_FormatPercent(blockChance));

    -- Avoidance (Dodge + Parry + Block + Miss chance)
    local missChance = 5;
    local level = UnitLevel(RD_UNIT);
    local defenseSkill = defense or (level * 5);
    if defenseSkill > level * 5 then
        missChance = 5 + (defenseSkill - level * 5) * 0.04;
    end
    local dodgeChance = (GetDodgeChance and GetDodgeChance()) or 0;
    local avoidance = missChance + dodgeChance + parryChance + blockChance;
    RelationshipsDashboardAvoidanceRowValue:SetText(RelationshipsDashboard_FormatPercent(avoidance));

    -- ==== Section: Resistances ====
    -- Resistance indices: 1=Holy, 2=Fire, 3=Nature, 4=Frost, 5=Shadow, 6=Arcane
    local resBase, resTotal, resBonus, resPos, resNeg;

    -- Arcane (index 6)
    resBase, resTotal, resBonus, resPos, resNeg = UnitResistance(RD_UNIT, RESISTANCE_INDICES.arcane);
    RelationshipsDashboardArcaneResRowValue:SetText(tostring(resTotal or 0));

    -- Fire (index 2)
    resBase, resTotal, resBonus, resPos, resNeg = UnitResistance(RD_UNIT, RESISTANCE_INDICES.fire);
    RelationshipsDashboardFireResRowValue:SetText(tostring(resTotal or 0));

    -- Nature (index 3)
    resBase, resTotal, resBonus, resPos, resNeg = UnitResistance(RD_UNIT, RESISTANCE_INDICES.nature);
    RelationshipsDashboardNatureResRowValue:SetText(tostring(resTotal or 0));

    -- Frost (index 4)
    resBase, resTotal, resBonus, resPos, resNeg = UnitResistance(RD_UNIT, RESISTANCE_INDICES.frost);
    RelationshipsDashboardFrostResRowValue:SetText(tostring(resTotal or 0));

    -- Shadow (index 5)
    resBase, resTotal, resBonus, resPos, resNeg = UnitResistance(RD_UNIT, RESISTANCE_INDICES.shadow);
    RelationshipsDashboardShadowResRowValue:SetText(tostring(resTotal or 0));

    -- ==== Apply class-specific visibility (hide irrelevant stats) ====
    RelationshipsDashboard_ApplyClassVisibility();
end

-------------------------------------------------------------------------------
-- Show/Hide Logic
-- Toggle the stats frame visibility with the CharacterFrame
-------------------------------------------------------------------------------
local function RelationshipsDashboard_ToggleVisibility()
    if CharacterFrame:IsVisible() then
        RelationshipsDashboardFrame:Show();
        RelationshipsDashboard_UpdateStatsNow();

    else
        RelationshipsDashboardFrame:Hide();
    end
end

-------------------------------------------------------------------------------
-- Hook into CharacterFrame show/hide
-- NOTE: HookScript() does NOT exist in vanilla 1.12 (added in TBC 2.1.0)
-- hooksecurefunc() does NOT exist either (added in TBC 2.0)
-- We must override the Show/Hide methods directly and call the originals.
-- Lua 5.0 uses unpack(arg) instead of ... for varargs in some contexts,
-- but function(...) works fine in Lua 5.0 as long as we forward args correctly.
-------------------------------------------------------------------------------
local RelationshipsDashboard_CharacterFrameHooked = false;

local function RelationshipsDashboard_HookCharacterFrame()
    if CharacterFrame and not RelationshipsDashboard_CharacterFrameHooked then
        RelationshipsDashboard_CharacterFrameHooked = true;

        -- Override CharacterFrame.Show to also show our stats panel
        local origShow = CharacterFrame.Show;
        CharacterFrame.Show = function(...)
            origShow(unpack(arg));
            RelationshipsDashboardFrame:Show();
            RelationshipsDashboard_UpdateStatsNow();

        end;

        -- Override CharacterFrame.Hide to also hide our stats panel
        local origHide = CharacterFrame.Hide;
        CharacterFrame.Hide = function(...)
            origHide(unpack(arg));
            RelationshipsDashboardFrame:Hide();
        end;
    end
end

-------------------------------------------------------------------------------
-- Hook InspectFrame so that inspecting another player also opens this
-- dashboard and shows THEIR stats (via unit "target"). When the inspect
-- window closes we revert RD_UNIT back to "player".
-------------------------------------------------------------------------------
local RelationshipsDashboard_InspectFrameHooked = false;

-------------------------------------------------------------------------------
-- Force the scroll viewport mask frames to a very high frame level so they
-- always draw ON TOP of the stat-row sub-frames inside the ScrollChild.
-- Must be re-applied whenever we change RelationshipsDashboardFrame's parent
-- or frame level (e.g. when hooking InspectFrame), because vanilla 1.12
-- cascades frame level changes down to child frames.
-------------------------------------------------------------------------------
function RelationshipsDashboard_BoostMaskLevels()
    local base = RelationshipsDashboardFrame:GetFrameLevel() or 2;
    local contentLevel = base + 10;
    local target = base + 100;

    if RelationshipsDashboardScrollFrame then
        RelationshipsDashboardScrollFrame:SetFrameLevel(contentLevel);
    end
    if RelationshipsDashboardContent then
        RelationshipsDashboardContent:SetFrameLevel(contentLevel + 1);
    end
    RelationshipsDashboard_ForEachScrollElement(function(element)
        element:SetFrameLevel(contentLevel + 2);
    end);

    if RelationshipsDashboardMaskTop then
        RelationshipsDashboardMaskTop:SetFrameLevel(target);
    end
    if RelationshipsDashboardMaskBottom then
        RelationshipsDashboardMaskBottom:SetFrameLevel(target);
    end
end


function RelationshipsDashboard_TryHookInspectFrame()
    if RelationshipsDashboard_InspectFrameHooked then return; end
    if not InspectFrame then return; end
    RelationshipsDashboard_InspectFrameHooked = true;

    local origShow = InspectFrame.Show;
    InspectFrame.Show = function(...)
        origShow(unpack(arg));
        -- Switch to inspect target
        RD_UNIT = "target";
        if UnitExists("target") and UnitIsPlayer("target") then
            -- IMPORTANT: parent to UIParent, NOT InspectFrame.
            -- InspectFrame has child sub-frames (PaperDoll, model) with high
            -- framelevels that will draw above our BG texture if we are a
            -- child of InspectFrame — that's what caused the "text bleeding
            -- through / scrolling through the inspect UI" bug.
            RelationshipsDashboardFrame:SetParent(UIParent);
            RelationshipsDashboardFrame:ClearAllPoints();
            -- Match the self (CharacterFrame) dashboard position: sit just off
            -- the frame's right edge with the same -30 overlap offset so the
            -- inspect dashboard lines up exactly like the personal one.
            RelationshipsDashboardFrame:SetPoint("TOPLEFT", InspectFrame, "TOPRIGHT", -30, -16);
            RelationshipsDashboardFrame:SetFrameStrata("HIGH");
            RelationshipsDashboardFrame:SetFrameLevel(20);
            RelationshipsDashboard_BoostMaskLevels();
            RelationshipsDashboardFrame:Show();
            RelationshipsDashboard_ApplyClassVisibility();
            RelationshipsDashboard_UpdateStats();
        end
    end;

    local origHide = InspectFrame.Hide;
    InspectFrame.Hide = function(...)
        origHide(unpack(arg));
        -- Restore player context and re-parent to CharacterFrame with the
        -- original overlapping anchor (CharacterFrame's right edge is empty
        -- border, so overlap is safe there).
        RD_UNIT = "player";
        RelationshipsDashboardFrame:Hide();
        RelationshipsDashboardFrame:SetParent(CharacterFrame);
        RelationshipsDashboardFrame:ClearAllPoints();
        RelationshipsDashboardFrame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", -30, -16);
        RelationshipsDashboardFrame:SetFrameStrata("MEDIUM");
        RelationshipsDashboardFrame:SetFrameLevel(2);
        RelationshipsDashboard_BoostMaskLevels();
        if CharacterFrame:IsVisible() then
            RelationshipsDashboardFrame:Show();
            RelationshipsDashboard_ApplyClassVisibility();
            RelationshipsDashboard_UpdateStats();
        end
    end;
end

-------------------------------------------------------------------------------
-- OnLoad - Initialize the addon
-------------------------------------------------------------------------------
function RelationshipsDashboard_OnLoad()
    -- Create the tooltip scanner (hidden, used for data extraction)
    RelationshipsDashboardTooltip = CreateFrame("GameTooltip", "RelationshipsDashboardTooltip", nil, "GameTooltipTemplate");
    RelationshipsDashboardTooltip:SetOwner(WorldFrame, "ANCHOR_NONE");

    -- Initialize section header text (DejaStats-style gold section headers)
    RDHeaderGeneralText:SetText("General");
    RDHeaderAttributesText:SetText("Attributes");
    RDHeaderOffenseText:SetText("Offense");
    RDHeaderEnhancementsText:SetText("Enhancements");
    RDHeaderDefensesText:SetText("Defenses");
    RDHeaderResistancesText:SetText("Resistances");

    -- Initialize stat row labels matching DejaStats layout
    -- Section: General
    RelationshipsDashboardHealthRowLabel:SetText("Health:");
    RelationshipsDashboardPowerRowLabel:SetText("Mana:");
    RelationshipsDashboardManaRowLabel:SetText("Mana:");
    RelationshipsDashboardArmorRowLabel:SetText("Armor:");
    RelationshipsDashboardMovementRowLabel:SetText("Movement Speed:");
    RelationshipsDashboardDurabilityRowLabel:SetText("Durability:");
    RelationshipsDashboardRepairCostRowLabel:SetText("Repair Total:");
    RelationshipsDashboardRepairCostRowValue:SetTextColor(1, 0.2, 0.2);
    RelationshipsDashboardGearScoreRowLabel:SetText("GearScore:");
    RelationshipsDashboardAvgILvlRowLabel:SetText("Avg Item Level:");

    -- Section: Attributes
    RelationshipsDashboardStrengthRowLabel:SetText("Strength:");
    RelationshipsDashboardAgilityRowLabel:SetText("Agility:");
    RelationshipsDashboardStaminaRowLabel:SetText("Stamina:");
    RelationshipsDashboardIntellectRowLabel:SetText("Intellect:");
    RelationshipsDashboardSpiritRowLabel:SetText("Spirit:");

    -- Section: Offense
    RelationshipsDashboardMeleeDmgRowLabel:SetText("Damage:");
    RelationshipsDashboardMeleeAPRowLabel:SetText("Attack Power:");
    RelationshipsDashboardMeleeSpeedRowLabel:SetText("Attack Speed:");
    RelationshipsDashboardWeaponDPSRowLabel:SetText("Weapon DPS:");
    RelationshipsDashboardWeaponSkillRowLabel:SetText("Weapon Skill:");
    RelationshipsDashboardMeleeHitRowLabel:SetText("Hit Chance:");
    RelationshipsDashboardMeleeCritRowLabel:SetText("Crit Chance:");

    -- Section: Enhancements
    RelationshipsDashboardRangedAPRowLabel:SetText("Ranged AP:");
    RelationshipsDashboardRangedCritRowLabel:SetText("Ranged Crit:");
    RelationshipsDashboardRangedSpeedRowLabel:SetText("Ranged Speed:");
    RelationshipsDashboardRangedDmgRowLabel:SetText("Ranged Damage:");
    RelationshipsDashboardSpellPowerRowLabel:SetText("Spell Power:");
    RelationshipsDashboardHealingPowerRowLabel:SetText("Healing Power:");
    RelationshipsDashboardSpellHitRowLabel:SetText("Spell Hit:");
    RelationshipsDashboardSpellCritRowLabel:SetText("Spell Crit:");
    RelationshipsDashboardManaRegenRowLabel:SetText("Mana Regen:");

    -- Section: Defenses
    RelationshipsDashboardDefenseRowLabel:SetText("Defense:");
    RelationshipsDashboardDodgeRowLabel:SetText("Dodge:");
    RelationshipsDashboardParryRowLabel:SetText("Parry:");
    RelationshipsDashboardBlockRowLabel:SetText("Block:");
    RelationshipsDashboardAvoidanceRowLabel:SetText("Avoidance:");
    RelationshipsDashboardAvoidanceRowValue:SetTextColor(0.2, 1, 0.2);

    -- Section: Resistances (school-colored labels)
    RelationshipsDashboardArcaneResRowLabel:SetText("Arcane:");
    RelationshipsDashboardFireResRowLabel:SetText("Fire:");
    RelationshipsDashboardNatureResRowLabel:SetText("Nature:");
    RelationshipsDashboardFrostResRowLabel:SetText("Frost:");
    RelationshipsDashboardShadowResRowLabel:SetText("Shadow:");

    -- Resistance label color overrides (school colors matching DejaStats)
    RelationshipsDashboardArcaneResRowLabel:SetTextColor(0.7, 0.2, 1);     -- Arcane (purple)
    RelationshipsDashboardFireResRowLabel:SetTextColor(1, 0.4, 0.1);       -- Fire (red-orange)
    RelationshipsDashboardNatureResRowLabel:SetTextColor(0.2, 0.9, 0.2);   -- Nature (green)
    RelationshipsDashboardFrostResRowLabel:SetTextColor(0.3, 0.6, 1);      -- Frost (blue)
    RelationshipsDashboardShadowResRowLabel:SetTextColor(0.6, 0.2, 0.8);   -- Shadow (violet)

    -- Power label override: update based on class power type at load
    -- This will be refined on each UpdateStats call
    local powerType = UnitPowerType("player");
    if powerType == 1 then
        RelationshipsDashboardPowerRowLabel:SetText("Rage:");
    elseif powerType == 2 then
        RelationshipsDashboardPowerRowLabel:SetText("Focus:");
    elseif powerType == 3 then
        RelationshipsDashboardPowerRowLabel:SetText("Energy:");
    else
        RelationshipsDashboardPowerRowLabel:SetText("Mana:");
    end

    -- Register for events
    local frame = RelationshipsDashboardFrame;
    frame:RegisterEvent("UNIT_STATS");
    frame:RegisterEvent("UNIT_ATTACK_POWER");
    frame:RegisterEvent("UNIT_RANGED_ATTACK_POWER");
    frame:RegisterEvent("UNIT_ATTACK_SPEED");
    frame:RegisterEvent("UNIT_RESISTANCES");
    frame:RegisterEvent("UNIT_DEFENSE");
    frame:RegisterEvent("UNIT_DAMAGE");
    frame:RegisterEvent("UPDATE_INVENTORY_ALERTS");
    frame:RegisterEvent("UNIT_INVENTORY_CHANGED");
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
    frame:RegisterEvent("UNIT_MODEL_CHANGED");
    frame:RegisterEvent("PLAYER_ENTERING_WORLD");
    frame:RegisterEvent("PLAYER_MONEY");
    frame:RegisterEvent("UPDATE_TOOLTIP");
    frame:RegisterEvent("MERCHANT_SHOW");
    frame:RegisterEvent("MERCHANT_UPDATE");
    frame:RegisterEvent("MERCHANT_CLOSED");
    frame:RegisterEvent("UNIT_DISPLAYPOWER");
    frame:RegisterEvent("UNIT_MANA");
    frame:RegisterEvent("UNIT_RAGE");
    frame:RegisterEvent("UNIT_ENERGY");
    frame:RegisterEvent("UNIT_FOCUS");
    frame:RegisterEvent("UNIT_HEALTH");
    frame:RegisterEvent("PLAYER_DEAD");
    frame:RegisterEvent("PLAYER_REGEN_DISABLED");
    frame:RegisterEvent("PLAYER_REGEN_ENABLED");
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
    frame:RegisterEvent("ZONE_CHANGED");
    frame:RegisterEvent("UNIT_MAXHEALTH");
    frame:RegisterEvent("UNIT_MAXMANA");
    frame:RegisterEvent("UNIT_MAXRAGE");
    frame:RegisterEvent("UNIT_MAXENERGY");
    frame:RegisterEvent("UNIT_MAXFOCUS");
    frame:RegisterEvent("ADDON_LOADED");
    frame:RegisterEvent("VARIABLES_LOADED");
    frame:RegisterEvent("PLAYER_TARGET_CHANGED");
    frame:RegisterEvent("PLAYER_UNGHOST");   -- Player is no longer a ghost (rez'd)
    frame:RegisterEvent("PLAYER_ALIVE");     -- Fires on both corpse-run and SH rez
    frame:RegisterEvent("CORPSE_IN_RANGE");  -- Near own corpse (retrieval possible)
    frame:RegisterEvent("CORPSE_OUT_OF_RANGE");
    -- Explicitly flush the saved-durability table back to its SavedVariable
    -- global on logout / /reload. WoW normally handles this automatically,
    -- but this safety net protects against the reference being unhooked by
    -- any future edit that reassigns RD_SavedDurability locally.
    frame:RegisterEvent("DUEL_REQUESTED");
    frame:RegisterEvent("DUEL_FINISHED");
    frame:RegisterEvent("PLAYER_LOGOUT");



    -- Hide the scrollbar and ALL its sub-elements for a flat UI
    -- UIPanelScrollFrameTemplate (WoW 1.12) creates $parentScrollBar (a Slider) with:
    --   $parentScrollUpButton  (Button: NormalTexture, PushedTexture, DisabledTexture, HighlightTexture)
    --   $parentScrollDownButton (Button: NormalTexture, PushedTexture, DisabledTexture, HighlightTexture)
    --   $parentThumbTexture     (Texture inheriting UIPanelScrollBarButton)
    -- We hide AND set alpha=0 on every element to guarantee nothing is visible
    local scrollBar = getglobal("RelationshipsDashboardScrollFrameScrollBar");
    if scrollBar then
        scrollBar:Hide();
        scrollBar:SetAlpha(0);

        -- Hide and make transparent the up/down arrow buttons and all their texture states
        local scrollUp = getglobal("RelationshipsDashboardScrollFrameScrollBarScrollUpButton");
        local scrollDown = getglobal("RelationshipsDashboardScrollFrameScrollBarScrollDownButton");
        if scrollUp then
            scrollUp:Hide();
            scrollUp:SetAlpha(0);
            -- Hide each texture state on the Up button
            local tex;
            tex = scrollUp:GetNormalTexture();   if tex then tex:SetAlpha(0); tex:Hide(); end
            tex = scrollUp:GetPushedTexture();    if tex then tex:SetAlpha(0); tex:Hide(); end
            tex = scrollUp:GetDisabledTexture();  if tex then tex:SetAlpha(0); tex:Hide(); end
            tex = scrollUp:GetHighlightTexture(); if tex then tex:SetAlpha(0); tex:Hide(); end
        end
        if scrollDown then
            scrollDown:Hide();
            scrollDown:SetAlpha(0);
            -- Hide each texture state on the Down button
            local tex;
            tex = scrollDown:GetNormalTexture();   if tex then tex:SetAlpha(0); tex:Hide(); end
            tex = scrollDown:GetPushedTexture();    if tex then tex:SetAlpha(0); tex:Hide(); end
            tex = scrollDown:GetDisabledTexture();  if tex then tex:SetAlpha(0); tex:Hide(); end
            tex = scrollDown:GetHighlightTexture(); if tex then tex:SetAlpha(0); tex:Hide(); end
        end

        -- Hide and make transparent the thumb (the draggable block in the scrollbar)
        -- In WoW 1.12, ThumbTexture is a single Texture (no Left/Right/Middle sub-textures)
        local thumb = getglobal("RelationshipsDashboardScrollFrameScrollBarThumbTexture");
        if thumb then
            thumb:SetAlpha(0);
            thumb:Hide();
        end
    end

    -- Enable mouse wheel scrolling on the scroll frame
    -- The ScrollFrame doesn't natively handle mouse wheel, so we add it
    local scrollFrame = RelationshipsDashboardScrollFrame;
    scrollFrame:EnableMouseWheel(true);
    scrollFrame:SetScript("OnMouseWheel", function()
        -- In WoW 1.12 Lua 5.0, arg1 contains the scroll delta
        -- Positive = scroll up, Negative = scroll down
        local delta = arg1;
        local scrollBar = getglobal("RelationshipsDashboardScrollFrameScrollBar");
        if scrollBar then
            local minVal, maxVal = scrollBar:GetMinMaxValues();
            local current = scrollBar:GetValue();
            local step = 30;  -- pixels per scroll step
            if delta > 0 then
                -- Scroll up
                if current - step < minVal then
                    scrollBar:SetValue(minVal);
                else
                    scrollBar:SetValue(current - step);
                end
            else
                -- Scroll down
                if current + step > maxVal then
                    scrollBar:SetValue(maxVal);
                else
                    scrollBar:SetValue(current + step);
                end
            end
            RelationshipsDashboard_UpdateViewportClip();
        end
    end);

    frame:SetScript("OnUpdate", function()
        -- Vanilla 1.12 passes elapsed via arg1 (Lua 5.0 has no `...` here).
        local elapsed = arg1 or 0;
        if RelationshipsDashboardFrame:IsVisible() then
            RelationshipsDashboard_UpdateViewportClip();
            -- Flush any pending coalesced stat refresh (throttled).
            RelationshipsDashboard_FlushPendingStats(elapsed);
        end
        -- Detect ghost-state transitions (spirit-release → ghost, or rez →
        -- alive) as they happen, so the durability % and estimated repair
        -- cost update the moment the player becomes a ghost instead of
        -- waiting until they respawn / a later event.
        local isGhostNow = (UnitIsGhost and UnitIsGhost("player")) and true or false;
        if RD_GhostStateLast == nil then
            RD_GhostStateLast = isGhostNow;
        elseif isGhostNow ~= RD_GhostStateLast then
            RD_GhostStateLast = isGhostNow;
            if isGhostNow then
                -- Player just released and became a ghost. The 10% death
                -- durability penalty is normally applied on PLAYER_DEAD, but
                -- guard against a missed application (e.g. PLAYER_DEAD arrived
                -- before saved-durability baselines existed).
                if not RD_DeathPenaltyApplied then
                    RelationshipsDashboard_ApplyDeathPenalty();
                    RD_DeathPenaltyApplied = true;
                end
                RD_WasGhost = true;
            else
                RD_DeathPenaltyApplied = false;
            end
            if RelationshipsDashboardFrame:IsVisible() then
                RelationshipsDashboard_UpdateStats();
            end
        end
    end);


    -- Ensure the scroll-viewport masks always draw above the stat row sub-frames
    -- inside the ScrollChild. Vanilla ScrollFrame does NOT clip nested child
    -- frames, so without these masks the row FontStrings render outside the
    -- scroll area when scrolled. See RelationshipsDashboard.xml for details.
    RelationshipsDashboard_BoostMaskLevels();

    -- Hook into CharacterFrame
    RelationshipsDashboard_HookCharacterFrame(); RelationshipsDashboard_TryHookInspectFrame();

    -- Initialize saved variables
    if not RelationshipsDashboardDB then
        RelationshipsDashboardDB = {};
    end

    -- Initial update (will run when CharacterFrame opens)
    -- The frame starts hidden, so we don't update immediately
end

-------------------------------------------------------------------------------
-- OnEvent - Handle registered events
-------------------------------------------------------------------------------
function RelationshipsDashboard_OnEvent(event)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_InspectUI" then
            RelationshipsDashboard_TryHookInspectFrame();
        elseif arg1 == "RelationshipsDashboard" then
            -- Bind the saved durability table so it persists across /reload
            if RelationshipsDashboardDB_SavedDurability == nil then
                RelationshipsDashboardDB_SavedDurability = {};
            end
            RD_SavedDurability = RelationshipsDashboardDB_SavedDurability;
            -- Restore the learned repair calibration factor.
            if RelationshipsDashboardDB and RelationshipsDashboardDB.repairCalibration
                    and RelationshipsDashboardDB.repairCalibrationVersion == RD_REPAIR_CALIBRATION_VERSION then
                RD_RepairCalibration = RelationshipsDashboardDB.repairCalibration;
            else
                RD_RepairCalibration = 1.0;
            end
        end
        return;
    elseif event == "VARIABLES_LOADED" then
        if RelationshipsDashboardDB_SavedDurability == nil then
            RelationshipsDashboardDB_SavedDurability = {};
        end
        RD_SavedDurability = RelationshipsDashboardDB_SavedDurability;
        if RelationshipsDashboardDB and RelationshipsDashboardDB.repairCalibration
                and RelationshipsDashboardDB.repairCalibrationVersion == RD_REPAIR_CALIBRATION_VERSION then
            RD_RepairCalibration = RelationshipsDashboardDB.repairCalibration;
        else
            RD_RepairCalibration = 1.0;
        end
        return;
    elseif event == "PLAYER_LOGOUT" then
        -- Guarantee the saved-durability table (and calibration) survive
        -- /reload and full logout, even if some other code path reassigned
        -- RD_SavedDurability to a fresh table after ADDON_LOADED.
        if RD_SavedDurability then
            RelationshipsDashboardDB_SavedDurability = RD_SavedDurability;
        end
        if RelationshipsDashboardDB and RD_RepairCalibration then
            RelationshipsDashboardDB.repairCalibration = RD_RepairCalibration;
            RelationshipsDashboardDB.repairCalibrationVersion = RD_REPAIR_CALIBRATION_VERSION;
        end
        return;

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- The dashboard can stay open while the user clicks between different
        -- targets in the world (or opens/closes inspect). Resync RD_UNIT against
        -- reality every time target changes, so class-based row filtering always
        -- matches the unit whose stats we are about to display.
        if RelationshipsDashboardFrame:IsVisible() then
            if InspectFrame and InspectFrame:IsVisible()
                    and UnitExists("target") and UnitIsPlayer("target") then
                RD_UNIT = "target";
            else
                RD_UNIT = "player";
            end
            RelationshipsDashboard_ApplyClassVisibility();
            RelationshipsDashboard_UpdateStats();
        end
        return;
    end
    if event == "PLAYER_ENTERING_WORLD" then
        -- Delay initial setup slightly
        RelationshipsDashboard_HookCharacterFrame(); RelationshipsDashboard_TryHookInspectFrame();
        -- Initialize mana tracking for druid form support
        local powerType = UnitPowerType("player");
        if powerType == 0 then
            RelationshipsDashboard_LastKnownMana = UnitMana("player");
            RelationshipsDashboard_LastKnownMaxMana = UnitManaMax("player");
        end
        RD_LastMoney = GetMoney();
        RD_InBattleground = RelationshipsDashboard_IsInBattleground();
        if RD_InBattleground and not RD_BG_DurabilitySnapshot then
            RelationshipsDashboard_SnapshotDurabilityForBG();
        end
        -- Sync stored ghost state to reality on login
        if UnitIsGhost and UnitIsGhost("player") then
            RD_WasGhost = true;
        end
    elseif event == "UNIT_DISPLAYPOWER" then
        -- Power type changed (e.g., druid shifted forms)
        if arg1 and arg1 ~= "player" then return; end
        local powerType = UnitPowerType("player");
        if powerType == 0 then
            RelationshipsDashboard_LastKnownMana = UnitMana("player");
            RelationshipsDashboard_LastKnownMaxMana = UnitManaMax("player");
        end
        if RelationshipsDashboardFrame:IsVisible() then
            RelationshipsDashboard_ApplyClassVisibility();
            RelationshipsDashboard_UpdateStats();
        end
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        RelationshipsDashboard_UpdateRepairFromMerchant();
        if RelationshipsDashboardFrame:IsVisible() then
            RelationshipsDashboard_UpdateStats();
        end
    elseif event == "MERCHANT_CLOSED" then
        RelationshipsDashboard_MerchantRepairCost = 0;
        RD_AtRepairMerchant = false;
        RD_LastMoney = GetMoney();
        if RelationshipsDashboardFrame:IsVisible() then
            RelationshipsDashboard_UpdateStats();
        end
    elseif event == "PLAYER_DEAD" then
        -- Refresh BG state before deciding to apply the death penalty.
        RD_InBattleground = RelationshipsDashboard_IsInBattleground();
        if RD_InBattleground and not RD_BG_DurabilitySnapshot then
            -- We entered a BG without seeing ZONE_CHANGED first (rare but
            -- observed on OctoWoW). Snapshot now so the restore is a no-op.
            RelationshipsDashboard_SnapshotDurabilityForBG();
        end
        -- Player died: apply 10% durability loss (skipped inside BGs).
        RelationshipsDashboard_ApplyDeathPenalty();
        if RD_InBattleground then
            RelationshipsDashboard_RestoreDurabilityFromBGSnapshot();
        end
        RD_DeathPenaltyApplied = true;
        RD_WasGhost = true;
        if RelationshipsDashboardFrame:IsVisible() then
            RelationshipsDashboard_UpdateStats();
        end
    elseif event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE" then
        -- Detect spirit-healer resurrection: player was a ghost, and after
        -- becoming alive is NOT near their corpse (corpse-run always leaves
        -- you at the corpse location — spirit rez teleports you to the
        -- graveyard). Vanilla exposes HasCorpse via GetCorpseRecoveryDelay():
        -- returns > 0 only after a spirit rez. That's our signal.
        local isAlive = not (UnitIsGhost and UnitIsGhost("player"))
                and not (UnitIsDead and UnitIsDead("player"));
        if RD_WasGhost and isAlive then
            local corpseDelay = 0;
            if GetCorpseRecoveryDelay then
                corpseDelay = GetCorpseRecoveryDelay() or 0;
            end
            if corpseDelay > 0 then
                RelationshipsDashboard_ApplySpiritHealerPenalty();
            end
            RD_WasGhost = false;
        end
        -- Clear the death-penalty guard once the player is alive again so a
        -- subsequent death re-applies the 10% loss.
        if not (UnitIsGhost and UnitIsGhost("player")) then
            RD_DeathPenaltyApplied = false;
            RD_GhostStateLast = false;
        end
        -- Always refresh the dashboard on rez (corpse-run OR spirit-heal).
        -- The 10% death penalty was already applied on PLAYER_DEAD but the
        -- character panel is usually closed at that moment, so this is the
        -- first chance the visible dashboard has to redraw with the loss.
        if RelationshipsDashboardFrame:IsVisible() then
            RelationshipsDashboard_UpdateStats();
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: start tracking hits for durability estimation
        RD_InCombat = true;
        RD_CombatHitCount = 0;
        RD_LastHealth = UnitHealth("player");
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat: stop tracking
        RD_InCombat = false;
        RD_CombatHitCount = 0;
    elseif event == "DUEL_REQUESTED" then
        -- A duel has been initiated between the player and someone else.
        -- Duels never cause real durability loss, so treat the duration
        -- like a battleground for our purposes. We capture equipped
        -- durability snapshots so we can restore them exactly if the duel
        -- somehow does mutate our tracker.
        RD_InDuel = true;
    elseif event == "DUEL_FINISHED" then
        -- Duel is over (accepted-and-completed, declined, or cancelled).
        -- Restore estimated durability to full for equipped items so any
        -- combat-wear ticks that fired mid-duel are undone.
        if RD_InDuel then
            RelationshipsDashboard_ResetDurabilityToFull();
        end
        RD_InDuel = false;
        if RelationshipsDashboardFrame:IsVisible() then
            RelationshipsDashboard_UpdateStats();
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
        -- Zone changed: update battleground status
        local wasInBG = RD_InBattleground;
        RD_InBattleground = RelationshipsDashboard_IsInBattleground();
        -- Entering a battleground: snapshot current durability so we can
        -- restore it exactly on exit regardless of any events fired inside.
        if RD_InBattleground and not wasInBG then
            RelationshipsDashboard_SnapshotDurabilityForBG();
        end
        -- When leaving a battleground, restore the pre-BG snapshot instead
        -- of resetting to full (avoids over-repairing gear that was already
        -- damaged before queueing).
        if wasInBG and not RD_InBattleground then
            if RD_BG_DurabilitySnapshot then
                RelationshipsDashboard_RestoreDurabilityFromBGSnapshot();
                RD_BG_DurabilitySnapshot = nil;
            else
                RelationshipsDashboard_ResetDurabilityToFull();
            end
        end
        if RelationshipsDashboardFrame:IsVisible() then
            RelationshipsDashboard_UpdateStats();
        end
    elseif event == "PLAYER_MONEY" then
        -- Gold changed. If a repair merchant is open this is very likely a
        -- repair (or a purchase). Check whether money actually decreased and
        -- whether the drop is consistent with the last-known repair-all cost.
        -- If so, we KNOW a repair just happened -> force a full reset even if
        -- GetRepairAllCost hasn't yet updated to 0 (some server builds lag by
        -- a frame).
        local newMoney = GetMoney();
        local spent = 0;
        if RD_LastMoney and newMoney and newMoney < RD_LastMoney then
            spent = RD_LastMoney - newMoney;
        end
        if RD_AtRepairMerchant then
            -- Detect "just repaired": money dropped by ~90%+ of the previously
            -- reported repair-all cost. Covers Repair All AND individual
            -- right-click repairs (which drop by a slot's share).
            if spent > 0 and RD_PrevMerchantRepairCost > 0
                    and spent >= math.floor(RD_PrevMerchantRepairCost * 0.9)
                    and spent <= RD_PrevMerchantRepairCost + 100 then
                RelationshipsDashboard_MerchantRepairCost = 0;
                RD_PrevMerchantRepairCost = 0;
                RelationshipsDashboard_ResetDurabilityToFull();
            else
                -- Otherwise just re-query cost normally; the function will
                -- itself trigger a reset if cost dropped to 0.
                RelationshipsDashboard_UpdateRepairFromMerchant();
            end
        end
        RD_LastMoney = newMoney;
        if RelationshipsDashboardFrame:IsVisible() then
            RelationshipsDashboard_UpdateStats();
        end
    else
        -- All other stat-related events (UNIT_MANA, UNIT_HEALTH, etc.)
        -- arg1 is the unitID for UNIT_* events — only update for "player"
        if arg1 and arg1 ~= "player" then
            return;
        end
        -- Track damage taken in combat for durability estimation
        if event == "UNIT_HEALTH" and RD_InCombat then
            local currentHealth = UnitHealth("player");
            if RD_LastHealth > 0 and currentHealth < RD_LastHealth then
                local damageTaken = RD_LastHealth - currentHealth;
                -- Apply combat wear (the function internally tracks hit count)
                RelationshipsDashboard_ApplyCombatWear(damageTaken);
            end
            RD_LastHealth = currentHealth;
        end
        if RelationshipsDashboardFrame:IsVisible() then
            RelationshipsDashboard_UpdateStats();
        end
    end
end
