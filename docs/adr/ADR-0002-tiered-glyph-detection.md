# ADR-0002: Tiered glyph detection (locale is not font)

- Status: Accepted
- Date: 2026-05-13

## Context

v1 gates Unicode glyphs on the *locale*: if `$LANG`, `$LC_ALL` or `$LC_CTYPE`
contains `UTF-8`, the prompt uses the fancy set (`╭╮╰╯`, `⚑`, `✓`, `✗`, `↑`,
`↓`); otherwise it falls back to ASCII (`+`, `S`, `OK`, `*`, `^`, `v`). That
heuristic is wrong: the locale tells you the *encoding* the terminal will pass
through (UTF-8 byte sequences won't be mangled into question marks), not
whether the *font* in use has the glyph at the codepoint we asked for. The
glyph either renders or it shows as tofu (the empty-square missing-glyph
indicator); the locale cannot tell the difference.

Concrete v1 failures that motivated this ADR:

- `╭╮╰╯` (box drawing corners) render as tofu on monospace fonts without those
  box-drawing variants. Common case: default Menlo on macOS, default
  DejaVu Sans Mono on some Linux distros with a stripped font config.
- `⚑` (stash flag, U+2691) renders as tofu on many monospace fonts; it lives
  outside the common monospace coverage.
- Powerline / Nerd Font glyphs (the branch icon, the wider arrows) render as
  tofu on any terminal whose font is not Nerd-patched, regardless of locale.

The user-facing symptom is "the symbols are broken" and the fix in v1 is to
manually set a non-UTF-8 locale, which also breaks unrelated things.

## Decision

Three explicit tiers, named and selectable:

- **`nerd`**: the Powerline branch glyph (``) plus the `unicode` set
  below. Requires a Nerd Font.
- **`unicode`**: arrows, a dot, simple glyphs present in virtually every
  monospace font: `↑ ↓ ● ≡ ↳ ❯ …`. No box-drawing characters here either; the
  v1 box was the v1 failure mode.
- **`ascii`**: word fallbacks: `^ v * s commit: exit N`.

Auto-detection picks **`unicode` if the locale is UTF-8, else `ascii`**.
**`nerd` is never auto-selected.** It is opt-in via
`BASHGITAWARE_NERD_FONT=1` (preferred, reads naturally) or
`BASHGITAWARE_GLYPHS=nerd` (explicit). Force any tier with
`BASHGITAWARE_GLYPHS`.

## Alternatives considered

- **Probe for Nerd Font** (emit a glyph, read back the cursor column, compare
  to a known plain character). Unreliable: the terminal reports the *font's*
  cell width, not whether the cell rendered a glyph or tofu. The probe also
  pollutes scrollback during shell startup and is racy with prompt rendering.
  Rejected.
- **Always assume Nerd Font.** Was the v1 implicit position whenever the
  locale was UTF-8 and the glyph happened to be box-drawing or `⚑`. Produced
  the tofu reports. Rejected.
- **Ship a font with the project.** Out of scope for a shell config and not
  how shell tools distribute. Rejected.

## Consequences

- The default render (auto-selected `unicode`) works on every reasonable
  terminal without configuration. The dropped box-drawing characters are
  intentional: those were the v1 failure surface.
- Users with a Nerd Font opt in with one env var and keep all advanced
  glyphs.
- Users on a strict ASCII terminal (an old SSH client, a serial console) get
  a useful prompt with no tofu.
- The README troubleshooting section names the tiers and the single env var
  to switch; "the symbols look broken" has a one-line fix.
- The implementation maintains three glyph maps; the cost of carrying two
  extra is trivial.
