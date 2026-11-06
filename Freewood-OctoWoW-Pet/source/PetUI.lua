-- Freewood-OctoWoW-Pet: Tab "Begleiter" im Freewood-Fenster
-- Links die Liste der erfassten Begleiter, rechts Kennzahlen, Nahrung und Faehigkeiten.
-- Aufbau angelehnt an das Stitch-Design "Jaeger Begleiter" (Filter/Liste links, Details rechts).

local ADDON, NS = ...

local FW = _G.Freewood
local Pet = NS.Pet
if not FW or not Pet then
    return
end

local UI = FW.UI

local LIST_W = 252
local ROW_H, ROW_GAP = 54, 6
local CARD_W, CARD_H, CARD_GAP = 176, 48, 10
local ABILITY_H = 30

local function FormatTime(t)
    if type(t) ~= "number" or t <= 0 then
        return "-"
    end
    return date("%d.%m.%Y %H:%M", t)
end

local function SortedKeys()
    local keys = {}
    for key in pairs(Pet.db.pets) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        if a == b then
            return false
        end
        if a == Pet.activeKey then
            return true
        end
        if b == Pet.activeKey then
            return false
        end
        local ra, rb = Pet.db.pets[a], Pet.db.pets[b]
        local ia, ib = ra.src == "import", rb.src == "import"
        if ia ~= ib then
            return not ia
        end
        local ua, ub = ra.updated or 0, rb.updated or 0
        if ua ~= ub then
            return ua > ub
        end
        return a < b
    end)
    return keys
end

local function Subtitle(rec)
    return string.format("%s  -  %s", rec.family or "?", string.format(FW.L.PET_LEVEL, rec.level or 0))
end

------------------------------------------------------------------------
-- Zeile der Liste
------------------------------------------------------------------------

local function CreateListRow(parent, onSelect)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    UI.AddBorder(row, "bronze", 0.6)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(34, 34)
    row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = UI.CreateLabel(row, "", { font = "heading", size = 13, color = "goldLight" })
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 52, -10)
    row.name:SetWidth(LIST_W - 130)
    row.name:SetWordWrap(false)

    row.sub = UI.CreateLabel(row, "", { size = 11, color = "textDim" })
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)
    row.sub:SetWidth(LIST_W - 70)
    row.sub:SetWordWrap(false)

    row.chip = UI.CreateChip(row, "", "success")
    row.chip:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -9)

    local function Refresh()
        if row.selected then
            row.bg:SetColorTexture(UI.Color("hover"))
            UI.SetBorderColor(row, "gold")
        elseif row.hover then
            row.bg:SetColorTexture(UI.Color("hover", 0.7))
            UI.SetBorderColor(row, "bronze")
        else
            row.bg:SetColorTexture(UI.Color("card"))
            UI.SetBorderColor(row, "bronze", 0.6)
        end
    end

    function row:SetSelected(selected)
        self.selected = selected
        Refresh()
    end

    row:SetScript("OnEnter", function()
        row.hover = true
        Refresh()
    end)
    row:SetScript("OnLeave", function()
        row.hover = false
        Refresh()
    end)
    row:SetScript("OnClick", function()
        onSelect(row.key)
    end)

    Refresh()
    return row
end

------------------------------------------------------------------------
-- Tab
------------------------------------------------------------------------

local function Build(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)

    local rows, abilityRows, foodChips = {}, {}, {}

    ---------------- linke Spalte ----------------
    local listTitle = UI.CreateLabel(f, L.PET_LIST_HEADER, { font = "heading", size = 14, color = "goldLight" })
    listTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local listDivider = UI.CreateDivider(f)
    listDivider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -26)
    listDivider:SetWidth(LIST_W)

    local listScroll = UI.CreateScrollFrame(f)
    listScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)
    listScroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    listScroll:SetWidth(LIST_W)

    local separator = f:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(UI.Color("bronze", 0.4))
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 10, 0)
    separator:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", LIST_W + 10, 0)

    ---------------- rechte Spalte ----------------
    local detail = CreateFrame("Frame", nil, f)
    detail:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 22, 0)
    detail:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    local empty = UI.CreateLabel(f, L.PET_EMPTY, { size = 12, color = "textDim", justifyV = "TOP", justify = "LEFT" })
    empty:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 22, -4)
    empty:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -4)
    empty:SetWordWrap(true)

    local headIcon = CreateFrame("Frame", nil, detail)
    headIcon:SetSize(48, 48)
    headIcon:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
    headIcon.tex = headIcon:CreateTexture(nil, "ARTWORK")
    headIcon.tex:SetPoint("TOPLEFT", headIcon, "TOPLEFT", 2, -2)
    headIcon.tex:SetPoint("BOTTOMRIGHT", headIcon, "BOTTOMRIGHT", -2, 2)
    headIcon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    UI.AddBorder(headIcon, "gold", 1)

    local nameLabel = UI.CreateLabel(detail, "", { font = "heading", size = 20, color = "goldLight" })
    nameLabel:SetPoint("TOPLEFT", detail, "TOPLEFT", 60, 0)
    nameLabel:SetWidth(380)
    nameLabel:SetWordWrap(false)

    local subLabel = UI.CreateLabel(detail, "", { size = 12, color = "textDim" })
    subLabel:SetPoint("TOPLEFT", detail, "TOPLEFT", 60, -28)

    local stateChip = UI.CreateChip(detail, "", "success")
    stateChip:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, -4)

    local updatedLabel = UI.CreateLabel(detail, "", { size = 11, color = "textDim", justify = "RIGHT" })
    updatedLabel:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, -32)
    updatedLabel:SetWidth(240)

    local headDivider = UI.CreateDivider(detail)
    headDivider:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -58)
    headDivider:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, -58)

    -- Kennzahlen
    local cards = {}
    local defs = {
        { key = "happiness", label = L.PET_HAPPINESS },
        { key = "loyalty", label = L.PET_LOYALTY },
        { key = "training", label = L.PET_TRAINING },
        { key = "health", label = L.PET_HEALTH },
        { key = "damage", label = L.PET_DAMAGE },
        { key = "armor", label = L.PET_ARMOR },
        { key = "ap", label = L.PET_AP },
        { key = "crit", label = L.PET_CRIT },
        { key = "move", label = L.PET_MOVE },
    }
    for i, def in ipairs(defs) do
        local card = UI.CreateStatCard(detail, def.label, CARD_W, CARD_H)
        UI.SetFont(card.value, "heading", 13)
        local col = (i - 1) % 3
        local rowIndex = math.floor((i - 1) / 3)
        card:SetPoint("TOPLEFT", detail, "TOPLEFT", col * (CARD_W + CARD_GAP), -(68 + rowIndex * (CARD_H + CARD_GAP)))
        -- Familienfaktor oben rechts auf der Karte
        card.factor = UI.CreateLabel(card, "", { size = 10, color = "textDim", justify = "RIGHT", flags = "" })
        card.factor:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -8)
        cards[def.key] = card
    end

    -- Widerstaende (Schulen 2 bis 6)
    local RES_W, RES_GAP = 100, 12
    local resDefs = {
        { school = 2, label = L.PET_RES_FIRE },
        { school = 3, label = L.PET_RES_NATURE },
        { school = 4, label = L.PET_RES_FROST },
        { school = 5, label = L.PET_RES_SHADOW },
        { school = 6, label = L.PET_RES_ARCANE },
    }
    local resCards = {}
    for i, def in ipairs(resDefs) do
        local card = UI.CreateStatCard(detail, def.label, RES_W, CARD_H)
        UI.SetFont(card.value, "heading", 13)
        card:SetPoint("TOPLEFT", detail, "TOPLEFT", (i - 1) * (RES_W + RES_GAP), -(68 + 3 * (CARD_H + CARD_GAP)))
        resCards[def.school] = card
    end

    -- Tooltips: lesen den aktuell angezeigten Eintrag (current) beim Darueberfahren
    local current
    local function NoData()
        return { L.PET_TIP_NODATA }
    end
    local function ArmorReduction(armor, level)
        if type(PaperDollFrame_GetArmorReduction) == "function" then
            local ok, v = pcall(PaperDollFrame_GetArmorReduction, armor, level)
            if ok and type(v) == "number" then
                return v
            end
        end
        local r = armor / (armor + 400 + 85 * level) * 100
        return math.min(75, r)
    end
    local function TipLines(key)
        local rec = current
        local lines = {}
        if not rec then
            return NoData()
        end
        if key == "health" then
            lines = { L.PET_TIP_HEALTH_1, L.PET_TIP_HEALTH_2 }
        elseif key == "armor" then
            if not rec.armor then return NoData() end
            lines = { string.format(L.PET_TIP_ARMOR_1, ArmorReduction(rec.armor, rec.level or 1)), L.PET_TIP_ARMOR_2 }
        elseif key == "damage" then
            if not (rec.dmgMin and rec.dmgMax) then return NoData() end
            lines = { string.format(L.PET_TIP_DAMAGE_1, rec.dmgMin, rec.dmgMax) }
            if rec.speed and rec.speed > 0 then
                lines[#lines + 1] = string.format(L.PET_TIP_DAMAGE_2, rec.speed)
                lines[#lines + 1] = string.format(L.PET_TIP_DAMAGE_3, (rec.dmgMin + rec.dmgMax) / 2 / rec.speed)
            end
        elseif key == "ap" then
            if not rec.apBase then return NoData() end
            local bonus = rec.apBonus or 0
            lines = { string.format(L.PET_TIP_AP_1, rec.apBase, bonus, rec.apBase + bonus), L.PET_TIP_AP_2 }
        elseif key == "crit" then
            if not (rec.critMelee or rec.critSpell or rec.critRanged) then return NoData() end
            if rec.critMelee then lines[#lines + 1] = string.format(L.PET_TIP_CRIT_1, rec.critMelee) end
            if rec.critSpell then lines[#lines + 1] = string.format(L.PET_TIP_CRIT_2, rec.critSpell) end
            if rec.critRanged then lines[#lines + 1] = string.format(L.PET_TIP_CRIT_3, rec.critRanged) end
            lines[#lines + 1] = L.PET_TIP_CRIT_4
        elseif key == "move" then
            if not rec.runSpeed then return NoData() end
            lines = { string.format(L.PET_TIP_MOVE_1, rec.runSpeed, math.floor(rec.runSpeed / 7 * 100 + 0.5)) }
        end
        return lines
    end
    local tipTitles = {
        health = L.PET_TIP_HEALTH, armor = L.PET_TIP_ARMOR, damage = L.PET_TIP_DAMAGE,
        ap = L.PET_TIP_AP, crit = L.PET_TIP_CRIT, move = L.PET_TIP_MOVE,
    }
    for key, title in pairs(tipTitles) do local key = key
        UI.AttachTooltip(cards[key], title, function() return TipLines(key) end)
    end
    for school, card in pairs(resCards) do local school = school
        UI.AttachTooltip(card, L.PET_TIP_RES, function()
            local v = current and current.resist and current.resist[school]
            if not v then return NoData() end
            local pct = math.min(75, v / (math.max(1, current.level or 1) * 5) * 75)
            return { string.format(L.PET_TIP_RES_1, v), string.format(L.PET_TIP_RES_2, pct), L.PET_TIP_RES_3 }
        end)
    end

    -- Faktor als Text und Farbe: ueber 1 gold, unter 1 gedaempft, 1,00 neutral
    local function SetFactor(card, factor)
        if not factor then
            card.factor:SetText("")
            return
        end
        local color = "textDim"
        if factor > 1.0001 then
            color = "goldLight"
        elseif factor < 0.9999 then
            color = "danger"
        end
        card.factor:SetText(string.format("x%.2f", factor))
        card.factor:SetTextColor(UI.Color(color))
    end

    -- Nahrung
    local foodLabel = UI.CreateLabel(detail, L.PET_FOOD, { font = "heading", size = 13, color = "goldLight" })
    foodLabel:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -300)
    local foodNone = UI.CreateLabel(detail, L.PET_FOOD_UNKNOWN, { size = 12, color = "textDim" })
    foodNone:SetPoint("LEFT", foodLabel, "RIGHT", 14, 0)

    -- Faehigkeiten
    local abilityTitle = UI.CreateLabel(detail, L.PET_ABILITIES, { font = "heading", size = 14, color = "goldLight" })
    abilityTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -336)
    local abilityDivider = UI.CreateDivider(detail)
    abilityDivider:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -360)
    abilityDivider:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, -360)

    local abilityScroll = UI.CreateScrollFrame(detail)
    abilityScroll:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -368)
    abilityScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 42)

    local abilityNote = UI.CreateLabel(abilityScroll.child, "", { size = 11, color = "textDim" })

    -- Knoepfe
    local status = UI.CreateLabel(detail, "", { size = 12 })
    status:SetWidth(360)

    local refreshButton = UI.CreateButton(detail, L.PET_REFRESH, 170, 28, function()
        local ok, reason = Pet:Scan()
        if ok then
            status:SetText("|cff" .. UI.Hex("success") .. FW.L.PET_REFRESH_OK .. "|r")
        else
            local msg = FW.L.PET_REFRESH_FAIL
            if reason == "nopet" then
                msg = FW.L.PET_REFRESH_NOPET
            elseif reason == "combat" then
                msg = FW.L.PET_REFRESH_COMBAT
            elseif reason == "error" or reason == "nodata" then
                msg = FW.L.PET_REFRESH_ERROR
            end
            status:SetText("|cff" .. UI.Hex("danger") .. msg .. "|r")
        end
    end, "primary")
    refreshButton:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 0)

    local confirming = false
    local deleteButton
    deleteButton = UI.CreateButton(detail, L.PET_DELETE, 160, 28, function()
        if confirming then
            confirming = false
            deleteButton:SetLabel(FW.L.PET_DELETE)
            deleteButton:SetStyle("danger")
            if Pet.selectedKey then
                Pet:Delete(Pet.selectedKey)
            end
        else
            confirming = true
            deleteButton:SetLabel(FW.L.PET_DELETE_CONFIRM)
            deleteButton:SetStyle("dangerActive")
            C_Timer.After(3, function()
                confirming = false
                deleteButton:SetLabel(FW.L.PET_DELETE)
                deleteButton:SetStyle("danger")
            end)
        end
    end, "danger")
    deleteButton:SetPoint("LEFT", refreshButton, "RIGHT", 8, 0)

    status:SetPoint("LEFT", deleteButton, "RIGHT", 16, 0)

    ---------------- Inhalt fuellen ----------------
    local HAPPINESS = {
        [3] = { text = function() return FW.L.PET_HAPPY end, color = "success" },
        [2] = { text = function() return FW.L.PET_CONTENT end, color = "goldLight" },
        [1] = { text = function() return FW.L.PET_UNHAPPY end, color = "danger" },
    }

    local function ShowFoods(foods)
        for _, chip in ipairs(foodChips) do
            chip:Hide()
        end
        if type(foods) ~= "table" or #foods == 0 then
            foodNone:Show()
            return
        end
        foodNone:Hide()
        local previous
        for i, food in ipairs(foods) do
            local chip = foodChips[i]
            if not chip then
                chip = UI.CreateChip(detail, food, "bronze")
                foodChips[i] = chip
            end
            chip:SetText(food, "goldAntique")
            chip:ClearAllPoints()
            if previous then
                chip:SetPoint("LEFT", previous, "RIGHT", 6, 0)
            else
                chip:SetPoint("LEFT", foodLabel, "RIGHT", 14, 0)
            end
            chip:Show()
            previous = chip
        end
    end

    local function ShowAbilities(rec)
        local list = rec.abilities or {}
        local others = rec.others or {}

        for i, ability in ipairs(list) do
            local row = abilityRows[i]
            if not row then
                row = UI.CreatePanel(abilityScroll.child, "card", "bronze")
                row:SetHeight(ABILITY_H)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(ABILITY_H - 8, ABILITY_H - 8)
                row.icon:SetPoint("LEFT", row, "LEFT", 5, 0)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.name = UI.CreateLabel(row, "", { size = 12 })
                row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                row.passive = UI.CreateLabel(row, "", { size = 10, color = "textDim", justify = "RIGHT" })
                row.chip = UI.CreateChip(row, "", "goldLight")
                row.chip:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                row.passive:SetPoint("RIGHT", row.chip, "LEFT", -8, 0)
                abilityRows[i] = row
            end
            local y = (i - 1) * (ABILITY_H + 4)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", abilityScroll.child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", abilityScroll.child, "TOPRIGHT", 0, -y)
            row.name:SetText(ability.name or "?")
            local tex
            if ability.spellID then
                if C_Spell and C_Spell.GetSpellTexture then
                    local ok, t = pcall(C_Spell.GetSpellTexture, ability.spellID)
                    tex = ok and t or nil
                elseif GetSpellTexture then
                    local ok, t = pcall(GetSpellTexture, ability.spellID)
                    tex = ok and t or nil
                end
            end
            row.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.passive:SetText(ability.passive and FW.L.PET_PASSIVE or "")
            if ability.rank then
                row.chip:SetText(string.format(FW.L.PET_RANK, ability.rank), "goldLight")
                row.chip:Show()
            else
                row.chip:Hide()
            end
            row:Show()
        end
        for i = #list + 1, #abilityRows do
            abilityRows[i]:Hide()
        end

        local y = #list * (ABILITY_H + 4)
        local noteText
        if #list == 0 then
            noteText = FW.L.PET_NO_ABILITIES
        elseif #others > 0 then
            noteText = string.format(FW.L.PET_OTHERS, #others)
        end
        abilityNote:ClearAllPoints()
        abilityNote:SetPoint("TOPLEFT", abilityScroll.child, "TOPLEFT", 4, -(y + 6))
        abilityNote:SetText(noteText or "")
        abilityScroll:SetContentHeight(y + 30)
    end

    local function ShowRecord(key, rec)
        current = rec
        local L2 = FW.L
        nameLabel:SetText(rec.name or "?")
        headIcon.tex:SetTexture(Pet.FamilyIcon and Pet.FamilyIcon(rec.family) or "Interface\\Icons\\Ability_Hunter_BeastTaming")
        subLabel:SetText(Subtitle(rec))
        updatedLabel:SetText(string.format(L2.PET_UPDATED, FormatTime(rec.updated or rec.importedAt)))

        if key == Pet.activeKey then
            stateChip:SetText(L2.PET_ACTIVE, "success")
            stateChip:Show()
        elseif rec.src == "import" then
            stateChip:SetText(L2.PET_IMPORTED, "textDim")
            stateChip:Show()
        else
            stateChip:Hide()
        end

        -- Zufriedenheit
        local happy = HAPPINESS[rec.happiness or 0]
        if happy then
            local text = happy.text()
            if rec.damagePct then
                text = string.format("%s (%d%%)", text, rec.damagePct)
            end
            cards.happiness:SetValue(text, happy.color)
        else
            cards.happiness:SetValue("-", "textDim")
        end

        -- Treue
        if rec.loyaltyText then
            local plain = rec.loyaltyText:gsub("^%b()%s*", "")
            local text = plain ~= "" and plain or rec.loyaltyText
            if rec.loyaltyLevel then
                text = rec.loyaltyLevel .. " - " .. text
            end
            cards.loyalty:SetValue(text)
        else
            cards.loyalty:SetValue("-", "textDim")
        end

        -- Trainingspunkte
        if rec.trainingTotal then
            local free = math.max(0, rec.trainingTotal - (rec.trainingSpent or 0))
            cards.training:SetValue(string.format(L2.PET_TRAINING_VALUE, free, rec.trainingTotal))
        else
            cards.training:SetValue("-", "textDim")
        end

        -- Leben, Schaden (mit Tempo im Titel), Ruestung, dazu die Familienfaktoren
        local mods = Pet.GetFamilyMods and Pet.GetFamilyMods(rec.family)
        if rec.hpMax then
            cards.health:SetValue(string.format("%d", rec.hpMax))
        else
            cards.health:SetValue("-", "textDim")
        end
        SetFactor(cards.health, mods and mods.hp)
        if rec.dmgMin and rec.dmgMax then
            cards.damage:SetValue(string.format("%d - %d", rec.dmgMin, rec.dmgMax))
        else
            cards.damage:SetValue("-", "textDim")
        end
        if rec.speed then
            cards.damage:SetLabel(string.format("%s  |  %.1f s", L2.PET_DAMAGE, rec.speed))
        else
            cards.damage:SetLabel(L2.PET_DAMAGE)
        end
        SetFactor(cards.damage, mods and mods.dmg)
        SetFactor(cards.armor, mods and mods.armor)
        if rec.armor then
            cards.armor:SetValue(string.format("%d", rec.armor))
        else
            cards.armor:SetValue("-", "textDim")
        end

        -- Zusatzwerte
        if rec.apBase then
            cards.ap:SetValue(string.format("%d", rec.apBase + (rec.apBonus or 0)))
        else
            cards.ap:SetValue("-", "textDim")
        end
        local crit = rec.critRanged or rec.critMelee
        if crit then
            cards.crit:SetValue(string.format("%.2f%%", crit))
        else
            cards.crit:SetValue("-", "textDim")
        end
        if rec.runSpeed then
            cards.move:SetValue(string.format("%d%%", math.floor(rec.runSpeed / 7 * 100 + 0.5)))
        else
            cards.move:SetValue("-", "textDim")
        end
        for school, card in pairs(resCards) do
            local v = rec.resist and rec.resist[school]
            if v then
                card:SetValue(string.format("%d", v))
            else
                card:SetValue("-", "textDim")
            end
        end

        ShowFoods(rec.foods)
        ShowAbilities(rec)
    end

    function f.Refresh()
        local keys = SortedKeys()

        if not Pet.selectedKey or not Pet.db.pets[Pet.selectedKey] then
            Pet.selectedKey = (Pet.activeKey and Pet.db.pets[Pet.activeKey]) and Pet.activeKey or keys[1]
        end

        for i, key in ipairs(keys) do
            local rec = Pet.db.pets[key]
            local row = rows[i]
            if not row then
                row = CreateListRow(listScroll.child, function(selectedKey)
                    Pet.selectedKey = selectedKey
                    f.Refresh()
                end)
                rows[i] = row
            end
            row.key = key
            local y = (i - 1) * (ROW_H + ROW_GAP)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", listScroll.child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", listScroll.child, "TOPRIGHT", 0, -y)
            row.name:SetText(rec.name or "?")
            row.icon:SetTexture(Pet.FamilyIcon and Pet.FamilyIcon(rec.family) or "Interface\\Icons\\Ability_Hunter_BeastTaming")
            row.sub:SetText(Subtitle(rec))
            if key == Pet.activeKey then
                row.chip:SetText(FW.L.PET_ACTIVE, "success")
                row.chip:Show()
            elseif rec.src == "import" then
                row.chip:SetText(FW.L.PET_IMPORTED, "textDim")
                row.chip:Show()
            else
                row.chip:Hide()
            end
            row:SetSelected(key == Pet.selectedKey)
            row:Show()
        end
        for i = #keys + 1, #rows do
            rows[i]:Hide()
        end
        listScroll:SetContentHeight(#keys * (ROW_H + ROW_GAP))

        local rec = Pet.selectedKey and Pet.db.pets[Pet.selectedKey]
        if rec then
            empty:Hide()
            detail:Show()
            ShowRecord(Pet.selectedKey, rec)
            refreshButton:SetButtonEnabled(UnitExists("pet") and true or false)
        else
            detail:Hide()
            empty:Show()
        end
    end

    FW:On("PET_UPDATED", function()
        if f:IsVisible() then
            f.Refresh()
        end
    end)

    f.Refresh()
    return f
end

UI:RegisterTab("pet", {
    label = function()
        return FW.L.PET_TAB
    end,
    order = 60,
    build = Build,
    onShow = function(f)
        f.Refresh()
    end,
})

SLASH_FREEWOODPET1 = "/fwpet"
SlashCmdList["FREEWOODPET"] = function()
    UI:Toggle("pet")
end
