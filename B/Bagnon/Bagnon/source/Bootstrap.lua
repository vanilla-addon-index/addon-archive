-- Enhanced Client startup contract for Bagnon.

Bagnon_EngineReady = CLASSIC_API_VERSION
	and type(CLASSIC_API_VERSION) == "number"

	and C_Timer
	and C_Timer.NewTimer
	and C_EventUtils and C_EventUtils.IsEventValid
	and C_EventUtils.IsEventValid("BAG_UPDATE_DELAYED")
	and C_EventUtils.IsEventValid("GET_ITEM_INFO_RECEIVED")
	and C_Container
	and C_Container.GetContainerItemID
	and C_Container.SortBags
	and C_Container.SetItemSearch
	and C_EventUtils.IsEventValid("INVENTORY_SEARCH_UPDATE")
	and C_Item and C_Item.GetItemTempEnchantInfo and C_Item.GetEnchantInfo and C_Item.GetItemQualityByID
	and C_Spell and C_Spell.GetSpellTexture
	and table.wipe

if not Bagnon_EngineReady then
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[Bagnon Fatal Error]|r Bagnon requires the Enhanced 1.12.1 engine (ClassicAPI with bag batching, timers, container sorting and item enchant metadata).", 1, 0.2, 0.2)
	end
	return
end
