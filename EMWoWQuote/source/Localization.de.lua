WQcategories = {
    "Siege",
    "Niederlagen",
    "Emotionen (positiv)",
    "Emotionen (negativ)",
    "Teams & Gilden",
    "Dungeons & Quests",
    "RPG & Community",
    "PvP",
    "Sonstige"
};

WQChannels = {
    ["s"] = { ["name"] = "Umgebung", ["event"] = "CHAT_MSG_SAY" },
    ["p"] = { ["name"] = "Gruppe", ["event"] = "CHAT_MSG_PARTY" },
    ["r"] = { ["name"] = "Raid", ["event"] = "CHAT_MSG_RAID"},
    ["g"] = { ["name"] = "Gilde", ["event"] = "CHAT_MSG_GUILD"},
	["o"] = { ["name"] = "Offiziere", ["event"] = "CHAT_MSG_OFFICER"}
};

WQ_HELP = {
    "--- WoWQuote HILFE ---\n",
	"|cffffffff- /wqh : |r |cff7090ffZeigt diese Hilfe an",
    "|cffffffff- /wqb [channel] [on|off]: |r |cff7090ffZeigt an oder verwaltet die Einstellungen fuer den Channel-Empfang von Quotes. Moegliche Channels sind: s(ay), p(arty), r(aid), g(uild) oder (o)fficer",
    "|cffffffff- /wqc : |r |cff7090ffListet alle verfuegbaren Kategorien mit IDs auf",
    "|cffffffff- /wql <Kategorie-ID>: |r |cff7090ffListet alle verfuegbaren Quotes in der entsprechenden Kategorie mit IDs auf",
    "|cffffffff- /wqf <Zeichenkette>: |r |cff7090ffListet alle Quotes auf, die die entsprechende Zeichenkette beinhalten",
    "|cffffffff- /wqa <Quote-ID> [Alias]: |r |cff7090ffWeist einem Quote einen userdefinierten Namensalias zu. Wenn die Aliasname-Angabe fehlt, wird der alte Alias geloescht",
    "|cffffffff- /wqs <Quote-ID|Alias>: |r |cff7090ffIn die Umgebung quoten",
    "|cffffffff- /wqp <Quote-ID|Alias>: |r |cff7090ffIn den Gruppenchannel quoten",
    "|cffffffff- /wqg <Quote-ID|Alias>: |r |cff7090ffIn den Gildenchannel quoten",
    "|cffffffff- /wqr <Quote-ID|Alias>: |r |cff7090ffIn den Raidchannel quoten",
    "|cffffffff- /wqo <Quote-ID|Alias>: |r |cff7090ffIn den Offizierschannel quoten"
};

WQ_MSG = {
	["msg_loaded"] = "%s v%s geladen. /wq eintippen fuer mehr Informationen.",
	["msg_cat_title"] = "%s - Verfuegbare Kategorien:",
	["msg_conf_title"] = "%s - Aktuelle Broadcast-Einstellungen:",
	["msg_qlist_title"] = "\n%s - Quotes aus '%s':",
	["err_cat_id"] = "Gueltige Kategorien-ID erwartet! /wqc zeigt eine Uebersicht.",
	["err_quote_not_found"] = "Quote-ID \"%s\" nicht gefunden!",
	["err_miss_channel"] = "Channel muss s, p, r, g oder o sein.",
	["err_miss_switch"] = "Bitte on oder off angeben.",
	["err_no_alias_id"] = "Verwendung: /wqa <Quote-ID> [Alias]",
	["err_wrong_alias"] = "Ungueltiger Alias angegeben. Erlaubt ist nur eine Folge aus Buchstaben oder Zahlen. Das erste Zeichen muss ein Buchstabe sein. Der Alias darf maximal 20 Zeichen lang sein.",
	["err_alias_not_found"] = "Quote-ID %s hat keinen definierten Alias.",
	["msg_alias_disabled"] = "Alias fuer Quote-ID %s wurde entfernt.",
	["msg_alias_set"] = "Alias fuer Quote-ID %s wurde gesetzt auf '%s'.",
	["msg_chan_on"] = "Empfang auf Channel '%s' wurde AKTIVIERT.",
	["msg_chan_off"] = "Empfang auf Channel '%s' wurde DEAKTIVIERT.",
	["err_search_len"] = "Suchzeichenfolge muss mindestens %s Zeichen lang sein.",
	["msg_search_count"] = "%s Quotes gefunden."
};