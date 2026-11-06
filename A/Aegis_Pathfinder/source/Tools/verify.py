#!/usr/bin/env python3
"""Offline verification for AEGIS: Pathfinder.

Checks what can be checked without a WoW client:

  syntax   every Lua file parses
  lua50    no Lua 5.1-only constructs that would fail on the 1.12 client
  toc      every file the .toc loads exists, in order
  xml      every Guides.xml lists files that exist, and lists all of them
  theme    no Blizzard chrome or stock icon art on a themed panel
  scope    no bare `Theme` in a file that never declares one
  media    every texture is a TGA the 1.12 client can load
  textures every path Theme.lua hands the client resolves to a real file
  filters  every |C| names classes and every |R| races, as the client does
  zones    every step with coordinates is on a zone the world map knows
  methods  no AegisPathfinder method is defined twice, except as a wrapper

Run from the repository root:  python3 Tools/verify.py
Exits non-zero if any check fails.
"""

import os
import re
import shutil
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAC = "luac5.1"

# Vendored Ace2 libraries are upstream code we do not police.
SKIP_DIRS = {".git", "libs", ".release"}


def walk(exts, skip=SKIP_DIRS):
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in skip]
        for fn in filenames:
            if os.path.splitext(fn)[1] in exts:
                yield os.path.join(dirpath, fn)


def rel(path):
    return os.path.relpath(path, ROOT)


class Report:
    def __init__(self):
        self.failures = []
        self.counts = {}

    def ok(self, check, n):
        self.counts[check] = n

    def fail(self, check, path, detail):
        self.failures.append((check, rel(path) if path else "-", detail))

    def summary(self):
        for check, n in self.counts.items():
            print("  %-8s %d passed" % (check, n))
        if not self.failures:
            print("\nAll checks passed.")
            return 0
        print("\n%d failure(s):\n" % len(self.failures))
        for check, path, detail in self.failures:
            print("  [%s] %s\n      %s" % (check, path, detail))
        return 1


def check_syntax(rep):
    files = sorted(walk({".lua"}))
    for path in files:
        proc = subprocess.run([LUAC, "-p", "-o", os.devnull, path],
                              capture_output=True, text=True)
        if proc.returncode != 0:
            rep.fail("syntax", path, proc.stderr.strip().splitlines()[0])
    rep.ok("syntax", len(files))


# Constructs that parse under 5.1 but are absent from the 5.0 runtime in the
# 1.12 client. Each is (regex, explanation, replacement to use instead).
LUA50_BANNED = [
    (re.compile(r"[^%\w]#[A-Za-z_({\"']"), "# length operator", "table.getn() / string.len()"),
    (re.compile(r"\bstring\.gmatch\b|:gmatch\("), "string.gmatch", "string.gfind()"),
    # Bare select() only. AegisPathfinder.select is the addon's own 5.0-safe
    # shim, so a qualified call is fine.
    (re.compile(r"(?<![.:\w])select\s*\(\s*[\"'#]"), "select()", "explicit named parameters"),
    (re.compile(r"\bmodule\s*\("), "module()", "a plain global table"),
    (re.compile(r"\b\d+//\d+"), "// integer division", "math.floor(a/b)"),
    # 5.1 additions to the standard library: nil on the client.
    (re.compile(r"\bmath\.huge\b"), "math.huge", "a large number, e.g. 1e9"),
    (re.compile(r"\bmath\.fmod\b"), "math.fmod", "math.mod()"),
    (re.compile(r"\btable\.maxn\b"), "table.maxn", "table.getn()"),
    (re.compile(r"\bstring\.match\b|:match\("), "string.match", "string.find() with captures"),
]


def pkgmeta_ignored():
    """Paths .pkgmeta excludes from the packaged addon.

    These are desktop-side tooling (Tools/, docs) that run on a
    normal Lua/Python install and never reach the 1.12 client, so the Lua 5.0
    restrictions do not apply to them.
    """
    path = os.path.join(ROOT, ".pkgmeta")
    if not os.path.exists(path):
        return set()
    body = open(path, encoding="utf-8").read()
    block = re.search(r"^ignore:\s*\n((?:\s+-\s+\S+\n?)+)", body, re.M)
    if not block:
        return set()
    return {m.strip() for m in re.findall(r"-\s+(\S+)", block.group(1))}


def is_shipped(path):
    relative = rel(path)
    for ignored in pkgmeta_ignored():
        if relative == ignored or relative.startswith(ignored.rstrip("/") + os.sep):
            return False
    return True


def _scan_lua(src, keep_strings):
    """Blank out Lua comments, and optionally string literals, in one pass.

    Comments and strings have to be recognised together: a `--` inside a
    string is not a comment, and a quote inside a comment is not a string.
    Stripping them in two separate regex passes got that wrong -- a message
    reading "open -- close one" lost its closing quote to the comment pass,
    and the string pass then ran on across the following lines.

    Newlines are always kept, so a failure still points at the right line.
    """
    out = []
    i, n = 0, len(src)

    def long_bracket(at):
        # "[[", "[=[", ... -> the matching closer, or None if not a long bracket
        m = re.match(r"\[(=*)\[", src[at:])
        return ("]" + m.group(1) + "]", len(m.group(0))) if m else (None, 0)

    def blank(text):
        return "".join(c if c == "\n" else " " for c in text)

    while i < n:
        c = src[i]
        if src.startswith("--", i):
            closer, width = long_bracket(i + 2)
            if closer:
                end = src.find(closer, i + 2 + width)
                end = n if end < 0 else end + len(closer)
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            out.append(blank(src[i:end]))
            i = end
        elif c == "[" and long_bracket(i)[0]:
            closer, width = long_bracket(i)
            end = src.find(closer, i + width)
            end = n if end < 0 else end + len(closer)
            out.append(src[i:end] if keep_strings else '""' + blank(src[i:end])[2:])
            i = end
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            end = min(j + 1, n)
            out.append(src[i:end] if keep_strings else c + c + blank(src[i + 2:end]))
            i = end
        else:
            out.append(c)
            i += 1
    return "".join(out)


def strip_lua_comments(src):
    """Blank out comments, keeping string literals."""
    return _scan_lua(src, keep_strings=True)


def strip_lua_noise(src):
    """Blank out comments and string literals so we only scan real code.

    Use this for checks about Lua syntax. Anything looking for a texture path
    or a frame template name must read the strings, so it wants
    strip_lua_comments instead -- see check_theme.
    """
    return _scan_lua(src, keep_strings=False)


def check_lua50(rep):
    files = [p for p in sorted(walk({".lua"})) if is_shipped(p)]
    for path in files:
        code = strip_lua_noise(open(path, encoding="utf-8", errors="replace").read())
        for lineno, line in enumerate(code.splitlines(), 1):
            for pattern, what, instead in LUA50_BANNED:
                if pattern.search(line):
                    rep.fail("lua50", path,
                             "line %d uses %s (1.12 is Lua 5.0 -- use %s)"
                             % (lineno, what, instead))
    rep.ok("lua50", len(files))


def toc_entries(toc_path):
    for raw in open(toc_path, encoding="utf-8", errors="replace"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        yield line.replace("\\", os.sep)


def check_toc(rep):
    tocs = sorted(walk({".toc"}))
    if not tocs:
        rep.fail("toc", None, "no .toc file found")
        return
    n = 0
    for toc in tocs:
        # WoW requires Interface/AddOns/<Folder>/<Folder>.toc -- the packager
        # supplies the folder name, so the .toc basename must match package-as.
        pkg = os.path.join(ROOT, ".pkgmeta")
        if os.path.exists(pkg):
            m = re.search(r"^package-as:\s*(\S+)", open(pkg).read(), re.M)
            if m and m.group(1) != os.path.splitext(os.path.basename(toc))[0]:
                rep.fail("toc", toc, "basename must match .pkgmeta package-as (%s)" % m.group(1))
        for entry in toc_entries(toc):
            target = os.path.join(os.path.dirname(toc), entry)
            if not os.path.exists(target):
                rep.fail("toc", toc, "missing file: %s" % entry)
            n += 1
    rep.ok("toc", n)


def check_xml(rep):
    n = 0
    for xml in sorted(walk({".xml"})):
        # Key bindings, not a file list: the client reads it by name.
        if os.path.basename(xml) == "Bindings.xml":
            check_bindings(rep, xml)
            continue
        body = open(xml, encoding="utf-8", errors="replace").read()
        listed = set(re.findall(r'<Script\s+file="([^"]+)"', body))
        folder = os.path.dirname(xml)
        for entry in sorted(listed):
            if not os.path.exists(os.path.join(folder, entry)):
                rep.fail("xml", xml, "lists missing file: %s" % entry)
            n += 1
        # A guide file nobody lists never loads -- silent content loss.
        on_disk = {f for f in os.listdir(folder) if f.endswith(".lua")}
        for orphan in sorted(on_disk - listed):
            rep.fail("xml", xml, "file on disk is not listed: %s" % orphan)
    rep.ok("xml", n)


def check_bindings(rep, path):
    body = open(path, encoding="utf-8", errors="replace").read()
    names = re.findall(r'<Binding\s+name="([^"]+)"', body)
    if not names:
        rep.fail("xml", path, "declares no bindings")
    # Each binding needs a label, or the key bindings list shows a blank row.
    code = "\n".join(open(p, encoding="utf-8", errors="replace").read()
                     for p in walk({".lua"}) if is_shipped(p))
    for name in names:
        if not re.search(r"\bBINDING_NAME_%s\s*=" % re.escape(name), code):
            rep.fail("xml", path, "binding %s has no BINDING_NAME_%s" % (name, name))


# Blizzard chrome the reskin replaced. Any of these creeping back means a panel
# has drifted off the theme, which is invisible until someone loads the client.
BLIZZARD_CHROME = [
    (re.compile(r"\bSetBackdrop\s*\("), "SetBackdrop -- use Theme:Panel or Theme:Strip"),
    (re.compile(r"TooltipBorderBG"), "TooltipBorderBG -- use Theme:Panel"),
    (re.compile(r"Interface\\\\DialogFrame"), "Blizzard dialog art -- use Theme:Panel"),
    (re.compile(r"Interface\\\\Buttons\\\\UI-CheckBox"), "Blizzard checkbox -- use Theme:StepCheck"),
    (re.compile(r"Interface\\\\Buttons\\\\UI-Panel-Button"), "Blizzard button art -- use the themed button"),
    (re.compile(r"SetFontObject\s*\(\s*GameFont"), "GameFont object -- use Theme:SetFont"),
    # Templates pull in the same art by name rather than by path, which is how
    # every panel in the addon kept its Blizzard chrome through the first
    # reskin pass: the palette changed underneath, the buttons did not.
    (re.compile(r'"UIPanelButtonTemplate"'), "UIPanelButtonTemplate -- use Theme:PanelButton"),
    (re.compile(r'"UIPanelCloseButton"'), "UIPanelCloseButton -- use Theme:CloseChip"),
    (re.compile(r'"OptionsButtonTemplate"'), "OptionsButtonTemplate -- use Theme:PanelButton"),
    (re.compile(r'"UIPanelScroll(Up|Down)ButtonTemplate"'), "Blizzard scroll button -- use Theme:ScrollBar"),
    (re.compile(r'"UIPanelScroll(Bar|Frame)Template"'), "Blizzard scroll bar -- use Theme:ScrollBar"),
    (re.compile(r"Interface\\\\Buttons\\\\UI-ScrollBar"), "Blizzard scrollbar art -- use Theme:ScrollBar"),
    # Stock icon art: bevelled, bordered, and a different palette to the
    # generated glyphs in media/icons.
    (re.compile(r"Interface\\\\Icons\\\\"), "Blizzard icon art -- use Theme.actionIcon / Theme.glyph"),
    (re.compile(r"Interface\\\\GossipFrame\\\\"), "Blizzard gossip art -- use Theme.actionIcon"),
    (re.compile(r"Interface\\{1,2}QuestFrame\\{1,2}"), "Blizzard quest-log art -- use Theme.texture / Theme.glyph"),
    (re.compile(r"Interface\\{1,2}Minimap\\{1,2}"), "Blizzard minimap-button art -- use the theme's disc and ring"),
]

# The guide browser's pictures are the game's own art by design -- a class
# quest's spell, a profession's icon -- shown as a picture, not as chrome.
THEME_ALLOWED = {
    "GuidePictures.lua": {"Blizzard icon art -- use Theme.actionIcon / Theme.glyph"},
}


def check_theme(rep):
    files = [p for p in sorted(walk({".lua"})) if is_shipped(p)]
    for path in files:
        allowed = THEME_ALLOWED.get(os.path.basename(path), set())
        # Comments only: every pattern here names a texture path or a frame
        # template, and both live inside string literals. Scanning the
        # string-blanked source made this check silently vacuous, which is how
        # a reskinned addon kept drawing Blizzard buttons and quest icons.
        code = strip_lua_comments(open(path, encoding="utf-8", errors="replace").read())
        for lineno, line in enumerate(code.splitlines(), 1):
            for pattern, why in BLIZZARD_CHROME:
                if why not in allowed and pattern.search(line):
                    rep.fail("theme", path, "line %d uses %s" % (lineno, why))
    rep.ok("theme", len(files))


# A bare `Theme` only works in a file that declares `local Theme`: there is no
# global of that name, and Core.lua loads before Theme.lua so it could not have
# one anyway. Three buttons in Core.lua were written as Theme:PanelButton and
# failed on first use, aborting the route and starting-zone dialogs half-built.
BARE_THEME = re.compile(r"(?<![.\w])Theme\s*[:.]")
# Top level only: a `local Theme` inside one function does nothing for the
# rest of the file, and letting it exempt the whole file is how this check
# first passed over the very bug it was written for.
LOCAL_THEME = re.compile(r"^local\s+Theme\s*=", re.M)


def check_theme_scope(rep):
    files = [p for p in sorted(walk({".lua"})) if is_shipped(p)]
    for path in files:
        src = open(path, encoding="utf-8", errors="replace").read()
        if LOCAL_THEME.search(src) or os.path.basename(path) == "Theme.lua":
            continue
        code = strip_lua_noise(src)
        for lineno, line in enumerate(code.splitlines(), 1):
            if BARE_THEME.search(line):
                rep.fail("scope", path,
                         "line %d uses a bare Theme with no `local Theme` in the file "
                         "-- use AegisPathfinder.Theme" % lineno)
    rep.ok("scope", len(files))


def check_media(rep):
    files = sorted(walk({".tga", ".blp"}))
    for path in files:
        if path.endswith(".blp"):
            continue
        with open(path, "rb") as fh:
            header = fh.read(18)
        if len(header) < 18:
            rep.fail("media", path, "truncated TGA header")
            continue
        image_type = header[2]
        width, height, depth = struct.unpack("<HHB", header[12:17])
        if image_type not in (2, 10):
            rep.fail("media", path, "image type %d; 1.12 wants uncompressed/RLE truecolor" % image_type)
        if depth != 32:
            rep.fail("media", path, "%d-bit; 1.12 textures must be 32-bit" % depth)
        for label, value in (("width", width), ("height", height)):
            if value == 0 or (value & (value - 1)) != 0:
                rep.fail("media", path, "%s %d is not a power of two" % (label, value))
        if os.path.basename(path) == "shadow.tga":
            check_shadow_ring(rep, path)
    rep.ok("media", len(files))


def check_shadow_ring(rep, path):
    """The panel shadow must be transparent where the panel is.

    Theme:Panel draws it in the same layer as the fill, and 1.12 does not
    order textures within a layer; the old shadow, darkest in its middle,
    drew a dark square straight through the guide panel. Needs Pillow, which
    Tools/build/make_assets.py needs anyway; skipped without it.
    """
    try:
        from PIL import Image
    except ImportError:
        return
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if img.getpixel((w // 2, h // 2))[3] != 0:
        rep.fail("media", path, "the shadow is not clear in the middle; it will show through the panel")
    if img.getpixel((3, h // 2))[3] == 0:
        rep.fail("media", path, "the shadow has nothing outside the panel's edge")


# Every "Interface\\AddOns\\..." path Theme.lua hands the client. The client
# reports a missing texture by drawing nothing at all, so a typo or a renamed
# folder is invisible until someone notices a blank square -- which is exactly
# what a stale "AegisPathfinder\\media\\resting.tga" did here.
ADDON_TEXTURE = re.compile(r'"(Interface\\\\AddOns\\\\[^"]+)"')


def check_texture_paths(rep):
    theme = os.path.join(ROOT, "Theme.lua")
    if not os.path.exists(theme):
        return
    src = strip_lua_comments(open(theme, encoding="utf-8", errors="replace").read())

    # MEDIA .. "name" concatenations, resolved the way Lua would.
    media = re.search(r'local MEDIA = "([^"]+)"', src)
    prefix = media.group(1) if media else ""
    paths = set(ADDON_TEXTURE.findall(src))
    for suffix in re.findall(r'MEDIA \.\. "([^"]+)"', src):
        paths.add(prefix + suffix)
    # "\\\\" in the source is two backslashes in the path: the check below
    # would find the file, and the client would not.
    for path in sorted(paths):
        if "\\\\\\\\" in path:
            rep.fail("textures", "Theme.lua", "%s has a doubled separator" % path)

    checked = 0
    for path in sorted(paths):
        rel = path.replace("\\\\", "/").replace("\\", "/")
        marker = "Interface/AddOns/"
        if marker not in rel:
            continue
        tail = rel.split(marker, 1)[1]
        # Strip the addon folder; what is left is relative to the repo root.
        parts = tail.split("/", 1)
        if len(parts) != 2:
            continue
        folder, inner = parts
        expected = os.path.basename(ROOT)
        if folder != expected:
            rep.fail("textures", "Theme.lua",
                     "%s points at folder '%s', but the addon is '%s'"
                     % (path, folder, expected))
            continue
        local = os.path.join(ROOT, *inner.split("/"))
        checked += 1
        # The client appends the extension itself, so try both.
        if not any(os.path.exists(local + ext) for ext in (".tga", ".blp", "")):
            rep.fail("textures", "Theme.lua", "%s has no file on disk" % path)
    rep.ok("textures", checked)


# GameTooltip is shared with the whole UI -- restyling it restyles every other
# addon's tooltips -- so the addon's hints use Theme:ShowTip, its own card.
# Only rows that are game items -- the Active Items buttons, the Gear finder's
# list -- may reach for GameTooltip: only it can show an item.
GAMETOOLTIP = re.compile(r"\bGameTooltip\s*:\s*SetOwner\b")
# Files whose rows are game items: only GameTooltip can show one.
GAMETOOLTIP_ALLOWED = {"ActiveFrames.lua", "GearFinderTab.lua"}


def check_tooltips(rep):
    files = [p for p in sorted(walk({".lua"}))
             if is_shipped(p) and os.path.basename(p) not in GAMETOOLTIP_ALLOWED]
    for path in files:
        code = strip_lua_noise(open(path, encoding="utf-8", errors="replace").read())
        for lineno, line in enumerate(code.splitlines(), 1):
            if GAMETOOLTIP.search(line):
                rep.fail("tooltips", path,
                         "line %d opens GameTooltip -- use Theme:ShowTip" % lineno)
    rep.ok("tooltips", len(files))


# Every window is in the DIALOG strata, where the client draws frames in
# level order across all windows at once. A window that is not registered with
# Theme's stacking keeps the level it was built at, and interleaves with any
# window it overlaps -- chips and scrollbars drawn through the other's body.
# Theme:Chrome registers its window; anything else calls RegisterWindow.
DIALOG_STRATA = re.compile(r'SetFrameStrata\s*\(\s*"DIALOG"\s*\)')
STACKED = re.compile(r"(?:\bChrome|\bRegisterWindow)\s*\(")


def check_stacking(rep):
    files = [p for p in sorted(walk({".lua"}))
             if is_shipped(p) and os.path.basename(p) != "Theme.lua"]
    for path in files:
        code = strip_lua_comments(open(path, encoding="utf-8", errors="replace").read())
        windows = len(DIALOG_STRATA.findall(code))
        stacked = len(STACKED.findall(code))
        if windows > stacked:
            rep.fail("stacking", path,
                     "%d DIALOG window(s) but %d registered with Theme's stacking "
                     "-- use Theme:Chrome or Theme:RegisterWindow" % (windows, stacked))
    rep.ok("stacking", len(files))


def check_upvalues(rep):
    """No function may read more than 32 file-scope locals.

    Lua 5.0 refuses to load a file that breaks this -- "too many upvalues
    (limit=32)" -- and the whole addon dies with it. Lua 5.1, which runs the
    tests, allows 60, so nothing else here would notice. `luac -l` prints
    each function's upvalue count; any 5.x luac reports the same number.
    """
    luac = shutil.which("luac5.1") or shutil.which("luac")
    if not luac:
        rep.ok("upvalues", 0)
        return
    n = 0
    for path in sorted(walk({".lua"})):
        if not is_shipped(path):
            continue
        out = subprocess.run([luac, "-l", "-p", path], capture_output=True, text=True)
        if out.returncode != 0:
            continue    # a syntax error; check_syntax reports it
        for count in re.findall(r"(\d+) upvalues?", out.stdout):
            if int(count) > 32:
                rep.fail("upvalues", path, "a function reads %s upvalues; Lua 5.0 allows 32" % count)
        n += 1
    rep.ok("upvalues", n)


def check_version(rep):
    """The version, in every place it is written.

    As in every Aegis addon, a bump touches five places -- Core.lua's
    AegisPathfinder.version, the .toc, the README's H1 and its "Something
    broken?" line, and the newest CHANGELOG.md entry -- and a missed one makes
    the addon report a version that is not the one it is, which sends a bug
    report and its reader to different code. Whether a bump was the right
    kind, MINOR or PATCH, is a judgement CONTRIBUTING.md describes and this
    does not guess at.
    """
    def read(name):
        with open(os.path.join(ROOT, name), encoding="utf-8") as fh:
            return fh.read()

    found = {}
    m = re.search(r'^AegisPathfinder\.version = "([^"]+)"', read("Core.lua"), re.M)
    found["Core.lua (AegisPathfinder.version)"] = m and m.group(1)
    m = re.search(r"^## Version: (\S+)", read("Aegis_Pathfinder.toc"), re.M)
    found["Aegis_Pathfinder.toc (## Version)"] = m and m.group(1)
    readme = read("README.md")
    m = re.search(r"^# Aegis: Pathfinder \(v([^)]+)\)", readme, re.M)
    found["README.md (H1)"] = m and m.group(1)
    m = re.search(r"Check the \*\*version\*\*.*?\(`v([^`]+)`\)", readme)
    found["README.md (Something broken?)"] = m and m.group(1)
    changelog = read("CHANGELOG.md")
    m = re.search(r"^## \[([0-9][^\]]*)\]", changelog, re.M)
    found["CHANGELOG.md (newest entry)"] = m and m.group(1)

    for where, v in found.items():
        if not v:
            rep.fail("version", where, "no version found")
    values = set(v for v in found.values() if v)
    if len(values) > 1:
        rep.fail("version", None, "the five version sites disagree: " +
                 ", ".join("%s %s" % (w, v) for w, v in found.items()))
    for v in values:
        if not re.match(r"^\d+\.\d+\.\d+$", v):
            rep.fail("version", None, "%s is not MAJOR.MINOR.PATCH" % v)
        elif ("[%s]: " % v) not in changelog:
            rep.fail("version", "CHANGELOG.md", "no link reference for [%s]" % v)
    rep.ok("version", len(found))


# Parser.lua shows a step only if its |C| matches UnitClass and its |R|
# matches UnitRace's first return, splitting each on "/" and comparing whole
# names ("!" before a name leaves that one out). Anything else never matches:
# "NightElf" (the client says "Night Elf"), a race in |C|, "Orc, Troll". The
# RestedXP converter wrote all three, and every Undead Warrior lost the
# Barrens quests behind |C|!Shaman/!Warrior/Undead|.
CLASS_NAMES = {"Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid"}
RACE_NAMES = {"Human", "Dwarf", "Gnome", "Night Elf", "High Elf",
              "Orc", "Troll", "Tauren", "Undead", "Goblin"}


def check_filters(rep):
    steps = 0
    for path in sorted(walk({".lua"})):
        if not rel(path).startswith("Guides" + os.sep):
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            for n, line in enumerate(f, 1):
                for tag, names, what in (("C", CLASS_NAMES, "class"), ("R", RACE_NAMES, "race")):
                    for value in re.findall(r"\|%s\|([^|]*)\|" % tag, line):
                        steps += 1
                        bad = [c for c in value.split("/") if (c[1:] if c.startswith("!") else c) not in names]
                        if bad:
                            rep.fail("filters", path, "line %d: |%s|%s| -- %s is not a %s the client names"
                                     % (n, tag, value, ", ".join(repr(b) for b in bad), what))
    rep.ok("filters", steps)


# The 1.12 world map's zones, and Turtle WoW's own by the names its zone guides
# use: what GetMapZones returns, so what a waypoint can be put on.
MAP_ZONES = {
    "Ashenvale", "Azshara", "Darkshore", "Darnassus", "Desolace", "Durotar", "Dustwallow Marsh",
    "Felwood", "Feralas", "Moonglade", "Mulgore", "Orgrimmar", "Silithus", "Stonetalon Mountains",
    "Tanaris", "Teldrassil", "The Barrens", "Thousand Needles", "Thunder Bluff", "Un'Goro Crater",
    "Winterspring",
    "Alterac Mountains", "Arathi Highlands", "Badlands", "Blasted Lands", "Burning Steppes",
    "Deadwind Pass", "Dun Morogh", "Duskwood", "Eastern Plaguelands", "Elwynn Forest",
    "Hillsbrad Foothills", "Ironforge", "Loch Modan", "Redridge Mountains", "Searing Gorge",
    "Silverpine Forest", "Stormwind City", "Stranglethorn Vale", "Swamp of Sorrows",
    "The Hinterlands", "Tirisfal Glades", "Undercity", "Western Plaguelands", "Westfall", "Wetlands",
    "Alah'Thalas", "Balor", "Blackstone Island", "Gillijim's Isle", "Gilneas", "Grim Reaches",
    "Hyjal", "Icepoint Rock", "Lapidis Isle", "Moonwhisper Coast", "Northwind",
    "Scarlet Enclave", "Tel'Abim", "Thalassian Highlands",
}
CONTINENTS = {"Kalimdor", "Eastern Kingdoms"}
COORDS = re.compile(r"\(([\d.]+),\s?([\d.]+)\)")      # Locale.lua's COORD_MATCH


def check_zones(rep):
    """A step whose note has coordinates gets a waypoint on its zone's map:
    its |Z| tag's, or the guide's, from the title. That zone has to be one the
    map knows, through Parser.lua's ZONE_NAMES -- "Redridge" is not, and every
    step of Optimized/Redridge said so in chat. A continent is let through: the
    waypoint code knows to skip it. So is no zone at all -- RestedXP's first
    step, in the zone you come from, takes the zone you are in."""
    with open(os.path.join(ROOT, "Parser.lua"), encoding="utf-8") as f:
        block = re.search(r"ZONE_NAMES = \{(.*?)\n\}", f.read(), re.S).group(1)
    names = dict(re.findall(r'\["([^"]+)"\] = "([^"]+)"', block))
    for short, full in names.items():
        if full not in MAP_ZONES:
            rep.fail("zones", os.path.join(ROOT, "Parser.lua"), "ZONE_NAMES[%r] = %r, not a zone on the map" % (short, full))
    steps = 0
    for path in sorted(walk({".lua"})):
        if not rel(path).startswith("Guides" + os.sep):
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        title = re.search(r'RegisterGuide\("([^"]+)"', text)
        m = title and re.search(r"([^/]+) \(.*\)$", title.group(1))
        guide_zone = m and names.get(m.group(1), m.group(1))
        for n, line in enumerate(text.splitlines(), 1):
            note = re.match(r"^[A-Za-z] ", line) and re.search(r"\|N\|([^|]*)\|", line)
            if not note or not COORDS.search(note.group(1)):
                continue
            steps += 1
            tag = re.search(r"\|Z\|([^|]*)\|", line)
            zone = names.get(tag.group(1), tag.group(1)) if tag and tag.group(1) else guide_zone
            if zone and zone not in MAP_ZONES and zone not in CONTINENTS:
                rep.fail("zones", path, "line %d: %s -- %r is not a zone on the map; tag the step |Z|<zone>|, "
                                        "or add the name to Parser.lua's ZONE_NAMES" % (n, ("|Z|" if tag else "title"), zone))
    rep.ok("zones", steps)


BOAT = re.compile(r"\bboat\b", re.I)


def check_boats(rep):
    """Turtle WoW has no boat between Menethil Harbor and Auberdine: Auberdine's
    boats go to Stormwind Harbor, Rut'theran Village and Alah'Thalas, and
    Menethil's to Theramore. A guide step that boards one between Menethil and
    Darkshore sent players to a dock nothing sails from ("Travel to Auberdine
    by boat from Menethil Harbor"). A step may name both only on the way
    through Stormwind Harbor; waiting at Menethil for a boat to Darkshore, or at
    Auberdine for one to Menethil, is the old route."""
    steps = 0
    for path in sorted(walk({".lua"})):
        if not rel(path).startswith("Guides" + os.sep):
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            for n, line in enumerate(f, 1):
                if not (line.startswith("b ") or BOAT.search(line)):
                    continue
                steps += 1
                low = line.lower()
                zone = re.search(r"\|Z\|([^|]*)\|", line)
                zone = zone and zone.group(1)
                both = "menethil" in low and ("auberdine" in low or "darkshore" in low)
                if (both and "stormwind harbor" not in low) \
                        or (zone == "Wetlands" and re.search(r"boat to (darkshore|auberdine)|auberdine boat", low)) \
                        or (zone == "Darkshore" and re.search(r"boat to menethil|menethil harbor boat", low)):
                    rep.fail("boats", path, "line %d: a boat between Menethil Harbor and Auberdine -- there is "
                                            "none; Auberdine's boat sails to Stormwind Harbor" % n)
    rep.ok("boats", steps)


def check_methods(rep):
    """An AegisPathfinder method defined in two files: the one loaded later
    replaces the other outright. QuestTracker.lua's PLAYER_LEVEL_UP replaced
    Core.lua's, and the starting zone stopped letting go on a level up. A
    later definition is allowed only as a wrapper, keeping the earlier one to
    call (`local skip = AegisPathfinder.SkipToNextObjective`)."""
    files = []
    for entry in toc_entries(os.path.join(ROOT, "Aegis_Pathfinder.toc")):
        if entry.endswith(".lua"):
            files.append(os.path.join(ROOT, entry))
    seen, n = {}, 0
    for path in files:
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        for m in re.finditer(r"^\s*(?:function AegisPathfinder[:.](\w+)\s*\(|AegisPathfinder[.:](\w+)\s*=\s*function\b)",
                             text, re.M):
            name = m.group(1) or m.group(2)
            line = text.count("\n", 0, m.start()) + 1
            n += 1
            if name in seen:
                keeps = re.search(r"=\s*AegisPathfinder\.%s\b(?!\s*\()" % re.escape(name), text[:m.start()])
                if not keeps:
                    rep.fail("methods", path, "line %d: AegisPathfinder:%s is defined again (first at %s) -- "
                                              "the later one replaces it; merge them, or keep the first to call"
                             % (line, name, seen[name]))
            else:
                seen[name] = "%s:%d" % (rel(path), line)
    rep.ok("methods", n)


def main():
    print("Verifying %s\n" % ROOT)
    rep = Report()
    check_syntax(rep)
    check_lua50(rep)
    check_toc(rep)
    check_xml(rep)
    check_theme(rep)
    check_theme_scope(rep)
    check_stacking(rep)
    check_tooltips(rep)
    check_media(rep)
    check_texture_paths(rep)
    check_upvalues(rep)
    check_version(rep)
    check_filters(rep)
    check_zones(rep)
    check_boats(rep)
    check_methods(rep)
    return rep.summary()


if __name__ == "__main__":
    sys.exit(main())
