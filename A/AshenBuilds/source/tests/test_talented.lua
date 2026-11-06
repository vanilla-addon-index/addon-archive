-- Ashen Builds must leave the Talented addon's globals alone.
check("Talented's table untouched", Talented.marker == TalentedMarker)
check("Talented:SetClassData not replaced", Talented.SetClassData() == "talented's own")
check("TalentedTooltipData not written to", TalentedTooltipData.TALENTED_OWN and TalentedTooltipData.WARRIOR == nil)
check("TalentedDataOverride not created", TalentedDataOverride == nil)
check("our talent data loaded separately", AshenBuildsTalentData.WARRIOR ~= nil and AshenBuildsTalentData ~= TalentedTooltipData)
