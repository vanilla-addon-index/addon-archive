if not GearRack.enabled then
    for _, name in ipairs({"GearRackUIFrame","GearRackUI_InvFrame","GearRackMinimapButton","GearRackUI_SetsFrame","GearRackTrinkets_Frame","GearRackTrinkets_MainFrame","GearRackTrinkets_MenuFrame","GearRackTrinkets_OptFrame"}) do
        local frame=_G[name]
        if frame then frame:Hide() end
    end
end
