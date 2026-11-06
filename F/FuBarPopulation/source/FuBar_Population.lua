FuBar_Population = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceConsole-2.0", "AceDB-2.0", "FuBarPlugin-2.0")
FuBar_Population.hasIcon = 'icon'
FuBar_Population.cannotHideText = true
FuBar_Population.cannotDetachTooltip = true
FuBar_Population.hasNoColor = true
FuBar_Population.clickableTooltip = true
FuBar_Population.folderName = "FuBar_Population"
FuBar_Population:RegisterDB("FuBar_PopulationDB")

local tablet = AceLibrary("Tablet-2.0")

local playersOnline, maxOnline
local Locale, L = GetLocale()
local L

if Locale == 'deDE' then
    L = {
        ['Maximum online'] = 'Maximal online'
    }
elseif Locale == 'frFR' then
    L = {
        ['Maximum online'] = 'Maximum en ligne'
    }
elseif Locale == 'esES' then
    L = {
        ['Maximum online'] = 'Máximo en línea'
    }
elseif Locale == 'ruRU' then
    L = {
        ['Maximum online'] = 'Максимум в игре'
    }
elseif Locale == 'zhCN' then
    L = {
        ['Maximum online'] = '最大在线'
    }
else
    L = {
        ['Maximum online'] = 'Maximum online'
    }
end

function Population_ChatFrame_OnEvent(event)
    -- Ensure that we don't accidently omit other chat messages
    if event == "CHAT_MSG_SYSTEM" and string.find(arg1, "Players online") then
		_, _, playersOnline, maxOnline = string.find(arg1, "(%d+).+ (%d+)")
    else
        OrigChatFrame_OnEvent(event)
    end
end

function FuBar_Population:OnInitialize()
    OrigChatFrame_OnEvent 	= ChatFrame_OnEvent
    ChatFrame_OnEvent 		= Population_ChatFrame_OnEvent

    self:SetText("Updating...")
end

function FuBar_Population:OnEnable()
    self:RegisterEvent("CHAT_MSG_SYSTEM")
    self:ScheduleRepeatingEvent("ScheduledWhoTimer", GetPlayersOnline, 30)
	
    GetPlayersOnline()
end

function GetPlayersOnline()
	if UnitIsDeadOrGhost("player") then
		return
	end
	
	SendChatMessage(".server info")
end

function FuBar_Population:CHAT_MSG_SYSTEM(arg1)
	self:SetText(playersOnline or "")
end

function FuBar_Population:OnDisable()

end

function FuBar_Population:OnClick()
    self:SetText("Updating...")
    GetPlayersOnline()
end

function FuBar_Population:OnTooltipUpdate()
	local cat = tablet:AddCategory(
		"columns", 2,
		"child_textR", 0, 
		"child_textG", 1,
		"child_textB", 0,
		"showWithoutChildren", false
	)

	cat:AddLine("text", L['Maximum online'] .. ':', "text2", maxOnline)
end
