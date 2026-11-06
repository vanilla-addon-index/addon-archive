local frame = CreateFrame("Frame")
-- String you are looking for in combat log
local skill = "Your Execute "
-- String length
local length = strlen(skill)

-- Event handler function, when the event is fired this function checks if the start of arg1 from "CHAT_MSG_SPELL_SELF_DAMAGE" matches the local skill string and plays the GLANG sound if it returns true
local function OnEvent()
    if strsub(arg1, 1, length) == skill then
        PlaySoundFile("Interface\\Addons\\ES\\Sounds\\FireShield.ogg", "SFX")
		return
	end

end

-- Register the event you want to track which in this case is "CHAT_MSG_SPELL_SELF_DAMAGE", because it fires every time the player hits an ability
frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")

-- Attach the event handler to the frame
frame:SetScript("OnEvent", OnEvent)
