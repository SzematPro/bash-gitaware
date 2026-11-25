# Migrating from v2 to v3

v3 keeps every v2 setting working. Below is what changed and how to get
the v2 look back if you want it.

## The look

v3 defaults to the **Lean** style: path and git on the first line, runtimes
aligned to the right, the prompt symbol on the second line. A result line
(`  ✘1 · 3s`) appears only after a command that failed or was slow. The v2
three-line stack is still available:

```bash
bga config set style classic      # or: export BASHGITAWARE_STYLE=classic
```

## Settings

Every v2 variable still works and keeps its meaning. A setting can now come
from three places, in this order of precedence: the environment, the config
file, then the preset.

| v2 variable | v3 | Notes |
|---|---|---|
| `BASHGITAWARE_GLYPHS` | same, key `glyphs` | |
| `BASHGITAWARE_NERD_FONT` | same, key `nerd_font` | With Nerd glyphs, Lean also draws Powerline separators (`powerline = 0` turns them off). |
| `BASHGITAWARE_COMMIT_LINE` | same, key `commit_line` | Off by default in Lean, on in classic. |
| `BASHGITAWARE_RUNTIME` | same, key `runtime` | |
| `BASHGITAWARE_TIMER_THRESHOLD` | same, key `timer_threshold` | |
| `BASHGITAWARE_PATH_MAXDEPTH` | same, key `path_maxdepth` | |
| `BASHGITAWARE_SHOW_HOST` | same, key `show_host` | |
| `BASHGITAWARE_PRESET` | same, key `preset` | |
| `BASHGITAWARE_OSC` | same, key `osc` | |
| `BASHGITAWARE_TRANSIENT` | same, key `transient` | The collapsed line no longer appears twice. |
| `BASHGITAWARE_ASYNC` | same, key `async` | Results now refresh after each command. |
| `NO_COLOR` | same | |

New in v3:

| Variable | Config key | Values | Default |
|---|---|---|---|
| `BASHGITAWARE_STYLE` | `style` | `lean`, `classic` | `lean` |
| `BASHGITAWARE_THEME` | `theme` | `aware`, `light`, `contrast` | `aware` |
| `BASHGITAWARE_CLOCK` | `clock` | `0`, `1` | `0` |
| `BASHGITAWARE_POWERLINE` | `powerline` | `0`, `1` | `1` (only with Nerd glyphs) |
| `BASHGITAWARE_MODE` | `mode` | `auto`, `plain`, `full` | `auto` |
| `BASHGITAWARE_TRUST_REPO_CONFIG` | `trust_repo_config` | `0`, `1` | `0` |
| `BASHGITAWARE_SHELL_DEFAULTS` | `shell_defaults` | `0`, `1` | unset: on (3.1); see below |
| `BASHGITAWARE_CONFIG` | | path to the config file | `~/.config/bash-gitaware/config` |

## The config file and `bga`

You no longer need to export variables. Set things with `bga`:

```bash
bga config set theme light
bga theme preview contrast
bga doctor
bga reload            # apply to the current shell
```

The file is plain `key = value` and is never sourced. An invalid line is
reported with its line number and skipped.

## Behavior that changed on purpose

- **Plain mode.** On a dumb terminal, without a tty, or when `CI`, `AGENT` or
  `AI_AGENT` is set, the prompt is one ASCII line with no escape sequences.
  `BASHGITAWARE_MODE=full` turns this detection off.
- **Your hooks are kept.** Sourcing bash-gitaware no longer replaces your
  `PROMPT_COMMAND`, `PS0`, DEBUG or EXIT traps. They run alongside it.
- **Repositories from archives.** In a `.git` directory whose config defines
  filter drivers, those drivers are disabled for the prompt's own git calls.
  Includes and partial clones show the branch only. If you rely on local
  filters (git-crypt, `git lfs install --local`), set
  `BASHGITAWARE_TRUST_REPO_CONFIG=1`.

## Install and uninstall

`./install.sh` now asks a few questions on a terminal. A mode flag
(`--append`, `--replace`) or `--yes` skips them; `--yes` alone means
replace mode, after a backup.
`./install.sh --uninstall` reverses an install.

## Upgrading from 3.0 to 3.1

- **Shell defaults are a setting now.** The history options, `ls`/`grep`
  colors, aliases (`ll`, `gs`, `gc`, `gp`, ...), `~/.bash_aliases` and
  bash-completion that 3.0 always loaded are controlled by
  `shell_defaults`. If you update with `git pull`, the key is not set and
  nothing changes: they stay on, and `bga doctor` asks you to choose. Choose
  with `bga config set shell_defaults 0` (prompt only) or `1`. 4.0 will
  treat an unset key as `0`.
- **`PATH` is no longer changed.** 3.0 added `~/.npm-global/bin` to the
  front of `PATH`. If you need it, add it to your own `~/.bashrc`:

  ```bash
  PATH="$HOME/.npm-global/bin:$PATH"
  ```
