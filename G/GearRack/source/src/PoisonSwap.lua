if not GearRack.enabled then return end

-- Swap between identical weapons carrying different temporary enchants.
-- Called from a macro; no bag-position or item-GUID state is persisted.

local function poison_swap_message(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00GearRack Poison Swap:|r " .. message)
end

-- After a saved set puts weapons on, name each hand that carries no poison, so
-- a set left unpoisoned in the bags is noticed on the first pull. Rogues only:
-- for other classes oils and stones are optional.
function GearRack.WarnUnpoisoned(request)
	local _, class = UnitClass("player")
	if class ~= "ROGUE" or not request or string.find(request.setname or "", "^GearRackEngine%-") then return end
	local main, off = request.items[16], request.items[17]
	main = main and main.id and main.id ~= 0 and main.id
	off = off and off.id and off.id ~= 0 and off.id
	if not main and not off then return end
	-- Let the client report the new weapons' enchants before reading them.
	C_Timer.After(0.5, function()
		local mainHas, _, _, offHas = GetWeaponEnchantInfo()
		main = main and not mainHas and GearRackEngine.SlotMatches(16, { id = main })
		off = off and not offHas and GearRackEngine.SlotMatches(17, { id = off })
		local hands = (main and off and "main hand and off hand have") or (main and "main hand has") or (off and "off hand has")
		if hands then
			DEFAULT_CHAT_FRAME:AddMessage("GearRack: " .. request.setname .. ": " .. hands .. " no poison.", 1, .5, .2)
		end
	end)
end

function GearRack.SwapPoison(slot, targetEnchantID)
	slot = slot or 17
	if slot ~= 16 and slot ~= 17 then
		poison_swap_message("Use equipment slot 16 (main hand) or 17 (off hand).")
		return
	end
	if targetEnchantID ~= nil and (type(targetEnchantID) ~= "number" or targetEnchantID <= 0 or targetEnchantID ~= math.floor(targetEnchantID)) then
		poison_swap_message("Target poison must be a positive enchant ID.")
		return
	end
	if SpellIsTargeting() or GetCursorInfo() then
		poison_swap_message("Finish the current cursor action first.")
		return
	end
	if GearRackEngine.IsEquipmentSwapActive() then
		poison_swap_message("A GearRack equipment swap is already active.")
		return
	end

	local wornLocation = { equipmentSlotIndex = slot }
	local itemID = C_Item.GetItemID(wornLocation)
	if not itemID then
		poison_swap_message("Equip one copy of the weapon first.")
		return
	end

	local hasWornEnchant, _, _, wornEnchantID = C_Item.GetItemTempEnchantInfo(wornLocation)
	if not hasWornEnchant or not wornEnchantID or wornEnchantID == 0 then
		poison_swap_message("The equipped weapon has no active poison.")
		return
	end
	if targetEnchantID == wornEnchantID then
		poison_swap_message("That poison is already equipped.")
		return
	end

	local candidate
	for _,entry in ipairs(GearRack.GetCarriedItems()) do
		if entry.baseID==itemID then
			local location={bagID=entry.bag,slotIndex=entry.slot}
			local hasEnchant, _, _, enchantID = C_Item.GetItemTempEnchantInfo(location)
			if hasEnchant and enchantID and enchantID ~= 0 and enchantID ~= wornEnchantID
				and (not targetEnchantID or enchantID == targetEnchantID) then
				if candidate then
					poison_swap_message("Multiple matching weapons found; specify a target enchant ID.")
					return
				end
				candidate = entry
			end
		end
	end

	if not candidate then
		poison_swap_message("No identical bagged weapon with the requested active poison was found.")
		return
	end

	-- The exact poisoned copy uses the same verified, persistent weapon request
	-- as the flyout. GCD/cast blocks must not lose a macro's desired weapon.
	GearRack.RequestItem(slot,candidate)
end
