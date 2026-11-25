# bash-gitaware 3.1: spec

- Status: Accepted (scope chosen by the owner on 2026-11-25; plan approved the same day)
- Date: 2026-11-25
- Base: 3.0.0 (`v3.0.0`, commit 15d5e2f) plus the CI budget fix b378023
- Builds on: [`../v3/SPEC.md`](../v3/SPEC.md). Its locked decisions (section 2),
  non-functional requirements (section 4) and lessons (sections 5 and 6)
  still apply and are not repeated here.

## 1. Why 3.1

3.0.0 shipped every Must item and four Should items. The 3.0 scope rule sent
all other Should items to 3.1, among them the shell-defaults module and the
policy file. 3.0.0 also left three loose ends:

- `lib/95-shell.bash` runs on every load and is not documented. The locked
  decision says it should be an optional module, off by default. It sets
  history options, evaluates `dircolors` and `lesspipe`, defines 18 aliases
  (`ls`, `grep`, `ll`, `gs`, `gc`, `gp`, `alert`, ...), sources
  `~/.bash_aliases` and bash-completion, and adds `~/.npm-global/bin` to
  `PATH`.
- `tests/MANUAL.md` still describes the v2 milestones and cache paths.
- The 60 ms render budget for hosts with `timeout(1)` is never measured on
  macOS. The hosted runner has no `gtimeout`, so it always takes the 90 ms
  watchdog path (ruling R-7).

## 2. Decisions for 3.1 (owner, 2026-11-25)

| Area | Decision |
|---|---|
| Shell defaults | Off for new installs. Existing 3.0 users keep them through a migration path and are told about it. The `~/.npm-global/bin` `PATH` entry is removed: it is the author's own setting, not a default. |
| Policy file | A system-wide file for administrators, `/etc/bash-gitaware/policy`, owned by root. It sets and locks keys above the user's config and environment. |
| Extras | vi-mode indicator, more runtimes, OSC 9;4 progress, `bga config edit`. |
| Version | 3.1.0, a minor release. Nothing changes for an existing install unless its owner opts in, except the `PATH` entry (listed under "Removed" in the CHANGELOG). |

## 3. Scope

| ID | Item | Priority |
|---|---|---|
| M1 | Shell-defaults module behind `shell_defaults`, off by default, with migration for 3.0 installs | Must |
| M2 | Policy file: system-wide, root-owned, locks keys | Must |
| M3 | Maintenance: macOS CI leg with a real timeout helper (coreutils); `tests/MANUAL.md` rewritten for v3 | Must |
| S5 | vi-mode indicator | Should |
| S6 | More runtimes: Ruby, Deno, Bun, Java | Should |
| S7 | OSC 9;4 taskbar progress while a command runs, opt-in | Should |
| S8 | `bga config edit`: opens `$VISUAL`/`$EDITOR` and validates the file before saving | Should |

Out of scope: a v2.0.5 backport (open as a separate decision), a templating
mini-language, and an animated pending indicator (ruled out in R-5).

## 4. Requirements per item

### M1 Shell defaults

- New key `shell_defaults = 0 | 1` (env `BASHGITAWARE_SHELL_DEFAULTS`).
- With 1, `lib/95-shell.bash` runs as it does today, minus the `PATH` line.
  With 0, none of it runs. Neither value makes bash-gitaware touch `PATH`.
- **Migration.** With the key unset, the module stays on (3.0 behavior),
  because users of append mode update with `git pull` and never run the
  installer again. `bga doctor` reports an unset key as a notice and says how
  to set it. The 3.1 installer always writes the key: append mode defaults to
  0, since the user's own `~/.bashrc` already has these settings; replace mode
  defaults to 1, since it replaces the file that had them. In 4.0 an unset key
  will mean 0. Precise rule: the default is 0 for every install made by the
  3.1 installer, and 1 only for an install that never set the key.
- Startup budget (100 ms) unchanged. With the module off, startup must not
  get slower.

### M2 Policy file

- Path `/etc/bash-gitaware/policy`. Same `key = value` format and the same
  per-key validation as the user config. Parsed as data, never sourced.
- Precedence: policy > environment > user config > preset. A key set in the
  policy is locked: `BASHGITAWARE_*` variables and the user's config cannot
  change it, and `bga config set`/`unset` on it exits 1 and names the policy.
- Trust: the file and every ancestor directory are owned by root and not
  writable by group or others (no ACL grants), the same rules as the
  installer's tamper check. `/etc` as a root-owned symlink (macOS
  `/private/etc`) is allowed. A file that fails the check is ignored with one
  warning, and `bga doctor` exits 1.
- Threat model, written in the ADR: the policy sets defaults for shared and
  managed machines and protects against other local users. It is **not** a
  boundary against the account owner, who can always skip `new.bashrc`.
- Unknown or invalid keys in the policy are warned about by line number and
  ignored, as in the user config.

### M3 Maintenance

- CI: a second macOS job installs `coreutils`, so both time-limit paths
  (helper and watchdog) are tested on macOS. Ruling R-8 changed the budget
  after the first runs: 60 ms off macOS and 90 ms on macOS with either
  helper, with the render median taken over 5 runs.
- `tests/MANUAL.md`: every check reflects 3.x (Lean, ledger, state directory
  under `XDG_RUNTIME_DIR` or the fallback, `bga`, plain mode, themes). The v2
  milestone sections are removed.

### S5 vi-mode indicator

- With `set -o vi`, the last prompt line shows the editing mode through
  readline's `show-mode-in-prompt` with `vi-ins-mode-string` and
  `vi-cmd-mode-string` (readline 7.0, so bash 4.4 and later).
- The strings come from theme tokens and the glyph tier, wrapped in `\1 \2`.
- If the user has set their own mode strings or `show-mode-in-prompt`,
  bash-gitaware leaves them alone. Key `vi_mode = auto | 0`.
- No indicator in plain mode or emacs mode. The transient prompt and the
  ledger keep their width math correct.

### S6 More runtimes

- Ruby (`.ruby-version`, `Gemfile`), Deno (`deno.json`, `deno.jsonc`), Bun
  (`bun.lockb`, `bun.lock`, `bunfig.toml`), Java (`.java-version`,
  `.sdkmanrc`).
- New runtimes read version files only and never run the tool. If there is
  no version file, the label is shown without a version.
- The same cache, escaping and right-block drop order as the existing
  `py`, `node`, `rust` and `go` entries.
- New key `runtimes` (comma list, default all) to choose which ones show.
  `runtime = 0` still turns them all off.

### S7 OSC 9;4 progress

- Opt-in key `progress = 0 | 1`, default 0.
- When on, `PS0` emits `OSC 9;4;3` (indeterminate) when a command starts and
  the prompt emits `OSC 9;4;0` before it is drawn. After a failure it emits
  state 2 (error) for one prompt, then 0.
- Off in plain mode, with `osc = 0`, and inside tmux/screen (no passthrough).
- Uses the existing `PS0` chaining. User `PS0` content is kept.

### S8 `bga config edit`

- Opens `$VISUAL`, then `$EDITOR`, then `vi` on a 0600 temp copy next to
  the config file, so the save is an atomic `mv`. On exit the copy is validated with the loader's rules.
- Valid: saved atomically (the same path as `bga config set`). Invalid: the
  warnings are shown, and the user chooses to edit again or discard. The
  original is never left half written.
- Refuses a symlinked config (as `config set` does). Keys locked by the
  policy are reported as having no effect.
- With no terminal, exits 2 with a message.

## 5. Acceptance criteria for the release

1. A fresh `install.sh --append --yes` produces a shell with no bash-gitaware
   aliases and an unchanged `PATH`. A 3.0 config with no `shell_defaults` key
   behaves exactly like 3.0, minus the `PATH` entry, and `bga doctor` shows
   the notice.
2. A root-owned policy that sets `theme = contrast` wins over
   `BASHGITAWARE_THEME=aware` and `bga config set theme aware` (which exits
   1). A policy that others can write is ignored with a warning.
3. CI passes on the bash 4.4-5.3 matrix, both macOS jobs (60 ms and 90 ms
   budgets), and the docs job (parity covers the new README sections).
4. Every S item has its tests listed in the plan, and all of them pass.
5. Shellcheck stays clean, the startup and render budgets are not raised, and
   no new ruling raises a budget.
