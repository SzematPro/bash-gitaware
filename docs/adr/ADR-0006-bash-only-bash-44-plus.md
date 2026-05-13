# ADR-0006: Bash-only, bash 4.4+

- Status: Accepted
- Date: 2026-05-13

## Context

There are good cross-shell prompts (Starship, oh-my-posh) and shell-specific
ones (Powerlevel10k for zsh, fish's built-in prompt). bash-gitaware is
shell-specific to bash, and specifically to **bash 4.4 or newer**. macOS
ships with bash 3.2.57 (frozen at the GPLv2-to-GPLv3 transition) and the
project does not target it.

This ADR records that boundary, because every feature in v2 hangs off it:
the implementation uses associative arrays, parameter transformations, the
DEBUG trap with `BASH_COMMAND` introspection, `bind -x` for the transient
prompt, and `${var@P}` for prompt-string testing. Walking any of that back
to a portable subset would change the project into something else.

## Decision

**No cross-shell.** bash-native by design. Use bash-specific features where
they fit (associative arrays, `printf -v`, `${var@P}`, `BASH_REMATCH`, the
DEBUG trap and `BASH_COMMAND`, `bind -x`, `PROMPT_COMMAND` as a function
name).

**Bash 4.4 floor.** Specifically required:

- Associative arrays (4.0+; used everywhere).
- `${var@P}` parameter transformation (4.4+; the prompt-string expansion
  trick used in scenario tests).
- `${var,,}` / `${var^^}` case modification (4.0+).
- `${BASH_VERSINFO}` for the runtime version check in `install.sh`.

The README points macOS users to a Homebrew bash
(`brew install bash`, then `chsh -s /opt/homebrew/bin/bash`) and explains
that the stock `/bin/bash` (3.2) is not supported. The `install.sh` script
checks `${BASH_VERSINFO[0]}` and warns if the shell is older than 4.4.

## Alternatives considered

- **Cross-shell support.** Means a portable subset of features and an
  abstraction layer over the prompt API differences (zsh's `precmd` and
  `preexec` vs bash's `PROMPT_COMMAND` and DEBUG trap, fish's prompt
  function vs bash's `PS1` model, the readline-vs-zle gulf). Large surface,
  hard to test, and "the best portable prompt" is already taken by
  Starship. Bash-native lets us be the best bash prompt instead. Rejected.
- **Bash 3.2 support.** Means no associative arrays, no `${var@P}`, no
  modern parameter expansion. The implementation would need workaround
  scaffolding throughout. macOS users are routinely told to install a
  recent bash for any non-trivial shell work; following the same convention
  here is normal. Rejected.

## Consequences

- The implementation is shorter and clearer.
- macOS users have one extra step (install Homebrew bash); documented in
  the README and warned by `install.sh`.
- Cross-shell users go elsewhere. That is acceptable; the niche is "the
  best bash prompt".
- Future v2.x releases can use features added in bash 4.4 freely without
  re-litigating support; a future v3 may raise the floor (to use `wait -p`,
  `EPOCHREALTIME` or other 5.x features) and will state so explicitly.
