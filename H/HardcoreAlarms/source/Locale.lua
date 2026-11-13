local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:NewLocale("HardcoreAlarms", "enUS", true)
if L then
    -- warnings
    L["WARNING"] = "Warning!"
    L["PANIC_WARNING"] = "PANIC WARNING!"
    L["PLAYER_PVP_WARN"] = "You are flagged for PvP!"
    L["HP_WARN"] = "Health LOW!"
    L["HP_PANIC"] = "Health CRITICAL!"
    L["PET_HP_WARN"] = "Pet's Health LOW!"
    L["PET_HP_PANIC"] = "Pet's Health CRITICAL!"
    L["BREATH_WARN_FMT"] = "Only %.0fs of breath!"
    L["OUT_OF_BREATH"] = "OUT OF BREATH!"
    L["TARGET_WARNTITLE"] = "Dangerous target!"
    L["TARGET_WARN_ELITE"] = "Elite enemy!"
    L["TARGET_WARN_HIGHLVL"] = "High level enemy!"
    L["TARGET_WARN_ENEMYPVPPLAYER"] = "Enemy player flagged for PVP!"
    L["TARGET_WARN_ENEMYPVPTARGET"] = "Enemy flagged for PVP!"
    L["TARGET_WARN_4966"] = "Accepting the quest \"The Missing Diplomat\" can easily kill you! You will instantly get ambushed by tough enemies" -- Unit name: Private Hendel
    L["TARGET_WARN_4191"] = "This unit is not actually dangerous. It's just a test." -- Unit name: Allyndia
    L["QUEST_WARNTITLE"] = "Dangerous Quest: "
    local quest_warnescort = "Spawn waves during escort can easily overwhelm you."
    L["QUEST_WARNESCORT"] = quest_warnescort
    local quest_warntightspace = "Lots of dangerous enemies in a tight space."
    L["QUEST_WARNTIGHTSPACE"] = quest_warntightspace
    L["QUEST_WARN_3909"] = "Drinking the Videre Elixir will instantly kill you." -- Quest title: The Videre Elixir
    L["QUEST_WARN_7843"] = "You will be PVP-flagged when the spear is placed. High level guards are nearby." -- Quest title: The final message to the Wildhammer
    L["QUEST_WARN_1380"] = "Spawn waves can easily overwhelm you. No easy escape either." -- Quest title:  Khan Hratha
    L["QUEST_WARN_6132"] = quest_warnescort -- Quest title: Get me out of here!
    L["QUEST_WARN_552"] = "The location where you turn this quest in is right next to high level guards." -- Quest title: Helcular's Revenge
    L["QUEST_WARN_976"] = quest_warnescort -- Quest title: Supplies to Auberdine
    L["QUEST_WARN_685"] = quest_warntightspace -- Quest title: Wanted Otto and Falconrest
    L["QUEST_WARN_348"] = quest_warntightspace -- Quest title: Stranglethorn Fever
    L["QUEST_WARN_4971"] = "Three parasites will instantly spawn on you at once. Killing parasites can spawn more parasites." -- Quest title: A matter of time
    L["QUEST_WARN_1150"] = quest_warntightspace -- Quest title: Test of Endurance
    L["QUEST_WARN_1090"] = quest_warntightspace -- Quest title: Gerenzo's Orders
    L["QUEST_WARN_1126"] = quest_warntightspace -- Quest title: Hive in the tower
    L["QUEST_WARN_4507"] = quest_warntightspace -- Quest title: Pawn captures Queen
    L["QUEST_WARN_217"] = "Three tough enemies at once in a tight space." -- Quest title: In defense of the king's lands
    L["QUEST_WARN_6134"] = "Once placed, stay away from the magnet to avoid getting swarmed. Magnet will turn neutral enemies hostile." -- Quest title: Ghost-o-plasm round up
    L["QUEST_WARN_5781"] = "Clicking on the grave will spawn four enemies at once." -- Quest title: Of forgotten memories
    L["QUEST_WARN_3566"] = "Tough elite enemies and mini-boss." -- Quest title: Rise Obsidion!
    L["QUEST_WARN_608"] = "The last quest in this chain is dangerous. " .. quest_warntightspace -- Quest title: The Bloodsail Buccaneers
    L["QUEST_WARN_2359"] = "Enemies are very tough and deal a lot of damage when you get caught." -- Quest title: Klaven's Tower
    L["QUEST_WARN_2381"] = "The parrot that spawns is level 55. Use the quest item to make it killable." -- Quest title: Plundering the plunderers
    L["QUEST_WARN_408"] = quest_warntightspace -- Quest title: Family crypt
    L["QUEST_WARN_1001"] = "This quest is not actually dangerous. It's just a test. Ignore this: " .. quest_warntightspace -- Quest title: Buzzbox 411
    L["TEST_WARN_TITLE"] = "Movable test warning"
    L["TEST_WARN_TEXT"] = "No warning whatsoever! Everything is chill. Promise. This is a test. For real. Don't panic!"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP"] = "Close warning window"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP_TEXT"] = "Shift-click to ignore the warning for this unit permanently."
    L["UNITSCAN_CHAT_MESSAGE"] = "Unitscan found a dangerous target:"
    L["UNITSCAN_WARNTITLE"] = "Danger nearby:"

    -- options
    L["OPT_DESCRIPTION_TOP_TITLE"] = "Info"
    L["OPT_DESCRIPTION_TOP"] = "Configurable Alarms for Low HP, out of breath, dangerous quests and enemies.\n\nYou can easily extend the list of dangerous quests and units yourself. More details in the README file in your addon folder.\nThis addon is free and open-source under GPLv3. This means you may use, modify, and distribute this project, but any changes you release must be licensed under GPLv3 and include the source code.\n\nHave fun and take care out there!"

    L["OPT_INFO"] = "All changes are instantly applied and saved."

    L["OPT_TEXT"] = "Text"
    L["OPT_FLASHING_SCREEN"] = "Flashing screen"
    L["OPT_SOUND"] = "Sound"
    L["OPT_SOUND_OFF"] = "Off"
    L["OPT_SOUND_ONCE"] = "Once"
    L["OPT_SOUND_REPEATING"] = "Repeating"

    L["OPT_MINIMAP_ICON"] = "Minimap Icon"
    L["OPT_SHOW_MINIMAP"] = "Show Minimap Icon"

    L["OPT_UI"] = "User interface"
    L["OPT_MOVABLE"] = "Make UI movable"
    L["OPT_MOVABLE_DESC"] = "Adjust the position of warnings by dragging them. Disable when you're done."
    L["OPT_WARN_STYLE"] = "Warning style"
    L["OPT_WARN_STYLE_DESC"] = "How do you want the warning to look like?"
    L["OPT_WARN_STYLE_BORDER_BG"] = "Border and background"
    L["OPT_WARN_STYLE_ONLY_BG"] = "Only background"
    L["OPT_WARN_STYLE_ONLY_TEXT"] = "Only text"

    L["OPT_WARN_PREF"] = "Warning preference"
    L["OPT_BREATH_WARN"] = "Breath warning"
    L["OPT_BREATH_WARN_DESC"] = "Changes how to warn you when running out of breath."
    L["OPT_HP_WARN"] = "Health warning"
    L["OPT_HP_WARN_DESC"] = "Changes how to warn you when you have low hp."
    L["OPT_PET_HP_WARN"] = "Pet's Health warning"
    L["OPT_PET_HP_WARN_DESC"] = "Changes how to warn you when your pet has low hp."
    L["OPT_DANG_TARGET_WARN"] = "Dangerous target warning"
    L["OPT_DANG_TARGET_WARN_DESC"] = "Changes how to warn you when targeting a normal target (usually high level)."
    L["OPT_DANG_ELITE_WARN"] = "Dangerous Elite target warning"
    L["OPT_DANG_ELITE_WARN_DESC"] = "Changes how to warn you when targeting an elite target."
    L["OPT_DANG_PVP_WARN"] = "Enemy PvP-Player target warning"
    L["OPT_DANG_PVP_WARN_DESC"] = "Changes how to warn you when targeting an enemy player that is flagged for PvP."
    L["OPT_SELF_PVP_WARN"] = "\"You are flagged for PvP\"-warning"
    L["OPT_SELF_PVP_WARN_DESC"] = "Changes how to warn you when you are flagged for PvP."
    L["OPT_QUEST_WARN"] = "Dangerous quest warning"
    L["OPT_QUEST_WARN_DESC"] = "Changes how to warn you when a dangerous quest comes up."
    L["OPT_UNITSCAN_WARN"] = "Nearby targets warning"
    L["OPT_UNITSCAN_WARN_DESC"] = "Changes how to warn you when a dangerous target has been found nearby."

    L["OPT_THRESHOLDS"] = "Thresholds"
    L["OPT_BREATH_LOW"] = "Breath low (seconds left)"
    L["OPT_BREATH_WARN_SEC"] = "Warning (seconds)"
    L["OPT_BREATH_WARN_SEC_DESC"] = "At what amount of breath left the normal warning should be shown"
    L["OPT_BREATH_PANIC_SEC"] = "Panic (seconds)"
    L["OPT_BREATH_PANIC_SEC_DESC"] = "At what amount of breath left the panic warning should be shown"

    L["OPT_HP_LOW"] = "HP low (in %)"
    L["OPT_HP_WARN_PCT"] = "Warning (%)"
    L["OPT_HP_WARN_PCT_DESC"] = "At what health percentage the normal warning should be shown"
    L["OPT_HP_PANIC_PCT"] = "Panic (%)"
    L["OPT_HP_PANIC_PCT_DESC"] = "At what health percentage the panic warning should be shown"
    L["OPT_PET_HP_LOW"] = "Pet's HP low (in %)"

    L["OPT_LEVEL_DIFF"] = "Level Difference (between you and your target)"
    L["OPT_LEVELDIFF_NORMAL"] = "Normal Target Warning"
    L["OPT_LEVELDIFF_NORMAL_DESC"] = "At what level difference between you and your target(normal) the normal warning should be shown"
    L["OPT_LEVELDIFF_ELITE"] = "Elite Target Warning"
    L["OPT_LEVELDIFF_ELITE_DESC"] = "At what level difference between you and your target(elite) the normal warning should be shown"
    L["OPT_LEVELDIFF_UNITSCAN"] = "Nearby Target Warning"
    L["OPT_LEVELDIFF_UNITSCAN_DESC"] = "All units below this level difference between you and your target will be ignored, when scanning for nearby dangerous targets."

    L["OPT_UNITSCAN"] = "Scan nearby targets"
    L["OPT_UNITSCAN_DESC"] = "When scanning for units during combat, some minor issues might occur, like your auto-attack being interrupted. This is due to limitations with WoW's API. If you enable 'scan in combat', make sure to also enable 'Attack on assist' in your interface options so that your melee auto-attack won't be interrupted!"
    L["OPT_UNITSCAN_ENABLE"] = "Enable scans"
    L["OPT_UNITSCAN_ENABLE_DESC"] = "Enable scanning of the vicinity every couple of seconds to check for dangerous targets."
    L["OPT_UNITSCAN_ENABLE_COMBAT"] = "Scan during combat"
    L["OPT_UNITSCAN_ENABLE_COMBAT_DESC"] = "Scanning will continue during combat. Make sure to enable 'Attack on assist' in your interface options!"

    L["OPT_DEBUG"] = "Debug (ignore for normal use)"
    L["OPT_DEBUG_OUTPUT"] = "Debug output"
    L["OPT_DEBUG_OUTPUT_DESC"] = "Enable debug output"
    L["OPT_CHECK_LOOP_INT"] = "Check Loop Interval (seconds)"
    L["OPT_CHECK_LOOP_INT_DESC"] = "Default is fine. Only change when you have performance problems."

    L["OPT_CLEAR_IGNORED"] = "Clear ignored warnings"
    L["OPT_CLEAR_IGNORED_DESC"] = "Reset the list of everything that you have dismissed/ignored permanently. Like warnings for particular quests or units."
end

local L = AceLocale:NewLocale("HardcoreAlarms", "deDE")
if L then
    -- warnings
    L["WARNING"] = "Warnung!"
    L["PANIC_WARNING"] = "PANIKWARNUNG!"
    L["PLAYER_PVP_WARN"] = "Du bist für PvP markiert!"
    L["HP_WARN"] = "Gesundheit NIEDRIG!"
    L["HP_PANIC"] = "Gesundheit KRITISCH!"
    L["PET_HP_WARN"] = "Begleitergesundheit NIEDRIG!"
    L["PET_HP_PANIC"] = "Begleitergesundheit KRITISCH!"
    L["BREATH_WARN_FMT"] = "Nur noch %.0fs Atem!"
    L["OUT_OF_BREATH"] = "KEIN ATEM MEHR!"
    L["TARGET_WARNTITLE"] = "Gefährliches Ziel!"
    L["TARGET_WARN_ELITE"] = "Elitegegner!"
    L["TARGET_WARN_HIGHLVL"] = "Gegner hohen Levels!"
    L["TARGET_WARN_ENEMYPVPPLAYER"] = "Gegnerischer Spieler für PvP markiert!"
    L["TARGET_WARN_ENEMYPVPTARGET"] = "Gegner für PvP markiert!"
    L["TARGET_WARN_4966"] = "Das Annehmen der Quest \"The Missing Diplomat\" kann dich leicht töten! Du wirst sofort von starken Gegnern überfallen." -- Unit name: Private Hendel
    L["TARGET_WARN_4191"] = "Diese Einheit ist nicht wirklich gefährlich. Sie ist nur ein Test." -- Unit name: Allyndia
    L["QUEST_WARNTITLE"] = "Gefährliche Quest: "
    local quest_warnescort = "Wellen von Gegnern während einer Eskorte können dich leicht überwältigen."
    L["QUEST_WARNESCORT"] = quest_warnescort
    local quest_warntightspace = "Viele gefährliche Feinde auf engem Raum."
    L["QUEST_WARNTIGHTSPACE"] = quest_warntightspace
    L["QUEST_WARN_3909"] = "Das Trinken des Videre-Elixiers tötet dich sofort." -- Quest title: The Videre Elixir
    L["QUEST_WARN_7843"] = "Du wirst PvP-markiert, wenn der Speer platziert wird. Hochstufige Wachen sind in der Nähe." -- Quest title: The final message to the Wildhammer
    L["QUEST_WARN_1380"] = "Spawn-Wellen können dich leicht überwältigen. Keine einfache Fluchtmöglichkeit." -- Quest title:  Khan Hratha
    L["QUEST_WARN_6132"] = quest_warnescort -- Quest title: Get me out of here!
    L["QUEST_WARN_552"] = "Der Ort, an dem du diese Quest abgibst, liegt direkt neben hochstufigen Wachen." -- Quest title: Helcular's Revenge
    L["QUEST_WARN_976"] = quest_warnescort -- Quest title: Supplies to Auberdine
    L["QUEST_WARN_685"] = quest_warntightspace -- Quest title: Wanted Otto and Falconrest
    L["QUEST_WARN_348"] = quest_warntightspace -- Quest title: Stranglethorn Fever
    L["QUEST_WARN_4971"] = "Drei Parasiten spawnen sofort gleichzeitig auf dir. Das Töten von Parasiten kann weitere Parasiten hervorrufen." -- Quest title: A matter of time
    L["QUEST_WARN_1150"] = quest_warntightspace -- Quest title: Test of Endurance
    L["QUEST_WARN_1090"] = quest_warntightspace -- Quest title: Gerenzo's Orders
    L["QUEST_WARN_1126"] = quest_warntightspace -- Quest title: Hive in the tower
    L["QUEST_WARN_4507"] = quest_warntightspace -- Quest title: Pawn captures Queen
    L["QUEST_WARN_217"] = "Drei starke Gegner gleichzeitig auf engem Raum." -- Quest title: In defense of the king's lands
    L["QUEST_WARN_6134"] = "Sobald du ihn platziert hast, halte Abstand zum Magneten, um zu vermeiden, dass du überwältigt wirst. Der Magnet macht neutrale Gegner feindlich." -- Quest title: Ghost-o-plasm round up
    L["QUEST_WARN_5781"] = "Das Anklicken des Grabes beschwört vier Gegner auf einmal." -- Quest title: Of forgotten memories
    L["QUEST_WARN_3566"] = "Starke Elitegegner und ein Mini-Boss." -- Quest title: Rise Obsidion!
    L["QUEST_WARN_608"] = "Die letzte Quest dieser Kette ist gefährlich. " .. quest_warntightspace -- Quest title: The Bloodsail Buccaneers
    L["QUEST_WARN_2359"] = "Gegner sind sehr stark und verursachen viel Schaden, wenn du erwischt wirst." -- Quest title: Klaven's Tower
    L["QUEST_WARN_2381"] = "Der gespawnte Papagei ist Level 55. Benutze den Questgegenstand, damit er tötbar wird." -- Quest title: Plundering the plunderers
    L["QUEST_WARN_408"] = quest_warntightspace -- Quest title: Family crypt
    L["QUEST_WARN_1001"] = "Diese Quest ist nicht wirklich gefährlich. Sie ist nur ein Test. Ignoriere dies: " .. quest_warntightspace -- Quest title: Buzzbox 411
    L["TEST_WARN_TITLE"] = "Verschiebbare Testwarnung"
    L["TEST_WARN_TEXT"] = "Überhaupt keine Warnung! Alles entspannt. Versprochen. Dies ist ein Test. Wirklich. Keine Panik!"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP"] = "Warnfenster schließen"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP_TEXT"] = "Umschalt-Klick, um die Warnung für diese Einheit dauerhaft zu ignorieren."
    L["UNITSCAN_CHAT_MESSAGE"] = "Unitscan hat ein gefährliches Ziel gefunden:"
    L["UNITSCAN_WARNTITLE"] = "Gefahr in der Nähe:"
    
    -- options
    L["OPT_DESCRIPTION_TOP_TITLE"] = "Info"
    L["OPT_DESCRIPTION_TOP"] = "Konfigurierbare Alarme für niedrige HP, außer Atem, gefährliche Quests und Gegner.\n\nDu kannst die Liste gefährlicher Quests und Einheiten selbst leicht erweitern. Mehr Details findest du in der README-Datei in deinem Addon-Ordner.\nDieses Addon ist kostenlos und Open-Source unter GPLv3. Das bedeutet, du kannst dieses Projekt verwenden, ändern und verbreiten, aber alle Änderungen, die du veröffentlichst, müssen unter GPLv3 lizenziert sein und den Quellcode enthalten.\n\nViel Spaß und pass auf dich auf!"

    L["OPT_INFO"] = "Alle Änderungen werden sofort übernommen und gespeichert."
    
    L["OPT_TEXT"] = "Text"
    L["OPT_FLASHING_SCREEN"] = "Blinkender Bildschirm"
    L["OPT_SOUND"] = "Sound"
    L["OPT_SOUND_OFF"] = "Aus"
    L["OPT_SOUND_ONCE"] = "Einmal"
    L["OPT_SOUND_REPEATING"] = "Wiederholt"
    
    L["OPT_MINIMAP_ICON"] = "Minikarten-Symbol"
    L["OPT_SHOW_MINIMAP"] = "Minikarten-Symbol anzeigen"
    
    L["OPT_UI"] = "Benutzeroberfläche"
    L["OPT_MOVABLE"] = "UI verschiebbar machen"
    L["OPT_MOVABLE_DESC"] = "Position der Warnungen per Drag verschieben. Deaktiviere, wenn du fertig bist."
    L["OPT_WARN_STYLE"] = "Warnstil"
    L["OPT_WARN_STYLE_DESC"] = "Wie soll die Warnung aussehen?"
    L["OPT_WARN_STYLE_BORDER_BG"] = "Rahmen und Hintergrund"
    L["OPT_WARN_STYLE_ONLY_BG"] = "Nur Hintergrund"
    L["OPT_WARN_STYLE_ONLY_TEXT"] = "Nur Text"
    
    L["OPT_WARN_PREF"] = "Warnpräferenz"
    L["OPT_BREATH_WARN"] = "Atemwarnung"
    L["OPT_BREATH_WARN_DESC"] = "Ändert, wie du gewarnt wirst, wenn dir die Luft ausgeht."
    L["OPT_HP_WARN"] = "Gesundheitswarnung"
    L["OPT_HP_WARN_DESC"] = "Ändert, wie du gewarnt wirst, wenn deine HP niedrig sind."
    L["OPT_PET_HP_WARN"] = "Gesundheitswarnung des Begleiters"
    L["OPT_PET_HP_WARN_DESC"] = "Ändert, wie du gewarnt wirst, wenn die HP deines Begleiters niedrig sind."
    L["OPT_DANG_TARGET_WARN"] = "Warnung vor gefährlichem Ziel"
    L["OPT_DANG_TARGET_WARN_DESC"] = "Ändert, wie du gewarnt wirst, wenn du ein normales (meist hochstufiges) Ziel anvisierst."
    L["OPT_DANG_ELITE_WARN"] = "Warnung vor gefährlichem Eliteziel"
    L["OPT_DANG_ELITE_WARN_DESC"] = "Ändert, wie du gewarnt wirst, wenn du ein Eliteziel anvisierst."
    L["OPT_DANG_PVP_WARN"] = "Warnung: feindlicher PvP-Spieler"
    L["OPT_DANG_PVP_WARN_DESC"] = "Ändert, wie du gewarnt wirst, wenn du einen feindlichen Spieler anvisierst, der für PvP markiert ist."
    L["OPT_SELF_PVP_WARN"] = "\"Du bist für PvP markiert\"-Warnung"
    L["OPT_SELF_PVP_WARN_DESC"] = "Ändert, wie du gewarnt wirst, wenn du selbst für PvP markiert bist."
    L["OPT_QUEST_WARN"] = "Warnung vor gefährlichen Quests"
    L["OPT_QUEST_WARN_DESC"] = "Ändert, wie du gewarnt wirst, wenn eine gefährliche Quest auftaucht."
    L["OPT_UNITSCAN_WARN"] = "Warnung vor Zielen in der Nähe"
    L["OPT_UNITSCAN_WARN_DESC"] = "Ändert, wie du gewarnt wirst, wenn in der Nähe ein gefährliches Ziel gefunden wurde."
    
    L["OPT_THRESHOLDS"] = "Schwellenwerte"
    L["OPT_BREATH_LOW"] = "Atem niedrig (verbleibende Sekunden)"
    L["OPT_BREATH_WARN_SEC"] = "Warnung (Sekunden)"
    L["OPT_BREATH_WARN_SEC_DESC"] = "Bei wie vielen verbleibenden Sekunden Atem die normale Warnung angezeigt werden soll"
    L["OPT_BREATH_PANIC_SEC"] = "Panik (Sekunden)"
    L["OPT_BREATH_PANIC_SEC_DESC"] = "Bei wie vielen verbleibenden Sekunden Atem die Panikwarnung angezeigt werden soll"
    
    L["OPT_HP_LOW"] = "HP niedrig (in %)"
    L["OPT_HP_WARN_PCT"] = "Warnung (%)"
    L["OPT_HP_WARN_PCT_DESC"] = "Bei welchem Gesundheitsprozentsatz die normale Warnung angezeigt werden soll"
    L["OPT_HP_PANIC_PCT"] = "Panik (%)"
    L["OPT_HP_PANIC_PCT_DESC"] = "Bei welchem Gesundheitsprozentsatz die Panikwarnung angezeigt werden soll"
    L["OPT_PET_HP_LOW"] = "HP des Begleiters niedrig (in %)"
    
    L["OPT_LEVEL_DIFF"] = "Levelunterschied (zwischen dir und deinem Ziel)"
    L["OPT_LEVELDIFF_NORMAL"] = "Warnung für normales Ziel"
    L["OPT_LEVELDIFF_NORMAL_DESC"] = "Bei welchem Levelunterschied zwischen dir und deinem (normalen) Ziel die normale Warnung angezeigt werden soll"
    L["OPT_LEVELDIFF_ELITE"] = "Warnung für Eliteziel"
    L["OPT_LEVELDIFF_ELITE_DESC"] = "Bei welchem Levelunterschied zwischen dir und deinem (Elite-)Ziel die normale Warnung angezeigt werden soll"
    L["OPT_LEVELDIFF_UNITSCAN"] = "Warnung für nahe Ziele"
    L["OPT_LEVELDIFF_UNITSCAN_DESC"] = "Alle Einheiten unterhalb dieses Levelunterschieds zwischen dir und dem Ziel werden beim Scannen nach gefährlichen Zielen ignoriert."

    L["OPT_UNITSCAN"] = "Nahe Ziele scannen"
    L["OPT_UNITSCAN_DESC"] = "Beim Scannen von Einheiten während des Kampfes können kleinere Probleme auftreten, z. B. dass dein Auto-Angriff unterbrochen wird. Das liegt an Beschränkungen der WoW-API. Wenn du 'während des Kampfes scannen' aktivierst, aktiviere in den Interface-Optionen auch 'Angriff bei Assist', damit dein Nahkampfangriff nicht unterbrochen wird!"
    L["OPT_UNITSCAN_ENABLE"] = "Scans aktivieren"
    L["OPT_UNITSCAN_ENABLE_DESC"] = "Aktiviere das Scannen der Umgebung alle paar Sekunden, um nach gefährlichen Zielen zu suchen."
    L["OPT_UNITSCAN_ENABLE_COMBAT"] = "Während des Kampfes scannen"
    L["OPT_UNITSCAN_ENABLE_COMBAT_DESC"] = "Das Scannen wird auch während des Kampfes fortgesetzt. Aktiviere in den Interface-Optionen 'Angriff bei Assist'!"

    L["OPT_DEBUG"] = "Debug (für normalen Gebrauch ignorieren)"
    L["OPT_DEBUG_OUTPUT"] = "Debug-Ausgabe"
    L["OPT_DEBUG_OUTPUT_DESC"] = "Debug-Ausgabe aktivieren"
    L["OPT_CHECK_LOOP_INT"] = "Prüfintervall (Sekunden)"
    L["OPT_CHECK_LOOP_INT_DESC"] = "Standard ist in Ordnung. Nur ändern, wenn du Performance-Probleme hast."
    
    L["OPT_CLEAR_IGNORED"] = "Ignorierte Warnungen löschen"
    L["OPT_CLEAR_IGNORED_DESC"] = "Setzt die Liste aller permanent ausgeblendeten/ignorierten Warnungen zurück. Zum Beispiel Warnungen für bestimmte Quests oder Einheiten."
end

local L = AceLocale:NewLocale("HardcoreAlarms", "esES")
if L then
    -- warnings
    L["WARNING"] = "¡Advertencia!"
    L["PANIC_WARNING"] = "¡ADVERTENCIA DE PÁNICO!"
    L["PLAYER_PVP_WARN"] = "¡Estás marcado para JcJ!"
    L["HP_WARN"] = "¡Salud BAJA!"
    L["HP_PANIC"] = "¡Salud CRÍTICA!"
    L["PET_HP_WARN"] = "¡Vida de la mascota BAJA!"
    L["PET_HP_PANIC"] = "¡Vida de la mascota CRÍTICA!"
    L["BREATH_WARN_FMT"] = "¡Solo quedan %.0fs de respiración!"
    L["OUT_OF_BREATH"] = "¡SIN ALIENTO!"
    L["TARGET_WARNTITLE"] = "¡Objetivo peligroso!"
    L["TARGET_WARN_ELITE"] = "¡Enemigo élite!"
    L["TARGET_WARN_HIGHLVL"] = "¡Enemigo de nivel alto!"
    L["TARGET_WARN_ENEMYPVPPLAYER"] = "¡Jugador enemigo marcado para JcJ!"
    L["TARGET_WARN_ENEMYPVPTARGET"] = "¡Enemigo marcado para JcJ!"
    L["TARGET_WARN_4966"] = "¡Aceptar la misión \"El diplomático desaparecido\" puede matarte fácilmente! Serás emboscado al instante por enemigos duros"
    L["TARGET_WARN_4191"] = "Esta unidad en realidad no es peligrosa. Es solo una prueba."
    L["QUEST_WARNTITLE"] = "Misión peligrosa: "
    local quest_warnescort = "Oleadas durante la escolta pueden abrumarte fácilmente."
    L["QUEST_WARNESCORT"] = quest_warnescort
    local quest_warntightspace = "Muchos enemigos peligrosos en un espacio reducido."
    L["QUEST_WARNTIGHTSPACE"] = quest_warntightspace
    L["QUEST_WARN_3909"] = "Beber el Elixir Videre te matará al instante."
    L["QUEST_WARN_7843"] = "Serás marcado para JcJ cuando se coloque la lanza. Hay guardias de alto nivel cerca."
    L["QUEST_WARN_1380"] = "Oleadas de aparición pueden abrumarte fácilmente. Tampoco hay escapatoria fácil."
    L["QUEST_WARN_6132"] = quest_warnescort
    L["QUEST_WARN_552"] = "El lugar donde entregas esta misión está justo al lado de guardias de alto nivel."
    L["QUEST_WARN_976"] = quest_warnescort
    L["QUEST_WARN_685"] = quest_warntightspace
    L["QUEST_WARN_348"] = quest_warntightspace
    L["QUEST_WARN_4971"] = "Tres parásitos aparecerán instantáneamente sobre ti a la vez. Matar parásitos puede generar más parásitos."
    L["QUEST_WARN_1150"] = quest_warntightspace
    L["QUEST_WARN_1090"] = quest_warntightspace
    L["QUEST_WARN_1126"] = quest_warntightspace
    L["QUEST_WARN_4507"] = quest_warntightspace
    L["QUEST_WARN_217"] = "Tres enemigos duros a la vez en un espacio reducido."
    L["QUEST_WARN_6134"] = "Una vez colocado, aléjate del imán para evitar ser rodeado. El imán volverá hostiles a enemigos neutrales."
    L["QUEST_WARN_5781"] = "Al hacer clic en la tumba aparecerán cuatro enemigos a la vez."
    L["QUEST_WARN_3566"] = "Enemigos élite duros y mini-jefe."
    L["QUEST_WARN_608"] = "La última misión de esta cadena es peligrosa. " .. quest_warntightspace
    L["QUEST_WARN_2359"] = "Los enemigos son muy duros y hacen mucho daño cuando te atrapan."
    L["QUEST_WARN_2381"] = "El loro que aparece es de nivel 55. Usa el objeto de misión para hacerlo vulnerable."
    L["QUEST_WARN_408"] = quest_warntightspace
    L["QUEST_WARN_1001"] = "Esta misión en realidad no es peligrosa. Es solo una prueba. Ignora esto: " .. quest_warntightspace
    L["TEST_WARN_TITLE"] = "Advertencia de prueba movible"
    L["TEST_WARN_TEXT"] = "¡Ninguna advertencia! Todo está tranquilo. Prometido. Esto es una prueba. De verdad. ¡No te asustes!"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP"] = "Cerrar ventana de advertencia"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP_TEXT"] = "Mayús-clic para ignorar permanentemente la advertencia para esta unidad."
    L["UNITSCAN_CHAT_MESSAGE"] = "Unitscan encontró un objetivo peligroso:"
    L["UNITSCAN_WARNTITLE"] = "Peligro cerca:"

    -- options
    L["OPT_DESCRIPTION_TOP_TITLE"] = "Info"
    L["OPT_DESCRIPTION_TOP"] = "Alarmas configurables para HP bajos, sin aliento, misiones y enemigos peligrosos.\n\nPuedes ampliar fácilmente la lista de misiones y unidades peligrosas tú mismo. Más detalles en el archivo README en la carpeta de tu addon.\nEste addon es gratuito y de código abierto bajo GPLv3. Esto significa que puedes usar, modificar y distribuir este proyecto, pero cualquier cambio que publiques debe estar bajo licencia GPLv3 e incluir el código fuente.\n\n¡Diviértete y cuídate!"

    L["OPT_INFO"] = "Todos los cambios se aplican y guardan al instante."
    
    L["OPT_TEXT"] = "Texto"
    L["OPT_FLASHING_SCREEN"] = "Pantalla intermitente"
    L["OPT_SOUND"] = "Sonido"
    L["OPT_SOUND_OFF"] = "Desactivado"
    L["OPT_SOUND_ONCE"] = "Una vez"
    L["OPT_SOUND_REPEATING"] = "Repetir"
    
    L["OPT_MINIMAP_ICON"] = "Icono del minimapa"
    L["OPT_SHOW_MINIMAP"] = "Mostrar icono del minimapa"
    
    L["OPT_UI"] = "Interfaz"
    L["OPT_MOVABLE"] = "Hacer la interfaz movible"
    L["OPT_MOVABLE_DESC"] = "Ajusta la posición de las advertencias arrastrándolas. Desactívala cuando termines."
    L["OPT_WARN_STYLE"] = "Estilo de advertencia"
    L["OPT_WARN_STYLE_DESC"] = "¿Cómo quieres que se vea la advertencia?"
    L["OPT_WARN_STYLE_BORDER_BG"] = "Borde y fondo"
    L["OPT_WARN_STYLE_ONLY_BG"] = "Solo fondo"
    L["OPT_WARN_STYLE_ONLY_TEXT"] = "Solo texto"
    
    L["OPT_WARN_PREF"] = "Preferencia de advertencia"
    L["OPT_BREATH_WARN"] = "Advertencia de respiración"
    L["OPT_BREATH_WARN_DESC"] = "Cambia cómo avisar cuando te quedas sin respiración."
    L["OPT_HP_WARN"] = "Advertencia de salud"
    L["OPT_HP_WARN_DESC"] = "Cambia cómo avisar cuando tienes poca salud."
    L["OPT_PET_HP_WARN"] = "Alerta de vida de la mascota"
    L["OPT_PET_HP_WARN_DESC"] = "Cambia cómo se te avisa cuando la mascota tiene poca vida."
    L["OPT_DANG_TARGET_WARN"] = "Advertencia de objetivo peligroso"
    L["OPT_DANG_TARGET_WARN_DESC"] = "Cambia cómo avisar cuando apuntas a un objetivo normal (usualmente de nivel alto)."
    L["OPT_DANG_ELITE_WARN"] = "Advertencia de objetivo élite peligroso"
    L["OPT_DANG_ELITE_WARN_DESC"] = "Cambia cómo avisar cuando apuntas a un objetivo élite."
    L["OPT_DANG_PVP_WARN"] = "Advertencia de objetivo jugador PvP enemigo"
    L["OPT_DANG_PVP_WARN_DESC"] = "Cambia cómo avisar cuando apuntas a un jugador enemigo marcado para JcJ."
    L["OPT_SELF_PVP_WARN"] = "Advertencia \"Estás marcado para JcJ\""
    L["OPT_SELF_PVP_WARN_DESC"] = "Cambia cómo avisar cuando estás marcado para JcJ."
    L["OPT_QUEST_WARN"] = "Advertencia de misión peligrosa"
    L["OPT_QUEST_WARN_DESC"] = "Cambia cómo avisar cuando surge una misión peligrosa."
    L["OPT_UNITSCAN_WARN"] = "Advertencia de objetivos cercanos"
    L["OPT_UNITSCAN_WARN_DESC"] = "Cambia cómo avisar cuando se encuentra un objetivo peligroso cercano."
    
    L["OPT_THRESHOLDS"] = "Umbrales"
    L["OPT_BREATH_LOW"] = "Respiración baja (segundos restantes)"
    L["OPT_BREATH_WARN_SEC"] = "Advertencia (segundos)"
    L["OPT_BREATH_WARN_SEC_DESC"] = "A cuántos segundos de respiración restante debe mostrarse la advertencia normal"
    L["OPT_BREATH_PANIC_SEC"] = "Pánico (segundos)"
    L["OPT_BREATH_PANIC_SEC_DESC"] = "A cuántos segundos de respiración restante debe mostrarse la advertencia de pánico"
    
    L["OPT_HP_LOW"] = "Salud baja (en %)"
    L["OPT_HP_WARN_PCT"] = "Advertencia (%)"
    L["OPT_HP_WARN_PCT_DESC"] = "A qué porcentaje de salud debe mostrarse la advertencia normal"
    L["OPT_HP_PANIC_PCT"] = "Pánico (%)"
    L["OPT_HP_PANIC_PCT_DESC"] = "A qué porcentaje de salud debe mostrarse la advertencia de pánico"
    L["OPT_PET_HP_LOW"] = "Vida de la mascota baja (en %)"
    
    L["OPT_LEVEL_DIFF"] = "Diferencia de nivel (entre tú y tu objetivo)"
    L["OPT_LEVELDIFF_NORMAL"] = "Advertencia de objetivo normal"
    L["OPT_LEVELDIFF_NORMAL_DESC"] = "A qué diferencia de nivel entre tú y tu objetivo (normal) debe mostrarse la advertencia normal"
    L["OPT_LEVELDIFF_ELITE"] = "Advertencia de objetivo élite"
    L["OPT_LEVELDIFF_ELITE_DESC"] = "A qué diferencia de nivel entre tú y tu objetivo (élite) debe mostrarse la advertencia normal"
    L["OPT_LEVELDIFF_UNITSCAN"] = "Advertencia de objetivo cercano"
    L["OPT_LEVELDIFF_UNITSCAN_DESC"] = "Todas las unidades por debajo de esta diferencia de nivel entre tú y el objetivo serán ignoradas al escanear objetivos peligrosos cercanos."
    
    L["OPT_UNITSCAN"] = "Escanear objetivos cercanos"
    L["OPT_UNITSCAN_DESC"] = "Al escanear unidades durante el combate pueden ocurrir pequeños problemas, como la interrupción de tu autoataque. Esto se debe a limitaciones de la API de WoW. Si habilitas 'escanear en combate', asegúrate también de activar 'Atacar al asistir' en las opciones de interfaz para que tu autoataque cuerpo a cuerpo no se interrumpa."
    L["OPT_UNITSCAN_ENABLE"] = "Activar escaneos"
    L["OPT_UNITSCAN_ENABLE_DESC"] = "Activa el escaneo de la zona cada pocos segundos para comprobar objetivos peligrosos."
    L["OPT_UNITSCAN_ENABLE_COMBAT"] = "Escanear durante el combate"
    L["OPT_UNITSCAN_ENABLE_COMBAT_DESC"] = "El escaneo continuará durante el combate. ¡Asegúrate de habilitar 'Atacar al asistir' en las opciones de interfaz!"

    L["OPT_DEBUG"] = "Depuración (ignorar para uso normal)"
    L["OPT_DEBUG_OUTPUT"] = "Salida de depuración"
    L["OPT_DEBUG_OUTPUT_DESC"] = "Habilitar salida de depuración"
    L["OPT_CHECK_LOOP_INT"] = "Intervalo del bucle de comprobación (segundos)"
    L["OPT_CHECK_LOOP_INT_DESC"] = "El valor por defecto está bien. Cámbialo solo si tienes problemas de rendimiento."
    
    L["OPT_CLEAR_IGNORED"] = "Borrar advertencias ignoradas"
    L["OPT_CLEAR_IGNORED_DESC"] = "Restablece la lista de todo lo que hayas descartado/ignorado permanentemente. Como advertencias para misiones o unidades concretas."
end

local L = AceLocale:NewLocale("HardcoreAlarms", "frFR")
if L then
    -- warnings
    L["WARNING"] = "Attention !"
    L["PANIC_WARNING"] = "ATTENTION PANIQUE !"
    L["PLAYER_PVP_WARN"] = "Vous êtes marqué pour le PvP !"
    L["HP_WARN"] = "Santé BASSE !"
    L["HP_PANIC"] = "Santé CRITIQUE !"
    L["PET_HP_WARN"] = "PV du familier FAIBLES !"
    L["PET_HP_PANIC"] = "PV du familier CRITIQUES !"
    L["BREATH_WARN_FMT"] = "Il ne reste que %.0fs de souffle !"
    L["OUT_OF_BREATH"] = "PLUS DE SOUFFLE !"
    L["TARGET_WARNTITLE"] = "Cible dangereuse !"
    L["TARGET_WARN_ELITE"] = "Ennemi d'élite !"
    L["TARGET_WARN_HIGHLVL"] = "Ennemi de haut niveau !"
    L["TARGET_WARN_ENEMYPVPPLAYER"] = "Joueur ennemi marqué pour le PvP !"
    L["TARGET_WARN_ENEMYPVPTARGET"] = "Cible marquée pour le PvP !"
    L["TARGET_WARN_4966"] = "Accepter la quête « The Missing Diplomat » peut vous tuer facilement ! Vous serez instantanément pris en embuscade par des ennemis coriaces."
    L["TARGET_WARN_4191"] = "Cette unité n'est pas réellement dangereuse. C'est juste un test."
    L["QUEST_WARNTITLE"] = "Quête dangereuse : "
    local quest_warnescort = "Des vagues d'ennemis durant l'escorte peuvent vous submerger facilement."
    L["QUEST_WARNESCORT"] = quest_warnescort
    local quest_warntightspace = "Nombreux ennemis dangereux dans un espace confiné."
    L["QUEST_WARNTIGHTSPACE"] = quest_warntightspace
    L["QUEST_WARN_3909"] = "Boire l'élixir Videre vous tuera instantanément."
    L["QUEST_WARN_7843"] = "Vous serez marqué PvP lorsque la lance sera plantée. Des gardes de haut niveau se trouvent à proximité."
    L["QUEST_WARN_1380"] = "Des vagues d'apparition peuvent vous submerger. Aucune issue facile non plus."
    L["QUEST_WARN_6132"] = quest_warnescort
    L["QUEST_WARN_552"] = "L'endroit où vous rendez cette quête se trouve juste à côté de gardes de haut niveau."
    L["QUEST_WARN_976"] = quest_warnescort
    L["QUEST_WARN_685"] = quest_warntightspace
    L["QUEST_WARN_348"] = quest_warntightspace
    L["QUEST_WARN_4971"] = "Trois parasites apparaîtront instantanément sur vous en même temps. Tuer des parasites peut en faire apparaître d'autres."
    L["QUEST_WARN_1150"] = quest_warntightspace
    L["QUEST_WARN_1090"] = quest_warntightspace
    L["QUEST_WARN_1126"] = quest_warntightspace
    L["QUEST_WARN_4507"] = quest_warntightspace
    L["QUEST_WARN_217"] = "Trois ennemis coriaces en même temps dans un espace confiné."
    L["QUEST_WARN_6134"] = "Une fois placé, tenez-vous à l'écart de l'aimant pour éviter d'être submergé. L'aimant rendra hostiles des ennemis neutres."
    L["QUEST_WARN_5781"] = "Cliquer sur la tombe fera apparaître quatre ennemis en même temps."
    L["QUEST_WARN_3566"] = "Ennemis d'élite coriaces et mini‑boss."
    L["QUEST_WARN_608"] = "La dernière quête de cette suite est dangereuse. " .. quest_warntightspace
    L["QUEST_WARN_2359"] = "Les ennemis sont très coriaces et infligent beaucoup de dégâts si vous vous faites surprendre."
    L["QUEST_WARN_2381"] = "Le perroquet invoqué est niveau 55. Utilisez l'objet de quête pour le rendre vulnérable."
    L["QUEST_WARN_408"] = quest_warntightspace
    L["QUEST_WARN_1001"] = "Cette quête n'est pas réellement dangereuse. C'est juste un test. Ignorez ceci : " .. quest_warntightspace
    L["TEST_WARN_TITLE"] = "Avertissement de test déplaçable"
    L["TEST_WARN_TEXT"] = "Aucun avertissement ! Tout est calme. Promis. C'est un test. Vraiment. Ne paniquez pas !"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP"] = "Fermer la fenêtre d'avertissement"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP_TEXT"] = "Maj‑clic pour ignorer définitivement l'avertissement pour cette unité."
    L["UNITSCAN_CHAT_MESSAGE"] = "Unitscan a trouvé une cible dangereuse :"
    L["UNITSCAN_WARNTITLE"] = "Danger à proximité :"
    
    -- options
    L["OPT_DESCRIPTION_TOP_TITLE"] = "Info"
    L["OPT_DESCRIPTION_TOP"] = "Alarmes configurables pour PV bas, essoufflement, quêtes et ennemis dangereux.\n\nVous pouvez facilement étendre la liste des quêtes et unités dangereuses vous-même. Plus de détails dans le fichier README dans le dossier de votre addon.\nCet addon est gratuit et open-source sous GPLv3. Cela signifie que vous pouvez utiliser, modifier et distribuer ce projet, mais toutes les modifications que vous publiez doivent être sous licence GPLv3 et inclure le code source.\n\nAmusez-vous bien et prenez soin de vous !"

    L["OPT_INFO"] = "Tous les changements sont appliqués et sauvegardés instantanément."

    L["OPT_TEXT"] = "Texte"
    L["OPT_FLASHING_SCREEN"] = "Écran clignotant"
    L["OPT_SOUND"] = "Son"
    L["OPT_SOUND_OFF"] = "Désactivé"
    L["OPT_SOUND_ONCE"] = "Une fois"
    L["OPT_SOUND_REPEATING"] = "Répétition"

    L["OPT_MINIMAP_ICON"] = "Icône de la minicarte"
    L["OPT_SHOW_MINIMAP"] = "Afficher l'icône de la minicarte"

    L["OPT_UI"] = "Interface utilisateur"
    L["OPT_MOVABLE"] = "Rendre l'UI déplaçable"
    L["OPT_MOVABLE_DESC"] = "Ajustez la position des avertissements en les faisant glisser. Désactivez quand vous avez fini."
    L["OPT_WARN_STYLE"] = "Style d'avertissement"
    L["OPT_WARN_STYLE_DESC"] = "Comment voulez‑vous que l'avertissement apparaisse ?"
    L["OPT_WARN_STYLE_BORDER_BG"] = "Bordure et fond"
    L["OPT_WARN_STYLE_ONLY_BG"] = "Seulement le fond"
    L["OPT_WARN_STYLE_ONLY_TEXT"] = "Seulement le texte"

    L["OPT_WARN_PREF"] = "Préférence d'avertissement"
    L["OPT_BREATH_WARN"] = "Avertissement de souffle"
    L["OPT_BREATH_WARN_DESC"] = "Change la manière d'avertir lorsque votre souffle baisse."
    L["OPT_HP_WARN"] = "Avertissement de santé"
    L["OPT_HP_WARN_DESC"] = "Change la manière d'avertir lorsque votre vie est basse."
    L["OPT_PET_HP_WARN"] = "Avertissement PV du familier"
    L["OPT_PET_HP_WARN_DESC"] = "Modifie la façon dont vous êtes averti lorsque les PV de votre familier sont bas."
    L["OPT_DANG_TARGET_WARN"] = "Avertissement de cible dangereuse"
    L["OPT_DANG_TARGET_WARN_DESC"] = "Change la manière d'avertir lorsque vous ciblez une cible normale (généralement de haut niveau)."
    L["OPT_DANG_ELITE_WARN"] = "Avertissement d'élite dangereuse"
    L["OPT_DANG_ELITE_WARN_DESC"] = "Change la manière d'avertir lorsque vous ciblez une cible élite."
    L["OPT_DANG_PVP_WARN"] = "Avertissement cible joueur PvP ennemi"
    L["OPT_DANG_PVP_WARN_DESC"] = "Change la manière d'avertir lorsque vous ciblez un joueur ennemi marqué pour le PvP."
    L["OPT_SELF_PVP_WARN"] = "Avertissement « Vous êtes marqué pour le PvP »"
    L["OPT_SELF_PVP_WARN_DESC"] = "Change la manière d'avertir lorsque vous êtes marqué pour le PvP."
    L["OPT_QUEST_WARN"] = "Avertissement de quête dangereuse"
    L["OPT_QUEST_WARN_DESC"] = "Change la manière d'avertir lorsqu'une quête dangereuse apparaît."
    L["OPT_UNITSCAN_WARN"] = "Avertissement de cibles proches"
    L["OPT_UNITSCAN_WARN_DESC"] = "Change la manière d'avertir lorsqu'une cible dangereuse a été trouvée à proximité."

    L["OPT_THRESHOLDS"] = "Seuils"
    L["OPT_BREATH_LOW"] = "Souffle bas (secondes restantes)"
    L["OPT_BREATH_WARN_SEC"] = "Avertissement (secondes)"
    L["OPT_BREATH_WARN_SEC_DESC"] = "À quel nombre de secondes de souffle restant afficher l'avertissement normal"
    L["OPT_BREATH_PANIC_SEC"] = "Panique (secondes)"
    L["OPT_BREATH_PANIC_SEC_DESC"] = "À quel nombre de secondes de souffle restant afficher l'avertissement de panique"

    L["OPT_HP_LOW"] = "PV bas (en %)"
    L["OPT_HP_WARN_PCT"] = "Avertissement (%)"
    L["OPT_HP_WARN_PCT_DESC"] = "À quel pourcentage de vie afficher l'avertissement normal"
    L["OPT_HP_PANIC_PCT"] = "Panique (%)"
    L["OPT_HP_PANIC_PCT_DESC"] = "À quel pourcentage de vie afficher l'avertissement de panique"
    L["OPT_PET_HP_LOW"] = "PV du familier faibles (en %)"

    L["OPT_LEVEL_DIFF"] = "Différence de niveau (entre vous et votre cible)"
    L["OPT_LEVELDIFF_NORMAL"] = "Avertissement cible normale"
    L["OPT_LEVELDIFF_NORMAL_DESC"] = "À quelle différence de niveau entre vous et votre cible (normale) afficher l'avertissement normal"
    L["OPT_LEVELDIFF_ELITE"] = "Avertissement cible élite"
    L["OPT_LEVELDIFF_ELITE_DESC"] = "À quelle différence de niveau entre vous et votre cible (élite) afficher l'avertissement normal"
    L["OPT_LEVELDIFF_UNITSCAN"] = "Avertissement cibles proches"
    L["OPT_LEVELDIFF_UNITSCAN_DESC"] = "Toutes les unités en dessous de cette différence de niveau entre vous et la cible seront ignorées lors du scan des cibles dangereuses à proximité."

    L["OPT_UNITSCAN"] = "Scanner les cibles proches"
    L["OPT_UNITSCAN_DESC"] = "Lors de la recherche d'unités en combat, de petits problèmes peuvent survenir, par exemple l'interruption de votre attaque automatique. Cela est dû à des limitations de l'API de WoW. Si vous activez 'scanner en combat', assurez-vous également d'activer 'Attaquer lors d'une assistance' dans les options d'interface afin que votre attaque de mêlée automatique ne soit pas interrompue !"
    L["OPT_UNITSCAN_ENABLE"] = "Activer les scans"
    L["OPT_UNITSCAN_ENABLE_DESC"] = "Activer le scan des environs toutes les quelques secondes pour vérifier les cibles dangereuses."
    L["OPT_UNITSCAN_ENABLE_COMBAT"] = "Scanner en combat"
    L["OPT_UNITSCAN_ENABLE_COMBAT_DESC"] = "Le scan continuera pendant le combat. Assurez-vous d'activer 'Attaquer lors d'une assistance' dans les options d'interface !"

    L["OPT_DEBUG"] = "Débogage (ignorer en usage normal)"
    L["OPT_DEBUG_OUTPUT"] = "Sortie debug"
    L["OPT_DEBUG_OUTPUT_DESC"] = "Activer la sortie debug"
    L["OPT_CHECK_LOOP_INT"] = "Intervalle de boucle de vérification (secondes)"
    L["OPT_CHECK_LOOP_INT_DESC"] = "La valeur par défaut convient. Ne changez que si vous avez des problèmes de performance."

    L["OPT_CLEAR_IGNORED"] = "Réinitialiser avertissements ignorés"
    L["OPT_CLEAR_IGNORED_DESC"] = "Réinitialise la liste de tout ce que vous avez abandonné/ignoré définitivement. Par exemple les avertissements pour des quêtes ou unités particulières."
end

local L = AceLocale:NewLocale("HardcoreAlarms", "ptBR")
if L then
    -- warnings
    L["WARNING"] = "Aviso!"
    L["PANIC_WARNING"] = "AVISO DE PÂNICO!"
    L["PLAYER_PVP_WARN"] = "Você está marcado para JvJ!"
    L["HP_WARN"] = "Vida BAIXA!"
    L["HP_PANIC"] = "Vida CRÍTICA!"
    L["PET_HP_WARN"] = "Vida do pet BAIXA!"
    L["PET_HP_PANIC"] = "Vida do pet CRÍTICA!"
    L["BREATH_WARN_FMT"] = "Apenas %.0fs de respiração!"
    L["OUT_OF_BREATH"] = "SEM AR!"
    L["TARGET_WARNTITLE"] = "Alvo perigoso!"
    L["TARGET_WARN_ELITE"] = "Inimigo elite!"
    L["TARGET_WARN_HIGHLVL"] = "Inimigo de nível alto!"
    L["TARGET_WARN_ENEMYPVPPLAYER"] = "Jogador inimigo marcado para JvJ!"
    L["TARGET_WARN_ENEMYPVPTARGET"] = "Inimigo marcado para JvJ!"
    L["TARGET_WARN_4966"] = "Aceitar a missão \"O diplomata desaparecido\" pode facilmente te matar! Você será emboscado instantaneamente por inimigos difíceis"
    L["TARGET_WARN_4191"] = "Essa unidade na verdade não é perigosa. É apenas um teste."
    L["QUEST_WARNTITLE"] = "Missão perigosa: "
    local quest_warnescort = "Ondas durante a escolta podem facilmente te sobrecarregar."
    L["QUEST_WARNESCORT"] = quest_warnescort
    local quest_warntightspace = "Muitos inimigos perigosos em um espaço apertado."
    L["QUEST_WARNTIGHTSPACE"] = quest_warntightspace
    L["QUEST_WARN_3909"] = "Beber o Elixir Videre vai te matar instantaneamente."
    L["QUEST_WARN_7843"] = "Você ficará marcado para JvJ quando a lança for colocada. Guardas de alto nível estão por perto."
    L["QUEST_WARN_1380"] = "Ondas de spawn podem facilmente te sobrecarregar. Também não há fuga fácil."
    L["QUEST_WARN_6132"] = quest_warnescort
    L["QUEST_WARN_552"] = "O local onde você entrega esta missão fica bem ao lado de guardas de alto nível."
    L["QUEST_WARN_976"] = quest_warnescort
    L["QUEST_WARN_685"] = quest_warntightspace
    L["QUEST_WARN_348"] = quest_warntightspace
    L["QUEST_WARN_4971"] = "Três parasitas irão spawnar instantaneamente em você ao mesmo tempo. Matar parasitas pode gerar mais parasitas."
    L["QUEST_WARN_1150"] = quest_warntightspace
    L["QUEST_WARN_1090"] = quest_warntightspace
    L["QUEST_WARN_1126"] = quest_warntightspace
    L["QUEST_WARN_4507"] = quest_warntightspace
    L["QUEST_WARN_217"] = "Três inimigos difíceis ao mesmo tempo em um espaço apertado."
    L["QUEST_WARN_6134"] = "Uma vez colocado, fique longe do ímã para evitar ser cercado. O ímã transformará inimigos neutros em hostis."
    L["QUEST_WARN_5781"] = "Clicar no túmulo fará quatro inimigos aparecerem ao mesmo tempo."
    L["QUEST_WARN_3566"] = "Inimigos élite difíceis e mini-chefe."
    L["QUEST_WARN_608"] = "A última missão dessa cadeia é perigosa. " .. quest_warntightspace
    L["QUEST_WARN_2359"] = "Os inimigos são muito fortes e causam muito dano quando te pegam."
    L["QUEST_WARN_2381"] = "O papagaio que surge é nível 55. Use o item da missão para torná-lo matável."
    L["QUEST_WARN_408"] = quest_warntightspace
    L["QUEST_WARN_1001"] = "Esta missão na verdade não é perigosa. É apenas um teste. Ignore isto: " .. quest_warntightspace
    L["TEST_WARN_TITLE"] = "Aviso de teste móvel"
    L["TEST_WARN_TEXT"] = "Nenhum aviso! Tudo está tranquilo. Promessa. Isto é um teste. Sério. Não entre em pânico!"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP"] = "Fechar janela de aviso"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP_TEXT"] = "Shift-clique para ignorar o aviso para esta unidade permanentemente."
    L["UNITSCAN_CHAT_MESSAGE"] = "Unitscan encontrou um alvo perigoso:"
    L["UNITSCAN_WARNTITLE"] = "Perigo próximo:"

    -- options
    L["OPT_DESCRIPTION_TOP_TITLE"] = "Info"
    L["OPT_DESCRIPTION_TOP"] = "Alarmes configuráveis para HP baixo, sem fôlego, missões e inimigos perigosos.\n\nVocê pode facilmente estender a lista de missões e unidades perigosas por conta própria. Mais detalhes no arquivo README na pasta do seu addon.\nEste addon é gratuito e open-source sob GPLv3. Isso significa que você pode usar, modificar e distribuir este projeto, mas quaisquer alterações que você publicar devem ser licenciadas sob GPLv3 e incluir o código-fonte.\n\nDivirta-se e se cuide!"

    L["OPT_INFO"] = "Todas as mudanças são aplicadas e salvas instantaneamente."

    L["OPT_TEXT"] = "Texto"
    L["OPT_FLASHING_SCREEN"] = "Tela piscando"
    L["OPT_SOUND"] = "Som"
    L["OPT_SOUND_OFF"] = "Desligado"
    L["OPT_SOUND_ONCE"] = "Uma vez"
    L["OPT_SOUND_REPEATING"] = "Repetir"

    L["OPT_MINIMAP_ICON"] = "Ícone do minimapa"
    L["OPT_SHOW_MINIMAP"] = "Mostrar ícone no minimapa"

    L["OPT_UI"] = "Interface"
    L["OPT_MOVABLE"] = "Tornar interface móvel"
    L["OPT_MOVABLE_DESC"] = "Ajuste a posição dos avisos arrastando-os. Desative quando terminar."
    L["OPT_WARN_STYLE"] = "Estilo de aviso"
    L["OPT_WARN_STYLE_DESC"] = "Como você quer que o aviso apareça?"
    L["OPT_WARN_STYLE_BORDER_BG"] = "Borda e fundo"
    L["OPT_WARN_STYLE_ONLY_BG"] = "Apenas fundo"
    L["OPT_WARN_STYLE_ONLY_TEXT"] = "Apenas texto"

    L["OPT_WARN_PREF"] = "Preferência de aviso"
    L["OPT_BREATH_WARN"] = "Aviso de respiração"
    L["OPT_BREATH_WARN_DESC"] = "Altera como avisar quando estiver ficando sem respiração."
    L["OPT_HP_WARN"] = "Aviso de vida"
    L["OPT_HP_WARN_DESC"] = "Altera como avisar quando você tiver pouca vida."
    L["OPT_PET_HP_WARN"] = "Aviso de vida do pet"
    L["OPT_PET_HP_WARN_DESC"] = "Altera como você é avisado quando a vida do seu pet está baixa."
    L["OPT_DANG_TARGET_WARN"] = "Aviso de alvo perigoso"
    L["OPT_DANG_TARGET_WARN_DESC"] = "Altera como avisar quando você estiver mirando um alvo normal (normalmente de nível alto)."
    L["OPT_DANG_ELITE_WARN"] = "Aviso de alvo elite perigoso"
    L["OPT_DANG_ELITE_WARN_DESC"] = "Altera como avisar quando você estiver mirando um alvo elite."
    L["OPT_DANG_PVP_WARN"] = "Aviso de alvo jogador PvP inimigo"
    L["OPT_DANG_PVP_WARN_DESC"] = "Altera como avisar quando você estiver mirando um jogador inimigo marcado para JvJ."
    L["OPT_SELF_PVP_WARN"] = "Aviso \"Você está marcado para JvJ\""
    L["OPT_SELF_PVP_WARN_DESC"] = "Altera como avisar quando você estiver marcado para JvJ."
    L["OPT_QUEST_WARN"] = "Aviso de missão perigosa"
    L["OPT_QUEST_WARN_DESC"] = "Altera como avisar quando surgir uma missão perigosa."
    L["OPT_UNITSCAN_WARN"] = "Aviso de alvos próximos"
    L["OPT_UNITSCAN_WARN_DESC"] = "Altera como avisar quando um alvo perigoso for encontrado próximo."

    L["OPT_THRESHOLDS"] = "Limiares"
    L["OPT_BREATH_LOW"] = "Respiração baixa (segundos restantes)"
    L["OPT_BREATH_WARN_SEC"] = "Aviso (segundos)"
    L["OPT_BREATH_WARN_SEC_DESC"] = "Com quantos segundos de respiração restante o aviso normal deve ser mostrado"
    L["OPT_BREATH_PANIC_SEC"] = "Pânico (segundos)"
    L["OPT_BREATH_PANIC_SEC_DESC"] = "Com quantos segundos de respiração restante o aviso de pânico deve ser mostrado"

    L["OPT_HP_LOW"] = "Vida baixa (em %)"
    L["OPT_HP_WARN_PCT"] = "Aviso (%)"
    L["OPT_HP_WARN_PCT_DESC"] = "Em qual porcentagem de vida o aviso normal deve ser mostrado"
    L["OPT_HP_PANIC_PCT"] = "Pânico (%)"
    L["OPT_HP_PANIC_PCT_DESC"] = "Em qual porcentagem de vida o aviso de pânico deve ser mostrado"
    L["OPT_PET_HP_LOW"] = "Vida do pet baixa (em %)"

    L["OPT_LEVEL_DIFF"] = "Diferença de nível (entre você e seu alvo)"
    L["OPT_LEVELDIFF_NORMAL"] = "Aviso de alvo normal"
    L["OPT_LEVELDIFF_NORMAL_DESC"] = "Em qual diferença de nível entre você e seu alvo (normal) o aviso normal deve ser mostrado"
    L["OPT_LEVELDIFF_ELITE"] = "Aviso de alvo elite"
    L["OPT_LEVELDIFF_ELITE_DESC"] = "Em qual diferença de nível entre você e seu alvo (elite) o aviso normal deve ser mostrado"
    L["OPT_LEVELDIFF_UNITSCAN"] = "Aviso de alvo próximo"
    L["OPT_LEVELDIFF_UNITSCAN_DESC"] = "Todas as unidades abaixo desta diferença de nível entre você e o alvo serão ignoradas ao escanear por alvos perigosos próximos."

    L["OPT_UNITSCAN"] = "Escanear alvos próximos"
    L["OPT_UNITSCAN_DESC"] = "Ao escanear unidades durante o combate, podem ocorrer pequenos problemas, como a interrupção do seu ataque automático. Isso se deve a limitações da API do WoW. Se você habilitar 'escanear em combate', certifique-se também de ativar 'Atacar ao assistir' nas opções de interface para que seu ataque corpo a corpo automático não seja interrompido!"
    L["OPT_UNITSCAN_ENABLE"] = "Ativar escaneamentos"
    L["OPT_UNITSCAN_ENABLE_DESC"] = "Ativa o escaneamento das proximidades a cada poucos segundos para verificar por alvos perigosos."
    L["OPT_UNITSCAN_ENABLE_COMBAT"] = "Escanear durante o combate"
    L["OPT_UNITSCAN_ENABLE_COMBAT_DESC"] = "O escaneamento continuará durante o combate. Certifique-se de ativar 'Atacar ao assistir' nas opções de interface!"

    L["OPT_DEBUG"] = "Depuração (ignorar para uso normal)"
    L["OPT_DEBUG_OUTPUT"] = "Saída de depuração"
    L["OPT_DEBUG_OUTPUT_DESC"] = "Habilitar saída de depuração"
    L["OPT_CHECK_LOOP_INT"] = "Intervalo do loop de verificação (segundos)"
    L["OPT_CHECK_LOOP_INT_DESC"] = "O padrão é suficiente. Altere apenas se tiver problemas de desempenho."

    L["OPT_CLEAR_IGNORED"] = "Limpar avisos ignorados"
    L["OPT_CLEAR_IGNORED_DESC"] = "Redefine a lista de tudo que você descartou/ignorou permanentemente. Como avisos para missões ou unidades específicas."
end

local L = AceLocale:NewLocale("HardcoreAlarms", "koKR")
if L then
    -- warnings
    L["WARNING"] = "경고!"
    L["PANIC_WARNING"] = "긴급 경고!"
    L["PLAYER_PVP_WARN"] = "당신은 PvP 표시 상태입니다!"
    L["HP_WARN"] = "체력 낮음!"
    L["HP_PANIC"] = "체력 위급!"
    L["PET_HP_WARN"] = "소환수 생명력 낮음!"
    L["PET_HP_PANIC"] = "소환수 생명력 위험!"
    L["BREATH_WARN_FMT"] = "호흡이 %.0f초 남았습니다!"
    L["OUT_OF_BREATH"] = "호흡 불가!"
    L["TARGET_WARNTITLE"] = "위험한 대상!"
    L["TARGET_WARN_ELITE"] = "정예 적!"
    L["TARGET_WARN_HIGHLVL"] = "고레벨 적!"
    L["TARGET_WARN_ENEMYPVPPLAYER"] = "PvP 표시된 적 플레이어!"
    L["TARGET_WARN_ENEMYPVPTARGET"] = "PvP 표시된 적!"
    L["TARGET_WARN_4966"] = "퀘스트 \"실종된 외교관\"을 수락하면 쉽게 죽을 수 있습니다! 강한 적들에게 즉시 매복당합니다"
    L["TARGET_WARN_4191"] = "이 유닛은 실제로 위험하지 않습니다. 테스트용입니다."
    L["QUEST_WARNTITLE"] = "위험한 퀘스트: "
    local quest_warnescort = "호위 도중 생성되는 몬스터 웨이브가 쉽게 압도할 수 있습니다."
    L["QUEST_WARNESCORT"] = quest_warnescort
    local quest_warntightspace = "좁은 공간에 위험한 적이 많습니다."
    L["QUEST_WARNTIGHTSPACE"] = quest_warntightspace
    L["QUEST_WARN_3909"] = "비데레 물약을 마시면 즉시 사망합니다."
    L["QUEST_WARN_7843"] = "창이 꽂히면 PvP 표시가 됩니다. 주변에 고레벨 경비병이 있습니다."
    L["QUEST_WARN_1380"] = "스폰 웨이브가 쉽게 압도할 수 있습니다. 도망칠 곳도 마땅치 않습니다."
    L["QUEST_WARN_6132"] = quest_warnescort
    L["QUEST_WARN_552"] = "퀘스트를 제출하는 위치가 고레벨 경비병 바로 옆에 있습니다."
    L["QUEST_WARN_976"] = quest_warnescort
    L["QUEST_WARN_685"] = quest_warntightspace
    L["QUEST_WARN_348"] = quest_warntightspace
    L["QUEST_WARN_4971"] = "세 마리의 기생충이 동시에 즉시 당신에게 생성됩니다. 기생충을 처치하면 더 많은 기생충이 생성될 수 있습니다."
    L["QUEST_WARN_1150"] = quest_warntightspace
    L["QUEST_WARN_1090"] = quest_warntightspace
    L["QUEST_WARN_1126"] = quest_warntightspace
    L["QUEST_WARN_4507"] = quest_warntightspace
    L["QUEST_WARN_217"] = "좁은 공간에서 동시에 세 명의 강한 적이 있습니다."
    L["QUEST_WARN_6134"] = "설치 후 자석에서 떨어져 있어 군중에 휩쓸리지 마세요. 자석은 중립 적을 적대적으로 만듭니다."
    L["QUEST_WARN_5781"] = "무덤을 클릭하면 네 마리의 적이 동시에 소환됩니다."
    L["QUEST_WARN_3566"] = "강력한 정예 적들과 미니 보스가 있습니다."
    L["QUEST_WARN_608"] = "이 연계 퀘스트의 마지막 퀘스트는 위험합니다. " .. quest_warntightspace
    L["QUEST_WARN_2359"] = "적들이 매우 강력하며, 잡히면 큰 피해를 줍니다."
    L["QUEST_WARN_2381"] = "소환되는 앵무새는 레벨 55입니다. 퀘스트 아이템을 사용해야 처치할 수 있습니다."
    L["QUEST_WARN_408"] = quest_warntightspace
    L["QUEST_WARN_1001"] = "이 퀘스트는 실제로 위험하지 않습니다. 테스트용입니다. 무시하세요: " .. quest_warntightspace
    L["TEST_WARN_TITLE"] = "이동 가능한 테스트 경고"
    L["TEST_WARN_TEXT"] = "경고 없음! 모두 괜찮습니다. 약속합니다. 이것은 테스트입니다. 진짜입니다. 당황하지 마세요!"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP"] = "경고 창 닫기"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP_TEXT"] = "Shift-클릭하여 이 유닛에 대한 경고를 영구히 무시합니다."
    L["UNITSCAN_CHAT_MESSAGE"] = "Unitscan이 위험한 대상을 찾았습니다:"
    L["UNITSCAN_WARNTITLE"] = "주변 위험:"

    -- options
    L["OPT_DESCRIPTION_TOP_TITLE"] = "정보"
    L["OPT_DESCRIPTION_TOP"] = "체력이 낮음, 숨가쁨, 위험한 퀘스트 및 적을 위한 설정 가능한 경고입니다.\n\n위험한 퀘스트와 유닛 목록은 직접 쉽게 확장할 수 있습니다. 애드온 폴더의 README 파일에서 자세한 내용을 확인하세요.\n이 애드온은 GPLv3 하에 무료 및 오픈소스입니다. 즉, 이 프로젝트를 사용, 수정 및 배포할 수 있지만, 배포하는 변경사항은 GPLv3로 라이선스되어야 하며 소스 코드를 포함해야 합니다.\n\n즐겁게 플레이하시고 조심하세요!"

    L["OPT_INFO"] = "모든 변경 사항은 즉시 적용되고 저장됩니다."
    
    L["OPT_TEXT"] = "텍스트"
    L["OPT_FLASHING_SCREEN"] = "화면 깜박임"
    L["OPT_SOUND"] = "사운드"
    L["OPT_SOUND_OFF"] = "꺼짐"
    L["OPT_SOUND_ONCE"] = "한 번"
    L["OPT_SOUND_REPEATING"] = "반복"
    
    L["OPT_MINIMAP_ICON"] = "미니맵 아이콘"
    L["OPT_SHOW_MINIMAP"] = "미니맵 아이콘 표시"
    
    L["OPT_UI"] = "사용자 인터페이스"
    L["OPT_MOVABLE"] = "UI 이동 가능"
    L["OPT_MOVABLE_DESC"] = "경고를 드래그하여 위치를 조정하세요. 완료되면 비활성화하세요."
    L["OPT_WARN_STYLE"] = "경고 스타일"
    L["OPT_WARN_STYLE_DESC"] = "경고를 어떻게 표시할지 선택하세요."
    L["OPT_WARN_STYLE_BORDER_BG"] = "테두리 및 배경"
    L["OPT_WARN_STYLE_ONLY_BG"] = "배경만"
    L["OPT_WARN_STYLE_ONLY_TEXT"] = "텍스트만"
    
    L["OPT_WARN_PREF"] = "경고 선호"
    L["OPT_BREATH_WARN"] = "호흡 경고"
    L["OPT_BREATH_WARN_DESC"] = "호흡이 부족할 때 경고하는 방식을 변경합니다."
    L["OPT_HP_WARN"] = "체력 경고"
    L["OPT_HP_WARN_DESC"] = "체력이 낮을 때 경고하는 방식을 변경합니다."
    L["OPT_PET_HP_WARN"] = "소환수 생명력 경고"
    L["OPT_PET_HP_WARN_DESC"] = "소환수의 생명력이 낮을 때 경고하는 방식을 변경합니다."
    L["OPT_DANG_TARGET_WARN"] = "위험한 대상 경고"
    L["OPT_DANG_TARGET_WARN_DESC"] = "일반 대상(보통 고레벨)을 가리킬 때의 경고 방식을 변경합니다."
    L["OPT_DANG_ELITE_WARN"] = "정예 대상 경고"
    L["OPT_DANG_ELITE_WARN_DESC"] = "정예 대상일 때의 경고 방식을 변경합니다."
    L["OPT_DANG_PVP_WARN"] = "적 PvP 플레이어 대상 경고"
    L["OPT_DANG_PVP_WARN_DESC"] = "PvP 표시된 적 플레이어를 대상으로 할 때의 경고 방식을 변경합니다."
    L["OPT_SELF_PVP_WARN"] = "\"당신은 PvP 표시 상태입니다\" 경고"
    L["OPT_SELF_PVP_WARN_DESC"] = "당신이 PvP 표시 상태일 때의 경고 방식을 변경합니다."
    L["OPT_QUEST_WARN"] = "위험한 퀘스트 경고"
    L["OPT_QUEST_WARN_DESC"] = "위험한 퀘스트가 나타날 때의 경고 방식을 변경합니다."
    L["OPT_UNITSCAN_WARN"] = "근처 대상 스캔 경고"
    L["OPT_UNITSCAN_WARN_DESC"] = "근처에서 위험한 대상이 발견될 때의 경고 방식을 변경합니다."
    
    L["OPT_THRESHOLDS"] = "임계값"
    L["OPT_BREATH_LOW"] = "호흡 낮음 (남은 초)"
    L["OPT_BREATH_WARN_SEC"] = "경고 (초)"
    L["OPT_BREATH_WARN_SEC_DESC"] = "남은 호흡이 몇 초일 때 일반 경고를 표시할지 설정합니다."
    L["OPT_BREATH_PANIC_SEC"] = "긴급 (초)"
    L["OPT_BREATH_PANIC_SEC_DESC"] = "남은 호흡이 몇 초일 때 긴급 경고를 표시할지 설정합니다."
    
    L["OPT_HP_LOW"] = "체력 낮음 (%)"
    L["OPT_HP_WARN_PCT"] = "경고 (%)"
    L["OPT_HP_WARN_PCT_DESC"] = "체력 퍼센티지가 이 값일 때 일반 경고를 표시합니다."
    L["OPT_HP_PANIC_PCT"] = "긴급 (%)"
    L["OPT_HP_PANIC_PCT_DESC"] = "체력 퍼센티지가 이 값일 때 긴급 경고를 표시합니다."
    L["OPT_PET_HP_LOW"] = "소환수 생명력 낮음 (퍼센트)"
    
    L["OPT_LEVEL_DIFF"] = "레벨 차이 (당신과 대상 간)"
    L["OPT_LEVELDIFF_NORMAL"] = "일반 대상 경고"
    L["OPT_LEVELDIFF_NORMAL_DESC"] = "당신과 일반 대상 간의 레벨 차이가 이 값일 때 일반 경고를 표시합니다."
    L["OPT_LEVELDIFF_ELITE"] = "정예 대상 경고"
    L["OPT_LEVELDIFF_ELITE_DESC"] = "당신과 정예 대상 간의 레벨 차이가 이 값일 때 일반 경고를 표시합니다."
    L["OPT_LEVELDIFF_UNITSCAN"] = "근처 대상 경고 임계값"
    L["OPT_LEVELDIFF_UNITSCAN_DESC"] = "근처 위험 대상 스캔 시 이 레벨 차이보다 낮은 유닛은 무시됩니다."
    
    L["OPT_UNITSCAN"] = "근처 대상 스캔"
    L["OPT_UNITSCAN_DESC"] = "전투 중 유닛을 스캔할 때 자동 공격이 끊기는 등 일부 사소한 문제가 발생할 수 있습니다. 이는 WoW API의 제약 때문입니다. '전투 중 스캔'을 활성화하면 인터페이스 옵션에서 '지원 시 공격'도 활성화하여 근접 자동 공격이 끊기지 않도록 하세요!"
    L["OPT_UNITSCAN_ENABLE"] = "스캔 활성화"
    L["OPT_UNITSCAN_ENABLE_DESC"] = "몇 초마다 주변을 스캔하여 위험한 대상을 확인합니다."
    L["OPT_UNITSCAN_ENABLE_COMBAT"] = "전투 중 스캔"
    L["OPT_UNITSCAN_ENABLE_COMBAT_DESC"] = "전투 중에도 스캔이 계속됩니다. 인터페이스 옵션에서 '지원 시 공격'을 활성화하세요!"

    L["OPT_DEBUG"] = "디버그 (일반 사용 시 무시)"
    L["OPT_DEBUG_OUTPUT"] = "디버그 출력"
    L["OPT_DEBUG_OUTPUT_DESC"] = "디버그 출력을 활성화합니다."
    L["OPT_CHECK_LOOP_INT"] = "체크 루프 간격 (초)"
    L["OPT_CHECK_LOOP_INT_DESC"] = "기본값으로도 충분합니다. 성능 문제가 있을 때만 변경하세요."
    
    L["OPT_CLEAR_IGNORED"] = "무시된 경고 초기화"
    L["OPT_CLEAR_IGNORED_DESC"] = "특정 퀘스트나 유닛에 대해 영구히 무시한 항목들의 목록을 초기화합니다."
end

local L = AceLocale:NewLocale("HardcoreAlarms", "zhTW")
if L then
    -- warnings
    L["WARNING"] = "警告！"
    L["PANIC_WARNING"] = "緊急警告！"
    L["PLAYER_PVP_WARN"] = "你已被標記為 PvP！"
    L["HP_WARN"] = "生命值 低！"
    L["HP_PANIC"] = "生命值 危急！"
    L["PET_HP_WARN"] = "寵物生命 低！"
    L["PET_HP_PANIC"] = "寵物生命 危急！"
    L["BREATH_WARN_FMT"] = "只剩 %.0f 秒呼吸！"
    L["OUT_OF_BREATH"] = "窒息！"
    L["TARGET_WARNTITLE"] = "危險目標！"
    L["TARGET_WARN_ELITE"] = "精英敵人！"
    L["TARGET_WARN_HIGHLVL"] = "高等級敵人！"
    L["TARGET_WARN_ENEMYPVPPLAYER"] = "敵方玩家已被標記為 PvP！"
    L["TARGET_WARN_ENEMYPVPTARGET"] = "敵方被標記為 PvP！"
    L["TARGET_WARN_4966"] = "接取任務「失蹤的外交官」可能會立即殺死你！你會立刻遭到強力敵人的伏擊"
    L["TARGET_WARN_4191"] = "此單位實際上並不危險。這只是個測試。"
    L["QUEST_WARNTITLE"] = "危險任務： "
    local quest_warnescort = "護送過程中的小怪波會輕易壓垮你。"
    L["QUEST_WARNESCORT"] = quest_warnescort
    local quest_warntightspace = "狹小空間內有大量危險敵人。"
    L["QUEST_WARNTIGHTSPACE"] = quest_warntightspace
    L["QUEST_WARN_3909"] = "飲用維德爾藥劑會立即殺死你。"
    L["QUEST_WARN_7843"] = "插上長矛時你會被標記為 PvP。附近有高等級守衛。"
    L["QUEST_WARN_1380"] = "刷新波會輕易壓垮你。也沒有容易的逃生路線。"
    L["QUEST_WARN_6132"] = quest_warnescort
    L["QUEST_WARN_552"] = "你交任務的位置就在高等級守衛旁邊。"
    L["QUEST_WARN_976"] = quest_warnescort
    L["QUEST_WARN_685"] = quest_warntightspace
    L["QUEST_WARN_348"] = quest_warntightspace
    L["QUEST_WARN_4971"] = "三個寄生蟲會同時瞬間出現在你身上。擊殺寄生蟲可能會產生更多寄生蟲。"
    L["QUEST_WARN_1150"] = quest_warntightspace
    L["QUEST_WARN_1090"] = quest_warntightspace
    L["QUEST_WARN_1126"] = quest_warntightspace
    L["QUEST_WARN_4507"] = quest_warntightspace
    L["QUEST_WARN_217"] = "在狹小空間內同時有三個強敵。"
    L["QUEST_WARN_6134"] = "放置後請遠離磁鐵以免被包圍。磁鐵會使中立敵人成為敵對。"
    L["QUEST_WARN_5781"] = "點擊墓碑會同時刷新四個敵人。"
    L["QUEST_WARN_3566"] = "強力的精英敵人以及小型首領。"
    L["QUEST_WARN_608"] = "此連續任務的最後一個任務很危險。 " .. quest_warntightspace
    L["QUEST_WARN_2359"] = "敵人非常強悍，當你被困住時會造成大量傷害。"
    L["QUEST_WARN_2381"] = "召喚出的鸚鵡是55級。使用任務物品才能對牠造成傷害。"
    L["QUEST_WARN_408"] = quest_warntightspace
    L["QUEST_WARN_1001"] = "此任務實際上並不危險。這只是個測試。忽略它： " .. quest_warntightspace
    L["TEST_WARN_TITLE"] = "可移動測試警告"
    L["TEST_WARN_TEXT"] = "完全沒有警告！一切都很平靜。保證。這是個測試。真的。別驚慌！"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP"] = "關閉警告視窗"
    L["UNITSCAN_WARNING_CLOSE_TOOLTIP_TEXT"] = "按住 Shift 點擊以永久忽略此單位的警告。"
    L["UNITSCAN_CHAT_MESSAGE"] = "Unitscan 發現一個危險目標："
    L["UNITSCAN_WARNTITLE"] = "附近有危險："

    -- options
    L["OPT_DESCRIPTION_TOP_TITLE"] = "資訊"
    L["OPT_DESCRIPTION_TOP"] = "為低血量、氣喘吁吁、危險任務與敵人提供可配置的警報。\n\n你可以輕鬆自行擴充危險任務與單位的清單。更多細節請參閱你 addon 資料夾中的 README 檔案。\n此 addon 在 GPLv3 授權下為免費且開源。這表示你可以使用、修改與散佈此專案，但你所發布的任何修改都必須以 GPLv3 授權並包含原始碼。\n\n祝遊戲愉快並多加小心！"

    L["OPT_INFO"] = "所有更改會立即套用並儲存。"

    L["OPT_TEXT"] = "文字"
    L["OPT_FLASHING_SCREEN"] = "閃爍畫面"
    L["OPT_SOUND"] = "音效"
    L["OPT_SOUND_OFF"] = "關閉"
    L["OPT_SOUND_ONCE"] = "一次"
    L["OPT_SOUND_REPEATING"] = "重複播放"

    L["OPT_MINIMAP_ICON"] = "小地圖圖示"
    L["OPT_SHOW_MINIMAP"] = "顯示小地圖圖示"

    L["OPT_UI"] = "使用者介面"
    L["OPT_MOVABLE"] = "介面可移動"
    L["OPT_MOVABLE_DESC"] = "拖曳警告以調整位置。完成後請停用。"
    L["OPT_WARN_STYLE"] = "警告樣式"
    L["OPT_WARN_STYLE_DESC"] = "你希望警告以何種方式顯示？"
    L["OPT_WARN_STYLE_BORDER_BG"] = "邊框與背景"
    L["OPT_WARN_STYLE_ONLY_BG"] = "僅背景"
    L["OPT_WARN_STYLE_ONLY_TEXT"] = "僅文字"

    L["OPT_WARN_PREF"] = "警告偏好"
    L["OPT_BREATH_WARN"] = "呼吸警告"
    L["OPT_BREATH_WARN_DESC"] = "設定在呼吸快耗盡時如何提醒你。"
    L["OPT_HP_WARN"] = "生命值警告"
    L["OPT_HP_WARN_DESC"] = "設定在生命值低時如何提醒你。"
    L["OPT_PET_HP_WARN"] = "寵物生命警告"
    L["OPT_PET_HP_WARN_DESC"] = "變更當寵物生命值低時如何提醒你。"
    L["OPT_DANG_TARGET_WARN"] = "危險目標警告"
    L["OPT_DANG_TARGET_WARN_DESC"] = "設定當你選取一般目標（通常為高等級）時的提醒方式。"
    L["OPT_DANG_ELITE_WARN"] = "精英目標警告"
    L["OPT_DANG_ELITE_WARN_DESC"] = "設定當你選取精英目標時的提醒方式。"
    L["OPT_DANG_PVP_WARN"] = "敵方 PvP 玩家目標警告"
    L["OPT_DANG_PVP_WARN_DESC"] = "設定當你選取已被標記為 PvP 的敵方玩家時的提醒方式。"
    L["OPT_SELF_PVP_WARN"] = "\"你已被標記為 PvP\" 警告"
    L["OPT_SELF_PVP_WARN_DESC"] = "設定在你被標記為 PvP 時如何提醒你。"
    L["OPT_QUEST_WARN"] = "危險任務警告"
    L["OPT_QUEST_WARN_DESC"] = "設定當出現危險任務時如何提醒你。"
    L["OPT_UNITSCAN_WARN"] = "附近目標警告"
    L["OPT_UNITSCAN_WARN_DESC"] = "設定當附近發現危險目標時如何提醒你。"

    L["OPT_THRESHOLDS"] = "門檻"
    L["OPT_BREATH_LOW"] = "呼吸低（剩餘秒數）"
    L["OPT_BREATH_WARN_SEC"] = "警告（秒）"
    L["OPT_BREATH_WARN_SEC_DESC"] = "當剩餘呼吸秒數到達此數值時顯示一般警告"
    L["OPT_BREATH_PANIC_SEC"] = "緊急（秒）"
    L["OPT_BREATH_PANIC_SEC_DESC"] = "當剩餘呼吸秒數到達此數值時顯示緊急警告"

    L["OPT_HP_LOW"] = "生命值低（百分比）"
    L["OPT_HP_WARN_PCT"] = "警告（%）"
    L["OPT_HP_WARN_PCT_DESC"] = "當生命值百分比低於此值時顯示一般警告"
    L["OPT_HP_PANIC_PCT"] = "緊急（%）"
    L["OPT_HP_PANIC_PCT_DESC"] = "當生命值百分比低於此值時顯示緊急警告"
    L["OPT_PET_HP_LOW"] = "寵物生命低 (百分比)"

    L["OPT_LEVEL_DIFF"] = "等級差（你與目標之間）"
    L["OPT_LEVELDIFF_NORMAL"] = "一般目標警告"
    L["OPT_LEVELDIFF_NORMAL_DESC"] = "當你與一般目標的等級差達到此值時顯示一般警告"
    L["OPT_LEVELDIFF_ELITE"] = "精英目標警告"
    L["OPT_LEVELDIFF_ELITE_DESC"] = "當你與精英目標的等級差達到此值時顯示一般警告"
    L["OPT_LEVELDIFF_UNITSCAN"] = "附近目標警告門檻"
    L["OPT_LEVELDIFF_UNITSCAN_DESC"] = "掃描附近危險目標時，低於此等級差的單位將被忽略。"

    L["OPT_UNITSCAN"] = "掃描附近目標"
    L["OPT_UNITSCAN_DESC"] = "在戰鬥中掃描單位時，可能會發生一些小問題，例如你的自動攻擊被中斷。這是由於 WoW API 的限制。如果你啟用「戰鬥中掃描」，請同時在介面選項中啟用「協助時攻擊」，以免你的近戰自動攻擊被中斷！"
    L["OPT_UNITSCAN_ENABLE"] = "啟用掃描"
    L["OPT_UNITSCAN_ENABLE_DESC"] = "每隔幾秒掃描一次附近以檢查危險目標。"
    L["OPT_UNITSCAN_ENABLE_COMBAT"] = "戰鬥中掃描"
    L["OPT_UNITSCAN_ENABLE_COMBAT_DESC"] = "掃描會在戰鬥中繼續。請在介面選項中啟用「協助時攻擊」！"

    L["OPT_DEBUG"] = "除錯（一般使用請忽略）"
    L["OPT_DEBUG_OUTPUT"] = "除錯輸出"
    L["OPT_DEBUG_OUTPUT_DESC"] = "啟用除錯輸出"
    L["OPT_CHECK_LOOP_INT"] = "檢查循環間隔（秒）"
    L["OPT_CHECK_LOOP_INT_DESC"] = "預設值已足夠。只有在遇到效能問題時才更改。"

    L["OPT_CLEAR_IGNORED"] = "清除已忽略的警告"
    L["OPT_CLEAR_IGNORED_DESC"] = "重置你永久關閉/忽略的所有項目清單。像是針對特定任務或單位的警告。"
end