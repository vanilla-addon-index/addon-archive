SoundBoard_Comms = {}

local prefix = "SOUND_BOARD"
local expectedChannel = "SoundBoardHidden"

function SoundBoard_Comms:OnChatMessage(message, sender, channelName)
    local msg = message
    local sender = sender
    local channelNameArg = channelName

    if sender == UnitName("player") then return end

    local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
    if not inGroup then return end

    -- Debug brut
    -- SoundBoard:Print("DEBUG: canal reçu = " .. tostring(channelNameArg))

    -- Vérifie le nom du canal (insensible à la casse)
    if not channelNameArg or strlower(channelNameArg) ~= strlower(expectedChannel) then
        return
    end

    -- Vérifie que le message commence par SOUND_BOARD
    if not msg or strsub(msg, 1, 11) ~= prefix then
        return
    end

    local name = strsub(msg, 12)
    if not name or name == "" then
        -- SoundBoard:Print("Réception d’un message vide.")
        return
    end

    -- SoundBoard:Print("→ Réception : " .. name .. " de " .. sender)
    SoundBoard:PlaySoundByName(name)
end
