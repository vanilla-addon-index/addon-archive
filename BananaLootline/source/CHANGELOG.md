# Changelog

Alle nennenswerten Änderungen an BananaLootline. Neueste Version oben.

## 0.24.4

- **Tierausbilder ist kein Klassenlehrer mehr.** Tierausbilder und Waffenmeister öffnen dasselbe Lehrerfenster wie der Klassenlehrer. Ein Jäger sah deshalb im Extras-Menü unter „Klassenlehrer" Knurren, Große Ausdauer und Widerstände. Jetzt prüft das Addon den Titel des NPCs („<Hunter Trainer>" / „<Jägerlehrer>") und merkt sich nur den Lehrer der eigenen Klasse.
  - Eine schon gespeicherte Tierausbilder-Liste wird beim Einloggen entfernt; beim nächsten Besuch des Klassenlehrers ist die richtige Liste da.
  - Ein Beruf, dessen Name sich nicht lesen ließ, stand bisher als „?" im Menü. Er heißt jetzt wie der Lehrertitel oder wird gar nicht gespeichert; der alte „?"-Eintrag wird entfernt.
- `tools/test_pettrainer.lua` prüft Jäger-, Tier- und Waffenlehrer, deutsche Titel und das Aufräumen.

## 0.24.3

- **Nur noch die eigene Rüstungsart.** Vorgeschlagen wird die schwerste Rüstungsart, die die Klasse tragen kann: Jäger Leder, ab 40 Kette; Schamane Leder, ab 40 Kette (plus Schilde); Krieger und Paladin Kette, ab 40 Platte (plus Schilde); Schurke und Druide Leder; Stoffklassen Stoff. Bisher kam alles, was die Klasse tragen *darf* — ein BM-Jäger auf Stufe 38 bekam die „Stormreaver Robe" (Stoff, Ausdauer, Intelligenz) als Brust-Upgrade, weil Rüstungspunkte zu schwach zählen, um den Abstand zu Leder auszugleichen.
  - Umhänge (im Spiel als Stoff geführt) sind davon ausgenommen.
  - Im Quellen-Menü schaltet „+ Leichtere Rüstung" die alte Auswahl wieder ein, pro Charakter gespeichert.
- `tools/test_armorpref.lua` prüft Jäger vor und ab 40, Umhänge, den Schalter und eine Stoffklasse.

## 0.24.2

- **Suche funktioniert ohne pfQuest.** Wer nur Questie (z. B. Questie-Octo) und kein pfQuest installiert hat, bekam immer „nichts Besseres gefunden": die Suche erwartete im ersten Schritt die pfQuest-Datenbank und blieb ohne sie stehen — Pool 0, ohne Fehlermeldung. Jetzt geht sie direkt zu den eingebauten Fundorten über. Gefunden dank der Suchdiagnose aus 0.24.1 (ein Tester auf Stufe 45: „pfQuest: 0 of 0", „Import: 2227 items in the search range").
- **Ehrliche pfQuest-Anzeige.** Beim Laden und in `/bll selftest` stand „pfQuest OK", sobald die eingebauten Fundorte da waren — auch ohne pfQuest. Jetzt heißt es „pfQuest nicht installiert (optional, die eingebauten Fundorte werden genutzt)".
- `tools/test_nopfquest.lua` spielt die ganze Suche ohne pfQuest mit den echten Daten durch (Stufe-45-Paladin).

## 0.24.1

- **Die Suche stirbt nicht mehr still.** Jeder Suchschritt läuft geschützt. Tritt ein Fehler auf, hält die Suche an, schreibt den Schritt und die Fehlermeldung rot in den Chat, und das Fenster zeigt „Suche fehlgeschlagen – siehe Chat“ statt „nichts Besseres gefunden“. Anlass: ein Tester auf Stufe 45 bekam Pool 0 ohne jede Fehlermeldung — vermutlich schluckte ein Fehler-Addon das Lua-Popup.
- **`/bll selftest` mit Suchdiagnose.** Neu sind die Zeilen:
  - wie viele pfQuest-Items im Suchbereich liegen (von wie vielen insgesamt),
  - wie viele Import-Items im Suchbereich liegen,
  - der Suchstatus, mit Warnung, wenn eine Suche seit über 5 Sekunden keinen Fortschritt macht,
  - der letzte Suchfehler,
  - eine Warnung, wenn die letzte Suche nichts gesammelt hat, obwohl Items im Bereich liegen.
- `tools/test_searchfail.lua` prüft Fehlerfang, Hängen und Diagnose.

## 0.24.0

- **Seitenmenü „Statgewichte" links am Hauptfenster.** Eine Lasche mit Pfeil im linken Zwischenrand neben den Slots klappt es auf. Alle Gewichte lassen sich direkt bearbeiten, gruppiert nach Attribute, Physisch, Zauber, Verteidigung und Widerstände; das Mausrad scrollt.
  - Die Werte sind die internen Gewichte des Addons, ohne Umrechnung.
  - Werte, die von der Spec abweichen, sind orange, der Spec-Wert steht in Klammern daneben.
  - „Vorlage" lädt die Werte eines anderen Talentbaums der Klasse in die Felder; gespeichert wird erst mit „Übernehmen". „Spec-Werte" setzt zurück.
  - Sind die Werte gleich der Spec, wird nichts gespeichert, die Spec-Gewichte gelten weiter.
- **Eigene Gewichte gelten jetzt pro Charakter** (auch `/bll weight`). Bisher lagen sie für den ganzen Account; vorhandene eigene Gewichte übernimmt der erste Charakter, der eingeloggt wird.
- `tools/test_weightsui.lua` prüft Speichern, Vorlagen, Zurücksetzen und die Übernahme alter Gewichte.

## 0.23.4

- **Tooltips im Extras-Menü.** Mit der Maus über einem Zauber oder Rezept erscheint, was er macht: Name und Rang, nötige Stufe bzw. Fertigkeit, Preis und die Beschreibung des Lehrers. Die Beschreibung liest das Addon beim Lehrerbesuch mit — dieselbe, die das Lehrerfenster unten zeigt; bei Rezepten ohne eigene Beschreibung den Tooltip des Eintrags. Für Listen von früheren Besuchen fehlt sie, bis man den Lehrer erneut öffnet; der Tooltip sagt das.

## 0.23.3

- **Extras: beim Klassenlehrer nur die nächsten fünf Lehrerstufen.** 0.23.2 zeigte alle Stufen bis 60, bei Stufe 17 waren das 22 Kopfzeilen. Jetzt sind es höchstens fünf, bei Stufe 17 also Level 18 bis 26. Berufe sind unverändert.

## 0.23.2

- **Seitenmenü „Extras": alles aufklappbar.** Beim Klassenlehrer ist „Jetzt lernbar" und jede einzelne Stufe eine Kopfzeile mit [+]/[−], rechts die Zahl der Zauber; bei den Berufslehrern jeder Beruf, rechts grün „N lernbar", falls es etwas zu lernen gibt. Ein Klick auf die Zeile klappt auf oder zu, der Zustand bleibt gespeichert.
  - Voreinstellung: „Jetzt lernbar" ist offen, Stufen und Berufe sind zu.
  - Weil zugeklappte Abschnitte kaum Platz brauchen, zeigt das Menü jetzt alle kommenden Stufen statt nur drei und alle kommenden Rezepte statt nur fünf. Reicht der Platz trotzdem nicht, scrollt das Mausrad.
- `tools/test_trainer.lua` prüft Auf- und Zuklappen.

## 0.23.1

- **Die Lasche zum Seitenmenü sitzt im Zwischenrand** zwischen rechter Liste und Fensterkante, senkrecht mittig zur Liste; der Pfeil steht mittig in der Lasche, die Zahl lernbarer Einträge darüber. Das Seitenmenü schliesst direkt an die Fensterkante an.
- **Lange Meldungen in der Kopfzeile laufen nicht mehr unter den Quellen-Knopf.** „Noch kein Weg. Unten auf …" bricht jetzt vor dem Knopf um.

## 0.23.0

- **Neu: Seitenmenü „Extras" mit Erinnerung an Klassen- und Berufslehrer.** Am rechten Rand des Fensters sitzt eine Lasche mit Pfeil; ein Klick klappt daneben das Menü auf. Die Zahl auf der Lasche sagt, wie viel gerade lernbar ist.
  - **Klassenlehrer:** was jetzt lernbar ist, mit Gesamtpreis, darunter die nächsten drei Stufen mit ihren Zaubern und Rängen, und wann und wo man zuletzt beim Lehrer war.
  - **Berufslehrer:** je Beruf die aktuelle Fertigkeit, was jetzt lernbar ist, und die nächsten Rezepte mit der nötigen Fertigkeit.
  - **Meldung beim Stufenaufstieg** im Chat und mitten auf dem Bildschirm, z. B. „Neu beim Klassenlehrer: 3 Zauber, 47s." Ebenso, wenn eine Berufsfertigkeit die Schwelle für neue Rezepte erreicht. Gemeldet wird nur, was neu dazugekommen ist.
  - **Woher die Daten kommen:** vom Lehrer selbst. Beim Öffnen des Lehrerfensters liest das Addon die ganze Liste — auch was noch nicht lernbar ist, mit Stufe, Fertigkeit und Preis — und merkt sie sich pro Charakter. Die Angaben stammen damit von diesem Server, auch für eigene Zauber. Dafür blendet es kurz „nicht verfügbar" im Lehrerfenster ein und stellt den Filter danach zurück.
  - Einmal muss man beim jeweiligen Lehrer gewesen sein. Bis dahin meldet das Addon auf geraden Stufen, dass es beim Klassenlehrer vermutlich Neues gibt.
- Neuer Test `tools/test_trainer.lua` mit nachgebautem Lehrerfenster.

## 0.22.19

- **„Pro Item": der Quellen-Knopf liegt nicht mehr unter der Zeile „Angelegt".** Die Ansicht beginnt 26 Pixel tiefer, der Knopf sitzt darüber und eine Ebene höher.

## 0.22.18

- **Neu: Quellen-Dropdown oben rechts in Lootline und „Pro Item".** Vorschlag eines Testers. Mehrfachauswahl aus Dungeon, Raid, Quest, Welt, Schlachtfeld, Weltboss, Händler und — nur in „Pro Item" — Ohne Fundort. Das Menü bleibt beim Klicken offen, jeder Haken zeichnet die Liste sofort neu; die Auswahl gilt für beide Ansichten und bleibt gespeichert. Der Knopf zeigt den Stand: „Quellen: Alle", „Quellen: Dungeon, Quest", „Quellen: 3 von 6", dazu „+Händler" bzw. „+Ohne Fundort".
  - Jede Quelle zählt genau zu einer Kategorie: eine Questbelohnung ist Quest, auch wenn die Quest in den Todesminen spielt; Händlerware ist Händler; alles andere zählt nach seinem Ort. Wer Quest abwählt, verliert die Todesminen-Questbelohnung, nicht die Drops dort.
  - Ein Teil bleibt sichtbar, solange eine seiner Quellen erlaubt ist. Im Wegplan steht es dann unter dieser Quelle.
  - Voreinstellung wie bisher: alles außer Händler und Ohne Fundort. Die Haken „Händler zeigen" und „Nur mit Fundort" gehen im Dropdown auf; wer sie gesetzt hatte, findet die Einstellung übernommen.
  - Neu ist, dass Händlerware ohne Haken auch in „Pro Item" fehlt; bisher erschien sie dort immer.
- **Questzeile: „Questlevel 15" statt „Quest 15", „(1 von 2)" statt „(Wahl aus 2)".** Die Zahl ist wie bisher die Stufe, ab der man die Quest annehmen kann.
- **Unten neben − / + steht jetzt klein, was die Pfeile tun:** „Levelrange erhöhen" und darunter „jetzt: bis Stufe 16" (eigene Stufe plus eingestellter Wert). Das Wort „Voraus" entfällt.
- **Export-Knopf und Export-Funktion entfernt.** Der Exportstring war für einen Websync gedacht, den es nicht gibt.
- `tools/test_lootline.lua` prüft den Quellenfilter: Kategorien je Quelle, Filter Dungeon und Quest, „Pro Item" mit und ohne Fundort, Übernahme der alten Haken.

## 0.22.17

Aus der zweiten Runde eines Testers (Schurke 60, noch mit 0.22.11).

- **Teile, deren Quellen alle in gesperrten Phasen liegen, fallen ganz heraus.** Die Phasensperre entfernte bisher nur die Quellen; das Teil blieb in „Pro Item" stehen, mit „No source data". Der Tester bekam so fast nur Drake Fang Talisman (BWL), Shieldrender Talisman (Rock of Desolation), Jom Gabbar (AQ40), Slayer's Crest und Bonescythe Gauntlets (Naxxramas). Jetzt gilt: hat jede Quelle einen Ort und ist jeder Ort gesperrt, kommt das Teil in keine Liste. 809 Teile sind davon betroffen. Wird die Phase geöffnet (Termin oder `/bll phase <n> on`), sind sie wieder da. Hergestellte Teile und Teile mit einer Quelle ohne Ort bleiben.
- **„Pro Item" zeigt standardmässig nur Teile mit Fundort.** Neuer Haken „Nur mit Fundort" oben rechts, an derselben Stelle wie „Händler zeigen" im Wegplan. Ohne Haken erscheinen wie bisher auch Teile ohne erreichbare Quelle — Altlasten der Datenbank, etwa ungenutzte Doppelversionen von Klassenteilen, die der Tester ansprach.
- **Neu: `/bll ilvl 60-80`.** Vorschlag des Testers: begrenzt die Vorschläge auf einen Itemlevel-Bereich. `/bll ilvl 60` setzt nur die Untergrenze, `/bll ilvl off` hebt den Filter auf, `/bll ilvl` allein zeigt den Stand. Teile ohne Itemlevel im Import bleiben drin.
- **Spezialisierung bei eigenen Gewichten.** Wer mit `/bll weight` eigene Gewichte gesetzt hat, sah „no spec detected", und die Wahl im Menü änderte sichtbar nichts: `Weights:Get()` kehrte bei eigenen Gewichten sofort zurück, bevor die Spezialisierung bestimmt war. Jetzt wird sie immer bestimmt und angezeigt; die Unterzeile sagt zusätzlich „(custom weights)", und eine Spec-Wahl weist darauf hin, dass die eigenen Gewichte vorgehen und `/bll weight reset` sie aufhebt. Vermutete Ursache der Meldung, nicht bestätigt.
- Neue Tests `tools/test_lockedsources.lua` und `tools/test_ilvlfilter.lua`; `tools/test_specchoice.lua` prüft eigene Gewichte.

## 0.22.16

Aus den Rückmeldungen von drei Testern (Schurke 60, Druide 43, Schutzpaladin 57). Alle drei hatten noch ältere Fassungen; was dort gemeldet war und seitdem behoben ist, steht unten am Ende.

- **Absturz `UI.lua: attempt to index local 'qc' (a nil value)` behoben.** Von allen drei Testern gemeldet, beim Schurken an Waffenhand und Schildhand. Der Datenbestand führt acht Teile mit Qualität 6 (Artefakt): die Klingen von Azzinoth und fünf Schmuckstücke ab Stufe 51. Die Farbtabelle kannte nur 0 bis 5; sobald eines davon in einer Liste stand, brach das Zeichnen ab und die Liste blieb leer. Jetzt gibt es Farben für 6 und 7 und einen Rückfall für jede andere Zahl.
- **Setboni machen ein Teil nicht mehr „unvollständig bewertbar".** Zeilen wie „Set: Reduces the cooldown of your Vanish ability by 30 sec." oder „(5) Set: … restore 35 energy" passten auf kein Muster und galten als unbezifferter Effekt; dann musste jedes Upgrade das angelegte Teil deutlich schlagen. Gleichzeitig zählte ein Setbonus wie „Set: Improves your chance to hit by 2%" bisher doppelt — einmal aus dem Tooltip, einmal über die Setdaten. Setzeilen werden beim Tooltip-Lesen jetzt übersprungen; Setboni bewertet allein SetDB nach der Zahl getragener Teile. Vorschlag des Testers, umgesetzt.
- **Klassenquests anderer Klassen fallen heraus.** Der Import kennt die Klasse einer Quest nicht, pfQuest schon. `Data/QuestData.lua` führt sie jetzt (632 Klassenquests), und eine Questbelohnung zählt nur, wenn die eigene Klasse die Quest annehmen darf. Beispiel: die Darkmantle-Teile aus „An Earnest Proposition" erscheinen beim Schurken, beim Jäger nicht mehr.
- **Rufvoraussetzungen werden gelesen.** Der Import führt sie seit Langem bei 411 Teilen („Argent Dawn - Honored"), das Addon nutzte sie nie — nur der Tooltip-Scan erwischte sie, und der läuft nur bei Teilen, die der Client schon kennt. Jetzt liest das Addon bei jeder Suche die Rufliste des Charakters; ein Teil, dessen Ruf man noch nicht hat, gilt als gesperrt wie ein Teil mit PvP-Rang. `/bll locked` zeigt es trotzdem. Eine Fraktion, die in der Rufliste nicht steht (eingeklappte Gruppe), gilt als nicht erreicht. **Im deutschen Client** heissen die Fraktionen anders als im Import; dort gelten Rufteile deshalb vorerst immer als gesperrt.
- **PvP-Ränge:** Der Export enthält keine Rangangabe. Es bleibt bei der Erkennung über den Tooltip („Requires Knight-Lieutenant"), die greift, sobald der Client das Teil kennt.
- **Letzte deutsche Texte in englischer Anzeige übersetzt:** Selbsttest („Zonen", „fehlt - Fundorte kommen aus pfQuest"), „NEU" in der Lootline, „Benötigt Stufe" im Ersatz-Tooltip. Die Spec-Namen sind seit 0.22.7 englisch.
- Neue Tests `tools/test_setlines.lua` und `tools/test_reputation_req.lua`; `tools/test_questinfo.lua` prüft die Klassenquests.

**Aus den Rückmeldungen, mit älteren Fassungen gemeldet und inzwischen behoben:** Inhalte noch nicht offener Phasen (Naxxramas, Ahn'Qiraj, Turm von Karazhan, Rock of Desolation) seit 0.22.6; Selbsttest mit falscher Version seit 0.22.6; Vorausplanung 3 bzw. 6 statt 0 seit 0.22.9.

**Offen:** Druide 43 meldete, die Suche finde nichts und `/bll stop` sage „läuft nichts". In der Nachstellung mit 0.22.16 findet die Suche für einen Druiden 43 Zul'Farrak, Stormwrought Ruins und weitere Orte. Wahrscheinlich war es derselbe Zeichenabsturz; bestätigt ist es nicht.

## 0.22.15

- **Das Questfenster öffnet links neben dem Hauptfenster und liegt davor.** Es lag auf derselben Ebene wie das Hauptfenster und erschien dahinter. Jetzt eine Ebene höher, oben bündig links daneben; reicht der Platz links nicht, rechts daneben. Ist das Hauptfenster zu, in der Bildmitte.

## 0.22.14

- **Klick auf eine Questbelohnung zeigt die ganze Questreihe.** In der Lootline und unter „Pro Item" öffnet ein Klick auf ein Teil mit „Quest" ein Fenster: alle Vorquests in der richtigen Reihenfolge bis zur Quest mit der Belohnung, je Schritt mit Name, Mindeststufe (orange, solange man sie nicht hat), Questlevel, Questgeber mit Zone und Koordinaten, Abgabe-NPC, falls ein anderer, und dem Questziel. Bei einer Auswahlbelohnung stehen darunter alle Teile, zwischen denen man wählt, das angeklickte grün markiert. Mit pfQuest zeigt „Auf Karte zeigen" den Anfang der Reihe auf der Karte.
- Beispiele: Tunic of Westfall gehört zu einer 7-teiligen Reihe „The Defias Brotherhood", die bei Gryan Stoutmantle in Westfall (56, 48) anfängt und über Wiley the Black im Rotkammgebirge und Mathias Shaw in Sturmwind führt. Tinkering Belt aus „The Harvest Golem Mystery" ist der neunte Schritt einer OctoWoW-eigenen Reihe bei Christopher Hewen in Sentinel Hill.
- Bei mehreren möglichen Vorquests gilt die, die die eigene Rasse annehmen darf; gibt es dann noch eine, steht ein Hinweis dabei.
- **Neu: `Data/QuestData.lua`**, erzeugt von `tools/quest_import.lua` aus pfQuest, pfQuest-turtle und pfQuest-octo: 3321 Quests (alle, die Gegenstände belohnen, plus ihre Vorquests) mit Geber, Abgabe, Stufen und Ziel, dazu 1283 NPCs mit Ort. 590 KB. Funktioniert auch ohne pfQuest im Client; fehlt eine Quest dort, gilt, was der Import weiss.
- Shift-Klick hängt weiterhin den Itemlink in den Chat, jetzt auch in der Lootline.
- Neuer Test `tools/test_questinfo.lua` an den echten Daten.

## 0.22.13

Aus dem Spieltest von 0.22.11: Frostmane Hollow stand jetzt im Wegplan, aber weit hinten — auf turtlelootline.com ganz oben.

- **Die Dropchance dämpft jetzt, statt zu multiplizieren.** Bisher zählte ein Teil mit Zuwachs mal Chance; ein Bossdrop mit 33 % zählte damit nur ein Drittel, eine Questbelohnung voll. turtlelootline.com lässt die Chance ganz weg — ihre Priorität ist die Summe der prozentualen Verbesserungen, und ein 2-%-Drop zählt dort wie ein sicherer. Jetzt gilt die Wurzel der Chance: 33 % zählt 0,58, 20 % zählt 0,45, 2 % noch 0,14, 0,1 % nur 0,03. Brauchbare Bossdrops rücken nach vorn, Seltenes bleibt hinten.
- **Jäger: die Nahkampfwaffe zählt kaum noch.** Waffen-DPS hatte an Nah- und Fernkampfwaffe dasselbe Gewicht. Rockslicer (Zweihandaxt, 18,2 DPS gegen 2,5 beim Dolch) brachte so rund 47 Punkte und zog die Todesminen über jeden Ort mit Rüstungsupgrades. Geschossen wird mit dem Bogen; an der Nahkampfhand zählt DPS beim Jäger jetzt mit 0,5 statt 3,0. Andere Klassen sind unverändert.
- Nachgestellt mit der Ausrüstung aus dem Bildschirmfoto: Frostmane Hollow steigt von 7,6 auf 13,2 Punkte und von Platz 5 auf Platz 4, vor die Questgruppe. Davor bleiben die Todesminen (sichere Questbelohnungen: Piercing Axe, Tinkering Belt), die Höhlen des Wehklagens und das Rotkammgebirge.
- `tools/test_questchoice.lua` rechnet mit der Wurzel; neuer Test `tools/test_meleedps.lua`.

## 0.22.12

- **Minimap-Knopf mit dem BananaLootline-Logo.** Klick öffnet und schliesst das Fenster, Ziehen verschiebt den Knopf um die Karte; die Position bleibt gespeichert. `/bll minimap` blendet ihn aus und wieder ein. Das Bild liegt als `Images/Minimap.tga` bei, 64 × 64 Pixel mit transparentem Rand. Damit ist der offene Punkt „Es gibt kein Minimap-Symbol" aus 0.22.6 erledigt.
- Neuer Test `tools/test_minimap.lua`.

## 0.22.11

Die Diagnose aus 0.22.10 hat den Fehler gefunden. `/bll why 116` meldete für Belt of Binding: im Pool, tragbar, 13,4 Punkte gegen 1,4 beim angelegten Gürtel, Quelle Hailar the Frigid in Frostmane Hollow mit 33 %. Alles richtig — und trotzdem stand es in keiner Liste.

- **Teile, deren Quelle nur der Import kennt, werden nicht mehr nach hinten sortiert.** Die Liste stellt Teile mit Fundort vor Teile ohne. Ob ein Teil einen Fundort hat, wurde aber nur an pfQuest gemessen. pfQuest kennt Belt of Binding nicht — also galt es als „ohne Fundort" und landete hinter allen Teilen, die pfQuest kennt, obwohl der Import seine Quelle seit 0.22.7 führt. Bei sechs Plätzen in „Pro Item" und drei je Platz im Wegplan kam es damit nie vor. Jetzt zählt auch der Import als Fundort.
- Die Nachstellung hatte das nicht gezeigt, weil sie ohne pfQuest lief: dort kamen alle Teile aus dem Import, und die Sortierung benachteiligte keines. Die beiden Korrekturen aus 0.22.8 und 0.22.9 waren trotzdem nötig, aber nicht die Ursache.
- Neuer Test `tools/test_importrank.lua` mit einem Teil, das pfQuest kennt, einem, das nur der Import kennt, und einem ohne jede Quelle.

## 0.22.10

Belt of Binding fehlt im Spiel weiter, obwohl die Nachstellung mit denselben Daten es mit +12 oben zeigt. Der Unterschied liegt in etwas, das nur im Spiel existiert — gespeicherter Itemcache, AtlasLoot oder pfQuest im Client.

- **Neu: `/bll why <itemID>`.** Zeigt für ein Teil, woran es hängt: Eintrag in der Itemdatenbank, ob es im Suchpool liegt und mit welchem Stufenband, den gespeicherten Cache-Eintrag samt Sperrvermerk, ob AtlasLoot eine Ruf- oder Rangbedingung meldet, ob es als tragbar gilt, seine Punktzahl gegen das angelegte Teil und die erste Quelle.

## 0.22.9

Aus dem zweiten Spieltest: Belt of Binding fehlte weiter, auch in „Pro Item", wo es mit +12 vor Belt of the Fang (+10) hätte stehen müssen.

- **Veraltete „Server liefert nichts"-Markierungen fallen weg.** Eine frühere Fassung hatte Belt of Binding beim Server angefragt, keine Antwort bekommen und es im gespeicherten Itemcache dauerhaft als nicht abrufbar markiert. Diese Markierung überlebte jedes Update, und das Teil erschien in keiner Liste mehr — obwohl der Import längst alle Werte führt und gar keine Anfrage nötig ist. Jetzt gilt die Markierung nur noch für Teile ohne Importwerte. Nachgestellt an den echten Daten: mit der alten Markierung ergibt sich genau die Gürtelliste aus dem Bildschirmfoto, ohne sie steht Belt of Binding mit +12 oben.
- **Vorausplanung steht jetzt auf 0.** Die Suche zeigt damit nur, was man sofort anlegen kann, wie turtlelootline.com. Wer früher selbst einen Wert eingestellt hat, behält ihn; − und + daneben ändern ihn wie bisher.
- **Version und „© Lumihunt" rechts unten im Fenster.**
- `tools/test_preload.lua` prüft beide Fälle der Markierung.

**Tribal War Gauntlets bleibt absichtlich draussen.** Es ist Kette, und Jäger tragen Kette erst ab Stufe 40. turtlelootline.com schlägt es einem Stufe-15-Jäger trotzdem vor.

## 0.22.8

Aus dem ersten Spieltest von 0.22.7: Belt of Binding hatte jetzt seinen Ort, Frostmane Hollow stand trotzdem nicht im Wegplan.

- **Der Wegplan sucht je Platz die besten Teile mit Ort, nicht die besten Teile.** Bisher kamen je Rüstungsplatz die drei besten Verbesserungen herein, und erst danach flogen die ohne Ort hinaus. Beim Gürtel eines Stufe-16-Jägers lagen vorn Deviate Scale Belt (hergestellt), Dark Leather Belt und Mosshide Cinch (beide ohne Fundort) — Belt of Binding mit 33 % in Frostmane Hollow kam nie in Betracht, und der Gürtel trug zum Wegplan gar nichts bei. Jetzt rücken die nächstbesten nach, bis drei Teile mit Ort gefunden sind; angesehen werden höchstens 40 je Platz.
- Die Einzelansicht „Pro Item" bleibt unverändert nach Zuwachs sortiert, mit oder ohne Ort.
- `tools/test_lootline.lua` stellt den Fall nach: drei bessere Teile ohne Ort, ein schwächeres in Frostmane Hollow.

## 0.22.7

Aus dem Vergleich mit turtlelootline.com: dort wählt man die Spezialisierung selbst, im Addon stand für einen Stufe-15-Jäger „keine Spez. erkannt".

- **Die Spezialisierung lässt sich jetzt von Hand wählen.** Ein Klick auf die Unterzeile im Fenster (Name, Stufe, Klasse) öffnet ein Menü mit „Automatisch" und den drei Talentbäumen. Automatisch bleibt die Voreinstellung und liest wie bisher die Talente ab 10 Punkten. Die eigene Wahl schlägt die Erkennung, steht als „(manuell)" in der Unterzeile und liegt pro Charakter in den SavedVariables. Nach der Wahl läuft die Suche sofort neu, weil sich mit den Gewichten die Rangfolge ändert.
- **Neu: `/bll spec <1-3|Name|auto>`.** Dasselbe im Chat. Der Name darf abgekürzt und deutsch oder englisch sein, `/bll spec tier` und `/bll spec beast` wählen beide Tierherrschaft. `/bll spec` allein zeigt wie bisher die Talentverteilung und zusätzlich eine eigene Wahl.
- **Spezialisierungen heissen in der englischen Anzeige jetzt englisch** („Beast Mastery" statt „Tierherrschaft").
- Neuer Test `tools/test_specchoice.lua`.

- **Gegner, die pfQuest nicht kennt, bekommen trotzdem einen Ort.** Belt of Binding und Tribal War Gauntlets fallen zu je 33 % von Hailar the Frigid und Battlemaster Ubukaz — turtlelootline.com setzt dafür Frostmane Hollow an die Spitze des Wegplans. Im Addon fehlten beide, weil der Ort eines Gegners bisher nur aus pfQuest kam, und dort stehen diese OctoWoW-eigenen Gegner nicht. Dasselbe traf viele Instanzbosse, die pfQuest ohne Koordinaten führt. 1737 Teile hatten Quellen, aber keine davon mit Ort.
- **Die Ortsnummer des Exports wird jetzt geeicht statt verworfen.** Sie ist allein nicht zu deuten, weil sie Gebiets- und Kartennummern mischt. Aber alle Gegner mit derselben Nummer, die pfQuest kennt, stimmen ab: unter 229 stehen 70 von 73 in Blackrock Spire, unter 209 alle 26 in Zul'Farrak. Zugeordnet wird ab drei Stimmen und 80 % Mehrheit; 62 Nummern sind so eindeutig, 8 bleiben offen. Nummern, unter denen pfQuest keinen Gegner kennt, sind Gebiete dieses Servers und behalten ihre eigene Nummer — 822 heisst Frostmane Hollow (Name laut turtlelootline.com), 820 The Golden Plains.
- **Instanzbosse ohne Ortsnummer stehen in einer Tabelle.** Ragnaros, Nefarian, Gandling, der Avatar von Hakkar, die Arena in Blackrock Depths, die Bosse in Stratholme und Blackrock Spire, der Abyssische Rat in Silithus und weitere — 47 Gegner, deren Ort eine Sachangabe zum Spiel ist.
- Teile mit Quelle, aber ohne Ort: **1737 → 1288**. Davon sind 1017 reine Herstellung, die keinen Ort braucht. Teile, die nur von Gegnern fallen und keinen Ort haben: **359 → 90**. Bereits vorhandene Orte haben sich nicht verändert.
- Der Import läuft mit den öffentlichen pfQuest-Paketen von GitHub (pfQuest, pfQuest-turtle, pfQuest-octo) und ergibt ohne diese Änderung byte-genau den bisherigen Datenstand.
- Neuer Test `tools/test_locvote.py`; `tools/test_screenshot.lua` prüft Frostmane Hollow. 31 Testdateien, alle grün.

Beim Jäger ändert die Wahl an den Gewichten noch nichts: die drei Talentbäume nutzen bisher dieselben Klassenwerte, weil die Quelle sie nicht unterscheidet.

## 0.22.6

Aus der Rückmeldung eines Testers, die mit einem Vergleichsbild der Seite turtlelootline.com kam.

- **Inhalt, den es auf dem Server noch nicht gibt, fällt aus dem Wegplan.** Ein Stufe-57-Paladin bekam als besten Wegplan Naxxramas, Ahn'Qiraj, den Smaragdgrünen Hain, die Obere Nekropole, den Turm von Karazhan und den Felsen der Verwüstung vorgeschlagen — alle sechs sind auf OctoWoW noch nicht offen. 524 von 2385 Dropzeilen in seinem Kandidatenpool kamen aus Instanzen, die nicht existieren. Das Addon konnte das nicht sehen, weil es Erreichbarkeit nur an der Gegnerstufe gemessen hat, und ein Stufe-63-Boss in Naxxramas sieht genauso aus wie ein Stufe-63-Gegner in Silithus.
- **Neu: `Phases.lua`.** Die sieben Inhaltsphasen mit ihren Freigabeterminen von `octowow.st/roadmap`, jeder Phase ihre Zonen zugeordnet. Eine Zone, deren Phase noch nicht offen ist, liefert keine Quellen. Das Datum entscheidet, die Sperre trägt sich also am Freigabetag selbst aus. Zonen ausserhalb der Liste — 86 der 96 Orte mit Beute — sind unberührt offen.
- **Neu: `/bll phase`.** Zeigt die sieben Phasen mit Termin und Zustand. `/bll phase <Nr> on|off` stellt eine Phase von Hand um, falls der Server von der Roadmap abweicht; `auto` nimmt das zurück. Die eigene Angabe liegt in den SavedVariables und schlägt den Termin.
- **Zwei Zonen sind über ihre Beute zugeordnet, nicht über den Namen.** „The Upper Necropolis" führt *Glyph of Deflection* und *Slayer's Crest* auf Itemlevel 90 — die Naxxramas-Schmuckstücke des Originals, also Phase 6. „The Rock of Desolation" führt Itemlevel 96, höher als alles in Naxxramas, mit Namen wie *Mephistroth's Cunning* — also Phase 7. Beide Zuordnungen sind begründet, nicht belegt; wer es besser weiss, stellt die Phase um.
- **Timbermaw Hold bleibt absichtlich offen.** Phase 5 heisst so, aber die beiden Zonen dieses Namens im Datenbestand führen nur neun Questbelohnungen auf Queststufe 45 und 50 — den Tunnel, der seit Serverstart offen ist. Wer sie sperrt, nimmt einem Stufe-45-Charakter Beute weg, die er holen kann. Die Instanz der Phase 5 steht noch nicht im Datenbestand.
- **Die Version kommt jetzt aus einer Quelle.** Bis 0.22.5 sagte die TOC 0.22.5 und der Selbsttest 0.21.1, weil die Nummer an zwei Stellen stand. `BLL.VERSION` ist weg; die Anmeldezeile und der Selbsttest lesen beide die TOC.
- **Zauberteile führten keinen Heilwert.** In Vanilla steht auf den meisten eine einzige Zeile: „Increases damage **and healing** done by magical spells and effects by up to N." Der Importer trug daraus nur `SPELLPOWER` ein, und damit fehlte 1443 Teilen ihr Heilwert vollständig. Für einen Heiler stand die Rangfolge dadurch auf dem Kopf: ein Teil mit „22 Schaden und Heilung" bekam 22 Punkte, ein Teil mit „22 Heilung" 35 — obwohl das erste dieselbe Heilung gibt und den Zauberschaden obendrein. Jetzt zählt die Zeile für beide Werte. Teile mit Heilwert: 543 vorher, 1985 jetzt.
- **Bei 49 Teilen addieren sich zwei Zeilen.** Das sind die Heilersets der ersten Raidstufe. *Circlet of Prophecy* führt „12 Schaden und Heilung" plus „11 Heilung", also 23 Heilung — im Addon standen 11. *Robes of Transcendence* gewinnen dadurch 48 Punkte für einen Heiligen Paladin.
- **Fehlende Anforderungsstufen werden geschätzt und als Schätzung markiert.** 3362 anlegbare Teile führen im Export keine. Der Abstand zwischen Itemstufe und Anforderungsstufe liegt im Bestand im Median bei genau 5; nach oben begrenzt 60, weil es in Vanilla keine höhere Anforderung gibt. Das neue Feld `reqest=1` hält fest, dass die Zahl geschätzt ist — eine Schätzung, die wie eine Messung aussieht, kann niemand mehr nachprüfen. Damit hat jedes anlegbare Teil eine Anforderungsstufe, und ein harter Filter darauf wirft nichts mehr weg.
- **Neu: `STAT_OVERRIDES` im Importer.** Zwei Teile tragen im Spiel einen Ausdauer-Nachteil, der im Export fehlt — *Cursed Eye of Paleth* mit −3 und *Bleeding Heart Talisman* mit −5. Die Werte stehen im Importer statt in `ItemData.lua`, weil die Datendatei bei jedem Import neu geschrieben wird. Herkunft ist ein Abgleich mit turtlelootline.com, nicht der Export; wer sie im Spiel am Tooltip sieht, kann sie bestätigen.
- Neuer Test `tools/test_spellpower.lua`.
- Neuer Test `tools/test_phases.lua`, der die sechs gemeldeten Orte als gesperrt und Blackrock Depths, Hateforge Quarry, Dire Maul und Scholomance als erreichbar nachweist. 29 Testdateien, alle grün.

### Noch offen

**Molten Core steht für eine Stufe 57 weiter im Wegplan**, mit 237 Epics auf Itemlevel bis 80. Das ist keine Phasensperre — Molten Core ist offen —, sondern die Vorausplanung: bei der Voreinstellung von sechs Stufen reicht die Suche bis Stufe 63 und lässt damit alles mit Anforderungsstufe 60 herein. `/bll ahead 0` nimmt es heraus. Ob die Voreinstellung sinken soll oder ob geplante Teile getrennt von sofort tragbaren stehen sollten, ist noch nicht entschieden.

**Der Absturz bei Qualität 6 ist nicht behoben.** `UI.lua` kennt die Qualitäten 0 bis 5; der Datenbestand führt acht Teile mit Qualität 6, darunter vier Schmuckstücke auf Anforderungsstufe 51. Die trifft jeder Charakter ab Stufe 51, und keine Phasensperre hält sie auf.

**Es gibt kein Minimap-Symbol.** Nicht ein defektes, sondern keines.

**Ein Teil verliert weiter seinen Zauberschaden.** *The Scythe of Elune* führt „Improves your chance to hit and get a critical strike with spells by 2%. Increases damage done by magical spells and effects by up to 40." — zwei Sätze in einer Zeile. Die Muster des Importers greifen am Zeilenanfang, also fällt der zweite Satz weg. Das einzige Teil im Bestand mit diesem Aufbau.

## 0.22.5

Aus zwei Testerrückmeldungen im Discord.

- **`/bll info` nennt jetzt die Version.** Ein Tester schrieb „I updated addons early 30/9, idk if u pushed another update in the meantime" — an dem Tag gab es fünf Fassungen. Ohne Versionsangabe lässt sich keine Fehlermeldung einordnen. Die Zeile kommt aus der TOC über `GetAddOnMetadata`, damit sie nicht an zwei Stellen gepflegt werden muss. Dazu die Zahl der geladenen Fundorte, NPC-Namen und Zonen.
- **Die Vorausplanung steht jetzt im Fenster.** Zwei Tester haben unabhängig voneinander danach gesucht; einer schrieb „I could not adjust the search range still". Es gab sie nur als `/bll ahead <n>` im Chat — ein Befehl, den niemand findet, ist keine Einstellung. Jetzt stehen Minus und Plus mit dem Wert rechts neben „Upgrades suchen", mit dem Zweck im Tooltip.
- **Eine Gruppe im Wegplan hiess buchstäblich „???".** Dahinter stecken vier Bosse auf Stufe 63 mit Beute auf Itemlevel 92 bis 96 — die Daten stimmten, nur der Name war pfQuests Platzhalter für unbenannte Zonen. Ursache war die Reihenfolge der Datenpakete: eines führt für Zone 5557 „???", ein anderes den echten Namen **The Rock of Desolation**, und das später gelesene gewann. Der Importer überspringt Platzhalter jetzt, damit sich der echte Name durchsetzt.
- Bleibt eine Zone trotzdem namenlos, zeigt das Addon „Zone 5557" statt sie wegzulassen. An der Nummer sieht man, was zu benennen ist — und die Gegenstände fallen nicht aus dem Wegplan.
- **Neu: `/bll zone <id> <Name>`.** Benennt einen Ort, den weder pfQuest noch der Import kennt. Die Angabe liegt in den SavedVariables und überlebt jedes Datenupdate. `/bll zone <id>` ohne Namen setzt zurück, `/bll zone` allein listet die eigenen Benennungen.
- Neuer Test `tools/test_zonename.lua`. 27 Testdateien, alle grün.

### Nicht behoben

**Frostmane Hollow fehlt im Wegplan.** Ein Tester hat danach gefragt. Die Gegenstände sind da und die Dropchancen stimmen — 20 Gegner mit „Frostmane" im Namen, 93 Dropzeilen —, aber bei 83 davon kennt pfQuest den Standort des Gegners nicht. Ohne Ort keine Gruppe. Unter „Pro Item" erscheinen sie. Das ist derselbe Fall wie die übrigen 521 Zeilen ohne Ort und löst sich erst, wenn der Export den Zonennamen selbst mitliefert.

Ragefire Chasm dagegen **ist** enthalten, mit 32 Gegenständen.

## 0.22.4

- **Symbole aus dem Export.** `GetItemInfo` liefert die Textur nur für Gegenstände, die der Client schon einmal gesehen hat — ausgerechnet die Teile, die man noch nicht hat, standen deshalb als Fragezeichen im Fenster. Der Export führt den Namen der Textur bei 99,4 % der Einträge; 14081 der 14230 anlegbaren Gegenstände haben jetzt ein Symbol. Der Pfad `Interface\Icons\` wird im Addon angehängt, statt ihn 14000 Mal mitzuschreiben. `GetItemInfo` bleibt die erste Wahl, der Import springt nur ein, wenn der Client nichts weiss. `Data/ItemData.lua` wächst dadurch um 320 KB auf 2,6 MB.
- **Der Ort entscheidet vor der Quellenart.** „The Deadmines" stand als `[QUEST]` da, weil die Questbelohnung das gewichtigste Teil der Gruppe war — obwohl drei der vier Teile von Elitegegnern in der Instanz fallen. Die Todesminen sind ein Dungeon, ob man wegen einer Quest oder wegen eines Drops hingeht, und die Stufenangabe 17–24 daneben stammt ohnehin aus derselben Tabelle. Händler und Quests entscheiden nur noch dort, wo der Ort selbst keine Kategorie hat.

## 0.22.3

Aus der Rückfrage, warum eine Allianzquest im Brachland steht. Die Fraktion war richtig, der Ort nicht.

- **Quests verorten sich jetzt selbst.** Der Export führt an jeder Quest ein Feld `category` — die AreaTable-ID ihrer Zone. Anders als der Nummernkreis bei den Gegnern ist dieser eindeutig: 3456 Naxxramas, 3428 Ahn'Qiraj, 1977 Zul'Gurub, 25 Blackrock Mountain. Bisher leitete der Importer den Ort aus dem Standort des Questgebers ab, und das war teils falsch: „Golemslayer Mitts" standen unter Duskwood, weil dort der Geber steht — „The Harvest Golem Mystery" spielt aber in Westfall. „Tunic of Westfall" steht jetzt unter Todesminen statt Westfall: die Kette fängt in Westfall an, endet aber dort, und dahin muss man für das Teil. Quests mit Ort steigen von 87 % auf 96,7 %.
- **Die Fraktionszuordnung ist belegt.** Geprüft an den Startgebieten: im Wald von Elwynn tragen 25 Quests `side 1` und keine `side 2`, in Durotar 30 Quests `side 2` und keine `side 1`, in Mulgore 14 und in Tirisfal 15 jeweils nur `side 2`. Also 1 Allianz, 2 Horde, 3 beide. Von 2646 Quests sind 701 Allianz, 628 Horde, 1292 für beide.
- Das Brachland führt 27 Hordenquests, 19 für beide und **3 für die Allianz**. „Kul Tiran Provisions: Special Goods" ist eine davon — OctoWoW-eigener Inhalt mit Bezug auf Theramore. Der Server sagt Allianz; ob das seine Absicht ist, lässt sich nur im Spiel prüfen.
- Zonen im Datenbestand steigen von 107 auf 137, weil Questzonen wie Naxxramas und Ahn'Qiraj dazukommen.

### Offen

- 25 Quests tragen `side 0` statt 1, 2 oder 3, darunter zwei in Durotar. Sie gelten als „für beide" und können damit bei der falschen Fraktion erscheinen. Das sind 0,9 % aller Quests.
- 42 Questkategorien haben keinen Namen, die meisten davon ID 5642 mit 33 Quests — vermutlich eine OctoWoW-eigene Zone. Diese Quests fallen auf den Standort des Gebers zurück.

## 0.22.2

Aus dem zweiten Bildschirmfoto. Der Wegplan stimmt jetzt inhaltlich; zwei Angaben fehlten noch.

- **Elite, Boss und Selten stehen in der Liste.** „Forest Leather Gloves" und „Forest Leather Bracers" fallen zu je 1,6 % im Brachland — aber von Humar the Pridelord, einem seltenen Elitegegner auf Stufe 23, und zwei weiteren Seltenen. Als blosse Prozentzahl las sich das wie ein gewöhnlicher Drop, und ein Stufe-15-Jäger läuft allein los. Die Kennung steht seit 0.22.0 in den Daten, nur nicht im Wegplan.
- **Die Beschriftung einer Gruppe folgt jetzt ihrem gewichtigsten Teil.** Das Brachland stand als `[QUEST]` da, obwohl zwei seiner drei Teile von Elitegegnern fallen und die Quest das schwächste Teil beisteuert. Die Kategorie wurde beim Anlegen der Gruppe vom ersten eingereihten Teil bestimmt — und welches das ist, entschied die Reihenfolge der Rüstungsplätze, nicht der Inhalt.
- `tools/test_lootline.lua` und `tools/test_screenshot.lua` decken beides ab. 26 Testdateien, alle grün.

### Geprüft und richtig

Die neue Liste stimmt Zeile für Zeile gegen die Serverdaten. Höhlen des Wehklagens mit fünf Teilen zu 25 bis 33 %, das Verlies mit Prison Shank zu 33 %, Westfall mit Quest 166 ab Stufe 14, Duskwood mit „The Harvest Golem Mystery" ab Stufe 15, Allianz. „Deckmaster's Commendation" kommt aus „Kul Tiran Provisions: Special Goods", Stufe 10, Allianz, im Brachland — eine Allianzquest in Hordengebiet, und der Fraktionsfilter hat sie zu Recht durchgelassen. „Stalking Pants" verkauft Wenna Silkbeard im Sumpfland für 78 Silber; die Gruppe heisst jetzt richtig `[VENDOR]`.

## 0.22.1

Aus einem Bildschirmfoto des Wegplans eines Stufe-15-Jägers. Drei der fünf Gruppen waren falsch.

- **Questbelohnungen wurden nie auf die Stufe geprüft.** Ganz oben stand „[QUEST] Östliche Pestländer" mit „Windreaper" aus einer Stufe-57-Quest und „Archlight Talisman" aus einer Stufe-50-Quest — für einen Charakter, der sie nicht einmal annehmen kann. Der Erreichbarkeitsfilter las `entry.level`; Quests tragen ihre Stufe aber in `questLevel` und liefen deshalb ungeprüft durch. 2032 der 2883 Questquellen liegen über Stufe 21. Für Quests gilt kein Zuschlag wie bei Gegnern: einen Gegner über der eigenen Stufe erlegt man in einer Gruppe, eine Quest ohne die geforderte Stufe kann man nicht annehmen. Die Angabe ist die Mindeststufe des Servers, bei 2905 von 2906 Questbelohnungen vorhanden.
- **Weltdrops mit Bruchteilen eines Prozents sind kein Reiseziel mehr.** Unter „[WORLD] Sumpfland" standen „Ranger Bow", „Feet of the Lynx" und „Sentry Cloak", alle drei bei denselben drei Gegnern, alle drei mit 0,0045 % — einer von 22000. Der Wegplan lässt Quellen unter 0,1 % jetzt aus; in der Einzelansicht bleiben sie stehen, denn falsch sind sie nicht, sie taugen nur nicht als Ziel. Die Grenze liegt in einer Lücke der Verteilung: unter 0,1 % liegen 12,5 % aller Gegnerquellen, darüber setzt sie bei 0,25 % wieder dicht ein. Über `BananaLootlineDB.minLootlineChance` verstellbar.
- **Entwicklereinträge fliegen schon beim Import raus.** „Windreaper" und „Archlight Talisman" hingen beide an „[UNUSED] Henria Derth". Der Laufzeitfilter fing sie ab, sie belegten aber einen der drei Plätze und verdrängten echte Quellen. Geprüft wird auf [UNUSED], [DEPRECATED], [OLD], [PH], [TEST], [NYI] und Testmobs.
- Truhen bekommen einen Ort. pfQuests Objekttabelle führt 10507 Objekte mit Koordinaten, im selben Format wie die Gegner. Bei 131 Gegenständen war eine Truhe die einzige verortbare Quelle; die fehlten im Wegplan. Von 11519 Gegenständen mit Quelle haben jetzt 9588 mindestens einen Ort, 83,2 %.
- Neuer Test `tools/test_screenshot.lua`: stellt den Fall aus dem Bildschirmfoto an den echten Daten nach — Stufe-15-Jäger, Allianz, ohne pfQuest — und prüft jede der dreizehn Zeilen. 26 Testdateien, alle grün.

### Was im Bildschirmfoto richtig war

Die Höhlen des Wehklagens mit fünf Teilen zwischen 25 % und 33 %, das Verlies mit „Prison Shank" zu 33 % vom Endgegner, und „Tunic of Westfall" aus Quest 166 mit Mindeststufe 14. Der Händlerfilter und die Fraktionsprüfung haben ebenfalls gegriffen: „Stalking Pants" erschien nur, weil der Haken bei Händlern gesetzt war.

## 0.22.0

**Die Fundorte kommen jetzt vom Server, nicht mehr aus dem Vanilla-Datenstand.** Das war die Einschränkung, die in 0.21.1 offen stehen blieb.

- Neuer Datenstand aus dem vollständigen OctoWoW-Export vom 30.09.2026: 23652 Gegenstände gelesen, 14230 davon anlegbar (vorher 11349), 11519 mit Fundort. Ein einziger Gegenstand ist beim Scrape gescheitert.
- **Die Werte sind strukturiert, nicht mehr aus Tooltips geraten.** Attribute, Widerstände, Rüstung, Waffenschaden und Sockelplatz kommen als Zahlen aus dem Export. Nur die Zweitwerte — Angriffskraft, Trefferwertung, Zaubermacht — stehen weiter als Satz und werden gelesen; dafür gibt es 21 Muster gegen den englischen Wortlaut, und der Scrape ist immer englisch. Die Kodierungsfalle aus 0.20.0 kann es im Import nicht mehr geben.
- **Sondereffekte stehen in den Daten.** 629 Gegenstände sind als `proc` gekennzeichnet: 1 für einen Treffereffekt, 2 für einen Benutzeffekt, 3 für beides. Die Schätzwerte `UNSCORED_FLAT = 12` und `UNSCORED_SHARE = 0.20` aus Punkt 7 waren geraten; jetzt ist es gemessen.
- **Questbelohnungen existieren.** 2664 Gegenstände kommen aus Quests, mit Quest-ID, Titel, Mindeststufe, Fraktion, der Anzahl der Auswahlbelohnungen und dem Questgeber. Über den Geber bekommt die Belohnung einen Ort — ohne den stünde sie ohne Ziel in der Liste; pfQuest kennt den Geber für 87,5 % der gebrauchten Quests. In pfQuest kommt das Feld `["Q"]` in keiner items-Datei vor — der Zweig im Addon war toter Code.
- Jede Quelle bringt die Stufe des Gegners, seine Elitekennung und seine Fraktion mit. Elite und Boss stehen jetzt in der Liste, damit niemand allein zu einem Gegner läuft, den er nicht umbringt. Händler zeigen ihren Preis und die Marke des Quartiermeisters.
- Quellen der Gegenfraktion erscheinen nicht mehr. „Outrider's Bow" gehört Kelm Hargunth, einem Hordenhändler in den Barrens — bei einem Allianzcharakter hatte das Teil nichts in der Lootline zu suchen.
- **„Outrider's Bow" verlangt keinen Ruf.** Der Serverdatensatz führt zu beiden Gegenständen dieses Namens (19558 ab Stufe 60, 20437 ab Stufe 18) keine Rufbedingung, weder im Tooltip noch im Feld `requires`. Die Zeile „Warsong Gulch - Revered" aus 0.21.0 stammt aus AtlasLoot und gilt für diesen Server nicht. Was der Server tatsächlich an Ruf verlangt, steht an 411 Gegenständen.
- 20437 hat kein einziges Attribut, nur Waffenschaden. Dass der Jäger dort nichts Brauchbares sah, war kein Fehler der Bewertung.
- **„Feet of the Lynx" hat jetzt die richtigen Quellen:** drei Gegner auf Stufe 23 und 24 in Dunkelhain und im Sumpfland, die beste mit 0,0045 %, dazu drei Truhen. Der Gegner jenseits von Stufe 60 mit 1,92 %, den pfQuest nennt, existiert nicht.
- Dropchancen werden lesbar angezeigt. Der Median aller Dropzeilen im Bestand liegt bei 0,0085 % — mit `%.1f%%` stand dort überall „0.0%", was aussieht wie „fällt nie". Die Nachkommastellen wachsen jetzt mit der Kleinheit des Werts.
- **Die Zonen-ID des Exports ist nicht benutzbar, und das war der Grund für alles Weitere.** Sie mischt zwei Nummernkreise: Freilandzonen tragen die AreaTable-ID, Instanzen die Map-ID, und beide überschneiden sich. 209 ist als Map-ID Zul'Farrak, als AreaTable Shadowfang Keep; unter 229 stehen Blackhand-Mobs, pfQuest nennt die ID „Olsen's Farthing". Nachgewiesen an den Gegnernamen für über zwanzig IDs. Der Importer bestimmt die Zone deshalb aus pfQuests Koordinaten, dessen Nummernkreis in sich geschlossen ist — alle 113 Koordinatenzonen haben einen Namen — und legt sie fertig ab. Zur Laufzeit wird nichts geraten. 90,3 % der 19312 Quellenzeilen haben damit einen Ort, alle 107 benutzten Zonen einen Namen.
- **Rollenteilung mit pfQuest:** der Export liefert Gegenstände, Werte, Dropchancen, Mobstufen und Quests; pfQuest liefert nur noch die Karte. Kennt der Import einen Gegenstand, gilt seine Angabe — auch wenn der Erreichbarkeitsfilter alles verwirft. Kein Rückfall auf pfQuest: „keine erreichbare Quelle" ist richtig, pfQuests Endgame-Gegner wäre falsch.
- Das Addon läuft jetzt ohne pfQuest. `Data/NpcData.lua` bringt 6942 Namen mit, `Data/ZoneNames.lua` die Zonen. Ohne pfQuest fehlt nur der Kartenpunkt.
- Klassenmasken mit allen Bits (2047 und 32767, einschliesslich der in 1.12 unbenutzten 32 und 512) werden zu -1 normalisiert. 482 Gegenstände waren betroffen.
- `Cand.CACHE_VERSION` auf 6, damit die gespeicherten Werte aus dem alten Datenstand neu berechnet werden.
- `/bll src <id>` zeigt zusätzlich Gegnerstufe, Elitekennung, Händlerpreis und die Marke des Quartiermeisters, und markiert Zeilen, die noch aus pfQuest stammen. `/bll selftest` meldet, wie viele Fundorte, NPC-Namen und Zonen geladen sind.
- `tools/octo_import.py` neu geschrieben für das JSONL-Format. Läuft in 13 Sekunden über den 736-MB-Export. Die 2,1 Millionen Dropzeilen schrumpfen auf 19312 Quellenzeilen aller Arten, weil je Art die drei besten bleiben — wer ein Teil sucht, braucht nicht alle 473 Gegner.
- Zwei neue Tests: `tools/test_octodata.lua` prüft die erzeugten Daten gegen die Fälle aus den Testerberichten, `tools/test_import_sources.lua` den neuen Weg in Sources.lua einschliesslich Rückfall, Fraktionsfilter und Betrieb ohne pfQuest. 25 Testdateien, alle grün.
- Ein einzelnes Latin-1-Byte in einem Kommentar in Locale.lua entfernt. Es machte die Datei zu ungültigem UTF-8 und war der Grund, warum `file` die Kodierung falsch meldete und ich sie in 0.20.0 zunächst falsch beurteilt habe.

- Hat die beste Quelle keinen Ort, eine schlechtere aber schon, nimmt der Wegplan die schlechtere. Ein Ziel mit halber Chance schlägt eines, zu dem niemand hinfindet; in der Einzelansicht bleibt die Reihenfolge nach Chance. Der Importer stellt zusätzlich sicher, dass unter den behaltenen Quellen eine mit Ort ist. Zusammen holt das 328 Gegenstände in den Wegplan zurück: von 6510 Gegenständen mit Gegnerquelle haben jetzt 5987 einen Ort (92,0 %) statt 5659 (86,9 %).

### Offen

- 2711 anlegbare Gegenstände haben keinen Fundort. Sie bleiben Kandidaten ohne Ort und erscheinen nur in der Einzelansicht.
- 523 Gegenstände haben keinen einzigen Gegner, dessen Standort pfQuest kennt. Sie fehlen im Wegplan und stehen nur in der Einzelansicht. Das ist die letzte Stelle, an der pfQuest überhaupt noch etwas beiträgt. Der Export nennt den Ort als Text neben dem NPC; nimmt der Scrape diesen Text mit statt nur der ID, schliesst sich die Lücke ohne weitere Annahme.
- **Bei `reqlevel` geht nichts verloren.** 10633 Gegenstände haben keine Stufenanforderung, und das ist richtig: von diesen 10633 trägt kein einziger eine Zeile „Requires Level" im Tooltip, und bei allen 12056 mit Anforderung stimmt der Tooltip exakt, null Abweichungen. Tier-3-Teile wie die Dreadnaught-Brustplatte (Itemlevel 92) haben in Vanilla keine Stufenanforderung. Der Rückfall `ilvl - 5` bleibt trotzdem nötig, weil sonst ein Teil mit Itemlevel 65 und ohne Anforderung im Pool eines Stufe-15-Charakters landet.
- Was die Meta-Datei des Exports tatsächlich meldet, ist etwas anderes: die Eimer mit `ilvl = 0` liessen sich für die Klassen Verbrauchbar, Rüstung, Quest und Verschiedenes nicht filtern. Der Export enthält keinen einzigen Gegenstand mit Itemlevel 0, dafür 298 Rüstungsteile ohne Itemlevel-Feld. Offen ist, ob dort Gegenstände ganz fehlen — das lässt sich nur an der Datenbank selbst prüfen.
- 25 anlegbare Gegenstände haben weder Itemlevel noch Stufenanforderung, aber Werte. Für die rechnet der Rückfall `max(0, ilvl - 5)` auf 0, sie stehen damit ab Stufe 1 im Pool. Darunter zwei Epics: „Banner of the Scarlet Crusade" mit +30 Angriffskraft und „Astral Moonstone Band" mit +9 Intelligenz und +9 Willenskraft.
- Herstellbare Gegenstände (1172) tragen die Zauber-ID des Rezepts, werden aber noch nicht als Quelle angezeigt.

## 0.21.1
- Quellen weit über der eigenen Stufe erscheinen nicht mehr im Wegplan. „Feet of the Lynx" ist ab Stufe 19 tragbar; pfQuest führt als beste Quelle einen Gegner jenseits von Stufe 60 mit 1,92 %, und der stand damit bei einem Stufe-15-Jäger ganz oben. 644 der 8364 Quellenpaare im Datenbestand sehen so aus. Die Grenze liegt bei eigener Stufe plus Vorausplanung plus 10, damit Instanzen drinbleiben.
- **Bekannte Einschränkung, die dieser Filter nicht behebt:** Die Quellenangaben stammen überwiegend aus dem Vanilla-Datenstand von pfQuest. Von 17712 Gegenständen dort hat pfQuest-octo nur 3292 überschrieben — für die übrigen 14279 gelten Angaben, die dieser Server nachweislich geändert hat. Die OctoWoW-Datenbank kennt für „Feet of the Lynx" 473 Gegner zwischen Stufe 15 und 35, keinen über 0,0045 %; pfQuest kennt einen einzigen mit 1,92 %. Verlässliche Fundorte und Dropchancen gibt es nur aus der Serverdatenbank.

## 0.21.0
- **AtlasLoot wird als Quelle für Zugangsbedingungen genutzt.** Es führt in `AtlasLoot_Data["AtlasLootSources"]` zu über 7000 Gegenständen einen Herkunftstext, darunter rund 240 mit Ruf- und 300 mit Rangbedingung. Von dort stammt die Zeile „Warsong Gulch - Revered" an „Outrider's Bow" — sie steht weder im Scan-Tooltip noch in der Serverdatenbank, und mit allen anderen Addons abgeschaltet verschwindet sie.
- Direkt aus der Tabelle gelesen statt aus dem Tooltip gefischt: kein Überfahren nötig, keine Abhängigkeit von der Ladereihenfolge der Addons. Der Tooltip-Weg bleibt als Rückfalllösung, falls AtlasLoot nicht installiert ist.
- Erkannt wird über die Konstanten des Clients (`FACTION_STANDING_LABEL5` bis `8` und `RANK`), aus denen AtlasLoot seine Texte baut. Damit greift der Abgleich in jeder Sprache ohne eigene Wortliste.
- `AtlasLoot` als optionale Abhängigkeit in der TOC eingetragen, damit es vorher lädt.

## 0.20.4
- Die Rufzeile im Tooltip stammt nicht vom Spielclient, sondern von einem anderen Addon — mit allen Addons ausser BananaLootline abgeschaltet verschwindet sie. Der Abgriff erfolgt deshalb jetzt einen Frame später, wenn alle Addons ihre Zeilen angehängt haben. Sofort gelesen entschied die Ladereihenfolge darüber, ob die Bedingung überhaupt ankommt.
- Der verzögerte Abgriff gleicht den Namen ab: wandert der Zeiger in der Zwischenzeit weiter, bekommt nicht der falsche Gegenstand die Sperre.
- Neu: `/bll item <id>` zeigt den gespeicherten Eintrag eines Gegenstands samt erkannter Sperre. Damit lässt sich prüfen, ob eine Bedingung beim Überfahren angekommen ist.
- Neu: `/bll hooks` listet die aktiven Addons auf, die Tooltips erweitern könnten.

## 0.20.3
- Referenz-Loottabellen werden endlich aufgelöst. Der Code las dafür `entry["L"]` — das Feld heisst in pfQuest-octo, pfQuest-turtle und im Vanilla-Paket ausnahmslos `["R"]`, ein `["L"]` kommt in keiner items-Datei vor. Der Zweig lief damit seit jeher ins Leere. Im OctoWoW-Datenstand hängen 706 Gegenstände an einer solchen Tabelle, davon 247 ohne jede andere Quelle: die standen ohne Fundort in der Liste und fielen aus dem Wegplan heraus. Beide Schreibweisen werden gelesen, falls ein Datenpaket doch abweicht.

## 0.20.2
- Rufbedingungen werden erkannt und die betroffenen Gegenstände aus dem Wegplan genommen. „Outrider's Bow" beim Quartiermeister in den Barrens verlangt ehrfürchtigen Ruf bei der Warsongschlucht — das Addon schlug ihn einem Charakter der Stufe 15 als bestes Ziel vor.
- Gelesen wird die Bedingung aus dem Tooltip im Spiel, sobald der Zeiger über dem Gegenstand steht. Der nachgebaute Scan-Tooltip liefert diese Zeile nicht: bei „Outrider's Bow" kamen dort sechs Zeilen an, im Spiel hat er sieben, und die fehlende war die Bedingung. Geprüft wurde das über vier Lesearten — versteckt und sichtbar, an `WorldFrame` und an `UIParent` gehängt — keine davon liefert sie. Der Datenbankauszug führt das Feld ebenfalls nicht.
- Der Befund bleibt im gespeicherten Cache und gilt dauerhaft, auch wenn der Client den Tooltip wieder vergisst.

## 0.20.1
- Neu: `/bll selftest` prüft im laufenden Spiel, was sich von aussen nicht feststellen lässt — ob die Tooltipmuster gegen die tatsächlich angelegte Ausrüstung greifen, ob Client- und Anzeigesprache zusammenpassen, ob die Datenquellen geladen sind und ob der Scan-Tooltip überhaupt vollständige Zeilen liefert. Auffälligkeiten sind rot markiert; die Ausgabe ist zum Weitergeben gedacht.
- Neu: `/bll tip <id>` liest denselben Gegenstand auf vier Wegen und zeigt, welcher die vollständigen Tooltipzeilen liefert. Anlass ist eine Zugangsbedingung, die im Spiel sichtbar ist, im Scan-Tooltip aber fehlt.
- Die Ausgaben von `/bll dump` folgen jetzt ebenfalls der Anzeigesprache.

## 0.20.0
- **Stärke und Rüstung wurden auf deutschen Clients nie erkannt.** Die Muster `St[aä]rke` und `R[uü]stung` sehen nach einer Zeichenklasse mit zwei Buchstaben aus, sind aber eine mit drei Bytes — das Umlautzeichen steht in der Datei als UTF-8. Die Klasse passt auf genau eines dieser Bytes, ein echtes „ä" im Tooltip besteht aus zweien. Für Krieger und Paladine war damit jede Bewertung wertlos. Die Muster greifen jetzt unabhängig von der Zeichenkodierung.
- Der Wegplan zeigt Händlerware nur noch auf Wunsch, über einen Haken oben rechts in der Liste. Händlerware gilt als sicher und bekommt den vollen Zuwachs angerechnet, während ein Dungeondrop mit seiner Dropchance multipliziert wird — ungefiltert stand der Händler damit immer oben und verdrängte jedes Ziel, zu dem man tatsächlich hingehen würde.
- Die Gruppe „kein Fundort" entfällt. Sie beantwortete die Frage „wohin als nächstes" nicht. In der Einzelansicht erscheinen diese Teile weiterhin.
- Die Herkunftsetiketten folgen der Anzeigesprache. DUNGEON, VENDOR, WORLD und die übrigen standen im englischen Fenster weiterhin auf Deutsch.
- Fehler behoben: Das Mausrad zeichnete in der Einzelansicht die zuletzt aufgebaute Lootline über das Fenster. Die Zeilen waren nur versteckt, ihre Daten standen noch bereit, und der Radlauf rief die Listenausgabe ohne Prüfung auf.

## 0.19.3
- Die Prüfung auf Ruf- und Rangbedingungen greift jetzt dort, wo sie etwas bewirkt. Sie liest den Tooltip, und den sah nur, was das Addon beim Server anfragen musste — bei einem Stufe-15-Jäger 22 von 955 verwertbaren Kandidaten, also zwei Prozent. Geprüft wird jetzt jeder Gegenstand, der tatsächlich in der Liste landet; kennt der Client ihn, kostet das keine einzige Serveranfrage.
- Ein gefiltertes Teil lässt die Liste nicht mehr schrumpfen: die nachfolgenden rücken auf.
- Drei Diagnosewerkzeuge unter `tools/`: `diag_full.lua` prüft alle Ausrüstungsplätze gegen die Itemdatenbank, `diag_gaps.lua` misst Lücken in der Datenlage, `diag_perf.lua` die Laufzeit. Aufruf vom Addonstamm, etwa `lua5.1 tools/diag_full.lua 60 WARRIOR`.
- Geprüft über 24 Kombinationen aus Stufe und Klasse: keine Vorschläge über der Stufengrenze, keine fremde Klasse, kein falscher Ausrüstungsplatz.

## 0.19.2
- Die Anforderungsstufe wird zwischen Itemcache und Itemdatenbank abgeglichen; bei Uneinigkeit gilt die höhere Angabe. „Outrider's Bow" erschien bei einem Stufe-15-Jäger mit dem Vermerk „ab 18", obwohl Tooltip und Import übereinstimmend Stufe 60 nennen — im gespeicherten Cache stand noch ein alter Wert, und Cache-Einträge werden nicht neu bewertet, solange ihre Version passt.
- Gegenstände mit Ruf- oder Rangbedingung erscheinen nicht mehr in den Vorschlägen. Beim PvP-Quartiermeister in den Barrens steht ein Bogen ab Stufe 18 — zu holen ist er aber erst mit dem passenden Ehrenrang. Das Addon kannte nur die Stufenangabe und setzte solche Teile ganz nach oben. Die Bedingung wird jetzt beim Auslesen des Tooltips erkannt und dauerhaft vermerkt, weil der Client den Tooltip später wieder vergisst.
- Neuer Befehl `/bll locked` blendet diese Teile wieder ein.
- `/bll dump <id>` weist eine erkannte Zugangsbedingung getrennt aus.
- Cache-Version 5: ältere Einträge kennen das neue Feld nicht und werden einmalig neu eingelesen.

## 0.19.1
- Fehler aus 0.19.0 behoben: Ein Stufe-15-Jäger bekam Gegenstände mit Itemlevel 65 aus Tanaris vorgeschlagen, und die Kandidatenzahl stieg von rund 600 auf 4118. Ursache war der Importfilter — 2275 der 11349 Einträge führen keine Anforderungsstufe, und die Prüfung „Anforderungsstufe kleiner als Obergrenze" ist bei einer 0 immer wahr. Fehlt die Angabe, wird sie jetzt über das Itemlevel geschätzt; der Abstand beträgt im Datenbestand im Median 5 Stufen.
- Der Rückblick nach unten wächst mit der Stufe statt fest bei 10 zu liegen: 3 Stufen auf Stufe 15, 10 auf Stufe 60. Der feste Wert war für das Stufenende gedacht und riss auf niedrigen Stufen das Suchband unnötig weit auf — Stufe 15 suchte 5 bis 21 ab statt 12 bis 21.
- Neuer Regressionstest `test_poolbounds.lua` mit genau den beiden Gegenständen aus dem Fehlerbericht.

## 0.19.0
- Effekte ohne Zahl werden beim Vergleich berücksichtigt. Der Scanner liest Werte aus dem Tooltip; ein Proc-Effekt steht dort als Satz und zählte deshalb null Punkte. Die Hand der Gerechtigkeit verlor damit gegen jedes beliebige Teil mit vier Ausdauer. Trägt der Spieler ein Teil mit unbeziffertem Effekt, muss ein Kandidat jetzt deutlich vorne liegen statt knapp; solche Vorschläge werden als unvollständiger Vergleich gekennzeichnet. Das angelegte Teil bekommt den Vermerk „Effekt nicht bewertet".
- Items ohne Kampfeffekt sind davon nicht betroffen. Die Anstecknadel der Argentumdämmerung bleibt bei null Punkten, jedes Teil mit einem einzigen Wert schlägt sie weiterhin.
- `/bll dump <id>` listet die Zeilen auf, die nach einem Effekt aussehen, aus denen aber kein Wert kam — damit lassen sich Fehlalarme der Erkennung melden.
- Statusmeldungen folgen jetzt dem Schalter DE/EN. Rund 60 Texte in Chat, Hilfe und Fortschrittsanzeige standen fest im Code und blieben deutsch, auch wenn die Anzeigesprache auf Englisch stand. Die Tooltip-Auswertung folgt weiterhin der Clientsprache.
- `/bll cat` versteht die Kategorien jetzt auch auf Englisch: `world`, `worldboss`, `battleground`, `vendor`, `object`.
- `/bll ahead` steuert endlich die Suche. Bisher wirkte die Einstellung nur als Filter auf bereits gefundene Items; `/bll up` suchte immer mit der festen Spanne 6.
- Das Suchband reicht 10 Stufen nach unten statt der halben Vorausplanung. Ein Charakter auf Stufe 60 suchte damit nur 57 bis 63 ab — ein Streifen, in dem am Stufenende fast nichts liegt. Jetzt sind es 50 bis 63.
- Die Quellenstufe eines Items ist nicht mehr das Minimum über alle Quellen, sondern die niedrigste Quelle innerhalb des Suchbands. Ein Raidteil, das irgendwo auch ein Stufe-40-Mob trägt, fiel vorher aus jedem Band eines Stufe-60-Charakters heraus.
- Der Kandidatenpool zieht zusätzlich Items aus der importierten ItemDB. pfQuest liefert nur Items mit brauchbarer Stufenangabe an der Quelle; am Stufenende blieb davon zu wenig übrig. Items aus dem Import haben keinen Fundort, werden als solche gekennzeichnet und hinter den verorteten einsortiert. Im Wegplan erscheinen sie nicht — dort gehört nur hin, wohin man auch gehen kann.
- Fehler behoben: `Progress()` war zweimal definiert. Die zweite Fassung überschrieb die erste und kannte nur einen Zustand, den es nicht gibt — während Abfrage und Auswertung zeigte das Fenster deshalb gar keinen Fortschritt.
- Fehler behoben: Die Meldung zu `/bll unused` gab `0%%` statt `0%` aus.
- Vier neue Testdateien: `test_messages.lua` prüft Schlüsselgleichheit, Formatplatzhalter und dass keine Meldung mehr fest verdrahtet ist, `test_searchband.lua` deckt Stufenband, Quellenstufe und Poolaufbau ab, `test_trinket.lua` den Vergleich bei Schmuckstücken ohne Werte, `test_unscored.lua` die Effekterkennung samt Gegenproben gegen Fehlalarme.

## 0.18.0
- Waffenfertigkeiten werden aus dem Client gelesen. Gelernte Waffen gelten sofort, lernbare erscheinen mit Hinweis „Waffenmeister" (ab Stufe 10, Stangenwaffen ab 20).
- Beidhändigkeit gilt, sobald der Client sie meldet. Vorher: Schurke ab 10, Krieger und Jäger ab 20.
- Schurken bekommen keine Einhandäxte mehr vorgeschlagen.
- Schamanen: keine Faustwaffen. Zweihandäxte und -kolben nur mit dem entsprechenden Talent.
- Fehler behoben: Items über der eigenen Stufe wurden dauerhaft aussortiert und kamen auch nach einem Stufenaufstieg nicht zurück. Die Vorausplanung zeigte dadurch kaum importierte Items. Cache-Version 4.

## 0.17.2
- `ItemData.lua` neu gebaut: Angriffskraft bei 600 Items, Distanz-AP 47, Verteidigung 368, Blockchance 62, Blockwert 39 und Leben/5 s 100 nachgetragen.
- Konverter überspringt bedingte Effekte („when fighting Beasts", „in Cat form only", Procs).
- Setbonus der Cryptstalker-Teile wird nicht mehr pro Teil als Wert gezählt.

## 0.17.1
- Scanner: „ranged attack power" zählte als Nahkampf-AP, „Increased Defense +7" und schulgebundener Zauberschaden wurden nicht erkannt. Behoben, Cache-Version 3.
- Jäger-Gewichte aus Icy Veins: Beweglichkeit 2,5, Krit und Treffer je 32, allgemeine Angriffskraft 1,0 statt 0,5.

## 0.17.0
- Lootline sortiert nach erwartetem Zuwachs pro Besuch (Zuwachs × Dropchance).
- Quests und Händler gelten als sichere Quelle statt als 1 % Dropchance.
- Waffen in der Schildhand verlangen Beidhändigkeit.

## 0.16.3
- Figur, Statfeld und Waffenreihe mittig zwischen Logo und Knopfleiste, Abstand zwischen Füssen und Statfeld.

## 0.16.2
- Figur nach oben verschoben, Statfeld und Waffenreihe direkt darunter.

## 0.16.1
- Statfeld nach Vorbild des Charakterfensters: zwei Kästen mit Auswahl (Grundwerte, Nahkampf, Distanz, Zauber, Verteidigung).

## 0.16.0
- Sprachumschalter DE/EN oben rechts, gespeichert pro Account. Die Tooltip-Auswertung folgt weiter der Clientsprache.
- Dankeschön-Knopf mit Dankesfenster.
- Statfeld unter die Figur verlegt.

## 0.15.0
- Slot-Ansicht neu gegliedert: Bereich „Angelegt" und Bereich „Upgrades" mit Name, Wertänderung, Fundort und Dropchance.
- Anbindung an BananaRepublik Partnerguild 2.1.0: Crafter-Anzahl bei Verzauberungen, Klick öffnet das Rezept.

## 0.14.0
- Umbenennung von OctoLootline in BananaLootline, Befehl `/bll`. Einstellungen werden aus OctoLootline übernommen.

## 0.13.3
- Lootline und Verzauberungen scrollbar, Überschriften einzeilig, Verzauberungen zweizeilig mit lesbaren Wertnamen.

## 0.13.2
- Quests mit Auswahlbelohnung zählen nur das beste Teil.

## 0.13.1
- Ausgangsstand der Übergabe.
