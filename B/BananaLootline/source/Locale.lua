--[[----------------------------------------------------------------------
  BananaLootline - Locale.lua

  Zwei Dinge stecken hier drin:

  1. UI-Strings (deDE / enUS)
  2. Die Tooltip-Patterns, mit denen Scanner.lua Stats aus einem Item liest.

  WICHTIG: Der 1.12-Client hat kein GetItemStats(). Der einzige zuverlaessige
  Weg, an die Werte eines Items zu kommen, ist den Tooltip in einen
  unsichtbaren Frame zu rendern und die Zeilen per String-Pattern zu parsen.
  Das ist zwangslaeufig sprachabhaengig.

  Die deDE-Patterns unten sind ein begruendeter Startsatz und muessen gegen
  einen echten deutschen Client verifiziert werden. Vorgehen: /bll debug
  ueber ein angelegtes Item laufen lassen - der Befehl dumpt alle rohen
  Tooltipzeilen ins Chatfenster. Was nicht gematcht wird, faellt sofort auf.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline

-- Zwei Sprachen, sauber getrennt:
--   clientLocale  Sprache des Spielclients. Bestimmt Tooltip-Muster und
--                 Rüstungsnamen, denn die liefert der Client. Nicht
--                 umschaltbar.
--   locale        Anzeigesprache des Addons. Folgt dem Client, bis der
--                 Nutzer oben rechts DE/EN waehlt.
BLL.clientLocale = GetLocale()
BLL.locale = BLL.clientLocale

------------------------------------------------------------------
-- UI-Strings
------------------------------------------------------------------

local L_enUS = {
  ["ADDON_NAME"]      = "BananaLootline",
  ["LOADED"]          = "loaded. Type /bll to open.",
  ["TITLE"]           = "BananaLootline",
  ["EMPTY"]           = "Empty",
  ["SOURCE"]          = "Source",
  ["SOURCES"]         = "Sources",
  ["DROPS_FROM"]      = "Drops from",
  ["OBJECT"]          = "Object",
  ["VENDOR"]          = "Vendor",
  ["QUEST"]           = "Quest",
  ["CHANCE"]          = "Chance",
  ["NO_SOURCE"]       = "No source data",
  ["NO_PFQUEST"]      = "pfQuest not found - source lookup disabled.",
  ["PFQUEST_OK"]      = "pfQuest database detected",
  ["PFQUEST_BUILTIN"] = "pfQuest not installed - using the built-in source data.",
  ["NO_ITEMDB"]       = "No item database imported yet (see tools/octodb_import.py).",
  ["SCAN_DONE"]       = "Gear scanned",
  ["TAB_GEAR"]        = "Gear",
  ["TAB_BAGS"]        = "Bags",
  ["TAB_INFO"]        = "Info",
  ["STATS_HEADER"]    = "Summed stats",
  ["NO_SPEC"]         = "no spec detected",
  ["NO_PFQUEST_SHORT"] = "pfQuest missing",
  ["LANG_TOOLTIP"]    = "Switch language",
  ["LANG_SWITCHED"]   = "Language set to English.",
  ["ABOUT_TOOLTIP"]   = "About this addon",
  ["THANKS_TITLE"]    = "Thank you for your support!",
  ["THANKS_BODY"]     = "This addon was built in many hours of spare time and stays free.\n\nIf you would like to say thanks, feel free to send me mail - gold, mats or just a few kind words always make my day.\n\n|cff888888Completely optional - the addon works just fine without it.|r",
  ["CHARACTER"]       = "Character:",
  ["FILL_NAME"]       = "Fill in name",
  ["CLOSE"]           = "Close",
  ["MAILBOX_OPEN"]    = "Mailbox open - one click fills in the name.",
  ["MAILBOX_CLOSED"]  = "Select and press Ctrl+C to copy the name. At a mailbox it is filled in automatically.",
  ["RECIPIENT_SET"]   = "Recipient",
  ["RECIPIENT_THANKS"] = "has been filled in. Thank you very much!",
  ["NEED_MAILBOX"]    = "You need to stand at a",
  ["MAILBOX"]         = "mailbox",
  ["NEED_MAILBOX_2"]  = "for that. You can also select the name and copy it with Ctrl+C.",

  -- ---- Statusmeldungen: Start und Datenbanken ----
  ["MIGRATED"]        = "Settings carried over from OctoLootline.",
  ["ITEMDB_BROKEN"]   = "ItemDB.lua is missing or was overwritten. The import target is Data/ItemData.lua, not ItemDB.lua!",
  ["ITEMDB_LOADED"]   = "ItemDB: %d items loaded",
  ["SETDB_LOADED"]    = "SetDB: %d sets loaded",
  ["ITEMDB_NONE"]     = "not imported",
  ["YES"]             = "yes",
  ["NO"]              = "no",
  ["ON"]              = "on",
  ["OFF"]             = "off",

  -- ---- Kandidatensuche ----
  ["CAND_NO_PFQUEST"] = "pfQuest missing - no suggestions without the database.",
  ["CAND_SEARCHING"]  = "Searching candidates for level %d-%d ...",
  ["CAND_FOUND"]      = "%d candidates found. Fetching item data ...",
  ["CAND_FOUND_MIX"]  = "%d candidates found (%d with location, %d from the import). Fetching item data ...",
  ["CAND_IMPORT"]     = "Import evaluated: %d items filtered out (wrong slot, wrong armor type or level too high).",
  ["CAND_CACHED"]     = "All item data already cached. Done.",
  ["CAND_REQUEST"]    = "%d unknown items, requesting them (approx. %d seconds). Runs in the background, /bll stop aborts.",
  ["CAND_ROUND2"]     = "%d items still open, second round.",
  ["CAND_DONE"]       = "Done: %d items read%s.",
  ["CAND_MISSING"]    = ", %d not found",
  ["CAND_IDLE"]       = "Nothing is running right now.",
  ["CAND_ABORTED"]    = "Aborted. %d items are saved and will be kept.",

  -- ---- Fortschritt im Fenster ----
  ["PROG_INDEX"]      = "Searching database ...",
  ["PROG_REQUEST"]    = "Requesting items: %d/%d (round %d)",
  ["PROG_WAIT"]       = "Waiting for server replies (%.0fs)",
  ["PROG_COLLECT"]    = "Evaluating replies ...",

  -- ---- Slash-Befehle ----
  ["DEBUG_STATE"]     = "Debug: %s",
  ["USAGE_DUMP"]      = "Usage: /bll dump <itemID>",
  ["USAGE_SRC"]       = "Usage: /bll src <itemID>",
  ["USAGE_WHY"]       = "Usage: /bll why <itemID> - shows why an item is or is not suggested.",
  ["HELP_WHY"]        = "why is an item (not) suggested",
  ["WHY_HEADER"]      = "Diagnosis for item %d:",
  ["MINIMAP_TIP"]     = "Click: open or close the window. Drag: move the button.",
  ["ST_SRC_COUNT"]    = "%d items, %d NPCs, %d zones",
  ["ST_SRC_NONE"]     = "missing - locations come from pfQuest",
  ["NEW_SLOT"]        = "NEW",
  ["AHEAD_HINT"]      = "Raise level range",
  ["QUEST_LEVEL"]     = "Quest level %d",
  ["QUEST_ONE_OF"]    = "1 of %d",
  ["WT_TITLE"]        = "Stat weights",
  ["WT_TIP"]          = "Edit the stat weights for this character. They decide which items rank as upgrades.",
  ["WT_PRESET"]       = "Preset",
  ["WT_PRESET_NONE"]  = "current",
  ["WT_APPLY"]        = "Apply",
  ["WT_RESET"]        = "Reset to spec",
  ["WT_HINT"]         = "Orange values differ from your spec, the spec value is in brackets. Saved for this character only.",
  ["WT_SAVED"]        = "Your stat weights are saved for this character.",
  ["WT_SAME"]         = "The weights match your spec, using the spec weights.",
  ["WT_G_PRIMARY"]    = "Attributes",
  ["WT_G_ATTACK"]     = "Physical",
  ["WT_G_SPELL"]      = "Spells",
  ["WT_G_DEFENSE"]    = "Defense",
  ["WT_G_RESIST"]     = "Resistances",
  ["EX_TITLE"]        = "Extras",
  ["EX_TIP"]          = "Class and profession trainers: what you can learn now and what comes next. The number shows how much is learnable right now.",
  ["TR_CLASS"]        = "Class trainer",
  ["TR_PROF"]         = "Profession trainers",
  ["TR_NOVISIT"]      = "Visit your class trainer once - from then on I know which spells come at which level.",
  ["TR_PROF_NOVISIT"] = "Visit a profession trainer once to see upcoming recipes here.",
  ["TR_NOW"]          = "Learnable now: %d (%s)",
  ["TR_NOTHING"]      = "Nothing new to learn right now.",
  ["TR_LEVEL"]        = "Level %d",
  ["TR_SKILL"]        = "skill %d",
  ["TR_LEARNABLE"]    = "%d learnable",
  ["TR_TIP_LEVEL"]    = "Requires level %d",
  ["TR_TIP_SKILL"]    = "Requires skill %d",
  ["TR_TIP_COST"]     = "Cost: %s",
  ["TR_TIP_NODESC"]   = "No description yet - it is read on your next trainer visit.",
  ["TR_VISIT"]        = "Last visit: level %d, %s",
  ["TR_CLASS_NEW"]    = "New at your class trainer: %d spell(s), %s.",
  ["TR_CLASS_GUESS"]  = "New level - there are probably new spells at your class trainer. Visit once and I can tell exactly.",
  ["TR_PROF_NEW"]     = "%s: %d new recipe(s) at the trainer.",
  ["SRC_TITLE"]       = "Sources",
  ["SRC_TIP"]         = "Choose which kinds of sources are suggested. Several can be ticked. Applies to Lootline and Per item.",
  ["SRC_BUTTON"]      = "Sources: %s",
  ["SRC_ALL"]         = "All",
  ["SRC_NONE"]        = "none",
  ["SRC_N"]           = "%d of %d",
  ["SRC_DUNGEON"]     = "Dungeon",
  ["SRC_RAID"]        = "Raid",
  ["SRC_QUEST"]       = "Quest",
  ["SRC_WELT"]        = "World",
  ["SRC_SCHLACHTFELD"] = "Battleground",
  ["SRC_WELTBOSS"]    = "World boss",
  ["SRC_HAENDLER"]    = "Vendor",
  ["SRC_NOSOURCE"]    = "No source",
  ["SRC_LIGHTER_ARMOR"] = "+ Lighter armor (e.g. cloth for hunters)",
  ["AHEAD_NOW"]       = "now: up to level %d",
  ["ILVL_SET"]        = "Item level filter: %d to %d. Only items in this range are suggested.",
  ["ILVL_MIN"]        = "Item level filter: from %d.",
  ["ILVL_OFF"]        = "Item level filter is off.",
  ["USAGE_ILVL"]      = "Usage: /bll ilvl 60-80, /bll ilvl 60 (minimum only), /bll ilvl off",
  ["HELP_ILVL"]       = "limit suggestions to an item level range",
  ["CUSTOM_WEIGHTS"]  = "custom weights",
  ["CUSTOM_WEIGHTS_NOTE"] = "Your own weights (/bll weight) are active and override the spec. /bll weight reset returns to class and spec weights.",
  ["REQ_LEVEL"]       = "Requires level %d",
  ["QI_TITLE"]        = "Quest",
  ["QI_CHAIN"]        = "Quest chain with %d steps, in this order:",
  ["QI_FROM"]         = "from level %d",
  ["QI_LEVEL"]        = "quest level %d",
  ["QI_REWARD"]       = "reward",
  ["QI_START"]        = "Accept:",
  ["QI_END"]          = "Turn in:",
  ["QI_ALT"]          = "There is another prerequisite (often the same quest for the other faction).",
  ["QI_CHOICE"]       = "Choose one of these rewards:",
  ["QI_UNKNOWN"]      = "No details known for this quest.",
  ["QI_MAP"]          = "Show on map",
  ["QI_NOMAP"]        = "Showing on the map needs pfQuest.",
  ["QI_CLICK"]        = "Click: show quest chain",
  ["MINIMAP_SHOWN"]   = "Minimap button shown.",
  ["MINIMAP_HIDDEN"]  = "Minimap button hidden. /bll minimap shows it again.",
  ["HELP_MINIMAP"]    = "show or hide the minimap button",
  ["USAGE_SET"]       = "Usage: /bll set <itemID> - shows set and bonuses of the item",
  ["SRC_HEADER"]      = "Sources for item %d:",
  ["WEIGHTS_RESET"]   = "Stat weights reset.",
  ["WEIGHT_SET"]      = "Weight %s = %s",
  ["WEIGHT_REMOVED"]  = "removed",
  ["WEIGHTS_CURRENT"] = "Current weights:",
  ["NO_SETDATA"]      = "No set data loaded.",
  ["ITEM_NO_SET"]     = "Item %d belongs to no set.",
  ["SET_WORN"]        = "%s - %d/%d worn",
  ["SET_ACTIVE"]      = "active",
  ["SET_INACTIVE"]    = "inactive",
  ["USECD_SET"]       = "Assumed cooldown for use effects: %d seconds",
  ["USECD_INFO"]      = "Assumed cooldown: %d seconds. Change with /bll usecd <seconds>. The database provides none, so it is estimated.",
  ["RATE_SET"]        = "Query rate: %d items/second",
  ["RATE_INFO"]       = "Current query rate: %d items/second. Change with /bll rate <1-30>. Higher values put more load on the server.",
  ["CACHE_CLEARED"]   = "Item cache cleared.",
  ["UNUSED_STATE"]    = "Unreachable sources (developer entries, 0%% drop): %s",
  ["UNUSED_SHOWN"]    = "are shown",
  ["UNUSED_HIDDEN"]   = "are hidden",
  ["REOPEN_WINDOW"]   = "Reopen the window for it to take effect.",
  ["USAGE_CAT"]       = "Usage: /bll cat <zone name> <dungeon|raid|world|worldboss|battleground|quest|vendor|object>",
  ["CAT_EXAMPLE"]     = "Example: /bll cat Concavius worldboss",
  ["CAT_OWN"]         = "Your own assignments:",
  ["CAT_UNKNOWN"]     = "Unknown category: %s",
  ["CAT_SET"]         = "%s now counts as %s. Reopen the window.",
  ["AHEAD_SET"]       = "Planning ahead: %d levels. The search now covers level %d-%d. Search again with /bll up.",
  ["AHEAD_INFO"]      = "Planning ahead: %d levels - that is what /bll up searches. Change with /bll ahead <0-60>, 0 shows only what you can wear right now.",
  ["SPEC_NONE"]       = "No spec detected (%d talent points spent, %d needed). Class weights apply.",
  ["SPEC_FOUND"]      = "Spec: %s (%d points total)",
  ["SPEC_SET"]        = "Spec set manually: %s. |cff888888/bll spec auto|r returns to detection.",
  ["SPEC_AUTO"]       = "Spec is detected automatically again.",
  ["SPEC_BAD"]        = "Unknown spec: %s. Use 1, 2, 3, a spec name or auto.",
  ["SPEC_MANUAL"]     = "manual",
  ["SPEC_MENU_AUTO"]  = "Automatic",
  ["SPEC_MENU_TITLE"] = "Spec",
  ["SPEC_TIP"]        = "Click to choose your spec. Automatic reads it from your talents (from 10 points on).",
  ["INFO_LINE"]       = "pfQuest: %s | ItemDB: %s | Language: %s",

  -- ---- Hilfe ----
  ["HELP_HEADER"]     = "Commands:",
  ["HELP_MAIN"]       = "open/close the window",
  ["HELP_LANG"]       = "display language",
  ["HELP_UP"]         = "search for upgrades (n = level span, default from /bll ahead)",
  ["HELP_STOP"]       = "abort a running query",
  ["HELP_RATE"]       = "query rate in items/second (default 8)",
  ["HELP_FORGET"]     = "clear the item cache",
  ["HELP_SPEC"]       = "show detected spec",
  ["HELP_SPEC_SET"]   = "choose spec manually, auto = detect",
  ["HELP_AHEAD"]      = "how many levels to plan ahead",
  ["HELP_CAT"]        = "reassign a location",
  ["HELP_UNUSED"]     = "show/hide unreachable sources",
  ["HELP_WEIGHT"]     = "show stat weights",
  ["HELP_WEIGHT_SET"] = "set a weight",
  ["HELP_WEIGHT_RST"] = "reset weights",
  ["HELP_SCAN"]       = "rescan gear and print it",
  ["HELP_DUMP"]       = "show raw tooltip lines of an item",
  ["HELP_TIP"]        = "compare tooltip read methods for one item",
  ["ST_TITLE"]        = "Self check %s",
  ["ST_LANG"]         = "Client language %s, display %s",
  ["ST_PATTERNS"]     = "Tooltip patterns: %s",
  ["ST_PATTERNS_NOTE"] = "(follows the client, not the switch)",
  ["ST_PFQUEST_NOTE"] = "- without it there are no locations",
  ["ST_PFQUEST_MISSING"] = "not installed (optional, built-in source data is used)",
  ["ST_ITEMDB_COUNT"] = "%d entries",
  ["ST_GEAR"]         = "Gear: %d of %d pieces with readable stats",
  ["ST_NO_STATS"]     = "Not a single stat read. That points to tooltip patterns that do not match the client language.",
  ["ST_WITHOUT"]      = "without stats: %s",
  ["ST_WITHOUT_NOTE"] = "(normal for trinkets and cloaks that have none)",
  ["ST_TOOLTIP"]      = "Tooltip readable: %d lines from \"%s\"",
  ["ST_TOOLTIP_BAD"]  = "Too few lines - the scan tooltip does not return what the game shows.",
  ["ST_BAND"]         = "Search range %d-%d, planning ahead %d",
  ["ST_POOL"]         = "Pool %d",
  ["ST_POOL_LOC"]     = "(%d with location)",
  ["ST_NOSEARCH"]     = "Not searched yet - /bll up",
  ["CAND_ERROR"]      = "Search stopped with an error in step \"%s\": %s",
  ["CAND_ERROR_HINT"] = "Please send a screenshot of this line and of /bll selftest.",
  ["PROG_FAILED"]     = "Search failed - see chat",
  ["ST_DIAG_PFQ"]     = "pfQuest: %d of %d items in the search range",
  ["ST_DIAG_IMPORT"]  = "Import: %d items in the search range",
  ["ST_DIAG_STATE"]   = "Search state: %s",
  ["ST_DIAG_STUCK"]   = "- stuck, no progress for %.0fs",
  ["ST_DIAG_EMPTY"]   = "The last search collected nothing although items are in range.",
  ["ST_DIAG_FAIL"]    = "Diagnosis failed: %s",
  ["ST_OK"]           = "Nothing unusual.",
  ["ST_WARN"]         = "%d item(s) to look at - please report the lines marked red.",
  ["USAGE_TIP"]       = "Usage: /bll tip <itemID>",
  ["USAGE_ITEM"]      = "Usage: /bll item <itemID>",
  ["ITEM_NOCACHE"]    = "No cache entry for %d",
  ["ITEM_HINT"]       = "(run /bll up first, then try again)",
  ["ITEM_HEAD"]       = "Cache %d: %s",
  ["ITEM_LEVEL"]      = "Level    ",
  ["ITEM_SLOT"]       = "Slot     ",
  ["ITEM_ORIGIN"]     = "Origin   ",
  ["ITEM_LOCK"]       = "Locked   ",
  ["ITEM_STATS"]      = "Stats    ",
  ["ITEM_IMPORT"]     = "import",
  ["ITEM_SERVER"]     = "server",
  ["ITEM_NONE"]       = "none",
  ["HOOKS_HEAD"]      = "Active addons that may extend tooltips:",
  ["HOOKS_NONE"]      = "none detected",
  ["HOOKS_TOTAL"]     = "%d addons in total",
  ["HELP_ITEM"]       = "show the cached entry of an item",
  ["HELP_HOOKS"]      = "list addons that may extend tooltips",
  ["TIP_COMPARE"]     = "Tooltip comparison for %s",
  ["TIP_HINT"]        = "For comparison: hover the item in game and see which lines are missing here.",
  ["DUMP_LINES"]      = "Tooltip lines:",
  ["DUMP_FOUND"]      = "Parsed: %s",
  ["DUMP_NOTHING"]    = "nothing",
  ["HELP_SELFTEST"]   = "check patterns, languages and data sources",
  ["HELP_ZONE"]       = "name a place the data does not know",
  ["AHEAD_TITLE"]     = "Forward planning",
  ["AHEAD_TIP"]       = "How many levels above your own the search reaches. 0 shows only what you can equip right now.",
  ["INFO_DATA"]       = "Sources: %d items, %d NPCs, %d zones",
  ["ZONE_SET"]        = "Zone %s is now called \"%s\".",
  ["ZONE_CLEARED"]    = "Zone %s reset to the bundled name.",
  ["USAGE_ZONE"]      = "Usage: /bll zone <id> <name>  -  /bll zone <id> clears it",
  ["HELP_PHASE"]      = "show content phases, open one by hand",
  ["USAGE_PHASE"]     = "Usage: /bll phase  -  /bll phase <no> on|off|auto",
  ["PHASE_HEADER"]    = "Content phases (source: octowow.st/roadmap)",
  ["PHASE_OPEN"]      = "open",
  ["PHASE_CLOSED"]    = "not yet open",
  ["PHASE_BYHAND"]    = "set by hand",
  ["PHASE_SET"]       = "Phase %d is now %s.",
  ["PHASE_AUTO"]      = "Phase %d follows its release date again.",
  ["PHASE_NODATE"]    = "The client gives no date. Every phase counts as closed until you open it with /bll phase <no> on.",
  ["INFO_PHASE"]      = "Phases: %d of %d open, %d zones locked",
  ["HELP_SRC"]        = "show sources of an item",
  ["HELP_SET"]        = "set and bonuses of an item",
  ["HELP_USECD"]      = "assumed cooldown for use effects",
  ["HELP_INFO"]       = "status line",
  ["HELP_DEBUG"]      = "toggle debug output",

  -- ---- Herkunft eines Kandidaten ----
  ["NO_LOCATION_YET"] = "no known location",
  ["LOCKED_ITEM"]     = "not freely available",
  ["CAT_DUNGEON"]     = "DUNGEON",
  ["CAT_RAID"]        = "RAID",
  ["CAT_QUEST"]       = "QUEST",
  ["CAT_VENDOR"]      = "VENDOR",
  ["CAT_OBJECT"]      = "OBJECT",
  ["CAT_WORLDBOSS"]   = "WORLD BOSS",
  ["CAT_PVP"]         = "PVP",
  ["CAT_WORLD"]       = "WORLD",
  ["NO_ROUTE"]        = "No route yet. Click \"Find upgrades\" below.",
  ["LOOT_QUESTS"]     = "Quests",
  ["LOCKED_STATE"]    = "Items with a reputation or rank requirement: %s",
  ["LOCKED_SHOWN"]    = "are shown",
  ["LOCKED_HIDDEN"]   = "are hidden",
  ["DUMP_LOCKED"]     = "Access requirement:",
  ["HELP_LOCKED"]     = "show/hide items needing reputation or rank",
  ["UNSCORED_EQUIPPED"] = "effect not scored",
  ["UNSCORED_HINT"]   = "The equipped item has an effect the addon cannot put a number on. Close suggestions are held back - they would be guesses.",
  ["UNSCORED_SHORT"]  = "comparison incomplete",
  ["DUMP_UNSCORED"]   = "Not scored:",
}

local L_deDE = {
  ["ADDON_NAME"]      = "BananaLootline",
  ["LOADED"]          = "geladen. /bll zum Oeffnen.",
  ["TITLE"]           = "BananaLootline",
  ["EMPTY"]           = "Leer",
  ["SOURCE"]          = "Quelle",
  ["SOURCES"]         = "Quellen",
  ["DROPS_FROM"]      = "Droppt von",
  ["OBJECT"]          = "Objekt",
  ["VENDOR"]          = "Haendler",
  ["QUEST"]           = "Quest",
  ["CHANCE"]          = "Chance",
  ["NO_SOURCE"]       = "Keine Quellendaten",
  ["NO_PFQUEST"]      = "pfQuest nicht gefunden - Quellensuche deaktiviert.",
  ["PFQUEST_OK"]      = "pfQuest-Datenbank erkannt",
  ["PFQUEST_BUILTIN"] = "pfQuest nicht installiert - nutze die eingebauten Fundorte.",
  ["NO_ITEMDB"]       = "Noch keine Itemdatenbank importiert (siehe tools/octodb_import.py).",
  ["SCAN_DONE"]       = "Ausruestung gescannt",
  ["TAB_GEAR"]        = "Ausruestung",
  ["TAB_BAGS"]        = "Taschen",
  ["TAB_INFO"]        = "Info",
  ["STATS_HEADER"]    = "Summierte Werte",
  ["NO_SPEC"]         = "keine Spez. erkannt",
  ["NO_PFQUEST_SHORT"] = "pfQuest fehlt",
  ["LANG_TOOLTIP"]    = "Sprache umschalten",
  ["LANG_SWITCHED"]   = "Sprache auf Deutsch gestellt.",
  ["ABOUT_TOOLTIP"]   = "Ueber dieses Addon",
  ["THANKS_TITLE"]    = "Danke fuer die Unterstuetzung!",
  ["THANKS_BODY"]     = "Dieses Addon ist in vielen Stunden Freizeit entstanden und bleibt kostenlos.\n\nWer sich bedanken moechte, kann mir gerne Post schicken - ueber Gold, Mats oder auch nur ein paar nette Worte freue ich mich immer.\n\n|cff888888Voellig freiwillig - das Addon funktioniert auch ohne komplett.|r",
  ["CHARACTER"]       = "Charakter:",
  ["FILL_NAME"]       = "Namen eintragen",
  ["CLOSE"]           = "Schliessen",
  ["MAILBOX_OPEN"]    = "Briefkasten offen - ein Klick traegt den Namen ein.",
  ["MAILBOX_CLOSED"]  = "Markieren und Strg+C kopiert den Namen. Am Briefkasten wird er per Knopfdruck eingetragen.",
  ["RECIPIENT_SET"]   = "Empfaenger",
  ["RECIPIENT_THANKS"] = "wurde eingetragen. Vielen Dank!",
  ["NEED_MAILBOX"]    = "Dafuer musst du an einem",
  ["MAILBOX"]         = "Briefkasten",
  ["NEED_MAILBOX_2"]  = "stehen. Der Name laesst sich aber auch markieren und mit Strg+C kopieren.",

  -- ---- Statusmeldungen: Start und Datenbanken ----
  ["MIGRATED"]        = "Einstellungen aus OctoLootline uebernommen.",
  ["ITEMDB_BROKEN"]   = "ItemDB.lua fehlt oder wurde ueberschrieben. Importziel ist Data/ItemData.lua, nicht ItemDB.lua!",
  ["ITEMDB_LOADED"]   = "ItemDB: %d Items geladen",
  ["SETDB_LOADED"]    = "SetDB: %d Sets geladen",
  ["ITEMDB_NONE"]     = "nicht importiert",
  ["YES"]             = "ja",
  ["NO"]              = "nein",
  ["ON"]              = "an",
  ["OFF"]             = "aus",

  -- ---- Kandidatensuche ----
  ["CAND_NO_PFQUEST"] = "pfQuest fehlt - ohne die Datenbank keine Vorschlaege.",
  ["CAND_SEARCHING"]  = "Suche Kandidaten fuer Stufe %d-%d ...",
  ["CAND_FOUND"]      = "%d Kandidaten gefunden. Hole Itemdaten ...",
  ["CAND_FOUND_MIX"]  = "%d Kandidaten gefunden (%d mit Fundort, %d aus dem Import). Hole Itemdaten ...",
  ["CAND_IMPORT"]     = "Import ausgewertet: %d Items aussortiert (falscher Slot, falsche Ruestungsart oder Stufe zu hoch).",
  ["CAND_CACHED"]     = "Alle Itemdaten bereits im Cache. Fertig.",
  ["CAND_REQUEST"]    = "%d unbekannte Items, frage sie an (ca. %d Sekunden). Laeuft im Hintergrund, /bll stop bricht ab.",
  ["CAND_ROUND2"]     = "%d Items noch offen, zweite Runde.",
  ["CAND_DONE"]       = "Fertig: %d Items eingelesen%s.",
  ["CAND_MISSING"]    = ", %d nicht auffindbar",
  ["CAND_IDLE"]       = "Es laeuft gerade nichts.",
  ["CAND_ABORTED"]    = "Abgebrochen. %d Items sind gespeichert und bleiben erhalten.",

  -- ---- Fortschritt im Fenster ----
  ["PROG_INDEX"]      = "Durchsuche Datenbank ...",
  ["PROG_REQUEST"]    = "Frage Items an: %d/%d (Runde %d)",
  ["PROG_WAIT"]       = "Warte auf Serverantworten (%.0fs)",
  ["PROG_COLLECT"]    = "Werte Antworten aus ...",

  -- ---- Slash-Befehle ----
  ["DEBUG_STATE"]     = "Debug: %s",
  ["USAGE_DUMP"]      = "Nutzung: /bll dump <itemID>",
  ["USAGE_SRC"]       = "Nutzung: /bll src <itemID>",
  ["USAGE_WHY"]       = "Nutzung: /bll why <itemID> - zeigt, warum ein Teil vorgeschlagen wird oder nicht.",
  ["HELP_WHY"]        = "warum wird ein Teil (nicht) vorgeschlagen",
  ["WHY_HEADER"]      = "Diagnose fuer Item %d:",
  ["MINIMAP_TIP"]     = "Klick: Fenster oeffnen oder schliessen. Ziehen: Knopf verschieben.",
  ["ST_SRC_COUNT"]    = "%d Items, %d NPCs, %d Zonen",
  ["ST_SRC_NONE"]     = "fehlt - Fundorte kommen aus pfQuest",
  ["NEW_SLOT"]        = "NEU",
  ["AHEAD_HINT"]      = "Levelrange erhoehen",
  ["QUEST_LEVEL"]     = "Questlevel %d",
  ["QUEST_ONE_OF"]    = "1 von %d",
  ["WT_TITLE"]        = "Statgewichte",
  ["WT_TIP"]          = "Statgewichte fuer diesen Charakter bearbeiten. Sie entscheiden, welche Items als Upgrade gelten.",
  ["WT_PRESET"]       = "Vorlage",
  ["WT_PRESET_NONE"]  = "aktuell",
  ["WT_APPLY"]        = "Uebernehmen",
  ["WT_RESET"]        = "Spec-Werte",
  ["WT_HINT"]         = "Orange Werte weichen von der Spec ab, der Spec-Wert steht in Klammern. Gilt nur fuer diesen Charakter.",
  ["WT_SAVED"]        = "Deine Statgewichte sind fuer diesen Charakter gespeichert.",
  ["WT_SAME"]         = "Die Werte entsprechen der Spec, es gelten die Spec-Gewichte.",
  ["WT_G_PRIMARY"]    = "Attribute",
  ["WT_G_ATTACK"]     = "Physisch",
  ["WT_G_SPELL"]      = "Zauber",
  ["WT_G_DEFENSE"]    = "Verteidigung",
  ["WT_G_RESIST"]     = "Widerstaende",
  ["EX_TITLE"]        = "Extras",
  ["EX_TIP"]          = "Klassen- und Berufslehrer: was jetzt lernbar ist und was als Naechstes kommt. Die Zahl zeigt, wie viel jetzt lernbar ist.",
  ["TR_CLASS"]        = "Klassenlehrer",
  ["TR_PROF"]         = "Berufslehrer",
  ["TR_NOVISIT"]      = "Einmal zum Klassenlehrer gehen - danach weiss ich, welche Zauber auf welcher Stufe kommen.",
  ["TR_PROF_NOVISIT"] = "Einmal einen Berufslehrer besuchen, dann stehen hier die kommenden Rezepte.",
  ["TR_NOW"]          = "Jetzt lernbar: %d (%s)",
  ["TR_NOTHING"]      = "Gerade nichts Neues zu lernen.",
  ["TR_LEVEL"]        = "Stufe %d",
  ["TR_SKILL"]        = "Fertigkeit %d",
  ["TR_LEARNABLE"]    = "%d lernbar",
  ["TR_TIP_LEVEL"]    = "Benoetigt Stufe %d",
  ["TR_TIP_SKILL"]    = "Benoetigt Fertigkeit %d",
  ["TR_TIP_COST"]     = "Kosten: %s",
  ["TR_TIP_NODESC"]   = "Noch keine Beschreibung - sie wird beim naechsten Lehrerbesuch gelesen.",
  ["TR_VISIT"]        = "Letzter Besuch: Stufe %d, %s",
  ["TR_CLASS_NEW"]    = "Neu beim Klassenlehrer: %d Zauber, %s.",
  ["TR_CLASS_GUESS"]  = "Neue Stufe - beim Klassenlehrer gibt es vermutlich neue Zauber. Einmal hingehen, dann weiss ich es genau.",
  ["TR_PROF_NEW"]     = "%s: %d neue(s) Rezept(e) beim Lehrer.",
  ["SRC_TITLE"]       = "Quellen",
  ["SRC_TIP"]         = "Welche Arten von Quellen vorgeschlagen werden. Mehrere moeglich. Gilt fuer Lootline und Pro Item.",
  ["SRC_BUTTON"]      = "Quellen: %s",
  ["SRC_ALL"]         = "Alle",
  ["SRC_NONE"]        = "keine",
  ["SRC_N"]           = "%d von %d",
  ["SRC_DUNGEON"]     = "Dungeon",
  ["SRC_RAID"]        = "Raid",
  ["SRC_QUEST"]       = "Quest",
  ["SRC_WELT"]        = "Welt",
  ["SRC_SCHLACHTFELD"] = "Schlachtfeld",
  ["SRC_WELTBOSS"]    = "Weltboss",
  ["SRC_HAENDLER"]    = "Haendler",
  ["SRC_NOSOURCE"]    = "Ohne Fundort",
  ["SRC_LIGHTER_ARMOR"] = "+ Leichtere Ruestung (z. B. Stoff fuer Jaeger)",
  ["AHEAD_NOW"]       = "jetzt: bis Stufe %d",
  ["ILVL_SET"]        = "Itemlevel-Filter: %d bis %d. Vorgeschlagen werden nur Teile in diesem Bereich.",
  ["ILVL_MIN"]        = "Itemlevel-Filter: ab %d.",
  ["ILVL_OFF"]        = "Itemlevel-Filter ist aus.",
  ["USAGE_ILVL"]      = "Nutzung: /bll ilvl 60-80, /bll ilvl 60 (nur Untergrenze), /bll ilvl off",
  ["HELP_ILVL"]       = "Vorschlaege auf einen Itemlevel-Bereich begrenzen",
  ["CUSTOM_WEIGHTS"]  = "eigene Gewichte",
  ["CUSTOM_WEIGHTS_NOTE"] = "Eigene Gewichte (/bll weight) sind aktiv und gehen der Spezialisierung vor. /bll weight reset kehrt zu Klassen- und Spec-Gewichten zurueck.",
  ["REQ_LEVEL"]       = "Benoetigt Stufe %d",
  ["QI_TITLE"]        = "Quest",
  ["QI_CHAIN"]        = "Questreihe mit %d Schritten, in dieser Reihenfolge:",
  ["QI_FROM"]         = "ab Stufe %d",
  ["QI_LEVEL"]        = "Questlevel %d",
  ["QI_REWARD"]       = "Belohnung",
  ["QI_START"]        = "Annehmen:",
  ["QI_END"]          = "Abgeben:",
  ["QI_ALT"]          = "Es gibt eine weitere Vorquest (oft dieselbe fuer die andere Fraktion).",
  ["QI_CHOICE"]       = "Eine dieser Belohnungen waehlen:",
  ["QI_UNKNOWN"]      = "Zu dieser Quest sind keine Einzelheiten bekannt.",
  ["QI_MAP"]          = "Auf Karte zeigen",
  ["QI_NOMAP"]        = "Die Kartenanzeige braucht pfQuest.",
  ["QI_CLICK"]        = "Klick: Questreihe anzeigen",
  ["MINIMAP_SHOWN"]   = "Minimap-Knopf eingeblendet.",
  ["MINIMAP_HIDDEN"]  = "Minimap-Knopf ausgeblendet. /bll minimap blendet ihn wieder ein.",
  ["HELP_MINIMAP"]    = "Minimap-Knopf ein- oder ausblenden",
  ["USAGE_SET"]       = "Nutzung: /bll set <itemID> - zeigt Set und Boni des Items",
  ["SRC_HEADER"]      = "Quellen fuer Item %d:",
  ["WEIGHTS_RESET"]   = "Statgewichte zurueckgesetzt.",
  ["WEIGHT_SET"]      = "Gewicht %s = %s",
  ["WEIGHT_REMOVED"]  = "entfernt",
  ["WEIGHTS_CURRENT"] = "Aktuelle Gewichte:",
  ["NO_SETDATA"]      = "Keine Setdaten geladen.",
  ["ITEM_NO_SET"]     = "Item %d gehoert zu keinem Set.",
  ["SET_WORN"]        = "%s - %d/%d getragen",
  ["SET_ACTIVE"]      = "aktiv",
  ["SET_INACTIVE"]    = "inaktiv",
  ["USECD_SET"]       = "Angenommene Abklingzeit fuer Use-Effekte: %d Sekunden",
  ["USECD_INFO"]      = "Angenommene Abklingzeit: %d Sekunden. Aendern mit /bll usecd <sekunden>. Die Datenbank liefert keine, deshalb wird geschaetzt.",
  ["RATE_SET"]        = "Abfragerate: %d Items/Sekunde",
  ["RATE_INFO"]       = "Aktuelle Abfragerate: %d Items/Sekunde. Aendern mit /bll rate <1-30>. Hoehere Werte belasten den Server staerker.",
  ["CACHE_CLEARED"]   = "Itemcache geleert.",
  ["UNUSED_STATE"]    = "Unerreichbare Quellen (Entwicklereintraege, 0%% Drop): %s",
  ["UNUSED_SHOWN"]    = "werden angezeigt",
  ["UNUSED_HIDDEN"]   = "werden ausgeblendet",
  ["REOPEN_WINDOW"]   = "Fenster neu oeffnen, damit es wirkt.",
  ["USAGE_CAT"]       = "Nutzung: /bll cat <Zonenname> <dungeon|raid|welt|weltboss|schlachtfeld|quest|haendler|objekt>",
  ["CAT_EXAMPLE"]     = "Beispiel: /bll cat Concavius weltboss",
  ["CAT_OWN"]         = "Eigene Zuordnungen:",
  ["CAT_UNKNOWN"]     = "Unbekannte Kategorie: %s",
  ["CAT_SET"]         = "%s gilt jetzt als %s. Fenster neu oeffnen.",
  ["AHEAD_SET"]       = "Vorausplanung: %d Stufen. Die Suche umfasst jetzt Stufe %d-%d. Neu suchen mit /bll up.",
  ["AHEAD_INFO"]      = "Vorausplanung: %d Stufen - so weit sucht /bll up. Aendern mit /bll ahead <0-60>, 0 zeigt nur sofort Tragbares.",
  ["SPEC_NONE"]       = "Keine Spezialisierung erkannt (%d Talentpunkte vergeben, noetig sind %d). Es gelten die Klassenwerte.",
  ["SPEC_FOUND"]      = "Spezialisierung: %s (%d Punkte gesamt)",
  ["SPEC_SET"]        = "Spezialisierung von Hand gesetzt: %s. |cff888888/bll spec auto|r schaltet zurueck auf Erkennung.",
  ["SPEC_AUTO"]       = "Spezialisierung wird wieder automatisch erkannt.",
  ["SPEC_BAD"]        = "Unbekannte Spezialisierung: %s. Moeglich sind 1, 2, 3, ein Name oder auto.",
  ["SPEC_MANUAL"]     = "manuell",
  ["SPEC_MENU_AUTO"]  = "Automatisch",
  ["SPEC_MENU_TITLE"] = "Spezialisierung",
  ["SPEC_TIP"]        = "Klicken, um die Spezialisierung zu waehlen. Automatisch liest sie aus den Talenten (ab 10 Punkten).",
  ["INFO_LINE"]       = "pfQuest: %s | ItemDB: %s | Sprache: %s",

  -- ---- Hilfe ----
  ["HELP_HEADER"]     = "Befehle:",
  ["HELP_MAIN"]       = "Fenster oeffnen/schliessen",
  ["HELP_LANG"]       = "Anzeigesprache",
  ["HELP_UP"]         = "Upgrades suchen (n = Stufenspanne, Standard aus /bll ahead)",
  ["HELP_STOP"]       = "laufende Abfrage abbrechen",
  ["HELP_RATE"]       = "Abfragerate in Items/Sekunde (Standard 8)",
  ["HELP_FORGET"]     = "Itemcache leeren",
  ["HELP_SPEC"]       = "erkannte Spezialisierung zeigen",
  ["HELP_SPEC_SET"]   = "Spezialisierung von Hand waehlen, auto = erkennen",
  ["HELP_AHEAD"]      = "wie viele Stufen vorausgeplant wird",
  ["HELP_CAT"]        = "Fundort umsortieren",
  ["HELP_UNUSED"]     = "unerreichbare Quellen ein/ausblenden",
  ["HELP_WEIGHT"]     = "Statgewichte zeigen",
  ["HELP_WEIGHT_SET"] = "Gewicht setzen",
  ["HELP_WEIGHT_RST"] = "Gewichte zuruecksetzen",
  ["HELP_SCAN"]       = "Ausruestung neu scannen und ausgeben",
  ["HELP_DUMP"]       = "rohe Tooltipzeilen eines Items zeigen",
  ["HELP_TIP"]        = "Leseverfahren fuer den Tooltip vergleichen",
  ["ST_TITLE"]        = "Selbstpruefung %s",
  ["ST_LANG"]         = "Clientsprache %s, Anzeige %s",
  ["ST_PATTERNS"]     = "Tooltipmuster: %s",
  ["ST_PATTERNS_NOTE"] = "(folgt dem Client, nicht dem Schalter)",
  ["ST_PFQUEST_NOTE"] = "- ohne sie gibt es keine Fundorte",
  ["ST_PFQUEST_MISSING"] = "nicht installiert (optional, die eingebauten Fundorte werden genutzt)",
  ["ST_ITEMDB_COUNT"] = "%d Eintraege",
  ["ST_GEAR"]         = "Ausruestung: %d von %d Teilen mit erkannten Werten",
  ["ST_NO_STATS"]     = "Kein einziger Wert erkannt. Das deutet darauf hin, dass die Tooltipmuster nicht zur Clientsprache passen.",
  ["ST_WITHOUT"]      = "ohne Werte: %s",
  ["ST_WITHOUT_NOTE"] = "(bei Schmuck und Umhaengen ohne Werte ist das normal)",
  ["ST_TOOLTIP"]      = "Tooltip lesbar: %d Zeilen aus \"%s\"",
  ["ST_TOOLTIP_BAD"]  = "Zu wenige Zeilen - der Scan-Tooltip liefert nicht, was im Spiel steht.",
  ["ST_BAND"]         = "Suchband %d-%d, Vorausplanung %d",
  ["ST_POOL"]         = "Pool %d",
  ["ST_POOL_LOC"]     = "(%d mit Fundort)",
  ["ST_NOSEARCH"]     = "Noch nicht gesucht - /bll up",
  ["CAND_ERROR"]      = "Suche mit Fehler abgebrochen in Schritt \"%s\": %s",
  ["CAND_ERROR_HINT"] = "Bitte einen Screenshot dieser Zeile und von /bll selftest schicken.",
  ["PROG_FAILED"]     = "Suche fehlgeschlagen - siehe Chat",
  ["ST_DIAG_PFQ"]     = "pfQuest: %d von %d Items im Suchbereich",
  ["ST_DIAG_IMPORT"]  = "Import: %d Items im Suchbereich",
  ["ST_DIAG_STATE"]   = "Suchstatus: %s",
  ["ST_DIAG_STUCK"]   = "- haengt, seit %.0fs kein Fortschritt",
  ["ST_DIAG_EMPTY"]   = "Die letzte Suche hat nichts gesammelt, obwohl Items im Bereich liegen.",
  ["ST_DIAG_FAIL"]    = "Diagnose fehlgeschlagen: %s",
  ["ST_OK"]           = "Keine Auffaelligkeiten.",
  ["ST_WARN"]         = "%d Auffaelligkeit(en) - bitte die rot markierten Zeilen melden.",
  ["USAGE_TIP"]       = "Nutzung: /bll tip <itemID>",
  ["USAGE_ITEM"]      = "Nutzung: /bll item <itemID>",
  ["ITEM_NOCACHE"]    = "Kein Cache-Eintrag fuer %d",
  ["ITEM_HINT"]       = "(erst /bll up, dann erneut)",
  ["ITEM_HEAD"]       = "Cache %d: %s",
  ["ITEM_LEVEL"]      = "Stufe    ",
  ["ITEM_SLOT"]       = "Slot     ",
  ["ITEM_ORIGIN"]     = "Herkunft ",
  ["ITEM_LOCK"]       = "Sperre   ",
  ["ITEM_STATS"]      = "Werte    ",
  ["ITEM_IMPORT"]     = "Import",
  ["ITEM_SERVER"]     = "Server",
  ["ITEM_NONE"]       = "keine",
  ["HOOKS_HEAD"]      = "Aktive Addons, die Tooltips erweitern koennten:",
  ["HOOKS_NONE"]      = "keine erkannt",
  ["HOOKS_TOTAL"]     = "%d Addons insgesamt",
  ["HELP_ITEM"]       = "Cache-Eintrag eines Gegenstands zeigen",
  ["HELP_HOOKS"]      = "Addons auflisten, die Tooltips erweitern",
  ["TIP_COMPARE"]     = "Tooltip-Vergleich fuer %s",
  ["TIP_HINT"]        = "Zum Vergleich: im Spiel ueber den Gegenstand fahren und schauen, welche Zeilen dort fehlen.",
  ["DUMP_LINES"]      = "Tooltipzeilen:",
  ["DUMP_FOUND"]      = "Erkannt: %s",
  ["DUMP_NOTHING"]    = "nichts",
  ["HELP_SELFTEST"]   = "Muster, Sprachen und Datenquellen pruefen",
  ["HELP_ZONE"]       = "einen Ort benennen, den die Daten nicht kennen",
  ["AHEAD_TITLE"]     = "Vorausplanung",
  ["AHEAD_TIP"]       = "Wie viele Stufen ueber der eigenen die Suche reicht. 0 zeigt nur, was sofort anlegbar ist.",
  ["INFO_DATA"]       = "Fundorte: %d Items, %d NPCs, %d Zonen",
  ["ZONE_SET"]        = "Zone %s heisst jetzt \"%s\".",
  ["ZONE_CLEARED"]    = "Zone %s auf den mitgelieferten Namen zurueckgesetzt.",
  ["USAGE_ZONE"]      = "Nutzung: /bll zone <id> <Name>  -  /bll zone <id> setzt zurueck",
  ["HELP_PHASE"]      = "Inhaltsphasen zeigen, eine von Hand freigeben",
  ["USAGE_PHASE"]     = "Nutzung: /bll phase  -  /bll phase <Nr> on|off|auto",
  ["PHASE_HEADER"]    = "Inhaltsphasen (Quelle: octowow.st/roadmap)",
  ["PHASE_OPEN"]      = "offen",
  ["PHASE_CLOSED"]    = "noch nicht offen",
  ["PHASE_BYHAND"]    = "von Hand gesetzt",
  ["PHASE_SET"]       = "Phase %d ist jetzt %s.",
  ["PHASE_AUTO"]      = "Phase %d richtet sich wieder nach ihrem Termin.",
  ["PHASE_NODATE"]    = "Der Client liefert kein Datum. Jede Phase gilt als gesperrt, bis du sie mit /bll phase <Nr> on freigibst.",
  ["INFO_PHASE"]      = "Phasen: %d von %d offen, %d Zonen gesperrt",
  ["HELP_SRC"]        = "Quellen eines Items zeigen",
  ["HELP_SET"]        = "Set und Boni eines Items",
  ["HELP_USECD"]      = "angenommene Abklingzeit fuer Use-Effekte",
  ["HELP_INFO"]       = "Statuszeile",
  ["HELP_DEBUG"]      = "Debugausgabe an/aus",

  -- ---- Herkunft eines Kandidaten ----
  ["NO_LOCATION_YET"] = "kein bekannter Fundort",
  ["LOCKED_ITEM"]     = "nicht frei erhaeltlich",
  ["CAT_DUNGEON"]     = "DUNGEON",
  ["CAT_RAID"]        = "RAID",
  ["CAT_QUEST"]       = "QUEST",
  ["CAT_VENDOR"]      = "HAENDLER",
  ["CAT_OBJECT"]      = "OBJEKT",
  ["CAT_WORLDBOSS"]   = "WELTBOSS",
  ["CAT_PVP"]         = "PVP",
  ["CAT_WORLD"]       = "WELT",
  ["NO_ROUTE"]        = "Noch kein Wegplan. Unten auf \"Upgrades suchen\" klicken.",
  ["LOOT_QUESTS"]     = "Quests",
  ["LOCKED_STATE"]    = "Gegenstaende mit Ruf- oder Rangbedingung: %s",
  ["LOCKED_SHOWN"]    = "werden angezeigt",
  ["LOCKED_HIDDEN"]   = "werden ausgeblendet",
  ["DUMP_LOCKED"]     = "Zugangsbedingung:",
  ["HELP_LOCKED"]     = "Teile mit Ruf- oder Rangbedingung ein-/ausblenden",
  ["UNSCORED_EQUIPPED"] = "Effekt nicht bewertet",
  ["UNSCORED_HINT"]   = "Das angelegte Teil hat einen Effekt, den das Addon nicht in Punkte fassen kann. Knappe Vorschlaege bleiben deshalb aussen vor - sie waeren geraten.",
  ["UNSCORED_SHORT"]  = "Vergleich unvollstaendig",
  ["DUMP_UNSCORED"]   = "Nicht bewertet:",
}

-- BLL.L bleibt immer dieselbe Tabelle. Core.lua und Sources.lua halten
-- sie in einer lokalen Variable; eine neue Tabelle beim Umschalten
-- wuerde dort nie ankommen. Deshalb wird der Inhalt ausgetauscht.
BLL.L = {}
setmetatable(BLL.L, { __index = function(t, k) return k end })

-- code: "deDE", "enUS" oder "auto"/nil (= Clientsprache)
function BLL:SetLanguage(code)
  if code ~= "deDE" and code ~= "enUS" then
    code = (BLL.clientLocale == "deDE") and "deDE" or "enUS"
  end
  BLL.locale = code
  local src = (code == "deDE") and L_deDE or L_enUS
  for k in pairs(BLL.L) do BLL.L[k] = nil end
  for k, v in pairs(src) do BLL.L[k] = v end
end

BLL:SetLanguage(nil)

------------------------------------------------------------------
-- Stat-Keys (interne, sprachunabhaengige Bezeichner)
------------------------------------------------------------------

BLL.STATS = {
  "STR", "AGI", "STA", "INT", "SPI",
  "ARMOR", "DEFENSE",
  "HIT", "CRIT", "SPELLHIT", "SPELLCRIT",
  "AP", "RAP", "SPELLPOWER", "HEALPOWER",
  "SPELLPOWER_ARCANE", "SPELLPOWER_FIRE", "SPELLPOWER_FROST",
  "SPELLPOWER_HOLY", "SPELLPOWER_NATURE", "SPELLPOWER_SHADOW",
  "MP5", "HP5", "HEALTH", "MANA",
  "DODGE", "PARRY", "BLOCK", "BLOCKVALUE",
  "RES_FIRE", "RES_FROST", "RES_NATURE", "RES_SHADOW", "RES_ARCANE",
  "WEAPON_MIN", "WEAPON_MAX", "WEAPON_SPEED", "WEAPON_DPS",
}

------------------------------------------------------------------
-- Tooltip-Patterns
--
-- Jeder Eintrag: { statkey, luapattern }
-- Das Pattern muss GENAU EINE Zahl capturen (ausser WEAPON_DMG, s.u.).
-- Reihenfolge zaehlt: das erste passende Pattern pro Zeile gewinnt,
-- danach wird die Zeile nicht weiter geprueft.
------------------------------------------------------------------

local P_enUS = {
  -- Grundwerte
  { "STR",         "^%+(%d+) Strength"          },
  { "AGI",         "^%+(%d+) Agility"           },
  { "STA",         "^%+(%d+) Stamina"           },
  { "INT",         "^%+(%d+) Intellect"         },
  { "SPI",         "^%+(%d+) Spirit"            },

  -- Negative Grundwerte (manche Items haben Mali)
  { "STR",         "^%-(%d+) Strength",         -1 },
  { "AGI",         "^%-(%d+) Agility",          -1 },
  { "STA",         "^%-(%d+) Stamina",          -1 },
  { "INT",         "^%-(%d+) Intellect",        -1 },
  { "SPI",         "^%-(%d+) Spirit",           -1 },

  -- Ruestung / Block
  { "ARMOR",       "^(%d+) Armor"               },
  { "BLOCKVALUE",  "^(%d+) Block"               },

  -- Widerstaende
  { "RES_FIRE",    "^%+(%d+) Fire Resistance"    },
  { "RES_FROST",   "^%+(%d+) Frost Resistance"   },
  { "RES_NATURE",  "^%+(%d+) Nature Resistance"  },
  { "RES_SHADOW",  "^%+(%d+) Shadow Resistance"  },
  { "RES_ARCANE",  "^%+(%d+) Arcane Resistance"  },

  -- Equip-Effekte
  -- RAP VOR AP: "ranged attack power by 24" passt auch auf das AP-Muster,
  -- und der Scanner nimmt den ersten Treffer. In umgekehrter Reihenfolge
  -- zaehlte jede Distanz-Angriffskraft als Nahkampf-AP.
  { "RAP",         "[Rr]anged [Aa]ttack [Pp]ower by (%d+)"             },
  { "AP",          "[Aa]ttack [Pp]ower by (%d+)"                       },
  { "SPELLPOWER",  "damage and healing done by magical spells.- (%d+)" },
  -- Schulgebundener Zauberschaden. Fehlte bisher ganz, die Gewichte
  -- fuer Feuer-, Frost- und Schattenmagier liefen damit ins Leere.
  { "SPELLPOWER_ARCANE", "Arcane spells and effects by up to (%d+)" },
  { "SPELLPOWER_FIRE",   "Fire spells and effects by up to (%d+)"   },
  { "SPELLPOWER_FROST",  "Frost spells and effects by up to (%d+)"  },
  { "SPELLPOWER_HOLY",   "Holy spells and effects by up to (%d+)"   },
  { "SPELLPOWER_NATURE", "Nature spells and effects by up to (%d+)" },
  { "SPELLPOWER_SHADOW", "Shadow spells and effects by up to (%d+)" },
  { "HEALPOWER",   "healing done by spells and effects.- (%d+)"        },
  { "CRIT",        "chance to get a critical strike by (%d+)"          },
  { "SPELLCRIT",   "chance to get a critical strike with spells by (%d+)" },
  { "HIT",         "chance to hit by (%d+)"                            },
  { "SPELLHIT",    "chance to hit with spells by (%d+)"                },
  -- "Increased Defense +7.": das Pluszeichen stand dem Muster im Weg
  { "DEFENSE",     "[Dd]efense.- %+?(%d+)"                             },
  { "DODGE",       "chance to dodge.- (%d+)"                           },
  { "PARRY",       "chance to parry.- (%d+)"                           },
  { "BLOCK",       "chance to block.- (%d+)"                           },
  { "MP5",         "(%d+) mana per 5"                                  },
  { "MP5",         "(%d+) mana every 5"                                },
  { "HP5",         "(%d+) health every 5"                              },

  -- Waffe
  { "WEAPON_SPEED", "^Speed (%d+%.%d+)"     },
  { "WEAPON_DPS",   "%((%d+%.%d+) damage per second%)" },
}

local P_deDE = {
  -- Grundwerte
  { "STR",         "^%+(%d+) St.-rke"          },
  { "AGI",         "^%+(%d+) Beweglichkeit"      },
  { "STA",         "^%+(%d+) Ausdauer"           },
  { "INT",         "^%+(%d+) Intelligenz"        },
  { "SPI",         "^%+(%d+) Willenskraft"       },

  { "STR",         "^%-(%d+) St.-rke",         -1 },
  { "AGI",         "^%-(%d+) Beweglichkeit",     -1 },
  { "STA",         "^%-(%d+) Ausdauer",          -1 },
  { "INT",         "^%-(%d+) Intelligenz",       -1 },
  { "SPI",         "^%-(%d+) Willenskraft",      -1 },

  -- Ruestung / Block
  { "ARMOR",       "^(%d+) R.-stung"           },
  { "BLOCKVALUE",  "^(%d+) Block"                },

  -- Widerstaende
  { "RES_FIRE",    "^%+(%d+) Feuerwiderstand"    },
  { "RES_FROST",   "^%+(%d+) Frostwiderstand"    },
  { "RES_NATURE",  "^%+(%d+) Naturwiderstand"    },
  { "RES_SHADOW",  "^%+(%d+) Schattenwiderstand" },
  { "RES_ARCANE",  "^%+(%d+) Arkanwiderstand"    },

  -- Equip-Effekte ("Anlegen: Erhoeht ...")
  { "AP",          "Angriffskraft um (%d+)"                      },
  { "RAP",         "[Dd]istanzangriffskraft um (%d+)"            },
  { "SPELLPOWER",  "Zauberschaden und Heilung.- (%d+)"           },
  { "SPELLPOWER",  "Zaubermacht um.- (%d+)"                      },
  { "HEALPOWER",   "Heilung von Zaubern.- (%d+)"                 },
  { "CRIT",        "kritischen Treffer um (%d+)"                 },
  { "SPELLCRIT",   "kritischen Zaubertreffer um (%d+)"           },
  { "HIT",         "Chance zu treffen um (%d+)"                  },
  { "SPELLHIT",    "Zauber treffen um (%d+)"                     },
  { "DEFENSE",     "Verteidigung.- %+?(%d+)"                     },
  { "DODGE",       "auszuweichen um (%d+)"                       },
  { "PARRY",       "zu parieren um (%d+)"                        },
  { "BLOCK",       "zu blocken um (%d+)"                         },
  { "MP5",         "(%d+) Mana pro 5"                            },
  { "MP5",         "(%d+) Mana alle 5"                           },
  { "HP5",         "(%d+) Leben alle 5"                          },

  -- Waffe
  { "WEAPON_SPEED", "^Tempo (%d+%.%d+)"    },
  { "WEAPON_DPS",   "%((%d+%.%d+) Schaden pro Sekunde%)" },
}

BLL.PATTERNS = (BLL.clientLocale == "deDE") and P_deDE or P_enUS

------------------------------------------------------------------
-- Hinweise auf Effekte, die kein Muster in Werte uebersetzt
--
-- Proc-Effekte sind in Vanilla haeufig und tauchen im Tooltip als Text
-- auf, nicht als Wert: "Chance bei Treffer", "2% Chance, einen
-- zusaetzlichen Angriff auszufuehren". Ein Item kann dadurch stark sein,
-- ohne dass der Scanner einen einzigen Punkt findet.
--
-- Diese Muster markieren solche Zeilen, damit der Vergleich weiss, dass
-- er unvollstaendig ist. Sie greifen nur bei Zeilen, auf die vorher KEIN
-- Wertmuster gepasst hat - "erhoeht Eure Chance auszuweichen um 1%" ist
-- also nicht betroffen, das ist laengst als DODGE erfasst.
--
-- Bewusst kurz: jedes Muster, das zu breit trifft, unterdrueckt echte
-- Vorschlaege. Verglichen wird kleingeschrieben.
------------------------------------------------------------------


------------------------------------------------------------------
-- Zugangsbedingungen: Ruf und PvP-Rang
--
-- Ein Bogen beim PvP-Quartiermeister kann Stufe 18 verlangen und
-- zusaetzlich einen Ehrenrang. Die Stufe kennt das Addon, den Rang
-- nicht - solche Teile standen deshalb ganz oben in der Lootline,
-- obwohl ein frischer Charakter nie an sie herankommt.
--
-- Erkannt wird die Bedingungszeile des Tooltips. Reine Stufenzeilen
-- ("Requires Level 18") filtert SKIP_PREFIX schon vorher heraus, hier
-- kommen also nur die anderen an: Ruf, Rang, Beruf.
--
-- Das Muster umgeht den Umlaut in "Benoetigt" absichtlich mit ".-",
-- damit es unabhaengig von der Zeichenkodierung des Clients greift.
------------------------------------------------------------------

BLL.RESTRICT_PREFIX = (BLL.clientLocale == "deDE")
  and { "^Ben.-tigt", "^Erfordert" }
  or  { "^Requires" }

-- Zusaetzliches Netz fuer Zeilen, die nicht mit dem Bedingungswort
-- beginnen, aber eindeutig eine Ruf- oder Rangstufe nennen.
BLL.RESTRICT_WORDS = (BLL.clientLocale == "deDE")
  and { "wohlwollend", "respektvoll", "ehrf", "freundlich", "revered",
        "ehrenrang", "rang " }
  or  { "friendly", "honored", "revered", "exalted", "rank " }

BLL.EFFECT_HINTS = (BLL.clientLocale == "deDE")
  and { "chance", "benutzen:", "wenn getroffen", "bei treffer" }
  or  { "chance", "use:", "when struck", "on hit" }


-- Schadensbereich wird separat behandelt, weil zwei Zahlen gecaptured werden.
BLL.DMG_PATTERN = (BLL.clientLocale == "deDE")
  and "^(%d+) %- (%d+) Schaden"
  or  "^(%d+) %- (%d+) Damage"

-- Zeilen, die wir gar nicht erst pruefen (spart Durchlaeufe)
BLL.SKIP_PREFIX = (BLL.clientLocale == "deDE")
  and { "Benoetigt Stufe", "Seelengebunden", "Beim Anlegen geb", "Einzigartig" }
  or  { "Requires Level", "Soulbound", "Binds when", "Unique" }

------------------------------------------------------------------
-- Dropchancen lesbar machen.
--
-- Die Zahlen aus dem Export reichen weit unter ein Prozent: "Feet of
-- the Lynx" faellt mit 0,0045 Prozent. Mit "%.1f%%" stand ueberall
-- "0.0%" - was aussieht wie "faellt nie" und trotzdem der haeufigste
-- Wert im Bestand ist. Der Median aller Dropzeilen liegt bei 0,0085
-- Prozent, die kleinste belegte Stelle bei 0,0001. Deshalb wachsen die
-- Nachkommastellen mit der Kleinheit des Werts, statt ihn wegzurunden.
function BLL:FormatChance(chance)
  local c = tonumber(chance)
  if not c or c <= 0 then return nil end
  if c >= 10     then return string.format("%.0f%%", c) end
  if c >= 1      then return string.format("%.1f%%", c) end
  if c >= 0.1    then return string.format("%.2f%%", c) end
  if c >= 0.01   then return string.format("%.3f%%", c) end
  if c >= 0.0001 then return string.format("%.4f%%", c) end
  return "<0.0001%"
end

------------------------------------------------------------------
-- Elitekennung eines Gegners.
--
-- Der Export fuehrt sie als Zahl. Fuer den Wegplan zaehlt vor allem der
-- Unterschied zwischen "kann ich allein" und "brauche ich eine Gruppe";
-- Selten und Boss stehen daneben, weil ein seltener Gegner nicht immer
-- da ist und ein Boss eine Instanz bedeutet.
--   1 Elite, 2 Selten-Elite, 3 Boss, 4 Selten
------------------------------------------------------------------

function BLL:EliteLabel(rank)
  local de = (self.locale == "deDE")
  if rank == 1 then return de and "Elite"  or "Elite"  end
  if rank == 2 then return de and "Selten-Elite" or "Rare Elite" end
  if rank == 3 then return de and "Boss"   or "Boss"   end
  if rank == 4 then return de and "Selten" or "Rare"   end
  return nil
end
