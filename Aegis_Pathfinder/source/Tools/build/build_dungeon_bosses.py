#!/usr/bin/env python3
"""Gather each dungeon guide's bosses, and what they do, into
Tools/data/dungeon_bosses.json, for the boss steps build_dungeon_guides.py
writes and the notes in dungeon_tactics.py.

    python3 Tools/build/build_dungeon_bosses.py --instancejournal DIR --cmangos FILE --scripts DIR

  * The bosses, in order, are InstanceJournal's
    (https://github.com/Arthur-Helias/InstanceJournal, public domain), with
    the abilities it has written up -- what each does, and flags for who it
    matters to.
  * For the original game's bosses, CMaNGOS: classic-db (FILE, the .sql or
    .sql.gz dump) gives each boss's spells -- its spell list, its spells and
    its EventAI casts, whose comments say when ("at 50% HP") -- and
    mangos-classic's ScriptDevAI scripts (DIR,
    src/game/AI/ScriptDevAI/scripts) the spells and adds a scripted fight
    uses. Each spell is described from classic-db's spell table: its school,
    what it dispels as, its mechanic (fear, stun, sleep ...), whom it hits
    (its target, everyone near, everyone in front) and whether it can be
    interrupted.

Turtle WoW's own bosses are in InstanceJournal only, and most have no
abilities written up there yet.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "Tools", "data", "dungeon_bosses.json")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Lua that prints InstanceJournal's dungeons -- bosses, abilities, flags --
# as JSON, from its data files and English text.
JOURNAL_DUMP = r"""
local ij = arg[1]
function GetLocale() return "enUS" end
dofile(ij .. "/locale/InstanceJournal-enUS.lua")
dofile(ij .. "/InstanceJournalLib.lua")
IJDB = IJDB or {}
dofile(ij .. "/InstanceJournalDB.lua")
local any = setmetatable({}, { __index = function(_, k) return { id = k } end })
IJDB.I, IJDB.Q, IJDB.N = any, any, any
local flagName = {}
for k, v in pairs(IJLib.AbilityFlags) do flagName[v] = k end
local function str(s)
	s = tostring(s or "")
	s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
	s = string.gsub(s, "|r", "")
	s = string.gsub(s, "\\", "\\\\")
	s = string.gsub(s, '"', '\\"')
	s = string.gsub(s, "\r", "")
	s = string.gsub(s, "\n", "\\n")
	return '"' .. s .. '"'
end
local out = {}
for line in io.lines(ij .. "/InstanceJournal.toc") do
	local _, _, f = string.find(line, "^db\\dungeons\\(.+)%.lua")
	if f then
		local before = {}
		for k in pairs(IJDB.DG or {}) do before[k] = true end
		dofile(ij .. "/db/dungeons/" .. f .. ".lua")
		for key, d in pairs(IJDB.DG) do
			if not before[key] then
				local bosses = {}
				for _, b in ipairs(d.Bosses or {}) do
					local abil = {}
					for _, a in ipairs(b.Abilities or {}) do
						local fl = {}
						for _, x in ipairs(a.Flags or {}) do table.insert(fl, str(flagName[x] or "?")) end
						table.insert(abil, string.format('{"name":%s,"effect":%s,"flags":[%s]}',
							str(a.Name), str(a.Effect), table.concat(fl, ",")))
					end
					table.insert(bosses, string.format('{"id":%s,"name":%s,"rare":%s,"abilities":[%s]}',
						str(b.Id), str(b.Name), tostring(b.IsRare == true), table.concat(abil, ",")))
				end
				table.insert(out, string.format('%s:{"name":%s,"bosses":[%s]}', str(f), str(d.Name),
					table.concat(bosses, ",")))
			end
		end
	end
end
io.write("{" .. table.concat(out, ",") .. "}")
"""


def journal(path):
    """InstanceJournal's dungeons by data file: {file: {name, bosses}}."""
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as fh:
        fh.write(JOURNAL_DUMP)
        script = fh.name
    try:
        out = subprocess.run(["lua5.1", script, path], capture_output=True, text=True)
    finally:
        os.unlink(script)
    if out.returncode != 0:
        sys.exit(out.stderr.strip() or "lua5.1 could not read InstanceJournal")
    return json.loads(out.stdout)


EFFECT = {2: "damage", 5: "teleport", 8: "power drain", 9: "leech", 10: "heal", 17: "weapon damage",
          28: "summon", 29: "leap", 30: "energize", 31: "weapon damage", 38: "dispel", 41: "summon",
          42: "summon", 56: "summon", 58: "weapon damage", 62: "power burn", 63: "threat", 68: "interrupt",
          74: "summon", 87: "summon", 88: "summon", 89: "summon", 90: "summon", 97: "summon",
          98: "knockback", 121: "weapon damage", 125: "threat"}
AURA = {3: "dot", 5: "confuse", 6: "charm", 7: "fear", 8: "hot", 12: "stun", 13: "damage done",
        15: "thorns", 22: "resistance", 25: "pacify", 26: "root", 27: "silence", 31: "speed", 33: "slow",
        36: "stance", 39: "immune", 53: "leech", 56: "transform", 60: "pacify", 64: "mana leech",
        65: "cast speed", 67: "disarm", 69: "absorb", 79: "damage done", 87: "damage taken", 89: "dot",
        101: "resistance", 118: "healing taken", 138: "haste", 47: "parry", 49: "dodge", 29: "stats",
        99: "attack power", 84: "regen"}
MECHANIC = {1: "charm", 2: "disorient", 3: "disarm", 5: "fear", 7: "root", 9: "silence", 10: "sleep",
            11: "snare", 12: "stun", 13: "freeze", 14: "knockout", 15: "bleed", 17: "polymorph",
            18: "banish", 20: "shackle", 24: "horror"}
DISPEL = {1: "Magic", 2: "Curse", 3: "Disease", 4: "Poison"}
SCHOOL = {0: "Physical", 1: "Holy", 2: "Fire", 3: "Nature", 4: "Frost", 5: "Shadow", 6: "Arcane"}
ENEMY_AREA = {8, 15, 16, 28, 52, 53}     # everyone round a point
CONE = {24, 54}                          # everyone in front
FRIENDS = {20, 21, 30, 31, 33, 37, 57}   # the caster's allies


def num(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


class CMaNGOS:
    def __init__(self, dump, scripts):
        from build_gathering import Dump
        db = Dump(dump)
        self.creature = {num(r["Entry"]): r for r in db.rows("creature_template")}
        self.spell_list = {}
        for r in db.rows("creature_spell_list"):
            self.spell_list.setdefault(num(r["Id"]), []).append(r)
        self.template_spells = {}
        for r in db.rows("creature_template_spells"):
            self.template_spells.setdefault(num(r["entry"]), []).extend(
                num(r["spell%d" % i]) for i in range(1, 11) if num(r["spell%d" % i]))
        self.eventai = {}
        for r in db.rows("creature_ai_scripts"):
            self.eventai.setdefault(num(r["creature_id"]), []).append(r)
        self.spells = {num(r["Id"]): r for r in db.rows("spell_template")}
        self.scripts = {}
        for base, _, files in os.walk(scripts):
            for f in files:
                if f.endswith((".cpp", ".h")):
                    p = os.path.join(base, f)
                    self.scripts[p] = open(p, encoding="utf-8", errors="replace").read()

    def enums(self, path):
        vals = {}
        for p in (path, path[:-4] + ".h"):
            for m in re.finditer(r"\b((?:SPELL|NPC)_[A-Z0-9_]+)\s*=\s*(\d+)\s*,?[ \t]*(//[^\n]*)?",
                                 self.scripts.get(p, "")):
                vals[m.group(1)] = (int(m.group(2)), (m.group(3) or "").strip("/ ").strip())
        return vals

    def script(self, name):
        """The spells and creatures a ScriptDevAI script's own AI names, by
        their enum: [(symbol, id, comment)], and its file."""
        for path, text in self.scripts.items():
            m = re.search(r'pNewScript->Name\s*=\s*"%s"\s*;' % re.escape(name), text)
            if not m:
                continue
            block = text[m.start():m.start() + 600]
            g = (re.search(r"GetAI\s*=\s*&GetNewAIInstance<(\w+)>", block)
                 or re.search(r"GetAI\s*=\s*&(\w+)", block))
            body = text
            if g:
                struct = g.group(1)
                d = re.search(r"%s\s*\([^)]*\)\s*\{[^}]*new\s+(\w+)" % re.escape(struct), text)
                struct = d.group(1) if d else struct
                s = re.search(r"struct\s+%s\b[^{;]*\{" % re.escape(struct), text)
                if s:
                    depth, i = 0, s.end() - 1
                    while i < len(text):
                        depth += {"{": 1, "}": -1}.get(text[i], 0)
                        if depth == 0:
                            break
                        i += 1
                    body = text[s.start():i]
            vals = self.enums(path)
            used = sorted(set(re.findall(r"\b((?:SPELL|NPC)_[A-Z0-9_]+)\b", body)))
            return os.path.basename(path), [(u,) + vals[u] for u in used if u in vals]
        return None, []

    def describe(self, sid, depth=0):
        s = self.spells.get(sid)
        if not s:
            return None
        out = {"id": sid, "name": s["SpellName"], "school": SCHOOL.get(num(s["School"]), "?")}
        if num(s["Dispel"]) in DISPEL:
            out["dispel"] = DISPEL[num(s["Dispel"])]
        mech = MECHANIC.get(num(s["Mechanic"]))
        what, more = set(), []
        for i in (1, 2, 3):
            e = num(s["Effect%d" % i])
            if not e:
                continue
            targets = {num(s["EffectImplicitTargetA%d" % i]), num(s["EffectImplicitTargetB%d" % i])}
            who = ("self" if targets <= {0, 1} else "in front" if targets & CONE else
                   "near" if targets & ENEMY_AREA else "allies" if targets & FRIENDS else "target")
            if e in (6, 35):
                kind = AURA.get(num(s["EffectApplyAuraName%d" % i]))
                if num(s["EffectApplyAuraName%d" % i]) in (23, 42) and depth < 2:
                    t = self.describe(num(s["EffectTriggerSpell%d" % i]), depth + 1)
                    if t:
                        more.append(t)
            else:
                kind = EFFECT.get(e)
                if e == 64 and depth < 2:
                    t = self.describe(num(s["EffectTriggerSpell%d" % i]), depth + 1)
                    if t:
                        more.append(t)
            if kind:
                what.add("%s (%s)" % (kind, who))
            mech = mech or MECHANIC.get(num(s["EffectMechanic%d" % i]))
        if mech:
            out["mechanic"] = mech
        out["does"] = sorted(what)
        cast = num(s["CastingTimeIndex"]) > 1
        channel = bool(num(s["AttributesEx"]) & 0x44)
        if num(s["InterruptFlags"]) & 8 and (cast or channel):
            out["interruptible"] = True
        if more:
            out["then"] = more
        return out

    def boss(self, entry):
        """What CMaNGOS has for a boss: its name, rank and level, its spells,
        when it casts them, and what it summons. None if it has no such
        creature -- one of Turtle WoW's own."""
        t = self.creature.get(entry)
        if not t:
            return None
        found = {}
        for r in self.spell_list.get(num(t["SpellList"]), []):
            found.setdefault(num(r["SpellId"]), set()).add(r["Comments"])
        for sid in self.template_spells.get(entry, []):
            found.setdefault(sid, set())
        summons = []
        for r in self.eventai.get(entry, []):
            for a in (1, 2, 3):
                kind = num(r["action%d_type" % a])
                if kind == 11:
                    found.setdefault(num(r["action%d_param1" % a]), set()).add(r["comment"])
                elif kind == 12:
                    summons.append(r["comment"])
        out = {"creature": t["Name"], "level": [num(t["MinLevel"]), num(t["MaxLevel"])]}
        if t["ScriptName"]:
            f, used = self.script(t["ScriptName"])
            out["script"] = f
            for sym, val, comment in used:
                if sym.startswith("SPELL_"):
                    found.setdefault(val, set()).add("%s%s" % (sym, " (%s)" % comment if comment else ""))
                elif val in self.creature:
                    summons.append("%s: %s" % (sym, self.creature[val]["Name"]))
        spells = []
        for sid, when in sorted(found.items()):
            d = self.describe(sid)
            if d:
                d["when"] = sorted(w for w in when if w)
                spells.append(d)
        out["spells"] = spells
        if summons:
            out["summons"] = sorted(set(summons))
        return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--instancejournal", required=True, help="an InstanceJournal checkout")
    ap.add_argument("--cmangos", required=True, help="classic-db's dump, .sql or .sql.gz")
    ap.add_argument("--scripts", required=True, help="mangos-classic's src/game/AI/ScriptDevAI/scripts")
    args = ap.parse_args()
    import build_dungeon_guides as guides
    ij = journal(args.instancejournal)
    cm = CMaNGOS(args.cmangos, args.scripts)
    out = {}
    for code, d in guides.DUNGEONS.items():
        bosses = []
        for f in d["journal"]:
            wing = ij[f]
            for b in wing["bosses"]:
                entry = {"id": b["id"], "name": b["name"], "wing": wing["name"], "rare": b["rare"],
                         "journal": b["abilities"]}
                found = cm.boss(num(b["id"]))
                if found:
                    entry.update(found)
                bosses.append(entry)
        out[code] = bosses
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, indent=1, sort_keys=True, ensure_ascii=False)
        fh.write("\n")
    n = sum(len(b) for b in out.values())
    known = sum(1 for b in out.values() for x in b if x["journal"] or x.get("spells"))
    print("wrote %s: %d bosses, %d with abilities" % (os.path.relpath(OUT, ROOT), n, known))


if __name__ == "__main__":
    main()
