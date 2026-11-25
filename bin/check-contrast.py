#!/usr/bin/env python3
"""Check WCAG contrast of every theme token against the theme's background.

Development tool (no runtime dependency). Reads the theme tables from
lib/19-theme.bash. Background and minimum ratios per theme are below: muted
tokens (dim, hash, commit) may be lower than the rest, because they are
meant to recede.

Usage: python3 -I bin/check-contrast.py [lib/19-theme.bash]   (exit 1 on failure)
"""
import re, sys

RULES = {  # theme: (background, min ratio for normal tokens, min for muted)
    'aware':    ('1e2030', 4.5, 3.0),
    'light':    ('ffffff', 4.5, 3.0),
    'contrast': ('000000', 7.0, 7.0),
}
MUTED = {'dim', 'hash', 'commit'}


def lum(h):
    def ch(c):
        c = c / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else 'lib/19-theme.bash'
    src = open(path, encoding='utf-8').read()
    bad = 0
    for name, (bg, need, need_muted) in RULES.items():
        m = re.search(r"^_bga_theme_%s='\n(.*?)\n'" % name, src, re.S | re.M)
        if not m:
            print('MISSING theme %s' % name); bad += 1; continue
        for row in m.group(1).splitlines():
            tok, hexv = row.split()[:2]
            r = ratio(hexv, bg)
            lim = need_muted if tok in MUTED else need
            flag = 'ok' if r >= lim else 'LOW'
            if flag != 'ok':
                bad += 1
            print('%-8s %-9s %s %5.2f (min %.1f) %s' % (name, tok, hexv, r, lim, flag))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
