# Changelog

All notable changes to bash-gitaware are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`shell_defaults` setting.** The history options, `ls`/`grep` colors,
  aliases, `~/.bash_aliases` and bash-completion that 3.0 always loaded can
  now be turned off (`bga config set shell_defaults 0`). The installer
  writes the key (by default `0` for append and `1` for replace; it asks on
  a terminal and keeps an existing value). When it is not set, they
  stay on as in 3.0, and `bga doctor` asks you to choose.

- **Administrator policy** (`/etc/bash-gitaware/policy`). Root can set and
  lock settings for every user. The policy is used only when root owns it
  and no one else can write it, and `bga doctor` shows what it locks.

- **Ruby, Deno, Bun and Java runtimes**, read from version files only (no
  program runs). `runtimes = py,node,...` picks which runtimes show.
- **vi-mode indicator**: with `set -o vi`, a marker appears in command mode,
  drawn by readline. Your own readline mode settings are kept.
- **Taskbar progress** (`progress = 1`, OSC 9;4) while a command runs, with
  the error state after a failure. Off by default, and inside tmux/screen.
- **`bga config edit`** opens `$VISUAL`/`$EDITOR` and checks the file
  before saving it.

### Changed

- Startup is about 12 ms faster with `shell_defaults = 0` where
  bash-completion is installed.
- CI tests macOS both with and without Homebrew coreutils. The render budget
  is now set per platform: 60 ms, or 90 ms on macOS.

### Fixed

- `bga reload` now applies config changes. Before, `bga theme set X;
  bga reload` kept the old theme, because values loaded from the config
  file counted as environment on the second load.

### Removed

- bash-gitaware no longer adds `~/.npm-global/bin` to `PATH`. If you need
  it, add it to your own `~/.bashrc` (see `docs/MIGRATION.md`).

## [3.0.0] - 2026-11-25

### Added

- **Lean style (default).** Path and git on line 1, runtimes and an optional
  clock aligned right, symbol on line 2, and a result line (`  ✘1 · 3s`) after
  failed or slow commands. `style = classic` keeps the v2 layout.
- **Themes.** `aware` (default), `light` and `contrast`, built from semantic
  color tokens and resolved for 24-bit, 256, 16 or no color. WCAG contrast
  is checked in CI.
- **Powerline separators** with Nerd Font glyphs.
- **`bga` command:** `config`, `theme`, `doctor`, `reload`, `version`.
- **Config file** (`~/.config/bash-gitaware/config`), parsed as data and
  validated per key, with line numbers in warnings.
- **Plain mode** for dumb terminals, CI and agents (one ASCII line).
- **Interactive installer** with `--yes`, `--uninstall` and a tamper check.
- **Spanish README** (`README.es.md`), with a parity check in CI.
  Migration guide: `docs/MIGRATION.md`.

### Changed

- One git call per prompt on the fast path. In a 100k-file repository the
  prompt takes about 11 ms with the background worker.
- bash-gitaware now coexists with your `PROMPT_COMMAND`, `PS0`, DEBUG and
  EXIT traps, and with bash-preexec, instead of replacing them.

### Fixed

- The transient prompt showed every collapsed command twice (bash 4.4-5.3).
- Runtime versions were recomputed on every prompt; the cache now works.
- The async git status was never refreshed while you stayed in a directory.
- `new.bashrc` failed to load with `set -o posix` on bash 4.4 and 5.0.
- An empty Enter no longer counts as a command.

### Security

- Four independent reviews (SR1-SR4) and automated reviews. Every finding
  was reproduced and fixed, with a regression test. The records are in
  `docs/v3/reviews/`, and the design is in
  `docs/adr/ADR-0008-v3-git-worker-trust-and-state.md`.

## [2.0.4] - 2026-11-25

### Security

- **Another bypass of the `.git` trust check.** Command substitution strips
  trailing newlines, so a repository path ending in a newline lost it and
  named a sibling directory. The background status job then ran
  `git status` in that sibling, without checking its config, so its filter
  drivers ran. The `rev-parse` output is now captured with a sentinel, must
  have exactly three newline-terminated lines, and the background job runs
  in the shell's own directory instead of a re-derived path.
- **Shell lock-up from a FIFO (found by an independent audit).** A FIFO or a
  `/dev/tty` symlink at `.git/config`, `HEAD`, `index`, `packed-refs` or any
  other path git reads blocked the prompt for good (Ctrl-C only restarted
  it), and in async mode each prompt left another stuck `git status` that
  outlived the shell. Every prompt git call now has a hard time limit
  (`timeout -s KILL`, or a watchdog where `timeout` is missing): 1 s each,
  3 s for a synchronous `git status`, 10 s in the background job. The first
  timeout makes the rest of that prompt skip git.

The same audit checked about 30 other command-valued git settings and hooks
reachable from the prompt's git calls and found them closed.

## [2.0.3] - 2026-11-25

### Security

- **Bypass of the 2.0.2 `.git` trust check.** The check read only the first
  256 characters of a linked worktree's `.git/commondir`, while git reads the
  whole file. With a longer path, the check scanned a decoy config at the
  truncated prefix while git loaded the real one, so that config's filter
  drivers ran. The common directory now comes from
  `git rev-parse --git-common-dir`, in the call the prompt already makes,
  and a missing config fails closed.
- **Newline in a repository path.** That output was split on newlines, so a
  directory name containing a newline (possible in an archive) shifted the
  fields and could point the check at a planted decoy config. Output with
  an unexpected number of lines now means no git info at all.

## [2.0.2] - 2026-11-25

### Security

- **Commands from a hostile `.git` directory (high).** `git clone` never
  copies `.git/config`, but an extracted archive can ship one. The prompt's
  own git calls could then run commands named there on every `cd`:
  `core.fsmonitor`, clean/process filter drivers (any freshly extracted tree
  has stale stat data), the `post-index-change` hook, `gpg.program` for a
  forged signed commit with `log.showSignature`, a lazy fetch in a partial
  clone, and the same settings inside submodules. Every git call the prompt
  makes now runs with `--no-optional-locks`, `core.hooksPath=/dev/null`,
  `core.fsmonitor` and `log.showSignature` off and `GIT_NO_LAZY_FETCH=1`;
  filter drivers defined in the repository's own config are neutralized
  (git itself lists them); `git status` skips submodule contents; and a
  repository config that uses `include`/`includeIf` or is a partial clone
  makes the prompt show only the branch. Users
  whose repositories legitimately define local filters (git-crypt,
  `git lfs install --local`) can set `BASHGITAWARE_TRUST_REPO_CONFIG=1`.
- **Prompt hang.** A version file or `.git` file that is a symlink to
  `/dev/zero`, `/dev/tty` or a FIFO hung every prompt. Such files are now
  read only when they are regular files, and at most 256 bytes.
- **Escape injection through the window title** (bash 4.4 to 5.1, where `\w`
  passes control characters through), through the transient prompt's echo
  of the typed line, and through C1 control characters in the C locale.

### Added

- `tests/gitconfig.sh` and new `tests/security.sh` scenarios for each case.
  Every one of them fails on 2.0.1.

## [2.0.1] - 2026-11-25

### Security

- **Prompt command execution (critical).** In 2.0.0 and earlier, branch
  names, commit subjects, directory names, `.python-version` / `.nvmrc` /
  `.node-version` contents and virtualenv/conda names were pasted into `PS1`
  unescaped. With bash's default `promptvars`, a repository containing a
  branch or commit subject such as `$(cmd)` or `` `cmd` `` ran `cmd` on every
  prompt as soon as the user entered the directory. All untrusted segments
  are now escaped by `__bga_ps1_lit` (new `lib/15-escape.bash`) and shown
  verbatim; backslash sequences such as `\u` in a subject are no longer
  decoded either.
- **Terminal-escape injection.** Control characters in those segments, and
  in the OSC 7 cwd report, are replaced with `?`.
- **Async cache in a shared directory.** Without `XDG_RUNTIME_DIR`, the
  cache lived at the predictable `/tmp/bga-<pid>.cache`, letting another
  local user plant a symlink that the cache write followed. It now lives in
  a private `mktemp -d` directory, removed at exit.

### Fixed

- Transient prompt line count is tracked while building `PS1` instead of
  counting `\n` in the final string, which over-counted when escaped text
  contained a literal backslash-n.

### Added

- `tests/security.sh`: regression scenarios for every injection source,
  control characters, special characters, `promptvars` off, and the async
  cache location.

## [2.0.0] - 2026-05-13

### Added

- **`demo/demo.tape` + `demo/demo.gif`**: a `vhs`-rendered demo showing a
  typical session (clean repo, dirty marker, stash count, command timer,
  failure prompt, leave the repo). Regenerate with `make demo` -- requires
  the `vhs`, `ttyd`, and `ffmpeg` binaries. Output is `.gif` (vhs does not
  support `.svg` directly); 126 KB at 1280x720, 12 fps.
- **`install.sh`**: one-shot installer with two modes. `--replace` (default)
  copies `new.bashrc` to `~/.bashrc` after a timestamped backup at
  `~/.bashrc.bak-<unix-ts>`. `--append` writes a `source <repo>/new.bashrc`
  line to the existing `~/.bashrc`, idempotent across reruns. Warns
  (does not refuse) when `bash` is older than 4.4; prints the macOS
  upgrade path. Flags: `--no-backup`, `--target FILE`, `--help`.
- **Async rendering**: the expensive part of the git info (`git status
  --porcelain=v2` for the dirty / ahead / behind counters) is computed in
  a background subshell and surfaced on the *next* prompt cycle, so the
  prompt appears instantly even on large monorepos. A faint `…`
  placeholder appears next to the branch info while the background job
  runs. The cheap info (branch, hash, in-progress state, commit subject,
  stash count) stays synchronous so the prompt is never information-empty.
  Disable with `BASHGITAWARE_ASYNC=0` for fully synchronous rendering.
  See [ADR-0005](docs/adr/ADR-0005-async-rendering.md) for the
  "deferred-on-next-prompt" tradeoff and what was deliberately not built
  (signal-based in-place refresh, runtime async).
- **Transient prompt**: after Enter, the previous prompt collapses to a
  one-line form `❯ <command>` (or `> <command>` on the ascii tier),
  colored by that command's exit code. The live prompt stays full and
  informative; the scrollback stays compact. Implemented via a `bind -x`
  auxiliary chord (`\C-x\C-t`) plus an Enter remap (`"\C-x\C-t\C-j"`) that
  collapses, then triggers `accept-line` via a separate readline binding
  to avoid recursing into the remap. Disable with
  `BASHGITAWARE_TRANSIENT=0`. See
  [ADR-0004](docs/adr/ADR-0004-transient-prompt.md).
- **Presets** via `BASHGITAWARE_PRESET=minimal|default|powerline|full`. The
  preset sets a coherent set of defaults; individual `BASHGITAWARE_*`
  variables still override. `minimal` is ascii-leaning with the commit line
  and runtime modules off; `powerline` turns on Nerd Font glyphs by default
  (the arrow-segment render is planned for a future release); `full` forces
  the commit line on, runtime modules on, and `user@host` always shown.
- **OSC 133 semantic prompt marks** (A/B/C/D) and **OSC 7 cwd reporting**.
  Modern terminals (WezTerm, Kitty, VS Code, iTerm2, Ghostty, Konsole,
  Windows Terminal, Warp, ...) use these to support "jump to previous
  prompt", "select last command output", failed-prompt decorations and
  "new tab inherits cwd". Disable with `BASHGITAWARE_OSC=0`. OSC 133;C is
  emitted via `PS0` rather than the DEBUG trap so it fires exactly once per
  user command at the right moment.
- v2 spec, plan, ADRs (six) and a render-pipeline diagram in `docs/` (Mermaid
  diagrams render natively on GitHub).
- Modular source layout under `lib/[0-9][0-9]-*.bash`; the single-file
  `new.bashrc` becomes a build artifact generated by `bin/build.sh` and
  committed. `make build` regenerates it; `make check` is the CI gate that
  verifies it is in sync.
- Two-line modular prompt: a context line (repo-relative path, branch + hash,
  ahead/behind, dirty, stash, in-progress git state) followed by the prompt
  symbol on a new line; optional "last commit subject" line between the two.
- Runtime modules for Node / Python / Rust / Go shown only in directories
  that call for them; result cached per `(PWD, VIRTUAL_ENV, CONDA_DEFAULT_ENV)`.
- Tiered glyphs (`nerd` > `unicode` > `ascii`). `nerd` is opt-in via
  `BASHGITAWARE_NERD_FONT=1`; a UTF-8 locale alone never selects it.
- Configurable knobs: `BASHGITAWARE_GLYPHS`, `BASHGITAWARE_NERD_FONT`,
  `BASHGITAWARE_COMMIT_LINE`, `BASHGITAWARE_RUNTIME`,
  `BASHGITAWARE_TIMER_THRESHOLD`, `BASHGITAWARE_PATH_MAXDEPTH`,
  `BASHGITAWARE_SHOW_HOST`, plus `NO_COLOR` (<https://no-color.org>).
- Test suite: scenario tests, performance budget, lib-syntax gate, build-
  freshness gate (`make test` / `bash tests/run.sh`).
- GitHub Actions CI workflow: shellcheck (`-x`), build-freshness check,
  tests. **CI matrix** for v2.0.0: a `bash-versions` job runs the test
  suite inside `bash:4.4` / `bash:5.0` / `bash:5.1` / `bash:5.2` /
  `bash:latest` Docker containers (Alpine-based); a `macos-tests` job
  runs the suite on `macos-latest` with Homebrew bash. The main
  `lint-build-test` job continues to run lint + freshness + tests on
  `ubuntu-latest` with the system bash.

### Changed

- `user@host` is now hidden by default and only shown over SSH or when
  running as root (`BASHGITAWARE_SHOW_HOST=always|never` to override).
- Path is repo-relative inside a git work tree (`repo-name + path-within-repo`)
  and trimmed to the last `BASHGITAWARE_PATH_MAXDEPTH` components by default.
- **README rewritten** for v2: the layout is two-line + optional commit
  line (was the v1 box prompt with bracketed `[branch:hash]`); the glyph
  set is tiered (was a single UTF-8/ASCII binary); the install path goes
  through `install.sh` (was a manual `cp`); the configuration surface is
  the `BASHGITAWARE_*` env vars + presets (was a partial subset). The new
  README documents the actual v2 anatomy, module layout, configuration
  matrix, presets, compatibility matrix, performance budget,
  troubleshooting (incl. the "tofu on non-Nerd-Font terminal" story), and
  contributing flow.

### Removed

- The v1 `╭─ Commit ─╮` box around the last commit subject and its manual
  width arithmetic. The commit subject still ships, on its own line, without
  box drawing (`BASHGITAWARE_COMMIT_LINE=0` to disable).
- Locale-only glyph gating. Glyphs now use the tiered detector described in
  [ADR-0002](docs/adr/ADR-0002-tiered-glyph-detection.md).

## [1.0.0] - 2026-02-10

The v1 baseline that shipped on the `main` branch before the v2 work began.
Retroactively versioned for the changelog.

### Added

- Optimized git-aware prompt with commit-message box, environment detection,
  command timer, virtual-environment indicators (Python venv, Conda, NVM
  node), container detection, SSH-aware host display, exit code, ahead/behind
  remote, stash count, git in-progress state via filesystem checks.
- Unicode box-drawing for the commit message line (`╭─ ─╮ │ ╰─╯`).
- ASCII fallback for non-UTF-8 locales.
- README with a manual-style explanation of each prompt element.
- MIT License.
- Performance: 2-3 git subprocesses per prompt (down from the early 7);
  environment detection done once at shell startup.
