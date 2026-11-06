local U = PandaUI

U.TalentAdvisorBuilds = {
  schemaVersion = 3,
  clientBuild = 5875,
  talentRevision = "OctoWoW-Turtle-1.18",
  contexts = { "LEVELING", "PVP", "RAID" },
  classRoles = {
    WARRIOR = { "DPS", "TANK" },
    DRUID = { "DPS", "TANK", "HEALER", "HYBRID" },
    HUNTER = { "DPS" },
    MAGE = { "DPS" },
    PALADIN = { "DPS", "TANK", "HEALER", "HYBRID" },
    PRIEST = { "DPS", "HEALER" },
    ROGUE = { "DPS" },
    SHAMAN = { "DPS", "HEALER", "HYBRID" },
    WARLOCK = { "DPS" },
  },
  trees = {
    WARRIOR = { { "WarriorArms", 18 }, { "WarriorFury", 17 }, { "WarriorProtection", 19 } },
    DRUID = { { "DruidBalance", 20 }, { "DruidFeralCombat", 18 }, { "DruidRestoration", 16 } },
    HUNTER = { { "HunterBeastMastery", 19 }, { "HunterMarksmanship", 16 }, { "HunterSurvival", 20 } },
    MAGE = { { "MageArcane", 19 }, { "MageFire", 17 }, { "MageFrost", 19 } },
    PALADIN = { { "PaladinHoly", 17 }, { "PaladinProtection", 16 }, { "PaladinCombat", 16 } },
    PRIEST = { { "PriestDiscipline", 18 }, { "PriestHoly", 17 }, { "PriestShadow", 17 } },
    ROGUE = { { "RogueAssassination", 18 }, { "RogueCombat", 18 }, { "RogueSubtlety", 20 } },
    SHAMAN = { { "ShamanElementalCombat", 17 }, { "ShamanEnhancement", 16 }, { "ShamanRestoration", 16 } },
    WARLOCK = { { "WarlockCurses", 18 }, { "WarlockSummoning", 18 }, { "WarlockDestruction", 16 } },
  },
  builds = {
    WARRIOR = {
      ARMS = { label = "TA_BUILD_ARMS", split = "31/20/0", primary = 1, codes = { "032050113322130221", "05051305000000000", "0000000000000000000" } },
      FURY = { label = "TA_BUILD_FURY", split = "20/31/0", primary = 2, codes = { "302050113320000000", "05501130503110501", "0000000000000000000" } },
      PROTECTION = { label = "TA_BUILD_PROTECTION", split = "5/15/31", primary = 3, codes = { "302000000000000000", "05051300000000000", "2300510222033110231" } },
    },
    DRUID = {
      FERAL = { label = "TA_BUILD_FERAL", split = "0/31/20", primary = 2, codes = { "00000000000000000000", "503200113032021521", "5050013150000000" } },
      HOTW = { label = "TA_BUILD_HOTW_NS", split = "0/31/20", primary = 2, codes = { "00000000000000000000", "503200113032021521", "5050013150000000" } },
      BALANCE = { label = "TA_BUILD_BALANCE_NS", split = "31/0/20", primary = 1, codes = { "50003200302503101321", "000000000000000000", "5050013150000000" } },
      MOONGLOW = { label = "TA_BUILD_MOONGLOW", split = "20/0/31", primary = 3, codes = { "50003200302500000000", "000000000000000000", "5050013150212501" } },
      RESTORATION = { label = "TA_BUILD_RESTORATION", split = "20/0/31", primary = 3, codes = { "50003200302500000000", "000000000000000000", "5050013150212501" } },
    },
    HUNTER = {
      BEAST_MASTERY = { label = "TA_BUILD_BEAST_MASTERY", split = "31/20/0", primary = 1, codes = { "5003202120053112211", "0505212050000000", "00000000000000000000" } },
      MARKSMAN = { label = "TA_BUILD_MARKSMAN", split = "20/31/0", primary = 2, codes = { "5003202120050000000", "0505212051121231", "00000000000000000000" } },
      MARKSMAN_PVP = { label = "TA_BUILD_MARKSMAN_SURVIVAL", split = "0/31/20", primary = 2, codes = { "0000000000000000000", "0505212051121231", "05032002201032000000" } },
    },
    MAGE = {
      FROST = { label = "TA_BUILD_FROST", split = "20/0/31", primary = 3, codes = { "2300051310230000000", "00000000000000000", "0503020410230113321" } },
      POM_FIRE = { label = "TA_BUILD_POM_FIRE", split = "20/31/0", primary = 2, codes = { "2300051310230000000", "50500201230213151", "0000000000000000000" } },
      AP_FROST = { label = "TA_BUILD_AP_FROST", split = "31/0/20", primary = 1, codes = { "2300051310230211151", "00000000000000000", "0503020410230000000" } },
      WINTERS_CHILL = { label = "TA_BUILD_WINTERS_CHILL", split = "20/0/31", primary = 3, codes = { "2300051310230000000", "00000000000000000", "0503020410230113321" } },
      FIRE = { label = "TA_BUILD_FIRE", split = "20/31/0", primary = 2, codes = { "2300051310230000000", "50500201230213151", "0000000000000000000" } },
    },
    PALADIN = {
      RETRIBUTION = { label = "TA_BUILD_RETRIBUTION", split = "20/0/31", primary = 3, codes = { "05320311005000000", "0000000000000000", "0523023003205051" } },
      HOLY_PVP = { label = "TA_BUILD_HOLY_PVP", split = "31/20/0", primary = 1, codes = { "05320311032041321", "5030231012300000", "0000000000000000" } },
      HOLY = { label = "TA_BUILD_HOLY", split = "31/20/0", primary = 1, codes = { "05320311032041321", "5030231012300000", "0000000000000000" } },
      PROTECTION = { label = "TA_BUILD_PROTECTION", split = "0/31/20", primary = 2, codes = { "00000000000000000", "0530231102331151", "0523023003200000" } },
      HOLY_RETRIBUTION = { label = "TA_BUILD_HOLY_RETRIBUTION", split = "31/0/20", primary = 1, codes = { "05320311032041321", "0000000000000000", "0523023003200000" } },
    },
    PRIEST = {
      SHADOW_LEVELING = { label = "TA_BUILD_SHADOW_LEVELING", split = "20/0/31", primary = 3, codes = { "203050001313200000", "00000000000000000", "50123022100511251" }, sequence = { "1:1", "3:1", "1:1", "3:1", "3:1", "3:1", "3:1" } },
      SHADOW = { label = "TA_BUILD_SHADOW", split = "20/0/31", primary = 3, codes = { "203050001313200000", "00000000000000000", "50123022100511251" } },
      HOLY = { label = "TA_BUILD_HOLY", split = "20/31/0", primary = 2, codes = { "203050001313200000", "32050013123011351", "00000000000000000" } },
      DISCIPLINE = { label = "TA_BUILD_DISCIPLINE", split = "31/20/0", primary = 1, codes = { "005050001313231151", "32050013123000000", "00000000000000000" } },
    },
    ROGUE = {
      COMBAT_LEVELING = { label = "TA_BUILD_COMBAT_SWORDS", split = "20/31/0", primary = 2, codes = { "005320104230000000", "050050230050122231", "00000000000000000000" } },
      HEMORRHAGE = { label = "TA_BUILD_HEMORRHAGE", split = "20/0/31", primary = 3, codes = { "005320104230000000", "000000000000000000", "50032030112032111231" } },
      COMBAT_SWORDS = { label = "TA_BUILD_COMBAT_SWORDS", split = "20/31/0", primary = 2, codes = { "005320104230000000", "050050230050122231", "00000000000000000000" } },
      COMBAT_DAGGERS = { label = "TA_BUILD_COMBAT_DAGGERS", split = "20/31/0", primary = 2, codes = { "005320104230000000", "500350230052102201", "00000000000000000000" } },
    },
    SHAMAN = {
      ENHANCEMENT = { label = "TA_BUILD_ENHANCEMENT", split = "0/31/20", primary = 2, codes = { "00000000000000000", "5005002035013151", "0503232005000000" } },
      ELEMENTAL = { label = "TA_BUILD_ELEMENTAL_NS", split = "31/0/20", primary = 1, codes = { "50032105020221251", "0000000000000000", "0503232005000000" } },
      RESTORATION = { label = "TA_BUILD_RESTORATION", split = "0/20/31", primary = 3, codes = { "00000000000000000", "5005002035000000", "0503232115021051" } },
      ENH_RESTO = { label = "TA_BUILD_ENH_RESTO", split = "0/20/31", primary = 3, codes = { "00000000000000000", "5005002035000000", "0503232115021051" } },
    },
    WARLOCK = {
      AFFLICTION = { label = "TA_BUILD_AFFLICTION", split = "31/20/0", primary = 1, codes = { "050320320222210151", "050230140221000000", "0000000000000000" } },
      SOUL_LINK = { label = "TA_BUILD_SOUL_LINK", split = "20/31/0", primary = 2, codes = { "050320320221000000", "050230140221113501", "0000000000000000" } },
      DS_RUIN = { label = "TA_BUILD_DS_RUIN", split = "20/0/31", primary = 3, codes = { "050320320221000000", "000000000000000000", "5005021522025121" } },
      SM_RUIN = { label = "TA_BUILD_SM_RUIN", split = "31/20/0", primary = 1, codes = { "050320320222210151", "050230140221000000", "0000000000000000" } },
    },
  },
  catalog = {
    WARRIOR = {
      LEVELING = { DPS = { "ARMS" }, TANK = { "ARMS" } },
      PVP = { DPS = { "ARMS" }, TANK = { "PROTECTION", "ARMS" } },
      RAID = { DPS = { "FURY", "ARMS" }, TANK = { "PROTECTION" } },
    },
    DRUID = {
      LEVELING = { DPS = { "FERAL", "BALANCE" }, TANK = { "FERAL" }, HEALER = { "HOTW", "MOONGLOW" }, HYBRID = { "HOTW" } },
      PVP = { DPS = { "HOTW", "BALANCE" }, TANK = { "HOTW" }, HEALER = { "HOTW", "MOONGLOW" }, HYBRID = { "HOTW", "BALANCE" } },
      RAID = { DPS = { "FERAL", "BALANCE" }, TANK = { "FERAL" }, HEALER = { "RESTORATION", "MOONGLOW" }, HYBRID = { "MOONGLOW", "HOTW" } },
    },
    HUNTER = {
      LEVELING = { DPS = { "BEAST_MASTERY" } },
      PVP = { DPS = { "MARKSMAN_PVP", "BEAST_MASTERY" } },
      RAID = { DPS = { "MARKSMAN", "MARKSMAN_PVP" } },
    },
    MAGE = {
      LEVELING = { DPS = { "FROST", "POM_FIRE" } },
      PVP = { DPS = { "FROST", "POM_FIRE", "AP_FROST" } },
      RAID = { DPS = { "WINTERS_CHILL", "FROST", "FIRE" } },
    },
    PALADIN = {
      LEVELING = { DPS = { "RETRIBUTION" }, TANK = { "PROTECTION", "RETRIBUTION" }, HEALER = { "HOLY_RETRIBUTION", "HOLY" }, HYBRID = { "HOLY_RETRIBUTION", "RETRIBUTION" } },
      PVP = { DPS = { "RETRIBUTION" }, TANK = { "PROTECTION", "HOLY_PVP" }, HEALER = { "HOLY_PVP" }, HYBRID = { "HOLY_RETRIBUTION", "HOLY_PVP" } },
      RAID = { DPS = { "RETRIBUTION" }, TANK = { "PROTECTION" }, HEALER = { "HOLY", "HOLY_RETRIBUTION" }, HYBRID = { "HOLY_RETRIBUTION", "HOLY" } },
    },
    PRIEST = {
      LEVELING = { DPS = { "SHADOW_LEVELING" }, HEALER = { "HOLY", "SHADOW_LEVELING" } },
      PVP = { DPS = { "SHADOW" }, HEALER = { "DISCIPLINE", "HOLY" } },
      RAID = { DPS = { "SHADOW" }, HEALER = { "HOLY", "DISCIPLINE" } },
    },
    ROGUE = {
      LEVELING = { DPS = { "COMBAT_LEVELING" } },
      PVP = { DPS = { "HEMORRHAGE", "COMBAT_SWORDS" } },
      RAID = { DPS = { "COMBAT_SWORDS", "COMBAT_DAGGERS" } },
    },
    SHAMAN = {
      LEVELING = { DPS = { "ENHANCEMENT", "ELEMENTAL" }, HEALER = { "ENH_RESTO", "RESTORATION" }, HYBRID = { "ENH_RESTO", "ELEMENTAL" } },
      PVP = { DPS = { "ELEMENTAL", "ENHANCEMENT" }, HEALER = { "ELEMENTAL", "RESTORATION" }, HYBRID = { "ELEMENTAL", "ENH_RESTO" } },
      RAID = { DPS = { "ELEMENTAL", "ENHANCEMENT" }, HEALER = { "RESTORATION", "ENH_RESTO" }, HYBRID = { "ENH_RESTO", "ELEMENTAL" } },
    },
    WARLOCK = {
      LEVELING = { DPS = { "AFFLICTION" } },
      PVP = { DPS = { "SOUL_LINK", "SM_RUIN" } },
      RAID = { DPS = { "DS_RUIN", "SM_RUIN" } },
    },
  },
}
