"""Test fuer octo_import.py: Ortsnummer des Exports als Rueckfall.

Hailar the Frigid (Belt of Binding, 33 %) steht nicht in pfQuest. Seine
Beute hatte deshalb keinen Ort und fiel aus dem Wegplan, waehrend
turtlelootline.com sie unter Frostmane Hollow fuehrt.
"""
import json, os, sys, tempfile
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import octo_import as oi

bad = 0
def check(c, m):
    global bad
    if not c:
        bad += 1; print("FEHLER:", m)

def mob(i, loc):
    return {"id": i, "name": "Mob %d" % i, "location": [loc], "percent": 1}

rows = [
    # 229: vier verortete Gegner in BRS, einer nicht verortet
    {"id": 1, "sources": {"dropped-by": [mob(10, 229), mob(11, 229), mob(12, 229), mob(13, 229), mob(14, 229)]}},
    # 33: uneindeutig, 2 gegen 2
    {"id": 2, "sources": {"dropped-by": [mob(20, 33), mob(21, 33), mob(22, 33), mob(23, 33), mob(24, 33)]}},
    # 822: niemand verortet -> eigene Nummer
    {"id": 3, "sources": {"dropped-by": [mob(63130, 822)]}},
    # 0 zaehlt nie
    {"id": 4, "sources": {"dropped-by": [mob(11502, 0)]}},
    # derselbe Gegner zaehlt nur einmal
    {"id": 5, "sources": {"dropped-by": [mob(10, 229)]}},
]
unit_zones = {10: 1583, 11: 1583, 12: 1583, 13: 1583, 20: 33, 21: 33, 22: 1, 23: 1}
zone_names = {1583: "Blackrock Spire", 33: "Stranglethorn Vale", 1: "Dun Morogh", 229: "Wrong"}

tmp = tempfile.mkdtemp()
path = os.path.join(tmp, "x.jsonl")
with open(path, "w", encoding="utf-8") as fh:
    for r in rows:
        fh.write(json.dumps(r) + "\n")

import io, contextlib
with contextlib.redirect_stdout(io.StringIO()):
    loc, stats = oi.vote_locations([path], unit_zones, zone_names)
check(loc.get(229) == 1583, "229 muss per Abstimmung Blackrock Spire werden, nicht pfQuests 'Wrong'")
check(33 not in loc, "33 ist uneindeutig und darf nicht zugeordnet werden")
check(loc.get(822) == 822, "822 ohne Stimmen behaelt die eigene Nummer")
check(0 not in loc, "Ortsnummer 0 wird nie zugeordnet")
check(oi.LOCATION_NAMES.get(822) == "Frostmane Hollow", "822 heisst Frostmane Hollow")

# build_sources: pfQuest > Ortsnummer > BOSS_ZONES
geo = (unit_zones, {}, {}, {}, zone_names, loc)
zu, nu = {}, {}
out = oi.build_sources(rows[0], geo, zu, nu)
zs = [r.get("z") for r in out["d"]]
check(all(z == 1583 for z in zs), "unverorteter Gegner 14 muss ueber 229 in BRS landen: %s" % zs)
out = oi.build_sources(rows[2], geo, zu, nu)
check(out["d"][0].get("z") == 822, "Hailar muss in 822 stehen")
out = oi.build_sources(rows[3], geo, zu, nu)
check(out["d"][0].get("z") == 2717, "Ragnaros ueber BOSS_ZONES in Molten Core")
print("ALLE TESTS OK" if bad == 0 else "TESTS FEHLGESCHLAGEN")
