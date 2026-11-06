/* ===========================================================================
   BananaLootline - Verzauberungen sammeln

   SO GEHT ES:
     1. octowow.st/db oeffnen.
     2. F12, Reiter "Konsole".
     3. Diese Datei komplett einfuegen, Enter.
     4. Am Ende laedt eine JSON-Datei herunter.

   WAS GEHOLT WIRD
     Verzauberkunst    11.333   (der Hauptteil)
     Ingenieurskunst   11.202   (Zielfernrohre)
     Lederverarbeitung 11.165   (Ruestungsflicken)
     Schmiedekunst     11.164   (Waffenketten, Stacheln)
     Schneiderei       11.197

   Die Zahlen folgen dem Muster der Itemfilter: Klasse 11 sind Berufe,
   die zweite Zahl ist der Beruf. 11.333 stammt aus der Seite selbst,
   die uebrigen sind die bekannten Vanilla-Nummern. Liefert eine nichts,
   meldet das Skript es und macht weiter.

   WAS DAS SKRIPT AUSWERTET
     Aus dem NAMEN den Slot: "Enchant Gloves - ..." gehoert an die
     Haende, "Sniper Scope" an die Distanzwaffe.
     Aus der BESCHREIBUNG die Werte: "increase Agility by 7" wird zu
     AGI 7.

   Was es nicht zuordnen kann, wirft es nicht weg, sondern legt einen
   grosszuegigen Rohtext ab und zaehlt es am Ende auf. Beim letzten
   Durchlauf liessen sich dadurch ueber hundert Eintraege nachtraeglich
   auswerten, ohne erneut zu sammeln - genau dafuer ist das da.

   BEFEHLE
     BLL.status()   Stand      BLL.save()   jetzt herunterladen
     BLL.stop()     abbrechen

   EINSTELLUNGEN (optional, vorher setzen)
     BLL_SPELLS   = ["11.333"];   nur bestimmte Berufe
     BLL_RATE     = 4;            Anfragen pro Sekunde
     BLL_PARALLEL = 3;            gleichzeitig offene Anfragen
=========================================================================== */

(function () {
  "use strict";

  var GROUPS = (typeof BLL_SPELLS !== "undefined" && BLL_SPELLS.length)
    ? BLL_SPELLS
    : ["11.333", "11.202", "11.165", "11.164", "11.197"];

  var RATE     = (typeof BLL_RATE === "number") ? BLL_RATE : 4;
  var PARALLEL = (typeof BLL_PARALLEL === "number") ? BLL_PARALLEL : 3;
  var STORE_KEY = "bll_enchant_cache";

  /* ------------------------------------------------------------------
     Slot aus dem Namen ableiten
  ------------------------------------------------------------------ */

  var SLOT_RULES = [
    [/\bBracer(s)?\b/i,        "WristSlot"],
    [/\bGloves\b|\bHands\b/i,  "HandsSlot"],
    [/\bBoots\b|\bFeet\b/i,    "FeetSlot"],
    [/\bChest\b/i,             "ChestSlot"],
    [/\bCloak\b|\bBack\b/i,    "BackSlot"],
    [/\bShield\b/i,            "SecondaryHandSlot"],
    [/\bScope\b/i,             "RangedSlot"],
    [/2H Weapon|Two-Handed/i,  "MainHandSlot"],
    [/\bWeapon\b/i,            "MainHandSlot"],
    [/\bShoulder/i,            "ShoulderSlot"],
    [/\bHead\b|\bHelm\b/i,     "HeadSlot"],
    [/\bLeg(s|guards)?\b/i,    "LegsSlot"],
    [/Armor Kit/i,             "LegsSlot"],
    [/\bRing\b/i,              "Finger0Slot"],
  ];

  function slotFor(name) {
    for (var i = 0; i < SLOT_RULES.length; i++) {
      if (SLOT_RULES[i][0].test(name)) { return SLOT_RULES[i][1]; }
    }
    return null;
  }

  /* ------------------------------------------------------------------
     Werte aus der Beschreibung

     Zwei Schreibweisen kommen vor: "increase Agility by 7" und
     "+7 Agility". Beide Formen stehen deshalb in der Liste.
  ------------------------------------------------------------------ */

  /* Die Datenbank formuliert denselben Effekt auf viele Arten. Diese
     Liste ist am echten Datenbestand gewachsen - jede Zeile steht fuer
     eine Schreibweise, die vorher durchgefallen ist. */
  var STAT_RULES = [
    ["STR",        [/increase[sd]?\s+(?:the\s+)?(?:(?:wearer|bearer)[\u2019\u02bc']s\s+)?Strength\s+by\s+(\d+)/i,
                    /(?:grant|give)s?\s+\+?(\d+)\s+Strength/i,
                    /add\s+(\d+)\s+to\s+Strength/i, /\+(\d+)\s+Strength/i,
                    /Strength of the (?:wearer|bearer) by\s+(\d+)/i]],
    ["AGI",        [/increase[sd]?\s+(?:the\s+)?(?:(?:wearer|bearer)[\u2019\u02bc']s\s+)?Agility\s+by\s+(\d+)/i,
                    /(?:grant|give)s?\s+\+?(\d+)\s+Agility/i,
                    /add\s+(\d+)\s+to\s+Agility/i, /\+(\d+)\s+Agility/i,
                    /Agility of the (?:wearer|bearer) by\s+(\d+)/i]],
    ["STA",        [/increase[sd]?\s+(?:the\s+)?(?:(?:wearer|bearer)[\u2019\u02bc']s\s+)?Stamina\s+by\s+(\d+)/i,
                    /(?:grant|give)s?\s+\+?(\d+)\s+Stamina/i,
                    /add\s+(\d+)\s+to\s+Stamina/i, /\+(\d+)\s+Stamina/i,
                    /Stamina of the (?:wearer|bearer) by\s+(\d+)/i]],
    ["INT",        [/increase[sd]?\s+(?:the\s+)?(?:(?:wearer|bearer)[\u2019\u02bc']s\s+)?Intellect\s+by\s+(\d+)/i,
                    /(?:grant|give)s?\s+\+?(\d+)\s+Intellect/i,
                    /add\s+(\d+)\s+to\s+[Ii]ntellect/i, /\+(\d+)\s+Intellect/i,
                    /Intellect of the (?:wearer|bearer) by\s+(\d+)/i]],
    ["SPI",        [/increase[sd]?\s+(?:the\s+)?(?:(?:wearer|bearer)[\u2019\u02bc']s\s+)?Spirit\s+by\s+(\d+)/i,
                    /(?:grant|give)s?\s+\+?(\d+)\s+Spirit/i,
                    /add\s+(\d+)\s+to\s+Spirit/i, /\+(\d+)\s+Spirit/i,
                    /Spirit of the (?:wearer|bearer) by\s+(\d+)/i]],

    ["ARMOR",      [/increase[sd]?\s+(?:its\s+)?armor\s+by\s+(\d+)/i,
                    /(?:grant|give|provide)s?\s+\+?(\d+)\s+(?:additional points? of\s+)?armor/i,
                    /(\d+)\s+additional points? of armor/i,
                    /armor of the (?:wearer|bearer) by\s+(\d+)/i,
                    /\+(\d+)\s+[Aa]rmor/i]],
    ["DEFENSE",    [/defense skill of the wearer is increased by\s+(\d+)/i,
                    /(?:grant|give)s?\s+\+?(\d+)\s+Defense/i,
                    /increase[sd]?\s+defense\s+by\s+(\d+)/i]],
    ["HEALTH",     [/increase[sd]?\s+the health of the wearer by\s+(\d+)/i,
                    /(?:grant|give)s?\s+\+?(\d+)\s+health/i]],
    ["MANA",       [/increase[sd]?\s+the mana of the wearer by\s+(\d+)/i,
                    /(?:grant|give)s?\s+\+?(\d+)\s+mana/i]],

    ["AP",         [/attack power\s+by\s+(\d+)/i, /\+(\d+)\s+Attack Power/i]],
    ["SPELLPOWER", [/damage(?: and healing)? done by (?:magical )?spells.{0,40}?by(?: up to)?\s+(\d+)/i,
                    /\+(\d+)\s+Spell Damage/i]],
    ["HEALPOWER",  [/healing done by spells.{0,40}?by(?: up to)?\s+(\d+)/i]],
    ["MP5",        [/(\d+)\s+mana per 5/i, /(\d+)\s+mana every 5/i]],
    ["HP5",        [/(\d+)\s+health every 5/i]],
    ["CRIT",       [/critical strike.{0,25}?by\s+(\d+)/i]],
    ["HIT",        [/chance to hit\s+by\s+(\d+)/i]],
    ["DODGE",      [/dodge.{0,25}?by\s+(\d+)/i]],
    ["BLOCK",      [/\+?(\d+)%\s+chance to block/i]],
    ["BLOCKVALUE", [/amount blocked by\s+(\d+)/i, /\+(\d+)\s+Block(?!\s*chance)/i]],

    ["RES_FIRE",   [/resistance to fire by\s+(\d+)/i, /Fire Resistance\s+by\s+(\d+)/i,
                    /\+(\d+)\s+Fire Resistance/i]],
    ["RES_FROST",  [/resistance to frost by\s+(\d+)/i, /Frost Resistance\s+by\s+(\d+)/i,
                    /\+(\d+)\s+Frost Resistance/i]],
    ["RES_NATURE", [/resistance to nature by\s+(\d+)/i, /Nature Resistance\s+by\s+(\d+)/i,
                    /\+(\d+)\s+Nature Resistance/i]],
    ["RES_SHADOW", [/resistance to shadow by\s+(\d+)/i, /Shadow Resistance\s+by\s+(\d+)/i,
                    /\+(\d+)\s+Shadow Resistance/i]],
    ["RES_ARCANE", [/resistance to arcane by\s+(\d+)/i, /Arcane Resistance\s+by\s+(\d+)/i,
                    /\+(\d+)\s+Arcane Resistance/i]],

    /* Schulgebundener Zauberschaden zaehlt nur fuer eine Schule und
       wird im Addon halb gewichtet. */
    ["SPELLPOWER_FIRE",   [/increase[sd]?\s+fire damage by(?: up to)?\s+(\d+)/i]],
    ["SPELLPOWER_FROST",  [/increase[sd]?\s+frost damage by(?: up to)?\s+(\d+)/i]],
    ["SPELLPOWER_SHADOW", [/increase[sd]?\s+shadow damage by(?: up to)?\s+(\d+)/i]],
    ["SPELLPOWER_ARCANE", [/increase[sd]?\s+arcane damage by(?: up to)?\s+(\d+)/i]],
    ["SPELLPOWER_NATURE", [/increase[sd]?\s+nature damage by(?: up to)?\s+(\d+)/i]],
    ["SPELLPOWER_HOLY",   [/increase[sd]?\s+holy damage by(?: up to)?\s+(\d+)/i]],
  ];

  /* Flacher Waffenschaden - Zielfernrohre und "Striking". Bleibt
     bewusst getrennt von den Werten: was +7 Schaden bringen, haengt
     vom Tempo der Waffe ab, das weiss erst das Addon. */
  var DMG_RULES = [
    /adds?\s+(\d+)\s+damage/i,
    /(\d+)\s+damage\s+to\s+(?:ranged\s+)?weapon/i,
    // "increases ITS damage by 7" - zwischen Verb und "damage" steht bei
    // Zielfernrohren ein Wort. Ohne die Luecke fiel der ganze Slot aus.
    /increase[sd]?\s+(?:\w+\s+){0,2}damage\s+by\s+(\d+)/i,
    // "to do 2 additional points of damage" - Formulierung der
    // Striking- und Impact-Verzauberungen auf Waffen.
    /(\d+)\s+additional points? of damage/i,
    // Das Pluszeichen kommt vor: "to do +5 damage"
    /do\s+\+?(\d+)\s+(?:additional\s+)?damage/i,
  ];

  var ALLRES = /All Resistances?\s+by\s+(\d+)|\+?(\d+)\s+to all resistances|\+(\d+)\s+All Resistances?|resistance to all schools of magic by\s+(\d+)/i;

  // "increase all stats by 4" - betrifft alle fuenf Grundwerte.
  var ALLSTATS = /all stats\s+by\s+(\d+)|\+?(\d+)\s+to all stats|\+(\d+)\s+[Aa]ll [Ss]tats/i;

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
     Beschreibung finden

     Der erste Anlauf suchte nur nach "Permanently enchant" und nahm
     sonst die ersten 600 Zeichen der Seite - also Navigation und
     Seitentitel. Bei 310 von 561 Verzauberungen kam dadurch nur Muell
     an, und die Werte fehlten.

     Jetzt mehrere Strategien nacheinander, und in JEDEM Fall wird ein
     grosszuegiger Rohtext mitgespeichert. Das ist wichtiger als es
     klingt: beim letzten Durchlauf liessen sich ueber hundert
     Eintraege nachtraeglich auswerten, WEIL der Rohtext da war - ohne
     erneutes Sammeln.
  ------------------------------------------------------------------ */

  /* Aufbau einer Zauberseite, am echten Beispiel abgelesen:
  
       Enchant Bracer - Minor Health      <- Name, mehrfach im Kopf
       5 sec cast
       Reagents: Strange Dust
       Tools: Runed Copper Rod
       Permanently enchant bracers to increase the health ... by 5.
       Reagents  Strange Dust  Tools  Runed Copper Rod     <- Abschnitte
       Details on spell  cost None  Range 0 yards ...      <- Tabelle
       Effect #1 (53) Enchant Item Permanent (41) Value: 0
  
     Entscheidend: die Beschreibung steht NACH "Reagents:" und "Tools:".
     Der erste Entwurf hat den Text bei "Reagents" abgeschnitten und
     damit genau die Beschreibung weggeworfen - daher die 310 leeren
     Eintraege.
  
     Das sichere Ende ist "Details on spell". Was davor liegt, ist
     Kopfbereich, Zutaten und Beschreibung; Zutaten und Zauberzeit
     werden gezielt entfernt, damit ihre Zahlen nicht als Werte
     missverstanden werden ("5 sec cast" waere sonst eine 5).
  ------------------------------------------------------------------ */

  function stripChrome(text, name) {
    // Alles ab der Detailtabelle abschneiden
    var t = text.split(/Details on spell/i)[0];

    // Kopfbereich: der Name steht dort mehrfach
    if (name) {
      var esc = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      var re = new RegExp(esc, "g"), m, last = -1;
      while ((m = re.exec(t)) !== null) {
        if (m.index > 500) { break; }
        last = m.index + m[0].length;
      }
      if (last > 0) { t = t.slice(last); }
    }

    // Seitengeruest und Zutaten entfernen. Ohne das liest der
    // Rueckfallweg "5 sec cast" oder "Level: 0" als Wert.
    t = t.replace(/\b\d+\s*(?:sec|second|min|minute)s?\s+cast\b/gi, " ");
    t = t.replace(/\bReagents?\s*:[^.]{0,120}?(?=(?:Tools?\s*:|Permanently|Attaches|Enchants|$))/gi, " ");
    t = t.replace(/\bTools?\s*:[^.]{0,120}?(?=(?:Permanently|Attaches|Enchants|Reagents|$))/gi, " ");
    t = t.replace(/Quick Facts|Level:\s*\d+|Wowhead|OctoWow Database|- Spells\b/gi, " ");
    t = t.replace(/\bReagents\b|\bTools\b/g, " ");
    t = t.replace(/\s+/g, " ");
    return t.trim();
  }

  var DESC_STARTS = [
    /Permanently enchant[^.]*\./i,
    /Permanently attach[^.]*\./i,
    /Permanently add[^.]*\./i,
    /Permanently increase[^.]*\./i,
    /Attaches? a[^.]*\./i,
    /Enchants? a[^.]*\./i,
    /Adds? \d+[^.]*\./i,
  ];

  function findDescription(text, name) {
    var body = stripChrome(text, name);

    for (var i = 0; i < DESC_STARTS.length; i++) {
      var m = body.match(DESC_STARTS[i]);
      if (m) { return { text: m[0].trim(), how: "satz" }; }
    }

    /* Kein bekannter Satzanfang: Abschnitt mit Zahl neben Wertwort.
       Faengt Formulierungen ab, die wir noch nicht kennen. */
    var near = body.match(/[^.]{0,160}\b\d+\b[^.]{0,160}(?:Agility|Strength|Stamina|Intellect|Spirit|Armor|[Rr]esistance|damage|healing|mana|health|Defense|block)[^.]{0,120}\./i)
            || body.match(/[^.]{0,160}(?:Agility|Strength|Stamina|Intellect|Spirit|Armor|[Rr]esistance|damage|healing|mana|health|Defense|block)[^.]{0,160}\b\d+\b[^.]{0,120}\./i);
    if (near) { return { text: near[0].trim(), how: "umfeld" }; }

    return { text: body.slice(0, 300), how: "roh" };
  }

  function parseSpellPage(html, id, name) {
    var text = htmlToText(html);
    var out = { id: id, name: name, stats: {} };

    var found = findDescription(text, name);
    out.desc = found.text.slice(0, 300);
    out.descHow = found.how;

    /* Zusaetzlich immer einen breiteren Rohausschnitt mitgeben. Kostet
       Platz in der Datei, erspart aber im Zweifel einen kompletten
       zweiten Sammellauf. */
    out.raw = stripChrome(text, name).slice(0, 600);

    var scope = out.desc;

    var m = scope.match(ALLRES);
    if (m) {
      var v = parseInt(m[1] || m[2] || m[3] || m[4], 10);
      out.stats.RES_FIRE = v; out.stats.RES_FROST = v; out.stats.RES_NATURE = v;
      out.stats.RES_SHADOW = v; out.stats.RES_ARCANE = v;
    }

    var ms = scope.match(ALLSTATS);
    if (ms) {
      var sv = parseInt(ms[1] || ms[2] || ms[3], 10);
      out.stats.STR = sv; out.stats.AGI = sv; out.stats.STA = sv;
      out.stats.INT = sv; out.stats.SPI = sv;
    }

    for (var i = 0; i < STAT_RULES.length; i++) {
      var key = STAT_RULES[i][0];
      if (out.stats[key] !== undefined) { continue; }
      var pats = STAT_RULES[i][1];
      for (var p = 0; p < pats.length; p++) {
        var mm = scope.match(pats[p]);
        if (mm) { out.stats[key] = parseInt(mm[1], 10); break; }
      }
    }

    for (var d = 0; d < DMG_RULES.length; d++) {
      var dm = scope.match(DMG_RULES[d]);
      if (dm) { out.dmg = parseInt(dm[1], 10); break; }
    }

    var rl = scope.match(/level\s+(\d+)\s+or higher item/i)
          || text.match(/Requires.{0,20}?level\s+(\d+)/i);
    if (rl) { out.req = parseInt(rl[1], 10); }

    out.slot = slotFor(name || "");

    /* "Enchant Item Permanent" steht in der Effekttabelle jeder echten
       Verzauberung. Damit lassen sich Berufsfertigkeiten und Zauberstaebe
       sicher aussortieren - der Name allein reicht dafuer nicht. */
    out.isEnchant = /Enchant Item Permanent/i.test(text) || /Permanently enchant|Permanently attach/i.test(text);

    var any = false;
    for (var k in out.stats) { any = true; break; }

    /* Baurezepte der Berufe tragen oft Slotwoerter im Namen -
       "Goblin Rocket Boots" landete dadurch im Fussslot. Ohne den
       Effektnachweis gilt ein Eintrag deshalb nicht als Verzauberung. */
    if (!out.isEnchant) { out.slot = null; }

    out.unresolved = (!any && out.dmg === undefined) || !out.slot;

    return out;
  }

  /* ------------------------------------------------------------------
     Listen holen
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
    var blobs = extractArrays(html), best = null;
    for (var b = 0; b < blobs.length; b++) {
      try {
        var arr = eval("(" + blobs[b] + ")");
        if (!arr || !arr.length) { continue; }
        if (arr[0] && arr[0].id !== undefined && arr[0].name !== undefined) {
          if (!best || arr.length > best.length) { best = arr; }
        }
      } catch (e) { /* naechster */ }
    }
    return best;
  }

  /* ------------------------------------------------------------------
     Zustand
  ------------------------------------------------------------------ */

  var cache = {};
  try { cache = JSON.parse(sessionStorage.getItem(STORE_KEY) || "{}"); } catch (e) { cache = {}; }

  var todo = [], pending = [], retry = [];
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
    var items = [];
    for (var i = 0; i < todo.length; i++) {
      var base = todo[i], d = cache[base.id];
      if (!d) { continue; }
      items.push({
        id: base.id, name: base.name, group: base.group,
        slot: d.slot, stats: d.stats, dmg: d.dmg, req: d.req,
        desc: d.desc, raw: d.raw, descHow: d.descHow,
        isEnchant: d.isEnchant, unresolved: d.unresolved
      });
    }
    return {
      exported: new Date().toISOString(), url: location.href,
      source: "spell-pages", groups: GROUPS,
      complete: (items.length === todo.length),
      expected: todo.length, count: items.length, enchants: items
    };
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

  function launch(sp) {
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

    fetch("?spell=" + sp.id, { credentials: "same-origin" })
      .then(function (r) { if (!r.ok) { throw new Error("HTTP " + r.status); } return r.text(); })
      .then(settle(function (html) {
        var wrong = looksWrong(html);
        if (wrong) { retry.push(sp); return; }

        cache[sp.id] = parseSpellPage(html, sp.id, sp.name);
        done++;

        if (done === 1) {
          console.log("[BLL] Erstes Ergebnis (bitte pruefen):", cache[sp.id]);
        }
        if (done % 25 === 0) {
          persist();
          var secs = (Date.now() - startedAt) / 1000;
          console.log("[BLL] " + done + "/" + pending.length + " ("
            + Math.round(done / pending.length * 100) + "%) - "
            + (done / secs).toFixed(1) + "/s");
        }
      }))
      .catch(settle(function (err) {
        failed++; retry.push(sp);
        if (failed <= 5) { console.warn("[BLL] Zauber " + sp.id + " fehlgeschlagen:",
          err && err.message ? err.message : err); }
      }));
  }

  function finish(reason) {
    if (retry.length && retryRound < 2 && !stopped) {
      retryRound++;
      pending = retry; retry = []; index = 0; parallelNow = 1;
      console.log("[BLL] Nachlauf " + retryRound + ": " + pending.length + " nochmal.");
      setTimeout(pump, 3000);
      return;
    }
    if (watchdog) { clearInterval(watchdog); watchdog = null; }
    persist();

    var p = buildPayload();
    var bySlot = {}, unresolved = [];
    for (var i = 0; i < p.enchants.length; i++) {
      var e = p.enchants[i];
      if (e.unresolved) { unresolved.push(e.name); }
      else { bySlot[e.slot] = (bySlot[e.slot] || 0) + 1; }
    }

    console.log("[BLL] Ende (" + reason + "). " + p.count + "/" + p.expected
      + " Zauber. Fehlgeschlagen: " + failed);
    console.log("[BLL] Pro Slot:", bySlot);

    var how = {};
    for (var h = 0; h < p.enchants.length; h++) {
      var k2 = cache[p.enchants[h].id] && cache[p.enchants[h].id].descHow;
      if (k2) { how[k2] = (how[k2] || 0) + 1; }
    }
    console.log("[BLL] Beschreibung gefunden ueber:", how,
      "(satz = klarer Satzanfang, umfeld = Zahl neben Wertwort, roh = Notnagel)");
    if (unresolved.length) {
      console.warn("[BLL] " + unresolved.length + " nicht zuordenbar - "
        + "sie stehen mit Rohtext in der Datei, damit die Muster ergaenzt "
        + "werden koennen:");
      console.warn("   " + unresolved.slice(0, 20).join(" | "));
    }
    download(p, "octodb_enchants");
  }

  window.BLL = window.BLL || {};
  window.BLL.stop = function () {
    stopped = true;
    if (watchdog) { clearInterval(watchdog); watchdog = null; }
    console.log("[BLL] Abbruch. " + done + " geholt. BLL.save() laedt sie herunter.");
  };
  window.BLL.status = function () {
    console.log("[BLL] " + index + "/" + pending.length + " angestossen, " + done
      + " fertig, " + failed + " fehlgeschlagen.");
  };
  window.BLL.save = function () {
    persist(); var p = buildPayload();
    console.log("[BLL] " + p.count + "/" + p.expected + " gespeichert");
    download(p, "octodb_enchants"); return p.count;
  };

  watchdog = setInterval(function () {
    if (stopped) { return; }
    if (Date.now() - lastActivity < 20000) { return; }
    if (inFlight > 0) {
      console.warn("[BLL] 20s ohne Antwort - " + inFlight + " Anfrage(n) aufgegeben.");
      inFlight = 0;
    }
    if (index >= pending.length && !retry.length) { finish("Wachhund"); return; }
    lastActivity = Date.now();
    pump();
  }, 5000);

  /* ------------------------------------------------------------------
     Los
  ------------------------------------------------------------------ */

  console.log("[BLL] Hole " + GROUPS.length + " Zauberlisten ...");

  var gi = 0;
  function nextGroup() {
    if (gi >= GROUPS.length) {
      pending = [];
      for (var t = 0; t < todo.length; t++) {
        if (!cache[todo[t].id]) { pending.push(todo[t]); }
      }
      console.log("[BLL] " + todo.length + " Zauber gesamt, "
        + (todo.length - pending.length) + " schon geholt, "
        + pending.length + " offen.");
      if (!pending.length) { finish("nichts offen"); return; }
      console.log("[BLL] Befehle: BLL.status() | BLL.save() | BLL.stop()");
      startedAt = Date.now();
      pump();
      return;
    }

    var g = GROUPS[gi]; gi++;
    fetch("?spells=" + g, { credentials: "same-origin" })
      .then(function (r) { if (!r.ok) { throw new Error("HTTP " + r.status); } return r.text(); })
      .then(function (html) {
        var wrong = looksWrong(html);
        if (wrong) { throw new Error(wrong); }
        var rows = parseListPage(html);
        if (!rows) { throw new Error("keine Zauberliste im HTML"); }
        var added = 0;
        for (var i = 0; i < rows.length; i++) {
          var r2 = rows[i];
          if (!r2 || r2.id == null) { continue; }
          todo.push({ id: r2.id, name: String(r2.name || "").replace(/^\d/, ""), group: g });
          added++;
        }
        console.log("[BLL] " + g + ": " + added + " Zauber");
      })
      .catch(function (e) {
        console.warn("[BLL] " + g + " uebersprungen: " + (e && e.message ? e.message : e));
      })
      .then(function () { setTimeout(nextGroup, 1000 / RATE); });
  }

  nextGroup();
})();
