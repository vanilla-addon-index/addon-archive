#!/usr/bin/env python3
"""OctoPad build: optional icon regeneration, version bump, structural checks, zip.

  python3 tools/build.py                 # checks + zip
  python3 tools/build.py --icons         # regenerate Glyphs/ and Icons/ first
  python3 tools/build.py --bump minor    # bump the version (major | minor | patch) in OctoPad.lua and the .toc
  python3 tools/build.py --out DIR       # where OctoPad.zip goes (default: repo root)
"""
import argparse, os, re, subprocess, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, 'OctoPad')
TOOLS = os.path.join(ROOT, 'tools')

def read(p): return open(p, encoding='utf-8').read()
def write(p, s): open(p, 'w', encoding='utf-8').write(s)

def bump(kind):
    lua = os.path.join(ADDON, 'OctoPad.lua'); toc = os.path.join(ADDON, 'OctoPad.toc')
    s = read(lua)
    m = re.search(r'OP\.VERSION = "(\d+)\.(\d+)\.(\d+)"', s)
    a, b, c = map(int, m.groups())
    if kind == 'major': a, b, c = a + 1, 0, 0
    elif kind == 'minor': b, c = b + 1, 0
    else: c += 1
    v = '%d.%d.%d' % (a, b, c)
    write(lua, s[:m.start()] + 'OP.VERSION = "%s"' % v + s[m.end():])
    write(toc, re.sub(r'## Version: [\d.]+', '## Version: ' + v, read(toc)))
    print('version', v)

def strip_lua(s):
    s = re.sub(r'--\[(=*)\[.*?\]\1\]', '', s, flags=re.S)       # long comments
    s = re.sub(r'\[(=*)\[.*?\]\1\]', '""', s, flags=re.S)        # long strings
    s = re.sub(r'--[^\n]*', '', s)
    s = re.sub(r'"(\\.|[^"\\\n])*"', '""', s)
    s = re.sub(r"'(\\.|[^'\\\n])*'", "''", s)
    return s

def check():
    ok = True
    toc = read(os.path.join(ADDON, 'OctoPad.toc'))
    files = [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith('#')]
    for f in files:
        p = os.path.join(ADDON, f)
        if not os.path.exists(p):
            print('MISSING', f); ok = False; continue
        if f.endswith('.lua'):
            s = strip_lua(read(p))
            opens = len(re.findall(r'\b(function|if|do|repeat)\b', s)) - len(re.findall(r'\bwhile\b[^\n]*\bdo\b|\bfor\b[^\n]*\bdo\b', s)) * 0
            ends = len(re.findall(r'\b(end|until)\b', s))
            # Lua 5.0 traps
            if re.search(r'#\w', s): print('WARN', f, '"#" length operator is Lua 5.1+'); ok = False
            if 'string.match' in s or 'string.gmatch' in s: print('WARN', f, 'string.match / gmatch are Lua 5.1+'); ok = False
            print('%-22s blocks %d / ends %d' % (f, opens, ends))
    try:
        subprocess.run(['xmllint', '--noout', os.path.join(ADDON, 'Bindings.xml')], check=True)
    except FileNotFoundError:
        pass
    except subprocess.CalledProcessError:
        ok = False
    return ok

def icons():
    for g in ('glyphs.py', 'keys.py', 'pfkeys.py', 'sysicons.py'):
        subprocess.run([sys.executable, os.path.join(TOOLS, g)], check=True)

def zipit(out):
    z = os.path.join(out, 'OctoPad.zip')
    with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
        for d, _, fs in os.walk(ADDON):
            for f in sorted(fs):
                p = os.path.join(d, f)
                zf.write(p, os.path.relpath(p, ROOT))
    print('wrote', z)

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--icons', action='store_true')
    ap.add_argument('--bump', choices=['major', 'minor', 'patch'])
    ap.add_argument('--out', default=ROOT)
    a = ap.parse_args()
    if a.icons: icons()
    if a.bump: bump(a.bump)
    if not check():
        print('checks failed'); sys.exit(1)
    zipit(a.out)
