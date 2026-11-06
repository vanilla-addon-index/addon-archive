"""Synchronize Turtle-custom item buy and sell prices into core/pricedata.lua.

Uses the read-only indexed Turtle database snapshot. Existing non-custom rows
are retained; every item marked custom is added or updated from that snapshot.
"""
import os
import re
import sqlite3
import urllib.parse


HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
GAME = os.path.dirname(os.path.dirname(os.path.dirname(ADDON)))
DATABASE = os.path.join(GAME, "#Addons-dev", "diagnostics", "turtle_wow_db_indexed", "tortoise.sqlite")
TARGET = os.path.join(ADDON, "core", "pricedata.lua")
ROW = re.compile(r'(\[(\d+)\]\s*=\s*")(\d+),(\d+)(")')


def turtle_prices():
    uri = "file:" + urllib.parse.quote(DATABASE.replace("\\", "/"), safe="/:\\") + "?mode=ro"
    connection = sqlite3.connect(uri, uri=True)
    try:
        return dict((int(entry), (int(sell), int(buy or 0)))
                    for entry, sell, buy in connection.execute(
                        "SELECT entry, sell_price, buy_price FROM items "
                        "WHERE custom = 1 AND entry > 0 AND sell_price IS NOT NULL"))
    finally:
        connection.close()


def main():
    prices = turtle_prices()
    with open(TARGET, encoding="utf-8", newline="") as handle:
        text = handle.read()
    seen = set()
    updated = [0]

    def replace(match):
        entry = int(match.group(2))
        value = prices.get(entry)
        if value is None:
            return match.group(0)
        seen.add(entry)
        sell, buy = value
        if int(match.group(3)) != sell or int(match.group(4)) != buy:
            updated[0] += 1
        return match.group(1) + str(sell) + "," + str(buy) + match.group(5)

    text = ROW.sub(replace, text)
    missing = sorted(set(prices) - seen)
    if missing:
        end = text.rfind("\n}")
        if end < 0:
            raise RuntimeError("pricedata table terminator not found")
        rows = []
        for index in range(0, len(missing), 6):
            chunk = missing[index:index + 6]
            rows.append("  " + " ".join("[%d]=\"%d,%d\"," % (entry, prices[entry][0], prices[entry][1])
                                           for entry in chunk))
        text = text[:end] + "\n" + "\n".join(rows) + text[end:]
    with open(TARGET, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("Turtle custom prices: %d added, %d updated, %d total" %
          (len(missing), updated[0], len(prices)))


if __name__ == "__main__":
    main()
