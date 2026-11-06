-- MouseoverCast v1.0.15-beta5
-- Vanilla WoW 1.12 / OctoWoW
-- Requires SuperWoW + ClassicAPI for macro-free actionbar mouseover casting.

local ADDON_NAME = "MouseoverCast"
local VERSION = "1.0.15-beta5"

local OriginalUseAction = UseAction
local OriginalCastSpell = CastSpell
local OriginalCastSpellByName = CastSpellByName
local OriginalPetAttack = PetAttack
local OriginalCastPetAction = CastPetAction
local petCommandDispatch = false
local pendingPetAttack = nil
local lastPetAttempt = { path = "none", result = "none" }

local frame = CreateFrame("Frame", "MouseoverCastEventFrame")

local DEFAULTS = {
    enabled = 1,
    offensive = 0,
    petAttack = 1,
    allowPets = 1,
    allHelpful = 0,
    quiet = 0,
}

local knownHealingNames = {}

-- One representative spell ID per friendly spell family. GetSpellInfo() from
-- ClassicAPI returns the localized name, so this works on non-English clients.
-- This list intentionally includes heals plus targeted defensive/protection
-- abilities, while leaving ordinary long-duration buffs untouched.
local healingFamilySpellIDs = {
    -- Priest
    2050,   -- Lesser Heal
    2054,   -- Heal
    2060,   -- Greater Heal
    2061,   -- Flash Heal
    139,    -- Renew
    17,     -- Power Word: Shield

    -- Druid
    5185,   -- Healing Touch
    8936,   -- Regrowth
    774,    -- Rejuvenation
    18562,  -- Swiftmend

    -- Paladin
    635,    -- Holy Light
    19750,  -- Flash of Light
    633,    -- Lay on Hands
    20473,  -- Holy Shock
    1022,   -- Blessing of Protection
    1044,   -- Blessing of Freedom
    6940,   -- Blessing of Sacrifice

    -- Shaman
    331,    -- Healing Wave
    8004,   -- Lesser Healing Wave
    1064,   -- Chain Heal
    974,    -- Earth Shield (Vanilla+ servers, if available)
}

-- Extra names for common Vanilla+ healing spells. These are only fallbacks;
-- the normal Vanilla heals above are localized automatically from spell IDs.
local extraHealingNames = {
    ["Lifebloom"] = 1,
    ["Nourish"] = 1,
    ["Circle of Healing"] = 1,
    ["Blühendes Leben"] = 1,
    ["Pflege"] = 1,
    ["Kreis der Heilung"] = 1,
}

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4fd1ffMouseoverCast:|r " .. msg)
    end
end

local function ApplyDefaults()
    if type(MouseoverCastDB) ~= "table" then
        MouseoverCastDB = {}
    end

    for key, value in pairs(DEFAULTS) do
        if MouseoverCastDB[key] == nil then
            MouseoverCastDB[key] = value
        end
    end
end

local function HasClassicAPI()
    return type(GetActionInfo) == "function"
        and type(GetSpellInfo) == "function"
        and type(IsHelpfulSpell) == "function"
        and type(IsHarmfulSpell) == "function"
end

local function HasSuperWoW()
    if SUPERWOW_VERSION then
        return true
    end

    -- SuperWoW's extended CastSpellByName accepts a second unit argument.
    -- There is no safe stock-1.12 feature probe for the extra C argument,
    -- so SUPERWOW_VERSION remains the primary detection path.
    return false
end

local function BuildHealingNameCache()
    knownHealingNames = {}

    if type(GetSpellInfo) == "function" then
        for _, spellID in ipairs(healingFamilySpellIDs) do
            local name = GetSpellInfo(spellID)
            if name then
                knownHealingNames[name] = 1
            end
        end
    end

    for name, value in pairs(extraHealingNames) do
        knownHealingNames[name] = value
    end
end

local function UnitIsValidFriendly(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    if not UnitCanAssist("player", unit) then
        return false
    end

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        return false
    elseif UnitIsDead and UnitIsDead(unit) then
        return false
    end

    if MouseoverCastDB and MouseoverCastDB.allowPets ~= 1 then
        if UnitPlayerControlled and UnitPlayerControlled(unit) and not UnitIsPlayer(unit) then
            return false
        end
    end

    return true
end

local function UnitIsValidEnemy(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    if not UnitCanAttack("player", unit) then
        return false
    end

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        return false
    elseif UnitIsDead and UnitIsDead(unit) then
        return false
    end

    return true
end

local function IsResolvableUnit(candidate)
    if type(candidate) ~= "string" or candidate == "" then
        return false
    end

    local ok, exists = pcall(UnitExists, candidate)
    return ok and exists and true or false
end

local function ResolveFrameUnit(f)
    local depth = 0

    while f and depth < 8 do
        -- ClassicAPI backports modern unit attributes. Many custom raid/
        -- utility frames expose their unit here instead of assigning .unit.
        if f.GetAttribute then
            local ok, candidate = pcall(f.GetAttribute, f, "unit")
            if ok and IsResolvableUnit(candidate) then
                return candidate
            end
        end

        -- Common field names used by Vanilla unit-frame addons.
        local fields = {
            "unit", "unitID", "unitId", "unitid",
            "Unit", "UnitID", "UnitId",
            "guid", "GUID", "unitGUID", "unitGuid",
        }

        for _, fieldName in ipairs(fields) do
            local candidate = f[fieldName]
            if IsResolvableUnit(candidate) then
                return candidate
            end
        end

        if f.label and f.id then
            local candidate = tostring(f.label) .. tostring(f.id)
            if IsResolvableUnit(candidate) then
                return candidate
            end
        end

        local name = nil
        if f.GetName then
            name = f:GetName()
        end

        if name then
            -- Lua 5.0 compatibility: use string.find captures instead of string.match.
            local _, _, n = string.find(name, "^PartyMemberFrame(%d+)PetFrame")
            if n and IsResolvableUnit("partypet" .. n) then
                return "partypet" .. n
            end

            _, _, n = string.find(name, "^PartyMemberFrame(%d+)")
            if n and IsResolvableUnit("party" .. n) then
                return "party" .. n
            end

            _, _, n = string.find(name, "^RaidMemberFrame(%d+)")
            if n and IsResolvableUnit("raid" .. n) then
                return "raid" .. n
            end

            if string.find(name, "PlayerFrame", 1, true) and IsResolvableUnit("player") then
                return "player"
            end

            if string.find(name, "PetFrame", 1, true) and IsResolvableUnit("pet") then
                return "pet"
            end

            if string.find(name, "TargetFrame", 1, true) and IsResolvableUnit("target") then
                return "target"
            end
        end

        -- Some raid-frame addons provide a logical row parent that differs
        -- from the visual GetParent() tree (Cursive exposes .parent).
        local logicalParent = f.parent
        if logicalParent and logicalParent ~= f
            and (type(logicalParent) == "table" or type(logicalParent) == "userdata") then
            f = logicalParent
        elseif f.GetParent then
            f = f:GetParent()
        else
            f = nil
        end

        depth = depth + 1
    end

    return nil
end

local function ResolveTooltipUnit(focus)
    -- ClassicAPI exposes the GUID currently stored in a unit tooltip. This is
    -- a last-resort bridge for UI elements that do not expose their unit
    -- directly on the frame.
    if not GameTooltip or not GameTooltip.IsVisible or not GameTooltip:IsVisible() then
        return nil
    end

    if focus and GameTooltip.IsOwned then
        local owned = false
        local f = focus
        local depth = 0

        while f and depth < 8 do
            local ok, result = pcall(GameTooltip.IsOwned, GameTooltip, f)
            if ok and result then
                owned = true
                break
            end

            if f.GetParent then
                f = f:GetParent()
            else
                f = nil
            end

            depth = depth + 1
        end

        if not owned then
            return nil
        end
    end

    if GameTooltip.GetUnitGUID then
        local ok, _, guid = pcall(GameTooltip.GetUnitGUID, GameTooltip)
        if ok and IsResolvableUnit(guid) then
            return guid
        end
    end

    return nil
end

local function ResolveMouseoverUnit()
    -- Cursive Raid and similar UI rows hold an explicit unit/GUID on their
    -- frame. Prefer the ACTUAL hovered frame over the generic 'mouseover'
    -- token; on this client that token can still point at the 3D world unit
    -- behind an addon window, or at the previous mouseover.
    local focus = GetMouseFocus and GetMouseFocus() or nil
    if focus then
        local frameUnit = ResolveFrameUnit(focus)
        if frameUnit then
            return frameUnit
        end
    end

    if IsResolvableUnit("mouseover") then
        return "mouseover"
    end

    if focus then
        return ResolveTooltipUnit(focus)
    end
    return nil
end

local function ResolveHoveredFrameGUID()
    if not GetMouseFocus then
        return nil
    end

    local f = GetMouseFocus()
    local depth = 0
    while f and depth < 8 do
        local fields = { "guid", "GUID", "unitGUID", "unitGuid" }
        for _, fieldName in ipairs(fields) do
            local candidate = f[fieldName]
            if type(candidate) == "string" and candidate ~= "" and IsResolvableUnit(candidate) then
                return candidate
            end
        end

        local logicalParent = f.parent
        if logicalParent and logicalParent ~= f
            and (type(logicalParent) == "table" or type(logicalParent) == "userdata") then
            f = logicalParent
        elseif f.GetParent then
            f = f:GetParent()
        else
            f = nil
        end
        depth = depth + 1
    end

    return nil
end

local function IsHealingSpell(spellID, spellName)
    if not spellID or not spellName then
        return false
    end

    if MouseoverCastDB and MouseoverCastDB.allHelpful == 1 then
        return IsHelpfulSpell(spellID) and true or false
    end

    return knownHealingNames[spellName] == 1
end

local function BuildCastName(name, rank)
    if not name then
        return nil
    end

    if rank and rank ~= "" then
        return name .. "(" .. rank .. ")"
    end

    return name
end

local function RestoreTargetByGUID(hadTarget, targetGUID)
    if targetGUID and type(TargetUnit) == "function" then
        local ok = pcall(TargetUnit, targetGUID)
        if ok and UnitExists("target") then
            if type(UnitGUID) ~= "function" or UnitGUID("target") == targetGUID then
                return
            end
        end
    end

    if hadTarget and type(TargetLastTarget) == "function" then
        TargetLastTarget()
    elseif not hadTarget and type(ClearTarget) == "function" then
        ClearTarget()
    end
end

local function ResolveStableGUID(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end

    -- Prefer UnitGUID when the client accepts the supplied token.
    if type(UnitGUID) == "function" then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and guid then
            return guid
        end
    end

    -- SuperWoW extends UnitExists(unit) with the GUID as its second return
    -- value. This is especially important for Cursive-style frames, which
    -- store a bare GUID on the row instead of a normal unit token.
    if type(UnitExists) == "function" then
        local ok, exists, guid = pcall(UnitExists, unit)
        if ok and exists and guid then
            return guid
        end
    end

    -- A resolvable SuperWoW GUID can itself be used as the stable identity.
    if string.find(unit, "^0x") and IsResolvableUnit(unit) then
        return unit
    end

    return nil
end

-- Warlock pet servers can acknowledge an attack after the first confirmation
-- interval.  Re-targeting the player to "help" can cancel/replace that order.
local function IsWarlock()
    if type(UnitClass) ~= "function" then return false end
    local _, classToken = UnitClass("player")
    return classToken == "WARLOCK"
end

-- Small, opt-in trace. Do not spam raid chat or frame updates.
local petTrace = {}
local function PetTrace(message, wanted)
    local now = GetTime and GetTime() or 0
    local entry = string.format("%.2f %s wanted=%s target=%s pet=%s",
        now, tostring(message), tostring(wanted),
        tostring(ResolveStableGUID("target")),
        tostring(ResolveStableGUID("pettarget")))
    table.insert(petTrace, entry)
    if table.getn(petTrace) > 12 then table.remove(petTrace, 1) end
end

local function TargetIsGUID(guid)
    if not guid or not UnitExists("target") then
        return false
    end

    if UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, "target", guid)
        if ok and same then
            return true
        end
    end

    local current = ResolveStableGUID("target")
    return current ~= nil and current == guid
end

local function RecordPetAttempt(path, result, unit, frameGUID, selectedGUID, attackSlot, method)
    lastPetAttempt = {
        path = path or "none",
        result = result or "none",
        unit = unit,
        frameGUID = frameGUID,
        selectedGUID = selectedGUID,
        attackSlot = attackSlot,
        method = method,
        petTargetGUID = ResolveStableGUID and ResolveStableGUID("pettarget") or nil,
        time = GetTime and GetTime() or 0,
    }
end

local function VerifyTemporaryTarget(unit, frameGUID)
    if not UnitExists("target") then
        return false
    end

    if unit and UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, "target", unit)
        if ok and same then
            return true
        end
    end

    if frameGUID and UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, "target", frameGUID)
        if ok and same then
            return true
        end
    end

    if frameGUID then
        local selectedGUID = ResolveStableGUID("target")
        if selectedGUID and selectedGUID == frameGUID then
            return true
        end
    end

    return false
end

local function QueuePetTargetRestore(hadTarget, originalGUID, temporaryGUID, waitForPetConfirm)
    local now = GetTime and GetTime() or 0
    pendingPetAttack = {
        hadTarget = hadTarget and true or false,
        originalGUID = originalGUID,
        temporaryGUID = temporaryGUID,
        waitForPetConfirm = waitForPetConfirm and true or false,
        minRestoreAt = now + 0.03,
        -- Warlock demons can acknowledge the order later than Hunter pets.
        -- Don't restore until the pet has held the requested GUID stably.
        confirmAt = nil,
        settleAfterConfirm = IsWarlock() and 0.12 or 0.25,
        retryAt = now + 0.38,
        -- Warlock: one unambiguous pet command, no late automatic retry.
        retried = IsWarlock(),
        restoreDeadline = now + (IsWarlock() and 0.85 or 1.35),
        warlockFallback = IsWarlock(),
    }
end

local function TrySynchronousPetAttack(unit, frameGUID, preferredSlot)
    if type(TargetUnit) ~= "function" then
        RecordPetAttempt("none", "no-targetunit", unit, frameGUID, nil, nil, "none")
        return false
    end

    local hadTarget = UnitExists("target") and true or false
    local originalGUID = hadTarget and ResolveStableGUID("target") or nil

    local function IssueAttack(path, selectedGUID, usePetBar)
        -- Warlock beta5: The old deferred state machine held the temporary
        -- enemy as the player's visible target for up to 0.85s, then restored
        -- it later.  Repeated presses caused noticeable target bouncing and
        -- competing commands. Instead, deliver exactly ONE attack immediately
        -- while the requested enemy is selected, then restore in THIS CALL.
        -- No delayed target swaps, timers, retries, or auto re-attacks.
        if IsWarlock() then
            local slot = preferredSlot
            if not slot and type(GetPetActionInfo) == "function" then
                for i = 1, 10 do
                    local isAttack = false
                    if type(IsPetAttackAction) == "function" then
                        local okAction, result = pcall(IsPetAttackAction, i)
                        isAttack = okAction and result and true or false
                    end
                    if not isAttack then
                        local name, _, texture, isToken = GetPetActionInfo(i)
                        if name then
                            local displayName = name
                            if isToken and getglobal then
                                displayName = getglobal(name) or name
                            end
                            isAttack = name == "PET_ACTION_ATTACK" or name == "PET_ATTACK"
                                or displayName == "Attack"
                                or (type(ATTACK) == "string" and displayName == ATTACK)
                                or (type(PET_ATTACK) == "string" and displayName == PET_ATTACK)
                                or (isToken and type(texture) == "string"
                                    and (string.find(texture, "PET_ACTION_ATTACK", 1, true)
                                        or string.find(texture, "PET_ATTACK", 1, true)))
                        end
                    end
                    if isAttack then slot = i; break end
                end
            end

            local method, okAttack = "none", false
            if slot and type(OriginalCastPetAction) == "function" then
                method = "CastPetAction(" .. tostring(slot) .. ")"
                okAttack = pcall(OriginalCastPetAction, slot)
            elseif type(OriginalPetAttack) == "function" then
                method = "PetAttack"
                okAttack = pcall(OriginalPetAttack)
            end

            -- Always restore even if the pet API raised an error. This is
            -- synchronous, so the player target is not held across OnUpdate.
            if selectedGUID and TargetIsGUID(selectedGUID) then
                RestoreTargetByGUID(hadTarget, originalGUID)
            end
            RecordPetAttempt(path, okAttack and "instant-attack-issued" or "instant-attack-error",
                unit, frameGUID, selectedGUID, slot, method)
            PetTrace((okAttack and "warlock-instant-attack via=" or "warlock-instant-error via=")
                .. method, selectedGUID or frameGUID)
            pendingPetAttack = nil
            return okAttack
        end
        if usePetBar then
            local slot = preferredSlot

            -- This function is intentionally self-contained because the normal
            -- FindPetAttackSlot helper is declared later in this Lua file.
            if not slot and type(GetPetActionInfo) == "function" then
                for i = 1, 10 do
                    local isAttack = false
                    if type(IsPetAttackAction) == "function" then
                        local okAttack, result = pcall(IsPetAttackAction, i)
                        isAttack = okAttack and result and true or false
                    end

                    if not isAttack then
                        local name, subtext, texture, isToken = GetPetActionInfo(i)
                        if name then
                            local localizedName = name
                            if isToken and getglobal then
                                localizedName = getglobal(name) or name
                            end
                            if name == "PET_ACTION_ATTACK" or name == "PET_ATTACK"
                                or localizedName == "Attack"
                                or (type(ATTACK) == "string" and localizedName == ATTACK)
                                or (type(PET_ATTACK) == "string" and localizedName == PET_ATTACK) then
                                isAttack = true
                            elseif isToken and type(texture) == "string"
                                and (string.find(texture, "PET_ACTION_ATTACK", 1, true)
                                    or string.find(texture, "PET_ATTACK", 1, true)) then
                                isAttack = true
                            end
                        end
                    end

                    if isAttack then
                        slot = i
                        break
                    end
                end
            end

            if slot and type(OriginalCastPetAction) == "function" then
                -- The 1.12 pet engine may need a frame for the temporary target
                -- to register. Save the original target and ALWAYS restore it.
                -- Issue ONE pet attack command, not a pet-bar command AND a
                -- PetAttack() in the same frame: some Warlock demons oscillate
                -- between the old and new targets after the double order.
                local now = GetTime and GetTime() or 0
                pendingPetAttack = {
                    phase = "attack",
                    attackAt = now + 0.08,
                    temporaryGUID = selectedGUID or frameGUID,
                    hadTarget = hadTarget,
                    originalGUID = originalGUID,
                    slot = slot,
                    unit = unit,
                    frameGUID = frameGUID,
                    attackMode = "petbar",
                    warlockFallback = IsWarlock(),
                }
                RecordPetAttempt(path, "delayed-attack-queued", unit, frameGUID, selectedGUID, slot, "CastPetAction")
                return true
            end
        end

        OriginalPetAttack()
        RecordPetAttempt(path, "petattack-issued", unit, frameGUID, selectedGUID, nil, "PetAttack")
        QueuePetTargetRestore(hadTarget, originalGUID, selectedGUID or frameGUID, true)
        return true
    end

    -- For addon UI rows (Cursive/Decursive/etc.) use the pet action bar command
    -- itself instead of the vanilla PetAttack() function.  Vanilla-era macro
    -- addons traditionally use CastPetAction(attackSlot) for reliable pet attack.
    -- Keep the temporary target until pettarget confirms the command.
    local usePetBar = frameGUID ~= nil

    if unit then
        local ok = pcall(TargetUnit, unit)
        local selectedGUID = ResolveStableGUID("target")
        if ok and VerifyTemporaryTarget(unit, frameGUID) and UnitIsValidEnemy("target") then
            return IssueAttack("unit", selectedGUID, usePetBar)
        end
        RecordPetAttempt("unit", ok and "verify-failed" or "target-error", unit, frameGUID, selectedGUID, nil, "none")
    end

    if frameGUID and frameGUID ~= unit then
        local ok = pcall(TargetUnit, frameGUID)
        local selectedGUID = ResolveStableGUID("target")
        if ok and VerifyTemporaryTarget(nil, frameGUID) and UnitIsValidEnemy("target") then
            return IssueAttack("frame-guid", selectedGUID, true)
        end
        RecordPetAttempt("frame-guid", ok and "verify-failed" or "target-error", unit, frameGUID, selectedGUID, nil, "none")
    end

    RestoreTargetByGUID(hadTarget, originalGUID)
    return false
end

local function UpdatePendingPetAttack()
    local pending = pendingPetAttack
    if not pending then
        return
    end

    local now = GetTime and GetTime() or 0

    -- Prefer no-target-switch pet commands. Only fall back to the temporary
    -- target transaction when the pet did not actually acquire the GUID.
    if pending.phase == "verify-direct" then
        local petGUID = ResolveStableGUID("pettarget")
        if petGUID and petGUID == pending.temporaryGUID then
            if not pending.confirmAt then pending.confirmAt = now end
            if now >= pending.confirmAt + (pending.settleAfterConfirm or 0) then
                lastPetAttempt.result = "direct-pet-confirmed-stable"
                lastPetAttempt.petTargetGUID = petGUID
                PetTrace("direct-confirmed", pending.temporaryGUID)
                pendingPetAttack = nil
            end
            return
        end
        -- The pet briefly switched and went back to the previous enemy.
        -- That isn't a confirmed attack; allow the normal fallback.
        pending.confirmAt = nil
        -- Don't retarget behind the user's back if they changed target after
        -- pressing the key. Checking the GUID also avoids unreliable names.
        local currentTargetGUID = ResolveStableGUID("target")
        if currentTargetGUID ~= pending.originalGUID then
            lastPetAttempt.result = "direct-unconfirmed-user-target-changed"
            pendingPetAttack = nil
            return
        end
        if now < (pending.verifyAt or 0) then
            return
        end

        -- Critical Warlock safeguard: never issue a second PetAttack against
        -- a temporarily selected target here. A late daemon acknowledgment
        -- can be overwritten by that fallback, sending it back to old enemy.
        if pending.warlockDirectOnly then
            PetTrace("warlock-unconfirmed-no-target-swap", pending.temporaryGUID)
            lastPetAttempt.result = "warlock-direct-unconfirmed"
            pendingPetAttack = nil
            return
        end

        local wantedUnit = pending.unit
        local wantedGUID = pending.temporaryGUID
        local wantedSlot = pending.slot
        pendingPetAttack = nil
        if not IsResolvableUnit(wantedGUID) or not UnitIsValidEnemy(wantedGUID) then
            lastPetAttempt.result = "direct-unconfirmed-unit-gone"
            return
        end
        if not TrySynchronousPetAttack(wantedUnit, wantedGUID, wantedSlot) then
            lastPetAttempt.result = "direct-fallback-failed"
        end
        return
    end

    if pending.phase == "attack" then
        if pending.temporaryGUID and not TargetIsGUID(pending.temporaryGUID) then
            -- Another click/key changed the target: never override the player.
            lastPetAttempt.result = "delayed-target-lost"
            pendingPetAttack = nil
            return
        end
        if now < (pending.attackAt or 0) then
            return
        end

        -- Beta3 queued the pet-bar attack but accidentally invoked PetAttack()
        -- here instead of CastPetAction(slot). That bypassed the intended
        -- dispatch route entirely. Send EXACTLY ONE command on the attack slot.
        local attackMethod = "PetAttack"
        if pending.attackMode == "petbar" and pending.slot
            and type(OriginalCastPetAction) == "function" then
            OriginalCastPetAction(pending.slot)
            attackMethod = "CastPetAction(" .. tostring(pending.slot) .. ")"
        elseif type(OriginalPetAttack) == "function" then
            OriginalPetAttack()
        end
        lastPetAttempt.result = "delayed-attack-issued-awaiting-restore"
        if pending.warlockFallback then
            PetTrace("warlock-fallback-attack-issued via=" .. attackMethod,
                pending.temporaryGUID)
        end
        lastPetAttempt.method = attackMethod
        lastPetAttempt.petTargetGUID = ResolveStableGUID("pettarget")

        -- Important: do NOT leave phase=attack, as the old diagnostic did.
        -- Wait briefly for the pet to confirm, then restore even on timeout.
        pending.phase = "restore"
        pending.waitForPetConfirm = true
        pending.minRestoreAt = now + 0.02
        pending.confirmAt = nil
        pending.settleAfterConfirm = pending.warlockFallback and 0.12 or 0.25
        pending.retryAt = now + 0.38
        pending.retried = pending.warlockFallback and true or false
        pending.restoreDeadline = now + (pending.warlockFallback and 0.85 or 1.35)
        return
    end
    local temporaryStillSelected = (not pending.temporaryGUID) or TargetIsGUID(pending.temporaryGUID)

    -- If the player changed target manually, never fight that change.
    if not temporaryStillSelected then
        if lastPetAttempt then
            lastPetAttempt.result = "target-changed"
            lastPetAttempt.petTargetGUID = ResolveStableGUID("pettarget")
        end
        pendingPetAttack = nil
        return
    end

    local petTargetGUID = ResolveStableGUID("pettarget")
    if lastPetAttempt then
        lastPetAttempt.petTargetGUID = petTargetGUID
    end

    local confirmed = pending.temporaryGUID and petTargetGUID and petTargetGUID == pending.temporaryGUID
    local deadline = now >= (pending.restoreDeadline or 0)

    if pending.waitForPetConfirm then
        if confirmed then
            if not pending.confirmAt then
                pending.confirmAt = now
                if lastPetAttempt then
                    lastPetAttempt.result = "pet-confirmed-holding"
                end
            end

            -- pettarget can flip before the actual attack command has fully
            -- settled. Keep the temporary target for a short grace period.
            if now < pending.confirmAt + (pending.settleAfterConfirm or 0) and not deadline then
                return
            end
        else
            -- A late pet response (or brief switch back to the prior target)
            -- must restart the stability window. Retry at most once, only
            -- while our temporary enemy is still the player's selected target.
            pending.confirmAt = nil
            if not pending.retried and now >= (pending.retryAt or 0) and not deadline then
                pending.retried = true
                if type(OriginalPetAttack) == "function" then
                    OriginalPetAttack()
                    if lastPetAttempt then
                        lastPetAttempt.result = "petattack-retry-awaiting-confirmation"
                        lastPetAttempt.method = "PetAttack+one-retry"
                    end
                end
            end
            if not deadline then return end
        end
    elseif now < (pending.minRestoreAt or 0) then
        return
    end

    RestoreTargetByGUID(pending.hadTarget, pending.originalGUID)
    if pending.warlockFallback then
        PetTrace(confirmed and "warlock-restored-pet-confirmed" or "warlock-restored-unconfirmed", pending.temporaryGUID)
    end
    if lastPetAttempt then
        if confirmed then
            lastPetAttempt.result = "pet-confirmed-settled-restored"
        elseif pending.waitForPetConfirm then
            lastPetAttempt.result = "pet-unconfirmed-timeout-restored"
        else
            lastPetAttempt.result = "restored"
        end
    end

    pendingPetAttack = nil
end

local function FindPetAttackSlot()
    if type(GetPetActionInfo) ~= "function" then
        return nil
    end

    for slot = 1, 10 do
        -- Keep this self-contained because IsPetAttackBarAction is declared
        -- later in the file.
        if type(IsPetAttackAction) == "function" then
            local ok, result = pcall(IsPetAttackAction, slot)
            if ok and result then
                return slot
            end
        end

        local name, subtext, texture, isToken = GetPetActionInfo(slot)
        if name then
            local localizedName = name
            if isToken and getglobal then
                localizedName = getglobal(name) or name
            end

            if name == "PET_ACTION_ATTACK" or name == "PET_ATTACK"
                or localizedName == "Attack"
                or (type(ATTACK) == "string" and localizedName == ATTACK)
                or (type(PET_ATTACK) == "string" and localizedName == PET_ATTACK) then
                return slot
            end

            if isToken and type(texture) == "string" then
                if string.find(texture, "PET_ACTION_ATTACK", 1, true)
                    or string.find(texture, "PET_ATTACK", 1, true) then
                    return slot
                end
            end
        end
    end

    return nil
end

local function TryConditionalPetAttack(unit)
    if not unit or type(unit) ~= "string" or unit == "" then
        return false
    end
    if type(SlashCmdList) ~= "table" then return false end

    -- ClassicAPI and SuperCleveRoidMacros may both register /petattack.
    -- Prefer the native ClassicAPI conditional handler: no extra macro addon
    -- needs to be installed. The Cursive frame GUID is passed explicitly.
    local handler = nil
    local handlerName = nil
    if IsWarlock() and type(SlashCmdList["PET_ATTACK"]) == "function" then
        handler = SlashCmdList["PET_ATTACK"]
        handlerName = "ClassicAPI"
    elseif type(SlashCmdList["PETATTACK"]) == "function" then
        handler = SlashCmdList["PETATTACK"]
        handlerName = "CleveRoid"
    elseif type(SlashCmdList["PET_ATTACK"]) == "function" then
        handler = SlashCmdList["PET_ATTACK"]
        handlerName = "ClassicAPI"
    end
    if not handler then
        PetTrace("no-conditional-handler", unit)
        return false
    end

    local message = "[@" .. unit .. "]"
    petCommandDispatch = true
    local ok, result = pcall(handler, message)
    petCommandDispatch = false
    -- A pcall succeeding is not proof that /petattack actually ran. Some
    -- providers return false when their conditional did not resolve. Nil is
    -- common for legitimate slash handlers and is verified asynchronously.
    PetTrace("conditional-" .. handlerName .. (ok and (result == false and "-rejected" or "-sent") or "-error"), unit)
    return ok and result ~= false
end

-- Repeated keypresses must not create overlapping transactions. In particular,
-- a pending fallback may have temporarily selected the enemy under the cursor.
-- Restore that target before starting a different request, but do not touch a
-- target changed manually by the player.
local function CancelPendingPetAttack()
    local pending = pendingPetAttack
    if not pending then return end
    if pending.phase ~= "verify-direct" and pending.temporaryGUID
        and TargetIsGUID(pending.temporaryGUID) then
        RestoreTargetByGUID(pending.hadTarget, pending.originalGUID)
    end
    pendingPetAttack = nil
end

local function TryMouseoverPetAttack(preferredSlot)
    if not MouseoverCastDB or MouseoverCastDB.petAttack ~= 1 then
        return false
    end

    if not HasClassicAPI() or not HasSuperWoW() or type(OriginalPetAttack) ~= "function" then
        return false
    end

    if not UnitExists("pet") then
        return false
    end

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("pet") then
        return false
    elseif UnitIsDead and UnitIsDead("pet") then
        return false
    end

    local unit = ResolveMouseoverUnit()
    if not unit or not UnitIsValidEnemy(unit) then
        RecordPetAttempt("none", "invalid-mouseover", unit, ResolveHoveredFrameGUID(), nil)
        return false
    end

    local frameGUID = ResolveHoveredFrameGUID()
    local mouseoverGUID = ResolveStableGUID(unit)

    local expectedGUID = frameGUID or mouseoverGUID

    -- Key mashing must not race a queued attack against its own target restore.
    -- Same enemy: let the existing command settle. Different enemy: cancel
    -- and restore the temporary player target before starting a fresh command.
    if pendingPetAttack then
        if expectedGUID and pendingPetAttack.temporaryGUID == expectedGUID then
            if IsWarlock() and pendingPetAttack.phase == "verify-direct"
                and (GetTime and GetTime() or 0) >= (pendingPetAttack.manualReissueAt or 0)
                and ResolveStableGUID("pettarget") ~= expectedGUID then
                -- An explicit second keypress may reissue after a safe delay;
                -- rapid key mashing must not generate overlapping requests.
                PetTrace("warlock-manual-reissue", expectedGUID)
                pendingPetAttack = nil
            else
                return true
            end
        else
            CancelPendingPetAttack()
        end
    end

    -- If this is already the selected target, do not touch targeting at all.
    if UnitExists("target") and UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, "target", unit)
        if ok and same then
            OriginalPetAttack()
            PetTrace("already-target-issued", expectedGUID)
            RecordPetAttempt("already-target", "attacked", unit, frameGUID, ResolveStableGUID("target"))
            return true
        end
    end

    -- Warlock correction: original Vanilla 1.12 PetAttack() takes NO unit
    -- argument. ClassicAPI's /petattack conditional ultimately reaches our
    -- wrapped global, but the underlying pet order still attacks the current
    -- selected target. Thus a successful slash handler can silently command
    -- the demon to the OLD target. For a valid Cursive row, skip that handler
    -- and use the verified, short-lived TargetUnit(GUID) transaction instead.
    -- This is the only vanilla API path that gives the pet the selected GUID.
    if IsWarlock() then
        if not expectedGUID or not IsResolvableUnit(expectedGUID) then
            RecordPetAttempt("warlock", "unresolved-hover-guid", unit, expectedGUID,
                ResolveStableGUID("target"), preferredSlot, "none")
            PetTrace("warlock-guid-unresolved", expectedGUID)
            return false
        end
        -- Keep the hovered frame identity in the trace. If two different
        -- Cursive rows produce the same wanted GUID, targeting is at fault;
        -- if wanted changes while pettarget does not, dispatch is at fault.
        local focus = GetMouseFocus and GetMouseFocus() or nil
        local focusName = focus and focus.GetName and focus:GetName() or "nil"
        PetTrace("warlock-fallback-request focus=" .. tostring(focusName)
            .. " unit=" .. tostring(unit)
            .. " frame=" .. tostring(frameGUID), expectedGUID)
        if TrySynchronousPetAttack(unit, expectedGUID, preferredSlot) then
            return true
        end
        PetTrace("warlock-fallback-target-verify-failed", expectedGUID)
        return false
    end

    -- Hunter: keep the existing direct conditional path and fallback.
    -- A slash handler returning successfully does not guarantee its pet
    -- attack actually took effect, so verify pettarget asynchronously.
    -- Don't try to cast on fake Cursive test-overlay rows.
    local directOriginalGUID = ResolveStableGUID("target")
    local directHadTarget = UnitExists("target") and true or false
    if expectedGUID and TryConditionalPetAttack(unit) then
        -- A third-party slash handler may temporarily select the unit itself.
        -- The direct path must never leave that change on the player.
        if ResolveStableGUID("target") ~= directOriginalGUID then
            RestoreTargetByGUID(directHadTarget, directOriginalGUID)
        end
        pendingPetAttack = {
            phase = "verify-direct",
            originalGUID = directOriginalGUID,
            temporaryGUID = expectedGUID,
            unit = unit,
            slot = preferredSlot,
            verifyAt = (GetTime and GetTime() or 0) + (IsWarlock() and 0.95 or 0.20),
            manualReissueAt = (GetTime and GetTime() or 0) + 0.55,
            warlockDirectOnly = IsWarlock(),
            confirmAt = nil,
            settleAfterConfirm = IsWarlock() and 0.40 or 0.25,
        }
        RecordPetAttempt("direct-unit", "direct-verifying", unit, expectedGUID,
            ResolveStableGUID("target"), preferredSlot, "ConditionalPetAttack")
        return true
    end

    -- 1.12 fallback: select only for the pet command and restore the original
    -- target after confirmation/short timeout. No permanent target switch.
    if TrySynchronousPetAttack(unit, expectedGUID, preferredSlot) then
        return true
    end

    return false
end

local function IsPetAttackBarAction(slot)
    if type(GetPetActionInfo) ~= "function" then
        return false
    end

    -- ClassicAPI/newer clients may expose this helper. Prefer it when present.
    if type(IsPetAttackAction) == "function" then
        local ok, result = pcall(IsPetAttackAction, slot)
        if ok and result then
            return true
        end
    end

    local name, subtext, texture, isToken = GetPetActionInfo(slot)
    if not name then
        return false
    end

    if name == "PET_ACTION_ATTACK" or name == "PET_ATTACK" then
        return true
    end

    local localizedName = name
    if isToken and getglobal then
        localizedName = getglobal(name) or name
    end

    if localizedName == "Attack" then
        return true
    end
    if type(ATTACK) == "string" and localizedName == ATTACK then
        return true
    end
    if type(PET_ATTACK) == "string" and localizedName == PET_ATTACK then
        return true
    end

    -- Tokenized command textures vary slightly between 1.12 UI builds.
    if isToken and type(texture) == "string" then
        if string.find(texture, "PET_ACTION_ATTACK", 1, true) or string.find(texture, "PET_ATTACK", 1, true) then
            return true
        end
    end

    return false
end

local function TryMouseoverCastBySpellID(spellID)
    if not MouseoverCastDB then
        return false
    end

    if MouseoverCastDB.enabled ~= 1 and MouseoverCastDB.offensive ~= 1 then
        return false
    end

    if not HasClassicAPI() or not HasSuperWoW() then
        return false
    end

    local name, rank = GetSpellInfo(spellID)
    if not name then
        return false
    end

    local unit = ResolveMouseoverUnit()
    if not unit then
        return false
    end

    local shouldCast = false

    -- Friendly mouseover healing/protection. Only approved heal and defensive
    -- spell families are redirected, so ordinary buffs keep normal behavior.
    if MouseoverCastDB.enabled == 1 and IsHealingSpell(spellID, name) and UnitIsValidFriendly(unit) then
        shouldCast = true
    end

    -- Offensive mouseover casting. ClassicAPI classifies harmful spells from
    -- Spell.dbc, so this covers damage spells, DoTs and hostile CC without a
    -- hard-coded class/spell list. Auto attack, items and macros never reach
    -- this path because GetActionInfo() only forwards spell actions.
    if not shouldCast and MouseoverCastDB.offensive == 1 and IsHarmfulSpell(spellID) and UnitIsValidEnemy(unit) then
        shouldCast = true
    end

    if not shouldCast then
        return false
    end

    local castName = BuildCastName(name, rank)
    if not castName then
        return false
    end

    -- SuperWoW extension: CastSpellByName(spell, unit)
    OriginalCastSpellByName(castName, unit)
    return true
end

-- Global action-bar hook. This is what allows normal spell buttons to behave
-- like mouseover heals without converting them into macros.
function UseAction(slot, checkCursor, onSelf)
    -- In Lua, numeric 0 is truthy. Treat only an explicit 1/true as self-cast.
    local explicitSelfCast = (onSelf == 1 or onSelf == true)
    if MouseoverCastDB and (MouseoverCastDB.enabled == 1 or MouseoverCastDB.offensive == 1) and not explicitSelfCast and HasClassicAPI() then
        local actionType, actionID = GetActionInfo(slot)
        if actionType == "spell" and actionID then
            if TryMouseoverCastBySpellID(actionID) then
                return
            end
        end
    end

    return OriginalUseAction(slot, checkCursor, onSelf)
end

-- Also support clicking a healing spell directly in the spellbook.
function CastSpell(spellBookSlot, bookType)
    if MouseoverCastDB and (MouseoverCastDB.enabled == 1 or MouseoverCastDB.offensive == 1) and HasClassicAPI() then
        local _, _, _, _, _, _, _, _, _, spellID = GetSpellInfo(spellBookSlot, bookType)
        if spellID and TryMouseoverCastBySpellID(spellID) then
            return
        end
    end

    return OriginalCastSpell(spellBookSlot, bookType)
end

-- Default Pet Attack keybinds and /script PetAttack() pass through this
-- global. When no explicit unit is supplied, redirect it to hostile mouseover.
function PetAttack(unit)
    -- ClassicAPI's PET_ATTACK handler ultimately reaches PetAttack(). Avoid
    -- wrapping that internal call again or we'd recurse back into the handler.
    if petCommandDispatch then
        return OriginalPetAttack()
    end

    -- Preserve explicit unit requests by routing them through ClassicAPI's
    -- conditional pet handler whenever possible.
    if unit ~= nil then
        if UnitIsValidEnemy(unit) and TryConditionalPetAttack(unit) then
            return
        end
        return OriginalPetAttack()
    end

    if TryMouseoverPetAttack() then
        return
    end
    if IsWarlock() and MouseoverCastDB and MouseoverCastDB.petAttack == 1 then
        local hoveredUnit = ResolveMouseoverUnit()
        if hoveredUnit and UnitIsValidEnemy(hoveredUnit) then
            -- No silent attack on the player's old target if a hovered enemy
            -- exists but could not be dispatched by the target-preserving path.
            PetTrace("warlock-block-wrong-target", hoveredUnit)
            return
        end
    end
    return OriginalPetAttack()
end

-- Clicking the Attack command on the pet action bar (or macros using
-- CastPetAction on that slot) normally bypasses PetAttack(), so catch it too.
-- IMPORTANT: keep the optional unit argument; v1.0.3 accidentally swallowed it.
function CastPetAction(slot, unit)
    if petCommandDispatch then
        return OriginalCastPetAction(slot)
    end

    if unit ~= nil and IsPetAttackBarAction(slot) then
        if UnitIsValidEnemy(unit) and TryConditionalPetAttack(unit) then
            return
        end
    end

    if MouseoverCastDB and MouseoverCastDB.petAttack == 1 and IsPetAttackBarAction(slot) then
        if TryMouseoverPetAttack(slot) then
            return
        end
    end

    if IsWarlock() and MouseoverCastDB and MouseoverCastDB.petAttack == 1
        and IsPetAttackBarAction(slot) then
        local hoveredUnit = ResolveMouseoverUnit()
        if hoveredUnit and UnitIsValidEnemy(hoveredUnit) then
            PetTrace("warlock-block-wrong-petbar-target", hoveredUnit)
            return
        end
    end
    return OriginalCastPetAction(slot)
end

local optionsPanel = nil
local optionsHealing = nil
local optionsOffensive = nil
local optionsPetAttack = nil
local optionsNavButton = nil
local optionsNavLabel = nil
local nativeContentScroll = nil
local optionsHooked = nil
local optionProbeElapsed = 0
local hookedNavButtons = {}

local function RefreshNativeControlsOption()
    if not MouseoverCastDB then
        return
    end

    if optionsHealing then
        if MouseoverCastDB.enabled == 1 then
            optionsHealing:SetChecked(1)
        else
            optionsHealing:SetChecked(nil)
        end
    end

    if optionsOffensive then
        if MouseoverCastDB.offensive == 1 then
            optionsOffensive:SetChecked(1)
        else
            optionsOffensive:SetChecked(nil)
        end
    end

    if optionsPetAttack then
        if MouseoverCastDB.petAttack == 1 then
            optionsPetAttack:SetChecked(1)
        else
            optionsPetAttack:SetChecked(nil)
        end
    end
end

local function GetFrameTextSafe(f)
    if not f then
        return nil
    end

    if f.GetText then
        local text = f:GetText()
        if text and text ~= "" then
            return text
        end
    end

    if f.GetRegions then
        local regions = { f:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetText then
                local text = region:GetText()
                if text and text ~= "" then
                    return text
                end
            end
        end
    end

    return nil
end

local function GetTextRegionSafe(f)
    if not f or not f.GetRegions then
        return nil
    end

    local regions = { f:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
            local text = region:GetText()
            if text and text ~= "" then
                return region
            end
        end
    end

    return nil
end

local function WalkChildren(root, callback, depth)
    if not root or not root.GetChildren then
        return
    end

    depth = depth or 0
    if depth > 8 then
        return
    end

    local children = { root:GetChildren() }
    for _, child in ipairs(children) do
        callback(child)
        WalkChildren(child, callback, depth + 1)
    end
end

local function FrameReallyVisible(f)
    if not f then
        return false
    end
    if f.IsVisible then
        return f:IsVisible()
    end
    if f.IsShown then
        return f:IsShown()
    end
    return true
end

local function FindLargestVisibleScrollFrame(root)
    local best = nil
    local bestArea = 0

    WalkChildren(root, function(child)
        if child and child.GetObjectType and child:GetObjectType() == "ScrollFrame" and FrameReallyVisible(child) then
            local w = child.GetWidth and child:GetWidth() or 0
            local h = child.GetHeight and child:GetHeight() or 0
            local area = w * h
            if w >= 220 and h >= 180 and area > bestArea then
                best = child
                bestArea = area
            end
        end
    end)

    return best
end

local function FindButtonByText(root, wanted1, wanted2)
    local found = nil
    WalkChildren(root, function(child)
        if found or not child or not child.GetObjectType or child:GetObjectType() ~= "Button" then
            return
        end

        local text = GetFrameTextSafe(child)
        if text == wanted1 or (wanted2 and text == wanted2) then
            found = child
        end
    end)
    return found
end

local function CreateStandaloneOptionsPanel(root, anchorScroll)
    if optionsPanel then
        if anchorScroll then
            optionsPanel:ClearAllPoints()
            optionsPanel:SetPoint("TOPLEFT", anchorScroll, "TOPLEFT", 0, 0)
            optionsPanel:SetPoint("BOTTOMRIGHT", anchorScroll, "BOTTOMRIGHT", 0, 0)
        end
        return optionsPanel
    end

    local panel = CreateFrame("Frame", "MouseoverCastOptionsPanel", root)
    panel:SetFrameLevel((anchorScroll and anchorScroll.GetFrameLevel and anchorScroll:GetFrameLevel() or root:GetFrameLevel()) + 2)
    if anchorScroll then
        panel:SetPoint("TOPLEFT", anchorScroll, "TOPLEFT", 0, 0)
        panel:SetPoint("BOTTOMRIGHT", anchorScroll, "BOTTOMRIGHT", 0, 0)
    else
        panel:SetPoint("TOPLEFT", root, "TOPLEFT", 210, -42)
        panel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -28, 48)
    end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -22)
    title:SetText("MouseoverCast")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    subtitle:SetWidth(330)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Macro-free mouseover casting. Normal target casting is used whenever no valid mouseover target exists.")

    local heal = CreateFrame("CheckButton", "MouseoverCastOptionsHealing", panel, "UICheckButtonTemplate")
    heal:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -4, -24)
    local healText = getglobal("MouseoverCastOptionsHealingText")
    if healText then
        healText:SetText("Mouseover Healing")
        healText:SetTextColor(1, 0.82, 0)
    end
    heal:SetScript("OnClick", function()
        if this:GetChecked() then
            MouseoverCastDB.enabled = 1
        else
            MouseoverCastDB.enabled = 0
        end
    end)
    heal:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Mouseover Healing", 1, 1, 1)
        GameTooltip:AddLine("Healing and supported protection spells cast on the friendly unit under your mouse cursor. With no valid friendly mouseover, normal casting is used.", 0.8, 0.8, 0.8, 1)
        GameTooltip:Show()
    end)
    heal:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local offensive = CreateFrame("CheckButton", "MouseoverCastOptionsOffensive", panel, "UICheckButtonTemplate")
    offensive:SetPoint("TOPLEFT", heal, "BOTTOMLEFT", 0, -8)
    local offensiveText = getglobal("MouseoverCastOptionsOffensiveText")
    if offensiveText then
        offensiveText:SetText("Mouseover Offensive Spells")
        offensiveText:SetTextColor(1, 0.82, 0)
    end
    offensive:SetScript("OnClick", function()
        if this:GetChecked() then
            MouseoverCastDB.offensive = 1
        else
            MouseoverCastDB.offensive = 0
        end
    end)
    offensive:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Mouseover Offensive Spells", 1, 1, 1)
        GameTooltip:AddLine("Harmful spells cast on the hostile unit under your mouse cursor while your current target stays selected. With no valid hostile mouseover, normal casting is used.", 0.8, 0.8, 0.8, 1)
        GameTooltip:Show()
    end)
    offensive:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local petAttack = CreateFrame("CheckButton", "MouseoverCastOptionsPetAttack", panel, "UICheckButtonTemplate")
    petAttack:SetPoint("TOPLEFT", offensive, "BOTTOMLEFT", 0, -8)
    local petAttackText = getglobal("MouseoverCastOptionsPetAttackText")
    if petAttackText then
        petAttackText:SetText("Mouseover Pet Attack")
        petAttackText:SetTextColor(1, 0.82, 0)
    end
    petAttack:SetScript("OnClick", function()
        if this:GetChecked() then
            MouseoverCastDB.petAttack = 1
        else
            MouseoverCastDB.petAttack = 0
        end
    end)
    petAttack:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Mouseover Pet Attack", 1, 1, 1)
        GameTooltip:AddLine("Pet Attack commands attack the hostile unit under your mouse cursor while your current target is restored immediately. Works with the normal Pet Attack keybind, the pet bar Attack button and /script PetAttack().", 0.8, 0.8, 0.8, 1)
        GameTooltip:Show()
    end)
    petAttack:SetScript("OnLeave", function() GameTooltip:Hide() end)

    optionsPanel = panel
    optionsHealing = heal
    optionsOffensive = offensive
    optionsPetAttack = petAttack
    panel:Hide()
    RefreshNativeControlsOption()
    return panel
end

local function UnlockOtherNavButtons(parent)
    if not parent or not parent.GetChildren then
        return
    end

    local children = { parent:GetChildren() }
    for _, child in ipairs(children) do
        if child ~= optionsNavButton and child.UnlockHighlight then
            child:UnlockHighlight()
        end
    end
end

local function HideStandalonePanel()
    if optionsPanel then
        optionsPanel:Hide()
    end
    if optionsNavButton and optionsNavButton.UnlockHighlight then
        optionsNavButton:UnlockHighlight()
    end
    if nativeContentScroll then
        nativeContentScroll:Show()
    end
end

local function ShowStandalonePanel()
    local root = getglobal("OptionsFrame")
    if not root then
        return
    end

    -- Remember the native right-hand content area while it is visible, then
    -- replace only that area. The left navigation, search bar and OK/Cancel
    -- buttons remain untouched.
    local liveScroll = FindLargestVisibleScrollFrame(root)
    if liveScroll and liveScroll ~= optionsPanel then
        nativeContentScroll = liveScroll
    end

    if not nativeContentScroll then
        return
    end

    CreateStandaloneOptionsPanel(root, nativeContentScroll)
    optionsPanel:ClearAllPoints()
    optionsPanel:SetPoint("TOPLEFT", nativeContentScroll, "TOPLEFT", 0, 0)
    optionsPanel:SetPoint("BOTTOMRIGHT", nativeContentScroll, "BOTTOMRIGHT", 0, 0)

    nativeContentScroll:Hide()
    optionsPanel:Show()
    RefreshNativeControlsOption()

    if optionsNavButton then
        UnlockOtherNavButtons(optionsNavButton:GetParent())
        if optionsNavButton.LockHighlight then
            optionsNavButton:LockHighlight()
        end
    end
end

local function HookNativeNavigationButtons(navParent)
    if not navParent or not navParent.GetChildren then
        return
    end

    local children = { navParent:GetChildren() }
    for _, child in ipairs(children) do
        if child ~= optionsNavButton and child.GetObjectType and child:GetObjectType() == "Button" and GetFrameTextSafe(child) then
            if not hookedNavButtons[child] then
                local old = child:GetScript("OnClick")
                hookedNavButtons[child] = 1
                child:SetScript("OnClick", function()
                    HideStandalonePanel()
                    if old then
                        old()
                    end
                    -- Octo may swap/rebuild the right-hand ScrollFrame after
                    -- the click. Forget the old pointer so the next MouseoverCast
                    -- click discovers the live one again.
                    nativeContentScroll = FindLargestVisibleScrollFrame(getglobal("OptionsFrame")) or nativeContentScroll
                end)
            end
        end
    end
end

local function CreateStandaloneNavButton(root)
    if optionsNavButton then
        return true
    end

    local helpButton = FindButtonByText(root, "Help", "Hilfe")
    if not helpButton then
        return false
    end

    local navParent = helpButton:GetParent()
    if not navParent then
        return false
    end

    local button = CreateFrame("Button", "MouseoverCastOptionsNavButton", navParent)
    button:SetWidth(helpButton:GetWidth() or 150)
    button:SetHeight(helpButton:GetHeight() or 20)

    -- Match Octo's native vertical row spacing exactly. Anchoring directly to
    -- Help's bottom made the custom row a few pixels too tight. Instead, find
    -- the nearest native navigation button above Help and reuse the actual
    -- top-to-top distance between those two native rows. This automatically
    -- follows UI scale and any font/layout changes.
    local nativeRowStep = nil
    if navParent.GetChildren and helpButton.GetTop then
        local helpTop = helpButton:GetTop()
        local helpLeft = helpButton.GetLeft and helpButton:GetLeft() or nil
        local bestAboveTop = nil
        local siblings = { navParent:GetChildren() }
        for _, sibling in ipairs(siblings) do
            if sibling ~= helpButton and sibling ~= button and sibling.GetObjectType and sibling:GetObjectType() == "Button" and GetFrameTextSafe(sibling) and sibling.GetTop then
                local siblingTop = sibling:GetTop()
                local siblingLeft = sibling.GetLeft and sibling:GetLeft() or nil
                if helpTop and siblingTop and siblingTop > helpTop then
                    -- Stay in the same navigation column.
                    if not helpLeft or not siblingLeft or math.abs(siblingLeft - helpLeft) < 8 then
                        if not bestAboveTop or siblingTop < bestAboveTop then
                            bestAboveTop = siblingTop
                        end
                    end
                end
            end
        end
        if helpTop and bestAboveTop then
            nativeRowStep = bestAboveTop - helpTop
        end
    end

    if nativeRowStep and nativeRowStep > 0 and nativeRowStep < 40 then
        button:SetPoint("TOPLEFT", helpButton, "TOPLEFT", 0, -nativeRowStep)
    else
        -- Safe fallback for unusual skins: native rows are normally ~20 px apart.
        local fallbackStep = (helpButton:GetHeight() or 16) + 3
        button:SetPoint("TOPLEFT", helpButton, "TOPLEFT", 0, -fallbackStep)
    end

    -- Clone the visual style of Octo's native Help navigation row instead
    -- of approximating it. This keeps MouseoverCast indistinguishable from
    -- the surrounding Interface menu entries across UI scales/font packs.
    local helpHighlight = helpButton.GetHighlightTexture and helpButton:GetHighlightTexture() or nil
    local helpHighlightPath = helpHighlight and helpHighlight.GetTexture and helpHighlight:GetTexture() or nil
    if helpHighlightPath then
        button:SetHighlightTexture(helpHighlightPath)
    else
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    end

    local highlight = button:GetHighlightTexture()
    if highlight then
        if helpHighlight and helpHighlight.GetAlpha then
            highlight:SetAlpha(helpHighlight:GetAlpha() or 1)
        else
            highlight:SetAlpha(1)
        end
        if helpHighlight and helpHighlight.GetTexCoord then
            local ulx, uly, llx, lly, urx, ury, lrx, lry = helpHighlight:GetTexCoord()
            if ulx then
                highlight:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
            end
        end
        if helpHighlight and helpHighlight.GetBlendMode and highlight.SetBlendMode then
            local mode = helpHighlight:GetBlendMode()
            if mode then highlight:SetBlendMode(mode) end
        end
    end

    local helpLabel = GetTextRegionSafe(helpButton)
    local label = button:CreateFontString(nil, "ARTWORK")

    -- Copy the exact native font, size, flags, color and shadow from Help.
    if helpLabel then
        if helpLabel.GetFont then
            local font, size, flags = helpLabel:GetFont()
            if font and size then
                label:SetFont(font, size, flags)
            end
        end
        if helpLabel.GetTextColor then
            local r, g, b, a = helpLabel:GetTextColor()
            if r then label:SetTextColor(r, g, b, a or 1) end
        end
        if helpLabel.GetShadowColor and label.SetShadowColor then
            local r, g, b, a = helpLabel:GetShadowColor()
            if r then label:SetShadowColor(r, g, b, a or 1) end
        end
        if helpLabel.GetShadowOffset and label.SetShadowOffset then
            local x, y = helpLabel:GetShadowOffset()
            if x and y then label:SetShadowOffset(x, y) end
        end

        -- Reuse Help's internal anchor offsets, but anchor them to our row.
        if helpLabel.GetPoint then
            local point, relativeTo, relativePoint, x, y = helpLabel:GetPoint(1)
            if point then
                label:SetPoint(point, button, relativePoint or point, x or 0, y or 0)
            end
        end
    end

    if not label:GetPoint(1) then
        label:SetPoint("LEFT", button, "LEFT", 14, 0)
    end
    label:SetText("MouseoverCast")

    button:SetScript("OnClick", function()
        ShowStandalonePanel()
    end)

    optionsNavButton = button
    optionsNavLabel = label
    HookNativeNavigationButtons(navParent)
    button:Show()
    return true
end

local function HookOptionsFrameLifecycle(root)
    if optionsHooked or not root then
        return
    end

    local oldShow = root:GetScript("OnShow")
    root:SetScript("OnShow", function()
        if oldShow then oldShow() end
        -- Always reopen on Octo's native page. MouseoverCast remains one click
        -- away in the left navigation and never leaves the native content hidden.
        if optionsPanel then optionsPanel:Hide() end
        if optionsNavButton and optionsNavButton.UnlockHighlight then optionsNavButton:UnlockHighlight() end
        nativeContentScroll = FindLargestVisibleScrollFrame(root) or nativeContentScroll
        if nativeContentScroll then nativeContentScroll:Show() end
        CreateStandaloneNavButton(root)
    end)

    local oldHide = root:GetScript("OnHide")
    root:SetScript("OnHide", function()
        HideStandalonePanel()
        if oldHide then oldHide() end
    end)

    optionsHooked = 1
end

local function ProbeNativeOptions()
    local root = getglobal("OptionsFrame")
    if not root then
        return false
    end

    HookOptionsFrameLifecycle(root)
    local ok = CreateStandaloneNavButton(root)

    if root:IsShown() and not optionsPanel then
        nativeContentScroll = FindLargestVisibleScrollFrame(root) or nativeContentScroll
        if nativeContentScroll then
            CreateStandaloneOptionsPanel(root, nativeContentScroll)
        end
    end

    return ok
end

SLASH_MOUSEOVERCAST1 = "/moc"
SLASH_MOUSEOVERCAST2 = "/mouseovercast"
SLASH_MOUSEOVERCAST3 = "/moh"
SLASH_MOUSEOVERCAST4 = "/mouseoverheal"
SlashCmdList["MOUSEOVERCAST"] = function(msg)
    local command = string.lower(msg or "")
    -- Vanilla/1.12 clients can pass leading/trailing whitespace to slash handlers.
    command = string.gsub(command, "^%s+", "")
    command = string.gsub(command, "%s+$", "")

    if command == "on" then
        MouseoverCastDB.enabled = 1
        RefreshNativeControlsOption()
        Print("enabled.")
        return
    elseif command == "off" then
        MouseoverCastDB.enabled = 0
        RefreshNativeControlsOption()
        Print("disabled.")
        return
    elseif command == "offensive on" or command == "offense on" then
        MouseoverCastDB.offensive = 1
        RefreshNativeControlsOption()
        Print("offensive mouseover casting enabled.")
        return
    elseif command == "offensive off" or command == "offense off" then
        MouseoverCastDB.offensive = 0
        RefreshNativeControlsOption()
        Print("offensive mouseover casting disabled.")
        return
    elseif command == "petattack on" or command == "pet on" then
        MouseoverCastDB.petAttack = 1
        RefreshNativeControlsOption()
        Print("mouseover pet attack enabled.")
        return
    elseif command == "petattack off" or command == "pet off" then
        MouseoverCastDB.petAttack = 0
        RefreshNativeControlsOption()
        Print("mouseover pet attack disabled.")
        return
    elseif command == "pettrace" or command == "pet trace" then
        Print("Last Pet Attack events (oldest to newest):")
        if table.getn(petTrace) == 0 then Print("No events recorded yet.") end
        for i = 1, table.getn(petTrace) do Print(petTrace[i]) end
        return
    elseif command == "petdebug" or command == "pet debug" then
        local unit = ResolveMouseoverUnit()
        local slot = FindPetAttackSlot()
        local focusName = "nil"
        if GetMouseFocus then
            local focus = GetMouseFocus()
            if focus and focus.GetName then focusName = focus:GetName() or "<unnamed>" end
        end
        local guid = unit and ResolveStableGUID(unit) or nil
        local frameGUID = ResolveHoveredFrameGUID()
        local targetGUID = ResolveStableGUID("target")
        local exists = unit and UnitExists(unit) and "yes" or "no"
        local hostile = unit and UnitCanAttack("player", unit) and "yes" or "no"
        local classicPetHandler = type(SlashCmdList) == "table" and type(SlashCmdList["PET_ATTACK"]) == "function" and "yes" or "no"
        local clevePetHandler = type(SlashCmdList) == "table" and type(SlashCmdList["PETATTACK"]) == "function" and "yes" or "no"
        local cleveLoaded = (SRCM_LOADED or CleveRoids) and "yes" or "no"
        Print("petdebug focus=" .. tostring(focusName)
            .. " unit=" .. tostring(unit)
            .. " guid=" .. tostring(guid)
            .. " frameGuid=" .. tostring(frameGUID)
            .. " targetGuid=" .. tostring(targetGUID)
            .. " pending=" .. tostring(pendingPetAttack and (pendingPetAttack.phase or "restore") or "no")
            .. " lastPath=" .. tostring(lastPetAttempt and lastPetAttempt.path or "none")
            .. " lastResult=" .. tostring(lastPetAttempt and lastPetAttempt.result or "none")
            .. " lastSelected=" .. tostring(lastPetAttempt and lastPetAttempt.selectedGUID or nil)
            .. " lastMethod=" .. tostring(lastPetAttempt and lastPetAttempt.method or nil)
            .. " lastSlot=" .. tostring(lastPetAttempt and lastPetAttempt.attackSlot or nil)
            .. " petTargetGuid=" .. tostring(lastPetAttempt and lastPetAttempt.petTargetGUID or ResolveStableGUID("pettarget"))
            .. " exists=" .. exists
            .. " hostile=" .. hostile
            .. " attackSlot=" .. tostring(slot)
            .. " classicPet=" .. classicPetHandler
            .. " clevePet=" .. clevePetHandler
            .. " cleveLoaded=" .. cleveLoaded
            .. " classicAPI=" .. tostring(CLASSIC_API_VERSION))
        return
    elseif command == "status" or command == "" then
        local state = MouseoverCastDB.enabled == 1 and "enabled" or "disabled"
        local offensiveState = MouseoverCastDB.offensive == 1 and "enabled" or "disabled"
        local petAttackState = MouseoverCastDB.petAttack == 1 and "enabled" or "disabled"
        local navState = optionsNavButton and "yes" or "not attached yet"
        Print("healing=" .. state .. ", offensive=" .. offensiveState .. ", petattack=" .. petAttackState .. ". Interface nav=" .. navState .. ". SuperWoW=" .. (HasSuperWoW() and "yes" or "no") .. ", ClassicAPI=" .. (HasClassicAPI() and "yes" or "no"))
        return
    elseif command == "ui" then
        local root = getglobal("OptionsFrame")
        Print("UI scan: OptionsFrame=" .. (root and "yes" or "no")
            .. ", NavButton=" .. (optionsNavButton and "yes" or "no")
            .. ", RightContent=" .. (nativeContentScroll and "yes" or "no"))
        ProbeNativeOptions()
        return
    end

    Print("Commands: /moc on, /moc off, /moc offensive on/off, /moc petattack on/off, /moc petdebug, /moc pettrace, /moc status, /moc ui")
end

frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        ApplyDefaults()
        BuildHealingNameCache()
        ProbeNativeOptions()

        if not HasClassicAPI() then
            Print("ClassicAPI was not detected. Mouseover casting will stay inactive until ClassicAPI is loaded.")
        elseif not HasSuperWoW() then
            Print("SuperWoW was not detected. Mouseover casting will stay inactive until SuperWoW is loaded.")
        elseif MouseoverCastDB.quiet ~= 1 then
            Print("v" .. VERSION .. " loaded. Settings: Interface > MouseoverCast.")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        BuildHealingNameCache()
        ProbeNativeOptions()
    elseif event == "ADDON_LOADED" then
        -- The OctoWoW Options UI may be load-on-demand. Retry after every
        -- addon load; this becomes a no-op as soon as the checkbox exists.
        ProbeNativeOptions()
    end
end)

-- Some OctoWoW builds instantiate OptionsFrame lazily. Probe lightly until
-- the left-side MouseoverCast entry exists; no work is done afterwards.
frame:SetScript("OnUpdate", function()
    UpdatePendingPetAttack()

    if optionsNavButton then
        return
    end
    optionProbeElapsed = optionProbeElapsed + (arg1 or 0)
    if optionProbeElapsed >= 0.20 then
        optionProbeElapsed = 0
        ProbeNativeOptions()
    end
end)
