#!/usr/bin/env python3
import os
import re

# Match invalid escape sequences in Lua string literals
# Valid escapes in Lua 5.0/5.1: \a, \b, \f, \n, \r, \t, \v, \\, \", \', \ddd (1-3 digits), \z (5.2+)
# Invalid: \., \B, \s, etc.
INVALID_ESCAPE_PATTERNS = [
    re.compile(r'"([^"\\]*(\\.[^"\\]*)*)"'),
    re.compile(r"'([^'\\]*(\\.[^'\\]*)*)'"),
]

def check_file(path):
    issues = []
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines, 1):
        # strip comments
        non_comment = line.split('--')[0]
        # check for triple backslashes
        if '\\\\\\' in non_comment:
            issues.append((i, "Triple backslash detected", line.strip()))
        
        # In a raw Lua string, \\ represents a single backslash.
        # Any remaining single backslash followed by a character that is not
        # a, b, f, n, r, t, v, \, ", ', or digits (e.g. \123) is an invalid escape.
        # We replace '\\\\' with nothing first, then find remaining backslashes!
        cleaned = non_comment.replace('\\\\', '')
        for quote_pat in [re.compile(r'"([^"]*)"'), re.compile(r"'([^']*)'")]:
            for m in quote_pat.finditer(cleaned):
                s = m.group(1)
                bad = re.findall(r'\\([^abfnrtv"\'0-9])', s)
                if bad:
                    for b in bad:
                        issues.append((i, f"Invalid escape sequence \\{b}", line.strip()))

    # Check for duplicate keys in dictionary tables
    keys = {}
    table_depth = 0
    for i, line in enumerate(lines, 1):
        clean = line.split('--')[0].strip()
        if '{' in clean:
            table_depth += clean.count('{')
            keys[table_depth] = set()
        m = re.match(r'^([a-zA-Z0-9_]+)\s*=', clean)
        if m and table_depth > 0:
            k = m.group(1)
            if table_depth in keys and k in keys[table_depth]:
                issues.append((i, f"Duplicate table key '{k}'", clean))
            elif table_depth in keys:
                keys[table_depth].add(k)
        if '}' in clean:
            table_depth -= clean.count('}')
            if table_depth < 0:
                table_depth = 0

    return issues

def main():
    total_issues = 0
    for root, dirs, files in os.walk('.'):
        if '.git' in root or 'tools' in root:
            continue
        for f in files:
            if f.endswith('.lua'):
                p = os.path.join(root, f)
                issues = check_file(p)
                if issues:
                    print(f"File: {p}")
                    for line_no, msg, content in issues:
                        print(f"  Line {line_no}: [{msg}] -> {content}")
                        total_issues += 1
    print(f"\nTotal syntax/escape issues found: {total_issues}")

if __name__ == '__main__':
    main()
