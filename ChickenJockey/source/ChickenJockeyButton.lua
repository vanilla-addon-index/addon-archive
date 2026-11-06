--=======================================================================================
-- ChickenJockeyButton.lua
-- Minimap button for Chicken Jockey
--=======================================================================================

function ChickenJockeyButton_Init()
    if ChickenJockeyButtonFrame then
        ChickenJockeyButtonFrame:Show();
    end
    -- Also try to show immediately if Minimap exists
    if Minimap and ChickenJockeyButtonFrame then
        ChickenJockeyButtonFrame:Show();
    end
end

function ChickenJockeyButton_OnClick(button)
    if button == "LeftButton" then
        local frame = getglobal("ChickenJockeyFrame")
        if frame then
            if frame:IsVisible() then
                frame:Hide()
            else
                frame:Show()
            end
        end
    end
end
