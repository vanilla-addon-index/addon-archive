"""Test fuer octodb_build.py: Equip-Effekte, Bedingungen, Setbonus-Artefakt."""
import importlib.util, os
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("b", os.path.join(here, "octodb_build.py"))
b = importlib.util.module_from_spec(spec); spec.loader.exec_module(b)

cases = [
    ("+20 Attack Power.", {"AP": 20}),
    ("Increases ranged attack power by 24.", {"RAP": 24}),
    ("Increased Defense +7.", {"DEFENSE": 7}),
    ("Increases your chance to block attacks with a shield by 1%.", {"BLOCK": 1}),
    ("+72 Attack Power when fighting Beasts.", {}),
    ("+406 Attack Power in Cat, Bear, Dire Bear, and Moonkin forms only.", {}),
    ("Blocking an attack has a 20% chance to grant an Earthen Shield, increasing Defense by 10 for 10 sec.", {}),
    ("Melee attacks against you increase your attack power by 10 for 30 sec. Stacks up to 100 times.", {}),
]
bad = 0
for text, want in cases:
    got = b.equip_to_stats(text)
    if got != want:
        bad += 1; print("FEHLER:", text, "->", got, "erwartet", want)

stats, _ = b.merged_stats({"stats": {"AGI": 45, "AP": 50}, "effects": []})
if "AP" in stats:
    bad += 1; print("FEHLER: Setbonus-AP ohne Effekttext nicht entfernt")
stats, _ = b.merged_stats({"stats": {"AP": 40}, "effects": [{"kind": "equip", "text": "Increases attack power by 40."}]})
if stats.get("AP") != 40:
    bad += 1; print("FEHLER: echte AP doppelt oder verloren:", stats)
print("ALLE TESTS OK" if bad == 0 else "TESTS FEHLGESCHLAGEN")
