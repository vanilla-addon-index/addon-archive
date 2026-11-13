local L = LibStub("AceLocale-3.0"):GetLocale("HardcoreAlarms")

local function ensureBelow(selfObj, val, dbKeyBelow, scaleSet)
    local currentBelowVal = selfObj.db.profile[dbKeyBelow]
    currentBelowVal = scaleSet and (currentBelowVal * scaleSet) or currentBelowVal
    if currentBelowVal >= val then
        local newBelowVal = val -1
        if newBelowVal <= 1 then newBelowVal = 1 end
        selfObj.db.profile[dbKeyBelow] = scaleSet and (newBelowVal / scaleSet) or newBelowVal
    end
end

local function makeWarnToggle(selfObj, name, desc, dbkey, warnlevel, order)
    return {
        order = order,
        type = "toggle",
        name = name,
        get = function() return selfObj.db.profile[dbkey][warnlevel] end,
        set = function(_, val) selfObj.db.profile[dbkey][warnlevel] = val; selfObj:ApplySettings() end,
    }
end

local function makeWarnToggleGroup(selfObj, name, desc, dbkey, order)
    return {
        order = order,
        type = "group",
        name = name,
        desc = desc,
        guiInline = true,
        args = {
            textOnly = makeWarnToggle(selfObj, L["OPT_TEXT"], nil, dbkey,selfObj.WARNLEVEL.TEXT, 1),
            textRedFlashing = makeWarnToggle(selfObj, L["OPT_FLASHING_SCREEN"], nil, dbkey,selfObj.WARNLEVEL.FLASHING_SCREEN, 2),
            sound = {
                order = 3,
                type = "select",
                name = L["OPT_SOUND"],
                values = {
                    off = L["OPT_SOUND_OFF"],
                    once = L["OPT_SOUND_ONCE"],
                    repeating = L["OPT_SOUND_REPEATING"]
                },
                get = function()
                    if selfObj.db.profile[dbkey][selfObj.WARNLEVEL.SOUND_ONCE] then
                        return "once"
                    elseif selfObj.db.profile[dbkey][selfObj.WARNLEVEL.SOUND_REPEATING] then
                        return "repeating"
                    else
                        return "off"
                    end
                end,
                set = function(_, val)
                    selfObj.db.profile[dbkey][selfObj.WARNLEVEL.SOUND_ONCE] = val == "once"
                    selfObj.db.profile[dbkey][selfObj.WARNLEVEL.SOUND_REPEATING] = val == "repeating"
                    selfObj:ApplySettings()
                end,
            }
        },
    }
end

local function makeRange(selfObj, name, desc, dbkey, order, min, max, step, scaleSet, dbKeyBelow, alwaysRefresh)
    return {
        order = order,
        type = "range",
        name = name,
        desc = desc,
        min = min, max = max, step = step,
        get = function() return selfObj.db.profile[dbkey] * (scaleSet or 1) end,
        set = function(_, val)
            selfObj.db.profile[dbkey] = scaleSet and (val / scaleSet) or val
            if dbKeyBelow then
                ensureBelow(selfObj, val, dbKeyBelow, scaleSet)
            end
            selfObj:ApplySettings()
            if dbKeyBelow then
                selfObj:RefreshBuildOptions()
            end
        end,
    }
end

function HardcoreAlarmsBuildOptions(selfObj, LibDBIcon)
    local profilesOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(selfObj.db)
    profilesOptions.order = 8
    profilesOptions.guiInline = true
    return {
        name = "HardcoreAlarms",
        type = "group",
        args = {
            profiles = profilesOptions,
            descriptionGroup = {
                order = 1,
                type = "group",
                name = L["OPT_DESCRIPTION_TOP_TITLE"],
                guiInline = true,
                args = {
                    descriptionTop = {
                        order = 1,
                        type = "description",
                        name = L["OPT_DESCRIPTION_TOP"],
                    },
                },
            },
            minimap = {
                order = 2,
                type = "group",
                name = L["OPT_MINIMAP_ICON"],
                guiInline = true,
                args = {
                    showMinimap = {
                        order = 1,
                        type = "toggle",
                        name = L["OPT_SHOW_MINIMAP"],
                        get = function() return not selfObj.db.profile.minimapIcon.hide end,
                        set = function(_, val)
                            selfObj.db.profile.minimapIcon.hide = not val
                            if LibDBIcon then
                                if val then LibDBIcon:Show("HardcoreAlarms") else LibDBIcon:Hide("HardcoreAlarms") end
                            end
                        end,
                    },
                },
            },

            ui = {
                order = 3,
                type = "group",
                name = L["OPT_UI"],
                guiInline = true,
                args = {
                    testWarnLevel = {
                        order = 1,
                        type = "toggle",
                        name = L["OPT_MOVABLE"],
                        desc = L["OPT_MOVABLE_DESC"],
                        get = function() return selfObj.db.profile.testWarnLevel[selfObj.WARNLEVEL.TEXT] end,
                        set = function(_, val)
                            selfObj.db.profile.testWarnLevel[selfObj.WARNLEVEL.TEXT] = val
                            selfObj:ApplySettings()
                        end,
                    },
                    warnStyle = {
                        order = 2,
                        type = "select",
                        name = L["OPT_WARN_STYLE"],
                        desc = L["OPT_WARN_STYLE_DESC"],
                        values = {
                            o1 = L["OPT_WARN_STYLE_BORDER_BG"],
                            o2 = L["OPT_WARN_STYLE_ONLY_BG"],
                            o3 = L["OPT_WARN_STYLE_ONLY_TEXT"],
                        },
                        get = function() return selfObj.db.profile.warnStyle end,
                        set = function(_, val) selfObj.db.profile.warnStyle = val; selfObj:ApplySettings() end,
                    }
                },
            },

            warnlevels = {
                order = 4,
                type = "group",
                name = L["OPT_WARN_PREF"],
                guiInline = true,
                args = {
                    breathWarnLevel = makeWarnToggleGroup(selfObj, L["OPT_BREATH_WARN"],
                        L["OPT_BREATH_WARN_DESC"],
                        "breathWarnLevel", 1),
                    hpWarnLevel = makeWarnToggleGroup(selfObj, L["OPT_HP_WARN"],
                        L["OPT_HP_WARN_DESC"],
                        "hpWarnLevel", 2),
                    petHpWarnLevel = makeWarnToggleGroup(selfObj, L["OPT_PET_HP_WARN"],
                        L["OPT_PET_HP_WARN_DESC"],
                        "petHpWarnLevel", 3),
                    dangerousTargetWarnLevel = makeWarnToggleGroup(selfObj, L["OPT_DANG_TARGET_WARN"],
                        L["OPT_DANG_TARGET_WARN_DESC"],
                        "dangerousTargetWarnLevel", 4),
                    dangerousTargetEliteWarnLevel = makeWarnToggleGroup(selfObj, L["OPT_DANG_ELITE_WARN"],
                        L["OPT_DANG_ELITE_WARN_DESC"],
                        "dangerousTargetEliteWarnLevel", 5),
                    dangerousTargetPvpWarnLevel = makeWarnToggleGroup(selfObj, L["OPT_DANG_PVP_WARN"],
                        L["OPT_DANG_PVP_WARN_DESC"],
                        "dangerousTargetPvpWarnLevel", 6),
                    selfPvpFlaggedWarnLevel = makeWarnToggleGroup(selfObj, L["OPT_SELF_PVP_WARN"],
                        L["OPT_SELF_PVP_WARN_DESC"],
                        "selfPvpFlaggedWarnLevel", 7),
                    questWarnLevel = makeWarnToggleGroup(selfObj, L["OPT_QUEST_WARN"],
                        L["OPT_QUEST_WARN_DESC"],
                        "questWarnLevel", 8),
                    unitscanWarnLevel = {
                        order = 9,
                        type = "group",
                        name = L["OPT_UNITSCAN_WARN"],
                        desc = L["OPT_UNITSCAN_WARN_DESC"],
                        guiInline = true,
                        args = {
                            textOnly = makeWarnToggle(selfObj, L["OPT_TEXT"], nil, "unitscanWarnLevel",selfObj.WARNLEVEL.TEXT, 1),
                            textRedFlashing = makeWarnToggle(selfObj, L["OPT_FLASHING_SCREEN"], nil, "unitscanWarnLevel",selfObj.WARNLEVEL.FLASHING_SCREEN, 2),
                            sound = makeWarnToggle(selfObj, L["OPT_SOUND"], nil, "unitscanWarnLevel",selfObj.WARNLEVEL.SOUND_ONCE, 3),
                        },
                    }
                },
            },

            thresholds = {
                order = 5,
                type = "group",
                name = L["OPT_THRESHOLDS"],
                guiInline = true,
                args = {
                    breathThresholdPrefs = {
                        order = 1,
                        type = "group",
                        name = L["OPT_BREATH_LOW"],
                        guiInline = true,
                        args = {
                            breathWarnThreshold = makeRange(selfObj, L["OPT_BREATH_WARN_SEC"],
                                L["OPT_BREATH_WARN_SEC_DESC"],
                                "breathWarnThreshold", 1, 1, 60, 1, 1, "breathPanicThreshold"),
                            breathPanicThreshold = makeRange(selfObj, L["OPT_BREATH_PANIC_SEC"],
                                L["OPT_BREATH_PANIC_SEC_DESC"],
                                "breathPanicThreshold", 2, 1, selfObj.db.profile["breathWarnThreshold"] - 1, 1, 1),
                        },
                    },
                    hpThresholdPrefs = {
                        order = 2,
                        type = "group",
                        name = L["OPT_HP_LOW"],
                        guiInline = true,
                        args = {
                            hpWarnThreshold = makeRange(selfObj, L["OPT_HP_WARN_PCT"],
                                L["OPT_HP_WARN_PCT_DESC"],
                                "hpWarnThreshold", 3, 1, 100, 1, 100, "hpPanicThreshold"),
                            hpPanicThreshold = makeRange(selfObj, L["OPT_HP_PANIC_PCT"],
                                L["OPT_HP_PANIC_PCT_DESC"],
                                "hpPanicThreshold", 4, 1, selfObj.db.profile["hpWarnThreshold"] * 100 - 1, 1, 100),
                        },
                    },
                    petHpThresholdPrefs = {
                        order = 3,
                        type = "group",
                        name = L["OPT_PET_HP_LOW"],
                        guiInline = true,
                        args = {
                            petHpWarnThreshold = makeRange(selfObj, L["OPT_HP_WARN_PCT"],
                                L["OPT_HP_WARN_PCT_DESC"],
                                "petHpWarnThreshold", 3, 1, 100, 1, 100, "petHpPanicThreshold"),
                            petHpPanicThreshold = makeRange(selfObj, L["OPT_HP_PANIC_PCT"],
                                L["OPT_HP_PANIC_PCT_DESC"],
                                "petHpPanicThreshold", 4, 1, selfObj.db.profile["petHpWarnThreshold"] * 100 - 1, 1, 100),
                        },
                    },
                    levelDiffThresholdPrefs = {
                        order = 4,
                        type = "group",
                        name = L["OPT_LEVEL_DIFF"],
                        guiInline = true,
                        args = {
                            leveldiffWarnThreshold = makeRange(selfObj, L["OPT_LEVELDIFF_NORMAL"],
                                L["OPT_LEVELDIFF_NORMAL_DESC"],
                                "leveldiffWarnThreshold", 5, -10, 20, 1, 1),
                            leveldiffWarnEliteThreshold = makeRange(selfObj, L["OPT_LEVELDIFF_ELITE"],
                                L["OPT_LEVELDIFF_ELITE_DESC"],
                                "leveldiffWarnEliteThreshold", 6, -20, 10, 1, 1),
                            leveldiffWarnUnitscanThreshold = makeRange(selfObj, L["OPT_LEVELDIFF_UNITSCAN"],
                                L["OPT_LEVELDIFF_UNITSCAN_DESC"],
                                "leveldiffWarnUnitscanThreshold", 7, -20, 10, 1, 1),
                        },
                    },
                },
            },

            unitscan = {
                order = 6,
                type = "group",
                name = L["OPT_UNITSCAN"],
                guiInline = true,
                args = {
                    unitscanDescription = {
                        order = 1,
                        type = "description",
                        name = L["OPT_UNITSCAN_DESC"],
                    },
                    unitscanEnabled = {
                        order = 2,
                        type = "toggle",
                        name = L["OPT_UNITSCAN_ENABLE"],
                        desc = L["OPT_UNITSCAN_ENABLE_DESC"],
                        get = function() return selfObj.db.profile.unitscanEnabled end,
                        set = function(_, val) selfObj.db.profile.unitscanEnabled = val; selfObj:ApplySettings() end,
                    },
                    unitscanInCombatEnabled = {
                        order = 3,
                        type = "toggle",
                        name = L["OPT_UNITSCAN_ENABLE_COMBAT"],
                        desc = L["OPT_UNITSCAN_ENABLE_COMBAT_DESC"],
                        get = function() return selfObj.db.profile.unitscanInCombatEnabled end,
                        set = function(_, val) selfObj.db.profile.unitscanInCombatEnabled = val; selfObj:ApplySettings() end,
                    },
                },
            },

            debug = {
                order = 9,
                type = "group",
                name = L["OPT_DEBUG"],
                guiInline = true,
                args = {
                    debugOutput = {
                        order = 1,
                        type = "toggle",
                        name = L["OPT_DEBUG_OUTPUT"],
                        desc = L["OPT_DEBUG_OUTPUT_DESC"],
                        get = function() return selfObj.db.profile.debugOutput end,
                        set = function(_, val) selfObj.db.profile.debugOutput = val; selfObj:ApplySettings() end,
                    },
                    checkLoopInterval = makeRange(selfObj, L["OPT_CHECK_LOOP_INT"],
                        L["OPT_CHECK_LOOP_INT_DESC"],
                        "checkLoopInterval", 2, 0.01, 1, 0.01, 1),
                },
            },

            resetGroup = {
                order = 7,
                type = "group",
                name = L["OPT_CLEAR_IGNORED"],
                guiInline = true,
                args = {
                    resetDescription = {
                        order = 1,
                        type = "description",
                        name = L["OPT_CLEAR_IGNORED_DESC"],
                    },
                    reset = {
                        order = 2,
                        type = "execute",
                        name = L["OPT_CLEAR_IGNORED"],
                        confirm = true,
                        func = function()
                            selfObj.db.profile.blacklistedQuestIds = {}
                            selfObj.db.profile.blacklistedUnitIds = {}
                            selfObj.db.profile.blacklistedUnitscanNames = {}
                            selfObj:ApplySettings()
                        end,
                    },
                },
            },


        },
    }
end
