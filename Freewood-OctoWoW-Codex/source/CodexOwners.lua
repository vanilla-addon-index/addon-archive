-- Freewood-OctoWoW-Codex: Eigentuemer der Datenbank
--
-- Hier stehen die Charaktere (Name-Realm), die DEV-Rechte vergeben duerfen. Nur Listen, die von einem dieser
-- Charaktere kommen, werden von anderen Spielern uebernommen. Der Absender einer Addon-Nachricht wird vom
-- Spiel gesetzt und kann nicht gefaelscht werden.
--
-- Eintrag zum Beispiel:   "Lacustat-NZoth",
-- (Name-Realm, Realm ohne Apostroph und Leerzeichen: NZoth, CThun, YShaarj. Ohne Realm gilt der eigene Realm.
--  Auf OctoWoW haben Charaktere nur einen Namen.)
--
-- Ist die Liste leer, gibt es niemanden mit DEV-Rechten: Namen koennen dann nicht bearbeitet werden.

local ADDON, NS = ...
if not NS then
    return
end

NS.Owners = {
    "Fwaroki-NZoth",       -- PvE
    "Freewood-CThun",      -- Hardcore
    "Fwfreewood-YShaarj",  -- PvP
}

-- Fest eingetragene Moderatoren (duerfen Namen aendern, Datensaetze markieren, Verbindungen und Ortspunkte weitergeben).
-- Gilt zusaetzlich zur Liste, die ein Eigentuemer ueber das Modul Rechte veroeffentlicht. Eine Sperre (blocked) dort geht vor.
NS.Moderators = {
    "Pinkytwinky",
    "Lacustat",
    "Dipps",
    "Arokisteel",
    "Windsteel",
}
