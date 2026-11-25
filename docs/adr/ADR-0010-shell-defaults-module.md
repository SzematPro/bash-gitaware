# ADR-0010: Shell-defaults module, off for new installs

- Status: Accepted
- Date: 2026-11-25

## Context

`lib/95-shell.bash` started as the rest of a Debian/Ubuntu `~/.bashrc`, so
that `install.sh --replace` gave a working shell. Up to 3.0.0 it ran on
every load and did all of this without being documented:

- history: `HISTCONTROL=ignoreboth`, `HISTSIZE=10000`,
  `HISTFILESIZE=20000`, `histappend`;
- `eval` of `lesspipe` and `dircolors`, and color aliases for `ls`, `grep`,
  `fgrep` and `egrep`;
- the aliases `ll`, `la`, `l`, `alert`, `gs`, `ga`, `gc`, `gp`, `gl`, `gd`,
  `gb`, `gco`, `gst` and `gsp`;
- sourcing `~/.bash_aliases` and bash-completion;
- `~/.npm-global/bin` added to the front of `PATH`.

With `install.sh --append`, a user who already has a full `~/.bashrc` got
all of it on top of their own settings: their history sizes were
overwritten, aliases such as `gc` or `gp` could shadow their commands, and
bash-completion was sourced a second time. The v3 spec had already decided
that this should be an optional module, off by default, and moved it to
3.1. In 3.1 measurements, bash-completion is most of the startup cost
(21 ms with the module, 9 ms without).

The catch is migration. Users of append mode update with `git pull`. They
never run the installer again, so it has no chance to ask them.

## Decision

- **Key `shell_defaults = 0 | 1`** (`BASHGITAWARE_SHELL_DEFAULTS`). With 1,
  the module runs as in 3.0. With 0, none of it runs.
- **Unset means on until 4.0.** This keeps 3.0 behavior for installs updated
  with `git pull`. `bga doctor` shows a notice while the key is unset, with
  the command to choose. The notice does not change the exit status. In 4.0,
  unset will mean off.
- **The installer always writes the key.** Append mode defaults to 0,
  because the user's own `~/.bashrc` already has these settings. Replace
  mode defaults to 1, because it replaces the file that had them. The
  interactive installer asks, with that default. A re-run keeps an existing
  value. If the config cannot be written, the installer warns and prints the
  command, and does not fail the install it has already done.
- **Always on, whatever the key says:** `shopt -s checkwinsize`, so that
  `COLUMNS` stays current for the right-aligned block (bash 4.4 does not
  enable it by default), and the `debian_chroot` lookup, which the prompt
  shows as a tag.
- **bash-gitaware never changes `PATH`.** The `~/.npm-global/bin` entry was
  the author's own setting, not a default, and it is removed in every mode.
- **An `if` block, not a function.** bash-completion has to be sourced at the
  top level. Inside a function its `declare` statements would create locals
  that disappear when the function returns.

## Alternatives considered

- **Off for everyone in 3.1.** Simpler, but a minor release would silently
  remove `gs`, `ll` and the history settings from users who updated with
  `git pull`.
- **On through all of 3.x, off in 4.0, with nothing written now.** New
  installs would keep getting settings they did not ask for, for a whole
  major version.
- **Splitting the module into finer keys** (history, aliases, completion).
  No user has asked for it. One key is enough for now, and finer keys can be
  added later without breaking this one.
- **Keeping the `PATH` entry behind the key.** It was never a default anyone
  chose, and a writable directory in the user's home placed ahead of the
  system directories is not something a prompt should add.

## Consequences

- New installs get only the prompt, unless the user picks replace mode or
  answers yes.
- 3.0 installs behave exactly as before, apart from `PATH`, and `doctor`
  tells their users to choose.
- With the module off, startup is about 12 ms faster where bash-completion
  is installed.
- Anyone who relied on `~/.npm-global/bin` being added has to add it to
  their own `~/.bashrc`. The CHANGELOG lists this under "Removed".
- 4.0 has to flip the unset default. That is a breaking change, and it will
  be listed as one.
