
function HendriShift(consumable, form)
    if form ~= 'Cat Form' and form ~= 'Dire Bear Form' then
        DEFAULT_CHAT_FRAME:AddMessage('Wrong form. Accepted forms "Cat Form", "Dire Bear Form".')
        return false
    end

    local bagId = -1
    local itemSlot = -1
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bag) do
            local item = GetContainerItemLink(bag, slot)
            if item and string.find(item, consumable, 1, true) then
                bagId = bag
                itemSlot = slot
                break
            end
        end
    end

    local formId = 1 -- bear
    if form == 'Cat Form' then
        formId = 3
    end

    local _, _, inForm = GetShapeshiftFormInfo(formId)
    local _, formCD = GetSpellCooldown(R_FindSpell(form), BOOKTYPE_SPELL)
    local _, potCD = GetContainerItemCooldown(bagId, itemSlot)

    local canForm = formCD == 0
    local canPot = potCD == 0

    if bagId == -1 or itemSlot == -1 then
        DEFAULT_CHAT_FRAME:AddMessage('Item ' .. consumable .. ' not found in bags.')
        if inForm then
            return false
        end
        canPot = false
    end


    if not inForm and canForm and canPot then
        UseContainerItem(bagId, itemSlot, true)
    end
    if not inForm and canForm and not canPot then
        CastSpellByName(form)
    end
    if not inForm and not canForm then
        -- you're fucked
    end
    if inForm and canPot then
        CastSpellByName(form) --debear
    end

end

function R_FindSpell(spellName)
    local maxSpells = 500;
    local id = 0;
    local searchName;
    local subName;
    while id <= maxSpells do
        id = id + 1;
        searchName, subName = GetSpellName(id, BOOKTYPE_SPELL);
        if searchName then
            if string.lower(searchName) == string.lower(spellName) then
                local nextName = GetSpellName(id + 1, BOOKTYPE_SPELL)
                if string.lower(nextName) ~= string.lower(searchName) then
                    break ;
                end
            end
        end
    end
    if id == maxSpells then
        id = nil
    end
    return id;
end
