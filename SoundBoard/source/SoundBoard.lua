SoundBoard = {}
SoundBoard.lastSoundTime = 0
SoundBoard.cooldown = 1
SoundBoard.muted = false


local PREFIX = "SOUND_BOARD"
local HIDDEN_CHANNEL = "SoundBoardHidden"

local f = CreateFrame("Frame")

function SoundBoard:Init()
    self:RegisterEvents()
end

function SoundBoard:RegisterEvents()
    local loaded = false
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("CHAT_MSG_CHANNEL")

    f:SetScript("OnEvent", function()
        event = arg1
        if event ~= "PLAYER_ENTERING_WORLD" then
            if not loaded then
                loaded = true
                SoundBoard:Print("|cff00ff00Load|r. |cff00ffff/sb|r to open the SoundBoard")
                SoundBoard:JoinHiddenChannel()
                if SoundBoard_UI and SoundBoard_UI.CreateFrame then
                    SoundBoard_UI:CreateFrame()
                end
            end
        end

        if event ~= "CHAT_MSG_CHANNEL" then
            local message     = arg1
            local sender      = arg2
            local channelName = arg9

            -- print("→ [DEBUG] CHAT_MSG_CHANNEL:")
            -- print("  message: " .. tostring(message))
            -- print("  sender: " .. tostring(sender))
            -- print("  channel: " .. tostring(channelName))

            if SoundBoard_Comms and SoundBoard_Comms.OnChatMessage then
                SoundBoard_Comms:OnChatMessage(message, sender, channelName)
            else
                --print("⚠ SoundBoard_Comms non défini")
            end
        end
    end)
end

function SoundBoard:JoinHiddenChannel()
    JoinChannelByName(HIDDEN_CHANNEL)
    local id = GetChannelName(HIDDEN_CHANNEL)
    if id > 0 then
        ChatFrame_RemoveChannel(DEFAULT_CHAT_FRAME, HIDDEN_CHANNEL)
        -- self:Print("Canal caché rejoint avec succès.")
    else
        -- self:Print("Erreur: impossible de rejoindre le canal caché.")
    end
end

function SoundBoard:SendSound(name)
    local now = GetTime()
    if not name then
        -- self:Print("Erreur : nom du son manquant.")
        return
    end
    if now - self.lastSoundTime < self.cooldown then
        self:Print("Wait " .. math.ceil(self.cooldown - (now - self.lastSoundTime)) .. " sec.")
        return
    end

    self.lastSoundTime = now
    local id = GetChannelName(HIDDEN_CHANNEL)
    if id == 0 then
        --self:Print("Canal '" .. HIDDEN_CHANNEL .. "' non rejoint.")
        return
    end

    local fullMessage = PREFIX .. name
    SendChatMessage(fullMessage, "CHANNEL", nil, id)
    -- self:Print("→ Son envoyé : " .. fullMessage)
    self:PlaySoundByName(name)
end

function SoundBoard:PlaySoundByName(name)
    if self.muted then return end

    local path = SoundBoard_Sounds and SoundBoard_Sounds[name] or SoundBoard_Custom and SoundBoard_Custom[name]
    if path then
        PlaySoundFile(path)
        -- self:Print("Lecture locale : " .. name)
    else
        --self:Print("Son introuvable : " .. name)
    end
end

function SoundBoard:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF96SoundBoard|r: " .. msg)
end

SoundBoard:Init()
