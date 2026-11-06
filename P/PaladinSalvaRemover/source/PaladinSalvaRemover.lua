local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_AURAS_CHANGED")

f:SetScript("OnEvent", function()
        if event == "PLAYER_AURAS_CHANGED" then
            if CheckRigteousFurry() then
            	CancelSalvationBuff()
            end
        end
    end)

function CheckRigteousFurry()
    local buff = "Spell_Holy_SealOfFury"
    local counter = 0
    while GetPlayerBuff(counter) >= 0 do
        local index, untilCancelled = GetPlayerBuff(counter)
        if untilCancelled == 1 then
            local texture = GetPlayerBuffTexture(index)
            if texture then  
                if string.find(texture, buff) then
                	return true
            	end
            end
        end
        counter = counter + 1
    end
    return false
end

function CancelSalvationBuff()
    local buff = {"Spell_Holy_SealOfSalvation", "Spell_Holy_GreaterBlessingofSalvation"}
    local counter = 0
    while GetPlayerBuff(counter) >= 0 do
        local index, untilCancelled = GetPlayerBuff(counter)
        if untilCancelled ~= 1 then
            local texture = GetPlayerBuffTexture(index)
            if texture then 
                local i = 1
                while buff[i] do
                    if string.find(texture, buff[i]) then
                        CancelPlayerBuff(index);
                        UIErrorsFrame:Clear();
                        UIErrorsFrame:AddMessage("Salvation Removed");
                        return
                    end
                    i = i + 1
                end
            end
        end
        counter = counter + 1
    end
    return nil
end
