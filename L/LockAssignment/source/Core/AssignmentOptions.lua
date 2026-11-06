-- Core: Domain options and lookups (curse, banish, announcer, spell/marker assets). No frame references.
LA.BanishMarkers = {
	"None", "Diamond", "Star", "Triangle", "Circle", "Square", "Moon", "Skull", "Cross"
}

LA.CurseOptions = {
	"None", "Elements", "Shadows", "Recklessness", "Tongues", "Weakness", "Doom LOL", "Agony"
}

LA.AnnouncerOptions = {
	"Addon Only", "Raid", "Party", "Whisper"
}

LA.SSTargets = {}

if not RAID_CLASS_COLORS then
	RAID_CLASS_COLORS = {
		["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
		["MAGE"]    = { r = 0.41, g = 0.8,  b = 0.94, colorStr = "ff69ccf0" },
		["ROGUE"]   = { r = 1,    g = 0.96, b = 0.41, colorStr = "fffff569" },
		["DRUID"]   = { r = 1,    g = 0.49, b = 0.04, colorStr = "ffff7d0a" },
		["HUNTER"]  = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473" },
		["SHAMAN"]  = { r = 0.14, g = 0.35, b = 1.0,  colorStr = "ff0070de" },
		["PRIEST"]  = { r = 1,    g = 1,    b = 1,    colorStr = "ffffffff" },
		["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79, colorStr = "ff9482c9" },
		["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" },
	}
end

function LA.GetClassColor(class)
	return RAID_CLASS_COLORS[class]
end

function LA.GetClassColorStr(color)
	if not color then
		return "ffffffff"
	end
	if color.colorStr then
		return color.colorStr
	end
	if color.r and color.g and color.b then
		return string.format(
			"ff%02x%02x%02x",
			math.floor(color.r * 255 + 0.5),
			math.floor(color.g * 255 + 0.5),
			math.floor(color.b * 255 + 0.5)
		)
	end
	return "ffffffff"
end

function LA.FirstToUpper(str)
	return (string.gsub(str, "^%l", string.upper))
end

function LA.GetColoredName(player)
	if player and player.Color ~= nil then
		return "|c" .. player.Color .. player.Name .. "|r"
	end
	return player and player.Name or ""
end

function LA.GetSSTargetsFromRaid()
	local results = {}
	if LA.RaidMode then
		for i = 1, 40 do
			local name, _, _, _, _, class, _, _, _, _, _ = GetRaidRosterInfo(i)
			if not (name == nil) then
				local colorStr = LA.GetClassColorStr(LA.GetClassColor(class))
				local ssWithColor = {}
				ssWithColor.Name = name
				ssWithColor.Color = colorStr
				ssWithColor.Class = "|c" .. colorStr .. LA.FirstToUpper(string.lower(class))
				table.insert(results, ssWithColor)
			end
		end
	end
	return results
end

function LA.GetSSTargets()
	return LA.SSTargets
end

function LA.UpdateSSTargets()
	LA.SSTargets = LA.GetSSTargetsFromRaid()
end

LA.SSTargets = LA.GetSSTargetsFromRaid()

-- Spell name/id/texture and raid marker asset lookups (domain data)
function LA.GetSpellNameFromDropDownList(ListValue)
	if ListValue == "Elements" then return "Curse of the Elements"
	elseif ListValue == "Shadows" then return "Curse of Shadow"
	elseif ListValue == "Recklessness" then return "Curse of Recklessness"
	elseif ListValue == "Doom LOL" then return "Curse of Doom"
	elseif ListValue == "Agony" then return "Curse of Agony"
	elseif ListValue == "Tongues" then return "Curse of Tongues"
	elseif ListValue == "Weakness" then return "Curse of Weakness"
	end
	return nil
end

function LA.GetSpellIdFromDropDownList(ListValue)
	if ListValue == "Elements" then return 11722
	elseif ListValue == "Shadows" then return 17937
	elseif ListValue == "Recklessness" then return 11717
	elseif ListValue == "Doom LOL" then return 603
	elseif ListValue == "Agony" then return 11713
	elseif ListValue == "Tongues" then return 11719
	elseif ListValue == "Weakness" then return 11708
	end
	return nil
end

function LA.GetSpellTextureFromDropDownList(ListValue)
	local spellName = LA.GetSpellNameFromDropDownList(ListValue)
	local spellsTable = {
		["Curse of the Elements"] = "Interface\\Icons\\Spell_Shadow_ChillTouch",
		["Curse of Shadow"] = "Interface\\Icons\\Spell_Shadow_CurseOfAchimonde",
		["Curse of Recklessness"] = "Interface\\Icons\\Spell_Shadow_UnholyStrength",
		["Curse of Doom"] = "Interface\\Icons\\Spell_Shadow_AuraOfDarkness",
		["Curse of Agony"] = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
		["Curse of Tongues"] = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
		["Curse of Weakness"] = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth",
	}
	return spellName and spellsTable[spellName]
end

function LA.GetAssetLocationFromRaidMarker(raidMarker)
	if raidMarker == "Skull" then return "Interface\\Addons\\LockAssignment\\assets\\UI-RaidTargetingIcon_8"
	elseif raidMarker == "Star" then return "Interface\\Addons\\LockAssignment\\assets\\UI-RaidTargetingIcon_1"
	elseif raidMarker == "Circle" then return "Interface\\Addons\\LockAssignment\\assets\\UI-RaidTargetingIcon_2"
	elseif raidMarker == "Diamond" then return "Interface\\Addons\\LockAssignment\\assets\\UI-RaidTargetingIcon_3"
	elseif raidMarker == "Triangle" then return "Interface\\Addons\\LockAssignment\\assets\\UI-RaidTargetingIcon_4"
	elseif raidMarker == "Moon" then return "Interface\\Addons\\LockAssignment\\assets\\UI-RaidTargetingIcon_5"
	elseif raidMarker == "Square" then return "Interface\\Addons\\LockAssignment\\assets\\UI-RaidTargetingIcon_6"
	elseif raidMarker == "Cross" then return "Interface\\Addons\\LockAssignment\\assets\\UI-RaidTargetingIcon_7"
	end
	return nil
end
