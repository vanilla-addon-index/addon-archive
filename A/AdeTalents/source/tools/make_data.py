#!/usr/bin/env python3
"""Build AdeTalents Data/<CLASS>.lua from the saved-variables files written by `/adet dump`.

Usage: python3 make_data.py <out_dir> <AdeTalents.lua> [<AdeTalents.lua> ...]

Each dump file may hold one or more classes. A talent's numbers are turned into {1}, {2} ...
placeholders. For every number we record whether it grows linearly with the rank ("r"),
stays the same ("c"), has a different value at every rank ("v") or is unknown ("?"),
and how sure we are:
  exact   - max rank 1, proven by the 'Next rank:' text of a learned talent,
            or confirmed from a talent tooltip (tools/verified.json)
  assumed - scaling guessed from the wording (percent "by N%" etc.)
  partial - at least one number could not be classified

tools/verified.json (next to this script) holds what was read from talent tooltips that show
every rank at once, like "[50/100]%". Format:
  { "DRUID": { "Owlkin Frenzy": [10, 30, 1, 10, [30, 25, 20]] } }
One entry per number of the description, in the order of {1}, {2} ...:
  a plain number   - the same at every rank
  a list [a, b, c] - the value at rank 1, 2, 3 (one value per rank, max rank long)
  {"fixed": 90}    - a fixed value (or a list, one per rank), not checked against the dump (stays "assumed")
A verified talent is checked against the dump (the number the dump shows must match).
"""
import re, json, sys, os

# ---------------------------------------------------------------- Lua table reader
def parse_lua_table(text):
    pos = [text.index('{')]
    n = len(text)
    num_re = re.compile(r'-?\d+(?:\.\d+)?')
    kw_re = re.compile(r'true|false|nil')
    id_re = re.compile(r'[A-Za-z_]\w*')
    eq_re = re.compile(r'\s*=')

    def ws():
        while pos[0] < n and text[pos[0]] in ' \t\r\n':
            pos[0] += 1

    def string():
        pos[0] += 1
        out = []
        while text[pos[0]] != '"':
            c = text[pos[0]]
            if c == '\\':
                pos[0] += 1
                e = text[pos[0]]
                out.append({'n': '\n', 't': '\t', 'r': '\r'}.get(e, e))
            else:
                out.append(c)
            pos[0] += 1
        pos[0] += 1
        return ''.join(out)

    def value():
        ws()
        c = text[pos[0]]
        if c == '{':
            return table()
        if c == '"':
            return string()
        m = num_re.match(text, pos[0])
        if m:
            pos[0] = m.end()
            s = m.group(0)
            return float(s) if '.' in s else int(s)
        m = kw_re.match(text, pos[0])
        if m:
            pos[0] = m.end()
            return {'true': True, 'false': False, 'nil': None}[m.group(0)]
        raise ValueError('bad value at %d: %r' % (pos[0], text[pos[0]:pos[0] + 30]))

    def table():
        pos[0] += 1
        d, idx = {}, 1
        while True:
            ws()
            if text[pos[0]] == '}':
                pos[0] += 1
                break
            if text[pos[0]] == '[':
                pos[0] += 1
                k = value()
                ws()
                pos[0] += 1          # ]
                ws()
                pos[0] += 1          # =
                d[k] = value()
            else:
                m = id_re.match(text, pos[0])
                e = eq_re.match(text, m.end()) if m else None
                if m and e:
                    pos[0] = e.end()
                    d[m.group(0)] = value()
                else:
                    d[idx] = value()
                    idx += 1
            ws()
            if text[pos[0]] == ',':
                pos[0] += 1
        if d and all(isinstance(k, int) for k in d) and sorted(d) == list(range(1, len(d) + 1)):
            return [d[k] for k in sorted(d)]
        return d

    return table()

# ---------------------------------------------------------------- tooltip cleaning
COST_L = re.compile(r'^(\d+(\.\d+)?\s+(Energy|Mana|Rage|Focus)|\d+% of base mana)$')
CAST_L = re.compile(r'^(Instant|Passive|\d+(\.\d+)? sec cast|Channeled)$')
# lines that are costs/cast times/requirements are kept as they are, numbers are not templated
RAW_LINE = re.compile(r'^(Requires\b|Next rank:|\d+(\.\d+)?\s+(Energy|Mana|Rage|Focus)\b|\d+% of base mana|Instant\b|Passive\b|\d+(\.\d+)? sec cast|Channeled\b)')

def clean_tip(lines):
    """Drop right-hand text that is left over from another tooltip (dumps made by v0.1.0)."""
    out = []
    for ln in lines:
        left, right = (ln.split(' | ', 1) + [None])[:2] if ' | ' in ln else (ln, None)
        keep = False
        if right is not None:
            if COST_L.match(left.strip()) and 'range' in right:
                keep = True
            elif CAST_L.match(left.strip()) and 'cooldown' in right:
                keep = True
        if not left.strip() or left.strip().startswith('Click to'):
            continue
        out.append(left + (' | ' + right if keep else ''))
    return out

# ---------------------------------------------------------------- number scaling
NUM = re.compile(r'(?<![\w.])(\d+(?:\.\d+)?)(%?)')
UNITS_CONST = ('sec', 'secs', 'seconds', 'second', 'min', 'minutes', 'yards', 'yd', 'yds', 'yard')

def classify(text, m):
    """Guess from the wording whether a number grows with the rank (r), is fixed (c) or unknown (?)."""
    bw = [w.lower() for w in re.findall(r"[A-Za-z']+", text[:m.start()])[-4:]]
    aw = [w.lower() for w in re.findall(r"[A-Za-z%']+", text[m.end():])[:2]]
    pct = m.group(2) == '%'
    unit = aw[0] if aw else ''
    if 'by' in bw[-2:]:
        return 'r'
    if bw and bw[-1] in ('for', 'lasts', 'over', 'within', 'every', 'after', 'than', 'below', 'above', 'under', 'at'):
        return 'c'
    if unit in ('times', 'stacks', 'stack', 'charges', 'charge') and bw and bw[-1] in ('to', 'than'):
        return 'c'
    if pct:
        return 'r'
    if unit in UNITS_CONST:
        return 'c'
    return '?'

def numbers_of(lines):
    """[(line_index, match)] for every number in the lines that may be templated."""
    res = []
    for i, ln in enumerate(lines):
        if RAW_LINE.match(ln.strip()):
            continue
        for m in NUM.finditer(ln):
            res.append((i, m))
    return res

def num(m):
    s = m.group(1)
    return float(s) if '.' in s else int(s)

def fmt(x):
    if abs(x - round(x)) < 1e-9:
        return str(int(round(x)))
    return ('%.4f' % x).rstrip('0').rstrip('.')

# Lines like "Chance: 40%" or "ICD: 3s" are not part of a talent's description: they are spell data
# added to the tooltip by other mods (nampower). AdeTalents only stores what the talent itself says.
SPELL_INFO = re.compile(r'\s*\b(?:Chance|ICD):\s*\d+(?:\.\d+)?\s*(?:%|s\b|sec\b)')

PROC_REMARK = re.compile(r'\s*Higher chance to trigger than [^(]*\(Rank \d+\)\.?')

def strip_spell_info(tip):
    out = list(tip[:2])                      # name and "Rank x/y"
    for line in tip[2:]:
        line = PROC_REMARK.sub('', SPELL_INFO.sub('', line))
        if line.strip():
            out.append(line)
    return out

def build_talent(t, tab_index, tab_name):
    tip = strip_spell_info(clean_tip(t['tip']))
    req = [l for l in tip[2:] if l.startswith('Requires') and 'point' in l]
    body = [l for l in tip[2:] if l not in req]
    nxt_lines = None
    if 'Next rank:' in body:
        k = body.index('Next rank:')
        body, nxt_lines = body[:k], body[k + 1:]
    r = t['rank'] or 0
    mx = t['max']
    cur = numbers_of(body)
    nxt = numbers_of(nxt_lines) if nxt_lines is not None else None
    kinds, n1, how = [], [], []
    for idx, (li, m) in enumerate(cur):
        a = num(m)
        if mx == 1:
            kinds.append('c'); n1.append(a); how.append('exact')
        elif nxt is not None and len(nxt) == len(cur):
            b = num(nxt[idx][1])
            if abs(a - b) < 1e-9:
                kinds.append('c'); n1.append(a); how.append('exact')
            else:
                d = b - a
                if r > 0 and abs(a - r * d) < 1e-6:
                    kinds.append('r'); n1.append(d); how.append('exact')
                else:
                    kinds.append('?'); n1.append(a); how.append('none')
        else:
            k = classify(body[li], m)
            if k == 'r':
                n1.append(a / r if r > 0 else a)
            else:
                n1.append(a)
            kinds.append(k)
            how.append('none' if k == '?' else 'guess')
    # template text
    tmpl = []
    counter = 0
    by_line = {}
    for (li, m), _ in zip(cur, range(len(cur))):
        by_line.setdefault(li, []).append(m)
    for li, ln in enumerate(body):
        if li in by_line:
            out, last = [], 0
            for m in by_line[li]:
                counter += 1
                out.append(ln[last:m.start(1)])
                out.append('{%d}' % counter)
                last = m.end(1)
            out.append(ln[last:])
            tmpl.append(''.join(out))
        else:
            tmpl.append(ln)
    if '?' in kinds:
        conf = 'partial'
    elif 'guess' in how:
        conf = 'assumed'
    else:
        conf = 'exact'
    return {
        'name': t['name'], 'tab': tab_index, 'tier': t['tier'], 'col': t['column'], 'max': mx,
        'req': req, 'text': '\n'.join(tmpl), 'n': [round(x, 4) for x in n1], 'k': ''.join(kinds), 'conf': conf,
        'dumpedRank': r, 'dumped': [num(m) for li, m in cur],
    }

def apply_verified(t, cls, spec, level):
    """Replace the guessed scaling of a talent by what was read from its tooltip."""
    where = '%s / %s' % (cls, t['name'])
    if len(spec) != len(t['n']):
        raise SystemExit('verified.json: %s has %d numbers in the description but %d entries' % (where, len(t['n']), len(spec)))
    rank_seen = max(t['dumpedRank'], 1)
    kinds, n, v = [], [], {}
    fixed = False
    for i, s in enumerate(spec):
        if isinstance(s, dict):
            # a fixed value that the dump may show differently (it depends on the player level);
            # stored as the same value at every rank, and the talent stays "assumed"
            f = s['fixed']
            fixed = True
            if isinstance(f, list):
                if len(f) != t['max']:
                    raise SystemExit('verified.json: %s number %d needs %d values (max rank), got %d' % (where, i + 1, t['max'], len(f)))
                kinds.append('v'); n.append(f[0]); v[i + 1] = f
            else:
                kinds.append('c'); n.append(f)
            continue
        if isinstance(s, list):
            if len(s) != t['max']:
                raise SystemExit('verified.json: %s number %d needs %d values (max rank), got %d' % (where, i + 1, t['max'], len(s)))
            seen = s[rank_seen - 1]
            kinds.append('v'); n.append(s[0]); v[i + 1] = s
        else:
            seen = s
            kinds.append('c'); n.append(s)
        if abs(seen - t['dumped'][i]) > 1e-6:
            raise SystemExit('verified.json: %s number %d: the dump shows %s at rank %d but verified.json says %s'
                             % (where, i + 1, t['dumped'][i], rank_seen, seen))
    t['k'], t['n'] = ''.join(kinds), n
    # a fixed value is a decision, not something the tooltip shows, so it stays "assumed"
    t['conf'] = 'assumed' if fixed else 'exact'
    if v:
        t['v'] = v

# ---------------------------------------------------------------- Lua writer
def lstr(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\r', '').replace('\n', '\\n') + '"'

def write_class(path, cls, tabs, talents, level):
    lines = []
    w = lines.append
    w('-- AdeTalents data: %s' % cls)
    w('-- Generated by tools/make_data.py from in-game talent dumps (/adet dump). Do not edit by hand.')
    w('-- text: description with the numbers replaced by {1}, {2} ... (values of rank 1, see n)')
    w('-- k: one letter per number: r = grows with the rank (value = n * rank), c = same at every rank,')
    w('--    v = different value at every rank (list in v[number][rank]),')
    w('--    ? = unknown')
    w('-- conf: exact = proven, max rank 1 or read from the tooltip, assumed = scaling guessed from the wording,')
    w('--       partial = has unknown numbers')
    w('AdeTalents = AdeTalents or {}')
    w('AdeTalents.Data = AdeTalents.Data or {}')
    w('AdeTalents.Data[%s] = {' % lstr(cls))
    w('  tabs = { %s },' % ', '.join(lstr(t) for t in tabs))
    w('  talents = {')
    for t in talents:
        req = '{ %s }' % ', '.join(lstr(x) for x in t['req']) if t['req'] else '{}'
        vtxt = ''
        if t.get('v'):
            vtxt = ', v = { %s }' % ', '.join(
                '[%d] = { %s }' % (i, ', '.join(fmt(x) for x in lst)) for i, lst in sorted(t['v'].items()))
        w('    [%s] = { tab = %d, tier = %d, col = %d, max = %d, req = %s, text = %s, n = { %s }, k = %s%s, conf = %s },' % (
            lstr(t['name']), t['tab'], t['tier'], t['col'], t['max'], req, lstr(t['text']),
            ', '.join(fmt(x) for x in t['n']), lstr(t['k']), vtxt, lstr(t['conf'])))
    w('  },')
    w('}')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')

# ---------------------------------------------------------------- main
def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    summary = {}
    review = []
    vpath = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'verified.json')
    verified = json.load(open(vpath, encoding='utf-8')) if os.path.exists(vpath) else {}
    used = set()
    for src in sys.argv[2:]:
        data = parse_lua_table(open(src, encoding='utf-8').read())
        for cls, d in data['dumps'].items():
            tabs = [t['name'] for t in d['tabs']]
            talents = []
            for ti, tab in enumerate(d['tabs'], 1):
                for t in tab['talents']:
                    built = build_talent(t, ti, tab['name'])
                    spec = verified.get(cls, {}).get(t['name'])
                    if spec is not None:
                        apply_verified(built, cls, spec, d.get('level') or 60)
                        used.add((cls, t['name']))
                    talents.append(built)
            talents.sort(key=lambda x: (x['tab'], x['tier'], x['col']))
            write_class(os.path.join(out_dir, cls + '.lua'), cls, tabs, talents, d.get('level'))
            c = {'exact': 0, 'assumed': 0, 'partial': 0}
            for t in talents:
                c[t['conf']] += 1
                if t['conf'] == 'partial' or (t['conf'] == 'assumed' and 'c' in t['k'] and 'r' in t['k']):
                    review.append('%s | %s | max %d | k=%s | %s' % (cls, t['name'], t['max'], t['k'], t['text'].replace('\n', ' / ')[:160]))
            summary[cls] = (len(talents), c)
    for cls, (n, c) in sorted(summary.items()):
        print('%-8s talents=%-3d exact=%-3d assumed=%-3d partial=%-3d' % (cls, n, c['exact'], c['assumed'], c['partial']))
    tot = {k: sum(v[1][k] for v in summary.values()) for k in ('exact', 'assumed', 'partial')}
    print('TOTAL    talents=%d exact=%d assumed=%d partial=%d' % (sum(v[0] for v in summary.values()), tot['exact'], tot['assumed'], tot['partial']))
    with open(os.path.join(out_dir, '_review.txt'), 'w', encoding='utf-8') as f:
        f.write('Talents whose scaling needs a human check (partial, or a mix of rising and fixed numbers):\n\n')
        f.write('\n'.join(review) + '\n')
    print('review list: %d talents' % len(review))
    unused = [(c, n) for c, d in verified.items() for n in d if (c, n) not in used]
    print('verified from tooltips: %d talents%s' % (len(used), ('; NOT FOUND in the dumps: %s' % unused) if unused else ''))

if __name__ == '__main__':
    main()
