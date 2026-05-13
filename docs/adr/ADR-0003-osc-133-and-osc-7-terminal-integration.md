# ADR-0003: Modern terminal integration (OSC 133 + OSC 7)

- Status: Accepted
- Date: 2026-05-13

## Context

Modern terminals expose features that depend on the shell emitting Operating
System Command (OSC) escape sequences. The two that matter for a prompt:

- **OSC 133** ("Final Term" protocol; the de facto semantic-prompt standard,
  implemented by WezTerm, Kitty, VS Code's integrated terminal, iTerm2,
  Ghostty, Konsole, Windows Terminal, Warp and others). The shell tells the
  terminal where a prompt begins and ends, where a command begins, and the
  exit code of the command that just ended. With those marks the terminal
  can implement "jump to previous prompt", "select last command output",
  "decorate failed commands in the gutter", and similar features.
- **OSC 7**. The shell tells the terminal the current working directory as a
  `file://` URL. The terminal can then open a new tab or split that inherits
  the cwd of the original.

v1 emits **OSC 0/2** (window title) and nothing else. None of the
semantic-prompt or cwd-inheritance features work in any terminal.

The cost of emitting these is two short escape sequences per prompt; modern
terminals consume them, older terminals ignore them as well-formed OSC.

## Decision

Emit, every prompt cycle:

- `OSC 133;A` at the start of the prompt (prompt-begin).
- `OSC 133;B` at the end of the prompt (prompt-end / command-begin marker for
  the terminal).
- `OSC 133;C` at the start of command execution. We piggyback on the existing
  preexec hook (a DEBUG trap, guarded so it fires once per command, already
  in use for the command timer).
- `OSC 133;D;$?` at the start of the next prompt cycle (command-end + exit
  code).
- `OSC 7;file://$HOSTNAME$PWD` (cwd as a `file://` URL).

Keep `OSC 0/2` (window/icon title) for terminals that show it.

Every sequence is wrapped in `\[ \]` so readline's prompt-width arithmetic
stays correct.

Disable with `BASHGITAWARE_OSC=0` for users on legacy terminals or
multiplexers where the chatter is unwelcome.

## Alternatives considered

- **Implement only OSC 133, skip OSC 7.** OSC 7 is one short sequence with
  immediate payoff (new tab inherits cwd). Cheap; ship both.
- **Probe terminal capability before emitting.** Most terminals that don't
  grok OSC 133/7 simply ignore the sequence; a probe adds shell-startup cost
  for negligible benefit. Don't probe; provide `BASHGITAWARE_OSC=0` for the
  rare case where emission causes a problem.
- **Emit OSC 633 (VS Code's superset of OSC 133).** Strictly more
  expressive but VS Code understands plain OSC 133 too. Sticking to the de
  facto standard covers more terminals without losing VS Code support.
  Rejected for v2.
- **Emit only on terminals known to support these sequences (allowlist).** A
  maintenance burden for no benefit — the failure mode of emission on an
  unknown terminal is "nothing visible", which is correct. Rejected.

## Consequences

- "Jump to previous prompt", "select last command output" and similar
  features work in every supported terminal.
- New tab or split in a supported terminal inherits the original cwd.
- Per-prompt overhead: ~50 bytes emitted, no extra subprocess. Negligible.
- One extra knob to document (`BASHGITAWARE_OSC=0`).
- One extra module (`lib/70-osc.bash`); small.
