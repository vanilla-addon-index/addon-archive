-- Freewood-OctoWoW-Loot: Texte
local ADDON, NS = ...

local FW = _G.Freewood
if not FW then
    return
end

FW:AddLocale("enUS", {
    LOOT_TITLE = "Loot Blacklist",
    LOOT_DESC = "Picks up listed items and deletes them with your next click in the world.",
    LOOT_TAB = "Loot",

    LOOT_LIST_HEADER = "Blacklist (this character)",
    LOOT_LIST_EMPTY = "The blacklist is empty. Add items on the right.",
    LOOT_PENDING = "waiting: %d",
    LOOT_REMOVE = "Remove from blacklist",

    LOOT_ADD_HEADER = "Add item",
    LOOT_ADD_DROP = "Drop an item from your bags here",
    LOOT_ADD_BOX = "Item link or ID",
    LOOT_ADD_BUTTON = "Add",
    LOOT_ADD_OK = "Added: %s",
    LOOT_ADD_ALREADY = "Already on the blacklist.",
    LOOT_ADD_INVALID = "Not a valid item.",
    LOOT_ADD_FULL = "The blacklist is full.",
    LOOT_ADD_HINT = "Shift-click an item link into the field, or type the item ID.",

    LOOT_RECENT_HEADER = "Recently received",
    LOOT_RECENT_EMPTY = "Nothing looted yet.",
    LOOT_RECENT_ADD = "+ List",
    LOOT_RECENT_LISTED = "listed",

    LOOT_LOG_HEADER = "Deleted",
    LOOT_LOG_EMPTY = "Nothing deleted yet.",
    LOOT_LOG_LINE = "%s  %s x%d",

    LOOT_SET_HEADER = "Loot blacklist",
    LOOT_SET_ENABLED = "Delete listed items on my next click in the world",
    LOOT_SET_AUTOLOOT = "Pick up listed items automatically from loot windows",
    LOOT_SET_CHAT = "Report deleted items in chat",
    LOOT_SET_NOTE = "Deleting needs a click from you: the game allows addons to delete only one item per mouse click.",

    LOOT_DELETED = "Deleted: %s x%d",
    LOOT_BLOCKED = "The game blocked deleting items. Waiting items stay in your bags. Use /fwloot test.",

    LOOT_TEST_API = "API: container %s, delete %s, world click %s",
    LOOT_TEST_PENDING = "Waiting items: %d. Click into the game world to delete one.",
    LOOT_TEST_NONE = "No listed item in your bags. Put a listed item in your bags and try again.",
    LOOT_TEST_RESET = "Block flag reset.",
    LOOT_YES = "yes",
    LOOT_NO = "no",

    LOOT_EXPORT_LABEL = "Loot blacklist",
    LOOT_IMPORT_STATS = "%d new, %d already listed",
    LOOT_IMPORT_EMPTY = "no valid entries",
    LOOT_IMPORT_TOO_MANY = "too many entries",
})

FW:AddLocale("deDE", {
    LOOT_TITLE = "Beute-Blacklist",
    LOOT_DESC = "Nimmt gelistete Items mit und löscht sie mit deinem nächsten Klick in der Spielwelt.",
    LOOT_TAB = "Beute",

    LOOT_LIST_HEADER = "Blacklist (dieser Charakter)",
    LOOT_LIST_EMPTY = "Die Blacklist ist leer. Füge rechts Items hinzu.",
    LOOT_PENDING = "wartend: %d",
    LOOT_REMOVE = "Von der Blacklist entfernen",

    LOOT_ADD_HEADER = "Item hinzufügen",
    LOOT_ADD_DROP = "Item aus der Tasche hier ablegen",
    LOOT_ADD_BOX = "Item-Link oder ID",
    LOOT_ADD_BUTTON = "Hinzufügen",
    LOOT_ADD_OK = "Hinzugefügt: %s",
    LOOT_ADD_ALREADY = "Steht schon auf der Blacklist.",
    LOOT_ADD_INVALID = "Kein gültiges Item.",
    LOOT_ADD_FULL = "Die Blacklist ist voll.",
    LOOT_ADD_HINT = "Item-Link mit Shift-Klick ins Feld setzen oder die Item-ID eintippen.",

    LOOT_RECENT_HEADER = "Zuletzt erhalten",
    LOOT_RECENT_EMPTY = "Noch nichts gelootet.",
    LOOT_RECENT_ADD = "+ Listen",
    LOOT_RECENT_LISTED = "gelistet",

    LOOT_LOG_HEADER = "Gelöscht",
    LOOT_LOG_EMPTY = "Noch nichts gelöscht.",
    LOOT_LOG_LINE = "%s  %s x%d",

    LOOT_SET_HEADER = "Beute-Blacklist",
    LOOT_SET_ENABLED = "Gelistete Items mit meinem nächsten Klick in der Spielwelt löschen",
    LOOT_SET_AUTOLOOT = "Gelistete Items aus Beutefenstern automatisch mitnehmen",
    LOOT_SET_CHAT = "Gelöschte Items im Chat melden",
    LOOT_SET_NOTE = "Zum Löschen braucht es einen Klick von dir: das Spiel erlaubt Addons nur ein gelöschtes Item pro Mausklick.",

    LOOT_DELETED = "Gelöscht: %s x%d",
    LOOT_BLOCKED = "Das Spiel hat das Löschen blockiert. Wartende Items bleiben in deinen Taschen. Nutze /fwloot test.",

    LOOT_TEST_API = "API: Container %s, Löschen %s, Weltklick %s",
    LOOT_TEST_PENDING = "Wartende Items: %d. Klicke in die Spielwelt, um eins zu löschen.",
    LOOT_TEST_NONE = "Kein gelistetes Item in deinen Taschen. Lege eins in die Tasche und versuche es erneut.",
    LOOT_TEST_RESET = "Sperrmarke zurückgesetzt.",
    LOOT_YES = "ja",
    LOOT_NO = "nein",

    LOOT_EXPORT_LABEL = "Beute-Blacklist",
    LOOT_IMPORT_STATS = "%d neu, %d schon gelistet",
    LOOT_IMPORT_EMPTY = "keine gültigen Einträge",
    LOOT_IMPORT_TOO_MANY = "zu viele Einträge",
})
