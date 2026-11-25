#!/usr/bin/env python3
"""Check that each English user doc and its Spanish twin stay in step.

Development and CI tool. For every pair (X.md, X.es.md) it compares:
the number of headings per level, the code blocks (must be identical, since
commands are not translated), the number of table rows, and the link
targets (except the link to the other language). Exit 1 on any difference.

Usage: python3 -I bin/check-doc-parity.py [repo root]
"""
import os, re, sys

PAIRS = [('README.md', 'README.es.md')]
LANG_LINKS = {'README.md', 'README.es.md'}


def facts(text):
    heads, blocks, rows, links = {}, [], 0, []
    in_code, buf = False, []
    for line in text.splitlines():
        if line.startswith('```'):
            if in_code:
                blocks.append('\n'.join(buf)); buf = []
            in_code = not in_code
            continue
        if in_code:
            buf.append(line); continue
        m = re.match(r'^(#+) ', line)
        if m:
            heads[len(m.group(1))] = heads.get(len(m.group(1)), 0) + 1
        if line.startswith('|'):
            rows += 1
        links += [t for t in re.findall(r'\]\(([^)]+)\)', line) if t not in LANG_LINKS]
    return heads, blocks, rows, links


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    bad = 0
    for en, es in PAIRS:
        a = facts(open(os.path.join(root, en), encoding='utf-8').read())
        b = facts(open(os.path.join(root, es), encoding='utf-8').read())
        for name, x, y in zip(('headings', 'code blocks', 'table rows', 'links'), a, b):
            if x != y:
                bad += 1
                print('%s vs %s: %s differ\n  en: %r\n  es: %r' % (en, es, name, x, y))
    print('parity ok' if not bad else 'parity FAILED (%d)' % bad)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
