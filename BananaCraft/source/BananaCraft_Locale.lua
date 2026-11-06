-- BananaCraft - Localization
-- ============================================================
--  IMPORTANT ARCHITECTURE NOTE / WICHTIGER HINWEIS:
--
--  EN: Only the DISPLAY is translated. All stored and
--      transmitted data (profession keys, recipe names,
--      category keys) stays in ENGLISH so that German and
--      English clients remain fully compatible over the wire.
--
--  DE: Uebersetzt wird ausschliesslich die ANZEIGE. Alle
--      gespeicherten und gesendeten Daten (Berufsschluessel,
--      Rezeptnamen, Kategorieschluessel) bleiben ENGLISCH,
--      damit deutsche und englische Clients weiterhin
--      miteinander kommunizieren koennen.
-- ============================================================

BCRAFT_Locales = {}
BCRAFT_Locales["enUS"] = {}
BCRAFT_Locales["deDE"] = {}

local en = BCRAFT_Locales["enUS"]
local de = BCRAFT_Locales["deDE"]

-- ---------- Interface strings ----------
en.ALL_SENT = "All professions have been sent!"
de.ALL_SENT = "Alle Berufe wurden gesendet!"

en.SENDING = "Sending:"
de.SENDING = "Sende:"

en.SCANNED = "Scanned:"
de.SCANNED = "Gescannt:"

en.RECIPES_SUFFIX = "recipes"
de.RECIPES_SUFFIX = "Rezepte"

en.TRANSFER_START = "Starting transfer:"
de.TRANSFER_START = "Starte Uebertragung:"

en.PROFS_QUEUED = "professions queued"
de.PROFS_QUEUED = "Berufe in Queue"

en.EST_TIME = "Estimated time: approx."
de.EST_TIME = "Geschaetzte Zeit: ca."

en.SECONDS = "seconds"
de.SECONDS = "Sekunden"

en.NOTHING_TO_SEND = "Nothing to send."
de.NOTHING_TO_SEND = "Keine Berufe zum Senden."

en.SCAN_FIRST = "Scan your professions first!"
de.SCAN_FIRST = "Scanne zuerst deine Berufe!"

en.REMAINING = "remaining"
de.REMAINING = "verbleibend"

en.WINDOW_TITLE = "BananaCraft - Craft Search"
de.WINDOW_TITLE = "BananaCraft - Craft-Suche"

en.SEARCH_LABEL = "Search:"
de.SEARCH_LABEL = "Suche:"

en.SHARE_BUTTON = "Share database with guild"
de.SHARE_BUTTON = "Datenbank mit der Gilde teilen"

en.ABOUT_TOOLTIP = "About this addon"
de.ABOUT_TOOLTIP = "Ueber dieses Addon"

en.LANG_TOOLTIP = "Switch language"
de.LANG_TOOLTIP = "Sprache umschalten"

en.ALL = "ALL"
de.ALL = "ALLE"

en.ONLINE = "Online"
de.ONLINE = "Online"

en.OFFLINE = "Offline"
de.OFFLINE = "Offline"

en.TOTAL = "total"
de.TOTAL = "Gesamt"

en.QUANTITY = "Quantity:"
de.QUANTITY = "Anzahl:"

en.WHISPER = "Whisper..."
de.WHISPER = "Anfluestern..."

en.MISSING = "Missing:"
de.MISSING = "Fehlen:"

en.ALL_MATS = "All materials available!"
de.ALL_MATS = "Alle Materialien vorhanden!"

en.PLAYER = "Player:"
de.PLAYER = "Spieler:"

en.PROFESSION = "Profession:"
de.PROFESSION = "Beruf:"

en.MATERIALS = "Materials"
de.MATERIALS = "Materialien"

en.NEEDED = "Needed"
de.NEEDED = "Benoetigt"

en.HAVE_BAGS_BANK = "Have (bags+bank)"
de.HAVE_BAGS_BANK = "Hast (Taschen+Bank)"

en.CRAFTERS = "Crafters"
de.CRAFTERS = "Hersteller"

en.NOBODY_ONLINE = "Sadly nobody is online right now who could help you here!"
de.NOBODY_ONLINE = "Leider ist derzeit keine Banane Online die dir hier weiterhelfen kann!"

en.CSV_EXPORT = "CSV Export"
de.CSV_EXPORT = "CSV Export"

en.CSV_HINT = "Ctrl+A -> Ctrl+C to copy!"
de.CSV_HINT = "Strg+A -> Strg+C zum Kopieren!"

en.CSV_NOTEPAD = "Then paste into Notepad and save as .csv!"
de.CSV_NOTEPAD = "Dann in Notepad einfuegen und als .csv speichern!"

en.CLOSE = "Close"
de.CLOSE = "Schliessen"

en.LINES = "lines"
de.LINES = "Zeilen"

en.THANKS_TITLE = "Thank you for your support!"
de.THANKS_TITLE = "Danke fuer die Unterstuetzung!"

en.THANKS_BODY = "This addon was built in many hours of spare time and stays free.\n\nIf you would like to say thanks, feel free to send me mail - gold, mats or just a few kind words always make my day.\n\n|cff888888Completely optional - the addon works just fine without it.|r"
de.THANKS_BODY = "Dieses Addon ist in vielen Stunden Freizeit entstanden und bleibt kostenlos.\n\nWer sich bedanken moechte, kann mir gerne Post schicken - ueber Gold, Mats oder auch nur ein paar nette Worte freue ich mich immer.\n\n|cff888888Voellig freiwillig - das Addon funktioniert auch ohne komplett.|r"

en.CHARACTER = "Character:"
de.CHARACTER = "Charakter:"

en.FILL_NAME = "Fill in name"
de.FILL_NAME = "Namen eintragen"

en.MAILBOX_OPEN = "Mailbox open - one click fills in the name."
de.MAILBOX_OPEN = "Briefkasten offen - ein Klick traegt den Namen ein."

en.MAILBOX_CLOSED = "Select and press Ctrl+C to copy the name. At a mailbox it is filled in automatically."
de.MAILBOX_CLOSED = "Markieren und Strg+C kopiert den Namen. Am Briefkasten wird er per Knopfdruck eingetragen."

en.RECIPIENT_SET = "Recipient"
de.RECIPIENT_SET = "Empfaenger"

en.RECIPIENT_THANKS = "has been filled in. Thank you very much!"
de.RECIPIENT_THANKS = "wurde eingetragen. Vielen Dank!"

en.NEED_MAILBOX = "You need to stand at a"
de.NEED_MAILBOX = "Dafuer musst du an einem"

en.MAILBOX = "mailbox"
de.MAILBOX = "Briefkasten"

en.NEED_MAILBOX_2 = "for that. You can also select the name and copy it with Ctrl+C."
de.NEED_MAILBOX_2 = "stehen. Der Name laesst sich aber auch markieren und mit Strg+C kopieren."

en.MM_LEFTCLICK = "Left-click: open/close window"
de.MM_LEFTCLICK = "Linksklick: Fenster oeffnen/schliessen"

en.MM_RIGHTCLICK = "Right-click + drag: move button"
de.MM_RIGHTCLICK = "Rechtsklick + Ziehen: Button verschieben"

en.MANAGE_PROFS = "Manage professions"
de.MANAGE_PROFS = "Berufe Verwalten"

en.MANAGE_HINT = "Click a profession to delete it and notify the guild"
de.MANAGE_HINT = "Klicke auf einen Beruf um ihn zu loeschen und an die Gilde zu senden"

en.NO_PROFS_STORED = "No professions stored"
de.NO_PROFS_STORED = "Keine Berufe gespeichert"

en.SHARE_SHORT = "Share database with guild"
de.SHARE_SHORT = "Datenbank an Gilde teilen"

en.CMD_HEADER = "Commands:"
de.CMD_HEADER = "Befehle:"

en.CMD_SHOW = "/bc show      - open/close the UI"
de.CMD_SHOW = "/bc show      - UI oeffnen/schliessen"

en.CMD_SCAN = "/bc scan      - scan the open profession"
de.CMD_SCAN = "/bc scan      - aktuell geoeffneten Beruf scannen"

en.CMD_RESCAN = "/bc rescan    - allow rescanning (clears session cache)"
de.CMD_RESCAN = "/bc rescan    - erlaube erneutes Scannen (cleart Session-Cache)"

en.CMD_SEND = "/bc send      - send all professions to the guild"
de.CMD_SEND = "/bc send      - alle Berufe an Gilde senden"

en.CMD_SYNC = "/bc sync      - lightweight sync: only pulls what's outdated"
de.CMD_SYNC = "/bc sync      - leichter Abgleich: holt nur veraltete Daten nach"

en.CMD_VERSIONCHECK = "/bc versioncheck - see which BananaCraft version guildmates run"
de.CMD_VERSIONCHECK = "/bc versioncheck - zeigt BananaCraft-Version der Gildenmitglieder"

en.CMD_DELETE = "/bc delete [prof] - delete a profession (e.g. /bc delete Alchemy)"
de.CMD_DELETE = "/bc delete [prof] - Beruf loeschen (z.B. /bc delete Alchemy)"

en.CMD_DELETE_ALL = "/bc delete all    - delete ALL professions"
de.CMD_DELETE_ALL = "/bc delete all    - ALLE Berufe loeschen"

en.CMD_SCANBANK = "/bc scanbank  - scan bank manually"
de.CMD_SCANBANK = "/bc scanbank  - Bank manuell scannen"

en.CMD_EXPORT = "/bc export    - CSV export for Discord/Excel"
de.CMD_EXPORT = "/bc export    - CSV-Export fuer Discord/Excel"

en.CMD_DEBUG = "/bc debug     - toggle debug"
de.CMD_DEBUG = "/bc debug     - Debug an/aus"

en.CMD_ABOUT = "/bc about     - info & support"
de.CMD_ABOUT = "/bc about     - Info & Unterstuetzung"

en.CMD_LANG = "/bc lang en|de|auto - language"
de.CMD_LANG = "/bc lang en|de|auto - Sprache"

en.SYNC_REQUESTING = "Sync: requesting updated data for professions:"
de.SYNC_REQUESTING = "Abgleich: fordere aktualisierte Daten an fuer Berufe:"

en.SYNC_UP_TO_DATE = "Sync: everything already up to date."
de.SYNC_UP_TO_DATE = "Abgleich: bereits alles aktuell."

en.VERSIONCHECK_ASKING = "Asking guild which BananaCraft version they run..."
de.VERSIONCHECK_ASKING = "Frage Gilde nach BananaCraft-Version..."

en.VERSIONCHECK_RUNS = "runs"
de.VERSIONCHECK_RUNS = "nutzt"

en.CACHE_CLEARED = "Session cache cleared. You can rescan all professions now!"
de.CACHE_CLEARED = "Session-Cache geloescht. Du kannst jetzt alle Berufe neu scannen!"

en.DEBUG_LABEL = "Debug:"
de.DEBUG_LABEL = "Debug:"

en.ON = "ON"
de.ON = "AN"

en.OFF = "OFF"
de.OFF = "AUS"

en.USAGE_DELETE = "Usage: /bc delete [profession] or /bc delete all"
de.USAGE_DELETE = "Benutzung: /bc delete [Beruf] oder /bc delete all"

en.EXAMPLE_DELETE = "Example: /bc delete Alchemy"
de.EXAMPLE_DELETE = "Beispiel: /bc delete Alchemy"

en.DB_WIPED = "ENTIRE DATABASE DELETED:"
de.DB_WIPED = "KOMPLETTE DATENBANK GELOESCHT:"

en.CHARACTERS = "character(s)"
de.CHARACTERS = "Character"

en.PROFESSIONS = "profession(s)"
de.PROFESSIONS = "Beruf(e)"

en.GUILD_ENTRIES = "guild entries"
de.GUILD_ENTRIES = "Gilden-Eintraege"

en.DELETED = "Deleted:"
de.DELETED = "Geloescht:"

en.ERROR = "Error:"
de.ERROR = "Fehler:"

en.PROF_NOT_FOUND = "not found"
de.PROF_NOT_FOUND = "nicht gefunden"

en.NO_PROF_OPEN = "No profession window open"
de.NO_PROF_OPEN = "Kein Beruf geoeffnet"

en.NO_RECIPES = "No recipes found"
de.NO_RECIPES = "Keine Rezepte gefunden"

en.NO_DATA_FOR = "No data for"
de.NO_DATA_FOR = "Keine Daten fuer"

en.LANG_SWITCHED = "Language set to English."
de.LANG_SWITCHED = "Sprache auf Deutsch gestellt."

-- ---------- Category names (keys stay English!) ----------
en.CAT = {}
de.CAT = {}
en.CAT["ALL"] = "ALL"
de.CAT["ALL"] = "ALLE"
en.CAT["2HWeapon"] = "Two-Handed Weapons"
de.CAT["2HWeapon"] = "Zweihandwaffen"
en.CAT["Amulets"] = "Amulets"
de.CAT["Amulets"] = "Amulette"
en.CAT["Axes"] = "Axes"
de.CAT["Axes"] = "Aexte"
en.CAT["Bags"] = "Bags"
de.CAT["Bags"] = "Taschen"
en.CAT["Belt"] = "Belts"
de.CAT["Belt"] = "Guertel"
en.CAT["Boots"] = "Boots"
de.CAT["Boots"] = "Stiefel"
en.CAT["Bracer"] = "Bracers"
de.CAT["Bracer"] = "Armschienen"
en.CAT["Bracers"] = "Bracers"
de.CAT["Bracers"] = "Armschienen"
en.CAT["Buckles"] = "Buckles"
de.CAT["Buckles"] = "Schnallen"
en.CAT["Cloth"] = "Cloth"
de.CAT["Cloth"] = "Stoffballen"
en.CAT["Chest"] = "Chest"
de.CAT["Chest"] = "Brustruestung"
en.CAT["Cloak"] = "Cloaks"
de.CAT["Cloak"] = "Umhaenge"
en.CAT["Daggers"] = "Daggers"
de.CAT["Daggers"] = "Dolche"
en.CAT["Defensive Potions and Elixirs"] = "Defensive Potions and Elixirs"
de.CAT["Defensive Potions and Elixirs"] = "Defensive Traenke und Elixiere"
en.CAT["Equipment"] = "Equipment"
de.CAT["Equipment"] = "Ausruestung"
en.CAT["Explosives"] = "Explosives"
de.CAT["Explosives"] = "Sprengstoffe"
en.CAT["Fist"] = "Fist Weapons"
de.CAT["Fist"] = "Faustwaffen"
en.CAT["Flasks"] = "Flasks"
de.CAT["Flasks"] = "Flaschen"
en.CAT["Gemstones"] = "Gemstones"
de.CAT["Gemstones"] = "Edelsteine"
en.CAT["Glove"] = "Gloves"
de.CAT["Glove"] = "Handschuhe"
en.CAT["Gloves"] = "Gloves"
de.CAT["Gloves"] = "Handschuhe"
en.CAT["Gnomish"] = "Gnomish"
de.CAT["Gnomish"] = "Gnomisch"
en.CAT["Goblin"] = "Goblin"
de.CAT["Goblin"] = "Goblin"
en.CAT["Health and Mana Potions"] = "Health and Mana Potions"
de.CAT["Health and Mana Potions"] = "Gesundheits- und Manatraenke"
en.CAT["Helm"] = "Helmets"
de.CAT["Helm"] = "Helme"
en.CAT["Maces"] = "Maces"
de.CAT["Maces"] = "Streitkolben"
en.CAT["Misc"] = "Miscellaneous"
de.CAT["Misc"] = "Verschiedenes"
en.CAT["Miscellaneous"] = "Miscellaneous"
de.CAT["Miscellaneous"] = "Verschiedenes"
en.CAT["OffHands"] = "Off-Hands"
de.CAT["OffHands"] = "Schildhand"
en.CAT["Offensive Potions and Elixirs"] = "Offensive Potions and Elixirs"
de.CAT["Offensive Potions and Elixirs"] = "Offensive Traenke und Elixiere"
en.CAT["Pants"] = "Pants"
de.CAT["Pants"] = "Hosen"
en.CAT["Parts"] = "Parts"
de.CAT["Parts"] = "Bauteile"
en.CAT["Protection Potions"] = "Protection Potions"
de.CAT["Protection Potions"] = "Schutztraenke"
en.CAT["Rings"] = "Rings"
de.CAT["Rings"] = "Ringe"
en.CAT["Shield"] = "Shields"
de.CAT["Shield"] = "Schilde"
en.CAT["Shirt"] = "Shirts"
de.CAT["Shirt"] = "Hemden"
en.CAT["Shoulders"] = "Shoulders"
de.CAT["Shoulders"] = "Schultern"
en.CAT["Smelting"] = "Smelting"
de.CAT["Smelting"] = "Schmelzen"
en.CAT["Staves"] = "Staves"
de.CAT["Staves"] = "Staebe"
en.CAT["Swords"] = "Swords"
de.CAT["Swords"] = "Schwerter"
en.CAT["Transmutes"] = "Transmutes"
de.CAT["Transmutes"] = "Transmutationen"
en.CAT["Trinkets"] = "Trinkets"
de.CAT["Trinkets"] = "Schmuck"
en.CAT["Weapon"] = "Weapons"
de.CAT["Weapon"] = "Waffen"
en.CAT["Weapons"] = "Weapons"
de.CAT["Weapons"] = "Waffen"
en.CAT["Weaponsmith"] = "Weaponsmith"
de.CAT["Weaponsmith"] = "Waffenschmied"

-- ---------- Profession names (keys stay English!) ----------
en.PROF = {}
de.PROF = {}
en.PROF["ALL"] = "ALL"
de.PROF["ALL"] = "ALLE"
en.PROF["Alchemy"] = "Alchemy"
de.PROF["Alchemy"] = "Alchemie"
en.PROF["Blacksmithing"] = "Blacksmithing"
de.PROF["Blacksmithing"] = "Schmiedekunst"
en.PROF["Enchanting"] = "Enchanting"
de.PROF["Enchanting"] = "Verzauberkunst"
en.PROF["Engineering"] = "Engineering"
de.PROF["Engineering"] = "Ingenieurskunst"
en.PROF["Jewelcrafting"] = "Jewelcrafting"
de.PROF["Jewelcrafting"] = "Juwelierskunst"
en.PROF["Leatherworking"] = "Leatherworking"
de.PROF["Leatherworking"] = "Lederverarbeitung"
en.PROF["Tailoring"] = "Tailoring"
de.PROF["Tailoring"] = "Schneiderei"
en.PROF["Cooking"] = "Cooking"
de.PROF["Cooking"] = "Kochkunst"
en.PROF["First Aid"] = "First Aid"
de.PROF["First Aid"] = "Erste Hilfe"
en.PROF["Mining"] = "Mining"
de.PROF["Mining"] = "Bergbau"
en.PROF["Survival"] = "Survival"
de.PROF["Survival"] = "Ueberleben"
en.PROF["Poisons"] = "Poisons"
de.PROF["Poisons"] = "Gifte"

-- ---------- Runtime language handling ----------
-- BCRAFT_L is the active table used everywhere in the addon.
BCRAFT_L = BCRAFT_Locales["enUS"]

-- Detect a sensible default from the game client
function BCRAFT_DetectLocale()
  local loc = "enUS"
  if GetLocale then
    local g = GetLocale()
    if g == "deDE" then loc = "deDE" end
  end
  return loc
end

-- Apply a language: "enUS", "deDE" or "auto"
function BCRAFT_SetLocale(which)
  if which == "auto" or which == nil then
    which = BCRAFT_DetectLocale()
  end
  if not BCRAFT_Locales[which] then which = "enUS" end

  BCRAFT_L = BCRAFT_Locales[which]

  if BananaCraftDB then
    if not BananaCraftDB.settings then BananaCraftDB.settings = {} end
    BananaCraftDB.settings.locale = which
  end

  return which
end

-- Current language code
function BCRAFT_GetLocale()
  if BananaCraftDB and BananaCraftDB.settings and BananaCraftDB.settings.locale then
    return BananaCraftDB.settings.locale
  end
  return BCRAFT_DetectLocale()
end

-- Translate a category key for display (falls back to the key itself)
function BCRAFT_CatName(key)
  if not key then return "" end
  if BCRAFT_L and BCRAFT_L.CAT and BCRAFT_L.CAT[key] then return BCRAFT_L.CAT[key] end
  return key
end

-- Translate a profession key for display (falls back to the key itself)
function BCRAFT_ProfName(key)
  if not key then return "" end
  if BCRAFT_L and BCRAFT_L.PROF and BCRAFT_L.PROF[key] then return BCRAFT_L.PROF[key] end
  return key
end

-- Einstellungen (Zahnrad) und Online-Filter
en.GEAR_TOOLTIP = "Settings"
de.GEAR_TOOLTIP = "Einstellungen"
en.FILTER_ONLINE_ONLY = "Online only"
de.FILTER_ONLINE_ONLY = "Nur online"
en.SET_TITLE = "BananaCraft - Settings"
de.SET_TITLE = "BananaCraft - Einstellungen"
en.SET_LANG = "Language:"
de.SET_LANG = "Sprache:"
en.SET_LANG_AUTO = "Auto"
de.SET_LANG_AUTO = "Auto"
en.SET_MINIMAP = "Show minimap button"
de.SET_MINIMAP = "Minimap-Button anzeigen"
en.SET_DEBUG = "Debug output"
de.SET_DEBUG = "Debug-Ausgabe"
en.SET_SECTION_DATA = "Data"
de.SET_SECTION_DATA = "Daten"
en.SET_SECTION_GUILD = "Guild"
de.SET_SECTION_GUILD = "Gilde"
en.BTN_RESCAN = "Rescan professions"
de.BTN_RESCAN = "Berufe neu scannen"
en.BTN_SEND_ALL = "Send everything"
de.BTN_SEND_ALL = "Alles senden"
en.BTN_SYNC = "Sync with guild"
de.BTN_SYNC = "Mit Gilde abgleichen"
en.BTN_EXPORT = "CSV export"
de.BTN_EXPORT = "CSV-Export"
en.BTN_SCANBANK = "Scan bank"
de.BTN_SCANBANK = "Bank scannen"
en.BTN_VERSIONCHECK = "Check guild versions"
de.BTN_VERSIONCHECK = "Gilden-Versionen pruefen"
en.SET_DELETE_PROF = "Delete profession"
de.SET_DELETE_PROF = "Beruf loeschen"
en.BTN_DELETE_ALL = "Delete all data"
de.BTN_DELETE_ALL = "Alle Daten loeschen"
en.CONFIRM_DELETE_PROF = "Delete your profession %s from the database?"
de.CONFIRM_DELETE_PROF = "Deinen Beruf %s aus der Datenbank loeschen?"
en.CONFIRM_DELETE_ALL = "Delete ALL recipe data (yours and your guild's)? This cannot be undone."
de.CONFIRM_DELETE_ALL = "ALLE Rezeptdaten loeschen (deine und die der Gilde)? Das kann nicht rueckgaengig gemacht werden."
en.UNKNOWN_REPAIRED = "Repaired recipes that were filed under an unknown profession:"
de.UNKNOWN_REPAIRED = "Rezepte repariert, die unter einem unbekannten Beruf gespeichert waren:"

-- Alts des Accounts
en.ALT_OF = "Alt of"
de.ALT_OF = "Alt von"
en.ALTS_INCLUDED = "Alts of this account included:"
de.ALTS_INCLUDED = "Alts dieses Accounts einbezogen:"

-- Alt-Export / -Import
en.BTN_ALT_EXPORT = "Export alts"
de.BTN_ALT_EXPORT = "Alts exportieren"
en.BTN_ALT_IMPORT = "Import alts"
de.BTN_ALT_IMPORT = "Alts importieren"
en.BTN_CLOSE = "Close"
de.BTN_CLOSE = "Schliessen"
en.BTN_SELECT_ALL = "Select all"
de.BTN_SELECT_ALL = "Alles markieren"
en.BTN_DO_IMPORT = "Import"
de.BTN_DO_IMPORT = "Importieren"
en.ALTX_TITLE_EXPORT = "Export alts"
de.ALTX_TITLE_EXPORT = "Alts exportieren"
en.ALTX_TITLE_IMPORT = "Import alts"
de.ALTX_TITLE_IMPORT = "Alts importieren"
en.ALTX_INFO_EXPORT = "Ctrl+C to copy. Paste it into 'Import alts' on the account that should show these characters."
de.ALTX_INFO_EXPORT = "Strg+C zum Kopieren. Auf dem Account, der diese Charaktere zeigen soll, unter 'Alts importieren' einfuegen."
en.ALTX_INFO_IMPORT = "Paste the exported text here (Ctrl+V), then click Import."
de.ALTX_INFO_IMPORT = "Den exportierten Text hier einfuegen (Strg+V) und auf Importieren klicken."
en.ALTX_CHARS = "characters"
de.ALTX_CHARS = "Charaktere"
en.ALTX_PROFS = "professions"
de.ALTX_PROFS = "Berufe"
en.ALTX_NONE = "No characters with professions found. Open your profession windows first."
de.ALTX_NONE = "Keine Charaktere mit Berufen gefunden. Oeffne zuerst deine Berufsfenster."
en.ALTX_BAD = "That is not a valid or complete BananaCraft export. Copy the whole text."
de.ALTX_BAD = "Das ist kein gueltiger oder vollstaendiger BananaCraft-Export. Den ganzen Text kopieren."
en.ALTX_DONE = "Imported characters:"
de.ALTX_DONE = "Charaktere importiert:"
en.ALTX_SKIPPED = "Skipped (already your own characters):"
de.ALTX_SKIPPED = "Uebersprungen (sind schon eigene Charaktere):"
en.ALTX_HINT = "Click 'Share database with guild' to send them to your guild."
de.ALTX_HINT = "Mit 'Datenbank mit der Gilde teilen' an die Gilde senden."
en.ALTX_CLEARED = "Imported characters removed:"
de.ALTX_CLEARED = "Importierte Charaktere entfernt:"

-- Hauptcharakter und Alt-Bestaetigung
en.SET_PICK_MAIN_HINT = "Tip: pick your Main character in the settings (gear icon), so your alts show as 'Alt of <Main>'."
de.SET_PICK_MAIN_HINT = "Tipp: Waehle im Einstellungsfenster (Zahnrad) deinen Main, damit deine Alts als 'Alt von <Main>' erscheinen."
en.SET_ALT_CONFIRM = "Alt confirmation"
de.SET_ALT_CONFIRM = "Alt-Bestaetigung"
en.SET_ALT_CONFIRM_TIP = "Optional. Alts report themselves ('I am an alt of <Main>') when they log in, and the list shows 'confirmed' or 'claimed'. This is no proof of the same account."
de.SET_ALT_CONFIRM_TIP = "Optional. Alts melden sich beim Login selbst ('ich bin Alt von <Main>'), und die Liste zeigt 'bestaetigt' oder 'angegeben'. Das ist kein Beweis fuer denselben Account."
en.ALT_CONFIRMED = "confirmed"
de.ALT_CONFIRMED = "bestaetigt"
en.ALT_CLAIMED = "claimed"
de.ALT_CLAIMED = "angegeben"

-- Auswahlmenues Alts
en.SET_ALTS_OTHER = "Alts from other accounts"
de.SET_ALTS_OTHER = "Alts von anderen Accounts"
en.SET_ALTS_SAME = "Twinks on the same account"
de.SET_ALTS_SAME = "Twinks auf selbem Account"
en.SET_MENU_MAIN = "Choose Main"
de.SET_MENU_MAIN = "Main waehlen"
en.SET_MENU_SHARE = "Share with guild"
de.SET_MENU_SHARE = "Mit Gilde teilen"
en.SET_DD_NONE = "none imported"
de.SET_DD_NONE = "keine importiert"
en.SET_DD_IMPORTED_N = "%d imported"
de.SET_DD_IMPORTED_N = "%d importiert"
en.SET_DD_MAIN = "Main: %s"
de.SET_DD_MAIN = "Main: %s"
en.SET_DD_PICK = "Choose Main!"
de.SET_DD_PICK = "Main waehlen!"

-- Katalog
en.CMD_CATALOG = "/bc | /bc catalog  - open the recipe catalog (profession > tier/category)"
de.CMD_CATALOG = "/bc | /bc katalog  - Rezeptkatalog oeffnen (Beruf > Stufe/Kategorie)"
en.CAT_TITLE = "BananaCraft - Catalog"
de.CAT_TITLE = "BananaCraft - Katalog"
en.CAT_ONLY_CRAFTERS = "Only with crafters"
de.CAT_ONLY_CRAFTERS = "Nur mit Crafter"
en.CAT_ONLY_ONLINE = "Only online"
de.CAT_ONLY_ONLINE = "Nur online"
en.CAT_SEARCH_RESULTS = "Search results"
de.CAT_SEARCH_RESULTS = "Suchergebnisse"
en.CAT_SKILL = "Skill:"
de.CAT_SKILL = "Fertigkeit:"
en.CAT_REAGENTS = "Reagents:"
de.CAT_REAGENTS = "Reagenzien:"
en.CAT_CASTTIME = "Cast time:"
de.CAT_CASTTIME = "Zauberzeit:"
en.CAT_TOOLS = "Tools:"
de.CAT_TOOLS = "Werkzeug:"
en.CAT_NOCACHE = "Item not in the client cache yet - right-click loads it from the server."
de.CAT_NOCACHE = "Item noch nicht im Client-Cache - Rechtsklick laedt es vom Server."
en.CAT_CRAFTERS_N = "Crafters: %d (%d online)"
de.CAT_CRAFTERS_N = "Hersteller: %d (%d online)"
en.CAT_CRAFTER_NONE = "No known crafter in the guild"
de.CAT_CRAFTER_NONE = "Kein Hersteller in der Gilde bekannt"
en.CAT_HINT_CLICK = "Click: details and whisper"
de.CAT_HINT_CLICK = "Klick: Details und Whisper"
en.CAT_FOOTER = "Banana Republic"
de.CAT_FOOTER = "Banana Republic"

en.STATS_PLAYERS = "players"
de.STATS_PLAYERS = "Spieler"
en.STATS_RECIPES = "recipes"
de.STATS_RECIPES = "Rezepte"

-- Sammelberufe und Popup-Ueberschriften
en.CAT_CRAFTED_BY = "Can be crafted by:"
de.CAT_CRAFTED_BY = "Kann hergestellt werden von:"
en.CAT_GATHERED_BY = "Can be gathered by:"
de.CAT_GATHERED_BY = "Kann abgebaut/gesammelt werden von:"
en.CAT_GATHERERS_N = "Gatherers: %d (%d online)"
de.CAT_GATHERERS_N = "Sammler: %d (%d online)"
en.CAT_GATHERER_NONE = "Nobody known yet. Each player's skill is recorded once they log in with this version."
de.CAT_GATHERER_NONE = "Noch niemand bekannt. Der Fertigkeitswert wird erfasst, sobald der Spieler mit dieser Version einloggt."
en.CAT_GATHER_HEADER = "Gathering"
de.CAT_GATHER_HEADER = "Sammeln"
en.CAT_NEEDS_SKILL = "needs skill"
de.CAT_NEEDS_SKILL = "benoetigt Fertigkeit"
