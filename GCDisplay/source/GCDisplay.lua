if SUPERWOW_STRING == nil or SUPERWOW_VERSION == nil then
    DEFAULT_CHAT_FRAME:AddMessage('GCDisplay requires SuperWoW to run.')
    return
end

local gcd = CreateFrame("Frame", nil)
gcd:SetPoint("CENTER", UIParent, "CENTER", 0, 70) 
gcd:SetWidth(64)
gcd:SetHeight(64)

local gcdTexture = gcd:CreateTexture(nil, "OVERLAY")
gcdTexture:SetTexture([[Interface\AddOns\GCDisplay\tga\Rounded_Normal.tga]])
gcdTexture:SetWidth(64)
gcdTexture:SetHeight(64)
gcdTexture:SetPoint("CENTER", gcd, "CENTER", 0, 0)
gcdTexture:Hide()

local spellFrame = CreateFrame("Frame", nil)
spellFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 70)
spellFrame:SetWidth(64)
spellFrame:SetHeight(64)

gcd:SetFrameLevel(spellFrame:GetFrameLevel() + 1)

local spellTexture = spellFrame:CreateTexture(nil, "OVERLAY")
spellTexture:SetWidth(64)
spellTexture:SetHeight(64)
spellTexture:SetPoint("CENTER", spellFrame, "CENTER", 0, 0)
spellTexture:Hide()

local candidateNoCdSpell = {
    Warrior = {
        "Battle Shout",
        "Rend",
        "Demoralizing Shout",
        "Sunder Armor",
    },
    Rogue = {
        'Sinister Strike',
    },
    Hunter = {
        'Aspect of the Monkey',
    },
    Priest = {
        'Power Word: Fortitude',
    },
    Mage = {
        'Arcane Intellect',
    },
    Shaman = {
        'Rockbiter Weapon',
    },
    Paladin = {
        'Devotion Aura',
    },
    Warlock = {
        'Demon Skin',
    },
    Druid = {
        'Mark of the Wild',
    },
}

local function SpellIsInCd(spellName)
    local spellId = 0
    for p = 1, 4 do
        local name, texture, offset, numSpells = GetSpellTabInfo(p)
        for s = 1, numSpells do
            spellId = spellId + 1
            local sName, sRank = GetSpellName(spellId, BOOKTYPE_SPELL)
            if sName == spellName then
                local start, duration, enabled = GetSpellCooldown(spellId, BOOKTYPE_SPELL)
                return start ~= 0
            end
        end
    end
    return false
end

local function FindSpellWithoutCd()
    local playerClass = UnitClass("player")
    local noCdSpellList = candidateNoCdSpell[playerClass]
    if noCdSpellList == nil then
        return
    end
    local spellId = 0
    for p = 1, 4 do
        local name, texture, offset, numSpells = GetSpellTabInfo(p)
        for s = 1, numSpells do
            spellId = spellId + 1
            local sName, sRank = GetSpellName(spellId, BOOKTYPE_SPELL)
            for _, candidate in pairs(noCdSpellList) do
                if candidate == sName then
                    return spellId, sName
                end
            end
        end
    end
    return nil
end
local spellId, spellName = FindSpellWithoutCd()
local lastElapsedTime = 1000
local newSpellCasted = false

local function ShowGcd()
    if gcdTexture then
        gcdTexture:Hide()
    end
    spellTexture:Hide()
    local sName
    if spellId then
        sName = GetSpellName(spellId, BOOKTYPE_SPELL)
    end
    if spellName == nil or sName ~= spellName then
        spellId, spellName = FindSpellWithoutCd()
    end
    if spellId == nil then
        return
    end
    local start, duration, enabled = GetSpellCooldown(spellId, BOOKTYPE_SPELL)
    if start == 0 then
        return
    end
    if not newSpellCasted then
        return
    end
    local elapsedTime = GetTime() - start
    if lastElapsedTime > elapsedTime then
        lastElapsedTime = elapsedTime
        if newSpellCasted then
            PlaySoundFile([[Interface\AddOns\GCDisplay\assets\sounds\plop_01.ogg]])
        end
    end
    lastElapsedTime = elapsedTime
    local ratio = elapsedTime / duration
    if ratio > 0.95 then
        gcdTexture:Hide()
        spellTexture:Hide()
        newSpellCasted = false
        return
    end
    gcdTexture:Show()
    local gcdTextureSize = (1 - ratio) * 105
    gcdTexture:SetWidth(gcdTextureSize)
    gcdTexture:SetHeight(gcdTextureSize)
    local spellTextureSize = (1 - ratio) * 64
    spellTexture:SetWidth(spellTextureSize)
    spellTexture:SetHeight(spellTextureSize)
    spellTexture:Show()
end

gcd:SetScript("OnUpdate", ShowGcd)

gcd:RegisterEvent('UNIT_CASTEVENT')

local function ShowSpellIcon(spell)
    local sId = 0
    for p = 1, 4 do
        local name, texture, offset, numSpells = GetSpellTabInfo(p)
        for s = 1, numSpells do
            sId = sId + 1
            local sName, sRank = GetSpellName(sId, BOOKTYPE_SPELL)
            if sName == spell then
                local newIcon = GetSpellTexture(sId, BOOKTYPE_SPELL)
                if newIcon then
                    spellTexture:SetTexture(newIcon)
                else
                    spellTexture:SetTexture(nil)
                end
            end
        end
    end
    return nil
end

local currentCast = nil
local function OnUnitCastEvent(caster, target, event, spellID, castDuration)
    local _, playerGuid = UnitExists('player')
    if playerGuid ~= caster then
        return
    end
    if event == "START" and castDuration > 0 then
        currentCast = spellID
    end
    if event ~= "CAST" then
        return
    end
    if spellID == currentCast then
        currentCast = nil
        return
    end
    local spell = SpellInfo(spellID)
    if not SpellIsInCd(spell) then
        return
    end

    if spell then
        ShowSpellIcon(spell)
        newSpellCasted = true
    end
end

gcd:SetScript("OnEvent", function()
    if not arg1 then return end

    local caster, target, event, spellID, castDuration = arg1, arg2, arg3, arg4, arg5
    OnUnitCastEvent(caster, target, event, spellID, castDuration)
end)
