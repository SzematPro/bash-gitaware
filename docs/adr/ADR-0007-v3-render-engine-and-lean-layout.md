# ADR-0007: v3 render engine and Lean layout

- Status: Accepted (layout open to owner feedback before 3.0.0)
- Date: 2026-11-25

## Context

v2 builds `PS1` by string concatenation in one function (`lib/60-render.bash`).
Each value is escaped inline, and the result is a fixed stack of lines:
context, an optional commit subject, then the prompt symbol. Users find the
look "starship-like, not premium". The v3 spec (`docs/v3/SPEC.md`, R1 to R4)
asks for a Lean default style: a command ledger, a transient prompt and
context aligned to the right, with the `Aware` theme.

Right alignment needs the display width of everything on the line. v2 only
measures string length, which is wrong for CJK, emoji, combining marks and
invalid UTF-8. The lost v3 attempt showed that a width engine in bash has
traps (SPEC section 5): byte-oriented `printf '%.1s'`, `mbtowc` state
corruption, quadratic idioms, and differences between glibc and musl.

## Decision

### Layout (Lean)

```
~/src/bash-gitaware  main ●2 ↑1                     py 3.12 · 3s · ✘1
❯ _
```

- Line 1, left: path, then git (branch, state, dirty count, ahead/behind,
  stash).
- Line 1, right: context, aligned to the last column. The segments are the
  runtime/version, the last command's duration (only when it reaches the
  threshold), its exit status (only on failure), and an optional clock (off by
  default).
- Line 2: the prompt symbol, colored by the last exit status.
- The commit subject is off by default in Lean (`commit_line=1` brings it back
  as its own line).
- **Ledger.** On Enter, the two-line prompt collapses into one ledger line,
  `❯ <command>` (ADR-0004 mechanism). When the command ends and it failed or
  reached the duration threshold, the next prompt is preceded by a dim result
  line, `  ✘1 · 3s`, so the scrollback reads as command, output, result.
  Successful fast commands add nothing.

### Render engine

1. **Segments.** Each segment is a function that sets `REPLY_TEXT` (PS1-safe:
   untrusted parts already escaped by `__bga_ps1_lit`, colors from tokens) and
   `REPLY_W` (display width of the visible text, measured on the raw text
   before escaping). Escaping happens once, inside the segment, never on the
   assembled line.
2. **Width engine** (`lib/17-width.bash`). `__bga_width <text>` sets
   `REPLY` to the number of terminal cells:
   - ASCII printable runs are counted in bulk (`${s%%[!\ -~]*}`), so mostly
     ASCII text costs close to linear time;
   - each non-ASCII character is decoded from its bytes under `LC_ALL=C` (no
     `mbtowc`) and looked up in a compact table: zero width for combining
     marks, ZWJ and variation selectors; two cells for East Asian Wide/Full
     and emoji presentation; one cell otherwise;
   - invalid or overlong UTF-8, and code points above U+10FFFF, count one
     cell per byte (glibc and musl disagree on them).
3. **Right alignment without trusting the width for readline.** The right
   block goes inside `\[ ... \]` as `ESC 7` (save cursor), `ESC [ <col> G`
   (column), the text, then `ESC 8` (restore). Readline counts it as zero
   width, so a width error can misplace the right block but never breaks
   line editing or wrapping. `col = COLUMNS - right_width + 1`.
4. **Narrow terminals.** When `left + right + 1 > COLUMNS`, right segments
   are dropped in this order: clock, runtime, duration, exit status. If the
   left part alone does not fit, the path is shortened first (fewer trailing
   components, down to one), and git keeps the branch only. `COLUMNS` is read
   on every prompt (`checkwinsize`), so a resize applies on the next prompt.
5. **Colors** come only from semantic tokens (`T1.4`), never from literal
   escapes in segment code.

## Alternatives considered

- **Pad with spaces up to the right block**, so readline counts it: simple,
  but any width error breaks cursor placement and wrapping on that line.
  Rejected; the cursor-move form fails soft.
- **Ask the terminal for the cursor position** (`ESC [6n`) to measure the
  width: exact, but it is a round trip per prompt, races with typed input
  and fails over slow links. Rejected.
- **Use `printf '%d' "'c"` to get code points**: fast, but its hidden
  `mbtowc` state is corrupted by truncated sequences on glibc (SPEC section 5).
  Rejected for untrusted input.
- **Keep the v2 three-line stack as the default**: rejected by the owner's
  premium-look goal. It stays available as a preset.

## Consequences

- The right block can drift by a few cells where our width table and the
  terminal's font disagree (ambiguous-width characters, new emoji). That is
  accepted: the alignment is cosmetic, and editing is unaffected.
- Terminals that do not implement `ESC 7`/`ESC 8` and `ESC [ n G` (rare,
  mostly `TERM=dumb`) are already in plain mode, which never draws a right
  block.
- Segments cost one width computation each per prompt. The ASCII fast path
  keeps this to a few parameter expansions for typical content. It is
  measured by the render budget (`tests/budgets.sh`).
