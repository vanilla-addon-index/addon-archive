#!/usr/bin/env python3
"""Write SellPrices.lua: what a vendor pays for each item, for the Action
Buttons page's "Delete cheapest item" button (Automation.lua).

1.12 tells an addon nothing about what a vendor pays -- GetItemInfo has no
price, and the vendor window shows one only for what you hover there -- so
the prices come from the CMaNGOS classic database, as pfUI's do: every item
in item_template with a SellPrice. Turtle WoW's own items are not in it; the
button offers those only when they are grey.

  python3 Tools/build/build_sell_prices.py --cmangos path/to/ClassicDB.sql.gz
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_gathering import Dump, num  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "SellPrices.lua")
DEFAULT_DB = os.path.join(os.path.dirname(ROOT), "cmangos", "classic-db", "Full_DB",
                          "ClassicDB_1_12_1_z2815.sql.gz")


def prices(db):
    return {num(r["entry"]): num(r["SellPrice"]) for r in db.rows("item_template") if num(r["SellPrice"]) > 0}


def write(sell):
    lua = [
        "-- SellPrices.lua",
        "--",
        "-- GENERATED FILE -- do not edit by hand.",
        "-- Source:    CMaNGOS classic-db (https://github.com/cmangos/classic-db): item_template.SellPrice",
        "-- Generator: Tools/build/build_sell_prices.py",
        "--",
        "-- What a vendor pays, in copper, for one of each item: 1.12 does not say.",
        "-- Automation.lua's \"Delete cheapest item\" button weighs your bags with it.",
        "",
        "AegisPathfinder.SELL_PRICES = {",
    ]
    ids = sorted(sell)
    for i in range(0, len(ids), 8):
        lua.append("\t" + " ".join("[%d] = %d," % (k, sell[k]) for k in ids[i:i + 8]))
    lua.append("}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lua) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--cmangos", default=DEFAULT_DB, help="the CMaNGOS classic-db dump (.sql or .sql.gz)")
    args = ap.parse_args()
    sell = prices(Dump(args.cmangos))
    write(sell)
    print("wrote %s: vendor prices for %d items" % (os.path.relpath(OUT, ROOT), len(sell)))


if __name__ == "__main__":
    main()
