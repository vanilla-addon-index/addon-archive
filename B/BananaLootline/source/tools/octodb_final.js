/* ===========================================================================
   BananaLootline - Waffen, Relikte und die Nachlese

   SO GEHT ES:
     1. octowow.st/db oeffnen.
     2. F12, Reiter "Konsole".
     3. Diese Datei komplett einfuegen, Enter.

   Das laeuft laenger als die bisherigen Durchgaenge - Waffen sind eine
   grosse Gruppe. Zwischendurch ruhig BLL.save() druecken, dann liegt ein
   Zwischenstand auf der Platte.

   WAS SICH GEGENUEBER DEM LETZTEN LAUF GEAENDERT HAT

   Relikte: liefen mit 4.0.28 ins Leere ("keine Itemliste im HTML").
   Libramme, Idole und Totems sind in Vanilla eigene Subklassen der
   Ruestung - 4.7, 4.8 und 4.9 - und kein Slot.

   Gekappte Listen: die 500er-Ringliste kam aus dem Zwischenspeicher des
   vorherigen Laufs, deshalb lief die Kappungspruefung nie an. Jetzt
   werden auch zwischengespeicherte Listen geprueft.

   Use-Effekte: wurden gar nicht gefunden, weil das Muster innerhalb
   einer Zeile suchte und der Tooltip "Use:" und den Text auf mehrere
   Elemente verteilt. Der Text wird jetzt vorher zusammengezogen.

   Qualitaet: die Praefixziffer 0 fehlte in der Tabelle - dadurch blieben
   71 Items ohne Qualitaet und mit Ziffer im Namen.

   Weil sich die Auswertung geaendert hat, werden auch bereits geholte
   Items dieser Slots noch einmal geholt. Rein zwischengespeicherte
   Ergebnisse der alten Fassung waeren sonst luecken- und fehlerhaft.

   WAEHREND ES LAEUFT
     BLL.status()   Stand      BLL.save()   jetzt herunterladen
     BLL.stop()     abbrechen
=========================================================================== */

(function () {
  "use strict";

  var SLOTS = (typeof BLL_SLOTS !== "undefined" && BLL_SLOTS.length) ? BLL_SLOTS : [
    /* Waffen - Itemklasse 2. Subklassen nach Vanilla-Schema.
       Grosse Gruppen wie Schwerter stossen an die 500er-Grenze;
       das Skript teilt sie dann selbst nach Qualitaet auf. */
    "2.15",  /* Dolche        */
    "2.7",   /* Schwert 1H    */
    "2.8",   /* Schwert 2H    */
    "2.0",   /* Axt 1H        */
    "2.1",   /* Axt 2H        */
    "2.4",   /* Streitkolben 1H */
    "2.5",   /* Streitkolben 2H */
    "2.6",   /* Stangenwaffe  */
    "2.10",  /* Stab          */
    "2.13",  /* Faustwaffe    */
    "2.2",   /* Bogen         */
    "2.18",  /* Armbrust      */
    "2.3",   /* Schusswaffe   */
    "2.16",  /* Wurfwaffe     */
    "2.19",  /* Zauberstab    */

    /* Relikte - eigene Subklassen der Ruestung, NICHT Slot 28.
       Der letzte Lauf lief mit 4.0.28 ins Leere. */
    "4.7",   /* Libramme */
    "4.8",   /* Idole    */
    "4.9",   /* Totems   */

    /* Zubehoer erneut: Ringe und Umhaenge waren gekappt, bei allen
       fehlen die Use-Effekte. */
    "4.0.11", "4.1.16", "4.0.12", "4.0.2", "4.0.23"
  ];

  var RATE        = (typeof BLL_RATE === "number") ? BLL_RATE : 4;
  var PARALLEL    = (typeof BLL_PARALLEL === "number") ? BLL_PARALLEL : 6;
  var MIN_QUALITY = (typeof BLL_MIN_QUALITY === "number") ? BLL_MIN_QUALITY : 2;

  /* Wird an jede Listen-URL angehaengt. Damit lassen sich die Attribut-
     spalten erzwingen - und dann braucht es KEINE Einzelseiten mehr.
     Siehe Kopfkommentar "ANFRAGEN SPAREN". */
  var LIST_SUFFIX = (typeof BLL_LIST_SUFFIX === "string") ? BLL_LIST_SUFFIX : "";

  /* Wird in jeden Cache-Eintrag geschrieben. Aeltere Eintraege stammen
     aus einer Fassung ohne Effekterkennung und werden neu geholt. */
  var PARSER_VERSION = 3;

  var STORE_KEY = "bll_batch_cache";
  var LIST_KEY  = "bll_batch_lists";

  /* Qualitaet = 6 minus Praefixziffer. Das "0" fehlte bisher und liess
     71 Items mit Ziffer im Namen und ohne Qualitaet zurueck. */
  var PREFIX_QUALITY = { "0": 6, "1": 5, "2": 4, "3": 3, "4": 2, "5": 1, "6": 0 };

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

    /* Weg 2: Tooltiptext auswerten.

       Alles auf EINE Zeile zusammenziehen. Der Tooltip verteilt "Use:"
       und den zugehoerigen Text oft auf mehrere HTML-Elemente, wodurch
       ein Zeilenumbruch dazwischen liegt. Zeilenweise Muster finden dann
       nichts - genau daran sind die Use-Effekte bisher gescheitert. */
    var text = htmlToText(html).replace(/\s+/g, " ");

    /* ----------------------------------------------------------------
       Schritt 1: Use- und Equip-Effekte

       MUSS vor der Statauswertung laufen, weil die gefundenen Use-Texte
       danach aus dem Statbereich entfernt werden.

       Ein Use-Effekt laesst sich nicht mit festen Werten verrechnen:
       "+100 Angriffskraft fuer 20 Sek, alle 2 Min" sind im Schnitt rund
       16 Angriffskraft, nicht 100. Wert, Dauer und Abklingzeit werden
       deshalb GETRENNT gespeichert - die Umrechnung macht das Addon.
    ---------------------------------------------------------------- */
    var effects = [];

    /* Erst grosszuegig greifen, dann zuschneiden. Ein frueherer Ansatz
       verlangte hinter dem Effekttext ein Schluesselwort wie "Requires".
       Fehlt das - etwa weil das Item keine Stufenanforderung hat - fand
       das Muster gar nichts. Ein Effekt braucht aber kein Ende, um
       gueltig zu sein. */
    var STOPS = ["Use:", "Equip:", "Chance on hit:", "Requires ", "Durability ",
                 "Sell Price", "Sells for", "Classes:", "Races:", "Item Level",
                 "Quick Facts", "Added in", "Comments", "Related", "Screenshots"];

    var effRe = /\b(Use|Equip|Chance on hit):\s*(.{4,300})/gi;
    var em;
    while ((em = effRe.exec(text)) !== null) {
      var kind = em[1].toLowerCase().replace(/\s+/g, "");
      var chunk = em[2];

      var cut = chunk.length;
      for (var si = 0; si < STOPS.length; si++) {
        var at = chunk.indexOf(STOPS[si]);
        if (at > 0 && at < cut) { cut = at; }
      }
      var trimmed = chunk.slice(0, cut);

      /* Kein Schluesselwort gefunden: am letzten Satzende kappen, damit
         kein Seitenrauschen anhaengt. */
      if (cut === chunk.length) {
        var dot = trimmed.lastIndexOf(". ");
        if (dot > 10) { trimmed = trimmed.slice(0, dot + 1); }
      }

      /* Die Suche hinter dem ZUGESCHNITTENEN Text fortsetzen, nicht
         hinter den grosszuegig gegriffenen 300 Zeichen. Sonst
         verschluckt ein Equip-Treffer den direkt folgenden Use-Effekt. */
      effRe.lastIndex = em.index + (em[0].length - chunk.length) + trimmed.length;

      var line = trimmed.replace(/\s+/g, " ").trim();
      if (line.length < 4) { continue; }

      var eff = { kind: kind, text: line };

      var v = line.match(/\bby (?:up to )?(\d+)/i)
           || line.match(/\b(?:Restores|Deals|Heals|Absorbs)\s+(\d+)/i)
           || line.match(/\b(\d+)\s*%/);
      if (v) { eff.value = parseInt(v[1], 10); }

      var dur = line.match(/for (\d+)\s*(sec|min)/i);
      if (dur) { eff.duration = parseInt(dur[1], 10) * (/min/i.test(dur[2]) ? 60 : 1); }

      var icd = line.match(/\((\d+)\s*(Min|Sec)\s*Cooldown\)/i);
      if (icd) { eff.cooldown = parseInt(icd[1], 10) * (/min/i.test(icd[2]) ? 60 : 1); }

      effects.push(eff);
    }

    /* Abklingzeit steht haeufig in einer eigenen Zeile statt im Effekttext */
    var cd = text.match(/\((\d+)\s*(Min|Sec)\s*Cooldown\)/i)
          || text.match(/Cooldown:\s*(\d+)\s*(min|sec)/i);
    if (cd) {
      var secs = parseInt(cd[1], 10) * (/min/i.test(cd[2]) ? 60 : 1);
      for (var ei = 0; ei < effects.length; ei++) {
        if (effects[ei].kind === "use" && !effects[ei].cooldown) {
          effects[ei].cooldown = secs;
        }
      }
    }

    if (effects.length) { out.effects = effects; }

    /* ----------------------------------------------------------------
       Schritt 2: feste Werte

       Zeitweise Effekte vorher herausschneiden. Sonst landet
       "Use: Increases attack power by 100 for 20 sec" als dauerhafte
       +100 Angriffskraft in den Stats und das Item wird masslos
       ueberbewertet. Equip-Zeilen bleiben stehen, die wirken dauerhaft.
    ---------------------------------------------------------------- */
    var statText = text;
    for (var ci = 0; ci < effects.length; ci++) {
      if (effects[ci].kind === "use" || effects[ci].kind === "chanceonhit") {
        var pos = statText.indexOf(effects[ci].text);
        if (pos !== -1) {
          statText = statText.slice(0, pos) + " "
                   + statText.slice(pos + effects[ci].text.length);
        }
      }
    }

    for (var p = 0; p < PATTERNS.length; p++) {
      var key = PATTERNS[p][0];
      if (out.stats[key] !== undefined) { continue; }
      var m = statText.match(PATTERNS[p][1]);
      if (m) { out.stats[key] = parseFloat(m[1]); }
    }

    /* Schadensbereich nur bei Waffen. Auf Ruestung stammt eine solche
       Zeile aus einem Proc-Text und ist kein Grundschaden. */
    if (WEAPON_SLOTS[slot]) {
      var dm = statText.match(DMG_PATTERN);
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
    while ((sm = SCHOOL_PATTERN.exec(statText)) !== null) {
      out.stats["SPELLPOWER_" + sm[1].toUpperCase()] = parseInt(sm[2], 10);
    }

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

  /* ------------------------------------------------------------------
     Gekappte Listen aufteilen

     Die Seite liefert hoechstens 500 Zeilen. Bei Ringen und Umhaengen
     reicht das nicht. Aufteilen nach Qualitaet loest das - nur kenne ich
     die Filtersyntax dieses Forks nicht.

     Also wird sie ausprobiert statt geraten: mehrere Kandidaten testen
     und pruefen, ob das Ergebnis wirklich nur die gewuenschte Qualitaet
     enthaelt. Die Qualitaet steckt als Ziffer vor dem Namen, ist also
     ohne Zusatzabfrage pruefbar.
  ------------------------------------------------------------------ */

  var CAP = 500;
  var QUALITY_SYNTAX = [
    function (q) { return "&filter=qu=" + q; },
    function (q) { return "&qu=" + q; },
    function (q) { return "&filter=qu:" + q; }
  ];
  var workingSyntax = null;

  function rowsQuality(rows) {
    var seen = {};
    for (var i = 0; i < rows.length; i++) {
      var sn = splitName(rows[i].name);
      var q = (rows[i].quality !== undefined) ? rows[i].quality : sn.quality;
      if (q !== null && q !== undefined) { seen[q] = 1; }
    }
    return Object.keys(seen);
  }

  function fetchList(url) {
    return fetch(url, { credentials: "same-origin" })
      .then(function (r) { if (!r.ok) { throw new Error("HTTP " + r.status); } return r.text(); })
      .then(function (html) {
        var wrong = looksWrong(html);
        if (wrong) { throw new Error(wrong); }
        var rows = parseListPage(html);
        if (!rows) { throw new Error("keine Itemliste im HTML"); }
        return rows;
      });
  }

  /* Probiert die Syntaxkandidaten an einem Filter durch. */
  function probeSyntax(filter, cb) {
    var si = 0;
    function tryNext() {
      if (si >= QUALITY_SYNTAX.length) {
        console.warn("[BLL] Keine Qualitaetssyntax hat funktioniert. " + filter
          + " bleibt bei " + CAP + " Eintraegen - es fehlen Items.");
        cb(null);
        return;
      }
      var mk = QUALITY_SYNTAX[si]; si++;
      fetchList("?items=" + filter + mk(4))
        .then(function (rows) {
          var qs = rowsQuality(rows);
          if (rows.length && rows.length < CAP && qs.length === 1 && qs[0] === "4") {
            console.log("[BLL] Qualitaetsfilter erkannt: " + mk(4)
              + " (" + rows.length + " epische Treffer)");
            workingSyntax = mk;
            cb(mk);
          } else {
            setTimeout(tryNext, 1000 / RATE);
          }
        })
        .catch(function () { setTimeout(tryNext, 1000 / RATE); });
    }
    tryNext();
  }

  /* Holt einen gekappten Filter in Qualitaetsstufen nach. */
  function splitByQuality(filter, mk, cb) {
    var quals = [0, 1, 2, 3, 4, 5], qi = 0, all = {}, total = 0;

    function nextQ() {
      if (qi >= quals.length) {
        var merged = [];
        for (var id in all) { merged.push(all[id]); }
        console.log("[BLL] " + filter + ": " + merged.length
          + " Items nach Aufteilung (vorher " + CAP + ")");
        cb(merged);
        return;
      }
      var q = quals[qi]; qi++;

      fetchList("?items=" + filter + mk(q))
        .then(function (rows) {
          for (var i = 0; i < rows.length; i++) {
            if (rows[i] && rows[i].id != null) { all[rows[i].id] = rows[i]; }
          }
          total += rows.length;
          if (rows.length >= CAP) {
            console.warn("[BLL] " + filter + " Qualitaet " + q + ": immer noch "
              + rows.length + " - auch hier fehlen moeglicherweise Items.");
          }
        })
        .catch(function (e) {
          console.warn("[BLL] " + filter + " Qualitaet " + q + ": "
            + (e && e.message ? e.message : e));
        })
        .then(function () { setTimeout(nextQ, 1000 / RATE); });
    }
    nextQ();
  }

  var capped = [];

  function loadLists(done_cb) {
    var i = 0;
    function next() {
      if (i >= SLOTS.length) { handleCapped(done_cb); return; }
      var filter = SLOTS[i]; i++;

      var cachedList = lists[filter + LIST_SUFFIX];
      if (cachedList) {
        /* Auch zwischengespeicherte Listen pruefen. Genau hier ist der
           letzte Lauf gescheitert: die gekappte 500er-Ringliste kam aus
           dem Cache, also lief die Pruefung nie an. */
        if (cachedList.length >= CAP) {
          console.warn("[BLL] " + filter + ": " + cachedList.length
            + " Eintraege aus dem Cache - an der Obergrenze. Teile auf ...");
          capped.push(filter);
        } else {
          console.log("[BLL] " + filter + ": " + cachedList.length
            + " Items (aus Cache)");
        }
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
          if (rows.length >= CAP) {
            console.warn("[BLL] " + filter + ": " + rows.length
              + " Eintraege - das ist die Obergrenze. Teile nach Qualitaet auf ...");
            capped.push(filter);
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

  /* Gekappte Filter nachbearbeiten: Syntax ermitteln, dann aufteilen. */
  function handleCapped(cb) {
    if (!capped.length) { cb(); return; }

    var ci = 0;
    function nextCapped() {
      if (ci >= capped.length) { cb(); return; }
      var filter = capped[ci]; ci++;

      function withSyntax(mk) {
        if (!mk) { setTimeout(nextCapped, 0); return; }
        splitByQuality(filter, mk, function (merged) {
          if (merged && merged.length) {
            lists[filter + LIST_SUFFIX] = merged;
            persist();
          }
          setTimeout(nextCapped, 1000 / RATE);
        });
      }

      if (workingSyntax) { withSyntax(workingSyntax); }
      else { probeSyntax(filter, withSyntax); }
    }
    nextCapped();
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
      var c = cache[todo[t].id];
      if (!c || c.v !== PARSER_VERSION) { pending.push(todo[t]); }
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
        var parsed = parseItemPage(html, item.id, item.slot);
        parsed.v = PARSER_VERSION;
        cache[item.id] = parsed;
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
      if (detail.effects && detail.effects.length) { merged.effects = detail.effects; }

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
