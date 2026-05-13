# ADR-0004: Transient prompt

- Status: Accepted
- Date: 2026-05-13

## Context

A long-lived shell accumulates prompts in scrollback. After a hundred commands
the scrollback is half full of past prompts repeating context the user no
longer needs: each historical prompt shows the path, branch, status and
runtime that were true at the time but are clutter in retrospect. The
interesting content scrolls past, surrounded by stale context.

Powerlevel10k (zsh) popularized the **transient prompt** pattern: as soon as a
command is submitted, the just-displayed prompt is replaced by a minimal form
(typically `❯` plus the command). The live prompt is full and informative; the
history collapses to one symbol per command. This is consistently cited as the
single most-valued P10k feature.

Replicating it in bash is non-trivial because readline owns the cursor on the
prompt line and there is no public API to redraw the prompt mid-edit.

## Decision

Implement transient prompt in `lib/80-transient.bash`:

1. The renderer records the number of physical lines the just-printed prompt
   occupies (computed from the assembled prompt string, accounting for
   embedded newlines and the terminal width).
2. On command submit, move the cursor up to the start of that prompt, clear
   to end of screen, then reprint a minimal form: the prompt symbol followed
   by the typed command (`❯ <command>`), colored by the previous exit code.
   Including the command keeps the scrollback useful ("which command produced
   this output") and matches the Powerlevel10k convention; printing the
   symbol alone would erase the command from scrollback for no gain.
3. Then run the user's command.

Hook strategy: `bind -x` carries the collapse function on an auxiliary chord
(`\C-x\C-t`); the Enter key (`\C-m`) is remapped to a readline macro
`"\C-x\C-t\C-j"`. The macro runs the collapse and then triggers `accept-line`
via `\C-j`, which is a separate default-bound key for accept-line — so we do
not recurse into our own `\C-m` remap. This works on any bash 4.4+ shell
with a standard readline; the macro is intercepted before readline's own
post-`bind -x` redraw, so the redraw is harmless. `BASHGITAWARE_TRANSIENT=0`
skips installation entirely; toggling it after sourcing also short-circuits
the function at call time.

Disable with `BASHGITAWARE_TRANSIENT=0`.

Edge cases the implementation must handle:

- **Multi-line prompt**: the recorded line count is the truth; move up that
  many rows.
- **First prompt** (no prior command): nothing to collapse, no-op.
- **Empty submit** (just Enter): collapse anyway, then print the next full
  prompt.
- **`Ctrl-C` at the prompt** (line discarded by readline): collapse the
  prompt; readline prints a new one on the same row.
- **`clear` command**: the screen clear runs after the collapse; final state
  is a clean screen either way.
- **Terminal resize between rendering and submit**: the recorded line count
  can be stale and the cursor may move to the wrong row. Acceptable; the
  next prompt cycle re-syncs.

## Alternatives considered

- **Pure-bash without `bind -x`, collapse only on the next prompt cycle.**
  Works, but a flash of "full prompt + typed command" appears for an instant
  before the collapse. Acceptable as a fallback; not ideal as the only
  strategy. We use both: `bind -x` where available, next-cycle elsewhere.
- **Do not implement transient.** Loses the most-requested feature; the
  implementation cost is moderate and the off switch is one env var. Ship it.
- **Custom readline binding for every key that submits** (Enter, `Ctrl-D` on
  an empty line, `Ctrl-J`, etc.). Bigger surface for the same payoff;
  `accept-line` is the canonical hook. Stick to `accept-line`.

## Consequences

- Scrollback stays compact: command history is one minimal prompt per line.
- The live prompt is full and useful; the user loses no context while they
  are at it.
- The collapse machinery is the most fragile module in normal use; exotic
  edge cases (a resize in the millisecond between render and submit, unusual
  readline keymaps overriding `accept-line`) can produce a single misaligned
  row. The off switch (`BASHGITAWARE_TRANSIENT=0`) is the escape hatch.
- An interactive manual test checklist (`tests/MANUAL.md`) covers the cases
  that are awkward to automate; a stretch goal is a `pty`-driven scenario
  test in CI.
