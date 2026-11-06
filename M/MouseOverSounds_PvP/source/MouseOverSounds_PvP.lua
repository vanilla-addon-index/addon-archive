local MouseOverSounds_PvP = CreateFrame("Frame","MouseOverSounds_PvP")
MouseOverSounds_PvP:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
MouseOverSounds_PvP:SetParent(GameTooltip) -- To only fire onupdate when tooltip is shown

local lastShowingOfTooltip = 0
local lastUpdateTooltip = 0

MouseOverSounds_PvP:SetScript('OnUpdate', function(self, elapsed)

	local firstShowing = GetTime() > lastShowingOfTooltip + 0.3
	
	lastShowingOfTooltip = GetTime()

	if GetTime() > lastUpdateTooltip + 3 then -- Don't update this every frame (for perf)
		lastUpdateTooltip = GetTime()
	end
	
end)

MouseOverSounds_PvP:SetScript("OnEvent", function(self,event, ...)

	local unit = 'mouseover' 
	
	if not (UnitIsPVP(unit)) then return end
	
	-- enemy npc
	if not (UnitPlayerControlled(unit)) and UnitIsEnemy("player", unit) then
		PlaySoundFile([[Interface\AddOns\MouseOverSounds_PvP\pvp.ogg]], 'Master')
		return
	end

	if (UnitPlayerControlled(unit)) then
		-- enemy or friendly player pvp flagged
		PlaySoundFile([[Interface\AddOns\MouseOverSounds_PvP\pvp.ogg]], 'Master')
		return
	end

end)