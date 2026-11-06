#!/usr/bin/env python3
"""Add the filter tags a person approved to the Optimized and zone guides.

    python3 Tools/build/apply_filter_tags.py                      # add them
    python3 Tools/build/apply_filter_tags.py --check              # report any missing
    python3 Tools/build/apply_filter_tags.py --pfquest DIR [DIR]  # recompute follow-ups first

Tools/build/find_filter_candidates.py lists the steps that probably want an |AH|,
|P|GROUP| or |D|<code>| tag into Tools/data/filter_candidates.json; the
answers -- which of each item's suggested tags to add -- are in
Tools/data/filter_decisions.json. A "yes" adds the tag; a "no" -- an answer
changed after the tags went in -- takes it off again; "steps" tags only the
steps shown that are not the quest's own (the "buy it on the Auction House"
note, not the quest you can also do by farming what it asks for).

What a "yes" covers depends on what the evidence was:

  * The quest itself -- one of its accept, kill, complete or turn-in steps:
    the tag goes on every step of that quest in the guides reviewed, as the
    review page promised, so a solo player never accepts a group quest they
    cannot finish.
  * Only a note, a run or a buy step that happens to carry a quest id ("Keep
    Pages", "Buy a Bronze Tube"): just the steps that were shown. The quest
    id there is incidental, and tagging the whole quest would hide one
    nobody reviewed.

A quest you can only pick up after a tagged one inherits its tag: with the
first hidden, nobody can accept the rest. Those follow-ups are worked out
from pfQuest's prerequisites (--pfquest: pfQuest's and pfQuest-turtle's
checkouts, or a folder of their db files with "/" as "_") and kept in the
decisions file with the quest they follow, so applying needs no database.

Each listed step is found by its line and checked against its title before
anything is written, so a guide edited since the review is reported rather
than tagged in the wrong place. Running it twice changes nothing.
"""

import json
import os
import re
import sys

from find_filter_candidates import ACTIONS

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CANDIDATES = os.path.join(ROOT, "Tools", "data", "filter_candidates.json")
DECISIONS = os.path.join(ROOT, "Tools", "data", "filter_decisions.json")
TARGETS = ["Guides/Optimized/Alliance", "Guides/Optimized/Horde",
           "Guides/Alliance", "Guides/Horde", "Guides/Both"]
QUEST_ACTIONS = {"Accept", "Complete", "Turn in", "Kill"}
# find_filter_candidates.py's names for the guides' action letters, back.
ACTION_LETTER = {name: letter for letter, name in ACTIONS.items()}


def tag_text(tag):
    if tag == "AH":
        return "|AH|"
    if tag == "GROUP":
        return "|P|GROUP|"
    return "|D|%s|" % tag


def has_tag(line, text):
    return (" " + text) in line or line.startswith(text)


def add_tag(line, text):
    """Before the step's zone tag, where the RestedXP guides put theirs;
    else at the end."""
    if has_tag(line, text):
        return line
    z = line.rfind(" |Z|")
    if z >= 0:
        return line[:z] + " " + text + line[z:]
    return line.rstrip() + " " + text


def approved(decisions, item_id, answer="yes"):
    return sorted(t for t, v in decisions.get(item_id, {}).items() if v == answer)


def quest_level(item):
    return bool(item.get("qid")) and any(s["action"] in QUEST_ACTIONS for s in item["steps"])


def find_step(lines, step, qid):
    """The reviewed step's line: where it was, or -- if the guide has been
    edited since -- the one line in the file with the same action, title and
    quest id. None when it is gone or can no longer be told apart."""
    def same(line):
        head = "%s %s" % (ACTION_LETTER.get(step["action"], "?"), step["title"])
        return line.startswith(head) and (not qid or "|QID|%d" % qid in line)
    i = step["line"] - 1
    if i < len(lines) and same(lines[i]):
        return i
    hits = [j for j, line in enumerate(lines) if same(line)]
    return hits[0] if len(hits) == 1 else None


def guide_files():
    for folder in TARGETS:
        for name in sorted(os.listdir(os.path.join(ROOT, folder))):
            if name.endswith(".lua"):
                yield folder + "/" + name


# --------------------------------------------------------------------------
# Follow-ups
# --------------------------------------------------------------------------

def pfquest_pre(directories):
    """quest id -> [prerequisite quest ids], pfQuest-turtle's over pfQuest's."""
    out = {}
    for name in ("db_quests.lua", "db_quests-turtle.lua"):
        path = None
        for d in directories:
            for p in (os.path.join(d, name), os.path.join(d, *name.split("_"))):
                if os.path.exists(p):
                    path = p
        if not path:
            sys.exit("missing pfQuest file: %s" % name.replace("_", "/"))
        with open(path, encoding="utf-8", errors="replace") as fh:
            src = fh.read()
        for m in re.finditer(r"\n  \[(\d+)\] = \{(.*?)\n  \},", src, re.S):
            pre = re.search(r'\["pre"\] = \{([^}]*)\}', m.group(2))
            out[int(m.group(1))] = [int(x) for x in re.findall(r"\d+", pre.group(1))] if pre else []
    return out


def followups(items, decisions, pre):
    """"q<id>" -> {tag: "q<id> it follows"} for each quest in the guides whose
    prerequisites lead back to a quest tagged whole."""
    tagged = {}
    for item in items:
        if quest_level(item):
            for t in approved(decisions, item["id"]):
                tagged.setdefault(item["qid"], set()).add(t)
    present = set()
    for path in guide_files():
        with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
            present.update(int(q) for q in re.findall(r"\|QID\|(\d+)", fh.read()))
    out = {}
    for q in sorted(present):
        if q in tagged:
            continue
        seen, stack = set(), list(pre.get(q, []))
        while stack:
            p = stack.pop()
            if p not in seen:
                seen.add(p)
                stack.extend(pre.get(p, []))
        for p in sorted(seen):
            for t in sorted(tagged.get(p, ())):
                out.setdefault("q%d" % q, {}).setdefault(t, "q%d" % p)
    return out


# --------------------------------------------------------------------------

def main():
    args = sys.argv[1:]
    check = "--check" in args
    with open(CANDIDATES, encoding="utf-8") as fh:
        items = json.load(fh)["items"]
    with open(DECISIONS, encoding="utf-8") as fh:
        record = json.load(fh)
    decisions = record["decisions"]

    # Follow-ups a changed answer no longer covers lose the tag they had.
    dropped = {}
    if "--pfquest" in args:
        dirs = [a for a in args[args.index("--pfquest") + 1:] if not a.startswith("--")]
        old = record.get("followups", {})
        record["followups"] = followups(items, decisions, pfquest_pre(dirs))
        for qid, tags in old.items():
            gone = sorted(set(tags) - set(record["followups"].get(qid, {})))
            if gone:
                dropped[qid] = gone
        with open(DECISIONS, "w", encoding="utf-8") as fh:
            json.dump(record, fh, indent=1, ensure_ascii=False)
            fh.write("\n")
        print("%d follow-up quest(s) inherit a tag; %d no longer do"
              % (len(record["followups"]), len(dropped)))

    files, problems, wanted, unwanted = {}, [], {}, {}

    def load(path):
        if path not in files:
            with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
                files[path] = fh.read().split("\n")
        return files[path]

    def want(target, tags, into):
        into.setdefault(target, [])
        for t in tags:
            if tag_text(t) not in into[target]:
                into[target].append(tag_text(t))

    def whole_quest(qid, tags, into):
        pat = re.compile(r"\|QID\|%d(?:\.\d+)?\|" % qid)
        for path in guide_files():
            for i, line in enumerate(load(path)):
                if pat.search(line):
                    want((path, i), tags, into)

    for answer, into in (("yes", wanted), ("no", unwanted), ("steps", wanted)):
        for item in items:
            tags = approved(decisions, item["id"], answer)
            if not tags:
                continue
            for step in item["steps"]:
                if answer == "steps" and step["action"] in QUEST_ACTIONS:
                    continue
                i = find_step(load(step["file"]), step, item.get("qid"))
                if i is None:
                    problems.append("%s:%d no longer reads \"%s\" -- re-run find_filter_candidates.py"
                                    % (step["file"], step["line"], step["title"]))
                    continue
                want((step["file"], i), tags, into)
            if quest_level(item):
                # A "steps" answer takes the tag off the quest's own steps.
                whole_quest(item["qid"], tags, unwanted if answer == "steps" else into)

    for qid, tags in sorted(record.get("followups", {}).items()):
        whole_quest(int(qid[1:]), sorted(tags), wanted)
    for qid, tags in sorted(dropped.items()):
        whole_quest(int(qid[1:]), tags, unwanted)

    missing, stale, changed = 0, 0, set()
    for (path, i), texts in sorted(wanted.items()):
        lines = files[path]
        for text in texts:
            if not has_tag(lines[i], text):
                missing += 1
                if not check:
                    lines[i] = add_tag(lines[i], text)
                    changed.add(path)
    for (path, i), texts in sorted(unwanted.items()):
        lines = files[path]
        for text in texts:
            # Another "yes" -- or a follow-up -- may still want it here.
            if has_tag(lines[i], text) and text not in wanted.get((path, i), []):
                stale += 1
                if not check:
                    lines[i] = lines[i].replace(" " + text, "", 1)
                    changed.add(path)

    for msg in problems:
        print("  ! " + msg)
    if check:
        print("%d step(s) approved for tags; %d tag(s) missing, %d withdrawn but still there"
              % (len(wanted), missing, stale))
        return 1 if (missing or stale or problems) else 0
    for path in sorted(changed):
        with open(os.path.join(ROOT, path), "w", encoding="utf-8") as fh:
            fh.write("\n".join(files[path]))
    print("%d step(s) approved for tags; added %d tag(s), removed %d, across %d guide(s)"
          % (len(wanted), missing, stale, len(changed)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
