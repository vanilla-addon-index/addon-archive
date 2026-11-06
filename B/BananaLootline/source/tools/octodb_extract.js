/* ===========================================================================
   BananaLootline - octodb_extract.js

   Zweck: Itemdaten aus der OctoWoW-Datenbank holen, OHNE gegen den
   DDoS-Schutz zu laufen.

   octowow.st/db liegt hinter einer Blazingfast-Browserpruefung. Ein
   Skript mit requests/curl bekommt dort nur die Challenge-Seite zu sehen.
   Dein Browser hat die Pruefung aber langst bestanden - also extrahieren
   wir direkt dort.

   ANLEITUNG
   ---------
   1. octowow.st/db oeffnen und im Menue auf "Items" klicken.
      NICHT die Suche benutzen - Suchergebnisse enthalten keine
      Slotangaben und sind fuer uns wertlos.
   2. Im Filterbereich den Slot waehlen, z.B. Kopf, und anwenden.
      Die URL muss danach "?items=" enthalten.
   3. Blaettern ist NICHT noetig. Die Seite zeigt zwar 50 Zeilen,
      haelt aber die komplette Liste im Browser.
   4. Entwicklerkonsole oeffnen (F12, Reiter "Konsole").
   5. Diese Datei komplett hineinkopieren, Enter.
   6. Es laedt eine Datei octodb_<zeitstempel>.json herunter.
   7. Schritte 2-6 pro Slot wiederholen.

   ATTRIBUTSPALTEN (optional)
   --------------------------
   Die Standardansicht liefert nur Name, Level, Req., Typ und Ruestung.
   Attribute wie Ausdauer oder Zaubermacht fehlen, weil sie keine Spalte
   der Tabelle sind - und was nicht angezeigt wird, steckt auch nicht in
   den Daten.

   Fuer das Addon ist das kein Problem: es liest Werte ohnehin aus dem
   Tooltip im Spiel. Der Import muss nur Slot und Qualitaet liefern.

   Wer die Werte trotzdem mitnehmen will: im Filterbereich pro Attribut
   eine Kriterienzeile anlegen, z.B. "Ausdauer - mindestens - 0". Der
   Schwellwert 0 schliesst nichts aus, erzwingt aber die Spalte. Danach
   taucht das Feld im Export auf.
   8. Alle JSON-Dateien in einen Ordner legen und den Importer laufen lassen:

        python3 octodb_import.py --from-json ./exports -o ../Data/ItemData.lua

   Falls der Browser das Einfuegen in die Konsole blockiert, muss man
   einmal "allow pasting" eintippen und bestaetigen.
=========================================================================== */

(function () {
  "use strict";

  var rows = [];
  var origin = "unbekannt";

  /* ------------------------------------------------------------------
     NUR die Itemliste nehmen.

     Eine AoWoW-Seite kann mehrere Listviews tragen - auf einer
     Suchergebnisseite je eine fuer Items, NPCs, Objekte, Quests und
     Zauber. Alle einzusammeln liefert einen Datensalat, in dem ein NPC
     genauso aussieht wie ein Item. Also gezielt auswaehlen.
  ------------------------------------------------------------------ */
  function hasSlot(data) {
    for (var i = 0; i < Math.min(data.length, 50); i++) {
      if (data[i] && data[i].slot !== undefined) { return true; }
    }
    return false;
  }

  var candidates = [];
  try {
    if (typeof g_listviews === "object" && g_listviews) {
      for (var key in g_listviews) {
        var lv = g_listviews[key];
        if (lv && lv.data && lv.data.length) {
          candidates.push({ key: key, lv: lv });
        }
      }
    }
  } catch (e) {
    console.warn("[BLL] g_listviews nicht lesbar:", e);
  }

  if (candidates.length > 1) {
    var names = [];
    for (var c = 0; c < candidates.length; c++) {
      names.push(candidates[c].key + " (" + candidates[c].lv.data.length + ")");
    }
    console.log("[BLL] Listen auf dieser Seite: " + names.join(", "));
  }

  var chosen = null;

  /* Erlaubt manuelles Erzwingen:  BLL_LISTVIEW = "items"  vor dem Ausfuehren */
  if (typeof BLL_LISTVIEW === "string") {
    for (var f = 0; f < candidates.length; f++) {
      if (candidates[f].key === BLL_LISTVIEW) { chosen = candidates[f]; }
    }
  }

  /* Bevorzugt: die Liste, die tatsaechlich Slotangaben mitbringt */
  if (!chosen) {
    for (var d = 0; d < candidates.length; d++) {
      if (hasSlot(candidates[d].lv.data)) { chosen = candidates[d]; break; }
    }
  }

  /* Sonst: die, die "items" heisst oder das Item-Template nutzt */
  if (!chosen) {
    for (var g = 0; g < candidates.length; g++) {
      if (candidates[g].key === "items" || candidates[g].lv.template === "item") {
        chosen = candidates[g];
        break;
      }
    }
  }

  if (chosen) {
    rows = chosen.lv.data;
    origin = "g_listviews." + chosen.key;
  }

  /* ------------------------------------------------------------------
     Fallback: Inline-Skripte nach "data: [...]" absuchen.
     Klammerzaehlung statt Regex, sonst schneidet man bei verschachtelten
     Arrays zu frueh ab.
  ------------------------------------------------------------------ */
  function extractArrays(text) {
    var out = [];
    var marker = /data\s*:\s*\[/g;
    var m;

    while ((m = marker.exec(text)) !== null) {
      var start = m.index + m[0].length - 1;
      var depth = 0, i = start, inStr = false, esc = false, quote = null;

      while (i < text.length) {
        var ch = text[i];
        if (inStr) {
          if (esc) { esc = false; }
          else if (ch === "\\") { esc = true; }
          else if (ch === quote) { inStr = false; }
        } else {
          if (ch === '"' || ch === "'") { inStr = true; quote = ch; }
          else if (ch === "[") { depth++; }
          else if (ch === "]") {
            depth--;
            if (depth === 0) { out.push(text.slice(start, i + 1)); break; }
          }
        }
        i++;
      }
    }
    return out;
  }

  if (rows.length === 0) {
    var scripts = document.getElementsByTagName("script");
    for (var sc = 0; sc < scripts.length; sc++) {
      var blobs = extractArrays(scripts[sc].textContent || "");
      for (var b = 0; b < blobs.length; b++) {
        try {
          var parsed = eval("(" + blobs[b] + ")");
          if (parsed && parsed.length && hasSlot(parsed)) {
            rows = parsed;
            origin = "inline script #" + sc;
            break;
          }
        } catch (e2) { /* naechster Kandidat */ }
      }
      if (rows.length) { break; }
    }
  }

  if (rows.length === 0) {
    console.error("[BLL] Keine Itemliste gefunden. Bist du auf der "
      + "Items-Seite mit gesetztem Filter?");
    return;
  }

  /* ------------------------------------------------------------------
     Pruefen, ob die Liste ueberhaupt brauchbar ist.

     Die Listview einer SUCHERGEBNISSEITE fuehrt nur Name, Level und Typ -
     ohne Slot ist der Export fuer uns wertlos. Lieber hier abbrechen als
     eine unbrauchbare Datei erzeugen.
  ------------------------------------------------------------------ */
  if (!hasSlot(rows)) {
    console.error("[BLL] Diese Liste enthaelt KEINE Slotangaben "
      + "(" + rows.length + " Zeilen aus " + origin + ").\n\n"
      + "Das passiert auf Suchergebnisseiten (?search=...). Deren Tabelle\n"
      + "kennt nur Name, Level und Typ.\n\n"
      + "So geht es richtig:\n"
      + " 1. Im Menue oben auf \"Items\" klicken (nicht die Suche benutzen)\n"
      + " 2. Im Filterbereich den Slot waehlen, z.B. Kopf\n"
      + " 3. Filter anwenden - die URL enthaelt dann ?items=...\n"
      + " 4. Dieses Skript erneut ausfuehren");
    return;
  }

  /* Doppelte entfernen - mehrere Listviews koennen dieselben Items zeigen */
  var seen = {}, unique = [];
  for (var r = 0; r < rows.length; r++) {
    var row = rows[r];
    if (row && row.id != null && !seen[row.id]) {
      seen[row.id] = true;
      unique.push(row);
    }
  }

  /* Uebersicht der vorkommenden Felder - hilft beim Anpassen der
     KEYMAP im Python-Importer */
  var keys = {};
  for (var u = 0; u < unique.length; u++) {
    for (var k in unique[u]) { keys[k] = (keys[k] || 0) + 1; }
  }

  console.log("[BLL] Quelle: " + origin);
  console.log("[BLL] Items: " + unique.length);
  console.log("[BLL] Felder:", Object.keys(keys).sort().join(", "));
  console.log("[BLL] Beispiel:", unique[0]);

  /* Download anstossen */
  var payload = {
    exported: new Date().toISOString(),
    url: location.href,
    count: unique.length,
    fields: Object.keys(keys).sort(),
    items: unique
  };

  var blob = new Blob([JSON.stringify(payload)], { type: "application/json" });
  var url = URL.createObjectURL(blob);
  var a = document.createElement("a");
  a.href = url;
  a.download = "octodb_" + Date.now() + ".json";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);

  console.log("[BLL] Datei heruntergeladen. Naechsten Slot filtern und "
    + "das Skript erneut ausfuehren.");
})();
