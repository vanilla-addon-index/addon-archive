local function MTHSmartAmmo_GetModuleStore()
	if MTH and MTH.GetModuleCharSavedVariables then
		return MTH:GetModuleCharSavedVariables("smartammo")
	end
	return nil
end

-- Single source of truth: moduleStore.settings.{smartEnabled,reloadEnabled,weaponSwapEnabled}
local function MTHSmartAmmo_GetSettings()
	local moduleStore = MTHSmartAmmo_GetModuleStore()
	if type(moduleStore) ~= "table" then
		return nil
	end
	if type(moduleStore.settings) ~= "table" then
		moduleStore.settings = {}
	end
	return moduleStore.settings
end

local function MTHSmartAmmo_ReadFlag(key)
	local settings = MTHSmartAmmo_GetSettings()
	if settings and settings[key] ~= nil then
		return settings[key] and true or false
	end
	return true -- default enabled
end

local function MTHSmartAmmo_WriteFlag(key, enabled)
	local settings = MTHSmartAmmo_GetSettings()
	if settings then
		settings[key] = enabled and true or false
	end
end

local function MTHSmartAmmo_IsSmartEnabled()
	return MTHSmartAmmo_ReadFlag("smartEnabled")
end

local function MTHSmartAmmo_IsReloadEnabled()
	return MTHSmartAmmo_ReadFlag("reloadEnabled")
end

local function MTHSmartAmmo_IsWeaponSwapEnabled()
	return MTHSmartAmmo_ReadFlag("weaponSwapEnabled")
end

local function MTHSmartAmmo_IsLowAmmoWarningEnabled()
	return MTHSmartAmmo_ReadFlag("lowAmmoWarningEnabled")
end

local function MTHSmartAmmo_ReadLowAmmoThreshold()
	local settings = MTHSmartAmmo_GetSettings()
	local threshold = tonumber(settings and settings.lowAmmoThreshold) or 200
	if threshold < 1 then threshold = 1 end
	return math.floor(threshold)
end

local MTHSmartAmmo_InitializeHooks
MTHSmartAmmo_EnsureHooks = nil

local MTH_SA_SPELL_EVENTS = {
	"START_AUTOREPEAT_SPELL",
	"STOP_AUTOREPEAT_SPELL",
	"SPELLCAST_INTERRUPTED",
	"SPELLCAST_FAILED",
	"SPELLCAST_STOP",
	"SPELLCAST_DELAYED",
}

function MTHSmartAmmo_SetSmartEnabled(enabled, silent)
	if enabled then
		local evFrame = getglobal("MTH_SA_EventFrame")
		if evFrame then
			for _, ev in ipairs(MTH_SA_SPELL_EVENTS) do
				evFrame:RegisterEvent(ev)
			end
		end
		if MTHSmartAmmo_InitializeHooks then
			MTHSmartAmmo_InitializeHooks()
		end
		if MTHSmartAmmo_EnsureHooks then
			MTHSmartAmmo_EnsureHooks("SetSmartEnabled")
		end
		if not silent and DEFAULT_CHAT_FRAME then
			MTH_SA_Print("Smart Ammo Enabled.")
		end
	else
		local evFrame = getglobal("MTH_SA_EventFrame")
		if evFrame then
			for _, ev in ipairs(MTH_SA_SPELL_EVENTS) do
				evFrame:UnregisterEvent(ev)
			end
		end
		if not silent and DEFAULT_CHAT_FRAME then
			MTH_SA_Print("Smart Ammo Disabled.")
		end
	end

	MTHSmartAmmo_WriteFlag("smartEnabled", enabled and true or false)
end

function MTHSmartAmmo_GetSmartEnabled()
	return MTHSmartAmmo_IsSmartEnabled() and true or false
end

function MTHSmartAmmo_SetReloadEnabled(enabled, silent)
	MTHSmartAmmo_WriteFlag("reloadEnabled", enabled and true or false)
	if not silent and DEFAULT_CHAT_FRAME then
		MTH_SA_Print("Smart Ammo reload fallback " .. (enabled and "Enabled." or "Disabled."))
	end
end

function MTHSmartAmmo_GetReloadEnabled()
	return MTHSmartAmmo_IsReloadEnabled() and true or false
end

function MTHSmartAmmo_SetWeaponSwapEnabled(enabled, silent)
	MTHSmartAmmo_WriteFlag("weaponSwapEnabled", enabled and true or false)
	if not silent and DEFAULT_CHAT_FRAME then
		MTH_SA_Print("Smart Ammo weapon-swap auto-equip " .. (enabled and "Enabled." or "Disabled."))
	end
end

function MTHSmartAmmo_GetWeaponSwapEnabled()
	return MTHSmartAmmo_IsWeaponSwapEnabled() and true or false
end

function MTHSmartAmmo_SetLowAmmoWarningEnabled(enabled, silent)
	MTHSmartAmmo_WriteFlag("lowAmmoWarningEnabled", enabled and true or false)
	if not silent and DEFAULT_CHAT_FRAME then
		MTH_SA_Print("Smart Ammo low-ammo warnings " .. (enabled and "Enabled." or "Disabled."))
	end
end

function MTHSmartAmmo_GetLowAmmoWarningEnabled()
	return MTHSmartAmmo_IsLowAmmoWarningEnabled() and true or false
end

function MTHSmartAmmo_SetLowAmmoThreshold(value)
	local settings = MTHSmartAmmo_GetSettings()
	if not settings then return end
	local threshold = tonumber(value) or 200
	if threshold < 1 then threshold = 1 end
	settings.lowAmmoThreshold = math.floor(threshold)
end

function MTHSmartAmmo_GetLowAmmoThreshold()
	return MTHSmartAmmo_ReadLowAmmoThreshold()
end

local MTHSmartAmmo_CastSpell_Hook
local MTHSmartAmmo_UseAction_Hook
local MTHSmartAmmo_CastSpellByName_Hook
local MTHSmartAmmo_HookEnsureElapsed = 0
local MTHSmartAmmo_InCastSpellHook = false
local MTHSmartAmmo_InUseActionHook = false
local MTHSmartAmmo_InCastSpellByNameHook = false
local MTHSmartAmmo_OriginalCastSpell = CastSpell
local MTHSmartAmmo_OriginalUseAction = UseAction
local MTHSmartAmmo_OriginalCastSpellByName = CastSpellByName

local function MTHSmartAmmo_AreHooksInstalled()
	return CastSpell == MTHSmartAmmo_CastSpell_Hook,
		UseAction == MTHSmartAmmo_UseAction_Hook,
		CastSpellByName == MTHSmartAmmo_CastSpellByName_Hook
end

local function MTHSmartAmmo_ForceHookGlobals()
	if type(MTHSmartAmmo_CastSpell_Hook) == "function" and CastSpell ~= MTHSmartAmmo_CastSpell_Hook then
                if CastSpell == MTHSmartAmmo_OriginalCastSpell or MTH_SA_CastSpell == nil then
                        MTH_SA_CastSpell = CastSpell
                        CastSpell = MTHSmartAmmo_CastSpell_Hook
                end
        end
        if type(MTHSmartAmmo_UseAction_Hook) == "function" and UseAction ~= MTHSmartAmmo_UseAction_Hook then
                if UseAction == MTHSmartAmmo_OriginalUseAction or MTH_SA_UseAction == nil then
                        MTH_SA_UseAction = UseAction
                        UseAction = MTHSmartAmmo_UseAction_Hook
                end
        end
        if type(MTHSmartAmmo_CastSpellByName_Hook) == "function" and CastSpellByName ~= MTHSmartAmmo_CastSpellByName_Hook then
                if CastSpellByName == MTHSmartAmmo_OriginalCastSpellByName or MTH_SA_CastSpellByName == nil then
                        MTH_SA_CastSpellByName = CastSpellByName
                        CastSpellByName = MTHSmartAmmo_CastSpellByName_Hook
                end
        end
end

MTH_SA = {}
MTH_SA_List = {}

MTH_SA_LastCheck = 0

MTH_SA_Tooltip = getglobal("MTH_SA_AmmoProbe") or CreateFrame("GameTooltip", "MTH_SA_AmmoProbe", nil, "GameTooltipTemplate")
MTH_SA_TooltipTextLeft1 = getglobal("MTH_SA_AmmoProbeTextLeft1")
MTH_SA_Tooltip:Hide()

local _, class = UnitClass("player")

	if class ~= "HUNTER" then 
		return 
	end

MTH_SA_IsWaitingSwapJunk = nil 
MTH_SA_IsWaitingSwapGood = nil 
MTH_SA_AutoShot = nil
MTH_SA_LastSpell = nil
MTH_SA_UpdateInterval = 0.1
MTH_SA_Quantity = 0
MTH_SA_LastFallbackAttempt = 0
MTH_SA_LastKnownEquippedName = nil
MTH_SA_LastFallbackNotice = { key = nil, time = 0 }
MTH_SA_LastKnownWeaponAmmoType = nil
MTH_SA_LastWeaponCheck = 0
MTH_SA_LastAmmoStockCheck = 0
MTH_SA_AmmoStockState = nil
MTH_SA_StartupProtectUntil = (GetTime() or 0) + 2.0
MTH_SA_StartupPrimed = nil

local function MTHSmartAmmo_RefreshAmmoButtonDisplay()
	local createButtons = getglobal("zButtonAmmo_CreateButtons")
	local setupSizeAndPosition = getglobal("zButtonAmmo_SetupSizeAndPosition")
	local ammoButton = getglobal("zButtonAmmo")
	if type(createButtons) == "function" and ammoButton then
		createButtons()
		if type(setupSizeAndPosition) == "function" then
			setupSizeAndPosition()
		end
	end
end

local function MTHSmartAmmo_ShowFallbackWarning(previousAmmo, newAmmo)
	if not previousAmmo or previousAmmo == "" or not newAmmo or newAmmo == "" then
		return
	end
	if previousAmmo == newAmmo then
		return
	end

	local now = GetTime() or 0
	local key = tostring(previousAmmo) .. "=>" .. tostring(newAmmo)
	if MTH_SA_LastFallbackNotice.key == key and (now - (MTH_SA_LastFallbackNotice.time or 0)) < 1.0 then
		return
	end
	MTH_SA_LastFallbackNotice.key = key
	MTH_SA_LastFallbackNotice.time = now

	local warning = "YOU RAN OUT OF " .. tostring(previousAmmo) .. ", I EQUIPPED " .. tostring(newAmmo) .. " !"
	if MTH_SA_Print then
		MTH_SA_Print(warning)
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(warning)
	end

	local hasWarningAnimation = type(MTH_CelebrateAmmoFallback) == "function"
		and type(MTH_FX_IsEnabled) == "function" and MTH_FX_IsEnabled("combat.ammoout")
	if hasWarningAnimation then
		MTH_CelebrateAmmoFallback(previousAmmo, newAmmo)
	elseif RaidWarningFrame and RaidNotice_AddMessage and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
		RaidNotice_AddMessage(RaidWarningFrame, warning, ChatTypeInfo["RAID_WARNING"])
	elseif UIErrorsFrame and UIErrorsFrame.AddMessage then
		UIErrorsFrame:AddMessage(warning, 1.0, 0.15, 0.15, 1.0)
	end

	if type(MTH_FX_Flash) == "function" and type(MTH_FX_IsEnabled) == "function"
		and MTH_FX_IsEnabled("combat.ammoswap") then
		local target = getglobal("zButtonAmmo")
		if target then
			MTH_FX_Flash(target, 1.00, 0.75, 0.20, 0.5)
		end
	end
end

local function MTHSmartAmmo_ShowAmmoStockWarning(ammoType, total, threshold)
	local isZero = total <= 0
	local warning
	if isZero then
		warning = "Out of " .. ammoType .. "! Your ranged weapon is now a very expensive club."
	else
		warning = "Running low on " .. ammoType .. " — only " .. tostring(total) .. " left. Restock before you're just angrily pointing at things."
	end
	if MTH_SA_Print then
		MTH_SA_Print(warning)
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(warning)
	end

	local flag = isZero and "combat.ammozero" or "combat.lowammo"
	local celebrate = isZero and MTH_CelebrateAmmoZero or MTH_CelebrateLowAmmo
	if type(celebrate) == "function" and type(MTH_FX_IsEnabled) == "function" and MTH_FX_IsEnabled(flag) then
		celebrate(ammoType, total, threshold)
	elseif RaidWarningFrame and RaidNotice_AddMessage and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
		RaidNotice_AddMessage(RaidWarningFrame, warning, ChatTypeInfo["RAID_WARNING"])
	elseif UIErrorsFrame and UIErrorsFrame.AddMessage then
		UIErrorsFrame:AddMessage(warning, 1.0, 0.15, 0.15, 1.0)
	end
end

local function MTHSmartAmmo_CountAmmoStock(ammoType)
	local rankMap = (ammoType == "Bullets" and MTH_AMMO_BULLET_RANK) or MTH_AMMO_ARROW_RANK or {}
	-- Bag scan already covers the quiver/ammo pouch; GetInventoryItemCount("player", 0)
	-- returns the bag copies of the loaded ammo, so adding it would double-count.
	local total = 0
	for bag = 4, 0, -1 do
		for slot = GetContainerNumSlots(bag), 1, -1 do
			local itemName = MTH_SA_GetContainerItemName(bag, slot)
			if itemName and rankMap[itemName] then
				local _, count = GetContainerItemInfo(bag, slot)
				total = total + (tonumber(count) or 1)
			end
		end
	end
	return total
end

-- ready < low < zero; a warning fires only when severity INCREASES (a real
-- downward crossing during play), never on the cold baseline or on restock.
local function MTHSmartAmmo_StockSeverity(state)
	if state == "zero" then return 2 end
	if state == "low" then return 1 end
	return 0
end

local function MTHSmartAmmo_CheckAmmoStock()
	if not MTH_SA_IsModuleEnabled() or not MTHSmartAmmo_IsLowAmmoWarningEnabled() then return end
	local ammoType = MTH_SA_GetEquippedWeaponAmmoType()
	if not ammoType then
		MTH_SA_AmmoStockState = nil
		return
	end
	local total = MTHSmartAmmo_CountAmmoStock(ammoType)
	local threshold = MTHSmartAmmo_ReadLowAmmoThreshold()
	local state = total <= 0 and "zero" or (total <= threshold and "low" or "ready")

	local prev = MTH_SA_AmmoStockState
	if prev ~= nil and MTHSmartAmmo_StockSeverity(state) > MTHSmartAmmo_StockSeverity(prev) then
		MTHSmartAmmo_ShowAmmoStockWarning(ammoType, total, threshold)
	end
	MTH_SA_AmmoStockState = state
end

local MTHSmartAmmo_FallbackCheckFrame = nil

local function MTHSmartAmmo_HandleFallbackResult(previousAmmo)
	if not MTHSmartAmmo_FallbackCheckFrame then
		MTHSmartAmmo_FallbackCheckFrame = CreateFrame("Frame", "MTH_SA_FallbackCheck")
		if not MTHSmartAmmo_FallbackCheckFrame then
			return
		end
	end
	local checkFrame = MTHSmartAmmo_FallbackCheckFrame
	checkFrame.elapsed = 0
	checkFrame._previousAmmo = previousAmmo
	checkFrame:SetScript("OnUpdate", function()
		this.elapsed = (this.elapsed or 0) + (arg1 or 0)
		if this.elapsed < 0.2 then
			return
		end

		local equippedNow = MTH_SA_GetEquippedAmmoName()
		if equippedNow and equippedNow ~= "" then
			MTH_SA_LastKnownEquippedName = equippedNow
		end

		MTHSmartAmmo_RefreshAmmoButtonDisplay()
		MTHSmartAmmo_ShowFallbackWarning(this._previousAmmo, equippedNow)

		this:SetScript("OnUpdate", nil)
		this:Hide()
	end)
	checkFrame:Show()
end

local function MTHSmartAmmo_TryFallbackEquip(reason)
	local now = GetTime() or 0
	if now < (MTH_SA_StartupProtectUntil or 0) then
		return
	end
	if not MTH_SA_IsModuleEnabled() then
		return
	end
	if not MTHSmartAmmo_IsSmartEnabled() then
		return
	end
	if not MTHSmartAmmo_IsReloadEnabled() then
		return
	end
	if MTH_SA_GetEquippedAmmoName() then
		return
	end

	now = GetTime() or 0
	if MTH_SA_LastFallbackAttempt and (now - MTH_SA_LastFallbackAttempt) < 0.5 then
		return
	end
	MTH_SA_LastFallbackAttempt = now
	local previousAmmo = MTH_SA_GetEquippedAmmoName() or MTH_SA_LastKnownEquippedName

	if MTH_SA_Check() or MTH_SA_FindAmmo() then
		MTH_SA_EquipAmmo()
		MTHSmartAmmo_HandleFallbackResult(previousAmmo)
	end
end

local function MTHSmartAmmo_FindBestAmmoForType(ammoType)
	if not ammoType then
		return nil
	end
	local rankMap = (ammoType == "Bullets" and MTH_AMMO_BULLET_RANK) or MTH_AMMO_ARROW_RANK or {}
	local best = nil
	for bag = 4, 0, -1 do
		for slot = GetContainerNumSlots(bag), 1, -1 do
			local itemName = MTH_SA_GetContainerItemName(bag, slot)
			if itemName then
				local value = rankMap[itemName]
				if value and (not best or value > best.value) then
					best = {
						name = itemName,
						value = value,
						bag = bag,
						slot = slot,
					}
				end
			end
		end
	end
	return best
end

local function MTHSmartAmmo_EquipAmmoFromSlot(bag, slot)
	if not bag or not slot then
		return false
	end
	PickupContainerItem(bag, slot)
	if CursorHasItem and CursorHasItem() then
		EquipCursorItem(0)
	end
	if CursorHasItem and CursorHasItem() then
		if ClearCursor then
			ClearCursor()
		end
		return false
	end
	return true
end

local function MTHSmartAmmo_HandleWeaponSwapAutoEquip(reason)
	local now = GetTime() or 0
	if now < (MTH_SA_StartupProtectUntil or 0) then
		return
	end
	if not MTH_SA_IsModuleEnabled() then
		return
	end
	if not MTHSmartAmmo_IsWeaponSwapEnabled() then
		return
	end

	local weaponAmmoType = MTH_SA_GetEquippedWeaponAmmoType()
	if not weaponAmmoType then
		MTH_SA_LastKnownWeaponAmmoType = nil
		MTH_SA_StartupPrimed = true
		return
	end

	if not MTH_SA_StartupPrimed then
		MTH_SA_LastKnownWeaponAmmoType = weaponAmmoType
		MTH_SA_StartupPrimed = true
		return
	end

	if MTH_SA_LastKnownWeaponAmmoType == weaponAmmoType then
		return
	end
	MTH_SA_LastKnownWeaponAmmoType = weaponAmmoType

	local bestAmmo = MTHSmartAmmo_FindBestAmmoForType(weaponAmmoType)
	if not bestAmmo then
		return
	end

	local equippedNow = MTH_SA_GetEquippedAmmoName()
	if equippedNow and equippedNow == bestAmmo.name then
		return
	end

	if MTHSmartAmmo_EquipAmmoFromSlot(bestAmmo.bag, bestAmmo.slot) then
		MTH_SA_LastKnownEquippedName = bestAmmo.name
		MTHSmartAmmo_RefreshAmmoButtonDisplay()
		if type(MTH_FX_Flash) == "function" and type(MTH_FX_IsEnabled) == "function"
			and MTH_FX_IsEnabled("combat.rangedswap") then
			local target = getglobal("zButtonAmmo")
			if target then
				MTH_FX_Flash(target, 0.30, 0.70, 1.00, 0.5)
			end
		end
	end
end

local frame = getglobal("MTH_SA_EventFrame") or CreateFrame("Frame", "MTH_SA_EventFrame")
frame:RegisterEvent("START_AUTOREPEAT_SPELL")
frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
frame:RegisterEvent("SPELLCAST_INTERRUPTED")
frame:RegisterEvent("SPELLCAST_FAILED")
frame:RegisterEvent("SPELLCAST_STOP")
frame:RegisterEvent("SPELLCAST_DELAYED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")


frame:SetScript("OnEvent", function()
	if event == "START_AUTOREPEAT_SPELL" then
		if MTHSmartAmmo_EnsureHooks then
			MTHSmartAmmo_EnsureHooks("EVENT:START_AUTOREPEAT_SPELL")
		end
		MTH_SA_AutoShot = 1
		MTHSmartAmmo_TryFallbackEquip("START_AUTOREPEAT_SPELL")
	elseif event == "STOP_AUTOREPEAT_SPELL" then
		MTH_SA_AutoShot = nil

	elseif event == "PLAYER_ENTERING_WORLD" then
		local now = GetTime() or 0
		MTH_SA_StartupProtectUntil = now + 2.0
		MTH_SA_StartupPrimed = nil
		MTH_SA_LastKnownWeaponAmmoType = MTH_SA_GetEquippedWeaponAmmoType()
		MTH_SA_LastKnownEquippedName = MTH_SA_GetEquippedAmmoName()
		MTH_SA_LastWeaponCheck = now

	elseif event == "SPELLCAST_START" then
		--DEFAULT_CHAT_FRAME:AddMessage("SPELLCAST_START ", 0, 1, 1)

	elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" or event == "SPELLCAST_DELAYED"  then
		if MTH_SA_IsWaitingSwapJunk then
			MTH_SA_EquipAmmo(1)
		elseif MTH_SA_IsWaitingSwapGood then
			MTH_SA_EquipAmmo()
		end
		MTH_SA_IsWaitingSwapJunk = nil 
		MTH_SA_IsWaitingSwapGood = nil
		MTH_SA_LastSpell = nil
	end
end)




local MTH_SA_OnUpdateElapsed = 0

frame:SetScript("OnUpdate", function()
	local dt = arg1 or 0
	MTHSmartAmmo_HookEnsureElapsed = MTHSmartAmmo_HookEnsureElapsed + dt
	MTH_SA_OnUpdateElapsed = MTH_SA_OnUpdateElapsed + dt
	if MTH_SA_OnUpdateElapsed < 0.10 then
		return
	end
	MTH_SA_OnUpdateElapsed = 0
	
	MTH_SA_CountEquippedAmmo()
	if MTH_SA_Quantity == 0 and not MTH_SA_IsWaitingSwapJunk and not MTH_SA_IsWaitingSwapGood then
		MTHSmartAmmo_TryFallbackEquip("OnUpdate-quantity-zero")
	end

	if MTH_SA_AmmoLastSwitch and (GetTime()-MTH_SA_AmmoLastSwitch > 0.5) and (MTH_SA_IsWaitingSwapJunk or MTH_SA_IsWaitingSwapGood) then
		if MTH_SA_IsWaitingSwapJunk then
			MTH_SA_EquipAmmo(1)
		elseif MTH_SA_IsWaitingSwapGood then
			MTH_SA_EquipAmmo()
		end
		MTH_SA_IsWaitingSwapJunk = nil 
		MTH_SA_IsWaitingSwapGood = nil
		MTH_SA_LastSpell = nil
	end 

	local now = GetTime() or 0
	if (now - (MTH_SA_LastWeaponCheck or 0)) >= 0.25 then
		MTH_SA_LastWeaponCheck = now
		MTHSmartAmmo_HandleWeaponSwapAutoEquip("OnUpdate-weapon-check")
	end
	if (now - (MTH_SA_LastAmmoStockCheck or 0)) >= 1.0 then
		MTH_SA_LastAmmoStockCheck = now
		MTHSmartAmmo_CheckAmmoStock()
	end
end)

function MTH_SA_CountEquippedAmmo()
	local ammo = GetInventoryItemCount("player", 0)
	local equippedName = MTH_SA_GetEquippedAmmoName()
	if equippedName and equippedName ~= "" then
                if equippedName ~= MTH_SA_LastKnownEquippedName then
                        MTH_SA_LastKnownEquippedName = equippedName
                        MTHSmartAmmo_RefreshAmmoButtonDisplay()
                end
	elseif ammo ~= MTH_SA_Quantity then
		MTH_SA_Quantity = ammo
	end
	
end 


function MTH_SA_GetEquippedWeaponAmmoType()
	local itemlink = GetInventoryItemLink("player", 18)
	if not itemlink then return end
	local _, _, itemid = string.find(itemlink, "item:(%d+)")
	if not itemid then return end
	local _, _, _, _, _, wpntype = GetItemInfo(itemid)
	if wpntype == MTH_WEAPON_BOWS or wpntype == MTH_WEAPON_CROSSBOWS then
		return "Arrows"
	elseif wpntype == MTH_WEAPON_GUNS then
		return "Bullets"
	end
end

function MTH_SA_GetEquippedAmmoName()
	MTH_SA_Tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	if MTH_SA_Tooltip:SetInventoryItem("player", 0) then
		return MTH_SA_TooltipTextLeft1:GetText()
	end
	return nil
end

function MTH_SA_GetContainerItemName(bag, slot)
	if not (bag and slot) then return nil end
	local item = GetContainerItemLink(bag, slot)
	local _, _, name = string.find(item or "", "%[(.+)%]")
	return name
end

function MTH_SA_EquipAmmo(junk)
	if not MTH_SA_AmmoLastSwitch then MTH_SA_AmmoLastSwitch = GetTime() end

	if not (MTH_SA_Check() or MTH_SA_FindAmmo()) then
		return
	end
	local bag, slot
	if junk then
		--DEFAULT_CHAT_FRAME:AddMessage("Time= " .. GetTime()-MTH_SA_AmmoLastSwitch , 0, 1, 1)
		if GetTime()-MTH_SA_AmmoLastSwitch > 0.5 then
			--DEFAULT_CHAT_FRAME:AddMessage("JUNK ! GetTime > 0.5 | Equipped=" .. MTH_SA_GetEquippedAmmoName() .. ' | Current=' .. MTH_SA.curname   , 0, 1, 1)
		else
			--DEFAULT_CHAT_FRAME:AddMessage("JUNK ! GetTime <= 0.5 | Equipped=" .. MTH_SA_GetEquippedAmmoName() .. ' | Current=' .. MTH_SA.curname   , 0, 1, 1)
		end 

		if MTH_SA_GetEquippedAmmoName() ~= MTH_SA.curname and GetTime()-MTH_SA_AmmoLastSwitch > 0.5 then
			if not MTH_SA_FindAmmo() then
				return
			end
		end
		bag, slot = MTH_SA.junkbag, MTH_SA.junkslot
	else
		bag, slot = MTH_SA.curbag, MTH_SA.curslot
	end
	

	
	--UseContainerItem(bag, slot)
	PickupContainerItem(bag,slot)	
	EquipCursorItem(0)	
	if junk then
		MTH_SA_IsWaitingSwapJunk = nil 
		MTH_SA_IsWaitingSwapGood = 1
	else
		MTH_SA_IsWaitingSwapJunk = nil
		MTH_SA_IsWaitingSwapGood = nil
	end 
	--PickupInventoryItem(0)
	--AutoEquipCursorItem()
	--EquipCursorItem(0)	

	MTH_SA_AmmoLastSwitch = GetTime()
end

function MTH_SA_FindAmmo()
	MTH_SA = {}
	MTH_SA_List = {}
	local ammotype = MTH_SA_GetEquippedWeaponAmmoType()
	if not ammotype then
		return
	end
	local curammo = MTH_SA_GetEquippedAmmoName()
	if not curammo and not MTHSmartAmmo_IsReloadEnabled() then
		return
	end
	local ammolist = (ammotype == "Bullets" and MTH_AMMO_BULLET_RANK) or MTH_AMMO_ARROW_RANK or {}
	MTH_SA_List = ammolist
	local item, value
	local junkvalue = 999
	local goodvalue
	for bag=4, 0, -1 do
		for slot=GetContainerNumSlots(bag), 1, -1 do
			item = MTH_SA_GetContainerItemName(bag, slot)
			
			if item then
				--DEFAULT_CHAT_FRAME:AddMessage("item = " .. item .. " | value = " .. ammolist[item], 0, 1, 1)
				value = ammolist[item]
				if value then
					
					if not goodvalue and item == curammo then
						MTH_SA.curvalue = value
						MTH_SA.curname = item
						MTH_SA.curbag = bag
						MTH_SA.curslot = slot
						goodvalue = value
						--DEFAULT_CHAT_FRAME:AddMessage("goodvalue A = " .. value , 0, 1, 1)
						if junkvalue == 1 then
							return 1
						end
					end
					if value < junkvalue then
						MTH_SA.junkvalue = item
						MTH_SA.junkname = item
						MTH_SA.junkbag = bag
						MTH_SA.junkslot = slot
						junkvalue = value
						--DEFAULT_CHAT_FRAME:AddMessage("junkvalue A = " .. value , 0, 1, 1)
						if not curammo then
							MTH_SA.curvalue = value
							MTH_SA.curname = item
							MTH_SA.curbag = bag
							MTH_SA.curslot = slot
							goodvalue = value
							--DEFAULT_CHAT_FRAME:AddMessage("goodvalue B = " .. value , 0, 1, 1)
						end
						if junkvalue == 1 and goodvalue then
							return 1
						end
					end
				end
			end
		end
	end
	if not goodvalue or junkvalue > goodvalue then
		MTH_SA.error = 1
		return
	end
	return 1
end

function MTH_SA_Check()
	if not MTH_SA.error and MTH_SA.curname and MTH_SA.junkname then
		if MTH_SA.curname == MTH_SA_GetContainerItemName(MTH_SA.curbag, MTH_SA.curslot) and
		MTH_SA.junkname == MTH_SA_GetContainerItemName(MTH_SA.junkbag, MTH_SA.junkslot) then
			return 1
		end
	end
end

MTHSmartAmmo_CastSpell_Hook = function(spell, tab)
	if MTHSmartAmmo_InCastSpellHook then
		if MTHSmartAmmo_OriginalCastSpell then
			return MTHSmartAmmo_OriginalCastSpell(spell, tab)
		end
		return
	end
	MTHSmartAmmo_InCastSpellHook = true

	if MTHSmartAmmo_IsSmartEnabled() then
		local name = GetSpellName(spell, tab)
		MTH_SA_LastSpell = name
		if name and MTH_AMMO_JUNKSHOT_SET and MTH_AMMO_JUNKSHOT_SET[name] then
			if MTH_SA_Check() or MTH_SA_FindAmmo() then
				MTH_SA_EquipAmmo(1)
			end
		end
	end

	local result
	local original = MTH_SA_CastSpell
	if original == MTHSmartAmmo_CastSpell_Hook or original == nil then
		original = MTHSmartAmmo_OriginalCastSpell
	end
	if original then
		result = original(spell, tab)
	end

	MTHSmartAmmo_InCastSpellHook = false
	return result
end

MTHSmartAmmo_UseAction_Hook = function(slot, checkCursor, onSelf)
	if MTHSmartAmmo_InUseActionHook then
		if MTHSmartAmmo_OriginalUseAction then
			return MTHSmartAmmo_OriginalUseAction(slot, checkCursor, onSelf)
		end
		return
	end
	MTHSmartAmmo_InUseActionHook = true

	local _actionText = GetActionText(slot)
	local _smart = MTHSmartAmmo_IsSmartEnabled()
	if not _actionText and _smart then
		MTH_SA_Tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		MTH_SA_Tooltip:SetAction(slot)
		local name = MTH_SA_TooltipTextLeft1:GetText()
		MTH_SA_LastSpell = name
		local _inSet = name and MTH_AMMO_JUNKSHOT_SET and MTH_AMMO_JUNKSHOT_SET[name]
		if _inSet then
			if MTH_SA_Check() or MTH_SA_FindAmmo() then
				MTH_SA_EquipAmmo(1)
			end
		end
	end

	local result
	local original = MTH_SA_UseAction
	if original == MTHSmartAmmo_UseAction_Hook or original == nil then
		original = MTHSmartAmmo_OriginalUseAction
	end
	if original then
		result = original(slot, checkCursor, onSelf)
	end

	MTHSmartAmmo_InUseActionHook = false
	return result
end

MTHSmartAmmo_CastSpellByName_Hook = function(spell, onSelf)
	if MTHSmartAmmo_InCastSpellByNameHook then
		if MTHSmartAmmo_OriginalCastSpellByName then
			return MTHSmartAmmo_OriginalCastSpellByName(spell, onSelf)
		end
		return
	end
	MTHSmartAmmo_InCastSpellByNameHook = true

	local _, _, name = string.find(spell or "", "([%w%'%s]+)")
	MTH_SA_LastSpell = name
	if name and MTHSmartAmmo_IsSmartEnabled() and MTH_AMMO_JUNKSHOT_SET and MTH_AMMO_JUNKSHOT_SET[name] then
		if MTH_SA_Check() or MTH_SA_FindAmmo() then
			MTH_SA_EquipAmmo(1)
		end
	end

	local result
	local original = MTH_SA_CastSpellByName
	if original == MTHSmartAmmo_CastSpellByName_Hook or original == nil then
		original = MTHSmartAmmo_OriginalCastSpellByName
	end
	if original then
		result = original(spell, onSelf)
	end

	MTHSmartAmmo_InCastSpellByNameHook = false
	return result
end

-- Defer hooking until after tables are initialized
MTHSmartAmmo_InitializeHooks = function()
	if not MTH_SA_IsModuleEnabled() then
		return
	end

-- Only install a hook if vanilla is on top (first-time install) or MetaHunt
        -- is already on top. If another addon (e.g. Quiver) is on top, it has already
        -- captured MetaHunt's hook as its super — reinstalling would create a double
        -- invocation and break addons that rely on IsCurrentAction after their super call.
        if CastSpell ~= MTHSmartAmmo_CastSpell_Hook then
                if CastSpell == MTHSmartAmmo_OriginalCastSpell or MTH_SA_CastSpell == nil then
                        MTH_SA_CastSpell = CastSpell
                        CastSpell = MTHSmartAmmo_CastSpell_Hook
                end
        end

        if UseAction ~= MTHSmartAmmo_UseAction_Hook then
                if UseAction == MTHSmartAmmo_OriginalUseAction or MTH_SA_UseAction == nil then
                        MTH_SA_UseAction = UseAction
                        UseAction = MTHSmartAmmo_UseAction_Hook
                end
        end

        if CastSpellByName ~= MTHSmartAmmo_CastSpellByName_Hook then
                if CastSpellByName == MTHSmartAmmo_OriginalCastSpellByName or MTH_SA_CastSpellByName == nil then
                        MTH_SA_CastSpellByName = CastSpellByName
                        CastSpellByName = MTHSmartAmmo_CastSpellByName_Hook
                end
	end
end

MTHSmartAmmo_EnsureHooks = function(reason)
	if not MTH_SA_IsModuleEnabled() then
		return false
	end
	if not MTHSmartAmmo_IsSmartEnabled() then
		return false
	end

	if MTHSmartAmmo_InitializeHooks then
		local ok, err = pcall(MTHSmartAmmo_InitializeHooks)
		if not ok then end
	end

	local castHook, actionHook, byNameHook = MTHSmartAmmo_AreHooksInstalled()
	if castHook and actionHook and byNameHook then
		return true
	end

	MTHSmartAmmo_ForceHookGlobals()
	castHook, actionHook, byNameHook = MTHSmartAmmo_AreHooksInstalled()
	return castHook and actionHook and byNameHook
end

-- Initialize hooks on module load
if not MTH_SA_MANAGED_HOOKS then
	MTHSmartAmmo_InitializeHooks()
end

SLASH_MTHSmartAmmo1 = "/smartammo"
SlashCmdList["MTHSmartAmmo"] = function(msg)
	if not MTH_SA_IsModuleEnabled() then
		MTH_SA_Print("Smart Ammo is disabled while module 'smartammo' is disabled.")
		return
	end

	local smartEnabled = MTHSmartAmmo_GetSmartEnabled()

	if msg == "status" then
		local castHook, actionHook, byNameHook = MTHSmartAmmo_AreHooksInstalled()
		MTH_SA_Print("Smart Ammo status: smart=" .. tostring(smartEnabled) .. ", module=" .. tostring(MTH_SA_IsModuleEnabled()) .. ", hooks=" .. tostring(castHook) .. "/" .. tostring(actionHook) .. "/" .. tostring(byNameHook))
		return
	end

	if smartEnabled then
		MTHSmartAmmo_SetSmartEnabled(nil)
	else
		MTHSmartAmmo_SetSmartEnabled(1)
	end
end