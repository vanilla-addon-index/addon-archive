/* ===========================================================================
   BananaLootline - octodb_details.js

   Holt die VOLLSTAENDIGEN Itemdaten, indem es fuer jedes Item der aktuell
   gefilterten Liste die Einzelseite abruft und auswertet.

   Warum ueberhaupt: die Listenansicht fuehrt nur die Spalten, die sie
   anzeigt - Name, Level, Req., Typ, Ruestung. Attribute, Equip-Effekte und
   Klassenbeschraenkungen stehen nur auf der Itemseite.

   Kein Durchklicken: die Seiten werden per fetch() im Hintergrund geladen.
   Deine Sitzung inklusive DDoS-Freigabe gilt dabei mit, die Seite bleibt
   offen und es geht deutlich schneller als ueber Navigation.

   BITTE MIT AUGENMASS
   -------------------
   Das sind viele Anfragen an einen Hobbyserver, der derzeit angegriffen
   wird. Voreingestellt sind 2 Anfragen pro Sekunde - das ist etwa das
   Tempo eines Menschen, der zuegig durch die Datenbank klickt. Bitte
   nicht wesentlich hoeher drehen.

   Der schonendste Weg bleibt, das OctoWoW-Team nach einem Datenbankauszug
   zu fragen. Eine Nachricht statt tausend Anfragen.

   ANLEITUNG
   ---------
   1. Wie bisher: Items -> Slot filtern, sodass die URL "?items=" enthaelt.
   2. Konsole oeffnen (F12), diese Datei einfuegen, Enter.
   3. Laufen lassen. Der Fortschritt steht in der Konsole.
      Abbrechen mit:            BLL.stop()
      Fortsetzen nach Abbruch:  Skript einfach erneut ausfuehren -
                                bereits geholte Items werden uebersprungen.
   4. Am Ende laedt eine JSON-Datei herunter.

   EINSTELLUNGEN (vor dem Ausfuehren setzen, alle optional)
   --------------------------------------------------------
     BLL_RATE       = 4;      Anfragen pro Sekunde (Startrate)
     BLL_PARALLEL   = 3;      gleichzeitig offene Anfragen

   ZUR GESCHWINDIGKEIT
   -------------------
   Der Flaschenhals ist die Antwortzeit des Servers, nicht die Pause.
   Laeuft immer nur eine Anfrage, gilt:

       Dauer pro Item = Antwortzeit + Pause

   Bei zwei Sekunden Antwortzeit sind das 0,5 Items pro Sekunde - egal
   was bei BLL_RATE steht. Deshalb schickt diese Fassung mehrere
   Anfragen gleichzeitig los. Der Durchsatz ist dann:

       min(BLL_RATE, BLL_PARALLEL / Antwortzeit)

   Drei parallele Anfragen bei zwei Sekunden Antwortzeit ergeben also
   1,5 Items pro Sekunde statt 0,5 - dreimal so schnell.

   Mehr als 6 bringt nichts: Browser oeffnen pro Server nicht mehr als
   sechs gleichzeitige Verbindungen. Und die Last beim Server steigt
   proportional mit - bei Challenge-Seiten drosselt das Skript deshalb
   von selbst.
     BLL_MIN_QUALITY= 2;      erst ab Gruen holen (0 = alles)
     BLL_MAX_LEVEL  = 0;      nur Items bis zu diesem Itemlevel (0 = alle)
=========================================================================== */

(function () {
  "use strict";

  var RATE        = (typeof BLL_RATE === "number") ? BLL_RATE : 4;
  var PARALLEL    = (typeof BLL_PARALLEL === "number") ? BLL_PARALLEL : 3;
  var MIN_QUALITY = (typeof BLL_MIN_QUALITY === "number") ? BLL_MIN_QUALITY : 2;
  var MAX_LEVEL   = (typeof BLL_MAX_LEVEL === "number") ? BLL_MAX_LEVEL : 0;

  var STORE_KEY = "bll_details_cache";

  /* ------------------------------------------------------------------
     Qualitaet steckt als Ziffer vor dem Namen, invertiert:
     1 = legendaer ... 6 = Schrott
  ------------------------------------------------------------------ */
  var PREFIX_QUALITY = { "1": 5, "2": 4, "3": 3, "4": 2, "5": 1, "6": 0 };

  function splitName(raw) {
    if (typeof raw !== "string" || !raw.length) { return { name: raw, quality: null }; }
    var q = PREFIX_QUALITY[raw.charAt(0)];
    if (q !== undefined) { return { name: raw.slice(1), quality: q }; }
    return { name: raw, quality: null };
  }

  /* ------------------------------------------------------------------
     Statmuster. Die Datenbank ist englisch, deshalb reicht ein Satz.
     Aufbau: [ Statname, Regex mit genau einer Zahlengruppe ]
  ------------------------------------------------------------------ */
  var PATTERNS = [
    ["STR",        /\+(\d+)\s+Strength/i],
    ["AGI",        /\+(\d+)\s+Agility/i],
    ["STA",        /\+(\d+)\s+Stamina/i],
    ["INT",        /\+(\d+)\s+Intellect/i],
    ["SPI",        /\+(\d+)\s+Spirit/i],

    ["ARMOR",      /(\d+)\s+Armor\b/i],
    ["BLOCKVALUE", /(\d+)\s+Block\b/i],

    ["RES_FIRE",   /\+(\d+)\s+Fire Resistance/i],
    ["RES_FROST",  /\+(\d+)\s+Frost Resistance/i],
    ["RES_NATURE", /\+(\d+)\s+Nature Resistance/i],
    ["RES_SHADOW", /\+(\d+)\s+Shadow Resistance/i],
    ["RES_ARCANE", /\+(\d+)\s+Arcane Resistance/i],

    ["AP",         /Increases attack power by (\d+)/i],
    ["RAP",        /ranged attack power by (\d+)/i],
    ["SPELLPOWER", /damage and healing done by magical spells and effects by up to (\d+)/i],
    ["HEALPOWER",  /healing done by spells and effects by up to (\d+)/i],
    ["CRIT",       /chance to get a critical strike by (\d+)/i],
    ["SPELLCRIT",  /chance to get a critical strike with spells by (\d+)/i],
    ["HIT",        /chance to hit by (\d+)/i],
    ["SPELLHIT",   /chance to hit with spells by (\d+)/i],
    ["DEFENSE",    /Increases defense by (\d+)/i],
    ["DODGE",      /chance to dodge an attack by (\d+)/i],
    ["PARRY",      /chance to parry an attack by (\d+)/i],
    ["BLOCK",      /chance to block attacks? by (\d+)/i],
    ["MP5",        /(\d+) mana per 5 sec/i],
    ["MP5",        /(\d+) mana every 5 sec/i],
    ["HP5",        /(\d+) health every 5 sec/i],

    ["WEAPON_SPEED", /Speed (\d+\.\d+)/i],
    ["WEAPON_DPS",   /\((\d+\.\d+) damage per second\)/i]
  ];

  /* Schulgebundener Zauberschaden - eigener Schluessel, weil er nur fuer
     eine Schule zaehlt und nicht mit allgemeiner Zaubermacht verrechnet
     werden darf. */
  var SCHOOL_PATTERN =
    /damage done by (Arcane|Fire|Frost|Holy|Nature|Shadow) spells and effects by up to (\d+)/gi;

  var DMG_PATTERN = /(\d+)\s*-\s*(\d+)\s+Damage/i;

  /* ------------------------------------------------------------------
     HTML -> reiner Text. Robuster als im DOM nach einem bestimmten
     Container zu suchen, dessen Klassenname sich zwischen AoWoW-Forks
     unterscheidet.
  ------------------------------------------------------------------ */
  function htmlToText(html) {
    var t = html;
    t = t.replace(/<script[\s\S]*?<\/script>/gi, " ");
    t = t.replace(/<style[\s\S]*?<\/style>/gi, " ");
    t = t.replace(/<br\s*\/?>/gi, "\n");
    t = t.replace(/<\/(tr|div|p|li|td)>/gi, "\n");
    t = t.replace(/<[^>]+>/g, " ");
    t = t.replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
         .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"');
    t = t.replace(/[ \t]+/g, " ");
    return t;
  }

  /* Slots, bei denen Waffenwerte ueberhaupt Sinn ergeben */
  var WEAPON_SLOTS = { 13:1, 14:1, 15:1, 17:1, 21:1, 22:1, 25:1, 26:1 };

  function parseItemPage(html, id, slot) {
    var out = { id: id, stats: {} };

    /* Weg 1: AoWoW legt die Werte oft als jsonequip ab. Wenn vorhanden,
       ist das die verlaesslichste Quelle. */
    var je = html.indexOf("jsonequip");
    if (je !== -1) {
      var braceStart = html.indexOf("{", je);
      if (braceStart !== -1) {
        var depth = 0, i = braceStart;
        while (i < html.length) {
          if (html[i] === "{") { depth++; }
          else if (html[i] === "}") {
            depth--;
            if (depth === 0) { break; }
          }
          i++;
        }
        try {
          var obj = eval("(" + html.slice(braceStart, i + 1) + ")");
          if (obj && typeof obj === "object") { out.jsonequip = obj; }
        } catch (e) { /* egal, Weg 2 greift */ }
      }
    }

    /* Weg 2: Tooltiptext auswerten. */
    var text = htmlToText(html);

    for (var p = 0; p < PATTERNS.length; p++) {
      var key = PATTERNS[p][0];
      if (out.stats[key] !== undefined) { continue; }
      var m = text.match(PATTERNS[p][1]);
      if (m) { out.stats[key] = parseFloat(m[1]); }
    }

    /* Schadensbereich nur bei Waffen auswerten. Auf Ruestung stammt eine
       solche Zeile aus einem Proc-Text ("Adds 12 - 18 damage") und ist
       kein Grundschaden - so bekam ein Helm faelschlich Waffenwerte. */
    if (WEAPON_SLOTS[slot]) {
      var dm = text.match(DMG_PATTERN);
      if (dm) {
        out.stats.WEAPON_MIN = parseInt(dm[1], 10);
        out.stats.WEAPON_MAX = parseInt(dm[2], 10);
      }
    } else {
      delete out.stats.WEAPON_SPEED;
      delete out.stats.WEAPON_DPS;
    }

    SCHOOL_PATTERN.lastIndex = 0;
    var sm;
    while ((sm = SCHOOL_PATTERN.exec(text)) !== null) {
      out.stats["SPELLPOWER_" + sm[1].toUpperCase()] = parseInt(sm[2], 10);
    }

    /* Quick Facts: Klassen- und Rassenmaske stehen dort als Zahl.
       Deutlich verlaesslicher als die Zeile "Classes: Mage" zu parsen. */
    var cm = text.match(/Class Mask:\s*(-?\d+)/i);
    if (cm) { out.classmask = parseInt(cm[1], 10); }
    var rm = text.match(/Race Mask:\s*(-?\d+)/i);
    if (rm) { out.racemask = parseInt(rm[1], 10); }

    var rl = text.match(/Requires Level (\d+)/i);
    if (rl) { out.reqlevel = parseInt(rl[1], 10); }

    var un = text.match(/Durability \d+ \/ (\d+)/i);
    if (un) { out.durability = parseInt(un[1], 10); }

    return out;
  }

  /* ------------------------------------------------------------------
     Itemliste der aktuellen Seite holen
  ------------------------------------------------------------------ */
  function getListRows() {
    var rows = [];
    try {
      if (typeof g_listviews === "object" && g_listviews) {
        for (var key in g_listviews) {
          var lv = g_listviews[key];
          if (lv && lv.data && lv.data.length) {
            for (var i = 0; i < lv.data.length; i++) {
              if (lv.data[i] && lv.data[i].slot !== undefined) {
                rows.push(lv.data[i]);
              }
            }
          }
        }
      }
    } catch (e) { /* nichts */ }
    return rows;
  }

  var listRows = getListRows();
  if (!listRows.length) {
    console.error("[BLL] Keine Itemliste mit Slotangaben gefunden.\n"
      + "Bist du auf der Items-Seite mit gesetztem Filter (?items=...)?");
    return;
  }

  /* ------------------------------------------------------------------
     Vorfilter - jede uebersprungene Zeile ist eine Anfrage weniger
  ------------------------------------------------------------------ */
  var todo = [], skipped = 0;

  for (var r = 0; r < listRows.length; r++) {
    var row = listRows[r];
    var sn = splitName(row.name);
    var quality = (row.quality !== undefined) ? row.quality : sn.quality;

    if (MIN_QUALITY > 0 && quality !== null && quality < MIN_QUALITY) { skipped++; continue; }
    if (MAX_LEVEL > 0 && row.level && row.level > MAX_LEVEL) { skipped++; continue; }

    todo.push({
      id: row.id,
      name: sn.name,
      quality: quality,
      level: row.level,
      reqlevel: row.reqlevel,
      slot: row.slot,
      classs: row.classs,
      subclass: row.subclass,
      armor: row.armor
    });
  }

  /* Bereits geholte Items aus einem frueheren Lauf uebernehmen */
  var cache = {};
  try {
    var stored = sessionStorage.getItem(STORE_KEY);
    if (stored) { cache = JSON.parse(stored); }
  } catch (e) { cache = {}; }

  var pending = [];
  for (var t = 0; t < todo.length; t++) {
    if (cache[todo[t].id]) { continue; }
    pending.push(todo[t]);
  }

  console.log("[BLL] Liste: " + listRows.length + " Items, "
    + skipped + " durch Vorfilter aussortiert, "
    + (todo.length - pending.length) + " schon geholt, "
    + pending.length + " offen.");
  console.log("[BLL] Geschaetzte Dauer: ca. "
    + Math.ceil(pending.length / RATE / 60) + " Minuten bei " + RATE + "/s.");

  if (!pending.length) {
    console.log("[BLL] Nichts zu tun - lade vorhandene Daten herunter.");
  }

  /* ------------------------------------------------------------------
     Abarbeiten

     Robustheit hat hier Vorrang vor Tempo. Ein Lauf dauert Minuten, und
     wenn er stillschweigend stehenbleibt, ist die Arbeit verloren.
     Deshalb:
       - jeder Schritt in try/catch, die naechste Runde wird IMMER geplant
       - ein Wachhund startet neu, falls doch mal nichts mehr passiert
       - Challenge- und Fehlerseiten werden erkannt statt als leeres
         Item verbucht
       - BLL.save() laedt jederzeit herunter, was bereits da ist
  ------------------------------------------------------------------ */

  var stopped = false, done = 0, failed = 0, challenged = 0, index = 0;
  var lastActivity = Date.now();
  var startedAt = Date.now();
  var retry = [];
  var watchdog = null;

  function persist() {
    try { sessionStorage.setItem(STORE_KEY, JSON.stringify(cache)); }
    catch (e) { console.warn("[BLL] Zwischenspeichern fehlgeschlagen:", e); }
  }

  /* Erkennt Seiten, die kein Item enthalten: DDoS-Pruefung, Fehlerseiten,
     Weiterleitungen. Ohne diese Pruefung landet so etwas als Item ohne
     Werte im Cache und wird nie wieder abgefragt. */
  function looksWrong(html) {
    if (!html || html.length < 500) { return "zu kurz"; }
    if (/Verifying your browser|DDoS Protection|Just a moment/i.test(html)) {
      return "DDoS-Pruefung";
    }
    if (/<title>\s*(404|403|500|Error)/i.test(html)) { return "Fehlerseite"; }
    return null;
  }

  function download(obj, prefix) {
    var blob = new Blob([JSON.stringify(obj)], { type: "application/json" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = prefix + "_" + Date.now() + ".json";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  function buildPayload() {
    var items = [];
    for (var i = 0; i < todo.length; i++) {
      var base = todo[i];
      var detail = cache[base.id];
      if (!detail) { continue; }

      var merged = {
        id: base.id, name: base.name, quality: base.quality,
        level: base.level, slot: base.slot,
        classs: base.classs, subclass: base.subclass
      };
      if (base.armor !== undefined) { merged.armor = base.armor; }
      if (detail.reqlevel !== undefined) { merged.reqlevel = detail.reqlevel; }
      else if (base.reqlevel !== undefined) { merged.reqlevel = base.reqlevel; }
      if (detail.classmask !== undefined) { merged.classmask = detail.classmask; }
      if (detail.racemask !== undefined) { merged.racemask = detail.racemask; }
      merged.stats = detail.stats || {};
      items.push(merged);
    }
    return {
      exported: new Date().toISOString(),
      url: location.href,
      source: "item-detail-pages",
      complete: (items.length === todo.length),
      expected: todo.length,
      count: items.length,
      items: items
    };
  }

  window.BLL = window.BLL || {};

  window.BLL.stop = function () {
    stopped = true;
    if (watchdog) { clearInterval(watchdog); watchdog = null; }
    console.log("[BLL] Abbruch. " + done + " geholt. BLL.save() laedt sie "
      + "herunter, ein erneuter Lauf setzt hier an.");
  };

  window.BLL.status = function () {
    console.log("[BLL] " + index + "/" + pending.length + " angestossen, "
      + done + " erfolgreich, " + failed + " fehlgeschlagen, "
      + challenged + " Challenge-Seiten, "
      + Math.round((Date.now() - lastActivity) / 1000) + "s seit der letzten "
      + "Antwort, gestoppt: " + stopped);
    return { index: index, total: pending.length, done: done, failed: failed };
  };

  window.BLL.save = function () {
    persist();
    var p = buildPayload();
    console.log("[BLL] " + p.count + " von " + p.expected + " Items gespeichert"
      + (p.complete ? "" : " (UNVOLLSTAENDIG)"));
    download(p, "octodb_detail");
    return p.count;
  };

  var retryRound = 0;

  function finish(reason) {
    /* Was an Challenge-Seiten oder Fehlern gescheitert ist, bekommt zwei
       zusaetzliche Runden - langsamer und mit weniger Parallelitaet. */
    if (retry.length && retryRound < 2 && !stopped) {
      retryRound++;
      pending = retry;
      retry = [];
      index = 0;
      parallelNow = 1;
      console.log("[BLL] Nachlauf " + retryRound + ": " + pending.length
        + " Items nochmal, einzeln und langsam.");
      setTimeout(pump, 3000);
      return;
    }

    if (watchdog) { clearInterval(watchdog); watchdog = null; }
    persist();
    var p = buildPayload();
    console.log("[BLL] Ende (" + reason + "). " + p.count + " von "
      + p.expected + " Items. Fehlgeschlagen: " + failed
      + ", Challenge-Seiten: " + challenged);
    if (!p.complete) {
      console.warn("[BLL] Unvollstaendig. Skript spaeter erneut ausfuehren - "
        + "die bereits geholten Items werden uebersprungen.");
    }
    download(p, "octodb_detail");
  }

  /* ------------------------------------------------------------------
     Ablaufsteuerung: mehrere Anfragen gleichzeitig

     Zwei unabhaengige Bremsen:
       PARALLEL - wie viele Anfragen gleichzeitig offen sein duerfen
       RATE     - wie oft eine NEUE gestartet werden darf

     Die zweite verhindert, dass beim Start alle auf einmal rausgehen.
  ------------------------------------------------------------------ */

  var inFlight = 0;
  var lastStart = 0;
  var pumpTimer = null;
  var parallelNow = PARALLEL;

  function pump() {
    if (stopped) { return; }

    if (index >= pending.length) {
      if (inFlight === 0) { finish("durchgelaufen"); }
      return;
    }

    while (inFlight < parallelNow && index < pending.length) {
      var wait = (1000 / RATE) - (Date.now() - lastStart);
      if (wait > 0) {
        if (!pumpTimer) {
          pumpTimer = setTimeout(function () { pumpTimer = null; pump(); }, wait);
        }
        return;
      }
      lastStart = Date.now();
      launch(pending[index]);
      index++;
    }
  }

  /* Wenn der Server Challenge-Seiten liefert, ist er ueberlastet. Dann
     runter mit der Parallelitaet statt stur weiterzuhaemmern. */
  function throttleDown(why) {
    if (parallelNow <= 1) { return; }
    parallelNow--;
    console.warn("[BLL] " + why + " - reduziere auf " + parallelNow
      + " gleichzeitige Anfragen.");
  }

  function launch(item) {
    inFlight++;
    var handled = false;

    function settle(fn) {
      return function (x) {
        if (handled) { return; }
        handled = true;
        try { fn(x); } catch (e) { console.warn("[BLL] Auswertungsfehler:", e); }
        inFlight--;
        lastActivity = Date.now();
        pump();
      };
    }

    try {
      fetch("?item=" + item.id, { credentials: "same-origin" })
        .then(function (resp) {
          if (!resp.ok) { throw new Error("HTTP " + resp.status); }
          return resp.text();
        })
        .then(settle(function (html) {
          var wrong = looksWrong(html);
          if (wrong) {
            challenged++;
            retry.push(item);
            if (challenged <= 3) {
              console.warn("[BLL] Item " + item.id + ": " + wrong
                + " statt Itemseite. Kommt spaeter nochmal dran.");
            }
            if (challenged % 5 === 0) { throttleDown("Challenge-Seiten"); }
            return;
          }

          cache[item.id] = parseItemPage(html, item.id, item.slot);
          done++;

          if (done === 1) {
            console.log("[BLL] Erstes Ergebnis (bitte pruefen):", cache[item.id]);
            var anyStat = false;
            for (var k in cache[item.id].stats) { anyStat = true; break; }
            if (!anyStat && !cache[item.id].jsonequip) {
              console.warn("[BLL] Keine Werte erkannt. Abbruch empfohlen "
                + "(BLL.stop()) - die Muster passen nicht zur Seite.");
            }
          }

          if (done % 20 === 0) {
            persist();
            var secs = (Date.now() - startedAt) / 1000;
            console.log("[BLL] " + done + "/" + pending.length
              + " (" + Math.round(done / pending.length * 100) + "%) - "
              + (done / secs).toFixed(1) + " Items/s, noch ca. "
              + Math.ceil((pending.length - done) / (done / secs) / 60) + " min");
          }
        }))
        .catch(settle(function (err) {
          failed++;
          retry.push(item);
          if (failed <= 5) {
            console.warn("[BLL] Item " + item.id + " fehlgeschlagen:",
              err && err.message ? err.message : err);
          }
          if (failed % 5 === 0) { throttleDown("Fehlschlaege"); }
        }));
    } catch (e) {
      failed++;
      inFlight--;
      console.warn("[BLL] Anfrage nicht moeglich:", e);
      lastActivity = Date.now();
      pump();
    }
  }

  /* Wachhund: falls zwanzig Sekunden lang nichts passiert, wieder
     anschieben. Fruehere Laeufe sind stillschweigend stehengeblieben -
     eine haengende Anfrage reicht dafuer aus. */
  watchdog = setInterval(function () {
    if (stopped) { return; }
    if (Date.now() - lastActivity < 20000) { return; }

    /* Haengende Anfragen geben ihr settle() nie zurueck, also bleibt
       inFlight zu hoch stehen und der Pool verhungert. Zuruecksetzen. */
    if (inFlight > 0) {
      console.warn("[BLL] 20s ohne Antwort - " + inFlight
        + " haengende Anfrage(n) werden aufgegeben.");
      inFlight = 0;
    }

    if (index >= pending.length && !retry.length) {
      finish("Wachhund: alles angestossen");
      return;
    }

    lastActivity = Date.now();
    pump();
  }, 5000);

  console.log("[BLL] Befehle: BLL.status() Stand | BLL.save() jetzt "
    + "herunterladen | BLL.stop() abbrechen");

  pump();
})();
