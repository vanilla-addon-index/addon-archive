local ADDON_NAME = "swapondeath"

local motc_equipped = false
local seal_equipped = false
local re_equip_timer = 0
local re_equip_count = 0

-- Interface
local frame = CreateFrame("Frame",nil,UIParent)

local function is_trinket_equipped(slot, name)
    local link = GetInventoryItemLink("player", slot)
    if not link then return end
    for id, name_equipped in string.gfind(link, "|c%x+|Hitem:(%d+):%d+:%d+:%d+|h%[(.-)%]|h|r$") do
        if name == name_equipped then
            return true
        end
    end
end

local function scan_equipped_items()
    motc_equipped = is_trinket_equipped(13, "Mark of the Champion") or is_trinket_equipped(14, "Mark of the Champion")
    seal_equipped = is_trinket_equipped(13, "Seal of the Dawn") or is_trinket_equipped(14, "Seal of the Dawn")
end

local function re_equip()
    if motc_equipped or seal_equipped then
        PickupInventoryItem(13)
        PickupInventoryItem(14)
        UIErrorsFrame:AddMessage("Re-equipped bugged trinket")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_ALIVE")
-- frame:RegisterEvent("PLAYER_DEAD")

frame:SetScript("OnEvent", function()

    -- DEFAULT_CHAT_FRAME:AddMessage("event: " .. tostring(event))
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        scan_equipped_items()
    end
    if event == 'UNIT_INVENTORY_CHANGED' then
        scan_equipped_items()
    end

    if event == 'PLAYER_UNGHOST'
    or (event == 'PLAYER_ALIVE' and not UnitIsDeadOrGhost("player"))
    then
        scan_equipped_items()
        if re_equip_timer < GetTime() - 5 then
            re_equip_timer = GetTime()
            re_equip()
        end
    end
end);

frame:SetScript("OnUpdate", function()
    if re_equip_timer ~= 0 and re_equip_timer < GetTime() - 5 then
        re_equip()
        re_equip_timer = 0
    end
end);
