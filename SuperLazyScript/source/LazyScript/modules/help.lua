local _G = getfenv(0)

local c = {}
local function refreshPalette()
    for key in pairs (c) do
        c[key] = nil
    end
    local theme = lazyScript.theme.themes[lazyScript.theme.active]
    if theme and theme.text then
        for name, code in pairs (theme.text) do
            c[name] = code
        end
    end
end
refreshPalette()
lazyScript.formHelp.refreshPalette = refreshPalette()

-- Clear help text after all addons have loaded
-- ---
local fr = CreateFrame("Frame")
fr:RegisterEvent("PLAYER_LOGIN")
fr:SetScript("OnEvent", function()

    lazyScript.formHelp.tabHelpText = {}
end)

--
-- ---
lazyScript.formHelp.Tabs = {
    [1] = "Actions",
    [2] = "Conditions",
    [3] = "Forms",
    [4] = "Settings",
    [5] = "Extras"
}

do
    LazyScriptFormHelpScrollFrameScrollChildText:SetScript("OnHyperlinkClick", function()
        -- arg1 is the link content (e.g., "tab:5")
        -- arg2 is the full text of the link
        -- arg3 is the mouse button used
        lazyScript.formHelp.HandleHyperlink(arg1)
    end)
    LazyScriptFormHelpScrollFrameScrollChildText:SetScript("OnHyperlinkEnter", function(self, link, text, button)
        SetCursor("Interface/Cursor/Cast")
    end)
    LazyScriptFormHelpScrollFrameScrollChildText:SetScript("OnHyperlinkLeave", function(self)
        ResetCursor()
    end)
end

---@diagnostic disable-next-line: duplicate-set-field
function lazyScript.formHelp.HandleHyperlink(link)
    if not link then return end
    -- Check if the link starts with our custom prefix
    if (string.sub(link, 1, 4) == "tab:") then
        local tabIndex = tonumber(string.sub(link, 5))
        -- local tabName = lazyScript.formHelp.Tabs[tabIndex]

        lazyScript.formHelp.OnTabButtonClick(tabIndex, Extras)
        LazyScriptFormHelp.selectedTab = tabIndex
        PanelTemplates_UpdateTabs(LazyScriptFormHelp)
    end
end

-- Colorize functions
-- ---
close = "|r"
local function Colorize(str)
    local protected = {}

    -- protect existing |c...|r color tags
    str = string.gsub(str, "|c%x%x%x%x%x%x%x%x[^|]*|r", function(span)
        table.insert(protected, span)
        return "\2" .. table.getn(protected) .. "\2"
    end)

    -- protect HTML tags
    str = string.gsub(str, "<[^>]+>", function(tag)
        table.insert(protected, tag)
        return "\2" .. table.getn(protected) .. "\2"
    end)

    -- colorise
    str = string.gsub(str, "%[(.-)%]", function(inner)
        return c.info .. "[" .. c.danger .. inner .. close .. c.info .. "]" .. close
    end)
    str = string.gsub(str, "%{(.-)%}", function(inner)
        return c.danger .. "{" .. c.success .. inner .. close .. c.danger .. "}" .. close
    end)

    -- restore everything
    str = string.gsub(str, "\2(%d+)\2", function(i)
        return protected[tonumber(i)]
    end)

    return str
end

local h1 = "<H1>"
local h2 = "<H2>"
local h2c = "</H2>"
local h1c = "</H1>"
local p = "<P>"
local pc = "</P>"
local br = "<BR/>"
-- Setup Tab 1
-- ---
---@diagnostic disable-next-line: duplicate-set-field
function lazyScript.formHelp.SetupOverview()
    local text = "<HTML><BODY>"
    text = text .. p .. c.bg .. "bg" .. c.bghighlight .. "bghighlight" .. c.primary .. "primary" .. c.secondary .. "secondary" .. c.emphasis .. "emphasis" .. c.success .. "success" .. c.danger .. "danger" .. c.warning .. "warning" .. c.info .. "info" .. c.nogcd .. "nogcd" .. pc .. br
    text = text .. h1 .. TAB_OVERVIEW_1 .. h1c .. "<BR/>" -- 'overview'
    text = text .. p .. TAB_OVERVIEW_2 .. pc .. "<BR/>"
    text = text .. p .. TAB_OVERVIEW_3 .. pc .. "<BR/>"
    text = text .. h2 .. TAB_OVERVIEW_TUTORIAL_1_1 .. h2c
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_1_2 .. pc .. "<BR/>"
    text = text .. "<H3>ss</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_1_3 .. pc .. "<BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_1_4 .. pc .. "<BR/>"
    text = text .. "<H3>/lazyscript</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_1_5 .. pc .. "<BR/>"
    text = text .. h2 .. TAB_OVERVIEW_TUTORIAL_2_1 .. h2c
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_2_2 .. pc
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_2_3 .. pc .. "<BR/>"
    text = text .. "<H3>riposte</H3>"
    text = text .. "<H3>ss</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_2_4 .. pc .. "<BR/>"
    text = text .. h2 .. TAB_OVERVIEW_TUTORIAL_3_1 .. h2c
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_3_2 .. pc .. "<BR/>"
    text = text .. "<H3>kick-ifTargetIsCasting</H3>"
    text = text .. "<H3>riposte</H3>"
    text = text .. "<H3>ss</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_3_3 .. pc .. "<BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_3_4 .. pc
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_3_5 .. pc .. "<BR/>"
    text = text .. "<H3>kick-ifTargetIsCasting=FIRE</H3>"
    text = text .. "<H3>riposte</H3>"
    text = text .. "<H3>ss</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_3_6 .. pc
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_3_7 .. pc .. "<BR/>"
    text = text .. "<H3>kick-ifTargetIsCasting=FIRE,FROST|r</H3>"
    text = text .. "<H3>riposte</H3>"
    text = text .. "<H3>ss</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_3_8 .. pc
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_3_9 .. pc .. "<BR/>"
    text = text .. "<H3>kick-ifTargetIsCasting=Heal,Greater Heal|r</H3>"
    text = text .. "<H3>riposte</H3>"
    text = text .. "<H3>ss</H3><BR/>"
    text = text .. h2 .. TAB_OVERVIEW_TUTORIAL_4_1 .. h2c
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_4_2 .. pc .. "<BR/>"
    text = text .. "<H3>snd-ifNotPlayerHasBuff=snd</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_4_3 .. pc .. "<BR/>"
    text = text .. "<H3>rupture-ifNotTargetHasDebuff=rupture|r</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_4_4 .. pc
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_4_5 .. pc .. "<BR/>"
    text = text .. "<H3>echo=w00t-ifPlayerHasBuffTitle=Rallying Cry of the Dragonslayer</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_4_6 .. pc
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_4_7 .. pc .. "<BR/>"
    text = text .. "<H3>stopAll-ifTargetHasDebuff&lt;3=sunder</H3><BR/>"
    text = text .. h2 .. TAB_OVERVIEW_TUTORIAL_5_1 .. h2c
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_5_2 .. pc .. "<BR/>"
    text = text .. "<H3>coldBlood-evisc-sayInSay=DIE!-ifCbKillShot</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_5_3 .. pc .. "<BR/>"
    text = text .. "<H3>huntersMark-petAttack</H3>"
    text = text .. "<H3>judge-sealCommand</H3>"
    text = text .. "<H3>innerFocus-greaterHeal</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_1 .. pc
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_2 .. pc .. "<BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_FORM_INT .. pc
    text = text .. "<H3>kick-ifTargetIsCasting-ifNotTargetIs=Stunned</H3>"
    text = text .. "<H3>gouge-ifTargetIsCasting-ifNotInFrontAttackJustFailed-ifNotTargetIs=Stunned</H3>"
    text = text ..
               "<H3>ks-ifTargetIsCasting=Greater Heal,Prayer of Healing,Healing Touch,Holy Light,Healing Wave,Chain Heal-ifNotTargetIs=Stunned</H3>"
    text = text ..
               "<H3>blind-ifTargetIsCasting=Greater Heal,Prayer of Healing,Healing Touch,Holy Light,Healing Wave,Chain Heal-ifNotTargetIs=Stunned</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_FORM_FA .. pc
    text = text .. "<H3>includeForm=Interrupts</H3>"
    text = text .. "<H3>riposte</H3>"
    text = text .. "<H3>evisc-5cp</H3>"
    text = text .. "<H3>ss</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_FORM_BA .. pc
    text = text .. "<H3>includeForm=Interrupts</H3>"
    text = text .. "<H3>evisc-5cp</H3>"
    text = text .. "<H3>bs</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_3 .. pc .. "<BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_4 .. pc .. "<BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_5 .. pc .. "<BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_FORM_INT .. pc
    text = text .. "<H3>kick</H3>"
    text = text .. "<H3>gouge-ifNotInFrontAttackJustFailed</H3>"
    text = text ..
               "<H3>ks-ifTargetIsCasting=Greater Heal,Prayer of Healing,Healing Touch,Holy Light,Healing Wave,Chain Heal</H3>"
    text = text ..
               "<H3>blind-ifTargetIsCasting=Greater Heal,Prayer of Healing,Healing Touch,Holy Light,Healing Wave,Chain Heal</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_FORM_FA .. pc
    text = text .. "<H3>callForm=Interrupts-ifTargetIsCasting-ifNotTargetIs=Stunned</H3>"
    text = text .. "<H3>riposte</H3>"
    text = text .. "<H3>evisc-5cp|</H3>"
    text = text .. "<H3>ss</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_FORM_BA .. pc
    text = text .. "<H3>callForm=Interrupts-ifTargetIsCasting-ifNotTargetIs=Stunned</H3>"
    text = text .. "<H3>evisc-5cp</H3>"
    text = text .. "<H3>bs</H3><BR/>"
    text = text .. p .. TAB_OVERVIEW_TUTORIAL_6_6 .. pc .. "<BR/>"
    text = text .. "</BODY></HTML>"
    -- lazyScript.formHelp.tabHelpText[Overview] = Colorize(text)
    lazyScript.formHelp.tabHelpText[Overview] = Colorize(text)
end
function lazyScript.formHelp.SetupExtras()
    local text = "<HTML><BODY>"
    text = text .. "<H1>Extra documentation" .. close .. "</H1>" .. br
    text = text .. "<H2>Valid UnitIDs:</H2>"
    text = text .. "<P>The following unit IDs can be used in actions that require a target unit (e.g., action{" ..
               c.info .. "@&lt;UnitId&gt;}" .. c.secondary .. "):</P>"
    local displayUnitIds = {"player", "pet", "party1, party2, party3, party4",
                            "partypet1, partypet2, partypet3, partypet4", "raid[1-40]", "raidpet[1-40]", "target",
                            "targettarget", "mouseover"}
    local unitIdList = {}
    for _, unitId in ipairs(displayUnitIds) do
        table.insert(unitIdList, c.info .. unitId .. close)
    end
    text = text .. "<P>" .. table.concat(unitIdList, "</P><P>") .. "</P>"
    text = text .. br .. "<H2>New Features:</H2>"
    text =
        text .. "<P>" .. c.warning .. "/ls" .. c.primary .. "	command for use in macros, e.g., `" .. c.warning .. "/ls" ..
            c.success .. " do" .. c.warning .. " ss" .. c.primary .. "`</P>"
    text = text .. "<P>" .. c.warning .. "(smart)" .. c.primary ..
               "	tag; if you are using LazySpell, this tag will replace the rank of spell for Lazyspell calculation, e.g., `" ..
               c.warning .. "/ls" .. c.success .. " do " .. c.warning .. "heal" .. c.warning .. "(smart)" .. c.info ..
               "@mouseover" .. c.primary .. "`</P>"
    text = text .. "<P>" .. c.primary .. "if[Not]" .. c.primary .. "GotTalent={Talent1,Talent2}" .. c.primary ..
               "	criteria</P>"
    text = text .. "<P>" .. c.primary .. "Support for LUNA, pfUI, NotGrid unitframes in " .. c.info .. "mouseover" ..
               c.primary .. " actions</P>"
    text =
        text .. "<P>" .. c.primary .. "" .. c.emphasis .. "frostNova" .. c.primary .. " and " .. c.emphasis .. "frostbite" ..
            c.primary .. "	to known debuffs</P>"
    text = text .. "<P>" .. c.primary .. "if[Not]" .. c.primary .. "PartyHaveClass" .. c.primary .. "		criteria; e.g., `" ..
               c.warning .. "sayInParty" .. c.primary .. "=" .. c.success .. "No Totem!" .. c.primary ..
               "-ifPartyHaveClass=shaman" .. c.primary .. "`</P>"
    text = text .. "<P>" .. c.primary .. "active=message" .. c.primary ..
               "		action; this action will indicate what script is active, e.g., 'active=solo-every2s'. This message will pop-up in a small window for about 1 second.</P>"
    text = text .. "<P>" .. c.primary .. "if[Not]" .. c.primary .. "OnCooldown" .. c.primary ..
               ";	added as an alternative for ifInCooldown for grammatic consistency</P>"
    text = text .. "<P>" .. c.primary .. "if[Not]" .. c.primary .. "AutoShotSafe" .. c.primary ..
               ";	this mask will try not to clip autoshots [Hunter only] [Quiver Required]" .. c.primary .. ". " ..
               c.primary .. "Mileage may vary according to lag.</P>"
    text = text .. "<P>" .. c.primary .. "if[Not]" .. c.primary .. "SwingSafe" .. c.primary ..
               ";		this mask will try not to clip weapon swings [SP_SwingTimer Required]" .. c.primary .. ".</P>"
    --[[
                sayinparty = "nototem!"
	sayInParty=NoTotem-ifPartyHaveClass=shaman

	- Added ifShieldEquipped criteria
	- Added action active=msg ucan use it to indicate what script is active now
	example active-solo-every2s
	- Added `Zeal` buff\debuff
	]]
    text = text .. "<BR/><H1>" .. c.secondary .. "List of PlaySound Actions</H1><BR/>"
    text = text .. "<P>" .. c.secondary .. "The playSound action plays a sound file. Syntax:</P>"
    text = text .. "<P>|cff40ff40playSound|r={soundName}</P><BR/>"
    text = text .. "<P>" .. c.secondary .. "Valid sound names include " .. c.danger ..
               "(note: some have deliberate typos that work in-game)" .. c.secondary .. ":</P>"
    local VALID_SOUND_NAMES = {"ACTIONBARBUTTONDOWN", "AUCTIONWINDOWCLOSE", "AUCTIONWINDOWOPEN", "BAGMENUBUTTONPRESS",
                               "Deathbind Sound", "DwarfExploration", "Fishing Reel in", "FriendJoinGame",
                               "GAMEABILITYACTIVATE", "GAMEABILITYBUTTONMOUSEDOWN", "GAMEERRORINVALIDTARGET",
                               "GAMEERROROUTOFMANA", "GAMEERROROUTOFRANGE", "GAMEERRORUNABLETOEQUIP", "GAMEDIALOGCLOSE",
                               "GAMEDIALOGOPEN", "GAMEGENERICBUTTONPRESS", "GAMEHIGHLIGHTFRIENDLYUNIT",
                               "GAMEHIGHLIGHTHOSTILEUNIT", "GAMEHIGHLIGHTNEUTRALUNIT", "GAMEINITIALATTACK",
                               "GAMENEWWINDOWTAB", "GAMESCREENLARGEBUTTONMOUSEDOWN", "GAMESCREENLARGEBUTTONMOUSEOVER",
                               "GAMESCREENLARGEBUTTONMOUSEUP", "GAMESCREENMEDIUMBUTTONMOUSEDOWN",
                               "GAMESCREENMEDIUMBUTTONMOUSEOVER", "GAMESCREENMEDIUMBUTTONMOUSEUP",
                               "GAMESCREENSMALLBUTTONMOUSEDOWN", "GAMESCREENSMALLBUTTONMOUSEOVER",
                               "GAMESCREENSMALLBUTTONMOUSEUP", "GAMESPELLACTIVATE", "GAMESPELLBUTTONMOUSEDOWN",
                               "GAMETARGETFRIENDLYUNIT", "GAMETARGETHOSTILEUNIT", "GAMETARGETNEUTRALUNIT",
                               "GAMEWINDOWCLOSE", "GAMEWINDOWOPEN", "GLUECHARCUSTOMIZATIONMOUSEDOWN",
                               "GLUECHARCUSTOMIZATIONMOUSEOVER", "GLUECHARCUSTOMIZATIONMOUSEUP",
                               "GLUECHECKBOXMOUSEDOWN", "GLUECHECKBOXMOUSEOVER", "GLUECHECKBOXMOUSEUP",
                               "GLUECREATECHARACTERBUTTON", "GLUEENTERWORLDBUTTON", "GLUEGENERICBUTTONPRESS",
                               "GLUESCREENEDITBOXKEYCLICK", "GLUESCREENLARGEBUTTONMOUSEDOWN",
                               "GLUESCREENLARGEBUTTONMOUSEOVER", "GLUESCREENLARGEBUTTONMOUSEUP",
                               "GLUESCREENMEDIUMBUTTONMOUSEDOWN", "GLUESCREENMEDIUMBUTTONMOUSEOVER",
                               "GLUESCREENMEDIUMBUTTONMOUSEUP", "GLUESCREENSMALLBUTTONMOUSEDOWN",
                               "GLUESCREENSMALLBUTTONMOUSEOVER", "GLUESCREENSMALLBUTTONMOUSEUP",
                               "GLUESCROLLBUTTONMOUSEDOWN", "GLUESCROLLBUTTONMOUSEOVER", "GLUESCROLLBUTTONMOUSEUP",
                               "GLUESOCIALCLOSE", "GLUESOCIALOPEN", "GnomeExploration", "gsCharacterCreationCancel",
                               "gsCharacterCreationClass", "gsCharacterCreationCreateChar", "gsCharacterCreationGender",
                               "gsCharacterCreationLook", "gsCharacterCreationRace", "gsCharacterSelection",
                               "gsCharacterSelectionAcctOptions", "gsCharacterSelectionCreateNew",
                               "gsCharacterSelectionDelCharacter", "gsCharacterSelectionEnterWorld",
                               "gsCharacterSelectionExit", "gsLogin", "gsLoginChangeRealm", "gsLoginChangeRealmCancel",
                               "gsLoginChangeRealmOK", "gsLoginChangeRealmSelect", "gsLoginExit", "gsLoginNewAccount",
                               "gsTitleCredits", "gsTitleEnterWorld", "gsTitleIntroMovie", "gsTitleOK",
                               "gsTitleOption16bit", "gsTitleOption32bit", "gsTitleOptionDirect3D", "gsTitleOptionExit",
                               "gsTitleOptionFullScreenMode", "gsTitleOptionOK", "gsTitleOptionOpenGL",
                               "gsTitleOptionScreenResolution", "gsTitleOptions", "gsTitleQuit", "HumanExploration",
                               "igAbilityClose", "igAbilityIconDrop", "igAbilityIconPickup", "igAbilityOpen",
                               "igAbiliityPageTurn", "igBackPackClose", "igBackPackCoinCancel", "igBackPackCoinOK",
                               "igBackPackCoinSelect", "igBackPackOpen", "igBonusBarOpen", "igCharacterInfoClose",
                               "igCharacterInfoOpen", "igCharacterInfoScrollDown", "igCharacterInfoScrollUp",
                               "igCharacterInfoTab", "igCharacterNPCDeselect", "igCharacterNPCSelect",
                               "igCharacterSelect", "igCharacterDeselect", "igChatBottom", "igChatEmoteButton",
                               "igChatScrollDown", "igChatScrollUp", "igCreatureAggroDeselect", "igCreatureAggroSelect",
                               "igCreatureNeutralDeselect", "igCreatureNeutralSelect", "igCurrentActiveSpell",
                               "igInventoryClose", "igInventoryOepn", "igInventoryRotateCharacter", "igMainMenuClose",
                               "igMainMenuContinue", "igMainMenuLogout", "igMainMenuOpen", "igMainMenuOption",
                               "igMainMenuOptionCheckBoxOff", "igMainMenuOptionCheckBoxOn", "igMainMenuOptionFaerTab",
                               "igMainMenuQuit", "igMiniMapClose", "igMiniMapOpen", "igMiniMapZoomIn",
                               "igMiniMapZoomOut", "igPlayerInvite", "igPlayerInviteAccept", "igPlayerInviteDecline",
                               "igPVPUpdate", "igQuestCancel", "igQuestFailed", "igQuestListClose",
                               "igQuestListComplete", "igQuestListOpen", "igQuestListSelect", "igQuestLogAbandonQuest",
                               "igQuestLogClose", "igQuestLogOpen", "igSocialClose", "igSocialOepn", "igSpellBookClose",
                               "igSpellBookOpen", "igSpellBookSpellIconDrop", "igSpellBookSpellIconPickup",
                               "igSpellBokPageTur", "INTERFACESOUND_BACKPACKCLOSE", "INTERFACESOUND_BACKPACKOPEN",
                               "INTERFACESOUND_CHARWINDOWCLOSE", "INTERFACESOUND_CHARWINDOWOPEN",
                               "INTERFACESOUND_CHARWINDOWTAB", "INTERFACESOUND_CURSORGRABOBJECT",
                               "INTERFACESOUND_CURSORDROPOBJECT", "INTERFACESOUND_GAMEMENUCLOSE",
                               "INTERFACESOUND_GAMEMENUOPEN", "INTERFACESOUND_GAMESCROLLBUTTON",
                               "INTERFACESOUND_LOSTTARGETUNIT", "INTERFACESOUND_MONEYFRAMECLOSE",
                               "INTERFACESOUND_MONEYFRAMEOPEN", "ITEMARMORSOUND", "ITEMGENERICSOUND", "ITEMWEAPONSOUND",
                               "LEVELUP", "LEVELUPSOUND", "LOOTWINDOWCLOSE", "LOOTWINDOWCOINSOUND", "LOOTWINDOWOPEN",
                               "LOOTWINDOWOPENEMPTY", "MAINBUTTONBARMENU", "MapPing", "MINIMAPCLOSE", "MINIMAPOPEN",
                               "MINIMAPZOOMIN", "MINIMAPZOOMOUT", "MONEYFRAMECLOSE", "MONEYFRAMEOPEN",
                               "NightElfExploration", "OrcExploration", "PAPERDOLLCLOSE", "PAPERDOLLOPEN",
                               "PVPENTERQUEUE", "PVPTHROUGHQUEUE", "QUESTADDED", "QUESTCOMPLETED", "QUESTLOGCLOSE",
                               "QUESTLOGOPEN", "RaidWarning", "ReadyCheck", "SHEATHINGMETALWEAPONUNSHEATHE",
                               "SHEATHINGMETALWEAPONSHEATHE", "SHEATHINGSHIELDUNSHEATHE", "SHEATHINGSHIELDSHEATHE",
                               "SHEATHINGWOODWEAPONUNSHEATHE", "SHEATHINGWOODWEAPONSHEATHE", "SPELLBOOKCHANGEPAGE",
                               "SPELLBOOKCLOSE", "SPELLBOOKOPEN", "TalentScreenClose", "TalentScreenOpen",
                               "TaxiNodeDiscovered", "TaurenExploration", "TellMessage", "TrollExploration",
                               "UChatScrollButton", "UndeadExploration", "UnwrapGift", "WriteQuest"}

    local soundList = {}
    for _, soundName in ipairs(VALID_SOUND_NAMES) do
        local displayName = soundName
        -- Highlight known typos with different color
        if soundName == "igSocialOepn" or soundName == "igInventoryOepn" then
            displayName = c.danger .. soundName .. "|r" -- Red color for typos
        else
            displayName = c.emphasis .. soundName .. "|r"
        end
        -- Play button
        -- local playButton = "|cff40ff40<a href=\"playsound:" .. soundName .. "\">[>]</a>|r"
        -- table.insert(soundList, playButton .. " " .. displayName)
        table.insert(soundList, displayName)
    end

    -- sound player

    text = text .. "<P>" .. table.concat(soundList, "</P><P>") .. "</P>"
    text = text .. "<BR/></BODY></HTML>"

    lazyScript.formHelp.tabHelpText[Extras] = Colorize(text)
end

TAB_ACTIONS_GREEN_ACTIONS =
    [[<BR/>]] .. c.info .. [[Actions with a ]] .. c.nogcd .. [[green pip    •|r ]]..c.info..[[do not trigger the global
    cooldown. LazyScript is able to perform multiple of these actions on a single line provided that the line has at
    most one action that triggers the global cooldown.<BR/>]]
TAB_ACTIONS_SYNTAX_SPECIFIC_SPELL_RANK_1 = [[
The &lt;UnitId&gt; can be any valid UnitId sequence as described in the 
<a href='tab:5'>]] .. c.info .. [[Extras|r</a> tab. For example, @player, @pet, 
@target, @targettarget. Note that the rank of the spell must always 
appear before the '@' symbol.
	]]
-- Setup Tab 2
-- ---
function lazyScript.formHelp.SetupActions()
    local text = "<HTML><BODY>"
    text = text .. "<h1>" .. TAB_LIST_ACTIONS .. "</h1>"
    text = text .. "<p>" .. TAB_ACTIONS_SYNTAX_SPECIFIC_SPELL_RANK .. "</p>"
    text = text .. "<P>|cffff770Caction|r[|cffff770C(rankXX)|r][|cffff770C@&lt;UnitId&gt;|r]</P>"
    text = text .. "<p>" .. TAB_ACTIONS_SYNTAX_SPECIFIC_SPELL_RANK_1 .. "</p>"
    text = text .. "<p>" .. TAB_ACTIONS_GREEN_ACTIONS .. "</p>" .. "<br/>"
    local actionList = {}
    for actionName, actionObj in pairs(lazyScript.actions) do
        local actionNameText = actionName
        if (actionObj.triggersGlobal == false) then
            actionNameText = c.nogcd .. actionNameText .. "    •" .. "|r"
        end
        table.insert(actionList,
            "|cffffffff" .. (lazyScript.actions[actionName]["name"] or lazyScript.actions[actionName]["code"]) ..
                "|r = " .. actionNameText)
    end
    table.sort(actionList)
    text = text .. h2 .. TAB_FULL_SHORT_NAME .. h2c
    text = text .. "<P>" .. table.concat(actionList, "</P><P>") .. "</P><BR/>"

    actionList = {}
    for actionName, actionObj in pairs(lazyScript.comboActions) do
        local actionNameText = actionName
        if (actionObj.triggersGlobal == false) then
            actionNameText = c.nogcd .. actionNameText .. "    •" .. "|r"
        end
        table.insert(actionList,
            "|cffffffff" .. (lazyScript.comboActions[actionName]["name"] or lazyScript.comboActions[actionName]["code"]) ..
                "|r = " .. actionNameText)
    end
    table.sort(actionList)
    if table.getn(actionList) then -- >= 1
        text = text .. h2 .. TAB_ACTIONS_COMBO .. h2c
        text = text .. "<P>" .. table.concat(actionList, "</P><P>") .. "</P><BR/>"
    end

    actionList = {}
    for actionName, actionObj in pairs(lazyScript.shapeshift) do
        lazyScript.d("shapeshift iter: " .. tostring(actionName))
        local actionNameText = actionName
        if (actionObj.triggersGlobal == false) then
            actionNameText = c.nogcd .. actionNameText .. "    •" .. "|r"
        end
        table.insert(actionList,
            "|cffffffff" .. (lazyScript.shapeshift[actionName]["name"] or lazyScript.shapeshift[actionName]["code"]) ..
                "|r = " .. actionNameText)
    end
    lazyScript.d("shapeshift actionList size: " .. table.getn(actionList))
    table.sort(actionList) --  why is this empty
    if table.getn(actionList) then -- >= 1
        text = text .. h2 .. TAB_ACTIONS_OTHER .. h2c
        text = text .. "<P>" .. table.concat(actionList, "</P><P>") .. "</P><BR/>"
    end

    actionList = {}
    for actionName, actionObj in pairs(lazyScript.pseudoActions) do
        local actionNameText = actionName
        if (actionObj.triggersGlobal == false) then
            actionNameText = c.nogcd .. actionNameText .. "    •" .. "|r"
        end
        table.insert(actionList,
            "|cffffffff" ..
                (lazyScript.pseudoActions[actionName]["name"] or lazyScript.pseudoActions[actionName]["code"]) ..
                "|r = " .. actionNameText)
    end
    table.sort(actionList)
    if table.getn(actionList) then -- >= 1 
        text = text .. h2 .. TAB_ACTIONS_SPECIAL .. h2c
        text = text .. "<P>" .. table.concat(actionList, "</P><P>") .. "</P><BR/>"
    end

    if (lazyScript.CustomActionHelp) then
        text = text .. lazyScript.CustomLocaleActionHelp()
        text = text .. lazyScript.CustomActionHelp()
    end
    text = text .. "<BR/>" .. h2 .. TAB_ACTIONS_PARAMETERS .. h2c
    text = text .. '<p align="left">'
    text = text .. TAB_ACTIONS_PARAMETERS_1 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_2 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_3 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_4 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_5 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_6 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_7 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_8 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_9 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_10 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_11 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_12 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_13 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_14 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_15 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_16 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_17 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_18 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_19 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_20 .. c.nogcd .. "    •" .. close .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_21 .. c.nogcd .. "    •" .. close .. "</p><BR/>"
    text = text .. h2 .. TAB_ACTIONS_PARAMETERS_22 .. h2c
    text = text .. "<p>" .. TAB_ACTIONS_PARAMETERS_23 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_24 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_25 .. "<BR/>"
    text = text .. TAB_ACTIONS_PARAMETERS_26 .. "</p>"
    text = text .. "</BODY></HTML>"

    -- text = lazyScript.formHelp.ColorizeBrackets(text)
    lazyScript.formHelp.tabHelpText[Actions] = Colorize(text)
end

-- Setup Tab 3
-- ---
function lazyScript.formHelp.SetupCriteria()
    local text = "<HTML><BODY>"
    text = text .. h1 .. TAB_LIST_CRITERIA .. h1c
    text = text .. p
    
        text = text .. TAB_CRITERIA_1 .. br ..br
    
    do
        local TAB_CRITERIA_2 = c.info .. [[• Multiple values within curly braces ({}]].. c.info .. [[) means choose one or more. <BR/>
         • If more than one is chosen, separate them with commas (e.g. ifRace=Human,Gnome) and the criteria will match if any of
        the choices match. <BR/>
         • If a multiple-choice criteria is negated with a "Not" (e.g. ifNotRace=Human,Gnome) then
        the criteria will match only if none of the choices match. <BR/>
        Square brackets []]..c.info..[[ mean the value is optional.]].. c.warning ..[[ <BR/>
         • Do NOT leave the curly braces or square brackets in your form.]]
        text = text .. TAB_CRITERIA_2 .. "<BR/>"
    end
    text = text .. pc .. "<br/>"
    -- Only criteria need special help text

    if (lazyScript.CustomHelp) then
        text = text .. lazyScript.CustomLocaleHelp()
        text = text .. lazyScript.CustomHelp()
    end

    text = text .. "<BR/>" .. h2 .. TAB_CRITERIA_ACTION .. h2c
    text = text .. "<P>-everyXXs</P>"
    text = text .. "<P>-if[Not]{Ctrl,Alt,Shift}Down |cffffff00(" .. TAB_CRITERIA_SEE_NOTE .. " #1)|r</P>"
    text = text .. "<P>-if[Not]Cooldown{&lt;,&gt;}XXs={action1,action2,...}</P>"
    text = text .. "<P>-if[Not]CurrentAction[=action1,action2,...]</P>"
    text = text .. "<P>-if[Not]GlobalCooldown |cffffff00(" .. TAB_CRITERIA_SEE_NOTE .. " #8)</P>"
    text = text .. "<P>-if[Not]History{&lt;,=,&gt;}XX=action</P>"
    text = text .. "<P>-if[Not]HistoryCount{&lt;,=,&gt;}XX=action</P>"
    text = text .. "<P>-if[Not]LastAction=action</P>"
    text = text .. "<P>-if[Not]LastUsed&gt;XXs=action |cffffff00(" .. TAB_CRITERIA_SEE_NOTE .. " #10)|r</P>"
    text = text .. "<P>-if[Not]InCooldown={action1,action2,...}</P>"
    text = text .. "<P>-if[Not]InRange={action1,action2,...} |cffffff00(" .. TAB_CRITERIA_SEE_NOTE .. " #2)|r</P>"
    text = text .. "<P>-if[Not]Timer&gt;XXs=action |cffffff00(" .. TAB_CRITERIA_SEE_NOTE .. " #10)|r</P>"
    text = text .. "<P>-if[Not]Usable={action1,action2,...} |cffffff00(" .. TAB_CRITERIA_SEE_NOTE .. " #7)|r</P><BR/>"
    text = text .. h2 .. TAB_CRITERIA_ATTACK .. h2c
    text = text .. "<P>-if[Not]BehindAttackJustFailed[X[.Y]s] |cffffff00(" .. TAB_CRITERIA_SEE_NOTE .. " #3)|r</P>"
    text = text .. "<P>-if[Not]InFrontAttackJustFailed[X[.Y]s] |cffffff00(" .. TAB_CRITERIA_SEE_NOTE .. " #3)|r</P>"
    text = text .. "<P>-if[Not]OutdoorsAttackJustFailed[X[.Y]s] |cffffff00(" .. TAB_CRITERIA_SEE_NOTE .. " #3)|r</P>"
    text = text .. "<P>-if[Not]Casting</P>"
    text = text .. "<P>-if[Not]Channelling</P>"
    text = text .. "<P>-if[Not]Shooting</P>"
    text = text .. "<P>-if[Not]Wanding</P><BR/>"
    text = text .. h2 .. TAB_CRITERIA_BUFF_DEBUFF .. h2c
    text = text .. "<P>-if[Not]{Buff,Debuff}Duration{&lt;,&gt;}XXs={buff1,buff2,...} |cffffff00(" ..
               TAB_CRITERIA_PLAYER_ONLY .. ")    •|r</P>"
    text = text .. "<P>-if[Not]{Buff,Debuff}TitleDuration{&lt;,&gt;}XXs={buffTitle1,buffTitle2,...} |cffffff00(" ..
               TAB_CRITERIA_SEE_NOTE .. " #4, " .. TAB_CRITERIA_PLAYER_ONLY .. ")|r</P>"
    text = text ..
               "<P>-if[Not][|cff00ffff&lt;UnitId&gt;|r]Has{Buff,Debuff}[{&lt;,=,&gt;}XX]={buff1,buff2,...} |cffffff00(" ..
               TAB_CRITERIA_SEE_NOTES .. " #5 " .. TAB_CRITERIA_AND .. " #9)|r</P>"
    text = text ..
               "<P>-if[Not][|cff00ffff&lt;UnitId&gt;|r]Has{Buff,Debuff}Title[{&lt;,=,&gt;}XX]={buffTitle1,buffTitle2,...} |cffffff00(" ..
               TAB_CRITERIA_SEE_NOTES .. " #4, #5, " .. TAB_CRITERIA_AND .. " #9)|r</P>"
    text = text ..
               "<P>-if[Not][|cff00ffff&lt;UnitId&gt;|r]Is={Asleep, Bleeding, CCd, Charmed, Cursed, Diseased, Disoriented, Dotted, Drinking, Eating, Feared, Immobile, Incapacitated, Magicked, Poisoned, Polymorphed, Slowed, Stunned, Stung} |cffffff00(" ..
               TAB_CRITERIA_SEE_NOTE .. " #9)|r</P>"
    text = text .. "<P>-if[Not]{MainHand, OffHand}Buffed</P><BR/>"
    text = text .. h2 .. TAB_CRITERIA_ITEM .. h2c
    text = text .. "<P>-if[Not]ItemCooldown{&lt;,&gt;}XXs={item1,item2,...}</P>"
    text = text .. "<P>-if[Not]ItemInCooldown={item1,item2,...}</P><BR/>"
    text = text .. h2 .. TAB_CRITERIA_PLAYER .. h2c
    text = text .. "<P>-if[Not]Dueling</P>"
    text = text .. "<P>-if[Not]Equipped=item</P>"
    text = text .. "<P>-if[Not]Ganked</P>"
    text = text .. "<P>-if[Not]InGroup |cffffff00(" .. TAB_CRITERIA_PARTY_OR_RAID .. ")|r</P>"
    text = text .. "<P>-if[Not]InInstance</P>"
    text = text .. "<P>-if[Not]InBattleground</P>"
    text = text .. "<P>-if[Not]InRaid</P>"
    text = text .. "<P>-if[Not]Mounted</P>"
    text = text .. "<P>-if[Not]Shadowmelded</P>"
    text = text .. "<P>-if[Not]Tracking={Herbs, Minerals, Treasure}</P>"
    text = text .. "<P>-if[{&lt;,=,&gt;}]XAttackers |cffffff00(" .. TAB_CRITERIA_PVP_ONLY .. ")|r</P>"
    text = text .. "<P>-if[Not]Zone=zonename</P><BR/>"
    text = text .. h2 .. TAB_CRITERIA_PET .. h2c
    text = text .. "<P>-if[Not]HasPet</P>"
    text = text .. "<P>-if[Not]PetAlive</P>"
    text = text .. "<P>-if[Not]Pet{Attacking, Following, Staying, Aggressive, Defensive, Passive}</P>"
    text = text ..
               "<P>-if[Not]PetFamily={Bat, Bear, Boar, Carrion Bird, Cat, Crab, Crocolisk, Doomguard, Felhunter, Gorilla, Hyena, Imp, Infernal, Owl, Raptor, Scorpid, Spider, Succubus, Tallstrider, Turtle, Voidwalker, Windserpent, Wolf}</P>"
    text = text .. "<P>-if[Not]PetName=name</P><BR/>"
    text = text .. h2 .. TAB_CRITERIA_PARTY_PET_TARGET .. h2c
    text = text .. "<P>-if[Not]{[Player],Target}{Blocked, Dodged, Parried, Resisted}[{&lt;,&gt;}XX.XXs] |cffffff00(" ..
               TAB_CRITERIA_DEFAULT .. TAB_CRITERIA_SEE_NOTE .. " #11)|r</P>"
    text = text .. "<P>-if[Not]{[Player],Target}FlaggedPVP</P>"
    text = text .. "<P>-if[Not]{[Player],Target}FlagRunner</P>"
    text = text .. "<P>-if[Not]{[Player],Pet,Target}InCombat</P>"
    text = text ..
               "<P>-if[|cff00ffff&lt;UnitId&gt;|r]{&lt;,=,&gt;}XX[%]{hp,mana/energy/rage/focus}[Deficit] |cffffff00(" ..
               TAB_CRITERIA_SEE_NOTE .. " #9)|r</P>"
    text = text ..
               "<P>-if[Not]{[Player],Target}Race={Human, Night Elf, Gnome, Dwarf, Orc, Scourge/Undead, Tauren, Troll}</P>"
    text = text ..
               "<P>-if[Not]PartyHaveClass={Druid, Hunder, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior}</P><BR/>"
    text = text .. h2 .. TAB_CRITERIA_TARGET .. h2c
    text = text .. "<P>-if[Not]CanDebuff</P>"
    text = text .. "<P>-if[Not]HaveTarget</P>"
    text = text .. "<P>-if[Not]TargetAlive</P>"
    text = text .. "<P>-if[Not]TargetAttackable</P>"
    text = text .. "<P>-if[Not]TargetBoss</P>"
    text = text .. "<P>-if[Not]TargetClass={Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior}</P>"
    text = text .. "<P>-if[Not]TargetElite</P>"
    text = text .. "<P>-if[Not]TargetEnemy</P>"
    text = text .. "<P>-if[Not]TargetFleeing |cffffff00(" .. TAB_CRITERIA_NPC_ONLY .. ")|r</P>"
    text = text .. "<P>-if[Not]TargetFriend</P>"
    text = text .. "<P>-if[Not]TargetHasTarget</P>"
    text = text .. "<P>-if[Not]TargetHostile</P>"
    text = text .. "<P>-if[Not]TargetIsCasting[={name regex,FIRE,FROST,NATURE,SHADOW,ARCANE,HOLY}]</P>"
    text = text .. "<P>-if[Not]TargetImmune[=action]</P>"
    text = text .. "<P>-if[Not]TargetInBlindRange |cffffff00(" .. TAB_CRITERIA_WITHIN .. " 10 " .. TAB_CRITERIA_YARDS ..
               ")|r</P>"
    text = text .. "<P>-if[Not]TargetInLongRange |cffffff00(" .. TAB_CRITERIA_WITHIN .. " 28 " .. TAB_CRITERIA_YARDS ..
               ")|r</P>"
    text =
        text .. "<P>-if[Not]TargetInMediumRange |cffffff00(" .. TAB_CRITERIA_WITHIN .. " 10 " .. TAB_CRITERIA_YARDS ..
            ")|r</P>"
    text = text .. "<P>-if[Not]TargetInMeleeRange |cffffff00(" .. TAB_CRITERIA_SEE_NOTE .. " #6)|r</P>"
    text = text .. "<P>-if[Not]TargetLevel{&lt;,=,&gt;}XX |cffffff00(" .. TAB_CRITERIA_NOT_WORK_BOSS .. ")|r</P>"
    text = text .. "<P>-if[Not]TargetMyLevel{&lt;,=,&gt;}{plus,minus}XX |cffffff00(" .. TAB_CRITERIA_NOT_WORK_BOSS ..
               ")|r</P>"
    text = text .. "<P>-if[Not]TargetNamed={regex1,regex2,...}</P>"
    text = text .. "<P>-if[Not]TargetNPC</P>"
    text = text .. "<P>-if[Not]TargetOfTarget</P>"
    text = text ..
               "<P>-if[Not]TargetOfTargetClass={Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior}</P>"
    text = text .. "<P>-if[Not]TargetTrivial</P>"
    text = text .. "<P>-if[Not]TargetType={Beast, Critter, Demon, Dragonkin, Elemental, Humanoid, Undead}</P>"
    text = text .. "<P>-ifTimeToDeath{&lt;,=,&gt;}XXs</P>"
    text = text .. "<P>-if[Not]UnitExists=[|cff00ffff&lt;UnitId&gt;|r]</P><BR/>"
    text = text .. "<p>"
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_1
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_2
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_3
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_4
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_5
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_6
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_7
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_8
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_8_CLASSES
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_9
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_10
    text = text .. "<BR/>" .. TAB_CRITERIA_CUSTOM_HELP_11
    text = text .. "<BR/></p></BODY></HTML>"

    -- text = lazyScript.formHelp.ColorizeBrackets(text)

    lazyScript.formHelp.tabHelpText[Criteria] = Colorize(text)
end

function lazyScript.formHelp.SetupBuffsDebuffs()
    local text = "<HTML><BODY>"
    text = text .. h1 .. TAB_LIST_BUFFS_DEBUFFS .. h1c
    text = text .. p .. TAB_BUFFS_DEBUFFS_USED .. pc
    text = text .. br .. h2 .. TAB_FULL_SHORT_NAME .. h2c
    local buffList = {}
    for buffName in pairs(lazyScript.buffTable) do
        table.insert(buffList,
            "|cffffffff" .. lazyScript.safeString(lazyScript.buffTable[buffName]["name"]) .. "|r = " .. buffName)
    end
    table.sort(buffList)

    text = text .. "<P>" .. table.concat(buffList, "</P><P>") .. "</P>"
    text = text .. "<BR/></BODY></HTML>"

    lazyScript.formHelp.tabHelpText[Buffs_Debuffs] = Colorize(text)
end

function lazyScript.formHelp.SetupHelpText()
    lazyScript.formHelp.SetupOverview()
    lazyScript.formHelp.SetupActions()
    lazyScript.formHelp.SetupCriteria()
    lazyScript.formHelp.SetupBuffsDebuffs()
    lazyScript.formHelp.SetupExtras() -- new

end

if not lazyScript.formHelp.tabHelpText[tabName] then
    lazyScript.formHelp.SetupHelpText()
end

-- LazyScriptFormHelp:Show() -- open help form on load(testing)
LazyScriptFormHelpScrollFrameScrollChildText:SetScript("OnHyperlinkClick", function(self, link, text, button)
    if link and string.sub(link, 1, 10) == "playsound:" then
        local soundName = string.sub(link, 11)

        -- DEBUG: Check exact string formatting in Chat Frame
        lazyScript.p("Attempting sound: '" .. tostring(soundName) .. "'")

        -- Try playing as a sound event name:
        PlaySound(soundName)

        -- Try playing as a file path (fallback):
        PlaySoundFile(soundName)
    end
end)
