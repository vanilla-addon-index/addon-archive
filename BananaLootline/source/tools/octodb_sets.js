/* ===========================================================================
   BananaLootline - Itemsets und ihre Boni

   SO GEHT ES:
     1. octowow.st/db oeffnen.
     2. F12, Reiter "Konsole".
     3. Diese Datei komplett einfuegen, Enter.

   WARUM DAS WICHTIG IST
   In Vanilla entscheidet der Set-Bonus haeufig ueber die Wahl. Ein fuer
   sich schwaecheres Teil ist die bessere Wahl, wenn es den Vierer-Bonus
   vervollstaendigt. Ohne diese Daten kann ein Planer solche Faelle gar
   nicht sehen - er wuerde stur das Teil mit den hoeheren Einzelwerten
   vorschlagen.

   Gespeichert wird pro Set: Name, Mitgliedsitems und die Boni mit ihrer
   Teileschwelle. Wert und Dauer werden, wo moeglich, als Zahl
   herausgezogen - die Verrechnung macht spaeter das Addon.

   BEFEHLE
     BLL.status()   Stand      BLL.save()   jetzt herunterladen
     BLL.stop()     abbrechen

   EINSTELLUNGEN (optional, vorher setzen)
     BLL_RATE     = 4;   Anfragen pro Sekunde
     BLL_PARALLEL = 3;   gleichzeitig offene Anfragen
=========================================================================== */

(function () {
  "use strict";

  var RATE     = (typeof BLL_RATE === "number") ? BLL_RATE : 4;
  var PARALLEL = (typeof BLL_PARALLEL === "number") ? BLL_PARALLEL : 3;
  var STORE_KEY = "bll_sets_cache";

  var PREFIX_QUALITY = { "0": 6, "1": 5, "2": 4, "3": 3, "4": 2, "5": 1, "6": 0 };

  function splitName(raw) {
    if (typeof raw !== "string" || !raw.length) { return { name: raw, quality: null }; }
    var q = PREFIX_QUALITY[raw.charAt(0)];
    if (q !== undefined) { return { name: raw.slice(1), quality: q }; }
    return { name: raw, quality: null };
  }

  function htmlToText(html) {
    var t = html;
    t = t.replace(/<script[\s\S]*?<\/script>/gi, " ");
    t = t.replace(/<style[\s\S]*?<\/style>/gi, " ");
    t = t.replace(/<[^>]+>/g, " ");
    t = t.replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
         .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"');
    return t.replace(/\s+/g, " ");
  }

  function looksWrong(html) {
    if (!html || html.length < 500) { return "zu kurz"; }
    if (/Verifying your browser|DDoS Protection|Just a moment/i.test(html)) { return "DDoS-Pruefung"; }
    if (/<title>\s*(404|403|500|Error)/i.test(html)) { return "Fehlerseite"; }
    return null;
  }

  /* ------------------------------------------------------------------
     Setseite auswerten
  ------------------------------------------------------------------ */

  /* Die Seite schreibt Boni als "3 pieces: ...", nicht als "(3) Set: ...".
     Der Block beginnt mit "Set Bonuses / Wearing more pieces of this set
     will convey bonuses to your character." und endet im Seitenfuss. */
  var STOPS = ["Requires ", "Classes:", "Races:",
               "Quick Facts", "Comments", "Related", "Screenshots", "Added in",
               "See also", "No comments", "Log in", "Post a comment"];

  function parseSetPage(html, setId) {
    var out = { id: setId, items: [], bonuses: [] };
    var text = htmlToText(html);

    /* Mitglieder: alle Itemverweise der Seite, Reihenfolge erhalten.
       Eine Setseite verlinkt praktisch nur ihre eigenen Teile. */
    var seen = {};
    var linkRe = /[?&]item=(\d+)/g, lm;
    while ((lm = linkRe.exec(html)) !== null) {
      var id = parseInt(lm[1], 10);
      if (!seen[id]) { seen[id] = 1; out.items.push(id); }
    }

    /* Boni: "(4) Set: Erhoeht ...". Die Zahl in Klammern ist die
       Teileschwelle - genau die braucht das Addon, um zu entscheiden,
       ob ein Kandidat den naechsten Bonus freischaltet. */
    /* Hauptform dieses Forks: "3 pieces: ...". Die Klammerform bleibt
       als zweite Moeglichkeit stehen, falls einzelne Seiten abweichen. */
    var bonusRe = /(?:\((\d+)\)\s*Set\s*:?|\b(\d+)\s+pieces?\s*:)\s*(.{4,300})/gi, bm;
    while ((bm = bonusRe.exec(text)) !== null) {
      var pieces = parseInt(bm[1] !== undefined ? bm[1] : bm[2], 10);
      var chunk = bm[3];

      var cut = chunk.length;

      /* Der naechste Bonus beginnt mit "5 pieces:". Per Regex schneiden,
         damit die ZAHL mitgeht - ein Schnitt auf die blosse Zeichenkette
         "pieces:" liess die "5" am Vorgaenger haengen und setzte die
         Suche mitten im naechsten Bonus fort, der dadurch verloren ging. */
      var nextBonus = chunk.match(/\b\d+\s+pieces?\s*:/i);
      if (nextBonus && nextBonus.index > 0) { cut = nextBonus.index; }

      for (var si = 0; si < STOPS.length; si++) {
        var at = chunk.indexOf(STOPS[si]);
        if (at > 0 && at < cut) { cut = at; }
      }
      var trimmed = chunk.slice(0, cut);
      if (cut === chunk.length) {
        var dot = trimmed.lastIndexOf(". ");
        if (dot > 10) { trimmed = trimmed.slice(0, dot + 1); }
      }
      /* Hinter dem ZUGESCHNITTENEN Text weitersuchen, sonst verschluckt
         der Zweier-Bonus den direkt folgenden Vierer-Bonus. */
      bonusRe.lastIndex = bm.index + (bm[0].length - chunk.length) + trimmed.length;

      var line = trimmed.replace(/\s+/g, " ").trim();
      if (line.length < 4) { continue; }

      var b = { pieces: pieces, text: line };
      var v = line.match(/\bby (?:up to )?(\d+)/i)
           || line.match(/\b(?:Restores|Increases|Improves|Adds)\s+(\d+)/i)
           || line.match(/\b(\d+)\s*%/);
      if (v) { b.value = parseInt(v[1], 10); }
      var dur = line.match(/for (\d+)\s*(sec|min)/i);
      if (dur) { b.duration = parseInt(dur[1], 10) * (/min/i.test(dur[2]) ? 60 : 1); }

      out.bonuses.push(b);
    }

    return out;
  }

  /* ------------------------------------------------------------------
     Zustand
  ------------------------------------------------------------------ */

  var cache = {};
  try { cache = JSON.parse(sessionStorage.getItem(STORE_KEY) || "{}"); } catch (e) { cache = {}; }

  var sets = [], pending = [], retry = [];
  var stopped = false, done = 0, failed = 0, index = 0;
  var inFlight = 0, lastStart = 0, pumpTimer = null, parallelNow = PARALLEL;
  var lastActivity = Date.now(), startedAt = Date.now(), watchdog = null, retryRound = 0;

  function persist() {
    try { sessionStorage.setItem(STORE_KEY, JSON.stringify(cache)); }
    catch (e) { console.warn("[BLL] Zwischenspeichern fehlgeschlagen:", e); }
  }

  function download(obj, prefix) {
    var blob = new Blob([JSON.stringify(obj)], { type: "application/json" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url; a.download = prefix + "_" + Date.now() + ".json";
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  function buildPayload() {
    var out = [];
    for (var i = 0; i < sets.length; i++) {
      var s = sets[i], d = cache[s.id];
      if (!d) { continue; }
      out.push({
        id: s.id, name: s.name, quality: s.quality, level: s.level,
        items: d.items || [], bonuses: d.bonuses || []
      });
    }
    return {
      exported: new Date().toISOString(),
      url: location.href,
      source: "itemsets",
      complete: (out.length === sets.length),
      expected: sets.length,
      count: out.length,
      sets: out
    };
  }

  /* ------------------------------------------------------------------
     Ablauf
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

  function loadSetList(cb) {
    /* Zuerst im laufenden Dokument nachsehen - steht man schon auf
       ?itemsets, spart das eine Anfrage. */
    var rows = null;
    try {
      if (typeof g_listviews === "object" && g_listviews) {
        for (var k in g_listviews) {
          var lv = g_listviews[k];
          if (lv && lv.data && lv.data.length) { rows = lv.data; break; }
        }
      }
    } catch (e) { /* egal */ }

    if (rows) { cb(rows); return; }

    fetch("?itemsets", { credentials: "same-origin" })
      .then(function (r) { if (!r.ok) { throw new Error("HTTP " + r.status); } return r.text(); })
      .then(function (html) {
        var wrong = looksWrong(html);
        if (wrong) { throw new Error(wrong); }
        var blobs = extractArrays(html);
        for (var b = 0; b < blobs.length; b++) {
          try {
            var arr = eval("(" + blobs[b] + ")");
            if (arr && arr.length && arr[0] && arr[0].id != null) { cb(arr); return; }
          } catch (e2) { /* naechster */ }
        }
        throw new Error("keine Setliste im HTML");
      })
      .catch(function (e) {
        console.error("[BLL] Setliste nicht lesbar: " + (e && e.message ? e.message : e));
        cb(null);
      });
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

  function launch(s) {
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

    fetch("?itemset=" + s.id, { credentials: "same-origin" })
      .then(function (r) { if (!r.ok) { throw new Error("HTTP " + r.status); } return r.text(); })
      .then(settle(function (html) {
        var wrong = looksWrong(html);
        if (wrong) { retry.push(s); return; }

        cache[s.id] = parseSetPage(html, s.id);
        done++;

        if (done === 1) {
          console.log("[BLL] Erstes Set (bitte pruefen):", s.name, cache[s.id]);
          if (!cache[s.id].bonuses.length) {
            console.warn("[BLL] Keine Boni erkannt. Abbruch empfohlen "
              + "(BLL.stop()) - das Muster passt nicht zur Seite.");
          }
        }
        if (done % 20 === 0) {
          persist();
          var secs = (Date.now() - startedAt) / 1000;
          console.log("[BLL] " + done + "/" + pending.length + " ("
            + Math.round(done / pending.length * 100) + "%) - "
            + (done / secs).toFixed(1) + " Sets/s");
        }
      }))
      .catch(settle(function (err) {
        failed++; retry.push(s);
        if (failed <= 5) { console.warn("[BLL] Set " + s.id + " fehlgeschlagen:",
          err && err.message ? err.message : err); }
      }));
  }

  function finish(reason) {
    if (retry.length && retryRound < 2 && !stopped) {
      retryRound++;
      pending = retry; retry = []; index = 0; parallelNow = 1;
      console.log("[BLL] Nachlauf " + retryRound + ": " + pending.length + " Sets nochmal.");
      setTimeout(pump, 3000);
      return;
    }
    if (watchdog) { clearInterval(watchdog); watchdog = null; }
    persist();

    var p = buildPayload();
    var mitBonus = 0, teile = 0;
    for (var i = 0; i < p.sets.length; i++) {
      if (p.sets[i].bonuses.length) { mitBonus++; }
      teile += p.sets[i].items.length;
    }
    console.log("[BLL] Ende (" + reason + "). " + p.count + "/" + p.expected
      + " Sets, davon " + mitBonus + " mit Boni. " + teile + " Teilezuordnungen.");
    if (!p.complete) {
      console.warn("[BLL] Unvollstaendig. Im selben Tab erneut ausfuehren.");
    }
    download(p, "octodb_sets");
  }

  window.BLL = window.BLL || {};
  window.BLL.stop = function () {
    stopped = true;
    if (watchdog) { clearInterval(watchdog); watchdog = null; }
    console.log("[BLL] Abbruch. " + done + " Sets geholt. BLL.save() laedt sie herunter.");
  };
  window.BLL.status = function () {
    console.log("[BLL] " + index + "/" + pending.length + " angestossen, " + done
      + " fertig, " + failed + " fehlgeschlagen, "
      + Math.round((Date.now() - lastActivity) / 1000) + "s seit letzter Antwort.");
  };
  window.BLL.save = function () {
    persist(); var p = buildPayload();
    console.log("[BLL] " + p.count + "/" + p.expected + " Sets gespeichert"
      + (p.complete ? "" : " (UNVOLLSTAENDIG)"));
    download(p, "octodb_sets"); return p.count;
  };

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

  console.log("[BLL] Hole die Setliste ...");
  loadSetList(function (rows) {
    if (!rows) { return; }

    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      if (!r || r.id == null) { continue; }
      var sn = splitName(r.name);
      sets.push({
        id: r.id,
        name: sn.name,
        quality: (r.quality !== undefined) ? r.quality : sn.quality,
        level: r.level
      });
    }

    pending = [];
    for (var s = 0; s < sets.length; s++) {
      if (!cache[sets[s].id]) { pending.push(sets[s]); }
    }

    console.log("[BLL] " + sets.length + " Sets gefunden, "
      + (sets.length - pending.length) + " schon geholt, " + pending.length + " offen.");
    if (!pending.length) { finish("nichts offen"); return; }
    console.log("[BLL] Befehle: BLL.status() | BLL.save() | BLL.stop()");
    startedAt = Date.now();
    pump();
  });
})();
