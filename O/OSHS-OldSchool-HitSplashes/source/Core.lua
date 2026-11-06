local ADDON_NAME = "OSHS"

OSHS = CreateFrame("Frame", "OSHSFrame", UIParent)
local HS = OSHS

local defaults = {
    enabled = true,
    showDamage = true,
    showDamageTaken = true,
    showInterrupts = true,
    showHealing = true,
    showMisses = true,
    colorBySchool = true,
    critColor = true,
    disableFloatingCombatText = true,
    useTargetFrame = true,
    scale = .9,
    textSize = 22,
    duration = 1.25,
    offsetX = 0,
    offsetY = -14,
    horizontalSpacing = 23,
    verticalSpacing = 19,
    showStatusEffects = true,
    statusShowIcons = true,
    statusTextSize = 17,
    statusDuration = 1.5,
    statusRiseDistance = 45,
    statusAnchorLocked = true,
    statusAnchorPoint = "CENTER",
    statusAnchorX = -120,
    statusAnchorY = -10,
    optionsPoint = "CENTER",
    optionsX = 0,
    optionsY = 0,
}

local damageEvents = {
    "CHAT_MSG_COMBAT_SELF_HITS",
    "CHAT_MSG_COMBAT_SELF_MISSES",
    "CHAT_MSG_COMBAT_PET_HITS",
    "CHAT_MSG_COMBAT_PET_MISSES",
    "CHAT_MSG_SPELL_SELF_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_PET_DAMAGE",
}

local incomingEvents = {
    CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = true,
    CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES = true,
    CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS = true,
    CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES = true,
    CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE = true,
    CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE = true,
    CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE = true,
}

local interruptOnlyEvents = {
    CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE = true,
    CHAT_MSG_SPELL_PARTY_DAMAGE = true,
    CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE = true,
}

local periodicDamageEvents = {
    CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE = true,
    CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE = true,
}

local petDamageEvents = {
    CHAT_MSG_COMBAT_PET_HITS = true,
    CHAT_MSG_COMBAT_PET_MISSES = true,
    CHAT_MSG_SPELL_PET_DAMAGE = true,
}

local healEvents = {
    "CHAT_MSG_SPELL_SELF_BUFF",
    "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
}

local schoolTextures = {
    physical = "Interface\\AddOns\\OSHS\\Assets\\Hitsplat-Physical.tga",
    holy = "Interface\\AddOns\\OSHS\\Assets\\Hitsplat-Holy.tga",
    fire = "Interface\\AddOns\\OSHS\\Assets\\Hitsplat-Fire.tga",
    nature = "Interface\\AddOns\\OSHS\\Assets\\Hitsplat-Nature.tga",
    frost = "Interface\\AddOns\\OSHS\\Assets\\Hitsplat-Frost.tga",
    shadow = "Interface\\AddOns\\OSHS\\Assets\\Hitsplat-Shadow.tga",
    arcane = "Interface\\AddOns\\OSHS\\Assets\\Hitsplat-Arcane.tga",
}

local plates, active, pool = {}, {}, {}
local interruptActive, interruptPool = {}, {}
local statusActive, statusPool, statusByKey = {}, {}, {}
local spellIcons = {}
local recentTargetGUIDs = {}
local pendingInterrupt
local lastWorldChildren, scanElapsed = 0, 0
local knownBossNames = {}
local nampowerHealsActive = GetNampowerVersion and true or false
local nampowerAurasActive = GetNampowerVersion and true or false
local nampowerSpellDamageActive = false
local nampowerAutoAttackActive = false
local nampowerControlledSpellActive = false
local nampowerControlledAutoActive = false
local nampowerIncomingSpellActive = false
local nampowerIncomingAutoActive = false
HS.hasClassicAPI = C_NamePlate and C_NamePlate.GetNamePlateForUnit and UnitGUID
HS.hasNampower = GetNampowerVersion and true or false

local function applyDefaults()
    if not OSHSDB then OSHSDB = {} end
    local key, value
    for key, value in pairs(defaults) do
        if OSHSDB[key] == nil then OSHSDB[key] = value end
    end
    HS.db = OSHSDB
end

local function readCVar(name)
    if not GetCVar then return nil end
    local ok, value = pcall(GetCVar, name)
    if ok and value ~= nil and value ~= "" then return tonumber(value) or value end
end

local function writeCVar(name, value)
    if SetCVar then pcall(SetCVar, name, value) end
end

function HS:ResetSettings()
    self:RestoreNativeTextSetting()
    OSHSDB = {}
    applyDefaults()
    self:ApplyNativeTextSetting()
    if self.PositionStatusAnchor then self:PositionStatusAnchor() end
    if self.SetStatusAnchorLocked then self:SetStatusAnchorLocked(self.db.statusAnchorLocked) end
end

function HS:RestoreNativeTextSetting()
    if not self.db then return end
    if self.db.nativeDamageBeforeOSHS ~= nil then
        writeCVar("CombatDamage", self.db.nativeDamageBeforeOSHS)
        self.db.nativeDamageBeforeOSHS = nil
    end
    if self.db.nativeHealingBeforeOSHS ~= nil then
        writeCVar("CombatHealing", self.db.nativeHealingBeforeOSHS)
        self.db.nativeHealingBeforeOSHS = nil
    end
end

function HS:ApplyNativeTextSetting()
    if not self.db or not SetCVar then return end
    if self.db.disableFloatingCombatText then
        if self.db.nativeDamageBeforeOSHS == nil then
            self.db.nativeDamageBeforeOSHS = readCVar("CombatDamage") or 1
        end
        if self.db.nativeHealingBeforeOSHS == nil then
            self.db.nativeHealingBeforeOSHS = readCVar("CombatHealing")
        end
        writeCVar("CombatDamage", 0)
        if self.db.nativeHealingBeforeOSHS ~= nil then writeCVar("CombatHealing", 0) end
    else self:RestoreNativeTextSetting() end
end

local function schoolKey(school)
    local value = string.lower(tostring(school or ""))
    if string.find(value, "holy") then return "holy" end
    if string.find(value, "fire") then return "fire" end
    if string.find(value, "nature") or string.find(value, "poison") then return "nature" end
    if string.find(value, "frost") then return "frost" end
    if string.find(value, "shadow") then return "shadow" end
    if string.find(value, "arcane") then return "arcane" end
    return "physical"
end

local function trimName(name)
    if not name then return nil end
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    return name
end

local function findNameRegion(frame)
    local regions = { frame:GetRegions() }
    local i, region, label
    for i = 1, table.getn(regions) do
        region = regions[i]
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            label = region:GetText()
            if label and label ~= "" and not tonumber(label) then return region end
        end
    end
end

local function considerPlate(frame)
    if not frame or plates[frame] then return end
    local bar = frame:GetChildren()
    if not bar or not bar.GetObjectType or bar:GetObjectType() ~= "StatusBar" then return end
    local nameRegion = findNameRegion(frame)
    if nameRegion then plates[frame] = { frame = frame, nameRegion = nameRegion } end
end

local function visualPlateAnchor(frame)
    if not frame then return nil end
    if frame.nameplate then return frame.nameplate.health or frame.nameplate end
    if frame.parent and frame.health and frame.platename then return frame.health end
    return frame
end

function HS:ScanNameplates()
    local count = WorldFrame:GetNumChildren()
    if count == lastWorldChildren then return end
    local children = { WorldFrame:GetChildren() }
    local i
    for i = 1, table.getn(children) do considerPlate(children[i]) end
    lastWorldChildren = count
end

local function plateForName(name)
    name = trimName(name)
    if not name then return nil end
    if HS.hasClassicAPI then
        if UnitExists("target") and UnitName("target") == name then
            local targetPlate = C_NamePlate.GetNamePlateForUnit("target")
            if targetPlate then return visualPlateAnchor(targetPlate) end
        end
        local i, token, frame
        for i = 1, 40 do
            token = "nameplate" .. i
            if UnitExists(token) and UnitName(token) == name then
                frame = C_NamePlate.GetNamePlateForUnit(token)
                if frame then return visualPlateAnchor(frame) end
            end
        end
    end
    local data
    for _, data in pairs(plates) do
        if data.frame:IsShown() and trimName(data.nameRegion:GetText()) == name then
            return visualPlateAnchor(data.frame)
        end
    end
end

local function plateForGUID(guid)
    if not guid then return nil end
    if C_NamePlate and C_NamePlate.GetNamePlateForGUID then
        local ok, frame = pcall(C_NamePlate.GetNamePlateForGUID, guid)
        if ok and frame then return visualPlateAnchor(frame) end
    end
    if UnitTokenFromGUID and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, token = pcall(UnitTokenFromGUID, guid)
        if ok and token then
            local frameOK, frame = pcall(C_NamePlate.GetNamePlateForUnit, token)
            if frameOK and frame then return visualPlateAnchor(frame) end
        end
    end
end

local function rememberCurrentBoss()
    if not UnitExists("target") then return end
    local name = UnitName("target")
    local classification = UnitClassification and UnitClassification("target")
    local level = UnitLevel and UnitLevel("target")
    if name and (classification == "worldboss" or level == -1) then knownBossNames[name] = true end
end

local function targetFrameForName(name)
    if not HS.db.useTargetFrame or not name or not UnitExists("target") or UnitName("target") ~= name then return nil end
    rememberCurrentBoss()
    if pfUI and pfUI.uf and pfUI.uf.target and pfUI.uf.target:IsShown() then
        return pfUI.uf.target.health or pfUI.uf.target
    end
    if TargetFrameHealthBar and TargetFrameHealthBar:IsShown() then return TargetFrameHealthBar end
    if TargetFrame and TargetFrame:IsShown() then return TargetFrame end
end

local function anchorIsVisible(anchor)
    if not anchor then return false end
    if anchor.IsVisible then return anchor:IsVisible() end
    return anchor:IsShown()
end

local function acquireSplat()
    local item = table.remove(pool)
    if item then item:Show(); return item end
    item = CreateFrame("Frame", nil, UIParent)
    item:SetWidth(180); item:SetHeight(52); item:SetFrameStrata("HIGH")
    item.splat = item:CreateTexture(nil, "ARTWORK")
    item.splat:SetPoint("CENTER", item, "CENTER", 0, 0)
    item.text = item:CreateFontString(nil, "OVERLAY")
    item.text:SetPoint("CENTER", item, "CENTER", 0, 0)
    return item
end

local function releaseSplat(item)
    item:Hide(); item:ClearAllPoints()
    item.anchor, item.slot, item.usesNameplate = nil, nil, nil
    table.insert(pool, item)
end

local function removeActive(index)
    local item = table.remove(active, index)
    if item then releaseSplat(item) end
end

local function acquireInterrupt()
    local item = table.remove(interruptPool)
    if item then item:Show(); return item end
    item = CreateFrame("Frame", nil, UIParent)
    item:SetWidth(240); item:SetHeight(34); item:SetFrameStrata("HIGH")
    item.text = item:CreateFontString(nil, "OVERLAY")
    item.text:SetPoint("CENTER", item, "CENTER", 0, 0)
    return item
end

local function releaseInterrupt(item)
    item:Hide(); item:ClearAllPoints()
    item.anchor = nil
    table.insert(interruptPool, item)
end

function HS:ShowPlateMessage(targetName, targetGUID, message, red, green, blue)
    if not self.db.enabled then return end
    local anchor
    if targetGUID then anchor = plateForGUID(targetGUID)
    end
    if not anchorIsVisible(anchor) and targetName and UnitExists("target") and trimName(UnitName("target")) == trimName(targetName) then
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local ok, frame = pcall(C_NamePlate.GetNamePlateForUnit, "target")
            if ok and frame then anchor = visualPlateAnchor(frame) end
        end
        if not anchorIsVisible(anchor) and UnitNameplate then
            local ok, frame = pcall(UnitNameplate, "target")
            if ok and frame then anchor = visualPlateAnchor(frame) end
        end
    end
    if not anchorIsVisible(anchor) then anchor = plateForName(targetName) end
    if not anchorIsVisible(anchor) then return end

    local i, item
    for i = table.getn(interruptActive), 1, -1 do
        if interruptActive[i].anchor == anchor then
            releaseInterrupt(table.remove(interruptActive, i))
        end
    end

    item = acquireInterrupt()
    local scale = tonumber(self.db.scale) or .9
    local textSize = math.max(12, (tonumber(self.db.textSize) or 22) * scale)
    item.text:SetFont("Interface\\AddOns\\OSHS\\Assets\\runescape.ttf", math.max(1, textSize - 1), "OUTLINE")
    if item.text.SetTextHeight then item.text:SetTextHeight(textSize) end
    item.text:SetText(message)
    item.text:SetTextColor(red or 1, green or 1, blue or 1)
    item:SetAlpha(1)
    item.anchor = anchor
    item.started = GetTime()
    item.duration = math.max(.8, tonumber(self.db.duration) or 1.25)
    item:SetPoint("BOTTOM", anchor, "TOP", tonumber(self.db.offsetX) or 0, 8)
    table.insert(interruptActive, item)
    return true
end

function HS:ShowInterrupt(targetName, targetGUID)
    if not self.db.showInterrupts then return end
    return self:ShowPlateMessage(targetName, targetGUID, "Interrupted!", 1, .86, .12)
end

function HS:ShowEnemyImmune(targetName, targetGUID)
    if not self.db.showMisses then return end
    return self:ShowPlateMessage(targetName, targetGUID, "Immune!", .7, .65, 1)
end

HS.DamageFallback = CreateFrame("Frame", "OSHSDamageAnchor", UIParent)
HS.DamageFallback:SetWidth(180); HS.DamageFallback:SetHeight(20)
HS.DamageFallback:SetPoint("CENTER", UIParent, "CENTER", 0, 105)

HS.HealFallback = CreateFrame("Frame", "OSHSHealAnchor", UIParent)
HS.HealFallback:SetWidth(180); HS.HealFallback:SetHeight(20)
HS.HealFallback:SetPoint("CENTER", UIParent, "CENTER", 0, -55)

HS.TakenFallback = CreateFrame("Frame", "OSHSTakenAnchor", UIParent)
HS.TakenFallback:SetWidth(180); HS.TakenFallback:SetHeight(20)
HS.TakenFallback:SetPoint("CENTER", UIParent, "CENTER", 0, -35)

HS.BossFallback = CreateFrame("Frame", "OSHSBossAnchor", UIParent)
HS.BossFallback:SetWidth(220); HS.BossFallback:SetHeight(20)
HS.BossFallback:SetPoint("CENTER", UIParent, "CENTER", 0, 175)

local statusAnchorBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

HS.StatusAnchor = CreateFrame("Frame", "OSHSStatusAnchor", UIParent)
HS.StatusAnchor:SetWidth(230); HS.StatusAnchor:SetHeight(28)
HS.StatusAnchor:SetPoint("CENTER", UIParent, "CENTER", -120, -10)
HS.StatusAnchor:SetFrameStrata("DIALOG")
HS.StatusAnchor:SetMovable(true); HS.StatusAnchor:RegisterForDrag("LeftButton")
HS.StatusAnchor:SetBackdrop(statusAnchorBackdrop)
HS.StatusAnchor.label = HS.StatusAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HS.StatusAnchor.label:SetPoint("CENTER", HS.StatusAnchor, "CENTER", 0, 0)
HS.StatusAnchor.label:SetText("OSHS status effects - drag to move")
HS.StatusAnchor:SetScript("OnDragStart", function() this:StartMoving() end)
HS.StatusAnchor:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, _, x, y = this:GetPoint(1)
    HS.db.statusAnchorPoint = point or "CENTER"
    HS.db.statusAnchorX = x or 0
    HS.db.statusAnchorY = y or 0
end)

function HS:PositionStatusAnchor()
    if not self.db then return end
    self.StatusAnchor:ClearAllPoints()
    local point = self.db.statusAnchorPoint or "CENTER"
    self.StatusAnchor:SetPoint(point, UIParent, point, self.db.statusAnchorX or -120, self.db.statusAnchorY or -10)
end

function HS:SetStatusAnchorLocked(locked)
    self.db.statusAnchorLocked = locked and true or false
    self.StatusAnchor:EnableMouse(not self.db.statusAnchorLocked)
    if self.db.statusAnchorLocked then
        self.StatusAnchor:SetBackdropColor(0, 0, 0, 0)
        self.StatusAnchor:SetBackdropBorderColor(0, 0, 0, 0)
        self.StatusAnchor.label:Hide()
    else
        self.StatusAnchor:SetBackdropColor(.35, .08, .45, .75)
        self.StatusAnchor:SetBackdropBorderColor(.85, .45, 1, 1)
        self.StatusAnchor.label:Show()
    end
    if self.UpdateStatusAnchorButton then self:UpdateStatusAnchorButton() end
end

local function acquireStatusItem()
    local item = table.remove(statusPool)
    if item then item:Show(); return item end
    item = CreateFrame("Frame", nil, UIParent)
    item:SetWidth(300); item:SetHeight(28); item:SetFrameStrata("HIGH")
    item.icon = item:CreateTexture(nil, "ARTWORK")
    item.icon:SetPoint("RIGHT", item, "CENTER", -3, 0)
    item.icon:SetTexCoord(.08, .92, .08, .92)
    item.text = item:CreateFontString(nil, "OVERLAY")
    item.text:SetPoint("LEFT", item, "CENTER", 3, 0)
    item.text:SetJustifyH("LEFT")
    return item
end


local function releaseStatusItem(item)
    if item.key and statusByKey[item.key] == item then statusByKey[item.key] = nil end
    item:Hide(); item:ClearAllPoints(); item.key = nil
    table.insert(statusPool, item)
end

function HS:ShowStatusEffect(message, r, g, b, texture, dedupeKey)
    if not self.db.enabled or not self.db.showStatusEffects or not message or message == "" then return end
    local now = GetTime()
    local existing = dedupeKey and statusByKey[dedupeKey]
    if existing and now - existing.started <= .3 then
        existing.text:SetText(message); existing.text:SetTextColor(r or 1, g or 1, b or 1)
        if self.db.statusShowIcons and texture then existing.icon:SetTexture(texture); existing.icon:Show() end
        existing.started = now; existing.duration = self.db.statusDuration
        return
    end

    if table.getn(statusActive) >= 4 then
        local oldest = table.remove(statusActive, 1)
        releaseStatusItem(oldest)
    end
    local item = acquireStatusItem()
    local size = tonumber(self.db.statusTextSize) or 17
    item.text:SetFont("Fonts\\FRIZQT__.TTF", math.max(1, size - 1), "OUTLINE")
    if item.text.SetTextHeight then item.text:SetTextHeight(size) end
    item.text:SetText(message); item.text:SetTextColor(r or 1, g or 1, b or 1)
    if self.db.statusShowIcons and texture then
        item.icon:SetTexture(texture); item.icon:SetWidth(size); item.icon:SetHeight(size); item.icon:Show()
    else
        item.icon:Hide()
    end
    item:SetAlpha(1); item.started = now; item.duration = tonumber(self.db.statusDuration) or 1.5
    item.key = dedupeKey
    if dedupeKey then statusByKey[dedupeKey] = item end
    table.insert(statusActive, item)
end

function HS:ShowSplat(targetName, amount, isCrit, isHeal, school, anchorHint, allowFallback, targetGUID, isTaken)
    if not self.db.enabled then return end
    if isHeal and not self.db.showHealing then return end
    if isTaken and not self.db.showDamageTaken then return end
    if not isHeal and tonumber(amount) and not self.db.showDamage then return end
    if (not tonumber(amount) or tonumber(amount) == 0) and not self.db.showMisses then return end

    local plateAnchor
    if not isTaken then
        if anchorHint then
            plateAnchor = anchorHint
        elseif targetGUID then
            plateAnchor = plateForGUID(targetGUID)
        else
            plateAnchor = plateForName(targetName)
        end
    end
    if not anchorIsVisible(plateAnchor) then plateAnchor = nil end
    local targetAnchor = not isTaken and not isHeal and not plateAnchor and targetFrameForName(targetName)
    local bossAnchor = not isTaken and not isHeal and not plateAnchor and not targetAnchor and knownBossNames[targetName] and self.BossFallback
    local fallback = isTaken and self.TakenFallback or (isHeal and self.HealFallback or self.DamageFallback)
    local anchor = plateAnchor or targetAnchor or bossAnchor or (allowFallback ~= false and fallback)
    if not anchor then return end

    local numeric = tonumber(amount)
    local amountText = tostring(numeric or 0)
    local scale = tonumber(self.db.scale) or .9
    local textSize = math.max(10, (tonumber(self.db.textSize) or 22) * .82 * scale)
    local item = acquireSplat()
    item.text:SetFont("Interface\\AddOns\\OSHS\\Assets\\runescape.ttf", math.max(1, textSize - 1), "OUTLINE")
    if item.text.SetTextHeight then item.text:SetTextHeight(textSize) end
    item.text:SetText(amountText)
    if isHeal then
        item.text:SetTextColor(.35, 1, .35)
    elseif isCrit and self.db.critColor then
        item.text:SetTextColor(1, .88, .3)
    else
        item.text:SetTextColor(1, 1, 1)
    end

    local texture = schoolTextures[self.db.colorBySchool and schoolKey(school) or "physical"]
    if isHeal then texture = "Interface\\AddOns\\OSHS\\Assets\\Hitsplat-Heal.tga"
    elseif not numeric or numeric == 0 then texture = "Interface\\AddOns\\OSHS\\Assets\\Hitsplat-Miss.tga" end
    item.splat:SetTexture(texture)
    if isHeal then item.splat:SetVertexColor(.15, 1, .15)
    else item.splat:SetVertexColor(1, 1, 1) end
    item.splat:SetWidth(math.max(42, 26 + string.len(amountText) * 7) * scale)
    item.splat:SetHeight(42 * scale)
    item:SetAlpha(1)
    item.anchor = anchor
    item.usesNameplate = plateAnchor and true or false

    local occupied = {}
    local oldestIndex, oldestTime
    local now = GetTime()
    local occupiedCount = 0
    local i, other
    for i = 1, table.getn(active) do
        other = active[i]
        if other.anchor == anchor and other.slot then
            if not occupied[other.slot] then
                occupied[other.slot] = true
                occupiedCount = occupiedCount + 1
            end
            if not oldestTime or other.started < oldestTime then oldestTime, oldestIndex = other.started, i end
        end
    end

    local slot
    if occupiedCount < 4 then
        for i = 1, 4 do if not occupied[i] then slot = i; break end end
    elseif oldestIndex then
        slot = active[oldestIndex].slot
        removeActive(oldestIndex)
    end
    slot = slot or 1
    item.slot = slot
    item.started = now
    item.duration = tonumber(self.db.duration) or 1.25

    local x = tonumber(self.db.offsetX) or 0
    local y = tonumber(self.db.offsetY) or -14
    local h = (tonumber(self.db.horizontalSpacing) or 23) * scale
    local v = (tonumber(self.db.verticalSpacing) or 19) * scale
    if slot == 2 then x, y = x - h, y - v
    elseif slot == 3 then x, y = x + h, y - v
    elseif slot == 4 then y = y - (2 * v) end
    item.offsetX, item.offsetY = x, y
    if plateAnchor then item:SetPoint("TOP", anchor, "BOTTOM", x, y)
    else item:SetPoint("CENTER", anchor, "CENTER", x, y) end
    table.insert(active, item)
end

function HS:Preview()
    local anchor = UnitName("target") or "Target"
    self:ShowSplat(anchor, 42, false, false, "Physical")
    self:ShowSplat(anchor, 73, true, false, "Fire")
    self:ShowSplat(anchor, 18, false, false, "Frost")
    self:ShowSplat(anchor, MISS or "Miss", false, false, nil)
end

local function parsePetDamage(message, eventName)
    local source, spell, target, amount, school
    local meleeEvent = eventName == "CHAT_MSG_COMBAT_PET_HITS"
    local cmatch = pfUI and pfUI.api and pfUI.api.cmatch
    if cmatch then
        local patterns = {
            { SPELLLOGCRITSCHOOLOTHEROTHER, true, false, true }, { SPELLLOGSCHOOLOTHEROTHER, false, false, true },
            { SPELLLOGCRITOTHEROTHER, true, false, false }, { SPELLLOGOTHEROTHER, false, false, false },
        }
        local i, p
        for i = 1, table.getn(patterns) do
            p = patterns[i]
            if p[1] then
                if p[4] then source, spell, target, amount, school = cmatch(message, p[1])
                else source, spell, target, amount = cmatch(message, p[1]); school = nil end
                if source then return target, amount, p[2], school end
            end
        end
        local meleePatterns = {
            { COMBATHITCRITSCHOOLOTHEROTHER, true, true }, { COMBATHITSCHOOLOTHEROTHER, false, true },
            { COMBATHITCRITOTHEROTHER, true, false }, { COMBATHITOTHEROTHER, false, false },
        }
        for i = 1, table.getn(meleePatterns) do
            p = meleePatterns[i]
            if p[1] then
                if p[3] then source, target, amount, school = cmatch(message, p[1])
                else source, target, amount = cmatch(message, p[1]); school = "Physical" end
                if source then return target, amount, p[2], school end
            end
        end
    end
    _, _, source, spell, target, amount, school = string.find(message, "^(.+)'s (.+) crits (.+) for (%d+) (%a+) damage")
    if source then return target, amount, true, school end
    _, _, source, spell, target, amount, school = string.find(message, "^(.+)'s (.+) hits (.+) for (%d+) (%a+) damage")
    if source then return target, amount, false, school end
    _, _, source, spell, target, amount = string.find(message, "^(.+)'s (.+) crits (.+) for (%d+)")
    if source then return target, amount, true end
    _, _, source, spell, target, amount = string.find(message, "^(.+)'s (.+) hits (.+) for (%d+)")
    if source then return target, amount, false end
    _, _, source, target, amount, school = string.find(message, "^(.+) crits (.+) for (%d+) (%a+) damage")
    if source then return target, amount, true, school end
    _, _, source, target, amount, school = string.find(message, "^(.+) hits (.+) for (%d+) (%a+) damage")
    if source then return target, amount, false, school end
    _, _, source, target, amount = string.find(message, "^(.+) crits (.+) for (%d+)")
    if source then return target, amount, true, meleeEvent and "Physical" or nil end
    _, _, source, target, amount = string.find(message, "^(.+) hits (.+) for (%d+)")
    if source then return target, amount, false, meleeEvent and "Physical" or nil end
end

local function parseDamage(message)
    local spell, target, amount, school, source
    local cmatch = pfUI and pfUI.api and pfUI.api.cmatch
    if cmatch then
        if SPELLLOGCRITSCHOOLSELFOTHER then spell, target, amount, school = cmatch(message, SPELLLOGCRITSCHOOLSELFOTHER); if spell then return target, amount, true, school end end
        if SPELLLOGSCHOOLSELFOTHER then spell, target, amount, school = cmatch(message, SPELLLOGSCHOOLSELFOTHER); if spell then return target, amount, false, school end end
        if SPELLLOGCRITSELFOTHER then spell, target, amount = cmatch(message, SPELLLOGCRITSELFOTHER); if spell then return target, amount, true end end
        if SPELLLOGSELFOTHER then spell, target, amount = cmatch(message, SPELLLOGSELFOTHER); if spell then return target, amount, false end end
        if COMBATHITCRITSCHOOLSELFOTHER then target, amount, school = cmatch(message, COMBATHITCRITSCHOOLSELFOTHER); if target then return target, amount, true, school end end
        if COMBATHITSCHOOLSELFOTHER then target, amount, school = cmatch(message, COMBATHITSCHOOLSELFOTHER); if target then return target, amount, false, school end end
        if COMBATHITCRITSELFOTHER then target, amount = cmatch(message, COMBATHITCRITSELFOTHER); if target then return target, amount, true, "Physical" end end
        if COMBATHITSELFOTHER then target, amount = cmatch(message, COMBATHITSELFOTHER); if target then return target, amount, false, "Physical" end end
        if PERIODICAURADAMAGESELFOTHER then target, amount, school, spell = cmatch(message, PERIODICAURADAMAGESELFOTHER); if target then return target, amount, false, school end end
    end
    _, _, spell, target, amount, school = string.find(message, "^Your (.+) crits (.+) for (%d+) (%a+) damage")
    if spell then return target, amount, true, school end
    _, _, spell, target, amount, school = string.find(message, "^Your (.+) hits (.+) for (%d+) (%a+) damage")
    if spell then return target, amount, false, school end
    _, _, spell, target, amount = string.find(message, "^Your (.+) crits (.+) for (%d+)")
    if spell then return target, amount, true end
    _, _, spell, target, amount = string.find(message, "^Your (.+) hits (.+) for (%d+)")
    if spell then return target, amount, false end
    _, _, target, amount, spell = string.find(message, "^(.+) suffers (%d+) .- damage from your (.+)%.")
    if target then return target, amount, false end
    _, _, target, amount = string.find(message, "^You crit (.+) for (%d+)")
    if target then return target, amount, true, "Physical" end
    _, _, target, amount = string.find(message, "^You hit (.+) for (%d+)")
    if target then return target, amount, false, "Physical" end
    _, _, target, amount = string.find(message, "^Your pet crits (.+) for (%d+)")
    if target then return target, amount, true, "Physical" end
    _, _, target, amount = string.find(message, "^Your pet hits (.+) for (%d+)")
    if target then return target, amount, false, "Physical" end
    _, _, source, spell, target, amount, school = string.find(message, "^(.+)'s (.+) crits (.+) for (%d+) (%a+) damage")
    if source and (source == UnitName("pet") or string.find(string.lower(source), "totem")) then return target, amount, true, school end
    _, _, source, spell, target, amount, school = string.find(message, "^(.+)'s (.+) hits (.+) for (%d+) (%a+) damage")
    if source and (source == UnitName("pet") or string.find(string.lower(source), "totem")) then return target, amount, false, school end
    _, _, source, spell, target, amount = string.find(message, "^(.+)'s (.+) crits (.+) for (%d+)")
    if source and (source == UnitName("pet") or string.find(string.lower(source), "totem")) then return target, amount, true end
    _, _, source, spell, target, amount = string.find(message, "^(.+)'s (.+) hits (.+) for (%d+)")
    if source and (source == UnitName("pet") or string.find(string.lower(source), "totem")) then return target, amount, false end
end

local function parsePeriodicDamage(message)
    local target, amount, school, spell
    local cmatch = pfUI and pfUI.api and pfUI.api.cmatch
    if cmatch and PERIODICAURADAMAGESELFOTHER then
        target, amount, school, spell = cmatch(message, PERIODICAURADAMAGESELFOTHER)
        if target then return target, amount, school end
    end
    _, _, target, amount, school, spell = string.find(message, "^(.+) suffers (%d+) (%a+) damage from your (.+)%.")
    if target then return target, amount, school end
    _, _, target, amount, spell = string.find(message, "^(.+) suffers (%d+) damage from your (.+)%.")
    if target then return target, amount end
end

local function parseHeal(message)
    local spell, target, amount
    local cmatch = pfUI and pfUI.api and pfUI.api.cmatch
    if cmatch then
        if HEALEDCRITSELFSELF then spell, amount = cmatch(message, HEALEDCRITSELFSELF); if spell then return UnitName("player"), amount, true end end
        if HEALEDSELFSELF then spell, amount = cmatch(message, HEALEDSELFSELF); if spell then return UnitName("player"), amount, false end end
        if HEALEDCRITSELFOTHER then spell, target, amount = cmatch(message, HEALEDCRITSELFOTHER); if spell then return target, amount, true end end
        if HEALEDSELFOTHER then spell, target, amount = cmatch(message, HEALEDSELFOTHER); if spell then return target, amount, false end end
        if PERIODICAURAHEALSELFSELF then amount, spell = cmatch(message, PERIODICAURAHEALSELFSELF); if amount then return UnitName("player"), amount, false end end
        if PERIODICAURAHEALSELFOTHER then target, amount, spell = cmatch(message, PERIODICAURAHEALSELFOTHER); if target then return target, amount, false end end
    end
    _, _, spell, amount = string.find(message, "^Your (.+) critically heals you for (%d+)")
    if spell then return UnitName("player"), amount, true end
    _, _, spell, amount = string.find(message, "^Your (.+) heals you for (%d+)")
    if spell then return UnitName("player"), amount, false end
    _, _, spell, target, amount = string.find(message, "^Your (.+) critically heals (.+) for (%d+)")
    if spell then return target, amount, true end
    _, _, spell, target, amount = string.find(message, "^Your (.+) heals (.+) for (%d+)")
    if spell then return target, amount, false end
end

local function parseMiss(message)
    local spell, target
    local cmatch = pfUI and pfUI.api and pfUI.api.cmatch
    if cmatch then
        local patterns = {
            { SPELLMISSSELFOTHER, true, MISS or "Miss" }, { SPELLDODGEDSELFOTHER, true, DODGE or "Dodge" },
            { SPELLPARRIEDSELFOTHER, true, PARRY or "Parry" }, { SPELLBLOCKEDSELFOTHER, true, BLOCK or "Block" },
            { SPELLRESISTSELFOTHER, true, RESIST or "Resist" }, { SPELLLOGABSORBSELFOTHER, true, ABSORB or "Absorb" },
            { SPELLIMMUNESELFOTHER, true, IMMUNE or "Immune" }, { SPELLREFLECTSELFOTHER, true, REFLECT or "Reflect" },
            { SPELLEVADEDSELFOTHER, true, EVADE or "Evade" }, { MISSEDSELFOTHER, false, MISS or "Miss" },
            { VSDODGESELFOTHER, false, DODGE or "Dodge" }, { VSPARRYSELFOTHER, false, PARRY or "Parry" },
            { VSBLOCKSELFOTHER, false, BLOCK or "Block" }, { VSIMMUNESELFOTHER, false, IMMUNE or "Immune" },
            { VSABSORBSELFOTHER, false, ABSORB or "Absorb" }, { VSEVADESELFOTHER, false, EVADE or "Evade" },
        }
        local i, p
        for i = 1, table.getn(patterns) do
            p = patterns[i]
            if p[1] then
                if p[2] then spell, target = cmatch(message, p[1]) else target = cmatch(message, p[1]) end
                if target then return target, p[3] end
            end
        end
    end
    _, _, spell, target = string.find(message, "^Your (.+) missed (.+)%.")
    if spell then return target, MISS or "Miss" end
    _, _, spell, target = string.find(message, "^Your (.+) was resisted by (.+)%.")
    if spell then return target, RESIST or "Resist" end
    _, _, spell, target = string.find(message, "^Your (.+) failed%. (.+) is immune%.")
    if spell then return target, IMMUNE or "Immune" end
    _, _, target, spell = string.find(message, "^(.+) is immune to your (.+)%.")
    if target then return target, IMMUNE or "Immune" end
    _, _, target = string.find(message, "^You miss (.+)%.")
    if target then return target, MISS or "Miss" end
    _, _, target = string.find(message, "^(.+) dodges")
    if target then return target, DODGE or "Dodge" end
    _, _, target = string.find(message, "^(.+) parries")
    return target, target and (PARRY or "Parry")
end

local function parsePetMiss(message)
    local source, spell, target
    local cmatch = pfUI and pfUI.api and pfUI.api.cmatch
    if cmatch then
        local patterns = {
            { SPELLMISSOTHEROTHER, true, MISS or "Miss" }, { SPELLDODGEDOTHEROTHER, true, DODGE or "Dodge" },
            { SPELLPARRIEDOTHEROTHER, true, PARRY or "Parry" }, { SPELLBLOCKEDOTHEROTHER, true, BLOCK or "Block" },
            { SPELLRESISTOTHEROTHER, true, RESIST or "Resist" }, { SPELLLOGABSORBOTHEROTHER, true, ABSORB or "Absorb" },
            { SPELLIMMUNEOTHEROTHER, true, IMMUNE or "Immune" }, { SPELLEVADEDOTHEROTHER, true, EVADE or "Evade" },
            { MISSEDOTHEROTHER, false, MISS or "Miss" }, { VSDODGEOTHEROTHER, false, DODGE or "Dodge" },
            { VSPARRYOTHEROTHER, false, PARRY or "Parry" }, { VSBLOCKOTHEROTHER, false, BLOCK or "Block" },
            { VSABSORBOTHEROTHER, false, ABSORB or "Absorb" }, { VSIMMUNEOTHEROTHER, false, IMMUNE or "Immune" },
            { VSEVADEOTHEROTHER, false, EVADE or "Evade" },
        }
        local i, p
        for i = 1, table.getn(patterns) do
            p = patterns[i]
            if p[1] then
                if p[2] then source, spell, target = cmatch(message, p[1]) else source, target = cmatch(message, p[1]) end
                if source then return target, p[3] end
            end
        end
    end
    _, _, source, spell, target = string.find(message, "^(.+)'s (.+) missed (.+)%.")
    if source then return target, MISS or "Miss" end
    _, _, source, spell, target = string.find(message, "^(.+)'s (.+) failed%. (.+) is immune%.")
    if source then return target, IMMUNE or "Immune" end
    _, _, source, target = string.find(message, "^(.+) misses (.+)%.")
    if source then return target end
    _, _, source, target = string.find(message, "^(.+) attacks%. (.+) dodges%.")
    if source then return target end
    _, _, source, target = string.find(message, "^(.+) attacks%. (.+) parries%.")
    if source then return target end
    _, _, source, target = string.find(message, "^(.+) attacks%. (.+) blocks%.")
    if source then return target end
    _, _, target, source = string.find(message, "^(.+) dodges (.+)%.")
    if target then return target end
    _, _, target, source = string.find(message, "^(.+) parries (.+)%.")
    if target then return target end
    _, _, target, source = string.find(message, "^(.+) blocks (.+)%.")
    return target, target and (BLOCK or "Block")
end

local function isImmuneResult(result)
    if not result then return false end
    return string.lower(tostring(result)) == string.lower(tostring(IMMUNE or "Immune"))
end

local function parseInterrupt(message, allowControlled)
    local source, target, spell
    local cmatch = pfUI and pfUI.api and pfUI.api.cmatch
    if cmatch and SPELLINTERRUPTSELFOTHER then
        target, spell = cmatch(message, SPELLINTERRUPTSELFOTHER)
        if target then return target end
    end
    _, _, target, spell = string.find(message, "^You interrupt (.+)'s (.-)[%.!]$")
    if target then return target end
    local ability
    _, _, ability, target, spell = string.find(message, "^Your (.+) interrupts (.+)'s (.-)[%.!]$")
    if target then return target end
    if string.find(string.lower(message), "interrupt", 1, true) and UnitExists("target") then
        return UnitName("target")
    end
    if not allowControlled then return end
    if cmatch and SPELLINTERRUPTOTHEROTHER then
        source, target, spell = cmatch(message, SPELLINTERRUPTOTHEROTHER)
    else
        _, _, source, target, spell = string.find(message, "^(.+) interrupts (.+)'s (.-)[%.!]$")
    end
    if source and (source == UnitName("pet") or string.find(string.lower(source), "totem")) then return target end
end

local function interruptGUIDForName(name)
    name = trimName(name)
    if name and UnitExists("target") and trimName(UnitName("target")) == name and UnitGUID then
        return UnitGUID("target")
    end
    local recent = name and recentTargetGUIDs[name]
    if recent and GetTime() - recent.time <= 1 then return recent.guid end
end

local function parseIncomingAvoidance(message)
    local source, spell
    local cmatch = pfUI and pfUI.api and pfUI.api.cmatch
    if cmatch then
        local patterns = {
            { SPELLMISSOTHERSELF, true }, { SPELLDODGEDOTHERSELF, true }, { SPELLPARRIEDOTHERSELF, true },
            { SPELLBLOCKEDOTHERSELF, true }, { SPELLRESISTOTHERSELF, true }, { SPELLLOGABSORBOTHERSELF, true },
            { SPELLIMMUNEOTHERSELF, true }, { SPELLEVADEDOTHERSELF, true }, { SPELLREFLECTOTHERSELF, true },
            { MISSEDOTHERSELF, false }, { VSDODGEOTHERSELF, false }, { VSPARRYOTHERSELF, false },
            { VSBLOCKOTHERSELF, false }, { VSABSORBOTHERSELF, false }, { VSIMMUNEOTHERSELF, false }, { VSEVADEOTHERSELF, false },
        }
        local i, p
        for i = 1, table.getn(patterns) do
            p = patterns[i]
            if p[1] then
                if p[2] then source, spell = cmatch(message, p[1]) else source = cmatch(message, p[1]) end
                if source then return source end
            end
        end
    end
    _, _, source = string.find(message, "^(.+)'s .+ was blocked%.")
    if source then return source end
    _, _, source = string.find(message, "^(.+)'s .+ missed you%.")
    if source then return source end
    _, _, source = string.find(message, "^(.+) attacks%. You block%.")
    if source then return source end
    _, _, source = string.find(message, "^(.+) attacks%. You dodge%.")
    if source then return source end
    _, _, source = string.find(message, "^(.+) attacks%. You parry%.")
    if source then return source end
    _, _, source = string.find(message, "^(.+) misses you%.")
    if source then return source end
    _, _, source = string.find(message, "^You block (.+)'s attack%.")
    if source then return source end
    _, _, source = string.find(message, "^You dodge (.+)'s attack%.")
    if source then return source end
    _, _, source = string.find(message, "^You parry (.+)'s attack%.")
    return source
end

local function parseIncoming(message)
    local source, spell, amount, school
    local cmatch = pfUI and pfUI.api and pfUI.api.cmatch
    if cmatch then
        if SPELLLOGCRITSCHOOLOTHERSELF then source, spell, amount, school = cmatch(message, SPELLLOGCRITSCHOOLOTHERSELF); if source then return source, amount, true, school end end
        if SPELLLOGSCHOOLOTHERSELF then source, spell, amount, school = cmatch(message, SPELLLOGSCHOOLOTHERSELF); if source then return source, amount, false, school end end
        if SPELLLOGCRITOTHERSELF then source, spell, amount = cmatch(message, SPELLLOGCRITOTHERSELF); if source then return source, amount, true end end
        if SPELLLOGOTHERSELF then source, spell, amount = cmatch(message, SPELLLOGOTHERSELF); if source then return source, amount, false end end
        if COMBATHITCRITSCHOOLOTHERSELF then source, amount, school = cmatch(message, COMBATHITCRITSCHOOLOTHERSELF); if source then return source, amount, true, school end end
        if COMBATHITSCHOOLOTHERSELF then source, amount, school = cmatch(message, COMBATHITSCHOOLOTHERSELF); if source then return source, amount, false, school end end
        if COMBATHITCRITOTHERSELF then source, amount = cmatch(message, COMBATHITCRITOTHERSELF); if source then return source, amount, true, "Physical" end end
        if COMBATHITOTHERSELF then source, amount = cmatch(message, COMBATHITOTHERSELF); if source then return source, amount, false, "Physical" end end
        if PERIODICAURADAMAGEOTHERSELF then amount, school, source, spell = cmatch(message, PERIODICAURADAMAGEOTHERSELF); if amount then return source, amount, false, school end end
        if PERIODICAURADAMAGESELFSELF then amount, school, spell = cmatch(message, PERIODICAURADAMAGESELFSELF); if amount then return UnitName("player"), amount, false, school end end
    end
    _, _, source, spell, amount, school = string.find(message, "^(.+)'s (.+) hits you for (%d+) (%a+) damage")
    if source then return source, amount, false, school end
    _, _, source, spell, amount, school = string.find(message, "^(.+)'s (.+) crits you for (%d+) (%a+) damage")
    if source then return source, amount, true, school end
    _, _, source, spell, amount = string.find(message, "^(.+)'s (.+) hits you for (%d+)")
    if source then return source, amount, false end
    _, _, source, spell, amount = string.find(message, "^(.+)'s (.+) crits you for (%d+)")
    if source then return source, amount, true end
    _, _, source, amount = string.find(message, "^(.+) hits you for (%d+)")
    if source then return source, amount, false, "Physical" end
    _, _, source, amount = string.find(message, "^(.+) crits you for (%d+)")
    if source then return source, amount, true, "Physical" end
    _, _, amount, school, source, spell = string.find(message, "^You suffer (%d+) (%a+) damage from (.+)'s (.+)%.")
    if amount then return source, amount, false, school end
    _, _, amount, source, spell = string.find(message, "^You suffer (%d+) damage from (.+)'s (.+)%.")
    if amount then return source, amount, false end
    _, _, amount, school, spell = string.find(message, "^You suffer (%d+) (%a+) damage from your (.+)%.")
    if amount then return UnitName("player"), amount, false, school end
end

function HS:HandleCombatMessage(eventName, message)
    if not self.db or not message then return end
    local target, amount, crit, school, result
    if eventName == "CHAT_MSG_SPELL_SELF_DAMAGE" or eventName == "CHAT_MSG_SPELL_PET_DAMAGE" or interruptOnlyEvents[eventName] then
        target = parseInterrupt(message, eventName == "CHAT_MSG_SPELL_PET_DAMAGE")
        if target then self:ShowInterrupt(target, interruptGUIDForName(target)); return end
        if interruptOnlyEvents[eventName] then return end
    end
    if incomingEvents[eventName] then
        local isMelee = string.find(eventName, "COMBAT_") and true or false
        if (isMelee and nampowerIncomingAutoActive) or (not isMelee and nampowerIncomingSpellActive) then return end
        target = parseIncomingAvoidance(message)
        if target then self:ShowSplat(target, 0, false, false, nil, nil, true, nil, true); return end
        target, amount, crit, school = parseIncoming(message)
        if target or amount then self:ShowSplat(target, amount, crit, false, school, nil, true, nil, true) end
    elseif periodicDamageEvents[eventName] then
        if nampowerSpellDamageActive then return end
        target, amount, school = parsePeriodicDamage(message)
        if target then self:ShowSplat(target, amount, false, false, school) end
    elseif petDamageEvents[eventName] then
        if (eventName == "CHAT_MSG_SPELL_PET_DAMAGE" and nampowerControlledSpellActive) or
           (eventName ~= "CHAT_MSG_SPELL_PET_DAMAGE" and nampowerControlledAutoActive) then return end
        target, amount, crit, school = parsePetDamage(message, eventName)
        if target then self:ShowSplat(target, amount, crit, false, school)
        else
            target, result = parsePetMiss(message)
            if target and (not isImmuneResult(result) or not self:ShowEnemyImmune(target)) then
                self:ShowSplat(target, 0, false, false)
            end
        end
    elseif string.find(eventName, "BUFF") then
        if not nampowerHealsActive then target, amount, crit = parseHeal(message) end
        if target then self:ShowSplat(target, amount, crit, true) end
    else
        if (eventName == "CHAT_MSG_SPELL_SELF_DAMAGE" and nampowerSpellDamageActive) or
           (string.find(eventName, "COMBAT_SELF") and nampowerAutoAttackActive) then return end
        target, amount, crit, school = parseDamage(message)
        if target then self:ShowSplat(target, amount, crit, false, school)
        else
            target, result = parseMiss(message)
            if target and (not isImmuneResult(result) or not self:ShowEnemyImmune(target)) then
                self:ShowSplat(target, 0, false, false)
            end
        end
    end
end

local function unitNameForGUID(guid)
    if not guid or not UnitGUID then return nil end
    local units = { "player", "target", "pet", "mouseover" }
    local i, unit
    for i = 1, 4 do table.insert(units, "party" .. i) end
    for i = 1, 40 do table.insert(units, "raid" .. i); table.insert(units, "nameplate" .. i) end
    for i = 1, table.getn(units) do
        unit = units[i]
        if UnitExists(unit) and UnitGUID(unit) == guid then return UnitName(unit) end
    end
    if GetUnitField then
        local ok, name = pcall(GetUnitField, guid, "name")
        if ok and name then return name end
    end
end

local function isPlayerOwnedGUID(guid)
    if not guid or not UnitGUID then return false end
    local playerGUID = UnitGUID("player")
    if not playerGUID then return false end
    if guid == playerGUID then return true end
    if UnitExists("pet") and UnitGUID("pet") == guid then return true end
    if UnitOwnerGUID then
        local ok, ownerGUID = pcall(UnitOwnerGUID, guid)
        if ok and ownerGUID == playerGUID then return true end
    end
    return false
end

local nampowerSchools = {
    [0] = "Physical", [1] = "Holy", [2] = "Fire", [3] = "Nature",
    [4] = "Frost", [5] = "Shadow", [6] = "Arcane",
}

local function autoAttackCrit(hitInfo)
    hitInfo = tonumber(hitInfo) or 0
    return bit and bit.band and bit.band(hitInfo, 128) ~= 0
end

local function spellNameFromID(spellID)
    if not spellID then return nil end
    if GetSpellRecField then
        local ok, name = pcall(GetSpellRecField, spellID, "name")
        if ok and name then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok and name then return name end
    end
end

local interruptSpellNames = {
    ["kick"] = true, ["pummel"] = true, ["shield bash"] = true,
    ["counterspell"] = true, ["earth shock"] = true,
    ["feral charge"] = true, ["spell lock"] = true,
}

local function spellHasInterruptEffect(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    if GetSpellRecField then
        local fields = { "effect1", "effect2", "effect3", "Effect1", "Effect2", "Effect3" }
        local i, ok, value
        for i = 1, table.getn(fields) do
            ok, value = pcall(GetSpellRecField, spellID, fields[i])
            if ok and tonumber(value) == 68 then return true end
        end
    end
    local name = spellNameFromID(spellID)
    return name and interruptSpellNames[string.lower(name)] and true or false
end

local function spellTextureFromID(spellID)
    if not spellID then return nil end
    if pfUI and pfUI.libdebuff_GetSpellIcon then
        local ok, texture = pcall(pfUI.libdebuff_GetSpellIcon, spellID)
        if ok and texture then return texture end
    end
    if GetSpellRecField and GetSpellIconTexture then
        local ok, iconID = pcall(GetSpellRecField, spellID, "spellIconID")
        if ok and iconID then
            local textureOK, texture = pcall(GetSpellIconTexture, iconID)
            if textureOK and texture then
                if not string.find(texture, "\\") then texture = "Interface\\Icons\\" .. texture end
                return texture
            end
        end
    end
end

local function buildSpellIcons()
    spellIcons = {}
    if not GetSpellName then return end
    local i, name, texture
    i = 1
    while true do
        name = GetSpellName(i, BOOKTYPE_SPELL or "spell")
        if not name then break end
        texture = GetSpellTexture(i, BOOKTYPE_SPELL or "spell")
        if texture and not spellIcons[name] then spellIcons[name] = texture end
        i = i + 1
    end
    if HasPetSpells and HasPetSpells() then
        i = 1
        while true do
            name = GetSpellName(i, BOOKTYPE_PET or "pet")
            if not name then break end
            texture = GetSpellTexture(i, BOOKTYPE_PET or "pet")
            if texture and not spellIcons[name] then spellIcons[name] = texture end
            i = i + 1
        end
    end
end

local function parseStatus(message, faded)
    local effect
    local cmatch = pfUI and pfUI.api and pfUI.api.cmatch
    if cmatch then
        if faded and AURAREMOVEDSELF then
            effect = cmatch(message, AURAREMOVEDSELF)
            if effect then return effect, "fade" end
        elseif not faded and AURAADDEDSELFHARMFUL then
            effect = cmatch(message, AURAADDEDSELFHARMFUL)
            if effect then return effect, "debuff" end
        end
        if not faded and AURAADDEDSELFHELPFUL then
            effect = cmatch(message, AURAADDEDSELFHELPFUL)
            if effect then return effect, "buff" end
        end
    end
    if faded then
        _, _, effect = string.find(message, "^(.+) fades from you%.")
        if effect then return effect, "fade" end
    else
        if string.find(message, "^You gain %d+ ") then return end
        _, _, effect = string.find(message, "^You gain (.+)%.")
        if effect then return effect, "buff" end
        _, _, effect = string.find(message, "^You are afflicted by (.+)%.")
        if effect then return effect, "debuff" end
    end
end

function HS:HandleStatusMessage(message, faded)
    if not message or nampowerAurasActive then return end
    local effect, statusType = parseStatus(message, faded)
    if not effect then return end
    local key = "aura:" .. string.lower(effect)
    if statusType == "debuff" then
        self:ShowStatusEffect("- " .. effect, 1, .3, .45, spellIcons[effect] or "Interface\\Icons\\Spell_Shadow_CurseOfTounges", key)
    elseif statusType == "fade" then
        self:ShowStatusEffect("-" .. effect, .65, .65, .65, spellIcons[effect], key)
    else
        self:ShowStatusEffect("+ " .. effect, .45, 1, .55, spellIcons[effect] or "Interface\\Icons\\Spell_Holy_MagicalSentry", key)
    end
end

HS:RegisterEvent("VARIABLES_LOADED")
HS:RegisterEvent("PLAYER_ENTERING_WORLD")
HS:RegisterEvent("PLAYER_TARGET_CHANGED")
HS:RegisterEvent("PLAYER_LOGOUT")
HS:RegisterEvent("LEARNED_SPELL_IN_TAB")
HS:RegisterEvent("SPELLS_CHANGED")
HS:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
HS:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
pcall(function() HS:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end)
local _, eventName
for _, eventName in ipairs(damageEvents) do HS:RegisterEvent(eventName) end
for _, eventName in ipairs(healEvents) do HS:RegisterEvent(eventName) end
for eventName in pairs(incomingEvents) do HS:RegisterEvent(eventName) end
for eventName in pairs(interruptOnlyEvents) do HS:RegisterEvent(eventName) end
if HS.hasNampower then
    HS:RegisterEvent("SPELL_CAST_EVENT")
    HS:RegisterEvent("SPELL_FAILED_OTHER")
    HS:RegisterEvent("SPELL_DAMAGE_EVENT_SELF")
    HS:RegisterEvent("SPELL_DAMAGE_EVENT_OTHER")
    HS:RegisterEvent("AUTO_ATTACK_SELF")
    HS:RegisterEvent("AUTO_ATTACK_OTHER")
    HS:RegisterEvent("SPELL_MISS_SELF")
    HS:RegisterEvent("SPELL_MISS_OTHER")
    HS:RegisterEvent("SPELL_HEAL_BY_SELF")
    HS:RegisterEvent("BUFF_ADDED_SELF")
    HS:RegisterEvent("BUFF_REMOVED_SELF")
    HS:RegisterEvent("DEBUFF_ADDED_SELF")
    HS:RegisterEvent("DEBUFF_REMOVED_SELF")
end

HS:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        applyDefaults(); HS:PositionStatusAnchor(); HS:SetStatusAnchorLocked(HS.db.statusAnchorLocked)
    elseif event == "PLAYER_ENTERING_WORLD" then
        applyDefaults(); buildSpellIcons(); HS:ScanNameplates(); HS:ApplyNativeTextSetting(); HS:PositionStatusAnchor(); HS:SetStatusAnchorLocked(HS.db.statusAnchorLocked)
        if HS.hasNampower and SetCVar then
            SetCVar("NP_EnableAutoAttackEvents", "1")
            SetCVar("NP_EnableSpellHealEvents", "1")
        end
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffd58cffOSHS:|r loaded. Type |cffffffff/oshs|r for settings.")
        end
    elseif event == "PLAYER_LOGOUT" then
        HS:RestoreNativeTextSetting()
    elseif event == "PLAYER_TARGET_CHANGED" then
        rememberCurrentBoss()
    elseif event == "LEARNED_SPELL_IN_TAB" or event == "SPELLS_CHANGED" then
        buildSpellIcons()
    elseif event == "SPELL_CAST_EVENT" then
        if tonumber(arg1) == 1 and spellHasInterruptEffect(arg2) then
            local targetGUID = arg4
            if not targetGUID or targetGUID == "0x0000000000000000" or targetGUID == "0x000000000" then
                targetGUID = UnitExists("target") and UnitGUID and UnitGUID("target")
            end
            pendingInterrupt = { guid = targetGUID, time = GetTime() }
        end
    elseif event == "SPELL_FAILED_OTHER" then
        if pendingInterrupt and GetTime() - pendingInterrupt.time <= 1.25 and
           (not pendingInterrupt.guid or pendingInterrupt.guid == arg1) then
            local targetGUID = pendingInterrupt.guid or arg1
            HS:ShowInterrupt(unitNameForGUID(targetGUID), targetGUID)
            pendingInterrupt = nil
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if arg2 == "SPELL_INTERRUPT" or arg3 == "SPELL_INTERRUPT" then
            local playerGUID = UnitGUID and UnitGUID("player")
            local sourceGUID, targetGUID, targetName = arg4, arg7, arg8
            if sourceGUID and (sourceGUID == playerGUID or isPlayerOwnedGUID(sourceGUID)) then
                HS:ShowInterrupt(targetName or unitNameForGUID(targetGUID), targetGUID)
            end
        end
    elseif event == "SPELL_DAMAGE_EVENT_SELF" then
        local playerGUID = UnitGUID and UnitGUID("player")
        local targetGUID, casterGUID = arg1, arg2
        local targetName = unitNameForGUID(targetGUID)
        if targetGUID and targetGUID == playerGUID then
            nampowerIncomingSpellActive = true
            HS:ShowSplat(UnitName("player"), arg4, (tonumber(arg6) or 0) ~= 0, false, nampowerSchools[tonumber(arg7)], nil, true, nil, true)
        else
            if casterGUID == playerGUID then nampowerSpellDamageActive = true
            else nampowerControlledSpellActive = true end
            if targetName and targetGUID then
                recentTargetGUIDs[trimName(targetName)] = { guid = targetGUID, time = GetTime() }
            end
            HS:ShowSplat(targetName, arg4, (tonumber(arg6) or 0) ~= 0, false, nampowerSchools[tonumber(arg7)], nil, false, targetGUID)
        end
    elseif event == "SPELL_DAMAGE_EVENT_OTHER" then
        local playerGUID = UnitGUID and UnitGUID("player")
        if arg1 and arg1 == playerGUID then
            nampowerIncomingSpellActive = true
            HS:ShowSplat(UnitName("player"), arg4, (tonumber(arg6) or 0) ~= 0, false, nampowerSchools[tonumber(arg7)], nil, true, nil, true)
        elseif isPlayerOwnedGUID(arg2) then
            local targetGUID = arg1
            local targetName = unitNameForGUID(targetGUID)
            nampowerControlledSpellActive = true
            if targetName and targetGUID then
                recentTargetGUIDs[trimName(targetName)] = { guid = targetGUID, time = GetTime() }
            end
            HS:ShowSplat(targetName, arg4, (tonumber(arg6) or 0) ~= 0, false, nampowerSchools[tonumber(arg7)], nil, false, targetGUID)
        end
    elseif event == "AUTO_ATTACK_SELF" then
        local casterGUID, targetGUID = arg1, arg2
        local targetName = unitNameForGUID(targetGUID)
        local playerGUID = UnitGUID and UnitGUID("player")
        if casterGUID == playerGUID then nampowerAutoAttackActive = true
        else nampowerControlledAutoActive = true end
        if targetName and targetGUID then
            recentTargetGUIDs[trimName(targetName)] = { guid = targetGUID, time = GetTime() }
        end
        local victimState = tonumber(arg5)
        if victimState == 4 then HS:ShowInterrupt(targetName, targetGUID) end
        if victimState == 7 then
            if not HS:ShowEnemyImmune(targetName, targetGUID) then
                HS:ShowSplat(targetName, 0, false, false, nil, nil, false, targetGUID)
            end
        elseif victimState == 1 or victimState == 4 then
            HS:ShowSplat(targetName, arg3, autoAttackCrit(arg4), false, "Physical", nil, false, targetGUID)
        else
            HS:ShowSplat(targetName, 0, false, false, nil, nil, false, targetGUID)
        end
    elseif event == "AUTO_ATTACK_OTHER" then
        local playerGUID = UnitGUID and UnitGUID("player")
        if arg2 and arg2 == playerGUID then
            nampowerIncomingAutoActive = true
            if tonumber(arg5) == 1 or tonumber(arg5) == 4 then
                HS:ShowSplat(UnitName("player"), arg3, autoAttackCrit(arg4), false, "Physical", nil, true, nil, true)
            else
                HS:ShowSplat(UnitName("player"), 0, false, false, nil, nil, true, nil, true)
            end
        elseif isPlayerOwnedGUID(arg1) then
            local targetGUID = arg2
            local targetName = unitNameForGUID(targetGUID)
            nampowerControlledAutoActive = true
            if targetName and targetGUID then
                recentTargetGUIDs[trimName(targetName)] = { guid = targetGUID, time = GetTime() }
            end
            local victimState = tonumber(arg5)
            if victimState == 4 then HS:ShowInterrupt(targetName, targetGUID) end
            if victimState == 7 then
                if not HS:ShowEnemyImmune(targetName, targetGUID) then
                    HS:ShowSplat(targetName, 0, false, false, nil, nil, false, targetGUID)
                end
            elseif victimState == 1 or victimState == 4 then
                HS:ShowSplat(targetName, arg3, autoAttackCrit(arg4), false, "Physical", nil, false, targetGUID)
            else
                HS:ShowSplat(targetName, 0, false, false, nil, nil, false, targetGUID)
            end
        end
    elseif event == "SPELL_MISS_SELF" then
        local casterGUID, targetGUID = arg1, arg2
        local targetName = unitNameForGUID(targetGUID)
        local missInfo = tonumber(arg4)
        local playerGUID = UnitGUID and UnitGUID("player")
        if casterGUID == playerGUID then nampowerSpellDamageActive = true
        else nampowerControlledSpellActive = true end
        if missInfo == 7 or missInfo == 8 then
            if not HS:ShowEnemyImmune(targetName, targetGUID) then
                HS:ShowSplat(targetName, 0, false, false, nil, nil, false, targetGUID)
            end
        else
            HS:ShowSplat(targetName, 0, false, false, nil, nil, false, targetGUID)
        end
    elseif event == "SPELL_MISS_OTHER" then
        local playerGUID = UnitGUID and UnitGUID("player")
        if arg2 and arg2 == playerGUID then
            nampowerIncomingSpellActive = true
            HS:ShowSplat(UnitName("player"), 0, false, false, nil, nil, true, nil, true)
        elseif isPlayerOwnedGUID(arg1) then
            local targetGUID = arg2
            local targetName = unitNameForGUID(targetGUID)
            local missInfo = tonumber(arg4)
            nampowerControlledSpellActive = true
            if missInfo == 7 or missInfo == 8 then
                if not HS:ShowEnemyImmune(targetName, targetGUID) then
                    HS:ShowSplat(targetName, 0, false, false, nil, nil, false, targetGUID)
                end
            else
                HS:ShowSplat(targetName, 0, false, false, nil, nil, false, targetGUID)
            end
        end
    elseif event == "SPELL_HEAL_BY_SELF" then
        nampowerHealsActive = true
        local playerGUID = UnitGUID and UnitGUID("player")
        local targetName = unitNameForGUID(arg1) or (arg1 == playerGUID and UnitName("player")) or "Friendly Player"
        HS:ShowSplat(targetName, arg4, arg5 == 1, true, nil, nil, true, arg1)
    elseif event == "BUFF_ADDED_SELF" or event == "BUFF_REMOVED_SELF" or event == "DEBUFF_ADDED_SELF" or event == "DEBUFF_REMOVED_SELF" then
        nampowerAurasActive = true
        if HS.db.showStatusEffects then
            local spellName = spellNameFromID(arg3) or "Status Effect"
            local texture = spellTextureFromID(arg3)
            local stacks = tonumber(arg4) or 0
            local state = tonumber(arg7) or 0
            local stackText = stacks > 1 and " x" .. stacks or ""
            local auraKey = "aura:" .. string.lower(spellName)
            if state == 2 then return
            elseif string.find(event, "REMOVED") then
                HS:ShowStatusEffect("-" .. spellName, .65, .65, .65, texture, auraKey)
            elseif string.find(event, "DEBUFF") then
                HS:ShowStatusEffect("- " .. spellName .. stackText, 1, .3, .45, texture or "Interface\\Icons\\Spell_Shadow_CurseOfTounges", auraKey)
            else
                HS:ShowStatusEffect("+ " .. spellName .. stackText, .45, 1, .55, texture or "Interface\\Icons\\Spell_Holy_MagicalSentry", auraKey)
            end
        end
    elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        HS:HandleStatusMessage(arg1, true)
    else
        HS:HandleCombatMessage(event, arg1)
        if event == "CHAT_MSG_SPELL_SELF_BUFF" or event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
            HS:HandleStatusMessage(arg1, false)
        end
    end
end)

HS:SetScript("OnUpdate", function()
    scanElapsed = scanElapsed + (arg1 or 0)
    if scanElapsed > .25 then HS:ScanNameplates(); scanElapsed = 0 end
    local now = GetTime()
    local i, item
    for i = table.getn(active), 1, -1 do
        item = active[i]
        if (item.usesNameplate and not anchorIsVisible(item.anchor)) or now - item.started >= item.duration then
            removeActive(i)
        else
            item:SetAlpha(1)
        end
    end
    for i = table.getn(interruptActive), 1, -1 do
        item = interruptActive[i]
        local progress = (now - item.started) / item.duration
        if not anchorIsVisible(item.anchor) or progress >= 1 then
            table.remove(interruptActive, i); releaseInterrupt(item)
        elseif progress > .65 then
            item:SetAlpha(1 - ((progress - .65) / .35))
        else
            item:SetAlpha(1)
        end
    end
    for i = table.getn(statusActive), 1, -1 do
        item = statusActive[i]
        local progress = (now - item.started) / item.duration
        if progress >= 1 then
            table.remove(statusActive, i); releaseStatusItem(item)
        else
            item:SetAlpha(1 - progress)
        end
    end
    local spacing = (tonumber(HS.db.statusTextSize) or 17) + 4
    local rise = tonumber(HS.db.statusRiseDistance) or 45
    for i = 1, table.getn(statusActive) do
        item = statusActive[i]
        local progress = (now - item.started) / item.duration
        item:ClearAllPoints()
        item:SetPoint("BOTTOM", HS.StatusAnchor, "TOP", 0, 4 + (i - 1) * spacing + progress * rise)
    end
end)

SLASH_OSHS1 = "/oshs"
SLASH_OSHS2 = "/hitsplats"
SlashCmdList.OSHS = function(msg)
    msg = string.lower(msg or "")
    if msg == "test" then HS:Preview()
    elseif msg == "heal" then HS:ShowSplat(UnitName("player"), 125, false, true, nil, nil, true)
    elseif msg == "interrupt" then
        local targetName = UnitExists("target") and UnitName("target")
        local targetGUID = targetName and UnitGUID and UnitGUID("target")
        if not targetName then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555OSHS:|r target an enemy with a visible nameplate first.")
        elseif not HS:ShowInterrupt(targetName, targetGUID) then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555OSHS:|r no visible nameplate found for " .. targetName .. ".")
        end
    elseif msg == "immune" then
        local targetName = UnitExists("target") and UnitName("target")
        local targetGUID = targetName and UnitGUID and UnitGUID("target")
        if not targetName then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555OSHS:|r target an enemy with a visible nameplate first.")
        elseif not HS:ShowEnemyImmune(targetName, targetGUID) then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555OSHS:|r no visible nameplate found for " .. targetName .. ".")
        end
    elseif msg == "reset" then
        HS:ResetSettings()
        if HS.RefreshOptions then HS:RefreshOptions() end
        DEFAULT_CHAT_FRAME:AddMessage("|cffd58cffOSHS:|r settings reset.")
    elseif HS.ToggleOptions then HS:ToggleOptions()
    else DEFAULT_CHAT_FRAME:AddMessage("|cffff5555OSHS:|r options failed to load.") end
end
