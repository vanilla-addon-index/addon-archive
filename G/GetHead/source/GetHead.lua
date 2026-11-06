local dragon = 2
local addonName = "GetHead"
local addonTitle = GetAddOnMetadata(addonName, "Title")
local addonNotes = GetAddOnMetadata(addonName, "Notes")
local addonVersion = GetAddOnMetadata(addonName, "Version")
local addonAuthor = GetAddOnMetadata(addonName, "Author")
local chatPrefix = "> "
local me = UnitName("player")
local lastDragonslayerReported = 0
local lastZandalarReported = 0

local function Message(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff".. chatPrefix .."|r "..message)
end

function GetHeadFrame.PLAYER_AURAS_CHANGED()
    --if GetHeadDisabled then return end
    local i, icon, spellid, dragonBuff, zgBuff = 1, nil, false, false
    while true do
        icon, _, spellId = UnitBuff("player", i);
        if icon == nil and spellId == nil then break end
        dragonBuff = (spellId == 22888) or (icon == "Interface\\Icons\\INV_Misc_Head_Dragon_01") -- Rallying Cry of the Dragonslayer
        zgBuff = spellId == 24425 --Spirit of Zandalar
        if dragonBuff or zgBuff then
            if dragon == 0 then
                Message((dragonBuff and "Rallying Cry of the Dragonslayer" or "Spirit of Zandalar") .. " acquired")
                if not GetHeadBroadcastDisabled then
                    local msg = dragon and "22888" or "24425"
                    if ChatThrottleLib then 
                        ChatThrottleLib:SendAddonMessage("BULK", addonName, msg, "GUILD")
                    else
                        SendAddonMessage(addonName, msg, "GUILD")
                    end
                end
                if not GetHeadLogoutDisabled then
                    Logout()
                end
            end
            dragon = 1
            return
        end
        i = i + 1
    end
    dragon = 0
end

function GetHeadFrame.CHAT_MSG_ADDON(addonTag, stringMessage, channel, sender)
    if addonTag ~= addonName then return end
    if VersionUtil:CHAT_MSG_ADDON(addonName, function(ver)
      Message("New version " .. ver .. " of " .. addonTitle .. " is available! Upgrade now at " .. addonNotes)
    end) then return end
    if not GetHeadBroadcastDisabled then
        local now = GetTime()
        if stringMessage == "24425" and lastZandalarReported + 30 < now then
            Message("Spirit of Zandalar reported by " .. sender)
            lastZandalarReported = now
        elseif stringMessage == "22888" and lastDragonslayerReported + 30 < now then
            Message("Rallying Cry of the Dragonslayer reported by " .. sender)
            lastDragonslayerReported = now
        end
    end
end

function GetHeadFrame.PARTY_MEMBERS_CHANGED()
    VersionUtil:PARTY_MEMBERS_CHANGED(addonName)
end
  
function GetHeadFrame.PLAYER_ENTERING_WORLD()
    VersionUtil:PLAYER_ENTERING_WORLD(addonName)
end

local InitSlashCommands = function()
	SLASH_GetHead1 = "/head"
	SlashCmdList["GetHead"] = function(message)
        if message == "logout" then
            GetHeadLogoutDisabled = not GetHeadLogoutDisabled
            Message("Logout is " .. (GetHeadLogoutDisabled and "off" or "on"))
        elseif message == "broadcast" then
            GetHeadBroadcastDisabled = not GetHeadBroadcastDisabled
            Message("Broadcast is " .. (GetHeadBroadcastDisabled and "off" or "on"))
        -- elseif message == "test" then
        --     GetHeadFrame.PLAYER_AURAS_CHANGED()
        else
            Message("/head logout - toggle logging out after receiving a fresh Dragonslayer of Zandalar buff")
            Message("/head broadcast - toggle broadcasting or receiving broadcasted buff drop information")
        end
    end
end

function GetHeadFrame.ADDON_LOADED()
    InitSlashCommands()
    this:UnregisterEvent("ADDON_LOADED")
end