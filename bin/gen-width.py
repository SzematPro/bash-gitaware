#!/usr/bin/env python3
"""Generate the display-width table embedded in lib/17-width.bash.

Development tool only (bash-gitaware has no runtime Python dependency).
Prints the three table lines between the markers in lib/17-width.bash:
range starts, range ends (code points, decimal) and one width digit per range.
Only ranges whose width is not 1 are listed, from U+0300 up:

  0  combining marks (Mn, Me), ZWJ/ZWNJ and other zero-width format
     characters, Hangul medial/final jamo, variation selectors;
  2  East Asian Wide and Fullwidth (this includes emoji presentation).

Usage: python3 -I bin/gen-width.py   (then paste over the table in the module)
"""
import unicodedata as u

ZERO_FORMAT = {0x200B, 0x200C, 0x200D, 0x200E, 0x200F,
               0x2060, 0x2061, 0x2062, 0x2063, 0x2064, 0xFEFF}


def width(cp):
    if cp in ZERO_FORMAT or 0x1160 <= cp <= 0x11FF \
            or 0xFE00 <= cp <= 0xFE0F or 0xE0100 <= cp <= 0xE01EF:
        return 0
    ch = chr(cp)
    if u.category(ch) in ('Mn', 'Me'):
        return 0
    if u.east_asian_width(ch) in ('W', 'F'):
        return 2
    return 1


def main():
    ranges, cur = [], None
    for cp in range(0x300, 0x110000):
        if 0xD800 <= cp <= 0xDFFF:
            continue
        w = width(cp)
        if w == 1:
            if cur:
                ranges.append(cur)
                cur = None
            continue
        if cur and cur[2] == w and cur[1] == cp - 1:
            cur[1] = cp
        else:
            if cur:
                ranges.append(cur)
            cur = [cp, cp, w]
    if cur:
        ranges.append(cur)
    print('# Unicode %s, %d ranges' % (u.unidata_version, len(ranges)))
    print('_bga_wlo=(%s)' % ' '.join(str(r[0]) for r in ranges))
    print('_bga_whi=(%s)' % ' '.join(str(r[1]) for r in ranges))
    print("_bga_ww='%s'" % ''.join(str(r[2]) for r in ranges))


if __name__ == '__main__':
    main()
