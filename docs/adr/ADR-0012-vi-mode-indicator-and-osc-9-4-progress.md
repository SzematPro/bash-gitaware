# ADR-0012: vi-mode indicator and OSC 9;4 progress

- Status: Accepted
- Date: 2026-11-25

## Context

3.1 adds two small terminal features (SPEC S5 and S7):

- **vi mode.** With `set -o vi`, the prompt gave no sign of whether the line
  was in insert or command mode.
- **Long commands.** Several terminals can show a progress state in the
  taskbar or tab: Windows Terminal, ConEmu, and more recent ones such as
  Ghostty. Nothing showed there while a long command ran.

Both run against the same constraint as the rest of the prompt: bash
cannot redraw the prompt while readline owns the line (ADR-0005, ruling
R-5). Anything printed from the side corrupts the input.

## Decision

**vi-mode indicator.**

- readline draws the indicator itself. With `show-mode-in-prompt on` it
  prints `vi-ins-mode-string` or `vi-cmd-mode-string` at the start of the
  last prompt line, and redraws it on every mode switch. bash-gitaware only
  sets those variables once, at load time (`lib/82-vimode.bash`).
- Command mode shows a marker (`N`; a vim glyph with Nerd Font glyphs) in
  the theme's `state` color. Insert mode shows nothing. `emacs-mode-string`
  is emptied, because `show-mode-in-prompt` also applies to emacs mode,
  which must look as it did before.
- The color escapes are wrapped in `\1 \2`, so readline does not count them
  in the prompt width. The escapes come only from the theme tables.
- A user who configured any of this is left alone: `show-mode-in-prompt
  on`, or any mode string changed from readline's default. `vi_mode = 0`
  and plain mode set nothing. Turning it off and reloading puts readline's
  defaults back.

**OSC 9;4 progress.**

- Off by default (`progress = 1` turns it on).
- `PS0` writes `OSC 9;4;3;0` (indeterminate) when a command starts.
- The next prompt writes `OSC 9;4;0;0` (clear). If a command ran and
  failed, it writes `OSC 9;4;2;100` (error) instead, which lasts until the
  next prompt.
- Off with `osc = 0`, in plain mode, and when `TMUX` or `STY` is set: tmux
  and screen do not pass the sequence to the outer terminal without
  passthrough settings.

## Alternatives considered

- **A mode segment in `PS1`.** bash does not re-render `PS1` when the mode
  changes, so the segment would show the mode of the previous line.
  readline's mode strings are the only redraw that bash offers.
- **Redrawing from a `bind -x` hook on ESC.** This writes to the terminal
  while readline owns the line, the failure that ruled out the animated
  indicator (R-5).
- **Progress on by default.** Most terminals without OSC 9;4 ignore it,
  but some treat OSC 9 as a desktop notification (below), and in any case
  this is a terminal-wide side effect that users did not ask for. It is
  also unverified on several terminals (below).
- **Reporting a percentage.** The shell cannot know how far a command has
  got. Only the indeterminate and error states are honest.

## Consequences

- The indicator has no per-prompt cost: one `bind -v` at load.
- When the user switches the editing mode with `set -o vi` after loading,
  the indicator still works, because the variables are already set.
- Pressing Enter in vi command mode does not collapse the transient prompt.
  The Enter remap lives in the keymap that was active at load. This
  predates 3.1.
- The vi-mode tests do not run `set -o vi` in `bash -i -c` without a tty.
  bash 4.4 to 5.2 crash there, with or without bash-gitaware, and 5.3
  fixes it. The real vi mode is tested in a pty.
- Some terminals use OSC 9 for desktop notifications (older iTerm2), so
  `progress = 1` may show pop-ups there. This is another reason it is
  opt-in.
- OSC 9;4 was checked as bytes in the test suite. How it looks on Windows
  Terminal, ConEmu and Ghostty has not been checked on a real terminal.
