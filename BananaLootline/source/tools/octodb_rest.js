/* ===========================================================================
   BananaLootline - Restliche Ruestung holen

   SO GEHT ES:
     1. octowow.st/db oeffnen (irgendeine Seite).
     2. F12, Reiter "Konsole".
     3. Diese Datei komplett einfuegen, Enter.
     4. Warten. Am Ende laedt eine JSON-Datei herunter.

   Mehr ist nicht zu tun. Keine Variablen setzen, keinen Filter klicken.

   WAS GEHOLT WIRD
     Stoff, Kette, Platte - je acht Slots plus Roben
     Schilde
     Leder ist NICHT dabei, das ist bereits fertig.

   WAEHREND ES LAEUFT (optional, in die Konsole)
     BLL.status()   zeigt den Stand
     BLL.save()     laedt sofort herunter, was bisher da ist
     BLL.stop()     bricht ab

   WICHTIG
     Tab offen lassen. Neuladen ist ok, Schliessen loescht den
     Zwischenstand. Nach einem Abbruch einfach im selben Tab erneut
     einfuegen - es macht dort weiter, wo es aufgehoert hat.

     Jeder Slot wird einzeln abgefragt, damit keine Liste an die
     Grenze von 500 Eintraegen stoesst. Passiert es doch, warnt das
     Skript - dann bitte melden.
=========================================================================== */

(function () {
  "use strict";

  var SLOTS = (typeof BLL_SLOTS !== "undefined" && BLL_SLOTS.length) ? BLL_SLOTS : [
    /* Stoff */
    "4.1.1", "4.1.3", "4.1.5", "4.1.20", "4.1.6", "4.1.7", "4.1.8", "4.1.9", "4.1.10",
    /* Kette */
    "4.3.1", "4.3.3", "4.3.5", "4.3.20", "4.3.6", "4.3.7", "4.3.8", "4.3.9", "4.3.10",
    /* Platte */
    "4.4.1", "4.4.3", "4.4.5", "4.4.20", "4.4.6", "4.4.7", "4.4.8", "4.4.9", "4.4.10",
    /* Schilde */
    "4.6.14"
  ];

  var RATE        = (typeof BLL_RATE === "number") ? BLL_RATE : 4;
  var PARALLEL    = (typeof BLL_PARALLEL === "number") ? BLL_PARALLEL : 6;
  var MIN_QUALITY = (typeof BLL_MIN_QUALITY === "number") ? BLL_MIN_QUALITY : 2;

  /* Wird an jede Listen-URL angehaengt. Damit lassen sich die Attribut-
     spalten erzwingen - und dann braucht es KEINE Einzelseiten mehr.
     Siehe Kopfkommentar "ANFRAGEN SPAREN". */
  var LIST_SUFFIX = (typeof BLL_LIST_SUFFIX === "string") ? BLL_LIST_SUFFIX : "";

  var STORE_KEY = "bll_batch_cache";
  var LIST_KEY  = "bll_batch_lists";

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
     Listenseiten holen und ihre Daten herausschneiden

     Das Listview steckt als JavaScript-Array im HTML der Seite. Wir
     holen die Seite per fetch und schneiden das Array heraus - dieselbe
     Klammerzaehlung wie im Einzelskript.
  ------------------------------------------------------------------ */

  function extractArrays(text) {
    var out = [], marker = /data\s*:\s*\[/g, m;
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
          else if (ch === "]") { depth--; if (depth === 0) { out.push(text.slice(start, i + 1)); break; } }
        }
        i++;
      }
    }
    return out;
  }

  function parseListPage(html) {
    var blobs = extractArrays(html);
    for (var b = 0; b < blobs.length; b++) {
      try {
        var arr = eval("(" + blobs[b] + ")");
        if (!arr || !arr.length) { continue; }
        var hasSlot = false;
        for (var i = 0; i < Math.min(arr.length, 50); i++) {
          if (arr[i] && arr[i].slot !== undefined) { hasSlot = true; break; }
        }
        if (hasSlot) { return arr; }
      } catch (e) { /* naechster */ }
    }
    return null;
  }

  /* ------------------------------------------------------------------
     Zustand
  ------------------------------------------------------------------ */

  var cache = {}, lists = {};
  try { cache = JSON.parse(sessionStorage.getItem(STORE_KEY) || "{}"); } catch (e) { cache = {}; }
  try { lists = JSON.parse(sessionStorage.getItem(LIST_KEY)  || "{}"); } catch (e) { lists = {}; }

  var todo = [], pending = [], retry = [];
  var stopped = false, done = 0, failed = 0, challenged = 0, index = 0;
  var inFlight = 0, lastStart = 0, pumpTimer = null, parallelNow = PARALLEL;
  var lastActivity = Date.now(), startedAt = Date.now(), watchdog = null;
  var retryRound = 0;

  function persist() {
    try {
      sessionStorage.setItem(STORE_KEY, JSON.stringify(cache));
      sessionStorage.setItem(LIST_KEY, JSON.stringify(lists));
    } catch (e) { console.warn("[BLL] Zwischenspeichern fehlgeschlagen:", e); }
  }

  function looksWrong(html) {
    if (!html || html.length < 500) { return "zu kurz"; }
    if (/Verifying your browser|DDoS Protection|Just a moment/i.test(html)) { return "DDoS-Pruefung"; }
    if (/<title>\s*(404|403|500|Error)/i.test(html)) { return "Fehlerseite"; }
    return null;
  }

  function download(obj, prefix) {
    var blob = new Blob([JSON.stringify(obj)], { type: "application/json" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url; a.download = prefix + "_" + Date.now() + ".json";
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  /* ------------------------------------------------------------------
     Phase 1: alle Listen einsammeln
  ------------------------------------------------------------------ */

  function loadLists(done_cb) {
    var i = 0;
    function next() {
      if (i >= SLOTS.length) { done_cb(); return; }
      var filter = SLOTS[i]; i++;

      if (lists[filter + LIST_SUFFIX]) {
        console.log("[BLL] " + filter + ": "
          + lists[filter + LIST_SUFFIX].length + " Items (aus Cache)");
        setTimeout(next, 0);
        return;
      }

      fetch("?items=" + filter + LIST_SUFFIX, { credentials: "same-origin" })
        .then(function (r) { if (!r.ok) { throw new Error("HTTP " + r.status); } return r.text(); })
        .then(function (html) {
          var wrong = looksWrong(html);
          if (wrong) { throw new Error(wrong); }
          var rows = parseListPage(html);
          if (!rows) { throw new Error("keine Itemliste im HTML"); }
          lists[filter + LIST_SUFFIX] = rows;
          persist();

          /* Runde Zahlen sind verdaechtig: Listenansichten werden oft bei
             50, 100, 200 oder 500 Zeilen gekappt. Dann fehlen Items, ohne
             dass irgendetwas nach Fehler aussieht - der schlimmste Fall,
             weil man es erst Wochen spaeter merkt. */
          var CAPS = { 50:1, 100:1, 150:1, 200:1, 250:1, 500:1, 1000:1 };
          if (CAPS[rows.length]) {
            console.warn("[BLL] " + filter + ": genau " + rows.length
              + " Items - das ist verdaechtig glatt. Moeglicherweise ist die "
              + "Liste gekappt und es fehlen Items. Pruef die Seite: steht "
              + "dort eine hoehere Gesamtzahl, den Slot zusaetzlich nach "
              + "Qualitaet aufteilen.");
          } else {
            console.log("[BLL] " + filter + ": " + rows.length + " Items");
          }
        })
        .catch(function (e) {
          console.warn("[BLL] " + filter + " uebersprungen: "
            + (e && e.message ? e.message : e));
        })
        .then(function () { setTimeout(next, 1000 / RATE); });
    }
    next();
  }

  /* ------------------------------------------------------------------
     Statfelder direkt aus einer Listenzeile lesen

     Wenn die Tabelle die Attributspalten fuehrt, stehen die Werte schon
     in den Listendaten. Dann ist die Einzelseite ueberfluessig - und aus
     rund 1600 Anfragen werden acht.
  ------------------------------------------------------------------ */

  var LIST_KEYMAP = {
    str: "STR", agi: "AGI", sta: "STA", int: "INT", spi: "SPI",
    armor: "ARMOR", dps: "WEAPON_DPS", mledps: "WEAPON_DPS",
    speed: "WEAPON_SPEED",
    atkpwr: "AP", mleatkpwr: "AP", rgdatkpwr: "RAP",
    spldmg: "SPELLPOWER", splheal: "HEALPOWER",
    critstrkrtng: "CRIT", splcritstrkrtng: "SPELLCRIT",
    hitrtng: "HIT", splhitrtng: "SPELLHIT",
    defrtng: "DEFENSE", dodgertng: "DODGE", parryrtng: "PARRY",
    blockrtng: "BLOCK", manargn: "MP5", healthrgn: "HP5",
    fireres: "RES_FIRE", frostres: "RES_FROST", natres: "RES_NATURE",
    shadowres: "RES_SHADOW", arcres: "RES_ARCANE"
  };

  /* Zaehlt nur, was ueber die Ruestung hinausgeht - armor allein steht
     auch in der Standardansicht und beweist nichts. */
  function statsFromRow(row) {
    var stats = {}, extra = 0;
    for (var k in LIST_KEYMAP) {
      var v = row[k];
      if (typeof v === "number" && v !== 0) {
        stats[LIST_KEYMAP[k]] = v;
        if (k !== "armor") { extra++; }
      }
    }
    return { stats: stats, extra: extra };
  }

  /* ------------------------------------------------------------------
     Phase 2: Details holen - nur fuer Items, deren Werte die Liste
     nicht schon mitgebracht hat
  ------------------------------------------------------------------ */

  function buildTodo() {
    todo = []; var skipped = 0, seen = {};

    for (var s = 0; s < SLOTS.length; s++) {
      var rows = lists[SLOTS[s] + LIST_SUFFIX];
      if (!rows) { continue; }

      for (var r = 0; r < rows.length; r++) {
        var row = rows[r];
        if (!row || row.id == null || seen[row.id]) { continue; }
        seen[row.id] = true;

        var sn = splitName(row.name);
        var quality = (row.quality !== undefined) ? row.quality : sn.quality;
        if (MIN_QUALITY > 0 && quality !== null && quality < MIN_QUALITY) { skipped++; continue; }

        todo.push({
          id: row.id, name: sn.name, quality: quality, level: row.level,
          reqlevel: row.reqlevel, slot: row.slot, classs: row.classs,
          subclass: row.subclass, armor: row.armor, filter: SLOTS[s],
          row: row
        });
      }
    }

    /* Werte, die schon in der Liste stehen, direkt uebernehmen. */
    var fromList = 0;
    for (var f = 0; f < todo.length; f++) {
      var it = todo[f];
      if (cache[it.id]) { continue; }
      if (!it.row) { continue; }

      var r = statsFromRow(it.row);
      if (r.extra > 0) {
        cache[it.id] = {
          id: it.id,
          stats: r.stats,
          reqlevel: it.reqlevel,
          fromList: 1
        };
        fromList++;
      }
    }
    if (fromList) { persist(); }

    pending = [];
    for (var t = 0; t < todo.length; t++) {
      if (!cache[todo[t].id]) { pending.push(todo[t]); }
    }

    console.log("[BLL] Gesamt " + todo.length + " Items, " + skipped
      + " durch Vorfilter aussortiert.");
    if (fromList) {
      console.log("[BLL] " + fromList + " Items komplett aus der Liste - "
        + "keine Einzelseite noetig. Das ist der Sparweg.");
    } else if (!LIST_SUFFIX) {
      console.log("[BLL] Die Liste fuehrt keine Attributspalten. Es braucht "
        + "daher eine Einzelseite pro Item. Mit BLL_LIST_SUFFIX liesse sich "
        + "das auf acht Anfragen druecken - siehe Kopfkommentar.");
    }
    console.log("[BLL] " + (todo.length - pending.length) + " fertig, "
      + pending.length + " Einzelseiten offen.");
    if (pending.length) {
      console.log("[BLL] Bei " + PARALLEL + " parallelen Anfragen etwa "
        + Math.ceil(pending.length / (PARALLEL / 2) / 60) + " Minuten.");
    }
  }

  function pump() {
    if (stopped) { return; }
    if (index >= pending.length) { if (inFlight === 0) { finish("durchgelaufen"); } return; }

    while (inFlight < parallelNow && index < pending.length) {
      var wait = (1000 / RATE) - (Date.now() - lastStart);
      if (wait > 0) {
        if (!pumpTimer) { pumpTimer = setTimeout(function () { pumpTimer = null; pump(); }, wait); }
        return;
      }
      lastStart = Date.now();
      launch(pending[index]);
      index++;
    }
  }

  function throttleDown(why) {
    if (parallelNow <= 1) { return; }
    parallelNow--;
    console.warn("[BLL] " + why + " - reduziere auf " + parallelNow + " gleichzeitige Anfragen.");
  }

  function launch(item) {
    inFlight++;
    var handled = false;

    function settle(fn) {
      return function (x) {
        if (handled) { return; }
        handled = true;
        try { fn(x); } catch (e) { console.warn("[BLL] Auswertungsfehler:", e); }
        inFlight--; lastActivity = Date.now(); pump();
      };
    }

    fetch("?item=" + item.id, { credentials: "same-origin" })
      .then(function (r) { if (!r.ok) { throw new Error("HTTP " + r.status); } return r.text(); })
      .then(settle(function (html) {
        var wrong = looksWrong(html);
        if (wrong) {
          challenged++; retry.push(item);
          if (challenged <= 3) { console.warn("[BLL] Item " + item.id + ": " + wrong); }
          if (challenged % 5 === 0) { throttleDown("Challenge-Seiten"); }
          return;
        }
        cache[item.id] = parseItemPage(html, item.id, item.slot);
        done++;

        if (done === 1) { console.log("[BLL] Erstes Ergebnis:", cache[item.id]); }
        if (done % 25 === 0) {
          persist();
          var secs = (Date.now() - startedAt) / 1000;
          console.log("[BLL] " + done + "/" + pending.length + " ("
            + Math.round(done / pending.length * 100) + "%) - "
            + (done / secs).toFixed(1) + " Items/s, noch ca. "
            + Math.ceil((pending.length - done) / (done / secs) / 60) + " min");
        }
      }))
      .catch(settle(function (err) {
        failed++; retry.push(item);
        if (failed <= 5) { console.warn("[BLL] Item " + item.id + " fehlgeschlagen:",
          err && err.message ? err.message : err); }
        if (failed % 5 === 0) { throttleDown("Fehlschlaege"); }
      }));
  }

  /* ------------------------------------------------------------------
     Ausgabe: eine Datei pro Slot, damit der Importer sie einzeln
     pruefen kann - plus eine Gesamtdatei
  ------------------------------------------------------------------ */

  function buildPayload() {
    var items = [], byFilter = {};

    for (var i = 0; i < todo.length; i++) {
      var base = todo[i], detail = cache[base.id];
      if (!detail) { continue; }

      var merged = {
        id: base.id, name: base.name, quality: base.quality, level: base.level,
        slot: base.slot, classs: base.classs, subclass: base.subclass
      };
      if (detail.fromList) { merged.source = "list"; }
      if (base.armor !== undefined) { merged.armor = base.armor; }
      merged.reqlevel = (detail.reqlevel !== undefined) ? detail.reqlevel : base.reqlevel;
      if (detail.classmask !== undefined) { merged.classmask = detail.classmask; }
      if (detail.racemask !== undefined) { merged.racemask = detail.racemask; }
      merged.stats = detail.stats || {};

      items.push(merged);
      byFilter[base.filter] = (byFilter[base.filter] || 0) + 1;
    }

    return {
      exported: new Date().toISOString(),
      url: location.href,
      source: "item-detail-pages",
      slots: SLOTS,
      perFilter: byFilter,
      complete: (items.length === todo.length),
      expected: todo.length,
      count: items.length,
      items: items
    };
  }

  function finish(reason) {
    if (retry.length && retryRound < 2 && !stopped) {
      retryRound++;
      pending = retry; retry = []; index = 0; parallelNow = 1;
      console.log("[BLL] Nachlauf " + retryRound + ": " + pending.length
        + " Items nochmal, einzeln und langsam.");
      setTimeout(pump, 3000);
      return;
    }

    if (watchdog) { clearInterval(watchdog); watchdog = null; }
    persist();

    var p = buildPayload();
    console.log("[BLL] Ende (" + reason + "). " + p.count + " von " + p.expected
      + " Items. Fehlgeschlagen: " + failed + ", Challenge-Seiten: " + challenged);
    console.log("[BLL] Pro Filter:", p.perFilter);

    var leer = [];
    for (var q = 0; q < SLOTS.length; q++) {
      if (!p.perFilter[SLOTS[q]]) { leer.push(SLOTS[q]); }
    }
    if (leer.length) {
      console.warn("[BLL] Ohne Treffer geblieben: " + leer.join(", ")
        + " - entweder gibt es dort nichts (bei .20 normal) oder die "
        + "Filternummer stimmt nicht.");
    }
    if (!p.complete) {
      console.warn("[BLL] Unvollstaendig. Im selben Tab erneut ausfuehren, "
        + "die fehlenden werden nachgeholt.");
    }
    download(p, "octodb_batch");
  }

  window.BLL = window.BLL || {};
  window.BLL.stop = function () {
    stopped = true;
    if (watchdog) { clearInterval(watchdog); watchdog = null; }
    console.log("[BLL] Abbruch. " + done + " geholt. BLL.save() laedt sie herunter.");
  };
  window.BLL.status = function () {
    console.log("[BLL] " + index + "/" + pending.length + " angestossen, " + done
      + " erfolgreich, " + failed + " fehlgeschlagen, " + challenged
      + " Challenge-Seiten, " + parallelNow + " parallel, "
      + Math.round((Date.now() - lastActivity) / 1000) + "s seit letzter Antwort.");
  };
  window.BLL.save = function () { persist(); var p = buildPayload();
    console.log("[BLL] " + p.count + "/" + p.expected + " gespeichert"
      + (p.complete ? "" : " (UNVOLLSTAENDIG)")); download(p, "octodb_batch"); return p.count; };

  watchdog = setInterval(function () {
    if (stopped) { return; }
    if (Date.now() - lastActivity < 20000) { return; }
    if (inFlight > 0) {
      console.warn("[BLL] 20s ohne Antwort - " + inFlight + " haengende Anfrage(n) aufgegeben.");
      inFlight = 0;
    }
    if (index >= pending.length && !retry.length) { finish("Wachhund"); return; }
    lastActivity = Date.now();
    pump();
  }, 5000);

  console.log("[BLL] Hole " + SLOTS.length + " Listen ...");
  loadLists(function () {
    buildTodo();
    startedAt = Date.now();
    if (!pending.length) { finish("nichts offen"); return; }
    console.log("[BLL] Befehle: BLL.status() | BLL.save() | BLL.stop()");
    pump();
  });
})();
