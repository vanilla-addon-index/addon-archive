local Players = {}
local Mobs = {}
local Targets = {}
local Icons = {
	["Druid"] = "Interface\\AddOns\\SkelaCustomNameplates\\Class\\ClassIcon_Druid",
	["Hunter"] = "Interface\\AddOns\\SkelaCustomNameplates\\Class\\ClassIcon_Hunter",
	["Mage"] = "Interface\\AddOns\\SkelaCustomNameplates\\Class\\ClassIcon_Mage",
	["Paladin"] = "Interface\\AddOns\\SkelaCustomNameplates\\Class\\ClassIcon_Paladin",
	["Priest"] = "Interface\\AddOns\\SkelaCustomNameplates\\Class\\ClassIcon_Priest",
	["Rogue"] = "Interface\\AddOns\\SkelaCustomNameplates\\Class\\ClassIcon_Rogue",
	["Shaman"] = "Interface\\AddOns\\SkelaCustomNameplates\\Class\\ClassIcon_Shaman",
	["Warlock"] = "Interface\\AddOns\\SkelaCustomNameplates\\Class\\ClassIcon_Warlock",
	["Warrior"] = "Interface\\AddOns\\SkelaCustomNameplates\\Class\\ClassIcon_Warrior",
}

local red = "|cffff0000"
local green = "|cff1eff00"
local blue = "|cff0070dd"
local grey = "|cff9d9d9d"
local white = "|r"

function SCNInitialise()
	if SCN_Options == nil then
		SCN_Options = {}
		SCN_Options["toggle"] = true
		SCN_Options["safetarget"] = true
		SCN_Options["click"] = true
		SCN_Options["hp"] = true
		SCN_Options["fifths"] = true
		SCN_Options["pic"] = "barSmall5ths"
		SCN_Options["pvprank"] = true
		SCN_Options["guild"] = true
		SCN_Options["showPets"] = false
		SCN_Options["classification"] = true
	end
		-- ensure backward compatibility for new options
	if SCN_Options["show_friendly"] == nil then
		SCN_Options["show_friendly"] = false
		SCN_Options["name_text_size"] = 12
		SCN_Options["rank_text_size"] = 12
		SCN_Options["level_text_size"] = 11
		SCN_Options["classification_text_size"] = 12
		SCN_Options["guild_text_size_short"] = 13
		SCN_Options["guild_text_size_long"] = 10
		SCN_Options["guild_text_max_length_of_short"] = 20
	end
end

function SCNReset()
	if (SCN_Options["toggle"]) then
		ShowNameplates()
		if (SCN_Options["show_friendly"]) then
			ShowFriendNameplates()
		else
			HideFriendNameplates()
		end
	else
		HideNameplates()
		HideFriendNameplates()
	end
end


local function scn_print(t)
	DEFAULT_CHAT_FRAME:AddMessage(t)
end

local function scn_is_numeric(x)
  if tonumber(x) ~= nil then
    return true
  end
  return false
end

-------------------------------------------Slash fuctions
SLASH_CUSTOMNAMEPLATES1 = '/scn';

function SlashCmdList.CUSTOMNAMEPLATES(msg, editbox)
	local parameters = {strsplit(" ", msg, 4)}

	local function colourCurrentText(text)
		return blue .. text .. white
	end

	if parameters[1] == nil then
		local toggle = red .. "Off"
		local showfriendly = red .. "Hide"
		local safetarget = red .. "Off"
		local click = red .. "Off"
		local fifths = red .. "Hide"
		local pvprank = red .. "Hide"
		local guild = red .. "Hide"
		local classification = red .. "Hide"

		if  SCN_Options["toggle"] then
			toggle = green .. "On"
		end
		if  SCN_Options["show_friendly"] then
			showfriendly = green .. "Show"
		end
		if  SCN_Options["safetarget"] then
			safetarget = green .. "On"
		end
		if  SCN_Options["click"] then
			click = green .. "On"
		end
		if  SCN_Options["fifths"] then
			fifths = green .. "Show"
		end
		if  SCN_Options["pvprank"] then
			pvprank = green .. "Show"
		end
		if  SCN_Options["guild"] then
			guild = green .. "Show"
		end
		if  SCN_Options["classification"] then
			classification = green .. "Show"
		end

		scn_print("Skela Custom Nameplates:")
		scn_print("/scn <option>")
		scn_print("- toggle " .. grey .. "// Toggle the addon (" .. toggle .. grey .. ")")
		scn_print("- showfriendly " .. grey .. "// Toggle showing friendlies by default (" .. showfriendly .. grey .. ")")
		scn_print("- safetarget " .. grey .. "// Toggle target safe mode (" .. safetarget .. grey .. ")")
		scn_print("- click " .. grey .. "// Toggle targeting by nameplates (" .. click .. grey .. ")")
		scn_print("- fifths " .. grey .. "// Toggle lines by every 20% hp (" .. fifths .. grey .. ")")
		scn_print("- pvprank " .. grey .. "// Show pvp ranks (" .. pvprank .. grey .. ")")
		scn_print("- guild " .. grey .. "// Show guild names (" .. guild .. grey .. ")")
		scn_print("- classification " .. grey .. "// Show if the mob is elite or rare (" .. classification .. grey .. ")")
		scn_print("- change " .. grey .. "// Change font size related settings")
		return
	end
	if parameters[1] == "toggle" then
		SCN_Options["toggle"] = not SCN_Options["toggle"]
		if SCN_Options["toggle"] then
			scn_print("The addon is turned ON!")
		else
			scn_print("The addon is turned Off!")
			ReloadUI();
		end
		return
	end
	if parameters[1] == "showfriendly" then
		SCN_Options["show_friendly"] = not SCN_Options["show_friendly"]
		if SCN_Options["show_friendly"] then
			scn_print("Friendlies' nameplates are now showed by default!")
		else
			scn_print("Friendlies' nameplates are now hidden by default!")
		end
		return
	end
	if parameters[1] == "safetarget" then
		SCN_Options["safetarget"] = not SCN_Options["safetarget"]
		if SCN_Options["safetarget"] then
			scn_print("Targetsafe radar is turned ON!")
		else
			scn_print("Targetsafe radar is turned Off!")
		end
		return
	end
	if parameters[1] == "click" then
		SCN_Options["click"] = not SCN_Options["click"]
		if SCN_Options["click"] then
			scn_print("Targetting by click is ON!")
		else
			scn_print("Targetting by click is Off!")
		end
		return
	end
	if parameters[1] == "fifths" then
		SCN_Options["fifths"] = not SCN_Options["fifths"]
		if SCN_Options["fifths"] then
			SCN_Options["pic"] = "barSmall5ths"
			scn_print("Lines every at 20% HP ON!")
		else
			SCN_Options["pic"] = "barSmall"
			scn_print("Lines every at 20% HP Off!")
		end
		return
	end
	if parameters[1] == "pvprank" then
		SCN_Options["pvprank"] = not SCN_Options["pvprank"]
		if SCN_Options["pvprank"] then
			scn_print("Showing pvp ranks ON!")
		else
			scn_print("Showing pvp ranks Off!")
		end
		return
	end
	if parameters[1] == "guild" then
		SCN_Options["guild"] = not SCN_Options["guild"]
		if SCN_Options["guild"] then
			scn_print("Showing guild ON!")
		else
			scn_print("Showing guild Off!")
		end
		return
	end
	if parameters[1] == "classification" then
		SCN_Options["classification"] = not SCN_Options["classification"]
		if SCN_Options["classification"] then
			scn_print("Showing unit classification ON!")
		else
			scn_print("Showing unit classification Off!")
		end
		return
	elseif parameters[1] ~= nil and parameters[1] == "change" then
		if parameters[2] == "Name" then
			if parameters[3] == nil then
				scn_print("Change the font size of the name (Current:" .. colourCurrentText(SCN_Options["name_text_size"]) .. "; Default:12)")
				scn_print("/scn change Name <new value>")
			elseif scn_is_numeric(parameters[3]) and tonumber(parameters[3]) > 0 then
				SCN_Options["name_text_size"] = tonumber(parameters[3])
				scn_print("Font size of the name is set to " .. colourCurrentText(SCN_Options["name_text_size"]))
			else
				scn_print("Invalid parameter given: " .. parameters[3])
			end
		elseif parameters[2] == "Rank" then
			if parameters[3] == nil then
				scn_print("Change the font size of the rank (Current:" .. colourCurrentText(SCN_Options["rank_text_size"]) .. "; Default:12)")
				scn_print("/scn change Rank <new value>")
			elseif scn_is_numeric(parameters[3]) and tonumber(parameters[3]) > 0 then
				SCN_Options["rank_text_size"] = tonumber(parameters[3])
				scn_print("Font size of the rank is set to " .. colourCurrentText(SCN_Options["rank_text_size"]))
			else
				scn_print("Invalid parameter given: " .. parameters[3])
			end
		elseif parameters[2] == "Level" then
			if parameters[3] == nil then
				scn_print("Change the font size of the level (Current:" .. colourCurrentText(SCN_Options["level_text_size"]) .. "; Default:11)")
				scn_print("/scn change Level <new value>")
			elseif scn_is_numeric(parameters[3]) and tonumber(parameters[3]) > 0 then
				SCN_Options["level_text_size"] = tonumber(parameters[3])
				scn_print("Font size of the level is set to " .. colourCurrentText(SCN_Options["level_text_size"]))
			else
				scn_print("Invalid parameter given: " .. parameters[3])
			end
		elseif parameters[2] == "Classification" then
			if parameters[3] == nil then
				scn_print("Change the font size of the classification (wether the mob is elite or rare) (Current:" .. colourCurrentText(SCN_Options["classification_text_size"]) .. "; Default:12)")
				scn_print("/scn change Classification <new value>")
			elseif scn_is_numeric(parameters[3]) and tonumber(parameters[3]) > 0 then
				SCN_Options["classification_text_size"] = tonumber(parameters[3])
				scn_print("Font size of the classification is set to " .. colourCurrentText(SCN_Options["classification_text_size"]))
			else
				scn_print("Invalid parameter given: " .. parameters[3])
			end
		elseif parameters[2] == "GuildWhenShort" then
			if parameters[3] == nil then
				scn_print("Change the font size of the guildname when the guildname is short (see GuildMaxLengthOfShort) (Current:" .. colourCurrentText(SCN_Options["guild_text_size_short"]) .. "; Default:13)")
				scn_print("/scn change GuildWhenShort <new value>")
			elseif scn_is_numeric(parameters[3]) and tonumber(parameters[3]) > 0 then
				SCN_Options["guild_text_size_short"] = tonumber(parameters[3])
				scn_print("Font size of the guildname when the guildname is short is set to " .. colourCurrentText(SCN_Options["guild_text_size_short"]))
			else
				scn_print("Invalid parameter given: " .. parameters[3])
			end
		elseif parameters[2] == "GuildWhenLong" then
			if parameters[3] == nil then
				scn_print("Change the font size of the guildname when the guildname is long (see GuildMaxLengthOfShort) (Current:" .. colourCurrentText(SCN_Options["guild_text_size_long"]) .. "; Default:10)")
				scn_print("/scn change GuildWhenLong <new value>")
			elseif scn_is_numeric(parameters[3]) and tonumber(parameters[3]) > 0 then
				SCN_Options["guild_text_size_long"] = tonumber(parameters[3])
				scn_print("Font size of the guildname when the guildname is long is set to " .. colourCurrentText(SCN_Options["guild_text_size_long"]))
			else
				scn_print("Invalid parameter given: " .. parameters[3])
			end
		elseif parameters[2] == "GuildMaxLengthOfShort" then
			if parameters[3] == nil then
				scn_print("Change how many characters a guild name has to be to still classify as short (Current:" .. colourCurrentText(SCN_Options["guild_text_max_length_of_short"]) .. "; Default:20)")
				scn_print("/scn change GuildMaxLengthOfShort <new value>")
			elseif scn_is_numeric(parameters[3]) and tonumber(parameters[3]) > 0 then
				SCN_Options["guild_text_max_length_of_short"] = tonumber(parameters[3])
				scn_print("The number of characters the guild name has to be to still classify as short is set to " .. colourCurrentText(SCN_Options["guild_text_size_long"]))
			else
				scn_print("Invalid parameter given: " .. parameters[3])
			end
		else
			scn_print("Change font size related settings")
			scn_print("/scn change <option> <new value>")
			scn_print("- Name " .. grey .. "// Change the font size of the name (Current:" .. colourCurrentText(SCN_Options["name_text_size"]) .. grey .."; Default:12)")
			scn_print("- Rank " .. grey .. "// Change the font size of the rank (Current:" .. colourCurrentText(SCN_Options["rank_text_size"]) .. grey .."; Default:12)")
			scn_print("- Level " .. grey .. "// Change the font size of the level (Current:" .. colourCurrentText(SCN_Options["level_text_size"]) .. grey .."; Default:11)")
			scn_print("- Classification " .. grey .. "// Change the font size of the classification (wether the mob is elite or rare) (Current:" .. colourCurrentText(SCN_Options["classification_text_size"]) .. grey .."; Default:12)")
			scn_print("- GuildWhenShort " .. grey .. "// Change the font size of the guildname when the guildname is short (Current:" .. colourCurrentText(SCN_Options["guild_text_size_short"]) .. grey .."; Default:13)")
			scn_print("- GuildWhenLong " .. grey .. "// Change the font size of the guildname when the guildname is long (Current:" .. colourCurrentText(SCN_Options["guild_text_size_long"]) .. grey .."; Default:10)")
			scn_print("- GuildMaxLengthOfShort " .. grey .. "// Change how many characters a guild name has to be to still classify as short (Current:" .. colourCurrentText(SCN_Options["guild_text_max_length_of_short"]) .. grey .."; Default:20)")
		end
	end
end

-------------------------------------------Slash fuctions

local function fillPlayerDB(name)
	if Targets[name] == nil then
		TargetByName(name, true)
		table.insert(Targets, name)
		Targets[name] = "ok"
		if UnitIsPlayer("target") then
			table.insert(Players, name)
			local pvpname = UnitPVPName("target")
			Players[name] = {["class"] = UnitClass("target"),
							["guild"] = GetGuildInfo("target"),
							["pvprank"] =  " "..strsub(pvpname, 0, strfind(pvpname, name)-1)}
		else
			table.insert(Mobs, name)
			Mobs[name] = {["classification"] = UnitClassification("target")}
		end
	end
end

local function IsNamePlateFrame(frame)
 local overlayRegion = frame:GetRegions()
  if not overlayRegion or overlayRegion:GetObjectType() ~= "Texture" or overlayRegion:GetTexture() ~= "Interface\\Tooltips\\Nameplate-Border" then
    return false
  end
  return true
end

local function isPet(name)
	PetsRU = {"Рыжая полосатая кошка", "Серебристая полосатая кошка", "Бомбейская кошка", "Корниш-рекс",
	"Ястребиная сова", "Большая рогатая сова", "Макао", "Сенегальский попугай", "Черная королевская змейка",
	"Бурая змейка", "Багровая змейка", "Луговая собачка", "Тараканище", "Анконская курица", "Щенок ворга",
	"Паучок Дымной Паутины", "Механическая курица", "Птенец летучего хамелеона", "Зеленокрылый ара", "Гиацинтовый ара",
	"Маленький темный дракончик", "Маленький изумрудный дракончик", "Маленький багровый дракончик", "Сиамская кошка",
	"Пещерная крыса без сознания", "Механическая белка", "Крошечная ходячая бомба", "Крошка Дымок", "Механическая жаба",
	"Заяц-беляк"}
	for _, petName in pairs(PetsRU) do
		if name == petName then
			return true
		end
	end
	PetsENG = {"Orange Tabby", "Silver Tabby", "Bombay", "Cornish Rex", "Hawk Owl", "Great Horned Owl",
	"Cockatiel", "Senegal", "Black Kingsnake", "Brown Snake", "Crimson Snake", "Prairie Dog", "Cockroach",
	"Ancona Chicken", "Worg Pup", "Smolderweb Hatchling", "Mechanical Chicken", "Sprite Darter", "Green Wing Macaw",
	"Hyacinth Macaw", "Tiny Black Whelpling", "Tiny Emerald Whelpling", "Tiny Crimson Whelpling", "Siamese",
	"Unconscious Dig Rat", "Mechanical Squirrel", "Pet Bombling", "Lil' Smokey", "Lifelike Mechanical Toad", "Disgusting Oozeling"}
	for _, petName in pairs(PetsENG) do
		if name == petName then
			return true
		end
	end
	return false
end

function SCN_OnUpdate()

	if not SCN_Options["toggle"] then
		return
	end
	local frames = { WorldFrame:GetChildren() }
	for _, namePlate in ipairs(frames) do
		if IsNamePlateFrame(namePlate) then
			local HealthBar = namePlate:GetChildren()
			local Border, Glow, Name, Level = namePlate:GetRegions()
			Border:Hide()
			Glow:Hide()

--SCN_Options setup
--		local mouseEnabled = namePlate:IsMouseEnabled()
			if SCN_Options["click"] then
				namePlate:EnableMouse(true)
			else
				namePlate:EnableMouse(false)
			end
--SCN_Options setup
--namePlate
			namePlate:SetWidth(110);
			namePlate:SetHeight(50);
--namePlate
--Healthbar
			HealthBar:SetStatusBarTexture("Interface\\AddOns\\SkelaCustomNameplates\\" .. SCN_Options["pic"])
			HealthBar:ClearAllPoints()
			HealthBar:SetPoint("CENTER", namePlate, "CENTER", 0, -10)
			HealthBar:SetWidth(100)
			HealthBar:SetHeight(10)   --default was 4
			HealthBar:SetAlpha(0.85)

			if HealthBar.bg == nil then
				HealthBar.bg = HealthBar:CreateTexture(nil, "BORDER")
				HealthBar.bg:SetTexture(0,0,0,0.85)
				HealthBar.bg:ClearAllPoints()
				HealthBar.bg:SetPoint("CENTER", namePlate, "CENTER", 0, -10)
				HealthBar.bg:SetWidth(HealthBar:GetWidth() + 1.5)
				HealthBar.bg:SetHeight(HealthBar:GetHeight() + 1.5)
			end
--Healthbar
--ClassIcon
			if namePlate.classIcon == nil then
				namePlate.classIcon = namePlate:CreateTexture(nil, "BORDER")
				namePlate.classIcon:SetTexture(0,0,0,0)
				namePlate.classIcon:ClearAllPoints()
				namePlate.classIcon:SetPoint("RIGHT", Name, "LEFT", -3, -1)
				namePlate.classIcon:SetWidth(12)
				namePlate.classIcon:SetHeight(12)
			end

			if namePlate.classIconBorder == nil then
				namePlate.classIconBorder = namePlate:CreateTexture(nil, "BACKGROUND")
				namePlate.classIconBorder:SetTexture(0,0,0,0.9)
				namePlate.classIconBorder:SetPoint("CENTER", namePlate.classIcon, "CENTER", 0, 0)
				namePlate.classIconBorder:SetWidth(13.5)
				namePlate.classIconBorder:SetHeight(13.5)
			end
			namePlate.classIconBorder:Hide()
			-- namePlate.classIconBorder:SetTexture(0,0,0,0)
			namePlate.classIcon:SetTexture(0,0,0,0)
--ClassIcon
--Guild
			if namePlate.guild == nil and SCN_Options["guild"] then
				namePlate.guild = namePlate:CreateFontString(nil, "ARTWORK")
				namePlate.guild:ClearAllPoints()
				namePlate.guild:SetPoint("CENTER", HealthBar, "CENTER", 0, -10)
				namePlate.guild:SetFontObject(GameFontNormal)
				namePlate.guild:SetFont("Interface\\AddOns\\CustomNameplates\\Fonts\\Ubuntu-C.ttf", SCN_Options["guild_text_size_short"])
				namePlate.guild:SetText(".");
				namePlate.guild:Hide();
			end
			namePlate.guild:Hide();
--Guild
--PVPRank
			if namePlate.pvprank == nil and SCN_Options["pvprank"]  then
				namePlate.pvprank = namePlate:CreateFontString(nil, "ARTWORK")
				namePlate.pvprank:ClearAllPoints()
				namePlate.pvprank:SetPoint("CENTER", HealthBar, "CENTER", 0, 21)
				namePlate.pvprank:SetFontObject(GameFontNormal)
				namePlate.pvprank:SetTextColor(1,1,1,0.9)
				namePlate.pvprank:SetFont("Interface\\AddOns\\CustomNameplates\\Fonts\\Ubuntu-C.ttf", SCN_Options["rank_text_size"])
				namePlate.pvprank:SetText(".");
				namePlate.pvprank:Hide();
			end
			namePlate.pvprank:Hide();
--PVPRank
--Classification
			if namePlate.classification == nil and SCN_Options["classification"] then
				namePlate.classification = namePlate:CreateFontString(nil, "ARTWORK")
				namePlate.classification:ClearAllPoints()
				namePlate.classification:SetPoint("CENTER", HealthBar, "CENTER", 0, -10)
				namePlate.classification:SetFontObject(GameFontNormal)
				namePlate.classification:SetTextColor(1,1,1,0.9)
				namePlate.classification:SetFont("Interface\\AddOns\\CustomNameplates\\Fonts\\Ubuntu-C.ttf", SCN_Options["classification_text_size"])
				namePlate.classification:SetText(".");
				namePlate.classification:Hide();
			end
			namePlate.classification:Hide();
--Classification
--Name
			Name:SetFontObject(GameFontNormal)
			Name:SetFont("Interface\\AddOns\\CustomNameplates\\Fonts\\Ubuntu-C.ttf", SCN_Options["name_text_size"])
			Name:SetPoint("BOTTOM", namePlate, "CENTER", 0, -5)
--Name
--Level
			Level:SetFontObject(GameFontNormal)
			Level:SetFont("Interface\\AddOns\\CustomNameplates\\Fonts\\Helvetica_Neue_LT_Com_77_Bold_Condensed.ttf", SCN_Options["level_text_size"])
			Level:SetPoint("TOPLEFT", Name, "RIGHT", 2, 3.5)
--Level
--Show
			HealthBar:Show()
			Name:Show()
			Level:Show()
--Show

--Colors
			local red, green, blue, _ = Name:GetTextColor()
			-- scn_print(red.." "..green.." "..blue)
			if red > 0.99 and green == 0 and blue == 0 then
				Name:SetTextColor(1,0.4,0.2,0.85)
			elseif red > 0.99 and green > 0.81 and green < 0.82 and blue == 0 then
				Name:SetTextColor(1,1,1,0.85)
			end

			local red, green, blue, _ = HealthBar:GetStatusBarColor()
			if blue > 0.99 and red == 0 and green == 0 then
				HealthBar:SetStatusBarColor(0.2,0.6,1,0.85)
			elseif red == 0 and green > 0.99 and blue == 0 then
				HealthBar:SetStatusBarColor(0.6,1,0,0.85)
			end

			local red, green, blue, _ = Level:GetTextColor()

			if red > 0.99 and green == 0 and blue == 0 then
				Level:SetTextColor(1,0.4,0.2,0.85)
			elseif red > 0.99 and green > 0.81 and green < 0.82 and blue == 0 then
				Level:SetTextColor(1,1,1,0.85)
			end
--Colors
---------------------------------------------------------------------
			local name = Name:GetText()
--Recording target

			if SCN_Options["safetarget"] then
				if  Players[name] == nil and Mobs[name] == nil and UnitName("target") == nil and Targets[name] == nil then
					fillPlayerDB(name)
					ClearTarget()
				end
			else
				if UnitName("target") == nil then
					SCN_CurrentTarget = nil
				else
					SCN_CurrentTarget = UnitName("target")
				end

				if  Players[name] == nil and Mobs[name] == nil and Targets[name] == nil then
					fillPlayerDB(name)
				end

				if SCN_CurrentTarget == nil then
					ClearTarget()
				else
					TargetByName(SCN_CurrentTarget)
				end
			end
--Recording target
--Display Non-combat Pets
			if SCN_Options["showPets"] ~= true then
				if isPet(name) then
					HealthBar:Hide()
					Name:Hide()
					Level:Hide()
				end
			end
--Display Non-combat Pets

--Display ClassIcon
			if  Players[name] ~= nil and namePlate.classIcon:GetTexture() == "Solid Texture" and string.find(namePlate.classIcon:GetTexture(), "Interface") == nil then
				namePlate.classIcon:SetTexture(Icons[Players[name]["class"]])
				namePlate.classIcon:SetTexCoord(.078, .92, .079, .937)
				namePlate.classIcon:SetAlpha(0.9)
				namePlate.classIconBorder:Show()
			end
--Display ClassIcon

--Display Guild
			if	Players[name] ~= nil then
				if Players[name]["guild"] ~= nil and SCN_Options["guild"] then
					namePlate.guild:SetText("<"..Players[name]["guild"]..">")
					if (strlen(Players[name]["guild"]) > SCN_Options["guild_text_max_length_of_short"]) then
						namePlate.guild:SetFont("Interface\\AddOns\\CustomNameplates\\Fonts\\Ubuntu-C.ttf", SCN_Options["guild_text_size_long"])
					else
						namePlate.guild:SetFont("Interface\\AddOns\\CustomNameplates\\Fonts\\Ubuntu-C.ttf", SCN_Options["guild_text_size_short"])
					end
					namePlate.guild:Show()
				else
					namePlate.guild:Hide()
				end
			end
--Display Guild

--Display Classification
			if	Mobs[name] ~= nil and SCN_Options["classification"] then
				if Mobs[name]["classification"] ~= nil and SCN_Options["classification"] and Mobs[name]["classification"] ~= "normal" then
					namePlate.classification:SetText("<"..Mobs[name]["classification"]..">")
					namePlate.classification:Show()
				else
					namePlate.classification:Hide()
				end
			end
--Display Classification

--Display PVPRank
			if	Players[name] ~= nil then
				if Players[name]["pvprank"] ~= nil and SCN_Options["pvprank"] then
					namePlate.pvprank:SetText(Players[name]["pvprank"])
					namePlate.pvprank:Show()
				else
					namePlate.pvprank:Hide()
				end
			end
--Display PVPRank
		end
	end
end

--Event handling

local f = CreateFrame("frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	SCNInitialise()
	SCNReset()
end)
f:SetScript("OnUpdate", SCN_OnUpdate)
