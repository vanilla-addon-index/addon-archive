local gfind = string.gmatch or string.gfind
local flyerTimer = CreateFrame("Frame")
flyerTimer:RegisterEvent("UI_ERROR_MESSAGE")
flyerTimer:SetScript("OnEnter", function() this:SetOwner(this, "ANCHOR_NONE") end)
flyerTimer:SetScript("OnEvent", function()
  if BigWigsBars == nil then return end
  for seconds in gfind(arg1, "You will be dismounted in ([0-9]+) seconds.") do
    if not BigWigsBars.frames or not BigWigsBars.frames.emphasizeAnchor or not BigWigsBars.frames.emphasizeAnchor.moduleBars then BigWigsBars:OnEnable() end
    local s = tonumber(seconds)
    BigWigsBars:BigWigs_StartBar(BigWigsCommonAuras, "Mounted", s, "Interface\\Icons\\ability_mount_gryphon_01")
  end
end)
