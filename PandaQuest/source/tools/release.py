"""Validate, prepare and package PandaQuest releases.

  python -B tools/release.py check [--release VERSION]
  python -B tools/release.py notes [VERSION]
  python -B tools/release.py prepare [--minor|--major]
  python -B tools/release.py package [--output PandaQuest.zip]

`prepare` turns "## Unreleased" into the next version and updates every
player-facing version field. Commit the result, create the matching `v*` tag
and push it; GitHub Actions packages the addon and publishes that version's
changelog entry.

`package` zips only the files players need: the runtime folders and the
top-level addon files tracked by Git. Dev tooling, docs and local notes are
left out.
"""

import argparse
import re
import subprocess
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON = "pandaQuest"
CHANGELOG = ROOT / "CHANGELOG.md"
TOC = ROOT / (ADDON + ".toc")
NAMESPACE = ROOT / "Core" / "Namespace.lua"
README = ROOT / "README.md"

# Everything the client loads at runtime, plus the licence and player docs.
RUNTIME_DIRS = (
    "Compatibility", "Core", "Data", "Database", "HUD", "Locales", "Map",
    "Quest", "Tooltip", "World", "media", "Libs",
)
RUNTIME_FILES = (
    ADDON + ".toc", ADDON + ".lua", "LICENSE", "README.md", "CHANGELOG.md",
)
# Runtime textures must be TGA or BLP; fonts and attribution files ship too.
MEDIA_EXTENSIONS = (".tga", ".blp", ".ttf", ".md", ".txt")

UNRELEASED = re.compile(r"^## \[?Unreleased\]?\s*$", re.I)
VERSION_HEADING = re.compile(
    r"^## \[?(\d+\.\d+\.\d+)\]?(?: - (\d{4}-\d{2}-\d{2}))?\s*$")


class Entry:
    def __init__(self, version, line):
        self.version = version
        self.line = line
        self.body = []

    def key(self):
        return tuple(int(part) for part in self.version.split("."))

    def text(self):
        return "\n".join(self.body).strip()


def _read(path):
    text = path.read_bytes().decode("utf-8")
    bom = text.startswith("﻿")
    if bom:
        text = text[1:]
    newline = "\r\n" if "\r\n" in text else "\n"
    return text.replace("\r\n", "\n"), bom, newline


def _write(path, text, bom, newline):
    text = text.replace("\n", newline)
    path.write_bytes((("﻿" if bom else "") + text).encode("utf-8"))


def _items(body):
    return [line for line in body if line.startswith("- ")]


def parse(text):
    errors = []
    unreleased = None
    entries = []
    current = None
    seen = set()
    for number, line in enumerate(text.split("\n"), 1):
        if line.startswith("## "):
            if UNRELEASED.match(line):
                if unreleased is not None or entries:
                    errors.append("line %d: Unreleased must be the first section" % number)
                unreleased = []
                current = unreleased
                continue
            match = VERSION_HEADING.match(line)
            if not match:
                errors.append("line %d: unknown section heading %r" % (number, line))
                current = None
                continue
            entry = Entry(match.group(1), number)
            if entry.version in seen:
                errors.append("line %d: duplicate version %s" % (number, entry.version))
            seen.add(entry.version)
            entries.append(entry)
            current = entry.body
        elif current is not None:
            current.append(line)
    if unreleased is None:
        errors.append("missing a '## Unreleased' section")
        unreleased = []
    for newer, older in zip(entries, entries[1:]):
        if newer.key() <= older.key():
            errors.append("line %d: %s is listed above older-or-equal %s"
                          % (newer.line, newer.version, older.version))
    for entry in entries[:1]:
        if not entry.text():
            errors.append("line %d: %s has no changes" % (entry.line, entry.version))
    return unreleased, entries, errors


def _match(path, pattern, label):
    text, _, _ = _read(path)
    match = re.search(pattern, text, re.M)
    if not match:
        raise SystemExit("cannot read %s from %s" % (label, path.relative_to(ROOT)))
    return match.group(1)


VERSION_FIELDS = (
    (TOC, r"^## Version: (\d+\.\d+\.\d+)[ \t]*$", "## Version: %s"),
    (NAMESPACE, r'^PQ\.version\s*=\s*"(\d+\.\d+\.\d+)"', 'PQ.version = "%s"'),
    (README, r"^Current release: (\d+\.\d+\.\d+)[ \t]*$", "Current release: %s"),
)


def project_versions():
    return [(path.relative_to(ROOT).as_posix(), _match(path, pattern, "version"))
            for path, pattern, _ in VERSION_FIELDS]


def load(release=None):
    text, _, _ = _read(CHANGELOG)
    unreleased, entries, errors = parse(text)
    versions = project_versions()
    current = versions[0][1]
    for path, version in versions:
        if version != current:
            errors.append("%s is %s but %s is %s" % (path, version, versions[0][0], current))
    if entries and entries[0].version != current:
        errors.append("latest changelog version is %s but the addon version is %s"
                      % (entries[0].version, current))
    if release:
        if release != current:
            errors.append("release %s does not match addon version %s" % (release, current))
        if _items(unreleased):
            errors.append("Unreleased still lists changes; run release.py prepare first")
    return current, unreleased, entries, errors


def bumped(version, part):
    major, minor, patch = (int(value) for value in version.split("."))
    if part == "major":
        return "%d.0.0" % (major + 1)
    if part == "minor":
        return "%d.%d.0" % (major, minor + 1)
    return "%d.%d.%d" % (major, minor, patch + 1)


def _fail(errors):
    raise SystemExit("release check failed:\n  " + "\n  ".join(errors))


def prepare(part):
    version, unreleased, _, errors = load()
    if errors:
        _fail(errors)
    if not _items(unreleased):
        raise SystemExit("Unreleased lists no changes: nothing to release")
    new_version = bumped(version, part)

    text, bom, newline = _read(CHANGELOG)
    lines = text.split("\n")
    start = next(i for i, line in enumerate(lines) if UNRELEASED.match(line))
    end = start + 1
    while end < len(lines) and not lines[end].startswith("## "):
        end += 1
    body = "\n".join(lines[start + 1:end]).strip("\n")
    output = lines[:start + 1] + ["", "## " + new_version, "", body, ""] + lines[end:]
    _write(CHANGELOG, "\n".join(output), bom, newline)

    for path, pattern, template in VERSION_FIELDS:
        source, bom, newline = _read(path)
        source, count = re.subn(pattern, template % new_version, source, count=1, flags=re.M)
        if count != 1:
            raise SystemExit("cannot update %s" % path.relative_to(ROOT))
        _write(path, source, bom, newline)
    print("%s -> %s. Review and commit, then create and push tag v%s."
          % (version, new_version, new_version))


def notes(entries, version):
    for entry in entries:
        if entry.version == version:
            return entry.text() + "\n"
    raise SystemExit("no changelog entry for %s" % version)


def tracked_files():
    try:
        output = subprocess.run(["git", "ls-files", "-z"], cwd=str(ROOT), check=True,
                                stdout=subprocess.PIPE).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        raise SystemExit("cannot list tracked files with git: %s" % error)
    return [name for name in output.decode("utf-8").split("\0") if name]


def player_files():
    files = []
    for name in tracked_files():
        top = name.split("/", 1)[0]
        if name in RUNTIME_FILES or (top in RUNTIME_DIRS and "/" in name):
            files.append(name)
    return sorted(files)


def toc_entries():
    text, _, _ = _read(TOC)
    entries = []
    for line in text.split("\n"):
        line = line.strip()
        if line and not line.startswith("#"):
            entries.append(line.replace("\\", "/"))
    return entries


def check_package(files):
    errors = []
    # The client runs on Windows, so TOC paths match files case-insensitively.
    shipped = set(name.lower() for name in files)
    for entry in toc_entries():
        if entry.lower() not in shipped:
            errors.append("TOC file missing from package: %s" % entry)
    for name in RUNTIME_FILES:
        if name.lower() not in shipped:
            errors.append("required file missing from package: %s" % name)
    for name in files:
        if ((name.startswith("media/") or "/media/" in name.lower())
                and not name.lower().endswith(MEDIA_EXTENSIONS)):
            errors.append("media file the client cannot use: %s" % name)
    listed = set(entry.lower() for entry in toc_entries())
    unlisted = [name for name in files
                if name.lower().endswith(".lua") and name.lower() not in listed
                and name.lower() != ADDON.lower() + ".lua"]
    return errors, unlisted


def package(output):
    files = player_files()
    errors, unlisted = check_package(files)
    for name in unlisted:
        print("warning: %s is not listed in the TOC" % name, file=sys.stderr)
    if errors:
        _fail(errors)
    output = Path(output)
    if not output.is_absolute():
        output = Path.cwd() / output
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(str(output), "w", zipfile.ZIP_DEFLATED) as archive:
        for name in files:
            archive.write(str(ROOT / name), ADDON + "/" + name)
    size = output.stat().st_size / (1024.0 * 1024.0)
    print("%s: %d files, %.1f MB" % (output, len(files), size))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command")
    commands.required = True
    check = commands.add_parser("check")
    check.add_argument("--release")
    show = commands.add_parser("notes")
    show.add_argument("version", nargs="?")
    prep = commands.add_parser("prepare")
    part = prep.add_mutually_exclusive_group()
    part.add_argument("--minor", dest="part", action="store_const", const="minor")
    part.add_argument("--major", dest="part", action="store_const", const="major")
    pack = commands.add_parser("package")
    pack.add_argument("--output", default="PandaQuest.zip")
    args = parser.parse_args()

    if args.command == "prepare":
        prepare(args.part or "patch")
        return
    if args.command == "package":
        package(args.output)
        return
    current, _, entries, errors = load(args.release if args.command == "check" else None)
    if errors:
        _fail(errors)
    if args.command == "check":
        print("CHANGELOG.md: OK (%s)" % current)
    else:
        sys.stdout.write(notes(entries, args.version or current))


if __name__ == "__main__":
    main()
