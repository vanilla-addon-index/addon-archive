if not StrategosBattleground_Localizations then
    StrategosBattleground_Localizations = {}
end
if not StrategosBattleground_ServerLocalizations then
    StrategosBattleground_ServerLocalizations = {}
end
if not StrategosBattleground_ClientLocalizations then
    StrategosBattleground_ClientLocalizations = {}
end

-- ↑ABOVE LINES HAVE TO BE INCLUDED AT THE BEGINNING OF EACH LOCALIZATION FILES↑
-- ADDING A NEW LOCALIZATION:
-- To add a new localization create a new file using this as a model, just replace `enUS`
-- with your language in `StrategosBattleground_Localizations.enUS` (e.g. `StrategosBattleground_Localizations.itIT`) and change
-- and replace the strings having care of leaving words followed by a `%` as they are
-- (e.g. `ARATHI_BOARD_WINNING_FACTION = "Horde wins in: %time"` ->
--       `ARATHI_BOARD_WINNING_FACTION = "L'Orda vincerà in: %time"`)
-- Remember to add the name of your file at the end of the .toc file.

StrategosBattleground_Localizations.enUS = {
    WARSONG_FLAG_GROUND = "GROUND",
    ARATHI_BOARD_STALL = "Stalling",
    ARATHI_BOARD_WIN_FACTION0 = "Horde wins!",
    ARATHI_BOARD_WIN_FACTION1 = "Alliance wins!",
    ARATHI_BOARD_WINNING_FACTION0 = "Horde wins in: %time",
    ARATHI_BOARD_WINNING_FACTION1 = "Alliance wins in: %time",
    BG_START_IN_UI = "[BG] Starting in",
    SETTINGS_TITLE = "Strategos Battleground Settings",
    SETTINGS_SERVER_LANGUAGE = "Server Language",
    SETTINGS_GENERAL_SECTION = "General",
    SETTINGS_AUTO_JOIN = "Auto queue",
    SETTINGS_AUTO_JOIN_GROUP = "Auto queue as group",
    SETTINGS_WSG_SECTION = "Warsong Gulch",
    SETTINGS_WSG_CARRIERS_SIDE = "Side of flag carrier frame:",
    SETTINGS_WSG_CARRIERS_SIDE_LEFT = "Left",
    SETTINGS_WSG_CARRIERS_SIDE_RIGHT = "Right",
    SETTINGS_WSG_CARRIERS_HEALTH_STYLE = "Flag carrier's health style:",
    SETTINGS_WSG_CARRIERS_HEALTH_STYLE_COLOR = "Color",
    SETTINGS_WSG_CARRIERS_HEALTH_STYLE_BAR = "Bar",
    SETTINGS_WSG_CARRIERS_HEALTH_WARNS = "Flag carriers low health warnings:",
    SETTINGS_WSG_CARRIERS_HEALTH_WARNS_ENABLED = "ON",
    SETTINGS_WSG_CARRIERS_HEALTH_WARNS_DISABLED = "OFF",
    SETTINGS_WSG_CARRIERS_HEALTH_WARNS_NO_LINK = "Use player links (colored text)",
}

StrategosBattleground_ServerLocalizations.enUS = {
    ALLIANCE = "Alliance",
    HORDE = "Horde",
    AALLIANCE = "[Aa]lliance",
    HHORDE = "[Hh]orde",
    BG_START_IN_CHAT = "Starting in: %time",
    WARSONG_GULCH_START_1M = "Warsong Gulch.- 1 minute",
    WARSONG_GULCH_START_30S = "Warsong Gulch.- 30 seconds",
    WARSONG_GULCH_STARTED = "^Let the.-Warsong Gulch.- beg[iu]n",
    WARSONG_GULCH_FLAG_PICKED_UP = "picked",
    WARSONG_GULCH_FLAG_PICKED_BY = "by (.*)!",
    WARSONG_GULCH_FLAG_DROPPED = "dropped",
    WARSONG_GULCH_FLAG_RETURNED = "returned",
    WARSONG_GULCH_FLAG_CAPTURED = "captured",
    WARSONG_GULCH_FLAG_RESET = "placed",
    WARSONG_LOWHEALTH_CHAT_WARN0 = "\124cffff0000\124Hplayer:%pname\124h[Horde Flag Carrier]\124h\124r is below %health% Health!",
    WARSONG_LOWHEALTH_CHAT_WARN1 = "\124cff00b0ff\124Hplayer:%pname\124h[Alliance Flag Carrier]\124h\124r is below %health% Health!",
    WARSONG_LOWHEALTH_CHAT_WARN0_ALT = "HORDE Flag Carrier is below %health% Health!",
    WARSONG_LOWHEALTH_CHAT_WARN1_ALT = "ALLIANCE Flag Carrier is below %health% Health!",
    ALTERAC_VALLEY_START_1M = "1 minute.-Alterac Valley",
    ALTERAC_VALLEY_START_30S = "30 seconds.-Alterac Valley",
    ALTERAC_VALLEY_STARTED = "Alterac Valley.- has begun",
    ALTERAC_VALLEY_UNDER_ATTACK = "The (.*) is under attack",
    ALTERAC_VALLEY_TAKEN = "The (.*) was taken by",
    ALTERAC_VALLEY_DESTROYED = "^(.*) was destroyed by",
    ARATHI_BOARD_WINNING_FACTION0 = "Horde wins in: %time",
    ARATHI_BOARD_WINNING_FACTION1 = "Alliance wins in: %time",
    ARATHI_BASIN_BLACKSMITH_LABEL = "Blacksmith",
    ARATHI_BASIN_FARM_LABEL = "Farm",
    ARATHI_BASIN_STABLES_LABEL = "Stables",
    ARATHI_BASIN_GOLD_MINE_LABEL = "Gold Mine",
    ARATHI_BASIN_LUMBER_MILL_LABEL = "Lumber Mill",
    ARATHI_BASIN_BLACKSMITH = "blacksmith",
    ARATHI_BASIN_FARM = "farm",
    ARATHI_BASIN_STABLES = "stables",
    ARATHI_BASIN_GOLD_MINE = "mine",
    ARATHI_BASIN_LUMBER_MILL = "lumber mill",
    ARATHI_BASIN_START_1M = "Arathi Basin.- 1 minute",
    ARATHI_BASIN_START_30S = "Arathi Basin.- 30 seconds",
    ARATHI_BASIN_STARTED = "Arathi Basin.- has begun",
    ARATHI_BASIN_CLAIMS = "claims the",
    ARATHI_BASIN_ASSAULTED = "assaulted the",
    ARATHI_BASIN_TAKEN = "taken the",
    ARATHI_BASIN_DEFENDED = "defended the",
    ARATHI_BASIN_CLAIMS_CAP = "claims the ([%w%s]+)",
    ARATHI_BASIN_ASSAULTED_CAP = "assaulted the ([%w%s]+)",
    ARATHI_BASIN_TAKEN_CAP = "taken the ([%w%s]+)",
    ARATHI_BASIN_DEFENDED_CAP = "defended the ([%w%s]+)",
}

StrategosBattleground_ClientLocalizations.enUS = {
    SILVERWING_FLAG = "Silverwing Flag",
    WARSONG_FLAG = "Warsong Flag",
    WARSONG_GULCH = "Warsong Gulch",
    DRUID = "Druid",
    HUNTER = "Hunter",
    MAGE = "Mage",
    PALADIN = "Paladin",
    PRIEST = "Priest",
    ROGUE = "Rogue",
    SHAMAN = "Shaman",
    WARLOCK = "Warlock",
    WARRIOR = "Warrior",
    ALTERAC_VALLEY = "Alterac Valley",
    ALTERAC_VALLEY_ALLIANCE_CONTROLLED = "Alliance Controlled",
    ALTERAC_VALLEY_HORDE_CONTROLLED = "Horde Controlled",
    ALTERAC_VALLEY_IN_CONFLICT = "In Conflict",
    ALTERAC_VALLEY_TOWER = "Tower",
    ALTERAC_VALLEY_BUNKER = "Bunker",
    ARATHI_BASIN = "Arathi Basin",
    ALTERAC_VALLEY_WEST_FROSTWOLF_TOWER = "West Frostwolf Tower",
    ALTERAC_VALLEY_EAST_FROSTWOLF_TOWER = "East Frostwolf Tower",
    ALTERAC_VALLEY_ICEBLOOD_TOWER = "Iceblood Tower",
    ALTERAC_VALLEY_TOWER_POINT = "Tower Point",
    ALTERAC_VALLEY_ICEBLOOD_GRAVEYARD = "Iceblood Graveyard",
    ALTERAC_VALLEY_FROSTWOLF_GRAVEYARD = "Frostwolf Graveyard",
    ALTERAC_VALLEY_FROSTWOLF_RELIEF_HUT = "Frostwolf Relief Hut",
    ALTERAC_VALLEY_DUN_BALDAR_NORTH_BUNKER = "Dun Baldar North Bunker",
    ALTERAC_VALLEY_DUN_BALDAR_SOUTH_BUNKER = "Dun Baldar South Bunker",
    ALTERAC_VALLEY_ICEWING_BUNKER = "Icewing Bunker",
    ALTERAC_VALLEY_STONEHEARTH_BUNKER = "Stonehearth Bunker",
    ALTERAC_VALLEY_STORMPIKE_AID_STATION = "Stormpike Aid Station",
    ALTERAC_VALLEY_STORMPIKE_GRAVEYARD = "Stormpike Graveyard",
    ALTERAC_VALLEY_STONEHEARTH_GRAVEYARD = "Stonehearth Graveyard",
    ALTERAC_VALLEY_SNOWFALL_GRAVEYARD = "Snowfall Graveyard",
    ARATHI_BASIN_BLACKSMITH_ZONE = "Blacksmith",
    ARATHI_BASIN_FARM_ZONE = "Farm",
    ARATHI_BASIN_STABLES_ZONE = "Stables",
    ARATHI_BASIN_GOLD_MINE_ZONE = "Gold Mine",
    ARATHI_BASIN_LUMBER_MILL_ZONE = "Lumber Mill",
}
