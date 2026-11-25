# ADR-0009: v3 command-line surface (`bga`)

- Status: Accepted
- Date: 2026-11-25

## Context

v2 is configured only through exported `BASHGITAWARE_*` variables, and its
installer asks nothing. The v3 spec (R6, R7) asks for a `bga` command to
inspect and change settings, preview themes and diagnose problems, and for
an interactive installer and uninstaller. Settings now also live in a
config file that is parsed, never sourced (T0.7).

## Decision

- **One implementation, two entry points.** `lib/94-cli.bash` defines the
  `bga` function in every interactive shell. `bin/bga` runs the same code as
  a script: it sources `new.bashrc` with `_BGA_CLI=1`, which loads settings,
  themes and detection but stops before hooks, aliases and completion. Only
  the function can `bga reload`, because a script cannot change its parent
  shell.
- **Commands:** `config path|list|get|set|unset`, `theme list|preview|set`,
  `doctor`, `reload`, `version`, `help`.
- **Exit codes:** 0 success, 1 a check or operation failed, 2 usage error
  (unknown command, key or value).
- **`config set`** validates with the loader's own rules
  (`__bga_config_valid`), so the CLI cannot write a value the loader would
  reject. The write is atomic: a temp file in the same directory, then
  `mv`, mode 0600. Comments and key order are kept. A symlinked config is
  refused rather than silently replaced by a regular file.
- **`theme preview`** prints a sample Lean prompt with the theme's raw
  tokens, then restores the current theme. PS1 is untouched.
- **`doctor`** reports bash, git, locale, glyphs, color depth, style/theme,
  plain mode, the timeout helper, the state directory and the config file,
  including the loader's warnings. It exits 1 when something blocks normal
  use: bash older than 4.4, git older than 2.11 or missing, an invalid
  config.
- **Installer:** asks for the mode, theme and glyphs only on a terminal with
  no mode flag. `--yes` takes the defaults. `--uninstall` reverses either
  mode. The tamper check refuses a `new.bashrc` or repository directory that
  someone else owns or that others can write; writable by the user's own
  primary group is accepted (ruling L-37).

## Alternatives considered

- **A separate CLI program (Python, Go)**: rejected. It would add a runtime
  dependency, and it could not change the running shell.
- **`bga config edit` opening `$EDITOR`**: deferred. Editing by hand is
  already possible, and validation runs on load and in `doctor`.

## Consequences

- Settings changed with `bga` apply to new shells, or right away after
  `bga reload`.
- `bin/bga` needs the repository checkout. A `--replace` install copies only
  `new.bashrc`, where the `bga` function is available in interactive shells
  anyway.
