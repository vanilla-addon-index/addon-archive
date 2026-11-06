#!/usr/bin/env python3
"""Import CraftRoute's recipe and merchant-price data into Crafting/.

    python3 Tools/build/import_recipes.py <path to a CraftRoute checkout> [--pfquest DIR] [--check]

CraftRoute (https://github.com/Kitymeowmeow-turt/CraftRoute, GPLv3, by
Kitymeowmeow) carries hand-checked recipe data for every crafting profession on
the Turtle WoW-lineage servers: each recipe's four skill thresholds, reagents,
what it costs to learn and where it comes from, plus what merchants charge for
reagents and pay for what you make. That data is the hard part of planning a
priced route, and it is used here with its author's blessing.

Only the data comes across. It is rewritten into this addon's own format -- one
line of text per recipe, read by CraftPlanner.lua -- and the planner itself is
written separately; nothing of CraftRoute's code is used.

A few of CraftRoute's reagents are given by item id rather than name. Their
names come from pfQuest's item database: pass --pfquest with a directory
holding pfQuest's db/enUS/items.lua (and pfQuest-turtle's items-turtle.lua) to
refresh them. The names found are cached in Tools/data/recipe_item_names.json,
so later runs need no pfQuest at all.

CraftRoute's leveling routes, which the crafting guides follow, are planned and
saved by Tools/build/import_routes.py.

With --check it converts and validates but writes nothing.
"""

import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUTDIR = os.path.join(ROOT, "Crafting")
NAME_CACHE = os.path.join(ROOT, "Tools", "data", "recipe_item_names.json")

# CraftRoute's file key -> the profession's name in game.
PROFESSIONS = [
    ("alchemy", "Alchemy"),
    ("blacksmithing", "Blacksmithing"),
    ("cooking", "Cooking"),
    ("enchanting", "Enchanting"),
    ("engineering", "Engineering"),
    ("jewelcrafting", "Jewelcrafting"),
    ("leatherworking", "Leatherworking"),
    ("survival", "Survival"),
    ("tailoring", "Tailoring"),
]

# The separators of a recipe line. No name may contain one.
SEPARATORS = (" = ", " + ", " @ ", " | ")


# --------------------------------------------------------------------------
# Reading Lua table literals
# --------------------------------------------------------------------------

TOKEN = re.compile(r"""
    (?P<space>\s+|--[^\n]*)
  | (?P<string>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')
  | (?P<number>-?\d+(?:\.\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z_0-9]*)
  | (?P<punct>[{}\[\]=,;])
""", re.X)


def tokens(src, at):
    while at < len(src):
        m = TOKEN.match(src, at)
        if not m:
            raise ValueError("cannot read Lua at %r" % src[at:at + 40])
        at = m.end()
        kind = m.lastgroup
        if kind == "space":
            continue
        text = m.group()
        if kind == "string":
            text = re.sub(r"\\(.)", r"\1", text[1:-1])
        elif kind == "number":
            text = float(text) if "." in text else int(text)
        yield kind, text, at


class Reader:
    """A recursive-descent reader for the subset of Lua the data files use:
    tables, strings, numbers and booleans."""

    def __init__(self, src, at):
        self.stream = tokens(src, at)
        self.peeked = None

    def next(self):
        if self.peeked:
            tok, self.peeked = self.peeked, None
            return tok
        return next(self.stream)

    def peek(self):
        if not self.peeked:
            self.peeked = next(self.stream)
        return self.peeked

    def value(self):
        kind, text, _ = self.next()
        if kind in ("string", "number"):
            return text
        if kind == "name" and text in ("true", "false", "nil"):
            return {"true": True, "false": False, "nil": None}[text]
        if text == "{":
            return self.table()
        raise ValueError("unexpected %r" % (text,))

    def table(self):
        array, fields = [], {}
        while True:
            kind, text, _ = self.peek()
            if text == "}":
                self.next()
                break
            if kind == "name" and text not in ("true", "false", "nil"):
                self.next()
                if self.next()[1] != "=":
                    raise ValueError("expected = after %s" % text)
                fields[text] = self.value()
            elif text == "[":
                self.next()
                key = self.value()
                if self.next()[1] != "]" or self.next()[1] != "=":
                    raise ValueError("bad [key]")
                fields[key] = self.value()
            else:
                array.append(self.value())
            if self.peek()[1] in (",", ";"):
                self.next()
        if fields and array:
            raise ValueError("mixed table")
        return fields if fields else array


def read_table_after(src, marker):
    at = src.index(marker) + len(marker)
    return Reader(src, at).value()


def read_prices(path, table):
    """CraftRoute's merchant price files: one `T["name"] = copper` a line."""
    prices = {}
    pattern = re.compile(r'^%s\["((?:\\.|[^"\\])*)"\]\s*=\s*(\d+)' % re.escape(table), re.M)
    with open(path, encoding="utf-8") as f:
        for name, copper in pattern.findall(f.read()):
            prices[re.sub(r"\\(.)", r"\1", name)] = int(copper)
    return prices


# --------------------------------------------------------------------------
# Item names
# --------------------------------------------------------------------------

def read_pfquest_names(directory):
    names = {}
    for fname in ("items.lua", "items-turtle.lua"):
        path = os.path.join(directory, fname)
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            src = f.read()
        for m in re.finditer(r'\[(\d+)\]\s*=\s*"((?:\\.|[^"\\])*)"', src):
            # The turtle file is read second: where the server renamed an
            # item, its name is the one players see.
            names[int(m.group(1))] = re.sub(r"\\(.)", r"\1", m.group(2))
    if not names:
        sys.exit("no pfQuest item names found in %s" % directory)
    return names


def load_cache():
    if os.path.exists(NAME_CACHE):
        with open(NAME_CACHE, encoding="utf-8") as f:
            data = json.load(f)
        return {int(k): v for k, v in data.get("ids", {}).items()}, data.get("case", {})
    return {}, {}


def save_cache(ids, case):
    os.makedirs(os.path.dirname(NAME_CACHE), exist_ok=True)
    with open(NAME_CACHE, "w", encoding="utf-8") as f:
        json.dump({
            "_about": "Item names for Tools/build/import_recipes.py, taken from pfQuest's item "
                      "database. ids: reagents CraftRoute gives by id. case: merchant-price "
                      "names (stored lower case by CraftRoute) in their in-game spelling.",
            "ids": {str(k): ids[k] for k in sorted(ids)},
            "case": {k: case[k] for k in sorted(case)},
        }, f, indent=1, ensure_ascii=False)
        f.write("\n")


# --------------------------------------------------------------------------
# Conversion
# --------------------------------------------------------------------------

def learn_source(r):
    """How a recipe is learned, as this addon writes it.

      trainer <copper>     taught by a trainer; ~ marks CraftRoute's estimate
      book <item> <copper> a recipe item; its merchant or auction price wins,
                           and <copper> (~ for an estimate) is the fallback
      book <item> ?        a recipe item that is only usable once priced
      quest                a quest reward
      drop                 a boss drop -- only planned once you know it
      special              reputation, a quest chain, a specialisation --
                           only planned once you know it
    """
    cost = int(r.get("learnCost") or 0)
    conf = r.get("learnCostConfidence") or "estimated"
    approx = "~" if conf == "estimated" else ""
    if r.get("bossObtained"):
        return "drop"
    if r.get("questObtained"):
        return "quest"
    book = r.get("scrollName")
    if book:
        if r.get("requiresScan") or conf == "unpriced":
            return "book %s ?" % book
        return "book %s %s%d" % (book, approx, cost)
    if conf == "unpriced":
        return "special"
    return "trainer %s%d" % (approx, cost)


def check_name(name, what):
    for sep in SEPARATORS:
        if sep in name:
            raise ValueError("%s %r contains %r" % (what, name, sep))
    if re.match(r"^\d+ ", name):
        raise ValueError("%s %r starts with a number" % (what, name))
    if name != name.strip() or not name:
        raise ValueError("%s %r has stray spaces" % (what, name))


def recipe_line(r, id_names, missing, corrected):
    parts = []
    for reagent in r["reagents"]:
        name = reagent.get("name")
        if not name and reagent.get("itemId"):
            name = id_names.get(reagent["itemId"])
            if not name:
                # Nobody's database knows it; the game names it at run time.
                missing.add(reagent["itemId"])
                name = "#%d" % reagent["itemId"]
        check_name(name, "reagent")
        qty = int(reagent.get("qty") or 1)
        parts.append(name if qty == 1 else "%d %s" % (qty, name))
    check_name(r["name"], "recipe")
    thresholds = [int(r[k]) for k in ("orange", "yellow", "green", "grey")]
    # A colour can start no earlier than the one before it: a recipe you can
    # only learn at 275 is orange at 275 whatever its yellow says. The source
    # has the odd slip like that; it is levelled up here and reported.
    for i in range(1, 4):
        if thresholds[i] < thresholds[i - 1]:
            corrected.append("%s: %s" % (r["name"], "-".join(str(t) for t in thresholds)))
            thresholds[i] = thresholds[i - 1]
    line = "%s = %s @ %s | %s" % (
        r["name"], " + ".join(parts), "-".join(str(t) for t in thresholds), learn_source(r))
    if r.get("excluded"):
        line += " | skip"
    if r.get("excludeFromMakeVsBuy"):
        line += " | nomake"
    return line


def lua_string(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


HEADER = """--[[
	{title} recipes, for the crafting route planner (CraftPlanner.lua).

	GENERATED FILE -- do not edit by hand.
	Source:    CraftRoute by Kitymeowmeow (GPLv3), data_{key}.lua
	Generator: Tools/build/import_recipes.py

	One recipe a line, ordered by the skill it turns orange at:

	  "<recipe> = <reagents> @ <orange>-<yellow>-<green>-<grey> | <learned> [| skip] [| nomake]"

	Reagents are joined by " + ", each with its count in front when that is
	more than one; "#<id>" is an item no database could name, which the game
	names once it has seen it. <learned> is how the recipe is learned:
	"trainer <copper>", "book <item> <copper>" or "book <item> ?", "quest",
	"drop" or "special"; a ~ marks an estimated cost. "skip" keeps a recipe
	out of routes (cooldowns, rare drops); "nomake" stops the planner making
	it to supply another recipe. Tools/build/import_recipes.py documents each.
]]

AegisPathfinder:RegisterRecipeBook({qtitle}, {{
"""


def write_book(key, title, lines, check):
    out = HEADER.format(title=title, key=key, qtitle=lua_string(title))
    out += "".join("\t%s,\n" % lua_string(line) for line in lines)
    out += "})\n"
    path = os.path.join(OUTDIR, title + ".lua")
    if not check:
        with open(path, "w", encoding="utf-8") as f:
            f.write(out)
    return path


def write_prices(buy, sell, check):
    out = [
        "--[[",
        "\tWhat merchants charge for reagents and recipes, and pay for what you make,",
        "\tfor the crafting route planner (CraftPlanner.lua). Copper per item.",
        "",
        "\tGENERATED FILE -- do not edit by hand.",
        "\tSource:    CraftRoute by Kitymeowmeow (GPLv3), data_vendorprices.lua and",
        "\t           data_vendorsellprices.lua",
        "\tGenerator: Tools/build/import_recipes.py",
        "",
        "\tA sell price of 0 is real: no merchant will buy the item. An item missing",
        "\tfrom `sell` has no confirmed price, and is never assumed to sell.",
        "]]",
        "",
        "AegisPathfinder:RegisterMerchantPrices({",
        "\tbuy = {",
    ]
    for name in sorted(buy, key=str.lower):
        out.append("\t\t[%s] = %d," % (lua_string(name), buy[name]))
    out.append("\t},")
    out.append("\tsell = {")
    for name in sorted(sell, key=str.lower):
        out.append("\t\t[%s] = %d," % (lua_string(name), sell[name]))
    out.append("\t},")
    out.append("})")
    path = os.path.join(OUTDIR, "Prices.lua")
    if not check:
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(out) + "\n")
    return path


def write_xml(files, check):
    out = ['<Ui xmlns="http://www.blizzard.com/wow/ui/">',
           "\t<!-- GENERATED by Tools/build/import_recipes.py -->"]
    for f in files:
        out.append('\t<Script file="%s"/>' % os.path.basename(f))
    out.append("</Ui>")
    path = os.path.join(OUTDIR, "Crafting.xml")
    if not check:
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(out) + "\n")
    return path


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("craftroute", help="path to a CraftRoute checkout")
    ap.add_argument("--pfquest", help="directory holding pfQuest's items.lua / items-turtle.lua")
    ap.add_argument("--check", action="store_true", help="validate only; write nothing")
    args = ap.parse_args()

    src_dir = args.craftroute
    id_names, case = load_cache()
    pf = read_pfquest_names(args.pfquest) if args.pfquest else None

    books = {}
    for key, title in PROFESSIONS:
        with open(os.path.join(src_dir, "data_%s.lua" % key), encoding="utf-8") as f:
            books[key] = read_table_after(f.read(), 'CraftRoute_Data["%s"] =' % key)

    ids = {r["itemId"] for recipes in books.values() for x in recipes
           for r in x["reagents"] if r.get("itemId") and not r.get("name")}
    if pf:
        id_names = {i: pf[i] for i in ids if i in pf}

    buy = read_prices(os.path.join(src_dir, "data_vendorprices.lua"), "CraftRoute_VendorPrices")
    sell = read_prices(os.path.join(src_dir, "data_vendorsellprices.lua"), "CraftRoute_VendorSellPrices")

    # Merchant prices are keyed in lower case; give them their in-game
    # spelling, from the recipe data first and then pfQuest.
    spelled = {}
    for recipes in books.values():
        for r in recipes:
            spelled[r["name"].lower()] = r["name"]
            if r.get("scrollName"):
                spelled[r["scrollName"].lower()] = r["scrollName"]
            for x in r["reagents"]:
                name = x.get("name") or id_names.get(x.get("itemId"))
                if name:
                    spelled[name.lower()] = name
    if pf:
        by_lower = {}
        for i in sorted(pf):
            by_lower.setdefault(pf[i].lower(), pf[i])
        case = {n: by_lower[n] for n in list(buy) + list(sell)
                if n not in spelled and n in by_lower}

    def spell(n):
        return spelled.get(n) or case.get(n) or n

    buy = {spell(n): p for n, p in buy.items()}
    sell = {spell(n): p for n, p in sell.items()}

    missing, corrected = set(), []
    written, total = [], 0
    for key, title in PROFESSIONS:
        recipes = books[key]
        seen = set()
        for r in recipes:
            if r["name"] in seen:
                raise ValueError("%s: %s appears twice" % (title, r["name"]))
            seen.add(r["name"])
        ordered = sorted(recipes, key=lambda r: (int(r["orange"]), int(r["grey"]), r["name"]))
        lines = [recipe_line(r, id_names, missing, corrected) for r in ordered]
        written.append(write_book(key, title, lines, args.check))
        total += len(lines)
        print("%-15s %4d recipes" % (title, len(lines)))

    for c in corrected:
        print("  thresholds levelled: " + c)
    if missing:
        print("  no name for item id%s %s: written as #<id>, named by the game at run time" % (
            "s" if len(missing) > 1 else "", ", ".join(str(i) for i in sorted(missing))))

    written.append(write_prices(buy, sell, args.check))
    write_xml(written, args.check)
    unspelled = [n for n in list(buy) + list(sell) if n == n.lower() and n.upper() != n]
    print("%d recipes, %d merchant buy prices, %d sell prices (%d left in lower case)" % (
        total, len(buy), len(sell), len(unspelled)))

    if pf and not args.check:
        save_cache(id_names, case)
    if args.check:
        print("check only: nothing written")


if __name__ == "__main__":
    main()
