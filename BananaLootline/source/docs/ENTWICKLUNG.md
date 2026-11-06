# BananaLootline – Entwicklung

Stand: Version 0.19.0. Dieses Dokument reicht, um am Addon weiterzuarbeiten.

---

## Technische Rahmenbedingungen

Diese Punkte haben die meisten Fehler verursacht.

**Lua 5.0, nicht 5.1.** Kein `#`-Operator (`table.getn`), kein `string.gmatch` (`string.gfind`), kein `select`. Handler nutzen die globalen `this`, `event`, `arg1`. Ein Parameter namens `arg` kollidiert mit der Vararg-Tabelle.

**`GameTooltip:GetItem()` existiert in 1.12 nicht.** Tooltip-Hooks merken sich den Itemlink beim Setzen (`SetHyperlink`, `SetBagItem`, `SetInventoryItem`, `SetLootItem`).

**`SetHyperlink` nimmt nur den nackten Teil** `item:12345:0:0:0`. Suffix-IDs können negativ sein.

**`ClearLines()` löscht die Texte nicht.** Beim Tooltip-Scan die FontStrings explizit leeren, sonst erbt ein Item die Zeilen des vorherigen.

**`GetItemInfo` liefert kein Itemlevel** und für nicht gecachte Items `nil`. Ein Tooltip-Aufruf stösst die Serverabfrage an, die Antwort kommt verzögert.

**`UNIT_INVENTORY_CHANGED` feuert ständig**, auch bei Haltbarkeitsverlust. Ohne Signaturvergleich läuft der Scan im Kampf im Sekundentakt.

**Bilder:** nur BLP oder unkomprimierte TGA, Kantenlänge als Zweierpotenz. PNG wird ohne Fehlermeldung nicht angezeigt.

**Der Addon-Ordner muss `BananaLootline` heissen.** Der Logopfad ist fest auf `Interface\AddOns\BananaLootline\Images\BananaForge` gesetzt.

**Zwei Sprachen, getrennt:**
- `BLL.clientLocale` ist die Sprache des Clients. Sie bestimmt Tooltip-Muster, Rüstungsnamen und Namen der Waffenfertigkeiten, denn diese Texte liefert der Client.
- `BLL.locale` ist die Anzeigesprache, umschaltbar über DE/EN. Wer die beiden verwechselt, zerstört beim Umschalten die Werteerkennung.

**`BLL.L` bleibt dieselbe Tabelle.** Core.lua und Sources.lua halten sie lokal. `SetLanguage` tauscht den Inhalt aus, nicht die Tabelle.

**Syntaxprüfung reicht nicht.** `luac -p` meldet nichts bei fehlenden Funktionen oder leeren Dateien. `tools/run_tests.sh` prüft deshalb zusätzlich die Dateigrösse und führt die Funktionstests aus.

---

## Aufbau

```
BananaLootline.toc
Locale.lua           UI-Strings DE/EN, Tooltip-Muster je Clientsprache, Statliste
Data/ItemData.lua    11349 Items – generiert, nicht von Hand bearbeiten
Data/SetData.lua     172 Sets mit Boni – generiert
Data/ZoneData.lua    50 Instanzen: Kategorie, Stufenbereich – generiert
Data/EnchantData.lua 111 Verzauberungen – generiert
ItemDB.lua           Zugriff auf Itemdaten
SetDB.lua            Sets, Mitgliedschaft, Bonusschwellen
EnchantDB.lua        Verzauberungsbewertung, Klassenfilter
Weights.lua          Statgewichte, Specerkennung, Scoring
Core.lua             Init, Events, Slash-Befehle, Migration von OctoLootline
Scanner.lua          Tooltip-Scan -> Statwerte
Sources.lua          pfQuest-Adapter, Tooltip-Hooks
Gear.lua             Ausrüstungsscan, Signatur, Export
Candidates.lua       Kandidatensuche, Waffenfertigkeiten, Lootline, Bewertung
UI.lua               Fenster: Puppe, Modell, Statfeld, drei Ansichten, Dankesfenster
Images/BananaForge.tga
tools/               Importwerkzeuge und Tests
docs/                diese Dokumentation
```

**`Data/*.lua` sind reine Daten** und werden von den Konvertern überschrieben. Die `*DB.lua` daneben enthalten den Code und dürfen nie überschrieben werden. Diese Trennung entstand, nachdem ein Import einmal die Lesefunktionen gelöscht hat.

---

## Datenquellen

### pfQuest / pfQuest-octo

Wird zur Laufzeit gelesen, nicht mitgeliefert (`items-turtle.lua` allein ist 7,5 MB). Liefert Loot-Quellen, Mob-Level, Zonen, Questgeber und Rassenmasken.

```lua
pfDB["items"]["data"][itemID] = {
  ["U"] = { [unitID] = chance },   -- Mob, Chance in Prozent
  ["O"] = { [objectID] = chance }, -- Objekt
  ["V"] = { [vendorID] = 0 },      -- Händler: 0 heisst sicher, nicht nie
  ["Q"] = { [questID] = 1 },       -- Quest: 1 ist kein Prozentwert
  ["L"] = { [refID] = chance },    -- Referenz-Loottabelle
}
```

Sources.lua setzt bei Quests und Händlern `chance = nil` und `sure = true`. Als Prozent gelesen, verlor jede Questbelohnung gegen einen Mob-Drop ab 1,1 %.

### octowow.st/db

Steht hinter einer Blazingfast-Browserprüfung. Direkter Abruf per Python oder curl scheitert, alles läuft über Browserskripte in der Konsole.

Filtersyntax: `?items=<Klasse>.<Subklasse>.<Slot>`, `?spells=11.<Beruf>`, `?itemsets`, `?items=-500` für serverspezifische Items. Listen sind bei 500 Einträgen gekappt (Zauber bei 300).

---

## Datenimport

| Datei | Zweck |
|---|---|
| `tools/octodb_all.js` | Gesamtdurchlauf: Waffen, alle Rüstungsarten, Relikte, Zubehör in einer Datei |
| `tools/octodb_batch.js` | mehrere Slots in einem Lauf |
| `tools/octodb_details.js` | Einzelseiten der gefilterten Liste: volle Werte und Effekttexte |
| `tools/octodb_rest.js` | restliche Rüstung nachholen |
| `tools/octodb_final.js` | Waffen, Relikte und Nachlese |
| `tools/octodb_missing.js` | fehlende Daten gezielt nachholen |
| `tools/octodb_extract.js` | eine einzelne gefilterte Liste exportieren |
| `tools/octodb_sets.js` | Itemsets und Bonusschwellen |
| `tools/octodb_enchants.js` | Verzauberungen aus der Zauberdatenbank |
| `tools/octodb_build.py` | **Konverter:** Item- und Set-Export -> ItemData.lua, SetData.lua |
| `tools/octodb_enchants_build.py` | **Konverter:** Verzauberungsexport -> EnchantData.lua |
| `tools/octodb_import.py` | veraltet, schreibt ein älteres Format. Nicht mehr verwenden, `octodb_build.py` ersetzt ihn. |

Ablauf:
1. Browserskript in der Konsole auf octowow.st/db ausführen. Das JSON landet in den Downloads.
2. JSON in einen Ordner ausserhalb des Repos legen. Rohdaten gehören nicht ins Repo, siehe `.gitignore`.
3. Konverter in einen **Zwischenordner** schreiben lassen, nicht direkt nach `Data/`:
   ```bash
   python3 tools/octodb_build.py ~/exports -o /tmp/build
   ```
   Enthält der Export nur Items, würde der Konverter sonst `SetData.lua` mit einem leeren Stand überschreiben.
4. Stichprobe: alten und neuen Stand vergleichen. Kein bestehender Wert darf sich unerwartet ändern. Rüstungswerte gegen die Listenspalte gegenrechnen ist der schnellste Plausibilitätstest.
5. Erst dann die Datei nach `Data/` kopieren.

**Die Browserskripte speichern immer die Effekttexte mit.** Fehlt ein Auswertungsmuster, lässt sich dieselbe Datei erneut durchlaufen, statt 25 Minuten neu zu sammeln.

**Was der Konverter aus Effekttexten nachträgt:** Kurzformen wie „+14 Attack Power." und „Increased Defense +4." Er überspringt Sätze mit Bedingung („when fighting", „forms only", „for 10 sec", „20% chance"), weil sie keine Dauerwerte sind. Angriffskraft ohne zugehörigen Effekttext verwirft er. Das war bei den Cryptstalker-Teilen der pro Teil verbuchte Setbonus.

---

## Bewertung

- **Statgewichte** pro Klasse in `Weights.DEFAULTS`, überschrieben pro Spezialisierung in `Weights.SPECS`. Die Spec-Erkennung greift erst ab 10 vergebenen Talentpunkten.
- **Jäger belegt:** Icy Veins, „Classic Hunter DPS Stat Priority" (Stand 17.11.2024), Bezug Stufe 60. Die übrigen Klassen sind Schätzwerte.
- **Prozentwerte** wie Krit und Treffer kommen als kleine Zahlen aus dem Tooltip und brauchen Gewichte im Bereich 15–35.
- **Equip-Effekte** stehen bereits in den Werten und dürfen nicht doppelt zählen. Use-Effekte zählen anteilig nach Dauer und Abklingzeit (angenommen 180 s).
- **Das angelegte Teil** braucht dieselben Zuschläge wie der Kandidat, sonst gewinnt jeder Kandidat automatisch.
- **Lootline-Priorität** = Summe aus Zuwachs × Dropchance. Quests und Händler zählen mit Faktor 1. Bei Quests mit Auswahlbelohnung zählt nur das beste Teil.

### Waffen

- `WEAPON_PROFICIENCY` in Candidates.lua: welche Waffenarten eine Klasse überhaupt lernen kann. Quellen: Allakhazam „Weapons (WoW)", Icy Veins und Wowhead Classic-Waffenguides.
- `Cand:ScanWeaponSkills()` liest die gelernten Fertigkeiten aus dem Fertigkeitenfenster. Eingeklappte Überschriften werden kurz aufgeklappt und danach wiederhergestellt. Neu eingelesen wird bei `SKILL_LINES_CHANGED` und `CHARACTER_POINTS_CHANGED`.
- Fehlt eine Fertigkeit, ist sie beim Waffenmeister ab Stufe 10 lernbar, Stangenwaffen ab 20. Talentwaffen (Schamane: Zweihandäxte und -kolben) lehrt kein Waffenmeister, sie erscheinen nur mit Talent.
- Beidhändigkeit: gilt, sobald der Client sie meldet. Sonst Schurke ab 10, Krieger und Jäger ab 20.
- Erkennt der Scan keine einzige Fertigkeit (unbekannte Clientsprache), prüft das Addon nur die Klassentabelle.

### Cache

`BananaLootlineDB.itemcache` hält Werte pro Item. `Cand.CACHE_VERSION` erzwingt ein Neueinlesen, wenn sich die Auswertung ändert (aktuell 4). Aussortier-Markierungen aus dem Import (`pre = 1`) werden bei jedem Lauf neu berechnet, weil sie von Stufe und Rüstungsart abhängen.

---

## Tests

```bash
bash tools/run_tests.sh
```

Der Runner prüft die Syntax aller Lua-Dateien, findet verdächtig kleine Dateien und führt alle `tools/test_*.lua` sowie `tools/test_build.py` aus. Bei einem Fehler endet er mit Exit-Code 1. GitHub Actions führt ihn bei jedem Push aus.

Die Tests stellen den 1.12-Client nach: Frames, FontStrings mit Breitenmessung, Fertigkeitenfenster, pfQuest-Daten. Sie laufen mit Lua 5.1, sperren aber `string.gmatch` und `select`. Das ist keine vollständige 5.0-Nachbildung.

| Test | Prüft |
|---|---|
| `test_patterns.lua` | Tooltip-Muster: RAP vor AP, Verteidigung, Schulschaden |
| `test_point1.lua` | Beidhändigkeit, sichere Quellen |
| `test_weaponskills.lua` | Waffenfertigkeiten aus dem Client, Talentwaffen, Rückfall |
| `test_preload.lua` | Neubewertung aussortierter Items nach Stufenaufstieg |
| `test_questchoice.lua` | Lootline-Priorität, Auswahlbelohnungen |
| `test_listview.lua` | Scrollen, Zeilenbreite, UTF-8-Kürzung |
| `test_slotview.lua` | Slot-Ansicht, Crafter-Brücke |
| `test_lang.lua` | Sprachumschaltung, Statfeld, Dankesfenster |
| `test_rename.lua` | Ladereihenfolge, Migration von OctoLootline |
| `test_build.py` | Konverter: Equip-Effekte, Bedingungen, Setbonus |

**Arbeitsweise:** Jede Änderung gegen einen Test prüfen, bevor sie ausgeliefert wird. Findet ein Test einen Fehler, erst klären, ob Addon oder Stub falsch liegt.

---

## Release

1. Version in `BananaLootline.toc` (`## Version:`) und `Core.lua` (`BLL.VERSION`) anheben.
2. Eintrag in `CHANGELOG.md`.
3. Commit, dann Tag setzen und pushen:
   ```bash
   git tag v0.18.0
   git push origin v0.18.0
   ```
4. Der Release-Workflow führt die Tests aus, prüft Tag gegen .toc-Version und hängt `BananaLootline-0.18.0.zip` an das Release. Das ZIP enthält den Ordner `BananaLootline` ohne `tools/`, `docs/` und `.github/`.

---

## Schnittstelle zu BananaRepublik Partnerguild

Ab Partnerguild 2.1.0 existiert `BRPP_API`:

```lua
BRPP_API.GetCrafters(rezeptname)  -- gesamt, online, davon Partnergilde
BRPP_API.ShowRecipe(rezeptname)   -- öffnet Fenster + Rezept, true bei Treffer
```

BananaLootline prüft nur, ob `BRPP_API` existiert und `ShowRecipe` eine Funktion ist. Die Zuordnung läuft über den Rezeptnamen ohne Gross-/Kleinschreibung und Satzzeichen. Verzauberungen haben in der Partner-DB keine ID.

---

## Offene Punkte

**Bewertung**
- Gewichte für die übrigen acht Klassen mit Quelle belegen
- Gewichte an die Charakterstufe anpassen statt fester Stufe-60-Werte
- Angriffskraft in Druidengestalt als eigener Schlüssel für Wildheit
- Dropchance über mehrere Mobs derselben Zone zusammenfassen

**Daten**
- Ringe und Umhänge unvollständig (Listen bei 500 gekappt)
- Zauberlisten bei 300 gekappt, eventuell fehlen Verzauberungen
- Rund 170 Waffen ohne Schadensbereich
- Use-Effekte ohne Abklingzeit aus der Datenbank

**Funktionen**
- Wunschliste (`BananaLootlineChar.wishlist` angelegt, ungenutzt)
- BiS- und Pre-Raid-BiS-Listen
- Chatmeldungen der Slash-Befehle folgen noch nicht dem Sprachumschalter
- Partner-Addon: Spell-ID beim Scan speichern, damit die Crafter-Zuordnung sprachunabhängig wird

**Aufräumen**
- Migrationscode für OctoLootline-Einstellungen entfernen, sobald alle umgestellt haben

**Im Spiel noch zu bestätigen**
- Scrollleiste und Mausrad, Textkürzung über die unsichtbare Messschrift
- Auswahlmenü der Statkästen
- Klick von der Verzauberung ins Partner-Addon
- Position der Figur bei anderen Völkern
