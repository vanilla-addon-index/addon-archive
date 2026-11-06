local frame = CreateFrame("FRAME");

frame:RegisterEvent("LOOT_OPENED");
frame:SetScript("OnEvent", function(self, event, ...)
    local index;
    local x, y = GetCursorPosition();
    local scale = LootFrame:GetEffectiveScale();
    x = x / scale;
    y = y / scale;
    LootFrame:ClearAllPoints();
    for index = 1, LOOTFRAME_NUMBUTTONS, 1 do
        local button = getglobal("LootButton"..index);
        if( button:IsVisible() ) then
            x = x - 42;
            y = y + 56 + (40 * index);
            LootFrame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", x, y);
            return;
        end
    end
    if LootFrameDownButton:IsVisible() then
        x = x - 158;
        y = y + 223;
    else
        if GetNumLootItems() == 0  then
            HideUIPanel(LootFrame);
            return
        end
        x = x - 173;
        y = y + 25;
    end
    LootFrame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", x, y);
end);
