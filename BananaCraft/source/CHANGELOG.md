# Changelog

Alle nennenswerten Änderungen an BananaCraft. Neueste Version oben.

## 3.0.0

- **Neu: Rezeptkatalog.** Das Hauptfenster ist jetzt ein Katalog im Stil von AtlasLoot: links der Beruf, in der Mitte Stufe/Kategorie (Apprentice, Journeyman, Expert, Artisan, Flasks, Protection Potions, Helm, Chest, …), rechts die Rezepte. Tooltips wie im Spiel, Qualitätsfarben, Filter „Nur mit Crafter" und „Nur online". Die Suche nach dem Namen bleibt und durchsucht alle Berufe; der Shift-Klick ins Suchfeld funktioniert weiter. Klick auf ein Rezept öffnet die Detailansicht mit Materialien, Herstellern und Whisper (rechts neben dem Katalog). Die bisherige Crafter-Liste entfällt.
- **Neu: Sammelberufe.** Kräuterkunde und Bergbau zeigen, wer welches Vorkommen abbauen bzw. ernten kann. Dafür liest der Addon den eigenen Fertigkeitswert aus und teilt ihn mit der Gilde.
- **Materialien für alle Rezepte.** Verzauberungen lesen ihre Materialien aus dem Tooltip des Spielclients, die „Crafted Epic Weapons" sind mit ihrem Herstellungsrezept verknüpft. `/bc checkmats` prüft, dass jedes Rezept Materialien hat.
- **Update ohne Löschen:** der Ordner heißt weiter `BananaCraft`, die gespeicherten Daten (`BananaCraftDB`) und das Nachrichten-Prefix bleiben gleich. Neue Version einfach über die alte kopieren; Gilden mit gemischten Versionen (2.x und 3.0) synchronisieren weiter miteinander.

## 2.7.0

- **Entfernt: die komplette Partnerfunktion** (Partnergilde, Einladecode, Partnerkanal, `/bc partner ...`, Partner-Bereich im Einstellungsfenster, `BananaCraft_Partner.lua`). Beim ersten Start räumt der Addon die Daten der bisher bekannten Partnergilden und den Partnerbereich aus der Datenbank; die eigene Gilde bleibt unangetastet. Alts, Main und Export/Import laufen unverändert über die Gilde.
- **Fix: Inkompatibilität mit GroupFinder und ähnlichen Chat-Addons.** BananaCraft hatte sich beim Login immer in `ChatFrame_OnEvent` eingehängt und dabei Hooks überschrieben, die andere Addons beim Laden gesetzt hatten. GroupFinder bekam dadurch keine Chatzeilen mehr und lief nicht. BananaCraft ersetzt `ChatFrame_OnEvent` beim Login nicht mehr.

## 2.6.1

- **Einstellungsfenster: zwei Auswahlmenüs statt Liste.** Links „Alts von anderen Accounts" (importierte Charaktere, nur teilen/nicht teilen), rechts „Twinks auf selbem Account" (Main wählen und Twinks teilen/nicht teilen). Der Main ist nur rechts wählbar. Die Menüköpfe zeigen den Stand („Main: Lumihunt", „2 importiert").

## 2.6.0

- **Neu: Hauptcharakter festlegen.** Im Einstellungsfenster (Bereich „Charaktere dieses Accounts") wählt jeder Spieler per Auswahl rechts neben dem Namen seinen **Main**. Alle anderen Charaktere des Accounts sind „Alt von <Main>", egal mit welchem Charakter man eingeloggt ist; links neben dem Namen lässt sich jeder Alt abwählen (der Main und der aktuelle Charakter werden immer geteilt). Ohne gewählten Main gilt wie bisher der eingeloggte Charakter.
- **Neu: Alt-Bestätigung (optional, standardmäßig aus).** Mit dem Haken „Alt-Bestätigung" melden sich Alts beim Login selbst („ich bin Alt von <Main>"), und die Liste zeigt „bestätigt" oder „angegeben". Eigene Charaktere gelten immer als bestätigt. **Das ist kein Beweis für „derselbe Account":** der 1.12-Client kennt keine Konto-Kennung, die Angabe stammt immer vom Absender.
- **Neu: Plausibilitätsprüfung der Zuordnung.** Eine Angabe „X ist Alt von Y" wird nur akzeptiert, wenn der Absender X, Y oder ein bekannter Alt von Y ist. Zuordnungen tragen einen Zeitstempel (die neueste gilt), und ein Wechsel des Mains oder Abwählen eines Alts entfernt den Zusatz bei den anderen. Fremde Zuordnungen werden nicht mehr weitergereicht, sie kommen nur vom Besitzer.

## 2.5.0

- **Neu: Shift-Klick ins Suchfeld.** Steht der Cursor im Suchfeld, schreibt ein Shift-Klick auf ein Item, eine Verzauberung oder ein Rezept (Taschen, Berufsfenster, Händler, Chat-Links) dessen Namen ins Suchfeld und startet die Suche. Vorsilben wie „Formula:", „Pattern:" oder „Enchanting:" werden entfernt. Ohne Cursor im Suchfeld oder ohne Shift verhält sich der Chat wie gewohnt.

## 2.4.0

- **Neu: Alts von anderen Accounts per Export/Import.** Im Einstellungsfenster gibt es *Alts exportieren* und *Alts importieren*. Auf dem Account mit den Alts exportieren und den Text mit Strg+C kopieren, auf dem Hauptaccount im Importfenster mit Strg+V einfügen. Der Text wird nur als Daten gelesen (nichts wird ausgeführt), eine Prüfsumme erkennt abgeschnittene oder kaputte Texte. Importierte Charaktere verhalten sich wie eigene Alts: Abwählen im Einstellungsfenster, Teilen als „Alt von …" mit *Share database with guild*. Eigene, selbst gescannte Charaktere werden nie überschrieben. Befehle: `/bc altexport`, `/bc altimport`, `/bc altclear` (entfernt alle importierten Charaktere).
- **Fix: CSV-Export** schlug im Spiel fehl (`string.gmatch` gibt es in WoW 1.12 nicht, dort heißt es `string.gfind`).
- **Fix: Alts verschwanden nach 14 Tagen** aus der Liste, wenn sie lange nicht eingeloggt waren. Beim Veröffentlichen gilt ihr Stand jetzt als frisch.

## 2.3.0

- **Neu: Alts des Accounts.** „Datenbank mit der Gilde teilen" nimmt jetzt auch die Berufe aller anderen Charaktere deines Accounts mit (die Daten liegen schon account-weit in `BananaCraftDB`; der Alt muss einmal mit dem Addon eingeloggt gewesen sein und seine Berufsfenster geöffnet haben). Sie erscheinen in der Gilde als Mitglied mit dem Zusatz „Alt von <Charakter>", unabhängig davon, ob der Alt in einer anderen Gilde oder gildenlos ist. Ist der Alt offline, aber der Besitzer online, gilt er als erreichbar und der Whisper geht an den Besitzer. Alts anderer Realms werden nicht geteilt. Im Einstellungsfenster lässt sich jeder Alt abwählen („Haken = wird geteilt"). Ohne Gilde werden keine Alts veröffentlicht.
- **Fix: Rezepte unter „UNKNOWN".** Öffnete man ein Berufsfenster, bevor das Spiel den Berufsnamen geladen hatte, lieferte es den Platzhalter `UNKNOWN`, und die Rezepte landeten unter diesem Beruf (Anzeige „UNKNOWN 0/0"). Der Scan wartet jetzt und versucht es erneut, eingehende Daten mit diesem Beruf werden verworfen. Vorhandene Einträge repariert der Addon beim Start anhand seiner Rezeptdatenbank (7 Berufe). Rezepte anderer Berufe (Kochen, Erste Hilfe) unter UNKNOWN werden gelöscht und beim nächsten Öffnen des Berufsfensters neu gescannt.
- **Neu: Haken „Nur online"** über der Liste.
- **Neu: Einstellungsfenster (Zahnrad)** mit Sprache, Nur-online, Minimap-Button, Debug, Berufe neu scannen, Alles senden, Abgleich, CSV-Export, Bank scannen, Versionen prüfen und Löschen (mit Rückfrage). Die `/bc`-Befehle bleiben.
- **Partnermodus ist nach jedem Login aus** und wird nur per `/bc partner on` (oder `create`/`add`) eingeschaltet. Das Hauptfenster hat nur noch den Button „Datenbank mit der Gilde teilen". Der Partner-Bereich (Code erstellen, Mit Code verbinden, An Partner teilen, Gildenmitglieder verbinden, Modus ausschalten) steht im Einstellungsfenster und ist nur sichtbar, solange der Modus an ist. Bei ausgeschaltetem Modus werden Codes anderer ignoriert, und nach dem Login wird nicht mehr automatisch nach einem Code gefragt.
- **Fix: Beruf löschen** entfernt jetzt auch den Eintrag in der Gildenliste (`Name@Gilde`).
- **Partnerkanal getrennt vom Gilden-Sync.** „Datenbank mit der Gilde teilen" sendet nur noch in den Gildenkanal. Der Partner-Sync (`/bc partner share` oder Einstellungsfenster) sendet nur eigene Daten und nur auf Knopfdruck, eigene Scans gehen nicht mehr automatisch an den Partner. `/bc partner off` beendet die Partnerschaft nicht mehr (dafür `/bc partner leave`).
- **Fix: „Alle Berufe wurden gesendet!" kam zu früh.** Die Meldung erscheint jetzt erst, wenn auch die Sendewarteschlangen (Gilde und Partnerkanal) leer sind. Der Partnerkanal sendet zusätzlich langsamer (1 Nachricht alle 1,5 Sekunden), weil der Server bei schnellerem Tempo weiter „You must wait N seconds before speaking again" meldete.
- **Fix: Versionsanzeige im Fenster.** Links unten stand fest `v1.0.0`, jetzt wird die echte Version (`ADDON_VERSION`) angezeigt.
- **Fix: „You must wait N seconds before speaking again" beim Teilen.** Der Partnerkanal lief mit 2,5 Nachrichten/Sekunde in den Chat-Spamschutz des Servers. Er sendet jetzt höchstens 1 Nachricht/Sekunde. Meldet der Server trotzdem die Sperre, pausiert die Warteschlange für die genannte Zeit und sendet die verworfene Nachricht danach erneut.
- **Fix: Esc schließt BananaCraft.** Hauptfenster, Rezept-Popup und Export-Fenster sind jetzt in `UISpecialFrames` eingetragen.
- **Fix: Eigener Charakter doppelt in der Crafter-Liste.** Wer vor dem Gildenbeitritt gildenlos war, stand als `<no guild (Name)>` (nicht erreichbar) zusätzlich zum echten Eintrag in der Liste. Solche veralteten Solo-Einträge werden jetzt beim Start entfernt, sobald die Gilde bekannt ist.

## 2.2.1

- **Neuer Name: BananaCraft** (vorher BananaRepublik Partnerguild). Addon-Ordner, alle Dateien, Fenstertitel, Minimap-Tooltip und Logo-Dateien heißen jetzt BananaCraft. Auch intern ist alles umbenannt: Befehl `/bc` (statt `/brpp`), gespeicherte Daten `BananaCraftDB`, Netzwerkprefix `BCRAFT0`, Funktionen `BCRAFT_*`. Da das Addon noch nicht veröffentlicht war, gibt es keine Übernahme alter Daten und keine Kompatibilität zu Testständen der alten Version. Den alten Ordner `BananaRepublik_Partnerguild` löschen.
- **Testdaten entfernt.** `BananaRepublik_Partnerguild_TestData.lua` und der Befehl `/brpptest` sind weg, die Tests waren erfolgreich. Reste aus früheren Testläufen werden beim ersten Start automatisch aus der Datenbank gelöscht.
- **Versionsnummer angeglichen.** `.toc`, Addon-Code (`/bc versioncheck`) und Changelog nennen jetzt alle 2.2.1.
- **Fix: Unterkategorie-Dropdown.** Beim Berufswechsel wurde das Dropdown mit `nil` initialisiert.
- **Fix: Oberfläche nach „Datenbank löschen".** Das Fenster wurde nicht neu gezeichnet, weil der Code den nicht vorhandenen Frame `BCRAFT_Frame` prüfte statt `BRPP_MainFrame`.
- **Fix: Minimap-Button ohne Bild.** Der Button wird jetzt komplett in Lua gebaut (ein Button mit Icon und Rahmen) statt per XML mit Frame und Kind-Button, wie bei den anderen BananaForge-Addons. Die XML-Datei entfällt. UI-Addons wie pfUI räumten die alte Bauweise leer.
- **Neues Logo** oben links im Fenster und als Minimap-Button.
- Repository wie die anderen BananaForge-Addons aufgebaut: README, MIT-Lizenz, Release-Workflow.

## 2.0.0

- Partnergilden-Kommunikation über Einladecode.
- Gildenbewusste Datenbankschlüssel (`Charname@Gilde`).
- Partnergilden-Markierung in der Oberfläche.
