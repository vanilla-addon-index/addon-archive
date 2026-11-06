--[[
	Load localized strings
]]

local localization_loader = getglobal("SC_Localization_"..GetLocale())
if( localization_loader ) then localization_loader()
else
	SC_Localization_enUS()
end

localization_loader = nil
