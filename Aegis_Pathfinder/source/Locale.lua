--[[ Locale.lua -- strings matched against the client's own text, and a few
	the addon shows, per client language. A string with no entry is used as
	written: L["Anything"] is "Anything".

	PART_GSUB and PART_FIND strip and read a quest's "(Part 2)" suffix, and
	COORD_MATCH finds the "(x, y)" coordinates in a step's note.
]]

local loc = GetLocale()

local english = {
	PART_GSUB = "%s%(Part %d+%)",
	PART_FIND = "(.+)%s%(Part %d+%)",
	COORD_MATCH = "%(([%d.]+),%s?([%d.]+)%)",

	["Imported your saved progress from TurtleGuide."] = "Imported your saved progress from TurtleGuide.",
	["You have been assigned the %s leveling route."] = "You have been assigned the %s leveling route.",
	["You have learned a new spell: (.*)."] = "You have learned a new spell: (.*).",
	-- Starting zone selector
	["Choose Starting Zone"] = "Choose Starting Zone",
	["Select which starting zone you want to level through:"] = "Select which starting zone you want to level through:",
	["Recommended for your race"] = "Recommended for your race",
	["Starting zone complete!"] = "Starting zone complete!",
	["Transitioning to shared leveling path..."] = "Transitioning to shared leveling path...",
	["You can change starting zones from the Options menu"] = "You can change starting zones from the Options menu",
	["Cross-race start: %s"] = "Cross-race start: %s",
}

local localized

if loc == "deDE" then localized = {
	PART_GSUB = "%s%(Teil %d+%)",
	PART_FIND = "(.+)%s%(Teil %d+%)",
	["^You .*Hitem:(%d+).*(%[.+%])"] = "^Ihr .*Hitem:(%d+).*(%[.+%])",
	["Automatically track quests"] = "Automatische Questverfolgung",
	["Automatically skip suggested follow-ups"] = "Follow-ups automatisch \195\188berspringen",
} end

if loc == "frFR" then localized = {
	PART_GSUB = "%s%(Partie %d+%)",
	PART_FIND = "(.+)%s%(Partie %d+%)",
	["^You .*Hitem:(%d+).*(%[.+%])"] = "^Vous .*Hitem:(%d+).*(%[.+%])",
	["Automatically track quests"] = "Suivi des qu\195\170tes automatique",
	["Automatically skip suggested follow-ups"] = "Sauter automatiquement les follow-ups sugg\195\169r\195\169s",
} end

if loc == "ruRU" then localized = {
	PART_GSUB = "%s%(\208\167\208\176\209\129\209\130\209\140 %d+%)",
	PART_FIND = "(.+)%s%(\208\167\208\176\209\129\209\130\209\140 %d+%)",
	["^You .*Hitem:(%d+).*(%[.+%])"] = "^\208\146\208\176\209\136\208\176 .*H\208\180\208\190\208\177\209\139\209\135\208\176:(%d+).*(%[.+%])",
} end

-- The client's language falls back to English, and English to the string
-- asked for, so a lookup always answers.
AEGISPATHFINDER_LOCALE = localized and setmetatable(localized, { __index = function(_, k) return english[k] or k end })
	or setmetatable(english, { __index = function(_, k) return k end })
