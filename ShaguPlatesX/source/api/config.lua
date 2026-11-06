-- load ShaguPlates environment
setfenv(1, ShaguPlatesX:GetEnvironment())

function ShaguPlatesX:UpdateConfig(group, subgroup, entry, value)
  -- create empty config if not existing
  if not ShaguPlatesX_config then
    _G.ShaguPlatesX_config = {}
  end

  -- check for missing config groups
  if not ShaguPlatesX_config[group] then
    ShaguPlatesX_config[group] = {}
  end

  -- update config
  if not subgroup and entry and value and not ShaguPlatesX_config[group][entry] then
    ShaguPlatesX_config[group][entry] = value
  end

  -- check for missing config subgroups
  if subgroup and not ShaguPlatesX_config[group][subgroup] then
    ShaguPlatesX_config[group][subgroup] = {}
  end

  -- update config in subgroup
  if subgroup and entry and value and not ShaguPlatesX_config[group][subgroup][entry] then
    ShaguPlatesX_config[group][subgroup][entry] = value
  end
end

function ShaguPlatesX:LoadConfig()
  --                MODULE        SUBGROUP       ENTRY               VALUE
  ShaguPlatesX:UpdateConfig("global",     nil,           "language",         GetLocale())
  ShaguPlatesX:UpdateConfig("global",     nil,           "profile",          "default")
  ShaguPlatesX:UpdateConfig("global",     nil,           "pixelperfect",     "0")
  ShaguPlatesX:UpdateConfig("global",     nil,           "offscreen",        "0")

  ShaguPlatesX:UpdateConfig("global",     nil,           "font_blizzard",    "0")
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_default", "Fonts\\FRIZQT__.TTF")
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_size",        "12")
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_unit", "Fonts\\FRIZQT__.TTF")
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_unit_size",   "12")
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_unit_style",  "OUTLINE")
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_unit_name",   ShaguPlatesX.path.."\\fonts\\Myriad-Pro.ttf")
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_combat",      ShaguPlatesX.path.."\\fonts\\Continuum.ttf")

  ShaguPlatesX:UpdateConfig("global",     nil,           "force_region",     "1")
  ShaguPlatesX:UpdateConfig("global",     nil,           "errors",           "1")
  ShaguPlatesX:UpdateConfig("global",     nil,           "twentyfour",       "1")
  ShaguPlatesX:UpdateConfig("global",     nil,           "servertime",       "0")
  ShaguPlatesX:UpdateConfig("global",     nil,           "override_shagutweaks_nameplates", "1")
  ShaguPlatesX:UpdateConfig("global",     nil,           "override_shagutweaks_targetlibs", "1")
  ShaguPlatesX:UpdateConfig("global",     nil,           "override_superapi_castlib", "1")

  ShaguPlatesX:UpdateConfig("gui",        nil,           "reloadmarker",     "0")
  ShaguPlatesX:UpdateConfig("gui",        nil,           "showdisabled",     "0")

  ShaguPlatesX:UpdateConfig("unitframes", nil,           "pastel",           "1")
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "manacolor",        ".5,.5,1,1")
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "animation_speed",  "5")
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "druidmanabar",     "1")
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "druidmanaheight",  "2")
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "druidmanatext",    "0")
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "abbrevnum",        "1")
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "abbrevname",       "1")

  ShaguPlatesX:UpdateConfig("chat",       "text",        "bracket",          "[]")

  ShaguPlatesX:UpdateConfig("appearance", "border",      "background",       "0,0,0,1")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "color",            "0.2,0.2,0.2,1")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "shadow",           "0")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "shadow_intensity", ".35")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "pixelperfect",     "1")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "force_blizz", "1")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "hidpi",            "1")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "default",          "3")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "nameplates",       "2")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "actionbars",       "-1")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "unitframes",       "-1")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "panels",           "-1")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "chat",             "-1")
  ShaguPlatesX:UpdateConfig("appearance", "border",      "bags",             "-1")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "lowcolor",         "1,.2,.2,1")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "normalcolor",      "1,1,1,1")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "minutecolor",      ".2,1,1,1")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "hourcolor",        ".2,.5,1,1")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "daycolor",         ".2,.2,1,1")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "threshold",        "2")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "font_size",        "12")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "font_size_blizz",  "12")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "font_size_foreign","12")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "debuffs",          "1")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "blizzard",         "0")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "foreign",          "0")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "milliseconds",     "1")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "hideanim",         "0")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "font",             ShaguPlatesX.path.."\\fonts\\BigNoodleTitling.ttf")
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "dynamicsize",      "1")
  ShaguPlatesX:UpdateConfig("appearance", "castbar",     "texture",          ShaguPlatesX.path.."\\img\\bar")
  ShaguPlatesX:UpdateConfig("appearance", "infight",     "screen",           "0")
  ShaguPlatesX:UpdateConfig("appearance", "infight",     "aggro",            "0")
  ShaguPlatesX:UpdateConfig("appearance", "infight",     "health",           "1")
  ShaguPlatesX:UpdateConfig("appearance", "infight",     "intensity",           "16")
  ShaguPlatesX:UpdateConfig("appearance", "bags",        "movable",          "0")
  ShaguPlatesX:UpdateConfig("appearance", "bags",        "icon_size",        "-1")
  ShaguPlatesX:UpdateConfig("appearance", "minimap",     "size",            "140")
  ShaguPlatesX:UpdateConfig("appearance", "minimap",     "coordsloc",        "bottomleft")

  ShaguPlatesX:UpdateConfig("tooltip",     nil,          "font_tooltip",     ShaguPlatesX.path.."\\fonts\\Myriad-Pro.ttf")

  ShaguPlatesX:UpdateConfig("bars",       "bar1",        "enable",           "1")
  ShaguPlatesX:UpdateConfig("bars",       "bar3",        "enable",           "1")
  ShaguPlatesX:UpdateConfig("bars",       "bar4",        "enable",           "1")
  ShaguPlatesX:UpdateConfig("bars",       "bar5",        "enable",           "1")
  ShaguPlatesX:UpdateConfig("bars",       "bar6",        "enable",           "1")
  ShaguPlatesX:UpdateConfig("bars",       "bar11",       "enable",           "1")
  ShaguPlatesX:UpdateConfig("bars",       "bar12",       "enable",           "1")

  ShaguPlatesX:UpdateConfig("bars",       "bar3",        "formfactor",       "6 x 2")
  ShaguPlatesX:UpdateConfig("bars",       "bar5",        "formfactor",       "6 x 2")
  ShaguPlatesX:UpdateConfig("bars",       "bar4",        "formfactor",       "1 x 12")
  ShaguPlatesX:UpdateConfig("bars",       "bar11",       "formfactor",       "10 x 1")
  ShaguPlatesX:UpdateConfig("bars",       "bar12",       "formfactor",       "10 x 1")

  ShaguPlatesX:UpdateConfig("bars",       "bar11",       "icon_size",        "18")
  ShaguPlatesX:UpdateConfig("bars",       "bar12",       "icon_size",        "18")

  for i=1,12 do
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "enable",           "0")
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "icon_size",        "20")
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "spacing",          "1")
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "formfactor",       "12 x 1")
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "background",       "1")
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "autohide",         "0")
    if i ~= 11 and i ~= 12 then
      ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "buttons",           "12")
    end
  end

  ShaguPlatesX:UpdateConfig("bars",       nil,           "animation",        "zoomfade")
  ShaguPlatesX:UpdateConfig("bars",       nil,           "nacolor",          ".3,.3,.3,1")

  ShaguPlatesX:UpdateConfig("bars",       nil,           "font",             ShaguPlatesX.path.."\\fonts\\BigNoodleTitling.ttf")

  ShaguPlatesX:UpdateConfig("bars",       "gryphons",    "texture",          "None")
  ShaguPlatesX:UpdateConfig("bars",       "gryphons",    "color",            ".6,.6,.6,1")
  ShaguPlatesX:UpdateConfig("bars",       "gryphons",    "size",             "64")

  ShaguPlatesX:UpdateConfig("totems",     nil,           "direction",        "HORIZONTAL")
  ShaguPlatesX:UpdateConfig("totems",     nil,           "iconsize",         "26")
  ShaguPlatesX:UpdateConfig("totems",     nil,           "spacing",          "3")

  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showhostile",      "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showfriendly",     "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "use_unitfonts", "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "legacy",           "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "overlap",          "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "verticalhealth",   "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "vertical_offset",  "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "scale",            "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "nameoffset",       "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showcastbar",      "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targetcastbar",    "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "spellname",        "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showdebuffs",      "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "selfdebuff",       "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "guessdebuffs",     "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "clickthrough",     "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "rightclick",       "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "clickthreshold",   "0.5")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "enemyclassc",      "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "friendclassc",     "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "friendclassnamec", "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "raidiconsize",     "16")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "raidiconpos",      "CENTER")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "raidiconoffx",     "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "raidiconoffy",     "-5")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "fullhealth",       "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "target",           "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "namefightcolor",   "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "enemynpc",         "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "enemyplayer",      "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "neutralnpc",       "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "friendlynpc",      "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "friendlyplayer",   "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "critters",         "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "totems",           "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "totemicons",       "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showguildname",    "0")

  ShaguPlatesX:UpdateConfig("nameplates", nil,           "outcombatstate",   "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "barcombatstate",   "1")

  ShaguPlatesX:UpdateConfig("nameplates", nil,           "ccombatthreat",    "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "ccombatnothreat",  "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "ccombatstun",      "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "ccombatcasting",   "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "combatthreat",     ".6,1,0,1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "combatnothreat",   ".9,.2,.3,1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "combatstun",       ".8,.8,.8,1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "combatcasting",    ".7,.2,.7,1")

  ShaguPlatesX:UpdateConfig("nameplates", nil,           "outfriendly",      "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "outfriendlynpc",   "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "outneutral",       "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "outenemy",         "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targethighlight",  "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "highlightcolor",   "1,1,1,1")

  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showhp",           "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "hptextpos",        "RIGHT")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "hptextformat",     "curmaxs")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "width",            "120")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "debuffsize",       "14")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "debuffoffset",     "4")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "heighthealth",     "8")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "heightcast",       "8")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "cpdisplay",        "0")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targetglow",       "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "glowcolor",        "1,1,1,1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targetzoom",       "1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targetzoomval",    ".30")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targetzoominstant","1")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "notargalpha",      ".70")
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "healthtexture",    ShaguPlatesX.path.."\\img\\bar")
  ShaguPlatesX:UpdateConfig("nameplates", "name",        "fontstyle",        "OUTLINE")
  ShaguPlatesX:UpdateConfig("nameplates", "health",      "offset",           "-4")
  ShaguPlatesX:UpdateConfig("nameplates", "debuffs",     "filter",           "none")
  ShaguPlatesX:UpdateConfig("nameplates", "debuffs",     "whitelist",        "")
  ShaguPlatesX:UpdateConfig("nameplates", "debuffs",     "blacklist",        "")
  ShaguPlatesX:UpdateConfig("nameplates", "debuffs",     "showstacks",       "0")
  ShaguPlatesX:UpdateConfig("nameplates", "debuffs",     "position",         "BOTTOM")

  ShaguPlatesX:UpdateConfig("abuttons",   nil,           "enable",           "1")
  ShaguPlatesX:UpdateConfig("abuttons",   nil,           "position",         "bottom")
  ShaguPlatesX:UpdateConfig("abuttons",   nil,           "spacing",          "2")
  ShaguPlatesX:UpdateConfig("abuttons",   nil,           "hideincombat",     "1")

  ShaguPlatesX:UpdateConfig("screenshot", nil,           "interval",         "0")
  ShaguPlatesX:UpdateConfig("screenshot", nil,           "faction",          "0")
  ShaguPlatesX:UpdateConfig("screenshot", nil,           "hk",               "0")
  ShaguPlatesX:UpdateConfig("screenshot", nil,           "loot",             "0")
  ShaguPlatesX:UpdateConfig("screenshot", nil,           "caption",          "0")

  ShaguPlatesX:UpdateConfig("position",   nil,           nil,                nil)
  ShaguPlatesX:UpdateConfig("disabled",   nil,           nil,                nil)
end

function ShaguPlatesX:MigrateConfig()
  -- migrating to new fonts (1.5 -> 1.6)
  if checkversion(1, 6, 0) then
    -- migrate font_default
    if ShaguPlatesX_config.global.font_default == "arial" then
      ShaguPlatesX_config.global.font_default = "Myriad-Pro"
    elseif ShaguPlatesX_config.global.font_default == "homespun" then
      ShaguPlatesX_config.global.font_default = "Homespun"
    elseif ShaguPlatesX_config.global.font_default == "diediedie" then
      ShaguPlatesX_config.global.font_default = "DieDieDie"
    end

    -- migrate font_square
    if ShaguPlatesX_config.global.font_square == "arial" then
      ShaguPlatesX_config.global.font_square = "Myriad-Pro"
    elseif ShaguPlatesX_config.global.font_square == "homespun" then
      ShaguPlatesX_config.global.font_square = "Homespun"
    elseif ShaguPlatesX_config.global.font_square == "diediedie" then
      ShaguPlatesX_config.global.font_square = "DieDieDie"
    end

    -- migrate font_combat
    if ShaguPlatesX_config.global.font_combat == "arial" then
      ShaguPlatesX_config.global.font_combat = "Myriad-Pro"
    elseif ShaguPlatesX_config.global.font_combat == "homespun" then
      ShaguPlatesX_config.global.font_combat = "Homespun"
    elseif ShaguPlatesX_config.global.font_combat == "diediedie" then
      ShaguPlatesX_config.global.font_combat = "DieDieDie"
    end
  end



  -- migrating to new fontnames (> 2.6)
  if checkversion(2, 6, 0) then
    -- migrate font_combat
    if ShaguPlatesX_config.global.font_square then
      ShaguPlatesX_config.global.font_unit = ShaguPlatesX_config.global.font_square
      ShaguPlatesX_config.global.font_square = nil
    end
  end

  -- migrating old to new font layout (> 3.0.0)
  if checkversion(3, 0, 0) then
    -- migrate font_default
    if not strfind(ShaguPlatesX_config.global.font_default, "\\") then
      ShaguPlatesX_config.global.font_default = ShaguPlatesX.path.."\\fonts\\" .. ShaguPlatesX_config.global.font_default .. ".ttf"
    end

    -- migrate font_unit
    if not strfind(ShaguPlatesX_config.global.font_unit, "\\") then
      ShaguPlatesX_config.global.font_unit = ShaguPlatesX.path.."\\fonts\\" .. ShaguPlatesX_config.global.font_unit .. ".ttf"
    end

    -- migrate font_combat
    if not strfind(ShaguPlatesX_config.global.font_combat, "\\") then
      ShaguPlatesX_config.global.font_combat = ShaguPlatesX.path.."\\fonts\\" .. ShaguPlatesX_config.global.font_combat .. ".ttf"
    end
  end


  -- migrating animation_speed (> 3.1.2)
  if checkversion(3, 1, 2) then
    if tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 13 then
      ShaguPlatesX_config.unitframes.animation_speed = "13"
    elseif tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 8 then
      ShaguPlatesX_config.unitframes.animation_speed = "8"
    elseif tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 5 then
      ShaguPlatesX_config.unitframes.animation_speed = "5"
    elseif tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 3 then
      ShaguPlatesX_config.unitframes.animation_speed = "3"
    elseif tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 2 then
      ShaguPlatesX_config.unitframes.animation_speed = "2"
    elseif tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 1 then
      ShaguPlatesX_config.unitframes.animation_speed = "1"
    else
      ShaguPlatesX_config.unitframes.animation_speed = "5"
    end
  end

  -- migrating actionbar settings (> 3.19)
  if checkversion(3, 19, 0) then

    local migratebars = {
      ["pfBarActionMain"] = "pfActionBarMain",
      ["pfBarBottomLeft"] = "pfActionBarTop",
      ["pfBarBottomRight"] = "pfActionBarLeft",
      ["pfBarTwoRight"] = "pfActionBarVertical",
      ["pfBarRight"] = "pfActionBarRight",
      ["pfBarShapeshift"] = "pfActionBarStances",
      ["pfBarPet"] = "pfActionBarPet",
    }

    -- migrate bar positions and scaling
    for oldname, newname in pairs(migratebars) do
      if ShaguPlatesX_config.position[oldname] then
        ShaguPlatesX_config.position[newname] = ShaguPlatesX.api.CopyTable(ShaguPlatesX_config.position[oldname])
        ShaguPlatesX_config.position[oldname] = nil
      end
    end

    -- migrate global settings to bar specifics
    for i=1,12 do
      if ShaguPlatesX_config.bars.icon_size then
        ShaguPlatesX_config.bars["bar"..i].icon_size = ShaguPlatesX_config.bars.icon_size
      end

      if ShaguPlatesX_config.bars.background then
        ShaguPlatesX_config.bars["bar"..i].background = ShaguPlatesX_config.bars.background
      end

      if ShaguPlatesX_config.bars.showmacro then
        ShaguPlatesX_config.bars["bar"..i].showmacro = ShaguPlatesX_config.bars.showmacro
      end

      if ShaguPlatesX_config.bars.showkeybind then
        ShaguPlatesX_config.bars["bar"..i].showkeybind = ShaguPlatesX_config.bars.showkeybind
      end

      if ShaguPlatesX_config.bars.hide_time then
        ShaguPlatesX_config.bars["bar"..i].hide_time = ShaguPlatesX_config.bars.hide_time
      end
    end

    ShaguPlatesX_config.bars.icon_size = nil
    ShaguPlatesX_config.bars.background = nil
    ShaguPlatesX_config.bars.showmacro = nil
    ShaguPlatesX_config.bars.showkeybind = nil
    ShaguPlatesX_config.bars.hide_time = nil

    if ShaguPlatesX_config.bars.hide_actionmain then
      ShaguPlatesX_config.bars.bar1.autohide = ShaguPlatesX_config.bars.hide_actionmain
      ShaguPlatesX_config.bars.hide_actionmain = nil
    end

    if ShaguPlatesX_config.bars.hide_bottomleft then
      ShaguPlatesX_config.bars.bar6.autohide = ShaguPlatesX_config.bars.hide_bottomleft
      ShaguPlatesX_config.bars.hide_bottomleft = nil
    end

    if ShaguPlatesX_config.bars.hide_bottomright then
      ShaguPlatesX_config.bars.bar5.autohide = ShaguPlatesX_config.bars.hide_bottomright
      ShaguPlatesX_config.bars.hide_bottomright = nil
    end

    if ShaguPlatesX_config.bars.hide_right then
      ShaguPlatesX_config.bars.bar3.autohide = ShaguPlatesX_config.bars.hide_right
      ShaguPlatesX_config.bars.hide_right = nil
    end

    if ShaguPlatesX_config.bars.hide_tworight then
      ShaguPlatesX_config.bars.bar4.autohide = ShaguPlatesX_config.bars.hide_tworight
      ShaguPlatesX_config.bars.hide_tworight = nil
    end

    if ShaguPlatesX_config.bars.hide_shapeshift then
      ShaguPlatesX_config.bars.bar11.autohide = ShaguPlatesX_config.bars.hide_shapeshift
      ShaguPlatesX_config.bars.hide_shapeshift = nil
    end

    if ShaguPlatesX_config.bars.hide_pet then
      ShaguPlatesX_config.bars.bar12.autohide = ShaguPlatesX_config.bars.hide_pet
      ShaguPlatesX_config.bars.hide_pet = nil
    end

    if ShaguPlatesX_config.bars.actionmain and ShaguPlatesX_config.bars.actionmain.formfactor then
      ShaguPlatesX_config.bars.bar1.formfactor = ShaguPlatesX_config.bars.actionmain.formfactor
      ShaguPlatesX_config.bars.actionmain.formfactor = nil
    end

    if ShaguPlatesX_config.bars.bottomleft and ShaguPlatesX_config.bars.bottomleft.formfactor then
      ShaguPlatesX_config.bars.bar6.formfactor = ShaguPlatesX_config.bars.bottomleft.formfactor
      ShaguPlatesX_config.bars.bottomleft.formfactor = nil
    end

    if ShaguPlatesX_config.bars.bottomright and ShaguPlatesX_config.bars.bottomright.formfactor then
      ShaguPlatesX_config.bars.bar5.formfactor = ShaguPlatesX_config.bars.bottomright.formfactor
      ShaguPlatesX_config.bars.bottomright.formfactor = nil
    end

    if ShaguPlatesX_config.bars.right and ShaguPlatesX_config.bars.right.formfactor then
      ShaguPlatesX_config.bars.bar3.formfactor = ShaguPlatesX_config.bars.right.formfactor
      ShaguPlatesX_config.bars.right.formfactor = nil
    end

    if ShaguPlatesX_config.bars.tworight and ShaguPlatesX_config.bars.tworight.formfactor then
      ShaguPlatesX_config.bars.bar4.formfactor = ShaguPlatesX_config.bars.tworight.formfactor
      ShaguPlatesX_config.bars.tworight.formfactor = nil
    end

    if ShaguPlatesX_config.bars.shapeshift and ShaguPlatesX_config.bars.shapeshift.formfactor then
      ShaguPlatesX_config.bars.bar11.formfactor = ShaguPlatesX_config.bars.shapeshift.formfactor
      ShaguPlatesX_config.bars.shapeshift.formfactor = nil
    end

    if ShaguPlatesX_config.bars.pet and ShaguPlatesX_config.bars.pet.formfactor then
      ShaguPlatesX_config.bars.bar12.formfactor = ShaguPlatesX_config.bars.pet.formfactor
      ShaguPlatesX_config.bars.pet.formfactor = nil
    end
  end


  ShaguPlatesX_config.version = ShaguPlatesX.version.string
end
