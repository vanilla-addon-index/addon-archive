#!/usr/bin/env python3
"""Erzeugt BananaCraft_Catalog.lua aus den Datenbankdateien von AtlasLoot (Turtle Edition).

Aufruf:  python3 -I gen_catalog.py <AtlasLoot-Ordner> <Ausgabedatei>

Liest Database/Menus.lua (Kategoriebaum), Database/Crafting.lua (Rezepte je Kategorie),
Database/Spells.lua (Reagenzien, Zauberzeit, Werkzeug) und Locale/locale.en.lua
(englische Texte) und schreibt eine kompakte Lua-Datei fuer das Addon.
"""
import re, sys, os

# ---------------------------------------------------------------- Lua-Tabellen-Parser (nur Daten)
class P:
    def __init__(self, text, L):
        self.s = text; self.i = 0; self.L = L
    def ws(self):
        s = self.s
        while self.i < len(s):
            c = s[self.i]
            if c in " \t\r\n\ufeff":
                self.i += 1
            elif s.startswith("--[[", self.i):
                j = s.find("]]", self.i + 4); self.i = len(s) if j < 0 else j + 2
            elif s.startswith("--", self.i):
                j = s.find("\n", self.i); self.i = len(s) if j < 0 else j + 1
            else:
                break
    def peek(self, t):
        self.ws(); return self.s.startswith(t, self.i)
    def eat(self, t):
        self.ws()
        if not self.s.startswith(t, self.i): raise SyntaxError("expected %r at %d: %r" % (t, self.i, self.s[self.i:self.i+40]))
        self.i += len(t)
    def string(self):
        q = self.s[self.i]; self.i += 1; out = []
        while True:
            c = self.s[self.i]
            if c == "\\":
                n = self.s[self.i+1]
                out.append({"n": "\n", "t": "\t", "r": "\r"}.get(n, n)); self.i += 2
            elif c == q:
                self.i += 1; break
            else:
                out.append(c); self.i += 1
        return "".join(out)
    def term(self):
        self.ws(); s = self.s; c = s[self.i]
        if c in "\"'":
            return self.string()
        if c == "{":
            return self.table()
        if c == "(":
            self.i += 1; v = self.expr(); self.eat(")"); return v
        m = re.compile(r"-?(0[xX][0-9a-fA-F]+|\d+\.?\d*)").match(s, self.i)
        if m:
            self.i = m.end(); t = m.group(0)
            return int(t, 16) if "x" in t.lower() else (float(t) if "." in t else int(t))
        m = re.compile(r"[A-Za-z_][A-Za-z0-9_.]*").match(s, self.i)
        if m:
            self.i = m.end(); name = m.group(0)
            if name == "true": return True
            if name == "false": return False
            if name == "nil": return None
            if self.peek("["):
                self.eat("["); k = self.expr(); self.eat("]")
                if name == "L": return self.L.get(k, k)
                return ""
            if self.peek("(") :  # Funktionsaufruf -> ignorieren
                depth = 0
                while True:
                    ch = self.s[self.i]
                    if ch == "(": depth += 1
                    if ch == ")":
                        depth -= 1
                        if depth == 0: self.i += 1; break
                    self.i += 1
                return ""
            return ""
        raise SyntaxError("bad term at %d: %r" % (self.i, s[self.i:self.i+40]))
    def expr(self):
        v = self.term()
        while self.peek(".."):
            self.eat(".."); w = self.term()
            v = (v if isinstance(v, str) else str(v)) + (w if isinstance(w, str) else str(w))
        return v
    def table(self):
        self.eat("{"); arr = []; mp = {}
        while True:
            self.ws()
            if self.peek("}"): self.eat("}"); break
            if self.peek("["):
                self.eat("["); k = self.expr(); self.eat("]"); self.eat("="); mp[k] = self.expr()
            else:
                m = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)").match(self.s, self.i) if True else None
                if m:
                    self.i = m.end(); mp[m.group(1)] = self.expr()
                else:
                    arr.append(self.expr())
            self.ws()
            if self.peek(",") or self.peek(";"): self.i += 1
        return (arr, mp)

def table_after(text, marker, L):
    a = text.index(marker) + len(marker)
    p = P(text, L); p.i = a; p.ws()
    return p.table()

def load_locale(path):
    t = open(path, encoding="utf-8", errors="replace").read()
    m = {}
    for k, v in re.findall(r'\["((?:[^"\\]|\\.)*)"\]\s*=\s*(true|"(?:[^"\\]|\\.)*")', t):
        key = bytes(k, "utf-8").decode("unicode_escape", "ignore") if "\\" in k else k
        if v == "true": m[key] = key
        else:
            val = v[1:-1]
            m[key] = bytes(val, "utf-8").decode("unicode_escape", "ignore") if "\\" in val else val
    return m

# ---------------------------------------------------------------- Hauptprogramm
def main(root, out):
    L = load_locale(os.path.join(root, "Locale", "locale.en.lua"))
    menus_txt = open(os.path.join(root, "Database", "Menus.lua"), encoding="utf-8", errors="replace").read()
    craft_txt = open(os.path.join(root, "Database", "Crafting.lua"), encoding="utf-8", errors="replace").read()
    spell_txt = open(os.path.join(root, "Database", "Spells.lua"), encoding="utf-8", errors="replace").read()
    tp_txt = open(os.path.join(root, "Core", "TextParsing.lua"), encoding="utf-8", errors="replace").read()

    tokens = {}
    for k, v in re.findall(r'\["(#(?:p|sk)\d+#)"\]\s*=\s*L\["([^"]+)"\]', tp_txt):
        tokens[k] = L.get(v, v)

    _, menus = table_after(menus_txt, "AtlasLoot_Data.MENUS =", L)
    _, craft = table_after(craft_txt, 'AtlasLoot_Data["AtlasLootCrafting"] =', L)
    _, spells = table_after(spell_txt, "GetSpellInfoAtlasLootDB =", L)
    craftspells = spells.get("craftspells", ({}, {}))[1] if isinstance(spells.get("craftspells"), tuple) else {}
    enchants = spells.get("enchants", ({}, {}))[1] if isinstance(spells.get("enchants"), tuple) else {}
    craft = {k: v for k, v in craft.items() if isinstance(v, tuple)}

    def rows_of(tkey):
        """Seiten tkey, tkey+1, ... zusammenfassen und nach Slot sortieren."""
        m = re.match(r"^(.*?)(\d+)$", tkey)
        if not m: return None
        stem, n = m.group(1), int(m.group(2))
        res = []
        while (stem + str(n)) in craft:
            arr = craft[stem + str(n)][0]
            page = []
            for r in arr:
                if isinstance(r, tuple) and len(r[0]) >= 4:
                    page.append(r[0])
            page.sort(key=lambda r: r[0] if isinstance(r[0], int) else 0)
            res.extend(page); n += 1
        return res or None

    item_to_spell = {}
    for sid, e in sorted(craftspells.items()):
        if isinstance(e, tuple) and isinstance(e[1].get("craftItem"), int) and e[1].get("reagents"):
            item_to_spell.setdefault(e[1]["craftItem"], sid)
    used_spells = {}
    used_enchants = {}

    def conv_row(r):
        slot, rid, icon, name, extra = (r + ["", "", "", "", ""])[:5]
        name = str(name); extra = str(extra); icon = str(icon)
        q = None
        m = re.match(r"=q(\d+)=(.*)$", name)
        if m: q = int(m.group(1)); name = m.group(2)
        else:
            m = re.match(r"=ds=(.*)$", name)
            if m: name = m.group(1)
        for k, v in tokens.items(): name = name.replace(k, v)
        name = name.strip()
        if rid == 0 or rid == "0" or (isinstance(rid, int) and rid == 0):
            return ["h", 0, "", 6, name, 0, 0, 0, 0]
        kind, num = "i", None
        if isinstance(rid, str) and re.match(r"^[se]\d+$", rid):
            kind, num = rid[0], int(rid[1:])
        elif isinstance(rid, int):
            num = rid
        else:
            return None
        if kind == "i" and num in item_to_spell:
            # reine Item-Zeile (z. B. Crafted Epic Weapons) -> Herstellungszauber mit Materialien
            kind, num = "s", item_to_spell[num]
        so = [int(x) for x in re.findall(r"=so[1-4]=(\d+)", extra)]
        while len(so) < 4: so.append(0)
        if kind == "s": used_spells[num] = True
        if kind == "e": used_enchants[num] = True
        return [kind, num, icon, q if q is not None else 0, name, so[0], so[1], so[2], so[3]]

    def make_cat(label, tkey):
        rows = rows_of(tkey)
        if not rows: return None
        conv = [c for c in (conv_row(r) for r in rows) if c]
        return {"name": label, "rows": conv} if conv else None

    def label_of(lbl):
        parts = str(lbl).split(": ")
        return parts[-1].strip()

    TIERS = ("Apprentice", "Journeyman", "Expert", "Artisan")
    DBKEY = {"Alchemy": "Alchemy", "Blacksmithing": "Blacksmithing", "Enchanting": "Enchanting", "Engineering": "Engineering",
             "Jewelcrafting": "Jewelcrafting", "Leatherworking": "Leatherworking", "Tailoring": "Tailoring",
             "Cooking": "Cooking", "First Aid": "First Aid", "Mining": "Mining", "Poisons": "Poisons",
             "Herbalism": "Herbalism", "Survival": "Survival", "Gardening": "Gardening"}

    top = menus["CRAFTINGMENU"][0]
    profs = []
    for e in sorted((x[0] for x in top if isinstance(x, tuple)), key=lambda r: r[0]):
        slot, target, icon, label = e[0], str(e[1]), str(e[2]), label_of(e[3])
        if target == "CRAFTSET":
            continue
        cats = []
        if target.endswith("MENU") and target in menus:
            sub = [x[0] for x in menus[target][0] if isinstance(x, tuple)]
            sub.sort(key=lambda r: r[0])
            last = None
            for r in sub:
                c = make_cat(label_of(r[3]), str(r[1]))
                if c:
                    if last is not None and r[0] - last > 1: c["gap"] = True
                    cats.append(c); last = r[0]
                else:
                    last = r[0]
        else:
            m = re.match(r"^(.*?)(Apprentice|Journeyman|Expert|Artisan)\d+$", target)
            if m:
                for t in TIERS:
                    c = make_cat(t, m.group(1) + t + "1")
                    if c: cats.append(c)
            else:
                c = make_cat(label, target)
                if c:
                    c["name"] = "Alle" if False else label
                    cats.append(c)
        if cats:
            profs.append({"key": label, "db": DBKEY.get(label, label), "icon": icon, "cats": cats,
                          "gather": label in ("Mining", "Herbalism")})

    profs.sort(key=lambda p: p.get("gather", False))   # Sammelberufe ans Ende (stabile Sortierung)

    # ---- Ausgabe
    def q(s):
        s = str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "").replace("\t", " ")
        return '"%s"' % s
    o = []
    o.append("-- BananaCraft -- Rezeptkatalog (generiert von tools/gen_catalog.py, nicht von Hand aendern)")
    o.append("BCRAFT_Catalog = {")
    for p in profs:
        o.append('{ key = %s, db = %s, icon = %s,%s cats = {' % (q(p["key"]), q(p["db"]), q(p["icon"]), " gather = true," if p.get("gather") else ""))
        for c in p["cats"]:
            o.append('{ name = %s,%s rows = {' % (q(c["name"]), " gap = true," if c.get("gap") else ""))
            for r in c["rows"]:
                o.append('{%s,%d,%s,%d,%s,%d,%d,%d,%d},' % (q(r[0]), r[1], q(r[2]), r[3], q(r[4]), r[5], r[6], r[7], r[8]))
            o.append('}},')
        o.append('}},')
    o.append("}")
    o.append("")
    o.append("-- Zauber: [id] = { Item, Zauberzeit, Abklingzeit, Werkzeug, Text, Reagenzien {{id,Anzahl},...} }")
    o.append("BCRAFT_CraftSpells = {")
    def reag(rs):
        out = []
        if isinstance(rs, tuple):
            for x in rs[0]:
                if isinstance(x, tuple) and x[0]:
                    ids = x[0]
                    out.append("{%d,%d}" % (ids[0], ids[1] if len(ids) > 1 else 1))
        return "{" + ",".join(out) + "}"
    for sid in sorted(used_spells):
        e = craftspells.get(sid)
        if not isinstance(e, tuple): continue
        m = e[1]
        item = m.get("craftItem") or 0
        o.append("[%d]={%d,%d,%d,%s,%s,%s}," % (sid, item if isinstance(item, int) else 0,
                 int(m.get("castTime") or 0), int(m.get("cooldown") or 0),
                 q(m.get("tools") or ""), q((m.get("text") or "")[:400]), reag(m.get("reagents"))))
    o.append("}")
    o.append("")
    o.append("-- Verzauberungen: [id] = Item (z. B. Zauberstab/Rute) oder 0")
    o.append("BCRAFT_Enchants = {")
    for eid in sorted(used_enchants):
        e = enchants.get(eid)
        item = 0
        if isinstance(e, tuple): item = e[1].get("item") or 0
        o.append("[%d]=%d," % (eid, item if isinstance(item, int) else 0))
    o.append("}")
    open(out, "w", encoding="utf-8").write("\n".join(o) + "\n")
    n = sum(len(c["rows"]) for p in profs for c in p["cats"])
    print("Berufe:", len(profs), "Kategorien:", sum(len(p["cats"]) for p in profs), "Zeilen:", n,
          "Zauber:", len(used_spells), "Verzauberungen:", len(used_enchants))
    for p in profs:
        print(" ", p["key"], "->", ", ".join("%s(%d)" % (c["name"], len(c["rows"])) for c in p["cats"]))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
